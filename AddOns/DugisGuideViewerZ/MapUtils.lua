--local mapdata = LibStub("LibMapData-1.0-Dugi")
--local astrolabe = DongleStub("Astrolabe-1.0-Dugi")
local DGV = DugisGuideViewer
--DGV.astrolabe = astrolabe
--DGV.mapdata = mapdata
local GetCreateTable, InitTable = DGV.GetCreateTable, DGV.InitTable
local oldAreaId2terrainMapId = oldAreaId2terrainMapId
local GetCurrentMapZone_export = GetCurrentMapZone_export
local GetCurrentMapDungeonLevel_export = GetCurrentMapDungeonLevel_export
local DungeonUsesTerrainMap_export = DungeonUsesTerrainMap_export
local _

local HBD = LibStub("HereBeDragons-2.0", true)
local pins = LibStub("HereBeDragons-Pins-2.0")
local HBDMigrate = LibStub("HereBeDragons-Migrate")

HBD_PINS_EVERYWHERE = 10002

local WORLD_MAP_ID = 947


---------------------------------------
---------- Polyfills for 8.0 ----------
---------------------------------------

--Returns currently active (displayed in World map Frame) map id in case WorldMapFrame is shown. 
--In case WorldMapFrame is not shown it returns GetBestMapForUnit
--todo: check if this function is used propertly in all places. In some places maybe better would be use  C_Map.GetBestMapForUnit("player") functiin  
DGV.GetCurrentMapID = function()
	if WorldMapFrame:IsShown() then
		return WorldMapFrame:GetMapID()
	end
    --Sometimes when moving from one zone to another C_Map.GetBestMapForUnit("player") returns nil
	return C_Map.GetBestMapForUnit("player") or WorldMapFrame:GetMapID()
end

if GetCurrentMapDungeonLevel == nil then
	GetCurrentMapDungeonLevel = function()
		return 0
	end
end

GetCurrentMapDungeonLevel_dugi = function()
	return UiMapId2Floor(C_Map.GetBestMapForUnit("player"))
end

--oldContinentId - one of values returned by old GetCurrentMapContinent
function OldContinent2UiMapID(oldContinentId)
	local map = {
	 [1] = 12      --Kalimdor         
	,[2] = 13      --Eastern Kingdoms 
	,[3] = 101      --Outland          
	,[4] = 113      --Northrend        
	,[5] = 948     --The Maelstrom    
	,[6] = 424     --Pandaria         
	,[7] = 572     --Draenor          
	,[8] = 619     --Broken Isles     
	,[9] = 905     --Argus            
	}

	return map[oldContinentId] or oldContinentId
end

--result - one of values returned by old GetCurrentMapContinent
local function ContinentUiMapID2OldContinent(ContinentUiMapID)
	local map = {
		 [12 ] = 1     --Kalimdor         
		,[13 ] = 2     --Eastern Kingdoms 
		,[101] = 3      --Outland          
		,[113] = 4      --Northrend        
		,[948] = 5     --The Maelstrom    
		,[424] = 6     --Pandaria         
		,[572] = 7     --Draenor          
		,[619] = 8     --Broken Isles     
		,[905] = 9     --Argus           
	}

	return map[ContinentUiMapID] or ContinentUiMapID
end

--Returns old continent id
GetMapContinent_dugi = function(currentMapId)
	while currentMapId ~= nil do
		local mapInfo = C_Map.GetMapInfo(currentMapId)
		
		if not mapInfo then
			return
		end
		
		if  mapInfo.mapType == Enum.UIMapType.Continent then
			return ContinentUiMapID2OldContinent(currentMapId), currentMapId
		end
		
		currentMapId = mapInfo.parentMapID
	end
end


GetCurrentMapContinent_dugi = function()
	local cont = GetMapContinent_dugi(DGV:GetCurrentMapID())
	return ContinentUiMapID2OldContinent(cont), cont
end

--Check if currently displayed map id a continent
IsCurrentMapContinent = function()
	local info = C_Map.GetMapInfo(DGV:GetCurrentMapID())
	return info.mapType == Enum.UIMapType.Continent
end

GetMapContinent_dugiNew = function(currentMapId)
	local _, ret = GetMapContinent_dugi(currentMapId)
	return ret
end

GetMapContinent_dugiOld = function(currentMapId)
	local old, ret = GetMapContinent_dugi(currentMapId)
	
	if currentMapId == 213 then
		return 12
	end
	
	return old
end

--For new maps this function returns nil
UiMapId2Floor = function(uiMapId)
	return select(2, HBDMigrate:GetLegacyMapInfo(uiMapId))
end

function GetCorpseMapPosition_dugi()
	local pos = C_DeathInfo.GetCorpseMapPosition(DGV:GetCurrentMapID())
	if pos then
		return pos.x, pos.y
	end
end


function DGV:Waypoint2MapCoordinates(waypoint)
    local wpx, wpy, wpm, wpf = waypoint.x/100, waypoint.y/100, waypoint.map, waypoint.floor
    local currentFloor = GetCurrentMapDungeonLevel()
    if wpf and currentFloor~=wpf then
        wpx, wpy = DGV:TranslateWorldMapPosition(wpm, wpf, wpx, wpy, wpm, currentFloor)
    end
    wpx = wpx * DugisMapOverlayFrame:GetWidth();
    wpy = -wpy * DugisMapOverlayFrame:GetHeight();

    return wpx, wpy
end

function DGV:IsPlayerPosAvailable()
	local x, y = HBD:GetPlayerZonePosition(true, false)
    return x ~= nil and y ~= nil 
end

--/run DGV:ShowMapData(mapId, ...)
function DGV:ShowMapData(mapId, ...)
	local tbl = {}
	local mapData = {}
	tbl[mapId] = mapData
	local numFloors = select("#", ...)
	LuaUtils:DugiSetMapByID(mapId)
	local _, TLx, TLy, BRx, BRy = GetCurrentMapZone();
	if ( TLx and TLy and BRx and BRy ) then
		if not ( TLx < BRx ) then
			TLx = -TLx;
			BRx = -BRx;
		end
		if not ( TLy < BRy) then
			TLy = -TLy;
			BRy = -BRy;
		end
		mapData.width = BRx - TLx
		mapData.height = BRy - TLy
		mapData.xOffset = TLx
		mapData.yOffset = TLy
	end
	if ( numFloors > 0 ) then
		for i = 1, numFloors do
			local f = select(i, ...)
			local _, TLx, TLy, BRx, BRy = GetCurrentMapDungeonLevel();
			if ( TLx and TLy and BRx and BRy ) then
				mapData[f] = {};
				if not ( TLx < BRx ) then
					TLx = -TLx;
					BRx = -BRx;
				end
				if not ( TLy < BRy) then
					TLy = -TLy;
					BRy = -BRy;
				end
				mapData[f].width = BRx - TLx
				mapData[f].height = BRy - TLy
				mapData[f].xOffset = TLx
				mapData[f].yOffset = TLy
			end
		end
	end
	DGV:DebugFormat("ShowMapData", "tbl", tbl)
end

--In case Worl Map Frame is opened it returns currently dosplayed map id
--In case Worl Map Frame is closed it returns  map id where the player is currently on
function DGV:GetDisplayedOrPlayerMapId()
	if WorldMapFrame:IsShown() then
		return WorldMapFrame:GetMapID()
	end
	return C_Map.GetBestMapForUnit("player")
end

function DGV:GetDisplayedMapNameOld()
	local id = WorldMapFrame:GetMapID()
	return select(3, HBDMigrate:GetLegacyMapInfo(id))
end

function DGV:GetMapNameFromID(UiMapID, oldAreaId)
	if UiMapID then 
		local info = C_Map.GetMapInfo(UiMapID)
		return info and info.name -- get it from game. 
	end
end

function DGV:GetMapIDFromName(mapName)
	if mapName then
		return HBD.mapName2MapId[mapName]
	else
		return 0
	end 
end

--[[function DGV:InitMapping( )
	DGV:initAnts()
	DGV.DugisArrow:initArrow()
end]]

--Translates local 0-1 to local 0-1 coordinates 
--Returns 0-1, 0-1
--In case uIMapID1 and uIMapID2 are on different continents this function doesn't work correctly (returns nil, nil)
function DGV:TranslateWorldMapPosition(UIMapID1, _, x, y, UIMapID2)
	return HBD:TranslateZoneCoordinates(x, y, UIMapID1, UIMapID2, true)
	--return astrolabe:TranslateWorldMapPosition(map, floor, x, y, M, F)
end

function DGV:IsOnAzeroth(uIMapID)
	while uIMapID ~= nil do
		local mapInfo = C_Map.GetMapInfo(uIMapID)
		
		if not mapInfo then
			return false
		end
        
		if mapInfo.mapType == Enum.UIMapType.World then
			return true
		end       
        
        --Argus / Wandering Isle should be not considered as map on Azeroth 
		if mapInfo.parentMapID == 905 or mapInfo.parentMapID == 947 then
			return false
		end            
		
		uIMapID = mapInfo.parentMapID
	end
end

--Translates x,y (0-1) coordinates from uIMapID1 zone to uIMapID2 zone
--Both uIMapID1 and uIMapID2 must be located on Azeroth
function DGV:TranslateWorldMapPositionViaAzeroth(uIMapID1, x, y, uIMapID2)
    local xAzeroth, yAzeroth = HBD:TranslateZoneCoordinates(x, y, uIMapID1, WORLD_MAP_ID, true)
    return HBD:TranslateZoneCoordinates(xAzeroth, yAzeroth, WORLD_MAP_ID, uIMapID2, true)
end

--Translates x,y (0-1) coordinates from uIMapID1 zone to uIMapID2 zone.
--In case uIMapID1 and uIMapID2 are on different continents TranslateWorldMapPosition doesn't work correctly so that function should not be used in such cases
function DGV:TranslateWorldMapPositionGlobal(uIMapID1, x, y, uIMapID2)
    if DGV:IsOnAzeroth(uIMapID1) and DGV:IsOnAzeroth(uIMapID2) then
        return DGV:TranslateWorldMapPositionViaAzeroth(uIMapID1, x, y, uIMapID2)
    else
        return HBD:TranslateZoneCoordinates(x, y, uIMapID1, uIMapID2, true)
    end
end

function DGV:PlaceIconOnMinimap( icon, mapID, mapFloor, x, y, showInParentZone_, floatOnEdge_)
	local showInParentZone = true
	local floatOnEdge = true
	
	if floatOnEdge_ ~= nil then
		floatOnEdge = floatOnEdge_
	end
	
	if showInParentZone_ ~= nil then
		showInParentZone = showInParentZone_
	end
	
	if x and y and mapID then
		pins:AddMinimapIconMap("loc"..x.."_"..y, icon, mapID , x, y, showInParentZone, floatOnEdge, true)
		icon.ref = "loc"..x.."_"..y
	end
end

function DGV:RemoveIconFromMinimap(icon)
	pins:RemoveMinimapIcon(icon.ref, icon)
end

function DGV:RemoveWorldMapIcon(icon)
	pins:RemoveWorldMapIcon(icon.ref, icon)
end

-- If forcedAbsoluteX and forcedAbsoluteY are nill the absolute position of the icon will not be calculated but forcedAbsoluteX and forcedAbsoluteY will be used instead

function DGV:PlaceIconOnWorldMap( frame, icon, mapID, mapFloor, x, y, forcedAbsoluteX, forcedAbsoluteY, showFlag)		
	if x and y and mapID then
        local ref = "loc"..x.."_"..y..mapID
		pins:AddWorldMapIconMap(ref, icon, mapID , x, y, showFlag or HBD_PINS_EVERYWHERE)
        icon.ref = ref
	end
	
	DGV:CheckForArrowChange()
	
	if DGV.WrongInstanceFloor --[[or not DGV.WaypointsShown]] then
		icon.icon:Hide()
	else
		icon.icon:Show()
	end
end

--todo: check ifall references use uiMapIDs with this function
function DGV:ComputeDistance( uiMapID1, _, x1, y1, uiMapID2, _, x2, y2 )
	local dist, dx, dy = HBD:GetZoneDistance(uiMapID1, x1, y1, uiMapID2, x2, y2)
	if dx and dy then
		return dist, -dx, -dy
	end
	return dist, dx, dy
end

--Accepts uiMapIDs
function DGV:GetMapDimension(uiMapID)
	return HBD:GetZoneSize(uiMapID)
end

local lastM, lastF = 0, 0
local GetCurrentMapDimension_cache = nil
function DGV:GetMapDimensionCached(m)
	if lastM ~= m or GetCurrentMapDimension_cache == nil then
		GetCurrentMapDimension_cache = {DGV:GetMapDimension(m)}
	end
	lastM = m
	return unpack(GetCurrentMapDimension_cache)
end

function DGV:IsValidDistance( uiMapID, f, x, y )
	local dist, dx, dy = DGV:GetDistanceFromPlayer(uiMapID, f, x, y)
	if dist and dx and dy then
		return true
	end
end

--x, y - 0-100
--
--todo:check references to GetDistanceFromPlayer and if first parameter is uiMapID
function DGV:GetDistanceFromPlayer(uiMapID, f, x, y)
	local pmap, _, px, py = DGV:GetPlayerPosition()
	--return astrolabe:ComputeDistance(pmap, pfloor, px, py, m, f, x/100, y/100) 
	local distance =  HBD:GetZoneDistance(pmap, px, py, uiMapID, x/100, y/100)
	return distance
end

function DGV:WorldMapFrameOnShow()
	DGV:OnMapChangeUpdateArrow( )
end

function DGV:WorldMapFrameOnHide()
	if DugisArrowGlobal.waypoints then
		LuaUtils:foreach(DugisArrowGlobal.waypoints, function(waypoint) 
			if not WorldMapFrame:IsShown() then 
				waypoint.worldmap:Hide()  
			end  
		end)
	end
end

WorldMapFrame:HookScript( "OnShow", DGV.WorldMapFrameOnShow )
WorldMapFrame:HookScript( "OnHide", DGV.WorldMapFrameOnHide )

--/run print(DugisGuideViewer:GetUnitPosition())
--Returns position 0-1, 0-1 on the map on which the player currently is.
--unit is ignored as anyway only this function isusedfor player
--2018-05-01 - works in the same way as the old one (except returned floor is always 0 and unit is ignored - player assumed)
--The result might be different than expected result for currently displayed map. HBD:GetPlayerZonePosition is using the best map for unit not currently opened map in WorldMapFrame.
--To use currently displayed map in world map frame pass useCurrentlyDisplayedMap with value true
function DGV:GetUnitPosition( unit, noMapChange, useCurrentlyDisplayedMap, allowOutOfBounds)
	local x, y, currentPlayerUIMapID, currentPlayerUIMapType = HBD:GetPlayerZonePosition(allowOutOfBounds, useCurrentlyDisplayedMap)
	return currentPlayerUIMapID, 0, x, y;
end

--replacement for old GetPlayerMapPosition
function DGV:GetPlayerMapPosition(allowOutOfMap)
	local _, _, x, y = DGV:GetPlayerPosition()
	
	if x == nil or y == nil or ((x < 0 or y < 0 or x > 1 or y > 1) and not allowOutOfMap) then
		return 0, 0 
	end
	
	return x, y
end

function DGV:GetPlayerPositionOnMap(destMapId, allowOutOfBounds)
	local x, y, mapId =  DGV:GetPlayerLocalPosition(allowOutOfBounds)
    return DGV:TranslateWorldMapPositionGlobal(mapId, x, y, destMapId)
end

--returns x, y, mapId
function DGV:GetPlayerLocalPosition(allowOutOfBounds)
	return HBD:GetPlayerZonePosition(allowOutOfBounds, false)
end

--Returns 0-1,0-1 coordinates on currently active (displayer in World Map Frame) map - might be not the same ascurrent players map.
--2018-05-01 - works in the same way as the old one (except returned floor is always 0)
function DGV:GetPlayerPosition()
	if not WorldMapFrame:IsShown() then
		local x, y, mapId = DGV:GetPlayerLocalPosition()
		return mapId, 0, x, y
	end

	local x, y = DGV:GetPlayerPositionOnMap(DGV:GetCurrentMapID())
	
	if not x then
		return
	end
	
	return DGV:GetCurrentMapID(), 0, x, y
end

function DGV:GetPlayerMapPositionDisruptive()
	local orig_mapId, orig_level = DGV:GetCurrentMapID() 
	LuaUtils:DugiSetMapToCurrentZone()
	local DugisArrow = DGV.Modules.DugisArrow
	--local m1, f1, x1, y1 =  DGV.astrolabe:GetUnitPosition("player")
	local m1, _, x1, y1 = DGV:GetUnitPosition()
	
	if not m1 or m1==0 then
		m1, x1, y1 = 
			DugisArrow.map,
			DugisArrow.pos_x, DugisArrow.pos_y
	end
	if orig_mapId~=m1 then
		LuaUtils:DugiSetMapByID(orig_mapId)
	end
	return m1, GetCurrentMapDungeonLevel_dugi(), x1, y1
end

local czLookup = {}

local function ContinentName2ContinentId(continentName, ...)
	return DGV:GetZoneIdByName(continentName)
end

--zone name[:continent name]
function DGV:GetZoneIdByName(name)
	if name == "Vale of Eternal Blossoms" then return 390 end --cheap fix otherwise it returns 520 which is another map of the same name but not used. 
	if type(name)~="string" then return nil end
    
    local zoneName_continentName = LuaUtils:split(name, ":")
    local zoneName = zoneName_continentName[1]
    local continentName = nil
    local continentId = nil
    
    if zoneName_continentName[2] ~= nil then
        continentName = zoneName_continentName[2]
        continentId = ContinentName2ContinentId(continentName)
    end
	
	return DGV:GetMapIDFromName(zoneName)
end

local function getCZ(mapId)
	local c, z 
	if czLookup[mapId] then 
		c, z = unpack(czLookup[mapId])
	end
	return c or 0, z or 0
end

function DGV:GetCZByMapId(mapId)
	if getCZ(mapId) == 0 then 
		return 12, 0
	else
		return getCZ(mapId)
	end
--[[	if mapId == 1052 or 
	mapId == 1048 or
	mapId == 1044 or
	mapId == 1068
	then
		return 10, 0
	end
	return getCZ(mapId)]]
end

function DGV.ContinentMapIterator(invariant, control)
	while true do
		control, tbl = next(czLookup, control)
		if not control then return end
		if tbl[1]==invariant then
			return control
		end
	end
end

DGV.TERRAIN_MAPS =  {
[0]="azeroth",
[1]="kalimdor",
[30]="pvpzone01",
[33]="shadowfang",
[36]="deadminesinstance",
[37]="pvpzone02",
[47]="razorfenkraulinstance",
[129]="razorfendowns",
[169]="emeralddream",
[189]="monasteryinstances",
[209]="tanarisinstance",
[269]="cavernsoftime",
[289]="schoolofnecromancy",
[309]="zul'gurub",
[329]="stratholme",
[451]="development",
[469]="blackwinglair",
[489]="pvpzone03",
[509]="ahnqiraj",
[529]="pvpzone04",
[530]="expansion01",
[531]="ahnqirajtemple",
[532]="karazahn",
[533]="stratholme raid",
[534]="hyjalpast",
[543]="hellfirerampart",
[559]="pvpzone05",
[560]="hillsbradpast",
[562]="bladesedgearena",
[564]="blacktemple",
[566]="netherstormbg",
[568]="zulaman",
[571]="northrend",
[572]="pvplordaeron",
[573]="exteriortest",
[574]="valgarde70",
[575]="utgardepinnacle",
[578]="nexus80",
[580]="sunwellplateau",
[585]="sunwell5manfix",
[595]="stratholmecot",
[599]="ulduar70",
[600]="draktheronkeep",
[601]="azjol_uppercity",
[602]="ulduar80",
[603]="ulduarraid",
[604]="gundrak",
[605]="development_nonweighted",
[607]="northrendbg",
[608]="dalaranprison",
[609]="deathknightstart",
[615]="chamberofaspectsblack",
[616]="nexusraid",
[617]="dalaranarena",
[618]="orgrimmararena",
[619]="azjol_lowercity",
[624]="wintergraspraid",
[628]="isleofconquest",
[631]="icecrowncitadel",
[632]="icecrowncitadel5man",
[638]="gilneas",
[643]="abyssalmaw_interior",
[644]="uldum",
[645]="blackrockspire_4_0",
[648]="lostisles",
[649]="argenttournamentraid",
[650]="argenttournamentdungeon",
[654]="gilneas2",
[655]="gilneasphase1",
[656]="gilneasphase2",
[657]="skywalldungeon",
[658]="quarryoftears",
[659]="lostislesphase1",
[660]="deephomeceiling",
[661]="lostislesphase2",
[668]="hallsofreflection",
[669]="blackwingdescent",
[670]="grimbatoldungeon",
[671]="grimbatolraid",
[719]="mounthyjalphase1",
[720]="firelands1",
[724]="chamberofaspectsred",
[725]="deepholmedungeon",
[726]="cataclysmctf",
[727]="stv_mine_bg",
[728]="thebattleforgilneas",
[730]="maelstromzone",
[731]="desolacebomb",
[732]="tolbarad",
[734]="ahnqirajterrace",
[736]="twilighthighlandsdragonmawphase",
[746]="uldumphaseoasis",
[751]="redgridgeorcbomb",
[754]="skywallraid",
[755]="uldumdungeon",
[757]="baradinhold",
[761]="gilneas_bg_2",
[764]="uldumphasewreckedcamp",
[859]="zul_gurub5man",
[860]="newracestartzone",
[861]="firelandsdailies",
[870]="hawaiimainland",
[930]="scenarioalcazisland",
[938]="cotdragonblight",
[939]="cotwaroftheancients",
[940]="thehouroftwilight",
[951]="nexuslegendary",
[959]="shadowpanhideout",
[960]="easttemple",
[961]="stormstoutbrewery",
[962]="thegreatwall",
[967]="deathwingback",
[968]="eyeofthestorm2.0",
[971]="jadeforestalliancehubphase",
[972]="jadeforestbattlefieldphase",
[974]="darkmoonfaire",
[975]="turtleshipphase01",
[976]="turtleshipphase02",
[977]="maelstromdeathwingfight",
[980]="tolvirarena",
[994]="mogudungeon",
[996]="moguexteriorraid",
[998]="valleyofpower",
[999]="bftalliancescenario",
[1000]="bfthordescenario",
[1001]="scarletsanctuaryarmoryandlibrary",
[1004]="scarletmonasterycathedralgy",
[1005]="brewmasterscenario01",
[1007]="newscholomance",
[1008]="mogushanpalace",
[1009]="mantidraid",
[1010]="mistsctf3",
[1011]="mantiddungeon",
[1014]="monkareascenario",
[1019]="ruinsoftheramore",
[1024]="pandafishingvillagescenario",
[1028]="moguruinsscenario",
[1029]="ancientmogucryptscenario",
[1030]="ancientmogucyptdestroyedscenario",
[1031]="provinggroundsscenario",
[1035]="valleyofpowerscenario",
[1043]="ringofvalorscenario",
[1048]="brewmasterscenario03",
[1049]="blackoxtemplescenario",
[1050]="scenarioklaxxiisland",
[1051]="scenariobrewmaster04",
[1061]="hordebeachdailyarea",
[1062]="alliancebeachdailyarea",
[1064]="moguislanddailyarea",
[1066]="stormwindgunshippandariastartarea",
[1074]="orgrimmargunshippandariastart",
[1116]="draenor",
[1075]="theramorescenariophase",
[1076]="jadeforesthordestartingarea",
[1095]="hordeambushscenario",
[1098]="thunderislandraid",
[1099]="navalbattlescenario",
[1101]="defenseofthealehousebg",
[1102]="hordebasebeachscenario",
[1103]="alliancebasebeachscenario",
[1104]="alittlepatiencescenario",
[1105]="goldrushbg",
[1106]="jainadalaranscenario",
[1112]="blacktemplescenario",
[1120]="thunderkinghordehub",
[1121]="thunderislandalliancehub",
[1123]="lightningforgemoguislandprogressionscenario",
[1124]="shipyardmoguislandprogressionscenario",
[1126]="hordehubmoguislandprogressionscenario",
[1128]="moguislandeventshordebase",
[1129]="moguislandeventsalliancebase",

[1220]="Troll Raid",
[1669]="Argus 1",
[646]="deephome",
}


--Data taken from UIMapIDToWorldMapAreaID.lua
--WorldMapAreaID,DungeonMapID,DungeonFloor = UiMapID
local mapKey2UiMapId = {
  ["4,,0"            ]  = 1  
, ["4,598,8"         ]  = 2  
, ["4,602,10"        ]  = 3  
, ["4,603,11"        ]  = 4  
, ["4,604,12"        ]  = 5  
, ["4,657,19"        ]  = 6  
, ["9,,0"            ]  = 7  
, ["9,570,6"         ]  = 8  
, ["9,575,7"         ]  = 9  
, ["11,,0"           ]  = 10 
, ["11,690,20"       ]  = 11 
, ["13,,0"           ]  = 12 
, ["14,,0"           ]  = 13 
, ["16,,0"           ]  = 14 
, ["17,,0"           ]  = 15 
, ["17,695,18"       ]  = 16 
, ["19,,0"           ]  = 17 
, ["20,,0"           ]  = 18 
, ["20,592,13"       ]  = 19 
, ["20,976,25"       ]  = 20 
, ["21,,0"           ]  = 21 
, ["22,,0"           ]  = 22 
, ["23,,0"           ]  = 23 
, ["23,947,20"       ]  = 24 
, ["24,,0"           ]  = 25 
, ["26,,0"           ]  = 26 
, ["27,,0"           ]  = 27 
, ["27,581,6"        ]  = 28 
, ["27,582,7"        ]  = 29 
, ["27,585,10"       ]  = 30 
, ["27,587,11"       ]  = 31 
, ["28,,0"           ]  = 32 
, ["28,625,14"       ]  = 33 
, ["28,626,15"       ]  = 34 
, ["28,627,16"       ]  = 35 
, ["29,,0"           ]  = 36 
, ["30,,0"           ]  = 37 
, ["30,567,1"        ]  = 38 
, ["30,577,2"        ]  = 39 
, ["30,706,19"       ]  = 40 
, ["30,1085,21"      ]  = 41 
, ["32,,0"           ]  = 42 
, ["32,1087,22"      ]  = 43 
, ["32,1089,23"      ]  = 44 
, ["32,1090,24"      ]  = 45 
, ["32,1016,27"      ]  = 46 
, ["34,,0"           ]  = 47 
, ["35,,0"           ]  = 48 
, ["36,,0"           ]  = 49 
, ["37,,0"           ]  = 50 
, ["38,,0"           ]  = 51 
, ["39,,0"           ]  = 52 
, ["39,579,4"        ]  = 53 
, ["39,580,5"        ]  = 54 
, ["39,689,17"       ]  = 55 
, ["40,,0"           ]  = 56 
, ["41,,0"           ]  = 57 
, ["41,558,2"        ]  = 58 
, ["41,564,3"        ]  = 59 
, ["41,565,4"        ]  = 60 
, ["41,566,5"        ]  = 61 
, ["42,,0"           ]  = 62 
, ["43,,0"           ]  = 63 
, ["61,,0"           ]  = 64 
, ["81,,0"           ]  = 65 
, ["101,,0"          ]  = 66 
, ["101,696,21"      ]  = 67 
, ["101,699,22"      ]  = 68 
, ["121,,0"          ]  = 69 
, ["141,,0"          ]  = 70 
, ["161,,0"          ]  = 71 
, ["161,622,15"      ]  = 72 
, ["161,623,16"      ]  = 73 
, ["161,631,17"      ]  = 74 
, ["161,632,18"      ]  = 75 
, ["181,,0"          ]  = 76 
, ["182,,0"          ]  = 77 
, ["201,,0"          ]  = 78 
, ["201,621,14"      ]  = 79 
, ["241,,0"          ]  = 80 
, ["261,,0"          ]  = 81 
, ["261,620,13"      ]  = 82 
, ["281,,0"          ]  = 83 
, ["301,,0"          ]  = 84 
, ["321,,1"          ]  = 85 
, ["321,118,2"       ]  = 86 
, ["341,,0"          ]  = 87 
, ["362,,0"          ]  = 88 
, ["381,,0"          ]  = 89 
, ["382,,0"          ]  = 90 
, ["401,,0"          ]  = 91 
, ["443,,0"          ]  = 92 
, ["461,,0"          ]  = 93 
, ["462,,0"          ]  = 94 
, ["463,,0"          ]  = 95 
, ["463,593,1"       ]  = 96 
, ["464,,0"          ]  = 97 
, ["464,594,2"       ]  = 98 
, ["464,688,3"       ]  = 99 
, ["465,,0"          ]  = 100
, ["466,,0"          ]  = 101
, ["467,,0"          ]  = 102
, ["471,,0"          ]  = 103
, ["473,,0"          ]  = 104
, ["475,,0"          ]  = 105
, ["476,,0"          ]  = 106
, ["477,,0"          ]  = 107
, ["478,,0"          ]  = 108
, ["479,,0"          ]  = 109
, ["480,,0"          ]  = 110
, ["481,,0"          ]  = 111
, ["482,,0"          ]  = 112
, ["485,,0"          ]  = 113
, ["486,,0"          ]  = 114
, ["488,,0"          ]  = 115
, ["490,,0"          ]  = 116
, ["491,,0"          ]  = 117
, ["492,,0"          ]  = 118
, ["493,,0"          ]  = 119
, ["495,,0"          ]  = 120
, ["496,,0"          ]  = 121
, ["499,,0"          ]  = 122
, ["501,,0"          ]  = 123
, ["502,,0"          ]  = 124
, ["504,27,1"        ]  = 125
, ["504,26,2"        ]  = 126
, ["510,,0"          ]  = 127
, ["512,,0"          ]  = 128
, ["520,25,1"        ]  = 129
, ["521,,0"          ]  = 130
, ["521,34,1"        ]  = 131
, ["522,50,1"        ]  = 132
, ["523,1,1"         ]  = 133
, ["523,2,2"         ]  = 134
, ["523,41,3"        ]  = 135
, ["524,39,1"        ]  = 136
, ["524,40,2"        ]  = 137
, ["525,54,1"        ]  = 138
, ["525,55,2"        ]  = 139
, ["526,53,1"        ]  = 140
, ["527,61,1"        ]  = 141
, ["528,,0"          ]  = 142
, ["528,42,1"        ]  = 143
, ["528,43,2"        ]  = 144
, ["528,45,3"        ]  = 145
, ["528,46,4"        ]  = 146
, ["529,,0"          ]  = 147
, ["529,69,1"        ]  = 148
, ["529,70,2"        ]  = 149
, ["529,71,3"        ]  = 150
, ["529,72,4"        ]  = 151
, ["529,98,5"        ]  = 152
, ["530,,0"          ]  = 153
, ["530,36,1"        ]  = 154
, ["531,,0"          ]  = 155
, ["532,63,1"        ]  = 156
, ["533,47,1"        ]  = 157
, ["533,48,2"        ]  = 158
, ["533,49,3"        ]  = 159
, ["534,37,1"        ]  = 160
, ["534,38,2"        ]  = 161
, ["535,56,1"        ]  = 162
, ["535,57,2"        ]  = 163
, ["535,58,3"        ]  = 164
, ["535,59,4"        ]  = 165
, ["535,60,5"        ]  = 166
, ["535,73,6"        ]  = 167
, ["536,52,1"        ]  = 168
, ["540,,0"          ]  = 169
, ["541,,0"          ]  = 170
, ["542,96,1"        ]  = 171
, ["543,94,1"        ]  = 172
, ["543,95,2"        ]  = 173
, ["544,,0"          ]  = 174
, ["544,611,1"       ]  = 175
, ["544,614,2"       ]  = 176
, ["544,615,3"       ]  = 177
, ["544,616,4"       ]  = 178
, ["545,,0"          ]  = 179
, ["545,606,1"       ]  = 180
, ["545,609,2"       ]  = 181
, ["545,610,3"       ]  = 182
, ["601,101,1"       ]  = 183
, ["602,,0"          ]  = 184
, ["603,102,1"       ]  = 185
, ["604,103,1"       ]  = 186
, ["604,104,2"       ]  = 187
, ["604,105,3"       ]  = 188
, ["604,106,4"       ]  = 189
, ["604,107,5"       ]  = 190
, ["604,108,6"       ]  = 191
, ["604,109,7"       ]  = 192
, ["604,110,8"       ]  = 193
, ["605,,0"          ]  = 194
, ["605,617,5"       ]  = 195
, ["605,618,6"       ]  = 196
, ["605,619,7"       ]  = 197
, ["606,,0"          ]  = 198
, ["607,,0"          ]  = 199
, ["609,,0"          ]  = 200
, ["610,,0"          ]  = 201
, ["611,,0"          ]  = 202
, ["613,,0"          ]  = 203
, ["614,,0"          ]  = 204
, ["615,,0"          ]  = 205
, ["626,,0"          ]  = 206
, ["640,,0"          ]  = 207
, ["640,991,1"       ]  = 208
, ["640,992,2"       ]  = 209
, ["673,,0"          ]  = 210
, ["680,136,1"       ]  = 213
, ["684,,0"          ]  = 217
, ["685,,0"          ]  = 218
, ["686,,0"          ]  = 219
, ["687,176,1"       ]  = 220
, ["688,162,1"       ]  = 221
, ["688,163,2"       ]  = 222
, ["688,164,3"       ]  = 223
, ["689,,0"          ]  = 224
, ["690,165,1"       ]  = 225
, ["691,168,1"       ]  = 226
, ["691,169,2"       ]  = 227
, ["691,170,3"       ]  = 228
, ["691,172,4"       ]  = 229
, ["692,171,1"       ]  = 230
, ["692,180,2"       ]  = 231
, ["696,181,1"       ]  = 232
, ["697,,0"          ]  = 233
, ["699,,0"          ]  = 234
, ["699,262,1"       ]  = 235
, ["699,263,2"       ]  = 236
, ["699,264,3"       ]  = 237
, ["699,265,4"       ]  = 238
, ["699,266,5"       ]  = 239
, ["699,267,6"       ]  = 240
, ["700,,0"          ]  = 241
, ["704,200,1"       ]  = 242
, ["704,201,2"       ]  = 243
, ["708,,0"          ]  = 244
, ["709,,0"          ]  = 245
, ["710,222,1"       ]  = 246
, ["717,,0"          ]  = 247
, ["718,196,1"       ]  = 248
, ["720,,0"          ]  = 249
, ["721,202,1"       ]  = 250
, ["721,207,2"       ]  = 251
, ["721,208,3"       ]  = 252
, ["721,209,4"       ]  = 253
, ["721,210,5"       ]  = 254
, ["721,211,6"       ]  = 255
, ["722,214,1"       ]  = 256
, ["722,215,2"       ]  = 257
, ["723,216,1"       ]  = 258
, ["723,217,2"       ]  = 259
, ["724,218,1"       ]  = 260
, ["725,221,1"       ]  = 261
, ["726,223,1"       ]  = 262
, ["727,226,1"       ]  = 263
, ["727,227,2"       ]  = 264
, ["728,228,1"       ]  = 265
, ["729,230,1"       ]  = 266
, ["730,231,1"       ]  = 267
, ["730,232,2"       ]  = 268
, ["731,233,1"       ]  = 269
, ["731,234,2"       ]  = 270
, ["731,235,3"       ]  = 271
, ["732,238,1"       ]  = 272
, ["733,,0"          ]  = 273
, ["734,,0"          ]  = 274
, ["736,,0"          ]  = 275
, ["737,,0"          ]  = 276
, ["747,,0"          ]  = 277
, ["749,28,1"        ]  = 279
, ["750,256,1"       ]  = 280
, ["750,257,2"       ]  = 281
, ["752,252,1"       ]  = 282
, ["753,116,1"       ]  = 283
, ["753,117,2"       ]  = 284
, ["754,131,1"       ]  = 285
, ["754,132,2"       ]  = 286
, ["755,182,1"       ]  = 287
, ["755,183,2"       ]  = 288
, ["755,184,3"       ]  = 289
, ["755,185,4"       ]  = 290
, ["756,166,1"       ]  = 291
, ["756,167,2"       ]  = 292
, ["757,123,1"       ]  = 293
, ["758,128,1"       ]  = 294
, ["758,129,2"       ]  = 295
, ["758,134,3"       ]  = 296
, ["759,119,1"       ]  = 297
, ["759,120,2"       ]  = 298
, ["759,135,3"       ]  = 299
, ["760,150,1"       ]  = 300
, ["761,149,1"       ]  = 301
, ["762,137,1"       ]  = 302
, ["762,140,2"       ]  = 303
, ["762,141,3"       ]  = 304
, ["762,179,4"       ]  = 305
, ["763,151,1"       ]  = 306
, ["763,152,2"       ]  = 307
, ["763,153,3"       ]  = 308
, ["763,154,4"       ]  = 309
, ["764,142,1"       ]  = 310
, ["764,143,2"       ]  = 311
, ["764,144,3"       ]  = 312
, ["764,145,4"       ]  = 313
, ["764,146,5"       ]  = 314
, ["764,147,6"       ]  = 315
, ["764,148,7"       ]  = 316
, ["765,155,1"       ]  = 317
, ["765,156,2"       ]  = 318
, ["766,191,1"       ]  = 319
, ["766,192,2"       ]  = 320
, ["766,195,3"       ]  = 321
, ["767,126,1"       ]  = 322
, ["767,127,2"       ]  = 323
, ["768,125,1"       ]  = 324
, ["769,122,1"       ]  = 325
, ["772,,0"          ]  = 327
, ["773,271,1"       ]  = 328
, ["775,,0"          ]  = 329
, ["776,322,1"       ]  = 330
, ["779,341,1"       ]  = 331
, ["780,355,1"       ]  = 332
, ["781,,0"          ]  = 333
, ["782,349,1"       ]  = 334
, ["789,,0"          ]  = 335
, ["789,440,1"       ]  = 336
, ["793,,0"          ]  = 337
, ["795,,0"          ]  = 338
, ["796,,0"          ]  = 339
, ["796,433,1"       ]  = 340
, ["796,434,2"       ]  = 341
, ["796,435,3"       ]  = 342
, ["796,436,4"       ]  = 343
, ["796,437,5"       ]  = 344
, ["796,438,6"       ]  = 345
, ["796,439,7"       ]  = 346
, ["797,219,1"       ]  = 347
, ["798,236,1"       ]  = 348
, ["798,237,2"       ]  = 349
, ["799,383,1"       ]  = 350
, ["799,385,2"       ]  = 351
, ["799,386,3"       ]  = 352
, ["799,387,4"       ]  = 353
, ["799,388,5"       ]  = 354
, ["799,389,6"       ]  = 355
, ["799,390,7"       ]  = 356
, ["799,391,8"       ]  = 357
, ["799,393,9"       ]  = 358
, ["799,398,10"      ]  = 359
, ["799,399,11"      ]  = 360
, ["799,401,12"      ]  = 361
, ["799,402,13"      ]  = 362
, ["799,403,14"      ]  = 363
, ["799,404,15"      ]  = 364
, ["799,405,16"      ]  = 365
, ["799,406,17"      ]  = 366
, ["800,,0"          ]  = 367
, ["800,467,1"       ]  = 368
, ["800,466,2"       ]  = 369
, ["803,458,1"       ]  = 370
, ["806,,0"          ]  = 371
, ["806,678,6"       ]  = 372
, ["806,679,7"       ]  = 373
, ["806,691,15"      ]  = 374
, ["806,692,16"      ]  = 375
, ["807,,0"          ]  = 376
, ["807,687,14"      ]  = 377
, ["808,,0"          ]  = 378
, ["809,,0"          ]  = 379
, ["809,680,8"       ]  = 380
, ["809,682,9"       ]  = 381
, ["809,683,10"      ]  = 382
, ["809,684,11"      ]  = 383
, ["809,685,12"      ]  = 384
, ["809,707,17"      ]  = 385
, ["809,739,20"      ]  = 386
, ["809,740,21"      ]  = 387
, ["810,,0"          ]  = 388
, ["810,686,13"      ]  = 389
, ["811,,0"          ]  = 390
, ["811,668,1"       ]  = 391
, ["811,669,2"       ]  = 392
, ["811,670,3"       ]  = 393
, ["811,671,4"       ]  = 394
, ["811,708,18"      ]  = 395
, ["811,709,19"      ]  = 396
, ["813,,0"          ]  = 397
, ["816,,0"          ]  = 398
, ["819,,0"          ]  = 399
, ["819,502,1"       ]  = 400
, ["820,,0"          ]  = 401
, ["820,495,1"       ]  = 402
, ["820,496,2"       ]  = 403
, ["820,497,3"       ]  = 404
, ["820,498,4"       ]  = 405
, ["820,499,5"       ]  = 406
, ["823,,0"          ]  = 407
, ["823,1157,1"      ]  = 408
, ["824,,0"          ]  = 409
, ["824,503,1"       ]  = 410
, ["824,504,2"       ]  = 411
, ["824,505,3"       ]  = 412
, ["824,512,4"       ]  = 413
, ["824,513,5"       ]  = 414
, ["824,514,6"       ]  = 415
, ["851,,0"          ]  = 416
, ["856,,0"          ]  = 417
, ["857,,0"          ]  = 418
, ["857,727,1"       ]  = 419
, ["857,728,2"       ]  = 420
, ["857,729,3"       ]  = 421
, ["858,,0"          ]  = 422
, ["860,576,1"       ]  = 423
, ["862,,0"          ]  = 424
, ["864,,0"          ]  = 425
, ["864,578,3"       ]  = 426
, ["866,,0"          ]  = 427
, ["866,584,9"       ]  = 428
, ["867,633,1"       ]  = 429
, ["867,634,2"       ]  = 430
, ["871,639,1"       ]  = 431
, ["871,640,2"       ]  = 432
, ["873,,0"          ]  = 433
, ["873,677,5"       ]  = 434
, ["874,641,1"       ]  = 435
, ["874,648,2"       ]  = 436
, ["875,649,1"       ]  = 437
, ["875,650,2"       ]  = 438
, ["876,635,1"       ]  = 439
, ["876,636,2"       ]  = 440
, ["876,637,3"       ]  = 441
, ["876,638,4"       ]  = 442
, ["877,,0"          ]  = 443
, ["877,651,1"       ]  = 444
, ["877,652,2"       ]  = 445
, ["877,653,3"       ]  = 446
, ["878,,0"          ]  = 447
, ["880,,0"          ]  = 448
, ["881,,0"          ]  = 449
, ["882,,0"          ]  = 450
, ["883,,0"          ]  = 451
, ["884,,0"          ]  = 452
, ["885,654,1"       ]  = 453
, ["885,655,2"       ]  = 454
, ["885,656,3"       ]  = 455
, ["886,,0"          ]  = 456
, ["887,,0"          ]  = 457
, ["887,660,1"       ]  = 458
, ["887,661,2"       ]  = 459
, ["888,,0"          ]  = 460
, ["889,,0"          ]  = 461
, ["890,,0"          ]  = 462
, ["891,,0"          ]  = 463
, ["891,599,9"       ]  = 464
, ["892,,0"          ]  = 465
, ["892,588,12"      ]  = 466
, ["893,,0"          ]  = 467
, ["894,,0"          ]  = 468
, ["895,,0"          ]  = 469
, ["895,583,8"       ]  = 470
, ["896,663,1"       ]  = 471
, ["896,664,2"       ]  = 472
, ["896,665,3"       ]  = 473
, ["897,666,1"       ]  = 474
, ["897,667,2"       ]  = 475
, ["898,642,1"       ]  = 476
, ["898,643,2"       ]  = 477
, ["898,644,3"       ]  = 478
, ["898,645,4"       ]  = 479
, ["899,672,1"       ]  = 480
, ["900,673,1"       ]  = 481
, ["900,674,2"       ]  = 482
, ["906,,0"          ]  = 483
, ["911,,0"          ]  = 486
, ["912,,0"          ]  = 487
, ["914,,0"          ]  = 488
, ["914,726,1"       ]  = 489
, ["919,,0"          ]  = 490
, ["919,732,1"       ]  = 491
, ["919,733,2"       ]  = 492
, ["919,734,3"       ]  = 493
, ["919,735,4"       ]  = 494
, ["919,736,5"       ]  = 495
, ["919,737,6"       ]  = 496
, ["919,738,7"       ]  = 497
, ["920,,0"          ]  = 498
, ["922,741,1"       ]  = 499
, ["922,742,2"       ]  = 500
, ["924,746,1"       ]  = 501
, ["924,748,2"       ]  = 502
, ["925,749,1"       ]  = 503
, ["928,,0"          ]  = 504
, ["928,758,1"       ]  = 505
, ["928,759,2"       ]  = 506
, ["929,,0"          ]  = 507
, ["930,750,1"       ]  = 508
, ["930,751,2"       ]  = 509
, ["930,752,3"       ]  = 510
, ["930,753,4"       ]  = 511
, ["930,754,5"       ]  = 512
, ["930,755,6"       ]  = 513
, ["930,756,7"       ]  = 514
, ["930,757,8"       ]  = 515
, ["933,,0"          ]  = 516
, ["933,761,1"       ]  = 517
, ["934,760,1"       ]  = 518
, ["935,,0"          ]  = 519
, ["937,,0"          ]  = 520
, ["937,775,1"       ]  = 521
, ["938,776,1"       ]  = 522
, ["939,,0"          ]  = 523
, ["940,,0"          ]  = 524
, ["941,,0"          ]  = 525
, ["941,815,1"       ]  = 526
, ["941,816,2"       ]  = 527
, ["941,817,3"       ]  = 528
, ["941,818,4"       ]  = 529
, ["941,859,6"       ]  = 530
, ["941,860,7"       ]  = 531
, ["941,861,8"       ]  = 532
, ["941,862,9"       ]  = 533
, ["945,,0"          ]  = 534
, ["946,,0"          ]  = 535
, ["946,884,13"      ]  = 536
, ["946,885,14"      ]  = 537
, ["946,937,30"      ]  = 538
, ["947,,0"          ]  = 539
, ["947,886,15"      ]  = 540
, ["947,894,22"      ]  = 541
, ["948,,0"          ]  = 542
, ["949,,0"          ]  = 543
, ["949,888,16"      ]  = 544
, ["949,889,17"      ]  = 545
, ["949,890,18"      ]  = 546
, ["949,891,19"      ]  = 547
, ["949,892,20"      ]  = 548
, ["949,893,21"      ]  = 549
, ["950,,0"          ]  = 550
, ["950,863,10"      ]  = 551
, ["950,864,11"      ]  = 552
, ["950,880,12"      ]  = 553
, ["951,,0"          ]  = 554
, ["951,808,22"      ]  = 555
, ["953,,0"          ]  = 556
, ["953,789,1"       ]  = 557
, ["953,790,2"       ]  = 558
, ["953,793,3"       ]  = 559
, ["953,794,4"       ]  = 560
, ["953,795,5"       ]  = 561
, ["953,796,6"       ]  = 562
, ["953,797,7"       ]  = 563
, ["953,798,8"       ]  = 564
, ["953,800,9"       ]  = 565
, ["953,801,10"      ]  = 566
, ["953,802,11"      ]  = 567
, ["953,803,12"      ]  = 568
, ["953,804,13"      ]  = 569
, ["953,805,14"      ]  = 570
, ["955,,0"          ]  = 571
, ["962,,0"          ]  = 572
, ["964,814,1"       ]  = 573
, ["969,828,1"       ]  = 574
, ["969,830,2"       ]  = 575
, ["969,831,3"       ]  = 576
, ["970,,0"          ]  = 577
, ["970,858,1"       ]  = 578
, ["971,902,23"      ]  = 579
, ["971,903,24"      ]  = 580
, ["971,904,25"      ]  = 581
, ["973,,0"          ]  = 582
, ["976,905,26"      ]  = 585
, ["976,906,27"      ]  = 586
, ["976,907,28"      ]  = 587
, ["978,,0"          ]  = 588
, ["978,934,29"      ]  = 589
, ["980,,0"          ]  = 590
, ["983,,0"          ]  = 592
, ["984,837,1"       ]  = 593
, ["986,,0"          ]  = 594
, ["987,839,1"       ]  = 595
, ["988,842,1"       ]  = 596
, ["988,841,2"       ]  = 597
, ["988,840,3"       ]  = 598
, ["988,843,4"       ]  = 599
, ["988,844,5"       ]  = 600
, ["989,845,1"       ]  = 601
, ["989,846,2"       ]  = 602
, ["993,847,1"       ]  = 606
, ["993,848,2"       ]  = 607
, ["993,849,3"       ]  = 608
, ["993,850,4"       ]  = 609
, ["994,,0"          ]  = 610
, ["994,852,1"       ]  = 611
, ["994,853,2"       ]  = 612
, ["994,854,3"       ]  = 613
, ["994,855,4"       ]  = 614
, ["994,856,5"       ]  = 615
, ["995,877,1"       ]  = 616
, ["995,878,2"       ]  = 617
, ["995,879,3"       ]  = 618
, ["1007,,0"         ]  = 619
, ["1008,,0"         ]  = 620
, ["1008,912,1"      ]  = 621
, ["1009,,0"         ]  = 622
, ["1010,,0"         ]  = 623
, ["1011,,0"         ]  = 624
, ["1014,,0"         ]  = 625
, ["1014,993,4"      ]  = 626
, ["1014,1009,10"    ]  = 627
, ["1014,1010,11"    ]  = 628
, ["1014,1011,12"    ]  = 629
, ["1015,,0"         ]  = 630
, ["1015,1019,17"    ]  = 631
, ["1015,1020,18"    ]  = 632
, ["1015,1021,19"    ]  = 633
, ["1017,,0"         ]  = 634
, ["1017,1018,1"     ]  = 635
, ["1017,1006,9"     ]  = 636
, ["1017,1034,25"    ]  = 637
, ["1017,1035,26"    ]  = 638
, ["1017,1036,27"    ]  = 639
, ["1017,1037,28"    ]  = 640
, ["1018,,0"         ]  = 641
, ["1018,1012,13"    ]  = 642
, ["1018,1013,14"    ]  = 643
, ["1018,1014,15"    ]  = 644
, ["1020,,0"         ]  = 645
, ["1021,,0"         ]  = 646
, ["1021,939,1"      ]  = 647
, ["1021,940,2"      ]  = 648
, ["1022,,0"         ]  = 649
, ["1024,,0"         ]  = 650
, ["1024,996,5"      ]  = 651
, ["1024,997,6"      ]  = 652
, ["1024,1005,8"     ]  = 653
, ["1024,1015,16"    ]  = 654
, ["1024,1025,20"    ]  = 655
, ["1024,1026,21"    ]  = 656
, ["1024,1038,29"    ]  = 657
, ["1024,1039,30"    ]  = 658
, ["1024,1040,31"    ]  = 659
, ["1024,1117,40"    ]  = 660
, ["1026,,0"         ]  = 661
, ["1026,926,1"      ]  = 662
, ["1026,927,2"      ]  = 663
, ["1026,925,3"      ]  = 664
, ["1026,928,4"      ]  = 665
, ["1026,929,5"      ]  = 666
, ["1026,930,6"      ]  = 667
, ["1026,931,7"      ]  = 668
, ["1026,932,8"      ]  = 669
, ["1026,933,9"      ]  = 670
, ["1027,,0"         ]  = 671
, ["1028,,0"         ]  = 672
, ["1028,1022,1"     ]  = 673
, ["1028,1023,2"     ]  = 674
, ["1028,1024,3"     ]  = 675
, ["1031,,0"         ]  = 676
, ["1032,941,1"      ]  = 677
, ["1032,942,2"      ]  = 678
, ["1032,943,3"      ]  = 679
, ["1033,,0"         ]  = 680
, ["1033,1031,22"    ]  = 681
, ["1033,1032,23"    ]  = 682
, ["1033,1033,24"    ]  = 683
, ["1033,1064,32"    ]  = 684
, ["1033,1065,33"    ]  = 685
, ["1033,1068,34"    ]  = 686
, ["1033,1069,35"    ]  = 687
, ["1033,1070,36"    ]  = 688
, ["1033,1071,37"    ]  = 689
, ["1033,1072,38"    ]  = 690
, ["1033,1114,39"    ]  = 691
, ["1033,1007,41"    ]  = 692
, ["1033,1008,42"    ]  = 693
, ["1034,,0"         ]  = 694
, ["1035,946,1"      ]  = 695
, ["1037,,0"         ]  = 696
, ["1038,,0"         ]  = 697
, ["1039,948,1"      ]  = 698
, ["1039,949,2"      ]  = 699
, ["1039,954,3"      ]  = 700
, ["1039,958,4"      ]  = 701
, ["1040,966,1"      ]  = 702
, ["1041,,0"         ]  = 703
, ["1041,963,1"      ]  = 704
, ["1041,964,2"      ]  = 705
, ["1042,,0"         ]  = 706
, ["1042,967,1"      ]  = 707
, ["1042,968,2"      ]  = 708
, ["1044,,0"         ]  = 709
, ["1045,969,1"      ]  = 710
, ["1045,970,2"      ]  = 711
, ["1045,971,3"      ]  = 712
, ["1046,,0"         ]  = 713
, ["1047,,0"         ]  = 714
, ["1048,,0"         ]  = 715
, ["1049,973,1"      ]  = 716
, ["1050,,0"         ]  = 717
, ["1051,,0"         ]  = 718
, ["1052,,1"         ]  = 719
, ["1052,981,2"      ]  = 720
, ["1052,982,3"      ]  = 721
, ["1054,974,1"      ]  = 723
, ["1056,,0"         ]  = 725
, ["1057,,0"         ]  = 726
, ["1059,,0"         ]  = 728
, ["1060,975,1"      ]  = 729
, ["1065,,0"         ]  = 731
, ["1066,977,1"      ]  = 732
, ["1067,,0"         ]  = 733
, ["1068,978,1"      ]  = 734
, ["1068,979,2"      ]  = 735
, ["1069,980,1"      ]  = 736
, ["1070,983,1"      ]  = 737
, ["1071,,0"         ]  = 738
, ["1072,,0"         ]  = 739
, ["1073,985,1"      ]  = 740
, ["1073,986,2"      ]  = 741
, ["1075,987,1"      ]  = 742
, ["1075,988,2"      ]  = 743
, ["1076,989,1"      ]  = 744
, ["1076,990,2"      ]  = 745
, ["1076,1078,3"     ]  = 746
, ["1077,,0"         ]  = 747
, ["1078,,0"         ]  = 748
, ["1079,994,1"      ]  = 749
, ["1080,,0"         ]  = 750
, ["1081,998,1"      ]  = 751
, ["1081,999,2"      ]  = 752
, ["1081,1000,3"     ]  = 753
, ["1081,1001,4"     ]  = 754
, ["1081,1002,5"     ]  = 755
, ["1081,1003,6"     ]  = 756
, ["1082,,0"         ]  = 757
, ["1084,,0"         ]  = 758
, ["1085,1027,1"     ]  = 759
, ["1086,,0"         ]  = 760
, ["1087,,0"         ]  = 761
, ["1087,1029,1"     ]  = 762
, ["1087,1030,2"     ]  = 763
, ["1088,1041,1"     ]  = 764
, ["1088,1042,2"     ]  = 765
, ["1088,1043,3"     ]  = 766
, ["1088,1044,4"     ]  = 767
, ["1088,1045,5"     ]  = 768
, ["1088,1046,6"     ]  = 769
, ["1088,1047,7"     ]  = 770
, ["1088,1048,8"     ]  = 771
, ["1088,1049,9"     ]  = 772
, ["1090,,0"         ]  = 773
, ["1090,1050,1"     ]  = 774
, ["1091,,0"         ]  = 775
, ["1092,,0"         ]  = 776
, ["1094,1051,1"     ]  = 777
, ["1094,1052,2"     ]  = 778
, ["1094,1053,3"     ]  = 779
, ["1094,1054,4"     ]  = 780
, ["1094,1055,5"     ]  = 781
, ["1094,1056,6"     ]  = 782
, ["1094,1057,7"     ]  = 783
, ["1094,1058,8"     ]  = 784
, ["1094,1059,9"     ]  = 785
, ["1094,1060,10"    ]  = 786
, ["1094,1061,11"    ]  = 787
, ["1094,1062,12"    ]  = 788
, ["1094,1086,13"    ]  = 789
, ["1096,,0"         ]  = 790
, ["1097,1066,1"     ]  = 791
, ["1097,1067,2"     ]  = 792
, ["1099,,0"         ]  = 793
, ["1100,1073,1"     ]  = 794
, ["1100,1074,2"     ]  = 795
, ["1100,1075,3"     ]  = 796
, ["1100,1076,4"     ]  = 797
, ["1102,1077,1"     ]  = 798
, ["1104,,0"         ]  = 799
, ["1104,1079,1"     ]  = 800
, ["1104,1080,2"     ]  = 801
, ["1104,1081,3"     ]  = 802
, ["1104,1082,4"     ]  = 803
, ["1105,1083,1"     ]  = 804
, ["1105,1084,2"     ]  = 805
, ["1114,,0"         ]  = 806
, ["1114,1091,1"     ]  = 807
, ["1114,1092,2"     ]  = 808
, ["1115,1093,1"     ]  = 809
, ["1115,1094,2"     ]  = 810
, ["1115,1095,3"     ]  = 811
, ["1115,1096,4"     ]  = 812
, ["1115,1097,5"     ]  = 813
, ["1115,1098,6"     ]  = 814
, ["1115,1099,7"     ]  = 815
, ["1115,1100,8"     ]  = 816
, ["1115,1101,9"     ]  = 817
, ["1115,1102,10"    ]  = 818
, ["1115,1103,11"    ]  = 819
, ["1115,1104,12"    ]  = 820
, ["1115,1105,13"    ]  = 821
, ["1115,1106,14"    ]  = 822
, ["1116,,0"         ]  = 823
, ["1126,,0"         ]  = 824
, ["1127,1110,1"     ]  = 825
, ["1129,1111,1"     ]  = 826
, ["1130,1112,1"     ]  = 827
, ["1131,1113,1"     ]  = 828
, ["1132,1115,1"     ]  = 829
, ["1135,,0"         ]  = 830
, ["1135,1163,1"     ]  = 831
, ["1135,1165,2"     ]  = 832
, ["1135,1184,7"     ]  = 833
, ["1136,,0"         ]  = 834
, ["1137,1118,1"     ]  = 835
, ["1137,1119,2"     ]  = 836
, ["1139,,0"         ]  = 837
, ["1140,,0"         ]  = 838
, ["1142,1123,1"     ]  = 839
, ["1143,1120,1"     ]  = 840
, ["1143,1121,2"     ]  = 841
, ["1143,1122,3"     ]  = 842
, ["1144,,0"         ]  = 843
, ["1145,,0"         ]  = 844
, ["1146,1124,1"     ]  = 845
, ["1146,1125,2"     ]  = 846
, ["1146,1126,3"     ]  = 847
, ["1146,1127,4"     ]  = 848
, ["1146,1128,5"     ]  = 849
, ["1147,1129,1"     ]  = 850
, ["1147,1130,2"     ]  = 851
, ["1147,1132,3"     ]  = 852
, ["1147,1133,4"     ]  = 853
, ["1147,1134,5"     ]  = 854
, ["1147,1135,6"     ]  = 855
, ["1147,1136,7"     ]  = 856
, ["1148,1138,1"     ]  = 857
, ["1149,,0"         ]  = 858
, ["1150,,0"         ]  = 859
, ["1151,,0"         ]  = 860
, ["1152,,0"         ]  = 861
, ["1153,,0"         ]  = 862
, ["1154,,0"         ]  = 863
, ["1155,,0"         ]  = 864
, ["1156,1143,1"     ]  = 865
, ["1156,1144,2"     ]  = 866
, ["1157,1140,1"     ]  = 867
, ["1158,1139,1"     ]  = 868
, ["1159,1141,1"     ]  = 869
, ["1159,1142,2"     ]  = 870
, ["1160,,0"         ]  = 871
, ["1161,,0"         ]  = 872
, ["1161,1145,1"     ]  = 873
, ["1161,1146,2"     ]  = 874
, ["1162,,0"         ]  = 875
, ["1163,,0"         ]  = 876
, ["1164,,0"         ]  = 877
, ["1165,,0"         ]  = 878
, ["1165,1147,1"     ]  = 879
, ["1165,1148,2"     ]  = 880
, ["1166,1150,1"     ]  = 881
, ["1170,,0"         ]  = 882
, ["1170,1166,3"     ]  = 883
, ["1170,1167,4"     ]  = 884
, ["1171,,0"         ]  = 885
, ["1171,1168,5"     ]  = 886
, ["1171,1169,6"     ]  = 887
, ["1172,1154,1"     ]  = 888
, ["1173,1149,1"     ]  = 889
, ["1173,1156,2"     ]  = 890
, ["1174,,0"         ]  = 891
, ["1174,1181,1"     ]  = 892
, ["1174,1179,2"     ]  = 893
, ["1174,1180,3"     ]  = 894
, ["1175,,0"         ]  = 895
, ["1176,,0"         ]  = 896
, ["1177,,0"         ]  = 897
, ["1177,1158,1"     ]  = 898
, ["1177,1159,2"     ]  = 899
, ["1177,1160,3"     ]  = 900
, ["1177,1161,4"     ]  = 901
, ["1177,1162,5"     ]  = 902
, ["1178,,0"         ]  = 903
, ["1183,,0"         ]  = 904
, ["1184,,0"         ]  = 905
, ["1185,,0"         ]  = 906
, ["1186,,0"         ]  = 907
, ["1187,,0"         ]  = 908
, ["1188,,0"         ]  = 909
, ["1188,1170,1"     ]  = 910
, ["1188,1171,2"     ]  = 911
, ["1188,1172,3"     ]  = 912
, ["1188,1173,4"     ]  = 913
, ["1188,1174,5"     ]  = 914
, ["1188,1175,6"     ]  = 915
, ["1188,1176,7"     ]  = 916
, ["1188,1177,8"     ]  = 917
, ["1188,1178,9"     ]  = 918
, ["1188,1182,10"    ]  = 919
, ["1188,1183,11"    ]  = 920
, ["1190,,0"         ]  = 921
, ["1191,,0"         ]  = 922
, ["1192,,0"         ]  = 923
, ["1193,,0"         ]  = 924
, ["1194,,0"         ]  = 925
, ["1195,,0"         ]  = 926
, ["1196,,0"         ]  = 927
, ["1197,,0"         ]  = 928
, ["1198,,0"         ]  = 929
, ["1199,,0"         ]  = 930
, ["1200,,0"         ]  = 931
, ["1201,,0"         ]  = 932
, ["1202,,0"         ]  = 933
, ["1204,1185,1"     ]  = 934
, ["1204,1186,2"     ]  = 935
, ["1205,,0"         ]  = 936
, ["1210,,0"         ]  = 938
, ["1211,,0"         ]  = 939
, ["1212,1188,1"     ]  = 940
, ["1212,1189,2"     ]  = 941
, ["1213,,0"         ]  = 942
, ["1214,,0"         ]  = 943
, ["1215,,0"         ]  = 971
, ["1216,,0"         ]  = 972
, ["1217,1190,1"     ]  = 973
, ["1219,,0"         ]  = 974
, ["1219,1191,1"     ]  = 975
, ["1219,1192,2"     ]  = 976
, ["1219,1193,3"     ]  = 977
, ["1219,1194,4"     ]  = 978
, ["1219,1195,5"     ]  = 979
, ["1219,1196,6"     ]  = 980
, ["1220,,0"         ]  = 981
, ["1184,,0"         ]  = 994
, ["382,,0"          ]  = 998

}

--definition: {uiMapId1=[oldMapId1, oldDungeonMapID1, oldDungeonFloor1], uiMapId2=[oldMapId2, oldDungeonMapID2, oldDungeonFloor2] }
--example: {980=[1219,1196,6]}
local uiMapId2OldMap = {}

LuaUtils:foreach(mapKey2UiMapId, function(uiMapId, oldMapInfo)
	--oldMapId, oldDungeonMapID, oldDungeonFloor
	local result = LuaUtils:split(oldMapInfo, ",")
	uiMapId2OldMap[uiMapId] = {tonumber(result[1]), tonumber(result[2]), tonumber(result[3])}
end)


--Data taken from UIMapIDToWorldMapAreaID.lua and processed
--Ignores DungeonMapID and DungeonFloor
local oldMapId2UiMapId = {
	 [4] = 1
	,[9] = 7
	,[11] = 10
	,[13] = 12
	,[14] = 13
	,[16] = 14
	,[17] = 15
	,[19] = 17
	,[20] = 18
	,[21] = 21
	,[22] = 22
	,[23] = 23
	,[24] = 25
	,[26] = 26
	,[27] = 27
	,[28] = 32
	,[29] = 36
	,[30] = 37
	,[32] = 42
	,[34] = 47
	,[35] = 48
	,[36] = 49
	,[37] = 50
	,[38] = 51
	,[39] = 52
	,[40] = 56
	,[41] = 57
	,[42] = 62
	,[43] = 63
	,[61] = 64
	,[81] = 65
	,[101] = 66
	,[121] = 69
	,[141] = 70
	,[161] = 71
	,[181] = 76
	,[182] = 77
	,[201] = 78
	,[241] = 80
	,[261] = 81
	,[281] = 83
	,[301] = 84
	,[321] = 85
	,[341] = 87
	,[362] = 88
	,[381] = 89
	,[382] = 90
	,[401] = 91
	,[443] = 92
	,[461] = 93
	,[462] = 94
	,[463] = 95
	,[464] = 97
	,[465] = 100
	,[466] = 101
	,[467] = 102
	,[471] = 103
	,[473] = 104
	,[475] = 105
	,[476] = 106
	,[477] = 107
	,[478] = 108
	,[479] = 109
	,[480] = 110
	,[481] = 111
	,[482] = 112
	,[485] = 113
	,[486] = 114
	,[488] = 115
	,[490] = 116
	,[491] = 117
	,[492] = 118
	,[493] = 119
	,[495] = 120
	,[496] = 121
	,[499] = 122
	,[501] = 123
	,[502] = 124
	,[504] = 125
	,[510] = 127
	,[512] = 128
	,[520] = 129
	,[521] = 130
	,[522] = 132
	,[523] = 133
	,[524] = 136
	,[525] = 138
	,[526] = 140
	,[527] = 141
	,[528] = 142
	,[529] = 147
	,[530] = 153
	,[531] = 155
	,[532] = 156
	,[533] = 157
	,[534] = 160
	,[535] = 162
	,[536] = 168
	,[540] = 169
	,[541] = 170
	,[542] = 171
	,[543] = 172
	,[544] = 174
	,[545] = 179
	,[601] = 183
	,[602] = 184
	,[603] = 185
	,[604] = 186
	,[605] = 194
	,[606] = 198
	,[607] = 199
	,[609] = 200
	,[610] = 201
	,[611] = 202
	,[613] = 203
	,[614] = 204
	,[615] = 205
	,[626] = 206
	,[640] = 207
	,[673] = 210
	,[680] = 213
	,[684] = 217
	,[685] = 218
	,[686] = 219
	,[687] = 220
	,[688] = 221
	,[689] = 224
	,[690] = 225
	,[691] = 226
	,[692] = 230
	,[696] = 232
	,[697] = 233
	,[699] = 234
	,[700] = 241
	,[704] = 242
	,[708] = 244
	,[709] = 245
	,[710] = 246
	,[717] = 247
	,[718] = 248
	,[720] = 249
	,[721] = 250
	,[722] = 256
	,[723] = 258
	,[724] = 260
	,[725] = 261
	,[726] = 262
	,[727] = 263
	,[728] = 265
	,[729] = 266
	,[730] = 267
	,[731] = 269
	,[732] = 272
	,[733] = 273
	,[734] = 274
	,[736] = 275
	,[737] = 276
	,[747] = 277
	,[749] = 279
	,[750] = 280
	,[752] = 282
	,[753] = 283
	,[754] = 285
	,[755] = 287
	,[756] = 291
	,[757] = 293
	,[758] = 294
	,[759] = 297
	,[760] = 300
	,[761] = 301
	,[762] = 302
	,[763] = 306
	,[764] = 310
	,[765] = 317
	,[766] = 319
	,[767] = 322
	,[768] = 324
	,[769] = 325
	,[772] = 327
	,[773] = 328
	,[775] = 329
	,[776] = 330
	,[779] = 331
	,[780] = 332
	,[781] = 333
	,[782] = 334
	,[789] = 335
	,[793] = 337
	,[795] = 338
	,[796] = 339
	,[797] = 347
	,[798] = 348
	,[799] = 350
	,[800] = 367
	,[803] = 370
	,[806] = 371
	,[807] = 376
	,[808] = 378
	,[809] = 379
	,[810] = 388
	,[811] = 390
	,[813] = 397
	,[816] = 398
	,[819] = 399
	,[820] = 401
	,[823] = 407
	,[824] = 409
	,[851] = 416
	,[856] = 417
	,[857] = 418
	,[858] = 422
	,[860] = 423
	,[862] = 424
	,[864] = 425
	,[866] = 427
	,[867] = 429
	,[871] = 431
	,[873] = 433
	,[874] = 435
	,[875] = 437
	,[876] = 439
	,[877] = 443
	,[878] = 447
	,[880] = 448
	,[881] = 449
	,[882] = 450
	,[883] = 451
	,[884] = 452
	,[885] = 453
	,[886] = 456
	,[887] = 457
	,[888] = 460
	,[889] = 461
	,[890] = 462
	,[891] = 463
	,[892] = 465
	,[893] = 467
	,[894] = 468
	,[895] = 469
	,[896] = 471
	,[897] = 474
	,[898] = 476
	,[899] = 480
	,[900] = 481
	,[906] = 483
	,[911] = 486
	,[912] = 487
	,[914] = 488
	,[919] = 490
	,[920] = 498
	,[922] = 499
	,[924] = 501
	,[925] = 503
	,[928] = 504
	,[929] = 507
	,[930] = 508
	,[933] = 516
	,[934] = 518
	,[935] = 519
	,[937] = 520
	,[938] = 522
	,[939] = 523
	,[940] = 524
	,[941] = 525
	,[945] = 534
	,[946] = 535
	,[947] = 539
	,[948] = 542
	,[949] = 543
	,[950] = 550
	,[951] = 554
	,[953] = 556
	,[955] = 571
	,[962] = 572
	,[964] = 573
	,[969] = 574
	,[970] = 577
	,[971] = 579
	,[973] = 582
	,[976] = 585
	,[978] = 588
	,[980] = 590
	,[983] = 592
	,[984] = 593
	,[986] = 594
	,[987] = 595
	,[988] = 596
	,[989] = 601
	,[993] = 606
	,[994] = 610
	,[995] = 616
	,[1007] = 619
	,[1008] = 620
	,[1009] = 622
	,[1010] = 623
	,[1011] = 624
	,[1014] = 625
	,[1015] = 630
	,[1017] = 634
	,[1018] = 641
	,[1020] = 645
	,[1021] = 646
	,[1022] = 649
	,[1024] = 650
	,[1026] = 661
	,[1027] = 671
	,[1028] = 672
	,[1031] = 676
	,[1032] = 677
	,[1033] = 680
	,[1034] = 694
	,[1035] = 695
	,[1037] = 696
	,[1038] = 697
	,[1039] = 698
	,[1040] = 702
	,[1041] = 703
	,[1042] = 706
	,[1044] = 709
	,[1045] = 710
	,[1046] = 713
	,[1047] = 714
	,[1048] = 715
	,[1049] = 716
	,[1050] = 717
	,[1051] = 718
	,[1052] = 719
	,[1054] = 723
	,[1056] = 725
	,[1057] = 726
	,[1059] = 728
	,[1060] = 729
	,[1065] = 731
	,[1066] = 732
	,[1067] = 733
	,[1068] = 734
	,[1069] = 736
	,[1070] = 737
	,[1071] = 738
	,[1072] = 739
	,[1073] = 740
	,[1075] = 742
	,[1076] = 744
	,[1077] = 747
	,[1078] = 748
	,[1079] = 749
	,[1080] = 750
	,[1081] = 751
	,[1082] = 757
	,[1084] = 758
	,[1085] = 759
	,[1086] = 760
	,[1087] = 761
	,[1088] = 764
	,[1090] = 773
	,[1091] = 775
	,[1092] = 776
	,[1094] = 777
	,[1096] = 790
	,[1097] = 791
	,[1099] = 793
	,[1100] = 794
	,[1102] = 798
	,[1104] = 799
	,[1105] = 804
	,[1114] = 806
	,[1115] = 809
	,[1116] = 823
	,[1126] = 824
	,[1127] = 825
	,[1129] = 826
	,[1130] = 827
	,[1131] = 828
	,[1132] = 829
	,[1135] = 830
	,[1136] = 834
	,[1137] = 835
	,[1139] = 837
	,[1140] = 838
	,[1142] = 839
	,[1143] = 840
	,[1144] = 843
	,[1145] = 844
	,[1146] = 845
	,[1147] = 850
	,[1148] = 857
	,[1149] = 858
	,[1150] = 859
	,[1151] = 860
	,[1152] = 861
	,[1153] = 862
	,[1154] = 863
	,[1155] = 864
	,[1156] = 865
	,[1157] = 867
	,[1158] = 868
	,[1159] = 869
	,[1160] = 871
	,[1161] = 872
	,[1162] = 875
	,[1163] = 876
	,[1164] = 877
	,[1165] = 878
	,[1166] = 881
	,[1170] = 882
	,[1171] = 885
	,[1172] = 888
	,[1173] = 889
	,[1174] = 891
	,[1175] = 895
	,[1176] = 896
	,[1177] = 897
	,[1178] = 903
	,[1183] = 904
	,[1184] = 905
	,[1185] = 906
	,[1186] = 907
	,[1187] = 908
	,[1188] = 909
	,[1190] = 921
	,[1191] = 922
	,[1192] = 923
	,[1193] = 924
	,[1194] = 925
	,[1195] = 926
	,[1196] = 927
	,[1197] = 928
	,[1198] = 929
	,[1199] = 930
	,[1200] = 931
	,[1201] = 932
	,[1202] = 933
	,[1204] = 934
	,[1205] = 936
	,[1210] = 938
	,[1211] = 939
	,[1212] = 940
	,[1213] = 942
	,[1214] = 943
	,[1215] = 971
	,[1216] = 972
	,[1217] = 973
	,[1219] = 974
	,[1220] = 981

}

function DGV:OldMapId2UiMapID(oldWorldMapAreaID, oldDungeonMapID, oldDungeonFloor)
	oldWorldMapAreaID = tonumber(oldWorldMapAreaID)
	--UiMapID,WorldMapAreaID,DungeonMapID,DungeonFloor
	local key = ""..(oldWorldMapAreaID or "")..","..(oldDungeonMapID or "")..","..(oldDungeonFloor or "0")
	local result = mapKey2UiMapId[key]
	
	if result == nil then
		result = oldMapId2UiMapId[oldWorldMapAreaID]
	end
	
	return result or oldWorldMapAreaID
end

--In the future blizzard may convert another maps to the "high resolution/big" format as well.
--In case some map is displayed as horizontal lines please add that map id to the table below.
local uiMapID2isBigMap = {
	[876] = true,
	[942] = true,
	[896] = true,
	[895] = true,
	[1161] = true,
	[875] = true,
	[864] = true,
	[863] = true,
	[862] = true,
	[1165] = true,
	[947] = true,
	[1011] = true,
	[1014] = true,
	[994] = true,
}


--In API 8.0 maps have much higher resolution (256 * 15 X 256 * 10). Before API 8.0 maps were (256 * 4 X 256 * 3)
function DGV:IsBigMap(uiMapID)
	return uiMapID2isBigMap[uiMapID]
end

function DGV:GetAntScale(mapId) 
	--WORLDMAP_AZEROTH_ID
    local zoomFactor =  1/(1 + WorldMapFrame:GetCanvasZoomPercent() * 0.7)
    
	if WorldMapFrame:IsMaximized() then
		if mapId == WORLD_MAP_ID then
			return 3.3 * zoomFactor
		end

		if DGV:IsBigMap(mapId) then
			return 3.5 * zoomFactor
		end
		
		return 1.0 * zoomFactor
	else
		if mapId == WORLD_MAP_ID then
			return 4.5 * zoomFactor
		end

		if DGV:IsBigMap(mapId) then
			return 4.5 * zoomFactor
		end
		
		return 1.5* zoomFactor
	end
end

--If old map is not fund then this function returns just uiMapID
function DGV:UiMapID2OldMapId(uiMapID)
	return (uiMapId2OldMap[uiMapID] or {})[1] or uiMapID
end

--If old map is not fund then this function returns just 0
function DGV:UiMapID2DungeonLevel(uiMapID)
	return (uiMapId2OldMap[uiMapID] or {})[3] or 0
end

--Returns uiMapID in case it is a new map
function DGV:UiMapID2BaseMapId(uiMapID)
	local oldMapId = (uiMapId2OldMap[uiMapID] or {})[1]
	
	--Provided uiMapID is a new map
	if not oldMapId then
		return uiMapID
	end
	
	return oldMapId2UiMapId[oldMapId] or uiMapID
end

function DGV:IsPointOutOfTheMap(x, y)
	return (not x) or (not y) or x > 1 or x < 0 or y > 1 or y < 0
end


--Functions for terrain/minimap purposes.

--Replacement for old GetAreaMapInfo function
function DGV:GetAreaMapInfo_dugi(uiMapID)
    local oldAreaId = DGV:UiMapID2OldMapId(uiMapID)
    return oldAreaId2terrainMapId[oldAreaId]
end
  
--Replacement for old GetCurrentMapZone function
function DGV:GetCurrentMapZone_dugi(uiMapID)
    local areaID, floor_ = DGV:UiMapID2OldMapId(uiMapID), DGV:UiMapID2DungeonLevel(uiMapID)
    local result = GetCurrentMapZone_export[(areaID or 0)..","..(floor_ or 0)]
    if result then
        return unpack(result)
    end
end

--Replacement for old GetCurrentMapDungeonLevel function
function DGV:GetCurrentMapDungeonLevel_dugiDetails(uiMapID)
    local areaID, floor_ = DGV:UiMapID2OldMapId(uiMapID), DGV:UiMapID2DungeonLevel(uiMapID)
    local result = GetCurrentMapDungeonLevel_export[(areaID or 0)..","..(floor_ or 0)]
    if result then
        return unpack(result)
    end
end

--Replacement for old DungeonUsesTerrainMap function
function DGV:DungeonUsesTerrainMap_dugi(uiMapID)
    local areaID, floor_ = DGV:UiMapID2OldMapId(uiMapID), DGV:UiMapID2DungeonLevel(uiMapID)
    return DungeonUsesTerrainMap_export[(areaID or 0)..","..(floor_ or 0)]
end
