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
