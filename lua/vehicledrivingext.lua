-- bots_can_catch
-- force bots to drop all bags before entering vehicles

Hooks:PreHook(VehicleDrivingExt, "on_team_ai_enter", "BHFR_VehicleDrivingExt_on_team_ai_enter",
    function(self, ai_unit)
        if ai_unit:movement().vehicle_seat.occupant ~= ai_unit and self:find_empty_seat() and ai_unit:movement().drop_all_carry then
            ai_unit:movement():drop_all_carry()
        end
    end
)
