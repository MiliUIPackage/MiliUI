local function skin_Blizzard_OrderHallUI()

		--[[ Order Hall Main Frame ]] --
		
		OrderHallMissionTutorialFrameBg:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 1)
		OrderHallMissionTutorialFrameBg:SetColorTexture(0.078,0.078,0.078,1)

		local Border = CreateFrame("Frame", "TutBorder", OrderHallMissionTutorialFrame.GlowBox)
		Border:SetSize(23, 23)
		Border:SetPoint("TOPLEFT",-3,2.5)
		Border:SetPoint("BOTTOMRIGHT",3,-2.5)	
		Border:SetBackdrop({
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border_blue.blp",
		edgeSize = 14})
		Border:SetBackdropBorderColor(1, 1, 1)
		Border:SetFrameStrata("TOOLTIP")
			
		m_fontify(OrderHallMissionTutorialFrame.GlowBox.BigText,"white")	
		
		OrderHallMissionFrame.ClassHallIcon:Hide()
	
		m_SetTexture(OrderHallMissionFrame.Top,"Interface\\FrameGeneral\\UI-Background-Rock.blp")
		m_SetTexture(OrderHallMissionFrame.Left,"Interface\\FrameGeneral\\UI-Background-Rock.blp")
		m_SetTexture(OrderHallMissionFrame.Right,"Interface\\FrameGeneral\\UI-Background-Rock.blp")
		m_SetTexture(OrderHallMissionFrame.Bottom,"Interface\\FrameGeneral\\UI-Background-Rock.blp")
		OrderHallMissionFrame.GarrCorners.TopLeftGarrCorner:Hide()
		OrderHallMissionFrame.GarrCorners.TopRightGarrCorner:Hide()
		OrderHallMissionFrame.GarrCorners.BottomLeftGarrCorner:Hide()
		OrderHallMissionFrame.GarrCorners.BottomRightGarrCorner:Hide()
		AdventureMapQuestChoiceDialog.Details.ScrollBar.Background:Hide()
		m_SetTexture(AdventureMapQuestChoiceDialog.Background,"Interface\\FrameGeneral\\UI-Background-Rock.blp")	
		AdventureMapQuestChoiceDialog.Rewards:SetAlpha(0)
		OrderHallTalentFramePortrait:SetMask("")
		m_SetTexture(OrderHallTalentFramePortrait,"Interface\\Icons\\inv_orderhall_orderresources.blp")
		OrderHallTalentFramePortrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
		m_border(OrderHallTalentFrame,330,388,"CENTER",-1,-26,14,"MEDIUM")
		m_border(OrderHallMissionFrameMissionsListScrollFrame,900,550,"CENTER",0,-2	,14,"MEDIUM")
		m_border_OrderHallMissionFrameMissionsListScrollFrame:SetPoint("TOPLEFT","OrderHallMissionFrameMissionsListScrollFrame",0,6)
		m_border_OrderHallMissionFrameMissionsListScrollFrame:SetPoint("BOTTOMRIGHT","OrderHallMissionFrameMissionsListScrollFrame",0,-6)
		m_border(OrderHallMissionFrameMissions.CombatAllyUI,881,120,"CENTER",1,0,12,"MEDIUM")
		m_border(OrderHallMissionFrameFollowers,310,570,"CENTER",0,-16,12,"HIGH")
		m_border(OrderHallMissionFrame.FollowerTab,580,570,"CENTER",0.5,-1,12,"HIGH")
		m_border(OrderHallMissionFrameMissions.MaterialFrame,300,26,"CENTER",0.5,0,12,"MEDIUM")
		m_border(OrderHallMissionFrameFollowers.MaterialFrame,300,26,"CENTER",0,0,12,"HIGH")
		m_border(OrderHallMissionFrame.MissionComplete,550,290,"CENTER",0,148,14,"HIGH")
		m_border(OrderHallMissionFrame.MissionComplete,560,600,"CENTER",0,0,14,"HIGH")
		m_border(OrderHallMissionFrame.MissionTab.MissionPage.Stage,554,238,"CENTER",0,0,14,"MEDIUM")
		m_border(OrderHallMissionFrameMissionsTab2,180,24,"CENTER",0,0,14,"MEDIUM")
		m_border(OrderHallMissionFrameMissionsTab1,180,24,"CENTER",0,0,14,"MEDIUM")
		m_border(OrderHallMissionFrame.MissionTab.MissionPage.RewardsFrame.Reward1,100,46,"CENTER",20,0,14,"HIGH")
		m_border(OrderHallMissionFrame.MissionTab.MissionPage.RewardsFrame.Reward1,46,46,"LEFT",-1,0,14,"HIGH")
		m_border(OrderHallMissionFrame.MissionTab.MissionPage.RewardsFrame.Reward2,100,46,"CENTER",20,0,14,"HIGH")
		m_border(OrderHallMissionFrame.MissionTab.MissionPage.RewardsFrame.Reward2,46,46,"LEFT",-1,0,14,"HIGH")
		m_border(OrderHallMissionFrame.FollowerTab.XPBar,504,16,"CENTER",0.5,0,12,"HIGH")
		m_border(OrderHallMissionFrame.MissionTab.ZoneSupportMissionPage,542,122,"CENTER",0,0,14,"HIGH")
		m_border(AdventureMapQuestChoiceDialog,358,444,"CENTER",0,-0.5,14,"HIGH")
		AdventureMapQuestChoiceDialog.Background:ClearAllPoints()
		AdventureMapQuestChoiceDialog.Background:SetSize(350,436)
		AdventureMapQuestChoiceDialog.Background:SetPoint("CENTER",AdventureMapQuestChoiceDialog,0,-1)
		m_border(OrderHallMissionFrame.MissionComplete.Stage.FollowersFrame.Follower2,124,49,"CENTER",24,4,12,"HIGH")
		m_border(OrderHallMissionFrame.MissionComplete.Stage.FollowersFrame.Follower3,124,49,"CENTER",24,4,12,"HIGH")
		m_border(OrderHallMissionFrame.MissionComplete.Stage.FollowersFrame.Follower1,124,49,"CENTER",24,4,12,"HIGH")
		m_border(OrderHallMissionFrame.MissionTab.ZoneSupportMissionPage,402,32,"BOTTOM",0,-35,14,"MEDIUM")
		m_border(OrderHallMissionFrame.FollowerTab,60,54,"TOPRIGHT",-6,-6,14,"HIGH")
		m_fontify(AdventureMapQuestChoiceDialog.Details.Child.TitleHeader,"color")
		m_fontify(AdventureMapQuestChoiceDialog.RewardsHeader,"color")
		m_fontify(AdventureMapQuestChoiceDialog.Details.Child.DescriptionText,"white")
		m_fontify(AdventureMapQuestChoiceDialog.Details.Child.ObjectivesText,"white")
		m_fontify(AdventureMapQuestChoiceDialog.Details.Child.ObjectivesHeader,"color")
		local _,OrderHallMissionFrameMissionsMaterialFrameRessources = OrderHallMissionFrameMissions.MaterialFrame:GetRegions()
		m_fontify(OrderHallMissionFrameMissionsMaterialFrameRessources,"color")
		m_fontify(OrderHallMissionFrameMissions.MaterialFrame.Materials,"white")
		m_fontify(OrderHallMissionFrameMissionsTab1.Text,"white")
		m_fontify(OrderHallMissionFrameMissionsTab2.Text,"white")
		m_fontify(OrderHallMissionFrameMissions.EmptyListString,"white")
		--[[ OrderHall Missionlist Frame ]]--

		local currencyborder = OrderHallMissionFrameMissions.MaterialFrame:GetRegions()
		currencyborder:Hide()		
		local _,_,_,_,_,_,_,_,_,Background  = OrderHallMissionFrame:GetRegions()
		m_SetTexture(Background,"Interface\\FrameGeneral\\UI-Background-Rock.blp")
		OrderHallMissionFrameMissionsListScrollFrameScrollBarBG:Hide()
		OrderHallMissionFrameFollowersListScrollFrameScrollBarBG:Hide()
		for i = 1,18 do
			local hideit=select(i,OrderHallMissionFrameMissions:GetRegions()) 
			hideit:Hide()
		end
		for i = 1,6 do
			local hideit=select(i,OrderHallMissionFrameMissionsTab1:GetRegions()) 
			hideit:SetAlpha(0)
		end
		for i = 1,6 do
			local hideit=select(i,OrderHallMissionFrameMissionsTab2:GetRegions()) 
			hideit:SetAlpha(0)
		end	
		for x=1,8 do	
			local button=_G["OrderHallMissionFrameMissionsListScrollFrameButton"..x]		
			local border = _G["OrderHallMissionFrameMissionsListScrollFrameButton"..x]:GetRegions()
			m_SetTexture(border,"Interface\\Garrison\\o_mission.blp")
			border:SetVertexColor(unpack(miirgui.Color))
			border:SetWidth(1024)
			border:SetHeight(128)
			border:ClearAllPoints()
			border:SetPoint("CENTER",0,0.5)
			for i = 2,12 do
				local hideit=select(i,_G["OrderHallMissionFrameMissionsListScrollFrameButton"..x]:GetRegions())
				hideit:Hide()
			end
			for i = 21,26 do
				local hideit=select(i,_G["OrderHallMissionFrameMissionsListScrollFrameButton"..x]:GetRegions())
				hideit:Hide()
			end
			m_fontify(button.Level,"white")
			m_fontify(button.Title,"white")
			m_SetTexture(button.Highlight,"Interface\\Garrison\\o_mission.blp")
			button.Highlight:SetVertexColor(unpack(miirgui.Highlight))
			button.Highlight:SetWidth(1024)
			button.Highlight:SetHeight(128)
			button.Highlight:ClearAllPoints()
			button.Highlight:SetPoint("CENTER",0,0.5)	
			button.RareOverlay:SetAlpha(0)			
		end
		
		--[[ OrderHall Mission Details Frame]]--
		
		m_fontify(OrderHallMissionFrame.MissionTab.MissionPage.Follower1.Name,"white")
		m_fontify(OrderHallMissionFrame.MissionTab.MissionPage.Follower2.Name,"white")
		m_fontify(OrderHallMissionFrame.MissionTab.MissionPage.Follower3.Name,"white")
		for i=1,10 do
			local hideit=select(i,OrderHallMissionFrame.MissionTab.MissionPage.RewardsFrame:GetRegions())
			hideit:Hide()
		end
		
		OrderHallMissionFrame.MissionTab.MissionPage.RewardsFrame.Reward1.BG:Hide()
		OrderHallMissionFrame.MissionTab.MissionPage.RewardsFrame.Reward2.BG:Hide()
			
		local _,_,_,hideit = OrderHallMissionFrame.MissionTab.MissionPage.Stage:GetRegions()
		hideit:Hide()
		for i=1,12 do
			local hideit=select(i,OrderHallMissionFrame.MissionTab.MissionPage:GetRegions())
			hideit:Hide()
		end
		for i=13,16 do
			local hideit=select(i,OrderHallMissionFrame.MissionTab.MissionPage:GetRegions())
			hideit:Hide()
		end
		for i=18,20 do
			local hideit=select(i,OrderHallMissionFrame.MissionTab.MissionPage:GetRegions())
			hideit:Hide()
		end		

		OrderHallMissionFrame.MissionTab.MissionPage.Enemy1.PortraitFrame.Portrait:SetMask("")
		OrderHallMissionFrame.MissionTab.MissionPage.Enemy1.PortraitFrame.Portrait:SetTexCoord(0.10, 0.90, 0.1, 0.90)
		OrderHallMissionFrame.MissionTab.MissionPage.Enemy1.PortraitFrame.PortraitRing:Hide()
		m_border(OrderHallMissionFrame.MissionTab.MissionPage.Enemy1,54,54,"CENTER",0.5,0.5,14,"MEDIUM")
		OrderHallMissionFrame.MissionTab.MissionPage.Enemy2.PortraitFrame.Portrait:SetMask("")
		OrderHallMissionFrame.MissionTab.MissionPage.Enemy2.PortraitFrame.Portrait:SetTexCoord(0.10, 0.90, 0.1, 0.90)
		OrderHallMissionFrame.MissionTab.MissionPage.Enemy2.PortraitFrame.PortraitRing:Hide()
		m_border(OrderHallMissionFrame.MissionTab.MissionPage.Enemy2,54,54,"CENTER",0.5,0.5,14,"MEDIUM")	
		OrderHallMissionFrame.MissionTab.MissionPage.Enemy3.PortraitFrame.Portrait:SetMask("")
		OrderHallMissionFrame.MissionTab.MissionPage.Enemy3.PortraitFrame.Portrait:SetTexCoord(0.10, 0.90, 0.1, 0.90)
		OrderHallMissionFrame.MissionTab.MissionPage.Enemy3.PortraitFrame.PortraitRing:Hide()
		m_border(OrderHallMissionFrame.MissionTab.MissionPage.Enemy3,54,54,"CENTER",0.5,0.5,14,"MEDIUM")
		OrderHallMissionFrame.MissionTab.MissionPage.BuffsFrame.BuffsBG:Hide()
		OrderHallMissionFrame.MissionTab.MissionPage.Stage.Header:Hide()
		m_fontify(OrderHallMissionFrame.MissionTab.MissionPage.BuffsFrame.BuffsTitle,"white")
		m_fontify(OrderHallMissionFrame.MissionTab.MissionPage.EmptyString,"white")
		m_fontify(OrderHallMissionFrame.MissionTab.MissionPage.Stage.Level,"white")
		m_fontify(OrderHallMissionFrame.MissionTab.MissionPage.Stage.Title,"white")
		m_fontify(OrderHallMissionFrame.MissionTab.MissionPage.Stage.ItemLevel,"white")
		m_fontify(OrderHallMissionFrame.MissionTab.MissionPage.Stage.Location,"white")	
		m_fontify(OrderHallMissionFrame.MissionTab.MissionPage.Stage.MissionInfo.XP,"white")
		m_fontify(OrderHallMissionFrame.MissionTab.MissionPage.Stage.MissionInfo.MissionTime,"white")
		m_fontify(OrderHallMissionFrame.MissionTab.MissionPage.Enemy1.Name,"white")
		m_fontify(OrderHallMissionFrame.MissionTab.MissionPage.Enemy2.Name,"white")
		m_fontify(OrderHallMissionFrame.MissionTab.MissionPage.Enemy3.Name,"white")
		m_fontify(OrderHallMissionFrame.MissionTab.MissionPage.Stage.MissionDescription,"white")
		m_fontify(OrderHallMissionFrame.MissionTab.MissionPage.RewardsFrame.MissionXP,"white")
		m_fontify(OrderHallMissionFrame.MissionTab.MissionPage.CostFrame.CostLabel,"color")
		m_fontify(OrderHallMissionFrame.MissionTab.MissionPage.CostFrame.Cost,"white")
		for i=1,3 do
			local missionPage = OrderHallMissionFrame.MissionTab.MissionPage
			missionPage.Followers[i].DurabilityBackground:SetAlpha(0)
			m_SetTexture(missionPage.Followers[i].PortraitFrame.Empty,"Interface\\Garrison\\quality.blp")
			missionPage.Followers[i].PortraitFrame.Empty:SetHeight(128)
			missionPage.Followers[i].PortraitFrame.Empty:SetWidth(128)
			missionPage.Followers[i].PortraitFrame.Highlight:Hide()
			missionPage.Followers[i].PortraitFrame.LevelBorder:SetAlpha(0)
			missionPage.Followers[i].Class:SetAlpha(0)
			local Background =missionPage.Followers[i]:GetRegions()
			Background:Hide()
			missionPage.Followers[i].PortraitFrame.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
			m_SetTexture(missionPage.Followers[i].PortraitFrame.PortraitRingQuality,"Interface\\Garrison\\qual.blp")
			missionPage.Followers[i].PortraitFrame.PortraitRingQuality:SetSize(64,64)
			missionPage.Followers[i].PortraitFrame.PortraitRing:Hide()
			m_fontify(missionPage.Followers[i].PortraitFrame.Level,"white")
			missionPage.Followers[i].PortraitFrame.SpellTargetHighlight:ClearAllPoints()
			missionPage.Followers[i].PortraitFrame.SpellTargetHighlight:SetSize(80.5,84)
			missionPage.Followers[i].PortraitFrame.SpellTargetHighlight:SetPoint("CENTER",missionPage.Followers[i].PortraitFrame,-0.5,3)
			m_SetTexture(missionPage.Followers[i].PortraitFrame.SpellTargetHighlight,"Interface\\Buttons\\ButtonHilight-Round.blp")
		end
	
		--[[ OrderHall Followerlist Frame ]]--

		local currencyborder2 = OrderHallMissionFrameFollowers.MaterialFrame:GetRegions()
		currencyborder2:Hide()
		for i = 1,19 do
			local hideit=select(i,OrderHallMissionFrameFollowers:GetRegions()) 
			hideit:Hide()
		end
		for i = 1,19 do
			local hideit=select(i,OrderHallMissionFrame.FollowerTab:GetRegions()) 
			hideit:Hide()
		end	
		local _,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,newbackground  = OrderHallMissionFrameFollowers:GetRegions()
		m_SetTexture(newbackground,"Interface\\FrameGeneral\\UI-Background-Rock.blp")
		newbackground:ClearAllPoints()
		newbackground:SetSize(308,568)
		newbackground:SetPoint("CENTER",OrderHallMissionFrameFollowers,0,-16)	
		OrderHallMissionFrame.FollowerTab.PortraitFrame.PortraitRing:Hide()
		OrderHallMissionFrame.FollowerTab.PortraitFrame.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
		m_SetTexture(OrderHallMissionFrame.FollowerTab.PortraitFrame.PortraitRingQuality,"Interface\\Garrison\\qual.blp")
		OrderHallMissionFrame.FollowerTab.PortraitFrame.PortraitRingQuality:SetSize(64,64)
		OrderHallMissionFrame.FollowerTab.PortraitFrame.LevelBorder:SetAlpha(0)
		OrderHallMissionFrame.FollowerTab.XPBar.XPLeft:Hide()
		OrderHallMissionFrame.FollowerTab.XPBar.XPRight:Hide()
		OrderHallMissionFrame.FollowerTab.Class:SetTexCoord(0.15, 0.85, 0.15, 0.85)

		m_fontify(OrderHallMissionFrame.FollowerTab.PortraitFrame.Level,"white")
		m_fontify(OrderHallMissionFrame.FollowerTab.XPBar.Label,"white",10)
		local _,OrderHallMissionFrameFollowersMaterialFrameRessources = OrderHallMissionFrameFollowers.MaterialFrame:GetRegions()
		m_fontify(OrderHallMissionFrameFollowersMaterialFrameRessources,"color")
		m_fontify(OrderHallMissionFrameFollowers.MaterialFrame.Materials,"white")
		m_fontify(OrderHallMissionFrame.FollowerTab.NumFollowers,"white")
		m_fontify(OrderHallMissionFrame.FollowerTab.ClassSpec,"white")
		m_fontify(OrderHallMissionFrame.FollowerTab.Name,"white")	
		m_fontify(OrderHallMissionFrame.FollowerTab.XPLabel,"white")
		m_fontify(OrderHallMissionFrame.FollowerTab.XPText,"white")
		
		--[[ OrderHall Combat Ally Frame ]]--
		
		OrderHallMissionFrameMissions.CombatAllyUI.Background:Hide()
		
		for i=1,3 do
			local hideit=select(i,OrderHallMissionFrame.MissionTab.ZoneSupportMissionPage:GetRegions())
			m_SetTexture(hideit,"Interface\\FrameGeneral\\UI-Background-Rock.blp")
		end
		for i=4,9 do
			local hideit=select(i,OrderHallMissionFrame.MissionTab.ZoneSupportMissionPage:GetRegions())
			hideit:Hide()
		end	
		if miirguiDB.cbar == true then
			OrderHallCommandBar:Hide()
			hooksecurefunc(OrderHallCommandBar,"RefreshCategories",function(self)
				self:Hide()
			end)
		end
		OrderHallMissionFrame.MissionTab.ZoneSupportMissionPage.CombatAllyLabel.TextBackground:SetDesaturated(1)
		m_fontify(OrderHallMissionFrame.MissionTab.ZoneSupportMissionPage.CombatAllyLabel.Text,"color")
		m_SetTexture(OrderHallMissionFrame.MissionTab.ZoneSupportMissionPage.ButtonFrame,"Interface\\FrameGeneral\\UI-Background-Rock.blp")
		OrderHallMissionFrame.MissionTab.ZoneSupportMissionPage.ButtonFrame:SetSize(400,30)
		m_SetTexture(OrderHallMissionFrameMissions.CombatAllyUI.Available.AddFollowerButton.EmptyPortrait,"Interface\\Garrison\\quality.tga")
		OrderHallMissionFrameMissions.CombatAllyUI.Available.AddFollowerButton.EmptyPortrait:SetSize(128,128)
		OrderHallMissionFrameMissions.CombatAllyUI.Available.AddFollowerButton.EmptyPortrait:ClearAllPoints()
		OrderHallMissionFrameMissions.CombatAllyUI.Available.AddFollowerButton.EmptyPortrait:SetPoint("CENTER",OrderHallMissionFrameMissions.CombatAllyUI.Available.AddFollowerButton,0,-32.5)
		m_SetTexture(OrderHallMissionFrameMissions.CombatAllyUI.Available.AddFollowerButton.PortraitHighlight,"Interface\\Buttons\\ButtonHilight-Square.blp")
		OrderHallMissionFrameMissions.CombatAllyUI.Available.AddFollowerButton.PortraitHighlight:SetSize(48,48)
		OrderHallMissionFrameMissions.CombatAllyUI.Available.AddFollowerButton.PortraitHighlight:SetPoint("CENTER",OrderHallMissionFrameMissions.CombatAllyUI.Available.AddFollowerButton,-0.5,6)
		OrderHallMissionFrame.MissionTab.ZoneSupportMissionPage.Follower1:ClearAllPoints()
		OrderHallMissionFrame.MissionTab.ZoneSupportMissionPage.Follower1:SetPoint("LEFT",0,0)
		m_SetTexture(OrderHallMissionFrame.MissionTab.ZoneSupportMissionPage.Follower1.PortraitFrame.Empty,"Interface\\Garrison\\quality.tga")			
		OrderHallMissionFrame.MissionTab.ZoneSupportMissionPage.Follower1.PortraitFrame.Empty:SetSize(128,128)
		OrderHallMissionFrame.MissionTab.ZoneSupportMissionPage.Follower1.PortraitFrame.Highlight:Hide()				
		OrderHallMissionFrame.MissionTab.ZoneSupportMissionPage.Follower1.PortraitFrame.LevelBorder:SetAlpha(0)
		OrderHallMissionFrame.MissionTab.ZoneSupportMissionPage.Follower1.Class:SetAlpha(0)
		local OrderHallMissionFrameMissionTabZoneSupportMissionPageFollower1Background = OrderHallMissionFrame.MissionTab.ZoneSupportMissionPage.Follower1:GetRegions()
		OrderHallMissionFrameMissionTabZoneSupportMissionPageFollower1Background:Hide()				
		OrderHallMissionFrame.MissionTab.ZoneSupportMissionPage.Follower1.PortraitFrame.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
		m_SetTexture(OrderHallMissionFrame.MissionTab.ZoneSupportMissionPage.Follower1.PortraitFrame.PortraitRingQuality,"Interface\\Garrison\\qual.blp")
		OrderHallMissionFrame.MissionTab.ZoneSupportMissionPage.Follower1.PortraitFrame.PortraitRingQuality:SetSize(64,64)
		OrderHallMissionFrame.MissionTab.ZoneSupportMissionPage.Follower1.PortraitFrame.PortraitRing:Hide()
		OrderHallMissionFrameMissions.CombatAllyUI.InProgress.PortraitFrame:SetPoint("LEFT",20,0.5)
		OrderHallMissionFrameMissions.CombatAllyUI.InProgress.PortraitFrame.LevelBorder:SetAlpha(0)		
		OrderHallMissionFrameMissions.CombatAllyUI.InProgress.PortraitFrame.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
		m_SetTexture(OrderHallMissionFrameMissions.CombatAllyUI.InProgress.PortraitFrame.PortraitRingQuality,"Interface\\Garrison\\qual.blp")
		OrderHallMissionFrameMissions.CombatAllyUI.InProgress.PortraitFrame.PortraitRingQuality:SetSize(64,64)
		OrderHallMissionFrameMissions.CombatAllyUI.InProgress.PortraitFrame.PortraitRing:Hide()
		m_fontify(OrderHallMissionFrame.MissionTab.ZoneSupportMissionPage.Follower1.PortraitFrame.Level,"white")
		m_fontify(OrderHallMissionFrame.MissionTab.ZoneSupportMissionPage.CostFrame.CostLabel,"white")
		m_fontify(OrderHallMissionFrame.MissionTab.ZoneSupportMissionPage.CombatAllyDescriptionLabel,"white")
		m_fontify(OrderHallMissionFrameMissions.CombatAllyUI.Available.CombatAllyLabel,"color")
		m_fontify(OrderHallMissionFrameMissions.CombatAllyUI.Available.Description,"white")
		m_fontify(OrderHallMissionFrameMissions.CombatAllyUI.InProgress.Name,"color")
		m_fontify(OrderHallMissionFrameMissions.CombatAllyUI.InProgress.Description,"white")
		m_fontify(OrderHallMissionFrameMissions.CombatAllyUI.InProgress.ZoneSupportName,"white")
		
		--[[ OrderHall Mission Complete Frame ]]--
		
		local bg = OrderHallMissionFrame.MissionComplete:GetRegions()
		bg:ClearAllPoints()
		bg:SetPoint("CENTER",OrderHallMissionFrame.MissionComplete,0,0)
		m_SetTexture(bg,"Interface\\FrameGeneral\\UI-Background-Rock.blp")
		bg:SetSize(552,592)
		OrderHallMissionFrame.MissionComplete.BonusRewards.Saturated:ClearAllPoints()
		OrderHallMissionFrame.MissionComplete.NextMissionButton:ClearAllPoints()
		OrderHallMissionFrame.MissionComplete.NextMissionButton:SetPoint("CENTER",0,-276)
		
		for i=2,12 do
			local hideit=select(i,OrderHallMissionFrame.MissionComplete:GetRegions())
			hideit:Hide()
		end
		for i=11,13 do
			local hideit=select(i,OrderHallMissionFrame.MissionComplete.Stage.MissionInfo:GetRegions())
			hideit:Hide()
		end
		for i =1,10 do
			local hideit=select(i,OrderHallMissionFrame.MissionComplete.BonusRewards:GetRegions())
			hideit:SetAlpha(0)
		end
		local _,_,_,hideit = OrderHallMissionFrame.MissionComplete.Stage:GetRegions()
		hideit:Hide()
		
		for i=1,5 do
			local hideit=select(i,OrderHallMissionFrame.MissionComplete.Stage.MissionInfo:GetRegions())
			hideit:Hide()
		end
		m_fontify(OrderHallMissionFrame.MissionComplete.Stage.MissionInfo.Level,"white")
		m_fontify(OrderHallMissionFrame.MissionComplete.Stage.MissionInfo.ItemLevel,"white")
		m_fontify(OrderHallMissionFrame.MissionComplete.Stage.MissionInfo.Title,"color")
		m_fontify(OrderHallMissionFrame.MissionComplete.Stage.MissionInfo.Location,"white")
		local _,_,_,_,_,_,_,_,_,_,rewards = OrderHallMissionFrame.MissionComplete.BonusRewards:GetRegions()
		m_fontify(rewards,"white")
	
	
		m_cursorfix(OrderHallMissionFrameFollowers.SearchBox)
	
	end
	
local f= CreateFrame("FRAME")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
	local f2= CreateFrame("FRAME")
	f2:RegisterEvent("ADDON_LOADED")
	f2:SetScript("OnEvent", function(_,event, arg1)
		if event == "ADDON_LOADED" and arg1 == "Blizzard_OrderHallUI" then
			skin_Blizzard_OrderHallUI()
			f2:UnregisterEvent("ADDON_LOADED")
		end	
	end)			
	if IsAddOnLoaded("Blizzard_OrderHallUI") then
		skin_Blizzard_OrderHallUI()
		f2:UnregisterEvent("ADDON_LOADED")
	end	
end)