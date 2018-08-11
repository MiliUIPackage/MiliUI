local function skin_Blizzard_Arftifact_UI()

	ArtifactFrame.ForgeBadgeFrame.CircleMask:Hide()
	ArtifactFrame.ForgeBadgeFrame.ItemIconBorder:Hide()
	ArtifactFrame.ForgeBadgeFrame:SetFrameStrata("TOOLTIP")
	ArtifactFrame.ForgeBadgeFrame.ItemIcon:SetTexCoord(0.15, 0.85, 0.15, 0.85)
	m_border(ArtifactFrame.ForgeBadgeFrame,72,72,"TOPLEFT",-16,16,14,"DIALOG")
	m_border(ArtifactFrame,226,74,"CENTER",0,0,14,"DIALOG")

	m_border_ArtifactFrame:SetPoint("TOPLEFT","ArtifactFrame",-3,3)
	m_border_ArtifactFrame:SetPoint("BOTTOMRIGHT","ArtifactFrame",3,-3)
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

local catchaddon = CreateFrame("FRAME")
catchaddon:RegisterEvent("ADDON_LOADED")

--function to catch loading addons
local function skinnedOnLoad(_, _, addon)
	if addon == "Blizzard_ArtifactUI" then
		skin_Blizzard_Arftifact_UI()
	end
end

--this function decides whether the addon is already loaded or if we need to look out for it!

local function skinnedOnLogin()
	if IsAddOnLoaded("Blizzard_ArtifactUI") then
		-- Addon is already loaded, procceed to skin!
		skin_Blizzard_Arftifact_UI()
	else
		-- Addon is not loaded yet, procceed to look out for it!
		catchaddon:SetScript("OnEvent", skinnedOnLoad)
	end
end

local HelloWorld = CreateFrame("FRAME")
HelloWorld:RegisterEvent("PLAYER_ENTERING_WORLD")
HelloWorld:SetScript("OnEvent", skinnedOnLogin)