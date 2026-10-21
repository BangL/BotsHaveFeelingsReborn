-- bot revive / follow icons: tell the movement who this bot is on its way to revive / follows

Hooks:PostHook(TeamAIBrain, "set_objective", "BHFR_TeamAIBrain_set_objective",
    function(self)
        local movement = self._unit:movement()
        if not movement.set_bhfr_reviving then
            return
        end

        local objective = self:objective()
        local revive_target, follow_target = nil, nil

        if objective and alive(objective.follow_unit) then
            local target = managers.criminals:character_name_by_unit(objective.follow_unit)

            if objective.type == "revive" then
                revive_target = target
            elseif objective.type == "follow" then
                follow_target = target
            end
        end

        movement:set_bhfr_reviving(revive_target)
        movement:set_bhfr_follow_target(follow_target)
    end
)
