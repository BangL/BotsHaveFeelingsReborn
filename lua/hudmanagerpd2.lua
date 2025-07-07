-- bots_can_catch

function HUDManager:set_bot_carry_weight(i, name_label_id, current, max)
    self._teammate_panels[i]:set_bot_carry_weight(current, max)
    local name_label = self:_get_name_label(name_label_id)
    if name_label then
        name_label:set_bot_carry_weight(current, max)
    end
end
