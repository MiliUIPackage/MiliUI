------------------------------------------------------------
-- 暴雪「選項 > 插件」入口頁：名稱＋版本＋開啟設定按鈕
-- 版面在共用層 Libs/MiliUIWidgets/BlizzOptions.lua，這裡只填字串。
--
-- 本體是這一組裡唯一的特例，兩處：
--   * 分類名叫「0米利UI設定」讓它在清單裡排最前；開頭那個 0 由
--     Enhance/AddonNames.lua 在顯示時洗掉。
--   * setCategoryID = false —— 不覆寫 category.ID。Blizzard 12.0+ 的
--     OpenSettingsPanel 內部需要 numeric ID，而本體這一頁會被別的地方用那條路開。
------------------------------------------------------------
local _, ns = ...

local category = ns.RegisterBlizzardCategory{
    title         = "米利UI套組",
    instructions  = "輸入 /miliui，或從 ESC 選單的「米利UI設定」按鈕開啟",
    versionText   = "版本：" .. ns.VERSION,
    buttonText    = "開啟設定",
    categoryName  = "0米利UI設定",
    setCategoryID = false,
}

-- 舊接口：其他模組曾經用它開暴雪面板，留著指向這一頁
MiliUI = MiliUI or {}
MiliUI.SettingsCategory = category
