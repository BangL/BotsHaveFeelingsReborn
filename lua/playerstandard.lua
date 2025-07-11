-- bots_can_carry // bots_can_follow_in_stealth shout interactions

local _get_unit_long_distance_action_original = PlayerStandard._get_unit_long_distance_action
local _get_long_distance_action_original = PlayerStandard._get_long_distance_action
local _start_action_intimidate_original = PlayerStandard._start_action_intimidate
local _do_long_distance_action_original = PlayerStandard._do_long_distance_action

local UNIT_TYPE_ENEMY = 0
local UNIT_TYPE_TEAMMATE = 2

-- proxy func, just to enable interactions on teammates in stealth
-- enemies are just included to keep their priority
function PlayerStandard:_get_unit_long_distance_action(targets_enemies, targets_civilians, targets_teammates,
                                                       only_special_enemies, targets_escorts, intimidation_amount,
                                                       primary_only, detect_only, ...)
    if managers.groupai:state():whisper_mode() and targets_teammates and
        -- only do custom stealth shouts if enabled locally and by host
        BotsHaveFeelingsReborn.Sync:GetConfigOption("bots_can_follow_in_stealth")
    then
        local char_table = {}
        local cam_fwd = self._ext_camera:forward()
        local my_head_pos = self._ext_movement:m_head_pos()
        local highlight_range = tweak_data.player.long_dis_interaction.highlight_range

        if targets_enemies then
            local enemies = managers.enemy:all_enemies()

            for _, u_data in pairs(enemies) do
                if self._unit:movement():team().foes[u_data.unit:movement():team().id] and
                    not u_data.unit:anim_data().long_dis_interact_disabled and
                    (u_data.char_tweak.priority_shout or not only_special_enemies) and
                    u_data.char_tweak.silent_priority_shout then
                    self:_add_unit_to_char_table(char_table, u_data.unit, UNIT_TYPE_ENEMY, highlight_range, false,
                        false, 0.01, my_head_pos, cam_fwd)
                end
            end
        end

        if #char_table == 0 then -- only try further if no enemies found to shout at
            for _, u_data in pairs(managers.groupai:state():all_char_criminals()) do
                local added

                if not added and
                    not u_data.unit:movement():downed() and
                    not u_data.unit:base().is_local_player and
                    not u_data.unit:anim_data().long_dis_interact_disabled then
                    self:_add_unit_to_char_table(char_table, u_data.unit, UNIT_TYPE_TEAMMATE, 100000, true, true, 0.01,
                        my_head_pos, cam_fwd)
                end
            end

            if #char_table > 0 then                                  -- only go custom call if found any team mate
                local prime_target = self:_get_interaction_target(char_table, my_head_pos, cam_fwd)
                if prime_target.unit_type == UNIT_TYPE_TEAMMATE then -- only go custom call if prime target is team mate
                    -- all conditions met until here? good, let's shout at that team mate then
                    return self:_get_long_distance_action(prime_target, char_table, intimidation_amount, primary_only,
                        detect_only)
                end
            end
        end
    end

    -- ... otherwise just go vanilla
    return _get_unit_long_distance_action_original(self, targets_enemies, targets_civilians, targets_teammates,
        only_special_enemies, targets_escorts, intimidation_amount,
        primary_only, detect_only, ...)
end

function PlayerStandard:_get_long_distance_action(prime_target, char_table, intimidation_amount, primary_only,
                                                  detect_only, ...)
    if BotsHaveFeelingsReborn.Sync:host_has_mod() and
        prime_target and
        not detect_only and
        (prime_target.unit_type == UNIT_TYPE_TEAMMATE) then
        local unit = prime_target.unit

        if managers.groupai:state():all_AI_criminals()[unit:key()] then
            local is_bot_ok = not unit:character_damage():need_revive()

            if is_bot_ok then -- skip everything if bot is down
                local whisper_mode = managers.groupai:state():whisper_mode()
                local is_caller_ok = not self._unit:character_damage():need_revive()
                local movement = unit:movement()
                local following_me = (movement:bhfr_following() == self._unit)
                local result = nil

                if not is_caller_ok then
                    -- tell bot to revive
                    result = "revive"
                elseif movement:is_carrying() and shift() and BotsHaveFeelingsReborn:GetConfigOption("shift_f_for_drop_all_carry") then
                    -- tell bot to drop bags
                    if Network:is_server() then
                        movement:drop_all_carry()
                    else
                        BotsHaveFeelingsReborn.Sync:send_to_host(BotsHaveFeelingsReborn.Sync.events.drop_all_carry, {
                            name = unit:base()._tweak_table
                        })
                    end
                    result = "down"
                elseif whisper_mode and BotsHaveFeelingsReborn:GetConfigOption("bots_can_follow_in_stealth") then
                    if BotsHaveFeelingsReborn:GetConfigOption("toggle_follow_wait_f_shouts_stealth") and following_me then
                        -- tell bot to wait in stealth
                        result = "stop"
                    else
                        -- tell bot to follow in stealth
                        result = "come"
                    end
                elseif (not whisper_mode) and BotsHaveFeelingsReborn:GetConfigOption("toggle_follow_wait_f_shouts_loud") and following_me then
                    -- tell bot to wait in loud
                    result = "stop"
                end

                if result and (result ~= "revive") then
                    return result, false, prime_target
                end
            end
        end
    end

    return _get_long_distance_action_original(self, prime_target, char_table, intimidation_amount, primary_only,
        detect_only, ...)
end

function PlayerStandard:_start_action_intimidate(t, ...)
    if not self._intimidate_t or t - self._intimidate_t > tweak_data.player.movement_state.interaction_delay then
        local voice_type, _, prime_target = self:_get_unit_long_distance_action(true, true, true, false, true)
        local interact_type, sound_name, queue_sound_name, queue_sound_suffix

        if voice_type == "revive" then
            interact_type = "cmd_get_up"
            queue_sound_suffix = "_help"
        elseif voice_type == "down" then
            interact_type = "cmd_down" -- FIXME no animation for this :(
            sound_name = "l02x_plu"    -- FIXME no sound files for this :(
        elseif voice_type == "stop" then
            interact_type = "cmd_stop" -- FIXME no animation for this :(
            queue_sound_suffix = "_wait"
        elseif voice_type == "come" then
            interact_type = "cmd_come"
            queue_sound_suffix = "_follow"
        end

        if interact_type then
            local criminal = managers.groupai:state():all_char_criminals()[prime_target.unit:key()]
            if queue_sound_suffix and criminal then
                local character
                if criminal.ai then
                    character = prime_target.unit:base()._tweak_table
                else
                    character = prime_target.unit:network():peer()._character
                end
                if character then
                    local target_char = self:get_wwise_nationality_from_nationality(character)
                    local nationality = self:get_wwise_nationality_from_nationality(managers.network:session()
                        :local_peer()._character)
                    if (target_char == nationality) and (nationality ~= "amer") then
                        target_char = "amer"
                    elseif (target_char == nationality) and (nationality == "amer") then
                        target_char = "brit"
                    end

                    if nationality == "russian" then
                        nationality = "rus"
                    end

                    sound_name = nationality .. "_call_" .. target_char
                    queue_sound_name = "com_" .. nationality .. queue_sound_suffix
                end
            end

            if sound_name then
                self:_do_long_distance_action(t, interact_type, sound_name, queue_sound_name,
                    managers.groupai:state():whisper_mode())

                if queue_sound_suffix and BotsHaveFeelingsReborn:GetConfigOption("send_comm_wheel_like_chat_messages") then
                    if queue_sound_suffix == "_follow" then
                        queue_sound_suffix = "_follow_me"
                    elseif queue_sound_suffix == "_help" then
                        queue_sound_suffix = "_assistance"
                    end

                    local target = self._unit:movement():current_state():teammate_aimed_at_by_player()
                    managers.chat:send_message(ChatManager.GAME, "Player",
                        "com_wheel_target_say" .. queue_sound_suffix .. "~" .. target)
                end

                if Network:is_server() and managers.groupai and managers.groupai:state() then
                    managers.groupai:state():handle_bot_shout(voice_type, self._unit, prime_target.unit)
                end

                if voice_type ~= "revive" then
                    return
                end
            end
        end

        return _start_action_intimidate_original(self, t, ...)
    end
end

function PlayerStandard:_do_long_distance_action(t, interact_type, sound_name, queue_sound_name, skip_alert, ...)
    -- _do_long_distance_action_original ignores queue_sound_name. lets handle it properly.
    if sound_name and queue_sound_name then
        self._intimidate_t = t

        self._unit:sound():say(sound_name, true, true)
        self._unit:sound():queue_sound("comm_wheel", queue_sound_name, nil, true)

        sound_name = nil -- tell _do_long_distance_action_original to shut up. - we got this
    end

    _do_long_distance_action_original(self, t, interact_type, sound_name, queue_sound_name, skip_alert, ...)
end
