-- keep the weapon of bots visible while downed (vanilla hides it via anim callback)

local function hide_equipped_unit() end

if TeamAIInventory then
    TeamAIInventory.hide_equipped_unit = hide_equipped_unit
end

if HuskTeamAIInventory then
    HuskTeamAIInventory.hide_equipped_unit = hide_equipped_unit
end

-- the m1911 npc model sits too low in the hand, the luger is fine
local M1911_OFFSET = Vector3(0, 0, 3)

local function fix_m1911(self)
    for _, selection in pairs(self._available_selections) do
        local unit = selection.unit
        if alive(unit) and not unit:base()._bhfr_m1911_fixed and unit:base()._name_id == "usa_m1911_npc" then
            unit:base()._bhfr_m1911_fixed = true
            for _, object in ipairs(unit:get_objects_by_type(Idstring("model"))) do
                object:set_local_position(object:local_position() + M1911_OFFSET)
            end
        end
    end
end

if TeamAIInventory then
    Hooks:PostHook(TeamAIInventory, "add_unit_by_name", "BHFR_TeamAIInventory_add_unit_by_name", fix_m1911)
end

if HuskTeamAIInventory then
    Hooks:PostHook(HuskTeamAIInventory, "add_unit_by_name", "BHFR_HuskTeamAIInventory_add_unit_by_name", fix_m1911)
end
