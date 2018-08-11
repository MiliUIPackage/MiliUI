local function skin_TradeFrame()

	TradeFramePlayerPortrait:SetTexCoord(0.13, 0.83, 0.13, 0.83)
	TradeFramePlayerPortrait:SetPoint("TOPLEFT",-8,10)
	TradeFramePlayerPortrait:SetWidth(64)
	TradeFramePlayerPortrait:SetHeight(64)
	TradeFrameRecipientPortrait:SetTexCoord(0.13, 0.83, 0.13, 0.83)
	TradeFrameRecipientPortrait:SetWidth(62)
	TradeFrameRecipientPortrait:SetHeight(62)
	TradeRecipientBG:Hide()
	TradeRecipientBotLeftCorner:SetPoint("BOTTOMLEFT", "TradeFrame", "BOTTOMRIGHT", -178, -5)

end

local m_catch = CreateFrame("Frame")
m_catch:RegisterEvent("PLAYER_LOGIN")
m_catch:SetScript("OnEvent", skin_TradeFrame)