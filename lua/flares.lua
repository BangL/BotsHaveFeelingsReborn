-- bots_extinguish_flares: a bot in reach (remaining time * bot speed) runs to a spotter flare and puts it out, 5% of the time by pissing on it (host only)

BotsHaveFeelingsReborn.Flares = BotsHaveFeelingsReborn.Flares or {}

local Flares = BotsHaveFeelingsReborn.Flares

local mvec3_copy = mvector3.copy
local mvec3_dis = mvector3.distance

local CHECK_INTERVAL = 0.3
local BOT_SPEED = 400 -- cm/s, rough run speed
local REACH_FACTOR = 0.8 -- path is longer than the straight line
local INTERACT_DIS = 90 -- arrival distance, the bot has to get close
local PISS_INTERACT_DIS = 200
local PISS_CHANCE = 0.05 -- easter egg: this share of the flares is put out the other way
local STAND_OFFSET = 20 -- the bot stands this far beside the flare, on the side it came from
local STAND_TIME = 3 -- time on the animation before the flare goes out (s)
local KNEEL_ACT = "e_so_pickup_stuff_floor_dustoff_hands" -- vanilla NPC act, bending down and dusting off the hands
local PISS_OFFSET = 175 -- the stream needs more room
local PISS_TIME = 6 -- time on the animation before the flare goes out (s)
local INTERACT_MARGIN = 1.5 -- on top of the standing time, when checking if a bot can make it (s)
local PISS_ACT = "e_so_ntl_pissing" -- vanilla NPC act, synced to every client
local MOVE_TOLERANCE = 150 -- the flare is still rolling, re-aim the bot

local function now()
	return TimerManager:game():time()
end

local function bot_available(unit)
	if not alive(unit) or not unit:brain() or not unit:brain()._logic_data then
		return false
	end

	local movement = unit:movement()
	local objective = unit:brain():objective()

	return not (movement._bhfr_flare or movement:downed() or unit:character_damage():need_revive() or
		(objective and objective.type == "revive"))
end

-- a spot next to the flare on the bot's side, so it does not stand on top of it
local function stand_spot(flare_pos, from_pos, offset)
	local dir = from_pos - flare_pos

	mvector3.set_z(dir, 0)

	if mvector3.length(dir) < 1 then
		return mvec3_copy(flare_pos), managers.navigation:get_nav_seg_from_pos(flare_pos, true)
	end

	mvector3.normalize(dir)

	local pos = flare_pos + dir * offset
	local seg = managers.navigation:get_nav_seg_from_pos(pos, true)

	if not seg then
		return mvec3_copy(flare_pos), managers.navigation:get_nav_seg_from_pos(flare_pos, true)
	end

	return pos, seg
end

local function flare_objective(pos, seg, radius)
	return {
		type = "defend_area",
		scan = true,
		destroy_clbk_key = false,
		pos = mvec3_copy(pos),
		nav_seg = seg,
		radius = radius,
	}
end

local function release(unit, job)
	local movement = unit:movement()

	movement._bhfr_flare = nil

	if not alive(unit) or movement:downed() or unit:character_damage():need_revive() then
		return
	end

	local brain = unit:brain()

	if brain:objective() ~= job.objective then
		-- something else gave the bot a new job, not ours to restore anymore
		return
	end

	local prev = job.prev

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

local function face(unit, pos)
	local dir = pos - unit:position()

	mvector3.set_z(dir, 0)

	if mvector3.length(dir) > 1 then
		unit:movement():set_rotation(Rotation(dir, math.UP))
	end
end

-- water stream out of the bot's hips, local on every machine (the host tells BHFR clients)
local STREAM_EFFECT = "effects/bhfr/pee_stream" -- own effect (assets/), the vanilla water effects do not show up here
local STREAM_INTERVAL = 0.08
local STREAM_SOUND_START = "canister_fill_loop_start" -- liquid loop from sfx.bnk, closest thing the game has
local STREAM_SOUND_STOP = "canister_fill_loop_stop"

function Flares.preload_stream()
	local ids_effect = Idstring("effect")
	local ids_name = Idstring(STREAM_EFFECT)

	if not managers.dyn_resource:is_resource_ready(ids_effect, ids_name, managers.dyn_resource.DYN_RESOURCES_PACKAGE) then
		managers.dyn_resource:load(ids_effect, ids_name, managers.dyn_resource.DYN_RESOURCES_PACKAGE, nil)

		return false
	end

	return true
end

-- arcs of drops from the bot's hips towards the flare it faces
function Flares.play_stream(unit, duration)
	if not alive(unit) or not Flares.preload_stream() then
		return
	end

	local t = TimerManager:game():time()
	local key = "bhfr_flare_stream" .. tostring(unit:key())

	for i = 0, math.floor(duration / STREAM_INTERVAL) - 1 do
		managers.enemy:add_delayed_clbk(key .. i, function()
			if not alive(unit) then
				return
			end

			local object = unit:get_object(Idstring("Hips")) or unit:orientation_object()

			World:effect_manager():spawn({
				effect = Idstring(STREAM_EFFECT),
				position = object:position() + unit:rotation():y() * 15,
				normal = unit:rotation():y() + math.UP * 0.3,
			})
		end, t + i * STREAM_INTERVAL)
	end

	if unit:sound() then
		unit:sound():play(STREAM_SOUND_START)
	end

	managers.enemy:add_delayed_clbk(key .. "stop", function()
		if alive(unit) and unit:sound() then
			unit:sound():play(STREAM_SOUND_STOP)
		end
	end, t + duration)
end

-- same as UseInteractionExt:interact, minus the parts that only make sense for the local player
local function extinguish(unit, flare, piss)
	local ext = flare:interaction()

	if not ext or not ext:active() then
		return
	end

	ext:remove_interact()

	if unit:sound() then
		unit:sound():say("player_gen_action_finished", true, true)
	end

	if flare:damage() and flare:damage():has_sequence("interact") then
		flare:damage():run_sequence_simple("interact", { unit = unit })
	end

	if flare:damage() and flare:damage():has_sequence("load") then
		flare:damage():run_sequence_simple("load", { unit = unit })
	end

	managers.network:session():send_to_peers_synched("sync_interacted", flare, -2, ext.tweak_data, 1)

	if ext._global_event then
		managers.mission:call_global_event(ext._global_event, unit)
	end

	ext:set_active(ext._tweak_data.keep_active == true)
end

function Flares:has_bot(flare)
	for _, char_data in pairs(managers.criminals:ai_criminals()) do
		local job = alive(char_data.unit) and char_data.unit:movement()._bhfr_flare

		if job and job.flare == flare then
			return true
		end
	end

	return false
end

function Flares:send_bot(flare_data, game_t)
	local flare = flare_data.unit
	local flare_pos = flare:position()
	local piss = math.random() < PISS_CHANCE
	local offset = piss and PISS_OFFSET or STAND_OFFSET
	local remaining = flare_data.barrage_time - Application:time() - (piss and PISS_TIME or STAND_TIME) - INTERACT_MARGIN
	local max_dis = remaining * BOT_SPEED * REACH_FACTOR

	if max_dis <= 0 then
		return
	end

	local best, best_dis

	for _, char_data in pairs(managers.criminals:ai_criminals()) do
		local unit = char_data.unit

		if bot_available(unit) then
			local dis = mvec3_dis(unit:position(), flare_pos)

			if dis <= max_dis and (not best_dis or dis < best_dis) then
				best, best_dis = unit, dis
			end
		end
	end

	if not best then
		return
	end

	local pos, seg = stand_spot(flare_pos, best:position(), offset)

	if not seg then
		return
	end

	local brain = best:brain()
	local objective = flare_objective(pos, seg, piss and 100 or 15)

	best:movement()._bhfr_flare = {
		flare = flare,
		objective = objective,
		piss = piss,
		offset = offset,
		prev = brain:objective(),
	}

	brain:set_objective(objective)
end

function Flares:update_bot(unit, job, game_t)
	local flare = job.flare
	local ext = alive(flare) and flare:interaction()
	local brain = unit:brain()

	if not ext or not ext:active() or unit:movement():downed() or unit:character_damage():need_revive() or
		brain:objective() ~= job.objective then
		release(unit, job)

		return
	end

	local flare_pos = flare:position()

	if job.done_t then
		-- the animation runs, put the flare out when the time is up
		if game_t >= job.done_t then
			extinguish(unit, flare, job.piss)
			release(unit, job)
		end

		return
	end

	local dis = mvec3_dis(unit:position(), flare_pos)
	local arrive_dis = job.piss and PISS_INTERACT_DIS or INTERACT_DIS
	local arrived = dis <= arrive_dis or (dis <= arrive_dis * 2 and brain:objective().in_place)

	if arrived then
		-- arrived: stop and take a moment before it goes out
		local seg = unit:movement():nav_tracker():nav_segment()

		job.objective = {
			type = "defend_area",
			scan = true,
			destroy_clbk_key = false,
			pos = mvec3_copy(unit:movement():nav_tracker():field_position()),
			nav_seg = seg,
			radius = 50,
		}
		face(unit, flare_pos)
		brain:set_objective(job.objective)

		if not job.piss then
			job.done_t = game_t + STAND_TIME

			unit:movement():action_request({
				type = "act",
				body_part = 1,
				variant = KNEEL_ACT,
				align_sync = true,
				blocks = {
					walk = -1,
				},
			})

			return
		end

		-- easter egg: vanilla NPC animation, stream and a line
		job.done_t = game_t + PISS_TIME
		Flares.play_stream(unit, PISS_TIME)

		if unit:sound() then
			unit:sound():say("player_gen_positive_reinforcement", true, true)
		end

		if BotsHaveFeelingsReborn.Sync then
			BotsHaveFeelingsReborn.Sync:send_to_peers(false, BotsHaveFeelingsReborn.Sync.events.bot_flare_stream, {
				name = unit:base()._tweak_table,
				duration = PISS_TIME,
			})
		end

		unit:movement():action_request({
			type = "act",
			body_part = 1,
			variant = PISS_ACT,
			align_sync = true,
			blocks = {
				walk = -1,
			},
		})

		return
	end

	if mvec3_dis(job.objective.pos, flare_pos) > job.offset + MOVE_TOLERANCE then
		local pos, seg = stand_spot(flare_pos, unit:position(), job.offset)

		if seg then
			job.objective = flare_objective(pos, seg, job.piss and 100 or 15)
			brain:set_objective(job.objective)
		end
	end
end

function Flares:update(game_t)
	-- running jobs
	for _, char_data in pairs(managers.criminals:ai_criminals()) do
		local unit = char_data.unit

		if alive(unit) and unit:movement()._bhfr_flare then
			self:update_bot(unit, unit:movement()._bhfr_flare, game_t)
		end
	end

	-- new flares
	for _, flare_data in ipairs(managers.barrage._flares or {}) do
		local flare = flare_data.unit

		if alive(flare) and not flare_data.called and flare:interaction() and flare:interaction():active() and
			not self:has_bot(flare) then
			self:send_bot(flare_data, game_t)
		end
	end
end

Hooks:PostHook(GroupAIStateBase, "update", "BHFR_GroupAIStateBase_update_flares",
	function(self, t, dt)
		if not Network:is_server() or not BotsHaveFeelingsReborn:GetConfigOption("bots_extinguish_flares") or
			not managers.barrage then
			return
		end

		local game_t = now()

		if self._bhfr_flares_t and (game_t < self._bhfr_flares_t) then
			return
		end

		self._bhfr_flares_t = game_t + CHECK_INTERVAL

		Flares.preload_stream()
		Flares:update(game_t)
	end
)
