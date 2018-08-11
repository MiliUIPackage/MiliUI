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
				local classcolor = {r=0.41,g=0.80,b=0.94,a=1}
				m_fontify(button.Follower.Name,classcolor)
			elseif string.find (follower.classAtlas,"Warrior") and not follower.isTroop then
				local classcolor = {r=0.78,g=0.61,b=0.43,a=1}
				m_fontify(button.Follower.Name,classcolor)
			elseif string.find (follower.classAtlas,"Rogue") and not follower.isTroop then
				local classcolor = {r=1.00,g=0.96,b=0.41,a=1}
				m_fontify(button.Follower.Name,classcolor)
			elseif string.find (follower.classAtlas,"Druid") and not follower.isTroop then
				local classcolor = {r=1.00,g=0.49,b=0.04,a=1}
				m_fontify(button.Follower.Name,classcolor)
			elseif string.find (follower.classAtlas,"Priest") and not follower.isTroop then
				local classcolor = {r=1,g=1,b=1,a=1}
				m_fontify(button.Follower.Name,classcolor)
			elseif string.find (follower.classAtlas,"Paladin") and not follower.isTroop then
				local classcolor = {r=0.96,g=0.55,b=0.73,a=1}
				m_fontify(button.Follower.Name,classcolor)
			elseif string.find (follower.classAtlas,"Hunter") and not follower.isTroop then
				local classcolor = {r=0.67,g=0.83,b=0.45,a=1}
				m_fontify(button.Follower.Name,classcolor)
			elseif string.find (follower.classAtlas,"Warlock") and not follower.isTroop then
				local classcolor = {r=0.58,g=0.51,b=0.79,a=1}
				m_fontify(button.Follower.Name,classcolor)
			elseif string.find (follower.classAtlas,"Monk") and not follower.isTroop then
				local classcolor = {r=0.33,g=0.54,b=0.52,a=1}
				m_fontify(button.Follower.Name,classcolor)
			elseif string.find (follower.classAtlas,"Shaman") and not follower.isTroop then
				local classcolor = {r=0.0,g=0.44,b=0.87,a=1}
				m_fontify(button.Follower.Name,classcolor)
			elseif string.find (follower.classAtlas,"Death") and not follower.isTroop then
				local classcolor = {r=0.77,g=0.12,b=0.23,a=1}
				m_fontify(button.Follower.Name,classcolor)
			elseif string.find (follower.classAtlas,"DemonHunter") and not follower.isTroop then
				local classcolor = {r=0.64,g=0.19,b=0.79,a=1}
				m_fontify(button.Follower.Name,classcolor)
			else
				m_fontify(button.Follower.Name,"white")
			end
			button.Follower.Class:Hide()
			button.Follower.PortraitFrame.LevelBorder:Hide()
			m_SetTexture(button.Follower.Highlight,"Interface\\Garrison\\followerhover.blp")
			button.Follower.Highlight:SetVertexColor(miirguiDB.color.r,miirguiDB.color.g,miirguiDB.color.b,1)
			button.Follower.Highlight:SetAlpha(0.2)
			button.Follower.Highlight:ClearAllPoints()
			button.Follower.Highlight:SetPoint("CENTER",button.Follower.PortraitFrame,130,0)
			button.Follower.Highlight:SetSize(256,64)

			button.Follower.Selection:SetVertexColor(miirguiDB.color.r,miirguiDB.color.g,miirguiDB.color.b,1)
			m_SetTexture(button.Follower.Selection,"Interface\\Garrison\\followerhover.blp")
			button.Follower.Selection:SetAlpha(0.2)
			button.Follower.Selection:SetSize(256,64)
			button.Follower.Selection:ClearAllPoints()
			button.Follower.Selection:SetPoint("CENTER",button.Follower.PortraitFrame,130,0)

			m_SetTexture(button.Follower.BG,"Interface\\Garrison\\follower.blp")
			button.Follower.BG:ClearAllPoints()
			button.Follower.BG:SetPoint("CENTER",button.Follower.PortraitFrame,130,0)
			button.Follower.BG:SetSize(256,64)

			button.Follower.PortraitFrame.PortraitRing:Hide()
			button.Follower.PortraitFrame.PortraitRingCover:Hide();
			button.Follower.PortraitFrame.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
			button.Follower.PortraitFrame.PortraitRingQuality:Show();
			m_SetTexture(button.Follower.PortraitFrame.PortraitRingQuality,"Interface\\Garrison\\qual.blp")
			button.Follower.PortraitFrame.PortraitRingQuality:SetSize(64,64)
			button.Follower.PortraitFrame.PortraitRingQuality:SetVertexColor(color.r, color.g, color.b);

			m_SetTexture(button.Follower.BusyFrame.Texture,"Interface\\Garrison\\followerhover.blp")
			button.Follower.BusyFrame.Texture:ClearAllPoints()
			button.Follower.BusyFrame.Texture:SetPoint("CENTER",button.Follower.PortraitFrame,130,0)
			button.Follower.BusyFrame.Texture:SetSize(256,64)

			if ( follower.status == GARRISON_FOLLOWER_INACTIVE ) then
				button.Follower.BusyFrame.Texture:SetVertexColor(0.22, 0.06, 0, 0.44);
			elseif ( follower.status ) then
				button.Follower.BusyFrame.Texture:SetVertexColor(0.22, 0.06, 0, 0.44);
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

	local background = self.MissionTab.MissionList.CompleteDialog.BorderFrame:GetRegions()
	background:ClearAllPoints()
	background:SetSize(208,156)
	background:SetPoint("CENTER",self.MissionTab.MissionList.CompleteDialog.BorderFrame.ViewButton,0,90)
	m_SetTexture(background,"Interface\\FrameGeneral\\UI-Background-Marble.blp")

	local _,_,_,_,_,_,_,_,_,_,_,_,chest = self.MissionTab.MissionList.CompleteDialog.BorderFrame:GetRegions()
	chest:ClearAllPoints()
	chest:SetPoint("CENTER",self.MissionTab.MissionList.CompleteDialog.BorderFrame,0,90)
	chest:SetSize(256,256)
	m_SetTexture(chest,"Interface\\Garrison\\complete.blp")

	for i=2,12 do
		local hideit=select(i,self.MissionTab.MissionList.CompleteDialog.BorderFrame:GetRegions())
		hideit:Hide()
	end
	self.MissionTab.MissionList.CompleteDialog.BorderFrame.ViewButton:ClearAllPoints()
	self.MissionTab.MissionList.CompleteDialog.BorderFrame.ViewButton:SetWidth(216)
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
			local followerbg = follower:GetRegions()
			m_SetTexture(followerbg,"Interface\\FrameGeneral\\UI-Background-Rock.blp")
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
			_,_,_,follower.XP.XPMid = follower.XP:GetRegions()
			follower.XP.XPMid:Hide()
			follower.PortraitFrame.PortraitRing:Hide()
			m_SetTexture(follower.PortraitFrame.PortraitRingQuality,"Interface\\Garrison\\qual.blp")
			follower.PortraitFrame.PortraitRingQuality:SetSize(64,64)
			follower.PortraitFrame.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
			follower.PortraitFrame.LevelBorder:Hide()
			follower.PortraitFrame.LevelBorder:SetAlpha(0)
			m_fontify(follower.PortraitFrame.Level,"white")
		end
	end

	self.MissionComplete.ChanceFrame.GreenGlow:Hide()
	self.MissionComplete.ChanceFrame.Banner:Hide()
	self.MissionComplete.ChanceFrame.ChanceBG:Hide()
	self.MissionComplete.ChanceFrame.SuccessGlow:Hide()
	if self.MissionComplete.BonusRewards.BonusChanceLabel then
		m_fontify(self.MissionComplete.BonusRewards.BonusChanceLabel,"white")
	end

end

local function miirgui_Expand(self,button)
		local bility = self:ExpandButtonAbilities(button, false);
		if bility >= 30 and bility < 32 then
			m_SetTexture(button.AbilitiesBG,"Interface\\Garrison\\bility1.blp")
			button.AbilitiesBG:SetSize(256,64)
		elseif bility >= 54 and bility < 55 then
			m_SetTexture(button.AbilitiesBG,"Interface\\Garrison\\bility2.blp")
			button.AbilitiesBG:SetSize(256,64)
		elseif bility >= 77 and bility < 78 then
			m_SetTexture(button.AbilitiesBG,"Interface\\Garrison\\bility3.blp")
			button.AbilitiesBG:SetSize(256,128)
		elseif bility >= 100 and bility < 101 then
			m_SetTexture(button.AbilitiesBG,"Interface\\Garrison\\bility4.blp")
			button.AbilitiesBG:SetSize(256,128)
		elseif bility >= 102 and bility < 124 then
			m_SetTexture(button.AbilitiesBG,"Interface\\Garrison\\bility5.blp")
			button.AbilitiesBG:SetSize(256,128)
		elseif  bility >= 146 then
			m_SetTexture(button.AbilitiesBG,"Interface\\Garrison\\bility6.blp")
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
					m_SetTexture(Mechanic.Border,"Interface\\Buttons\\CheckButtonGlow.blp")
					Mechanic.CheckBurst:Hide()
					Mechanic.CheckGlow:Hide()
					Mechanic.Check:ClearAllPoints()
					Mechanic.Check:SetSize(30,30)
					Mechanic.Check:SetPoint("CENTER",Mechanic,0.5,0)
					m_SetTexture(Mechanic.Check,"Interface\\Garrison\\newinvasion.blp")
					Mechanic.Check:SetVertexColor(0,1,0,1)
				end
			end
		end

local catchaddon = CreateFrame("FRAME")
catchaddon:RegisterEvent("ADDON_LOADED")

--function to catch loading addons
local function skinnedOnLoad(_, _, addon)
	if addon == "Blizzard_GarrisonUI" then
		hooksecurefunc(GarrisonMissionFrameFollowers,"UpdateData",miirgui_UpdateData)
		hooksecurefunc(GarrisonLandingPage.FollowerList,"UpdateData",miirgui_UpdateData)
		hooksecurefunc(GarrisonRecruitSelectFrame.FollowerList,"UpdateData",miirgui_UpdateData)
		hooksecurefunc(GarrisonBuildingFrameFollowers,"UpdateData",miirgui_UpdateData)
		hooksecurefunc(GarrisonMission,"CheckCompleteMissions",miirgui_CheckCompleteMissions)
		hooksecurefunc(GarrisonMissionFrameFollowers,"ExpandButton",miirgui_Expand)
		hooksecurefunc(GarrisonRecruitSelectFrame.FollowerList,"ExpandButton",miirgui_Expand)
		hooksecurefunc(GarrisonMission,"SetEnemies",miirgui_SetEnemies)
		hooksecurefunc(OrderHallMissionFrameFollowers,"UpdateData",miirgui_UpdateData)
		hooksecurefunc(OrderHallMissionFrameFollowers,"ExpandButton",miirgui_Expand)
		--BFA
		hooksecurefunc(BFAMissionFrameFollowers,"UpdateData",miirgui_UpdateData)
		hooksecurefunc(BFAMissionFrameFollowers,"ExpandButton",miirgui_Expand)
	end
	--[[
	if addon == "Blizzard_GarrisonUI" and addon == "Blizzard_GarrisonUI" then
		hooksecurefunc(OrderHallMissionFrameFollowers,"UpdateData",miirgui_UpdateData)
		hooksecurefunc(OrderHallMissionFrameFollowers,"ExpandButton",miirgui_Expand)
		--print("4")
	end]]
	

end

--this function decides whether the addon is already loaded or if we need to look out for it!

local function skinnedOnLogin()
	if IsAddOnLoaded("Blizzard_GarrisonUI") then
		-- Addon is already loaded, procceed to skin!
		hooksecurefunc(GarrisonMissionFrameFollowers,"UpdateData",miirgui_UpdateData)
		hooksecurefunc(GarrisonLandingPage.FollowerList,"UpdateData",miirgui_UpdateData)
		hooksecurefunc(GarrisonRecruitSelectFrame.FollowerList,"UpdateData",miirgui_UpdateData)
		hooksecurefunc(GarrisonBuildingFrameFollowers,"UpdateData",miirgui_UpdateData)
		hooksecurefunc(GarrisonMission,"CheckCompleteMissions",miirgui_CheckCompleteMissions)
		hooksecurefunc(GarrisonMissionFrameFollowers,"ExpandButton",miirgui_Expand)
		hooksecurefunc(GarrisonRecruitSelectFrame.FollowerList,"ExpandButton",miirgui_Expand)
		hooksecurefunc(GarrisonMission,"SetEnemies",miirgui_SetEnemies)
		hooksecurefunc(OrderHallMissionFrameFollowers,"UpdateData",miirgui_UpdateData)
		hooksecurefunc(OrderHallMissionFrameFollowers,"ExpandButton",miirgui_Expand)
		--BFA
		hooksecurefunc(BFAMissionFrameFollowers,"UpdateData",miirgui_UpdateData)
		hooksecurefunc(BFAMissionFrameFollowers,"ExpandButton",miirgui_Expand)
	else
		-- Addon is not loaded yet, procceed to look out for it!
		catchaddon:SetScript("OnEvent", skinnedOnLoad)
	end
	--[[
	if IsAddOnLoaded("Blizzard_OrderHallUI") and IsAddOnLoaded("Blizzard_GarrisonUI") then
		-- Addon is already loaded, procceed to skin!
		hooksecurefunc(OrderHallMissionFrameFollowers,"UpdateData",miirgui_UpdateData)
		hooksecurefunc(OrderHallMissionFrameFollowers,"ExpandButton",miirgui_Expand)
		--print("3")
	else
		-- Addon is not loaded yet, procceed to look out for it!
		catchaddon:SetScript("OnEvent", skinnedOnLoad)
	end]]

end

local HelloWorld = CreateFrame("FRAME")
HelloWorld:RegisterEvent("PLAYER_ENTERING_WORLD")
HelloWorld:SetScript("OnEvent", skinnedOnLogin)