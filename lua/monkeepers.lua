-- monkeepers_mode: bots carry bags along the routes players use (host only)
-- port of Monkeepers (TdlQ, PAYDAY 2): a player picks up a bag and throws it far away -> route
-- pickup -> throw spot. Bags lying around the pickup spot are then fetched by a bot, carried to
-- the throw spot and thrown the same way (same direction and force, which lands the same).

BotsHaveFeelingsReborn.Monkeepers = BotsHaveFeelingsReborn.Monkeepers or {
	routes = {},
	pickups = {}, -- by peer id: where and what the player picked up last
	bag_jobs = {}, -- by bag key
}

local M = BotsHaveFeelingsReborn.Monkeepers

local mvec3_copy = mvector3.copy
local mvec3_dis = mvector3.distance

M.MODE_OFF = 1
M.MODE_ID = 2 -- only bags with the same carry id
M.MODE_TYPE = 3 -- only bags of the same type (= throw distance)
M.MODE_ANY = 4

M.MIN_DISTANCE = 700 -- the throw has to land this far from where the bag was picked up
M.MIN_HEIGHT = 250 -- ... or this much higher / lower
M.PICKUP_RADIUS = 600 -- bags this close to the pickup spot belong to the route
M.UNUSED_ROUTE_T = 90 -- a route nothing is left to do for is dropped after this
M.FAIL_DELAY = 10 -- a route that failed is left alone for this long
M.JOB_TIMEOUT = 60
M.LANDING_DELAY = 2.5 -- from the throw to where the bag lies
M.CHECK_INTERVAL = 0.5
M.SO_PREFIX = "bhfr_mkp_"

local function now()
	return TimerManager:game():time()
end

function M:mode()
	return BotsHaveFeelingsReborn:GetConfigOption("monkeepers_mode") or self.MODE_OFF
end

function M:enabled()
	return Network:is_server() and self:mode() ~= self.MODE_OFF
end

function M:acceptable(carry_id)
	local carry_tweak = tweak_data.carry[carry_id]
	local excluded = BotsHaveFeelingsReborn.NO_CATCH_CARRY_IDS

	return carry_tweak ~= nil and not (excluded and excluded[carry_id])
end

function M:carry_match(id1, id2)
	local mode = self:mode()

	if mode == self.MODE_ID then
		return id1 == id2
	elseif mode == self.MODE_TYPE then
		local carry_tweak1, carry_tweak2 = tweak_data.carry[id1], tweak_data.carry[id2]

		return carry_tweak1 ~= nil and carry_tweak2 ~= nil and carry_tweak1.type == carry_tweak2.type
	elseif mode == self.MODE_ANY then
		return true
	end

	return false
end

local function nav_spot(pos)
	local tracker = managers.navigation:create_nav_tracker(pos, false)
	local seg, field_pos = tracker:nav_segment(), tracker:field_position()

	managers.navigation:destroy_nav_tracker(tracker)

	return seg, field_pos, managers.groupai:state():get_area_from_nav_seg_id(seg)
end

-- recording -----------------------------------------------------------------------------------

function M:on_pickup(bag, peer, player)
	player = player or (peer and peer:unit())

	if not alive(player) or not bag:carry_data() then
		return
	end

	peer = peer or managers.network:session():peer_by_unit(player)

	local carry_id = bag:carry_data():carry_id()

	if not peer or not self:acceptable(carry_id) then
		return
	end

	self.pickups[peer:id()] = {
		carry_id = carry_id,
		pos = mvec3_copy(player:position()),
	}
end

-- called with the bag unit a player has just thrown
function M:on_player_throw(bag, carry_id, peer, position, dir, level)
	if not self:enabled() or not peer or not alive(bag) then
		return
	end

	local pickup = self.pickups[peer:id()]
	local thrower = peer:unit()

	if not pickup or pickup.carry_id ~= carry_id or not alive(thrower) then
		return
	end

	self.pickups[peer:id()] = nil

	local throw = {
		carry_id = carry_id,
		pickup_pos = pickup.pos,
		throw_pos = mvec3_copy(thrower:position()),
		start_dz = position.z - thrower:position().z,
		dir = mvec3_copy(dir),
		level = level or 0,
	}

	managers.enemy:add_delayed_clbk("bhfr_mkp_landing" .. tostring(bag:key()), function()
		if alive(bag) and self:enabled() and not (bag:carry_data() and bag:carry_data():is_linked()) then
			self:make_route(throw, mvec3_copy(bag:position()))
		end
	end, now() + self.LANDING_DELAY)
end

function M:remove_route(i)
	local route = table.remove(self.routes, i)

	if route then
		route.obsolete = true
	end
end

function M:make_route(throw, land_pos)
	local dis = mvec3_dis(throw.pickup_pos:with_z(0), land_pos:with_z(0))

	if dis < self.MIN_DISTANCE and math.abs(land_pos.z - throw.pickup_pos.z) < self.MIN_HEIGHT then
		return
	end

	local horizontal = throw.dir:with_z(0)

	if mvector3.length(horizontal) < 0.01 then
		return
	end

	-- the same route again (or the opposite one) is replaced
	for i = #self.routes, 1, -1 do
		local route = self.routes[i]

		if self:carry_match(throw.carry_id, route.carry_id) then
			local same = mvec3_dis(route.pickup_pos, throw.pickup_pos) < self.PICKUP_RADIUS
			local opposite = mvec3_dis(route.pickup_pos, land_pos) < self.PICKUP_RADIUS and
				mvec3_dis(route.land_pos, throw.pickup_pos) < self.PICKUP_RADIUS

			if same or opposite then
				self:remove_route(i)
			end
		end
	end

	table.insert(self.routes, {
		carry_id = throw.carry_id,
		pickup_pos = throw.pickup_pos,
		throw_pos = throw.throw_pos,
		land_pos = land_pos,
		start_dz = throw.start_dz,
		dir = throw.dir,
		level = throw.level,
		rot = Rotation(horizontal, math.UP),
		created_t = now(),
		last_used_t = now(),
	})
end

-- bots ----------------------------------------------------------------------------------------

function M:revive_pending()
	for id, so in pairs(managers.groupai:state()._special_objectives) do
		if type(id) == "string" and so.data and so.data.AI_group == "friendlies" and id:find("revive") then
			return true
		end
	end

	return false
end

function M:bot_available(unit)
	if not alive(unit) or not unit:brain() or not unit:brain()._logic_data then
		return false
	end

	local movement = unit:movement()

	if movement._bhfr_mkp or movement._bhfr_gpk or movement._bhfr_flare or movement._bhfr_flee or movement:downed() or
		unit:character_damage():need_revive() or movement:is_carrying() or movement:chk_action_forbidden("walk") then
		return false
	end

	local objective = unit:brain():objective()

	return not objective or objective.type == "follow"
end

-- an older route that still has a bag waiting goes first
function M:older_route_waiting(route)
	for _, job in pairs(self.bag_jobs) do
		local other = job.route

		if job.state == "waiting" and other ~= route and not other.obsolete and other.created_t < route.created_t and
			not (other.failed_t and now() - other.failed_t < self.FAIL_DELAY) then
			return true
		end
	end

	return false
end

function M:make_drop_objective(job)
	local route = job.route
	local seg, pos, area = nav_spot(route.throw_pos)

	return {
		type = "act",
		pose = "stand",
		nav_seg = seg,
		area = area,
		pos = pos,
		rot = route.rot,
		destroy_clbk_key = false,
		action_duration = 0.2,
		fail_clbk = function(unit)
			self:end_job(job, unit, true)
		end,
		complete_clbk = function(unit)
			self:on_drop_done(job, unit)
		end,
		action = {
			variant = "gesture_stop",
			align_sync = true,
			body_part = 1,
			type = "act",
			blocks = {
				aim = -1,
				turn = -1,
			},
		},
	}
end

function M:register_bag(bag, route)
	local key = bag:key()

	if self.bag_jobs[key] then
		return
	end

	local seg, pos, area = nav_spot(bag:position())

	if not area then
		return
	end

	local job = {
		bag = bag,
		key = key,
		route = route,
		so_id = self.SO_PREFIX .. tostring(key),
		state = "waiting",
		t = now(),
	}

	local objective = {
		type = "act",
		haste = "run",
		pose = "crouch",
		nav_seg = seg,
		area = area,
		pos = pos,
		destroy_clbk_key = false,
		action_duration = 1,
		fail_clbk = function(unit)
			self:end_job(job, unit, true)
		end,
		complete_clbk = function(unit)
			self:on_pickup_done(job, unit)
		end,
		action = {
			variant = "untie",
			align_sync = true,
			body_part = 1,
			type = "act",
		},
	}

	self.bag_jobs[key] = job

	managers.groupai:state():add_special_objective(job.so_id, {
		interval = 1,
		base_chance = 1,
		chance_inc = 0,
		usage_amount = 1,
		objective = objective,
		search_pos = pos,
		AI_group = "friendlies",
		verification_clbk = function(candidate)
			return self:verify(job, candidate)
		end,
		admin_clbk = function(unit)
			job.state = "walking"
			job.carrier = unit
			job.t = now()
			job.prev_objective = job.candidates and job.candidates[unit:key()]
			job.objective = unit:brain():objective()
			job.bhfr_mode = unit:movement():bhfr_mode()
			job.bhfr_following = unit:movement():bhfr_following()
			unit:movement()._bhfr_mkp = job
			unit:movement():set_bhfr_carry_job("fetch")
			managers.groupai:state():remove_special_objective(job.so_id)
		end,
	})
end

function M:verify(job, candidate)
	local route = job.route

	if not self:enabled() or route.obsolete or (route.failed_t and now() - route.failed_t < self.FAIL_DELAY) then
		return false
	end

	if not alive(job.bag) or not self:bot_available(candidate) then
		return false
	end

	if not candidate:movement():can_carry_weight(job.bag:carry_data():carry_id()) then
		return false
	end

	if self:revive_pending() or self:older_route_waiting(route) then
		return false
	end

	-- the objective the bot gets back after the job (admin_clbk only sees the job's own)
	job.candidates = job.candidates or {}
	job.candidates[candidate:key()] = candidate:brain():objective()

	return true
end

function M:on_pickup_done(job, unit)
	local bag = job.bag

	if job.carrier ~= unit or not alive(bag) or bag:carry_data():is_linked() or not unit:movement():add_carry_unit(bag) then
		self:end_job(job, unit, true)

		return
	end

	bag:carry_data():link_to(unit)

	job.state = "carrying"
	unit:movement():set_bhfr_carry_job("bring")
	job.t = now()
	job.objective = self:make_drop_objective(job)

	unit:brain():set_objective(job.objective)
end

-- same event a player's throw sends: every peer pushes the (already existing) bag the same way
function M:on_drop_done(job, unit)
	local bag, route = job.bag, job.route

	if alive(bag) and bag:carry_data():is_linked() then
		local cd = bag:carry_data()
		local carry_id, multiplier = cd:carry_id(), cd:multiplier()
		local start = unit:position() + Vector3(0, 0, route.start_dz)

		cd:unlink(true)
		bag:set_position(start)

		managers.network:session():send_to_peers_synched("sync_carry_data", bag, carry_id, multiplier, start, route.dir,
			route.level, nil, 0)
		managers.player:sync_carry_data(bag, carry_id, multiplier, start, route.dir, route.level, nil, 0)
	end

	route.last_used_t = now()

	self:end_job(job, unit, false)
end

-- mark = the route failed, give it a break
function M:end_job(job, unit, mark)
	if mark and job.route then
		job.route.failed_t = now()
	end

	self.bag_jobs[job.key] = nil
	managers.groupai:state():remove_special_objective(job.so_id)

	if alive(unit) then
		local movement = unit:movement()

		if movement._bhfr_mkp == job then
			movement._bhfr_mkp = nil
			movement:set_bhfr_carry_job(nil)

			if alive(job.bag) and job.bag:carry_data() and job.bag:carry_data():is_linked() then
				movement:drop_all_carry()
			end

			local objective = unit:brain():objective()

			if objective and objective == job.objective then
				unit:brain():set_objective(nil)
			end

			-- the game hands out a new objective after the job (in stealth: stand still) or none at all
			managers.enemy:add_delayed_clbk("bhfr_mkp_restore" .. tostring(job.key), function()
				self:restore_follow(unit, job)
			end, now() + 0.1)
		end
	end
end

-- the bot goes back to following whom it followed before the job, unless it was told something else since
function M:restore_follow(unit, job)
	local prev = job.prev_objective

	if not alive(unit) or not prev or prev.type ~= "follow" or not alive(prev.follow_unit) then
		return
	end

	local movement = unit:movement()

	if movement._bhfr_mkp or movement._bhfr_gpk or movement:downed() or unit:character_damage():need_revive() or
		movement:bhfr_mode() ~= job.bhfr_mode or movement:bhfr_following() ~= job.bhfr_following then
		return
	end

	local objective = unit:brain():objective()

	if not objective or objective.type == "defend_area" then
		unit:brain():set_objective(prev)
	end
end

-- upkeep --------------------------------------------------------------------------------------

function M:reset()
	for _, job in pairs(table.map_copy(self.bag_jobs)) do
		self:end_job(job, job.carrier, false)
	end

	self.routes = {}
	self.pickups = {}
	self.bag_jobs = {}
end

function M:bags_around(route)
	local bags = {}

	for _, unit in ipairs(managers.interaction._interactive_units) do
		local cd = alive(unit) and unit:carry_data()

		if cd and unit:interaction():active() and not cd:is_linked() and self:carry_match(route.carry_id, cd:carry_id()) then
			local pos = unit:position()

			if mvec3_dis(pos:with_z(0), route.pickup_pos:with_z(0)) < self.PICKUP_RADIUS and
				math.abs(pos.z - route.pickup_pos.z) < self.MIN_HEIGHT then
				table.insert(bags, unit)
			end
		end
	end

	return bags
end

function M:update(t)
	-- jobs that lost their reason
	for key, job in pairs(table.map_copy(self.bag_jobs)) do
		local bag, unit = job.bag, job.carrier

		if not alive(bag) or job.route.obsolete and job.state == "waiting" then
			self:end_job(job, unit, false)
		elseif job.state == "waiting" then
			if bag:carry_data():is_linked() or not bag:interaction():active() then
				self:end_job(job, unit, false)
			end
		elseif job.state == "walking" and (bag:carry_data():is_linked() or not bag:interaction():active()) and alive(unit) then
			-- someone else took the bag on the way
			self:end_job(job, unit, false)
		elseif not alive(unit) or unit:movement():downed() or unit:character_damage():need_revive() or
			unit:brain():objective() ~= job.objective or t - job.t > self.JOB_TIMEOUT then
			self:end_job(job, unit, true)
		end
	end

	-- routes: find bags to fetch, drop routes nothing was left to do for
	for i = #self.routes, 1, -1 do
		local route = self.routes[i]
		local bags = self:bags_around(route)

		for _, bag in ipairs(bags) do
			self:register_bag(bag, route)
		end

		if #bags > 0 then
			route.last_used_t = t
		end

		if t - route.last_used_t > self.UNUSED_ROUTE_T then
			self:remove_route(i)
		end
	end
end

Hooks:PostHook(GroupAIStateBase, "update", "BHFR_GroupAIStateBase_update_monkeepers",
	function(self, t, dt)
		if not Network:is_server() or not managers.navigation:is_data_ready() then
			return
		end

		local game_t = now()

		if self._bhfr_mkp_t and game_t < self._bhfr_mkp_t then
			return
		end

		self._bhfr_mkp_t = game_t + M.CHECK_INTERVAL

		if M:enabled() then
			M:update(game_t)
		elseif next(M.routes) or next(M.bag_jobs) then
			M:reset()
		end
	end
)
