ExplorationTrackingPoints = {}
ExplorationTrackingPoints["Alliance"] = {}
ExplorationTrackingPoints["Horde"] = {}
--Allow atomatic addition of key/table combos

LuaUtils:foreach({ExplorationTrackingPoints, ExplorationTrackingPoints.Alliance, ExplorationTrackingPoints.Horde}, function(v, k)
    setmetatable(v,
    {
        __index = function(t,i)
            t[i] = {}
            return t[i]
        end,
    })
end)


local tappend = DugisGuideViewer.TableAppend
local points = ExplorationTrackingPoints
local DGV = DugisGuideViewer


--Example:
--/script searchAchievementWaypointsByMapName("Starbreeze Village")

-- Result:
--"areaName1" = {{x = x_y[1], y = x_y[2], subzoneName = description, zone = zoneName}, {x = x_y[1], y = x_y[2], subzoneName = description, zone = zoneNameB}},
--"areaName2" = {{x = x_y[1], y = x_y[2], subzoneName = description, zone = zoneName}},
--"areaName3" = {{x = x_y[1], y = x_y[2], subzoneName = description, zone = zoneName},{x = x_y[1], y = x_y[2], subzoneName = description, zone = zoneName},{x = x_y[1], y = x_y[2], subzoneName = description, zone = zoneName}},
function searchAchievementWaypointsByMapName(mapName)
    local searchKey = mapName
    local associativeResult = {}
    
    local englishFaction = UnitFactionGroup("player")
    
    local searchTable = LuaUtils:clone(points)
    
    if englishFaction == "Horde" then
        searchTable = LuaUtils:MergeTables(searchTable, points.Horde)
    end
    
    if englishFaction =="Alliance" then
        searchTable = LuaUtils:MergeTables(searchTable, points.Alliance)
    end
    
    for zoneNameKey, _table in pairs(searchTable) do
        for i = 1, #_table do
            local achevementData = _table[i]
            local a_coord_aId_critIndex_customLabel = LuaUtils:split(achevementData, ":")
            local achievementIdORLabel = a_coord_aId_critIndex_customLabel[3]
            local criteriaIndex = tonumber(a_coord_aId_critIndex_customLabel[4])

            local description
            local localizedMapName
            local zoneName
            local customLabel
            local localizedCustomLabel
            searchKey = strupper(searchKey)
            
            zoneName = LuaUtils:split(zoneNameKey, ":")
            zoneName = zoneName[1]

            local mapId = DGV:GetMapIDFromName(zoneName)

            if mapId and tonumber(mapId) then
                localizedMapName =  DGV:GetMapNameFromID(mapId)
            end
            
            if tonumber(achievementIdORLabel) and criteriaIndex then
                description = GetAchievementCriteriaInfo(tonumber(achievementIdORLabel), criteriaIndex)
            end
            
            if not tonumber(achievementIdORLabel) then
                customLabel = achievementIdORLabel
                localizedCustomLabel = DugisGuideViewer:localize(achievementIdORLabel, "ZONE")
            end

            if (description and strupper(description):match(searchKey))
            or (localizedMapName and strupper(localizedMapName):match(searchKey)) 
            or (customLabel and strupper(customLabel):match(searchKey)) 
            or (localizedCustomLabel and strupper(localizedCustomLabel):match(searchKey)) then
                local coordinates = a_coord_aId_critIndex_customLabel[2]
                local x_y = LuaUtils:split(coordinates, ",")

                local key = zoneName or description or "other places"
                
                local nodes = associativeResult[key]

                if not nodes then
                    associativeResult[key] = {}
                    nodes = associativeResult[key]
                end
                
                nodes[#nodes+1] = {x = x_y[1], y = x_y[2], subzoneName = description or localizedCustomLabel or customLabel or "?", zone = zoneName or "defaut"}
            end
        end
    end
    
    return associativeResult
end
----- Formatting -----
-- Rare: "R:location:<NPC ID>:extra note1:<additional location 1>:<additional location 2>",
-- Pet: "P:location:<Species ID>:extra note1:<additional location 1>:<additional location 2>",
-- Achievement:"A:<coordinates>:<achievement ID>:<criteria index(optional)>:<extra tooltip(optional)>",
---------------------------
for k, v in pairs(DugisWorldMapTrackingPoints.Alliance) do
  points.Alliance[k] = {}
end
for k, v in pairs(DugisWorldMapTrackingPoints.Horde) do
  points.Horde[k] = {}
end
tappend(points.Alliance["Westfall:0"])
tappend(points.Alliance["Darnassus:0"])
tappend(points.Alliance["DunMorogh:0"])
tappend(points.Alliance["Ashenvale:0"])
tappend(points.Alliance["SouthernBarrens:0"])
tappend(points.Alliance["Redridge:0"])
tappend(points.Alliance["LochModan:0"])
tappend(points.Alliance["BlastedLands:0"])
tappend(points.Alliance["Ironforge:0"])
tappend(points.Alliance["StormwindCity:0"])
tappend(points.Alliance["TwilightHighlands:0"])
tappend(points.Alliance["Elwynn:0"])
tappend(points.Alliance["Darkshore:0"])
tappend(points.Alliance["Duskwood:0"])
tappend(points.Alliance["Teldrassil:0"])
tappend(points.Alliance["StranglethornJungle:0"])
tappend(points.Alliance["TheCapeOfStranglethorn:0"])
tappend(points.Alliance["Krasarang:0"])
tappend(points.Horde["Undercity:0"])
tappend(points.Horde["Dalaran:1"])
tappend(points.Horde["Mulgore:0"])
tappend(points.Horde["SwampOfSorrows:0"])
tappend(points.Horde["SilvermoonCity:0"])
tappend(points.Horde["Durotar:0"])
tappend(points.Horde["Tirisfal:0"])
tappend(points.Horde["TwilightHighlands:0"])
tappend(points.Horde["Aszhara:0"])
tappend(points.Horde["Orgrimmar:1"])
tappend(points.Horde["Arathi:0"])
tappend(points.Horde["HillsbradFoothills:0"])
tappend(points.Horde["EversongWoods:0"])
tappend(points.Horde["ThunderBluff:0"])
tappend(points.Horde["Barrens:0"])
tappend(points.Horde["Ashenvale:0"])
tappend(points.Horde["StonetalonMountains:0"])
tappend(points.Horde["Desolace:0"])
tappend(points.Horde["SouthernBarrens:0"])
tappend(points.Horde["Krasarang:0"])
tappend(points["Tanaris:0"],                             
	"A:52.00,28.00:851:11", --Gadgetzan Tanaris	 161
	"A:73.00,46.00:851:2", --Lost Rigger Cove Tanaris	 161
	"A:52.00,45.00:851:9", --Broken Pillar Tanaris	 161
	"A:65.00,49.00:851:12", --Caverns of Time Tanaris	 161
	"A:64.00,60.00:851:16", --Southbreak Shore Tanaris	 161
	"A:54.00,92.00:851:6", --Land's End Beach Tanaris	 161
	"A:52.00,67.00:851:5", --The Gaping Chasm Tanaris	 161
	"A:47.00,65.00:851:10", --Eastmoon Ruins Tanaris	 161
	"A:40.00,71.00:851:13", --Southmoon Ruins Tanaris	 161
	"A:37.00,77.00:851:1", --Valley of the Watchers Tanaris	 161
	"A:29.00,64.00:851:7", --Thistleshrub Valley Tanaris	 161
	"A:40.00,55.00:851:4", --Dunemaul Compound Tanaris	 161
	"A:36.00,43.00:851:3", --The Noxious Lair Tanaris	 161
	"A:45.00,41.00:851:15", --Abyssal Sands Tanaris	 161
	"A:38.00,27.00:851:14", --Sandsorrow Watch Tanaris	 161
	"A:38.00,16.00:851:8") --Zul'Farrak Tanaris	 161

tappend(points["DeathknellStart:0"])
tappend(points["Feralas:0"],
	"A:46.00,18.00:849:3", --The Twin Colossals Feralas	 121
	"A:48.00,43.00:849:4", --The Forgotten Coast Feralas	 121
	"A:46.00,45.00:849:13", --Feathermoon Stronghold Feralas	 121
	"A:32.00,44.00:849:2", --Ruins of Feathermoon Feralas	 121
	"A:54.00,56.00:849:6", --Feral Scar Vale Feralas	 121
	"A:59.00,69.00:849:7", --Ruins of Isildien Feralas	 121
	"A:65.00,60.00:849:12", --Darkmist Ruins Feralas	 121
	"A:59.00,43.00:849:5", --Dire Maul Feralas	 121
	"A:69.00,40.00:849:10", --Grimtotem Compound Feralas	 121
	"A:77.00,31.00:849:11", --Gordunni Outpost Feralas	 121
	"A:75.00,42.00:849:9", --Camp Mojache Feralas	 121
	"A:73.00,53.00:849:1", --Lower Wilds Feralas	 121
	"A:75.00,61.00:849:8") --The Writhing Deep Feralas	 121

tappend(points["BoreanTundra:0"],
	"A:50.00,9.00:1264:8", --Bor'gorok Outpost Borean Tundra	 486
	"A:49.00,25.00:1264:2", --Steeljaw's Caravan Borean Tundra	 486
	"A:45.00,33.00:1264:9", --Amber Ledge Borean Tundra	 486
	"A:27.00,37.00:1264:7", --Coldarra Borean Tundra	 486
	"A:32.00,54.00:1264:5", --Garrosh's Landing Borean Tundra	 486
	"A:44.00,56.00:1264:10", --Warsong Hold Borean Tundra	 486
	"A:44.00,78.00:1264:3", --Riplash Strand Borean Tundra	 486
	"A:53.00,71.00:1264:11", --Valiance Keep Borean Tundra	 486
	"A:64.00,48.00:1264:4", --Kaskala Borean Tundra	 486
	"A:67.00,24.00:1264:12", --The Geyser Fields Borean Tundra	 486
	"A:76.00,19.00:1264:13", --The Dens of Dying Borean Tundra	 486
	"A:82.00,24.00:1264:1", --Temple City of En'kilah Borean Tundra	 486
	"A:82.00,47.00:1264:6") --Death's Stand Borean Tundra	 486

tappend(points["TheCapeOfStranglethorn:0"],
	"A:42.00,68.00:4995:1", --Booty Bay The Cape of Stranglethorn	 673
	"A:50.00,68.00:4995:10", --Wild Shore The Cape of Stranglethorn	 673
	"A:56.00,75.00:4995:5", --Jaguero Isle The Cape of Stranglethorn	 673
	"A:50.00,56.00:4995:6", --Mistvale Valley The Cape of Stranglethorn	 673
	"A:42.00,49.00:4995:7", --Nek'mani Wellspring The Cape of Stranglethorn	 673
	"A:34.00,30.00:4995:4", --Hardwrench Hideaway The Cape of Stranglethorn	 673
	"A:50.00,29.00:4995:3", --Gurubashi Arena The Cape of Stranglethorn	 673
	"A:53.00,31.00:4995:9", --Ruins of Jubuwal The Cape of Stranglethorn	 673
	"A:60.00,42.00:4995:8", --Ruins of Aboraz The Cape of Stranglethorn	 673
	"A:62.00,30.00:4995:2") --Crystalvein Mine The Cape of Stranglethorn	 673

tappend(points["GrizzlyHills:0"],
	"A:14.00,86.00:1266:9", --Venture Bay Grizzly Hills	 490
	"A:28.00,74.00:1266:10", --Voldrune Grizzly Hills	 490
	"A:21.00,65.00:1266:1", --Conquest Hold Grizzly Hills	 490
	"A:31.00,60.00:1266:11", --Amberpine Lodge Grizzly Hills	 490
	"A:16.00,47.00:1266:5", --Granite Springs Grizzly Hills	 490
	"A:18.00,25.00:1266:2", --Drak'Tharon Keep Grizzly Hills	 490
	"A:37.00,36.00:1266:12", --Blue Sky Logging Grounds Grizzly Hills	 490
	"A:50.00,42.00:1266:6", --Grizzlemaw Grizzly Hills	 490
	"A:50.00,57.00:1266:7", --Rage Fang Shrine Grizzly Hills	 490
	"A:76.00,58.00:1266:4", --Dun Argol Grizzly Hills	 490
	"A:65.00,47.00:1266:13", --Camp Oneqwah Grizzly Hills	 490
	"A:57.00,30.00:1266:14", --Westfall Brigade Encampment Grizzly Hills	 490
	"A:71.00,26.00:1266:3", --Drakil'jin Ruins Grizzly Hills	 490
	"A:69.00,15.00:1266:8") --Thor Modan Grizzly Hills	 490

tappend(points["ZulDrak:0"],
	"A:77.00,59.00:1267:6", --Altar of Quetz'lun Zul'Drak	 496
	"A:59.00,57.00:1267:9", --Zim'Torga Zul'Drak	 496
	"A:63.00,71.00:1267:8", --Altar of Har'koa Zul'Drak	 496
	"A:61.00,78.00:1267:14", --Kolramas Zul'Drak	 496
	"A:43.00,77.00:1267:2", --Drak'Sotra Fields Zul'Drak	 496
	"A:49.00,56.00:1267:3", --Amphitheater of Anguish Zul'Drak	 496
	"A:32.00,75.00:1267:13", --Light's Breach Zul'Drak	 496
	"A:21.00,76.00:1267:10", --Zeramas Fly Zul'Drak	 496
	"A:17.00,58.00:1267:12", --Thrym's End Zul'Drak	 496
	"A:28.00,46.00:1267:11", --Voltarus Fly Zul'Drak	 496
	"A:40.00,38.00:1267:4", --Altar of Sseratus Zul'Drak	 496
	"A:53.00,36.00:1267:5", --Altar of Rhunok Zul'Drak	 496
	"A:76.00,43.00:1267:7", --Altar of Mam'toth Zul'Drak	 496
	"A:82.00,20.00:1267:1") --Gundrak Zul'Drak	 496

tappend(points["Dalaran:1"])
tappend(points["VashjirDepths:0"],
	"A:70.00,29.00:4825:2", --Abyssal Breach Vashj'ir	 614
	"A:40.00,18.00:4825:4", --Deepfin Ridge Vashj'ir	 614
	"A:55.00,43.00:4825:7", --Seabrush Vashj'ir	 614
	"A:40.00,40.00:4825:8", --The Scalding Chasm Vashj'ir	 614
	"A:31.00,47.00:4825:6", --L'ghorek Vashj'ir	 614
	"A:23.00,73.00:4825:1", --Abandoned Reef Vashj'ir	 614
	"A:43.00,64.00:4825:3", --Underlight Canyon Vashj'ir	 614
	"A:51.00,67.00:4825:5") --Korthun's End Vashj'ir	 614

tappend(points["Hinterlands:0"],
	"A:13.00,48.00:773:1", --Aerie Peak The Hinterlands	 26
	"A:24.00,43.00:773:2", --Plaguemist Ravine The Hinterlands	 26
	"A:30.00,48.00:773:4", --Quel'Danil Lodge The Hinterlands	 26
	"A:23.00,58.00:773:3", --Zun'watha The Hinterlands	 26
	"A:34.00,70.00:773:5", --Shadra'Alor The Hinterlands	 26
	"A:40.00,59.00:773:6", --Valorwind Lake The Hinterlands	 26
	"A:48.00,66.00:773:9", --The Altar of Zul The Hinterlands	 26
	"A:48.00,52.00:773:8", --The Creeping Ruin The Hinterlands	 26
	"A:47.00,40.00:773:7", --Agol'watha The Hinterlands	 26
	"A:57.00,40.00:773:11", --Skulk Rock The Hinterlands	 26
	"A:63.00,24.00:773:10", --Seradane The Hinterlands	 26
	"A:72.00,53.00:773:12", --Shaol'watha The Hinterlands	 26
	"A:62.00,72.00:773:13", --Jintha'Alor The Hinterlands	 26
	"A:72.00,66.00:773:14") --The Overlook Cliffs The Hinterlands	 26

tappend(points["Mulgore:0"],
	"A:43.00,16.00:736:13", --Wildmane Water Well Mulgore	 9
	"A:52.00,11.00:736:12", --Windfury Ridge Mulgore	 9
	"A:49.00,35.00:736:8", --The Golden Plains Mulgore	 9
	"A:44.00,45.00:736:9", --Thunderhorn Water Well Mulgore	 9
	"A:32.00,48.00:736:10", --Bael'dun Digsite Mulgore	 9
	"A:34.00,62.00:736:2", --Palemane Rock Mulgore	 9
	"A:49.00,58.00:736:3", --Bloodhoof Village Mulgore	 9
	"A:39.00,82.00:736:1", --Red Cloud Mesa Mulgore	 9
	"A:53.00,66.00:736:4", --Winterhoof Water Well Mulgore	 9
	"A:53.00,47.00:736:7", --Ravaged Caravan Mulgore	 9
	"A:62.00,48.00:736:6", --The Venture Co. Mine Mulgore	 9
	"A:64.00,63.00:736:5", --The Rolling Plains Mulgore	 9
	"A:60.00,21.00:736:11") --Red Rocks Mulgore	 9

tappend(points["SwampOfSorrows:0"],
	"A:46.00,54.00:782:5", --Stonard Swamp of Sorrows	 38
	"A:65.00,54.00:782:6", --Pool of Tears Swamp of Sorrows	 38
	"A:66.00,73.00:782:7", --Stagalbog Swamp of Sorrows	 38
	"A:81.00,87.00:782:10", --Misty Reed Strand Swamp of Sorrows	 38
	"A:84.00,36.00:782:8", --Sorrowmurk Swamp of Sorrows	 38
	"A:73.00,13.00:782:9", --Bogpaddle Swamp of Sorrows	 38
	"A:68.00,36.00:782:12", --Marshtide Watch Swamp of Sorrows	 38
	"A:39.00,42.00:782:4", --The Shifting Mire Swamp of Sorrows	 38
	"A:30.00,33.00:782:2", --The Harborage Swamp of Sorrows	 38
	"A:14.00,36.00:782:1", --Misty Valley Swamp of Sorrows	 38
	"A:24.00,50.00:782:3", --Splinterspear Junction Swamp of Sorrows	 38
	"A:18.00,65.00:782:11") --Purespring Cavern Swamp of Sorrows	 38

tappend(points["Silverpine:0"],
	"A:57.00,08.00:769:13", --Forsaken High Command Silverpine Forest	 21
	"A:66.00,27.00:769:6", --Fenris Isle Silverpine Forest	 21
	"A:57.00,34.00:769:2", --The Decrepit Ferry Silverpine Forest	 21
	"A:52.00,25.00:769:3", --Valgan's Field Silverpine Forest	 21
	"A:44.00,20.00:769:15", --Forsaken Rear Guard Silverpine Forest	 21
	"A:35.00,13.00:769:4", --The Skittering Dark Silverpine Forest	 21
	"A:31.00,18.00:769:14", --North Tide's Run Silverpine Forest	 21
	"A:39.00,28.00:769:5", --North Tide's Beachhead Silverpine Forest	 21
	"A:43.00,41.00:769:8", --The Sepulcher Silverpine Forest	 21
	"A:47.00,53.00:769:10", --Olsen's Farthing Silverpine Forest	 21
	"A:55.00,47.00:769:9", --Deep Elem Mine Silverpine Forest	 21
	"A:61.00,64.00:769:11", --Ambermill Silverpine Forest	 21
	"A:44.00,68.00:769:12", --Shadowfang Keep Silverpine Forest	 21
	"A:51.00,65.00:769:3", --The Forsaken Front Silverpine Forest	 21
	"A:49.00,78.00:769:1") --The Battlefront Silverpine Forest	 21

tappend(points["BlastedLands:0"],
	"A:54.00,53.00:766:5", --The Dark Portal Blasted Lands	 19
	"A:64.00,74.00:766:13", --The Red Reaches Blasted Lands	 19
	"A:50.00,72.00:766:11", --Sunveil Excursion Blasted Lands	 19
	"A:45.00,85.00:766:12", --Surwich Blasted Lands	 19
	"A:37.00,75.00:766:14", --The Tainted Forest Blasted Lands	 19
	"A:34.00,48.00:766:8", --The Tainted Scar Blasted Lands	 19
	"A:45.00,39.00:766:7", --Dreadmaul Post Blasted Lands	 19
	"A:37.00,29.00:766:6", --Altar of Storms Blasted Lands	 19
	"A:44.00,26.00:766:9", --Rise of the Defiler Blasted Lands	 19
	"A:60.00,29.00:766:4", --Serpent's Coil Blasted Lands	 19
	"A:68.00,33.00:766:10", --Shattershore Blasted Lands	 19
	"A:61.00,19.00:766:3", --Nethergarde Keep Blasted Lands	 19
	"A:53.00,17.00:766:2", --Nethergarde Supply Camps Blasted Lands	 19
	"A:43.00,14.00:766:1") --Dreadmaul Hold Blasted Lands	 19
	
tappend(points["BladesEdgeMountains:0"],
	"A:77.00,24.00:865:6", --Broken Wilds Blade's Edge Mountains	 475
	"A:72.00,23.00:865:19", --Skald Blade's Edge Mountains	 475
	"A:65.00,24.00:865:13", --Gruul's Lair Blade's Edge Mountains	 475
	"A:64.00,14.00:865:21", --Crystal Spine Blade's Edge Mountains	 475
	"A:52.00,12.00:865:1", --Bash'ir Landing Blade's Edge Mountains	 475
	"A:55.00,27.00:865:4", --Bloodmaul Camp Blade's Edge Mountains	 475
	"A:64.00,31.00:865:24", --Veil Ruuan Blade's Edge Mountains	 475
	"A:62.00,34.00:865:18", --Ruuan Weald Blade's Edge Mountains	 475
	"A:70.00,42.00:865:2", --Bladed Gulch Blade's Edge Mountains	 475
	"A:73.00,41.00:865:9", --Forge Camp: Anger Blade's Edge Mountains	 475
	"A:65.00,53.00:865:17", --Razor Ridge Blade's Edge Mountains	 475
	"A:71.00,61.00:865:25", --Vekhaar Stand Blade's Edge Mountains	 475
	"A:74.00,61.00:865:15", --Mok'Nathal Village Blade's Edge Mountains	 475
	"A:64.00,67.00:865:8", --Death's Door Blade's Edge Mountains	 475
	"A:49.00,70.00:865:14", --Jagged Ridge Blade's Edge Mountains	 475
	"A:52.00,56.00:865:22", --Thunderlord Stronghold Blade's Edge Mountains	 475
	"A:53.00,43.00:865:7", --Circle of Blood Blade's Edge Mountains	 475
	"A:40.00,53.00:865:3", --Bladespire Hold Blade's Edge Mountains	 475
	"A:36.00,39.00:865:11", --Forge Camp: Wrath Blade's Edge Mountains	 475
	"A:39.00,20.00:865:12", --Grishnath Blade's Edge Mountains	 475
	"A:31.00,28.00:865:16", --Raven's Wood Blade's Edge Mountains	 475
	"A:28.00,48.00:865:26", --Vortex Summit Blade's Edge Mountains	 475
	"A:28.00,81.00:865:10", --Forge Camp: Terror Blade's Edge Mountains	 475
	"A:35.00,76.00:865:23", --Veil Lashh Blade's Edge Mountains	 475
	"A:37.00,64.00:865:20", --Sylvanaar Blade's Edge Mountains	 475
	"A:46.00,77.00:865:5") --Bloodmaul Outpost Blade's Edge Mountains	 475
	
tappend(points["Zangarmarsh:0"],
	"A:42.00,30.00:863:15", --Orebor Harborage Zangarmarsh	 467
	"A:61.00,41.00:863:14", --Bloodscale Grounds Zangarmarsh	 467
	"A:68.00,48.00:863:7", --Telredor Zangarmarsh	 467
	"A:81.00,38.00:863:8", --The Dead Mire Zangarmarsh	 467
	"A:79.00,64.00:863:1", --Cenarion Refuge Zangarmarsh	 467
	"A:83.00,82.00:863:11", --Umbrafen Village Zangarmarsh	 467
	"A:70.00,80.00:863:18", --Darkcrest Shore Zangarmarsh	 467
	"A:58.00,62.00:863:9", --The Lagoon Zangarmarsh	 467
	"A:47.00,53.00:863:10", --Twin Spire Ruins Zangarmarsh	 467
	"A:46.00,63.00:863:3", --Feralfen Village Zangarmarsh	 467
	"A:29.00,61.00:863:6", --Quagg Ridge Zangarmarsh	 467
	"A:31.00,50.00:863:17", --Zabra'jin Zangarmarsh	 467
	"A:29.00,33.00:863:4", --Hewn Bog Zangarmarsh	 467
	"A:17.00,23.00:863:2", --Ango'rosh Grounds Zangarmarsh	 467
	"A:18.00,7.00:863:13", --Ango'rosh Stronghold Zangarmarsh	 467
	"A:22.00,40.00:863:5", --Marshlight Lake Zangarmarsh	 467
	"A:18.00,50.00:863:12", --Sporeggar Zangarmarsh	 467
	"A:14.00,62.00:863:16") --The Spawning Glen Zangarmarsh	 467
	
tappend(points["StranglethornJungle:0"],
	"A:52.00,66.00:781:4", --Fort Livingston Northern Stranglethorn	 37
	"A:60.00,55.00:781:2", --Balia'mah Ruins Northern Stranglethorn	 37
	"A:65.00,50.00:781:11", --Mosh'Ogg Ogre Mound Northern Stranglethorn	 37
	"A:64.00,40.00:781:3", --Bambala Northern Stranglethorn	 37
	"A:46.00,53.00:781:10", --Mizjah Ruins Northern Stranglethorn	 37
	"A:39.00,50.00:781:1", --Grom'gol Base Camp Northern Stranglethorn	 37
	"A:42.00,41.00:781:9", --Kal'ai Ruins Northern Stranglethorn	 37
	"A:34.00,36.00:781:13", --Bal'lal Ruins Northern Stranglethorn	 37
	"A:29.00,42.00:781:14", --The Vile Reef Northern Stranglethorn	 37
	"A:19.00,24.00:781:5", --Zuuldaia Ruins Northern Stranglethorn	 37
	"A:25.00,21.00:781:15", --Ruins of Zul'Kunda Northern Stranglethorn	 37
	"A:43.00,22.00:781:6", --Nesingwary's Expedition Northern Stranglethorn	 37
	"A:51.00,33.00:781:12", --Lake Nazferiti Northern Stranglethorn	 37
	"A:67.00,32.00:781:16", --Zul'Gurub Northern Stranglethorn	 37
	"A:57.00,21.00:781:8", --Kurzen's Compound Northern Stranglethorn	 37
	"A:47.00,11.00:781:7") --Rebel Camp Northern Stranglethorn	 37
	
tappend(points["Netherstorm:0"],
	"A:48.00,84.00:843:12", --Wizard Row Netherstorm	 479
	"A:48.00,84.00:843:3", --Manaforge Coruu Netherstorm	 479
	"A:40.00,75.00:843:10", --Arklon Ruins Netherstorm	 479
	"A:56.00,78.00:843:15", --Sunfury Hold Netherstorm	 479
	"A:59.00,67.00:843:4", --Manaforge Duro Netherstorm	 479
	"A:71.00,65.00:843:8", --Tempest Keep Netherstorm	 479
	"A:72.00,40.00:843:11", --Celestial Ridge Netherstorm	 479
	"A:62.00,39.00:843:6", --Manaforge Ultris Netherstorm	 479
	"A:55.00,42.00:843:19", --Ethereum Staging Grounds Netherstorm	 479
	"A:45.00,54.00:843:18", --Dome Midrealm Netherstorm	 479
	"A:44.00,36.00:843:16", --The Stormspire Netherstorm	 479
	"A:54.00,25.00:843:7", --Ruins of Farahlon Netherstorm	 479
	"A:49.00,18.00:843:13", --Netherstone Netherstorm	 479
	"A:45.00,13.00:843:18", --Dome Farfield Netherstorm	 479
	"A:37.00,25.00:843:21", --Forge Base: Oblivion Netherstorm	 479
	"A:29.00,15.00:843:20", --Socrethar's Seat Netherstorm	 479
	"A:26.00,38.00:843:5", --Manaforge Ara Netherstorm	 479
	"A:32.00,56.00:843:14", --Ruins of Enkaat Netherstorm	 479
	"A:33.00,65.00:843:1", --Area 52 Netherstorm	 479
	"A:31.00,76.00:843:9", --The Heap Netherstorm	 479
	"A:22.00,70.00:843:2", --Manaforge B'naar Netherstorm	 479
	"A:22.00,56.00:843:17") --Plank Bridge Netherstorm	 479
	
tappend(points["StonetalonMountains:0"],
	"A:77.00,90.00:847:12", --Greatwood Vale Stonetalon Mountains	 81
	"A:77.00,77.00:847:5", --Unearthed Grounds Stonetalon Mountains	 81
	"A:69.00,92.00:847:9", --Malaka'jin Stonetalon Mountains	 81
	"A:62.00,89.00:847:11", --Boulderslide Ravine Stonetalon Mountains	 81
	"A:54.00,56.00:847:10", --Webwinder Path Stonetalon Mountains	 81
	"A:57.00,73.00:847:6", --Webwinder Hollow Stonetalon Mountains	 81
	"A:66.00,63.00:847:2", --Krom'gar Fortress Stonetalon Mountains	 81
	"A:67.00,55.00:847:13", --Windshear Crag Stonetalon Mountains	 81
	"A:58.00,55.00:847:7", --Windshear Hold Stonetalon Mountains	 81
	"A:48.00,77.00:847:3", --Ruins of Eldre'thar Stonetalon Mountains	 81
	"A:49.00,62.00:847:14", --Sun Rock Retreat Stonetalon Mountains	 81
	"A:49.00,47.00:847:16", --Mirkfallon Lake Stonetalon Mountains	 81
	"A:46.00,35.00:847:8", --Cliffwalker Post Stonetalon Mountains	 81
	"A:43.00,24.00:847:17", --Stonetalon Peak Stonetalon Mountains	 81
	"A:39.00,31.00:847:4", --Thal'darah Overlook Stonetalon Mountains	 81
	"A:41.00,38.00:847:1", --Battlescar Valley Stonetalon Mountains	 81
	"A:34.00,69.00:847:15") --The Charred Vale Stonetalon Mountains	 81

tappend(points["Barrens:0"],
	"A:42.70,15.30:750:3", --The Mor'shan Rampart Northern Barrens	 11
	"A:67.00,40.00:750:3", --Far Watch Post Northern Barrens	 11
	"A:66.00,13.00:750:1", --Boulder Lode Mine Northern Barrens	 11
	"A:58.00,19.00:750:4", --The Sludge Fen Northern Barrens	 11
	"A:43.00,38.00:750:5", --Dreadmist Peak Northern Barrens	 11
	"A:54.00,40.00:750:8", --Grol'dom Farm Northern Barrens	 11
	"A:55.00,50.00:750:10", --Thorn Hill Northern Barrens	 11
	"A:50.00,58.00:750:11", --The Crossroads Northern Barrens	 11
	"A:67.00,72.00:750:13", --Ratchet Northern Barrens	 11
	"A:69.00,80.00:750:14", --The Merchant Coast Northern Barrens	 11
	"A:55.00,80.00:750:12", --The Stagnant Oasis Northern Barrens	 11
	"A:41.00,74.00:750:2", --Lushwater Oasis Northern Barrens	 11
	"A:37.00,46.00:750:7", --The Forgotten Pools Northern Barrens	 11
	"A:29.00,35.00:750:6") --The Dry Hills Northern Barrens	 11
	
tappend(points["Dustwallow:0"],
	"A:30.00,48.00:850:5", --Shady Rest Inn Dustwallow Marsh	 141
	"A:41.00,73.00:850:4", --Mudsprocket Dustwallow Marsh	 141
	"A:52.00,73.00:850:8", --Wyrmbog Dustwallow Marsh	 141
	"A:46.00,47.00:850:3", --Direhorn Post Dustwallow Marsh	 141
	"A:36.00,31.00:850:7", --Brackenwall Village Dyslix Silvergrub	 141
	"A:41,11.00:850:2", --Blackhoof Village Dustwallow Marsh	 141
	"A:66.00,44.00:850:1", --Theramore Isle Dustwallow Marsh	 141
	"A:72.00,19.00:850:9", --Alcaz Island Dustwallow Marsh	 141
	"A:61.00,20.00:850:6") --Dreadmurk Shore Dustwallow Marsh	 141
	
tappend(points["SholazarBasin:0"],
	"A:46.00,25.00:1268:2", --The Savage Thicket Sholazar Basin	 493
	"A:49.00,38.00:1268:10", --The Glimmering Pillar Sholazar Basin	 493
	"A:73.00,36.00:1268:9", --The Avalanche Sholazar Basin	 493
	"A:80.00,54.00:1268:4", --Makers' Overlook Sholazar Basin	 493
	"A:65.00,59.00:1268:8", --The Lifeblood Pillar Sholazar Basin	 493
	"A:54.00,56.00:1268:7", --Rainspeaker Canopy Sholazar Basin	 493
	"A:48.00,63.00:1268:1", --River's Heart Sholazar Basin	 493
	"A:33.00,52.00:1268:6", --The Suntouched Pillar Sholazar Basin	 493
	"A:29.00,38.00:1268:5", --Makers' Perch Sholazar Basin	 493
	"A:26.00,35.00:1268:12", --The Stormwright's Shelf Sholazar Basin	 493
	"A:25.00,81.00:1268:11", --Kartak's Hold Sholazar Basin	 493
	"A:36.00,75.00:1268:3") --The Mosslight Pillar Sholazar Basin	 493
	
tappend(points["Durotar:0"],
	"A:54.00,10.00:728:11", --Skull Rock Durotar	 4
	"A:53.00,23.00:728:10", --Drygulch Ravine Durotar	 4
	"A:53.00,43.00:728:7", --Razor Hill Durotar	 4
	"A:58.00,56.00:728:6", --Tiragarde Keep Durotar	 4
	"A:55.00,74.00:728:4", --Sen'jin Village Durotar	 4
	"A:65.00,83.00:728:5", --Echo Isles Durotar	 4
	"A:48.00,78.00:728:2", --Northwatch Foothold Durotar	 4
	"A:44.00,59.00:728:1", --Valley of Trials Durotar	 4
	"A:43.00,49.00:728:8", --Razormane Grounds Durotar	 4
	"A:37.00,42.00:728:3", --Southfury Watershed Durotar	 4
	"A:42.00,8.00:728:12", --Orgrimmar Durotar	 4	
	"A:39.00,28.00:728:9") --Thunder Ridge Durotar	 4

tappend(points["Desolace:0"],
	"A:49.00,07.00:848:1", --Tethris Aran Desolace	 101
	"A:65.00,08.00:848:3", --Nijel's Point Desolace	 101
	"A:76.00,21.00:848:4", --Sargeron Desolace	 101
	"A:55.00,28.00:848:5", --Thunder Axe Fortress Desolace	 101
	"A:28.00,9.00:848:8", --Ranazjar Isle Desolace	 101
	"A:30.00,28.00:848:16", --Slitherblade Shore Desolace	 101
	"A:52.00,48.00:848:6", --Cenarion Wildlands Desolace	 101
	"A:50.00,57.00:848:10", --Kodo Graveyard Desolace	 101
	"A:74.00,49.00:848:7", --Magram Territory Desolace	 101
	"A:73.00,73.00:848:14", --Shok'Thokar Desolace	 101
	"A:79.00,77.00:848:15", --Shadowbreak Ravine Desolace	 101
	"A:52.00,76.00:848:13", --Mannoroc Coven Desolace	 101
	"A:36.00,71.00:848:2", --Thargad's Camp Desolace	 101
	"A:33.00,58.00:848:9", --Valley of Spears Desolace	 101
	"A:24.00,70.00:848:11", --Shadowprey Village Desolace	 101
	"A:34.00,86.00:848:12") --Gelkis Village Desolace	 101
	
tappend(points["Tirisfal:0"],
	"A:75.00,61.00:768:9", --Balnir Farmstead Tirisfal Glades	 20
	"A:78.00,54.00:768:10", --Crusader Outpost Tirisfal Glades	 20
	"A:84.00,47.00:768:12", --Venomweb Vale Tirisfal Glades	 20
	"A:82.00,32.00:768:14", --Scarlet Monastery Tirisfal Glades	 20
	"A:79.00,29.00:768:11", --Scarlet Watch Post Tirisfal Glades	 20
	"A:68.00,37.00:768:8", --Brightwater Lake Tirisfal Glades	 20
	"A:59.00,35.00:768:7", --Garren's Haunt Tirisfal Glades	 20
	"A:59.00,51.00:768:6", --Brill Tirisfal Glades	 20
	"A:53.00,57.00:768:5", --Cold Hearth Manor Tirisfal Glades	 20
	"A:49.00,52.00:768:16", --Calston Estate Tirisfal Glades	 20
	"A:48.00,39.00:768:3", --Agamand Mills Tirisfal Glades	 20
	"A:36.00,50.00:768:2", --Solliden Farmstead Tirisfal Glades	 20
	"A:35.00,59.00:768:1", --Deathknell Tirisfal Glades	 20
	"A:48.00,64.00:768:4", --Nightmare Vale Tirisfal Glades	 20
	"A:81.00,69.00:768:15", --The Bulwark Tirisfal Glades	 20
	"A:61.00,64.00:768:13") --Ruins of Lordaeron Tirisfal Glades	 20

tappend(points["Ashenvale:0"],
	"A:93.00,35.00:845:16", --Bough Shadow Ashenvale	 43
	"A:80.00,49.00:845:15", --Satyrnaar Ashenvale	 43
	"A:83.00,57.00:845:17", --Warsong Lumber Camp Ashenvale	 43
	"A:89.00,77.00:845:18", --Felfire Hill Ashenvale	 43
	"A:66.00,82.00:845:13", --Fallen Sky Lake Ashenvale	 43
	"A:73.00,62.00:845:14", --Splintertree Post Ashenvale	 43
	"A:54.00,36.00:845:11", --The Howling Vale Ashenvale	 43
	"A:61.00,51.00:845:12", --Raynewood Retreat Ashenvale	 43
	"A:50.00,67.00:845:3", --Silverwind Refuge Ashenvale	 43
	"A:50.00,53.00:845:4", --Thunder Peak Ashenvale	 43
	"A:36.00,50.00:845:9", --Astranaar Ashenvale	 43
	"A:33.00,67.00:845:10", --The Ruins of Stardust Ashenvale	 43
	"A:22.00,53.00:845:8", --The Shrine of Aessina Ashenvale	 43
	"A:31.00,44.00:845:7", --Thistlefur Village Ashenvale	 43
	"A:26.00,37.00:845:6", --Maestra's Post Ashenvale	 43
	"A:20.00,42.00:845:5", --Lake Falathim Ashenvale	 43
	"A:14.00,27.00:845:1", --The Zoram Strand Ashenvale	 43
	"A:26.00,21.00:845:2") --Orendil's Retreat Ashenvale	 43

tappend(points["Dragonblight:0"],
	"A:14.00,47.00:1265:13", --Westwind Refugee Camp Dragonblight	 488
	"A:25.00,43.00:1265:7", --Icemist Village Dragonblight	 488
	"A:36.00,46.00:1265:11", --Agmar's Hammer Dragonblight	 488
	"A:40.00,67.00:1265:2", --Lake Indu'le Dragonblight	 488
	"A:63.00,73.00:1265:8", --Emerald Dragonshrine Dragonblight	 488
	"A:59.00,54.00:1265:12", --Wyrmrest Temple Dragonblight	 488
	"A:55.00,34.00:1265:1", --Galakrond's Rest Dragonblight	 488
	"A:40.00,31.00:1265:3", --Obsidian Dragonshrine Dragonblight	 488
	"A:37.00,17.00:1265:10", --Angrathar the Wrathgate Dragonblight	 488
	"A:55.00,20.00:1265:9", --Coldwind Heights Dragonblight	 488
	"A:60.00,20.00:1265:16", --The Crystal Vice Dragonblight	 488
	"A:73.00,25.00:1265:17", --Scarlet Point Dragonblight	 488
	"A:84.00,26.00:1265:6", --Light's Trust Dragonblight	 488
	"A:87.00,50.00:1265:5", --Naxxramas Dragonblight	 488
	"A:76.00,62.00:1265:14", --Venomspite Dragonblight	 488
	"A:71.00,74.00:1265:4", --New Hearthglen Dragonblight	 488
	"A:82.00,68.00:1265:15") --The Forgotten Shore Dragonblight	 488

tappend(points["Dalaran:2"])
tappend(points["TerokkarForest:0"],
	"A:56.00,19.00:867:11", --Razorthorn Shelf Terokkar Forest	 478
	"A:19.00,62.00:867:1", --Bleeding Hollow Ruins Terokkar Forest	 478
	"A:29.00,12.00:867:10", --The Barrier Hills Terokkar Forest	 478
	"A:35.00,30.00:867:8", --Shattrath City Terokkar Forest	 478
	"A:41.00,22.00:867:3", --Cenarion Thicket Terokkar Forest	 478
	"A:38.00,39.00:867:5", --Grangol'var Village Terokkar Forest	 478
	"A:42.00,52.00:867:14", --Carrion Hill Terokkar Forest	 478
	"A:37.00,52.00:867:15", --Refugee Caravan Terokkar Forest	 478
	"A:31.00,53.00:867:17", --Shadow Tomb Terokkar Forest	 478
	"A:24.00,59.00:867:19", --Veil Rhaze Terokkar Forest	 478
	"A:38.00,64.00:867:16", --Ring of Observance Terokkar Forest	 478
	"A:33.00,69.00:867:13", --Auchenai Grounds Terokkar Forest	 478
	"A:43.00,76.00:867:18", --Derelict Caravan Terokkar Forest	 478
	"A:50.00,66.00:867:20", --Writhing Mound Terokkar Forest	 478
	"A:55.00,54.00:867:2", --Allerian Stronghold Terokkar Forest	 478
	"A:49.00,46.00:867:6", --Stonebreaker Hold Terokkar Forest	 478
	"A:51.00,29.00:867:7", --Tuurem Terokkar Forest	 478
	"A:60.00,40.00:867:9", --Raastok Glade Terokkar Forest	 478
	"A:70.00,37.00:867:4", --Firewing Point Terokkar Forest	 478
	"A:66.00,53.00:867:12", --Bonechewer Ruins Terokkar Forest	 478
	"A:67.00,73.00:867:21") --Skettis Terokkar Forest	 478
	
tappend(points["HowlingFjord:0"],
	"A:27.00,24.00:1263:4", --Apothecary Camp Howling Fjord	 491
	"A:30.00,26.00:1263:6", --Steel Gate Howling Fjord	 491
	"A:45.00,35.00:1263:16", --Skorn Howling Fjord	 491
	"A:30.00,43.00:1263:19", --Westguard Keep Howling Fjord	 491
	"A:39.00,50.00:1263:10", --Ember Clutch Howling Fjord	 491
	"A:25.00,57.00:1263:1", --Kamagua Howling Fjord	 491
	"A:35.00,80.00:1263:7", --Scalawag Point Howling Fjord	 491
	"A:52.00,67.00:1263:15", --New Agamand Howling Fjord	 491
	"A:50.00,53.00:1263:14", --Halgrind Howling Fjord	 491
	"A:58.00,46.00:1263:18", --Utgarde Keep Howling Fjord	 491
	"A:57.00,36.00:1263:2", --Cauldros Isle Howling Fjord	 491
	"A:66.00,39.00:1263:21", --Baleheim Howling Fjord	 491
	"A:68.00,54.00:1263:8", --Nifflevar Howling Fjord	 491
	"A:72.00,71.00:1263:20", --Baelgun's Excavation Site Howling Fjord	 491
	"A:77.00,48.00:1263:13", --Ivald's Ruin Howling Fjord	 491
	"A:78.00,30.00:1263:5", --Vengeance Landing Howling Fjord	 491
	"A:68.00,27.00:1263:11", --Giants' Run Howling Fjord	 491
	"A:60.00,15.00:1263:12", --Fort Wildervar Howling Fjord	 491
	"A:53.00,27.00:1263:17", --The Twisted Glade Howling Fjord	 491
	"A:48.00,10.00:1263:3", --Camp Winterhoof Howling Fjord	 491
	"A:36.00,10.00:1263:9") --Gjalerbron Howling Fjord	 491

tappend(points["TwilightHighlands:0"],
	"A:74.00,52.00:4866:5", --Dragonmaw Port Twilight Highlands	 700
	"A:76.00,62.00:4866:23", --Twilight Shore Twilight Highlands	 700
	"A:80.00,75.00:4866:11", --Highbank Twilight Highlands	 700
	"A:64.00,77.00:4866:15", --Obsidian Forest Twilight Highlands	 700
	"A:45.00,76.00:4866:3", --Crushblow Twilight Highlands	 700
	"A:49.00,68.00:4866:6", --Dunwald Ruins Twilight Highlands	 700
	"A:54.00,65.00:4866:12", --Highland Forest Twilight Highlands	 700
	"A:51.00,57.00:4866:2", --Crucible of Carnage Twilight Highlands	 700
	"A:41.00,59.00:4866:25", --Victor's Point Twilight Highlands	 700
	"A:40.00,46.00:4866:21", --The Twilight Breach Twilight Highlands	 700
	"A:20.00,55.00:4866:10", --Grim Batol Twilight Highlands	 700
	"A:29.00,44.00:4866:26", --Wyrms' Bend Twilight Highlands	 700
	"A:26.00,38.00:4866:4", --Dragonmaw Pass Twilight Highlands	 700
	"A:25.00,24.00:4866:24", --Vermillion Redoubt Twilight Highlands	 700
	"A:36.00,38.00:4866:19", --The Gullet Twilight Highlands	 700
	"A:38.00,33.00:4866:8", --Glopgut's Hollow Twilight Highlands	 700
	"A:42.00,23.00:4866:13", --Humboldt Conflagration Twilight Highlands	 700
	"A:43.00,17.00:4866:16", --Ruins of Drakgor Twilight Highlands	 700
	"A:47.00,13.00:4866:27", --The Maw of Madness Twilight Highlands	 700
	"A:55.00,14.00:4866:14", --Kirthaven Twilight Highlands	 700
	"A:76.00,16.00:4866:20", --The Krazzworks Twilight Highlands	 700
	"A:70.00,36.00:4866:17", --Slithering Cove Twilight Highlands	 700
	"A:57.00,31.00:4866:18", --The Black Breach Twilight Highlands	 700
	"A:48.00,30.00:4866:22", --Thundermar Twilight Highlands	 700
	"A:54.00,42.00:4866:1", --Bloodgulch Twilight Highlands	 700
	"A:62.00,48.00:4866:9", --Gorshak War Camp Twilight Highlands	 700
	"A:59.00,57.00:4866:7") --Firebeard's Patrol Twilight Highlands	 700

tappend(points["Winterspring:0"],
	"A:61.00,37.00:857:6", --Everlook Winterspring	 281
	"A:51.00,52.00:857:3", --Lake Kel'Theril Winterspring	 281
	"A:55.00,64.00:857:5", --Mazthoril Winterspring	 281
	"A:57.00,82.00:857:12", --Frostwhisper Gorge Winterspring	 281
	"A:64.00,75.00:857:7", --Owl Wing Thicket Winterspring	 281
	"A:68.00,58.00:857:4", --Ice Thistle Hills Winterspring	 281
	"A:66.00,48.00:857:9", --Winterfall Village Winterspring	 281
	"A:62.00,25.00:857:10", --The Hidden Grove Winterspring	 281
	"A:47.00,17.00:857:11", --Frostsaber Rock Winterspring	 281
	"A:49.00,40.00:857:4", --Starfall Village Winterspring	 281
	"A:36.00,56.00:857:2", --Timbermaw Post Winterspring	 281
	"A:32.00,50.00:857:1") --Frostfire Hot Springs Winterspring	 281

tappend(points["Aszhara:0"],
	"A:26.80,77.60:852:11", --Orgrimmar Rear Gate Azshara	 181
	"A:35.00,75.00:852:15", --Lake Mennar Azshara	 181
	"A:32.00,51.00:852:12", --Ruins of Eldarath Azshara	 181
	"A:40.00,49.00:852:2", --The Shattered Strand Azshara	 181
	"A:43.00,75.00:852:8", --The Secret Lab Azshara	 181
	"A:45.00,81.00:852:16", --The Ruined Reaches Azshara	 181
	"A:55.00,78.00:852:17", --Storm Cliffs Azshara	 181
	"A:63.00,79.00:852:14", --Ravencrest Monument Azshara	 181
	"A:63.00,69.00:852:13", --Southridge Beach Azshara	 181
	"A:59.00,50.00:852:3", --Bilgewater Harbor Azshara	 181
	"A:71.00,35.00:852:6", --Ruins of Arkkoran Azshara	 181
	"A:80.00,32.00:852:5", --Tower of Eldara Azshara	 181
	"A:65.00,25.00:852:4", --Bitter Reaches Azshara	 181
	"A:49.00,27.00:852:7", --Darnassian Base Camp Azshara	 181
	"A:33.00,33.00:852:10", --Blackmaw Hold Azshara	 181
	"A:25.00,38.00:852:9", --Bear's Head Azshara	 181
	"A:21.00,55.00:852:1") --Gallywix Pleasure Palace Azshara	 181

tappend(points["EasternPlaguelands:0"],
	"A:51.00,20.00:771:18", --Northpass Tower Eastern Plaguelands	 23
	"A:48.00,14.00:771:19", --Quel'Lithien Lodge Eastern Plaguelands	 23
	"A:28.00,25.00:771:21", --Plaguewood Eastern Plaguelands	 23
	"A:27.00,10.00:771:22", --Stratholme Eastern Plaguelands	 23
	"A:13.00,28.00:771:20", --Terrordale Eastern Plaguelands	 23
	"A:46.00,43.00:771:15", --Blackwood Lake Eastern Plaguelands	 23
	"A:59.00,18.00:771:17", --Zul'Mashar Eastern Plaguelands	 23
	"A:64.00,27.00:771:16", --Northdale Eastern Plaguelands	 23
	"A:62.00,42.00:771:14", --Eastwall Tower Eastern Plaguelands	 23
	"A:74.00,38.00:771:13", --The Noxious Glade Eastern Plaguelands	 23
	"A:71.00,51.00:771:7", --Pestilent Scar Eastern Plaguelands	 23
	"A:75.00,52.00:771:11", --Light's Hope Chapel Eastern Plaguelands	 23
	"A:76.00,75.00:771:10", --Tyr's Hand Eastern Plaguelands	 23
	"A:85.00,74.00:771:23", --Ruins of the Scarlet Enclave Eastern Plaguelands	 23
	"A:58.00,73.00:771:9", --Lake Mereldar Eastern Plaguelands	 23
	"A:54.00,62.00:771:8", --Corin's Crossing Eastern Plaguelands	 23
	"A:48.00,62.00:771:12", --The Infectis Scar Eastern Plaguelands	 23
	"A:34.00,84.00:771:6", --Darrowshire Eastern Plaguelands	 23
	"A:35.00,68.00:771:4", --Crown Guard Tower Eastern Plaguelands	 23
	"A:33.00,51.00:771:5", --The Fungal Vale Eastern Plaguelands	 23
	"A:23.00,68.00:771:2", --The Marris Stead Eastern Plaguelands	 23
	"A:24.00,78.00:771:3", --The Undercroft Eastern Plaguelands	 23
	"A:8.00,66.00:771:1") --Thondroril River Eastern Plaguelands	 23

tappend(points["CrystalsongForest:0"],
	"A:47.00,44.00:1457:4", --Forlorn Woods Crystalsong Forest	 510
	"A:60.00,61.00:1457:8", --The Unbound Thicket Crystalsong Forest	 510
	"A:76.00,48.00:1457:3", --Sunreaver's Command Crystalsong Forest	 510
	"A:74.00,80.00:1457:5", --Windrunner's Overlook Crystalsong Forest	 510
	"A:23.00,57.00:1457:1", --The Azure Front Crystalsong Forest	 510
	"A:15.00,42.00:1457:7", --Violet Stand Crystalsong Forest	 510
	"A:14.00,34.00:1457:6", --The Great Tree Crystalsong Forest	 510
	"A:18.00,15.00:1457:2") --The Decrepit Flow Crystalsong Forest	 510

tappend(points["UngoroCrater:0"],
	"A:54.00,61.00:854:4", --Marshal's Stand Un'Goro Crater	 201
	"A:50.00,79.00:854:2", --The Slithering Scar Un'Goro Crater	 201
	"A:68.00,64.00:854:9", --The Marshlands Un'Goro Crater	 201
	"A:69.00,34.00:854:11", --The Roiling Gardens Un'Goro Crater	 201
	"A:76.00,33.00:854:5", --Ironstone Plateau Un'Goro Crater	 201
	"A:63.00,17.00:854:8", --Fungal Rock Un'Goro Crater	 201
	"A:50.00,21.00:854:7", --Lakkari Tar Pits Un'Goro Crater	 201
	"A:51.00,47.00:854:6", --Fire Plume Ridge Un'Goro Crater	 201
	"A:43.00,41.00:854:10", --Mossy Pile Un'Goro Crater	 201
	"A:32.00,67.00:854:4", --Terror Run Un'Goro Crater	 201
	"A:29.00,53.00:854:3", --Golakka Hot Springs Un'Goro Crater	 201
	"A:30.00,36.00:854:12") --The Screaming Reaches Un'Goro Crater	 201

tappend(points["Hellfire:0"],
	"A:86.00,50.00:862:1", --The Stair of Destiny Hellfire Peninsula	 465
	"A:72.00,52.00:862:10", --The Legion Front Hellfire Peninsula	 465
	"A:77.00,70.00:862:16", --Void Ridge Hellfire Peninsula	 465
	"A:67.00,72.00:862:13", --Zeth'Gor Hellfire Peninsula	 465
	"A:55.00,63.00:862:5", --Honor Hold Hellfire Peninsula	 465
	"A:54.00,81.00:862:2", --Expedition Armory Hellfire Peninsula	 465
	"A:45.00,83.00:862:17", --The Warp Fields Hellfire Peninsula	 465
	"A:26.00,72.00:862:14", --Den of Haal'esh Hellfire Peninsula	 465
	"A:27.00,61.00:862:3", --Falcon Watch Hellfire Peninsula	 465
	"A:15.00,60.00:862:8", --Ruins of Sha'naar Hellfire Peninsula	 465
	"A:14.00,45.00:862:15", --Fallen Sky Ridge Hellfire Peninsula	 465
	"A:23.00,40.00:862:9", --Temple of Telhamat Hellfire Peninsula	 465
	"A:32.00,28.00:862:6", --Mag'har Post Hellfire Peninsula	 465
	"A:39.00,40.00:862:7", --Pools of Aggonar Hellfire Peninsula	 465
	"A:48.00,52.00:862:4", --Hellfire Citadel Hellfire Peninsula	 465
	"A:54.00,39.00:862:11", --Thrallmar Hellfire Peninsula	 465
	"A:65.00,31.00:862:18", --Forge Camp: Mageddon Hellfire Peninsula	 465
	"A:61.00,18.00:862:12") --Throne of Kil'jaeden Hellfire Peninsula	 465

tappend(points["Arathi:0"],
	"A:74.00,38.00:761:16", --Hammerfall Arathi Highlands	 16
	"A:62.00,30.00:761:15", --Circle of East Binding Arathi Highlands	 16
	"A:50.00,40.00:761:14", --Dabyrie's Farmstead Arathi Highlands	 16
	"A:55.00,58.00:761:13", --Go'Shek Farm Arathi Highlands	 16
	"A:65.00,68.00:761:12", --Witherbark Village Arathi Highlands	 16
	"A:48.00,77.00:761:9", --Boulderfist Hall Arathi Highlands	 16
	"A:46.00,52.00:761:11", --Circle of Outer Binding Arathi Highlands	 16
	"A:40.00,47.00:761:10", --Refuge Pointe Arathi Highlands	 16
	"A:26.00,42.00:761:3", --Boulder'gor Arathi Highlands	 16
	"A:26.00,30.00:761:2", --Northfold Manor Arathi Highlands	 16
	"A:19.00,31.00:761:1", --Circle of West Binding Arathi Highlands	 16
	"A:12.00,35.00:761:4", --Galen's Fall Arathi Highlands	 16
	"A:19.00,58.00:761:5", --Stromgarde Keep Arathi Highlands	 16
	"A:29.00,59.00:761:7", --Circle of Inner Binding Arathi Highlands	 16
	"A:24.00,83.00:761:6", --Faldir's Cove Arathi Highlands	 16
	"A:39.00,92.00:761:8") --Thandol Span Arathi Highlands	 16

tappend(points["SearingGorge:0"],
	"A:33.00,80.00:774:8", --Blackrock Mountain Searing Gorge	 28
	"A:21.00,78.00:774:3", --Blackchar Cave Searing Gorge	 28
	"A:48.00,71.00:774:4", --The Sea of Cinders Searing Gorge	 28
	"A:62.00,63.00:774:5", --Grimesilt Dig Site Searing Gorge	 28
	"A:72.00,27.00:774:6", --Dustfire Valley Searing Gorge	 28
	"A:57.00,39.00:774:2", --The Cauldron Searing Gorge	 28
	"A:36.00,27.00:774:7", --Thorium Point Searing Gorge	 28
	"A:26.00,34.00:774:1") --Firewatch Ridge Searing Gorge	 28
    
tappend(points["SouthernBarrens:0"],
	"A:67.00,45.00:4996:7", --Northwatch Hold Southern Barrens	 607
	"A:37.00,12.00:4996:5", --Honor's Stand Southern Barrens	 607
	"A:45.00,60.00:4996:9", --Ruins of Taurajo Southern Barrens	 607
	"A:41.00,46.00:4996:11", --Vendetta Point Southern Barrens	 607
	"A:39.00,20.00:4996:6", --Hunter's Hill Southern Barrens	 607
	"A:48.00,37.00:4996:10", --The Overgrowth Southern Barrens	 607
	"A:49.00,49.00:4996:2", --Forward Command Southern Barrens	 607
	"A:45.00,68.00:4996:2", --Battlescar Southern Barrens	 607
	"A:40.00,78.00:4996:4", --Frazzlecraz Motherlode Southern Barrens	 607
	"A:41.00,94.00:4996:8", --Razorfen Kraul Southern Barrens	 607
	"A:49.00,86.00:4996:1") --Bael Modan Southern Barrens	 607

tappend(points["TheStormPeaks:0"],
	"A:70.00,49.00:1269:11", --Thunderfall The Storm Peaks	 495
	"A:66.00,50.00:1269:9", --Temple of Life The Storm Peaks	 495
	"A:64.00,47.00:1269:6", --Terrace of the Makers The Storm Peaks	 495
	"A:64.00,59.00:1269:3", --Dun Niffelem The Storm Peaks	 495
	"A:48.00,69.00:1269:1", --Brunnhildar Village The Storm Peaks	 495
	"A:43.00,82.00:1269:14", --Garm's Bane The Storm Peaks	 495
	"A:35.00,86.00:1269:7", --Sparksocket Minefield The Storm Peaks	 495
	"A:29.00,75.00:1269:15", --Frosthold The Storm Peaks	 495
	"A:31.00,69.00:1269:4", --Bor's Breath The Storm Peaks	 495
	"A:26.00,62.00:1269:5", --Valkyrion The Storm Peaks	 495
	"A:25.00,51.00:1269:16", --Nidavelir The Storm Peaks	 495
	"A:27.00,43.00:1269:13", --Snowdrift Plains The Storm Peaks	 495
	"A:29.00,44.00:1269:2", --Narvir's Cradle The Storm Peaks	 495
	"A:34.00,56.00:1269:12", --Temple of Storms The Storm Peaks	 495
	"A:41.00,56.00:1269:8", --Engine of the Makers The Storm Peaks	 495
	"A:40.00,24.00:1269:10") --Ulduar The Storm Peaks	 495

tappend(points["VashjirRuins:0"],
	"A:55.00,28.00:4825:20", --Shimmering Grotto Vashj'ir	 615
	"A:50.00,41.00:4825:21", --Silver Tide Hollow Vashj'ir	 615
	"A:65.00,43.00:4825:18", --Ruins of Thelserai Temple Vashj'ir	 615
	"A:59.00,48.00:4825:17", --Nespirah Vashj'ir	 615
	"A:46.00,79.50:4825:16", --Beth'mora Ridge Vashj'ir	 615
	"A:33.00,69.00:4825:19", --Ruins of Vashj'ir Vashj'ir	 615
	"A:43.00,47.00:4825:9") --Glimmerdeep Gorge Vashj'ir	 615
	
tappend(points["HillsbradFoothills:0"],
	"A:29.00,63.00:772:21", --Southpoint Gate Hillsbrad Foothills	 24
	"A:33.00,71.00:772:1", --Azurelode Mine Hillsbrad Foothills	 24
	"A:26.00,85.00:772:16", --Purgation Isle Hillsbrad Foothills	 24
	"A:47.00,71.00:772:18", --Ruins of Southshore Hillsbrad Foothills	 24
	"A:39.00,60.00:772:25", --The Sludge Fields Hillsbrad Foothills	 24
	"A:46.00,54.00:772:8", --Darrow Hill Hillsbrad Foothills	 24
	"A:49.00,47.00:772:3", --Corrahn's Dagger Hillsbrad Foothills	 24
	"A:43.00,39.00:772:13", --Growless Cave Hillsbrad Foothills	 24
	"A:44.00,50.00:772:24", --The Headland Hillsbrad Foothills	 24
	"A:40.00,48.00:772:12", --Gavin's Naze Hillsbrad Foothills	 24
	"A:33.00,47.00:772:2", --Brazie Farmstead Hillsbrad Foothills	 24
	"A:30.00,36.00:772:6", --Dalaran Crater Hillsbrad Foothills	 24
	"A:35.00,25.00:772:14", --Misty Shore Hillsbrad Foothills	 24
	"A:44.00,10.00:772:7", --Dandred's Fold Hillsbrad Foothills	 24
	"A:50.00,12.00:772:26", --The Uplands Hillsbrad Foothills	 24
	"A:57.00,25.00:772:22", --Strahnbrad Hillsbrad Foothills	 24
	"A:50.00,24.00:772:4", --Crushridge Hold Hillsbrad Foothills	 24
	"A:47.00,18.00:772:19", --Slaughter Hollow Hillsbrad Foothills	 24
	"A:45.00,26.00:772:17", --Ruins of Alterac Hillsbrad Foothills	 24
	"A:51.00,31.00:772:11", --Gallows' Corner Hillsbrad Foothills	 24
	"A:55.00,38.00:772:20", --Sofera's Naze Hillsbrad Foothills	 24
	"A:67.00,37.00:772:5", --Chillwind Point Hillsbrad Foothills	 24
	"A:56.00,46.00:772:23", --Tarren Mill Hillsbrad Foothills	 24
	"A:58.00,74.00:772:15", --Nethander Stead Hillsbrad Foothills	 24
	"A:62.00,84.00:772:9", --Dun Garok Hillsbrad Foothills	 24
	"A:76.00,41.00:772:10") --Durnholde Keep Hillsbrad Foothills	 24

tappend(points["VashjirKelpForest:0"],
	"A:40.00,32.00:4825:14", --Legion's Fate Vashj'ir	 610
	"A:46.00,26.00:4825:13", --Seafarer's Tomb Vashj'ir	 610
	"A:58.00,45.00:4825:15", --The Skeletal Reef Vashj'ir	 610
	"A:52.00,56.00:4825:11", --Gurboggle's Ledge Vashj'ir	 610
	"A:60.00,60.00:4825:10", --Gnaws' Boneyard Vashj'ir	 610
	"A:58.00,78.00:4825:12") --The Clutch Vashj'ir	 610

tappend(points["ThousandNeedles:0"],
	"A:12.00,34.00:846:5", --Highperch Thousand Needles	 61
	"A:32.00,35.00:846:5", --Darkcloud Pinnacle Thousand Needles	 61
	"A:88.00,57.00:846:2", --Splithoof Heights Thousand Needles	 61
	"A:45.00,50.00:846:4", --Freewind Post Thousand Needles	 61
	"A:75.00,60.00:846:3", --The Shimmering Deep Thousand Needles	 61
	"A:69.00,85.00:846:9", --Sunken Dig Site Thousand Needles	 61
	"A:53.00,61.00:846:12", --The Twilight Withering Thousand Needles	 61
	"A:12.00,08.00:846:8", --Westreach Summit Thousand Needles	 61
	"A:41.00,29.00:846:10", --Razorfen Downs Thousand Needles	 61
	"A:92.00,81.00:846:6", --Southsea Holdfast Thousand Needles	 61
	"A:30.00,57.00:846:9", --Twilight Bulwark Thousand Needles	 61
	"A:32.00,22.00:846:1") --The Great Lift 	 61
	
tappend(points["Ghostlands:0"],
	"A:26.00,16.00:858:3", --Goldenmist Village Ghostlands	 463
	"A:48.00,11.00:858:15", --Elrendar Crossing Ghostlands	 463
	"A:61.00,12.00:858:2", --Suncrown Village Ghostlands	 463
	"A:79.00,21.00:858:7", --Dawnstar Spire Ghostlands	 463
	"A:72.00,32.00:858:8", --Farstrider Enclave Ghostlands	 463
	"A:65.00,60.00:858:11", --Zeb'Nowa Ghostlands	 463
	"A:71.00,63.00:858:12", --Amani Pass Ghostlands	 463
	"A:55.00,48.00:858:6", --Sanctum of the Sun Ghostlands	 463
	"A:46.00,32.00:858:1", --Tranquillien Ghostlands	 463
	"A:33.00,35.00:858:6", --Sanctum of the Moon Ghostlands	 463
	"A:18.00,43.00:858:4", --Windrunner Village Ghostlands	 463
	"A:13.00,57.00:858:13", --Windrunner Spire Ghostlands	 463
	"A:34.00,47.00:858:14", --Bleeding Ziggurat Ghostlands	 463
	"A:40.00,49.00:858:9", --Howling Ziggurat Ghostlands	 463
	"A:35.00,72.00:858:10", --Deatholme Ghostlands	 463
	"A:47.00,79.00:858:16") --Thalassian Pass Ghostlands	 463

tappend(points["Silithus:0"],
	"A:81.00,18.00:856:8", --Valor's Rest Silithus	 261
	"A:64.00,47.00:856:2", --Southwind Village Silithus	 261
	"A:60.00,70.00:856:5", --Hive'Regal Silithus	 261
	"A:35.00,80.00:856:6", --The Scarab Wall Silithus	 261
	"A:31.00,53.00:856:4", --Hive'Zora Silithus	 261
	"A:30.00,16.00:856:1", --The Crystal Vale Silithus	 261
	"A:49.00,23.00:856:7", --Hive'Ashi Silithus	 261
	"A:53.00,34.00:856:3") --Cenarion Hold Silithus	 261
	
tappend(points["Nagrand:0"],
	"A:33.00,15.00:866:19", --Zangar Ridge Nagrand	 477
	"A:27.00,21.00:866:11", --Warmaul Hill Nagrand	 477
	"A:46.00,19.00:866:5", --Laughing Skull Ruins Nagrand	 477
	"A:60.00,23.00:866:10", --Throne of the Elements Nagrand	 477
	"A:56.00,36.00:866:2", --Garadar Nagrand	 477
	"A:49.00,55.00:866:15", --Southwind Cleft Nagrand	 477
	"A:42.00,44.00:866:3", --Halaa Nagrand	 477
	"A:31.00,43.00:866:7", --Sunspring Post Nagrand	 477
	"A:24.00,35.00:866:14", --Forge Camp: Hate Nagrand	 477
	"A:8.00,43.00:866:16", --The Twilight Ridge Nagrand	 477
	"A:19.00,51.00:866:1", --Forge Camp: Fear Nagrand	 477
	"A:36.00,71.00:866:6", --Spirit Fields Nagrand	 477
	"A:53.00,70.00:866:8", --Telaar Nagrand	 477
	"A:62.00,63.00:866:13", --Clan Watch Nagrand	 477
	"A:70.00,81.00:866:4", --Kil'sorrow Fortress Nagrand	 477
	"A:74.00,66.00:866:12", --Burning Blade Ruins Nagrand	 477
	"A:65.00,56.00:866:9", --The Ring of Trials Nagrand	 477
	"A:72.00,52.00:866:18", --Windyreed Village Nagrand	 477
	"A:72.00,36.00:866:17") --Windyreed Pass Nagrand	 477

tappend(points["BurningSteppes:0"],
	"A:66.00,71.00:775:7", --Blackrock Pass Burning Steppes	 29
	"A:72.00,65.00:775:2", --Morgan's Vigil Burning Steppes	 29
	"A:75.00,53.00:775:3", --Terror Wing Path Burning Steppes	 29
	"A:68.00,41.00:775:1", --Dreadmaul Rock Burning Steppes	 29
	"A:53.00,38.00:775:5", --Ruins of Thaurissan Burning Steppes	 29
	"A:32.00,35.00:775:7", --Blackrock Stronghold Burning Steppes	 29
	"A:41.00,53.00:775:6", --Black Tooth Hovel Burning Steppes	 29
	"A:23.00,65.00:775:8", --The Whelping Downs Burning Steppes	 29
	"A:08.00,32.00:775:9", --Altar of Storms Burning Steppes	 29
	"A:21.00,46.00:775:10") --Blackrock Mountain Burning Steppes	 29

tappend(points["WesternPlaguelands:0"],
	"A:69.00,50.00:770:14", --Thondroril River Western Plaguelands	 22
	"A:65.00,40.00:770:13", --The Weeping Cave Western Plaguelands	 22
	"A:62.00,58.00:770:12", --Gahrron's Withering Western Plaguelands	 22
	"A:62.00,64.00:770:1", --Darrowmere Lake Western Plaguelands	 22
	"A:68.00,78.00:770:2", --Caer Darrow Western Plaguelands	 22
	"A:51.00,78.00:770:3", --Sorrow Hill Western Plaguelands	 22
	"A:43.00,69.00:770:4", --Andorhal Western Plaguelands	 22
	"A:52.00,66.00:770:8", --The Writhing Haunt Western Plaguelands	 22
	"A:46.00,53.00:770:7", --Dalson's Farm Western Plaguelands	 22
	"A:47.10,41.60:770:11", --Redpine Dell Western Plaguelands	 22
	"A:48.00,32.00:770:9", --Northridge Lumber Camp Western Plaguelands	 22
	"A:44.00,16.00:770:10", --Hearthglen Western Plaguelands	 22
	"A:36.00,56.00:770:6", --Felstone Field Western Plaguelands	 22
	"A:27.00,57.00:770:5") --The Bulwark Western Plaguelands	 22

tappend(points["ShadowmoonValley:0"],
	"A:23.00,38.00:864:3", --Legion Hold Shadowmoon Valley	 473
	"A:29.00,28.00:864:5", --Shadowmoon Village Shadowmoon Valley	 473
	"A:40.00,39.00:864:7", --The Deathforge Shadowmoon Valley	 473
	"A:50.00,42.00:864:8", --The Hand of Gul'dan The Fel Pits} works as well.	 473
	"A:45.00,28.00:864:1", --Coilskar Point Shadowmoon Valley	 473
	"A:61.00,29.00:864:11", --Altar of Sha'tar Shadowmoon Valley	 473
	"A:67.00,38.00:864:6", --Ata'mal Terrace Shadowmoon Valley	 473
	"A:60.00,48.00:864:9", --Warden's Cage Shadowmoon Valley	 473
	"A:64.00,57.00:864:13", --Netherwing Fields Shadowmoon Valley	 473
	"A:70.00,85.00:864:4", --Netherwing Ledge Shadowmoon Valley	 473
	"A:46.00,68.00:864:2", --Eclipse Point Shadowmoon Valley	 473
	"A:35.00,58.00:864:10", --Wildhammer Stronghold Shadowmoon Valley	 473
	"A:29.00,55.00:864:12") --Illidari Point Shadowmoon Valley	 473

tappend(points["LakeWintergrasp:0"])
tappend(points["Hyjal:0"],
	"A:37.00,44.00:4863:1", --Rim of the World Mount Hyjal	 606
	"A:78.00,58.00:4863:4", --Darkwhisper Gorge Mount Hyjal	 606
	"A:60.00,24.00:4863:6", --Nordrassil Mount Hyjal	 606
	"A:29.00,29.00:4863:8", --Shrine of Goldrinn Mount Hyjal	 606
	"A:61.00,59.00:4863:10", --The Scorched Plain Mount Hyjal	 606
	"A:43.00,27.00:4863:2", --The Circle of Cinders Mount Hyjal	 606
	"A:17.00,50.00:4863:3", --Ashen Lake Mount Hyjal	 606
	"A:71.00,73.00:4863:5", --Gates of Sothann Mount Hyjal	 606
	"A:31.00,76.00:4863:8", --Sethria's Roost Mount Hyjal	 606
	"A:32.00,51.00:4863:9", --The Flamewake Mount Hyjal	 606
	"A:51.00,76.00:4863:11") --The Throne of Flame Mount Hyjal	 606

tappend(points["IcecrownGlacier:0"],
	"A:54.00,85.00:1270:2", --Icecrown Citadel Icecrown	 492
	"A:48.00,68.00:1270:12", --Corp'rethar: The Horror Gate Icecrown	 492
	"A:57.00,63.00:1270:10", --Ymirheim Icecrown	 492
	"A:67.00,65.00:1270:4", --The Broken Front Icecrown	 492
	"A:78.00,65.00:1270:14", --Scourgeholme Icecrown	 492
	"A:83.00,72.00:1270:9", --Valley of Echoes Icecrown	 492
	"A:69.00,38.00:1270:7", --Sindragosa's Fall Icecrown	 492
	"A:58.00,39.00:1270:1", --The Bombardment Icecrown	 492
	"A:54.00,38.00:1270:6", --Aldur'thar: The Desolation Gate Icecrown	 492
	"A:43.00,23.00:1270:15", --The Shadow Vault Icecrown	 492
	"A:35.00,26.00:1270:13", --Jotunheim Icecrown	 492
	"A:31.00,29.00:1270:8", --Valhalas Icecrown	 492
	"A:43.00,60.00:1270:11", --The Conflagration Icecrown	 492
	"A:34.00,68.00:1270:5", --The Fleshwerks Icecrown	 492
	"A:12.00,46.00:1270:3") --Onslaught Harbor Icecrown	 492

tappend(points["Uldum:0"],
	"A:55.00,33.00:4865:12", --Ramkahen Uldum	 720 
	"A:60.00,39.00:4865:16", --Tahret Grounds Uldum	 720 
	"A:54.00,42.00:4865:22", --Vir'naal Dam Uldum	 720 
	"A:54.00,49.00:4865:1", --Akhenet Fields Uldum	 720 
	"A:48.00,38.00:4865:5", --Mar'at Uldum	 720 
	"A:45.00,16.00:4865:13", --Ruins of Ahmtul Uldum	 720 
	"A:40.00,22.00:4865:8", --Obelisk of the Moon Uldum	 720 
	"A:33.00,31.00:4865:17", --Temple of Uldum Uldum	 720 
	"A:39.00,41.00:4865:11", --Orsis Uldum	 720 
	"A:22.00,63.00:4865:15", --Schnottz's Landing Uldum	 720 
	"A:31.00,64.00:4865:14", --Ruins of Ammon Uldum	 720 
	"A:45.00,56.00:4865:10", --Obelisk of the Sun Uldum	 720 
	"A:45.00,71.00:4865:2", --Cradle of the Ancients Uldum	 720 
	"A:50.00,80.00:4865:7", --Neferset City Uldum	 720 
	"A:65.00,76.00:4865:4", --Lost City of the Tol'vir Uldum	 720 
	"A:76.00,60.00:4865:21", --The Trail of Devastation Uldum	 720 
	"A:84.00,56.00:4865:18", --The Cursed Landing Uldum	 720 
	"A:76.00,52.00:4865:20", --Tombs of the Precursors Uldum	 720 
	"A:67.00,41.00:4865:6", --Nahom Uldum	 720 
	"A:64.00,30.00:4865:9", --Obelisk of the Stars Uldum	 720 
	"A:68.00,22.00:4865:19", --The Gate of Unending Cycles Uldum	 720 
	"A:64.00,21.00:4865:3") --Khartut's Tomb Uldum	 720 

tappend(points["ShattrathCity:0"])
tappend(points["Deepholm:0"],
	"A:50.00,55.00:4864:6", --Temple of Earth Deepholm	 640
	"A:41.00,66.00:4864:11", --Masters' Gate Deepholm	 640
	"A:35.00,81.00:4864:9", --The Quaking Fields Deepholm	 640
	"A:56.00,75.00:4864:5", --Storm's Fury Wreckage Deepholm	 640
	"A:69.00,76.00:4864:10", --Twilight Overlook Deepholm	 640
	"A:72.00,45.00:4864:12", --Crimson Expanse Deepholm	 640
	"A:60.00,60.00:4864:1", --Deathwing's Fall Deepholm	 640
	"A:56.00,13.00:4864:8", --Therazane's Throne Deepholm	 640
	"A:41.00,20.00:4864:7", --The Pale Roost Deepholm	 640
	"A:28.00,31.00:4864:2", --Needlerock Chasm Deepholm	 640
	"A:22.00,47.00:4864:3", --Needlerock Slag Deepholm	 640
	"A:27.00,69.00:4864:4") --Stonehearth Deepholm	 640

tappend(points["EversongWoods:0"],
	"A:55.00,54.00:859:8", --Stillwhisper Pond Eversong Woods	 462
	"A:61.00,54.00:859:23", --Thuron's Livery Eversong Woods	 462
	"A:68.00,52.00:859:9", --Duskwither Grounds Eversong Woods	 462
	"A:71.00,48.00:859:14", --Azurebreeze Coast Eversong Woods	 462
	"A:60.00,62.00:859:7", --Farstrider Retreat Eversong Woods	 462
	"A:64.00,73.00:859:16", --Elrendar Falls Eversong Woods	 462
	"A:65.00,81.00:859:18", --Lake Elrendar Eversong Woods	 462
	"A:70.00,75.00:859:12", --Tor'Watha Eversong Woods	 462
	"A:62.00,79.00:859:25", --Zeb'Watha Eversong Woods	 462
	"A:58.00,72.00:859:11", --The Living Wood Eversong Woods	 462
	"A:53.00,70.00:859:6", --East Sanctum Eversong Woods	 462
	"A:43.00,71.00:859:10", --Fairbreeze Village Eversong Woods	 462
	"A:38.00,73.00:859:21", --Saltheril's Haven Eversong Woods	 462
	"A:44.00,53.00:859:5", --North Sanctum Eversong Woods	 462
	"A:44.00,36.00:859:2", --Ruins of Silvermoon Eversong Woods	 462
	"A:36.00,27.00:859:1", --Sunstrider Isle Eversong Woods	 462
	"A:35.00,59.00:859:3", --West Sanctum Eversong Woods	 462
	"A:27.00,60.00:859:24", --Tranquil Shore Eversong Woods	 462
	"A:32.00,69.00:859:4", --Sunsail Anchorage Eversong Woods	 462
	"A:33.00,76.00:859:17", --Goldenbough Pass Eversong Woods	 462
	"A:27.00,83.00:859:22", --Golden Strand Eversong Woods	 462
	"A:36.00,85.00:859:13", --The Scorched Grove Eversong Woods	 462
	"A:44.00,85.00:859:19", --Runestone Falithas Eversong Woods	 462
	"A:55.00,84.00:859:20") --Runestone Shan'dor Eversong Woods	 462
    
tappend(points["Felwood:0"],
	"A:62.00,9.00:853:1", --Felpaw Village Felwood	 182
	"A:62.00,23.00:853:2", --Talonbranch Glade Felwood	 182
	"A:48.00,23.00:853:3", --Irontree Woods Felwood	 182
	"A:42.00,16.00:853:4", --Jadefire Run Felwood	 182
	"A:42.00,40.00:853:5", --Shatter Scar Vale Felwood	 182
	"A:41.00,48.00:853:6", --Bloodvenom Falls Felwood	 182
	"A:35.00,60.00:853:7", --Jaedenar Felwood	 182
	"A:37.00,68.00:853:8", --Ruins of Constellas Felwood	 182
	"A:39.00,82.00:853:9", --Jadefire Glen Felwood	 182
	"A:51.00,80.00:853:10", --Emerald Sanctuary Felwood	 182
	"A:49.00,86.00:853:11", --Deadwood Village Felwood	 182
	"A:56.00,87.00:853:12") --Morlos'Aran Felwood	 182
	
tappend(points["Badlands:0"],
	"A:17.00,42.00:765:10", --New Kargath Badlands	 17
	"A:17.00,63.00:765:4", --Camp Cagg Badlands	 17
	"A:34.00,51.00:765:5", --Scar of the Worldbreaker Badlands	 17
	"A:31.00,43.00:765:6", --The Dustbowl Badlands	 17
	"A:46.00,57.00:765:2", --Agmond's End Badlands	 17
	"A:52.00,50.00:765:9", --Bloodwatcher Point Badlands	 17
	"A:70.00,44.00:765:1", --Lethlor Ravine Badlands	 17
	"A:60.00,21.00:765:8", --Camp Kosh Badlands	 17
	"A:40.00,26.00:765:7", --Angor Fortress Badlands	 17
	"A:41.00,11.00:765:3") --Uldaman Badlands	 17

tappend(points["TheJadeForest:0"],
	"A:25.60,37.60:6351:9",	--"Exploration Pandaria"
	"A:47.10,45.90:6351:2",	--"Exploration Pandaria"
	"A:54.20,91.30:6351:3",	--"Exploration Pandaria"
	"A:52.00,27.50:6351:4",	--"Exploration Pandaria"
	"A:44.30,92.10:6351:15",	--"Exploration Pandaria"
	"A:46.30,29.40:6351:7",	--"Exploration Pandaria"
	"A:27.70,48.40:6351:6",	--"Exploration Pandaria"
	"A:28.70,14.20:6351:17",	--"Exploration Pandaria"
	"A:43.80,74.40:6351:8",	--"Exploration Pandaria"
	"A:57.50,83.90:6351:5",	--"Exploration Pandaria"
	"A:46.00,63.40:6351:11",	--"Exploration Pandaria"
	"A:53.10,82.60:6351:12",	--"Exploration Pandaria"
	"A:55.50,62.30:6351:13",	--"Exploration Pandaria"
	"A:42.60,16.10:6351:10",	--"Exploration Pandaria"
	"A:57.20,45.60:6351:14",	--"Exploration Pandaria"
	"A:44.60,24.40:6351:1",	--"Exploration Pandaria"
	"A:63.80,27.10:6351:16"	--"Exploration Pandaria"
)
tappend(points["KunLaiSummit:0"],
	"A:72.60,93.30:6976:1",	--"Exploration Pandaria"
	"A:42.70,87.10:6976:2",	--"Exploration Pandaria"
	"A:55.60,91.40:6976:3",	--"Exploration Pandaria"
	"A:74.90,12.50:6976:4",	--"Exploration Pandaria"
	"A:38.60,78.00:6976:5",	--"Exploration Pandaria"
	"A:58.70,71.50:6976:6",	--"Exploration Pandaria"
	"A:44.70,52.30:6976:7",	--"Exploration Pandaria"
	"A:67.80,72.10:6976:8",	--"Exploration Pandaria"
	"A:48.70,43.20:6976:9",	--"Exploration Pandaria"
	"A:34.90,49.10:6976:10",	--"Exploration Pandaria"
	"A:66.20,50.70:6976:11",	--"Exploration Pandaria"
	"A:47.40,67.20:6976:12",	--"Exploration Pandaria"
	"A:60.10,43.70:6976:13",	--"Exploration Pandaria"
	"A:62.50,29.90:6976:14"	--"Exploration Pandaria"
)
tappend(points["TownlongWastes:0"],
	"A:68.40,44.80:6977:5",	--"Exploration Pandaria"
	"A:74.70,80.50:6977:1",	--"Exploration Pandaria"
	"A:82.10,73.00:6977:6",	--"Exploration Pandaria"
	"A:56.00,52.00:6977:2",	--"Exploration Pandaria"
	"A:41.90,59.10:6977:4",	--"Exploration Pandaria"
	"A:53.70,78.50:6977:3",	--"Exploration Pandaria"
	"A:49.40,71.40:6977:7",	--"Exploration Pandaria"
	"A:26.60,18.10:6977:8",	--"Exploration Pandaria"
	"A:43.40,85.40:6977:9",	--"Exploration Pandaria"
	"A:22.50,46.90:6977:10",	--"Exploration Pandaria"
	"A:66.30,69.20:6977:11"	--"Exploration Pandaria"
)
tappend(points["ValeofEternalBlossoms:0"],
	"A:33.10,72.50:6979:2",	--"Exploration Pandaria"
	"A:71.10,46.00:6979:3",	--"Exploration Pandaria"
	"A:24.70,41.10:6979:1",	--"Exploration Pandaria"
	"A:17.90,67.90:6979:4",	--"Exploration Pandaria"
	"A:83.10,57.80:6979:6",	--"Exploration Pandaria"
	"A:61.30,22.70:6979:9",	--"Exploration Pandaria"
	"A:16.90,48.30:6979:11",	--"Exploration Pandaria"
	"A:56.40,43.70:6979:7",	--"Exploration Pandaria"
	"A:43.90,20.10:6979:5",	--"Exploration Pandaria"
	"A:51.90,68.40:6979:8",	--"Exploration Pandaria"
	"A:40.40,48.00:6979:10"	--"Exploration Pandaria"
)
tappend(points["ValleyoftheFourWinds:0"],
	"A:14.80,78.40:6969:2",	--"Exploration Pandaria"
	"A:55.90,34.30:6969:3",	--"Exploration Pandaria"
	"A:53.30,50.30:6969:5",	--"Exploration Pandaria"
	"A:30.70,29.10:6969:7",	--"Exploration Pandaria"
	"A:68.40,43.60:6969:8",	--"Exploration Pandaria"
	"A:16.30,82.40:6969:9",	--"Exploration Pandaria"
	"A:17.20,38.90:6969:10",	--"Exploration Pandaria"
	"A:61.10,27.10:6969:11",	--"Exploration Pandaria"
	"A:72.40,61.50:6969:12",	--"Exploration Pandaria"
	"A:64.70,56.40:6969:13",	--"Exploration Pandaria"
	"A:24.90,42.50:6969:14",	--"Exploration Pandaria"
	"A:20.00,58.40:6969:6",	--"Exploration Pandaria"
	"A:36.00,68.70:6969:15",	--"Exploration Pandaria"
	"A:40.00,40.00:6969:16",	--"Exploration Pandaria"
	"A:52.00,63.30:6969:4",	--"Exploration Pandaria"
	"A:75.80,25.50:6969:17",	--"Exploration Pandaria"
	"A:76.70,59.50:6969:1",	--"Exploration Pandaria"
	"A:86.60,40.00:6969:18"	--"Exploration Pandaria"
)
tappend(points["Krasarang:0"],
	"A:68.00,43.80:6975:1",	--"Exploration Pandaria"
	"A:32.00,72.70:6975:2",	--"Exploration Pandaria"
	"A:40.70,34.10:6975:8",	--"Exploration Pandaria"
	"A:63.00,22.00:6975:3",	--"Exploration Pandaria"
	"A:29.60,40.70:6975:4",	--"Exploration Pandaria"
	"A:82.10,22.70:6975:5",	--"Exploration Pandaria"
	"A:47.40,75.80:6975:7",	--"Exploration Pandaria"
	"A:55.40,30.80:6975:9",	--"Exploration Pandaria"
	"A:23.50,46.60:6975:10",	--"Exploration Pandaria"
	"A:40.40,48.70:6975:11",	--"Exploration Pandaria"
	"A:47.30,39.10:6975:12",	--"Exploration Pandaria"
	"A:20.20,36.90:6975:13",	--"Exploration Pandaria"
	"A:68.40,22.80:6975:6",	--"Exploration Pandaria"
	"A:11.50,62.30:6975:14",	--"Exploration Pandaria"
	"A:46.30,92.80:6975:15",	--"Exploration Pandaria"
	"A:76.70,09.00:6975:16"	--"Exploration Pandaria"
)
tappend(points["TheHiddenPass:0"])
tappend(points["DreadWastes:0"],
	"A:36.60,33.40:6978:1",	--"Exploration Pandaria"
	"A:55.70,34.80:6978:2",	--"Exploration Pandaria"
	"A:61.70,15.10:6978:3",	--"Exploration Pandaria"
	"A:56.10,61.60:6978:4",	--"Exploration Pandaria"
	"A:38.30,17.60:6978:5",	--"Exploration Pandaria"
	"A:56.30,69.50:6978:6",	--"Exploration Pandaria"
	"A:71.80,27.40:6978:7",	--"Exploration Pandaria"
	"A:42.30,56.40:6978:8",	--"Exploration Pandaria"
	"A:44.90,41.10:6978:9",	--"Exploration Pandaria"
	"A:50.00,12.70:6978:10",	--"Exploration Pandaria"
	"A:59.40,41.50:6978:11",	--"Exploration Pandaria"
	"A:30.20,76.10:6978:12"	--"Exploration Pandaria"
)
tappend(points["AzuremystIsle:0"],
	"A:41.00,73.00:860:15", --The Exodar The Exodar	 471
	"A:21.00,54.00:860:16", --Valaar's Berth Azuremyst Isle	 464
	"A:37.00,59.00:860:10", --Pod Cluster Azuremyst Isle	 464
	"A:26.00,66.00:860:4", --Bristlelimb Village Azuremyst Isle	 464
	"A:13.00,80.00:860:13", --Silvermyst Isle Azuremyst Isle	 464
	"A:32.00,77.00:860:17", --Wrathscale Point Azuremyst Isle	 464
	"A:46.00,71.00:860:9", --Odesyus' Landing Azuremyst Isle	 464
	"A:53.00,61.00:860:11", --Pod Wreckage Azuremyst Isle	 464
	"A:59.00,68.00:860:7", --Geezle's Camp Azuremyst Isle	 464
	"A:62.00,54.00:860:2", --Ammen Ford Azuremyst Isle	 464
	"A:77.00,43.00:860:1", --Ammen Vale Azuremyst Isle	 464
	"A:49.00,50.00:860:3", --Azure Watch Azuremyst Isle	 464
	"A:52.00,42.00:860:8", --Moongraze Woods Azuremyst Isle	 464
	"A:45.00,20.00:860:14", --Stillpine Hold Azuremyst Isle	 464
	"A:58.00,17.00:860:5", --Emberglade Azuremyst Isle	 464
	"A:47.00,5.00:860:6", --Fairbridge Strand Azuremyst Isle	 464
	"A:41.00,4.00:860:12") --Silting Shore Azuremyst Isle	 464
	
tappend(points["BloodmystIsle:0"],
	"A:62.00,89.00:861:8", --Kessel's Crossing Bloodmyst Isle	 476
	"A:57.00,81.00:861:22", --The Lost Fold Bloodmyst Isle	 476
	"A:66.00,78.00:861:7", --Bristlelimb Enclave Bloodmyst Isle	 476
	"A:69.00,67.00:861:27", --Wrathscale Lair Bloodmyst Isle	 476
	"A:73.00,70.00:861:18", --The Crimson Reach Bloodmyst Isle	 476
	"A:82.00,52.00:861:5", --Bloodcurse Isle Bloodmyst Isle	 476
	"A:80.00,26.00:861:16", --The Bloodcursed Reef Bloodmyst Isle	 476
	"A:78.00,28.00:861:28", --Wyrmscar Island Bloodmyst Isle	 476
	"A:73.00,20.00:861:14", --Talon Stand Bloodmyst Isle	 476
	"A:74.00,9.00:861:25", --Veridian Point Bloodmyst Isle	 476
	"A:53.00,16.00:861:24", --The Warp Piston Bloodmyst Isle	 476
	"A:55.00,35.00:861:12", --Ragefeather Ridge Bloodmyst Isle	 476
	"A:61.00,44.00:861:13", --Ruins of Loreth'Aran Bloodmyst Isle	 476
	"A:54.00,55.00:861:6", --Blood Watch Bloodmyst Isle	 476
	"A:46.00,45.00:861:4", --Bladewood Bloodmyst Isle	 476
	"A:41.00,32.00:861:2", --Axxarien Bloodmyst Isle	 476
	"A:38.00,20.00:861:17", --The Bloodwash Bloodmyst Isle	 476
	"A:34.00,23.00:861:21", --The Hidden Reef Bloodmyst Isle	 476
	"A:30.00,45.00:861:26", --Vindicator's Rest Bloodmyst Isle	 476
	"A:29.00,36.00:861:20", --The Foul Pool Bloodmyst Isle	 476
	"A:25.00,42.00:861:15", --Tel'athion's Camp Bloodmyst Isle	 476
	"A:22.00,37.00:861:1", --Amberweb Pass Bloodmyst Isle	 476
	"A:19.00,52.00:861:23", --The Vector Coil Bloodmyst Isle	 476
	"A:39.00,61.00:861:19", --Core Bloodmyst Isle	 476
	"A:38.00,79.00:861:11", --Nazzivian Bloodmyst Isle	 476
	"A:31.00,87.00:861:3", --Blacksilt Shore Bloodmyst Isle	 476
	"A:44.00,84.00:861:10", --Mystwood Bloodmyst Isle	 476
	"A:51.00,76.00:861:9") --Middenvale Bloodmyst Isle	 476
	
tappend(points["TheExodar:0"],
	"A:41.00,73.00:860:15")	--"Exploration Kalimdor"
	
tappend(points["Darkshore:0"],
	"A:40.00,87.00:844:11", --The Master's Glaive Darkshore	 42
	"A:32.00,83.00:844:10", --Nazj'vel Darkshore	 42
	"A:40.00,71.00:844:11", --Wildbend River Darkshore	 42
	"A:45.00,58.00:844:8", --Ameth'Aran Darkshore	 42
	"A:43.00,53.00:844:7", --The Eye of the Vortex Darkshore	 42
	"A:36.00,43.00:844:1", --Ruins of Auberdine Darkshore	 42
	"A:40.00,32.00:844:5", --Withering Thicket Darkshore	 42
	"A:50.00,19.00:844:9", --Lor'danel Darkshore	 42
	"A:60.00,20.00:844:1", --Ruins of Mathystra Darkshore	 42
	"A:70.00,19.00:844:2", --Shatterspear Vale Darkshore	 42
	"A:62.00,09.00:844:3") --Shatterspear War Camp Darkshore	 42

tappend(points["Moonglade:0"],
	"A:68.00,60.00:855:4", --Stormrage Barrow Dens Moonglade	 241
	"A:48.00,39.00:855:2", --Nighthaven Moonglade	 241
	"A:36.00,42.00:855:3", --Shrine of Remulos Moonglade	 241
	"A:45.00,58.00:855:1") --Lake Elune'ara Moonglade	 241

tappend(points["Teldrassil:0"],
	"A:39.00,31.00:842:9", --The Oracle Glade Teldrassil	 41
	"A:44.00,35.00:842:10", --Wellspring Lake Teldrassil	 41
	"A:50.00,38.00:842:2",	--The Cleft Teldrassil	 41
	"A:46.00,51.00:842:4", --Ban'ethil Hollow Teldrassil	 41
	"A:41.00,55.00:842:7", --Pools of Arlithrien Teldrassil	 41
	"A:43.00,64.00:842:5", --Gnarlpine Hold Teldrassil	 41
	"A:50.00,63.00:842:6", --Lake Al'Ameth Teldrassil	 41
	"A:56.00,53.00:842:3", --Dolanaar Teldrassil	 41
	"A:64.00,50.00:842:8", --Starbreeze Village Teldrassil	 41
	"A:57.00,38.00:842:1") --Shadowglen Teldrassil	 41

tappend(points["Darnassus:0"],
	"A:54.80,89.90:842:12", --Rut'theran Village Teldrassil	 381
	"A:70.00,40.00:842:11") --Darnassus Darnassus	 381

tappend(points["DeadwindPass:0"],
	"A:42.00,34.00:777:1", --Deadman's Crossing Deadwind Pass	 32
	"A:58.00,64.00:777:2", --The Vice Deadwind Pass	 32
	"A:48.00,75.00:777:3") --Karazhan Deadwind Pass	 32

tappend(points["DunMorogh:0"],
	"A:90.00,37.00:627:12", --North Gate Outpost Dun Morogh	 27
	"A:84.00,51.00:627:10", --Helm's Bed Lake Dun Morogh	 27
	"A:76.00,53.00:627:11", --Gol'Bolar Quarry Dun Morogh	 27
	"A:71.00,48.00:627:9", --Amberstill Ranch Dun Morogh	 27
	"A:78.00,25.00:627:5", --Ironforge Airfield Dun Morogh	 27
	"A:58.00,36.00:627:15", --Gates of Ironforge Dun Morogh	 27
	"A:68.00,56.00:627:8", --The Tundrid Hills Dun Morogh	 27
	"A:59.00,57.00:627:13", --Frostmane Front Dun Morogh	 27
	"A:53.00,51.00:627:7", --Kharanos Dun Morogh	 27
	"A:49.00,40.00:627:6", --Shimmer Ridge Dun Morogh	 27
	"A:42.00,39.00:627:14", --Iceflow Lake Dun Morogh	 27
	"A:33.00,37.00:627:4", --New Tinkertown Dun Morogh	 27
	"A:32.00,49.00:627:13", --Frostmane Hold Dun Morogh	 27
	"A:42.00,63.00:627:1", --Coldridge Pass Dun Morogh	 27
	"A:34.00,71.00:627:2") --Coldridge Valley Dun Morogh	 27
	
tappend(points["Duskwood:0"],
	"A:49.00,73.00:778:7", --The Yorgen Farmstead Duskwood	 34
	"A:63.00,72.00:778:9", --The Rotting Orchard Duskwood	 34
	"A:78.00,69.00:778:10", --Tranquil Gardens Cemetery Duskwood	 34
	"A:74.00,46.00:778:11", --Darkshire Duskwood	 34
	"A:77.00,35.00:778:12", --Manor Mistmantle Duskwood	 34
	"A:64.00,37.00:778:8", --Brightwood Grove Duskwood	 34
	"A:47.00,45.00:778:6", --Twilight Grove Duskwood	 34
	"A:35.00,72.00:778:5", --Vul'Gol Ogre Mound Duskwood	 34
	"A:21.00,68.00:778:2", --Addle's Stead Duskwood	 34
	"A:20.00,55.00:778:3", --Raven Hill Duskwood	 34
	"A:20.00,42.00:778:4", --Raven Hill Cemetery Duskwood	 34
	"A:9.00,49.00:778:1", --The Hushed Bank Duskwood	 34
	"A:37.00,17.00:778:13") --The Darkened Bank Duskwood	 34

tappend(points["Elwynn:0"],
	"A:24.00,74.00:776:2", --Westbrook Garrison Elwynn Forest	 30
	"A:38.00,82.00:776:4", --Fargodeep Mine Elwynn Forest	 30
	"A:42.00,65.00:776:3", --Goldshire Elwynn Forest	 30
	"A:45.00,47.00:776:1", --Northshire Valley Elwynn Forest	 30
	"A:52.00,66.00:776:10", --Crystal Lake Elwynn Forest	 30
	"A:48.00,87.00:776:5", --Jerod's Landing Elwynn Forest	 30
	"A:69.00,79.00:776:7", --Brackwell Pumpkin Patch Elwynn Forest	 30
	"A:64.00,70.00:776:6", --Tower of Azora Elwynn Forest	 30
	"A:73.00,58.00:776:11", --Stone Cairn Lake Elwynn Forest	 30
	"A:81.00,66.00:776:8", --Eastvale Logging Camp Elwynn Forest	 30
	"A:84.00,79.00:776:9") --Ridgepoint Tower Elwynn Forest	 30

tappend(points["LochModan:0"],
	"A:19.00,17.00:779:5", --North Gate Pass Loch Modan	 35
	"A:34.00,18.00:779:4", --Silver Stream Mine Loch Modan	 35
	"A:41.00,11.00:779:2", --Stonewrought Dam Loch Modan	 35
	"A:46.00,18.00:779:1", --The Loch Loch Modan	 35
	"A:70.00,24.00:779:3", --Mo'grosh Stronghold Loch Modan	 35
	"A:80.00,62.00:779:6", --The Farstrider Lodge Loch Modan	 35
	"A:68.00,63.00:779:7", --Ironband's Excavation Site Loch Modan	 35
	"A:40.00,67.00:779:8", --Grizzlepaw Ridge Loch Modan	 35
	"A:34.00,47.00:779:9", --Thelsamar Loch Modan	 35
	"A:31.00,72.00:779:10", --Stonesplinter Valley Loch Modan	 35
	"A:21.00,72.00:779:11") --Valley of Kings Loch Modan	 35

tappend(points["Sunwell:0"],
	"A:54.00,50.00:868")	--"Exploration Eastern Kingdom"			"A:54.00,50.00:868",	--"Exploration Eastern Kingdom"
	--"The Oceanographer"		

tappend(points["Redridge:0"],
	"A:18.00,62.00:780:3", --Three Corners Redridge Mountains	 36
	"A:27.00,69.00:780:4", --Lakeridge Highway Redridge Mountains	 36
	"A:52.00,54.00:780:13", --Camp Everstill Redridge Mountains	 36
	"A:64.00,69.00:780:4", --Render's Valley Redridge Mountains	 36
	"A:78.00,64.00:780:12", --Shalewind Canyon Redridge Mountains	 36
	"A:73.00,55.00:780:7", --Stonewatch Falls Redridge Mountains	 36
	"A:68.00,37.00:780:11", --Galardell Valley Redridge Mountains	 36
	"A:60.00,50.00:780:10", --Stonewatch Keep Redridge Mountains	 36
	"A:48.00,38.00:780:6", --Alther's Mill Redridge Mountains	 36
	"A:35.00,48.00:780:2", --Lake Everstill Redridge Mountains	 36
	"A:28.00,44.00:780:1", --Lakeshire Redridge Mountains	 36
	"A:33.00,26.00:780:5", --Redridge Canyons Redridge Mountains	 36
	"A:35.00,15.00:780:9") --Render's Camp Redridge Mountains	 36
	
tappend(points["Westfall:0"],
	"A:56.00,51.00:802:1", --Sentinel Hill Westfall	 39
	"A:62.00,60.00:802:7", --The Dead Acre Westfall	 39
	"A:64.00,72.00:802:13", --The Dust Plains Westfall	 39
	"A:47.00,78.00:802:11", --The Dagger Hills Westfall	 39
	"A:43.00,69.00:802:8", --Moonbrook Westfall	 39
	"A:34.00,73.00:802:10", --Demont's Place Westfall	 39
	"A:37.00,51.00:802:9", --Alexston Farmstead Westfall	 39
	"A:37.00,45.00:802:12", --The Raging Chasm Westfall	 39
	"A:44.00,35.00:802:6", --The Molsen Farm Westfall	 39
	"A:44.00,25.00:802:5", --Jangolode Mine Westfall	 39
	"A:51.00,22.00:802:3", --Furlbrow's Pumpkin Farm Westfall	 39
	"A:54.00,32.00:802:2", --Saldean's Farm Westfall	 39
	"A:58.00,17.00:802:4") --The Jansen Stead Westfall	 39
	
tappend(points["Wetlands:0"],
	"A:49.00,17.00:841:8", --Dun Modr Wetlands	 40
	"A:44.00,27.00:841:7", --Ironbeard's Tomb Wetlands	 40
	"A:34.00,20.00:841:6", --Saltspray Glen Wetlands	 40
	"A:33.00,31.00:841:5", --Sundown Marsh Wetlands	 40
	"A:19.00,37.00:841:3", --Bluegill Marsh Wetlands	 40
	"A:13.00,55.00:841:1", --Menethil Harbor Wetlands	 40
	"A:21.00,49.00:841:2", --Black Channel Marsh Wetlands	 40
	"A:35.00,47.00:841:4", --Whelgar's Excavation Site Wetlands	 40
	"A:47.00,48.00:841:9", --Angerfang Encampment Wetlands	 40
	"A:57.00,40.00:841:11", --Greenwarden's Grove Wetlands	 40
	"A:60.00,27.00:841:13", --Direforge Hill Wetlands	 40
	"A:68.00,37.00:841:16", --Raptor Ridge Wetlands	 40
	"A:58.00,53.00:841:12", --Mosshide Fen Wetlands	 40
	"A:52.00,52.00:841:10", --Thelgen Rock Wetlands	 40
	"A:57.00,72.00:841:15", --Slabchisel's Survey Wetlands	 40
	"A:54.00,70.00:841:14") --Dun Algaz Wetlands	 40
	
tappend(points["Stratholme:1"])
tappend(points["Scholomance:2"])
tappend(points["TolBarad:0"])
tappend(points["TolBaradDailyArea:0"])
tappend(points["StormwindCity:0"])
tappend(points["AhnQirajTheFallenKingdom:0"])
tappend(points["TheHiddenPass:0"])
tappend(points["MoltenFront:0"])
tappend(points["DarkmoonFaireIsland:0"])
tappend(points["IsleoftheThunderKing:0"])
tappend(points["TimelessIsle:0"])--achievements                                                                           
tappend(points["TimelessIsle:0"])--Gonna Need a Bigger Bag                                                                
tappend(points["TimelessIsle:0"]) --rares/battle pets                                                                      
tappend(points["FrostfireRidge:0"],
	"A:31.9,21.9:8937:6",	--Explore
	"A:21.6,56.1:8937:15",	--Explore
	"A:24.1,56.1:8937:1",	--Explore
	"A:24.1,46.6:8937:5",	--Explore
	"A:33.5,22.9:8937:2",	--Explore
	"A:37.6,13.2:8937:13",	--Explore
	"A:47.7,48.1:8937:14",	--Explore
	"A:53.7,52.2:8937:8",	--Explore
	"A:60.3,59.4:8937:4",	--Explore
	"A:59.4,30.1:8937:11",	--Explore
	"A:66.2,49.2:8937:7",	--Explore
	"A:83.2,59.3:8937:9",	--Explore
	"A:82.9,61.0:8937:3",	--Explore
	"A:75.5,63.1:8937:10",	--Explore
	"A:46.0,54.8:8937:12")	--Explore
tappend(points["Gorgrond:0"],
	"A:38.1,75.1:8939:5",	--Explore
	"A:42.3,73.9:8939:2",	--Explore
	"A:45.8,77.4:8939:1",	--Explore
	"A:51.2,71.2:8939:12",	--Explore
	"A:48.9,69.4:8939:4",	--Explore
	"A:44.0,62.1:8939:8",	--Explore
	"A:43.7,30.9:8939:14",	--Explore
	"A:44.3,19.5:8939:13",	--Explore
	"A:54.8,33.5:8939:3",	--Explore
	"A:57.9,32.0:8939:6",	--Explore
	"A:59.2,53.2:8939:10",	--Explore
	"A:52.8,60.0:8939:9",	--Explore
	"A:41.6,76.2:8939:7",	--Explore
	"A:42.6,65.4:8939:11")	--Explore
tappend(points["NagrandDraenor:0"],
	"A:86.4,66.2:8942:8",	--Explore
	"A:85.2,51.3:8942:4",	--Explore
	"A:83.6,32.1:8942:14:",	--Explore
	"A:85.5,27.2:8942:15",	--Explore
	"A:67.0,48.6:8942:13",	--Explore
	"A:72.6,67.6:8942:3",	--Explore
	"A:69.2,64.3:8942:11",	--Explore
	"A:52.5,67.6:8942:10",	--Explore
	"A:42.3,74.5:8942:6",	--Explore
	"A:40.8,55.6:8942:1",	--Explore
	"A:52.7,47.2:8942:7",	--Explore
	"A:50.3,19.3:8942:2",	--Explore
	"A:55.1,19.6:8942:12",	--Explore
	"A:44.9,33.4:8942:9",	--Explore
	"A:36.2,33.9:8942:5")	--Explore
 
tappend(points["ShadowmoonValleyDR:0"],
	"A:68.5,46.6:8938:7",	--Explore
	"A:27.4,20.5:8938:6",	--Explore
	"A:28.0,29.0:8938:1",	--Explore
	"A:36.3,25.1:8938:5",	--Explore
	"A:43.3,35.5:8938:4",	--Explore
	"A:55.4,33.2:8938:3",	--Explore
	"A:39.7,56.7:8938:8",	--Explore
	"A:48.9,69.4:8938:10",	--Explore
	"A:51.5,68.9:8938:9",	--Explore
	"A:55.6,82.4:8938:2",	--Explore
	"A:42.6,83.6:8938:11")	--Explore
tappend(points["garrisonsmvalliance:0"])
tappend(points["SpiresOfArak:0"],
	"A:43.7,17.8:8941:1",	--Explore
	"A:50.8,32.6:8941:9",	--Explore
	"A:47.1,40.8:8941:17",	--Explore
	"A:45.3,31.6:8941:6",	--Explore
	"A:31.0,38.1:8941:3",	--Explore
	"A:39.3,48.3:8941:12",	--Explore
	"A:41.3,58.2:8941:7",	--Explore
	"A:48.9,61.3:8941:16",	--Explore
	"A:56.9,86.9:8941:4",	--Explore
	"A:61.3,72.3:8941:14",	--Explore
	"A:62.2,58.2:8941:5",	--Explore
	"A:53.7,54.4:8941:15",	--Explore
	"A:62.3,44.6:8941:10",	--Explore
	"A:73.5,42.0:8941:13",	--Explore
	"A:67.1,28.1:8941:2",	--Explore
	"A:31.1,28.7:8941:11",	--Explore
	"A:48.0,52.7:8941:8")	--Explore
tappend(points["Talador:0"],
	"A:68.4,1.9:8940:8",	--Explore
	"A:68.9,20.7:8940:5:",	--Explore
	"A:78.7,27.8:8940:15",	--Explore
	"A:75.6,40.9:8940:1",	--Explore
	"A:65.3,48.4:8940:3",	--Explore
	"A:64.6,40.7:8940:14",	--Explore
	"A:60.4,20.9:8940:9",	--Explore
	"A:49.2,35.0:8940:11",	--Explore
	"A:52.1,60.8:8940:2",	--Explore
	"A:45.2,59.1:8940:4",	--Explore
	"A:36.5,71.2:8940:7",	--Explore
	"A:48.8,86.7:8940:12",	--Explore
	"A:63.8,69.8:8940:6",	--Explore
	"A:30.3,32.7:8940:13",	--Explore
	"A:73.6,62.9:8940:10")	--Explore
tappend(points["TanaanJungle:0"],
	"A:73.4,71.1:10260:1",
	"A:23.3,48.9:10260:14",
	"A:60.6,46.4:10260:13",
	"A:29.0,69.7:10260:12",
	"A:58.5,60.3:10260:10",
	"A:29.0,37.0:10260:9",
	"A:55.1,24.7:10260:8",
	"A:40.0,38.2:10260:7",
	"A:48.4,37.4:10260:4",
	"A:45.6,53.6:10260:6",
	"A:12.9,57.0:10260:5",
	"A:54.7,75.3:10260:3",
	"A:37.0,69.2:10260:11",
	"A:16.4,63.9:10260:2")

tappend(points["Azsuna:0"],
	"A:39.6,50.2:10665:9", --Faronaar
	"A:60.6,34.9:10665:5", -- The Greenway
	"A:41.4,39.0:10665:4", -- Llothien Highlands
	"A:55.7,41.4:10665:3", -- Nar'thalas
	"A:65.6,49.0:10665:7", -- Ruined Sanctum
	"A:52.7,16.8:10665:8", -- Ley-Ruins of Zarkhenar
	"A:65.8,27.9:10665:1", -- Felblaze Ingress
	"A:46.8,73.1:10665:6", -- Isle of the Watchers
	"A:48.0,13.6:10665:10", -- Lost Orchard
	"A:53.8,58.9:10665:11", -- Oceanus Cove
	"A:57.1,64.8:10665:2") -- Temple of Lights

tappend(points["Valsharah:0"],
	"A:42.4,58.6:10666:6", --Bradensbrook
	"A:25.5,66.5:10666:2", -- Gloaming Reef
	"A:54.6,73.0:10666:9", -- Lorlathil
	"A:61.2,73.1:10666:5", -- Moonclaw Vale
	"A:47.3,85.1:10666:10", -- Smolderhide Thicket
	"A:47.9,69.6:10666:3", -- Thas'talah
	"A:38.8,51.8:10666:11", -- Black Rook Hold
	"A:44.2,30.4:10666:12", -- The Dreamgrove
	"A:51.9,64.0:10666:8", -- Grove of Cenarius
	"A:71.6,39.1:10666:4", -- Mistvale
	"A:61.1,31.1:10666:9", -- Shala'nir
	"A:54.1,55.4:10666:13") -- Temple of Elune

tappend(points["Highmountain:0"],
	"A:43.0,33.5:10667:10", --Bloodhunt Highlands
	"A:56.9,90.0:10667:2", -- Highmountain Summit
	"A:27.3,54.6:10667:12", -- Nightwatcher's Perch
	"A:38.9,67.8:10667:9", --Riverbend
	"A:43.7,8.70:10667:1", -- Shipwreck Cove
	"A:58.7,64.7:10667:5", --Stonehoof Watch
	"A:46.2,61.4:10667:8", --Thunder Totem
	"A:29.3,33.4:10667:11", -- Blind Marshlands
	"A:55.6,83.9:10667:6", --Ironhorn Enclave
	"A:43.1,51.7:10667:14", --Pinerock Basin
	"A:56.4,21.8:10667:7", --Rockaway Shallows
	"A:52.6,44.8:10667:4", --Skyhorn
	"A:35.6,63.6:10667:3", --Sylvan Falls
	"A:35.2,45.7:10667:13") --Trueshot Lodge

tappend(points["Stormheim:0"],
	"A:47.2,44.8:10668:9", --Aggrammar's Vault
	"A:55.6,73.6:10668:2", -- Dreadwake's Landing
	"A:72.0,60.0:10668:1", -- Greywatch
	"A:73.4,39.7:10668:4", -- Haustvald
	"A:38.8,20.4:10668:15", -- Maw of Nashal
	"A:44.9,37.0:10668:14", -- Nastrondir
	"A:71.5,50.1:10668:13", -- The Runewood
	"A:60.8,65.5:10668:5", -- Skold-Ashil
	"A:51.4,57.0:10668:17", -- Talonrest
	"A:60.4,51.1:10668:19", -- Valdisdall
	"A:33.9,34.7:10668:6", -- Blackbeak Overlook
	"A:75.2,54.8:10668:3", -- Dreyrgrot
	"A:66.8,64.1:10668:7", -- Gates of Valor
	"A:44.3,64,5:10668:8", -- Hrydshal
	"A:80.1,59.2:10668:10", -- Morheim
	"A:69.9,22.0:10668:11", -- Watchman's Rock
	"A:77.8,6.70:10668:12", -- Shield's Rest
	"A:59.1,31.2:10668:16", -- Storm's Reach
	"A:58.0,44.4:10668:18", -- Tideskorn Harbor
	"A:34.5,51.3:10668:20") -- Weeping Bluffs

tappend(points["Suramar:0"],	
	"A:30.4,42.3:10669:11", -- Ambervale
	"A:19.5,45.2:10669:4", -- Falanaar
	"A:47.3,50.4:10669:5", -- The Grand Pomenade
	"A:38.1,22.9:10669:1", -- Moon Guard Stronghold
	"A:37.0,45.9:10669:3", -- Ruins of Elun'eth
	"A:42.2,35.5:10669:2", -- Tel'anor
	"A:64.0,42.0:10669:8", -- Crimson Thicket
	"A:34.3,74.8:10669:9", -- Felsoul Hold
	"A:71.5,51.1:10669:10", -- Jandvik
	"A:34.9,31.0:10669:6", -- Moonwhisper Gulch
	"A:46.1,59.8:10669:7") -- Suramar City

tappend(points["BrokenShore:0"],		
	"A:44.66,62.92:11543:1", --Deliverance Point
	"A:31.80,60.03:11543:2", --Deadwood Landing
	"A:80.60,51.13:11543:8", --Felfire Pass
	"A:72.74,29.36:11543:7", --Felrage Strand
	"A:47.19,16.67:11543:5", --The Weeping Terrace
	"A:50.85,29.15:11543:4", --Broken Valley
	"A:52.04,37.80:11543:3", --Soul Ruin
	"A:62.46,23.04:11543:6") --Tomb of Sargeras
	
tappend(points["ArgusMacAree:0"], --1170
	"A:57.0,53.6:12069:2", --Conservatory of the Arcane 
	"A:48.8,70.0:12069:7", --Ruins of Oronaar 
	"A:49.7,66.1:12069:8", --Azurelight Square 
	"A:38.1,52.5:12069:9", --Shadowguard Incursion 
	"A:55.0,80.4:12069:12", --Triumvirate's End 
	"A:55.1,43.4:12069:13") --Arinor Gardens 
	
tappend(points["ArgusSurface:0"], --1135
	"A:58.9,59.8:12069:1", --Annihilan Pits 
	"A:61.4,44.9:12069:5", --Nath'raxas Hold 
	"A:61.2,62.4:12069:6", --Petrified Forest 
	"A:42.4,58.7:12069:10") --Shattered Fields 
	
tappend(points["ArgusCore:0"], --1171
	"A:68.1,32.3:12069:3", --Defiled Path 
	"A:64.8,55.2:12069:4", --Felfire Armory 
	"A:70.1,58.7:12069:11") --Terminus 

--Disable automatic addition of key/table combos
--getmetatable(DugisWorldMapTrackingPoints).__index = nil
