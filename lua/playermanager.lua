-- bots_can_catch

local BotCarryBags_PlayerManager_server_drop_carry = PlayerManager.server_drop_carry

function PlayerManager:server_drop_carry(carry_id, carry_multiplier, position, rotation,
										 dir, throw_distance_multiplier_upgrade_level, zipline_unit, peer, ...)
	local carry_unit = BotCarryBags_PlayerManager_server_drop_carry(self, carry_id, carry_multiplier, position, rotation,
		dir, throw_distance_multiplier_upgrade_level, zipline_unit, peer, ...)

	if BotsHaveFeelingsReborn:GetConfigOption("bots_can_catch") then
		if carry_unit
			and alive(carry_unit)
			and carry_unit:carry_data()
			and tweak_data.carry
			and not tweak_data.carry[carry_unit:carry_data():carry_id()].is_corpse then
			carry_unit:carry_data():start_bot_carry_catch()
		end
	end

	return carry_unit
end
