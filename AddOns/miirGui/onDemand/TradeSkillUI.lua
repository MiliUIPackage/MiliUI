local frame = CreateFrame("FRAME")
frame:RegisterEvent("ADDON_LOADED")
function frame:OnEvent(event, arg1)
	if event == "ADDON_LOADED" and arg1 == "Blizzard_TradeSkillUI" then
		TradeSkillFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
		TradeSkillFrame.DetailsFrame.Background:Hide()
		TradeSkillFrame.DetailsFrame.ScrollBar.Background:Hide()
		TradeSkillFrame.DetailsFrame.Contents.ResultIcon.Background:Hide()
		TradeSkillFrame:HookScript("OnShow",function()
			m_border(TradeSkillFrame,340,TradeSkillFrame:GetHeight()-102,"TOPLEFT",326,-79,14,"HIGH")	
			m_border(m_border_TradeSkillFrame,330,TradeSkillFrame:GetHeight()-82,"TOPLEFT",-325,0,14,"HIGH")
		end)
	end
end
frame:SetScript("OnEvent", frame.OnEvent);