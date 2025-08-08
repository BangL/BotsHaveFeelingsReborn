local default_weapon_name_original = TeamAIBase.default_weapon_name
function TeamAIBase:default_weapon_name(slot, ...)
    local loadout = tweak_data.character[self._tweak_table].loadout

    if loadout then
        -- get weapon from server (ignore local setting if client)
        local index = BotsHaveFeelingsReborn.Sync:GetConfigOption("bot_weapon_" .. self._tweak_table .. "_primary")
        if index then
            loadout.primary = BotsHaveFeelingsReborn.BOT_WEAPONS_PRIMARY[index].weapon
        end
    end

    return default_weapon_name_original(self, slot, ...)
end
