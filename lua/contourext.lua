Hooks:PostHook(ContourExt, "add", "BHFR_ContourExt_add", function(self, type)
	if type == "mark_enemy" or type == "mark_enemy_damage_bonus" or type == "mark_enemy_turret" then
		local base = alive(self._unit) and self._unit:base()
		if base then
			base._bhfr_mark_t = TimerManager:game():time()
		end
	end
end)
