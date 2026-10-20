-- bots_avoid_grenades: fires (molotov, thermite, flamers) are danger zones until they burn out

Hooks:PostHook(FireManager, "propagate_fire", "BHFR_FireManager_propagate_fire",
	function(self, position, tweak_id)
		local fire_tweak = self._tweak_data and self._tweak_data[tweak_id]

		if Network:is_server() and BotsHaveFeelingsReborn.Danger and position and fire_tweak then
			BotsHaveFeelingsReborn.Danger:add_static_zone(position, math.max((fire_tweak.range or 0) * 1.5, 200),
				fire_tweak.duration or 5)
		end
	end
)
