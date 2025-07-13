-- bots_can_catch
-- make sure bots drop bags before a bot despawns when replaced by dropin

Hooks:PreHook(GroupAIStateBase, "sync_remove_one_criminal_ai", "BHFR_GroupAIStateBase_sync_remove_one_criminal_ai",
	function(self, name, replace_with_player)
		local unit = managers.criminals:character_unit_by_name(name)
		if unit and alive(unit) then
			unit:movement():drop_all_carry()
		end
	end
)

-- shout commands

function GroupAIStateBase:_get_known_shout_by_event_id(event_id)
	if not self._shout_cache then
		-- caching all sounds we care about, as i have no clue how to inverse SoundDevice:string_to_id() at all
		self._shout_cache = {}
		local character_names = managers.criminals:character_names()
		for _, caller in ipairs(character_names) do
			local caller_short = CriminalsManager.comm_wheel_callout_from_nationality(caller)
			for _, cmd in ipairs({ "follow", "help", "wait" }) do
				local sound = "com_" .. caller_short .. "_" .. cmd
				self._shout_cache[tostring(SoundDevice:string_to_id(sound))] = {
					caller = caller,
					cmd = cmd,
					sound = sound,
				}
			end
			for _, target in ipairs(character_names) do
				local target_short = CriminalsManager.comm_wheel_callout_from_nationality(target)
				if target_short ~= caller_short then
					local sound = caller_short .. "_call_" .. target_short
					self._shout_cache[tostring(SoundDevice:string_to_id(sound))] = {
						caller = caller,
						target = target,
						sound = sound
					}
				end
			end
		end
	end

	return self._shout_cache[tostring(event_id)]
end

function GroupAIStateBase:clear_shout_buffer()
	self._shout_buffer = {}
end

function GroupAIStateBase:handle_bot_shout_by_event_id(event_id)
	if not Network:is_server() then
		return
	end
	local shout = self:_get_known_shout_by_event_id(event_id)
	if (not shout) or (type(shout) ~= "table") then
		return
	end

	local caller = shout.caller
	local target = shout.target
	local cmd = shout.cmd

	-- validate: is caller unit still player right now?
	local caller_unit = managers.criminals:character_unit_by_name(caller)
	if caller_unit and caller_unit:base() and (caller_unit:base().is_local_player or caller_unit:base().is_husk_player) then
		if target then
			-- heads-up shout detected
			if not self._shout_buffer[caller] then
				self._shout_buffer[caller] = {}
			end
			-- store target and time for a possible follow-up shout
			self._shout_buffer[caller].last_heads_up_time = TimerManager:game():time()
			self._shout_buffer[caller].last_heads_up_target = target
		elseif cmd then
			-- follow-up shout detected
			local buffer = self._shout_buffer[caller]
			if buffer then
				if (not buffer.last_heads_up_time) or ((TimerManager:game():time() - buffer.last_heads_up_time) > 3) then
					--  no heads-up shout in the last 3 seconds. ignore
					return
				end
				local nationality = target or buffer.last_heads_up_target
				local unit = managers.criminals:character_unit_by_name(nationality)
				-- validate: is target unit still a bot right now? (and still matches)
				if unit and unit:base() and unit:base()._tweak_table and (unit:base()._tweak_table == nationality) then
					self:handle_bot_shout(cmd, caller_unit, unit)
				end
			end
		end
	end
end

function GroupAIStateBase:handle_bot_shout(cmd, caller, bot)
	if not Network:is_server() then
		return
	end
	if bot:anim_data() and bot:anim_data().forced then
		log("[BHFR] warning: bot shout received but skipped! reason: bot unit is busy performing a forced animation.")
	elseif bot:brain() and bot:brain()._logic_data and bot:brain()._logic_data.objective and (bot:brain()._logic_data.objective.type == "revive") then
		log("[BHFR] warning: bot shout received but skipped! reason: bot unit is busy reviving someone.")
	else
		local whisper_mode = managers.groupai:state():whisper_mode()
		local movement = bot:movement()
		if table.contains({ "follow_me", "follow", "assistance", "help", "revive", "come" }, cmd) then
			if not whisper_mode then
				-- follow / revive (loud)
				movement:set_bhfr_mode(TeamAIMovement.bhfr_modes.vanilla, caller)
			elseif BotsHaveFeelingsReborn:GetConfigOption("bots_can_follow_in_stealth") then
				-- follow (stealth)
				movement:set_bhfr_mode(TeamAIMovement.bhfr_modes.stealth_follow, caller)
			end
		elseif table.contains({ "stop", "wait" }, cmd) then
			if BotsHaveFeelingsReborn:GetConfigOption(whisper_mode and "bots_can_follow_in_stealth" or "bots_can_wait_when_loud") then
				-- defend area
				movement:set_bhfr_mode(TeamAIMovement.bhfr_modes.defend_area, nil)
			end
		elseif cmd == "down" then
			-- from drop_all_bags shout. already handled by PlayerStandard:_get_long_distance_action, ignore here
		else
			log("[BHFR] debug info: received unimplemented bot shout: " .. tostring(cmd))
		end
	end
end

-- prevent bots from following next player if follow_unit peer is gone in stealth
local _determine_objective_for_criminal_AI_original = GroupAIStateBase._determine_objective_for_criminal_AI

function GroupAIStateBase:_determine_objective_for_criminal_AI(unit, ...)
	if managers.groupai:state():whisper_mode() then
		return unit:movement():get_bhfr_objective_defend_area()
	end

	return _determine_objective_for_criminal_AI_original(self, unit, ...)
end

-- override to disable teleport when loud wait is active


local teleport_team_ai_original = GroupAIStateBase.teleport_team_ai

function GroupAIStateBase:teleport_team_ai(...)
	if Network:is_server() and BotsHaveFeelingsReborn:GetConfigOption("bots_can_wait_when_loud") then
		local distance_treshold = tweak_data.criminals.loud_teleport_distance_treshold
		local all_criminals = managers.criminals:ai_criminals()
		local all_peers = managers.network:session():all_peers()

		for _, char_data in pairs(all_criminals) do
			local unit = char_data.unit
			local min_distance = -1
			local target_unit

			if alive(unit) and (unit:movement():bhfr_mode() ~= TeamAIMovement.bhfr_modes.defend_area) then -- added check here
				for _, peer in pairs(all_peers) do
					local peer_unit = peer:unit()

					if alive(peer_unit) then
						local player_pos = peer_unit:position()
						local distance = mvector3.distance_sq(unit:position(), player_pos)

						if min_distance < 0 or distance < min_distance then
							min_distance = distance
							target_unit = peer_unit
						end
					end
				end

				if distance_treshold < min_distance then
					local cones_to_send = TeamAILogicTravel._unit_cones(managers.player:players(), 400)
					local follow_tracker = target_unit:movement():nav_tracker()
					local dest_nav_seg_id = follow_tracker:nav_segment()
					local dest_area = self:get_area_from_nav_seg_id(dest_nav_seg_id)
					local follow_pos = follow_tracker:field_position()
					local max_near_distance = 2000
					local cover = managers.navigation:find_cover_in_nav_seg_excluding_cones(dest_area.nav_segs,
						max_near_distance, follow_pos, nil, cones_to_send)
					local target_pos = cover and cover[NavigationManager.COVER_POSITION] or
						follow_tracker:field_position()

					local action_desc = {
						body_part = 1,
						position = target_pos,
						type = "warp",
					}
					local delay = 1 + math.rand(1)

					managers.queued_tasks:queue(nil, self._do_teleport_ai, self, {
						action_desc = action_desc,
						unit = unit,
					}, delay)
				end
			end
		end
	else
		teleport_team_ai_original(self, ...)
	end
end
