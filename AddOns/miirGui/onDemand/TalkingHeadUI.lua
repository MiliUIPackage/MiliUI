local frame = CreateFrame("FRAME")
frame:RegisterEvent("ADDON_LOADED")
function frame:OnEvent(event, arg1)
	if event == "ADDON_LOADED" and arg1 == "Blizzard_TalkingHeadUI" then

		--local frame = TalkingHeadFrame;
		m_fontify(TalkingHeadFrame.NameFrame.Name,"color")
		m_fontify(TalkingHeadFrame.TextFrame.Text,"white")

	end
end
frame:SetScript("OnEvent", frame.OnEvent);