-- bot revive icon: tell the movement who this bot is on its way to revive

Hooks:PostHook(TeamAIBrain, "set_objective", "BHFR_TeamAIBrain_set_objective",
    function(self)
        local movement = self._unit:movement()
        if not movement.set_bhfr_reviving then
            return
        end

        local objective = self:objective()
        local target = nil

        if objective and (objective.type == "revive") and alive(objective.follow_unit) then
            target = managers.criminals:character_name_by_unit(objective.follow_unit)
        end

        movement:set_bhfr_reviving(target)
    end
)
