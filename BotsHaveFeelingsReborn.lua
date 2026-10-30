BotsHaveFeelingsReborn = BotsHaveFeelingsReborn or class()

BotsHaveFeelingsReborn._config_defaults_path = ModPath .. "default_config.json"
BotsHaveFeelingsReborn._config_path = SavePath .. "BotsHaveFeelingsReborn.json"
BotsHaveFeelingsReborn._config = {}
BotsHaveFeelingsReborn._config_defaults = {}

BotsHaveFeelingsReborn.BOT_WEAPONS_PRIMARY = {
    { id = "ger_mp38_npc",   weapon = Idstring("units/vanilla/weapons/wpn_npc_ger_mp38/wpn_npc_ger_mp38") },
    { id = "ger_stg44_npc",  weapon = Idstring("units/vanilla/weapons/wpn_npc_ger_stg44/wpn_npc_ger_stg44") },
    { id = "thompson_npc",   weapon = Idstring("units/vanilla/weapons/wpn_npc_smg_thompson/wpn_npc_smg_thompson") },
    { id = "usa_garand_npc", weapon = Idstring("units/vanilla/weapons/wpn_npc_usa_garand/wpn_npc_usa_garand") },
    { id = "ger_geco_npc",   weapon = Idstring("units/vanilla/weapons/wpn_npc_ger_geco/wpn_npc_ger_geco") },
    { id = "ger_kar98_npc",  weapon = Idstring("units/vanilla/weapons/wpn_npc_ger_k98/wpn_npc_ger_k98") },
    -- usa_m1912_npc: invisible, the vanilla model is 1/100 of the size of the other npc weapons
    -- { id = "usa_m1912_npc",  weapon = Idstring("units/vanilla/weapons/wpn_npc_usa_m1912/wpn_npc_usa_m1912") },
}

-- secondary slot: used in stealth and while downed
BotsHaveFeelingsReborn.BOT_WEAPONS_SECONDARY = {
    { id = "ger_luger_npc", weapon = Idstring("units/vanilla/weapons/wpn_npc_ger_luger/wpn_npc_ger_luger") },
    { id = "usa_m1911_npc", weapon = Idstring("units/vanilla/weapons/wpn_npc_usa_m1911/wpn_npc_usa_m1911") },
}

-- throwables a bot can be given (id = loc key suffix, projectile = tweak_data.projectiles entry)
BotsHaveFeelingsReborn.BOT_GRENADES = {
    { id = "grenade_none" },
    { id = "grenade_concrete", projectile = "concrete" },
    { id = "grenade_d343",     projectile = "d343" },
    { id = "grenade_mills",    projectile = "mills" },
    { id = "grenade_m24",      projectile = "m24" },
    { id = "grenade_betty",    projectile = "betty" },
}

-- Settings the host dictates: the client ignores its own copy of these and uses
-- the value from the handshake. Ids are config keys, used verbatim with
-- GetConfigOption(), so each one has to exist in default_config.json.
BotsHaveFeelingsReborn.SYNCED_SETTINGS = {
    "bots_can_follow_in_stealth",
    "wait_modes",
    "double_bot_health",
    "bot_weapon_russian_primary",
    "bot_weapon_german_primary",
    "bot_weapon_british_primary",
    "bot_weapon_american_primary",
    "bot_weapon_russian_secondary",
    "bot_weapon_german_secondary",
    "bot_weapon_british_secondary",
    "bot_weapon_american_secondary",
}

function BotsHaveFeelingsReborn:SaveConfig()
    local file = io.open(self._config_path, "w+")
    if file then
        file:write(json.encode(self._config))
        file:close()
    end
end

function BotsHaveFeelingsReborn:LoadConfig()
    self._config = clone(self._config_defaults)
    local file = io.open(self._config_path, "r")
    if file then
        local config = json.decode(file:read("*all"))
        file:close()
        if config and (type(config) == "table") then
            for k, v in pairs(config) do
                self._config[k] = v
            end
            -- "Spring Mine" (betty) was removed from BOT_GRENADES: shift saved indices once
            if not config.grenades_migrated then
                for _, nationality in ipairs({ "russian", "german", "british", "american" }) do
                    local key = "bot_grenade_" .. nationality
                    local idx = tonumber(config[key])
                    if idx then
                        self._config[key] = (idx > 3) and (idx - 1) or idx
                    end
                end
                self._config.grenades_migrated = true
            end
        end
    end
end

function BotsHaveFeelingsReborn:GetConfigOption(id)
    return self._config[id]
end

function BotsHaveFeelingsReborn:SetConfigOption(id, value)
    if self._config[id] ~= value then
        self._config[id] = value
        return true
    end

    return false
end

function BotsHaveFeelingsReborn:LoadConfigDefaults()
    local default_file = io.open(self._config_defaults_path)
    if default_file then
        self._config_defaults = json.decode(default_file:read("*all"))
        default_file:close()
    end
end

BotsHaveFeelingsReborn:LoadConfigDefaults()
BotsHaveFeelingsReborn:LoadConfig()

-- bots_no_unnecessary_revive: set by ReviveInteractionExt (see interactionext.lua)
-- the timeout keeps a revive that never got interrupted (reviver left) from
-- blocking the bots forever
function BotsHaveFeelingsReborn:IsBeingRevived(unit)
    local interaction = alive(unit) and unit:interaction()
    local t = interaction and interaction._bhfr_revive_t

    return t and ((TimerManager:game():time() - t) < (tweak_data.interaction:get_interaction("revive").timer + 3)) or false
end

-- bots refuse new revive objectives for a unit somebody is already reviving
function BotsHaveFeelingsReborn:BlockRevivesInProgress(logic)
    local is_available_for_assignment_original = logic.is_available_for_assignment

    function logic.is_available_for_assignment(data, new_objective, ...)
        if new_objective and (new_objective.type == "revive") and
            BotsHaveFeelingsReborn:GetConfigOption("bots_no_unnecessary_revive") and
            BotsHaveFeelingsReborn:IsBeingRevived(new_objective.follow_unit) then
            return false
        end

        return is_available_for_assignment_original(data, new_objective, ...)
    end
end

-- A synced setting that is missing from default_config.json never makes it into
-- the handshake data and so never reaches a client - without a word otherwise.
for _, option_id in ipairs(BotsHaveFeelingsReborn.SYNCED_SETTINGS) do
    if BotsHaveFeelingsReborn._config_defaults[option_id] == nil then
        log("[BHFR] unknown synced setting \"" .. tostring(option_id) .. "\", it can never be synced.")
    end
end
