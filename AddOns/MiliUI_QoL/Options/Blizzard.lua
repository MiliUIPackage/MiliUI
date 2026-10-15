------------------------------------------------------------
-- 暴雪「選項 > 插件」入口頁：名稱＋版本＋開啟設定按鈕
-- 版面在共用層 Libs/MiliUIWidgets/BlizzOptions.lua，這裡只填字串。
-- ⚠ 版本那行與按鈕文字一定要在這裡傳：共用層不查語系表（語系契約只有四個 key）。
------------------------------------------------------------
local _, ns = ...

ns.BlizzCategory = ns.RegisterBlizzardCategory{
    title        = ns.TITLE,
    instructions = "輸入 /mqol 開啟設定",
    versionText  = "版本：" .. ns.VERSION,
    buttonText   = "開啟設定",
    onClick      = function() ns.Host.Open() end,
}
