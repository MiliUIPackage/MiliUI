local f = CreateFrame("Frame");
f:RegisterEvent("PLAYER_ENTERING_WORLD");
f:SetScript("OnEvent", function()
		
LootFramePortraitOverlay:SetTexCoord(0.13, 0.83, 0.13, 0.83)
LootFramePortraitOverlay:SetPoint("TOPLEFT",-8,10)
LootFramePortraitOverlay:SetWidth(64)
LootFramePortraitOverlay:SetHeight(64)
		
end)