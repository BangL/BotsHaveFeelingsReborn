-- bots_can_follow_in_stealth // bots_are_undetectable // bots_avoid_guards

local get_attention_original = AIAttentionObject.get_attention

-- bots_avoid_guards: guards notice a bot at half the speed they notice a player (notice progress is dt / speed_mul * notice_delay_mul)
local BOT_NOTICE_DELAY_MUL = BotsHaveFeelingsReborn.BOT_NOTICE_DELAY_MUL

-- one copy per original settings table: callers compare settings by identity (verify_attention)
local slowed_settings = setmetatable({}, { __mode = "k" })

local function slowed(settings)
    local copy = slowed_settings[settings]
    if not copy then
        copy = clone(settings)
        copy.notice_delay_mul = (settings.notice_delay_mul or 1) * BOT_NOTICE_DELAY_MUL
        slowed_settings[settings] = copy
    end

    return copy
end

-- only bots that follow the player in stealth can step out of a guard's sight; the ones that stand around (not activated, or told to wait) stay undetectable
local function bot_can_avoid(unit)
    local movement = unit:movement()

    return movement and movement.bhfr_mode and (movement:bhfr_mode() == TeamAIMovement.bhfr_modes.stealth_follow)
end

function AIAttentionObject:get_attention(filter, min, max, team, ...)
    local is_bot = self._unit and
        managers.groupai and
        managers.groupai:state() and
        managers.groupai:state():whisper_mode() and
        managers.groupai:state():all_AI_criminals()[self._unit:key()]
    local avoid = is_bot and BotsHaveFeelingsReborn:GetConfigOption("bots_avoid_guards") and bot_can_avoid(self._unit)

    if is_bot and not avoid and BotsHaveFeelingsReborn:GetConfigOption("bots_are_undetectable") then
        -- bots are totally not suspicious at all in stealth!
        min = AIAttentionObject.REACT_IDLE
        max = AIAttentionObject.REACT_IDLE
    end

    local settings = get_attention_original(self, filter, min, max, team, ...)

    if avoid and settings then
        return slowed(settings)
    end

    return settings
end
