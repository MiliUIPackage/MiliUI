local frame = CreateFrame("FRAME")
frame:RegisterEvent("ADDON_LOADED")
function frame:OnEvent(event, arg1)
	if event == "ADDON_LOADED" and arg1 == "Blizzard_LookingForGuildUI" then
		LookingForGuildFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	end
end

frame:SetScript("OnEvent", frame.OnEvent);