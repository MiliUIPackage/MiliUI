local function skin_Blizzard_GarrisonUI()

	local function miirgui_GarrisonLandingPageReport(self)
		for i=1,12 do
			local shipment = self.shipmentsPool:Acquire()
			local roundoverlay= shipment:GetRegions()
			roundoverlay:Hide()
			shipment.Icon:SetDesaturated(false)
			shipment.Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
			m_fontify(shipment.Name,"white")
			m_fontify(shipment.Count,"white")
			m_SetTexture(shipment.Done,"Interface\\Garrison\\shipborder.blp")
			shipment.Done:SetVertexColor(1,1,0,1)
			shipment.Done:SetSize(64,64)
			shipment.Done:Show()
			shipment.Border:Show()
			m_SetTexture(shipment.Border,"Interface\\Garrison\\shipborder.blp")
			shipment.Border:SetSize(64,64)
			shipment.Border:SetVertexColor(miirguiDB.color.r,miirguiDB.color.g,miirguiDB.color.b,1)
			shipment.BG:SetAlpha(0)
		end
	end

	GarrisonLandingPageReport:HookScript("OnShow",miirgui_GarrisonLandingPageReport)

	local function miirgui_GarrisonLandingPageReportList_Update()
		local items = GarrisonLandingPageReport.List.items or {};
		local numItems = #items;
		local scrollFrame = GarrisonLandingPageReport.List.listScroll;
		local offset = HybridScrollFrame_GetOffset(scrollFrame);
		local buttons = scrollFrame.buttons;
		local numButtons = #buttons;
		if (numItems == 0) then
			m_fontify(GarrisonLandingPageReport.List.EmptyMissionText,"white")
		end
		for i = 1, numButtons do
			local button = buttons[i];
			local index = offset + i;
			local item = items[index];
			if ( item ) then
				m_SetTexture(button.BG,"Interface\\FrameGeneral\\UI-Background-Rock.blp")
				button.BG:SetSize(400,42)
				m_fontify(button.TimeLeft,"white",12)
				button.MissionTypeIcon:ClearAllPoints()
				button.MissionTypeIcon:SetPoint("LEFT",button,10,0)
				button.MissionTypeIcon:SetSize(34,34)
				m_fontify(button.Title,"color")
				if (item.isComplete) then
					m_fontify(button.MissionType,"green")
				end
			end
		end
	end

	hooksecurefunc("GarrisonLandingPageReportList_Update",miirgui_GarrisonLandingPageReportList_Update)

	local function miirgui_GarrisonLandingPageReportList_UpdateAvailable()
		local items = GarrisonLandingPageReport.List.AvailableItems or {};
		local numItems = #items;
		local scrollFrame = GarrisonLandingPageReport.List.listScroll;
		local offset = HybridScrollFrame_GetOffset(scrollFrame);
		local buttons = scrollFrame.buttons;
		local numButtons = #buttons;
		for i = 1, numButtons do
			local button = buttons[i];
			local index = offset + i
			if ( index <= numItems ) then
				m_SetTexture(button.BG,"Interface\\FrameGeneral\\UI-Background-Rock.blp")
				button.BG:SetSize(400,42)
				button.id = index;
				button.Reward1.Icon:SetTexCoord(0.02, 0.98, 0.02, 0.98)
				button.MissionTypeIcon:ClearAllPoints()
				button.MissionTypeIcon:SetPoint("LEFT",button,10,0)
				button.MissionTypeIcon:SetSize(34,34)
				m_fontify(button.Title,"color")
			end
		end
	end

	hooksecurefunc("GarrisonLandingPageReportList_UpdateAvailable",miirgui_GarrisonLandingPageReportList_UpdateAvailable)

	hooksecurefunc(GarrisonLandingPage.FollowerTab,"ShowEquipment",function(self,followerInfo)
		self.equipmentPool:ReleaseAll();
		local numEquipmentWithUnlockables = #followerInfo.equipment + #followerInfo.unlockableEquipment;
		local lastEquipmentFrame;
		for i=1, numEquipmentWithUnlockables do
			local equipment;
			if (i <= #followerInfo.equipment) then
				equipment = followerInfo.equipment[i];
			else
				equipment = followerInfo.unlockableEquipment[i - #followerInfo.equipment];
			end

			local equipmentFrame = self.equipmentPool:Acquire();
			if (self.isLandingPage) then
				equipmentFrame:SetScale(1);
			end

			equipmentFrame.followerTypeID = followerInfo.followerTypeID;
			equipmentFrame.followerList = self:GetFollowerList();
			equipmentFrame.abilityID = equipment.id;
			equipmentFrame.followerID = followerInfo.followerID;
			if (equipment.icon) then
				equipmentFrame.Icon:SetSize(40,40)
				equipmentFrame.Border:Hide()
				equipmentFrame.BG:ClearAllPoints()
				equipmentFrame.BG:SetSize(46,46)
				equipmentFrame.BG:SetPoint("CENTER",equipmentFrame.Icon,0,0)
				m_border(equipmentFrame,42,42,"CENTER",0,0,14,"HIGH")
			else
				equipmentFrame.Border:Hide()
				equipmentFrame.BG:ClearAllPoints()
				equipmentFrame.BG:SetSize(46,46)
				equipmentFrame.BG:SetPoint("CENTER",equipmentFrame.Icon,0,0)
				m_border(equipmentFrame,42,42,"CENTER",0,0,14,"HIGH")
			end
			if (lastEquipmentFrame) then
				equipmentFrame:SetPoint("TOPLEFT", lastEquipmentFrame, "TOPRIGHT");
			else
				local totalWidth = equipmentFrame:GetWidth() * numEquipmentWithUnlockables;
				if (self.isLandingPage) then
					equipmentFrame:SetPoint("TOPLEFT", self.AbilitiesFrame.EquipmentSlotsLabel, "BOTTOM", -totalWidth/2, 0);
				else
					equipmentFrame:SetPoint("TOPLEFT", self.AbilitiesFrame.EquipmentSlotsLabel, "BOTTOM", -totalWidth/2, -20);
				end
			end
			equipmentFrame:Show();
			lastEquipmentFrame = equipmentFrame;
		end
end)	
	
	local bg = GarrisonLandingPage:GetRegions()
	m_SetTexture(bg,"Interface\\FrameGeneral\\UI-Background-Marble.blp")
	bg:ClearAllPoints()
	bg:SetPoint("LEFT")
	bg:SetSize(830,520)

	--Invasion Alert Icon

	local _,newinvasion = GarrisonLandingPage.InvasionBadge:GetRegions()
	newinvasion:ClearAllPoints()
	m_SetTexture(newinvasion,"Interface\\Garrison\\newinvasion.blp")
	newinvasion:SetSize(32,32)
	newinvasion:ClearAllPoints()
	newinvasion:SetPoint("CENTER",0,-10)

	local invasion = GarrisonLandingPage.InvasionBadge:GetRegions()
	invasion:ClearAllPoints()
	m_SetTexture(invasion,"Interface\\Garrison\\invasion.blp")
	invasion:SetSize(32,32)
	invasion:ClearAllPoints()
	invasion:SetPoint("CENTER",0,-10)

	-- Main Report Frame

	local bg = GarrisonLandingPageReportList:GetRegions()
	bg:Hide()
	GarrisonLandingPageReportListListScrollFrameScrollBarTrack:Hide()
	local _, anvil = GarrisonLandingPageReport:GetRegions()
	anvil:Hide()
	for i=2,10 do
		local hideit=select(i,GarrisonLandingPage:GetRegions() )
		hideit:Hide()
	end
	for i=7,9 do
		local hover=select(i,GarrisonLandingPageTab1:GetRegions())
		hover:SetAlpha(0)
	end
	for i=7,9 do
		local hover=select(i,GarrisonLandingPageTab2:GetRegions())
		hover:SetAlpha(0)
	end
	for i=7,9 do
		local hover=select(i,GarrisonLandingPageTab3:GetRegions())
		hover:SetAlpha(0)
	end

	--progress and available button

	local avail = GarrisonLandingPageReport.Available:GetRegions()
	avail:SetAlpha(0)
	local inp = GarrisonLandingPageReport.InProgress:GetRegions()
	inp:SetAlpha(0)
	m_border(GarrisonLandingPageReport.InProgress,194,30,"CENTER",0,-4,12,"MEDIUM")
	m_border(GarrisonLandingPageReport.Available,194,30,"CENTER",0,-4,12,"MEDIUM")

	--Mission List

	for i=1,10 do
		m_border(_G["GarrisonLandingPageReportListListScrollFrameButton"..i],402,46,"CENTER",0.5,-1,12,"MEDIUM")
	end

	m_fontify(GarrisonLandingPageReport.Title,"color")

	--ReportFrame Tabs
	GarrisonLandingPageTab1.LeftDisabled:SetAlpha(0)
	GarrisonLandingPageTab1.RightDisabled:SetAlpha(0)
	GarrisonLandingPageTab1.MiddleDisabled:ClearAllPoints()
	GarrisonLandingPageTab1.MiddleDisabled:SetPoint("TOPLEFT","GarrisonLandingPageTab1",0,0)
	GarrisonLandingPageTab1.MiddleDisabled:SetPoint("BOTTOMRIGHT","GarrisonLandingPageTab1",0,2)
	GarrisonLandingPageTab1.Left:SetAlpha(0)
	GarrisonLandingPageTab1.Right:SetAlpha(0)
	GarrisonLandingPageTab1.Middle:ClearAllPoints()
	GarrisonLandingPageTab1.Middle:SetPoint("TOPLEFT","GarrisonLandingPageTab1",0,0)
	GarrisonLandingPageTab1.Middle:SetPoint("BOTTOMRIGHT","GarrisonLandingPageTab1",0,2)

	GarrisonLandingPageTab2.LeftDisabled:SetAlpha(0)
	GarrisonLandingPageTab2.RightDisabled:SetAlpha(0)
	GarrisonLandingPageTab2.MiddleDisabled:ClearAllPoints()
	GarrisonLandingPageTab2.MiddleDisabled:SetPoint("TOPLEFT","GarrisonLandingPageTab2",10,0)
	GarrisonLandingPageTab2.MiddleDisabled:SetPoint("BOTTOMRIGHT","GarrisonLandingPageTab2",-10,2)
	GarrisonLandingPageTab2.Left:SetAlpha(0)
	GarrisonLandingPageTab2.Right:SetAlpha(0)
	GarrisonLandingPageTab2.Middle:ClearAllPoints()
	GarrisonLandingPageTab2.Middle:SetPoint("TOPLEFT","GarrisonLandingPageTab2",10,0)
	GarrisonLandingPageTab2.Middle:SetPoint("BOTTOMRIGHT","GarrisonLandingPageTab2",-10,2)
	-- Fleet

	GarrisonLandingPageTab3:ClearAllPoints()
	GarrisonLandingPageTab3:SetPoint("RIGHT",GarrisonLandingPageTab2,84,0)
	GarrisonLandingPageTab3.LeftDisabled:SetAlpha(0)
	GarrisonLandingPageTab3.RightDisabled:SetAlpha(0)
	GarrisonLandingPageTab3.MiddleDisabled:ClearAllPoints()

	GarrisonLandingPageTab3.MiddleDisabled:SetPoint("TOPLEFT","GarrisonLandingPageTab3",0,0)
	GarrisonLandingPageTab3.MiddleDisabled:SetPoint("BOTTOMRIGHT","GarrisonLandingPageTab3",0,4)

	GarrisonLandingPageTab3.Left:SetAlpha(0)
	GarrisonLandingPageTab3.Right:SetAlpha(0)
	GarrisonLandingPageTab3.Middle:ClearAllPoints()
	GarrisonLandingPageTab3.Middle:SetPoint("TOPLEFT","GarrisonLandingPageTab3",0,0)
	GarrisonLandingPageTab3.Middle:SetPoint("BOTTOMRIGHT","GarrisonLandingPageTab3",0,4)

	--[[ Follower Tab ]]--

	for i=1,3 do
		local hideit=select(i,GarrisonLandingPage.FollowerList:GetRegions())
		hideit:Hide()
	end
	for i = 1,19 do
		local hideit=select(i,GarrisonMissionFrame.FollowerTab:GetRegions())
		hideit:Hide()
	end

	local function miirgui_GarrisonLandingPage_ShowFollower(self,followerID)
		local followerInfo = C_Garrison.GetFollowerInfo(followerID);
		if followerInfo.quality == 6 then
			self.PortraitFrame.PortraitRingQuality:Show()
			self.PortraitFrame.PortraitRingQuality:SetVertexColor(0.90196,0.8,0.50196,1)
			self.Name:SetTextColor(0.90196,0.8,0.50196,1)
		end
	end

	hooksecurefunc(GarrisonLandingPage.FollowerTab,"ShowFollower",miirgui_GarrisonLandingPage_ShowFollower)

	GarrisonLandingPage.FollowerTab.XPBar.XPLeft:Hide()
	GarrisonLandingPage.FollowerTab.XPBar.XPRight:Hide()
	GarrisonLandingPage.FollowerTab.PortraitFrame.PortraitRing:Hide()
	GarrisonLandingPage.FollowerTab.PortraitFrame.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
	m_SetTexture(GarrisonLandingPage.FollowerTab.PortraitFrame.PortraitRingQuality,"Interface\\Garrison\\qual.blp")
	GarrisonLandingPage.FollowerTab.PortraitFrame.PortraitRingQuality:SetSize(64,64)
	GarrisonLandingPage.FollowerTab.PortraitFrame.LevelBorder:SetAlpha(0)
	GarrisonLandingPage.FollowerTab.Class:SetTexCoord(0.15, 0.85, 0.15, 0.85)
	m_border(GarrisonLandingPage.FollowerTab,60,52,"TOPRIGHT",-12,-6,14,"MEDIUM")
	m_fontify(GarrisonLandingPage.FollowerTab.PortraitFrame.Level,"white")
	m_fontify(GarrisonLandingPage.FollowerTab.ClassSpec,"white")
	m_fontify(GarrisonLandingPage.FollowerTab.Name,"white")
	m_fontify(GarrisonLandingPage.FollowerTab.XPLabel,"white")
	m_fontify(GarrisonLandingPage.FollowerTab.XPText,"white")
	m_fontify(GarrisonLandingPage.FollowerTab.XPBar.Label,"white",10)
	m_border(GarrisonLandingPage,832,522,"Center",0,0,14,"MEDIUM")
	GarrisonLandingPageTab1:SetFrameStrata("HIGH")
	GarrisonLandingPageTab2:SetFrameStrata("HIGH")
	GarrisonLandingPageTab3:SetFrameStrata("HIGH")
	m_border(GarrisonLandingPageTab1,GarrisonLandingPageTab1:GetWidth()-12,GarrisonLandingPageTab1:GetHeight()-4,"Center",0.5,0,14,"HIGH")
	m_border(GarrisonLandingPageTab2,GarrisonLandingPageTab2:GetWidth()-16,GarrisonLandingPageTab2:GetHeight()-4,"Center",0,0,14,"HIGH")
	m_border(GarrisonLandingPageTab3,GarrisonLandingPageTab3:GetWidth()-20,GarrisonLandingPageTab3:GetHeight()-4,"Center",0.5,0,14,"HIGH")

	m_border(GarrisonLandingPage.FollowerTab.XPBar,374,16,"Center",0,0,12,"MEDIUM")
	m_fontify(GarrisonLandingPage.FollowerTab.FollowerText,"color")
	m_fontify(GarrisonLandingPage.FollowerTab.AbilitiesFrame.EquipmentSlotsLabel,"color")
	m_border(GarrisonCapacitiveDisplayFrame,240,50,"TOP",14,-66,14,"MEDIUM")
	GarrisonLandingPageTutorialBoxBg:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 1)
	GarrisonLandingPageTutorialBoxBg:SetColorTexture(0.078,0.078,0.078,1)
	m_border(GarrisonLandingPageTutorialBox,226,76,"CENTER",0,0,14,"DIALOG")
	m_fontify(GarrisonLandingPageTutorialBox.Text,"white")

	--[[GarrisonCapacitiveDisplayFrame]]--

	m_border(GarrisonCapacitiveDisplayFrame.CapacitiveDisplay,332,340,"CENTER",0,0,14,"HIGH")
	GarrisonCapacitiveDisplayFramePortrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)

	local function miirgui_GarrisonCapacitiveDisplayFrame(self)
		GarrisonCapacitiveDisplayFrame.CapacitiveDisplay.ShipmentIconFrame.ShipmentName:SetJustifyH("LEFT")
		local display = self.CapacitiveDisplay;
		local reagents = display.Reagents;
		if reagents[2] == nil then
			local reagent = reagents[1]
			_,bg = reagent:GetRegions()
			m_SetTexture(bg,"Interface\\AuctionFrame\\UI-AuctionItemNameFrame.blp")
		else
			for i = 1, 2 do
				local reagent = reagents[i];
				_,bg = reagent:GetRegions()
				m_SetTexture(bg,"Interface\\AuctionFrame\\UI-AuctionItemNameFrame.blp")
			end
		end
		if (GarrisonCapacitiveDisplayFrame.CapacitiveDisplay.ShipmentIconFrame.Follower) then
			local follower = GarrisonCapacitiveDisplayFrame.CapacitiveDisplay.ShipmentIconFrame.Follower
			GarrisonCapacitiveDisplayFrame.CapacitiveDisplay.IconBG:Hide()
			follower.PortraitRing:Hide()
			follower.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
			m_SetTexture(follower.PortraitRingQuality,"Interface\\Garrison\\qual.blp")
			follower.PortraitRingQuality:SetSize(64,64)
			GarrisonCapacitiveDisplayFrame.CapacitiveDisplay.ShipmentIconFrame.Icon:SetSize(48,48)
			GarrisonCapacitiveDisplayFrame.CapacitiveDisplay.ShipmentIconFrame.Icon:SetPoint("CENTER",0,4)
		end
	end
	GarrisonCapacitiveDisplayFrame:HookScript("OnShow",miirgui_GarrisonCapacitiveDisplayFrame)
	m_cursorfix(GarrisonLandingPageFollowerList.SearchBox)
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