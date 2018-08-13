-----------------------------------------------------------------------
-- Upvalued Lua API.
-----------------------------------------------------------------------
local _G = getfenv(0)
local select = _G.select
local string = _G.string
local format = string.format

-- WoW
local GetAchievementInfo = GetAchievementInfo
-- ----------------------------------------------------------------------------
-- AddOn namespace.
-- ----------------------------------------------------------------------------
local addonname = ...
local AtlasLoot = _G.AtlasLoot
local data = AtlasLoot.ItemDB:Add(addonname, 7)

local AL = AtlasLoot.Locales

local RF_DIFF = data:AddDifficulty(AL["Raid Finder"], "LFRWithPreset", {
	Item = {
		--item1bonus = "LegionLFR",
		item2bonus = "LegionMaxTitanforgedByBaseLvl",
		autoCompleteItem2 = true,
		addDifficultyBonus = true,
	},
}, 17)
local NORMAL_DIFF = data:AddDifficulty(AL["Normal"], "n", nil, 1)
local NORMAL_RAID_DIFF = data:AddDifficulty(AL["Normal"], "NormalRaidWithPreset", {
	Item = {
		--item1bonus = nil,
		item2bonus = "LegionMaxTitanforgedByBaseLvl",
		autoCompleteItem2 = true,
		addDifficultyBonus = true,
	},
}, 14)
local NORMAL_DUNGEON_DIFF = data:AddDifficulty(AL["Normal"], "DungeonWithPreset", {
	Item = {
		--item1bonus = "LegionDungeon",
		item2bonus = "LegionDungeonTitanforged",
		autoCompleteItem2 = true,
		addDifficultyBonus = true,
	},
}, 1)
local HEROIC_DIFF = data:AddDifficulty(AL["Heroic"], "h", nil, 2)
local HEROIC_DUNGEON_DIFF = data:AddDifficulty(AL["Heroic"], "HeroicDungeonWithPreset", {
	Item = {
		--item1bonus = "LegionHCDungeon",
		item2bonus = "LegionHCDungeonTitanforged",
		autoCompleteItem2 = true,
		addDifficultyBonus = true,
	},
}, 2)
local MYTHICD_DIFF = data:AddDifficulty(AL["Mythic"], "h", nil, 23)
local MYTHICD_DUNGEON_DIFF = data:AddDifficulty(AL["Mythic"], "MythicDungeonWithPreset", {
	Item = {
		--item1bonus = "LegionMDungeon",
		item2bonus = "LegionMDungeonTitanforged",
		autoCompleteItem2 = true,
		addDifficultyBonus = true,
	},
}, 23)
local MYTHICD2_DIFF = data:AddDifficulty(AL["Mythic"], "h", nil, 23)
local MYTHICD2_DUNGEON_DIFF = data:AddDifficulty(AL["Mythic"], "MythicDungeon2WithPreset", {
	Item = {
		item1bonus = "LegionMDungeon2",
		item2bonus = "LegionMDungeon2Titanforged",
		autoCompleteItem2 = true,
		addDifficultyBonus = true,
	},
}, 23)
local HEROIC_PRE_DIFF = data:AddDifficulty(AL["Heroic"], "HeroicWithPreset", {
	Item = {
		--item1bonus = "LegionHeroicRaid",
		item2bonus = "LegionMaxTitanforgedByBaseLvl",
		autoCompleteItem2 = true,
		addDifficultyBonus = true,
	},
}, 15)
local MYTHIC_DIFF = data:AddDifficulty(AL["Mythic"], "m", nil, 16)
local MYTHIC_PRE_DIFF = data:AddDifficulty(AL["Mythic"], "MyhticWithPreset", {
	Item = {
		--item1bonus = "LegionMythicRaid",
		item2bonus = "LegionMaxTitanforgedByBaseLvl",
		autoCompleteItem2 = true,
		addDifficultyBonus = true,
	},
}, 16)

local NORMAL_ITTYPE = data:AddItemTableType("Item", "Item")
local RAID_ITTYPE = data:AddItemTableType("Item", "Item") -- Normal, Thunder-/Warforged...
local AC_ITTYPE = data:AddItemTableType("Achievement", "Item")

local DUNGEON_CONTENT = data:AddContentType(AL["Dungeons"], ATLASLOOT_DUNGEON_COLOR)
local RAID_CONTENT = data:AddContentType(AL["Raids"], ATLASLOOT_RAID_COLOR)

-- Shared loot tables
local LEGION_DUNGEON_HERO_AC_TABLE = {	--[Legion Dungeon Hero]
	name = select(2, GetAchievementInfo(11164)),
	TableType = AC_ITTYPE,
	ExtraList = true,
	CoinTexture = "Achievement",
	[HEROIC_DIFF] = {
		{ 1, 11164 },
		{ 2, 10781 },			{ 17, 10784 },
		{ 3, 10788 },			{ 18, 10796 },
		{ 4, 10799 },			{ 19, 10802 },
		{ 5, 10805 },			{ 20, 10808 },
	},
}

local LEGION_GLORY_OF_THE_HERO_AC_TABLE = {	--[Glory of the Legion Hero]
	name = select(2, GetAchievementInfo(11163)),
	TableType = AC_ITTYPE,
	ExtraList = true,
	CoinTexture = "Achievement",
	[HEROIC_DIFF] = {
		{ 1, 11163, "mount225765" },
		{ 2, 10456 },			{ 17, 10457 },
		{ 3, 10458 },			{ 18, 10766 },
		{ 4, 10769 },			{ 19, 10996 },
		{ 5, 10875 },			{ 20, 10544 },
		{ 6, 10542 },			{ 21, 10543 },
		{ 7, 10554 },			{ 22, 10553 },
		{ 8, 10679 },			{ 23, 10680 },
		{ 9, 10707 },			{ 24, 10709 },
		{ 10, 10710 },			{ 25, 10711 },
		{ 11, 10413 },			{ 26, 10411 },
		{ 12, 10412 },			{ 27, 10776 },
		{ 13, 10775 },			{ 28, 10773 },
		{ 14, 10610 },			{ 29, 10611 },
	},
}

local LEGION_RAID1_AC_TABLE = {	-- [Glory of the Legion Raider]
name = select(2, GetAchievementInfo(11180)),
	TableType = AC_ITTYPE,
	ExtraList = true,
	CoinTexture = "Achievement",
	[NORMAL_DIFF] = {
		{ 1, 11180, "mount193007" },
		{ 2, 10555 },			{ 17, 10771 },
		{ 3, 10753 },			{ 18, 10830 },
		{ 4, 10663 },			{ 19, 10772 },
		{ 5, 10755 },			{ 20, 10678 },
		{ 6, 10697 },			{ 21, 10742 },
		{ 7, 10817 },			{ 22, 10851 },
		{ 8, 10754 },			{ 23, 10704 },
		{ 9, 10575 },			{ 24, 10699 },
		{ 10, 10696 },
	},
}

local LEGION_TRIAL_OF_VALOR_AC_TABLE = { -- Heroic: Trial of Valor
name = select(2, GetAchievementInfo(11426)),
	TableType = AC_ITTYPE,
	ExtraList = true,
	CoinTexture = "Achievement",
	[NORMAL_DIFF] = {
		{1, 11426 },
	}
}

local LEGION_GLORY_TOMB_RAIDER_AC_TABLE = { -- Glory of the Tomb Raider
name = select(2, GetAchievementInfo(11763)),
	TableType = AC_ITTYPE,
	ExtraList = true,
	CoinTexture = "Achievement",
	[NORMAL_DIFF] = {
		{ 1, 11763 }, -- Glory of the Tomb Raider
		{ 2, 11724 }, -- Fel Turkey!
		{ 3, 11696 }, -- Grin and Bear It
		{ 4, 11683 }, -- Bingo!
		{ 5, 11676 }, -- Five Course Seafood Buffet
		{ 17, 11675 }, -- Sky Walker
		{ 18, 11674 }, -- Great Soul, Great Purpose
		{ 19, 11773 }, -- Wax On, Wax Off
		{ 20, 11770 }, -- Dark Souls
		{ 21, 11699 }, -- Grand Fin-ale
	}
}


local LEGION_WORLD_BOSS_AC_TABLE = { 
name = select(2, GetAchievementInfo(11160)),
	TableType = AC_ITTYPE,
	ExtraList = true,
	CoinTexture = "Achievement",
	[NORMAL_DIFF] = {
		{1, 11160 }, -- Unleashed Monstrosities
	}
}

local LEGION_WORLD_BOSS_AC_TABLE2 = { 
name = select(2, GetAchievementInfo(11786)),
	TableType = AC_ITTYPE,
	ExtraList = true,
	CoinTexture = "Achievement",
	[NORMAL_DIFF] = {
		{1, 11786 }, -- Terrors of the Shore
	}
}

-- /////////////////////////////////
-- Instance
-- /////////////////////////////////
data["TheArcway"] = {
	EncounterJournalID = 726,
	MapID = 1079,
	AtlasMapID = "TheArcway",
	ContentType = DUNGEON_CONTENT,
	items = {
		{	--Ivanyr
			EncounterJournalID = 1497,
			[MYTHICD_DUNGEON_DIFF] = {
				{  1, 134467 }, -- Nether Mindsnappers
				{  2, 134501 }, -- Crackling Overcharge Chestguard
				{  3, 137398 }, -- Portable Manacracker
				{  4, 134280 }, -- Swordsinger's Wristguards
				{  5, 134269 }, -- Arcane Defender's Belt
				{  6, 134421 }, -- Ink-Smudged Handwraps
				{  7, 137397 }, -- Tunnel Trudger Footguards
				{  8, 134309 }, -- Manawracker Shoulders
				{  9, 134298 }, -- Ley Dragoon's Stompers
				{  10, 134526 }, -- Gnawed Thumb Ring
				{  11, 137399 }, -- Ivanyr's Hunger
			},
		},
		{	--Corstilax
			EncounterJournalID = 1498,
			[MYTHICD_DUNGEON_DIFF] = {
				{  1, 134424 }, -- Collar of Enclosure
				{  2, 134488 }, -- Stabilized Energy Pendant
				{  3, 137400 }, -- Coagulated Nightwell Residue
				{  4, 137402 }, -- Cleansing Isotope
				{  5, 134453 }, -- Spaulders of Aberrant Inhibition
				{  6, 134522 }, -- Detention Wristclamps
				{  7, 134463 }, -- Decontaminated Chain Tunic
				{  8, 134402 }, -- Cape of Rigid Order
				{  9, 137403 }, -- Quarantine Catalyst
			},
		},
		{	--General Xakal
			EncounterJournalID = 1499,
			[MYTHICD_DUNGEON_DIFF] = {
				{  1, 137407 }, -- Sealed Fel Fissure
				{  2, 134396 }, -- Netherwhisper Slippers
				{  3, 134533 }, -- Ring of Looming Menace
				{  4, 134387 }, -- Mardum Chain Helm
				{  5, 134449 }, -- Bloodclaw Leggings
				{  6, 137406 }, -- Terrorbound Nexus
				{  7, 137408 }, -- Xakal's Determination
				{  8, 134359 }, -- Portalguard Legplates
				{  9, 137404 }, -- Legwraps of Reverberating Shadows
				{  10, 134373 }, -- Felbat Leather Vest
				{  11, 137405 }, -- Remorseless Chain Armbands
				{  12, 134509 }, -- Fists of the Legion
			},
		},
		{	--Nal'tira
			EncounterJournalID = 1500,
			[MYTHICD_DUNGEON_DIFF] = {
				{  1, 137409 }, -- Manafang Waistguard
				{  2, 137411 }, -- Nal'tira's Venom Gland
				{  3, 137410 }, -- Greathelm of Barbed Chelicerae
				{  4, 137412 }, -- Fistful of Eyes
				{  5, 133766 }, -- Nether Anti-Toxin
				{  6, 134472 }, -- Arcane Exterminator's Shoulderguards
				{  7, 134410 }, -- Cloak of Mana-Spun Silk
				{  8, 134540 }, -- Ring of Twisted Webbing
				{  9, 134435 }, -- Tunnel Fiend Bracers
			},
		},
		{	--Advisor Vandros
			EncounterJournalID = 1501,
			[MYTHICD_DUNGEON_DIFF] = {
				{  1, 137417 }, -- Treads of Fates Entwined
				{  2, 134304 }, -- Manawracker Crown
				{  3, 134286 }, -- Swordsinger's Shoulders
				{  4, 134518 }, -- Frozen Pendulum Shoulderguards
				{  5, 134475 }, -- Mute Erasure Legguards
				{  6, 134267 }, -- Arcane Defender's Breastplate
				{  7, 137419 }, -- Chrono Shard
				{  8, 137421 }, -- Accelerating Torrent
				{  9, 137413 }, -- Time-Breached Waistband
				{  10, 134413 }, -- Fluxflow Robes
				{  11, 134297 }, -- Ley Dragoon's Gloves
				{  12, 134444 }, -- Mana-Lanced Gloves
				{  13, 137416 }, -- Chain of Causal Links
				{  14, 137418 }, -- Erratically Ticking Talisman
				{  15, 137420 }, -- Split Second
				{  16, 137415 }, -- Gaze of Fleeting Hours
			},
		},
	}
}

data["AssaultOnVioletHold"] = {
	EncounterJournalID = 777,
	MapID = 1066,
	AtlasMapID = "AssaultonVioletHold",
	ContentType = DUNGEON_CONTENT,
	items = {
		{	--Festerface
			EncounterJournalID = 1693,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 137437 }, -- Slimeflow Breastplate
				{  2, 134454 }, -- Spaulders of Unstable Experiments
				{  3, 137479 }, -- Cowl of Promising News
				{  4, 137436 }, -- Pustulous Girdle
				{  5, 137438 }, -- Band of Decaying Rubies
				{  6, 137439 }, -- Tiny Oozeling in a Jar
				{  7, 134414 }, -- Fetid Gutcover Apron
				{  8, 137465 }, -- Festerface's Rotted Gut
				{  9, 137434 }, -- Split-Vein Bracers
				{  10, 137435 }, -- Blightbile Waistband
				{  11, 134468 }, -- Gloves of Flesh-Shaping
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 125, "ac9023" },
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
		},
		{	--Shivermaw
			EncounterJournalID = 1694,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 134411 }, -- Iceblood Shroud
				{  2, 134445 }, -- Frostcarver Grips
				{  3, 134434 }, -- Cinch of Freezing Fog
				{  4, 137466 }, -- Frostwyrm Heart
				{  5, 137468 }, -- Bonecrushing Hail
				{  6, 137440 }, -- Shivermaw's Jawbone
				{  7, 134476 }, -- Wyrmwing Kilt
				{  8, 134523 }, -- Etched Dragonbone Warboots
				{  9, 134493 }, -- Band of Crystalline Bone
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
		},
		{	--Blood Princess Thalena
			EncounterJournalID = 1702,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 134422 }, -- Satin Throatclutchers
				{  2, 137471 }, -- Drop of True Blood
				{  3, 137460 }, -- Constricting Chain Harness
				{  4, 137462 }, -- Jewel of Insatiable Desire
				{  5, 134404 }, -- Stole of Malefic Repose
				{  6, 134457 }, -- Sash of the Twilight Princess
				{  7, 137461 }, -- Breathless Choker
				{  8, 137478 }, -- Reflection of Sorrow
				{  9, 134516 }, -- Tassets of Ravenous Euphoria
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 120, "ac9551" },
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
		},
		{	--Mindflayer Kaahrj
			EncounterJournalID = 1686,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 137433 }, -- Obelisk of the Void
				{  2, 134479 }, -- Mantle of the Abyss
				{  3, 134439 }, -- Tunic of the Underworld
				{  4, 137464 }, -- Tendril of Darkness
				{  5, 137431 }, -- Despair-Bound Armplates
				{  6, 134498 }, -- Chain of a Hundred Maws
				{  7, 137432 }, -- Ring of Mind-Shielding
				{  8, 134425 }, -- Hood of Ancient Evil
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 217, "ac10080" },
			},
		},
		{	--Millificent Manastorm
			EncounterJournalID = 1688,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 137469 }, -- Thorium-Plated Egg
				{  2, 137441 }, -- Millificent's Turboview Specs
				{  3, 137443 }, -- Mithril Melon Vault
				{  4, 137445 }, -- Insurmountable Skullfortress
				{  5, 137444 }, -- Plasma-Drilled Steel Toes
				{  6, 137470 }, -- Rocket Chicken Rocket Fuel
				{  7, 134502 }, -- Exo-Mesh Carpalform Armplates Mk. VII
				{  8, 134534 }, -- Dingy Wedding Band
				{  9, 137446 }, -- Elementium Bomb Squirrel Generator
				{  10, 134430 }, -- Magnificent Aeroglide Shoulderpads
				{  11, 134450 }, -- D-Lux Slipstream Pants
				{  12, 137442 }, -- Compact Trifold Wristbands
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 217, "ac10080" },
			},
		},
		{	--Anub'esset
			EncounterJournalID = 1696,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 137424 }, -- Burrow-Dweller Leggings
				{  2, 137428 }, -- Chestguard of Ravaged Chitin
				{  3, 137430 }, -- Impenetrable Nerubian Husk
				{  4, 134489 }, -- Seal of Malicious Deceit
				{  5, 137425 }, -- Cryptwalker Bracers
				{  6, 137427 }, -- Corpse Feast Headwrap
				{  7, 137429 }, -- Serrated Mandible Grips
				{  8, 134506 }, -- Legplates of the Swarm
				{  9, 134418 }, -- Scarab-Caller Grips
				{  10, 134485 }, -- Cuffs of the Nerubian Empire
				{  11, 137463 }, -- Fealty of Nerub
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 217, "ac10080" },
			},
		},		
		{	--Sael'orn
			EncounterJournalID = 1697,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 137452 }, -- Thrumming Gossamer
				{  2, 134527 }, -- Loop of Eightfold Eyes
				{  3, 137449 }, -- Wicked Broodmother's Chestguard
				{  4, 134357 }, -- Portalguard Waistplate
				{  5, 137473 }, -- Phase Spider Mandible
				{  6, 137450 }, -- Leggings of Acidic Venom
				{  7, 134482 }, -- Cinch of Frozen Fear
				{  8, 134393 }, -- Netherwhisper Gloves
				{  9, 134521 }, -- Dread-Stricken Shoulderguards
				{  10, 137474 }, -- Loyalty to the Matriarch
				{  11, 137447 }, -- Lair Matron's Spaulders
				{  12, 137451 }, -- Vision of the Spider Queen
				{  13, 134541 }, -- Tightweb Choker
				{  14, 134390 }, -- Mardum Chain Vest
				{  15, 134371 }, -- Felbat Leather Gloves
				{  16, 137448 }, -- Toxin-Stitched Footwraps
				{  17, 134436 }, -- Armbands of Slaughter
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				-- { 217, "ac10080" },
			},
		},
		{	--Fel Lord Betrug
			EncounterJournalID = 1711,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 137456 }, -- Belt of Mighty Links
				{  2, 134360 }, -- Portalguard Shoulders
				{  3, 134395 }, -- Netherwhisper Robes
				{  4, 134368 }, -- Felbat Leather Wristwraps
				{  5, 137472 }, -- Betrug's Vigor
				{  6, 137476 }, -- Brand of Tyranny
				{  7, 134446 }, -- Vigilant Bondbreaker Headdress
				{  8, 137457 }, -- Chestplate of the Obstinate Conqueror
				{  9, 134466 }, -- Begrudging Trudgers
				{  10, 137454 }, -- Footguards of Stayed Execution
				{  11, 134389 }, -- Mardum Chain Pauldrons
				{  12, 137455 }, -- Spaulders of Tense Sinew
				{  13, 137459 }, -- Chaos Talisman
				{  14, 137458 }, -- Chaos-Forged Necklace
				{  15, 134407 }, -- Rugged Marauder Cape
				{  16, 134515 }, -- Greaves of Ruinous Dominion
				{  17, 137453 }, -- Legwraps of Rampant Turmoil
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 217, "ac10080" },
			},
		},
--[[		{	--Challenge Mode Gear
			name = AL["Challenge Mode Gear"],
			ExtraList = true,
			[NORMAL_DIFF] = "AtlasLoot_Collections:CMGEAR:1",
		},
]]
		LEGION_DUNGEON_HERO_AC_TABLE,
		LEGION_GLORY_OF_THE_HERO_AC_TABLE,
	}
}

data["BlackRookHold"] = {
	EncounterJournalID = 740,
	MapID = 1081,
	AtlasMapID = "BlackRookHoldA",
	ContentType = DUNGEON_CONTENT,
	items = {
		{	--The Amalgam of Souls
			EncounterJournalID = 1518,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 134437 }, -- Harrowing Soulspun Bracers
				{  2, 134469 }, -- Midnight Reaper Handwraps
				{  3, 139241 }, -- Rook Footman's Warboots
				{  4, 139245 }, -- Shadow Archer's Spaulders
				{  5, 136714 }, -- Amalgam's Seventh Spine
				{  6, 134442 }, -- Tooled Rivermoor Boots
				{  7, 136977 }, -- Shadowfeather Shawl
				{  8, 136719 }, -- Curdled Soul Essence
				{  9, 139246 }, -- Ravencourt Formal Robes
				{  10, 139242 }, -- Raven's Veil Gloves
				{  11, 137270 }, -- Howling Echoes
				{  12, 136976 }, -- Etheldrin's Breastplate
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
		},
		{	--Illysanna Ravencrest
			EncounterJournalID = 1653,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 136978 }, -- Ember of Nullification
				{  2, 134490 }, -- Ring of Contempt
				{  3, 134419 }, -- Slippers of Heedless Sacrifice
				{  4, 134440 }, -- Soulstarve Hood
				{  5, 134412 }, -- Cloak of Unwavering Loyalty
				{  6, 134519 }, -- Ravencrest Bonecrush Gauntlets
				{  7, 136724 }, -- Soul-Torn Fury Cinch
				{  8, 136720 }, -- Snapped Emerald Pendant
				{  9, 136769 }, -- Ravencrest's Wrath
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 116, "ac8993" },
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
		},
		{	--Smashspite the Hateful
			EncounterJournalID = 1664,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 134362 }, -- Portalguard Wristguard
				{  2, 136721 }, -- Mo'arg Eyepatch
				{  3, 134507 }, -- Leadfoot Earthshakers
				{  4, 134391 }, -- Netherwhisper Cinch
				{  5, 134528 }, -- Band of Callous Dominance
				{  6, 134483 }, -- Fel-Hammered Greaves
				{  7, 136979 }, -- Shorn Batbrood Cuffs
				{  8, 136715 }, -- Spiked Counterweight
				{  9, 134373 }, -- Felbat Leather Vest
				{  10, 134390 }, -- Mardum Chain Vest
				{  11, 134426 }, -- Collar of Raking Claws
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
		},
		{	--Lord Kur'talos Ravencrest
			EncounterJournalID = 1672,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 136770 }, -- Drape of the Raven Lord
				{  2, 136716 }, -- Caged Horror
				{  3, 139243 }, -- Raven's Veil Belt
				{  4, 139247 }, -- Ravencourt Formal Mantle
				{  5, 134384 }, -- Mardum Chain Wristclamp
				{  6, 136717 }, -- Absolved Ravencrest Brooch
				{  7, 134431 }, -- Latosius's Blasting Gloves
				{  8, 139240 }, -- Rook Footman's Legplates
				{  9, 139244 }, -- Shadow Archer's Helm
				{  10, 134358 }, -- Portalguard Helm
				{  11, 136718 }, -- Mark of Varo'then
				{  12, 134370 }, -- Felbat Leather Leggings
				{  13, 134510 }, -- Pauldrons of Ancient Command
				{  14, 134394 }, -- Netherwhisper Leggings
				{  15, 134477 }, -- Ravencrest's Unerring Striders
				{  16, 134499 }, -- Raven Filigree Pendant
				{  17, 134451 }, -- Legguards of Endless Horrors
				{  18, 137272 }, -- Cruelty of Dantalionax
				--{ 220, "ac9037" },
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 212, "113682:0", false, [ATLASLOOT_IT_FILTERIGNORE] = true },	-- Core of Flame
				--{ 221, "ac9046" },
				--{ 222, "ac9005" },
				--{ 223, "ac9008" },
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 221, "ac10076" },
			},
		},
--[[		{	--Challenge Mode Gear
			name = AL["Challenge Mode Gear"],
			ExtraList = true,
			[NORMAL_DIFF] = "AtlasLoot_Collections:CMGEAR:1",
		},
]]		
		LEGION_DUNGEON_HERO_AC_TABLE,
		LEGION_GLORY_OF_THE_HERO_AC_TABLE,
	}
}

-- Cathedral of Eternal Night 
data["CathedralofEternalNight"] = {
	EncounterJournalID = 900,
	MapID = 1146,
	ItemBaseLvl = 845,
	AtlasMapID = "CathedralofEternalNightA",
	ContentType = DUNGEON_CONTENT,
	items = {
		{	-- Agronox
			EncounterJournalID = 1905,
			[HEROIC_DUNGEON_DIFF] = {
				{ 1 , 144458 }, -- Agronax's Unsullied Heartwood
				{ 2 , 144469 }, -- Caretaker's Budding Mantle
				{ 3 , 144491 }, -- Choking Vine Bindings
				{ 4 , 144490 }, -- Corruption-Fused Stompers
				{ 5 , 144468 }, -- Felpruner's Shroud
				{ 6 , 144470 }, -- Grovetender's Handwraps
				{ 7 , 144459 }, -- Knot of Fel
				{ 8 , 144497 }, -- Petrified Husk Girdle
				{ 9 , 144477 }, -- Splinters of Agronax
				{ 10, 144483 }, -- Spore-Coated Vest
				{ 11, 144498 }, -- Vambraces of Fel Crust
			},
			[MYTHICD_DUNGEON_DIFF] = HEROIC_DUNGEON_DIFF,
		},
		{	-- Thrashbite the Scornful
			EncounterJournalID = 1906,
			[HEROIC_DUNGEON_DIFF] = {
				{ 1 , 144492 }, -- Chain-Draped Gauntlets
				{ 2 , 144482 }, -- Fel-Oiled Infernal Machine
				{ 3 , 144462 }, -- Fel-Tempered Link
				{ 4 , 144460 }, -- Fury of the Scorned
				{ 5 , 144493 }, -- Link-Lashed Spaulders
				{ 6 , 144479 }, -- Master Thrasher's Lockcollar
				{ 7 , 144485 }, -- Mo'arg Heavyweight's Wristwraps
				{ 8 , 144471 }, -- Pulverizing Felsoles
				{ 9 , 144484 }, -- Tattered Scornful Leggings
				{ 10, 144499 }, -- Tenderized Breastplate
				{ 11, 144472 }, -- Thrashbite's Cummerbund
				{ 12, 144461 }, -- Thrashbite's Spite
			},
			[MYTHICD_DUNGEON_DIFF] = HEROIC_DUNGEON_DIFF,
		},
		{	-- Domatrax
			EncounterJournalID = 1904,
			[HEROIC_DUNGEON_DIFF] = {
				{ 1 , 144496 }, -- Burning Chain Waistguard
				{ 2 , 144476 }, -- Cloak of the Unending Assault
				{ 3 , 144475 }, -- Dark Mistress' Cuffs
				{ 4 , 144495 }, -- Domatrax's Chain Hauberk
				{ 5 , 144488 }, -- Feaster Hide Gloves
				{ 6 , 144466 }, -- Gore-Flecked Feaster Fang
				{ 7 , 144503 }, -- Helm of Domatrax
				{ 8 , 144481 }, -- Ring of Fel Domination
				{ 9 , 144474 }, -- Sheer Felwoven Hosiery
				{ 10, 144489 }, -- Shoulderguards of Legion Domination
				{ 11, 144500 }, -- Two-Toed Thrashstompers
				{ 12, 144467 }, -- Vial of Eternal Moon
			},
			[MYTHICD_DUNGEON_DIFF] = HEROIC_DUNGEON_DIFF,
		},
		{	-- Mephistroth
			EncounterJournalID = 1878,
			[HEROIC_DUNGEON_DIFF] = {
				{ 1 , 144478 }, -- Band of Dark Solitude
				{ 2 , 144486 }, -- Cerulean Shadowfade Belt
				{ 3 , 144501 }, -- Dread Commander's Pauldrons
				{ 4 , 144480 }, -- Dreadstone of Endless Shadows
				{ 5 , 144465 }, -- Essence of the Legion Tempest
				{ 6 , 144494 }, -- Imposing Dreadsoul Headgear
				{ 7 , 144464 }, -- Mephistroth's Nail
				{ 8 , 144473 }, -- Nathrezim Acolyte's Robes
				{ 9 , 144502 }, -- Shadowed Grips of the Nathrezim
				{ 10, 144463 }, -- Shard of Kaldorei Stained Glass
				{ 11, 144487 }, -- Treads of Creeping Shadows
			},
			[MYTHICD_DUNGEON_DIFF] = HEROIC_DUNGEON_DIFF,
		},
	},
}

data["CourtOfStars"] = {
	EncounterJournalID = 800,
	MapID = 1087,
	AtlasMapID = "CourtofStarsA",
	ContentType = DUNGEON_CONTENT,
	items = {
		{	--Patrol Captain Gerdo
			EncounterJournalID = 1718,
			[MYTHICD_DUNGEON_DIFF] = {
				{  1, 137482 }, -- Duskwatch Guard's Boots
				{  2, 137484 }, -- Flask of the Solemn Night
				{  3, 134308 }, -- Manawracker Sandals
				{  4, 134280 }, -- Swordsinger's Wristguards
				{  5, 137483 }, -- Cape of the Duskwatch
				{  6, 137490 }, -- Self-Forging Credentials
				{  7, 134480 }, -- Epaulets of Deceitful Intent
				{  8, 134296 }, -- Ley Dragoon's Wristbraces
				{  9, 134268 }, -- Arcane Defender's Gauntlets
				{  10, 137480 }, -- Guileful Intruder Handguards
				{  11, 134415 }, -- Arcanist's Resonant Robes
			},
		},
		{	--Talixae Flamewreath
			EncounterJournalID = 1719,
			[MYTHICD_DUNGEON_DIFF] = {
				{  1, 134392 }, -- Netherwhisper Hood
				{  2, 134529 }, -- Chain of Scorched Bones
				{  3, 134503 }, -- Inferno Breastplate
				{  4, 134385 }, -- Mardum Chain Gloves
				{  5, 137492 }, -- Flamewreath Spark
				{  6, 134374 }, -- Felbat Leather Pauldrons
				{  7, 137485 }, -- Infernal Writ
				{  8, 134460 }, -- Fevermelt Legguards
				{  9, 137491 }, -- Felsworn Covenant
				{  10, 137488 }, -- Cord of Wicked Pyromania
				{  11, 134360 }, -- Portalguard Shoulders
				{  12, 134473 }, -- Collar of Fiery Allegiance
			},
		},
		{	--Advisor Melandrus
			EncounterJournalID = 1720,
			[MYTHICD_DUNGEON_DIFF] = {
				{  1, 137487 }, -- Strand of the Stars
				{  2, 134298 }, -- Ley Dragoon's Stompers
				{  3, 137495 }, -- Crux of Blind Faith
				{  4, 137499 }, -- Roaring Breeze Waistguard
				{  5, 134310 }, -- Manawracker Bindings
				{  6, 134287 }, -- Swordsinger's Belt
				{  7, 137496 }, -- Suramar Magistrate Leggings
				{  8, 134447 }, -- Veil of Unseen Strikes
				{  9, 137489 }, -- Arcane-Bound Gale Chain
				{  10, 137493 }, -- Edge of the First Blade
				{  11, 137497 }, -- Footpads of the Swift Balestra
				{  12, 134432 }, -- Amice of the Unfurling Tempest
				{  13, 137486 }, -- Windscar Whetstone
				{  14, 137498 }, -- Luminous Bladesworn Hauberk
				{  15, 134542 }, -- Jeweled Signet of Melandrus
				{  16, 134271 }, -- Arcane Defender's Pants
				{  17, 134513 }, -- Helmet of Reverent Loyalty
			},
		},
--[[		
		{	--Challenge Mode Gear
			name = AL["Challenge Mode Gear"],
			ExtraList = true,
			[NORMAL_DIFF] = "AtlasLoot_Collections:CMGEAR:1",
		},
]]		
		LEGION_DUNGEON_HERO_AC_TABLE,
		LEGION_GLORY_OF_THE_HERO_AC_TABLE,
	}
}

data["DarkheartThicket"] = {
	EncounterJournalID = 762,
	MapID = 1067,
	AtlasMapID = "DarkheartThicket",
	ContentType = DUNGEON_CONTENT,
	items = {
		{	--Archdruid Glaidalis
			EncounterJournalID = 1654,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 137302 }, -- Misshapen Abomination Heart
				{  2, 134520 }, -- Thornscar Wristguards
				{  3, 134487 }, -- Arch-Druid's Tainted Seal
				{  4, 139086 }, -- Night Dreamer Crest
				{  5, 139058 }, -- Nightsfall Helmet
				{  6, 137301 }, -- Corrupted Starlight
				{  7, 139077 }, -- Bramblemail Belt
				{  8, 134429 }, -- Grove Darkener's Treads
				{  9, 134423 }, -- Poisonroot Belt
				{  10, 139071 }, -- Tranquil Bough Vest
				{  11, 137300 }, -- Gloves of Wretched Lesions
				{  12, 137303 }, -- Touch of Nightfall
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 130, "ac9083" },
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
		},
		{	--Oakheart
			EncounterJournalID = 1655,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 134452 }, -- Epaulets of Dessicated Foliage
				{  2, 137304 }, -- Oakheart's Trunkwarmers
				{  3, 137306 }, -- Oakheart's Gnarled Root
				{  4, 137308 }, -- Clotted Sap of the Grove
				{  5, 121325 }, -- Terrorweave Gloves
				{  6, 137305 }, -- Blighted Grasp Bracers
				{  7, 137307 }, -- Corrupted Knot
				{  8, 121319 }, -- Vilescale Helm
				{  9, 121299 }, -- Dreadhide Girdle
				{  10, 134531 }, -- Band of Twisted Bark
				{  11, 121280 }, -- Wracksoul Legplates
				{  12, 134500 }, -- Breastplate of Preservation
				--{ 216, "ac9038" },
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 217, "ac9047" },
				--{ 218, "ac9082" },
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 217, "ac10079" },
			},
		},
		{	--Dresaron
			EncounterJournalID = 1656,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 139089 }, -- Night Dreamer Robe
				{  2, 137310 }, -- Greatbelt of Disruption
				{  3, 139082 }, -- Bramblemail Greaves
				{  4, 134464 }, -- Whelp Handler's Lined Boots
				{  5, 139056 }, -- Nightsfall Gauntlets
				{  6, 137312 }, -- Nightmare Egg Shell
				{  7, 137309 }, -- Slipstream Shoulderpads
				{  8, 137311 }, -- Chain of the Green Flight
				{  9, 137313 }, -- Roiling Fog
				{  10, 139070 }, -- Tranquil Bough Hood
				{  11, 134461 }, -- Thermal Bindings
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
		},
		{	--Shade of Xavius
			EncounterJournalID = 1657,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 137317 }, -- Xavius' Mad Whispers
				{  2, 121316 }, -- Vilescale Bracers
				{  3, 134504 }, -- Curserunner Soulcrushers
				{  4, 121293 }, -- Dreadhide Boots
				{  5, 121326 }, -- Terrorweave Leggings
				{  6, 137314 }, -- Wristbands of Cursed Torment
				{  7, 137322 }, -- Mantle of the Resolute Champion
				{  8, 121276 }, -- Wracksoul Chestplate
				{  9, 137315 }, -- Writhing Heart of Darkness
				{  10, 134405 }, -- Cloak of Fading Echoes
				{  11, 134537 }, -- Signet of the Highborne Magi
				{  12, 134448 }, -- Ashen Satyr Leggings
				{  13, 137321 }, -- Burning Sky Pauldrons
				{  14, 137316 }, -- Torch of Shaladrassil
				{  15, 137320 }, -- Gloves of Vile Defiance
				{  16, 137319 }, -- Paranoid Sprinters
				{  17, 134462 }, -- Dream Bolstered Chestguard
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
		},
--[[
		{	--Challenge Mode Gear
			name = AL["Challenge Mode Gear"],
			ExtraList = true,
			[NORMAL_DIFF] = "AtlasLoot_Collections:CMGEAR:1",
		},
]]		
		LEGION_DUNGEON_HERO_AC_TABLE,
		LEGION_GLORY_OF_THE_HERO_AC_TABLE,
	}
}

data["EyeOfAzshara"] = {
	EncounterJournalID = 716,
	MapID = 1046,
	AtlasMapID = "EyeofAzshara",
	ContentType = DUNGEON_CONTENT,
	items = {
		{	--Warlord Parjesh
			EncounterJournalID = 1480,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 137362 }, -- Parjesh's Medallion
				{  2, 134484 }, -- Crestrider Conduit Bracers
				{  3, 134261 }, -- Seawitch Gloves
				{  4, 134492 }, -- Hatecoil Commander's Amulet
				{  5, 137361 }, -- Roaring Shellbreaker Greatbelt
				{  6, 137363 }, -- Bloodied Spearhead
				{  7, 134441 }, -- Shellshock Footguards
				{  8, 134251 }, -- Sea Stalker's Cinch
				{  9, 134223 }, -- Coralplate Chestguard
				{  10, 137360 }, -- Shoulderpads of Crashing Waves
				{  11, 134240 }, -- Brinewashed Leather Cowl
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 220, "ac9054" },
				--{ 221, "ac9026" },
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 220, "ac10084" },
			},
		},
		{	--Lady Hatecoil
			EncounterJournalID = 1490,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 137364 }, -- Crashing Oceantide Mantle
				{  2, 134471 }, -- Helm of Endless Dunes
				{  3, 134263 }, -- Seawitch Robes
				{  4, 134505 }, -- Horizon Line Warboots
				{  5, 137365 }, -- Condensed Saltsea Globule
				{  6, 134230 }, -- Coralplate Wristguard
				{  7, 137367 }, -- Stormsinger Fulmination Charge
				{  8, 134433 }, -- Cord of the Sea-Caller
				{  9, 134253 }, -- Sea Stalker's Gloves
				{  10, 134238 }, -- Brinewashed Leather Pants
				{  11, 134525 }, -- Seal of the Nazjatar Empire
				{  12, 137366 }, -- Gift of the Ocean Empress
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 124, "ac9018" },
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
		},
		{	--King Deepbeard
			EncounterJournalID = 1491,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 134514 }, -- Keelhauler Legplates
				{  2, 134456 }, -- Taut Halyard Waistband
				{  3, 137368 }, -- Breastplate of Ten Lashes
				{  4, 137370 }, -- Heart of the Sea
				{  5, 134539 }, -- Braided Silver Ring
				{  6, 134406 }, -- Mainsail Cloak
				{  7, 137369 }, -- Giant Ornamental Pearl
				{  8, 137371 }, -- Tumultuous Aftershock
				{  9, 134428 }, -- Rising Ocean Legwraps
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
		},
		{	--Serpentrix
			EncounterJournalID = 1479,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 137377 }, -- Serpentrix's Guile
				{  2, 137372 }, -- Wristbands of the Swirling Deeps
				{  3, 134239 }, -- Brinewashed Leather Grips
				{  4, 134256 }, -- Sea Stalker's Leggings
				{  5, 134438 }, -- Tunic of the Pitiless Monstrosity
				{  6, 134260 }, -- Seawitch Hood
				{  7, 134508 }, -- Stormwake Handguards
				{  8, 134465 }, -- Hydra Scale Sabatons
				{  9, 137373 }, -- Tempered Egg of Serpentrix
				{  10, 137375 }, -- Blazing Hydra Flame Sac
				{  11, 134228 }, -- Coralplate Pauldrons
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 120, "ac9025" },
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
		},
		{	--Wrath of Azshara
			EncounterJournalID = 1492,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 134497 }, -- Stormcharged Choker
				{  2, 134259 }, -- Seawitch Cinch
				{  3, 137381 }, -- Pact of Vengeful Service
				{  4, 134237 }, -- Brinewashed Leather Boots
				{  5, 137379 }, -- Tempestbinder's Crystal
				{  6, 134225 }, -- Coralplate Girdle
				{  7, 137378 }, -- Bottled Hurricane
				{  8, 137380 }, -- Rage of the Tides
				{  9, 134532 }, -- Band of Fused Coral
				{  10, 134459 }, -- Cuffs of the Arcane Storm
				{  11, 134417 }, -- Slippers of Martyrdom
				{  12, 134478 }, -- Thundercrush Pauldrons
				{  13, 134255 }, -- Sea Stalker's Hood
				{  14, 134512 }, -- Casque of the Deep
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 220, "ac9054" },
				--{ 221, "ac9026" },
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 220, "ac10084" },
			},
		},
--[[
		{	--Challenge Mode Gear
			name = AL["Challenge Mode Gear"],
			ExtraList = true,
			[NORMAL_DIFF] = "AtlasLoot_Collections:CMGEAR:1",
		},
]]
		LEGION_DUNGEON_HERO_AC_TABLE,
		LEGION_GLORY_OF_THE_HERO_AC_TABLE,
	}
}

data["HallsOfValor"] = {
	EncounterJournalID = 721,
	MapID = 1041,
	AtlasMapID = "HallsofValorA",
	ContentType = DUNGEON_CONTENT,
	items = {
		{	--Hymdall
			EncounterJournalID = 1485,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 133642 }, -- Horn of Valor
				{  2, 134216 }, -- Bonespeaker Cowl
				{  3, 136774 }, -- Cushioned Treads of Glory
				{  4, 133628 }, -- Battleborne Sentinel Gauntlets
				{  5, 134194 }, -- Biornskin Leggings
				{  6, 136973 }, -- Burden of Vigilance
				{  7, 134213 }, -- Tideskorn Mantle
				{  8, 133621 }, -- Adorned Guardian's Bracers
				{  9, 134179 }, -- Skoldiir Breastplate
				{  10, 133805 }, -- Thundercaller's Chain
				{  11, 133763 }, -- Key to the Halls
				--{ 221, "114780:0", false, [ATLASLOOT_IT_FILTERIGNORE] = true },	-- Pure Solium Band
				--{ 223, "ac8843" },
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 224, "ac8844" },
				--{ 225, "ac9036" },
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 224, "ac10081" },
			},
		},
		{	--Hyrja
			EncounterJournalID = 1486,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 136974 }, -- Empowerment of Thunder
				{  2, 134186 }, -- Skoldiir Bracers
				{  3, 133620 }, -- Amice of the Enlightened
				{  4, 133622 }, -- Thunderfused Val'kyr Hauberk
				{  5, 134209 }, -- Tideskorn Gauntlets
				{  6, 134196 }, -- Biornskin Hood
				{  7, 133613 }, -- Solsten's Arcing Runecord
				{  8, 134219 }, -- Bonespeaker Robes
				{  9, 136771 }, -- Eyir's Blessing
				{  10, 133646 }, -- Mote of Sanctification
				{  11, 133679 }, -- Val'kyr Ascension Signet
				{  12, 136772 }, -- Valkyra Protector Greatboots
				--{ 221, "114780:0", false, [ATLASLOOT_IT_FILTERIGNORE] = true },	-- Pure Solium Band
				--{ 223, "ac8843" },
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 224, "ac8844" },
				--{ 225, "ac9036" },
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 224, "ac10081" },
			},
		},
		{	--Fenryr
			EncounterJournalID = 1487,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 133639 }, -- Goldscar Pelt
				{  2, 133626 }, -- Runebands of the Worthy
				{  3, 136975 }, -- Hunger of the Pack
				{  4, 136773 }, -- Greatbelt of Alpha Dominance
				{  5, 133615 }, -- Hide of Fenryr
				{  6, 133609 }, -- Silken Bloodscent Gloves
				{  7, 133687 }, -- Fenryr's Bloodstained Fang
				{  8, 133633 }, -- Wolfstride Pendant
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 118, "ac9033" },
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
		},
		{	--God-King Skovald
			EncounterJournalID = 1488,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 134182 }, -- Skoldiir Helm
				{  2, 133764 }, -- Ragnarok Ember
				{  3, 134222 }, -- Bonespeaker Bracers
				{  4, 133641 }, -- Eye of Skovald
				{  5, 136778 }, -- Skovald's Resolve
				{  6, 133630 }, -- Greaves of the God-King
				{  7, 133617 }, -- Cruel Vice Grips
				{  8, 133638 }, -- Woe-Bearer's Band
				{  9, 133623 }, -- Felstep Footguards
				{  10, 134193 }, -- Biornskin Moccasins
				{  11, 136775 }, -- Infernal Mantle of Conquest
				{  12, 134212 }, -- Tideskorn Leggings
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
		},
		{	--Odyn
			EncounterJournalID = 1489,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 139281 }, -- Glory Seeker's Helm
				{  2, 133767 }, -- Pendant of the Stormforger
				{  3, 133647 }, -- Gift of Radiance
				{  4, 133686 }, -- Stormforged Inferno
				{  5, 134217 }, -- Bonespeaker Gloves
				{  6, 139282 }, -- Solid Gold Bracelets
				{  7, 133765 }, -- Cape of Valarjar Courage
				{  8, 136776 }, -- Bjorn's Hunting Strap
				{  9, 134207 }, -- Tideskorn Cinch
				{  10, 134180 }, -- Skoldiir Gauntlets
				{  11, 134192 }, -- Biornskin Bracer
				{  12, 139280 }, -- Treads of Light
				{  13, 136777 }, -- Collar of Honorable Exultation
				{  14, 133685 }, -- Odyn's Boon
				{  15, 133631 }, -- Pauldrons of the All-Father
				{  16, 133610 }, -- Leggings of Swirling Runes
				{  17, 139283 }, -- Wristbands of Magnificent Splendor
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 120, "ac9035" },
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
		},
--[[		
		{	--Challenge Mode Gear
			name = AL["Challenge Mode Gear"],
			ExtraList = true,
			[NORMAL_DIFF] = "AtlasLoot_Collections:CMGEAR:1",
		},
]]
		LEGION_DUNGEON_HERO_AC_TABLE,
		LEGION_GLORY_OF_THE_HERO_AC_TABLE,
	}
}

data["MawOfSouls"] = {
	EncounterJournalID = 727,
	MapID = 1042,
	AtlasMapID = "MawofSoulsA",
	ContentType = DUNGEON_CONTENT,
	items = {
		{	--Ymiron, the Fallen King
			EncounterJournalID = 1502,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 133644 }, -- Memento of Angerboda
				{  2, 133616 }, -- Legwraps of Unworthy Souls
				{  3, 133637 }, -- Utgarde Royal Signet
				{  4, 134179 }, -- Skoldiir Breastplate
				{  5, 133629 }, -- Crown of Fallen Kings
				{  6, 134210 }, -- Tideskorn Sabatons
				{  7, 134217 }, -- Bonespeaker Gloves
				{  8, 133682 }, -- Northern Gale
				{  9, 137326 }, -- Fragmented Meteorite Whetstone
				{  10, 134199 }, -- Biornskin Belt
				{  11, 133625 }, -- Shoulderguards of Bane
				{  12, 133614 }, -- Frost-Stricken Cuffs
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 120, "ac9493" },
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
		},
		{	--Harbaron
			EncounterJournalID = 1512,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 134197 }, -- Biornskin Vest
				{  2, 133768 }, -- Harbaron's Tether
				{  3, 137325 }, -- Afterlife Manacles
				{  4, 137327 }, -- Relinquishing Grip of Helheim
				{  5, 134211 }, -- Tideskorn Coif
				{  6, 134183 }, -- Skoldiir Legguards
				{  7, 133645 }, -- Naglfar Fare
				{  8, 133632 }, -- Void-Touched Wristplates
				{  9, 137324 }, -- Bleak Underworld Treads
				{  10, 133771 }, -- Seacursed Wrap
				{  11, 134218 }, -- Bonespeaker Leggings
				{  12, 133611 }, -- Soul-Stitched Robes
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 120, "ac9017" },
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
		},
		{	--Helya
			EncounterJournalID = 1663,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 133608 }, -- Mistbound Helarjar Footwraps
				{  2, 137332 }, -- Mantle of the Dark Sea
				{  3, 134221 }, -- Bonespeaker Mantle
				{  4, 133636 }, -- Brysngamen, Torc of Helheim
				{  5, 137329 }, -- Figurehead of the Naglfar
				{  6, 137333 }, -- Seaworthy Deck Hands
				{  7, 133683 }, -- Seacursed Mist
				{  8, 134214 }, -- Tideskorn Vest
				{  9, 134195 }, -- Biornskin Gloves
				{  10, 133769 }, -- Tempered Seaborne Leggings
				{  11, 133618 }, -- Kraken Hide Helm
				{  12, 133684 }, -- Screams of the Unworthy
				{  13, 134184 }, -- Skoldiir Shoulderguards
				{  14, 133634 }, -- Grasping Tentacle Loop
				{  15, 137331 }, -- Belt of Eternal Torment
				{  16, 133770 }, -- Slack Tide Girdle
				{  17, 137334 }, -- Salt-Laden Stompers
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
		},
--[[
		{	--Challenge Mode Gear
			name = AL["Challenge Mode Gear"],
			ExtraList = true,
			[NORMAL_DIFF] = "AtlasLoot_Collections:CMGEAR:1",
		},
]]		
		LEGION_DUNGEON_HERO_AC_TABLE,
		LEGION_GLORY_OF_THE_HERO_AC_TABLE,
	}
}

data["Neltharion'sLair"] = {
	EncounterJournalID = 767,
	MapID = 1065,
	AtlasMapID = "NeltharionsLair",
	ContentType = DUNGEON_CONTENT,
	items = {
		{	--Rokmora
			EncounterJournalID = 1662,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 139121 }, -- Skyhorn Mantle
				{  2, 137338 }, -- Shard of Rokmora
				{  3, 137340 }, -- Crystalline Energies
				{  4, 134481 }, -- Boulderbuckle Strap
				{  5, 134427 }, -- Riverrider Legwraps
				{  6, 139105 }, -- Rivermane Sandals
				{  7, 137337 }, -- Deepfurrow Bracers
				{  8, 137339 }, -- Quivering Blightshard Husk
				{  9, 134491 }, -- Understone Gorget
				{  10, 139095 }, -- Greystone Belt
				{  11, 139130 }, -- Sunfrost Wristwraps
				{  12, 137336 }, -- Vest of Rupturing Diamonds
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 120, "ac9045" },
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
		},
		{	--Ularogg Cragshaper
			EncounterJournalID = 1665,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 137347 }, -- Fragment of Loathing
				{  2, 134141 }, -- Rockbound Sabatons
				{  3, 134443 }, -- Gravelworn Handguards
				{  4, 134177 }, -- Roggthread Mantle
				{  5, 134164 }, -- Bitestone Wristwrap
				{  6, 137346 }, -- Murmuring Idol
				{  7, 134530 }, -- Loop of Vitriolic Intent
				{  8, 137354 }, -- Tunic of Screaming Earth
				{  9, 137341 }, -- Cragshaper's Fitted Hood
				{  10, 137344 }, -- Talisman of the Cragshaper
				{  11, 137342 }, -- Rock Solid Legplates
				{  12, 134152 }, -- Steelgazer Hide Hood
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 130, "ac9058" },
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
		},
		{	--Naraxas
			EncounterJournalID = 1673,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 137349 }, -- Naraxas' Spiked Tongue
				{  2, 137351 }, -- Noxious Entrails
				{  3, 134458 }, -- Wristbands of Rousing Violence
				{  4, 134524 }, -- Band of the Wyrm Matron
				{  5, 134511 }, -- Subterranean Horror Faceguard
				{  6, 137348 }, -- Gauntlets of Innumerable Barbs
				{  7, 137350 }, -- Monstrous Gluttony
				{  8, 134416 }, -- Offal Galoshes
				{  9, 134408 }, -- Putrid Carapace
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 126, "ac9056" },
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
		},
		{	--Dargrul the Underking
			EncounterJournalID = 1687,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 134455 }, -- Sinister Ashfall Cord
				{  2, 134154 }, -- Steelgazer Hide Mantle
				{  3, 134171 }, -- Roggthread Cord
				{  4, 137353 }, -- Charskin Legguards
				{  5, 137355 }, -- Rumblestone Gauntlets
				{  6, 137357 }, -- Mark of Dargrul
				{  7, 137359 }, -- Pebble of Ages
				{  8, 134166 }, -- Bitestone Boots
				{  9, 134420 }, -- Gloves of the Mountain Conquest
				{  10, 134470 }, -- Mountain Throne Coif
				{  11, 134517 }, -- Tremorguard Pauldrons
				{  12, 134474 }, -- Faultline Leggings
				{  13, 137352 }, -- Tunic of Smoldering Ire
				{  14, 137358 }, -- Hate-Sculpted Magma
				{  15, 134135 }, -- Rockbound Chestguard
				{  16, 134495 }, -- Chain of the Underking
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
		},
--[[
		{	--Challenge Mode Gear
			name = AL["Challenge Mode Gear"],
			ExtraList = true,
			[NORMAL_DIFF] = "AtlasLoot_Collections:CMGEAR:1",
		},
]]		
		LEGION_DUNGEON_HERO_AC_TABLE,
		LEGION_GLORY_OF_THE_HERO_AC_TABLE,
	}
}

data["ReturnToKarazhan"] = {
	EncounterJournalID = 860,
	MapID = 1115,
	AtlasMapID = "ReturntoKarazhanA",
	ContentType = DUNGEON_CONTENT,
	items = {
		{	--Opera Hall: Wikket
			EncounterJournalID = 1820,
			[MYTHICD2_DUNGEON_DIFF] = {
				{ 1, 142179 }, -- Memory of Betrayal
				{ 2, 142198 }, -- Inordinately Wonderous Wristguards
				{ 3, 142204 }, -- Boots of False Promises
				{ 4, 142296 }, -- Wikket Witch's Hat
				{ 5, 142298 }, -- Astonishingly Scarlet Slippers
				{ 6, 142300 }, -- Greaves of Miraculous Magnificence
				{ 7, 142137 }, -- Short Jibbet Waistguard
				{ 8, 142175 }, -- Arcanum of Weightlessness
				{ 9, 142194 }, -- Gloomy Vortex
				{ 10, 142205 }, -- Jabber Grookin' Gauntlets
				{ 11, 142299 }, -- Horkin' Stuff-Lobbers
			},
		},
		{	--Opera Hall: Westfall Story
			EncounterJournalID = 1826,
			[MYTHICD2_DUNGEON_DIFF] = {
				{ 1, 142164 }, -- Toe Knee's Promise
				{ 2, 142146 }, -- Blackfin Wristband
				{ 3, 142178 }, -- Ruffian's Poisoned Blade
				{ 4, 142302 }, -- Armguards of Burning Passion
				{ 5, 142154 }, -- Bracelets of the Sorrowful Bride
				{ 6, 142201 }, -- Mantle of Conflicted Loyalties
				{ 7, 142190 }, -- Love's Intermission
				{ 8, 142160 }, -- Mrrgria's Favor
				{ 9, 142186 }, -- Mrrmgmrl Grmmlmglrg
			},
		},
		{	--Opera Hall: Beautiful Beast
			EncounterJournalID = 1827,
			[MYTHICD2_DUNGEON_DIFF] = {
				{ 1, 142192 }, -- Ghastly Curse
				{ 2, 142196 }, -- Cinch of Improbable Desire
				{ 3, 142168 }, -- Majordomo's Dinner Bell
				{ 4, 142202 }, -- Trousers of Royal Vanity
				{ 5, 142206 }, -- Cloak of Sweltering Flame
				{ 6, 142197 }, -- Legguards of Imprisonment
				{ 7, 142304 }, -- Visage of Brutish Iron
				{ 8, 142188 }, -- Spellbound Rose Petal
				{ 9, 142184 }, -- Candle of Flickering Lumens
			},
		},
		{	--Maiden of Virtue
			EncounterJournalID = 1825,
			[MYTHICD2_DUNGEON_DIFF] = {
				{ 1, 142193 }, -- Begrudging Confessions
				{ 2, 142187 }, -- Virtuous Directive
				{ 3, 142139 }, -- Vest of Wanton Deeds
				{ 4, 142138 }, -- Confiscated Manacles
				{ 5, 142153 }, -- Cord of the Penitent
				{ 6, 142170 }, -- Drape of Shame
				{ 7, 142124 }, -- Treads of the Depraved
				{ 8, 142158 }, -- Faith's Crucible
			},
		},
		{	--Attumen the Huntsman
			EncounterJournalID = 1835,
			[MYTHICD2_DUNGEON_DIFF] = {
				{ 1, 142136 }, -- Mantle of Hideous Trophies
				{ 2, 142183 }, -- Lava-Quenched Hoofplate
				{ 3, 142185 }, -- Fear of Predation
				{ 4, 142174 }, -- Choker of Barbed Reins
				{ 5, 142191 }, -- Dirge of the Hunted
				{ 6, 142148 }, -- Wilderness Stalker's Softsoles
				{ 7, 142126 }, -- Helm of Phantasmal Scars
				{ 8, 142236 }, -- Midnight's Eternal Reins
				{ 9, 142140 }, -- Calliard's Galoshes
				{ 10, 142161 }, -- Inescapable Dread
			},
		},
		{	--Moroes
			EncounterJournalID = 1837,
			[MYTHICD2_DUNGEON_DIFF] = {
				{ 1, 142147 }, -- Robes of Wicked Modesty
				{ 2, 142134 }, -- Castellan's Blinders
				{ 3, 142123 }, -- Breastplate of Obligation
				{ 4, 138797 }, -- Illusion: Mongoose
				{ 5, 142189 }, -- Perfectly Preserved Apple
				{ 6, 142171 }, -- Seal of Darkshire Nobility
				{ 7, 142143 }, -- Willbreaker Legguards
				{ 8, 142177 }, -- Jagged Emerald
				{ 9, 142159 }, -- Bloodstained Handkerchief
			},
		},
		{	--The Curator
			EncounterJournalID = 1836,
			[MYTHICD2_DUNGEON_DIFF] = {
				{ 1, 142149 }, -- Gloves of Arcane Confluence
				{ 2, 142181 }, -- Seeping Corruption
				{ 3, 142125 }, -- Repurposed Golem Grips
				{ 4, 142172 }, -- Terestian's Signet Ring
				{ 5, 142309 }, -- Fauna Analysis Widget
				{ 6, 142176 }, -- Arcing Static Charge
				{ 7, 142133 }, -- Gauntlets of Confinement
				{ 8, 142165 }, -- Deteriorated Construct Core
				{ 9, 142141 }, -- Custodian's Soothing Touch
				{ 10, 142130 }, -- Bite-Marked Wristplates
			},
		},
		{	--Shade of Medivh
			EncounterJournalID = 1817,
			[MYTHICD2_DUNGEON_DIFF] = {
				{ 1, 142207 }, -- Amulet of the Last Guardian
				{ 2, 142157 }, -- Aran's Relaxing Ruby
				{ 3, 142129 }, -- Spellwarding Waistguard
				{ 4, 142131 }, -- Frozen-Link Chestguard
				{ 5, 142152 }, -- Shoulderpads of Chaotic Thought
				{ 6, 142169 }, -- Raven Eidolon
				{ 7, 142310 }, -- Anthology of Horrors
				{ 8, 142308 }, -- Ageless Winter
				{ 9, 142145 }, -- Girdle of Ghostly Exclusion
			},
		},
		{	--Mana Devourer
			EncounterJournalID = 1818,
			[MYTHICD2_DUNGEON_DIFF] = {
				{ 1, 142162 }, -- Fluctuating Energy
				{ 2, 142305 }, -- Suffused Manapearl
				{ 3, 142307 }, -- Miniature Bonfire
				{ 4, 142144 }, -- Unending Horizon Spaulders
				{ 5, 142150 }, -- Hood of Uncanny Perspectives
				{ 6, 142135 }, -- Legguards of Countless Hours
				{ 7, 142128 }, -- Pauldrons of Encroaching Limits
				{ 8, 142215 }, -- Wine-Stained Mantle
				{ 9, 142180 }, -- Grisly Schism
			},
		},
		{	--Viz'aduum the Watcher
			EncounterJournalID = 1838,
			[MYTHICD2_DUNGEON_DIFF] = {
				{ 1, 142151 }, -- Leggings of Countless Worlds
				{ 2, 142306 }, -- Rift Stabilization Shard
				{ 3, 142132 }, -- Doomstride Footguards
				{ 4, 142182 }, -- Viz'aduum's Mindstone
				{ 5, 142127 }, -- Tassets of Perpetual Despair
				{ 6, 142142 }, -- Unbound Reality Mask
				{ 7, 142173 }, -- Ring of Collapsing Futures
				{ 8, 142167 }, -- Eye of Command
			},
		},
	}
}

-- Seat of the Triumvirate
data["SeatoftheTriumvirate"] = {
	EncounterJournalID = 945,
	MapID = 1178,
	AtlasMapID = "TheSeatoftheTriumvirate",
	ContentType = DUNGEON_CONTENT,
	items = {
		{	-- Zuraal the Ascended
			EncounterJournalID = 1979,
			[HEROIC_DUNGEON_DIFF] = {
				{ 1, 151312 }, -- Ampoule of Pure Void
				{ 2, 151329 }, -- Breastplate of the Dark Touch
				{ 3, 151331 }, -- Pauldrons of the Broken
				{ 4, 151320 }, -- Void-Coated Stompers
				{ 5, 151326 }, -- Waistguard of Bound Energy
				{ 6, 151315 }, -- Bracers of Dark Binding
				{ 7, 151300 }, -- Handwraps of the Ascended
				{ 8, 151304 }, -- Subjugator's Leggings
				{ 9, 151291 }, -- Frozen Void Shard
				{ 10, 151308 }, -- Mac'Aree Seal of Nobility
				{ 11, 151336 }, -- Voidlashed Hood
				{ 12, 151293 }, -- Orb of the Abandoned Magi
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = HEROIC_DUNGEON_DIFF,
			},
		},
		{	-- Saprish
			EncounterJournalID = 1980,
			[HEROIC_DUNGEON_DIFF] = {
				{ 1, 151327 }, -- Girdle of the Shadowguard
				{ 2, 151314 }, -- Shifting Stalker Hide Pants
				{ 3, 151318 }, -- Gloves of the Dark Shroud
				{ 4, 151307 }, -- Void Stalker's Contract
				{ 5, 151294 }, -- Coalesced Void
				{ 6, 151330 }, -- Trap Jammers
				{ 7, 151303 }, -- Voidbender Robe
				{ 8, 151321 }, -- Darkfang Scale Wristguards
				{ 9, 151323 }, -- Pauldrons of the Void Hunter
				{ 10, 151295 }, -- Darkstorm Arrowhead
				{ 11, 151337 }, -- Shadow-Weaver's Crown
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = HEROIC_DUNGEON_DIFF,
			},
		},
		{	-- Viceroy Nezhar
			EncounterJournalID = 1981,
			[HEROIC_DUNGEON_DIFF] = {
				{ 1, 151297 }, -- Carved Argunite Idol
				{ 2, 151299 }, -- Viceroy's Umbral Mantle
				{ 3, 151316 }, -- Cinch of the Umbral Lasher
				{ 4, 151333 }, -- Crown of the Dark Envoy
				{ 5, 151290 }, -- Darktide Fervor
				{ 6, 151309 }, -- Necklace of the Twisting Void
				{ 7, 151288 }, -- Void-Resistant Seedpod
				{ 8, 151332 }, -- Voidclaw Gauntlets
				{ 9, 151325 }, -- Void-Linked Robe
				{ 10, 151305 }, -- Entropic Wristwraps
				{ 11, 151338 }, -- Leggings of Shifting Darkness
				{ 12, 151310 }, -- Reality Breacher
				{ 13, 151317 }, -- Footpads of Seeping Dread
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = HEROIC_DUNGEON_DIFF,
			},
		},
		{	-- L'ura
			EncounterJournalID = 1982,
			[HEROIC_DUNGEON_DIFF] = {
				{ 1, 151301 }, -- Slippers of Growing Despair
				{ 2, 151289 }, -- Badge of the Fallen Vindicator
				{ 3, 151322 }, -- Void-Touched Grips
				{ 4, 151324 }, -- Helm of Shadowy Descent
				{ 5, 151296 }, -- Blood of the Vanquished
				{ 6, 151313 }, -- Vest of the Void's Embrace
				{ 7, 151311 }, -- Band of the Triumvirate
				{ 8, 151302 }, -- Cord of Unraveling Reality
				{ 9, 151319 }, -- Twilight's Edge Spaulders
				{ 10, 151328 }, -- Vambraces of Lost Hope
				{ 11, 151339 }, -- Legplates of Ultimate Sacrifice
				{ 12, 151340 }, -- Echo of L'ura
				{ 13, 151292 }, -- Sanctified Eredar Lock
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = HEROIC_DUNGEON_DIFF,
			},
		},
	},
}

data["VaultOfTheWardens"] = {
	EncounterJournalID = 707,
	MapID = 1045,
	AtlasMapID = "VaultoftheWardensA",
	ContentType = DUNGEON_CONTENT,
	items = {
		{	--Tirathon Saltheril
			EncounterJournalID = 1467,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 137542 }, -- Metamorphosis Spark
				{  2, 134398 }, -- Netherwhisper Wristguard
				{  3, 137537 }, -- Tirathon's Betrayal
				{  4, 137509 }, -- Glaivemaster's Studded Grips
				{  5, 137532 }, -- Seal of Saltheril
				{  6, 137502 }, -- Hood of Indignation
				{  7, 134369 }, -- Felbat Leather Boots
				{  8, 137517 }, -- Striders of Furious Flight
				{  9, 137524 }, -- Mortar Guard Shoulderplates
				{  10, 134390 }, -- Mardum Chain Vest
				{  11, 134362 }, -- Portalguard Wristguard
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 126, "ac9056" },
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
		},
		{	--Inquisitor Tormentorum
			EncounterJournalID = 1695,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 137538 }, -- Orb of Torment
				{  2, 137511 }, -- Hood of the Blind Executioner
				{  3, 137518 }, -- Leggings of Biting Links
				{  4, 137544 }, -- Prisoner's Wail
				{  5, 137525 }, -- Blood-Spattered Gauntlets
				{  6, 137543 }, -- Soulsap Shackles
				{  7, 137530 }, -- Drape of Vile Misfortune
				{  8, 137503 }, -- Amice of Cruel Laughter
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 126, "ac9056" },
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
		},
		{	--Ash'golm
			EncounterJournalID = 1468,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 137512 }, -- Flame Juggler's Armbands
				{  2, 137546 }, -- Molten Giant's Eye
				{  3, 137535 }, -- Lavadrip Pendant
				{  4, 137539 }, -- Faulty Countermeasure
				{  5, 137526 }, -- Crown of Ash
				{  6, 137545 }, -- Flashfrozen Ember
				{  7, 137505 }, -- Leggings of the Third Degree
				{  8, 137504 }, -- Flameheart Vestment
				{  9, 137520 }, -- Permafrost Waistband
				{  10, 137523 }, -- Magmacrusher Girdle
				{  11, 137510 }, -- Charskin Mantle
				{  12, 137519 }, -- Lavabreaker Gauntlets
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 126, "ac9056" },
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
		},
		{	--Glazer
			EncounterJournalID = 1469,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 137547 }, -- Pulsing Prism
				{  2, 137527 }, -- Polished Jade Chestguard
				{  3, 137533 }, -- Ring of Minute Mirrors
				{  4, 137506 }, -- Gloves of Unseen Evil
				{  5, 137513 }, -- Girdle of Lidless Sight
				{  6, 137536 }, -- Pendant of the Watchful Eye
				{  7, 137516 }, -- Collar of Blindsight
				{  8, 137540 }, -- Concave Reflecting Lens
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 126, "ac9056" },
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
		},
		{	--Cordana Felsong
			EncounterJournalID = 1470,
			[NORMAL_DUNGEON_DIFF] = {
				{  1, 137514 }, -- Chestguard of Insidious Desire
				{  2, 134356 }, -- Portalguard Gauntlets
				{  3, 137522 }, -- Bracers of Twisted Revelation
				{  4, 137507 }, -- Waistband of Spiritual Doom
				{  5, 137515 }, -- Warden's Martial Greaves
				{  6, 137550 }, -- Moonglaive Dervish
				{  7, 134392 }, -- Netherwhisper Hood
				{  8, 137531 }, -- Cloak of Enthralling Darkness
				{  9, 137508 }, -- Shadewalker Footwraps
				{  10, 137528 }, -- Legguards of Illusory Burdens
				{  11, 134386 }, -- Mardum Chain Boots
				{  12, 137521 }, -- Shoulderguards of Shunned Duty
				{  13, 137529 }, -- Pathfinders of Dark Omens
				{  14, 134371 }, -- Felbat Leather Gloves
				{  15, 137548 }, -- Elune's Light
				{  16, 137541 }, -- Moonlit Prism
				{  17, 137549 }, -- Shade of the Vault
			},
			[HEROIC_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
				--{ 126, "ac9056" },
			},
			[MYTHICD_DUNGEON_DIFF] = {
				GetItemsFromDiff = NORMAL_DUNGEON_DIFF,
			},
		},
	}
}			

-- /////////////////////////////////
-- Raid
-- /////////////////////////////////

-- Antorus, the Burning Throne
data["AntorustheBurningThrone"] = {
	EncounterJournalID = 946,
	MapID = 1188,
	AtlasMapID = "AntorustheBurningThroneA",
	ContentType = RAID_CONTENT,
	items = {
		{	-- Garothi Worldbreaker
			EncounterJournalID = 1992,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
			},
			[NORMAL_RAID_DIFF] = {
				{ 1 , 152017 }, -- Soul-Tempered Chestplate
				{ 2 , 152036 }, -- Hellfire Ignition Switch
				{ 3 , 152031 }, -- Doomfire Dynamo
				{ 4 , 152002 }, -- Battalion-Shattering Leggings
				{ 5 , 151937 }, -- Cloak of the Burning Vanguard
				{ 6 , 152028 }, -- Spurting Reaver Heart
				{ 7 , 151956 }, -- Garothi Feedback Conduit
				{ 8 , 151943 }, -- Crown of Relentless Annihilation
				{ 9 , 152009 }, -- Doomwalker Warboots
				{ 10, 151962 }, -- Prototype Personnel Decimator
				{ 11, 152039 }, -- Viscous Reaver-Coolant
				{ 12, 151951 }, -- Enhanced Worldscorcher Cinch
				{ 13, 151998 }, -- Heedless Eradication Gauntlets
				{ 14, 151987 }, -- Breach-Blocker Legguards
				{ 15, 151988 }, -- Shoulderpads of the Demonic Blitz
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
			},
		},
		{	-- Felhounds of Sargeras
			EncounterJournalID = 1987,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
			},
			[NORMAL_RAID_DIFF] = {
				{ 1 , 151968 }, -- Shadow-Singed Fang
				{ 2 , 151949 }, -- Soul-Siphon Mantle
				{ 3 , 152027 }, -- Gravitational Condensate
				{ 4 , 152000 }, -- Shadowfused Chain Coif
				{ 5 , 151973 }, -- Collar of Null-Flame
				{ 6 , 152012 }, -- Molten Bite Handguards
				{ 7 , 152059 }, -- Whistling Ulna
				{ 8 , 151974 }, -- Eye of Shatug
				{ 9 , 151947 }, -- Vestments of Enflamed Blight
				{ 10, 152021 }, -- Flamelicked Girdle
				{ 11, 152056 }, -- Corrupting Dewclaw
				{ 12, 152645 }, -- Eye of F'harg
				{ 13, 152291 }, -- Fraternal Fervor
				{ 14, 152816 }, -- Antoran Charhound
				{ 15, 151983 }, -- Vicious Flamepaws
				{ 16, 151980 }, -- Harness of Oppressing Dark
				{ 17, 152004 }, -- Pauldrons of the Soulburner
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
			},
		},
		{	-- Antoran High Command
			EncounterJournalID = 1997,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
			},
			[NORMAL_RAID_DIFF] = {
				{ 1 , 152119 }, -- Felreaper Drape
				{ 2 , 152154 }, -- Gilded Seraph's Drape
				{ 3 , 152131 }, -- Serpentstalker Drape
				{ 4 , 152011 }, -- Eredar Warcouncil Sabatons
				{ 5 , 151953 }, -- Man'ari Pyromancer Cuffs
				{ 6 , 152143 }, -- Cloak of Chi'Ji
				{ 7 , 151992 }, -- Fiendish Logistician's Wristwraps
				{ 8 , 151969 }, -- Terminus Signaling Beacon
				{ 9 , 152043 }, -- Lightshield Amplifier
				{ 10, 151985 }, -- General Erodus' Tricorne
				{ 11, 152113 }, -- Dreadwake Greatcloak
				{ 12, 152179 }, -- Juggernaut Cloak
				{ 13, 152125 }, -- Bearmantle Cloak
				{ 14, 152136 }, -- Runebound Cape
				{ 15, 151957 }, -- Ishkar's Felshield Emitter
				{ 16, 152149 }, -- Light's Vanguard Greatcloak
				{ 17, 152172 }, -- Grim Inquisitor's Cloak
				{ 18, 152424 }, -- Legwraps of the Seasoned Exterminator
				{ 19, 151994 }, -- Fleet Commander's Hauberk
				{ 20, 152032 }, -- Twisted Engineer's Fel-Infuser
				{ 21, 152006 }, -- Depraved Tactician's Waistguard
				{ 22, 152161 }, -- Cloak of the Dashing Scoundrel
				{ 23, 152019 }, -- Pauldrons of the Eternal Offensive
				{ 24, 152293 }, -- Fasces of the Endless Legions
				{ 25, 152167 }, -- Drape of Venerated Spirits
				{ 26, 152295 }, -- Svirax's Grim Trophy
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
			},
		},
		{	-- Portal Keeper Hasabel
			EncounterJournalID = 1985,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
			},
			[NORMAL_RAID_DIFF] = {
				{ 1 , 152049 }, -- Fel-Engraved Handbell
				{ 2 , 151976 }, -- Riftworld Codex
				{ 3 , 152008 }, -- Reality-Splitting Wristguards
				{ 4 , 151965 }, -- Vulcanarcore Pendant
				{ 5 , 152057 }, -- Crepuscular Skitterer Egg
				{ 6 , 151958 }, -- Tarratus Keystone
				{ 7 , 152001 }, -- Nexus Conductor's Headgear
				{ 8 , 152063 }, -- Seal of the Portalmaster
				{ 9 , 152035 }, -- Blazing Dreadsteed Horseshoe
				{ 10, 151945 }, -- Lady Dacidion's Silk Slippers
				{ 11, 151990 }, -- Portal Keeper's Cincture
				{ 12, 152041 }, -- Sublimating Portal Frost
				{ 13, 152086 }, -- Grips of Hungering Shadows
				{ 14, 152020 }, -- Nathrezim Battle Girdle
				{ 15, 151941 }, -- Aranasi Shadow-Weaver's Gloves
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
			},
		},
		{	-- Eonar the Life-Binder
			EncounterJournalID = 2025,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
			},
			[NORMAL_RAID_DIFF] = {
				{ 1 , 152061 }, -- Droplets of the Cleansing Storm
				{ 2 , 152158 }, -- Gilded Seraph's Robes
				{ 3 , 152007 }, -- Sash of the Gilded Rose
				{ 4 , 152166 }, -- Robes of Venerated Spirits
				{ 5 , 152112 }, -- Dreadwake Bonecage
				{ 6 , 152178 }, -- Juggernaut Breastplate
				{ 7 , 152124 }, -- Bearmantle Harness
				{ 8 , 151981 }, -- Life-Bearing Footpads
				{ 9 , 152140 }, -- Runebound Tunic
				{ 10, 152148 }, -- Light's Vanguard Breastplate
				{ 11, 151970 }, -- Vitality Resonator
				{ 12, 152160 }, -- Vest of the Dashing Scoundrel
				{ 13, 152023 }, -- Vambraces of Life's Assurrance
				{ 14, 152013 }, -- Helmet of the Hidden Sanctuary
				{ 15, 152681 }, -- Headdress of Living Brambles
				{ 16, 152176 }, -- Grim Inquisitor's Robes
				{ 17, 152118 }, -- Felreaper Vest
				{ 18, 152044 }, -- Spark of Everburning Light
				{ 19, 152688 }, -- Loop of the Life-Binder
				{ 20, 152130 }, -- Serpentstalker Tunic
				{ 21, 152047 }, -- Ironvine Thorn
				{ 22, 151952 }, -- Cord of Blossoming Petals
				{ 23, 152142 }, -- Tunic of Chi'Ji
				{ 24, 152054 }, -- Unwavering Soul Essence
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
			},
		},
		{	-- Imonar the Soulhunter
			EncounterJournalID = 2009,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
			},
			[NORMAL_RAID_DIFF] = {
				{ 1 , 152146 }, -- Leggings of Chi'Ji
				{ 2 , 151999 }, -- Preysnare Vicegrips
				{ 3 , 152042 }, -- Hoarfrost-Beast Talon
				{ 4 , 152170 }, -- Leggings of Venerated Spirits
				{ 5 , 152050 }, -- Mysterious Petrified Egg
				{ 6 , 152116 }, -- Dreadwake Legplates
				{ 7 , 152182 }, -- Juggernaut Legplates
				{ 8 , 151938 }, -- Drape of the Spirited Hunt
				{ 9 , 152128 }, -- Bearmantle Legguards
				{ 10, 151989 }, -- Spaulders of the Relentless Tracker
				{ 11, 152024 }, -- Fallen Magi's Seerstone
				{ 12, 152152 }, -- Light's Vanguard Legplates
				{ 13, 151939 }, -- Whisperstep Runners
				{ 14, 152687 }, -- Imonar's Demi-Gauntlets
				{ 15, 152164 }, -- Pants of the Dashing Scoundrel
				{ 16, 152416 }, -- Shoulderguards of Indomitable Purpose
				{ 17, 151996 }, -- Deft Soulhunter's Sabatons
				{ 18, 151967 }, -- Electrostatic Lasso
				{ 19, 152122 }, -- Felreaper Leggings
				{ 20, 152157 }, -- Gilded Seraph's Leggings
				{ 21, 151944 }, -- Soulhunter's Cowl
				{ 22, 152134 }, -- Serpentstalker Legguards
				{ 23, 152045 }, -- Venerated Puresoul Idol
				{ 24, 152139 }, -- Runebound Leggings
				{ 25, 152175 }, -- Grim Inquisitor's Leggings
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
			},
		},
		{	-- Kin'garoth
			EncounterJournalID = 2004,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
			},
			[NORMAL_RAID_DIFF] = {
				{ 1 , 152150 }, -- Light's Vanguard Gauntlets
				{ 2 , 152034 }, -- Obliterator Propellant
				{ 3 , 152162 }, -- Gloves of the Dashing Scoundrel
				{ 4 , 152120 }, -- Felreaper Gloves
				{ 5 , 152155 }, -- Gilded Seraph's Handwraps
				{ 6 , 152132 }, -- Serpentstalker Grips
				{ 7 , 151955 }, -- Acrid Catalyst Injector
				{ 8 , 152144 }, -- Grips of Chi'Ji
				{ 9 , 152055 }, -- Kin'garoth's Oil-Sump
				{ 10, 152137 }, -- Runebound Gloves
				{ 11, 152280 }, -- Scalding Shatterguards
				{ 12, 151963 }, -- Forgefiend's Fabricator
				{ 13, 152412 }, -- Depraved Machinist's Footpads
				{ 14, 152168 }, -- Gloves of Venerated Spirits
				{ 15, 152048 }, -- Decimator Crankshaft
				{ 16, 152114 }, -- Dreadwake Gauntlets
				{ 17, 152180 }, -- Juggernaut Gauntlets
				{ 18, 152064 }, -- Band of the Sargerite Smith
				{ 19, 152126 }, -- Bearmantle Paws
				{ 20, 151975 }, -- Apocalypse Drive
				{ 21, 151948 }, -- Magma-Spattered Smock
				{ 22, 152014 }, -- Titan-Subjugator's Visage
				{ 23, 152173 }, -- Grim Inquisitor's Gloves
				{ 24, 152051 }, -- Eidolon of Life
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
			},
		},
		{	-- The Coven of Shivarra
			EncounterJournalID = 1986,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
			},
			[NORMAL_RAID_DIFF] = {
				{ 1 , 152177 }, -- Grim Inquisitor's Shoulderguards
				{ 2 , 152123 }, -- Felreaper Spaulders
				{ 3 , 152003 }, -- Legguards of Numbing Gloom
				{ 4 , 152135 }, -- Serpentstalker Mantle
				{ 5 , 152046 }, -- Coven Prayer Bead
				{ 6 , 152147 }, -- Meditation Spheres of Chi'Ji
				{ 7 , 152058 }, -- Stormcaller's Fury
				{ 8 , 152159 }, -- Gilded Seraph's Amice
				{ 9 , 151946 }, -- Fervent Twilight Legwraps
				{ 10, 152171 }, -- Pauldrons of Venerated Spirits
				{ 11, 152117 }, -- Dreadwake Pauldrons
				{ 12, 152183 }, -- Juggernaut Pauldrons
				{ 13, 152284 }, -- Zealous Tormentor's Ring
				{ 14, 152040 }, -- Frigid Gloomstone
				{ 15, 152129 }, -- Bearmantle Shoulders
				{ 16, 152141 }, -- Runebound Mantle
				{ 17, 151977 }, -- Diima's Glacial Aegis
				{ 18, 152289 }, -- Highfather's Machination
				{ 19, 152153 }, -- Light's Vanguard Shoulderplates
				{ 20, 151971 }, -- Sheath of Asara
				{ 21, 152010 }, -- Burning Coven Sabatons
				{ 22, 152165 }, -- Shoulderpads of the Dashing Scoundrel
				{ 23, 152029 }, -- Shivarran Cachabon
				{ 24, 151984 }, -- Lurid Grips of the Obscene
				{ 25, 152414 }, -- Bracers of Wanton Morality
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
			},
		},
		{	-- Varimathras
			EncounterJournalID = 1983,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
			},
			[NORMAL_RAID_DIFF] = {
				{ 1 , 151942 }, -- Cord of Surging Hysteria
				{ 2 , 151991 }, -- Belt of Fractured Sanity
				{ 3 , 152092 }, -- Nathrezim Incisor
				{ 4 , 152025 }, -- Thu'rayan Lash
				{ 5 , 151997 }, -- Nathrezim Shade-Walkers
				{ 6 , 151954 }, -- Blood-Drenched Bindings
				{ 7 , 152015 }, -- Greaves of Mercurial Alliegance
				{ 8 , 151964 }, -- Seeping Scourgewing
				{ 9 , 151960 }, -- Carafe of Searing Light
				{ 10, 152037 }, -- Tormentor's Brand
				{ 11, 151979 }, -- Vest of Unfathomable Anguish
				{ 12, 151966 }, -- Riveted Choker of Delirium
				{ 13, 152281 }, -- Varimathras' Shattered Manacles
				{ 14, 152060 }, -- Neuroshock Electrode
				{ 15, 151995 }, -- Robes of the Forsaken Dreadlord
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
			},
		},
		{	-- Aggramar
			EncounterJournalID = 1984,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
			},
			[NORMAL_RAID_DIFF] = {
				{ 1 , 152115 }, -- Dreadwake Helm
				{ 2 , 152181 }, -- Juggernaut Helm
				{ 3 , 152127 }, -- Bearmantle Headdress
				{ 4 , 152038 }, -- Pyretic Bronze Clasp
				{ 5 , 152174 }, -- Grim Inquisitor's Death Mask
				{ 6 , 152151 }, -- Light's Vanguard Helm
				{ 7 , 152093 }, -- Gorshalach's Legacy
				{ 8 , 152163 }, -- Cavalier Hat of the Dashing Scoundrel
				{ 9 , 151950 }, -- Fallen Avenger's Amice
				{ 10, 151978 }, -- Foe-Breaker Titanguard
				{ 11, 152282 }, -- Caustic Titanspite Legguards
				{ 12, 152121 }, -- Felreaper Hood
				{ 13, 152156 }, -- Gilded Seraph's Crown
				{ 14, 152169 }, -- Headdress of Venerated Spirits
				{ 15, 152133 }, -- Serpentstalker Helmet
				{ 16, 152062 }, -- Greatcloak of the Dark Pantheon
				{ 17, 152683 }, -- World-Ravager Waistguard
				{ 18, 152052 }, -- Sporemound Seedling
				{ 19, 151940 }, -- Sandals of the Reborn Colossus
				{ 20, 152022 }, -- Grond-Father Girdle
				{ 21, 152033 }, -- Sliver of Corruption
				{ 22, 152684 }, -- Greatboots of the Searing Tempest
				{ 23, 152145 }, -- Douli of Chi'Ji
				{ 24, 152138 }, -- Runebound Collar
				{ 25, 152018 }, -- Breastplate of Molten Rebirth
				{ 26, 152026 }, -- Prototype Titan-Disc
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
			},
		},
		{	-- Argus the Unmaker
			EncounterJournalID = 2031,
			[RF_DIFF] = {
				{ 1, 151972 }, -- Sullied Seal of the Pantheon
				{ 2, 151982 }, -- Vest of Waning Life
				{ 3, 151986 }, -- Death-Enveloping Cincture
				{ 4, 152005 }, -- Pauldrons of Colossal Burden
				{ 5, 152016 }, -- Cosmos-Culling Legplates
				{ 6, 152283 }, -- Chain of the Unmaker
				{ 7, 152423 }, -- Helm of the Awakened Soul
				{ 8, 152679 }, -- Gambeson of Sargeras' Corruption
				{ 9, 152680 }, -- Handwraps of Inevitable Doom
				{ 10, 152686 }, -- Nascent Deathbringer's Clutches
				{ 11, 155846 }, -- Miniaturized Cosmic Beacon
				{ 12, 155847 }, -- Cruor of the Avenger
				{ 13, 155848 }, -- Condensed Blight Orb
				{ 14, 155849 }, -- Flickering Ember of Rage
				{ 15, 155850 }, -- Rime of the Spirit Realm
				{ 16, 155851 }, -- Reorigination Spark
				{ 17, 155852 }, -- Volatile Soul Fragment
				{ 18, 155853 }, -- Conch of the Thunderer
				{ 19, 155854 }, -- Root of the Lifebinder
				{ 20, 155855 }, -- Mote of the Forgemaster
			},
			[NORMAL_RAID_DIFF] = {
				GetItemsFromDiff = RF_DIFF,
				{ 21, 154172 }, -- Aman'Thul's Vision
				{ 22, 154173 }, -- Aggramar's Conviction
				{ 23, 154174 }, -- Golganneth's Vitality
				{ 24, 154175 }, -- Eonar's Compassion
				{ 25, 154176 }, -- Khaz'goroth's Courage
				{ 26, 154177 }, -- Norgannon's Prowess
				{ 27, 155831 }, -- Pantheon's Blessing
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 28, 152789 }, -- Shackled Ur'zul
			},
		},
		{	--Tier 21 Sets
			name = format(AL["Tier %d Sets"], 21),
			ExtraList = true,
			[NORMAL_DIFF] = "AtlasLoot_Collections:TIERSETS:21",
		},
	},
}

data["BrokenIsles"] = {
	EncounterJournalID = 822,
	MapID = 1007,
	ItemBaseLvl = 860,
	AtlasMapID = "OR_BrokenIsles",
	ContentType = RAID_CONTENT,
	items = {
		{	--Ana-Mouz
			EncounterJournalID = 1790,
			[NORMAL_RAID_DIFF] = {
				{  1, 141423 }, -- Crop Top Chain Hauberk
				{  2, 141486 }, -- Demonic Birthstone Ring
				{  3, 141419 }, -- Skimpy Demonleather Tunic
				{  4, 141413 }, -- Low-Cut Chestplate
				{  5, 141427 }, -- Sheer Felthreaded Robe
				{  6, 141520 }, -- Imp-Eye Diamond
				{  7, 141448 }, -- Imp Mother's Loincloth
				-- { 16, "ac9423" },
			},
		},
		{	--Calamir
			EncounterJournalID = 1774,
			[NORMAL_RAID_DIFF] = {
				{  1, 141437 }, -- Warboots of Smoldering Fury
				{  2, 141522 }, -- Calamir's Jaw
				{  3, 141432 }, -- Frostburned Sabatons
				{  4, 141430 }, -- Mana-Tanned Sandals
				{  5, 141533 }, -- Ring of Frozen Magic
				{  6, 141443 }, -- Sandals of Frozen Ash
				{  7, 141438 }, -- Pendant of Cold Flame
				--{ 24, "ac9425" },
			},
		},
		{	--Drugon the Frostblood
			EncounterJournalID = 1789,
			[NORMAL_RAID_DIFF] = {
				{  1, 141535 }, -- Ettin Fingernail
				{  2, 141439 }, -- Ettinbone Bracers
				{  3, 141517 }, -- Drugon's Snowglobe
				{  4, 141538 }, -- Giant's Handkerchief
				{  5, 141428 }, -- Snowdrift Bracers
				{  6, 141429 }, -- Wax-Sealed Leather Bracers
				{  7, 141433 }, -- Assorted Dragonscale Bracers
				-- { 16, "ac9423" },
			},
		},
		{	--Flotsam
			EncounterJournalID = 1795,
			[NORMAL_RAID_DIFF] = {
				{  1, 141466 }, -- Blackwater Raider Handguards
				{  2, 141516 }, -- \"Liberated\" Un'goro Relic
				{  3, 141475 }, -- Salt-Stained Tuskarr Gloves
				{  4, 141539 }, -- Ragged Azsharan Sail Fragment
				{  5, 141470 }, -- Faded Bloodsail Handwraps
				{  6, 141544 }, -- Marshstomper Oracle's Loop
				{  7, 141476 }, -- Kezan Pirate's Mitts
				-- { 16, "ac9423" },
			},
		},
		{	--Humongris
			EncounterJournalID = 1770,
			[NORMAL_RAID_DIFF] = {
				{  1, 141416 }, -- Padawsen's Squished Pauldrons
				{  2, 141536 }, -- Padawsen's Unlucky Charm
				{  3, 141426 }, -- Shoulderplates of Oversized Sorcery
				{  4, 141445 }, -- Mantle of the Aspiring Spellgiant
				{  5, 141540 }, -- Coerced Wizard's Cloak
				{  6, 141422 }, -- Shoulderguards of Unimaginative Magic
				{  7, 141521 }, -- Sea Giant Toothpick Fragment
				-- { 16, "ac9423" },
			},
		},
		{	--Levantus
			EncounterJournalID = 1769,
			[NORMAL_RAID_DIFF] = {
				{  1, 141431 }, -- Hook-Fingered Gauntlets
				{  2, 141523 }, -- Fel-Scented Bait
				{  3, 141440 }, -- Seaweed \"Leather\" Mitts
				{  4, 141441 }, -- Chum-Chopper Gauntlets
				{  5, 141435 }, -- Whirlpool Gloves
				{  6, 141545 }, -- Ring of Deep Sea Pearls
				{  7, 141473 }, -- Krakentooth Necklace
				--{ 22, "ac9423" },
			},
		},
		{	--Na'zak the Fiend
			EncounterJournalID = 1783,
			[NORMAL_RAID_DIFF] = {
				{ 1, 141515 }, -- Leystone Nugget
				{ 2, 141425 }, -- Avalanche Resistant Legplates
				{ 3, 141488 }, -- Mana-Dowsing Ring
				{ 4, 141534 }, -- Loop of Polished Pebbles
				{ 5, 141421 }, -- Venomscarred Chain Leggings
				{ 6, 141415 }, -- Na'zak's Dusty Pantaloons
				{ 7, 141417 }, -- Dessicated Leather Pants
				-- { 16, "ac9423" },
			},
		},
		{	--Nithogg
			EncounterJournalID = 1749,
			[NORMAL_RAID_DIFF] = {
				{  1, 141424 }, -- Stormbattered Casque
				{  2, 141418 }, -- Helm of the Mountain Recluse
				{  3, 141546 }, -- Cursed Warden's Keepsake
				{  4, 141420 }, -- Coif of Unstable Discharge
				{  5, 141519 }, -- Pillaged Titan Disc
				{  6, 141541 }, -- Windwhipped Greatcloak
				{  7, 141414 }, -- Hood of Scorned Brood
				-- { 16, "ac9423" },
			},
		},
		{	--Shar'thos
			EncounterJournalID = 1763,
			[NORMAL_RAID_DIFF] = {
				{  1, 141542 }, -- Despoiled Dreamthread Cloak
				{  2, 141487 }, -- Tunic of Waking Nightmares
				{  3, 141481 }, -- Chestplate of Blackened Emeralds
				{  4, 141518 }, -- Decaying Dragonfang
				{  5, 141547 }, -- Choker of Dreamthorns
				{  6, 141495 }, -- Robe of Fever Dreams
				{  7, 141491 }, -- Hauberk of the Snarled Vale
				-- { 16, "ac9423" },
			},
		},
		{	--The Soultakers
			EncounterJournalID = 1756,
			[NORMAL_RAID_DIFF] = {
				{  1, 141444 }, -- Hel-Cursed Belt
				{  2, 141537 }, -- Thrice-Accursed Compass
				{  3, 141436 }, -- Helchain Waistguard
				{  4, 141434 }, -- Cord of Kept Souls
				{  5, 141442 }, -- Sea-Reaver's Girdle
				{  6, 141506 }, -- Soultrapper's Pendant
				{  7, 141514 }, -- Barnacled Mistcaller Orb
				--{ 16, "ac9423" },
			},
		},
		{	--Withered J'im
			EncounterJournalID = 1796,
			[NORMAL_RAID_DIFF] = {
				{  1, 141459 }, -- Manacrystal-Adorned Helmet
				{  2, 141453 }, -- Magic-Warped Hood
				{  3, 141482 }, -- Unstable Arcanocrystal
				{  4, 141455 }, -- Cave Skulker's Helm
				{  5, 141449 }, -- Mana Scavenger's Mask
				{  6, 141492 }, -- Dingy Suramar Mercantile Signet
				{  7, 141543 }, -- Drape of the Mana-Starved
				-- { 16, "ac9423" },
			},
		},
		{ -- Brutallus
			EncounterJournalID = 1883,
			[NORMAL_RAID_DIFF] = {
				{ 1, 147742 }, -- Violent Zealot's Shoulderpads
				{ 2, 147748 }, -- Gauntlets of Dreadful Tenacity
				{ 3, 147765 }, -- Clasp of Burning Demise
				{ 4, 147739 }, -- Rigid Meteorguard Gauntlets
				{ 5, 147756 }, -- Crashing Ember
				{ 6, 147747 }, -- Armbands of Crude Strategy
				{ 7, 147749 }, -- Polished Felfury Helmet
				{ 8, 147755 }, -- Brutallus's Wretched Heart
				{ 9, 147732 }, -- Leggings of Echoing Calamity
			},
		},
		{ -- Malificus
			EncounterJournalID = 1884,
			[NORMAL_RAID_DIFF] = {
				{  1, 147744 }, -- Treads of Disorderly Retreat
				{  2, 147733 }, -- Doomsayer's Ritualistic Vestment
				{  3, 147735 }, -- Cuffs of Fearful Service
				{  4, 147754 }, -- Gory Dreadlord Horn
				{  5, 147741 }, -- Legguards of Unholy Disdain
				{  6, 147758 }, -- Beguiling Revelation
				{  7, 147745 }, -- Taloned Brain-Scrapers
				{  8, 147764 }, -- Cloak of Growing Mistrust
				{  9, 147740 }, -- Plague-Resistant Headcover
				{ 10, 147750 }, -- Malicious Zealot's Legplates
			},
		},
		{ -- Si'vash
			EncounterJournalID = 1885,
			[NORMAL_RAID_DIFF] = {
				{ 1, 147757 }, -- Globule of Submersion
				{ 2, 147731 }, -- Cowl of Plumbed Depths
				{ 3, 147767 }, -- Coral Band of the Abyss
				{ 4, 147761 }, -- Sandblasted Conch
				{ 5, 147737 }, -- Shorebreaker Robes
				{ 6, 147751 }, -- Si'vashi Guard's Breastplate
				{ 7, 147752 }, -- Pauldrons of the Engulfing Tide
				{ 8, 147746 }, -- Glistening Seaspray Legguards
				{ 9, 147736 }, -- Dockthrasher Cinch
			},
		},
		{ -- Apocron
			EncounterJournalID = 1956,
			[NORMAL_RAID_DIFF] = {
				{ 1, 147730 },  -- Ashen Worldscorcher Gloves
				{ 2, 147759 },  -- Charged Felfire Casing
				{ 3, 147760 },  -- Apocron's Energy Core
				{ 4, 147766 },  -- Band of Dark Millennia
				{ 5, 147734 },  -- Spaulders of Forgotten Worlds
				{ 6, 147738 },  -- Doom-Herald's Footpads
				{ 7, 147743 },  -- Harness of Devouring Flame
				{ 8, 147753 },  -- Reaver's Rattling Girdle
			},
		},
		LEGION_WORLD_BOSS_AC_TABLE,
		LEGION_WORLD_BOSS_AC_TABLE2,
	}
}

data["TheEmeraldNightmare"] = {
	EncounterJournalID = 768,
	MapID = 1094,
	ItemBaseLvl = 850,
	AtlasMapID = "TheEmeraldNightmareA",
	ContentType = RAID_CONTENT,
	TableType = RAID_ITTYPE,
	items = {
		{	--Nythendra
			EncounterJournalID = 1703,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 16, nil }, -- ignore the AC: Buggy Fight in LFR
			},
			[NORMAL_RAID_DIFF] = {
				{ 1, 139252 }, -- Preserved Worldseed
				{ 2, 139224 }, -- Insect-Etched Chestplate
				{ 3, 139320 }, -- Ravaged Seed Pod
				{ 4, 139200 }, -- Stained Maggot Squishers
				{ 5, 139249 }, -- Shaladrassil's Blossom
				{ 6, 139251 }, -- Despoiled Dragonscale
				{ 7, 139235 }, -- Wristclamps of Mad Dreams
				{ 8, 139197 }, -- Lifeless Buckled Girdle
				{ 9, 139212 }, -- Creeping String of Larva
				{ 10, 139214 }, -- Greyed Dragonscale Coif
				{ 11, 139321 }, -- Swarming Plaguehive
				{ 12, 139236 }, -- Grubby Silver Ring
				{ 13, 139250 }, -- Unwaking Slumber
				{ 14, 139191 }, -- Ancient Dreamwoven Mantle
				{ 16, "ac10555" }, -- AC: Buggy Fight
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 17, "ac10821" }, -- AC: Mythic: Nythendra
			},
		},
		{	--Il'gynoth, Heart of Corruption
			EncounterJournalID = 1738,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 18, nil }, -- ignore the AC: Took the Red Eye Down in LFR
			},
			[NORMAL_RAID_DIFF] = {
				{ 1, 139237 }, -- Dreadful Cyclopean Signet
				{ 2, 139326 }, -- Wriggling Sinew
				{ 3, 139256 }, -- Sloshing Core of Hatred
				{ 4, 139258 }, -- Radiating Metallic Shard
				{ 5, 139215 }, -- Singular Chain Leggings
				{ 6, 139202 }, -- Dreamsculptor's Gloves
				{ 7, 139324 }, -- Goblet of Nightmarish Ichor
				{ 8, 139206 }, -- Otherworldy Leather Mantle
				{ 9, 139227 }, -- Waistplate of Nameless Horror
				{ 10, 139188 }, -- Celestially Aligned Hood
				{ 11, 139257 }, -- Gore-Drenched Fetish
				{ 12, 139259 }, -- Cube of Malice
				{ 13, 139213 }, -- Gauntlets of Malevolent Intent
				{ 14, 139233 }, -- Pauldrons of Shifting Runes
				{ 15, 139325 }, -- Spontaneous Appendages
				{ 16, 139187 }, -- Cinch of Cosmic Insignficance
				{ 18, "ac10830" }, -- AC: Took the Red Eye Down
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 19, "ac10823" }, -- AC: Mythic: Il'gynoth
			},
		},
		{	--Elerethe Renferal
			EncounterJournalID = 1744,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 16, nil }, -- ignore the AC: Webbing Crashers in LFR
			},
			[NORMAL_RAID_DIFF] = {
				{ 1, 138217 }, -- Pliable Spider Silk Cinch
				{ 2, 139209 }, -- Wristwraps of Broken Trust
				{ 3, 138221 }, -- Gossamer-Spun Greatcloak
				{ 4, 139230 }, -- Storm-Battered Legplates
				{ 5, 139322 }, -- Cocoon of Enforced Solitude
				{ 6, 139204 }, -- Mask of Multitudinous Eyes
				{ 7, 139221 }, -- Patient Ambusher's Hauberk
				{ 8, 139253 }, -- Fel-Bloated Venom Sac
				{ 9, 139255 }, -- Scything Quill
				{ 10, 139229 }, -- Venom-Fanged Barbute
				{ 11, 139219 }, -- Black Venom Sabatons
				{ 12, 139323 }, -- Twisting Wind
				{ 13, 139190 }, -- Ragged Horrorweave Leggings
				{ 14, 139254 }, -- Shrieking Bloodstone
				{ 16, "ac10771" }, -- AC: Webbing Crashers
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 17, "ac10822" }, -- AC: Mythic: Elerethe Renferal
			},
		},
		{	--Ursoc
			EncounterJournalID = 1667,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 18, nil }, -- ignore the AC: Scare Bear in LFR
			},
			[NORMAL_RAID_DIFF] = {
				{ 1, 139327 }, -- Unbridled Fury
				{ 2, 139239 }, -- Cursed Beartooth Necklace
				{ 3, 139196 }, -- Ragged Fur Wristwraps
				{ 4, 139328 }, -- Ursoc's Rending Paw
				{ 5, 139260 }, -- Bloodied Bear Fang
				{ 6, 139217 }, -- Matted Fur Pauldrons
				{ 7, 139234 }, -- Trampling Warboots
				{ 8, 139330 }, -- Heightened Senses
				{ 9, 139208 }, -- Scarred Ragefang Chestpiece
				{ 10, 139195 }, -- Crimson Wool-Lined Slippers
				{ 11, 139329 }, -- Bloodthirsty Instinct
				{ 12, 139261 }, -- Tuft of Ironfur
				{ 13, 139201 }, -- Splotched Bloodfur Leggings
				{ 14, 139262 }, -- Reverberating Femur
				{ 15, 139220 }, -- Scored Ironclaw Sabatons
				{ 16, 139226 }, -- Primal Gauntlets of Rage
				{ 18, "ac10753" }, -- AC: Scare Bear
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 19, "ac10824" }, -- AC: Mythic: Ursoc
			},
		},
		{	--Dragons of Nightmare, Ysondre
			EncounterJournalID = 1704,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 18, nil }, -- ignore the AC: Imagined Dragons World Tour in LFR
			},
			[NORMAL_RAID_DIFF] = {
				{ 1, 138219 }, -- Dragonspur Wristguards
				{ 2, 138212 }, -- Handwraps of Delusional Power
				{ 3, 138215 }, -- Dreamscale Inlaid Vestments
				{ 4, 138225 }, -- Phantasmal Echo
				{ 5, 138227 }, -- Entrancing Stone
				{ 6, 138214 }, -- Gauntlets of the Demented Mind
				{ 7, 138216 }, -- Horror Inscribed Chestguard
				{ 8, 138218 }, -- Dragonbone Wristclamps
				{ 9, 138220 }, -- Mindrend Band
				{ 10, 138222 }, -- Vial of Nightmare Fog
				{ 11, 138224 }, -- Unstable Horrorslime
				{ 12, 138211 }, -- Malignant Sabatons
				{ 13, 138228 }, -- Bioluminescent Mushroom
				{ 14, 139205 }, -- Cowl of Fright
				{ 15, 138226 }, -- Nightmare Engulfed Jewel
				{ 16, 136903, "pet1723" }, -- Nightmare Whelpling
				{ 18, "ac10663" }, -- AC: Imagined Dragons World Tour
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 19, "ac10825" }, -- AC: Mythic: Dragons of Nightmare
			},
		},
		{	--Cenarius
			EncounterJournalID = 1750,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 16, nil }, -- ignore the AC: Use the Force(s) in LFR
			},
			[NORMAL_RAID_DIFF] = {
				{ 1, 139207 }, -- Tunic of the Grove Keeper
				{ 2, 139194 }, -- Cozy Dryad Hoof-Socks
				{ 3, 139211 }, -- Laughing Sister's Pouch-Chain
				{ 4, 139333 }, -- Horn of Cenarius
				{ 5, 139264 }, -- Uplifting Emerald
				{ 6, 139192 }, -- Mantle of Perpetual Bloom
				{ 7, 139263 }, -- Blessing of Cenarius
				{ 8, 139225 }, -- Fitted Ironbark Gauntlets
				{ 9, 139248 }, -- Evergreen Vinewrap Drape
				{ 10, 139334 }, -- Nature's Call
				{ 11, 139231 }, -- Crown of Steely Brambles
				{ 12, 139218 }, -- Thorny Bramblemail Pauldrons
				{ 13, 139265 }, -- Radiant Dragon Egg
				{ 14, 139198 }, -- Forest-Lord's Waistwrap
				{ 16, "ac10772" }, -- AC: Use the Force(s)
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 17, "ac10826" }, -- AC: Mythic: Cenarius
			},
		},
		{	--Xavius
			EncounterJournalID = 1726,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 19, nil }, -- ignore the AC: I Attack the Darkness in LFR
			},
			[NORMAL_RAID_DIFF] = {
				{ 1, 139266 }, -- Fragment of Eternal Spite
				{ 2, 139332 }, -- Blackened Portalstone Necklace
				{ 3, 139336 }, -- Bough of Corruption
				{ 4, 139216 }, -- Disjointed Linkage Leggings
				{ 5, 139189 }, -- Hood of Darkened Visions
				{ 6, 139193 }, -- Maddening Robe of Secrets
				{ 7, 139228 }, -- Eon-Tempered Waistplate
				{ 8, 139232 }, -- Midnight Herald's Pauldrons
				{ 9, 139267 }, -- Azsharan Councillor's Clasp
				{ 10, 139268 }, -- Nightmarish Elm Branch
				{ 11, 139222 }, -- Manacles of the Nightmare Colossus
				{ 12, 139199 }, -- Boots of Endless Betrayal
				{ 13, 139203 }, -- Repulsive Leathery Pants
				{ 14, 139238 }, -- Twice-Warped Azsharan Signet
				{ 15, 139335 }, -- Grotesque Statuette
				{ 16, 139269 }, -- Crystallized Drop of Eternity
				{ 17, 141006 }, -- The First Satyr's Spaulders
				{ 19, "ac10755" }, -- AC: I Attack the Darkness
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 20, "ac10827" }, -- AC: Mythic: Xavius
			},
		},
		LEGION_RAID1_AC_TABLE,
	},
}

-- Invasion Points
data["InvasionPoints"] = {
	EncounterJournalID = 959,
	MapID = 1135,
	--AtlasMapID = "InvasionPoints",
	ContentType = RAID_CONTENT,
	items = {
		{	-- Matron Folnuna
			EncounterJournalID = 2010,
			[NORMAL_RAID_DIFF] = {
				{ 1 , 152349 }, -- Nefarious Light-Step Slippers
				{ 2 , 152053 }, -- Essence of the Burgeoning Brood
				{ 3 , 152346 }, -- Frigid Earing
				{ 4 , 152372 }, -- Waistguard of Devilish Deeds
				{ 5 , 152359 }, -- Vile Drifter's Footpads
				{ 6 , 152376 }, -- Crown of Burning Resolve
				{ 7 , 152375 }, -- Gauntlets of Barbaric Cruelty
				{ 8 , 152380 }, -- Waistguard of Fel Magics
				{ 9 , 152356 }, -- Fel-Absorbant Wristbands
				{ 10, 152369 }, -- Helm of the Vigilant Eye
				{ 11, 152371 }, -- Shoulderguards of the Despondent Masses
				{ 12, 152358 }, -- Imp-Overseer's Vest
				{ 13, 152360 }, -- Gloves of Barbarous Feats
				{ 14, 152354 }, -- Accursed Defiler's Mantle
			},
		},
		{	-- Mistress Alluradel
			EncounterJournalID = 2011,
			[NORMAL_RAID_DIFF] = {
				{ 1 , 152362 }, -- Leggings of Heinous Acts
				{ 2 , 152379 }, -- Spaulders of Vile Determination
				{ 3 , 152366 }, -- Enthralling Chain Armor
				{ 4 , 152372 }, -- Waistguard of Devilish Deeds
				{ 5 , 152374 }, -- Soul Crushing Stompers
				{ 6 , 152378 }, -- Breastplate of Terminal End
				{ 7 , 152363 }, -- Fel-Spike Shoulderpads
				{ 8 , 152364 }, -- Cinch of Detestable Guile
				{ 9 , 152351 }, -- Mesmerizing Soul Hood
				{ 10, 152354 }, -- Accursed Defiler's Mantle
				{ 11, 152294 }, -- Fel Mistress' Brand
				{ 12, 152373 }, -- Poison-Barbed Bracers
				{ 13, 152030 }, -- Scourge of Perverse Desire
				{ 14, 152349 }, -- Nefarious Light-Step Slippers
			},
		},
		{	-- Inquisitor Meto
			EncounterJournalID = 2012,
			[NORMAL_RAID_DIFF] = {
				{ 1 , 152364 }, -- Cinch of Detestable Guile
				{ 2 , 152381 }, -- Tainted Corruptor's Vambraces
				{ 3 , 152353 }, -- Robes of Demonic Purpose
				{ 4 , 152370 }, -- Legguards of Doomed Chattel
				{ 5 , 152344 }, -- Meto's Orb of Entropy
				{ 6 , 152361 }, -- Horned Hood of Retaliation
				{ 7 , 152378 }, -- Breastplate of Terminal End
				{ 8 , 152290 }, -- Censer of Dark Intent
				{ 9 , 152368 }, -- Fel-Linked Crushers
				{ 10, 152350 }, -- Gloves of Grim Direction
				{ 11, 152371 }, -- Shoulderguards of the Despondent Masses
				{ 12, 152380 }, -- Waistguard of Fel Magics
				{ 13, 152349 }, -- Nefarious Light-Step Slippers
				{ 14, 152359 }, -- Vile Drifter's Footpads
			},
		},
		{	-- Occularus
			EncounterJournalID = 2013,
			[NORMAL_RAID_DIFF] = {
				{ 1 , 152377 }, -- Gore-Soaked Legplates
				{ 2 , 152381 }, -- Tainted Corruptor's Vambraces
				{ 3 , 152355 }, -- Sash of Diabolic Preparation
				{ 4 , 152374 }, -- Soul Crushing Stompers
				{ 5 , 152351 }, -- Mesmerizing Soul Hood
				{ 6 , 152354 }, -- Accursed Defiler's Mantle
				{ 7 , 152367 }, -- Sabatons of Ceaseless Assault
				{ 8 , 152369 }, -- Helm of the Vigilant Eye
				{ 9 , 152358 }, -- Imp-Overseer's Vest
				{ 10, 152373 }, -- Poison-Barbed Bracers
				{ 11, 152360 }, -- Gloves of Barbarous Feats
				{ 12, 152347 }, -- Occularus' Unblemished Lens
			},
		},
		{	-- Sotanathor
			EncounterJournalID = 2014,
			[NORMAL_RAID_DIFF] = {
				{ 1 , 152377 }, -- Gore-Soaked Legplates
				{ 2 , 152379 }, -- Spaulders of Vile Determination
				{ 3 , 152366 }, -- Enthralling Chain Armor
				{ 4 , 152353 }, -- Robes of Demonic Purpose
				{ 5 , 152372 }, -- Waistguard of Devilish Deeds
				{ 6 , 152361 }, -- Horned Hood of Retaliation
				{ 7 , 152348 }, -- Sotanathor's Thundring Hoof
				{ 8 , 152365 }, -- Bracers of Diabolic Fury
				{ 9 , 152292 }, -- Spike of Immortal Command
				{ 10, 152368 }, -- Fel-Linked Crushers
				{ 11, 152362 }, -- Leggings of Heinous Acts
				{ 12, 152350 }, -- Gloves of Grim Direction
				{ 13, 152375 }, -- Gauntlets of Barbaric Cruelty
				{ 14, 152352 }, -- Subjugated Drudge's Leggings
			},
		},
		{	-- Pit Lord Vilemus
			EncounterJournalID = 2015,
			[NORMAL_RAID_DIFF] = {
				{ 1 , 152368 }, -- Fel-Linked Crushers
				{ 2 , 152370 }, -- Legguards of Doomed Chattel
				{ 3 , 152355 }, -- Sash of Diabolic Preparation
				{ 4 , 152374 }, -- Soul Crushing Stompers
				{ 5 , 152376 }, -- Crown of Burning Resolve
				{ 6 , 152363 }, -- Fel-Spike Shoulderpads
				{ 7 , 152365 }, -- Bracers of Diabolic Fury
				{ 8 , 152352 }, -- Subjugated Drudge's Leggings
				{ 9 , 152345 }, -- Vilemus' Bile
				{ 10, 152356 }, -- Fel-Absorbant Wristbands
				{ 11, 152378 }, -- Breastplate of Terminal End
				{ 12, 152360 }, -- Gloves of Barbarous Feats
				{ 13, 152367 }, -- Sabatons of Ceaseless Assault
			},
		},
	},
}

data["TheNighthold"] = {
	EncounterJournalID = 786,
	MapID = 1088,
	ItemBaseLvl = 875,
	AtlasMapID = "TheNightholdA",
	ContentType = RAID_CONTENT,
	TableType = RAID_ITTYPE,
	items = {
		{	--Skorpyron
			EncounterJournalID = 1706,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 16, nil }, -- ignore the AC: Cage Rematch in LFR
			},
			[NORMAL_RAID_DIFF] = {
				{ 1, 140902 }, -- Jagged Carapace Wristclamps
				{ 2, 140876 }, -- Stinger Resistant Bracers
				{ 3, 140790 }, -- Claw of the Crystalline Scorpid
				{ 4, 140789 }, -- Animated Exoskeleton
				{ 5, 140884 }, -- Leystone-Toe Kickers
				{ 6, 140901 }, -- Vintage Suramar Nobility Hat
				{ 7, 140888 }, -- Scorpid Handler's Gloves
				{ 8, 140875 }, -- Arcanochitin Hauberk
				{ 9, 140862 }, -- Gnawed Nightfallen Britches
				{ 10, 140849 }, -- Antiquated Highborne Cinch
				{ 11, 140815 }, -- Infused Chitin Fragment
				{ 12, 140898 }, -- Radiant String of Scorpid Eyes
				{ 13, 140840 }, -- Chittering Mandible
				{ 14, 140827 }, -- Manatoxin Gland
				{ 16, "ac10678" }, -- AC: Cage Rematch
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 17, "ac10840" }, -- AC: Mythic: Skorpyron
			},
		},
		{	--Chronomatic Anomaly
			EncounterJournalID = 1725,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 13, 138828, false, [ATLASLOOT_IT_FILTERIGNORE] = true }, -- Illusion: Chronos
				{ 16, nil }, -- ignore the AC: Grand Opening in LFR
			},
			[NORMAL_RAID_DIFF] = {
				{ 1, 140872 }, -- Pauldrons of Warped Memory
				{ 2, 140831 }, -- Suspended Nightwell Droplet
				{ 3, 140848 }, -- Robes of Fluctuating Energy
				{ 4, 140882 }, -- Chrono-Tempered Legplates
				{ 5, 140792 }, -- Erratic Metronome
				{ 6, 140863 }, -- Temporally Displaced Gloves
				{ 7, 140853 }, -- Chaos-Scarred Mantle
				{ 8, 140903 }, -- Hood of Fading Opportunity
				{ 9, 140860 }, -- Stutterstep Treads
				{ 10, 140791 }, -- Royal Dagger Haft
				{ 11, 140879 }, -- Gauntlets of Fractured Eons
				{ 12, 140821 }, -- Precipice of Eternity
				{ 13, 138828, false, [ATLASLOOT_IT_FILTERIGNORE] = true }, -- Illusion: Chronos
				{ 14, 140894 }, -- Zealous Timestone Pendant
				{ 15, 140843 }, -- Flickering Timespark
				{ 16, "ac10697" }, -- AC: Grand Opening
			},
			[HEROIC_PRE_DIFF] = {
			GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 13, 138828, false, [ATLASLOOT_IT_FILTERIGNORE] = true }, -- Illusion: Chronos
			},
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 13, 138828, false, [ATLASLOOT_IT_FILTERIGNORE] = true }, -- Illusion: Chronos
				{ 17, "ac10842" }, -- AC: Mythic: Chronomatic Anomaly
			},
		},
		{	--Trilliax
			EncounterJournalID = 1731,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 27, nil }, -- ignore the AC: Gluten Free in LFR
			},
			[NORMAL_RAID_DIFF] = {
				{ 1, 140812 }, -- Soggy Manascrubber Brush
				{ 2, 138367 }, -- Cloak of Enveloped Dissonance
				{ 3, 140851 }, -- Nighthold Custodian's Hood
				{ 4, 140793 }, -- Perfectly Preserved Cake
				{ 5, 140871 }, -- Pertinacious Legplates
				{ 6, 138364 }, -- Dreadwyrm Greatcloak
				{ 7, 138368 }, -- Eagletalon Cloak
				{ 8, 138372 }, -- Cloak of Bound Elements
				{ 9, 140794 }, -- Arcanogolem Digit
				{ 10, 138375 }, -- Cape of Second Sight
				{ 11, 138371 }, -- Doomblade Shadowwrap
				{ 12, 140854 }, -- Perpetually Muddy Sandals
				{ 13, 138365 }, -- Cloak of Everburning Knowledge
				{ 14, 140880 }, -- Gilded Nightborne Waistplate
				{ 15, 138373 }, -- Cloak of Azj'Aqir
				{ 16, 138369 }, -- Greatmantle of the Highlord
				{ 17, 140869 }, -- Sterilizer's Insulated Gauntlets
				{ 18, 140865 }, -- Tunic of Unwavering Devotion
				{ 19, 140838 }, -- Construct Personality Sphere
				{ 20, 140904 }, -- Immaculately Polished Boots
				{ 21, 138366 }, -- Cloak of the Astral Warden
				{ 22, 138370 }, -- Purifier's Drape
				{ 23, 138374 }, -- Greatcloak of the Obsidian Aspect
				{ 24, 140858 }, -- Cake Carrier's Girdle
				{ 25, 140818 }, -- Foreign Contaminant
				{ 27, "ac10742" }, -- AC: Gluten Free
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 28, "ac10843" }, -- AC: Mythic: Trilliax
			},
		},
		{	--Spellblade Aluriel
			EncounterJournalID = 1751,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 16, nil }, -- ignore the AC: A Change In Scenery in LFR
			},
			[NORMAL_RAID_DIFF] = {
				{ 1, 140852 }, -- Master Warmage's Leggings
				{ 2, 140878 }, -- Duskwatch Plate Bracers
				{ 3, 140895 }, -- Spellblade's Gemmed Signet
				{ 4, 140867 }, -- Sabatons of Burning Steps
				{ 5, 140832 }, -- Heart of Frost
				{ 6, 140796 }, -- Entwined Elemental Foci
				{ 7, 140813 }, -- Arcana Crux
				{ 8, 140905 }, -- Gloves of Synchronus Elements
				{ 9, 140877 }, -- Captain's Parade Breastplate
				{ 10, 140834 }, -- Soul of Flame
				{ 11, 140866 }, -- Nightborne Battle-Magus Hood
				{ 12, 140868 }, -- Emblazoned Duskwatch Belt
				{ 13, 140795 }, -- Aluriel's Mirror
				{ 14, 140850 }, -- Bracers of Harnessed Flame
				{ 16, "ac10817" }, -- AC: A Change In Scenery
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 17, "ac10844" }, -- AC: Mythic: Spellblade Aluriel
			},
		},
		{	--Tichondrius
			EncounterJournalID = 1762,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 23, nil }, -- ignore the AC: Not For You in LFR
			},
			[NORMAL_RAID_DIFF] = {
				{ 1, 138363 }, -- Shoulderplates of the Obsidian Aspect
				{ 2, 138336 }, -- Mantle of the Astral Warden
				{ 3, 140855 }, -- Dreadlord's Tattered Wingcover
				{ 4, 138348 }, -- Pauldrons of Bound Elements
				{ 5, 138321 }, -- Mantle of Everburning Knowledge
				{ 6, 140844 }, -- Archaic Nathrezim Keepsake
				{ 7, 138337 }, -- Pauldrons of Enveloped Dissonance
				{ 8, 138380 }, -- Shoulderguards of Second Sight
				{ 9, 138322 }, -- Purifier's Mantle
				{ 10, 138361 }, -- Dreadwyrm Shoulderguards
				{ 11, 138338 }, -- Doomblade Spaulders
				{ 12, 140798 }, -- Icon of Rot
				{ 13, 140892 }, -- Goresmeared Abyssal Waistplate
				{ 14, 138323 }, -- Pauldrons of Azj'Aqir
				{ 15, 140797 }, -- Fang of Tichcondrius
				{ 16, 138362 }, -- Pauldrons of the Highlord
				{ 17, 140906 }, -- Ring of Exclusive Servitude
				{ 18, 140819 }, -- Vampiric Fetish
				{ 19, 140859 }, -- Girdle of Nefarious Strategy
				{ 20, 138347 }, -- Eagletalon Spaulders
				{ 21, 140824 }, -- Writ of Subjugation
				{ 23, "ac10704" }, -- AC: Not For You
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 24, "ac10847" }, -- AC: Mythic: Tichondrius
			},
		},
		{	--Krosus
			EncounterJournalID = 1713,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 24, nil }, -- ignore the AC: Burning Bridges in LFR
			},
			[NORMAL_RAID_DIFF] = {
				{ 1, 138320 }, -- Finery of Azj'Aqir
				{ 2, 140835 }, -- Unkindled Ember
				{ 3, 140870 }, -- Architect's Coif of Despair
				{ 4, 140816 }, -- Fingernail of the Fel Brute
				{ 5, 138325 }, -- Tunic of Enveloped Dissonance
				{ 6, 140825 }, -- Felfire Pitch
				{ 7, 138318 }, -- Robe of Everburning Knowledge
				{ 8, 140899 }, -- Beleron's Choker of Misery
				{ 9, 138376 }, -- Tunic of Second Sight
				{ 10, 140907 }, -- Bridgebreaker Gauntlets
				{ 11, 140800 }, -- Pharamere's Forbidden Grimore
				{ 12, 140887 }, -- Man'ari Skullbuckled Cinch
				{ 13, 138346 }, -- Raiment of Shackled Elements
				{ 14, 138350 }, -- Breastplate of the Highlord
				{ 15, 138324 }, -- Robe of the Astral Warden
				{ 16, 140857 }, -- Well-Flattened Wristguards
				{ 17, 138319 }, -- Purifier's Cassock
				{ 18, 138326 }, -- Doomblade Tunic
				{ 19, 138339 }, -- Eagletalon Tunic
				{ 20, 140799 }, -- Might of Krosus
				{ 21, 138351 }, -- Chestplate of the Obsidian Aspect
				{ 22, 138349 }, -- Dreadwyrm Breastplate
				{ 24, "ac10575" }, -- AC: Burning Bridges
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 25, "ac10848" }, -- AC: Mythic: Krosus
			},
		},
		{	--High Botanist Tel'arn
			EncounterJournalID = 1761,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 16, nil }, -- ignore the AC: Fruit of All Evil in LFR
			},
			[NORMAL_RAID_DIFF] = {
				{ 1, 140874 }, -- Thistle-Proof Thorngrabbers
				{ 2, 140861 }, -- Grove-Tender's Moccasins
				{ 3, 140908 }, -- Trousers of Cultivation
				{ 4, 140822 }, -- Breath of Dusk
				{ 5, 140839 }, -- Parasitic Spore
				{ 6, 140886 }, -- Woven Lasher Tendril Bracers
				{ 7, 140873 }, -- Shal'dorei Weedstompers
				{ 8, 140802 }, -- Nightblooming Frond
				{ 9, 140801 }, -- Fury of the Burning Sky
				{ 10, 140881 }, -- Eventide Casque
				{ 11, 140883 }, -- Shoulderguard of the Eclipse
				{ 12, 140896 }, -- Ring of Braided Stems
				{ 13, 140836 }, -- Sunflare Coal
				{ 16, "ac10754" }, -- AC: Fruit of All Evil
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 17, "ac10846" }, -- AC: Mythic: High Botanist Tel'arn
			},
		},
		{	--Star Augur Etraeus
			EncounterJournalID = 1732,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 24, nil }, -- ignore the AC: Elementalry! in LFR
			},
			[NORMAL_RAID_DIFF] = {
				{ 1, 140804 }, -- Star Gate
				{ 2, 138328 }, -- Gloves of Enveloped Dissonance
				{ 3, 140909 }, -- Astromancer's Greatcloak
				{ 4, 138340 }, -- Eagletalon Gauntlets
				{ 5, 138352 }, -- Dreadwyrm Gauntlets
				{ 6, 138329 }, -- Doomblade Gauntlets
				{ 7, 138341 }, -- Gauntlets of Bound Elements
				{ 8, 140891 }, -- Sabatons of Unchanging Fate
				{ 9, 140864 }, -- Mantle of the Torn Sky
				{ 10, 140841 }, -- Tempest of the Heavens
				{ 11, 140845 }, -- Glistening Meteorite Shard
				{ 12, 138311 }, -- Clutch of Azj'Aqir
				{ 13, 138377 }, -- Gloves of Second Sight
				{ 14, 138354 }, -- Gauntlets of the Obsidian Aspect
				{ 15, 140803 }, -- Etraeus' Celestial Map
				{ 16, 140900 }, -- Brooch of the Astral Scryer
				{ 17, 140833 }, -- Sundered Comet
				{ 18, 138310 }, -- Purifier's Gloves
				{ 19, 138327 }, -- Gloves of the Astral Warden
				{ 20, 140885 }, -- Treads of Galactic Odyssey
				{ 21, 138309 }, -- Gloves of Everburning Knowledge
				{ 22, 138353 }, -- Gauntlets of the Highlord
				{ 24, "ac10851" }, -- AC: Elementalry!
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 25, "ac10845" }, -- AC: Mythic: Star Augur Etraeus
			},
		},
		{	--Grand Magistrix Elisande
			EncounterJournalID = 1743,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 25, nil }, -- ignore the AC: Infinitesimal in LFR
			},
			[NORMAL_RAID_DIFF] = {
				{ 1, 140893 }, -- Eternally Recurring Bracers
				{ 2, 138355 }, -- Dreadwyrm Crown
				{ 3, 138332 }, -- Doomblade Cowl
				{ 4, 138313 }, -- Purifier's Gorget
				{ 5, 140890 }, -- Belt of Celestial Alignment
				{ 6, 140805 }, -- Ephemeral Paradox
				{ 7, 140910 }, -- Cloak of Temporal Recalibration
				{ 8, 138314 }, -- Eyes of Azj'Aqir
				{ 9, 140806 }, -- Convergence of Fates
				{ 10, 140810 }, -- Farsight Spiritjewel
				{ 11, 140837 }, -- Exothermic Core
				{ 12, 140911 }, -- Mantle of Prestidigitation
				{ 13, 138342 }, -- Eagletalon Cowl
				{ 14, 140889 }, -- Bracers of Impossible Choices
				{ 15, 138343 }, -- Helm of Bound Elements
				{ 16, 138330 }, -- Hood of the Astral Warden
				{ 17, 140842 }, -- Collapsing Epoch
				{ 18, 138331 }, -- Hood of Enveloped Dissonance
				{ 19, 138356 }, -- Helmet of the Highlord
				{ 20, 140912 }, -- Waistplate of Fractured Realities
				{ 21, 138312 }, -- Hood of Everburning Knowledge
				{ 22, 138378 }, -- Mask of Second Sight
				{ 23, 138357 }, -- Warhelm of the Obsidian Aspect
				{ 25, "ac10699" }, -- AC: Infinitesimal
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 26, "ac10849" }, -- AC: Mythic: Grand Magistrix Elisande
			},
		},
		{	--Gul'dan
			EncounterJournalID = 1737,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 26, nil }, -- ignore the AC: I've Got My Eyes On You in LFR
			},
			[NORMAL_RAID_DIFF] = {
				{ 1, 140897 }, -- Ring of the Scoured Clan
				{ 2, 138359 }, -- Legplates of the Highlord
				{ 3, 140913 }, -- Breastplate of the Remembered King
				{ 4, 138344 }, -- Eagletalon Legchains
				{ 5, 138317 }, -- Leggings of Azj'Aqir
				{ 6, 138360 }, -- Legplates of the Obsidian Aspect
				{ 7, 138333 }, -- Leggings of the Astral Warden
				{ 8, 140817 }, -- Lionshead Lapel Clasp
				{ 9, 140914 }, -- Outcast Wanderer's Footrags
				{ 10, 138345 }, -- Leggings of Bound Elements
				{ 11, 140809 }, -- Whispers in the Dark
				{ 12, 138334 }, -- Leggings of Enveloped Dissonance
				{ 13, 140820 }, -- Phial of Fel Blood
				{ 14, 140919 }, -- High Shadow Councilor's Wrap
				{ 15, 140826 }, -- Felstained Jawbone Fragments
				{ 16, 138379 }, -- Legwraps of Second Sight
				{ 17, 140807 }, -- Infernal Contract
				{ 18, 138358 }, -- Dreadwyrm Legplates
				{ 19, 140917 }, -- Netherbranded Shoulderpads
				{ 20, 138335 }, -- Doomblade Pants
				{ 21, 138315 }, -- Leggings of Everburning Knowledge
				{ 22, 140823 }, -- Warchief's Shattered Tusk
				{ 23, 138316 }, -- Purifier's Leggings
				{ 24, 140808 }, -- Draught of Souls
				{ 26, "ac10696" }, -- AC: I've Got My Eyes On You
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 27, "ac10850" }, -- AC: Mythic: Gul'dan
			},
		},
		{	--Tier 19 Sets
			name = format(AL["Tier %d Sets"], 19),
			ExtraList = true,
			[NORMAL_DIFF] = "AtlasLoot_Collections:TIERSETS:19",
		},
		LEGION_RAID1_AC_TABLE,
	},
}

-- Tomb of Sargeras
data["TombofSargeras"] = {
	EncounterJournalID = 875,
	MapID = 1147,
	ItemBaseLvl = 890,
	AtlasMapID = "TombofSargerasA",
	ContentType = RAID_CONTENT,
	TableType = RAID_ITTYPE,
	items = {
		{	-- Goroth
			EncounterJournalID = 1862,
			[RF_DIFF] = NORMAL_RAID_DIFF,
			[NORMAL_RAID_DIFF] = {
				{ 1 , 147055 }, -- Belt of Screaming Slag
				{ 2 , 147108 }, -- Brand of Relentless Agony
				{ 3 , 147076 }, -- Charred Hymnal of the Moon
				{ 4 , 147039 }, -- Cinch of Sizzling Flesh
				{ 5 , 146984 }, -- Cloak of Stifling Brimstone
				{ 6 , 146986 }, -- Emberscatter Treads
				{ 7 , 147112 }, -- Felsoul Vortex
				{ 8 , 147022 }, -- Feverish Carapace
				{ 9 , 147104 }, -- Icon of Perverse Animation
				{ 10, 147084 }, -- Imploding Infernal Star
				{ 11, 147009 }, -- Infernal Cinders
				{ 12, 147065 }, -- Lava-Slough Legguards
				{ 13, 146992 }, -- Legwraps of Fused Loathing
				{ 14, 147057 }, -- Pain-Singed Armguards
				{ 15, 147069 }, -- Shoulderplates of Crackling Flame
				{ 16, 147027 }, -- Spirebreaker Harness
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = NORMAL_RAID_DIFF,
		},
		{	-- Demonic Inquisition
			EncounterJournalID = 1867,
			[RF_DIFF] = NORMAL_RAID_DIFF,
			[NORMAL_RAID_DIFF] = {
				{ 1 , 147003 }, -- Barbaric Mindslaver
				{ 2 , 147080 }, -- Blood of the Unworthy
				{ 3 , 147073 }, -- Bonemeal-Crusted Armplates
				{ 4 , 147035 }, -- Bonespur Studded Legwraps
				{ 5 , 146998 }, -- Braided Torture Lash
				{ 6 , 147010 }, -- Cradle of Anguish
				{ 7 , 147147 }, -- Crown of the Arcane Tempest
				{ 8 , 147130 }, -- Demonbane Faceguard
				{ 9 , 147183 }, -- Diabolic Helm
				{ 10, 147172 }, -- Fanged Slayer's Helm
				{ 11, 147051 }, -- Flesh Raking Leggings
				{ 12, 147124 }, -- Gravewarden Visage
				{ 13, 147178 }, -- Helmet of the Skybreaker
				{ 14, 147165 }, -- Hood of Blind Absolution
				{ 15, 147077 }, -- Inexorable Truth Serum
				{ 16, 147096 }, -- Inquisition's Master Key
				{ 17, 146996 }, -- Mantle of Broken Spirits
				{ 18, 147053 }, -- Pauldrons of the Gibbering Eye
				{ 19, 147160 }, -- Radiant Lightbringer Crown
				{ 20, 147041 }, -- Sinew-Stitched Wristguards
				{ 21, 147088 }, -- Smoldering Thumbscrews
				{ 22, 147136 }, -- Stormheart Headdress
				{ 23, 147013 }, -- String of Extracted Incisors
				{ 24, 147190 }, -- Titanic Onslaught Greathelm
				{ 25, 147142 }, -- Wildstalker Helmet
				{ 26, 147154 }, -- Xuen's Helm
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = NORMAL_RAID_DIFF,
		},
		{	-- Harjatan
			EncounterJournalID = 1856,
			[RF_DIFF] = NORMAL_RAID_DIFF,
			[NORMAL_RAID_DIFF] = {
				{ 1 , 147100 }, -- Calcified Barnacle
				{ 2 , 147002 }, -- Charm of the Rising Tide
				{ 3 , 147129 }, -- Demonbane Gauntlets
				{ 4 , 147182 }, -- Diabolic Gloves
				{ 5 , 147037 }, -- Dripping Arcfin Shoulderpads
				{ 6 , 147171 }, -- Fanged Slayer's Handguards
				{ 7 , 147029 }, -- Glacier Walkers
				{ 8 , 147164 }, -- Gloves of Blind Absolution
				{ 9 , 147146 }, -- Gloves of the Arcane Tempest
				{ 10, 147123 }, -- Gravewarden Handguards
				{ 11, 147177 }, -- Grips of the Skybreaker
				{ 12, 147109 }, -- Harjatan's Leering Eye
				{ 13, 147043 }, -- Hauberk of Frozen Mist
				{ 14, 147092 }, -- Ice-Threaded Conch
				{ 15, 147045 }, -- Insulated Finpads
				{ 16, 147159 }, -- Radiant Lightbringer Gauntlets
				{ 17, 147000 }, -- Ravenous Devotee's Bracelets
				{ 18, 146994 }, -- Robe of Aqueous Command
				{ 19, 147020 }, -- Scaled Band of Servitude
				{ 20, 147071 }, -- Shiversleet Waistguard
				{ 21, 147135 }, -- Stormheart Gloves
				{ 22, 147189 }, -- Titanic Onslaught Handguards
				{ 23, 147067 }, -- Wave-Hammered Breastplate
				{ 24, 147141 }, -- Wildstalker Gauntlets
				{ 25, 147153 }, -- Xuen's Gauntlets
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = NORMAL_RAID_DIFF,
		},
		{	-- Sisters of the Moon
			EncounterJournalID = 1903,
			[RF_DIFF] = NORMAL_RAID_DIFF,
			[NORMAL_RAID_DIFF] = {
				{ 1 , 147097 }, -- Blessing of the White Lady
				{ 2 , 147005 }, -- Chalice of Moonlight
				{ 3 , 147101 }, -- Chiseled Starlight
				{ 4 , 147068 }, -- Cuirass of Blinding Dawn
				{ 5 , 147061 }, -- Dusk-Crusher Handguards
				{ 6 , 147089 }, -- Ferocity of the Devout
				{ 7 , 147033 }, -- Lunar-Wrath Headgear
				{ 8 , 147054 }, -- Mantle of Waning Radiance
				{ 9 , 147031 }, -- Moonfire Stranglers
				{ 10, 147105 }, -- Moontalon's Feather
				{ 11, 147078 }, -- Mote of Astral Suffusion
				{ 12, 146997 }, -- Shoulderpads of Whispering Twilight
				{ 13, 146987 }, -- Slippers of Enduring Vigilance
				{ 14, 147017 }, -- Tarnished Sentinel Medallion
				{ 15, 147012 }, -- Umbral Moonglaives
				{ 16, 147056 }, -- Waistguard of Interminable Unity
				{ 17, 147021 }, -- Yathae's Thumb Ring
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = NORMAL_RAID_DIFF,
		},
		{	-- Mistress Sassz'ine
			EncounterJournalID = 1861,
			[RF_DIFF] = NORMAL_RAID_DIFF,
			[NORMAL_RAID_DIFF] = {
				{ 1 , 147049 }, -- Azure Squallshaper's Helm
				{ 2 , 147131 }, -- Demonbane Leggings
				{ 3 , 147184 }, -- Diabolic Leggings
				{ 4 , 147173 }, -- Fanged Slayer's Legguards
				{ 5 , 147113 }, -- Flawless Hurricane Pearl
				{ 6 , 147093 }, -- Globe of Frothing Eddies
				{ 7 , 147125 }, -- Gravewarden Legplates
				{ 8 , 147028 }, -- Hide of the Abyssal Behemoth
				{ 9 , 146990 }, -- Hundred-Fathom Veil
				{ 10, 147059 }, -- Iron Ballast Sabatons
				{ 11, 147166 }, -- Leggings of Blind Absolution
				{ 12, 147148 }, -- Leggings of the Arcane Tempest
				{ 13, 147179 }, -- Legguards of the Skybreaker
				{ 14, 147023 }, -- Leviathan's Hunger
				{ 15, 147085 }, -- Mutated Nautilus
				{ 16, 147081 }, -- Pungent Chum
				{ 17, 147161 }, -- Radiant Lightbringer Greaves
				{ 18, 147004 }, -- Sea Star of the Depthmother
				{ 19, 146985 }, -- Shroud of the Drowned Adherent
				{ 20, 147137 }, -- Stormheart Legguards
				{ 21, 147016 }, -- Terror From Below
				{ 22, 147191 }, -- Titanic Onslaught Greaves
				{ 23, 147011 }, -- Vial of Ceaseless Toxins
				{ 24, 147143 }, -- Wildstalker Leggings
				{ 25, 147155 }, -- Xuens' Legguards
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = NORMAL_RAID_DIFF,
		},
		{	-- The Desolate Host
			EncounterJournalID = 1896,
			[RF_DIFF] = NORMAL_RAID_DIFF,
			[NORMAL_RAID_DIFF] = {
				{ 1 , 147063 }, -- Armet of the Rotten Mind
				{ 2 , 147086 }, -- Befouled Effigy of Elune
				{ 3 , 147128 }, -- Demonbane Shroud
				{ 4 , 147181 }, -- Diabolic Shroud
				{ 5 , 147145 }, -- Drape of the Arcane Tempest
				{ 6 , 147176 }, -- Drape of the Skybreaker
				{ 7 , 147040 }, -- Etched Bone Waistband
				{ 8 , 147170 }, -- Fanged Slayer's Shroud
				{ 9 , 147047 }, -- Gauntlets of Spiteful Haunting
				{ 10, 147106 }, -- Glowing Prayer Candle
				{ 11, 147070 }, -- Grave-Dredged Pauldrons
				{ 12, 147122 }, -- Gravewarden Cloak
				{ 13, 147110 }, -- Grimacing Highborne Skull
				{ 14, 147014 }, -- Locket of Splintered Souls
				{ 15, 147114 }, -- Preserved Starlight Incense
				{ 16, 147158 }, -- Radiant Lightbringer Cape
				{ 17, 147024 }, -- Reliquary of the Damned
				{ 18, 147163 }, -- Shawl of Blind Absolution
				{ 19, 146995 }, -- Soul Queen's Ceremonial Robes
				{ 20, 147018 }, -- Spectral Thurible
				{ 21, 147134 }, -- Stormheart Drape
				{ 22, 147188 }, -- Titanic Onslaught Cloak
				{ 23, 147140 }, -- Wildstalker Cape
				{ 24, 147152 }, -- Xuen's Cloak
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = NORMAL_RAID_DIFF,
		},
		{	-- Maiden of Vigilance
			EncounterJournalID = 1897,
			[RF_DIFF] = NORMAL_RAID_DIFF,
			[NORMAL_RAID_DIFF] = {
				{ 1 , 147194 },	 -- Band of Rescinded Truths
				{ 2 , 147050 },	 -- Crown of Discarded Hope
				{ 3 , 147127 },	 -- Demonbane Harness
				{ 4 , 147185 },	 -- Diabolic Robe
				{ 5 , 147015 },	 -- Engine of Eradication
				{ 6 , 147169 },	 -- Fanged Slayer's Chestguard
				{ 7 , 147098 },	 -- Fragment of Grace
				{ 8 , 147032 },	 -- Gloves of Wayward Compulsions
				{ 9 , 147121 },	 -- Gravewarden Chestplate
				{ 10, 147175 },	 -- Harness of the Skybreaker
				{ 11, 146993 },	 -- Leggings of Divine Portents
				{ 12, 147157 },	 -- Radiant Lightbringer Breastplate
				{ 13, 147025 },	 -- Recompiled Guardian Module
				{ 14, 147167 },	 -- Robes of Blind Absolution
				{ 15, 147149 },	 -- Robes of the Arcane Tempest
				{ 16, 147090 },	 -- Stabilized Extinction Protocol
				{ 17, 147060 },	 -- Steadfast Purifier's Warboots
				{ 18, 147133 },	 -- Stormheart Tunic
				{ 19, 146999 },	 -- Strife-Riddled Cinch
				{ 20, 151189 },	 -- Tears of the Maiden
				{ 21, 147187 },	 -- Titanic Onslaught Breastplate
				{ 22, 147115 },	 -- Unfurling Origination
				{ 23, 147094 },	 -- Virus of Lethargy
				{ 24, 147139 },	 -- Wildstalker Chestguard
				{ 25, 147151 },	 -- Xuen's Tunic
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = NORMAL_RAID_DIFF,
		},
		{	-- Fallen Avatar
			EncounterJournalID = 1873,
			[RF_DIFF] = NORMAL_RAID_DIFF,
			[NORMAL_RAID_DIFF] = {
				{ 1 , 147006 },	 -- Archive of Faith
				{ 2 , 146991 },	 -- Blackened Mask of Disgrace
				{ 3 , 147042 },	 -- Bracers of Rippling Darkness
				{ 4 , 147193 },	 -- Cape of Mindless Fury
				{ 5 , 147091 },	 -- Cleansing Ignition Catalyst
				{ 6 , 147132 },	 -- Demonbane Shoulderpads
				{ 7 , 147186 },	 -- Diabolic Mantle
				{ 8 , 147174 },	 -- Fanged Slayer's Shoulderpads
				{ 9 , 147030 },	 -- Felscape Pathfinders
				{ 10, 147126 },	 -- Gravewarden Pauldrons
				{ 11, 147062 },	 -- Groundshatter Gauntlets
				{ 12, 147052 },	 -- Legguards of Siphoned Power
				{ 13, 147168 },	 -- Mantle of Blind Absolution
				{ 14, 147150 },	 -- Mantle of the Arcane Tempest
				{ 15, 147001 },	 -- Oathbreaker's Cuffs
				{ 16, 147180 },	 -- Pauldrons of the Skybreaker
				{ 17, 147162 },	 -- Radiant Lightbringer Shoulderguards
				{ 18, 147102 },	 -- Reactive Pylon Casing
				{ 19, 147138 },	 -- Stormheart Mantle
				{ 20, 147192 },	 -- Titanic Onslaught Pauldrons
				{ 21, 147107 },	 -- Valorous Spark of Hope
				{ 22, 147144 },	 -- Wildstalker Spaulders
				{ 23, 147156 },	 -- Xuen's Shoulderguards
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = NORMAL_RAID_DIFF,
		},
		{	-- Kil'jaeden
			EncounterJournalID = 1898,
			[RF_DIFF] = NORMAL_RAID_DIFF,
			[NORMAL_RAID_DIFF] = {
				{ 1 , 147099 },	 -- Boon of the Prophet
				{ 2 , 146988 },	 -- Gloves of Furtive Oppression
				{ 3 , 147066 },	 -- Greaves of Impure Midnight
				{ 4 , 147082 },	 -- Man'ari Blood Pact
				{ 5 , 147087 },	 -- Ruinous Ashes
				{ 6 , 147111 },	 -- Scornful Reflection
				{ 7 , 147195 },	 -- Seal of the Second Duumvirate
				{ 8 , 147034 },	 -- Shadow-Scarred Headcover
				{ 9 , 147026 },	 -- Shifting Cosmic Sliver
				{ 10, 147072 },	 -- Soul-Render's Greatbelt
				{ 11, 151190 },	 -- Specter of Betrayal
				{ 12, 147095 },	 -- Sphere of Entropy
				{ 13, 147046 },	 -- Star-Stalker Treads
				{ 14, 147007 },	 -- The Deceiver's Grand Design
				{ 15, 147019 },	 -- Tome of Unraveling Sanity
				{ 16, 147079 },	 -- Torn Fabric of Reality
				{ 17, 147048 },	 -- Vicegrip of the Unrepentant
				{ 18, 147347 },	 -- Waistguard of Profane Duplicity
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = NORMAL_RAID_DIFF,
		},
		{	--Tier 20 Sets
			name = format(AL["Tier %d Sets"], 20),
			ExtraList = true,
			[NORMAL_DIFF] = "AtlasLoot_Collections:TIERSETS:20",
		},
		LEGION_GLORY_TOMB_RAIDER_AC_TABLE,
	},
}

data["TrialOfValor"] = {
	EncounterJournalID = 861,
	MapID = 1114,
	ItemBaseLvl = 865,
	AtlasMapID = "TrialofValorA",
	ContentType = RAID_CONTENT,
	TableType = RAID_ITTYPE,
	items = {
		{	--Odyn
			EncounterJournalID = 1819,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 16, nil }, -- ignore the AC: You Runed Everything!
			},
			[NORMAL_RAID_DIFF] = {
				{ 1, 142419 }, -- Sky-Valiant's Wristguards
				{ 2, 142511 }, -- Unforged Titansteel
				{ 3, 142410 }, -- Robes of Celestial Adornment
				{ 4, 142425 }, -- Goldrune Legplates
				{ 5, 142519 }, -- Favor of the Prime Designate
				{ 6, 142431 }, -- Gleaming Val'kyr Cuirass
				{ 7, 142508 }, -- Chains of the Valorous
				{ 8, 142540 }, -- Mantle of the Victorious Dead
				{ 9, 142422 }, -- Radiant Soul Sabatons
				{ 10, 142514 }, -- Ravens' Sight
				{ 11, 142411 }, -- Cinch of Light
				{ 12, 142430 }, -- Gloves of Issued Challenge
				{ 13, 142520 }, -- Ring of Ascended Glory
				{ 14, 142421 }, -- Leggings of the Undaunted
				{ 16, "ac11337" }, -- AC: You Runed Everything!
			},
			[HEROIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
			},
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 17, "ac11396" }, -- AC: Mythic: Odyn
			},
		},
		{	--Guarm
			EncounterJournalID = 1830,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 16, nil }, -- ignore the AC: Boneafide Tri Tip
			},
			[NORMAL_RAID_DIFF] = {
				{ 1, 142432 }, -- Helbeast Skin Tunic
				{ 2, 142434 }, -- Kvaldir Exult's Grips
				{ 3, 142423 }, -- Bite-Resistant Wristclamps
				{ 4, 142515 }, -- Chilled Incisor
				{ 5, 142412 }, -- Windwhipped Sailcloth
				{ 6, 142506 }, -- Eye of Guarm
				{ 7, 142435 }, -- Reinforced Hound-Handler's Gauntlets
				{ 8, 142512 }, -- Accursed Cuspid
				{ 9, 142426 }, -- Lead-Soled Seabed Striders
				{ 10, 142516 }, -- Sizzling Fang
				{ 11, 142413 }, -- Leggings of the Lower Planes
				{ 12, 142415 }, -- Helhound Hair Bracers
				{ 13, 142417 }, -- Moccasins of Silent Passage
				{ 16, "ac11386" }, -- AC: Boneafide Tri Tip
			},
			[HEROIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
			},
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 17, "ac11397" }, -- AC: Mythic: Guarm
			},
		},
		{	--Helya
			EncounterJournalID = 1829,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 16, nil }, -- ignore the AC: Patient Zero
			},
			[NORMAL_RAID_DIFF] = {
				{ 1, 142507 }, -- Brinewater Slime in a Bottle
				{ 2, 142518 }, -- Fury of the Sea
				{ 3, 142513 }, -- Token of the Lightning Keeper
				{ 4, 142427 }, -- Calcareous Wristclamps
				{ 5, 142517 }, -- Swell of the Tides
				{ 6, 142429 }, -- Oiled Rigger's Handwraps
				{ 7, 142521 }, -- Drape of the Unworthy
				{ 8, 142418 }, -- Sucker-Scarred Leggings
				{ 9, 142510 }, -- Phylactery of Unwilling Servitude
				{ 10, 142416 }, -- Strand of Whelk Shells
				{ 11, 142424 }, -- Krakenbone Waistplate
				{ 12, 142420 }, -- Anchor Chain Waistguard
				{ 13, 142428 }, -- Sea Fan Pendant
				{ 14, 142433 }, -- Corroded Val'kyr Chainmail
				{ 15, 142414 }, -- Treads of the Drowned
				{ 16, "ac11377" }, -- AC: Patient Zero
			},
			[HEROIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
			},
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 17, "ac11387" }, -- AC: The Chosen
				{ 18, "ac11398" }, -- AC: Mythic: Helya
				
			},
		},
		LEGION_TRIAL_OF_VALOR_AC_TABLE
	}
}

