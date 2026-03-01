local BtWQuests = BtWQuests
local L = BtWQuests.L
local Database = BtWQuests.Database
BtWQuests.Constant.Expansions.Midnight = LE_EXPANSION_MIDNIGHT or 11
BtWQuests.Constant.Category.Midnight = BtWQuests.Constant.Category.Midnight or {}
BtWQuests.Constant.Chain.Midnight = BtWQuests.Constant.Chain.Midnight or {}
local Category = BtWQuests.Constant.Category.Midnight
local Chain = BtWQuests.Constant.Chain.Midnight

BtWQuests.Constant.Category.Midnight = {
    EversongWoods = 1201,
    Zulaman = 1202,
    Harandar = 1203,
    Voidstorm = 1204,
    Arator = 1205,
}
BtWQuests.Constant.Chain.Midnight = {
    EversongWoods = {},
    Zulaman = {},
    Harandar = {},
    Voidstorm = {},
    Arator = {},
}

Database:AddExpansion(BtWQuests.Constant.Expansions.Midnight, {
    image = {
        texture = "Interface\\AddOns\\BtWQuestsMidnight\\UI-Expansion",
        texCoords = {0, 0.90625, 0, 0.8125}
    }
})

BtWQuests.Constant.Restrictions.MidnightToF = -120001;
BtWQuests.Constant.Restrictions.NotMidnightToF = -120002;
Database:AddCondition(BtWQuests.Constant.Restrictions.MidnightToF, { type = "quest", id = 90806 }) -- "Threads of Fate"
Database:AddCondition(BtWQuests.Constant.Restrictions.NotMidnightToF, { type = "quest", id = 90806, status = { "pending" } }) -- "Threads of Fate"
