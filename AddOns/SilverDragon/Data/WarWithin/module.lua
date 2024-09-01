if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then return end -- classic misses expansion variables
if LE_EXPANSION_LEVEL_CURRENT < (LE_EXPANSION_WAR_WITHIN or math.huge) then return end

local core = LibStub("AceAddon-3.0"):GetAddon("SilverDragon")

-- Handynotes imports
--[[
minor transformations applied:
s/(?<= ){ -- (.+)$/{\n\t\tlabel="$1",/g",
--]]

-- Stub time!
local ns = {
	RegisterPoints = function(...)
		core:RegisterHandyNotesData("地心之戰", ...)
	end,
	conditions = core.conditions,
	MAXLEVEL = core.conditions.Level(80),
	SUPERRARE = function(point)
		local note = "This is a \"super rare\" which can drop higher level loot"
		if point.note then
			point.note = point.note .. "\n" .. note
		else
			point.note = note
		end
		return point
	end,
	atlas_texture = function(atlas, ...) return atlas end,
	nodeMaker = function(defaults)
		local meta = {__index = defaults}
		return function(details)
			details = details or {}
			if details.note and defaults.note then
				details.note = details.note .. "\n" .. defaults.note
			end
			local meta2 = getmetatable(details)
			if meta2 and meta2.__index then
				return setmetatable(details, {__index = MergeTable(CopyTable(defaults), meta2.__index)})
			end
			return setmetatable(details, meta)
		end
	end,
}

ns.KHAZALGAR = 2274
ns.DORNOGAL = 2339
ns.ISLEOFDORN = 2248
ns.RINGINGDEEPS = 2214
ns.HALLOWFALL = 2215
ns.AZJKAHET = 2255
ns.CITYOFTHREADS = 2213

ns.FACTION_ARATHI = 2570

ns.PROF_WW_ALCHEMY = 2871 -- spell:
ns.PROF_WW_BLACKSMITHING = 2872 -- spell:423332
ns.PROF_WW_COOKING = 2873 -- spell:
ns.PROF_WW_ENCHANTING = 2874 -- spell:
ns.PROF_WW_ENGINEERING = 2875 -- spell:
ns.PROF_WW_FISHING = 2876
ns.PROF_WW_HERBALISM = 2877
ns.PROF_WW_INSCRIPTION = 2878 -- spell:
ns.PROF_WW_JEWELCRAFTING = 2879 -- spell:
ns.PROF_WW_LEATHERWORKING = 2880 -- spell:
ns.PROF_WW_MINING = 2881
ns.PROF_WW_SKINNING = 2882
ns.PROF_WW_TAILORING = 2883 -- spell:

-- Treasures

core:RegisterTreasureData("WarWithin", {
	-- Isle of Dorn
	[6210] = {
		name="Tree's Treasure",
		achievement=40434, criteria=68197,
		quest=83242, -- 82160 when treasure appears
		loot={{224585, toy=true}}, -- Hanna's Locket
		notes="In cave; talk to {npc:222940:Freysworn Letitia} for a {item:224185:Crab-Guiding Branch}, then go find {npc:222941:Pearlescent Shellcrab} around the zone",
	},
	[6224] = {
		name="Magical Treasure Chest",
		achievement=40434, criteria=68199,
		quest=83243, -- 82212 for giving Lionel crabs
		loot={{224579, pet=3362}}, -- Sapphire Crab
		notes="Push {npc:223104:Lionel} into the water, talk to it, then go gather 5x {item:223159:Plump Snapcrab} nearby",
	},
	[6208] = {
		name="Mysterious Orb",
		achievement=40434, criteria=68201,
		quest=83244, -- 82047 after talking, 82134 after giving, also 82252 when looted
		loot={224373}, -- Waterlord's Iridescent Gem
		notes="Talk to {npc:222847:Weary Water Elemental}, then go fetch its {item:221504:Elemental Pearl}",
	},
	[6209] = {
		name="Mushroom Cap",
		achievement=40434, criteria=68202,
		quest=83245, -- 82142 after giving cap, 82253 as well on loot
		loot={210796}, -- Mycobloom
		notes="Talk to {npc:222894:U'llort the Self-Exiled} then fetch a {item:221550:Boskroot Cap} from the nearby woods",
	},
	[6236] = {
		name="Thak's Treasure",
		achievement=40434, criteria=68203,
		quest=82246,
		loot={
			212498, -- Ambivalent Amber
			212511, -- Ostentatious Onyx
		},
		notes="Talk to {npc:223227:One-Eyed Thak} and follow him to the treasure",
	},
	[6212] = {
		name="Lost Mosswool (Mosswool Flower)",
		achievement=40434, criteria=68204,
		quest=82145, -- when flower spawns
		loot={{224450, pet=4527}}, -- Lil' Moss Rosy
		notes="Chase {npc:222956:Lost Mosswool} to the flower",
	},
	[6238] = {
		name="Mosswool Flower",
		achievement=40434, criteria=68204,
		quest=83246, -- 82251 also when looted
		loot={{224450, pet=4527}}, -- Lil' Moss Rosy
		requires=ns.conditions.QuestComplete(82145),
		notes="Chase {npc:222956:Lost Mosswool} to the flower; if another player has recently looted if you may have to wait for it to appear",
	},
	[6273] = {
		name="Kobold Pickaxe",
		achievement=40434, criteria=68205,
		quest=82325,
		loot={223484}, -- Kobold Mastermind's "Pivel"
		notes="Despawns for a while after someone loots it, so you might need to wait around",
	},
	[6262] = {
		name="Jade Pearl",
		achievement=40434, criteria=68206,
		quest=82287,
		loot={223280}, -- Jade Pearl
		note="Despawns for a while after someone loots it, so you might need to wait around",
	},
	[6274] = {
		name="Shimmering Opal Lily",
		achievement=40434, criteria=68207,
		quest=82326,
		loot={
			213197, -- Null Lotus
			210800, -- Luredrop
		},
		path=47316149,
		notes="At the bottom of the cave; despawns for a while after someone loots it, so you might need to wait around",
	},
	[6292] = {
		name="Infused Cinderbrew",
		achievement=40434, criteria=68208,
		quest=82714,
		loot={224263}, -- Infused Fire-Honey Milk
		notes="On the desk; despawns for a while after someone loots it, so you might need to wait around"
	},
	[6293] = {
		name="Web-Wrapped Axe",
		achievement=40434, criteria=68209,
		quest=82715,
		loot={224290}, -- Storm Defender's Axe
		notes="Inside the building; despawns for a while after someone loots it, so you might need to wait around",
	},

	-- Turtle's Thanks
	[6244] = {
		name="Dalaran Sewer Turtle",
		achievement=40434, criteria=68198,
		quest=79585, -- pike
		loot={{224549,pet=4594}}, -- Sewer Turtle Whistle
		notes="Give {npc:223338:Dalaran Sewer Turtle} 5x {item:220143:Dornish Pike}, then leave the area and return to give it 1x {item:222533:Goldengill Trout}. Then go find it again in Dornegal.",
		active=ns.conditions.Item(220143, 5),
	},
	[6245] = {
		name="Dalaran Sewer Turtle",
		achievement=40434, criteria=68198,
		quest=79586, -- trout
		loot={{224549,pet=4594}}, -- Sewer Turtle Whistle
		note="Give {npc:223338:Dalaran Sewer Turtle} 1x {item:222533:Goldengill Trout}. Then go find it again in Dornegal.",
		active=ns.conditions.Item(222533),
	},
	[6246] = {
		name="Dalaran Sewer Turtle",
		achievement=40434, criteria=68198,
		quest=82255,
		loot={{224549,pet=4594}}, -- Sewer Turtle Whistle
		requires=ns.conditions.QuestComplete(79586), -- moves here
		notes="Talk to the turtle to spawn the treasure",
	},
	[6579] = {
		name="Turtle's Thanks",
		achievement=40434, criteria=68198,
		quest=82716, -- final!, also  when treasure spawns
		loot={{224549,pet=4594}}, -- Sewer Turtle Whistle
		requires=ns.conditions.QuestComplete(79586), -- moves here
		notes="Talk to the turtle to spawn the treasure",
	},

	-- Ringing Deeps
	[6286] = {
		name="Dusty Prospector's Chest",
		achievement=40724, criteria=69312,
		quest=82464,
		loot={212495, 212505, 212508}, -- some gems
		requires={ns.conditions.Level(71), ns.conditions.Item(223878), ns.conditions.Item(223879), ns.conditions.Item(223880), ns.conditions.Item(223881), ns.conditions.Item(223882)},
		notes="At the back of the inn; gather the five shards first",
	},
	[5994] = {
		name="Webbed Knapsack",
		achievement=40724, criteria=69280,
		quest=79308,
		loot={
			213254, -- Big Gold Nugget
			213251, -- Cinderbee Wax Jar
			213250, -- Cracked Gem
			213253, -- Gilded Candle
			213255, -- Wax Canary
			213252, -- Stolen Earthen Contraption
			213257, -- Wax Shovel
		},
		level=71,
		notes="In cave",
	},
	[6232] = {
		name="Cursed Pickaxe",
		achievement=40724, criteria=69281,
		quest=82230,
		loot={224837}, -- Cursed Pickaxe
		level=71,
	},
	[6233] = {
		name="Munderut's Forgotten Stash",
		achievement=40724, criteria=69282,
		quest=82235,
		loot={212498}, -- Ambivalent Amber + commendations
		level=71,
	},
	[6235] = {
		name="Discarded Toolbox",
		achievement=40724, criteria=69283,
		quest=82239,
		loot={224644}, -- Lava-Forged Cogwhee
		level=73,
	},
	[6356] = {
		name="Waterlogged Refuse",
		achievement=40724, criteria=69304,
		quest=83030,
		loot={213250, 213255, 213253, 213254}, -- various grays
		level=71,
	},
	[6277] = {
		name="Scary Dark Chest",
		achievement=40724, criteria=69307,
		quest=82818,
		loot={{224439, pet=4470}}, -- Oop'lajax
		level=71,
	},
	[6241] = {
		name="Kaja'Cola Machine",
		achievement=40724, criteria=69308,
		quest=82819,
		loot={220774}, -- Goblin Mini Fridge
		notes="Order four drinks in the right order: Bluesberry, Orange, Oyster, Mangoro (BOOM!)",
	},
	[6284] = {
		name="Dislodged Blockage",
		achievement=40724, criteria=69311,
		quest=82820,
		loot={{221548, pet=4536}}, -- Blightbud
		notes="Solve a sliding-tiles puzzle",
		level=71, -- can solve the puzzle, but not loot the chest
	},
	[6074] = {
		name="Forgotten Treasure",
		achievement=40724, criteria=69313,
		quest=80485, -- chests: 80488, 80489, 80490, 80487
		loot={{224783, toy=true}},
		notes="Cave behind the waterfall; open chests until you find the key",
		level=71,
	},
}, true)

-- Rares

local LOC_allkhazalgar = {[ns.KHAZALGAR]={},[ns.DORNOGAL]={},[ns.ISLEOFDORN]={},[ns.RINGINGDEEPS]={},[ns.HALLOWFALL]={},[ns.AZJKAHET]={},}

-- Isle of Dorn

ns.RegisterPoints(ns.ISLEOFDORN, {
	[22985829] = {
		label="Alunira",
		criteria=68225,
		quest=82196,
		npc=219281,
		loot={{223270, mount=2176}},
		active={ns.conditions.Item(224025, 10), ns.conditions.Item(224026)},
		note="Get 10x {item:224025:Crackling Shard} from zone mobs, combine into {item:224026:Storm Vessel}, use to break the shield",
		vignette=6055,
		--route={16606120,23205840},
	},
	[72043881] = {
		label="Tephratennae",
		criteria=68229,
		quest=81923,
		npc=221126,
		loot={
			223922, -- Cinder Pollen Cloak
			223937, -- Honey Deliverer's Leggings
		},
		-- tameable=true, -- wasp
		vignette=6112,
	},
	[57003460] = {
		label="Warphorn",
		criteria=68213,
		quest=81894,
		npc=219263,
		loot={
			223341, -- Warphorn's Resilient Mane
			223342, -- Warphorn's Resilient Chestplate
			223343, -- Warphorn's Resilient Chainmail
			223344, -- Warphorn's Resilient Vest
		},
		route={57003460, 58403560, 58403680, 57803780, 56603840, 56003780, 56403660, loop=true,},
		vignette=6044,
	},
	[48202703] = {
		label="Kronolith, Might of the Mountain",
		criteria=68220,
		quest=81902,
		npc=219270,
		loot={
			221210, -- Grips of the Earth
			221254, -- Earthshatter Lance
			221507, -- Earth Golem's Wrap
		},
		vignette=6051,
	},
	[74082756] = {
		label="Shallowshell the Clacker",
		criteria=68221,
		quest=81903, -- 84032
		npc=219278,
		loot={
			221224, -- Bouldershell Waistguard
			221233, -- Deephunter's Bloody Hook
			221255, -- Sharpened Scalepiercer
			221234, -- Tidal Pendant
			221248, -- Deep Terror Carver
		},
		vignette=6052,
	},
	[41137679] = {
		label="Bloodmaw",
		criteria=68214,
		quest=81893,
		npc=219264,
		loot={
			223349, -- Wolf Packleader's Cowl
			223350, -- Wolf Packleader's Helm
			223351, -- Wolf Packleader's Hood
			223370, -- Wolf Packleader's Visor
		},
		vignette=6045,
	},
	[58766068] = {
		label="Springbubble",
		criteria=68212,
		quest=81892,
		npc=219262,
		loot={
			223356, -- Shoulderpads of the Steamsurger
			223357, -- Spaulders of the Steamsurger
			223358, -- Mantle of the Steamsurger (name matches, but not listed?)
			223359, -- Epaulets of the Steamsurger
		},
		vignette=6043,
	},
	[62776842] = {
		label="Sandres the Relicbearer",
		criteria=68211,
		quest=79685,
		npc=217534,
		loot={
			223376, -- Band of the Relic Bearer
		},
		vignette=6026,
	},
	[55712727] = {
		label="Clawbreaker K'zithix",
		criteria=68224,
		quest=81920, -- 84036
		npc=221128,
		loot={
			223140, -- Formula: Enchant Cloak - Chant of Burrowing Rapidity
		},
		vignette=6115,
	},
	[47946014] = {
		label="Emperor Pitfang",
		criteria=68215,
		quest=81895,
		npc=219265,
		loot={
			223345, -- Viper's Stone Grips
			223346, -- Viper's Stone Handguards
			223347, -- Viper's Stone Mitts
			223348, -- Viper's Stone Gauntlets
		},
		vignette=6046,
		note="At the bottom of the cave",
	},
	[25784503] = {
		label="Escaped Cutthroat",
		criteria=68218,
		quest=81907,
		npc=219266,
		vignette=6049,
		loot={
			221208, -- Unseen Cutthroat's Tunic
			221235, -- Dark Agent's Cloak
		},
	},
	[73004010] = {
		label="Matriarch Charfuria",
		criteria=68231,
		quest=81921,
		npc=220890,
		loot={
			223948, -- Stubborn Wolf's Greathelm
			221247, -- Cavernous Critter Shooter
			221251, -- Bestial Underground Cleaver
			221265, -- Charm of the Underground Beast
			221246, -- Fierce Beast Staff
		},
		vignette=6114,
	},
	[57461625] = {
		label="Tempest Lord Incarnus",
		criteria=68219,
		quest=81901,
		npc=219269,
		loot={
			221230, -- Storm Bindings
			221236, -- Stormbreaker's Shield
		},
		vignette=6050,
	},
	[53348006] = {
		label="Gar'loc",
		criteria=68217,
		quest=81899,
		npc=219268,
		loot={
			221222, -- Water-Imbued Spaulders
			221234, -- Tidal Pendant
			221248, -- Deep Terror Carver
			221255, -- Sharpened Scalepiercer
			221233, -- Deephunter's Bloody Hook
		},
		vignette=6048,
	},
	[57072279] = {
		label="Twice-Stinger the Wretched",
		criteria=68222,
		quest=81904, -- 84033
		npc=219271,
		loot={
			221219, -- Silkwing Trousers
			221239, -- Spider Blasting Blunderbuss
			221506, -- Arachnid's Web-Sown Guise
		},
		-- tameable=true, -- blood beast
		vignette=6053,
	},
	[36477505] = {
		label="Rustul Titancap",
		criteria=68210,
		quest=78619,
		npc=213115,
		loot={
			223364, -- Wristwraps of the Titancap
			223365, -- Wristguards of the Titancap
			223366, -- Bracers of the Titancap
			223367, -- Cuffs of the Titancap
		},
		vignette=5959,
		note="Wanders the quarry",
	},
	[63994055] = {
		label="Flamekeeper Graz",
		criteria=68223,
		quest=81905, -- 84034
		npc=219279,
		loot={
			221244, -- Flamekeeper's Footpads
			221249, -- Kobold Rodent Squasher
		},
		vignette=6054,
	},
	[50876984] = {
		label="Plaguehart",
		criteria=68216,
		quest=81897, -- also 84026?
		npc=219267,
		loot={
			221213, -- Shawl of the Plagued
			221265, -- Charm of the Underground Beast
			221246, -- Fierce Beast Staff
			221251, -- Bestial Underground Cleaver
			221247, -- Cavernous Critter Shooter
		},
		--tameable=true, -- stag
		vignette=6047,
	},
	[69853847] = {
		label="Sweetspark the Oozeful",
		criteria=68230,
		quest=81922,
		npc=220883,
		loot={
			223929, -- Honey Sweetener's Squeezers
			223921, -- Ever-Oozing Signet
			223920, -- Slime Deflecting Stopper
		},
		vignette=6113,
	},
	-- Violet Hold prisoners:
	-- These all technically spawn exactly at 30915238
	[29915238] = {
		label="Kereke",
		criteria=68227,
		quest=82204,
		npc=222378,
		loot={
			226111, -- Arakkoan Ritual Staff
			226113, -- Kereke's Flourishing Sabre
			226114, -- Windslicer's Lance
		},
		vignette=6215,
		note="Violet Hold Prisoner",
	},
	[30915238] = {
		label="Zovex",
		criteria=68226,
		quest=82203,
		npc=219284,
		loot={
			226117, -- Dalaran Guardian's Arcanotool
			226118, -- Arcane Prisoner's Puncher
			226119, -- Arcane Sharpshooter's Crossbow
		},
		vignette=6058,
		note="Violet Hold Prisoner",
	},
	[31915238] = {
		label="Rotfist",
		criteria=68228,
		quest=82205,
		npc=222380,
		loot={
			226112, -- Rotfist Flesh Carver
			226115, -- Contaminating Cleaver
			226116, -- Coagulating Phlegm Churner
		},
		vignette=6216,
		note="Violet Hold Prisoner",
	},
}, {
	achievement=40435, -- Adventurer
})

ns.RegisterPoints(ns.ISLEOFDORN, {
	[31495529] = {
		label="Malfunctioning Spire",
		quest=81891,
		npc=220068,
		loot={
			210931, -- Bismuth
			210934, -- Aqirite
			210937, -- Ironclaw Ore
			210939, -- Null Stone
		},
		vignette=6073,
	},
	-- [46003180] = {
		label="Rowdy Rubble",
	--     quest=81515,
	--     npc=220846,
	--     vignette=6102,
	-- },
	[69204960] = {
		label="Elusive Ironhide Maelstrom Wolf",
		quest=nil,
		npc=224515,
		requires=ns.conditions.Profession(ns.PROF_WW_SKINNING),
		active=ns.conditions.Item(219007), -- Elusive Creature Lure
	},
})

-- Ringing Deeps

ns.RegisterPoints(ns.RINGINGDEEPS, {
	[52591991] = {
		label="Automaxor",
		criteria=69634,
		quest=81674,
		npc=220265,
		loot={
			221218, -- Reinforced Construct's Greaves
			221238, -- Pillar of Constructs
		},
		vignette=6128,
	},
	[41361692] = {
		label="Charmonger",
		criteria=69632,
		quest=81562,
		npc=220267,
		loot={
			221209, -- Flame Trader's Gloves
			221249, -- Kobold Rodent Squasher
		},
		vignette=6104,
	},
	[42773508] = {
		label="King Splash",
		criteria=69624,
		quest=80547,
		npc=220275,
		loot={
			223352, -- Waterskipper's Legplates
			223353, -- Waterskipper's Trousers
			223354, -- Waterskipper's Chain Leggings
			223355, -- Waterskipper's Leggings
		},
		--tameable=true, -- hopper
		vignette=6088,
	},
	[66002840] = {
		label="Candleflyer Captain",
		criteria=69623,
		quest=80505,
		npc=220276,
		loot={
			223360, -- Flying Kobold's Seatbelt (plate)
			223361, -- Flying Kobold's Seatbelt (cloth)
			223362, -- Flying Kobold's Seatbelt (mail)
			223363, -- Flying Kobold's Seatbelt (leather)
		},
		note="Patrols the area",
		vignette=6080,
	},
	[50864651] = {
		label="Cragmund",
		criteria=69630,
		quest=80560, -- 84042
		npc=220269,
		loot={
			221205, -- Vest of the River
			221254, -- Earthshatter Lance
			221507, -- Earth Golem's Wrap
		},
		vignette=6090,
	},
	[55060843] = {
		label="Deepflayer Broodmother",
		criteria=69636,
		quest=80536, -- 85162
		npc=220286,
		loot={
			221254, -- Earthshatter Lance
			221507, -- Earth Golem's Wrap
			225999, -- Earthen Adventurer's Tabard
		},
		note="Flys around anticlockwise",
		route={
			55060843, 53000880, 49560836, 49121007, 45290955, 43790822, 42650871, 44220973, 44331083, 45151312,
			43171750, 48681919, 53022244, 53751761, 56091023,
			loop=true,
		},
		vignette=6082,
	},
	[49556619] = {
		label="Aquellion",
		criteria=69625,
		quest=80557,
		npc=220274,
		loot={
			223340, -- Footguards of Shallow Waters
			223371, -- Slippers of Shallow Waters
			223372, -- Sabatons of Shallow Waters
			223373, -- Treads of Shallow Waters
		},
		vignette=6089,
	},
	[52022657] = {
		label="Zilthara",
		criteria=69629,
		quest=80506,
		npc=220270,
		loot={
			221220, -- Basilisk Scale Pauldrons
			221246, -- Fierce Beast Staff
			221247, -- Cavernous Critter Shooter
			221251, -- Bestial Underground Cleaver
			221265, -- Charm of the Underground Beast
		},
		vignette=6079,
	},
	[57903813] = {
		label="Coalesced Monstrosity",
		criteria=69633,
		quest=81511,
		npc=220266,
		loot={
			221226, -- Voidtouched Waistguard
			223006, -- Signet of Dark Horizons
		},
		vignette=6101,
	},
	[46701209] = {
		label="Terror of the Forge",
		criteria=69628,
		quest=80507, -- 84040
		npc=220271,
		loot={
			221233, -- Deephunter's Bloody Hook
			221234, -- Tidal Pendant
			221242, -- Forgeborn Helm
			221248, -- Deep Terror Carver
			221255, -- Sharpened Scalepiercer
		},
		vignette=6081,
		note="Walking in the lava",
	},
	[47224696] = {
		label="Kelpmire",
		criteria=69635,
		quest=81485, -- 84047
		npc=220287,
		loot={
			221204, -- Spore Giant's Stompers
			221250, -- Creeping Lasher Machete
			221253, -- Cultivator's Plant Puncher
			221264, -- Fungarian Mystic's Cluster
			223005, -- String of Fungal Fruits
		},
		vignette=6099,
	},
	[57025480] = {
		label="Rampaging Blight",
		criteria=69626,
		quest=81563,
		npc=220273,
		loot={
			223401, -- Corrupted Earthen Wristwraps
			223402, -- Corrupted Earthen Wristguards
			223403, -- Corrupted Earthen Binds
			223404, -- Corrupted Earthen Cuffs
		},
		vignette=6105,
	},
	[71654629] = {
		label="Trungal",
		criteria=69631,
		quest=80574,
		npc=220268,
		loot={
			221228, -- Infested Fungal Wristwraps
			221250, -- Creeping Lasher Machete
			221253, -- Cultivator's Plant Puncher
			221264, -- Fungarian Mystic's Cluster
			223005, -- String of Fungal Fruits
		},
		note="Kill the {npc:220615:Root of Trungal} to spawn",
		path={72534569, 72844444},
		vignette=6126,
	},
	[68404754] = {
		label="Spore-infused Shalewing",
		criteria=69638,
		quest=81652,
		npc=221217,
		loot={
			223918, -- Specter Stalker's Shotgun
			223919, -- Abducted Lawman's Gavel
			223942, -- Spore-Encrusted Ribbon
		},
		vignette=6121,
		note="Flies around clockwise",
		route={
			68604852, 68735012, 68675047, 68215137, 68055156, 67745171, 67535176, 67225176, 67075174, 66585120, 66244896,
			66264870, 66404840, 66234817, 65724779, 65564760, 65474737, 65534711, 65724669, 65834655, 66044644, 66944640,
			67624608, 67774620, 68094659, 68214680, 68404754,
			loop=true,
		},
	},
	[65364949] = {
		label="Hungerer of the Deeps",
		criteria=69639,
		quest=81648, -- 84048
		npc=221199,
		loot={
			221233, -- Deephunter's Bloody Hook
			221234, -- Tidal Pendant
			221248, -- Deep Terror Carver
			221255, -- Sharpened Scalepiercer
			223949, -- Dark Depth Stompers
		},
		vignette=6119,
	},
	[67085262] = {
		label="Disturbed Earthgorger",
		criteria=69640,
		quest=80003,
		npc=218393,
		loot={
			221237, -- Lamentable Vagrant's Lantern
			223926, -- Earthgorger's Chain Bib
			223943, -- Cord of the Earthbreaker
		},
		vignette=6031,
	},
	[66716881] = {
		label="Deathbound Husk",
		criteria=69627,
		quest=81566,
		npc=220272,
		loot={
			223368, -- Twisted Earthen Signet
		},
		vignette=6106,
		note="In cave",
		path=67056796,
	},
	[60887682] = {
		label="Lurker of the Deeps",
		criteria=69637,
		quest=81633, -- 85163
		npc=220285,
		loot={
			{223501, mount=2205}, -- Regurgitated Mole Reins
			221233, -- Deephunter's Bloody Hook
			221234, -- Tidal Pendant
			221248, -- Deep Terror Carver
			221255, -- Sharpened Scalepiercer
		},
		vignette=6110,
		note="Pull 5 levers across the zone at the same time to summon; they stay activated for ~10 seconds, so you'll need a group",
		related={
			[49470882] = {label="Inconspicuous Lever", note="Pull all 5 levers simultaneously to summon {npc:220285:Lurker of the Deeps}"},
			[53912530] = {label="Inconspicuous Lever", note="Pull all 5 levers simultaneously to summon {npc:220285:Lurker of the Deeps}"},
			[57612358] = {label="Inconspicuous Lever", note="Pull all 5 levers simultaneously to summon {npc:220285:Lurker of the Deeps}"},
			[59079239] = {label="Inconspicuous Lever", note="Pull all 5 levers simultaneously to summon {npc:220285:Lurker of the Deeps}"},
			[62854464] = {label="Inconspicuous Lever", note="Pull all 5 levers simultaneously to summon {npc:220285:Lurker of the Deeps}"},
		},
	},
}, {
	achievement=40837, -- Adventurer
})

ns.RegisterPoints(ns.RINGINGDEEPS, {
	[62805000] = {
		label="Slatefang",
		quest=nil,
		npc=228439,
		requires=ns.conditions.Profession(ns.PROF_WW_SKINNING),
		active=ns.conditions.Item(219008), -- Supreme Beast Lure
	},
})

-- Hallowfall

ns.RegisterPoints(ns.HALLOWFALL, {
	[23005922] = {
		label="Lytfang the Lost",
		criteria=69710,
		quest=81756,
		npc=221534,
		loot={
			221207, -- Den Mother's Chestpiece
			221246, -- Fierce Beast Staff
			221251, -- Bestial Underground Cleaver
			221265, -- Charm of the Underground Beast
		},
		vignette=6145,
	},
	[63402880] = {
		label="Moth'ethk",
		criteria=69719,
		quest=82557,
		npc=206203,
		loot={
			221240, -- Nerubian Stagshell Gouger
			221252, -- Nerubian Slayer's Claymore
			221263, -- Nerubian Venom-Tipped Dart
			223924, -- Chitin-Inscribed Vest
		},
		vignette=5958,
		note="Objective of {questname:76588}",
	},
	[44011639] = {
		label="The Perchfather",
		criteria=69711,
		quest=81791,
		npc=221648,
		loot={
			221229, -- Perchfather's Cuffs
			221246, -- Fierce Beast Staff
			221247, -- Cavernous Critter Shooter
			221251, -- Bestial Underground Cleaver
			221265, -- Charm of the Underground Beast
		},
		vignette=6151,
	},
	[56466897] = {
		label="The Taskmaker",
		criteria=69708,
		quest=80009,
		npc=218444,
		loot={
			221215, -- Taskmaster's Mining Cap
			221240, -- Nerubian Stagshell Gouger
			221252, -- Nerubian Slayer's Claymore
			221263, -- Nerubian Venom-Tipped Dart
		},
		vignette=6033,
	},
	[31205464] = {
		label="Grimslice",
		criteria=69706,
		quest=81761,
		npc=221551,
		loot={
			223397, -- Abyssal Hunter's Girdle
			223398, -- Abyssal Hunter's Sash
			223399, -- Abyssal Hunter's Chain
			223400, -- Abyssal Hunter's Cinch
		},
		route={
			31205464, 33235598, 32725814, 34135728, 34525751, 35085894, 35655746, 36495657, 36945464,
			36555280, 35625156, 35055029, 34555186, 34135204, 32725119, 33235334,
			r=0, g=1, b=1,
			loop=true,
		},
		vignette=6146,
		note="Patrols clockwise",
	},
	[43622993] = {
		label="Strength of Beledar",
		criteria=69713,
		quest=81849,
		npc=221690, -- Rage of Beledar
		loot={
			221216, -- Bruin Strength Legplates
			221246, -- Fierce Beast Staff
			221247, -- Cavernous Critter Shooter
			221251, -- Bestial Underground Cleaver
			221265, -- Charm of the Underground Beast
			221508, -- Pelt of Beledar's Strength
		},
		vignette=6153,
	},
	[57046436] = {
		label="Ixlorb the Spinner",
		criteria=69704,
		quest=80006,
		npc=218426,
		loot={
			223374, -- Nerubian Weaver's Gown
			223379, -- Nerubian Weaver's Chestplate
			223380, -- Nerubian Weaver's Chainmail
			223381, -- Nerubian Weaver's Vest
			223100, -- Pattern: Vambraces of Deepening Darkness
		},
		vignette=6032, -- Ixlorb the Weaver
	},
	[62401320] = {
		label="Murkspike",
		criteria=69728,
		quest=82565,
		npc=220771,
		loot={
			221233, -- Deephunter's Bloody Hook
			221234, -- Tidal Pendant
			221248, -- Deep Terror Carver
			221255, -- Sharpened Scalepiercer
			223934, -- Makrura's Foreboding Legplates
		},
		vignette=6123,
		note="Objective of {questname:76588}",
	},
	[63643204] = {
		label="Deathpetal",
		criteria=69721,
		quest=82559,
		npc=206184,
		loot={
			221250, -- Creeping Lasher Machete
			221253, -- Cultivator's Plant Puncher
			221264, -- Fungarian Mystic's Cluster
			223005, -- String of Fungal Fruits
			223927, -- Vinewrapped Leather Tunic
		},
		vignette=6078,
		note="Objective of {questname:76588}",
	},
	[72136436] = {
		label="Deepfiend Azellix",
		criteria=69703,
		quest=80011,
		npc=218458,
		loot={
			223393, -- Deepfiend Spaulders
			223394, -- Deepfiend Pauldrons
			223395, -- Deepfiend Shoulderpads
			223396, -- Deepfiend Shoulder Shells
		},
		vignette=6035,
	},
	[64401880] = {
		label="Duskshadow",
		criteria=69724,
		quest=82562,
		npc=221179,
		loot={
			223918, -- Specter Stalker's Shotgun
			223919, -- Abducted Lawman's Gavel
			223936, -- Shadow Bog Trousers
		},
		vignette=6122,
		note="Objective of {questname:76588}",
	},
	[36687172] = {
		label="Funglour",
		criteria=69707,
		quest=81881,
		npc=221767,
		loot={
			223377, -- Ancient Fungarian's Fingerwrap
		},
		vignette=6157,
	},
	[35953546] = {
		label="Sir Alastair Purefire",
		criteria=69714,
		quest=81853,
		npc=221708,
		loot={
			221241, -- Priestly Agent's Knife
			221245, -- Righteous Path Treads
		},
		vignette=6154,
	},
	[43410990] = {
		label="Horror of the Shallows",
		criteria=69712,
		quest=81836,
		npc=221668,
		loot={
			221211, -- Grasp of the Shallows
			221233, -- Deephunter's Bloody Hook
			221234, -- Tidal Pendant
			221248, -- Deep Terror Carver
			221255, -- Sharpened Scalepiercer
		},
		vignette=6152,
		note="Very long patrol",
		route={
			43410990, 43870879, 44520774, 45250767, 45970726, 45540662, 44870677, 44270749, 43710858, 41631452,
			41391580, 41051714, 40501821, 39731909, 36652173, 33992545, 33422650, 32912763, 31783130, 30933154,
			29993162, 29123191, 28213204, 27343238, 26553287, 26513416, 26813550, 27983757, 28633853, 29403934,
			30173998, 30764092, 30984221, 30594339, 29814381, 27194486, 26364534, 25664611, 24954700, 23314830,
			23274858, 22464885, 20774968, 19904976, 19565105, 20285138, 20865040, 21614971, 22474926,
			r=0,g=0,b=1,
		},
	},
	[73405259] = {
		label="Sloshmuck",
		criteria=69709,
		quest=79271,
		npc=215805,
		loot={
			221223, -- Bog Beast Mantle
			221250, -- Creeping Lasher Machete
			221253, -- Cultivator's Plant Puncher
			221264, -- Fungarian Mystic's Cluster
			223005, -- String of Fungal Fruits
		},
		vignette=5988,
	},
	[52132682] = {
		label="Murkshade",
		criteria=69705,
		quest=80010,
		npc=218452,
		loot={
			223382, -- Murkshade Grips
			223383, -- Murkshade Handguards
			223384, -- Murkshade Gloves
			223385, -- Murkshade Gauntlets
		},
		vignette=6034,
		note="Underwater",
	},
	[67562316] = {
		label="Croakit",
		criteria=69722,
		quest=82560,
		npc=214757,
		loot={
			221246, -- Fierce Beast Staff
			221247, -- Cavernous Critter Shooter
			221251, -- Bestial Underground Cleaver
			221265, -- Charm of the Underground Beast
			223938, -- Marsh Hopper's Spaulders
		},
		vignette=6125,
		--tameable=true, -- hopper
		note="Objective of {questname:76588}",
	},
	[57304858] = {
		label="Pride of Beledar",
		criteria=69715,
		quest=81882,
		npc=221786,
		loot={
			221225, -- Benevolent Hornstag Cinch
			221246, -- Fierce Beast Staff
			221247, -- Cavernous Critter Shooter
			221251, -- Bestial Underground Cleaver
			221265, -- Charm of the Underground Beast
			223007, -- Lance of Beledar's Pride
		},
		vignette=6159,
		-- tameable=true, -- stag
	},
	[66202340] = {
		label="Toadstomper",
		criteria=69723,
		quest=82561,
		npc=207803,
		loot={
			223920, -- Slime Deflecting Stopper
			223921, -- Ever-Oozing Signet
			223933, -- Slime Goliath's Cap
		},
		vignette=6084,
		note="Objective of {questname:76588}",
	},
	[64802920] = {
		label="Crazed Cabbage Smacker",
		criteria=69720,
		quest=82558,
		npc=206514,
		loot={
			211968, -- Blueprint Bundle
			221238, -- Pillar of Constructs
			223928, -- Crop Cutter's Gauntlets
			223935, -- Cabbage Harvester's Pantaloons
		},
		vignette=6120,
		note="Objective of {questname:76588}",
	},
	[60201860] = {
		label="Finclaw Bloodtide",
		criteria=69727,
		quest=82564,
		npc=207780, -- also 220492?
		loot={
			221233, -- Deephunter's Bloody Hook
			221234, -- Tidal Pendant
			221248, -- Deep Terror Carver
			223925, -- Blood Hungerer's Chestplate
		},
		vignette=6085,
		note="Objective of {questname:76588}",
	},
	[61603360] = {
		label="Ravageant",
		criteria=69726,
		quest=82566,
		npc=207826,
		loot={
			221240, -- Nerubian Stagshell Gouger
			221252, -- Nerubian Slayer's Claymore
			221263, -- Nerubian Venom-Tipped Dart
			223932, -- Scarab's Carapace Cap
		},
		vignette=6124,
		note="Objective of {questname:76588}",
	},
	[61403220] = {
		label="Parasidious",
		criteria=69725,
		quest=82563,
		npc=206977,
		loot={
			221250, -- Creeping Lasher Machete
			221264, -- Fungarian Mystic's Cluster
			223005, -- String of Fungal Fruits
			223940, -- Deranged Fungarian's Epaulets
		},
		vignette=6361,
		note="Objective of {questname:76588}",
	},
	-- UNKNOWN LOCATION
	--[[
	[] = {
		label="Brineslash",
		criteria=69718,
		quest=80486,
		npc=220159,
		vignette=6075,
	},
	--]]
}, {
	achievement=40851,
})
-- Beledar's Spawn
ns.RegisterPoints(ns.HALLOWFALL, {
	[25825754] = {},
	[32673962] = {},
	[37207191] = {},
	[37744585] = {},
	[38382474] = {},
	[42733133] = {},
	[45252569] = {},
	[47015504] = {},
	[48853197] = {},
	[50514857] = {},
	[51427080] = {},
	[54833679] = {},
	[58034885] = {},
	[60451862] = {},
	[61380753] = {},
	[62823857] = {},
	[68123014] = {},
	[71976558] = {},
	[72066566] = {},
	[72804152] = {},
}, {
	achievement=40851,
	criteria=69716,
	quest=81763,
	npc=207802,
	loot={
		{223315, mount=2192,}, -- Beledar's Spawn
		223006, -- Signet of Dark Horizons
	},
	requires=ns.conditions.MajorFaction(ns.FACTION_ARATHI, 23),
	active=ns.conditions.QuestComplete(82998), -- attunement
	note="Buy and use {item:224553:Beledar's Attunement} from {majorfaction:2570:Hallowfall Arathi} to access",
	vignette=6359, -- also 6118?
})

-- Deathtide
local deathtide = ns.nodeMaker{
	achievement=40851,
	criteria=69717,
	quest=81880,
	level=80, -- required to loot the offering/jar
}
ns.RegisterPoints(ns.HALLOWFALL, {
	[44744241] = {
		label="Deathtide",
		npc=221753,
		loot={
			223920, -- Slime Deflecting Stopper
			223921, -- Ever-Oozing Signet
			225997, -- Earthen Adventurer's Spaulders
		},
		vignette=6156,
		active=ns.conditions.Item(220123), -- Ominous Offering
		note="Create an {item:220123:Ominous Offering} to summon",
	},
}, deathtide{})
ns.RegisterPoints(ns.HALLOWFALL, {
	-- Jar of Mucus
	[48001668] = {route={48001668, 44744241, highlightOnly=true}},
}, deathtide{
	label="{item:220124}",
	loot={220124},
	texture=ns.atlas_texture("playerpartyblip",{r=0,g=1,b=1,}),
	minimap=true,
	note="Take to {npc:221753} @ 44.7,42.4",
})
ns.RegisterPoints(ns.HALLOWFALL, {
	 -- Offering of Pure Water
	[28925120] = {route={28925120, 44744241, highlightOnly=true}},
	[34185782] = {route={34185782, 44744241, highlightOnly=true}},
	[34365357] = {route={34365357, 44744241, highlightOnly=true}},
	[43451413] = {route={43451413, 44744241, highlightOnly=true}},
	[50094966] = {route={50094966, 44744241, highlightOnly=true}},
	[53771913] = {route={53771913, 44744241, highlightOnly=true}},
	[55142344] = {route={55142344, 44744241, highlightOnly=true}},
}, deathtide{
	label="{item:220122}",
	loot={220122},
	texture=ns.atlas_texture("playerpartyblip",{r=0,g=0,b=1,}),
	minimap=true,
	note="Take to {npc:221753} @ 44.7,42.4",
})


ns.RegisterPoints(ns.HALLOWFALL, {
	[62650611] = {
		label="Radiant-Twisted Mycelium",
		quest=nil, -- 76588 defender of the flame
		npc=214905,
		vignette=5984,
		note="Objective of {questname:76588}",
	},
})

-- Azj-Kahet

ns.RegisterPoints(ns.AZJKAHET, {
	[65201896] = {
		label="Kaheti Silk Hauler",
		-- [62404140, 68205360]
		criteria=69659,
		quest=81702,
		npc=221327,
		loot={
			221206, -- Reinforced Chitin Chestpiece
			221240, -- Nerubian Stagshell Gouger
			221252, -- Nerubian Slayer's Claymore
			221263, -- Nerubian Venom-Tipped Dart
		},
		vignette=6134,
		route={65201896, 65142033, 63122532, 62492877, 61882919},
		note="Slowly wanders back and forth",
	},
	[76585780] = {
		label="XT-Minecrusher 8700",
		criteria=69660,
		quest=81703,
		npc=216034,
		loot={
			221231, -- Steam-Powered Wristwatch
			221232, -- Polished Goblin Bling
		},
		vignette=6131,
	},
	[47204320] = {
		label="Abyssal Devourer",
		-- [47204320, 47204380]
		criteria=69651,
		quest=81695,
		npc=216031,
		loot={
			223389, -- Legplates of Dark Hunger
			223390, -- Leggings of Dark Hunger
			223391, -- Legguards of Dark Hunger
			223392, -- Trousers of Dark Hunger
		},
		vignette=6129,
	},
	[68876480] = {
		label="Maddened Siegebomber",
		criteria=69663,
		quest=81706,
		npc=216044,
		loot={
			221217, -- Nerubian Bomber's Leggings
			221240, -- Nerubian Stagshell Gouger
			221252, -- Nerubian Slayer's Claymore
			221263, -- Nerubian Venom-Tipped Dart
		},
		vignette=6138,
		route={
			68876480, 69006715, 67206730, 65596605, 63576530, 61636444, 61006640,
			62106844, 64256750, 65356414, 66936243,
			loop=true,
		},
		note="Patrols around the area, fighting other mobs",
	},
	[34574106] = {
		label="Vilewing",
		-- [36004480, 36204400, 36404580, 36604660, 36804320, 36804580, 37004540]
		criteria=69656,
		quest=81700,
		npc=216037,
		loot={
			223386, -- Vilewing Crown
			223387, -- Vilewing Chain Helm
			223388, -- Vilewing Cap
			223405, -- Vilewing Visor
		},
		vignette=6132,
	},
	[61242731] = {
		label="Webspeaker Grik'ik",
		criteria=69655,
		quest=81699,
		npc=216041,
		loot={
			223369, -- Webspeaker's Spiritual Cloak
		},
		vignette=6135,
	},
	[70732146] = {
		label="Cha'tak",
		criteria=69661,
		quest=81704,
		npc=216042,
		loot={
			221212, -- Death Burrower Handguards
			221237, -- Lamentable Vagrant's Lantern
		},
		vignette=6136,
		note="Cave behind the waterfall",
	},
	[58056233] = {
		label="Enduring Gutterface",
		criteria=69664,
		quest=81707,
		npc=216045,
		loot={
			221233, -- Deephunter's Bloody Hook
			221234, -- Tidal Pendant
			221243, -- Slippers of Delirium
			221248, -- Deep Terror Carver
			221255, -- Sharpened Scalepiercer
		},
		vignette=6139,
	},
	[69996920] = {
		label="Monstrous Lasharoth",
		criteria=69662,
		quest=81705,
		npc=216043,
		loot={
			221227, -- Monstrous Fungal Cord
			221250, -- Creeping Lasher Machete
			221253, -- Cultivator's Plant Puncher
			221264, -- Fungarian Mystic's Cluster
			223005, -- String of Fungal Fruits
		},
		vignette=6137,
	},
	[44803980] = {
		label="Khak'ik",
		criteria=69653,
		quest=81694,
		npc=216032,
		loot={
			223378, -- Footguards of the Nerubian Twins
			223406, -- Slippers of the Nerubian Twins
			223407, -- Sabatons of the Nerubian Twins
			223408, -- Treads of the Nerubian Twins
		},
		vignette=6130,
		note="Patrols with {npc:221032:Rhak'ik}",
	},
	--[[ -- with Khak'ik:
	[43763953] = {
		label="Rhak'ik",
		-- [44803880, 44803980, 45204440]
		criteria=69653,
		quest=81694,
		npc=221032,
		vignette=6130, -- Stronghold Scouts
		note="Patrols with {npc:216032:Khak'ik}",
	},
	--]]
	[37944285] = {
		label="Ahg'zagall",
		criteria=69654,
		quest=78905,
		npc=214151,
		loot={
			223375, -- Clattering Chitin Necklace
		},
		vignette=5973,
	},
	[64600352] = {
		label="Umbraclaw Matra",
		criteria=69668,
		quest=82037,
		npc=216051,
		loot={
			221240, -- Nerubian Stagshell Gouger
			221252, -- Nerubian Slayer's Claymore
			221263, -- Nerubian Venom-Tipped Dart
			223930, -- Monstrous Chain Pincers
		},
		vignette=6186,
	},
	[62940509] = {
		label="Kaheti Bladeguard",
		criteria=69670,
		quest=82078,
		npc=216052, -- Skirmisher Sa'ztyk
		loot={
			223915, -- Nerubian Orator's Stiletto
			223916, -- Nerubian Cutthroat's Reach
			223917, -- Nerubian Covert's Cloak
			223939, -- Esteemed Nerubian's Mantle
		},
		vignette=6204,
		note="Patrols the area",
	},
	[64590667] = {
		label="Deepcrawler Tx'kesh",
		criteria=69669,
		quest=82077,
		npc=222624,
		loot={
			223915, -- Nerubian Orator's Stiletto
			223916, -- Nerubian Cutthroat's Reach
			223917, -- Nerubian Covert's Cloak
			223923, -- Gilded Cryptlord's Sabatons
		},
		vignette=6203,
	},
}, {
	achievement=40840, -- Adventurer
	levels=true,
})

ns.RegisterPoints(2256, {
		label="Azj-Kahet Lower",
	[64768691] = {
		label="Harvester Qixt",
		criteria=69667,
		quest=82036,
		npc=216050,
		loot={
			223915, -- Nerubian Orator's Stiletto
			223916, -- Nerubian Cutthroat's Reach
			223941, -- Nerubian Cultivator's Girdle
		},
		vignette=6185,
	},
	[61938973] = {
		label="The Oozekhan",
		criteria=69666,
		quest=82035,
		npc=216049,
		loot={
			223006, -- Signet of Dark Horizons
			223931, -- Black Blood Cowl
		},
		vignette=6184,
	},
	[67458318] = {
		label="Jix'ak the Crazed",
		criteria=69665,
		quest=82034,
		npc=216048,
		loot={
			223915, -- Nerubian Orator's Stiletto
			223916, -- Nerubian Cutthroat's Reach
			223917, -- Nerubian Covert's Cloak
			223950, -- Corruption Sifter's Treads
		},
		vignette=6183,
	},
}, {
	achievement=40840, -- Adventurer
	levels=true,
})

ns.RegisterPoints(ns.AZJKAHET, {
	[63409500] = {
		label="The One Left",
		quest=nil,
		npc=216047,
		loot={
			221246, -- Fierce Beast Staff
			221247, -- Cavernous Critter Shooter
			221251, -- Bestial Underground Cleaver
			221265, -- Charm of the Underground Beast
			225998, -- Earthen Adventurer's Cloak
		},
		path=65269328,
	},
}, {levels=true})

ns.RegisterPoints(ns.CITYOFTHREADS, {
	[36404160] = {
		label="The Groundskeeper",
		criteria=69657,
		quest=81634,
		npc=216038,
		loot={
			221214, -- Chitin Chain Headpiece
			221240, -- Nerubian Stagshell Gouger
			221252, -- Nerubian Slayer's Claymore
			221263, -- Nerubian Venom-Tipped Dart
		},
		vignette=6111,
	},
	[67165840] = {
		label="Xishorr",
		criteria=69658,
		quest=81701,
		npc=216039,
		loot={
			221221, -- Venomous Lurker's Greathelm
			221239, -- Spider Blasting Blunderbuss
			221506, -- Arachnid's Web-Sown Guise
		},
		vignette=6133,
	},
}, {
	achievement=40840, -- Adventurer
	parent=true, levels=true, translate={[2256]=true},
})

ns.RegisterPoints(ns.AZJKAHET, {
	[62796618] = {
		label="Tka'ktath",
		quest=82289,
		npc=216046,
		loot={
			{225952, quest=83627}, -- Vial of Tka'ktath's Bloo
			-- {224150, mount=2222}, -- Siesbarg
			221240, -- Nerubian Stagshell Gouger
			221252, -- Nerubian Slayer's Claymore
			221263, -- Nerubian Venom-Tipped Dart
		},
		vignette=6265,
		note="Begins a quest chain leading to the mount {item:224150:Siesbarg}",
	},
	[39804100] = {
		label="Elusive Razormouth Steelhide",
		quest=nil,
		npc=226232,
		requires=ns.conditions.Profession(ns.PROF_WW_SKINNING),
		active=ns.conditions.Item(219007), -- Elusive Creature Lure
	},
}, {levels=true,})
