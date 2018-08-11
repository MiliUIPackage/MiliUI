local function skin_AdventureMap()

	--[[ BFA Main Frame]]--
	local _,_,_,_,closebutton=BFAMissionFrame.CloseButton:GetRegions()
	closebutton:Hide()
	local _,BFAMissionFrameMissionsMaterialFrameRessources = BFAMissionFrameMissions.MaterialFrame:GetRegions()
	m_fontify(BFAMissionFrameMissionsMaterialFrameRessources,"color")
	m_fontify(BFAMissionFrameMissions.MaterialFrame.Materials,"white")
	m_border(BFAMissionFrameMissionsListScrollFrame,900,570,"CENTER",0,-1.5,14,"MEDIUM")
	m_border(BFAMissionFrameFollowers,310,570,"CENTER",0,-16,12,"MEDIUM")
	m_border(BFAMissionFrame.FollowerTab,580,570,"CENTER",0.5,-1,12,"MEDIUM")
	m_border(BFAMissionFrameMissions.MaterialFrame,300,26,"CENTER",0.5,0,12,"MEDIUM")
	m_border(BFAMissionFrameFollowers.MaterialFrame,300,26,"CENTER",0,0,12,"MEDIUM")
	m_border(BFAMissionFrame.MissionComplete,550,290,"CENTER",0,148,14,"HIGH")
	m_border(BFAMissionFrame.MissionComplete,560,600,"CENTER",0,0,14,"HIGH")
	m_border(BFAMissionFrame.MissionTab.MissionPage.Stage,554,238,"CENTER",0,0,14,"MEDIUM")
	m_border(BFAMissionFrameMissionsTab2,180,24,"CENTER",0,0,14,"MEDIUM")
	m_border(BFAMissionFrameMissionsTab1,180,24,"CENTER",0,0,14,"MEDIUM")
	m_border(BFAMissionFrame.MissionTab.MissionPage.RewardsFrame.Reward1,100,46,"CENTER",20,0,14,"MEDIUM")
	m_border(BFAMissionFrame.MissionTab.MissionPage.RewardsFrame.Reward1,46,46,"LEFT",-1,0,14,"MEDIUM")
	m_border(BFAMissionFrame.MissionTab.MissionPage.RewardsFrame.Reward2,100,46,"CENTER",20,0,14,"MEDIUM")
	m_border(BFAMissionFrame.MissionTab.MissionPage.RewardsFrame.Reward2,46,46,"LEFT",-1,0,14,"MEDIUM")
	m_border(BFAMissionFrame.FollowerTab.ItemArmor,140,44,"CENTER",0,0,14,"MEDIUM")
	m_border(BFAMissionFrame.FollowerTab.ItemArmor,44,44,"LEFT",-1,0,14,"MEDIUM")
	m_border(BFAMissionFrame.FollowerTab.ItemWeapon,140,44,"CENTER",0,0,14,"MEDIUM")
	m_border(BFAMissionFrame.FollowerTab.ItemWeapon,44,44,"LEFT",-1,0,14,"MEDIUM")
	m_border(BFAMissionFrame.FollowerTab.XPBar,504,16,"CENTER",0,0,12,"TOOLTIP")
	m_border(BFAMissionFrame.MissionComplete.Stage.FollowersFrame.Follower2,124,49,"CENTER",24,4,12,"HIGH")
	m_border(BFAMissionFrame.MissionComplete.Stage.FollowersFrame.Follower3,124,49,"CENTER",24,4,12,"HIGH")
	m_border(BFAMissionFrame.MissionComplete.Stage.FollowersFrame.Follower1,124,49,"CENTER",24,4,12,"HIGH")

	m_fontify(AdventureMapQuestChoiceDialog.Details.Child.TitleHeader,"color")
	m_fontify(AdventureMapQuestChoiceDialog.Details.Child.ObjectivesHeader,"color")
	AdventureMapQuestChoiceDialog.Details.ScrollBar.Background:Hide()
	
	--Dirty Hack for cba to do bg
	local f = CreateFrame("Frame",BLAAAA,BFAMissionFrame)
	f:SetFrameStrata("BACKGROUND")
	f:SetSize(962,662)
	local t = f:CreateTexture(nil,"BACKGROUND")
	t:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock.blp")
	t:SetAllPoints(f)
	f.texture = t
	f:SetPoint("CENTER",0,0)
	f:Show()
		
	m_border(BFAMissionFrame,970,668,"CENTER",0,0,14,"HIGH")
	m_cursorfix(BFAMissionFrameFollowers.SearchBox)
	local _,_,_,title=BFAMissionFrame.TitleScroll:GetRegions()
	m_fontify(title,"white")
	BFAMissionFrame.Top:Hide()
	BFAMissionFrame.TitleScroll.ScrollMiddle:Hide()
	BFAMissionFrame.TitleScroll.ScrollLeft:Hide()
	BFAMissionFrame.TitleScroll.ScrollRight:Hide()
	m_SetTexture(BFAMissionFrame.BackgroundTile,"Interface\\FrameGeneral\\UI-Background-Rock.blp")
	BFAMissionFrameMissionsListScrollFrameScrollBarBG:Hide()
	BFAMissionFrameFollowersListScrollFrameScrollBarBG:Hide()
	BFAMissionFrameFollowersListScrollFrameScrollBarBG:Hide()
	BFAMissionFrame.GarrCorners.TopLeftGarrCorner:Hide()
	BFAMissionFrame.GarrCorners.TopRightGarrCorner:Hide()
	BFAMissionFrame.GarrCorners.BottomLeftGarrCorner:Hide()
	BFAMissionFrame.GarrCorners.BottomRightGarrCorner:Hide()
	local currencyborder = BFAMissionFrameMissions.MaterialFrame:GetRegions()
	currencyborder:Hide()
	local currencyborder2= BFAMissionFrameFollowers.MaterialFrame:GetRegions()
	currencyborder2:Hide()
	for i = 11,14 do
		local hideit=select(i,BFAMissionFrame:GetRegions())
		hideit:Hide()
	end
	for i = 1,18 do
		local  hideit=select(i,BFAMissionFrameMissions:GetRegions())
		hideit:Hide()
	end
	for i = 1,6 do
		local hideit=select(i,BFAMissionFrameMissionsTab1:GetRegions())
		hideit:SetAlpha(0)
	end
	for i = 1,6 do
		local hideit=select(i,BFAMissionFrameMissionsTab2:GetRegions())
		hideit:SetAlpha(0)
	end
	m_fontify(BFAMissionFrameMissionsTab1Text,"white")
	m_fontify(BFAMissionFrameMissionsTab2Text,"white")
	for x=1,8 do
		local button=_G["BFAMissionFrameMissionsListScrollFrameButton"..x]
		local border =button:GetRegions()
		m_SetTexture(border,"Interface\\Garrison\\mission.blp")
		border:SetVertexColor(miirguiDB.color.r,miirguiDB.color.g,miirguiDB.color.b,1)
		border:SetWidth(1024)
		border:SetHeight(128)
		border:ClearAllPoints()
		border:SetPoint("CENTER")
		for i = 2,12 do
			local hideit=select(i,_G["BFAMissionFrameMissionsListScrollFrameButton"..x]:GetRegions())
			hideit:Hide()
		end
		for i = 21,26 do
			local hideit=select(i,_G["BFAMissionFrameMissionsListScrollFrameButton"..x]:GetRegions())
			hideit:Hide()
		end
		m_fontify(button.Level,"white")
		m_fontify(button.Title,"white")
		m_SetTexture(button.Highlight,"Interface\\Garrison\\mission.blp")
		button.Highlight:SetVertexColor(miirguiDB.color.hr,miirguiDB.color.hg,miirguiDB.color.hb,1)
		button.Highlight:SetWidth(1024)
		button.Highlight:SetHeight(128)
		button.Highlight:ClearAllPoints()
		button.Highlight:SetPoint("CENTER")
		button.RareOverlay:SetAlpha(0)
	end

	--[[ BFA Mission Details Frame	]]--

	m_fontify(BFAMissionFrame.MissionTab.MissionPage.Follower1.Name,"white")
	m_fontify(BFAMissionFrame.MissionTab.MissionPage.Follower2.Name,"white")
	m_fontify(BFAMissionFrame.MissionTab.MissionPage.Follower3.Name,"white")

	local _,_,_,hideit = BFAMissionFrame.MissionTab.MissionPage.Stage:GetRegions()
	hideit:Hide()
	for i=1,10 do
		local hideit=select(i,BFAMissionFrame.MissionTab.MissionPage.RewardsFrame:GetRegions())
		hideit:Hide()
	end
	for i=1,12 do
		local hideit=select(i,BFAMissionFrame.MissionTab.MissionPage:GetRegions())
		hideit:Hide()
	end
	for i=13,16 do
		local hideit=select(i,BFAMissionFrame.MissionTab.MissionPage:GetRegions())
		hideit:Hide()
	end
	for i=18,20 do
		local hideit=select(i,BFAMissionFrame.MissionTab.MissionPage:GetRegions())
		hideit:Hide()
	end
	BFAMissionFrame.MissionTab.MissionPage.Enemy1.PortraitFrame.Elite:SetAlpha(0)
	BFAMissionFrame.MissionTab.MissionPage.Enemy1.PortraitFrame.Portrait:SetMask("")
	BFAMissionFrame.MissionTab.MissionPage.Enemy1.PortraitFrame.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
	BFAMissionFrame.MissionTab.MissionPage.Enemy1.PortraitFrame.PortraitRing:Hide()
	m_border(BFAMissionFrame.MissionTab.MissionPage.Enemy1,54,54,"CENTER",0.5,0.5,14,"MEDIUM")

	BFAMissionFrame.MissionTab.MissionPage.Enemy2.PortraitFrame.Elite:SetAlpha(0)
	BFAMissionFrame.MissionTab.MissionPage.Enemy2.PortraitFrame.Portrait:SetMask("")
	BFAMissionFrame.MissionTab.MissionPage.Enemy2.PortraitFrame.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
	BFAMissionFrame.MissionTab.MissionPage.Enemy2.PortraitFrame.PortraitRing:Hide()
	m_border(BFAMissionFrame.MissionTab.MissionPage.Enemy2,54,54,"CENTER",0.5,0.5,14,"MEDIUM")

	BFAMissionFrame.MissionTab.MissionPage.Enemy3.PortraitFrame.Elite:SetAlpha(0)
	BFAMissionFrame.MissionTab.MissionPage.Enemy3.PortraitFrame.Portrait:SetMask("")
	BFAMissionFrame.MissionTab.MissionPage.Enemy3.PortraitFrame.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
	BFAMissionFrame.MissionTab.MissionPage.Enemy3.PortraitFrame.PortraitRing:Hide()
	m_border(BFAMissionFrame.MissionTab.MissionPage.Enemy3,54,54,"CENTER",0.5,0.5,14,"MEDIUM")

	BFAMissionFrame.MissionTab.MissionPage.RewardsFrame.Reward1.BG:Hide()
	BFAMissionFrame.MissionTab.MissionPage.RewardsFrame.Reward2.BG:Hide()
	BFAMissionFrame.MissionTab.MissionPage.BuffsFrame.BuffsBG:Hide()
	BFAMissionFrame.MissionTab.MissionPage.Stage.Header:Hide()
	m_fontify(BFAMissionFrame.MissionTab.MissionPage.BuffsFrame.BuffsTitle,"white")
	m_fontify(BFAMissionFrame.MissionTab.MissionPage.EmptyString,"white")
	m_fontify(BFAMissionFrame.MissionTab.MissionPage.Stage.Level,"white")
	m_fontify(BFAMissionFrame.MissionTab.MissionPage.Stage.Title,"white")
	m_fontify(BFAMissionFrame.MissionTab.MissionPage.Stage.ItemLevel,"white")
	m_fontify(BFAMissionFrame.MissionTab.MissionPage.Stage.Location,"white")
	m_fontify(BFAMissionFrame.MissionTab.MissionPage.Stage.MissionInfo.XP,"white")
	m_fontify(BFAMissionFrame.MissionTab.MissionPage.Stage.MissionInfo.MissionTime,"white")
	m_fontify(BFAMissionFrame.MissionTab.MissionPage.Stage.MissionInfo.MissionEnv,"white")
	m_fontify(BFAMissionFrame.MissionTab.MissionPage.Enemy1.Name,"white")
	m_fontify(BFAMissionFrame.MissionTab.MissionPage.Enemy2.Name,"white")
	m_fontify(BFAMissionFrame.MissionTab.MissionPage.Enemy3.Name,"white")
	m_fontify(BFAMissionFrame.MissionTab.MissionPage.Stage.MissionDescription,"white")
	m_fontify(BFAMissionFrame.MissionTab.MissionPage.RewardsFrame.MissionXP,"white")
	m_fontify(BFAMissionFrame.MissionTab.MissionPage.CostFrame.CostLabel,"color")
	m_fontify(BFAMissionFrame.MissionTab.MissionPage.CostFrame.Cost,"white")
	for i=1,3 do
		local missionPage = BFAMissionFrame.MissionTab.MissionPage
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

	--[[ BFA Followerlist Frame]]--

	BFAMissionFrame.FollowerTab.Class:SetAlpha(0)
	local _,BFAMissionFrameFollowersMaterialFrameRessources = BFAMissionFrameFollowers.MaterialFrame:GetRegions()
	m_fontify(BFAMissionFrameFollowersMaterialFrameRessources,"color")
	m_fontify(BFAMissionFrameFollowers.MaterialFrame.Materials,"white")
	for i = 1,20 do
		local hideit=select(i,BFAMissionFrameFollowers:GetRegions())
		hideit:Hide()
	end
	for i = 1,19 do
		local hideit=select(i,BFAMissionFrame.FollowerTab:GetRegions())
		hideit:Hide()
	end
	BFAMissionFrame.FollowerTab.PortraitFrame.PortraitRing:Hide()
	BFAMissionFrame.FollowerTab.PortraitFrame.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
	m_SetTexture(BFAMissionFrame.FollowerTab.PortraitFrame.PortraitRingQuality,"Interface\\Garrison\\qual.blp")
	BFAMissionFrame.FollowerTab.PortraitFrame.PortraitRingQuality:SetSize(64,64)
	BFAMissionFrame.FollowerTab.PortraitFrame.LevelBorder:SetAlpha(0)
	local _,xpleft,xpright,xpmiddle = BFAMissionFrame.FollowerTab.XPBar:GetRegions()
	xpleft:Hide()
	xpright:Hide()
	xpmiddle:Hide()
	BFAMissionFrame.FollowerTab.ItemWeapon.Border:Hide()
	BFAMissionFrame.FollowerTab.ItemArmor.Border:Hide()
	m_fontify(BFAMissionFrame.FollowerTab.PortraitFrame.Level,"white")
	m_fontify(BFAMissionFrame.FollowerTab.XPBar.Label,"white",10)
	m_fontify(BFAMissionFrame.FollowerTab.NumFollowers,"white")

	--[[ BFA Mission Complete Frame ]]--

	local bg = BFAMissionFrame.MissionComplete:GetRegions()
	bg:ClearAllPoints()
	bg:SetPoint("CENTER",BFAMissionFrame.MissionComplete,0,0)
	m_SetTexture(bg,"Interface\\FrameGeneral\\UI-Background-Rock.blp")
	bg:SetSize(552,592)
	BFAMissionFrame.MissionComplete.BonusRewards.Saturated:ClearAllPoints()
	BFAMissionFrame.MissionComplete.NextMissionButton:ClearAllPoints()
	BFAMissionFrame.MissionComplete.NextMissionButton:SetPoint("CENTER",0,-276)

	for i=1,10 do
		local hideit=select(i,BFAMissionFrame.MissionTab.MissionPage.RewardsFrame:GetRegions())
		hideit:Hide()
	end
	local hideit = BFAMissionFrame.MissionTab.MissionPage.RewardsFrame.Reward1:GetRegions()
	hideit:Hide()
	local hideit=select(1,BFAMissionFrame.MissionTab.MissionPage.RewardsFrame.Reward2:GetRegions())
	hideit:Hide()
	for i=2,12 do
		local hideit=select(i,BFAMissionFrame.MissionComplete:GetRegions())
		hideit:Hide()
	end
	for i=11,13 do
		local hideit=select(i,BFAMissionFrame.MissionComplete.Stage.MissionInfo:GetRegions())
		hideit:Hide()
	end
	for i =1,10 do
		local hideit=select(i,BFAMissionFrame.MissionComplete.BonusRewards:GetRegions())
		hideit:SetAlpha(0)
	end
	local _,_,_,hideit = BFAMissionFrame.MissionComplete.Stage:GetRegions()
	hideit:Hide()

	for i=1,5 do
		local hideit=select(i,BFAMissionFrame.MissionComplete.Stage.MissionInfo:GetRegions())
		hideit:Hide()
	end
	m_fontify(BFAMissionFrame.MissionComplete.Stage.MissionInfo.Level,"white")
	m_fontify(BFAMissionFrame.MissionComplete.Stage.MissionInfo.ItemLevel,"white")
	m_fontify(BFAMissionFrame.MissionComplete.Stage.MissionInfo.Title,"color")
	m_fontify(BFAMissionFrame.MissionComplete.Stage.MissionInfo.Location,"white")
	local _,_,_,_,_,_,_,_,_,_,rewards = BFAMissionFrame.MissionComplete.BonusRewards:GetRegions()
	m_fontify(rewards,"white")

end

local catchaddon = CreateFrame("FRAME")
catchaddon:RegisterEvent("ADDON_LOADED")

--function to catch loading addons
local function skinnedOnLoad(_, _, addon)
	if IsAddOnLoaded("Blizzard_AdventureMap") and addon == "Blizzard_GarrisonUI" then
		skin_AdventureMap()
	end
end

--this function decides whether the addon is already loaded or if we need to look out for it!

local function skinnedOnLogin()
	if IsAddOnLoaded("Blizzard_GarrisonUI") and IsAddOnLoaded("Blizzard_AdventureMap") then
		-- Addon is already loaded, procceed to skin!
		skin_AdventureMap()
	else
		-- Addon is not loaded yet, procceed to look out for it!
		catchaddon:SetScript("OnEvent", skinnedOnLoad)
	end
end

local HelloWorld = CreateFrame("FRAME")
HelloWorld:RegisterEvent("PLAYER_ENTERING_WORLD")
HelloWorld:SetScript("OnEvent", skinnedOnLogin)