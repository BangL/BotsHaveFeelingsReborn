-- bots_can_follow_in_stealth networking

Hooks:PostHook(TeamAIBrain, "on_cool_state_changed", "BHFR_TeamAIBrain_on_cool_state_changed",
    function(self, state)
        if Network:is_server() then
            local name = managers.criminals:character_name_by_unit(self._unit)
            if name then
                BotsHaveFeelingsReborn.Sync:send_to_known_peers(BotsHaveFeelingsReborn.Sync.events.bot_cool, {
                    name = name,
                    state = state,
                }, name)
            end
        end
    end
)
