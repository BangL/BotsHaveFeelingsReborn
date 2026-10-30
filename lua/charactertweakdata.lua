-- bot_weapon_*_primary: gang_member presets for NPC weapons that have none in vanilla

local _presets_original = CharacterTweakData._presets

function CharacterTweakData:_presets(...)
    local presets = _presets_original(self, ...)
    local gang_member = presets.weapon.gang_member

    -- shotgun: based on the m1912 preset
    if not gang_member.ger_geco_npc then
        gang_member.ger_geco_npc = deep_clone(gang_member.usa_m1912_npc)
        gang_member.ger_geco_npc.melee_retry_delay = presets.weapon.normal.ger_geco_npc.melee_retry_delay
    end

    -- repeater rifle: based on the garand preset
    if not gang_member.ger_kar98_npc then
        gang_member.ger_kar98_npc = deep_clone(gang_member.usa_garand_npc)
        gang_member.ger_kar98_npc.melee_retry_delay = presets.weapon.normal.ger_kar98_npc.melee_retry_delay
        gang_member.ger_kar98_npc.autofire_rounds = nil
    end

    return presets
end

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
