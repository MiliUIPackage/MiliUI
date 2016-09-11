local addonname = ...
local AtlasLoot = _G.AtlasLoot
local data = AtlasLoot.ItemDB:Add(addonname, 7)

local AL = AtlasLoot.Locales

local RF_DIFF = data:AddDifficulty(AL["Raid Finder"], "LFRWithPreset", {
	Item = {
		item1bonus = "LegionLFR",
		item2bonus = "LegionLFRTitanforged",
		autoCompleteItem2 = true,
	},
}, 17)
local NORMAL_DIFF = data:AddDifficulty(AL["Normal"], "n", nil, 1)
local NORMAL_RAID_DIFF = data:AddDifficulty(AL["Normal"], "NormalRaidWithPreset", {
	Item = {
		item1bonus = nil,
		item2bonus = "LegionRaidTitanforged",
		autoCompleteItem2 = true,
	},
}, 14)
local NORMAL_DUNGEON_DIFF = data:AddDifficulty(AL["Normal"], "DungeonWithPreset", {
	Item = {
		item1bonus = "LegionDungeon",
		item2bonus = "LegionDungeonTitanforged",
		autoCompleteItem2 = true,
	},
})
local HEROIC_DIFF = data:AddDifficulty(AL["Heroic"], "h", nil, 2)
local HEROIC_DUNGEON_DIFF = data:AddDifficulty(AL["Heroic"], "HeroicDungeonWithPreset", {
	Item = {
		item1bonus = "LegionHCDungeon",
		item2bonus = "LegionHCDungeonTitanforged",
		autoCompleteItem2 = true,
	},
})
local MYTHICD_DIFF = data:AddDifficulty(AL["Mythic"], "h", nil, 3)
local MYTHICD_DUNGEON_DIFF = data:AddDifficulty(AL["Mythic"], "MythicDungeonWithPreset", {
	Item = {
		item1bonus = "LegionMDungeon",
		item2bonus = "LegionMDungeonTitanforged",
		autoCompleteItem2 = true,
	},
})
local HEROIC_PRE_DIFF = data:AddDifficulty(AL["Heroic"], "HeroicWithPreset", {
	Item = {
		item1bonus = "LegionHeroicRaid",
		item2bonus = "LegionHeroicRaidTitanforged",
		autoCompleteItem2 = true,
	},
}, 15)
local MYTHIC_DIFF = data:AddDifficulty(AL["Mythic"], "m", nil, 16)
local MYTHIC_PRE_DIFF = data:AddDifficulty(AL["Mythic"], "MyhticWithPreset", {
	Item = {
		item1bonus = "LegionMythicRaid",
		item2bonus = "LegionMythicRaidTitanforged",
		autoCompleteItem2 = true,
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

data["AssaultOnVioletHold"] = {
	EncounterJournalID = 777,
	MapID = 1066,
	ContentType = DUNGEON_CONTENT,
	items = {
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
	ContentType = DUNGEON_CONTENT,
	items = {
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

data["CourtOfStars"] = {
	EncounterJournalID = 800,
	MapID = 1087,
	ContentType = DUNGEON_CONTENT,
	items = {
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
	ContentType = DUNGEON_CONTENT,
	items = {
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
	ContentType = DUNGEON_CONTENT,
	items = {
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
	ContentType = DUNGEON_CONTENT,
	items = {
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

data["TheArcway"] = {
	EncounterJournalID = 726,
	MapID = 1079,
	ContentType = DUNGEON_CONTENT,
	items = {
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
	}
}

data["VaultOfTheWardens"] = {
	EncounterJournalID = 707,
	MapID = 1045,
	ContentType = DUNGEON_CONTENT,
	items = {
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
	}
}			

data["BrokenIsles"] = {
	EncounterJournalID = 822,
	MapID = 0,
	ContentType = RAID_CONTENT,
	items = {
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
	}
}

data["TheEmeraldNightmare"] = {
	EncounterJournalID = 768,
	MapID = 1094,
	ContentType = RAID_CONTENT,
	TableType = RAID_ITTYPE,
	items = {
		{	--Elerethe Renferal
			EncounterJournalID = 1744,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
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
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				--{ 27, "ac10027" },
			},
		},
		{	--Ursoc
			EncounterJournalID = 1667,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
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
				--{ 24, "ac10057" },
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				--{ 25, "ac10032" },
			},
		},
		{	--Nythendra
			EncounterJournalID = 1703,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
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
				--{ 24, "ac10013" },
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				--{ 25, "ac10033" },
			},
		},
		{	--Xavius
			EncounterJournalID = 1726,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
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
				--{ 25, "ac10054" },
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				--{ 26, "ac10034" },
			},
		},
		{	--Il'gynoth, Heart of Corruption
			EncounterJournalID = 1738,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
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
				--{ 25, "ac9972" },
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				--{ 26, "ac10035" },
			},
		},
		{	--Cenarius
			EncounterJournalID = 1750,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
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
				--{ 24, "ac9979" },
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				--{ 25, "ac10253" },
			},
		},
		{	--Dragons of Nightmare
			EncounterJournalID = 1704,
			[RF_DIFF] = {

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
				--{ 28, "ac9988" },
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				--{ 29, "ac10037" },
			},
		},
--[[		{	--Tier 18 Sets
			name = format(AL["Tier %d Sets"], 18),
			ExtraList = true,
			[RF_DIFF] = "AtlasLoot_Collections:TIERSETS:18:rf",
			[NORMAL_RAID_DIFF] = "AtlasLoot_Collections:TIERSETS:18:n",
			[HEROIC_PRE_DIFF] = "AtlasLoot_Collections:TIERSETS:18:h",
			[MYTHIC_PRE_DIFF] = "AtlasLoot_Collections:TIERSETS:18:m",
		},
]]		
		LEGION_RAID1_AC_TABLE,
	},
}

data["TheNighthold"] = {
	EncounterJournalID = 786,
	MapID = 1088,
	ContentType = RAID_CONTENT,
	TableType = RAID_ITTYPE,
	items = {
		{	--Trilliax
			EncounterJournalID = 1731,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
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
				--{ 23, "ac8948" },
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				--{ 24, "ac8949" },
			},
		},
		{	--Krosus
			EncounterJournalID = 1713,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
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
				--{ 23, "ac8947" },
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				--{ 24, "ac8960" },
			},
		},
		{	--High Botanist Tel'arn
			EncounterJournalID = 1761,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
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
				--{ 19, "ac8974" },
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				--{ 20, "ac8961" },
			},
		},
		{	--Star Augur Etraeus
			EncounterJournalID = 1732,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
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
				--{ 23, "ac8975" },
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				--{ 24, "ac8962" },
			},
		},
		{	--Spellblade Aluriel
			EncounterJournalID = 1751,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
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
				--{ 24, "ac8958" },
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				--{ 25, "ac8963" },
			},
		},
		{	--Chronomatic Anomaly
			EncounterJournalID = 1725,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 13, 138828, false, [ATLASLOOT_IT_FILTERIGNORE] = true }, -- Illusion: Chronos
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
				--{ 22, "ac8976" },
			},
			[HEROIC_PRE_DIFF] = {
			GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 13, 138828, false, [ATLASLOOT_IT_FILTERIGNORE] = true }, -- Illusion: Chronos
			},
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				{ 13, 138828, false, [ATLASLOOT_IT_FILTERIGNORE] = true }, -- Illusion: Chronos
				--{ 23, "ac8964" },
			},
		},
		{	--Grand Magistrix Elisande
			EncounterJournalID = 1743,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
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
				--{ 27, "ac8988" },
				--{ 28, "ac8977" },
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				--{ 29, "ac8965" },
			},
		},
		{	--Gul'dan
			EncounterJournalID = 1737,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
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
				--{ 27, "ac8988" },
				--{ 28, "ac8977" },
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				--{ 29, "ac8965" },
			},
		},
		{	--Tichondrius
			EncounterJournalID = 1762,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
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
				--{ 27, "ac8988" },
				--{ 28, "ac8977" },
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				--{ 29, "ac8965" },
			},
		},
		{	--Skorpyron
			EncounterJournalID = 1706,
			[RF_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
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
				--{ 27, "ac8988" },
				--{ 28, "ac8977" },
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = {
				GetItemsFromDiff = NORMAL_RAID_DIFF,
				--{ 29, "ac8965" },
			},
		},
--[[		
		{	--HighmaulTrash
			name = AL["Trash Mobs"],
			ExtraList = true,
			[NORMAL_RAID_DIFF] = {
				{ 1, 119343 },	-- Eye-Blinder Greatcloak
				{ 2, 119347 },	-- Gill's Glorious Windcloak
				{ 3, 119346 },	-- Kyu-Sy's Tarflame Doomcloak
				{ 4, 119344 },	-- Magic-Breaker Cape
				{ 5, 119345 },	-- Milenah's Intricate Cloak
				{ 16, 119336 },	-- Cord of Winsome Sorrows
				{ 17, 119335 },	-- Eyeripper Girdle
				{ 18, 119338 },	-- Belt of Inebriated Sorrows
				{ 19, 119337 },	-- Ripswallow Plate Belt
			},
			[HEROIC_PRE_DIFF] = NORMAL_RAID_DIFF,
			[MYTHIC_PRE_DIFF] = NORMAL_RAID_DIFF,
		},
]]		
		LEGION_RAID1_AC_TABLE,
	},
}
