-- improve_bot_speed

local _get_current_max_walk_speed_original = CriminalActionWalk._get_current_max_walk_speed

function CriminalActionWalk:_get_current_max_walk_speed(...)
    if BotsHaveFeelingsReborn:GetConfigOption("improve_bot_speed") then
        return CriminalActionWalk.super._get_current_max_walk_speed(self, "fwd")
    else
        return _get_current_max_walk_speed_original(self, ...)
    end
end
