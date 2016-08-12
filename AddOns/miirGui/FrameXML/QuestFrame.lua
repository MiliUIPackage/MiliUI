local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
	QuestFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	QuestFrameGreetingPanelBg:SetAlpha(0)
	WorldMapFrameTutorialButton.Ring:SetAlpha(0)
	WorldMapFramePortrait:SetWidth(66)
	WorldMapFramePortrait:SetHeight(66)
	WorldMapFramePortrait:SetPoint("TOPLEFT",-9,9)
	WorldMapFramePortrait:SetTexture("Interface\\Addons\\miirgui\\gfx\\quest.blp")
	local GossipFrameBackground = select(19,GossipFrame:GetRegions())
	GossipFrameBackground:SetAlpha(0)
	QuestFrameDetailPanelBg:SetAlpha(0)
	QuestFrameRewardPanelBg:SetAlpha(0)
	QuestMapDetailsScrollFrameScrollBarTrack:SetAlpha(0)
	QuestFrameProgressPanelBg:SetAlpha(0)
	QuestNPCModelTopBorder:SetAlpha(0)
	QuestNPCModelLeftBorder:SetAlpha(0)
	QuestNPCModelRightBorder:SetAlpha(0)
	QuestNPCModelBottomBorder:SetAlpha(0)
	QuestNPCModelBotLeftCorner:SetAlpha(0)
	QuestNPCModelBotRightCorner:SetAlpha(0)
	QuestNPCModelTextBottomBorder:SetAlpha(0)
	QuestNPCModelTextLeftBorder:SetAlpha(0)
	QuestNPCModelTextRightBorder:SetAlpha(0)
	QuestNPCModelTextBotRightCorner:SetAlpha(0)
	QuestNPCModelTextBotLeftCorner:SetAlpha(0)
	QuestNPCModelNameplate:SetAlpha(0)
	QuestNPCModelShadowOverlay:SetAlpha(0)
	QuestNPCModelTopBg:SetAlpha(0)	
	QuestNPCModelBg:ClearAllPoints()
	QuestNPCModelBg:SetPoint("TOPLEFT","QuestNPCModel",0,16)
	QuestNPCModelBg:SetPoint("BOTTOMRIGHT","QuestNPCModel",0,-86)
	m_fontify(QuestNPCModelText,"white")
	m_border(QuestNPCModel,202,336,"CENTER",1,-34,14,"MEDIUM")
	m_border(QuestFrame,330,412,"CENTER",-1,-17,14,"MEDIUM")
	m_border(QuestLogPopupDetailFrame,330,412,"CENTER",-1,-17,14,"MEDIUM")
	m_border(GossipFrame,330,412,"CENTER",-1,-17,14,"MEDIUM")
	
	local function miirgui_GossipFrameUpdate()
		GossipFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
		GossipFramePortrait:SetWidth(66)
		GossipFramePortrait:SetHeight(66)
		GossipFramePortrait:SetPoint("TOPLEFT",-9,10)
		m_fontify(GossipGreetingText,"white")
		for i=1, 32 do
			local button = _G["GossipTitleButton"..i]
			if button:GetFontString() then
				m_fontify(button:GetFontString(),"white")
				if button:GetFontString():GetText() and button:GetFontString():GetText():find("|cff000000") then
					button:GetFontString():SetText(string.gsub(button:GetFontString():GetText(), "|cff000000", "|cffffffff"))
					m_fontify(button:GetFontString(),"same")
				end
			end		
		end
	end
	
	hooksecurefunc("GossipFrameUpdate",miirgui_GossipFrameUpdate)
	
	local function miirgui_WorldMapFrame()
		local BountyBg=select(1,WorldMapFrame.UIElementsFrame.BountyBoard.TutorialBox:GetRegions())
		BountyBg:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 1)
		BountyBg:SetColorTexture(0.078,0.078,0.078,1)	
		if not m_helpplate then
			local Border = CreateFrame("Frame", "m_helpplate", WorldMapFrame.UIElementsFrame.BountyBoard.TutorialBox)
			Border:SetSize(226,90)
			Border:SetPoint("TOPLEFT",WorldMapFrame.UIElementsFrame.BountyBoard.TutorialBox,-3,2.5)
			Border:SetPoint("BOTTOMRIGHT",WorldMapFrame.UIElementsFrame.BountyBoard.TutorialBox,3,-2.5)
			Border:SetBackdrop({
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border_blue.blp",
			edgeSize = 14})
			Border:SetBackdropBorderColor(1, 1, 1)
			Border:SetFrameStrata("DIALOG")
		end
		m_fontify(WorldMapFrame.UIElementsFrame.BountyBoard.TutorialBox.Text,"white")
	end
	
	WorldMapFrame:HookScript("OnShow",miirgui_WorldMapFrame)

	local function miirgui_QuestInfo_Display(_, parentFrame)
		local questFrame = parentFrame:GetParent():GetParent()
		local sealMaterialBG = questFrame.SealMaterialBG
		if sealMaterialBG then	
			sealMaterialBG:SetAlpha(0)
		end	
		QuestInfoRewardsFrame.ArtifactXPFrame.Overlay:SetAlpha(0)
		local QuestLogPopupDetailFrameBackground= select(18,QuestLogPopupDetailFrame:GetRegions())
		QuestLogPopupDetailFrameBackground:SetAlpha(0)
		local QuestLogPopupDetailFramePortrait= select(24,QuestLogPopupDetailFrame:GetRegions())
		QuestLogPopupDetailFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
		QuestLogPopupDetailFramePortrait:SetPoint("TOPLEFT",-9,9)
		QuestFramePortrait:SetSize(66,66)
		--QuestFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
		QuestFramePortrait:SetPoint("TOPLEFT",-9,10)
		m_fontify(QuestNPCModelNameText,"color")
		m_fontify(QuestInfoTitleHeader,"color")
		m_fontify(QuestInfoDescriptionHeader,"color")
		m_fontify(QuestInfoObjectivesHeader,"color")
		m_fontify(QuestInfoRewardsFrame.Header,"color")
		m_fontify(QuestInfoDescriptionText,"white")
		m_fontify(QuestInfoObjectivesText,"white")
		m_fontify(QuestInfoGroupSize,"white")
		m_fontify(QuestInfoRewardText,"white")
		m_fontify(QuestInfoSkillPointFrame.ValueText,"white")
		m_fontify(QuestInfoRewardsFrame.ItemChooseText,"white")
		m_fontify(QuestInfoRewardsFrame.ItemReceiveText,"white")
		m_fontify(QuestInfoMoneyFrameGoldButtonText,"white")
		m_fontify(QuestInfoMoneyFrameSilverButtonText,"white")
		m_fontify(QuestInfoMoneyFrameCopperButtonText,"white")
		m_fontify(QuestInfoXPFrame.ValueText,"white")
		m_fontify(QuestInfoRewardsFrame.PlayerTitleText,"white")
		m_fontify(QuestInfoRewardsFrame.XPFrame.ReceiveText,"white")
		m_fontify(MapQuestInfoRewardsFramePoints,"white")
		m_fontify(MapQuestInfoRewardsFrame.ItemReceiveText,"white")
		m_fontify(MapQuestInfoRewardsFrameQuestInfoItem1.Name,"white")
		m_fontify(MapQuestInfoRewardsFrame.SkillPointFrame.Name,"white")
		m_fontify(MapQuestInfoRewardsFrame.XPFrame.Name,"white")
		m_fontify(MapQuestInfoRewardsFrame.MoneyFrame.Name,"white")
		m_fontify(QuestFont,"white")
		m_fontify(MapQuestInfoRewardsFrame.ItemChooseText,"white")
		local QuestMapFrameDetailsFrameRewardsFrameHeader= select(3,QuestMapFrame.DetailsFrame.RewardsFrame:GetRegions())
		m_fontify(QuestMapFrameDetailsFrameRewardsFrameHeader,"color")
		m_fontify(QuestInfoSealFrame.Text,"same")
		
		local QuestInfoRewardsFramewilllearn = select(5,QuestInfoRewardsFrame:GetRegions())
		if QuestInfoRewardsFramewilllearn ~= nil then
			m_fontify(QuestInfoRewardsFramewilllearn,"white")
		end
			
		for i=1,6 do 
			if _G["QuestInfoObjective"..i] and questFrame:GetName() == "QuestLogPopupDetailFrame" then	
				local r = _G["QuestInfoObjective"..i]:GetTextColor()
				if r >0 then
					m_fontify(_G["QuestInfoObjective"..i],"green")
				else
					m_fontify(_G["QuestInfoObjective"..i],"grey")
				end
			elseif _G["QuestInfoObjective"..i] and questFrame:GetName() == "QuestMapFrame" then	
				local r,g,b = _G["QuestInfoObjective"..i]:GetTextColor()
				if r == 0 and g == 0 and b == 0 then
					m_fontify(_G["QuestInfoObjective"..i],"grey")
				elseif r >= 0.19 and r <=0.20 then
					m_fontify(_G["QuestInfoObjective"..i],"green")
				end
			--cql code
			elseif _G["QuestInfoObjective"..i] and questFrame:GetName() == "ClassicQuestLog" then	
				local r,g,b = _G["QuestInfoObjective"..i]:GetTextColor()
				if r == 0 and g == 0 and b == 0 then
					m_fontify(_G["QuestInfoObjective"..i],"grey")
				elseif r >= 0.19 and r <=0.20 then
					m_fontify(_G["QuestInfoObjective"..i],"green")
				end	
			--cql code
			end
		end
	end

	hooksecurefunc("QuestInfo_Display", miirgui_QuestInfo_Display)
	
	local function miirgui_QuestFrameProgressItems_Update()
		m_fontify(QuestProgressTitleText,"color")
		m_fontify(QuestProgressText,"white")
		m_fontify(QuestProgressRequiredItemsText,"color")
		m_fontify(QuestProgressRequiredMoneyText,"white")	
	end

	hooksecurefunc("QuestFrameProgressItems_Update", miirgui_QuestFrameProgressItems_Update)

	local function miirgui_QuestMapFrame_ShowQuestDetails()
		for i =1,4 do
			local test=select(i,MapQuestInfoRewardsFrame:GetRegions())
			if test then
				m_fontify(test,"white")
			end
		end
	end
	
	hooksecurefunc("QuestMapFrame_ShowQuestDetails",miirgui_QuestMapFrame_ShowQuestDetails)

	local function miirgui_greetings_panel()
		m_fontify(GreetingText,"white")
		m_fontify(CurrentQuestsText,"color")
		m_fontify(AvailableQuestsText,"color")
		for i=1, 32 do
			local button = _G["QuestTitleButton"..i]
			if button:GetFontString() then
				if button:GetFontString():GetText() and button:GetFontString():GetText():find("|cff000000") then
				button:GetFontString():SetText(string.gsub(button:GetFontString():GetText(), "|cff000000", "|cffffffff"))
				m_fontify(button:GetFontString(),"same")
				end
			end
		end	
	end
	
	QuestFrameGreetingPanel:HookScript("OnShow", miirgui_greetings_panel)
	hooksecurefunc("QuestFrameGreetingPanel_OnShow",miirgui_greetings_panel)
	
	local function miirgui_QuestMapFrame()
			for key in pairs(MapQuestInfoRewardsFrame["followerRewardPool"]) do
			local followerFrame = MapQuestInfoRewardsFrame.followerRewardPool:Acquire();	
			followerFrame.Class:SetAlpha(0)
			followerFrame.BG:ClearAllPoints()
			followerFrame.BG:SetSize(140,39)
			followerFrame.BG:SetPoint("RIGHT",followerFrame,40,3)
			followerFrame.BG:SetTexture("Interface\\AuctionFrame\\UI-AuctionItemNameFrame.blp")
			followerFrame.PortraitFrame.PortraitRing:SetAlpha(0)
			followerFrame.PortraitFrame.LevelBorder:SetAlpha(0)
			followerFrame.PortraitFrame.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
			followerFrame.PortraitFrame.PortraitRingQuality:SetTexture("Interface\\Buttons\\UI-Quickslot.blp")
			followerFrame.PortraitFrame.PortraitRingQuality:SetSize(84,84)
			followerFrame.PortraitFrame.PortraitRingQuality:ClearAllPoints()
			followerFrame.PortraitFrame.PortraitRingQuality:SetPoint("LEFT",followerFrame.PortraitFrame,-16,2)
			m_fontify(followerFrame.Name,"white")
			m_fontify(followerFrame.PortraitFrame.Level,"white")
		end
	end
	
	QuestMapFrame:HookScript("OnShow",miirgui_QuestMapFrame)
	
	local function miirgui_QuestFrame()
		local numchildren = QuestInfoRewardsFrame:GetNumChildren()
		for i = 1,numchildren do
			local followerFrame=select(i,QuestInfoRewardsFrame:GetChildren())
			if followerFrame.Class then
				followerFrame.Class:SetAlpha(0)
				followerFrame.BG:ClearAllPoints()
				followerFrame.BG:SetSize(140,39)
				followerFrame.BG:SetPoint("RIGHT",followerFrame,40,3)
				followerFrame.BG:SetTexture("Interface\\AuctionFrame\\UI-AuctionItemNameFrame.blp")
				followerFrame.PortraitFrame.PortraitRing:SetAlpha(0)
				followerFrame.PortraitFrame.LevelBorder:SetAlpha(0)
				followerFrame.PortraitFrame.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
				followerFrame.PortraitFrame.PortraitRingQuality:SetTexture("Interface\\Buttons\\UI-Quickslot.blp")
				followerFrame.PortraitFrame.PortraitRingQuality:SetSize(84,84)
				followerFrame.PortraitFrame.PortraitRingQuality:ClearAllPoints()
				followerFrame.PortraitFrame.PortraitRingQuality:SetPoint("LEFT",followerFrame.PortraitFrame,-16,2)
				followerFrame.Name:ClearAllPoints()
				followerFrame.Name:SetPoint("TOPLEFT",followerFrame.BG,3,0)
				followerFrame.Name:SetPoint("BOTTOMRIGHT",followerFrame.BG,-6,0)
				m_fontify(followerFrame.Name,"white")
				m_fontify(followerFrame.PortraitFrame.Level,"white")
			end
		end
	end
	
	QuestFrame:HookScript("OnShow",miirgui_QuestFrame)

end)