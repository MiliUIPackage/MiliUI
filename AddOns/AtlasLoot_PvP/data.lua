local addonname = ...
local AtlasLoot = _G.AtlasLoot
local data = AtlasLoot.ItemDB:Add(addonname)

local AL = AtlasLoot.Locales
local ALIL = AtlasLoot.IngameLocales

-- change sortorder for factions
local ALLIANCE_DIFF, HORDE_DIFF
if UnitFactionGroup("player") == "Horde" then
	HORDE_DIFF = data:AddDifficulty(FACTION_HORDE)
	ALLIANCE_DIFF = data:AddDifficulty(FACTION_ALLIANCE)
else
	ALLIANCE_DIFF = data:AddDifficulty(FACTION_ALLIANCE)
	HORDE_DIFF = data:AddDifficulty(FACTION_HORDE)
end

local NORMAL_ITTYPE = data:AddItemTableType("Item", "Item")

local PRICE_EXTRA_ITTYPE = data:AddExtraItemTableType("Price")

local PVP_CONTENT = data:AddContentType(AL["PvP"], ATLASLOOT_PVP_COLOR)

data["WODS3SETS"] = {
	name = string.format(AL["Warlords Season %d"], 3).." "..AL["Class Sets"],
	ContentType = NORMAL_ITTYPE,
	items = {
		{
			name = LOCALIZED_CLASS_NAMES_MALE["DEATHKNIGHT"],
			[ALLIANCE_DIFF] = {
				{ 1, 125827, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Dreadplate Helm
				{ 2, 125829, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Dreadplate Shoulders
				{ 3, 125825, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Dreadplate Chestpiece
				{ 4, 125826, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Dreadplate Gauntlets
				{ 5, 125828, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Dreadplate Legguards
				{ 7, 126029, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Dreadplate Helm
				{ 8, 126031, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Dreadplate Shoulders
				{ 9, 126027, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Dreadplate Chestpiece
				{ 10, 126028, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Dreadplate Gauntlets
				{ 11, 126030, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Dreadplate Legguards
				{ 16, 126186 }, -- Warmongering Aspirant's Dreadplate Helm
				{ 17, 126188 }, -- Warmongering Aspirant's Dreadplate Shoulders
				{ 18, 126184 }, -- Warmongering Aspirant's Dreadplate Chestpiece
				{ 19, 126185 }, -- Warmongering Aspirant's Dreadplate Gauntlets
				{ 20, 126187 }, -- Warmongering Aspirant's Dreadplate Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 126306, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Dreadplate Helm
				{ 2, 126308, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Dreadplate Shoulders
				{ 3, 126304, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Dreadplate Chestpiece
				{ 4, 126305, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Dreadplate Gauntlets
				{ 5, 126307, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Dreadplate Legguards
				{ 7, 126506, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Dreadplate Helm
				{ 8, 126508, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Dreadplate Shoulders
				{ 9, 126504, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Dreadplate Chestpiece
				{ 10, 126505, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Dreadplate Gauntlets
				{ 11, 126507, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Dreadplate Legguards
				{ 16, 126663 }, -- Warmongering Aspirant's Dreadplate Helm
				{ 17, 126665 }, -- Warmongering Aspirant's Dreadplate Shoulders
				{ 18, 126661 }, -- Warmongering Aspirant's Dreadplate Chestpiece
				{ 19, 126662 }, -- Warmongering Aspirant's Dreadplate Gauntlets
				{ 20, 126664 }, -- Warmongering Aspirant's Dreadplate Legguards
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["DRUID"],
			[ALLIANCE_DIFF] = {
				{ 1, 125831, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Dragonhide Helm
				{ 2, 125834, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Dragonhide Spaulders
				{ 3, 125833, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Dragonhide Robes
				{ 4, 125830, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Dragonhide Gloves
				{ 5, 125832, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Dragonhide Legguards
				{ 7, 126033, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Dragonhide Helm
				{ 8, 126036, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Dragonhide Spaulders
				{ 9, 126035, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Dragonhide Tunic
				{ 10, 126032, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Dragonhide Gloves
				{ 11, 126034, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Dragonhide Legguards
				{ 16, 126190 }, -- Warmongering Aspirant's Dragonhide Helm
				{ 17, 126193 }, -- Warmongering Aspirant's Dragonhide Spaulders
				{ 18, 126192 }, -- Warmongering Aspirant's Dragonhide Tunic
				{ 19, 126189 }, -- Warmongering Aspirant's Dragonhide Gloves
				{ 20, 126191 }, -- Warmongering Aspirant's Dragonhide Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 126310, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Dragonhide Helm
				{ 2, 126313, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Dragonhide Spaulders
				{ 3, 126312, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Dragonhide Robes
				{ 4, 126309, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Dragonhide Gloves
				{ 5, 126311, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Dragonhide Legguards
				{ 7, 126510, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Dragonhide Helm
				{ 8, 126513, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Dragonhide Spaulders
				{ 9, 126512, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Dragonhide Tunic
				{ 10, 126509, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Dragonhide Gloves
				{ 11, 126511, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Dragonhide Legguards
				{ 16, 126667 }, -- Warmongering Aspirant's Dragonhide Helm
				{ 17, 126670 }, -- Warmongering Aspirant's Dragonhide Spaulders
				{ 18, 126669 }, -- Warmongering Aspirant's Dragonhide Tunic
				{ 19, 126666 }, -- Warmongering Aspirant's Dragonhide Gloves
				{ 20, 126668 }, -- Warmongering Aspirant's Dragonhide Legguards
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["HUNTER"],
			[ALLIANCE_DIFF] = {
				{ 1, 125837, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Chain Helm
				{ 2, 125839, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Chain Spaulders
				{ 3, 125835, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Chain Armor
				{ 4, 125836, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Chain Gauntlets
				{ 5, 125838, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Chain Leggings
				{ 7, 126039, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Chain Helm
				{ 8, 126041, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Chain Spaulders
				{ 9, 126037, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Chain Armor
				{ 10, 126038, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Chain Gauntlets
				{ 11, 126040, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Chain Leggings
				{ 16, 126196 }, -- Warmongering Aspirant's Chain Helm
				{ 17, 126198 }, -- Warmongering Aspirant's Chain Spaulders
				{ 18, 126194 }, -- Warmongering Aspirant's Chain Armor
				{ 19, 126195 }, -- Warmongering Aspirant's Chain Gauntlets
				{ 20, 126197 }, -- Warmongering Aspirant's Chain Leggings
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 126316, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Chain Helm
				{ 2, 126318, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Chain Spaulders
				{ 3, 126314, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Chain Armor
				{ 4, 126315, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Chain Gauntlets
				{ 5, 126317, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Chain Leggings
				{ 7, 126516, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Chain Helm
				{ 8, 126518, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Chain Spaulders
				{ 9, 126514, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Chain Armor
				{ 10, 126515, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Chain Gauntlets
				{ 11, 126517, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Chain Leggings
				{ 16, 126673 }, -- Warmongering Aspirant's Chain Helm
				{ 17, 126675 }, -- Warmongering Aspirant's Chain Spaulders
				{ 18, 126671 }, -- Warmongering Aspirant's Chain Armor
				{ 19, 126672 }, -- Warmongering Aspirant's Chain Gauntlets
				{ 20, 126674 }, -- Warmongering Aspirant's Chain Leggings
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["MAGE"],
			[ALLIANCE_DIFF] = {
				{ 1, 125884, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Silk Cowl
				{ 2, 125887, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Silk Amice
				{ 3, 125886, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Silk Robe
				{ 4, 125883, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Silk Handguards
				{ 5, 125885, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Silk Trousers
				{ 7, 126078, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Silk Cowl
				{ 8, 126081, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Silk Amice
				{ 9, 126080, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Silk Robe
				{ 10, 126077, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Silk Handguards
				{ 11, 126079, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Silk Trousers
				{ 16, 126211 }, -- Warmongering Aspirant's Silk Cowl
				{ 17, 126214 }, -- Warmongering Aspirant's Silk Amice
				{ 18, 126213 }, -- Warmongering Aspirant's Silk Robe
				{ 19, 126210 }, -- Warmongering Aspirant's Silk Handguards
				{ 20, 126212 }, -- Warmongering Aspirant's Silk Trousers
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 126363, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Silk Cowl
				{ 2, 126366, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Silk Amice
				{ 3, 126365, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Silk Robe
				{ 4, 126362, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Silk Handguards
				{ 5, 126364, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Silk Trousers
				{ 7, 126555, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Silk Cowl
				{ 8, 126558, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Silk Amice
				{ 9, 126557, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Silk Robe
				{ 10, 126554, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Silk Handguards
				{ 11, 126556, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Silk Trousers
				{ 16, 126688 }, -- Warmongering Aspirant's Silk Cowl
				{ 17, 126691 }, -- Warmongering Aspirant's Silk Amice
				{ 18, 126690 }, -- Warmongering Aspirant's Silk Robe
				{ 19, 126687 }, -- Warmongering Aspirant's Silk Handguards
				{ 20, 126689 }, -- Warmongering Aspirant's Silk Trousers
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["MONK"],
			[ALLIANCE_DIFF] = {
				{ 1, 125908, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Ironskin Helm
				{ 2, 125910, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Ironskin Spaulders
				{ 3, 125911, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Ironskin Tunic
				{ 4, 125907, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Ironskin Gloves
				{ 5, 125909, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Ironskin Legguards
				{ 7, 126094, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Ironskin Helm
				{ 8, 126096, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Ironskin Spaulders
				{ 9, 126097, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Ironskin Tunic
				{ 10, 126093, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Ironskin Gloves
				{ 11, 126095, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Ironskin Legguards
				{ 16, 126219 }, -- Warmongering Aspirant's Ironskin Helm
				{ 17, 126221 }, -- Warmongering Aspirant's Ironskin Spaulders
				{ 18, 126222 }, -- Warmongering Aspirant's Ironskin Tunic
				{ 19, 126218 }, -- Warmongering Aspirant's Ironskin Gloves
				{ 20, 126220 }, -- Warmongering Aspirant's Ironskin Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 126387, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Ironskin Helm
				{ 2, 126389, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Ironskin Spaulders
				{ 3, 126390, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Ironskin Tunic
				{ 4, 126386, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Ironskin Gloves
				{ 5, 126388, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Ironskin Legguards
				{ 7, 126571, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Ironskin Helm
				{ 8, 126573, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Ironskin Spaulders
				{ 9, 126574, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Ironskin Tunic
				{ 10, 126570, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Ironskin Gloves
				{ 11, 126572, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Ironskin Legguards
				{ 16, 126696 }, -- Warmongering Aspirant's Ironskin Helm
				{ 17, 126698 }, -- Warmongering Aspirant's Ironskin Spaulders
				{ 18, 126699 }, -- Warmongering Aspirant's Ironskin Tunic
				{ 19, 126695 }, -- Warmongering Aspirant's Ironskin Gloves
				{ 20, 126697 }, -- Warmongering Aspirant's Ironskin Legguards
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["PALADIN"],
			[ALLIANCE_DIFF] = {
				{ 1, 125914, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Scaled Helm
				{ 2, 125916, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Scaled Shoulders
				{ 3, 125912, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Scaled Chestpiece
				{ 4, 125913, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Scaled Gauntlets
				{ 5, 125915, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Scaled Legguards
				{ 7, 126100, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Scaled Helm
				{ 8, 126102, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Scaled Shoulders
				{ 9, 126098, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Scaled Chestpiece
				{ 10, 126099, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Scaled Gauntlets
				{ 11, 126101, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Scaled Legguards
				{ 16, 126225 }, -- Warmongering Aspirant's Scaled Helm
				{ 17, 126227 }, -- Warmongering Aspirant's Scaled Shoulders
				{ 18, 126223 }, -- Warmongering Aspirant's Scaled Chestpiece
				{ 19, 126224 }, -- Warmongering Aspirant's Scaled Gauntlets
				{ 20, 126226 }, -- Warmongering Aspirant's Scaled Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 126393, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Scaled Helm
				{ 2, 126395, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Scaled Shoulders
				{ 3, 126391, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Scaled Chestpiece
				{ 4, 126392, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Scaled Gauntlets
				{ 5, 126394, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Scaled Legguards
				{ 7, 126577, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Scaled Helm
				{ 8, 126579, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Scaled Shoulders
				{ 9, 126575, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Scaled Chestpiece
				{ 10, 126576, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Scaled Gauntlets
				{ 11, 126578, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Scaled Legguards
				{ 16, 126702 }, -- Warmongering Aspirant's Scaled Helm
				{ 17, 126704 }, -- Warmongering Aspirant's Scaled Shoulders
				{ 18, 126700 }, -- Warmongering Aspirant's Scaled Chestpiece
				{ 19, 126701 }, -- Warmongering Aspirant's Scaled Gauntlets
				{ 20, 126703 }, -- Warmongering Aspirant's Scaled Legguards
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["PRIEST"],
			[ALLIANCE_DIFF] = {
				{ 1, 125937, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Satin Hood
				{ 2, 125940, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Satin Mantle
				{ 3, 125939, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Satin Robe
				{ 4, 125936, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Satin Gloves
				{ 5, 125938, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Satin Leggings
				{ 7, 126115, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Satin Hood
				{ 8, 126118, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Satin Mantle
				{ 9, 126117, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Satin Robe
				{ 10, 126114, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Satin Gloves
				{ 11, 126116, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Satin Leggings
				{ 16, 126232 }, -- Warmongering Aspirant's Satin Hood
				{ 17, 126235 }, -- Warmongering Aspirant's Satin Mantle
				{ 18, 126234 }, -- Warmongering Aspirant's Satin Robe
				{ 19, 126231 }, -- Warmongering Aspirant's Satin Gloves
				{ 20, 126233 }, -- Warmongering Aspirant's Satin Leggings
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 126416, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Satin Hood
				{ 2, 126419, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Satin Mantle
				{ 3, 126418, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Satin Robe
				{ 4, 126415, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Satin Gloves
				{ 5, 126417, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Satin Leggings
				{ 7, 126592, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Satin Hood
				{ 8, 126595, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Satin Mantle
				{ 9, 126594, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Satin Robe
				{ 10, 126591, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Satin Gloves
				{ 11, 126593, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Satin Leggings
				{ 16, 126709 }, -- Warmongering Aspirant's Satin Hood
				{ 17, 126712 }, -- Warmongering Aspirant's Satin Mantle
				{ 18, 126711 }, -- Warmongering Aspirant's Satin Robe
				{ 19, 126708 }, -- Warmongering Aspirant's Satin Gloves
				{ 20, 126710 }, -- Warmongering Aspirant's Satin Leggings
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["ROGUE"],
			[ALLIANCE_DIFF] = {
				{ 1, 125943, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Leather Helm
				{ 2, 125945, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Leather Spaulders
				{ 3, 125941, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Leather Tunic
				{ 4, 125942, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Leather Gloves
				{ 5, 125944, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Leather Legguards
				{ 7, 126121, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Leather Helm
				{ 8, 126123, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Leather Spaulders
				{ 9, 126119, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Leather Tunic
				{ 10, 126120, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Leather Gloves
				{ 11, 126122, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Leather Legguards
				{ 16, 126238 }, -- Warmongering Aspirant's Leather Helm
				{ 17, 126240 }, -- Warmongering Aspirant's Leather Spaulders
				{ 18, 126236 }, -- Warmongering Aspirant's Leather Tunic
				{ 19, 126237 }, -- Warmongering Aspirant's Leather Gloves
				{ 20, 126239 }, -- Warmongering Aspirant's Leather Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 126422, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Leather Helm
				{ 2, 126424, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Leather Spaulders
				{ 3, 126420, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Leather Tunic
				{ 4, 126421, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Leather Gloves
				{ 5, 126423, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Leather Legguards
				{ 7, 126598, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Leather Helm
				{ 8, 126600, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Leather Spaulders
				{ 9, 126596, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Leather Tunic
				{ 10, 126597, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Leather Gloves
				{ 11, 126599, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Leather Legguards
				{ 16, 126715 }, -- Warmongering Aspirant's Leather Helm
				{ 17, 126717 }, -- Warmongering Aspirant's Leather Spaulders
				{ 18, 126713 }, -- Warmongering Aspirant's Leather Tunic
				{ 19, 126714 }, -- Warmongering Aspirant's Leather Gloves
				{ 20, 126716 }, -- Warmongering Aspirant's Leather Legguards
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["SHAMAN"],
			[ALLIANCE_DIFF] = {
				{ 1, 125948, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Ringmail Helm
				{ 2, 125950, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Ringmail Spaulders
				{ 3, 125946, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Ringmail Armor
				{ 4, 125947, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Ringmail Gauntlets
				{ 5, 125949, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Ringmail Kilt
				{ 7, 126126, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Ringmail Helm
				{ 8, 126128, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Ringmail Spaulders
				{ 9, 126124, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Ringmail Armor
				{ 10, 126125, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Ringmail Gauntlets
				{ 11, 126127, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Ringmail Leggings
				{ 16, 126243 }, -- Warmongering Aspirant's Ringmail Helm
				{ 17, 126245 }, -- Warmongering Aspirant's Ringmail Spaulders
				{ 18, 126241 }, -- Warmongering Aspirant's Ringmail Armor
				{ 19, 126242 }, -- Warmongering Aspirant's Ringmail Gauntlets
				{ 20, 126244 }, -- Warmongering Aspirant's Ringmail Leggings
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 126427, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Ringmail Helm
				{ 2, 126429, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Ringmail Spaulders
				{ 3, 126425, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Ringmail Armor
				{ 4, 126426, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Ringmail Gauntlets
				{ 5, 126428, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Ringmail Kilt
				{ 7, 126603, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Ringmail Helm
				{ 8, 126605, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Ringmail Spaulders
				{ 9, 126601, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Ringmail Armor
				{ 10, 126602, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Ringmail Gauntlets
				{ 11, 126604, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Ringmail Leggings
				{ 16, 126720 }, -- Warmongering Aspirant's Ringmail Helm
				{ 17, 126722 }, -- Warmongering Aspirant's Ringmail Spaulders
				{ 18, 126718 }, -- Warmongering Aspirant's Ringmail Armor
				{ 19, 126719 }, -- Warmongering Aspirant's Ringmail Gauntlets
				{ 20, 126721 }, -- Warmongering Aspirant's Ringmail Leggings
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["WARLOCK"],
			[ALLIANCE_DIFF] = {
				{ 1, 125990, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Felweave Cowl
				{ 2, 125993, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Felweave Amice
				{ 3, 125992, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Felweave Raiment
				{ 4, 125989, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Felweave Handguards
				{ 5, 125991, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Felweave Trousers
				{ 7, 126168, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Felweave Cowl
				{ 8, 126171, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Felweave Amice
				{ 9, 126170, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Felweave Raiment
				{ 10, 126167, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Felweave Handguards
				{ 11, 126169, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Felweave Trousers
				{ 16, 126259 }, -- Warmongering Aspirant's Felweave Cowl
				{ 17, 126262 }, -- Warmongering Aspirant's Felweave Amice
				{ 18, 126261 }, -- Warmongering Aspirant's Felweave Raiment
				{ 19, 126258 }, -- Warmongering Aspirant's Felweave Handguards
				{ 20, 126260 }, -- Warmongering Aspirant's Felweave Trousers
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 126467, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Felweave Cowl
				{ 2, 126470, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Felweave Amice
				{ 3, 126469, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Felweave Raiment
				{ 4, 126466, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Felweave Handguards
				{ 5, 126468, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Felweave Trousers
				{ 7, 126645, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Felweave Cowl
				{ 8, 126648, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Felweave Amice
				{ 9, 126647, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Felweave Raiment
				{ 10, 126644, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Felweave Handguards
				{ 11, 126646, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Felweave Trousers
				{ 16, 126736 }, -- Warmongering Aspirant's Felweave Cowl
				{ 17, 126739 }, -- Warmongering Aspirant's Felweave Amice
				{ 18, 126738 }, -- Warmongering Aspirant's Felweave Raiment
				{ 19, 126735 }, -- Warmongering Aspirant's Felweave Handguards
				{ 20, 126737 }, -- Warmongering Aspirant's Felweave Trousers
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["WARRIOR"],
			[ALLIANCE_DIFF] = {
				{ 1, 125996, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Plate Helm
				{ 2, 125998, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Plate Shoulders
				{ 3, 125994, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Plate Chestpiece
				{ 4, 125995, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Plate Gauntlets
				{ 5, 125997, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Plate Legguards
				{ 7, 126174, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Plate Helm
				{ 8, 126176, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Plate Shoulders
				{ 9, 126172, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Plate Chestpiece
				{ 10, 126173, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Plate Gauntlets
				{ 11, 126175, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Plate Legguards
				{ 16, 126265 }, -- Warmongering Aspirant's Plate Helm
				{ 17, 126267 }, -- Warmongering Aspirant's Plate Shoulders
				{ 18, 126263 }, -- Warmongering Aspirant's Plate Chestpiece
				{ 19, 126264 }, -- Warmongering Aspirant's Plate Gauntlets
				{ 20, 126266 }, -- Warmongering Aspirant's Plate Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 126473, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Plate Helm
				{ 2, 126475, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Plate Shoulders
				{ 3, 126471, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Plate Chestpiece
				{ 4, 126472, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Plate Gauntlets
				{ 5, 126474, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Plate Legguards
				{ 7, 126651, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Plate Helm
				{ 8, 126653, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Plate Shoulders
				{ 9, 126649, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Plate Chestpiece
				{ 10, 126650, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Plate Gauntlets
				{ 11, 126652, [PRICE_EXTRA_ITTYPE] = "honor:2250" }, -- Warmongering Combatant's Plate Legguards
				{ 16, 126742 }, -- Warmongering Aspirant's Plate Helm
				{ 17, 126744 }, -- Warmongering Aspirant's Plate Shoulders
				{ 18, 126740 }, -- Warmongering Aspirant's Plate Chestpiece
				{ 19, 126741 }, -- Warmongering Aspirant's Plate Gauntlets
				{ 20, 126743 }, -- Warmongering Aspirant's Plate Legguards
			},
		},
	},
}
data["WODS3NONSETGEAR"] = {
	name = string.format(AL["Warlords Season %d"], 3).." "..AL["Non-Set Gear"],
	ContentType = NORMAL_ITTYPE,
	items = {
		{
			name = ALIL["Cloth"],
			[ALLIANCE_DIFF] = {
				-- ilvl 710
				{ 1, 125816, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Hood of Prowess
				{ 2, 125821, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Cowl of Cruelty
				{ 4, 125819, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Amice of Prowess
				{ 5, 125824, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Mantle of Cruelty
				{ 7, 125818, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Robes of Prowess
				{ 8, 125823, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Raiment of Cruelty
				{ 10, 125815, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Gloves of Prowess
				{ 11, 125820, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Handguards of Cruelty
				{ 16, 125812, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Cuffs of Prowess
				{ 17, 125813, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Cuffs of Cruelty
				{ 18, 125814, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Cuffs of Victory
				{ 20, 125817, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Leggings of Prowess
				{ 21, 125822, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Trousers of Cruelty
				{ 23, 125806, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Cord of Cruelty
				{ 24, 125807, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Cord of Prowess
				{ 25, 125808, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Cord of Victory
				{ 27, 125809, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Treads of Cruelty
				{ 28, 125810, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Treads of Prowess
				{ 29, 125811, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Treads of Victory
				-- ilvl 680
				{ 101, 126023 }, -- Warmongering Combatant's Hood of Prowess
				{ 103, 126026 }, -- Warmongering Combatant's Amice of Prowess
				{ 105, 126025 }, -- Warmongering Combatant's Robes of Prowess
				{ 107, 126022 }, -- Warmongering Combatant's Gloves of Prowess
				{ 109, 126020, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Cuffs of Prowess
				{ 110, 126021, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Cuffs of Cruelty
				{ 112, 126024 }, -- Warmongering Combatant's Leggings of Prowess
				{ 114, 126016, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Cord of Cruelty
				{ 115, 126017, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Cord of Prowess
				{ 116, 126018, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Treads of Cruelty
				{ 117, 126019, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Treads of Prowess
				-- ilvl 625
				{ 119, 126183 }, -- Warmongering Aspirant's Cuffs of Prowess
				{ 121, 126181 }, -- Warmongering Aspirant's Cord of Cruelty
				{ 123, 126182 }, -- Warmongering Aspirant's Treads of Cruelty
			},
			[HORDE_DIFF] = {
				-- ilvl 710
				{ 1, 126295, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Hood of Prowess
				{ 2, 126300, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Cowl of Cruelty
				{ 4, 126298, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Amice of Prowess
				{ 5, 126303, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Mantle of Cruelty
				{ 7, 126297, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Robes of Prowess
				{ 8, 126302, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Raiment of Cruelty
				{ 10, 126294, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Gloves of Prowess
				{ 11, 126299, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Handguards of Cruelty
				{ 16, 126291, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Cuffs of Prowess
				{ 17, 126292, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Cuffs of Cruelty
				{ 18, 126293, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Cuffs of Victory
				{ 20, 126296, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Leggings of Prowess
				{ 21, 126301, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Trousers of Cruelty
				{ 23, 126285, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Cord of Cruelty
				{ 24, 126286, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Cord of Prowess
				{ 25, 126287, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Cord of Victory
				{ 27, 126288, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Treads of Cruelty
				{ 28, 126289, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Treads of Prowess
				{ 29, 126290, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Treads of Victory
				-- ilvl 680
				{ 101, 126500 }, -- Warmongering Combatant's Hood of Prowess
				{ 103, 126503 }, -- Warmongering Combatant's Amice of Prowess
				{ 105, 126502 }, -- Warmongering Combatant's Robes of Prowess
				{ 107, 126499 }, -- Warmongering Combatant's Gloves of Prowess
				{ 109, 126497, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Cuffs of Prowess
				{ 110, 126498, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Cuffs of Cruelty
				{ 112, 126501 }, -- Warmongering Combatant's Leggings of Prowess
				{ 114, 126493, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Cord of Cruelty
				{ 115, 126494, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Cord of Prowess
				{ 116, 126495, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Treads of Cruelty
				{ 117, 126496, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Treads of Prowess
				-- ilvl 625
				{ 119, 126660 }, -- Warmongering Aspirant's Cuffs of Prowess
				{ 121, 126658 }, -- Warmongering Aspirant's Cord of Cruelty
				{ 123, 126659 }, -- Warmongering Aspirant's Treads of Cruelty
			},
		},
		{
			name = ALIL["Leather"],
			[ALLIANCE_DIFF] = {
				-- ilvl 710
				{ 1, 125875, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Helm
				{ 2, 125880, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Headcover
				{ 4, 125877, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Spaulders
				{ 5, 125882, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Pauldrons
				{ 7, 125873, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Tunic
				{ 8, 125878, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Chestguard
				{ 10, 125874, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Gloves
				{ 11, 125879, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Grips
				{ 16, 125870, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Bindings of Cruelty
				{ 17, 125871, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Bindings of Prowess
				{ 18, 125872, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Bindings of Victory
				{ 20, 125876, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Legguards
				{ 21, 125881, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Leggings
				{ 23, 125864, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Belt of Prowess
				{ 24, 125865, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Belt of Cruelty
				{ 25, 125866, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Belt of Victory
				{ 27, 125867, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Boots of Cruelty
				{ 28, 125868, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Boots of Prowess
				{ 29, 125869, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Boots of Victory
				-- ilvl 680
				{ 101, 126074 }, -- Warmongering Combatant's Helm
				{ 103, 126076 }, -- Warmongering Combatant's Spaulders
				{ 105, 126072 }, -- Warmongering Combatant's Tunic
				{ 107, 126073 }, -- Warmongering Combatant's Gloves
				{ 109, 126070, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Bindings of Cruelty
				{ 110, 126071, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Bindings of Prowess
				{ 112, 126075 }, -- Warmongering Combatant's Legguards
				{ 114, 126066, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Belt of Prowess
				{ 115, 126067, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Belt of Cruelty
				{ 116, 126068, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Boots of Cruelty
				{ 117, 126069, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Boots of Prowess
				-- ilvl 625
				{ 119, 126209 }, -- Warmongering Aspirant's Bindings of Cruelty
				{ 121, 126207 }, -- Warmongering Aspirant's Belt of Prowess
				{ 123, 126208 }, -- Warmongering Aspirant's Boots of Cruelty
			},
			[HORDE_DIFF] = {
				-- ilvl 710
				{ 1, 126354, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Helm
				{ 2, 126359, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Headcover
				{ 4, 126356, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Spaulders
				{ 5, 126361, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Pauldrons
				{ 7, 126352, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Tunic
				{ 8, 126357, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Chestguard
				{ 10, 126353, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Gloves
				{ 11, 126358, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Grips
				{ 16, 126349, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Bindings of Cruelty
				{ 17, 126350, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Bindings of Prowess
				{ 18, 126351, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Bindings of Victory
				{ 20, 126355, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Legguards
				{ 21, 126360, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Leggings
				{ 23, 126343, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Belt of Prowess
				{ 24, 126344, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Belt of Cruelty
				{ 25, 126345, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Belt of Victory
				{ 27, 126346, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Boots of Cruelty
				{ 28, 126347, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Boots of Prowess
				{ 29, 126348, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Boots of Victory
				-- ilvl 680
				{ 101, 126551 }, -- Warmongering Combatant's Helm
				{ 103, 126553 }, -- Warmongering Combatant's Spaulders
				{ 105, 126549 }, -- Warmongering Combatant's Tunic
				{ 107, 126550 }, -- Warmongering Combatant's Gloves
				{ 109, 126547, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Bindings of Cruelty
				{ 110, 126548, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Bindings of Prowess
				{ 112, 126552 }, -- Warmongering Combatant's Legguards
				{ 114, 126543, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Belt of Prowess
				{ 115, 126544, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Belt of Cruelty
				{ 116, 126545, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Boots of Cruelty
				{ 117, 126546, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Boots of Prowess
				-- ilvl 625
				{ 119, 126686 }, -- Warmongering Aspirant's Bindings of Cruelty
				{ 121, 126684 }, -- Warmongering Aspirant's Belt of Prowess
				{ 123, 126685 }, -- Warmongering Aspirant's Boots of Cruelty
			},
		},
		{
			name = ALIL["Mail"],
			[ALLIANCE_DIFF] = {
				-- ilvl 710
				{ 1, 125899, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Helm
				{ 2, 125904, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Coif
				{ 4, 125901, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Spaulders
				{ 5, 125906, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Pauldrons
				{ 7, 125897, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Armor
				{ 8, 125902, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Chestguard
				{ 10, 125898, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Gauntlets
				{ 11, 125903, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Gloves
				{ 16, 125894, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Armbands of Prowess
				{ 17, 125895, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Armbands of Cruelty
				{ 18, 125896, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Armbands of Victory
				{ 20, 125900, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Leggings
				{ 21, 125905, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Leggings
				{ 23, 125888, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Waistguard of Cruelty
				{ 24, 125889, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Waistguard of Prowess
				{ 25, 125890, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Waistguard of Victory
				{ 27, 125891, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Footguards of Cruelty
				{ 28, 125892, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Footguards of Prowess
				{ 29, 125893, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Footguards of Victory
				-- ilvl 680
				{ 101, 126090 }, -- Warmongering Combatant's Helm
				{ 103, 126092 }, -- Warmongering Combatant's Spaulders
				{ 105, 126088 }, -- Warmongering Combatant's Armor
				{ 107, 126089 }, -- Warmongering Combatant's Gauntlets
				{ 109, 126086, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Armbands of Prowess
				{ 110, 126087, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Armbands of Cruelty
				{ 112, 126091 }, -- Warmongering Combatant's Leggings
				{ 114, 126082, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Waistguard of Cruelty
				{ 115, 126083, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Waistguard of Prowess
				{ 116, 126084, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Footguards of Cruelty
				{ 117, 126085, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Footguards of Prowess
				-- ilvl 625
				{ 119, 126217 }, -- Warmongering Aspirant's Armbands of Prowess
				{ 121, 126215 }, -- Warmongering Aspirant's Waistguard of Cruelty
				{ 123, 126216 }, -- Warmongering Aspirant's Footguards of Cruelty
			},
			[HORDE_DIFF] = {
				-- ilvl 710
				{ 1, 126378, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Helm
				{ 2, 126383, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Coif
				{ 4, 126380, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Spaulders
				{ 5, 126385, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Pauldrons
				{ 7, 126376, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Armor
				{ 8, 126381, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Chestguard
				{ 10, 126377, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Gauntlets
				{ 11, 126382, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Gloves
				{ 16, 126373, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Armbands of Prowess
				{ 17, 126374, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Armbands of Cruelty
				{ 18, 126375, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Armbands of Victory
				{ 20, 126379, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Leggings
				{ 21, 126384, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Leggings
				{ 23, 126367, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Waistguard of Cruelty
				{ 24, 126368, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Waistguard of Prowess
				{ 25, 126369, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Waistguard of Victory
				{ 27, 126370, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Footguards of Cruelty
				{ 28, 126371, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Footguards of Prowess
				{ 29, 126372, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Footguards of Victory
				-- ilvl 680
				{ 101, 126567 }, -- Warmongering Combatant's Helm
				{ 103, 126569 }, -- Warmongering Combatant's Spaulders
				{ 105, 126565 }, -- Warmongering Combatant's Armor
				{ 107, 126566 }, -- Warmongering Combatant's Gauntlets
				{ 109, 126563, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Armbands of Prowess
				{ 110, 126564, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Armbands of Cruelty
				{ 112, 126568 }, -- Warmongering Combatant's Leggings
				{ 114, 126559, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Waistguard of Cruelty
				{ 115, 126560, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Waistguard of Prowess
				{ 116, 126561, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Footguards of Cruelty
				{ 117, 126562, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Footguards of Prowess
				-- ilvl 625
				{ 119, 126694 }, -- Warmongering Aspirant's Armbands of Prowess
				{ 121, 126692 }, -- Warmongering Aspirant's Waistguard of Cruelty
				{ 123, 126693 }, -- Warmongering Aspirant's Footguards of Cruelty
			},
		},
		{
			name = ALIL["Plate"],
			[ALLIANCE_DIFF] = {
				-- ilvl 710
				{ 1, 125928, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Plate Helmet
				{ 2, 125933, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Plate Visor
				{ 4, 125930, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Shoulderplates
				{ 5, 125935, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Plate Pauldrons
				{ 7, 125926, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Plate Breastplate
				{ 8, 125931, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Plate Chestguard
				{ 10, 125927, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Plate Gloves
				{ 11, 125932, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Plate Grips
				{ 16, 125923, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Armplates of Cruelty
				{ 17, 125924, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Armplates of Prowess
				{ 18, 125925, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Armplates of Victory
				{ 20, 125929, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Legplates
				{ 21, 125934, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Plate Leggings
				{ 22, 125917, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Girdle of Cruelty
				{ 23, 125918, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Girdle of Prowess
				{ 24, 125919, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Girdle of Victory
				{ 26, 125920, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Warboots of Cruelty
				{ 27, 125921, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Warboots of Prowess
				{ 28, 125922, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Warboots of Victory
				-- ilvl 680
				{ 101, 126111 }, -- Warmongering Combatant's Plate Helmet
				{ 103, 126113 }, -- Warmongering Combatant's Shoulderplates
				{ 105, 126109 }, -- Warmongering Combatant's Plate Breastplate
				{ 107, 126110 }, -- Warmongering Combatant's Plate Gloves
				{ 109, 126107, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Armplates of Cruelty
				{ 110, 126108, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Armplates of Prowess
				{ 112, 126112 }, -- Warmongering Combatant's Legplates
				{ 114, 126103, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Girdle of Cruelty
				{ 115, 126104, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Girdle of Prowess
				{ 116, 126105, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Warboots of Cruelty
				{ 117, 126106, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Warboots of Prowess
				-- ilvl 625
				{ 119, 126230 }, -- Warmongering Aspirant's Armplates of Cruelty
				{ 121, 126228 }, -- Warmongering Aspirant's Girdle of Cruelty
				{ 123, 126229 }, -- Warmongering Aspirant's Warboots of Cruelty
			},
			[HORDE_DIFF] = {
				-- ilvl 710
				{ 1, 126407, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Plate Helmet
				{ 2, 126412, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Plate Visor
				{ 4, 126409, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Shoulderplates
				{ 5, 126414, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Plate Pauldrons
				{ 7, 126405, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Plate Breastplate
				{ 8, 126410, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Plate Chestguard
				{ 10, 126406, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Plate Gloves
				{ 11, 126411, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Plate Grips
				{ 16, 126402, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Armplates of Cruelty
				{ 17, 126403, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Armplates of Prowess
				{ 18, 126404, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Armplates of Victory
				{ 20, 126408, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Legplates
				{ 21, 126413, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Warmongering Gladiator's Plate Leggings
				{ 23, 126396, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Girdle of Cruelty
				{ 24, 126397, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Girdle of Prowess
				{ 25, 126398, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Girdle of Victory
				{ 27, 126399, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Warboots of Cruelty
				{ 28, 126400, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Warboots of Prowess
				{ 29, 126401, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Warboots of Victory
				-- ilvl 680
				{ 101, 126588 }, -- Warmongering Combatant's Plate Helmet
				{ 103, 126590 }, -- Warmongering Combatant's Shoulderplates
				{ 105, 126586 }, -- Warmongering Combatant's Plate Breastplate
				{ 107, 126587 }, -- Warmongering Combatant's Plate Gloves
				{ 109, 126584, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Armplates of Cruelty
				{ 110, 126585, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Armplates of Prowess
				{ 112, 126589 }, -- Warmongering Combatant's Legplates
				{ 114, 126580, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Girdle of Cruelty
				{ 115, 126581, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Girdle of Prowess
				{ 116, 126582, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Warboots of Cruelty
				{ 117, 126583, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Warboots of Prowess
				-- ilvl 625
				{ 119, 126707 }, -- Warmongering Aspirant's Armplates of Cruelty
				{ 121, 126705 }, -- Warmongering Aspirant's Girdle of Cruelty
				{ 123, 126706 }, -- Warmongering Aspirant's Warboots of Cruelty
			},
		},
		{
			name = AL["Amulets"],
			[ALLIANCE_DIFF] = {
				-- ilvl 710
				{ 1, 125801, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Necklace of Cruelty
				{ 2, 125802, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Necklace of Prowess
				{ 3, 125851, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Pendant of Cruelty
				{ 4, 125852, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Pendant of Prowess
				{ 5, 125853, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Pendant of Meditation
				{ 6, 125854, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Pendant of Contemplation
				{ 7, 125960, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Choker of Cruelty
				{ 8, 125961, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Choker of Prowess
				{ 9, 125967, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Choker of Endurance
				-- ilvl 680
				{ 16, 126011, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Necklace of Cruelty
				{ 17, 126012, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Necklace of Prowess
				{ 18, 126053, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Pendant of Cruelty
				{ 19, 126054, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Pendant of Prowess
				{ 20, 126055, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Pendant of Meditation
				{ 21, 126056, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Pendant of Contemplation
				{ 22, 126138, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Choker of Cruelty
				{ 23, 126139, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Choker of Prowess
				{ 24, 126164, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Choker of Endurance
				-- ilvl 625
				{ 11, 126178 }, -- Warmongering Aspirant's Necklace of Cruelty
				{ 12, 126201 }, -- Warmongering Aspirant's Pendant of Cruelty
				{ 13, 126202 }, -- Warmongering Aspirant's Pendant of Meditation
				{ 14, 126247 }, -- Warmongering Aspirant's Choker of Cruelty
				{ 15, 126250 }, -- Warmongering Aspirant's Choker of Endurance
			},
			[HORDE_DIFF] = {
				-- ilvl 710
				{ 1, 126280, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Necklace of Cruelty
				{ 2, 126281, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Necklace of Prowess
				{ 3, 126330, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Pendant of Cruelty
				{ 4, 126331, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Pendant of Prowess
				{ 5, 126332, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Pendant of Meditation
				{ 6, 126333, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Pendant of Contemplation
				{ 7, 126439, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Choker of Cruelty
				{ 8, 126440, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Choker of Prowess
				{ 9, 126446, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Choker of Endurance
				-- ilvl 680
				{ 16, 126488, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Necklace of Cruelty
				{ 17, 126489, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Necklace of Prowess
				{ 18, 126530, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Pendant of Cruelty
				{ 19, 126531, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Pendant of Prowess
				{ 20, 126532, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Pendant of Meditation
				{ 21, 126533, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Pendant of Contemplation
				{ 22, 126615, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Choker of Cruelty
				{ 23, 126616, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Choker of Prowess
				{ 24, 126641, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Choker of Endurance
				-- ilvl 625
				{ 11, 126655 }, -- Warmongering Aspirant's Necklace of Cruelty
				{ 12, 126678 }, -- Warmongering Aspirant's Pendant of Cruelty
				{ 13, 126679 }, -- Warmongering Aspirant's Pendant of Meditation
				{ 14, 126724 }, -- Warmongering Aspirant's Choker of Cruelty
				{ 15, 126727 }, -- Warmongering Aspirant's Choker of Endurance
			},
		},
		{
			name = AL["Cloaks"],
			[ALLIANCE_DIFF] = {
				-- ilvl 710
				{ 1, 125799, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Cape of Cruelty
				{ 2, 125800, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Cape of Prowess
				{ 3, 125847, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Drape of Cruelty
				{ 4, 125848, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Drape of Prowess
				{ 5, 125849, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Drape of Meditation
				{ 6, 125850, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Drape of Contemplation
				{ 7, 125958, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Cloak of Cruelty
				{ 8, 125959, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Cloak of Prowess
				{ 9, 125966, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Cloak of Endurance
				-- ilvl 680
				{ 16, 126009, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Cape of Cruelty
				{ 17, 126010, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Cape of Prowess
				{ 18, 126049, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Drape of Cruelty
				{ 19, 126050, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Drape of Prowess
				{ 20, 126051, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Drape of Meditation
				{ 21, 126052, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Drape of Contemplation
				{ 22, 126136, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Cloak of Cruelty
				{ 23, 126137, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Cloak of Prowess
				{ 24, 126163, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Cloak of Endurance
				-- ilvl 625
				{ 11, 126177 }, -- Warmongering Aspirant's Cape of Cruelty
				{ 12, 126199 }, -- Warmongering Aspirant's Drape of Cruelty
				{ 13, 126200 }, -- Warmongering Aspirant's Drape of Meditation
				{ 14, 126246 }, -- Warmongering Aspirant's Cloak of Cruelty
				{ 15, 126249 }, -- Warmongering Aspirant's Cloak of Endurance
			},
			[HORDE_DIFF] = {
				-- ilvl 710
				{ 1, 126278, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Cape of Cruelty
				{ 2, 126279, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Cape of Prowess
				{ 3, 126326, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Drape of Cruelty
				{ 4, 126327, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Drape of Prowess
				{ 5, 126328, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Drape of Meditation
				{ 6, 126329, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Drape of Contemplation
				{ 7, 126437, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Cloak of Cruelty
				{ 8, 126438, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Cloak of Prowess
				{ 9, 126445, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Cloak of Endurance
				-- ilvl 680
				{ 16, 126486, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Cape of Cruelty
				{ 17, 126487, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Cape of Prowess
				{ 18, 126526, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Drape of Cruelty
				{ 19, 126527, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Drape of Prowess
				{ 20, 126528, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Drape of Meditation
				{ 21, 126529, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Drape of Contemplation
				{ 22, 126613, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Cloak of Cruelty
				{ 23, 126614, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Cloak of Prowess
				{ 24, 126640, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Cloak of Endurance
				-- ilvl 625
				{ 11, 126654 }, -- Warmongering Aspirant's Cape of Cruelty
				{ 12, 126676 }, -- Warmongering Aspirant's Drape of Cruelty
				{ 13, 126677 }, -- Warmongering Aspirant's Drape of Meditation
				{ 14, 126723 }, -- Warmongering Aspirant's Cloak of Cruelty
				{ 15, 126726 }, -- Warmongering Aspirant's Cloak of Endurance
			},
		},
		{
			name = AL["Rings"],
			[ALLIANCE_DIFF] = {
				-- ilvl 710
				{ 1, 125803, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Ring of Cruelty
				{ 2, 125804, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Ring of Prowess
				{ 3, 125805, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Ring of Triumph
				{ 4, 125857, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Band of Cruelty
				{ 5, 125858, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Band of Prowess
				{ 6, 125859, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Band of Victory
				{ 7, 125860, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Band of Meditation
				{ 8, 125861, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Band of Contemplation
				{ 9, 125962, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Signet of Cruelty
				{ 10, 125963, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Signet of Accuracy
				{ 11, 125964, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Signet of Ruthlessness
				{ 12, 125968, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Signet of Dedication
				{ 13, 125969, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Signet of Endurance
				-- ilvl 680
				{ 16, 126013, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Ring of Cruelty
				{ 17, 126014, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Ring of Prowess
				{ 18, 126015, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Ring of Triumph
				{ 19, 126059, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Band of Cruelty
				{ 20, 126060, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Band of Prowess
				{ 21, 126061, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Band of Victory
				{ 22, 126062, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Band of Meditation
				{ 23, 126063, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Band of Contemplation
				{ 24, 126140, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Signet of Cruelty
				{ 25, 126141, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Signet of Accuracy
				{ 26, 126142, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Signet of Ruthlessness
				{ 27, 126165, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Signet of Dedication
				{ 28, 126166, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Signet of Endurance
				-- ilvl 625
				{ 101, 126179 }, -- Warmongering Aspirant's Ring of Cruelty
				{ 102, 126180 }, -- Warmongering Aspirant's Ring of Prowess
				{ 103, 126203 }, -- Warmongering Aspirant's Band of Cruelty
				{ 104, 126204 }, -- Warmongering Aspirant's Band of Prowess
				{ 105, 126205 }, -- Warmongering Aspirant's Band of Meditation
				{ 106, 126206 }, -- Warmongering Aspirant's Band of Contemplation
				{ 107, 126248 }, -- Warmongering Aspirant's Signet of Cruelty
				{ 108, 126251 }, -- Warmongering Aspirant's Signet of Dedication
				{ 109, 126252 }, -- Warmongering Aspirant's Signet of Endurance
				{ 110, 127120 }, -- Warmongering Aspirant's Signet of Accuracy
			},
			[HORDE_DIFF] = {
				-- ilvl 710
				{ 1, 126282, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Ring of Cruelty
				{ 2, 126283, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Ring of Prowess
				{ 3, 126284, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Ring of Triumph
				{ 4, 126336, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Band of Cruelty
				{ 5, 126337, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Band of Prowess
				{ 6, 126338, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Band of Victory
				{ 7, 126339, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Band of Meditation
				{ 8, 126340, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Band of Contemplation
				{ 9, 126441, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Signet of Cruelty
				{ 10, 126442, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Signet of Accuracy
				{ 11, 126443, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Signet of Ruthlessness
				{ 12, 126447, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Signet of Dedication
				{ 13, 126448, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Warmongering Gladiator's Signet of Endurance
				-- ilvl 680
				{ 16, 126490, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Ring of Cruelty
				{ 17, 126491, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Ring of Prowess
				{ 18, 126492, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Ring of Triumph
				{ 19, 126536, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Band of Cruelty
				{ 20, 126537, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Band of Prowess
				{ 21, 126538, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Band of Victory
				{ 22, 126539, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Band of Meditation
				{ 23, 126540, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Band of Contemplation
				{ 24, 126617, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Signet of Cruelty
				{ 25, 126618, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Signet of Accuracy
				{ 26, 126619, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Signet of Ruthlessness
				{ 27, 126642, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Signet of Dedication
				{ 28, 126643, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Warmongering Combatant's Signet of Endurance
				-- ilvl 625
				{ 101, 126656 }, -- Warmongering Aspirant's Ring of Cruelty
				{ 102, 126657 }, -- Warmongering Aspirant's Ring of Prowess
				{ 103, 126680 }, -- Warmongering Aspirant's Band of Cruelty
				{ 104, 126681 }, -- Warmongering Aspirant's Band of Prowess
				{ 105, 126682 }, -- Warmongering Aspirant's Band of Meditation
				{ 106, 126683 }, -- Warmongering Aspirant's Band of Contemplation
				{ 107, 126725 }, -- Warmongering Aspirant's Signet of Cruelty
				{ 108, 126728 }, -- Warmongering Aspirant's Signet of Dedication
				{ 109, 126729 }, -- Warmongering Aspirant's Signet of Endurance
				{ 110, 127121 }, -- Warmongering Aspirant's Signet of Accuracy
			},
		},
		{
			name = AL["Trinkets"],
			[ALLIANCE_DIFF] = {
				-- ilvl 710
				{ 1, 125970, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Badge of Conquest
				{ 2, 125975, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Badge of Dominance
				{ 3, 125981, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Badge of Victory
				{ 4, 125983, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Badge of Adaptation
				{ 6, 125972, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Emblem of Cruelty
				{ 7, 125973, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Emblem of Tenacity
				{ 8, 125974, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Emblem of Meditation
				{ 10, 125971, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Insignia of Conquest
				{ 11, 125976, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Insignia of Dominance
				{ 12, 125982, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Insignia of Victory
				{ 16, 125977, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Medallion of Cruelty
				{ 17, 125979, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Medallion of Tenacity
				{ 18, 125980, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Medallion of Meditation
				{ 19, 127125, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Medallion of Adaptation
				{ 21, 125984 }, -- Warmongering Gladiator's Accolade of Conquest
				{ 22, 125985 }, -- Warmongering Gladiator's Accolade of Dominance
				{ 23, 125986 }, -- Warmongering Gladiator's Accolade of Victory
				{ 24, 125987 }, -- Warmongering Gladiator's Accolade of Meditation
				{ 25, 125988 }, -- Warmongering Gladiator's Accolade of Endurance
				-- ilvl 680
				{ 101, 126144, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Badge of Conquest
				{ 102, 126149, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Badge of Dominance
				{ 103, 126155, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Badge of Victory
				{ 104, 126157, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Badge of Adaptation
				{ 106, 126146, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Emblem of Cruelty
				{ 107, 126147, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Emblem of Tenacity
				{ 108, 126148, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Emblem of Meditation
				{ 110, 126145, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Insignia of Conquest
				{ 111, 126150, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Insignia of Dominance
				{ 112, 126156, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Insignia of Victory
				{ 116, 126151, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Medallion of Cruelty
				{ 117, 126153, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Medallion of Tenacity
				{ 118, 126154, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Medallion of Meditation
				{ 119, 126152, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Medallion of Adaptation
				{ 121, 126158 }, -- Warmongering Combatant's Accolade of Conquest
				{ 122, 126159 }, -- Warmongering Combatant's Accolade of Dominance
				{ 123, 126160 }, -- Warmongering Combatant's Accolade of Victory
				{ 124, 126161 }, -- Warmongering Combatant's Accolade of Meditation
				{ 125, 126162 }, -- Warmongering Combatant's Accolade of Endurance
				-- ilvl 625
				{ 114, 126253 }, -- Warmongering Aspirant's Accolade of Conquest
				{ 115, 126254 }, -- Warmongering Aspirant's Accolade of Dominance
				{ 127, 126255 }, -- Warmongering Aspirant's Accolade of Victory
				{ 128, 126256 }, -- Warmongering Aspirant's Accolade of Meditation
				{ 129, 126257 }, -- Warmongering Aspirant's Accolade of Endurance
			},
			[HORDE_DIFF] = {
				-- ilvl 710
				{ 1, 126449, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Badge of Conquest
				{ 2, 126454, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Badge of Dominance
				{ 3, 126458, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Badge of Victory
				{ 4, 126460, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Badge of Adaptation
				{ 6, 126451, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Emblem of Cruelty
				{ 7, 126452, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Emblem of Tenacity
				{ 8, 126453, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Emblem of Meditation
				{ 10, 126450, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Insignia of Conquest
				{ 11, 126455, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Insignia of Dominance
				{ 12, 126459, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Insignia of Victory
				{ 16, 127126, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Medallion of Cruelty
				{ 17, 126456, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Medallion of Tenacity
				{ 18, 126457, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Medallion of Meditation
				{ 19, 125978, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Warmongering Gladiator's Medallion of Adaptation
				{ 21, 126461 }, -- Warmongering Gladiator's Accolade of Conquest
				{ 22, 126462 }, -- Warmongering Gladiator's Accolade of Dominance
				{ 23, 126463 }, -- Warmongering Gladiator's Accolade of Victory
				{ 24, 126464 }, -- Warmongering Gladiator's Accolade of Meditation
				{ 25, 126465 }, -- Warmongering Gladiator's Accolade of Endurance
				-- ilvl 680
				{ 101, 126621, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Badge of Conquest
				{ 102, 126626, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Badge of Dominance
				{ 103, 126632, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Badge of Victory
				{ 104, 126634, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Badge of Adaptation
				{ 106, 126623, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Emblem of Cruelty
				{ 107, 126624, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Emblem of Tenacity
				{ 108, 126625, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Emblem of Meditation
				{ 110, 126622, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Insignia of Conquest
				{ 111, 126627, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Insignia of Dominance
				{ 112, 126633, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Insignia of Victory
				{ 116, 126628, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Medallion of Cruelty
				{ 117, 126629, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Medallion of Adaptation
				{ 118, 126630, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Medallion of Tenacity
				{ 119, 126631, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Warmongering Combatant's Medallion of Meditation
				{ 121, 126635 }, -- Warmongering Combatant's Accolade of Conquest
				{ 122, 126636 }, -- Warmongering Combatant's Accolade of Dominance
				{ 123, 126637 }, -- Warmongering Combatant's Accolade of Victory
				{ 124, 126638 }, -- Warmongering Combatant's Accolade of Meditation
				{ 125, 126639 }, -- Warmongering Combatant's Accolade of Endurance
				-- ilvl 625
				{ 114, 126730 }, -- Warmongering Aspirant's Accolade of Conquest
				{ 115, 126731 }, -- Warmongering Aspirant's Accolade of Dominance
				{ 127, 126732 }, -- Warmongering Aspirant's Accolade of Victory
				{ 128, 126733 }, -- Warmongering Aspirant's Accolade of Meditation
				{ 129, 126734 }, -- Warmongering Aspirant's Accolade of Endurance
			},
		},
		{
			name = AL["Miscellaneous"],
			[ALLIANCE_DIFF] = {
				-- ilvl 710
				{ 1, 127369, [PRICE_EXTRA_ITTYPE] = "conquest:1000" }, -- Warmongering Gladiator's Tabard
				{ 3, 120286, [PRICE_EXTRA_ITTYPE] = "conquest:2500" }, -- Enchanter's Illusion - Glorious Tyranny
				{ 4, 120287, [PRICE_EXTRA_ITTYPE] = "conquest:2500" }, -- Enchanter's Illusion - Primal Victory
				-- ilvl 680
				-- ilvl 625
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				-- ilvl 710
				{ 1, 127371, [PRICE_EXTRA_ITTYPE] = "conquest:1000" }, -- Warmongering Gladiator's Tabard
				-- ilvl 680
				-- ilvl 625
			},
		},
	},
}

--[[
data["WODS3WEAPONS"] = {
	name = string.format(AL["Warlords Season %d"], 3).." "..AL["Weapons"],
	ContentType = NORMAL_ITTYPE,
	items = {
		{
			name = string.format(AL["ilvl %d"], 705).." "..AL["Elite"],
			[ALLIANCE_DIFF] = {
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
		{
			name = string.format(AL["ilvl %d"], 705).." (735)",
			[ALLIANCE_DIFF] = {
			},
			[HORDE_DIFF] = {
			},
		},
		{
			name = string.format(AL["ilvl %d"], 680).." (710)",
			[ALLIANCE_DIFF] = {
			},
			[HORDE_DIFF] = {
			},
		},
	},
}
]]
data["WODS2SETS"] = {
	name = string.format(AL["Warlords Season %d"], 2).." "..AL["Class Sets"],
	ContentType = NORMAL_ITTYPE,
	items = {
		{
			name = LOCALIZED_CLASS_NAMES_MALE["DEATHKNIGHT"],
			[ALLIANCE_DIFF] = {
				{ 1, 124713, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Dreadplate Helm
				{ 2, 124715, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Dreadplate Shoulders
				{ 3, 124711, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Dreadplate Chestpiece
				{ 4, 124712, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Dreadplate Gauntlets
				{ 5, 124714, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Dreadplate Legguards
				{ 7, 124915, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Dreadplate Helm
				{ 8, 124917, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Dreadplate Shoulders
				{ 9, 124913, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Dreadplate Chestpiece
				{ 10, 124914, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Dreadplate Gauntlets
				{ 11, 124916, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Dreadplate Legguards
				{ 16, 125072  }, -- Wild Aspirant's Dreadplate Helm
				{ 17, 125074  }, -- Wild Aspirant's Dreadplate Shoulders
				{ 18, 125070  }, -- Wild Aspirant's Dreadplate Chestpiece
				{ 19, 125071  }, -- Wild Aspirant's Dreadplate Gauntlets
				{ 20, 125073  }, -- Wild Aspirant's Dreadplate Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 125192, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Dreadplate Helm
				{ 2, 125194, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Dreadplate Shoulders
				{ 3, 125190, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Dreadplate Chestpiece
				{ 4, 125191, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Dreadplate Gauntlets
				{ 5, 125193, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Dreadplate Legguards
				{ 7, 125392, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Dreadplate Helm
				{ 8, 125394, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Dreadplate Shoulders
				{ 9, 125390, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Dreadplate Chestpiece
				{ 10, 125391, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Dreadplate Gauntlets
				{ 11, 125393, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Dreadplate Legguards
				{ 16, 125549  }, -- Wild Aspirant's Dreadplate Helm
				{ 17, 125551  }, -- Wild Aspirant's Dreadplate Shoulders
				{ 18, 125547  }, -- Wild Aspirant's Dreadplate Chestpiece
				{ 19, 125548  }, -- Wild Aspirant's Dreadplate Gauntlets
				{ 20, 125550  }, -- Wild Aspirant's Dreadplate Legguards
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["DRUID"],
			[ALLIANCE_DIFF] = {
				{ 1, 124717, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Dragonhide Helm
				{ 2, 124720, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Dragonhide Spaulders
				{ 3, 124719, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Dragonhide Robes
				{ 4, 124716, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Dragonhide Gloves
				{ 5, 124718, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Dragonhide Legguards
				{ 7, 124919, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Dragonhide Helm
				{ 8, 124922, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Dragonhide Spaulders
				{ 9, 124921, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Dragonhide Tunic
				{ 10, 124918, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Dragonhide Gloves
				{ 11, 124920, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Dragonhide Legguards
				{ 16, 125076  }, -- Wild Aspirant's Dragonhide Helm
				{ 17, 125079  }, -- Wild Aspirant's Dragonhide Spaulders
				{ 18, 125078  }, -- Wild Aspirant's Dragonhide Tunic
				{ 19, 125075  }, -- Wild Aspirant's Dragonhide Gloves
				{ 20, 125077  }, -- Wild Aspirant's Dragonhide Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 125196, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Dragonhide Helm
				{ 2, 125199, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Dragonhide Spaulders
				{ 3, 125198, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Dragonhide Tunic
				{ 4, 125195, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Dragonhide Gloves
				{ 5, 125197, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Dragonhide Legguards
				{ 7, 125396, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Dragonhide Helm
				{ 8, 125399, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Dragonhide Spaulders
				{ 9, 125398, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Dragonhide Tunic
				{ 10, 125395, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Dragonhide Gloves
				{ 11, 125397, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Dragonhide Legguards
				{ 16, 125553  }, -- Wild Aspirant's Dragonhide Helm
				{ 17, 125556  }, -- Wild Aspirant's Dragonhide Spaulders
				{ 18, 125555  }, -- Wild Aspirant's Dragonhide Tunic
				{ 19, 125552  }, -- Wild Aspirant's Dragonhide Gloves
				{ 20, 125554  }, -- Wild Aspirant's Dragonhide Legguards
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["HUNTER"],
			[ALLIANCE_DIFF] = {
				{ 1, 124723, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Chain Helm
				{ 2, 124725, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Chain Spaulders
				{ 3, 124721, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Chain Armor
				{ 4, 124722, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Chain Gauntlets
				{ 5, 124724, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Chain Leggings
				{ 7, 124925, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Chain Helm
				{ 8, 124927, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Chain Spaulders
				{ 9, 124923, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Chain Armor
				{ 10, 124924, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Chain Gauntlets
				{ 11, 124926, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Chain Leggings
				{ 16, 125082  }, -- Wild Aspirant's Chain Helm
				{ 17, 125084  }, -- Wild Aspirant's Chain Spaulders
				{ 18, 125080  }, -- Wild Aspirant's Chain Armor
				{ 19, 125081  }, -- Wild Aspirant's Chain Gauntlets
				{ 20, 125083  }, -- Wild Aspirant's Chain Leggings
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 125202, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Chain Helm
				{ 2, 125204, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Chain Spaulders
				{ 3, 125200, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Chain Armor
				{ 4, 125201, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Chain Gauntlets
				{ 5, 125203, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Chain Leggings
				{ 7, 125402, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Chain Helm
				{ 8, 125404, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Chain Spaulders
				{ 9, 125400, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Chain Armor
				{ 10, 125401, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Chain Gauntlets
				{ 11, 125403, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Chain Leggings
				{ 16, 125559  }, -- Wild Aspirant's Chain Helm
				{ 17, 125561  }, -- Wild Aspirant's Chain Spaulders
				{ 18, 125557  }, -- Wild Aspirant's Chain Armor
				{ 19, 125558  }, -- Wild Aspirant's Chain Gauntlets
				{ 20, 125560  }, -- Wild Aspirant's Chain Leggings
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["MAGE"],
			[ALLIANCE_DIFF] = {
				{ 1, 124770, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Silk Cowl
				{ 2, 124773, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Silk Amice
				{ 3, 124772, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Silk Robe
				{ 4, 124769, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Silk Handguards
				{ 5, 124771, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Silk Trousers
				{ 7, 124964, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Silk Cowl
				{ 8, 124967, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Silk Amice
				{ 9, 124966, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Silk Robe
				{ 10, 124963, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Silk Handguards
				{ 11, 124965, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Silk Trousers
				{ 16, 125097  }, -- Wild Aspirant's Silk Cowl
				{ 17, 125100  }, -- Wild Aspirant's Silk Amice
				{ 18, 125099  }, -- Wild Aspirant's Silk Robe
				{ 19, 125096  }, -- Wild Aspirant's Silk Handguards
				{ 20, 125098  }, -- Wild Aspirant's Silk Trousers
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 125249, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Silk Cowl
				{ 2, 125252, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Silk Amice
				{ 3, 125251, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Silk Robe
				{ 4, 125248, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Silk Handguards
				{ 5, 125250, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Silk Trousers
				{ 7, 125441, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Silk Cowl
				{ 8, 125444, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Silk Amice
				{ 9, 125443, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Silk Robe
				{ 10, 125440, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Silk Handguards
				{ 11, 125442, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Silk Trousers
				{ 16, 125574  }, -- Wild Aspirant's Silk Cowl
				{ 17, 125577  }, -- Wild Aspirant's Silk Amice
				{ 18, 125576  }, -- Wild Aspirant's Silk Robe
				{ 19, 125573  }, -- Wild Aspirant's Silk Handguards
				{ 20, 125575  }, -- Wild Aspirant's Silk Trousers
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["MONK"],
			[ALLIANCE_DIFF] = {
				{ 1, 124794, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Ironskin Helm
				{ 2, 124796, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Ironskin Spaulders
				{ 3, 124797, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Ironskin Tunic
				{ 4, 124793, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Ironskin Gloves
				{ 5, 124795, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Ironskin Legguards
				{ 7, 124980, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Ironskin Helm
				{ 8, 124982, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Ironskin Spaulders
				{ 9, 124983, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Ironskin Tunic
				{ 10, 124979, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Ironskin Gloves
				{ 11, 124981, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Ironskin Legguards
				{ 16, 125105  }, -- Wild Aspirant's Ironskin Helm
				{ 17, 125107  }, -- Wild Aspirant's Ironskin Spaulders
				{ 18, 125108  }, -- Wild Aspirant's Ironskin Tunic
				{ 19, 125104  }, -- Wild Aspirant's Ironskin Gloves
				{ 20, 125106  }, -- Wild Aspirant's Ironskin Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 125273, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Ironskin Helm
				{ 2, 125275, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Ironskin Spaulders
				{ 3, 125276, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Ironskin Tunic
				{ 4, 125272, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Ironskin Gloves
				{ 5, 125274, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Ironskin Legguards
				{ 7, 125457, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Ironskin Helm
				{ 8, 125459, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Ironskin Spaulders
				{ 9, 125460, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Ironskin Tunic
				{ 10, 125456, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Ironskin Gloves
				{ 11, 125458, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Ironskin Legguards
				{ 16, 125582  }, -- Wild Aspirant's Ironskin Helm
				{ 17, 125584  }, -- Wild Aspirant's Ironskin Spaulders
				{ 18, 125585  }, -- Wild Aspirant's Ironskin Tunic
				{ 19, 125581  }, -- Wild Aspirant's Ironskin Gloves
				{ 20, 125583  }, -- Wild Aspirant's Ironskin Legguards
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["PALADIN"],
			[ALLIANCE_DIFF] = {
				{ 1, 124800, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Scaled Helm
				{ 2, 124802, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Scaled Shoulders
				{ 3, 124798, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Scaled Chestpiece
				{ 4, 124799, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Scaled Gauntlets
				{ 5, 124801, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Scaled Legguards
				{ 7, 124986, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Scaled Helm
				{ 8, 124988, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Scaled Shoulders
				{ 9, 124984, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Scaled Chestpiece
				{ 10, 124985, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Scaled Gauntlets
				{ 11, 124987, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Scaled Legguards
				{ 16, 125111  }, -- Wild Aspirant's Scaled Helm
				{ 17, 125113  }, -- Wild Aspirant's Scaled Shoulders
				{ 18, 125109  }, -- Wild Aspirant's Scaled Chestpiece
				{ 19, 125110  }, -- Wild Aspirant's Scaled Gauntlets
				{ 20, 125112  }, -- Wild Aspirant's Scaled Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 125279, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Scaled Helm
				{ 2, 125281, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Scaled Shoulders
				{ 3, 125277, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Scaled Chestpiece
				{ 4, 125278, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Scaled Gauntlets
				{ 5, 125280, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Scaled Legguards
				{ 7, 125463, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Scaled Helm
				{ 8, 125465, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Scaled Shoulders
				{ 9, 125461, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Scaled Chestpiece
				{ 10, 125462, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Scaled Gauntlets
				{ 11, 125464, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Scaled Legguards
				{ 16, 125588  }, -- Wild Aspirant's Scaled Helm
				{ 17, 125590  }, -- Wild Aspirant's Scaled Shoulders
				{ 18, 125586  }, -- Wild Aspirant's Scaled Chestpiece
				{ 19, 125587  }, -- Wild Aspirant's Scaled Gauntlets
				{ 20, 125589  }, -- Wild Aspirant's Scaled Legguards
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["PRIEST"],
			[ALLIANCE_DIFF] = {
				{ 1, 124823, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Satin Hood
				{ 2, 124826, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Satin Mantle
				{ 3, 124825, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Satin Robe
				{ 4, 124822, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Satin Gloves
				{ 5, 124824, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Satin Leggings
				{ 7, 125001, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Satin Hood
				{ 8, 125004, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Satin Mantle
				{ 9, 125003, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Satin Robe
				{ 10, 125000, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Satin Gloves
				{ 11, 125002, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Satin Leggings
				{ 16, 125118  }, -- Wild Aspirant's Satin Hood
				{ 17, 125121  }, -- Wild Aspirant's Satin Mantle
				{ 18, 125120  }, -- Wild Aspirant's Satin Robe
				{ 19, 125117  }, -- Wild Aspirant's Satin Gloves
				{ 20, 125119  }, -- Wild Aspirant's Satin Leggings
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 125302, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Satin Hood
				{ 2, 125305, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Satin Mantle
				{ 3, 125304, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Satin Robe
				{ 4, 125301, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Satin Gloves
				{ 5, 125303, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Satin Leggings
				{ 7, 125478, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Satin Hood
				{ 8, 125481, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Satin Mantle
				{ 9, 125480, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Satin Robe
				{ 10, 125477, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Satin Gloves
				{ 11, 125479, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Satin Leggings
				{ 16, 125595  }, -- Wild Aspirant's Satin Hood
				{ 17, 125598  }, -- Wild Aspirant's Satin Mantle
				{ 18, 125597  }, -- Wild Aspirant's Satin Robe
				{ 19, 125594  }, -- Wild Aspirant's Satin Gloves
				{ 20, 125596  }, -- Wild Aspirant's Satin Leggings
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["ROGUE"],
			[ALLIANCE_DIFF] = {
				{ 1, 124829, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Leather Helm
				{ 2, 124831, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Leather Spaulders
				{ 3, 124827, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Leather Tunic
				{ 4, 124828, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Leather Gloves
				{ 5, 124830, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Leather Legguards
				{ 7, 125007, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Leather Helm
				{ 8, 125009, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Leather Spaulders
				{ 9, 125005, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Leather Tunic
				{ 10, 125006, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Leather Gloves
				{ 11, 125008, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Leather Legguards
				{ 16, 125124  }, -- Wild Aspirant's Leather Helm
				{ 17, 125126  }, -- Wild Aspirant's Leather Spaulders
				{ 18, 125122  }, -- Wild Aspirant's Leather Tunic
				{ 19, 125123  }, -- Wild Aspirant's Leather Gloves
				{ 20, 125125  }, -- Wild Aspirant's Leather Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 125308, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Leather Helm
				{ 2, 125310, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Leather Spaulders
				{ 3, 125306, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Leather Tunic
				{ 4, 125307, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Leather Gloves
				{ 5, 125309, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Leather Legguards
				{ 7, 125484, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Leather Helm
				{ 8, 125486, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Leather Spaulders
				{ 9, 125482, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Leather Tunic
				{ 10, 125483, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Leather Gloves
				{ 11, 125485, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Leather Legguards
				{ 16, 125601  }, -- Wild Aspirant's Leather Helm
				{ 17, 125603  }, -- Wild Aspirant's Leather Spaulders
				{ 18, 125599  }, -- Wild Aspirant's Leather Tunic
				{ 19, 125600  }, -- Wild Aspirant's Leather Gloves
				{ 20, 125602  }, -- Wild Aspirant's Leather Legguards
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["SHAMAN"],
			[ALLIANCE_DIFF] = {
				{ 1, 124834, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Ringmail Helm
				{ 2, 124836, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Ringmail Spaulders
				{ 3, 124832, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Ringmail Armor
				{ 4, 124833, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Ringmail Gauntlets
				{ 5, 124835, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Ringmail Leggings
				{ 7, 125012, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Ringmail Helm
				{ 8, 125014, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Ringmail Spaulders
				{ 9, 125010, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Ringmail Armor
				{ 10, 125011, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Ringmail Gauntlets
				{ 11, 125013, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Ringmail Leggings
				{ 16, 125129  }, -- Wild Aspirant's Ringmail Helm
				{ 17, 125131  }, -- Wild Aspirant's Ringmail Spaulders
				{ 18, 125127  }, -- Wild Aspirant's Ringmail Armor
				{ 19, 125128  }, -- Wild Aspirant's Ringmail Gauntlets
				{ 20, 125130  }, -- Wild Aspirant's Ringmail Leggings
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 125313, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Ringmail Helm
				{ 2, 125315, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Ringmail Spaulders
				{ 3, 125311, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Ringmail Armor
				{ 4, 125312, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Ringmail Gauntlets
				{ 5, 125314, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Ringmail Leggings
				{ 7, 125489, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Ringmail Helm
				{ 8, 125491, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Ringmail Spaulders
				{ 9, 125487, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Ringmail Armor
				{ 10, 125488, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Ringmail Gauntlets
				{ 11, 125490, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Ringmail Leggings
				{ 16, 125606  }, -- Wild Aspirant's Ringmail Helm
				{ 17, 125608  }, -- Wild Aspirant's Ringmail Spaulders
				{ 18, 125604  }, -- Wild Aspirant's Ringmail Armor
				{ 19, 125605  }, -- Wild Aspirant's Ringmail Gauntlets
				{ 20, 125607  }, -- Wild Aspirant's Ringmail Leggings
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["WARLOCK"],
			[ALLIANCE_DIFF] = {
				{ 1, 124876, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Felweave Cowl
				{ 2, 124879, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Felweave Amice
				{ 3, 124878, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Felweave Raiment
				{ 4, 124875, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Felweave Handguards
				{ 5, 124877, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Felweave Trousers
				{ 7, 125054, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Felweave Cowl
				{ 8, 125057, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Felweave Amice
				{ 9, 125056, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Felweave Raiment
				{ 10, 125053, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Felweave Handguards
				{ 11, 125055, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Felweave Trousers
				{ 16, 125145  }, -- Wild Aspirant's Felweave Cowl
				{ 17, 125148  }, -- Wild Aspirant's Felweave Amice
				{ 18, 125147  }, -- Wild Aspirant's Felweave Raiment
				{ 19, 125144  }, -- Wild Aspirant's Felweave Handguards
				{ 20, 125146  }, -- Wild Aspirant's Felweave Trousers
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 125353, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Felweave Cowl
				{ 2, 125356, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Felweave Amice
				{ 3, 125355, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Felweave Raiment
				{ 4, 125352, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Felweave Handguards
				{ 5, 125354, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Felweave Trousers
				{ 7, 125531, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Felweave Cowl
				{ 8, 125534, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Felweave Amice
				{ 9, 125533, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Felweave Raiment
				{ 10, 125530, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Felweave Handguards
				{ 11, 125532, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Felweave Trousers
				{ 16, 125622  }, -- Wild Aspirant's Felweave Cowl
				{ 17, 125625  }, -- Wild Aspirant's Felweave Amice
				{ 18, 125624  }, -- Wild Aspirant's Felweave Raiment
				{ 19, 125621  }, -- Wild Aspirant's Felweave Handguards
				{ 20, 125623  }, -- Wild Aspirant's Felweave Trousers
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["WARRIOR"],
			[ALLIANCE_DIFF] = {
				{ 1, 124882, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Plate Helm
				{ 2, 124884, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Plate Shoulders
				{ 3, 124880, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Plate Chestpiece
				{ 4, 124881, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Plate Gauntlets
				{ 5, 124883, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Plate Legguards
				{ 7, 125060, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Plate Helm
				{ 8, 125062, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Plate Shoulders
				{ 9, 125058, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Plate Chestpiece
				{ 10, 125059, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Plate Gauntlets
				{ 11, 125061, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Plate Legguards
				{ 16, 125151  }, -- Wild Aspirant's Plate Helm
				{ 17, 125153  }, -- Wild Aspirant's Plate Shoulders
				{ 18, 125149  }, -- Wild Aspirant's Plate Chestpiece
				{ 19, 125150  }, -- Wild Aspirant's Plate Gauntlets
				{ 20, 125152  }, -- Wild Aspirant's Plate Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 125359, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Plate Helm
				{ 2, 125361, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Plate Shoulders
				{ 3, 125357, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Plate Chestpiece
				{ 4, 125358, [PRICE_EXTRA_ITTYPE] = "conquest:1750"  }, -- Wild Gladiator's Plate Gauntlets
				{ 5, 125360, [PRICE_EXTRA_ITTYPE] = "conquest:2250"  }, -- Wild Gladiator's Plate Legguards
				{ 7, 125537, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Plate Helm
				{ 8, 125539, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Plate Shoulders
				{ 9, 125535, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Plate Chestpiece
				{ 10, 125536, [PRICE_EXTRA_ITTYPE] = "honor:1750"  }, -- Wild Combatant's Plate Gauntlets
				{ 11, 125538, [PRICE_EXTRA_ITTYPE] = "honor:2250"  }, -- Wild Combatant's Plate Legguards
				{ 16, 125628  }, -- Wild Aspirant's Plate Helm
				{ 17, 125630  }, -- Wild Aspirant's Plate Shoulders
				{ 18, 125626  }, -- Wild Aspirant's Plate Chestpiece
				{ 19, 125627  }, -- Wild Aspirant's Plate Gauntlets
				{ 20, 125629  }, -- Wild Aspirant's Plate Legguards
			},
		},
	},
}
data["WODS2NONSETGEAR"] = {
	name = string.format(AL["Warlords Season %d"], 2).." "..AL["Non-Set Gear"],
	ContentType = NORMAL_ITTYPE,
	items = {
		{
			name = ALIL["Cloth"],
			[ALLIANCE_DIFF] = {
				-- ilvl 700
				{ 1, 124761, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Helm
				{ 2, 124766, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Headcover
				{ 4, 124763, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Spaulders
				{ 5, 124768, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Pauldrons
				{ 7, 124759, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Tunic
				{ 8, 124764, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Chestguard
				{ 10, 124760, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Gloves
				{ 11, 124765, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Grips
				{ 16, 124762, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Legguards
				{ 17, 124767, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Leggings
				{ 18, 124756, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Bindings of Cruelty
				{ 19, 124757, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Bindings of Prowess
				{ 20, 124758, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Bindings of Victory
				{ 22, 124750, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Belt of Prowess
				{ 23, 124751, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Belt of Cruelty
				{ 24, 124752, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Belt of Victory
				{ 26, 124753, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Boots of Cruelty
				{ 27, 124754, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Boots of Prowess
				{ 28, 124755, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Boots of Victory
				-- ilvl 670
				{ 101, 124960 }, -- Wild Combatant's Helm
				{ 103, 124962 }, -- Wild Combatant's Spaulders
				{ 105, 124958 }, -- Wild Combatant's Tunic
				{ 107, 124959 }, -- Wild Combatant's Gloves
				{ 109, 124956, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Bindings of Cruelty
				{ 110, 124957, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Bindings of Prowess
				{ 112, 124961 }, -- Wild Combatant's Legguards
				{ 114, 124952, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Belt of Prowess
				{ 115, 124953, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Belt of Cruelty
				{ 116, 124954, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Boots of Cruelty
				{ 117, 124955, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Boots of Prowess
				-- ilvl 625
				{ 119, 125095 }, -- Wild Aspirant's Bindings of Cruelty
				{ 121, 125093 }, -- Wild Aspirant's Belt of Prowess
				{ 123, 125094 }, -- Wild Aspirant's Boots of Cruelty
			},
			[HORDE_DIFF] = {
				-- ilvl 700
				{ 1, 125240, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Helm
				{ 2, 125245, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Headcover
				{ 4, 125242, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Spaulders
				{ 5, 125247, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Pauldrons
				{ 7, 125238, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Tunic
				{ 8, 125243, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Chestguard
				{ 10, 125239, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Gloves
				{ 11, 125244, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Grips
				{ 16, 125235, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Bindings of Cruelty
				{ 17, 125236, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Bindings of Prowess
				{ 18, 125237, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Bindings of Victory
				{ 19, 125241, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Legguards
				{ 20, 125246, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Leggings
				{ 22, 125229, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Belt of Prowess
				{ 23, 125230, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Belt of Cruelty
				{ 24, 125231, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Belt of Victory
				{ 26, 125232, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Boots of Cruelty
				{ 27, 125233, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Boots of Prowess
				{ 28, 125234, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Boots of Victory
				-- ilvl 670
				{ 101, 125437 }, -- Wild Combatant's Helm
				{ 103, 125439 }, -- Wild Combatant's Spaulders
				{ 105, 125435 }, -- Wild Combatant's Tunic
				{ 107, 125436 }, -- Wild Combatant's Gloves
				{ 109, 125433, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Bindings of Cruelty
				{ 110, 125434, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Bindings of Prowess
				{ 112, 125438 }, -- Wild Combatant's Legguards
				{ 114, 125429, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Belt of Prowess
				{ 115, 125430, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Belt of Cruelty
				{ 116, 125431, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Boots of Cruelty
				{ 117, 125432, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Boots of Prowess
				-- ilvl 625
				{ 119, 125572 }, -- Wild Aspirant's Bindings of Cruelty
				{ 121, 125570 }, -- Wild Aspirant's Belt of Prowess
				{ 123, 125571 }, -- Wild Aspirant's Boots of Cruelty
			},
		},
		{
			name = ALIL["Leather"],
			[ALLIANCE_DIFF] = {
				-- ilvl 700
				{ 1, 124761, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Helm
				{ 2, 124766, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Headcover
				{ 4, 124763, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Spaulders
				{ 5, 124768, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Pauldrons
				{ 7, 124759, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Tunic
				{ 8, 124764, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Chestguard
				{ 10, 124760, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Gloves
				{ 11, 124765, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Grips
				{ 16, 124762, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Legguards
				{ 17, 124767, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Leggings
				{ 18, 124756, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Bindings of Cruelty
				{ 19, 124757, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Bindings of Prowess
				{ 20, 124758, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Bindings of Victory
				{ 22, 124750, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Belt of Prowess
				{ 23, 124751, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Belt of Cruelty
				{ 24, 124752, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Belt of Victory
				{ 26, 124753, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Boots of Cruelty
				{ 27, 124754, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Boots of Prowess
				{ 28, 124755, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Boots of Victory
				-- ilvl 670
				{ 101, 124960 }, -- Wild Combatant's Helm
				{ 103, 124962 }, -- Wild Combatant's Spaulders
				{ 105, 124958 }, -- Wild Combatant's Tunic
				{ 107, 124959 }, -- Wild Combatant's Gloves
				{ 109, 124956, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Bindings of Cruelty
				{ 110, 124957, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Bindings of Prowess
				{ 112, 124961 }, -- Wild Combatant's Legguards
				{ 114, 124952, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Belt of Prowess
				{ 115, 124953, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Belt of Cruelty
				{ 116, 124954, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Boots of Cruelty
				{ 117, 124955, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Boots of Prowess
				-- ilvl 625
				{ 119, 125095 }, -- Wild Aspirant's Bindings of Cruelty
				{ 121, 125093 }, -- Wild Aspirant's Belt of Prowess
				{ 123, 125094 }, -- Wild Aspirant's Boots of Cruelty
			},
			[HORDE_DIFF] = {
				-- ilvl 700
				{ 1, 125240, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Helm
				{ 2, 125245, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Headcover
				{ 4, 125242, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Spaulders
				{ 5, 125247, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Pauldrons
				{ 7, 125238, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Tunic
				{ 8, 125243, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Chestguard
				{ 10, 125239, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Gloves
				{ 11, 125244, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Grips
				{ 16, 125235, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Bindings of Cruelty
				{ 17, 125236, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Bindings of Prowess
				{ 18, 125237, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Bindings of Victory
				{ 19, 125241, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Legguards
				{ 20, 125246, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Leggings
				{ 22, 125229, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Belt of Prowess
				{ 23, 125230, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Belt of Cruelty
				{ 24, 125231, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Belt of Victory
				{ 26, 125232, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Boots of Cruelty
				{ 27, 125233, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Boots of Prowess
				{ 28, 125234, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Boots of Victory
				-- ilvl 670
				{ 101, 125437 }, -- Wild Combatant's Helm
				{ 103, 125439 }, -- Wild Combatant's Spaulders
				{ 105, 125435 }, -- Wild Combatant's Tunic
				{ 107, 125436 }, -- Wild Combatant's Gloves
				{ 109, 125433, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Bindings of Cruelty
				{ 110, 125434, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Bindings of Prowess
				{ 112, 125438 }, -- Wild Combatant's Legguards
				{ 114, 125429, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Belt of Prowess
				{ 115, 125430, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Belt of Cruelty
				{ 116, 125431, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Boots of Cruelty
				{ 117, 125432, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Boots of Prowess
				-- ilvl 625
				{ 119, 125572 }, -- Wild Aspirant's Bindings of Cruelty
				{ 121, 125570 }, -- Wild Aspirant's Belt of Prowess
				{ 123, 125571 }, -- Wild Aspirant's Boots of Cruelty
			},
		},
		{
			name = ALIL["Mail"],
			[ALLIANCE_DIFF] = {
				-- ilvl 700
				{ 1, 124785, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Helm
				{ 2, 124790, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Coif
				{ 4, 124787, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Spaulders
				{ 5, 124792, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Pauldrons
				{ 7, 124783, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Armor
				{ 8, 124788, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Chestguard
				{ 10, 124784, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Gauntlets
				{ 11, 124789, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Gloves
				{ 16, 124780, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Armbands of Prowess
				{ 17, 124781, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Armbands of Cruelty
				{ 18, 124782, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Armbands of Victory
				{ 19, 124786, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Leggings
				{ 20, 124791, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Leggings
				{ 22, 124774, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Waistguard of Cruelty
				{ 23, 124775, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Waistguard of Prowess
				{ 24, 124776, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Waistguard of Victory
				{ 26, 124777, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Footguards of Cruelty
				{ 27, 124778, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Footguards of Prowess
				{ 28, 124779, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Footguards of Victory
				-- ilvl 670
				{ 101, 124976 }, -- Wild Combatant's Helm
				{ 103, 124978 }, -- Wild Combatant's Spaulders
				{ 105, 124974 }, -- Wild Combatant's Armor
				{ 107, 124975 }, -- Wild Combatant's Gauntlets
				{ 109, 124972, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Armbands of Prowess
				{ 110, 124973, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Armbands of Cruelty
				{ 112, 124977 }, -- Wild Combatant's Leggings
				{ 114, 124968, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Waistguard of Cruelty
				{ 115, 124969, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Waistguard of Prowess
				{ 116, 124970, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Footguards of Cruelty
				{ 117, 124971, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Footguards of Prowess
				-- ilvl 625
				{ 119, 125103 }, -- Wild Aspirant's Armbands of Prowess
				{ 121, 125101 }, -- Wild Aspirant's Waistguard of Cruelty
				{ 123, 125102 }, -- Wild Aspirant's Footguards of Cruelty
			},
			[HORDE_DIFF] = {
				-- ilvl 700
				{ 1, 125264, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Helm
				{ 2, 125269, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Coif
				{ 4, 125266, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Spaulders
				{ 5, 125271, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Pauldrons
				{ 7, 125262, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Armor
				{ 8, 125267, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Chestguard
				{ 10, 125263, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Gauntlets
				{ 11, 125268, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Gloves
				{ 16, 125259, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Armbands of Prowess
				{ 17, 125260, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Armbands of Cruelty
				{ 18, 125261, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Armbands of Victory
				{ 19, 125265, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Leggings
				{ 20, 125270, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Leggings
				{ 22, 125253, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Waistguard of Cruelty
				{ 23, 125254, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Waistguard of Prowess
				{ 24, 125255, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Waistguard of Victory
				{ 26, 125256, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Footguards of Cruelty
				{ 27, 125257, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Footguards of Prowess
				{ 28, 125258, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Footguards of Victory
				-- ilvl 670
				{ 101, 125453 }, -- Wild Combatant's Helm
				{ 103, 125455 }, -- Wild Combatant's Spaulders
				{ 105, 125451 }, -- Wild Combatant's Armor
				{ 107, 125452 }, -- Wild Combatant's Gauntlets
				{ 109, 125449, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Armbands of Prowess
				{ 110, 125450, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Armbands of Cruelty
				{ 112, 125454 }, -- Wild Combatant's Leggings
				{ 114, 125445, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Waistguard of Cruelty
				{ 115, 125446, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Waistguard of Prowess
				{ 116, 125447, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Footguards of Cruelty
				{ 117, 125448, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Footguards of Prowess
				-- ilvl 625
				{ 119, 125580 }, -- Wild Aspirant's Armbands of Prowess
				{ 121, 125578 }, -- Wild Aspirant's Waistguard of Cruelty
				{ 123, 125579 }, -- Wild Aspirant's Footguards of Cruelty
			},
		},
		{
			name = ALIL["Plate"],
			[ALLIANCE_DIFF] = {
				-- ilvl 700
				{ 1, 124814, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Plate Helmet
				{ 2, 124819, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Plate Visor
				{ 4, 124816, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Shoulderplates
				{ 5, 124821, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Plate Pauldrons
				{ 7, 124812, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Plate Breastplate
				{ 8, 124817, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Plate Chestguard
				{ 10, 124813, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Plate Gloves
				{ 11, 124818, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Plate Grips
				{ 16, 124809, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Armplates of Cruelty
				{ 17, 124810, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Armplates of Prowess
				{ 18, 124811, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Armplates of Victory
				{ 19, 124815, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Legplates
				{ 20, 124820, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Plate Leggings
				{ 22, 124803, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Girdle of Cruelty
				{ 23, 124804, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Girdle of Prowess
				{ 24, 124805, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Girdle of Victory
				{ 26, 124806, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Warboots of Cruelty
				{ 27, 124807, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Warboots of Prowess
				{ 28, 124808, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Warboots of Victory
				-- ilvl 670
				{ 101, 124997 }, -- Wild Combatant's Plate Helmet
				{ 103, 124999 }, -- Wild Combatant's Shoulderplates
				{ 105, 124995 }, -- Wild Combatant's Plate Breastplate
				{ 107, 124996 }, -- Wild Combatant's Plate Gloves
				{ 109, 124993, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Armplates of Cruelty
				{ 110, 124994, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Armplates of Prowess
				{ 112, 124998 }, -- Wild Combatant's Legplates
				{ 114, 124989, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Girdle of Cruelty
				{ 115, 124990, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Girdle of Prowess
				{ 116, 124991, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Warboots of Cruelty
				{ 117, 124992, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Warboots of Prowess
				-- ilvl 625
				{ 119, 125116 }, -- Wild Aspirant's Armplates of Cruelty
				{ 121, 125114 }, -- Wild Aspirant's Girdle of Cruelty
				{ 123, 125115 }, -- Wild Aspirant's Warboots of Cruelty
			},
			[HORDE_DIFF] = {
				-- ilvl 700
				{ 1, 125293, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Plate Helmet
				{ 2, 125298, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Plate Visor
				{ 4, 125295, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Shoulderplates
				{ 5, 125300, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Plate Pauldrons
				{ 7, 125291, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Plate Breastplate
				{ 8, 125296, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Plate Chestguard
				{ 10, 125292, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Plate Gloves
				{ 11, 125297, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Plate Grips
				{ 16, 125288, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Armplates of Cruelty
				{ 17, 125289, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Armplates of Prowess
				{ 18, 125290, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Armplates of Victory
				{ 19, 125294, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Legplates
				{ 20, 125299, [PRICE_EXTRA_ITTYPE] = "conquest:2250" }, -- Wild Gladiator's Plate Leggings
				{ 22, 125282, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Girdle of Cruelty
				{ 23, 125283, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Girdle of Prowess
				{ 24, 125284, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Girdle of Victory
				{ 26, 125285, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Warboots of Cruelty
				{ 27, 125286, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Warboots of Prowess
				{ 28, 125287, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Warboots of Victory
				-- ilvl 670
				{ 101, 125474 }, -- Wild Combatant's Plate Helmet
				{ 103, 125476 }, -- Wild Combatant's Shoulderplates
				{ 105, 125472 }, -- Wild Combatant's Plate Breastplate
				{ 107, 125473 }, -- Wild Combatant's Plate Gloves
				{ 109, 125470, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Armplates of Cruelty
				{ 110, 125471, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Armplates of Prowess
				{ 112, 125475 }, -- Wild Combatant's Legplates
				{ 114, 125466, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Girdle of Cruelty
				{ 115, 125467, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Girdle of Prowess
				{ 116, 125468, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Warboots of Cruelty
				{ 117, 125469, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Warboots of Prowess
				-- ilvl 625
				{ 119, 125593 }, -- Wild Aspirant's Armplates of Cruelty
				{ 121, 125591 }, -- Wild Aspirant's Girdle of Cruelty
				{ 123, 125592 }, -- Wild Aspirant's Warboots of Cruelty
			},
		},
		{
			name = AL["Amulets"],
			[ALLIANCE_DIFF] = {
				-- ilvl 700
				{ 1, 124687, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Necklace of Cruelty
				{ 2, 124688, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Necklace of Prowess
				{ 3, 124737, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Pendant of Cruelty
				{ 4, 124738, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Pendant of Prowess
				{ 5, 124739, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Pendant of Meditation
				{ 6, 124740, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Pendant of Contemplation
				{ 7, 124846, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Choker of Cruelty
				{ 8, 124847, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Choker of Prowess
				{ 9, 124853, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Choker of Endurance
				-- ilvl 670
				{ 16, 124897, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Necklace of Cruelty
				{ 17, 124898, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Necklace of Prowess
				{ 18, 124939, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Pendant of Cruelty
				{ 19, 124940, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Pendant of Prowess
				{ 20, 124941, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Pendant of Meditation
				{ 21, 124942, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Pendant of Contemplation
				{ 22, 125024, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Choker of Cruelty
				{ 23, 125025, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Choker of Prowess
				{ 24, 125050, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Choker of Endurance
				-- ilvl 625
				{ 26, 125064 }, -- Wild Aspirant's Necklace of Cruelty
				{ 27, 125087 }, -- Wild Aspirant's Pendant of Cruelty
				{ 28, 125088 }, -- Wild Aspirant's Pendant of Meditation
				{ 29, 125133 }, -- Wild Aspirant's Choker of Cruelty
				{ 30, 125136 }, -- Wild Aspirant's Choker of Endurance
			},
			[HORDE_DIFF] = {
				-- ilvl 700
				{ 1, 125166, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Necklace of Cruelty
				{ 2, 125167, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Necklace of Prowess
				{ 3, 125216, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Pendant of Cruelty
				{ 4, 125217, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Pendant of Prowess
				{ 5, 125218, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Pendant of Meditation
				{ 6, 125219, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Pendant of Contemplation
				{ 7, 125325, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Choker of Cruelty
				{ 8, 125326, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Choker of Prowess
				{ 9, 125332, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Choker of Endurance
				-- ilvl 670
				{ 16, 125374, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Necklace of Cruelty
				{ 17, 125375, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Necklace of Prowess
				{ 18, 125416, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Pendant of Cruelty
				{ 19, 125417, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Pendant of Prowess
				{ 20, 125418, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Pendant of Meditation
				{ 21, 125419, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Pendant of Contemplation
				{ 22, 125501, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Choker of Cruelty
				{ 23, 125502, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Choker of Prowess
				{ 24, 125527, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Choker of Endurance
				-- ilvl 625
				{ 26, 125541 }, -- Wild Aspirant's Necklace of Cruelty
				{ 27, 125564 }, -- Wild Aspirant's Pendant of Cruelty
				{ 28, 125565 }, -- Wild Aspirant's Pendant of Meditation
				{ 29, 125610 }, -- Wild Aspirant's Choker of Cruelty
				{ 30, 125613 }, -- Wild Aspirant's Choker of Endurance
			},
		},
		{
			name = AL["Cloaks"],
			[ALLIANCE_DIFF] = {
				-- ilvl 700
				{ 1, 124685, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Cape of Cruelty
				{ 2, 124686, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Cape of Prowess
				{ 3, 124733, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Drape of Cruelty
				{ 4, 124734, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Drape of Prowess
				{ 5, 124735, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Drape of Meditation
				{ 6, 124736, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Drape of Contemplation
				{ 7, 124844, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Cloak of Cruelty
				{ 8, 124845, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Cloak of Prowess
				{ 9, 124852, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Cloak of Endurance
				-- ilvl 650
				{ 16, 124895, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Cape of Cruelty
				{ 17, 124896, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Cape of Prowess
				{ 18, 124935, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Drape of Cruelty
				{ 19, 124936, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Drape of Prowess
				{ 20, 124937, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Drape of Meditation
				{ 21, 124938, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Drape of Contemplation
				{ 22, 125022, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Cloak of Cruelty
				{ 23, 125023, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Cloak of Prowess
				{ 24, 125049, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Cloak of Endurance
				-- ilvl 625
				{ 11, 125063 }, -- Wild Aspirant's Cape of Cruelty
				{ 12, 125085 }, -- Wild Aspirant's Drape of Cruelty
				{ 13, 125086 }, -- Wild Aspirant's Drape of Meditation
				{ 14, 125132 }, -- Wild Aspirant's Cloak of Cruelty
				{ 15, 125135 }, -- Wild Aspirant's Cloak of Endurance
				-- ilvl 100
				{ 26, 127375 }, -- Wild Gladiator's Greatcloak
			},
			[HORDE_DIFF] = {
				-- ilvl 700
				{ 1, 125164, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Cape of Cruelty
				{ 2, 125165, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Cape of Prowess
				{ 3, 125212, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Drape of Cruelty
				{ 4, 125213, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Drape of Prowess
				{ 5, 125214, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Drape of Meditation
				{ 6, 125215, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Drape of Contemplation
				{ 7, 125323, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Cloak of Cruelty
				{ 8, 125324, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Cloak of Prowess
				{ 9, 125331, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Cloak of Endurance
				-- ilvl 670
				{ 16, 125372, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Cape of Cruelty
				{ 17, 125373, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Cape of Prowess
				{ 18, 125412, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Drape of Cruelty
				{ 19, 125413, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Drape of Prowess
				{ 20, 125414, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Drape of Meditation
				{ 21, 125415, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Drape of Contemplation
				{ 22, 125499, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Cloak of Cruelty
				{ 23, 125500, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Cloak of Prowess
				{ 24, 125526, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Cloak of Endurance
				-- ilvl 625
				{ 11, 125540 }, -- Wild Aspirant's Cape of Cruelty
				{ 12, 125562 }, -- Wild Aspirant's Drape of Cruelty
				{ 13, 125563 }, -- Wild Aspirant's Drape of Meditation
				{ 14, 125609 }, -- Wild Aspirant's Cloak of Cruelty
				{ 15, 125612 }, -- Wild Aspirant's Cloak of Endurance
				-- ilvl 100
				{ 26, 127374 }, -- Wild Gladiator's Greatcloak
			},
		},
		{
			name = AL["Rings"],
			[ALLIANCE_DIFF] = {
				-- ilvl 700
				{ 1, 124689, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Ring of Cruelty
				{ 2, 124690, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Ring of Prowess
				{ 3, 124691, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Ring of Triumph
				{ 4, 124743, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Band of Cruelty
				{ 5, 124744, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Band of Prowess
				{ 6, 124745, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Band of Victory
				{ 7, 124746, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Band of Meditation
				{ 8, 124747, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Band of Contemplation
				{ 9, 124848, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Signet of Cruelty
				{ 10, 124849, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Signet of Accuracy
				{ 11, 124850, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Signet of Ruthlessness
				{ 12, 124854, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Signet of Dedication
				{ 13, 124855, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Signet of Endurance
				-- ilvl 670
				{ 16, 124899, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Ring of Cruelty
				{ 17, 124900, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Ring of Prowess
				{ 18, 124901, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Ring of Triumph
				{ 19, 124945, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Band of Cruelty
				{ 20, 124946, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Band of Prowess
				{ 21, 124947, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Band of Victory
				{ 22, 124948, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Band of Meditation
				{ 23, 124949, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Band of Contemplation
				{ 24, 125026, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Signet of Cruelty
				{ 25, 125027, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Signet of Accuracy
				{ 26, 125028, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Signet of Ruthlessness
				{ 27, 125051, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Signet of Dedication
				{ 28, 125052, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Signet of Endurance
				-- ilvl 625
				{ 101, 125065 }, -- Wild Aspirant's Ring of Cruelty
				{ 102, 125066 }, -- Wild Aspirant's Ring of Prowess
				{ 103, 125089 }, -- Wild Aspirant's Band of Cruelty
				{ 104, 125090 }, -- Wild Aspirant's Band of Prowess
				{ 105, 125091 }, -- Wild Aspirant's Band of Meditation
				{ 106, 125092 }, -- Wild Aspirant's Band of Contemplation
				{ 107, 125134 }, -- Wild Aspirant's Signet of Cruelty
				{ 108, 125137 }, -- Wild Aspirant's Signet of Dedication
				{ 109, 125138 }, -- Wild Aspirant's Signet of Endurance
				{ 110, 127118 }, -- Wild Aspirant's Signet of Accuracy
			},
			[HORDE_DIFF] = {
				-- ilvl 700
				{ 1, 125168, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Ring of Cruelty
				{ 2, 125169, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Ring of Prowess
				{ 3, 125170, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Ring of Triumph
				{ 4, 125222, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Band of Cruelty
				{ 5, 125223, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Band of Prowess
				{ 6, 125224, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Band of Victory
				{ 7, 125225, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Band of Meditation
				{ 8, 125226, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Band of Contemplation
				{ 9, 125327, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Signet of Cruelty
				{ 10, 125328, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Signet of Accuracy
				{ 11, 125329, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Signet of Ruthlessness
				{ 12, 125333, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Signet of Dedication
				{ 13, 125334, [PRICE_EXTRA_ITTYPE] = "conquest:1250" }, -- Wild Gladiator's Signet of Endurance
				-- ilvl 670
				{ 16, 125376, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Ring of Cruelty
				{ 17, 125377, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Ring of Prowess
				{ 18, 125378, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Ring of Triumph
				{ 19, 125422, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Band of Cruelty
				{ 20, 125423, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Band of Prowess
				{ 21, 125424, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Band of Victory
				{ 22, 125425, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Band of Meditation
				{ 23, 125426, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Band of Contemplation
				{ 24, 125503, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Signet of Cruelty
				{ 25, 125504, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Signet of Accuracy
				{ 26, 125505, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Signet of Ruthlessness
				{ 27, 125528, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Signet of Dedication
				{ 28, 125529, [PRICE_EXTRA_ITTYPE] = "honor:1250" }, -- Wild Combatant's Signet of Endurance
				-- ilvl 625
				{ 101, 125542 }, -- Wild Aspirant's Ring of Cruelty
				{ 102, 125543 }, -- Wild Aspirant's Ring of Prowess
				{ 103, 125566 }, -- Wild Aspirant's Band of Cruelty
				{ 104, 125567 }, -- Wild Aspirant's Band of Prowess
				{ 105, 125568 }, -- Wild Aspirant's Band of Meditation
				{ 106, 125569 }, -- Wild Aspirant's Band of Contemplation
				{ 107, 125611 }, -- Wild Aspirant's Signet of Cruelty
				{ 108, 125614 }, -- Wild Aspirant's Signet of Dedication
				{ 109, 125615 }, -- Wild Aspirant's Signet of Endurance
				{ 110, 127119 }, -- Wild Aspirant's Signet of Accuracy
			},
		},
		{
			name = AL["Trinkets"],
			[ALLIANCE_DIFF] = {
				-- ilvl 700
				{ 1, 124856, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Badge of Conquest
				{ 2, 124857, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Insignia of Conquest
				{ 3, 124858, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Emblem of Cruelty
				{ 4, 124859, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Emblem of Tenacity
				{ 5, 124860, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Emblem of Meditation
				{ 6, 124861, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Badge of Dominance
				{ 7, 124862, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Insignia of Dominance
				{ 8, 124863, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Medallion of Cruelty
				{ 9, 124865, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Medallion of Tenacity
				{ 10, 124866, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Medallion of Meditation
				{ 16, 124867, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Badge of Victory
				{ 17, 124868, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Insignia of Victory
				{ 18, 124869, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Badge of Adaptation
				{ 19, 124870 }, -- Wild Gladiator's Accolade of Conquest
				{ 20, 124871 }, -- Wild Gladiator's Accolade of Dominance
				{ 21, 124872 }, -- Wild Gladiator's Accolade of Victory
				{ 22, 124873 }, -- Wild Gladiator's Accolade of Meditation
				{ 23, 124874 }, -- Wild Gladiator's Accolade of Endurance
				{ 24, 127123, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Medallion of Adaptation
				-- ilvl 670
				{ 101, 125030, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Badge of Conquest
				{ 102, 125031, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Insignia of Conquest
				{ 103, 125032, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Emblem of Cruelty
				{ 104, 125033, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Emblem of Tenacity
				{ 105, 125034, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Emblem of Meditation
				{ 106, 125035, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Badge of Dominance
				{ 107, 125036, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Insignia of Dominance
				{ 108, 125037, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Medallion of Cruelty
				{ 109, 125038, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Medallion of Adaptation
				{ 110, 125039, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Medallion of Tenacity
				{ 111, 125040, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Medallion of Meditation
				{ 112, 125041, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Badge of Victory
				{ 113, 125042, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Insignia of Victory
				{ 114, 125043, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Badge of Adaptation
				{ 115, 125044 }, -- Wild Combatant's Accolade of Conquest
				{ 116, 125045 }, -- Wild Combatant's Accolade of Dominance
				{ 117, 125046 }, -- Wild Combatant's Accolade of Victory
				{ 118, 125047 }, -- Wild Combatant's Accolade of Meditation
				{ 119, 125048 }, -- Wild Combatant's Accolade of Endurance
				-- ilvl 625
				{ 121, 125139 }, -- Wild Aspirant's Accolade of Conquest
				{ 122, 125140 }, -- Wild Aspirant's Accolade of Dominance
				{ 123, 125141 }, -- Wild Aspirant's Accolade of Victory
				{ 124, 125142 }, -- Wild Aspirant's Accolade of Meditation
				{ 125, 125143 }, -- Wild Aspirant's Accolade of Endurance
			},
			[HORDE_DIFF] = {
				-- ilvl 700
				{ 1, 124864, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Medallion of Adaptation
				{ 2, 125335, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Badge of Conquest
				{ 3, 125336, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Insignia of Conquest
				{ 4, 125337, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Emblem of Cruelty
				{ 5, 125338, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Emblem of Tenacity
				{ 6, 125339, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Emblem of Meditation
				{ 7, 125340, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Badge of Dominance
				{ 8, 125341, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Insignia of Dominance
				{ 9, 125342, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Medallion of Tenacity
				{ 10, 125343, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Medallion of Meditation
				{ 16, 125344, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Badge of Victory
				{ 17, 125345, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Insignia of Victory
				{ 18, 125346, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Badge of Adaptation
				{ 19, 125347 }, -- Wild Gladiator's Accolade of Conquest
				{ 20, 125348 }, -- Wild Gladiator's Accolade of Dominance
				{ 21, 125349 }, -- Wild Gladiator's Accolade of Victory
				{ 22, 125350 }, -- Wild Gladiator's Accolade of Meditation
				{ 23, 125351 }, -- Wild Gladiator's Accolade of Endurance
				{ 24, 127124, [PRICE_EXTRA_ITTYPE] = "conquest:1750" }, -- Wild Gladiator's Medallion of Cruelty
				-- ilvl 670
				{ 101, 125507, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Badge of Conquest
				{ 102, 125508, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Insignia of Conquest
				{ 103, 125509, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Emblem of Cruelty
				{ 104, 125510, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Emblem of Tenacity
				{ 105, 125511, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Emblem of Meditation
				{ 106, 125512, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Badge of Dominance
				{ 107, 125513, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Insignia of Dominance
				{ 108, 125514, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Medallion of Cruelty
				{ 109, 125515, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Medallion of Adaptation
				{ 110, 125516, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Medallion of Tenacity
				{ 111, 125517, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Medallion of Meditation
				{ 112, 125518, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Badge of Victory
				{ 113, 125519, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Insignia of Victory
				{ 114, 125520, [PRICE_EXTRA_ITTYPE] = "honor:1750" }, -- Wild Combatant's Badge of Adaptation
				{ 115, 125521 }, -- Wild Combatant's Accolade of Conquest
				{ 116, 125522 }, -- Wild Combatant's Accolade of Dominance
				{ 117, 125523 }, -- Wild Combatant's Accolade of Victory
				{ 118, 125524 }, -- Wild Combatant's Accolade of Meditation
				{ 119, 125525 }, -- Wild Combatant's Accolade of Endurance
				-- ilvl 625
				{ 121, 125616 }, -- Wild Aspirant's Accolade of Conquest
				{ 122, 125617 }, -- Wild Aspirant's Accolade of Dominance
				{ 123, 125618 }, -- Wild Aspirant's Accolade of Victory
				{ 124, 125619 }, -- Wild Aspirant's Accolade of Meditation
				{ 125, 125620 }, -- Wild Aspirant's Accolade of Endurance
			},
		},
		{
			name = AL["Miscellaneous"],
			[ALLIANCE_DIFF] = {
				{ 1, 127366 }, -- Wild Gladiator's Tabard
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 127365 }, -- Wild Gladiator's Tabard
			},
		},

	},
}
--[[
data["WODS2WEAPONS"] = {
	name = string.format(AL["Warlords Season %d"], 2).." "..AL["Weapons"],
	ContentType = NORMAL_ITTYPE,
	items = {
		{
			name = string.format(AL["ilvl %d"], 700).." "..AL["Elite"],
			[ALLIANCE_DIFF] = {
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
		{
			name = string.format(AL["ilvl %d"], 700).." (730)",
			[ALLIANCE_DIFF] = {
			},
			[HORDE_DIFF] = {
			},
		},
		{
			name = string.format(AL["ilvl %d"], 670).." (715)",
			[ALLIANCE_DIFF] = {
			},
			[HORDE_DIFF] = {
			},
		},
	},
}
]]
data["WODS1SETS"] = {
	name = string.format(AL["Warlords Season %d"], 1).." "..AL["Class Sets"],
	ContentType = NORMAL_ITTYPE,
	items = {
		{
			name = LOCALIZED_CLASS_NAMES_MALE["DEATHKNIGHT"],
			[ALLIANCE_DIFF] = {
				{ 1, 115631, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Dreadplate Helm
				{ 2, 115633, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Dreadplate Shoulders
				{ 3, 115629, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Dreadplate Chestpiece
				{ 4, 115630, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Dreadplate Gauntlets
				{ 5, 115632, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Dreadplate Legguards
				{ 7, 115839, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Dreadplate Helm (r2000)
				{ 8, 115841, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Dreadplate Shoulders (r2000)
				{ 9, 115837, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Dreadplate Chestpiece (r2000)
				{ 10, 115838, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Dreadplate Gauntlets (r2000)
				{ 11, 115906, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Dreadplate Girdle (r2000)
				{ 12, 115840, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Dreadplate Legguards (r2000)
				{ 13, 115909, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Dreadplate Warboots (r2000)
				{ 16, 115051, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Dreadplate Helm
				{ 17, 115053, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Dreadplate Shoulders
				{ 18, 115049, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Dreadplate Chestpiece
				{ 19, 115050, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Dreadplate Gauntlets
				{ 20, 115052, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Dreadplate Legguards
				{ 22, 115199 },	-- Primal Aspirant's Dreadplate Helm
				{ 23, 115201 },	-- Primal Aspirant's Dreadplate Shoulders
				{ 24, 115197 },	-- Primal Aspirant's Dreadplate Chestpiece
				{ 25, 115198 },	-- Primal Aspirant's Dreadplate Gauntlets
				{ 26, 115200 },	-- Primal Aspirant's Dreadplate Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 111104, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Dreadplate Helm
				{ 2, 111106, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Dreadplate Shoulders
				{ 3, 111102, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Dreadplate Chestpiece
				{ 4, 111103, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Dreadplate Gauntlets
				{ 5, 111105, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Dreadplate Legguards
				{ 16, 119841, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Dreadplate Helm
				{ 17, 119843, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Dreadplate Shoulders
				{ 18, 119839, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Dreadplate Chestpiece
				{ 19, 119840, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Dreadplate Gauntlets
				{ 20, 119842, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Dreadplate Legguards
				{ 22, 119976 },	-- Primal Aspirant's Dreadplate Helm
				{ 23, 119978 },	-- Primal Aspirant's Dreadplate Shoulders
				{ 24, 119974 },	-- Primal Aspirant's Dreadplate Chestpiece
				{ 25, 119975 },	-- Primal Aspirant's Dreadplate Gauntlets
				{ 26, 119977 },	-- Primal Aspirant's Dreadplate Legguards
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["DRUID"],
			[ALLIANCE_DIFF] = {
				{ 1, 115635, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Dragonhide Helm
				{ 2, 115638, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Dragonhide Spaulders
				{ 3, 115637, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Dragonhide Robes
				{ 4, 115634, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Dragonhide Gloves
				{ 5, 115636, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Dragonhide Legguards
				{ 7, 115843, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Dragonhide Helm (r2000)
				{ 8, 115846, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Dragonhide Spaulders (r2000)
				{ 9, 115845, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Dragonhide Robes (r2000)
				{ 10, 115842, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Dragonhide Gloves (r2000)
				{ 11, 115971, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Dragonhide Belt (r2000)
				{ 12, 115844, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Dragonhide Legguards (r2000)
				{ 13, 115970, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Dragonhide Footguards (r2000)
				{ 16, 115055, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Dragonhide Helm
				{ 17, 115058, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Dragonhide Spaulders
				{ 18, 115057, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Dragonhide Robes
				{ 19, 115054, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Dragonhide Gloves
				{ 20, 115056, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Dragonhide Legguards
				{ 22, 115203 },	-- Primal Aspirant's Dragonhide Helm
				{ 23, 115206 },	-- Primal Aspirant's Dragonhide Spaulders
				{ 24, 115205 },	-- Primal Aspirant's Dragonhide Robes
				{ 25, 115202 },	-- Primal Aspirant's Dragonhide Gloves
				{ 26, 115204 },	-- Primal Aspirant's Dragonhide Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 111108, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Dragonhide Helm
				{ 2, 111111, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Dragonhide Spaulders
				{ 3, 111110, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Dragonhide Robes
				{ 4, 111107, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Dragonhide Gloves
				{ 5, 111109, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Dragonhide Legguards
				{ 16, 119845, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Dragonhide Helm
				{ 17, 119848, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Dragonhide Spaulders
				{ 18, 119847, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Dragonhide Robes
				{ 19, 119844, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Dragonhide Gloves
				{ 20, 119846, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Dragonhide Legguards
				{ 22, 119980 },	-- Primal Aspirant's Dragonhide Helm
				{ 23, 119983 },	-- Primal Aspirant's Dragonhide Spaulders
				{ 24, 119982 },	-- Primal Aspirant's Dragonhide Robes
				{ 25, 119979 },	-- Primal Aspirant's Dragonhide Gloves
				{ 26, 119981 },	-- Primal Aspirant's Dragonhide Legguards
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["HUNTER"],
			[ALLIANCE_DIFF] = {
				{ 1, 115641, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Chain Helm
				{ 2, 115643, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Chain Spaulders
				{ 3, 115639, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Chain Armor
				{ 4, 115640, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Chain Gauntlets
				{ 5, 115642, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Chain Leggings
				{ 7, 115872, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Chain Helm (r2000)
				{ 8, 115874, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Chain Spaulders (r2000)
				{ 9, 115870, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Chain Armor (r2000)
				{ 10, 115871, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Chain Gauntlets (r2000)
				{ 11, 115866, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Chain Links (r2000)
				{ 12, 115873, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Chain Leggings (r2000)
				{ 13, 115868, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Chain Sabatons (r2000)
				{ 16, 115061, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Chain Helm
				{ 17, 115063, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Chain Spaulders
				{ 18, 115059, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Chain Armor
				{ 19, 115060, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Chain Gauntlets
				{ 20, 115062, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Chain Leggings
				{ 22, 115209 },	-- Primal Aspirant's Chain Helm
				{ 23, 115211 },	-- Primal Aspirant's Chain Spaulders
				{ 24, 115207 },	-- Primal Aspirant's Chain Armor
				{ 25, 115208 },	-- Primal Aspirant's Chain Gauntlets
				{ 26, 115210 },	-- Primal Aspirant's Chain Leggings
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 111114, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Chain Helm
				{ 2, 111116, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Chain Spaulders
				{ 3, 111112, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Chain Armor
				{ 4, 111113, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Chain Gauntlets
				{ 5, 111115, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Chain Leggings
				{ 16, 119851, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Chain Helm
				{ 17, 119853, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Chain Spaulders
				{ 18, 119849, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Chain Armor
				{ 19, 119850, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Chain Gauntlets
				{ 20, 119852, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Chain Leggings
				{ 22, 119986 },	-- Primal Aspirant's Chain Helm
				{ 23, 119988 },	-- Primal Aspirant's Chain Spaulders
				{ 24, 119984 },	-- Primal Aspirant's Chain Armor
				{ 25, 119985 },	-- Primal Aspirant's Chain Gauntlets
				{ 26, 119987 },	-- Primal Aspirant's Chain Leggings
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["MAGE"],
			[ALLIANCE_DIFF] = {
				{ 1, 115678, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Silk Cowl
				{ 2, 115681, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Silk Amice
				{ 3, 115680, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Silk Robe
				{ 4, 115677, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Silk Handguards
				{ 5, 115679, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Silk Trousers
				{ 7, 115876, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Silk Cowl (r2000)
				{ 8, 115879, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Silk Amice (r2000)
				{ 9, 115878, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Silk Robe (r2000)
				{ 10, 115875, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Silk Handguards (r2000)
				{ 11, 115824, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Silk Cord (r2000)
				{ 12, 115877, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Silk Trousers (r2000)
				{ 13, 115827, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Silk Treads (r2000)
				{ 16, 115091, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Silk Cowl
				{ 17, 115094, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Silk Amice
				{ 18, 115093, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Silk Robe
				{ 19, 115090, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Silk Handguards
				{ 20, 115092, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Silk Trousers
				{ 22, 115221 },	-- Primal Aspirant's Silk Cowl
				{ 23, 115224 },	-- Primal Aspirant's Silk Amice
				{ 24, 115223 },	-- Primal Aspirant's Silk Robe
				{ 25, 115220 },	-- Primal Aspirant's Silk Handguards
				{ 26, 115222 },	-- Primal Aspirant's Silk Trousers
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 111151, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Silk Cowl
				{ 2, 111154, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Silk Amice
				{ 3, 111153, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Silk Robe
				{ 4, 111150, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Silk Handguards
				{ 5, 111152, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Silk Trousers
				{ 16, 119874, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Silk Cowl
				{ 17, 119877, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Silk Amice
				{ 18, 119876, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Silk Robe
				{ 19, 119873, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Silk Handguards
				{ 20, 119875, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Silk Trousers
				{ 22, 119998 },	-- Primal Aspirant's Silk Cowl
				{ 23, 120001 },	-- Primal Aspirant's Silk Amice
				{ 24, 120000 },	-- Primal Aspirant's Silk Robe
				{ 25, 119997 },	-- Primal Aspirant's Silk Handguards
				{ 26, 119999 },	-- Primal Aspirant's Silk Trousers
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["MONK"],
			[ALLIANCE_DIFF] = {
				{ 1, 115692, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Ironskin Helm
				{ 2, 115694, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Ironskin Spaulders
				{ 3, 115695, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Ironskin Tunic
				{ 4, 115691, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Ironskin Gloves
				{ 5, 115693, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Ironskin Legguards
				{ 7, 115883, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Ironskin Helm (r2000)
				{ 8, 115885, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Ironskin Spaulders (r2000)
				{ 9, 115886, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Ironskin Tunic (r2000)
				{ 10, 115882, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Ironskin Gloves (r2000)
				{ 11, 115880, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Ironskin Waistband (r2000)
				{ 12, 115884, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Ironskin Legguards (r2000)
				{ 13, 115881, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Ironskin Boots (r2000)
				{ 16, 115102, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Ironskin Helm
				{ 17, 115104, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Ironskin Spaulders
				{ 18, 115105, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Ironskin Tunic
				{ 19, 115101, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Ironskin Gloves
				{ 20, 115103, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Ironskin Legguards
				{ 22, 115229 },	-- Primal Aspirant's Ironskin Helm
				{ 23, 115231 },	-- Primal Aspirant's Ironskin Spaulders
				{ 24, 115232 },	-- Primal Aspirant's Ironskin Tunic
				{ 25, 115228 },	-- Primal Aspirant's Ironskin Gloves
				{ 26, 115230 },	-- Primal Aspirant's Ironskin Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 111165, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Ironskin Helm
				{ 2, 111167, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Ironskin Spaulders
				{ 3, 111168, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Ironskin Tunic
				{ 4, 111164, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Ironskin Gloves
				{ 5, 111166, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Ironskin Legguards
				{ 16, 119885, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Ironskin Helm
				{ 17, 119887, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Ironskin Spaulders
				{ 18, 119888, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Ironskin Tunic
				{ 19, 119884, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Ironskin Gloves
				{ 20, 119886, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Ironskin Legguards
				{ 22, 120006 },	-- Primal Aspirant's Ironskin Helm
				{ 23, 120008 },	-- Primal Aspirant's Ironskin Spaulders
				{ 24, 120009 },	-- Primal Aspirant's Ironskin Tunic
				{ 25, 120005 },	-- Primal Aspirant's Ironskin Gloves
				{ 26, 120007 },	-- Primal Aspirant's Ironskin Legguards
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["PALADIN"],
			[ALLIANCE_DIFF] = {
				{ 1, 115698, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Scaled Helm
				{ 2, 115700, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Scaled Shoulders
				{ 3, 115696, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Scaled Chestpiece
				{ 4, 115697, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Scaled Gauntlets
				{ 5, 115699, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Scaled Legguards
				{ 7, 115894, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Scaled Helm (r2000)
				{ 8, 115896, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Scaled Shoulders (r2000)
				{ 9, 115892, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Scaled Chestpiece (r2000)
				{ 10, 115893, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Scaled Gauntlets (r2000)
				{ 11, 115897, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Scaled Clasp (r2000)
				{ 12, 115895, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Scaled Legguards (r2000)
				{ 13, 115900, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Scaled Greaves (r2000)
				{ 16, 115108, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Scaled Helm
				{ 17, 115110, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Scaled Shoulders
				{ 18, 115106, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Scaled Chestpiece
				{ 19, 115107, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Scaled Gauntlets
				{ 20, 115109, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Scaled Legguards
				{ 22, 115235 },	-- Primal Aspirant's Scaled Helm
				{ 23, 115237 },	-- Primal Aspirant's Scaled Shoulders
				{ 24, 115233 },	-- Primal Aspirant's Scaled Chestpiece
				{ 25, 115234 },	-- Primal Aspirant's Scaled Gauntlets
				{ 26, 115236 },	-- Primal Aspirant's Scaled Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 111171, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Scaled Helm
				{ 2, 111173, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Scaled Shoulders
				{ 3, 111169, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Scaled Chestpiece
				{ 4, 111170, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Scaled Gauntlets
				{ 5, 111172, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Scaled Legguards
				{ 16, 119891, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Scaled Helm
				{ 17, 119893, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Scaled Shoulders
				{ 18, 119889, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Scaled Chestpiece
				{ 19, 119890, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Scaled Gauntlets
				{ 20, 119892, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Scaled Legguards
				{ 22, 120012 },	-- Primal Aspirant's Scaled Helm
				{ 23, 120014 },	-- Primal Aspirant's Scaled Shoulders
				{ 24, 120010 },	-- Primal Aspirant's Scaled Chestpiece
				{ 25, 120011 },	-- Primal Aspirant's Scaled Gauntlets
				{ 26, 120013 },	-- Primal Aspirant's Scaled Legguards
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["PRIEST"],
			[ALLIANCE_DIFF] = {
				{ 1, 115711, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Satin Hood
				{ 2, 115714, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Satin Mantle
				{ 3, 115713, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Satin Robe
				{ 4, 115710, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Satin Gloves
				{ 5, 115712, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Satin Leggings
				{ 7, 115917, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Satin Hood (r2000)
				{ 8, 115920, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Satin Mantle (r2000)
				{ 9, 115919, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Satin Robe (r2000)
				{ 10, 115916, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Satin Gloves (r2000)
				{ 11, 115969, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Satin Cord (r2000)
				{ 12, 115918, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Satin Leggings (r2000)
				{ 13, 115968, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Satin Treads (r2000)
				{ 16, 115118, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Satin Hood
				{ 17, 115121, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Satin Mantle
				{ 18, 115120, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Satin Robe
				{ 19, 115117, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Satin Gloves
				{ 20, 115119, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Satin Leggings
				{ 22, 115242 },	-- Primal Aspirant's Satin Hood
				{ 23, 115245 },	-- Primal Aspirant's Satin Mantle
				{ 24, 115244 },	-- Primal Aspirant's Satin Robe
				{ 25, 115241 },	-- Primal Aspirant's Satin Gloves
				{ 26, 115243 },	-- Primal Aspirant's Satin Leggings
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 111184, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Satin Hood
				{ 2, 111187, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Satin Mantle
				{ 3, 111186, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Satin Robe
				{ 4, 111183, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Satin Gloves
				{ 5, 111185, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Satin Leggings
				{ 16, 119901, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Satin Hood
				{ 17, 119904, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Satin Mantle
				{ 18, 119903, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Satin Robe
				{ 19, 119900, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Satin Gloves
				{ 20, 119902, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Satin Leggings
				{ 22, 120019 },	-- Primal Aspirant's Satin Hood
				{ 23, 120022 },	-- Primal Aspirant's Satin Mantle
				{ 24, 120021 },	-- Primal Aspirant's Satin Robe
				{ 25, 120018 },	-- Primal Aspirant's Satin Gloves
				{ 26, 120020 },	-- Primal Aspirant's Satin Leggings
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["ROGUE"],
			[ALLIANCE_DIFF] = {
				{ 1, 115717, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Leather Helm
				{ 2, 115719, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Leather Spaulders
				{ 3, 115715, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Leather Tunic
				{ 4, 115716, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Leather Gloves
				{ 5, 115718, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Leather Legguards
				{ 7, 115925, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Leather Helm (r2000)
				{ 8, 115927, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Leather Spaulders (r2000)
				{ 9, 115923, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Leather Tunic (r2000)
				{ 10, 115924, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Leather Gloves (r2000)
				{ 11, 115921, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Leather Waistband (r2000)
				{ 12, 115926, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Leather Legguards (r2000)
				{ 13, 115922, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Leather Boots (r2000)
				{ 16, 115124, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Leather Helm
				{ 17, 115126, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Leather Spaulders
				{ 18, 115122, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Leather Tunic
				{ 19, 115123, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Leather Gloves
				{ 20, 115125, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Leather Legguards
				{ 22, 115248 },	-- Primal Aspirant's Leather Helm
				{ 23, 115250 },	-- Primal Aspirant's Leather Spaulders
				{ 24, 115246 },	-- Primal Aspirant's Leather Tunic
				{ 25, 115247 },	-- Primal Aspirant's Leather Gloves
				{ 26, 115249 },	-- Primal Aspirant's Leather Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 111190, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Leather Helm
				{ 2, 111192, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Leather Spaulders
				{ 3, 111188, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Leather Tunic
				{ 4, 111189, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Leather Gloves
				{ 5, 111191, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Leather Legguards
				{ 16, 119907, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Leather Helm
				{ 17, 119909, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Leather Spaulders
				{ 18, 119905, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Leather Tunic
				{ 19, 119906, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Leather Gloves
				{ 20, 119908, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Leather Legguards
				{ 22, 120025 },	-- Primal Aspirant's Leather Helm
				{ 23, 120027 },	-- Primal Aspirant's Leather Spaulders
				{ 24, 120023 },	-- Primal Aspirant's Leather Tunic
				{ 25, 120024 },	-- Primal Aspirant's Leather Gloves
				{ 26, 120026 },	-- Primal Aspirant's Leather Legguards
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["SHAMAN"],
			[ALLIANCE_DIFF] = {
				{ 1, 115722, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Ringmail Helm
				{ 2, 115724, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Ringmail Spaulders
				{ 3, 115720, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Ringmail Armor
				{ 4, 115721, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Ringmail Gauntlets
				{ 5, 115723, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Ringmail Leggings
				{ 7, 115933, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Ringmail Helm (r2000)
				{ 8, 115935, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Ringmail Spaulders (r2000)
				{ 9, 115931, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Ringmail Armor (r2000)
				{ 10, 115932, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Ringmail Gauntlets (r2000)
				{ 11, 115928, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Ringmail Waistguard (r2000)
				{ 12, 115934, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Ringmail Leggings (r2000)
				{ 13, 115929, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Ringmail Footguards (r2000)
				{ 16, 115129, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Ringmail Helm
				{ 17, 115131, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Ringmail Spaulders
				{ 18, 115127, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Ringmail Armor
				{ 19, 115128, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Ringmail Gauntlets
				{ 20, 115130, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Ringmail Leggings
				{ 22, 115253 },	-- Primal Aspirant's Ringmail Helm
				{ 23, 115255 },	-- Primal Aspirant's Ringmail Spaulders
				{ 24, 115251 },	-- Primal Aspirant's Ringmail Armor
				{ 25, 115252 },	-- Primal Aspirant's Ringmail Gauntlets
				{ 26, 115254 },	-- Primal Aspirant's Ringmail Leggings
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 111195, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Ringmail Helm
				{ 2, 111197, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Ringmail Spaulders
				{ 3, 111193, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Ringmail Armor
				{ 4, 111194, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Ringmail Gauntlets
				{ 5, 111196, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Ringmail Leggings
				{ 16, 119912, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Ringmail Helm
				{ 17, 119915, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Ringmail Spaulders
				{ 18, 119910, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Ringmail Armor
				{ 19, 119911, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Ringmail Gauntlets
				{ 20, 119913, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Ringmail Leggings
				{ 22, 120030 },	-- Primal Aspirant's Ringmail Helm
				{ 23, 120032 },	-- Primal Aspirant's Ringmail Spaulders
				{ 24, 120028 },	-- Primal Aspirant's Ringmail Armor
				{ 25, 120029 },	-- Primal Aspirant's Ringmail Gauntlets
				{ 26, 120031 },	-- Primal Aspirant's Ringmail Leggings
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["WARLOCK"],
			[ALLIANCE_DIFF] = {
				{ 1, 115762, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Felweave Cowl
				{ 2, 115765, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Felweave Amice
				{ 3, 115764, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Felweave Raiment
				{ 4, 115761, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Felweave Handguards
				{ 5, 115763, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Felweave Trousers
				{ 7, 115957, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Felweave Cowl (r2000)
				{ 8, 115960, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Felweave Amice (r2000)
				{ 9, 115959, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Felweave Raiment (r2000)
				{ 10, 115956, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Felweave Handguards (r2000)
				{ 11, 115825, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Felweave Cord (r2000)
				{ 12, 115958, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Felweave Trousers (r2000)
				{ 13, 115828, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Felweave Treads (r2000)
				{ 16, 115162, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Felweave Cowl
				{ 17, 115165, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Felweave Amice
				{ 18, 115164, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Felweave Raiment
				{ 19, 115161, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Felweave Handguards
				{ 20, 115163, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Felweave Trousers
				{ 22, 115259 },	-- Primal Aspirant's Felweave Cowl
				{ 23, 115262 },	-- Primal Aspirant's Felweave Amice
				{ 24, 115261 },	-- Primal Aspirant's Felweave Raiment
				{ 25, 115258 },	-- Primal Aspirant's Felweave Handguards
				{ 26, 115260 },	-- Primal Aspirant's Felweave Trousers
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 111235, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Felweave Cowl
				{ 2, 111238, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Felweave Amice
				{ 3, 111237, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Felweave Raiment
				{ 4, 111234, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Felweave Handguards
				{ 5, 111236, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Felweave Trousers
				{ 16, 119939, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Felweave Cowl
				{ 17, 119942, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Felweave Amice
				{ 18, 119941, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Felweave Raiment
				{ 19, 119938, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Felweave Handguards
				{ 20, 119940, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Felweave Trousers
				{ 22, 120036 },	-- Primal Aspirant's Felweave Cowl
				{ 23, 120039 },	-- Primal Aspirant's Felweave Amice
				{ 24, 120038 },	-- Primal Aspirant's Felweave Raiment
				{ 25, 120035 },	-- Primal Aspirant's Felweave Handguards
				{ 26, 120037 },	-- Primal Aspirant's Felweave Trousers
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["WARRIOR"],
			[ALLIANCE_DIFF] = {
				{ 1, 115768, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Plate Helm
				{ 2, 115770, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Plate Shoulders
				{ 3, 115766, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Plate Chestpiece
				{ 4, 115767, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Plate Gauntlets
				{ 5, 115769, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Plate Legguards
				{ 7, 115963, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Plate Helm (r2000)
				{ 8, 115965, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Plate Shoulders (r2000)
				{ 9, 115961, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Plate Chestpiece (r2000)
				{ 10, 115962, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Plate Gauntlets (r2000)
				{ 11, 115907, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Plate Girdle (r2000)
				{ 12, 115964, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Plate Legguards (r2000)
				{ 13, 115908, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Plate Warboots (r2000)
				{ 16, 115168, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Plate Helm
				{ 17, 115170, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Plate Shoulders
				{ 18, 115166, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Plate Chestpiece
				{ 19, 115167, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Plate Gauntlets
				{ 20, 115169, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Plate Legguards
				{ 22, 115265 },	-- Primal Aspirant's Plate Helm
				{ 23, 115267 },	-- Primal Aspirant's Plate Shoulders
				{ 24, 115263 },	-- Primal Aspirant's Plate Chestpiece
				{ 25, 115264 },	-- Primal Aspirant's Plate Gauntlets
				{ 26, 115266 },	-- Primal Aspirant's Plate Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 111241, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Plate Helm
				{ 2, 111243, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Plate Shoulders
				{ 3, 111239, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Plate Chestpiece
				{ 4, 111240, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Plate Gauntlets
				{ 5, 111242, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Plate Legguards
				{ 16, 119945, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Plate Helm
				{ 17, 119947, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Plate Shoulders
				{ 18, 119943, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Plate Chestpiece
				{ 19, 119944, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Plate Gauntlets
				{ 20, 119946, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Plate Legguards
				{ 22, 120042 },	-- Primal Aspirant's Plate Helm
				{ 23, 120044 },	-- Primal Aspirant's Plate Shoulders
				{ 24, 120040 },	-- Primal Aspirant's Plate Chestpiece
				{ 25, 120041 },	-- Primal Aspirant's Plate Gauntlets
				{ 26, 120043 },	-- Primal Aspirant's Plate Legguards
			},
		},
	},
}

data["WODS1NONSETGEAR"] = {
	name = string.format(AL["Warlords Season %d"], 1).." "..AL["Non-Set Gear"],
	ContentType = NORMAL_ITTYPE,
	items = {
		{
			name = ALIL["Cloth"],
			[ALLIANCE_DIFF] = {
				{ 1, 115611, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Hood of Prowess
				{ 2, 115614, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Amice of Prowess
				{ 3, 115613, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Robes of Prowess
				{ 4, 115610, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Gloves of Prowess
				{ 5, 115612, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Leggings of Prowess
				{ 7, 115627, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Cuffs of Cruelty
				{ 8, 115626, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Cuffs of Prowess
				{ 10, 115620, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Cord of Cruelty
				{ 11, 115621, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Cord of Prowess
				{ 13, 115623, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Treads of Cruelty
				{ 14, 115624, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Treads of Prowess
				{ 16, 115616, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Cowl of Cruelty
				{ 17, 115619, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Mantle of Cruelty
				{ 18, 115618, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Raiment of Cruelty
				{ 19, 115628, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Cuffs of Victory
				{ 20, 115615, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Handguards of Cruelty
				{ 21, 115622, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Cord of Victory
				{ 22, 115617, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Trousers of Cruelty
				{ 23, 115625, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Treads of Victory
				{ 101, 115039, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Hood of Prowess
				{ 102, 115042, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Amice of Prowess
				{ 103, 115041, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Robes of Prowess
				{ 104, 115038, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Gloves of Prowess
				{ 105, 115040, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Leggings of Prowess
				{ 107, 115048, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Cuffs of Cruelty
				{ 108, 115047, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Cuffs of Prowess
				{ 110, 115043, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Cord of Cruelty
				{ 111, 115044, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Cord of Prowess
				{ 113, 115045, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Treads of Cruelty
				{ 114, 115046, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Treads of Prowess
				{ 116, 115196 },	-- Primal Aspirant's Cuffs of Prowess
				{ 117, 115194 },	-- Primal Aspirant's Cord of Cruelty
				{ 118, 115195 },	-- Primal Aspirant's Treads of Cruelty
			},
			[HORDE_DIFF] = {
				{ 1, 111084, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Hood of Prowess
				{ 2, 111087, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Amice of Prowess
				{ 3, 111086, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Robes of Prowess
				{ 4, 111083, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Gloves of Prowess
				{ 5, 111085, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Leggings of Prowess
				{ 7, 111100, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Cuffs of Cruelty
				{ 8, 111099, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Cuffs of Prowess
				{ 10, 111093, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Cord of Cruelty
				{ 11, 111094, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Cord of Prowess
				{ 13, 111096, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Treads of Cruelty
				{ 14, 111097, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Treads of Prowess
				{ 16, 111089, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Cowl of Cruelty
				{ 17, 111092, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Mantle of Cruelty
				{ 18, 111091, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Raiment of Cruelty
				{ 19, 111101, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Cuffs of Victory
				{ 20, 111088, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Handguards of Cruelty
				{ 21, 111095, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Cord of Victory
				{ 22, 111090, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Trousers of Cruelty
				{ 23, 111098, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Treads of Victory
				{ 101, 119829, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Hood of Prowess
				{ 102, 119832, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Amice of Prowess
				{ 103, 119831, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Robes of Prowess
				{ 104, 119828, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Gloves of Prowess
				{ 105, 119830, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Leggings of Prowess
				{ 107, 119838, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Cuffs of Cruelty
				{ 108, 119837, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Cuffs of Prowess
				{ 110, 119833, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Cord of Cruelty
				{ 111, 119834, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Cord of Prowess
				{ 113, 119835, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Treads of Cruelty
				{ 114, 119836, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Treads of Prowess
				{ 116, 119973 },	-- Primal Aspirant's Cuffs of Prowess
				{ 117, 119971 },	-- Primal Aspirant's Cord of Cruelty
				{ 118, 119972 },	-- Primal Aspirant's Treads of Cruelty
			},
		},
		{
			name = ALIL["Leather"],
			[ALLIANCE_DIFF] = {
				{ 1, 115775, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Helm
				{ 2, 115777, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Spaulders
				{ 3, 115773, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Tunic
				{ 4, 115774, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Gloves
				{ 5, 115776, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Legguards
				{ 7, 115674, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Bindings of Cruelty
				{ 8, 115675, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Bindings of Prowess
				{ 10, 115669, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Belt of Cruelty
				{ 11, 115668, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Belt of Prowess
				{ 13, 115671, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Boots of Cruelty
				{ 14, 115672, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Boots of Prowess
				{ 16, 115785, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Headcover
				{ 17, 115787, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Pauldrons
				{ 18, 115783, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Chestguard
				{ 19, 115676, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Bindings of Victory
				{ 20, 115784, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Grips
				{ 21, 115670, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Belt of Victory
				{ 22, 115786, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Leggings
				{ 23, 115673, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Boots of Victory
				{ 101, 115175, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Helm
				{ 102, 115177, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Spaulders
				{ 103, 115173, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Tunic
				{ 104, 115174, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Gloves
				{ 105, 115176, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Legguards
				{ 107, 115088, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Bindings of Cruelty
				{ 108, 115089, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Bindings of Prowess
				{ 110, 115085, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Belt of Cruelty
				{ 111, 115084, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Belt of Prowess
				{ 113, 115086, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Boots of Cruelty
				{ 114, 115087, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Boots of Prowess
				{ 116, 115219 },	-- Primal Aspirant's Bindings of Cruelty
				{ 117, 115217 },	-- Primal Aspirant's Belt of Prowess
				{ 118, 115218 },	-- Primal Aspirant's Boots of Cruelty
			},
			[HORDE_DIFF] = {
				{ 1, 111275, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Helm
				{ 2, 111277, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Spaulders
				{ 3, 111273, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Tunic
				{ 4, 111274, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Gloves
				{ 5, 111276, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Legguards
				{ 7, 111147, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Bindings of Cruelty
				{ 8, 111148, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Bindings of Prowess
				{ 10, 111142, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Belt of Cruelty
				{ 11, 111141, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Belt of Prowess
				{ 13, 111144, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Boots of Cruelty
				{ 14, 111145, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Boots of Prowess
				{ 16, 111285, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Headcover
				{ 17, 111287, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Pauldrons
				{ 18, 111283, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Chestguard
				{ 19, 111149, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Bindings of Victory
				{ 20, 111284, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Grips
				{ 21, 111143, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Belt of Victory
				{ 22, 111286, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Leggings
				{ 23, 111146, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Boots of Victory
				{ 101, 119952, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Helm
				{ 102, 119954, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Spaulders
				{ 103, 119950, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Tunic
				{ 104, 119951, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Gloves
				{ 105, 119953, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Legguards
				{ 107, 119871, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Bindings of Cruelty
				{ 108, 119872, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Bindings of Prowess
				{ 110, 119868, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Belt of Cruelty
				{ 111, 119867, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Belt of Prowess
				{ 113, 119869, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Boots of Cruelty
				{ 114, 119870, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Boots of Prowess
				{ 116, 119996 },	-- Primal Aspirant's Bindings of Cruelty
				{ 117, 119994 },	-- Primal Aspirant's Belt of Prowess
				{ 118, 119995 },	-- Primal Aspirant's Boots of Cruelty
			},
		},
		{
			name = ALIL["Mail"],
			[ALLIANCE_DIFF] = {
				{ 1, 115780, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Helm
				{ 2, 115782, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Spaulders
				{ 3, 115778, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Armor
				{ 4, 115779, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Gauntlets
				{ 5, 115781, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Leggings
				{ 7, 115689, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Armbands of Cruelty
				{ 8, 115688, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Armbands of Prowess
				{ 10, 115682, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Waistguard of Cruelty
				{ 11, 115683, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Waistguard of Prowess
				{ 13, 115685, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Footguards of Cruelty
				{ 14, 115686, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Footguards of Prowess
				{ 16, 115790, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Coif
				{ 17, 115792, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Pauldrons
				{ 18, 115788, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Chestguard
				{ 19, 115690, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Armbands of Victory
				{ 20, 115789, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Gloves
				{ 21, 115684, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Waistguard of Victory
				{ 22, 115791, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Leggings
				{ 23, 115687, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Footguards of Victory
				{ 101, 115180, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Helm
				{ 102, 115182, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Spaulders
				{ 103, 115178, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Armor
				{ 104, 115179, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Gauntlets
				{ 105, 115181, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Leggings
				{ 107, 115100, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Armbands of Cruelty
				{ 108, 115099, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Armbands of Prowess
				{ 110, 115095, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Waistguard of Cruelty
				{ 111, 115096, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Waistguard of Prowess
				{ 113, 115097, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Footguards of Cruelty
				{ 114, 115098, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Footguards of Prowess
				{ 116, 115227 },	-- Primal Aspirant's Armbands of Prowess
				{ 117, 115225 },	-- Primal Aspirant's Waistguard of Cruelty
				{ 118, 115226 },	-- Primal Aspirant's Footguards of Cruelty
			},
			[HORDE_DIFF] = {
				{ 1, 111280, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Helm
				{ 2, 111282, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Spaulders
				{ 3, 111278, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Armor
				{ 4, 111279, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Gauntlets
				{ 5, 111281, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Leggings
				{ 7, 111162, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Armbands of Cruelty
				{ 8, 111161, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Armbands of Prowess
				{ 10, 111155, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Waistguard of Cruelty
				{ 11, 111156, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Waistguard of Prowess
				{ 13, 111158, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Footguards of Cruelty
				{ 14, 111159, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Footguards of Prowess
				{ 16, 111290, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Coif
				{ 17, 111292, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Pauldrons
				{ 18, 111288, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Chestguard
				{ 19, 111163, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Armbands of Victory
				{ 20, 111289, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Gloves
				{ 21, 111157, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Waistguard of Victory
				{ 22, 111291, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Leggings
				{ 23, 111160, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Footguards of Victory
				{ 101, 119957, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Helm
				{ 102, 119959, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Spaulders
				{ 103, 119955, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Armor
				{ 104, 119956, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Gauntlets
				{ 105, 119958, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Leggings
				{ 107, 119883, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Armbands of Cruelty
				{ 108, 119882, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Armbands of Prowess
				{ 110, 119878, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Waistguard of Cruelty
				{ 111, 119879, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Waistguard of Prowess
				{ 113, 119880, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Footguards of Cruelty
				{ 114, 119881, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Footguards of Prowess
				{ 116, 120004 },	-- Primal Aspirant's Armbands of Prowess
				{ 117, 120002 },	-- Primal Aspirant's Waistguard of Cruelty
				{ 118, 120003 },	-- Primal Aspirant's Footguards of Cruelty
			},
		},
		{
			name = ALIL["Plate"],
			[ALLIANCE_DIFF] = {
				{ 1, 115738, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Plate Helm
				{ 2, 115740, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Plate Shoulders
				{ 3, 115736, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Plate Chestpiece
				{ 4, 115737, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Plate Gauntlets
				{ 5, 115739, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Plate Legguards
				{ 7, 115707, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Armplates of Cruelty
				{ 8, 115708, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Armplates of Prowess
				{ 10, 115701, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Girdle of Cruelty
				{ 11, 115702, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Girdle of Prowess
				{ 13, 115704, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Warboots of Cruelty
				{ 14, 115705, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Warboots of Prowess
				{ 16, 115743, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Plate Visor
				{ 17, 115745, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Plate Pauldrons
				{ 18, 115741, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Plate Chestguard
				{ 19, 115709, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Armplates of Victory
				{ 20, 115742, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Plate Grips
				{ 21, 115703, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Girdle of Victory
				{ 22, 115744, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Plate Leggings
				{ 23, 115706, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Warboots of Victory
				{ 101, 115143, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Plate Helm
				{ 102, 115145, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Plate Shoulders
				{ 103, 115141, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Plate Chestpiece
				{ 104, 115142, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Plate Gauntlets
				{ 105, 115144, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Plate Legguards
				{ 107, 115115, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Armplates of Cruelty
				{ 108, 115116, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Armplates of Prowess
				{ 110, 115111, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Girdle of Cruelty
				{ 111, 115112, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Girdle of Prowess
				{ 113, 115113, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Warboots of Cruelty
				{ 114, 115114, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Warboots of Prowess
				{ 116, 115240 },	-- Primal Aspirant's Armplates of Cruelty
				{ 117, 115238 },	-- Primal Aspirant's Girdle of Cruelty
				{ 118, 115239 },	-- Primal Aspirant's Warboots of Cruelty
			},
			[HORDE_DIFF] = {
				{ 1, 111211, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Plate Helm
				{ 2, 111213, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Plate Shoulders
				{ 3, 111209, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Plate Chestpiece
				{ 4, 111210, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Plate Gauntlets
				{ 5, 111212, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Plate Legguards
				{ 7, 111180, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Armplates of Cruelty
				{ 8, 111181, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Armplates of Prowess
				{ 10, 111174, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Girdle of Cruelty
				{ 11, 111175, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Girdle of Prowess
				{ 13, 111177, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Warboots of Cruelty
				{ 14, 111178, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Warboots of Prowess
				{ 16, 111216, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Plate Visor
				{ 17, 111218, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Plate Pauldrons
				{ 18, 111214, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Plate Chestguard
				{ 19, 111182, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Armplates of Victory
				{ 20, 111215, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Plate Grips
				{ 21, 111176, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Girdle of Victory
				{ 22, 111217, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Plate Leggings
				{ 23, 111179, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Warboots of Victory
				{ 101, 119920, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Plate Helm
				{ 102, 119922, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Plate Shoulders
				{ 103, 119918, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Plate Chestpiece
				{ 104, 119919, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Plate Gauntlets
				{ 105, 119921, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Plate Legguards
				{ 107, 119898, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Armplates of Cruelty
				{ 108, 119899, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Armplates of Prowess
				{ 110, 119894, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Girdle of Cruelty
				{ 111, 119895, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Girdle of Prowess
				{ 113, 119896, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Warboots of Cruelty
				{ 114, 119897, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Warboots of Prowess
				{ 116, 120017 },	-- Primal Aspirant's Armplates of Cruelty
				{ 117, 120015 },	-- Primal Aspirant's Girdle of Cruelty
				{ 118, 120016 },	-- Primal Aspirant's Warboots of Cruelty
			},
		},
		{
			name = AL["Amulets"],
			[ALLIANCE_DIFF] = {
				{ 1, 115734, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Choker of Cruelty
				{ 2, 120108, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Choker of Endurance
				{ 3, 115735, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Choker of Prowess
				{ 5, 115606, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Necklace of Cruelty
				{ 6, 115607, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Necklace of Prowess
				{ 8, 115658, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Pendant of Contemplation
				{ 9, 115655, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Pendant of Cruelty
				{ 10, 115657, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Pendant of Meditation
				{ 11, 115656, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Pendant of Prowess
				{ 16, 115139, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Choker of Cruelty
				{ 17, 115140, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Choker of Prowess
				{ 18, 115034, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Necklace of Cruelty
				{ 19, 115035, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Necklace of Prowess
				{ 20, 115074, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Pendant of Contemplation
				{ 21, 115071, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Pendant of Cruelty
				{ 22, 115073, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Pendant of Meditation
				{ 23, 115072, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Pendant of Prowess
				{ 25, 115256 },	-- Primal Aspirant's Choker of Cruelty
				{ 26, 115191 },	-- Primal Aspirant's Necklace of Cruelty
				{ 27, 115212 },	-- Primal Aspirant's Pendant of Cruelty
			},
			[HORDE_DIFF] = {
				{ 1, 111207, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Choker of Cruelty
				{ 2, 120107, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Choker of Endurance
				{ 3, 111208, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Choker of Prowess
				{ 5, 111079, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Necklace of Cruelty
				{ 6, 111080, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Necklace of Prowess
				{ 8, 111131, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Pendant of Contemplation
				{ 9, 111128, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Pendant of Cruelty
				{ 10, 111130, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Pendant of Meditation
				{ 11, 111129, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Pendant of Prowess
				{ 16, 119916, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Choker of Cruelty
				{ 17, 119917, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Choker of Prowess
				{ 18, 119824, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Necklace of Cruelty
				{ 19, 119825, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Necklace of Prowess
				{ 20, 119857, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Pendant of Contemplation
				{ 21, 119854, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Pendant of Cruelty
				{ 22, 119856, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Pendant of Meditation
				{ 23, 119855, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Pendant of Prowess
				{ 25, 120033 },	-- Primal Aspirant's Choker of Cruelty
				{ 26, 119968 },	-- Primal Aspirant's Necklace of Cruelty
				{ 27, 119989 },	-- Primal Aspirant's Pendant of Cruelty
			},
		},
		{
			name = AL["Cloaks"],
			[ALLIANCE_DIFF] = {
				{ 1, 115604, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Cape of Cruelty
				{ 2, 115605, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Cape of Prowess
				{ 4, 115732, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Cloak of Cruelty
				{ 5, 120100, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Cloak of Endurance
				{ 6, 115733, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Cloak of Prowess
				{ 8, 115654, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Drape of Contemplation
				{ 9, 115651, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Drape of Cruelty
				{ 10, 115653, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Drape of Meditation
				{ 11, 115652, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Drape of Prowess
				{ 16, 115183, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Cape of Cruelty
				{ 17, 115184, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Cape of Prowess
				{ 18, 115189, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Cloak of Cruelty
				{ 19, 115190, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Cloak of Prowess
				{ 20, 115188, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Drape of Contemplation
				{ 21, 115185, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Drape of Cruelty
				{ 22, 115187, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Drape of Meditation
				{ 23, 115186, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Drape of Prowess
				{ 25, 115268 },	-- Primal Aspirant's Cape of Cruelty
				{ 26, 115271 },	-- Primal Aspirant's Cloak of Cruelty
				{ 27, 115269 },	-- Primal Aspirant's Drape of Cruelty
				{ 28, 115270 },	-- Primal Aspirant's Drape of Meditation
			},
			[HORDE_DIFF] = {
				{ 1, 111077, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Cape of Cruelty
				{ 2, 111078, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Cape of Prowess
				{ 4, 111205, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Cloak of Cruelty
				{ 5, 120099, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Cloak of Endurance
				{ 6, 111206, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Cloak of Prowess
				{ 8, 111127, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Drape of Contemplation
				{ 9, 111124, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Drape of Cruelty
				{ 10, 111126, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Drape of Meditation
				{ 11, 111125, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Drape of Prowess
				{ 16, 119960, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Cape of Cruelty
				{ 17, 119961, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Cape of Prowess
				{ 18, 119966, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Cloak of Cruelty
				{ 19, 119967, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Cloak of Prowess
				{ 20, 119965, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Drape of Contemplation
				{ 21, 119962, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Drape of Cruelty
				{ 22, 119964, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Drape of Meditation
				{ 23, 119963, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Drape of Prowess
				{ 25, 120045 },	-- Primal Aspirant's Cape of Cruelty
				{ 26, 120048 },	-- Primal Aspirant's Cloak of Cruelty
				{ 27, 120046 },	-- Primal Aspirant's Drape of Cruelty
				{ 28, 120047 },	-- Primal Aspirant's Drape of Meditation
			},
		},
		{
			name = AL["Rings"],
			[ALLIANCE_DIFF] = {
				{ 1, 115665, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Band of Contemplation
				{ 2, 115661, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Band of Cruelty
				{ 3, 115664, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Band of Meditation
				{ 4, 115662, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Band of Prowess
				{ 5, 115663, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Band of Victory
				{ 7, 115608, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Ring of Cruelty
				{ 8, 115609, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Ring of Prowess
				{ 9, 115771, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Ring of Prowess
				{ 11, 115747, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Signet of Accuracy
				{ 12, 115772, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Signet of Accuracy
				{ 13, 115746, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Signet of Cruelty
				{ 14, 120104, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Signet of Endurance
				{ 16, 115081, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Band of Contemplation
				{ 17, 115077, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Band of Cruelty
				{ 18, 115080, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Band of Meditation
				{ 19, 115078, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Band of Prowess
				{ 20, 115079, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Band of Victory
				{ 21, 115036, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Ring of Cruelty
				{ 22, 115037, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Ring of Prowess
				{ 23, 115171, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Ring of Prowess
				{ 24, 115147, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Signet of Accuracy
				{ 25, 115172, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Signet of Accuracy
				{ 26, 115146, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Signet of Cruelty
				{ 101, 115216 },	-- Primal Aspirant's Band of Contemplation
				{ 102, 115213 },	-- Primal Aspirant's Band of Cruelty
				{ 103, 115215 },	-- Primal Aspirant's Band of Meditation
				{ 104, 115214 },	-- Primal Aspirant's Band of Prowess
				{ 105, 115192 },	-- Primal Aspirant's Ring of Cruelty
				{ 106, 115193 },	-- Primal Aspirant's Ring of Prowess
				{ 107, 115257 },	-- Primal Aspirant's Signet of Cruelty
			},
			[HORDE_DIFF] = {
				{ 1, 111138, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Band of Contemplation
				{ 2, 111134, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Band of Cruelty
				{ 3, 111137, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Band of Meditation
				{ 4, 111135, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Band of Prowess
				{ 5, 111136, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Band of Victory
				{ 7, 111081, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Ring of Cruelty
				{ 8, 111082, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Ring of Prowess
				{ 9, 111271, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Ring of Prowess
				{ 11, 111220, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Signet of Accuracy
				{ 12, 111272, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Signet of Accuracy
				{ 13, 111219, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Signet of Cruelty
				{ 14, 120103, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Signet of Endurance
				{ 16, 119864, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Band of Contemplation
				{ 17, 119860, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Band of Cruelty
				{ 18, 119863, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Band of Meditation
				{ 19, 119861, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Band of Prowess
				{ 20, 119862, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Band of Victory
				{ 21, 119826, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Ring of Cruelty
				{ 22, 119827, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Ring of Prowess
				{ 23, 119948, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Ring of Prowess
				{ 24, 119924, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Signet of Accuracy
				{ 25, 119949, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Signet of Accuracy
				{ 26, 119923, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Signet of Cruelty
				{ 101, 119993 },	-- Primal Aspirant's Band of Contemplation
				{ 102, 119990 },	-- Primal Aspirant's Band of Cruelty
				{ 103, 119992 },	-- Primal Aspirant's Band of Meditation
				{ 104, 119991 },	-- Primal Aspirant's Band of Prowess
				{ 105, 119969 },	-- Primal Aspirant's Ring of Cruelty
				{ 106, 119970 },	-- Primal Aspirant's Ring of Prowess
				{ 107, 120034 },	-- Primal Aspirant's Signet of Cruelty
			},
		},
		{
			name = AL["Trinkets"],
			[ALLIANCE_DIFF] = {
				{ 1, 115496, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Badge of Adaptation
				{ 2, 115749, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Badge of Conquest
				{ 3, 115754, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Badge of Dominance
				{ 4, 115759, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Badge of Victory
				{ 5, 115751, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Emblem of Cruelty
				{ 6, 115753, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Emblem of Meditation
				{ 7, 115752, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Emblem of Tenacity
				{ 8, 115750, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Insignia of Conquest
				{ 9, 115755, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Insignia of Dominance
				{ 10, 115760, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Insignia of Victory
				{ 11, 115756, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Medallion of Cruelty
				{ 12, 115758, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Medallion of Meditation
				{ 13, 115757, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Medallion of Tenacity
				{ 16, 115521, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Badge of Adaptation
				{ 17, 115149, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Badge of Conquest
				{ 18, 115154, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Badge of Dominance
				{ 19, 115159, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Badge of Victory
				{ 20, 115151, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Emblem of Cruelty
				{ 21, 115153, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Emblem of Meditation
				{ 22, 115152, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Emblem of Tenacity
				{ 23, 115150, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Insignia of Conquest
				{ 24, 115155, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Insignia of Dominance
				{ 25, 115160, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Insignia of Victory
				{ 26, 115156, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Medallion of Cruelty
				{ 27, 115158, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Medallion of Meditation
				{ 28, 115157, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Medallion of Tenacity
			},
			[HORDE_DIFF] = {
				{ 1, 115495, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Badge of Adaptation
				{ 2, 111222, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Badge of Conquest
				{ 3, 111222, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Badge of Dominance
				{ 4, 111232, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Badge of Victory
				{ 5, 111224, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Emblem of Cruelty
				{ 6, 111226, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Emblem of Meditation
				{ 7, 111225, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Emblem of Tenacity
				{ 8, 111223, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Insignia of Conquest
				{ 9, 111228, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Insignia of Dominance
				{ 10, 111233, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Insignia of Victory
				{ 11, 111229, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Medallion of Cruelty
				{ 12, 111231, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Medallion of Meditation
				{ 13, 111230, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Medallion of Tenacity
				{ 16, 120049, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Badge of Adaptation
				{ 17, 119926, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Badge of Conquest
				{ 18, 119931, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Badge of Dominance
				{ 19, 119936, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Badge of Victory
				{ 20, 119928, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Emblem of Cruelty
				{ 21, 119930, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Emblem of Meditation
				{ 22, 119929, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Emblem of Tenacity
				{ 23, 119927, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Insignia of Conquest
				{ 24, 119932, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Insignia of Dominance
				{ 25, 119937, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Insignia of Victory
				{ 26, 119933, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Medallion of Cruelty
				{ 27, 119935, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Medallion of Meditation
				{ 28, 119934, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Medallion of Tenacity
			},
		},
		{
			name = AL["Miscellaneous"],
			[ALLIANCE_DIFF] = {
				{ 1, 115979, [PRICE_EXTRA_ITTYPE] = "conquest:1000" },	-- Primal Gladiator's Greatcloak (r2600)
				{ 3, 115972, [PRICE_EXTRA_ITTYPE] = "conquest:1000" },	-- Primal Gladiator's Tabard (r2600)
				{ 16, 115976, [PRICE_EXTRA_ITTYPE] = "112160:1:conquest:500" },	-- Enchant Weapon - Glory of the Blackrock (r2400)
				{ 17, 115978, [PRICE_EXTRA_ITTYPE] = "112165:1:conquest:500" },	-- Enchant Weapon - Glory of the Frostwolf (r2400)
				{ 18, 115975, [PRICE_EXTRA_ITTYPE] = "112115:1:conquest:500" },	-- Enchant Weapon - Glory of the Shadowmoon (r2400)
				{ 19, 115973, [PRICE_EXTRA_ITTYPE] = "110682:1:conquest:500" },	-- Enchant Weapon - Glory of the Thunderlord (r2400)
				{ 20, 115977, [PRICE_EXTRA_ITTYPE] = "112164:1:conquest:500" },	-- Enchant Weapon - Glory of the Warsong (r2400)
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
	},
}

data["WODS1WEAPONS"] = {
	name = string.format(AL["Warlords Season %d"], 1).." "..AL["Weapons"],
	ContentType = NORMAL_ITTYPE,
	items = {
		{
			name = string.format(AL["ilvl %d"], 660).." "..AL["Elite"],
			[ALLIANCE_DIFF] = {
				{ 1, 115949, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Render (r2000)
				{ 2, 115948, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Ripper (r2000)
				{ 4, 115832, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Spellblade (r2000)
				{ 5, 115947, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Shanker (r2000)
				{ 7, 115950, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Mageblade (r2000)
				{ 8, 115822, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Quickblade (r2000)
				{ 9, 115954, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Slicer (r2000)
				{ 11, 115820, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Cleaver (r2000)
				{ 12, 115952, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Hacker (r2000)
				{ 16, 115953, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Bonecracker (r2000)
				{ 17, 115863, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Gavel (r2000)
				{ 18, 115821, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Pummeler (r2000)
				{ 20, 115819, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Greatsword (r2000)
				{ 21, 115817, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Decapitator (r2000)
				{ 22, 115818, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Bonegrinder (r2000)
				{ 24, 115910, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Pike (r2000)
				{ 26, 115833, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Battle Staff (r2000)
				{ 27, 115865, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Energy Staff (r2000)
				{ 101, 115831, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Barrier (r2000)
				{ 102, 115864, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Redoubt (r2000)
				{ 103, 115955, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Shield Wall (r2000)
				{ 105, 115836, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Heavy Crossbow (r2000)
				{ 106, 115823, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Longbow (r2000)
				{ 107, 115862, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Rifle (r2000)
				{ 116, 115951, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Baton of Light (r2000)
				{ 117, 115835, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Touch of Defeat (r2000)
				{ 119, 115834, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Reprieve (r2000)
				{ 120, 115830, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Endgame (r2000)
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
		{
			name = string.format(AL["ilvl %d"], 660).." (690)",
			[ALLIANCE_DIFF] = {
				{ 1, 115726, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Render
				{ 2, 115596, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Ripper
				{ 4, 115644, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Spellblade
				{ 5, 115595, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Shanker
				{ 7, 115646, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Mageblade
				{ 8, 115598, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Quickblade
				{ 9, 115728, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Slicer
				{ 11, 115594, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Cleaver
				{ 12, 115725, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Hacker
				{ 16, 115727, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Bonecracker
				{ 17, 115645, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Gavel
				{ 18, 115597, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Pummeler
				{ 20, 115731, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Greatsword
				{ 21, 115729, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Decapitator
				{ 22, 115730, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Bonegrinder
				{ 24, 115602, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Pike
				{ 26, 115649, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Battle Staff
				{ 27, 115650, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Energy Staff
				{ 101, 115667, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Barrier
				{ 102, 115666, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Redoubt
				{ 103, 115748, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Shield Wall
				{ 105, 115600, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Heavy Crossbow
				{ 106, 115599, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Longbow
				{ 107, 115601, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Rifle
				{ 116, 115647, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Baton of Light
				{ 117, 115648, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Touch of Defeat
				{ 119, 115660, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Reprieve
				{ 120, 115659, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Endgame
			},
			[HORDE_DIFF] = {
				{ 1, 111199, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Render
				{ 2, 111069, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Ripper
				{ 4, 111117, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Spellblade
				{ 5, 111068, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Shanker
				{ 7, 111119, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Mageblade
				{ 8, 111071, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Quickblade
				{ 9, 111201, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Slicer
				{ 11, 111067, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Cleaver
				{ 12, 111198, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Hacker
				{ 16, 111200, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Bonecracker
				{ 17, 111118, [PRICE_EXTRA_ITTYPE] = "conquest:2250" },	-- Primal Gladiator's Gavel
				{ 18, 111070, [PRICE_EXTRA_ITTYPE] = "conquest:1750" },	-- Primal Gladiator's Pummeler
				{ 20, 111204, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Greatsword
				{ 21, 111202, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Decapitator
				{ 22, 111203, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Bonegrinder
				{ 24, 111075, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Pike
				{ 26, 111122, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Battle Staff
				{ 27, 111123, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Energy Staff
				{ 101, 111140, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Barrier
				{ 102, 111139, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Redoubt
				{ 103, 111221, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Shield Wall
				{ 105, 111073, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Heavy Crossbow
				{ 106, 111072, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Longbow
				{ 107, 111074, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Rifle
				{ 116, 111120, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Baton of Light
				{ 117, 111121, [PRICE_EXTRA_ITTYPE] = "conquest:3500" },	-- Primal Gladiator's Touch of Defeat
				{ 119, 111133, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Reprieve
				{ 120, 111132, [PRICE_EXTRA_ITTYPE] = "conquest:1250" },	-- Primal Gladiator's Endgame
			},
		},
		{
			name = string.format(AL["ilvl %d"], 620).." (675)",
			[ALLIANCE_DIFF] = {
				{ 1, 120071, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Render
				{ 2, 120055, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Ripper
				{ 4, 120063, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Spellblade
				{ 5, 120054, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Shanker
				{ 7, 120065, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Mageblade
				{ 8, 120057, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Quickblade
				{ 9, 120073, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Slicer
				{ 11, 120053, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Cleaver
				{ 12, 120070, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Hacker
				{ 16, 120072, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Bonecracker
				{ 17, 120064, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Gavel
				{ 18, 120056, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Pummeler
				{ 20, 120076, [PRICE_EXTRA_ITTYPE] = "honor:3500" },	-- Primal Combatant's Greatsword
				{ 21, 120074, [PRICE_EXTRA_ITTYPE] = "honor:3500" },	-- Primal Combatant's Decapitator
				{ 22, 120075, [PRICE_EXTRA_ITTYPE] = "honor:3500" },	-- Primal Combatant's Bonegrinder
				{ 24, 120061, [PRICE_EXTRA_ITTYPE] = "honor:3500" },	-- Primal Combatant's Pike
				{ 26, 120068, [PRICE_EXTRA_ITTYPE] = "honor:3500" },	-- Primal Combatant's Battle Staff
				{ 27, 120069, [PRICE_EXTRA_ITTYPE] = "honor:3500" },	-- Primal Combatant's Energy Staff
				{ 28, 120062, [PRICE_EXTRA_ITTYPE] = "honor:3500" },	-- Primal Combatant's Staff
				{ 101, 115083, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Barrier
				{ 102, 115082, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Redoubt
				{ 103, 115148, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Shield Wall
				{ 105, 120059, [PRICE_EXTRA_ITTYPE] = "honor:3500" },	-- Primal Combatant's Heavy Crossbow
				{ 106, 120058, [PRICE_EXTRA_ITTYPE] = "honor:3500" },	-- Primal Combatant's Longbow
				{ 107, 120060, [PRICE_EXTRA_ITTYPE] = "honor:3500" },	-- Primal Combatant's Rifle
				{ 116, 120066, [PRICE_EXTRA_ITTYPE] = "honor:3500" },	-- Primal Combatant's Baton of Light
				{ 117, 120067, [PRICE_EXTRA_ITTYPE] = "honor:3500" },	-- Primal Combatant's Touch of Defeat
				{ 119, 115076, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Reprieve
				{ 120, 115075, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Endgame
			},
			[HORDE_DIFF] = {
				{ 1, 115133, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Render
				{ 2, 115026, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Ripper
				{ 4, 115064, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Spellblade
				{ 5, 115025, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Shanker
				{ 7, 115066, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Mageblade
				{ 8, 115028, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Quickblade
				{ 9, 115135, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Slicer
				{ 11, 115024, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Cleaver
				{ 12, 115132, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Hacker
				{ 16, 115134, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Bonecracker
				{ 17, 115065, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Primal Combatant's Gavel
				{ 18, 115027, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Primal Combatant's Pummeler
				{ 20, 115138, [PRICE_EXTRA_ITTYPE] = "honor:3500" },	-- Primal Combatant's Greatsword
				{ 21, 115136, [PRICE_EXTRA_ITTYPE] = "honor:3500" },	-- Primal Combatant's Decapitator
				{ 22, 115137, [PRICE_EXTRA_ITTYPE] = "honor:3500" },	-- Primal Combatant's Bonegrinder
				{ 24, 115032, [PRICE_EXTRA_ITTYPE] = "honor:3500" },	-- Primal Combatant's Pike
				{ 26, 115069, [PRICE_EXTRA_ITTYPE] = "honor:3500" },	-- Primal Combatant's Battle Staff
				{ 27, 115070, [PRICE_EXTRA_ITTYPE] = "honor:3500" },	-- Primal Combatant's Energy Staff
				{ 28, 115033, [PRICE_EXTRA_ITTYPE] = "honor:3500" },	-- Primal Combatant's Staff
				{ 101, 119866, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Barrier
				{ 102, 119865, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Redoubt
				{ 103, 119925, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Shield Wall
				{ 105, 115030, [PRICE_EXTRA_ITTYPE] = "honor:3500" },	-- Primal Combatant's Heavy Crossbow
				{ 106, 115029, [PRICE_EXTRA_ITTYPE] = "honor:3500" },	-- Primal Combatant's Longbow
				{ 107, 115031, [PRICE_EXTRA_ITTYPE] = "honor:3500" },	-- Primal Combatant's Rifle
				{ 116, 115067, [PRICE_EXTRA_ITTYPE] = "honor:3500" },	-- Primal Combatant's Baton of Light
				{ 117, 115068, [PRICE_EXTRA_ITTYPE] = "honor:3500" },	-- Primal Combatant's Touch of Defeat
				{ 119, 119859, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Reprieve
				{ 120, 119858, [PRICE_EXTRA_ITTYPE] = "honor:1250" },	-- Primal Combatant's Endgame
			},
		},
	},
}

-- Mists of Pandaria Season 15

data["MOPS15SETS"] = {
	name = string.format(AL["Season %d"], 15).." "..AL["Class Sets"].." ("..AL["Mists of Pandaria"]..")",
	ContentType = NORMAL_ITTYPE,
	items = {
		{
			name = LOCALIZED_CLASS_NAMES_MALE["DEATHKNIGHT"],
			[ALLIANCE_DIFF] = {
				{ 1, 102713, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Dreadplate Helm
				{ 2, 102652, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Dreadplate Shoulders
				{ 3, 102676, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Dreadplate Chestpiece
				{ 4, 102650, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Dreadplate Gauntlets
				{ 5, 102651, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Dreadplate Legguards
				{ 16, 103181, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Dreadplate Helm
				{ 17, 103183, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Dreadplate Shoulders
				{ 18, 103179, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Dreadplate Chestpiece
				{ 19, 103180, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Dreadplate Gauntlets
				{ 20, 103182, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Dreadplate Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 103378, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Dreadplate Helm
				{ 2, 103380, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Dreadplate Shoulders
				{ 3, 103376, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Dreadplate Chestpiece
				{ 4, 103377, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Dreadplate Gauntlets
				{ 5, 103379, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Dreadplate Legguards
				{ 16, 102910, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Dreadplate Helm
				{ 17, 102849, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Dreadplate Shoulders
				{ 18, 102873, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Dreadplate Chestpiece
				{ 19, 102847, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Dreadplate Gauntlets
				{ 20, 102848, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Dreadplate Legguards
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["DRUID"],
			[ALLIANCE_DIFF] = {
				-- Moonkin, 550 > 522
				{ 1, 102634, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Wyrmhide Helm
				{ 2, 102700, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Wyrmhide Spaulders
				{ 3, 102614, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Wyrmhide Robes
				{ 4, 102696, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Wyrmhide Gloves
				{ 5, 102767, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Wyrmhide Legguards
				{ 16, 103202, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Wyrmhide Helm
				{ 17, 103205, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Wyrmhide Spaulders
				{ 18, 103204, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Wyrmhide Robes
				{ 19, 103201, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Wyrmhide Gloves
				{ 20, 103203, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Wyrmhide Legguards
				-- Cat/Bear, 550 > 522
				{ 7, 102653, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Dragonhide Helm
				{ 8, 102741, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Dragonhide Spaulders
				{ 9, 102740, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Dragonhide Robes
				{ 10, 102739, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Dragonhide Gloves
				{ 11, 102654, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Dragonhide Legguards
				{ 22, 103185, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Dragonhide Helm
				{ 23, 103188, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Dragonhide Spaulders
				{ 24, 103187, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Dragonhide Robes
				{ 25, 103184, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Dragonhide Gloves
				{ 26, 103186, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Dragonhide Legguards
				-- Heal, 550 > 522
				{ 101, 102776, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Kodohide Helm
				{ 102, 102658, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Kodohide Spaulders
				{ 103, 102721, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Kodohide Robes
				{ 104, 102657, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Kodohide Gloves
				{ 105, 102761, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Kodohide Legguards
				{ 116, 103193, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Kodohide Helm
				{ 117, 103196, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Kodohide Spaulders
				{ 118, 103195, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Kodohide Robes
				{ 119, 103192, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Kodohide Gloves
				{ 120, 103194, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Kodohide Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				-- Moonkin, 550 > 522
				{ 1, 103399, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Wyrmhide Helm
				{ 2, 103402, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Wyrmhide Spaulders
				{ 3, 103401, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Wyrmhide Robes
				{ 4, 103398, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Wyrmhide Gloves
				{ 5, 103400, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Wyrmhide Legguards
				{ 16, 102831, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Wyrmhide Helm
				{ 17, 102897, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Wyrmhide Spaulders
				{ 18, 102811, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Wyrmhide Robes
				{ 19, 102893, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Wyrmhide Gloves
				{ 20, 102964, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Wyrmhide Legguards
				-- Cat/Bear, 550 > 522
				{ 7, 103382, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Dragonhide Helm
				{ 8, 103385, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Dragonhide Spaulders
				{ 9, 103384, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Dragonhide Robes
				{ 10, 103381, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Dragonhide Gloves
				{ 11, 103383, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Dragonhide Legguards
				{ 22, 102850, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Dragonhide Helm
				{ 23, 102938, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Dragonhide Spaulders
				{ 24, 102937, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Dragonhide Robes
				{ 25, 102936, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Dragonhide Gloves
				{ 26, 102851, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Dragonhide Legguards
				-- Heal, 550 > 522
				{ 101, 103390, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Kodohide Helm
				{ 102, 103393, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Kodohide Spaulders
				{ 103, 103392, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Kodohide Robes
				{ 104, 103389, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Kodohide Gloves
				{ 105, 103391, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Kodohide Legguards
				{ 116, 102973, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Kodohide Helm
				{ 117, 102855, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Kodohide Spaulders
				{ 118, 102918, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Kodohide Robes
				{ 119, 102854, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Kodohide Gloves
				{ 120, 102958, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Kodohide Legguards
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["HUNTER"],
			[ALLIANCE_DIFF] = {
				{ 1, 102690, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Chain Helm
				{ 2, 102734, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Chain Spaulders
				{ 3, 102689, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Chain Armor
				{ 4, 102737, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Chain Gauntlets
				{ 5, 102670, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Chain Leggings
				{ 16, 103221, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Chain Helm
				{ 17, 103223, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Chain Spaulders
				{ 18, 103219, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Chain Armor
				{ 19, 103220, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Chain Gauntlets
				{ 20, 103222, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Chain Leggings
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 103418, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Chain Helm
				{ 2, 103420, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Chain Spaulders
				{ 3, 103416, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Chain Armor
				{ 4, 103417, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Chain Gauntlets
				{ 5, 103419, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Chain Leggings
				{ 16, 102887, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Chain Helm
				{ 17, 102931, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Chain Spaulders
				{ 18, 102886, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Chain Armor
				{ 19, 102934, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Chain Gauntlets
				{ 20, 102867, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Chain Leggings
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["MAGE"],
			[ALLIANCE_DIFF] = {
				{ 1, 102667, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Silk Cowl
				{ 2, 102673, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Silk Amice
				{ 3, 102715, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Silk Robe
				{ 4, 102735, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Silk Handguards
				{ 5, 102648, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Silk Trousers
				{ 16, 103225, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Silk Cowl
				{ 17, 103228, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Silk Amice
				{ 18, 103227, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Silk Robe
				{ 19, 103224, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Silk Handguards
				{ 20, 103226, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Silk Trousers
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				{ 1, 103422, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Silk Cowl
				{ 2, 103425, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Silk Amice
				{ 3, 103424, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Silk Robe
				{ 4, 103421, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Silk Handguards
				{ 5, 103423, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Silk Trousers
				{ 16, 102864, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Silk Cowl
				{ 17, 102870, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Silk Amice
				{ 18, 102912, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Silk Robe
				{ 19, 102932, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Silk Handguards
				{ 20, 102845, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Silk Trousers
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["MONK"],
			[ALLIANCE_DIFF] = {
				-- Windwalker, 550 > 522
				{ 1, 102712, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Ironskin Helm
				{ 2, 102626, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Ironskin Spaulders
				{ 3, 102720, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Ironskin Tunic
				{ 4, 102675, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Ironskin Gloves
				{ 5, 102656, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Ironskin Legguards
				{ 16, 103233, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Ironskin Helm
				{ 17, 103235, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Ironskin Spaulders
				{ 18, 103236, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Ironskin Tunic
				{ 19, 103232, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Ironskin Gloves
				{ 20, 103234, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Ironskin Legguards
				-- Mistweaver, 550 > 522
				{ 7, 102628, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Copperskin Helm
				{ 8, 102777, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Copperskin Spaulders
				{ 9, 102763, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Copperskin Tunic
				{ 10, 102627, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Copperskin Gloves
				{ 11, 102762, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Copperskin Legguards
				{ 22, 103238, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Copperskin Helm
				{ 23, 103240, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Copperskin Spaulders
				{ 24, 103241, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Copperskin Tunic
				{ 25, 103237, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Copperskin Gloves
				{ 26, 103239, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Copperskin Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				-- Windwalker, 550 > 522
				{ 1, 103430, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Ironskin Helm
				{ 2, 103432, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Ironskin Spaulders
				{ 3, 103433, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Ironskin Tunic
				{ 4, 103429, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Ironskin Gloves
				{ 5, 103431, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Ironskin Legguards
				{ 16, 102909, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Ironskin Helm
				{ 17, 102823, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Ironskin Spaulders
				{ 18, 102917, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Ironskin Tunic
				{ 19, 102872, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Ironskin Gloves
				{ 20, 102853, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Ironskin Legguards
				-- Mistweaver, 550 > 522
				{ 7, 103435, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Copperskin Helm
				{ 8, 103437, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Copperskin Spaulders
				{ 9, 103438, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Copperskin Tunic
				{ 10, 103434, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Copperskin Gloves
				{ 11, 103436, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Copperskin Legguards
				{ 22, 102825, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Copperskin Helm
				{ 23, 102974, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Copperskin Spaulders
				{ 24, 102960, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Copperskin Tunic
				{ 25, 102824, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Copperskin Gloves
				{ 26, 102959, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Copperskin Legguards
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["PALADIN"],
			[ALLIANCE_DIFF] = {
				-- Retribution, 550 > 522
				{ 1, 102779, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Scaled Helm
				{ 2, 102744, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Scaled Spaulders
				{ 3, 102747, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Scaled Chestguard
				{ 4, 102630, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Scaled Gloves
				{ 5, 102780, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Scaled Legguards
				{ 16, 103244, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Scaled Helm
				{ 17, 103246, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Scaled Spaulders
				{ 18, 103242, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Scaled Chestguard
				{ 19, 103243, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Scaled Gloves
				{ 20, 103245, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Scaled Legguards
				-- Holy, 550 > 522
				{ 7, 102635, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Ornamented Helm
				{ 8, 102697, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Ornamented Spaulders
				{ 9, 102632, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Ornamented Chestguard
				{ 10, 102722, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Ornamented Gloves
				{ 11, 102768, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Ornamented Legguards
				{ 22, 103255, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Ornamented Helm
				{ 23, 103257, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Ornamented Spaulders
				{ 24, 103253, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Ornamented Chestguard
				{ 25, 103254, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Ornamented Gloves
				{ 26, 103256, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Ornamented Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				-- Retribution, 550 > 522
				{ 1, 103441, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Scaled Helm
				{ 2, 103443, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Scaled Spaulders
				{ 3, 103439, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Scaled Chestguard
				{ 4, 103440, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Scaled Gloves
				{ 5, 103442, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Scaled Legguards
				{ 16, 102976, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Scaled Helm
				{ 17, 102941, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Scaled Spaulders
				{ 18, 102944, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Scaled Chestguard
				{ 19, 102827, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Scaled Gloves
				{ 20, 102977, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Scaled Legguards
				-- Holy, 550 > 522
				{ 7, 103452, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Ornamented Helm
				{ 8, 103454, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Ornamented Spaulders
				{ 9, 103450, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Ornamented Chestguard
				{ 10, 103451, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Prideful Gladiator's Ornamented Gloves
				{ 11, 103453, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Prideful Gladiator's Ornamented Legguards
				{ 22, 102832, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Ornamented Helm
				{ 23, 102894, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Ornamented Spaulders
				{ 24, 102829, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Ornamented Chestguard
				{ 25, 102919, [PRICE_EXTRA_ITTYPE] = "honor:1750" },	-- Grievous Gladiator's Ornamented Gloves
				{ 26, 102965, [PRICE_EXTRA_ITTYPE] = "honor:2250" },	-- Grievous Gladiator's Ornamented Legguards
			},
		},
	},
}
-- Classic Season 5
data["CLASSICS5SETS"] = {
	name = string.format(AL["Season %d"], 5).." "..AL["Class Sets"].." ("..AL["Wrath of the Lich King"]..")",
	ContentType = NORMAL_ITTYPE,
	items = {
		{
			name = LOCALIZED_CLASS_NAMES_MALE["DEATHKNIGHT"],
			[ALLIANCE_DIFF] = {
				{ 1, 40824, [PRICE_EXTRA_ITTYPE] = "money:1418900" }, -- Deadly Gladiator's Dreadplate Helm
				{ 2, 40863, [PRICE_EXTRA_ITTYPE] = "money:1451400" }, -- Deadly Gladiator's Dreadplate Shoulders
				{ 3, 40784, [PRICE_EXTRA_ITTYPE] = "money:1896000" }, -- Deadly Gladiator's Dreadplate Chestpiece
				{ 4, 40806, [PRICE_EXTRA_ITTYPE] = "money:960400" }, -- Deadly Gladiator's Dreadplate Gauntlets
				{ 5, 40845, [PRICE_EXTRA_ITTYPE] = "money:1953400" }, -- Deadly Gladiator's Dreadplate Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["DRUID"],
			[ALLIANCE_DIFF] = {
				{ 1, 41677, [PRICE_EXTRA_ITTYPE] = "money:1505300" }, -- Deadly Gladiator's Dragonhide Helm
				{ 2, 41714, [PRICE_EXTRA_ITTYPE] = "money:1489000" }, -- Deadly Gladiator's Dragonhide Spaulders
				{ 3, 41660, [PRICE_EXTRA_ITTYPE] = "money:1981300" }, -- Deadly Gladiator's Dragonhide Robes
				{ 4, 41772, [PRICE_EXTRA_ITTYPE] = "money:992700" }, -- Deadly Gladiator's Dragonhide Gloves
				{ 5, 41666, [PRICE_EXTRA_ITTYPE] = "money:1882000" }, -- Deadly Gladiator's Dragonhide Legguards
				{ 7, 41320, [PRICE_EXTRA_ITTYPE] = "money:1477800" }, -- Deadly Gladiator's Kodohide Helm
				{ 8, 41274, [PRICE_EXTRA_ITTYPE] = "money:1408400" }, -- Deadly Gladiator's Kodohide Spaulders
				{ 9, 41309, [PRICE_EXTRA_ITTYPE] = "money:1896400" }, -- Deadly Gladiator's Kodohide Robes
				{ 10, 41286, [PRICE_EXTRA_ITTYPE] = "money:1014300" }, -- Deadly Gladiator's Kodohide Gloves
				{ 11, 41297, [PRICE_EXTRA_ITTYPE] = "money:1953200" }, -- Deadly Gladiator's Kodohide Legguards
				{ 16, 41326, [PRICE_EXTRA_ITTYPE] = "money:1403600" }, -- Deadly Gladiator's Wyrmhide Helm
				{ 17, 41280, [PRICE_EXTRA_ITTYPE] = "money:1478200" }, -- Deadly Gladiator's Wyrmhide Spaulders
				{ 18, 41315, [PRICE_EXTRA_ITTYPE] = "money:1938900" }, -- Deadly Gladiator's Wyrmhide Robes
				{ 19, 41292, [PRICE_EXTRA_ITTYPE] = "money:964400" }, -- Deadly Gladiator's Wyrmhide Gloves
				{ 20, 41303, [PRICE_EXTRA_ITTYPE] = "money:1995700" }, -- Deadly Gladiator's Wyrmhide Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["HUNTER"],
			[ALLIANCE_DIFF] = {
				{ 1, 41156, [PRICE_EXTRA_ITTYPE] = "money:1381800" }, -- Deadly Gladiator's Chain Helm
				{ 2, 41216, [PRICE_EXTRA_ITTYPE] = "money:1419400" }, -- Deadly Gladiator's Chain Spaulders
				{ 3, 41086, [PRICE_EXTRA_ITTYPE] = "money:1917800" }, -- Deadly Gladiator's Chain Armor
				{ 4, 41142, [PRICE_EXTRA_ITTYPE] = "money:949700" }, -- Deadly Gladiator's Chain Gauntlets
				{ 5, 41204, [PRICE_EXTRA_ITTYPE] = "money:1953000" }, -- Deadly Gladiator's Chain Leggings
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["MAGE"],
			[ALLIANCE_DIFF] = {
				{ 1, 41945, [PRICE_EXTRA_ITTYPE] = "money:1371200" }, -- Deadly Gladiator's Silk Cowl
				{ 2, 41964, [PRICE_EXTRA_ITTYPE] = "money:1509900" }, -- Deadly Gladiator's Silk Amice
				{ 3, 41951, [PRICE_EXTRA_ITTYPE] = "money:1925300" }, -- Deadly Gladiator's Silk Raiment
				{ 4, 41970, [PRICE_EXTRA_ITTYPE] = "money:964400" }, -- Deadly Gladiator's Silk Handguards
				{ 5, 41958, [PRICE_EXTRA_ITTYPE] = "money:1974700" }, -- Deadly Gladiator's Silk Trousers
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["PALADIN"],
			[ALLIANCE_DIFF] = {
				{ 1, 40932, [PRICE_EXTRA_ITTYPE] = "money:1392400" }, -- Deadly Gladiator's Ornamented Headcover
				{ 2, 40962, [PRICE_EXTRA_ITTYPE] = "money:1483300" }, -- Deadly Gladiator's Ornamented Spaulders
				{ 3, 40905, [PRICE_EXTRA_ITTYPE] = "money:1952600" }, -- Deadly Gladiator's Ornamented Chestguard
				{ 4, 40926, [PRICE_EXTRA_ITTYPE] = "money:1010900" }, -- Deadly Gladiator's Ornamented Gloves
				{ 5, 40938, [PRICE_EXTRA_ITTYPE] = "money:1953600" }, -- Deadly Gladiator's Ornamented Legplates
				{ 16, 40825, [PRICE_EXTRA_ITTYPE] = "money:1462400" }, -- Deadly Gladiator's Scaled Helm
				{ 17, 40864, [PRICE_EXTRA_ITTYPE] = "money:1456600" }, -- Deadly Gladiator's Scaled Shoulders
				{ 18, 40785, [PRICE_EXTRA_ITTYPE] = "money:1903000" }, -- Deadly Gladiator's Scaled Chestpiece
				{ 19, 40805, [PRICE_EXTRA_ITTYPE] = "money:956800" }, -- Deadly Gladiator's Scaled Gauntlets
				{ 20, 40846, [PRICE_EXTRA_ITTYPE] = "money:1960300" }, -- Deadly Gladiator's Scaled Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["PRIEST"],
			[ALLIANCE_DIFF] = {
				{ 1, 41853, [PRICE_EXTRA_ITTYPE] = "money:1376400" }, -- Deadly Gladiator's Mooncloth Hood
				{ 2, 41868, [PRICE_EXTRA_ITTYPE] = "money:1493900" }, -- Deadly Gladiator's Mooncloth Mantle
				{ 3, 41858, [PRICE_EXTRA_ITTYPE] = "money:1925100" }, -- Deadly Gladiator's Mooncloth Robe
				{ 4, 41873, [PRICE_EXTRA_ITTYPE] = "money:950100" }, -- Deadly Gladiator's Mooncloth Gloves
				{ 5, 41863, [PRICE_EXTRA_ITTYPE] = "money:1960300" }, -- Deadly Gladiator's Mooncloth Leggings
				{ 16, 41914, [PRICE_EXTRA_ITTYPE] = "money:1419300" }, -- Deadly Gladiator's Satin Hood
				{ 17, 41933, [PRICE_EXTRA_ITTYPE] = "money:1413800" }, -- Deadly Gladiator's Satin Mantle
				{ 18, 41920, [PRICE_EXTRA_ITTYPE] = "money:1989400" }, -- Deadly Gladiator's Satin Robe
				{ 19, 41939, [PRICE_EXTRA_ITTYPE] = "money:996700" }, -- Deadly Gladiator's Satin Gloves
				{ 20, 41926, [PRICE_EXTRA_ITTYPE] = "money:1839100" }, -- Deadly Gladiator's Satin Leggings
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["ROGUE"],
			[ALLIANCE_DIFF] = {
				{ 1, 41671, [PRICE_EXTRA_ITTYPE] = "money:1435300" }, -- Deadly Gladiator's Leather Helm
				{ 2, 41682, [PRICE_EXTRA_ITTYPE] = "money:1387500" }, -- Deadly Gladiator's Leather Spaulders
				{ 3, 41649, [PRICE_EXTRA_ITTYPE] = "money:1903500" }, -- Deadly Gladiator's Leather Tunic
				{ 4, 41766, [PRICE_EXTRA_ITTYPE] = "money:971400" }, -- Deadly Gladiator's Leather Gloves
				{ 5, 41654, [PRICE_EXTRA_ITTYPE] = "money:1938900" }, -- Deadly Gladiator's Leather Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["SHAMAN"],
			[ALLIANCE_DIFF] = {
				{ 1, 41150, [PRICE_EXTRA_ITTYPE] = "money:1494400" }, -- Deadly Gladiator's Linked Helm
				{ 2, 41210, [PRICE_EXTRA_ITTYPE] = "money:1493800" }, -- Deadly Gladiator's Linked Spaulders
				{ 3, 41080, [PRICE_EXTRA_ITTYPE] = "money:2016900" }, -- Deadly Gladiator's Linked Armor
				{ 4, 41136, [PRICE_EXTRA_ITTYPE] = "money:928300" }, -- Deadly Gladiator's Linked Gauntlets
				{ 5, 41198, [PRICE_EXTRA_ITTYPE] = "money:1910700" }, -- Deadly Gladiator's Linked Leggings
				{ 7, 41018, [PRICE_EXTRA_ITTYPE] = "money:1499800" }, -- Deadly Gladiator's Mail Helm
				{ 8, 41043, [PRICE_EXTRA_ITTYPE] = "money:1381800" }, -- Deadly Gladiator's Mail Spaulders
				{ 9, 40991, [PRICE_EXTRA_ITTYPE] = "money:1903300" }, -- Deadly Gladiator's Mail Armor
				{ 10, 41006, [PRICE_EXTRA_ITTYPE] = "money:939200" }, -- Deadly Gladiator's Mail Gauntlets
				{ 11, 41032, [PRICE_EXTRA_ITTYPE] = "money:1909900" }, -- Deadly Gladiator's Mail Leggings
				{ 16, 41012, [PRICE_EXTRA_ITTYPE] = "money:1429800" }, -- Deadly Gladiator's Ringmail Helm
				{ 17, 41037, [PRICE_EXTRA_ITTYPE] = "money:1494400" }, -- Deadly Gladiator's Ringmail Spaulders
				{ 18, 40990, [PRICE_EXTRA_ITTYPE] = "money:1896200" }, -- Deadly Gladiator's Ringmail Armor
				{ 19, 41000, [PRICE_EXTRA_ITTYPE] = "money:989000" }, -- Deadly Gladiator's Ringmail Gauntlets
				{ 20, 41026, [PRICE_EXTRA_ITTYPE] = "money:1867400" }, -- Deadly Gladiator's Ringmail Leggings
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["WARLOCK"],
			[ALLIANCE_DIFF] = {
				{ 1, 41992, [PRICE_EXTRA_ITTYPE] = "money:1446100" }, -- Deadly Gladiator's Felweave Cowl
				{ 2, 42010, [PRICE_EXTRA_ITTYPE] = "money:1435300" }, -- Deadly Gladiator's Felweave Amice
				{ 3, 41997, [PRICE_EXTRA_ITTYPE] = "money:1967200" }, -- Deadly Gladiator's Felweave Raiment
				{ 4, 42016, [PRICE_EXTRA_ITTYPE] = "money:1011200" }, -- Deadly Gladiator's Felweave Handguards
				{ 5, 42004, [PRICE_EXTRA_ITTYPE] = "money:1875100" }, -- Deadly Gladiator's Felweave Trousers
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["WARRIOR"],
			[ALLIANCE_DIFF] = {
				{ 1, 40823, [PRICE_EXTRA_ITTYPE] = "money:1413500" }, -- Deadly Gladiator's Plate Helm
				{ 2, 40862, [PRICE_EXTRA_ITTYPE] = "money:1446100" }, -- Deadly Gladiator's Plate Shoulders
				{ 3, 40786, [PRICE_EXTRA_ITTYPE] = "money:1910100" }, -- Deadly Gladiator's Plate Chestpiece
				{ 4, 40804, [PRICE_EXTRA_ITTYPE] = "money:953200" }, -- Deadly Gladiator's Plate Gauntlets
				{ 5, 40844, [PRICE_EXTRA_ITTYPE] = "money:1946300" }, -- Deadly Gladiator's Plate Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
	},
}
-- Classic Season 4
data["CLASSICS4SETS"] = {
	name = string.format(AL["Season %d"], 4).." "..AL["Class Sets"].." ("..AL["Burning Crusade"]..")",
	ContentType = NORMAL_ITTYPE,
	items = {
		{
			name = LOCALIZED_CLASS_NAMES_MALE["DEATHKNIGHT"],
			[ALLIANCE_DIFF] = {
				{ 1, 40442, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Dreadplate Helm
				{ 2, 40444, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Dreadplate Shoulders
				{ 3, 40440, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Dreadplate Chestpiece
				{ 4, 40441, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Dreadplate Gauntlets
				{ 5, 40443, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Dreadplate Legguards
				
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["DRUID"],
			[ALLIANCE_DIFF] = {
				{ 1, 34999, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Dragonhide Helm
				{ 2, 35001, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Dragonhide Spaulders
				{ 3, 35002, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Dragonhide Tunic
				{ 4, 34998, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Dragonhide Gloves
				{ 5, 35000, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Dragonhide Legguards
				{ 7, 35023, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Kodohide Helm
				{ 8, 35025, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Kodohide Spaulders
				{ 9, 35026, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Kodohide Tunic
				{ 10, 35022, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Kodohide Gloves
				{ 11, 35024, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Kodohide Legguards
				{ 16, 35112, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Wyrmhide Helm
				{ 17, 35114, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Wyrmhide Spaulders
				{ 18, 35115, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Wyrmhide Tunic
				{ 19, 35111, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Wyrmhide Gloves
				{ 20, 35113, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Wyrmhide Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["HUNTER"],
			[ALLIANCE_DIFF] = {
				{ 1, 34992, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Chain Helm
				{ 2, 34994, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Chain Spaulders
				{ 3, 34990, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Chain Armor
				{ 4, 34991, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Chain Gauntlets
				{ 5, 34993, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Chain Leggings
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["MAGE"],
			[ALLIANCE_DIFF] = {
				{ 1, 35097, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Silk Cowl
				{ 2, 35096, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Silk Amice
				{ 3, 35099, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Silk Raiment
				{ 5, 35098, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Silk Handguards
				{ 6, 35100, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Silk Trousers
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["PALADIN"],
			[ALLIANCE_DIFF] = {
				{ 1, 35029, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Lamellar Helm
				{ 2, 35031, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Lamellar Shoulders
				{ 3, 35027, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Lamellar Chestpiece
				{ 4, 35028, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Lamellar Gauntlets
				{ 5, 35030, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Lamellar Legguards
				{ 7, 35061, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Ornamented Headcover
				{ 8, 35063, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Ornamented Spaulders
				{ 9, 35059, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Ornamented Chestguard
				{ 10, 35060, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Ornamented Gloves
				{ 11, 35062, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Ornamented Legplates
				{ 16, 35090, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Scaled Helm
				{ 17, 35092, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Scaled Shoulders
				{ 18, 35088, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Scaled Chestpiece
				{ 19, 35089, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Scaled Gauntlets
				{ 20, 35091, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Scaled Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["PRIEST"],
			[ALLIANCE_DIFF] = {
				{ 1, 35054, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Mooncloth Hood
				{ 2, 35056, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Mooncloth Mantle
				{ 3, 35057, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Mooncloth Robe
				{ 4, 35053, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Mooncloth Gloves
				{ 5, 35055, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Mooncloth Leggings
				{ 16, 35084, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Satin Hood
				{ 17, 35086, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Satin Mantle
				{ 18, 35087, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Satin Robe
				{ 19, 35083, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Satin Gloves
				{ 20, 35085, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Satin Leggings
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["ROGUE"],
			[ALLIANCE_DIFF] = {
				{ 1, 35033, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Leather Helm
				{ 2, 35035, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Leather Spaulders
				{ 3, 35036, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Leather Tunic
				{ 6, 35032, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Leather Gloves
				{ 5, 35034, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Leather Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["SHAMAN"],
			[ALLIANCE_DIFF] = {
				{ 1, 35044, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Linked Helm
				{ 2, 35046, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Linked Spaulders
				{ 3, 35042, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Linked Armor
				{ 4, 35043, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Linked Gauntlets
				{ 5, 35045, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Linked Leggings
				{ 7, 35050, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Mail Helm
				{ 8, 35052, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Mail Spaulders
				{ 9, 35048, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Mail Armor
				{ 10, 35049, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Mail Gauntlets
				{ 11, 35051, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Mail Leggings
				{ 16, 35079, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Ringmail Helm
				{ 17, 35081, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Ringmail Spaulders
				{ 18, 35077, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Ringmail Armor
				{ 19, 35078, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Ringmail Gauntlets
				{ 20, 35080, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Ringmail Leggings
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["WARLOCK"],
			[ALLIANCE_DIFF] = {
				{ 1, 35004, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Dreadweave Hood
				{ 2, 35006, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Dreadweave Mantle
				{ 3, 35007, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Dreadweave Robe
				{ 4, 35003, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Dreadweave Gloves
				{ 5, 35005, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Dreadweave Leggings
				{ 16, 35010, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Felweave Cowl
				{ 17, 35009, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Felweave Amice
				{ 18, 35012, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Felweave Raiment
				{ 19, 35011, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Felweave Handguards
				{ 20, 35013, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Felweave Trousers
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["WARRIOR"],
			[ALLIANCE_DIFF] = {
				{ 1, 35068, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Plate Helm
				{ 2, 35070, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Plate Shoulders
				{ 3, 35066, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Plate Chestpiece
				{ 6, 35067, [PRICE_EXTRA_ITTYPE] = "honor:140"  }, -- Brutal Gladiator's Plate Gauntlets
				{ 5, 35069, [PRICE_EXTRA_ITTYPE] = "honor:175"  }, -- Brutal Gladiator's Plate Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
	},
}
-- Classic Season 3
data["CLASSICS3SETS"] = {
	name = string.format(AL["Season %d"], 3).." "..AL["Class Sets"].." ("..AL["Burning Crusade"]..")",
	ContentType = NORMAL_ITTYPE,
	items = {
		{
			name = LOCALIZED_CLASS_NAMES_MALE["DRUID"],
			[ALLIANCE_DIFF] = {
				--
				{ 1, 33672, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Dragonhide Helm
				{ 2, 33674, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Dragonhide Spaulders
				{ 3, 33675, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Dragonhide Tunic
				{ 4, 33671, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Dragonhide Gloves
				{ 5, 33673, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Dragonhide Legguards
				--
				{ 7, 33691, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Kodohide Helm
				{ 8, 33693, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Kodohide Spaulders
				{ 9, 33694, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Kodohide Tunic
				{ 10, 33690, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Kodohide Gloves
				{ 11, 33692, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Kodohide Legguards
				--
				{ 16, 33768, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Wyrmhide Helm
				{ 17, 33770, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Wyrmhide Spaulders
				{ 18, 33771, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Wyrmhide Tunic
				{ 19, 33767, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Wyrmhide Gloves
				{ 20, 33769, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Wyrmhide Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				--
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["HUNTER"],
			[ALLIANCE_DIFF] = {
				{ 1, 33666, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Chain Helm
				{ 2, 33668, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Chain Spaulders
				{ 3, 33664, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Chain Armor
				{ 4, 33665, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Chain Gauntlets
				{ 5, 33667, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Chain Leggings
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				--
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["MAGE"],
			[ALLIANCE_DIFF] = {
				{ 1, 33758, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Silk Cowl
				{ 2, 33757, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Silk Amice
				{ 3, 33760, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Silk Raiment
				{ 4, 33759, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Silk Handguards
				{ 5, 33761, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Silk Trousers
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				--
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["PALADIN"],
			[ALLIANCE_DIFF] = {
				--
				{ 1, 33697, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Lamellar Helm
				{ 2, 33699, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Lamellar Shoulders
				{ 3, 33695, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Lamellar Chestpiece
				{ 4, 33696, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Lamellar Gauntlets
				{ 5, 33698, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Lamellar Legguards
				--
				{ 7, 33724, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Ornamented Headcover
				{ 8, 33726, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Ornamented Spaulders
				{ 9, 33722, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Ornamented Chestguard
				{ 10, 33723, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Ornamented Gloves
				{ 11, 33725, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Ornamented Legplates
				--
				{ 16, 33751, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Scaled Helm
				{ 17, 33753, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Scaled Shoulders
				{ 18, 33749, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Scaled Chestpiece
				{ 19, 33750, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Scaled Gauntlets
				{ 20, 33752, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Scaled Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				--
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["PRIEST"],
			[ALLIANCE_DIFF] = {
				--
				{ 1, 33718, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Mooncloth Hood
				{ 2, 33720, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Mooncloth Mantle
				{ 3, 33721, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Mooncloth Robe
				{ 4, 33717, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Mooncloth Gloves
				{ 5, 33719, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Mooncloth Leggings
				{ 16, 33745, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Satin Hood
				{ 17, 33747, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Satin Mantle
				{ 18, 33748, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Satin Robe
				{ 19, 33744, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Satin Gloves
				{ 20, 33746, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Satin Leggings
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				--
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["ROGUE"],
			[ALLIANCE_DIFF] = {
				{ 1, 33701, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Leather Helm
				{ 2, 33703, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Leather Spaulders
				{ 3, 33704, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Leather Tunic
				{ 4, 33700, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Leather Gloves
				{ 5, 33702, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Leather Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				--
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["SHAMAN"],
			[ALLIANCE_DIFF] = {
				--
				{ 1, 33708, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Linked Helm
				{ 2, 33710, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Linked Spaulders
				{ 3, 33706, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Linked Armor
				{ 4, 33707, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Linked Gauntlets
				{ 5, 33709, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Linked Leggings
				--
				{ 7, 33713, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Mail Helm
				{ 8, 33715, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Mail Spaulders
				{ 9, 33711, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Vengeful Gladiator's Mail Armor
				{ 10, 33712, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Mail Gauntlets
				{ 11, 33714, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Mail Leggings
				--
				{ 16, 33740, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Ringmail Helm
				{ 17, 33742, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Ringmail Spaulders
				{ 18, 33738, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Ringmail Armor
				{ 19, 33739, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Ringmail Gauntlets
				{ 20, 33741, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Ringmail Leggings
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				--
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["WARLOCK"],
			[ALLIANCE_DIFF] = {
				--
				{ 1, 33677, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Dreadweave Hood
				{ 2, 33679, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Dreadweave Mantle
				{ 3, 33680, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Dreadweave Robe
				{ 4, 33676, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Dreadweave Gloves
				{ 5, 33678, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Dreadweave Leggings
				--
				{ 16, 33683, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Felweave Cowl
				{ 17, 33682, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Felweave Amice
				{ 18, 33685, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Felweave Raiment
				{ 19, 33684, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Felweave Handguards
				{ 20, 33686, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Felweave Trousers
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				--
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["WARRIOR"],
			[ALLIANCE_DIFF] = {
				{ 1, 33730, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Plate Helm
				{ 2, 33732, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Plate Shoulders
				{ 3, 33728, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Plate Chestpiece
				{ 4, 33729, [PRICE_EXTRA_ITTYPE] = "honor:750" },	-- Vengeful Gladiator's Plate Gauntlets
				{ 5, 33731, [PRICE_EXTRA_ITTYPE] = "honor:1000" },	-- Vengeful Gladiator's Plate Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				--
			},
		},
	},
}
data["CLASSICS3WEAPONS"] = {
	name = string.format(AL["Season %d"], 3).." "..AL["Weapons"].." ("..AL["Burning Crusade"]..")",
	ContentType = NORMAL_ITTYPE,
	items = {
		{
			name = string.format(AL["Weapons"]),
			[ALLIANCE_DIFF] = {
				{ 1, 34059, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Vengeful Gladiator's Baton of Light
				{ 2, 34540, [PRICE_EXTRA_ITTYPE] = "honor:1500"  }, -- Vengeful Gladiator's Battle Staff
				{ 3, 33006, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Vengeful Gladiator's Heavy Crossbow
				{ 4, 34066, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Vengeful Gladiator's Piercing Touch
				{ 5, 33755, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Vengeful Gladiator's Shield Wall
				{ 6, 33764, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Vengeful Gladiator's Touch of Defeat
				{ 7, 33766, [PRICE_EXTRA_ITTYPE] = "honor:1500"  }, -- Vengeful Gladiator's War Staff
				{ 8, 33669, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Vengeful Gladiator's Cleaver
				{ 9, 33687, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Vengeful Gladiator's Gavel
				{ 10, 33705, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Vengeful Gladiator's Fleshslicer
				{ 11, 33733, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Vengeful Gladiator's Pummeler
				{ 12, 33737, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Vengeful Gladiator's Ripper
				{ 13, 33743, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Vengeful Gladiator's Salvation
				{ 14, 33754, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Vengeful Gladiator's Shanker
				{ 15, 33762, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Vengeful Gladiator's Slicer
				{ 16, 33763, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Vengeful Gladiator's Spellblade
				{ 17, 34016, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Vengeful Gladiator's Slasher
				{ 18, 33661, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Vengeful Gladiator's Barrier
				{ 19, 33735, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Vengeful Gladiator's Redoubt
				{ 20, 34529, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Vengeful Gladiator's Longbow
				{ 21, 34530, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Vengeful Gladiator's Rifle
				{ 22, 33663, [PRICE_EXTRA_ITTYPE] = "honor:1500"  }, -- Vengeful Gladiator's Bonegrinder
				{ 23, 33670, [PRICE_EXTRA_ITTYPE] = "honor:1500"  }, -- Vengeful Gladiator's Decapitator
				{ 24, 33688, [PRICE_EXTRA_ITTYPE] = "honor:1500"  }, -- Vengeful Gladiator's Greatsword
				{ 25, 33716, [PRICE_EXTRA_ITTYPE] = "honor:1500"  }, -- Vengeful Gladiator's Staff
				{ 26, 33727, [PRICE_EXTRA_ITTYPE] = "honor:1500"  }, -- Vengeful Gladiator's Painsaw
				{ 27, 34014, [PRICE_EXTRA_ITTYPE] = "honor:1500"  }, -- Vengeful Gladiator's Waraxe
				{ 28, 33662, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Vengeful Gladiator's Bonecracker
				{ 29, 33689, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Vengeful Gladiator's Hacker
				{ 30, 33734, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Vengeful Gladiator's Quickblade
				{ 101, 33756, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Vengeful Gladiator's Shiv
				{ 102, 33801, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Vengeful Gladiator's Mutilator
				{ 103, 34015, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Vengeful Gladiator's Chopper
				{ 104, 33681, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Vengeful Gladiator's Endgame
				{ 105, 33736, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Vengeful Gladiator's Reprieve
				{ 106, 34033, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Vengeful Gladiator's Grimoire
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				--
			},
		},
	},
}
-- Classic Season 2
data["CLASSICS2SETS"] = {
	name = string.format(AL["Season %d"], 2).." "..AL["Class Sets"].." ("..AL["Burning Crusade"]..")",
	ContentType = NORMAL_ITTYPE,
	items = {
		{
			name = LOCALIZED_CLASS_NAMES_MALE["DRUID"],
			[ALLIANCE_DIFF] = {
				-- Feral / Guardian
				{ 1, 31968, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Dragonhide Helm
				{ 2, 31971, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Dragonhide Spaulders
				{ 3, 31972, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Dragonhide Tunic
				{ 4, 31967, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Dragonhide Gloves
				{ 5, 31969, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Dragonhide Legguards
				-- Restoration
				{ 7, 31988, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Kodohide Helm
				{ 8, 31990, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Kodohide Spaulders
				{ 9, 31991, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Kodohide Tunic
				{ 10, 31987, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Kodohide Gloves
				{ 11, 31989, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Kodohide Legguards
				-- Balance
				{ 16, 32057, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Wyrmhide Helm
				{ 17, 32059, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Wyrmhide Spaulders
				{ 18, 32060, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Wyrmhide Tunic
				{ 19, 32056, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Wyrmhide Gloves
				{ 20, 32058, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Wyrmhide Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				--
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["HUNTER"],
			[ALLIANCE_DIFF] = {
				{ 1, 31962, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Chain Helm
   				{ 2, 31964, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Chain Spaulders
				{ 3, 31960, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Chain Armor
				{ 4, 31961, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Chain Gauntlets
				{ 5, 31963, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Chain Leggings
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				--
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["MAGE"],
			[ALLIANCE_DIFF] = {
				{ 1, 32048, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Silk Cowl
   				{ 2, 32047, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Silk Amice
   				{ 3, 32050, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Silk Raiment
   				{ 4, 32049, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Silk Handguards
   				{ 5, 32051, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Silk Trousers
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				--
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["PALADIN"],
			[ALLIANCE_DIFF] = {
				--
				{ 1, 31997, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Lamellar Helm
				{ 2, 31996, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Lamellar Shoulders
				{ 3, 31992, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Lamellar Chestpiece
				{ 4, 31993, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Lamellar Gauntlets
				{ 5, 31995, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Lamellar Legguards
				--
				{ 7, 32022, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Ornamented Headcover
				{ 8, 32024, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Ornamented Spaulders
				{ 9, 32020, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Ornamented Chestguard
				{ 10, 32021, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Ornamented Gloves
				{ 11, 32023, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Ornamented Legplates
				--
				{ 16, 32041, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Scaled Helm
				{ 17, 32043, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Scaled Shoulders
				{ 18, 32039, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Scaled Chestpiece
				{ 19, 32040, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Scaled Gauntlets
				{ 20, 32042, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Scaled Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				--
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["PRIEST"],
			[ALLIANCE_DIFF] = {
				--
				{ 1, 32016, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Mooncloth Hood
				{ 2, 32018, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Mooncloth Mantle
				{ 3, 32019, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Mooncloth Robe
				{ 4, 32015, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Mooncloth Gloves
				{ 5, 32017, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Mooncloth Leggings
				--
				{ 16, 32035, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Satin Hood
				{ 17, 32037, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Satin Mantle
				{ 18, 32038, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Satin Robe
				{ 19, 32034, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Satin Gloves
				{ 20, 32036, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Satin Leggings
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				--
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["ROGUE"],
			[ALLIANCE_DIFF] = {
				{ 1, 31999, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Leather Helm
				{ 2, 32001, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Leather Spaulders
				{ 3, 32002, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Leather Tunic
				{ 4, 31998, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Leather Gloves
				{ 5, 32000, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Leather Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				--
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["SHAMAN"],
			[ALLIANCE_DIFF] = {
				--
				{ 1, 32006, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Linked Helm
				{ 2, 32008, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Linked Spaulders
				{ 3, 32004, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Linked Armor
				{ 4, 32005, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Linked Gauntlets
				{ 5, 32007, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Linked Leggings
				--
				{ 7, 32011, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Mail Helm
				{ 8, 32013, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Mail Spaulders
				{ 9, 32009, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Mail Armor
				{ 10, 32010, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Mail Gauntlets
				{ 11, 32012, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Mail Leggings
				--
				{ 16, 32031, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Ringmail Helm
				{ 17, 32033, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Ringmail Spaulders
				{ 18, 32029, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Ringmail Armor
				{ 19, 32030, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Ringmail Gauntlets
				{ 20, 32032, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Ringmail Leggings
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				--
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["WARLOCK"],
			[ALLIANCE_DIFF] = {
				--
				{ 1, 31974, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Dreadweave Hood
				{ 2, 31976, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Dreadweave Mantle
				{ 3, 31977, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Dreadweave Robe
				{ 4, 31973, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Dreadweave Gloves
				{ 5, 31975, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Dreadweave Leggings
				--
				{ 16, 31980, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Felweave Cowl
				{ 17, 31979, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Felweave Amice
				{ 18, 31982, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Felweave Raiment
				{ 19, 31981, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Felweave Handguards
				{ 20, 31983, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Felweave Trousers
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				--
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["WARRIOR"],
			[ALLIANCE_DIFF] = {
				{ 1, 30488, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Plate Helm
				{ 2, 30490, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Plate Shoulders
				{ 3, 30486, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Plate Chestpiece
				{ 4, 30487, [PRICE_EXTRA_ITTYPE] = "honor:750"  },	-- Merciless Gladiator's Plate Gauntlets
				{ 5, 30489, [PRICE_EXTRA_ITTYPE] = "honor:1000"  },	-- Merciless Gladiator's Plate Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				--
			},
		},
	},
}
data["CLASSICS2WEAPONS"] = {
	name = string.format(AL["Season %d"], 2).." "..AL["Weapons"].." ("..AL["Burning Crusade"]..")",
	ContentType = NORMAL_ITTYPE,
	items = {
		{
			name = string.format(AL["Weapons"]),
			[ALLIANCE_DIFF] = {
				{ 1, 31965, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Merciless Gladiator's Cleaver
				{ 2, 31986, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Merciless Gladiator's Crossbow of the Phoenix
				{ 3, 32045, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Merciless Gladiator's Shield Wall
				{ 4, 32962, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Merciless Gladiator's Touch of Defeat
				{ 5, 32055, [PRICE_EXTRA_ITTYPE] = "honor:1500"  }, -- Merciless Gladiator's War Staff
				{ 6, 32003, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Merciless Gladiator's Fleshslicer
				{ 7, 32026, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Merciless Gladiator's Pummeler
				{ 8, 32028, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Merciless Gladiator's Ripper
				{ 9, 32044, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Merciless Gladiator's Shanker
				{ 10, 32052, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Merciless Gladiator's Slicer
				{ 11, 32053, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Merciless Gladiator's Spellblade
				{ 12, 32963, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Merciless Gladiator's Gavel
				{ 13, 32964, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Merciless Gladiator's Salvation
				{ 14, 33313, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Merciless Gladiator's Barrier
				{ 15, 31959, [PRICE_EXTRA_ITTYPE] = "honor:1500"  }, -- Merciless Gladiator's Bonegrinder
				{ 16, 31966, [PRICE_EXTRA_ITTYPE] = "honor:1500"  }, -- Merciless Gladiator's Decapitator
				{ 17, 31984, [PRICE_EXTRA_ITTYPE] = "honor:1500"  }, -- Merciless Gladiator's Greatsword
				{ 18, 32014, [PRICE_EXTRA_ITTYPE] = "honor:1500"  }, -- Merciless Gladiator's Maul
				{ 19, 32025, [PRICE_EXTRA_ITTYPE] = "honor:1500"  }, -- Merciless Gladiator's Painsaw
				{ 20, 31958, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Merciless Gladiator's Bonecracker
				{ 21, 31985, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Merciless Gladiator's Hacker
				{ 22, 32027, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Merciless Gladiator's Quickblade
				{ 23, 32046, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Merciless Gladiator's Shiv
				{ 24, 31978, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Merciless Gladiator's Endgame
				{ 25, 32961, [PRICE_EXTRA_ITTYPE] = "honor:750"  }, -- Merciless Gladiator's Reprieve
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
	},
}
-- Classic Season 1
data["CLASSICS1SETS"] = {
	name = string.format(AL["Season %d"], 1).." "..AL["Class Sets"].." ("..AL["Burning Crusade"]..")",
	ContentType = NORMAL_ITTYPE,
	items = {
		{
			name = LOCALIZED_CLASS_NAMES_MALE["DRUID"],
			[ALLIANCE_DIFF] = {
				-- Guardian
				{ 1, 28127 },	-- Gladiator's Dragonhide Helm
				{ 2, 28129 },	-- Gladiator's Dragonhide Spaulders
				{ 3, 28130 },	-- Gladiator's Dragonhide Tunic
				{ 4, 28126 },	-- Gladiator's Dragonhide Gloves
				{ 5, 28128 },	-- Gladiator's Dragonhide Legguards
				-- Restoration
				{ 7, 31376 },	-- Gladiator's Kodohide Helm
				{ 8, 31378 },	-- Gladiator's Kodohide Spaulders
				{ 9, 31379 },	-- Gladiator's Kodohide Tunic
				{ 10, 31375 },	-- Gladiator's Kodohide Gloves
				{ 11, 31377 },	-- Gladiator's Kodohide Legguards
				-- Feral
				{ 16, 28137 },	-- Gladiator's Wyrmhide Helm
				{ 17, 28139 },	-- Gladiator's Wyrmhide Spaulders
				{ 18, 28140 },	-- Gladiator's Wyrmhide Tunic
				{ 19, 28136 },	-- Gladiator's Wyrmhide Gloves
				{ 20, 28138 }, 	-- Gladiator's Wyrmhide Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["HUNTER"],
			[ALLIANCE_DIFF] = {
				{ 1, 28331 },	-- Gladiator's Chain Helm
				{ 2, 28333 },	-- Gladiator's Chain Spaulders
				{ 3, 28334 }, 	-- Gladiator's Chain Armor
				{ 4, 28335 },	-- Gladiator's Chain Gauntlets
				{ 5, 28332 },	-- Gladiator's Chain Leggings
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["MAGE"],
			[ALLIANCE_DIFF] = {
				{ 1, 25855 },	-- Gladiator's Silk Cowl
				{ 2, 25854 },	-- Gladiator's Silk Amice
				{ 3, 25856 },	-- Gladiator's Silk Raiment
				{ 4, 25857 },	-- Gladiator's Silk Handguards
				{ 5, 25858 },	-- Gladiator's Silk Trousers
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["SHAMAN"].." / "..LOCALIZED_CLASS_NAMES_MALE["PALADIN"],
			[ALLIANCE_DIFF] = {
				-- Retribution
				{ 1, 27704 },	-- Gladiator's Lamellar Helm
				{ 2, 27706 },	-- Gladiator's Lamellar Shoulders
				{ 3, 27702 },	-- Gladiator's Lamellar Chestpiece
				{ 4, 27703 },	-- Gladiator's Lamellar Gauntlets
				{ 5, 27705 },	-- Gladiator's Lamellar Legguards
				-- 
				{ 7, 27881 },	-- Gladiator's Scaled Helm
				{ 8, 27883 },	-- Gladiator's Scaled Shoulders
				{ 9, 27879 },	-- Gladiator's Scaled Chestpiece
				{ 10, 27880 },	-- Gladiator's Scaled Gauntlets
				{ 11, 27882 },	-- Gladiator's Scaled Legguards
				-- Holy
				{ 16, 31616 },	-- Gladiator's Ornamented Headcover
				{ 17, 31619 },	-- Gladiator's Ornamented Spaulders				
				{ 18, 31613 },	-- Gladiator's Ornamented Chestguard
				{ 19, 31614 },	-- Gladiator's Ornamented Gloves
				{ 20, 31618 },	-- Gladiator's Ornamented Legplates
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
				-- Enhancement
				{ 1, 25998 },  -- Gladiator's Linked Helm
				{ 2, 25999 },  -- Gladiator's Linked Spaulders
				{ 3, 25997 },  -- Gladiator's Linked Armor
				{ 4, 26000 },  -- Gladiator's Linked Gauntlets
				{ 5, 26001 },  -- Gladiator's Linked Leggings
				-- Elemental
				{ 7, 27471 },  -- Gladiator's Mail Helm
				{ 8, 27473 },  -- Gladiator's Mail Spaulders
				{ 9, 27469 },  -- Gladiator's Mail Armor
				{ 10, 27470 },  -- Gladiator's Mail Gauntlets
				{ 11, 27472 },  -- Gladiator's Mail Leggings
				-- Restoration
				{ 16, 31400 },  -- Gladiator's Ringmail Helm
				{ 17, 31407 },  -- Gladiator's Ringmail Spaulders
				{ 18, 31396 },  -- Gladiator's Ringmail Armor
				{ 19, 31397 },  -- Gladiator's Ringmail Gauntlets
				{ 20, 31406 },  -- Gladiator's Ringmail Leggings

			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["PRIEST"],
			[ALLIANCE_DIFF] = {
				-- Holy
				{ 1, 31410 },	-- Gladiator's Mooncloth Hood
				{ 2, 31412 },	-- Gladiator's Mooncloth Mantle
				{ 3, 31413 },	-- Gladiator's Mooncloth Robe
				{ 4, 31409 },	-- Gladiator's Mooncloth Gloves
				{ 5, 31411 },	-- Gladiator's Mooncloth Leggings
				-- Shadow
				{ 16, 27708 },	-- Gladiator's Satin Hood
				{ 17, 27710 },	-- Gladiator's Satin Mantle
				{ 18, 27711 },	-- Gladiator's Satin Robe
				{ 19, 27707 },	-- Gladiator's Satin Gloves
				{ 20, 27709 },	-- Gladiator's Satin Leggings
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["ROGUE"],
			[ALLIANCE_DIFF] = {
				{ 1, 25830 },	-- Gladiator's Leather Helm
				{ 2, 25832 },	-- Gladiator's Leather Spaulders
				{ 3, 25831 },	-- Gladiator's Leather Tunic
				{ 4, 25834 },	-- Gladiator's Leather Gloves
				{ 5, 25833 },	-- Gladiator's Leather Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["WARLOCK"],
			[ALLIANCE_DIFF] = {
				{ 1, 24553 },	-- Gladiator's Dreadweave Hood
				{ 2, 24554 },	-- Gladiator's Dreadweave Mantle
				{ 3, 24552 },	-- Gladiator's Dreadweave Robe
				{ 4, 24556 },	-- Gladiator's Dreadweave Gloves
				{ 5, 24555 },	-- Gladiator's Dreadweave Leggings
				{ 16, 30187 },	-- Gladiator's Felweave Cowl
				{ 17, 30186 },	-- Gladiator's Felweave Amice
				{ 18, 30200 },	-- Gladiator's Felweave Raiment
				{ 19, 30188 },	-- Gladiator's Felweave Handguards
				{ 20, 30201 },	-- Gladiator's Felweave Trousers

			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
		{
			name = LOCALIZED_CLASS_NAMES_MALE["WARRIOR"],
			[ALLIANCE_DIFF] = {
				{ 1, 24545 },	-- Gladiator's Plate Helm
				{ 2, 24546 },	-- Gladiator's Plate Shoulders
				{ 3, 24544 },	-- Gladiator's Plate Chestpiece
				{ 4, 24549 },	-- Gladiator's Plate Gauntlets
				{ 5, 24547 },	-- Gladiator's Plate Legguards
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
	},
}
data["CLASSICS1WEAPONS"] = {
	name = string.format(AL["Season %d"], 1).." "..AL["Weapons"].." ("..AL["Burning Crusade"]..")",
	ContentType = NORMAL_ITTYPE,
	items = {
		{
			name = string.format(AL["Weapons"]),
			[ALLIANCE_DIFF] = {
				{ 1, 28294 }, -- Gladiator's Heavy Crossbow
				{ 3, 28320 }, -- Gladiator's Touch of Defeat
				{ 5, 28314 }, -- Gladiator's Fleshslicer				
				{ 6, 28313 }, -- Gladiator's Ripper
				{ 7, 32450 }, -- Gladiator's Gavel
				{ 8, 28305 }, -- Gladiator's Pummeler
				{ 9, 32451 }, -- Gladiator's Salvation
				{ 10, 28312 }, -- Gladiator's Shanker
				{ 11, 28297 }, -- Gladiator's Spellblade
				{ 12, 28295 }, -- Gladiator's Slicer
				{ 13, 28308 }, -- Gladiator's Cleaver
				{ 16, 24557 }, -- Gladiator's War Staff
				{ 17, 28299 }, -- Gladiator's Bonegrinder
				{ 18, 28298 }, -- Gladiator's Decapitator
				{ 19, 24550 }, -- Gladiator's Greatsword
				{ 20, 28476 }, -- Gladiator's Maul
				{ 21, 28300 }, -- Gladiator's Painsaw
				{ 23, 28302 }, -- Gladiator's Bonecracker
				{ 24, 28309 }, -- Gladiator's Hacker
				{ 25, 28307 }, -- Gladiator's Quickblade
				{ 26, 28310 }, -- Gladiator's Shiv
				{ 28, 28358 }, -- Gladiator's Shield Wall
				{ 29, 28346 }, -- Gladiator's Endgame
				{ 30, 32452 }, -- Gladiator's Reprieve
			},
			[HORDE_DIFF] = {
				GetItemsFromDiff = ALLIANCE_DIFF,
			},
		},
	},
}