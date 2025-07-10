-- networking

Hooks:PostHook(CoreWorldCollection, "level_transition_cleanup", "BHFR_CoreWorldCollection_level_transition_cleanup",
    function(self)
        if BotsHaveFeelingsReborn.Sync then
            BotsHaveFeelingsReborn.Sync:clear_drop_in_cache()
        end
        if managers.groupai and managers.groupai:state() then
            managers.groupai:state():clear_shout_buffer()
        end
    end
)
