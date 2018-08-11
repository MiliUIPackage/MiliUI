local function skin_Blizzard_PVPUI()
	HonorFrame.BonusFrame.WorldBattlesTexture:Hide()
	local _,ring1,icon1 = PVPQueueFrameCategoryButton1:GetRegions()
	ring1:Hide()
	icon1:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	icon1:SetWidth(46)
	icon1:SetHeight(46)
	local _,ring2,icon2 =PVPQueueFrameCategoryButton2:GetRegions()
	ring2:Hide()
	icon2:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	icon2:SetWidth(46)
	icon2:SetHeight(46)
	local _,ring3,icon3 = PVPQueueFrameCategoryButton3:GetRegions()
	ring3:Hide()
	icon3:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	icon3:SetWidth(46)
	icon3:SetHeight(46)
	PVPReadyDialogBackground:Hide()
	HonorFrame.BonusFrame.RandomBGButton.Reward.Border:Hide()
	HonorFrame.BonusFrame.RandomBGButton.Reward.Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	HonorFrame.BonusFrame.RandomEpicBGButton.Reward.Border:Hide()
	HonorFrame.BonusFrame.RandomEpicBGButton.Reward.Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)

	local function miirgui_HonorFrameBonusFrame_Update()
		HonorFrame.BonusFrame.Arena1Button.Reward:ClearAllPoints()
		HonorFrame.BonusFrame.Arena1Button.Reward:SetPoint("RIGHT",HonorFrame.BonusFrame.Arena1Button,-14,0)
		HonorFrame.BonusFrame.Arena1Button.Reward.Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
		HonorFrame.BonusFrame.Arena1Button.Reward.Border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border.blp")
		HonorFrame.BonusFrame.Arena1Button.Reward.Border:SetVertexColor(miirguiDB.color.r,miirguiDB.color.g,miirguiDB.color.b,1)
		HonorFrame.BonusFrame.Arena1Button.Reward.Border:SetSize(64,64)
		if HonorFrame.BonusFrame.RandomBGButton.Reward.EnlistmentBonus:IsShown() then
			HonorFrame.BonusFrame.RandomBGButton.Reward.EnlistmentBonus:ClearAllPoints()
			HonorFrame.BonusFrame.RandomBGButton.Reward.EnlistmentBonus:SetPoint("LEFT",HonorFrame.BonusFrame.RandomBGButton.Reward,-24,-2)
			HonorFrame.BonusFrame.RandomBGButton.Reward.EnlistmentBonus.Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
		end
		if HonorFrame.BonusFrame.BrawlButton.Reward:IsShown() then
			HonorFrame.BonusFrame.BrawlButton.Reward:ClearAllPoints()
			HonorFrame.BonusFrame.BrawlButton.Reward:SetPoint("RIGHT",HonorFrame.BonusFrame.BrawlButton,-14,0)
			HonorFrame.BonusFrame.BrawlButton.Reward.Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
			HonorFrame.BonusFrame.BrawlButton.Reward.Border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border.blp")
			HonorFrame.BonusFrame.BrawlButton.Reward.Border:SetVertexColor(miirguiDB.color.r,miirguiDB.color.g,miirguiDB.color.b,1)
			HonorFrame.BonusFrame.BrawlButton.Reward.Border:SetSize(64,64)
		end
	end
	
	hooksecurefunc("HonorFrameBonusFrame_Update",miirgui_HonorFrameBonusFrame_Update)

	m_border(PVPQueueFrameCategoryButton1,50,50,"LEFT",10,0,14,"MEDIUM")
	m_fontify(PVPQueueFrameCategoryButton1.Name,"white")
	m_border(PVPQueueFrameCategoryButton2,50,50,"LEFT",10,0,14,"MEDIUM")
	m_fontify(PVPQueueFrameCategoryButton2.Name,"white")
	m_border(PVPQueueFrameCategoryButton3,50,50,"LEFT",10,0,14,"MEDIUM")
	m_fontify(PVPQueueFrameCategoryButton3.Name,"white")
	m_border(HonorFrame,396,298,"CENTER",0,-32.5,14,"HIGH")
	
	m_border(ConquestFrame,396,298,"CENTER",0,-30.5,14,"HIGH")
	m_border(PVPQueueFrame.HonorInset,164,384.5,"CENTER",0,0,14,"MEDIUM")
	m_border(HonorFrame.BonusFrame.RandomBGButton,38,38,"RIGHT",-20,-2,14,"HIGH")
	m_border(HonorFrame.BonusFrame.RandomEpicBGButton,38,38,"RIGHT",-20,-2,14,"HIGH")

	hooksecurefunc(HonorFrame.ConquestBar,"Update",function(self)
		local season = GetCurrentArenaSeason();
		if season > 0 then
			self.Reward.CircleMask:Hide()
			self.Reward.Icon:SetSize(32,32)
			self.Reward.Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
			self.Reward.Ring:SetTexture("Interface\\Buttons\\UI-ActionButton-Border.blp")
			self.Reward.Ring:SetVertexColor(miirguiDB.color.r,miirguiDB.color.g,miirguiDB.color.b,1)
			self.Reward.Ring:SetSize(64,64)
		else
			self.Reward.CircleMask:Hide()
			self.Reward.Icon:Hide()
		end
	end)
	
	hooksecurefunc(ConquestFrame.ConquestBar,"Update",function(self)
		local season = GetCurrentArenaSeason();
		if season > 0 then
			self.Reward.CircleMask:Hide()
			self.Reward.Icon:SetSize(32,32)
			self.Reward.Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
			self.Reward.Ring:SetTexture("Interface\\Buttons\\UI-ActionButton-Border.blp")
			self.Reward.Ring:SetVertexColor(miirguiDB.color.r,miirguiDB.color.g,miirguiDB.color.b,1)
			self.Reward.Ring:SetSize(64,64)
		else
			self.Reward.CircleMask:Hide()
			self.Reward.Icon:Hide()
		end
	end)
	
	PVPQueueFrame.HonorInset.RatedPanel.SeasonRewardFrame.CircleMask:Hide()
	PVPQueueFrame.HonorInset.RatedPanel.SeasonRewardFrame.Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	PVPQueueFrame.HonorInset.RatedPanel.SeasonRewardFrame.Icon:SetSize(32,32)
	PVPQueueFrame.HonorInset.RatedPanel.SeasonRewardFrame.Ring:SetTexture("Interface\\Buttons\\UI-ActionButton-Border.blp")
	PVPQueueFrame.HonorInset.RatedPanel.SeasonRewardFrame.Ring:SetVertexColor(miirguiDB.color.r,miirguiDB.color.g,miirguiDB.color.b,1)
	PVPQueueFrame.HonorInset.RatedPanel.SeasonRewardFrame.Ring:SetSize(64,64)
	

	PremadeGroupsPvPTutorialAlertBg:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 1)
	PremadeGroupsPvPTutorialAlertBg:SetColorTexture(0.078,0.078,0.078,1)
	m_border(PremadeGroupsPvPTutorialAlert,226,156,"CENTER",0.5,0,14,"DIALOG")
	m_fontify(PremadeGroupsPvPTutorialAlert.Text,"white")

	ConquestFrame.Arena2v2.Reward.Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	m_border(ConquestFrame.Arena2v2.Reward,38,38,"CENTER",0,0.5,14,"MEDIUM")

	ConquestFrame.Arena3v3.Reward.Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	m_border(ConquestFrame.Arena3v3.Reward,38,38,"CENTER",0,0.5,14,"MEDIUM")

	ConquestFrame.RatedBG.Reward.Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	m_border(ConquestFrame.RatedBG.Reward,38,38,"CENTER",0,0.5,14,"MEDIUM")
	
end

local catchaddon = CreateFrame("FRAME")
catchaddon:RegisterEvent("ADDON_LOADED")

--function to catch loading addons
local function skinnedOnLoad(_, _, addon)
	if addon == "Blizzard_PVPUI" then
		skin_Blizzard_PVPUI()
	end
end

--this function decides whether the addon is already loaded or if we need to look out for it!

local function skinnedOnLogin()
	if IsAddOnLoaded("Blizzard_PVPUI") then
		-- Addon is already loaded, procceed to skin!
		skin_Blizzard_PVPUI()
	else
		-- Addon is not loaded yet, procceed to look out for it!
		catchaddon:SetScript("OnEvent", skinnedOnLoad)
	end
end

local HelloWorld = CreateFrame("FRAME")
HelloWorld:RegisterEvent("PLAYER_ENTERING_WORLD")
HelloWorld:SetScript("OnEvent", skinnedOnLogin)