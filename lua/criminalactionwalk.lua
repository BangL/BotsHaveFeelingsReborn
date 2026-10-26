-- improve_bot_speed // bots_slowed_by_carry

local _get_current_max_walk_speed_original = CriminalActionWalk._get_current_max_walk_speed

-- same formula as PlayerCarry:_get_max_walk_speed (weight ratio, slowest carried type wins)
function CriminalActionWalk:_bhfr_carry_speed_multiplier()
    local movement = self._unit:movement()
    local units = movement and movement._carry_units
    if not units or not movement.is_carrying or not movement:is_carrying() then
        return 1
    end

    local ratio = math.clamp(movement:get_my_carry_weight() / movement:get_my_carry_weight_limit(), 0, 1)
    local multiplier = 1
    for _, unit in pairs(units) do
        if alive(unit) and unit:carry_data() then
            local carry_tweak = tweak_data.carry[unit:carry_data():carry_id()]
            local value = tweak_data.carry:get_type_value_weighted(carry_tweak and carry_tweak.type or "normal",
                "move_speed_modifier", ratio)
            multiplier = math.min(multiplier, value or 1)
        end
    end

    return multiplier
end

function CriminalActionWalk:_get_current_max_walk_speed(...)
    local speed
    if BotsHaveFeelingsReborn:GetConfigOption("improve_bot_speed") then
        speed = CriminalActionWalk.super._get_current_max_walk_speed(self, "fwd")
    else
        speed = _get_current_max_walk_speed_original(self, ...)
    end

    if BotsHaveFeelingsReborn:GetConfigOption("bots_slowed_by_carry") then
        speed = speed * self:_bhfr_carry_speed_multiplier()
    end

    return speed
end
