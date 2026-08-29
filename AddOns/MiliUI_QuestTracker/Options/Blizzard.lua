------------------------------------------------------------
-- 暴雪「選項 > 插件」入口頁：名稱＋版本＋開啟設定按鈕
-- 版面在共用層 Libs/MiliUIWidgets/BlizzOptions.lua，這裡只填字串。
--
-- ⚠ 版本那行與按鈕文字**一定要在這裡傳**：共用層不查語系表（語系契約只有四個
--   key），沒傳就是英文字面值。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

ns.BlizzCategory = ns.RegisterBlizzardCategory{
    title        = L["MiliUI Quest Tracker"],
    instructions = L["Use /mquest to open options"],
    versionText  = L["Version: %s"]:format(ns.VERSION),
    buttonText   = L["Open options"],
}
