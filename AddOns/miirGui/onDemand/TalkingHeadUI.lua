local function skin_Blizzard_TalkingHeadUI()
		m_fontify(TalkingHeadFrame.NameFrame.Name,"color")
		m_fontify(TalkingHeadFrame.TextFrame.Text,"white")
end
	
local f= CreateFrame("FRAME")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
	local f2= CreateFrame("FRAME")
	f2:RegisterEvent("ADDON_LOADED")
	f2:SetScript("OnEvent", function(_,event, arg1)
		if event == "ADDON_LOADED" and arg1 == "Blizzard_TalkingHeadUI" then
			skin_Blizzard_TalkingHeadUI()
			f2:UnregisterEvent("ADDON_LOADED")
		end	
	end)			
	if IsAddOnLoaded("Blizzard_TalkingHeadUI") then
		skin_Blizzard_TalkingHeadUI()
		f2:UnregisterEvent("ADDON_LOADED")
	end	
end)