-- bots_avoid_grenades: danger zones around live grenades and fires, bots step out of them (host only)

BotsHaveFeelingsReborn.Danger = BotsHaveFeelingsReborn.Danger or { zones = {} }

local Danger = BotsHaveFeelingsReborn.Danger

local mvec3_copy = mvector3.copy
local mvec3_dis = mvector3.distance

local MARGIN = 150 -- stay this far outside of the blast radius
local CHECK_INTERVAL = 0.3
local MIN_FLEE_T = 1
local MAX_FLEE_T = 12

local function now()
	return TimerManager:game():time()
end

-- a live projectile, the zone follows it until it is gone (= detonated)
function Danger:add_unit_zone(unit, range, fuse)
	table.insert(self.zones, {
		unit = unit,
		range = range,
		expire_t = now() + fuse + 2,
	})
end

-- fire stays where it was lit
function Danger:add_static_zone(pos, range, duration)
	table.insert(self.zones, {
		pos = mvec3_copy(pos),
		range = range,
		expire_t = now() + duration,
	})
end

function Danger:zone_pos(zone)
	return zone.unit and zone.unit:position() or zone.pos
end

function Danger:cleanup(t)
	for i = #self.zones, 1, -1 do
		local zone = self.zones[i]

		if (t > zone.expire_t) or (zone.unit and not alive(zone.unit)) then
			table.remove(self.zones, i)
		end
	end
end

-- the zone containing pos (nearest centre first), if any
function Danger:zone_at(pos, margin)
	local result, result_dis

	for _, zone in ipairs(self.zones) do
		local dis = mvec3_dis(pos, self:zone_pos(zone))

		if (dis < zone.range + margin) and (not result_dis or dis < result_dis) then
			result = zone
			result_dis = dis
		end
	end

	return result
end

-- a spot outside the zone the bot can walk to, away from its centre
function Danger:find_safe_pos(bot_pos, zone_pos, safe_dis)
	local dir = bot_pos - zone_pos

	mvector3.set_z(dir, 0)

	if mvector3.length(dir) < 1 then
		dir = Vector3(1, 0, 0)
	end

	mvector3.normalize(dir)

	for _, angle in ipairs({ 0, 40, -40, 80, -80, 120, -120 }) do
		local candidate_dir = mvec3_copy(dir)

		mvector3.rotate_with(candidate_dir, Rotation(angle, 0, 0))

		local candidate = zone_pos + candidate_dir * safe_dis

		mvector3.set_z(candidate, bot_pos.z)

		local cover = managers.navigation:find_cover_nearest_pos(candidate, 400)
		local pos = cover and mvec3_copy(cover[NavigationManager.COVER_POSITION]) or candidate
		local seg = managers.navigation:get_nav_seg_from_pos(pos, true)

		if seg and (mvec3_dis(pos, zone_pos) >= safe_dis * 0.85) then
			return pos, seg
		end
	end
end

function Danger:restore(unit, flee)
	local brain = unit:brain()
	local prev = flee.prev

	-- the unit to follow may be gone by now
	if prev and prev.follow_unit and not alive(prev.follow_unit) then
		prev = nil
	end

	if prev then
		prev.in_place = nil

		brain:set_objective(prev)
	else
		managers.groupai:state():on_criminal_jobless(unit)
	end
end

function Danger:update_bot(unit, t)
	local movement = unit:movement()
	local brain = unit:brain()
	local objective = brain:objective()
	local flee = movement._bhfr_flee

	if flee and (objective ~= flee.objective) then
		-- something else gave the bot a new job, not ours to restore anymore
		movement._bhfr_flee = nil
		flee = nil
	end

	local bot_pos = unit:position()
	local zone = self:zone_at(bot_pos, MARGIN)

	if flee and not zone then
		if (t > flee.min_t) then
			movement._bhfr_flee = nil

			self:restore(unit, flee)
		end

		return
	elseif flee and (t > flee.max_t) then
		movement._bhfr_flee = nil

		self:restore(unit, flee)

		return
	elseif not zone then
		return
	end

	if flee and (mvec3_dis(bot_pos, flee.pos) > 150) then
		-- still on its way
		return
	end

	if not flee and ((objective and (objective.type == "revive")) or
		unit:movement():downed() or unit:character_damage():need_revive() or
		unit:movement():chk_action_forbidden("walk")) then
		return
	end

	local pos, seg = self:find_safe_pos(bot_pos, self:zone_pos(zone), zone.range + MARGIN + 100)

	if not pos then
		return
	end

	local flee_objective = {
		type = "defend_area",
		scan = true,
		destroy_clbk_key = false,
		pos = pos,
		nav_seg = seg,
		radius = 1000,
	}

	movement._bhfr_flee = {
		objective = flee_objective,
		prev = flee and flee.prev or objective,
		pos = pos,
		min_t = t + MIN_FLEE_T,
		max_t = flee and flee.max_t or (t + MAX_FLEE_T),
	}

	brain:set_objective(flee_objective)
end

function Danger:update(t)
	self:cleanup(t)

	for _, char_data in pairs(managers.criminals:ai_criminals()) do
		local unit = char_data.unit

		if alive(unit) and unit:brain() and unit:brain()._logic_data then
			self:update_bot(unit, t)
		end
	end
end

Hooks:PostHook(GroupAIStateBase, "update", "BHFR_GroupAIStateBase_update_danger",
	function(self, t, dt)
		if not Network:is_server() or not BotsHaveFeelingsReborn:GetConfigOption("bots_avoid_grenades") then
			return
		end

		local game_t = now()

		if self._bhfr_danger_t and (game_t < self._bhfr_danger_t) then
			return
		end

		self._bhfr_danger_t = game_t + CHECK_INTERVAL

		Danger:update(game_t)
	end
)
