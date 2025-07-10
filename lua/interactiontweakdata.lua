Hooks:PostHook(InteractionTweakData, "_init_comwheels", "BHFR_InteractionTweakData__init_comwheels",
    function(self)
        self.bhfr_comm_wheel_original_callbacks = {}
        for _, option in ipairs(self.com_wheel.options) do
            local og_clbk = option.clbk
            option.clbk = callback(self, self, "bhfr_comm_wheel_callback", og_clbk)
        end
    end
)

function InteractionTweakData:bhfr_comm_wheel_callback(og_clbk, say_target_id, default_say_id, post_prefix,
                                                       past_prefix, waypoint_tech, ...)
    if og_clbk then
        og_clbk(say_target_id, default_say_id, post_prefix, past_prefix, waypoint_tech, ...)
    end
    if past_prefix and Network:is_server() and managers.groupai and managers.groupai:state() then
        local id = string.trim(past_prefix, "_*")
        if table.contains({ "follow", "help", "wait" }, id) then
            local player = managers.player:player_unit()
            local _, _, target = player:movement():current_state():teammate_aimed_at_by_player()
            if target and managers.groupai:state():all_AI_criminals()[target:key()] then
                managers.groupai:state():handle_bot_shout(id, player, target)
            end
        end
    end
end
