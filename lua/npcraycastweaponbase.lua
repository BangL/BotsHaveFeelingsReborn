-- local setup_original = NPCRaycastWeaponBase.setup

-- function NPCRaycastWeaponBase:setup(setup_data, ...)
-- 	setup_original(self, setup_data, ...)
-- 	local user_unit = setup_data.user_unit
-- 	if user_unit and user_unit:in_slot(16) then
-- 		self._bullet_slotmask = self._bullet_slotmask - World:make_slot_mask(16, 22)
-- 	end
-- end
