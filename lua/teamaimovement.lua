-- bots_can_follow_in_stealth / bots_can_wait_when_loud networking

TeamAIMovement.bhfr_modes = {
	vanilla = 0,     -- follow/revive (loud)
	stealth_follow = 1, -- follow (stealth)
	defend_area = 2, -- wait: stationary (stealth/loud)
	defend_cover = 3, -- wait: use cover (loud)
}

-- wait modes in the order they are cycled through (host setting "wait_modes":
-- 1 = stationary -> cover, 2 = cover -> stationary, 3 = only stationary,
-- 4 = only cover). a single mode is returned as both first and second.
function TeamAIMovement.bhfr_wait_modes()
	local modes = TeamAIMovement.bhfr_modes
	local setting = BotsHaveFeelingsReborn.Sync:GetConfigOption("wait_modes")
	if setting == 2 then
		return modes.defend_cover, modes.defend_area
	elseif setting == 3 then
		return modes.defend_area, modes.defend_area
	elseif setting == 4 then
		return modes.defend_cover, modes.defend_cover
	end
	return modes.defend_area, modes.defend_cover
end

function TeamAIMovement:bhfr_is_wait_mode()
	local mode = self:bhfr_mode()
	return (mode == self.bhfr_modes.defend_area) or (mode == self.bhfr_modes.defend_cover)
end

-- first -> second -> first, anything else -> first (single mode: always that one)
function TeamAIMovement:bhfr_next_wait_mode()
	local first, second = self.bhfr_wait_modes()
	return (self:bhfr_mode() == first) and second or first
end

Hooks:PostHook(TeamAIMovement, "check_visual_equipment", "BHFR_TeamAIMovement_check_visual_equipment",
	function(self)
		if Network:is_client() and
			BotsHaveFeelingsReborn.Sync and
			BotsHaveFeelingsReborn.Sync:host_has_mod() then
			local cache = BotsHaveFeelingsReborn.Sync.drop_in_cache[self._unit:base()._tweak_table]
			if cache then
				local data = cache[BotsHaveFeelingsReborn.Sync.events.bot_bhfr_mode]
				if data then
					-- set_bhfr_mode compares mode and followed unit itself
					self:set_bhfr_mode(data.mode, data.following)
					-- set_bhfr_mode skips the hud if nothing changed, but the label may be new
					self:_update_bhfr_hud()
				end
				local revive_data = cache[BotsHaveFeelingsReborn.Sync.events.bot_bhfr_revive]
				if revive_data then
					self:set_bhfr_reviving(revive_data.target)
				end
				local follow_data = cache[BotsHaveFeelingsReborn.Sync.events.bot_bhfr_follow]
				if follow_data then
					self:set_bhfr_follow_target(follow_data.target)
				end
				local carry_data = cache[BotsHaveFeelingsReborn.Sync.events.bot_bhfr_carry]
				if carry_data then
					self:set_bhfr_carry_job(carry_data.state)
				end
				local bot_carry_weight_data = cache[BotsHaveFeelingsReborn.Sync.events.bot_carry_weight]
				if bot_carry_weight_data then
					self:modify_carry_weight(bot_carry_weight_data.current, bot_carry_weight_data.max, true)
				end
			end
		end
	end
)

function TeamAIMovement:_switch_to_not_cool(instant)
	local inventory = self._unit:inventory()
	local whisper_mode = managers.groupai:state():whisper_mode()

	-- update crouching
	self._unit:character_damage():set_crouch_move(whisper_mode or self:bhfr_is_wait_mode())

	-- use secondary weapon in stealth
	local slot = whisper_mode and PlayerInventory.SLOT_1 or PlayerInventory.SLOT_2
	if inventory:is_selection_available(slot) and (inventory:equipped_selection() ~= slot) then
		inventory:equip_selection(slot)
	end

	if not Network:is_server() then
		-- fix not needed anymore
		-- self._cool = false -- fix client not saving self._cool = false (host saves in _switch_to_not_cool_clbk_func)
		return
	end

	if self._heat_listener_clbk and not whisper_mode then
		managers.groupai:state():remove_listener(self._heat_listener_clbk)

		self._heat_listener_clbk = nil
	end

	if instant then
		if self._switch_to_not_cool_clbk_id then
			managers.enemy:remove_delayed_clbk(self._switch_to_not_cool_clbk_id)
		end

		self._switch_to_not_cool_clbk_id = "dummy"

		self:_switch_to_not_cool_clbk_func()
	elseif not self._switch_to_not_cool_clbk_id then
		self._switch_to_not_cool_clbk_id = "switch_to_not_cool_clbk" .. tostring(self._unit:key())

		managers.enemy:add_delayed_clbk(self._switch_to_not_cool_clbk_id,
			callback(self, self, "_switch_to_not_cool_clbk_func"), TimerManager:game():time() + math.random() * 1 + 0.5)
	end
end

function TeamAIMovement:set_bhfr_mode(mode, caller)
	local caller_string = false
	if caller and (type(caller) == "string") then
		caller_string = caller
		caller = managers.criminals:character_unit_by_name(caller)
	end
	if caller and not caller_string then
		caller_string = managers.criminals:character_name_by_unit(caller)
	end

	if (self:bhfr_mode() == mode) and (self:bhfr_following() == caller) then
		-- nothing changed
		return
	end

	self._bhfr_mode = mode
	self._bhfr_following = caller

	-- bot crouching
	self._unit:character_damage():set_crouch_move(self:bhfr_mode() ~= self.bhfr_modes.vanilla)

	self:_update_bhfr_hud()

	if not Network:is_server() then
		return
	end

	self:set_cool(false)

	local brain = self._unit:brain()
	local following = nil

	if caller and (caller:base().is_local_player and caller:character_damage() or caller:movement()):need_revive() then
		-- revive
		following = caller_string
		brain:set_objective(self:get_bhfr_objective_revive(caller))
	elseif self:bhfr_is_wait_mode() then
		-- defend area (stationary / use cover, told apart by the logic hooks)
		brain:set_objective(self:get_bhfr_objective_defend_area())
	elseif caller then
		-- follow
		following = caller_string
		brain:set_objective(self:get_bhfr_objective_follow(caller))
	end

	BotsHaveFeelingsReborn.Sync:send_to_peers(false, BotsHaveFeelingsReborn.Sync.events.bot_bhfr_mode, {
		name = self._unit:base()._tweak_table,
		mode = mode,
		following = following
	})
end

function TeamAIMovement:get_bhfr_objective_revive(caller)
	return {
		type = "revive",
		scan = true,
		called = true,
		destroy_clbk_key = false,
		follow_unit = caller,
		action_duration = tweak_data.interaction:get_interaction("revive").timer,
		nav_seg = caller:movement():nav_tracker():nav_segment(),
		action = {
			type = "act",
			variant = "revive",
			body_part = 1,
			align_sync = true,
			blocks = {
				action = -1,
				aim = -1,
				heavy_hurt = -1,
				hurt = -1,
				light_hurt = -1,
				walk = -1,
			},
		},
		followup_objective = {
			type = "act",
			scan = true,
			action = {
				type = "act",
				variant = "crouch",
				body_part = 1,
				blocks = {
					action = -1,
					aim = -1,
					heavy_hurt = -1,
					hurt = -1,
					walk = -1,
				},
			},
		},
	}
end

function TeamAIMovement:get_bhfr_objective_follow(caller)
	local result = {
		type = "follow",
		scan = true,
		called = true,
		follow_unit = caller,
		destroy_clbk_key = false,
	}
	if managers.groupai:state():whisper_mode() then
		result.pose = "crouch"
	end
	return result
end

function TeamAIMovement:get_bhfr_objective_defend_area()
	return {
		type = "defend_area",
		pose = "crouch",
		scan = true,
		destroy_clbk_key = false,
		pos = mvector3.copy(self:nav_tracker():field_position()),
		nav_seg = self:nav_tracker():nav_segment(),
		radius = 1000,
	}
end

-- colour of the followed character, picked locally: the same one WolfgangHUD
-- (if installed, it has its own colorize modes) or the game uses for names and outlines
function TeamAIMovement:_bhfr_follow_color()
	local target = self._bhfr_follow_target

	if not target then
		return nil
	end

	local target_unit = managers.criminals:character_unit_by_name(target)
	local color_id

	if alive(target_unit) then
		if WolfgangHUD and WolfgangHUD.character_color_id then
			-- its panel mode looks the unit up in the criminals manager, which can fail while units come and go
			local ok, id = blt.pcall(WolfgangHUD.character_color_id, WolfgangHUD, target_unit)

			color_id = ok and id or nil
		else
			color_id = managers.criminals:character_color_id_by_unit(target_unit)
		end
	end

	return color_id and tweak_data.chat_colors[color_id] or Color.white
end

function TeamAIMovement:_update_bhfr_hud()
	local unit_data = self._unit:unit_data()
	if unit_data and managers.hud and unit_data.teammate_panel_id then
		managers.hud:set_bot_bhfr_mode(unit_data.teammate_panel_id, unit_data.name_label_id, self:bhfr_mode())

		-- revive icon: red when the bot is on its way to revive the local player, white for anybody else
		local target = self._bhfr_reviving
		local state = target and ((target == managers.criminals:local_character_name()) and "me" or "other")
		managers.hud:set_bot_bhfr_revive(unit_data.teammate_panel_id, unit_data.name_label_id, state)

		managers.hud:set_bot_bhfr_follow(unit_data.teammate_panel_id, unit_data.name_label_id,
			self:_bhfr_follow_color())
		managers.hud:set_bot_bhfr_carry(unit_data.teammate_panel_id, unit_data.name_label_id, self._bhfr_carry_job)
	end
end

-- monkeepers_mode: "fetch" = on its way to a bag, "bring" = carrying it to the throw spot (nil = none)
function TeamAIMovement:set_bhfr_carry_job(state)
	if self._bhfr_carry_job == state then
		return
	end

	self._bhfr_carry_job = state

	self:_update_bhfr_hud()

	if Network:is_server() and BotsHaveFeelingsReborn.Sync then
		BotsHaveFeelingsReborn.Sync:send_to_peers(false, BotsHaveFeelingsReborn.Sync.events.bot_bhfr_carry, {
			name = self._unit:base()._tweak_table,
			state = state
		})
	end
end

-- name of the criminal this bot is on its way to revive (nil = none)
function TeamAIMovement:set_bhfr_reviving(target_name)
	if self._bhfr_reviving == target_name then
		return
	end

	self._bhfr_reviving = target_name

	self:_update_bhfr_hud()

	if Network:is_server() and BotsHaveFeelingsReborn.Sync then
		BotsHaveFeelingsReborn.Sync:send_to_peers(false, BotsHaveFeelingsReborn.Sync.events.bot_bhfr_revive, {
			name = self._unit:base()._tweak_table,
			target = target_name
		})
	end
end

function TeamAIMovement:bhfr_reviving()
	return self._bhfr_reviving
end

-- name of the criminal this bot follows (nil = none)
function TeamAIMovement:set_bhfr_follow_target(target_name)
	if self._bhfr_follow_target == target_name then
		return
	end

	self._bhfr_follow_target = target_name

	self:_update_bhfr_hud()

	if Network:is_server() and BotsHaveFeelingsReborn.Sync then
		BotsHaveFeelingsReborn.Sync:send_to_peers(false, BotsHaveFeelingsReborn.Sync.events.bot_bhfr_follow, {
			name = self._unit:base()._tweak_table,
			target = target_name
		})
	end
end

function TeamAIMovement:bhfr_mode()
	return self._bhfr_mode or self.bhfr_modes.vanilla
end

function TeamAIMovement:bhfr_following()
	return self._bhfr_following
end

-- bots_can_catch

tweak_data.ai_carry = {
	throw_force = 150
}

TeamAIMovement.CLASS_MAP = {
	["american"] = "assault",
	["german"] = "demolitions",
	["russian"] = "infiltrator",
	["british"] = "recon",
}

function TeamAIMovement:is_carrying()
	if Network:is_server() then
		if self._carry_units and not table.empty(self._carry_units) then
			return true
		end
	else
		if self:get_my_carry_weight() > 0 then
			return true
		end
	end

	return false
end

function TeamAIMovement:add_carry_unit(unit)
	local carry_id = unit:carry_data():carry_id()
	local carry_tweak = tweak_data.carry[carry_id]
	if self:can_carry_weight(carry_id) then
		self._carry_units = self._carry_units or {}
		self._carry_units[unit:id()] = unit
		self:modify_carry_weight(carry_tweak and carry_tweak.weight or tweak_data.carry.default_bag_weight)
		return true
	end
	return false
end

function TeamAIMovement:remove_carry_unit(unit, silent)
	if Network:is_server() and self:is_carrying() then
		local carry_id = unit:carry_data():carry_id()
		local carry_tweak = tweak_data.carry[carry_id]
		self._carry_units[unit:id()] = nil
		self:modify_carry_weight(-(carry_tweak and carry_tweak.weight or tweak_data.carry.default_bag_weight), nil, false,
			silent)
	end
end

function TeamAIMovement:can_carry_weight(carry_id)
	local carry_tweak = tweak_data.carry[carry_id]

	return (self:get_my_carry_weight_limit() >= (self:get_my_carry_weight() + (carry_tweak and carry_tweak.weight or tweak_data.carry.default_bag_weight)))
end

function TeamAIMovement:get_my_carry_weight()
	return self._carry_weight or 0
end

function TeamAIMovement:get_my_carry_weight_limit()
	local class_tweak_data = tweak_data.player:get_tweak_data_for_class(self.CLASS_MAP[self._unit:base()._tweak_table] or
		"assault")
	return (class_tweak_data.movement.carry.CARRY_WEIGHT_MAX or 5) +
		(BotsHaveFeelingsReborn:GetConfigOption("bots_have_strong_back") and 2 or 0)
end

function TeamAIMovement:drop_all_carry()
	if not Network:is_server() then
		return
	end
	if self:is_carrying() then
		for _, unit in pairs(self._carry_units) do
			if unit and alive(unit) and unit:carry_data() then
				unit:carry_data():unlink(true)
			end
		end
	end
	self._carry_units = {}
	self:reset_carry_weight()
end

function TeamAIMovement:modify_carry_weight(amount, max, abs, silent)
	if abs then
		self._carry_weight = amount or 0
	elseif amount and (amount ~= 0) then
		self._carry_weight = math.round(self:get_my_carry_weight() + amount)
	end

	max = max or self:get_my_carry_weight_limit()

	local unit_data = self._unit:unit_data()
	if unit_data and managers.hud and unit_data.teammate_panel_id and unit_data.name_label_id then
		-- update GUI
		managers.hud:set_bot_carry_weight(unit_data.teammate_panel_id, unit_data.name_label_id,
			self._carry_weight, max)
	end

	if Network:is_server() and BotsHaveFeelingsReborn.Sync and not silent then
		-- update clients
		BotsHaveFeelingsReborn.Sync:send_to_peers(false, BotsHaveFeelingsReborn.Sync.events.bot_carry_weight, {
			name = self._unit:base()._tweak_table,
			current = self._carry_weight,
			max = max
		})
	end
end

function TeamAIMovement:reset_carry_weight()
	self:modify_carry_weight(nil, nil, true)
end
