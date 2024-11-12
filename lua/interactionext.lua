-- bots_no_unnecessary_revive

local _at_interact_start_original = ReviveInteractionExt._at_interact_start

function ReviveInteractionExt:_at_interact_start(player, timer, ...)
	_at_interact_start_original(self, player, timer, ...)
	if BotsHaveFeelingsReborn:GetConfigOption("bots_no_unnecessary_revive") and Network:is_server()
		and managers.groupai and (self.tweak_data == "revive" or self.tweak_data == "free") then
		for u_key, u_data in pairs(managers.groupai:state():all_AI_criminals()) do
			local unit = u_data.unit
			if alive(unit) and u_key ~= player:key() then
				local brain = unit:brain()
				if brain then
					local data = brain._logic_data
					if data then
						local obj = data.objective
						if obj and obj.type == "revive" then
							local follow_unit = obj.follow_unit
							if follow_unit and follow_unit:key() == self._unit:key() then
								brain:set_objective()
							end
						end
					end
				end
			end
		end
	end
end
