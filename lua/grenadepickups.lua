-- bots_throw_grenades: a bot has as many grenades as a player can carry of its throwable (and gets nothing for free), a thrown one is gone.
-- It refills at grenade pickups: a bot that only follows walks to one nearby, takes what it is missing and the pickup shrinks like it does
-- for a player; a bot that runs over one anyway takes it on the way (host only).

BotsHaveFeelingsReborn.GrenadePickups = BotsHaveFeelingsReborn.GrenadePickups or {
	jobs = {}, -- by bot key
	claimed = {}, -- pickup keys a bot is on its way to
	counts = {}, -- grenades by character (a respawned bot keeps what its predecessor had left)
}

local G = BotsHaveFeelingsReborn.GrenadePickups

local mvec3_dis = mvector3.distance

G.RADIUS = 1500 -- a bot only goes for pickups this close to it
G.MAX_DZ = 250 -- ... and not much above or below it
G.PLAYER_NEAR = 400 -- a pickup with a player this close to it is left to the player
G.JOB_TIMEOUT = 30
G.CHECK_INTERVAL = 1
G.PASS_RADIUS = 150 -- a bot this close to a pickup takes it on the way, whatever it is doing (like a player running over it)
G.PASS_DZ = 150
G.PASS_INTERVAL = 0.2
G.TWEAK = "grenade_pickup_new"

local function now()
	return TimerManager:game():time()
end

function G:enabled()
	return Network:is_server() and BotsHaveFeelingsReborn:GetConfigOption("bots_throw_grenades")
end

-- grenades the bot has / can carry; a new throwable starts full
function G:amount(unit)
	local _, tweak, id = BotsHaveFeelingsReborn.GetBotGrenade(unit)

	if not id then
		return 0, 0
	end

	local name = unit:base()._tweak_table
	local max = tweak.max_amount or 0
	local count = self.counts[name]

	if not count or count.id ~= id then
		count = { id = id, n = max }
		self.counts[name] = count
	end

	return count.n, max
end

function G:set_amount(unit, n)
	self:amount(unit) -- makes sure the entry exists

	local count = self.counts[unit:base()._tweak_table]

	if count then
		count.n = n
	end
end

function G:spent(unit)
	local have = self:amount(unit)

	if have > 0 then
		self:set_amount(unit, have - 1)
	end
end

-- the extension that holds the stack of a pickup unit
local function stack_ext(unit)
	local ext = unit:base()

	if not (ext and ext.get_stack_size) then
		ext = unit.pickup and unit:pickup()
	end

	return ext and ext.get_stack_size and ext or nil
end

local function nav_spot(pos)
	local tracker = managers.navigation:create_nav_tracker(pos, false)
	local seg, field_pos = tracker:nav_segment(), tracker:field_position()

	managers.navigation:destroy_nav_tracker(tracker)

	return seg, field_pos, managers.groupai:state():get_area_from_nav_seg_id(seg)
end

function G:usable(unit)
	if not alive(unit) or not unit:interaction() or unit:interaction().tweak_data ~= self.TWEAK or not unit:interaction():active() then
		return nil
	end

	local ext = stack_ext(unit)

	return ext and ext:get_stack_size() > 0 and ext or nil
end

function G:player_near(pos)
	for _, player in pairs(managers.player:players()) do
		if alive(player) and mvec3_dis(player:position(), pos) < self.PLAYER_NEAR then
			return true
		end
	end

	return false
end

-- is there a way to the pickup that is not much longer than the straight line (a pickup behind a wall is not worth the walk)
function G:reachable(unit, pickup)
	local from_tracker = unit:movement():nav_tracker()
	local to_seg = nav_spot(pickup:position())

	if not from_tracker or not to_seg then
		return false
	end

	local path = managers.navigation:search_coarse({
		id = "bhfr_gpk" .. tostring(unit:key()),
		from_tracker = from_tracker,
		to_seg = to_seg,
		access_pos = unit:brain()._SO_access,
	})

	if not path then
		return false
	end

	local length, last = 0, unit:position()

	for _, node in ipairs(path) do
		local pos = node[2]

		if pos then
			length = length + mvec3_dis(last, pos)
			last = pos
		end
	end

	return length <= self.RADIUS * 2
end

-- a bot that sees an enemy fights instead of fetching grenades
function G:in_combat(unit)
	local data = unit:brain()._logic_data
	local enemy_mask = managers.slot:get_mask("enemies")

	for _, att in pairs(data and data.detected_attention_objects or {}) do
		if att.identified and att.verified and alive(att.unit) and att.unit:in_slot(enemy_mask) then
			return true
		end
	end

	return false
end

function G:find(unit)
	local bot_pos = unit:position()
	local candidates = {}

	for _, pickup in ipairs(managers.interaction._interactive_units or {}) do
		if self:usable(pickup) and not self.claimed[pickup:key()] then
			local pos = pickup:position()
			local dis = mvec3_dis(bot_pos, pos)

			if dis <= self.RADIUS and math.abs(pos.z - bot_pos.z) <= self.MAX_DZ and not self:player_near(pos) then
				candidates[#candidates + 1] = { pickup = pickup, dis = dis }
			end
		end
	end

	table.sort(candidates, function(a, b)
		return a.dis < b.dis
	end)

	-- the nearest ones first, at most three path searches per look
	for i = 1, math.min(3, #candidates) do
		if self:reachable(unit, candidates[i].pickup) then
			return candidates[i].pickup
		end
	end
end

function G:start_job(unit, pickup)
	local seg, pos, area = nav_spot(pickup:position())

	if not area then
		return
	end

	local movement = unit:movement()
	local job = {
		unit = unit,
		key = unit:key(),
		pickup = pickup,
		pickup_key = pickup:key(),
		t = now(),
		prev_objective = unit:brain():objective(),
		bhfr_mode = movement:bhfr_mode(),
		bhfr_following = movement:bhfr_following(),
	}

	job.objective = {
		type = "act",
		haste = "run",
		pose = "crouch",
		nav_seg = seg,
		area = area,
		pos = pos,
		destroy_clbk_key = false,
		action_duration = 0.6,
		fail_clbk = function()
			self:end_job(job)
		end,
		complete_clbk = function()
			self:on_arrive(job)
		end,
		action = {
			variant = "untie",
			align_sync = true,
			body_part = 1,
			type = "act",
		},
	}

	self.jobs[job.key] = job
	self.claimed[pickup:key()] = true
	movement._bhfr_gpk = job

	unit:brain():set_objective(job.objective)
end

-- takes what the bot is missing (at most the stack), like a player does
function G:take(unit, pickup)
	local ext = self:usable(pickup)

	if not (ext and alive(unit)) then
		return 0
	end

	local have, max = self:amount(unit)
	local taken = math.min(ext:get_stack_size(), max - have)

	if taken > 0 then
		self:set_amount(unit, have + taken)

		managers.network:session():send_to_peers_synched("sync_pickup_munitions_stack", pickup, taken)
		ext:consume(taken)
	end

	return math.max(taken, 0)
end

function G:on_arrive(job)
	self:take(job.unit, job.pickup)
	self:end_job(job)
end

-- a bot that runs over a pickup takes it (room provided), no matter what it does or sees
function G:pass_by(t)
	if not self._pickup_t or t >= self._pickup_t then
		self._pickup_t = t + 0.5
		self._pickups = {}

		for _, unit in ipairs(managers.interaction._interactive_units or {}) do
			if self:usable(unit) then
				self._pickups[#self._pickups + 1] = unit
			end
		end
	end

	if #self._pickups == 0 then
		return
	end

	for _, data in pairs(managers.groupai:state():all_AI_criminals()) do
		local unit = data.unit

		if alive(unit) and not unit:movement():downed() and not unit:character_damage():need_revive() then
			local have, max = self:amount(unit)

			if have < max then
				local bot_pos = unit:position()

				for _, pickup in ipairs(self._pickups) do
					if alive(pickup) and mvec3_dis(bot_pos, pickup:position()) <= self.PASS_RADIUS and
						math.abs(pickup:position().z - bot_pos.z) <= self.PASS_DZ and self:take(unit, pickup) > 0 then
						local job = self.jobs[unit:key()]

						-- it was on its way to this one: nothing to walk to anymore
						if job and job.pickup == pickup then
							self:end_job(job)
						end

						break
					end
				end
			end
		end
	end
end

function G:end_job(job)
	local unit = job.unit

	self.jobs[job.key] = nil

	self.claimed[job.pickup_key] = nil

	if not alive(unit) then
		return
	end

	local movement = unit:movement()

	if movement._bhfr_gpk ~= job then
		return
	end

	movement._bhfr_gpk = nil

	if unit:brain():objective() == job.objective then
		unit:brain():set_objective(nil)
	end

	-- the game hands out a new objective after the job (in stealth: stand still): back to following whom it followed
	managers.enemy:add_delayed_clbk("bhfr_gpk_restore" .. tostring(job.key) .. "_" .. tostring(now()), function()
		BotsHaveFeelingsReborn.Monkeepers:restore_follow(unit, job)
	end, now() + 0.1)
end

function G:reset()
	for _, job in pairs(table.map_copy(self.jobs)) do
		self:end_job(job)
	end

	self.jobs = {}
	self.claimed = {}
	self.counts = {}
	self._pickups = nil
	self._pickup_t = nil
end

function G:update(t)
	for _, job in pairs(table.map_copy(self.jobs)) do
		local unit = job.unit

		if not alive(unit) or unit:movement():downed() or unit:character_damage():need_revive() or
			unit:brain():objective() ~= job.objective or not self:usable(job.pickup) or t - job.t > self.JOB_TIMEOUT then
			self:end_job(job)
		end
	end

	for _, data in pairs(managers.groupai:state():all_AI_criminals()) do
		local unit = data.unit

		if alive(unit) and not self.jobs[unit:key()] and BotsHaveFeelingsReborn.Monkeepers:bot_available(unit, true) and
			not self:in_combat(unit) then
			local have, max = self:amount(unit)

			if have < max then
				local pickup = self:find(unit)

				if pickup then
					self:start_job(unit, pickup)
				end
			end
		end
	end
end

Hooks:PostHook(GroupAIStateBase, "update", "BHFR_GroupAIStateBase_update_grenade_pickups",
	function(self, t, dt)
		if not Network:is_server() or not managers.navigation:is_data_ready() then
			return
		end

		local game_t = now()

		if not G:enabled() then
			if next(G.jobs) then
				G:reset()
			end

			return
		end

		if not self._bhfr_gpk_pass_t or game_t >= self._bhfr_gpk_pass_t then
			self._bhfr_gpk_pass_t = game_t + G.PASS_INTERVAL

			G:pass_by(game_t)
		end

		if not self._bhfr_gpk_t or game_t >= self._bhfr_gpk_t then
			self._bhfr_gpk_t = game_t + G.CHECK_INTERVAL

			G:update(game_t)
		end
	end
)
