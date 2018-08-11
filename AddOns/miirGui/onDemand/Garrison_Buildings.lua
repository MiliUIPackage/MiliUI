local function skin_Blizzard_GarrisonUI()
	-- Main Frame
	m_fontify(GarrisonBuildingFrame.MapFrame.TownHall.TownHallName,"white")
	local  _,_,_,_,_,_,_,_,_,GarrisonRecruitSelectFrameBackground = GarrisonRecruitSelectFrame:GetRegions()
	m_SetTexture(GarrisonRecruitSelectFrameBackground,"Interface\\FrameGeneral\\UI-Background-Rock.blp")
	local MaterialFrameCurrencyBorder = GarrisonBuildingFrame.BuildingList.MaterialFrame:GetRegions()
	MaterialFrameCurrencyBorder:Hide()
	for i =11,14 do
		local hideit=select(i,GarrisonBuildingFrame:GetRegions())
		hideit:Hide()
	end
	for i =1,21 do
		local hideit=select(i,GarrisonBuildingFrame.BuildingList:GetRegions())
		hideit:Hide()
	end
	for i =1,25 do
		local hideit=select(i,GarrisonBuildingFrame.TownHallBox:GetRegions())
		hideit:Hide()
	end
	for i =1,25 do
		local hideit=select(i,GarrisonBuildingFrame.InfoBox:GetRegions())
		hideit:Hide()
	end
	GarrisonBuildingFrameTutorialButton.Ring:Hide()
	local _,_,_,_,_,_,_,_,_,GarrisonBuildingFrameBackground,GarrisonBuildingFrameTopbar = GarrisonBuildingFrame:GetRegions()
	m_SetTexture(GarrisonBuildingFrameBackground,"Interface\\FrameGeneral\\UI-Background-Rock.blp")
	m_SetTexture(GarrisonBuildingFrameTopbar,"Interface\\FrameGeneral\\UI-Background-Rock.blp")
	m_border(GarrisonBuildingFrame.BuildingList.MaterialFrame,280,26,"CENTER",0,0,14,"MEDIUM")
	m_border(GarrisonBuildingFrame.TownHallBox,640,164,"CENTER",0,0,14,"MEDIUM")
	m_border(GarrisonBuildingFrame.InfoBox,640,164,"CENTER",0,0,14,"MEDIUM")
	m_border(GarrisonBuildingFrame.BuildingList,288,570,"CENTER",0,0,14,"MEDIUM")
	m_border(GarrisonBuildingFrame.BuildingList.Tab1,90,22,"CENTER",0,0,14,"MEDIUM")
	m_border(GarrisonBuildingFrame.BuildingList.Tab2,90,22,"CENTER",0,0,14,"MEDIUM")
	m_border(GarrisonBuildingFrame.BuildingList.Tab3,90,22,"CENTER",0,0,14,"MEDIUM")
	m_border(GarrisonBuildingFrame.InfoBox.AddFollowerButton,48,48,"CENTER",0,4,14,"MEDIUM")
	m_border(GarrisonBuildingFrameFollowers,270,560,"CENTER",-6,6,12,"HIGH")

	local function miirgui_GarrisonBuildingList_SelectTab(tab)
		local list = GarrisonBuildingFrame.BuildingList;
		local currButton
		for i=1, #tab.buildings do
			local building = tab.buildings[i];
			currButton = list.Buttons[i];

			m_fontify(currButton.Name,"white")
			currButton.Name:ClearAllPoints()
			currButton.Name:SetPoint("LEFT",60,0)

			local bg,selected,_,_,_,hover = currButton:GetRegions()
			m_SetTexture(bg,"Interface\\Garrison\\building.blp")
			bg:SetSize(256,64)
			bg:ClearAllPoints()
			bg:SetPoint("LEFT",22,1)

			m_SetTexture(selected,"Interface\\Garrison\\selected.blp")
			selected:SetSize(256,64)
			selected:ClearAllPoints()
			selected:SetPoint("LEFT",22,1)

			m_SetTexture(hover,"Interface\\Garrison\\selected.blp")
			hover:SetSize(256,64)
			hover:ClearAllPoints()
			hover:SetPoint("LEFT",22,1)

			if (building.needsPlan) then
				bg:SetDesaturated(true)
				currButton.Plans:ClearAllPoints()
				currButton.Plans:SetPoint("RIGHT",-20,0)
			end
		end
	end

	hooksecurefunc("GarrisonBuildingList_SelectTab",miirgui_GarrisonBuildingList_SelectTab)

	--BuildingTabs
	local _,hideit,hover = GarrisonBuildingFrame.BuildingList.Tab1:GetRegions()
	hideit:SetAlpha(0)
	hover:ClearAllPoints()
	hover:SetPoint("CENTER")
	hover:SetSize(88,20)

	local _,hideit,hover = GarrisonBuildingFrame.BuildingList.Tab2:GetRegions()
	hideit:SetAlpha(0)
	hover:ClearAllPoints()
	hover:SetPoint("CENTER")
	hover:SetSize(88,20)

	local _,hideit,hover = GarrisonBuildingFrame.BuildingList.Tab3:GetRegions()
	hideit:SetAlpha(0)
	hover:ClearAllPoints()
	hover:SetPoint("CENTER")
	hover:SetSize(88,20)

	--Building Info Box

	local function miirgui_GarrisonBuildingInfoBox_ShowBuilding()
		m_fontify(GarrisonBuildingFrame.TownHallBox.Title,"color")
		m_fontify(GarrisonBuildingFrame.TownHallBox.Description,"white")
		m_fontify(GarrisonBuildingFrame.TownHallBox.UpgradeCostBar.CostAmountGold,"white")
		m_fontify(GarrisonBuildingFrame.TownHallBox.UpgradeCostBar.CostAmountMaterial,"white")
		m_fontify(GarrisonBuildingFrame.TownHallBox.UpgradeCostBar.CostLabel,"color")
		m_fontify(GarrisonBuildingFrame.InfoBox.Title,"color")
		m_fontify(GarrisonBuildingFrame.InfoBox.Description,"white")
		m_fontify(GarrisonBuildingFrame.InfoBox.UpgradeCostBar.CostAmountMaterial,"white")
		m_fontify(GarrisonBuildingFrame.InfoBox.UpgradeCostBar.CostAmountGold,"white")
		m_fontify(GarrisonBuildingFrame.InfoBox.UpgradeCostBar.CostLabel,"color")
		m_fontify(GarrisonBuildingFrame.InfoBox.UpgradeCostBar.TimeLabel,"color")
		m_fontify(GarrisonBuildingFrame.InfoBox.UpgradeCostBar.TimeAmount,"white")
	end

	hooksecurefunc("GarrisonBuildingInfoBox_ShowBuilding",miirgui_GarrisonBuildingInfoBox_ShowBuilding)

	-- Info Box Follower

	GarrisonBuildingFrame.InfoBox.FollowerPortrait.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
	GarrisonBuildingFrame.InfoBox.FollowerPortrait.Portrait:ClearAllPoints()
	GarrisonBuildingFrame.InfoBox.FollowerPortrait.Portrait:SetPoint("CENTER",0,2)

	GarrisonBuildingFrame.InfoBox.FollowerPortrait.PortraitRing:Hide()
	m_SetTexture(GarrisonBuildingFrame.InfoBox.FollowerPortrait.PortraitRingQuality,"Interface\\Garrison\\qual.blp")
	GarrisonBuildingFrame.InfoBox.FollowerPortrait.PortraitRingQuality:SetHeight(64)
	GarrisonBuildingFrame.InfoBox.FollowerPortrait.PortraitRingQuality:SetWidth(64)
	GarrisonBuildingFrame.InfoBox.FollowerPortrait.PortraitRingQuality:ClearAllPoints()
	GarrisonBuildingFrame.InfoBox.FollowerPortrait.PortraitRingQuality:SetPoint("CENTER",0,-4)
	GarrisonBuildingFrame.InfoBox.FollowerPortrait.LevelBorder:SetAlpha(0)
	m_fontify(GarrisonBuildingFrame.InfoBox.FollowerPortrait.Level,"white")
	m_fontify(GarrisonBuildingFrame.InfoBox.FollowerPortrait.FollowerStatus,"white")

	--Info Box Add Follower

	GarrisonBuildingFrame.InfoBox.AddFollowerButton.EmptyPortrait:Hide()
	m_SetTexture(GarrisonBuildingFrame.InfoBox.AddFollowerButton.PortraitHighlight,"Interface\\Containerframe\\quality.blp")
	GarrisonBuildingFrame.InfoBox.AddFollowerButton.PortraitHighlight:ClearAllPoints()
	GarrisonBuildingFrame.InfoBox.AddFollowerButton.PortraitHighlight:SetPoint("CENTER",0,4)
	GarrisonBuildingFrame.InfoBox.AddFollowerButton.PortraitHighlight:SetSize(44,44)
	m_fontify(GarrisonBuildingFrame.InfoBox.AddFollowerButton.AddFollowerText,"white")


	--Assign a follower to a building

	for i=1,21 do
		hideit=select(i,GarrisonBuildingFrameFollowers:GetRegions())
		hideit:SetAlpha(0)
	end

	GarrisonBuildingFrameFollowersListScrollFrameScrollBarBG:Hide()
	GarrisonBuildingFrame.GarrCorners.TopLeftGarrCorner:Hide()
	GarrisonBuildingFrame.GarrCorners.TopRightGarrCorner:Hide()
	GarrisonBuildingFrame.GarrCorners.BottomLeftGarrCorner:Hide()
	GarrisonBuildingFrame.GarrCorners.BottomRightGarrCorner:Hide()

	--[[RECRUITERFRAME]]--

	local _,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,GarrisonRecruiterFramePortrait = GarrisonRecruiterFrame:GetRegions()
	GarrisonRecruiterFramePortrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
	GarrisonRecruiterFramePortrait:SetPoint("TOPLEFT",-6,7)

	--[[GARRISONRECRUITSELECTFRAME]]--

	m_border(GarrisonRecruitSelectFrame.FollowerList,310,570,"CENTER",0,0,12,"MEDIUM")
	m_border(GarrisonRecruitSelectFrame.FollowerSelection.Recruit1,190,570,"CENTER",0,4,14,"MEDIUM")
	m_border(GarrisonRecruitSelectFrame.FollowerSelection.Recruit2,190,570,"CENTER",0,4,14,"MEDIUM")
	m_border(GarrisonRecruitSelectFrame.FollowerSelection.Recruit3,190,570,"CENTER",0,4,14,"MEDIUM")
	m_border(GarrisonRecruiterFrame,330,342,"CENTER",0,-16,14,"MEDIUM")

	--Hide parchement

	GarrisonRecruitSelectFrameListScrollFrameScrollBarBG:Hide()
	local _,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,bg = GarrisonRecruiterFrame:GetRegions()
	bg:Hide()

	GarrisonRecruitSelectFrame.Top:Hide()
	GarrisonRecruitSelectFrame.Right:Hide()
	GarrisonRecruitSelectFrame.Left:Hide()
	GarrisonRecruitSelectFrame.Bottom:Hide()
	GarrisonRecruitSelectFrame.GarrCorners.TopLeftGarrCorner:Hide()
	GarrisonRecruitSelectFrame.GarrCorners.TopRightGarrCorner:Hide()
	GarrisonRecruitSelectFrame.GarrCorners.BottomLeftGarrCorner:Hide()
	GarrisonRecruitSelectFrame.GarrCorners.BottomRightGarrCorner:Hide()


	-- Modify the possible recruits portraits

	local function miirgui_GarrisonRecruitSelectFrame_UpdateRecruits()
		local recruitFrame = GarrisonRecruitSelectFrame.FollowerSelection;
		local followers = C_Garrison.GetAvailableRecruits();
		for i=1, 3 do
			local follower = followers[i];
			local frame = recruitFrame["Recruit"..i];
			if(follower)then
				frame:Show()
				frame.PortraitFrame.PortraitRing:Hide()
				m_SetTexture(frame.PortraitFrame.PortraitRingQuality,"Interface\\Garrison\\qual.blp")
				frame.PortraitFrame.PortraitRingQuality:SetSize(64,64)
				frame.PortraitFrame.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
				frame.PortraitFrame.LevelBorder:SetAlpha(0)
				m_fontify(frame.PortraitFrame.Level,"white")
			end
		end
	end

	hooksecurefunc("GarrisonRecruitSelectFrame_UpdateRecruits",miirgui_GarrisonRecruitSelectFrame_UpdateRecruits)

	--Hide scroll list parchement

	for i=1,20 do
		local hideit=select(i,GarrisonRecruitSelectFrame.FollowerList:GetRegions())
		hideit:Hide()
	end

	--Hide Followerselection parchement

	for i=1,22 do
		local hideit=select(i,GarrisonRecruitSelectFrame.FollowerSelection:GetRegions())
		hideit:Hide()
	end

end

local catchaddon = CreateFrame("FRAME")
catchaddon:RegisterEvent("ADDON_LOADED")

--function to catch loading addons
local function skinnedOnLoad(_, _, addon)
	if addon == "Blizzard_GarrisonUI" then
		skin_Blizzard_GarrisonUI()
	end
end

--this function decides whether the addon is already loaded or if we need to look out for it!

local function skinnedOnLogin()
	if IsAddOnLoaded("Blizzard_GarrisonUI") then
		-- Addon is already loaded, procceed to skin!
		skin_Blizzard_GarrisonUI()
	else
		-- Addon is not loaded yet, procceed to look out for it!
		catchaddon:SetScript("OnEvent", skinnedOnLoad)
	end
end

local HelloWorld = CreateFrame("FRAME")
HelloWorld:RegisterEvent("PLAYER_ENTERING_WORLD")
HelloWorld:SetScript("OnEvent", skinnedOnLogin)