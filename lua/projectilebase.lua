-- bots_avoid_grenades: every live grenade is a danger zone

Hooks:PostHook(ProjectileBase, "init", "BHFR_ProjectileBase_init",
	function(self, unit)
		if not Network:is_server() or not BotsHaveFeelingsReborn.Danger then
			return
		end

		local tweak = self.name_id and tweak_data.projectiles[self.name_id]

		-- explosives only (no decoys, ammo bags, ...)
		if tweak and tweak.is_a_grenade and ((tweak.damage or 0) >= 100) then
			BotsHaveFeelingsReborn.Danger:add_unit_zone(unit, self._range or tweak.range or 500,
				self._init_timer or tweak.init_timer or 4.5)
		end
	end
)
