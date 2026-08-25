------------------------------------------------------------
-- 本插件專屬的選單清單（共用層 Controls.lua 不放宿主資料）
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local D = ns.Data

ns.Specs = {}
local Specs = ns.Specs

------------------------------------------------------------
-- 字型／材質的清單住在 Core/Media.lua（那裡是這兩者的唯一來源，
-- 內建材質的註冊也在那）。這裡只轉呼叫，不要各自維護一份。
------------------------------------------------------------
Specs.FontItems    = function() return ns.Media.FontItems() end
Specs.TextureItems = function() return ns.Media.BarTextureItems() end

Specs.OUTLINES = {
    { text = L["None"],           value = "NONE" },
    { text = L["Outline"],        value = "OUTLINE" },
    { text = L["Thick outline"],  value = "THICKOUTLINE" },
}

------------------------------------------------------------
-- 統計類型
------------------------------------------------------------
function Specs.MeterTypeItems()
    local items = {}
    for _, dmType in ipairs(D.TYPE_ORDER) do
        items[#items + 1] = {
            text = D.TYPE_NAMES[dmType] or "?",
            value = dmType,
        }
    end
    return items
end

------------------------------------------------------------
-- 其他固定清單
------------------------------------------------------------
Specs.NUMBER_FORMATS = {
    { text = L["Per second only"],    value = 0 },
    { text = L["Total only"],         value = 1 },
    { text = L["Total (per second)"], value = 2 },
    { text = L["Total | per second"], value = 3 },
}

Specs.ICON_STYLES = {
    { text = L["Specialization icon"], value = "spec" },
    { text = L["Class icon"],          value = "class" },
    { text = L["None"],                value = "none" },
}

Specs.AUTO_RESET = {
    { text = L["Ask first"],       value = "ask" },
    { text = L["Reset silently"],  value = "auto" },
    { text = L["Do nothing"],      value = "off" },
}

Specs.BAR_STYLES = {
    { text = L["Line under the row"], value = "line-bottom" },
    { text = L["Line above the row"], value = "line-top" },
    { text = L["Filled bar"],         value = "fill" },
}

Specs.BAR_COLOR_MODES = {
    { text = L["Class color"],  value = "class" },
    { text = L["Accent color"], value = "accent" },
    { text = L["Custom color"], value = "custom" },
}

Specs.BREAKDOWN_ANCHORS = {
    { text = L["Above the hovered row"], value = "row" },
    { text = L["Center of the screen"],  value = "center" },
    { text = L["Left of the window"],    value = "left" },
    { text = L["Right of the window"],   value = "right" },
}

Specs.VISIBILITY = {
    { text = L["Always"],       value = "always" },
    { text = L["In combat"],    value = "combat" },
    { text = L["In instances"], value = "instance" },
    { text = L["In a group"],   value = "group" },
}

Specs.SESSION_TYPES = {
    { text = L["Current"], value = D.S.Current },
    { text = L["Overall"], value = D.S.Overall },
}

function Specs.WindowItems()
    local items = {}
    for i = 1, ns.DB.WindowCount() do
        items[i] = { text = ns.Windows.Label(i), value = i }
    end
    return items
end
