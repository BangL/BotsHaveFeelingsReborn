-- bots_can_catch

BotsHaveFeelingsReborn.NO_CATCH_CARRY_IDS = {
	corpse_body = true,
	german_spy_body = true,
	ladder_4m = true,
	-- plank = true,
	parachute = true,
	turret_m2_gun = true,
}

local BotCarryBags_PlayerManager_server_drop_carry = PlayerManager.server_drop_carry

function PlayerManager:server_drop_carry(carry_id, carry_multiplier, position, rotation,
										 dir, throw_distance_multiplier_upgrade_level, zipline_unit, peer, ...)
	local carry_unit = BotCarryBags_PlayerManager_server_drop_carry(self, carry_id, carry_multiplier, position, rotation,
		dir, throw_distance_multiplier_upgrade_level, zipline_unit, peer, ...)

	if BotsHaveFeelingsReborn:GetConfigOption("bots_can_catch") then
		if carry_unit
			and alive(carry_unit)
			and carry_unit:carry_data()
			and tweak_data.carry then
			if not BotsHaveFeelingsReborn.NO_CATCH_CARRY_IDS[carry_unit:carry_data():carry_id()] then
				carry_unit:carry_data():start_bot_carry_catch()
			end
		end
	end

	if peer and not zipline_unit and BotsHaveFeelingsReborn.Monkeepers then
		BotsHaveFeelingsReborn.Monkeepers:on_player_throw(carry_unit, carry_id, peer, position, dir,
			throw_distance_multiplier_upgrade_level)
	end

	return carry_unit
end
