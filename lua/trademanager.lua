-- bot respawn timer on the teammate panel

Hooks:PostHook(TradeManager, "on_AI_criminal_death", "BHFR_TradeManager_on_AI_criminal_death",
	function(self, criminal_name)
		local crim_data = managers.criminals:character_data_by_name(criminal_name)

		if crim_data and crim_data.panel_id and managers.hud then
			managers.hud:set_bot_respawn_timer(crim_data.panel_id, criminal_name)
		end
	end
)
