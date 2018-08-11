local function skin_QuestFrame()

	QuestFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	QuestFramePortrait:SetSize(66,66)
	QuestFramePortrait:SetPoint("TOPLEFT",-9,10)

	m_SetTexture(WorldMapFramePortrait,"Interface\\Addons\\miirgui\\gfx\\quest.blp")
	--WorldMapFrameTutorialButton.Ring:SetAlpha(0)
	WorldMapFramePortrait:SetSize(66,66)
	WorldMapFramePortrait:SetPoint("TOPLEFT",-9,9)

	QuestMapDetailsScrollFrameScrollBarTrack:SetAlpha(0)
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

	m_fontify(QuestNPCModelNameText,"color")
	m_fontify(QuestInfoSkillPointFrame.ValueText,"white")
	m_fontify(QuestInfoMoneyFrameGoldButtonText,"white")
	m_fontify(QuestInfoMoneyFrameSilverButtonText,"white")
	m_fontify(QuestInfoMoneyFrameCopperButtonText,"white")
	m_fontify(QuestInfoXPFrame.ValueText,"white")
	m_fontify(QuestFont,"white")

	local _,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,QuestLogPopupDetailFramePortrait =QuestLogPopupDetailFrame:GetRegions()
	QuestLogPopupDetailFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	QuestLogPopupDetailFramePortrait:SetPoint("TOPLEFT",-9,9)

	local _,_,QuestMapFrameDetailsFrameRewardsFrameHeader= QuestMapFrame.DetailsFrame.RewardsFrame:GetRegions()
	m_fontify(QuestMapFrameDetailsFrameRewardsFrameHeader,"color")

	local function miirgui_GossipFrameUpdate()
		GossipFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
		GossipFramePortrait:SetSize(66,66)
		GossipFramePortrait:SetPoint("TOPLEFT",-9,10)
		m_fontify(GossipGreetingText,"white")
		for i=1, 32 do
			local button = _G["GossipTitleButton"..i]
			if button:GetFontString() then
				m_fontify(button:GetFontString(),"white")
				if button:GetFontString():GetText() and button:GetFontString():GetText():find("|cff000000") then
					button:GetFontString():SetText(string.gsub(button:GetFontString():GetText(), "|cff000000", "|cffffffff"))
				end
			end
		end
	end

	hooksecurefunc("GossipFrameUpdate",miirgui_GossipFrameUpdate)

	local function miirgui_QuestInfo_ShowObjectives()
		local _, _, finished;
		local numObjectives = GetNumQuestLeaderBoards();
		local objectivesTable = QuestInfoObjectivesFrame.Objectives;
		local numVisibleObjectives = 0;
		for i = 1,numObjectives do
			_, _, finished = GetQuestLogLeaderBoard(i);
			numVisibleObjectives = numVisibleObjectives+1;
			local objective = objectivesTable[numVisibleObjectives];
			if objective then
				if ( finished )  then
					m_fontify(objective,"green")
				else
					m_fontify(objective,"grey")
				end
			end
		end
	end

	hooksecurefunc("QuestInfo_Display",miirgui_QuestInfo_ShowObjectives)

	local function miirgui_q_fonts()
		m_fontify(QuestInfoTitleHeader,"color")
		m_fontify(QuestInfoDescriptionHeader,"color")
		m_fontify(QuestInfoObjectivesHeader,"color")
		m_fontify(QuestInfoDescriptionText,"white")
		m_fontify(QuestInfoObjectivesText,"white")
		m_fontify(QuestInfoGroupSize,"white")
		m_fontify(QuestInfoRewardText,"white")
		m_fontify(QuestInfoRewardsFrame.Header,"color")
		m_fontify(QuestInfoRewardsFrame.ItemReceiveText,"white")
	end

	QuestFrame:HookScript("OnShow",miirgui_q_fonts)
	QuestInfoObjectivesFrame:HookScript("OnShow",miirgui_q_fonts)
	QuestMapFrame.DetailsFrame:HookScript("OnShow",miirgui_q_fonts)
	QuestLogPopupDetailFrame:HookScript("OnShow",miirgui_q_fonts)
	QuestFrameRewardPanel:HookScript("OnShow",miirgui_q_fonts)
	QuestFrameDetailPanel:HookScript("OnShow",miirgui_q_fonts)

	MapQuestInfoRewardsFrame:HookScript("OnShow",function(self)
		local _,_,_,willlearn=self:GetRegions() -- You will learn the following
			if willlearn then
			m_fontify(willlearn,"white")
		end
		m_fontify(self.ItemReceiveText,"white")
		m_fontify(MapQuestInfoRewardsFramePoints,"white")
		m_fontify(MapQuestInfoRewardsFrameQuestInfoItem1.Name,"white")
		m_fontify(self.SkillPointFrame.Name,"white")
		m_fontify(self.XPFrame.Name,"white")
		m_fontify(self.MoneyFrame.Name,"white")
		m_fontify(self.ItemChooseText,"white")
	end)

	QuestInfoRewardsFrame:HookScript("OnShow",function(self)
		m_fontify(self.Header,"color")
		m_fontify(self.PlayerTitleText,"white")
		m_fontify(self.XPFrame.ReceiveText,"white")
		m_fontify(self.ItemReceiveText,"white")
		m_fontify(self.ItemChooseText,"white")
		local _,_,_,_,QuestInfoRewardsFramewilllearn = self:GetRegions()
		if QuestInfoRewardsFramewilllearn ~= nil then
			m_fontify(QuestInfoRewardsFramewilllearn,"white")
		end
		self.ArtifactXPFrame.Overlay:SetAlpha(0)
		end)

	QuestFrame:HookScript("OnEvent",function(_,event)
		if event == "QUEST_LOG_UPDATE" and QuestInfoRewardsFrame:IsVisible() and not WorldMapFrame:IsVisible() then
			QuestInfoRewardsFrame.spellHeaderPool.textR, QuestInfoRewardsFrame.spellHeaderPool.textG, QuestInfoRewardsFrame.spellHeaderPool.textB = 1,1,1
		elseif event == "QUEST_COMPLETE" and QuestInfoRewardsFrame:IsVisible() and not WorldMapFrame:IsVisible() then
			QuestInfoRewardsFrame.spellHeaderPool.textR, QuestInfoRewardsFrame.spellHeaderPool.textG, QuestInfoRewardsFrame.spellHeaderPool.textB = 1,1,1
		end
	end)

	local function miirgui_QuestFrameProgressItems_Update()
		m_fontify(QuestProgressTitleText,"color")
		m_fontify(QuestProgressText,"white")
		m_fontify(QuestProgressRequiredItemsText,"color")
		m_fontify(QuestProgressRequiredMoneyText,"white")
	end

	hooksecurefunc("QuestFrameProgressItems_Update", miirgui_QuestFrameProgressItems_Update)

	local function miirgui_greetings_panel()
		m_fontify(GreetingText,"white")
		m_fontify(CurrentQuestsText,"color")
		m_fontify(AvailableQuestsText,"color")
		for i=1, 32 do
			if _G["QuestTitleButton"..i] then
			local button = _G["QuestTitleButton"..i]
				if button:GetFontString() then
					if button:GetFontString():GetText() and button:GetFontString():GetText():find("|cff000000") then
					button:GetFontString():SetText(string.gsub(button:GetFontString():GetText(), "|cff000000", "|cffffffff"))
					end
				end
			end
		end
	end

	QuestFrameGreetingPanel:HookScript("OnShow", miirgui_greetings_panel)
	hooksecurefunc("QuestFrameGreetingPanel_OnShow",miirgui_greetings_panel)

	local function miirgui_QuestFrame()
		local numchildren = QuestInfoRewardsFrame:GetNumChildren()
		for i = 1,numchildren do
			local followerFrame=select(i,QuestInfoRewardsFrame:GetChildren())
			if followerFrame.Class then
				followerFrame.Class:SetAlpha(0)
				followerFrame.BG:ClearAllPoints()
				followerFrame.BG:SetSize(140,39)
				followerFrame.BG:SetPoint("RIGHT",followerFrame,40,3)
				m_SetTexture(followerFrame.BG,"Interface\\AuctionFrame\\UI-AuctionItemNameFrame.blp")
				followerFrame.PortraitFrame.PortraitRing:SetAlpha(0)
				followerFrame.PortraitFrame.LevelBorder:SetAlpha(0)
				followerFrame.PortraitFrame.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
				m_SetTexture(followerFrame.PortraitFrame.PortraitRingQuality,"Interface\\Buttons\\UI-Quickslot.blp")
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
	QuestLogPopupDetailFrame:HookScript("OnShow",miirgui_QuestFrame)

	local _,_,_,_,_,_,Bountyboard=WorldMapFrame:GetChildren()
	
	hooksecurefunc(Bountyboard,"RefreshBountyTabs",function(self)
		self.bountyTabPool:ReleaseAll();
		for bountyIndex, bounty in ipairs(self.bounties) do
			local tab = self.bountyTabPool:Acquire();
			local _,_,border= tab:GetRegions()
			border:ClearAllPoints()
			border:SetSize(58,58)
			border:SetPoint("CENTER",tab,0.5,2)
			border:SetVertexColor(miirguiDB.color.r,miirguiDB.color.g,miirguiDB.color.b,1)
			m_SetTexture(border,"Interface\\Buttons\\UI-ActionButton-Border.blp")
			tab.Icon:Hide()
			tab.EmptyIcon:Show()
			tab.EmptyIcon:SetTexture(bounty.icon)
			tab.EmptyIcon:SetSize(32,32)
			tab.bountyIndex = bountyIndex;
			tab.isEmpty = false;
			self:AnchorBountyTab(tab);
			tab:Show();
		end
		for bountyIndex = #self.bounties + 1, self.minimumTabsToDisplay do
			local tab = self.bountyTabPool:Acquire();
			local _,_,border= tab:GetRegions()
			border:ClearAllPoints()
			border:SetSize(58,58)
			border:SetPoint("CENTER",tab,0.5,2)
			border:SetVertexColor(miirguiDB.color.r,miirguiDB.color.g,miirguiDB.color.b,1)
			m_SetTexture(border,"Interface\\Buttons\\UI-ActionButton-Border.blp")
			tab.Icon:Hide();
			tab.EmptyIcon:Show();
			tab.EmptyIcon:SetSize(32,32)
			tab.bountyIndex = bountyIndex;
			tab.isEmpty = true;
			self:AnchorBountyTab(tab);
			tab:Show();
		end
	end)
	
	WorldMapFrame.BorderFrame.Tutorial.Ring:Hide()
	
end

local m_catch = CreateFrame("Frame")
m_catch:RegisterEvent("PLAYER_LOGIN")
m_catch:SetScript("OnEvent", skin_QuestFrame)
