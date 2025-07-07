-- bots_can_follow_in_stealth // bots_are_undetectable

local get_attention_original = AIAttentionObject.get_attention

function AIAttentionObject:get_attention(filter, min, max, team, ...)
    if self._unit and
        managers.groupai and
        managers.groupai:state() and
        managers.groupai:state():whisper_mode() and
        BotsHaveFeelingsReborn:GetConfigOption("bots_are_undetectable") and
        managers.groupai:state():all_AI_criminals()[self._unit:key()] then
        -- bots are totally not suspicious at all in stealth!
        min = AIAttentionObject.REACT_IDLE
        max = AIAttentionObject.REACT_IDLE
    end
    return get_attention_original(self, filter, min, max, team, ...)
end
