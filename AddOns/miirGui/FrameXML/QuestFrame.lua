local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
	QuestFramePortrait:SetSize(66,66)
	QuestFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	QuestFramePortrait:SetPoint("TOPLEFT",-9,10)	
	
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
	
	QuestFrameGreetingPanelBg:Hide()
	WorldMapFrameTutorialButton.Ring:Hide()
	WorldMapFramePortrait:SetWidth(66)
	WorldMapFramePortrait:SetHeight(66)
	WorldMapFramePortrait:SetPoint("TOPLEFT",-9,9)
	WorldMapFramePortrait:SetTexture("Interface\\Addons\\miirgui\\gfx\\quest.blp")
	local GossipFrameBackground = select(19,GossipFrame:GetRegions())
	GossipFrameBackground:Hide()
	QuestFrameDetailPanelBg:Hide()
	QuestFrameRewardPanelBg:Hide()
	QuestMapDetailsScrollFrameScrollBarTrack:Hide()
	QuestFrameProgressPanelBg:Hide()
	QuestNPCModelTopBorder:Hide()
	QuestNPCModelLeftBorder:Hide()
	QuestNPCModelRightBorder:Hide()
	QuestNPCModelBottomBorder:Hide()
	QuestNPCModelBotLeftCorner:Hide()
	QuestNPCModelBotRightCorner:Hide()
	QuestNPCModelTextBottomBorder:Hide()
	QuestNPCModelTextLeftBorder:Hide()
	QuestNPCModelTextRightBorder:Hide()
	QuestNPCModelTextBotRightCorner:Hide()
	QuestNPCModelTextBotLeftCorner:Hide()
	QuestNPCModelNameplate:SetAlpha(0)
	QuestNPCModelShadowOverlay:Hide()
	QuestNPCModelTopBg:Hide()	
	QuestNPCModelBg:ClearAllPoints()
	QuestNPCModelBg:SetPoint("TOPLEFT","QuestNPCModel",0,16)
	QuestNPCModelBg:SetPoint("BOTTOMRIGHT","QuestNPCModel",0,-86)
	m_border(QuestNPCModel,202,336,"CENTER",1,-34,14,"MEDIUM")
	m_border(QuestFrame,330,412,"CENTER",-1,-17,14,"MEDIUM")
	m_border(QuestLogPopupDetailFrame,330,412,"CENTER",-1,-17,14,"MEDIUM")
	m_border(GossipFrame,330,412,"CENTER",-1,-17,14,"MEDIUM")

	local function miirgui_QuestInfo_Display(_, parentFrame)
		local questFrame = parentFrame:GetParent():GetParent()
		local sealMaterialBG = questFrame.SealMaterialBG
		local numObjectives = GetNumQuestLeaderBoards();
		local objective;
		local _, type, finished;
		local objectivesTable = QuestInfoObjectivesFrame.Objectives;
		local numVisibleObjectives = 0;
		if sealMaterialBG then	
			sealMaterialBG:Hide()
		end
		
		QuestInfoRewardsFrame.ArtifactXPFrame.Overlay:Hide()
		local QuestLogPopupDetailFrameBackground= select(18,QuestLogPopupDetailFrame:GetRegions())
		QuestLogPopupDetailFrameBackground:Hide()
		local QuestLogPopupDetailFramePortrait= select(24,QuestLogPopupDetailFrame:GetRegions())
		QuestLogPopupDetailFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
		QuestLogPopupDetailFramePortrait:SetPoint("TOPLEFT",-9,9)
		QuestFramePortrait:SetSize(66,66)
		QuestFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
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
		
		local QuestInfoRewardsFramewilllearn = select(5,QuestInfoRewardsFrame:GetRegions())
		if QuestInfoRewardsFramewilllearn ~= nil then
			m_fontify(QuestInfoRewardsFramewilllearn,"white")
		end
		
		for i = 1, numObjectives do
			_, type, finished = GetQuestLogLeaderBoard(i);
			if (type ~= "spell" and type ~= "log" and numVisibleObjectives < MAX_OBJECTIVES) then
				numVisibleObjectives = numVisibleObjectives+1;
				objective = objectivesTable[numVisibleObjectives];
				if ( not objective ) then
					objective = QuestInfoObjectivesFrame:CreateFontString("QuestInfoObjective"..numVisibleObjectives, "BACKGROUND", "QuestFontNormalSmall");
				end
				if ( finished ) then
					m_fontify(objective,"green")
				else
					m_fontify(objective,"grey")
				end
			end
		end
		m_fontify(QuestInfoSealFrame.Text,"same")
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
	
	QuestFrameGreetingPanel:HookScript("OnUpdate", function()
		m_fontify(GreetingText,"white")
		m_fontify(CurrentQuestsText,"color")
		m_fontify(AvailableQuestsText,"color")
		for i=1, MAX_NUM_QUESTS do
			local button = _G["QuestTitleButton"..i]
			if button:GetFontString() then
				if button:GetFontString():GetText() and button:GetFontString():GetText():find("|cff000000") then
				button:GetFontString():SetText(string.gsub(button:GetFontString():GetText(), "|cff000000", "|cffffffff"))
				m_fontify(button:GetFontString(),"color")
				end
			end
		end
	end)
	
	
	local function miirgui_QuestMapFrame()
			for key in pairs(MapQuestInfoRewardsFrame["followerRewardPool"]) do
			local followerFrame = MapQuestInfoRewardsFrame.followerRewardPool:Acquire();	
			followerFrame.Class:Hide()
			followerFrame.BG:ClearAllPoints()
			followerFrame.BG:SetSize(140,39)
			followerFrame.BG:SetPoint("RIGHT",followerFrame,40,3)
			followerFrame.BG:SetTexture("Interface\\AuctionFrame\\UI-AuctionItemNameFrame.blp")
			followerFrame.PortraitFrame.PortraitRing:Hide()
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
			for key in pairs(QuestInfoRewardsFrame["followerRewardPool"]) do
			local followerFrame = QuestInfoRewardsFrame.followerRewardPool:Acquire();	
			followerFrame.Class:Hide()
			followerFrame.BG:ClearAllPoints()
			followerFrame.BG:SetSize(140,39)
			followerFrame.BG:SetPoint("RIGHT",followerFrame,40,3)
			followerFrame.BG:SetTexture("Interface\\AuctionFrame\\UI-AuctionItemNameFrame.blp")
			followerFrame.PortraitFrame.PortraitRing:Hide()
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
	
	QuestFrame:HookScript("OnEvent",miirgui_QuestFrame)

end)