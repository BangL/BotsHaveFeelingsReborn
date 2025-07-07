-- bots_can_catch

tweak_data.ai_carry = {
	throw_force = 150,
	catch_timeout = 5
}

TeamAIMovement.CLASS_MAP = {
	["american"] = "assault",
	["german"] = "demolitions",
	["russian"] = "infiltrator",
	["british"] = "recon",
}

function TeamAIMovement:is_carrying()
	if self._carry_units and not table.empty(self._carry_units) then
		return true
	end

	return false
end

function TeamAIMovement:add_carry_unit(unit)
	local carry_id = unit:carry_data():carry_id()
	local carry_tweak = tweak_data.carry[carry_id]
	if self:can_carry_weight(carry_id) then
		self._carry_units = self._carry_units or {}
		self._carry_units[unit:id()] = unit
		self:modify_carry_weight(carry_tweak and carry_tweak.weight or tweak_data.carry.default_bag_weight)
		return true
	end
	return false
end

function TeamAIMovement:remove_carry_unit(unit)
	if self:is_carrying() then
		local carry_id = unit:carry_data():carry_id()
		local carry_tweak = tweak_data.carry[carry_id]
		self._carry_units[unit:id()] = nil
		self:modify_carry_weight(-(carry_tweak and carry_tweak.weight or tweak_data.carry.default_bag_weight))
	end
end

function TeamAIMovement:can_carry_weight(carry_id)
	local carry_tweak = tweak_data.carry[carry_id]

	return not carry_tweak.skip_exit_secure and (self:get_my_carry_weight_limit() >=
		(self:get_my_carry_weight() + (carry_tweak and carry_tweak.weight or tweak_data.carry.default_bag_weight)))
end

function TeamAIMovement:get_my_carry_weight()
	return self._carry_weight or 0
end

function TeamAIMovement:get_my_carry_weight_limit()
	local nationality = managers.criminals:character_name_by_unit(self._unit) or "british"
	local class_tweak_data = tweak_data.player:get_tweak_data_for_class(self.CLASS_MAP[nationality] or "assault")
	return class_tweak_data.movement.carry.CARRY_WEIGHT_MAX or 5
end

function TeamAIMovement:drop_all_carry()
	if self:is_carrying() then
		for _, unit in pairs(self._carry_units) do
			if unit and alive(unit) and unit:carry_data() then
				unit:carry_data():unlink()
			end
		end
	end
	self._carry_units = {}
	self:modify_carry_weight(0, true)
end

-- bots_secure_carried

function TeamAIMovement:secure_all_carry()
	if self:is_carrying() then
		for _, unit in pairs(self._carry_units) do
			if unit and alive(unit) then
				local carry_id = unit:carry_data():carry_id()
				local carry_tweak = tweak_data.carry[carry_id]
				unit:carry_data():unlink()
				if BotsHaveFeelingsReborn:GetConfigOption("bots_secure_carried") and (carry_tweak.loot_value or carry_tweak.loot_outlaw_value) then
					managers.loot:server_secure_loot(carry_id, unit:carry_data():multiplier(),
						false)
				end
				unit:set_slot(0)
			end
		end
	end
	self._carry_units = {}
	self:modify_carry_weight(0, true)
end

function TeamAIMovement:modify_carry_weight(current, abs)
	if current and abs then
		self._carry_weight = current
	elseif self:is_carrying() and current and not abs then
		self._carry_weight = math.round(self:get_my_carry_weight() + current)
	else
		self._carry_weight = 0
	end

	local max = self:get_my_carry_weight_limit()

	local unit_data = self._unit:unit_data()
	if unit_data and managers.hud and unit_data.teammate_panel_id and unit_data.name_label_id then
		-- update GUI
		managers.hud:set_bot_carry_weight(unit_data.teammate_panel_id, unit_data.name_label_id,
			self._carry_weight, max)
	end

	if Network:is_server() and BotsHaveFeelingsReborn.Sync then
		-- update clients
		local name = managers.criminals:character_name_by_unit(self._unit)
		BotsHaveFeelingsReborn.Sync:send_to_known_peers(BotsHaveFeelingsReborn.Sync.events.bot_carry_weight, {
			name = name,
			current = self._carry_weight,
			max = max
		}, name)
	end
end
