-- bots_can_follow_in_stealth networking workaround
-- proxy func without hard calling set_cool(false) too early

local long_distance_interaction_original = UnitNetworkHandler.long_distance_interaction

function UnitNetworkHandler:long_distance_interaction(target_unit, amount, aggressor_unit, ...)
    if self._verify_gamestate(self._gamestate_filter.any_ingame) and
        self._verify_character(target_unit) and
        self._verify_character(aggressor_unit) then
        local target_is_criminal = target_unit:in_slot(managers.slot:get_mask("criminals")) or
            target_unit:in_slot(managers.slot:get_mask("harmless_criminals"))
        local aggressor_is_criminal = aggressor_unit:in_slot(managers.slot:get_mask("criminals")) or
            aggressor_unit:in_slot(managers.slot:get_mask("harmless_criminals"))
        local brain = target_unit:brain()
        if target_is_criminal and
            aggressor_is_criminal and
            brain and
            brain.on_long_distance_interact and
            brain._current_logic and
            brain._logic_data then
            brain._current_logic.on_long_distance_interact(brain._logic_data, aggressor_unit)
            return
        end
    end

    long_distance_interaction_original(self, target_unit, amount, aggressor_unit, ...)
end
