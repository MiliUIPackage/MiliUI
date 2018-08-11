local function skin_TabardFrame()

	TabardFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)

end

local m_catch = CreateFrame("Frame")
m_catch:RegisterEvent("PLAYER_LOGIN")
m_catch:SetScript("OnEvent", skin_TabardFrame)