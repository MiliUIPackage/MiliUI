local DGV = DugisGuideViewer
if not DGV then return end

local CarboniteVersion = "0"

local IsLegion = select(4, GetBuildInfo()) >= 70000
local IsLegionPatch = select(4, GetBuildInfo()) >= 70100

if DugisGuideViewer.carboniteloaded then
	CarboniteVersion = GetAddOnMetadata("Carbonite", "Version"):match("^([%d.]+)");
end

local HBD = LibStub("HereBeDragons-2.0-Dugis")
local pins = LibStub("HereBeDragons-Pins-2.0-Dugis")

local DugisArrow, L = DGV:RegisterModule("DugisArrow"), DugisLocals
DugisArrowGlobal = DugisArrow 

local MinimumRecalculateRoutes_sec = 15

DugisArrow.essential = true
local _
local InCombatLockdown, DoOutOfCombat = InCombatLockdown, DGV.DoOutOfCombat
local BeginAutoroutine, InterruptAutoroutine, YieldAutoroutine, GetRunningAutoroutine, RegisterReaction, RegisterMemberFunctionReaction, tPool, DebugPrint = 
	DGV.BeginAutoroutine, DGV.InterruptAutoroutine, DGV.YieldAutoroutine, DGV.GetRunningAutoroutine, DGV.RegisterReaction, DGV.RegisterMemberFunctionReaction, DGV.tPool, DGV.DebugPrint

        
local function CreateArrowFrame()
	if not DugisArrowFrame then
		CreateFrame("Button", "DugisArrowFrame", UIParent)
		DugisArrowFrame:SetFrameStrata("LOW")
		DugisArrowFrame:EnableMouse(true)
		DugisArrowFrame:SetMovable(true)
		DugisArrowFrame:SetUserPlaced(true)
		DugisArrowFrame.arrow = DugisArrowFrame:CreateTexture("BACKGROUND")
		DugisArrowFrame.arrow:SetColorTexture(0,0,0,1);
		DugisArrowFrame.button = CreateFrame("Button", "DugisArrowActionButton", UIParent, "SecureActionButtonTemplate")
		DugisArrowFrame.button:SetFrameStrata("LOW")
		DugisArrowFrame.button:SetFrameLevel(2)
		DugisArrowFrame.button:SetNormalTexture("Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\IconBorder")
		DugisArrowFrame.button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
		DugisArrowFrame.button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
		DugisArrowFrame.button.texture = DugisArrowFrame.button:CreateTexture(nil, "ARTWORK")
		DugisArrowFrame.button.texture:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
		DugisArrowFrame.button.texture:SetAllPoints(DugisArrowFrame.button)
		DugisArrowFrame.button.background = DugisArrowFrame.button:CreateTexture(nil, "BACKGROUND")
		DugisArrowFrame.button.background:SetColorTexture(0,0,0)
		DugisArrowFrame.button.background:SetPoint("CENTER", DugisArrowFrame.button)
		DugisArrowFrame.button.background:SetHeight(48)
		DugisArrowFrame.button.background:SetWidth(48)
		DugisArrowFrame.button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        
        local noRouteButton = GUIUtils:AddButton(DugisArrowFrame, "", 0, 0, 48, 48, 48, 48, function()  end, "Interface\\Icons\\INV_Misc_Map_01", "Interface\\Icons\\INV_Misc_Map_01", 
        "Interface\\Icons\\INV_Misc_Map_01"
        , false)
        
        noRouteButton.button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        
        noRouteButton.button:SetScript("OnEnter", function()
            local filename, _, _ = GameTooltipTextLeft1:GetFont()
            DugisArrowTooltipTextLeft1:SetFont(filename, 11)
                
            DugisArrowTooltip:SetOwner(DugisArrowFrame, "ANCHOR_TOPLEFT")
            DugisArrowTooltip:AddLine(L["Waypoint arrow not available. Click here to check the world map"], 1, 1, 1, 1, true)

            DugisArrowTooltip:Show()
            DugisArrowTooltip:ClearAllPoints()
            DugisArrowTooltip:SetPoint("BOTTOMLEFT", DugisArrowFrame, "BOTTOMRIGHT", 10, 0)
        end)
        
        noRouteButton.button:SetScript("OnLeave", function()
            DugisArrowTooltip:Hide()
        end) 
        

        noRouteButton.button:SetMovable(true)
        
        DugisArrowFrame.noRouteButton = noRouteButton
        
		DugisArrowFrame.progress = DugisProgressIcon
		DugisProgressIcon:SetScript("OnMouseUp", function(_, button)
			if button == "RightButton" then
				DugisArrow.WayFrame_OnClick()
			end
		end)
		
		DugisArrowFrame.progress:SetPoint("CENTER", DugisArrowFrame)
		--DugisArrowFrame.button:SetPoint("CENTER", 0, 35)
		DugisArrowFrame.progress:Hide()
		DugisArrowFrame.button:Hide()
		DugisArrowFrame:Hide()
	end
	return DugisArrowFrame
end
CreateArrowFrame()

function DugisArrow:GetBadColor()
	return DugisGuideUser.DGV_BAD_COLOR or DugisGuideViewer.defaultBadArrowColor
end

function DugisArrow:GetMiddleColor()
	return DugisGuideUser.DGV_MIDDLE_COLOR or DugisGuideViewer.defaultMiddleArrowColor
end

function DugisArrow:GetGoodColor()
	return DugisGuideUser.DGV_GOOD_COLOR or DugisGuideViewer.defaultGoodArrowColor
end

function DugisArrow:GetExactColor()
	return DugisGuideUser.DGV_EXACT_COLOR or DugisGuideViewer.defaultExactArrowColor
end

function DugisArrow:GetQuestingAreaColor()
	return DugisGuideUser.DGV_QUESTING_AREA_COLOR or DugisGuideViewer.defaultQuestingAreaColor
end

function DugisArrow:Initialize()
	DGV.DugisArrow = DugisArrow

	DGV.WaypointsShown = true

	DugisArrow.CLASSIC_UP 	= "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\ArrowsC"
	DugisArrow.CLASSIC_DOWN = "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\ArrowsC-Down"
	DugisArrow.MODERN_UP 	= "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\Arrows"
	DugisArrow.MODERN_DOWN 	= "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\Arrows-Down"
	DugisArrow.STAIRS	= "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\stair"
    DugisArrow.NOROUTE	= "Interface\\Icons\\INV_Misc_Map_01"

	local DADEFAULT = {}
	DADEFAULT["arrow"]			= true
	DADEFAULT["point"]			= "CENTER"
	DADEFAULT["relativePoint"]	= "CENTER"
	DADEFAULT["arrow_pos_x"]	= 0
	DADEFAULT["arrow_pos_y"]	= 300
	DADEFAULT["arrow_locked"]	= false
	DADEFAULT["gps_locked"]	    = false
	DADEFAULT["arrow_size"]		= 1
	DADEFAULT["arrow_textsize"]	= 1	
    
    DugisArrow.foundRoute = true

	local OnUpdate

	local index, waypoint

	local function InterpolateTwoColors(n, r1, g1, b1, r2, g2, b2)
		return LuaUtils.inOutQuad(n, r1, r2), LuaUtils.inOutQuad(n, g1, g2), LuaUtils.inOutQuad(n, b1, b2)
	end 
	
	--normalizedDirection has values from 0 to 1. 1 for excelent direction. 0 for oposite/very bad direction
	local function ColorGradient(normalizedDirection)
		local gradientTable = {} 
		gradientTable[1] = DugisArrow:GetBadColor()
		gradientTable[2] = DugisArrow:GetMiddleColor()
 		gradientTable[3] = DugisArrow:GetGoodColor()
		gradientTable[4] = DugisArrow:GetExactColor()
		
		local directionRanges = { {0, 0.3333}, {0.3333, 0.95}, {0.95, 1} }
		
		local color1, color2
		local interpolation

		LuaUtils:foreach(directionRanges, function(range, index)
			local v1 = range[1]
			local v2 = range[2]
			if normalizedDirection >= v1 and normalizedDirection < v2 then
				color1 = gradientTable[index]
				color2 = gradientTable[index + 1]
				interpolation = (normalizedDirection - v1) / (v2 - v1)
			end
		end)
		
		local r1, g1, b1 = unpack(color1)
		local r2, g2, b2 = unpack(color2)
		
		--if normalizedDirection > 0.98 then
		--	return unpack(DugisArrow:GetExactColor())
		--end
		
		return InterpolateTwoColors(interpolation, r1, g1, b1, r2, g2, b2)
	end

	local wayframe = CreateArrowFrame()

	DugisGuideViewer.wayframe = wayframe
	
	local titleframe = DugisArrowTitleFrame
	if not titleframe then
		titleframe = CreateFrame("Frame", "DugisArrowTitleFrame", wayframe)
		wayframe.title = titleframe:CreateFontString("OVERLAY", nil, "GameFontHighlightSmall")
        wayframe.title:SetWidth(400)
        
		wayframe.status = titleframe:CreateFontString("OVERLAY", nil, "GameFontNormalSmall")
		wayframe.tta = titleframe:CreateFontString("OVERLAY", nil, "GameFontNormalSmall")
		wayframe.title:SetPoint("TOP", wayframe, "BOTTOM", 0, 0)
		wayframe.status:SetPoint("TOP", wayframe.title, "BOTTOM", 0, 0)
		wayframe.tta:SetPoint("LEFT", wayframe.status, "RIGHT", 0, 0)
	end
	
	local lfgFrame = DugisArrowLFGFrame
	local function GetCreateArrowLFGFrame()
		if not lfgFrame then
			lfgFrame = CreateFrame("Frame", "DugisArrowLFGFrame", DugisArrowFrame, "DugisArrowLFGFrameTemplate")
			lfgFrame:EnableMouse(true)
			lfgFrame:SetMovable(true)
			lfgFrame:SetUserPlaced(true)
			lfgFrame:SetPoint("LEFT", DugisArrowFrame, "RIGHT")
			lfgFrame.button:SetFrameStrata("TOOLTIP")
			lfgFrame:Hide()
		end
		return lfgFrame
	end

	local default_font_name, default_font_size, default_font_flags = wayframe.title:GetFont()

	local function OnDragStart(self, button)
		if InCombatLockdown() then
			return
		end
		
		local isGPSShown = GPSArrowScroll:GetAlpha() ~= 0 and GPSArrow:IsShown()
	
		if DGV:UserSetting(DGV_GPS_MERGE_WITH_DUGI_ARROW) then
			if isGPSShown and DugisArrow:GetSetting("gps_locked") then
				return
			end
			if not isGPSShown and DugisArrow:GetSetting("arrow_locked") then
				return
			end
		else
			if DugisArrow:GetSetting("arrow_locked") then
				return
			end
		end
		
		DugisArrowFrame.button:SetPoint("TOPLEFT", DugisArrowFrame,  15, 0)
		wayframe.moving = true
		DugisArrowFrame:StartMoving()
	end

	local function OnDragStop(self, button)
		DugisArrowFrame:StopMovingOrSizing()
		if not InCombatLockdown() then
			local point, relativeTo, relativePoint, xOfs, yOfs = wayframe:GetPoint()
			DugisArrow:SetSetting("point", point)
			DugisArrow:SetSetting("relativePoint", relativePoint)
			DugisArrow:SetSetting("arrow_pos_x", xOfs)
			DugisArrow:SetSetting("arrow_pos_y", yOfs)
			wayframe.moving = false
			
			if DugisGuideViewer.Modules.GPSArrowModule then
				DugisGuideViewer.Modules.GPSArrowModule.FixTopPosition()
			end
		end
	end
	
	local function OnActionButtonDragStart()
		if not InCombatLockdown() then
			OnDragStart(wayframe)
		end
	end
	
	local function OnActionButtonDragStop(force)
		if not InCombatLockdown() or force then
			OnDragStop(wayframe)
		end
	end
	
	wayframe.OnActionButtonDragStop = OnActionButtonDragStop

	wayframe:SetScript("OnDragStart", OnDragStart)
	wayframe:SetScript("OnDragStop", OnDragStop)
	wayframe:RegisterForDrag("LeftButton")
	wayframe.button:SetScript("OnDragStart", OnActionButtonDragStart)
	wayframe.button:SetScript("OnDragStop", OnActionButtonDragStop)
	wayframe.button:RegisterForDrag("LeftButton")
	wayframe.arrow = wayframe:CreateTexture("OVERLAY")
	wayframe.arrow:SetAllPoints()
	local status = wayframe.status
	local tta = wayframe.tta
	local arrow = wayframe.arrow

	local active_point, arrive_distance, showDownArrow, point_title
	active_point = {}
	
	function DugisArrow:GetActivePoint()
		return active_point
	end
	
	local function UseTomTomArrow()
		return DGV:UserSetting(DGV_TOMTOMARROW) and DGV.tomtomloaded
	end
	
	local function UseCarboniteArrow()
		return DGV:UserSetting(DGV_CARBONITEARROW) and DGV.carboniteloaded and Nx.Map
	end

	local function SetUseItemByQID(questId)
		DGV:SetUseItemByQID(questId)
	end	

	function DugisArrow:Show()
		if not DugisArrow.waypoints then return end
		wayframe:SetClampedToScreen(true);
		if not wayframe.moving then
			wayframe:SetPoint(DugisArrow:GetSetting("point"), nil, DugisArrow:GetSetting("relativePoint"),  DugisArrow:GetSetting("arrow_pos_x"), DugisArrow:GetSetting("arrow_pos_y"))
		end

		if DugisGuideViewer:UserSetting(DGV_DUGIARROW) and not UseTomTomArrow() and not UseCarboniteArrow() then
			wayframe:Show()
			if DGV.Modules.GPSArrowModule then
				DGV.Modules.GPSArrowModule.UpdateVisibility()
			end
		end
	end
	
	local function HideDugiWayframe()
		local waypoints = DugisArrow.waypoints
		if not waypoints or #waypoints<1 then 	
			wayframe:Hide()
			if DGV.Modules.GPSArrowModule then
				DGV.Modules.GPSArrowModule.UpdateVisibility()
			end
			wayframe.button:Hide()
		end
	end

	function DugisArrow:Hide()
		local waypoints = DugisArrow.waypoints
		if not waypoints or #waypoints<1 then 
			DoOutOfCombat(HideDugiWayframe)
		end
	end
	
	local function ShouldShowStairs()
		--return DugisGuideViewer.WrongInstanceFloor or --Don't really need anymore
		--	(active_point.waypoint and 
		--		(active_point.waypoint.cue=="upstairs" or active_point.waypoint.cue=="downstairs"))
	end
    
	local function WayFrame_OnClick(self, button)
		local menu = DugisGuideViewer.ArrowMenu:CreateMenu("wayframe_menu")
		DugisGuideViewer.ArrowMenu:CreateMenuTitle(menu, L["Dugi Arrow"])

		DugisArrow:PopulateMenu(menu)

		menu:ShowAtCursor()
	end   

	DugisArrow.WayFrame_OnClick = WayFrame_OnClick

	function DugisArrow:setArrowTexture( )
		local setTexture
		if ShouldShowStairs() then
			setTexture = DugisArrow.STAIRS
			arrow:SetTexCoord(0,1,0,1)
			arrow:SetVertexColor(1,1,1,1)
		else
		  if DugisGuideViewer:UserSetting(DGV_CLASSICARROW) then
				DugisArrow.arrowTexture = DugisArrow.CLASSIC_UP
				DugisArrow.arrowDownTexture = DugisArrow.CLASSIC_DOWN
			else
				DugisArrow.arrowTexture = DugisArrow.MODERN_UP
				DugisArrow.arrowDownTexture = DugisArrow.MODERN_DOWN
			end

			if showDownArrow then 
                setTexture = DugisArrow.arrowDownTexture 
            else 
                setTexture = DugisArrow.arrowTexture 
            end
		end
        
        if not DugisArrow.foundRoute then
            setTexture = DugisArrow.NOROUTE
			DugisArrow:SetScale()
            arrow:SetTexCoord(0,1,0,1)
            DugisArrowFrame.arrow:SetVertexColor(1,1,1)
       
            if not wayframe.progress:IsShown() and not DugisArrowActionButton:IsShown() then
                DugisArrowFrame.noRouteButton.button:Show()
            end
            DugisArrowFrame.noRouteButton.button:SetScript("OnDragStart", OnDragStart)
            DugisArrowFrame.noRouteButton.button:SetScript("OnDragStop", OnDragStop)
            DugisArrowFrame.noRouteButton.button:RegisterForDrag("LeftButton")
           
            DugisArrowFrame.noRouteButton.button:SetScript("OnClick", function(self, button)
                if button=="RightButton" then
                    WayFrame_OnClick(wayframe, button)
                end
                
                if button == "LeftButton" then
                    WorldMapFrame:Show()
                    
                    local firstWaypoint = DugisArrow:getFirstWaypoint()
                    
                    if firstWaypoint and firstWaypoint.map then
						LuaUtils:DugiSetMapByID(firstWaypoint.map)
                        DGV:UpdateMapPingForNoRoutePath()
                    end
                end
            end)
        else
            DugisArrowFrame.noRouteButton.button:Hide()
        end        

		if setTexture ~= DugisArrow.currentTexture then
			arrow:SetTexture(setTexture)
			DugisArrow.currentTexture = setTexture
			DugisArrow:SetScale()
		end
		if not wayframe.arrow:IsShown() and
			not wayframe.button:IsShown() and
			not wayframe.progress:IsShown() and
			DugisArrow:getNumWaypoints() > 0 then 
			DugisArrow:WaypointsChanged()
		end
	end

	--Waypoint 1



	local DESCRIPTION_FORMAT = L["Waypoint %d"]
	local DESCRIPTION_PATTERN = L["Waypoint (%d+)"]
	local function GetNextManualWaypointDescription()
		local highest = 0
		if DugisArrow.waypoints then
			for k, v in ipairs(DugisArrow.waypoints) do
				if v.desc then
					local match = v.desc:match(DESCRIPTION_PATTERN)
					if match then
						local num = tonumber(match)
						highest = math.max(highest, num)
					end
				end
			end
		end
		return string.format(DESCRIPTION_FORMAT, highest+1)
	end
	
	local function point_OnClick(self, button)
		local point = self.point
		local menu = DugisGuideViewer.ArrowMenu:CreateMenu("point_menu")
		DugisGuideViewer.ArrowMenu:CreateMenuTitle(menu, point.desc)
		local remove = DugisGuideViewer.ArrowMenu:CreateMenuItem(menu, L["Remove Waypoint"])
		remove:SetFunction(function () DugisArrow:SetNextWaypoint(point)  end)
		local removeAll = DugisGuideViewer.ArrowMenu:CreateMenuItem(menu, L["Remove All Waypoints"])
		removeAll:SetFunction(function () DugisGuideViewer:RemoveAllWaypoints()  end)
		menu:ShowAtCursor()
	end

	do
		if not DugisArrowTooltip then
			local tooltip = CreateFrame("GameTooltip", "DugisArrowTooltip", UIParent, "GameTooltipTemplate")
			tooltip:SetFrameStrata("TOOLTIP")
		end
	end

	local function arrow_OnEnter(self, button)
		if DugisGuideViewer.WrongInstanceFloor then
			DugisArrowTooltip:SetParent(self)
			DugisArrowTooltip:SetOwner(self, "ANCHOR_CURSOR")
			DugisArrowTooltip:AddLine(L["Waypoint is on a different floor"])
			DugisArrowTooltip:Show()
		end
	end

	local function arrow_OnLeave(self, button)
		DugisArrowTooltip:Hide()
	end

	do
		local tooltip = CreateFrame("GameTooltip", "DugisWaypointTooltip", UIParent, "GameTooltipTemplate")
		tooltip:SetFrameStrata("TOOLTIP")
	end

	local function point_OnEnter(self, button)
		if UIParent:IsVisible() then
			DugisWaypointTooltip:SetParent(UIParent)
		else
			DugisWaypointTooltip:SetParent(self)
		end

		DugisWaypointTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
		DugisWaypointTooltip:AddLine(string.format("%s (%.2f, %.2f)", self.point.desc or "", self.point.x or 0, self.point.y or 0))
		DugisWaypointTooltip:Show()
	end

	local function point_OnLeave(self, button)
		DugisWaypointTooltip:Hide()
	end
	
	local pointCache
	local function GetCreatePoint()
		if not pointCache then pointCache = UIFrameCache:New("Button", "DugisArrowMapPoint", DugisMapOverlayFrame) end
		local worldpoint = pointCache:GetFrame()
		worldpoint:RegisterForClicks("RightButtonUp")
		worldpoint:SetScript("OnClick", point_OnClick)
		worldpoint:SetScript("OnEnter", point_OnEnter)
		worldpoint:SetScript("OnLeave", point_OnLeave)
		if not worldpoint.icon then
			worldpoint.icon = worldpoint:CreateTexture("ARTWORK")
			worldpoint.icon:SetAllPoints()
		end
		worldpoint.icon:Show()

		return worldpoint
	end	
    
	local GPSArrowPointCache
	local function GetCreateGPSArrowPoint()
		if GPSArrow then
			if not GPSArrowPointCache then GPSArrowPointCache = UIFrameCache:New("Button", "DugisArrowBattlefieldMapDDPoint", GPSArrow.map_overlay) end
		end
		local worldpoint = GPSArrowPointCache:GetFrame()
        
		if GPSArrow then
			worldpoint:SetFrameStrata(GPSArrow.map_overlay:GetFrameStrata())
			worldpoint:SetFrameLevel(GPSArrow.map_overlay:GetFrameLevel()  )
		end
		worldpoint:RegisterForClicks("RightButtonUp")
		worldpoint:SetScript("OnClick", point_OnClick)
		worldpoint:SetScript("OnEnter", point_OnEnter)
		worldpoint:SetScript("OnLeave", point_OnLeave)
		if not worldpoint.icon then
			worldpoint.icon = worldpoint:CreateTexture()
			worldpoint.icon:SetAllPoints()
		end
		worldpoint.icon:Show()

		return worldpoint
	end

	local miniPointCache
	local function GetCreateMinimapPoint()
		if not miniPointCache then miniPointCache = UIFrameCache:New("Button", "DugisArrowMinimapPoint", DugisMinimapOverlayFrame) end
		local minipoint = miniPointCache:GetFrame()
		minipoint:RegisterForClicks("RightButtonUp")
		minipoint:SetScript("OnClick", point_OnClick)
		minipoint:SetScript("OnUpdate", DugisArrow.Minimap_OnUpdate)
		minipoint:SetScript("OnEnter", point_OnEnter)
		minipoint:SetScript("OnLeave", point_OnLeave)

		if not minipoint.icon then
			minipoint.icon = minipoint:CreateTexture("ARTWORK")
			minipoint.icon:SetAllPoints()
		end

		if not minipoint.arrow then
			minipoint.arrow = minipoint:CreateTexture("BACKGROUND")
			minipoint.arrow:SetTexture("Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\TrackingArrow")
			minipoint.arrow:SetPoint("CENTER", 0 ,0)
			minipoint.arrow:SetHeight(40)
			minipoint.arrow:SetWidth(40)
		end
		
		minipoint.arrow:Hide()
		minipoint.icon:Show()
        
        if not minipoint.GetName_org then
            minipoint.GetName_org = minipoint.GetName
            minipoint.GetName = function()
            
                local stack = debugstack()
                local isCalledByMinimapButtonFrameAddon = (string.find(stack, "MinimapButtonFrame") ~= nil)
                
                --To prevent MinimapButtonFrame addon anchoring waypoints
                if isCalledByMinimapButtonFrameAddon then
                    return "ActionBar"
                else
                    return minipoint:GetName_org()
                end
                
            end
        end

		return minipoint
	end
	
	function DugisArrow:FinalizeWaypointIcon() 
		DugisGuideUser.FinalizeWaypoint = true
		local waypoint = DugisArrow:getFinalWaypoint()
		if waypoint then 
			RemoveWaypointAt(DugisArrow:getNumWaypoints())	
			DugisArrow:AddWaypoint(waypoint.map, waypoint.floor, waypoint.x, waypoint.y, waypoint.desc, waypoint.guideIndex, waypoint.questId, waypoint.isRouteDestination, waypoint.isWTag)
		end
	end
	
	local recalculationQueue, recalculationPoints
	local function InterruptRecalculation()
		if recalculationQueue then
			while #recalculationQueue>0 do
				recalculationQueue:Remove(1):Pool()
			end
			recalculationQueue:Pool()
			recalculationQueue = nil
		end
		if recalculationPoints then
			while #recalculationPoints>0 do
				recalculationPoints:Remove(1):Pool()
			end
			recalculationPoints:Pool()
			recalculationPoints = nil
		end
		InterruptAutoroutine("RecalculateRoutes")
	end
	
	local function SetGPSArrowPointPos(point, x, y)
		point.GPSArrowPoint:ClearAllPoints()
		point.GPSArrowPoint:SetPoint("CENTER", GPSArrow.map_overlay, "TOPLEFT", x,  y)	
	end
	
	local function PlaceWaypoint(point)
		local mapID, _, x, y, desc = point.map, point.floor, point.x, point.y, point.desc
		local mapFloor = UiMapId2Floor(mapID)
        if not x then return end
		point.worldmap = GetCreatePoint()
		point.minimap = GetCreateMinimapPoint()
		
		if GPSArrow then
			point.GPSArrowPoint = GetCreateGPSArrowPoint()
		end
		point.minimap.point = point
		point.worldmap.point = point
		
		if GPSArrow then
			point.GPSArrowPoint.point = point
		end

		local texture, worldmapSize, minimapSize, lastWaypoint, isCircular, isWTag, skip
		local guideIndex = DugisGuideUser.WaypointGuideIndex		
		local virtual = 0
		
		if guideIndex and DugisGuideViewer:GuideOn() and DugisGuideViewer.chardb.EssentialsMode ~= 1 and DGV:isValidGuide(CurrentTitle) and DugisGuideViewer.tags then 
			if #DGV:getCoords(guideIndex) == 1 and not DugisGuideUser.FinalizeWaypoint then 
				virtual = 1 
			end
			lastWaypoint = #DGV:getCoords(guideIndex) - 1 + DugisArrow:GetTotalRouteWaypoints()
			local tag = DugisGuideViewer.tags[guideIndex]
			if tag then
				isWTag = tag:match("(|LOOP|)")~=nil
				isCircular = tag:match("(|W|)")~=nil
			end
		end --need this for single waypoints with routes. 
		
		if isCircular and lastWaypoint and DugisArrow:getNumWaypoints() + virtual == lastWaypoint then
			--texture = DGV:getIcon(DGV.actions[guideIndex], guideIndex )
			texture = "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\circular"
			worldmapSize = 34
			minimapSize = 32
		elseif isWTag and lastWaypoint and DugisArrow:getNumWaypoints() + virtual == lastWaypoint then
			texture = "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\waypoint_g"
			worldmapSize = 18.5
			minimapSize = 16.5
		else
			texture = "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\waypoint"
			worldmapSize = 18.5
			minimapSize = 16.5
		end
		point.worldmap.icon:SetTexture(texture)
		point.worldmap.icon:SetDrawLayer("ARTWORK", 5)
		local alpha = (GetCurrentMapDungeonLevel_dugi()~=mapFloor and .5) or 1
		point.worldmap.icon:SetAlpha(alpha)
		point.worldmap:Show()
		point.worldmap:SetHeight(worldmapSize)
		point.worldmap:SetWidth(worldmapSize)
		point.worldmap.baseSize = worldmapSize

		function point:UpdateSize()
			self.worldmap:SetWidth(self.worldmap.baseSize)
			self.worldmap:SetHeight(self.worldmap.baseSize)
		end
		
		point:UpdateSize()
        
        if GPSArrow then
			point.GPSArrowPoint.icon:SetTexture(texture)
		end
		
		local alpha = (GetCurrentMapDungeonLevel_dugi()~=mapFloor and .5) or 1
		
		if GPSArrow then
			point.GPSArrowPoint.icon:SetAlpha(1)
			point.GPSArrowPoint:Show()
			point.GPSArrowPoint:SetHeight(16 / (GPSArrow.scale or 1))
			point.GPSArrowPoint:SetWidth(16 / (GPSArrow.scale or 1))
		end
        
		point.minimap.icon:SetTexture(texture)
		point.minimap.icon:SetAlpha(alpha)
		

		point.minimap:SetHeight(minimapSize)
		point.minimap:SetWidth(minimapSize)

		if not DugisArrow.waypoints then
			DugisArrow.waypoints = {}
		end
		table.insert(DugisArrow.waypoints, point)

		--DebugPrint("Point placed at x:"..x.."y:"..y.."mapID"..mapID)
		if DugisGuideViewer.WaypointsShown and not UseCarboniteArrow() then
			DugisGuideViewer:PlaceIconOnWorldMap( WorldMapButton, point.worldmap, mapID, mapFloor, x/100, y/100 )
            
			if GPSArrow then
				local w, h = GPSArrow.map_overlay:GetWidth(), -GPSArrow.map_overlay:GetHeight()
				SetGPSArrowPointPos(point, (x/100) * w,  (y/100) * h)
			end
            
			DugisGuideViewer:PlaceIconOnMinimap( point.minimap, mapID, mapFloor, x/100, y/100 )
		end
		
		if UseCarboniteArrow() then
			if CarboniteVersion > "5.4.0" then
				if Nx.db.profile.Map.RouteUse then Nx.db.profile.Map.RouteUse = false end
			else
				if Nx.Travel.GOpts and Nx.Travel.GOpts["MapRouteUse"] then Nx.Travel.GOpts["MapRouteUse"] = false end
			end
			
			local opts = {}
			local map = Nx.Map:GetMap (1)
			local wx, wy = map:GetWorldPos (mapID, x, y)
			
			opts.title = desc
			point.carbonite = map:SetTarget ("Goto", wx, wy, wx, wy, nil, nil, opts.title or "", true, mapID)
			DugisArrowFrame.progress:SetPoint("CENTER", NxHUD, 0, -43)
			if mapFloor and mapFloor > 0 then 
				UIErrorsFrame:AddMessage("Warning! waypoint might be inaccurate\nIndoor map is not supported by Carbonite",1,0,0,1) 
				PlaySoundFile("sound\\interface\\magicclick.ogg")
			end
			
		elseif UseTomTomArrow() then
			local opts = {}
			opts.title = desc
			point.tomtom = TomTom:AddMFWaypoint(mapID, mapFloor, x/100, y/100, opts)
		end
		
		
		if UseTomTomArrow() then
			local first = DugisArrow:getFirstWaypoint()
			TomTom:SetCrazyArrow(  first.tomtom, 5, first.desc )
		elseif not UseTomTomArrow() and not UseCarboniteArrow() and DugisArrow:getNumWaypoints() == 1 then
			DugisArrow:setArrow( point.map, point.floor, point.x, point.y, point.desc, point )
		end

        DGV:UpdateMapPingForNoRoutePath()
        
		DugisArrow:WaypointsChanged()
		return point
	end
	
	function DugisArrow:OnMapChanged() 
		LuaUtils:foreach(DugisArrow.waypoints or {}, function(waypoint)
			waypoint:UpdateSize()
		end)
	end
	
	local function AddWaypoint(mapID, x, y, desc)
		if DGV.currentAutoroutine and DGV.currentAutoroutine.key=="RecalculateRoutes" then
			local point = DGV.GetCreateTable()
			point.desc = desc
			
            
			point.map = mapID
			point.floor = mapFloor
			point.x = x
			point.y = y
			if not recalculationPoints then
				recalculationPoints = DGV.GetCreateTable()
			end
			recalculationPoints:Insert(point)
			return point
		end
		
		local point = DGV.GetCreateTable()
		point.desc = desc
		
		point.map = mapID
		point.floor = mapFloor
		point.x = x
		point.y = y
		return PlaceWaypoint(point)
	end
	
	function DGV:AddRouteWaypoint(mapID, mapFloor, x, y, desc, cue)
		local point = AddWaypoint(mapID, (x or 0)*100, (y or 0)*100, desc)
		point.isRouteWaypoint = true
		point.cue = cue
		return point
	end
	
	function DGV:AddCorpseWaypoint(mapID, mapFloor, x, y, desc) -- prevents duplicates of "My Corpse" waypoints
		if DugisArrow:getNumWaypoints() > 0 then 
			for i = 1, #DugisArrow.waypoints do 
				if DugisArrow.waypoints[i] and (DugisArrow.waypoints[i].isCorpseWaypoint or DugisArrow.waypoints[i].desc == L["My Corpse"]) then 
					return
				end
			end 
		end		
		DGV:AddCorpseWaypointChecked(mapID, mapFloor, x, y, desc)	
	end
	
	function DGV:AddCorpseWaypointChecked(mapID, mapFloor, x, y, desc)
		local point = AddWaypoint(mapID, x*100, y*100, desc)
		point.isCorpseWaypoint = true
		return point
	end
	
	function DGV:AddRouteWaypointWithNoTrigger(mapID, x, y, desc)
		local point = DGV:AddRouteWaypoint(mapID, mapFloor, x, y, desc)
		point.noTrigger = true
		return point
	end
	
	function DGV:AddRouteWaypointWithDestinationTrigger(mapID, mapFloor, x, y, desc, destID)
		local point = DGV:AddRouteWaypoint(mapID, mapFloor, x, y, desc)
		point.destID = destID
		return point
	end
	
	function DGV:AddRouteWaypointWithItem(mapID, mapFloor, x, y, desc, itemID)
		local point = DGV:AddRouteWaypoint(mapID, mapFloor, x, y, desc)
		point.itemID = itemID
		return point
	end
	
	function DGV:AddRouteWaypointWithSpell(mapID, mapFloor, x, y, desc, spellID)
		local point = DGV:AddRouteWaypoint(mapID, mapFloor, x, y, desc)
		point.spellID = spellID
		return point
	end
	
	function DGV:AddRouteWaypointWithSpellRequirement(mapID, mapFloor, x, y, desc, spellID)
		local point = DGV:AddRouteWaypoint(mapID, mapFloor, x, y, desc)
		point.spellRequirement = spellID
		return point
	end
	
	function DGV:AddLFGTeleportWaypoint(mapID, mapFloor, x, y, desc)
		local point = DGV:AddRouteWaypoint(mapID, mapFloor, x, y, desc)
		point.isLFGTeleport = true
		point.destID = mapID
		return point
	end

    
    function DGV:AddCustomRouteWaypoint(x, y, desc, zoneNameOrId, mapFloor)
		local m,f = DGV:GetCurrentMapID()
     
		if m==-1 then m=0 end
		if zoneNameOrId then
			local id = DugisGuideViewer:GetZoneIdByName(zoneNameOrId)
       
			if id then m=id
			else
				m=zoneNameOrId
			end
		end
        
		if mapFloor then f=mapFloor end

		return DGV:AddRouteWaypoint( m, f, x, y, desc)
	end
    
	function DGV:AddCustomWaypoint(x, y, desc, zoneNameOrId, mapFloor, qid)
		local m,f = DGV:GetCurrentMapID()
		if m==-1 then m=0 end
		if zoneNameOrId then
			local id = DugisGuideViewer:GetZoneIdByName(zoneNameOrId)
			if id then m=id
			else
				m=zoneNameOrId
			end
		end
		if mapFloor then f=mapFloor end
		--DGV:DebugFormat("AddCustomWaypoint AddWaypoint", "args", {m, f, x*100, y*100, desc, nil, nil, qid})
		DugisArrow:AddWaypoint( m, f, x*100, y*100, desc, nil, qid, true)
		--if DugisArrow:getNumWaypoints() == 1 then
		--	DugisGuideViewer.DugisArrow:setArrow( m, f, x*100, y*100, desc)
		--end
	end

	function DGV:AddManualWaypoint(x, y, zoneNameOrId, mapFloor)
		if zoneNameOrId and not tonumber(zoneNameOrId) then
			zoneNameOrId = DGV:GetZoneIdByName(zoneNameOrId)
		end
		DGV:AddCustomWaypoint(x, y, GetNextManualWaypointDescription(), zoneNameOrId, mapFloor)
	end
	
	function DugisArrow:LocalCoordinate(m, f, x, y)
    
        local TaxiData = DugisGuideViewer.Modules.TaxiData
    
		--DGV:DebugFormat("LocalCoordinate", "args", {m, f, x, y})
		if m==-1 then return end
		local currentId,currentFloor = DGV:GetCurrentMapID()
		if currentId~=m then
			LuaUtils:DugiSetMapByID(m)
		end
        
        local positionMapInfo = C_Map.GetMapInfoAtPosition(m, x,y);	
        
		if currentId~=m then
			LuaUtils:DugiSetMapByID(currentId)
		end
		if positionMapInfo and positionMapInfo.mapID then
			local altId = positionMapInfo.mapID
			if altId then
				local altFloor = f
				if TaxiData.NonZeroOpenWorldFloors[altId] then
					altFloor=1
				end
				x,y = DGV:TranslateWorldMapPositionGlobal(
					m,x, y, 
					altId)
				m = altId
				f = altFloor
			end
		end
		--DGV:DebugFormat("LocalCoordinate", "actualMapName", actualMapName,  "return", {m, f, x, y})
		return m, f, x, y
	end
    
	function DugisMapOverlayFrame_OnMouseUp(self, ...)
		local mouseButton, button = ...
		if not DugisGuideViewer.tomtomloaded
			and not DugisGuideViewer.carboniteloaded
			and DGV:UserSetting(DGV_MANUALWAYPOINT)
			and (IsControlKeyDown() or IsShiftKeyDown())
		then
			if mouseButton == "RightButton" then
				local cX, cY = DugisGuideViewer:GetCurrentCursorPosition(DugisMapOverlayFrame)
				if IsControlKeyDown() then DugisGuideViewer:RemoveAllWaypoints() end
				local actualID = DGV:GetCurrentMapID()
                actualID, f, cX, cY = DugisArrow:LocalCoordinate(actualID, f, cX, cY)
				if not cY then return end
				DGV:AddManualWaypoint(cX, cY, actualID, f)
			elseif mouseButton == "LeftButton" then
				--[[if DGV.Modules.WorldMapTracking:ShowMenu(DugisMapOverlayFrame) then
					return
				end]]
                DugisArrow.old_WorldMapButtonOnClick(self, ...)
			end
		else
            DugisArrow.old_WorldMapButtonOnClick(self, ...)
		end
	end
--[[
    
	hooksecurefunc("QuestPOI_DisplayButton", function(parentName, buttonType, buttonIndex, questId)
		local poiButton = _G["poi"..tostring(parentName)..tostring(buttonType).."_"..tostring(buttonIndex)];
		local swapButton = _G["poi" .. parentName .. "_Swap"]

		if poiButton then poiButton:RegisterForClicks("AnyUp") end
		if swapButton then swapButton:RegisterForClicks("AnyUp") end
	end)


	hooksecurefunc("QuestPOI_SelectButton", function(poiButton)
		if ( not WorldMapFrame:IsShown() and (poiButton.type ~= QUEST_POI_COMPLETE_OUT) and DugisGuideViewer:GuideOn() == true ) then
			poiButton.selectionGlow:Show();
		end
	end)
]]	
	function DugisArrow:VisitFlightmaster(npc)
		if npc and DugisArrow.waypoints then
			for _, waypoint in pairs(DugisArrow.waypoints) do
				if waypoint.flightMasterID and 
					waypoint.flightMasterID==npc
				then 
					DGV.DugisArrow:SetNextWaypoint(waypoint)
					return
				end
			end
		end
	end
	
	hooksecurefunc("TakeTaxiNode", function(id)
		if DugisArrow.loaded then
			local x,y = TaxiNodePosition(id)
			y = 1 - y
			local cont = GetCurrentMapContinent_dugi()
			local lookupTable = DGV.Modules.TaxiData:GetLookupTable()
			if lookupTable then
				local conttable = lookupTable[cont]
				if conttable then
					local destNpc = conttable[DGV:PackXY(x,y)]
					if destNpc then
						DugisArrow:VisitFlightmaster(destNpc)
					end
				end
			end
		end
	end)

	local function GetPOIWaypointDescription(poiButton)
		--DGV:DebugFormat("GetPOIWaypointDescription", "poiButton", poiButton)
		local questId = poiButton.questID or (poiButton.quest and poiButton.quest.questId)
		local logIndex = GetQuestLogIndexByID(questId)
		local guideIndex = DugisGuideViewer:GetUnfinishedGuideIndexByQID(questId)
		local desc = GetQuestLogTitle(logIndex);

		if guideIndex then
			desc = DugisGuideViewer:GetQuestDescription(guideIndex)			
		elseif poiButton and poiButton.style == "normal" and GetQuestLogCompletionText(logIndex) then
			desc = "|cffffd200"..GetQuestLogCompletionText(logIndex).."|r"
		elseif poiButton then
			desc = "|cffffd200"..(GetQuestLogTitle(logIndex) or " ").."|r"
		end
		return desc
	end

	function DugisArrow:QuestPOIWaypoint(poiButton, reset)
		--DGV:DebugFormat("QuestPOIWaypoint", "WorldMapFrame:IsShown() ", WorldMapFrame:IsShown() )
		if 
			not UseTomTomArrow() 			
		then
			local questId = poiButton.questID or (poiButton.quest and poiButton.quest.questId)
			local m, f
			local desc = GetPOIWaypointDescription(poiButton)
			local _, posX, posY, objective = QuestPOIGetIconInfo(questId)
            
            if poiButton.worldQuest == true or poiButton.worldQuest == false then --false for bonus objectives
                --reset = true
                desc = C_TaskQuest.GetQuestInfoByQuestID(questId);
				if desc then 
					desc = "|cffffd200"..desc.."|r"..L[" (World Quest)"]
				end				
				m = C_TaskQuest.GetQuestZoneID(questId)
				if m then LuaUtils:DugiSetMapByID(m) end
				--f = GetCurrentMapDungeonLevel()
                posX, posY = C_TaskQuest.GetQuestLocation(questId, m)
            elseif posX then 
				m, f = DGV:GetCurrentMapID() --needed for quest in microdungeons
            else
                m, f = LuaUtils:DugiGetQuestWorldMapAreaID(questId)
            end
            
			if m and not posX then  --this is needed otherwise QuestPOIGetIconInfo returns nil for POI not in current map.
				LuaUtils:DugiSetMapByID(m) 
				_, posX, posY, objective = QuestPOIGetIconInfo(questId)
			end 
			if m == 321 and f == 0 then --force floor fix for orgrimmar
				f = 1
			end
			if reset then DugisGuideViewer:RemoveAllWaypoints() end
			if posX and posX > 0 then
				DGV:AddCustomWaypoint(posX, posY, desc, m, f, questId)
				if DugisGuideViewer:IsModuleLoaded("Target") then DoOutOfCombat(DugisGuideViewer.Modules.Target.Frame.Hide, DugisGuideViewer.Modules.Target.Frame) end
			end
		end
	end
	--local landmarkType, name, description, textureIndex, x, y, mapLinkID, inBattleMap, graveyardID, areaID, poiID, isObjectIcon, atlasIcon = GetMapLandmarkInfo(i);	
	function DugisArrow:LandMarkPOIWaypoint(poiButton, reset)
		if not poiButton then return end
		local posX, posY = poiButton.normalizedX, poiButton.normalizedY
		local m, f = DGV:GetCurrentMapID()
		if reset then DugisGuideViewer:RemoveAllWaypoints() end
		if posX then 
			DGV:AddCustomWaypoint(posX, posY, poiButton.name, m, f) 
		end
	end	

	function DugisArrow:OnQuestLogChanged(isInThread)
		if DugisGuideViewer.wqtloaded then return end
		local wp = DugisArrow:getFirstWaypoint()
		if not wp or wp.guideIndex or not wp.questId then return end
		
		if IsLegionPatch then 
			if (QuestUtils_IsQuestWorldQuest(wp.questId) and IsWorldQuestWatched(wp.questId)) or select(2, GetTaskInfo(wp.questId)) then 
				return 
			end		
		else
			if (QuestMapFrame_IsQuestWorldQuest(wp.questId) and IsWorldQuestWatched(wp.questId)) or select(2, GetTaskInfo(wp.questId)) then 
				return 
			end
		end
		for i=1,GetNumQuestLogEntries() do
            local _, _, _, _, _, _, _, id = GetQuestLogTitle(i)
			local link = GetQuestLink(id)
			local qid = link and tonumber(link:match("|Hquest:(%d+):"))
			if qid==wp.questId  then
				return
			end
		end
		DugisArrow:SetNextWaypoint(wp, isInThread)
	end
	
    local disabledClicksDugisArrow = false
	function DugisArrow:DisableMapClicks()
		if not DugisGuideViewer.carboniteloaded then
            disabledClicksDugisArrow = true 
		end
	end
	
	function DugisArrow:EnableMapClicks()
        disabledClicksDugisArrow = false
		if not DugisGuideViewer.carboniteloaded and not DugisArrow.old_WorldMapButtonOnClick then
            DugisArrow.old_WorldMapButtonOnClick = WorldMapFrame.ScrollContainer:GetScript("OnMouseDown")
            WorldMapFrame.ScrollContainer:SetScript("OnMouseDown", function(...)
                if not disabledClicksDugisArrow then
                    DugisMapOverlayFrame_OnMouseUp(...)
                end
            end)   
		end
	end
	
	local function UpdatePosition(setMapToCurrentZone)

		local prev_map, prev_floor = DugisArrow.map, DugisArrow.floor
		local _,_,_,x =  DugisGuideViewer:GetPlayerPosition()

		if not WorldMapFrame:IsVisible() and not 
			(DugisGuideViewer.carboniteloaded and NxMap1 and NxMap1:IsVisible()) and x
		then --NxMap1 is the Carbonite map
			DugisArrow.map, DugisArrow.floor, DugisArrow.pos_x, DugisArrow.pos_y = DugisGuideViewer:GetPlayerPosition()

		else --World Map Minimized
			local x, y = DGV:GetPlayerMapPosition()
			local floors = 0
			
			DugisArrow.pos_x, DugisArrow.pos_y = x, y
		end

		local isInInstance = IsInInstance()

		if setMapToCurrentZone then
			if isInInstance and (DugisArrow.map ~= prev_map or DugisArrow.floor ~= prev_floor) then
				DebugPrint("Map Change Detected")
				LuaUtils:DugiSetMapToCurrentZone()
			end
		end
	end

	function DugisArrow:initArrow()
		if not DugisMapOverlayFrame then
			DugisArrow.map_overlay = CreateFrame("FRAME", "DugisMapOverlayFrame", WorldMapFrame.ScrollContainer.Child)
			DugisArrow.map_overlay:SetAllPoints()
			DugisArrow.map_overlay:SetFrameLevel(1000)
			DugisArrow.map_overlay:SetFrameStrata("TOOLTIP")
		end

		if not DugisMinimapOverlayFrame then
			DugisArrow.minimap_overlay = CreateFrame("FRAME", "DugisMinimapOverlayFrame", Minimap)
			DugisArrow.minimap_overlay:SetAllPoints()
		end
		DugisArrow:EnableMapClicks()
		
		if DugisGuideViewer:UserSetting(DGV_CLASSICARROW) then
			wayframe.arrow:SetTexture(DugisArrow.CLASSIC_UP)
		else
			wayframe.arrow:SetTexture(DugisArrow.MODERN_UP)
		end

		if not DugisArrowDb or not DugisArrow:GetSetting("point") then DugisArrow:LoadDefaultSettings() end

		-- Player Position Variables
		DugisArrow.continent = 0;
		DugisArrow.zone = 0;
		DugisArrow.pos_x = 0;
		DugisArrow.pos_y = 0;
		DugisArrow.map = 0

		-- Update Variables
		DugisArrow.updatestart = 0;
		DugisArrow.updateend = 0;
		DugisArrow.updatelast = 0;

		DugisMapOverlayFrame:Show()
		DugisMinimapOverlayFrame:Show()
		UpdatePosition(true)

	end

	function DugisArrow:ResetPosition()
		wayframe:ClearAllPoints()
		wayframe:SetPoint("CENTER", DADEFAULT["arrow_pos_x"], DADEFAULT["arrow_pos_y"])
		DugisArrow:SetSetting("point", DADEFAULT["point"])
		DugisArrow:SetSetting("relativePoint", DADEFAULT["relativePoint"])
		DugisArrow:SetSetting("arrow_pos_x", DADEFAULT["arrow_pos_x"])
		DugisArrow:SetSetting("arrow_pos_y", DADEFAULT["arrow_pos_y"])
		DugisArrow:SetSetting("arrow_locked", false)
		DugisArrow:SetSetting("gps_locked", DADEFAULT["gps_locked"])
		DugisArrow:SetSetting("arrow_size", DADEFAULT["arrow_size"])
		DugisArrow:SetSetting("arrow_textsize", DADEFAULT["arrow_textsize"])
		DugisArrow:Show()
	end

	function DugisArrow:SetScale(scale)
		--if InCombatLockdown() then return end
		if scale then
			DugisArrow:SetSetting("arrow_size", scale)
		else
			scale = DugisArrow:GetSetting("arrow_size")
		end
        if DugisArrow.foundRoute or not DugisArrowFrame.arrow:IsShown() then
            if not showDownArrow then
                wayframe:SetHeight(60 * scale)
                wayframe:SetWidth(80 * scale)
            else
                scale = 0.85 * scale
                wayframe:SetHeight(92 * scale)
                wayframe:SetWidth(70 * scale)
            end
            wayframe.title:SetPoint("TOP", wayframe, "BOTTOM", 0, 0)
        else
            scale = 0.5 * scale
            wayframe:SetHeight(80 * scale)
            wayframe:SetWidth(80 * scale)
            wayframe.title:SetPoint("TOP", wayframe, "BOTTOM", 0, -10)
			if DGV.Modules.GPSArrowModule then
				DGV.Modules.GPSArrowModule.title:SetPoint("TOP", wayframe, "BOTTOM", 0, -10)
			end
			
        end
        
        if not InCombatLockdown() then
            wayframe.button:SetHeight(50 * scale)
            wayframe.button:SetWidth(50 * scale)
        end
        
        DugisArrowFrame.noRouteButton.button:SetHeight(80 * scale)
        DugisArrowFrame.noRouteButton.button:SetWidth(80 * scale)
        
	end

	function DugisArrow:SetTextScale(scale)
		if scale then
			DugisArrow:SetSetting("arrow_textsize", scale)
		else
			scale = DugisArrow:GetSetting("arrow_textsize")
		end

		wayframe.title:SetFont(default_font_name, default_font_size * scale, default_font_flags)
		wayframe.status:SetFont(default_font_name, default_font_size * scale, default_font_flags)
		wayframe.tta:SetFont(default_font_name, default_font_size * scale, default_font_flags)

		if DGV.Modules.GPSArrowModule then
			DGV.Modules.GPSArrowModule.title:SetFont(default_font_name, default_font_size * scale, default_font_flags)
			DGV.Modules.GPSArrowModule.status:SetFont(default_font_name, default_font_size * scale, default_font_flags)
			DGV.Modules.GPSArrowModule.tta:SetFont(default_font_name, default_font_size * scale, default_font_flags)
		end
		
	end

	function DugisArrow:setArrow(m, f, x, y, desc, waypoint)
		active_point.m, active_point.f, active_point.x, active_point.y = m, f, x/100, y/100
		active_point.waypoint = waypoint
		wayframe.title:SetText(desc)
		if DGV.Modules.GPSArrowModule then
			DGV.Modules.GPSArrowModule.title:SetText(desc)
		end
		DugisArrow:Show()
	end

	function DugisArrow:PrintStatus()
		DebugPrint("Player Status:")

		self:PrintBool("map", DugisArrow.map)
		self:PrintBool("floor", DugisArrow.floor)
		self:PrintBool("pos_x", DugisArrow.pos_x)
		self:PrintBool("pos_y", DugisArrow.pos_y)

		DebugPrint("Waypoint Status:")
		self:PrintBool("map", active_point.m)
		self:PrintBool("floor", active_point.f)
		self:PrintBool("pos_x", active_point.x)
		self:PrintBool("pos_y", active_point.y)
	end



	function DugisArrow:DebugZ()
		local k, v
		DebugPrint("---------DugisArrow.waypoints:")
		if DugisArrow.waypoints then
			for k, v in ipairs(DugisArrow.waypoints) do
				DebugPrint("Index:"..k.." x coord:"..v.x.." y coord:"..v.y.." map:"..v.map.." floor:"..(v.floor or 0))
			end
		else
			DebugPrint("Empty")
		end

		self:PrintBool("WrongInstanceFloor", DugisGuideViewer.WrongInstanceFloor)
		DebugPrint("---------")
	end

	function DugisArrow:PrintBool(name, data)
		if type(data) == "boolean" then
			if data == true then DebugPrint(name.." == true")
			elseif data == false then DebugPrint(name.." == false")
			elseif data == nil then DebugPrint(name.." == nil") end
		else
			if data then DebugPrint(name.." == "..data) else DebugPrint(name.." == nil") end
		end
	end
	
	local function UpdateLFDFrame()
		local lfgMap,lfgId = DugisArrow:GetFirstWaypointLFGDestination()
		local fmap,_ = DugisGuideViewer:ReturnTag("F")
		
		if lfgId and (DugisArrow.map~=lfgMap or (DugisArrow.map~=lfgMap and fmap==lfgMap)) and not DGV:IsLFGQueued() then
			--Disable for now, sometime it appears for some map even though character is the correct map
			--GetCreateArrowLFGFrame()
			--lfgFrame.button.queue = lfgId
			--lfgFrame:Show()
		else
			if lfgFrame then lfgFrame:Hide() end
		end
		
	end

	local last_distance = 0
	local tta_throttle = 0
	local speed = 0
	local speed_count = 0
	
	DugisArrowGlobal.lastAngle = -1000
	
	local function OnUpdate(self, elapsed)

		local text = ""

		local playerX, playerY, playerM = DGV:GetPlayerLocalPosition(true)
		
		local dist, dx, dy = DugisGuideViewer:ComputeDistance(playerM, nil, playerX, playerY, active_point.m, nil, active_point.x, active_point.y)

		if DGV.Modules.GPSArrowModule then
			DGV.Modules.GPSArrowModule.DistanceChanged(dist, dx, dy, active_point.m, active_point.f)
		end
		
		--if not DugisArrow.pos_x or not DugisArrow.pos_y or not DugisArrow:GetSetting("arrow") then
		if dist and dx and dy then

			local mdist = dist * 0.9144
			if GetLocale() == "enUS" then
				if dist > 9999 then
					text = math.floor(0.5 + dist/1760)..L[" mil"]
				else
					text = math.floor(0.5 + dist)..L[" yd"]
				end
			else
				if mdist > 9999 then
					text = math.floor(0.5 + mdist/1000)..L[" km"]
				else
					text = math.floor(0.5 + mdist)..L[" m"]
				end
			end

			status:SetText(text)
			
			if DGV.Modules.GPSArrowModule then
				DGV.Modules.GPSArrowModule.status:SetText(text)
			end

			tta_throttle = tta_throttle + elapsed

			if tta_throttle >= 1 then
				--print("dist="..dist.."Map="..DugisArrow.map.."Floor="..DugisArrow.floor.."xpos="..DugisArrow.pos_x.."ypos="..DugisArrow.pos_y.."map="..active_point.m.."floor="..active_point.f.."ap_x="..active_point.x.."ap_y"..active_point.y)
				-- Calculate the speed in yards per sec at which we're moving
				local current_speed = (last_distance - dist) / tta_throttle

				if last_distance == 0 then
				current_speed = 0
				end

				--DebugPrint("last_distance"..last_distance.."dist"..dist.."current_speed"..current_speed)
				if speed_count < 2 then
					speed = (speed + current_speed) / 2
					speed_count = speed_count + 1
				else
					speed_count = 0
					speed = current_speed
				end

				if speed > 0 then
					local eta = math.abs(dist / speed)
					if eta > 2^42 then
						wayframe.status:SetPoint("TOP", wayframe.title, "BOTTOM", -21, 0)
						wayframe.tta:SetPoint("LEFT", wayframe.status, "RIGHT", 8, 0)
						tta:SetText("***")
						
						if DGV.Modules.GPSArrowModule then
							DGV.Modules.GPSArrowModule.status:SetPoint("TOP", DGV.Modules.GPSArrowModule.title, "BOTTOM", -21, 0)
							DGV.Modules.GPSArrowModule.tta:SetPoint("LEFT", DGV.Modules.GPSArrowModule.status, "RIGHT", 8, 0)
							DGV.Modules.GPSArrowModule.tta:SetText("***")
						end
					elseif eta > 3600 then
						wayframe.status:SetPoint("TOP", wayframe.title, "BOTTOM", -24, 0)
						wayframe.tta:SetPoint("LEFT", wayframe.status, "RIGHT", 8, 0)
						tta:SetFormattedText("%01d:%02d:%02d", eta / 3600, eta % 24, eta %60)
						
						if DGV.Modules.GPSArrowModule then
							DGV.Modules.GPSArrowModule.status:SetPoint("TOP", DGV.Modules.GPSArrowModule.title, "BOTTOM", -24, 0)
							DGV.Modules.GPSArrowModule.tta:SetPoint("LEFT", DGV.Modules.GPSArrowModule.status, "RIGHT", 8, 0)
							DGV.Modules.GPSArrowModule.tta:SetFormattedText("%01d:%02d:%02d", eta / 3600, eta % 24, eta %60)
						end
					else
						wayframe.status:SetPoint("TOP", wayframe.title, "BOTTOM", -21, 0)
						wayframe.tta:SetPoint("LEFT", wayframe.status, "RIGHT", 8, 0)
						tta:SetFormattedText("%01d:%02d", eta / 60, eta % 60)
						
						if DGV.Modules.GPSArrowModule then
							DGV.Modules.GPSArrowModule.status:SetPoint("TOP", DGV.Modules.GPSArrowModule.title, "BOTTOM", -21, 0)
							DGV.Modules.GPSArrowModule.tta:SetPoint("LEFT", DGV.Modules.GPSArrowModule.status, "RIGHT", 8, 0)
							DGV.Modules.GPSArrowModule.tta:SetFormattedText("%01d:%02d", eta / 60, eta % 60)
						end
					end
				else
					wayframe.status:SetPoint("TOP", wayframe.title, "BOTTOM", -21, 0)
					wayframe.tta:SetPoint("LEFT", wayframe.status, "RIGHT", 8, 0)
					tta:SetText("***")
					
					if DGV.Modules.GPSArrowModule then
						DGV.Modules.GPSArrowModule.status:SetPoint("TOP", DGV.Modules.GPSArrowModule.title, "BOTTOM", -21, 0)
						DGV.Modules.GPSArrowModule.tta:SetPoint("LEFT", DGV.Modules.GPSArrowModule.status, "RIGHT", 8, 0)
						DGV.Modules.GPSArrowModule.tta:SetText("***")
					end					
				end

				last_distance = dist
				tta_throttle = 0
			end

			if ShouldShowStairs() then
				DugisArrow:SetScale()

				DugisArrow:setArrowTexture( )
			elseif (dist and dist <= 30 and DugisGuideViewer:ReturnTag("W")) or (dist and dist <= 5) then
				if not showDownArrow then
					showDownArrow = true
					DugisArrow:SetScale()
					DugisArrow:setArrowTexture( )
					arrow:SetVertexColor(1, 0.85, 0)
				end

				local cell = math.floor(mod(GetTime() * 60, 55))

				local column = cell % 9
				local row = floor(cell / 9)

				local xstart = (column * 53) / 512
				local ystart = (row * 70) / 512
				local xend = ((column + 1) * 53) / 512
				local yend = ((row + 1) * 70) / 512
				arrow:SetTexCoord(xstart,xend,ystart,yend)

				if DugisGuideViewer:IsPlayerAtBlizzardDestination() then
					local r, g, b = unpack(DugisArrow:GetQuestingAreaColor())
					arrow:SetVertexColor(r, g, b)
				end
			else
				if showDownArrow then
					showDownArrow = false
					DugisArrow:SetScale()
					DugisArrow:setArrowTexture( )
				end

				local angle = atan2(-dx, -dy) / 360 * (math.pi * 2)
				local player = GetPlayerFacing_dugi()
				angle = angle - player

				if angle ~= DugisArrowGlobal.lastAngle then
				
					DugisArrowGlobal.lastAngle = angle
					
					local perc = math.abs((math.pi - math.abs(angle)) / math.pi)
					if perc > 1 then perc = 2 - perc end

				
					local r,g,b = ColorGradient(perc)
					
					--To remove original light-yellow color from arrow
					arrow:SetDesaturated(true)
					
					arrow:SetVertexColor(r,g,b)

					if DugisGuideViewer:IsPlayerAtBlizzardDestination() then
						local r, g, b = unpack(DugisArrow:GetQuestingAreaColor())
						arrow:SetVertexColor(r, g, b)
					end

					local cell = floor(angle / (math.pi * 2) * 108 + 0.5) % 108
					local column = cell % 9
					local row = floor(cell / 9)

					local xstart = (column * 56) / 512
					local ystart = (row * 42) / 512
					local xend = ((column + 1) * 56) / 512
					local yend = ((row + 1) * 42) / 512
					arrow:SetTexCoord(xstart,xend,ystart,yend)
				
				end
			end
            DugisArrow.foundRoute = true
		elseif active_point.m == 715 or --To force teleport portal regardless of cooldown
		DugisArrow.map == 715 or
		active_point.m == 709 or
		DugisArrow.map == 709 or
		active_point.m == 734 or
		DugisArrow.map == 734 or		
		active_point.m == 735 or
		DugisArrow.map == 735		
		then
			wayframe.arrow:Hide()
			DugisArrow:setArrowTexture( )
			DugisArrow.foundRoute = true
			status:SetText("***")
			if DGV.Modules.GPSArrowModule then
				DGV.Modules.GPSArrowModule.status:SetText("***")
			end
		else
            DugisArrow.foundRoute = false
		end
	end

	--[[ todo: find replacement
	hooksecurefunc("WorldMapLevelDropDown_Update", function()
		DGV:OnMapChangeUpdateArrow( )
	end)
	]]

	--[[function DugisGuideViewer:GetPlayerPosition()
		--DugisGuideViewer.astrolabe:GetCurrentPlayerPosition()--astrolabe initialization workaround
		return DugisArrow.map, DugisArrow.floor, DugisArrow.pos_x, DugisArrow.pos_y
	end]]

	function DugisGuideViewer:CheckForArrowChange()
		if DugisArrow.map ~= active_point.m and
			IsInInstance() then
			self.WrongInstanceFloor = true
		else
			self.WrongInstanceFloor = nil
		end
	end

	local lastElapsed = 0
	local function AlwaysUpdate(reaction, event, elapsed)
		-- Update Player Position
		UpdatePosition(false)
	
		if ((elapsed - DugisArrow.updatelast) > 1 ) then
			DugisArrow:UPDATE()
			DugisArrow.updatelast = elapsed
		end
		DugisGuideViewer.Ants:UpdateAntTrail(elapsed-lastElapsed)
		lastElapsed = elapsed
		
		if DugisArrow:getNumWaypoints() > 1 and not (DugisGuideViewer.carboniteloaded and DugisGuideViewer:UserSetting(DGV_CARBONITEARROW)) then
			if DugisArrow:DidPlayerReachWaypoint() then
				DugisArrow:SetNextWaypoint()
				DugisArrow:setArrowTexture( )
			end
		end				
		
		if DugisArrow.recalculateRoutesAwaiting and not DugisArrow.recalculatingRoutes then
			DugisArrow.RecalculateRoutes()
			DugisArrow.recalculateRoutesAwaiting = false
		end
		
	end

	function DugisArrow:UPDATE(event, elapsed, ...)

		-- Update Arrow		

		DugisGuideViewer:CheckForFloorChange()
		DugisGuideViewer:CheckForArrowChange()	
		
		if not DugisGuideUser.FinalizeWaypoint then
			DugisArrow:FinalizeWaypointIcon() 
		end
		DugisGuideViewer:UpdateTravelToLocation()		
		DugisArrow:setArrowTexture( )		
	end

	function DugisArrow:GetSetting(variable)

		if variable and DugisArrowDb then
			return DugisArrowDb[variable]
		end
	end

	function DugisArrow:SetSetting(variable, value)

		if DugisArrowDb and variable then
			if not value then DugisArrowDb[variable] = false
			else DugisArrowDb[variable] = value end
		end
	end

	function DugisArrow:ResetSettings()
		DugisArrowDb = {}
	end

	function DugisArrow:LoadDefaultSettings()
		DugisArrowDb = DADEFAULT
	end

	local function spacer()
		local htex = DugisGuideViewer.ArrowMenu:CreateIconTexture(item, 10)
		htex:SetVertexColor(1, 1, 1, 0)
		return htex
	end

	function DugisArrow:PopulateMenu(menu)
		local remove = DugisGuideViewer.ArrowMenu:CreateMenuItem(menu, L["Remove Waypoint"])
		remove:SetFunction(function () DugisArrow:ClearArrow() end)

		local removeAll = DugisGuideViewer.ArrowMenu:CreateMenuItem(menu, L["Remove All Waypoints"])
		removeAll:SetFunction(function () DugisGuideViewer:RemoveAllWaypoints()  end)

		local refresh = DugisGuideViewer.ArrowMenu:CreateMenuItem(menu, L["Refresh"])
		refresh:SetFunction(function () 
			DugisArrow.RefreshRoute(0)
		end)
		
		if waypoints then
			local wp = waypoints[#waypoints]
			if wp then
				DugisGuideViewer:RemoveAllWaypoints()
				local map, floor, x, y, desc, guideIndex, isWTag, questId = wp.map, wp.floor, wp.x, wp.y, wp.desc, wp.guideIndex, wp.isWTag, wp.questId
				LuaUtils:Delay(1, function()
					DugisArrow.SetWaypointInfo(map, floor, x, y, desc, guideIndex, isWTag, questId, true)
				end)
			end
		end

		local lock = DugisGuideViewer.ArrowMenu:CreateMenuItem(menu, not DugisArrow:GetSetting("arrow_locked") and L["Lock Arrow"] or L["Unlock Arrow"])
		local ltex = DugisGuideViewer.ArrowMenu:CreateIconTexture(item, 10)
		lock:SetFunction(function () local arrow_locked = not DugisArrow:GetSetting("arrow_locked"); DugisArrow:SetSetting("arrow_locked", arrow_locked); end)
		lock:AddTexture(ltex, true)
		lock:AddTexture(spacer(), false)
		ltex:SetVertexColor(1, 1, 1, DugisArrow:GetSetting("arrow_locked") and 1 or 0)
		
		local lockGPS = DugisGuideViewer.ArrowMenu:CreateMenuItem(menu, not DugisArrow:GetSetting("gps_locked") and L["Lock Zone Map"] or L["Unlock Zone Map"])
		local ltex = DugisGuideViewer.ArrowMenu:CreateIconTexture(item, 10)
		lockGPS:SetFunction(function () local gps_locked = not DugisArrow:GetSetting("gps_locked"); DugisArrow:SetSetting("gps_locked", gps_locked); end)
		lockGPS:AddTexture(ltex, true)
		lockGPS:AddTexture(spacer(), false)
		ltex:SetVertexColor(1, 1, 1, DugisArrow:GetSetting("gps_locked") and 1 or 0)

		local scale = DugisGuideViewer.ArrowMenu:CreateMenuItem(menu, L["Arrow Scale"])
		scale:ClearAllPoints()
		local scale_menu = DugisGuideViewer.ArrowMenu:CreateMenu("scale_menu")
		scale:SetSubmenu(scale_menu)

		scale:AddTexture(spacer(), true)
		for i = 5, 15 do
			local it = DugisGuideViewer.ArrowMenu:CreateMenuItem(scale_menu, string.format("%d%%", i * 10))
			local ix = i
			it:SetFunction(function () DugisArrow:SetScale(ix / 10) end)
			local icon = DugisGuideViewer.ArrowMenu:CreateIconTexture(item, 10)
			if DugisArrow:GetSetting("arrow_size") == ix / 10 then
				icon:SetVertexColor(1, 1, 1, 1)
			else
				icon:SetVertexColor(1, 1, 1, 0)
			end
			it:AddTexture(icon)
		end

		local tscale = DugisGuideViewer.ArrowMenu:CreateMenuItem(menu, L["Text Scale"])
		tscale:ClearAllPoints()
		
		local tscale_menu = DugisGuideViewer.ArrowMenu:CreateMenu("tscale_menu")
		tscale:SetSubmenu(tscale_menu)
		tscale:AddTexture(spacer(), true)
		for i = 5, 15 do
			local it = DugisGuideViewer.ArrowMenu:CreateMenuItem(tscale_menu, string.format("%d%%", i * 10))
			local ix = i
			it:SetFunction(function () DugisArrow:SetTextScale(ix / 10) end)
			local icon = DugisGuideViewer.ArrowMenu:CreateIconTexture(item, 10)
			if DugisArrow:GetSetting("arrow_textsize") == ix / 10 then
				icon:SetVertexColor(1, 1, 1, 1)
			else
				icon:SetVertexColor(1, 1, 1, 0)
			end
			it:AddTexture(icon)
		end

	end

	wayframe:RegisterForClicks("RightButtonUp")
	wayframe:SetScript("OnClick", WayFrame_OnClick)
	wayframe.button:HookScript("OnClick", 
		function(self, button)
			if button=="RightButton" then
				WayFrame_OnClick(self, button)
			end
		end)
	wayframe:SetScript("OnEnter", arrow_OnEnter)
	wayframe:SetScript("OnLeave", arrow_OnLeave)

	--[[
	hooksecurefunc("WorldMapLevelDropDown_Update", function()
		DebugPrint("WorldMapLevelDropDown_Update")
		DugisArrow:onMapChangeUpdateArrow( )
	end)
	--]]
	
	local UID = 0
	local function SetWaypointMembers(point, guideIndex, isWTag, questId)
		point.guideIndex = guideIndex
		point.questId = questId or (DGV.qid and DGV.qid[guideIndex])
		point.isWTag = isWTag
        
		UID = UID + 1
		point.uid = UID
		DugisArrow:WaypointsChanged()
	end
	
	local function SetWaypointMembersPostCalculation(mapID, mapFloor, x, y, desc, point, guideIndex, isWTag, questId)
		if not point then
			--DGV:DebugFormat("DugisArrow:AddWaypoint No route found")
			point = AddWaypoint(mapID, x, y, desc)
		end
		point.isRouteWaypoint = nil
		point.isRouteDestination = true
		SetWaypointMembers(point, guideIndex, isWTag, questId)
	end
	
	local function SetSmartWaypointRoutine(mapID, mapFloor, x, y, desc, guideIndex, isWTag, questId)
		DugisArrow:SetProgressSpinner()
		local last = DugisArrow.waypoints and DugisArrow.waypoints[#DugisArrow.waypoints]
		local point = DGV:SetSmartWaypoint(mapID, mapFloor, x, y, desc, 
			last and last.map, 
			last and last.floor, 
			last and last.x, 
			last and last.y)
		SetWaypointMembersPostCalculation(mapID, mapFloor, x, y, desc, point, guideIndex, isWTag, questId)
	end
	
	local waypointInfoQueue
	local function InterruptSetSmartWaypoint()
		InterruptAutoroutine("SetSmartWaypoint")
		if not waypointInfoQueue then return end
		while #waypointInfoQueue>0 do
			waypointInfoQueue:Remove(1):Pool()
		end
		waypointInfoQueue:Pool()
		waypointInfoQueue = nil
	end
	
	local function QueueWaypointInfo(mapID, mapFloor, x, y, desc, guideIndex, isWTag, questId, forceCalculation)
		if not waypointInfoQueue then
			waypointInfoQueue = DGV.GetCreateTable()
		end
		waypointInfoQueue:Insert(DGV.GetCreateTable(mapID, mapFloor, x, y, desc, guideIndex, isWTag, questId, forceCalculation))
	end
	
	local SetQueuedWaypointInfo
	local function SetWaypointInfo(mapID, mapFloor, x, y, desc, guideIndex, isWTag, questId, forceCalculation)
		InterruptRecalculation()

        local disabledTaxiSystem = not DGV:UserSetting(DGV_USETAXISYSTEM) or isWTag
		if disabledTaxiSystem or (DugisArrow:getNumWaypoints()>0 and not forceCalculation) then
			local point = AddWaypoint(mapID, x, y, desc)
			SetWaypointMembers(point, guideIndex, isWTag, questId)
			return true
		else
			BeginAutoroutine("SetSmartWaypoint", SetSmartWaypointRoutine, mapID, mapFloor, x, y, desc, guideIndex, isWTag, questId):OnCompletion(SetQueuedWaypointInfo)
			return false
		end
	end
	
	DugisArrow.SetWaypointInfo = SetWaypointInfo
	
	SetQueuedWaypointInfo = function()
		if waypointInfoQueue then
			while #waypointInfoQueue>0 do
				local info = waypointInfoQueue:Remove(1)
				local complete = SetWaypointInfo(info:Pool())
				if not complete then
					break
				end
			end
			if #waypointInfoQueue==0 then
				waypointInfoQueue:Pool()
				waypointInfoQueue = nil
			end
		end
	end
	
	function DugisArrow:AddWaypoint( mapID, mapFloor, x, y, desc, guideIndex, questId, forceCalculation, isWTag)
		--DGV:DebugFormat("AddWaypoint", "mapID", mapID, "mapFloor", mapFloor, "x", x, "y", y, "desc", desc)
		DugisGuideUser.WaypointGuideIndex = guideIndex

		if not isWTag and guideIndex and DugisGuideViewer:IsModuleLoaded("Guides") and DugisGuideViewer.tags[guideIndex] then
			isWTag = DugisGuideViewer.tags[guideIndex]:match("(|LOOP|)")~=nil
		end
		
		local waypointAutoroutine = GetRunningAutoroutine("SetSmartWaypoint")
		if waypointAutoroutine then
			QueueWaypointInfo(mapID, mapFloor, x, y, desc, guideIndex, isWTag, questId, forceCalculation)
		else
			SetWaypointInfo(mapID, mapFloor, x, y, desc, guideIndex, isWTag, questId, forceCalculation)
		end
	end

	function DugisArrow:getNumWaypoints( )
		return (DugisArrow.waypoints and #DugisArrow.waypoints) or 0
	end

	function DugisArrow:getFirstWaypoint()
		if DugisArrow.waypoints then
			return DugisArrow.waypoints[1]

		end
	end
	
	function DugisArrow:getFinalWaypoint()
		if DugisArrow.waypoints then
			return DugisArrow.waypoints[DugisArrow:getNumWaypoints()]
		end
	end	

	local maxsetnext = 0
	function DugisArrow:SetNextWaypoint(removeMe, isInThread)
        LuaUtils:RestIfNeeded(isInThread)
        
		if maxsetnext > 30 then return end --Stops endless loop if 2 waypoints are very close together with |LOOP| tag which can crash the game
		maxsetnext = maxsetnext + 1
			
		local waypoint, firstWaypoint

		--DebugPrint("SetNextWaypoint stack:"..debugstack())
		--DebugPrint("SetNextWaypoint removeMe:"..tostring(removeMe).." getNumWaypoints:"..getNumWaypoints())
		if DugisArrow:getNumWaypoints() > 1 or removeMe then
			waypoint = DugisArrow:DidPlayerReachWaypoint()
			waypoint = removeMe or DugisArrow:getFirstWaypoint()
			--waypoint = removeMe or ((waypoint.isWTag or waypoint.isRouteWaypoint) and waypoint) or DugisArrow:getFirstWaypoint()
			
			if not waypoint.isWTag or waypoint.isRouteWaypoint or removeMe then 
				DugisArrow:RemoveWaypoint(waypoint)				
				if DugisGuideViewer:UserSetting(DGV_WAYPOINT_PING) then PlaySoundFile("sound\\interface\\magicclick.ogg") end
				UIErrorsFrame:AddMessage(L["Waypoint reached."],1,1,1,1)
			elseif DugisArrow:DidPlayerReachWaypoint() ~= DugisArrow:getFinalWaypoint() then		
				DugisArrow:RemoveWaypoint(waypoint)	
				DugisArrow:AddWaypoint(waypoint.map, waypoint.floor, waypoint.x, waypoint.y, waypoint.desc, waypoint.guideIndex, waypoint.questId, false, waypoint.isWTag)  --creates problems with recalculation, revisit later. 
				if DugisGuideViewer:UserSetting(DGV_WAYPOINT_PING) then PlaySoundFile("sound\\interface\\magicclick.ogg") end
				UIErrorsFrame:AddMessage(L["Waypoint reached."],1,1,1,1)				
			end

			firstWaypoint = DugisArrow:getFirstWaypoint()

			if firstWaypoint and firstWaypoint ~= waypoint then
				if UseTomTomArrow() then
					TomTom:SetCrazyArrow( firstWaypoint.tomtom, 5, firstWaypoint.desc )
				else
					DugisArrow:setArrow( firstWaypoint.map, firstWaypoint.floor, firstWaypoint.x, firstWaypoint.y, firstWaypoint.desc, firstWaypoint )
					DugisArrow:WaypointsChanged()
				end
			end
			
			if waypoint and not waypoint.isWTag and DugisArrow:DidPlayerReachWaypoint() and not removeMe and not waypoint.isRouteWaypoint then
				DugisArrow:SetNextWaypoint(isInThread)
			elseif waypoint and waypoint.isWTag and DugisArrow:DidPlayerReachWaypoint() and (DugisArrow:DidPlayerReachWaypoint() ~= DugisArrow:getFinalWaypoint()) and not removeMe and not waypoint.isRouteWaypoint then
				DugisArrow:SetNextWaypoint(isInThread)
			end				
		end
		maxsetnext = 0
	end

	function DugisArrow:DidPlayerReachWaypoint()
		local dist
		local minimumdist = 15 

		for _, waypoint in pairs(DugisArrow.waypoints) do
			dist = DugisGuideViewer:GetDistanceFromPlayer(waypoint.map, waypoint.floor, waypoint.x, waypoint.y)
			--if dist then DebugPrint("dist="..dist) end
			if waypoint.isWTag then minimumdist = 30 end
			
			if dist and dist < minimumdist and 
				not waypoint.flightMasterID and 
				not waypoint.destID and
				not waypoint.spellRequirement and
				not waypoint.noTrigger and
				not waypoint.isCorpseWaypoint
			then
				local pmap, pfloor, px, py = DGV:GetPlayerPosition()
--DGV:DebugFormat("DidPlayerReachWaypoint", "pfloor", pfloor, "waypoint", waypoint)
				if pmap==waypoint.map then
					return waypoint
				end
			end
			if 
				waypoint.destID and
				waypoint.destID==DugisArrow.map and
				not WorldMapFrame:IsShown() --DugisArrow.map isn't reliable when the map is opened and manipulated, but destID is only used after a teleport scenario, after which the map will always be closed.
			then
				return waypoint
			end
		end

	end
    
	function DugisArrow:DidPlayerReachPlace(x, y, m, f)
		local dist
		local minimumdist = 15 

        local dist = DugisGuideViewer:GetDistanceFromPlayer(m, f, x, y)
        
        if dist and dist < minimumdist then
            local _, pfloor = DGV:GetPlayerPosition()
            if pfloor == f then
                return true
            end
        end
    end

	--was not used
	
	function DugisGuideViewer:PrintCoords()
		for _, waypoint in pairs(DugisArrow.waypoints) do
			DebugPrint("waypoints uid:"..waypoint.uid.." M:"..waypoint.map.." F:"..waypoint.floor.." X:"..waypoint.x.." Y:"..waypoint.y.." desc:"..waypoint.desc)
		end
	end
	
	function RemoveWaypointAt(index)
		local waypoint = table.remove(DugisArrow.waypoints, index)
		if waypoint.tomtom then DugisArrow:RemoveTomTomWaypoint(waypoint.tomtom) end

		waypoint.worldmap.icon:Hide()
		waypoint.worldmap:Hide()
        
		DugisGuideViewer:RemoveMinimapIcon(waypoint.minimap)
		DugisGuideViewer:RemoveWorldMapIcon(waypoint.worldmap)
        
		if DGV.Modules.GPSArrowModule then 
			waypoint.GPSArrowPoint.icon:Hide()
			waypoint.GPSArrowPoint:Hide()
		end
        
        
		pointCache:ReleaseFrame(waypoint.worldmap)
		miniPointCache:ReleaseFrame(waypoint.minimap)
		
		if DGV.Modules.GPSArrowModule then 
			GPSArrowPointCache:ReleaseFrame(waypoint.GPSArrowPoint)
		end
		tPool(waypoint)
		if DugisArrow:getNumWaypoints() == 0 then 
			DugisArrow:Hide()
		end
		
		return
	end

	function DugisGuideViewer:RemoveAllWaypoints()
		InterruptRecalculation()
		InterruptSetSmartWaypoint()
		if UseCarboniteArrow() then 
			local map = Nx.Map:GetMap (1)
			if map then 
				map:ClearTargets()
			end
		end
		if DugisArrow.waypoints then
			while #DugisArrow.waypoints>0 do
				RemoveWaypointAt(1)
			end
			DugisArrow.waypoints = nil
			DugisArrow.waypointsRemoved = true
		end
		DugisArrow:Hide()
		DugisArrow:WaypointsChanged()
	end

    
	function DugisGuideViewer:RemoveAllWaypointsFromZone(zoneName)

        InterruptRecalculation()
        InterruptSetSmartWaypoint()

        if UseCarboniteArrow() then 
            local map = Nx.Map:GetMap (1)
            map:ClearTargets()
        end

        if DugisArrow.waypoints then

            for i=#DugisArrow.waypoints,1,-1 do
            
                local name = DGV:GetMapNameFromID(DugisArrow.waypoints[i].map)
            
                if name == zoneName then
                    RemoveWaypointAt(i)
                end
            end            

            if #DugisArrow.waypoints == 0 then
                DugisArrow.waypoints = nil
                DugisArrow:Hide()
            end

        end
        
        DugisArrow:Hide()
        DugisArrow:WaypointsChanged()
	end

    
	function DugisArrow:ClearArrow( )
		DugisArrow:SetNextWaypoint(DugisArrow:getFirstWaypoint())
	end

	function DugisArrow:RemoveWaypoint(waypoint, suppressChangedEvent)
		--DebugPrint("Try to delete waypoint:"..waypoint.x..","..waypoint.y)
		local index = 1
		while index<=#(DugisArrow.waypoints) do
			local val = DugisArrow.waypoints[index]
			if val == waypoint then
				RemoveWaypointAt(index)
				break
			elseif val.isRouteWaypoint then
				RemoveWaypointAt(index)
			else
				index = index+1
			end
		end
		if not suppressChangedEvent then
			DugisArrow:WaypointsChanged()
		end
	end

	function DugisGuideViewer:RemoveMinimapIcon(point)
		DugisGuideViewer:RemoveIconFromMinimap(point)
	end
	
	function DugisArrow.UpdateWaypointsVisibility()
		if DugisArrow.waypoints then
		
			local hiddenRest = false
		
			for i=1, #DugisArrow.waypoints do
				local waypoint = DugisArrow.waypoints[i]
				
				waypoint.hiddenRestOnMinimap = hiddenRest
				
				if hiddenRest then
					waypoint.minimap.icon:Hide()
					waypoint.minimap.arrow:Hide()
					
					if waypoint.minimapVisualLine then
						waypoint.minimapVisualLine:Hide()
					end
				end
			
				if waypoint.minimap.edge then
					hiddenRest = true
				end
			end
		end
	end
	

	local minimap_counts = {}
	local rad_135 = math.rad(135)
	local square_half = math.sqrt(0.5)
	function DugisArrow.Minimap_OnUpdate(self, elapsed)

		--todo
		local dist,x,y = 0 --DugisGuideViewer.astrolabe:GetDistanceToIcon(self)
		if not dist then
			self:Hide()
			return
		end

		minimap_counts[self] = (minimap_counts[self] or 0) + elapsed
		
		if minimap_counts[self] < 0.1 then 
			return 
		end
		
		minimap_counts[self] = 0

		local edge = pins:IsMinimapIconOnEdge(self) 
		self.edge = edge
		
		if ShouldShowStairs() then
			self.icon:Hide()
			self.arrow:Hide()
		elseif edge then
			self.icon:Hide()
			self.arrow:Show()

			local angle = pins:GetVectorToIcon(self)

			angle = (angle or 0) + rad_135
			if GetCVar("rotateMinimap") == "1" then
				local cring = GetPlayerFacing_dugi()
				angle = angle - cring
			end

			local sin,cos = math.sin(angle) * square_half, math.cos(angle) * square_half
			self.arrow:SetTexCoord(0.5-sin, 0.5+cos, 0.5+cos, 0.5+sin, 0.5-cos, 0.5-sin, 0.5+sin, 0.5-cos)
		else
			self.icon:Show()
			self.arrow:Hide()
		end
		
		DugisArrow.UpdateWaypointsVisibility()
	end

	function DugisArrow:RemoveTomTomWaypoint(waypoint)
		DugisArrow.CallingRemoveWaypoint = true
		TomTom:RemoveWaypoint(waypoint)
		DugisArrow.CallingRemoveWaypoint = nil
	end

	--[[local function IsValidCurrentWaypoint(posX, posY, desc)
		local waypoints = DugisGuideViewer.DugisArrow.waypoints
		if waypoints then
			for _, waypoint in pairs(waypoints) do
				--DebugPrint(string.format("Debug IsValidCurrentWaypoint: waypoint.desc=%s desc=%s waypoint.x=%s posX=%s waypoint.y=%s posY=%s",waypoint.desc, desc, waypoint.x, posX, waypoint.y,posY))
				if waypoint.desc == desc and waypoint.x == posX and waypoint.y == posY then
					return true
				end
			end
		end
		return false
	end

	function DugisArrow:GuideIndexHasWaypoint(index)
		local desc = DugisGuideViewer:GetQuestDescription(index)
		local XYVals = DugisGuideViewer:getCoords(index)
		local waypoints = DugisGuideViewer.DugisArrow.waypoints
		if waypoints and XYVals and #XYVals>0 and desc then
			for _, coord in ipairs(XYVals) do
				local x, y = unpack(coord)
					if IsValidCurrentWaypoint(x, y, desc) then return 1 end
			end
		end
		return false
	end

	function DugisArrow:QuestPOIHasWaypoint(qid)
		local _, posX, posY = QuestPOIGetIconInfo(qid)
		local numEntries = QuestMapUpdateAllQuests()
		if poiWorldMapPOIFrame_Swap and
			poiWorldMapPOIFrame_Swap.quest and
			poiWorldMapPOIFrame_Swap.quest.questId==qid
		then
			if IsValidCurrentWaypoint(posX*100, posY*100, GetPOIWaypointDescription(poiWorldMapPOIFrame_Swap)) then
				return true
			end
		end

		local questCount = 0
		local numCompletedQuests = 0
		for i = 1, numEntries do
			local questId, questLogIndex = QuestPOIGetQuestIDByVisibleIndex(i);
		if ( questLogIndex and questLogIndex > 0 ) then
				questCount = questCount + 1;
				local isComplete = select(7, GetQuestLogTitle(questLogIndex))
				if ( isComplete ) then
					numCompletedQuests = numCompletedQuests + 1;
				end
				local poiButton = _G["poiWorldMapPOIFrame"..tostring(QUEST_POI_NUMERIC).."_"..tostring(questCount - numCompletedQuests)];
				if poiButton and poiButton.questId==qid then
					--DebugPrint("Debug QuestPOIHasWaypoint: qid="..tostring(qid))
					if IsValidCurrentWaypoint(posX*100, posY*100, GetPOIWaypointDescription(poiButton)) then
						--DebugPrint("Debug QuestPOIHasWaypoint: valid")
						return true
					end
				end
			end
		end
		return false
	end]]
	
	function DugisArrow:GetTotalRouteWaypoints()
		local waypoints = DugisGuideViewer.DugisArrow.waypoints
		local total = 0
		if waypoints then
			for _, waypoint in pairs(waypoints) do
				if waypoint.isRouteWaypoint then total = total + 1 end
			end
		end
		return total
	end	

	function DugisArrow:GetFirstWaypointGuideIndex()
		local waypoints = DugisGuideViewer.DugisArrow.waypoints
		if waypoints then
			for _, waypoint in pairs(waypoints) do
				if waypoint.guideIndex then return waypoint.guideIndex end
			end
		end
		return nil
	end

	function DugisArrow:GetFirstWaypointQuestId()
		local waypoints = DugisGuideViewer.DugisArrow.waypoints
		if waypoints then
			for _, waypoint in pairs(waypoints) do
				if waypoint.questId then return waypoint.questId end
			end
		end
		return nil
	end

	function DugisArrow:GetFirstWaypointLFGDestination()
		local waypoints = DugisGuideViewer.DugisArrow.waypoints
		if waypoints then
			for _, waypoint in pairs(waypoints) do
				local lfd = DGV:GetLFD(waypoint.map)
				if lfd then return waypoint.map,lfd end
			end
		end
		if DugisGuideViewer:ReturnTag("F") then 
			local fmap,_ = DugisGuideViewer:ReturnTag("F")
			local lfd = DGV:GetLFD(fmap)
			if lfd then return fmap,lfd end
		end
		return nil
	end
	
	local function SetWayFrameItem(itemID)
		wayframe.button:SetAttribute("type1", "item")
		wayframe.button:SetAttribute("item1", 
			"item:"..itemID)
		if wayframe:IsShown() then
			wayframe.button:Show()
		end
		DugisArrow:SetScale()
	end
	
	local function SetWayFrameSpell(spellID)
		wayframe.button:SetAttribute("type1", "spell")
		wayframe.button:SetAttribute("spell1", 
			GetSpellInfo(spellID))
		if wayframe:IsShown() then
			wayframe.button:Show()
		end
		DugisArrow:SetScale()
	end
	
	local function SetWayFrameLFGTeleport()
		wayframe.button:SetAttribute("type1", "macro")
		wayframe.button:SetAttribute("macrotext", "/run LFGTeleport(1)")
		if wayframe:IsShown() then
			wayframe.button:Show()
		end
		DugisArrow:SetScale()
	end
	
	function DugisArrow:SetProgressSpinner()
		wayframe.tta:SetText("")
		wayframe.title:Hide()
		wayframe.status:SetText("")
		
		if DGV.Modules.GPSArrowModule then
			DGV.Modules.GPSArrowModule.tta:SetText("")
			DGV.Modules.GPSArrowModule.title:Hide()
			DGV.Modules.GPSArrowModule.status:SetText("")
		end
		
		wayframe.arrow:Hide()
		DoOutOfCombat(wayframe.button.Hide,
			wayframe.button)
		wayframe.progress:Show()
        wayframe.noRouteButton.button:Hide()
	end

	local function HideInvisibleGPSWaypoints()
		--Hidding GPS waypoints that should not be visible
		LuaUtils:foreach(DugisArrowGlobal.waypoints, function(waypoint)
			if not (waypoint.worldmap.icon:IsShown() and waypoint.worldmap:GetTop() and waypoint.worldmap:GetLeft()) then
				waypoint.GPSArrowPoint:Hide()
			end
		end)
	end	

	function DugisGuideViewer:OnMapChangeUpdateGPSArrow( )
		if DugisArrow.waypoints  then
			local oldContinentId, continentId = GetCurrentMapContinent_dugi()
			for index, waypoint in pairs(DugisArrow.waypoints) do
				local w, h = GPSArrow.map_overlay:GetWidth(), -GPSArrow.map_overlay:GetHeight()
				local x, y = DGV:TranslateWorldMapPosition(waypoint.map, _, waypoint.x/100, waypoint.y/100,  DGV:GetDisplayedOrPlayerMapId())
				if x and y and w and h then
					SetGPSArrowPointPos(waypoint, x * w,  y * h)
					
					if x > 1 or x < 0 or y > 1 or y < 0 then
						waypoint.GPSArrowPoint:Hide()
					else
						waypoint.GPSArrowPoint:Show()
					end
                else
                    waypoint.GPSArrowPoint:Hide()
                end
			end
			
			HideInvisibleGPSWaypoints()
		end
	end	
	
	function DugisArrow:WaypointsChanged()
		wayframe.progress:Hide()
		wayframe.title:Show()
		
		if DGV.Modules.GPSArrowModule then
			DGV.Modules.GPSArrowModule.title:Show()
		end
		
		local waypoints = DugisArrow.waypoints
		local finalWaypoint 
	
		if not waypoints or #waypoints<1 then
			DoOutOfCombat(HideDugiWayframe)
		else 
			finalWaypoint = #waypoints
		end
		
		local center = wayframe:GetCenter()
		local top = wayframe:GetTop()
		local width = wayframe.button:GetWidth()
		if center and top and width then
			DoOutOfCombat(
				wayframe.button.SetPoint, 
				wayframe.button, "TOPLEFT", 
				UIParent, 
				center-(width/2), 
				top-UIParent:GetHeight())
		end
		
		if active_point.waypoint and 
			active_point.waypoint.cue 
		then
			
		elseif active_point.waypoint and 
			active_point.waypoint.itemID 
		then
			wayframe.arrow:Hide()
			wayframe.button.texture:SetTexture(
				GetItemIcon(active_point.waypoint.itemID))
			DoOutOfCombat(SetWayFrameItem, active_point.waypoint.itemID)
		elseif active_point.waypoint and 
				active_point.waypoint.spellID
		then
			wayframe.arrow:Hide()
			wayframe.button.texture:SetTexture(
				select(3,
					GetSpellInfo(active_point.waypoint.spellID)))
			DoOutOfCombat(SetWayFrameSpell, active_point.waypoint.spellID)
		elseif active_point.waypoint and 
				active_point.waypoint.isLFGTeleport
		then
			wayframe.arrow:Hide()
			wayframe.button.texture:SetTexture("Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\dungeon.tga")
			DoOutOfCombat(SetWayFrameLFGTeleport)
		else
			wayframe.arrow:Show()
			DoOutOfCombat(wayframe.button.Hide,wayframe.button)
		end
		UpdateLFDFrame()
		
		--DebugPrint("Debug WaypointsChanged: SmallFrame.Frame.Waypoint="..tostring(SmallFrame.Frame.Waypoint))
		local guideIndex = DugisArrow:GetFirstWaypointGuideIndex()
		--local dist = DugisGuideViewer:ComputeDistance(DugisArrow.map, DugisArrow.floor, DugisArrow.pos_x, DugisArrow.pos_y, active_point.m, active_point.f, active_point.x, active_point.y)

		if DGV:IsModuleLoaded("SmallFrame") then
			for _,frame in DGV.Modules.SmallFrame.IterateActiveStatusFrames do
				if DugisGuideUser.CurrentQuestIndex
					and frame.guideIndex==guideIndex
				then
					frame.Waypoint:SetNormalTexture("Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\waypoint_selected.tga")
				else
					frame.Waypoint:SetNormalTexture("Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\waypoint.tga")
				end
			end
		end

		if DGV:IsModuleLoaded("StickyFrame") then
			if DGV.Modules.StickyFrame.StickyQuests then
				for stickyIndex, questIndex in ipairs(DGV.Modules.StickyFrame.StickyQuests) do
					local sticky = _G["DGV_SFRow"..stickyIndex]
					if sticky and sticky.Waypoint and guideIndex==questIndex then
						sticky.Waypoint:SetNormalTexture("Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\waypoint_selected.tga")
					elseif sticky then
						sticky.Waypoint:SetNormalTexture("Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\waypoint.tga")
					end
				end
			end
		end

		if DGV:IsModuleLoaded("Guides") then
			local visualRows = DGV.visualRows
			if visualRows then
				for index, row in ipairs(visualRows) do

					if row.WayPoint and guideIndex==index then
						row.WayPoint:SetNormalTexture("Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\waypoint_selected.tga")
					else
						row.WayPoint:SetNormalTexture("Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\waypoint.tga")
					end
				end
			end
		end
		local questId = DugisArrow:GetFirstWaypointQuestId()
		--if DGV.ItemButton then DoOutOfCombat(DGV.ItemButton.Hide, DGV.ItemButton) end
		DoOutOfCombat(SetUseItemByQID, questId)
		if guideIndex then
			DGV:SetTarget(guideIndex)
			if DGV:IsModelDataOn() then
				DGV:ShowModel(guideIndex)
			end
			if waypoints and #waypoints>0 then
				finalWaypoint = #waypoints
				--dist = DugisGuideViewer:ComputeDistance(waypoints[finalWaypoint].map, waypoints[finalWaypoint].floor, waypoints[finalWaypoint].x, waypoints[finalWaypoint].y, active_point.m, active_point.f, active_point.x, active_point.y)
			end
			
			if waypoints[finalWaypoint].x ~= DugisGuideUser.PreviewPointx and waypoints[finalWaypoint].y ~= DugisGuideUser.PreviewPointy and active_point and active_point.waypoint and not active_point.waypoint.isWTag then
				if not DugisGuideViewer:IsPlayerAtBlizzardDestination() then
					DGV.MapPreview:FadeInMap()
					DugisGuideUser.PreviewPointx = waypoints[finalWaypoint].x
					DugisGuideUser.PreviewPointy = waypoints[finalWaypoint].y
				end
			end
		elseif questId then
			local questPOI = DGV:IterateQuestPOIs(function(poi)
				local id = poi.questId or (poi.quest and poi.quest.questId)
				if id==questId then return poi end
			end)
			if questPOI then
				DGV:WipeModels()
				DGV:WipeTargetNPCs()
				DGV:IterateGuideIndicesWithQID(questId, function(index)
					local action = DGV.actions[index]
					if questPOI.type==QUEST_POI_NUMERIC then
						if action=="C" or action=="N" or action=="K" then
							if DGV:IsModelDataOn() then
								DGV.Modules.ModelViewer:AddIndexModels(index)
							end
							DGV.Modules.Target:AddIndexNPCs(index)
						elseif action=="T" then
							return true
						end
					else
						if action=="T" then
							if DGV:IsModelDataOn() then
								DGV.Modules.ModelViewer:AddIndexModels(index)
							end
							DGV.Modules.Target:AddIndexNPCs(index)
							return true
						end
					end
				end)
				if DGV:IsModelDataOn() then
					DGV.Modules.ModelViewer:Finalize()
				end
				DGV:FinalizeTarget()
			end

			if waypoints and #waypoints>0 then
				finalWaypoint = #waypoints
				--dist = DugisGuideViewer:ComputeDistance(waypoints[finalWaypoint].map, waypoints[finalWaypoint].floor, waypoints[finalWaypoint].x, waypoints[finalWaypoint].y, active_point.m, active_point.f, active_point.x, active_point.y)
			end
			if waypoints[finalWaypoint].x ~= DugisGuideUser.PreviewPointx and waypoints[finalWaypoint].y ~= DugisGuideUser.PreviewPointy and active_point and active_point.waypoint and not active_point.waypoint.isWTag then
				if not DugisGuideViewer:IsPlayerAtBlizzardDestination() then
					DGV.MapPreview:FadeInMap()
					DugisGuideUser.PreviewPointx = waypoints[finalWaypoint].x
					DugisGuideUser.PreviewPointy = waypoints[finalWaypoint].y
				end
			end
		end
		UpdateLFDFrame()
		if questId then DGV:SafeSetMapQuestId(questId) end
        
        DGV:UpdateMapPingForNoRoutePath(true)
		
		if DGV.Modules.GPSArrowModule then
			DGV.Modules.GPSArrowModule.WaypointsChanged()
		end
		
		DugisGuideViewer:OnMapChangeUpdateGPSArrow( )
		
		DGV:WorldMapFrameOnHide()
		
	end

	--Notify us when TomTom removes waypoints, so we can delete our ant trail
	if DugisGuideViewer.tomtomloaded then
		local function hook_RemoveWayPoint(self, tomtomway)
			if DugisArrow.waypoints and not DugisArrow.CallingRemoveWaypoint then
				for index, waypoint in ipairs(DugisArrow.waypoints) do
					if tomtomway[3]*100 == waypoint.x and tomtomway[4]*100 == waypoint.y then
						DugisArrow:SetNextWaypoint(waypoint)
					end
				end
			end
		end
		hooksecurefunc(TomTom, "RemoveWaypoint", hook_RemoveWayPoint)
	end

	if DugisGuideViewer.tomtomloaded then
		local function hook_RemoveAllWaypoints(self)
			DugisGuideViewer:RemoveAllWaypoints()
		end
		hooksecurefunc(StaticPopupDialogs["TOMTOM_REMOVE_ALL_CONFIRM"], "OnAccept", hook_RemoveAllWaypoints)
	end
	
	function DGV:UNIT_SPELLCAST_SUCCEEDED(event, unit, cast, spellID)
        if unit == "player" then
            DugisGuideViewer:OnCastingSpell(spellID)
        end
    
		if unit=="player" and DugisArrow.waypoints then
			--DGV:DebugFormat("UNIT_SPELLCAST_SUCCEEDED", "spellID", spellID)
			for _, waypoint in pairs(DugisArrow.waypoints) do
				if spellID and (waypoint.spellRequirement==spellID or waypoint.spellID==spellID) then
					DugisArrow:SetNextWaypoint(waypoint)
					break
				end
			end
		end
	end

    function DGV:UpdateMapPingForNoRoutePath(hideOnly)
        local currentMapId = DGV:GetCurrentMapID()
        --local currentFloor = GetCurrentMapDungeonLevel()

        if not DugisGuideViewer.Modules.MapPreview.WaypointMapPing then
            DugisGuideViewer.Modules.MapPreview:InitializeWaypointMapPing()
        end

        local lastWaypoint = DugisArrowGlobal:getFinalWaypoint(); 
        
        if lastWaypoint then
            local x, y = DugisGuideViewer:Waypoint2MapCoordinates(lastWaypoint)
            DugisGuideViewer.Modules.MapPreview.WaypointMapPing:SetPoint("CENTER", DugisMapOverlayFrame, "TOPLEFT", x, y)
            
            if currentMapId == lastWaypoint.map  and not DugisArrow.foundRoute then
                if not hideOnly then
                    DugisGuideViewer.Modules.MapPreview.WaypointMapPing:Show()
                end
            else
                DugisGuideViewer.Modules.MapPreview.WaypointMapPing:Hide()
            end
        else
            DugisGuideViewer.Modules.MapPreview.WaypointMapPing:Hide()
        end
    end

	--local orig_WorldMapQuestPOI_OnClick = WorldMapQuestPOI_OnClick
	function DugisArrow:Load()
		DugisArrow:initArrow()
		DGV:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		DugisArrow:SetScale()
		DugisArrow:SetTextScale()
		
		function DugisArrow:WorldMapQuestPOI_OnClick(self, button, down)
			if button == "RightButton" and (IsControlKeyDown() or IsShiftKeyDown()) then
				DugisArrow:QuestPOIWaypoint(self, IsControlKeyDown())
			end
		end

		wayframe:SetScript("OnUpdate", OnUpdate)
		DugisArrow:Show()

		function DGV:OnMapChangeUpdateArrow( )
            DGV:UpdateMapPingForNoRoutePath(true)
			--DebugPrint("##################onMapChangeUpdateArrow")
			if DugisArrow.waypoints and not UseCarboniteArrow() then
				local oldContinentId, continentId = GetCurrentMapContinent_dugi()
                local c, z, m = oldContinentId, 0, DGV:GetCurrentMapID()
				for index, waypoint in pairs(DugisArrow.waypoints) do
					DugisGuideViewer:PlaceIconOnWorldMap( WorldMapButton, waypoint.worldmap, waypoint.map, waypoint.floor, waypoint.x/100, waypoint.y/100)
				end
			end
		end
		
		DGV.RegisterStopwatchReaction(0):WithAction(AlwaysUpdate)
			:DisposeOn(RegisterMemberFunctionReaction("DugisGuideViewer.Modules.DugisArrow", "Unload"))
			
		local function PlayerUnghost()
			if DugisArrow.waypoints and #DugisArrow.waypoints > 0 and not UnitIsDeadOrGhost("player") then
				for i = 1, #DugisArrow.waypoints do 
					if DugisArrow.waypoints[i] and (DugisArrow.waypoints[i].isCorpseWaypoint or DugisArrow.waypoints[i].desc == L["My Corpse"]) then 
						RemoveWaypointAt(i)
					end
				end
			end
			
			local waypoint = DugisArrow:getFirstWaypoint()

			if waypoint then
				if UseTomTomArrow() then
					TomTom:SetCrazyArrow( waypoint.tomtom, 5, waypoint.desc )
				else
					DugisArrow:setArrow( waypoint.map, waypoint.floor, waypoint.x, waypoint.y, waypoint.desc, waypoint )
					DugisArrow:WaypointsChanged()
				end
			end
			--[[ old way doesn't work with essential mode
			if active_point and active_point.waypoint and active_point.waypoint.isCorpseWaypoint then
				DGV.DugisArrow:SetNextWaypoint(active_point.waypoint)
			end]]			
		end		
		DGV.RegisterReaction("PLAYER_UNGHOST"):WithAction(PlayerUnghost)
			:DisposeOn(RegisterMemberFunctionReaction("DugisGuideViewer.Modules.DugisArrow", "Unload"))
		DGV.RegisterReaction("PLAYER_ALIVE"):WithAction(PlayerUnghost)
			:DisposeOn(RegisterMemberFunctionReaction("DugisGuideViewer.Modules.DugisArrow", "Unload"))			
			
		local function DiffRecalculationPoints()
			if not recalculationPoints or not DugisArrow.waypoints then 
				return 
			end
			local diffDetected = #recalculationPoints~=#DugisArrow.waypoints
			if not diffDetected then
				for index, diff in recalculationPoints:IPairs() do
					local live = DugisArrow.waypoints[index]
					if 
						live.map~=diff.map or
						live.floor~=diff.floor or
						live.y~=diff.y or
						live.x~=diff.x or
						live.desc~=diff.desc
					then
						diffDetected = true
						break
					end
				end
			end
--DGV:DebugFormat("DiffRecalculationPoints", "diffDetected", diffDetected, "recalculationPoints==nil", recalculationPoints==nil)
			if diffDetected then
				while #DugisArrow.waypoints>0 do
					RemoveWaypointAt(1)
				end
				while #recalculationPoints>0 do
					PlaceWaypoint(recalculationPoints:Remove(1))
				end
				DugisArrow:WaypointsChanged()
			else
				while #recalculationPoints>0 do
					tPool(recalculationPoints:Remove(1))
				end
			end
			recalculationPoints:Pool()
			recalculationPoints = nil
		end
			
			
		local RecalculateRoutesRoutine_lastTime = 0
		local function RecalculateRoutesRoutine()
			if (GetTime() - RecalculateRoutesRoutine_lastTime) < MinimumRecalculateRoutes_sec then
				return
			end

			DugisArrow.recalculatingRoutes = true

			local last
            
            if not recalculationQueue then
				DugisArrow.recalculatingRoutes = false
                return
            end
			
			RecalculateRoutesRoutine_lastTime = GetTime()
            
			for index,location in recalculationQueue:IPairs() do
				local point
				local mapID, mapFloor, x, y, desc, guideIndex, isWTag, questId, forceCalculation = location:Unpack()
				if index==1 or forceCalculation then
					point = DGV:SetSmartWaypoint(mapID, mapFloor, x, y, desc, 
						last and last.map, 
						last and last.floor, 
						last and last.x, 
						last and last.y)
					if not point then
						point = AddWaypoint(mapID, x, y, desc)
					else
						point.isRouteWaypoint = nil
						point.isRouteDestination = true
					end
				else
					point = AddWaypoint(mapID, x, y, desc)
				end
				last = location
				point.guideIndex = guideIndex
				point.questId = questId or (DGV.qid and DGV.qid[guideIndex])
				point.isWTag = isWTag
				
			end
			DiffRecalculationPoints()
			DugisArrow.recalculatingRoutes = false
		end
		
		local function AddRecalculationLocation( mapID, mapFloor, x, y, desc, guideIndex, questId, forceCalculation)
			local isWTag = nil
			if guideIndex and DugisGuideViewer:IsModuleLoaded("Guides") and DugisGuideViewer.tags[guideIndex] then
				isWTag = DugisGuideViewer.tags[guideIndex]:match("(|LOOP|)")~=nil
			end
			
			if not recalculationQueue then
				recalculationQueue = DGV.GetCreateTable()
			end
			recalculationQueue:Insert(DGV.GetCreateTable(mapID, mapFloor, x, y, desc, guideIndex, isWTag, questId, forceCalculation))
		end
		
		local function RecalculateRoutes()
			if (GetTime() - RecalculateRoutesRoutine_lastTime) < MinimumRecalculateRoutes_sec then
				return
			end
		
			if DugisArrow.recalculatingRoutes then
				DugisArrow.recalculateRoutesAwaiting = true
				return
			end
		
			if 
				GetRunningAutoroutine("RecalculateRoutes") or 
				GetRunningAutoroutine("SetSmartWaypoint") or 
				not DugisArrow.waypoints 
			then 
				InterruptRecalculation()
				DugisArrow.recalculateRoutesAwaiting = true
				return
			end
			
			InterruptRecalculation()
			for _, waypoint in ipairs(DugisArrow.waypoints) do
				if not waypoint.isRouteWaypoint then
					AddRecalculationLocation(waypoint.map, waypoint.floor, waypoint.x, waypoint.y, waypoint.desc, waypoint.guideIndex, waypoint.questId, waypoint.isRouteDestination)
				end
			end
			if recalculationQueue then 
				BeginAutoroutine("RecalculateRoutes", RecalculateRoutesRoutine):OnInterrupt(function() 
					DugisArrow.recalculatingRoutes = false
				end)
			end
		end
		
		DugisArrow.RecalculateRoutes = RecalculateRoutes
		
		local lastM, lastF
		local function MapChangedPredicate()
			if not WorldMapFrame or WorldMapFrame:IsShown() then return end
			local x,y = DGV:GetPlayerMapPosition()
			if not x or not y or (x==0 and y==0) then return end
			if UnitOnTaxi("player") then return end
			local m, f = DGV:GetCurrentMapID()
			local isContinent = (DGV:GetCZByMapId(m))==0 and not IsInInstance()
			if isContinent then return end
            
			local changed = (m~=lastM or f~=lastF)
            
			lastM,lastF = m,f
			return changed
		end
		
		--todo: find replacement
		--RegisterReaction("WORLD_MAP_UPDATE"):WithPredicate(MapChangedPredicate):WithAction(RecalculateRoutes)
		--	:DisposeOn(RegisterMemberFunctionReaction("DugisGuideViewer.Modules.DugisArrow", "Unload"))
		
		local function NotFlyingPredicate()
			return not UnitOnTaxi("player")
		end
		RegisterReaction("ZONE_CHANGED")
			:Or(RegisterReaction("ZONE_CHANGED_NEW_AREA"))
			:Or(RegisterReaction("ZONE_CHANGED_INDOORS"))
			:Or(RegisterReaction("MINIMAP_UPDATE_ZOOM"))			
			:WithPredicate(NotFlyingPredicate)
			:WithAction(function()
                LuaUtils:Delay(5, function()
                    RecalculateRoutes()
                end)
            end)
			:DisposeOn(RegisterMemberFunctionReaction("DugisGuideViewer.Modules.DugisArrow", "Unload"))
			
		local function TaxiLandingPredicate()
			if InCombatLockdown() then return end
			return true
		end
		RegisterReaction("VEHICLE_UPDATE")
			:WithPredicate(TaxiLandingPredicate)
			:WithAction(RecalculateRoutes)
			:AfterWait(2)
			:DisposeOn(RegisterMemberFunctionReaction("DugisGuideViewer.Modules.DugisArrow", "Unload"))
	end

	function DugisArrow:Unload()
		DGV:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		DGV.WaypointsShown = false
		DugisArrow:Hide()
		DugisMapOverlayFrame:Hide()
		DugisMinimapOverlayFrame:Hide()

		wayframe:SetScript("OnUpdate", nil)
		DugisGuideViewer.Ants:ClearAntTrail()
		DugisGuideViewer:RemoveAllWaypoints()
		DugisArrow:Hide()
	end
    
	function UpdateCurrentBeaconMode()
        local TaxiData = DugisGuideViewer.Modules.TaxiData
    
        --FlightMapFrame
        --Check for Argus
		if FlightMapFrame and FlightMapFrame:IsShown() and FlightMapFrame.GetMapID and FlightMapFrame:GetMapID() == 1184 then
			local activePool = FlightMapFrame.pinPools["FlightMap_FlightPointPinTemplate"]
			for pin in activePool:EnumerateActive() do 
                local taxiNodeData = pin.taxiNodeData
              
                if taxiNodeData then
                    local id, x, y, name= taxiNodeData.nodeID, taxiNodeData.x, taxiNodeData.y, taxiNodeData.name
                    
                    x =  LuaUtils:Round(x, 7)
                    y =  LuaUtils:Round(y, 7)
                    
                    if x == 0.3279081 and y == 0.5351712 then
                        TaxiData.currentBeaconMode = "veiled-den"
                    end    
                        
                    if x == 0.3434584 and y == 0.7191246 then
                        TaxiData.currentBeaconMode = "lights-purchase"
                    end
                end
			end
		end
        
        --WorldMapFrame
        --[[ todo: find replacement
		if WorldMapFrame and WorldMapFrame:IsShown() then
            local numPOIs = GetNumMapLandmarks();
            for i=1, numPOIs do
                local _, name, _, _, x, y = C_WorldMap.GetMapLandmarkInfo(i)
            
                x =  LuaUtils:Round(x, 7)
                y =  LuaUtils:Round(y, 7)
                
                --Antoran Wastes
                if DGV:GetCurrentMapID() == 1171 then
                    if x == 0.726423 and y == 0.7616945 then
                        TaxiData.currentBeaconMode = "lights-purchase"
                    end
                    if x == 0.7059556 and y == 0.2547702 then
                        TaxiData.currentBeaconMode = "veiled-den"
                    end
                end
            end               
        end]]
	end
	
	--[[  todo: find replacement
	hooksecurefunc("WorldMapFrame_Update", function()
            UpdateCurrentBeaconMode()
            
			if not DugisMapOverlayFrame then return end
			
			local info = C_Map.GetCurrentMapInfo()
			
			if info.mapType == Enum.UIMapType.Cosmic
			then
				DugisMapOverlayFrame:Hide()
			else
				DugisMapOverlayFrame:Show()
			end
		end)
	]]
end

function DugisArrow.RefreshRoute(delay)
	delay = delay or 1
	
	local waypoints = DugisGuideViewer.Modules.DugisArrow.waypoints
	if waypoints then
		local wp = waypoints[#waypoints]
		if wp then
			DugisGuideViewer:RemoveAllWaypoints()
			local map, floor, x, y, desc, guideIndex, isWTag, questId = wp.map, wp.floor, wp.x, wp.y, wp.desc, wp.guideIndex, wp.isWTag, wp.questId
			LuaUtils:Delay(delay, function()
				DugisArrow.SetWaypointInfo(map, floor, x, y, desc, guideIndex, isWTag, questId, true)
			end)
		end
	end
end

local function OnTeleportUsed()
	DugisArrow.RefreshRoute()
end

function DugisArrow.DetectTeleportUsage()
	LuaUtils:Delay(2, function()
        if DugisLastPosition.mapId ~= nil and DugisLastPosition.mapId ~= C_Map.GetBestMapForUnit("player") then
            --Teleport or portal used
            OnTeleportUsed()
        end
        DugisLastPosition.mapId = C_Map.GetBestMapForUnit("player")
	end)
end