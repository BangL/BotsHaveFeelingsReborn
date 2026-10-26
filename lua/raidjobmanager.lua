-- bots_can_catch / monkeepers_mode (carried loot is not secured, bots drop it)

local external_end_mission_original = RaidJobManager.external_end_mission

function RaidJobManager:external_end_mission(restart_camp, is_failed, ...)
    if BotsHaveFeelingsReborn.Monkeepers then
        BotsHaveFeelingsReborn.Monkeepers:reset()
    end
    if not restart_camp and Network:is_server() and self._current_job and not is_failed then
        local _all_AI_criminals = managers.groupai:state():all_AI_criminals() or {}
        for _, data in pairs(_all_AI_criminals) do
            if data.unit and alive(data.unit) and data.unit:movement() then
                data.unit:movement():drop_all_carry() -- bags carried by bots do not count, monkeepers_mode is for that
            end
        end
    end
    external_end_mission_original(self, restart_camp, is_failed, ...)
end

local external_start_mission_clbk_original = RaidJobManager.external_start_mission_clbk

function RaidJobManager:external_start_mission_clbk(...)
    if BotsHaveFeelingsReborn.Monkeepers then
        BotsHaveFeelingsReborn.Monkeepers:reset()
    end
    return external_start_mission_clbk_original(self, ...)
end
