local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()

GameMenuFrameHeader:Hide()
InterfaceOptionsFrameHeader:Hide()
InterfaceOptionsFrameHeaderText:Hide()
VideoOptionsFrameHeader:Hide()
VideoOptionsFrameHeaderText:Hide()
local GameMenuText=select (11,GameMenuFrame:GetRegions())
GameMenuText:Hide()

GameMenuFrame:SetWidth(190)
GameMenuFrame:SetBackdrop({
bgFile = "Interface/Tooltips/UI-Tooltip-Background",
edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border_blue.blp",
edgeSize = 14, 
insets = { left = 2, right = 2, top = 2, bottom = 2 }
})
GameMenuFrame:SetBackdropColor(0,0,0,0.8);
		
InterfaceOptionsFrameCategoriesBottom:SetVertexColor(1,1,1,1)

InterfaceOptionsFrame:SetBackdrop({
bgFile = "Interface/Tooltips/UI-Tooltip-Background",
edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border_blue.blp",
edgeSize = 14, 
insets = { left = 4, right = 4, top = 4, bottom = 4 }
})	
InterfaceOptionsFrame:SetBackdropColor(0,0,0,0.8);
InterfaceOptionsFramePanelContainer:SetBackdrop({
edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border_blue.blp",
edgeSize = 14,
})

StaticPopup1:SetBackdrop({
bgFile = "Interface/Tooltips/UI-Tooltip-Background",
edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border_blue.blp",
edgeSize = 14, 
insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
StaticPopup1:SetBackdropColor(0,0,0,0.8);
			
VideoOptionsFrameCategoryFrameBottom:SetVertexColor(1,1,1,1)	
VideoOptionsFrame:SetBackdrop({
bgFile = "Interface/Tooltips/UI-Tooltip-Background",
edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border_blue.blp",
edgeSize = 14, 
insets = { left = 4, right = 4, top = 4, bottom = 4 }
})	
VideoOptionsFrame:SetBackdropColor(0,0,0,0.8);
VideoOptionsFramePanelContainer:SetBackdrop({
edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border_blue.blp",
edgeSize = 14,
})

Display_:SetBackdrop({
edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border_blue.blp",
edgeSize = 14,
})
Graphics_:SetBackdrop({
edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border_blue.blp",
edgeSize = 14,
})
AudioOptionsSoundPanelPlayback:SetBackdrop({
edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border_blue.blp",
edgeSize = 14,
})
AudioOptionsSoundPanelHardware:SetBackdrop({
edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border_blue.blp",
edgeSize = 14,
})
AudioOptionsSoundPanelVolume:SetBackdrop({
edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border_blue.blp",
edgeSize = 14,
})
AudioOptionsVoicePanelTalking:SetBackdrop({
edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border_blue.blp",
edgeSize = 14,
})
AudioOptionsVoicePanelListening:SetBackdrop({
edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border_blue.blp",
edgeSize = 14,
})
AudioOptionsVoicePanelBinding:SetBackdrop({
edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border_blue.blp",
edgeSize = 14,
})
end)