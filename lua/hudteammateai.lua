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
    end
)
