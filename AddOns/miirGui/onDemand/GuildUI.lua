local frame = CreateFrame("FRAME")
frame:RegisterEvent("ADDON_LOADED")
function frame:OnEvent(event, arg1)
	if event == "ADDON_LOADED" and arg1 == "Blizzard_GuildUI" then
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
end

frame:SetScript("OnEvent", frame.OnEvent);