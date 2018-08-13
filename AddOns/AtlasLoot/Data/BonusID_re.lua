local AtlasLoot = _G.AtlasLoot
local BonusIDInfoFunc = {}
AtlasLoot.BonusIDInfo = BonusIDInfoFunc

local type = type
local type_table = "table"

local BonusID_Diff = {
	[1] = 1,
	[2] = 2,
	[3] = 0,
	[4] = 0,
	[5] = 0,
	[6] = 0,
	[7] = 0,
	[8] = 0,
	[9] = 0,
	[11] = 10,
	[12] = 9,
	[14] = 3,
	[15] = 5,
	[16] = 6,
	[17] = 4,
	[18] = 0,
	[19] = 0,
	[20] = 0,
	[23] = 23,
	[24] = 22,
	[25] = 0,
	[29] = 0,
}
local BonusID_BY_DIFF = 3524



function BonusIDInfoFunc.GetItemBonusIDByDiff(diffID)
	return {BonusID_BY_DIFF}, BonusID_Diff[diffID]
end
