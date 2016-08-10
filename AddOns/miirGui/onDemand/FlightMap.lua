local frame = CreateFrame("FRAME")
frame:RegisterEvent("ADDON_LOADED")
function frame:OnEvent(event, arg1)
	if event == "ADDON_LOADED" and arg1 == "Blizzard_FlightMap" then
		FlightMapFramePortrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
		FlightMapFramePortrait:SetAlpha(1)
		FlightMapFramePortrait:SetPoint("TOPLEFT",-7,7)
	end
end			
frame:SetScript("OnEvent", frame.OnEvent);