local function skin_LootFrame()

	LootFramePortraitOverlay:SetTexCoord(0.13, 0.83, 0.13, 0.83)
	LootFramePortraitOverlay:SetPoint("TOPLEFT",-8,10)
	LootFramePortraitOverlay:SetWidth(64)
	LootFramePortraitOverlay:SetHeight(64)

end

local m_catch = CreateFrame("Frame")
m_catch:RegisterEvent("PLAYER_LOGIN")
m_catch:SetScript("OnEvent", skin_LootFrame)