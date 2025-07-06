if not BotsHaveFeelingsReborn.Sync then
    BotsHaveFeelingsReborn.Sync = {
        msg_id = "BHFR",
        peers = { false, false, false, false },
        events = {
            handshake = "handshake",
            bot_carry_weight = "bot_carry_weight",
        },
        drop_in_cache = {},
    }

    function BotsHaveFeelingsReborn.Sync.table_to_string(tbl)
        return LuaNetworking:TableToString(tbl) or ""
    end

    function BotsHaveFeelingsReborn.Sync.string_to_table(str)
        local tbl = LuaNetworking:StringToTable(str) or ""

        for k, v in pairs(tbl) do
            tbl[k] = BotsHaveFeelingsReborn.Sync.to_original_type(v)
        end

        return tbl
    end

    function BotsHaveFeelingsReborn.Sync.to_original_type(s)
        local v = s
        if type(s) == "string" then
            if s == "nil" then
                v = nil
            elseif s == "true" or s == "false" then
                v = (s == "true")
            else
                v = tonumber(s) or s
            end
        end
        return v
    end

    function BotsHaveFeelingsReborn.Sync:send_to_peer(peer_id, event, data)
        if peer_id and peer_id ~= LuaNetworking:LocalPeerID() and event then
            local tags = {
                id = self.msg_id,
                event = event
            }

            if type(data) == "table" then
                data = self.table_to_string(data)
                tags["table"] = true
            end

            LuaNetworking:SendToPeer(peer_id, self.table_to_string(tags), data or "")
        end
    end

    function BotsHaveFeelingsReborn.Sync:send_to_host(event, data)
        self:send_to_peer(managers.network:session():server_peer():id(), event, data)
    end

    function BotsHaveFeelingsReborn.Sync:send_to_known_peers(event, data, drop_in_cache_key)
        for peer_id, known in ipairs(self.peers) do
            if known then
                if (event ~= self.events.handshake) and drop_in_cache_key then
                    self.drop_in_cache[event] = self.drop_in_cache[event] or {}
                    self.drop_in_cache[event][drop_in_cache_key] = data
                end
                self:send_to_peer(peer_id, event, data)
            end
        end
    end

    function BotsHaveFeelingsReborn.Sync:clear_cache()
        self.drop_in_cache = {}
    end

    function BotsHaveFeelingsReborn.Sync:receive(sender, tags, data)
        sender = tonumber(sender)
        if sender then
            tags = self.string_to_table(tags)
            if tags.id and tags.id == self.msg_id and not string.is_nil_or_empty(tags.event) then
                if tags.table then
                    data = self.string_to_table(data)
                else
                    data = self.to_original_type(data)
                end
                if sender and self.events[tags.event] and self[tags.event] then
                    self[tags.event](self, sender, data)
                end
            end
        end
    end

    function BotsHaveFeelingsReborn.Sync:handshake(peer_id, data)
        if Network:is_server() then
            log("[BHFR handshake] Client " .. tostring(peer_id) .. " is using BHFR.")
            -- host handshake confirmation back to client
            self:send_to_peer(peer_id, self.events.handshake)
            self:handle_drop_in(peer_id)
        else
            log("[BHFR handshake] The host is using BHFR.")
        end
        self.peers[peer_id] = true
    end

    function BotsHaveFeelingsReborn.Sync:handle_drop_in(peer_id)
        for event, cache in pairs(self.drop_in_cache) do
            for _, data in pairs(cache) do
                self:send_to_peer(peer_id, event, data)
            end
        end
    end

    function BotsHaveFeelingsReborn.Sync:reset_peer(peer_id)
        if self.peers[peer_id] then
            self.peers[peer_id] = false
        end
    end

    function BotsHaveFeelingsReborn.Sync:bot_carry_weight(peer_id, data)
        if data.name and data.current then
            local unit = managers.criminals:character_unit_by_name(data.name)
            if unit and unit:movement() and unit:movement().modify_carry_weight then
                unit:movement():modify_carry_weight(data.current, true)
            end
        end
    end
end

Hooks:Add("BaseNetworkSessionOnLoadComplete", "BHFR_BaseNetworkSessionOnLoadComplete",
    function(local_peer, id)
        if BotsHaveFeelingsReborn.Sync and LuaNetworking:IsMultiplayer() and Network:is_client() then
            -- client handshake request to host
            BotsHaveFeelingsReborn.Sync:send_to_host(BotsHaveFeelingsReborn.Sync.events.handshake)
        end
    end
)

Hooks:Add("BaseNetworkSessionOnPeerRemoved", "BHFR_BaseNetworkSessionOnPeerRemoved",
    function(peer, peer_id, reason)
        if BotsHaveFeelingsReborn.Sync then
            -- reset handshake
            BotsHaveFeelingsReborn.Sync:reset_peer(peer_id)
        end
    end
)

Hooks:Add("NetworkReceivedData", "BHFR_NetworkReceivedData",
    function(sender, tags, data)
        if BotsHaveFeelingsReborn.Sync then
            BotsHaveFeelingsReborn.Sync:receive(sender, tags, data)
        end
    end
)

Hooks:PostHook(CoreWorldCollection, "level_transition_cleanup", "BHFR_CoreWorldCollection_level_transition_cleanup",
    function(self)
        if BotsHaveFeelingsReborn.Sync then
            BotsHaveFeelingsReborn.Sync:clear_cache()
        end
    end
)
