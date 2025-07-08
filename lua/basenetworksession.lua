-- networking

if not BotsHaveFeelingsReborn.Sync then
    BotsHaveFeelingsReborn.Sync = {
        msg_id = "BHFR",
        peers = { false, false, false, false },
        events = {
            handshake = "handshake",
            rejected = "rejected",
            bot_carry_weight = "bot_carry_weight",
            bot_cool = "bot_cool",
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

    function BotsHaveFeelingsReborn.Sync:send_to_known_peers(event, data, cache_key)
        if (event ~= self.events.handshake and event ~= event ~= self.events.rejected) and cache_key then
            self.drop_in_cache[cache_key] = self.drop_in_cache[cache_key] or {}
            self.drop_in_cache[cache_key][event] = data
        end
        for peer_id, known in ipairs(self.peers) do
            if known and peer_id ~= managers.network:session():local_peer():id() then
                self:send_to_peer(peer_id, event, data)
            end
        end
    end

    function BotsHaveFeelingsReborn.Sync:peer_has_mod(peer_id)
        return (peer_id == managers.network:session():local_peer():id()) or
            (Network:is_server() and (peer_id == 1)) or
            self.peers[peer_id]
    end

    function BotsHaveFeelingsReborn.Sync:host_has_mod()
        return self:peer_has_mod(1)
    end

    function BotsHaveFeelingsReborn.Sync:clear_cache()
        self.drop_in_cache = {}
    end

    function BotsHaveFeelingsReborn.Sync:handle_drop_in(peer_id)
        for bot_name, cache in pairs(self.drop_in_cache) do
            local bot_data = managers.criminals:character_data_by_name(bot_name)
            if bot_data and bot_data.ai then
                for event, cache_data in pairs(cache) do
                    self:send_to_peer(peer_id, event, cache_data)
                end
            end
        end
    end

    function BotsHaveFeelingsReborn.Sync:reset_peer(peer_id)
        if self.peers[peer_id] then
            self.peers[peer_id] = false
        end
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
                if self.events[tags.event] and self[tags.event] then
                    self[tags.event](self, sender, data)
                elseif tags.event ~= self.events.rejected then
                    self:send_to_peer(sender, self.events.rejected, "event unknown.")
                end
            end
        end
    end

    -- server event handlers

    function BotsHaveFeelingsReborn.Sync:handshake(peer_id, data)
        if Network:is_server() then
            log("[BHFR handshake] Client " .. tostring(peer_id) .. " is using BHFR.")
            -- host handshake confirmation back to client
            self:send_to_peer(peer_id, self.events.handshake)
            -- self:handle_drop_in(peer_id) -- not here! here is way too early!! see BHFR_BaseNetworkSession_on_peer_sync_complete
        else
            log("[BHFR handshake] The host is using BHFR.")
        end
        self.peers[peer_id] = true
    end

    -- client event handlers

    function BotsHaveFeelingsReborn.Sync:bot_carry_weight(peer_id, data)
        if peer_id ~= 1 then -- we only listen to the server!
            self:send_to_peer(peer_id, self.events.rejected, "only the host is allowed to send this.")
            return
        end
        if data.name and data.current then
            local unit = managers.criminals:character_unit_by_name(data.name)
            if unit and unit:movement() and unit:movement().modify_carry_weight then
                unit:movement():modify_carry_weight(data.current, true)
            end
        end
    end

    function BotsHaveFeelingsReborn.Sync:bot_cool(peer_id, data)
        if peer_id ~= 1 then -- we only listen to the server!
            self:send_to_peer(peer_id, self.events.rejected, "only the host is allowed to send this.")
            return
        end
        if data.name and data.state ~= nil then
            local unit = managers.criminals:character_unit_by_name(data.name)
            if unit then
                if unit:movement() and unit:movement().cool and (unit:movement():cool() ~= data.state) then
                    unit:movement():set_cool(data.state)
                end
            else
                -- unit was null, cache for TeamAIDamage
                self.drop_in_cache[data.name] = self.drop_in_cache[data.name] or {}
                self.drop_in_cache[data.name][self.events.bot_cool] = data
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

Hooks:PostHook(BaseNetworkSession, "on_peer_sync_complete", "BHFR_BaseNetworkSession_on_peer_sync_complete",
    function(self, peer, peer_id)
        if BotsHaveFeelingsReborn.Sync and Network:is_server() and self._local_peer and peer:ip_verified() then
            -- send cached data to dop in client
            BotsHaveFeelingsReborn.Sync:handle_drop_in(peer_id)
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
