-- networking

if not BotsHaveFeelingsReborn.Sync then
    BotsHaveFeelingsReborn.Sync = {
        msg_id = "BHFR",
        peers = { false, false, false, false },
        events = {
            handshake = "handshake",
            rejected = "rejected",
            bot_carry_weight = "bot_carry_weight",
            bot_bhfr_mode = "bot_bhfr_mode",
            drop_all_carry = "drop_all_carry",
        },
        valid = {
            server = 0,
            client = 1,
            both = 2,
        },
        drop_in_cache = {},
        settings_cache = {},
        protocol_version = 2,
        synced_settings = {
            "bots_can_follow_in_stealth",
            "double_bot_health"
        },
    }

    function BotsHaveFeelingsReborn.Sync.table_to_string(tbl)
        return LuaNetworking:TableToString(tbl) or ""
    end

    function BotsHaveFeelingsReborn.Sync.string_to_table(str)
        local tbl = LuaNetworking:StringToTable(str) or {}

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
            elseif (s == "true") or (s == "false") then
                v = (s == "true")
            else
                v = tonumber(s) or s
            end
        end
        return v
    end

    function BotsHaveFeelingsReborn.Sync:_validate(valid_on, valid_from, needs_name, peer_id, data)
        if (valid_on == self.valid.server) and Network:is_client() then
            self:send_to_peer(peer_id, self.events.rejected, "clients cannot handle this.")
            return false
        end
        if (valid_on == self.valid.client) and Network:is_server() then
            self:send_to_peer(peer_id, self.events.rejected, "the host cannot handle this.")
            return false
        end
        if (valid_from == self.valid.server) and (peer_id ~= 1) then
            self:send_to_peer(peer_id, self.events.rejected, "only the host is allowed to send this.")
            return false
        end
        if (valid_from == self.valid.client) and (peer_id == 1) then
            self:send_to_peer(peer_id, self.events.rejected, "only clients are allowed to send this.")
            return false
        end
        if needs_name and ((not data) or (type(data) ~= "table") or (not data.name) or (data.name == "")) then
            self:send_to_peer(peer_id, self.events.rejected, "data must be a table and contain a filled name field.")
            return false
        end
        return true
    end

    function BotsHaveFeelingsReborn.Sync:send_to_peer(peer_id, event, data)
        if peer_id and (peer_id ~= LuaNetworking:LocalPeerID()) and event then
            local tags = {
                id = self.msg_id,
                event = event
            }

            if type(data) == "table" then
                data = self.table_to_string(data)
            end
            LuaNetworking:SendToPeer(peer_id, self.table_to_string(tags), data or "")
        end
    end

    function BotsHaveFeelingsReborn.Sync:send_to_host(event, data)
        self:send_to_peer(managers.network:session():server_peer():id(), event, data)
    end

    function BotsHaveFeelingsReborn.Sync:send_to_known_peers(event, data)
        if (event ~= self.events.handshake) and (event ~= self.events.rejected) then
            self:cache(event, data)
        end
        for peer_id, known in ipairs(self.peers) do
            if known and (peer_id ~= managers.network:session():local_peer():id()) then
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

    function BotsHaveFeelingsReborn.Sync:clear_drop_in_cache()
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
            if tags.id and (tags.id == self.msg_id) and not string.is_nil_or_empty(tags.event) then
                data = self.string_to_table(data)
                if self.events[tags.event] and self[tags.event] then
                    self[tags.event](self, sender, data)
                elseif tags.event ~= self.events.rejected then
                    self:send_to_peer(sender, self.events.rejected, "event unknown.")
                end
            end
        end
    end

    function BotsHaveFeelingsReborn.Sync:cache(event, data)
        if (type(data) ~= "table") or (not data.name) then
            log("[BHFR Error] synced/cached data must be a table and contain a name field.")
            return
        end
        self.drop_in_cache[data.name] = self.drop_in_cache[data.name] or {}
        self.drop_in_cache[data.name][event] = data
    end

    function BotsHaveFeelingsReborn.Sync:GetConfigOption(name, host_only)
        return (Network:is_server() or (BotsHaveFeelingsReborn.Sync:host_has_mod() and self.settings_cache[name]))
            and (host_only or BotsHaveFeelingsReborn:GetConfigOption(name))
    end

    -- bidirectional event handlers

    function BotsHaveFeelingsReborn.Sync:handshake(peer_id, data)
        if not self:_validate(self.valid.both, self.valid.both, false, peer_id, data) then
            return
        end

        if tostring(data.version) ~= tostring(self.protocol_version) then
            log("[BHFR handshake] received handshake, but wrong protocol version. skipping. local version: " ..
                tostring(self.protocol_version) .. ", remote version: " .. tostring(data.version))
            return
        end

        if Network:is_server() then
            log("[BHFR handshake] Client " .. tostring(peer_id) .. " is using compatible BHFR version.")
            -- host handshake confirmation back to client, including server protocol version and synced settings
            local host_data = { version = self.protocol_version }
            for _, option_id in ipairs(self.synced_settings) do
                host_data[option_id] = BotsHaveFeelingsReborn:GetConfigOption(option_id)
            end
            self:send_to_peer(peer_id, self.events.handshake, host_data)
        else
            log("[BHFR handshake] The host is using compatible BHFR version.")
            self.settings_cache = data
        end
        self.peers[peer_id] = true
    end

    -- client -> server event handlers

    function BotsHaveFeelingsReborn.Sync:drop_all_carry(peer_id, data)
        if not self:_validate(self.valid.server, self.valid.client, true, peer_id, data) then
            return
        end
        if data.name then
            local unit = managers.criminals:character_unit_by_name(data.name)
            if unit and unit:movement() and unit:movement().is_carrying and unit:movement():is_carrying() then
                -- tell bot to drop bags
                unit:movement():drop_all_carry()
            end
        end
    end

    -- server -> client event handlers

    function BotsHaveFeelingsReborn.Sync:bot_carry_weight(peer_id, data)
        if not self:_validate(self.valid.client, self.valid.server, true, peer_id, data) then
            return
        end
        if data.name and data.current then
            local unit = managers.criminals:character_unit_by_name(data.name)
            if unit then
                if unit:movement() and unit:movement().modify_carry_weight then
                    unit:movement():modify_carry_weight(data.current, data.max, true)
                end
            else
                -- unit was null, cache for TeamAIMovement
                self:cache(self.events.bot_carry_weight, data)
            end
        end
    end

    function BotsHaveFeelingsReborn.Sync:bot_bhfr_mode(peer_id, data)
        if not self:_validate(self.valid.client, self.valid.server, true, peer_id, data) then
            return
        end
        if data.name and data.mode then
            local unit = managers.criminals:character_unit_by_name(data.name)
            if unit then
                if unit:movement() and unit:movement().set_bhfr_mode then
                    unit:movement():set_bhfr_mode(data.mode, data.following)
                end
            else
                -- unit was null, cache for TeamAIMovement
                self:cache(self.events.bot_bhfr_mode, data)
            end
        end
    end
end

Hooks:Add("BaseNetworkSessionOnLoadComplete", "BHFR_BaseNetworkSessionOnLoadComplete",
    function(local_peer, id)
        if BotsHaveFeelingsReborn.Sync and LuaNetworking:IsMultiplayer() and Network:is_client() then
            -- client handshake request to host
            BotsHaveFeelingsReborn.Sync:send_to_host(BotsHaveFeelingsReborn.Sync.events.handshake,
                { version = BotsHaveFeelingsReborn.Sync.protocol_version })
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
