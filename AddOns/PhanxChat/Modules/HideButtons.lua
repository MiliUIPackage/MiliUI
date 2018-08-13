--[[--------------------------------------------------------------------
	PhanxChat
	Reduces chat frame clutter and enhances chat frame functionality.
	Copyright (c) 2006-2018 Phanx <addons@phanx.net>. All rights reserved.
	https://www.wowinterface.com/downloads/info6323-PhanxChat.html
	https://www.curseforge.com/wow/addons/phanxchat
	https://github.com/phanx-wow/PhanxChat
----------------------------------------------------------------------]]

local _, PhanxChat = ...
local L = PhanxChat.L

local noop = function() end

------------------------------------------------------------------------

function PhanxChat:HideButtons(frame)
	local name = frame:GetName()
	local buttonFrame = _G[name .. "ButtonFrame"]

	if self.db.HideButtons then
		buttonFrame.Show = noop
		buttonFrame:Hide()
	else
		buttonFrame.Show = nil
		buttonFrame:Show()
		-- TODO: remove if nothing is broken without it
		-- FCF_UpdateButtonSide(frame)
	end
end

------------------------------------------------------------------------

function PhanxChat:SetHideButtons(v)
	if self.debug then print("PhanxChat: SetHideButtons", v) end
	if type(v) == "boolean" then
		self.db.HideButtons = v
	end

	for frame in pairs(self.frames) do
		self:HideButtons(frame)
	end

	if self.db.HideButtons then
		ChatFrameChannelButton:SetScript("OnShow", ChatFrameChannelButton.Hide)
		ChatFrameChannelButton:Hide()

		ChatFrameMenuButton:SetScript("OnShow", ChatFrameMenuButton.Hide)
		ChatFrameMenuButton:Hide()

		QuickJoinToastButton:SetScript("OnShow", QuickJoinToastButton.Hide)
		QuickJoinToastButton:Hide()
	elseif not self.isLoading then
		ChatFrameChannelButton:SetScript("OnShow", nil)
		ChatFrameChannelButton:Show()

		ChatFrameMenuButton:SetScript("OnShow", nil)
		ChatFrameMenuButton:Show()

		QuickJoinToastButton:SetScript("OnShow", nil)
		QuickJoinToastButton:Show()
	end
end

BNToastFrame:SetClampedToScreen(true)

table.insert(PhanxChat.RunOnLoad, PhanxChat.SetHideButtons)
table.insert(PhanxChat.RunOnProcessFrame, PhanxChat.HideButtons)
