-- bots_no_unnecessary_revive

-- who is reviving this unit: local revivers (host player, bots) by unit key, and
-- a flag for revivers on other machines. one flag is not enough, a bot we stop
-- interrupts its revive and that must not end the revive of somebody else.
Hooks:PreHook(ReviveInteractionExt, "_at_interact_start", "BHFR_ReviveInteractionExt_at_interact_start",
	function(self, player)
		local key = alive(player) and player:key() or nil

		self._bhfr_revivers = self._bhfr_revivers or {}
		self._bhfr_revivers[key or "?"] = true
		-- read by set_waypoint_paused, which this call leads to
		self._bhfr_starter_key = key or "?"
	end
)

Hooks:PreHook(ReviveInteractionExt, "_at_interact_interupt", "BHFR_ReviveInteractionExt_at_interact_interupt",
	function(self, player)
		if self._bhfr_revivers then
			self._bhfr_revivers[alive(player) and player:key() or "?"] = nil
		end

		self._bhfr_interrupting = true
	end
)

Hooks:PostHook(ReviveInteractionExt, "_at_interact_interupt", "BHFR_ReviveInteractionExt_at_interact_interupt_done",
	function(self)
		self._bhfr_interrupting = nil
	end
)

-- paused = somebody started / stopped reviving this unit (synced to all peers,
-- so this also covers clients reviving)
Hooks:PostHook(ReviveInteractionExt, "set_waypoint_paused", "BHFR_ReviveInteractionExt_set_waypoint_paused",
	function(self, paused)
		local starter_key = self._bhfr_starter_key

		self._bhfr_starter_key = nil

		if not paused then
			-- a stop from the network ends the remote revive, an interruption here only ends its own
			if not self._bhfr_interrupting then
				self._bhfr_remote_reviving = nil
			end

			if self._bhfr_remote_reviving or (self._bhfr_revivers and next(self._bhfr_revivers)) then
				self._bhfr_revive_t = TimerManager:game():time()
			else
				self._bhfr_revive_t = nil
			end

			return
		end

		if not starter_key then
			self._bhfr_remote_reviving = true
		end

		self._bhfr_revive_t = TimerManager:game():time()

		if BotsHaveFeelingsReborn:GetConfigOption("bots_no_unnecessary_revive") and Network:is_server() and managers.groupai then
			local ai_criminals = managers.groupai:state():all_AI_criminals()
			local starter_is_bot = starter_key and ai_criminals[starter_key]

			-- bots on their way (or already at it, if a human starts) stop, BlockRevivesInProgress keeps them from retrying
			for u_key, u_data in pairs(ai_criminals) do
				local unit = u_data.unit
				if alive(unit) and not (starter_is_bot and (u_key == starter_key)) then
					local brain = unit:brain()
					local data = brain and brain._logic_data
					local obj = data and data.objective
					if obj and (obj.type == "revive") and obj.follow_unit and (obj.follow_unit:key() == self._unit:key()) then
						brain:set_objective()
					end
				end
			end
		end
	end
)

-- monkeepers_mode: remember where a player picked a bag up

Hooks:PreHook(CarryInteractionExt, "sync_interacted", "BHFR_CarryInteractionExt_sync_interacted",
	function(self, peer, player)
		local monkeepers = BotsHaveFeelingsReborn.Monkeepers

		if monkeepers and monkeepers:enabled() then
			monkeepers:on_pickup(self._unit, peer, player)
		end
	end
)
