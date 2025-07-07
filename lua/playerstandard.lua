-- bots_can_carry // bots_can_follow_in_stealth shout interactions

local _get_unit_long_distance_action_original = PlayerStandard._get_unit_long_distance_action

local UNIT_TYPE_ENEMY = 0
local UNIT_TYPE_TEAMMATE = 2

function PlayerStandard:_get_unit_long_distance_action(targets_enemies, targets_civilians, targets_teammates,
                                                       only_special_enemies, targets_escorts, intimidation_amount,
                                                       primary_only, detect_only, ...)
    if managers.groupai:state():whisper_mode() and targets_teammates and BotsHaveFeelingsReborn:GetConfigOption("bots_can_follow_in_stealth") then
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

local _get_long_distance_action_original = PlayerStandard._get_long_distance_action

function PlayerStandard:_get_long_distance_action(prime_target, char_table, intimidation_amount, primary_only,
                                                  detect_only, ...)
    if BotsHaveFeelingsReborn.Sync:host_has_mod() and
        prime_target and
        not detect_only and
        prime_target.unit_type == UNIT_TYPE_TEAMMATE then
        local unit = prime_target.unit

        if managers.groupai:state():all_AI_criminals()[unit:key()] then
            local is_ok = not unit:character_damage():need_revive()
            if is_ok then
                if unit:movement():is_carrying() and shift() then
                    if Network:is_server() then
                        -- tell bot to drop bags
                        unit:movement():drop_all_carry()

                        return "down", false, prime_target
                    else
                        -- tell server to make bot drop bags
                        -- TODO: sync a drop-request via BotsHaveFeelingsReborn.Sync

                        -- return "down", false, prime_target
                    end
                end

                local movement = prime_target.unit:movement()
                if managers.groupai:state():whisper_mode() then
                    -- tell bot to stay, in stealth
                    local cmd = movement:cool() and "come" or "stop"
                    if Network:is_server() then
                        prime_target.unit:brain()._current_logic.on_long_distance_interact(
                            prime_target.unit:brain()._logic_data, self._unit)
                    else
                        managers.network:session():send_to_host("long_distance_interaction", prime_target.unit, 0,
                            self._unit)
                    end

                    return cmd, false, prime_target
                end
            end
        end
    end

    return _get_long_distance_action_original(self, prime_target, char_table, intimidation_amount, primary_only,
        detect_only, ...)
end

local _start_action_intimidate_original = PlayerStandard._start_action_intimidate

function PlayerStandard:_start_action_intimidate(t, ...)
    if not self._intimidate_t or t - self._intimidate_t > tweak_data.player.movement_state.interaction_delay then
        local skip_alert = managers.groupai:state():whisper_mode()
        local voice_type, _, prime_target = self:_get_unit_long_distance_action(true, true, true, false, true)
        local interact_type, sound_name, queue_sound_name, queue_sound_suffix

        if voice_type == "down" then
            interact_type = "cmd_down" -- FIXME no animation for this :(
            sound_name = "l02x_sin"    -- FIXME no sound files for this :(
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
                    if target_char == nationality and nationality ~= "amer" then
                        target_char = "amer"
                    elseif target_char == nationality and nationality == "amer" then
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
                self:_do_long_distance_action(t, interact_type, sound_name, queue_sound_name, skip_alert)

                return true
            end
        end

        return _start_action_intimidate_original(self, t, ...)
    end
end

local _do_long_distance_action_original = PlayerStandard._do_long_distance_action
function PlayerStandard:_do_long_distance_action(t, interact_type, sound_name, queue_sound_name, skip_alert, ...)
    -- _do_long_distance_action_original ignores queue_sound_name. lets handle it properly.
    if sound_name and queue_sound_name then
        self._intimidate_t = t

        self:say_line(sound_name, queue_sound_name, skip_alert)
        sound_name = nil -- tell _do_long_distance_action_original to shut up. - we got this
    end

    _do_long_distance_action_original(self, t, interact_type, sound_name, queue_sound_name, skip_alert, ...)
end
