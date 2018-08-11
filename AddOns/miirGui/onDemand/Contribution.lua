local function skin_Blizzard_Contribution_UI()

	m_SetTexture(ContributionCollectionFrame.Background,"Interface\\FrameGeneral\\UI-Background-Rock.blp")
	ContributionCollectionFrame.CloseButton.CloseButtonBackground:Hide()
	m_border(ContributionCollectionFrame,872,584,"Center",0,0,14,"HIGH")

	local function miirgui_ContributionMixin_Update(self)
		m_fontify(self.Header.Text,"white")
		self.Header.Background:Hide()
	end

	hooksecurefunc(ContributionMixin,"Update",miirgui_ContributionMixin_Update)

	local function miirgui_ContributionRewardMixin_Setup(self)
		self.Border:ClearAllPoints()
		self.Border:SetPoint("LEFT",self,-13,-1.5)
		self.Border:SetTexture("Interface\\Buttons\\UI-Quickslot.blp")
		self.Border:SetSize(62,62)
		m_fontify(self.RewardName,"white")
	end

	hooksecurefunc(ContributionRewardMixin,"Setup",miirgui_ContributionRewardMixin_Setup)

	local function miirgui_ContributionStatusMixin_Update(self)
		self.Spark:Hide()
		self.SparkGlow:Hide()
		self:SetStatusBarTexture("Interface\\Targetingframe\\UI-StatusBar.blp")
		self:SetStatusBarColor(miirguiDB.color.r,miirguiDB.color.g,miirguiDB.color.b,1)
		m_SetTexture(self.BG,"Interface\\FrameGeneral\\UI-Background-Marble.blp")
		if not self.border then
			m_border(self,230,22,"Center",0,0,12,"HIGH")
			self.Border:SetVertexColor(0,0,0,0)
			self.border=true
		end
	end

	hooksecurefunc(ContributionStatusMixin,"Update",miirgui_ContributionStatusMixin_Update)

end

local catchaddon = CreateFrame("FRAME")
catchaddon:RegisterEvent("ADDON_LOADED")

--function to catch loading addons
local function skinnedOnLoad(_, _, addon)
	if addon == "Blizzard_Contribution" then
		skin_Blizzard_Contribution_UI()
	end
end

--this function decides whether the addon is already loaded or if we need to look out for it!

local function skinnedOnLogin()
	if IsAddOnLoaded("Blizzard_Contribution") then
		-- Addon is already loaded, procceed to skin!
		skin_Blizzard_Contribution_UI()
	else
		-- Addon is not loaded yet, procceed to look out for it!
		catchaddon:SetScript("OnEvent", skinnedOnLoad)
	end
end

local HelloWorld = CreateFrame("FRAME")
HelloWorld:RegisterEvent("PLAYER_ENTERING_WORLD")
HelloWorld:SetScript("OnEvent", skinnedOnLogin)