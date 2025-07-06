-- -- bots_can_catch debug

-- local _get_long_distance_action_original = PlayerStandard._get_long_distance_action
-- function PlayerStandard:_get_long_distance_action(prime_target, char_table, intimidation_amount, primary_only,
--                                                   detect_only, ...)
--     if (not detect_only) and prime_target and prime_target.unit:in_slot(16, 24) then
--         local is_ok, is_teammate_ai
--         local unit = prime_target.unit

--         local record = managers.groupai:state():all_criminals()[unit:key()]
--         if record and record.ai then
--             is_teammate_ai = true
--             local dmg = unit:character_damage()
--             is_ok = not dmg:need_revive()
--         end

--         if is_ok then
--             if is_teammate_ai and unit:movement():is_carrying() and Network:is_server() then
--                 -- tell bot to drop bags
--                 unit:movement():drop_all_carry()
--                 return "down", false, prime_target
--             end
--         end
--     end

--     return _get_long_distance_action_original(self, prime_target, char_table, intimidation_amount, primary_only,
--         detect_only, ...)
-- end
