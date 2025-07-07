-- bots_can_follow_in_stealth networking

local on_long_distance_interact_original = TeamAILogicIdle.on_long_distance_interact

function TeamAILogicIdle.on_long_distance_interact(data, instigator)
    if Network:is_server() and not data.unit:anim_data().forced and not (data.objective and data.objective.type == "revive") then
        local is_human_player = instigator:base().is_local_player or instigator:base().is_husk_player
        if is_human_player then
            local peer_id = instigator:network():peer():id()
            local movement = data.unit:movement()

            if managers.groupai:state():whisper_mode() then
                if BotsHaveFeelingsReborn.Sync:peer_has_mod(peer_id) and not movement:cool() then
                    local keep_position = mvector3.copy(movement:nav_tracker():field_position())
                    movement:set_cool(true)
                    -- create custom objective and return
                    data.unit:brain():set_objective({
                        type = "stop",
                        nav_seg = managers.navigation:get_nav_seg_from_pos(keep_position, true),
                        pos = keep_position,
                        -- followup_objective = { -- FIXME?
                        --     action = {
                        --         blocks = {
                        --             action = -1,
                        --             aim = -1,
                        --             heavy_hurt = -1,
                        --             hurt = -1,
                        --             walk = -1,
                        --         },
                        --         body_part = 1,
                        --         type = "act",
                        --         variant = "crouch",
                        --     },
                        --     scan = true,
                        --     type = "act",
                        -- },
                    })
                    return
                else
                    movement:set_cool(false)
                    -- don't return here, vanilla code will create type = follow objective for us (or even type = revive, if downed)
                end
            end
        end
    end

    on_long_distance_interact_original(data, instigator)
end
