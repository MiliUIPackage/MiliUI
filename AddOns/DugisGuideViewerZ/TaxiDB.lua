local DGV = DugisGuideViewer
if not DGV then return end
local L = DugisLocals
local _

local TaxiDB = DGV:RegisterModule("TaxiDB")
TaxiDB.essential = true

--DugisFlightmasterLookupTable
--DugisFlightmasterDataTable
--TaxiDataCollection

local authorMode = false

function TaxiDB:Initialize()
	function DGV:GuidToNpcId(guid)
		if not guid then return nil end
		return tonumber(string.match(guid, "^[^-]+-%d+-%d+-%d+-%d+-(%d+)"))
	end

	function DGV:PackXY(x, y)
		local factor = 2^16
		return floor(x*factor)*factor + floor(y*factor)
	end

	function PackStrings(...)
		local value
		for i=1,select("#", ...) do
			local ith = tostring((select(i, ...)))
			if not value then value = ith
			else value = value..":"..ith end
		end
		return value
	end

	local function UpdateLookupTable(cont, x, y)
		local npc = DGV:GuidToNpcId(UnitGUID("npc"))
		local tbl =  DGV.Modules.TaxiData:GetLookupTable()
		local lookup = tbl[cont]
		
		if not lookup then
		    tbl[cont] = {}
			lookup = tbl[cont]
		end
		local coord = DGV:PackXY(x,y)
		--[[for key,value in pairs(lookup) do
			if value==npc then
				lookup[key]=nil
			end
		end]] -- don't need to delete existing npc, for some reason Draenor TaxiNodePosition is not the same as TaxiScr or TaxiDest calls. 
		lookup[coord] = npc
	end

	local function GetCoord()
		local x,y = select(3, DGV:GetPlayerPosition())
		if y then return DGV:PackXY(x,y) end
	end
	
	function TaxiDB:UnhighlightAllFlightpoints()
		if WorldFlightMapFrame then
			local kids = { WorldFlightMapFrame:GetChildren() };
			for _, child in ipairs(kids) do
				local text = child:GetNormalTexture()
				text:SetVertexColor(1,1,1)
			end
			
			if not WorldFlightMapFrame.hookedOnShow then
				WorldFlightMapFrame:HookScript("OnShow", function()
					TaxiDB:UnhighlightAllFlightpoints()
				end)
				
				WorldFlightMapFrame.hookedOnShow = true
			end
		elseif FlightMapFrame then
			local activePool = FlightMapFrame.pinPools["FlightMap_FlightPointPinTemplate"]
			for pin in activePool:EnumerateActive() do 
				pin.Icon:SetVertexColor(1,1,1)
			end
			
			if not FlightMapFrame.hookedOnShow then
				FlightMapFrame:HookScript("OnShow", function()
					TaxiDB:UnhighlightAllFlightpoints()
				end)
				
				FlightMapFrame.hookedOnShow = true
			end
		elseif TaxiFrame then 
			for i=1,NumTaxiNodes() do
				local btn = _G["TaxiButton"..i]
				if btn and btn:GetNormalTexture() then 
					btn:GetNormalTexture():SetVertexColor(1,1,1)
				end
			end
		end
	end
	
	local function HighlightTaxiIconWithRed(normalTexture)
		normalTexture:SetVertexColor(1,0,0)
	end
	
	local function GetPointerCoord()
		local x,y = DGV:GetCurrentCursorPosition(DugisMapOverlayFrame)
		if y then return DGV:PackXY(x,y) end
	end
    
    local function HighlightFlightmasterDestination_on_WorldFlightMap(i)
		TaxiDB:UnhighlightAllFlightpoints()
        local kids = { WorldFlightMapFrame:GetChildren() };
        
        for _, child in ipairs(kids) do
            if (i == child:GetID()) then
				HighlightTaxiIconWithRed(child:GetNormalTexture())
            end
        end
    end
    
    local is_WorldFlightMapFrame_Hooked = false
    
    local function TryTakeTaxiNode(i)
        if DGV:UserSetting(DGV_AUTOFLIGHTPATHSELECT) == true and not IsPlayerMoving() then
            TakeTaxiNode(i)
        elseif DGV:UserSetting(DGV_AUTOFLIGHTPATHSELECT) == true then
            UIErrorsFrame:AddMessage(ERR_TAXIPLAYERMOVING,1,1,0,1)
        end
    end    
    
	
	local function HighlightFlightmasterDestination()
    	TaxiDB:UnhighlightAllFlightpoints()
        if is_WorldFlightMapFrame_Hooked == false and WorldFlightMapFrame ~= nil then
            hooksecurefunc(WorldFlightMapFrame, "WORLD_MAP_UPDATE", function() 
                HighlightFlightmasterDestination()
            end)
            is_WorldFlightMapFrame_Hooked = true
        end
    
		if DGV.Modules.DugisArrow.waypoints then
			for _, waypoint in pairs(DGV.Modules.DugisArrow.waypoints) do
				if waypoint.flightMasterID then
					for i=1,NumTaxiNodes() do
						local x,y = TaxiNodePosition(i)
						local cont = GetCurrentMapContinent_dugi()
                        
                        --Prevent Lua error on max zoom out
                        if DGV.Modules.TaxiData:GetLookupTable()[cont] == nil then
                            return
                        end
						local loopNPC = DGV.Modules.TaxiData:GetLookupTable()[cont][DGV:PackXY(x,y)]
						if loopNPC and waypoint.flightMasterID==loopNPC then
                            if WorldFlightMapFrame == nil then
                                --For Broken Isles or Argus
                                if cont == 8 or cont == 9 or cont == 875 or cont == 876 then
                                    local activePool = FlightMapFrame.pinPools["FlightMap_FlightPointPinTemplate"]
                                    for pin in activePool:EnumerateActive() do 
                                        local pinSlot = pin.taxiNodeData.slotIndex
                                        if i == pinSlot then
                                            TryTakeTaxiNode(i)
											HighlightTaxiIconWithRed(pin.Icon)
                                        end
                                        
										if not pin.hooledOnLeave then
											pin:HookScript("OnLeave", function()
												HighlightFlightmasterDestination()
											end)
											pin.hooledOnLeave = true
										end
                                        
                                    end
                                else
                                    local btn = _G["TaxiButton"..i]
                                    
                                    if btn and btn:GetNormalTexture() then
                                        TryTakeTaxiNode(i)
										HighlightTaxiIconWithRed(btn:GetNormalTexture())
                                    end
                                end
                            else
                                --Auto path select
                                if DGV:UserSetting(DGV_AUTOFLIGHTPATHSELECT) == true and not IsPlayerMoving() then
                                    TakeTaxiNode(i)
                                elseif DGV:UserSetting(DGV_AUTOFLIGHTPATHSELECT) == true then
                                    UIErrorsFrame:AddMessage(ERR_TAXIPLAYERMOVING,1,1,0,1)
                                end
                            
                                HighlightFlightmasterDestination_on_WorldFlightMap(i)
                            end
						end
					end
				end
			end
		end
	end
	
	function DGV:PLAYER_STOPPED_MOVING()
		if DGV:UserSetting(DGV_AUTOFLIGHTPATHSELECT) == true and TaxiFrame:IsShown() then
			HideUIPanel(TaxiFrame);
		end
	end
	
	TaxiDB.routeToRecalculate = {}
	function DGV:TAXIMAP_OPENED()
        UpdateCurrentBeaconMode()
        
		--if WorldMapFrame:IsShown() then HideUIPanel(WorldMapFrame) end
		LuaUtils:DugiSetMapToCurrentZone()
		local cont, newContId = GetCurrentMapContinent_dugi()
		local recalulateRoute = false
		if not DugisFlightmasterDataTable then 
			DugisFlightmasterDataTable = {}
		end
		if not DugisFlightmasterDataTable[cont] then 
			DugisFlightmasterDataTable[cont] = {}
			if TaxiDB.routeToRecalculate.desc then
				recalulateRoute = true
			end
		end

		local key = DGV:GuidToNpcId(UnitGUID("npc"))
        
        local isCurrentMasterAFerryMaster = DGV.Modules.TaxiData:IsFerryMaster(key)

		if not key then return end
		local direct = {}
		local indirect = {}
		local fullData = DGV.Modules.TaxiData:GetFullData()
		for i=1,NumTaxiNodes() do
			local x,y = TaxiNodePosition(i)
			local nodeType = TaxiNodeGetType(i)
			local name = TaxiNodeName(i)
			
			y = 1 - y
			
			local tbl =  DGV.Modules.TaxiData:GetLookupTable()
			local packed = DGV:PackXY(x,y)
			local contitnentTable = tbl[cont]
			
			local npc = contitnentTable and contitnentTable[packed]
            
            local isCurrentNodeAFerryMaster = DGV.Modules.TaxiData:IsFerryMaster(npc)
            if isCurrentNodeAFerryMaster == isCurrentMasterAFerryMaster then
                        
			if npc and not DugisFlightmasterDataTable[cont][npc] and nodeType=="REACHABLE" then
				DugisFlightmasterDataTable[cont][npc] = {}
			end
					
			if DugisFlightmasterDataTable[cont][npc] and nodeType~="REACHABLE" then 
				DugisFlightmasterDataTable[cont][npc] = nil
			end
			
			if DugisFlightmasterDataTable[cont][npc] and not DugisFlightmasterDataTable[cont][npc].m and fullData and fullData[cont] then
				DugisFlightmasterDataTable[cont][npc].m = fullData[cont][npc] and fullData[cont][npc].m
				DugisFlightmasterDataTable[cont][npc].f = fullData[cont][npc] and fullData[cont][npc].f
				DugisFlightmasterDataTable[cont][npc].coord = fullData[cont][npc] and fullData[cont][npc].coord
			end			
			
			if name and DugisFlightmasterDataTable[cont][npc] and not DugisFlightmasterDataTable[cont][npc].name then
				DugisFlightmasterDataTable[cont][npc].name = name
			end
			
			if nodeType=="CURRENT" then
				UpdateLookupTable(cont, x, y)
			elseif nodeType=="REACHABLE" and GetNumRoutes(i)==1 then
				UpdateLookupTable(cont, TaxiGetSrcX(i, 1), TaxiGetSrcY(i, 1))
				local dx, dy = TaxiGetDestX(i, 1), TaxiGetDestY(i, 1)
				local directNpc = DGV.Modules.TaxiData:GetLookupTable()[cont][DGV:PackXY(dx,dy)]
				tinsert(direct, directNpc or "XY-"..DGV:PackXY(dx,dy))
			elseif nodeType=="REACHABLE" then
				UpdateLookupTable(cont, TaxiGetSrcX(i, 1), TaxiGetSrcY(i, 1))
				local path = {}
				for j=1, GetNumRoutes(i) do
					local dx, dy = TaxiGetDestX(i, j), TaxiGetDestY(i, j)
					local indirectNpc = DGV.Modules.TaxiData:GetLookupTable()[cont][DGV:PackXY(dx,dy)]
					tinsert(path, indirectNpc or "XY-"..DGV:PackXY(dx,dy))
				end
				tinsert(indirect, PackStrings(unpack(path)))
			end
           
            end
		end

		local globalData = fullData[cont] and fullData[cont][key]
		if not DugisFlightmasterDataTable[cont][key] or
			not DugisFlightmasterDataTable[cont][key].m
		then
			DugisFlightmasterDataTable[cont][key] =
			{
				m = (globalData and globalData.m) or DGV:GetCurrentMapID() ,
				f = (globalData and globalData.f) or GetCurrentMapDungeonLevel(),
				coord = (globalData and globalData.coord) or GetCoord(),

			}
		end
		local newDirect = PackStrings(unpack(direct))
		if not globalData or globalData.direct~=newDirect then
			DugisFlightmasterDataTable[cont][key].direct = newDirect
		end
		for _, rt in ipairs(indirect) do
			if (not globalData or not tContains(globalData, rt)) and
				not tContains(DugisFlightmasterDataTable[cont][key], rt)
			then
				tinsert(DugisFlightmasterDataTable[cont][key], rt)
			end
		end
		
		local fullDataContTable = fullData[cont]
		if fullDataContTable then
			for key,globalData in pairs(fullDataContTable) do
				if globalData.overridePlayerData then
					DugisFlightmasterDataTable[cont][key] = globalData
				end
			end
		end
		
		if recalulateRoute or (DGV:IsModuleLoaded("Guides") and DGV.actions[DugisGuideUser.CurrentQuestIndex] == "f") then
			CloseTaxiMap()
			PlaySoundFile("sound\\interface\\magicclick.ogg")
			UIErrorsFrame:AddMessage(L["DG: Flight master data updated!"],1,1,0,1)			
			if recalulateRoute then
				DGV:RemoveAllWaypoints()	
				DGV.Modules.DugisArrow:VisitFlightmaster(key)
				DGV.SetSmartWaypointNoThread = true
				DGV:SetSmartWaypoint(
					TaxiDB.routeToRecalculate.m, 
					TaxiDB.routeToRecalculate.f, 
					TaxiDB.routeToRecalculate.x*100, 
					TaxiDB.routeToRecalculate.y*100, 
					TaxiDB.routeToRecalculate.desc)
				DGV.SetSmartWaypointNoThread = false
			end
			if (DGV:IsModuleLoaded("Guides") and DGV.actions[DugisGuideUser.CurrentQuestIndex] == "f") then
				DGV:SetChkToComplete(DugisGuideUser.CurrentQuestIndex)
				DGV:MoveToNextQuest()
			end
		end
		HighlightFlightmasterDestination()
	end
    
    hooksecurefunc("TaxiNodeOnButtonLeave", function()
        HighlightFlightmasterDestination()
    end)
    
	function TaxiDB:GetPackedPlayerLocation()
		local mapId,level = DGV:GetCurrentMapID() 
		local coord = GetCoord()
		if coord then
			return PackStrings(mapId, level, coord)
		end
	end
	
	--/run DugisGuideViewer.Modules.TaxiDB:ShowLocation()
	function TaxiDB:ShowLocation(forceMapZone, forceLevel)
		local mapId,level = DGV:GetCurrentMapID() 
		local coord = GetCoord()
		if coord then
			DGV:DebugFormat("ShowLocation", "player location", PackStrings(mapId, level, coord))
		end
		coord = GetPointerCoord()
		if coord then
			local x,y = DGV:UnpackXY(coord)
			if forceMapZone then
				coord = DGV:PackXY(DGV:TranslateWorldMapPosition(
					mapId, level, x, y, forceMapZone, level))
				mapId = forceMapZone
			end
			DGV:DebugFormat("ShowLocation", "pointer location", PackStrings(mapId, level, coord))
			
            local positionMapInfo = C_Map.GetMapInfoAtPosition(mapId, x,y);	
			if positionMapInfo and positionMapInfo.mapID then
				local zoneId = positionMapInfo.mapID
				DGV:DebugFormat("ShowLocation", "pointer map trans", zoneId)
				DGV:DebugFormat("ShowLocation", "pointer map trans relative", 
						PackStrings(level, DGV:PackXY(DGV:TranslateWorldMapPositionGlobal(
							mapId, x, y, zoneId))))
			end
		end
	end
	
	--/run DugisGuideViewer.Modules.TaxiDB:StartWatch()
	local watchVal
	function TaxiDB:StartWatch()
		watchVal = GetTime()
		DGV:DebugFormat("StartWatch")
		TaxiDB:ShowLocation()
	end
	
	--/run DugisGuideViewer.Modules.TaxiDB:StopWatch()
	function TaxiDB:StopWatch()
		if watchVal then
			local stopVal = GetTime()
			DGV:DebugFormat("StopWatch", "elapsed", stopVal-watchVal)
			TaxiDB:ShowLocation()
		end
	end
	
	--[[local function StoreZoneDataPostTeleport()
		local currentLevel = GetCurrentMapDungeonLevel()
		DGV:DebugFormat("OnZoneChanged", "currentMapId", currentMapId, "lastCast", DugisUnboundTeleports.lastCast)
		for portId,data in pairs(DGV.Modules.TaxiData.UnboundTeleportData) do
			local spellId,_,_,loc = strsplit(":", data)
			if not loc and DugisUnboundTeleports.lastCast==tonumber(spellId) then
				DugisUnboundTeleports[portId] = 
					PackStrings(spellId, currentMapId, currentLevel, GetCoord())
			end
		end
		DugisUnboundTeleports.lastCast = nil
	end]]

	function DGV:LogInkeeper()
		local coord = GetCoord()
		if coord then
			local npc = DGV:GuidToNpcId(UnitGUID("target"))
			local innLine = string.format("7:%s:%s:%s", 
						coord,
						npc,
						GetBindLocation())
			if not TaxiDataCollection.Inkeepers then
				TaxiDataCollection.Inkeepers = {}
			end
			TaxiDataCollection.Inkeepers[UnitName("target")] = innLine
		end
	end
	
	local function OnZoneChanged()
		
	end
	
	function TaxiDB:OnZoneChanged()
		local mapId = DGV:GetCurrentMapID() 
		if not TaxiDataCollection then
			TaxiDataCollection = {}
		end
		if TaxiDataCollection.lastMapId~=mapId then
			OnZoneChanged()
		end
		TaxiDataCollection.lastMapId = mapId
	end
	
	function TaxiDB:OnModulesLoaded()
		if authorMode then
			hooksecurefunc("TaxiNodeCost", function(event)
				local cont = GetCurrentMapContinent_dugi()
				--if ( event == "TAXIMAP_OPENED" ) then
					if cont == 8 or cont == 9 or cont == 875 or cont == 876 then
					for i=1,NumTaxiNodes() do
						local xyKey = DGV:PackXY(TaxiNodePosition(i))
						local lookup = DGV.Modules.TaxiData:GetLookupTable()[cont][xyKey]				
						local activePool = FlightMapFrame.pinPools["FlightMap_FlightPointPinTemplate"]
						for pin in activePool:EnumerateActive() do 
							local pinSlot = pin.taxiNodeData.slotIndex
							if i == pinSlot and not lookup then
								HighlightTaxiIconWithRed(pin.Icon)
							end
						end
					end
				   else

					for i=1,NumTaxiNodes() do
						local btn = _G["TaxiButton"..i]
						if btn and btn:GetNormalTexture() then
							local xyKey = DGV:PackXY(TaxiNodePosition(i))
							local lookup = DGV.Modules.TaxiData:GetLookupTable()[cont][xyKey]
							if not lookup then
								btn:GetNormalTexture():SetTexture(1,0,0)
							elseif not DugisFlightmasterDataTable[cont][lookup] or not DugisFlightmasterDataTable[cont][lookup].m then
								btn:GetNormalTexture():SetTexture(0,0,1)
							end
						end
					end
				end
				--end
			end)
			
			if not TaxiDataCollection then
				TaxiDataCollection = {}
			end
			if not TaxiDataCollection.ZoneTransData then 
				TaxiDataCollection.ZoneTransData = DGV.Modules.TaxiData.ZoneTransData
			end
			local previewPointPool = {}
			local previewPoints = {}
			local function GetCreatePreviewPoint()
				local ppt = tremove(previewPointPool)
				if not ppt then
					ppt = CreateFrame("Button", nil, DugisMapOverlayFrame)
					ppt:RegisterForClicks("RightButtonUp")
					ppt:SetScript("OnClick", 
						function()
							if IsControlKeyDown() then
								ppt:RemoveMe()
							end
						end)
					ppt.icon = ppt:CreateTexture("ARTWORK")
					ppt.icon:SetAllPoints()
					ppt.icon:Show()
					ppt.icon:SetTexture("Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\circular")
					ppt:SetHeight(32)
					ppt:SetWidth(32)
				end
				ppt.icon:SetVertexColor(0, 1, 0)
				ppt:Show()
				tinsert(previewPoints, ppt)
				return ppt
			end
			
			local function RemoveValue(contData, mTrans, mDest)-- level, coord)
				--[[local newVal = PackStrings(level, coord)
				
				local existing = contData[mTrans][mDest]
				DGV:DebugFormat("RemoveValue", "existing", existing, "newVal", newVal, "strfind", {strfind(existing, newVal)})
				local start,finish = strfind(existing, newVal)
				existing = strtrim(strsub(existing, 1, start-1), ":")..strtrim(strsub(existing, finish+1), ":")
				DGV:DebugFormat("RemoveValue", "existing", existing)
				if strlen(existing)==0 then existing=nil end

				contData[mTrans][mDest] = existing]]
				contData[mTrans][mDest] = nil
			end
		
			function TaxiDB:OnMapChangedOrOpen()
				if not WorldMapFrame:IsShown() then return end
				while #(previewPoints)>0 do
					local ppt = tremove(previewPoints)
					ppt:Hide()
					tinsert(previewPointPool, ppt)
				end
				local mapId = DGV:GetCurrentMapID() 
				local c = GetMapContinent_dugi(mapId)
				local contData = TaxiDataCollection.ZoneTransData[c]
				if contData and contData[mapId] then
					for mDest,data in pairs(contData[mapId]) do
						if mDest~="requirements" then
							local dataTbl = {strsplit(":", data)}
							for i=1,#(dataTbl),2 do
								local ppt = GetCreatePreviewPoint()
								local requirements = contData[mDest] and contData[mDest].requirements
								--DGV:DebugFormat("UpdateMap", "mDest", mDest, "contData[mDest]",contData[mDest], "requirements", requirements)
								if requirements then
									if strmatch(requirements, "Alliance") then
										ppt.icon:SetVertexColor(0, 0, 1)
									elseif strmatch(requirements, "Horde") then
										ppt.icon:SetVertexColor(1, 0, 0)
									end
								end
								ppt.RemoveMe = function()
									RemoveValue(
										contData, 
										mapId,
										mDest)
									RemoveValue(
										contData,
										mDest, 
										mapId)
									ppt:Hide()
								end
								DGV:PlaceIconOnWorldMap(
									WorldMapButton, 
									ppt, 
									mapId, 
									tonumber(dataTbl[i]), 
									DGV:UnpackXY(dataTbl[i+1]))
							end
						end
					end
				end
			end
			
			local function AddValue(contData, mTrans, mDest, level, coord)
				local newVal = PackStrings(level, coord)
				if not contData[mTrans] then contData[mTrans] = {} end
				local existing = contData[mTrans][mDest]
				if existing then
					newVal = PackStrings(existing, newVal)
				end
				contData[mTrans][mDest] = newVal
			end
		else
			if TaxiDataCollection then
				TaxiDataCollection.ZoneTransData = nil
			end
			DugisFlightmasterLookupTable = nil
		end
	end
	
-- 	WorldFrame:HookScript("OnMouseUp",function(...)
-- 		DGV:DebugFormat("WorldFrame.OnMouseUp", 
-- 			"GetCursorInfo", {GetCursorInfo()},
-- 			"changed", SetCursor("Interface\\Cursor\\Interact.blp"))
-- 		ResetCursor()
-- 	end)

	function TaxiDB:Load()
		DGV:RegisterEvent("TAXIMAP_OPENED")
		DGV:RegisterEvent("PLAYER_STOPPED_MOVING")

		if not TaxiDataCollection then
			TaxiDataCollection = {}
		end
		--DGV:DebugFormat("TaxiDB:Load", "DugisFlightmasterDataTable", DugisFlightmasterDataTable)
		if DugisFlightmasterDataTable then
			for cont, tbl in pairs(DugisFlightmasterDataTable) do
				--DGV:DebugFormat("TaxiDB:Load", "cont", cont)
				for id,data in pairs(tbl) do
					--DGV:DebugFormat("TaxiDB:Load", "data.direct", data.direct)
					local direct = {}
					if data.direct then
						for _, val in ipairs({strsplit(":", data.direct)}) do
							if strsub(val, 1, 3)=="XY-" then
								local loc = strsub(val, 4)
								if cont and tonumber(loc) then
									local contData = DGV.Modules.TaxiData:GetLookupTable()[cont]
									if contData then
										local lookup =  contData[tonumber(loc)]
										tinsert(direct, lookup or val)
									end
								end
							else
								tinsert(direct, val)
							end
						end
					end
					data.direct = PackStrings(unpack(direct))
					local indirect = {}
					local newData = {}
					while #data>0 do
						wipe(indirect)
						local hops = data[1]
						for _, val in ipairs({strsplit(":", hops)}) do
							if strsub(val, 1, 3)=="XY-" then
								local loc = strsub(val, 4)
								if cont and tonumber(loc) then
									local contData = DGV.Modules.TaxiData:GetLookupTable()[cont]
									if contData then
										local lookup =  contData[tonumber(loc)]
										tinsert(indirect, lookup or val)
									end
								end
							else
								tinsert(indirect, val)
							end
						end
						local packt = PackStrings(unpack(indirect))
						if not tContains(newData, packt) then
							tinsert(newData, packt)
						end
						tremove(data, 1)
					end
					for _, val in ipairs(newData) do
						tinsert(data, val)
					end
				end
			end
		end
	end
	
	function TaxiDB:Unload()
		DGV:UnregisterEvent("TAXIMAP_OPENED")
		DGV:UnregisterEvent("PLAYER_STOPPED_MOVING")
	end
end
