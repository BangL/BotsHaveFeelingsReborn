-- wait modes: walk back to the spot the bot was told to wait at

local mvec3_dis = mvector3.distance

local _update_original = TeamAILogicIdle.update

function TeamAILogicIdle.update(data, ...)
	local objective = data.objective
	local movement = data.unit:movement()

	if objective and objective.type == "defend_area" and objective.pos and
		movement.bhfr_is_wait_mode and movement:bhfr_is_wait_mode() and
		not data.internal_data.acting and
		(not data.bhfr_return_t or data.bhfr_return_t < data.t) and
		not movement:chk_action_forbidden("walk") and
		mvec3_dis(data.m_pos, objective.pos) > 100 then
		-- use cover: stay in cover as long as hurt
		local wounded = (movement:bhfr_mode() == TeamAIMovement.bhfr_modes.defend_cover) and
			(data.unit:character_damage():health_ratio() < 0.5)

		if not wounded then
			-- throttle, in case the spot cannot be reached
			data.bhfr_return_t = data.t + 3
			objective.in_place = nil

			TeamAILogicBase._exit_to_state(data.unit, "travel")

			return
		end
	end

	return _update_original(data, ...)
end

-- bots_no_unnecessary_revive

BotsHaveFeelingsReborn:BlockRevivesInProgress(TeamAILogicIdle)

-- bots_prioritize_marked: vanilla reads attention_data.mark_t but never sets it (and would only
-- honor it within 16 m); here a visible marked enemy (nearest first) wins at any distance
local MARK_WINDOW = 8

local _get_priority_attention_original = TeamAILogicIdle._get_priority_attention

function TeamAILogicIdle._get_priority_attention(data, attention_objects, ...)
	local best, best_dis, best_reaction, marked_found

	if BotsHaveFeelingsReborn:GetConfigOption("bots_prioritize_marked") then
		local reaction_func
		for _, attention_data in pairs(attention_objects) do
			local unit = attention_data.unit
			local base = alive(unit) and unit:base()
			local mark_t = base and base._bhfr_mark_t
			if mark_t then
				attention_data.mark_t = mark_t
				if attention_data.identified and attention_data.verified and not attention_data.pause_expire_t and
					data.t - mark_t < MARK_WINDOW then
					reaction_func = reaction_func or TeamAILogicBase._chk_reaction_to_attention_object
					local reaction = reaction_func(data, attention_data, not CopLogicAttack._can_move(data))
					local dis = mvec3_dis(data.m_pos, attention_data.m_pos)
					if reaction and reaction >= AIAttentionObject.REACT_COMBAT and (not best_dis or dis < best_dis) then
						best, best_dis, best_reaction = attention_data, dis, reaction
					end
				end
			end
		end
	end

	local target, slot, reaction = _get_priority_attention_original(data, attention_objects, ...)

	if best then
		return best, 1, best_reaction
	end

	return target, slot, reaction
end
