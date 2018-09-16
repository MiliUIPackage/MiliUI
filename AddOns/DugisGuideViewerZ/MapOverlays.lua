local MOD = DugisGuideViewer
local _
local MapOverlays = MOD:RegisterModule("MapOverlays")
MapOverlays.essential = true
local harvestingDataMode = false

local HBDMigrate = LibStub("HereBeDragons-Migrate-Dugis")

function MapOverlays:Initialize()
	local defaults = {
		global = {
			overlayData = {
				["AhnQirajTheFallenKingdom"] = {
					["AQKingdom"] = 121271159,
				},
				["Arathi"] = {
					["BoulderfistHall"] = 394406398204,
					["Bouldergor"] = 132249835769,
					["CircleofEastBinding"] = 135822293175,
					["CircleofInnerBinding"] = 335218445540,
					["CircleofWestBinding"] = 25859226844,
					["CirecleofOuterBinding"] = 293479837911,
					["DabyriesFarmstead"] = 155042680018,
					["FaldirsCove"] = 429577744657,
					["GalensFall"] = 154619135188,
					["GoShekFarm"] = 267812856114,
					["Hammerfall"] = 127311035662,
					["NorthfoldManor"] = 112881578211,
					["RefugePoint"] = 156000073924,
					["StromgardeKeep"] = 288858884380,
					["ThandolSpan"] = 446950535405,
					["WitherbarkVillage"] = 385972662532,
				},
				["Ashenvale"] = {
					["Astranaar"] = 176361323771,
					["BoughShadow"] = 159790615718,
					["FallenSkyLake"] = 413945581855,
					["FelfireHill"] = 341125182741,
					["LakeFalathim"] = 159031468216,
					["MaelstrasPost"] = 197502198,
					["NightRun"] = 272280847581,
					["OrendilsRetreat"] = 150203636,
					["RaynewoodRetreat"] = 237801570535,
					["Satyrnaar"] = 166086291691,
					["SilverwindRefuge"] = 360058245467,
					["TheHowlingVale"] = 104649178437,
					["TheRuinsofStardust"] = 355629022444,
					["TheShrineofAssenia"] = 295321234738,
					["TheZoramStrand"] = 399622,
					["ThistlefurVillage"] = 84019496250,
					["ThunderPeak"] = 130318391499,
					["WarsongLumberCamp"] = 285350264039,
				},
				["Aszhara"] = {
					["BearsHead"] = 151516315904,
					["BilgewaterHarbor"] = 136779789899,
					["BitterReaches"] = 500424001,
					["BlackmawHold"] = 57122499844,
					["DarnassianBaseCamp"] = 3581155571,
					["GallywixPleasurePalace"] = 238444321018,
					["LakeMennar"] = 405057806546,
					["OrgimmarRearGate"] = 369390537056,
					["RavencrestMonument"] = 431069867303,
					["RuinsofArkkoran"] = 130525889755,
					["RuinsofEldarath"] = 246126195930,
					["StormCliffs"] = 433144963279,
					["TheSecretLab"] = 425572127928,
					["TheShatteredStrand"] = 180720313550,
					["TowerofEldara"] = 24339891506,
				},
				["AzuremystIsle"] = {
					["AmmenFord"] = 300114247936,
					["AmmenVale"] = 112222274011,
					["AzureWatch"] = 267763581184,
					["BristlelimbVillage"] = 389950996736,
					["Emberglade"] = 26281771264,
					["FairbridgeStrand"] = 373424384,
					["GreezlesCamp"] = 376341528832,
					["MoongrazeWoods"] = 196965826816,
					["OdesyusLanding"] = 406243770624,
					["PodCluster"] = 327786168576,
					["PodWreckage"] = 375220600960,
					["SiltingShore"] = 3526623488,
					["SilvermystIsle"] = 478913198336,
					["StillpineHold"] = 52996342016,
					["TheExodar"] = 91346174464,
					["ValaarsBerth"] = 325528584448,
					["WrathscalePoint"] = 452276247808,
				},
				["Badlands"] = {
					["AgmondsEnd"] = 338470208854,
					["AngorFortress"] = 73255845149,
					["ApocryphansRest"] = 70867322108,
					["CampBoff"] = 236650430738,
					["CampCagg"] = 301721808211,
					["CampKosh"] = 20929843436,
					["DeathwingScar"] = 191309866312,
					["HammertoesDigsite"] = 124985217233,
					["LethlorRavine"] = 59615319509,
					["TheDustbowl"] = 106451727574,
					["Uldaman"] = 352536842,
				},
				["Barrens"] = {
					["BoulderLodeMine"] = 8052229398,
					["DreadmistPeak"] = 111973436657,
					["FarWatchPost"] = 139094995151,
					["GroldomFarm"] = 136835196147,
					["MorshanRampart"] = 6713204997,
					["Ratchet"] = 407521901787,
					["TheCrossroads"] = 295658783977,
					["TheDryHills"] = 61325195547,
					["TheForgottenPools"] = 223443419582,
					["TheMerchantCoast"] = 490209497403,
					["TheSludgeFen"] = 6865282305,
					["TheStagnantOasis"] = 407309157712,
					["TheWailingCaverns"] = 341609616761,
					["ThornHill"] = 273235025135,
				},
				["BladesEdgeMountains"] = {
					["BashirLanding"] = 442761472,
					["BladedGulch"] = 158493573376,
					["BladesipreHold"] = 173202205952,
					["BloodmaulCamp"] = 102437748992,
					["BloodmaulOutpost"] = 398717134080,
					["BrokenWilds"] = 117806727424,
					["CircleofWrath"] = 225946370304,
					["DeathsDoor"] = 267899014400,
					["ForgeCampAnger"] = 158454776224,
					["ForgeCampTerror"] = 446827852288,
					["ForgeCampWrath"] = 189245161728,
					["Grishnath"] = 30364926208,
					["GruulsLayer"] = 87525949696,
					["JaggedRidge"] = 444997040384,
					["MokNathalVillage"] = 319591547136,
					["RavensWood"] = 59280458240,
					["RazorRidge"] = 357041520896,
					["RidgeofMadness"] = 277606721792,
					["RuuanWeald"] = 105729491200,
					["Skald"] = 76941623552,
					["Sylvanaar"] = 376113002752,
					["TheCrystalpine"] = 613679360,
					["ThunderlordStronghold"] = 292482855168,
					["VeilLashh"] = 459845910784,
					["VeilRuuan"] = 162725495040,
					["VekhaarStand"] = 436598997248,
					["VortexPinnacle"] = 221365352704,
				},
				["BlastedLands"] = {
					["AltarofStorms"] = 118347730158,
					["DreadmaulHold"] = 270743824,
					["DreadmaulPost"] = 195764089067,
					["NethergardeKeep"] = 6998406439,
					["NethergardeSupplyCamps"] = 457383107,
					["RISEOFTHEDEFILER"] = 109915056296,
					["SerpentsCoil"] = 104634440922,
					["Shattershore"] = 98316859632,
					["SunveilExcursion"] = 401984465129,
					["Surwich"] = 509302996167,
					["TheDarkPortal"] = 192585967986,
					["TheRedReaches"] = 288322062604,
					["TheTaintedForest"] = 334072485212,
					["TheTaintedScar"] = 188056045876,
				},
				["BloodmystIsle"] = {
					["AmberwebPass"] = 66618654976,
					["Axxarien"] = 146340577536,
					["BlacksiltShore"] = 457599863296,
					["Bladewood"] = 224797131008,
					["BloodWatch"] = 277483880704,
					["BloodscaleIsle"] = 275678232815,
					["BristlelimbEnclave"] = 440806932736,
					["KesselsCrossing"] = 566404199909,
					["Middenvale"] = 436373553408,
					["Mystwood"] = 518941500672,
					["Nazzivian"] = 434054103296,
					["RagefeatherRidge"] = 126132420864,
					["RuinsofLorethAran"] = 232511504640,
					["TalonStand"] = 84441039104,
					["TelathionsCamp"] = 232117108864,
					["TheBloodcursedReef"] = 58746732800,
					["TheBloodwash"] = 29307961600,
					["TheCrimsonReach"] = 93997760768,
					["TheCryoCore"] = 306323915008,
					["TheFoulPool"] = 146260885760,
					["TheHiddenReef"] = 42091151616,
					["TheLostFold"] = 505186294016,
					["TheVectorCoil"] = 255596083712,
					["TheWarpPiston"] = 31611683072,
					["VeridianPoint"] = 668205312,
					["VindicatorsRest"] = 260089053440,
					["WrathscaleLair"] = 363552047360,
					["WyrmscarIsland"] = 88689869056,
				},
				["BoreanTundra"] = {
					["AmberLedge"] = 150664861940,
					["BorGorokOutpost"] = 329461132,
					["Coldarra"] = 52819404,
					["DeathsStand"] = 195088899361,
					["GarroshsLanding"] = 255711373579,
					["Kaskala"] = 230314799489,
					["RiplashStrand"] = 411550615934,
					["SteeljawsCaravan"] = 71283571956,
					["TempleCityOfEnKilah"] = 16853012770,
					["TheDensOfDying"] = 12505531595,
					["TheGeyserFields"] = 503667063,
					["TorpsFarm"] = 254762307770,
					["ValianceKeep"] = 283947350275,
					["WarsongStronghold"] = 254822078724,
				},
				["BurningSteppes"] = {
					["AltarofStorms"] = 368822,
					["BlackrockMountain"] = 83235097,
					["BlackrockPass"] = 277465164074,
					["BlackrockStronghold"] = 246809920,
					["Dracodar"] = 254477253994,
					["DreadmaulRock"] = 162730876178,
					["MorgansVigil"] = 274449462655,
					["PillarofAsh"] = 274069878034,
					["RuinsofThaurissan"] = 441813316,
					["TerrorWingPath"] = 8193922398,
				},
				["CrystalsongForest"] = {
					["ForlornWoods"] = 135950880,
					["SunreaversCommand"] = 43512087998,
					["TheAzureFront"] = 261993439648,
					["TheDecrepitFlow"] = 227616,
					["TheGreatTree"] = 97710772476,
					["TheUnboundThicket"] = 113267668470,
					["VioletStand"] = 188978871560,
					["WindrunnersOverlook"] = 411708978734,
				},
				["Darkshore"] = {
					["AmethAran"] = 354643232070,
					["EyeoftheVortex"] = 256939065674,
					["Lordanel"] = 58392339733,
					["Nazjvel"] = 501654693108,
					["RuinsofAuberdine"] = 195714812107,
					["RuinsofMathystra"] = 30607154376,
					["ShatterspearVale"] = 17805067514,
					["ShatterspearWarcamp"] = 592596213,
					["TheMastersGlaive"] = 518907946287,
					["WildbendRiver"] = 406168208698,
					["WitheringThicket"] = 127021607240,
				},
				["DeadwindPass"] = {
					["DeadmansCrossing"] = 87566953,
					["Karazhan"] = 332956801537,
					["TheVice"] = 223792792926,
				},
				["Deepholm"] = {
					["CrimsonExpanse"] = 13451542990,
					["DeathwingsFall"] = 319477341638,
					["NeedlerockChasm"] = 21339514,
					["NeedlerockSlag"] = 156766598514,
					["ScouredReach"] = 470056452,
					["StoneHearth"] = 337155295603,
					["StormsFuryWreckage"] = 411723658532,
					["TempleOfEarth"] = 190353597795,
					["ThePaleRoost"] = 89408979,
					["TheShatteredField"] = 470447004078,
					["TherazanesThrone"] = 455242002,
					["TwilightOverlook"] = 451569508763,
					["TwilightTerrace"] = 412628490477,
				},
				["Desolace"] = {
					["CenarionWildlands"] = 167939175736,
					["GelkisVillage"] = 507023397138,
					["KodoGraveyard"] = 293509225722,
					["MagramTerritory"] = 183179137313,
					["MannorocCoven"] = 383725657414,
					["NijelsPoint"] = 601097447,
					["RanzjarIsle"] = 220345505,
					["Sargeron"] = 687117629,
					["ShadowbreakRavine"] = 432312428836,
					["ShadowpreyVillage"] = 396359937246,
					["ShokThokar"] = 343141610805,
					["SlitherbladeShore"] = 25988258130,
					["TethrisAran"] = 418530578,
					["ThargadsCamp"] = 404015474900,
					["ThunderAxeFortress"] = 53074932956,
					["ValleyofSpears"] = 210631937345,
				},
				["Dragonblight"] = {
					["AgmarsHammer"] = 218240346348,
					["Angrathar"] = 220449074,
					["ColdwindHeights"] = 422800597,
					["EmeraldDragonshrine"] = 389264140484,
					["GalakrondsRest"] = 127155799298,
					["IcemistVillage"] = 177308255467,
					["LakeIndule"] = 336309039460,
					["LightsRest"] = 8253626667,
					["Naxxramas"] = 172523536695,
					["NewHearthglen"] = 385043666134,
					["ObsidianDragonshrine"] = 111937793328,
					["RubyDragonshrine"] = 223730683068,
					["ScarletPoint"] = 8113195243,
					["TheCrystalVice"] = 510921957,
					["TheForgottenShore"] = 357214484781,
					["VenomSpite"] = 284161167586,
					["WestwindRefugeeCamp"] = 200834067685,
					["WyrmrestTemple"] = 235624826173,
				},
				["DreadWastes"] = {
					["BREWGARDEN"] = 368273658,
					["BRINYMUCK"] = 334158379333,
					["CLUTCHESOFSHEKZEER"] = 134575618257,
					["DREADWATERLAKE"] = 336539635010,
					["HEARTOFFEAR"] = 131197080838,
					["HORRIDMARCH"] = 240980789571,
					["KLAXXIVESS"] = 118592059628,
					["KYPARIVOR"] = 508754245,
					["RIKKITUNVILLAGE"] = 34607392986,
					["SOGGYSGAMBLE"] = 436411286796,
					["TERRACEOFGURTHAN"] = 99406293201,
					["ZANVESS"] = 413560761634,
				},
				["DunMorogh"] = {
					["AmberstillRanch"] = 242216000761,
					["ColdridgePass"] = 365449990369,
					["ColdridgeValley"] = 393094674830,
					["FrostmaneFront"] = 275370032354,
					["FrostmaneHold"] = 243792078261,
					["Gnomeregan"] = 28991355289,
					["GolBolarQuarry"] = 309933108422,
					["HelmsBedLake"] = 288559966426,
					["IceFlowLake"] = 276142316,
					["Ironforge"] = 417688952,
					["IronforgeAirfield"] = 660946228,
					["Kharanos"] = 236694204600,
					["NorthGateOutpost"] = 46973434093,
					["TheGrizzledDen"] = 308556234963,
					["TheShimmeringDeep"] = 142150445227,
					["TheTundridHills"] = 329172378798,
				},
				["Durotar"] = {
					["DrygulchRavine"] = 64859869420,
					["EchoIsles"] = 443905473866,
					["NorthwatchFoothold"] = 472864945314,
					["Orgrimmar"] = 324179203,
					["RazorHill"] = 169029635296,
					["RazormaneGrounds"] = 283784673528,
					["SenjinVillage"] = 436418568384,
					["SkullRock"] = 459437264,
					["SouthfuryWatershed"] = 187127003380,
					["ThunderRidge"] = 51849160924,
					["TiragardeKeep"] = 320459710674,
					["ValleyOfTrials"] = 335326480638,
				},
				["Duskwood"] = {
					["AddlesStead"] = 373696012587,
					["BrightwoodGrove"] = 120780635415,
					["Darkshire"] = 138110363977,
					["ManorMistmantle"] = 131689797851,
					["RacenHill"] = 313633436877,
					["RavenHillCemetary"] = 141829657923,
					["TheDarkenedBank"] = 27991977891,
					["TheHushedBank"] = 163209071805,
					["TheRottingOrchard"] = 395702443299,
					["TheTranquilGardensCemetary"] = 370024894755,
					["TheTwilightGrove"] = 108777574720,
					["TheYorgenFarmstead"] = 425622495465,
					["VulGolOgreMound"] = 381417711884,
				},
				["Dustwallow"] = {
					["AlcazIsland"] = 23236649166,
					["BlackhoofVillage"] = 208854360,
					["BrackenwllVillage"] = 63490483584,
					["DirehornPost"] = 181838066967,
					["Mudsprocket"] = 336195845553,
					["ShadyRestInn"] = 202007353661,
					["TheWyrmbog"] = 396587478452,
					["TheramoreIsle"] = 240013008177,
					["WitchHill"] = 449152270,
				},
				["Dustwallow_terrain1"] = {
					["ALCAZISLAND"] = 23236649166,
					["BLACKHOOFVILLAGE"] = 208854360,
					["BRACKENWLLVILLAGE"] = 63490483584,
					["DIREHORNPOST"] = 181838066967,
					["MUDSPROCKET"] = 336195845553,
					["SHADYRESTINN"] = 202007353661,
					["THERAMOREISLE"] = 240013008177,
					["THEWYRMBOG"] = 396587478452,
					["WITCHHILL"] = 449152270,
				},
				["EasternPlaguelands"] = {
					["Acherus"] = 110333543652,
					["BlackwoodLake"] = 162535808238,
					["CorinsCrossing"] = 310828553402,
					["CrownGuardTower"] = 377154108618,
					["Darrowshire"] = 496290183416,
					["EastwallTower"] = 198135955637,
					["LakeMereldar"] = 458972448010,
					["LightsHopeChapel"] = 291704631492,
					["LightsShieldTower"] = 291394193651,
					["Northdale"] = 66096177417,
					["NorthpassTower"] = 74508861690,
					["Plaguewood"] = 43100927304,
					["QuelLithienLodge"] = 368229653,
					["RuinsOfTheScarletEnclave"] = 317528069384,
					["Stratholme"] = 123914550,
					["Terrordale"] = 10737746178,
					["TheFungalVale"] = 226751635730,
					["TheInfectisScar"] = 283018274993,
					["TheMarrisStead"] = 359843178698,
					["TheNoxiousGlade"] = 59737681193,
					["ThePestilentScar"] = 374064087222,
					["TheUndercroft"] = 490758950168,
					["ThondorilRiver"] = 107374721286,
					["Tyrshand"] = 445211998422,
					["ZulMashar"] = 553828638,
				},
				["Elwynn"] = {
					["BrackwellPumpkinPatch"] = 455824597279,
					["CrystalLake"] = 351551044828,
					["EastvaleLoggingCamp"] = 314270010662,
					["FargodeepMine"] = 451223478541,
					["Goldshire"] = 315939331348,
					["JerodsLanding"] = 462124431590,
					["NorthshireValley"] = 148548919591,
					["RidgepointTower"] = 475336476957,
					["StonecairnLake"] = 200295072084,
					["Stromwind"] = 432640,
					["TowerofAzora"] = 308718847246,
					["WestbrookGarrison"] = 381300303117,
				},
				["EversongWoods"] = {
					["AzurebreezeCoast"] = 245514895616,
					["DuskwitherGrounds"] = 272291332352,
					["EastSanctum"] = 400988307712,
					["ElrendarFalls"] = 429031424128,
					["FairbreezeVilliage"] = 414869356800,
					["FarstriderRetreat"] = 386022899968,
					["GoldenboughPass"] = 503839850752,
					["LakeElrendar"] = 506344969344,
					["NorthSanctum"] = 320353861888,
					["RuinsofSilvermoon"] = 146351063296,
					["RunestoneFalithas"] = 532972482816,
					["RunestoneShandor"] = 530915178752,
					["SatherilsHaven"] = 412656861440,
					["SilvermoonCity"] = 93877436928,
					["StillwhisperPond"] = 337652220160,
					["SunsailAnchorage"] = 434034049280,
					["SunstriderIsle"] = 5573706240,
					["TheGoldenStrand"] = 445795005568,
					["TheLivingWood"] = 451507642496,
					["TheScortchedGrove"] = 544654622976,
					["ThuronsLivery"] = 328056570112,
					["TorWatha"] = 338908513536,
					["TranquilShore"] = 320200769792,
					["WestSanctum"] = 342830088320,
					["Zebwatha"] = 510608475264,
				},
				["Felwood"] = {
					["BloodvenomFalls"] = 248265245017,
					["DeadwoodVillage"] = 542669704365,
					["EmeraldSanctuary"] = 410582733074,
					["FelpawVillage"] = 494044467,
					["IrontreeWoods"] = 59481801989,
					["JadefireGlen"] = 492075960549,
					["JadefireRun"] = 9981598983,
					["Jaedenar"] = 340621705535,
					["MorlosAran"] = 520190345403,
					["RuinsofConstellas"] = 385765038348,
					["ShatterScarVale"] = 115145435479,
					["TalonbranchGlade"] = 61760309457,
				},
				["Feralas"] = {
					["CampMojache"] = 195051090094,
					["DarkmistRuins"] = 308759697580,
					["DireMaul"] = 108956774665,
					["FeathermoonStronghold"] = 254856593625,
					["FeralScar"] = 302200835263,
					["GordunniOutpost"] = 125249418432,
					["GrimtotemCompund"] = 183172819103,
					["LowerWilds"] = 205877626063,
					["RuinsofFeathermoon"] = 246082121936,
					["RuinsofIsildien"] = 380594533582,
					["TheForgottenCoast"] = 368686973122,
					["TheTwinColossals"] = 284506462,
					["WrithingDeep"] = 320658946280,
				},
				["FrostfireRidge"] = {
					["BLADESPIREFORTRESS"] = 125667949924,
					["BLOODMAULSTRONGHOLD"] = 4621296898,
					["BONESOFAGURAK"] = 343288411409,
					["DAGGERMAWRAVINE"] = 98008497407,
					["FROSTWINDDUNES"] = 127097106,
					["GRIMFROSTHILL"] = 226111990962,
					["GROMBOLASH"] = 35940187353,
					["GROMGAR"] = 347348489498,
					["HORDEGARRISON"] = 351466161419,
					["IRONSIEGEWORKS"] = 168209717577,
					["IRONWAYSTATION"] = 327089994951,
					["MAGNAROK"] = 36072347861,
					["NOGARRISON"] = 351466161419,
					["STONEFANGOUTPOST"] = 302042512635,
					["THEBONESLAG"] = 206462732544,
					["THECRACKLINGPLAINS"] = 147563255050,
					["WORGOL"] = 313608348989,
				},
				["Ghostlands"] = {
					["AmaniPass"] = 249735598484,
					["BleedingZiggurat"] = 255743754496,
					["DawnstarSpire"] = 603193771,
					["Deatholme"] = 402753099264,
					["ElrendarCrossing"] = 342098432,
					["FarstriderEnclave"] = 146629984685,
					["GoldenmistVillage"] = 46662144,
					["HowlingZiggurat"] = 235506435328,
					["IsleofTribulations"] = 613679360,
					["SanctumoftheMoon"] = 135511933184,
					["SanctumoftheSun"] = 161531560192,
					["SuncrownVillage"] = 482607616,
					["ThalassiaPass"] = 436321130752,
					["Tranquillien"] = 2530738432,
					["WindrunnerSpire"] = 308206108928,
					["WindrunnerVillage"] = 125691232512,
					["ZebNowa"] = 254965890560,
				},
				["Gilneas"] = {
					["CrowleyOrchard"] = 458761607378,
					["Duskhaven"] = 357841422622,
					["EmberstoneMine"] = 46841298201,
					["GilneasCity"] = 225992514842,
					["Greymanemanor"] = 217043944692,
					["HammondFarmstead"] = 378132476098,
					["HaywardFishery"] = 482417536177,
					["Keelharbor"] = 102318299416,
					["KorothsDen"] = 414876709086,
					["NorthernHeadlands"] = 406120715,
					["NorthgateWoods"] = 15538104602,
					["StormglenVillage"] = 499831221569,
					["TempestsReach"] = 312069154142,
					["TheBlackwald"] = 423582990616,
					["TheHeadlands"] = 168116552,
				},
				["Gorgrond"] = {
					["BASTIONRISE"] = 544684016964,
					["BEASTWATCH"] = 398759986342,
					["EASTERNRUIN"] = 279723574482,
					["EVERMORN"] = 477036205353,
					["FOUNDRY"] = 79934223571,
					["FOUNDRYSOUTH"] = 196970991833,
					["GRONNCANYON"] = 228977788183,
					["HIGHLANDPASS"] = 78957055261,
					["HIGHPASS"] = 268866651345,
					["IRONDOCKS"] = 367186235,
					["MUSHROOMS"] = 347284379901,
					["STONEMAULARENA"] = 359975274713,
					["STONEMAULSOUTH"] = 446965102800,
					["STRIPMINE"] = 83005513978,
					["TANGLEHEART"] = 399905092870,
				},
				["GrizzlyHills"] = {
					["AmberpineLodge"] = 262220843286,
					["BlueSkyLoggingGrounds"] = 138756205817,
					["CampOneqwah"] = 147677521220,
					["ConquestHold"] = 329656867148,
					["DrakTheronKeep"] = 49392416126,
					["DrakilJinRuins"] = 44660191583,
					["DunArgol"] = 276525629895,
					["GraniteSprings"] = 222272127332,
					["GrizzleMaw"] = 201165344038,
					["RageFangShrine"] = 316007623131,
					["ThorModan"] = 533977417,
					["UrsocsDen"] = 34707083592,
					["VentureBay"] = 495014067474,
					["Voldrune"] = 452230110491,
				},
				["Hellfire"] = {
					["DenofHaalesh"] = 442572734720,
					["ExpeditionArmory"] = 443729313280,
					["FalconWatch"] = 350232074752,
					["FallenSkyRidge"] = 152507252992,
					["ForgeCampRage"] = 27345289728,
					["HellfireCitadel"] = 225840670976,
					["HonorHold"] = 320467108096,
					["MagharPost"] = 118327869696,
					["PoolsofAggonar"] = 48660742400,
					["RuinsofShanaar"] = 311411730688,
					["TempleofTelhamat"] = 163249127936,
					["TheLegionFront"] = 138046603520,
					["TheStairofDestiny"] = 168277049600,
					["Thrallmar"] = 165846188288,
					["ThroneofKiljaeden"] = 6942884352,
					["VoidRidge"] = 395876499712,
					["WarpFields"] = 438409892096,
					["ZethGor"] = 462317402534,
				},
				["HillsbradFoothills"] = {
					["AzurelodeMine"] = 428724115636,
					["ChillwindPoint"] = 73596673471,
					["CorrahnsDagger"] = 240965025927,
					["CrushridgeHold"] = 108933542022,
					["DalaranCrater"] = 147209828668,
					["DandredsFold"] = 357680386,
					["DarrowHill"] = 300019777683,
					["DunGarok"] = 440802740493,
					["DurnholdeKeep"] = 233594883509,
					["GallowsCorner"] = 150796913819,
					["GavinsNaze"] = 273091265652,
					["GrowlessCave"] = 205461266603,
					["HillsbradFields"] = 324470488366,
					["LordamereInternmentCamp"] = 232131828986,
					["MistyShore"] = 45433922718,
					["NethanderSteed"] = 401032335564,
					["PurgationIsle"] = 542449478800,
					["RuinsOfAlterac"] = 91632096445,
					["SlaughterHollow"] = 59488985236,
					["SoferasNaze"] = 178748803220,
					["SouthpointTower"] = 332922091832,
					["Southshore"] = 378358951141,
					["Strahnbrad"] = 47774369043,
					["TarrenMill"] = 243183856805,
					["TheHeadland"] = 274213261417,
					["TheUplands"] = 462586068,
				},
				["Hinterlands"] = {
					["AeriePeak"] = 253403344110,
					["Agolwatha"] = 171109986512,
					["JinthaAlor"] = 359140721951,
					["PlaguemistRavine"] = 112882636991,
					["QuelDanilLodge"] = 194578173169,
					["Seradane"] = 5867101487,
					["ShadraAlor"] = 407179038960,
					["Shaolwatha"] = 223931012377,
					["SkulkRock"] = 209893698736,
					["TheAltarofZul"] = 368667988193,
					["TheCreepingRuin"] = 270992088263,
					["TheOverlookCliffs"] = 287399363828,
					["ValorwindLake"] = 289136660679,
					["Zunwatha"] = 305102292194,
				},
				["HowlingFjord"] = {
					["AncientLift"] = 377242188977,
					["ApothecaryCamp"] = 39832528135,
					["BaelgunsExcavationSite"] = 351765054708,
					["Baleheim"] = 183140267182,
					["CampWinterHoof"] = 371410143,
					["CauldrosIsle"] = 173386418357,
					["EmberClutch"] = 218266599637,
					["ExplorersLeagueOutpost"] = 361390891240,
					["FortWildervar"] = 513999099,
					["GiantsRun"] = 600099114,
					["Gjalerbron"] = 236123378,
					["Halgrind"] = 223754853563,
					["IvaldsRuin"] = 240145081537,
					["Kamagua"] = 298604307789,
					["NewAgamand"] = 386982531356,
					["Nifflevar"] = 258322153650,
					["ScalawagPoint"] = 440410573150,
					["Skorn"] = 116324016366,
					["SteelGate"] = 107607138526,
					["TheTwistedGlade"] = 61643901194,
					["UtgardeKeep"] = 232428796152,
					["VengeanceLanding"] = 27540146399,
					["WestguardKeep"] = 193368125787,
				},
				["HrothgarsLanding"] = {
				},
				["Hyjal"] = {
					["ArchimondesVengeance"] = 5704560910,
					["AshenLake"] = 83758582042,
					["DarkwhisperGorge"] = 138154564928,
					["DireforgeHill"] = 211845035278,
					["GatesOfSothann"] = 344249940240,
					["Nordrassil"] = 411373081,
					["SethriasRoost"] = 468297425173,
					["ShrineOfGoldrinn"] = 18375574819,
					["TheRegrowth"] = 271711534521,
					["TheScorchedPlain"] = 232359469421,
					["TheThroneOfFlame"] = 406208154019,
				},
				["IcecrownGlacier"] = {
					["Aldurthar"] = 40101076341,
					["ArgentTournamentGround"] = 32858407226,
					["Corprethar"] = 421265625396,
					["IcecrownCitadel"] = 500774938932,
					["Jotunheim"] = 131020056969,
					["OnslaughtHarbor"] = 179315159244,
					["Scourgeholme"] = 287412829429,
					["SindragosasFall"] = 33942756652,
					["TheBombardment"] = 194911653112,
					["TheBrokenFront"] = 353846402331,
					["TheConflagration"] = 327834355939,
					["TheFleshwerks"] = 312687750363,
					["TheShadowVault"] = 16443129055,
					["Valhalas"] = 53914878190,
					["ValleyofEchoes"] = 419509265677,
					["Ymirheim"] = 296818523359,
				},
				["Kezan"] = {
					["KEZANMAP"] = 4295648234,
				},
				["Krasarang"] = {
					["AnglersOutpost"] = 220688746761,
					["CradleOfChiJi"] = 403911731472,
					["DojaniRiver"] = 3759433918,
					["FallsongRiver"] = 82907112662,
					["LostDynasty"] = 29608926425,
					["NayeliLagoon"] = 400865607926,
					["RedwingRefuge"] = 67978405076,
					["RuinsOfDojan"] = 47710600396,
					["RuinsOfKorja"] = 94620757203,
					["TempleOfTheRedCrane"] = 231169330395,
					["TheDeepwild"] = 63767474364,
					["TheForbiddenJungle"] = 84825911553,
					["TheSouthernIsles"] = 286713505020,
					["UngaIngoo"] = 535069632770,
					["ZhusBastion"] = 641937714,
					["krasarangCove"] = 21136421150,
				},
				["Krasarang_terrain1"] = {
					["ANGLERSOUTPOST"] = 215320042843,
					["CRADLEOFCHIJI"] = 403911731472,
					["DOJANIRIVER"] = 3759433918,
					["FALLSONGRIVER"] = 82907112662,
					["KRASARANGCOVE"] = 21136446759,
					["LOSTDYNASTY"] = 29608926425,
					["NAYELILAGOON"] = 400865607926,
					["REDWINGREFUGE"] = 67978405076,
					["RUINSOFDOJAN"] = 47710600396,
					["RUINSOFKORJA"] = 94620757203,
					["TEMPLEOFTHEREDCRANE"] = 231169330395,
					["THEDEEPWILD"] = 63767474364,
					["THEFORBIDDENJUNGLE"] = 84825911553,
					["THESOUTHERNISLES"] = 286689404179,
					["UNGAINGOO"] = 535069632770,
					["ZHUSBASTION"] = 641937714,
				},
				["KunLaiSummit"] = {
					["BinanVillage"] = 505295345904,
					["FireboughNook"] = 532913762528,
					["GateoftheAugust"] = 543784339717,
					["Iseoflostsouls"] = 4926448899,
					["Kotapeak"] = 386791638268,
					["Mogujia"] = 441792545021,
					["MountNeverset"] = 283707130169,
					["MuskpawRanch"] = 336713750757,
					["PeakOfSerenity"] = 67995194655,
					["ShadoPanMonastery"] = 98876917121,
					["TEMPLEOFTHEWHITETIGER"] = 183151890682,
					["TheBurlapTrail"] = 333277581622,
					["ValleyOfEmperors"] = 205559940320,
					["ZouchinVillage"] = 69246086442,
				},
				["LakeWintergrasp"] = {
				},
				["LochModan"] = {
					["GrizzlepawRidge"] = 348149487889,
					["IronbandsExcavationSite"] = 318332243341,
					["MogroshStronghold"] = 56410498342,
					["NorthgatePass"] = 17073471,
					["SilverStreamMine"] = 231993569,
					["StonesplinterValley"] = 370626828561,
					["StronewroughtDam"] = 355672397,
					["TheFarstriderLodge"] = 225010028893,
					["TheLoch"] = 87330089290,
					["Thelsamar"] = 156766608839,
					["ValleyofKings"] = 333934060854,
				},
				["Moonglade"] = {
					["LakeEluneara"] = 293361483183,
					["Nighthaven"] = 145343369562,
					["ShrineofRemulos"] = 97929961743,
					["StormrageBarrowDens"] = 226054465811,
				},
				["Mulgore"] = {
					["BaeldunDigsite"] = 236460376282,
					["BloodhoofVillage"] = 293466242350,
					["PalemaneRock"] = 344931382444,
					["RavagedCaravan"] = 240974468283,
					["RedCloudMesa"] = 430870634942,
					["RedRocks"] = 46710056122,
					["StonetalonPass"] = 210952429,
					["TheGoldenPlains"] = 108917907642,
					["TheRollingPlains"] = 313011719428,
					["TheVentureCoMine"] = 148732424400,
					["ThunderBluff"] = 66790362485,
					["ThunderhornWaterWell"] = 217245195465,
					["WildmaneWaterWell"] = 347254974,
					["WindfuryRidge"] = 419637470,
					["WinterhoofWaterWell"] = 365543220398,
				},
				["Nagrand"] = {
					["BurningBladeRUins"] = 359322171648,
					["ClanWatch"] = 390326386944,
					["ForgeCampFear"] = 266326151680,
					["ForgeCampHate"] = 165526372608,
					["Garadar"] = 153997279488,
					["Halaa"] = 207583707392,
					["KilsorrowFortress"] = 459073111296,
					["LaughingSkullRuins"] = 56202887424,
					["OshuGun"] = 358806272512,
					["RingofTrials"] = 287248220416,
					["SouthwindCleft"] = 277435646208,
					["SunspringPost"] = 213904523520,
					["Telaar"] = 419165372672,
					["ThroneoftheElements"] = 57437061376,
					["TwilightRidge"] = 114901385472,
					["WarmaulHill"] = 34524627200,
					["WindyreedPass"] = 85452914944,
					["WindyreedVillage"] = 250880459008,
					["ZangarRidge"] = 58272776448,
				},
				["NagrandDraenor"] = {
					["ANCESTRAL"] = 278349937898,
					["BROKENPRECIPICE"] = 13153570097,
					["ELEMENTALS"] = 616843550,
					["GROMMASHAR"] = 394692703488,
					["HALLVALOR"] = 127505125612,
					["HIGHMAUL"] = 447959,
					["IRONFISTHARBOR"] = 380401600748,
					["LOKRATH"] = 201190503740,
					["MARGOKS"] = 408811766009,
					["MUSHROOMS"] = 27626077434,
					["OSHUGUN"] = 347202660614,
					["RINGOFBLOOD"] = 451181831,
					["RINGOFTRIALS"] = 171273678178,
					["SUNSPRINGWATCH"] = 105554114834,
					["TELAAR"] = 379514536232,
				},
				["Netherstorm"] = {
					["Area52"] = 416864665856,
					["ArklonRuins"] = 426619699456,
					["CelestialRidge"] = 186432880896,
					["EcoDomeFarfield"] = 11152916736,
					["EtheriumStagingGrounds"] = 223842926848,
					["ForgeBaseOG"] = 23871095040,
					["KirinVarVillage"] = 562080924928,
					["ManaforgeBanar"] = 301875989760,
					["ManaforgeCoruu"] = 525434277120,
					["ManaforgeDuro"] = 361265103104,
					["ManafrogeAra"] = 166609551616,
					["Netherstone"] = 21906063616,
					["NetherstormBridge"] = 315818770688,
					["RuinedManaforge"] = 148714553600,
					["RuinsofEnkaat"] = 323461841152,
					["RuinsofFarahlon"] = 52984807936,
					["SocretharsSeat"] = 41042575616,
					["SunfuryHold"] = 484733838592,
					["TempestKeep"] = 305564877209,
					["TheHeap"] = 488803357952,
					["TheScrapField"] = 280620171520,
					["TheStormspire"] = 144194142464,
				},
				["Redridge"] = {
					["AlthersMill"] = 149617368292,
					["CampEverstill"] = 307556975805,
					["GalardellValley"] = 602357164,
					["LakeEverstill"] = 229865941456,
					["LakeridgeHighway"] = 339457966472,
					["Lakeshire"] = 118111863194,
					["RedridgeCanyons"] = 39096733,
					["RendersCamp"] = 224647525,
					["RendersValley"] = 405273873835,
					["ShalewindCanyon"] = 304590688562,
					["StonewatchFalls"] = 324820719932,
					["StonewatchKeep"] = 503746788,
					["ThreeCorners"] = 274878323011,
				},
				["RuinsofGilneas"] = {
					["GilneasPuzzle"] = 685034,
				},
				["STVDiamondMineBG"] = {
					["17467"] = 185973492097,
					["17468"] = 103513553258,
					["17469"] = 310904028324,
					["17470"] = 135884178645,
				},
				["SearingGorge"] = {
					["BlackcharCave"] = 387621113207,
					["BlackrockMountain"] = 455521587504,
					["DustfireValley"] = 616926600,
					["FirewatchRidge"] = 80531039597,
					["GrimsiltWorksite"] = 259328846265,
					["TannerCamp"] = 386980434491,
					["TheCauldron"] = 183853490657,
					["ThoriumPoint"] = 41069884845,
				},
				["ShadowmoonValley"] = {
					["AltarofShatar"] = 100403511552,
					["CoilskarPoint"] = 8955363840,
					["EclipsePoint"] = 333219994112,
					["IlladarPoint"] = 275028115712,
					["LegionHold"] = 166539559424,
					["NetherwingCliffs"] = 331293655296,
					["NetherwingLedge"] = 478350114284,
					["ShadowmoonVilliage"] = 37703123456,
					["TheBlackTemple"] = 135927431564,
					["TheDeathForge"] = 138817306880,
					["TheHandofGuldan"] = 97050427904,
					["TheWardensCage"] = 277517593088,
					["WildhammerStronghold"] = 246063488512,
				},
				["ShadowmoonValleyDR"] = {
					["ANGUISHFORTRESS"] = 171945763125,
					["DARKTIDEROOST"] = 501928371482,
					["ELODOR"] = 446966051,
					["EMBAARI"] = 169934582106,
					["GARRISON"] = 203709663,
					["GLOOMSHADE"] = 5703450853,
					["GULVAR"] = 27579652,
					["KARABOR"] = 161624684937,
					["NOGARRISON"] = 203709663,
					["SHAZGUL"] = 338500486426,
					["SHIMMERINGMOOR"] = 329040270624,
					["SOCRETHAR"] = 441709700298,
					["SWISLAND"] = 494245413037,
				},
				["SholazarBasin"] = {
					["KartaksHold"] = 402733176137,
					["RainspeakerCanopy"] = 262440987855,
					["RiversHeart"] = 364375254484,
					["TheAvalanche"] = 99409470786,
					["TheGlimmeringPillar"] = 36830518566,
					["TheLifebloodPillar"] = 144407119160,
					["TheMakersOverlook"] = 254142609641,
					["TheMakersPerch"] = 145135755513,
					["TheMosslightPillar"] = 381456540911,
					["TheSavageThicket"] = 55176303909,
					["TheStormwrightsShelf"] = 62422024460,
					["TheSuntouchedPillar"] = 199802286535,
				},
				["Silithus"] = {
					["CenarionHold"] = 153993089316,
					["HiveAshi"] = 4656999829,
					["HiveRegal"] = 333258791401,
					["HiveZora"] = 221191192094,
					["SouthwindVillage"] = 194924236085,
					["TheCrystalVale"] = 132372809,
					["TheScarabWall"] = 488552748612,
					["TwilightBaseCamp"] = 162240110002,
					["ValorsRest"] = 644117819,
				},
				["Silverpine"] = {
					["Ambermill"] = 268969430299,
					["BerensPeril"] = 435395239230,
					["DeepElemMine"] = 228139931865,
					["FenrisIsle"] = 16715659616,
					["ForsakenHighCommand"] = 466795881,
					["ForsakenRearGuard"] = 387168442,
					["NorthTidesBeachhead"] = 73353338030,
					["NorthTidesRun"] = 154494233,
					["OlsensFarthing"] = 267689041147,
					["ShadowfangKeep"] = 362204533939,
					["TheBattlefront"] = 461001380095,
					["TheDecrepitFields"] = 167997759664,
					["TheForsakenFront"] = 351567803544,
					["TheGreymaneWall"] = 543646976409,
					["TheSepulcher"] = 168935235802,
					["TheSkitteringDark"] = 247640291,
					["ValgansField"] = 83161690274,
				},
				["SouthernBarrens"] = {
					["BaelModan"] = 491117563149,
					["Battlescar"] = 329926304128,
					["ForwardCommand"] = 269952921816,
					["FrazzlecrazMotherload"] = 468433702130,
					["HonorsStand"] = 210938171,
					["HuntersHill"] = 69034232026,
					["NorthwatchHold"] = 158414953752,
					["RazorfenKraul"] = 567222087894,
					["RuinsofTaurajo"] = 307346189597,
					["TheOvergrowth"] = 125931063651,
					["VendettaPoint"] = 210733586686,
				},
				["SpiresOfArak"] = {
					["BLOODBLADEREDOUBT"] = 225836165329,
					["BLOODMANEVALLEY"] = 376239806693,
					["CENTERRAVENNEST"] = 274269927612,
					["CLUTCHPOP"] = 410728497369,
					["EASTMUSHROOMS"] = 167110758582,
					["EMPTYGARRISON"] = 280542506174,
					["HOWLINGCRAG"] = 481577342,
					["NWCORNER"] = 107266362,
					["SETHEKKHOLLOW"] = 136910773486,
					["SKETTIS"] = 303217011,
					["SOLOSPIRENORTH"] = 90644443332,
					["SOLOSPIRESOUTH"] = 296745093289,
					["SOUTHPORT"] = 352512560325,
					["VEILAKRAZ"] = 89415457020,
					["VEILZEKK"] = 288309354694,
					["VENTURECOVE"] = 510515152098,
					["WRITHINGMIRE"] = 212807668965,
				},
				["StonetalonMountains"] = {
					["BattlescarValley"] = 203168195874,
					["BoulderslideRavine"] = 550313816258,
					["CliffwalkerPost"] = 102389448945,
					["GreatwoodVale"] = 481667805506,
					["KromgarFortress"] = 366762725559,
					["Malakajin"] = 577247513811,
					["MirkfallonLake"] = 153982590196,
					["RuinsofEldrethar"] = 441692957917,
					["StonetalonPeak"] = 278122801,
					["SunRockRetreat"] = 306386794718,
					["ThaldarahOverlook"] = 130187195602,
					["TheCharredVale"] = 395345938709,
					["UnearthedGrounds"] = 396896712969,
					["WebwinderHollow"] = 431073003684,
					["WebwinderPath"] = 282885193995,
					["WindshearCrag"] = 192758971766,
					["WindshearHold"] = 310852646064,
				},
				["StranglethornJungle"] = {
					["BalAlRuins"] = 180668736671,
					["BaliaMahRuins"] = 261335758063,
					["Bambala"] = 176687333566,
					["FortLivingston"] = 403070691558,
					["GromGolBaseCamp"] = 245125794983,
					["KalAiRuins"] = 197939845259,
					["KurzensCompound"] = 523483380,
					["LakeNazferiti"] = 102438768880,
					["Mazthoril"] = 391353994590,
					["MizjahRuins"] = 264546464925,
					["MoshOggOgreMound"] = 272226269418,
					["NesingwarysExpedition"] = 67966793955,
					["RebelCamp"] = 321034542,
					["RuinsOfZulKunda"] = 165946596,
					["TheVileReef"] = 223485329644,
					["ZulGurub"] = 656982392,
					["ZuuldalaRuins"] = 23632026948,
				},
				["Sunwell"] = {
					["SunsReachHarbor"] = 270847607296,
					["SunsReachSanctum"] = 4558684672,
				},
				["SwampOfSorrows"] = {
					["Bogpaddle"] = 629343494,
					["IthariusCave"] = 259853185292,
					["MarshtideWatch"] = 501569866,
					["MistyValley"] = 85899638028,
					["MistyreedStrand"] = 629830034,
					["PoolOfTears"] = 256153720065,
					["Sorrowmurk"] = 86636923109,
					["SplinterspearJunction"] = 253606845678,
					["Stagalbog"] = 387113598299,
					["Stonard"] = 277337133413,
					["TheHarborage"] = 84994715914,
					["TheShiftingMire"] = 26117251364,
				},
				["Talador"] = {
					["ARUUNA"] = 191752284549,
					["AUCHINDOUN"] = 382606776629,
					["CENTERISLES"] = 245385945340,
					["COURTOFSOULS"] = 283625362739,
					["FORTWRYNN"] = 45691940132,
					["GORDALFORTRESS"] = 406449326503,
					["GULROK"] = 391015315734,
					["NORTHGATE"] = 598889870,
					["ORUNAICOAST"] = 448015639,
					["SEENTRANCE"] = 320693621044,
					["SHATTRATH"] = 23804099990,
					["TELMOR"] = 548899288561,
					["TOMBOFLIGHTS"] = 291353350470,
					["TUUREM"] = 159408947425,
					["ZANGARRA"] = 38328882463,
				},
				["TanaanJungle"] = {
					["DARKPORTAL"] = 146697278797,
					["DRAENEISW"] = 394148397230,
					["FANGRILA"] = 421356904791,
					["FELFORGE"] = 201200950495,
					["IRONFRONT"] = 283468092625,
					["IRONHARBOR"] = 66890012861,					
					["KILJAEDEN"] = 25107386733,
					["KRANAK"] = 100988614994,
					["LIONSWATCH"] = 336568992014,
					["MARSHLANDS"] = 411553720566,
					["SHANAAR"] = 380283185400,
					["VOLMAR"] = 184135423214,
					["ZETHGOL"] = 208429903122,
					["HELLFIRECITADEL"] = 281586943303,				
				},
				["Tanaris"] = {
					["AbyssalSands"] = 159225415935,
					["BrokenPillar"] = 226992753859,
					["CavernsofTime"] = 256082359509,
					["DunemaulCompound"] = 276271645927,
					["EastmoonRuins"] = 366544587949,
					["Gadgetzan"] = 99216445629,
					["GadgetzanBay"] = 10166293758,
					["LandsEndBeach"] = 485783462112,
					["LostRiggerCover"] = 216467229874,
					["SandsorrowWatch"] = 106607826134,
					["SouthbreakShore"] = 310769805586,
					["SouthmoonRuins"] = 375051734248,
					["TheGapingChasm"] = 391311977697,
					["TheNoxiousLair"] = 226830252211,
					["ThistleshrubValley"] = 300841997533,
					["ValleryoftheWatchers"] = 463050307853,
					["ZulFarrak"] = 193132859,
				},
				["Teldrassil"] = {
					["BanethilHollow"] = 237689351343,
					["Darnassus"] = 194503853354,
					["GalardellValley"] = 254965639346,
					["GnarlpineHold"] = 381542388934,
					["LakeAlameth"] = 333302671649,
					["PoolsofArlithrien"] = 261281237132,
					["RutheranVillage"] = 481381544253,
					["Shadowglen"] = 112173737201,
					["StarbreezeVillage"] = 233572602043,
					["TheCleft"] = 117491075216,
					["TheOracleGlade"] = 96926421186,
					["WellspringLake"] = 89521382565,
				},
				["TerokkarForest"] = {
					["AllerianStronghold"] = 297930064128,
					["AuchenaiGrounds"] = 466263189760,
					["BleedingHollowClanRuins"] = 323304668416,
					["BonechewerRuins"] = 295825572096,
					["CarrionHill"] = 292453351680,
					["CenarionThicket"] = 329515264,
					["FirewingPoint"] = 160635027841,
					["GrangolvarVilliage"] = 183760060928,
					["RaastokGlade"] = 165886034176,
					["RazorthornShelf"] = 20902576384,
					["RefugeCaravan"] = 288094421120,
					["RingofObservance"] = 370766250240,
					["SethekkTomb"] = 310568550656,
					["ShattrathCity"] = 4404544000,
					["SkethylMountains"] = 374133293568,
					["SmolderingCaravan"] = 494258045184,
					["StonebreakerHold"] = 177583948032,
					["TheBarrierHills"] = 4416864512,
					["Tuurem"] = 36984848640,
					["VeilRhaze"] = 388927586560,
					["WrithingMound"] = 351551095040,
				},
				["TheCapeOfStranglethorn"] = {
					["BootyBay"] = 366449261793,
					["CrystalveinMine"] = 78937010447,
					["GurubashiArena"] = 362025198,
					["HardwrenchHideaway"] = 124772382052,
					["JagueroIsle"] = 434285846768,
					["MistvaleValley"] = 266716039421,
					["NekmaniWellspring"] = 229013419254,
					["RuinsofAboraz"] = 194906341560,
					["RuinsofJubuwal"] = 128266237083,
					["TheSundering"] = 474170612,
					["WildShore"] = 421263593708,
				},
				["TheHiddenPass"] = {
					["TheBlackMarket"] = 188294346207,
					["TheHiddenCliffs"] = 454258982,
					["TheHiddenSteps"] = 512607059234,
				},
				["TheJadeForest"] = {
					["ChunTianMonastery"] = 60444317923,
					["DawnsBlossom"] = 191467047146,
					["DreamersPavillion"] = 558842925274,
					["EmperorsOmen"] = 22999675082,
					["GlassfinVillage"] = 384950393110,
					["GrookinMound"] = 229971825917,
					["HellscreamsHope"] = 80720599236,
					["JadeMines"] = 157185882348,
					["NectarbreezeOrchard"] = 354639151323,
					["NookaNooka"] = 162333406427,
					["RuinsOfGanShi"] = 331512004,
					["SerpentsSpine"] = 321455874239,
					["SlingtailPits"] = 447125573811,
					["TempleOfTheJadeSerpent"] = 317244787976,
					["TheArboretum"] = 231359072498,
					["Waywardlanding"] = 517906557147,
					["WindlessIsle"] = 46736437499,
					["WreckOfTheSkyShark"] = 211974354,
				},
				["TheLostIsles"] = {
					["Alliancebeachhead"] = 373797597361,
					["BilgewaterLumberyard"] = 46655554808,
					["GallywixDocks"] = 22916812973,
					["HordeBaseCamp"] = 492029802718,
					["KTCOilPlatform"] = 12265339036,
					["Lostpeak"] = 23158330718,
					["OoomlotVillage"] = 370973822173,
					["Oostan"] = 173388597458,
					["RaptorRise"] = 395573408936,
					["RuinsOfVashelan"] = 485792899284,
					["ScorchedGully"] = 198981222705,
					["ShipwreckShore"] = 438285024428,
					["SkyFalls"] = 141096577214,
					["TheSavageGlen"] = 349189660903,
					["TheSlavePits"] = 73307194580,
					["WarchiefsLookout"] = 154895882399,
					["landingSite"] = 385868764302,
				},
				["TheStormPeaks"] = {
					["BorsBreath"] = 402767678786,
					["BrunnhildarVillage"] = 397640247601,
					["DunNiffelem"] = 306521177397,
					["EngineoftheMakers"] = 318159113426,
					["Frosthold"] = 460775977204,
					["GarmsBane"] = 505073040568,
					["NarvirsCradle"] = 154843462836,
					["Nidavelir"] = 221304266973,
					["SnowdriftPlains"] = 153715187917,
					["SparksocketMinefield"] = 502765134075,
					["TempleofLife"] = 121930791094,
					["TempleofStorms"] = 323447066793,
					["TerraceoftheMakers"] = 131303036267,
					["Thunderfall"] = 192857739570,
					["Ulduar"] = 228861297,
					["Valkyrion"] = 341552822500,
				},
				["TheWanderingIsle"] = {
					["Fe-FangVillage"] = 9804478698,
					["MandoriVillage"] = 316091521634,
					["MorningBreezeVillage"] = 38867889413,
					["Pei-WuForest"] = 436307499659,
					["PoolofthePaw"] = 348203970780,
					["RidgeofLaughingWinds"] = 212793099577,
					["SkyfireCrash-Site"] = 434995731802,
					["TempleofFiveDawns"] = 195835672159,
					["TheDawningValley"] = 341471909,
					["TheRows"] = 317282702721,
					["TheSingingPools"] = 13456862580,
					["TheWoodofStaves"] = 216909958109,
				},
				["ThousandNeedles"] = {
					["DarkcloudPinnacle"] = 124731519293,
					["FreewindPost"] = 200005664180,
					["Highperch"] = 143881793782,
					["RazorfenDowns"] = 312797545,
					["RustmaulDiveSite"] = 499842755818,
					["SouthseaHoldfast"] = 443174617334,
					["SplithoofHeights"] = 53212506543,
					["TheGreatLift"] = 142844176,
					["TheShimmeringDeep"] = 276571778459,
					["TheTwilightWithering"] = 353625263478,
					["TwilightBulwark"] = 258903279974,
					["WestreachSummit"] = 333080,
				},
				["Tirisfal"] = {
					["AgamandMills"] = 96976769309,
					["BalnirFarmstead"] = 348515388658,
					["BrightwaterLake"] = 131597635794,
					["Brill"] = 271086442695,
					["CalstonEstate"] = 274212234419,
					["ColdHearthManor"] = 340814644436,
					["CrusaderOutpost"] = 249827641519,
					["Deathknell"] = 222274411951,
					["GarrensHaunt"] = 139013085374,
					["NightmareVale"] = 349330236641,
					["RuinsofLorderon"] = 385917136262,
					["ScarletMonastery"] = 51242080518,
					["ScarletWatchPost"] = 107026294945,
					["SollidenFarmstead"] = 206369424670,
					["TheBulwark"] = 355078588709,
					["VenomwebVale"] = 161850088698,
				},
				["TolBarad"] = {
				},
				["TolBaradDailyArea"] = {
				},
				["TownlongWastes"] = {
					["GaoRanBlockade"] = 503083901281,
					["KriVess"] = 224852718847,
					["MingChiCrossroads"] = 480400078071,
					["NiuzaoTemple"] = 258995494184,
					["OsulMesa"] = 199229743342,
					["ShadoPanGarrison"] = 413823838421,
					["ShanzeDao"] = 131324204,
					["Sikvess"] = 465251314949,
					["SriVess"] = 206255189286,
					["TheSumprushes"] = 396782417167,
					["palewindVillage"] = 389420468506,
				},
				["TwilightHighlands"] = {
					["Bloodgulch"] = 220553442519,
					["CrucibleOfCarnage"] = 288168820939,
					["Crushblow"] = 480350768310,
					["DragonmawPass"] = 128928921883,
					["DragonmawPort"] = 263728610555,
					["DunwaldRuins"] = 394477660357,
					["FirebeardsPatrol"] = 285065008343,
					["GlopgutsHollow"] = 95868352686,
					["GorshakWarCamp"] = 236792752322,
					["GrimBatol"] = 239531741414,
					["Highbank"] = 433449045212,
					["HighlandForest"] = 354840453359,
					["HumboldtConflaguration"] = 95923877007,
					["Kirthaven"] = 505687348,
					["ObsidianForest"] = 408479367510,
					["RuinsOfDrakgor"] = 310565070,
					["SlitheringCove"] = 182114788550,
					["TheBlackBreach"] = 130445166803,
					["TheGullet"] = 192482037935,
					["TheKrazzworks"] = 686006498,
					["TheTwilightBreach"] = 206485803207,
					["TheTwilightCitadel"] = 337313630569,
					["TheTwilightGate"] = 382595177637,
					["Thundermar"] = 100250391790,
					["TwilightShore"] = 371080767748,
					["VermillionRedoubt"] = 17254588740,
					["VictoryPoint"] = 328881831089,
					["WeepingWound"] = 375584982,
					["WyrmsBend"] = 249323264191,
				},
				["Uldum"] = {
					["AkhenetFields"] = 297920554148,
					["CradelOfTheAncient"] = 432001950922,
					["HallsOfOrigination"] = 198196840717,
					["KhartutsTomb"] = 568548555,
					["LostCityOfTheTolVir"] = 313011799273,
					["Marat"] = 187256997024,
					["Nahom"] = 174557694189,
					["Neferset"] = 412743891153,
					["ObeliskOfTheMoon"] = 115573136,
					["ObeliskOfTheStars"] = 130500700356,
					["ObeliskOfTheSun"] = 303151918349,
					["Orsis"] = 146305961209,
					["Ramkahen"] = 72371899620,
					["RuinsOfAhmtul"] = 382907670,
					["RuinsOfAmmon"] = 310539183307,
					["Schnottzslanding"] = 237326599480,
					["TahretGrounds"] = 207803808918,
					["TempleofUldum"] = 136503837992,
					["TheCursedlanding"] = 183324963053,
					["TheGateofUnendingCycles"] = 16784797857,
					["TheTrailOfDevestation"] = 375425020110,
					["TheVortexPinnacle"] = 508567948501,
					["ThroneOfTheFourWinds"] = 465170568462,
					["VirnaalDam"] = 231356907671,
				},
				["UngoroCrater"] = {
					["FirePlumeRidge"] = 206532018497,
					["FungalRock"] = 584252640,
					["GolakkaHotSprings"] = 242817979701,
					["IronstonePlateau"] = 216562628805,
					["LakkariTarPits"] = 320117168,
					["MarshalsStand"] = 354819418316,
					["MossyPile"] = 192543909050,
					["TerrorRun"] = 383496000828,
					["TheMarshlands"] = 275479163143,
					["TheRollingGarden"] = 42468705617,
					["TheScreamingReaches"] = 164966732,
					["TheSlitheringScar"] = 412668414333,
				},
				["ValeofEternalBlossoms"] = {
					["GuoLaiRuins"] = 3312809297,
					["MistfallVillage"] = 389978309942,
					["MoguShanPalace"] = 24282269045,
					["SettingSunTraining"] = 251256026462,
					["TheGoldenStair"] = 17524062450,
					["TheStairsAscent"] = 287272443326,
					["TheTwinMonoliths"] = 104619059472,
					["TuShenBurialGround"] = 339668685067,
					["WhiteMoonShrine"] = 11243100458,
					["WhitepetalLake"] = 182827902219,
					["WinterboughGlade"] = 114894910825,
				},
				["ValleyoftheFourWinds"] = {
					["CliffsofDispair"] = 434017411582,
					["DustbackGorge"] = 368293761233,
					["GildedFan"] = 44482990288,
					["GrandGranery"] = 349316534586,
					["Halfhill"] = 190511830222,
					["HarvestHome"] = 256629796100,
					["KuzenVillage"] = 79692087495,
					["MudmugsPlace"] = 173460907238,
					["NesingwarySafari"] = 350149236985,
					["PaoquanHollow"] = 112755726609,
					["PoolsofPurity"] = 62815197397,
					["RumblingTerrace"] = 323806811413,
					["SilkenFields"] = 272212692222,
					["SingingMarshes"] = 139764993199,
					["StormsoutBrewery"] = 408260215041,
					["Theheartland"] = 80796328222,
					["ThunderfootFields"] = 652539260,
					["ZhusDecent"] = 123139853615,
				},
				["VashjirDepths"] = {
					["AbandonedReef"] = 282446932339,
					["AbyssalBreach"] = 521624043,
					["ColdlightChasm"] = 300927015179,
					["DeepfinRidge"] = 34648365419,
					["FireplumeTrench"] = 118442159402,
					["KorthunsEnd"] = 304301344114,
					["LGhorek"] = 225655952690,
					["Seabrush"] = 196930169057,
				},
				["VashjirKelpForest"] = {
					["DarkwhisperGorge"] = 245366977756,
					["GnawsBoneyard"] = 349439223095,
					["GubogglesLedge"] = 301066304739,
					["HoldingPens"] = 431048895804,
					["HonorsTomb"] = 46569568547,
					["LegionsFate"] = 37801487638,
					["TheAccursedReef"] = 174329136468,
				},
				["VashjirRuins"] = {
					["BethMoraRidge"] = 478242110799,
					["GlimmeringdeepGorge"] = 238653985040,
					["Nespirah"] = 280729236766,
					["RuinsOfTherseral"] = 188485958853,
					["RuinsOfVashjir"] = 287990719837,
					["ShimmeringGrotto"] = 419715411,
					["SilverTideHollow"] = 34517351904,
				},
				["WesternPlaguelands"] = {
					["Andorhal"] = 368394442192,
					["CaerDarrow"] = 419389718722,
					["DalsonsFarm"] = 249422872901,
					["DarrowmereLake"] = 380639701484,
					["FelstoneField"] = 245053477105,
					["GahrronsWithering"] = 229226311921,
					["Hearthglen"] = 246693296,
					["NorthridgeLumberCamp"] = 132312652135,
					["RedpineDell"] = 226859554082,
					["SorrowHill"] = 481310241136,
					["TheBulwark"] = 252379984188,
					["TheWeepingCave"] = 162713016505,
					["TheWrithingHaunt"] = 356977413289,
					["ThondrorilRiver"] = 559337783,
				},
				["Westfall"] = {
					["AlexstonFarmstead"] = 282569439578,
					["DemontsPlace"] = 403939986633,
					["FurlbrowsPumpkinFarm"] = 413357253,
					["GoldCoastQuarry"] = 85034584299,
					["JangoloadMine"] = 326341828,
					["Moonbrook"] = 349289272552,
					["SaldeansFarm"] = 87446238452,
					["SentinelHill"] = 243089548517,
					["TheDaggerHills"] = 424446018852,
					["TheDeadAcre"] = 215305438401,
					["TheDustPlains"] = 406377993533,
					["TheGapingChasm"] = 180697130168,
					["TheJansenStead"] = 497208522,
					["TheMolsenFarm"] = 127066669258,
					["WestfallLighthouse"] = 512406756563,
				},
				["Wetlands"] = {
					["AngerfangEncampment"] = 216198807788,
					["BlackChannelMarsh"] = 257737072941,
					["BluegillMarsh"] = 109554426177,
					["DireforgeHills"] = 37038035273,
					["DunAlgaz"] = 450260852010,
					["DunModr"] = 7889675521,
					["GreenwardensGrove"] = 110004286714,
					["IronbeardsTomb"] = 81994678457,
					["MenethilHarbor"] = 318901693765,
					["MosshideFen"] = 249638923633,
					["RaptorRidge"] = 132698592512,
					["Satlspray"] = 228878586,
					["SlabchiselsSurvey"] = 378515288364,
					["SundownMarsh"] = 67772861716,
					["ThelganRock"] = 360092744962,
					["WhelgarsExcavationSite"] = 209574100266,
				},
				["Winterspring"] = {
					["Everlook"] = 209885304002,
					["FrostfireHotSprings"] = 126799349112,
					["FrostsaberRock"] = 319041868,
					["FrostwhisperGorge"] = 509398408509,
					["IceThistleHills"] = 337764377849,
					["LakeKeltheril"] = 288153143567,
					["Mazthoril"] = 365490845953,
					["OwlWingThicket"] = 471955822846,
					["StarfallVillage"] = 35673952623,
					["TheHiddenGrove"] = 18778160461,
					["TimbermawPost"] = 324366758250,
					["WinterfallVillage"] = 194964047069,
				},
				["Zangarmarsh"] = {
					["AngoroshGrounds"] = 53779628288,
					["AngoroshStronghold"] = 130154752,
					["BloodscaleEnclave"] = 443006845184,
					["CenarionRefuge"] = 345399099700,
					["CoilfangReservoir"] = 97121730816,
					["FeralfenVillage"] = 356811883008,
					["MarshlightLake"] = 163293954304,
					["OreborHarborage"] = 27189051648,
					["QuaggRidge"] = 349114293504,
					["Sporeggar"] = 216917082624,
					["Telredor"] = 120856248576,
					["TheDeadMire"] = 138190258462,
					["TheHewnBog"] = 54990995712,
					["TheLagoon"] = 325880905984,
					["TheSpawningGlen"] = 364031246592,
					["TwinspireRuins"] = 267720589568,
					["UmbrafenVillage"] = 495750167808,
					["ZabraJin"] = 249291866368,
				},
				["ZulDrak"] = {
					["AltarOfHarKoa"] = 371000083721,
					["AltarOfMamToth"] = 95092536631,
					["AltarOfQuetzLun"] = 270145978629,
					["AltarOfRhunok"] = 136817459447,
					["AltarOfSseratus"] = 180690870509,
					["AmphitheaterOfAnguish"] = 308467202314,
					["DrakSotraFields"] = 384741680414,
					["GunDrak"] = 659858768,
					["Kolramas"] = 469623872814,
					["LightsBreach"] = 389958387009,
					["ThrymsEnd"] = 265214505232,
					["Voltarus"] = 205267438810,
					["Zeramas"] = 442389233971,
					["ZimTorga"] = 259274311929,
				},
				["AszunaDungeonExterior"] = {
					["EYEOFAZSHARA"] = 41579344,
				},
				["Azsuna"] = {
					["FARONAAR"] = 217070183754,
					["FELBLAZE"] = 623164655,
					["GREENWAY"] = 102477521143,
					["ISLEOFTHEWATCHERS"] = 430865395009,
					["LLOTHIENHIGHLANDS"] = 74318075231,
					["LOSTORCHARD"] = 269673787,
					["NARTHALAS"] = 186219954448,
					["OCEANUSCOVE"] = 262408513742,
					["RUINEDSANCTUM"] = 250730545372,
					["TEMPLELIGHTS"] = 365576834229,
					["ZARKHENAR"] = 500370720,
				},
				["BrokenShore"] = {
					["BROKENVALLEY"] = 90460981586,
					["DEADWOODLANDING"] = 279403812022,
					["DELIVERANCEPOINT"] = 324597508483,
					["FELRAGESTRAND"] = 107999416652,
					["SOULRUIN"] = 193681701202,
					["THELOSTTEMPLE"] = 182125318452,
					["THEWEEPINGTERRACE"] = 14325863700,
					["TOMBOFSARGERAS"] = 524596536,
				},		
				["Highmountain"] = {
					["BLOODHUNTHIGHLANDS"] = 80852805929,
					["CAVEA"] = 204477663342,
					["FELTOTEM"] = 33466685696,
					["FROSTHOOFWATCH"] = 438496875706,
					["IRONHORNENCLAVE"] = 440708368672,
					["NIGHTWATCHERSPERCH"] = 261993307480,
					["PINEROCKBASIN"] = 267700555993,
					["RIVERBEND"] = 386876625110,
					["ROCKAWAYSHALLOWS"] = 48810473679,
					["SHIPWRECKCOVE"] = 347253019,
					["SKYHORN"] = 192574362935,
					["STONEHOOFWATCH"] = 253921403221,
					["SYLVANFALLS"] = 367220038077,
					["THUNDERTOTEM"] = 324618362100,
					["TRUESHOTLODGE"] = 253664374956,
				},			
				["Niskara"] = {
					["DEATHKNIGHT"] = 255834839156,
					["MARKSMAN"] = 250464104710,
				},	
				["Stormheim"] = {
					["AGGRAMMARSVAULT"] = 225864508615,
					["BLACKBEAKOVERLOOK"] = 138674391337,
					["DREADWAKE"] = 442861083863,
					["DREYRGROT"] = 286337942660,
					["GREYWATCH"] = 364678122669,
					["HALLSOFVALOR"] = 400045662460,
					["HAUSTVALD"] = 201431627976,
					["HRYDSHAL"] = 379031187063,
					["MAWOFNASHAL"] = 18083325,
					["MORHEIM"] = 336858370198,
					["NASTRONDIR"] = 102367430897,
					["QATCHMANSROCK"] = 87626516615,
					["RUNEWOOD"] = 243286628546,
					["SHIELDSREST"] = 722645281,
					["SKOLDASHIL"] = 370971681969,
					["STORMSREACH"] = 127236473012,
					["TALONREST"] = 303126757667,
					["TIDESKORNHARBOR"] = 196997225677,
					["VALDISDALL"] = 309785163962,
					["WEEPINGBLUFFS"] = 198701279618,
				},		
				["Suramar"] = {
					["AMBERVALE"] = 192338517214,
					["CRIMSONTHICKET"] = 516289863,
					["FALANAAR"] = 146053330168,
					["FELSOULHOLD"] = 327683517729,
					["GRANDPROMENADE"] = 306377428323,
					["JANDVIK"] = 611871139,
					["MOONGUARDSTRONGHOLD"] = 61068768,
					["MOONWHISPERGULCH"] = 211087788,
					["RUINSOFELUNEETH"] = 242942705885,
					["SURAMARCITY"] = 355817833942,
					["TELANOR"] = 343265667,
				},
				["Valsharah"] = {
					["ANDUTALAH"] = 269051216113,
					["BLACKROOKHOLD"] = 188179805434,
					["BRADENSBROOK"] = 295550832951,
					["DREAMGROVE"] = 297120038,
					["GLOAMINGREEF"] = 294348174575,
					["GROVEOFCENARIUS"] = 377362733227,
					["LORLATHIL"] = 443945218225,
					["MISTVALE"] = 19967336722,
					["MOONCLAWVALE"] = 408597849342,
					["SHALANIR"] = 439722310,
					["SMOLDERHIDE"] = 515736006997,
					["TEMPLEOFELUNE"] = 258179558616,
					["THASTALAH"] = 447035384026,
				},		
				["ArgusCore"] = {
					["DEFILEDPATH"] = 307627634,
					["FELFIREARMORY"] = 684692,
					["TERMINUS"] = 256111983059,
				},
				["ArgusMacAree"] = {
					["CONSERVATORY"] = 119707895097,
					["RUINSOFORONAAR"] = 305234499849,
					["SEATOFTRIUMVIRATE"] = 58260463055,
					["SHADOWGUARD"] = 472562,
					["TRIUMVIRATES"] = 403083370780,
					["UPPERTERRACE"] = 331453,
				},
				["ArgusSurface"] = {
					["ANNIHILANPITS"] = 191515410728,
					["KROKULHOVEL"] = 391291126067,
					["NATHRAXAS"] = 175545155,
					["PETRIFIEDFOREST"] = 310895832509,
					["SHATTEREDFIELDS"] = 148215712242,
				},						
				['*'] = {},
				
				
				
				----------- Content of DataExport: ----------------
				[896] = {
					{
						["offsetX"] = 1812,
						["textureHeight"] = 880,
						["textureWidth"] = 1125,
						["offsetY"] = 760,
						["fileDataIDs"] = {
							2037819, -- [1]
							2037830, -- [2]
							2037832, -- [3]
							2037833, -- [4]
							2037834, -- [5]
							2037835, -- [6]
							2037836, -- [7]
							2037837, -- [8]
							2037838, -- [9]
							2037820, -- [10]
							2037821, -- [11]
							2037822, -- [12]
							2037823, -- [13]
							2037824, -- [14]
							2037825, -- [15]
							2037826, -- [16]
							2037827, -- [17]
							2037828, -- [18]
							2037829, -- [19]
							2037831, -- [20]
						},
					}, -- [1]
					{
						["offsetX"] = 1644,
						["textureHeight"] = 1081,
						["textureWidth"] = 948,
						["offsetY"] = 361,
						["fileDataIDs"] = {
							2038047, -- [1]
							2038058, -- [2]
							2038060, -- [3]
							2038061, -- [4]
							2038062, -- [5]
							2038063, -- [6]
							2038064, -- [7]
							2038065, -- [8]
							2038066, -- [9]
							2038048, -- [10]
							2038049, -- [11]
							2038050, -- [12]
							2038051, -- [13]
							2038052, -- [14]
							2038053, -- [15]
							2038054, -- [16]
							2038055, -- [17]
							2038056, -- [18]
							2038057, -- [19]
							2038059, -- [20]
						},
					}, -- [2]
					{
						["offsetX"] = 933,
						["textureHeight"] = 1421,
						["textureWidth"] = 1188,
						["offsetY"] = 863,
						["fileDataIDs"] = {
							2037789, -- [1]
							2037800, -- [2]
							2037811, -- [3]
							2037813, -- [4]
							2037814, -- [5]
							2037815, -- [6]
							2037816, -- [7]
							2037817, -- [8]
							2037818, -- [9]
							2037790, -- [10]
							2037791, -- [11]
							2037792, -- [12]
							2037793, -- [13]
							2037794, -- [14]
							2037795, -- [15]
							2037796, -- [16]
							2037797, -- [17]
							2037798, -- [18]
							2037799, -- [19]
							2037801, -- [20]
							2037802, -- [21]
							2037803, -- [22]
							2037804, -- [23]
							2037805, -- [24]
							2037806, -- [25]
							2037807, -- [26]
							2037808, -- [27]
							2037809, -- [28]
							2037810, -- [29]
							2037812, -- [30]
						},
					}, -- [3]
					{
						["offsetX"] = 1839,
						["textureHeight"] = 1059,
						["textureWidth"] = 1154,
						["offsetY"] = 0,
						["fileDataIDs"] = {
							2037839, -- [1]
							2037850, -- [2]
							2037857, -- [3]
							2037858, -- [4]
							2037859, -- [5]
							2037860, -- [6]
							2037861, -- [7]
							2037862, -- [8]
							2037863, -- [9]
							2037840, -- [10]
							2037841, -- [11]
							2037842, -- [12]
							2037843, -- [13]
							2037844, -- [14]
							2037845, -- [15]
							2037846, -- [16]
							2037847, -- [17]
							2037848, -- [18]
							2037849, -- [19]
							2037851, -- [20]
							2037852, -- [21]
							2037853, -- [22]
							2037854, -- [23]
							2037855, -- [24]
							2037856, -- [25]
						},
					}, -- [4]
					{
						["offsetX"] = 388,
						["textureHeight"] = 839,
						["textureWidth"] = 1239,
						["offsetY"] = 570,
						["fileDataIDs"] = {
							2037864, -- [1]
							2037875, -- [2]
							2037877, -- [3]
							2037878, -- [4]
							2037879, -- [5]
							2037880, -- [6]
							2037881, -- [7]
							2037882, -- [8]
							2037883, -- [9]
							2037865, -- [10]
							2037866, -- [11]
							2037867, -- [12]
							2037868, -- [13]
							2037869, -- [14]
							2037870, -- [15]
							2037871, -- [16]
							2037872, -- [17]
							2037873, -- [18]
							2037874, -- [19]
							2037876, -- [20]
						},
					}, -- [5]
					{
						["offsetX"] = 377,
						["textureHeight"] = 1154,
						["textureWidth"] = 1139,
						["offsetY"] = 939,
						["fileDataIDs"] = {
							2037884, -- [1]
							2037895, -- [2]
							2037902, -- [3]
							2037903, -- [4]
							2037904, -- [5]
							2037905, -- [6]
							2037906, -- [7]
							2037907, -- [8]
							2037908, -- [9]
							2037885, -- [10]
							2037886, -- [11]
							2037887, -- [12]
							2037888, -- [13]
							2037889, -- [14]
							2037890, -- [15]
							2037891, -- [16]
							2037892, -- [17]
							2037893, -- [18]
							2037894, -- [19]
							2037896, -- [20]
							2037897, -- [21]
							2037898, -- [22]
							2037899, -- [23]
							2037900, -- [24]
							2037901, -- [25]
						},
					}, -- [6]
					{
						["offsetX"] = 2386,
						["textureHeight"] = 1181,
						["textureWidth"] = 770,
						["offsetY"] = 1049,
						["fileDataIDs"] = {
							2038067, -- [1]
							2038078, -- [2]
							2038080, -- [3]
							2038081, -- [4]
							2038082, -- [5]
							2038083, -- [6]
							2038084, -- [7]
							2038085, -- [8]
							2038086, -- [9]
							2038068, -- [10]
							2038069, -- [11]
							2038070, -- [12]
							2038071, -- [13]
							2038072, -- [14]
							2038073, -- [15]
							2038074, -- [16]
							2038075, -- [17]
							2038076, -- [18]
							2038077, -- [19]
							2038079, -- [20]
						},
					}, -- [7]
					{
						["offsetX"] = 1847,
						["textureHeight"] = 1169,
						["textureWidth"] = 1090,
						["offsetY"] = 1025,
						["fileDataIDs"] = {
							2038087, -- [1]
							2038098, -- [2]
							2038105, -- [3]
							2038106, -- [4]
							2038107, -- [5]
							2038108, -- [6]
							2038109, -- [7]
							2038110, -- [8]
							2038111, -- [9]
							2038088, -- [10]
							2038089, -- [11]
							2038090, -- [12]
							2038091, -- [13]
							2038092, -- [14]
							2038093, -- [15]
							2038094, -- [16]
							2038095, -- [17]
							2038096, -- [18]
							2038097, -- [19]
							2038099, -- [20]
							2038100, -- [21]
							2038101, -- [22]
							2038102, -- [23]
							2038103, -- [24]
							2038104, -- [25]
						},
					}, -- [8]
					{
						["offsetX"] = 1261,
						["textureHeight"] = 1204,
						["textureWidth"] = 1079,
						["offsetY"] = 0,
						["fileDataIDs"] = {
							2038112, -- [1]
							2038123, -- [2]
							2038130, -- [3]
							2038131, -- [4]
							2038132, -- [5]
							2038133, -- [6]
							2038134, -- [7]
							2038135, -- [8]
							2038136, -- [9]
							2038113, -- [10]
							2038114, -- [11]
							2038115, -- [12]
							2038116, -- [13]
							2038117, -- [14]
							2038118, -- [15]
							2038119, -- [16]
							2038120, -- [17]
							2038121, -- [18]
							2038122, -- [19]
							2038124, -- [20]
							2038125, -- [21]
							2038126, -- [22]
							2038127, -- [23]
							2038128, -- [24]
							2038129, -- [25]
						},
					}, -- [9]
					{
						["offsetX"] = 1212,
						["textureHeight"] = 1323,
						["textureWidth"] = 1521,
						["offsetY"] = 1237,
						["fileDataIDs"] = {
							2038161, -- [1]
							2038172, -- [2]
							2038183, -- [3]
							2038191, -- [4]
							2038192, -- [5]
							2038193, -- [6]
							2038194, -- [7]
							2038195, -- [8]
							2038196, -- [9]
							2038162, -- [10]
							2038163, -- [11]
							2038164, -- [12]
							2038165, -- [13]
							2038166, -- [14]
							2038167, -- [15]
							2038168, -- [16]
							2038169, -- [17]
							2038170, -- [18]
							2038171, -- [19]
							2038173, -- [20]
							2038174, -- [21]
							2038175, -- [22]
							2038176, -- [23]
							2038177, -- [24]
							2038178, -- [25]
							2038179, -- [26]
							2038180, -- [27]
							2038181, -- [28]
							2038182, -- [29]
							2038184, -- [30]
							2038185, -- [31]
							2038186, -- [32]
							2038187, -- [33]
							2038188, -- [34]
							2038189, -- [35]
							2038190, -- [36]
						},
					}, -- [10]
					{
						["offsetX"] = 438,
						["textureHeight"] = 1026,
						["textureWidth"] = 1424,
						["offsetY"] = 0,
						["fileDataIDs"] = {
							2038197, -- [1]
							2038208, -- [2]
							2038219, -- [3]
							2038221, -- [4]
							2038222, -- [5]
							2038223, -- [6]
							2038224, -- [7]
							2038225, -- [8]
							2038226, -- [9]
							2038198, -- [10]
							2038199, -- [11]
							2038200, -- [12]
							2038201, -- [13]
							2038202, -- [14]
							2038203, -- [15]
							2038204, -- [16]
							2038205, -- [17]
							2038206, -- [18]
							2038207, -- [19]
							2038209, -- [20]
							2038210, -- [21]
							2038211, -- [22]
							2038212, -- [23]
							2038213, -- [24]
							2038214, -- [25]
							2038215, -- [26]
							2038216, -- [27]
							2038217, -- [28]
							2038218, -- [29]
							2038220, -- [30]
						},
					}, -- [11]
				},
				[863] = {
					{
						["offsetX"] = 2349,
						["textureHeight"] = 996,
						["textureWidth"] = 1098,
						["offsetY"] = 871,
						["fileDataIDs"] = {
							2023693, -- [1]
							2023704, -- [2]
							2023706, -- [3]
							2023707, -- [4]
							2023708, -- [5]
							2023709, -- [6]
							2023710, -- [7]
							2023711, -- [8]
							2023712, -- [9]
							2023694, -- [10]
							2023695, -- [11]
							2023696, -- [12]
							2023697, -- [13]
							2023698, -- [14]
							2023699, -- [15]
							2023700, -- [16]
							2023701, -- [17]
							2023702, -- [18]
							2023703, -- [19]
							2023705, -- [20]
						},
					}, -- [1]
					{
						["offsetX"] = 1511,
						["textureHeight"] = 991,
						["textureWidth"] = 800,
						["offsetY"] = 1043,
						["fileDataIDs"] = {
							2023713, -- [1]
							2023721, -- [2]
							2023722, -- [3]
							2023723, -- [4]
							2023724, -- [5]
							2023725, -- [6]
							2023726, -- [7]
							2023727, -- [8]
							2023728, -- [9]
							2023714, -- [10]
							2023715, -- [11]
							2023716, -- [12]
							2023717, -- [13]
							2023718, -- [14]
							2023719, -- [15]
							2023720, -- [16]
						},
					}, -- [2]
					{
						["offsetX"] = 2309,
						["textureHeight"] = 1103,
						["textureWidth"] = 1065,
						["offsetY"] = 210,
						["fileDataIDs"] = {
							2023868, -- [1]
							2023879, -- [2]
							2023886, -- [3]
							2023887, -- [4]
							2023888, -- [5]
							2023889, -- [6]
							2023890, -- [7]
							2023891, -- [8]
							2023892, -- [9]
							2023869, -- [10]
							2023870, -- [11]
							2023871, -- [12]
							2023872, -- [13]
							2023873, -- [14]
							2023874, -- [15]
							2023875, -- [16]
							2023876, -- [17]
							2023877, -- [18]
							2023878, -- [19]
							2023880, -- [20]
							2023881, -- [21]
							2023882, -- [22]
							2023883, -- [23]
							2023884, -- [24]
							2023885, -- [25]
						},
					}, -- [3]
					{
						["offsetX"] = 1097,
						["textureHeight"] = 1119,
						["textureWidth"] = 1534,
						["offsetY"] = 281,
						["fileDataIDs"] = {
							2023893, -- [1]
							2023904, -- [2]
							2023915, -- [3]
							2023917, -- [4]
							2023918, -- [5]
							2023919, -- [6]
							2023920, -- [7]
							2023921, -- [8]
							2023922, -- [9]
							2023894, -- [10]
							2023895, -- [11]
							2023896, -- [12]
							2023897, -- [13]
							2023898, -- [14]
							2023899, -- [15]
							2023900, -- [16]
							2023901, -- [17]
							2023902, -- [18]
							2023903, -- [19]
							2023905, -- [20]
							2023906, -- [21]
							2023907, -- [22]
							2023908, -- [23]
							2023909, -- [24]
							2023910, -- [25]
							2023911, -- [26]
							2023912, -- [27]
							2023913, -- [28]
							2023914, -- [29]
							2023916, -- [30]
						},
					}, -- [4]
					{
						["offsetX"] = 484,
						["textureHeight"] = 967,
						["textureWidth"] = 1157,
						["offsetY"] = 1539,
						["fileDataIDs"] = {
							2023923, -- [1]
							2023934, -- [2]
							2023936, -- [3]
							2023937, -- [4]
							2023938, -- [5]
							2023939, -- [6]
							2023940, -- [7]
							2023941, -- [8]
							2023942, -- [9]
							2023924, -- [10]
							2023925, -- [11]
							2023926, -- [12]
							2023927, -- [13]
							2023928, -- [14]
							2023929, -- [15]
							2023930, -- [16]
							2023931, -- [17]
							2023932, -- [18]
							2023933, -- [19]
							2023935, -- [20]
						},
					}, -- [5]
					{
						["offsetX"] = 1072,
						["textureHeight"] = 809,
						["textureWidth"] = 1289,
						["offsetY"] = 1676,
						["fileDataIDs"] = {
							2023943, -- [1]
							2023954, -- [2]
							2023960, -- [3]
							2023961, -- [4]
							2023962, -- [5]
							2023963, -- [6]
							2023964, -- [7]
							2023965, -- [8]
							2023966, -- [9]
							2023944, -- [10]
							2023945, -- [11]
							2023946, -- [12]
							2023947, -- [13]
							2023948, -- [14]
							2023949, -- [15]
							2023950, -- [16]
							2023951, -- [17]
							2023952, -- [18]
							2023953, -- [19]
							2023955, -- [20]
							2023956, -- [21]
							2023957, -- [22]
							2023958, -- [23]
							2023959, -- [24]
						},
					}, -- [6]
					{
						["offsetX"] = 1682,
						["textureHeight"] = 1029,
						["textureWidth"] = 1349,
						["offsetY"] = 0,
						["fileDataIDs"] = {
							2023967, -- [1]
							2023978, -- [2]
							2023989, -- [3]
							2023991, -- [4]
							2023992, -- [5]
							2023993, -- [6]
							2023994, -- [7]
							2023995, -- [8]
							2023996, -- [9]
							2023968, -- [10]
							2023969, -- [11]
							2023970, -- [12]
							2023971, -- [13]
							2023972, -- [14]
							2023973, -- [15]
							2023974, -- [16]
							2023975, -- [17]
							2023976, -- [18]
							2023977, -- [19]
							2023979, -- [20]
							2023980, -- [21]
							2023981, -- [22]
							2023982, -- [23]
							2023983, -- [24]
							2023984, -- [25]
							2023985, -- [26]
							2023986, -- [27]
							2023987, -- [28]
							2023988, -- [29]
							2023990, -- [30]
						},
					}, -- [7]
					{
						["offsetX"] = 1807,
						["textureHeight"] = 1075,
						["textureWidth"] = 841,
						["offsetY"] = 1043,
						["fileDataIDs"] = {
							2023997, -- [1]
							2024008, -- [2]
							2024010, -- [3]
							2024011, -- [4]
							2024012, -- [5]
							2024013, -- [6]
							2024014, -- [7]
							2024015, -- [8]
							2024016, -- [9]
							2023998, -- [10]
							2023999, -- [11]
							2024000, -- [12]
							2024001, -- [13]
							2024002, -- [14]
							2024003, -- [15]
							2024004, -- [16]
							2024005, -- [17]
							2024006, -- [18]
							2024007, -- [19]
							2024009, -- [20]
						},
					}, -- [8]
					{
						["offsetX"] = 620,
						["textureHeight"] = 1249,
						["textureWidth"] = 1225,
						["offsetY"] = 565,
						["fileDataIDs"] = {
							2024017, -- [1]
							2024028, -- [2]
							2024035, -- [3]
							2024036, -- [4]
							2024037, -- [5]
							2024038, -- [6]
							2024039, -- [7]
							2024040, -- [8]
							2024041, -- [9]
							2024018, -- [10]
							2024019, -- [11]
							2024020, -- [12]
							2024021, -- [13]
							2024022, -- [14]
							2024023, -- [15]
							2024024, -- [16]
							2024025, -- [17]
							2024026, -- [18]
							2024027, -- [19]
							2024029, -- [20]
							2024030, -- [21]
							2024031, -- [22]
							2024032, -- [23]
							2024033, -- [24]
							2024034, -- [25]
						},
					}, -- [9]
				},
				[942] = {
					{
						["offsetX"] = 1750,
						["textureHeight"] = 1224,
						["textureWidth"] = 1167,
						["offsetY"] = 1336,
						["fileDataIDs"] = {
							2033045, -- [1]
							2033056, -- [2]
							2033063, -- [3]
							2033064, -- [4]
							2033065, -- [5]
							2033066, -- [6]
							2033067, -- [7]
							2033068, -- [8]
							2033069, -- [9]
							2033046, -- [10]
							2033047, -- [11]
							2033048, -- [12]
							2033049, -- [13]
							2033050, -- [14]
							2033051, -- [15]
							2033052, -- [16]
							2033053, -- [17]
							2033054, -- [18]
							2033055, -- [19]
							2033057, -- [20]
							2033058, -- [21]
							2033059, -- [22]
							2033060, -- [23]
							2033061, -- [24]
							2033062, -- [25]
						},
					}, -- [1]
					{
						["offsetX"] = 1288,
						["textureHeight"] = 1134,
						["textureWidth"] = 1030,
						["offsetY"] = 1426,
						["fileDataIDs"] = {
							2033070, -- [1]
							2033081, -- [2]
							2033088, -- [3]
							2033089, -- [4]
							2033090, -- [5]
							2033091, -- [6]
							2033092, -- [7]
							2033093, -- [8]
							2033094, -- [9]
							2033071, -- [10]
							2033072, -- [11]
							2033073, -- [12]
							2033074, -- [13]
							2033075, -- [14]
							2033076, -- [15]
							2033077, -- [16]
							2033078, -- [17]
							2033079, -- [18]
							2033080, -- [19]
							2033082, -- [20]
							2033083, -- [21]
							2033084, -- [22]
							2033085, -- [23]
							2033086, -- [24]
							2033087, -- [25]
						},
					}, -- [2]
					{
						["offsetX"] = 2181,
						["textureHeight"] = 1491,
						["textureWidth"] = 1659,
						["offsetY"] = 1069,
						["fileDataIDs"] = {
							2033095, -- [1]
							2033106, -- [2]
							2033117, -- [3]
							2033128, -- [4]
							2033132, -- [5]
							2033133, -- [6]
							2033134, -- [7]
							2033135, -- [8]
							2033136, -- [9]
							2033096, -- [10]
							2033097, -- [11]
							2033098, -- [12]
							2033099, -- [13]
							2033100, -- [14]
							2033101, -- [15]
							2033102, -- [16]
							2033103, -- [17]
							2033104, -- [18]
							2033105, -- [19]
							2033107, -- [20]
							2033108, -- [21]
							2033109, -- [22]
							2033110, -- [23]
							2033111, -- [24]
							2033112, -- [25]
							2033113, -- [26]
							2033114, -- [27]
							2033115, -- [28]
							2033116, -- [29]
							2033118, -- [30]
							2033119, -- [31]
							2033120, -- [32]
							2033121, -- [33]
							2033122, -- [34]
							2033123, -- [35]
							2033124, -- [36]
							2033125, -- [37]
							2033126, -- [38]
							2033127, -- [39]
							2033129, -- [40]
							2033130, -- [41]
							2033131, -- [42]
						},
					}, -- [3]
					{
						["offsetX"] = 1365,
						["textureHeight"] = 1380,
						["textureWidth"] = 929,
						["offsetY"] = 0,
						["fileDataIDs"] = {
							2033137, -- [1]
							2033148, -- [2]
							2033154, -- [3]
							2033155, -- [4]
							2033156, -- [5]
							2033157, -- [6]
							2033158, -- [7]
							2033159, -- [8]
							2033160, -- [9]
							2033138, -- [10]
							2033139, -- [11]
							2033140, -- [12]
							2033141, -- [13]
							2033142, -- [14]
							2033143, -- [15]
							2033144, -- [16]
							2033145, -- [17]
							2033146, -- [18]
							2033147, -- [19]
							2033149, -- [20]
							2033150, -- [21]
							2033151, -- [22]
							2033152, -- [23]
							2033153, -- [24]
						},
					}, -- [4]
					{
						["offsetX"] = 1153,
						["textureHeight"] = 711,
						["textureWidth"] = 1403,
						["offsetY"] = 1056,
						["fileDataIDs"] = {
							2033161, -- [1]
							2033171, -- [2]
							2033172, -- [3]
							2033173, -- [4]
							2033174, -- [5]
							2033175, -- [6]
							2033176, -- [7]
							2033177, -- [8]
							2033178, -- [9]
							2033162, -- [10]
							2033163, -- [11]
							2033164, -- [12]
							2033165, -- [13]
							2033166, -- [14]
							2033167, -- [15]
							2033168, -- [16]
							2033169, -- [17]
							2033170, -- [18]
						},
					}, -- [5]
					{
						["offsetX"] = 840,
						["textureHeight"] = 1050,
						["textureWidth"] = 859,
						["offsetY"] = 475,
						["fileDataIDs"] = {
							2033179, -- [1]
							2033190, -- [2]
							2033192, -- [3]
							2033193, -- [4]
							2033194, -- [5]
							2033195, -- [6]
							2033196, -- [7]
							2033197, -- [8]
							2033198, -- [9]
							2033180, -- [10]
							2033181, -- [11]
							2033182, -- [12]
							2033183, -- [13]
							2033184, -- [14]
							2033185, -- [15]
							2033186, -- [16]
							2033187, -- [17]
							2033188, -- [18]
							2033189, -- [19]
							2033191, -- [20]
						},
					}, -- [6]
					{
						["offsetX"] = 1918,
						["textureHeight"] = 1466,
						["textureWidth"] = 1052,
						["offsetY"] = 0,
						["fileDataIDs"] = {
							2033199, -- [1]
							2033210, -- [2]
							2033221, -- [3]
							2033223, -- [4]
							2033224, -- [5]
							2033225, -- [6]
							2033226, -- [7]
							2033227, -- [8]
							2033228, -- [9]
							2033200, -- [10]
							2033201, -- [11]
							2033202, -- [12]
							2033203, -- [13]
							2033204, -- [14]
							2033205, -- [15]
							2033206, -- [16]
							2033207, -- [17]
							2033208, -- [18]
							2033209, -- [19]
							2033211, -- [20]
							2033212, -- [21]
							2033213, -- [22]
							2033214, -- [23]
							2033215, -- [24]
							2033216, -- [25]
							2033217, -- [26]
							2033218, -- [27]
							2033219, -- [28]
							2033220, -- [29]
							2033222, -- [30]
						},
					}, -- [7]
					{
						["offsetX"] = 2515,
						["textureHeight"] = 1981,
						["textureWidth"] = 1325,
						["offsetY"] = 0,
						["fileDataIDs"] = {
							2033229, -- [1]
							2033240, -- [2]
							2033251, -- [3]
							2033262, -- [4]
							2033272, -- [5]
							2033273, -- [6]
							2033274, -- [7]
							2033275, -- [8]
							2033276, -- [9]
							2033230, -- [10]
							2033231, -- [11]
							2033232, -- [12]
							2033233, -- [13]
							2033234, -- [14]
							2033235, -- [15]
							2033236, -- [16]
							2033237, -- [17]
							2033238, -- [18]
							2033239, -- [19]
							2033241, -- [20]
							2033242, -- [21]
							2033243, -- [22]
							2033244, -- [23]
							2033245, -- [24]
							2033246, -- [25]
							2033247, -- [26]
							2033248, -- [27]
							2033249, -- [28]
							2033250, -- [29]
							2033252, -- [30]
							2033253, -- [31]
							2033254, -- [32]
							2033255, -- [33]
							2033256, -- [34]
							2033257, -- [35]
							2033258, -- [36]
							2033259, -- [37]
							2033260, -- [38]
							2033261, -- [39]
							2033263, -- [40]
							2033264, -- [41]
							2033265, -- [42]
							2033266, -- [43]
							2033267, -- [44]
							2033268, -- [45]
							2033269, -- [46]
							2033270, -- [47]
							2033271, -- [48]
						},
					}, -- [8]
					{
						["offsetX"] = 0,
						["textureHeight"] = 1457,
						["textureWidth"] = 1628,
						["offsetY"] = 1103,
						["fileDataIDs"] = {
							2033415, -- [1]
							2033426, -- [2]
							2033437, -- [3]
							2033448, -- [4]
							2033452, -- [5]
							2033453, -- [6]
							2033454, -- [7]
							2033455, -- [8]
							2033456, -- [9]
							2033416, -- [10]
							2033417, -- [11]
							2033418, -- [12]
							2033419, -- [13]
							2033420, -- [14]
							2033421, -- [15]
							2033422, -- [16]
							2033423, -- [17]
							2033424, -- [18]
							2033425, -- [19]
							2033427, -- [20]
							2033428, -- [21]
							2033429, -- [22]
							2033430, -- [23]
							2033431, -- [24]
							2033432, -- [25]
							2033433, -- [26]
							2033434, -- [27]
							2033435, -- [28]
							2033436, -- [29]
							2033438, -- [30]
							2033439, -- [31]
							2033440, -- [32]
							2033441, -- [33]
							2033442, -- [34]
							2033443, -- [35]
							2033444, -- [36]
							2033445, -- [37]
							2033446, -- [38]
							2033447, -- [39]
							2033449, -- [40]
							2033450, -- [41]
							2033451, -- [42]
						},
					}, -- [9]
				},
				[895] = {
					{
						["offsetX"] = 1108,
						["textureHeight"] = 788,
						["textureWidth"] = 859,
						["offsetY"] = 451,
						["fileDataIDs"] = {
							2033457, -- [1]
							2033465, -- [2]
							2033466, -- [3]
							2033467, -- [4]
							2033468, -- [5]
							2033469, -- [6]
							2033470, -- [7]
							2033471, -- [8]
							2033472, -- [9]
							2033458, -- [10]
							2033459, -- [11]
							2033460, -- [12]
							2033461, -- [13]
							2033462, -- [14]
							2033463, -- [15]
							2033464, -- [16]
						},
					}, -- [1]
					{
						["offsetX"] = 2117,
						["textureHeight"] = 1009,
						["textureWidth"] = 1432,
						["offsetY"] = 332,
						["fileDataIDs"] = {
							2033473, -- [1]
							2033484, -- [2]
							2033490, -- [3]
							2033491, -- [4]
							2033492, -- [5]
							2033493, -- [6]
							2033494, -- [7]
							2033495, -- [8]
							2033496, -- [9]
							2033474, -- [10]
							2033475, -- [11]
							2033476, -- [12]
							2033477, -- [13]
							2033478, -- [14]
							2033479, -- [15]
							2033480, -- [16]
							2033481, -- [17]
							2033482, -- [18]
							2033483, -- [19]
							2033485, -- [20]
							2033486, -- [21]
							2033487, -- [22]
							2033488, -- [23]
							2033489, -- [24]
						},
					}, -- [2]
					{
						["offsetX"] = 1806,
						["textureHeight"] = 900,
						["textureWidth"] = 1777,
						["offsetY"] = 0,
						["fileDataIDs"] = {
							2033497, -- [1]
							2033508, -- [2]
							2033518, -- [3]
							2033519, -- [4]
							2033520, -- [5]
							2033521, -- [6]
							2033522, -- [7]
							2033523, -- [8]
							2033524, -- [9]
							2033498, -- [10]
							2033499, -- [11]
							2033500, -- [12]
							2033501, -- [13]
							2033502, -- [14]
							2033503, -- [15]
							2033504, -- [16]
							2033505, -- [17]
							2033506, -- [18]
							2033507, -- [19]
							2033509, -- [20]
							2033510, -- [21]
							2033511, -- [22]
							2033512, -- [23]
							2033513, -- [24]
							2033514, -- [25]
							2033515, -- [26]
							2033516, -- [27]
							2033517, -- [28]
						},
					}, -- [3]
					{
						["offsetX"] = 2314,
						["textureHeight"] = 821,
						["textureWidth"] = 1047,
						["offsetY"] = 1739,
						["fileDataIDs"] = {
							2033525, -- [1]
							2033536, -- [2]
							2033538, -- [3]
							2033539, -- [4]
							2033540, -- [5]
							2033541, -- [6]
							2033542, -- [7]
							2033543, -- [8]
							2033544, -- [9]
							2033526, -- [10]
							2033527, -- [11]
							2033528, -- [12]
							2033529, -- [13]
							2033530, -- [14]
							2033531, -- [15]
							2033532, -- [16]
							2033533, -- [17]
							2033534, -- [18]
							2033535, -- [19]
							2033537, -- [20]
						},
					}, -- [4]
					{
						["offsetX"] = 1538,
						["textureHeight"] = 1284,
						["textureWidth"] = 908,
						["offsetY"] = 176,
						["fileDataIDs"] = {
							2033545, -- [1]
							2033556, -- [2]
							2033562, -- [3]
							2033563, -- [4]
							2033564, -- [5]
							2033565, -- [6]
							2033566, -- [7]
							2033567, -- [8]
							2033568, -- [9]
							2033546, -- [10]
							2033547, -- [11]
							2033548, -- [12]
							2033549, -- [13]
							2033550, -- [14]
							2033551, -- [15]
							2033552, -- [16]
							2033553, -- [17]
							2033554, -- [18]
							2033555, -- [19]
							2033557, -- [20]
							2033558, -- [21]
							2033559, -- [22]
							2033560, -- [23]
							2033561, -- [24]
						},
					}, -- [5]
					{
						["offsetX"] = 2054,
						["textureHeight"] = 1171,
						["textureWidth"] = 978,
						["offsetY"] = 995,
						["fileDataIDs"] = {
							2033585, -- [1]
							2033596, -- [2]
							2033598, -- [3]
							2033599, -- [4]
							2033600, -- [5]
							2033601, -- [6]
							2033602, -- [7]
							2033603, -- [8]
							2033604, -- [9]
							2033586, -- [10]
							2033587, -- [11]
							2033588, -- [12]
							2033589, -- [13]
							2033590, -- [14]
							2033591, -- [15]
							2033592, -- [16]
							2033593, -- [17]
							2033594, -- [18]
							2033595, -- [19]
							2033597, -- [20]
						},
					}, -- [6]
					{
						["offsetX"] = 2451,
						["textureHeight"] = 944,
						["textureWidth"] = 1242,
						["offsetY"] = 1035,
						["fileDataIDs"] = {
							2033605, -- [1]
							2033616, -- [2]
							2033618, -- [3]
							2033619, -- [4]
							2033620, -- [5]
							2033621, -- [6]
							2033622, -- [7]
							2033623, -- [8]
							2033624, -- [9]
							2033606, -- [10]
							2033607, -- [11]
							2033608, -- [12]
							2033609, -- [13]
							2033610, -- [14]
							2033611, -- [15]
							2033612, -- [16]
							2033613, -- [17]
							2033614, -- [18]
							2033615, -- [19]
							2033617, -- [20]
						},
					}, -- [7]
					{
						["offsetX"] = 2852,
						["textureHeight"] = 1057,
						["textureWidth"] = 891,
						["offsetY"] = 1503,
						["fileDataIDs"] = {
							2033625, -- [1]
							2033636, -- [2]
							2033638, -- [3]
							2033639, -- [4]
							2033640, -- [5]
							2033641, -- [6]
							2033642, -- [7]
							2033643, -- [8]
							2033644, -- [9]
							2033626, -- [10]
							2033627, -- [11]
							2033628, -- [12]
							2033629, -- [13]
							2033630, -- [14]
							2033631, -- [15]
							2033632, -- [16]
							2033633, -- [17]
							2033634, -- [18]
							2033635, -- [19]
							2033637, -- [20]
						},
					}, -- [8]
					{
						["offsetX"] = 1772,
						["textureHeight"] = 1223,
						["textureWidth"] = 953,
						["offsetY"] = 1199,
						["fileDataIDs"] = {
							2033783, -- [1]
							2033794, -- [2]
							2033796, -- [3]
							2033797, -- [4]
							2033798, -- [5]
							2033799, -- [6]
							2033800, -- [7]
							2033801, -- [8]
							2033802, -- [9]
							2033784, -- [10]
							2033785, -- [11]
							2033786, -- [12]
							2033787, -- [13]
							2033788, -- [14]
							2033789, -- [15]
							2033790, -- [16]
							2033791, -- [17]
							2033792, -- [18]
							2033793, -- [19]
							2033795, -- [20]
						},
					}, -- [9]
					{
						["offsetX"] = 802,
						["textureHeight"] = 678,
						["textureWidth"] = 1306,
						["offsetY"] = 0,
						["fileDataIDs"] = {
							2033803, -- [1]
							2033813, -- [2]
							2033814, -- [3]
							2033815, -- [4]
							2033816, -- [5]
							2033817, -- [6]
							2033818, -- [7]
							2033819, -- [8]
							2033820, -- [9]
							2033804, -- [10]
							2033805, -- [11]
							2033806, -- [12]
							2033807, -- [13]
							2033808, -- [14]
							2033809, -- [15]
							2033810, -- [16]
							2033811, -- [17]
							2033812, -- [18]
						},
					}, -- [10]
				},
				[862] = {
					{
						["offsetX"] = 2685,
						["textureHeight"] = 668,
						["textureWidth"] = 793,
						["offsetY"] = 633,
						["fileDataIDs"] = {
							2034211, -- [1]
							2034215, -- [2]
							2034216, -- [3]
							2034217, -- [4]
							2034218, -- [5]
							2034219, -- [6]
							2034220, -- [7]
							2034221, -- [8]
							2034222, -- [9]
							2034212, -- [10]
							2034213, -- [11]
							2034214, -- [12]
						},
					}, -- [1]
					{
						["offsetX"] = 321,
						["textureHeight"] = 1565,
						["textureWidth"] = 1650,
						["offsetY"] = 378,
						["fileDataIDs"] = {
							2034162, -- [1]
							2034173, -- [2]
							2034184, -- [3]
							2034195, -- [4]
							2034206, -- [5]
							2034207, -- [6]
							2034208, -- [7]
							2034209, -- [8]
							2034210, -- [9]
							2034163, -- [10]
							2034164, -- [11]
							2034165, -- [12]
							2034166, -- [13]
							2034167, -- [14]
							2034168, -- [15]
							2034169, -- [16]
							2034170, -- [17]
							2034171, -- [18]
							2034172, -- [19]
							2034174, -- [20]
							2034175, -- [21]
							2034176, -- [22]
							2034177, -- [23]
							2034178, -- [24]
							2034179, -- [25]
							2034180, -- [26]
							2034181, -- [27]
							2034182, -- [28]
							2034183, -- [29]
							2034185, -- [30]
							2034186, -- [31]
							2034187, -- [32]
							2034188, -- [33]
							2034189, -- [34]
							2034190, -- [35]
							2034191, -- [36]
							2034192, -- [37]
							2034193, -- [38]
							2034194, -- [39]
							2034196, -- [40]
							2034197, -- [41]
							2034198, -- [42]
							2034199, -- [43]
							2034200, -- [44]
							2034201, -- [45]
							2034202, -- [46]
							2034203, -- [47]
							2034204, -- [48]
							2034205, -- [49]
						},
					}, -- [2]
					{
						["offsetX"] = 1357,
						["textureHeight"] = 672,
						["textureWidth"] = 1130,
						["offsetY"] = 0,
						["fileDataIDs"] = {
							2034223, -- [1]
							2034230, -- [2]
							2034231, -- [3]
							2034232, -- [4]
							2034233, -- [5]
							2034234, -- [6]
							2034235, -- [7]
							2034236, -- [8]
							2034237, -- [9]
							2034224, -- [10]
							2034225, -- [11]
							2034226, -- [12]
							2034227, -- [13]
							2034228, -- [14]
							2034229, -- [15]
						},
					}, -- [3]
					{
						["offsetX"] = 1815,
						["textureHeight"] = 1207,
						["textureWidth"] = 699,
						["offsetY"] = 260,
						["fileDataIDs"] = {
							2034238, -- [1]
							2034245, -- [2]
							2034246, -- [3]
							2034247, -- [4]
							2034248, -- [5]
							2034249, -- [6]
							2034250, -- [7]
							2034251, -- [8]
							2034252, -- [9]
							2034239, -- [10]
							2034240, -- [11]
							2034241, -- [12]
							2034242, -- [13]
							2034243, -- [14]
							2034244, -- [15]
						},
					}, -- [4]
					{
						["offsetX"] = 2325,
						["textureHeight"] = 830,
						["textureWidth"] = 934,
						["offsetY"] = 1270,
						["fileDataIDs"] = {
							2034253, -- [1]
							2034261, -- [2]
							2034262, -- [3]
							2034263, -- [4]
							2034264, -- [5]
							2034265, -- [6]
							2034266, -- [7]
							2034267, -- [8]
							2034268, -- [9]
							2034254, -- [10]
							2034255, -- [11]
							2034256, -- [12]
							2034257, -- [13]
							2034258, -- [14]
							2034259, -- [15]
							2034260, -- [16]
						},
					}, -- [5]
					{
						["offsetX"] = 2144,
						["textureHeight"] = 1559,
						["textureWidth"] = 943,
						["offsetY"] = 0,
						["fileDataIDs"] = {
							2034293, -- [1]
							2034304, -- [2]
							2034314, -- [3]
							2034315, -- [4]
							2034316, -- [5]
							2034317, -- [6]
							2034318, -- [7]
							2034319, -- [8]
							2034320, -- [9]
							2034294, -- [10]
							2034295, -- [11]
							2034296, -- [12]
							2034297, -- [13]
							2034298, -- [14]
							2034299, -- [15]
							2034300, -- [16]
							2034301, -- [17]
							2034302, -- [18]
							2034303, -- [19]
							2034305, -- [20]
							2034306, -- [21]
							2034307, -- [22]
							2034308, -- [23]
							2034309, -- [24]
							2034310, -- [25]
							2034311, -- [26]
							2034312, -- [27]
							2034313, -- [28]
						},
					}, -- [6]
					{
						["offsetX"] = 2107,
						["textureHeight"] = 967,
						["textureWidth"] = 769,
						["offsetY"] = 327,
						["fileDataIDs"] = {
							2034321, -- [1]
							2034329, -- [2]
							2034330, -- [3]
							2034331, -- [4]
							2034332, -- [5]
							2034333, -- [6]
							2034334, -- [7]
							2034335, -- [8]
							2034336, -- [9]
							2034322, -- [10]
							2034323, -- [11]
							2034324, -- [12]
							2034325, -- [13]
							2034326, -- [14]
							2034327, -- [15]
							2034328, -- [16]
						},
					}, -- [7]
					{
						["offsetX"] = 1825,
						["textureHeight"] = 1344,
						["textureWidth"] = 999,
						["offsetY"] = 1216,
						["fileDataIDs"] = {
							2034337, -- [1]
							2034348, -- [2]
							2034354, -- [3]
							2034355, -- [4]
							2034356, -- [5]
							2034357, -- [6]
							2034358, -- [7]
							2034359, -- [8]
							2034360, -- [9]
							2034338, -- [10]
							2034339, -- [11]
							2034340, -- [12]
							2034341, -- [13]
							2034342, -- [14]
							2034343, -- [15]
							2034344, -- [16]
							2034345, -- [17]
							2034346, -- [18]
							2034347, -- [19]
							2034349, -- [20]
							2034350, -- [21]
							2034351, -- [22]
							2034352, -- [23]
							2034353, -- [24]
						},
					}, -- [8]
					{
						["offsetX"] = 1312,
						["textureHeight"] = 1512,
						["textureWidth"] = 888,
						["offsetY"] = 82,
						["fileDataIDs"] = {
							2034269, -- [1]
							2034280, -- [2]
							2034286, -- [3]
							2034287, -- [4]
							2034288, -- [5]
							2034289, -- [6]
							2034290, -- [7]
							2034291, -- [8]
							2034292, -- [9]
							2034270, -- [10]
							2034271, -- [11]
							2034272, -- [12]
							2034273, -- [13]
							2034274, -- [14]
							2034275, -- [15]
							2034276, -- [16]
							2034277, -- [17]
							2034278, -- [18]
							2034279, -- [19]
							2034281, -- [20]
							2034282, -- [21]
							2034283, -- [22]
							2034284, -- [23]
							2034285, -- [24]
						},
					}, -- [9]
					{
						["offsetX"] = 1046,
						["textureHeight"] = 1287,
						["textureWidth"] = 1243,
						["offsetY"] = 1273,
						["fileDataIDs"] = {
							2034370, -- [1]
							2034381, -- [2]
							2034392, -- [3]
							2034394, -- [4]
							2034395, -- [5]
							2034396, -- [6]
							2034397, -- [7]
							2034398, -- [8]
							2034399, -- [9]
							2034371, -- [10]
							2034372, -- [11]
							2034373, -- [12]
							2034374, -- [13]
							2034375, -- [14]
							2034376, -- [15]
							2034377, -- [16]
							2034378, -- [17]
							2034379, -- [18]
							2034380, -- [19]
							2034382, -- [20]
							2034383, -- [21]
							2034384, -- [22]
							2034385, -- [23]
							2034386, -- [24]
							2034387, -- [25]
							2034388, -- [26]
							2034389, -- [27]
							2034390, -- [28]
							2034391, -- [29]
							2034393, -- [30]
						},
					}, -- [10]
					{
						["offsetX"] = 2409,
						["textureHeight"] = 912,
						["textureWidth"] = 979,
						["offsetY"] = 0,
						["fileDataIDs"] = {
							2034400, -- [1]
							2034408, -- [2]
							2034409, -- [3]
							2034410, -- [4]
							2034411, -- [5]
							2034412, -- [6]
							2034413, -- [7]
							2034414, -- [8]
							2034415, -- [9]
							2034401, -- [10]
							2034402, -- [11]
							2034403, -- [12]
							2034404, -- [13]
							2034405, -- [14]
							2034406, -- [15]
							2034407, -- [16]
						},
					}, -- [11]
					{
						["offsetX"] = 2631,
						["textureHeight"] = 617,
						["textureWidth"] = 726,
						["offsetY"] = 1023,
						["fileDataIDs"] = {
							2034361, -- [1]
							2034362, -- [2]
							2034363, -- [3]
							2034364, -- [4]
							2034365, -- [5]
							2034366, -- [6]
							2034367, -- [7]
							2034368, -- [8]
							2034369, -- [9]
						},
					}, -- [12]
				},
				[864] = {
					{
						["offsetX"] = 1006,
						["textureHeight"] = 897,
						["textureWidth"] = 881,
						["offsetY"] = 341,
						["fileDataIDs"] = {
							2033917, -- [1]
							2033925, -- [2]
							2033926, -- [3]
							2033927, -- [4]
							2033928, -- [5]
							2033929, -- [6]
							2033930, -- [7]
							2033931, -- [8]
							2033932, -- [9]
							2033918, -- [10]
							2033919, -- [11]
							2033920, -- [12]
							2033921, -- [13]
							2033922, -- [14]
							2033923, -- [15]
							2033924, -- [16]
						},
					}, -- [1]
					{
						["offsetX"] = 1469,
						["textureHeight"] = 876,
						["textureWidth"] = 1287,
						["offsetY"] = 1684,
						["fileDataIDs"] = {
							2033821, -- [1]
							2033832, -- [2]
							2033838, -- [3]
							2033839, -- [4]
							2033840, -- [5]
							2033841, -- [6]
							2033842, -- [7]
							2033843, -- [8]
							2033844, -- [9]
							2033822, -- [10]
							2033823, -- [11]
							2033824, -- [12]
							2033825, -- [13]
							2033826, -- [14]
							2033827, -- [15]
							2033828, -- [16]
							2033829, -- [17]
							2033830, -- [18]
							2033831, -- [19]
							2033833, -- [20]
							2033834, -- [21]
							2033835, -- [22]
							2033836, -- [23]
							2033837, -- [24]
						},
					}, -- [2]
					{
						["offsetX"] = 1569,
						["textureHeight"] = 822,
						["textureWidth"] = 1139,
						["offsetY"] = 1281,
						["fileDataIDs"] = {
							2033845, -- [1]
							2033856, -- [2]
							2033858, -- [3]
							2033859, -- [4]
							2033860, -- [5]
							2033861, -- [6]
							2033862, -- [7]
							2033863, -- [8]
							2033864, -- [9]
							2033846, -- [10]
							2033847, -- [11]
							2033848, -- [12]
							2033849, -- [13]
							2033850, -- [14]
							2033851, -- [15]
							2033852, -- [16]
							2033853, -- [17]
							2033854, -- [18]
							2033855, -- [19]
							2033857, -- [20]
						},
					}, -- [3]
					{
						["offsetX"] = 1316,
						["textureHeight"] = 672,
						["textureWidth"] = 849,
						["offsetY"] = 895,
						["fileDataIDs"] = {
							2033865, -- [1]
							2033869, -- [2]
							2033870, -- [3]
							2033871, -- [4]
							2033872, -- [5]
							2033873, -- [6]
							2033874, -- [7]
							2033875, -- [8]
							2033876, -- [9]
							2033866, -- [10]
							2033867, -- [11]
							2033868, -- [12]
						},
					}, -- [4]
					{
						["offsetX"] = 2063,
						["textureHeight"] = 727,
						["textureWidth"] = 913,
						["offsetY"] = 517,
						["fileDataIDs"] = {
							2033877, -- [1]
							2033881, -- [2]
							2033882, -- [3]
							2033883, -- [4]
							2033884, -- [5]
							2033885, -- [6]
							2033886, -- [7]
							2033887, -- [8]
							2033888, -- [9]
							2033878, -- [10]
							2033879, -- [11]
							2033880, -- [12]
						},
					}, -- [5]
					{
						["offsetX"] = 1880,
						["textureHeight"] = 835,
						["textureWidth"] = 969,
						["offsetY"] = 859,
						["fileDataIDs"] = {
							2033889, -- [1]
							2033897, -- [2]
							2033898, -- [3]
							2033899, -- [4]
							2033900, -- [5]
							2033901, -- [6]
							2033902, -- [7]
							2033903, -- [8]
							2033904, -- [9]
							2033890, -- [10]
							2033891, -- [11]
							2033892, -- [12]
							2033893, -- [13]
							2033894, -- [14]
							2033895, -- [15]
							2033896, -- [16]
						},
					}, -- [6]
					{
						["offsetX"] = 807,
						["textureHeight"] = 688,
						["textureWidth"] = 926,
						["offsetY"] = 1801,
						["fileDataIDs"] = {
							2033905, -- [1]
							2033909, -- [2]
							2033910, -- [3]
							2033911, -- [4]
							2033912, -- [5]
							2033913, -- [6]
							2033914, -- [7]
							2033915, -- [8]
							2033916, -- [9]
							2033906, -- [10]
							2033907, -- [11]
							2033908, -- [12]
						},
					}, -- [7]
					{
						["offsetX"] = 1579,
						["textureHeight"] = 966,
						["textureWidth"] = 915,
						["offsetY"] = 220,
						["fileDataIDs"] = {
							2033933, -- [1]
							2033941, -- [2]
							2033942, -- [3]
							2033943, -- [4]
							2033944, -- [5]
							2033945, -- [6]
							2033946, -- [7]
							2033947, -- [8]
							2033948, -- [9]
							2033934, -- [10]
							2033935, -- [11]
							2033936, -- [12]
							2033937, -- [13]
							2033938, -- [14]
							2033939, -- [15]
							2033940, -- [16]
						},
					}, -- [8]
					{
						["offsetX"] = 1362,
						["textureHeight"] = 542,
						["textureWidth"] = 794,
						["offsetY"] = 2018,
						["fileDataIDs"] = {
							2033949, -- [1]
							2033953, -- [2]
							2033954, -- [3]
							2033955, -- [4]
							2033956, -- [5]
							2033957, -- [6]
							2033958, -- [7]
							2033959, -- [8]
							2033960, -- [9]
							2033950, -- [10]
							2033951, -- [11]
							2033952, -- [12]
						},
					}, -- [9]
					{
						["offsetX"] = 1180,
						["textureHeight"] = 856,
						["textureWidth"] = 666,
						["offsetY"] = 1255,
						["fileDataIDs"] = {
							2033961, -- [1]
							2033965, -- [2]
							2033966, -- [3]
							2033967, -- [4]
							2033968, -- [5]
							2033969, -- [6]
							2033970, -- [7]
							2033971, -- [8]
							2033972, -- [9]
							2033962, -- [10]
							2033963, -- [11]
							2033964, -- [12]
						},
					}, -- [10]
					{
						["offsetX"] = 739,
						["textureHeight"] = 816,
						["textureWidth"] = 769,
						["offsetY"] = 1332,
						["fileDataIDs"] = {
							2033973, -- [1]
							2033981, -- [2]
							2033982, -- [3]
							2033983, -- [4]
							2033984, -- [5]
							2033985, -- [6]
							2033986, -- [7]
							2033987, -- [8]
							2033988, -- [9]
							2033974, -- [10]
							2033975, -- [11]
							2033976, -- [12]
							2033977, -- [13]
							2033978, -- [14]
							2033979, -- [15]
							2033980, -- [16]
						},
					}, -- [11]
					{
						["offsetX"] = 576,
						["textureHeight"] = 703,
						["textureWidth"] = 1086,
						["offsetY"] = 902,
						["fileDataIDs"] = {
							2033989, -- [1]
							2033996, -- [2]
							2033997, -- [3]
							2033998, -- [4]
							2033999, -- [5]
							2034000, -- [6]
							2034001, -- [7]
							2034002, -- [8]
							2034003, -- [9]
							2033990, -- [10]
							2033991, -- [11]
							2033992, -- [12]
							2033993, -- [13]
							2033994, -- [14]
							2033995, -- [15]
						},
					}, -- [12]
					{
						["offsetX"] = 1733,
						["textureHeight"] = 843,
						["textureWidth"] = 1223,
						["offsetY"] = 0,
						["fileDataIDs"] = {
							2034004, -- [1]
							2034015, -- [2]
							2034017, -- [3]
							2034018, -- [4]
							2034019, -- [5]
							2034020, -- [6]
							2034021, -- [7]
							2034022, -- [8]
							2034023, -- [9]
							2034005, -- [10]
							2034006, -- [11]
							2034007, -- [12]
							2034008, -- [13]
							2034009, -- [14]
							2034010, -- [15]
							2034011, -- [16]
							2034012, -- [17]
							2034013, -- [18]
							2034014, -- [19]
							2034016, -- [20]
						},
					}, -- [13]
				},
			---------------------------
				
			}

		}
	}

	defaults.global.overlayData.Hyjal_terrain1 = defaults.global.overlayData.Hyjal
	defaults.global.overlayData.Uldum_terrain1 = defaults.global.overlayData.Uldum
	defaults.global.overlayData.Gilneas_terrain1 = defaults.global.overlayData.Gilneas
	defaults.global.overlayData.Gilneas_terrain2 = defaults.global.overlayData.Gilneas
	defaults.global.overlayData.TheLostIsles_terrain1 = defaults.global.overlayData.TheLostIsles
	defaults.global.overlayData.TheLostIsles_terrain2 = defaults.global.overlayData.TheLostIsles
	defaults.global.overlayData.TwilightHighlands_terrain1 = defaults.global.overlayData.TwilightHighlands
	defaults.global.overlayData.BlastedLands_terrain1 = defaults.global.overlayData.BlastedLands	

    local function ShouldShowOriginalTexture(mapId)
        if (mapId == 81 or mapId == 18 or mapId == 14)
		and UnitLevel("player") >= 110 then
            return true
        end
    end
    
	local function FindTilesFrame()
		local allMapFrames = {WorldMapFrame.ScrollContainer.Child:GetChildren()}
		for i = 1, #allMapFrames do
			local frame = allMapFrames[i]
			if frame.detailTilePool then
				return frame 
			end
		end
	end
	local db
	
	C_MapExplorationInfo.GetExploredMapTextures_org = C_MapExplorationInfo.GetExploredMapTextures
	
	C_MapExplorationInfo.GetExploredMapTextures = function(mapId)
		local result = C_MapExplorationInfo.GetExploredMapTextures_org(mapId)
 
        if ShouldShowOriginalTexture(mapId) then
            return result
        end
        
        local isBlizzard = string.find(debugstack(), "MapExplorationDataProvider") ~= nil
    
        if isBlizzard then
            if result then
                return result
            else
                return {}
            end
        end
		
		if not DugisGuideViewer:UserSetting(DGV_REMOVEMAPFOG) 
		or DugisGuideViewer.mapsterloaded 
		or not MOD.GuideOn 
		or not DugisGuideViewer:IsBigMap(mapId) --for old maps we don't make any changes as we have stored old overrides
		then
			return result
		end
		
		result = result or {}
		
		if db and db.global.overlayData then
			if db.global.overlayData[mapId] then
				local internalOverlayData = db.global.overlayData[mapId]
				for i=1, #internalOverlayData do
					if not result[i] then
						result[i] = internalOverlayData[i]
									
						result[i]["hitRect"] = {
							["top"] = 0,
							["right"] = 0,
							["left"] = 0,
							["bottom"] = 0,
						}
						result[i]["isShownByMouseOver"] = false
					end
				end
			end
		end
		
		return result
	end
	
	--[[Returns:
		{
			mapDirectory = "",
			texData = {
				[mapName1] = 09812341,
				[mapName2] = 98745632
			}
		}
	]]
	local function GetCurrentMapOverlayData(mapId)
		local result = {texData = {}}
        
        if not mapId then
            return result
        end
		
		--For new maps we use another mechanism - overriden GetExploredMapTextures function
		if DugisGuideViewer:IsBigMap(mapId) then
			return result
		end
		
		local mapInfo = DugisGuideViewer.GetMapInfo(mapId)
		
		if not mapInfo then
			return
		end
		
		local isMicroDungeon = (mapInfo.mapType == Enum.UIMapType.Micro)
		local _, _, mapName = HBDMigrate:GetLegacyMapInfo(mapId)
		
		if not mapName then
			return result
		end
		
		local mapDirectory
		if isMicroDungeon then
			--todo: reimplement microdungeons
			return result
		else
			mapDirectory = "Interface\\Worldmap\\"..mapName.."\\"
		end

		if db == nil then
			return result
		end
		
		if db.global.overlayData[mapName] == nil then
			db.global.overlayData[mapName] = {}
		end
		
		result = {texData = LuaUtils:clone(db.global.overlayData[mapName] or {})}
		result.mapDirectory = mapDirectory
		return result
	end
	
	local function HarvestCurrentMapOverlayInfo()
		local exploredMaps = C_MapExplorationInfo.GetExploredMapTextures_org(WorldMapFrame:GetMapID())
		
		if exploredMaps and DugisGuideViewer:IsBigMap(WorldMapFrame:GetMapID()) then
			if not DataExport then
				DataExport = {}
			end
			
			--Currently displayed map
			local currentMapId = WorldMapFrame:GetMapID()
			
			if not DataExport[currentMapId] then
				DataExport[currentMapId] = {}
			end
		
			if exploredMaps then
				for i=1, #exploredMaps do
					local exploredMap = LuaUtils:clone(exploredMaps[i])
					exploredMap.hitRect = nil
					exploredMap.isShownByMouseOver = nil
					DataExport[currentMapId][i] = exploredMap
				end
			end
		end
	end
	
	local overlayTextures  = {}
	overlayTexturesGPS  = {}    
    local bigOverlays = {}

	function OverrideMapOverlaysUniversal(forWMap)
		if db == nil then
			return
		end
        
        LuaUtils:foreach(bigOverlays, function(v)
            v:Hide()
        end)
	 
		local discoveredOverlayData = {}
		
		local removeFogForGPSArrow
		
		if DugisGuideViewer.Modules.GPSArrowModule then
			removeFogForGPSArrow = DugisGuideViewer.Modules.GPSArrowModule.Options.removeFog
		end

		if (not DugisGuideViewer:UserSetting(DGV_REMOVEMAPFOG) or DugisGuideViewer.mapsterloaded or not MOD.GuideOn) and #overlayTextures==0 then
			return
		end

	  if forWMap then
		for i = 1, #overlayTextures  do
			overlayTextures[i]:Hide()
		end
	  else
		for i = 1, #overlayTexturesGPS  do
			if type(overlayTexturesGPS[i]) == "table" then
				overlayTexturesGPS[i]:Hide()
			end
		end
	  end
		
        if ShouldShowOriginalTexture((forWMap and WorldMapFrame:GetMapID()) or DugisGuideViewer.Modules.GPSArrowModule.GetMapIdForGPSMap()) then
            return
        end        
	 
		if forWMap then
		wipe(overlayTextures)
		else
		wipe(overlayTexturesGPS)
		end

		local itemIndex = 1
		local item = _G[format("WorldMapOverlay%s", itemIndex)]
		while item do
		  if forWMap then
			tinsert(overlayTextures, item)
		  else
			tinsert(overlayTexturesGPS, item:GetTexture())
		  end
			itemIndex = itemIndex + 1
		    item = _G[format("WorldMapOverlay%s", itemIndex)]
		end
		
		if harvestingDataMode then
			HarvestCurrentMapOverlayInfo()
		end
		
		local texInfo
		
		if forWMap then
			texInfo = GetCurrentMapOverlayData(WorldMapFrame:GetMapID())
		else
			texInfo = GetCurrentMapOverlayData(DugisGuideViewer.Modules.GPSArrowModule.GetMapIdForGPSMap())
		end

        ------------------------------------------------------
        -- ONLY BIG MAPS  ------------------------------------
        ------------------------------------------------------
        local tilesFrame = FindTilesFrame()
        local mapID = WorldMapFrame:GetMapID();
         
        if DugisGuideViewer:IsBigMap(mapID) then
            local exploredMapTextures = C_MapExplorationInfo.GetExploredMapTextures(mapID);
            if exploredMapTextures then
                local layerIndex = WorldMapFrame:GetCanvasContainer():GetCurrentLayerIndex();
                local layers = C_Map.GetMapArtLayers(mapID);
                local layerInfo = layers[layerIndex];
                local TILE_SIZE_WIDTH = layerInfo.tileWidth;
                local TILE_SIZE_HEIGHT = layerInfo.tileHeight;
                local textureNumber =  0
                for i, exploredTextureInfo in ipairs(exploredMapTextures) do
                    local numTexturesWide = ceil(exploredTextureInfo.textureWidth/TILE_SIZE_WIDTH);
                    local numTexturesTall = ceil(exploredTextureInfo.textureHeight/TILE_SIZE_HEIGHT);
                    local texturePixelWidth, textureFileWidth, texturePixelHeight, textureFileHeight;
                    for j = 1, numTexturesTall do
                        
                        if ( j < numTexturesTall ) then
                            texturePixelHeight = TILE_SIZE_HEIGHT;
                            textureFileHeight = TILE_SIZE_HEIGHT;
                        else
                            texturePixelHeight = mod(exploredTextureInfo.textureHeight, TILE_SIZE_HEIGHT);
                            if ( texturePixelHeight == 0 ) then
                                texturePixelHeight = TILE_SIZE_HEIGHT;
                            end
                            textureFileHeight = 16;
                            while(textureFileHeight < texturePixelHeight) do
                                textureFileHeight = textureFileHeight * 2;
                            end
                        end
                        for k = 1, numTexturesWide do
                          textureNumber = textureNumber + 1
                            local texture =  bigOverlays[textureNumber]
                            if not texture then
                                 texture = tilesFrame:CreateTexture(nil, "ARTWORK")   
                            end 
                            
                            bigOverlays[textureNumber] = texture
                            
                            if ( k < numTexturesWide ) then
                                texturePixelWidth = TILE_SIZE_WIDTH;
                                textureFileWidth = TILE_SIZE_WIDTH;
                            else
                                texturePixelWidth = mod(exploredTextureInfo.textureWidth, TILE_SIZE_WIDTH);
                                if ( texturePixelWidth == 0 ) then
                                    texturePixelWidth = TILE_SIZE_WIDTH;
                                end
                                textureFileWidth = 16;
                                while(textureFileWidth < texturePixelWidth) do
                                    textureFileWidth = textureFileWidth * 2;
                                end
                            end
                            texture:SetWidth(texturePixelWidth);
                            texture:SetHeight(texturePixelHeight);
                            texture:SetTexCoord(0, texturePixelWidth/textureFileWidth, 0, texturePixelHeight/textureFileHeight);
                            texture:SetPoint("TOPLEFT", exploredTextureInfo.offsetX + (TILE_SIZE_WIDTH * (k-1)), -(exploredTextureInfo.offsetY + (TILE_SIZE_HEIGHT * (j - 1))));
                            texture:SetTexture(exploredTextureInfo.fileDataIDs[((j - 1) * numTexturesWide) + k], nil, nil, "TRILINEAR");
                            texture:SetVertexColor(0.5, 0.5, 0.5)
                            if exploredTextureInfo.isShownByMouseOver then
                                -- keep track of the textures to show by mouseover
                                texture:SetDrawLayer("ARTWORK", -7);
                                texture:Hide();
                                local highlightRect = self.highlightRectPool:Acquire();
                                highlightRect:SetSize(exploredTextureInfo.hitRect.right - exploredTextureInfo.hitRect.left, exploredTextureInfo.hitRect.bottom - exploredTextureInfo.hitRect.top);
                                highlightRect:SetPoint("TOPLEFT", exploredTextureInfo.hitRect.left, -exploredTextureInfo.hitRect.top);
                                highlightRect.index = i;
                                highlightRect.texture = texture;
                            else
                                texture:SetDrawLayer("ARTWORK", -7);
                                texture:Show();
                            end
                        end
                    end
                end
            end
                        
			return
		end
        
        
        ------------------------------------------------------
        --ONLY SMALL MAPS ------------------------------------
        ------------------------------------------------------
		local textureCount = 0
		local numOverlayTextures  = #overlayTextures
		local texturePixelWidth, textureFileWidth, texturePixelHeight, textureFileHeight
		
		for texName, texData in pairs(texInfo.texData) do
			local texturePath = texInfo.mapDirectory .. texName
			local textureWidth, textureHeight, offsetX, offsetY = mod(texData, 2^10), mod(floor(texData / 2^10), 2^10), mod(floor(texData / 2^20), 2^10), floor(texData / 2^30)

			local numTexturesWide = ceil(textureWidth / 256)
			local numTexturesTall = ceil(textureHeight / 256)
			local neededTextures = textureCount + (numTexturesWide * numTexturesTall)
			if neededTextures > numOverlayTextures  then
				for j = numOverlayTextures  + 1, neededTextures do
				  if forWMap then
					local texture = tilesFrame:CreateTexture(format("DugiWorldMapOverlay%s", j), "ARTWORK")
					tinsert(overlayTextures , texture)
				  else
					if GPSArrow then
						local textureGPS = GPSArrow:CreateTexture(format("DugiWorldMapOverlayGPS%s", j), "ARTWORK")
						tinsert(overlayTexturesGPS , textureGPS)
					end
				  end
				end
				numOverlayTextures  = neededTextures
			end
            
			for j = 1, numTexturesTall do
				if j < numTexturesTall then
					texturePixelHeight = 256
					textureFileHeight = 256
				else
					texturePixelHeight = mod(textureHeight, 256)
					if texturePixelHeight == 0 then
						texturePixelHeight = 256
					end
					textureFileHeight = 16
					while textureFileHeight < texturePixelHeight do
						textureFileHeight = textureFileHeight * 2
					end
				end
                
				for k = 1, numTexturesWide do
                    textureCount = textureCount + 1
                    local texture
                    local textureGPS

                    if k < numTexturesWide then
                        texturePixelWidth = 256
                        textureFileWidth = 256
                    else
                        texturePixelWidth = mod(textureWidth, 256)
                        if texturePixelWidth == 0 then
                            texturePixelWidth = 256
                        end
                        textureFileWidth = 16
                        while textureFileWidth < texturePixelWidth do
                            textureFileWidth = textureFileWidth * 2
                        end
                    end

                    if forWMap then
                        texture = overlayTextures [textureCount]

                        texture:SetWidth(texturePixelWidth)
                        texture:SetHeight(texturePixelHeight)
                        texture:SetTexCoord(0, texturePixelWidth / textureFileWidth, 0, texturePixelHeight / textureFileHeight)
                        texture:ClearAllPoints()
                        texture:SetPoint("TOPLEFT", (offsetX + (256 * (k-1))), -(offsetY + (256 * (j - 1))))
                        texture:SetTexture(format(texturePath.."%d", ((j - 1) * numTexturesWide) + k))
                    else
                        textureGPS = overlayTexturesGPS[textureCount]
                        if DugisGuideViewer.Modules.GPSArrowModule then
                            if type(textureGPS) ~= "table" then
                                overlayTexturesGPS[textureCount] = GPSArrow:CreateTexture(format("DugiWorldMapOverlayGPS%s", textureCount), "ARTWORK")
                                overlayTexturesGPS[textureCount]:SetTexture(textureGPS)
                                textureGPS = overlayTexturesGPS[textureCount]

                                local factor = DugisGuideViewer.Modules.GPSArrowModule.GetMapOverlaysFactor()
                                textureGPS:SetWidth(texturePixelWidth * factor)
                                textureGPS:SetHeight(texturePixelHeight * factor)
                                textureGPS:SetTexCoord(0, texturePixelWidth / textureFileWidth, 0, texturePixelHeight / textureFileHeight)
                                textureGPS:ClearAllPoints()
                                local x = (offsetX + (256  * (k-1)))
                                local y = -(offsetY + (256 * (j-1))) 
                                textureGPS:SetPoint("TOPLEFT", _G["GPSArrow"..1]:GetParent(), x * factor, y * factor)
                                textureGPS:SetTexture(format(texturePath.."%d", ((j - 1) * numTexturesWide) + k))

                                textureGPS.orgX = x
                                textureGPS.orgY = y
                                textureGPS.orgW = texturePixelWidth
                                textureGPS.orgH = texturePixelHeight
                            end
                        end
                    end
                      
                    if DugisGuideViewer:UserSetting(DGV_REMOVEMAPFOG) or not DugisGuideViewer.mapsterloaded and MOD.GuideOn then
                        if forWMap then
                            texture:SetVertexColor(0.5, 0.5, 0.5)
                            texture:SetDrawLayer("ARTWORK", 1)
                            texture:Show()
                        else
                            if type(textureGPS) == "table" then
                                textureGPS:SetVertexColor(.8, .8, .8)
                                textureGPS:SetDrawLayer("ARTWORK", 1)
                                textureGPS:Show()
                            end
                        end
                    else
                        if forWMap then
                            texture:Show()
                        else
                            if type(textureGPS) == "table" then
                                textureGPS:Show()
                            end
                        end
                    end
				end
			end
		end
		
	  if forWMap then
		for i = textureCount+1, numOverlayTextures  do
			overlayTextures [i]:Hide()
		end	
	  else
		for i = textureCount+1, numOverlayTextures  do
			if type(overlayTexturesGPS[i]) == "table" then
				overlayTexturesGPS[i]:Hide()
			end
		end
      end
		wipe(discoveredOverlayData)

		if not DugisGuideViewer:UserSetting(DGV_REMOVEMAPFOG) or not MOD.GuideOn or DugisGuideViewer.mapsterloaded then
		  if forWMap then
			wipe(overlayTextures)
		  else
			wipe(overlayTexturesGPS)
		  end
		end
	end
	
	function OverrideMapOverlays()
		OverrideMapOverlaysUniversal(true)
		OverrideMapOverlaysUniversal(false)
	end

	-- Code courtesy ckknight
	function MOD:GetCurrentCursorPosition(frame)
	local x, y = GetCursorPosition()
	local left, top = frame:GetLeft(), frame:GetTop()
	local width = frame:GetWidth()
	local height = frame:GetHeight()
	local scale = frame:GetEffectiveScale()
	local cx = (x/scale - left) / width
	local cy = (top - y/scale) / height

		if cx < 0 or cx > 1 or cy < 0 or cy > 1 then
			return nil, nil
	end
	return cx, cy
	end

	local formatCoords = "%.2f, %.2f"


	local UpdateWorldMapFrame = MOD.NoOp
	function MOD:InitializeMapOverlays()
		db = LibStub("AceDB-3.0"):New("MapOverlaysDugis", defaults)
		
		-- todo: find replacement
		--hooksecurefunc("WorldMapFrame_Update", UpdateWorldMapFrame);
		hooksecurefunc(WorldMapFrame, "OnMapChanged", UpdateWorldMapFrame);
		
	end

	function MOD:MapHasOverlays()
		local overlayMap = db.global.overlayData[WorldMapFrame:GetMapID()]
		return overlayMap and next(overlayMap)
	end

	function MapOverlays:Load()
		UpdateWorldMapFrame = function()
			if not MOD.CoordsFrame then
				MOD.CoordsFrame = CreateFrame("Frame", nil, WorldMapFrame)
				MOD.CoordsFrame.Player = MOD.CoordsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				MOD.CoordsFrame.Cursor = MOD.CoordsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				MOD.CoordsFrame:SetScript("OnUpdate", function()
					if MOD:UserSetting(DGV_DISPLAYMAPCOORDINATES)
						and not DugisGuideViewer.mapsterloaded
						and not DugisGuideViewer.tomtomloaded
					then
						local _, _, x, y  = DugisGuideViewer:GetUnitPosition("player", true)
						if not x or not y then
							MOD.CoordsFrame.Player:SetText("|cffffd200玩家:|r ---")
						else
							MOD.CoordsFrame.Player:SetFormattedText("|cffffd200玩家:|r %s", formatCoords:format(x*100, y*100))
						end

						if WorldMapFrame.ScrollContainer.Child:GetLeft() then --prevents error on early load
							local cX, cY = MOD:GetCurrentCursorPosition(WorldMapFrame.ScrollContainer.Child)
							if not cX or not cY then
								MOD.CoordsFrame.Cursor:SetText("|cffffd200游標:|r ---")
							else
								MOD.CoordsFrame.Cursor:SetFormattedText("|cffffd200游標:|r %s", formatCoords:format(cX*100, cY*100))
							end
						end
                        MOD.CoordsFrame:Show()
					else
						MOD.CoordsFrame:Hide()
					end

					if DugisGuideViewer.tomtomloaded
						or MOD:UserSetting(DGV_DISPLAYMAPCOORDINATES)
					then
					
					end
				end)
				MOD.CoordsFrame:Show()
			end

			MOD.CoordsFrame.Player:ClearAllPoints()
			MOD.CoordsFrame.Cursor:ClearAllPoints()
			
			if not WorldMapFrame:IsMaximized() then
				MOD.CoordsFrame.Player:SetPoint("TOPLEFT", WorldMapFrame, "BOTTOMLEFT", 4, -5)
				MOD.CoordsFrame.Cursor:SetPoint("TOPLEFT", WorldMapFrame, "BOTTOMLEFT", 140, -5)
	     	else
				MOD.CoordsFrame.Player:SetPoint("TOPLEFT", WorldMapFrame, "BOTTOM", -120, -30)
				MOD.CoordsFrame.Cursor:SetPoint("TOPLEFT", WorldMapFrame, "BOTTOM", 20, -30)
			end
            
			OverrideMapOverlays()
		end
		MOD:InitializeMapOverlays()
        
        UpdateWorldMapFrame()
	end

	function MapOverlays:Unload()
		OverrideMapOverlays()
		UpdateWorldMapFrame = MOD.NoOp
		if MOD.CoordsFrame then MOD.CoordsFrame:Hide() end
	end
end
