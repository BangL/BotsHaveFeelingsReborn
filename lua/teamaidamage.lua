local init_original = TeamAIDamage.init
local _apply_damage_original = TeamAIDamage._apply_damage
local _regenerated_original = TeamAIDamage._regenerated
local friendly_fire_hit_original = TeamAIDamage.friendly_fire_hit

-- double_bot_health

function TeamAIDamage:init(unit, ...)
    init_original(self, unit, ...)

    -- apply doubled bot stealth if enabled by host & ignore local setting if client
    if BotsHaveFeelingsReborn.Sync:GetConfigOption("double_bot_health") then
        self._unit = unit
        self._char_tweak = tweak_data.character[unit:base()._tweak_table]
        local damage_tweak = self._char_tweak.damage

        self._HEALTH_INIT = 2 * damage_tweak.HEALTH_INIT

        self._HEALTH_TOTAL = self._HEALTH_INIT
        self._HEALTH_TOTAL_PERCENT = self._HEALTH_TOTAL / 100
        self._health = self._HEALTH_INIT
        self._health_ratio = self._health / self._HEALTH_INIT
    end
end

-- bot_hurt_sound

function TeamAIDamage:_apply_damage(attack_data, result, force, ...)
    local damage_percent, health_subtracted = _apply_damage_original(self, attack_data, result, force, ...)
    if BotsHaveFeelingsReborn:GetConfigOption("bot_hurt_sound") then
        local data = self._unit:brain()._logic_data
        if data then
            local my_data = data.internal_data
            if not my_data.said_hurt then
                if self._health_ratio <= 0.2 then
                    if not self:need_revive() then
                        my_data.said_hurt = true
                        self._unit:sound():say("g80x_plu", true)
                    end
                end
            end
        end
    end
    return damage_percent, health_subtracted
end

function TeamAIDamage:_regenerated(...)
    local data = self._unit:brain()._logic_data
    if data then
        local my_data = data.internal_data
        if my_data.said_hurt then
            my_data.said_hurt = false
        end
    end
    return _regenerated_original(self, ...)
end

-- improve_bot_movement: skip dodge animation through ff

function TeamAIDamage:friendly_fire_hit(...)
    if BotsHaveFeelingsReborn:GetConfigOption("improve_bot_movement") then
        return
    else
        friendly_fire_hit_original(self, ...)
    end
end

-- enable crouch for stealth follow and defend area

function TeamAIDamage:set_crouch_move(state)
    self._char_tweak.crouch_move = state
end

-- a bot that is down or dead is not on its way to anybody and no longer waits
-- (a revived bot starts over with the vanilla follow behaviour)

local function clear_bhfr_reviving(self)
    local movement = self._unit:movement()
    if movement and movement.set_bhfr_reviving then
        movement:set_bhfr_reviving(nil)

        if movement:bhfr_is_wait_mode() then
            movement:set_bhfr_mode(TeamAIMovement.bhfr_modes.vanilla, nil)
        end
    end
end

Hooks:PostHook(TeamAIDamage, "_check_bleed_out", "BHFR_TeamAIDamage_check_bleed_out",
    function(self)
        if self._bleed_out then
            clear_bhfr_reviving(self)
        end
    end
)

Hooks:PostHook(TeamAIDamage, "_die", "BHFR_TeamAIDamage_die", clear_bhfr_reviving)
