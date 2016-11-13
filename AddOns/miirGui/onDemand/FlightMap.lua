local function skin_Blizzard_FlightMap()
	FlightMapFramePortrait:SetBlendMode("DISABLE")
	FlightMapFramePortrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
	FlightMapFramePortrait:SetPoint("TOPLEFT",-7,7)
end			

local f= CreateFrame("FRAME")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()	
	local f2= CreateFrame("FRAME")
	f2:RegisterEvent("ADDON_LOADED")
	f2:SetScript("OnEvent", function(_,event, arg1)
		if event == "ADDON_LOADED" and arg1 == "Blizzard_FlightMap" then
			skin_Blizzard_FlightMap()
			f2:UnregisterEvent("ADDON_LOADED")
		end	
	end)			
	if IsAddOnLoaded("Blizzard_FlightMap") then
		skin_Blizzard_FlightMap()
		f2:UnregisterEvent("ADDON_LOADED")
	end	
end)