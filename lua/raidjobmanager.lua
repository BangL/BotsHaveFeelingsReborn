-- bots_can_catch / bots_secure_carried

local external_end_mission_original = RaidJobManager.external_end_mission

function RaidJobManager:external_end_mission(restart_camp, is_failed, ...)
    if not restart_camp and Network:is_server() and self._current_job and not is_failed then
        local _all_AI_criminals = managers.groupai:state():all_AI_criminals() or {}
        for _, data in pairs(_all_AI_criminals) do
            if data.unit and alive(data.unit) and data.unit:movement() then
                data.unit:movement():secure_all_carry()
            end
        end
    end
    external_end_mission_original(self, restart_camp, is_failed, ...)
end
