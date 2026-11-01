-- bots_avoid_guards: in stealth a following bot backs off to the last spot no guard could see it at, and waits there until the guards look away
-- bots_melee_guards: a bot that is unseen sneaks up on a lone guard (no other guard sees the guard or the bot) and takes it out with a melee strike
-- Same cone test as CopLogicBase._angle_and_dis_chk (vision.cone_1..3), widened by a margin so the bot leaves before the notice meter rises.

local mvec3_dir = mvector3.direction
local mvec3_dis = mvector3.distance
local mrot_set_look_at = mrotation.set_look_at

local CHECK_INTERVAL = 0.25
local MAX_CHECK_DIS = 3500
local ANGLE_MARGIN = 15
local RANGE_MARGIN = 1.15
local CLEAR_DELAY = 3          -- unexposed for this long, and the player too, before the bot follows again
local RETREAT_REPICK_INTERVAL = 1
local EYE_HEIGHT = 150
local TRAIL_KEEP_T = 25      -- seconds of unexposed positions the bot remembers
local TRAIL_MIN_AGE = 1
local RETREAT_MIN_DIS = 800  -- retreat at least this far back along its own trail
local RETREAT_ARRIVED_DIS = 200
-- Detour: after being driven back twice within BLOCKED_WINDOW the bot looks for another way to the player around the guards' near cones
local BLOCKED_WINDOW = 30
local BLOCKED_COUNT = 2
local DETOUR_REACHED_DIS = 250
-- A spot that drove the bot back stays "hot" until no guard covers it any more; the bot waits there instead of walking into the same cone again
local HOT_SPOT_WAIT_MAX = 25
-- Dipping into the far cone is fine for a moment, standing in it is not
local FAR_CONE_BUDGET = 4
local DETOUR_TIMEOUT = 25
local DETOUR_MAX_TRIES = 2
local NOTICE_THRESHOLD = 0.05
-- Avoiding is relaxed, a player dips into a far cone too: the notice meter fills with dt / speed_mul (cone 1 ~1.75 s, cone 2 ~2.2 s,
-- cone 3 ~7 s) and drains slowly, so a bot only backs off from the near cones or once a guard really starts to notice it.
local TOLERANT_MAX_CONE = 2
-- Rush: a bot that is being noticed by a single guard hits it before the meter is full instead of running away
local RUSH_MAX_DIS = 900
local RUSH_SPEED = 450       -- cm/s, assumed run speed of a bot (walking is 375)
local RUSH_SAFETY = 0.6      -- the bot has to arrive within this share of the guard's remaining notice time
local RUSH_ABORT_PROGRESS = 0.9
-- Panic: a guard is about to identify the bot and is within reach - hit it whatever else can see, the alarm is coming anyway
local PANIC_PROGRESS = 0.55
local PANIC_DIS = 450
local PANIC_SAFETY = 0.9
local TOLERANT_NOTICE = 0.35
local TOLERANT_ANGLE_MARGIN = 0
local TOLERANT_RANGE_MARGIN = 1
local AMBUSH_SEARCH_DIS = 1400
local AMBUSH_STRIKE_DIS = 180
local AMBUSH_CHECK_INTERVAL = 0.1
local AMBUSH_REAR_ANGLE = 125      -- the bot has to stay this far behind the guard's line of sight (0 = front, 180 = back)
local AMBUSH_GUARD_MOVED_DIS = 80  -- guard walked off its spot
local AMBUSH_GUARD_TURNED = 30     -- guard turned (degrees)
local AMBUSH_ISOLATION_DIS = 1800  -- no other guard this close to the target, seen or not (noise, found body)
local AMBUSH_GAZE_STABLE_T = 4     -- the guard has to look the same way for this long before it is a target
local AMBUSH_GAZE_TOLERANCE = 10   -- degrees
local AMBUSH_MAX_PLAYER_DIS = 2500
local AMBUSH_TIMEOUT = 12
local AMBUSH_SEARCH_INTERVAL = 1
local AMBUSH_COOLDOWN = 5

local tmp_vec = Vector3()
local tmp_rot = Rotation()

-- the cone (1 = near ... 3 = far) of the guard that covers the position, widened by the margins, nil if none or the line of sight is blocked
local function guard_cone(guard, ld, pos, angle_margin, range_margin)
    local vision = ld.internal_data and ld.internal_data.vision
    if not vision then
        return nil
    end

    local head = guard:movement():m_head_pos()
    local dis = mvec3_dir(tmp_vec, head, pos)
    if dis > MAX_CHECK_DIS then
        return nil
    end

    mrot_set_look_at(tmp_rot, tmp_vec, math.UP)
    local angle = math.abs(180 - math.abs(tmp_rot:yaw() - guard:movement():m_head_rot():yaw()))

    for i = 1, 3 do
        local cone = vision["cone_" .. i]
        if (angle <= cone.angle / 2 + angle_margin) and (dis < cone.distance * range_margin) then
            if World:raycast("ray", head, pos, "slot_mask", ld.visibility_slotmask, "ray_type", "ai_vision", "report") then
                return nil
            end

            return i
        end
    end

    return nil
end

-- strict: any cone, widened (melee target checks)
local function guard_sees(guard, ld, pos)
    return guard_cone(guard, ld, pos, ANGLE_MARGIN, RANGE_MARGIN) ~= nil
end

-- any unsuspecting guard sees the position, or already has the bot in its notice list;
-- tolerant: only the near cones count, and a guard has to have started to notice the bot
local function exposed(bot_unit, pos, ignore_guard, tolerant)
    local bot_key = bot_unit and bot_unit:key()

    for _, enemy in pairs(managers.enemy:all_enemies()) do
        local guard = enemy.unit
        local brain = alive(guard) and guard:brain()
        local ld = brain and brain._logic_data

        if ld and ld.cool and ld.detected_attention_objects and (guard ~= ignore_guard) then
            local noticed = bot_key and ld.detected_attention_objects[bot_key]
            if noticed and (noticed.identified or ((noticed.notice_progress or 0) > (tolerant and TOLERANT_NOTICE or NOTICE_THRESHOLD))) then
                return true
            end

            if tolerant then
                local cone = guard_cone(guard, ld, pos, TOLERANT_ANGLE_MARGIN, TOLERANT_RANGE_MARGIN)
                if cone and (cone <= TOLERANT_MAX_CONE) then
                    return true
                end
            elseif guard_sees(guard, ld, pos) then
                return true
            end
        end
    end

    return false
end

-- how long each guard has been looking the same way: { [guard key] = { yaw, since } }
local gazes = {}
local gaze_track_t = -1

local function track_gazes(t)
    if t == gaze_track_t then
        return
    end
    gaze_track_t = t

    for key, enemy in pairs(managers.enemy:all_enemies()) do
        local guard = enemy.unit
        if alive(guard) then
            local yaw = guard:movement():m_head_rot():yaw()
            local gaze = gazes[key]
            if not gaze or (math.abs((yaw - gaze.yaw + 180) % 360 - 180) > AMBUSH_GAZE_TOLERANCE) then
                gazes[key] = { yaw = yaw, since = t }
            end
        else
            gazes[key] = nil
        end
    end
end

local function gaze_stable(guard_key, t)
    local gaze = gazes[guard_key]
    return gaze and ((t - gaze.since) >= AMBUSH_GAZE_STABLE_T)
end

-- angle between the guard's facing and the direction to pos, flat (0 = in front of it, 180 = right behind it)
local function angle_from_front(guard, pos)
    local fwd = guard:movement():m_head_rot():y()
    local dir = pos - guard:position()
    mvector3.set_z(fwd, 0)
    mvector3.set_z(dir, 0)
    mvector3.normalize(fwd)
    mvector3.normalize(dir)

    return mvector3.angle(fwd, dir)
end

-- no other guard close to the target at all
local function isolated(guard)
    for _, enemy in pairs(managers.enemy:all_enemies()) do
        local other = enemy.unit
        if alive(other) and (other ~= guard) and not other:character_damage():dead() and (mvec3_dis(other:position(), guard:position()) < AMBUSH_ISOLATION_DIS) then
            return false
        end
    end

    return true
end

-- guards a bot may take out: alive, unsuspecting, no special enemy
local function ambush_target_ok(guard)
    if not alive(guard) then
        return false
    end

    local damage = guard:character_damage()
    local ld = guard:brain() and guard:brain()._logic_data
    local char_tweak = tweak_data.character[guard:base()._tweak_table]

    return damage and not damage:dead() and ld and ld.cool and char_tweak and not char_tweak.special_type
end

local function melee_strike(bot_unit, guard)
    local damage = guard:character_damage()
    local dir = guard:position() - bot_unit:position()
    mvector3.normalize(dir)

    local weapon_unit = bot_unit:inventory() and bot_unit:inventory():equipped_unit()
    local strike = {
        attacker_unit = bot_unit,
        can_headshot = false,
        col_ray = {
            ray = dir,
            position = guard:movement():m_head_pos(),
            normal = -dir,
            body = guard:body(0),
        },
        damage = damage._HEALTH_INIT,
        damage_effect = damage._HEALTH_INIT,
        variant = "melee",
        weapon_unit = weapon_unit,
    }

    local ok, err = blt.pcall(damage.damage_melee, damage, strike)
    if not ok then
        log("[BHFR] bot melee strike failed: " .. tostring(err))
    end
end

-- shows what the bot is up to in the HUD (and on the clients); leaves monkeepers' carry job icons alone
function TeamAIMovement:_bhfr_set_action(state)
    local current = self._bhfr_carry_job
    if state then
        self:set_bhfr_carry_job(state)
    elseif (current == "avoid") or (current == "ambush") or (current == "detour") then
        self:set_bhfr_carry_job(nil)
    end
end

function TeamAIMovement:bhfr_is_avoiding()
    return self._bhfr_avoiding == true
end

function TeamAIMovement:bhfr_is_ambushing()
    return self._bhfr_ambush ~= nil
end

function TeamAIMovement:_bhfr_restore_follow()
    local caller = self:bhfr_following()
    if alive(caller) and (self:bhfr_mode() == self.bhfr_modes.stealth_follow) then
        self._unit:brain():set_objective(self:get_bhfr_objective_follow(caller))
    end
end

function TeamAIMovement:_bhfr_avoid_end()
    self._bhfr_hot_spot = nil
    self._bhfr_avoiding = nil
    self._bhfr_clear_t = nil
    self:_bhfr_set_action(nil)

    self:_bhfr_restore_follow()
end

-- haste: the objective's own walk speed; bots in stealth are "cool" and only walk, running out of a cone has to be asked for
function TeamAIMovement:_bhfr_hold_at(pos, radius, pose, haste)
    local nav_seg = pos and managers.navigation:get_nav_seg_from_pos(pos, true)
    if not nav_seg then
        return false
    end

    self._unit:brain():set_objective({
        type = "defend_area",
        pose = pose or "crouch",
        haste = haste,
        scan = true,
        destroy_clbk_key = false,
        pos = mvector3.copy(pos),
        nav_seg = nav_seg,
        radius = radius,
    })

    return true
end

-- positions the bot stood at while no guard could see it: the way back out of a guard's sight
function TeamAIMovement:_bhfr_trail_add(t, pos)
    local trail = self._bhfr_trail or {}
    self._bhfr_trail = trail

    local last = trail[#trail]
    if not last or (mvec3_dis(last.pos, pos) > 50) then
        table.insert(trail, { t = t, pos = mvector3.copy(pos) })
    end

    while trail[1] and ((t - trail[1].t) > TRAIL_KEEP_T) do
        table.remove(trail, 1)
    end
end

-- The way back: a spot of the trail, always further back than the one picked before (older_than), far enough from here
-- and out of every near cone. Returns the trail entry.
function TeamAIMovement:_bhfr_retreat_entry(t, older_than)
    local trail = self._bhfr_trail
    if not trail or #trail == 0 then
        return nil
    end

    local here = self._unit:position()
    for i = #trail, 1, -1 do
        local entry = trail[i]
        if (not older_than or (entry.t < older_than)) and ((t - entry.t) >= TRAIL_MIN_AGE) and (mvec3_dis(entry.pos, here) >= RETREAT_MIN_DIS) and
            not exposed(nil, entry.pos + Vector3(0, 0, EYE_HEIGHT), nil, true) then
            return entry
        end
    end

    -- nothing safe on the trail: the oldest spot is the furthest back
    if not older_than or (trail[1].t < older_than) then
        return trail[1]
    end
end

function TeamAIMovement:_bhfr_avoid_start()
    local entry = self:_bhfr_retreat_entry(TimerManager:game():time())
    if entry and self:_bhfr_hold_at(entry.pos, 50, "stand", "run") then
        if not self._bhfr_hot_spot then
            self._bhfr_hot_spot = { pos = mvector3.copy(self._unit:position()), t = TimerManager:game():time() }
        end

        self._bhfr_avoiding = true
        self._bhfr_clear_t = nil
        self:_bhfr_set_action("avoid")
        self._bhfr_retreat_to = entry.pos
        self._bhfr_retreat_entry_t = entry.t

        local starts = self._bhfr_avoid_starts or {}
        self._bhfr_avoid_starts = starts
        table.insert(starts, TimerManager:game():time())
        while #starts > 5 do
            table.remove(starts, 1)
        end
        self._bhfr_retreat_t = TimerManager:game():time()
    end
end

-- driven back again and again at the same place: no way through for now
function TeamAIMovement:_bhfr_is_blocked(t)
    local count = 0
    for _, start_t in ipairs(self._bhfr_avoid_starts or {}) do
        if (t - start_t) <= BLOCKED_WINDOW then
            count = count + 1
        end
    end

    return count >= BLOCKED_COUNT
end

-- coarse path to the player that keeps out of every nav segment a guard covers with a near cone; list of positions or nil
function TeamAIMovement:_bhfr_find_detour(player_unit)
    local nav = managers.navigation
    local tracker = player_unit:movement():nav_tracker()
    local to_seg = tracker and tracker:nav_segment()
    local ld = self._unit:brain()._logic_data
    if not to_seg or not ld then
        return nil
    end

    local cache = {}
    local function verify(seg_id)
        if cache[seg_id] == nil then
            local seg = nav._nav_segments[seg_id]
            cache[seg_id] = not (seg and exposed(nil, seg.pos + Vector3(0, 0, EYE_HEIGHT), nil, true))
        end

        return cache[seg_id]
    end

    local path = nav:search_coarse({
        access_pos = ld.char_tweak.access,
        from_tracker = self._unit:movement():nav_tracker(),
        to_seg = to_seg,
        verify_clbk = verify,
    })
    if not path or (#path < 2) then
        return nil
    end

    local points = {}
    for i = 2, #path do
        local entry = path[i]
        local seg = nav._nav_segments[entry[1]]
        local pos = entry[2] or (seg and seg.pos)
        if pos then
            table.insert(points, mvector3.copy(pos))
        end
    end

    return (#points > 0) and points or nil
end

function TeamAIMovement:_bhfr_detour_start(t)
    local player = self:bhfr_following()
    if not alive(player) or not self:_bhfr_is_blocked(t) or ((self._bhfr_detour_tries or 0) >= DETOUR_MAX_TRIES) then
        return false
    end

    local points = self:_bhfr_find_detour(player)
    if not points or not self:_bhfr_hold_at(points[1], 100, "crouch") then
        return false
    end

    self._bhfr_detour_tries = (self._bhfr_detour_tries or 0) + 1
    self._bhfr_detour_try_t = t
    self._bhfr_avoiding = nil
    self._bhfr_clear_t = nil
    self._bhfr_detour = { points = points, i = 1, start_t = t }
    self:_bhfr_set_action("detour")

    return true
end

function TeamAIMovement:_bhfr_detour_end()
    self._bhfr_detour = nil
    self._bhfr_hot_spot = nil
    self:_bhfr_set_action(nil)
    self:_bhfr_restore_follow()
end

function TeamAIMovement:_bhfr_detour_update(t, is_exposed)
    local detour = self._bhfr_detour

    if is_exposed then
        -- the way round is covered as well: back off again
        self._bhfr_detour = nil
        self:_bhfr_avoid_start()
        if not self._bhfr_avoiding then
            self:_bhfr_detour_end()
        end
    elseif (t - detour.start_t) > DETOUR_TIMEOUT then
        self:_bhfr_detour_end()
    elseif mvec3_dis(self._unit:position(), detour.points[detour.i]) < DETOUR_REACHED_DIS then
        detour.i = detour.i + 1
        if detour.i > #detour.points then
            self:_bhfr_detour_end()
        else
            self:_bhfr_hold_at(detour.points[detour.i], 100, "crouch")
        end
    end
end

function TeamAIMovement:_bhfr_ambush_end(cooldown)
    self._bhfr_ambush = nil
    self:_bhfr_set_action(nil)
    self._bhfr_ambush_next_t = TimerManager:game():time() + (cooldown or AMBUSH_COOLDOWN)

    self:_bhfr_restore_follow()
end

-- why a guard is no target for this bot (nil = it is one)
function TeamAIMovement:bhfr_ambush_block_reason(guard, player_unit)
    if not ambush_target_ok(guard) then
        return "not unsuspecting / special / dead"
    end

    local pos = self._unit:position()
    local ld = guard:brain()._logic_data

    if mvec3_dis(pos, guard:position()) >= AMBUSH_SEARCH_DIS then
        return "too far"
    elseif alive(player_unit) and (mvec3_dis(player_unit:position(), guard:position()) >= AMBUSH_MAX_PLAYER_DIS) then
        return "too far from the player"
    elseif ld.name ~= "idle" then
        return "guard is moving (" .. tostring(ld.name) .. ")"
    elseif not gaze_stable(guard:key(), TimerManager:game():time()) then
        return "guard keeps turning"
    elseif not isolated(guard) then
        return "other guard close by"
    elseif angle_from_front(guard, pos) < AMBUSH_REAR_ANGLE then
        return "bot not behind the guard"
    elseif guard_sees(guard, ld, self._unit:movement():m_head_pos()) then
        return "guard sees the bot"
    elseif exposed(nil, guard:movement():m_head_pos(), guard) then
        return "another guard sees the target"
    end
end

function TeamAIMovement:_bhfr_find_ambush_target(player_unit)
    local best, best_dis

    for _, enemy in pairs(managers.enemy:all_enemies()) do
        local guard = enemy.unit
        local dis = alive(guard) and mvec3_dis(self._unit:position(), guard:position())

        if dis and (not best_dis or (dis < best_dis)) and not self:bhfr_ambush_block_reason(guard, player_unit) then
            best, best_dis = guard, dis
        end
    end

    return best
end

-- the one guard that is about to notice this bot, if it can be reached and hit before it does
function TeamAIMovement:_bhfr_find_rush_target(t)
    local bot_key = self._unit:key()
    local head = self._unit:movement():m_head_pos()
    local culprit

    for _, enemy in pairs(managers.enemy:all_enemies()) do
        local guard = enemy.unit
        local ld = alive(guard) and guard:brain() and guard:brain()._logic_data

        if ld and ld.cool and ld.detected_attention_objects then
            local noticed = ld.detected_attention_objects[bot_key]
            local cone = guard_cone(guard, ld, head, TOLERANT_ANGLE_MARGIN, TOLERANT_RANGE_MARGIN)

            if (noticed and (noticed.identified or ((noticed.notice_progress or 0) > TOLERANT_NOTICE))) or (cone and (cone <= TOLERANT_MAX_CONE)) then
                if culprit then
                    return nil -- more than one: nobody gets out of this by hitting a single guard
                end
                culprit = { guard = guard, ld = ld, noticed = noticed, cone = cone }
            end
        end
    end

    if not culprit or not ambush_target_ok(culprit.guard) or (culprit.noticed and culprit.noticed.identified) then
        return nil
    end

    local guard = culprit.guard
    local dis = mvec3_dis(self._unit:position(), guard:position())
    if dis > RUSH_MAX_DIS then
        return nil
    end

    local progress = culprit.noticed and culprit.noticed.notice_progress or 0
    local vision = culprit.ld.internal_data.vision
    local speed_mul = vision["cone_" .. (culprit.cone or 1)].speed_mul
    local remaining = (1 - progress) * speed_mul / BotsHaveFeelingsReborn.BOT_NOTICE_DELAY_MUL
    local need = math.max(dis - AMBUSH_STRIKE_DIS, 0) / RUSH_SPEED

    -- nobody else may see the guard or the bot
    if (need > (remaining * RUSH_SAFETY)) or exposed(nil, guard:movement():m_head_pos(), guard, true) or exposed(nil, head, guard, true) then
        return nil
    end

    return guard, need
end

function TeamAIMovement:_bhfr_find_panic_target()
    local bot_key = self._unit:key()
    local here = self._unit:position()
    local best, best_progress, best_need

    for _, enemy in pairs(managers.enemy:all_enemies()) do
        local guard = enemy.unit
        local ld = alive(guard) and guard:brain() and guard:brain()._logic_data
        local noticed = ld and ld.cool and ld.detected_attention_objects and ld.detected_attention_objects[bot_key]
        local progress = noticed and not noticed.identified and noticed.notice_progress

        if progress and (progress >= PANIC_PROGRESS) and (not best_progress or (progress > best_progress)) and ambush_target_ok(guard) then
            local dis = mvec3_dis(here, guard:position())
            if dis <= PANIC_DIS then
                local cone = guard_cone(guard, ld, self._unit:movement():m_head_pos(), TOLERANT_ANGLE_MARGIN, TOLERANT_RANGE_MARGIN) or 1
                local remaining = (1 - progress) * ld.internal_data.vision["cone_" .. cone].speed_mul / BotsHaveFeelingsReborn.BOT_NOTICE_DELAY_MUL
                local need = math.max(dis - AMBUSH_STRIKE_DIS, 0) / RUSH_SPEED

                if need <= (remaining * PANIC_SAFETY) then
                    best, best_progress, best_need = guard, progress, need
                end
            end
        end
    end

    return best, best_need
end

function TeamAIMovement:_bhfr_rush_start(guard, need, panic)
    if self:_bhfr_hold_at(guard:position(), 50, "stand", "run") then
        local t = TimerManager:game():time()
        self._bhfr_ambush = { guard = guard, start_t = t, rush = true, panic = panic, deadline = t + (need * 1.5) + 1.5 }
        self:_bhfr_set_action("ambush")
    end
end

function TeamAIMovement:_bhfr_ambush_start(guard)
    if self:_bhfr_hold_at(guard:position(), 50) then
        self._bhfr_ambush = {
            guard = guard,
            start_t = TimerManager:game():time(),
            guard_pos = mvector3.copy(guard:position()),
            guard_yaw = guard:movement():m_head_rot():yaw(),
        }
        self:_bhfr_set_action("ambush")
    end
end

-- true while the ambush is running
function TeamAIMovement:_bhfr_ambush_update(t)
    local ambush = self._bhfr_ambush
    local guard = ambush.guard

    if ambush.rush then
        local noticed = alive(guard) and guard:brain()._logic_data.detected_attention_objects[self._unit:key()]
        local dis = alive(guard) and mvec3_dis(self._unit:position(), guard:position())

        local give_up = not ambush_target_ok(guard) or (t > ambush.deadline)
        if not ambush.panic then
            give_up = give_up or (dis >= AMBUSH_STRIKE_DIS and noticed and (noticed.identified or ((noticed.notice_progress or 0) >= RUSH_ABORT_PROGRESS))) or
                exposed(nil, guard:movement():m_head_pos(), guard, true)
        end

        if give_up then
            -- too late or somebody else shows up: call it off and get away
            self:_bhfr_ambush_end(AMBUSH_COOLDOWN * 2)
            self:_bhfr_avoid_start()
        elseif dis < AMBUSH_STRIKE_DIS then
            melee_strike(self._unit, guard)
            self:_bhfr_ambush_end()
        end

        return true
    end

    if not ambush_target_ok(guard) or ((t - ambush.start_t) > AMBUSH_TIMEOUT) then
        self:_bhfr_ambush_end()
        return true
    end

    local head = self._unit:movement():m_head_pos()
    local ld = guard:brain()._logic_data
    local yaw_diff = math.abs((guard:movement():m_head_rot():yaw() - ambush.guard_yaw + 180) % 360 - 180)
    local risky = (ld.name ~= "idle") or
        (mvec3_dis(guard:position(), ambush.guard_pos) > AMBUSH_GUARD_MOVED_DIS) or (yaw_diff > AMBUSH_GUARD_TURNED) or
        (angle_from_front(guard, self._unit:position()) < AMBUSH_REAR_ANGLE) or not isolated(guard) or
        guard_sees(guard, ld, head) or exposed(nil, guard:movement():m_head_pos(), guard) or exposed(self._unit, head, guard)

    if risky then
        -- the guard moved or looks round, or somebody else turns up: call it off and get out of sight
        self:_bhfr_ambush_end(AMBUSH_COOLDOWN * 2)
        self:_bhfr_avoid_start()
        return true
    end

    if mvec3_dis(self._unit:position(), guard:position()) < AMBUSH_STRIKE_DIS then
        melee_strike(self._unit, guard)
        self:_bhfr_ambush_end()
    end

    return true
end

Hooks:PostHook(TeamAIMovement, "update", "BHFR_TeamAIMovement_update_avoid",
    function(self)
        if not Network:is_server() then
            return
        end

        local t = TimerManager:game():time()
        if self._bhfr_avoid_next_t and (t < self._bhfr_avoid_next_t) then
            return
        end
        self._bhfr_avoid_next_t = t + (self._bhfr_ambush and AMBUSH_CHECK_INTERVAL or CHECK_INTERVAL)

        local active = BotsHaveFeelingsReborn:GetConfigOption("bots_avoid_guards") and
            managers.groupai:state():whisper_mode() and
            (self:bhfr_mode() == self.bhfr_modes.stealth_follow)

        if not active then
            local hold = self._bhfr_avoiding or self._bhfr_ambush or self._bhfr_detour
            self._bhfr_avoiding = nil
            self._bhfr_ambush = nil
            self._bhfr_detour = nil
            self._bhfr_hot_spot = nil
            self._bhfr_far_since = nil
            self._bhfr_avoid_starts = nil
            self._bhfr_detour_tries = nil
            self._bhfr_clear_t = nil
            self._bhfr_trail = nil
            self:_bhfr_set_action(nil)
            if hold then
                self:_bhfr_restore_follow()
            end
            return
        end

        track_gazes(t)

        if BotsHaveFeelingsReborn:GetConfigOption("bots_melee_guards") and not (self._bhfr_ambush and self._bhfr_ambush.panic) and
            not (self.is_carrying and self:is_carrying()) then
            local guard, need = self:_bhfr_find_panic_target()
            if guard then
                self._bhfr_avoiding = nil
                self._bhfr_detour = nil
                self._bhfr_ambush = nil
                self:_bhfr_rush_start(guard, need, true)
                return
            end
        end

        if self._bhfr_ambush then
            self:_bhfr_ambush_update(t)
            return
        end

        local pos = self._unit:position()
        local head = self._unit:movement():m_head_pos()
        local is_exposed = exposed(self._unit, head, nil, true)

        -- standing in a far cone for longer than the budget counts as exposed
        if not is_exposed and exposed(self._unit, head) then
            self._bhfr_far_since = self._bhfr_far_since or t
            is_exposed = (t - self._bhfr_far_since) > FAR_CONE_BUDGET
        else
            self._bhfr_far_since = nil
        end

        if self._bhfr_detour then
            if not is_exposed then
                self:_bhfr_trail_add(t, pos)
            end
            self:_bhfr_detour_update(t, is_exposed)
            return
        end

        -- a new trouble-free stretch gives the detours back
        if self._bhfr_detour_try_t and ((t - self._bhfr_detour_try_t) > (BLOCKED_WINDOW * 2)) then
            self._bhfr_detour_tries = 0
            self._bhfr_detour_try_t = nil
        end

        if self._bhfr_avoiding then
            -- the hold objective can get lost on the way: put it back
            local objective = self._unit:brain():objective()
            if not objective or (objective.type ~= "defend_area") then
                self:_bhfr_hold_at(self._bhfr_retreat_to, 50, "stand", "run")
            end

            local player = self:bhfr_following()
            if is_exposed then
                self._bhfr_clear_t = nil

                -- the spot turned unsafe, or the bot is there and still seen: go further back (never to a spot nearer than the last one)
                if (t - (self._bhfr_retreat_t or 0)) >= RETREAT_REPICK_INTERVAL then
                    self._bhfr_retreat_t = t
                    local target = self._bhfr_retreat_to
                    if not target or (mvec3_dis(self._unit:position(), target) < RETREAT_ARRIVED_DIS) or
                        exposed(nil, target + Vector3(0, 0, EYE_HEIGHT), nil, true) then
                        local entry = self:_bhfr_retreat_entry(t, self._bhfr_retreat_entry_t)
                        if entry and self:_bhfr_hold_at(entry.pos, 50, "stand", "run") then
                            self._bhfr_retreat_to = entry.pos
                            self._bhfr_retreat_entry_t = entry.t
                        end
                    end
                end
            elseif alive(player) and exposed(nil, player:movement():m_head_pos(), nil, true) then
                -- the bot is hidden, but the player it follows is not: stay put until they are out of sight too
                self._bhfr_clear_t = nil
            elseif self._bhfr_hot_spot and ((t - self._bhfr_hot_spot.t) < HOT_SPOT_WAIT_MAX) and
                exposed(nil, self._bhfr_hot_spot.pos + Vector3(0, 0, EYE_HEIGHT), nil, true) then
                -- the place that drove us back is still covered: wait for the guards to look away
                self._bhfr_clear_t = nil
            elseif not self._bhfr_clear_t then
                self._bhfr_clear_t = t
            elseif (t - self._bhfr_clear_t) >= CLEAR_DELAY then
                -- repeatedly pushed back here? try to find a way round before following on
                if not self:_bhfr_detour_start(t) then
                    self:_bhfr_avoid_end()
                end
            end
        elseif is_exposed then
            local rush_target, need
            if BotsHaveFeelingsReborn:GetConfigOption("bots_melee_guards") and not (self.is_carrying and self:is_carrying()) then
                rush_target, need = self:_bhfr_find_rush_target(t)
            end

            if rush_target then
                self:_bhfr_rush_start(rush_target, need)
            else
                self:_bhfr_avoid_start()
            end
        else
            self:_bhfr_trail_add(t, pos)

            if BotsHaveFeelingsReborn:GetConfigOption("bots_melee_guards") and
                (not self._bhfr_ambush_next_t or (t >= self._bhfr_ambush_next_t)) and
                not (self.is_carrying and self:is_carrying()) then
                self._bhfr_ambush_next_t = t + AMBUSH_SEARCH_INTERVAL

                local guard = self:_bhfr_find_ambush_target(self:bhfr_following())
                if guard then
                    self:_bhfr_ambush_start(guard)
                end
            end
        end
    end
)
