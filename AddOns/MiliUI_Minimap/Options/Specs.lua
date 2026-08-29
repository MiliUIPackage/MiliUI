------------------------------------------------------------
-- 下拉選單的清單
--
-- ⚠ 字型清單一定要是**函式**、不能是檔案層的常數表：LibSharedMedia 可能比我們
--   晚載入，而且別的插件會一路註冊到 PLAYER_LOGIN 之後。開分頁那一刻才求值
--   才列得全。（同一條在 MiliUI_DamageMeters/Core/Media.lua 也寫著。）
------------------------------------------------------------
local _, ns = ...

local L = ns.L

ns.Specs = {}
local Specs = ns.Specs

Specs.SHAPES = {
    { text = L["Square"], value = "square" },
    { text = L["Circle"], value = "circle" },
}

-- 三種顯示模式共用一份 —— 玩家在每個元素看到的選項都一樣，學一次就好
Specs.VISIBILITY = {
    { text = L["Always"],    value = "always" },
    { text = L["Mouseover"], value = "mouseover" },
    { text = L["Never"],     value = "never" },
}

Specs.OUTLINES = {
    { text = L["None"],          value = "NONE" },
    { text = L["Outline"],       value = "OUTLINE" },
    { text = L["Thick outline"], value = "THICKOUTLINE" },
}

Specs.INFO_SOURCES = {
    { text = L["Guild"],        value = "guild" },
    { text = L["Friends"],      value = "friends" },
    { text = L["Addon buttons"], value = "bag" },
    { text = L["Nothing"],      value = "none" },
}

Specs.PIN_SIDES = {
    { text = L["Top"],    value = "top" },
    { text = L["Bottom"], value = "bottom" },
    { text = L["Left"],   value = "left" },
    { text = L["Right"],  value = "right" },
}

function Specs.Fonts()
    return ns.Style.FontItems()
end
