-- make sure bots drop bags before a bot despawns
-- TODO?: only drop the bag of the removed bot, if possible

Hooks:PreHook(GroupAIStateBase, "remove_one_teamAI", "BHFR_GroupAIStateBase_remove_one_teamAI",
	function(self, name_to_remove, replace_with_player)
		local _all_AI_criminals = self:all_AI_criminals() or {}
		for _, data in pairs(_all_AI_criminals) do
			if data.unit and alive(data.unit) and data.unit:movement():carrying_bag() then
				data.unit:movement():throw_bag()
			end
		end
	end
)
