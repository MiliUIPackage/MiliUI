local function skin_TimerFrame()

	TimeManagerGlobe:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	TimeManagerGlobe:SetPoint("TOPLEFT", -7,9)

end

local m_catch = CreateFrame("Frame")
m_catch:RegisterEvent("PLAYER_LOGIN")
m_catch:SetScript("OnEvent", skin_TimerFrame)