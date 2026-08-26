------------------------------------------------------------
-- 本插件專屬的選單清單（共用層 Controls.lua 不放宿主資料）
------------------------------------------------------------
local _, ns = ...

local L = ns.L

ns.Specs = {}
local Specs = ns.Specs

-- 字型清單住在 Core/Media.lua（那裡是字型的唯一來源），這裡只轉呼叫。
-- ⚠ 傳函式不傳表：LibSharedMedia 可能比我們晚載入，開分頁那一刻才求值才列得全。
Specs.FontItems = function() return ns.Media.FontItems() end

-- 堆疊層數的錨點。八個方位的鍵值與 Core/DB.lua 的 DB.ANCHORS 一致。
Specs.ANCHORS = {
    { text = L["Top left"],     value = "TOPLEFT" },
    { text = L["Top"],          value = "TOP" },
    { text = L["Top right"],    value = "TOPRIGHT" },
    { text = L["Left"],         value = "LEFT" },
    { text = L["Right"],        value = "RIGHT" },
    { text = L["Bottom left"],  value = "BOTTOMLEFT" },
    { text = L["Bottom"],       value = "BOTTOM" },
    { text = L["Bottom right"], value = "BOTTOMRIGHT" },
}
