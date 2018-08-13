--[[--------------------------------------------------------------------
	PhanxChat
	Reduces chat frame clutter and enhances chat frame functionality.
	Copyright (c) 2006-2014 Phanx <addons@phanx.net>. All rights reserved.
	https://www.wowinterface.com/downloads/info6323-PhanxChat.html
	https://www.curseforge.com/wow/addons/phanxchat
	https://github.com/phanx-wow/PhanxChat
----------------------------------------------------------------------]]

local PHANXCHAT, PhanxChat = ...

PhanxChat.OptionsPanel = LibStub("PhanxConfig-OptionsPanel").CreateOptionsPanel(PHANXCHAT, nil, function(self)
	local L = PhanxChat.L
	local db = PhanxChat.db
	local NEW = " |TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:0|t"

	local title, notes = self:CreateHeader(self.name, GetAddOnMetadata(PHANXCHAT, "Notes"))

	--------------------------------------------------------------------
	-- Frame options

	local HideButtons = self:CreateCheckbox(L.HideButtons, L.HideButtons_Desc)
	HideButtons:SetPoint("TOPLEFT", notes, "BOTTOMLEFT", -2, -8)
	function HideButtons:OnValueChanged(value)
		if PhanxChat.debug then print("PhanxChat: SetHideButtons", value) end
		PhanxChat:SetHideButtons(value)
	end

	local HideTextures = self:CreateCheckbox(L.HideTextures, L.HideTextures_Desc)
	HideTextures:SetPoint("TOPLEFT", HideButtons, "BOTTOMLEFT", 0, -8)
	function HideTextures:OnValueChanged(value)
		if PhanxChat.debug then print("PhanxChat: SetHideTextures", value) end
		PhanxChat:SetHideTextures(value)
	end

	local HideFlash = self:CreateCheckbox(L.HideFlash, L.HideFlash_Desc)
	HideFlash:SetPoint("TOPLEFT", HideTextures, "BOTTOMLEFT", 0, -8)
	function HideFlash:OnValueChanged(value)
		if PhanxChat.debug then print("PhanxChat: SetHideFlash", value) end
		PhanxChat:SetHideFlash(value)
	end

	local LockTabs = self:CreateCheckbox(L.LockTabs, L.LockTabs_Desc)
	LockTabs:SetPoint("TOPLEFT", HideFlash, "BOTTOMLEFT", 0, -8)
	function LockTabs:OnValueChanged(value)
		if PhanxChat.debug then print("PhanxChat: SetLockTabs", value) end
		PhanxChat:SetLockTabs(value)
	end

	local RemoveHoverDelay = self:CreateCheckbox(REMOVE_CHAT_DELAY_TEXT)
	RemoveHoverDelay:SetPoint("TOPLEFT", LockTabs, "BOTTOMLEFT", 0, -8)
	function RemoveHoverDelay:OnValueChanged(value)
		if PhanxChat.debug then print("PhanxChat: removeChatDelay", value) end
		SetCVar("removeChatDelay", value and "1" or "0")
	end
	
	local ScrollWheel = self:CreateCheckbox(CHAT_MOUSE_WHEEL_SCROLL, OPTION_TOOLTIP_CHAT_MOUSE_WHEEL_SCROLL)
	ScrollWheel:SetPoint("TOPLEFT", RemoveHoverDelay, "BOTTOMLEFT", 0, -8)
	function ScrollWheel:OnValueChanged(value)
		if PhanxChat.debug then print("PhanxChat: chatMouseScroll", value) end
		SetCVar("chatMouseScroll", value and "1" or "0")
	end

	local EnableResizeEdges = self:CreateCheckbox(L.EnableResizeEdges, L.EnableResizeEdges_Desc)
	EnableResizeEdges:SetPoint("TOPLEFT", ScrollWheel, "BOTTOMLEFT", 0, -8)
	function EnableResizeEdges:OnValueChanged(value)
		if PhanxChat.debug then print("PhanxChat: SetEnableResizeEdges", value) end
		PhanxChat:SetEnableResizeEdges(value)
	end

	--------------------------------------------------------------------
	-- Edit box options

	local EnableArrows = self:CreateCheckbox(L.EnableArrows, L.EnableArrows_Desc)
	EnableArrows:SetPoint("TOPLEFT", EnableResizeEdges, "BOTTOMLEFT", 0, -8) -- TODO add space
	function EnableArrows:OnValueChanged(value)
		if PhanxChat.debug then print("PhanxChat: EnableArrows", value) end
		PhanxChat:SetEnableArrows(value)
	end

	local MoveEditBox = self:CreateCheckbox(L.MoveEditBox, L.MoveEditBox_Desc)
	MoveEditBox:SetPoint("TOPLEFT", EnableArrows, "BOTTOMLEFT", 0, -8)
	function MoveEditBox:OnValueChanged(value)
		if PhanxChat.debug then print("PhanxChat: SetMoveEditBox", value) end
		PhanxChat:SetMoveEditBox(value)
	end

	local EnableSticky = self:CreateDropdown(L.EnableSticky, L.EnableSticky_Desc, {
		{ value = "ALL", text = L.All },
		{ value = "BLIZZARD", text = L.Default },
		{ value = "NONE", text = L.None },
	})
	EnableSticky:SetPoint("TOPLEFT", MoveEditBox, "BOTTOMLEFT", 0, -14)
	EnableSticky:SetWidth(200)

	function EnableSticky:OnValueChanged(value, text)
		if PhanxChat.debug then print("PhanxChat: SetEnableSticky", value) end
		PhanxChat:SetEnableSticky(value)
	end

	--------------------------------------------------------------------

	local FadeTime = self:CreateSlider(L.FadeTime, L.FadeTime_Desc, 0, 5, 0.25, nil, true)
	FadeTime:SetPoint("TOPLEFT", EnableSticky, "BOTTOMLEFT", 2, -14)
	FadeTime:SetWidth(200)
	function FadeTime:OnValueChanged(value)
		if PhanxChat.debug then print("PhanxChat: SetFadeTime", value) end
		PhanxChat:SetFadeTime(value)
		return value
	end

	local MINUTES_AND_SECONDS = MINUTE_ONELETTER_ABBR .. " " .. SECOND_ONELETTER_ABBR
	function FadeTime.valueText:SetText(text)
		local v = self:GetParent():GetValue()
		if PhanxChat.debug then print(type(v), tostring(v), "SetText", type(text), tostring(text)) end
		local m = floor(text)
		local s = 60 * (text - m)
		if m > 0 and s > 0 then
			self:SetFormattedText(MINUTES_AND_SECONDS, m, s)
		elseif m > 0 then
			self:SetFormattedText(MINUTE_ONELETTER_ABBR, m)
		elseif s > 0 then
			self:SetFormattedText(SECOND_ONELETTER_ABBR, s)
		else
			self:SetFormattedText(VIDEO_OPTIONS_DISABLED) -- use instead of SetText to avoid infinite loop
		end
	end

	--------------------------------------------------------------------

	local HidePetCombatLog = self:CreateCheckbox(L.HidePetCombatLog, L.HidePetCombatLog_Desc)
	HidePetCombatLog:SetPoint("TOPLEFT", notes, "BOTTOM", 2, -8)
	function HidePetCombatLog:OnValueChanged(value)
		if PhanxChat.debug then print("PhanxChat: HidePetCombatLog", value) end
		db.HidePetCombatLog = value
	end

	--------------------------------------------------------------------
	-- Message options

	local HideNotices = self:CreateCheckbox(L.HideNotices, L.HideNotices_Desc)
	HideNotices:SetPoint("TOPLEFT", HidePetCombatLog, "BOTTOMLEFT", 0, -8)
	function HideNotices:OnValueChanged(value)
		if PhanxChat.debug then print("PhanxChat: SetHideNotices", value) end
		PhanxChat:SetHideNotices(value)
	end

	local HideRepeats = self:CreateCheckbox(L.HideRepeats, L.HideRepeats_Desc)
	HideRepeats:SetPoint("TOPLEFT", HideNotices, "BOTTOMLEFT", 0, -8)
	function HideRepeats:OnValueChanged(value)
		if PhanxChat.debug then print("PhanxChat: SetHideRepeats", value) end
		PhanxChat:SetHideRepeats(value)
	end

	local LinkURLs = self:CreateCheckbox(L.LinkURLs, L.LinkURLs_Desc)
	LinkURLs:SetPoint("TOPLEFT", HideRepeats, "BOTTOMLEFT", 0, -8)
	function LinkURLs:OnValueChanged(value)
		if PhanxChat.debug then print("PhanxChat: SetLinkURLs", value) end
		PhanxChat:SetLinkURLs(value)
	end

	local ShortenChannelNames = self:CreateCheckbox(L.ShortenChannelNames, L.ShortenChannelNames_Desc)
	ShortenChannelNames:SetPoint("TOPLEFT", LinkURLs, "BOTTOMLEFT", 2, -8)
	function ShortenChannelNames:OnValueChanged(value)
		if PhanxChat.debug then print("PhanxChat: ShortenChannelNames", value) end
		PhanxChat:SetShortenChannelNames(value)
	end

	--------------------------------------------------------------------
	-- Player name options

	local ShowClassColors = self:CreateCheckbox(L.ShowClassColors, L.ShowClassColors_Desc)
	ShowClassColors:SetPoint("TOPLEFT", ShortenChannelNames, "BOTTOMLEFT", 0, -8)
	function ShowClassColors:OnValueChanged(value)
		if PhanxChat.debug then print("PhanxChat: SetShowClassColors", value) end
		PhanxChat:SetShowClassColors(value)
		PhanxChat:SetReplaceRealNames() -- need to flush the bnetName cache
	end

	local RemoveRealmNames = self:CreateCheckbox(L.RemoveRealmNames, L.RemoveRealmNames_Desc)
	RemoveRealmNames:SetPoint("TOPLEFT", ShowClassColors, "BOTTOMLEFT", 0, -8)
	function RemoveRealmNames:OnValueChanged(value)
		if PhanxChat.debug then print("PhanxChat: RemoveRealmNames", value) end
		db.RemoveRealmNames = value
	end

	local ReplaceRealNames = self:CreateCheckbox(L.ReplaceRealNames, L.ReplaceRealNames_Desc)
	ReplaceRealNames:SetPoint("TOPLEFT", RemoveRealmNames, "BOTTOMLEFT", 0, -8)
	function ReplaceRealNames:OnValueChanged(value)
		if PhanxChat.debug then print("PhanxChat: ReplaceRealNames", value) end
		PhanxChat:SetReplaceRealNames(value)
	end

	local ShortenRealNames = self:CreateDropdown(L.ShortenRealNames, L.ShortenRealNames_Desc, {
		{ value = "BATTLETAG", text = L.ShortenRealNames_UseBattleTag },
		{ value = "FIRSTNAME", text = L.ShortenRealNames_UseFirstName },
		{ value = "FULLNAME",  text = L.ShortenRealNames_UseFullName },
	})
	ShortenRealNames:SetPoint("TOPLEFT", ReplaceRealNames, "BOTTOMLEFT", 0, -14)
	ShortenRealNames:SetWidth(200)

	function ShortenRealNames:OnValueChanged(value, text)
		if PhanxChat.debug then print("PhanxChat: ShortenRealNames", value) end
		PhanxChat:SetReplaceRealNames(value)
	end

	--------------------------------------------------------------------

	local FontSize = self:CreateSlider(L.FontSize, L.FontSize_Desc .. "\n\n" .. L.FontSize_Note, 8, 24, 1)
	FontSize:SetPoint("TOPLEFT", ShortenRealNames, "BOTTOMLEFT", 0, -14)
	FontSize:SetWidth(200)
	function FontSize:OnValueChanged(value)
		if PhanxChat.debug then print("PhanxChat: FCF_SetChatWindowFontSize", value) end
		db.FontSize = value
		for frame in pairs(PhanxChat.frames) do
			FCF_SetChatWindowFontSize(nil, frame, value)
		end
	end

	--------------------------------------------------------------------

	local LineSpacing = self:CreateSlider("Line Spacing", nil, 0, 5, 1)
	LineSpacing:SetPoint("TOPLEFT", FontSize, "BOTTOMLEFT", 0, -14)
	LineSpacing:SetWidth(200)
	function LineSpacing:OnValueChanged(value)
		db.LineSpacing = value
		for frame in pairs(PhanxChat.frames) do
			frame:SetSpacing(value)
		end
	end

	--------------------------------------------------------------------

	local bnetValues = {
		BATTLETAG = L.ShortenRealNames_UseBattleTag,
		FIRSTNAME = L.ShortenRealNames_UseFirstName,
		FULLNAME = L.ShortenRealNames_UseFullName,
	}
	local stickyValues = {
		ALL = L.All,
		BLIZZARD = L.Default,
		NONE = L.None,
	}

	self.refresh = function(self)
		ShortenChannelNames:SetChecked(db.ShortenChannelNames)
		ShowClassColors:SetChecked(db.ShowClassColors)
		RemoveRealmNames:SetChecked(db.RemoveRealmNames)
		ReplaceRealNames:SetChecked(db.ReplaceRealNames)
		ShortenRealNames:SetValue(db.ShortenRealNames, bnetValues[db.ShortenRealNames])
		EnableArrows:SetChecked(db.EnableArrows)
		EnableResizeEdges:SetChecked(db.EnableResizeEdges)
		LinkURLs:SetChecked(db.LinkURLs)
		LockTabs:SetChecked(db.LockTabs)
		MoveEditBox:SetChecked(db.MoveEditBox)
		HideNotices:SetChecked(db.HideNotices)
		HideRepeats:SetChecked(db.HideRepeats)

		HidePetCombatLog:SetChecked(db.HidePetCombatLog)
		HideButtons:SetChecked(db.HideButtons)
		HideTextures:SetChecked(db.HideTextures)
		HideFlash:SetChecked(db.HideFlash)
		EnableSticky:SetValue(db.EnableSticky, stickyValues[db.EnableSticky])
		FadeTime:SetValue(db.FadeTime)
		FontSize:SetValue(db.FontSize or floor(select(2, ChatFrame1:GetFont()) + 0.5))
		LineSpacing:SetValue(db.LineSpacing or 0)

		ScrollWheel:SetChecked(GetCVarBool("chatMouseScroll"))
		RemoveHoverDelay:SetChecked(GetCVarBool("removeChatDelay"))
	end

	self:refresh()
end)

------------------------------------------------------------------------
--	Slash command
------------------------------------------------------------------------

SLASH_PHANXCHAT1 = "/pchat"

SlashCmdList.PHANXCHAT = function(cmd)
	InterfaceOptionsFrame_OpenToCategory(PhanxChat.OptionsPanel)
end
