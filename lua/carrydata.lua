-- bots_can_catch

local can_secure_original = CarryData.can_secure

function CarryData:start_bot_carry_catch()
	self._bot_try_catch_t = TimerManager:game():time()
	self._unit:set_extension_update_enabled(self.IDS_CARRY_DATA, true) -- enable update()
end

function CarryData:stop_bot_carry_catch()
	self._bot_try_catch_t = nil
	self._unit:set_extension_update_enabled(self.IDS_CARRY_DATA, false) -- disable update()
end

Hooks:PostHook(CarryData, "update", "BHFR_CarryData_update",
	function(self)
		if not self:can_secure() or not self._bot_try_catch_t or (TimerManager:game():time() - self._bot_try_catch_t) > tweak_data.ai_carry.catch_timeout then
			self:stop_bot_carry_catch()
		elseif self._unit:interaction() and self._unit:interaction():active() then
			local _all_AI_criminals = managers.groupai:state():all_AI_criminals() or {}
			for _, data in pairs(_all_AI_criminals) do
				if data.unit and alive(data.unit) then
					if data.unit:movement():downed() or
						data.unit:movement().vehicle_unit or
						not data.unit:movement().add_carry_unit or
						mvector3.distance(self._unit:position(), data.unit:position()) > tweak_data.ai_carry.throw_force then
						-- skip
					elseif data.unit:movement():add_carry_unit(self._unit) then
						self:link_to(data.unit)
						break
					end
				end
			end
		end
	end
)

Hooks:PostHook(CarryData, "save", "BHFR_CarryData_save",
	function(self, data)
		if Network:is_server() and self._linked_to then
			managers.enemy:add_delayed_clbk("send_loot_link" .. tostring(self._unit:key()),
				callback(self, self, "clbk_send_bot_carry_link"), TimerManager:game():time() + 0.1)
		end
	end
)

function CarryData:clbk_send_bot_carry_link()
	if Network:is_server() and alive(self._unit) and self._linked_to then
		managers.network:session():send_to_peers_synched("loot_link", self._unit, self._linked_to)
	end
end

Hooks:PostHook(CarryData, "link_to", "BHFR_CarryData_link_to",
	function(self, parent_unit)
		self._linked_to = parent_unit
	end
)

Hooks:PostHook(CarryData, "unlink", "BHFR_CarryData_unlink",
	function(self)
		self:on_carry_unlinked()
	end
)

Hooks:PostHook(CarryData, "on_pickup", "BHFR_CarryData_on_pickup",
	function(self)
		self:on_carry_unlinked()
	end
)

function CarryData:on_carry_unlinked()
	if self._linked_to and self._linked_to:movement() and self._linked_to:movement().remove_carry_unit then
		self._linked_to:movement():remove_carry_unit(self._unit)
	end
	self._linked_to = nil
end

function CarryData:is_linked()
	return self._linked_to ~= nil
end

function CarryData:can_secure(...)
	if self:is_linked() then -- prevent vehicles from catching, if a bot did already
		return false
	end
	return can_secure_original(self, ...)
end
