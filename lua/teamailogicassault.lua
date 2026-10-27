-- grenades: bots throw at groups of enemies, never at spots where a teammate (or the bot itself) would be hit

local mvec3_angle = mvector3.angle
local mvec3_dis = mvector3.distance
local mvec3_norm = mvector3.normalize

local CHECK_INTERVAL = 1 -- seconds between two looks for a target
local COOLDOWN = 8       -- seconds between two throws of one bot
local MIN_GROUP_SIZE = 3 -- enemies in blast range of the target
local MAX_THROW_DIS = 2000 -- cm
local SAFETY_MARGIN = 200  -- cm outside of the blast radius (more than the flee margin in danger.lua)

local projectile_indices = {}

-- projectile index and tweak data of the throwable chosen for this bot
local function get_grenade(unit)
	local nationality = unit:base()._tweak_table
	local grenade = BotsHaveFeelingsReborn.BOT_GRENADES[BotsHaveFeelingsReborn:GetConfigOption("bot_grenade_" .. tostring(nationality))]
	local projectile = grenade and grenade.projectile

	if not projectile then
		return
	end

	if not projectile_indices[projectile] then
		projectile_indices[projectile] = BlackMarketTweakData:get_index_from_projectile_id(projectile)
	end

	return projectile_indices[projectile], tweak_data.projectiles[projectile], projectile
end

-- projectile index, tweak data and id of the throwable of this bot (grenadepickups.lua counts them)
function BotsHaveFeelingsReborn.GetBotGrenade(unit)
	return get_grenade(unit)
end

-- nobody of ours (players, bots, the thrower) inside the blast
local function is_safe_to_throw(from_pos, target_pos, range)
	local safe_dis = range + SAFETY_MARGIN

	if mvec3_dis(from_pos, target_pos) <= safe_dis then
		return false
	end

	for _, char_data in pairs(managers.groupai:state():all_char_criminals()) do
		local unit = char_data.unit

		if alive(unit) and (mvec3_dis(unit:position(), target_pos) <= safe_dis) then
			return false
		end
	end

	return true
end

-- the visible enemy with the most other enemies around it, if it is a big enough group
local function find_target(data, from_pos, look_vec, range)
	local enemy_slotmask = managers.slot:get_mask("enemies")
	local enemies = {}

	for _, att in pairs(data.detected_attention_objects) do
		local unit = att.identified and att.unit

		if unit and alive(unit) and unit:in_slot(enemy_slotmask) and unit:base() and unit:base()._tweak_table then
			table.insert(enemies, att)
		end
	end

	local best, best_count

	for _, att in ipairs(enemies) do
		local pos = att.unit:position()
		local dis = mvec3_dis(from_pos, pos)

		if att.verified and (dis > range + SAFETY_MARGIN) and (dis <= MAX_THROW_DIS) and
			(mvec3_angle(att.m_head_pos - from_pos, look_vec) <= 90) then
			local count = 0

			for _, other in ipairs(enemies) do
				if mvec3_dis(other.unit:position(), pos) <= range * 0.7 then
					count = count + 1
				end
			end

			if (count >= MIN_GROUP_SIZE) and (not best_count or count > best_count) then
				best = att
				best_count = count
			end
		end
	end

	if best and is_safe_to_throw(from_pos, best.unit:position(), range) then
		return best
	end
end

Hooks:PreHook(TeamAILogicAssault, "update", "BHFR_TeamAILogicAssault_update", function(data)
	if not (Network:is_server() and BotsHaveFeelingsReborn:GetConfigOption("bots_throw_grenades")) then
		return
	end

	local t = TimerManager:game():time()

	if data.bhfr_grenade_t and (data.bhfr_grenade_t > t) then
		return
	end

	local projectile_index, projectile_tweak = get_grenade(data.unit)

	if not projectile_index then
		return
	end

	-- a bot carries as many as a player can, and only gets new ones from grenade pickups (grenadepickups.lua)
	local pickups = BotsHaveFeelingsReborn.GrenadePickups

	if pickups and pickups:amount(data.unit) <= 0 then
		data.bhfr_grenade_t = t + CHECK_INTERVAL

		return
	end

	data.bhfr_grenade_t = t + CHECK_INTERVAL

	local crim_mov = data.unit:movement()
	local from_pos = crim_mov:m_head_pos()
	local target = find_target(data, from_pos, crim_mov:m_rot():y(), projectile_tweak.range)

	if not target then
		return
	end

	data.bhfr_grenade_t = t + COOLDOWN

	local direction = target.m_head_pos - from_pos

	mvec3_norm(direction)

	if ProjectileBase.throw_projectile(projectile_index, from_pos, direction) then
		if pickups then
			pickups:spent(data.unit)
		end

		crim_mov:play_redirect("throw_grenade")
		managers.network:session():send_to_peers_synched("play_distance_interact_redirect", data.unit, "throw_grenade")
	end
end)

-- bots_no_unnecessary_revive

BotsHaveFeelingsReborn:BlockRevivesInProgress(TeamAILogicAssault)
