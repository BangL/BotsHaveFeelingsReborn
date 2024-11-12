BotsHaveFeelingsReborn = BotsHaveFeelingsReborn or class()

BotsHaveFeelingsReborn._config_defaults_path = ModPath .. "default_config.json"
BotsHaveFeelingsReborn._config_path = SavePath .. "BotsHaveFeelingsReborn.json"
BotsHaveFeelingsReborn._config = {}
BotsHaveFeelingsReborn._config_defaults = {}

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
        if config and type(config) == "table" then
            for k, v in pairs(config) do
                self._config[k] = v
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
