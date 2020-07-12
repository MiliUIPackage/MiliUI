--Initialize local variables--
local mp = {}
mp.version = "8.2.0.0"
mp.isCustom = false
mp.frame = nil
mp.model = nil
mp.source = nil
mp.button = {}
mp.button.data = {}
mp.i = "item:"
mp.s = "spell:"
mp.e = "enchant:"
mp.p = "battlepet:"
mp.f = "garrfollower:"
--Global to local variables--
local pairs = pairs
local strmatch = string.match
local tonumber = tonumber
local format = string.format

DressUpMountLink = function() return end
DressUpBattlePetLink = function() return end

--Functions--
local function ShowModel(modelName, displayId, owned, battlePet)
	if not displayId then return end
	mp.frame = nil
	mp.model = nil
	if SideDressUpFrame.parentFrame and SideDressUpFrame.parentFrame:IsShown() then
		--if battlePet then return end--let blizzard handle display of battle pets
		mp.frame, mp.model = SideDressUpFrame, SideDressUpModel
		mp.frame.mode = "battlepet"
	else
		mp.frame, mp.model = ModelPiqueFrame, ModelPiqueModel
		ModelPiqueFrameDescriptionText:SetText(modelName.."|n"..owned)
	end
	if mp.frame == ModelPiqueFrame then
		SetPortraitTexture(ModelPiqueFramePortrait, "player")
	end
	local camera --= mp.cameraTable[displayId]
	if camera then
		mp.model:SetModelScale(camera.S)
		mp.model:SetPosition(camera.X, camera.Y, camera.Z)
		mp.model:SetDisplayInfo(displayId)
		mp.isCustom = true
	end
	mp.model:SetDisplayInfo(displayId)
	if not mp.frame:IsShown() then
		ShowUIPanel(mp.frame)
	end
end

local function GetDisplayID(link)
	if not link then return end
	local item = tonumber(strmatch(link, mp.i.."(%d+)"))
	local spellId = tonumber(strmatch(link, mp.s.."(%d+)"))
	local enchant = tonumber(strmatch(link, mp.e.."(%d+)"))
	local battlePet = tonumber(strmatch(link, mp.p.."(%d+)"))
	local follower = tonumber(strmatch(link, mp.f.."(%d+)"))
	local modelName
	local displayId
	local owned = ""
	mp.source = ""
	if item then
		local itemData
		for k,v in pairs(mp.itemTable) do
		itemData = v[item]
			if itemData then
				if k <= 2 then
					spellId = mp.itemToSpellTable[item]
					if not spellId and itemData then 
						for k,v in pairs(mp.spellTable) do
							if v == itemData and k ~= item then
								spellId = k
							end
						end
					end
				elseif k == 3 then
					local info = C_Garrison.GetFollowerInfo(itemData)
					modelName = info.name
					displayId = info.displayID
				elseif k == 4 then
					mp.button.num = 1
					mp.button.data = itemData
					mp.button.numMax = #itemData
					if mp.button.numMax > 1 then
						ModelPique_Button:SetText(format("%s/%s%s", mp.button.num, mp.button.numMax, mp.button.data[mp.button.num][3] or ""))
						ModelPique_Button:Show()
					end
					return ShowModel(GetDisplayID(format("%s%s", mp.button.data[mp.button.num][2] or mp.s, mp.button.data[mp.button.num][1])))
				elseif k == 5 then--toy
					spellId = mp.itemToSpellTable[item]
					if not spellId and itemData then 
						for k,v in pairs(mp.spellTable) do
							if v == itemData and k ~= item then
								spellId = k
							end
						end
					end
				end
				if modelName and displayId then
					return modelName, displayId, owned
				end
			end
		end
	end
	if follower then
		modelName = C_Garrison.GetFollowerInfo(follower).name
		displayId = C_Garrison.GetFollowerInfo(follower).displayID
		return modelName, displayId, owned
	end
	if battlePet then
		modelName, _, _, _, _, _, _, _, _, _, _, displayId = C_PetJournal.GetPetInfoBySpeciesID(battlePet)
	end
	if not modelName then
		modelName = GetSpellInfo(spellId or enchant) or strmatch(link,"%[(.*)%]")
	end
	if not displayId then
		displayId = mp.spellTable[spellId or enchant] or mp.petTable[battlePet]
	end
	return modelName, displayId, owned, battlePet
end

function ModelPique_Button_OnClick(self, button, down)
	mp.button.num = mp.button.num < mp.button.numMax and mp.button.num + 1 or 1
	ModelPique_Button:SetText(format("%s/%s%s", mp.button.num, mp.button.numMax, mp.button.data[mp.button.num][3] or ""))
	return ShowModel(GetDisplayID(format("%s%s", mp.button.data[mp.button.num][2] or mp.s, mp.button.data[mp.button.num][1])))
end

function ModelPiqueFrame_OnLoad()
	ModelPiqueFrameDescriptionText:SetPoint("CENTER", "ModelPiqueFrameTitleText", "BOTTOM", "0", "-22")
	ModelPiqueFrameDescriptionText:SetFontObject(GameFontNormal)
	ModelPiqueFrameTitleText:SetText(format("%s%s", "坐騎/戰寵模組預覽 v", mp.version))
	SetDressUpBackground(ModelPiqueFrame, "Pet")
end

function ModelPiqueFrameTooltipFrame_OnEnter(self)
	--[[if source and source ~= "" then
		GameTooltip:SetOwner(ModelPiqueFrameTooltipFrame, "ANCHOR_NONE")
		GameTooltip:SetText(source)
		GameTooltip:SetPoint("TOPLEFT", ModelPiqueFrameTooltipFrame, "TOPRIGHT", 0, 0)
		GameTooltip:Show()
	end--]]
end

local origHandleModifiedItemClick = HandleModifiedItemClick

function HandleModifiedItemClick(link)
	if link and IsModifiedClick("DRESSUP") and not IsDressableItem(link) then
		if mp.isCustom then
			mp.model:SetModelScale(1)
			mp.model:SetPosition(0,0,0)
			mp.isCustom = false
		end
		ModelPique_Button:Hide()
		ShowModel(GetDisplayID(link))
	end
	return origHandleModifiedItemClick(link)
end

--Item Data table--
mp.itemTable = {
[1] = {
------------------------------------------
--**************************************--
--*************** MOUNTS ***************--
--**************************************--
------------------------------------------
--1.11.1 and earlier
[18796]=14573,--Swift Brown Wolf
[21176]=15676,--Black Qiraji Battle Tank
[12302]=9695,--Ancient Frostsaber
[12303]=9991,--Black Nightsaber
[12330]=2326,--Red Wolf
[12351]=1166,--Winter Wolf
[12353]=2410,--White Stallion
[12354]=2408,--Palomino
[13086]=10426,--Winterspring Frostsaber
[13317]=6471,--Ivory Raptor
[13326]=9474,--White Mechanostrider Mod B
[13327]=10666,--Icy Blue Mechanostrider Mod A
[13328]=2784,--Black Ram
[13329]=2787,--Frost Ram
[13334]=10720,--Green Skeletal Warhorse
[13335]=10718,--Rivendare's Deathcharger
[15292]=12245,--Green Kodo
[15293]=12242,--Teal Kodo
[18766]=14331,--Swift Frostsaber
[18767]=14332,--Swift Mistsaber
[18772]=14374,--Swift Green Mechanostrider
[18773]=14376,--Swift White Mechanostrider
[18774]=14377,--Swift Yellow Mechanostrider
[18776]=14582,--Swift Palomino
[18777]=14583,--Swift Brown Steed
[18778]=14338,--Swift White Steed
[18785]=14346,--Swift White Ram
[18786]=14347,--Swift Brown Ram
[18787]=14576,--Swift Gray Ram
[18788]=14339,--Swift Blue Raptor
[18789]=14344,--Swift Olive Raptor
[18790]=14342,--Swift Orange Raptor
[18791]=10721,--Purple Skeletal Warhorse
[18793]=14349,--Great White Kodo
[18794]=14578,--Great Brown Kodo
[18795]=14579,--Great Gray Kodo
[8586]=6469,--Mottled Red Raptor
[18797]=14575,--Swift Timber Wolf
[18798]=14574,--Swift Gray Wolf
[18902]=14632,--Swift Stormsaber
[19029]=14776,--Frostwolf Howler
[19030]=14777,--Stormpike Battle Charger
[19872]=15289,--Swift Razzashi Raptor
[19902]=15290,--Swift Zulian Tiger
[21218]=15672,--Blue Qiraji Battle Tank
[21321]=15681,--Red Qiraji Battle Tank
[21323]=15679,--Green Qiraji Battle Tank
[21324]=15680,--Yellow Qiraji Battle Tank
[8591]=6472,--Turquoise Raptor
[1132]=247,--Timber Wolf
[2414]=2409,--Pinto
[5655]=2405,--Chestnut Mare
[5656]=2404,--Brown Horse
[5665]=2327,--Dire Wolf
[5668]=2328,--Brown Wolf
[5864]=2736,--Gray Ram
[5872]=2785,--Brown Ram
[5873]=2786,--White Ram
[8563]=9473,--Red Mechanostrider
[8588]=4806,--Emerald Raptor
[2411]=2402,--Black Stallion
[8592]=6473,--Violet Raptor
[8595]=6569,--Blue Mechanostrider
[8629]=6448,--Striped Nightsaber
[8631]=6080,--Striped Frostsaber
[8632]=6444,--Spotted Frostsaber
[13321]=10661,--Green Mechanostrider
[13322]=9476,--Unpainted Mechanostrider
[13331]=10670,--Red Skeletal Horse
[13332]=10671,--Blue Skeletal Horse
[13333]=10672,--Brown Skeletal Horse
[15277]=12246,--Gray Kodo
[15290]=11641,--Brown Kodo
--2.0
[23720]=17158,--Riding Turtle
--2.0.1
[25477]=17719,--Swift Red Wind Rider
[25532]=17722,--Swift Yellow Wind Rider
[25533]=17721,--Swift Purple Wind Rider
[25531]=17720,--Swift Green Wind Rider
[25470]=17697,--Golden Gryphon
[25471]=17694,--Ebon Gryphon
[25472]=17696,--Snowy Gryphon
[25474]=17699,--Tawny Wind Rider
[25475]=17700,--Blue Wind Rider
[25476]=17701,--Green Wind Rider
[28915]=21074,--Dark Riding Talbuk
[28936]=18697,--Swift Pink Hawkstrider
[29102]=19375,--Cobalt War Talbuk
[29103]=19377,--White War Talbuk
[29104]=19378,--Silver War Talbuk
[29105]=19376,--Tan War Talbuk
[29223]=19484,--Swift Green Hawkstrider
[29224]=19482,--Swift Purple Hawkstrider
[29227]=19375,--Cobalt War Talbuk
[29228]=19303,--Dark War Talbuk
[29229]=19378,--Silver War Talbuk
[29230]=19376,--Tan War Talbuk
[29231]=19377,--White War Talbuk
[29465]=14372,--Black Battlestrider
[29466]=14348,--Black War Kodo
[29467]=14577,--Black War Ram
[29468]=14337,--Black War Steed
[29469]=14334,--Black War Wolf
[29470]=10719,--Red Skeletal Warhorse
[29471]=14330,--Black War Tiger
[29472]=14388,--Black War Raptor
[29745]=19871,--Great Blue Elekk
[29746]=19873,--Great Green Elekk
[29747]=19872,--Great Purple Elekk
[30480]=19250,--Fiery Warhorse
[31829]=21073,--Cobalt Riding Talbuk
[31830]=21073,--Cobalt Riding Talbuk
[31831]=21075,--Silver Riding Talbuk
[31832]=21075,--Silver Riding Talbuk
[31833]=21077,--Tan Riding Talbuk
[31834]=21077,--Tan Riding Talbuk
[31835]=21076,--White Riding Talbuk
[31836]=21076,--White Riding Talbuk
[28481]=17063,--Brown Elekk
[28927]=18696,--Red Hawkstrider
[29220]=19480,--Blue Hawkstrider
[29221]=19478,--Black Hawkstrider
[29222]=19479,--Purple Hawkstrider
[29743]=19870,--Purple Elekk
[29744]=19869,--Gray Elekk
--2.1
[32319]=21156,--Blue Riding Nether Ray
[25473]=17759,--Swift Blue Gryphon
[25528]=17703,--Swift Green Gryphon
[25529]=17717,--Swift Purple Gryphon
[32314]=21152,--Green Riding Nether Ray
[32316]=21155,--Purple Riding Nether Ray
[32317]=21158,--Red Riding Nether Ray
[32318]=21157,--Silver Riding Nether Ray
[25527]=17718,--Swift Red Gryphon
[32857]=21520,--Onyx Netherwing Drake
[32858]=21521,--Azure Netherwing Drake
[32859]=21525,--Cobalt Netherwing Drake
[32860]=21523,--Purple Netherwing Drake
[32861]=21522,--Veridian Netherwing Drake
[32862]=21524,--Violet Netherwing Drake
[32768]=21473,--Raven Lord
--2.1.1
[32458]=17890,--Ashes of Al'ar
--2.1.2
[30609]=20344,--Swift Nether Drake
--2.2
[33977]=22350,--Swift Brewfest Ram
[33976]=22265,--Brewfest Ram
--2.2.2
[33182]=21939,--Swift Flying Broom
[33184]=21939,--Swift Magic Broom
[33176]=21939,--Flying Broom
--[33183]=,--Old Magic Broom
--2.3
[25596]=17890,--Peep the Phoenix Mount
[33809]=22464,--Amani War Bear
[33999]=22473,--Cenarion War Hippogryph
[34061]=22720,--Turbo-Charged Flying Machine
[34092]=22620,--Merciless Nether Drake
[34060]=22719,--Flying Machine
[34129]=20359,--Swift Warstrider
--2.4
[35513]=19483,--Swift White Hawkstrider
[35906]=23928,--Black War Elekk
--2.4.2
[37676]=24725,--Vengeful Nether Drake
--2.4.3
[43516]=27507,--Brutal Nether Drake
[37719]=24745,--Swift Zhevra
[37828]=24757,--Great Brewfest Kodo
[37012]=25159,--Headless Horseman's Mount
[43599]=27567,--Big Blizzard Bear
[37011]=21939,--Magic Broom
[39476]=24758,--Fresh Goblin Brewfest Hops
[39477]=22265,--Fresh Dwarven Brewfest Hops
--3.0.1
[41508]=25871,--Mechano-Hog
[44502]=25871,--Mechano-Hog(Recipe)
[40775]=28108,--Winged Steed of the Ebon Blade
--3.0.2
[44413]=25870,--Mekgineer's Chopper
[44503]=25870,--Mekgineer's Chopper(Recipe)
[44221]=17697,--Loaned Gryphon Reins
[44229]=17699,--Loaned Wind Rider Reins
[44168]=28045,--Time-Lost Proto-Drake
[43952]=27785,--Azure Drake
[43954]=27796,--Twilight Drake
[43955]=25835,--Red Drake
[43951]=25833,--Bronze Drake
[44151]=28041,--Blue Proto-Drake
[43953]=25832,--Blue Drake
[44178]=25836,--Albino Drake
[44558]=28060,--Magnificent Flying Carpet
[44689]=27913,--Armored Snowy Gryphon
[44690]=27914,--Armored Blue Wind Rider
[43986]=25831,--Black Drake
[44554]=28082,--Flying Carpet
[44223]=27818,--Black War Bear
[43956]=27247,--Black War Mammoth
[43961]=27242,--Grand Ice Mammoth
[43962]=28428,--White Polar Bear
[44077]=27245,--Black War Mammoth
[44080]=27246,--Ice Mammoth
[44086]=27239,--Grand Ice Mammoth
[43958]=27248,--Ice Mammoth
[44224]=27819,--Black War Bear
[44225]=27820,--Armored Brown Bear
[44226]=27821,--Armored Brown Bear
[44230]=27243,--Wooly Mammoth
[44231]=27244,--Wooly Mammoth
[44234]=27238,--Traveler's Tundra Mammoth
[44235]=27237,--Traveler's Tundra Mammoth
--3.0.3
[44160]=28044,--Red Proto-Drake
[44707]=28053,--Green Proto-Drake
[43959]=27241,--Grand Black War Mammoth
--3.0.8
[44175]=28042,--Plagued Proto-Drake
--3.0.9
[44164]=28040,--Black Proto-Drake
[44083]=27240,--Grand Black War Mammoth
--3.1
[46109]=29161,--Sea Turtle
[44843]=27525,--Blue Dragonhawk
[45693]=28890,--Mimiron's Head
[45725]=22471,--Argent Hippogryph
[44842]=28402,--Red Dragonhawk
[45125]=28912,--Stormwind Steed
[45586]=29258,--Ironforge Ram
[45589]=28571,--Gnomeregan Mechanostrider
[45590]=29255,--Exodar Elekk
[45591]=29256,--Darnassian Nightsaber
[45592]=29259,--Thunder Bluff Kodo
[45593]=29261,--Darkspear Raptor
[45595]=29260,--Orgrimmar Wolf
[45596]=29262,--Silvermoon Hawkstrider
[45597]=29257,--Forsaken Warhorse
[46101]=10718,--Blue Skeletal Warhorse
[46099]=207,--Black Wolf
[46100]=12241,--White Kodo
[46308]=29130,--Black Skeletal Horse
--3.1.1
[46171]=25593,--Furious Gladiator's Frost Wyrm
--3.1.2
[45802]=28954,--Rusted Proto-Drake
[46752]=29043,--Swift Gray Steed
[46744]=14333,--Swift Moonsaber
[46745]=28606,--Great Red Elekk
[46746]=28605,--White Skeletal Warhorse
[46743]=14343,--Swift Purple Raptor
[46748]=28612,--Swift Violet Ram
[46749]=14335,--Swift Burgundy Wolf
[46750]=28556,--Great Golden Kodo
[46751]=28607,--Swift Red Hawkstrider
[46747]=14375,--Turbostrider
--3.1.3
[45801]=28953,--Ironbound Proto-Drake
--3.2
[44177]=28043,--Violet Proto-Drake
[46813]=22474,--Silver Covenant Hippogryph
[46814]=29696,--Sunreaver Dragonhawk
[49286]=23647,--X-51 Nether-Rocket X-TREME
[46708]=25511,--Deadly Gladiator's Frost Wyrm
[49285]=23656,--X-51 Nether-Rocket
[46102]=29102,--Venomhide Ravasaur
[46815]=28888,--Quel'dorei Steed
[46816]=28889,--Sunreaver Hawkstrider
[47101]=29754,--Ochre Skeletal Warhorse
[47179]=28919,--Argent Charger
[47180]=28918,--Argent Warhorse
[49044]=29284,--Swift Alliance Steed
[49096]=29937,--Crusader's White Warhorse
[49098]=29938,--Crusader's Black Warhorse
[49282]=25335,--Big Battle Bear
[49284]=21974,--Swift Spectral Tiger
[49290]=29344,--Magic Rooster
[47100]=29755,--Striped Dawnsaber
[49283]=21973,--Spectral Tiger
--3.2.2
[49636]=30346,--Onyxian Drake
[49046]=29283,--Swift Horde Wolf
[49288]=30141,--Little Ivory Raptor Whistle
[49289]=30518,--Little White Stallion Bridle
--3.3
[50818]=31007,--Invincible
[50818]=31007,--Invincible(Recipe)
--3.3.2
[51954]=31156,--Bloodbathed Frostbrood Vanquisher
[50250]=30989,--Big Love Rocket
--3.3.3
[47840]=29794,--Relentless Gladiator's Frost Wyrm
[51955]=31154,--Icebound Frostbrood Vanquisher
[54797]=28063,--Frosty Flying Carpet
[54798]=28063,--Frosty Flying Carpet(Recipe)
[54069]=31803,--Blazing Hippogryph
[54860]=31992,--X-53 Touring Rocket
[52200]=25279,--Crimson Deathcharger
[54811]=31958,--Celestial Steed
--3.3.5
[54068]=31721,--Wooly White Rhino
--4.0.1
[65891]=35750,--Sandstone Drake
[67538]=35750,--Sandstone Drake(Recipe)
[63043]=35751,--Vitreous Stone Drake
[62900]=35551,--Volcanic Stone Drake
[62901]=35757,--Drake of the East Wind
[63039]=35754,--Drake of the West Wind
[63040]=35553,--Drake of the North Wind
[63041]=35755,--Drake of the South Wind
[63042]=35740,--Phosphorescent Stone Drake
[50435]=31047,--Wrathful Gladiator's Frost Wyrm
[63125]=37145,--Dark Phoenix
[64998]=37160,--Spectral Steed
[64999]=37159,--Spectral Wolf
[65356]=35754,--Drake of the West Wind
[63044]=35136,--Brown Riding Camel
[63045]=35134,--Tan Riding Camel
[63046]=35135,--Grey Riding Camel
[64883]=15672,--Ultramarine Qiraji Battle Tank
--4.0.3
[67151]=34955,--Subdued Seahorse
[54465]=34956,--Abyssal Seahorse
[68008]=37231,--Mottled Drake
[60954]=34410,--Fossilized Raptor
[62462]=35250,--Goblin Turbo-Trike
[62298]=36213,--Golden King
[67107]=37138,--Kor'kron Annihilator
[62461]=35249,--Goblin Trike
--4.1
[69747]=38261,--Amani Battle Bear
[69213]=38018,--Flameward Hippogryph
[69224]=38031,--Pureblood Fire Hawk
[68825]=37800,--Amani Dragonhawk
[68823]=14341,--Armored Razzashi Raptor
[68824]=37799,--Swift Zulian Panther
[69228]=38048,--Savage Raptor
[69846]=38260,--Winged Guardian
[69846]=38260,--Winged Guardian(Recipe)
--4.2
[69230]=38046,--Corrupted Fire Hawk
[71339]=38756,--Vicious Gladiator's Twilight Drake
[70909]=38668,--Vicious War Steed
[70910]=38607,--Vicious War Wolf
[71665]=38783,--Flametalon of Alysrazor
--4.3
[77067]=39561,--Blazing Drake
[77069]=39563,--Life-Binder's Handmaiden
[78919]=39229,--Experiment 12-B
[77068]=39562,--Twilight Harbinger
[71954]=38755,--Ruthless Gladiator's Twilight Drake
[74269]=31803,--Blazing Hippogryph
[76889]=39546,--Spectral Gryphon
[76902]=39547,--Spectral Wind Rider
[73839]=39095,--Swift Mountain Horse
[71718]=17011,--Swift Shorestrider
[72140]=1281,--Swift Forest Strider
[72145]=16992,--Swift Springstrider
[72146]=1961,--Swift Lovebird
[72575]=37204,--White Riding Camel
[73766]=39060,--Darkmoon Dancing Bear
[76755]=39530,--Tyrael's Charger
[78924]=40029,--Heart of the Aspects
[73838]=39096,--Mountain Horse
[72582]=38972,--Corrupted Hippogryph
--4.3.2
[79771]=40568,--Feldrake
--5.0.1
[83088]=42502,--Jade Panther
[83845]=42502,--Jade Panther(Recipe)
[79802]=40590,--Jade Cloud Serpent
[82453]=42185,--Jeweled Onyx Panther
[83877]=42185,--Jeweled Onyx Panther(Recipe)
[84101]=42703,--Grand Expedition Yak
[85429]=41991,--Golden Cloud Serpent
[85430]=41989,--Azure Cloud Serpent
[87768]=41990,--Onyx Cloud Serpent
[87769]=41592,--Crimson Cloud Serpent
[87771]=43689,--Heavenly Onyx Cloud Serpent
[87773]=43692,--Heavenly Crimson Cloud Serpent
[87774]=43693,--Heavenly Golden Cloud Serpent
[87777]=46087,--Astral Cloud Serpent
[87781]=43704,--Azure Riding Crane
[87782]=43705,--Golden Riding Crane
[87783]=43706,--Regal Riding Crane
[87788]=43711,--Grey Riding Yak
[87789]=43712,--Blonde Riding Yak
[89154]=44633,--Crimson Pandaren Phoenix
[89304]=43686,--Thundering August Cloud Serpent
[89305]=44759,--Green Shado-Pan Riding Tiger
[89306]=44757,--Red Shado-Pan Riding Tiger
[89307]=43900,--Blue Shado-Pan Riding Tiger
[89362]=44807,--Brown Riding Goat
[89390]=44837,--White Riding Goat
[89391]=44836,--Black Riding Goat
[89783]=45264,--Son of Galleon
[83087]=42499,--Ruby Panther
[83931]=42499,--Ruby Panther(Recipe)
[81354]=41711,--Azure Water Strider
[83089]=42501,--Sunstone Panther
[83830]=42501,--Sunstone Panther(Recipe)
[83090]=42500,--Sapphire Panther
[83932]=42500,--Sapphire Panther(Recipe)
[81559]=41903,--Pandaren Kite
[85666]=43562,--Thundering Jade Cloud Serpent
[89785]=45271,--Pandaren Kite
[85262]=43090,--Amber Scorpion
[83086]=42498,--Obsidian Nightwing
[87250]=43637,--Depleted-Kyparium Rocket
[87251]=43638,--Geosynchronous World Spinner
[89363]=44808,--Red Flying Cloud
[82811]=42352,--Great Red Dragon Turtle
[87801]=43722,--Great Green Dragon Turtle
[87802]=43723,--Great Black Dragon Turtle
[87803]=43724,--Great Blue Dragon Turtle
[87804]=43725,--Great Brown Dragon Turtle
[87805]=43726,--Great Purple Dragon Turtle
[85870]=43254,--Imperial Quilen
[82765]=42250,--Green Dragon Turtle
[87795]=43717,--Black Dragon Turtle
[87796]=43718,--Blue Dragon Turtle
[87797]=43719,--Brown Dragon Turtle
[87799]=43720,--Purple Dragon Turtle
[87800]=43721,--Red Dragon Turtle
[89682]=44635,--Oddly-Shaped Horn
[89697]=45163,--Bag of Kafa Beans
[89770]=45242,--Tuft of Yak Fur
[87775]=43695,--Heavenly Jade Cloud Serpent
[87776]=43697,--Heavenly Azure Cloud Serpent
--5.0.4
[90655]=45797,--Thundering Ruby Cloud Serpent
[90711]=45520,--Emerald Pandaren Phoenix
[90712]=45522,--Violet Pandaren Phoenix
[90710]=45521,--Ashen Pandaren Phoenix
[91010]=42352,--Great Red Dragon Turtle
[91011]=43723,--Great Black Dragon Turtle
[91012]=43722,--Great Green Dragon Turtle
[91013]=43724,--Great Blue Dragon Turtle
[91014]=43725,--Great Brown Dragon Turtle
[91015]=43726,--Great Purple Dragon Turtle
[91004]=42250,--Green Dragon Turtle
[91005]=43719,--Brown Dragon Turtle
[91006]=43720,--Purple Dragon Turtle
[91007]=43721,--Red Dragon Turtle
[91008]=43717,--Black Dragon Turtle
[91009]=43718,--Blue Dragon Turtle
--5.0.5
[85785]=38757,--Cataclysmic Gladiator's Twilight Drake
--5.1
[93168]=46929,--Grand Armored Gryphon
[93169]=46930,--Grand Armored Wyvern
[93385]=47166,--Grand Gryphon
[93386]=47165,--Grand Wyvern
[91802]=42147,--Jade Pandaren Kite
[92724]=46729,--Swift Windsteed
--5.2
[93666]=47238,--Spawn of Horridon
[95057]=47981,--Thundering Cobalt Cloud Serpent
[95059]=47983,--Clutch of Ji-Kun
[95564]=48100,--Golden Primal Direhorn
[95565]=48101,--Crimson Primal Direhorn
[95041]=47976,--Malevolent Gladiator's Cloud Serpent
[95416]=46686,--Sky Golem
[93662]=47256,--Armored Skyscreamer
[93671]=48014,--Ghastly Charger
[94228]=47716,--Cobalt Primordial Direhorn
[94229]=47715,--Slate Primordial Direhorn
[94230]=47718,--Amber Primordial Direhorn
[94231]=47717,--Jade Primordial Direhorn
[94290]=47825,--Bone-White Primal Raptor
[94291]=47826,--Red Primal Raptor
[94292]=47828,--Black Primal Raptor
[94293]=47827,--Green Primal Raptor
[95341]=48020,--Armored Bloodwing
--5.3
[98405]=48858,--Brawler's Burly Mushan Beast
[98104]=48815,--Armored Red Dragonhawk
[98259]=48816,--Armored Blue Dragonhawk
[97989]=48714,--Enchanted Fey Dragon
[98618]=48931,--Hearthsteed
--5.4
[104327]=51359,--Prideful Gladiator's Cloud Serpent
[103638]=51484,--Ashhide Mushan Beast
[104246]=51481,--Kor'kron War Wolf
[104253]=51485,--Kor'kron Juggernaut
[104269]=51488,--Thundering Onyx Cloud Serpent
[104325]=51361,--Tyrannical Gladiator's Cloud Serpent
[104326]=51360,--Grievous Gladiator's Cloud Serpent
[104208]=51479,--Spawn of Galakras
[102514]=51037,--Vicious Warsaber
[102533]=51048,--Vicious Skeletal Warhorse
[103630]=17158,--Riding Turtle
[104011]=51323,--Stormcrow
[101675]=49295,--Shimmering Moonstone
[104329]=51484,--Ash-Covered Horn
[104346]=51591,--Golden Glider
--5.4.1
[106246]=51993,--Emerald Hippogryph
--5.4.2
[107951]=53038,--Iron Skyreaver
--5.4.7
[109013]=53774,--Armored Dread Raven
--5.4.8
[112326]=55896,--Warforged Nightmare
[112327]=55907,--Grinning Reaver
--6.0.1
[108883]=59762,--Dustmane Direwolf
[116350]=59762,--Dustmane Direwolf(Recipe)
[115363]=28060,--Creeping Carpet
[114866]=28060,--Creeping Carpet(Recipe)
--[113543]=,--Spirit of Shinri
[118676]=25836,--Emerald Drake
[115484]=58772,--Core Hound
[116383]=59159,--Gorestrider Gronnling
[116785]=59759,--Swift Frostwolf
[118515]=61363,--Cindermane Charger
[119179]=61152,--Iron Star Roller
[119180]=60345,--Goren "Log" Roller
--[114832]=,--Creeping Carpet
--6.0.2
[116771]=59751,--Solar Spirehawk
[116791]=60577,--Challenger's War Yeti
[116660]=59837,--Ironhoof Destroyer
[116661]=59339,--Mottled Meadowstomper
[116674]=59736,--Great Greytusk
[116767]=59744,--Sapphire Riverbeast
[116773]=59364,--Swift Breezestrider
[116777]=60574,--Vicious War Ram
[116778]=60575,--Vicious War Raptor
[116788]=60208,--Warlord's Deathwheel
[116789]=60207,--Champion's Treadblade
[116792]=60578,--Sunhide Gronnling
[116794]=54114,--Garn Nighthowl
[116655]=59321,--Witherhide Cliffstomper
[116656]=59320,--Trained Icehoof
--[116657]=2410,--Ancient Leatherhide
[116658]=59324,--Tundra Icehoof
[116662]=59340,--Trained Meadowstomper
[116663]=59341,--Shadowhide Pearltusk
[116664]=59342,--Dusty Rockhide
[116665]=59343,--Armored Irontusk
[116666]=59349,--Blacksteel Battleboar
[116659]=59323,--Bloodhoof Bull
[116668]=59347,--Armored Frostboar
[116669]=59346,--Armored Razorback
[116670]=59344,--Frostplains Battleboar
[116671]=59739,--Wild Goretusk
[116672]=59738,--Domesticated Razorback
[116673]=59737,--Giant Coldsnout
[116675]=59735,--Trained Rocktusk
[116676]=59743,--Trained Riverwallow
[116768]=59745,--Mosshide Riverwallow
[116769]=59746,--Mudback Riverbeast
[116772]=59363,--Shadowmane Charger
[116774]=59365,--Trained Silverpelt
[116775]=59366,--Breezestrider Stallion
[116776]=59367,--Pale Thorngrazer
[116779]=59756,--Garn Steelmaw
[116780]=59752,--Warsong Direfang
[116781]=59753,--Armored Frostwolf
[116782]=59754,--Ironside Warwolf
[116784]=59757,--Trained Snarler
[116786]=59760,--Smoky Direwolf
[116667]=59348,--Rocktusk Battleboar
--6.1
[120968]=61804,--Chauffeured Chopper (Alliance)
[122703]=61803,--Chauffeured Chopper (Horde)
[121815]=38785,--Voidtalon of the Dark Star
[122469]=62148,--Mystic Runesaber
--6.2
[123890]=62893,--Felsteel Annihilator
[128277]=63956,--Primal Gladiator's Felblood Gronnling
[128281]=64378,--Wild Gladiator's Felblood Gronnling
[128282]=64377,--Warmongering Gladiator's Felblood Gronnling
[123974]=63032,--Corrupted Dreadwing
[124089]=63249,--Vicious War Mechanostrider
[124540]=63580,--Vicious War Kodo
[127140]=63873,--Infernal Direwolf
[128311]=64426,--Coalfist Gronnling
[128480]=64726,--Bristling Hellboar(Horde)
[128481]=64726,--Bristling Hellboar(Alliance)
[128526]=64849,--Deathtusk Felboar(Horde)
[128527]=64849,--Deathtusk Felboar(Alliance)
[128706]=65040,--Soaring Skyterror
--6.2.2
[129922]=48946,--Ironbound Wraithcharger
[129923]=65994,--Eclipse Dragonhawk
[128671]=64960,--Minion of Grumpus
[128422]=64583,--Grove Warden
[128425]=64582,--Illidari Felstalker
--6.2.3
[133543]=67594,--Infinite Timereaver
--7.0.3
[140228]=71001,--Prestigious Bronze Courser
[140232]=70999,--Prestigious Forest Courser
[140233]=70998,--Prestigious Ivory Courser
[140407]=71000,--Prestigious Midnight Courser
[140408]=70996,--Prestigious Azure Courser
[140230]=70997,--Prestigious Royal Courser
[131734]=70874,--Spirit of Eche'ro
[137570]=69276,--Bloodfang Widow
[137574]=70040,--Felblaze Infernal
[137575]=70051,--Hellfire Infernal
--[137576]=,--Coldflame Infernal
[137577]=70060,--Predatory Bloodgazer
[137578]=70063,--Snowfeather Hunter
[137579]=70062,--Brilliant Direbeak
[137580]=70061,--Viridian Sharptalon
--[137614]=,--Frostshard Infernal
--[137615]=,--Flarecore Infernal
[137686]=70099,--Steelbound Devourer
[137687]=70099,--Steelbound Devourer(Recipe)
[138201]=71939,--Fathom Dweller
[138258]=29361,--Long-Forgotten Hippogryph
[138387]=70619,--Ratstallion
[141216]=72700,--Grove Defiler
[141217]=63625,--Leyfeather Hippogryph
[141843]=73315,--Vindictive Gladiator's Storm Dragon
[141844]=73316,--Fearless Gladiator's Storm Dragon
[141845]=73317,--Cruel Gladiator's Storm Dragon
[141846]=73319,--Ferocious Gladiator's Storm Dragon
[141847]=73320,--Fierce Gladiator's Storm Dragon
[141848]=73321,--Demonic Gladiator's Storm Dragon
[129962]=67042,--Great Northern Elderhorn
[141850]=67042,--Great Northern Elderhorn(Recipe)
[137573]=68851,--Llothien Prowler
[138811]=68849,--Brinedeep Bottom-Feeder
[129280]=38668,--Prestigious War Steed
[140348]=71975,--Vicious Warstrider
[140350]=72020,--Vicious War Elekk
[140353]=71973,--Vicious Gilnean Warhorse
[140354]=71816,--Vicious War Trike
[141713]=68848,--Arcadian War Turtle
[129744]=48946,--Ironbound Wraithcharger
[140500]=72071,--Mechanized Lumber Extractor
--7.1.0
[142436]=74032,--Arcanist's Manasaber
[142398]=73254,--Darkwater Skate
[142369]=73991,--White Hawkstrider
[142236]=73808,--Midnight
[143864]=68069,--Prestigious War Wolf
[142403]=19480,--Rockspine Basilisk
[142552]=74104,--Smoldering Ember Wyrm
--7.2
[143643]=74315,--Abyss Worm
[142225]=73784,--Ban-Lu, Grandmaster's Companion
[143490]=74136,--Shadowblade's Crimson Omen
[147806]=63628,--Cloudwing Hippogryph
[142231]=73785,--Deathlord's Vilebrood Vanquisher
--[142224]=,--Gift of the Holy Keepers
[143502]=74148,--Highlord's Golden Charger
[143503]=74149,--Highlord's Vengeful Charger
[143637]=75532,--Netherlord's Brimstone Wrathsteed
[143505]=74151,--Highlord's Valorous Charger
[147807]=67039,--Highmountain Elderhorn
[142232]=73778,--Battlelord's Bloodthirsty War Wyrm
[143764]=74480,--Leywoven Flying Carpet
[143491]=74134,--Shadowblade's Baneful Omen
[143492]=74135,--Shadowblade's Lethal Omen
--[143638]=,--Archdruid's Lunarwing Form
[143631]=74298,--Primal Flamesaber
[143489]=76024,--Farseer's Raging Tempest
[143493]=74133,--Shadowblade's Murderous Omen
--[142223]=,--REUSE
[147835]=74314,--Riddler's Mind-Worm
[142233]=75533,--Netherlord's Accursed Wrathsteed
[143752]=73248,--Brawler's Burly Basilisk
[143504]=74150,--Highlord's Vigilant Charger
[142228]=73781,--Huntmaster's Dire Wolfhawk
[142226]=73782,--Huntmaster's Fierce Wolfhawk
[142227]=73780,--Huntmaster's Loyal Wolfhawk
[147805]=68053,--Valarjar Stormwing
[142234]=73805,--Vicious War Bear
[142235]=73806,--Vicious War Bear
[142237]=73817,--Vicious War Lion
[142437]=74034,--Vicious War Scorpion
[143648]=74320,--Vicious War Turtle
[143649]=74321,--Vicious War Turtle
[147804]=76424,--Wild Dreamrunner
--7.3
[152904]=79593,--Acid Belcher
[152816]=79479,--Antoran Charhound
[152815]=79480,--Antoran Gloomhound
[153044]=79790,--Avenging Felcrusher
[152903]=79592,--Biletooth Gnasher
[153041]=79440,--Bleakhoof Ruinstrider
[153043]=79789,--Blessed Felcrusher
[152905]=79595,--Crimson Slavermaw
[153485]=78105,--Darkmoon Dirigible
[152843]=74900,--Darkspore Mana Ray
[152841]=79487,--Felglow Mana Ray
[153042]=79732,--Glorious Felcrusher
[152901]=79583,--Violet Spellwing
[152844]=79484,--Lambent Mana Ray
[152788]=75585,--Lightforged Warframe
[151623]=78092,--Lucid Nightmare
[147901]=76586,--Luminous Starseeker
[152814]=76311,--Maddened Chaosrunner
[152912]=79613,--Pond Nettle
[152794]=79443,--Amethyst Ruinstrider
[152795]=79441,--Beryl Ruinstrider
[152797]=79437,--Cerulean Ruinstrider
[152793]=79444,--Russet Ruinstrider
[152791]=76318,--Sable Ruinstrider
[152796]=79438,--Umber Ruinstrider
[152840]=79486,--Scintillating Mana Ray
[152789]=79436,--Shackled Ur'zul
[152842]=79485,--Vibrant Mana Ray
[152869]=76426,--Vicious War Fox
[152870]=76427,--Vicious War Fox
[152790]=76646,--Vile Fiend
--7.3.5
[153493]=76533,--Demonic Gladiator's Storm Dragon
[155656]=81114,--Lightforged Felcrusher
[155662]=81113,--Highmountain Thunderhoof
[156486]=81648,--Starcursed Voidstrider
[156487]=74032,--Nightborne Manasaber
[151625]=75705,--Ruby Qiraji Resonating Crystal
[151626]=75706,--Sapphire Qiraji Resonating Crystal
--8.0.1
[156884]=82782,--Black Gladiator's Proto-Drake
[163216]=78858,--Bloodgorged Crawg
[156880]=82804,--Blue Gladiator's Proto-Drake
[163578]=87773,--Broken Highland Mustang
[163576]=75324,--Dune Scavenger
[163574]=81694,--Terrified Pack Mule
[163577]=87772,--Conquerer's Scythemaw
[163583]=87776,--Craghorn Chasm-Leaper
[161331]=85691,--Dark Iron Core Hound
[156879]=82809,--Dread Gladiator's Proto-Drake
[163981]=38784,--Frenzied Feltalon
[156885]=82805,--Gold Gladiator's Proto-Drake
[163573]=81690,--Goldenmane
[163131]=73253,--Great Sea Ray
[156883]=82806,--Green Gladiator's Proto-Drake
[163579]=87774,--Highland Mustang
[159146]=77023,--Kua'fon
[163646]=85581,--Lil' Donkey
[161330]=84468,--Mag'har Direwolf
[161134]=80864,--Mecha-Mogul Mk2
[161135]=80864,--Mecha-Mogul Mk2(Recipe)
[159921]=84274,--Tomb Stalker
[161479]=74316,--Nazjatar Blood Serpent
[156882]=82807,--Pale Gladiator's Proto-Drake
[164250]=88359,--Prestigious Bloodforged Courser
[163982]=88116,--Pureheart Courser
[156881]=82810,--Purple Gladiator's Proto-Drake
[163582]=45836,--Qinsho's Eternal Hound
[163575]=76706,--Leaping Veinseeker
[161911]=82148,--Admiralty Stallion
[161773]=75323,--Alabaster Hyena
[161667]=87041,--Armored Albino Pterrordax
[161664]=77070,--Armored Ebony Pterrordax
[161666]=87044,--Armored Orange Pterrordax
[161665]=87045,--Cobalt Pterrordax
[161912]=81693,--Dapple Gray
[161908]=83666,--Dusky Waycrest Gryphon
[161774]=76708,--Expedition Bloodswarmer
[163042]=83632,--Mighty Caravan Brutosaur
[161215]=75600,--Obsidian Krolusk
[163589]=87779,--Palehide Direhorn
[161879]=83664,--Proudmoore Sea Scout
[161910]=82161,--Smoky Charger
[163063]=87701,--Spectral Phoenix
[161909]=83665,--Stormsong Coastwatcher
[159842]=80449,--Summon Sharkbait
[156564]=81772,--Shu-Zen, the Divine Sentinel
[163645]=87848,--Skullripper
[163127]=86527,--Teldrassil Hippogryph
[163183]=81952,--Spawn of Krag'wa
[163586]=79916,--Squawks
--[163188]=,--Surf Jelly
[163585]=87747,--Surf Jelly
[163644]=14345,--Swift Albino Raptor
[163186]=87741,--Tempestuous Skystallion
[156798]=88835,--The Hivemind
[163584]=87775,--Twilight Avenger
[160829]=78860,--Underrot Crawg
[163121]=82528,--Vicious War Basilisk
[163122]=82527,--Vicious War Basilisk
[163124]=85393,--Vicious War Clefthoof
[163123]=85888,--Vicious War Riverbeast
[163128]=85886,--Undercity Plaguebat
[163706]=86091,--Witherbark Direwing
[153594]=80513,--Xiwyllag ATV
[157870]=83525,--Zandalari Direhorn
--[158922]=,--Zany Zombified Raptor
[160589]=85970,--The Dreadwake
--8.1
[166432]=89750,--Ashenvale Chimaera
[166465]=90393,--Azureshell Krolusk
[166428]=706,--Blackpaw
[166468]=55151,--Bloodgorged Hunter
[166469]=60307,--Bloodthirsty Dreadwing
[166442]=81959,--Blue Marsh Hopper
[166438]=706,--Blackpaw
[166774]=90398,--Hogrus, Swine of Good Fortune
[166437]=89247,--Kaldorei Nightsaber
[166434]=89246,--Umber Nightsaber
[166539]=90194,--Dazar'alor Windreaver
[166433]=12247,--Frightened Kodo
[166518]=90189,--G.M.O.D.
[166705]=90414,--Glacial Tidestorm
[166467]=90158,--Island Thunderscale
[166435]=89247,--Kaldorei Nightsaber
[164571]=88646,--Meat Wagon
[166463]=90159,--Priestess' Moonsaber
[166417]=75322,--Reins of the Onyx War Hyena
[166466]=5050,--Risen Mare
[166464]=90394,--Rubyshell Krolusk
[166471]=34958,--Saltwater Seahorse
[166436]=6448,--Sandy Nightsaber
[166745]=84359,--Siltwing Albatross
[166470]=67041,--Stonehide Elderhorn
[166803]=89246,--Umber Nightsaber
[165020]=88760,--Vicious Black Bonesteed
[165019]=88755,--Vicious Black Warsaber
[166775]=90397,--Vulpine Familiar
[166443]=81958,--Yellow Marsh Hopper
--8.1.5
[167894]=90215,--Beastlord's Irontusk
[167895]=57466,--Beastlord's Warwolf
[168055]=91388,--Bloodflank Charger
[166724]=90419,--Bruce
[168056]=91389,--Ironclad Frostclaw
[164762]=88974,--Kul Tiran Charger
--8.2
[168830]=92730,--Aerial Unit R-21\/X
--[170178]=,--Alpha Fin
[167167]=90725,--Ankoan Waveray
[167171]=90729,--Azshari Bloatray
[168408]=91787,--Child of Torcali
[169202]=92254,--Crimson Tidestallion
[169200]=91236,--Deepcoral Snapdragon
[169201]=88768,--Fabious
[169203]=92251,--Inkscale Deepseeker
[168329]=91633,--Mechacycle Model W
--[168673]=,--Keys to the Silver Mono-Wheel
[168826]=90710,--Mechagon Peacekeeper
[167751]=92666,--X-995 Mechanocat
[169198]=91104,--Royal Snapdragon
[168829]=92731,--Rustbolt Resistor
[168370]=91634,--Junkheap Drifter
[168823]=90711,--Rusty Mechanocrawler
[168827]=90712,--Scrapforged Mechaspider
[169163]=90728,--Silent Glider
[169194]=91238,--Snapback Scuttler
[169199]=91237,--Snapdragon Kelpstalker
[166776]=90396,--Sylverian Dreamer
[167170]=90727,--Unshackled Waveray
[169162]=90421,--Wonderwing 2.0
},
[2] = {
------------------------------------------
--**************************************--
--************* COMPANIONS *************--
--**************************************--
------------------------------------------
--1.11.1 and earlier
[12264]=9563,--Worg Pup
[21277]=10269,--Tranquil Mechanical Yeti
[12529]=27718,--Smolderweb Hatchling
[20769]=15436,--Disgusting Oozeling
[15996]=901,--Lifelike Toad
[16044]=901,--Lifelike Toad(Recipe)
[11474]=6294,--Sprite Darter Hatchling
[11825]=8909,--Pet Bombling
[11828]=8909,--Pet Bombling(Recipe)
[11826]=8910,--Lil' Smoky
[11827]=8910,--Lil' Smoky(Recipe)
[10398]=7920,--Mechanical Chicken
[11026]=6295,--Tree Frog
[11027]=901,--Wood Frog
[19450]=14938,--Jubling
--[19462]=,--Unhatched Jubling Egg
[11023]=5369,--Ancona Chicken
[8499]=6290,--Crimson Whelpling
[8500]=4615,--Great Horned Owl
[8501]=6299,--Hawk Owl
[10360]=1206,--Black Kingsnake
[10361]=2957,--Brown Snake
[10392]=6303,--Crimson Snake
[10393]=2177,--Undercity Cockroach
[10394]=1072,--Brown Prairie Dog
[10822]=6288,--Dark Whelpling
[8498]=6291,--Emerald Whelpling
[8494]=6192,--Hyacinth Macaw
[13582]=10993,--Zergling
[13583]=10990,--Panda Cub
[13584]=10992,--Mini Diablo
[20371]=15369,--Murky
[8485]=5556,--Bombay Cat
[8486]=5586,--Cornish Rex Cat
[8487]=5554,--Orange Tabby Cat
[8488]=5555,--Silver Tabby Cat
[8489]=9990,--White Kitten
[8490]=5585,--Siamese Cat
[8491]=5448,--Black Tabby Cat
[8492]=5207,--Green Wing Macaw
[8495]=6190,--Senegal
[8496]=6191,--Cockatiel
[8497]=328,--Snowshoe Rabbit
[4401]=7937,--Mechanical Squirrel
[4408]=7937,--Mechanical Squirrel(Recipe)
[23015]=2176,--Whiskers the Rat
[11110]=304,--Westfall Chicken
[21301]=15660,--Father Winter's Helper
[21305]=15663,--Winter's Little Helper
[21308]=15904,--Winter Reindeer
[23083]=16587,--Spirit of Summer
--[22200]=,--Silver Shafted Arrow
[22235]=15992,--Peddlefeet
[23002]=16259,--Speedy
[23007]=16257,--Mr. Wiggles
[21309]=13610,--Tiny Snowman
--1.12.1
[18964]=14657,--Loggerhead Snapjaw
[19054]=14779,--Tiny Red Dragon
[19055]=14778,--Tiny Green Dragon
--2.0
[23713]=16943,--Hippogryph Hatchling
--2.0.1
[31760]=20996,--Miniwing
[29363]=19600,--Mana Wyrmling
[29364]=4626,--Brown Rabbit
[29902]=19986,--Red Moth
[29958]=20029,--Blue Dragonhawk Hatchling
[27445]=18269,--Magical Crawdad
[29901]=19987,--Blue Moth
[29903]=19985,--Yellow Moth
[29904]=19999,--White Moth
[29953]=20026,--Golden Dragonhawk Hatchling
[29956]=20027,--Red Dragonhawk Hatchling
[29957]=20037,--Silver Dragonhawk Hatchling
[32588]=21362,--Bananas
--2.0.3
[23712]=37949,--White Tiger Cub
--2.1
[22114]=15984,--Gurky
[25535]=17723,--Netherwhelp
[32616]=21382,--Egbert
[32617]=21381,--Willy
[32622]=21393,--Peanut
[29960]=20042,--Firefly
[30360]=15398,--Lurky
--2.2.2
[32233]=22349,--Wolpertinger
[33154]=21900,--Sinister Squashling
--2.3
[34478]=22855,--Tiny Sporebat
[34535]=6293,--Azure Whelpling
[33993]=22459,--Mojo
[34493]=22966,--Dragon Kite
[34425]=22776,--Clockwork Rocket Bot
[34492]=22903,--Rocket Chicken
--2.4
[35504]=23574,--Phoenix Hatchling
[33816]=22388,--Toothy
[33818]=22389,--Muckbreath
[35349]=23507,--Snarly
[35350]=23506,--Chuck
--2.4.2
[38628]=25457,--Nether Ray Fry
[34955]=8409,--Searing Scorchling
[38050]=25002,--Ethereal Soul-Trader
[39656]=25900,--Mini Tyrael
[32498]=21328,--Lucky
--2.4.3
[37297]=24393,--Spirit of Competition
--[37710]=25332,--Crashin' Thrashin' Racer
--3.0.1
[21168]=15595,--Baby Shark
[40653]=16633,--Stinker
--3.0.2
[38658]=4185,--Vampiric Batling
[39973]=28089,--Ghostly Skull
[43698]=27627,--Giant Sewer Rat
[44723]=28216,--Pengu
[39896]=45919,--Tickbird Hatchling
[39899]=28215,--White Tickbird Hatchling
[44721]=28217,--Proto-Drake Whelp
[44481]=26524,--Grindgear Toy Gorilla
[44482]=27829,--Trusty Copper Racer
--3.0.3
[39286]=28456,--Frosty
[44738]=45937,--Kirin Tor Familiar
[39898]=28084,--Cobra Hatchling
[44819]=16189,--Baby Blizzard Bear
--3.0.8
[44841]=28397,--Little Fawn
--3.1
[44822]=2955,--Albino Snake
[45942]=29060,--XS-001 Constructor Bot
[44794]=6302,--Spring Rabbit
[44965]=28482,--Teldrassil Sproutling
[44970]=28489,--Dun Morogh Cub
[44971]=4732,--Tirisfal Batling
[44973]=15470,--Durotar Scorpion
[44974]=16205,--Elwynn Lamb
[44980]=28502,--Mulgore Hatchling
[44983]=45880,--Strand Crawler
[44984]=28493,--Ammen Vale Lashling
[44998]=28946,--Argent Squire
[45002]=28539,--Mechanopeep
[45022]=28948,--Argent Gruntling
[45057]=28599,--Wind-Up Train Wrecker
[45606]=46939,--Sen'jin Fetish
[44982]=45960,--Enchanted Broom
[44601]=27829,--Heavy Copper Racer
[44599]=27829,--Zippy Copper Racer
[45047]=28811,--Sandbox Tiger
--3.1.2
[45180]=28734,--Murkimus the Gladiator
--3.1.3
[46767]=29279,--Warbot
--3.2
[48112]=29805,--Darting Hatchling
[48116]=29803,--Gundrak Hatchling
[48118]=29802,--Leaping Hatchling
[48120]=29809,--Obsidian Hatchling
[48122]=29810,--Ravasaur Hatchling
[48124]=29808,--Razormaw Hatchling
[48126]=29806,--Razzashi Hatchling
[48114]=29807,--Deviate Hatchling
[46707]=22629,--Pint-Sized Pink Pachyderm
[46802]=29348,--Grunty
[46544]=25384,--Curious Wolvar Pup
[46545]=25173,--Curious Oracle Hatchling
[46820]=29372,--Shimmering Wyrmling
[46821]=29372,--Shimmering Wyrmling
[46396]=25384,--Wolvar Orphan Whistle
[46397]=25173,--Oracle Orphan Whistle
--3.2.2
[49362]=30356,--Onyxian Whelpling
[41133]=26452,--Mr. Chilly
[44810]=45968,--Plump Turkey
[49665]=30414,--Pandaren Monk
[49693]=30507,--Lil' K.T.
[46831]=29404,--Macabre Marionette
[49287]=30157,--Tuskarr Kite
[49343]=30409,--Spectral Tiger Cub
--3.3
[46398]=11709,--Calico Cat
[49646]=30462,--Core Hound Pup
[49912]=31174,--Perky Pug
[34518]=21304,--Golden Pig
[34519]=22938,--Silver Pig
[37298]=24620,--Essence of Competition
[22781]=16189,--Poley
[45047]=28811,--Sandbox Tiger
--3.3.2
[49662]=30412,--Gryphon Hatchling
[49663]=30413,--Wind Rider Cub
[50446]=31073,--Toxic Wasteling
--3.3.3
[53641]=31722,--Frigid Frostling
[54847]=32031,--Lil' XT
[54436]=22778,--Blue Clockwork Rocket Bot
--[54343]=25332,--Blue Crashin' Thrashin' Racer 
--3.3.5
[56806]=32670,--Mini Thor
--4.0.1
[63138]=37136,--Dark Phoenix Hatchling
[64403]=33217,--Fox Kit
[63398]=36220,--Armadillo Pup
[63355]=36499,--Rustberg Seagull
[64996]=36499,--Rustberg Seagull
[67128]=32031,--Landro's Lil' XT
[67418]=36896,--Deathy
[66076]=9905,--Mr. Grubbs
[65362]=37199,--Guild Page
[65363]=37198,--Guild Herald
[65364]=37196,--Guild Herald
[65661]=32699,--Blue Mini Jouster
[65662]=32707,--Gold Mini Jouster
[65361]=37200,--Guild Page
--4.0.3
[60955]=34413,--Fossilized Hatchling
[46892]=28734,--Murkimus the Gladiator
[49664]=30402,--Zipao Tiger
[62540]=35338,--Lil' Deathwing
[62769]=15393,--Eat the Egg
[48527]=29819,--Onyx Panther
[68385]=37541,--Lil' Ragnaros
[68618]=37526,--Moonkin Hatchling
[68619]=37527,--Moonkin Hatchling
[67600]=6290,--Lil&#039; Alexstrasza
[60847]=34262,--Crawling Claw
[66080]=28435,--Tiny Flamefly
[59597]=33512,--Personal World Destroyer
[60216]=33559,--De-Weaponized Mechanical Companion
[64372]=36211,--Clockwork Gnome
[67274]=36902,--Enchanted Lantern
[67308]=36902,--Enchanted Lantern(Recipe)
[67275]=36901,--Magic Lamp
[67312]=36901,--Magic Lamp(Recipe)
[67282]=45878,--Elementium Geode
[46325]=45943,--Withers
[60869]=45940,--Pebble
[64494]=36637,--Tiny Shale Spider
[66067]=37154,--Singing Sunflower
[66073]=38135,--Scooter the Snail
[54810]=31956,--Celestial Dragon
[46709]=17192,--MiniZep Controller
--4.0.6
[68673]=27718,--Smolderweb Hatchling
--4.1
[69991]=22855,--Tiny Sporebat
[69824]=38232,--Voodoo Figurine
[69821]=38229,--Pterrordax Hatchling
[68840]=30507,--Landro's Lichling
[68841]=37846,--Nightsaber Cub
[69648]=38134,--Legs
[69847]=38359,--Guardian Cub
[70099]=16943,--Cenarion Hatchling
[68833]=37814,--Panther Cub
[69239]=37712,--Winterspring Cub
[69992]=29372,--Shimmering Wyrmling
[69251]=38065,--Lashtail Hatchling
--4.2
[71033]=38614,--Lil' Tarecgosa
[72068]=38359,--Guardian Cub
[70908]=38539,--Feline Familiar
[71076]=38638,--Creepy Crate
[71726]=38803,--Murkablo
[70140]=38455,--Hyjal Bear Cub
[72045]=38342,--Horde Balloon
[71137]=38691,--Brewfest Keg Pony
[71140]=38693,--Nuts
[71387]=38776,--Brilliant Kaliri
[72042]=38343,--Alliance Balloon
[70160]=38429,--Crimson Lasher
--4.3
[73953]=39109,--Sea Pony
[71624]=38777,--Purple Puffer
[72153]=39694,--Sand Scarab
[73762]=38344,--Darkmoon Balloon
[73764]=46001,--Darkmoon Monkey
[73765]=38809,--Darkmoon Turtle
[73797]=45939,--Lumpy
[73903]=15381,--Darkmoon Tonk
[73905]=17192,--Darkmoon Zeppelin
[72134]=38919,--Gregarious Grell
[74981]=39137,--Darkmoon Cub
[76062]=39380,--Fetish Shaman
[78916]=40019,--Soul of the Aspects
[75040]=38344,--Flimsy Darkmoon Balloon
[75041]=38340,--Flimsy Green Balloon
[75042]=38341,--Flimsy Yellow Balloon
[74610]=39163,--Lunar Lantern
[74611]=39333,--Festival Lantern
[77158]=39319,--Darkmoon "Tiger"
--4.3.2
[79744]=40538,--Eye of the Legion
--5.0.1
[85513]=43865,--Thundering Serpent Hatchling
[87526]=45386,--Mechanical Pandaren Dragonling
[80008]=45957,--Darkmoon Rabbit
[85220]=44655,--Terrible Turnip
[85222]=46385,--Red Cricket
[85447]=47955,--Tiny Goldfish
[85578]=45894,--Feral Vermling
[85871]=43255,--Lucky Quilen Cub
[89587]=41833,--Porcupette
[89686]=45987,--Jade Tentacle
[89736]=45195,--Venus
[87567]=44792,--Food
[87568]=44791,--Food
[88148]=43868,--Jade Crane Chick
[82774]=15905,--Jade Owl
[90470]=15905,--Jade Owl(Recipe)
[82775]=42297,--Sapphire Cub
[90471]=42297,--Sapphire Cub(Recipe)
[86562]=43597,--Hopling
[86563]=45854,--Aqua Strider
[86564]=45938,--Grinder
[88147]=43127,--Singing Cricket
[84105]=42721,--Fishy
[89367]=44792,--Yu'lon Kite
[89368]=44791,--Chi-Ji Kite
--5.0.3
[74622]=16587,--Fire Spirit
[89640]=45072,--Life Spirit
[89641]=45073,--Water Spirit
--5.0.4
[90897]=33217,--Fox Kit
[90898]=33217,--Fox Kit
[90173]=45942,--Pandaren Water Spirit
[90177]=45527,--Baneling
[90953]=30409,--Spectral Cub
[90953]=30409,--Spectral Cub
[90953]=30409,--Spectral Cub
--5.1
[90900]=44551,--Imperial Moth
[91040]=46174,--Darkmoon Eye
[92707]=46720,--Cinder Kitten
[92798]=46809,--Pandaren Fire Spirit
[92799]=46810,--Pandaren Air Spirit
[92800]=46811,--Pandaren Earth Spirit
[93031]=46897,--Mr. Bigglesworth
[90902]=40521,--Imperial Silkworm
[91031]=46171,--Darkmoon Glowfly
[91003]=46163,--Darkmoon Hatchling
[93029]=46921,--Stitched Pup
[93025]=46882,--Clock'em
[93032]=46896,--Fungal Abomination
[93033]=46900,--Harbinger of Flame
[93034]=46923,--Corefire Imp
[93035]=46902,--Ashstone Core
[93036]=46903,--Untamed Hatchling
[93037]=46905,--Death Talon Whelpguard
[93038]=46925,--Chrominius
[93039]=46924,--Viscidus Globule
[93040]=46922,--Anubisath Idol
[93041]=46909,--Mini Mindslayer
[93030]=46898,--Giant Bone Spider
[92959]=39331,--Darkmoon "Cougar"
[92968]=46695,--Darkmoon "Murloc"
[92969]=46696,--Darkmoon "Rocket"
[92956]=39330,--Darkmoon "Snow Leopard"
[92970]=46697,--Darkmoon "Wyvern"
[92966]=46693,--Darkmoon "Dragon"
[92958]=39332,--Darkmoon "Nightsaber"
[92967]=46694,--Darkmoon "Gryphon"
--5.2
[95422]=48055,--Zandalari Anklerender
[93669]=47348,--Gusting Grimoire
[94124]=47848,--Sunreaver Micro-Sentry
[94125]=47252,--Living Sandling
[94126]=47731,--Zandalari Kneebiter
[94152]=47708,--Son of Animus
[94190]=47732,--Spectral Porcupette
[94208]=47747,--Sunfur Panda
[94209]=47749,--Snowy Panda
[94210]=47748,--Mountain Panda
[94595]=48091,--Spawn of G'nathus
[94835]=48001,--Ji-Kun Hatchling
[94025]=47634,--Red Panda
[95423]=48056,--Zandalari Footslasher
[95424]=48057,--Zandalari Toenibbler
[95621]=29279,--Warbot
[94191]=48211,--Stunted Direhorn
[94573]=48213,--Direhorn Runt
[94574]=48212,--Pygmy Direhorn
[94903]=47711,--Pierre
[94932]=47959,--Tiny Red Carp
[94933]=47957,--Tiny Blue Carp
[94934]=47958,--Tiny Green Carp
[94935]=47960,--Tiny White Carp
--5.3
[98550]=48934,--Blossoming Ancient
[100870]=49081,--Murkimus Tyrannicus
[97821]=48651,--Gahz'rooki
[97548]=48878,--Lil' Bad Wolf
[97549]=48857,--Menagerie Custodian
[97550]=48856,--Netherspace Abyssal
[97551]=48662,--Fiendish Imp
[97552]=48855,--Tideskipper
[97961]=48708,--Filthling
[97554]=48661,--Coilfang Stalker
[97555]=48664,--Pocket Reaver
[97556]=48668,--Lesser Voidcaller
[97557]=48663,--Phoenix Hawk Hatchling
[97558]=48667,--Tito
[97959]=48704,--Living Fluid
[97960]=48705,--Viscous Horror
[97553]=48666,--Tainted Waveling
--5.4
[101570]=855,--Moon Moon
[104317]=51505,--Rotten Little Helper
[100905]=49084,--Rascal-Bot
[101771]=49846,--Xu-Fu, Cub of Xuen
[102145]=49835,--Chi-Chi, Hatchling of Chi-Ji
[102146]=49845,--Zao, Calfling of Niuzao
[102147]=49836,--Yu'la, Broodling of Yu'lon
[103637]=47858,--Vengeful Porcupette
[103670]=49289,--Lil' Bling
[104156]=40908,--Ashleaft Spriteling
[104157]=51413,--Azure Crane Chick
[104158]=51268,--Blackfuse Bombling
[104159]=51271,--Ruby Droplet
[104160]=51408,--Dandelion Frolicker
[104162]=51417,--Droplet of Y'Shaarj
[104163]=51267,--Gooey Sha-ling
[104164]=51270,--Jademist Dancer
[104165]=51269,--Kovok
[104166]=51272,--Ominous Flame
[104167]=51279,--Skunky Alemental
[104168]=51278,--Spineclaw Crab
[104169]=47991,--Gulp Froglet
[104202]=51475,--Bonkers
[104291]=51502,--Gu'chi Swarmling
[104295]=47856,--Harmonious Porcupette
[104307]=51504,--Jadefire Spirit
[104332]=51530,--Sky Lantern
[104333]=51530,--Flimsy Sky Lantern
[104161]=51277,--Death Adder Hatchling
--5.4.1
[106240]=51988,--Alterac Brew-Pup
[106244]=51990,--Murkalot
--5.4.2
[106256]=51994,--Treasure Goblin
[108438]=37526,--Moonkin Hatchling
--[104318]=51507,--Crashin' Thrashin' Flyer
--5.4.7
[109014]=53719,--Dread Hatchling
--6.0.1
[118598]=57825,--Sun Sproutling
[110684]=54752,--Lil' Leftovers
[111402]=59021,--Mechanical Axebeak
[118484]=59021,--Mechanical Axebeak(Recipe)
[111660]=53748,--Iron Starlette
[111866]=53878,--Royal Peacock
[112057]=55679,--Lifelike Mechanical Frostboar
[118485]=55679,--Lifelike Mechanical Frostboar(Recipe)
[112699]=58722,--Teroclaw Hatchling
[113554]=57803,--Zomstrok
[113558]=54511,--Weebomination
[113623]=57970,--Ghastly Kid
[114919]=49259,--Sea Calf
[114968]=58395,--Deathwatch Hatchling
[115282]=58547,--Draenei Micro Defender
[115301]=58570,--Molten Corgi
[115483]=58770,--Sky-Bo
[116064]=47931,--Syd the Squid
[116258]=59099,--Mystical Spring Bouquet
[116403]=30969,--Bush Chicken
[116801]=58169,--Cursed Birman
[116804]=59330,--Widget the Departed
[116815]=59352,--Netherspawn, Spawn of Netherspawn
[117404]=15595,--Land Shark
[117528]=59668,--Lanticore Spawnling
[118207]=60016,--Hydraling
[118516]=61128,--Argi
[118517]=61127,--Grommloc
[118518]=61133,--Unused
[118574]=60441,--Hatespark the Tiny
[118577]=60458,--Stormwing
[118578]=59017,--Firewing
[118595]=57824,--Nightshade Sproutling
[118596]=57820,--Sassy Sproutling
[118597]=57821,--Kelp Sproutling
[110721]=54848,--Crazy Carrot
[118599]=57823,--Autumnal Sproutling
[118600]=57822,--Forest Sproutling
[118675]=6292,--Summon Bronze Whelpling
[118709]=60732,--Dread Dandelion
[118741]=49122,--Mechanical Scorpid
[119177]=49122,--Mechanical Scorpid(Recipe)
[118919]=60875,--Ore Eater
[118921]=60819,--Everbloom Peachick
[118923]=60820,--Sentinel's Companion
[119048]=53502,--Hogs
[119112]=60876,--Son of Sethe
[119141]=54855,--Frostwolf Pup
[119142]=58547,--Draenei Micro Defender
[119143]=60876,--Son of Sethe
[119146]=58617,--Bone Wasp
[119148]=58768,--Albino River Calf
[119149]=57822,--Forest Sproutling
[119150]=60909,--Sky Fry
[119170]=60930,--Eye of Observation
[114834]=39130,--Meadowstomper Calfling
[115469]=39130,--Meadowstomper Calfling
[116402]=58736,--Stonegrinder
[117354]=59577,--Ancient Nest Guardian
[117380]=59578,--Frostwolf Ghostpup
[117564]=58825,--Fruit Hunter
[118101]=59885,--Zangar Spore
[118104]=61548,--Umbrafen Spore
[118105]=61550,--Seaborne Spore
[118106]=61549,--Crimson Spore
[118107]=61547,--Brilliant Spore
[113216]=58170,--Elekk Plushie
[114865]=58170,--Elekk Plushie(Recipe)
[116155]=28502,--Lovebird Hatchling
[116439]=38473,--Blazing Cindercrawler
[116756]=42430,--Stout Alemental
--[101628]=,--Temporal Shard
--6.0.2
[119328]=58534,--Soul of the Forge
[119329]=58534,--Soul of the Forge(Recipe)
[119434]=53610,--Albino Chimaeraling
[119467]=59038,--Puddle Terror
[119468]=60617,--Sunfire Kaliri
[120121]=61148,--Trunks
[120309]=58932,--Pygmy Cow
[119431]=61016,--Servant of Demidos
[120050]=59603,--Veilwatcher Hatchling
[120051]=59034,--Kaliri Hatchling
--6.1
[122113]=61896,--Sunblade Micro-Defender
[122104]=61887,--Leviathan
[122106]=61888,--Abyssius
[122107]=61890,--Fragment of Anger
[122108]=61891,--Fragment of Suffering
[122109]=61889,--Fragment of Desire
[122110]=61892,--Sister of Temptation
[122111]=61894,--Stinkrot
[122112]=40224,--Hyjal Wisp
[122105]=61884,--Grotesque
[122114]=62466,--Chaos Pup
[122115]=61898,--Wretched Servant
[122116]=61900,--K'ute
[122125]=62404,--Race MiniZep
--[122477]=,--My Special Pet
[122532]=60975,--Bone Serpent
[122533]=60609,--Young Talbuk
[122534]=62440,--Slithershock Elver
--6.2
[127749]=64097,--Corrupted Nest Guardian
[126925]=63693,--Blorp
[127701]=60972,--Glowing Sporebat
[127703]=60889,--Dusty Sporewing
[127704]=58613,--Bloodthorn Hatchling
[127705]=63447,--Lost Netherpup
[127748]=63446,--Cinder Pup
[126926]=63691,--Ghostshell Crab
[127753]=63584,--Nightmare Bell
[127754]=58760,--Periwinkle Calf
[127856]=64194,--Left Shark
[127868]=64222,--Crusher
[128309]=64425,--Shard of Cyrukh
[128477]=64720,--Savage Cub
[128478]=38310,--Blazing Firehawk
--6.2.2
[128423]=64587,--Summon Zeradar
[128424]=64588,--Summon Brightpaw
[128426]=64585,--Nibbles
[128427]=64589,--Summon Murkidan
[129205]=61986,--Fel Pup
[129216]=65713,--Energized Manafiend
[129217]=65717,--Empowered Manafiend
[129218]=65714,--Empyreal Manafiend
[128770]=65128,--Grumpling
--6.2.3
[134047]=68067,--Baby Winston
--7.0.3
[136910]=23408,--Alarm-o-Bot
[139775]=71002,--Alliance Enthusiast
[128690]=65070,--Ashmaw Cub
[136919]=66485,--Baby Elderhorn
[140934]=72658,--Benax
[136907]=65670,--Black Piglet
[129188]=65630,--Bleakwater Jelly
[129362]=65813,--Broot
[136906]=65669,--Brown Piglet
[136923]=68858,--Celestial Calf
[136925]=68729,--Corgi Pup
[140320]=68845,--Corgnelius
[140672]=72239,--Court Scribe
[129175]=65590,--Crispin
[129178]=65120,--Emmigosa
[128533]=69490,--Enchanted Cauldron
[128621]=69490,--Enchanted Cauldron(Recipe)
[128535]=69488,--Enchanted Pen
[128623]=69488,--Enchanted Pen(Recipe)
[128534]=69489,--Enchanted Torch
[128622]=69489,--Enchanted Torch(Recipe)
[136899]=65113,--Extinguished Eye
[136901]=65112,--Eye of Inquisition
[129760]=65672,--Fel Piglet
[136924]=68859,--Felbat Pup
[130168]=66155,--Fetid Waveling
[140316]=68860,--Firebat Pup
[136898]=65087,--Fledgling Warden Owl
[128354]=65071,--Grumpy
[136900]=65111,--Hateful Eye
[139776]=71003,--Horde Fanatic
[140261]=71938,--Hungering Claw
[136911]=59042,--Knockoff Blingtron
[140323]=71980,--Lagan
[129960]=70125,--Leather Pet Bed
[137933]=70125,--Leather Pet Bed(Recipe)
[136914]=66212,--Leyline Broodling
[139791]=71826,--Lurking Owl Kitten
[140741]=72085,--Nightmare Lasher
[140761]=72461,--Nightmare Treant
[136903]=71945,--Nightmare Whelpling
[129878]=65090,--Nightwatch Swooper
[136897]=65091,--Northern Hawk Owl
[129826]=65130,--Nursery Spider
[141316]=72660,--Squirky
[129798]=65638,--Plump Jelly
[130154]=65091,--Pygmy Owl
[136913]=66210,--Red Broodling
[141352]=70663,--Rescued Fawn
[136905]=65667,--Ridgeback Piglet
[130166]=66157,--Risen Saber Kitten
[140274]=55291,--River Calf
[136904]=65637,--Sewer-Pipe Jelly
[129277]=62216,--Skyhorn Nestling
[141530]=73093,--Snowfang
[129108]=65527,--Son of Goredome
[140670]=58170,--Souvenir Elekk
[141205]=59818,--Souvenir Murloc
[140671]=72238,--Souvenir Raptor
[138810]=70937,--Sting Ray Pup
[129208]=67250,--Stormborne Whelpling
[136920]=69254,--Sunborne Val'kyr
[136908]=65671,--Thaumaturgical Piglet
[130167]=66147,--Thistleleaf Adventurer
[136902]=65121,--Dream Whelpling
[139789]=71828,--Transmutant
[132519]=68666,--Trigger
[136921]=68666,--Trigger
[139790]=71827,--Untethered Wyrmling
[141348]=72900,--Wonderous Wisdomball
--[131737]=,--Wyrmy Tunkins
[136922]=69532,--Wyrmy Tunkins
[137298]=69896,--Zoom
--7.1.0
[142448]=74036,--Albino Buzzard
[142091]=73689,--Snaplasher
[142099]=73708,--Wicked Soul
[142098]=73707,--Drudge Ghoul
[142380]=73245,--Dutiful Gruntling
[142379]=73244,--Dutiful Squire
[142094]=73697,--Boneshard
[142083]=73661,--Dreadmaw
[142089]=29819,--Sanctum Cub
[141714]=73308,--Igneous Flameling
[142087]=26740,--Ironbound Proto-Whelp
[142084]=73663,--Snobold Runt
[142085]=59766,--Nerubian Swarmer
[141532]=28726,--Noblegarden Bunny
[142090]=73684,--Winter Rageling
[142092]=73692,--G0-R41-0N Ultratonk
[142096]=73704,--Blightbreath
[142086]=73671,--Magma Rageling
[142095]=73699,--Blood Boil
[142097]=73706,--Soulbroken Whelpling
[142100]=68857,--Stardust
[142088]=73673,--Runeforged Servitor
[142093]=73694,--Creeping Tentacle
--7.1.5
[143842]=74520,--Trashy
[143953]=74657,--Infinite Hatchling
[143954]=74700,--Paradox Spirit
[144394]=59026,--Tylarr Gronnden
--7.2
[143756]=74468,--Everliving Spore
[143755]=74472,--Young Venomfang
[143754]=74469,--Cavern Moccasin
[146417]=65071,--Grumpy
[147539]=75315,--Bloodbrood Whelpling
[147540]=75316,--Frostbrood Whelpling
[147841]=68861,--Orphaned Felbat
[147542]=75989,--Ban-Fu, Cub of Ban-Lu
[143679]=58823,--Crackers
[146953]=75766,--Scraps
[147543]=76262,--Son of Skum
[147541]=75317,--Vilebrood Whelpling
--7.2.5
[101426]=78587,--Micronax
[150739]=75498,--Pocket Cannon
[151632]=78106,--Mining Monkey
[151828]=78261,--Summon Ageless Bronze Drake
[151829]=78222,--Summon Bronze Proto-Whelp
[150741]=76956,--Tricorne
[151569]=1072,--Sneaky Marmot
[151633]=1418,--Dig Rat
[150742]=45555,--Pet Reaper 50
--7.3
[152963]=79712,--Amalgam of Destruction
[152974]=79639,--Drafty
[152976]=45289,--Cinderweb Recluse
[153026]=79777,--Cross Gazer
[153054]=79796,--Docile Skyfin
[152980]=71972,--Corrupted Blood
[152967]=79634,--Discarded Experiment
[152978]=38283,--Infernal Pyreclaw
[153045]=79783,--Fel Lasher
[153055]=79797,--Fel-Afflicted Skyfin
[153040]=78451,--Felclaw Marsuul
[153057]=79798,--Fossorial Bile Larva
[152555]=78989,--Ghost Shark
[153056]=79760,--Grasping Manifestation
[152970]=79637,--Bound Stream
[151645]=74513,--Dibbler
[151269]=74514,--Naxxy
[152969]=79635,--Twilight Clutch-Sister
[153027]=79776,--Orphaned Marsuul
[152979]=65888,--Faceless Mindlasher
[153252]=79888,--Rebellious Imp
[152966]=79630,--Tinytron
[152981]=79711,--Unstable Tendril
[152968]=24751,--Rattlejaw
[152975]=79707,--Blazehound
[147900]=76595,--Twilight
[152972]=79638,--Faceless Minion
[153195]=76829,--Uuna
[152977]=79709,--Surger
[152973]=79641,--Zephyrian Prince
--7.3.5
[156721]=82391,--Mailemental
[151234]=77501,--Shadow
[156851]=82688,--Silithid Mini-Tank
--8.0.1
[163489]=78239,--Abyssal Eel
[163506]=80852,--Accursed Hexxer
[163650]=87870,--Aldrusian Sproutling
[163689]=87903,--Ragepeep
[162578]=80456,--Baa'l
[163859]=83653,--Baby Crawg
[163858]=80458,--Slippy
[163799]=88012,--Pet Template
[163511]=75381,--Barnacled Hermit Crab
[163500]=80460,--Bloodfeaster Larva
[163818]=88005,--Bloodstone Tunneler
[163493]=80951,--Bloody Rabbit Fang
[163244]=87760,--Brutus
[163974]=87998,--Bucketshell
[163508]=86529,--Butterfly in a Jar
[163798]=88016,--Pet Template
[163504]=78161,--Child of Jani
[163823]=86463,--Coldlight Surfrunner
[163513]=81099,--Cou'pa
[163805]=88002,--Pet Template
[163510]=81058,--Crimson Frog
[156566]=81984,--Dart
[163809]=88040,--Pet Template
[162686]=80456,--REUSE
[163553]=83052,--Digitized Assistant
[163634]=79567,--Dreadtick Leecher
[163555]=84157,--Drop of Azerite
[163492]=27682,--Drustvar Piglet
[152878]=86482,--Summon Enchanted Tiki Mask
[158077]=75339,--Francois
[163806]=26524,--Pet Template
[160704]=86101,--Summon Filthy Slime
[163554]=83052,--Finicky Gauntlet
[163509]=76624,--Freshwater Pincher
[163648]=87862,--Fuzzy Creepling
[163557]=83052,--Gigan Tarantula
[163811]=88058,--Pet Template
[163495]=80414,--Greatwing Macaw Feather
[163218]=74515,--Hearthy
--[154703]=,--Hot Air Balloon - Pet (NEEDS NAME)
[163802]=88034,--Pet Template
[160940]=86231,--Summon Vengeful Chicken
[161080]=86484,--Summon Direhorn Hatchling
[163821]=88007,--Juvenile Brineshell
[163804]=88001,--Pet Template
[163822]=88008,--Kunchong Hatchling
[163776]=81972,--Large Honeycomb Cluster
[163812]=88060,--Pet Template
[163502]=83641,--Lil' Ben'fon
[163778]=87976,--Lil' Siege Tower
[161016]=86445,--Summon Lil' Tika
[163779]=87977,--Lil' War Machine
[163815]=88061,--Pet Template
[163568]=83685,--Lost Platysaur
[163712]=16880,--Squawkling
[163556]=83052,--Mechanized Gulper
[163814]=88059,--Pet Template
[163820]=88036,--Muskflank Calfling
[163801]=88017,--Pet Template
[163490]=81966,--Pair of Bee Wings
[161089]=86806,--Summon Restored Revenant
[163690]=74038,--Foulfeather
[163813]=88057,--Pet Template
[158464]=86136,--Summon Poda
[163800]=88003,--Pet Template
[163491]=81079,--Pristine Falcon Feather
[163559]=83052,--Queen Cobra
[163503]=76383,--Ranishu Runt
[163499]=84863,--Raptor Containment Crate
[152880]=69490,--Enchanted Cauldron
[152879]=69490,--Enchanted Cauldron
[163220]=75349,--Rooter
[163808]=88038,--Pet Template
[163512]=80029,--Sandstinger Wasp
[163560]=81219,--Saurolisk Hatchling
[163684]=87895,--Scabby
[163797]=87999,--Pet Template
[163515]=83052,--Shard of Azerite
[163711]=87945,--Fozling
[163975]=87997,--Sir Snips
[160708]=86135,--Summon Smoochums
[160847]=86229,--Summon Guardian Cobra Hatchling
[163816]=81098,--Pet Template
[163819]=88035,--Snort
[163803]=88000,--Pet Template
[160702]=86088,--Summon Spawn of Merektha
[163497]=86805,--Spooky Bundle of Sticks
[163496]=75353,--Strange Looking Mechanical Squirrel
[163817]=88064,--Sunscale Hatchling
[161081]=86488,--Summon Taptaf
[163677]=87890,--Teeny Titan Orb
[163810]=45190,--Pet Template
[161214]=86574,--Summon Mummy
[163807]=88004,--Pet Template
[163498]=84857,--Tiny Direhorn
[163652]=87871,--Voidwiggler
[163505]=76761,--Toad in a Box
[163501]=88468,--Tragg the Curious
[163861]=80458,--Bloodfeaster Larva
[163514]=80467,--Violent Looking Flower Pot
[163824]=88037,--Voru'kar Leecher
[163494]=69092,--Wad of Spider Web
[163860]=78837,--Gearspring Hopper
[160588]=86021,--Cap'n Crackers
--8.1
[166714]=77901,--Albatross Hatchling
[166491]=80967,--Albino Duskwatcher
[166486]=66487,--Baby Stonehide
[166448]=5187,--Gust of Cyclarus
[166452]=23000,--Hydrath Water Droplet
[166718]=36743,--Cobalt Raven
[166500]=88023,--Crimson Octopode
[166449]=90155,--Darkshore Sentinel
[165846]=30298,--Child of Pa'ku
[166453]=90140,--Everburning Treant
[166493]=90181,--Firesting Buzzer
[166487]=90173,--Leatherwing Screecher
[165855]=88785,--Leper Rat
[166494]=90182,--Lord Woofington
[165854]=88790,--Mechanical Cockroach
[165845]=80802,--Feathers
[165849]=90411,--Mechantula
[165844]=90411,--Mechantula(Recipe)
[165894]=31623,--Mini Spider Tank
[166489]=90177,--Needleback Pup
[166528]=90230,--Nightwreathed Watcher
[166716]=80954,--Crimson Bat Pup
[166791]=81079,--Pristine Falcon Feather
[166358]=80413,--Proper Parrot
[166451]=81665,--Detective Ray
[166715]=90279,--Rebuilt Gorilla Bot
[166723]=90412,--Rebuilt Mechanical Spider
[165857]=89767,--Alarm-O-Dog
[165722]=89609,--Redridge Tarantula
[166488]=90176,--Rotting Ghoul
[166498]=90183,--Scritches
[166492]=80966,--Shadefeather Hatchling
[165848]=77989,--Spawn of Krag'wa
[166454]=90141,--Void Jelly
[166347]=90030,--Tanzil
[165847]=89742,--Thunder Lizard Runt
[166499]=90184,--Thunderscale Whelpling
[166495]=76763,--Tonguelasher
[166346]=90029,--Trecker
[166719]=78243,--Violet Abyssal Eel
[160587]=86020,--Summon Whomper
[165907]=86573,--Wicker Wraith
[166345]=90028,--Dasher
[166455]=90142,--Zur'aj the Depleted
--8.1.5
[167055]=42520,--Amber Goo Puddle
[167051]=44445,--Azure Cloud Serpent Egg
[167010]=81097,--Beakbert
[167049]=90830,--Celestial Gift
[167009]=81213,--Enchanted Saurolisk Scale
[167056]=50919,--Essence of Pride
[167057]=90866,--Happiness
[164969]=89260,--Horse Balloon
[167058]=45274,--Kor'thik Swarmling
[167050]=47859,--Mogu Statue
[164971]=89262,--Murloc Balloon
[154902]=58823,--Perculia's Peculiar Parrot
[167008]=82003,--Sandy Hermit Crab Shell
[167011]=78849,--Slimy Pouch
[167054]=90745,--Spawn of Garalon
[167052]=39739,--Spirit of the Spring
[167047]=40155,--Stoneclaw
[167053]=90867,--Tiny Amber Wings
[167048]=90715,--Wayward Spirit
[164970]=89261,--Wolf Balloon
--8.2
[169322]=92073,--Adventurous Hopling
[169363]=90519,--Amethyst Softshell
[169393]=90413,--Arachnoid Skitterbot
[170072]=92502,--Armored Vaultbot
[169392]=81215,--Bonebiter
[169354]=92156,--Brilliant Glimmershell
[169373]=90991,--Brinestone Algan
[169374]=90993,--Budding Algan
[170102]=92580,--Burnout
[169356]=91024,--Caverndark Nightmare
[169357]=91021,--Chitterspine Devourer
[169355]=91027,--Chitterspine Needler
[169676]=10723,--Shrieker
[169375]=80466,--Coral Lashling
[169677]=9758,--Crypt Fiend
[169361]=90944,--Daggertooth Frenzy
[169365]=91111,--Damplight Slug
[169377]=92162,--Drowned Hatchling
[169396]=91656,--Echoing Oozeling
[169670]=92265,--Minimancer
[169205]=6290,--Ghostly Whelpling
[169350]=75367,--Glittering Diamondshell
[169195]=88784,--Golden Cricket
[169378]=88764,--Golden Snorf
[169349]=88874,--Kelpfin
[169358]=91028,--Lightless Ambusher
[169382]=74801,--Lost Robogrip
[169353]=90868,--Lustrous Glimmershell
[169879]=80254,--Irradiated Elementaling
[169385]=90874,--Microbot 8D
[169384]=90878,--Microbot XD
[169360]=90513,--Mindlost Bloodfrenzy
[169371]=91235,--Murgle
[169380]=88766,--Mustyfur Snooter
[169362]=88019,--Nameless Octopode
[169372]=86465,--Necrofin Tadpole
[169381]=75332,--OOX-35/MG
[169352]=92157,--Pearlescent Glimmershell
[169364]=90515,--Prismatic Softshell
[169351]=75374,--Sandclaw Nestseeker
[169369]=47252,--Sandkeep
[169370]=92159,--Scalebrood Hydra
[169367]=88619,--Seafury
[169376]=92158,--Skittering Eel
[167809]=91224,--Slimy Darkhunter
[167808]=91249,--Slimy Eel
[167807]=91248,--Slimy Fangtooth
[167810]=91220,--Slimy Hermit Crab
[167806]=91232,--Slimy Octopode
[167805]=91250,--Slimy Otter
[167804]=91219,--Slimy Sea Slug
[169679]=92266,--Gruesome Belcher
[169379]=88761,--Snowsoft Nibbler
[169359]=78240,--Spawn of Nalaada
[169886]=91631,--Spraybot 0D
[169368]=50613,--Stormwrath
[169383]=74800,--Utility Mechanoclaw
[169366]=91114,--Wriggler
[169348]=88873,--Zanj'ir Poker
[169678]=23057,--Ziggy

},
[3] = {
------------------------------------------
--**************************************--
--************* FOLLOWERS **************--
--**************************************--
------------------------------------------
--6.0.1
[112848]=463,--Daleera Moonfang
[119161]=459,--Karg Bloodfury
[119165]=460,--Professor Felblast
[119166]=458,--Cacklebone
[119167]=458,--Vindicator Heluun
[112737]=153,--Ka'la
[119162]=459,--Cleric Maluuf
[114825]=463,--Ulna Thresher
[114826]=153,--Bruma Swiftstone
--[119164]=,--Arakkoa Outcasts Follower
--[119168]=,--Vol'jin's Spear Follower
--[119169]=,--Wrynn's Vanguard Follower
--6.0.2
[119256]=211,--Glirin
[119248]=462,--Dawnseeker Rukaryx
[119240]=185,--Lokra
[119242]=154,--Magister Serena
[119243]=154,--Magister Krelas
[119244]=453,--Hulda Shadowblade
[119245]=453,--Dark Ranger Velonara
[119252]=212,--Rangari Erdanii
[119253]=212,--Spirit of Bony Xuk
[119254]=176,--Pitfighter Vaandaam
[119255]=176,--Bruto
[119233]=159,--Kaz the Shrieker
[119257]=211,--Penny Clobberbottom
[119267]=168,--Ziri'ak
[119288]=463,--Daleera Moonfang
[119291]=184,--Artificer Andren
[119292]=186,--Vindicator Onaala
[119296]=185,--Rangari Chel
[119298]=159,--Ranger Kaalya
[119418]=155,--Morketh Bladehowl
[119420]=155,--Miall
[119821]=462,--Dawnseeker Rukaryx
--6.1
[122135]=186,--Greatmother Geyah
[122136]=184,--Kal'gor the Honorable
[122137]=153,--Bruma Swiftstone
[122138]=463,--Ulna Thresher
--6.2
[128439]=580,--Pallas
[128440]=581,--Dowser Goodwell
[128441]=582,--Solar Priest Vayx
[128445]=581,--Dowser Bigspark
------------------------------------------
--**************************************--
--*************** SHIPS ****************--
--**************************************--
------------------------------------------
--6.2
[128487]=583,--The Awakener
[128488]=583,--The Awakener
},
[4] = {
------------------------------------------
--**************************************--
--************* CONTAINERS *************--
--**************************************--
------------------------------------------
		--8.1
		[166525]={--Nightwreathed Egg
			{289359},--Nightwreathed Watcher
		},
		--8.0.1
		[160832]={--Viable Cobra Egg
			{160831, mp.i},--Cracking Cobra Egg
		},
		[160831]={--Cracking Cobra Egg
			{273159},--Spawn of Merektha
		},
		[160325]={--Quivering Sac
			{280619},--Slippy
			{279435},--Baby Crawg
			{280617},--Gearspring Hopper
			{280618},--Bloodfeaster Larva
		},
		[160324]={--Grumbling Sac
			{280619},--Slippy
			{279435},--Baby Crawg
			{280617},--Gearspring Hopper
			{280618},--Bloodfeaster Larva
		},
		--7.3
		[151638]={--Leprous Sack of Pet Supplies
			{233647},--Dibbler
		},
		[153190]={--Fel-Spotted Egg
			{153191, mp.i},--Cracked Fel-Spotted Egg
		},
		[153191]={--Cracked Fel-Spotted Egg
			{254296},--Fel-Afflicted Skyfin
			{254295},--Docile Skyfin
			{253106},--Vibrant Mana Ray
			{235764},--Darkspore Mana Ray
			{253108},--Felglow Mana Ray
			{253109},--Scintillating Mana Ray
		},
		[152923]={--Gleaming Footlocker
			{254259},--Avenging Felcrusher
			{254258},--Blessed Felcrusher
			{254069},--Glorious Felcrusher
		},
		--7.2.5
		[151482]={--Time-Lost Wallet
			{248240},--Ageless Bronze Drake
			{248025},--Bronze Proto-Whelp
		},
		--7.2
		[147361]={--Legionfall Chest
			{243136},--Orphaned Felbat
		},
		[146900]={--Nightfallen Cache
			{233364},--Leywoven Flying Carpet
		},
		[146901]={--Valarjar Strongbox
			{242882},--Valarjar Stormwing
		},
		[146897]={--Farondis Chest
			{242881},--Cloudwing Hippogryph
		},
		[146899]={--Highmountain Supplies
			{242874},--Highmountain Elderhorn
		},
		[146898]={--Dreamweaver Cache
			{242875},--Wild Dreamrunner
		},
		[143753]={--Damp Pet Supplies
			{233331},--Everliving Spore
			{233333},--Cavern Moccasin
			{233335},--Young Venomfang
		},
		--7.1
		[142381]={--Oath of Fealty
			{230443},--Dutiful Squire
			{230444},--Dutiful Gruntling
		},
		--7.0.3
		[137608]={--Growling Sac
			{210681},--Thaumaturgical Piglet
			{210678},--Ridgeback Piglet
			{221906},--Transmutant
		},
		[139777]={--Strange Crate
			{221684},--Alliance Enthusiast
			{221683},--Horde Fanatic
		},
		[132892]={--Blingtron 6000 Gift Package
			{147124},--Lil' Bling
		},
		--6.2.2
		[128670]={--Savage Gift
			{191314},--Minion of Grumpus
		},
		--6.2
		[127751]={--Fel-Touched Pet Supplies
			{185055},--Nightmare Bell
			{187555},--Periwinkle Calf
			{173544},--Seaborne Spore
			{173532},--Zangar Spore
		},
		[128025]={--Rattling Iron Cage
			{171837},--Warsong Direfang
			{171619},--Tundra Icehoof
			{171630},--Armored Razorback
		},
		--6.1
		[122535]={--Traveler's Pet Supplies
			{177238},--Bone Serpent
			{177223},--Slithershock Elver
			{177218},--Young Talbuk
		},
		--6.0.1
		[113258]={--Blingtron 5000 Gift Package
			{147124},--Lil' Bling
			{170292},--Sky-Bo
			{82173},--De-Weaponized Mechanical Companion
			{162135},--Lifelike Mechanical Frostboar
			{160403},--Mechanical Axebeak
			{126885},--Mechanical Pandaren Dragonling
			{170288},--Mechanical Scorpid
			{81937},--Personal World Destroyer
			{126507},--Depleted-Kyparium Rocket
			{126508},--Geosynchronous World Spinner
			{60424, nil, format(" (%s)", FACTION_ALLIANCE)},--Mekgineer's Chopper
			{55531, nil, format(" (%s)", FACTION_HORDE)},--Mechano-Hog
		},
		[112107]={--Mysterious Egg
			{112108, mp.i},--Cracked Egg
		},
		[112108]={--Cracked Egg
			{170285},--Fruit Hunter
		},
		[116980]={--Invader's Forgotten Treasure
			{171635},--Giant Coldsnout
			{171624},--Shadowhide Pearltusk
			{171843},--Smoky Direwolf
			{171836},--Garn Steelmaw
		},
		[116404]={--Pilgrim's Bounty
			{171500},--Bush Chicken
		},
		[118697]={--Big Bag of Pet Supplies
			{170291},--Firewing
			{167731},--Ghastly Kid
			{177227},--Sunfire Kaliri
			{167397},--Sun Sproutling
			{170279},--Puddle Terror
			{158261},--Weebomination
			{177212},--Albino Chimaeraling
		},
		[116062]={--Greater Darkmoon Pet Supplies
			{170774},--Syd the Squid
		},
		--5.4
		[103632]={--Lucky Box of Greatness
			{30174},--Lucky Riding Turtle
		},
		--Winter Veil 2013
		[104319]={--Winter Veil Gift
			--{148577, " (2013)"},--Crashin' Thrashin' Flyer
			{65451, nil, " (2010)"},--MiniZep
			--{49352, " (2008)"},--Crashin' Thrashin' Racer
			{54187, nil, " (2007)"},--Clockwork Rocket Bot
		},
		[116762]={--Stolen Present
			{148567, nil, " (2013)"},--Rotten Little Helper
			{103125, nil, " (2012)"},--Lumpy
			{65451, nil, " (2010)"},--MiniZep
			--{49352, " (2008)"},--Crashin' Thrashin' Racer
			{54187, nil,  " (2007)"},--Clockwork Rocket Bot
			--{75111},--Blue Crashin' Thrashin' Racer
			{75134},--Blue Clockwork Rocket Bot
			{62949},--Wind-Up Train Wrecker
			{61022},--Heavy Copper Racer
			{61021},--Zippy Copper Racer
			{60838},--Trusty Copper Racer
			{60832},--Grindgear Toy Gorilla
		},
		--5.2
		[94295]={--Primal Egg
			{94296, mp.i},--Cracked Primal Egg
		},
		[94296]={--Cracked Primal Egg
			{138643},--Green Primal Raptor
			{138642},--Black Primal Raptor
			{138641},--Red Primal Raptor
		},
		[93724]={--Darkmoon Game Prize
			{135025},--Darkmoon "Murloc"
			{135026},--Darkmoon "Rocket"
			{135027},--Darkmoon "Wyvern"
			{135022},--Darkmoon "Dragon"
			{135023},--Darkmoon "Gryphon"
			{135009},--Darkmoon "Cougar"
			{135007},--Darkmoon "Snow Leopard"
			{135008},--Darkmoon "Nightsaber"
			{107926},--Darkmoon "Tiger"
			{103076},--Darkmoon Balloon
			{103544},--Darkmoon Tonk
			{103074},--Darkmoon Turtle
			{105122},--Darkmoon Cub
			{101733},--Darkmoon Monkey
			{103549},--Darkmoon Zeppelin
			{132762},--Darkmoon Hatchling
		},
		--5.2
		[94207]={--Fabled Pandaren Pet Supplies
			{138382},--Mountain Panda
			{138381},--Snowy Panda
			{138380},--Sunfur Panda
		},
		--5.1
		[92960]={--Silkworm Cocoon
			{132580},--Imperial Silkworm
			{132574},--Imperial Moth
		},
		[91086]={--Darkmoon Pet Supplies
			{132789},--Darkmoon Eye
		},
		[93149]={--Pandaren Spirit Pet Supplies
			{134895},--Pandaren Earth Spirit
		},
		[93147]={--Pandaren Spirit Pet Supplies
			{131590},--Pandaren Water Spirit
		},
		[93146]={--Pandaren Spirit Pet Supplies
			{134892},--Pandaren Fire Spirit
		},
		[93148]={--Pandaren Spirit Pet Supplies
			{134894},--Pandaren Air Spirit
		},
		--5.0.1
		[85497]={--Chirping Package
			{123784},--Red Cricket
		},
		[86623]={--Blingtron 4000 Gift Package
			{147124},--Lil' Bling-
			{170292},--Sky-Bo
			{82173},--De-Weaponized Mechanical Companion-
			{19772},--Lifelike Toad
			{15049},--Lil' Smoky
			{126885},--Mechanical Pandaren Dragonling
			{4055},--Mechanical Squirrel
			{81937},--Personal World Destroyer
			{15048},--Pet Bombling
			{26010},--Tranquil Mechanical Yeti
			{126507},--Depleted-Kyparium Rocket
			{126508},--Geosynchronous World Spinner
			{60424, nil, format(" (%s)", FACTION_ALLIANCE)},--Mekgineer's Chopper
			{55531, nil, format(" (%s)", FACTION_HORDE)},--Mechano-Hog
		},
		--4.3
		[77956]={--Spectral Mount Crate
			{107516, nil, format(" (%s)", FACTION_ALLIANCE)},--Spectral Gryphon
			{107517, nil, format(" (%s)", FACTION_HORDE)},--Spectral Wind Rider
		},
		--4.2
		[71631]={--Zen'Vorka's Cache
			{45890},--Searing Scorchling
		},
		--4.0.3
		[61387]={--Hidden Stash
			{93739},--Mr. Grubbs
		},
		[68384]={--Moonkin Egg
			{95786, nil, format(" (%s)", FACTION_ALLIANCE)},--Moonkin Hatchling
			{95909, nil, format(" (%s)", FACTION_HORDE)},--Moonkin Hatchling
		},
		[64657]={--Canopic Jar
			{93326},--Sandstone Drake
		},
		--4.0.1
		[54516]={--Loot-Filled Pumpkin
			{42609},--Sinister Squashling
			{47977},--Magic Broom
			{42667},--Flying Broom
			{48025},--Headless Horseman's Mount
		},
		[67414]={--Bag of Shiny Things
			{62561},--Strand Crawler
		},
		--3.3.3
		[54535]={--Keg-Shaped Treasure Chest
			{49379},--Great Brewfest Kodo
			{43900},--Swift Brewfest Ram
		},
		[54536]={--Satchel of Chilled Goods
			{74932},--Frigid Frostling
		},
		[54537]={--Heart-Shaped Box
			{71840},--Toxic Wasteling
			{71342},--Big Love Rocket
		},
		[51316]={--Unsealed Chest
			{73313},--Crimson Deathcharger
		},
		--3.3.2
		[52676]={--Cache of the Ley-Guardian
			{59568},--Blue Drake
		},
		--3.3
		[50301]={--Landro's Pet Box
			{62857},--Sandbox Tiger
		},
		--3.1
		[45072]={--Brightly Colored Egg
			{61725},--Spring Rabbit
			{102349},--Swift Springstrider
		},
		[46007]={--Bag of Fishing Treasures
			{62561},--Strand Crawler
		},
		--3.0.2
		[39878]={--Mysterious Egg
			{39883, mp.i},--Cracked Egg
		},
		[39883]={--Cracked Egg
			{61351},--Cobra Hatchling
			{61348},--Tickbird Hatchling
			{61349},--White Tickbird Hatchling
			{61350},--Proto-Drake Whelp
			{61294},--Green Proto-Drake
		},
		[44751]={--Hyldnir Spoils
			{54753},--White Polar Bear
		},
		--2.4.3
		[37586]={--Handful of Treats
			{42609},--Sinister Squashling
			{47977},--Magic Broom
		},
		--2.4
		[35348]={--Bag of Fishing Treasures
			{46426},--Chuck
			{43698},--Muckbreath
			{46425},--Snarly
			{43697},--Toothy
		},
		--2.2.2
		[34077]={--Crudely Wrapped Gift
			{47977},--Magic Broom
		},	
		--1.11.1 and earlier
		[20768]={--Oozing Bag
			{20769},--Disgusting Oozeling
		},
		[21310]={--Gaily Wrapped Present
			{26045},--Tiny Snowman
			{26529},--Winter Reindeer
			{26533},--Father Winter's Helper
			{26541},--Winter's Little Helper
		},
		[21327]={--Ticking Present
			{21325},--Mechanical Greench
			{21213},--Preserved Holly
		},
	},
[5] = {
------------------------------------------
--**************************************--
--**************** TOYS ****************--
--**************************************--
------------------------------------------
	--2.0.1
	[23767]=16970,--Crashin Robot
	[23810]=16970,--Crashin Robot(Recipe)
	--2.4.0
	[34686]=23523,--Brazier of Dancing Flames
	}
}

--Spell Data table--
mp.spellTable = {
------------------------------------------
--**************************************--
--*************** MOUNTS ***************--
--**************************************--
------------------------------------------
--only spells
[48778]=25280,--Acherus Deathcharger
[127180]=43708,--Albino Riding Crane
[127209]=43709,--Black Riding Yak
[127213]=43710,--Brown Riding Yak
[123160]=42837,--Crimson Riding Crane
[127271]=43713,--Crimson Water Strider
[89520]=36022,--Goblin Mini Hotrod
[127278]=43716,--Golden Water Strider
[97501]=38032,--Green Fire Hawk
[127274]=43714,--Jade Water Strider
[127178]=43707,--Jungle Riding Crane
[127272]=43715,--Orange Water Strider
[123182]=41089,--White Riding Yak
[221886]=19085,--Divine Steed (Horde Charger)
[221885]=30501,--Divine Steed (Horde Kodo)
[221883]=14584,--Divine Steed (Alliance Charger)
[221887]=31368,--Divine Steed (Alliance Elekk)
[215545]=68251,--Fel Bat
[200175]=67575,--Felsaber
[276112]=85394,--Divine Steed
[276111]=85395,--Divine Steed
--[301841]=,--Kua'fon
[302796]=92403,--Swift Spectral Armored Gryphon
[302794]=92401,--Swift Spectral Fathom Ray
[302795]=92732,--Swift Spectral Magnetocraft
[302797]=92078,--Swift Spectral Pterrordax
[300152]=34955,--Tidestallion
[300154]=34955,--Tidestallion
--1.11.1 and earlier
[23250]=14573,--Swift Brown Wolf
[26656]=15676,--Black Qiraji Battle Tank
[16056]=9695,--Ancient Frostsaber
[16055]=9991,--Black Nightsaber
[16080]=2326,--Red Wolf
[16081]=1166,--Winter Wolf
[16083]=2410,--White Stallion
[16082]=2408,--Palomino
[17229]=10426,--Winterspring Frostsaber
[17450]=6471,--Ivory Raptor
[15779]=9474,--White Mechanostrider Mod B
[17459]=10666,--Icy Blue Mechanostrider Mod A
[17461]=2784,--Black Ram
[17460]=2787,--Frost Ram
[17465]=10720,--Green Skeletal Warhorse
[17481]=10718,--Rivendare's Deathcharger
[18991]=12245,--Green Kodo
[18992]=12242,--Teal Kodo
[23221]=14331,--Swift Frostsaber
[23219]=14332,--Swift Mistsaber
[23225]=14374,--Swift Green Mechanostrider
[23223]=14376,--Swift White Mechanostrider
[23222]=14377,--Swift Yellow Mechanostrider
[23227]=14582,--Swift Palomino
[23229]=14583,--Swift Brown Steed
[23228]=14338,--Swift White Steed
[23240]=14346,--Swift White Ram
[23238]=14347,--Swift Brown Ram
[23239]=14576,--Swift Gray Ram
[23241]=14339,--Swift Blue Raptor
[23242]=14344,--Swift Olive Raptor
[23243]=14342,--Swift Orange Raptor
[23246]=10721,--Purple Skeletal Warhorse
[23247]=14349,--Great White Kodo
[23249]=14578,--Great Brown Kodo
[23248]=14579,--Great Gray Kodo
[16084]=6469,--Mottled Red Raptor
[23251]=14575,--Swift Timber Wolf
[23252]=14574,--Swift Gray Wolf
[23338]=14632,--Swift Stormsaber
[23509]=14776,--Frostwolf Howler
[23510]=14777,--Stormpike Battle Charger
[24242]=15289,--Swift Razzashi Raptor
[24252]=15290,--Swift Zulian Tiger
[25953]=15672,--Blue Qiraji Battle Tank
[26054]=15681,--Red Qiraji Battle Tank
[26056]=15679,--Green Qiraji Battle Tank
[26055]=15680,--Yellow Qiraji Battle Tank
[10796]=6472,--Turquoise Raptor
[580]=247,--Timber Wolf
[472]=2409,--Pinto
[6648]=2405,--Chestnut Mare
[458]=2404,--Brown Horse
[6653]=2327,--Dire Wolf
[6654]=2328,--Brown Wolf
[6777]=2736,--Gray Ram
[6899]=2785,--Brown Ram
[6898]=2786,--White Ram
[10873]=9473,--Red Mechanostrider
[8395]=4806,--Emerald Raptor
[470]=2402,--Black Stallion
[10799]=6473,--Violet Raptor
[10969]=6569,--Blue Mechanostrider
[10793]=6448,--Striped Nightsaber
[8394]=6080,--Striped Frostsaber
[10789]=6444,--Spotted Frostsaber
[17453]=10661,--Green Mechanostrider
[17454]=9476,--Unpainted Mechanostrider
[17462]=10670,--Red Skeletal Horse
[17463]=10671,--Blue Skeletal Horse
[17464]=10672,--Brown Skeletal Horse
[18989]=12246,--Gray Kodo
[18990]=11641,--Brown Kodo
--2.0
[30174]=17158,--Riding Turtle
--2.0.1
[32246]=17719,--Swift Red Wind Rider
[32296]=17722,--Swift Yellow Wind Rider
[32297]=17721,--Swift Purple Wind Rider
[32295]=17720,--Swift Green Wind Rider
[32235]=17697,--Golden Gryphon
[32239]=17694,--Ebon Gryphon
[32240]=17696,--Snowy Gryphon
[32243]=17699,--Tawny Wind Rider
[32244]=17700,--Blue Wind Rider
[32245]=17701,--Green Wind Rider
[39316]=21074,--Dark Riding Talbuk
[33660]=18697,--Swift Pink Hawkstrider
[34896]=19375,--Cobalt War Talbuk
[34897]=19377,--White War Talbuk
[34898]=19378,--Silver War Talbuk
[34899]=19376,--Tan War Talbuk
[35025]=19484,--Swift Green Hawkstrider
[35027]=19482,--Swift Purple Hawkstrider
[34896]=19375,--Cobalt War Talbuk
[34790]=19303,--Dark War Talbuk
[34898]=19378,--Silver War Talbuk
[34899]=19376,--Tan War Talbuk
[34897]=19377,--White War Talbuk
[22719]=14372,--Black Battlestrider
[22718]=14348,--Black War Kodo
[22720]=14577,--Black War Ram
[22717]=14337,--Black War Steed
[22724]=14334,--Black War Wolf
[22722]=10719,--Red Skeletal Warhorse
[22723]=14330,--Black War Tiger
[22721]=14388,--Black War Raptor
[35713]=19871,--Great Blue Elekk
[35712]=19873,--Great Green Elekk
[35714]=19872,--Great Purple Elekk
[36702]=19250,--Fiery Warhorse
[39315]=21073,--Cobalt Riding Talbuk
[39315]=21073,--Cobalt Riding Talbuk
[39317]=21075,--Silver Riding Talbuk
[39317]=21075,--Silver Riding Talbuk
[39318]=21077,--Tan Riding Talbuk
[39318]=21077,--Tan Riding Talbuk
[39319]=21076,--White Riding Talbuk
[39319]=21076,--White Riding Talbuk
[34406]=17063,--Brown Elekk
[34795]=18696,--Red Hawkstrider
[35020]=19480,--Blue Hawkstrider
[35022]=19478,--Black Hawkstrider
[35018]=19479,--Purple Hawkstrider
[35711]=19870,--Purple Elekk
[35710]=19869,--Gray Elekk
--2.1
[39803]=21156,--Blue Riding Nether Ray
[32242]=17759,--Swift Blue Gryphon
[32290]=17703,--Swift Green Gryphon
[32292]=17717,--Swift Purple Gryphon
[39798]=21152,--Green Riding Nether Ray
[39801]=21155,--Purple Riding Nether Ray
[39800]=21158,--Red Riding Nether Ray
[39802]=21157,--Silver Riding Nether Ray
[32289]=17718,--Swift Red Gryphon
[41513]=21520,--Onyx Netherwing Drake
[41546]=21520,--Onyx Netherwing Drake(Recipe)
[41514]=21521,--Azure Netherwing Drake
[41547]=21521,--Azure Netherwing Drake(Recipe)
[41515]=21525,--Cobalt Netherwing Drake
[41543]=21525,--Cobalt Netherwing Drake(Recipe)
[41516]=21523,--Purple Netherwing Drake
[41544]=21523,--Purple Netherwing Drake(Recipe)
[41517]=21522,--Veridian Netherwing Drake
[41549]=21522,--Veridian Netherwing Drake(Recipe)
[41518]=21524,--Violet Netherwing Drake
[41548]=21524,--Violet Netherwing Drake(Recipe)
[41252]=21473,--Raven Lord
--2.1.1
[40192]=17890,--Ashes of Al'ar
--2.1.2
[37015]=20344,--Swift Nether Drake
--2.2
[43900]=22350,--Swift Brewfest Ram
[43899]=22265,--Brewfest Ram
--2.2.2
[42668]=21939,--Swift Flying Broom
[42668]=21939,--Swift Magic Broom
[42667]=21939,--Flying Broom
--2.3
[32345]=17890,--Peep the Phoenix Mount
[43688]=22464,--Amani War Bear
[43927]=22473,--Cenarion War Hippogryph
[44151]=22720,--Turbo-Charged Flying Machine
[44157]=22720,--Turbo-Charged Flying Machine(Recipe)
[44744]=22620,--Merciless Nether Drake
[44153]=22719,--Flying Machine
[44155]=22719,--Flying Machine(Recipe)
[35028]=20359,--Swift Warstrider
--2.4
[46628]=19483,--Swift White Hawkstrider
[48027]=23928,--Black War Elekk
--2.4.2
[49193]=24725,--Vengeful Nether Drake
--2.4.3
[58615]=27507,--Brutal Nether Drake
[49322]=24745,--Swift Zhevra
[49379]=24757,--Great Brewfest Kodo
[48025]=25159,--Headless Horseman's Mount
[58983]=27567,--Big Blizzard Bear
[47977]=21939,--Magic Broom
[66050]=22265,--Fresh Dwarven Brewfest Hops
[66051]=24758,--Fresh Goblin Brewfest Hops
--3.0.1
[55531]=25871,--Mechano-Hog
[60866]=25871,--Mechano-Hog(Recipe)
[54729]=28108,--Winged Steed of the Ebon Blade
--3.0.2
[60424]=25870,--Mekgineer's Chopper
[60867]=25870,--Mekgineer's Chopper(Recipe)
[64749]=17697,--Loaned Gryphon Reins
[60126]=17697,--Loaned Gryphon Reins(Recipe)
[64762]=17699,--Loaned Wind Rider Reins
[60128]=17699,--Loaned Wind Rider Reins(Recipe)
[60002]=28045,--Time-Lost Proto-Drake
[59567]=27785,--Azure Drake
[59571]=27796,--Twilight Drake
[59570]=25835,--Red Drake
[59569]=25833,--Bronze Drake
[59996]=28041,--Blue Proto-Drake
[59568]=25832,--Blue Drake
[60025]=25836,--Albino Drake
[61309]=28060,--Magnificent Flying Carpet
[60971]=28060,--Magnificent Flying Carpet(Recipe)
[61229]=27913,--Armored Snowy Gryphon
[61230]=27914,--Armored Blue Wind Rider
[59650]=25831,--Black Drake
[61451]=28082,--Flying Carpet
[60969]=28082,--Flying Carpet(Recipe)
[60118]=27818,--Black War Bear
[59785]=27247,--Black War Mammoth
[61470]=27242,--Grand Ice Mammoth
[54753]=28428,--White Polar Bear
[59788]=27245,--Black War Mammoth
[59797]=27246,--Ice Mammoth
[61469]=27239,--Grand Ice Mammoth
[59799]=27248,--Ice Mammoth
[60119]=27819,--Black War Bear
[60114]=27820,--Armored Brown Bear
[60116]=27821,--Armored Brown Bear
[59791]=27243,--Wooly Mammoth
[59793]=27244,--Wooly Mammoth
[61447]=27238,--Traveler's Tundra Mammoth
[61425]=27237,--Traveler's Tundra Mammoth
--3.0.3
[59961]=28044,--Red Proto-Drake
[61294]=28053,--Green Proto-Drake
[61465]=27241,--Grand Black War Mammoth
--3.0.8
[60021]=28042,--Plagued Proto-Drake
--3.0.9
[59976]=28040,--Black Proto-Drake
[61467]=27240,--Grand Black War Mammoth
--3.1
[64731]=29161,--Sea Turtle
[61996]=27525,--Blue Dragonhawk
[63796]=28890,--Mimiron's Head
[63844]=22471,--Argent Hippogryph
[61997]=28402,--Red Dragonhawk
[63232]=28912,--Stormwind Steed
[63636]=29258,--Ironforge Ram
[63638]=28571,--Gnomeregan Mechanostrider
[63639]=29255,--Exodar Elekk
[63637]=29256,--Darnassian Nightsaber
[63641]=29259,--Thunder Bluff Kodo
[63635]=29261,--Darkspear Raptor
[63640]=29260,--Orgrimmar Wolf
[63642]=29262,--Silvermoon Hawkstrider
[63643]=29257,--Forsaken Warhorse
[64656]=10718,--Blue Skeletal Warhorse
[64658]=207,--Black Wolf
[64657]=12241,--White Kodo
[64977]=29130,--Black Skeletal Horse
--3.1.1
[65439]=25593,--Furious Gladiator's Frost Wyrm
--3.1.2
[63963]=28954,--Rusted Proto-Drake
[65640]=29043,--Swift Gray Steed
[65638]=14333,--Swift Moonsaber
[65637]=28606,--Great Red Elekk
[65645]=28605,--White Skeletal Warhorse
[65644]=14343,--Swift Purple Raptor
[65643]=28612,--Swift Violet Ram
[65646]=14335,--Swift Burgundy Wolf
[65641]=28556,--Great Golden Kodo
[65639]=28607,--Swift Red Hawkstrider
[65642]=14375,--Turbostrider
--3.1.3
[63956]=28953,--Ironbound Proto-Drake
--3.2
[60024]=28043,--Violet Proto-Drake
[66087]=22474,--Silver Covenant Hippogryph
[66088]=29696,--Sunreaver Dragonhawk
[46199]=23647,--X-51 Nether-Rocket X-TREME
[64927]=25511,--Deadly Gladiator's Frost Wyrm
[46197]=23656,--X-51 Nether-Rocket
[64659]=29102,--Venomhide Ravasaur
[66090]=28888,--Quel'dorei Steed
[66091]=28889,--Sunreaver Hawkstrider
[66846]=29754,--Ochre Skeletal Warhorse
[66906]=28919,--Argent Charger
[67466]=28918,--Argent Warhorse
[68057]=29284,--Swift Alliance Steed
[68187]=29937,--Crusader's White Warhorse
[68188]=29938,--Crusader's Black Warhorse
[51412]=25335,--Big Battle Bear
[42777]=21974,--Swift Spectral Tiger
[65917]=29344,--Magic Rooster
[66847]=29755,--Striped Dawnsaber
[42776]=21973,--Spectral Tiger
--3.2.2
[69395]=30346,--Onyxian Drake
[68056]=29283,--Swift Horde Wolf
[68769]=30141,--Little Ivory Raptor Whistle
[68768]=30518,--Little White Stallion Bridle
--3.3
[72286]=31007,--Invincible
--3.3.2
[72808]=31156,--Bloodbathed Frostbrood Vanquisher
[71342]=30989,--Big Love Rocket
--3.3.3
[67336]=29794,--Relentless Gladiator's Frost Wyrm
[72807]=31154,--Icebound Frostbrood Vanquisher
[75596]=28063,--Frosty Flying Carpet
[75597]=28063,--Frosty Flying Carpet(Recipe)
[74856]=31803,--Blazing Hippogryph
[75973]=31992,--X-53 Touring Rocket
[73313]=25279,--Crimson Deathcharger
[75614]=31958,--Celestial Steed
--3.3.5
[74918]=31721,--Wooly White Rhino
--4.0.1
[93326]=35750,--Sandstone Drake
[93328]=35750,--Sandstone Drake(Recipe)
[88746]=35751,--Vitreous Stone Drake
[88331]=35551,--Volcanic Stone Drake
[88335]=35757,--Drake of the East Wind
[88741]=35754,--Drake of the West Wind
[88742]=35553,--Drake of the North Wind
[88744]=35755,--Drake of the South Wind
[88718]=35740,--Phosphorescent Stone Drake
[71810]=31047,--Wrathful Gladiator's Frost Wyrm
[88990]=37145,--Dark Phoenix
[92231]=37160,--Spectral Steed
[92232]=37159,--Spectral Wolf
[88741]=35754,--Drake of the West Wind
[88748]=35136,--Brown Riding Camel
[88749]=35134,--Tan Riding Camel
[88750]=35135,--Grey Riding Camel
[92155]=15672,--Ultramarine Qiraji Battle Tank
--4.0.3
[98718]=34955,--Subdued Seahorse
[75207]=34956,--Abyssal Seahorse
[93623]=37231,--Mottled Drake
[84751]=34410,--Fossilized Raptor
[87091]=35250,--Goblin Turbo-Trike
[90621]=36213,--Golden King
[93644]=37138,--Kor'kron Annihilator
[87090]=35249,--Goblin Trike
--4.1
[98204]=38261,--Amani Battle Bear
[97359]=38018,--Flameward Hippogryph
[97493]=38031,--Pureblood Fire Hawk
[96503]=37800,--Amani Dragonhawk
[96491]=14341,--Armored Razzashi Raptor
[96499]=37799,--Swift Zulian Panther
[97581]=38048,--Savage Raptor
[98727]=38260,--Winged Guardian
--4.2
[97560]=38046,--Corrupted Fire Hawk
[101282]=38756,--Vicious Gladiator's Twilight Drake
[100332]=38668,--Vicious War Steed
[100333]=38607,--Vicious War Wolf
[101542]=38783,--Flametalon of Alysrazor
--4.3
[107842]=39561,--Blazing Drake
[107845]=39563,--Life-Binder's Handmaiden
[110039]=39229,--Experiment 12-B
[107844]=39562,--Twilight Harbinger
[101821]=38755,--Ruthless Gladiator's Twilight Drake
[74856]=31803,--Blazing Hippogryph
[107516]=39546,--Spectral Gryphon
[107517]=39547,--Spectral Wind Rider
[103196]=39095,--Swift Mountain Horse
[101573]=17011,--Swift Shorestrider
[102346]=1281,--Swift Forest Strider
[102349]=16992,--Swift Springstrider
[102350]=1961,--Swift Lovebird
[102488]=37204,--White Riding Camel
[103081]=39060,--Darkmoon Dancing Bear
[107203]=39530,--Tyrael's Charger
[110051]=40029,--Heart of the Aspects
[103195]=39096,--Mountain Horse
[102514]=38972,--Corrupted Hippogryph
--4.3.2
[113120]=40568,--Feldrake
--5.0.1
[121837]=42502,--Jade Panther
[121844]=42502,--Jade Panther(Recipe)
[113199]=40590,--Jade Cloud Serpent
[120043]=42185,--Jeweled Onyx Panther
[120045]=42185,--Jeweled Onyx Panther(Recipe)
[122708]=42703,--Grand Expedition Yak
[123993]=41991,--Golden Cloud Serpent
[123992]=41989,--Azure Cloud Serpent
[127154]=41990,--Onyx Cloud Serpent
[127156]=41592,--Crimson Cloud Serpent
[127158]=43689,--Heavenly Onyx Cloud Serpent
[127161]=43692,--Heavenly Crimson Cloud Serpent
[127164]=43693,--Heavenly Golden Cloud Serpent
[127170]=46087,--Astral Cloud Serpent
[127174]=43704,--Azure Riding Crane
[127176]=43705,--Golden Riding Crane
[127177]=43706,--Regal Riding Crane
[127216]=43711,--Grey Riding Yak
[127220]=43712,--Blonde Riding Yak
[129552]=44633,--Crimson Pandaren Phoenix
[129918]=43686,--Thundering August Cloud Serpent
[129932]=44759,--Green Shado-Pan Riding Tiger
[129935]=44757,--Red Shado-Pan Riding Tiger
[129934]=43900,--Blue Shado-Pan Riding Tiger
[130086]=44807,--Brown Riding Goat
[130137]=44837,--White Riding Goat
[130138]=44836,--Black Riding Goat
[130965]=45264,--Son of Galleon
[121838]=42499,--Ruby Panther
[121841]=42499,--Ruby Panther(Recipe)
[118089]=41711,--Azure Water Strider
[121839]=42501,--Sunstone Panther
[121843]=42501,--Sunstone Panther(Recipe)
[121836]=42500,--Sapphire Panther
[121842]=42500,--Sapphire Panther(Recipe)
[118737]=41903,--Pandaren Kite
[124408]=43562,--Thundering Jade Cloud Serpent
[130985]=45271,--Pandaren Kite
[123886]=43090,--Amber Scorpion
[121820]=42498,--Obsidian Nightwing
[126507]=43637,--Depleted-Kyparium Rocket
[127138]=43637,--Depleted-Kyparium Rocket(Recipe)
[126508]=43638,--Geosynchronous World Spinner
[127139]=43638,--Geosynchronous World Spinner(Recipe)
[130092]=44808,--Red Flying Cloud
[120822]=42352,--Great Red Dragon Turtle
[127293]=43722,--Great Green Dragon Turtle
[127295]=43723,--Great Black Dragon Turtle
[127302]=43724,--Great Blue Dragon Turtle
[127308]=43725,--Great Brown Dragon Turtle
[127310]=43726,--Great Purple Dragon Turtle
[124659]=43254,--Imperial Quilen
[120395]=42250,--Green Dragon Turtle
[127286]=43717,--Black Dragon Turtle
[127287]=43718,--Blue Dragon Turtle
[127288]=43719,--Brown Dragon Turtle
[127289]=43720,--Purple Dragon Turtle
[127290]=43721,--Red Dragon Turtle
[130678]=44635,--Oddly-Shaped Horn
[130730]=45163,--Bag of Kafa Beans
[130895]=45242,--Tuft of Yak Fur
[127165]=43695,--Heavenly Jade Cloud Serpent
[127169]=43697,--Heavenly Azure Cloud Serpent
--5.0.4
[132036]=45797,--Thundering Ruby Cloud Serpent
[132118]=45520,--Emerald Pandaren Phoenix
[132119]=45522,--Violet Pandaren Phoenix
[132117]=45521,--Ashen Pandaren Phoenix
[120822]=42352,--Great Red Dragon Turtle
[127295]=43723,--Great Black Dragon Turtle
[127293]=43722,--Great Green Dragon Turtle
[127302]=43724,--Great Blue Dragon Turtle
[127308]=43725,--Great Brown Dragon Turtle
[127310]=43726,--Great Purple Dragon Turtle
[120395]=42250,--Green Dragon Turtle
[127288]=43719,--Brown Dragon Turtle
[127289]=43720,--Purple Dragon Turtle
[127290]=43721,--Red Dragon Turtle
[127286]=43717,--Black Dragon Turtle
[127287]=43718,--Blue Dragon Turtle
--5.0.5
[124550]=38757,--Cataclysmic Gladiator's Twilight Drake
--5.1
[135416]=46929,--Grand Armored Gryphon
[135418]=46930,--Grand Armored Wyvern
[136163]=47166,--Grand Gryphon
[136164]=47165,--Grand Wyvern
[133023]=42147,--Jade Pandaren Kite
[134573]=46729,--Swift Windsteed
--5.2
[136471]=47238,--Spawn of Horridon
[139442]=47981,--Thundering Cobalt Cloud Serpent
[139448]=47983,--Clutch of Ji-Kun
[140249]=48100,--Golden Primal Direhorn
[140250]=48101,--Crimson Primal Direhorn
[139407]=47976,--Malevolent Gladiator's Cloud Serpent
[134359]=46686,--Sky Golem
[95416]=46686,--Sky Golem(Recipe)
[136400]=47256,--Armored Skyscreamer
[136505]=48014,--Ghastly Charger
[138423]=47716,--Cobalt Primordial Direhorn
[138425]=47715,--Slate Primordial Direhorn
[138424]=47718,--Amber Primordial Direhorn
[138426]=47717,--Jade Primordial Direhorn
[138640]=47825,--Bone-White Primal Raptor
[138641]=47826,--Red Primal Raptor
[138642]=47828,--Black Primal Raptor
[138643]=47827,--Green Primal Raptor
[139595]=48020,--Armored Bloodwing
--5.3
[142641]=48858,--Brawler's Burly Mushan Beast
[142266]=48815,--Armored Red Dragonhawk
[142478]=48816,--Armored Blue Dragonhawk
[142878]=48714,--Enchanted Fey Dragon
[142073]=48931,--Hearthsteed
--5.4
[148620]=51359,--Prideful Gladiator's Cloud Serpent
[148428]=51484,--Ashhide Mushan Beast
[148396]=51481,--Kor'kron War Wolf
[148417]=51485,--Kor'kron Juggernaut
[148476]=51488,--Thundering Onyx Cloud Serpent
[148618]=51361,--Tyrannical Gladiator's Cloud Serpent
[148619]=51360,--Grievous Gladiator's Cloud Serpent
[148392]=51479,--Spawn of Galakras
[146615]=51037,--Vicious Warsaber
[146622]=51048,--Vicious Skeletal Warhorse
[30174]=17158,--Riding Turtle
[147595]=51323,--Stormcrow
[145133]=49295,--Shimmering Moonstone
[148626]=51484,--Ash-Covered Horn
[148773]=51591,--Golden Glider
--5.4.1
[149801]=51993,--Emerald Hippogryph
--5.4.2
[153489]=53038,--Iron Skyreaver
--5.4.7
[155741]=53774,--Armored Dread Raven
--5.4.8
[163024]=55896,--Warforged Nightmare
[163025]=55907,--Grinning Reaver
--6.0.1
[171844]=59762,--Dustmane Direwolf,171844,28896,59762
[171291]=59762,--Dustmane Direwolf(Recipe)
[171436]=59159,--Gorestrider Gronnling
[171842]=59759,--Swift Frostwolf
--[174004]=,--Spirit of Shinri
[169952]=28060,--Creeping Carpet
[168850]=28060,--Creeping Carpet(Recipe)
[175700]=25836,--Emerald Drake
[170347]=58772,--Core Hound
[171847]=61363,--Cindermane Charger
[176762]=61152,--Iron Star Roller
[176759]=60345,--Goren "Log" Roller
--6.0.2
[171828]=59751,--Solar Spirehawk
[171848]=60577,--Challenger's War Yeti
[171621]=59837,--Ironhoof Destroyer
[171622]=59339,--Mottled Meadowstomper
[171636]=59736,--Great Greytusk
[171824]=59744,--Sapphire Riverbeast
[171830]=59364,--Swift Breezestrider
[171834]=60574,--Vicious War Ram
[171835]=60575,--Vicious War Raptor
[171845]=60208,--Warlord's Deathwheel
[171846]=60207,--Champion's Treadblade
[171849]=60578,--Sunhide Gronnling
[171851]=54114,--Garn Nighthowl
[171616]=59321,--Witherhide Cliffstomper
[171617]=59320,--Trained Icehoof
--[171618]=2410,--Ancient Leatherhide
[171619]=59324,--Tundra Icehoof
[171623]=59340,--Trained Meadowstomper
[171624]=59341,--Shadowhide Pearltusk
[171625]=59342,--Dusty Rockhide
[171626]=59343,--Armored Irontusk
[171627]=59349,--Blacksteel Battleboar
[171620]=59323,--Bloodhoof Bull
[171629]=59347,--Armored Frostboar
[171630]=59346,--Armored Razorback
[171632]=59344,--Frostplains Battleboar
[171633]=59739,--Wild Goretusk
[171634]=59738,--Domesticated Razorback
[171635]=59737,--Giant Coldsnout
[171637]=59735,--Trained Rocktusk
[171638]=59743,--Trained Riverwallow
[171825]=59745,--Mosshide Riverwallow
[171826]=59746,--Mudback Riverbeast
[171829]=59363,--Shadowmane Charger
[171831]=59365,--Trained Silverpelt
[171832]=59366,--Breezestrider Stallion
[171833]=59367,--Pale Thorngrazer
[171836]=59756,--Garn Steelmaw
[171837]=59752,--Warsong Direfang
[171838]=59753,--Armored Frostwolf
[171839]=59754,--Ironside Warwolf
[171841]=59757,--Trained Snarler
[171843]=59760,--Smoky Direwolf
[171628]=59348,--Rocktusk Battleboar
--6.1
[179245]=61804,--Chauffeured Chopper (Alliance)
[179244]=61803,--Chauffeured Chopper (Horde)
[179478]=38785,--Voidtalon of the Dark Star
[180545]=62148,--Mystic Runesaber
--6.2
[182912]=62893,--Felsteel Annihilator
[186828]=63956,--Primal Gladiator's Felblood Gronnling
[189043]=64378,--Wild Gladiator's Felblood Gronnling
[189044]=64377,--Warmongering Gladiator's Felblood Gronnling
[183117]=63032,--Corrupted Dreadwing
[183889]=63249,--Vicious War Mechanostrider
[185052]=63580,--Vicious War Kodo
[186305]=63873,--Infernal Direwolf
[189364]=64426,--Coalfist Gronnling
[190690]=64726,--Bristling Hellboar
[190977]=64849,--Deathtusk Felboar
[191633]=65040,--Soaring Skyterror
--6.2.2
[142910]=48946,--Ironbound Wraithcharger
[194464]=65994,--Eclipse Dragonhawk
[191314]=64960,--Minion of Grumpus
[189999]=64583,--Grove Warden
[189998]=64582,--Illidari Felstalker
--6.2.3
[201098]=67594,--Infinite Timereaver
--7.0.3
[222202]=71001,--Prestigious Bronze Courser
[222237]=70999,--Prestigious Forest Courser
[222238]=70998,--Prestigious Ivory Courser
[222241]=71000,--Prestigious Midnight Courser
[222240]=70996,--Prestigious Azure Courser
[222236]=70997,--Prestigious Royal Courser
[196681]=70874,--Spirit of Eche'ro
[213115]=69276,--Bloodfang Widow
[213134]=70040,--Felblaze Infernal
[171827]=70051,--Hellfire Infernal
--[171840]=,--Coldflame Infernal
[213158]=70060,--Predatory Bloodgazer
[213163]=70063,--Snowfeather Hunter
[213164]=70062,--Brilliant Direbeak
[213165]=70061,--Viridian Sharptalon
--[213350]=,--Frostshard Infernal
--[213349]=,--Flarecore Infernal
[213209]=70099,--Steelbound Devourer
[213916]=70099,--Steelbound Devourer(Recipe)
[223018]=71939,--Fathom Dweller
[215159]=29361,--Long-Forgotten Hippogryph
[215558]=70619,--Ratstallion
[193007]=72700,--Grove Defiler
[225765]=63625,--Leyfeather Hippogryph
[227986]=73315,--Vindictive Gladiator's Storm Dragon
[227988]=73316,--Fearless Gladiator's Storm Dragon
[227989]=73317,--Cruel Gladiator's Storm Dragon
[227991]=73319,--Ferocious Gladiator's Storm Dragon
[227994]=73320,--Fierce Gladiator's Storm Dragon
[227995]=73321,--Demonic Gladiator's Storm Dragon
[213339]=67042,--Great Northern Elderhorn
[194780]=67042,--Great Northern Elderhorn(Recipe)
[171850]=68851,--Llothien Prowler
[214791]=68849,--Brinedeep Bottom-Feeder
[193695]=38668,--Prestigious War Steed
[223363]=71975,--Vicious Warstrider
[223578]=72020,--Vicious War Elekk
[223341]=71973,--Vicious Gilnean Warhorse
[223354]=71816,--Vicious War Trike
[227956]=68848,--Arcadian War Turtle
[142910]=48946,--Ironbound Wraithcharger
[223814]=72071,--Mechanized Lumber Extractor
--7.1.0
[230987]=74032,--Arcanist's Manasaber
[228919]=73254,--Darkwater Skate
[230401]=73991,--White Hawkstrider
[229499]=73808,--Midnight
[204166]=68069,--Prestigious War Wolf
[230844]=19480,--Rockspine Basilisk
[231428]=74104,--Smoldering Ember Wyrm
--7.2
[232519]=74315,--Abyss Worm
[229385]=73784,--Ban-Lu, Grandmaster's Companion
[231525]=74136,--Shadowblade's Crimson Omen
[242881]=63628,--Cloudwing Hippogryph
[229387]=73785,--Deathlord's Vilebrood Vanquisher
[231435]=74148,--Highlord's Golden Charger
[231587]=74149,--Highlord's Vengeful Charger
[238452]=75532,--Netherlord's Brimstone Wrathsteed
[231589]=74151,--Highlord's Valorous Charger
[242874]=67039,--Highmountain Elderhorn
[229388]=73778,--Battlelord's Bloodthirsty War Wyrm
[233364]=74480,--Leywoven Flying Carpet
[231524]=74134,--Shadowblade's Baneful Omen
[231523]=74135,--Shadowblade's Lethal Omen
--[231437]=,--Archdruid's Lunarwing Form
[232405]=74298,--Primal Flamesaber
[231442]=76024,--Farseer's Raging Tempest
[231434]=74133,--Shadowblade's Murderous Omen
[243025]=74314,--Riddler's Mind-Worm
[238454]=75533,--Netherlord's Accursed Wrathsteed
[230844]=73248,--Brawler's Burly Basilisk
[231588]=74150,--Highlord's Vigilant Charger
[229439]=73781,--Huntmaster's Dire Wolfhawk
[229438]=73782,--Huntmaster's Fierce Wolfhawk
[229386]=73780,--Huntmaster's Loyal Wolfhawk
[242882]=68053,--Valarjar Stormwing
[229487]=73805,--Vicious War Bear
[229486]=73806,--Vicious War Bear
[229512]=73817,--Vicious War Lion
[230988]=74034,--Vicious War Scorpion
[232523]=74320,--Vicious War Turtle
[232525]=74321,--Vicious War Turtle
[242875]=76424,--Wild Dreamrunner
--7.3
[253662]=79593,--Acid Belcher
[253088]=79479,--Antoran Charhound
[253087]=79480,--Antoran Gloomhound
[254259]=79790,--Avenging Felcrusher
[253660]=79592,--Biletooth Gnasher
[254260]=79440,--Bleakhoof Ruinstrider
[254258]=79789,--Blessed Felcrusher
[253661]=79595,--Crimson Slavermaw
[247448]=78105,--Darkmoon Dirigible
[235764]=74900,--Darkspore Mana Ray
[253108]=79487,--Felglow Mana Ray
[254069]=79732,--Glorious Felcrusher
[253639]=79583,--Violet Spellwing
[253107]=79484,--Lambent Mana Ray
[239013]=75585,--Lightforged Warframe
[247402]=78092,--Lucid Nightmare
[243512]=76586,--Luminous Starseeker
[253058]=76311,--Maddened Chaosrunner
[253711]=79613,--Pond Nettle
[253004]=79443,--Amethyst Ruinstrider
[253005]=79441,--Beryl Ruinstrider
[253007]=79437,--Cerulean Ruinstrider
[253006]=79444,--Russet Ruinstrider
[242305]=76318,--Sable Ruinstrider
[253008]=79438,--Umber Ruinstrider
[253109]=79486,--Scintillating Mana Ray
[243651]=79436,--Shackled Ur'zul
[253106]=79485,--Vibrant Mana Ray
[242897]=76426,--Vicious War Fox
[242896]=76427,--Vicious War Fox
[243652]=76646,--Vile Fiend
--7.3.5
[239770]=75707,--Black Qiraji War Tank
[243201]=76533,--Demonic Gladiator's Storm Dragon
[258022]=81114,--Lightforged Felcrusher
[258060]=81113,--Highmountain Thunderhoof
[259202]=81648,--Starcursed Voidstrider
[258845]=74032,--Nightborne Manasaber
[239769]=15672,--Purple Qiraji War Tank
[239767]=75705,--Ruby Qiraji Resonating Crystal
[239766]=75706,--Sapphire Qiraji Resonating Crystal
--8.0.1
[262027]=82782,--Black Gladiator's Proto-Drake
[250735]=78858,--Bloodgorged Crawg
[262023]=82804,--Blue Gladiator's Proto-Drake
[279457]=87773,--Broken Highland Mustang
[237286]=75324,--Dune Scavenger
[260174]=81694,--Terrified Pack Mule
[279454]=87772,--Conquerer's Scythemaw
[279467]=87776,--Craghorn Chasm-Leaper
[271646]=85691,--Dark Iron Core Hound
[262022]=82809,--Dread Gladiator's Proto-Drake
[280729]=38784,--Frenzied Feltalon
[262028]=82805,--Gold Gladiator's Proto-Drake
[260175]=81690,--Goldenmane
[278803]=73253,--Great Sea Ray
[262026]=82806,--Green Gladiator's Proto-Drake
[279456]=87774,--Highland Mustang
[267270]=77023,--Kua'fon
[279608]=85581,--Lil' Donkey
[267274]=84468,--Mag'har Direwolf
[261437]=80864,--Mecha-Mogul Mk2
[274621]=80864,--Mecha-Mogul Mk2(Recipe)
[266058]=84274,--Tomb Stalker
[275623]=74316,--Nazjatar Blood Serpent
[262025]=82807,--Pale Gladiator's Proto-Drake
[281044]=88359,--Prestigious Bloodforged Courser
[280730]=88116,--Pureheart Courser
[262024]=82810,--Purple Gladiator's Proto-Drake
[279469]=45836,--Qinsho's Eternal Hound
[243795]=76706,--Leaping Veinseeker
[259213]=82148,--Admiralty Stallion
[237287]=75323,--Alabaster Hyena
[275840]=87041,--Armored Albino Pterrordax
[244712]=77070,--Armored Ebony Pterrordax
[275838]=87044,--Armored Orange Pterrordax
[275837]=87045,--Cobalt Pterrordax
[260172]=81693,--Dapple Gray
[275859]=83666,--Dusky Waycrest Gryphon
[275841]=76708,--Expedition Bloodswarmer
[264058]=83632,--Mighty Caravan Brutosaur
[239049]=75600,--Obsidian Krolusk
[279474]=87779,--Palehide Direhorn
[275868]=83664,--Proudmoore Sea Scout
[260173]=82161,--Smoky Charger
[278656]=87701,--Spectral Phoenix
[275866]=83665,--Stormsong Coastwatcher
[254813]=80449,--Summon Sharkbait
[259395]=81772,--Shu-Zen, the Divine Sentinel
[279611]=87848,--Skullripper
[274610]=86527,--Teldrassil Hippogryph
[259740]=81952,--Spawn of Krag'wa
[254811]=79916,--Squawks
[278979]=87747,--Surf Jelly
[279569]=14345,--Swift Albino Raptor
[278966]=87741,--Tempestuous Skystallion
[261395]=88835,--The Hivemind
[279466]=87775,--Twilight Avenger
[273541]=78860,--Underrot Crawg
[261434]=82528,--Vicious War Basilisk
[261433]=82527,--Vicious War Basilisk
[270560]=85393,--Vicious War Clefthoof
[272481]=85888,--Vicious War Riverbeast
[272472]=85886,--Undercity Plaguebat
[279868]=86091,--Witherbark Direwing
[256123]=80513,--Xiwyllag ATV
[265935]=80513,--Xiwyllag ATV(Recipe)
[263707]=83525,--Zandalari Direhorn
--[266229]=,--Zany Zombified Raptor
[272770]=85970,--The Dreadwake
--8.1
[288495]=89750,--Ashenvale Chimaera
[288736]=90393,--Azureshell Krolusk
[288438]=706,--Blackpaw
[288720]=55151,--Bloodgorged Hunter
[288714]=60307,--Bloodthirsty Dreadwing
[288587]=81959,--Blue Marsh Hopper
[288438]=706,--Blackpaw
[290134]=90398,--Hogrus, Swine of Good Fortune
[288505]=89247,--Kaldorei Nightsaber
[288503]=89246,--Umber Nightsaber
[289101]=90194,--Dazar'alor Windreaver
[288499]=12247,--Frightened Kodo
[289083]=90189,--G.M.O.D.
[289555]=90414,--Glacial Tidestorm
[288721]=90158,--Island Thunderscale
[288505]=89247,--Kaldorei Nightsaber
[281554]=88646,--Meat Wagon
[288740]=90159,--Priestess' Moonsaber
[237288]=75322,--Reins of the Onyx War Hyena
[288722]=5050,--Risen Mare
[288735]=90394,--Rubyshell Krolusk
[288711]=34958,--Saltwater Seahorse
[288506]=6448,--Sandy Nightsaber
[266925]=84359,--Siltwing Albatross
[288712]=67041,--Stonehide Elderhorn
[288503]=89246,--Umber Nightsaber
[281890]=88760,--Vicious Black Bonesteed
[281887]=88755,--Vicious Black Warsaber
[290133]=90397,--Vulpine Familiar
[288589]=81958,--Yellow Marsh Hopper
--8.1.5
[294568]=90215,--Beastlord's Irontusk
[294569]=57466,--Beastlord's Warwolf
[295387]=91388,--Bloodflank Charger
[289639]=90419,--Bruce
[295386]=91389,--Ironclad Frostclaw
[282682]=88974,--Kul Tiran Charger
--8.2
[290718]=92730,--Aerial Unit R-21\/X
--[304696]=,--Alpha Fin
[292407]=90725,--Ankoan Waveray
[292419]=90729,--Azshari Bloatray
[297560]=91787,--Child of Torcali
[300153]=92254,--Crimson Tidestallion
[300147]=91236,--Deepcoral Snapdragon
[300150]=88768,--Fabious
[300151]=92251,--Inkscale Deepseeker
[296788]=91633,--Mechacycle Model W
[299158]=90710,--Mechagon Peacekeeper
[294143]=92666,--X-995 Mechanocat
[294193]=92666,--X-995 Mechanocat(Recipe)
[294038]=91104,--Royal Snapdragon
[299170]=92731,--Rustbolt Resistor
[297157]=91634,--Junkheap Drifter
[291492]=90711,--Rusty Mechanocrawler
[299159]=90712,--Scrapforged Mechaspider
[300149]=90728,--Silent Glider
[294039]=91238,--Snapback Scuttler
[300146]=91237,--Snapdragon Kelpstalker
[290132]=90396,--Sylverian Dreamer
[291538]=90727,--Unshackled Waveray
[290328]=90421,--Wonderwing 2.0

------------------------------------------
--**************************************--
--************* COMPANIONS *************--
--**************************************--
------------------------------------------
--spells only
[66520]=29605,--Jade Tiger
[40319]=21304,--Lucky
[93815]=38311,--Bubbles
[93461]=32031,--Landro's Lil' XT
[93818]=36583,--Lizzy
[75936]=28734,--Murkimus the Gladiator
[89929]=36129,--Rumbling Rockling
[89930]=36130,--Swirling Stormling
[89931]=36131,--Whirling Waveling
[148068]=51742,--Ashwing Moth
[143732]=49086,--Crafty
[148069]=51301,--Flamering Moth
[123214]=42872,--Gilnean Raven
[123212]=32790,--Shore Crawler
[148065]=51740,--Skywisp Moth
[181086]=62354,--Graves
[227052]=73351,--Knight-Captain Murky --! not murky
[227051]=73352,--Legionnaire Murky --!
[225761]=73353,--Mischief --!
[210692]=66211,--Purple Broodling
[210693]=66213,--Yellow Broodling
[230076]=70068,--Bloodgazer Hatchling
[230074]=70070,--Direbeak Hatchling
[230075]=70069,--Sharptalon Hatchling
[230073]=70071,--Snowfeather Hatchling
--1.11.1 and earlier
[15999]=9563,--Worg Pup
[26010]=10269,--Tranquil Mechanical Yeti
[26011]=10269,--Tranquil Mechanical Yeti(Recipe)
[12529]=27718,--Smolderweb Hatchling
[25162]=15436,--Disgusting Oozeling
[19772]=901,--Lifelike Toad
[19793]=901,--Lifelike Toad(Recipe)
[15067]=6294,--Sprite Darter Hatchling
[15048]=8909,--Pet Bombling
[15628]=8909,--Pet Bombling(Recipe)
[15049]=8910,--Lil' Smoky
[15633]=8910,--Lil' Smoky(Recipe)
[12243]=7920,--Mechanical Chicken
[10704]=6295,--Tree Frog
[10703]=901,--Wood Frog
[23811]=14938,--Jubling
[23851]=14938,--Jubling(Recipe)
--[23851]=,--Unhatched Jubling Egg
[10685]=5369,--Ancona Chicken
[10697]=6290,--Crimson Whelpling
[10707]=4615,--Great Horned Owl
[10706]=6299,--Hawk Owl
[10714]=1206,--Black Kingsnake
[10716]=2957,--Brown Snake
[10717]=6303,--Crimson Snake
[10688]=2177,--Undercity Cockroach
[10709]=1072,--Brown Prairie Dog
[10695]=6288,--Dark Whelpling
[10698]=6291,--Emerald Whelpling
[10682]=6192,--Hyacinth Macaw
[17709]=10993,--Zergling
[17707]=10990,--Panda Cub
[17708]=10992,--Mini Diablo
[24696]=15369,--Murky
[10673]=5556,--Bombay Cat
[10674]=5586,--Cornish Rex Cat
[10676]=5554,--Orange Tabby Cat
[10678]=5555,--Silver Tabby Cat
[10679]=9990,--White Kitten
[10677]=5585,--Siamese Cat
[10675]=5448,--Black Tabby Cat
[10683]=5207,--Green Wing Macaw
[10684]=6190,--Senegal
[10680]=6191,--Cockatiel
[10711]=328,--Snowshoe Rabbit
[4055]=7937,--Mechanical Squirrel
[3928]=7937,--Mechanical Squirrel(Recipe)
[28740]=2176,--Whiskers the Rat
[13548]=304,--Westfall Chicken
[26533]=15660,--Father Winter's Helper
[26541]=15663,--Winter's Little Helper
[26529]=15904,--Winter Reindeer
[28871]=16587,--Spirit of Summer
--[27662]=,--Silver Shafted Arrow
[27570]=15992,--Peddlefeet
[28738]=16259,--Speedy
[28739]=16257,--Mr. Wiggles
[26045]=13610,--Tiny Snowman
--1.12.1
[23429]=14657,--Loggerhead Snapjaw
[23530]=14779,--Tiny Red Dragon
[23531]=14778,--Tiny Green Dragon
--2.0
[30156]=16943,--Hippogryph Hatchling
--2.0.1
[39181]=20996,--Miniwing
[35156]=19600,--Mana Wyrmling
[35239]=4626,--Brown Rabbit
[35909]=19986,--Red Moth
[36031]=20029,--Blue Dragonhawk Hatchling
[33050]=18269,--Magical Crawdad
[33062]=18269,--Magical Crawdad(Recipe)
[35907]=19987,--Blue Moth
[35910]=19985,--Yellow Moth
[35911]=19999,--White Moth
[36027]=20026,--Golden Dragonhawk Hatchling
[36028]=20027,--Red Dragonhawk Hatchling
[36029]=20037,--Silver Dragonhawk Hatchling
[40549]=21362,--Bananas
--2.0.3
[30152]=37949,--White Tiger Cub
--2.1
[27241]=15984,--Gurky
[32298]=17723,--Netherwhelp
--[42426]=17723,--Netherwhelp(Recipe)
[40614]=21382,--Egbert
[40613]=21381,--Willy
[40634]=21393,--Peanut
[36034]=20042,--Firefly
[24988]=15398,--Lurky
--2.2.2
[39709]=22349,--Wolpertinger
[42609]=21900,--Sinister Squashling
--2.3
[45082]=22855,--Tiny Sporebat
[10696]=6293,--Azure Whelpling
[43918]=22459,--Mojo
--[43923]=22459,--Mojo(Recipe)
[45127]=22966,--Dragon Kite
[54187]=22776,--Clockwork Rocket Bot
[45125]=22903,--Rocket Chicken
--2.4
[46599]=23574,--Phoenix Hatchling
[43697]=22388,--Toothy
[43698]=22389,--Muckbreath
[46425]=23507,--Snarly
[46426]=23506,--Chuck
--2.4.2
[51716]=25457,--Nether Ray Fry
[45890]=8409,--Searing Scorchling
[49964]=25002,--Ethereal Soul-Trader
[53082]=25900,--Mini Tyrael
[53085]=25900,--Mini Tyrael(Recipe)
[40405]=21328,--Lucky
--[40406]=21328,--Lucky(Recipe)
--2.4.3
[48406]=24393,--Spirit of Competition
--[49352]=25332,--Crashin' Thrashin' Racer
--3.0.1
[25849]=15595,--Baby Shark
[40990]=16633,--Stinker
--3.0.2
[51851]=4185,--Vampiric Batling
[53316]=28089,--Ghostly Skull
[59250]=27627,--Giant Sewer Rat
[61357]=28216,--Pengu
[61348]=45919,--Tickbird Hatchling
[61349]=28215,--White Tickbird Hatchling
[61350]=28217,--Proto-Drake Whelp
[60832]=26524,--Grindgear Toy Gorilla
[60838]=27829,--Trusty Copper Racer
--3.0.3
[52615]=28456,--Frosty
[62456]=28456,--Frosty(Recipe)
[61472]=45937,--Kirin Tor Familiar
[61457]=45937,--Kirin Tor Familiar(Recipe)
[61351]=28084,--Cobra Hatchling
[61855]=16189,--Baby Blizzard Bear
--3.0.8
[61991]=28397,--Little Fawn
--3.1
[10713]=2955,--Albino Snake
[64351]=29060,--XS-001 Constructor Bot
[64347]=29060,--XS-001 Constructor Bot(Recipe)
[61725]=6302,--Spring Rabbit
[62491]=28482,--Teldrassil Sproutling
[62508]=28489,--Dun Morogh Cub
[62510]=4732,--Tirisfal Batling
[62513]=15470,--Durotar Scorpion
[62516]=16205,--Elwynn Lamb
[62542]=28502,--Mulgore Hatchling
[62561]=45880,--Strand Crawler
[62562]=28493,--Ammen Vale Lashling
[62609]=28946,--Argent Squire
[62674]=28539,--Mechanopeep
[62746]=28948,--Argent Gruntling
[62949]=28599,--Wind-Up Train Wrecker
[63712]=46939,--Sen'jin Fetish
[62564]=45960,--Enchanted Broom
[61022]=27829,--Heavy Copper Racer
[61021]=27829,--Zippy Copper Racer
[62857]=28811,--Sandbox Tiger
--3.1.2
[63318]=28734,--Murkimus the Gladiator
--3.1.3
[65682]=29279,--Warbot
--3.2
[67413]=29805,--Darting Hatchling
[67415]=29803,--Gundrak Hatchling
[67416]=29802,--Leaping Hatchling
[67417]=29809,--Obsidian Hatchling
[67418]=29810,--Ravasaur Hatchling
[67419]=29808,--Razormaw Hatchling
[67420]=29806,--Razzashi Hatchling
[67414]=29807,--Deviate Hatchling
[44369]=22629,--Pint-Sized Pink Pachyderm
[66030]=29348,--Grunty
[65382]=25384,--Curious Wolvar Pup
[65381]=25173,--Curious Oracle Hatchling
[66096]=29372,--Shimmering Wyrmling
[66096]=29372,--Shimmering Wyrmling
[65353]=25384,--Wolvar Orphan Whistle
[65360]=25384,--Wolvar Orphan Whistle(Recipe)
[65352]=25173,--Oracle Orphan Whistle
[65359]=25173,--Oracle Orphan Whistle(Recipe)
--3.2.2
[69002]=30356,--Onyxian Whelpling
[55068]=26452,--Mr. Chilly
[61773]=45968,--Plump Turkey
[69541]=30414,--Pandaren Monk
[69677]=30507,--Lil' K.T.
[66175]=29404,--Macabre Marionette
[68767]=30157,--Tuskarr Kite
[68810]=30409,--Spectral Tiger Cub
--3.3
[65358]=11709,--Calico Cat
[69452]=30462,--Core Hound Pup
[70613]=31174,--Perky Pug
[45174]=21304,--Golden Pig
[45175]=22938,--Silver Pig
[48408]=24620,--Essence of Competition
[28505]=16189,--Poley
[62857]=28811,--Sandbox Tiger
--3.3.2
[69535]=30412,--Gryphon Hatchling
[69536]=30413,--Wind Rider Cub
[71840]=31073,--Toxic Wasteling
--3.3.3
[74932]=31722,--Frigid Frostling
[75906]=32031,--Lil' XT
[75134]=22778,--Blue Clockwork Rocket Bot
--[75111]=25332,--Blue Crashin' Thrashin' Racer 
--3.3.5
[78381]=32670,--Mini Thor
--4.0.1
[89039]=37136,--Dark Phoenix Hatchling
[90637]=33217,--Fox Kit
[89670]=36220,--Armadillo Pup
[89472]=36499,--Rustberg Seagull
[89472]=36499,--Rustberg Seagull
[93624]=32031,--Landro's Lil' XT
[94070]=36896,--Deathy
[93739]=9905,--Mr. Grubbs
[92396]=37199,--Guild Page
[92397]=37198,--Guild Herald
[92398]=37196,--Guild Herald
[78683]=32699,--Blue Mini Jouster
[78685]=32707,--Gold Mini Jouster
[92395]=37200,--Guild Page
--4.0.3
[84752]=34413,--Fossilized Hatchling
[63318]=28734,--Murkimus the Gladiator
[69539]=30402,--Zipao Tiger
[87344]=35338,--Lil' Deathwing
[87863]=15393,--Eat the Egg
[67527]=29819,--Onyx Panther
[95787]=37541,--Lil' Ragnaros
[95786]=37526,--Moonkin Hatchling
[95909]=37527,--Moonkin Hatchling
[84263]=34262,--Crawling Claw
[93813]=28435,--Tiny Flamefly
[81937]=33512,--Personal World Destroyer
[84412]=33512,--Personal World Destroyer(Recipe)
[82173]=33559,--De-Weaponized Mechanical Companion
[84413]=33559,--De-Weaponized Mechanical Companion(Recipe)
[90523]=36211,--Clockwork Gnome
[93836]=36902,--Enchanted Lantern
[93841]=36902,--Enchanted Lantern(Recipe)
[93837]=36901,--Magic Lamp
[93843]=36901,--Magic Lamp(Recipe)
[93838]=45878,--Elementium Geode
[65046]=45943,--Withers
[84492]=45940,--Pebble
[91343]=36637,--Tiny Shale Spider
[93823]=37154,--Singing Sunflower
[93817]=38135,--Scooter the Snail
[75613]=31956,--Celestial Dragon
[65451]=17192,--MiniZep Controller
--4.0.6
[16450]=27718,--Smolderweb Hatchling
--4.1
[45082]=22855,--Tiny Sporebat
[98587]=38232,--Voodoo Figurine
[98571]=38229,--Pterrordax Hatchling
[96817]=30507,--Landro's Lichling
[96819]=37846,--Nightsaber Cub
[98079]=38134,--Legs
[98736]=38359,--Guardian Cub
[99578]=16943,--Cenarion Hatchling
[96571]=37814,--Panther Cub
[97638]=37712,--Winterspring Cub
[66096]=29372,--Shimmering Wyrmling
[97779]=38065,--Lashtail Hatchling
--4.2
[100576]=38614,--Lil' Tarecgosa
[98736]=38359,--Guardian Cub
[100330]=38539,--Feline Familiar
[100684]=38638,--Creepy Crate
[101606]=38803,--Murkablo
[99663]=38455,--Hyjal Bear Cub
[101989]=38342,--Horde Balloon
[100959]=38691,--Brewfest Keg Pony
[100970]=38693,--Nuts
[101424]=38776,--Brilliant Kaliri
[101986]=38343,--Alliance Balloon
[99668]=38429,--Crimson Lasher
--4.3
[103588]=39109,--Sea Pony
[101493]=38777,--Purple Puffer
[102353]=39694,--Sand Scarab
[103076]=38344,--Darkmoon Balloon
[101733]=46001,--Darkmoon Monkey
[103074]=38809,--Darkmoon Turtle
[103125]=45939,--Lumpy
[103544]=15381,--Darkmoon Tonk
[103549]=17192,--Darkmoon Zeppelin
[102317]=38919,--Gregarious Grell
[105122]=39137,--Darkmoon Cub
[105633]=39380,--Fetish Shaman
[110029]=40019,--Soul of the Aspects
[140218]=38344,--Flimsy Darkmoon Balloon
[105228]=38340,--Flimsy Green Balloon
[105229]=38341,--Flimsy Yellow Balloon
[104047]=39163,--Lunar Lantern
[104049]=39333,--Festival Lantern
[107926]=39319,--Darkmoon "Tiger"
--4.3.2
[112994]=40538,--Eye of the Legion
--5.0.1
[127813]=43865,--Thundering Serpent Hatchling
[126885]=45386,--Mechanical Pandaren Dragonling
[127135]=45386,--Mechanical Pandaren Dragonling(Recipe)
[114090]=45957,--Darkmoon Rabbit
[123778]=44655,--Terrible Turnip
[123784]=46385,--Red Cricket
[124000]=47955,--Tiny Goldfish
[124152]=45894,--Feral Vermling
[124660]=43255,--Lucky Quilen Cub
[118414]=41833,--Porcupette
[130726]=45987,--Jade Tentacle
[130759]=45195,--Venus
[127006]=44792,--Food
[127008]=44791,--Food
[127816]=43868,--Jade Crane Chick
[120501]=15905,--Jade Owl
[131897]=15905,--Jade Owl(Recipe)
[120507]=42297,--Sapphire Cub
[131898]=42297,--Sapphire Cub(Recipe)
[126247]=43597,--Hopling
[126249]=45854,--Aqua Strider
[126251]=45938,--Grinder
[127815]=43127,--Singing Cricket
[122748]=42721,--Fishy
[127006]=44792,--Yu'lon Kite
[127007]=44792,--Yu'lon Kite(Recipe)
[127008]=44791,--Chi-Ji Kite
[127009]=44791,--Chi-Ji Kite(Recipe)
--5.0.3
[110955]=16587,--Fire Spirit
[130649]=45072,--Life Spirit
[130650]=45073,--Water Spirit
--5.0.4
[90637]=33217,--Fox Kit
[90637]=33217,--Fox Kit
[131590]=45942,--Pandaren Water Spirit
[131650]=45527,--Baneling
[132759]=30409,--Spectral Cub
[132759]=30409,--Spectral Cub
[68810]=30409,--Spectral Tiger Cub
--5.1
[132574]=44551,--Imperial Moth
[132789]=46174,--Darkmoon Eye
[134538]=46720,--Cinder Kitten
[134892]=46809,--Pandaren Fire Spirit
[134894]=46810,--Pandaren Air Spirit
[134895]=46811,--Pandaren Earth Spirit
[135256]=46897,--Mr. Bigglesworth
[132580]=40521,--Imperial Silkworm
[132579]=40521,--Imperial Silkworm(Recipe)
[132785]=46171,--Darkmoon Glowfly
[132762]=46163,--Darkmoon Hatchling
[135257]=46921,--Stitched Pup
[135156]=46882,--Clock'em
[135255]=46896,--Fungal Abomination
[135258]=46900,--Harbinger of Flame
[135259]=46923,--Corefire Imp
[135261]=46902,--Ashstone Core
[135263]=46903,--Untamed Hatchling
[135265]=46905,--Death Talon Whelpguard
[135264]=46925,--Chrominius
[135266]=46924,--Viscidus Globule
[135267]=46922,--Anubisath Idol
[135268]=46909,--Mini Mindslayer
[135254]=46898,--Giant Bone Spider
[135009]=39331,--Darkmoon "Cougar"
[135025]=46695,--Darkmoon "Murloc"
[135026]=46696,--Darkmoon "Rocket"
[135007]=39330,--Darkmoon "Snow Leopard"
[135027]=46697,--Darkmoon "Wyvern"
[135022]=46693,--Darkmoon "Dragon"
[135008]=39332,--Darkmoon "Nightsaber"
[135023]=46694,--Darkmoon "Gryphon"
--5.2
[139932]=48055,--Zandalari Anklerender
[136484]=47348,--Gusting Grimoire
[138082]=47848,--Sunreaver Micro-Sentry
[137977]=47252,--Living Sandling
[138087]=47731,--Zandalari Kneebiter
[138161]=47708,--Son of Animus
[138285]=47732,--Spectral Porcupette
[138380]=47747,--Sunfur Panda
[138381]=47749,--Snowy Panda
[138382]=47748,--Mountain Panda
[138913]=48091,--Spawn of G'nathus
[139148]=48001,--Ji-Kun Hatchling
[137568]=47634,--Red Panda
[139933]=48056,--Zandalari Footslasher
[139934]=48057,--Zandalari Toenibbler
[65682]=29279,--Warbot
[138287]=48211,--Stunted Direhorn
[139153]=48213,--Direhorn Runt
[138825]=48212,--Pygmy Direhorn
[138824]=47711,--Pierre
[139196]=47711,--Pierre(Recipe)
[139361]=47959,--Tiny Red Carp
[139362]=47957,--Tiny Blue Carp
[139363]=47958,--Tiny Green Carp
[139365]=47960,--Tiny White Carp
--5.3
[142880]=48934,--Blossoming Ancient
[143637]=49081,--Murkimus Tyrannicus
[141789]=48651,--Gahz'rooki
[141433]=48878,--Lil' Bad Wolf
[141434]=48857,--Menagerie Custodian
[141435]=48856,--Netherspace Abyssal
[141451]=48662,--Fiendish Imp
[141436]=48855,--Tideskipper
[142030]=48708,--Filthling
[141446]=48661,--Coilfang Stalker
[141447]=48664,--Pocket Reaver
[141448]=48668,--Lesser Voidcaller
[141449]=48663,--Phoenix Hawk Hatchling
[141450]=48667,--Tito
[142028]=48704,--Living Fluid
[142029]=48705,--Viscous Horror
[141437]=48666,--Tainted Waveling
--5.4
[144761]=855,--Moon Moon
[148567]=51505,--Rotten Little Helper
[143703]=49084,--Rascal-Bot
[143714]=49084,--Rascal-Bot(Recipe)
[145696]=49846,--Xu-Fu, Cub of Xuen
[145697]=49835,--Chi-Chi, Hatchling of Chi-Ji
[145699]=49845,--Zao, Calfling of Niuzao
[145698]=49836,--Yu'la, Broodling of Yu'lon
[148427]=47858,--Vengeful Porcupette
[147124]=49289,--Lil' Bling
[148046]=40908,--Ashleaft Spriteling
[148047]=51413,--Azure Crane Chick
[148049]=51268,--Blackfuse Bombling
[148050]=51271,--Ruby Droplet
[148051]=51408,--Dandelion Frolicker
[148058]=51417,--Droplet of Y'Shaarj
[148059]=51267,--Gooey Sha-ling
[148060]=51270,--Jademist Dancer
[148061]=51269,--Kovok
[148062]=51272,--Ominous Flame
[148063]=51279,--Skunky Alemental
[148066]=51278,--Spineclaw Crab
[148067]=47991,--Gulp Froglet
[148373]=51475,--Bonkers
[148527]=51502,--Gu'chi Swarmling
[148530]=47856,--Harmonious Porcupette
[148552]=51504,--Jadefire Spirit
[148684]=51530,--Sky Lantern
[148684]=51530,--Flimsy Sky Lantern
[148052]=51277,--Death Adder Hatchling
--5.4.1
[149787]=51988,--Alterac Brew-Pup
[149792]=51990,--Murkalot
--5.4.2
[149810]=51994,--Treasure Goblin
[154165]=37526,--Moonkin Hatchling
--[148577]=51507,--Crashin' Thrashin' Flyer
--5.4.7
[155748]=53719,--Dread Hatchling
--6.0.1
[167397]=57825,--Sun Sproutling
[159296]=54752,--Lil' Leftovers
[160403]=59021,--Mechanical Axebeak
[162209]=59021,--Mechanical Axebeak(Recipe)
[155838]=53748,--Iron Starlette
[161643]=53878,--Royal Peacock
[162135]=55679,--Lifelike Mechanical Frostboar
[162210]=55679,--Lifelike Mechanical Frostboar(Recipe)
[164212]=58722,--Teroclaw Hatchling
[167336]=57803,--Zomstrok
[158261]=54511,--Weebomination
[167731]=57970,--Ghastly Kid
[168977]=49259,--Sea Calf
[169220]=58395,--Deathwatch Hatchling
[169666]=58547,--Draenei Micro Defender
[169695]=58570,--Molten Corgi
[170292]=58770,--Sky-Bo
[170774]=47931,--Syd the Squid
[171222]=59099,--Mystical Spring Bouquet
[171500]=30969,--Bush Chicken
[171912]=58169,--Cursed Birman
[171915]=59330,--Widget the Departed
[170269]=59352,--Netherspawn, Spawn of Netherspawn
[172695]=15595,--Land Shark
[172998]=59668,--Lanticore Spawnling
[170273]=60016,--Hydraling
[177232]=61128,--Argi
[177234]=61127,--Grommloc
[177220]=61133,--Unused
[170268]=60441,--Hatespark the Tiny
[170289]=60458,--Stormwing
[170291]=59017,--Firewing
[167394]=57824,--Nightshade Sproutling
[167395]=57820,--Sassy Sproutling
[167392]=57821,--Kelp Sproutling
[159581]=54848,--Crazy Carrot
[167389]=57823,--Autumnal Sproutling
[167390]=57822,--Forest Sproutling
[10699]=6292,--Summon Bronze Whelpling
[170272]=60732,--Dread Dandelion
[170288]=49122,--Mechanical Scorpid
[176732]=49122,--Mechanical Scorpid(Recipe)
[170280]=60875,--Ore Eater
[176137]=60819,--Everbloom Peachick
[176140]=60820,--Sentinel's Companion
[170267]=53502,--Hogs
[170277]=60876,--Son of Sethe
[170281]=54855,--Frostwolf Pup
[169666]=58547,--Draenei Micro Defender
[170277]=60876,--Son of Sethe
[170286]=58617,--Bone Wasp
[170287]=58768,--Albino River Calf
[167390]=57822,--Forest Sproutling
[170271]=60909,--Sky Fry
[170275]=60930,--Eye of Observation
[168668]=39130,--Meadowstomper Calfling
[168668]=39130,--Meadowstomper Calfling
[170282]=58736,--Stonegrinder
[172632]=59577,--Ancient Nest Guardian
[170274]=59578,--Frostwolf Ghostpup
[170285]=58825,--Fruit Hunter
[173532]=59885,--Zangar Spore
[173543]=61548,--Umbrafen Spore
[173544]=61550,--Seaborne Spore
[173542]=61549,--Crimson Spore
[173547]=61547,--Brilliant Spore
[166071]=58170,--Elekk Plushie
[168849]=58170,--Elekk Plushie(Recipe)
[171118]=28502,--Lovebird Hatchling
[171552]=38473,--Blazing Cindercrawler
[171758]=42430,--Stout Alemental
--6.0.2
[170276]=58534,--Soul of the Forge
[177169]=58534,--Soul of the Forge(Recipe)
[177212]=53610,--Albino Chimaeraling
[170279]=59038,--Puddle Terror
[177227]=60617,--Sunfire Kaliri
[177233]=61148,--Trunks
[177216]=58932,--Pygmy Cow
[170278]=61016,--Servant of Demidos
[170283]=59603,--Veilwatcher Hatchling
[177215]=59034,--Kaliri Hatchling
--6.1
[179838]=61896,--Sunblade Micro-Defender
[179830]=61887,--Leviathan
[179831]=61888,--Abyssius
[179832]=61890,--Fragment of Anger
[179833]=61891,--Fragment of Suffering
[179834]=61889,--Fragment of Desire
[179835]=61892,--Sister of Temptation
[179836]=61894,--Stinkrot
[179837]=40224,--Hyjal Wisp
[179811]=61884,--Grotesque
[179839]=62466,--Chaos Pup
[179840]=61898,--Wretched Servant
[179841]=61900,--K'ute
[179954]=62404,--Race MiniZep
[177238]=60975,--Bone Serpent
[177218]=60609,--Young Talbuk
[177223]=62440,--Slithershock Elver
--6.2
[187532]=64097,--Corrupted Nest Guardian
[185601]=63693,--Blorp
[187376]=60972,--Glowing Sporebat
[187383]=60889,--Dusty Sporewing
[187384]=58613,--Bloodthorn Hatchling
[184481]=63447,--Lost Netherpup
[184482]=63446,--Cinder Pup
[184480]=61986,--Fel Pup
[185591]=63691,--Ghostshell Crab
[185055]=63584,--Nightmare Bell
[187555]=58760,--Periwinkle Calf
[188084]=64194,--Left Shark
[188235]=64222,--Crusher
[189357]=64425,--Shard of Cyrukh
[190682]=64720,--Savage Cub
[190681]=38310,--Blazing Firehawk
--6.2.2
[143637]=64587,--Summon Zeradar
[190035]=64588,--Summon Brightpaw
[190020]=64585,--Nibbles
[190036]=64589,--Summon Murkidan
[184480]=61986,--Fel Pup
[193572]=65713,--Energized Manafiend
[193588]=65717,--Empowered Manafiend
[193589]=65714,--Empyreal Manafiend
[191967]=65128,--Grumpling
--6.2.3
[204148]=68067,--Baby Winston
--7.0.3
[210682]=23408,--Alarm-o-Bot
[221684]=71002,--Alliance Enthusiast
[191425]=65070,--Ashmaw Cub
[210694]=66485,--Baby Elderhorn
[225200]=72658,--Benax
[210680]=65670,--Black Piglet
[193434]=65630,--Bleakwater Jelly
[193943]=65813,--Broot
[210679]=65669,--Brown Piglet
[210698]=68858,--Celestial Calf
[210701]=68729,--Corgi Pup
[223359]=68845,--Corgnelius
[224403]=72239,--Court Scribe
[193368]=65590,--Crispin
[193388]=65120,--Emmigosa
[191071]=69490,--Enchanted Cauldron
[191074]=69490,--Enchanted Cauldron(Recipe)
[191073]=69488,--Enchanted Pen
[191076]=69488,--Enchanted Pen(Recipe)
[191072]=69489,--Enchanted Torch
[191075]=69489,--Enchanted Torch(Recipe)
[210671]=65113,--Extinguished Eye
[210673]=65112,--Eye of Inquisition
[194294]=65672,--Fel Piglet
[210699]=68859,--Felbat Pup
[195368]=66155,--Fetid Waveling
[223339]=68860,--Firebat Pup
[210669]=65087,--Fledgling Warden Owl
[186299]=65071,--Grumpy
[210672]=65111,--Hateful Eye
[221683]=71003,--Horde Fanatic
[223027]=71938,--Hungering Claw --! display glitch
[210683]=59042,--Knockoff Blingtron
[223409]=71980,--Lagan
[213337]=70125,--Leather Pet Bed
[194776]=70125,--Leather Pet Bed(Recipe)
[210691]=66212,--Leyline Broodling
[221908]=71826,--Lurking Owl Kitten
[224536]=72085,--Nightmare Lasher
[224786]=72461,--Nightmare Treant
[210675]=71945,--Nightmare Whelpling
[194393]=65090,--Nightwatch Swooper
[210665]=65091,--Northern Hawk Owl
[194357]=65130,--Nursery Spider
[225663]=72660,--Squirky
[194330]=65638,--Plump Jelly
[215560]=65091,--Pygmy Owl
[210690]=66210,--Red Broodling
[226813]=70663,--Rescued Fawn
[210678]=65667,--Ridgeback Piglet
[195370]=66157,--Risen Saber Kitten
[223110]=55291,--River Calf
[210677]=65637,--Sewer-Pipe Jelly
[193680]=62216,--Skyhorn Nestling
[227093]=73093,--Snowfang
[193279]=65527,--Son of Goredome
[224397]=58170,--Souvenir Elekk
[224398]=58170,--Souvenir Elekk(Recipe)
[225688]=59818,--Souvenir Murloc
[225687]=59818,--Souvenir Murloc(Recipe)
[224401]=72238,--Souvenir Raptor
[224402]=72238,--Souvenir Raptor(Recipe)
[217218]=70937,--Sting Ray Pup
[193514]=67250,--Stormborne Whelpling
[210695]=69254,--Sunborne Val'kyr
[210681]=65671,--Thaumaturgical Piglet --! display issue
[195369]=66147,--Thistleleaf Adventurer
[210674]=65121,--Dream Whelpling
[221906]=71828,--Transmutant
[210696]=68666,--Trigger
[198981]=68666,--Trigger(Recipe)
[221907]=71827,--Untethered Wyrmling
[226682]=72900,--Wonderous Wisdomball
[210697]=69532,--Wyrmy Tunkins
[212749]=69896,--Zoom
--7.1.0
[231017]=74036,--Albino Buzzard
[229098]=73689,--Snaplasher
[229106]=73708,--Wicked Soul
[229105]=73707,--Drudge Ghoul
[230444]=73245,--Dutiful Gruntling
[230443]=73244,--Dutiful Squire
[229101]=73697,--Boneshard
[229090]=73661,--Dreadmaw
[229096]=29819,--Sanctum Cub
[227964]=73308,--Igneous Flameling
[229094]=26740,--Ironbound Proto-Whelp
[229091]=73663,--Snobold Runt
[229092]=59766,--Nerubian Swarmer
[227113]=28726,--Noblegarden Bunny
[229097]=73684,--Winter Rageling
[229099]=73692,--G0-R41-0N Ultratonk
[229103]=73704,--Blightbreath
[229093]=73671,--Magma Rageling
[229102]=73699,--Blood Boil
[229104]=73706,--Soulbroken Whelpling
[229110]=68857,--Stardust
[229095]=73673,--Runeforged Servitor
[229100]=73694,--Creeping Tentacle
--7.1.5
[233805]=74520,--Trashy
[234555]=74657,--Infinite Hatchling
[234556]=74700,--Paradox Spirit
[236285]=59026,--Tylarr Gronnden
--7.2
[233331]=74468,--Everliving Spore
[233335]=74472,--Young Venomfang
[233333]=74469,--Cavern Moccasin
[186299]=65071,--Grumpy
[237250]=75315,--Bloodbrood Whelpling
[237251]=75316,--Frostbrood Whelpling
[243136]=68861,--Orphaned Felbat
[240794]=75989,--Ban-Fu, Cub of Ban-Lu
[232867]=58823,--Crackers
[240064]=75766,--Scraps
[242047]=76262,--Son of Skum
[237252]=75317,--Vilebrood Whelpling
--7.2.5
[249870]=78587,--Micronax
[244345]=75498,--Pocket Cannon
[247452]=78106,--Mining Monkey
[248240]=78261,--Summon Ageless Bronze Drake
[248025]=78222,--Summon Bronze Proto-Whelp
[244440]=76956,--Tricorne
[247123]=1072,--Sneaky Marmot
[247474]=1418,--Dig Rat
[244466]=45555,--Pet Reaper 50
--7.3
[253929]=79712,--Amalgam of Destruction
[253818]=79639,--Drafty
[253918]=45289,--Cinderweb Recluse
[254196]=79777,--Cross Gazer
[254295]=79796,--Docile Skyfin
[253927]=71972,--Corrupted Blood
[253790]=79634,--Discarded Experiment
[253925]=38283,--Infernal Pyreclaw
[254271]=79783,--Fel Lasher
[254296]=79797,--Fel-Afflicted Skyfin
[254255]=78451,--Felclaw Marsuul
[254298]=79798,--Fossorial Bile Larva
[251191]=78989,--Ghost Shark
[254297]=79760,--Grasping Manifestation
[253809]=79637,--Bound Stream
[233647]=74513,--Dibbler
[233649]=74514,--Naxxy
[253805]=79635,--Twilight Clutch-Sister
[254197]=79776,--Orphaned Marsuul
[253926]=65888,--Faceless Mindlasher
[254749]=79888,--Rebellious Imp
[253788]=79630,--Tinytron
[253928]=79711,--Unstable Tendril
[253799]=24751,--Rattlejaw
[253916]=79707,--Blazehound
[243499]=76595,--Twilight
[253813]=79638,--Faceless Minion
[254763]=76829,--Uuna
[253924]=79709,--Surger
[253816]=79641,--Zephyrian Prince
--7.3.5
[260887]=82391,--Mailemental
[246105]=77501,--Shadow
[261755]=82688,--Silithid Mini-Tank
--8.0.1
[279638]=87870,--Aldrusian Sproutling
[279723]=87903,--Ragepeep
[277461]=80456,--Baa'l
[279435]=83653,--Baby Crawg
[280619]=80458,--Slippy
[177242]=88012,--Pet Template
[280332]=88005,--Bloodstone Tunneler
[280727]=87998,--Bucketshell
[177243]=88016,--Pet Template
[280337]=86463,--Coldlight Surfrunner
[177235]=88002,--Pet Template
[259758]=81984,--Dart
[177228]=88040,--Pet Template
[256010]=80456,--REUSE
[274760]=86482,--Summon Enchanted Tiki Mask
[264001]=75339,--Francois
[177231]=26524,--Pet Template
[273184]=86101,--Summon Filthy Slime
[279631]=87862,--Fuzzy Creepling
[177225]=88058,--Pet Template
--[257141]=,--Hot Air Balloon - Pet (NEEDS NAME)(Recipe)
[177239]=88034,--Pet Template
[273869]=86231,--Summon Vengeful Chicken
[274348]=86484,--Summon Direhorn Hatchling
[280335]=88007,--Juvenile Brineshell
[177236]=88001,--Pet Template
[280336]=88008,--Kunchong Hatchling
[177224]=88060,--Pet Template
[280185]=87976,--Lil' Siege Tower
[274202]=86445,--Summon Lil' Tika
[280188]=87977,--Lil' War Machine
[177219]=88061,--Pet Template
[279433]=83685,--Lost Platysaur
[279930]=16880,--Squawkling
[177221]=88059,--Pet Template
[280334]=88036,--Muskflank Calfling
[177240]=88017,--Pet Template
[274380]=86806,--Summon Restored Revenant
[279724]=74038,--Foulfeather
[177222]=88057,--Pet Template
[273195]=86136,--Summon Poda
[177241]=88003,--Pet Template
[191071]=69490,--Enchanted Cauldron
[191071]=69490,--Enchanted Cauldron
[177229]=88038,--Pet Template
[279686]=87895,--Scabby
[177244]=87999,--Pet Template
[279929]=87945,--Fozling
[280728]=87997,--Sir Snips
[273215]=86135,--Summon Smoochums
[273839]=86229,--Summon Guardian Cobra Hatchling
[177217]=81098,--Pet Template
[280333]=88035,--Snort
[177237]=88000,--Pet Template
[273159]=86088,--Summon Spawn of Merektha
[280331]=88064,--Sunscale Hatchling
[274353]=86488,--Summon Taptaf
[279657]=87890,--Teeny Titan Orb
[177226]=45190,--Pet Template
[274776]=86574,--Summon Mummy
[177230]=88004,--Pet Template
[279643]=87871,--Voidwiggler
[280618]=80458,--Bloodfeaster Larva
[280338]=88037,--Voru'kar Leecher
[280617]=78837,--Gearspring Hopper
[272772]=86021,--Cap'n Crackers
--8.1
[289606]=77901,--Albatross Hatchling
[288890]=80967,--Albino Duskwatcher
[288867]=66487,--Baby Stonehide
[288582]=5187,--Gust of Cyclarus
[288595]=23000,--Hydrath Water Droplet
[289629]=36743,--Cobalt Raven
[288919]=88023,--Crimson Octopode
[288486]=90155,--Darkshore Sentinel
[286483]=30298,--Child of Pa'ku
[288597]=90140,--Everburning Treant
[288895]=90181,--Firesting Buzzer
[288868]=90173,--Leatherwing Screecher
[286576]=88785,--Leper Rat
[288901]=90182,--Lord Woofington
[286574]=88790,--Mechanical Cockroach
[286474]=80802,--Feathers
[286514]=90411,--Mechantula
[286478]=90411,--Mechantula(Recipe)
[286790]=31623,--Mini Spider Tank
[288875]=90177,--Needleback Pup
[289359]=90230,--Nightwreathed Watcher
[289622]=80954,--Crimson Bat Pup
[288054]=80413,--Proper Parrot
[288592]=81665,--Detective Ray
[289604]=90279,--Rebuilt Gorilla Bot
[289605]=90412,--Rebuilt Mechanical Spider
[286582]=89767,--Alarm-O-Dog
[285843]=89609,--Redridge Tarantula
[288870]=90176,--Rotting Ghoul
[288914]=90183,--Scritches
[288889]=80966,--Shadefeather Hatchling
[286484]=77989,--Spawn of Krag'wa
[288598]=90141,--Void Jelly
[288009]=90030,--Tanzil
[286482]=89742,--Thunder Lizard Runt
[288916]=90184,--Thunderscale Whelpling
[288910]=76763,--Tonguelasher
[288006]=90029,--Trecker
[289633]=78243,--Violet Abyssal Eel
[272771]=86020,--Summon Whomper
[286837]=86573,--Wicker Wraith
[287997]=90028,--Dasher
[288600]=90142,--Zur'aj the Depleted
--8.1.5
[283740]=89260,--Horse Balloon
[283741]=89262,--Murloc Balloon
[257603]=58823,--Perculia's Peculiar Parrot
[283744]=89261,--Wolf Balloon
--8.2
[300934]=92073,--Adventurous Hopling
[303784]=92502,--Armored Vaultbot
[303899]=92580,--Burnout
[302003]=10723,--Shrieker
[301996]=9758,--Crypt Fiend
[300387]=92265,--Minimancer
[300367]=6290,--Ghostly Whelpling
[300325]=88784,--Golden Cricket
[303608]=80254,--Irradiated Elementaling
[300270]=90878,--Microbot XD(Recipe)
[294279]=91224,--Slimy Darkhunter
[294278]=91249,--Slimy Eel
[294277]=91248,--Slimy Fangtooth
[294280]=91220,--Slimy Hermit Crab
[294276]=91232,--Slimy Octopode
[294275]=91250,--Slimy Otter
[294274]=91219,--Slimy Sea Slug
[301985]=92266,--Gruesome Belcher
[300269]=74800,--Utility Mechanoclaw(Recipe)
[301992]=23057,--Ziggy

------------------------------------------
--**************************************--
--**************** TOYS ****************--
--**************************************--
------------------------------------------
--2.0.1
[30261]=16970,--Crashin Robot
[30337]=16970,--Crashin Robot(Recipe)
--2.4.0
[45426]=23523,--Brazier of Dancing Flames
}

--Battle pet data table--
mp.petTable = {
--1.11.1 and earlier
[39]=7937,--Mechanical Squirrel
[40]=5556,--Bombay Cat
[41]=5586,--Cornish Rex Cat
[42]=5448,--Black Tabby Cat
[43]=5554,--Orange Tabby Cat
[44]=5585,--Siamese Cat
[45]=5555,--Silver Tabby Cat
[46]=9990,--White Kitten
[47]=6191,--Cockatiel
[49]=6192,--Hyacinth Macaw
[50]=5207,--Green Wing Macaw
[51]=6190,--Senegal
[52]=5369,--Ancona Chicken
[55]=2177,--Undercity Cockroach
[56]=6288,--Dark Whelpling
[58]=6290,--Crimson Whelpling
[59]=6291,--Emerald Whelpling
[64]=901,--Wood Frog
[65]=6295,--Tree Frog
[67]=6299,--Hawk Owl
[68]=4615,--Great Horned Owl
[70]=1072,--Brown Prairie Dog
[72]=328,--Snowshoe Rabbit
[75]=1206,--Black Kingsnake
[77]=2957,--Brown Snake
[78]=6303,--Crimson Snake
[83]=7920,--Mechanical Chicken
[85]=8909,--Pet Bombling
[86]=8910,--Lil' Smoky
[87]=6294,--Sprite Darter Hatchling
[89]=9563,--Worg Pup
[90]=27718,--Smolderweb Hatchling
[92]=10990,--Panda Cub
[93]=10992,--Mini Diablo
[94]=10993,--Zergling
[95]=901,--Lifelike Toad
[106]=14938,--Jubling
[107]=15369,--Murky
[114]=15436,--Disgusting Oozeling
[116]=10269,--Tranquil Mechanical Yeti
[117]=13610,--Tiny Snowman
[118]=15904,--Winter Reindeer
[119]=15660,--Father Winter's Helper
[120]=15663,--Winter's Little Helper
[121]=15984,--Gurky
[122]=15992,--Peddlefeet
[125]=16259,--Speedy
[126]=16257,--Mr. Wiggles
[127]=2176,--Whiskers the Rat
[128]=16587,--Spirit of Summer
--1.12.1
[57]=6293,--Azure Whelpling
[69]=6298,--Snowy Owl
[74]=2955,--Albino Snake
[111]=15398,--Lurky
[757]=14778,--Tiny Green Dragon
[758]=14779,--Tiny Red Dragon
[1168]=15395,--Murki
[1352]=22938,--Chubbs
--2.0
[130]=16943,--Hippogryph Hatchling
--2.0.1
[132]=18269,--Magical Crawdad
[136]=19600,--Mana Wyrmling
[137]=4626,--Brown Rabbit
[138]=19987,--Blue Moth
[139]=19986,--Red Moth
[140]=19985,--Yellow Moth
[141]=19999,--White Moth
[142]=20026,--Golden Dragonhawk Hatchling
[143]=20027,--Red Dragonhawk Hatchling
[144]=20037,--Silver Dragonhawk Hatchling
[149]=20996,--Miniwing
[156]=21362,--Bananas
--2.1
[131]=17723,--Netherwhelp
[146]=20042,--Firefly
[155]=21328,--Lucky
[157]=21381,--Willy
[158]=21382,--Egbert
[159]=21393,--Peanut
--2.2
[145]=20029,--Blue Dragonhawk Hatchling
--2.2.2
[153]=22349,--Wolpertinger
--2.3
[162]=21900,--Sinister Squashling
[163]=22388,--Toothy
[164]=22389,--Muckbreath
[165]=22459,--Mojo
[167]=22855,--Tiny Sporebat
[168]=22903,--Rocket Chicken
[169]=22966,--Dragon Kite
[191]=22776,--Clockwork Rocket Bot
--2.4
[124]=16189,--Poley
[160]=16633,--Stinker
[166]=22629,--Pint-Sized Pink Pachyderm
[170]=21304,--Golden Pig
[171]=22938,--Silver Pig
[172]=8409,--Searing Scorchling
[173]=23507,--Snarly
[174]=23506,--Chuck
[175]=23574,--Phoenix Hatchling
[1073]=15398,--Terky
--2.4.2
[183]=25002,--Ethereal Soul-Trader
[186]=25457,--Nether Ray Fry
[189]=25900,--Mini Tyrael
--2.4.3
[179]=24393,--Spirit of Competition
[180]=24620,--Essence of Competition
--3.0.1
[115]=15595,--Baby Shark
--3.0.2
[84]=304,--Westfall Chicken
[187]=4185,--Vampiric Batling
[190]=28089,--Ghostly Skull
[193]=27627,--Giant Sewer Rat
[194]=45919,--Tickbird Hatchling
[195]=28215,--White Tickbird Hatchling
[196]=28217,--Proto-Drake Whelp
[197]=28084,--Cobra Hatchling
[198]=28216,--Pengu
--3.0.3
[188]=28456,--Frosty
[199]=45937,--Kirin Tor Familiar
[202]=16189,--Baby Blizzard Bear
--3.0.8
[203]=28397,--Little Fawn
--3.1
[211]=45880,--Strand Crawler
[214]=28946,--Argent Squire
[216]=28948,--Argent Gruntling
--3.1.1
[209]=16205,--Elwynn Lamb
[212]=28493,--Ammen Vale Lashling
[213]=45960,--Enchanted Broom
[218]=46939,--Sen'jin Fetish
--3.1.3
[227]=29279,--Warbot
--3.2
[229]=29372,--Shimmering Wyrmling
[234]=29803,--Gundrak Hatchling
[235]=29802,--Leaping Hatchling
[236]=29809,--Obsidian Hatchling
--3.2.2
[201]=45968,--Plump Turkey
[1351]=29404,--Macabre Marionette
--3.3
[228]=29348,--Grunty
[248]=30414,--Pandaren Monk
[250]=31174,--Perky Pug
--3.3.2
[246]=30413,--Wind Rider Cub
--3.3.3
[200]=6302,--Spring Rabbit
[204]=28482,--Teldrassil Sproutling
[205]=28489,--Dun Morogh Cub
[215]=28539,--Mechanopeep
[224]=11709,--Calico Cat
[226]=25384,--Curious Wolvar Pup
[237]=29810,--Ravasaur Hatchling
[238]=29808,--Razormaw Hatchling
[242]=30409,--Spectral Tiger Cub
[245]=30412,--Gryphon Hatchling
[249]=30507,--Lil' K.T.
[253]=31722,--Frigid Frostling
[254]=22778,--Blue Clockwork Rocket Bot
--3.3.5
[192]=26452,--Mr. Chilly
[206]=4732,--Tirisfal Batling
[207]=15470,--Durotar Scorpion
[210]=28502,--Mulgore Hatchling
[217]=28734,--Murkimus the Gladiator
[225]=25173,--Curious Oracle Hatchling
[232]=29805,--Darting Hatchling
[233]=29807,--Deviate Hatchling
[239]=29806,--Razzashi Hatchling
[243]=30356,--Onyxian Whelpling
[256]=32031,--Lil' XT
--4.0.1
[220]=45943,--Withers
[266]=34413,--Fossilized Hatchling
[277]=36211,--Clockwork Gnome
[291]=37154,--Singing Sunflower
--4.0.3
[259]=32699,--Blue Mini Jouster
[262]=33559,--De-Weaponized Mechanical Companion
[265]=45940,--Pebble
[267]=36902,--Enchanted Lantern
[279]=36637,--Tiny Shale Spider
[285]=32031,--Landro's Lil' XT
[287]=28435,--Tiny Flamefly
[293]=45878,--Elementium Geode
[296]=37526,--Moonkin Hatchling
[297]=37541,--Lil' Ragnaros
--4.1
[302]=30507,--Landro's Lichling
[307]=38065,--Lashtail Hatchling
--4.2
[323]=38693,--Nuts
[331]=38343,--Alliance Balloon
--4.2.2
[311]=38359,--Guardian Cub
--4.3
[330]=46001,--Darkmoon Monkey
[335]=38809,--Darkmoon Turtle
[336]=38344,--Darkmoon Balloon
[337]=45939,--Lumpy
[338]=15381,--Darkmoon Tonk
[339]=17192,--Darkmoon Zeppelin
[343]=39137,--Darkmoon Cub
--5.0.1
[231]=29605,--Jade Tiger
[374]=42906,--Black Lamb
[378]=328,--Rabbit
[379]=134,--Squirrel
[381]=41833,--Porcupette
[383]=43798,--Eternal Strider
[385]=4959,--Mouse
[386]=1072,--Prairie Dog
[387]=1206,--Snake
[388]=45880,--Shore Crab
[389]=41886,--Tiny Harvester
[390]=45889,--Deer
[391]=328,--Mountain Cottontail
[392]=1141,--Redridge Rat
[393]=2177,--Cockroach
[394]=856,--Sheep
[395]=41887,--Fledgling Buzzard
[396]=2536,--Dusk Spiderling
[397]=16633,--Skunk
[398]=1141,--Black Rat
[399]=3126,--Rat Snake
[400]=45905,--Widow Spiderling
[401]=32789,--Strand Crab
[402]=36944,--Swamp Moth
[403]=6189,--Parrot
[404]=4959,--Long-tailed Mole
[405]=36578,--Tree Python
[406]=7511,--Beetle
[407]=45902,--Forest Spiderling
[408]=36583,--Lizard Hatchling
[409]=42509,--Polly
[410]=1141,--Wharf Rat
[411]=21362,--Baby Ape
[412]=45902,--Spider
[414]=15469,--Scorpid
[415]=8971,--Fire Beetle
[416]=41960,--Scorpling
[417]=1141,--Rat
[418]=1986,--Water Snake
[419]=6297,--Small Frog
[420]=901,--Toad
[421]=36671,--Crimson Moth
[422]=1986,--Moccasin
[423]=28507,--Lava Crab
[424]=2177,--Roach
[425]=4268,--Ash Viper
[427]=45904,--Ash Spiderling
[428]=42051,--Molten Hatchling
[429]=41981,--Lava Beetle
[430]=15467,--Gold Beetle
[431]=35804,--Rattlesnake
[432]=15469,--Stripe-Tailed Scorpid
[433]=36585,--Spiky Lizard
[434]=10000,--Ram
[437]=42068,--Little Black Ram
[438]=2954,--King Snake
[439]=45917,--Restless Shadeling
[440]=42203,--Snow Cub
[441]=36342,--Alpine Hare
[442]=2177,--Irradiated Roach
[443]=328,--Grasslands Cottontail
[445]=45936,--Tiny Twister
[446]=42218,--Jade Oozeling
[447]=654,--Fawn
[448]=1560,--Hare
[449]=45899,--Brown Marmot
[450]=9904,--Maggot
[452]=36620,--Red-Tailed Chipmunk
[453]=42229,--Infested Bear Cub
[454]=1141,--Undercity Rat
[455]=42334,--Blighted Squirrel
[456]=42265,--Blighthawk
[457]=9904,--Festering Maggot
[458]=45952,--Lost of Lordaeron
[459]=5585,--Cat
[460]=42335,--Ruby Sapling
[461]=9906,--Larva
[463]=42342,--Spirit Crab
[464]=42343,--Grey Moth
[465]=42344,--Ravager Hatchling
[466]=36583,--Spiny Lizard
[467]=7511,--Dung Beetle
[468]=46940,--Creepy Crawly
[469]=36644,--Twilight Beetle
[470]=36236,--Twilight Spider
[471]=7920,--Robo-Chick
[472]=26532,--Rabid Nut Varmint 5000
[473]=27881,--Turquoise Turtle
[474]=42362,--Cheetah Cub
[475]=45896,--Giraffe Calf
[476]=1547,--Gazelle
[477]=45958,--Gazelle Fawn
[478]=36944,--Forest Moth
[479]=328,--Elfin Rabbit
[480]=36648,--Topaz Shale Hatchling
[482]=4268,--Rock Viper
[483]=36583,--Horny Toad
[484]=45906,--Desert Spider
[485]=42381,--Stone Armadillo
[486]=45890,--Mule Deer
[487]=36620,--Alpine Chipmunk
[488]=36580,--Coral Snake
[489]=42745,--Spawn of Onyxia
[491]=5586,--Sand Kitten
[492]=7511,--Stinkbug
[493]=42407,--Shimmershell Snail
[494]=42416,--Silithid Hatchling
[495]=6297,--Frog
[496]=42409,--Rusty Snail
[497]=2177,--Tainted Cockroach
[498]=36944,--Tainted Moth
[499]=1141,--Tainted Rat
[500]=46003,--Minfernal
[502]=6297,--Spotted Bell Frog
[503]=36944,--Silky Moth
[504]=45913,--Diemetradon Hatchling
[505]=42415,--Twilight Iguana
[506]=45908,--Venomspitter Hatchling
[507]=6300,--Crested Owl
[508]=42412,--Darkshore Cub
[509]=42202,--Tiny Bog Beast
[511]=35804,--Sidewinder
[512]=35113,--Scarab Hatchling
[513]=42523,--Qiraji Guardling
[514]=42553,--Flayer Youngling
[515]=42554,--Sporeling Sprout
[517]=45998,--Warpstalker Hatchling
[518]=42575,--Clefthoof Runt
[519]=45923,--Fel Flame
[521]=45988,--Fledgling Nether Ray
[523]=45885,--Devouring Maggot
[525]=45968,--Turkey
[528]=45953,--Scalded Basilisk Hatchling
[529]=42617,--Fjord Worg Pup
[530]=42781,--Oily Slimeling
[535]=30159,--Water Waveling
[536]=25390,--Tundra Penguin
[539]=4959,--Grotto Vole
[540]=1141,--Carrion Rat
[541]=2177,--Fire-Proof Roach
[542]=6297,--Mac Frog
[543]=2177,--Locust
[544]=36944,--Oasis Moth
[545]=15469,--Leopard Scorpid
[546]=42771,--Tol'vir Scarab
[547]=45820,--Nordrassil Wisp
[548]=30412,--Wildhammer Gryphon Hatchling
[549]=45900,--Yellow-Bellied Marmot
[550]=4959,--Highlands Mouse
[553]=1141,--Stowaway Rat
[554]=36605,--Crimson Shale Hatchling
[555]=45897,--Deepholm Cockroach
[556]=15467,--Crystal Beetle
[557]=42467,--Nether Faerie Dragon
[558]=42757,--Arctic Fox Kit
[559]=45879,--Crimson Geode
[560]=45995,--Sea Gull
[562]=36544,--Coral Adder
[564]=27883,--Emerald Turtle
[565]=6297,--Jungle Darter
[566]=45852,--Mirror Strider
[567]=2955,--Temple Snake
[568]=38380,--Silkbead Snail
[569]=38831,--Garden Frog
[570]=40093,--Masked Tanuki
[571]=35802,--Grove Viper
[572]=45880,--Spirebound Crab
[573]=45994,--Sandy Petrel
[626]=4732,--Bat
[627]=10090,--Infected Squirrel
[628]=37686,--Infected Fawn
[629]=32790,--Shore Crawler
[630]=42872,--Gilnean Raven
[631]=36578,--Emerald Boa
[632]=36583,--Ash Lizard
[633]=16633,--Mountain Skunk
[634]=45909,--Crystal Spider
[635]=1986,--Adder
[637]=20923,--Skittering Cavern Crawler
[638]=2177,--Nether Roach
[639]=1072,--Borean Marmot
[640]=328,--Snowshoe Hare
[641]=328,--Arctic Hare
[644]=22175,--Fjord Rat
[645]=45970,--Highlands Turkey
[646]=304,--Chicken
[647]=134,--Grizzly Squirrel
[648]=5379,--Huge Toad
[649]=1924,--Biletoad
[650]=44655,--Terrible Turnip
[652]=47955,--Tiny Goldfish
[671]=43255,--Lucky Quilen Cub
[675]=1141,--Stormwind Rat
[678]=40226,--Jungle Grub
[680]=43347,--Kuitan Mongoose
[699]=45911,--Jumping Spider
[702]=6296,--Leopard Tree Frog
[703]=43194,--Masked Tanuki Pup
[706]=40089,--Bandicoon
[707]=41834,--Bandicoon Kit
[708]=45991,--Malayan Quillrat
[709]=45990,--Malayan Quillrat Pup
[710]=43360,--Marsh Fiddler
[711]=42856,--Sifang Otter
[712]=42983,--Sifang Otter Pup
[713]=27679,--Softshell Snapling
[714]=44816,--Feverbite Hatchling
[716]=45910,--Amethyst Spiderling
[717]=45996,--Savory Beetle
[718]=36955,--Luyu Moth
[722]=28434,--Mei Li Sparkler
[723]=42859,--Spiny Terrapin
[724]=36388,--Alpine Foxling
[725]=42757,--Alpine Foxling Kit
[726]=45999,--Plains Monitor
[727]=4959,--Prairie Mouse
[728]=304,--Szechuan Chicken
[729]=6302,--Tolai Hare
[730]=28998,--Tolai Hare Pup
[731]=4440,--Zooey Snake
[732]=36956,--Amber Moth
[733]=43344,--Grassland Hopper
[737]=43347,--Mongoose
[739]=43346,--Mongoose Pup
[740]=4959,--Yakrat
[741]=45984,--Silent Hedgehog
[742]=45985,--Clouded Hedgehog
[743]=45882,--Rapana Whelk
[744]=45898,--Resilient Roach
[745]=15469,--Crunchy Scorpion
[746]=45881,--Emperor Crab
[747]=46000,--Effervescent Glowfly
[748]=36956,--Gilded Moth
[749]=43428,--Golden Civet
[750]=43259,--Golden Civet Kitten
[751]=40584,--Dancing Water Skimmer
[752]=6297,--Yellow-Bellied Bullfrog
[755]=2177,--Death's Head Cockroach
[756]=36944,--Fungal Moth
[802]=43865,--Thundering Serpent Hatchling
[817]=43875,--Wild Jade Hatchling
[818]=45064,--Wild Golden Hatchling
[821]=45894,--Feral Vermling
[823]=22447,--Highlands Skunk
[834]=45938,--Grinder
[836]=45854,--Aqua Strider
[837]=36603,--Emerald Shale Hatchling
[838]=36604,--Amethyst Shale Hatchling
[847]=42721,--Fishy
[848]=45957,--Darkmoon Rabbit
[851]=36583,--Horned Lizard
[872]=2954,--Slither
[873]=2958,--Fangs
[874]=1418,--Teensy
[875]=26184,--Clucks
[876]=45555,--Foe Reaper 800
[877]=36342,--Flipsy
[880]=45558,--Darkwidow
[881]=43193,--Blackfang
[882]=40338,--Webwinder
[885]=29963,--Nanners
[886]=45561,--Young Beaky
[887]=45560,--Eyegouger
--5.0.3
[844]=45386,--Mechanical Pandaren Dragonling
[845]=15905,--Jade Owl
[849]=44791,--Chi-Ji Kite
[856]=45987,--Jade Tentacle
[889]=45564,--Mumtar
[890]=45563,--Spike
[891]=45567,--Ripper
[892]=45565,--Springtail
[893]=45895,--Longneck
[894]=45569,--Flutterby
[895]=36313,--Oozer
[896]=45568,--Mister Pinch
[897]=45570,--Acidous
[898]=42670,--Odoron
[899]=1986,--Constrictor
[900]=45572,--Rockhide
[901]=45573,--Ambershell
[902]=43221,--Bounder
[904]=45576,--Prancer
[905]=45574,--Rasp
[906]=45577,--Glimmer
[907]=45578,--Whirls
[908]=45579,--Cluckatron
[909]=45580,--Gizmo
[911]=45581,--Firetooth
[912]=45582,--Flameclaw
[915]=45583,--Cho'guana
[916]=22175,--Plague
[917]=45584,--Indigon
[921]=45587,--Ultramus
[922]=45585,--Beamer
[923]=45586,--Hatewalker
[924]=39352,--Lacewing
[925]=45590,--Beacon
[926]=45589,--Willow
[927]=45591,--Blizzy
[928]=45637,--Frostmaw
[929]=45593,--Tinygos
[931]=45594,--Plop
[932]=45595,--Corpsefeeder
[933]=45597,--Subject 142
[934]=45599,--Plaguebringer
[935]=45598,--Bleakspinner
[936]=20265,--Carrion
[937]=45600,--Obsidion
[938]=45601,--Veridia
[939]=45602,--Garnestrasz
[944]=45884,--Moltar
[945]=45611,--Ignious
[946]=44533,--Comet
[947]=45612,--Nightstalker
[948]=45613,--Bishibosh
[949]=21900,--Jack
[950]=8189,--Sploder
[951]=32670,--Goliath
[952]=29279,--ED-005
[953]=45614,--Fungor
[954]=45615,--Tripod
[955]=45616,--Glitterfly
[959]=45619,--Cragmaw
[960]=45620,--Gnasher
[961]=45621,--Chomps
[962]=45622,--Netherbite
[963]=45623,--Jadefire
[964]=22587,--Arcanus
[965]=45624,--Warble
[966]=45625,--Gobbles
[967]=45626,--Dinner
[968]=45629,--Mort
[969]=45628,--Stitch
[970]=45630,--Spooky Strangler
[971]=45632,--Rot
[974]=45634,--Blight
[975]=45635,--Fleshrender
[976]=37327,--Cadavus
[977]=19290,--Bloom
[978]=45636,--Beakmaster X-225
[979]=23947,--Grizzle
[995]=45099,--Brood of Mothallus
[996]=45652,--Toothbreaker
[997]=45651,--Siren
[998]=45080,--Woodcarver
[999]=45653,--Needleback
[1000]=36955,--Lightstalker
[1001]=45654,--Bleat
[1002]=23926,--Lapin
[1003]=30971,--Piqua
[1007]=40121,--Mutilator
[1008]=45658,--Pounder
[1009]=45657,--Crusher
[1010]=45660,--Whiskers
[1011]=45661,--Stormlash
[1012]=43352,--Chirrup
--5.0.4
[868]=45942,--Pandaren Water Spirit
[878]=45556,--Dipsy
[883]=45559,--Emeralda
[888]=45562,--Burgle
[913]=30356,--Blaze
[941]=45606,--Anklor
[942]=21950,--Croaker
[943]=45603,--Dampwing
[957]=2838,--Dramaticus
[958]=5379,--Prince Wart
[983]=33293,--Fracture
[987]=19634,--Amythel
[988]=45646,--Twilight
[990]=45647,--Spring
[991]=45648,--Pyth
[992]=45650,--Dor the Wall
[994]=45617,--Skyshaper
[1004]=45655,--Skimmer
[1013]=44779,--Wanderer's Festival Hatchling
[1042]=46385,--Red Cricket
--5.1
[1040]=40521,--Imperial Silkworm
[1067]=46193,--Honky-Tonk
[1124]=46809,--Pandaren Fire Spirit
[1125]=46810,--Pandaren Air Spirit
[1127]=30409,--Spectral Cub
[1128]=40714,--Sumprush Rodent
[1145]=46897,--Mr. Bigglesworth
[1146]=46921,--Stitched Pup
[1147]=46900,--Harbinger of Flame
[1150]=46902,--Ashstone Core
[1152]=46925,--Chrominius
[1156]=46909,--Mini Mindslayer
[1160]=46941,--Arcane Eye
[1161]=47636,--Infinite Whelpling
[1163]=46948,--Anodized Robo Cub
[1164]=47021,--Cogblade Raptor
[1165]=47635,--Nexus Whelpling
--5.2
[240]=29819,--Onyx Panther
[241]=30157,--Tuskarr Kite
[244]=30462,--Core Hound Pup
[247]=30402,--Zipao Tiger
[251]=31073,--Toxic Wasteling
[255]=31956,--Celestial Dragon
[258]=32670,--Mini Thor
[260]=32707,--Gold Mini Jouster
[261]=33512,--Personal World Destroyer
[264]=34262,--Crawling Claw
[268]=35338,--Lil' Deathwing
[270]=37136,--Dark Phoenix Hatchling
[271]=36499,--Rustberg Gull
[272]=36220,--Armadillo Pup
[278]=33217,--Fox Kit
[280]=37200,--Guild Page
[281]=37199,--Guild Page
[282]=37198,--Guild Herald
[283]=37196,--Guild Herald
[286]=9905,--Mr. Grubbs
[289]=38135,--Scooter the Snail
[292]=36901,--Magic Lamp
[294]=36896,--Deathy
[298]=37527,--Moonkin Hatchling
[301]=37814,--Panther Cub
[303]=37846,--Nightsaber Cub
[306]=37712,--Winterspring Cub
[308]=38134,--Legs
[309]=38229,--Pterrordax Hatchling
[310]=38232,--Voodoo Figurine
[316]=16943,--Cenarion Hatchling
[317]=38455,--Hyjal Bear Cub
[318]=38429,--Crimson Lasher
[319]=38539,--Feline Familiar
[320]=38614,--Lil' Tarecgosa
[321]=38638,--Creepy Crate
[325]=38776,--Brilliant Kaliri
[328]=38777,--Purple Puffer
[329]=38803,--Murkablo
[332]=38342,--Horde Balloon
[333]=38919,--Gregarious Grell
[340]=39109,--Sea Pony
[341]=39163,--Lunar Lantern
[342]=39333,--Festival Lantern
[344]=38340,--Green Balloon
[345]=38341,--Yellow Balloon
[346]=39380,--Fetish Shaman
[347]=40019,--Soul of the Aspects
[348]=40538,--Eye of the Legion
[380]=40713,--Bucktooth Flapper
[532]=42708,--Stunted Shardhorn
[534]=42709,--Imperial Eagle Chick
[537]=42735,--Dragonbone Hatchling
[538]=42737,--Scourged Whelpling
[552]=42783,--Twilight Fiendling
[665]=39694,--Sand Scarab
[677]=40089,--Shy Bandicoon
[679]=43485,--Summit Kid
[753]=36671,--Garden Moth
[754]=20042,--Shrine Fly
[792]=43868,--Jade Crane Chick
[819]=43874,--Wild Crimson Hatchling
[820]=43127,--Singing Cricket
[835]=43597,--Hopling
[846]=42297,--Sapphire Cub
[850]=44792,--Yu'lon Kite
[855]=45195,--Venus
[879]=45557,--Flufftail
[884]=45639,--Moonstalker
[903]=45527,--Baneling
[956]=45618,--Stompy
[972]=45633,--Sleet
[973]=45631,--Drogar
[980]=5990,--Incinderous
[981]=45643,--Ashtail
[982]=45644,--Kali
[984]=45645,--Crystallus
[985]=36436,--Ruby
[986]=42988,--Helios
[989]=34913,--Clatter
[993]=45649,--Fangor
[1005]=32661,--Mollus
[1006]=45656,--Diamond
[1039]=44551,--Imperial Moth
[1061]=46163,--Darkmoon Hatchling
[1062]=46171,--Darkmoon Glowfly
[1063]=46174,--Darkmoon Eye
[1065]=46174,--Judgement
[1066]=46192,--Fezwick
[1068]=36743,--Crow
[1117]=46720,--Cinder Kitten
[1126]=46811,--Pandaren Earth Spirit
[1129]=46862,--Ka'wi the Gorger
[1142]=46882,--Clock'em
[1143]=46898,--Giant Bone Spider
[1144]=46896,--Fungal Abomination
[1149]=46923,--Corefire Imp
[1151]=46903,--Untamed Hatchling
[1153]=46905,--Death Talon Whelpguard
[1154]=46924,--Viscidus Globule
[1155]=46922,--Anubisath Idol
[1157]=46936,--Harpy Youngling
[1158]=46937,--Stunted Yeti
[1159]=46938,--Lofty Libram
[1162]=46947,--Fluxfire Feline
[1166]=46953,--Kun-Lai Runt
[1167]=46954,--Emerald Proto-Whelp
[1174]=47348,--Gusting Grimoire
[1175]=47633,--Thundertail Flapper
[1176]=47634,--Red Panda
[1177]=47252,--Living Sandling
[1178]=47848,--Sunreaver Micro-Sentry
[1179]=47690,--Electrified Razortooth
[1180]=47731,--Zandalari Kneebiter
[1181]=47887,--Elder Python
[1182]=47989,--Swamp Croaker
[1183]=47708,--Son of Animus
[1184]=48211,--Stunted Direhorn
[1185]=47732,--Spectral Porcupette
[1187]=47740,--Gorespine
[1188]=47754,--No-No
[1189]=47742,--Greyhoof
[1190]=42986,--Lucky Yi
[1191]=47743,--Ti'un the Wanderer
[1192]=47744,--Kafi
[1193]=41372,--Dos-Ryga
[1194]=47745,--Nitun
[1195]=44096,--Skitterer Xi'a
[1196]=47747,--Sunfur Panda
[1197]=47749,--Snowy Panda
[1198]=47748,--Mountain Panda
[1201]=48091,--Spawn of G'nathus
[1202]=48001,--Ji-Kun Hatchling
[1204]=47711,--Pierre
[1206]=47959,--Tiny Red Carp
[1207]=47957,--Tiny Blue Carp
[1208]=47958,--Tiny Green Carp
[1209]=47960,--Tiny White Carp
[1211]=48055,--Zandalari Anklerender
[1212]=48056,--Zandalari Footslasher
[1213]=48057,--Zandalari Toenibbler
--5.3
[1200]=48212,--Pygmy Direhorn
[1205]=48213,--Direhorn Runt
[1226]=48878,--Lil' Bad Wolf
[1227]=48857,--Menagerie Custodian
[1228]=48856,--Netherspace Abyssal
[1229]=48662,--Fiendish Imp
[1230]=48855,--Tideskipper
[1231]=48666,--Tainted Waveling
[1232]=48661,--Coilfang Stalker
[1233]=48664,--Pocket Reaver
[1234]=48668,--Lesser Voidcaller
[1235]=48663,--Phoenix Hawk Hatchling
[1236]=48667,--Tito
[1237]=48651,--Gahz'rooki
[1238]=48650,--Unborn Val'kyr
[1243]=48704,--Living Fluid
[1244]=48705,--Viscous Horror
[1245]=48708,--Filthling
[1247]=48877,--Doopy
[1248]=48934,--Blossoming Ancient
--5.4
[1130]=14779,--Crimson
[1131]=42926,--Glowy
[1132]=46863,--Marley
[1133]=40002,--Tiptoe
[1134]=42781,--Sludgy
[1135]=20749,--Dusty
[1136]=44445,--Whispertail
[1137]=1418,--Darnak the Tunneler
[1138]=39741,--Pandaren Water Spirit
[1139]=39747,--Pandaren Fire Spirit
[1140]=41252,--Pandaren Air Spirit
[1141]=40079,--Pandaren Earth Spirit
[1255]=49081,--Murkimus Tyrannicus
[1256]=49084,--Rascal-Bot
[1259]=40338,--Widowling
[1266]=49846,--Xu-Fu, Cub of Xuen
[1267]=49262,--Xu-Fu, Cub of Xuen
[1268]=48211,--Trike
[1269]=49282,--Screamer
[1271]=51712,--Chaos
[1276]=855,--Moon Moon
[1277]=49289,--Lil' B
[1278]=49288,--Au
[1279]=21304,--Banks
[1280]=42430,--Brewly
[1281]=43127,--Chirps
[1282]=49290,--Tonsa
[1283]=43876,--Knowledge
[1284]=45960,--Patience
[1285]=27563,--Wisdom
[1286]=51599,--Summer
[1287]=46947,--Stormoen
[1288]=49299,--Nairn
[1289]=45957,--Monte
[1290]=43350,--Rikki
[1291]=51008,--Socks
[1292]=30414,--Bolo
[1293]=30414,--Li
[1295]=30414,--Yen
[1296]=42162,--Carpe Diem
[1297]=2069,--River
[1298]=45073,--Spirus
[1299]=28456,--Cindy
[1300]=35338,--Dah'da
[1301]=6290,--Alex
[1303]=49835,--Chi-Chi, Hatchling of Chi-Ji
[1304]=49836,--Yu'la, Broodling of Yu'lon
[1305]=49845,--Zao, Calfling of Niuzao
[1311]=50743,--Chi-Chi, Hatchling of Chi-Ji
[1317]=49263,--Yu'la, Broodling of Yu'lon
[1319]=49430,--Zao, Calfling of Niuzao
[1320]=49289,--Lil' Bling
[1321]=51413,--Azure Crane Chick
[1322]=51268,--Blackfuse Bombling
[1323]=40908,--Ashleaf Spriteling
[1324]=51742,--Ashwing Moth
[1325]=51301,--Flamering Moth
[1326]=51740,--Skywisp Moth
[1328]=51271,--Ruby Droplet
[1329]=51408,--Dandelion Frolicker
[1330]=51277,--Death Adder Hatchling
[1331]=51417,--Droplet of Y'Shaarj
[1332]=51267,--Gooey Sha-ling
[1333]=51270,--Jademist Dancer
[1334]=51269,--Kovok
[1335]=51272,--Ominous Flame
[1336]=51279,--Skunky Alemental
[1337]=51278,--Spineclaw Crab
[1338]=47991,--Gulp Froglet
[1339]=51451,--Lil' Oondasta
[1343]=51475,--Bonkers
[1344]=47858,--Vengeful Porcupette
[1345]=51502,--Gu'chi Swarmling
[1346]=47856,--Harmonious Porcupette
[1348]=51504,--Jadefire Spirit
[1349]=51505,--Rotten Little Helper
[1350]=51530,--Sky Lantern
--5.4.1
[1363]=51988,--Alterac Brew-Pup
[1364]=51990,--Murkalot
--5.4.2
[1365]=51994,--Treasure Goblin
--5.4.7
[1386]=53719,--Dread Hatchling
--6.0.1
[1434]=57825,--Sun Sproutling
[1395]=54752,--Lil' Leftovers
[1403]=59021,--Mechanical Axebeak
[1387]=53748,--Iron Starlette
[1411]=53878,--Royal Peacock
[1412]=55679,--Lifelike Mechanical Frostboar
[1416]=58722,--Teroclaw Hatchling
[1428]=57803,--Zomstrok
[1394]=54511,--Weebomination
[1442]=57970,--Ghastly Kid
[1448]=49259,--Sea Calf
[1449]=58395,--Deathwatch Hatchling
[1450]=58547,--Draenei Micro Defender
[1451]=58570,--Molten Corgi
[1467]=58770,--Sky-Bo
[1478]=47931,--Syd the Squid
--[]=59099,--Mystical Spring Bouquet
[1516]=30969,--Bush Chicken
[1521]=58169,--Cursed Birman
[1523]=59330,--Widget the Departed
[1524]=59352,--Netherspawn, Spawn of Netherspawn
[115]=15595,--Land Shark
[1533]=59668,--Lanticore Spawnling
[1541]=60016,--Hydraling
[1603]=61128,--Argi
[1602]=61127,--Grommloc
[1604]=61133,--Unused
[1544]=60441,--Hatespark the Tiny
[1546]=60458,--Stormwing
[1545]=59017,--Firewing
[1432]=57824,--Nightshade Sproutling
[1433]=57820,--Sassy Sproutling
[1431]=57821,--Kelp Sproutling
[1396]=54848,--Crazy Carrot
[1429]=57823,--Autumnal Sproutling
[1430]=57822,--Forest Sproutling
[1563]=6292,--Summon Bronze Whelpling
[1564]=60732,--Dread Dandelion
[1565]=49122,--Mechanical Scorpid
[1495]=60875,--Ore Eater
[1566]=60819,--Everbloom Peachick
[1567]=60820,--Sentinel's Companion
[1384]=53502,--Hogs
[1574]=60876,--Son of Sethe
[1542]=54855,--Frostwolf Pup
[1450]=58547,--Draenei Micro Defender
[1574]=60876,--Son of Sethe
[1458]=58617,--Bone Wasp
[1571]=58768,--Albino River Calf
[1430]=57822,--Forest Sproutling
[1575]=60909,--Sky Fry
[1576]=60930,--Eye of Observation
[1446]=39130,--Meadowstomper Calfling
[1446]=39130,--Meadowstomper Calfling
[1515]=58736,--Stonegrinder
[1531]=59577,--Ancient Nest Guardian
[1530]=59578,--Frostwolf Ghostpup
[1471]=58825,--Fruit Hunter
[1536]=59885,--Zangar Spore
[1538]=61548,--Umbrafen Spore
[1539]=61550,--Seaborne Spore
[1537]=61549,--Crimson Spore
[1540]=61547,--Brilliant Spore
[1426]=58170,--Elekk Plushie
[1511]=28502,--Lovebird Hatchling
[1517]=38473,--Blazing Cindercrawler
[1518]=42430,--Stout Alemental
--6.0.2
[1569]=58534,--Soul of the Forge
[1385]=53610,--Albino Chimaeraling
[1568]=59038,--Puddle Terror
[1570]=60617,--Sunfire Kaliri
[1605]=61148,--Trunks
[1543]=58932,--Pygmy Cow
[1601]=61016,--Servant of Demidos
[1596]=59603,--Veilwatcher Hatchling
[1597]=59034,--Kaliri Hatchling
--6.1
[1632]=61896,--Sunblade Micro-Defender
[1623]=61887,--Leviathan
[1624]=61888,--Abyssius
[1625]=61890,--Fragment of Anger
[1626]=61891,--Fragment of Suffering
[1627]=61889,--Fragment of Desire
[1628]=61892,--Sister of Temptation
[1629]=61894,--Stinkrot
[1631]=40224,--Hyjal Wisp
[1622]=61884,--Grotesque
[1633]=62466,--Chaos Pup
[1634]=61898,--Wretched Servant
--[]=61900,--K'ute
[1636]=62404,--Race MiniZep
[1639]=62354,--Graves
[1600]=60975,--Bone Serpent
[1656]=60609,--Young Talbuk
[1655]=62440,--Slithershock Elver
--6.2
[1672]=64097,--Corrupted Nest Guardian
--[]=63693,--Blorp
[1598]=60972,--Glowing Sporebat
[1588]=60889,--Dusty Sporewing
[1577]=58613,--Bloodthorn Hatchling
[1661]=63447,--Lost Netherpup
[1662]=63446,--Cinder Pup
[1665]=63691,--Ghostshell Crab
[1664]=63584,--Nightmare Bell
[1663]=58760,--Periwinkle Calf
[1687]=64194,--Left Shark
[1688]=64222,--Crusher
[1690]=64425,--Shard of Cyrukh
[1692]=64720,--Savage Cub
[1693]=38310,--Blazing Firehawk
--6.2.2
[1255]=64587,--Summon Zeradar
[1466]=64588,--Summon Brightpaw
[1691]=64585,--Nibbles
[1454]=64589,--Summon Murkidan
[1660]=61986,--Fel Pup
[1764]=65713,--Energized Manafiend
[1766]=65717,--Empowered Manafiend
[1765]=65714,--Empyreal Manafiend
[1725]=65128,--Grumpling
--6.2.3
[1828]=68067,--Baby Winston
--7.0.3
[1805]=23408,--Alarm-o-Bot
[1918]=71002,--Alliance Enthusiast
[1706]=65070,--Ashmaw Cub
[1884]=66485,--Baby Elderhorn
[1934]=72658,--Benax
[1758]=65670,--Black Piglet --! display issue
[1753]=65630,--Bleakwater Jelly
[1777]=65813,--Broot
[1757]=65669,--Brown Piglet --! display issue
[1888]=68858,--Celestial Calf
[1890]=68729,--Corgi Pup
[1929]=68845,--Corgnelius
[1931]=72239,--Court Scribe
[1752]=65590,--Crispin
[1720]=65120,--Emmigosa
[1699]=69490,--Enchanted Cauldron
[1701]=69488,--Enchanted Pen
[1700]=69489,--Enchanted Torch
[1717]=65113,--Extinguished Eye
[1719]=65112,--Eye of Inquisition
[1760]=65672,--Fel Piglet --! display issue
[1889]=68859,--Felbat Pup
[1802]=66155,--Fetid Waveling
[1928]=68860,--Firebat Pup
[1716]=65087,--Fledgling Warden Owl
[1705]=65071,--Grumpy
[1718]=65111,--Hateful Eye
[1919]=71003,--Horde Fanatic
[1926]=71938,--Hungering Claw
[1806]=59042,--Knockoff Blingtron
[1930]=71980,--Lagan
--[]=70125,--Leather Pet Bed
[1808]=66212,--Leyline Broodling
[1922]=71826,--Lurking Owl Kitten
[1932]=72085,--Nightmare Lasher
[1933]=72461,--Nightmare Treant
[1723]=71945,--Nightmare Whelpling
[1715]=65090,--Nightwatch Swooper
[1714]=65091,--Northern Hawk Owl
[1727]=65130,--Nursery Spider
[1935]=72660,--Squirky
[1755]=65638,--Plump Jelly
[1907]=65091,--Pygmy Owl
[1807]=66210,--Red Broodling
[1938]=70663,--Rescued Fawn
[1756]=65667,--Ridgeback Piglet --! display issue
[1804]=66157,--Risen Saber Kitten
[1453]=55291,--River Calf
[1754]=65637,--Sewer-Pipe Jelly
[1711]=62216,--Skyhorn Nestling
[1941]=73093,--Snowfang
[1751]=65527,--Son of Goredome
--[]=58170,--Souvenir Elekk
--[]=59818,--Souvenir Murloc
--[]=72238,--Souvenir Raptor
[1911]=70937,--Sting Ray Pup
[1721]=67250,--Stormborne Whelpling
[1885]=69254,--Sunborne Val'kyr
[1759]=65671,--Thaumaturgical Piglet
[1803]=66147,--Thistleleaf Adventurer
[1722]=65121,--Dream Whelpling
[1920]=71828,--Transmutant
[1886]=68666,--Trigger
[1886]=68666,--Trigger
[1921]=71827,--Untethered Wyrmling
--[]=72900,--Wonderous Wisdomball
[1887]=69532,--Wyrmy Tunkins
[1903]=69896,--Zoom
--[]=44820,--Knight-Captain Murky
--[]=44820,--Legionnaire Murky
--[]=44820,--Mischief
[1809]=66211,--Purple Broodling
[1810]=66213,--Yellow Broodling
--7.1.0
[1977]=70068,--Bloodgazer Hatchling
[1975]=70070,--Direbeak Hatchling
[1976]=70069,--Sharptalon Hatchling
[1974]=70071,--Snowfeather Hatchling
[1984]=74036,--Albino Buzzard
[1960]=73689,--Snaplasher
[1968]=73708,--Wicked Soul
[1967]=73707,--Drudge Ghoul
--[]=73245,--Dutiful Gruntling
--[]=73244,--Dutiful Squire
[1963]=73697,--Boneshard
[1952]=73661,--Dreadmaw
[1958]=29819,--Sanctum Cub
[1949]=73308,--Igneous Flameling
[1956]=26740,--Ironbound Proto-Whelp
[1953]=73663,--Snobold Runt
[1954]=59766,--Nerubian Swarmer
[1943]=28726,--Noblegarden Bunny
[1959]=73684,--Winter Rageling
[1961]=73692,--G0-R41-0N Ultratonk
[1965]=73704,--Blightbreath
[1955]=73671,--Magma Rageling
[1964]=73699,--Blood Boil
[1966]=73706,--Soulbroken Whelpling
[1969]=68857,--Stardust
[1957]=73673,--Runeforged Servitor
[1962]=73694,--Creeping Tentacle
--7.1.5
[2004]=74520,--Trashy
[2017]=74657,--Infinite Hatchling
[2018]=74700,--Paradox Spirit
[2022]=59026,--Tylarr Gronnden
--7.2
[1998]=74468,--Everliving Spore
[2000]=74472,--Young Venomfang
[1999]=74469,--Cavern Moccasin
[1705]=65071,--Grumpy
[2035]=75315,--Bloodbrood Whelpling
[2036]=75316,--Frostbrood Whelpling
[2050]=68861,--Orphaned Felbat
[2047]=75989,--Ban-Fu, Cub of Ban-Lu
[1997]=58823,--Crackers
[2042]=75766,--Scraps
[2049]=76262,--Son of Skum
[2037]=75317,--Vilebrood Whelpling
--7.2.5
[666]=78587,--Micronax
[2041]=75498,--Pocket Cannon
[2064]=78106,--Mining Monkey
[2072]=78261,--Summon Ageless Bronze Drake
[2071]=78222,--Summon Bronze Proto-Whelp
[2057]=76956,--Tricorne
[2063]=1072,--Sneaky Marmot
[2065]=1418,--Dig Rat
[2058]=45555,--Pet Reaper 50
--7.3
[2093]=79712,--Amalgam of Destruction
[2085]=79639,--Drafty
[2087]=45289,--Cinderweb Recluse
[2115]=79777,--Cross Gazer
[2118]=79796,--Docile Skyfin
[2091]=71972,--Corrupted Blood
[2079]=79634,--Discarded Experiment
[2089]=38283,--Infernal Pyreclaw
[2117]=79783,--Fel Lasher
[2119]=79797,--Fel-Afflicted Skyfin
[2113]=78451,--Felclaw Marsuul
[2121]=79798,--Fossorial Bile Larva
[2077]=78989,--Ghost Shark
[2120]=79760,--Grasping Manifestation
[2082]=79637,--Bound Stream
[2001]=74513,--Dibbler
[2002]=74514,--Naxxy
[2081]=79635,--Twilight Clutch-Sister
[2116]=79776,--Orphaned Marsuul
[2090]=65888,--Faceless Mindlasher
[2135]=79888,--Rebellious Imp
[2078]=79630,--Tinytron
[2092]=79711,--Unstable Tendril
[2080]=24751,--Rattlejaw
[2086]=79707,--Blazehound
[2051]=76595,--Twilight
[2083]=79638,--Faceless Minion
--[]=76829,--Uuna
[2088]=79709,--Surger
[2084]=79641,--Zephyrian Prince
--7.3.5
[2158]=82391,--Mailemental
[2062]=77501,--Shadow
[2163]=82688,--Silithid Mini-Tank
--8.0.1
[2403]=78239,--Abyssal Eel
[2420]=80852,--Accursed Hexxer
[2433]=87870,--Aldrusian Sproutling
[2437]=87903,--Ragepeep
[2352]=80456,--Baa'l
[2477]=83653,--Baby Crawg
[2476]=80458,--Slippy
[2456]=88012,--Pet Template
[2425]=75381,--Barnacled Hermit Crab
[2414]=80460,--Bloodfeaster Larva
[2451]=88005,--Bloodstone Tunneler
[2407]=80951,--Bloody Rabbit Fang
[2402]=87760,--Brutus
[2479]=87998,--Bucketshell
[2422]=86529,--Butterfly in a Jar
[2455]=88016,--Pet Template
[2418]=78161,--Child of Jani
[2457]=86463,--Coldlight Surfrunner
[2427]=81099,--Cou'pa
[2448]=88002,--Pet Template
[2424]=81058,--Crimson Frog
[2157]=81984,--Dart
[2464]=88040,--Pet Template
[2144]=80456,--REUSE
[2429]=83052,--Digitized Assistant
[2431]=79567,--Dreadtick Leecher
[2439]=84157,--Drop of Azerite
[2406]=27682,--Drustvar Piglet
[2201]=86482,--Summon Enchanted Tiki Mask
[2165]=75339,--Francois
[2449]=26524,--Pet Template
[2187]=86101,--Summon Filthy Slime
[2429]=83052,--Finicky Gauntlet
[2423]=76624,--Freshwater Pincher
[2432]=87862,--Fuzzy Creepling
[2429]=83052,--Gigan Tarantula
[2466]=88058,--Pet Template
[2409]=80414,--Greatwing Macaw Feather
[2003]=74515,--Hearthy
--[]=,--Hot Air Balloon - Pet (NEEDS NAME)
[2461]=88034,--Pet Template
[2192]=86231,--Summon Vengeful Chicken
[2197]=86484,--Summon Direhorn Hatchling
[2453]=88007,--Juvenile Brineshell
[2447]=88001,--Pet Template
[2454]=88008,--Kunchong Hatchling
[2442]=81972,--Large Honeycomb Cluster
[2468]=88060,--Pet Template
[2416]=83641,--Lil' Ben'fon
[2443]=87976,--Lil' Siege Tower
[2196]=86445,--Summon Lil' Tika
[2444]=87977,--Lil' War Machine
[2471]=88061,--Pet Template
[2430]=83685,--Lost Platysaur
[2441]=16880,--Squawkling
[2429]=83052,--Mechanized Gulper
[2467]=88059,--Pet Template
[2458]=88036,--Muskflank Calfling
[2462]=88017,--Pet Template
[2404]=81966,--Pair of Bee Wings
[2199]=86806,--Summon Restored Revenant
[2438]=74038,--Foulfeather
[2465]=88057,--Pet Template
[2188]=86136,--Summon Poda
[2452]=88003,--Pet Template
[2405]=81079,--Pristine Falcon Feather
[2429]=83052,--Queen Cobra
[2417]=76383,--Ranishu Runt
[2413]=84863,--Raptor Containment Crate
[1699]=69490,--Enchanted Cauldron
[1699]=69490,--Enchanted Cauldron
[2401]=75349,--Rooter
[2463]=88038,--Pet Template
[2426]=80029,--Sandstinger Wasp
[2421]=81219,--Saurolisk Hatchling
[2436]=87895,--Scabby
[2445]=87999,--Pet Template
[2429]=83052,--Shard of Azerite
[2440]=87945,--Fozling
[2478]=87997,--Sir Snips
[2189]=86135,--Summon Smoochums
[2190]=86229,--Summon Guardian Cobra Hatchling
[2472]=81098,--Pet Template
[2459]=88035,--Snort
[2446]=88000,--Pet Template
[2186]=86088,--Summon Spawn of Merektha
[2411]=86805,--Spooky Bundle of Sticks
[2410]=75353,--Strange Looking Mechanical Squirrel
[2473]=88064,--Sunscale Hatchling
[2198]=86488,--Summon Taptaf
[2435]=87890,--Teeny Titan Orb
[2469]=45190,--Pet Template
[2202]=86574,--Summon Mummy
[2450]=88004,--Pet Template
[2412]=84857,--Tiny Direhorn
[2434]=87871,--Voidwiggler
[2419]=76761,--Toad in a Box
[2415]=88468,--Tragg the Curious
[2476]=80458,--Bloodfeaster Larva
[2428]=80467,--Violent Looking Flower Pot
[2460]=88037,--Voru'kar Leecher
[2408]=69092,--Wad of Spider Web
[2474]=78837,--Gearspring Hopper
[2185]=86021,--Cap'n Crackers
--8.1
[2566]=77901,--Albatross Hatchling
[2555]=80967,--Albino Duskwatcher
[2551]=66487,--Baby Stonehide
[2545]=5187,--Gust of Cyclarus
[2547]=23000,--Hydrath Water Droplet
[2568]=36743,--Cobalt Raven
[2562]=88023,--Crimson Octopode
[2544]=90155,--Darkshore Sentinel
[2544]=30298,--Child of Pa'ku
[2527]=90140,--Everburning Treant
[2557]=90181,--Firesting Buzzer
[2552]=90173,--Leatherwing Screecher
[2532]=88785,--Leper Rat
[2558]=90182,--Lord Woofington
[2531]=88790,--Mechanical Cockroach
[2526]=80802,--Feathers
[2530]=90411,--Mechantula
[2534]=31623,--Mini Spider Tank
[2554]=90177,--Needleback Pup
[2563]=90230,--Nightwreathed Watcher
[2567]=80954,--Crimson Bat Pup
[2405]=81079,--Pristine Falcon Feather
[2541]=80413,--Proper Parrot
[2546]=81665,--Detective Ray
[2564]=90279,--Rebuilt Gorilla Bot
[2565]=90412,--Rebuilt Mechanical Spider
[2533]=89767,--Alarm-O-Dog
[2525]=89609,--Redridge Tarantula
[2553]=90176,--Rotting Ghoul
[2560]=90183,--Scritches
[2556]=80966,--Shadefeather Hatchling
[2528]=77989,--Spawn of Krag'wa
[2549]=90141,--Void Jelly
[2540]=90030,--Tanzil
[2529]=89742,--Thunder Lizard Runt
[2561]=90184,--Thunderscale Whelpling
[2559]=76763,--Tonguelasher
[2539]=90029,--Trecker
[2569]=78243,--Violet Abyssal Eel
[2184]=86020,--Summon Whomper
[2535]=86573,--Wicker Wraith
[2538]=90028,--Dasher
[2550]=90142,--Zur'aj the Depleted
--8.1.5
[2589]=42520,--Amber Goo Puddle
[2583]=44445,--Azure Cloud Serpent Egg
[2576]=81097,--Beakbert
[2581]=90830,--Celestial Gift
[2578]=81213,--Enchanted Saurolisk Scale
[2590]=50919,--Essence of Pride
[2591]=90866,--Happiness
--[]=89260,--Horse Balloon
[2585]=45274,--Kor'thik Swarmling
[2582]=47859,--Mogu Statue
--[]=89262,--Murloc Balloon
[2146]=58823,--Perculia's Peculiar Parrot
[2575]=82003,--Sandy Hermit Crab Shell
[2577]=78849,--Slimy Pouch
[2587]=90745,--Spawn of Garalon
[2584]=39739,--Spirit of the Spring
[2579]=40155,--Stoneclaw
[2586]=90867,--Tiny Amber Wings
[2580]=90715,--Wayward Spirit
--[]=89261,--Wolf Balloon
--8.2
[2755]=92073,--Adventurous Hopling
[2697]=90519,--Amethyst Softshell
[2720]=90413,--Arachnoid Skitterbot
[2766]=92502,--Armored Vaultbot
[2719]=81215,--Bonebiter
[2688]=92156,--Brilliant Glimmershell
[2706]=90991,--Brinestone Algan
[2707]=90993,--Budding Algan
[2767]=92580,--Burnout
[2690]=91024,--Caverndark Nightmare
[2691]=91021,--Chitterspine Devourer
[2689]=91027,--Chitterspine Needler
[2750]=10723,--Shrieker
[2708]=80466,--Coral Lashling
[2749]=9758,--Crypt Fiend
[2695]=90944,--Daggertooth Frenzy
[2699]=91111,--Damplight Slug
[2710]=92162,--Drowned Hatchling
[2721]=91656,--Echoing Oozeling
[2638]=92265,--Minimancer
[2754]=6290,--Ghostly Whelpling
[2684]=75367,--Glittering Diamondshell
--[]=88784,--Golden Cricket
[2711]=88764,--Golden Snorf
[2683]=88874,--Kelpfin
[2692]=91028,--Lightless Ambusher
[2715]=74801,--Lost Robogrip
[2687]=90868,--Lustrous Glimmershell
[2756]=80254,--Irradiated Elementaling
[2718]=90874,--Microbot 8D
[2717]=90878,--Microbot XD
[2694]=90513,--Mindlost Bloodfrenzy
[2681]=91235,--Murgle
[2713]=88766,--Mustyfur Snooter
[2696]=88019,--Nameless Octopode
[2682]=86465,--Necrofin Tadpole
[2714]=75332,--OOX-35/MG
[2686]=92157,--Pearlescent Glimmershell
[2698]=90515,--Prismatic Softshell
[2685]=75374,--Sandclaw Nestseeker
[2703]=47252,--Sandkeep
[2704]=92159,--Scalebrood Hydra
[2701]=88619,--Seafury
[2709]=92158,--Skittering Eel
[2762]=91224,--Slimy Darkhunter
[2758]=91249,--Slimy Eel
[2761]=91248,--Slimy Fangtooth
[2763]=91220,--Slimy Hermit Crab
[2760]=91232,--Slimy Octopode
[2757]=91250,--Slimy Otter
[2765]=91219,--Slimy Sea Slug
[2747]=92266,--Gruesome Belcher
[2712]=88761,--Snowsoft Nibbler
[2693]=78240,--Spawn of Nalaada
[2753]=91631,--Spraybot 0D
[2702]=50613,--Stormwrath
[2716]=74800,--Utility Mechanoclaw
[2700]=91114,--Wriggler
[2680]=88873,--Zanj'ir Poker
[2748]=23057,--Ziggy

}

--Item to spell data table--
mp.itemToSpellTable = {
------------------------------------------
--**************************************--
--*************** MOUNTS ***************--
--**************************************--
------------------------------------------
--1.11.1 and earlier
[18796]=23250,--Swift Brown Wolf
[21176]=26656,--Black Qiraji Battle Tank
[12302]=16056,--Ancient Frostsaber
[12303]=16055,--Black Nightsaber
[12330]=16080,--Red Wolf
[12351]=16081,--Winter Wolf
[12353]=16083,--White Stallion
[12354]=16082,--Palomino
[13086]=17229,--Winterspring Frostsaber
[13317]=17450,--Ivory Raptor
[13326]=15779,--White Mechanostrider Mod B
[13327]=17459,--Icy Blue Mechanostrider Mod A
[13328]=17461,--Black Ram
[13329]=17460,--Frost Ram
[13334]=17465,--Green Skeletal Warhorse
[13335]=17481,--Rivendare's Deathcharger
[15292]=18991,--Green Kodo
[15293]=18992,--Teal Kodo
[18766]=23221,--Swift Frostsaber
[18767]=23219,--Swift Mistsaber
[18772]=23225,--Swift Green Mechanostrider
[18773]=23223,--Swift White Mechanostrider
[18774]=23222,--Swift Yellow Mechanostrider
[18776]=23227,--Swift Palomino
[18777]=23229,--Swift Brown Steed
[18778]=23228,--Swift White Steed
[18785]=23240,--Swift White Ram
[18786]=23238,--Swift Brown Ram
[18787]=23239,--Swift Gray Ram
[18788]=23241,--Swift Blue Raptor
[18789]=23242,--Swift Olive Raptor
[18790]=23243,--Swift Orange Raptor
[18791]=23246,--Purple Skeletal Warhorse
[18793]=23247,--Great White Kodo
[18794]=23249,--Great Brown Kodo
[18795]=23248,--Great Gray Kodo
[8586]=16084,--Mottled Red Raptor
[18797]=23251,--Swift Timber Wolf
[18798]=23252,--Swift Gray Wolf
[18902]=23338,--Swift Stormsaber
[19029]=23509,--Frostwolf Howler
[19030]=23510,--Stormpike Battle Charger
[19872]=24242,--Swift Razzashi Raptor
[19902]=24252,--Swift Zulian Tiger
[21218]=25953,--Blue Qiraji Battle Tank
[21321]=26054,--Red Qiraji Battle Tank
[21323]=26056,--Green Qiraji Battle Tank
[21324]=26055,--Yellow Qiraji Battle Tank
[8591]=10796,--Turquoise Raptor
[1132]=580,--Timber Wolf
[2414]=472,--Pinto
[5655]=6648,--Chestnut Mare
[5656]=458,--Brown Horse
[5665]=6653,--Dire Wolf
[5668]=6654,--Brown Wolf
[5864]=6777,--Gray Ram
[5872]=6899,--Brown Ram
[5873]=6898,--White Ram
[8563]=10873,--Red Mechanostrider
[8588]=8395,--Emerald Raptor
[2411]=470,--Black Stallion
[8592]=10799,--Violet Raptor
[8595]=10969,--Blue Mechanostrider
[8629]=10793,--Striped Nightsaber
[8631]=8394,--Striped Frostsaber
[8632]=10789,--Spotted Frostsaber
[13321]=17453,--Green Mechanostrider
[13322]=17454,--Unpainted Mechanostrider
[13331]=17462,--Red Skeletal Horse
[13332]=17463,--Blue Skeletal Horse
[13333]=17464,--Brown Skeletal Horse
[15277]=18989,--Gray Kodo
[15290]=18990,--Brown Kodo
--2.0
[23720]=30174,--Riding Turtle
--2.0.1
[25477]=32246,--Swift Red Wind Rider
[25532]=32296,--Swift Yellow Wind Rider
[25533]=32297,--Swift Purple Wind Rider
[25531]=32295,--Swift Green Wind Rider
[25470]=32235,--Golden Gryphon
[25471]=32239,--Ebon Gryphon
[25472]=32240,--Snowy Gryphon
[25474]=32243,--Tawny Wind Rider
[25475]=32244,--Blue Wind Rider
[25476]=32245,--Green Wind Rider
[28915]=39316,--Dark Riding Talbuk
[28936]=33660,--Swift Pink Hawkstrider
[29102]=34896,--Cobalt War Talbuk
[29103]=34897,--White War Talbuk
[29104]=34898,--Silver War Talbuk
[29105]=34899,--Tan War Talbuk
[29223]=35025,--Swift Green Hawkstrider
[29224]=35027,--Swift Purple Hawkstrider
[29227]=34896,--Cobalt War Talbuk
[29228]=34790,--Dark War Talbuk
[29229]=34898,--Silver War Talbuk
[29230]=34899,--Tan War Talbuk
[29231]=34897,--White War Talbuk
[29465]=22719,--Black Battlestrider
[29466]=22718,--Black War Kodo
[29467]=22720,--Black War Ram
[29468]=22717,--Black War Steed
[29469]=22724,--Black War Wolf
[29470]=22722,--Red Skeletal Warhorse
[29471]=22723,--Black War Tiger
[29472]=22721,--Black War Raptor
[29745]=35713,--Great Blue Elekk
[29746]=35712,--Great Green Elekk
[29747]=35714,--Great Purple Elekk
[30480]=36702,--Fiery Warhorse
[31829]=39315,--Cobalt Riding Talbuk
[31830]=39315,--Cobalt Riding Talbuk
[31831]=39317,--Silver Riding Talbuk
[31832]=39317,--Silver Riding Talbuk
[31833]=39318,--Tan Riding Talbuk
[31834]=39318,--Tan Riding Talbuk
[31835]=39319,--White Riding Talbuk
[31836]=39319,--White Riding Talbuk
[28481]=34406,--Brown Elekk
[28927]=34795,--Red Hawkstrider
[29220]=35020,--Blue Hawkstrider
[29221]=35022,--Black Hawkstrider
[29222]=35018,--Purple Hawkstrider
[29743]=35711,--Purple Elekk
[29744]=35710,--Gray Elekk
--2.1
[32319]=39803,--Blue Riding Nether Ray
[25473]=32242,--Swift Blue Gryphon
[25528]=32290,--Swift Green Gryphon
[25529]=32292,--Swift Purple Gryphon
[32314]=39798,--Green Riding Nether Ray
[32316]=39801,--Purple Riding Nether Ray
[32317]=39800,--Red Riding Nether Ray
[32318]=39802,--Silver Riding Nether Ray
[25527]=32289,--Swift Red Gryphon
[32857]=41513,--Onyx Netherwing Drake
[32858]=41514,--Azure Netherwing Drake
[32859]=41515,--Cobalt Netherwing Drake
[32860]=41516,--Purple Netherwing Drake
[32861]=41517,--Veridian Netherwing Drake
[32862]=41518,--Violet Netherwing Drake
[32768]=41252,--Raven Lord
--2.1.1
[32458]=40192,--Ashes of Al'ar
--2.1.2
[30609]=37015,--Swift Nether Drake
--2.2
[33977]=43900,--Swift Brewfest Ram
[33976]=43899,--Brewfest Ram
--2.2.2
[33182]=42668,--Swift Flying Broom
[33184]=42668,--Swift Magic Broom
[33176]=42667,--Flying Broom
--2.3
[25596]=32345,--Peep the Phoenix Mount
[33809]=43688,--Amani War Bear
[33999]=43927,--Cenarion War Hippogryph
[34061]=44151,--Turbo-Charged Flying Machine
[34092]=44744,--Merciless Nether Drake
[34060]=44153,--Flying Machine
[34129]=35028,--Swift Warstrider
--2.4
[35513]=46628,--Swift White Hawkstrider
[35906]=48027,--Black War Elekk
--2.4.2
[37676]=49193,--Vengeful Nether Drake
--2.4.3
[43516]=58615,--Brutal Nether Drake
[37719]=49322,--Swift Zhevra
[37828]=49379,--Great Brewfest Kodo
[37012]=48025,--Headless Horseman's Mount
[43599]=58983,--Big Blizzard Bear
[37011]=47977,--Magic Broom
[37750]=66052,--Fresh Brewfest Hops
[39476]=66051,--Fresh Goblin Brewfest Hops
--3.0.1
[41508]=55531,--Mechano-Hog
[44502]=55531,--Mechano-Hog(Recipe)
[40775]=54729,--Winged Steed of the Ebon Blade
--3.0.2
[44413]=60424,--Mekgineer's Chopper
[44503]=60424,--Mekgineer's Chopper(Recipe)
[44221]=64749,--Loaned Gryphon Reins
[44229]=64762,--Loaned Wind Rider Reins
[44168]=60002,--Time-Lost Proto-Drake
[43952]=59567,--Azure Drake
[43954]=59571,--Twilight Drake
[43955]=59570,--Red Drake
[43951]=59569,--Bronze Drake
[44151]=59996,--Blue Proto-Drake
[43953]=59568,--Blue Drake
[44178]=60025,--Albino Drake
[44558]=61309,--Magnificent Flying Carpet
[44689]=61229,--Armored Snowy Gryphon
[44690]=61230,--Armored Blue Wind Rider
[43986]=59650,--Black Drake
[44554]=61451,--Flying Carpet
[44223]=60118,--Black War Bear
[43956]=59785,--Black War Mammoth
[43961]=61470,--Grand Ice Mammoth
[43962]=54753,--White Polar Bear
[44077]=59788,--Black War Mammoth
[44080]=59797,--Ice Mammoth
[44086]=61469,--Grand Ice Mammoth
[43958]=59799,--Ice Mammoth
[44224]=60119,--Black War Bear
[44225]=60114,--Armored Brown Bear
[44226]=60116,--Armored Brown Bear
[44230]=59791,--Wooly Mammoth
[44231]=59793,--Wooly Mammoth
[44234]=61447,--Traveler's Tundra Mammoth
[44235]=61425,--Traveler's Tundra Mammoth
--3.0.3
[44160]=59961,--Red Proto-Drake
[44707]=61294,--Green Proto-Drake
[43959]=61465,--Grand Black War Mammoth
--3.0.8
[44175]=60021,--Plagued Proto-Drake
--3.0.9
[44164]=59976,--Black Proto-Drake
[44083]=61467,--Grand Black War Mammoth
--3.1
[46109]=64731,--Sea Turtle
[44843]=61996,--Blue Dragonhawk
[45693]=63796,--Mimiron's Head
[45725]=63844,--Argent Hippogryph
[44842]=61997,--Red Dragonhawk
[45125]=63232,--Stormwind Steed
[45586]=63636,--Ironforge Ram
[45589]=63638,--Gnomeregan Mechanostrider
[45590]=63639,--Exodar Elekk
[45591]=63637,--Darnassian Nightsaber
[45592]=63641,--Thunder Bluff Kodo
[45593]=63635,--Darkspear Raptor
[45595]=63640,--Orgrimmar Wolf
[45596]=63642,--Silvermoon Hawkstrider
[45597]=63643,--Forsaken Warhorse
[46101]=64656,--Blue Skeletal Warhorse
[46099]=64658,--Black Wolf
[46100]=64657,--White Kodo
[46308]=64977,--Black Skeletal Horse
--3.1.1
[46171]=65439,--Furious Gladiator's Frost Wyrm
--3.1.2
[45802]=63963,--Rusted Proto-Drake
[46752]=65640,--Swift Gray Steed
[46744]=65638,--Swift Moonsaber
[46745]=65637,--Great Red Elekk
[46746]=65645,--White Skeletal Warhorse
[46743]=65644,--Swift Purple Raptor
[46748]=65643,--Swift Violet Ram
[46749]=65646,--Swift Burgundy Wolf
[46750]=65641,--Great Golden Kodo
[46751]=65639,--Swift Red Hawkstrider
[46747]=65642,--Turbostrider
--3.1.3
[45801]=63956,--Ironbound Proto-Drake
--3.2
[44177]=60024,--Violet Proto-Drake
[46813]=66087,--Silver Covenant Hippogryph
[46814]=66088,--Sunreaver Dragonhawk
[49286]=46199,--X-51 Nether-Rocket X-TREME
[46708]=64927,--Deadly Gladiator's Frost Wyrm
[49285]=46197,--X-51 Nether-Rocket
[46102]=64659,--Venomhide Ravasaur
[46815]=66090,--Quel'dorei Steed
[46816]=66091,--Sunreaver Hawkstrider
[47101]=66846,--Ochre Skeletal Warhorse
[47179]=66906,--Argent Charger
[47180]=67466,--Argent Warhorse
[49044]=68057,--Swift Alliance Steed
[49096]=68187,--Crusader's White Warhorse
[49098]=68188,--Crusader's Black Warhorse
[49282]=51412,--Big Battle Bear
[49284]=42777,--Swift Spectral Tiger
[49290]=65917,--Magic Rooster
[47100]=66847,--Striped Dawnsaber
[49283]=42776,--Spectral Tiger
--3.2.2
[49636]=69395,--Onyxian Drake
[49046]=68056,--Swift Horde Wolf
[49288]=68769,--Little Ivory Raptor Whistle
[49289]=68768,--Little White Stallion Bridle
--3.3
[50818]=72286,--Invincible
[50818]=72286,--Invincible(Recipe)
--3.3.2
[51954]=72808,--Bloodbathed Frostbrood Vanquisher
[50250]=71342,--Big Love Rocket
--3.3.3
[47840]=67336,--Relentless Gladiator's Frost Wyrm
[51955]=72807,--Icebound Frostbrood Vanquisher
[54797]=75596,--Frosty Flying Carpet
[54798]=75596,--Frosty Flying Carpet(Recipe)
[54069]=74856,--Blazing Hippogryph
[54860]=75973,--X-53 Touring Rocket
[52200]=73313,--Crimson Deathcharger
[54811]=75614,--Celestial Steed
--3.3.5
[54068]=74918,--Wooly White Rhino
--4.0.1
[65891]=93326,--Sandstone Drake
[67538]=93326,--Sandstone Drake(Recipe)
[63043]=88746,--Vitreous Stone Drake
[62900]=88331,--Volcanic Stone Drake
[62901]=88335,--Drake of the East Wind
[63039]=88741,--Drake of the West Wind
[63040]=88742,--Drake of the North Wind
[63041]=88744,--Drake of the South Wind
[63042]=88718,--Phosphorescent Stone Drake
[50435]=71810,--Wrathful Gladiator's Frost Wyrm
[63125]=88990,--Dark Phoenix
[64998]=92231,--Spectral Steed
[64999]=92232,--Spectral Wolf
[65356]=88741,--Drake of the West Wind
[63044]=88748,--Brown Riding Camel
[63045]=88749,--Tan Riding Camel
[63046]=88750,--Grey Riding Camel
[64883]=92155,--Ultramarine Qiraji Battle Tank
--4.0.3
[67151]=98718,--Subdued Seahorse
[54465]=75207,--Abyssal Seahorse
[68008]=93623,--Mottled Drake
[60954]=84751,--Fossilized Raptor
[62462]=87091,--Goblin Turbo-Trike
[62298]=90621,--Golden King
[67107]=93644,--Kor'kron Annihilator
[62461]=87090,--Goblin Trike
--4.1
[69747]=98204,--Amani Battle Bear
[69213]=97359,--Flameward Hippogryph
[69224]=97493,--Pureblood Fire Hawk
[68825]=96503,--Amani Dragonhawk
[68823]=96491,--Armored Razzashi Raptor
[68824]=96499,--Swift Zulian Panther
[69228]=97581,--Savage Raptor
[69846]=98727,--Winged Guardian
[69846]=98727,--Winged Guardian(Recipe)
--4.2
[69230]=97560,--Corrupted Fire Hawk
[71339]=101282,--Vicious Gladiator's Twilight Drake
[70909]=100332,--Vicious War Steed
[70910]=100333,--Vicious War Wolf
[71665]=101542,--Flametalon of Alysrazor
--4.3
[77067]=107842,--Blazing Drake
[77069]=107845,--Life-Binder's Handmaiden
[78919]=110039,--Experiment 12-B
[77068]=107844,--Twilight Harbinger
[71954]=101821,--Ruthless Gladiator's Twilight Drake
[74269]=74856,--Blazing Hippogryph
[76889]=107516,--Spectral Gryphon
[76902]=107517,--Spectral Wind Rider
[73839]=103196,--Swift Mountain Horse
[71718]=101573,--Swift Shorestrider
[72140]=102346,--Swift Forest Strider
[72145]=102349,--Swift Springstrider
[72146]=102350,--Swift Lovebird
[72575]=102488,--White Riding Camel
[73766]=103081,--Darkmoon Dancing Bear
[76755]=107203,--Tyrael's Charger
[78924]=110051,--Heart of the Aspects
[73838]=103195,--Mountain Horse
[72582]=102514,--Corrupted Hippogryph
--4.3.2
[79771]=113120,--Feldrake
--5.0.1
[83088]=121837,--Jade Panther
[83845]=121837,--Jade Panther(Recipe)
[79802]=113199,--Jade Cloud Serpent
[82453]=120043,--Jeweled Onyx Panther
[83877]=120043,--Jeweled Onyx Panther(Recipe)
[84101]=122708,--Grand Expedition Yak
[85429]=123993,--Golden Cloud Serpent
[85430]=123992,--Azure Cloud Serpent
[87768]=127154,--Onyx Cloud Serpent
[87769]=127156,--Crimson Cloud Serpent
[87771]=127158,--Heavenly Onyx Cloud Serpent
[87773]=127161,--Heavenly Crimson Cloud Serpent
[87774]=127164,--Heavenly Golden Cloud Serpent
[87777]=127170,--Astral Cloud Serpent
[87781]=127174,--Azure Riding Crane
[87782]=127176,--Golden Riding Crane
[87783]=127177,--Regal Riding Crane
[87788]=127216,--Grey Riding Yak
[87789]=127220,--Blonde Riding Yak
[89154]=129552,--Crimson Pandaren Phoenix
[89304]=129918,--Thundering August Cloud Serpent
[89305]=129932,--Green Shado-Pan Riding Tiger
[89306]=129935,--Red Shado-Pan Riding Tiger
[89307]=129934,--Blue Shado-Pan Riding Tiger
[89362]=130086,--Brown Riding Goat
[89390]=130137,--White Riding Goat
[89391]=130138,--Black Riding Goat
[89783]=130965,--Son of Galleon
[83087]=121838,--Ruby Panther
[83931]=121838,--Ruby Panther(Recipe)
[81354]=118089,--Azure Water Strider
[83089]=121839,--Sunstone Panther
[83830]=121839,--Sunstone Panther(Recipe)
[83090]=121836,--Sapphire Panther
[83932]=121836,--Sapphire Panther(Recipe)
[81559]=118737,--Pandaren Kite
[85666]=124408,--Thundering Jade Cloud Serpent
[89785]=130985,--Pandaren Kite
[85262]=123886,--Amber Scorpion
[83086]=121820,--Obsidian Nightwing
[87250]=126507,--Depleted-Kyparium Rocket
[87251]=126508,--Geosynchronous World Spinner
[89363]=130092,--Red Flying Cloud
[82811]=120822,--Great Red Dragon Turtle
[87801]=127293,--Great Green Dragon Turtle
[87802]=127295,--Great Black Dragon Turtle
[87803]=127302,--Great Blue Dragon Turtle
[87804]=127308,--Great Brown Dragon Turtle
[87805]=127310,--Great Purple Dragon Turtle
[85870]=124659,--Imperial Quilen
[82765]=120395,--Green Dragon Turtle
[87795]=127286,--Black Dragon Turtle
[87796]=127287,--Blue Dragon Turtle
[87797]=127288,--Brown Dragon Turtle
[87799]=127289,--Purple Dragon Turtle
[87800]=127290,--Red Dragon Turtle
[89682]=130678,--Oddly-Shaped Horn
[89697]=130730,--Bag of Kafa Beans
[89770]=130895,--Tuft of Yak Fur
--5.0.4
[90655]=132036,--Thundering Ruby Cloud Serpent
[90711]=132118,--Emerald Pandaren Phoenix
[90712]=132119,--Violet Pandaren Phoenix
[90710]=132117,--Ashen Pandaren Phoenix
[91010]=120822,--Great Red Dragon Turtle
[91011]=127295,--Great Black Dragon Turtle
[91012]=127293,--Great Green Dragon Turtle
[91013]=127302,--Great Blue Dragon Turtle
[91014]=127308,--Great Brown Dragon Turtle
[91015]=127310,--Great Purple Dragon Turtle
[91004]=120395,--Green Dragon Turtle
[91005]=127288,--Brown Dragon Turtle
[91006]=127289,--Purple Dragon Turtle
[91007]=127290,--Red Dragon Turtle
[91008]=127286,--Black Dragon Turtle
[91009]=127287,--Blue Dragon Turtle
--5.0.5
[85785]=124550,--Cataclysmic Gladiator's Twilight Drake
--5.1
[93168]=135416,--Grand Armored Gryphon
[93169]=135418,--Grand Armored Wyvern
[93385]=136163,--Grand Gryphon
[93386]=136164,--Grand Wyvern
[91802]=133023,--Jade Pandaren Kite
[92724]=134573,--Swift Windsteed
--5.2
[93666]=136471,--Spawn of Horridon
[95057]=139442,--Thundering Cobalt Cloud Serpent
[95059]=139448,--Clutch of Ji-Kun
[95564]=140249,--Golden Primal Direhorn
[95565]=140250,--Crimson Primal Direhorn
[95041]=139407,--Malevolent Gladiator's Cloud Serpent
[95416]=134359,--Sky Golem
[93662]=136400,--Armored Skyscreamer
[93671]=136505,--Ghastly Charger
[94228]=138423,--Cobalt Primordial Direhorn
[94229]=138425,--Slate Primordial Direhorn
[94230]=138424,--Amber Primordial Direhorn
[94231]=138426,--Jade Primordial Direhorn
[94290]=138640,--Bone-White Primal Raptor
[94291]=138641,--Red Primal Raptor
[94292]=138642,--Black Primal Raptor
[94293]=138643,--Green Primal Raptor
[95341]=139595,--Armored Bloodwing
--5.3
[98405]=142641,--Brawler's Burly Mushan Beast
[98104]=142266,--Armored Red Dragonhawk
[98259]=142478,--Armored Blue Dragonhawk
[97989]=142878,--Enchanted Fey Dragon
[98618]=142073,--Hearthsteed
--5.4
[104327]=148620,--Prideful Gladiator's Cloud Serpent
[103638]=148428,--Ashhide Mushan Beast
[104246]=148396,--Kor'kron War Wolf
[104253]=148417,--Kor'kron Juggernaut
[104269]=148476,--Thundering Onyx Cloud Serpent
[104325]=148618,--Tyrannical Gladiator's Cloud Serpent
[104326]=148619,--Grievous Gladiator's Cloud Serpent
[104208]=148392,--Spawn of Galakras
[102514]=146615,--Vicious Warsaber
[102533]=146622,--Vicious Skeletal Warhorse
[103630]=30174,--Riding Turtle
[104011]=147595,--Stormcrow
[101675]=145133,--Shimmering Moonstone
[104329]=148626,--Ash-Covered Horn
[104346]=148773,--Golden Glider
--5.4.1
[106246]=149801,--Emerald Hippogryph
--5.4.2
[107951]=153489,--Iron Skyreaver
--5.4.7
[109013]=155741,--Armored Dread Raven
--5.4.8
[112326]=163024,--Warforged Nightmare
[112327]=163025,--Grinning Reaver
--6.0.1
[108883]=171844,--Dustmane Direwolf
[116350]=171844,--Dustmane Direwolf(Recipe)
[116383]=171436,--Gorestrider Gronnling
[116785]=171842,--Swift Frostwolf
[113543]=174004,--Spirit of Shinri
[115363]=169952,--Creeping Carpet
[114866]=169952,--Creeping Carpet(Recipe)
[118676]=175700,--Emerald Drake
[115484]=170347,--Core Hound
[118515]=171847,--Cindermane Charger
[119179]=176762,--Iron Star Roller
[119180]=176759,--Goren "Log" Roller
--6.0.2
[116771]=171828,--Solar Spirehawk
[116791]=171848,--Challenger's War Yeti
[116660]=171621,--Ironhoof Destroyer
[116661]=171622,--Mottled Meadowstomper
[116674]=171636,--Great Greytusk
[116767]=171824,--Sapphire Riverbeast
[116773]=171830,--Swift Breezestrider
[116777]=171834,--Vicious War Ram
[116778]=171835,--Vicious War Raptor
[116788]=171845,--Warlord's Deathwheel
[116789]=171846,--Champion's Treadblade
[116792]=171849,--Sunhide Gronnling
[116794]=171851,--Garn Nighthowl
[116655]=171616,--Witherhide Cliffstomper
[116656]=171617,--Trained Icehoof
[116657]=171618,--Ancient Leatherhide
[116658]=171619,--Tundra Icehoof
[116662]=171623,--Trained Meadowstomper
[116663]=171624,--Shadowhide Pearltusk
[116664]=171625,--Dusty Rockhide
[116665]=171626,--Armored Irontusk
[116666]=171627,--Blacksteel Battleboar
[116659]=171620,--Bloodhoof Bull
[116668]=171629,--Armored Frostboar
[116669]=171630,--Armored Razorback
[116670]=171632,--Frostplains Battleboar
[116671]=171633,--Wild Goretusk
[116672]=171634,--Domesticated Razorback
[116673]=171635,--Giant Coldsnout
[116675]=171637,--Trained Rocktusk
[116676]=171638,--Trained Riverwallow
[116768]=171825,--Mosshide Riverwallow
[116769]=171826,--Mudback Riverbeast
[116772]=171829,--Shadowmane Charger
[116774]=171831,--Trained Silverpelt
[116775]=171832,--Breezestrider Stallion
[116776]=171833,--Pale Thorngrazer
[116779]=171836,--Garn Steelmaw
[116780]=171837,--Warsong Direfang
[116781]=171838,--Armored Frostwolf
[116782]=171839,--Ironside Warwolf
[116784]=171841,--Trained Snarler
[116786]=171843,--Smoky Direwolf
[116667]=171628,--Rocktusk Battleboar
--6.1
[120968]=179245,--Chauffeured Chopper (Alliance)
[122703]=179244,--Chauffeured Chopper (Horde)
[121815]=179478,--Voidtalon of the Dark Star
[122469]=180545,--Mystic Runesaber
--6.2
[123890]=182912,--Felsteel Annihilator
[128277]=186828,--Primal Gladiator's Felblood Gronnling
[128281]=189043,--Wild Gladiator's Felblood Gronnling
[128282]=189044,--Warmongering Gladiator's Felblood Gronnling
[123974]=183117,--Corrupted Dreadwing
[124089]=183889,--Vicious War Mechanostrider
[124540]=185052,--Vicious War Kodo
[127140]=186305,--Infernal Direwolf
[128311]=189364,--Coalfist Gronnling
[128480]=190690,--Bristling Hellboar(Horde)
[128481]=190690,--Bristling Hellboar(Alliance)
[128526]=190977,--Deathtusk Felboar(Horde)
[128527]=190977,--Deathtusk Felboar(Alliance)
[128706]=191633,--Soaring Skyterror
--6.2.2
[129922]=142910,--Ironbound Wraithcharger
[129923]=194464,--Eclipse Dragonhawk
[128671]=191314,--Minion of Grumpus
[128422]=189999,--Grove Warden
[128425]=189998,--Illidari Felstalker
--6.2.3
[133543]=201098,--Infinite Timereaver
--7.0.3
[140228]=222202,--Prestigious Bronze Courser
[140232]=222237,--Prestigious Forest Courser
[140233]=222238,--Prestigious Ivory Courser
[140407]=222241,--Prestigious Midnight Courser
[140408]=222240,--Prestigious Azure Courser
[140230]=222236,--Prestigious Royal Courser
[131734]=196681,--Spirit of Eche'ro
[137570]=213115,--Bloodfang Widow
[137574]=213134,--Felblaze Infernal
[137575]=171827,--Hellfire Infernal
[137576]=171840,--Coldflame Infernal
[137577]=213158,--Predatory Bloodgazer
[137578]=213163,--Snowfeather Hunter
[137579]=213164,--Brilliant Direbeak
[137580]=213165,--Viridian Sharptalon
[137614]=213350,--Frostshard Infernal
[137615]=213349,--Flarecore Infernal
[137686]=213209,--Steelbound Devourer
[137687]=213209,--Steelbound Devourer(Recipe)
[138201]=223018,--Fathom Dweller
[138258]=215159,--Long-Forgotten Hippogryph
[138387]=215558,--Ratstallion
[141216]=193007,--Grove Defiler
[141217]=225765,--Leyfeather Hippogryph
[141843]=227986,--Vindictive Gladiator's Storm Dragon
[141844]=227988,--Fearless Gladiator's Storm Dragon
[141845]=227989,--Cruel Gladiator's Storm Dragon
[141846]=227991,--Ferocious Gladiator's Storm Dragon
[141847]=227994,--Fierce Gladiator's Storm Dragon
[141848]=227995,--Demonic Gladiator's Storm Dragon
[129962]=213339,--Great Northern Elderhorn
[141850]=213339,--Great Northern Elderhorn(Recipe)
[137573]=171850,--Llothien Prowler
[138811]=214791,--Brinedeep Bottom-Feeder
[129280]=193695,--Prestigious War Steed
[140348]=223363,--Vicious Warstrider
[140350]=223578,--Vicious War Elekk
[140353]=223341,--Vicious Gilnean Warhorse
[140354]=223354,--Vicious War Trike
[141713]=227956,--Arcadian War Turtle
[129744]=142910,--Ironbound Wraithcharger
[140500]=223814,--Mechanized Lumber Extractor
--7.1.0
[142436]=230987,--Arcanist's Manasaber
[142398]=228919,--Darkwater Skate
[142369]=230401,--White Hawkstrider
[142236]=229499,--Midnight
[143864]=204166,--Prestigious War Wolf
[142403]=230844,--Rockspine Basilisk
[142552]=231428,--Smoldering Ember Wyrm
--7.2
[143643]=232519,--Abyss Worm
[142225]=229385,--Ban-Lu, Grandmaster's Companion
[143490]=231525,--Shadowblade's Crimson Omen
[147806]=242881,--Cloudwing Hippogryph
[142231]=229387,--Deathlord's Vilebrood Vanquisher
[143502]=231435,--Highlord's Golden Charger
[143503]=231587,--Highlord's Vengeful Charger
[143637]=238452,--Netherlord's Brimstone Wrathsteed
[143505]=231589,--Highlord's Valorous Charger
[147807]=242874,--Highmountain Elderhorn
[142232]=229388,--Battlelord's Bloodthirsty War Wyrm
[143764]=233364,--Leywoven Flying Carpet
[143491]=231524,--Shadowblade's Baneful Omen
[143492]=231523,--Shadowblade's Lethal Omen
[143638]=231437,--Archdruid's Lunarwing Form
[143631]=232405,--Primal Flamesaber
[143489]=231442,--Farseer's Raging Tempest
[143493]=231434,--Shadowblade's Murderous Omen
[147835]=243025,--Riddler's Mind-Worm
[142233]=238454,--Netherlord's Accursed Wrathsteed
[143752]=230844,--Brawler's Burly Basilisk
[143504]=231588,--Highlord's Vigilant Charger
[142228]=229439,--Huntmaster's Dire Wolfhawk
[142226]=229438,--Huntmaster's Fierce Wolfhawk
[142227]=229386,--Huntmaster's Loyal Wolfhawk
[147805]=242882,--Valarjar Stormwing
[142234]=229487,--Vicious War Bear
[142235]=229486,--Vicious War Bear
[142237]=229512,--Vicious War Lion
[142437]=230988,--Vicious War Scorpion
[143648]=232523,--Vicious War Turtle
[143649]=232525,--Vicious War Turtle
[147804]=242875,--Wild Dreamrunner
--7.3
[152904]=253662,--Acid Belcher
[152816]=253088,--Antoran Charhound
[152815]=253087,--Antoran Gloomhound
[153044]=254259,--Avenging Felcrusher
[152903]=253660,--Biletooth Gnasher
[153041]=254260,--Bleakhoof Ruinstrider
[153043]=254258,--Blessed Felcrusher
[152905]=253661,--Crimson Slavermaw
[153485]=247448,--Darkmoon Dirigible
[152843]=235764,--Darkspore Mana Ray
[152841]=253108,--Felglow Mana Ray
[153042]=254069,--Glorious Felcrusher
[152901]=253639,--Violet Spellwing
[152844]=253107,--Lambent Mana Ray
[152788]=239013,--Lightforged Warframe
[151623]=247402,--Lucid Nightmare
[147901]=243512,--Luminous Starseeker
[152814]=253058,--Maddened Chaosrunner
[152912]=253711,--Pond Nettle
[152794]=253004,--Amethyst Ruinstrider
[152795]=253005,--Beryl Ruinstrider
[152797]=253007,--Cerulean Ruinstrider
[152793]=253006,--Russet Ruinstrider
[152791]=242305,--Sable Ruinstrider
[152796]=253008,--Umber Ruinstrider
[152840]=253109,--Scintillating Mana Ray
[152789]=243651,--Shackled Ur'zul
[152842]=253106,--Vibrant Mana Ray
[152869]=242897,--Vicious War Fox
[152870]=242896,--Vicious War Fox
[152790]=243652,--Vile Fiend
--7.3.5
[153493]=243201,--Demonic Gladiator's Storm Dragon
[155656]=258022,--Lightforged Felcrusher
[155662]=258060,--Highmountain Thunderhoof
[156486]=259202,--Starcursed Voidstrider
[156487]=258845,--Nightborne Manasaber
[151625]=239767,--Ruby Qiraji Resonating Crystal
[151626]=239766,--Sapphire Qiraji Resonating Crystal
--8.0.1
[156884]=262027,--Black Gladiator's Proto-Drake
[163216]=250735,--Bloodgorged Crawg
[156880]=262023,--Blue Gladiator's Proto-Drake
[163578]=279457,--Broken Highland Mustang
[163576]=237286,--Dune Scavenger
[163574]=260174,--Terrified Pack Mule
[163577]=279454,--Conquerer's Scythemaw
[163583]=279467,--Craghorn Chasm-Leaper
[161331]=271646,--Dark Iron Core Hound
[156879]=262022,--Dread Gladiator's Proto-Drake
[163981]=280729,--Frenzied Feltalon
[156885]=262028,--Gold Gladiator's Proto-Drake
[163573]=260175,--Goldenmane
[163131]=278803,--Great Sea Ray
[156883]=262026,--Green Gladiator's Proto-Drake
[163579]=279456,--Highland Mustang
[159146]=267270,--Kua'fon
[163646]=279608,--Lil' Donkey
[161330]=267274,--Mag'har Direwolf
[161134]=261437,--Mecha-Mogul Mk2
[161135]=261437,--Mecha-Mogul Mk2(Recipe)
[159921]=266058,--Tomb Stalker
[161479]=275623,--Nazjatar Blood Serpent
[156882]=262025,--Pale Gladiator's Proto-Drake
[164250]=281044,--Prestigious Bloodforged Courser
[163982]=280730,--Pureheart Courser
[156881]=262024,--Purple Gladiator's Proto-Drake
[163582]=279469,--Qinsho's Eternal Hound
[163575]=243795,--Leaping Veinseeker
[161911]=259213,--Admiralty Stallion
[161773]=237287,--Alabaster Hyena
[161667]=275840,--Armored Albino Pterrordax
[161664]=244712,--Armored Ebony Pterrordax
[161666]=275838,--Armored Orange Pterrordax
[161665]=275837,--Cobalt Pterrordax
[161912]=260172,--Dapple Gray
[161908]=275859,--Dusky Waycrest Gryphon
[161774]=275841,--Expedition Bloodswarmer
[163042]=264058,--Mighty Caravan Brutosaur
[161215]=239049,--Obsidian Krolusk
[163589]=279474,--Palehide Direhorn
[161879]=275868,--Proudmoore Sea Scout
[161910]=260173,--Smoky Charger
[163063]=278656,--Spectral Phoenix
[161909]=275866,--Stormsong Coastwatcher
[159842]=254813,--Summon Sharkbait
[156564]=259395,--Shu-Zen, the Divine Sentinel
[163645]=279611,--Skullripper
[163127]=274610,--Teldrassil Hippogryph
[163183]=259740,--Spawn of Krag'wa
[163586]=254811,--Squawks
[163585]=278979,--Surf Jelly
[163644]=279569,--Swift Albino Raptor
[163186]=278966,--Tempestuous Skystallion
[156798]=261395,--The Hivemind
[163584]=279466,--Twilight Avenger
[160829]=273541,--Underrot Crawg
[163121]=261434,--Vicious War Basilisk
[163122]=261433,--Vicious War Basilisk
[163124]=270560,--Vicious War Clefthoof
[163123]=272481,--Vicious War Riverbeast
[163128]=272472,--Undercity Plaguebat
[163706]=279868,--Witherbark Direwing
[153594]=256123,--Xiwyllag ATV
[157870]=263707,--Zandalari Direhorn
[158922]=266229,--Zany Zombified Raptor
[160589]=272770,--The Dreadwake
--8.1
[166432]=288495,--Ashenvale Chimaera
[166465]=288736,--Azureshell Krolusk
[166428]=288438,--Blackpaw
[166774]=290134,--Hogrus, Swine of Good Fortune
[166468]=288720,--Bloodgorged Hunter
[166469]=288714,--Bloodthirsty Dreadwing
[166442]=288587,--Blue Marsh Hopper
[166438]=288438,--Blackpaw
[166437]=288505,--Kaldorei Nightsaber
[166434]=288503,--Umber Nightsaber
[166539]=289101,--Dazar'alor Windreaver
[166433]=288499,--Frightened Kodo
[166518]=289083,--G.M.O.D.
[166705]=289555,--Glacial Tidestorm
[166467]=288721,--Island Thunderscale
[166435]=288505,--Kaldorei Nightsaber
[164571]=281554,--Meat Wagon
[166463]=288740,--Priestess' Moonsaber
[166417]=237288,--Reins of the Onyx War Hyena
[166466]=288722,--Risen Mare
[166464]=288735,--Rubyshell Krolusk
[166471]=288711,--Saltwater Seahorse
[166436]=288506,--Sandy Nightsaber
[166745]=266925,--Siltwing Albatross
[166470]=288712,--Stonehide Elderhorn
[166803]=288503,--Umber Nightsaber
[165020]=281890,--Vicious Black Bonesteed
[165019]=281887,--Vicious Black Warsaber
[166775]=290133,--Vulpine Familiar
[166443]=288589,--Yellow Marsh Hopper
--8.1.5
[167894]=294568,--Beastlord's Irontusk
[167895]=294569,--Beastlord's Warwolf
[168055]=295387,--Bloodflank Charger
[166724]=289639,--Bruce
[168056]=295386,--Ironclad Frostclaw
[164762]=282682,--Kul Tiran Charger
--8.2
[168830]=290718,--Aerial Unit R-21\/X
[170178]=304696,--Alpha Fin
[167167]=292407,--Ankoan Waveray
[167171]=292419,--Azshari Bloatray
[168408]=297560,--Child of Torcali
[169202]=300153,--Crimson Tidestallion
[169200]=300147,--Deepcoral Snapdragon
[169201]=300150,--Fabious
[169203]=300151,--Inkscale Deepseeker
[168329]=296788,--Mechacycle Model W
[168826]=299158,--Mechagon Peacekeeper
[167751]=294143,--X-995 Mechanocat
[169198]=294038,--Royal Snapdragon
[168829]=299170,--Rustbolt Resistor
[168370]=297157,--Junkheap Drifter
[168823]=291492,--Rusty Mechanocrawler
[168827]=299159,--Scrapforged Mechaspider
[169163]=300149,--Silent Glider
[169194]=294039,--Snapback Scuttler
[169199]=300146,--Snapdragon Kelpstalker
[166776]=290132,--Sylverian Dreamer
[167170]=291538,--Unshackled Waveray
[169162]=290328,--Wonderwing 2.0

------------------------------------------
--**************************************--
--************* COMPANIONS *************--
--**************************************--
------------------------------------------
--1.11.1 and earlier
[12264]=15999,--Worg Pup
[21277]=26010,--Tranquil Mechanical Yeti
[12529]=16450,--Smolderweb Hatchling
[20769]=25162,--Disgusting Oozeling
[15996]=19772,--Lifelike Toad
[16044]=19772,--Lifelike Toad(Recipe)
[11474]=15067,--Sprite Darter Hatchling
[11825]=15048,--Pet Bombling
[11828]=15048,--Pet Bombling(Recipe)
[11826]=15049,--Lil' Smoky
[11827]=15049,--Lil' Smoky(Recipe)
[10398]=12243,--Mechanical Chicken
[11026]=10704,--Tree Frog
[11027]=10703,--Wood Frog
[19450]=23811,--Jubling
[19462]=23851,--Unhatched Jubling Egg
[11023]=10685,--Ancona Chicken
[8499]=10697,--Crimson Whelpling
[8500]=10707,--Great Horned Owl
[8501]=10706,--Hawk Owl
[10360]=10714,--Black Kingsnake
[10361]=10716,--Brown Snake
[10392]=10717,--Crimson Snake
[10393]=10688,--Undercity Cockroach
[10394]=10709,--Brown Prairie Dog
[10822]=10695,--Dark Whelpling
[8498]=10698,--Emerald Whelpling
[8494]=10682,--Hyacinth Macaw
[13582]=17709,--Zergling
[13583]=17707,--Panda Cub
[13584]=17708,--Mini Diablo
[20371]=24696,--Murky
[8485]=10673,--Bombay Cat
[8486]=10674,--Cornish Rex Cat
[8487]=10676,--Orange Tabby Cat
[8488]=10678,--Silver Tabby Cat
[8489]=10679,--White Kitten
[8490]=10677,--Siamese Cat
[8491]=10675,--Black Tabby Cat
[8492]=10683,--Green Wing Macaw
[8495]=10684,--Senegal
[8496]=10680,--Cockatiel
[8497]=10711,--Snowshoe Rabbit
[4401]=4055,--Mechanical Squirrel
[4408]=4055,--Mechanical Squirrel(Recipe)
[23015]=28740,--Whiskers the Rat
[11110]=13548,--Westfall Chicken
[21301]=26533,--Father Winter's Helper
[21305]=26541,--Winter's Little Helper
[21308]=26529,--Winter Reindeer
[23083]=28871,--Spirit of Summer
[22200]=27662,--Silver Shafted Arrow
[22235]=27570,--Peddlefeet
[23002]=28738,--Speedy
[23007]=28739,--Mr. Wiggles
[21309]=26045,--Tiny Snowman
--1.12.1
[18964]=23429,--Loggerhead Snapjaw
[19054]=23530,--Tiny Red Dragon
[19055]=23531,--Tiny Green Dragon
--2.0
[23713]=30156,--Hippogryph Hatchling
--2.0.1
[31760]=39181,--Miniwing
[29363]=35156,--Mana Wyrmling
[29364]=35239,--Brown Rabbit
[29902]=35909,--Red Moth
[29958]=36031,--Blue Dragonhawk Hatchling
[27445]=33050,--Magical Crawdad
[29901]=35907,--Blue Moth
[29903]=35910,--Yellow Moth
[29904]=35911,--White Moth
[29953]=36027,--Golden Dragonhawk Hatchling
[29956]=36028,--Red Dragonhawk Hatchling
[29957]=36029,--Silver Dragonhawk Hatchling
[32588]=40549,--Bananas
--2.0.3
[23712]=30152,--White Tiger Cub
--2.1
[22114]=27241,--Gurky
[25535]=32298,--Netherwhelp
[32616]=40614,--Egbert
[32617]=40613,--Willy
[32622]=40634,--Peanut
[29960]=36034,--Firefly
[30360]=24988,--Lurky
--2.2.2
[32233]=39709,--Wolpertinger
[33154]=42609,--Sinister Squashling
--2.3
[34478]=45082,--Tiny Sporebat
[34535]=10696,--Azure Whelpling
[33993]=43918,--Mojo
[34493]=45127,--Dragon Kite
[34425]=54187,--Clockwork Rocket Bot
[34492]=45125,--Rocket Chicken
--2.4
[35504]=46599,--Phoenix Hatchling
[33816]=43697,--Toothy
[33818]=43698,--Muckbreath
[35349]=46425,--Snarly
[35350]=46426,--Chuck
--2.4.2
[38628]=51716,--Nether Ray Fry
[34955]=45890,--Searing Scorchling
[38050]=49964,--Ethereal Soul-Trader
[39656]=53082,--Mini Tyrael
[32498]=40405,--Lucky
--2.4.3
[37297]=48406,--Spirit of Competition
--[37710]=49352,--Crashin' Thrashin' Racer
--3.0.1
[21168]=25849,--Baby Shark
[40653]=40990,--Stinker
--3.0.2
[38658]=51851,--Vampiric Batling
[39973]=53316,--Ghostly Skull
[43698]=59250,--Giant Sewer Rat
[44723]=61357,--Pengu
[39896]=61348,--Tickbird Hatchling
[39899]=61349,--White Tickbird Hatchling
[44721]=61350,--Proto-Drake Whelp
[44481]=60832,--Grindgear Toy Gorilla
[44482]=60838,--Trusty Copper Racer
--3.0.3
[39286]=52615,--Frosty
[44738]=61472,--Kirin Tor Familiar
[39898]=61351,--Cobra Hatchling
[44819]=61855,--Baby Blizzard Bear
--3.0.8
[44841]=61991,--Little Fawn
--3.1
[44822]=10713,--Albino Snake
[45942]=64351,--XS-001 Constructor Bot
[44794]=61725,--Spring Rabbit
[44965]=62491,--Teldrassil Sproutling
[44970]=62508,--Dun Morogh Cub
[44971]=62510,--Tirisfal Batling
[44973]=62513,--Durotar Scorpion
[44974]=62516,--Elwynn Lamb
[44980]=62542,--Mulgore Hatchling
[44983]=62561,--Strand Crawler
[44984]=62562,--Ammen Vale Lashling
[44998]=62609,--Argent Squire
[45002]=62674,--Mechanopeep
[45022]=62746,--Argent Gruntling
[45057]=62949,--Wind-Up Train Wrecker
[45606]=63712,--Sen'jin Fetish
[44982]=62564,--Enchanted Broom
[44601]=61022,--Heavy Copper Racer
[44599]=61021,--Zippy Copper Racer
[45047]=62857,--Sandbox Tiger
--3.1.2
[45180]=63318,--Murkimus the Gladiator
--3.1.3
[46767]=65682,--Warbot
--3.2
[48112]=67413,--Darting Hatchling
[48116]=67415,--Gundrak Hatchling
[48118]=67416,--Leaping Hatchling
[48120]=67417,--Obsidian Hatchling
[48122]=67418,--Ravasaur Hatchling
[48124]=67419,--Razormaw Hatchling
[48126]=67420,--Razzashi Hatchling
[48114]=67414,--Deviate Hatchling
[46707]=44369,--Pint-Sized Pink Pachyderm
[46802]=66030,--Grunty
[46544]=65382,--Curious Wolvar Pup
[46545]=65381,--Curious Oracle Hatchling
[46820]=66096,--Shimmering Wyrmling
[46821]=66096,--Shimmering Wyrmling
[46396]=65353,--Wolvar Orphan Whistle
[46397]=65352,--Oracle Orphan Whistle
--3.2.2
[49362]=69002,--Onyxian Whelpling
[41133]=55068,--Mr. Chilly
[44810]=61773,--Plump Turkey
[49665]=69541,--Pandaren Monk
[49693]=69677,--Lil' K.T.
[46831]=66175,--Macabre Marionette
[49287]=68767,--Tuskarr Kite
[49343]=68810,--Spectral Tiger Cub
--3.3
[46398]=65358,--Calico Cat
[49646]=69452,--Core Hound Pup
[49912]=70613,--Perky Pug
[34518]=45174,--Golden Pig
[34519]=45175,--Silver Pig
[37298]=48408,--Essence of Competition
[22781]=28505,--Poley
[45047]=62857,--Sandbox Tiger
--3.3.2
[49662]=69535,--Gryphon Hatchling
[49663]=69536,--Wind Rider Cub
[50446]=71840,--Toxic Wasteling
--3.3.3
[53641]=74932,--Frigid Frostling
[54847]=75906,--Lil' XT
[54436]=75134,--Blue Clockwork Rocket Bot
--[54343]=75111,--Blue Crashin' Thrashin' Racer 
--3.3.5
[56806]=78381,--Mini Thor
--4.0.1
[63138]=89039,--Dark Phoenix Hatchling
[64403]=90637,--Fox Kit
[63398]=89670,--Armadillo Pup
[63355]=89472,--Rustberg Seagull
[64996]=89472,--Rustberg Seagull
[67128]=93624,--Landro's Lil' XT
[67418]=94070,--Deathy
[66076]=93739,--Mr. Grubbs
[65362]=92396,--Guild Page
[65363]=92397,--Guild Herald
[65364]=92398,--Guild Herald
[65661]=78683,--Blue Mini Jouster
[65662]=78685,--Gold Mini Jouster
[65361]=92395,--Guild Page
--4.0.3
[60955]=84752,--Fossilized Hatchling
[46892]=63318,--Murkimus the Gladiator
[49664]=69539,--Zipao Tiger
[62540]=87344,--Lil' Deathwing
[62769]=87863,--Eat the Egg
[48527]=67527,--Onyx Panther
[68385]=95787,--Lil' Ragnaros
[68618]=95786,--Moonkin Hatchling
[68619]=95909,--Moonkin Hatchling
[60847]=84263,--Crawling Claw
[66080]=93813,--Tiny Flamefly
[59597]=81937,--Personal World Destroyer
[60216]=82173,--De-Weaponized Mechanical Companion
[64372]=90523,--Clockwork Gnome
[67274]=93836,--Enchanted Lantern
[67308]=93836,--Enchanted Lantern(Recipe)
[67275]=93837,--Magic Lamp
[67312]=93837,--Magic Lamp(Recipe)
[67282]=93838,--Elementium Geode
[46325]=65046,--Withers
[60869]=84492,--Pebble
[64494]=91343,--Tiny Shale Spider
[66067]=93823,--Singing Sunflower
[66073]=93817,--Scooter the Snail
[54810]=75613,--Celestial Dragon
[46709]=65451,--MiniZep Controller
--4.0.6
[68673]=16450,--Smolderweb Hatchling
--4.1
[69991]=45082,--Tiny Sporebat
[69824]=98587,--Voodoo Figurine
[69821]=98571,--Pterrordax Hatchling
[68840]=96817,--Landro's Lichling
[68841]=96819,--Nightsaber Cub
[69648]=98079,--Legs
[69847]=98736,--Guardian Cub
[70099]=99578,--Cenarion Hatchling
[68833]=96571,--Panther Cub
[69239]=97638,--Winterspring Cub
[69992]=66096,--Shimmering Wyrmling
[69251]=97779,--Lashtail Hatchling
--4.2
[71033]=100576,--Lil' Tarecgosa
[72068]=98736,--Guardian Cub
[70908]=100330,--Feline Familiar
[71076]=100684,--Creepy Crate
[71726]=101606,--Murkablo
[70140]=99663,--Hyjal Bear Cub
[72045]=101989,--Horde Balloon
[71137]=100959,--Brewfest Keg Pony
[71140]=100970,--Nuts
[71387]=101424,--Brilliant Kaliri
[72042]=101986,--Alliance Balloon
[70160]=99668,--Crimson Lasher
--4.3
[73953]=103588,--Sea Pony
[71624]=101493,--Purple Puffer
[72153]=102353,--Sand Scarab
[73762]=103076,--Darkmoon Balloon
[73764]=101733,--Darkmoon Monkey
[73765]=103074,--Darkmoon Turtle
[73797]=103125,--Lumpy
[73903]=103544,--Darkmoon Tonk
[73905]=103549,--Darkmoon Zeppelin
[72134]=102317,--Gregarious Grell
[74981]=105122,--Darkmoon Cub
[76062]=105633,--Fetish Shaman
[78916]=110029,--Soul of the Aspects
[75040]=140218,--Flimsy Darkmoon Balloon
[75041]=105228,--Flimsy Green Balloon
[75042]=105229,--Flimsy Yellow Balloon
[74610]=104047,--Lunar Lantern
[74611]=104049,--Festival Lantern
[77158]=107926,--Darkmoon "Tiger"
--4.3.2
[79744]=112994,--Eye of the Legion
--5.0.1
[85513]=127813,--Thundering Serpent Hatchling
[87526]=126885,--Mechanical Pandaren Dragonling
[80008]=114090,--Darkmoon Rabbit
[85220]=123778,--Terrible Turnip
[85222]=123784,--Red Cricket
[85447]=124000,--Tiny Goldfish
[85578]=124152,--Feral Vermling
[85871]=124660,--Lucky Quilen Cub
[89587]=118414,--Porcupette
[89686]=130726,--Jade Tentacle
[89736]=130759,--Venus
[87567]=127006,--Food
[87568]=127008,--Food
[88148]=127816,--Jade Crane Chick
[82774]=120501,--Jade Owl
[90470]=120501,--Jade Owl(Recipe)
[82775]=120507,--Sapphire Cub
[90471]=120507,--Sapphire Cub(Recipe)
[86562]=126247,--Hopling
[86563]=126249,--Aqua Strider
[86564]=126251,--Grinder
[88147]=127815,--Singing Cricket
[84105]=122748,--Fishy
[89367]=127006,--Yu'lon Kite
[89368]=127008,--Chi-Ji Kite
[74622]=110955,--Fire Spirit
[89640]=130649,--Life Spirit
[89641]=130650,--Water Spirit
--5.0.4
[90897]=90637,--Fox Kit
[90898]=90637,--Fox Kit
[90173]=131590,--Pandaren Water Spirit
[90177]=131650,--Baneling
[90953]=132759,--Spectral Cub
[90953]=132759,--Spectral Cub
[90953]=132759,--Spectral Cub
--5.1
[90900]=132574,--Imperial Moth
[91040]=132789,--Darkmoon Eye
[92707]=134538,--Cinder Kitten
[92798]=134892,--Pandaren Fire Spirit
[92799]=134894,--Pandaren Air Spirit
[92800]=134895,--Pandaren Earth Spirit
[93031]=135256,--Mr. Bigglesworth
[90902]=132580,--Imperial Silkworm
[91031]=132785,--Darkmoon Glowfly
[91003]=132762,--Darkmoon Hatchling
[93029]=135257,--Stitched Pup
[93025]=135156,--Clock'em
[93032]=135255,--Fungal Abomination
[93033]=135258,--Harbinger of Flame
[93034]=135259,--Corefire Imp
[93035]=135261,--Ashstone Core
[93036]=135263,--Untamed Hatchling
[93037]=135265,--Death Talon Whelpguard
[93038]=135264,--Chrominius
[93039]=135266,--Viscidus Globule
[93040]=135267,--Anubisath Idol
[93041]=135268,--Mini Mindslayer
[93030]=135254,--Giant Bone Spider
[92959]=135009,--Darkmoon "Cougar"
[92968]=135025,--Darkmoon "Murloc"
[92969]=135026,--Darkmoon "Rocket"
[92956]=135007,--Darkmoon "Snow Leopard"
[92970]=135027,--Darkmoon "Wyvern"
[92966]=135022,--Darkmoon "Dragon"
[92958]=135008,--Darkmoon "Nightsaber"
[92967]=135023,--Darkmoon "Gryphon"
--5.2
[95422]=139932,--Zandalari Anklerender
[93669]=136484,--Gusting Grimoire
[94124]=138082,--Sunreaver Micro-Sentry
[94125]=137977,--Living Sandling
[94126]=138087,--Zandalari Kneebiter
[94152]=138161,--Son of Animus
[94190]=138285,--Spectral Porcupette
[94208]=138380,--Sunfur Panda
[94209]=138381,--Snowy Panda
[94210]=138382,--Mountain Panda
[94595]=138913,--Spawn of G'nathus
[94835]=139148,--Ji-Kun Hatchling
[94025]=137568,--Red Panda
[95423]=139933,--Zandalari Footslasher
[95424]=139934,--Zandalari Toenibbler
[95621]=65682,--Warbot
[94191]=138287,--Stunted Direhorn
[94573]=139153,--Direhorn Runt
[94574]=138825,--Pygmy Direhorn
[94903]=138824,--Pierre
[94932]=139361,--Tiny Red Carp
[94933]=139362,--Tiny Blue Carp
[94934]=139363,--Tiny Green Carp
[94935]=139365,--Tiny White Carp
--5.3
[98550]=142880,--Blossoming Ancient
[100870]=143637,--Murkimus Tyrannicus
[97821]=141789,--Gahz'rooki
[97548]=141433,--Lil' Bad Wolf
[97549]=141434,--Menagerie Custodian
[97550]=141435,--Netherspace Abyssal
[97551]=141451,--Fiendish Imp
[97552]=141436,--Tideskipper
[97961]=142030,--Filthling
[97554]=141446,--Coilfang Stalker
[97555]=141447,--Pocket Reaver
[97556]=141448,--Lesser Voidcaller
[97557]=141449,--Phoenix Hawk Hatchling
[97558]=141450,--Tito
[97959]=142028,--Living Fluid
[97960]=142029,--Viscous Horror
[97553]=141437,--Tainted Waveling
--5.4
[101570]=144761,--Moon Moon
[104317]=148567,--Rotten Little Helper
[100905]=143703,--Rascal-Bot
[101771]=145696,--Xu-Fu, Cub of Xuen
[102145]=145697,--Chi-Chi, Hatchling of Chi-Ji
[102146]=145699,--Zao, Calfling of Niuzao
[102147]=145698,--Yu'la, Broodling of Yu'lon
[103637]=148427,--Vengeful Porcupette
[103670]=147124,--Lil' Bling
[104156]=148046,--Ashleaft Spriteling
[104157]=148047,--Azure Crane Chick
[104158]=148049,--Blackfuse Bombling
[104159]=148050,--Ruby Droplet
[104160]=148051,--Dandelion Frolicker
[104162]=148058,--Droplet of Y'Shaarj
[104163]=148059,--Gooey Sha-ling
[104164]=148060,--Jademist Dancer
[104165]=148061,--Kovok
[104166]=148062,--Ominous Flame
[104167]=148063,--Skunky Alemental
[104168]=148066,--Spineclaw Crab
[104169]=148067,--Gulp Froglet
[104202]=148373,--Bonkers
[104291]=148527,--Gu'chi Swarmling
[104295]=148530,--Harmonious Porcupette
[104307]=148552,--Jadefire Spirit
[104332]=148684,--Sky Lantern
[104333]=148684,--Flimsy Sky Lantern
[104161]=148052,--Death Adder Hatchling
--5.4.1
[106240]=149787,--Alterac Brew-Pup
[106244]=149792,--Murkalot
--5.4.2
[106256]=149810,--Treasure Goblin
[108438]=154165,--Moonkin Hatchling
--[104318]=148577,--Crashin' Thrashin' Flyer
--5.4.7
[109014]=155748,--Dread Hatchling
--6.0.1
[118598]=167397,--Sun Sproutling
[110684]=159296,--Lil' Leftovers
[111402]=160403,--Mechanical Axebeak
[118484]=160403,--Mechanical Axebeak(Recipe)
[111660]=155838,--Iron Starlette
[111866]=161643,--Royal Peacock
[112057]=162135,--Lifelike Mechanical Frostboar
[118485]=162135,--Lifelike Mechanical Frostboar(Recipe)
[112699]=164212,--Teroclaw Hatchling
[113554]=167336,--Zomstrok
[113558]=158261,--Weebomination
[113623]=167731,--Ghastly Kid
[114919]=168977,--Sea Calf
[114968]=169220,--Deathwatch Hatchling
[115282]=169666,--Draenei Micro Defender
[115301]=169695,--Molten Corgi
[115483]=170292,--Sky-Bo
[116064]=170774,--Syd the Squid
[116258]=171222,--Mystical Spring Bouquet
[116403]=171500,--Bush Chicken
[116801]=171912,--Cursed Birman
[116804]=171915,--Widget the Departed
[116815]=170269,--Netherspawn, Spawn of Netherspawn
[117404]=172695,--Land Shark
[117528]=172998,--Lanticore Spawnling
[118207]=170273,--Hydraling
[118516]=177232,--Argi
[118517]=177234,--Grommloc
[118518]=177220,--Unused
[118574]=170268,--Hatespark the Tiny
[118577]=170289,--Stormwing
[118578]=170291,--Firewing
[118595]=167394,--Nightshade Sproutling
[118596]=167395,--Sassy Sproutling
[118597]=167392,--Kelp Sproutling
[110721]=159581,--Crazy Carrot
[118599]=167389,--Autumnal Sproutling
[118600]=167390,--Forest Sproutling
[118675]=10699,--Summon Bronze Whelpling
[118709]=170272,--Dread Dandelion
[118741]=170288,--Mechanical Scorpid
[119177]=170288,--Mechanical Scorpid(Recipe)
[118919]=170280,--Ore Eater
[118921]=176137,--Everbloom Peachick
[118923]=176140,--Sentinel's Companion
[119048]=170267,--Hogs
[119112]=170277,--Son of Sethe
[119141]=170281,--Frostwolf Pup
[119142]=169666,--Draenei Micro Defender
[119143]=170277,--Son of Sethe
[119146]=170286,--Bone Wasp
[119148]=170287,--Albino River Calf
[119149]=167390,--Forest Sproutling
[119150]=170271,--Sky Fry
[119170]=170275,--Eye of Observation
[114834]=168668,--Meadowstomper Calfling
[115469]=168668,--Meadowstomper Calfling
[116402]=170282,--Stonegrinder
[117354]=172632,--Ancient Nest Guardian
[117380]=170274,--Frostwolf Ghostpup
[117564]=170285,--Fruit Hunter
[118101]=173532,--Zangar Spore
[118104]=173543,--Umbrafen Spore
[118105]=173544,--Seaborne Spore
[118106]=173542,--Crimson Spore
[118107]=173547,--Brilliant Spore
[113216]=166071,--Elekk Plushie
[114865]=166071,--Elekk Plushie(Recipe)
[116155]=171118,--Lovebird Hatchling
[116439]=171552,--Blazing Cindercrawler
[116756]=171758,--Stout Alemental
--6.0.2
[119328]=170276,--Soul of the Forge
[119329]=170276,--Soul of the Forge(Recipe)
[119434]=177212,--Albino Chimaeraling
[119467]=170279,--Puddle Terror
[119468]=177227,--Sunfire Kaliri
[120121]=177233,--Trunks
[120309]=177216,--Pygmy Cow
[119431]=170278,--Servant of Demidos
[120050]=170283,--Veilwatcher Hatchling
[120051]=177215,--Kaliri Hatchling
--6.1
[122113]=179838,--Sunblade Micro-Defender
[122104]=179830,--Leviathan
[122106]=179831,--Abyssius
[122107]=179832,--Fragment of Anger
[122108]=179833,--Fragment of Suffering
[122109]=179834,--Fragment of Desire
[122110]=179835,--Sister of Temptation
[122111]=179836,--Stinkrot
[122112]=179837,--Hyjal Wisp
[122105]=179811,--Grotesque
[122114]=179839,--Chaos Pup
[122115]=179840,--Wretched Servant
[122116]=179841,--K'ute
[122125]=179954,--Race MiniZep
[122532]=177238,--Bone Serpent
[122533]=177218,--Young Talbuk
[122534]=177223,--Slithershock Elver
--6.2
[127749]=187532,--Corrupted Nest Guardian
[126925]=185601,--Blorp
[127701]=187376,--Glowing Sporebat
[127703]=187383,--Dusty Sporewing
[127704]=187384,--Bloodthorn Hatchling
[127705]=184481,--Lost Netherpup
[127748]=184482,--Cinder Pup
[126926]=185591,--Ghostshell Crab
[127753]=185055,--Nightmare Bell
[127754]=187555,--Periwinkle Calf
[127856]=188084,--Left Shark
[127868]=188235,--Crusher
[128309]=189357,--Shard of Cyrukh
[128477]=190682,--Savage Cub
[128478]=190681,--Blazing Firehawk
--6.2.2
[128423]=143637,--Summon Zeradar
[128424]=190035,--Summon Brightpaw
[128426]=190020,--Nibbles
[128427]=190036,--Summon Murkidan
[129205]=184480,--Fel Pup
[129216]=193572,--Energized Manafiend
[129217]=193588,--Empowered Manafiend
[129218]=193589,--Empyreal Manafiend
[128770]=191967,--Grumpling
--6.2.3
[134047]=204148,--Baby Winston
--7.0.3
[136910]=210682,--Alarm-o-Bot
[139775]=221684,--Alliance Enthusiast
[128690]=191425,--Ashmaw Cub
[136919]=210694,--Baby Elderhorn
[140934]=225200,--Benax
[136907]=210680,--Black Piglet
[129188]=193434,--Bleakwater Jelly
[129362]=193943,--Broot
[136906]=210679,--Brown Piglet
[136923]=210698,--Celestial Calf
[136925]=210701,--Corgi Pup
[140320]=223359,--Corgnelius
[140672]=224403,--Court Scribe
[129175]=193368,--Crispin
[129178]=193388,--Emmigosa
[128533]=191071,--Enchanted Cauldron
[128621]=191071,--Enchanted Cauldron(Recipe)
[128535]=191073,--Enchanted Pen
[128623]=191073,--Enchanted Pen(Recipe)
[128534]=191072,--Enchanted Torch
[128622]=191072,--Enchanted Torch(Recipe)
[136899]=210671,--Extinguished Eye
[136901]=210673,--Eye of Inquisition
[129760]=194294,--Fel Piglet
[136924]=210699,--Felbat Pup
[130168]=195368,--Fetid Waveling
[140316]=223339,--Firebat Pup
[129961]=213325,--Flaming Hoop
[137932]=213325,--Flaming Hoop(Recipe)
[136898]=210669,--Fledgling Warden Owl
[128354]=186299,--Grumpy
[136900]=210672,--Hateful Eye
[139776]=221683,--Horde Fanatic
[140261]=223027,--Hungering Claw
[136911]=210683,--Knockoff Blingtron
[140323]=223409,--Lagan
[129960]=213337,--Leather Pet Bed
[137933]=213337,--Leather Pet Bed(Recipe)
[129958]=213314,--Leather Pet Leash
[137934]=213314,--Leather Pet Leash(Recipe)
[136914]=210691,--Leyline Broodling
[139791]=221908,--Lurking Owl Kitten
[140741]=224536,--Nightmare Lasher
[140761]=224786,--Nightmare Treant
[136903]=210675,--Nightmare Whelpling
[129878]=194393,--Nightwatch Swooper
[136897]=210665,--Northern Hawk Owl
[129826]=194357,--Nursery Spider
[141316]=225663,--Squirky
[129798]=194330,--Plump Jelly
[130154]=215560,--Pygmy Owl
[136913]=210690,--Red Broodling
[141352]=226813,--Rescued Fawn
[136905]=210678,--Ridgeback Piglet
[130166]=195370,--Risen Saber Kitten
[140274]=223110,--River Calf
[136904]=210677,--Sewer-Pipe Jelly
[129277]=193680,--Skyhorn Nestling
[141530]=227093,--Snowfang
[129108]=193279,--Son of Goredome
[140670]=224397,--Souvenir Elekk
[141205]=225688,--Souvenir Murloc
[140671]=224401,--Souvenir Raptor
[138810]=217218,--Sting Ray Pup
[129208]=193514,--Stormborne Whelpling
[136920]=210695,--Sunborne Val'kyr
[136908]=210681,--Thaumaturgical Piglet
[130167]=195369,--Thistleleaf Adventurer
[136902]=210674,--Dream Whelpling
[139789]=221906,--Transmutant
[132519]=210696,--Trigger
[136921]=210696,--Trigger
[139790]=221907,--Untethered Wyrmling
[141348]=226682,--Wonderous Wisdomball
[136922]=210697,--Wyrmy Tunkins
[137298]=212749,--Zoom
--7.1.0
[142448]=231017,--Albino Buzzard
[142091]=229098,--Snaplasher
[142099]=229106,--Wicked Soul
[142098]=229105,--Drudge Ghoul
[142380]=230444,--Dutiful Gruntling
[142379]=230443,--Dutiful Squire
[142094]=229101,--Boneshard
[142083]=229090,--Dreadmaw
[142089]=229096,--Sanctum Cub
[141714]=227964,--Igneous Flameling
[142087]=229094,--Ironbound Proto-Whelp
[142084]=229091,--Snobold Runt
[142085]=229092,--Nerubian Swarmer
[141532]=227113,--Noblegarden Bunny
[142090]=229097,--Winter Rageling
[142092]=229099,--G0-R41-0N Ultratonk
[142096]=229103,--Blightbreath
[142086]=229093,--Magma Rageling
[142095]=229102,--Blood Boil
[142097]=229104,--Soulbroken Whelpling
[142100]=229110,--Stardust
[142088]=229095,--Runeforged Servitor
[142093]=229100,--Creeping Tentacle
--7.1.5
[143842]=233805,--Trashy
[143953]=234555,--Infinite Hatchling
[143954]=234556,--Paradox Spirit
[144394]=236285,--Tylarr Gronnden
--7.2
[143756]=233331,--Everliving Spore
[143755]=233335,--Young Venomfang
[143754]=233333,--Cavern Moccasin
[146417]=186299,--Grumpy
[147539]=237250,--Bloodbrood Whelpling
[147540]=237251,--Frostbrood Whelpling
[147841]=243136,--Orphaned Felbat
[147542]=240794,--Ban-Fu, Cub of Ban-Lu
[143679]=232867,--Crackers
[146953]=240064,--Scraps
[147543]=242047,--Son of Skum
[147541]=237252,--Vilebrood Whelpling
--7.2.5
[101426]=249870,--Micronax
[150739]=244345,--Pocket Cannon
[151632]=247452,--Mining Monkey
[151828]=248240,--Summon Ageless Bronze Drake
[151829]=248025,--Summon Bronze Proto-Whelp
[150741]=244440,--Tricorne
[151569]=247123,--Sneaky Marmot
[151633]=247474,--Dig Rat
[150742]=244466,--Pet Reaper 50
--7.3
[152963]=253929,--Amalgam of Destruction
[152974]=253818,--Drafty
[152976]=253918,--Cinderweb Recluse
[153026]=254196,--Cross Gazer
[153054]=254295,--Docile Skyfin
[152980]=253927,--Corrupted Blood
[152967]=253790,--Discarded Experiment
[152978]=253925,--Infernal Pyreclaw
[153045]=254271,--Fel Lasher
[153055]=254296,--Fel-Afflicted Skyfin
[153040]=254255,--Felclaw Marsuul
[153057]=254298,--Fossorial Bile Larva
[152555]=251191,--Ghost Shark
[153056]=254297,--Grasping Manifestation
[152970]=253809,--Bound Stream
[151645]=233647,--Dibbler
[151269]=233649,--Naxxy
[152969]=253805,--Twilight Clutch-Sister
[153027]=254197,--Orphaned Marsuul
[152979]=253926,--Faceless Mindlasher
[153252]=254749,--Rebellious Imp
[152966]=253788,--Tinytron
[152981]=253928,--Unstable Tendril
[152968]=253799,--Rattlejaw
[152975]=253916,--Blazehound
[147900]=243499,--Twilight
[152972]=253813,--Faceless Minion
[153195]=254763,--Uuna
[152977]=253924,--Surger
[152973]=253816,--Zephyrian Prince
--7.3.5
[156721]=260887,--Mailemental
[156851]=261755,--Silithid Mini-Tank
--8.0.1
[163650]=279638,--Aldrusian Sproutling
[163689]=279723,--Ragepeep
[162578]=277461,--Baa'l
[163859]=279435,--Baby Crawg
[163858]=280619,--Slippy
[163799]=177242,--Pet Template
[163818]=280332,--Bloodstone Tunneler
[163974]=280727,--Bucketshell
[163798]=177243,--Pet Template
[163823]=280337,--Coldlight Surfrunner
[163805]=177235,--Pet Template
[156566]=259758,--Dart
[163809]=177228,--Pet Template
[162686]=256010,--REUSE
[152878]=274760,--Summon Enchanted Tiki Mask
[158077]=264001,--Francois
[163806]=177231,--Pet Template
[160704]=273184,--Summon Filthy Slime
[163648]=279631,--Fuzzy Creepling
[163811]=177225,--Pet Template
[163802]=177239,--Pet Template
[160940]=273869,--Summon Vengeful Chicken
[161080]=274348,--Summon Direhorn Hatchling
[163821]=280335,--Juvenile Brineshell
[163804]=177236,--Pet Template
[163822]=280336,--Kunchong Hatchling
[163812]=177224,--Pet Template
[163778]=280185,--Lil' Siege Tower
[161016]=274202,--Summon Lil' Tika
[163779]=280188,--Lil' War Machine
[163815]=177219,--Pet Template
[163568]=279433,--Lost Platysaur
[163712]=279930,--Squawkling
[163814]=177221,--Pet Template
[163820]=280334,--Muskflank Calfling
[163801]=177240,--Pet Template
[161089]=274380,--Summon Restored Revenant
[163690]=279724,--Foulfeather
[163813]=177222,--Pet Template
[158464]=273195,--Summon Poda
[163800]=177241,--Pet Template
[152880]=191071,--Enchanted Cauldron
[152879]=191071,--Enchanted Cauldron
[163808]=177229,--Pet Template
[163684]=279686,--Scabby
[163797]=177244,--Pet Template
[163711]=279929,--Fozling
[163975]=280728,--Sir Snips
[160708]=273215,--Summon Smoochums
[160847]=273839,--Summon Guardian Cobra Hatchling
[163816]=177217,--Pet Template
[163819]=280333,--Snort
[163803]=177237,--Pet Template
[160702]=273159,--Summon Spawn of Merektha
[163817]=280331,--Sunscale Hatchling
[161081]=274353,--Summon Taptaf
[163677]=279657,--Teeny Titan Orb
[163810]=177226,--Pet Template
[161214]=274776,--Summon Mummy
[163807]=177230,--Pet Template
[163652]=279643,--Voidwiggler
[163861]=280618,--Bloodfeaster Larva
[163824]=280338,--Voru'kar Leecher
[163860]=280617,--Gearspring Hopper
[160588]=272772,--Cap'n Crackers
--8.1
[166714]=289606,--Albatross Hatchling
[166491]=288890,--Albino Duskwatcher
[166486]=288867,--Baby Stonehide
[166448]=288582,--Gust of Cyclarus
[166452]=288595,--Hydrath Water Droplet
[166718]=289629,--Cobalt Raven
[166500]=288919,--Crimson Octopode
[166449]=288486,--Darkshore Sentinel
[165846]=286483,--Child of Pa'ku
[166453]=288597,--Everburning Treant
[166493]=288895,--Firesting Buzzer
[166487]=288868,--Leatherwing Screecher
[165855]=286576,--Leper Rat
[166494]=288901,--Lord Woofington
[165854]=286574,--Mechanical Cockroach
[165845]=286474,--Feathers
[165849]=286514,--Mechantula
[165844]=286514,--Mechantula(Recipe)
[165894]=286790,--Mini Spider Tank
[166489]=288875,--Needleback Pup
[166528]=289359,--Nightwreathed Watcher
[166716]=289622,--Crimson Bat Pup
[166358]=288054,--Proper Parrot
[166451]=288592,--Detective Ray
[166715]=289604,--Rebuilt Gorilla Bot
[166723]=289605,--Rebuilt Mechanical Spider
[165857]=286582,--Alarm-O-Dog
[165722]=285843,--Redridge Tarantula
[166488]=288870,--Rotting Ghoul
[166498]=288914,--Scritches
[166492]=288889,--Shadefeather Hatchling
[165848]=286484,--Spawn of Krag'wa
[166454]=288598,--Void Jelly
[166347]=288009,--Tanzil
[165847]=286482,--Thunder Lizard Runt
[166499]=288916,--Thunderscale Whelpling
[166495]=288910,--Tonguelasher
[166346]=288006,--Trecker
[166719]=289633,--Violet Abyssal Eel
[160587]=272771,--Summon Whomper
[165907]=286837,--Wicker Wraith
[166345]=287997,--Dasher
[166455]=288600,--Zur'aj the Depleted
--8.1.5
[164969]=283740,--Horse Balloon
[164971]=283741,--Murloc Balloon
[154902]=257603,--Perculia's Peculiar Parrot
[164970]=283744,--Wolf Balloon
--8.2
[169322]=300934,--Adventurous Hopling
[170072]=303784,--Armored Vaultbot
[170102]=303899,--Burnout
[169676]=302003,--Shrieker
[169677]=301996,--Crypt Fiend
[169670]=300387,--Minimancer
[169205]=300367,--Ghostly Whelpling
[169195]=300325,--Golden Cricket
[169879]=303608,--Irradiated Elementaling
[167809]=294279,--Slimy Darkhunter
[167808]=294278,--Slimy Eel
[167807]=294277,--Slimy Fangtooth
[167810]=294280,--Slimy Hermit Crab
[167806]=294276,--Slimy Octopode
[167805]=294275,--Slimy Otter
[167804]=294274,--Slimy Sea Slug
[169679]=301985,--Gruesome Belcher
[169678]=301992,--Ziggy
------------------------------------------
--**************************************--
--**************** TOYS ****************--
--**************************************--
------------------------------------------
--2.0.1
[23767]=30261,--Crashin Robot
[23810]=30261,--Crashin Robot(Recipe)
--2.4.0
[34686]=45426,--Brazier of Dancing Flames
}

--Camera data table--
mp.cameraTable = {
[27829]={["X"]=0,["Y"]=0,["Z"]=1.3,["S"]=0.3},
[48858]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.4},
[29060]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[28811]={["X"]=0,["Y"]=0,["Z"]=0.9,["S"]=1},
[11641]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[27242]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.6},
[40590]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[41991]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[51502]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[29259]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[48213]={["X"]=5,["Y"]=0,["Z"]=0,["S"]=0.6},
[48020]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[51269]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=0.9},
[46922]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.6},
[48211]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=0.6},
[46909]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.7},
[45264]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.4},
[4185]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.4},
[34955]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[24757]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[37154]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[20042]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.2},
[28556]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[12245]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[16943]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.4},
[27239]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[51591]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=0.7},
[38229]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.4},
[27248]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.6},
[28063]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[14778]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.7},
[10269]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.8},
[46925]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[41989]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[48212]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=0.5},
[45271]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=0.6},
[35750]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.8},
[38134]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[2177]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[40029]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.3},
[14348]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[42721]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[12246]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[12242]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[45195]={["X"]=0,["Y"]=0,["Z"]=0.3,["S"]=0.5},
[28435]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[21381]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=0.7},
[39319]={["X"]=0,["Y"]=0,["Z"]=0.9,["S"]=1},
[9905]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=0.6},
[53774]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=0.7},
[14579]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[21382]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.6},
[35757]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.7},
[51484]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[44635]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[28082]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[24758]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[41592]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[45987]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[4732]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.4},
[27245]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.2},
[43689]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[37541]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.6},
[48100]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=0.8},
[45521]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[40521]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=0.8},
[48101]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=0.8},
[45520]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[48855]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[46171]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[35755]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.7},
[45522]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[43562]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[30462]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[30346]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.8},
[28060]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.6},
[46087]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[42147]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=0.8},
[44655]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.7},
[47981]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[20996]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.7},
[25835]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.8},
[39563]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.8},
[28948]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[47716]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=0.8},
[35553]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.8},
[47983]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[37231]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.8},
[47715]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=0.8},
[44633]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[47959]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[25836]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.8},
[47955]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[47718]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=0.8},
[47597]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[47717]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=0.8},
[35754]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.8},
[47958]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[47976]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[39332]={["X"]=0,["Y"]=0,["Z"]=0.6,["S"]=1.2},
[47960]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[48661]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[51361]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[45797]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[51360]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[39330]={["X"]=0,["Y"]=0,["Z"]=0.6,["S"]=1.2},
[28063]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.6},
[27240]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[25833]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.8},
[27246]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[27785]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.8},
[51359]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[14349]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[34956]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[24393]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[27247]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[43693]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[39331]={["X"]=0,["Y"]=0,["Z"]=0.6,["S"]=1.2},
[51484]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=0.8},
[47256]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=0.6},
[27238]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[41903]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=0.7},
[51488]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[47238]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=0.8},
[27244]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[27237]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[41990]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[28217]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[24620]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[43692]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[14578]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[35551]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.8},
[40568]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.8},
[43686]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[43695]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[43697]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1},
[36583]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[55907]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[58395]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.5},
[58768]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=0.6},
[43697]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.0},
[55679]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=0.8},
[54848]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.6},
[43695]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.0},
[58772]={["X"]=0,["Y"]=0,["Z"]=0,["S"]=1.7},
}
