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

-- bots_no_unnecessary_revive

BotsHaveFeelingsReborn:BlockRevivesInProgress(TeamAILogicTravel)
