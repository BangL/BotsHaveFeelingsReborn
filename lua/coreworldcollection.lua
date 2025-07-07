-- networking

Hooks:PostHook(CoreWorldCollection, "level_transition_cleanup", "BHFR_CoreWorldCollection_level_transition_cleanup",
    function(self)
        if BotsHaveFeelingsReborn.Sync then
            BotsHaveFeelingsReborn.Sync:clear_cache()
        end
    end
)
