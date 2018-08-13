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
local hooks = PhanxChat.hooks

function PhanxChat:SetClampRectInsets(frame)
	if PhanxChat.db.MoveEditBox then
		frame:SetClampRectInsets(0, 25, 35, -5)
	else
		frame:SetClampRectInsets(0, 25, 35, -30)
	end
end

hooksecurefunc("FloatingChatFrame_UpdateBackgroundAnchors", function(self)
	PhanxChat:SetClampRectInsets(self)
end)

InterfaceOptionsSocialPanelChatStyle:HookScript("OnEnter", function(self)
	if PhanxChat.db.MoveEditBox then
		GameTooltip:AddLine(format(L.OptionLockedConditional, L.MoveEditBox), 1, 1, 1, true)
		GameTooltip:Show()
	end
end)

local function Insert(editBox, text)
	-- Remove annoying prepended spaces on shift-clicked links
	return hooks[editBox].Insert(editBox, strtrim(text))
end

function PhanxChat:MoveEditBox(frame)
	local editBox = frame.editBox or _G[frame:GetName() .. "EditBox"]
	if not editBox then return end

	if not hooks[editBox] then
		hooks[editBox] = {}
	end
	if not hooks[editBox].Insert then
		hooks[editBox].Insert = editBox.Insert
		editBox.Insert = Insert
	end

	self:SetClampRectInsets(frame)

	if self.db.MoveEditBox then
		editBox:ClearAllPoints()
		editBox:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", -5, 2)
		editBox:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 5, 2)

		SetCVar("chatStyle", "classic")
		InterfaceOptionsSocialPanelChatStyle_SetChatStyle("classic")

		InterfaceOptionsSocialPanelChatStyleButton:Disable()
		InterfaceOptionsSocialPanelChatStyleLabel:SetVertexColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
		InterfaceOptionsSocialPanelChatStyleText:SetVertexColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
	else
		editBox:ClearAllPoints()
		editBox:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -5, -2)
		editBox:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 5, -2)

		InterfaceOptionsSocialPanelChatStyleButton:Enable()
		InterfaceOptionsSocialPanelChatStyleLabel:SetVertexColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
		InterfaceOptionsSocialPanelChatStyleText:SetVertexColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	end
end

function PhanxChat:SetMoveEditBox(v)
	if self.debug then print("PhanxChat: SetMoveEditBox", v) end
	if type(v) == "boolean" then
		self.db.MoveEditBox = v
	end

	for frame in pairs(self.frames) do
		self:MoveEditBox(frame)
	end
end

table.insert(PhanxChat.RunOnLoad, PhanxChat.SetMoveEditBox)
table.insert(PhanxChat.RunOnProcessFrame, PhanxChat.MoveEditBox)