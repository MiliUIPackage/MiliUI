	local function miirgui_UpdateData(self)
		local followers = self.followers
		local followersList = self.followersList
		local numFollowers = #followersList
		local scrollFrame = self.listScroll
		local offset = HybridScrollFrame_GetOffset(scrollFrame)
		local buttons = scrollFrame.buttons
		local numButtons = #buttons
		for i = 1, numButtons do
			local button = buttons[i]
			local index = offset + i
			if ( index <= numFollowers and followersList[index] == 0 ) then		
				m_fontify(button.Category,"white")
			elseif ( index <= numFollowers ) then
				local follower = followers[followersList[index]]
				local color = ITEM_QUALITY_COLORS[follower.quality]		
				if string.find (follower.classAtlas,"Mage") and not follower.isTroop then
					local classcolor = {0.41,0.80,0.94,1}
					m_fontify(button.Follower.Name,classcolor)		
				elseif string.find (follower.classAtlas,"Warrior") and not follower.isTroop then
					local classcolor = {0.78,0.61,0.43,1}
					m_fontify(button.Follower.Name,classcolor)		
				elseif string.find (follower.classAtlas,"Rogue") and not follower.isTroop then
					local classcolor = {1.00,0.96,0.41,1}
					m_fontify(button.Follower.Name,classcolor)		
				elseif string.find (follower.classAtlas,"Druid") and not follower.isTroop then
					local classcolor = {1.00,0.49,0.04,1}
					m_fontify(button.Follower.Name,classcolor)				
				elseif string.find (follower.classAtlas,"Priest") and not follower.isTroop then
					local classcolor = {1,1,1,1}
					m_fontify(button.Follower.Name,classcolor)
				elseif string.find (follower.classAtlas,"Paladin") and not follower.isTroop then
					local classcolor = {0.96,0.55,0.73,1}
					m_fontify(button.Follower.Name,classcolor)				
				elseif string.find (follower.classAtlas,"Hunter") and not follower.isTroop then
					local classcolor = {0.67,0.83,0.45,1}
					m_fontify(button.Follower.Name,classcolor)			
				elseif string.find (follower.classAtlas,"Warlock") and not follower.isTroop then
					local classcolor = {0.58,0.51,0.79,1}
					m_fontify(button.Follower.Name,classcolor)		
				elseif string.find (follower.classAtlas,"Monk") and not follower.isTroop then
					local classcolor = {0.33,0.54,0.52,1}
					m_fontify(button.Follower.Name,classcolor)		
				elseif string.find (follower.classAtlas,"Shaman") and not follower.isTroop then
					local classcolor = {0.0,0.44,0.87,1}
					m_fontify(button.Follower.Name,classcolor)	
				elseif string.find (follower.classAtlas,"Death") and not follower.isTroop then
					local classcolor = {0.77,0.12,0.23,1}
					m_fontify(button.Follower.Name,classcolor)	
				elseif string.find (follower.classAtlas,"DemonHunter") and not follower.isTroop then
					local classcolor = {0.64,0.19,0.79,1}
					m_fontify(button.Follower.Name,classcolor)
				else
					m_fontify(button.Follower.Name,"white")
				end			
				button.Follower.Class:Hide()
				button.Follower.PortraitFrame.LevelBorder:Hide()
				m_fontify(button.Follower.PortraitFrame.Level,"same")
				m_fontify(button.Follower.ILevel,"same")
				m_fontify(button.Follower.Status,"same")
				button.Follower.Highlight:SetTexture("Interface\\Garrison\\followerhover.blp")
				button.Follower.Highlight:SetVertexColor(unpack(miirgui.Color))
				button.Follower.Highlight:SetAlpha(0.2)
				button.Follower.Highlight:ClearAllPoints()
				button.Follower.Highlight:SetPoint("CENTER",button.Follower.PortraitFrame,130,0)
				button.Follower.Highlight:SetSize(256,64)
				
				button.Follower.Selection:SetVertexColor(unpack(miirgui.Color))
				button.Follower.Selection:SetTexture("Interface\\Garrison\\followerhover.blp")
				button.Follower.Selection:SetAlpha(0.2)
				button.Follower.Selection:SetSize(256,64)
				button.Follower.Selection:ClearAllPoints()
				button.Follower.Selection:SetPoint("CENTER",button.Follower.PortraitFrame,130,0)
				
				button.Follower.BG:SetTexture("Interface\\Garrison\\follower.blp")
				button.Follower.BG:ClearAllPoints()
				button.Follower.BG:SetPoint("CENTER",button.Follower.PortraitFrame,130,0)
				button.Follower.BG:SetSize(256,64)
				
				button.Follower.PortraitFrame.PortraitRing:Hide()
				button.Follower.PortraitFrame.PortraitRingCover:Hide();
				button.Follower.PortraitFrame.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
				button.Follower.PortraitFrame.PortraitRingQuality:Show();
				button.Follower.PortraitFrame.PortraitRingQuality:SetTexture("Interface\\Garrison\\qual.blp")
				button.Follower.PortraitFrame.PortraitRingQuality:SetSize(64,64)
				button.Follower.PortraitFrame.PortraitRingQuality:SetVertexColor(color.r, color.g, color.b);
				
				button.Follower.BusyFrame.Texture:SetTexture("Interface\\Garrison\\followerhover.blp")	
				button.Follower.BusyFrame.Texture:ClearAllPoints()
				button.Follower.BusyFrame.Texture:SetPoint("CENTER",button.Follower.PortraitFrame,130,0)
				button.Follower.BusyFrame.Texture:SetSize(256,64)

				if ( follower.status == GARRISON_FOLLOWER_INACTIVE ) then		
					button.Follower.BusyFrame.Texture:SetVertexColor(unpack(GARRISON_FOLLOWER_INACTIVE_COLOR));	
				elseif ( follower.status ) then
					button.Follower.BusyFrame.Texture:SetVertexColor(unpack(GARRISON_FOLLOWER_INACTIVE_COLOR));		
				end
				if ( follower.isCollected ) then
					button.Follower.PortraitFrame.Portrait:SetDesaturated(false)
					button.Follower.BG:SetDesaturated(false)
				else
					button.Follower.PortraitFrame.Portrait:SetDesaturated(true)
					button.Follower.BG:SetDesaturated(true)
				end				
			end
		end
	end 

	local function miirgui_CheckCompleteMissions(self)
		self.MissionTab.MissionList.CompleteDialog.BorderFrame.Model:Hide()
		self.MissionTab.MissionList.CompleteDialog.BorderFrame.Stage:Hide()
		
		local background=select(1,self.MissionTab.MissionList.CompleteDialog.BorderFrame:GetRegions())
		background:ClearAllPoints()
		background:SetSize(208,156)
		background:SetPoint("CENTER",self.MissionTab.MissionList.CompleteDialog.BorderFrame.ViewButton,0,90)
		background:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble.blp")
		
		local chest = select(13,self.MissionTab.MissionList.CompleteDialog.BorderFrame:GetRegions())
		chest:ClearAllPoints()
		chest:SetPoint("CENTER",self.MissionTab.MissionList.CompleteDialog.BorderFrame,0,90)
		chest:SetSize(256,256)
		chest:SetTexture("Interface\\Garrison\\complete.blp")
		
		for i=2,12 do
			local hideit=select(i,self.MissionTab.MissionList.CompleteDialog.BorderFrame:GetRegions())
			hideit:Hide()
		end
		self.MissionTab.MissionList.CompleteDialog.BorderFrame.ViewButton:ClearAllPoints()
		self.MissionTab.MissionList.CompleteDialog.BorderFrame.ViewButton:SetPoint("CENTER",0,0)
		m_border(self.MissionTab.MissionList.CompleteDialog.BorderFrame.ViewButton,212,160,"CENTER",0,90.5,14,"MEDIUM")	
		
		if self:GetName() == "OrderHallMissionFrame" then
			m_fontify(OrderHallMissionFrameMissionsText,"green")
		elseif self:GetName() == "GarrisonShipyardFrame" then
			m_fontify(GarrisonShipyardFrameText,"green")
		elseif self:GetName() == "GarrisonMissionFrame" then
			m_fontify(GarrisonMissionFrameMissionsText,"green")
		end
		if self:GetName() == "GarrisonShipyardFrame" then
		else
			for i=1, 3 do	
				local follower = self.MissionComplete.Stage.FollowersFrame.Followers[i];		
				local followerbg=select(1,follower:GetRegions())
				followerbg:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock.blp")
				followerbg:ClearAllPoints()
				followerbg:SetPoint("CENTER",24,4)
				followerbg:SetSize(120,47)			
				follower.Class:Hide()
				m_fontify(follower.Name,"white")
				follower.XP:ClearAllPoints()
				follower.XP:SetPoint("CENTER",25,-10)
				follower.XP:SetWidth(116)					
				follower.XP.XPLeft:Hide()
				follower.XP.XPRight:Hide()
				follower.XP.XPMid=select(4,follower.XP:GetRegions())
				follower.XP.XPMid:Hide()
				follower.PortraitFrame.PortraitRing:Hide()
				follower.PortraitFrame.PortraitRingQuality:SetTexture("Interface\\Garrison\\qual.blp")
				follower.PortraitFrame.PortraitRingQuality:SetSize(64,64)
				follower.PortraitFrame.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
				follower.PortraitFrame.LevelBorder:Hide()
				follower.PortraitFrame.LevelBorder:SetAlpha(0)
				m_fontify(follower.PortraitFrame.Level,"white")
				follower.DurabilityBackground:Hide()
				follower.DurabilityBackground:SetAlpha(0)
				follower.DurabilityBackground:ClearAllPoints()
			end	
		end

		self.MissionComplete.ChanceFrame.GreenGlow:Hide()
		self.MissionComplete.ChanceFrame.Banner:Hide()
		self.MissionComplete.ChanceFrame.ChanceBG:Hide()
		self.MissionComplete.ChanceFrame.SuccessGlow:Hide()
		m_fontify(self.MissionComplete.ChanceFrame.ChanceText,"same")	
		m_fontify(self.MissionComplete.ChanceFrame.ResultText,"same")	
		if self.MissionComplete.BonusRewards.BonusChanceLabel then
			m_fontify(self.MissionComplete.BonusRewards.BonusChanceLabel,"white")
			m_fontify(self.MissionComplete.BonusText.BonusText,"same")
		end
		
	end
	
	local function miirgui_Expand(self,button)
			local bility = self:ExpandButtonAbilities(button, false);
			if bility >= 30 and bility < 32 then
				button.AbilitiesBG:SetTexture("Interface\\Garrison\\bility1.blp")
				button.AbilitiesBG:SetSize(256,64)
			elseif bility >= 54 and bility < 55 then
				button.AbilitiesBG:SetTexture("Interface\\Garrison\\bility2.blp")
				button.AbilitiesBG:SetSize(256,64)
			elseif bility >= 77 and bility < 78 then
				button.AbilitiesBG:SetTexture("Interface\\Garrison\\bility3.blp")
				button.AbilitiesBG:SetSize(256,128)
			elseif bility >= 100 and bility < 101 then
				button.AbilitiesBG:SetTexture("Interface\\Garrison\\bility4.blp")
				button.AbilitiesBG:SetSize(256,128)
			elseif bility >= 102 and bility < 124 then
				button.AbilitiesBG:SetTexture("Interface\\Garrison\\bility5.blp")
				button.AbilitiesBG:SetSize(256,128)
			elseif  bility >= 146 then
				button.AbilitiesBG:SetTexture("Interface\\Garrison\\bility6.blp")
			button.AbilitiesBG:SetSize(256,256)
			
			end
			button.UpArrow:ClearAllPoints()
			button.UpArrow:SetPoint("TOPRIGHT",-10,-46)
		end

		local function miirgui_SetEnemies(self,missionPage, enemies)
			for i=1, #enemies do
				local Frame = missionPage.Enemies[i];
				local enemy = enemies[i];
				local numMechs = 0;
				local sortedKeys = self:SortMechanics(enemy.mechanics);
				for _, id in ipairs(sortedKeys) do
					numMechs = numMechs + 1;
					local Mechanic = Frame.Mechanics[numMechs];	
					Mechanic.Border:Show()	
					Mechanic.Border:ClearAllPoints()
					Mechanic.Border:SetSize(52,52)
					Mechanic.Border:SetPoint("CENTER",Mechanic,0.5,0)
					Mechanic.Border:SetTexture("Interface\\Buttons\\CheckButtonGlow.blp")
					Mechanic.CheckBurst:Hide()
					Mechanic.CheckGlow:Hide()
					Mechanic.Check:ClearAllPoints()
					Mechanic.Check:SetSize(30,30)
					Mechanic.Check:SetPoint("CENTER",Mechanic,0.5,0)
					Mechanic.Check:SetTexture("Interface\\Garrison\\newinvasion.blp")
					Mechanic.Check:SetVertexColor(0,1,0,1)
				end
			end
		end	

	local frame = CreateFrame("FRAME")
	frame:RegisterEvent("ADDON_LOADED")
	function frame:OnEvent(event, arg1)
		if event == "ADDON_LOADED" and arg1 == "Blizzard_GarrisonUI" then			
			hooksecurefunc(GarrisonMissionFrameFollowers,"UpdateData",miirgui_UpdateData)	
			hooksecurefunc(GarrisonLandingPage.FollowerList,"UpdateData",miirgui_UpdateData)		
			hooksecurefunc(GarrisonRecruitSelectFrame.FollowerList,"UpdateData",miirgui_UpdateData)
			hooksecurefunc(GarrisonBuildingFrameFollowers,"UpdateData",miirgui_UpdateData)
			hooksecurefunc(GarrisonMission,"CheckCompleteMissions",miirgui_CheckCompleteMissions)
			hooksecurefunc(GarrisonMissionFrameFollowers,"ExpandButton",miirgui_Expand)
			hooksecurefunc(GarrisonRecruitSelectFrame.FollowerList,"ExpandButton",miirgui_Expand)
			hooksecurefunc(GarrisonMission,"SetEnemies",miirgui_SetEnemies)
		end
		if event == "ADDON_LOADED" and arg1 == "Blizzard_OrderHallUI" then
			hooksecurefunc(OrderHallMissionFrameFollowers,"UpdateData",miirgui_UpdateData)
			hooksecurefunc(OrderHallMissionFrameFollowers,"ExpandButton",miirgui_Expand)
		end
	end	
	frame:SetScript("OnEvent", frame.OnEvent);