-- bots_can_follow_in_stealth networking

Hooks:PostHook(TeamAIMovement, "check_visual_equipment", "BHFR_TeamAIMovement_check_visual_equipment",
	function(self)
		if Network:is_client() and
			BotsHaveFeelingsReborn.Sync and
			BotsHaveFeelingsReborn.Sync:host_has_mod() then
			local name = managers.criminals:character_name_by_unit(self._unit)
			if name then
				local cache = BotsHaveFeelingsReborn.Sync.drop_in_cache[name]
				if cache then
					local bot_cool_data = cache[BotsHaveFeelingsReborn.Sync.events.bot_cool]
					if bot_cool_data and (self:cool() ~= bot_cool_data.state) then
						self:set_cool(bot_cool_data.state)
					end
					local bot_carry_weight_data = cache[BotsHaveFeelingsReborn.Sync.events.bot_carry_weight]
					if bot_carry_weight_data then
						self:modify_carry_weight(bot_carry_weight_data.current, true)
					end
				end
			end
		end
	end
)

function TeamAIMovement:_switch_to_not_cool(instant)
	local inventory = self._unit:inventory()

	-- use secondary weapon in stealth
	local slot = managers.groupai:state():whisper_mode() and PlayerInventory.SLOT_1 or PlayerInventory.SLOT_2

	if inventory:is_selection_available(slot) and inventory:equipped_selection() ~= slot then
		inventory:equip_selection(slot)
	end

	if not Network:is_server() then
		self._cool = false -- fix client not saving self._cool = false (host saves in _switch_to_not_cool_clbk_func)
		return
	end

	if self._heat_listener_clbk then
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

-- bots_can_catch

tweak_data.ai_carry = {
	throw_force = 150,
	catch_timeout = 5
}

TeamAIMovement.CLASS_MAP = {
	["american"] = "assault",
	["german"] = "demolitions",
	["russian"] = "infiltrator",
	["british"] = "recon",
}

function TeamAIMovement:is_carrying()
	if self._carry_units and not table.empty(self._carry_units) then
		return true
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

function TeamAIMovement:remove_carry_unit(unit)
	if self:is_carrying() then
		local carry_id = unit:carry_data():carry_id()
		local carry_tweak = tweak_data.carry[carry_id]
		self._carry_units[unit:id()] = nil
		self:modify_carry_weight(-(carry_tweak and carry_tweak.weight or tweak_data.carry.default_bag_weight))
	end
end

function TeamAIMovement:can_carry_weight(carry_id)
	local carry_tweak = tweak_data.carry[carry_id]

	return not carry_tweak.skip_exit_secure and (self:get_my_carry_weight_limit() >=
		(self:get_my_carry_weight() + (carry_tweak and carry_tweak.weight or tweak_data.carry.default_bag_weight)))
end

function TeamAIMovement:get_my_carry_weight()
	return self._carry_weight or 0
end

function TeamAIMovement:get_my_carry_weight_limit()
	local nationality = managers.criminals:character_name_by_unit(self._unit) or "british"
	local class_tweak_data = tweak_data.player:get_tweak_data_for_class(self.CLASS_MAP[nationality] or "assault")
	return class_tweak_data.movement.carry.CARRY_WEIGHT_MAX or 5
end

function TeamAIMovement:drop_all_carry()
	if self:is_carrying() then
		for _, unit in pairs(self._carry_units) do
			if unit and alive(unit) and unit:carry_data() then
				unit:carry_data():unlink(true)
			end
		end
	end
	self._carry_units = {}
	self:modify_carry_weight(0, true)
end

function TeamAIMovement:modify_carry_weight(current, abs)
	if current and abs then
		self._carry_weight = current
	elseif self:is_carrying() and current and not abs then
		self._carry_weight = math.round(self:get_my_carry_weight() + current)
	else
		self._carry_weight = 0
	end

	local max = self:get_my_carry_weight_limit()

	local unit_data = self._unit:unit_data()
	if unit_data and managers.hud and unit_data.teammate_panel_id and unit_data.name_label_id then
		-- update GUI
		managers.hud:set_bot_carry_weight(unit_data.teammate_panel_id, unit_data.name_label_id,
			self._carry_weight, max)
	end

	if Network:is_server() and BotsHaveFeelingsReborn.Sync then
		-- update clients
		local name = managers.criminals:character_name_by_unit(self._unit)
		BotsHaveFeelingsReborn.Sync:send_to_known_peers(BotsHaveFeelingsReborn.Sync.events.bot_carry_weight, {
			name = name,
			current = self._carry_weight,
			max = max
		})
	end
end

-- bots_secure_carried

function TeamAIMovement:secure_all_carry()
	if self:is_carrying() then
		for _, unit in pairs(self._carry_units) do
			if unit and alive(unit) then
				local carry_id = unit:carry_data():carry_id()
				local carry_tweak = tweak_data.carry[carry_id]
				unit:carry_data():unlink(true)
				if BotsHaveFeelingsReborn:GetConfigOption("bots_secure_carried") and (carry_tweak.loot_value or carry_tweak.loot_outlaw_value) then
					managers.loot:server_secure_loot(carry_id, unit:carry_data():multiplier(),
						false)
				end
				unit:set_slot(0)
			end
		end
	end
	self._carry_units = {}
	self:modify_carry_weight(0, true)
end
