-- bots_can_catch ui proxy func

function HUDManager:set_bot_carry_weight(i, name_label_id, current, max)
    self._teammate_panels[i]:set_bot_carry_weight(current, max)
    local name_label = self:_get_name_label(name_label_id)
    if name_label then
        name_label:set_bot_carry_weight(current, max)
    end
end

-- bots_wait_modes ui proxy func

function HUDManager:set_bot_bhfr_mode(i, name_label_id, mode)
    local panel = self._teammate_panels[i]
    if panel and panel.set_bot_mode then
        panel:set_bot_mode(mode)
    end

    local name_label = name_label_id and self:_get_name_label(name_label_id)
    if name_label and name_label.set_bot_mode then
        name_label:set_bot_mode(mode)
    end
end

function HUDManager:set_bot_bhfr_revive(i, name_label_id, state)
    local panel = self._teammate_panels[i]
    if panel and panel.set_bot_revive then
        panel:set_bot_revive(state)
    end

    local name_label = name_label_id and self:_get_name_label(name_label_id)
    if name_label and name_label.set_bot_revive then
        name_label:set_bot_revive(state)
    end
end

function HUDManager:set_bot_respawn_timer(i, character_name)
    local panel = self._teammate_panels[i]
    if panel and panel.set_bot_respawn_timer then
        panel:set_bot_respawn_timer(character_name)
    end
end

function HUDManager:set_bot_bhfr_follow(i, name_label_id, color)
    local panel = self._teammate_panels[i]
    if panel and panel.set_bot_follow then
        panel:set_bot_follow(color)
    end

    local name_label = name_label_id and self:_get_name_label(name_label_id)
    if name_label and name_label.set_bot_follow then
        name_label:set_bot_follow(color)
    end
end
