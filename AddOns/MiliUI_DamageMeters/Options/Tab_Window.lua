------------------------------------------------------------
-- 「視窗」分頁：背景、邊框、標題列（全部視窗共用的外觀）
------------------------------------------------------------
local _, ns = ...

local L = ns.L

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
    { type = "header", label = L["Background"] },
    { type = "color",  key = "bgColor", label = L["Window background"], hasAlpha = true },

    { type = "header", label = L["Window border"] },
    { type = "slider", key = "borderSize", label = L["Border thickness"], min = 0, max = 4, step = 1 },
    { type = "color",  key = "borderColor", label = L["Border color"], hasAlpha = true },

    { type = "header", label = L["Title bar"] },
    { type = "slider", key = "hdrHeight",   label = L["Height"],    min = 12, max = 40, step = 1 },
    { type = "slider", key = "hdrFontSize", label = L["Font size"], min = 7,  max = 24, step = 1 },
    { type = "toggle", key = "hdrTextUseClassColor", label = L["Title in your class color"] },
    { type = "text",   label = L["On by default — it is the same accent color the rest of the MiliUI addons use. Turn it off to pick a fixed color below."] },
    { type = "color",  key = "hdrTextColor", label = L["Title color"], hasAlpha = false },
    { type = "numbers", label = L["Title offset"], fields = {
        { key = "hdrTextOffX", label = "X" },
        { key = "hdrTextOffY", label = "Y" },
    } },
    { type = "color",  key = "hdrBgColor", label = L["Title bar background"], hasAlpha = true },
    { type = "slider", key = "hdrBottomBorderSize", label = L["Bottom line thickness"], min = 0, max = 4, step = 1 },
    { type = "color",  key = "hdrBottomBorderColor", label = L["Bottom line color"], hasAlpha = true },

    { type = "header", label = L["Title bar buttons"] },
    { type = "slider", key = "hdrIconSize", label = L["Button size"], min = 12, max = 32, step = 1 },
    { type = "toggle", key = "hdrMouseoverIcons", label = L["Only show the buttons on mouseover"] },
    { type = "text",   label = L["Hidden buttons take up no space, so the title gets the whole bar."] },
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["Window"])
    local ctx = ns.Controls.MakeCtx(function() return ns.db.style end, Apply)
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx)
end

ns.RegisterCallback("ShowOptionsTab", "windowTab", function(id)
    if id ~= "window" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)
