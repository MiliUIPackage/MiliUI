local BtWQuests = BtWQuests
local L = BtWQuests.L
local Database = BtWQuests.Database
BtWQuests.Constant.Expansions.Midnight = LE_EXPANSION_MIDNIGHT or 11
BtWQuests.Constant.Category.Midnight = BtWQuests.Constant.Category.Midnight or {}
BtWQuests.Constant.Chain.Midnight = BtWQuests.Constant.Chain.Midnight or {}
local Category = BtWQuests.Constant.Category.Midnight
local Chain = BtWQuests.Constant.Chain.Midnight

Database:AddExpansion(BtWQuests.Constant.Expansions.Midnight, {
    image = {
        texture = "Interface\\AddOns\\BtWQuestsMidnightPrologue\\UI-Expansion",
        texCoords = {0, 0.90625, 0, 0.8125}
    }
})
