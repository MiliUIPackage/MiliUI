--[[
LibItemBuffs-1.0 - buff-to-item database.
(c) 2013-2014 Adirelle (adirelle@gmail.com)

This file is part of LibItemBuffs-1.0.

LibItemBuffs-1.0 is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

LibItemBuffs-1.0 is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with LibItemBuffs-1.0.  If not, see <http://www.gnu.org/licenses/>.
--]]

local version
local trinkets = {}
local consumables = {
	-- Special case: Alchemist's Flask
	[79638] = 75525,
	[79639] = 75525,
	[79640] = 75525,
	-- Empowered Augment Runes
	[175456] = { -- Hyper Augmentation
		118630, -- Hyper Augment Rune
		128475, -- Empowered Augment Rune (Horde)
		128482, -- Empowered Augment Rune (Alliance)
	},
	[175439] = { -- Stout Augmentation
		118631, -- Stout Augment Rune
		128475, -- Empowered Augment Rune (Horde)
		128482, -- Empowered Augment Rune (Alliance)
	},
	[175457] = { -- Focus Augmentation
		118632, -- Focus Augment Rune
		128475, -- Empowered Augment Rune (Horde)
		128482, -- Empowered Augment Rune (Alliance)
	},
}

local enchantments = {
	-- MoP enchantments

	-- Weapon (we assign it to the main hand weapon though it could come from the off-hand)
	[109085] = INVSLOT_MAINHAND, -- Engineering: Lord Blastington's Scope of Doom
	[118334] = INVSLOT_MAINHAND, -- Enchanting: Dancing Steel (agility)
	[118335] = INVSLOT_MAINHAND, -- Enchanting: Dancing Steel (strength)
	[104993] = INVSLOT_MAINHAND, -- Enchanting: Jade Spirit
	[116660] = INVSLOT_MAINHAND, -- Enchanting: River's Song -- NEED CONFIRMATION
	[116631] = INVSLOT_MAINHAND, -- Enchanting: Colossus
	[104423] = INVSLOT_MAINHAND, -- Enchanting: Windsong (haste)
	[104510] = INVSLOT_MAINHAND, -- Enchanting: Windsong (mastery)
	[104509] = INVSLOT_MAINHAND, -- Enchanting: Windsong (critical strike)

	-- Glove
	[108788] = INVSLOT_HAND, -- Engineering: Phase Fingers -- NEED CONFIRMATION
	[ 96228] = INVSLOT_HAND, -- Engineering: Synapse Springs, Mark II (agility)
	[ 96229] = INVSLOT_HAND, -- Engineering: Synapse Springs, Mark II (strength)
	[ 96230] = INVSLOT_HAND, -- Engineering: Synapse Springs, Mark II (intellect)

	-- Belt
	[131459] = INVSLOT_WAIST, -- Engineering: Watergliding Jets

	-- Cloak
	[126389] = INVSLOT_BACK, -- Engineering: Goblin Glider -- NEED CONFIRMATION
	[125488] = INVSLOT_BACK, -- Tailoring: Darkglow Embroidery, rank 3 -- NEED CONFIRMATION
	[125487] = INVSLOT_BACK, -- Tailoring: Lightweave Embroidery, rank 3
	[125489] = INVSLOT_BACK, -- Tailoring: Swordguard  Embroidery, rank 3 -- NEED CONFIRMATION

	-- Legendary meta gems
	[137593] = INVSLOT_HEAD, -- Indomitable Primal Diamond
	[137288] = INVSLOT_HEAD, -- Courageous Primal Diamond
	[137596] = INVSLOT_HEAD, -- Capacitive Primal Diamond
	[137590] = INVSLOT_HEAD, -- Sinister Primal Diamond
}

-- Anything below this line is generated with the extractor. Editing it is useless.
--== CUT HERE ==--
version = 20161028114345
-- Trinkets
trinkets[   408] =  32492 -- Kidney Shot (Ashtongue Talisman of Lethality)
trinkets[   835] =   1404 -- Tidal Charm
trinkets[   980] = 124522 -- Agony (Fragment of the Dark Star)
trinkets[  1139] =   5079 -- Cold Eye (Cold Basilisk Eye)
trinkets[  1943] =  32492 -- Rupture (Ashtongue Talisman of Lethality)
trinkets[  2098] = 124520 -- Run Through (Bleeding Hollow Toxin Vessel)
trinkets[  4079] =   4397 -- Cloaking (Gnomish Cloaking Device)
trinkets[  5171] =  32492 -- Slice and Dice (Ashtongue Talisman of Lethality)
trinkets[  5217] = 124514 -- Tiger's Fury (Seed of Creation)
trinkets[ 10342] =   1490 -- Guardian Effect (Guardian Talisman)
trinkets[ 10368] =  11302 -- Uther's Light Effect (Uther's Strength)
trinkets[ 12042] = 124516 -- Arcane Power (Tome of Shifting Words)
trinkets[ 12438] = { -- Slow Fall
	 10684, -- Colossal Parachute
	 18951, -- Evonice's Landin' Pilla
	 60680, -- S.A.F.E. "Parachute"
}
trinkets[ 12733] =  10418 -- Mithril Insignia (Glimmering Mithril Insignia)
trinkets[ 12766] =  10455 -- Poison Cloud (Chained Essence of Eranikus)
trinkets[ 13183] =  10727 -- Goblin Dragon Gun
trinkets[ 13237] =  10577 -- Goblin Mortar
trinkets[ 13278] =  10645 -- Gnomish Death Ray
trinkets[ 13744] =   2802 -- Blazing Emblem
trinkets[ 14530] =   2820 -- Speed (Nifty Stopwatch)
trinkets[ 14874] =  32492 -- Rupture (Ashtongue Talisman of Lethality)
trinkets[ 14903] =  32492 -- Rupture (Ashtongue Talisman of Lethality)
trinkets[ 15583] =  32492 -- Rupture (Ashtongue Talisman of Lethality)
trinkets[ 15595] =  11810 -- Force of Will
trinkets[ 15601] =  11815 -- Hand of Justice
trinkets[ 15604] =  11819 -- Second Wind
trinkets[ 15646] =  11832 -- Burst of Knowledge
trinkets[ 17275] =  13164 -- Heart of the Scale
trinkets[ 17330] =  13213 -- Poison (Smolderweb's Eye)
trinkets[ 18376] = 124522 -- Corruption (Fragment of the Dark Star)
trinkets[ 18946] =  14557 -- The Lion Horn of Stormwind
trinkets[ 19574] = 124515 -- Bestial Wrath (Talisman of the Master Tracker)
trinkets[ 20587] =  15873 -- Ragged John's Neverending Cup
trinkets[ 21068] = 124522 -- Corruption (Fragment of the Dark Star)
trinkets[ 21956] =  17759 -- Physical Protection (Mark of Resolution)
trinkets[ 21970] =  17774 -- Mark of the Chosen
trinkets[ 23097] =  18638 -- Fire Reflector (Hyper-Radiant Flame Reflector)
trinkets[ 23131] =  18634 -- Frost Reflector (Gyrofreeze Ice Reflector)
trinkets[ 23132] =  18639 -- Shadow Reflector (Ultra-Flash Shadow Reflector)
trinkets[ 23271] =  18820 -- Ephemeral Power (Talisman of Ephemeral Power)
trinkets[ 23506] =  19024 -- Aura of Protection (Arena Grand Master)
trinkets[ 23684] =  19288 -- Aura of the Blue Dragon (Darkmoon Card: Blue Dragon)
trinkets[ 23720] =  19337 -- Blessing of the Black Book (The Black Book)
trinkets[ 23721] =  19336 -- Arcane Infused (Arcane Infused Gem)
trinkets[ 23723] =  19339 -- Mind Quickening (Mind Quickening Gem)
trinkets[ 23724] =  19340 -- Metamorphosis Rune (Rune of Metamorphosis)
trinkets[ 23725] =  19341 -- Gift of Life (Lifegiving Gem)
trinkets[ 23726] =  19342 -- Venomous Totem
trinkets[ 23733] =  19343 -- Blinding Light (Scrolls of Blinding Light)
trinkets[ 23734] =  19344 -- Nature Aligned (Natural Alignment Crystal)
trinkets[ 23780] =  19345 -- Aegis of Preservation
trinkets[ 23991] = { -- Damage Absorb
	 20071, -- Talisman of Arathor
	 20072, -- Defiler's Talisman
}
trinkets[ 24268] =  19930 -- Mar'li's Brain Boost (Mar'li's Eye)
trinkets[ 24347] =  19979 -- Master Angler (Hook of the Master Angler)
trinkets[ 24352] =  19991 -- Devilsaur Fury (Devilsaur Eye)
trinkets[ 24354] =  19990 -- Prayer Beads Blessing (Blessed Prayer Beads)
trinkets[ 24389] =  20036 -- Chaos Fire (Fire Ruby)
trinkets[ 24427] =  20130 -- Diamond Flask
trinkets[ 24498] =  19952 -- Brilliant Light (Gri'lek's Charm of Valor)
trinkets[ 24499] =  19956 -- Energized Shield (Wushoolay's Charm of Spirits)
trinkets[ 24531] =  19953 -- Refocus (Renataki's Charm of Beasts)
trinkets[ 24542] =  19955 -- Nimble Healing Touch (Wushoolay's Charm of Nature)
trinkets[ 24543] =  19957 -- Massive Destruction (Hazza'rah's Charm of Destruction)
trinkets[ 24544] =  19959 -- Arcane Potency (Hazza'rah's Charm of Magic)
trinkets[ 24546] =  19958 -- Rapid Healing (Hazza'rah's Charm of Healing)
trinkets[ 24610] =  19947 -- Pagle's Broken Reel (Nat Pagle's Broken Reel)
trinkets[ 24865] =  20512 -- Sanctified Orb
trinkets[ 24998] =  20636 -- Healing of the Ages (Hibernation Crystal)
trinkets[ 25746] = { -- Damage Absorb
	 21115, -- Defiler's Talisman
	 21117, -- Talisman of Arathor
}
trinkets[ 25747] = { -- Damage Absorb
	 21116, -- Defiler's Talisman
	 21118, -- Talisman of Arathor
}
trinkets[ 25750] = { -- Damage Absorb
	 21119, -- Talisman of Arathor
	 21120, -- Defiler's Talisman
	 65286, -- Ancient Seed Casing
}
trinkets[ 25891] =  21180 -- Earthstrike
trinkets[ 26166] =  21473 -- Obsidian Insight (Eye of Moam)
trinkets[ 26168] =  21488 -- Chitinous Spikes (Fetish of Chitinous Spikes)
trinkets[ 26400] =  21647 -- Arcane Shroud (Fetish of the Sand Reaver)
trinkets[ 26467] =  21625 -- Persistent Shield (Scarab Brooch)
trinkets[ 26480] =  21670 -- Badge of the Swarmguard
trinkets[ 26551] =  21748 -- Jade Owl (Figurine - Jade Owl)
trinkets[ 26571] =  21756 -- Golden Hare (Figurine - Golden Hare)
trinkets[ 26576] =  21758 -- Black Pearl Panther (Figurine - Black Pearl Panther)
trinkets[ 26581] =  21760 -- Truesilver Crab (Figurine - Truesilver Crab)
trinkets[ 26593] =  21763 -- Truesilver Boar (Figurine - Truesilver Boar)
trinkets[ 26599] =  21769 -- Ruby Serpent (Figurine - Ruby Serpent)
trinkets[ 26600] =  21777 -- Emerald Owl (Figurine - Emerald Owl)
trinkets[ 26609] =  21784 -- Black Diamond Crab (Figurine - Black Diamond Crab)
trinkets[ 26614] =  21789 -- Dark Iron Scorpid (Figurine - Dark Iron Scorpid)
trinkets[ 26679] =  32492 -- Deadly Throw (Ashtongue Talisman of Lethality)
trinkets[ 27615] =  32492 -- Kidney Shot (Ashtongue Talisman of Lethality)
trinkets[ 27675] =  22268 -- Chromatic Infusion (Draconic Infused Emblem)
trinkets[ 28200] =  22678 -- Ascendance (Talisman of Ascendance)
trinkets[ 28777] =  23041 -- Slayer's Crest
trinkets[ 28778] =  23042 -- Loatheb's Reflection
trinkets[ 28779] =  23046 -- Essence of Sapphiron (The Restrained Essence of Sapphiron)
trinkets[ 28780] =  23047 -- The Eye of the Dead (Eye of the Dead)
trinkets[ 28862] =  23001 -- The Eye of Diminution (Eye of Diminution)
trinkets[ 28866] =  22954 -- Kiss of the Spider
trinkets[ 29506] =  23558 -- The Burrower's Shell
trinkets[ 29601] =  28727 -- Enlightenment (Pendant of the Violet Eye)
trinkets[ 29602] =  23570 -- Jom Gabbar
trinkets[ 30108] = 124522 -- Unstable Affliction (Fragment of the Dark Star)
trinkets[ 30621] =  32492 -- Kidney Shot (Ashtongue Talisman of Lethality)
trinkets[ 30832] =  32492 -- Kidney Shot (Ashtongue Talisman of Lethality)
trinkets[ 30938] = 124522 -- Corruption (Fragment of the Dark Star)
trinkets[ 31038] =  24124 -- Felsteel Boar (Figurine - Felsteel Boar)
trinkets[ 31039] =  24125 -- Dawnstone Crab (Figurine - Dawnstone Crab)
trinkets[ 31040] =  24126 -- Living Ruby Serpent (Figurine - Living Ruby Serpent)
trinkets[ 31045] =  24127 -- Talasite Owl (Figurine - Talasite Owl)
trinkets[ 31047] =  24128 -- Nightseye Panther (Figurine - Nightseye Panther)
trinkets[ 31405] = 124522 -- Corruption (Fragment of the Dark Star)
trinkets[ 31771] = { -- Shell of Deterrence
	 24376, -- Runed Fungalcap
	127184, -- Runed Fungalcap
}
trinkets[ 31794] =  24390 -- Focused Mind (Auslese's Light Channeler)
trinkets[ 32063] = 124522 -- Corruption (Fragment of the Dark Star)
trinkets[ 32197] = 124522 -- Corruption (Fragment of the Dark Star)
trinkets[ 32355] = { -- Focused Power
	 25619, -- Glowing Crystal Insignia
	 25620, -- Ancient Crystal Talisman
}
trinkets[ 32362] = { -- Burning Hatred
	 25628, -- Ogre Mauler's Badge
	 25633, -- Uniting Charm
}
trinkets[ 32367] =  25634 -- Power of Prayer (Oshu'gun Relic)
trinkets[ 32600] =  25787 -- Avoidance (Charm of Alacrity)
trinkets[ 32645] =  32492 -- Envenom (Ashtongue Talisman of Lethality)
trinkets[ 33012] =  26055 -- Consume Essence (Oculus of the Hidden Eye)
trinkets[ 33014] =  27416 -- Consume Life (Fetish of the Fallen)
trinkets[ 33089] = { -- Vigilance of the Colossus
	 27529, -- Figurine of the Colossus
	123992, -- Figurine of the Colossus
}
trinkets[ 33370] = { -- Spell Haste
	 28190, -- Scarab of the Infinite Cycle
	127448, -- Scarab of the Infinite Cycle
}
trinkets[ 33400] = { -- Accelerated Mending
	 27828, -- Warp-Scarab Brooch
	127245, -- Warp-Scarab Brooch
}
trinkets[ 33479] =  27891 -- Adamantine Shell (Adamantine Figurine)
trinkets[ 33523] = { -- Mark of Vindication
	 27926, -- Mark of Vindication
	 27927, -- Mark of Vindication
}
trinkets[ 33649] = { -- Rage of the Unraveller
	 28034, -- Hourglass of the Unraveller
	127441, -- Hourglass of the Unraveller
}
trinkets[ 33662] =  28040 -- Arcane Energy (Vengeance of the Illidari)
trinkets[ 33667] =  28041 -- Ferocity (Bladefist's Breadth)
trinkets[ 33668] =  28042 -- Tenacity (Regal Protectorate)
trinkets[ 33758] =  28109 -- Essence Infused Mushroom
trinkets[ 33807] =  28288 -- Abacus of Violent Odds
trinkets[ 33891] = 124514 -- Incarnation: Tree of Life (Seed of Creation)
trinkets[ 33943] =  32481 -- Travel Form (Charm of Swift Flight)
trinkets[ 34000] =  28223 -- The Arcanist's Stone (Arcanist's Stone)
trinkets[ 34106] =  28121 -- Unyielding Courage (Icon of Unyielding Courage)
trinkets[ 34108] =  32492 -- Spine Break (Ashtongue Talisman of Lethality)
trinkets[ 34210] =  28370 -- Endless Blessings (Bangle of Endless Blessings)
trinkets[ 34321] = { -- Call of the Nexus
	 28418, -- Shiffar's Nexus-Horn
	127173, -- Shiffar's Nexus-Horn
}
trinkets[ 34438] = 124522 -- Unstable Affliction (Fragment of the Dark Star)
trinkets[ 34439] = 124522 -- Unstable Affliction (Fragment of the Dark Star)
trinkets[ 34519] =  28528 -- Time's Favor (Moroes' Lucky Pocket Watch)
trinkets[ 34747] =  28789 -- Recurring Power (Eye of Magtheridon)
trinkets[ 34775] =  28830 -- Dragonspine Flurry (Dragonspine Trophy)
trinkets[ 35163] =  29370 -- Blessing of the Silver Crescent (Icon of the Silver Crescent)
trinkets[ 35165] =  29376 -- Essence of the Martyr
trinkets[ 35166] =  29383 -- Lust for Battle (Bloodlust Brooch)
trinkets[ 35183] = 124522 -- Unstable Affliction (Fragment of the Dark Star)
trinkets[ 35337] = { -- Spell Power
	 29132, -- Scryer's Bloodgem
	 29179, -- Xi'ri's Gift
}
trinkets[ 35733] =  29776 -- Ancient Power (Core of Ar'kelos)
trinkets[ 36347] =  30293 -- Healing Power (Heavenly Inspiration)
trinkets[ 36372] =  30300 -- Phalanx (Dabiri's Enigma)
trinkets[ 36432] =  30340 -- Spell Power (Starkiller's Bauble)
trinkets[ 37113] = 124522 -- Corruption (Fragment of the Dark Star)
trinkets[ 37174] =  30450 -- Perceived Weakness (Warp-Spring Coil)
trinkets[ 37198] =  30447 -- Blessing of Righteousness (Tome of Fiery Redemption)
trinkets[ 37243] =  30663 -- Revitalize (Fathom-Brooch of the Tidewalker)
trinkets[ 37508] =  30448 -- Shot Power (Talon of Al'ar)
trinkets[ 37656] =  32496 -- Wisdom (Memento of Tyrande)
trinkets[ 38324] =  30619 -- Regeneration (Fel Reaver's Piston)
trinkets[ 38325] =  30620 -- Regeneration (Spyglass of the Hidden Fleet)
trinkets[ 38332] =  28590 -- Blessing of Life (Ribbon of Sacrifice)
trinkets[ 38346] =  28370 -- Meditation (Bangle of Endless Blessings)
trinkets[ 38348] =  30626 -- Unstable Currents (Sextant of Unstable Currents)
trinkets[ 38351] =  30629 -- Displacement (Scarab of Displacement)
trinkets[ 39200] =  25937 -- Heroism (Terokkar Tablet of Precision)
trinkets[ 39201] =  25936 -- Spell Power (Terokkar Tablet of Vim)
trinkets[ 39212] = 124522 -- Corruption (Fragment of the Dark Star)
trinkets[ 39228] =  27770 -- Argussian Compass
trinkets[ 39439] =  31856 -- Aura of the Crusader (Darkmoon Card: Crusade)
trinkets[ 39443] =  31857 -- Aura of Wrath (Darkmoon Card: Wrath)
trinkets[ 39621] = 124522 -- Corruption (Fragment of the Dark Star)
trinkets[ 40120] =  32481 -- Travel Form (Charm of Swift Flight)
trinkets[ 40396] =  32483 -- Fel Infusion (The Skull of Gul'dan)
trinkets[ 40402] =  30665 -- Deep Meditation (Earring of Soulful Meditation)
trinkets[ 40459] =  32485 -- Fire Blood (Ashtongue Talisman of Valor)
trinkets[ 40464] =  32501 -- Protector's Vigor (Shadowmoon Insignia)
trinkets[ 40477] =  32505 -- Forceful Strike (Madness of the Betrayer)
trinkets[ 40480] =  32493 -- Power of the Ashtongue (Ashtongue Talisman of Shadows)
trinkets[ 40483] =  32488 -- Insight of the Ashtongue (Ashtongue Talisman of Insight)
trinkets[ 40487] =  32487 -- Deadly Aim (Ashtongue Talisman of Swiftness)
trinkets[ 40538] =  32534 -- Tenacity (Brooch of the Immortal King)
trinkets[ 40724] =  32654 -- Valor (Crystalforged Trinket)
trinkets[ 40729] =  32658 -- Heightened Reflexes (Badge of Tenacity)
trinkets[ 41261] =  32770 -- Combat Valor (Skyguard Silver Cross)
trinkets[ 41263] =  32771 -- Combat Gallantry (Airman's Ribbon of Gallantry)
trinkets[ 41988] = 124522 -- Corruption (Fragment of the Dark Star)
trinkets[ 42084] =  30627 -- Fury of the Crashing Waves (Tsunami Talisman)
trinkets[ 43710] =  33828 -- Diabolic Remedy (Tome of Diabolic Remedy)
trinkets[ 43712] =  33829 -- Mojo Madness (Hex Shrunken Head)
trinkets[ 43713] =  33830 -- Hardened Skin (Ancient Aqir Artifact)
trinkets[ 43716] =  33831 -- Call of the Berserker (Berserker's Call)
trinkets[ 44055] = { -- Tremendous Fortitude
	 33832, -- Battlemaster's Determination
	 34049, -- Battlemaster's Audacity
	 34050, -- Battlemaster's Perseverance
	 34162, -- Battlemaster's Depravity
	 34163, -- Battlemaster's Cruelty
	 34576, -- Battlemaster's Cruelty
	 34577, -- Battlemaster's Depravity
	 34578, -- Battlemaster's Determination
	 34579, -- Battlemaster's Audacity
	 34580, -- Battlemaster's Perseverance
	 35326, -- Battlemaster's Alacrity
	 35327, -- Battlemaster's Alacrity
}
trinkets[ 45040] =  34427 -- Battle Trance (Blackened Naaru Sliver)
trinkets[ 45042] =  34429 -- Power Circle (Shifting Naaru Sliver)
trinkets[ 45049] =  34428 -- Tenacity (Steely Naaru Sliver)
trinkets[ 45052] =  34430 -- Evocation (Glimmering Naaru Sliver)
trinkets[ 45053] = { -- Disdain
	 34472, -- Shard of Contempt
	133463, -- Shard of Contempt
}
trinkets[ 45062] = { -- Holy Energy
	 34471, -- Vial of the Sunwell
	133462, -- Vial of the Sunwell
}
trinkets[ 46567] =  23836 -- Rocket Launch (Goblin Rocket Launcher)
trinkets[ 46780] =  35693 -- Empyrean Tortoise (Figurine - Empyrean Tortoise)
trinkets[ 46783] =  35700 -- Crimson Serpent (Figurine - Crimson Serpent)
trinkets[ 46784] =  35702 -- Shadowsong Panther (Figurine - Shadowsong Panther)
trinkets[ 46785] =  35703 -- Seaspray Albatross (Figurine - Seaspray Albatross)
trinkets[ 47215] =  35935 -- Runic Infusion (Infused Coldstone Rune)
trinkets[ 47217] =  35937 -- Foaming Rage (Braxley's Backyard Moonshine)
trinkets[ 47782] = 124522 -- Corruption (Fragment of the Dark Star)
trinkets[ 47806] =  36871 -- Towering Rage (Fury of the Encroaching Storm)
trinkets[ 47807] =  36872 -- Healing Focus (Mender of the Oncoming Dawn)
trinkets[ 47816] = { -- Spell Power
	 36874, -- Horn of the Herald
	 38257, -- Strike of the Seas
}
trinkets[ 48846] = { -- Runic Infusion
	 37555, -- Warsong's Wrath
	 38213, -- Harbinger's Wrath
}
trinkets[ 48847] =  37556 -- Precise Strikes (Talisman of the Tundra)
trinkets[ 48848] =  37557 -- Feral Fury (Warsong's Fervor)
trinkets[ 48855] =  37558 -- Healing Purity (Tidal Boon)
trinkets[ 48865] =  37560 -- Perfumed Grace (Vial of Renewal)
trinkets[ 48868] =  37562 -- Skycaller's Swiftness (Fury of the Crimson Drake)
trinkets[ 48875] = { -- Spell Power
	 38760, -- Mendicant's Charm
	 38762, -- Insignia of Bloody Fire
}
trinkets[ 49623] =  37835 -- Effervescence (Je'Tze's Bell)
trinkets[ 50261] =  38258 -- Nimble Fingers (Sailor's Knotted Charm)
trinkets[ 50263] =  38259 -- Quickness of the Sailor (First Mate's Pocketwatch)
trinkets[ 50708] =  19992 -- Primal Instinct (Devilsaur Tooth)
trinkets[ 51348] =  38359 -- Venture Company Beatdown! (Goblin Repetition Reducer)
trinkets[ 51952] =  38289 -- Dark Iron Luck (Coren's Lucky Coin)
trinkets[ 51953] =  38290 -- Dark Iron Pipeweed (Dark Iron Smoking Pipe)
trinkets[ 51954] =  38288 -- Hopped Up (Direbrew Hops)
trinkets[ 51955] =  38287 -- Dire Drunkard (Empty Mug of Direbrew)
trinkets[ 51978] =  38080 -- Jormungar Slime (Automated Weapon Coater)
trinkets[ 51985] =  38070 -- Far-Seeing Eyes (Foresight's Anticipation)
trinkets[ 51987] =  38081 -- Arcane Infusion (Scarab of Isanoth)
trinkets[ 52419] =  38674 -- Deflection (Soul Harvester's Charm)
trinkets[ 52424] =  38675 -- Retaliation (Signet of the Dark Brotherhood)
trinkets[ 52507] = 124514 -- Ragepaw's Presence (Seed of Creation)
trinkets[ 54092] =  40354 -- Monster Slayer's Kit
trinkets[ 54329] =  40601 -- Argent Dawn Banner
trinkets[ 54418] =  40593 -- Argent Tome Bunny Spawn (Argent Tome)
trinkets[ 54696] =  38212 -- Wracking Pains (Death Knight's Anguish)
trinkets[ 54739] =  37559 -- Star of Light (Serrah's Star)
trinkets[ 54839] =  38071 -- Purified Spirit (Valonforth's Remembrance)
trinkets[ 55018] =  40767 -- Sonic Awareness (Sonic Booster)
trinkets[ 55019] =  40865 -- Sonic Shield (Noise Machine)
trinkets[ 55039] =  41121 -- Gnomish Lightning Generator
trinkets[ 55613] = 124521 -- Flame Shock (Core of the Primal Elements)
trinkets[ 55915] = { -- Tremendous Fortitude
	 42128, -- Battlemaster's Hostility
	 42129, -- Battlemaster's Accuracy
	 42130, -- Battlemaster's Avidity
	 42131, -- Battlemaster's Conviction
	 42132, -- Battlemaster's Bravery
}
trinkets[ 56121] =  42341 -- Ruby Hare (Figurine - Ruby Hare)
trinkets[ 56184] =  42395 -- Twilight Serpent (Figurine - Twilight Serpent)
trinkets[ 56186] =  42413 -- Sapphire Owl (Figurine - Sapphire Owl)
trinkets[ 56188] =  42418 -- Emerald Boar (Figurine - Emerald Boar)
trinkets[ 56898] = 124522 -- Corruption (Fragment of the Dark Star)
trinkets[ 57350] =  42988 -- Illusionary Barrier (Darkmoon Card: Illusion)
trinkets[ 58157] =  30446 -- Solarian's Grace (Solarian's Sapphire)
trinkets[ 58811] = 124522 -- Corruption (Fragment of the Dark Star)
trinkets[ 58904] =  43573 -- Tears of Anguish (Tears of Bitter Anguish)
trinkets[ 58971] = 124521 -- Flame Shock (Core of the Primal Elements)
trinkets[ 59657] = { -- Argent Valor
	 44013, -- Cannoneer's Fuselighter
	 44015, -- Cannoneer's Morale
}
trinkets[ 59658] =  44014 -- Argent Heroism (Fezzik's Pocketwatch)
trinkets[ 59757] =  44063 -- Figurine - Monarch Crab
trinkets[ 59789] =  44074 -- Oracle Ablutions (Oracle Talisman of Ablution)
trinkets[ 59821] =  44073 -- Frenzyheart Fury (Frenzyheart Insignia of Fury)
trinkets[ 60054] =  40683 -- Valor Medal of the First War
trinkets[ 60062] = { -- Essence of Life
	 40685, -- The Egg of Mortal Essence
	 49078, -- Ancient Pickled Egg
}
trinkets[ 60064] =  44912 -- Now is the time! (Flow of Knowledge)
trinkets[ 60065] =  44914 -- Reflection of Torment (Anvil of Titans)
trinkets[ 60180] = { -- Resolute
	 37638, -- Offering of Sacrifice
	 39292, -- Repelling Charge
	127550, -- Offering of Sacrifice
}
trinkets[ 60196] =  42989 -- Berserker! (Darkmoon Card: Berserker!)
trinkets[ 60214] =  36993 -- Seal of the Pantheon
trinkets[ 60215] =  37872 -- Lavanthor's Talisman
trinkets[ 60218] =  37220 -- Essence of Gossamer
trinkets[ 60258] =  40372 -- Rune of Repulsion
trinkets[ 60286] =  40257 -- Defender's Code
trinkets[ 60299] =  37723 -- Incisor Fragment
trinkets[ 60302] = { -- Meteorite Whetstone
	 37390, -- Meteorite Whetstone
	127493, -- Meteorite Whetstone
}
trinkets[ 60305] = { -- Heart of a Dragon
	 37166, -- Sphere of Red Dragon's Blood
	127594, -- Sphere of Red Dragon's Blood
}
trinkets[ 60314] =  40431 -- Fury of the Five Flights
trinkets[ 60319] =  40531 -- Mark of Norgannon
trinkets[ 60437] =  40256 -- Grim Toll
trinkets[ 60439] =  39257 -- Loatheb's Shadow
trinkets[ 60471] =  36972 -- Tome of Arcane Phenomena
trinkets[ 60479] =  37660 -- Forge Ember
trinkets[ 60480] =  37873 -- Mark of the War Prisoner
trinkets[ 60486] =  40432 -- Illustration of the Dragon Soul
trinkets[ 60492] =  39229 -- Embrace of the Spider
trinkets[ 60494] =  40255 -- Dying Curse
trinkets[ 60517] =  37734 -- Talisman of Troll Divinity
trinkets[ 60520] =  37657 -- Spark of Life
trinkets[ 60521] = { -- Winged Talisman
	 37844, -- Winged Talisman
	127512, -- Winged Talisman
}
trinkets[ 60525] =  40430 -- Majestic Dragon Figurine
trinkets[ 60527] =  39388 -- Essence Flow (Spirit-World Glass)
trinkets[ 60530] =  40258 -- Forethought Talisman
trinkets[ 60538] =  40382 -- Soul of the Dead
trinkets[ 61426] =  38763 -- Infinite Spirit (Futuresight Rune)
trinkets[ 61427] =  38764 -- Infinite Speed (Rune of Finite Variation)
trinkets[ 61428] =  38765 -- Infinite Power (Rune of Infinite Power)
trinkets[ 61617] =  43837 -- Warm Glow (Softly Glowing Orb)
trinkets[ 61619] =  43838 -- Tentacles (Chuchu's Tiny Box of Horrors)
trinkets[ 61620] =  43836 -- Bleeding Heart (Thorny Rose Brooch)
trinkets[ 61671] =  43829 -- Crusader's Glory (Crusader's Locket)
trinkets[ 61778] =  38761 -- Scything Talons (Talon of Hatred)
trinkets[ 62088] =  39811 -- Infiltrator's Guile (Badge of the Infiltrator)
trinkets[ 63250] = { -- Jouster's Fury
	 45131, -- Jouster's Fury
	 45219, -- Jouster's Fury
}
trinkets[ 64524] =  46086 -- Platinum Disks of Battle
trinkets[ 64525] =  46087 -- Platinum Disks of Sorcery
trinkets[ 64527] =  46088 -- Platinum Disks of Swiftness
trinkets[ 64707] =  45466 -- Scale of Fates
trinkets[ 64712] =  45148 -- Living Flame
trinkets[ 64713] =  45518 -- Flame of the Heavens (Flare of the Heavens)
trinkets[ 64739] =  45535 -- Show of Faith
trinkets[ 64741] =  45490 -- Pandora's Plea
trinkets[ 64763] =  45158 -- Heart of Iron
trinkets[ 64765] =  45507 -- The General's Heart
trinkets[ 64772] =  45609 -- Comet's Trail
trinkets[ 64790] =  45522 -- Blood of the Old God
trinkets[ 64800] =  45263 -- Wrathstone
trinkets[ 64999] =  46051 -- Meteoric Inspiration (Meteorite Crystal)
trinkets[ 65003] =  45929 -- Memories of Love (Sif's Remembrance)
trinkets[ 65004] =  45866 -- Alacrity of the Elements (Elemental Focus Stone)
trinkets[ 65006] =  45308 -- Eye of the Broodmother
trinkets[ 65008] =  45292 -- Energy Siphon
trinkets[ 65011] =  45313 -- Furnace Stone
trinkets[ 65012] =  46021 -- Royal Seal of King Llane
trinkets[ 65014] =  45286 -- Pyrite Infusion (Pyrite Infuser)
trinkets[ 65019] =  45931 -- Mjolnir Runestone
trinkets[ 65024] =  46038 -- Implosion (Dark Matter)
trinkets[ 67596] = { -- Tremendous Fortitude
	 42133, -- Battlemaster's Fury
	 42134, -- Battlemaster's Precision
	 42135, -- Battlemaster's Vivacity
	 42136, -- Battlemaster's Rage
	 42137, -- Battlemaster's Ruination
}
trinkets[ 67631] =  47216 -- Aegis (The Black Heart)
trinkets[ 67669] =  47213 -- Elusive Power (Abyssal Rune)
trinkets[ 67671] =  47214 -- Fury (Banner of Victory)
trinkets[ 67683] =  48722 -- Celerity (Shard of the Crystal Heart)
trinkets[ 67684] =  48724 -- Hospitality (Talisman of Resurgence)
trinkets[ 67694] =  47735 -- Defensive Tactics (Glyph of Indomitability)
trinkets[ 67695] =  47734 -- Rage (Mark of Supremacy)
trinkets[ 67696] = { -- Energized
	 47041, -- Solace of the Defeated
	 47271, -- Solace of the Fallen
}
trinkets[ 67699] = { -- Fortitude
	 47080, -- Satrina's Impeding Scarab
	 47290, -- Juggernaut's Vitality
}
trinkets[ 67726] = { -- Escalating Power
	 47728, -- Binding Light
	 47880, -- Binding Stone
}
trinkets[ 67728] = { -- Hardening Armor
	 47727, -- Fervor of the Frostborn
	 47882, -- Eitrigg's Oath
}
trinkets[ 67738] = { -- Rising Fury
	 47725, -- Victor's Call
	 47881, -- Vengeance of the Forsaken
}
trinkets[ 67740] = { -- Escalating Power
	 47947, -- Binding Light
	 48019, -- Binding Stone
}
trinkets[ 67742] = { -- Hardening Armor
	 47949, -- Fervor of the Frostborn
	 48021, -- Eitrigg's Oath
}
trinkets[ 67747] = { -- Rising Fury
	 47948, -- Victor's Call
	 48020, -- Vengeance of the Forsaken
}
trinkets[ 67750] = { -- Energized
	 47059, -- Solace of the Defeated
	 47432, -- Solace of the Fallen
}
trinkets[ 67753] = { -- Fortitude
	 47088, -- Satrina's Impeding Scarab
	 47451, -- Juggernaut's Vitality
}
trinkets[ 68443] =  49080 -- Drunken Evasiveness (Brawler's Souvenir)
trinkets[ 69404] = 124522 -- Curse of Agony (Fragment of the Dark Star)
trinkets[ 71396] =  50355 -- Rage of the Fallen (Herkuml War Token)
trinkets[ 71401] =  50342 -- Icy Rage (Whispering Fanged Skull)
trinkets[ 71403] =  50198 -- Fatal Flaws (Needle-Encrusted Scorpion)
trinkets[ 71541] =  50343 -- Icy Rage (Whispering Fanged Skull)
trinkets[ 71568] =  50260 -- Urgency (Ephemeral Snowflake)
trinkets[ 71569] =  50235 -- Increased Fortitude (Ick's Rotting Thumb)
trinkets[ 71570] =  50340 -- Cultivated Power (Muradin's Spyglass)
trinkets[ 71572] =  50345 -- Cultivated Power (Muradin's Spyglass)
trinkets[ 71575] =  50341 -- Invigorated (Unidentifiable Organ)
trinkets[ 71577] =  50344 -- Invigorated (Unidentifiable Organ)
trinkets[ 71579] =  50357 -- Elusive Power (Maghia's Misguided Quill)
trinkets[ 71584] =  50358 -- Revitalized (Purified Lunar Dust)
trinkets[ 71586] =  50356 -- Hardened Skin (Corroded Skeleton Key)
trinkets[ 71601] =  50353 -- Surge of Power (Dislodged Foreign Object)
trinkets[ 71605] =  50360 -- Siphoned Power (Phylactery of the Nameless Lich)
trinkets[ 71633] =  50352 -- Thick Skin (Corpse Tongue Coin)
trinkets[ 71635] =  50361 -- Aegis of Dalaran (Sindragosa's Flawless Fang)
trinkets[ 71636] =  50365 -- Siphoned Power (Phylactery of the Nameless Lich)
trinkets[ 71638] =  50364 -- Aegis of Dalaran (Sindragosa's Flawless Fang)
trinkets[ 71639] =  50349 -- Thick Skin (Corpse Tongue Coin)
trinkets[ 71644] =  50348 -- Surge of Power (Dislodged Foreign Object)
trinkets[ 73522] =  52351 -- King of Boars (Figurine - King of Boars)
trinkets[ 73549] =  52199 -- Demon Panther (Figurine - Demon Panther)
trinkets[ 73550] =  52352 -- Earthen Guardian (Figurine - Earthen Guardian)
trinkets[ 73551] =  52353 -- Jeweled Serpent (Figurine - Jeweled Serpent)
trinkets[ 73552] =  52354 -- Dream Owl (Figurine - Dream Owl)
trinkets[ 75456] =  54590 -- Piercing Twilight (Sharpened Twilight Scale)
trinkets[ 75458] =  54569 -- Piercing Twilight (Sharpened Twilight Scale)
trinkets[ 75466] =  54572 -- Twilight Flames (Charred Twilight Scale)
trinkets[ 75473] =  54588 -- Twilight Flames (Charred Twilight Scale)
trinkets[ 75477] =  54571 -- Scaly Nimbleness (Petrified Twilight Scale)
trinkets[ 75480] =  54591 -- Scaly Nimbleness (Petrified Twilight Scale)
trinkets[ 75490] =  54573 -- Eyes of Twilight (Glowing Twilight Scale)
trinkets[ 75495] =  54589 -- Eyes of Twilight (Glowing Twilight Scale)
trinkets[ 75528] = 124522 -- Tortured Soul (Fragment of the Dark Star)
trinkets[ 78830] =  56847 -- Projectile Vomit (Chelsea's Nightmare)
trinkets[ 82811] = 124522 -- Corrupted Dreams (Fragment of the Dark Star)
trinkets[ 84212] =  23040 -- Glyph of Deflection
trinkets[ 84213] =  29387 -- Gnome Ingenuity (Gnomeregan Auto-Dodger 600)
trinkets[ 84960] = { -- Tremendous Fortitude
	 61026, -- Vicious Gladiator's Emblem of Cruelty
	 61030, -- Vicious Gladiator's Emblem of Proficiency
	 61031, -- Vicious Gladiator's Emblem of Meditation
	 61032, -- Vicious Gladiator's Emblem of Tenacity
}
trinkets[ 84966] =  61034 -- Call of Victory (Vicious Gladiator's Badge of Victory)
trinkets[ 84968] =  61035 -- Call of Dominance (Vicious Gladiator's Badge of Dominance)
trinkets[ 84969] =  61033 -- Call of Conquest (Vicious Gladiator's Badge of Conquest)
trinkets[ 85022] =  61047 -- Surge of Conquest (Vicious Gladiator's Insignia of Conquest)
trinkets[ 85027] =  61045 -- Surge of Dominance (Vicious Gladiator's Insignia of Dominance)
trinkets[ 85032] =  61046 -- Surge of Victory (Vicious Gladiator's Insignia of Victory)
trinkets[ 89091] =  62047 -- Volcanic Destruction (Darkmoon Card: Volcano)
trinkets[ 89181] =  62048 -- Mighty Earthquake (Darkmoon Card: Earthquake)
trinkets[ 89182] =  62050 -- Giant Wave (Darkmoon Card: Tsunami)
trinkets[ 90842] =  57346 -- Mindfletcher (Mindfletcher Talisman)
trinkets[ 90847] = { -- Prismatic
	 59661, -- Pelagic Prism
	 59664, -- Pelagic Prism
}
trinkets[ 90854] = { -- Visionary
	 59630, -- Severed Visionary Tentacle
	 59633, -- Severed Visionary Tentacle
}
trinkets[ 90885] =  55787 -- Witching Hour (Witching Hourglass)
trinkets[ 90887] =  56320 -- Witching Hour (Witching Hourglass)
trinkets[ 90889] =  61429 -- Fury of the Earthen (Insignia of the Earthen Lord)
trinkets[ 90895] =  61411 -- Kiss of Death (Stonemother's Kiss)
trinkets[ 90896] =  55810 -- Tendrils of Darkness (Tendrils of Burrowing Dark)
trinkets[ 90898] = { -- Tendrils of Darkness
	 56339, -- Tendrils of Burrowing Dark
	133216, -- Tendrils of Burrowing Dark
}
trinkets[ 90900] =  63842 -- Focus (World-Queller Focus)
trinkets[ 90953] =  56138 -- Dead Winds (Gale of Shadows)
trinkets[ 90985] = { -- Dead Winds
	 56462, -- Gale of Shadows
	133304, -- Gale of Shadows
}
trinkets[ 90989] =  55889 -- Hymn of Power (Anhuur's Hymnal)
trinkets[ 90992] =  56407 -- Hymn of Power (Anhuur's Hymnal)
trinkets[ 90996] =  55879 -- Crescendo of Suffering (Sorrowsong)
trinkets[ 91002] = { -- Crescendo of Suffering
	 56400, -- Sorrowsong
	133275, -- Sorrowsong
}
trinkets[ 91007] =  59326 -- Dire Magic (Bell of Enraging Resonance)
trinkets[ 91019] =  58183 -- Soul Power (Soul Casket)
trinkets[ 91024] =  59519 -- Revelation (Theralion's Mirror)
trinkets[ 91027] =  59514 -- Heart's Revelation (Heart of Ignacious)
trinkets[ 91041] =  59514 -- Heart's Judgment (Heart of Ignacious)
trinkets[ 91047] = { -- Battle Magic
	 62465, -- Stump of Time
	 62470, -- Stump of Time
}
trinkets[ 91075] =  63839 -- Vengeful Wisp (Harmlight Token)
trinkets[ 91135] =  55256 -- Leviathan (Sea Star)
trinkets[ 91136] = { -- Leviathan
	 56290, -- Sea Star
	133201, -- Sea Star
}
trinkets[ 91138] =  55819 -- Cleansing Tears (Tear of Blood)
trinkets[ 91139] = { -- Cleansing Tears
	 56351, -- Tear of Blood
	133227, -- Tear of Blood
}
trinkets[ 91141] =  55854 -- Anthem (Rainsong)
trinkets[ 91143] = 133252 -- Anthem (Rainsong)
trinkets[ 91147] =  55995 -- Blessing of Isiset (Blood of Isiset)
trinkets[ 91149] =  56414 -- Blessing of Isiset (Blood of Isiset)
trinkets[ 91155] =  58184 -- Expansive Soul (Core of Ripeness)
trinkets[ 91173] =  60233 -- Celerity (Shard of Woe)
trinkets[ 91184] =  59500 -- Grounded Soul (Fall of Mortality)
trinkets[ 91192] = { -- Pattern of Light
	 62467, -- Mandala of Stirring Patterns
	 62472, -- Mandala of Stirring Patterns
}
trinkets[ 91296] =  56136 -- Egg Shell (Corrupted Egg Shell)
trinkets[ 91308] = { -- Egg Shell
	 56463, -- Corrupted Egg Shell
	133305, -- Corrupted Egg Shell
}
trinkets[ 91320] =  59354 -- Inner Eye (Jar of Ancient Remedies)
trinkets[ 91322] =  59354 -- Blind Spot (Jar of Ancient Remedies)
trinkets[ 91336] =  57316 -- Heavy Lifting (Egg-Lift Talisman)
trinkets[ 91338] =  59792 -- Dietary Enhancement (Petrified Spider Crab)
trinkets[ 91340] = { -- Typhoon
	 56285, -- Might of the Ocean
	133197, -- Might of the Ocean
}
trinkets[ 91341] =  66994 -- Typhoon (Soul's Anguish)
trinkets[ 91344] = { -- Battle!
	 59685, -- Kvaldir Battle Standard
	 59689, -- Kvaldir Battle Standard
}
trinkets[ 91345] =  61448 -- Favored (Oremantle's Favor)
trinkets[ 91351] =  55814 -- Polarization (Magnetite Mirror)
trinkets[ 91352] = { -- Polarization
	 56345, -- Magnetite Mirror
	133222, -- Magnetite Mirror
}
trinkets[ 91355] = { -- Fatality
	 63838, -- Shrine-Cleansing Purifier
	 63841, -- Tank-Commander Insignia
}
trinkets[ 91363] =  55868 -- Heartened (Heart of Solace)
trinkets[ 91364] = { -- Heartened
	 56393, -- Heart of Solace
	133268, -- Heart of Solace
}
trinkets[ 91368] =  56431 -- Eye of Doom (Right Eye of Rajh)
trinkets[ 91370] =  56100 -- Eye of Doom (Right Eye of Rajh)
trinkets[ 91374] = { -- Battle Prowess
	 56458, -- Mark of Khardros
	133300, -- Mark of Khardros
}
trinkets[ 91376] =  56132 -- Battle Prowess (Mark of Khardros)
trinkets[ 91810] =  58180 -- Slayer (License to Slay)
trinkets[ 91816] =  59224 -- Rageheart (Heart of Rage)
trinkets[ 91821] =  59506 -- Race Against Death (Crushing Weight)
trinkets[ 91828] = { -- Thrill of Victory
	 62464, -- Impatience of Youth
	 62469, -- Impatience of Youth
}
trinkets[ 91832] =  59461 -- Raw Fury (Fury of Angerforge)
trinkets[ 91836] =  59461 -- Forged Fury (Fury of Angerforge)
trinkets[ 92043] =  57325 -- Invigorated (Bileberry Smelling Salts)
trinkets[ 92045] = { -- Power of Focus
	 59707, -- Wavespeaker's Focus
	 59710, -- Wavespeaker's Focus
}
trinkets[ 92052] =  66969 -- Herald of Doom (Heart of the Vile)
trinkets[ 92055] =  61462 -- Gear Detected! (Gear Detector)
trinkets[ 92069] =  55795 -- Final Key (Key to the Endless Chamber)
trinkets[ 92071] = { -- Nimble
	 63840, -- Juju of Nimbleness
	 63843, -- Blood-Soaked Ale Mug
}
trinkets[ 92085] =  55874 -- Grace (Tia's Grace)
trinkets[ 92087] =  56295 -- Herald of Doom (Grace of the Herald)
trinkets[ 92089] = { -- Grace
	 56394, -- Tia's Grace
	133269, -- Tia's Grace
}
trinkets[ 92091] = { -- Final Key
	 56328, -- Key to the Endless Chamber
	133206, -- Key to the Endless Chamber
}
trinkets[ 92094] =  56427 -- Eye of Vengeance (Left Eye of Rajh)
trinkets[ 92096] =  56102 -- Eye of Vengeance (Left Eye of Rajh)
trinkets[ 92098] =  56115 -- Speed of Thought (Skardyn's Grace)
trinkets[ 92099] = { -- Speed of Thought
	 56440, -- Skardyn's Grace
	133282, -- Skardyn's Grace
}
trinkets[ 92104] =  58181 -- River of Death (Fluid Death)
trinkets[ 92108] =  59520 -- Heedless Carnage (Unheeded Warning)
trinkets[ 92123] = { -- Enigma
	 62463, -- Unsolvable Riddle
	 62468, -- Unsolvable Riddle
}
trinkets[ 92124] =  59441 -- Nefarious Plot (Prestor's Talisman of Machination)
trinkets[ 92126] =  59473 -- Twisted (Essence of the Cyclone)
trinkets[ 92162] =  59617 -- Mentally Prepared (Mentalist's Protective Bottle)
trinkets[ 92166] =  65804 -- Hardened Shell (Talisman of Sinister Order)
trinkets[ 92172] =  61433 -- Great Fortitude (Insignia of Diplomacy)
trinkets[ 92174] = { -- Hardened Shell
	 56280, -- Porcelain Crab
	133192, -- Porcelain Crab
}
trinkets[ 92179] =  55816 -- Lead Plating (Leaden Despair)
trinkets[ 92184] = { -- Lead Plating
	 56347, -- Leaden Despair
	133224, -- Leaden Despair
}
trinkets[ 92186] =  55845 -- Amazing Fortitude (Heart of Thunder)
trinkets[ 92187] = { -- Amazing Fortitude
	 56370, -- Heart of Thunder
	133246, -- Heart of Thunder
}
trinkets[ 92188] = { -- Master Tactician
	 63742, -- Za'brox's Lucky Tooth
	 63745, -- Za'brox's Lucky Tooth
}
trinkets[ 92199] =  55881 -- Blademaster (Impetuous Query)
trinkets[ 92200] = 133281 -- Blademaster (Impetuous Query)
trinkets[ 92205] = { -- Duelist
	 56449, -- Throngus's Finger
	133291, -- Throngus's Finger
}
trinkets[ 92208] =  56121 -- Duelist (Throngus's Finger)
trinkets[ 92213] =  59515 -- Memory of Invincibility (Vial of Stolen Memories)
trinkets[ 92216] =  64763 -- Surge of Conquest (Bloodthirsty Gladiator's Insignia of Victory)
trinkets[ 92218] =  64762 -- Surge of Dominance (Bloodthirsty Gladiator's Insignia of Dominance)
trinkets[ 92220] =  64761 -- Surge of Conquest (Bloodthirsty Gladiator's Insignia of Conquest)
trinkets[ 92222] = { -- Image of Immortality
	 62466, -- Mirror of Broken Images
	 62471, -- Mirror of Broken Images
}
trinkets[ 92223] = { -- Tremendous Fortitude
	 64740, -- Bloodthirsty Gladiator's Emblem of Cruelty
	 64741, -- Bloodthirsty Gladiator's Emblem of Meditation
	 64742, -- Bloodthirsty Gladiator's Emblem of Tenacity
}
trinkets[ 92224] =  64689 -- Call of Victory (Bloodthirsty Gladiator's Badge of Victory)
trinkets[ 92225] =  64688 -- Call of Dominance (Bloodthirsty Gladiator's Badge of Dominance)
trinkets[ 92226] =  64687 -- Call of Conquest (Bloodthirsty Gladiator's Badge of Conquest)
trinkets[ 92233] =  58182 -- Tectonic Shift (Bedrock Talisman)
trinkets[ 92235] =  59332 -- Turn of the Worm (Symbiotic Worm)
trinkets[ 92318] =  65053 -- Dire Magic (Bell of Enraging Resonance)
trinkets[ 92320] =  65105 -- Revelation (Theralion's Mirror)
trinkets[ 92325] =  65110 -- Heart's Revelation (Heart of Ignacious)
trinkets[ 92328] =  65110 -- Heart's Judgment (Heart of Ignacious)
trinkets[ 92329] =  65029 -- Inner Eye (Jar of Ancient Remedies)
trinkets[ 92331] =  65029 -- Blind Spot (Jar of Ancient Remedies)
trinkets[ 92332] =  65124 -- Grounded Soul (Fall of Mortality)
trinkets[ 92342] =  65118 -- Race Against Death (Crushing Weight)
trinkets[ 92345] =  65072 -- Rageheart (Heart of Rage)
trinkets[ 92349] =  65026 -- Nefarious Plot (Prestor's Talisman of Machination)
trinkets[ 92351] =  65140 -- Twisted (Essence of the Cyclone)
trinkets[ 92355] =  65048 -- Turn of the Worm (Symbiotic Worm)
trinkets[ 92357] =  65109 -- Memory of Invincibility (Vial of Stolen Memories)
trinkets[ 93248] = { -- Horn of the Traitor
	 63632, -- Horn of the Traitor
	 63633, -- Horn of the Traitor
}
trinkets[ 93740] =  65931 -- Poison Cloud (Essence of Eranikus' Shade)
trinkets[ 93791] =  63241 -- Pilla (Very Soft Pillow)
trinkets[ 95227] =  63192 -- Tosselwrench's Shrinker
trinkets[ 95870] =  66879 -- Lightning in a Bottle (Bottled Lightning)
trinkets[ 95872] =  67101 -- Undying Flames (Unquenchable Flame)
trinkets[ 95874] =  67037 -- Searing Words (Binding Promise)
trinkets[ 95875] =  67118 -- Heartsparked (Electrospark Heartstarter)
trinkets[ 95877] =  67152 -- La-La's Song (Lady La-La's Singing Shell)
trinkets[ 95879] =  62978 -- Devourer's Stomach
trinkets[ 95880] =  62966 -- Emissary's Watch
trinkets[ 95881] =  62984 -- Omarion's Gift
trinkets[ 95882] =  62995 -- Underlord's Mandible
trinkets[ 96908] =  68926 -- Victory (Jaws of Defeat)
trinkets[ 96911] =  68927 -- Devour (The Hungerer)
trinkets[ 96923] = { -- Titanic Power
	 68972, -- Apparatus of Khaz'goroth
	 69113, -- Apparatus of Khaz'goroth
}
trinkets[ 96945] =  68981 -- Loom of Fate (Spidersilk Spindle)
trinkets[ 96962] =  68982 -- Soul Fragment (Necromantic Focus)
trinkets[ 96980] =  68995 -- Accelerated (Vessel of Acceleration)
trinkets[ 96988] =  68996 -- Stay of Execution
trinkets[ 97007] =  68998 -- Mark of the Firelord (Rune of Zeth)
trinkets[ 97008] =  69000 -- Fiery Quintessence
trinkets[ 97009] =  69001 -- Ancient Petrified Seed
trinkets[ 97010] =  69002 -- Essence of the Eternal Flame
trinkets[ 97121] =  69111 -- Victory (Jaws of Defeat)
trinkets[ 97125] =  69112 -- Devour (The Hungerer)
trinkets[ 97129] =  69138 -- Loom of Fate (Spidersilk Spindle)
trinkets[ 97131] =  69139 -- Soul Fragment (Necromantic Focus)
trinkets[ 97142] =  69167 -- Accelerated (Vessel of Acceleration)
trinkets[ 99711] =  70517 -- Call of Conquest (Vicious Gladiator's Badge of Conquest)
trinkets[ 99712] =  70518 -- Call of Dominance (Vicious Gladiator's Badge of Dominance)
trinkets[ 99713] =  70519 -- Call of Victory (Vicious Gladiator's Badge of Victory)
trinkets[ 99714] = { -- Tremendous Fortitude
	 70563, -- Vicious Gladiator's Emblem of Cruelty
	 70564, -- Vicious Gladiator's Emblem of Meditation
	 70565, -- Vicious Gladiator's Emblem of Tenacity
}
trinkets[ 99717] =  70577 -- Surge of Conquest (Vicious Gladiator's Insignia of Conquest)
trinkets[ 99719] =  70578 -- Surge of Dominance (Vicious Gladiator's Insignia of Dominance)
trinkets[ 99721] =  70579 -- Surge of Victory (Vicious Gladiator's Insignia of Victory)
trinkets[ 99737] = { -- Tremendous Fortitude
	 70396, -- Ruthless Gladiator's Emblem of Cruelty
	 70397, -- Ruthless Gladiator's Emblem of Meditation
	 70398, -- Ruthless Gladiator's Emblem of Tenacity
}
trinkets[ 99739] =  70399 -- Call of Conquest (Ruthless Gladiator's Badge of Conquest)
trinkets[ 99740] =  70400 -- Call of Victory (Ruthless Gladiator's Badge of Victory)
trinkets[ 99741] =  70401 -- Call of Dominance (Ruthless Gladiator's Badge of Dominance)
trinkets[ 99742] =  70402 -- Surge of Dominance (Ruthless Gladiator's Insignia of Dominance)
trinkets[ 99746] =  70403 -- Surge of Victory (Ruthless Gladiator's Insignia of Victory)
trinkets[ 99748] =  70404 -- Surge of Conquest (Ruthless Gladiator's Insignia of Conquest)
trinkets[ 99915] =  70141 -- Caber Toss (Dwyer's Caber)
trinkets[100322] =  70141 -- Pumped Up (Dwyer's Caber)
trinkets[100612] =  70142 -- Summon Moonwell (Moonwell Chalice)
trinkets[101287] =  71335 -- Reflection of Torment (Coren's Chilled Chromium Coaster)
trinkets[101289] =  71336 -- Essence of Life (Petrified Pickled Egg)
trinkets[101291] =  71337 -- Now is the time! (Mithril Stopwatch)
trinkets[101293] =  71338 -- Drunken Evasiveness (Brawler's Trophy)
trinkets[101492] =  70143 -- Summon Splashing Waters (Moonwell Phial)
trinkets[101515] =  70144 -- Charged Blows (Ricket's Magnetic Fireball)
trinkets[102432] =  72455 -- Surge of Victory (Ruthless Gladiator's Insignia of Victory)
trinkets[102434] =  72450 -- Call of Victory (Ruthless Gladiator's Badge of Victory)
trinkets[102435] =  72449 -- Surge of Dominance (Ruthless Gladiator's Insignia of Dominance)
trinkets[102437] =  72448 -- Call of Dominance (Ruthless Gladiator's Badge of Dominance)
trinkets[102438] = { -- Tremendous Fortitude
	 72359, -- Ruthless Gladiator's Emblem of Cruelty
	 72360, -- Ruthless Gladiator's Emblem of Tenacity
	 72361, -- Ruthless Gladiator's Emblem of Meditation
}
trinkets[102439] =  72309 -- Surge of Conquest (Ruthless Gladiator's Insignia of Conquest)
trinkets[102441] =  72304 -- Call of Conquest (Ruthless Gladiator's Badge of Conquest)
trinkets[102543] = 124514 -- Incarnation: King of the Jungle (Seed of Creation)
trinkets[102558] = 124514 -- Incarnation: Guardian of Ursoc (Seed of Creation)
trinkets[102560] = 124514 -- Incarnation: Chosen of Elune (Seed of Creation)
trinkets[102659] = { -- Arrow of Time
	 72897, -- Arrow of Time
	133420, -- Arrow of Time
}
trinkets[102660] =  72901 -- Rosary of Light
trinkets[102662] =  72898 -- Foul Gift (Foul Gift of the Demon Lord)
trinkets[102664] =  72899 -- Varo'then's Brooch
trinkets[102667] =  72900 -- Veil of Lies
trinkets[102740] = { -- Strength of Courage
	 73062, -- Zealous Idol of Battle
	 73155, -- Ebonsoul Idol of Battle
	 73165, -- Valiant Idol of Battle
}
trinkets[102741] = { -- Avoidance of the Snake
	 73060, -- Zealous Defender's Idol
	 73157, -- Ebonsoul Defender's Idol
	 73167, -- Valiant Defender's Idol
	 88636, -- Monastic Defender's Idol
}
trinkets[102742] = { -- Mastery of Nimbleness
	 73042, -- Zealous Defender's Stone
	 73061, -- Zealous Stone of Battle
	 73067, -- Wildsoul Stone of Rage
	 73121, -- Shadowstalking Stone of Rage
	 73135, -- Stormbinder Stone of Rage
	 73150, -- Beastsoul Stone of Rage
	 73154, -- Ebonsoul Stone of Battle
	 73160, -- Ebonsoul Defender's Stone
	 73164, -- Valiant Stone of Battle
	 73170, -- Valiant Defender's Stone
	 88634, -- Monastic Defender's Stone
	 88639, -- Monastic Stone of Rage
}
trinkets[102744] = { -- Haste of the Mongoose
	 73065, -- Wildsoul Stone of Destruction
	 73101, -- Magesoul Stone of Destruction
	 73106, -- Dreadsoul Stone of Destruction
	 73116, -- Seraphic Stone of Destruction
	 73140, -- Stormbinder Stone of Destruction
}
trinkets[102746] = { -- Spirit of Wisdom
	 73063, -- Zealous Idol of Wisdom
	 73114, -- Seraphic Idol of Wisdom
	 73129, -- Wildsoul Idol of Wisdom
	 73142, -- Stormbinder Idol of Wisdom
	 88647, -- Monastic Idol of Wisdom
}
trinkets[102747] = { -- Agility of the Tiger
	 73068, -- Wildsoul Idol of Rage
	 73124, -- Shadowstalking Idol of Rage
	 73132, -- Stormbinder Idol of Rage
	 73147, -- Beastsoul Idol of Rage
	 88642, -- Monastic Idol of Rage
}
trinkets[102748] = { -- Intellect of the Sage
	 73066, -- Wildsoul Idol of Destruction
	 73104, -- Magesoul Idol of Destruction
	 73109, -- Dreadsoul Idol of Destruction
	 73119, -- Seraphic Idol of Destruction
	 73137, -- Stormbinder Idol of Destruction
}
trinkets[105132] =  73648 -- Call of Conquest (Cataclysmic Gladiator's Badge of Conquest)
trinkets[105133] =  73496 -- Call of Victory (Cataclysmic Gladiator's Badge of Victory)
trinkets[105134] =  73498 -- Call of Dominance (Cataclysmic Gladiator's Badge of Dominance)
trinkets[105135] =  73643 -- Surge of Conquest (Cataclysmic Gladiator's Insignia of Conquest)
trinkets[105137] =  73497 -- Surge of Dominance (Cataclysmic Gladiator's Insignia of Dominance)
trinkets[105139] =  73491 -- Surge of Victory (Cataclysmic Gladiator's Insignia of Victory)
trinkets[105144] = { -- Tremendous Fortitude
	 73591, -- Cataclysmic Gladiator's Emblem of Meditation
	 73592, -- Cataclysmic Gladiator's Emblem of Tenacity
	 73593, -- Cataclysmic Gladiator's Emblem of Cruelty
}
trinkets[106951] = 124514 -- Berserk (Seed of Creation)
trinkets[107947] =  77113 -- Agile (Kiroptyric Sigil)
trinkets[107948] = { -- Ultimate Power
	 77114, -- Bottled Wishes
	 77115, -- Reflection of the Light
}
trinkets[107949] =  77116 -- Titanic Strength (Rotting Skull)
trinkets[107951] =  77117 -- Elusive (Fire of the Deep)
trinkets[107960] =  77197 -- Combat Trance (Wrath of Unchaining)
trinkets[107962] =  77199 -- Expansive Mind (Heart of Unliving)
trinkets[107966] =  77200 -- Titanic Strength (Eye of Unmaking)
trinkets[107968] =  77201 -- Preternatural Evasion (Resolve of Undying)
trinkets[107970] =  77198 -- Combat Mind (Will of Unbinding)
trinkets[107982] =  77204 -- Velocity (Seal of the Seven Signs)
trinkets[107986] =  77206 -- Master Tactician (Soulshifter Vortex)
trinkets[107988] =  77205 -- Find Weakness (Creche of the Final Dragon)
trinkets[109709] =  77973 -- Velocity (Starcatcher Compass)
trinkets[109711] =  77993 -- Velocity (Starcatcher Compass)
trinkets[109714] = 133537 -- Agile (Kiroptyric Sigil)
trinkets[109717] =  77974 -- Combat Trance (Wrath of Unchaining)
trinkets[109719] =  77994 -- Combat Trance (Wrath of Unchaining)
trinkets[109742] =  77972 -- Find Weakness (Creche of the Final Dragon)
trinkets[109744] =  77992 -- Find Weakness (Creche of the Final Dragon)
trinkets[109746] = 133540 -- Titanic Strength (Rotting Skull)
trinkets[109748] =  77977 -- Titanic Strength (Eye of Unmaking)
trinkets[109750] =  77997 -- Titanic Strength (Eye of Unmaking)
trinkets[109774] =  77970 -- Master Tactician (Soulshifter Vortex)
trinkets[109776] =  77990 -- Master Tactician (Soulshifter Vortex)
trinkets[109778] = 133541 -- Elusive (Fire of the Deep)
trinkets[109780] =  77978 -- Preternatural Evasion (Resolve of Undying)
trinkets[109782] =  77998 -- Preternatural Evasion (Resolve of Undying)
trinkets[109787] =  77971 -- Velocity (Insignia of the Corrupted Mind)
trinkets[109789] =  77991 -- Velocity (Insignia of the Corrupted Mind)
trinkets[109791] = { -- Ultimate Power
	133538, -- Bottled Wishes
	133539, -- Reflection of the Light
}
trinkets[109793] =  77975 -- Combat Mind (Will of Unbinding)
trinkets[109795] =  77995 -- Combat Mind (Will of Unbinding)
trinkets[109802] =  77969 -- Velocity (Seal of the Seven Signs)
trinkets[109804] =  77989 -- Velocity (Seal of the Seven Signs)
trinkets[109811] =  77976 -- Expansive Mind (Heart of Unliving)
trinkets[109813] =  77996 -- Expansive Mind (Heart of Unliving)
trinkets[109908] =  72898 -- Foul Gift (Foul Gift of the Demon Lord)
trinkets[109993] =  74035 -- Master Pit Fighter
trinkets[109994] =  74034 -- Pit Fighter
trinkets[110008] =  72901 -- Rosary of Light
trinkets[117642] =  80773 -- Singing Cricket Medallion
trinkets[117643] =  80774 -- Grove Viper Medallion
trinkets[117644] =  80775 -- Coral Adder Medallion
trinkets[117645] =  80776 -- Flamelager Medallion
trinkets[117646] =  80777 -- Amberfly Idol
trinkets[117647] =  80778 -- Silkbead Emblem (Silkbead Idol)
trinkets[117648] =  80779 -- Mirror Strider Emblem
trinkets[117649] =  80780 -- Greenpaw Idol
trinkets[117650] =  80781 -- Shoots of Life
trinkets[117651] =  80782 -- Misty Jade Idol
trinkets[118611] =  81532 -- Silkspawn Carving
trinkets[118613] =  81534 -- Carp Hunter Feather
trinkets[118614] =  81535 -- Glade Pincher Feather
trinkets[118615] =  81536 -- Jungle Huntress Idol
trinkets[118750] =  81661 -- Faded Forest Medallion
trinkets[118751] =  81662 -- Faded Forest Emblem
trinkets[118752] =  81663 -- Faded Forest Medal
trinkets[118753] =  81664 -- Faded Forest Insignia
trinkets[118754] =  81665 -- Faded Forest Badge
trinkets[118871] =  81834 -- Silkspawn Wing
trinkets[118872] =  81835 -- Plainshawk Feather
trinkets[118873] =  81836 -- Lucky "Rabbit's" Foot
trinkets[118874] =  81837 -- Viseclaw Carapace
trinkets[118875] =  81838 -- Tawnyhide Antler
trinkets[120171] =  82574 -- Coin of Blessings
trinkets[120172] =  82575 -- Coin of Serendipity
trinkets[120173] =  82576 -- Coin of Luck
trinkets[120174] =  82577 -- Coin of Good Fortune
trinkets[120175] =  82578 -- Luckydo Coin
trinkets[120176] =  82579 -- Lorewalker's Mark
trinkets[120177] =  82580 -- Lorewalker's Emblem
trinkets[120178] =  82581 -- Lorewalker's Sigil
trinkets[120179] =  82582 -- Lorewalker's Medallion
trinkets[120180] =  82583 -- Lorewalker's Insignia
trinkets[120254] =  82696 -- Mountainscaler Mark
trinkets[120255] =  82697 -- Mountainscaler Medal
trinkets[120256] =  82698 -- Mountainscaler Emblem
trinkets[120257] =  82699 -- Mountainscaler Insignia
trinkets[120258] =  82700 -- Mountainscaler Badge
trinkets[122266] =  83245 -- Wasteland Relic
trinkets[122267] =  83246 -- Wasteland Sigil
trinkets[122268] =  83247 -- Wasteland Emblem
trinkets[122269] =  83248 -- Wasteland Insignia
trinkets[122270] =  83249 -- Wasteland Badge
trinkets[122309] =  83731 -- Mark of the Catacombs
trinkets[122310] =  83732 -- Sigil of the Catacombs
trinkets[122311] =  83733 -- Emblem of the Catacombs
trinkets[122312] =  83734 -- Medallion of the Catacombs
trinkets[122313] =  83735 -- Symbol of the Catacombs
trinkets[122314] =  83736 -- Sigil of Compassion
trinkets[122315] =  83737 -- Sigil of Fidelity
trinkets[122316] =  83738 -- Sigil of Grace
trinkets[122317] =  83739 -- Sigil of Patience
trinkets[122318] =  83740 -- Sigil of Devotion
trinkets[122687] =  84071 -- Charm of Ten Songs
trinkets[122688] =  84072 -- Braid of Ten Songs
trinkets[122689] =  84073 -- Knot of Ten Songs
trinkets[122691] =  84075 -- Relic of Kypari Zar
trinkets[122692] =  84076 -- Sigil of Kypari Zar
trinkets[122693] =  84077 -- Emblem of Kypari Zar
trinkets[122694] =  84078 -- Insignia of Kypari Zar
trinkets[122695] =  84079 -- Badge of Kypari Zar
trinkets[126236] = { -- Slippery
	 81243, -- Iron Protector Talisman
	 85181, -- Iron Protector Talisman
	100999, -- Heart-Lesion Defender Idol
	101089, -- Mistdancer Defender Idol
	101160, -- Sunsoul Defender Idol
	101303, -- Oathsworn Defender Idol
	117042, -- Heart-Lesion Defender Idol
	117132, -- Mistdancer Defender Idol
	117203, -- Sunsoul Defender Idol
	117346, -- Oathsworn Defender Idol
	119492, -- Heart-Lesion Defender Idol
	119582, -- Mistdancer Defender Idol
	119653, -- Sunsoul Defender Idol
	119796, -- Oathsworn Defender Idol
	121852, -- Inexorable Defender Idol
	121925, -- Harmonious Defender Idol
	121964, -- Duskbreaker Defender Idol
	122060, -- Defiant Defender Idol
}
trinkets[126260] =  81181 -- Heart of Fire
trinkets[126266] = { -- Enlightenment
	 81133, -- Empty Fruit Barrel
	101041, -- Springrain Stone of Wisdom
	101107, -- Mistdancer Stone of Wisdom
	101138, -- Sunsoul Stone of Wisdom
	101183, -- Communal Stone of Wisdom
	101250, -- Streamtalker Stone of Wisdom
	116823, -- Katealystic Konverter
	117084, -- Springrain Stone of Wisdom
	117150, -- Mistdancer Stone of Wisdom
	117181, -- Sunsoul Stone of Wisdom
	117226, -- Communal Stone of Wisdom
	117293, -- Streamtalker Stone of Wisdom
	119534, -- Springrain Stone of Wisdom
	119600, -- Mistdancer Stone of Wisdom
	119631, -- Sunsoul Stone of Wisdom
	119676, -- Communal Stone of Wisdom
	119743, -- Streamtalker Stone of Wisdom
	121652, -- Ancient Leaf
	121885, -- Nurturer Stone of Wisdom
	121936, -- Harmonious Stone of Wisdom
	121952, -- Duskbreaker Stone of Wisdom
	121984, -- Soulward Stone of Wisdom
	122026, -- Stormseeker Stone of Wisdom
}
trinkets[126270] = { -- Vial of Ichorous Blood
	 81264, -- Vial of Ichorous Blood
	100963, -- Vial of Ichorous Blood
}
trinkets[126476] =  81192 -- Predation (Vision of the Predator)
trinkets[126478] = { -- Flashfreeze
	 81263, -- Flashfrozen Resin Globule
	100951, -- Flashfrozen Resin Globule
}
trinkets[126483] = { -- Windswept Pages
	 81125, -- Windswept Pages
	112887, -- Goc's Trophy
	113162, -- Kral'za's Resolve
	118020, -- Goc's Trophy
}
trinkets[126484] = { -- Flashing Steel
	 81265, -- Flashing Steel Talisman
	 88294, -- Flashing Steel Talisman
}
trinkets[126489] = { -- Relentlessness
	 81267, -- Searing Words
	 88355, -- Searing Words
	112886, -- Ferocity of Kor'gall
	113163, -- Kliaa's Venomclaws
}
trinkets[126513] = { -- Poised to Strike
	 81138, -- Carbonic Carbuncle
	112884, -- Might of Kor'gall
	113159, -- Probiscus of the Swampfly Queen
}
trinkets[126519] = { -- Lessons of the Darkmaster
	 81268, -- Lessons of the Darkmaster
	 88358, -- Lessons of the Darkmaster
}
trinkets[126533] = { -- Indomitable
	 86131, -- Vial of Dragon's Blood
	 86790, -- Vial of Dragon's Blood
	 87063, -- Vial of Dragon's Blood
	116127, -- Bright Coin
}
trinkets[126554] = { -- Agile
	 86132, -- Bottle of Infinite Stars
	 86791, -- Bottle of Infinite Stars
	 87057, -- Bottle of Infinite Stars
	101009, -- Springrain Idol of Rage
	101054, -- Trailseeker Idol of Rage
	101113, -- Mistdancer Idol of Rage
	101200, -- Lightdrinker Idol of Rage
	101217, -- Streamtalker Idol of Rage
	111530, -- Giantstalker's Guile
	111546, -- Grondo's Eyepatch
	114887, -- Excavated Highmaul Knicknack
	114959, -- Prickly Shadeback Thorn
	116824, -- Rabid Talbuk Horn
	117052, -- Springrain Idol of Rage
	117097, -- Trailseeker Idol of Rage
	117156, -- Mistdancer Idol of Rage
	117243, -- Lightdrinker Idol of Rage
	117260, -- Streamtalker Idol of Rage
	117537, -- Springrain Idol of Durability
	119502, -- Springrain Idol of Rage
	119547, -- Trailseeker Idol of Rage
	119606, -- Mistdancer Idol of Rage
	119693, -- Lightdrinker Idol of Rage
	119710, -- Streamtalker Idol of Rage
	119805, -- Springrain Idol of Durability
	121860, -- Nurturer Idol of Rage
	121866, -- Nurturer Idol of Durability
	121892, -- Warscout Idol of Rage
	121939, -- Harmonious Idol of Rage
	121992, -- Skulldugger Idol of Rage
	122006, -- Stormseeker Idol of Rage
	131803, -- Spine of Barax
}
trinkets[126577] = { -- Inner Brilliance
	 86133, -- Light of the Cosmos
	 86792, -- Light of the Cosmos
	 87065, -- Light of the Cosmos
}
trinkets[126582] = { -- Unwavering Might
	 86144, -- Lei Shen's Final Orders
	 86802, -- Lei Shen's Final Orders
	 87072, -- Lei Shen's Final Orders
	100991, -- Heart-Lesion Idol of Battle
	101152, -- Sunsoul Idol of Battle
	101295, -- Oathsworn Idol of Battle
	112885, -- Commander Gar's Iron Insignia
	113158, -- Dol'mak's Lucky Charm
	113253, -- Karg's Hunting Horn
	114890, -- Excavated Highmaul Doohickey
	117034, -- Heart-Lesion Idol of Battle
	117195, -- Sunsoul Idol of Battle
	117338, -- Oathsworn Idol of Battle
	118019, -- Might of the Magnaron
	119484, -- Heart-Lesion Idol of Battle
	119645, -- Sunsoul Idol of Battle
	119788, -- Oathsworn Idol of Battle
	120337, -- Novice Rylak Hunter's Horn
	121849, -- Inexorable Idol of Battle
	121961, -- Duskbreaker Idol of Battle
	122057, -- Defiant Idol of Battle
}
trinkets[126588] = { -- Arcane Secrets
	 86147, -- Qin-xi's Polarizing Seal
	 86805, -- Qin-xi's Polarizing Seal
	 87075, -- Qin-xi's Polarizing Seal
}
trinkets[126597] = { -- Jade Warlord Figurine
	 86046, -- Jade Warlord Figurine
	 86775, -- Jade Warlord Figurine
	 89079, -- Lao-Chin's Liquid Courage
}
trinkets[126599] = { -- Velocity
	 86042, -- Jade Charioteer Figurine
	 86043, -- Jade Bandit Figurine
	 86771, -- Jade Charioteer Figurine
	 86772, -- Jade Bandit Figurine
	 89082, -- Hawkmaster's Talon
}
trinkets[126605] = { -- Blossom
	 86044, -- Jade Magistrate Figurine
	 86773, -- Jade Magistrate Figurine
	 89081, -- Blossom of Pure Snow
}
trinkets[126606] = { -- Scroll of Revered Ancestors
	 86045, -- Jade Courtesan Figurine
	 86774, -- Jade Courtesan Figurine
	 89080, -- Scroll of Revered Ancestors
}
trinkets[126640] = { -- Radiance
	 86327, -- Spirits of the Sun
	 86885, -- Spirits of the Sun
	 87163, -- Spirits of the Sun
}
trinkets[126646] = { -- Untouchable
	 86323, -- Stuff of Nightmares
	 86881, -- Stuff of Nightmares
	 87160, -- Stuff of Nightmares
}
trinkets[126649] = { -- Unrelenting Attacks
	 86332, -- Terror in the Mists
	 86890, -- Terror in the Mists
	 87167, -- Terror in the Mists
}
trinkets[126657] = { -- Alacrity
	 86336, -- Darkmist Vortex
	 86894, -- Darkmist Vortex
	 87172, -- Darkmist Vortex
}
trinkets[126659] = { -- Quickened Tongues
	 86388, -- Essence of Terror
	 86907, -- Essence of Terror
	 87175, -- Essence of Terror
	101023, -- Springrain Idol of Destruction
	101069, -- Mountainsage Idol of Destruction
	101168, -- Communal Idol of Destruction
	101222, -- Streamtalker Idol of Destruction
	101263, -- Felsoul Idol of Destruction
	117066, -- Springrain Idol of Destruction
	117112, -- Mountainsage Idol of Destruction
	117211, -- Communal Idol of Destruction
	117265, -- Streamtalker Idol of Destruction
	117306, -- Felsoul Idol of Destruction
	119516, -- Springrain Idol of Destruction
	119562, -- Mountainsage Idol of Destruction
	119661, -- Communal Idol of Destruction
	119715, -- Streamtalker Idol of Destruction
	119756, -- Felsoul Idol of Destruction
	121876, -- Nurturer Idol of Destruction
	121909, -- Abstruse Idol of Destruction
	121975, -- Soulward Idol of Destruction
	122017, -- Stormseeker Idol of Destruction
	122037, -- Ruinrain Idol of Destruction
}
trinkets[126679] = { -- Call of Victory
	 84490, -- Dreadful Gladiator's Badge of Victory
	 84942, -- Malevolent Gladiator's Badge of Victory
	 91410, -- Tyrannical Gladiator's Badge of Victory
	 91763, -- Malevolent Gladiator's Badge of Victory
	 94349, -- Tyrannical Gladiator's Badge of Victory
	 99943, -- Tyrannical Gladiator's Badge of Victory
	100019, -- Tyrannical Gladiator's Badge of Victory
	100500, -- Grievous Gladiator's Badge of Victory
	100579, -- Grievous Gladiator's Badge of Victory
	102636, -- Prideful Gladiator's Badge of Victory
	102833, -- Grievous Gladiator's Badge of Victory
	103314, -- Grievous Gladiator's Badge of Victory
	103511, -- Prideful Gladiator's Badge of Victory
}
trinkets[126683] = { -- Call of Dominance
	 84488, -- Dreadful Gladiator's Badge of Dominance
	 84940, -- Malevolent Gladiator's Badge of Dominance
	 91400, -- Tyrannical Gladiator's Badge of Dominance
	 91753, -- Malevolent Gladiator's Badge of Dominance
	 94346, -- Tyrannical Gladiator's Badge of Dominance
	 99937, -- Tyrannical Gladiator's Badge of Dominance
	100016, -- Tyrannical Gladiator's Badge of Dominance
	100490, -- Grievous Gladiator's Badge of Dominance
	100576, -- Grievous Gladiator's Badge of Dominance
	102633, -- Prideful Gladiator's Badge of Dominance
	102830, -- Grievous Gladiator's Badge of Dominance
	103308, -- Grievous Gladiator's Badge of Dominance
	103505, -- Prideful Gladiator's Badge of Dominance
}
trinkets[126690] = { -- Call of Conquest
	 84344, -- Dreadful Gladiator's Badge of Conquest
	 84934, -- Malevolent Gladiator's Badge of Conquest
	 91099, -- Tyrannical Gladiator's Badge of Conquest
	 91452, -- Malevolent Gladiator's Badge of Conquest
	 94373, -- Tyrannical Gladiator's Badge of Conquest
	 99772, -- Tyrannical Gladiator's Badge of Conquest
	100043, -- Tyrannical Gladiator's Badge of Conquest
	100195, -- Grievous Gladiator's Badge of Conquest
	100603, -- Grievous Gladiator's Badge of Conquest
	102659, -- Prideful Gladiator's Badge of Conquest
	102856, -- Grievous Gladiator's Badge of Conquest
	103145, -- Grievous Gladiator's Badge of Conquest
	103342, -- Prideful Gladiator's Badge of Conquest
}
trinkets[126697] = { -- Tremendous Fortitude
	 84399, -- Dreadful Gladiator's Emblem of Cruelty
	 84400, -- Dreadful Gladiator's Emblem of Tenacity
	 84401, -- Dreadful Gladiator's Emblem of Meditation
	 84936, -- Malevolent Gladiator's Emblem of Cruelty
	 84938, -- Malevolent Gladiator's Emblem of Tenacity
	 84939, -- Malevolent Gladiator's Emblem of Meditation
	 91209, -- Tyrannical Gladiator's Emblem of Cruelty
	 91210, -- Tyrannical Gladiator's Emblem of Tenacity
	 91211, -- Tyrannical Gladiator's Emblem of Meditation
	 91562, -- Malevolent Gladiator's Emblem of Cruelty
	 91563, -- Malevolent Gladiator's Emblem of Tenacity
	 91564, -- Malevolent Gladiator's Emblem of Meditation
	 94329, -- Tyrannical Gladiator's Emblem of Meditation
	 94396, -- Tyrannical Gladiator's Emblem of Cruelty
	 94422, -- Tyrannical Gladiator's Emblem of Tenacity
	 94516, -- Fortitude of the Zandalari
	 95677, -- Fortitude of the Zandalari
	 96049, -- Fortitude of the Zandalari
	 96421, -- Fortitude of the Zandalari
	 96793, -- Fortitude of the Zandalari
	 99838, -- Tyrannical Gladiator's Emblem of Cruelty
	 99839, -- Tyrannical Gladiator's Emblem of Tenacity
	 99840, -- Tyrannical Gladiator's Emblem of Meditation
	 99990, -- Tyrannical Gladiator's Emblem of Meditation
	100066, -- Tyrannical Gladiator's Emblem of Cruelty
	100092, -- Tyrannical Gladiator's Emblem of Tenacity
	100305, -- Grievous Gladiator's Emblem of Cruelty
	100306, -- Grievous Gladiator's Emblem of Tenacity
	100307, -- Grievous Gladiator's Emblem of Meditation
	100559, -- Grievous Gladiator's Emblem of Meditation
	100626, -- Grievous Gladiator's Emblem of Cruelty
	100652, -- Grievous Gladiator's Emblem of Tenacity
	102616, -- Prideful Gladiator's Emblem of Meditation
	102680, -- Prideful Gladiator's Emblem of Cruelty
	102706, -- Prideful Gladiator's Emblem of Tenacity
	102813, -- Grievous Gladiator's Emblem of Meditation
	102877, -- Grievous Gladiator's Emblem of Cruelty
	102903, -- Grievous Gladiator's Emblem of Tenacity
	103210, -- Grievous Gladiator's Emblem of Cruelty
	103211, -- Grievous Gladiator's Emblem of Tenacity
	103212, -- Grievous Gladiator's Emblem of Meditation
	103407, -- Prideful Gladiator's Emblem of Cruelty
	103408, -- Prideful Gladiator's Emblem of Tenacity
	103409, -- Prideful Gladiator's Emblem of Meditation
}
trinkets[126700] = { -- Surge of Victory
	 84495, -- Dreadful Gladiator's Insignia of Victory
	 84937, -- Malevolent Gladiator's Insignia of Victory
	 91415, -- Tyrannical Gladiator's Insignia of Victory
	 91768, -- Malevolent Gladiator's Insignia of Victory
	 94415, -- Tyrannical Gladiator's Insignia of Victory
	 99948, -- Tyrannical Gladiator's Insignia of Victory
	100085, -- Tyrannical Gladiator's Insignia of Victory
	100505, -- Grievous Gladiator's Insignia of Victory
	100645, -- Grievous Gladiator's Insignia of Victory
	102699, -- Prideful Gladiator's Insignia of Victory
	102896, -- Grievous Gladiator's Insignia of Victory
	103319, -- Grievous Gladiator's Insignia of Victory
	103516, -- Prideful Gladiator's Insignia of Victory
}
trinkets[126705] = { -- Surge of Dominance
	 84489, -- Dreadful Gladiator's Insignia of Dominance
	 84941, -- Malevolent Gladiator's Insignia of Dominance
	 91401, -- Tyrannical Gladiator's Insignia of Dominance
	 91754, -- Malevolent Gladiator's Insignia of Dominance
	 94482, -- Tyrannical Gladiator's Insignia of Dominance
	 99938, -- Tyrannical Gladiator's Insignia of Dominance
	100152, -- Tyrannical Gladiator's Insignia of Dominance
	100491, -- Grievous Gladiator's Insignia of Dominance
	100712, -- Grievous Gladiator's Insignia of Dominance
	102766, -- Prideful Gladiator's Insignia of Dominance
	102963, -- Grievous Gladiator's Insignia of Dominance
	103309, -- Grievous Gladiator's Insignia of Dominance
	103506, -- Prideful Gladiator's Insignia of Dominance
}
trinkets[126707] = { -- Surge of Conquest
	 84349, -- Dreadful Gladiator's Insignia of Conquest
	 84935, -- Malevolent Gladiator's Insignia of Conquest
	 91104, -- Tyrannical Gladiator's Insignia of Conquest
	 91457, -- Malevolent Gladiator's Insignia of Conquest
	 94356, -- Tyrannical Gladiator's Insignia of Conquest
	 99777, -- Tyrannical Gladiator's Insignia of Conquest
	100026, -- Tyrannical Gladiator's Insignia of Conquest
	100200, -- Grievous Gladiator's Insignia of Conquest
	100586, -- Grievous Gladiator's Insignia of Conquest
	102643, -- Prideful Gladiator's Insignia of Conquest
	102840, -- Grievous Gladiator's Insignia of Conquest
	103150, -- Grievous Gladiator's Insignia of Conquest
	103347, -- Prideful Gladiator's Insignia of Conquest
}
trinkets[127549] =  87500 -- Munificence (Brooch of Munificent Deeds)
trinkets[127569] =  87499 -- Gleaming (Grakl's Gleaming Talisman)
trinkets[127572] =  87497 -- Karma (Core of Decency)
trinkets[127575] =  87495 -- Perfection (Gerp's Perfect Arrow)
trinkets[127577] =  87496 -- Final Word (Daelo's Final Words)
trinkets[127915] = { -- Essence of Life
	 87573, -- Thousand-Year Pickled Egg
	117359, -- Thousand-Year Pickled Egg
}
trinkets[127923] = { -- Now is the time!
	 87572, -- Mithril Wristwatch
	117358, -- Mithril Wristwatch
}
trinkets[127928] = { -- Reflection of Torment
	 87574, -- Coren's Cold Chromium Coaster
	117360, -- Coren's Cold Chromium Coaster
}
trinkets[127967] = { -- Drunken Evasiveness
	 87571, -- Brawler's Statue
	117357, -- Brawler's Statue
}
trinkets[128386] =  88585 -- Mantid Poison (Dislodged Stinger)
trinkets[128519] =  88371 -- Watermelon Bomb
trinkets[128521] =  88376 -- Painted Turnip (Orange Painted Turnip)
trinkets[128984] =  79328 -- Blessing of the Celestials (Relic of Xuen)
trinkets[128985] =  79331 -- Blessing of the Celestials (Relic of Yu'lon)
trinkets[128986] =  79327 -- Blessing of the Celestials (Relic of Xuen)
trinkets[128987] =  79330 -- Blessing of the Celestials (Relic of Chi-Ji)
trinkets[128988] =  79329 -- Protection of the Celestials (Relic of Niuzao)
trinkets[129812] =  89083 -- Hunger (Iron Belly Wok)
trinkets[132404] = 124523 -- Shield Block (Worldbreaker's Resolve)
trinkets[132756] = 124522 -- Corruption (Fragment of the Dark Star)
trinkets[133630] = { -- Exquisite Proficiency
	100990, -- Heart-Lesion Stone of Battle
	101002, -- Heart-Lesion Defender Stone
	101012, -- Springrain Stone of Rage
	101026, -- Springrain Stone of Destruction
	101057, -- Trailseeker Stone of Rage
	101072, -- Mountainsage Stone of Destruction
	101087, -- Mistdancer Defender Stone
	101117, -- Mistdancer Stone of Rage
	101151, -- Sunsoul Stone of Battle
	101163, -- Sunsoul Defender Stone
	101171, -- Communal Stone of Destruction
	101203, -- Lightdrinker Stone of Rage
	101220, -- Streamtalker Stone of Rage
	101225, -- Streamtalker Stone of Destruction
	101266, -- Felsoul Stone of Destruction
	101294, -- Oathsworn Stone of Battle
	101306, -- Oathsworn Defender Stone
	113254, -- Lokra's Fury
	113255, -- Asha's Fang
	113527, -- Legacy of Om'ra
	114886, -- Twisted Elemental Focus
	114889, -- Kuhlrath's Cursed Totem
	114891, -- Void-Touched Totem
	114957, -- Oversized Shadeback Talon
	116075, -- Scales of Gennadian
	116799, -- Smoldering Heart of Hyperious
	117033, -- Heart-Lesion Stone of Battle
	117045, -- Heart-Lesion Defender Stone
	117055, -- Springrain Stone of Rage
	117069, -- Springrain Stone of Destruction
	117100, -- Trailseeker Stone of Rage
	117115, -- Mountainsage Stone of Destruction
	117130, -- Mistdancer Defender Stone
	117160, -- Mistdancer Stone of Rage
	117194, -- Sunsoul Stone of Battle
	117206, -- Sunsoul Defender Stone
	117214, -- Communal Stone of Destruction
	117246, -- Lightdrinker Stone of Rage
	117263, -- Streamtalker Stone of Rage
	117268, -- Streamtalker Stone of Destruction
	117309, -- Felsoul Stone of Destruction
	117337, -- Oathsworn Stone of Battle
	117349, -- Oathsworn Defender Stone
	117540, -- Springrain Stone of Durability
	119483, -- Heart-Lesion Stone of Battle
	119495, -- Heart-Lesion Defender Stone
	119505, -- Springrain Stone of Rage
	119519, -- Springrain Stone of Destruction
	119550, -- Trailseeker Stone of Rage
	119565, -- Mountainsage Stone of Destruction
	119580, -- Mistdancer Defender Stone
	119610, -- Mistdancer Stone of Rage
	119644, -- Sunsoul Stone of Battle
	119656, -- Sunsoul Defender Stone
	119664, -- Communal Stone of Destruction
	119696, -- Lightdrinker Stone of Rage
	119713, -- Streamtalker Stone of Rage
	119718, -- Streamtalker Stone of Destruction
	119759, -- Felsoul Stone of Destruction
	119787, -- Oathsworn Stone of Battle
	119799, -- Oathsworn Defender Stone
	119808, -- Springrain Stone of Durability
	120341, -- Burning Pearl
	121848, -- Inexorable Stone of Battle
	121855, -- Inexorable Defender Stone
	121863, -- Nurturer Stone of Rage
	121869, -- Nurturer Stone of Durability
	121879, -- Nurturer Stone of Destruction
	121895, -- Warscout Stone of Rage
	121912, -- Abstruse Stone of Destruction
	121924, -- Harmonious Defender Stone
	121941, -- Harmonious Stone of Rage
	121960, -- Duskbreaker Stone of Battle
	121967, -- Duskbreaker Defender Stone
	121978, -- Soulward Stone of Destruction
	121995, -- Skulldugger Stone of Rage
	122009, -- Stormseeker Stone of Rage
	122020, -- Stormseeker Stone of Destruction
	122040, -- Ruinrain Stone of Destruction
	122056, -- Defiant Stone of Battle
	122063, -- Defiant Defender Stone
	131799, -- Zugdug's Piece of Paradise
}
trinkets[134944] =  92782 -- Footman's Resolve (Steadfast Footman's Medallion)
trinkets[134945] =  92784 -- SI:7 Training (SI:7 Operative's Manual)
trinkets[134953] =  92783 -- Grunt's Tenacity (Mark of the Hardened Grunt)
trinkets[134954] =  92785 -- Kor'kron Elite (Kor'kron Book of Hurting)
trinkets[136082] = { -- Static Charge
	 93254, -- Static-Caster's Medallion
	 93259, -- Shock-Charger Medallion
}
trinkets[136083] =  93255 -- Needle and Thread (Cutstitcher Medallion)
trinkets[136084] = { -- Sense for Weakness
	 93256, -- Skullrender Medallion
	 93261, -- Helmbreaker Medallion
}
trinkets[136085] = { -- Vapor Lock
	 93257, -- Medallion of Mystifying Vapors
	 93262, -- Vaporshield Medallion
}
trinkets[136086] = { -- Archer's Grace
	 93253, -- Woundripper Medallion
	 93258, -- Arrowflight Medallion
}
trinkets[136087] =  93260 -- Heartwarmer (Heartwarmer Medallion)
trinkets[136088] = { -- Deadeye
	 93341, -- Dominator's Deadeye Badge
	 93346, -- Deadeye Badge of the Shieldwall
}
trinkets[136089] = { -- Arcane Sight
	 93342, -- Dominator's Arcane Badge
	 93347, -- Arcane Badge of the Shieldwall
}
trinkets[136090] = { -- Mender's Charm
	 93343, -- Dominator's Mending Badge
	 93348, -- Mending Badge of the Shieldwall
}
trinkets[136091] = { -- Knightly Valor
	 93344, -- Dominator's Knightly Badge
	 93349, -- Knightly Badge of the Shieldwall
}
trinkets[136092] = { -- Superior Durability
	 93345, -- Dominator's Durable Badge
	 93350, -- Durable Badge of the Shieldwall
}
trinkets[137211] = { -- Tremendous Fortitude
	 93900, -- Inherited Mark of Tyranny
	122530, -- Inherited Mark of Tyranny
}
trinkets[138174] = 124522 -- Corruption (Fragment of the Dark Star)
trinkets[138699] =  94511 -- Superluminal (Vicious Talisman of the Shado-Pan Assault)
trinkets[138702] =  94508 -- Surge of Strength (Brutal Talisman of the Shado-Pan Assault)
trinkets[138703] =  94510 -- Acceleration (Volatile Talisman of the Shado-Pan Assault)
trinkets[138728] =  94507 -- Change of Tactics (Steadfast Talisman of the Shado-Pan Assault)
trinkets[138756] = { -- Blades of Renataki
	 94512, -- Renataki's Soul Charm
	 95625, -- Renataki's Soul Charm
	 95997, -- Renataki's Soul Charm
	 96369, -- Renataki's Soul Charm
	 96741, -- Renataki's Soul Charm
}
trinkets[138759] = { -- Feathers of Fury
	 94515, -- Fabled Feather of Ji-Kun
	 95726, -- Fabled Feather of Ji-Kun
	 96098, -- Fabled Feather of Ji-Kun
	 96470, -- Fabled Feather of Ji-Kun
	 96842, -- Fabled Feather of Ji-Kun
}
trinkets[138786] = { -- Wushoolay's Lightning
	 94513, -- Wushoolay's Final Choice
	 95669, -- Wushoolay's Final Choice
	 96041, -- Wushoolay's Final Choice
	 96413, -- Wushoolay's Final Choice
	 96785, -- Wushoolay's Final Choice
}
trinkets[138856] = { -- Cloudburst
	 94514, -- Horridon's Last Gasp
	 95641, -- Horridon's Last Gasp
	 96013, -- Horridon's Last Gasp
	 96385, -- Horridon's Last Gasp
	 96757, -- Horridon's Last Gasp
}
trinkets[138864] = { -- Blood of Power
	 94518, -- Delicate Vial of the Sanguinaire
	 95779, -- Delicate Vial of the Sanguinaire
	 96151, -- Delicate Vial of the Sanguinaire
	 96523, -- Delicate Vial of the Sanguinaire
	 96895, -- Delicate Vial of the Sanguinaire
}
trinkets[138870] = { -- Rampage
	 94519, -- Primordius' Talisman of Rage
	 95757, -- Primordius' Talisman of Rage
	 96129, -- Primordius' Talisman of Rage
	 96501, -- Primordius' Talisman of Rage
	 96873, -- Primordius' Talisman of Rage
}
trinkets[138895] = { -- Frenzy
	 94522, -- Talisman of Bloodlust
	 95748, -- Talisman of Bloodlust
	 96120, -- Talisman of Bloodlust
	 96492, -- Talisman of Bloodlust
	 96864, -- Talisman of Bloodlust
}
trinkets[138898] = { -- Breath of Many Minds
	 94521, -- Breath of the Hydra
	 95711, -- Breath of the Hydra
	 96083, -- Breath of the Hydra
	 96455, -- Breath of the Hydra
	 96827, -- Breath of the Hydra
}
trinkets[138925] = { -- Zandalari Warding
	 94525, -- Stolen Relic of Zuldazar
	 95763, -- Stolen Relic of Zuldazar
	 96135, -- Stolen Relic of Zuldazar
	 96507, -- Stolen Relic of Zuldazar
	 96879, -- Stolen Relic of Zuldazar
}
trinkets[138938] = { -- Juju Madness
	 94523, -- Bad Juju
	 95665, -- Bad Juju
	 96037, -- Bad Juju
	 96409, -- Bad Juju
	 96781, -- Bad Juju
}
trinkets[138963] = { -- Perfect Aim
	 94524, -- Unerring Vision of Lei Shen
	 95814, -- Unerring Vision of Lei Shen
	 96186, -- Unerring Vision of Lei Shen
	 96558, -- Unerring Vision of Lei Shen
	 96930, -- Unerring Vision of Lei Shen
}
trinkets[138967] = { -- Blessing of Zuldazar
	 94525, -- Stolen Relic of Zuldazar
	 95763, -- Stolen Relic of Zuldazar
	 96135, -- Stolen Relic of Zuldazar
	 96507, -- Stolen Relic of Zuldazar
	 96879, -- Stolen Relic of Zuldazar
}
trinkets[138979] = { -- Soul Barrier
	 94528, -- Soul Barrier
	 95811, -- Soul Barrier
	 96183, -- Soul Barrier
	 96555, -- Soul Barrier
	 96927, -- Soul Barrier
}
trinkets[139133] = { -- Mastermind
	 94531, -- Cha-Ye's Essence of Brilliance
	 95772, -- Cha-Ye's Essence of Brilliance
	 96144, -- Cha-Ye's Essence of Brilliance
	 96516, -- Cha-Ye's Essence of Brilliance
	 96888, -- Cha-Ye's Essence of Brilliance
	111548, -- Grondo's To-Do List
	112888, -- Anger of Kor'gall
	113161, -- Throbbing Swampfly Venom Sac
	114888, -- Excavated Highmaul Thingamabob
	114961, -- Thornmother Eye
	116077, -- Pulsating Brain of No'losh
	118202, -- Fungus-Infected Hydra Lung
}
trinkets[139170] = { -- Eye of Brutality
	 94529, -- Gaze of the Twins
	 95799, -- Gaze of the Twins
	 96171, -- Gaze of the Twins
	 96543, -- Gaze of the Twins
	 96915, -- Gaze of the Twins
}
trinkets[140380] = { -- Shield of Hydra Sputum
	 94520, -- Inscribed Bag of Hydra-Spawn
	 95712, -- Inscribed Bag of Hydra-Spawn
	 96084, -- Inscribed Bag of Hydra-Spawn
	 96456, -- Inscribed Bag of Hydra-Spawn
	 96828, -- Inscribed Bag of Hydra-Spawn
}
trinkets[144073] =  31615 -- Arcane Energy (Ancient Draenei Arcane Relic)
trinkets[144074] =  31617 -- Ferocity (Ancient Draenei War Talisman)
trinkets[144108] =  38073 -- Arcane Energy (Will of the Red Dragonflight)
trinkets[144129] = { -- Tremendous Fortitude
	 41587, -- Battlemaster's Celerity
	 41588, -- Battlemaster's Aggression
	 41589, -- Battlemaster's Resolve
	 41590, -- Battlemaster's Courage
}
trinkets[144130] =  39821 -- Spell Power (Spiritist's Focus)
trinkets[144201] =  55266 -- Herald of Doom (Grace of the Herald)
trinkets[144203] =  55237 -- Hardened Shell (Porcelain Crab)
trinkets[144205] =  55251 -- Typhoon (Might of the Ocean)
trinkets[145416] =  32492 -- Envenom (Ashtongue Talisman of Lethality)
trinkets[145417] =  32492 -- Rupture (Ashtongue Talisman of Lethality)
trinkets[145418] =  32492 -- Slice and Dice (Ashtongue Talisman of Lethality)
trinkets[146046] = { -- Expanded Mind
	102293, -- Purified Bindings of Immerseus
	104426, -- Purified Bindings of Immerseus
	104675, -- Purified Bindings of Immerseus
	104924, -- Purified Bindings of Immerseus
	105173, -- Purified Bindings of Immerseus
	105422, -- Purified Bindings of Immerseus
	112426, -- Purified Bindings of Immerseus
	112889, -- Genesaur's Greatness
	113160, -- Moonstone Luck Token
	118021, -- Goc's Eye
}
trinkets[146184] = { -- Wrath of the Darkspear
	102310, -- Black Blood of Y'Shaarj
	104652, -- Black Blood of Y'Shaarj
	104901, -- Black Blood of Y'Shaarj
	105150, -- Black Blood of Y'Shaarj
	105399, -- Black Blood of Y'Shaarj
	105648, -- Black Blood of Y'Shaarj
	112938, -- Black Blood of Y'Shaarj
}
trinkets[146218] = { -- Yu'lon's Bite
	103687, -- Yu'lon's Bite
	103987, -- Yu'lon's Bite
}
trinkets[146245] = { -- Outrage
	102298, -- Evil Eye of Galakras
	104495, -- Evil Eye of Galakras
	104744, -- Evil Eye of Galakras
	104993, -- Evil Eye of Galakras
	105242, -- Evil Eye of Galakras
	105491, -- Evil Eye of Galakras
	112703, -- Evil Eye of Galakras
}
trinkets[146250] = { -- Determination
	102305, -- Thok's Tail Tip
	104613, -- Thok's Tail Tip
	104862, -- Thok's Tail Tip
	105111, -- Thok's Tail Tip
	105360, -- Thok's Tail Tip
	105609, -- Thok's Tail Tip
	112850, -- Thok's Tail Tip
	113408, -- Greka's Dentures
}
trinkets[146285] = { -- Cruelty
	102308, -- Skeer's Bloodsoaked Talisman
	104636, -- Skeer's Bloodsoaked Talisman
	104885, -- Skeer's Bloodsoaked Talisman
	105134, -- Skeer's Bloodsoaked Talisman
	105383, -- Skeer's Bloodsoaked Talisman
	105632, -- Skeer's Bloodsoaked Talisman
	112913, -- Skeer's Bloodsoaked Talisman
}
trinkets[146296] = { -- Celestial Celerity
	103689, -- Alacrity of Xuen
	103989, -- Alacrity of Xuen
}
trinkets[146308] = { -- Dextrous
	102292, -- Assurance of Consequence
	104476, -- Assurance of Consequence
	104725, -- Assurance of Consequence
	104974, -- Assurance of Consequence
	105223, -- Assurance of Consequence
	105472, -- Assurance of Consequence
	112947, -- Assurance of Consequence
	113024, -- "Reliable" Threat Assessor
}
trinkets[146310] = { -- Restless Agility
	102311, -- Ticking Ebon Detonator
	104616, -- Ticking Ebon Detonator
	104865, -- Ticking Ebon Detonator
	105114, -- Ticking Ebon Detonator
	105363, -- Ticking Ebon Detonator
	105612, -- Ticking Ebon Detonator
	112879, -- Ticking Ebon Detonator
}
trinkets[146312] = { -- Celestial Master
	103686, -- Discipline of Xuen
	103986, -- Discipline of Xuen
}
trinkets[146314] = { -- Titanic Restoration
	102299, -- Prismatic Prison of Pride
	104478, -- Prismatic Prison of Pride
	104727, -- Prismatic Prison of Pride
	104976, -- Prismatic Prison of Pride
	105225, -- Prismatic Prison of Pride
	105474, -- Prismatic Prison of Pride
	112948, -- Prismatic Prison of Pride
}
trinkets[146317] = { -- Restless Spirit
	102309, -- Dysmorphic Samophlange of Discontinuity
	104619, -- Dysmorphic Samophlange of Discontinuity
	104868, -- Dysmorphic Samophlange of Discontinuity
	105117, -- Dysmorphic Samophlange of Discontinuity
	105366, -- Dysmorphic Samophlange of Discontinuity
	105615, -- Dysmorphic Samophlange of Discontinuity
	112877, -- Dysmorphic Samophlange of Discontinuity
}
trinkets[146323] = { -- Inward Contemplation
	103688, -- Contemplation of Chi-Ji
	103988, -- Contemplation of Chi-Ji
}
trinkets[146343] = { -- Avoidance
	102296, -- Rook's Unlucky Talisman
	104442, -- Rook's Unlucky Talisman
	104691, -- Rook's Unlucky Talisman
	104940, -- Rook's Unlucky Talisman
	105189, -- Rook's Unlucky Talisman
	105438, -- Rook's Unlucky Talisman
	112476, -- Rook's Unlucky Talisman
}
trinkets[146344] = { -- Defensive Maneuvers
	103690, -- Resolve of Niuzao
	103990, -- Resolve of Niuzao
}
trinkets[146395] = { -- Tactician
	102307, -- Curse of Hubris
	104649, -- Curse of Hubris
	104898, -- Curse of Hubris
	105147, -- Curse of Hubris
	105396, -- Curse of Hubris
	105645, -- Curse of Hubris
	112924, -- Curse of Hubris
}
trinkets[146739] = 124522 -- Corruption (Fragment of the Dark Star)
trinkets[148388] = 103639 -- White Ash (Pouch of White Ash)
trinkets[148447] = 103678 -- Winds of Time (Time-Lost Artifact)
trinkets[148896] = { -- Ferocity
	102302, -- Sigil of Rampage
	104584, -- Sigil of Rampage
	104833, -- Sigil of Rampage
	105082, -- Sigil of Rampage
	105331, -- Sigil of Rampage
	105580, -- Sigil of Rampage
	112825, -- Sigil of Rampage
}
trinkets[148897] = { -- Extravagant Visions
	102303, -- Frenzied Crystal of Rage
	104576, -- Frenzied Crystal of Rage
	104825, -- Frenzied Crystal of Rage
	105074, -- Frenzied Crystal of Rage
	105323, -- Frenzied Crystal of Rage
	105572, -- Frenzied Crystal of Rage
	112815, -- Frenzied Crystal of Rage
}
trinkets[148899] = { -- Tenacious
	102295, -- Fusion-Fire Core
	104463, -- Fusion-Fire Core
	104712, -- Fusion-Fire Core
	104961, -- Fusion-Fire Core
	105210, -- Fusion-Fire Core
	105459, -- Fusion-Fire Core
	111547, -- Grondo's Spare Eye
	112503, -- Fusion-Fire Core
	113025, -- External Combustion Engine
}
trinkets[148903] = { -- Vicious
	102301, -- Haromm's Talisman
	104531, -- Haromm's Talisman
	104780, -- Haromm's Talisman
	105029, -- Haromm's Talisman
	105278, -- Haromm's Talisman
	105527, -- Haromm's Talisman
	112754, -- Haromm's Talisman
}
trinkets[148906] = { -- Toxic Power
	102300, -- Kardris' Toxic Totem
	104544, -- Kardris' Toxic Totem
	104793, -- Kardris' Toxic Totem
	105042, -- Kardris' Toxic Totem
	105291, -- Kardris' Toxic Totem
	105540, -- Kardris' Toxic Totem
	112768, -- Kardris' Toxic Totem
	113023, -- Foolproof Targeting Mechanism
	118230, -- Smoldering Cerulean Stone
}
trinkets[148908] = { -- Mark of Salvation
	102294, -- Nazgrim's Burnished Insignia
	104553, -- Nazgrim's Burnished Insignia
	104802, -- Nazgrim's Burnished Insignia
	105051, -- Nazgrim's Burnished Insignia
	105300, -- Nazgrim's Burnished Insignia
	105549, -- Nazgrim's Burnished Insignia
	112778, -- Nazgrim's Burnished Insignia
}
trinkets[148911] = { -- Soothing Power
	102304, -- Thok's Acid-Grooved Tooth
	104611, -- Thok's Acid-Grooved Tooth
	104860, -- Thok's Acid-Grooved Tooth
	105109, -- Thok's Acid-Grooved Tooth
	105358, -- Thok's Acid-Grooved Tooth
	105607, -- Thok's Acid-Grooved Tooth
	112849, -- Thok's Acid-Grooved Tooth
}
trinkets[155447] = 108902 -- Armored Elekk Tusk
trinkets[160818] = { -- Rapid Corrosion
	111533, -- Corrosive Tongue of Reeg'ak
	118229, -- Resonant Hidecrystal of the Gorger
}
trinkets[162913] = 112317 -- Visions of the Future (Winged Hourglass)
trinkets[162915] = 112318 -- Spirit of the Warlords (Skull of War)
trinkets[162917] = 112319 -- Strength of Steel (Knight's Badge)
trinkets[162919] = 112320 -- Nightmare Fire (Sandman's Pouch)
trinkets[165485] = { -- Mastery
	109997, -- Kihra's Adrenaline Injector
	114369, -- Tormented Fang of Gore
}
trinkets[165531] = { -- Haste
	110002, -- Fleshrender's Meathook
	114366, -- Tormented Tooth of Ferocity
}
trinkets[165532] = { -- Critical Strike
	110007, -- Voidmender's Shadowgem
	110012, -- Bonemaw's Big Toe
}
trinkets[165534] = { -- Versatility
	110017, -- Enforcer's Stun Grenade
	114368, -- Tormented Insignia of Dreams
}
trinkets[165535] = { -- Mastery
	110008, -- Tharbek's Lucky Pebble
	110018, -- Kyrak's Vileblood Serum
}
trinkets[165540] = 114367 -- Critical Strike (Tormented Emblem of Flame)
trinkets[165542] = 109998 -- Critical Strike (Gor'ashan's Lodestone Spike)
trinkets[165543] = { -- Versatility
	110003, -- Ragewing's Firefang
	110013, -- Emberscale Talisman
	114370, -- Tormented Seal of Fortitude
}
trinkets[165822] = { -- Haste
	109999, -- Witherbark's Branch
	110014, -- Spores of Alacrity
	114430, -- Munificent Bonds of Fury
	118779, -- Bladespike Charm
}
trinkets[165824] = { -- Mastery
	110019, -- Xeri'tac's Unhatched Egg Sac
	113663, -- Petrified Flesh-Eating Spore
	114429, -- Munificent Censer of Tranquility
	118776, -- Talisman of the Invader
	118778, -- Ironmender's Totem
	118780, -- Bloodburn Protector
}
trinkets[165830] = { -- Critical Strike
	114427, -- Munificent Emblem of Terror
	118777, -- Bloodcaster's Charm
}
trinkets[165832] = 110004 -- Critical Strike (Coagulated Genesaur Blood)
trinkets[165833] = { -- Versatility
	110009, -- Leaf of the Ancient Protectors
	114428, -- Munificent Orb of Ice
	114431, -- Munificent Soul of Compassion
}
trinkets[170397] = { -- Rapid Adaptation
	135691, -- Vindictive Gladiator's Badge of Conquest
	135697, -- Vindictive Gladiator's Badge of Dominance
	135700, -- Vindictive Gladiator's Badge of Victory
	135703, -- Vindictive Gladiator's Badge of Adaptation
	135804, -- Vindictive Gladiator's Badge of Conquest
	135810, -- Vindictive Gladiator's Badge of Dominance
	135813, -- Vindictive Gladiator's Badge of Victory
	135816, -- Vindictive Gladiator's Badge of Adaptation
	135917, -- Vindictive Combatant's Badge of Conquest
	135923, -- Vindictive Combatant's Badge of Dominance
	135926, -- Vindictive Combatant's Badge of Victory
	135929, -- Vindictive Combatant's Badge of Adaptation
	136030, -- Vindictive Combatant's Badge of Conquest
	136036, -- Vindictive Combatant's Badge of Dominance
	136039, -- Vindictive Combatant's Badge of Victory
	136042, -- Vindictive Combatant's Badge of Adaptation
	136143, -- Vindictive Gladiator's Badge of Conquest
	136149, -- Vindictive Gladiator's Badge of Dominance
	136152, -- Vindictive Gladiator's Badge of Victory
	136155, -- Vindictive Gladiator's Badge of Adaptation
	136256, -- Vindictive Gladiator's Badge of Conquest
	136262, -- Vindictive Gladiator's Badge of Dominance
	136265, -- Vindictive Gladiator's Badge of Victory
	136268, -- Vindictive Gladiator's Badge of Adaptation
}
trinkets[172691] = 117402 -- Shadow Reflector (Ultra-Electrified Reflector)
trinkets[172693] = 117403 -- Frostfire Reflector (Gyro-Radiant Reflector)
trinkets[173834] = 118211 -- ROLKOR SMASH (Rolkor's Rage)
trinkets[176050] =  32492 -- Kidney Shot (Ashtongue Talisman of Lethality)
trinkets[176460] = 118884 -- Kyb's Foolish Perseverance
trinkets[176873] = 113905 -- Turnbuckle Terror (Tablet of Turnbuckle Teamwork)
trinkets[176874] = 113969 -- Convulsive Shadows (Vial of Convulsive Shadows)
trinkets[176875] = 113835 -- Void Shards (Shards of Nothing)
trinkets[176876] = 113834 -- Vision of the Cyclops (Pol's Blinded Eye)
trinkets[176878] = 113931 -- Lub-Dub (Beating Heart of the Mountain)
trinkets[176879] = 113842 -- Caustic Healing (Emblem of Caustic Healing)
trinkets[176881] = 114491 -- Turbulent Emblem
trinkets[176882] = 114489 -- Turbulent Focusing Crystal
trinkets[176883] = 114488 -- Turbulent Vial of Toxin
trinkets[176884] = 114490 -- Turbulent Relic of Mendacity
trinkets[176885] = 114492 -- Turbulent Seal of Defiance
trinkets[176903] = 118877 -- Fizzlebang's Folly
trinkets[176912] = 118881 -- Bajheric Bangle
trinkets[176914] = 118879 -- Everblooming Thorny Hibiscus
trinkets[176917] = 118875 -- Pajeet-Nov's Perpetual Puzzle
trinkets[176928] = 118883 -- Bronzed Elekk Statue
trinkets[176935] = 114613 -- Formidable Fang
trinkets[176937] = 114614 -- Formidable Relic of Blood
trinkets[176939] = 114610 -- Formidable Jar of Doom
trinkets[176941] = 114611 -- Formidable Orb of Putrescence
trinkets[176943] = 114612 -- Formidable Censer of Faith
trinkets[176974] = 116292 -- Mote of the Mountain
trinkets[176978] = 116291 -- Immaculate Living Mushroom
trinkets[176980] = 116315 -- Heart of the Fury (Furyheart Talisman)
trinkets[176982] = 116318 -- Stoneheart Idol
trinkets[176984] = 116314 -- Blackheart Enforcer's Medallion
trinkets[177035] = 118114 -- Meaty Dragonspine Trophy
trinkets[177038] = 113612 -- Balanced Fate (Scales of Doom)
trinkets[177040] = 113645 -- Tectus' Heartbeat (Tectus' Beating Heart)
trinkets[177042] = 119193 -- Screaming Spirits (Horn of Screaming Spirits)
trinkets[177046] = 119194 -- Howling Soul (Goren Soul Repository)
trinkets[177051] = 113948 -- Instability (Darmac's Unstable Talisman)
trinkets[177053] = 113861 -- Gazing Eye (Evergaze Arcane Eidolon)
trinkets[177056] = 113893 -- Blast Furnace (Blast Furnace Door)
trinkets[177060] = 119192 -- Squeak Squeak (Ironspike Chew Toy)
trinkets[177063] = 113889 -- Elemental Shield (Elementalist's Shielding Talisman)
trinkets[177067] = 113985 -- Detonation (Humming Blackiron Trigger)
trinkets[177081] = 113984 -- Molten Metal (Blackiron Micro Crucible)
trinkets[177086] = 113986 -- Sanitizing (Auto-Repairing Autoclave)
trinkets[177096] = 113983 -- Forgemaster's Vigor (Forgemaster's Insignia)
trinkets[177102] = 113987 -- Battering (Battering Talisman)
trinkets[177189] = 118882 -- Sword Technique (Scabbard of Kyanos)
trinkets[177594] = 118878 -- Sudden Clarity (Copeland's Clarity)
trinkets[177597] = 118876 -- "Lucky" Flip (Lucky Double-Sided Coin)
trinkets[181706] = { -- Savage Fortitude
	111224, -- Primal Gladiator's Emblem of Cruelty
	111225, -- Primal Gladiator's Emblem of Tenacity
	111226, -- Primal Gladiator's Emblem of Meditation
	115151, -- Primal Combatant's Emblem of Cruelty
	115152, -- Primal Combatant's Emblem of Tenacity
	115153, -- Primal Combatant's Emblem of Meditation
	115751, -- Primal Gladiator's Emblem of Cruelty
	115752, -- Primal Gladiator's Emblem of Tenacity
	115753, -- Primal Gladiator's Emblem of Meditation
	117731, -- Tournament Gladiator's Emblem of Cruelty
	117732, -- Tournament Gladiator's Emblem of Tenacity
	117733, -- Tournament Gladiator's Emblem of Meditation
	117932, -- Tournament Gladiator's Emblem of Cruelty
	117933, -- Tournament Gladiator's Emblem of Tenacity
	117934, -- Tournament Gladiator's Emblem of Meditation
	119928, -- Primal Combatant's Emblem of Cruelty
	119929, -- Primal Combatant's Emblem of Tenacity
	119930, -- Primal Combatant's Emblem of Meditation
	124858, -- Wild Gladiator's Emblem of Cruelty
	124859, -- Wild Gladiator's Emblem of Tenacity
	124860, -- Wild Gladiator's Emblem of Meditation
	125032, -- Wild Combatant's Emblem of Cruelty
	125033, -- Wild Combatant's Emblem of Tenacity
	125034, -- Wild Combatant's Emblem of Meditation
	125337, -- Wild Gladiator's Emblem of Cruelty
	125338, -- Wild Gladiator's Emblem of Tenacity
	125339, -- Wild Gladiator's Emblem of Meditation
	125509, -- Wild Combatant's Emblem of Cruelty
	125510, -- Wild Combatant's Emblem of Tenacity
	125511, -- Wild Combatant's Emblem of Meditation
	125972, -- Warmongering Gladiator's Emblem of Cruelty
	125973, -- Warmongering Gladiator's Emblem of Tenacity
	125974, -- Warmongering Gladiator's Emblem of Meditation
	126146, -- Warmongering Combatant's Emblem of Cruelty
	126147, -- Warmongering Combatant's Emblem of Tenacity
	126148, -- Warmongering Combatant's Emblem of Meditation
	126451, -- Warmongering Gladiator's Emblem of Cruelty
	126452, -- Warmongering Gladiator's Emblem of Tenacity
	126453, -- Warmongering Gladiator's Emblem of Meditation
	126623, -- Warmongering Combatant's Emblem of Cruelty
	126624, -- Warmongering Combatant's Emblem of Tenacity
	126625, -- Warmongering Combatant's Emblem of Meditation
	135694, -- Vindictive Gladiator's Emblem of Cruelty
	135695, -- Vindictive Gladiator's Emblem of Tenacity
	135696, -- Vindictive Gladiator's Emblem of Meditation
	135807, -- Vindictive Gladiator's Emblem of Cruelty
	135808, -- Vindictive Gladiator's Emblem of Tenacity
	135809, -- Vindictive Gladiator's Emblem of Meditation
	135920, -- Vindictive Combatant's Emblem of Cruelty
	135921, -- Vindictive Combatant's Emblem of Tenacity
	135922, -- Vindictive Combatant's Emblem of Meditation
	136033, -- Vindictive Combatant's Emblem of Cruelty
	136034, -- Vindictive Combatant's Emblem of Tenacity
	136035, -- Vindictive Combatant's Emblem of Meditation
	136146, -- Vindictive Gladiator's Emblem of Cruelty
	136147, -- Vindictive Gladiator's Emblem of Tenacity
	136148, -- Vindictive Gladiator's Emblem of Meditation
	136259, -- Vindictive Gladiator's Emblem of Cruelty
	136260, -- Vindictive Gladiator's Emblem of Tenacity
	136261, -- Vindictive Gladiator's Emblem of Meditation
}
trinkets[182057] = { -- Surge of Dominance
	111228, -- Primal Gladiator's Insignia of Dominance
	115155, -- Primal Combatant's Insignia of Dominance
	115755, -- Primal Gladiator's Insignia of Dominance
	117735, -- Tournament Gladiator's Insignia of Dominance
	117936, -- Tournament Gladiator's Insignia of Dominance
	119932, -- Primal Combatant's Insignia of Dominance
	124862, -- Wild Gladiator's Insignia of Dominance
	125036, -- Wild Combatant's Insignia of Dominance
	125341, -- Wild Gladiator's Insignia of Dominance
	125513, -- Wild Combatant's Insignia of Dominance
	125976, -- Warmongering Gladiator's Insignia of Dominance
	126150, -- Warmongering Combatant's Insignia of Dominance
	126455, -- Warmongering Gladiator's Insignia of Dominance
	126627, -- Warmongering Combatant's Insignia of Dominance
}
trinkets[182059] = { -- Surge of Conquest
	111223, -- Primal Gladiator's Insignia of Conquest
	115150, -- Primal Combatant's Insignia of Conquest
	115750, -- Primal Gladiator's Insignia of Conquest
	117730, -- Tournament Gladiator's Insignia of Conquest
	117931, -- Tournament Gladiator's Insignia of Conquest
	119927, -- Primal Combatant's Insignia of Conquest
	124857, -- Wild Gladiator's Insignia of Conquest
	125031, -- Wild Combatant's Insignia of Conquest
	125336, -- Wild Gladiator's Insignia of Conquest
	125508, -- Wild Combatant's Insignia of Conquest
	125971, -- Warmongering Gladiator's Insignia of Conquest
	126145, -- Warmongering Combatant's Insignia of Conquest
	126450, -- Warmongering Gladiator's Insignia of Conquest
	126622, -- Warmongering Combatant's Insignia of Conquest
}
trinkets[182062] = { -- Surge of Victory
	111233, -- Primal Gladiator's Insignia of Victory
	115160, -- Primal Combatant's Insignia of Victory
	115760, -- Primal Gladiator's Insignia of Victory
	117740, -- Tournament Gladiator's Insignia of Victory
	117941, -- Tournament Gladiator's Insignia of Victory
	119937, -- Primal Combatant's Insignia of Victory
	124868, -- Wild Gladiator's Insignia of Victory
	125042, -- Wild Combatant's Insignia of Victory
	125345, -- Wild Gladiator's Insignia of Victory
	125519, -- Wild Combatant's Insignia of Victory
	125982, -- Warmongering Gladiator's Insignia of Victory
	126156, -- Warmongering Combatant's Insignia of Victory
	126459, -- Warmongering Gladiator's Insignia of Victory
	126633, -- Warmongering Combatant's Insignia of Victory
}
trinkets[182073] = { -- Rapid Adaptation
	111222, -- Primal Gladiator's Badge of Conquest
	111227, -- Primal Gladiator's Badge of Dominance
	111232, -- Primal Gladiator's Badge of Victory
	115149, -- Primal Combatant's Badge of Conquest
	115154, -- Primal Combatant's Badge of Dominance
	115159, -- Primal Combatant's Badge of Victory
	115495, -- Primal Gladiator's Badge of Adaptation
	115496, -- Primal Gladiator's Badge of Adaptation
	115521, -- Primal Combatant's Badge of Adaptation
	115749, -- Primal Gladiator's Badge of Conquest
	115754, -- Primal Gladiator's Badge of Dominance
	115759, -- Primal Gladiator's Badge of Victory
	117729, -- Tournament Gladiator's Badge of Conquest
	117734, -- Tournament Gladiator's Badge of Dominance
	117739, -- Tournament Gladiator's Badge of Victory
	117773, -- Tournament Gladiator's Badge of Adaptation
	117774, -- Tournament Gladiator's Badge of Adaptation
	117930, -- Tournament Gladiator's Badge of Conquest
	117935, -- Tournament Gladiator's Badge of Dominance
	117940, -- Tournament Gladiator's Badge of Victory
	119926, -- Primal Combatant's Badge of Conquest
	119931, -- Primal Combatant's Badge of Dominance
	119936, -- Primal Combatant's Badge of Victory
	120049, -- Primal Combatant's Badge of Adaptation
	124856, -- Wild Gladiator's Badge of Conquest
	124861, -- Wild Gladiator's Badge of Dominance
	124867, -- Wild Gladiator's Badge of Victory
	124869, -- Wild Gladiator's Badge of Adaptation
	125030, -- Wild Combatant's Badge of Conquest
	125035, -- Wild Combatant's Badge of Dominance
	125041, -- Wild Combatant's Badge of Victory
	125043, -- Wild Combatant's Badge of Adaptation
	125335, -- Wild Gladiator's Badge of Conquest
	125340, -- Wild Gladiator's Badge of Dominance
	125344, -- Wild Gladiator's Badge of Victory
	125346, -- Wild Gladiator's Badge of Adaptation
	125507, -- Wild Combatant's Badge of Conquest
	125512, -- Wild Combatant's Badge of Dominance
	125518, -- Wild Combatant's Badge of Victory
	125520, -- Wild Combatant's Badge of Adaptation
	125970, -- Warmongering Gladiator's Badge of Conquest
	125975, -- Warmongering Gladiator's Badge of Dominance
	125981, -- Warmongering Gladiator's Badge of Victory
	125983, -- Warmongering Gladiator's Badge of Adaptation
	126144, -- Warmongering Combatant's Badge of Conquest
	126149, -- Warmongering Combatant's Badge of Dominance
	126155, -- Warmongering Combatant's Badge of Victory
	126157, -- Warmongering Combatant's Badge of Adaptation
	126449, -- Warmongering Gladiator's Badge of Conquest
	126454, -- Warmongering Gladiator's Badge of Dominance
	126458, -- Warmongering Gladiator's Badge of Victory
	126460, -- Warmongering Gladiator's Badge of Adaptation
	126621, -- Warmongering Combatant's Badge of Conquest
	126626, -- Warmongering Combatant's Badge of Dominance
	126632, -- Warmongering Combatant's Badge of Victory
	126634, -- Warmongering Combatant's Badge of Adaptation
}
trinkets[183924] = 124228 -- Sign of the Dark Star (Desecrated Shadowmoon Insignia)
trinkets[183926] = 124226 -- Countenance of Tyranny (Malicious Censer)
trinkets[183929] = 124232 -- Sudden Intuition (Intuition's Gift)
trinkets[183931] = 124241 -- Anzu's Flight (Anzu's Cursed Plume)
trinkets[183941] = 124236 -- Hungering Blows (Unending Hunger)
trinkets[184073] = 124230 -- Mark of Doom (Prophecy of Fear)
trinkets[184293] = 124225 -- Spirit Shift (Soul Capacitor)
trinkets[185102] = 124518 -- Focus of Vengeance (Libram of Vindication)
trinkets[185103] = 124519 -- Naaru's Discipline (Repudiation of War)
trinkets[185104] = 124519 -- Mental Fatigue (Repudiation of War)
trinkets[185229] = 124522 -- Flamelicked (Fragment of the Dark Star)
trinkets[185230] = 124523 -- Berserker's Fury (Worldbreaker's Resolve)
trinkets[186254] = 124515 -- Bestial Wrath (Talisman of the Master Tracker)
trinkets[186323] = 126948 -- Champion's Fortitude (Defending Champion)
trinkets[187372] =  28370 -- Judgment (Bangle of Endless Blessings)
trinkets[188389] = 124521 -- Flame Shock (Core of the Primal Elements)
trinkets[188838] = 124521 -- Flame Shock (Core of the Primal Elements)
trinkets[190025] = { -- Surge of Victory
	135702, -- Vindictive Gladiator's Insignia of Victory
	135815, -- Vindictive Gladiator's Insignia of Victory
	135928, -- Vindictive Combatant's Insignia of Victory
	136041, -- Vindictive Combatant's Insignia of Victory
	136154, -- Vindictive Gladiator's Insignia of Victory
	136267, -- Vindictive Gladiator's Insignia of Victory
}
trinkets[190026] = { -- Surge of Conquest
	135693, -- Vindictive Gladiator's Insignia of Conquest
	135806, -- Vindictive Gladiator's Insignia of Conquest
	135919, -- Vindictive Combatant's Insignia of Conquest
	136032, -- Vindictive Combatant's Insignia of Conquest
	136145, -- Vindictive Gladiator's Insignia of Conquest
	136258, -- Vindictive Gladiator's Insignia of Conquest
}
trinkets[190027] = { -- Surge of Dominance
	135699, -- Vindictive Gladiator's Insignia of Dominance
	135812, -- Vindictive Gladiator's Insignia of Dominance
	135925, -- Vindictive Combatant's Insignia of Dominance
	136038, -- Vindictive Combatant's Insignia of Dominance
	136151, -- Vindictive Gladiator's Insignia of Dominance
	136264, -- Vindictive Gladiator's Insignia of Dominance
}
trinkets[190456] = 124523 -- Ignore Pain (Worldbreaker's Resolve)
trinkets[193346] = 129163 -- Caber Toss (Lost Etin's Strength)
trinkets[194543] = 129849 -- Gnome Ingenuity (Gnomeregan Auto-Blocker 601)
trinkets[194608] = 129896 -- Reflection of Torment (Mirror of Truth)
trinkets[194618] = 129898 -- Rage (Mark of Supremacy)
trinkets[194625] = 129895 -- Valor Medal of the First War
trinkets[194627] = 129893 -- Now is the time! (Sundial of the Exiled)
trinkets[194632] = 129848 -- Lust for Battle (Bloodlust Brooch)
trinkets[194637] = 129851 -- Essence of the Martyr
trinkets[194638] = 129937 -- Lust for Battle (Emblem of Fury)
trinkets[194645] = 129850 -- Blessing of the Silver Crescent (Icon of the Silver Crescent)
trinkets[195007] = 129897 -- Essence of Life (The Egg of Mortal Essence)
trinkets[196207] = 124522 -- Corruption (Fragment of the Dark Star)
trinkets[196760] = 131735 -- Imp Portal (Imp Generator)
trinkets[197277] =  28370 -- Judgment (Bangle of Endless Blessings)
trinkets[199129] = 124523 -- Shield Block (Worldbreaker's Resolve)
trinkets[201405] = 133595 -- Demonbane (Gronntooth War Horn)
trinkets[201408] = 133597 -- Cleansing Flame (Infallible Tracking Charm)
trinkets[201410] = 133596 -- Voidsight (Orb of Voidsight)
trinkets[201414] = 133598 -- Bulwark of Purity (Purified Shard of the Third Moon)
trinkets[201854] = 121729 -- Bug Spray (Ormgul's Bug Sprayer)
trinkets[202744] = { -- Cursed Fortitude
	121570, -- Might of the Forsaken
	129260, -- Tenacity of Cursed Blood
}
trinkets[202761] = { -- Banshee's Blight
	121572, -- Sylvanas' Barbed Arrow
	129258, -- Sylvanas' Broken Arrow
}
trinkets[202836] = 121491 -- Velvety Cadavernet (Shalrala's Engraved Goblet)
trinkets[202847] = 132963 -- Nether Drake Impulse (Young Drake's Impulse)
trinkets[202866] = 132971 -- Desperation (Nightfallen's Desperation)
trinkets[202879] = 132970 -- Ley Surge (Runas' Nearly Depleted Ley Crystal)
trinkets[202886] = 129317 -- Lightning Charged (Lodestone of the Mystic)
trinkets[202889] = 129319 -- Stormbreaker's Bulwark (Lodestone of the Stormbreaker)
trinkets[202899] = 132091 -- Uriah's Blessing (Warmth of Uriah)
trinkets[202905] = 121726 -- Navarrogg's Guidance
trinkets[202908] = 121727 -- Rivermane Purification (Cleansed Poison Idol)
trinkets[202912] = 121649 -- Wrath of Elune (Vibrant Temple Masonry)
trinkets[202917] = 121647 -- Wrath of Elune (Temple Priestess' Charm)
trinkets[206444] = 124521 -- Flame Shock (Core of the Primal Elements)
trinkets[207033] = 124515 -- Bestial Wrath (Talisman of the Master Tracker)
trinkets[212799] =  30720 -- Displacement Beacon (Serpent-Coil Braid)
trinkets[213888] = 136975 -- Scent of Blood (Hunger of the Pack)
trinkets[214128] = 137419 -- Acceleration (Chrono Shard)
trinkets[214142] = 133766 -- Nether Anti-Toxin
trinkets[214169] = 136715 -- Brutal Haymaker (Spiked Counterweight)
trinkets[214203] = 133647 -- Spear of Light (Gift of Radiance)
trinkets[214222] =  28370 -- Judgment (Bangle of Endless Blessings)
trinkets[214229] = 137315 -- Feed on the Weak (Writhing Heart of Darkness)
trinkets[214350] = 137306 -- Nightmare Essence (Oakheart's Gnarled Root)
trinkets[214366] = 137338 -- Crystalline Body (Shard of Rokmora)
trinkets[214423] = 137344 -- Stance of the Mountain (Talisman of the Cragshaper)
trinkets[214459] = 136978 -- Choking Flames (Ember of Nullification)
trinkets[214572] = 137400 -- Nightwell Energy (Coagulated Nightwell Residue)
trinkets[214577] = 137400 -- Nightwell Energy (Coagulated Nightwell Residue)
trinkets[214584] = 137440 -- Ice Bomb (Shivermaw's Jawbone)
trinkets[214831] = 137459 -- Chaotic Energy (Chaos Talisman)
trinkets[214962] = 137539 -- Sheathed in Frost (Faulty Countermeasure)
trinkets[214971] = 137369 -- Gaseous Bubble (Giant Ornamental Pearl)
trinkets[214980] = 137486 -- Slicing Maelstrom (Windscar Whetstone)
trinkets[215126] = 137439 -- Congealing Goo (Tiny Oozeling in a Jar)
trinkets[215127] = 137439 -- Fetid Regurgitation (Tiny Oozeling in a Jar)
trinkets[215206] = 137462 -- Vampyr's Kiss (Jewel of Insatiable Desire)
trinkets[215248] = 133645 -- Shroud of the Naglfar (Naglfar Fare)
trinkets[215294] = 137378 -- Gathering Clouds (Bottled Hurricane)
trinkets[215479] = 124517 -- Ironskin Brew (Sacred Draenic Incense)
trinkets[215648] = 137541 -- Elune's Light (Moonlit Prism)
trinkets[215658] = 137537 -- Darkstrikes (Tirathon's Betrayal)
trinkets[215670] = 137329 -- Taint of the Sea (Figurehead of the Naglfar)
trinkets[215859] = 137398 -- Volatile Magic (Portable Manacracker)
trinkets[215936] = 137538 -- Soul Sap (Orb of Torment)
trinkets[215956] = 133642 -- Valarjar's Path (Horn of Valor)
trinkets[218845] = { -- Starlance Vigil
	138823, -- Starlance's Protective Ward
	138837, -- Ghostly Defenses
}
trinkets[221695] = 139327 -- Wild God's Fury (Unbridled Fury)
trinkets[221752] = 139330 -- Heightened Senses
trinkets[221770] = 139328 -- Rend Flesh (Ursoc's Rending Paw)
trinkets[221796] = 139329 -- Blood Frenzy (Bloodthirsty Instinct)
trinkets[221812] = 139321 -- Plague Swarm (Swarming Plaguehive)
trinkets[221837] = 139322 -- Solitude (Cocoon of Enforced Solitude)
trinkets[221878] = 138222 -- Spirit Fragment (Vial of Nightmare Fog)
trinkets[222046] = 139326 -- Maddening Whispers (Wriggling Sinew)
trinkets[222166] = 139325 -- Horrific Appendages (Spontaneous Appendages)
trinkets[222479] = 138225 -- Shadowy Reflection (Phantasmal Echo)
trinkets[222634] = 140161 -- Bladestorm (Hargal's Favorite Trinket)
trinkets[222706] = 139336 -- Poisoned Dreams (Bough of Corruption)
trinkets[224060] = 140034 -- Devilsaur's Stampede (Impact Tremor)
trinkets[224074] = 140026 -- Devilsaur's Bite (The Devilsaur's Bite)
trinkets[224078] = 140030 -- Devilsaur Shock Leash (Devilsaur Shock-Baton)
trinkets[224154] = 121808 -- Nether Energy (Nether Conductors)
trinkets[224165] = 121806 -- Ettin's Brawn (Mountain Rage Shaker)
trinkets[225033] = 140789 -- Living Carapace (Animated Exoskeleton)
trinkets[225130] = 140797 -- Vampiric Aura (Fang of Tichcondrius)
trinkets[225140] = 140807 -- Infernal Contract
trinkets[225141] = 140808 -- Fel-Crazed Rage (Draught of Souls)
trinkets[225724] = 140795 -- Nightwell Tranquility (Aluriel's Mirror)
trinkets[225736] = 140802 -- Recursive Strikes (Nightblooming Frond)
trinkets[225774] = 140809 -- Nefarious Pact (Whispers in the Dark)
trinkets[226991] = 128958 -- Demonic Ferocity (Lekos' Leash)
trinkets[227099] = 132895 -- Inspiration (The Watcher's Divine Inspiration)
trinkets[227408] = 141618 -- New Growth (Life-Giving Berries)
trinkets[227869] = 141585 -- Six-Feather Fan
trinkets[228142] = 141586 -- Incensed (Marfisi's Giant Censer)
-- Consumables
consumables[   673] =   5997 -- Minor Defense (Elixir of Minor Defense)
consumables[   700] =   3434 -- Sleep (Slumber Sand)
consumables[   746] =   1251 -- First Aid (Linen Bandage)
consumables[   833] =   1401 -- Green Tea (Riverpaw Tea Leaf)
consumables[  1090] =   2091 -- Sleep (Magic Dust)
consumables[  1159] =   2581 -- First Aid (Heavy Linen Bandage)
consumables[  2367] =   2454 -- Lion's Strength (Elixir of Lion's Strength)
consumables[  2374] =   2457 -- Minor Agility (Elixir of Minor Agility)
consumables[  2378] =   2458 -- Minor Fortitude (Elixir of Minor Fortitude)
consumables[  2379] = { -- Speed
	  2459, -- Swiftness Potion
	 54213, -- Molotov Cocktail
}
consumables[  3160] =   3390 -- Lesser Agility (Elixir of Lesser Agility)
consumables[  3164] =   3391 -- Ogre's Strength (Elixir of Ogre's Strength)
consumables[  3166] =   3383 -- Wisdom (Elixir of Wisdom)
consumables[  3169] =   3387 -- Invulnerability (Limited Invulnerability Potion)
consumables[  3219] =   3382 -- Weak Troll's Blood (Weak Troll's Blood Elixir)
consumables[  3220] =   3389 -- Defense (Elixir of Defense)
consumables[  3222] =   3388 -- Strong Troll's Blood Elixir
consumables[  3223] =   3826 -- Major Troll's Blood Elixir
consumables[  3267] =   3530 -- First Aid (Wool Bandage)
consumables[  3268] =   3531 -- First Aid (Heavy Wool Bandage)
consumables[  3593] =   3825 -- Elixir of Fortitude
consumables[  3680] =   3823 -- Lesser Invisibility (Lesser Invisibility Potion)
consumables[  4318] =   4546 -- Guile of the Raptor (Call of the Raptor)
consumables[  4941] =   4623 -- Stoneshield (Lesser Stoneshield Potion)
consumables[  5020] =   4952 -- Stormstout
consumables[  5021] =   4953 -- Trogg Ale
consumables[  5665] =   5206 -- Fury of the Bogling (Bogling Root)
consumables[  5917] =   1191 -- Fumble (Bag of Marbles)
consumables[  6114] =   5342 -- Raptor Punch
consumables[  6196] =  83795 -- Far Sight (Scrying Roguestone)
consumables[  6262] =   5512 -- Healthstone
consumables[  6405] =  66888 -- Furbolg Form (Stave of Fur and Claw)
consumables[  6512] = { -- Detect Lesser Invisibility
	  3828, -- Elixir of Detect Lesser Invisibility
	116269, -- Elixir of Detect Lesser Invisibility
}
consumables[  6615] = { -- Free Action
	  5634, -- Free Action Potion
	116267, -- Free Action Potion
}
consumables[  6724] =   5816 -- Light of Elune
consumables[  7178] =   5996 -- Water Breathing (Elixir of Water Breathing)
consumables[  7233] =   6049 -- Fire Protection (Fire Protection Potion)
consumables[  7239] =   6050 -- Frost Protection (Frost Protection Potion)
consumables[  7242] =   6048 -- Shadow Protection (Shadow Protection Potion)
consumables[  7245] =   6051 -- Holy Protection (Holy Protection Potion)
consumables[  7254] =   6052 -- Nature Protection (Nature Protection Potion)
consumables[  7396] =   1322 -- Fishliver Oil
consumables[  7840] =   6372 -- Swim Speed (Swim Speed Potion)
consumables[  7844] =   6373 -- Fire Power (Elixir of Firepower)
consumables[  7926] =   6450 -- First Aid (Silk Bandage)
consumables[  7927] =   6451 -- First Aid (Heavy Silk Bandage)
consumables[  8063] =   6522 -- Deviate Fish
consumables[  8070] =   1970 -- Rejuvenation (Restoring Balm)
consumables[  8091] =   3013 -- Armor (Scroll of Protection)
consumables[  8094] =   1478 -- Armor (Scroll of Protection II)
consumables[  8095] =   4421 -- Armor (Scroll of Protection III)
consumables[  8096] =    955 -- Intellect (Scroll of Intellect)
consumables[  8097] =   2290 -- Intellect (Scroll of Intellect II)
consumables[  8098] =   4419 -- Intellect (Scroll of Intellect III)
consumables[  8099] =   1180 -- Stamina (Scroll of Stamina)
consumables[  8100] =   1711 -- Stamina (Scroll of Stamina II)
consumables[  8101] =   4422 -- Stamina (Scroll of Stamina III)
consumables[  8112] =   1181 -- Versatility (Scroll of Versatility)
consumables[  8113] =   1712 -- Versatility (Scroll of Versatility II)
consumables[  8114] =   4424 -- Versatility (Scroll of Versatility III)
consumables[  8115] =   3012 -- Agility (Scroll of Agility)
consumables[  8116] =   1477 -- Agility (Scroll of Agility II)
consumables[  8117] =   4425 -- Agility (Scroll of Agility III)
consumables[  8118] =    954 -- Strength (Scroll of Strength)
consumables[  8119] =   2289 -- Strength (Scroll of Strength II)
consumables[  8120] =   4426 -- Strength (Scroll of Strength III)
consumables[  8202] =   6635 -- Sapta Sight (Earth Sapta)
consumables[  8212] =   6662 -- Giant Growth (Elixir of Giant Growth)
consumables[  8213] =   6657 -- Cooked Deviate Fish (Savory Deviate Delight)
consumables[  8277] =   5457 -- Voodoo Hex (Severed Voodoo Claw)
consumables[  8312] = { -- Trap
	   835, -- Large Rope Net
	  4941, -- Really Sticky Glue
}
consumables[  8898] =   6636 -- Sapta Sight (Fire Sapta)
consumables[  8899] =   6637 -- Sapta Sight (Water Sapta)
consumables[ 10667] =   8410 -- Rage of Ages (R.O.I.D.S.)
consumables[ 10668] =   8411 -- Spirit of Boar (Lung Juice Cocktail)
consumables[ 10669] =   8412 -- Strike of the Scorpok (Ground Scorpok Assay)
consumables[ 10692] =   8423 -- Infallible Mind (Cerebral Cortex Compound)
consumables[ 10693] =   8424 -- Spiritual Domination (Gizzard Gum)
consumables[ 10723] = { -- Touch of Zanzil Cure
	  8095, -- Hinott's Oil
	  8432, -- Eau de Mixilpixil
}
consumables[ 10838] =   8544 -- First Aid (Mageweave Bandage)
consumables[ 10839] =   8545 -- First Aid (Heavy Mageweave Bandage)
consumables[ 11007] = { -- Weak Alcohol
	  2686, -- Thunder Ale
	  2723, -- Bottle of Dalaran Noir
	  2894, -- Rhapsody Malt
	 17196, -- Holiday Spirits
	 19222, -- Cheap Beer
	 23492, -- Suntouched Special Reserve
	 40035, -- Northrend Honey Mead
	 44570, -- Glass of Eversong Wine
	 44616, -- Glass of Dalaran White
	 61982, -- Fizzy Fruit Wine
	 81407, -- Four Wind Soju
	 82343, -- Lordaeron Lambic
	 83095, -- Lagrave Stout
	 98157, -- Big Blossom Brew
	117437, -- Skyreach Sunrise
	117441, -- Elekk's Neck
	117453, -- "Da Bruisery" OPA
	128833, -- Kaldorei Ginger Wine
	138295, -- Farondis Royal Red
	140187, -- First Year Blue
	140188, -- Second Year Blue
	140189, -- Third Year Blue
}
consumables[ 11008] = { -- Standard Alcohol
	  2593, -- Flask of Stormwind Tawny
	  2596, -- Skin of Dwarven Stout
	  3703, -- Southshore Stout
	 11846, -- Wizbang's Special Brew
	 17403, -- Steamwheedle Fizzy Spirits
	 18287, -- Evermurky
	 40036, -- Snowplum Brandy
	 44571, -- Bottle of Silvermoon Port
	 44575, -- Flask of Bitter Cactus Cider
	 44617, -- Glass of Dalaran Red
	 44618, -- Glass of Aged Dalaran Red
	 44619, -- Glass of Peaked Dalaran Red
	 57543, -- Stormhammer Stout
	 61983, -- Imported E.K. Ale
	 61984, -- Potent Pineapple Punch
	 62908, -- Hair of the Dog
	 63275, -- Gilnean Fortified Brandy
	 63291, -- Blood Red Ale
	 63292, -- Disgusting Rotgut
	 63293, -- Blackheart Grog
	 63296, -- Embalming Fluid
	 63299, -- Sunkissed Wine
	128841, -- Highmountain Tiswin
	128842, -- Tideskorn Mead Ale
	136563, -- Pocket Warmed Arkhi
	136565, -- Fermented Melon Juice
	140271, -- Valarjar Java
}
consumables[ 11009] = { -- Strong Alcohol
	  2594, -- Flagon of Dwarven Mead
	  2595, -- Jug of Badlands Bourbon
	  4595, -- Junglevine Wine
	  4600, -- Cherry Grog
	  9260, -- Volatile Rum
	  9360, -- Cuergo's Gold
	 17402, -- Greatfather's Winter Ale
	 18288, -- Molasses Firewater
	 23586, -- Aerie Peak Pale Ale
	 28284, -- Don Carlos Tequila
	 29112, -- Cenarion Spirits
	 30309, -- Stonebreaker Brew
	 30499, -- Brightsong Wine
	 30858, -- Peon Sleep Potion
	 32667, -- Bash Ale
	 33929, -- Brewfest Brew
	 38350, -- Winterfin "Depth Charge"
	 38432, -- Plugger's Blackrock Ale
	 40042, -- Caraway Burnwine
	 43695, -- Half Full Bottle of Prison Moonshine
	 43696, -- Half Empty Bottle of Prison Moonshine
	 44573, -- Cup of Frog Venom Brew
	 44574, -- Skin of Mulgore Firewater
	 52974, -- Mack's Deep Sea Grog
	 61985, -- Banana Cocktail
	 61986, -- Tol Barad Coconut Rum
	 62674, -- Highland Spirits
	 62790, -- Darkbrew Lager
	 64639, -- Silversnap Ice
	 81415, -- Pandaren Plum Wine
	 82344, -- Hearthglen Ambrosia
	 83094, -- Foote Tripel
	 88531, -- Lao Chin's Last Mug
	 89683, -- Hozen Cuervo
	 93208, -- Darkmoon P.I.E.
	107499, -- Mulled Alterac Brandy
	114017, -- Steamwheedle Wagon Bomb
	117439, -- "Da Bruisery" Hot & Wroth
	117440, -- Peglegger's Porter
	117442, -- Thunderbelly Mead
	117568, -- Jug of Ironwine
	119022, -- Shadowmoon Sugar Pear Cider
	128834, -- Bradensbrook Gorse Wine
	133988, -- "Sessionable" Drog
	136562, -- Deep Sea Spirit
	136564, -- Runewood Akvavit
	136566, -- Mariner's Grog
	136568, -- Black Rook Stout
	138294, -- Sea Breeze
	141210, -- Warm Nightpear Cider
	141211, -- Arcfruit Sangree
}
consumables[ 11319] =   8827 -- Water Walking (Elixir of Water Walking)
consumables[ 11328] =   8949 -- Agility (Elixir of Agility)
consumables[ 11334] =   9187 -- Greater Agility (Elixir of Greater Agility)
consumables[ 11348] =  13445 -- Greater Armor (Elixir of Superior Defense)
consumables[ 11349] =   8951 -- Armor (Elixir of Greater Defense)
consumables[ 11350] = { -- Fire Shield
	  8956, -- Oil of Immolation
	118699, -- Oil of Immolation
}
consumables[ 11359] =   9030 -- Restoration (Restorative Potion)
consumables[ 11371] =   9088 -- Gift of Arthas
consumables[ 11389] = { -- Detect Undead
	  9154, -- Elixir of Detect Undead
	116272, -- Elixir of Detect Undead
}
consumables[ 11390] =   9155 -- Arcane Elixir
consumables[ 11392] =   9172 -- Invisibility (Invisibility Potion)
consumables[ 11396] =   9179 -- Greater Intellect (Elixir of Greater Intellect)
consumables[ 11403] = { -- Dream Vision
	  9197, -- Elixir of Dream Vision
	116273, -- Elixir of Dream Vision
}
consumables[ 11405] =   9206 -- Elixir of the Giants (Elixir of Giants)
consumables[ 11406] =   9224 -- Elixir of Demonslaying
consumables[ 11407] = { -- Detect Demon
	  9233, -- Elixir of Detect Demon
	116274, -- Elixir of Detect Demon
}
consumables[ 11474] =   9264 -- Shadow Power (Elixir of Shadow Power)
consumables[ 11629] = { -- Potent Alcohol
	  9361, -- Cuergo's Gold with Worm
	 12003, -- Dark Dwarven Lager
	 19221, -- Darkmoon Special Reserve
	 23584, -- Loch Modan Lager
	 23848, -- Nethergarde Bitter
	 44716, -- Mysterious Fermented Liquid
	 61384, -- Doublerum
	113108, -- Ogre Moonshine
	114850, -- Bubblefizz Bubbly
	116917, -- Sailor Zazzuk's 180-Proof Rum
	133989, -- Homebrew Drog
	136561, -- Inferno Punch
	141209, -- Distilled Nightwine
}
consumables[ 12174] =  10309 -- Agility (Scroll of Agility IV)
consumables[ 12175] =  10305 -- Armor (Scroll of Protection IV)
consumables[ 12176] =  10308 -- Intellect (Scroll of Intellect IV)
consumables[ 12177] =  10306 -- Versatility (Scroll of Versatility IV)
consumables[ 12178] =  10307 -- Stamina (Scroll of Stamina IV)
consumables[ 12179] =  10310 -- Strength (Scroll of Strength IV)
consumables[ 12608] = { -- Catseye Elixir
	 10592, -- Catseye Elixir
	116270, -- Catseye Elixir
}
consumables[ 13424] =   1434 -- Faerie Fire (Glowing Wax Stick)
consumables[ 13808] =  10830 -- M73 Frag Grenade
consumables[ 15822] =  12190 -- Dreamless Sleep (Dreamless Sleep Potion)
consumables[ 15852] =  12217 -- Dragonbreath Chili
consumables[ 16629] =  12650 -- Attuned Dampener
consumables[ 16739] =   1973 -- Orb of Deception
consumables[ 17038] =  12820 -- Winterfall Firewater
consumables[ 17528] = { -- Mighty Rage
	 13442, -- Mighty Rage Potion
	116275, -- Mighty Rage Potion
}
consumables[ 17535] =  13447 -- Elixir of the Sages
consumables[ 17537] =  13453 -- Elixir of Brute Force
consumables[ 17538] =  13452 -- Elixir of the Mongoose
consumables[ 17539] =  13454 -- Greater Arcane Elixir
consumables[ 17540] =  13455 -- Greater Stoneshield (Greater Stoneshield Potion)
consumables[ 17543] =  13457 -- Fire Protection (Greater Fire Protection Potion)
consumables[ 17544] =  13456 -- Frost Protection (Greater Frost Protection Potion)
consumables[ 17545] =  13460 -- Holy Protection (Greater Holy Protection Potion)
consumables[ 17546] =  13458 -- Nature Protection (Greater Nature Protection Potion)
consumables[ 17548] =  13459 -- Shadow Protection (Greater Shadow Protection Potion)
consumables[ 17549] =  13461 -- Arcane Protection (Greater Arcane Protection Potion)
consumables[ 17624] = { -- Petrification
	 13506, -- Potion of Petrification
	116277, -- Potion of Petrification
}
consumables[ 17626] =  13510 -- Flask of the Titans
consumables[ 17627] =  13511 -- Distilled Wisdom (Flask of Distilled Wisdom)
consumables[ 17628] =  13512 -- Supreme Power (Flask of Supreme Power)
consumables[ 17639] =  13514 -- Wail of the Banshee
consumables[ 18071] =  13724 -- Enriched Manna Biscuit
consumables[ 18124] =  13810 -- Blessed Sunfruit
consumables[ 18140] =  13813 -- Blessed Sunfruit Juice
consumables[ 18608] =  14529 -- First Aid (Runecloth Bandage)
consumables[ 18610] =  14530 -- First Aid (Heavy Runecloth Bandage)
consumables[ 20707] =   5232 -- Soulstone
consumables[ 20875] =  17048 -- Rumsey Rum
consumables[ 21149] =  17198 -- Egg Nog (Winter Veil Egg Nog)
consumables[ 21920] =  17708 -- Frost Power (Elixir of Frost Power)
consumables[ 21955] =  17747 -- Razorlash Root
consumables[ 22789] =  18269 -- Gordok Green Grog
consumables[ 22790] =  18284 -- Kreeg's Stout Beatdown
consumables[ 22807] = { -- Greater Water Breathing
	 18294, -- Elixir of Greater Water Breathing
	 25539, -- Potion of Water Breathing
}
consumables[ 23540] =  19060 -- Warsong Gulch Enriched Ration
consumables[ 23692] =  19301 -- Alterac Manna Biscuit
consumables[ 23698] =  19318 -- Alterac Spring Water (Bottled Alterac Spring Water)
consumables[ 24360] =  20002 -- Greater Dreamless Sleep (Greater Dreamless Sleep Potion)
consumables[ 24361] =  20004 -- Mighty Troll's Blood Elixir
consumables[ 24363] =  20007 -- Mageblood Elixir
consumables[ 24364] =  20008 -- Living Free Action (Living Action Potion)
consumables[ 24382] =  20079 -- Spirit of Zanza
consumables[ 24383] =  20081 -- Swiftness of Zanza
consumables[ 24410] = { -- Arathi Basin Iron Ration
	 20064, -- Arathi Basin Iron Ration
	 20224, -- Defiler's Iron Ration
	 20227, -- Highlander's Iron Ration
}
consumables[ 24411] = { -- Arathi Basin Enriched Ration
	 20062, -- Arathi Basin Enriched Ration
	 20222, -- Defiler's Enriched Ration
	 20225, -- Highlander's Enriched Ration
}
consumables[ 24417] =  20080 -- Sheen of Zanza
consumables[ 25037] =  20709 -- Rumsey Rum Light
consumables[ 25690] =  21072 -- Brain Food (Smoked Sagefish)
consumables[ 25691] =  21217 -- Brain Food (Sagefish Delight)
consumables[ 25722] =  21114 -- Rumsey Rum Dark
consumables[ 25851] =  21171 -- Lightheaded (Filled Festive Mug)
consumables[ 25990] =  21215 -- Graccu's Mince Meat Fruitcake
consumables[ 26030] =  11950 -- Windblossom Berries
consumables[ 26263] =  21537 -- Dim Sum (Festival Dumplings)
consumables[ 26276] =  21546 -- Greater Firepower (Elixir of Greater Firepower)
consumables[ 26389] =  21721 -- Moonglow Alcohol (Moonglow)
consumables[ 26899] =  22259 -- Give Friendship Bracelet (Unbestowed Friendship Bracelet)
consumables[ 27030] =  21990 -- First Aid (Netherweave Bandage)
consumables[ 27031] =  21991 -- First Aid (Heavy Netherweave Bandage)
consumables[ 27571] =  22218 -- Cascade of Roses (Handful of Rose Petals)
consumables[ 27652] =  22193 -- Elixir of Resistance (Bloodkelp Elixir of Resistance)
consumables[ 27653] =  22192 -- Elixir of Dodging (Bloodkelp Elixir of Dodging)
consumables[ 28486] =  22779 -- Scourgebane Draught
consumables[ 28488] =  22778 -- Scourgebane Infusion
consumables[ 28489] =  22823 -- Camouflage (Elixir of Camouflage)
consumables[ 28490] =  22824 -- Major Strength (Elixir of Major Strength)
consumables[ 28491] =  22825 -- Healing Power (Elixir of Healing Power)
consumables[ 28492] =  22826 -- Sneaking (Sneaking Potion)
consumables[ 28493] =  22827 -- Major Frost Power (Elixir of Major Frost Power)
consumables[ 28494] =  22828 -- Insane Strength Potion
consumables[ 28496] =  22830 -- Greater Stealth Detection (Elixir of the Searching Eye)
consumables[ 28497] =  39666 -- Mighty Agility (Elixir of Mighty Agility)
consumables[ 28501] =  22833 -- Major Firepower (Elixir of Major Firepower)
consumables[ 28502] =  22834 -- Major Armor (Elixir of Major Defense)
consumables[ 28503] =  22835 -- Major Shadow Power (Elixir of Major Shadow Power)
consumables[ 28504] =  22836 -- Major Dreamless Sleep (Major Dreamless Sleep Potion)
consumables[ 28506] =  22837 -- Potion of Heroes (Heroic Potion)
consumables[ 28507] =  22838 -- Haste (Haste Potion)
consumables[ 28508] =  22839 -- Destruction (Destruction Potion)
consumables[ 28509] =  22840 -- Greater Versatility (Elixir of Major Mageblood)
consumables[ 28511] = { -- Fire Protection
	 22841, -- Major Fire Protection Potion
	 32846, -- Major Fire Protection Potion
}
consumables[ 28512] = { -- Frost Protection
	 22842, -- Major Frost Protection Potion
	 32847, -- Major Frost Protection Potion
}
consumables[ 28513] = { -- Nature Protection
	 22844, -- Major Nature Protection Potion
	 32844, -- Major Nature Protection Potion
}
consumables[ 28515] =  22849 -- Ironshield (Ironshield Potion)
consumables[ 28518] =  22851 -- Flask of Fortification
consumables[ 28519] =  22853 -- Flask of Mighty Versatility
consumables[ 28520] =  22854 -- Flask of Relentless Assault
consumables[ 28521] =  22861 -- Flask of Blinding Light
consumables[ 28527] =  22795 -- Fel Blossom
consumables[ 28536] = { -- Arcane Protection
	 22845, -- Major Arcane Protection Potion
	 32840, -- Major Arcane Protection Potion
}
consumables[ 28537] = { -- Shadow Protection
	 22846, -- Major Shadow Protection Potion
	 32845, -- Major Shadow Protection Potion
}
consumables[ 28538] =  22847 -- Holy Protection (Major Holy Protection Potion)
consumables[ 28540] =  22866 -- Flask of Pure Death
consumables[ 29271] =  23334 -- Power Surge (Cracked Power Core)
consumables[ 29308] =  23381 -- Power Surge (Chipped Power Core)
consumables[ 29332] =  23327 -- Fire-toasted Bun (Fire-Toasted Bun)
consumables[ 29333] =  23326 -- Midsummer Sausage
consumables[ 29334] =  23211 -- Toasted Smorc
consumables[ 29335] =  23435 -- Elderberry Pie
consumables[ 29348] =  23444 -- Goldenmist Special Brew
consumables[ 30088] =  23194 -- Lesser Mark of the Dawn
consumables[ 30089] =  23195 -- Mark of the Dawn
consumables[ 30090] =  23196 -- Greater Mark of the Dawn
consumables[ 30167] =  49704 -- Red Ogre Costume (Carved Ogre Idol)
consumables[ 30550] =  23862 -- Redemption of the Fallen
consumables[ 30557] =  23865 -- Wrath of the Titans
consumables[ 30562] =  23857 -- Legacy of the Mountain King
consumables[ 30567] =  23864 -- Torment of the Worgen
consumables[ 30845] =  23985 -- Tracker's Vitality (Crystal of Vitality)
consumables[ 30847] =  23986 -- Tracker's Insight (Crystal of Insight)
consumables[ 30848] =  23989 -- Tracker's Ferocity (Crystal of Ferocity)
consumables[ 31367] =  24268 -- Netherweave Net
consumables[ 31920] =  24421 -- Nagrand Cherry
consumables[ 32028] =  24494 -- Elune's Embrace (Tears of the Goddess)
consumables[ 32096] =  24522 -- Thrallmar's Favor (Thrallmar Favor)
consumables[ 32098] =  24520 -- Honor Hold's Favor (Honor Hold Favor)
consumables[ 32304] =  25548 -- Tallstalk Mushroom
consumables[ 32305] =  25550 -- Toadstool Toxin (Redcap Toadstool)
consumables[ 33019] =  27317 -- Sapta Sight (Elemental Sapta)
consumables[ 33077] =  27498 -- Agility (Scroll of Agility V)
consumables[ 33078] =  27499 -- Intellect (Scroll of Intellect V)
consumables[ 33079] =  27500 -- Armor (Scroll of Protection V)
consumables[ 33080] =  27501 -- Versatility (Scroll of Versatility V)
consumables[ 33081] =  27502 -- Stamina (Scroll of Stamina V)
consumables[ 33082] =  27503 -- Strength (Scroll of Strength V)
consumables[ 33720] =  28102 -- Onslaught Elixir
consumables[ 33721] =  40070 -- Spellpower Elixir
consumables[ 33726] =  28104 -- Elixir of Mastery
consumables[ 33772] =  28112 -- Underspore Pod
consumables[ 34603] =  28607 -- Sunfury Disguise
consumables[ 35409] =  29482 -- Brain Damage (Ethereum Essence)
consumables[ 35474] =  29532 -- Drums of Panic
consumables[ 35475] =  29528 -- Drums of War
consumables[ 35476] =  29529 -- Drums of Battle
consumables[ 35477] =  29530 -- Drums of Speed
consumables[ 35478] =  29531 -- Drums of Restoration
consumables[ 38157] =  31122 -- Overseer Disguise
consumables[ 38318] =  31337 -- Transformation - Blackwhelp (Orb of the Blackwhelp)
consumables[ 38551] =  31449 -- Stealth Detection (Distilled Stalker Sight)
consumables[ 38552] =  31450 -- Improved Stealth (Stealth of the Stalker)
consumables[ 38553] =  31451 -- Energized (Pure Energy)
consumables[ 38908] =  31676 -- Fel Regeneration Potion
consumables[ 38929] =  31677 -- Fel Mana (Fel Mana Potion)
consumables[ 38954] =  31679 -- Fel Strength Elixir
consumables[ 39625] =  32062 -- Elixir of Major Fortitude
consumables[ 39626] =  32063 -- Earthen Elixir
consumables[ 39627] =  32067 -- Elixir of Draenic Wisdom
consumables[ 39628] =  32068 -- Elixir of Ironskin
consumables[ 40567] =  32599 -- Unstable Flask of the Bandit
consumables[ 40568] =  32596 -- Unstable Flask of the Elder
consumables[ 40572] =  32598 -- Unstable Flask of the Beast
consumables[ 40573] =  32600 -- Unstable Flask of the Physician
consumables[ 40575] =  32597 -- Unstable Flask of the Soldier
consumables[ 40576] =  32601 -- Unstable Flask of the Sorcerer
consumables[ 41031] =  32722 -- Enriched Terocone Juice
consumables[ 41301] =  32782 -- Time-Lost Figurine
consumables[ 41608] =  32901 -- Relentless Assault of Shattrath (Shattrath Flask of Relentless Assault)
consumables[ 41609] =  32898 -- Fortification of Shattrath (Shattrath Flask of Fortification)
consumables[ 41610] =  32899 -- Mighty Restoration of Shattrath (Shattrath Flask of Mighty Restoration)
consumables[ 41611] =  32900 -- Supreme Power of Shattrath (Shattrath Flask of Supreme Power)
consumables[ 42254] = { -- Weak Alcohol
	 37490, -- Aromatic Honey Brew
	 37900, -- Aromatic Honey Brew
}
consumables[ 42255] = { -- Weak Alcohol
	 37489, -- Izzard's Ever Flavor
	 37899, -- Izzard's Ever Flavor
}
consumables[ 42256] = { -- Weak Alcohol
	 37488, -- Wild Winter Pilsner
	 37898, -- Wild Winter Pilsner
}
consumables[ 42257] = { -- Weak Alcohol
	 37493, -- Blackrock Lager
	 37903, -- Blackrock Lager
}
consumables[ 42258] = { -- Weak Alcohol
	 37498, -- Bartlett's Bitter Brew
	 37908, -- Bartlett's Bitter Brew
}
consumables[ 42259] = { -- Weak Alcohol
	 37496, -- Binary Brew
	 37906, -- Binary Brew
}
consumables[ 42260] = { -- Weak Alcohol
	 37497, -- Autumnal Acorn Ale
	 37907, -- Autumnal Acorn Ale
}
consumables[ 42261] = { -- Weak Alcohol
	 37499, -- Lord of Frost's Private Label
	 37909, -- Lord of Frost's Private Label
}
consumables[ 42263] = { -- Weak Alcohol
	 37492, -- Springtime Stout
	 37902, -- Springtime Stout
}
consumables[ 42264] = { -- Weak Alcohol
	 37495, -- Draenic Pale Ale
	 37905, -- Draenic Pale Ale
}
consumables[ 42365] =  33079 -- Murloc Costume
consumables[ 42760] =  33218 -- Goblin Gumbo
consumables[ 43194] =  33457 -- Agility (Scroll of Agility VI)
consumables[ 43195] =  33458 -- Intellect (Scroll of Intellect VI)
consumables[ 43196] =  33459 -- Armor (Scroll of Protection VI)
consumables[ 43197] =  33460 -- Versatility (Scroll of Versatility VI)
consumables[ 43198] =  33461 -- Stamina (Scroll of Stamina VI)
consumables[ 43199] =  33462 -- Strength (Scroll of Strength VI)
consumables[ 43381] =  33621 -- Plague Spray
consumables[ 43730] =  33866 -- Electrified (Stormchops)
consumables[ 43771] =  43005 -- Pet Treat (Spiced Mammoth Treats)
consumables[ 43816] =  33930 -- Charm of the Bloodletter (Amani Charm of the Bloodletter)
consumables[ 43818] =  33931 -- Charm of Mighty Mojo (Amani Charm of Mighty Mojo)
consumables[ 43820] =  33932 -- Charm of the Witch Doctor (Amani Charm of the Witch Doctor)
consumables[ 43822] =  33933 -- Charm of the Raging Defender (Amani Charm of the Raging Defender)
consumables[ 43959] = { -- Weak Alcohol
	 37494, -- Stranglethorn Brew
	 37904, -- Stranglethorn Brew
}
consumables[ 43961] = { -- Weak Alcohol
	 37491, -- Metok's Bubble Bock
	 37901, -- Metok's Bubble Bock
}
consumables[ 44107] = { -- Brewfest Drink
	 33030, -- Barleybrew Clear
	 34017, -- Small Step Brew
}
consumables[ 44109] = { -- Brewfest Drink
	 33028, -- Barleybrew Light
	 34018, -- Long Stride Brew
}
consumables[ 44110] = { -- Brewfest Drink
	 33029, -- Barleybrew Dark
	 34019, -- Path of Brew
}
consumables[ 44111] = { -- Brewfest Drink
	 33031, -- Thunder 45
	 34020, -- Jungle River Water
}
consumables[ 44112] = { -- Brewfest Drink
	 33032, -- Thunderbrew Ale
	 34021, -- Brewdoo Magic
}
consumables[ 44113] = { -- Brewfest Drink
	 33033, -- Thunderbrew Stout
	 34022, -- Stout Shrunken Head
}
consumables[ 44114] =  33034 -- Brewfest Drink (Gordok Grog)
consumables[ 44115] =  33035 -- Brewfest Drink (Ogre Mead)
consumables[ 44116] =  33036 -- Brewfest Drink (Mudder's Milk)
consumables[ 44212] =  34068 -- Jack-o'-Lanterned! (Weighted Jack-o'-Lantern)
consumables[ 44235] = { -- Water Breathing
	 34076, -- Fish Bladder
	 40390, -- Vic's Emergency Air Tank
}
consumables[ 44467] =  34130 -- Recovery Diver's Potion
consumables[ 44755] =  34191 -- Snowflakes (Handful of Snowflakes)
consumables[ 45373] =  34537 -- Bloodberry (Bloodberry Elixir)
consumables[ 45417] =  34684 -- Summer Flower Shower (Handful of Summer Petals)
consumables[ 45543] =  34721 -- First Aid (Frostweave Bandage)
consumables[ 45544] =  34722 -- First Aid (Heavy Frostweave Bandage)
consumables[ 45694] =  34832 -- Captain Rumsey's Lager
consumables[ 46168] = { -- Pet Biscuit
	 35223, -- Papa Hummel's Old-Fashioned Pet Biscuit
	 71153, -- Magical Pet Biscuit
}
consumables[ 46837] =  35716 -- Pure Death of Shattrath (Shattrath Flask of Pure Death)
consumables[ 46839] =  35717 -- Blinding Light of Shattrath (Shattrath Flask of Blinding Light)
consumables[ 46927] =  35720 -- Strong Alcohol (Lord of Frost's Private Label)
consumables[ 47228] =  35946 -- Fizzcrank Practice Parachute
consumables[ 47371] =  36748 -- Dark Brewmaiden's Brew
consumables[ 47430] =  36770 -- Undigestible (Zort's Protective Elixir)
consumables[ 48099] =  37091 -- Intellect (Scroll of Intellect VII)
consumables[ 48100] =  37092 -- Intellect (Scroll of Intellect VIII)
consumables[ 48101] =  37093 -- Stamina (Scroll of Stamina VII)
consumables[ 48102] =  37094 -- Stamina (Scroll of Stamina VIII)
consumables[ 48103] =  37097 -- Versatility (Scroll of Versatility VII)
consumables[ 48104] =  37098 -- Versatility (Scroll of Versatility VIII)
consumables[ 48332] =  37254 -- Going Ape! (Super Simian Sphere)
consumables[ 48359] =  37265 -- Tua'kea's Breathing Bladder
consumables[ 48719] =  37449 -- Water Breathing (Breath of Murloc)
consumables[ 48889] =  37582 -- Pyroblast Cinnamon Ball
consumables[ 48890] =  37583 -- G.N.E.R.D.S.
consumables[ 48891] =  37584 -- Soothing Spearmint Candy
consumables[ 48892] =  37585 -- Chewy Fel Taffy
consumables[ 49007] =  37604 -- Sparkling Smile (Tooth Pick)
consumables[ 49097] =  37661 -- Out of Body Experience (Gossamer Potion)
consumables[ 49352] =  37710 -- Crashin' Thrashin' Racer Controller
consumables[ 49512] =   1399 -- Fireball (Magic Candle)
consumables[ 49546] =  37877 -- Eagle Eyes (Silver Feather)
consumables[ 49736] =  37925 -- Experimental Mixture
consumables[ 50247] =  38233 -- Path of Illidan
consumables[ 50369] =  38294 -- Ethereal Liqueur
consumables[ 50425] =  38300 -- Diluted Ethereum Essence
consumables[ 50809] =  38351 -- Murliver Oil
consumables[ 50986] =  38466 -- Sulfuron Slammer
consumables[ 51010] =  38320 -- Dire Brew
consumables[ 51510] =  38577 -- Party G.R.E.N.A.D.E.
consumables[ 51845] =  38657 -- Freya's Ward
consumables[ 52009] =  38291 -- Ethereal Mutagen
consumables[ 53373] =  39738 -- Thunderbrew's Hard Ale
consumables[ 53746] =  40068 -- Wrath Elixir
consumables[ 53747] =  40072 -- Elixir of Versatility
consumables[ 53748] =  40073 -- Mighty Strength (Elixir of Mighty Strength)
consumables[ 53749] =  40076 -- Guru's Elixir
consumables[ 53751] =  40078 -- Elixir of Mighty Fortitude
consumables[ 53752] =  40079 -- Lesser Flask of Toughness
consumables[ 53753] =  40081 -- Nightmare Slumber (Potion of Nightmares)
consumables[ 53755] =  46376 -- Flask of the Frost Wyrm
consumables[ 53758] =  46379 -- Flask of Stoneblood
consumables[ 53760] =  46377 -- Flask of Endless Rage
consumables[ 53762] =  40093 -- Indestructible (Indestructible Potion)
consumables[ 53763] =  40097 -- Protection (Elixir of Protection)
consumables[ 53764] =  40109 -- Mighty Versatility (Elixir of Mighty Mageblood)
consumables[ 53908] =  40211 -- Speed (Potion of Speed)
consumables[ 53909] =  40212 -- Wild Magic (Potion of Wild Magic)
consumables[ 53910] =  40213 -- Arcane Protection (Mighty Arcane Protection Potion)
consumables[ 53911] =  40214 -- Fire Protection (Mighty Fire Protection Potion)
consumables[ 53913] =  40215 -- Frost Protection (Mighty Frost Protection Potion)
consumables[ 53914] =  40216 -- Nature Protection (Mighty Nature Protection Potion)
consumables[ 53915] =  40217 -- Shadow Protection (Mighty Shadow Protection Potion)
consumables[ 54212] =  46378 -- Flask of Pure Mojo
consumables[ 54452] =  28103 -- Adept's Elixir
consumables[ 54494] =  22831 -- Major Agility (Elixir of Major Agility)
consumables[ 54497] =   1177 -- Lesser Armor (Oil of Olaf)
consumables[ 55001] = 107640 -- Parachute (Potion of Slow Fall)
consumables[ 55346] =  41367 -- Dark Jade Focusing Lens
consumables[ 55536] =  41509 -- Frostweave Net
consumables[ 55592] =  43352 -- Clean (Pet Grooming Kit)
consumables[ 56190] =  42420 -- Shadow Crystal Focusing Lens
consumables[ 56191] =  42421 -- Shadow Jade Focusing Lens
consumables[ 57388] =  43004 -- Critter Bite (Critter Bites)
consumables[ 57727] =  43135 -- Fate Rune of Fleet Feet
consumables[ 58441] =  43472 -- Snowfall Lager
consumables[ 58442] =  43462 -- Airy Pale Ale
consumables[ 58444] =  43470 -- Worg Tooth Oatmeal Stout
consumables[ 58448] =  43465 -- Strength (Scroll of Strength VII)
consumables[ 58449] =  43466 -- Strength (Scroll of Strength VIII)
consumables[ 58450] =  43463 -- Agility (Scroll of Agility VII)
consumables[ 58451] =  43464 -- Agility (Scroll of Agility VIII)
consumables[ 58452] =  43467 -- Armor (Scroll of Protection VII)
consumables[ 58454] =  43473 -- Drakefire Chile Ale
consumables[ 58493] =  43489 -- Mohawked! (Mohawk Grenade)
consumables[ 58496] =  43488 -- Sad (Last Week's Mammoth)
consumables[ 58499] =  43490 -- Happy (Tasty Cupcake)
consumables[ 58500] =  43491 -- Angry (Bad Clams)
consumables[ 58502] =  43492 -- Scared (Haunted Herring)
consumables[ 59090] =  43626 -- Happy Pet Snack
consumables[ 59640] =  44012 -- Underbelly Elixir
consumables[ 59755] =  44064 -- Frenzyheart Fury (Nepeta Leaf)
consumables[ 59776] =  44065 -- Oracle Ownage (Oracle Secret Solution)
consumables[ 60106] =  44114 -- Old Spices
consumables[ 60122] =  44228 -- Baby Spice
consumables[ 60340] =  44325 -- Accuracy (Elixir of Accuracy)
consumables[ 60341] =  44327 -- Deadly Strikes (Elixir of Deadly Strikes)
consumables[ 60343] =  44328 -- Mighty Defense (Elixir of Mighty Defense)
consumables[ 60344] =  44329 -- Expertise (Elixir of Expertise)
consumables[ 60346] =  44331 -- Lightning Speed (Elixir of Lightning Speed)
consumables[ 60347] =  44332 -- Mighty Thoughts (Elixir of Mighty Thoughts)
consumables[ 61717] =  44792 -- Blossoming Branch
consumables[ 61781] = { -- Turkey Feathers
	 44812, -- Turkey Shooter
	116400, -- Silver-Plated Turkey Shooter
}
consumables[ 61819] =  44817 -- Manabonked! (The Mischief Maker)
consumables[ 62061] =  21213 -- Festive Holiday Mount (Preserved Holly)
consumables[ 62062] =  37816 -- Brewfestive Holiday Mount (Preserved Brewfest Hops)
consumables[ 63729] =  45621 -- Minor Accuracy (Elixir of Minor Accuracy)
consumables[ 64184] =  45896 -- In the Maws of the Old God (Unbound Fragments of Val'anyr)
consumables[ 65247] =  33874 -- Really Well Fed (Kibler's Bits)
consumables[ 65363] =  46403 -- Brewfest Drink (Chuganpug's Delight)
consumables[ 65393] =  46718 -- Flowers of the Dead (Orange Marigold)
consumables[ 65426] =  46696 -- On the Prowl (Panther Figurine)
consumables[ 65451] =  46709 -- Using MiniZep Controller (MiniZep Controller)
consumables[ 65745] = { -- Path of Cenarius
	 46779, -- Path of Cenarius
	103631, -- Lucky Path of Cenarius
}
consumables[ 65780] =  46783 -- Pink Gumball
consumables[ 66050] =  39477 -- Fresh Dwarven Hops (Fresh Dwarven Brewfest Hops)
consumables[ 66051] =  39476 -- Fresh Goblin Hops (Fresh Goblin Brewfest Hops)
consumables[ 66052] =  37750 -- Fresh Brewfest Hops
consumables[ 68417] = { -- Wrapping Paper - Dummy Spell
	  5042, -- Red Ribboned Wrapping Paper
	  5048, -- Blue Ribboned Wrapping Paper
	 17303, -- Blue Ribboned Wrapping Paper
	 17304, -- Green Ribboned Wrapping Paper
	 17307, -- Purple Ribboned Wrapping Paper
}
consumables[ 69466] =  49649 -- Hurl Spine (Impaling Spine)
consumables[ 69560] = { -- Brewfest Drink
	 46399, -- Thunder's Plunder
	 46402, -- Promise of the Pandaren
}
consumables[ 69561] = { -- Brewfest Drink
	 46400, -- Barleybrew Gold
	 46401, -- Crimson Stripe
}
consumables[ 70233] =  49856 -- "VICTORY" Perfume
consumables[ 70234] =  49857 -- "Enchantress" Perfume
consumables[ 70235] =  49858 -- "Forever" Perfume
consumables[ 70242] =  49859 -- "Bravado" Cologne
consumables[ 70243] =  49861 -- "STALWART" Cologne
consumables[ 70244] =  49860 -- "Wizardry" Cologne
consumables[ 70456] =  50218 -- Stealth (Krennan's Potion of Stealth)
consumables[ 70631] =  50220 -- Swing Torch (Half-Burnt Torch)
consumables[ 70771] = { -- Lovely Card
	 49936, -- Lovely Stormwind Card
	 49937, -- Lovely Undercity Card
}
consumables[ 70774] = { -- Lovely Card
	 49938, -- Lovely Darnassus Card
	 49939, -- Lovely Orgrimmar Card
}
consumables[ 70777] = { -- Lovely Card
	 49940, -- Lovely Ironforge Card
	 49941, -- Lovely Thunder Bluff Card
}
consumables[ 70779] = { -- Lovely Card
	 49942, -- Lovely Exodar Card
	 49943, -- Lovely Silvermoon City Card
}
consumables[ 71087] =  50163 -- Lovely Rose
consumables[ 71092] =  50164 -- Fras Siabi's Barely Bigger Beer
consumables[ 71349] =  50441 -- Capture Lasher Seed (Garl's Net)
consumables[ 71388] =  50334 -- Rapier of the Gilnean Patriots
consumables[ 71775] =  50430 -- Throw Meat (Scraps of Rotting Meat)
consumables[ 71909] =  50471 -- Heartbroken (The Heartbreaker)
consumables[ 73320] =  52201 -- Frostborn Illusion (Muradin's Favor)
consumables[ 73619] =  52490 -- Stardust
consumables[ 73673] =  52505 -- Poison Extraction Totem
consumables[ 73984] =  52828 -- Mental Training (Orb of Ascension)
consumables[ 74359] =  52819 -- Extinguish Flames (Frostgale Crystal)
consumables[ 74553] =  53049 -- First Aid (Embersilk Bandage)
consumables[ 74554] =  53050 -- First Aid (Heavy Embersilk Bandage)
consumables[ 74555] =  53051 -- First Aid (Dense Embersilk Bandage)
consumables[ 74589] =  53057 -- Identity Crisis (Faded Wizard Hat)
consumables[ 74797] =  54455 -- Paint Bomb
consumables[ 74842] =  53476 -- Gnomeregan Overcloak
consumables[ 75148] =  54442 -- Embersilk Net
consumables[ 75192] =  54463 -- Weakening (Flameseer's Staff)
consumables[ 75531] =  54651 -- Gnomeregan Pride
consumables[ 75532] =  54653 -- Darkspear Pride
consumables[ 75554] =  54814 -- Flame Ascendancy (Talisman of Flame Ascendancy)
consumables[ 75693] =  54822 -- Darkspear Overcloak (Sen'jin Overcloak)
consumables[ 75724] =  55137 -- Seeds of Discord (Ogre Disguise)
consumables[ 76145] =  54962 -- Wind Powered (Elemental Air Shard)
consumables[ 77664] =  56178 -- Throw Rope (Duarn's Rope)
consumables[ 78993] =  57194 -- Concentration (Potion of Concentration)
consumables[ 79468] =  58084 -- Ghost Elixir
consumables[ 79469] =  58085 -- Flask of Steelskin
consumables[ 79470] =  58086 -- Flask of the Draconic Mind
consumables[ 79471] =  58087 -- Flask of the Winds
consumables[ 79472] =  58088 -- Flask of Titanic Strength
consumables[ 79474] =  58089 -- Elixir of the Naga
consumables[ 79475] =  58090 -- Earthen Armor (Earthen Potion)
consumables[ 79476] =  58091 -- Volcanic Power (Volcanic Potion)
consumables[ 79477] =  58092 -- Elixir of the Cobra
consumables[ 79480] =  58093 -- Elixir of Deep Earth
consumables[ 79481] =  58094 -- Impossible Accuracy (Elixir of Impossible Accuracy)
consumables[ 79625] =  58142 -- Deathblood Venom
consumables[ 79632] =  58144 -- Mighty Speed (Elixir of Mighty Speed)
consumables[ 79633] =  58145 -- Tol'vir Agility (Potion of the Tol'vir)
consumables[ 79634] =  58146 -- Golem's Strength (Golemblood Potion)
consumables[ 79635] =  58148 -- Elixir of the Master
consumables[ 80263] =  58488 -- Potion of Treasure Finding
consumables[ 80532] =  44330 -- Armor Piercing (Elixir of Armor Piercing)
consumables[ 80760] =  58933 -- Westfall Mud Pie
consumables[ 82563] =  60382 -- Carve Meat (Mylra's Knife)
consumables[ 85624] =  61381 -- Yance's Special Burger (Yance's Special Burger Patty)
consumables[ 87368] =  62542 -- Mech Control Scrambler
consumables[ 87648] =  62675 -- Starfire Espresso
consumables[ 87649] =  62680 -- Satisfied (Chocolate Cookie)
consumables[ 88026] =  62795 -- Silversnap Swim Tonic
consumables[ 89342] =  63307 -- Versatility (Scroll of Versatility IX)
consumables[ 89343] =  63303 -- Agility (Scroll of Agility IX)
consumables[ 89344] =  63308 -- Armor (Scroll of Protection IX)
consumables[ 89345] =  63306 -- Stamina (Scroll of Stamina IX)
consumables[ 89346] =  63304 -- Strength (Scroll of Strength IX)
consumables[ 89347] =  63305 -- Intellect (Scroll of Intellect IX)
consumables[ 91722] =  64640 -- Puffer Breath (Infectis Puffer Sashimi)
consumables[ 91754] =  64481 -- Receive the Blessing of the Old God (Blessing of the Old God)
consumables[ 91760] =  64646 -- Endure the Transformation (Bones of Transformation)
consumables[ 91771] =  64651 -- Wisp Form (Wisp Amulet)
consumables[ 92146] =  64881 -- Scarab Storm (Pendant of the Scarab Storm)
consumables[ 93095] = 134022 -- Burgy Blackheart's Handsome Hat
consumables[ 94160] =  67438 -- Flask of Flowing Water
consumables[ 96312] =  68806 -- Kalytha's Haunted Locket
consumables[ 97020] =  69027 -- Eat Cone of Cold (Cone of Cold)
consumables[ 97026] =  34000 -- Blood Elf Female Mask
consumables[ 97030] =  34002 -- Blood Elf Male Mask
consumables[ 97033] =  34001 -- Draenei Female Mask
consumables[ 97034] =  34003 -- Draenei Male Mask
consumables[ 97035] =  20562 -- Dwarf Female Mask
consumables[ 97054] =  20561 -- Dwarf Male Mask
consumables[ 97055] =  20392 -- Gnome Female Mask
consumables[ 97056] =  20391 -- Gnome Male Mask
consumables[ 97057] =  49212 -- Goblin Female Mask
consumables[ 97058] =  49210 -- Goblin Male Mask
consumables[ 97059] =  20565 -- Human Female Mask
consumables[ 97061] =  20566 -- Human Male Mask
consumables[ 97062] =  20563 -- Night Elf Female Mask
consumables[ 97063] =  20564 -- Night Elf Male Mask
consumables[ 97096] =  20569 -- Orc Female Mask
consumables[ 97097] =  20570 -- Orc Male Mask
consumables[ 97107] =  20571 -- Tauren Female Mask
consumables[ 97108] =  20572 -- Tauren Male Mask
consumables[ 97109] =  20567 -- Troll Female Mask
consumables[ 97111] =  20568 -- Troll Male Mask
consumables[ 97112] =  20574 -- Undead Female Mask
consumables[ 97113] =  20573 -- Undead Male Mask
consumables[ 97115] =  49215 -- Worgen Female Mask
consumables[ 97116] =  49216 -- Worgen Male Mask
consumables[ 97150] =  69187 -- Murloc Female Mask
consumables[ 97159] =  69188 -- Murloc Male Mask
consumables[ 97162] =  69189 -- Naga Female Mask
consumables[ 97163] =  69190 -- Naga Male Mask
consumables[ 97165] =  69192 -- Ogre Female Mask
consumables[ 97166] =  69193 -- Ogre Male Mask
consumables[ 97167] =  69194 -- Vrykul Female Mask
consumables[ 97169] =  69195 -- Vrykul Male Mask
consumables[ 97602] =  69233 -- Eat Cone of Cold (Cone of Cold)
consumables[ 98444] =  69775 -- Vrykul Drinking Horn
consumables[ 98445] =  69776 -- Trapped in Amber (Ancient Amber)
consumables[ 99976] =  70725 -- Squashling Costume (Hallowed Hunter Wand - Squashling)
consumables[100951] =  71134 -- WoW's 8th Anniversary (Celebration Package)
consumables[101498] = { -- Throwing Starfish
	 71627, -- Throwing Starfish
	110506, -- Parasitic Starfish
}
consumables[102362] =  72159 -- Red Ogre Mage Costume (Magical Ogre Idol)
consumables[102365] =  72161 -- Spurious Sarcophagus
consumables[102694] =  72985 -- First Aid (Windwool Bandage)
consumables[102695] =  72986 -- First Aid (Heavy Windwool Bandage)
consumables[105681] =  76075 -- Mantid Elixir
consumables[105682] =  76076 -- Mad Hozen Elixir
consumables[105683] =  76077 -- Elixir of Weaponry
consumables[105684] =  76078 -- Elixir of the Rapids
consumables[105685] =  76079 -- Elixir of Peace
consumables[105686] =  76080 -- Elixir of Perfection
consumables[105687] =  76081 -- Elixir of Mirrors
consumables[105688] =  76083 -- Monk's Elixir
consumables[105689] =  76084 -- Flask of Spring Blossoms
consumables[105691] =  76085 -- Flask of the Warm Sun
consumables[105693] =  76086 -- Flask of Falling Leaves
consumables[105694] =  76087 -- Flask of the Earth
consumables[105696] =  76088 -- Flask of Winter's Bite
consumables[105697] =  76089 -- Virmen's Bite
consumables[105698] =  76090 -- Potion of the Mountains
consumables[105701] =  76092 -- Potion of Focus
consumables[105702] =  76093 -- Potion of the Jade Serpent
consumables[105706] =  76095 -- Potion of Mogu Power
consumables[105707] =  76096 -- Darkwater Potion
consumables[109933] =  78883 -- Darkmoon Firewater
consumables[110648] =  79048 -- Whimsical Skull Mask
consumables[113095] =  79769 -- Demon Hunter's Aspect
consumables[115037] =  80313 -- Ling-Ting's Herbal Journey (Ling-Ting's Favorite Tea)
consumables[117164] =  81054 -- Kafa Rush (Kafa'kota Berry)
consumables[122099] =  93314 -- Bamboozled (Magic Bamboo Shoot)
consumables[122159] =  90427 -- Pandaren Brewpack
consumables[123145] =  84686 -- Dreadbrew (Mug of Dreadbrew)
consumables[125167] =  85973 -- Ancient Pandaren Fishing Charm
consumables[125686] =  86432 -- Banana Infused Rum
consumables[125879] =  86508 -- Fresh Bread
consumables[126118] =  86536 -- Dart of Lethargy (Wu Kao Dart of Lethargy)
consumables[126144] =  87264 -- Four Senses Brew
consumables[126294] =  86607 -- Goblin Dragon Gun, Mark II
consumables[126389] = 109076 -- Goblin Glider (Goblin Glider Kit)
consumables[127145] =  87528 -- Honorary Brewmaster Keg
consumables[127207] =  86568 -- Memory of Mr. Smite (Mr. Smite's Brass Compass)
consumables[127230] =  86569 -- Visions of Insanity (Crystal of Insanity)
consumables[127249] =  86573 -- Flesh to Stone (Shard of Archstone)
consumables[127250] =  86574 -- Ancient Knowledge (Elixir of Ancient Knowledge)
consumables[127261] = { -- Stonebinding
	 86571, -- Kang's Bindstone
	104262, -- Odd Polished Stone
}
consumables[127266] =  86577 -- Amber Prison (Rod of Ambershaping)
consumables[127269] =  86578 -- Everlasting Frenzy (Eternal Warrior's Sigil)
consumables[127285] =  86582 -- Shimmering Water (Aqua Jewel)
consumables[127292] =  86581 -- Watersight (Farwater Conch)
consumables[127318] =  86590 -- Gentle Breeze (Essence of the Breeze)
consumables[127322] =  86592 -- Offering of Peace (Hozen Peace Pipe)
consumables[127323] =  86593 -- Beach Bum (Hozen Beach Ball)
consumables[127770] =  88382 -- Keenbean Kafa Boost (Keenbean Kafa)
consumables[127771] =  88381 -- Silversage Incense
consumables[127803] =  88377 -- Turnip Paint Gun (Turnip Paint "Gun")
consumables[127843] =  88379 -- Grummlecake
consumables[127882] = { -- Squirmy Delight
	 88388, -- Squirmy Delight
	140343, -- Exotic Squirmy Delight
}
consumables[128018] =  88385 -- Searing Gaze of the Dook (Hozen Idol)
consumables[128081] =  88384 -- The Burlap Blessing (Burlap Ritual Bag)
consumables[128150] =  88417 -- Gokk'lok Shell (Gokk'lok's Shell)
consumables[128275] =  88589 -- Cremate (Cremating Torch)
consumables[128290] =  88492 -- Wicked Wikket
consumables[128307] =  88530 -- Bubbling Beverage
consumables[128308] =  88529 -- Sparkling Water
consumables[128328] =  88580 -- Ken-Ken's Mask
consumables[128797] =  88802 -- Summon Foxicopter (Foxicopter Controller)
consumables[128849] = 138981 -- Guard (Skinny Milk)
consumables[129023] =  88566 -- Surgical Alterations (Krastinov's Bag of Horrors)
consumables[129498] =  89230 -- Restorative Amber
consumables[129836] =  86586 -- Panflute Melody (Panflute of Pandaria)
consumables[129861] =  86575 -- Ancient Ritual (Chalice of Secrets)
consumables[129864] =  86583 -- Salyin Distraction (Salyin Battle Banner)
consumables[130121] =  89373 -- Scotty's Lucky Coin
consumables[130678] =  89682 -- Unruly Behemoth (Oddly-Shaped Horn)
consumables[130730] =  89697 -- Kafa-Crazed Goat (Bag of Kafa Beans)
consumables[130895] =  89770 -- Rampaging Yak (Tuft of Yak Fur)
consumables[131171] =  89869 -- Pandaren Scarecrow
consumables[131307] =  89906 -- Magical Mini-Treat
consumables[131364] =  90006 -- Vanish (Wu Kao Smoke Bomb)
consumables[131493] =  90067 -- B.F.F. (B. F. F. Necklace)
consumables[131510] = { -- Uncontrolled Banish
	 90078, -- Cracked Talisman
	104320, -- Cursed Talisman
}
consumables[131785] =  90426 -- Brewhelm
consumables[131798] =  90428 -- Pandaren Brew
consumables[132700] =  90918 -- WoW's 9th Anniversary (Celebration Package)
consumables[133994] =  86143 -- Revive Battle Pets (Battle Pet Bandage)
consumables[134870] =  22848 -- Empowerment (Elixir of Empowerment)
consumables[134873] =  58143 -- Prismatic Elixir
consumables[134986] = { -- Potion of Brawler's Might
	 92941, -- Potion of Brawler's Might
	 98063, -- Bottomless Potion of Brawler's Might
}
consumables[134987] = { -- Potion of Brawler's Cunning
	 92942, -- Potion of Brawler's Cunning
	 98062, -- Bottomless Potion of Brawler's Cunning
}
consumables[134989] = { -- Potion of Brawler's Deftness
	 92943, -- Potion of Brawler's Deftness
	 98061, -- Bottomless Potion of Brawler's Deftness
}
consumables[135376] =  93158 -- Bottled (Expired Blackout Brew)
consumables[136583] =  93730 -- Darkmoon Top Hat
consumables[138927] = { -- Burning Essence
	 94604, -- Burning Seed
	122304, -- Fandral's Seed Pouch
}
consumables[139488] = { -- Sleep Dust
	 95093, -- Sleep Dust
	 97154, -- Sleep Dust
}
consumables[139490] = { -- Frost Rune Trap
	 95055, -- Frost Rune Trap
	 97156, -- Frost Rune Trap
}
consumables[139492] = { -- Potion of Light Steps
	 95054, -- Potion of Light Steps
	 97157, -- Potion of Light Steps
}
consumables[141917] =  97919 -- Whole-Body Shrinka'
consumables[142204] =  98112 -- Lesser Pet Treat
consumables[142205] =  98114 -- Pet Treat
consumables[142278] =  98117 -- Moneybrau Bloat (Moneybrau)
consumables[142325] =  98132 -- Shado-Pan Geyser Gun
consumables[142372] =  98136 -- Control Jerry (Gastropod Shell)
consumables[144787] = 101571 -- Moonfang Shroud
consumables[145255] = 105898 -- Aspect of Moonfang (Moonfang's Paw)
consumables[145727] =   1127 -- Flamestrike (Flash Bundle)
consumables[145731] =  13508 -- Eye of Kilrogg (Eye of Arachnida)
consumables[146555] = 102351 -- Drums of Rage
consumables[146939] = 103557 -- Enduring Elixir of Wisdom
consumables[147055] = 103641 -- Singing Crystal
consumables[147226] = 103642 -- Book of the Ages
consumables[147412] = 104111 -- Elixir of Wandering Spirits
consumables[147476] = 103643 -- Dew of Eternal Morning
consumables[147643] = 134024 -- Cursed Swabby Helmet
consumables[148238] = 104196 -- Consume Ogre Queasine (Delectable Ogre Queasine)
consumables[148361] = 103683 -- Mask of Anger
consumables[148365] = 103681 -- Mask of Doubt
consumables[148366] = 103679 -- Mask of Fear
consumables[148367] = 103680 -- Mask of Hatred
consumables[148368] = 103682 -- Mask of Violence
consumables[148385] = 102467 -- Censer of Eternal Agony
consumables[148429] = 102463 -- Fire-Watcher's Oath
consumables[148521] = 104287 -- Windfeather (Windfeather Plume)
consumables[148523] = 104288 -- Jade Mist (Condensed Jademist)
consumables[148525] = 104289 -- Faintly-Glowing Herb
consumables[148526] = 104290 -- Sticky Silk (Sticky Silkworm Goo)
consumables[148528] = 104293 -- Scuttler's Shell
consumables[148529] = 104294 -- Rime of the Time-Lost Mariner
consumables[148538] = 104302 -- Blackflame Daggers
consumables[148554] = 104312 -- Strange Spores (Strange Glowing Mushroom)
consumables[148565] = 104316 -- Spectral Grog
consumables[148577] = 104318 -- Using Flyer Controller (Crashin' Thrashin' Flyer Controller)
consumables[148623] = 104328 -- Cauterizing Core
consumables[148626] = 104329 -- Furious Ashhide Mushan (Ash-Covered Horn)
consumables[148773] = 104346 -- Golden Glider
consumables[150047] = 106894 -- Blasterone (Blasterown Tablets)
consumables[150986] = 107224 -- WoW's 10th Anniversary (Celebration Package)
consumables[154694] = 108631 -- Crashin' Thrashin' Roller (Crashin' Thrashin' Roller Controller)
consumables[154696] = 108635 -- Crashin' Thrashin' Killdozer (Crashin' Thrashin' Killdozer Controller)
consumables[154697] = 108633 -- Crashin' Thrashin' Cannon (Crashin' Thrashin' Cannon Controller)
consumables[154698] = 108634 -- Crashin' Thrashin' Mortar (Crashin' Thrashin' Mortar Controller)
consumables[154699] = 108632 -- Crashin' Thrashin' Flamer (Crashin' Thrashin' Flamer Controller)
consumables[156064] = 109153 -- Greater Draenic Agility Flask
consumables[156070] = 109147 -- Draenic Intellect Flask
consumables[156071] = 109148 -- Draenic Strength Flask
consumables[156073] = 109145 -- Draenic Agility Flask
consumables[156077] = 109152 -- Draenic Stamina Flask
consumables[156079] = 109155 -- Greater Draenic Intellect Flask
consumables[156080] = 109156 -- Greater Draenic Strength Flask
consumables[156084] = 109160 -- Greater Draenic Stamina Flask
consumables[156136] = 109184 -- Stealth Field (Stealthman 54)
consumables[156423] = { -- Draenic Agility Potion
	109217, -- Draenic Agility Potion
	122453, -- Commander's Draenic Agility Potion
}
consumables[156426] = { -- Draenic Intellect Potion
	109218, -- Draenic Intellect Potion
	122454, -- Commander's Draenic Intellect Potion
}
consumables[156428] = { -- Draenic Strength Potion
	109219, -- Draenic Strength Potion
	122455, -- Commander's Draenic Strength Potion
}
consumables[156430] = { -- Draenic Versatility Potion
	109220, -- Draenic Versatility Potion
	122456, -- Commander's Draenic Versatility Potion
}
consumables[156432] = { -- Draenic Channeled Mana Potion
	109221, -- Draenic Channeled Mana Potion
	118262, -- Brilliant Dreampetal
}
consumables[156779] = 109599 -- Neural Silencer
consumables[157737] = 110505 -- Mesmerizing Fruit Hat
consumables[158031] = 110274 -- Jawless Skulker Bait
consumables[158034] = 110289 -- Fat Sleeper Bait
consumables[158035] = 110290 -- Blind Lake Sturgeon Bait
consumables[158036] = 110291 -- Fire Ammonite Bait
consumables[158037] = 110292 -- Sea Scorpion Bait
consumables[158038] = 110293 -- Abyssal Gulper Eel Bait
consumables[158039] = 110294 -- Blackwater Whiptail Bait
consumables[158474] = 110424 -- Savage Safari Hat
consumables[158486] =  92738 -- Safari Hat
consumables[158533] = 110433 -- Ambush Dragonfly (Dragonfly Ambusher)
consumables[158693] = 110508 -- Fish Pheromones ("Fragrant" Pheromone Fish)
consumables[160688] = 108743 -- Smoldering Boots (Deceptia's Smoldering Boots)
consumables[160748] = 111522 -- Exceptional Alcohol (Tikari & K.A.Y.T.)
consumables[161255] = 111603 -- First Aid (Antiseptic Bandage)
consumables[161495] = 111842 -- Star Root Tuber
consumables[162313] = 112090 -- Transmorphed (Transmorphic Tincture)
consumables[162402] = 108739 -- Shiny Pearl (Pretty Draenor Pearl)
consumables[162906] = 112321 -- Enchanted Dust
consumables[163219] = 112384 -- Reflecting Prism
consumables[163441] = 112498 -- Prismatic Focusing Lens
consumables[163522] = 112499 -- Stinky Gloom Bomb (Stinky Gloom Bombs)
consumables[165185] = 113096 -- Bloodclaw Charm (Bloodmane Charm)
consumables[165802] = 113143 -- Well Fed (Glowing Honeycomb)
consumables[166352] = 113278 -- Find Treasure (Scavenger's Eyepiece)
consumables[166353] = 113273 -- Soulstealer (Orb of the Soulstealer)
consumables[166354] = 113274 -- Celerity (Plume of Celerity)
consumables[166355] = 113275 -- Powertap (Ravenlord's Talon)
consumables[166357] = 113277 -- Ogreblood (Ogreblood Potion)
consumables[166361] = 113276 -- Pride (Pridehunter's Fang)
consumables[166592] = 113375 -- Vindicator's Armor Polish Kit
consumables[167268] = 113540 -- Ba'ruun's Bountiful Bloom
consumables[167273] = 113542 -- Whispers of Rai'Vosh
consumables[167399] = 113570 -- Make Like A Tree (Ancient's Bloom)
consumables[167839] = 113631 -- Hypnotize Critter (Hypnosis Goggles)
consumables[167982] = { -- Delicious Brew
	114015, -- Lavastone Pale
	114016, -- Lavastone Jack
}
consumables[168223] = 114124 -- Invisibility (Phantom Potion)
consumables[168224] = 114125 -- Preserved Discombobulator Ray
consumables[168349] = 114238 -- Well Fed (Spiced Barbed Trout)
consumables[168362] = 114244 -- GG-117 Micro-Jetpack
consumables[168655] = 114983 -- Sticky Grenade (Sticky Grenade Launcher)
consumables[168657] = 114227 -- Bubble Wand
consumables[168935] = 114926 -- Restoration (Restorative Goldcap)
consumables[169291] = 111476 -- Stolen Breath
consumables[169356] = 114982 -- Pure Songflower Serenade (Song Flower)
consumables[169489] = 115020 -- Goblin Rocket Pack
consumables[170221] = 115466 -- Elemental Fragment
consumables[170225] = 115464 -- Frosty (Lingering Frost Essence)
consumables[170293] = 115468 -- Frosty (Permanent Frost Essence)
consumables[170295] = 115470 -- Displaced (Lingering Time Bubble)
consumables[170298] = 115472 -- Displaced (Permanent Time Bubble)
consumables[170398] = 115501 -- Kowalski's Music Box
consumables[170425] = 115506 -- Treessassin's Guise
consumables[170493] = 115519 -- Honorbound (Flask of the Honorbound)
consumables[170494] = 115520 -- Flask of Conquest (Spoiled Flask of Conquest)
consumables[170495] = { -- Swift Riding Crop
	115522, -- Swift Riding Crop
	116397, -- Swift Riding Crop
}
consumables[170522] = { -- Flimsy X-Ray Goggles
	115532, -- Flimsy X-Ray Goggles
	116398, -- Flimsy X-Ray Goggles
}
consumables[170788] = 116067 -- Ring of Broken Promises
consumables[170839] = 116114 -- Magma Crawler Illusion (Prestige Card: The Turn)
consumables[170869] = 116115 -- Blazing Wings
consumables[170895] = 116119 -- Ango'rosh Sorcerer Stone
consumables[170908] = 116120 -- Tasty Talador Lunch
consumables[170932] = 116125 -- All Wrapped Up (Klikixx's Webspinner)
consumables[170937] = 119157 -- Saberon Cat-Sip
consumables[170950] = 116139 -- Haunted (Haunting Memento)
consumables[171234] = 116456 -- Scroll of Storytelling
consumables[171245] = 116412 -- Scroll of Invisibility (Scroll of Mass Invisibility)
consumables[171247] = 116413 -- Scroll of Town Portal
consumables[171249] = 116411 -- Scroll of Protection
consumables[171250] = 116410 -- Scroll of Speed
consumables[171352] = 115503 -- Molten Path (Blazing Diamond Pendant)
consumables[171554] = 116440 -- Burning Defender (Burning Defender's Medallion)
consumables[171567] = 116442 -- Spirit of Vengeance (Vengeful Spiritshard)
consumables[171573] = 116444 -- Spirit of Sorrow (Forlorn Spiritshard)
consumables[171574] = 116443 -- Spirit of Peace (Peaceful Spiritshard)
consumables[171575] = 116445 -- Spirit of Anxiety (Anxious Spiritshard)
consumables[171607] = { -- Love Ray
	116648, -- Manufactured Love Prism
	116651, -- True Love Prism
}
consumables[171725] = 117013 -- Wand of Lightning Shield
consumables[171761] = 116758 -- Brewfest Banner
consumables[171782] = 116763 -- Crashin' Thrashin' Shredder Controller
consumables[171958] = 116828 -- Exquisite Lich King Costume (Exquisite Costume Set: "The Lich King")
consumables[172027] = 116856 -- Blooming Rose ("Blooming Rose" Contender's Costume)
consumables[172047] = 116889 -- Purple Phantom ("Purple Phantom" Contender's Costume)
consumables[172049] = 116890 -- Santo's Sun ("Santo's Sun" Contender's Costume)
consumables[172052] = 116888 -- Night Demon ("Night Demon" Contender's Costume)
consumables[172053] = 116891 -- Snowy Owl ("Snowy Owl" Contender's Costume)
consumables[172160] = 116925 -- Free Action (Vintage Free Action Potion)
consumables[172368] = 116979 -- Blackwater Anti-Venom
consumables[172548] = 116999 -- Scroll of Replenishment
consumables[172609] = 117398 -- Subversive Infestation (Everbloom Seed Pouch)
consumables[173102] = 117550 -- Bees! BEES! BEEEEEEEEEEES! (Angry Beehive)
consumables[173125] = 117569 -- AUGH (Giant Deathweb Egg)
consumables[173260] = 118006 -- Shieldtronic Shield
consumables[173359] = 115525 -- Scary Ogre (Scary Ogre Face)
consumables[173893] = 118221 -- Petrify Critter (Petrification Stone)
consumables[174004] = 113543 -- Spirit of Shinri
consumables[174018] = 118278 -- Pale Vision Potion
consumables[174021] = 118265 -- Echoing Betrayal
consumables[174062] = 118275 -- Well Fed (Perfect Nagrand Cherry)
consumables[174077] = 118274 -- Well Fed (Perfect Fuzzy Pear)
consumables[174078] = 118277 -- Well Fed (Perfect Ironpeel Plantain)
consumables[174079] = 118273 -- Well Fed (Perfect O'ruk Orange)
consumables[174080] = 118276 -- Well Fed (Perfect Greenskin Apple)
consumables[174524] = 118414 -- Awesome! (Awesomefish)
consumables[174528] = 118415 -- Griefer (Grieferfish)
consumables[174841] = 118511 -- Thank you! (Tyfish)
consumables[175439] = 118631 -- Stout Augmentation (Stout Augment Rune)
consumables[175456] = 118630 -- Hyper Augmentation (Hyper Augment Rune)
consumables[175457] = 118632 -- Focus Augmentation (Focus Augment Rune)
consumables[175618] = 118664 -- Fury of the Frostwolf (Frostwolf Elixir)
consumables[175623] = 118665 -- Valor of the Council (Exarch Elixir)
consumables[175630] = 118666 -- Claw of the Outcasts (Arakkoa Elixir)
consumables[175631] = 118667 -- Ticking Bomb (Steamwheedle Elixir)
consumables[175632] = 118668 -- Mocking Skull (Laughing Skull Elixir)
consumables[175633] = 118669 -- Deadeye (Sha'tari Elixir)
consumables[175771] = 118698 -- Wings of the Outcasts
consumables[175790] = { -- Draenic Swiftness Potion
	116266, -- Draenic Swiftness Potion
	122452, -- Commander's Draenic Swiftness Potion
}
consumables[175817] = 116276 -- Draenic Living Action Potion
consumables[175832] = 118716 -- Goren Disguise (Goren Garb)
consumables[175833] = { -- Invisibility
	116268, -- Draenic Invisibility Potion
	122451, -- Commander's Draenic Invisibility Potion
}
consumables[175841] = 118711 -- Draenic Water Walking (Draenic Water Walking Elixir)
consumables[175844] = 116271 -- Greater Water Breathing (Draenic Water Breathing Elixir)
consumables[176049] = 118897 -- Miner's Coffee
consumables[176057] = 118900 -- Grob's Fancy Brew (Hol'bruk's Brutal Brew)
consumables[176059] = 118904 -- Unleashed Mania
consumables[176061] = 118903 -- Preserved Mining Pick
consumables[176064] = 118905 -- Sinister Spores
consumables[176107] = { -- Brawler's Draenic Agility Potion
	118910, -- Brawler's Draenic Agility Potion
	118913, -- Brawler's Bottomless Draenic Agility Potion
}
consumables[176108] = { -- Brawler's Draenic Intellect Potion
	118911, -- Brawler's Draenic Intellect Potion
	118914, -- Brawler's Bottomless Draenic Intellect Potion
}
consumables[176109] = { -- Brawler's Draenic Strength Potion
	118912, -- Brawler's Draenic Strength Potion
	118915, -- Brawler's Bottomless Draenic Strength Potion
}
consumables[176151] = 118922 -- Whispers of Insanity (Oralius' Whispering Crystal)
consumables[176160] = 118935 -- Bloom (Ever-Blooming Frond)
consumables[176179] = 118937 -- Gamon's Heroic Spirit (Gamon's Braid)
consumables[176180] = 118938 -- Duplicate Millhouse (Manastorm's Duplicator)
consumables[176438] = 119092 -- Moroes' Famous Polish
consumables[176594] = 119144 -- Touch of the Naaru
consumables[176759] = 119180 -- Goren "Log" Roller
consumables[176785] = 119182 -- Soulsaver (Soul Evacuation Crystal)
consumables[176898] = 119215 -- Gnomebulation (Robo-Gnomebulator)
consumables[176899] = 119220 -- Gladiator's Banner (Alliance Gladiator's Banner)
consumables[176900] = 119221 -- Gladiator's Banner (Horde Gladiator's Banner)
consumables[176905] = 119216 -- Super Sticky Glitter Bomb
consumables[177154] = 119324 -- Savage Remedy
consumables[177206] = 119433 -- Path of the Void
consumables[177207] = 119432 -- Botani Camouflague (Botani Camouflage)
consumables[177214] = 119435 -- Path of Flame
consumables[177248] = 119439 -- Gut Punch (Personal Voodoo Doll)
consumables[177250] = 119440 -- Training Shoes
consumables[177257] = 119447 -- Training Wheels
consumables[177304] = 119449 -- Shadowberry Juice (Shadowberry)
consumables[178119] = 120182 -- Accelerated Learning (Excess Potion of Accelerated Learning)
consumables[178207] = 120257 -- Drums of Fury
consumables[178660] = 120349 -- Enduring Vial of Swiftness
consumables[179001] = 120857 -- Summon Barrel of Bandanas (Barrel of Bandanas)
consumables[179869] = 122120 -- Gaze of the Darkmoon
consumables[179872] = 122117 -- Twice-Cursed Arakkoa Feather (Cursed Feather of Ikzan)
consumables[179873] = 122121 -- Darkmoon Gazer
consumables[179880] = 122123 -- Fling Rings (Darkmoon Ring-Flinger)
consumables[179892] = 122122 -- Crashin' Thrashin' Tonk Controller (Darkmoon Tonk Controller)
consumables[179969] = 122128 -- Checkered Flag
consumables[180441] = 122283 -- Rukhmar's Sacred Memory
consumables[181642] = 122298 -- Bodyguard Miniaturization Device
consumables[181943] = 122293 -- Pepe (Trans-Dimensional Bird Whistle)
consumables[182226] = 122742 -- Bladebone Hook
consumables[182346] =  13379 -- Piccolo of the Flaming Fire
consumables[182665] = 123865 -- Aspect of Ursol (Relic of Ursol)
consumables[182723] = 123868 -- Aspect of Shakama (Relic of Shakama)
consumables[182724] = 123869 -- Aspect of Elune (Relic of Elune)
consumables[182993] = 123956 -- Leystone Hoofplates
consumables[183650] = 124072 -- Ward of Sargeras
consumables[183666] = 124071 -- Into the Shadows (Shadowstone)
consumables[183918] = 124093 -- Challenging the Blackfang! (Minor Blackfang Challenge Totem)
consumables[183973] = 124094 -- Challenging the Blackfang! (Major Blackfang Challenge Totem)
consumables[183975] = 124095 -- Challenging the Blackfang! (Prime Blackfang Challenge Totem)
consumables[184727] = 124506 -- Vial of Fel Cleansing
consumables[185464] = 124642 -- Supremacy Draught (Darkmoon Draught of Supremacy)
consumables[185470] = 124659 -- Supremacy Tincture (Darkmoon Tincture of Supremacy)
consumables[185471] = 124646 -- Flexibility Draught (Darkmoon Draught of Flexibility)
consumables[185472] = 124658 -- Flexibility Tincture (Darkmoon Tincture of Flexibility)
consumables[185474] = 124651 -- Deflection Draught (Darkmoon Draught of Deflection)
consumables[185475] = 124652 -- Deflection Tincture (Darkmoon Tincture of Deflection)
consumables[185476] = 124653 -- Deftness Tincture (Darkmoon Tincture of Deftness)
consumables[185477] = 124650 -- Deftness Draught (Darkmoon Draught of Deftness)
consumables[185478] = 124649 -- Defense Draught (Darkmoon Draught of Defense)
consumables[185479] = 124654 -- Defense Tincture (Darkmoon Tincture of Defense)
consumables[185480] = 124648 -- Divergence Draught (Darkmoon Draught of Divergence)
consumables[185481] = 124655 -- Divergence Tincture (Darkmoon Tincture of Divergence)
consumables[185482] = 124647 -- Alacrity Draught (Darkmoon Draught of Alacrity)
consumables[185483] = 124656 -- Alacrity Tincture (Darkmoon Tincture of Alacrity)
consumables[185484] = 124645 -- Precision Draught (Darkmoon Draught of Precision)
consumables[185485] = 124657 -- Precision Tincture (Darkmoon Tincture of Precision)
consumables[185562] = 124671 -- Darkmoon Firewater
consumables[185703] = 126934 -- Lemon Herb Filet
consumables[186530] = 127272 -- Rickety Glider
consumables[186842] = 127394 -- Podling Disguise (Podling Camouflage)
consumables[187146] = 127670 -- Tome of Secrets (Accursed Tome of the Sargerei)
consumables[187150] = 127668 -- Jewel of Hellfire
consumables[187349] = 127695 -- Spirit Shroud (Spirit Wand)
consumables[187399] = 127707 -- Indestructible Bone
consumables[187451] = 127669 -- Skull of the Mad Chief
consumables[187681] = 127768 -- Fel Petal
consumables[187935] = 127859 -- Dazzling Rod
consumables[188020] = 127838 -- Sylvan Elixir
consumables[188021] = 127839 -- Avalanche Elixir
consumables[188023] = 127840 -- Spirit Realm (Skaggldrynk)
consumables[188024] = 127841 -- Skystep Potion
consumables[188027] = 127843 -- Potion of Deadly Grace
consumables[188028] = 127844 -- Potion of the Old War
consumables[188029] = 127845 -- Unbending Potion
consumables[188030] = 127846 -- Leytorrent Potion
consumables[188031] = 127847 -- Flask of the Whispered Pact
consumables[188033] = 127848 -- Flask of the Seventh Demon
consumables[188034] = 127849 -- Flask of the Countless Armies
consumables[188035] = 127850 -- Flask of Ten Thousand Scars
consumables[188172] = 127864 -- Personal Spotlight
consumables[188228] = 127659 -- Ironbeard's Hat (Ghostly Iron Buccaneer's Hat)
consumables[188454] = 127987 -- WoW's 11th Anniversary (Celebration Package)
consumables[188756] = 127990 -- Distilled Essence of Zanzil
consumables[188769] = 127776 -- Candle Taker (Half-Melted Candle)
consumables[188904] = 128229 -- Felmouth Frenzy Bait
consumables[189363] = 128310 -- Burning Blade
consumables[189375] = 128312 -- Rapid Mind (Elixir of the Rapid Mind)
consumables[189561] = 128328 -- Skoller's Bag of Squirrel Treats
consumables[190337] = 128404 -- Helbrim's Special
consumables[190532] = 128437 -- Potion of Bubbling Pustules
consumables[190653] = 128462 -- Ceremonial Karabor Guise (Karabor Councilor's Attire)
consumables[190655] = 128471 -- Frostwolf Grunt's Battlegear
consumables[190824] = 128505 -- Murloc Costume (Celebration Wand - Murloc)
consumables[190826] = 128506 -- Gnoll Costume (Celebration Wand - Gnoll)
consumables[190837] = 128510 -- Exquisite VanCleef Costume (Exquisite Costume Set: "Edwin VanCleef")
consumables[190968] = 128634 -- Mysterious Brew
consumables[191176] = 128636 -- Endothermic Blaster
consumables[191194] = 128643 -- Exquisite Deathwing Costume (Exquisite Costume Set: "Deathwing")
consumables[191212] = 128647 -- Fizzy Apple Cider
consumables[191644] = 128708 -- Swiftness (Molted Feather)
consumables[191920] = 128768 -- Candy Cane
consumables[192225] = 128807 -- Coin of Many Faces
consumables[192233] = 128805 -- Potion of Fel Protection
consumables[192475] = 128875 -- Rotten Flank
consumables[192999] = 129093 -- Ravenbear Disguise
consumables[193287] = 129113 -- Visage of the Vrykul (Faintly Glowing Flagon of Mead)
consumables[193333] = 129149 -- Hellheim Spirit Memory (Death's Door Charm)
consumables[193345] = 129165 -- Barnacle-Encrusted Gem
consumables[193456] = 129192 -- Gaze of the Legion (Inquisitor's Menacing Eye)
consumables[193547] = 129210 -- Fel Crystal Infusion (Fel Crystal Fragments)
consumables[194076] = 129734 -- Potion of Cowardly Flight
consumables[194286] = 129758 -- Toughness (Reinforced Kodo Hide)
consumables[194481] = 129926 -- Mark of the Ashtongue
consumables[194807] = 129965 -- Grizzlesnout's Fang
consumables[194812] = 129929 -- Time-Lost Mirror (Ever-Shifting Mirror)
consumables[195386] = 130169 -- Tournament Favor
consumables[195427] = 129369 -- Convincing Critter Disguise
consumables[195461] = 130157 -- Syxsehnz Rod Effects (Syxsehnz Rod)
consumables[195503] = 130171 -- Gaze (Cursed Orb)
consumables[195509] = 130147 -- Thistleleaf Disguise (Thistleleaf Branch)
consumables[195806] = 130249 -- Waywatcher's Boon
consumables[195949] = 130158 -- Path of Elothir
consumables[196000] = 130259 -- True Rogue (Ancient Bandana)
consumables[196039] = 130260 -- Throw Poison (Thaedris's Elixir)
consumables[196067] = 130251 -- JewelCraft
consumables[196415] = 130898 -- Light in the Darkness
consumables[196420] = 130899 -- Sunstriding (Striding with the Sunwalkers)
consumables[196423] = 130900 -- Eternal Sacrifice (Sacrificing for Your Friends)
consumables[196759] = 131810 -- Derelict Skyhorn Kite
consumables[196768] = 131811 -- Rocfeather Skyhorn Kite
consumables[196783] = 131812 -- Crystal Growth (Darkshard Fragment)
consumables[196847] = 131900 -- Majesty of the Elderhorn (Majestic Elderhorn Hoof)
consumables[197373] = 132176 -- Thunder Special
consumables[197382] = 132178 -- Honed Weaponry (Battleguard's Sharpening Stone)
consumables[201072] = 133511 -- Gurboggle's Gleaming Bauble
consumables[201179] = 133542 -- Deathwing Simulator (Tosselwrench's Mega-Accurate Simulation Viewfinder)
consumables[201721] = 133911 -- Undersea Explorer Gear (Seafarer's Diving Gear)
consumables[201741] = 133688 -- Tugboat Bobber
consumables[201798] = 133888 -- Shortstalk Mushroom
consumables[201799] = 133889 -- Giantcap Mushroom
consumables[201800] = 133890 -- Stoneshroom
consumables[201801] = 133891 -- Wormstalk Mushroom
consumables[201803] = 133892 -- Floaty Fungus
consumables[201805] = 133702 -- Aromatic Murloc Slime
consumables[201806] = 133703 -- Pearlescent Conch
consumables[201807] = 133704 -- Rusty Queenfish Brooch
consumables[201809] = 133706 -- The Cat's Meow (Mossgill Bait)
consumables[201810] = 133707 -- Nightmare Nightcrawler
consumables[201811] = 133708 -- Drowned Thistleleaf
consumables[201813] = 133710 -- Salmon Lure
consumables[201815] = 133712 -- Frost Worm
consumables[201816] = 133713 -- Moosehorn Hook
consumables[201817] = 133714 -- Silverscale Minnow
consumables[201818] = 133715 -- Ancient Vrykul Ring
consumables[201819] = 133716 -- Soggy Drakescale
consumables[201820] = 133717 -- Enchanted Lure
consumables[201822] = 133720 -- Demonic Detritus
consumables[201823] = 133722 -- Axefish Lure
consumables[201976] = 138026 -- Reactivation (Empowered Charging Device)
consumables[202131] = 133795 -- Ravenous Flyfishing (Ravenous Fly)
consumables[202477] = 133984 -- Masquerade (Nightborne Disguise)
consumables[202850] = 133940 -- First Aid (Silkweave Bandage)
consumables[203441] = 133985 -- Heavy Drog
consumables[203443] = 133983 -- Mammoth Milk
consumables[203451] = 133987 -- Blue Drog
consumables[203491] = 133992 -- DrogLite
consumables[203501] = 133993 -- Jug of Drog
consumables[203533] = 133997 -- Black Icey Bling (Black Ice)
consumables[203657] = 134004 -- Noble's Elementium Signet Bling (Noble's Eternal Elementium Signet)
consumables[203689] = 134006 -- Caber Toss (Dwyer's Spare Caber)
consumables[203691] = 134008 -- Rosary of Light (Simple Rosary of Light)
consumables[203711] = 134021 -- Rocket Man (X-52 Rocket Helmet)
consumables[205522] = 134823 -- Field Dressing
consumables[205755] = 134831 -- "Guy Incognito" Costume
consumables[205798] = 134838 -- Ultra-Dense Energy Bar
consumables[206494] = 135503 -- Phial of Anaesthetic Gas
consumables[207695] = 136373 -- Can of Worms Bobber (Can O' Worms Bobber)
consumables[207696] = 136374 -- Toy Cat Head Bobber
consumables[207698] = 136375 -- Duck Bobber (Squeaky Duck Bobber)
consumables[207699] = 136376 -- Murloc Bobber
consumables[207700] = 136377 -- Oversized Bobber
consumables[208097] = { -- Image of Kalec
	136410, -- Kalec's Image Crystal
	138115, -- Kalec's Image Crystal
}
consumables[208705] = 131746 -- Stonehide Leather Barding
consumables[209563] = 136708 -- Demonsteel Stirrups
consumables[212198] = 137222 -- Crimson Vial
consumables[212400] = 137248 -- Hiro Brew
consumables[213258] = 137604 -- Unstable Riftstone
consumables[213325] = 129961 -- Flaming Hoop
consumables[213664] = 137648 -- Nimble Brew
consumables[214038] = 138033 -- Demonic Command (Scroll of Command)
consumables[214814] = 138202 -- Sparklepony XL
consumables[215329] = 138298 -- Inconspicuous Crate
consumables[215757] = 138400 -- Petey
consumables[215916] = 138414 -- Emergency Pirate Outfit
consumables[216528] = 138490 -- Waterspeaker's Blessing (Waterspeaker's Totem)
consumables[216876] = 138732 -- Empowering (History of the Blade)
consumables[217024] = 138785 -- Empowering (Adventurer's Resounding Glory)
consumables[217045] = 138781 -- Empowering (Brief History of the Aeons)
consumables[217055] = { -- Empowering
	138782, -- Brief History of the Ages
	141857, -- Soldier's Exertion
}
consumables[217299] = 138812 -- Empowering (Adventurer's Wisdom)
consumables[217300] = 138814 -- Empowering (Adventurer's Renown)
consumables[217301] = 138813 -- Empowering (Adventurer's Resounding Renown)
consumables[217355] = 138816 -- Empowering (Adventurer's Glory)
consumables[217461] = 138870 -- Spirit Spirits
consumables[217481] = 138871 -- Storming Saison
consumables[217489] = 138869 -- Gordok Bock
consumables[217498] = 138867 -- Shimmer Stout
consumables[217504] = 138868 -- Mannoroth's Blood Red Ale
consumables[217511] = { -- Empowering
	138864, -- Skirmisher's Advantage
	141858, -- Soldier's Worth
}
consumables[217512] = 138865 -- Empowering (Gladiator's Triumph)
consumables[217597] = 138873 -- Mystical Frosh Hat
consumables[217611] = 138874 -- Crackling Shards
consumables[217668] = 138878 -- Request the Master Call on You (Copy of Daglop's Contract)
consumables[217670] = 138880 -- Empowering (Soldier's Grit)
consumables[217671] = 138881 -- Empowering (Soldier's Glory)
consumables[217689] = 138886 -- Empowering (Favor of Valajar)
consumables[217708] = 138900 -- Gravil Goldbraid's Famous Sausage Hat
consumables[217835] = 138956 -- Hypermagnetic Lure
consumables[217836] = 138957 -- Auriphagic Sardine
consumables[217837] = 138958 -- Glob of Really Sticky Glue
consumables[217838] = 138959 -- Micro-Vortex Generator
consumables[217839] = 138960 -- Wish Crystal
consumables[217840] = 138961 -- Alchemical Bonding Agent
consumables[217842] = 138962 -- Starfish on a String
consumables[217844] = 138963 -- Tiny Little Grabbing Apparatus
consumables[217917] = 138990 -- Exquisite Grommash Costume (Exquisite Costume Set: "Grommash")
consumables[218861] = 139175 -- Arcane Lure
consumables[219159] = 139285 -- WoW's 12th Anniversary (Celebration Package)
consumables[220058] = 139459 -- Blessing of the Light
consumables[220110] = 139461 -- Shroud of Darkness (Rune of Darkness)
consumables[220273] = 139427 -- Wild Mana Wand
consumables[220335] = 139451 -- Void Infused (Swirling Void Potion)
consumables[220356] = 139452 -- Essence of the Light
consumables[220485] = 139500 -- Slow Fall (Hippogryph Feather)
consumables[220510] = 139503 -- Bloodtotem Saddle Blanket
consumables[220547] = 140322 -- Empowering (Trainer's Insight)
consumables[220548] = 139609 -- Empowering (Depleted Cadet's Wand)
consumables[220549] = 139510 -- Empowering (Black Rook Soldier's Insignia)
consumables[220550] = 139613 -- Empowering (Tale-Teller's Staff)
consumables[220551] = 141710 -- Empowering (Discontinued Suramar City Key)
consumables[220553] = 141709 -- Empowering (Ancient Champion Effigy)
consumables[220584] = 139536 -- Emanation of the Winds
consumables[220645] = 139546 -- Twisting Anima of Souls
consumables[220651] = 139547 -- Runes of the Darkening
consumables[220655] = 139548 -- The Bonereaper's Hook
consumables[220658] = 139549 -- Guise of the Deathwalker
consumables[220662] = 139550 -- Bulwark of the Iron Warden
consumables[220663] = 139551 -- The Sunbloom
consumables[220664] = 139592 -- Slick Shoes (Smoky Boots)
consumables[220670] = 139552 -- Feather of the Moonspirit
consumables[220676] = 139553 -- Mark of the Glade Guardian
consumables[220679] = 139554 -- Acorn of the Endless
consumables[220681] = 139555 -- Designs of the Grand Architect
consumables[220683] = 139556 -- Syriel Crescentfall's Notes: Ravenguard
consumables[220684] = 139557 -- Last Breath of the Forest
consumables[220688] = 139558 -- The Woolomancer's Charge
consumables[220690] = 139559 -- The Stars' Design
consumables[220691] = 139560 -- Everburning Crystal
consumables[220692] = 139561 -- Legend of the Monkey King
consumables[220693] = 139562 -- Breath of the Undying Serpent
consumables[220694] = 139563 -- The Stormfist
consumables[220696] = 139564 -- Lost Secrets of the Watcher (Lost Edicts of the Watcher)
consumables[220699] = 139565 -- Spark of the Fallen Exarch
consumables[220701] = 139566 -- Heart of Corruption
consumables[220703] = 139567 -- Writings of the End
consumables[220705] = 139568 -- Staff of the Lightborn
consumables[220706] = 139569 -- Claw of N'Zoth
consumables[220708] = 139570 -- The Cypher of Broken Bone
consumables[220709] = 139571 -- Tome of Otherworldly Venoms
consumables[220710] = 139572 -- Lost Codex of the Amani
consumables[220712] = 139573 -- The Warmace of Shirvallah
consumables[220715] = 139574 -- Coil of the Drowned Queen
consumables[220718] = 139575 -- Rite of the Executioner (Essence of the Executioner)
consumables[220724] = 139576 -- Visage of the First Wakener
consumables[220729] = 139577 -- The Burning Jewel of Sargeras
consumables[220731] = 139578 -- Strom'kar, the Bladebreaker (The Arcanite Bladebreaker)
consumables[220732] = 139579 -- The Dragonslayers
consumables[220734] = 139580 -- Burning Blood of the Worldbreaker (Burning Plate of the Worldbreaker)
consumables[220856] = 139587 -- Suspicious Crate
consumables[220931] = 139584 -- Sticky Bomb (Sticky Bombs)
consumables[221526] = 140253 -- Swiftpad Brew
consumables[221543] = 140256 -- Skysinger Brew
consumables[221544] = 140287 -- Stoutheart Brew
consumables[221545] = 140288 -- Bubblebelly Brew
consumables[221547] = 140289 -- Lungfiller Brew
consumables[221548] = 140290 -- Seastrider Brew
consumables[221549] = 140291 -- Featherfoot Brew
consumables[221550] = 140292 -- Tumblerun Brew
consumables[221558] = 140295 -- Badgercharm Brew
consumables[221777] = 128979 -- Writing a Legend (Unwritten Legend)
consumables[222630] = 140160 -- Stormforged Vrykul Horn
consumables[222907] = 140231 -- Narcissa's Mirror
consumables[223143] = 140309 -- Prismatic Bauble
consumables[223303] = 140314 -- Crab Shank
consumables[223446] = 140325 -- Home-Made Party Mask (Home Made Party Mask)
consumables[223497] = 140331 -- Skyhorn War Harness
consumables[223498] = 140332 -- Rivermane War Harness
consumables[223499] = 140333 -- Bloodtotem War Harness
consumables[223500] = 140334 -- Highmountain War Harness
consumables[223602] = 140352 -- Dreamberries
consumables[223722] = 140439 -- Sunblossom Pollen
consumables[223753] = 140452 -- Crest of Heroism
consumables[223754] = 140453 -- Crest of Carnage
consumables[223755] = 140454 -- Crest of Devastation
consumables[223756] = 140455 -- Crest of Heroism
consumables[223757] = 140456 -- Crest of Carnage
consumables[223758] = 140457 -- Crest of Devastation
consumables[224001] = 140587 -- Defiled Augmentation (Defiled Augment Rune)
consumables[224992] = 140780 -- Projection of a future Fal'dorei (Fal'dorei Egg)
consumables[225428] = 141013 -- Town Portal: Shala'nir (Scroll of Town Portal: Shala'nir)
consumables[225434] = 141014 -- Town Portal: Sashj'tar (Scroll of Town Portal: Sashj'tar)
consumables[225435] = 141015 -- Town Portal: Kal'delar (Scroll of Town Portal: Kal'delar)
consumables[225436] = 141016 -- Town Portal: Faronaar (Scroll of Town Portal: Faronaar)
consumables[225440] = 141017 -- Town Portal: Lian'tril (Scroll of Town Portal: Lian'tril)
consumables[225798] = 141295 -- Extra Thick Mojo
consumables[225823] = 141298 -- Displacement (Displacer Meditation Stone)
consumables[225826] = 141300 -- Arcane Beam (Magi Focusing Crystal)
consumables[225832] = 141306 -- Nightglow Wisp (Wisp in a Bottle)
consumables[225897] = 141310 -- Empowering (Falanaar Crescent)
consumables[226175] = 141331 -- Vial of Green Goo
consumables[226267] = 141334 -- Mighty Mess Remover
consumables[226277] = 130897 -- Divine Miracle (Miracles and You)
consumables[226322] = 141958 -- Soul Flame of Fortification
consumables[226325] = 141959 -- Soul Flame of Alacrity
consumables[226326] = 141960 -- Soul Flame of Insight
consumables[226327] = 141961 -- Soul Flame of Rejuvenation
consumables[226329] = 141962 -- Soul Flame of Castigation
consumables[226779] = 140460 -- Empowering (Thisalee's Fighting Claws)
consumables[227531] = 141638 -- Empowering (Falanaar Scepter)
consumables[227535] = 141639 -- Empowering (Falanaar Orb)
consumables[227886] = 141708 -- Empowering (Curio of Neltharion)
consumables[227889] = 141706 -- Empowering (Carved Oaken Windchimes)
consumables[227904] = 141690 -- Empowering (Symbol of Victory)
consumables[227905] = 141689 -- Empowering (Jewel of Victory)
consumables[227907] = 138786 -- Empowering (Talisman of Victory)
consumables[227941] = 139608 -- Empowering (Brittle Spelltome)
consumables[227942] = { -- Empowering
	141702, -- Spoiled Manawine Dregs
	141956, -- Rotten Spellbook
}
consumables[227943] = 139610 -- Empowering (Musty Azsharan Grimoire)
consumables[227944] = 141707 -- Empowering (Smuggled Magical Supplies)
consumables[227945] = 139611 -- Empowering (Primitive Roggtotem)
consumables[227946] = 141703 -- Empowering (Witch-Harpy Talon)
consumables[227947] = 139612 -- Empowering (Highmountain Mystic's Totem)
consumables[227948] = 139615 -- Empowering (Untapped Mana Gem)
consumables[227949] = 139616 -- Empowering (Dropper of Nightwell Liquid)
consumables[227950] = 141711 -- Empowering (Ancient Druidic Carving)
consumables[228067] = 140176 -- Empowering (Accolade of Victory)
consumables[228069] = 141701 -- Empowering (Selfless Glory)
consumables[228077] = 141699 -- Empowering (Boon of the Companion)
consumables[228078] = 141852 -- Empowering (Accolade of Heroism)
consumables[228079] = 141853 -- Empowering (Accolade of Myth)
consumables[228080] = 141854 -- Empowering (Accolade of Achievement)
consumables[228106] = 139512 -- Empowering (Sigilstone of Tribute)
consumables[228107] = 139511 -- Empowering (Hallowed Runestone)
consumables[228108] = 141704 -- Empowering (Forgotten Offering)
consumables[228109] = 139507 -- Empowering (Cracked Vrykul Insignia)
consumables[228110] = 141705 -- Empowering (Disorganized Ravings)
consumables[228111] = 139509 -- Empowering (Worldtree Bloom)
consumables[228112] = 139508 -- Empowering (Dried Worldtree Seeds)
consumables[228130] = 141855 -- Empowering (History of the Aeons)
consumables[228131] = 141856 -- Empowering (History of the Ages)
consumables[228135] = 141859 -- Empowering (Soldier's Splendor)
consumables[228140] = 141862 -- Observing the Cosmos (Mote of Light)
consumables[228220] = 141872 -- Empowering (Artisan's Handiwork)
consumables[228290] = 141879 -- Personal Egg (Berglrgl Perrgl Girggrlf)
consumables[228310] = { -- Empowering
	141883, -- Azsharan Keepsake
	141886, -- Crackling Dragonscale
	141887, -- Lucky Brulstone
	141888, -- Discarded Aristocrat's Censer
	141890, -- Petrified Acorn
}
consumables[228323] = 141884 -- Krota's Shield
consumables[228352] = 141889 -- Empowering (Glory of the Melee)
consumables[228422] = { -- Empowering
	139614, -- Azsharan Manapearl
	141930, -- Smolderhide Spirit Beads
}
consumables[228423] = 139617 -- Empowering (Ancient Warden Manacles)
consumables[228436] = 141921 -- Empowering (Dessicated Blue Dragonscale)
consumables[228437] = { -- Empowering
	141922, -- Brulstone Fishing Sinker
	141929, -- Hippogryph Plumage
}
consumables[228438] = 141923 -- Empowering (Petrified Axe Haft)
consumables[228439] = { -- Empowering
	141924, -- Broken Control Mechanism
	141928, -- Reaver's Harpoon Head
}
consumables[228440] = 141925 -- Empowering (Pruned Nightmare Shoot)
consumables[228442] = { -- Empowering
	141926, -- Druidic Molting
	141931, -- Tattered Farondis Heraldry
}
consumables[228443] = 141927 -- Empowering (Burrowing Worm Mandible)
consumables[228444] = 141932 -- Empowering (Shard of Compacted Energy)
consumables[228483] = 141964 -- Flaming Demonheart
consumables[228484] = 141965 -- Shadowy Demonheart
consumables[228485] = 141966 -- Coercive Demonheart
consumables[228486] = 141967 -- Whispering Demonheart
consumables[228487] = 141968 -- Immense Demonheart
consumables[228647] = { -- Empowering
	142001, -- Antler of Cenarius
	142002, -- Dragonscale of the Earth Aspect
	142003, -- Talisman of the Ascended
	142004, -- Nar'thalas Research Tome
	142005, -- Vial of Diluted Nightwell Liquid
	142006, -- Ceremonial Warden Glaive
	142007, -- Omnibus: The Schools of Arcane Magic
}
consumables[228921] = 141024 -- Empowering (Seal of Leadership)
consumables[228955] = 140310 -- Empowering (Crude Statuette)
consumables[228956] = 138783 -- Empowering (Glittering Memento)
consumables[228957] = { -- Empowering
	130152, -- Condensed Light of Elune
	131751, -- Fractured Portal Shard
	131753, -- Prayers to the Earthmother
	131763, -- Bundle of Trueshot Arrows
	131795, -- Nar'thalasian Corsage
	132950, -- Petrified Snake
	138885, -- Treasure of the Ages
	141892, -- Gilbert's Finest
}
consumables[228959] = { -- Empowering
	131802, -- Offering to Ram'Pag
	132897, -- Mandate of the Watchers
	141891, -- Branch of Shaladrassil
	141896, -- Nashal's Spyglass
}
consumables[228960] = 138839 -- Empowering (Valiant's Glory)
consumables[228961] = { -- Empowering
	131808, -- Engraved Bloodtotem Armlet
	140685, -- Enchanted Sunrunner Kidney
	141876, -- Soul-Powered Containment Unit
}
consumables[228962] = { -- Empowering
	140372, -- Ancient Artificer's Manipulator
	140381, -- Jandvick Jarl's Ring, and Finger
	140386, -- Inquisitor's Shadow Orb
	140388, -- Falanaar Gemstone
	140396, -- Friendly Brawler's Wager
	141877, -- Coura's Ancient Scepter
}
consumables[228963] = 140384 -- Empowering (Azsharan Court Scepter)
consumables[228964] = 141023 -- Empowering (Seal of Victory)
consumables[229746] = { -- Empowering
	138784, -- Questor's Glory
	141383, -- Crystallized Moon Drop
	141384, -- Emblem of the Dark Covenant
	141385, -- Tidestone Sliver
	141386, -- Giant Pearl Scepter
	141387, -- Emerald Bloom
	141388, -- Warden's Boon
	141389, -- Stareye Gem
	141390, -- The Corruptor's Totem
	141391, -- Ashildir's Unending Courage
	141392, -- Fragment of the Soulcage
	141393, -- Onyx Arrowhead
	141394, -- Plume of the Great Eagle
	141395, -- Stonedark's Pledge
	141396, -- The River's Blessing
	141397, -- The Spiritwalker's Wisdom
	141398, -- Blessing of the Watchers
	141399, -- Overcharged Stormscale
	141400, -- Underking's Fist
	141401, -- Renewed Lifeblood
	141402, -- Odyn's Watchful Gaze
	141403, -- Tablet of Tyr
	141404, -- Insignia of the Second Command
	141405, -- Senegos' Favor
}
consumables[229747] = 139413 -- Empowering (Greater Questor's Glory)
consumables[229776] = 139506 -- Empowering (Greater Glory of the Order)
consumables[229778] = { -- Empowering
	140349, -- Spare Arcane Ward
	142054, -- Enchanted Nightborne Coin
}
consumables[229779] = { -- Empowering
	140238, -- Scavenged Felstone
	140241, -- Enchanted Moonfall Text
	140252, -- Tel'anor Ancestral Tablet
	140847, -- Ancient Workshop Focusing Crystal
	141668, -- The Arcanist's Codex
	141670, -- Arcane Trap Power Core
	141671, -- Moon Guard Focusing Stone
	141672, -- Insignia of the Nightborne Commander
	141674, -- Brand of a Blood Brother
	141675, -- Deepwater Blossom
	141933, -- Citrine Telemancy Index
	141935, -- Enchrgled Mlrgmlrg of Enderglment
	141940, -- Starsong's Bauble
	141943, -- Moon Guard Power Gem
	141944, -- Empowered Half-Shell
	141945, -- Magically-Fortified Vial
	141946, -- Trident of Sashj'tar
	141947, -- Mark of Lunastre
	141948, -- Token of a Master Cultivator
	141949, -- Everburning Arcane Glowlamp
}
consumables[229780] = { -- Empowering
	140237, -- Iadreth's Enchanted Birthstone
	140244, -- Jandvick Jarl's Pendant Stone
	140247, -- Mornath's Enchanted Statue
	140250, -- Ingested Legion Stabilizer
	141673, -- Love-Laced Arrow
	141936, -- Petrified Fel-Heart
	141941, -- Crystallized Sablehorn Antler
	141942, -- Managazer's Petrifying Eye
}
consumables[229781] = 140517 -- Empowering (Glory of the Order)
consumables[229782] = { -- Empowering
	141313, -- Manafused Fal'dorei Egg Sac
	141314, -- Treemender's Beacon
}
consumables[229783] = { -- Empowering
	138480, -- Black Harvest Tome
	138487, -- Shinfel's Staff of Torment
	140364, -- Frostwyrm Bone Fragment
	140365, -- Dried Stratholme Lily
	140366, -- Scarlet Hymnal
	140367, -- Tattered Sheet Music
	140368, -- Tarnished Engagement Ring
	140377, -- Broken Medallion of Karabor
	140379, -- Broken Warden Glaive Blade
	140380, -- Swiftflight's Tail Feather
	140382, -- Tiny War Drum
	140383, -- Glowing Cave Mushroom
	140385, -- Legion Pamphlet
	140459, -- Moon Lily
	140461, -- Battered Trophy
	140462, -- Draketaming Spurs
	140463, -- Broken Eredar Blade
	140466, -- Corroded Eternium Rose
	140467, -- Fel-Infused Shell
	140468, -- Eagle Eggshell Fragment
	140469, -- Felslate Arrowhead
	140470, -- Ancient Gilnean Locket
	140473, -- Night-forged Halberd
	140474, -- Nar'thalas Pottery Fragment
	140475, -- Morning Glory Vine
	140476, -- Astranaar Globe
	140477, -- Inert Ashes
	140484, -- Well-Used Drinking Horn
	140485, -- Duskpelt Fang
	140486, -- Storm Drake Scale
	140487, -- War-Damaged Vrykul Helmet
	140488, -- Huge Blacksmith's Hammer
	140497, -- Bundle of Tiny Spears
	140503, -- Blank To-Do List
	140504, -- Kvaldir Anchor Line
	140505, -- Sweaty Bandanna
	140507, -- Unlabeled Potion
	140508, -- Nightborne Artificer's Ring
	140516, -- Elemental Bracers
	140518, -- Bottled Lightning
	140519, -- Whispering Totem
	140520, -- Amethyst Geode
}
consumables[229784] = { -- Empowering
	140357, -- Fel Lava Rock
	140358, -- Eredar Armor Clasp
	140359, -- Darkened Eyeball
	140361, -- Pulsating Runestone
	140369, -- Scrawled Recipe
	140370, -- Amber Shard
	140371, -- Letter from Exarch Maladaar
	140373, -- Ornamented Boot Strap
	140374, -- Jagged Worgen Fang
	140387, -- Bracer Gemstone
	140389, -- Petrified Flame
	140391, -- Argussian Diamond
	140392, -- Safety Valve
	140393, -- Repentia's Whip
	140471, -- Lord Shalzaru's Relic
	140478, -- Painted Bark
	140479, -- Broken Legion Communicator
	140480, -- Drained Construct Core
	140481, -- Shimmering Hourglass
	140482, -- Storm Drake Fang
	140489, -- Ettin Toe Ring
	140490, -- Wooden Snow Shoes
	140491, -- Stolen Pearl Ring
	140492, -- Gleaming Glacial Pebble
	140494, -- Eredar Tail-Cuff
	140498, -- Legion Admirer's Note
	140509, -- Demon-Scrawled Drawing
	140510, -- Iron Black Rook Hold Key
	140511, -- Soul Shackle
	140512, -- Oversized Drinking Mug
	140521, -- Fire Turtle Shell Fragment
	140522, -- Petrified Spiderweb
	140523, -- Crimson Cavern Mushroom
	140524, -- Sharp Twilight Tooth
	140525, -- Obsidian Mirror
	140528, -- Dalaran Wine Glass
	140529, -- Felstalker's Ring
	140530, -- Opalescent Shell
	140531, -- Ravencrest Family Seal
	140532, -- Inscribed Vrykul Runestone
}
consumables[229785] = { -- Empowering
	141667, -- Ancient Keeper's Brooch
	141677, -- Key to the Bazaar
	141679, -- Cobalt Amber Crystal
	141950, -- Arcane Seed Case
}
consumables[229786] = { -- Empowering
	140251, -- Purified Satyr Totem
	140254, -- The Seawarden's Beacon
	141937, -- Eredari Ignition Crystal
}
consumables[229787] = 141669 -- Empowering (Fel-Touched Tome)
consumables[229788] = { -- Empowering
	141951, -- Spellbound Jewelry Box
	141952, -- Delving Deeper by Arcanist Perclanea
}
consumables[229789] = 140304 -- Empowering (Activated Essence)
consumables[229790] = 140305 -- Empowering (Brimming Essence)
consumables[229791] = 140306 -- Empowering (Mark of the Valorous)
consumables[229792] = 140307 -- Empowering (Heart of Zin-Azshari)
consumables[229793] = 140409 -- Empowering (Tome of Dimensional Awareness)
consumables[229794] = { -- Empowering
	140410, -- Mark of the Rogues
	141676, -- The Valewatcher's Boon
	141953, -- Nightglow Energy Vessel
}
consumables[229795] = { -- Empowering
	141678, -- Night Devint: The Perfection of Arcwine
	141954, -- 'Borrowed' Highborne Magi's Chalice
}
consumables[229796] = { -- Empowering
	141680, -- Titan-Forged Locket
	141955, -- Corupted Duskmere Crest
}
consumables[229798] = 140422 -- Empowering (Moonglow Idol)
consumables[229799] = 140421 -- Empowering (Ancient Qiraji Idol)
consumables[229803] = { -- Empowering
	141682, -- Free Floating Ley Spark
	141683, -- Mana-Injected Chronarch Power Core
}
consumables[229804] = { -- Empowering
	140445, -- Arcfruit
	141684, -- Residual Manastorm Energy
}
consumables[229805] = 140444 -- Empowering (Dream Tear)
consumables[229806] = 141685 -- Empowering (The Valewalker's Blessing)
consumables[229807] = 141863 -- Empowering (Daglop's Precious)
consumables[229857] = 141934 -- Empowering (Partially Enchanted Nightborne Coin)
consumables[229858] = 140255 -- Empowering (Enchanted Nightborne Coin)
consumables[229859] = 141681 -- Empowering (Valewalker Talisman)

LibStub('LibItemBuffs-1.0'):__UpgradeDatabase(version, trinkets, consumables, enchantments)
