local DGV = DugisGuideViewer
local MP = DGV:RegisterModule("MapPreview")
MP.essential = true
local L = DugisLocals
local mapAlpha = 0.6
local IsLegion = select(4, GetBuildInfo()) >= 70000

local elementIndex = 0
local function GetNextIndex()
    elementIndex = elementIndex + 1
    return elementIndex
end

--name: tracking, level
local function GetWorldMapButton(name)
    local result
    LuaUtils:foreach({WorldMapFrame:GetChildren()}, function(v, k) 
        if type(v) == "table" and v.Hide and v.InitializeDropDown then 
            if v.selectedValue and name == "level" then
                result = v
            end

            if not v.selectedValue and name == "tracking" then
                result = v
            end
        end 
    end)
    return result
end

function MP:Initialize()
	DGV.MapPreview = MP

	local function IterateNonPreviewElements(delegate, unconditional)
        elementIndex = 0
		delegate(WorldMapFrameCloseButton, GetNextIndex())
		if DGV.CoordsFrame then
			delegate(DGV.CoordsFrame, GetNextIndex())
		end
        delegate(WorldMapFrame.BorderFrame, GetNextIndex())
        delegate(WorldMapFrame.NavBar, GetNextIndex())
        
        delegate(GetWorldMapButton("tracking"), GetNextIndex())
        delegate(GetWorldMapButton("level"), GetNextIndex())
        
        delegate(WorldMapFrame.BorderFrame.Bg, GetNextIndex())
        delegate(WorldMapFrame.SidePanelToggle, GetNextIndex())
        
        delegate(QuestMapFrame, GetNextIndex())
		if DugisGuideViewer.whollyloaded then delegate(Wholly.mapFrame, GetNextIndex())	end
		delegate(MapsterOptionsButton, GetNextIndex())
		delegate(Mapster_CoordsFrame, GetNextIndex())
		delegate(TomTomWorldFrame, GetNextIndex())
        
        local poiIndex = 1
        while _G["WorldMapFramePOI"..poiIndex] do 
            delegate(_G["WorldMapFramePOI"..poiIndex], GetNextIndex())                
            poiIndex = poiIndex + 1  
        end     

		local numDetails = 0--GetNumberOfDetailTiles()
        --[[
		if unconditional or (GetCurrentMapZone() > 0 and DGV:MapHasOverlays()) then
			for i=1, numDetails do
				delegate(_G["WorldMapDetailTile"..i], GetNextIndex())
			end
		end
        ]]
        
        LuaUtils:foreach(DugisGuideViewer.Modules.WorldMapTracking.trackingPoints, function(point)
            delegate(point, GetNextIndex())
        end) 
        
        --[[
		local levels
		if IsLegion then
			levels = #{ GetNumDungeonMapLevels() }
		else
			levels = GetNumDungeonMapLevels();
		end		
		if levels and levels > 0 then
			delegate(WorldMapLevelDropDown, elementIndex + numDetails + 1)
		end]]
	end

	local nonPreviewElementsShown = {}
	local function RestoreNonPreviewElements()
		IterateNonPreviewElements(function(frame, index)
			if nonPreviewElementsShown[index] then
                if frame then
                    frame:Show()
                end
			end
		end, true)
        
        WorldMapFrame:EnableMouse(true)
	end

	local function HideNonPreviewElements()
		if not DugisGuideViewer:GetDB(DGV_MAPPREVIEWHIDEBORDER) then
			return
		end
		RestoreNonPreviewElements()
		IterateNonPreviewElements(function(frame, index)
            if frame then
                nonPreviewElementsShown[index] = frame:IsShown()
            end
		end, true)
		IterateNonPreviewElements(function(frame, index)
            if frame then
                frame:Hide()
            end
		end)
        
        WorldMapFrame:EnableMouse(false)
	end

	local function SupressNonPreviewElements()
		if not DugisGuideViewer:GetDB(DGV_MAPPREVIEWHIDEBORDER) then
			return
		end
		IterateNonPreviewElements(function(frame, index)
            if frame then
                frame:Hide()
            end
		end)
	end

	local function IteratePreviewElements(delegate, unconditional)
		local lastWaypoint
		local numDetail = 0 --GetNumberOfDetailTiles()
		--[[if unconditional or GetCurrentMapZone() == 0 or not DGV:MapHasOverlays() then
			for i=1, numDetail do
				delegate(_G["WorldMapDetailTile"..i], i)
			end
		end]]
		if DGV.CoordsFrame then
            delegate(DGV.CoordsFrame, numDetail+1)
		end
		if DGV.DugisArrow.map_overlay then
			delegate(DGV.DugisArrow.map_overlay, numDetail+1)
		end
		if DGV.DugisArrow.waypoints and #DGV.DugisArrow.waypoints>0 then
			lastWaypoint = #DGV.DugisArrow.waypoints
			delegate(DGV.DugisArrow.waypoints[lastWaypoint].worldmap, numDetail+2)
		end
		delegate(WorldMapDetailFrame, numDetail+3)

		if unconditional or not DugisGuideViewer:GetDB(DGV_MAPPREVIEWHIDEBORDER) then
			IterateNonPreviewElements(function(frame, index)
				delegate(frame, index + numDetail+4)
			end)
		end
	end

	local orig_WorldMapArchaeologyDigSites = nil
	local no_op = function()end
	function MP:SetCombatHooks()
	end

	function MP:ResetCombatHooks()
	end

	--local resetWindowToggle = false
	local previewElementAlphas = {}
	local function ResetMapFade(noResize)
		if MP.IsAnimating and MP:IsAnimating() then
			DGV:DebugFormat("ResetMapFade IsAnimating")
			MP.FadeInAnimationGroup:Stop()
			MP.FadeOutAnimationGroup:Stop()
			RestoreNonPreviewElements()
			WorldMapFrame:SetAlpha(1)
            --JU 2016-10-17
		    --WorldMapArchaeologyDigSites:GetScript("OnLoad")(WorldMapArchaeologyDigSites)
		    --WorldMapArchaeologyDigSites:SetBorderAlpha(192)
			if MP.WaypointMapPing then MP.WaypointMapPing:Hide() end

			IteratePreviewElements(function(frame, index)
                if frame then
                    frame:SetAlpha(previewElementAlphas[index] or 1)
                end
			end, true)
			wipe(previewElementAlphas)
			--DGV:SafeMapUpdate()
		end
		--MP:ResetAnimationHooks()
		DGV.DugisArrow:EnableMapClicks()
	end

	function DGV:PLAYER_REGEN_DISABLED ()
		MP:SetCombatHooks()
        if WorldMapShowDropDown then
            WorldMapShowDropDown:Hide()
        end
		if MP:IsAnimating() then
			--ResetMapFade();
			--WorldMapFrame_ToggleWindowSize()
			--resetWindowToggle = false
			HideUIPanel(WorldMapFrame)
		end
	end

	function DGV:PLAYER_REGEN_ENABLED ()
		MP:ResetCombatHooks()
        if WorldMapShowDropDown then
            WorldMapShowDropDown:Show()
        end
	end
    
    local function IsQuestWatchedDugi(poiButton)
        local id = poiButton.questID or (poiButton.quest and poiButton.quest.questId)  
        if not poiButton.worldQuest then
            return id and IsQuestWatched(GetQuestLogIndexByID(id))
        else
            return id and (IsWorldQuestHardWatched(id) or IsWorldQuestWatched(id))
        end
    end

	function HideNonWaypointPOIs()
		if DGV.DugisArrow.waypoints and #DGV.DugisArrow.waypoints>0 and
			DugisGuideViewer:GetDB(DGV_MAPPREVIEWPOIS)~="All Available Quests" then
			local questId = DGV.DugisArrow:GetFirstWaypointQuestId() 
			local hidePoiFunc = function(poi)
                local parentIsMap = (poi:GetParent():GetName()  == "WorldMapPOIFrame")
                
				local id = poi.questID or (poi.quest and poi.quest.questId)  
				poi:Show()
                if poi.worldQuest then
                    poi:SetAlpha(1)
                end
				--DGV:DebugFormat("FadeInMap hide non waypoint pois", "waypoint qid", DGV.DugisArrow.waypoints[1].questId, "id", id)
				if DugisGuideViewer:GetDB(DGV_MAPPREVIEWPOIS)=="All Tracked Quests" then
					if id and not IsQuestWatchedDugi(poi) and parentIsMap then
						poi:Hide()
                        if poi.worldQuest then
                            poi:SetAlpha(0)
                        end
					end					
				elseif DugisGuideViewer:GuideOn() and DugisGuideViewer.chardb.EssentialsMode ~= 1 then 

					if DugisGuideViewer:IsModuleRegistered("Guides") and DGV.actions[DugisGuideUser.CurrentQuestIndex] == "R" then 
						if id and not IsQuestWatchedDugi(poi) and parentIsMap then
							poi:Hide()
                            if poi.worldQuest then
                                poi:SetAlpha(0)
                            end
						end
					else
						if id~=questId then
							poi:Hide()
                            if poi.worldQuest then
                                poi:SetAlpha(0)
                            end
						end
					end
				else				
					if id~=questId then
						poi:Hide()
                        if poi.worldQuest then
                            poi:SetAlpha(0)
                        end
					end
				end			
				if id==questId then 
				end	
			end
            DGV:IterateQuestPOIs(hidePoiFunc, WorldMapPOIFrame, QUEST_POI_NUMERIC)
            DGV:IterateQuestPOIs(hidePoiFunc, WorldMapPOIFrame, QUEST_POI_COMPLETE_IN)
            DGV:IterateQuestPOIs(hidePoiFunc, WorldMapPOIFrame, QUEST_POI_COMPLETE_OUT)
            DGV:IterateQuestPOIs(hidePoiFunc, WorldMapPOIFrame, QUEST_POI_COMPLETE_SWAP)
            DGV:IterateQuestPOIs(hidePoiFunc, WorldMapPOIFrame, nil, "WorldQuest")
            DGV:IterateQuestPOIs(hidePoiFunc, WorldMapPOIFrame, nil, "WorldMapFrameTaskPOI")
            DGV:IterateQuestPOIs(hidePoiFunc, WorldMapPOIFrame, nil, "WorldMapStoryLine")
            
		end
	end

	function MP:ConfigChanged()
		if MP.FadeInAnimationGroup then
			WorldMapFrame:Hide()
			ResetMapFade()
			MP.WaitAnimation:SetDuration(DugisGuideViewer:GetDB(DGV_MAPPREVIEWDURATION))
		end
		MP:FadeInMap()
	end

	function MP:IsAnimating()
		return (MP.FadeInAnimationGroup and MP.FadeInAnimationGroup:IsPlaying()) or
			(MP.FadeOutAnimationGroup and MP.FadeOutAnimationGroup:IsPlaying())
	end
	
	local function IsWaypointWithinCurrentFloorArea()
		local lastWaypoint = #DGV.DugisArrow.waypoints
		local wp = DGV.DugisArrow.waypoints[lastWaypoint]
		local wpx, wpy, wpm, wpf = wp.x/100, wp.y/100, wp.map, wp.floor
		if wp.map~= DGV:GetCurrentMapID()  then return end
		local wpx, wpy = DGV:TranslateWorldMapPosition(wpm, wpf, wpx, wpy, wpm, GetCurrentMapDungeonLevel())
		return wpx > 0 and wpy > 0 and wpx < 1 and wpy < 1
	end

	local WorldMapFrame = WorldMapFrame
	MP.ForceMapPreview = false
	MP.SupressToggleMap = false
	local fadingMap = nil
    local fadeInMapFirstTime = true
	function MP:FadeInMap()
        if fadeInMapFirstTime then
		--[[todo: find replacement
            WorldMapPOIFrame:HookScript("OnHide", function(self)
                LuaUtils:foreach(allWorldQuestButtons, function(button)
                   button:SetAlpha(1)
                end)
            end)
			]]
            fadeInMapFirstTime = false
        end
    
		if InCombatLockdown()
			or (WorldMapFrame:IsShown() and not MP:IsAnimating() and not MP.ForceMapPreview)
			or DGV:GetDB(DGV_MAPPREVIEWDURATION)==0
			or not DGV:GetDB(DGV_ENABLED_MAPPREVIEW)
			or DGV.carboniteloaded
			or WorldMapFrame:IsMaximized()
			or QuestFrame:IsShown()
			or GossipFrame:IsShown()
			or MerchantFrame:IsShown()
			or TaxiFrame:IsShown()
			--or QuestLogFrame:IsShown()
--			or QuestLogDetailFrame:IsShown()
			or SpellBookFrame:IsShown()
			or CharacterFrame:IsShown()
			or DugisGuideUser.PetBattleOn
			or (DugisMainBorder and DugisMainBorder:IsVisible())
			or (ArtifactFrame and ArtifactFrame:IsShown())			
			then return end
		if GetCVarBool("closedInfoFrames") == false then  
			SetCVarBitfield( "closedInfoFrames", LE_FRAME_TUTORIAL_WORLD_MAP_FRAME, true ) --stops annoying tutorial frame from poping up the first time
		end			
		local fadeMapId = DGV.DugisArrow.waypoints 
			and #DGV.DugisArrow.waypoints>0 

			and DGV.DugisArrow.waypoints[1].map
		--DGV:DebugFormat("FadeInMap", "fadeMapId", fadeMapId)
		if fadingMap~=fadeMapId then
			--DGV:DebugFormat("FadeInMap Resetting")
			ResetMapFade()
		end
		fadingMap = fadeMapId
		MP.ForceMapPreview = false
		local lastWaypoint
		
		--MP:SetAnimationHooks()
-- 		local wmbUpdate = WorldMapButton:GetScript("OnUpdate")
-- 		if wmbUpdate~=MP.WorldMapButton_OnUpdate then
-- 			DGV:DebugFormat("FadeInMap", "wmbUpdate", wmbUpdate)
-- 			orig_WorldMapButton_OnUpdate = wmbUpdate
-- 			WorldMapButton:SetScript("OnUpdate", MP.WorldMapButton_OnUpdate)
-- 		end
		--DGV:DebugFormat("FadeInMap")
		if not MP.FadeInAnimationGroup then
			ShowUIPanel(WorldMapFrame)
			--prevents error on early load
			if not WorldMapFrame:GetPoint(1) then
				--MP:ResetAnimationHooks()
				return
			end
			--DGV:DebugFormat("Debug FadeInMap: create MP.FadeInAnimationGroup","stack", debugstack())
			--[[DugisMapOverlayFrame:HookScript("OnEnter", function()
				ResetMapFade(true)
			end)]]

			MP.FadeInAnimationGroup = WorldMapFrame.ScrollContainer.Child:CreateAnimationGroup()
			MP.FadeInAnimationGroup:SetLooping("NONE")
			local fadeInAnimation = MP.FadeInAnimationGroup:CreateAnimation("DGV_FadeInMap")
			fadeInAnimation:SetDuration(.1)
			fadeInAnimation:SetOrder(1)
			fadeInAnimation:SetSmoothing("IN")
			fadeInAnimation:SetScript("OnPlay", function()
				IteratePreviewElements(function(frame, index)
					if frame and not previewElementAlphas[index] then
						previewElementAlphas[index] = frame:GetAlpha()
					end
				end)
				--DGV:DebugFormat("Debug FadeInMap: playing")
				WorldMapFrame:SetAlpha(.01)
				if DGV.DugisArrow.waypoints and #DGV.DugisArrow.waypoints>0 then
					lastWaypoint = #DGV.DugisArrow.waypoints
					if not IsWaypointWithinCurrentFloorArea() then
						local m,f = DGV.DugisArrow.waypoints[lastWaypoint].map, DGV.DugisArrow.waypoints[lastWaypoint].floor or 0
						LuaUtils:DugiSetMapByID(m)
					end
				end
				HideNonPreviewElements()
			end)
			fadeInAnimation:SetScript("OnFinished", function()
				--WorldMapFrame:SetAlpha(1)
				MP.FadeOutAnimationGroup:Play()
			end)
			fadeInAnimation:SetScript("OnUpdate", function(self)
				SupressNonPreviewElements()
				local progress = self:GetSmoothProgress()
				WorldMapFrame:SetAlpha(progress*0.5)
			end)

			MP.FadeOutAnimationGroup = WorldMapFrame.ScrollContainer.Child:CreateAnimationGroup()
			MP.WaitAnimation = MP.FadeOutAnimationGroup:CreateAnimation("DGV_FadeInMapWait")
			MP.WaitAnimation:SetDuration(DugisGuideViewer:GetDB(DGV_MAPPREVIEWDURATION))
			MP.WaitAnimation:SetOrder(1)
			MP.WaitAnimation:SetScript("OnPlay", function(self)
				WorldMapFrame:SetAlpha(1)
				if not MP.WaypointMapPing then
                    MP:InitializeWaypointMapPing()
				end
				--WorldMapFrame_UpdateMap()
				if MP.IsAnimating and MP:IsAnimating() then
					HideNonWaypointPOIs()
				end
				IteratePreviewElements(function(frame, index)
					if frame and not previewElementAlphas[index] then
						previewElementAlphas[index] = frame:GetAlpha()
					end
				end)
				IteratePreviewElements(function(frame, index)
                    if frame then
                        frame:SetAlpha(mapAlpha)
                        if frame.SetBorderAlpha then
                            frame:SetBorderAlpha(mapAlpha*255)
                        end
                        if frame.SetFillAlpha then
                            frame:SetFillAlpha(mapAlpha*255)
                        end
                    end
				end)

				if DGV.DugisArrow.waypoints and #DGV.DugisArrow.waypoints>0 then
					lastWaypoint = #DGV.DugisArrow.waypoints
					--DGV:DebugFormat("FadeInMap waitAnimation OnPlay", "x", DGV.DugisArrow.waypoints[1].x, "y", DGV.DugisArrow.waypoints[1].y)
					local wpx, wpy, wpm, wpf = DGV.DugisArrow.waypoints[lastWaypoint].x/100, DGV.DugisArrow.waypoints[lastWaypoint].y/100, DGV.DugisArrow.waypoints[lastWaypoint].map, DGV.DugisArrow.waypoints[lastWaypoint].floor
					local currentFloor = GetCurrentMapDungeonLevel()
					if wpf and currentFloor~=wpf then
						wpx, wpy = DGV:TranslateWorldMapPosition(wpm, wpf, wpx, wpy, wpm, currentFloor)
					end
					wpx = wpx * DugisMapOverlayFrame:GetWidth();
					wpy = -wpy * DugisMapOverlayFrame:GetHeight();
					MP.WaypointMapPing:SetPoint("CENTER", DugisMapOverlayFrame, "TOPLEFT", wpx, wpy)
					MP.WaypointMapPing:Show()
					DGV.DugisArrow.waypoints[lastWaypoint].worldmap:SetAlpha(1)
					if not IsWaypointWithinCurrentFloorArea() then
						LuaUtils:DugiSetMapByID(DGV.DugisArrow.waypoints[lastWaypoint].map)
					end
				end
				MP.WaypointMapPing:SetAlpha(255)
				--[[if DGV.CoordsFrame then
					DGV.CoordsFrame:SetAlpha(1)
				end]]
				if DGV.DugisArrow.map_overlay then
					DGV.DugisArrow.map_overlay:SetAlpha(1)
				end
				--PlaySound("MapPing");
				--MP.WaypointMapPing.timer = 1;
			end)
			MP.WaitAnimation:SetScript("OnUpdate", function(self)
				SupressNonPreviewElements()
			end)
			MP.WaitAnimation:SetScript("OnFinished", function()
				MP.WaypointMapPing:Hide()
			end)

			local fadeOutAnimation = MP.FadeOutAnimationGroup:CreateAnimation("DGV_FadeOutMap")
			fadeOutAnimation:SetDuration(.1)
			fadeOutAnimation:SetOrder(2)
			fadeOutAnimation:SetSmoothing("OUT")
			fadeOutAnimation:SetScript("OnFinished", function()
				--DGV:DebugFormat("FadeInMap fadeOutAnimation OnFinished")
				HideUIPanel(WorldMapFrame)
			end)
			fadeOutAnimation:SetScript("OnUpdate", function(self)
				SupressNonPreviewElements()
				local progress = self:GetSmoothProgress()
				WorldMapFrame:SetAlpha((1-progress)*mapAlpha)
			end)
		else
			--WorldMapFrame:Hide()
			--MP:SetAnimationHooks()
		end
		MP.SupressToggleMap = true
		--avoid closing guide frame when WorldMapFrame.Show won't cause taint
		if not InCombatLockdown() then
			WorldMapFrame:Show()
		else
			ShowUIPanel(WorldMapFrame)
		end

		MP.SupressToggleMap = false

		if MP:IsAnimating() then
			MP.FadeInAnimationGroup:Stop()
			MP.FadeOutAnimationGroup:Stop()
			MP.FadeOutAnimationGroup:Play()
		else
			MP.FadeInAnimationGroup:Play()
		end
		DGV.DugisArrow:DisableMapClicks()
	end
    
    function MP:InitializeWaypointMapPing()
        --prevents error on early load
		
        if not WorldMapFrame.ScrollContainer:GetLeft() then
            if MP.FadeOutAnimationGroup then
                MP.FadeOutAnimationGroup:Stop()
            end
            HideUIPanel(WorldMapFrame)
            return
        end
        MP.WaypointMapPing = CreateFrame("Model", nil, WorldMapFrame.ScrollContainer)
        MP.WaypointMapPing:SetModel([[Interface\MiniMap\Ping\MinimapPing.mdx]])
        MP.WaypointMapPing:SetWidth(100)
        MP.WaypointMapPing:SetHeight(100)
        --MP.WaypointMapPing:SetModelScale(.4)
        MP.WaypointMapPing:SetPoint("CENTER", WorldMapFrame.ScrollContainer)
        local scale = UIParent:GetEffectiveScale();
        local hypotenuse = ( ( GetScreenWidth() * scale ) ^ 2 + ( GetScreenHeight() * scale ) ^ 2 ) ^ 0.5;
        --DGV:DebugFormat("Debug FadeInMap: create MP.WaypointMapPing","WorldMapDetailFrame:GetLeft()", WorldMapDetailFrame:GetLeft())
        local coordRight = ( MP.WaypointMapPing:GetRight() - MP.WaypointMapPing:GetLeft() ) / hypotenuse; -- X
        local coordTop = ( MP.WaypointMapPing:GetTop() - MP.WaypointMapPing:GetBottom() ) / hypotenuse; -- Y
        MP.WaypointMapPing:SetPosition(coordRight * 0.5 + 0.0075, coordTop * 0.5 + 0.0075, 255)
        MP.WaypointMapPing:SetSequence(0)
    end


	--WorldMapFrame:HookScript("OnHide", function() ResetMapFade() end)

	hooksecurefunc("HideUIPanel", function(frame)
		if frame==WorldMapFrame then
			DGV:DebugFormat("HideUIPanel WorldMapFrame", "stack", debugstack(2, 20))
		end
		if frame==WorldMapFrame then
			ResetMapFade()
		end
	end)

	hooksecurefunc("QuestLogPopupDetailFrame_Show", function()
		if MP.IsAnimating and MP:IsAnimating() then
			if WorldMapFrame:IsShown() then HideUIPanel(WorldMapFrame) end
		end
	end)		

	function MP:Load()
		DGV:RegisterEvent("PLAYER_REGEN_DISABLED" );
		DGV:RegisterEvent("PLAYER_REGEN_ENABLED" );
	end

	function MP:Unload()
		DGV:UnregisterEvent("PLAYER_REGEN_DISABLED")
		DGV:UnregisterEvent("PLAYER_REGEN_ENABLED")
		
		ResetMapFade()
		MP:ResetCombatHooks()

-- 		if orig_WorldMapButton_OnUpdate then
-- 			WorldMapButton:SetScript("OnUpdate", orig_WorldMapButton_OnUpdate)
-- 		end
	end
end