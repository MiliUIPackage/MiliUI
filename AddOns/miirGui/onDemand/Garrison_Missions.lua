local function skin_Blizzard_GarrisonUI()
	
		--[[ Garrison Main Frame]]--
	
		GarrisonMissionFrameHelpBoxBg:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 1)
		GarrisonMissionFrameHelpBoxBg:SetColorTexture(0.078,0.078,0.078,1)
		m_border(GarrisonMissionFrameHelpBox,226,62,"CENTER",0,0,14,"FULLSCREEN_DIALOG")
		m_border_GarrisonMissionFrameHelpBox:SetPoint("TOPLEFT","GarrisonMissionFrameHelpBox",-3,3)
		m_border_GarrisonMissionFrameHelpBox:SetPoint("BOTTOMRIGHT","GarrisonMissionFrameHelpBox",3,-3)	
		m_fontify(GarrisonMissionFrameHelpBox.BigText,"white")	
		local _,GarrisonMissionFrameMissionsMaterialFrameRessources = GarrisonMissionFrameMissions.MaterialFrame:GetRegions()
		m_fontify(GarrisonMissionFrameMissionsMaterialFrameRessources,"color")
		m_fontify(GarrisonMissionFrameMissions.MaterialFrame.Materials,"white")
		m_border(GarrisonMissionFrameMissionsListScrollFrame,900,570,"CENTER",0,-1.5,14,"MEDIUM")
		m_border(GarrisonMissionFrameFollowers,310,570,"CENTER",0,-16,12,"MEDIUM")
		m_border(GarrisonMissionFrame.FollowerTab,580,570,"CENTER",0.5,-1,12,"MEDIUM")
		m_border(GarrisonMissionFrameMissions.MaterialFrame,300,26,"CENTER",0.5,0,12,"MEDIUM")
		m_border(GarrisonMissionFrameFollowers.MaterialFrame,300,26,"CENTER",0,0,12,"MEDIUM")
		m_border(GarrisonMissionFrame.MissionComplete,550,290,"CENTER",0,148,14,"HIGH")
		m_border(GarrisonMissionFrame.MissionComplete,560,600,"CENTER",0,0,14,"HIGH")
		m_border(GarrisonMissionFrame.MissionTab.MissionPage.Stage,554,238,"CENTER",0,0,14,"MEDIUM")
		m_border(GarrisonMissionFrameMissionsTab2,180,24,"CENTER",0,0,14,"MEDIUM")
		m_border(GarrisonMissionFrameMissionsTab1,180,24,"CENTER",0,0,14,"MEDIUM")
		m_border(GarrisonMissionFrame.MissionTab.MissionPage.RewardsFrame.Reward1,100,46,"CENTER",20,0,14,"MEDIUM")
		m_border(GarrisonMissionFrame.MissionTab.MissionPage.RewardsFrame.Reward1,46,46,"LEFT",-1,0,14,"MEDIUM")
		m_border(GarrisonMissionFrame.MissionTab.MissionPage.RewardsFrame.Reward2,100,46,"CENTER",20,0,14,"MEDIUM")
		m_border(GarrisonMissionFrame.MissionTab.MissionPage.RewardsFrame.Reward2,46,46,"LEFT",-1,0,14,"MEDIUM")
		m_border(GarrisonMissionFrame.FollowerTab.ItemArmor,140,44,"CENTER",0,0,14,"MEDIUM")
		m_border(GarrisonMissionFrame.FollowerTab.ItemArmor,44,44,"LEFT",-1,0,14,"MEDIUM")
		m_border(GarrisonMissionFrame.FollowerTab.ItemWeapon,140,44,"CENTER",0,0,14,"MEDIUM")
		m_border(GarrisonMissionFrame.FollowerTab.ItemWeapon,44,44,"LEFT",-1,0,14,"MEDIUM")
		m_border(GarrisonMissionFrame.FollowerTab.XPBar,504,16,"CENTER",0,0,12,"MEDIUM")	
		m_border(GarrisonMissionFrame.MissionComplete.Stage.FollowersFrame.Follower2,124,49,"CENTER",24,4,12,"HIGH")
		m_border(GarrisonMissionFrame.MissionComplete.Stage.FollowersFrame.Follower3,124,49,"CENTER",24,4,12,"HIGH")
		m_border(GarrisonMissionFrame.MissionComplete.Stage.FollowersFrame.Follower1,124,49,"CENTER",24,4,12,"HIGH")
		
		m_cursorfix(GarrisonMissionFrameFollowers.SearchBox)
		
		local _,_,_,_,_,_,_,_,_,Background = GarrisonMissionFrame:GetRegions()
		m_SetTexture(Background,"Interface\\FrameGeneral\\UI-Background-Rock.blp")
		GarrisonMissionFrameMissionsListScrollFrameScrollBarBG:Hide()
		GarrisonMissionFrameFollowersListScrollFrameScrollBarBG:Hide()
		GarrisonMissionFrameFollowersListScrollFrameScrollBarBG:Hide()
		GarrisonMissionFrame.GarrCorners.TopLeftGarrCorner:Hide()
		GarrisonMissionFrame.GarrCorners.TopRightGarrCorner:Hide()
		GarrisonMissionFrame.GarrCorners.BottomLeftGarrCorner:Hide()
		GarrisonMissionFrame.GarrCorners.BottomRightGarrCorner:Hide()
		local currencyborder = GarrisonMissionFrameMissions.MaterialFrame:GetRegions()
		currencyborder:Hide()
		local currencyborder2= GarrisonMissionFrameFollowers.MaterialFrame:GetRegions()
		currencyborder2:Hide()
		for i = 11,14 do
			local hideit=select(i,GarrisonMissionFrame:GetRegions())
			hideit:Hide()
		end	
		for i = 1,18 do
			local  hideit=select(i,GarrisonMissionFrameMissions:GetRegions()) 
			hideit:Hide()
		end
		for i = 1,6 do
			local hideit=select(i,GarrisonMissionFrameMissionsTab1:GetRegions()) 
			hideit:SetAlpha(0)
		end
		for i = 1,6 do
			local hideit=select(i,GarrisonMissionFrameMissionsTab2:GetRegions()) 
			hideit:SetAlpha(0)
		end	
		m_fontify(GarrisonMissionFrameMissionsTab1Text,"white")
		m_fontify(GarrisonMissionFrameMissionsTab2Text,"white")
		for x=1,8 do	
			local button=_G["GarrisonMissionFrameMissionsListScrollFrameButton"..x]	
			local border =button:GetRegions()
			m_SetTexture(border,"Interface\\Garrison\\mission.blp")
			border:SetVertexColor(unpack(miirgui.Color))
			border:SetWidth(1024)
			border:SetHeight(128)
			border:ClearAllPoints()
			border:SetPoint("CENTER")
			for i = 2,12 do
				local hideit=select(i,_G["GarrisonMissionFrameMissionsListScrollFrameButton"..x]:GetRegions())
				hideit:Hide()
			end
			for i = 21,26 do
				local hideit=select(i,_G["GarrisonMissionFrameMissionsListScrollFrameButton"..x]:GetRegions())
				hideit:Hide()
			end
			m_fontify(button.Level,"white")
			m_fontify(button.Title,"white")
			m_SetTexture(button.Highlight,"Interface\\Garrison\\mission.blp")
			button.Highlight:SetVertexColor(unpack(miirgui.Highlight))
			button.Highlight:SetWidth(1024)
			button.Highlight:SetHeight(128)
			button.Highlight:ClearAllPoints()
			button.Highlight:SetPoint("CENTER")
			button.RareOverlay:SetAlpha(0)
		end
		
		--[[ Garrison Mission Details Frame	]]--
		
		m_fontify(GarrisonMissionFrame.MissionTab.MissionPage.Follower1.Name,"white")
		m_fontify(GarrisonMissionFrame.MissionTab.MissionPage.Follower2.Name,"white")
		m_fontify(GarrisonMissionFrame.MissionTab.MissionPage.Follower3.Name,"white")
		
		local _,_,_,hideit = GarrisonMissionFrame.MissionTab.MissionPage.Stage:GetRegions()
		hideit:Hide()
		for i=1,10 do
			local hideit=select(i,GarrisonMissionFrame.MissionTab.MissionPage.RewardsFrame:GetRegions())
			hideit:Hide()
		end
		for i=1,12 do
			local hideit=select(i,GarrisonMissionFrame.MissionTab.MissionPage:GetRegions())
			hideit:Hide()
		end
		for i=13,16 do
			local hideit=select(i,GarrisonMissionFrame.MissionTab.MissionPage:GetRegions())
			hideit:Hide()
		end
		for i=18,20 do
			local hideit=select(i,GarrisonMissionFrame.MissionTab.MissionPage:GetRegions())
			hideit:Hide()
		end
		GarrisonMissionFrame.MissionTab.MissionPage.Enemy1.PortraitFrame.Elite:SetAlpha(0)
		GarrisonMissionFrame.MissionTab.MissionPage.Enemy1.PortraitFrame.Portrait:SetMask("")
		GarrisonMissionFrame.MissionTab.MissionPage.Enemy1.PortraitFrame.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
		GarrisonMissionFrame.MissionTab.MissionPage.Enemy1.PortraitFrame.PortraitRing:Hide()
		m_border(GarrisonMissionFrame.MissionTab.MissionPage.Enemy1,54,54,"CENTER",0.5,0.5,14,"MEDIUM")
		
		GarrisonMissionFrame.MissionTab.MissionPage.Enemy2.PortraitFrame.Elite:SetAlpha(0)
		GarrisonMissionFrame.MissionTab.MissionPage.Enemy2.PortraitFrame.Portrait:SetMask("")
		GarrisonMissionFrame.MissionTab.MissionPage.Enemy2.PortraitFrame.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
		GarrisonMissionFrame.MissionTab.MissionPage.Enemy2.PortraitFrame.PortraitRing:Hide()
		m_border(GarrisonMissionFrame.MissionTab.MissionPage.Enemy2,54,54,"CENTER",0.5,0.5,14,"MEDIUM")	
		
		GarrisonMissionFrame.MissionTab.MissionPage.Enemy3.PortraitFrame.Elite:SetAlpha(0)
		GarrisonMissionFrame.MissionTab.MissionPage.Enemy3.PortraitFrame.Portrait:SetMask("")
		GarrisonMissionFrame.MissionTab.MissionPage.Enemy3.PortraitFrame.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
		GarrisonMissionFrame.MissionTab.MissionPage.Enemy3.PortraitFrame.PortraitRing:Hide()
		m_border(GarrisonMissionFrame.MissionTab.MissionPage.Enemy3,54,54,"CENTER",0.5,0.5,14,"MEDIUM")
		
		GarrisonMissionFrame.MissionTab.MissionPage.RewardsFrame.Reward1.BG:Hide()
		GarrisonMissionFrame.MissionTab.MissionPage.RewardsFrame.Reward2.BG:Hide()
		GarrisonMissionFrame.MissionTab.MissionPage.BuffsFrame.BuffsBG:Hide()
		GarrisonMissionFrame.MissionTab.MissionPage.Stage.Header:Hide()
		m_fontify(GarrisonMissionFrame.MissionTab.MissionPage.BuffsFrame.BuffsTitle,"white")
		m_fontify(GarrisonMissionFrame.MissionTab.MissionPage.EmptyString,"white")
		m_fontify(GarrisonMissionFrame.MissionTab.MissionPage.Stage.Level,"white")
		m_fontify(GarrisonMissionFrame.MissionTab.MissionPage.Stage.Title,"white")
		m_fontify(GarrisonMissionFrame.MissionTab.MissionPage.Stage.ItemLevel,"white")
		m_fontify(GarrisonMissionFrame.MissionTab.MissionPage.Stage.Location,"white")	
		m_fontify(GarrisonMissionFrame.MissionTab.MissionPage.Stage.MissionInfo.XP,"white")
		m_fontify(GarrisonMissionFrame.MissionTab.MissionPage.Stage.MissionInfo.MissionTime,"white")	
		m_fontify(GarrisonMissionFrame.MissionTab.MissionPage.Stage.MissionInfo.MissionEnv,"white")
		m_fontify(GarrisonMissionFrame.MissionTab.MissionPage.Enemy1.Name,"white")
		m_fontify(GarrisonMissionFrame.MissionTab.MissionPage.Enemy2.Name,"white")
		m_fontify(GarrisonMissionFrame.MissionTab.MissionPage.Enemy3.Name,"white")
		m_fontify(GarrisonMissionFrame.MissionTab.MissionPage.Stage.MissionDescription,"white")
		m_fontify(GarrisonMissionFrame.MissionTab.MissionPage.RewardsFrame.MissionXP,"white")
		m_fontify(GarrisonMissionFrame.MissionTab.MissionPage.CostFrame.CostLabel,"color")
		m_fontify(GarrisonMissionFrame.MissionTab.MissionPage.CostFrame.Cost,"white")
		for i=1,3 do
			local missionPage = GarrisonMissionFrame.MissionTab.MissionPage
			m_SetTexture(missionPage.Followers[i].PortraitFrame.Empty,"Interface\\Garrison\\quality.blp")
			missionPage.Followers[i].PortraitFrame.Empty:SetHeight(128)
			missionPage.Followers[i].PortraitFrame.Empty:SetWidth(128)
			missionPage.Followers[i].PortraitFrame.Highlight:Hide()
			missionPage.Followers[i].PortraitFrame.LevelBorder:SetAlpha(0)
			missionPage.Followers[i].Class:SetAlpha(0)
			local Background = missionPage.Followers[i]:GetRegions()
			Background:Hide()
			missionPage.Followers[i].PortraitFrame.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
			m_SetTexture(missionPage.Followers[i].PortraitFrame.PortraitRingQuality,"Interface\\Garrison\\qual.blp")
			missionPage.Followers[i].PortraitFrame.PortraitRingQuality:SetSize(64,64)
			missionPage.Followers[i].PortraitFrame.PortraitRing:Hide()
			m_fontify(missionPage.Followers[i].PortraitFrame.Level,"white")
		end
		
		--[[ Garrison Followerlist Frame]]--
		local _,GarrisonMissionFrameFollowersMaterialFrameRessources = GarrisonMissionFrameFollowers.MaterialFrame:GetRegions()
		m_fontify(GarrisonMissionFrameFollowersMaterialFrameRessources,"color")
		m_fontify(GarrisonMissionFrameFollowers.MaterialFrame.Materials,"white")
		for i = 1,20 do
			local hideit=select(i,GarrisonMissionFrameFollowers:GetRegions()) 
			hideit:Hide()
		end
		for i = 1,19 do
			local hideit=select(i,GarrisonMissionFrame.FollowerTab:GetRegions()) 
			hideit:Hide()
		end
		GarrisonMissionFrame.FollowerTab.PortraitFrame.PortraitRing:Hide()
		GarrisonMissionFrame.FollowerTab.PortraitFrame.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
		m_SetTexture(GarrisonMissionFrame.FollowerTab.PortraitFrame.PortraitRingQuality,"Interface\\Garrison\\qual.blp")
		GarrisonMissionFrame.FollowerTab.PortraitFrame.PortraitRingQuality:SetSize(64,64)
		GarrisonMissionFrame.FollowerTab.PortraitFrame.LevelBorder:SetAlpha(0)
		local _,xpleft,xpright,xpmiddle = GarrisonMissionFrame.FollowerTab.XPBar:GetRegions()
		xpleft:Hide()
		xpright:Hide()
		xpmiddle:Hide()
		GarrisonMissionFrame.FollowerTab.ItemWeapon.Border:Hide()
		GarrisonMissionFrame.FollowerTab.ItemArmor.Border:Hide()
		m_fontify(GarrisonMissionFrame.FollowerTab.PortraitFrame.Level,"white")
		m_fontify(GarrisonMissionFrame.FollowerTab.XPBar.Label,"white",10)
		m_fontify(GarrisonMissionFrame.FollowerTab.NumFollowers,"white")

		--[[ Garrison Mission Complete Frame ]]--
	
		local bg = GarrisonMissionFrame.MissionComplete:GetRegions()
		bg:ClearAllPoints()
		bg:SetPoint("CENTER",GarrisonMissionFrame.MissionComplete,0,0)
		m_SetTexture(bg,"Interface\\FrameGeneral\\UI-Background-Rock.blp")
		bg:SetSize(552,592)
		GarrisonMissionFrame.MissionComplete.BonusRewards.Saturated:ClearAllPoints()
		GarrisonMissionFrame.MissionComplete.NextMissionButton:ClearAllPoints()
		GarrisonMissionFrame.MissionComplete.NextMissionButton:SetPoint("CENTER",0,-276)
		
		for i=1,10 do
			local hideit=select(i,GarrisonMissionFrame.MissionTab.MissionPage.RewardsFrame:GetRegions())
			hideit:Hide()
		end
		local hideit = GarrisonMissionFrame.MissionTab.MissionPage.RewardsFrame.Reward1:GetRegions()
		hideit:Hide()
		local hideit=select(1,GarrisonMissionFrame.MissionTab.MissionPage.RewardsFrame.Reward2:GetRegions())
		hideit:Hide()
		for i=2,12 do
			local hideit=select(i,GarrisonMissionFrame.MissionComplete:GetRegions())
			hideit:Hide()
		end
		for i=11,13 do
			local hideit=select(i,GarrisonMissionFrame.MissionComplete.Stage.MissionInfo:GetRegions())
			hideit:Hide()
		end
		for i =1,10 do
			local hideit=select(i,GarrisonMissionFrame.MissionComplete.BonusRewards:GetRegions())
			hideit:SetAlpha(0)
		end
		local _,_,_,hideit = GarrisonMissionFrame.MissionComplete.Stage:GetRegions()
		hideit:Hide()
		
		for i=1,5 do
			local hideit=select(i,GarrisonMissionFrame.MissionComplete.Stage.MissionInfo:GetRegions())
			hideit:Hide()
		end
		m_fontify(GarrisonMissionFrame.MissionComplete.Stage.MissionInfo.Level,"white")
		m_fontify(GarrisonMissionFrame.MissionComplete.Stage.MissionInfo.ItemLevel,"white")
		m_fontify(GarrisonMissionFrame.MissionComplete.Stage.MissionInfo.Title,"color")
		m_fontify(GarrisonMissionFrame.MissionComplete.Stage.MissionInfo.Location,"white")
		local _,_,_,_,_,_,_,_,_,_,rewards = GarrisonMissionFrame.MissionComplete.BonusRewards:GetRegions()
		m_fontify(rewards,"white")
		
	end
	

local f= CreateFrame("FRAME")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
	local f2= CreateFrame("FRAME")
	f2:RegisterEvent("ADDON_LOADED")
	f2:SetScript("OnEvent", function(_,event, arg1)
		if event == "ADDON_LOADED" and arg1 == "Blizzard_GarrisonUI" then
			skin_Blizzard_GarrisonUI()
			f2:UnregisterEvent("ADDON_LOADED")
		end	
	end)			
	if IsAddOnLoaded("Blizzard_GarrisonUI") then
		skin_Blizzard_GarrisonUI()
		f2:UnregisterEvent("ADDON_LOADED")
	end	
end)
		
-- Better Garrison Minimap Button

GarrisonLandingPageMinimapButton:SetScript("OnClick", function(_,button)
	if button == "RightButton" then
		if (GarrisonLandingPage and GarrisonLandingPage:IsShown()) then
			HideUIPanel(GarrisonLandingPage)
			ShowGarrisonLandingPage(2)
		else
			ShowGarrisonLandingPage(2)
		end
	else
		GarrisonLandingPage_Toggle();
	end
end)

GarrisonLandingPageMinimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")