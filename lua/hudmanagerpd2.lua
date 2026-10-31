-- bots_can_catch ui proxy func

-- The bots' brains are deactivated while the game is torn down (quit, restart), long after the hud has been
-- destroyed: a call on a dead gui object is an access violation, not a lua error. Only hand out live widgets.
local function live_panel(self, i)
    local panel = self._teammate_panels[i]

    return panel and alive(panel._right_panel) and panel or nil
end

local function live_label(self, name_label_id)
    local name_label = name_label_id and self:_get_name_label(name_label_id)

    return name_label and alive(name_label._object) and name_label or nil
end

function HUDManager:set_bot_carry_weight(i, name_label_id, current, max)
    local panel = live_panel(self, i)
    if panel then
        panel:set_bot_carry_weight(current, max)
    end

    local name_label = live_label(self, name_label_id)
    if name_label then
        name_label:set_bot_carry_weight(current, max)
    end
end

-- bots_wait_modes ui proxy func

function HUDManager:set_bot_bhfr_mode(i, name_label_id, mode)
    local panel = live_panel(self, i)
    if panel and panel.set_bot_mode then
        panel:set_bot_mode(mode)
    end

    local name_label = live_label(self, name_label_id)
    if name_label and name_label.set_bot_mode then
        name_label:set_bot_mode(mode)
    end
end

function HUDManager:set_bot_bhfr_revive(i, name_label_id, state)
    local panel = live_panel(self, i)
    if panel and panel.set_bot_revive then
        panel:set_bot_revive(state)
    end

    local name_label = live_label(self, name_label_id)
    if name_label and name_label.set_bot_revive then
        name_label:set_bot_revive(state)
    end
end

function HUDManager:set_bot_respawn_timer(i, character_name)
    local panel = live_panel(self, i)
    if panel and panel.set_bot_respawn_timer then
        panel:set_bot_respawn_timer(character_name)
    end
end

function HUDManager:set_bot_bhfr_follow(i, name_label_id, color)
    local panel = live_panel(self, i)
    if panel and panel.set_bot_follow then
        panel:set_bot_follow(color)
    end

    local name_label = live_label(self, name_label_id)
    if name_label and name_label.set_bot_follow then
        name_label:set_bot_follow(color)
    end
end

function HUDManager:set_bot_bhfr_carry(i, name_label_id, state)
    local panel = live_panel(self, i)
    if panel and panel.set_bot_carry_job then
        panel:set_bot_carry_job(state)
    end

    local name_label = live_label(self, name_label_id)
    if name_label and name_label.set_bot_carry_job then
        name_label:set_bot_carry_job(state)
    end
end
