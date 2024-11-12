-- carry

function UnitNetworkHandler:sync_ai_throw_bag(unit, carry_unit, target_unit, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end
	if alive(unit) and alive(carry_unit) then
		unit:movement():sync_throw_bag(carry_unit, target_unit)
	end
end
