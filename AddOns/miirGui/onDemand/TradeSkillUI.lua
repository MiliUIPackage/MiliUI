local function skin_Blizzard_TradeSkillUI()
		TradeSkillFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
		TradeSkillFrame.DetailsFrame.Background:Hide()
		TradeSkillFrame.DetailsFrame.ScrollBar.Background:Hide()
		TradeSkillFrame.DetailsFrame.Contents.ResultIcon.Background:Hide()
		m_border(TradeSkillFrame.DetailsFrame.Contents.ResultIcon,48,48,"CENTER",0,0,12,"HIGH")	
		TradeSkillFrame:HookScript("OnShow",function()
			m_border(TradeSkillFrame,340,TradeSkillFrame:GetHeight()-102,"TOPLEFT",326,-79,14,"HIGH")	
			m_border(m_border_TradeSkillFrame,330,TradeSkillFrame:GetHeight()-82,"TOPLEFT",-325,0,14,"HIGH")
		end)
	end
	
local f= CreateFrame("FRAME")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
	local f2= CreateFrame("FRAME")
	f2:RegisterEvent("ADDON_LOADED")
	f2:SetScript("OnEvent", function(_,event, arg1)
		if event == "ADDON_LOADED" and arg1 == "Blizzard_TradeSkillUI" then
			skin_Blizzard_TradeSkillUI()
			f2:UnregisterEvent("ADDON_LOADED")
		end	
	end)			
	if IsAddOnLoaded("Blizzard_TradeSkillUI") then
		skin_Blizzard_TradeSkillUI()
		f2:UnregisterEvent("ADDON_LOADED")
	end	
end)