--[[
	format:
	{ name,	x,	y,	mapID,	
]]--

local ALName, ALPrivate = ...
local AtlasLoot = _G.AtlasLoot
local MapPOI = {}
AtlasLoot.MapPOI = MapPOI

-- lua

-- WoW

-- local
local MAP_ID = {
	
	-- WoD
	DRAENOR = 1116,
	HORDE_GARRISON_1 = 1152,	-- FWHordeGarrisonLevel1
	HORDE_GARRISON_2 = 1153,	-- FWHordeGarrisonLevel2
	HORDE_GARRISON_3 = 1154,	-- FWHordeGarrisonLevel3
	ALLIANCE_GARRISON_1 = 1158,	-- SMVAllianceGarrisonLevel1
	ALLIANCE_GARRISON_2 = 1159,	-- SMVAllianceGarrisonLevel2
	ALLIANCE_GARRISON_3 = 1160,	-- SMVAllianceGarrisonLevel3
	PROVING_GROUNDS = 1148,
}
local MAP_DATA = {[1] = "Kalimdor",[1019] = "RuinsOfTheramore",[1024] = "PandaFishingVillageScenario",[1028] = "MoguRuinsScenario",[1029] = "AncientMoguCryptScenario",[1030] = "AncientMoguCyptDestroyedScenario",[1031] = "ProvingGroundsScenario",[1032] = "PetBattleJadeForest",[1035] = "ValleyOfPowerScenario",[1043] = "RingOfValorScenario",[1048] = "BrewmasterScenario03",[1049] = "BlackOxTempleScenario",[1050] = "ScenarioKlaxxiIsland",[1051] = "ScenarioBrewmaster04",[529] = "PVPZone04",[530] = "Expansion01",[1061] = "HordeBeachDailyArea",[1062] = "AllianceBeachDailyArea",[532] = "Karazahn",[1064] = "MoguIslandDailyArea",[533] = "Stratholme Raid",[1066] = "StormwindGunshipPandariaStartArea",[534] = "HyjalPast",[1074] = "OrgrimmarGunshipPandariaStart",[1075] = "TheramoreScenarioPhase",[1076] = "JadeForestHordeStartingArea",[540] = "HellfireMilitary",[542] = "HellfireDemon",[543] = "HellfireRampart",[544] = "HellfireRaid",[545] = "CoilfangPumping",[546] = "CoilfangMarsh",[547] = "CoilfangDraenei",[1095] = "HordeAmbushScenario",[1098] = "ThunderIslandRaid",[550] = "TempestKeepRaid",[1101] = "DefenseOfTheAleHouseBG",[1102] = "HordeBaseBeachScenario",[1103] = "AllianceBaseBeachScenario",[1104] = "ALittlePatienceScenario",[1105] = "GoldRushBG",[1106] = "JainaDalaranScenario",[1107] = "WarlockArea",[555] = "AuchindounShadow",[556] = "AuchindounDemon",[1112] = "BlackTempleScenario",[1113] = "DarkmoonCarousel",[558] = "AuchindounDraenei",[1116] = "Draenor",[559] = "PVPZone05",[560] = "HillsbradPast",[1120] = "ThunderKingHordeHub",[1121] = "ThunderIslandAllianceHub",[1122] = "CitySiegeMoguIslandProgressionScenario",[1123] = "LightningForgeMoguIslandProgressionScenario",[1124] = "ShipyardMoguIslandProgressionScenario",[1125] = "AllianceHubMoguIslandProgressionScenario",[1126] = "HordeHubMoguIslandProgressionScenario",[1127] = "FinalGateMoguIslandProgressionScenario",[1128] = "MoguIslandEventsHordeBase",[1129] = "MoguIslandEventsAllianceBase",[1130] = "ShimmerRidgeScenario",[1131] = "DarkHordeScenario",[1132] = "Transport218599",[1133] = "Transport218600",[1134] = "ShadoPanArena",[1135] = "MoguIslandLootRoom",[1136] = "OrgrimmarRaid",[571] = "Northrend",[572] = "PVPLordaeron",[1144] = "HeartOfTheOldGodScenario",[573] = "ExteriorTest",[36] = "DeadminesInstance",[1148] = "ProvingGrounds",[575] = "UtgardePinnacle",[576] = "Nexus70",[1152] = "FWHordeGarrisonLevel1",[1153] = "FWHordeGarrisonLevel2",[1154] = "FWHordeGarrisonLevel3",[1155] = "Stormgarde Keep",[1157] = "HalfhillScenario",[1158] = "SMVAllianceGarrisonLevel1",[1159] = "SMVAllianceGarrisonLevel2",[1160] = "SMVAllianceGarrisonLevel3",[1161] = "CelestialChallenge",[582] = "Transport176244",[1166] = "SmallBattlegroundA",[584] = "Transport176231",[1168] = "ThePurgeOfGrommarScenario",[1169] = "SmallBattlegroundB",[1170] = "SmallBattlegroundC",[1171] = "SmallBattlegroundD",[1172] = "Transport_Siege_of_Orgrimmar_Alliance",[1173] = "Transport_Siege_of_Orgrimmar_Horde",[1175] = "OgreCompound",[1176] = "MoonCultistHideout",[589] = "Transport175080",[1179] = "WarcraftHeroes",[1181] = "PattyMackTestGarrisonBldgMap",[1182] = "DraenorAuchindoun",[592] = "Transport186238",[593] = "Transport20808",[1187] = "GORAllianceGarrisonLevel1",[1188] = "GORAllianceGarrisonLevel2",[1189] = "GORAllianceGarrisonLevel3",[1190] = "BlastedLands",[1191] = "Ashran",[1192] = "Transport_Iron_Horde_Gorgrond_Train",[597] = "CraigTest",[1195] = "WarWharfSmackdown",[599] = "Ulduar70",[600] = "DrakTheronKeep",[1200] = "BonetownScenario",[601] = "Azjol_Uppercity",[1203] = "FrostfireFinaleScenario",[1205] = "BlackrockFoundryRaid",[1207] = "TaladorIronHordeFinaleScenario",[1208] = "BlackrockFoundryTrainDepot",[605] = "development_nonweighted",[606] = "QA_DVD",[1212] = "6HU_GARRISON_Blacksmithing_hub",[1213] = "alliance_garrison_alchemy",[1214] = "alliance_garrison_enchanting",[1215] = "garrison_alliance_engineering",[1216] = "garrison_alliance_farmhouse",[1217] = "garrison_alliance_inscription",[1218] = "garrison_alliance_jewelcrafting",[1219] = "garrison_alliance_leatherworking",[1221] = "garrison_alliance_mine_1",[1222] = "garrison_alliance_mine_2",[1223] = "garrison_alliance_mine_3",[1224] = "garrison_alliance_stable_1",[613] = "Transport_Orgrimmar_Warsong_Hold",[1226] = "garrison_alliance_stable_3",[614] = "Transport_Stormwind_Valiance_Keep",[1228] = "HighmaulOgreRaid",[1229] = "garrison_alliance_inn_1",[1230] = "garrison_alliance_barn",[1231] = "Transport227523",[1232] = "GorHordeGarrisonLevel0",[1233] = "GORHordeGarrisonLevel3",[1234] = "TALAllianceGarrisonLevel0",[1235] = "TALAllianceGarrisonLevel3",[1236] = "TALHordeGarrisonLevel0",[1237] = "TALHordeGarrisonLevel3",[1238] = "SOAAllianceGarrison0",[1239] = "SOAAllianceGarrison3",[1240] = "SOAHordeGarrison0",[1241] = "SOAHordeGarrison3",[1242] = "NAGAllianceGarrisonLevel0",[1243] = "NAGAllianceGarrisonLevel3",[1244] = "NAGHordeGarrisonLevel0",[1245] = "NAGHordeGarrisonLevel3",[1247] = "garrison_alliance_armory1",[1248] = "garrison_alliance_barracks1",[1249] = "garrison_alliance_engineering1",[1250] = "alliance_garrison_herb_garden1",[1251] = "alliance_garrison_inn1",[1252] = "garrison_alliance_lumbermill1",[1253] = "alliance_garrison_magetower1",[1254] = "garrison_alliance_pet_stable1",[1255] = "garrison_alliance_salvageyard1",[1256] = "garrison_alliance_storehouse1",[1257] = "garrison_alliance_trading_post1",[1258] = "garrison_alliance_tailoring1",[1259] = "garrison_alliance_enchanting",[1260] = "garrison_alliance_blacksmith1",[1261] = "garrison_alliance_plot_small",[1262] = "garrison_alliance_plot_medium",[1263] = "garrison_alliance_plot_large",[1265] = "TanaanJungleIntro",[1266] = "CircleofBloodScenario",[1268] = "TerongorsConfrontation",[1270] = "devland3",[1273] = "nagrand_garrison_camp_stable_2",[638] = "Gilneas",[1277] = "DefenseOfKaraborScenario",[1278] = "garrison_horde_barracks1",[1279] = "ShaperDungeon",[1280] = "TrollRaid2",[1281] = "garrison_horde_alchemy1",[1282] = "garrison_horde_armory1",[1283] = "garrison_horde_barn1",[1284] = "garrison_horde_blacksmith1",[1285] = "garrison_horde_enchanting1",[1286] = "garrison_horde_engineering1",[1287] = "garrison_horde_inn1",[1288] = "garrison_horde_inscription1",[1289] = "garrison_horde_jewelcrafting1",[1290] = "garrison_horde_leatherworking1",[1291] = "garrison_horde_lumbermill1",[1292] = "garrison_horde_magetower1",[1293] = "garrison_horde_mine1",[1294] = "garrison_alliance_petstabe",[1295] = "garrison_horde_salvageyard1",[1296] = "garrison_horde_sparringarena1",[1297] = "garrison_horde_stable1",[1298] = "garrison_horde_storehouse1",[1299] = "garrison_horde_tailoring1",[1300] = "garrison_horde_tradingpost1",[1301] = "garrison_horde_workshop1",[1302] = "garrison_alliance_workshop1",[1303] = "garrison_horde_farm1",[1304] = "garrison_horde_plot_large",[1305] = "garrison_horde_plot_medium",[1306] = "garrison_horde_plot_small",[1307] = "TanaanJungleIntroForgePhase",[1308] = "garrison_horde_fishing1",[1309] = "garrison_alliance_fishing1",[1310] = "Expansion5QAModelMap",[1311] = "outdoorGarrisonArenaHorde",[1312] = "outdoorGarrisonArenaAlliance",[1313] = "outdoorGarrisonLumberMillAlliance",[1314] = "outdoorGarrisonLumberMillHorde",[1315] = "outdoorGarrisonArmoryHorde",[1316] = "outdoorGarrisonArmoryAlliance",[1317] = "outdoorGarrisonMageTowerHorde",[1318] = "outdoorGarrisonMageTowerAlliance",[1319] = "outdoorGarrisonStablesHorde",[1320] = "outdoorGarrisonStablesAlliance",[1321] = "outdoorGarrisonWorkshopHorde",[1322] = "outdoorGarrisonWorkshopAlliance",[1323] = "outdoorGarrisonInnHorde",[1324] = "outdoorGarrisonInnAlliance",[1325] = "outdoorGarrisonTradingPostHorde",[1326] = "outdoorGarrisonTradingPostAlliance",[1327] = "outdoorGarrisonConstructionPlotHorde",[1328] = "outdoorGarrisonConstructionPlotAlliance",[1329] = "GrommasharScenario",[1330] = "FWHordeGarrisonLeve2new",[1331] = "SMVAllianceGarrisonLevel2new",[1332] = "garrison_horde_barracks2",[1333] = "garrison_horde_armory2",[1334] = "garrison_horde_barn2",[1335] = "garrison_horde_inn2",[1336] = "garrison_horde_lumbermill2",[1337] = "garrison_horde_magetower2",[1338] = "garrison_horde_petstable2",[42] = "Collin",[1340] = "garrison_horde_tradingpost2",[1341] = "garrison_horde_workshop2",[1342] = "garrison_horde_barracks3",[1343] = "garrison_horde_armory3",[1344] = "garrison_horde_barn3",[1345] = "garrison_horde_inn3",[1346] = "garrison_horde_magetower3",[1347] = "garrison_horde_petstable3",[1348] = "garrison_horde_stable3",[1349] = "garrison_horde_tradingpost3",[1350] = "garrison_horde_workshop3",[1351] = "Garrison_Alliance_Large_Construction",[1352] = "Garrison_Alliance_Medium_Construction",[1353] = "Garrison_Horde_Large_Construction",[1354] = "Garrison_Horde_Medium_Construction",[1358] = "UpperBlackRockSpire",[1361] = "garrisonAllianceMageTower2",[1362] = "garrisonAllianceMageTower3",[1363] = "garrison_horde_mine2",[1364] = "garrison_horde_mine3",[1367] = "garrison_alliance_workshop2",[1368] = "garrison_alliance_workshop3",[1369] = "garrison_alliance_lumbermill2",[1370] = "garrison_alliance_lumbermill3",[1371] = "Garrison_Horde_Small_Construction",[1372] = "Garrison_Alliance_Small_Construction",[1374] = "AuchindounQuest",[1375] = "alliance_garrison_alchemy_rank2",[1376] = "alliance_garrison_alchemy_rank3",[1377] = "garrison_alliance_blacksmith2",[1378] = "garrison_alliance_enchanting2",[1379] = "garrison_alliance_engineering2",[1380] = "garrison_alliance_inscription2",[1381] = "garrison_alliance_inscription3",[1382] = "garrison_alliance_jewelcrafting2",[1383] = "garrison_alliance_jewelcrafting3",[1384] = "garrison_alliance_leatherworking2",[1385] = "garrison_alliance_leatherworking3",[1386] = "garrison_alliance_tailoring2",[1387] = "garrison_alliance_storehouse2",[1388] = "garrison_alliance_storehouse3",[1389] = "garrison_horde_storehouse2",[1390] = "garrison_horde_storehouse3",[1391] = "garrison_alliance_salvageyard2",[1392] = "garrison_alliance_salvageyard3",[1393] = "garrison_horde_lumbermill3",[1394] = "garrison_alliance_pet_stable2",[1395] = "garrison_alliance_pet_stable3",[1396] = "garrison_alliance_trading_post2",[1397] = "garrison_alliance_trading_post3",[1398] = "garrison_alliance_barn2",[1399] = "garrison_alliance_barn3",[1400] = "garrison_alliance_inn_2",[1401] = "garrison_alliance_inn_3",[1402] = "GorgrondFinaleScenario",[1403] = "garrison_alliance_barracks2",[1404] = "garrison_alliance_barracks3",[1405] = "garrison_alliance_armory2",[1406] = "garrison_alliance_armory3",[1407] = "GorgrondFinaleScenarioMap",[1409] = "garrison_horde_sparringarena2",[1410] = "garrison_horde_sparringarena3",[1411] = "garrison_horde_alchemy2",[1412] = "garrison_horde_alchemy3",[1413] = "garrison_horde_blacksmith2",[1414] = "garrison_horde_blacksmith3",[1415] = "garrison_horde_enchanting2",[1416] = "garrison_horde_enchanting3",[1417] = "garrison_horde_inscription2",[1418] = "garrison_horde_inscription3",[1419] = "garrison_horde_leatherworking2",[1420] = "garrison_horde_leatherworking3",[1421] = "garrison_horde_jewelcrafting2",[1422] = "garrison_horde_jewelcrafting3",[712] = "Transport197349",[1424] = "garrison_horde_tailoring3",[1425] = "garrison_horde_salvageyard2",[1426] = "garrison_horde_salvageyard3",[1427] = "PattyMackTestGarrisonBldgMap2",[1429] = "garrison_horde_engineering2",[1430] = "garrison_horde_engineering3",[1431] = "SparringArenaLevel3Stadium",[1432] = "garrison_horde_fishing2",[1433] = "garrison_horde_fishing3",[1434] = "garrison_alliance_fishing2",[718] = "Transport201834",[90] = "GnomeragonInstance",[719] = "MountHyjalPhase1",[1438] = "garrison_alliance_petstable2",[720] = "Firelands1",[1440] = "garrison_alliance_infirmary1",[721] = "Firelands2",[1442] = "garrison_alliance_infirmary3",[723] = "Stormwind",[1446] = "outdoorGarrisonConstructionPlotAllianceLarge",[724] = "ChamberofAspectsRed",[725] = "DeepholmeDungeon",[726] = "CataclysmCTF",[727] = "STV_Mine_BG",[728] = "TheBattleforGilneas",[730] = "MaelstromZone",[731] = "DesolaceBomb",[732] = "TolBarad",[734] = "AhnQirajTerrace",[736] = "TwilightHighlandsDragonmawPhase",[369] = "DeeprunTram",[738] = "Transport200100",[739] = "Transport200101",[740] = "Transport200102",[741] = "Transport200103",[742] = "Transport203729",[743] = "Transport203730",[746] = "UldumPhaseOasis",[747] = "Transport 203732",[748] = "Transport203858",[749] = "Transport203859",[750] = "Transport203860",[751] = "RedgridgeOrcBomb",[752] = "RedridgeBridgePhaseOne",[753] = "RedridgeBridgePhaseTwo",[754] = "SkywallRaid",[755] = "UldumDungeon",[757] = "BaradinHold",[759] = "UldumPhasedEntrance",[760] = "TwilightHighlandsPhasedEntrance",[761] = "Gilneas_BG_2",[762] = "Transport 203861",[763] = "Transport 203862",[764] = "UldumPhaseWreckedCamp",[765] = "Transport203863",[48] = "Blackfathom",[767] = "Transport 2033865",[389] = "OrgrimmarInstance",[25] = "ScottTest",[409] = "MoltenCore",[13] = "test",[209] = "TanarisInstance",[429] = "DireMaul",[859] = "Zul_Gurub5Man",[860] = "NewRaceStartZone",[861] = "FirelandsDailies",[870] = "HawaiiMainLand",[109] = "SunkenTemple",[449] = "AlliancePVPBarracks",[450] = "HordePVPBarracks",[451] = "development",[229] = "BlackRockSpire",[230] = "BlackrockDepths",[930] = "ScenarioAlcazIsland",[469] = "BlackwingLair",[938] = "COTDragonblight",[939] = "COTWarOfTheAncients",[940] = "TheHourOfTwilight",[951] = "NexusLegendary",[1447] = "outdoorGarrisonConstructionPlotHordeLarge",[1441] = "garrison_alliance_infirmary2",[1439] = "garrison_alliance_petstable3",[1437] = "garrison_alliance_petstable1",[1435] = "garrison_alliance_fishing3",[0] = "Azeroth",[612] = "Transport_Menethil_Valgarde",[631] = "IcecrownCitadel",[30] = "PVPZone01",[632] = "IcecrownCitadel5Man",[623] = "Transport192242",[959] = "ShadowpanHideout",[1423] = "garrison_horde_tailoring2",[960] = "EastTemple",[637] = "AbyssalMaw",[961] = "StormstoutBrewery",[766] = "Transport 2033864",[962] = "TheGreatWall",[552] = "TempestKeepArcane",[553] = "TempestKeepAtrium",[70] = "Uldaman",[641] = "Transport_AllianceAirshipBG",[129] = "RazorfenDowns",[642] = "Transport_HordeAirshipBG",[643] = "AbyssalMaw_Interior",[644] = "Uldum",[645] = "BlackRockSpire_4_0",[967] = "DeathwingBack",[588] = "Transport176310",[968] = "EyeoftheStorm2.0",[329] = "Stratholme",[646] = "Deephome",[647] = "Transport_Orgrimmar_to_Thunderbluff",[189] = "MonasteryInstances",[648] = "LostIsles",[971] = "JadeForestAllianceHubPhase",[649] = "ArgentTournamentRaid",[972] = "JadeForestBattlefieldPhase",[650] = "ArgentTournamentDungeon",[651] = "ElevatorSpawnTest",[34] = "StormwindJail",[974] = "DarkmoonFaire",[33] = "Shadowfang",[975] = "TurtleShipPhase01",[574] = "Valgarde70",[976] = "TurtleShipPhase02",[654] = "Gilneas2",[977] = "MaelstromDeathwingFight",[489] = "PVPZone03",[655] = "GilneasPhase1",[656] = "GilneasPhase2",[657] = "SkywallDungeon",[658] = "QuarryofTears",[980] = "TolVirArena",[531] = "AhnQirajTemple",[659] = "LostIslesPhase1",[660] = "Deephomeceiling",[661] = "LostIslesPhase2",[662] = "Transport197195",[269] = "CavernsOfTime",[668] = "HallsOfReflection",[669] = "BlackwingDescent",[670] = "GrimBatolDungeon",[1339] = "garrison_horde_stable2",[671] = "GrimBatolRaid",[672] = "Transport197347",[673] = "Transport197348",[169] = "EmeraldDream",[548] = "CoilfangRaid",[1099] = "NavalBattleScenario",[554] = "TempestKeepFactory",[35] = "StormwindPrison",[43] = "WailingCaverns",[557] = "AuchindounEthereal",[562] = "bladesedgearena",[564] = "BlackTemple",[565] = "GruulsLair",[566] = "NetherstormBG",[568] = "ZulAman",[349] = "Mauradon",[44] = "Monastery",[994] = "MoguDungeon",[289] = "SchoolofNecromancy",[995] = "MoguInteriorRaid",[578] = "Nexus80",[996] = "MoguExteriorRaid",[580] = "SunwellPlateau",[47] = "RazorfenKraulInstance",[585] = "Sunwell5ManFix",[998] = "ValleyOfPower",[713] = "Transport197350",[999] = "BFTAllianceScenario",[586] = "Transport181645",[1000] = "BFTHordeScenario",[587] = "Transport177233",[1001] = "ScarletSanctuaryArmoryAndLibrary",[37] = "PVPZone02",[1227] = "garrison_alliance_tailoring",[590] = "Transport176495",[591] = "Transport164871",[1225] = "garrison_alliance_stable_2",[1004] = "ScarletMonasteryCathedralGY",[594] = "Transport187038",[1005] = "BrewmasterScenario01",[595] = "StratholmeCOT",[596] = "Transport187263",[598] = "Sunwell5Man",[1007] = "NewScholomance",[602] = "Ulduar80",[1008] = "MogushanPalace",[1209] = "ArakkoaDungeon",[1009] = "MantidRaid",[603] = "UlduarRaid",[1010] = "MistsCTF3",[604] = "GunDrak",[1011] = "MantidDungeon",[607] = "NorthrendBG",[608] = "DalaranPrison",[609] = "DeathKnightStart",[610] = "Transport_Tirisfal _Vengeance_Landing",[249] = "OnyxiaLairInstance",[1014] = "MonkAreaScenario",[615] = "ChamberOfAspectsBlack",[616] = "NexusRaid",[617] = "DalaranArena",[618] = "OrgrimmarArena",[619] = "Azjol_LowerCity",[622] = "Transport192241",[509] = "AhnQiraj",[624] = "WintergraspRaid",[627] = "unused",[628] = "IsleofConquest",}


function MapPOI:Create()

end

function MapPOI:GetMinimapData(mapId, mapWidth, mapHeight, centerPointX, centerPointY)
	--[[
		X1Y1-----
		|		 |
		|		 |
		|		 |
		 -----X2Y2
	]]--
	local mapDataId, _, _, X1, X2, Y1, Y2 = GetAreaMapInfo(mapId)
	
	if not mapDataId or not MAP_DATA[mapDataId] or not X1 or X1 == 0 then return end
	
	-- area width/height
	local areaWidth = abs(X2-X1)
	local areaHeight = abs(Y2-Y1)
	
	-- single tile size
	local tileSize = mapWidth / areaWidth * MINIMAP_TILE_YARD_SIZE
	local tileSizeY = mapHeight / areaHeight * MINIMAP_TILE_YARD_SIZE
	
	-- num and pos of tiles in the grid
	local numTileX, posTileX = modf(MINIMAP_GRID_SIZE - X1 / MINIMAP_TILE_YARD_SIZE)					
	local numTileY, posTileY = modf(MINIMAP_GRID_SIZE - Y1 / MINIMAP_TILE_YARD_SIZE)
	
	-- offsets
	local tileOffsetX = (X1 - ((numTileX - MINIMAP_GRID_SIZE) * -MINIMAP_TILE_YARD_SIZE)) / areaWidth
	local tileOffsetY = (Y1 - ((numTileY - MINIMAP_GRID_SIZE) * -MINIMAP_TILE_YARD_SIZE)) / areaHeight
	
	-- number of tiles X and Y
	local numTilesX = ceil((areaWidth + posTileX * MINIMAP_TILE_YARD_SIZE) / MINIMAP_TILE_YARD_SIZE)
	local numTilesY = ceil((areaHeight + posTileY * MINIMAP_TILE_YARD_SIZE) / MINIMAP_TILE_YARD_SIZE)
	
	-- return table
	local data = {
		tileSize = tileSize,
		numTilesX = numTilesX,
		numTilesY = numTilesY,
		numTimes = numTilesX * numTilesY,
		files = {},
	}
	
	-- the data for all files
	local textureWidth, textureHeight, point, texLeft, texRight, texTop, texBottom
	for y=1,numTilesY do
		for x=1,numTilesX do
		
			textureWidth, textureHeight = tileSize, tileSize
			texLeft, texRight, texTop, texBottom = 0, 1, 0, 1
		
			-- ####
			-- tex
			-- ####
			
			-- 1 tile
			if numTilesX == 1 and numTilesY == 1 then
				textureWidth = mapWidth
				textureHeight = mapHeight
				texLeft = posTileX
				texTop = posTileY
				texRight = (mapWidth + posTileX * tileSize) / tileSize
				texBottom = (mapHeight + posTileY * tileSize) / tileSize
			-- 1 tile width
			elseif numTilesX == 1 then
				textureWidth = mapWidth
				texLeft = posTileX
				texRight = (mapWidth + posTileX * tileSize) / tileSize
			-- 1 tile height
			elseif numTilesY == 1 then
				textureHeight = mapHeight
				texTop = posTileY
				texBottom = (mapHeight + posTileY * tileSize) / tileSize
			-- TOPLEFT
			elseif y == 1 and x == 1 then
				textureWidth = tileSize - posTileX*tileSize
				textureHeight = tileSize - posTileY*tileSize
				texLeft = posTileX
				texTop = posTileY
			-- TOPRIGHT
			elseif y == 1 and x == numTilesX then
				textureWidth = mapWidth - (tileOffsetX*mapWidth+tileSize*(x-1))
				textureHeight = tileSize - posTileY*tileSize
				texTop = posTileY
				texRight = textureWidth/tileSize
			-- BOTTOMLEFT
			elseif y == numTilesY and x == 1 then
				textureWidth = tileSize - posTileX*tileSize
				textureHeight = (-tileOffsetY*mapHeight-tileSize*(y-1)) + mapHeight
				texLeft = posTileX
				texBottom = textureHeight/tileSize
			-- BOTTOMRIGHT
			elseif y == numTilesY and x == numTilesX then
				textureWidth = mapWidth - (tileOffsetX*mapWidth+tileSize*(x-1))
				textureHeight = (-tileOffsetY*mapHeight-tileSize*(y-1)) + mapHeight
				texRight = textureWidth/tileSize
				texBottom = textureHeight/tileSize
			-- TOP
			elseif y == 1 then
				textureHeight = tileSize - posTileY*tileSize
				texTop = posTileY
			-- BOTTOM
			elseif y == numTilesY then
				textureHeight = (-tileOffsetY*mapHeight-tileSize*(y-1)) + mapHeight
				texBottom = textureHeight/tileSize
			-- LEFT
			elseif x == 1 then 
				textureWidth = tileSize - posTileX*tileSize
				texLeft = posTileX
			-- RIGHT
			elseif x == numTilesX then
				textureWidth = mapWidth - (tileOffsetX*mapWidth+tileSize*(x-1))
				texRight = textureWidth/tileSize
			end
			
			data.files[#data.files+1] = {
				width = textureWidth,
				height = textureHeight,
				path = format(MapData.MiniMapPath, MAP_DATA[mapDataId], numTileX+(x-1), numTileY+(y-1)),
				tex = {texLeft, texRight, texTop, texBottom},
			}
		end
	end
	
	return data
end

-- ###########################
-- GUI
-- ###########################
function MapPOI:GUI_Get()
	if not self.frame then
	
	end
	return self.frame
end
