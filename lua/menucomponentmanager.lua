-- options menu

BotsHaveFeelingsRebornMenu = BotsHaveFeelingsRebornMenu or class(BLTMenu)

function BotsHaveFeelingsRebornMenu:Init(root)
	self._something_changed = false

	self:_MakeHeader()

	self:_MakeSeparator()

	self:_MakeOptionToggle("double_bot_health")
	self:_MakeOptionToggle("improve_bot_aim")
	self:_MakeOptionToggle("improve_bot_movement")
	self:_MakeOptionToggle("improve_bot_speed")

	self:_MakeSeparator()

	self:_MakeOptionToggle("bots_give_human_player_xp")

	self:_MakeSeparator()

	self:_MakeOptionToggle("bot_hurt_sound")

	self:_MakeSeparator()

	self:_MakeOptionToggle("bots_can_catch")
	self:_MakeOptionToggle("bots_have_strong_back")
	self:_MakeOptionToggle("bots_secure_carried")
	self:_MakeOptionToggle("shift_f_for_drop_all_carry")

	self:_MakeSeparator()

	self:_MakeOptionToggle("bots_can_follow_in_stealth")
	self:_MakeOptionToggle("toggle_follow_wait_f_shouts_stealth")
	self:_MakeOptionToggle("bots_are_undetectable")

	self:_MakeSeparator()

	self:_MakeOptionToggle("bots_can_wait_when_loud")
	self:_MakeOptionToggle("toggle_follow_wait_f_shouts_loud")

	self:_MakeSeparator()

	self:_MakeOptionToggle("send_comm_wheel_like_chat_messages")

	self:_MakeSeparator()
	self:_MakeSeparator()

	self:_MakeSeparator("bhfr_experimental", true)

	self:_MakeOptionToggle("bots_no_unnecessary_revive")
	self:_MakeOptionToggle("bots_throw_grenades")

	self:_MakeResetButton()
end

function BotsHaveFeelingsRebornMenu:_MakeHeader()
	self:Title({
		text = "bhfr_title",
	})
	self:Label({
		text = nil,
		localize = false,
		h = 8,
	})
end

function BotsHaveFeelingsRebornMenu:_MakeResetButton()
	self:LongRoundedButton2({
		name = "bhfr_reset",
		text = "bhfr_reset",
		localize = true,
		callback = callback(self, self, "Reset"),
		ignore_align = true,
		y = 832,
		x = 1472,
	})
end

function BotsHaveFeelingsRebornMenu:_MakeSeparator(text, localize)
	self:SubTitle({ text = text, localize = localize, y_offset = text and 0 or 8 })
end

function BotsHaveFeelingsRebornMenu:_MakeOptionToggle(option)
	local id = "bhfr_" .. option
	local btn_interact = managers.localization:btn_macro("interact", true) or
		managers.localization:get_default_macro("BTN_INTERACT")
	self:Toggle({
		name = id,
		text = managers.localization:text(id, { BTN_INTERACT = btn_interact }),
		localize = false,
		localized = false,
		desc = managers.localization:text(id .. "_desc", { BTN_INTERACT = btn_interact }),
		localize_desc = false,
		localized_desc = false,
		value = BotsHaveFeelingsReborn:GetConfigOption(option),
		callback = callback(self, self, "OnOptionChanged", option),
	})
end

function BotsHaveFeelingsRebornMenu:OnOptionChanged(option, value)
	if BotsHaveFeelingsReborn:SetConfigOption(option, value) then
		self._something_changed = true
	end
end

function BotsHaveFeelingsRebornMenu:Reset(value, item)
	QuickMenu:new(
		managers.localization:text("bhfr_reset"),
		managers.localization:text("bhfr_reset_confirm"),
		{
			[1] = {
				text = managers.localization:text("dialog_no"),
				is_cancel_button = true,
			},
			[2] = {
				text = managers.localization:text("dialog_yes"),
				callback = function()
					-- reset config
					BotsHaveFeelingsReborn:LoadConfigDefaults()
					BotsHaveFeelingsReborn:SaveConfig()
					-- reset menu
					self._something_changed = false
					self:ReloadMenu()
				end,
			},
		},
		true
	)
end

function BotsHaveFeelingsRebornMenu:Close()
	if self._something_changed then
		BotsHaveFeelingsReborn:SaveConfig()
	end
end

Hooks:Add("MenuComponentManagerInitialize", "BHFR_MenuComponentManagerInitialize",
	function(self)
		RaidMenuHelper:CreateMenu({
			name = "bhfr_options",
			name_id = "bhfr_title",
			inject_menu = "blt_options",
			class = BotsHaveFeelingsRebornMenu
		})
	end
)
