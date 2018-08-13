local AtlasLoot = _G.AtlasLoot
local AceGUI = LibStub("AceGUI-3.0")
local AL = AtlasLoot.Locales
local ALIL = AtlasLoot.IngameLocales

local Dev = {}
-- /////////////////////////////////////////////////////////////////////////
AtlasLoot.Dev = Dev

local EJ_DIFFICULTIES =  
{
	{ size = "5", prefix = PLAYER_DIFFICULTY1, difficultyID = 1 },
	{ size = "5", prefix = PLAYER_DIFFICULTY2, difficultyID = 2 },
	{ size = "5", prefix = PLAYER_DIFFICULTY6, difficultyID = 23 },
	{ size = "5", prefix = PLAYER_DIFFICULTY_TIMEWALKER, difficultyID = 24 },
	{ size = "25", prefix = PLAYER_DIFFICULTY3, difficultyID = 7 },
	{ size = "10", prefix = PLAYER_DIFFICULTY1, difficultyID = 3 },
	{ size = "10", prefix = PLAYER_DIFFICULTY2, difficultyID = 5 },
	{ size = "25", prefix = PLAYER_DIFFICULTY1, difficultyID = 4 },
	{ size = "25", prefix = PLAYER_DIFFICULTY2, difficultyID = 6 },
	{ prefix = PLAYER_DIFFICULTY3, difficultyID = 17 },
	{ prefix = PLAYER_DIFFICULTY1, difficultyID = 14 },
	{ prefix = PLAYER_DIFFICULTY2, difficultyID = 15 },
	{ prefix = PLAYER_DIFFICULTY6, difficultyID = 16 },
}

function AtlasLoot:DEV_ScanEJ(givenTierId)
	self.db.DEV_ScanEJ = {}
	local db = self.db.DEV_ScanEJ
	if EncounterJournal then
		EncounterJournal:UnregisterEvent("EJ_DIFFICULTY_UPDATE")
	end
	
	for tier = 1,EJ_GetNumTiers() do		-- scan tiers Classic, bc, ...
		if givenTierId and givenTierId ~= tier then
			-- Do nothing
		else
			EJ_SelectTier(tier)
			local tierName = EJ_GetTierInfo(tier)
			db[tierName] = {
				info = {
					tierID = tier,
				},
				dungeons = {},
				raids = {},
			}
			local loopKill = 0
			local showRaid = false
			local index = 1
			local instanceID, name, description, bgImage, buttonImage, loreImage, dungeonAreaMapID, link
			while true do
				loopKill = loopKill + 1
				if loopKill > 700 then print"ouch loop break" break end
				instanceID, name, description, bgImage, buttonImage, loreImage, dungeonAreaMapID, link = EJ_GetInstanceByIndex(index, showRaid)
				if not instanceID and showRaid then	
					break
				elseif not instanceID then
					index = 1
					showRaid = true
				else
					local curDb = showRaid and db[tierName].raids or db[tierName].dungeons
					
					curDb[name] = {
						info = {
							instanceID = instanceID,
							name = name,
							description = description,
							bgImage = bgImage,
							buttonImage = buttonImage,
							loreImage = loreImage,
							dungeonAreaMapID = dungeonAreaMapID,
							MapID = link,
						},
						bosses = {},
					}
					curDb = curDb[name].bosses
					
					EJ_SelectInstance(instanceID)	-- select instance..
					
					local bossIndex = 1
					local encounterName, encounterDescription, encounterID, rootSectionID, encounterLink = EJ_GetEncounterInfoByIndex(bossIndex)
					local loopProtectEncount = 0
					
					while encounterID do
						loopProtectEncount = loopProtectEncount +1
						if loopProtectEncount > 500 then print("ouch encounterLoop break"..loopProtectEncount) break end
						EJ_SelectEncounter(encounterID)
						curDb[encounterName] = {
							info = {
								name = encounterName,
								description = description,
								encounterID = encounterID,
								rootSectionID = rootSectionID,
								link = link,
							},
							items = {},
						}
						for diffIndex = 1,#EJ_DIFFICULTIES do
							local entry = EJ_DIFFICULTIES[diffIndex];
							if EJ_IsValidInstanceDifficulty(entry.difficultyID) then
								EJ_SetDifficulty(entry.difficultyID)
								local diffName, groupType, isHeroic, isChallengeMode, displayHeroic, displayMythic, toggleDifficultyID = GetDifficultyInfo(entry.difficultyID)
								curDb[encounterName].items[diffName] = {}
								--print(diffName, groupType, isHeroic, isChallengeMode, displayHeroic, displayMythic, toggleDifficultyID)
								local lootDb = curDb[encounterName].items[diffName] 
								local itemName, _, itemID
								for itemIndex = 1, EJ_GetNumLoot() do
									itemID, _, itemName	= EJ_GetLootInfoByIndex(itemIndex)
									if itemID then
										lootDb[itemID] = itemName
										print(itemName)
									end
								end
							end
						end
						
						bossIndex = bossIndex + 1
						encounterName, encounterDescription, encounterID, rootSectionID, encounterLink = EJ_GetEncounterInfoByIndex(bossIndex)
					end
					
					index = index +1
				end
				
				
			end

		end
	end
	
	if EncounterJournal then
		EncounterJournal:RegisterEvent("EJ_DIFFICULTY_UPDATE")
	end
end
--[[
local db 
local ORIGetItemInfo = GetItemInfo
function GetItemInfo(xxx)
	if not db then 
		if not AtlasLoot.db.itemInfo then
			AtlasLoot.db.itemInfo = {}
		end
		db = AtlasLoot.db.itemInfo
	end
	local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemCount, itemEquipLoc, itemTexture, vendorPrice = ORIGetItemInfo(xxx)
	if itemSubType and itemType then
		if not db[itemType] then
			db[itemType] = {}
		end
		db[itemType][itemSubType] = true
	end
	if itemEquipLoc then
		if not db.slot then db.slot = {} end
		db[itemEquipLoc] = nil
		db.slot[itemEquipLoc] = true
	end
	return itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemCount, itemEquipLoc, itemTexture, vendorPrice
end
]]--

-- ################
-- DEV !!! remove later only for tests
-- ################
local GUIDS = {
	["Player-1097-040A43FC"] = "author",	-- shijera@ysera-eu
	["Player-1097-0444710C"] = "author",	-- lag@ysera-eu
	["Player-1097-044F8D64"] = "author",
	["Player-1097-047418F7"] = "author",	-- schoko!
	["Player-1097-045D6B65"] = "author", 	-- Cali
	[true] = "Player-1097-00490D06",		-- meena@ysera-eu
	[true] = "Player-1097-0212CAC6",		-- xyriana@ysera-eu
	["Player-612-0566C578"] = "author",		-- Dynaletik@nerathor-eu
	["Player-612-05667280"] = "author",		-- Dynarix@nerathor-eu
	["Player-612-0566725A"] = "author",		-- Dynalowtik@nerathor-eu
}
local AUTHOR_STRING = "AtlasLoot Author |TInterface\\MoneyFrame\\UI-GoldIcon:0|t"
local FRIEND_STRING = "AtlasLoot Friend |TInterface\\MoneyFrame\\UI-SilverIcon:0|t"
function hookUnitTarget(self)
	local name, unit = self:GetUnit()
	if name and unit then
		local guid = UnitGUID(unit)
		if guid and GUIDS[guid] then
			self:AddLine(GUIDS[guid] == "author" and AUTHOR_STRING or FRIEND_STRING, 0, 1, 0 )
		end
	end
end
GameTooltip:HookScript("OnTooltipSetUnit", hookUnitTarget)
-- /////////////////////////////////////////////////////////////////////////
local AtlasLoot_TextParsing = {
--[[
	-- Classes
	{ "#c1#", LOCALIZED_CLASS_NAMES_MALE["DRUID"] },
	{ "#c2#", LOCALIZED_CLASS_NAMES_MALE["HUNTER"] },
	{ "#c3#", LOCALIZED_CLASS_NAMES_MALE["MAGE"] },
	{ "#c4#", LOCALIZED_CLASS_NAMES_MALE["PALADIN"] },
	{ "#c5#", LOCALIZED_CLASS_NAMES_MALE["PRIEST"] },
	{ "#c6#", LOCALIZED_CLASS_NAMES_MALE["ROGUE"] },
	{ "#c7#", LOCALIZED_CLASS_NAMES_MALE["SHAMAN"] },
	{ "#c8#", LOCALIZED_CLASS_NAMES_MALE["WARLOCK"] },
	{ "#c9#", LOCALIZED_CLASS_NAMES_MALE["WARRIOR"] },
	{ "#c10#", LOCALIZED_CLASS_NAMES_MALE["DEATHKNIGHT"] },
	{ "#c11#", LOCALIZED_CLASS_NAMES_MALE["MONK"] },

	-- Professions
	{ "#p1#", GetSpellInfo(2259) },		-- Alchemy
	{ "#p2#", GetSpellInfo(2018) },		-- Blacksmithing
	{ "#p3#", GetSpellInfo(2550) },		-- Cooking
	{ "#p4#", GetSpellInfo(7411) },		-- Enchanting
	{ "#p5#", GetSpellInfo(4036) },		-- Engineering
	{ "#p6#", GetSpellInfo(3273) },		-- First Aid
	{ "#p7#", GetSpellInfo(2108) },		-- Leatherworking
	{ "#p8#", GetSpellInfo(3908) },		-- Tailoring
	{ "#p9#", GetSpellInfo(10656) },	-- Dragonscale Leatherworking
	{ "#p10#", GetSpellInfo(10660) },	-- Tribal Leatherworking
	{ "#p11#", GetSpellInfo(10658) },	-- Elemental Leatherworking
	{ "#p12#", GetSpellInfo(25229) },	-- Jewelcrafting
	{ "#p13#", GetSpellInfo(9788) },	-- Armorsmith
	{ "#p14#", GetSpellInfo(17041) },	-- Master Axesmith
	{ "#p15#", GetSpellInfo(17039) },	-- Master Swordsmith
	{ "#p16#", GetSpellInfo(9787) },	-- Weaponsmith
	{ "#p17#", GetSpellInfo(20220) },	-- Gnomish Engineering
	{ "#p18#", GetSpellInfo(20221) },	-- Goblin Engineering
	{ "#p19#", GetSpellInfo(26798) },	-- Mooncloth Tailoring
	{ "#p20#", GetSpellInfo(26801) },	-- Shadoweave Tailoring
	{ "#p21#", GetSpellInfo(26797) },	-- Spellfire Tailoring
	{ "#p22#", GetSpellInfo(17040) },	-- Master Hammersmith
	{ "#p23#", GetSpellInfo(2575) },	-- Mining
	{ "#p24#", GetSpellInfo(63275) },	-- Fishing
	{ "#p25#", GetSpellInfo(78670) },	-- Archaeology
	{ "#p26#", GetSpellInfo(45357) },	-- Inscription
	{ "#p27#", GetSpellInfo(2366) },	-- Herbalism
	{ "#p28#", GetSpellInfo(921) },		-- Pick Pocket
	
	-- Reputation
	{ "#r1#", "Neutral" },
	{ "#r2#", "Friendly" },
	{ "#r3#", "Honored" },
	{ "#r4#", "Revered" },
	{ "#r5#", "Exalted" },

	-- Armour Class
	{ "#a1#", "Cloth" },
	{ "#a2#", "Leather" },
	{ "#a3#", "Mail" },
	{ "#a4#", "Plate" },

	-- Body Slot
	{ "#s1#", "Head" },
	{ "#s2#", "Neck" },
	{ "#s3#", "Shoulder" },
	{ "#s4#", "Back" },
	{ "#s5#", "Chest" },
	{ "#s6#", "Shirt" },
	{ "#s7#", "Tabard" },
	{ "#s8#", "Wrist" },
	{ "#s9#", "Hands" },
	{ "#s10#", "Waist" },
	{ "#s11#", "Legs" },
	{ "#s12#", "Feet" },
	{ "#s13#", "Ring" },
	{ "#s14#", "Trinket" },
	{ "#s15#", "Held in Off-Hand" },

	-- Weapon Wielding
	{ "#h1#", "One-Hand" },
	{ "#h2#", "Two-Hand" },
	{ "#h3#", "Main Hand" },
	{ "#h4#", "Off Hand" },

	-- Weapon Type
	{ "#w1#", "Axe" },
	{ "#w2#", "Bow" },
	{ "#w3#", "Crossbow" },
	{ "#w4#", "Dagger" },
	{ "#w5#", "Gun" },
	{ "#w6#", "Mace" },
	{ "#w7#", "Polearm" },
	{ "#w8#", "Shield" },
	{ "#w9#", "Staff" },
	{ "#w10#", "Sword" },
	{ "#w12#", "Wand" },
	{ "#w13#", "Fist Weapon" },

	-- Misc Inventory related words
	{ "#e1#", "Bag" },
	{ "#e2#", "Potion" },
	{ "#e3#", "Food" },
	{ "#e4#", "Drink" },
	{ "#e5#", "Bandage" },
	{ "#e6#", "Trade Goods" },
	{ "#e7#", "Gem" },
	{ "#e8#", "Reagent" },
	{ "#e9#", "Key" },
	{ "#e10#", "Book" },
	{ "#e11#", "Scope" },
	{ "#e12#", "Mount" },
	{ "#e13#", "Companion" },
	{ "#e14#", "Banner" },
	{ "#e15#", "Token" },
	{ "#e16#", "Darkmoon Faire Card" },
	{ "#e17#", "Enchant" },
	{ "#e18#", "Consumable" },
	{ "#e20#", "Fishing Pole" },
	{ "#e21#", "Fish" },
	{ "#e22#", "Combat Pet" },
	{ "#e23#", "Fireworks" },
	{ "#e24#", "Fishing Lure" },
	{ "#e25#", "Transformation Item" },
	{ "#e26#", "Ground Mount" },
	{ "#e27#", "Flying Mount" },
	--{ "#e28#", "Aquatic Mount" }, -- Saved for later
	--{ "#e29#", "Aquatic Mount" }, -- Saved for later
	{ "#e30#", "Meat" },
	{ "#e31#", "Vegetables" },
	{ "#e32#", "Meta" },

	-- Labels for Loot Descriptions
	{ "#m1#", "Classes:" },
	{ "#m2#", "This Item Begins a Quest" },
	{ "#m3#", "Quest Item" },
	{ "#m4#", "Quest Reward" },
	{ "#m5#", "Shared" },
	{ "#m6#", FACTION_HORDE },
	{ "#m7#", FACTION_ALLIANCE },
	{ "#m17#", "Currency" },
	{ "#m20#", "Misc" },
	{ "#m21#", string.format("Tier %d", 4) },
	{ "#m22#", string.format("Tier %d", 5) },
	{ "#m23#", string.format("Tier %d", 6) },
	{ "#m24#", "Card Game Item" },
	{ "#m27#", "Used to summon boss" },
	{ "#m29#", "Tradable for sunmote + item above" },
	{ "#m30#", string.format("Tier %d", 1) },
	{ "#m31#", string.format("Tier %d", 2) },
	{ "#m32#", "Achievement Reward" },
	{ "#m34#", "Old Quest Reward" },
	{ "#m35#", string.format("Tier %d", 3) },
	{ "#m36#", "No Longer Available"},
	{ "#m37#", string.format("Tier %d", 11) },
	{ "#m38#", string.format("Tier %d", 12) },
	{ "#m39#", string.format("Tier %d", 13) },
	{ "#m40#", string.format("Tier %d", 14) },
	{ "#m41#", string.format("Tier %d", 15) },
	{ "#m42#", string.format("Tier %d", 16) },

	-- Misc
	{ "#j1#", "Normal Mode" },
	{ "#j2#", "Raid" },
	{ "#j3#", "Heroic Mode" },
	{ "#j4#", "Heroic" },
	{ "#j6#", "Dungeon Set 1" },
	{ "#j7#", "Dungeon Set 2" },
	{ "#j8#", "Dungeon Set 1/2" },
	{ "#j9#", "Replica" },
	{ "#j11#", "Fire Resistance Gear" },
	{ "#j12#", "Arcane Resistance Gear" },
	{ "#j13#", "Nature Resistance Gear" },
	{ "#j19#", "Fire" },
	{ "#j20#", "Water" },
	{ "#j21#", "Wind" },
	{ "#j22#", "Earth" },
	{ "#j27#", "Additional Heroic Loot" },
	{ "#j28#", "Entrance" },
	{ "#j30#", "Mounts" },
	{ "#j53#", "Hard Mode" },

	-- Upper Deck Card Game
	{ "#ud1#", "Loot Card Items" },

	-- AQ20 Tokens
	{ "#aq20t1#", "Qiraji Ornate Hilt" },
	{ "#aq20t2#", "Qiraji Martial Drape" },
	{ "#aq20t3#", "Qiraji Magisterial Ring" },
	{ "#aq20t4#", "Qiraji Ceremonial Ring" },
	{ "#aq20t5#", "Qiraji Regal Drape" },
	{ "#aq20t6#", "Qiraji Spiked Hilt" },

	-- AQ40 Tokens
	{ "#aq40t1#", "Qiraji Bindings of Dominance" },
	{ "#aq40t2#", "Vek'nilash's Circlet" },
	{ "#aq40t3#", "Ouro's Intact Hide" },
	{ "#aq40t4#", "Husk of the Old God" },
	{ "#aq40t5#", "Qiraji Bindings of Command" },
	{ "#aq40t6#", "Vek'lor's Diadem" },
	{ "#aq40t7#", "Skin of the Great Sandworm" },
	{ "#aq40t8#", "Carapace of the Old God" },

	-- BRD Arena Mini Bosses
	{ "#brd1#", "Anub'shiah" },
	{ "#brd2#", "Eviscerator" },
	{ "#brd3#", "Gorosh the Dervish" },
	{ "#brd4#", "Grizzle" },
	{ "#brd5#", "Hedrum the Creeper" },
	{ "#brd6#", "Ok'thor the Breaker" },

	-- NPC Names
	{ "#n17#", "Theldren" },
	{ "#n18#", "Sothos and Jarien" },

	-- Factions
	{ "#f1#", ALIL["Lower City"] },
	{ "#f2#", ALIL["The Sha'tar"] },
	{ "#f3#", ALIL["Thrallmar"] },
	{ "#f4#", ALIL["Honor Hold"] },
	{ "#f5#", ALIL["Keepers of Time"] },
	{ "#f6#", ALIL["Cenarion Expedition"] },

	-- Blacksmithing Crafted Plate Sets
	{ "#craftbp1#", "Imperial Plate" },
	{ "#craftbp2#", "The Darksoul" },
	{ "#craftbp3#", "Fel Iron Plate" },
	{ "#craftbp4#", "Adamantite Battlegear" },
	{ "#craftbp5#", "Flame Guard" },
	{ "#craftbp6#", "Enchanted Adamantite Armor" },
	{ "#craftbp7#", "Khorium Ward" },
	{ "#craftbp8#", "Faith in Felsteel" },
	{ "#craftbp9#", "Burning Rage" },
	{ "#craftbp10#", "Ornate Saronite Battlegear" },
	{ "#craftbp11#", "Savage Saronite Battlegear" },

	-- Leatherworking Crafted Leather Sets
	{ "#craftlwl1#", "Volcanic Armor" },
	{ "#craftlwl2#", "Ironfeather Armor" },
	{ "#craftlwl3#", "Stormshroud Armor" },
	{ "#craftlwl4#", "Devilsaur Armor" },
	{ "#craftlwl5#", "Blood Tiger Harness" },
	{ "#craftlwl6#", "Primal Batskin" },
	{ "#craftlwl7#", "Wild Draenish Armor" },
	{ "#craftlwl8#", "Thick Draenic Armor" },
	{ "#craftlwl9#", "Fel Skin" },
	{ "#craftlwl10#", "Strength of the Clefthoof" },
	{ "#craftlwe1#", "Primal Intent" },
	{ "#craftlwt1#", "Windhawk Armor" },
	{ "#craftlwl11#", "Borean Embrace" },
	{ "#craftlwl12#", "Iceborne Embrace" },
	{ "#craftlwl13#", "Eviscerator's Battlegear" },
	{ "#craftlwl14#", "Overcaster Battlegear" },

	-- Leatherworking Crafted Mail Sets
	{ "#craftlwm1#", "Green Dragon Mail" },
	{ "#craftlwm2#", "Blue Dragon Mail" },
	{ "#craftlwm3#", "Black Dragon Mail" },
	{ "#craftlwm4#", "Scaled Draenic Armor" },
	{ "#craftlwm5#", "Felscale Armor" },
	{ "#craftlwm6#", "Felstalker Armor" },
	{ "#craftlwm7#", "Fury of the Nether" },
	{ "#craftlwd1#", "Netherscale Armor" },
	{ "#craftlwd2#", "Netherstrike Armor" },
	{ "#craftlwm8#", "Frostscale Binding" },
	{ "#craftlwm9#", "Nerubian Hive" },
	{ "#craftlwm10#", "Stormhide Battlegear" },
	{ "#craftlwm11#", "Swiftarrow Battlegear" },

	-- Tailoring Crafted Sets
	{ "#craftt1#", "Bloodvine Garb" },
	{ "#craftt2#", "Netherweave Vestments" },
	{ "#craftt3#", "Imbued Netherweave" },
	{ "#craftt4#", "Arcanoweave Vestments" },
	{ "#craftt5#", "The Unyielding" },
	{ "#craftt6#", "Whitemend Wisdom" },
	{ "#craftt7#", "Spellstrike Infusion" },
	{ "#craftt8#", "Battlecast Garb" },
	{ "#craftt9#", "Soulcloth Embrace" },
	{ "#crafttm1#", "Primal Mooncloth" },
	{ "#crafttsh1#", "Shadow's Embrace" },
	{ "#crafttsf1#", "Wrath of Spellfire" },
	{ "#craftt10#", "Frostwoven Power" },
	{ "#craftt11#", "Duskweaver" },
	{ "#craftt12#", "Frostsavage Battlegear" },

	-- Vanilla WoW Sets
	{ "#pre60s1#", "Defias Leather" },
	{ "#pre60s2#", "Embrace of the Viper" },
	{ "#pre60s3#", "Chain of the Scarlet Crusade" },
	{ "#pre60s4#", "The Gladiator" },
	{ "#pre60s5#", "Ironweave Battlesuit" },
	{ "#pre60s6#", "Necropile Raiment" },
	{ "#pre60s7#", "Cadaverous Garb" },
	{ "#pre60s8#", "Bloodmail Regalia" },
	{ "#pre60s9#", "Deathbone Guardian" },
	{ "#pre60s10#", "The Postmaster" },
	{ "#pre60s15#", "Shard of the Gods" },
	{ "#pre60s16#", "Major Mojo Infusion" },
	{ "#pre60s17#", "Overlord's Resolution" },
	{ "#pre60s18#", "Prayer of the Primal" },
	{ "#pre60s19#", "Zanzil's Concentration" },
	{ "#pre60s20#", "Spirit of Eskhandar" },
	{ "#pre60s21#", "The Twin Blades of Hakkari" },
	{ "#pre60s22#", "Primal Blessing" },
	{ "#pre60s23#", "Dal'Rend's Arms" },
	{ "#pre60s24#", "Spider's Kiss" },

	-- AQ20 Sets
	{ "#aq20s1#", "Symbols of Unending Life" },
	{ "#aq20s2#", "Trappings of the Unseen Path" },
	{ "#aq20s3#", "Trappings of Vaulted Secrets" },
	{ "#aq20s4#", "Battlegear of Eternal Justice" },
	{ "#aq20s5#", "Finery of Infinite Wisdom" },
	{ "#aq20s6#", "Emblems of Veiled Shadows" },
	{ "#aq20s7#", "Gift of the Gathering Storm" },
	{ "#aq20s8#", "Implements of Unspoken Names" },
	{ "#aq20s9#", "Battlegear of Unyielding Strength" },

	-- AQ40 Sets
	{ "#aq40s1#", "Genesis Raiment" },
	{ "#aq40s2#", "Striker's Garb" },
	{ "#aq40s3#", "Enigma Vestments" },
	{ "#aq40s4#", "Avenger's Battlegear" },
	{ "#aq40s5#", "Garments of the Oracle" },
	{ "#aq40s6#", "Deathdealer's Embrace" },
	{ "#aq40s7#", "Stormcaller's Garb" },
	{ "#aq40s8#", "Doomcaller's Attire" },
	{ "#aq40s9#", "Conqueror's Battlegear" },

	-- Dungeon 1 Sets
	{ "#t0s1#", "Wildheart Raiment" },
	{ "#t0s2#", "Beaststalker Armor" },
	{ "#t0s3#", "Magister's Regalia" },
	{ "#t0s4#", "Lightforge Armor" },
	{ "#t0s5#", "Vestments of the Devout" },
	{ "#t0s6#", "Shadowcraft Armor" },
	{ "#t0s7#", "The Elements" },
	{ "#t0s8#", "Dreadmist Raiment" },
	{ "#t0s9#", "Battlegear of Valor" },

	-- Dungeon 2 Sets
	{ "#t05s1#", "Feralheart Raiment" },
	{ "#t05s2#", "Beastmaster Armor" },
	{ "#t05s3#", "Sorcerer's Regalia" },
	{ "#t05s4#", "Soulforge Armor" },
	{ "#t05s5#", "Vestments of the Virtuous" },
	{ "#t05s6#", "Darkmantle Armor" },
	{ "#t05s7#", "The Five Thunders" },
	{ "#t05s8#", "Deathmist Raiment" },
	{ "#t05s9#", "Battlegear of Heroism" },

	-- Dungeon 3 Sets
	{ "#ds3s1#", "Hallowed Raiment" },
	{ "#ds3s2#", "Incanter's Regalia" },
	{ "#ds3s3#", "Mana-Etched Regalia" },
	{ "#ds3s4#", "Oblivion Raiment" },
	{ "#ds3s5#", "Assassination Armor" },
	{ "#ds3s6#", "Moonglade Raiment" },
	{ "#ds3s7#", "Wastewalker Armor" },
	{ "#ds3s8#", "Beast Lord Armor" },
	{ "#ds3s9#", "Desolation Battlegear" },
	{ "#ds3s10#", "Tidefury Raiment" },
	{ "#ds3s11#", "Bold Armor" },
	{ "#ds3s12#", "Doomplate Battlegear" },
	{ "#ds3s13#", "Righteous Armor" },

	-- Tier 1 Sets
	{ "#t1s1#", "Cenarion Raiment" },
	{ "#t1s2#", "Giantstalker Armor" },
	{ "#t1s3#", "Arcanist Regalia" },
	{ "#t1s4#", "Lawbringer Armor" },
	{ "#t1s5#", "Vestments of Prophecy" },
	{ "#t1s6#", "Nightslayer Armor" },
	{ "#t1s7#", "The Earthfury" },
	{ "#t1s8#", "Felheart Raiment" },
	{ "#t1s9#", "Battlegear of Might" },

	-- Tier 2 Sets
	{ "#t2s1#", "Stormrage Raiment" },
	{ "#t2s2#", "Dragonstalker Armor" },
	{ "#t2s3#", "Netherwind Regalia" },
	{ "#t2s4#", "Judgement Armor" },
	{ "#t2s5#", "Vestments of Transcendence" },
	{ "#t2s6#", "Bloodfang Armor" },
	{ "#t2s7#", "The Ten Storms" },
	{ "#t2s8#", "Nemesis Raiment" },
	{ "#t2s9#", "Battlegear of Wrath" },

	-- Tier 3 Sets
	{ "#t3s1#", "Dreamwalker Raiment" },
	{ "#t3s2#", "Cryptstalker Armor" },
	{ "#t3s3#", "Frostfire Regalia" },
	{ "#t3s4#", "Redemption Armor" },
	{ "#t3s5#", "Vestments of Faith" },
	{ "#t3s6#", "Bonescythe Armor" },
	{ "#t3s7#", "The Earthshatterer" },
	{ "#t3s8#", "Plagueheart Raiment" },
	{ "#t3s9#", "Dreadnaught's Battlegear" },

	-- Tier 4 Sets
	{ "#t4s1_1#", "Malorne Harness" },
	{ "#t4s1_2#", "Malorne Raiment" },
	{ "#t4s1_3#", "Malorne Regalia" },
	{ "#t4s2#", "Demon Stalker Armor" },
	{ "#t4s3#", "Aldor Regalia" },
	{ "#t4s4_1#", "Justicar Armor" },
	{ "#t4s4_2#", "Justicar Battlegear" },
	{ "#t4s4_3#", "Justicar Raiment" },
	{ "#t4s5_1#", "Incarnate Raiment" },
	{ "#t4s5_2#", "Incarnate Regalia" },
	{ "#t4s6#", "Netherblade" },
	{ "#t4s7_1#", "Cyclone Harness" },
	{ "#t4s7_2#", "Cyclone Raiment" },
	{ "#t4s7_3#", "Cyclone Regalia" },
	{ "#t4s8#", "Voidheart Raiment" },
	{ "#t4s9_1#", "Warbringer Armor" },
	{ "#t4s9_2#", "Warbringer Battlegear" },

	-- Tier 5 Sets
	{ "#t5s1_1#", "Nordrassil Harness" },
	{ "#t5s1_2#", "Nordrassil Raiment" },
	{ "#t5s1_3#", "Nordrassil Regalia" },
	{ "#t5s2#", "Rift Stalker Armor" },
	{ "#t5s3#", "Tirisfal Regalia" },
	{ "#t5s4_1#", "Crystalforge Armor" },
	{ "#t5s4_2#", "Crystalforge Battlegear" },
	{ "#t5s4_3#", "Crystalforge Raiment" },
	{ "#t5s5_1#", "Avatar Raiment" },
	{ "#t5s5_2#", "Avatar Regalia" },
	{ "#t5s6#", "Deathmantle" },
	{ "#t5s7_1#", "Cataclysm Harness" },
	{ "#t5s7_2#", "Cataclysm Raiment" },
	{ "#t5s7_3#", "Cataclysm Regalia" },
	{ "#t5s8#", "Corruptor Raiment" },
	{ "#t5s9_1#", "Destroyer Armor" },
	{ "#t5s9_2#", "Destroyer Battlegear" },

	-- Tier 6 Sets
	{ "#t6s1_1#", "Thunderheart Harness" },
	{ "#t6s1_2#", "Thunderheart Raiment" },
	{ "#t6s1_3#", "Thunderheart Regalia" },
	{ "#t6s2#", "Gronnstalker's Armor" },
	{ "#t6s3#", "Tempest Regalia" },
	{ "#t6s4_1#", "Lightbringer Armor" },
	{ "#t6s4_2#", "Lightbringer Battlegear" },
	{ "#t6s4_3#", "Lightbringer Raiment" },
	{ "#t6s5_1#", "Vestments of Absolution" },
	{ "#t6s5_2#", "Absolution Regalia" },
	{ "#t6s6#", "Slayer's Armor" },
	{ "#t6s7_1#", "Skyshatter Harness" },
	{ "#t6s7_2#", "Skyshatter Raiment" },
	{ "#t6s7_3#", "Skyshatter Regalia" },
	{ "#t6s8#", "Malefic Raiment" },
	{ "#t6s9_1#", "Onslaught Armor" },
	{ "#t6s9_2#", "Onslaught Battlegear" },

	-- Tier 7 Sets
	{ "#t7s1_1#", "Dreamwalker Garb" },
	{ "#t7s1_2#", "Dreamwalker Battlegear" },
	{ "#t7s1_3#", "Dreamwalker Regalia" },
	{ "#t7s2#", "Cryptstalker Battlegear" },
	{ "#t7s3#", "Frostfire Garb" },
	{ "#t7s4_1#", "Redemption Regalia" },
	{ "#t7s4_2#", "Redemption Battlegear" },
	{ "#t7s4_3#", "Redemption Plate" },
	{ "#t7s5_1#", "Regalia of Faith" },
	{ "#t7s5_2#", "Garb of Faith" },
	{ "#t7s6#", "Bonescythe Battlegear" },
	{ "#t7s7_1#", "Earthshatter Garb" },
	{ "#t7s7_2#", "Earthshatter Battlegear" },
	{ "#t7s7_3#", "Earthshatter Regalia" },
	{ "#t7s8#", "Plagueheart Garb" },
	{ "#t7s9_1#", "Dreadnaught Battlegear" },
	{ "#t7s9_2#", "Dreadnaught Plate" },
	{ "#t7s10_1#", "Scourgeborne Battlegear" },
	{ "#t7s10_2#", "Scourgeborne Plate" },

	-- Tier 8 Sets
	{ "#t8s1_1#", "Nightsong Garb" },
	{ "#t8s1_2#", "Nightsong Battlegear" },
	{ "#t8s1_3#", "Nightsong Regalia" },
	{ "#t8s2#", "Scourgestalker Battlegear" },
	{ "#t8s3#", "Kirin Tor Garb" },
	{ "#t8s4_1#", "Aegis Regalia" },
	{ "#t8s4_2#", "Aegis Battlegear" },
	{ "#t8s4_3#", "Aegis Plate" },
	{ "#t8s5_1#", "Sanctification Regalia" },
	{ "#t8s5_2#", "Sanctification Garb" },
	{ "#t8s6#", "Terrorblade Battlegear" },
	{ "#t8s7_1#", "Worldbreaker Garb" },
	{ "#t8s7_2#", "Worldbreaker Battlegear" },
	{ "#t8s7_3#", "Worldbreaker Regalia" },
	{ "#t8s8#", "Deathbringer Garb" },
	{ "#t8s9_1#", "Siegebreaker Battlegear" },
	{ "#t8s9_2#", "Siegebreaker Plate" },
	{ "#t8s10_1#", "Darkruned Battlegear" },
	{ "#t8s10_2#", "Darkruned Plate" },

	-- Tier 9 Sets
	{ "#t9s1_1a#", "Malfurion's Garb" },
	{ "#t9s1_1h#", "Runetotem's Garb" },
	{ "#t9s1_2a#", "Malfurion's Battlegear" },
	{ "#t9s1_2h#", "Runetotem's Battlegear" },
	{ "#t9s1_3a#", "Malfurion's Regalia" },
	{ "#t9s1_3h#", "Runetotem's Regalia" },
	{ "#t9s2_a#", "Windrunner's Battlegear" },
	{ "#t9s2_h#", "Windrunner's Pursuit" },
	{ "#t9s3_a#", "Khadgar's Regalia" },
	{ "#t9s3_h#", "Sunstrider's Regalia" },
	{ "#t9s4_1a#", "Turalyon's Garb" },
	{ "#t9s4_1h#", "Liadrin's Garb" },
	{ "#t9s4_2a#", "Turalyon's Battlegear" },
	{ "#t9s4_2h#", "Liadrin's Battlegear" },
	{ "#t9s4_3a#", "Turalyon's Plate" },
	{ "#t9s4_3h#", "Liadrin's Plate" },
	{ "#t9s5_1a#", "Velen's Regalia" },
	{ "#t9s5_1h#", "Zabra's Regalia" },
	{ "#t9s5_2a#", "Velen's Raiment" },
	{ "#t9s5_2h#", "Zabra's Raiment" },
	{ "#t9s6_a#", "VanCleef's Battlegear" },
	{ "#t9s6_h#", "Garona's Battlegear" },
	{ "#t9s7_1a#", "Nobundo's Garb" },
	{ "#t9s7_1h#", "Thrall's Garb" },
	{ "#t9s7_2a#", "Nobundo's Battlegear" },
	{ "#t9s7_2h#", "Thrall's Battlegear" },
	{ "#t9s7_3a#", "Nobundo's Regalia" },
	{ "#t9s7_3h#", "Thrall's Regalia" },
	{ "#t9s8_a#", "Kel'Thuzad's Regalia" },
	{ "#t9s8_h#", "Gul'dan's Regalia" },
	{ "#t9s9_1a#", "Wrynn's Battlegear" },
	{ "#t9s9_1h#", "Hellscream's Battlegear" },
	{ "#t9s9_2a#", "Wrynn's Plate" },
	{ "#t9s9_2h#", "Hellscream's Plate" },
	{ "#t9s10_1a#", "Thassarian's Plate" },
	{ "#t9s10_1h#", "Koltira's Plate" },
	{ "#t9s10_2a#", "Thassarian's Battlegear" },
	{ "#t9s10_2h#", "Koltira's Battlegear" },

	-- Tier 10 Sets
	{ "#t10s1_1#", "Lasherweave Garb" },
	{ "#t10s1_2#", "Lasherweave Battlegear" },
	{ "#t10s1_3#", "Lasherweave Regalia" },
	{ "#t10s2#", "Ahn'Kahar Blood Hunter's Battlegear" },
	{ "#t10s3#", "Bloodmage's Regalia" },
	{ "#t10s4_1#", "Lightsworn Garb" },
	{ "#t10s4_2#", "Lightsworn Plate" },
	{ "#t10s4_3#", "Lightsworn Battlegear" },
	{ "#t10s5_1#", "Crimson Acolyte's Regalia" },
	{ "#t10s5_2#", "Crimson Acolyte's Raiment" },
	{ "#t10s6#", "Shadowblade's Battlegear" },
	{ "#t10s7_1#", "Frost Witch's Garb" },
	{ "#t10s7_2#", "Frost Witch's Battlegear" },
	{ "#t10s7_3#", "Frost Witch's Regalia" },
	{ "#t10s8#", "Dark Coven's Regalia" },
	{ "#t10s9_1#", "Ymirjar Lord's Battlegear" },
	{ "#t10s9_2#", "Ymirjar Lord's Plate" },
	{ "#t10s10_1#", "Scourgelord's Battlegear" },
	{ "#t10s10_2#", "Scourgelord's Plate" },

	-- Tier 11 Sets
	{ "#t11s1_1#", "Stormrider's Vestments" },
	{ "#t11s1_2#", "Stormrider's Battlegarb" },
	{ "#t11s1_3#", "Stormrider's Regalia" },
	{ "#t11s2#", "Lightning-Charged Battlegear" },
	{ "#t11s3#", "Firelord's Vestments" },
	{ "#t11s4_1#", "Reinforced Sapphirium Regalia" },
	{ "#t11s4_2#", "Reinforced Sapphirium Battlearmor" },
	{ "#t11s4_3#", "Reinforced Sapphirium Battleplate" },
	{ "#t11s5_1#", "Mercurial Regalia" },
	{ "#t11s5_2#", "Mercurial Vestments" },
	{ "#t11s6#", "Wind Dancer's Regalia" },
	{ "#t11s7_1#", "Vestments of the Raging Elements" },
	{ "#t11s7_2#", "Battlegear of the Raging Elements" },
	{ "#t11s7_3#", "Regalia of the Raging Elements" },
	{ "#t11s8#", "Shadowflame Regalia" },
	{ "#t11s9_1#", "Earthen Warplate" },
	{ "#t11s9_2#", "Earthen Battleplate" },
	{ "#t11s10_1#", "Magma Plated Battlegear" },
	{ "#t11s10_2#", "Magma Plated Battlearmor" },

	-- Tier 12 Sets
	{ "#t12s1_1#", "Obsidian Arborweave Vestments" },
	{ "#t12s1_2#", "Obsidian Arborweave Battlegarb" },
	{ "#t12s1_3#", "Obsidian Arborweave Regalia" },
	{ "#t12s2#", "Flamewaker's Battlegear" },
	{ "#t12s3#", "Firehawk Robes of Conflagration" },
	{ "#t12s4_1#", "Regalia of Immolation" },
	{ "#t12s4_2#", "Battlearmor of Immolation" },
	{ "#t12s4_3#", "Battleplate of Immolation" },
	{ "#t12s5_1#", "Regalia of the Cleansing Flame" },
	{ "#t12s5_2#", "Vestments of the Cleansing Flame" },
	{ "#t12s6#", "Vestments of the Dark Phoenix" },
	{ "#t12s7_1#", "Volcanic Vestments" },
	{ "#t12s7_2#", "Volcanic Battlegear" },
	{ "#t12s7_3#", "Volcanic Regalia" },
	{ "#t12s8#", "Balespider's Burning Vestments" },
	{ "#t12s9_1#", "Molten Giant Warplate" },
	{ "#t12s9_2#", "Molten Giant Battleplate" },
	{ "#t12s10_1#", "Elementium Deathplate Battlegear" },
	{ "#t12s10_2#", "Elementium Deathplate Battlearmor" },

	-- Tier 13 Sets
	{ "#t13s1_1#", "Deep Earth Vestments" },
	{ "#t13s1_2#", "Deep Earth Battlegarb" },
	{ "#t13s1_3#", "Deep Earth Regalia" },
	{ "#t13s2#", "Wyrmstalker Battlegear" },
	{ "#t13s3#", "Time Lord's Regalia" },
	{ "#t13s4_1#", "Regalia of Radiant Glory" },
	{ "#t13s4_2#", "Armor of Radiant Glory" },
	{ "#t13s4_3#", "Battleplate of Radiant Glory" },
	{ "#t13s5_1#", "Regalia of Dying Light" },
	{ "#t13s5_2#", "Vestments of Dying Light" },
	{ "#t13s6#", "Blackfang Battleweave" },
	{ "#t13s7_1#", "Spiritwalker's Vestments" },
	{ "#t13s7_2#", "Spiritwalker's Battlegear" },
	{ "#t13s7_3#", "Spiritwalker's Regalia" },
	{ "#t13s8#", "Vestments of the Faceless Shroud" },
	{ "#t13s9_1#", "Colossal Dragonplate Battlegear" },
	{ "#t13s9_2#", "Colossal Dragonplate Armor" },
	{ "#t13s10_1#", "Necrotic Boneplate Battlegear" },
	{ "#t13s10_2#", "Necrotic Boneplate Armor" },

	-- Tier 14 Sets
	{ "#t14s1_1#", "Vestments of the Eternal Blossom" },
	{ "#t14s1_2#", "Battlegear of the Eternal Blossom" },
	{ "#t14s1_3#", "Regalia of the Eternal Blossom" },
	{ "#t14s1_4#", "Armor of the Eternal Blossom" },
	{ "#t14s2#", "Yaungol Slayer Battlegear" },
	{ "#t14s3#", "Regalia of the Burning Scroll" },
	{ "#t14s4_1#", "White Tiger Vestments" },
	{ "#t14s4_2#", "White Tiger Plate" },
	{ "#t14s4_3#", "White Tiger Battlegear" },
	{ "#t14s5_1#", "Regalia of the Guardian Serpent" },
	{ "#t14s5_2#", "Vestments of the Guardian Serpent" },
	{ "#t14s6#", "Battlegear of the Thousandfold Blades" },
	{ "#t14s7_1#", "Vestments of the Firebird" },
	{ "#t14s7_2#", "Battlegear of the Firebird" },
	{ "#t14s7_3#", "Regalia of the Firebird" },
	{ "#t14s8#", "Sha-Skin Regalia" },
	{ "#t14s9_1#", "Battleplate of Resounding Rings" },
	{ "#t14s9_2#", "Plate of Resounding Rings" },
	{ "#t14s10_1#", "Battlegear of the Lost Catacomb" },
	{ "#t14s10_2#", "Plate of the Lost Catacomb" },
	{ "#t14s11_1#", "Armor of the Red Crane" },
	{ "#t14s11_2#", "Battlegear of the Red Crane" },
	{ "#t14s11_3#", "Vestments of the Red Crane" },

	-- Tier 15 Sets
	{ "#t15s1_1#", "Vestments of the Haunted Forest" },
	{ "#t15s1_2#", "Battlegear of the Haunted Forest" },
	{ "#t15s1_3#", "Regalia of the Haunted Forest" },
	{ "#t15s1_4#", "Armor of the Haunted Forest" },
	{ "#t15s2#", "Battlegear of the Saurok Stalker" },
	{ "#t15s3#", "Regalia of the Chromatic Hydra" },
	{ "#t15s4_1#", "Vestments of the Lightning Emperor" },
	{ "#t15s4_2#", "Plate of the Lightning Emperor" },
	{ "#t15s4_3#", "Battlegear of the Lightning Emperor" },
	{ "#t15s5_1#", "Regalia of the Exorcist" },
	{ "#t15s5_2#", "Vestments of the Exorcist" },
	{ "#t15s6#", "Nine-Tail Battlegear" },
	{ "#t15s7_1#", "Vestments of the Witch Doctor" },
	{ "#t15s7_2#", "Battlegear of the Witch Doctor" },
	{ "#t15s7_3#", "Regalia of the Witch Doctor" },
	{ "#t15s8#", "Regalia of the Thousandfold Hells" },
	{ "#t15s9_1#", "Battleplate of the Last Mogu" },
	{ "#t15s9_2#", "Plate of the Last Mogu" },
	{ "#t15s10_1#", "Battleplate of the All-Consuming Maw" },
	{ "#t15s10_2#", "Plate of the All-Consuming Maw" },
	{ "#t15s11_1#", "Fire-Charm Armor" },
	{ "#t15s11_2#", "Fire-Charm Battlegear" },
	{ "#t15s11_3#", "Fire-Charm Vestments" },

	-- Tier 16 Sets
	{ "#t16s1_1#", "Vestments of the Shattered Vale" },
	{ "#t16s1_2#", "Battlegear of the Shattered Vale" },
	{ "#t16s1_3#", "Regalia of the Shattered Vale" },
	{ "#t16s1_4#", "Armor of the Shattered Vale" },
	{ "#t16s2#", "Battlegear of the Unblinking Vigil" },
	{ "#t16s3#", "Chronomancer Regalia" },
	{ "#t16s4_1#", "Vestments of Winged Triumph" },
	{ "#t16s4_2#", "Plate of Winged Triumph" },
	{ "#t16s4_3#", "Battlegear of Winged Triumph" },
	{ "#t16s5_1#", "Regalia of Ternion Glory" },
	{ "#t16s5_2#", "Vestments of Ternion Glory" },
	{ "#t16s6#", "Barbed Assassin Battlegear" },
	{ "#t16s7_1#", "Celestial Harmony Vestment" },
	{ "#t16s7_2#", "Celestial Harmony Battlegear" },
	{ "#t16s7_3#", "Celestial Harmony Regalia" },
	{ "#t16s8#", "Regalia of the Horned Nightmare" },
	{ "#t16s9_1#", "Battleplate of the Prehistoric Marauder" },
	{ "#t16s9_2#", "Plate of the Prehistoric Marauder" },
	{ "#t16s10_1#", "Battleplate of Cyclopean Dread" },
	{ "#t16s10_2#", "Plate of Cyclopean Dread" },
	{ "#t16s11_1#", "Armor of Seven Sacred Seals" },
	{ "#t16s11_2#", "Battlegear of Seven Sacred Seals" },
	{ "#t16s11_3#", "Vestments of Seven Sacred Seals" },

	-- Arathi Basin Sets - Alliance
	{ "#absa1#", "The Highlander's Intent" },
	{ "#absa2#", "The Highlander's Purpose" },
	{ "#absa3#", "The Highlander's Will" },
	{ "#absa4#", "The Highlander's Determination" },
	{ "#absa5#", "The Highlander's Fortitude" },
	{ "#absa6#", "The Highlander's Resolution" },
	{ "#absa7#", "The Highlander's Resolve" },

	-- Arathi Basin Sets - Horde
	{ "#absh1#", "The Defiler's Intent" },
	{ "#absh2#", "The Defiler's Purpose" },
	{ "#absh3#", "The Defiler's Will" },
	{ "#absh4#", "The Defiler's Determination" },
	{ "#absh5#", "The Defiler's Fortitude" },
	{ "#absh6#", "The Defiler's Resolution" },

	-- PvP Level 60 Rare Sets - Alliance 
	{ "#pvpra1#", "Lieutenant Commander's Refuge" },
	{ "#pvpra2#", "Lieutenant Commander's Pursuance" },
	{ "#pvpra3#", "Lieutenant Commander's Arcanum" },
	{ "#pvpra4#", "Lieutenant Commander's Redoubt" },
	{ "#pvpra5#", "Lieutenant Commander's Investiture" },
	{ "#pvpra6#", "Lieutenant Commander's Guard" },
	{ "#pvpra7#", "Lieutenant Commander's Dreadgear" },
	{ "#pvpra8#", "Lieutenant Commander's Battlearmor" },
	{ "#pvpra9#", "Lieutenant Commander's Earthshaker" },

	-- PvP Level 60 Rare Sets - Horde
	{ "#pvprh1#", "Champion's Refuge" },
	{ "#pvprh2#", "Champion's Pursuance" },
	{ "#pvprh3#", "Champion's Arcanum" },
	{ "#pvprh4#", "Champion's Investiture" },
	{ "#pvprh5#", "Champion's Guard" },
	{ "#pvprh6#", "Champion's Stormcaller" },
	{ "#pvprh7#", "Champion's Dreadgear" },
	{ "#pvprh8#", "Champion's Battlearmor" },
	{ "#pvprh9#", "Champion's Redoubt" },

	-- PvP Level 60 Epic Sets - Alliance
	{ "#pvpea1#", "Field Marshal's Sanctuary" },
	{ "#pvpea2#", "Field Marshal's Pursuit" },
	{ "#pvpea3#", "Field Marshal's Regalia" },
	{ "#pvpea4#", "Field Marshal's Aegis" },
	{ "#pvpea5#", "Field Marshal's Raiment" },
	{ "#pvpea6#", "Field Marshal's Vestments" },
	{ "#pvpea7#", "Field Marshal's Threads" },
	{ "#pvpea8#", "Field Marshal's Battlegear" },
	{ "#pvpea9#", "Field Marshal's Earthshaker" },

	-- PvP Level 60 Epic Sets - Horde
	{ "#pvpeh1#", "Warlord's Sanctuary" },
	{ "#pvpeh2#", "Warlord's Pursuit" },
	{ "#pvpeh3#", "Warlord's Regalia" },
	{ "#pvpeh4#", "Warlord's Raiment" },
	{ "#pvpeh5#", "Warlord's Vestments" },
	{ "#pvpeh6#", "Warlord's Earthshaker" },
	{ "#pvpeh7#", "Warlord's Threads" },
	{ "#pvpeh8#", "Warlord's Battlegear" },
	{ "#pvpeh9#", "Warlord's Aegis" },

	-- Outland Faction Reputation PvP Sets
	{ "#pvprep701_1#", "Dragonhide Battlegear" },
	{ "#pvprep701_2#", "Wyrmhide Battlegear" },
	{ "#pvprep701_3#", "Kodohide Battlegear" },
	{ "#pvprep702#", "Stalker's Chain Battlegear" },
	{ "#pvprep703#", "Evoker's Silk Battlegear" },
	{ "#pvprep704_1#", "Crusader's Scaled Battlegear" },
	{ "#pvprep704_2#", "Crusader's Ornamented Battlegear" },
	{ "#pvprep705_1#", "Satin Battlegear" },
	{ "#pvprep705_2#", "Mooncloth Battlegear" },
	{ "#pvprep706#", "Opportunist's Battlegear" },
	{ "#pvprep707_1#", "Seer's Linked Battlegear" },
	{ "#pvprep707_2#", "Seer's Mail Battlegear" },
	{ "#pvprep707_3#", "Seer's Ringmail Battlegear" },
	{ "#pvprep708#", "Dreadweave Battlegear" },
	{ "#pvprep709#", "Savage Plate Battlegear" },

	-- Arena Epic Sets
	{ "#reqrating#", "Rating:" },
	{ "#arenas1_1#", "Gladiator's Sanctuary" },
	{ "#arenas1_2#", "Gladiator's Wildhide" },
	{ "#arenas1_3#", "Gladiator's Refuge" },
	{ "#arenas2#", "Gladiator's Pursuit" },
	{ "#arenas3#", "Gladiator's Regalia" },
	{ "#arenas4_1#", "Gladiator's Aegis" },
	{ "#arenas4_2#", "Gladiator's Vindication" },
	{ "#arenas4_3#", "Gladiator's Redemption" },
	{ "#arenas5_1#", "Gladiator's Raiment" },
	{ "#arenas5_2#", "Gladiator's Investiture" },
	{ "#arenas6#", "Gladiator's Vestments" },
	{ "#arenas7_1#", "Gladiator's Earthshaker" },
	{ "#arenas7_2#", "Gladiator's Thunderfist" },
	{ "#arenas7_3#", "Gladiator's Wartide" },
	{ "#arenas8_1#", "Gladiator's Dreadgear" },
	{ "#arenas8_2#", "Gladiator's Felshroud" },
	{ "#arenas9#", "Gladiator's Battlegear" },
	{ "#arenas10#", "Gladiator's Desecration" },
	{ "#arenas11_1#", "Gladiator's Ironskin" },
	{ "#arenas11_2#", "Gladiator's Copperskin" },

	-- Crafting
	{ "#sr#", "Skill Required:" },
	{ "#sk#", "Skill" },

	-- Misc PvP Set Text
	{ "#pvps1#", "Epic Set" },
	{ "#pvps2#", "Rare Set" },

	-- Text Colouring
	{ "=q0=", "|cff9d9d9d" },	-- Gray
	{ "=q1=", "|cffFFFFFF" },	-- White
	{ "=q2=", "|cff1eff00" },	-- Green
	{ "=q3=", "|cff0070dd" },	-- Blue
	{ "=q4=", "|cffa335ee" },	-- Purple
	{ "=q5=", "|cffFF8000" },	-- Orange
	{ "=q6=", "|cffFF0000" },	-- Red 
	{ "=q7=", "|cffe6cc80" },	-- Beige
	{ "=ec1=", "|cffFF8400" },	-- Orange
	{ "=ds=", "|cffFFd200" },	-- Yellow

	-- Months
	{ "#month1#", ALIL["January"] },
	{ "#month2#", ALIL["February"] },
	{ "#month3#", ALIL["March"] },
	{ "#month4#", ALIL["April"] },
	{ "#month5#", ALIL["May"] },
	{ "#month6#", ALIL["June"] },
	{ "#month7#", ALIL["July"] },
	{ "#month8#", ALIL["August"] },
	{ "#month9#", ALIL["September"] },
	{ "#month10#", ALIL["October"] },
	{ "#month11#", ALIL["November"] },
	{ "#month12#", ALIL["December"] },

	-- Currency Icons
	{ "#gold#", "|TInterface\\AddOns\\AtlasLoot\\Images\\gold:0|t" },
	{ "#silver#", "|TInterface\\AddOns\\AtlasLoot\\Images\\silver:0|t" },
	{ "#copper#", "|TInterface\\AddOns\\AtlasLoot\\Images\\bronze:0|t" },

	-- Currency Icons - PvP
	{ "#markthrallmar#", "|TInterface\\Icons\\INV_Misc_Token_Thrallmar:0|t" },
	{ "#markhhold#", "|TInterface\\Icons\\INV_Misc_Token_HonorHold:0|t" },
	{ "#halaabattle#", "|TInterface\\Icons\\INV_Misc_Rune_08:0|t" },
	{ "#halaaresearch#", "|TInterface\\Icons\\INV_Misc_Rune_09:0|t" },
	{ "#markofhonor#",  "|T1322720:0|t" }, -- Interface/Icons/Ability_PVP_GladiatorMedallion

	-- Currency Icons - PvE
	{ "#trophyofthecrusade#", "|TInterface\\Icons\\INV_Misc_Trophy_Argent:0|t" },

	-- Currency Icons - Events
	{ "#valentineday2#", "|TInterface\\Icons\\inv_jewelry_necklace_43:0|t"},

	-- Currency Icons - Factions
	{ "#glowcap#", "|TInterface\\Icons\\INV_Mushroom_02:0|t" },
	{ "#kyparite#", "|TInterface\\Icons\\inv_ore_manticyte:0|t" },							-- Kyparite (Klaxxi)
	{ "#ogrilashard#", "|TInterface\\Icons\\INV_Misc_Apexis_Shard:0|t" },
	{ "#ogrilacrystal#", "|TInterface\\Icons\\INV_Misc_Apexis_Crystal:0|t" },
	{ "#winterfinclam#", "|TInterface\\Icons\\INV_Misc_Shell_03:0|t" },

	-- Currency Icons - Crafting Recipes
	{ "#elementiumbar#", "|TInterface\\Icons\\inv_misc_pyriumbar:0|t"},						-- Elementium Bar (SmithingCataVendor)
	{ "#hardenedelementiumbar#", "|TInterface\\Icons\\inv_misc_ebonsteelbar:0|t"},			-- Hardened Elementium Bar (SmithingCataVendor)
	{ "#pyriumbar#", "|TInterface\\Icons\\inv_misc_pyriumbar_02:0|t"},						-- Pyrium Bar (SmithingCataVendor)
	{ "#heavenlyshard#", "|TInterface\\Icons\\inv_misc_largeshard_superior:0|t"},			-- Heavenly Shard (EnchantingCataVendor)
	{ "#hypnoticdust#", "|TInterface\\Icons\\inv_enchant_dust:0|t"},						-- Hypnotic Dust (EnchantingCataVendor)
	{ "#maelstromcrystal#", "|TInterface\\Icons\\inv_misc_crystalepic:0|t"},				-- Maelstrom Crystal (EnchantingCataVendor)
	{ "#embersilkbolt#", "|TInterface\\Icons\\inv_misc_emberweavecloth_01:0|t"},			-- Bolt of Embersilk Cloth (TailoringCataVendor)
	{ "#dreamcloth#", "|TInterface\\Icons\\inv_chest_cloth_57:0|t"},						-- Dream Cloth (TailoringCataVendor)
	{ "#heavysavageleather#", "|TInterface\\Icons\\item_savageleatherhide:0|t"},			-- Heavy Savage Leather (LeatherworkingCataVendor)
]]
}
local AtlasLoot_Data = {}

local itemUpdated = 0

function Dev:Init()
	AtlasLoot.SlashCommands:Add("dev", Dev.DevTool_Slash, "Development tools")
end
AtlasLoot:AddInitFunc(Dev.Init)

function Dev:DevTool_Slash(...)
	Dev:DevTool_CreateFrame()
end

function Dev:GetEntryInfos()
	local itemIDs = {}
	local numItemIds = 0
	local spellIDs = {}
	local numSpellIds = 0
	for dataID, data in pairs(AtlasLoot_Data) do
		for _,tableType in ipairs(lootTableTypes) do
			if data[tableType] then
				for _,itemTable in ipairs(data[tableType]) do
					for _,item in ipairs(itemTable) do
						local num1
						if type(item[2]) == "string" then
							num1 = string.find(item[2], "s(%d+)")
						end
						if item[2] and type(item[2]) == "number" and item[2] > 0 then
							if not itemIDs[item[2]] then
								itemIDs[item[2]] = true
								numItemIds = numItemIds + 1
							end
						elseif item[2] and type(item[2]) == "string" and num1 then
							if not spellIDs[item[2]] then
								spellIDs[item[2]] = true
								numSpellIds = numSpellIds + 1
								if item[3] and tonumber(item[3]) and not itemIDs[tonumber(item[3])] then
									itemIDs[tonumber(item[3])] = true
									numItemIds = numItemIds + 1
								end
							end
						end
					end
				end
			end
		end
	end
	print("ITEMS: "..numItemIds.." --- SPELLS: "..numSpellIds)
end
-- ######################################################
local function returnItemTableString(tab)
	lootTableString = ""
	if not tab then return "" end
	for site, siteTab in ipairs(tab) do
		if site == 1 then
			lootTableString = lootTableString.."{\n"
		else
			lootTableString = lootTableString.."\n["..site.."] = {\n"
		end
		for itemNum, item in ipairs(siteTab) do
			local temp = ""
			lootTableString = lootTableString.."{ "
			for id, entry in ipairs(item) do
				local trim = ", "
				if id == #item then
					trim = ""
				end
				if type(entry) == "string" then
					temp = temp.."\""..entry.."\""..trim
				elseif type(entry) == "number" then
					temp = temp..entry..trim
				end
			end
			lootTableString = lootTableString..temp.." },\n"
		end
		lootTableString = lootTableString.."}"
	end
	return lootTableString
end

local function getItemPrice(strg, newPrice, costItemID)
	local retStrg
	costItemID = tonumber(costItemID) or 0
	local priceTab = {
		[137642] = "markofhonor",
		[1356] = "echoofbattle",
		[1455894] = "echoofdomination",
		[1357] = "forlorn",
		[60329] = "EChestguard", -- Earthen Chestguard
		[60323] = "EBattleplate", -- Earthen Battleplate
		[60332] = "EHandguards", -- Earthen Handguards
		[60326] = "EGauntlets", -- Earthen Gauntlets
		[60328] = "EFaceguard", -- Earthen Faceguard
		[60325] = "EHelmet", -- Earthen Helmet
		[60330] = "ELegguards", -- Earthen Legguards
		[60324] = "ELegplates", -- Earthen Legplates
		[60331] = "EShoulderguards", -- Earthen Shoulderguards
		[60327] = "EPauldrons", -- Earthen Pauldrons
		[67424] = "forlornChest", -- Chest of the Forlorn Protector
		[65087] = "forlornShoulders", -- Shoulders of the Forlorn Protector
		[67430] = "forlornGauntlets", -- Gauntlets of the Forlorn Protector
		[65000] = "forlornCrown", -- Crown of the Forlorn Protector
		[67427] = "forlornLeggings", -- Leggings of the Forlorn Protector
		-- currency
		[1166] = "timewarped", -- Timewarped Badge
		[1501] = "WrithingEssence", -- Writhing Essence, added in 7.3.0
		[1506] = "ArgusWaystone", -- Argus Waystone, added in 7.3.0
		[1508] = "VeiledArgunite", -- Veiled Argunite, added in 7.3.0
	}
	--	/run print(getItemPrice("2175 #justice# / 60 #champseal#", 5000, "Interface\\Icons\\pvecurrency-justice"))
--	local englishFaction, _ = UnitFactionGroup("player")
	for k,v in pairs(priceTab) do
		if k == costItemID then
			retStrg = string.format("%s:%d", v, newPrice)
			itemUpdated = itemUpdated + 1
		end
	end
	if not retStrg then retStrg = strg or "" end
	return retStrg
end

local qualityTab = {
	--"=q0=",
	"=q1=",
	"=q2=",
	"=q3=",
	"=q4=",
	"=q5=",
	"=q6=",
	"=q7=",
}

local function FixTextBack(text)
	if not text or string.trim(text) == "" then return "" end
	
	text = gsub(text, "Miscellaneous", "#m20#");
	for k in ipairs(AtlasLoot_TextParsing) do
		text = gsub(text, AtlasLoot_TextParsing[k][2], AtlasLoot_TextParsing[k][1]);
	end

    return text;
end

--- Gets item equip infos and format it
-- self creats a string that contains infos about the item (Amortype, Weapon,...)
-- @param itemID The item ID
-- @return item equip-info string
-- @usage local itemEquipInfo = GetItemEquipInfo(12345)
local function GetItemEquipInfo(itemID)
	if not itemID or itemID == "" or type(itemID) ~= "number" then return "" end
	local _, _, _, _, _, itemType, itemSubType, _, itemEquipLoc = GetItemInfo(itemID)
	if not itemType or not itemEquipLoc then return "" end
	local tempText = ""
	if _G[itemEquipLoc] then
		if itemType == ENCHSLOT_WEAPON then
			tempText = itemSubType..', '..itemType
		else
			tempText = _G[itemEquipLoc]..', '..itemSubType
		end
	elseif itemSubType and string.find(itemSubType, MONEY) then
		tempText = MONEY
	end
	return tempText
end

local function startVendorScan(tab)
	itemUpdated = 0
	-- itemTexture, itemValue, itemLink = GetMerchantItemCostItem(index, itemIndex)
	-- numItems = GetMerchantNumItems();
	-- itemID = string.match(itemLink, "item:(%d+):")

	if MerchantFrame:IsShown() then
		if tab then
			for i = 1,GetMerchantNumItems() do
				local itemTexture, itemValue = GetMerchantItemCostItem(i, 1)
				local itemLink = GetMerchantItemLink(i)
				local itemID = string.match(itemLink or "item:0:", "item:(%d+):")
				itemID = itemID or 0
				for site, siteTab in ipairs(tab) do
					for itemNum, item in ipairs(siteTab) do
						if itemID and tonumber(itemID) and item[2] == tonumber(itemID) then
							tab[1][i][6] = getItemPrice(item[6], itemValue, itemTexture)
						end
					end
				end
			end
		else
			tab = {}
			tab[1] = {}
			for i = 1,GetMerchantNumItems() do
				local name, texture, price, quantity, numAvailable, isUsable, extendedCost = GetMerchantItemInfo(i)
				local itemCount = GetMerchantItemCostInfo(i)
				local priceStr
				local citemTexture, citemValue, citemLink, citemID, currencyID
				local itemLink = GetMerchantItemLink(i)
				local itemID = string.match(itemLink or "item:0:", "item:(%d+):")
				itemID = itemID or 0
				itemID = tonumber(itemID)
				local _,_,quality = GetItemInfo(itemID)
				if quality then quality = qualityTab[quality] end
				local desc = FixTextBack(GetItemEquipInfo(itemID))
				if (price > 0) then
					priceStr = string.format("[PRICE_EXTRA_ITTYPE] = \"money:%d", price)
				else
					priceStr = "[PRICE_EXTRA_ITTYPE] = \""
					for j=1, itemCount do
						citemTexture, citemValue, citemLink = GetMerchantItemCostItem(i, j)
						citemID = string.match(citemLink or "item:0:", "item:(%d+):")
						if not citemID then
							currencyID = string.match(citemLink or "|Hcurrency:0|h", "|Hcurrency:(%d+)|h")
						end
						priceStr = priceStr..getItemPrice(nil, citemValue, citemID or currencyID)
						if j<itemCount then priceStr = priceStr..":" end
					end
					
				end
				
				--tab[1][i] = { i, itemID, "", string.format("%s%s", quality or "", name or ""), "=ds="..desc, getItemPrice(nil, itemValue, itemTexture) }
				tab[1][i] = { i, itemID, priceStr or "", format("-- %s, %s", name or "", desc), texture, itemTexture }
			end
		end
	else
		print("No vendor frame shown")
	end
	
	return tab
end

-- function that draws the widgets for the first tab
local function VendorFrame(container)
	local lootTable, lootTableString
  
	local multiEditbox = AceGUI:Create("MultiLineEditBox")
    
	local editbox = AceGUI:Create("EditBox")
	editbox:SetLabel("LootTable:")
	editbox:SetWidth(200)
	editbox:SetCallback("OnEnterPressed", function(widget, event, text) 
		lootTable = text
		lootTableString = ""
		if AtlasLoot_Data[lootTable] and AtlasLoot_Data[lootTable]["Normal"] then
			lootTableString = returnItemTableString(AtlasLoot_Data[lootTable]["Normal"])
		end
		multiEditbox:SetText(lootTableString)
		multiEditbox.editBox:SetFocus() 
	end)
	container:AddChild(editbox)

	local desc = AceGUI:Create("Label")
	desc:SetText("")
	--desc:SetFullWidth(true)
	
	local button = AceGUI:Create("Button")
	button:SetText("Start Scan")
	button:SetCallback("OnClick", function() 
		local newTab, lootTableString
		if lootTable and AtlasLoot_Data[lootTable] and AtlasLoot_Data[lootTable]["Normal"] then
			newTab = startVendorScan(AtlasLoot_Data[lootTable]["Normal"]) 
		else
			newTab = startVendorScan() 
		end
		desc:SetText(itemUpdated.." items updated.") 
		lootTableString = startVendorScan(newTab)
		lootTableString = returnItemTableString(lootTableString)
		multiEditbox:SetText(lootTableString)
		multiEditbox.editBox:SetFocus() 
	end)
	button:SetWidth(200)
	container:AddChild(button)

	container:AddChild(desc)
	
	multiEditbox:SetLabel("LootTable:")
	multiEditbox:SetFullWidth(true)
	multiEditbox:SetFullHeight(true)
	--multiEditbox:SetCallback("OnEnterPressed", function(widget, event, text) lootTable = text end)
	container:AddChild(multiEditbox)
end
-- ######################################################
-- ######################################################

local function CheckTextParsing(entrys)
	entrys = entrys or 0
	local checkString = ""
	local numberFound = 0
	local checkTable = {}
	for iniName, iniTable in pairs(AtlasLoot_Data) do
		for tableType, tableTypeTable in pairs(iniTable) do
			if tableType ~= "info" then
				if type(tableTypeTable) == "table" then
					for tableNumber, tableNumberTable in ipairs(tableTypeTable) do
						if type(tableNumberTable) == "table" then
							for itemNum, itemTable in ipairs(tableNumberTable) do
								for k,v in pairs(AtlasLoot_TextParsing) do
									local tabName = v[1].." <"..v[2]..">"
									if not checkTable[tabName] then checkTable[tabName] = {} end
									if string.find(itemTable[4] or "", v[1]) 
									or string.find(itemTable[5] or "", v[1]) 
									or string.find(itemTable[6] or "", v[1]) 
									or string.find(itemTable[7] or "", v[1]) then
										checkTable[tabName][#checkTable[tabName] + 1] = "AtlasLoot_Data[\""..iniName.."\"][\""..tableType.."\"]["..tableNumber.."]["..itemNum.."]"
									end
								end
							end
						end
					end
				end
			end
		end
	end
	
	for k,v in pairs(checkTable) do
		if #v <= entrys then
			numberFound = numberFound + 1
			local chacheString = ""
			chacheString = chacheString.."\""..k.."\" ("..#v..")\n"
			for i,j in ipairs(v) do
				chacheString = chacheString.."-- "..j.."\n"
			end
			chacheString = chacheString.."\n\n"
			checkString = checkString..chacheString
			chacheString = nil
		end
	end
	
	return checkString, numberFound
end

local function TextParsingFrame(container)
	local multiEditbox = AceGUI:Create("MultiLineEditBox")
	local numEntrys
	
	local editbox = AceGUI:Create("EditBox")
	editbox:SetLabel("Less than x entrys:")
	editbox:SetWidth(200)
	editbox:SetCallback("OnEnterPressed", function(widget, event, text) 
		numEntrys = tonumber(text)
		editbox:SetText(numEntrys)
		multiEditbox.editBox:SetFocus() 
	end)
	container:AddChild(editbox)
	
	local desc = AceGUI:Create("Label")
	desc:SetText("0")
	
	local button = AceGUI:Create("Button")
	button:SetText("Start Scan")
	button:SetCallback("OnClick", function() 
		local text, number = CheckTextParsing(numEntrys)
		multiEditbox:SetText(text)
		desc:SetText(number.." entrys found")
		multiEditbox.editBox:HighlightText(0)
		multiEditbox.editBox:SetFocus() 
	end)
	button:SetWidth(200)
	container:AddChild(button)
	local button2 = AceGUI:Create("Button")
	button2:SetText("Mark all")
	button2:SetCallback("OnClick", function()
		multiEditbox.editBox:HighlightText(0)
	end)
	button2:SetWidth(200)
	container:AddChild(button2)
	container:AddChild(desc)
	
	multiEditbox:SetLabel("TextParsing:")
	multiEditbox:SetFullWidth(true)
	multiEditbox:SetFullHeight(true)
	--multiEditbox:SetCallback("OnEnterPressed", function(widget, event, text) lootTable = text end)
	container:AddChild(multiEditbox)

end

-- ######################################################
-- ######################################################
local ATLASLOOT_INSTANCE_MODULE_LIST = {
	"AtlasLoot_Legion",
	"AtlasLoot_WarlordsofDraenor",
	"AtlasLoot_MistsofPandaria",
	"AtlasLoot_Cataclysm",
	"AtlasLoot_WrathoftheLichKing",
	"AtlasLoot_BurningCrusade",
	"AtlasLoot_Classic",
}
local function CheckInstanceList()
	local cacheTab = {}
	local moduleList = {}
	local retString = ""
	
	for k,v in ipairs(ATLASLOOT_INSTANCE_MODULE_LIST) do
		moduleList[v] = k
	end
	for iniName, iniTable in pairs(AtlasLoot_Data) do
		--iniTable.info.module
		if not iniTable or not iniTable.info or not iniTable.info.module then
			print("ERROR "..iniName)
		else
			cacheTab[iniName] = moduleList[iniTable.info.module]
		end
	end
	
	retString = "AtlasLoot_InstanceList_Loader = {\n"
	for k,v in pairs(cacheTab) do
		retString = retString.."\n[\""..k.."\"] = "..v..","
	end
	retString = retString.."\n}"
	
	return retString
end


local function InstanceInfoFrame(container)
	local multiEditbox = AceGUI:Create("MultiLineEditBox")
	
	local button = AceGUI:Create("Button")
	button:SetText("Start Scan")
	button:SetCallback("OnClick", function() 
		local text, number = CheckInstanceList()
		multiEditbox:SetText(text)
		multiEditbox.editBox:HighlightText(0)
		multiEditbox.editBox:SetFocus() 
	end)
	button:SetWidth(200)
	container:AddChild(button)
	local button2 = AceGUI:Create("Button")
	button2:SetText("Mark all")
	button2:SetCallback("OnClick", function()
		multiEditbox.editBox:HighlightText(0)
		multiEditbox.editBox:SetFocus() 
	end)
	button2:SetWidth(200)
	container:AddChild(button2)
	
	multiEditbox:SetLabel("InstanceList:")
	multiEditbox:SetFullWidth(true)
	multiEditbox:SetFullHeight(true)
	--multiEditbox:SetCallback("OnEnterPressed", function(widget, event, text) lootTable = text end)
	container:AddChild(multiEditbox)
end

-- ######################################################
-- ######################################################

local AchievementIDs = {
	1312, -- BC
	2256, -- WotLK 
	7439, -- Mop
}

local function AchievementScan(id)
	if not id or id <= 0 then return "ERROR" end
	local ret = ""
	
	for i = 1,GetAchievementNumCriteria(id) do
		local name = GetAchievementCriteriaInfo(id,i)
		ret = ret..string.format("[\"%s\"] = GetAchievementCriteriaInfo(%d,%d),\n", name, id, i)
	end
	
	return ret
end
local function AchievementScanAll()
	local ret = ""
	for k,v in ipairs(AchievementIDs) do
		ret = ret..AchievementScan(v)
	end
	return ret
end

local function AchievementScanFrame(container)
	local textAID

	local editbox2 = AceGUI:Create("EditBox")

	local multiEditbox = AceGUI:Create("MultiLineEditBox")
	
	local editbox = AceGUI:Create("EditBox")
	editbox:SetLabel("AchievementID:")
	editbox:SetWidth(200)
	editbox:SetCallback("OnEnterPressed", function(widget, event, text) 
		textAID = tonumber(text)
		multiEditbox:SetText(AchievementScan( textAID ))
		multiEditbox.editBox:SetFocus() 
	end)
	container:AddChild(editbox)
	
	local button = AceGUI:Create("Button")
	button:SetText("Start Scan")
	button:SetCallback("OnClick", function() 
		multiEditbox:SetText(AchievementScan( textAID ))
		multiEditbox.editBox:SetFocus() 
	end)
	button:SetWidth(200)
	container:AddChild(button)
	
	local button2 = AceGUI:Create("Button")
	button2:SetText("Scan All")
	button2:SetCallback("OnClick", function() 
		multiEditbox:SetText(AchievementScanAll())
		multiEditbox.editBox:SetFocus() 
	end)
	button2:SetWidth(200)
	container:AddChild(button2)
	
	multiEditbox:SetLabel("Achievement Info:")
	multiEditbox:SetFullWidth(true)
	multiEditbox:SetFullHeight(true)
	--multiEditbox:SetCallback("OnEnterPressed", function(widget, event, text) lootTable = text end)
	container:AddChild(multiEditbox)
end

-- ######################################################
-- ######################################################
function startEJScan()
	local num = EJ_GetNumLoot()
	local rettab = {
		[1] = {}
	}
	for i = 1, num do
		local name, icon, slot, armorType, itemID, link = EJ_GetLootInfoByIndex(i)
		
		local _,_,quality = GetItemInfo(itemID)
		quality = qualityTab[quality]
		
		local desc = FixTextBack(GetItemEquipInfo(itemID))
		rettab[1][i] = {i, itemID, "", quality..name, "=ds="..desc }
	end
	
	return rettab
end

local function EJScan(container)
	local lootTable, lootTableString
  
	local multiEditbox = AceGUI:Create("MultiLineEditBox")

	local desc = AceGUI:Create("Label")
	desc:SetText("")
	--desc:SetFullWidth(true)
	
	local button = AceGUI:Create("Button")
	button:SetText("Start Scan")
	button:SetCallback("OnClick", function() 
		lootTableString = startEJScan()
		lootTableString = returnItemTableString(lootTableString)
		multiEditbox:SetText(lootTableString)
	end)
	button:SetWidth(200)
	container:AddChild(button)

	container:AddChild(desc)
	
	multiEditbox:SetLabel("LootTable:")
	multiEditbox:SetFullWidth(true)
	multiEditbox:SetFullHeight(true)
	--multiEditbox:SetCallback("OnEnterPressed", function(widget, event, text) lootTable = text end)
	container:AddChild(multiEditbox)
end

-- diff = max 5
local instanceList = {
--	317, -- Mogu
--	322, -- Pandaria
--	320, -- Terasse
--	330, -- HoF
--	362, -- Throne
--	369, -- OG
--	557, -- Draenor
--	477, -- Highmaul
--	669, -- HellfireCitadel
--	457, -- BlackrockFoundry
	861, -- TrialOfValor
	786, -- TheNighthold
	768, -- EmeraldNightmare
	875, -- Tomb of Sargeras
	822, -- BrokenIsles
}
local difficultys = {7,3,5,4,6,14}
local numClasses = GetNumClasses()
local function startBonusRollScan()
	local tab = {}
	local retString = ""
	if not IsAddOnLoaded("Blizzard_EncounterJournal") then
		LoadAddOn("Blizzard_EncounterJournal")
	end
	EncounterJournal_ListInstances()
	EJ_ClearSearch()
	EJ_SetDifficulty(1)

	--EncounterJournal_DisplayInstance(
	for _,iniId in ipairs(instanceList) do
		for _,diff in ipairs(difficultys) do --for diff=1,6 do  
			EncounterJournal_ListInstances()
			EncounterJournal_DisplayInstance(iniId)
			EJ_SetDifficulty(diff)
			for classId=1,numClasses do
				local numSpecs = GetNumSpecializationsForClassID(classId)
				for specId=1,numSpecs do
					local specID, specName = GetSpecializationInfoForClassID(classId, specId)
					EJ_SetLootFilter(classId, specID)
					local numLoot = EJ_GetNumLoot()
					--print(numLoot)
					for loot=1,numLoot do
						local itemID, encounterID, name, icon, slot, armorType, link = EJ_GetLootInfoByIndex(loot)
						if not tab[itemID] then tab[itemID] = {} end
						if not tab[itemID][classId] then
							tab[itemID][classId] = {}
							for i=1,numSpecs do
								tab[itemID][classId][i] = false
							end
						end
						tab[itemID][classId][specId] = true
					end
				end
			end
		end
	end
	
	for itemId, itemTab in pairs(tab) do
		retString = retString.."AtlasLoot_BonusRoll_Items["..itemId.."]={"
		for classId, classTab in pairs(itemTab) do
			retString = retString.."["..classId.."]={"
			for specId,spec in ipairs(classTab) do
				if specId > 1 then
					retString=retString..","
				end
				if spec then
					retString=retString.."true"
				else
					retString=retString.."false"
				end
			end
			retString = retString.."},"
		end
		retString = retString.."}\n"
	end
	
	return retString
end

local function startClassScan()
	local ret = "local classTable = {\n"
	for i = 1,11 do
		ret = ret.."["..i.."] = {"
		for j=1,4 do
			local id, name, description, icon, background, role = GetSpecializationInfoForClassID(i,j)
			if id then
				ret = ret.."["..id.."] = "..j..","
			end
		end
		ret = ret.."},\n"
	end
	ret = ret.."}"
	
	return ret
end

--EJ_SetLootFilter(classID, specID)
local function BonusRollScanFrame(container)
	local lootTable, lootTableString
  
	local multiEditbox = AceGUI:Create("MultiLineEditBox")

	local desc = AceGUI:Create("Label")
	desc:SetText("")
	--desc:SetFullWidth(true)
	
	local button = AceGUI:Create("Button")
	button:SetText("Start Scan")
	button:SetCallback("OnClick", function() 
		lootTableString = startBonusRollScan()
		multiEditbox:SetText(lootTableString)
		multiEditbox.editBox:HighlightText(0)
		multiEditbox.editBox:SetFocus() 
	end)
	button:SetWidth(200)
	container:AddChild(button)
	
	local button2 = AceGUI:Create("Button")
	button2:SetText("Class Scan")
	button2:SetCallback("OnClick", function() 
		lootTableString = startClassScan()
		multiEditbox:SetText(lootTableString)
		multiEditbox.editBox:HighlightText(0)
		multiEditbox.editBox:SetFocus() 
	end)
	button2:SetWidth(200)
	container:AddChild(button2)

	container:AddChild(desc)
	
	multiEditbox:SetLabel("LootTable:")
	multiEditbox:SetFullWidth(true)
	multiEditbox:SetFullHeight(true)
	--multiEditbox:SetCallback("OnEnterPressed", function(widget, event, text) lootTable = text end)
	container:AddChild(multiEditbox)
end
-- ######################################################


-- Callback function for OnGroupSelected
local function SelectGroup(container, event, group)
   container:ReleaseChildren()
   if group == "tab1" then
		VendorFrame(container)
   elseif group == "tab2" then
		TextParsingFrame(container)
	elseif group == "tab3" then
		InstanceInfoFrame(container)
	elseif group == "tab4" then
		EJScan(container)
	elseif group == "tab5" then
		AchievementScanFrame(container)
	elseif group == "tab6" then
		BonusRollScanFrame(container)
	end
end


function Dev:DevTool_CreateFrame()
	local frame = AceGUI:Create("Frame")
	frame:SetTitle("DevTools")
	frame:SetStatusText("DevTools Frame")
	frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
	-- Fill Layout - the TabGroup widget will fill the whole frame
	frame:SetLayout("Fill")

	-- Create the TabGroup
	local tab =  AceGUI:Create("TabGroup")
	tab:SetLayout("Flow")
	-- Setup which tabs to show
	tab:SetTabs({{text="Vendor Scan", value="tab1"}, {text="TextParsing Scan", value="tab2"}, {text="InstanceInfo Scan", value="tab3"}, {text="EJ Scan", value="tab4"}, {text="Achievement Scan", value="tab5"}, {text="BonusRoll Scan", value="tab6"}})
	-- Register callback
	tab:SetCallback("OnGroupSelected", SelectGroup)
	-- Set initial Tab (this will fire the OnGroupSelected callback)
	tab:SelectTab("tab1")

	-- add to the frame container
	frame:AddChild(tab)

end

function Dev:GetMapIds()
	self.db.profile.MAPIDS = self.db.profile.MAPIDS or {}	
	for i = 1,10000 do
		if GetMapNameByID(i) then
			self.db.profile.MAPIDS[i] = GetMapNameByID(i)
		end
	end
end

function Dev:GetEJDetails(bool)
	local iniIndex = 1
	local iniID, iniName = EJ_GetInstanceByIndex(iniIndex, bool)
	self.db.profile.EJINFO = self.db.profile.EJINFO or {}	
	local bossIndex, bossName, bossID
	while iniID do
		EJ_SelectInstance(iniID)
		bossIndex = 1
		bossName, _, bossID = EJ_GetEncounterInfoByIndex(bossIndex)
		--print(iniName, " = ", iniID)#
		self.db.profile.EJINFO[iniID] = {[iniName] = true}
		while bossName and bossIndex < 50 do
			--print("	", bossName, " = ", bossID)
			self.db.profile.EJINFO[iniID][bossID] = bossName
			bossIndex = bossIndex + 1
			bossName, _, bossID = EJ_GetEncounterInfoByIndex(bossIndex)
		end
		iniIndex = iniIndex + 1
        iniID, iniName = EJ_GetInstanceByIndex(iniIndex, bool)
	end
	if bool == false or bool == nil then
		AtlasLoot:GetEJDetails(true)
	end
end

local atlasSupportRemoved = false
function Dev:ReduceMemoryUsage()
	for iniName, iniTable in pairs(AtlasLoot_Data) do
		if iniTable.info and iniTable.info.module then
			iniTable.info.module = nil
		end
		if not string.find(iniName, "MENU") then
			for tableType, tableTypeTable in pairs(iniTable) do
				if tableType ~= "info" then
					for tableNumber, tableNumberTable in ipairs(tableTypeTable) do
						if type(tableNumberTable) == "table" then
							for itemNum, itemTable in ipairs(tableNumberTable) do
								if itemTable[4] ~= "INV_Box_01" and itemTable[4] ~= "inv_box_04" then
									itemTable[4] = nil
									itemTable[5] = nil
									itemTable[6] = nil
									itemTable[7] = nil
									itemTable[8] = nil
								end
							end
						end
					end
				end
			end
		end
	end
	
	if not atlasSupportRemoved and not IsAddOnLoaded("Atlas") then
		for k,v in pairs(AtlasLoot_LootTableRegister["Instances"]) do
			if type(v) == "table" and v["Bosses"] then
				for i,j in ipairs(v["Bosses"]) do
					j[2] = nil
				end
			end
		end
		
		AtlasLoot.SetupForAtlas = nil
		AtlasLoot.AtlasInitialize = nil
		AtlasLoot.Atlas_OnShow = nil 
		AtlasLoot.AtlasRefreshHook = nil 
		AtlasLoot.AtlasScrollBar_Update = nil 
		AtlasLoot.Atlas_SetBoss = nil 
		AtlasLoot.Boss_OnClick = nil 
		atlasSupportRemoved = true
	end
	collectgarbage("collect")

end

--[[ EVENTLOG
local eventSave = {}
local eventFrame = CreateFrame("FRAME")
local functioneventFrameOnEvent = function(self, event, ...)
	if event then
		if not eventSave[event] then eventSave[event] = {} end
		table.insert(eventSave[event], {...})
		print(event, ...)
	end
end
eventFrame:SetScript("OnEvent", functioneventFrameOnEvent)

function AtlasLoot_PrintEventLog()
	for event,eventTab in pairs(eventSave) do
		if eventTab and type(eventTab) == "table" then
			for i,args in ipairs(eventTab) do
				local argString = event.." - "
				local tmp = ""
				for k,v in ipairs(args) do
					tmp = string.format("## arg%d:%s", k, tostring(v or "nil"))
					argString = argString..tmp
				end
				print(argString)
			end
		end
	end
end

eventFrame:RegisterEvent("SPELL_CONFIRMATION_PROMPT")
eventFrame:RegisterEvent("SPELL_CONFIRMATION_TIMEOUT")
eventFrame:RegisterEvent("BONUS_ROLL_STARTED")
eventFrame:RegisterEvent("BONUS_ROLL_FAILED")
eventFrame:RegisterEvent("BONUS_ROLL_RESULT")
]]--
