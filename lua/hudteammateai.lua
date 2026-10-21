-- bots_can_catch hud ai teammate gui panels

Hooks:PostHook(HUDTeammateAI, "init", "BHFR_HUDTeammateAI_init",
    function(self, i, teammates_panel)
        self:_create_bot_carry_weight_panel()
    end
)

function HUDTeammateAI:_create_bot_carry_weight_panel()
    self._bot_carry_weight_panel = self._right_panel:panel({
        h = HUDTeammateAI.PLAYER_NAME_H,
        name = "bot_carry_panel",
        x = 0,
        y = 0,
        visible = false,
    })

    self._bot_carry_weight_icon = self._bot_carry_weight_panel:bitmap({
        layer = 1,
        name = "bot_carry_weight_icon",
        texture = tweak_data.gui.icons[HUDNameLabel.WEIGHT_ICON].texture,
        texture_rect = tweak_data.gui.icons[HUDNameLabel.WEIGHT_ICON].texture_rect,
        h = self._bot_carry_weight_panel:h() - 2,
        w = self._bot_carry_weight_panel:h() - 2,
    })
    self._bot_carry_weight_icon:set_center_y((self._bot_carry_weight_panel:h() / 2) - 4)
    self._bot_carry_weight_icon:set_left(0)

    self._bot_carry_weight_text = self._bot_carry_weight_panel:text({
        align = "center",
        font = tweak_data.gui.fonts[HUDTeammateAI.PLAYER_NAME_FONT],
        font_size = HUDTeammateAI.PLAYER_NAME_FONT_SIZE,
        layer = 2,
        name = "bot_carry_weight_text",
        text = "0/5",
        vertical = "center",
        w = self._bot_carry_weight_panel:w(),
    })
    self._bot_carry_weight_icon:set_center_y(self._bot_carry_weight_panel:h() / 2)

    self:_fit_bot_carry_panel()
    self:_create_bot_mode_panel()
end

function HUDTeammateAI:_create_bot_mode_panel()
    self._bot_mode_icon = self._right_panel:bitmap({
        layer = 1,
        name = "bot_mode_icon",
        texture = tweak_data.gui.icons.waypoint_special_wait.texture,
        texture_rect = tweak_data.gui.icons.waypoint_special_wait.texture_rect,
        h = HUDTeammateAI.PLAYER_NAME_H - 2,
        w = HUDTeammateAI.PLAYER_NAME_H - 2,
        visible = false,
    })
    self._bot_mode_icon:set_center_y((HUDTeammateAI.PLAYER_NAME_H / 2) - 4)

    local icon = tweak_data.gui.icons.waypoint_special_health

    self._bot_revive_icon = self._right_panel:bitmap({
        layer = 1,
        name = "bot_revive_icon",
        texture = icon.texture,
        texture_rect = icon.texture_rect,
        h = HUDTeammateAI.PLAYER_NAME_H - 2,
        w = HUDTeammateAI.PLAYER_NAME_H - 2,
        visible = false,
    })
    self._bot_revive_icon:set_center_y((HUDTeammateAI.PLAYER_NAME_H / 2) - 4)

    local follow_icon = tweak_data.gui.icons.comm_wheel_follow_me

    self._bot_follow_icon = self._right_panel:bitmap({
        layer = 1,
        name = "bot_follow_icon",
        texture = follow_icon.texture,
        texture_rect = follow_icon.texture_rect,
        h = HUDTeammateAI.PLAYER_NAME_H - 2,
        w = HUDTeammateAI.PLAYER_NAME_H - 2,
        visible = false,
    })
    self._bot_follow_icon:set_center_y((HUDTeammateAI.PLAYER_NAME_H / 2) - 4)

    self._bot_respawn_text = self._right_panel:text({
        align = "left",
        font = tweak_data.gui.fonts[HUDTeammateAI.PLAYER_NAME_FONT],
        font_size = HUDTeammateAI.PLAYER_NAME_FONT_SIZE,
        layer = 1,
        name = "bot_respawn_text",
        text = "",
        vertical = "center",
        visible = false,
    })
end

-- time until the (dead) bot is respawned, counted down by the trade manager on every machine
function HUDTeammateAI:set_bot_respawn_timer(character_name)
    self._bot_respawn_name = character_name
    self._bot_respawn_text:stop()
    self._bot_respawn_text:set_visible(true)
    self._bot_respawn_text:animate(callback(self, self, "_animate_bot_respawn_timer"))
end

function HUDTeammateAI:_animate_bot_respawn_timer(text)
    while managers.trade:is_criminal_in_custody(self._bot_respawn_name) do
        local seconds = math.floor(managers.trade:respawn_delay_by_name(self._bot_respawn_name))

        -- 0 = waiting for the trade to be allowed (e.g. stealth)
        text:set_text((seconds > 0) and string.format("%d:%02d", math.floor(seconds / 60), seconds % 60) or "...")
        self:_fit_bot_carry_panel()

        local t = 0
        while t < 0.25 do
            t = t + coroutine.yield()
        end
    end

    self._bot_respawn_name = nil
    text:set_visible(false)
end

-- on its way to revive: white = somebody else, red = the local player
function HUDTeammateAI:set_bot_revive(state)
    self._bot_revive_state = state

    self._bot_revive_icon:set_color((state == "me") and Color.red or Color.white)
    self:_update_bot_icons()
end

-- follow icon in the colour of the character the bot follows
function HUDTeammateAI:set_bot_follow(color)
    self._bot_follow_color = color

    if color then
        self._bot_follow_icon:set_color(color)
    end
    self:_update_bot_icons()
end

-- icons are only shown while the bot is up
function HUDTeammateAI:_update_bot_icons()
    self._bot_follow_icon:set_visible((self._bot_follow_color ~= nil) and not self._bot_downed)
    self._bot_mode_icon:set_visible((self._bot_mode ~= nil) and not self._bot_downed)
    self._bot_revive_icon:set_visible((self._bot_revive_state ~= nil) and not self._bot_downed)
    self:_fit_bot_carry_panel()
end

-- stationary / use cover icon next to the name (and the carry weight, if shown)
function HUDTeammateAI:set_bot_mode(mode)
    local modes = TeamAIMovement.bhfr_modes
    local icon_id = (mode == modes.defend_area) and "waypoint_special_wait"
        or (mode == modes.defend_cover) and "waypoint_special_defend"
    local icon = icon_id and tweak_data.gui.icons[icon_id]

    self._bot_mode = icon and mode or nil

    if icon then
        self._bot_mode_icon:set_image(icon.texture, unpack(icon.texture_rect))
    end
    self:_update_bot_icons()
end

function HUDTeammateAI:set_bot_carry_weight(current, max)
    if current and max and (current > 0) then
        self._bot_carry_weight_text:set_text(current .. "/" .. max)
        self._bot_carry_weight_panel:set_visible(true)
        self:_fit_bot_carry_panel()
    else
        self._bot_carry_weight_panel:set_visible(false)
    end
end

function HUDTeammateAI:_fit_bot_carry_panel()
    BLT:make_fine_text(self._bot_carry_weight_text)
    self._bot_carry_weight_text:set_left(self._bot_carry_weight_icon:right())
    self._bot_carry_weight_panel:set_w(self._bot_carry_weight_text:right())
    BLT:make_fine_text(self._player_name)
    self._bot_carry_weight_panel:set_left(self._player_name:right() + 10)

    -- everything next to the name, left to right
    local x = self._bot_carry_weight_panel:visible() and self._bot_carry_weight_panel:right() or self._player_name:right()

    for _, icon in ipairs({ self._bot_mode_icon, self._bot_revive_icon, self._bot_follow_icon }) do
        if icon then
            icon:set_left(x + 10)

            if icon:visible() then
                x = icon:right()
            end
        end
    end

    if self._bot_respawn_text then
        BLT:make_fine_text(self._bot_respawn_text)
        self._bot_respawn_text:set_left(self._player_name:right() + 10)
        self._bot_respawn_text:set_center_y((HUDTeammateAI.PLAYER_NAME_H / 2) - 4)
    end
end

Hooks:PostHook(HUDTeammateAI, "set_name", "BHFR_HUDTeammateAI_set_name",
    function(self)
        self:_fit_bot_carry_panel()
    end
)

Hooks:PostHook(HUDTeammateAI, "refresh", "BHFR_HUDTeammateAI_refresh",
    function(self)
        self:_fit_bot_carry_panel()
    end
)

Hooks:PostHook(HUDTeammateAI, "reset_state", "BHFR_HUDTeammateAI_reset_state",
    function(self)
        self._bot_carry_weight_panel:set_visible(false)
        self._bot_mode = nil
        self._bot_revive_state = nil
        self._bot_downed = nil
        self._bot_follow_color = nil
        self._bot_follow_icon:set_visible(false)
        self._bot_respawn_name = nil
        self._bot_respawn_text:stop()
        self._bot_respawn_text:set_visible(false)
        self._bot_mode_icon:set_visible(false)
        self._bot_revive_icon:set_visible(false)
    end
)

Hooks:PostHook(HUDTeammateAI, "go_into_bleedout", "BHFR_HUDTeammateAI_go_into_bleedout",
    function(self)
        self._bot_downed = true
        self:_update_bot_icons()
    end
)

Hooks:PostHook(HUDTeammateAI, "on_revived", "BHFR_HUDTeammateAI_on_revived",
    function(self)
        self._bot_downed = nil
        self:_update_bot_icons()
    end
)
