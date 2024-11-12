-- bots_give_human_player_xp

local calculate_exp_breakdown_original = RaidExperienceManager.calculate_exp_breakdown

function RaidExperienceManager:calculate_exp_breakdown(mission_id, operation_id, success, ...)
	if managers.criminals and BotsHaveFeelingsReborn:GetConfigOption("bots_give_human_player_xp") then
		managers.criminals._count_ai_as_humans = true
	end
	local xp_breakdown = calculate_exp_breakdown_original(self, mission_id, operation_id, success, ...)
	if managers.criminals and managers.criminals._count_ai_as_humans then
		managers.criminals._count_ai_as_humans = nil
	end
	return xp_breakdown
end
