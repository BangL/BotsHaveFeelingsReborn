-- bots_no_unnecessary_revive

-- remember who starts the revive, so a reviving bot does not cancel itself
Hooks:PreHook(ReviveInteractionExt, "_at_interact_start", "BHFR_ReviveInteractionExt_at_interact_start",
	function(self, player)
		self._bhfr_reviver_key = alive(player) and player:key() or nil
	end
)

-- paused = somebody started / stopped reviving this unit (synced to all peers,
-- so this also covers clients reviving)
Hooks:PostHook(ReviveInteractionExt, "set_waypoint_paused", "BHFR_ReviveInteractionExt_set_waypoint_paused",
	function(self, paused)
		if not paused then
			self._bhfr_revive_t = nil
			self._bhfr_reviver_key = nil
			return
		end

		self._bhfr_revive_t = TimerManager:game():time()

		if BotsHaveFeelingsReborn:GetConfigOption("bots_no_unnecessary_revive") and Network:is_server() and managers.groupai then
			-- bots still on their way stop, BlockRevivesInProgress keeps them from retrying
			for u_key, u_data in pairs(managers.groupai:state():all_AI_criminals()) do
				local unit = u_data.unit
				if alive(unit) and (u_key ~= self._bhfr_reviver_key) then
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
