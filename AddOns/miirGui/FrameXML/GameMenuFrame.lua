local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()

GameMenuFrameHeader:Hide()
local GameMenuText=select (11,GameMenuFrame:GetRegions())
GameMenuText:Hide()
		
InterfaceOptionsFramePanelContainer:SetBackdrop({
edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border_blue.blp",
edgeSize = 14,
})
InterfaceOptionsFrameHeader:Hide()
InterfaceOptionsFrameHeaderText:Hide()
VideoOptionsFrameHeader:Hide()
VideoOptionsFrameHeaderText:Hide()
	
local gamemenubg = select(1,GameMenuFrame:GetRegions())
gamemenubg:ClearAllPoints()
gamemenubg:SetPoint("TOPLEFT", GameMenuFrame, 7,-7)
gamemenubg:SetPoint("BOTTOMRIGHT", GameMenuFrame, -7,7)

local staticbg = select(1,StaticPopup1:GetRegions())
staticbg:ClearAllPoints()
staticbg:SetPoint("TOPLEFT",StaticPopup1,10,-10)
staticbg:SetPoint("BOTTOMRIGHT", StaticPopup1, -10,9)
		
end)