-- voice line based server handling of F / comm wheel calls, when targeting bots

local say_original = UnitNetworkHandler.say
function UnitNetworkHandler:say(caller_unit, event_id, sender, ...)
    if alive(caller_unit) and
        self._verify_gamestate(self._gamestate_filter.any_ingame) and
        Network:is_server() then
        local peer = self._verify_sender(sender)
        -- verify: is sender == caller?
        if peer and caller_unit:network() and caller_unit:network():peer() and (peer:id() == caller_unit:network():peer():id()) then
            -- verify: is caller/sender a human player (not a bot)?
            if caller_unit:base() and (caller_unit:base().is_local_player or caller_unit:base().is_husk_player) then
                if managers.groupai and managers.groupai:state() then
                    managers.groupai:state():handle_bot_shout_by_event_id(event_id)
                end
            end
        end
    end

    say_original(self, caller_unit, event_id, sender, ...)
end
