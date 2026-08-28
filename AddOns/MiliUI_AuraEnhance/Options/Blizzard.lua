------------------------------------------------------------
-- 暴雪「選項 > 插件」入口頁：名稱＋版本＋開啟設定按鈕
-- 版面在共用層 Libs/MiliUIWidgets/BlizzOptions.lua，這裡只填字串。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

ns.BlizzCategory = ns.RegisterBlizzardCategory{
    title        = L["MiliUI Aura Enhance"],
    instructions = L["Use /maura to open options"],
}
