local function skin_Blizzard_GuildUI()
		GuildInfoDetailsFrameScrollBarTrack:SetAlpha(0)
		GuildNewsContainerScrollBarTrack:SetAlpha(0)
		GuildPerksContainerScrollBarTrack:Hide()
		GuildLogScrollFrameScrollBarTrack:Hide()
		GuildTextEditScrollFrameScrollBarTrack:Hide()
		GuildRewardsFrameBg:Hide()
		m_border(GuildNewsFrame,328,318,"CENTER",0.5,0.5,14,"MEDIUM")
		m_border(GuildRewardsFrame,328,318,"TOP",0.5,0,14,"MEDIUM")	
		m_border(GuildInfoFrame,328,336,"TOP",0.5,1,14,"MEDIUM")
		m_border(GuildRosterFrame,330,310,"CENTER",-1,-32,14,"MEDIUM")
		m_border(GuildPerksFrame,330,340,"CENTER",-1,0,12,"MEDIUM")

end
	
local f= CreateFrame("FRAME")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
	local f2= CreateFrame("FRAME")
	f2:RegisterEvent("ADDON_LOADED")
	f2:SetScript("OnEvent", function(_,event, arg1)
		if event == "ADDON_LOADED" and arg1 == "Blizzard_GuildUI" then
			skin_Blizzard_GuildUI()
			f2:UnregisterEvent("ADDON_LOADED")
		end	
	end)			
	if IsAddOnLoaded("Blizzard_GuildUI") then
		skin_Blizzard_GuildUI()
		f2:UnregisterEvent("ADDON_LOADED")
	end	
end)