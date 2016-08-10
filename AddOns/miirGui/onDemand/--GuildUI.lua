-- local frame = CreateFrame("FRAME")
-- frame:RegisterEvent("ADDON_LOADED")
-- function frame:OnEvent(event, arg1)
-- 	if event == "ADDON_LOADED" and arg1 == "Blizzard_GuildUI" then
-- 		GuildInfoDetailsFrameScrollBarTrack:SetAlpha(0)
-- 		GuildNewsContainerScrollBarTrack:SetAlpha(0)
-- 		GuildPerksContainerScrollBarTrack:Hide()
-- 		GuildLogScrollFrameScrollBarTrack:Hide()
-- 		local Emblem1 = select(1, GuildPointFrame:GetRegions())
-- 		Emblem1:Hide()
-- 		local Emblem2 = select(4, GuildPointFrame:GetRegions())
-- 		Emblem2:Hide()
-- 		GuildTextEditScrollFrameScrollBarTrack:Hide()

-- 		m_border(GuildRosterFrame,330,310,"CENTER",-1,-32,14,"MEDIUM")
-- 		m_border(GuildPerksFrame,330,340,"CENTER",-1,0,12,"MEDIUM")
-- 		m_border(GuildInfoFrameRecruitment,330,336,"CENTER",-1,0,12,"MEDIUM")
-- 		m_border(GuildInfoFrameApplicants,330,336,"CENTER",-1,0,12,"MEDIUM")

-- 	end
-- end

-- frame:SetScript("OnEvent", frame.OnEvent);