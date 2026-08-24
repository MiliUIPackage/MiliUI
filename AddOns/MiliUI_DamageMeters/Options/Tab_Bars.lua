------------------------------------------------------------
-- 「長條」分頁：列高、材質、顏色、圖示、底色、邊框
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local Specs = ns.Specs

local tab, scroll, refreshers

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

local function Apply()
    ns.Windows.ApplyStyle()
    RefreshAll()
end

local CONTROLS = {
    { type = "header", label = L["Size"] },
    { type = "slider", key = "barHeight",  label = L["Bar height"],  min = 8,  max = 40, step = 1 },
    { type = "slider", key = "barSpacing", label = L["Bar spacing"], min = 0,  max = 10, step = 1 },

    { type = "header", label = L["Fill"] },
    { type = "dropdown", key = "barStyle", label = L["Bar style"], items = Specs.BAR_STYLES },
    { type = "text",   label = L["The line style keeps the icon and the text, and shrinks the bar itself down to a hairline along the edge of the row — the line length still tracks the value."] },
    { type = "slider", key = "barLineHeight", label = L["Line thickness"], min = 1, max = 6, step = 1 },
    { type = "dropdown", key = "barTexture", label = L["Bar texture"],
      items = function() return Specs.TextureItems() end },
    { type = "dropdown", key = "barColorMode", label = L["Bar color"], items = Specs.BAR_COLOR_MODES },
    { type = "color",  key = "barColor", label = L["Custom bar color"], hasAlpha = false },
    { type = "text",   label = L["\"Custom color\" only applies when the bar color mode above is set to it. Accent color is your own class color."] },
    { type = "slider", key = "barFillAlpha", label = L["Fill opacity"], min = 10, max = 100, step = 5, scale = 100 },

    { type = "header", label = L["Track background"] },
    { type = "color",  key = "barBgColor", label = L["Background color"], hasAlpha = true },
    { type = "toggle", key = "barBgUseClassColor", label = L["Tint the background with the class color"] },

    { type = "header", label = L["Icon"] },
    { type = "dropdown", key = "iconStyle", label = L["Icon style"], items = Specs.ICON_STYLES },
    { type = "slider", key = "iconZoom", label = L["Icon zoom"], min = 0, max = 20, step = 1, scale = 100 },
    { type = "text",   label = L["Spec icons come from the API; the class icons are Blizzard's built-in sprite sheet. No image files of the addon's own are involved."] },

    { type = "header", label = L["Bar border"] },
    { type = "slider", key = "barBorderSize", label = L["Border thickness"], min = 0, max = 4, step = 1 },
    { type = "color",  key = "barBorderColor", label = L["Border color"], hasAlpha = true },
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["Bars"])
    local ctx = ns.Controls.MakeCtx(function() return ns.db.style end, Apply)
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx)
end

ns.RegisterCallback("ShowOptionsTab", "barsTab", function(id)
    if id ~= "bars" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)
