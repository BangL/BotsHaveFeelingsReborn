-- grenades
--TODO: rework

local mvec3_angle = mvector3.angle
local mvec3_norm = mvector3.normalize
local projectile_id = BlackMarketTweakData:get_index_from_projectile_id("d343")

Hooks:PreHook(TeamAILogicAssault, "update", "BHFR_TeamAILogicAssault_update", function(data)
	if Network:is_server() and BotsHaveFeelingsReborn:GetConfigOption("bots_throw_grenades") then
		local t = TimerManager:game():time()
		if not TeamAILogicAssault._conc_t or TeamAILogicAssault._conc_t + 5 < t then
			TeamAILogicAssault._conc_t = t
			local enemy_slotmask = managers.slot:get_mask("enemies")
			local target_unit, target_dis
			local close_enemies = 0
			local crim_mov = data.unit:movement()
			local from_pos = crim_mov:m_head_pos()
			local look_vec = crim_mov:m_rot():y()
			local detected_obj = data.detected_attention_objects
			for _, u_char in pairs(detected_obj) do
				if u_char.identified then
					local unit = u_char.unit
					if unit:in_slot(enemy_slotmask) then
						if u_char.verified then
							local dis = u_char.verified_dis
							if dis <= 8000 then
								local vec = u_char.m_head_pos - from_pos
								if mvec3_angle(vec, look_vec) <= 90 then
									local tweak_table = unit:base()._tweak_table
									if tweak_table then
										close_enemies = close_enemies + 1
										if close_enemies >= 3 then
											if not target_dis or target_dis < dis then
												target_unit = unit
												target_dis = dis
											end
										end
									end
								end
							end
						end
					end
				end
			end
			if target_unit then
				local mvec_spread_direction = target_unit:movement():m_head_pos() - from_pos
				mvec3_norm(mvec_spread_direction)
				local cc_unit = ProjectileBase.spawn(projectile_id, from_pos, Rotation())
				if cc_unit then
					crim_mov:play_redirect("throw_grenade")
					managers.network:session():send_to_peers_synched("play_distance_interact_redirect", data.unit,
						"throw_grenade")
					cc_unit:base():throw({ dir = mvec_spread_direction, owner = data.unit })
				end
			end
		end
	end
end)
