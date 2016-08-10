local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
		
m_icon(FriendsFrame, "friends", -8, 9, "MEDIUM") 
		
m_border(FriendsListFrame,332,318,"CENTER",-2,-29,14,"MEDIUM")
m_border(IgnoreListFrame,332,318,"CENTER",-2,-29,14,"MEDIUM")
m_border(PendingListFrame,332,318,"CENTER",-2,-29,14,"MEDIUM")
m_border(WhoFrame,332,322,"CENTER",-2,-28,14,"MEDIUM")
m_border(ChannelFrame,330,340,"CENTER",-2,-4,14,"MEDIUM")
m_border(RaidFrame,330,340,"CENTER",-1,-17,14,"MEDIUM")
end)


	
local frame = CreateFrame("FRAME");
frame:RegisterEvent("RAID_ROSTER_UPDATE")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
function frame:OnEvent()	
	if IsInRaid() then
		m_border_RaidFrame:ClearAllPoints()
		m_border_RaidFrame:SetPoint("CENTER",-1,-27)
		m_border_RaidFrame:SetSize(330,364)
	else
		m_border_RaidFrame:ClearAllPoints()
		m_border_RaidFrame:SetPoint("CENTER",-1,-17)
		m_border_RaidFrame:SetSize(330,340)
	end	
end
frame:SetScript("OnEvent", frame.OnEvent);	