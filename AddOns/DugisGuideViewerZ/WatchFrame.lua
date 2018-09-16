local DGV = DugisGuideViewer
if not DGV then return end

local WF = DGV:RegisterModule("DugisWatchFrame")
WF.essential = true

local smallAndObjectiveFrameOneBkg = true

ObjectiveFrameDugiBkg = CreateFrame("Frame", "ObjectiveFrameDugiBkg", UIParent)
ObjectiveFrameDugiBkg:SetFrameStrata("BACKGROUND")
ObjectiveFrameDugiBkg:SetFrameLevel(8)
ObjectiveFrameDugiBkg:SetWidth(52)
ObjectiveFrameDugiBkg:SetHeight(52)
ObjectiveFrameDugiBkg:SetPoint("CENTER", 0, 220)
ObjectiveFrameDugiBkg:Hide()

ObjectiveFrameDugiBkg:EnableMouse(true)

--Variables to store Objective Tracker Frame position in floating mode.
WF.objectiveTrackerX, WF.objectiveTrackerY = nil ,nil

local function GetSmallFrame()
	if DugisGuideViewer.Modules.SmallFrame and DugisGuideViewer.Modules.SmallFrame.Frame then
		return DugisGuideViewer.Modules.SmallFrame
	end
end

function IsSmallFrameCollapsed()
	local SmallFrame = GetSmallFrame()
	return SmallFrame.collapseHeader:IsShown() and SmallFrame.collapsed
end

local function IsObjectiveTrackerVisible()
	return ObjectiveTrackerFrame.HeaderMenu:IsVisible()  and not  ObjectiveTrackerFrame.collapsed  and ObjectiveFrameDugiBkg.initialized
end

ObjectiveFrameDugiBkg:HookScript("OnMouseDown", function()
	--Todo: check if mouse is in ObjectiveTrackerFrame indeed and if ObjectiveTrackerFrame is shown
	local SmallFrame = GetSmallFrame()
	
	if DugisGuideViewer:UserSetting(DGV_MOVEWATCHFRAME) and not DugisGuideViewer:UserSetting(DGV_DISABLEWATCHFRAMEMOD) then
		if not DGV:IsGoldMode() or DGV:IsSmallFrameFloating() then
			local frame = ObjectiveTrackerFrame
			frame.startMouseX, frame.startMouseY = GetCursorPosition()
			frame.startFrameX, frame.startFrameY = GUIUtils:GetRealFeamePos(frame)
			frame.startHeaderFrameX, frame.startHeaderFrameY = GUIUtils:GetRealFeamePos(ObjectiveTrackerFrame.HeaderMenu)
			frame.isDragging = true
		else
			SmallFrame.OnDragStart()
		end
	end
end)

ObjectiveFrameDugiBkg:HookScript("OnMouseUp", function()
	local SmallFrame = GetSmallFrame()
	
	if not DGV:IsGoldMode() or DGV:IsSmallFrameFloating() then
		local frame = ObjectiveTrackerFrame
		frame.isDragging = false
	else
		local SmallFrame = GetSmallFrame()
		SmallFrame.OnDragStop()
	end
end)

function ObjectiveFrameDugiBkgDrag()
	if DugisGuideViewer:UserSetting(DGV_DISABLEWATCHFRAMEMOD) or DGV:IncompatibleAddonLoaded() or DGV:ObjectiveTrackerOriginal() then return end

	local frame = ObjectiveTrackerFrame
	
	if frame.isDragging then
		if not IsMouseButtonDown("LeftButton") then
			frame.isDragging = false
		end
	end
	
	if frame.isDragging and not DGV:ObjectiveTrackerOriginal() then
		local SmallFrame = GetSmallFrame()
		if not DGV:IsGoldMode() or DGV:IsSmallFrameFloating() then
			local currentMouseX, currentMouseY = GetCursorPosition()
			local deltaMouseX, deltaMouseY = currentMouseX - frame.startMouseX, currentMouseY - frame.startMouseY
			local newBkgFrameX, newBkgFrameY = frame.startFrameX + deltaMouseX, frame.startFrameY + deltaMouseY
			local newHeaderFrameX, newHeaderFrameY = frame.startHeaderFrameX + deltaMouseX, frame.startHeaderFrameY + deltaMouseY
			
			ObjectiveTrackerFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", newBkgFrameX,  newBkgFrameY)
			ObjectiveTrackerFrame.HeaderMenu:ClearAllPoints()
			ObjectiveTrackerFrame.HeaderMenu:SetPoint("TOPLEFT", UIParent, "TOPLEFT", newHeaderFrameX,  newHeaderFrameY)
			
			WF.objectiveTrackerX, WF.objectiveTrackerY = GUIUtils:GetRealFeamePos(ObjectiveTrackerFrame)
		end
	end
end

local oldObjectiveTrackerOriginal
WF.OnFrameUpdate = function()
	if not WF.initialized then
		return
	end
	
	if oldObjectiveTrackerOriginal ~= nil 
	and oldObjectiveTrackerOriginal ~= DGV:ObjectiveTrackerOriginal()
	and DGV:ObjectiveTrackerOriginal() then
		WF:OnBeforeObjectiveTrackerOriginal()
	end
	oldObjectiveTrackerOriginal = DGV:ObjectiveTrackerOriginal()

	
	if not DGV:GuideOn() then
		ObjectiveFrameDugiBkg:Hide()
		if SmallFrameBkg then
			SmallFrameBkg:Hide()
			if DGV.SmallFrame.header then
				DGV.SmallFrame.header:Hide()
				DGV.SmallFrame.collapseHeader:Hide()
			end
		end
		return
	end
	
	local width = 300
	
	local SmallFrame = GetSmallFrame()
	
	if SmallFrame and SmallFrame.Frame and not DGV:IsGoldMode() then
		SmallFrame.header:Hide()
		SmallFrame.Frame:Hide()
	end
	
	if SmallFrame and SmallFrame.Frame:GetTop() == nil then
		local initialY = -180
		local initialX = GetScreenWidth() - 350
		SmallFrame.Frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", initialX, initialY)
	end
	
	--Setting original Objective Tracker/small frame position (below minimap) in case SmallFrame/Objective frame is not floating
	if not DugisGuideViewer:UserSetting(DGV_MOVEWATCHFRAME) then
	
		--Checking space for action bars
		local marginRight  = 0
		local marginTop = 0

		if MultiBarLeft:IsVisible() then
			marginRight = MultiBarLeft:GetWidth() * 2
		else
			if MultiBarRight:IsVisible() then
				marginRight = MultiBarRight:GetWidth()
			end
		end
		
		local top = MinimapCluster:GetHeight()
		
		if DugisGuideViewer.luiloaded then
			top = top  + 50
			marginRight = 35
		end
		
		--Adjustment for Titan Panel addon Top bars 
		if Titan_Bar__Display_Bar2 and Titan_Bar__Display_Bar2:GetHeight() > 0 then
			marginTop = marginTop - 48
		elseif Titan_Bar__Display_Bar and Titan_Bar__Display_Bar:GetHeight() > 0 then
			marginTop = marginTop - 24				
		end		
		
		if not DGV:IsGoldMode() or DGV:IsSmallFrameFloating() then
			if not DGV:IncompatibleAddonLoaded() and not DGV:ObjectiveTrackerOriginal() then
				if DurabilityFrame and DurabilityFrame:IsVisible() then
					marginTop = -DurabilityFrame:GetHeight() - 10
				end
				
				if VehicleSeatIndicator and VehicleSeatIndicator:IsVisible() then
					marginTop = -VehicleSeatIndicator:GetHeight() - 10
				end
								
				ObjectiveTrackerFrame:ClearAllPoints()
				if DugisGuideViewer:UserSetting(DGV_WATCHFRAMEBORDER) then
					ObjectiveTrackerFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", GetScreenWidth() - width - marginRight - 5, -top + marginTop)
				else
					ObjectiveTrackerFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", GetScreenWidth() - width - marginRight - 1, -top + marginTop)
				end
			end
		else
			if DurabilityFrame and DurabilityFrame:IsVisible() then
				marginTop = -DurabilityFrame:GetHeight() + 5
			end
			
			if VehicleSeatIndicator and VehicleSeatIndicator:IsVisible() then
				marginTop = -VehicleSeatIndicator:GetHeight() + 5
			end
			
			if DugisGuideViewer:IsModuleRegistered("SmallFrame") then 
				SmallFrame.Frame:ClearAllPoints()
				if DugisGuideViewer:UserSetting(DGV_WATCHFRAMEBORDER) then
					SmallFrame.Frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", GetScreenWidth() - SmallFrame.Frame:GetWidth() - marginRight - 5, -top + marginTop + 15)
				else
					SmallFrame.Frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", GetScreenWidth() - SmallFrame.Frame:GetWidth() - marginRight - 1, -top + marginTop + 15)	
				end				
			end
		end
	end
	
	local left, top = 0,0
	
	if DGV:IsGoldMode() then
		 left, top = GUIUtils:GetRealFeamePos(SmallFrame.Frame)
	end
	
	local leftTracker, topTracker = GUIUtils:GetRealFeamePos(ObjectiveTrackerFrame)
	
	if not DGV:IncompatibleAddonLoaded() and not DGV:ObjectiveTrackerOriginal() then
		if not DGV:IsGoldMode() or DGV:IsSmallFrameFloating() then
			ObjectiveTrackerFrame:ClearAllPoints()
			if DugisGuideViewer:UserSetting(DGV_MOVEWATCHFRAME) and WF.objectiveTrackerX then
				--Setting ObjectiveTrackerFrame to the current one (WF.objectiveTrackerX) for floating mode
				ObjectiveFrameDugiBkg:SetPoint("TOPLEFT", UIParent, "TOPLEFT", WF.objectiveTrackerX - 40,  WF.objectiveTrackerY + 15)
				
				--Setting ObjectiveTrackerFrame background position to be the same ObjectiveTrackerFrame
				ObjectiveTrackerFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", WF.objectiveTrackerX,  WF.objectiveTrackerY)
			else
				--Setting ObjectiveTrackerFrame background position to be the same ObjectiveTrackerFrame
				ObjectiveFrameDugiBkg:SetPoint("TOPLEFT", UIParent, "TOPLEFT", leftTracker,  topTracker + 15)
				ObjectiveTrackerFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", leftTracker + 40,  topTracker)
				
				--Storing current objective tracker frame position to be used in the future.
				WF.objectiveTrackerX, WF.objectiveTrackerY = leftTracker, topTracker
			end
			
			ObjectiveTrackerFrame:SetHeight(GetScreenHeight())
		else
			local height =  SmallFrame.Frame:GetHeight()
			
			if DGV.shouldUpdateObjectiveTracker then 
				ObjectiveTrackerFrame:ClearAllPoints()
				ObjectiveTrackerFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left + 40,  top - height)
				ObjectiveTrackerFrame:SetHeight(GetScreenHeight())
			end
			ObjectiveFrameDugiBkg:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left,  top - height + 10)
			
			--Storing current objective tracker frame position to be used the future - for example in the essential mode.
			WF.objectiveTrackerX, WF.objectiveTrackerY = GUIUtils:GetRealFeamePos(ObjectiveTrackerFrame)
		end
	end
	
	if DGV:IsGoldMode() then
		width = SmallFrame.Frame:GetWidth()
	end
		
	if not DGV:IncompatibleAddonLoaded() and not DGV:ObjectiveTrackerOriginal() then
		ObjectiveFrameDugiBkg:SetWidth(width)
		
        local realH = GetWorldQuestRealHeight()
		if realH then
			ObjectiveFrameDugiBkg:SetHeight(realH + 30)
		end
	end
	
	ObjectiveFrameDugiBkg.initialized = true
	
	
	if DGV:IsGoldMode() then
		--SmallFrameBkg
		SmallFrameBkg:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left,  top)
		SmallFrameBkg:SetWidth(width)
		
		if  smallAndObjectiveFrameOneBkg and not DGV:IsSmallFrameFloating() then 
			local _, topTracker = GUIUtils:GetRealFeamePos(ObjectiveFrameDugiBkg)
			local heightTracker = ObjectiveFrameDugiBkg:GetHeight()
			local bottomTracker = topTracker - heightTracker
			local heightSharedBkg = 0
			
			if IsObjectiveTrackerVisible() then
				heightSharedBkg = top - bottomTracker
			else
				heightSharedBkg = SmallFrame.Frame:GetHeight()
			end
			
			SmallFrameBkg:SetHeight(heightSharedBkg)
		else
			SmallFrameBkg:SetHeight(SmallFrame.Frame:GetHeight())
		end
		
		--Visibility
		if SmallFrame.Frame:IsVisible() and not IsSmallFrameCollapsed() then
			SmallFrameBkg:Show()
		else
			SmallFrameBkg:Hide()
		end
	else
		if SmallFrameBkg then
			SmallFrameBkg:Hide()
		end
	end
	
	ObjectiveFrameDugiBkgDrag()
	
	if DGV:IsGoldMode() then
		--Updating small frame header positioning
		if SmallFrame.Frame:IsVisible() and not IsSmallFrameCollapsed() then
			SmallFrame.header:Show()
			
			SmallFrame.header:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left + 30,  top - 15)
			SmallFrame.header:EnableMouse(false)
			--SmallFrame.header.Text:EnableMouse(false)

		else
			SmallFrame.header:Hide()
		end
	end
	---
	if ObjectiveFrameDugiBkg and not DGV:IncompatibleAddonLoaded() and not DGV:ObjectiveTrackerOriginal() then
		local shouldBeHidden = not ObjectiveTrackerFrame.HeaderMenu:IsVisible()  or ObjectiveTrackerFrame.collapsed  or not ObjectiveFrameDugiBkg.initialized 
		
		if DGV.shouldUpdateObjectiveTracker then
			if shouldBeHidden then
				ObjectiveFrameDugiBkg:Hide()
			else
				ObjectiveFrameDugiBkg:Show()
			end
		end
		
		if shouldBeHidden
		or (smallAndObjectiveFrameOneBkg and (DGV:IsGoldMode() and not DGV:IsSmallFrameFloating()) )then 
			ObjectiveFrameDugiBkg:SetAlpha(0)
		else
			ObjectiveFrameDugiBkg:SetAlpha(1)
		end
	end
	
	--Updating header menu ( [V] button positon)
	if DGV.shouldUpdateObjectiveTracker then 
		if not DGV:IncompatibleAddonLoaded() and not DGV:ObjectiveTrackerOriginal() then
			ObjectiveTrackerFrame.HeaderMenu:ClearAllPoints()
			if not DGV:IsGoldMode() or DGV:IsSmallFrameFloating() then
				local width = ObjectiveFrameDugiBkg:GetWidth()
				if DugisGuideViewer:UserSetting(DGV_MOVEWATCHFRAME) then 
					ObjectiveTrackerFrame.HeaderMenu:SetPoint("TOPLEFT", UIParent, "TOPLEFT", leftTracker + width - 60,  topTracker)	
				else
					ObjectiveTrackerFrame.HeaderMenu:SetPoint("TOPLEFT", UIParent, "TOPLEFT", leftTracker + width - 20,  topTracker)					
				end
			else
				ObjectiveTrackerFrame.HeaderMenu:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left + width - 20,  top - 15)	
			end
		end
		
		if SmallFrameBkg then
			SmallFrameBkg:SetAlpha(1)
		end
	end
	
	-----Model viewer
	-- MV.Frame.moving
	if DugisGuideViewer.Modules.ModelViewer then
		local MV = DugisGuideViewer.Modules.ModelViewer
		if MV.Frame then
			local width = MV.Frame:GetWidth()
			if DGV:UserSetting(DGV_LOCKMODELFRAME) then 
				if not InCombatLockdown() then
					MV.Frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left - width + 7, top)
				end
			end
		end
	end
	
	--Checking if only small frame is visible. If that is the case then an extra header button should be shown
	if SmallFrame then
		SmallFrame.UpdateSmallFrameHeader()
		SmallFrame.UpdateProgressBarPosition()
	end
end

function WF:OnBeforeEssentialModeActive()
	local SmallFrame = GetSmallFrame()
		
	if SmallFrame and not DGV:IsSmallFrameFloating() then
		WF.objectiveTrackerX, WF.objectiveTrackerY = GUIUtils:GetRealFeamePos(SmallFrame.Frame)
		WF.objectiveTrackerX, WF.objectiveTrackerY = WF.objectiveTrackerX + 40 , WF.objectiveTrackerY - 15
	end
end

function WF:RestoreOriginalObjectiveTrackerPosition()
	ObjectiveTrackerFrame:ClearAllPoints()
	ObjectiveTrackerFrame:SetPoint("TOPRIGHT", MinimapCluster, "BOTTOMRIGHT", -10, 0)
	ObjectiveTrackerFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -10, 85)
	
	ObjectiveTrackerFrame.HeaderMenu:ClearAllPoints()
	ObjectiveTrackerFrame.HeaderMenu:SetPoint("TOPRIGHT", ObjectiveTrackerFrame, "TOPRIGHT", 0, 0)	
end

function WF:OnBeforePluginOff()
	if not DGV:IncompatibleAddonLoaded() then
		WF:RestoreOriginalObjectiveTrackerPosition()
	end
end

function WF:OnBeforeObjectiveTrackerOriginal()
	WF:RestoreOriginalObjectiveTrackerPosition()
end

function WF:UpdateWatchFrameMovable()
	if DugisGuideViewer:UserSetting(DGV_DISABLEWATCHFRAMEMOD) then 
		ObjectiveFrameDugiBkg:EnableMouse(false)
	else 
		ObjectiveFrameDugiBkg:EnableMouse(true)
	end
		
	local SmallFrame = GetSmallFrame()
		
	if SmallFrame then
		SmallFrame.Frame:EnableMouse(not DugisGuideViewer:UserSetting(DGV_LOCKSMALLFRAME))
		SmallFrame.collapseHeader:EnableMouse(not DugisGuideViewer:UserSetting(DGV_LOCKSMALLFRAME))
		if DugisSmallFrameStatus1 then
			DugisSmallFrameStatus1:EnableMouse(not DugisGuideViewer:UserSetting(DGV_LOCKSMALLFRAME))
		end
	end
end   

function WF:Initialize()  
	if WF.initialized then return end
	WF.initialized = true
  
    function WF:ResetWatchFrameMovable()
        WF:DelayUpdate()
	end    
    

	local flashGroup, flash
	local L, RegisterFunctionReaction, RegisterMemberFunctionReaction = DugisLocals, DGV.RegisterFunctionReaction, DGV.RegisterMemberFunctionReaction
	
	function WF:ShouldModWatchFrame(forceLoaded)
		if forceLoaded then return true end
		return (WF.loaded or forceLoaded)
	end

	function WF:Reset()
	end
	
    function GetLastWorldQuestBlock()
        local bottomBlock = nil
        local top = 100000
         
        for k, v in pairs(WORLD_QUEST_TRACKER_MODULE.usedBlocks) do
            if (v:GetTop() and v:GetTop() < top)  or (v:GetBottom() and v:GetBottom() < top)then
                bottomBlock = v
                top = v:GetTop()
            end
        end
         
        return bottomBlock
    end
    
	local function GetBottomElement()
		if GetNumTrackedAchievements() > 0 then 
			return ACHIEVEMENT_TRACKER_MODULE.lastBlock
		elseif C_Scenario.GetInfo() then 
            if ObjectiveTrackerBlocksFrame.QuestHeader.module.lastBlock == nil then
                return ACHIEVEMENT_TRACKER_MODULE.lastBlock
            end
			return ObjectiveTrackerBlocksFrame.QuestHeader.module.lastBlock
        elseif GetLastWorldQuestBlock() then
            return GetLastWorldQuestBlock()
        else
			return BONUS_OBJECTIVE_TRACKER_MODULE.firstBlock or ObjectiveTrackerBlocksFrame.QuestHeader.module.lastBlock or ObjectiveTrackerBlocksFrame
		end
	end
	
	function GetWorldQuestRealHeight()
		local lastBlock = GetBottomElement()
		if lastBlock then
			local height = lastBlock:GetHeight()
			local top = (GetScreenHeight()  - lastBlock:GetTop())
			local ObjectiveTrackerFrame_top = (GetScreenHeight()  - ObjectiveTrackerFrame:GetTop())
			local realHeight = top -  ObjectiveTrackerFrame_top + height
			return realHeight
		end
	end
	
	local firstTime = true
	function WF:DelayUpdate()
		if DugisGuideViewer:IsModuleRegistered("SmallFrame") then 
			DGV:OnWatchFrameUpdate() 
			if firstTime then
				LuaUtils:Delay(2, function()
					DGV:OnWatchFrameUpdate() 
				end)
			end
			firstTime = false
		else
			LuaUtils:Delay(2, function()
				if DugisGuideViewer:IsModuleRegistered("SmallFrame") then 
					DGV:OnWatchFrameUpdate() 
				end
			end)
		end
	end

	local objectiveTrackerUpdateReaction--, manageFramePositionsReaction
	function WF:Load()
		objectiveTrackerUpdateReaction = RegisterFunctionReaction("ObjectiveTracker_Update", nil, function()
			WF.DelayUpdate()
			if DugisGuideViewer.NamePlate and DugisGuideViewer.NamePlate.OnObjectiveTracker_Update then
				DugisGuideViewer.NamePlate:OnObjectiveTracker_Update()
			end
		end)
	end

	function WF:Unload()
		objectiveTrackerUpdateReaction:Dispose()
	end
	
	if IsAddOnLoaded("DBM-Core") and DugisGuideViewer:GuideOn() and DugisGuideViewer.chardb.EssentialsMode ~= 1 then 
		hooksecurefunc(DBM, "StartCombat", function()
			DGV:OnDBMUpdate()
		end)	
		hooksecurefunc(DBM, "EndCombat", function()
			DGV:OnDBMUpdate()
		end)		
	end
end