-- wait modes in combat: stationary never leaves its spot, use cover only
-- takes cover close to it (the way back is handled in teamailogicidle.lua)

local function bhfr_wait_mode(data)
	local movement = alive(data.unit) and data.unit:movement()
	return movement and movement.bhfr_mode and movement:bhfr_mode()
end

local _chk_wants_to_take_cover_original = CopLogicAttack._chk_wants_to_take_cover

function CopLogicAttack._chk_wants_to_take_cover(data, my_data, ...)
	if bhfr_wait_mode(data) == TeamAIMovement.bhfr_modes.defend_area then
		return false
	end

	return _chk_wants_to_take_cover_original(data, my_data, ...)
end

local _find_cover_original = CopLogicAttack._find_cover

function CopLogicAttack._find_cover(data, my_data, threat_pos, ...)
	local near_pos = data.objective and data.objective.pos

	if near_pos and (bhfr_wait_mode(data) == TeamAIMovement.bhfr_modes.defend_cover) then
		local best_cover = my_data.best_cover

		if my_data.processing_cover_path or my_data.charge_path_search_id or
			(best_cover and CopLogicAttack._verify_follow_cover(best_cover[1], near_pos, threat_pos, 200, 1000)) then
			return
		end

		local found_cover = managers.navigation:find_cover_near_pos_1(near_pos, threat_pos, 400, 0, true)

		if found_cover then
			local better_cover = { found_cover }

			CopLogicAttack._set_best_cover(data, my_data, better_cover)

			local offset_pos, yaw = CopLogicAttack._get_cover_offset_pos(data, better_cover, threat_pos)

			if offset_pos then
				better_cover[5] = offset_pos
				better_cover[6] = yaw
			end
		end

		return
	end

	return _find_cover_original(data, my_data, threat_pos, ...)
end
