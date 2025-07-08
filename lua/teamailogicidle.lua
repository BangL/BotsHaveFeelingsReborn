-- bots_can_follow_in_stealth networking

local on_long_distance_interact_original = TeamAILogicIdle.on_long_distance_interact

function TeamAILogicIdle.on_long_distance_interact(data, instigator)
    if Network:is_server() and not data.unit:anim_data().forced and not (data.objective and data.objective.type == "revive") then
        local is_human_player = instigator:base().is_local_player or instigator:base().is_husk_player
        if is_human_player then
            local peer_id = instigator:network():peer():id()
            local movement = data.unit:movement()

            if managers.groupai:state():whisper_mode() and BotsHaveFeelingsReborn.Sync:peer_has_mod(peer_id) then
                if not movement:cool() then
                    movement:set_cool(true)

                    local keep_position = mvector3.copy(movement:nav_tracker():field_position())
                    data.unit:brain():set_objective({
                        type = "defend_area",
                        nav_seg = managers.navigation:get_nav_seg_from_pos(keep_position, true),
                        pos = keep_position,
                        scan = true,
                    })

                    return
                else
                    movement:set_cool(false)

                    data.unit:brain():set_objective({
                        haste = "walk",
                        called = true,
                        follow_unit = instigator,
                        scan = true,
                        type = "follow",
                        fail_clbk = callback(TeamAILogicIdle, TeamAILogicIdle, "clbk_follow_objective_failed", data),
                    })

                    return
                end
            end
        end
    end

    on_long_distance_interact_original(data, instigator)
end

function TeamAILogicIdle.clbk_follow_objective_failed(data)
    if managers.groupai:state():whisper_mode() and not data.unit:movement():cool() then
        data.unit:movement():set_cool(true)
    end
end
