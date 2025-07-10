-- improve_bot_aim

local init_original = CriminalsManager.init
local get_num_player_criminals_original = CriminalsManager.get_num_player_criminals

function CriminalsManager:init(...)
    if BotsHaveFeelingsReborn:GetConfigOption("improve_bot_aim") then
        local gang_weapon = tweak_data.character.presets.weapon.gang_member
        if gang_weapon then
            for _, v in pairs(gang_weapon) do
                if (#v.FALLOFF == 2) and not ((v.FALLOFF[1].dmg_mul == 7.5) and (v.FALLOFF[2].dmg_mul == 7.5)) then -- skip if 'competent bots' already did its job here
                    v.focus_delay = 0
                    v.aim_delay = { 0, 0 }
                    v.range = tweak_data.character.presets.weapon.sniper.ger_kar98_npc.range
                    v.RELOAD_SPEED = 1
                    v.spread = 5
                    v.FALLOFF = {
                        {
                            r = 1500,
                            acc = { 1, 1 },
                            dmg_mul = 5,
                            recoil = { 0.2, 0.2 },
                            mode = { 0, 0, 0, 1 }
                        },
                        {
                            r = 4500,
                            acc = { 1, 1 },
                            dmg_mul = 1,
                            recoil = { 2, 2 },
                            mode = { 0, 0, 0, 1 }
                        }
                    }
                end
            end
        end
    end
    init_original(self, ...)
end

-- bots_give_human_player_xp

function CriminalsManager:get_num_player_criminals(...)
    if self._count_ai_as_humans then -- special case for RaidExperienceManager:calculate_exp_breakdown
        local num = 0
        for _, data in pairs(self._characters) do
            if data.taken then
                num = num + 1
            end
        end
        return num
    else
        return get_num_player_criminals_original(self, ...)
    end
end
