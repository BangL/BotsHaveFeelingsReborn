-- monkeepers_mode: a bot on its way with a bag job (an "act" objective) is no candidate for the game's revive SO,
-- a player would revive anyway; with a bag on its back the job pauses and goes on afterwards

local is_available_for_assignment_original = TeamAILogicTravel.is_available_for_assignment

function TeamAILogicTravel.is_available_for_assignment(data, new_objective, ...)
	local job = data.unit:movement()._bhfr_mkp

	if new_objective and new_objective.type == "revive" and job and data.objective == job.objective and
		not data.internal_data.exiting then
		return true
	end

	return is_available_for_assignment_original(data, new_objective, ...)
end

-- stealth: following goes straight to the followed player's area, not from cover to cover

local determine_destination_occupation_original = TeamAILogicTravel._determine_destination_occupation

function TeamAILogicTravel._determine_destination_occupation(data, objective, ...)
	local occupation = determine_destination_occupation_original(data, objective, ...)

	if occupation and occupation.cover and objective.type == "follow" and managers.groupai:state():whisper_mode() then
		local my_data = data.internal_data
		local dest_area = managers.groupai:state():get_area_from_nav_seg_id(my_data.coarse_path[#my_data.coarse_path][1])

		occupation = {
			pos = CopLogicTravel._get_pos_on_wall(dest_area.pos, objective.called and 600 or nil),
			type = "defend",
		}
	end

	return occupation
end

-- bots_no_unnecessary_revive

BotsHaveFeelingsReborn:BlockRevivesInProgress(TeamAILogicTravel)
