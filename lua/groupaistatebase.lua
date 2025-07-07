-- bots_can_catch
-- make sure bots drop bags before a bot despawns when replaced by dropin

Hooks:PreHook(GroupAIStateBase, "sync_remove_one_criminal_ai", "BHFR_GroupAIStateBase_sync_remove_one_criminal_ai",
	function(self, name, replace_with_player)
		local unit = managers.criminals:character_unit_by_name(name)
		if unit and alive(unit) then
			unit:movement():drop_all_carry()
		end
	end
)
