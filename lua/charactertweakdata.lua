-- improve_bot_movement

local _init_russian_original = CharacterTweakData._init_russian
local _init_german_original = CharacterTweakData._init_german
local _init_british_original = CharacterTweakData._init_british
local _init_american_original = CharacterTweakData._init_american

function CharacterTweakData:_init_russian(presets, ...)
    _init_russian_original(self, presets, ...)

    if BotsHaveFeelingsReborn:GetConfigOption("improve_bot_movement") then
        self.russian.no_run_start = true
        self.russian.no_run_stop = true
        self.russian.always_face_enemy = true
        self.russian.dodge = presets.dodge.ninja
        self.russian.move_speed = presets.move_speed.lightning
    end
end

function CharacterTweakData:_init_german(presets, ...)
    _init_german_original(self, presets, ...)

    if BotsHaveFeelingsReborn:GetConfigOption("improve_bot_movement") then
        self.german.no_run_start = true
        self.german.no_run_stop = true
        self.german.always_face_enemy = true
        self.german.dodge = presets.dodge.ninja
        self.german.move_speed = presets.move_speed.lightning
    end
end

function CharacterTweakData:_init_british(presets, ...)
    _init_british_original(self, presets, ...)

    if BotsHaveFeelingsReborn:GetConfigOption("improve_bot_movement") then
        self.british.no_run_start = true
        self.british.no_run_stop = true
        self.british.always_face_enemy = true
        self.british.dodge = presets.dodge.ninja
        self.british.move_speed = presets.move_speed.lightning
    end
end

function CharacterTweakData:_init_american(presets, ...)
    _init_american_original(self, presets, ...)

    if BotsHaveFeelingsReborn:GetConfigOption("improve_bot_movement") then
        self.american.no_run_start = true
        self.american.no_run_stop = true
        self.american.always_face_enemy = true
        self.american.dodge = presets.dodge.ninja
        self.american.move_speed = presets.move_speed.lightning
    end
end
