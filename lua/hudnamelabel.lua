-- bots_can_catch name labels above heads

HUDNameLabel.WEIGHT_ICON = "weight_icon"

Hooks:PreHook(HUDNameLabel, "init", "BHFR_HUDNameLabel_pre_init",
    function(self, hud, params)
        table.insert(HUDNameLabel.STATES, #HUDNameLabel.STATES, {
            control = "bot_carry_weight_panel",
            id = "bot_carry_weight",
        })
    end
)

Hooks:PostHook(HUDNameLabel, "init", "BHFR_HUDNameLabel_post_init",
    function(self, hud, params)
        self:_create_bot_carry_weight_panel()
    end
)

function HUDNameLabel:_create_bot_carry_weight_panel()
    self._bot_carry_weight_panel = self._object:panel({
        alpha = 0,
        layer = 5,
        name = "bot_carry_weight_panel",
        h = self._object:h(),
        w = self._object:w()
    })

    local name = self._name

    if managers.user:get_setting("capitalize_names") then
        name = utf8.to_upper(name)
    end

    self._bot_carry_character_name = self._bot_carry_weight_panel:text({
        align = "center",
        layer = 1,
        font = self.PLAYER_NAME_FONT,
        font_size = self.PLAYER_NAME_FONT_SIZE,
        h = self.PLAYER_NAME_H,
        name = "bot_carry_character_name",
        text = name,
        vertical = "center",
        w = self._bot_carry_weight_panel:w(),
    })

    self._bot_carry_character_name:set_center_x(self._bot_carry_weight_panel:w() / 2)
    self._bot_carry_character_name:set_top(0)

    self._bot_carry_weight_icon = self._bot_carry_weight_panel:bitmap({
        layer = 2,
        halign = "center",
        name = "bot_carry_weight_icon",
        texture = tweak_data.gui.icons[HUDNameLabel.WEIGHT_ICON].texture,
        texture_rect = tweak_data.gui.icons[HUDNameLabel.WEIGHT_ICON].texture_rect,
        valign = "center",
        h = self.PLAYER_NAME_H,
        w = self.PLAYER_NAME_H,
    })
    self._bot_carry_weight_icon:set_right(self._bot_carry_weight_panel:w() / 2)
    self._bot_carry_weight_icon:set_top(self._bot_carry_character_name:bottom())

    self._bot_carry_weight_text = self._bot_carry_weight_panel:text({
        align = "center",
        font = tweak_data.gui.fonts[HUDNameLabel.TIMER_FONT],
        font_size = HUDNameLabel.TIMER_FONT_SIZE,
        -- h = self._bot_carry_weight_panel:h(),
        layer = 3,
        name = "bot_carry_weight_text",
        text = "0/5",
        vertical = "center",
        w = self._bot_carry_weight_panel:w(),
    })
    BLT:make_fine_text(self._bot_carry_weight_text)
    self._bot_carry_weight_text:set_left(self._bot_carry_weight_panel:w() / 2)
    self._bot_carry_weight_text:set_top(self._bot_carry_character_name:bottom())

    self._bot_carry_weight_panel:set_h(self._bot_carry_weight_text:bottom())
end

Hooks:PostHook(HUDNameLabel, "refresh", "BHFR_HUDNameLabel_refresh",
    function(self)
        local name = self._name

        if managers.user:get_setting("capitalize_names") then
            name = utf8.to_upper(name)
        end

        self._bot_carry_character_name:set_text(name)
    end
)


function HUDNameLabel:set_bot_carry_weight(current, max)
    if current and max and (current > 0) then
        self._bot_carry_weight_text:set_text(current .. "/" .. max)
        BLT:make_fine_text(self._bot_carry_weight_text)
        self._bot_carry_weight_text:set_left(self._bot_carry_weight_panel:w() / 2)
        self:_add_active_state("bot_carry_weight")
    else
        self:_remove_active_state("bot_carry_weight")
    end
end
