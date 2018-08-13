local AtlasLoot = _G.AtlasLoot
local ItemString = {}
AtlasLoot.ItemString = ItemString

local BonusIDInfo = AtlasLoot.BonusIDInfo

-- lua
local format = string.format
local tbl_concat = table.concat

local ITEM_FORMAT_STRING = "item:%d:0:0:0:0:0:0:0:0:0:0:0:0"
local ITEM_FORMAT_ALL_STRING = "item:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%s"
local ITEM_FORMAT_BONUS_STRING = "item:%d:::::::::::%s:%d:%s"

ATLASLOOT_ITEM_BONUSIDS = {
	-- Raid
	["LFR"] = 451,
	["SoOWarforged"] = 448,
	["HeroicRaid"] = 566,
	["MythicRaid"] = 567,
	["LegionLFR"] = 3379,
	["LegionHeroicRaid"] = 1805,
	["LegionMythicRaid"] = 1806,
}

local ITEM_LVL_BONUS = {
	[0] =	1472,
	[1] =	1473,
	[2] =	1474,
	[3] =	1475,
	[4] =	1476,
	[5] =	1477,
	[6] =	1478,
	[7] =	1479,
	[8] =	1480,
	[9] =	1481,
	[10] =	1482,
	[11] =	1483,
	[12] =	1484,
	[13] =	1485,
	[14] =	1486,
	[15] =	1487,
	[16] =	1488,
	[17] =	1489,
	[18] =	1490,
	[19] =	1491,
	[20] =	1492,
	[21] =	1493,
	[22] =	1494,
	[23] =	1495,
	[24] =	1496,
	[25] =	1497,
	[26] =	1498,
	[27] =	1499,
	[28] =	1500,
	[29] =	1501,
	[30] =	1502,
	[31] =	1503,
	[32] =	1504,
	[33] =	1505,
	[34] =	1506,
	[35] =	1507,
	[36] =	1508,
	[37] =	1509,
	[38] =	1510,
	[39] =	1511,
	[40] =	1512,
	[41] =	1513,
	[42] =	1514,
	[43] =	1515,
	[44] =	1516,
	[45] =	1517,
	[46] =	1518,
	[47] =	1519,
	[48] =	1520,
	[49] =	1521,
	[50] =	1522,
	[51] =	1523,
	[52] =	1524,
	[53] =	1525,
	[54] =	1526,
	[55] =	1527,
	[56] =	1528,
	[57] =	1529,
	[58] =	1530,
	[59] =	1531,
	[60] =	1532,
	[61] =	1533,
	[62] =	1534,
	[63] =	1535,
	[64] =	1536,
	[65] =	1537,
	[66] =	1538,
	[67] =	1539,
	[68] =	1540,
	[69] =	1541,
	[70] =	1542,
	[71] =	1543,
	[72] =	1544,
	[73] =	1545,
	[74] =	1546,
	[75] =	1547,
	[76] =	1548,
	[77] =	1549,
	[78] =	1550,
	[79] =	1551,
	[80] =	1552,
	[81] =	1553,
	[82] =	1554,
	[83] =	1555,
	[84] =	1556,
	[85] =	1557,
	[86] =	1558,
	[87] =	1559,
	[88] =	1560,
	[89] =	1561,
	[90] =	1562,
	[91] =	1563,
	[92] =	1564,
	[93] =	1565,
	[94] =	1566,
	[95] =	1567,
	[96] =	1568,
	[97] =	1569,
	[98] =	1570,
	[99] =	1571,
	[100] =	1572,
	[101] =	1573,
	[102] =	1574,
	[103] =	1575,
	[104] =	1576,
	[105] =	1577,
	[106] =	1578,
	[107] =	1579,
	[108] =	1580,
	[109] =	1581,
	[110] =	1582,
	[111] =	1583,
	[112] =	1584,
	[113] =	1585,
	[114] =	1586,
	[115] =	1587,
	[116] =	1588,
	[117] =	1589,
	[118] =	1590,
	[119] =	1591,
	[120] =	1592,
	[121] =	1593,
	[122] =	1594,
	[123] =	1595,
	[124] =	1596,
	[125] =	1597,
	[126] =	1598,
	[127] =	1599,
	[128] =	1600,
	[129] =	1601,
	[130] =	1602,
	[131] =	1603,
	[132] =	1604,
	[133] =	1605,
	[134] =	1606,
	[135] =	1607,
	[136] =	1608,
	[137] =	1609,
	[138] =	1610,
	[139] =	1611,
	[140] =	1612,
	[141] =	1613,
	[142] =	1614,
	[143] =	1615,
	[144] =	1616,
	[145] =	1617,
	[146] =	1618,
	[147] =	1619,
	[148] =	1620,
	[149] =	1621,
	[150] =	1622,
	[151] =	1623,
	[152] =	1624,
	[153] =	1625,
	[154] =	1626,
	[155] =	1627,
	[156] =	1628,
	[157] =	1629,
	[158] =	1630,
	[159] =	1631,
	[160] =	1632,
	[161] =	1633,
	[162] =	1634,
	[163] =	1635,
	[164] =	1636,
	[165] =	1637,
	[166] =	1638,
	[167] =	1639,
	[168] =	1640,
	[169] =	1641,
	[170] =	1642,
	[171] =	1643,
	[172] =	1644,
	[173] =	1645,
	[174] =	1646,
	[175] =	1647,
	[176] =	1648,
	[177] =	1649,
	[178] =	1650,
	[179] =	1651,
	[180] =	1652,
	[181] =	1653,
	[182] =	1654,
	[183] =	1655,
	[184] =	1656,
	[185] =	1657,
	[186] =	1658,
	[187] =	1659,
	[188] =	1660,
	[189] =	1661,
	[190] =	1662,
	[191] =	1663,
	[192] =	1664,
	[193] =	1665,
	[194] =	1666,
	[195] =	1667,
	[196] =	1668,
	[197] =	1669,
	[198] =	1670,
	[199] =	1671,
	[200] =	1672,
}

local TITANFORGED_ADD = { 3442 }
local LEGION_MAX_UPGRADELVL = 925
local function GetPresetForTitanforged(baseLvl, maxLvl, extraBonus)
	baseLvl = baseLvl or maxLvl
	baseLvl = maxLvl - baseLvl
	local tab = {
		ITEM_LVL_BONUS[baseLvl] or nil
	}
	if extraBonus then
		for i = 1, #extraBonus do
			tab[#tab+1] = extraBonus[i]
		end
	end
	return tab
end

local C_ITEM_BONUS_PRESET = {
	["nil"] = {}
}
local ITEM_BONUS_PRESET = {
	-- Dungeons
	["BSM"]					= { 518 },
	["ID"]					= { 519 },
	["Auch"]				= { 520 },
	["Skyreach"]				= { 521 },
	["Dungeon"]				= { 522 },
	["HCDungeon"]				= { 524 },
	["HCDungeonWarforged"]			= { 524, 448 },
	["MDungeon"]				= { 642 },
	["MDungeonWarforged"]			= { 642, 644 },
	-- ## Legion
	["LegionDungeon"]			= { 1826 },
	["LegionDungeonTitanforged"] 		= GetPresetForTitanforged(820, LEGION_MAX_UPGRADELVL, TITANFORGED_ADD),--{ 1826, 1522 },
	["LegionHCDungeon"]			= { 1726 },
	["LegionHCDungeonTitanforged"]		= GetPresetForTitanforged(820, LEGION_MAX_UPGRADELVL, TITANFORGED_ADD),--{ 1726, 1522 },
	["LegionMDungeon"] 			= { 1727 },
	["LegionMDungeonTitanforged"]		= GetPresetForTitanforged(820, LEGION_MAX_UPGRADELVL, TITANFORGED_ADD),--{ 1727, 1522 },
	["LegionMDungeon2"]			= { 3452 },
	["LegionMDungeon2Titanforged"]		= GetPresetForTitanforged(820, LEGION_MAX_UPGRADELVL, TITANFORGED_ADD),--{ 3452, 1522 },
	-- Raids
	["LFR"]					= { 451 },
	["SoOWarforged"]			= { 448 },
	["HeroicSoO"] 				= { 449 },
	["HeroicSoOWarforged"]			= { 449, 448 },
	["MythicSoO"] 				= { 450 },
	["MythicSoOWarforged"]			= { 450, 448 },
	["RaidWarforged"]			= { 560 },
	["HeroicRaid"] 				= { 566 },
	["HeroicRaidWarforged"]			= { 566, 561 },
	["MythicRaid"] 				= { 567 },
	["MythicRaidWarforged"]			= { 567, 562 },
	["LegionLFR"] 				= { 3379 },
	["LegionLFRTitanforged"] 		= { 1522, 3442 },
	["LegionRaid"]				= { 1807 },
	["LegionRaidTitanforged"]		= { 1522, 3442 },
	["LegionHeroicRaid"] 			= { 1805 },
	["LegionHeroicRaidTitanforged"] 	= { 1522, 3442 },
	["LegionMythicRaid"] 			= { 1806 },
	["LegionMythicRaidTitanforged"] 	= { 1522, 3442 },
	
	["LegionEmeraldNightmareTitanforged"] 	= { 1547, 3442 },
	["LegionNightholdTitanforged"] 		= { 1522, 3442 },
	
	["LegionMaxTitanforgedByBaseLvl"] = function(baseLvl)		-- set the baseLvl with "ItemBaseLvl = 000," in the Instance Table.
		if not baseLvl then return C_ITEM_BONUS_PRESET["nil"] end
		if not C_ITEM_BONUS_PRESET["LegionMaxTitanforgedByBaseLvl"..baseLvl] then
			C_ITEM_BONUS_PRESET["LegionMaxTitanforgedByBaseLvl"..baseLvl] = GetPresetForTitanforged(baseLvl, LEGION_MAX_UPGRADELVL, TITANFORGED_ADD) -- 3442 adds "Titanforged"
		end
		return C_ITEM_BONUS_PRESET["LegionMaxTitanforgedByBaseLvl"..baseLvl]
	end,
	
	-- Crafting
	["Stage1"]			= { 525 },
	["Stage2"]			= { 526 },
	["Stage3"]			= { 527 },
	["Stage4"]			= { 593 },
	["Stage5"]			= { 617 },
	["Stage6"]			= { 618 },
	["Stage2W"]			= { 558 },
	["Stage3W"]			= { 559 },
	["Stage4W"]			= { 594 },
	["Stage5W"]			= { 619 },
	["Stage6W"]			= { 620 },
	-- Heirloom
	["Stage2H"]			= { 582 },
	["Stage3H"]			= { 583 }
}

function ItemString.Create(itemID, extra)
	if extra then
		return format( ITEM_FORMAT_EXTRA_STRING,
			itemID,					-- itemID
			extra.enchant or 0,			-- extra.enchant
			extra.gem1 or 0,			-- extra.gem1
			extra.gem2 or 0,			-- extra.gem2
			extra.gem3 or 0,			-- extra.gem3
			extra.gem4 or 0,			-- extra.gem4
			extra.suffixID or 0,			-- extra.suffixID
			extra.uniqueID or 0,			-- extra.uniqueID
			extra.level or 0,			-- extra.level
			extra.upgradeId or 0,			-- extra.upgradeId
			extra.instanceDifficultyID or 0,	-- extra.instanceDifficultyID
			extra.bonus and #extra.bonus or 0,
			extra.bonus and tbl_concat(extra.bonus, ":") or ""
		)
	else
		return format( ITEM_FORMAT_STRING,
			itemID					-- itemID
		)
	end
end

function ItemString.AddBonus(itemID, bonus, difficultyID, baseLvl)
	bonus = bonus and (ITEM_BONUS_PRESET[bonus] or ITEM_BONUS_PRESET[bonus[1]]) or bonus
	if bonus and type(bonus) == "string" then print(bonus) elseif bonus and type(bonus) == "function" then bonus = bonus(baseLvl) end
	local difficulty
	if difficultyID then
		difficultyID, difficulty = BonusIDInfo.GetItemBonusIDByDiff(difficultyID)
		if bonus then
			--for i = 1,#bonus do
			--	difficultyID[#difficultyID+1] = bonus[i]
			--end
			difficultyID = bonus
		end
		bonus = difficultyID
	end
	return format( ITEM_FORMAT_BONUS_STRING,
			itemID,
			difficulty or 0,
			bonus and #bonus or 0,
			bonus and tbl_concat(bonus, ":") or ""
		) 
end

-- difficultyID = http://wow.gamepedia.com/DifficultyID
function ItemString.AddBonusByDifficultyID(itemID, difficultyID)
	if not itemID then return elseif not difficultyID then return ItemString.Create(itemID) end
	
	return format( ITEM_FORMAT_BONUS_STRING,
			itemID,
			1,
			BonusIDInfo.GetItemBonusIDByDiff(itemID, difficultyID) or 0
		) 
end

--[[
function AltasLoot_PrintItemString(index)
	local name, icon, slot, armorType, itemID, link, encounterID = EJ_GetLootInfoByIndex(index)
	local itemstring = gsub(link, "\124", "\124\124")
	print(itemstring) --/run AltasLoot_PrintItemString(1)
end
]]
-- /run print(AtlasLoot.ItemString.AddBonusByDifficultyID(140914, 16))
-- /run print(GetItemInfo(AtlasLoot.ItemString.AddBonusByDifficultyID(140914, 16)))
