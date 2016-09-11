local function skin_Blizzard_Arftifact_UI()		
		ArtifactFrame.ForgeBadgeFrame.ForgeClassBadgeIcon:Hide()
		ArtifactFrameTab1:ClearAllPoints()
		ArtifactFrameTab1:SetPoint("BOTTOMLEFT", ArtifactFrame.BorderFrame.ForgeBottomBorder, 0, -20);
		ArtifactFrame.ForgeBadgeFrame.ForgeLevelBackground:ClearAllPoints()
		ArtifactFrame.ForgeBadgeFrame.ForgeLevelBackground:SetPoint("TOPLEFT",ArtifactFrame,20,-10)
		m_SetTexture(ArtifactFrame.ForgeBadgeFrame.ForgeLevelBackground,"Interface\\Artifacts\\ArtifactPower-QuestBorder.blp")
		ArtifactFrame.ForgeBadgeFrame.ForgeLevelBackground:SetSize(64,64)
		
		ArtifactFrame.ForgeBadgeFrame.ForgeLevelLabel:ClearAllPoints()
		ArtifactFrame.ForgeBadgeFrame.ForgeLevelLabel:SetPoint("CENTER",ArtifactFrame.ForgeBadgeFrame.ForgeLevelBackground)

		ArtifactFrame.ForgeBadgeFrame.ForgeLevelBackgroundBlack:SetAlpha(0)
		
		local bg = ArtifactFrame.KnowledgeLevelHelpBox:GetRegions()
		bg:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 1)
		bg:SetColorTexture(0.078,0.078,0.078,1)
		m_border(ArtifactFrame.KnowledgeLevelHelpBox,226,74,"CENTER",0,0,14,"DIALOG")		
		m_fontify(ArtifactFrame.KnowledgeLevelHelpBox.Text,"white")	

		local bg = ArtifactFrame.AppearanceTabHelpBox:GetRegions()
		bg:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 1)
		bg:SetColorTexture(0.078,0.078,0.078,1)
		m_border(ArtifactFrame.AppearanceTabHelpBox,225,72,"CENTER",0,0,14,"DIALOG")		
		m_fontify(ArtifactFrame.AppearanceTabHelpBox.Text,"white")			
end

local f= CreateFrame("FRAME")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()	
	local f2= CreateFrame("FRAME")
	f2:RegisterEvent("ADDON_LOADED")
	f2:SetScript("OnEvent", function(_,event, arg1)
	
		if event == "ADDON_LOADED" and arg1 == "Blizzard_ArtifactUI" then
			skin_Blizzard_Arftifact_UI()
			f2:UnregisterEvent("ADDON_LOADED")
		end	
	end)			
	if IsAddOnLoaded("Blizzard_ArtifactUI") then
		skin_Blizzard_Arftifact_UI()
		f2:UnregisterEvent("ADDON_LOADED")
	end	
end)