------------------------------------------------------------
-- 「文字」分頁：字型、字級、顏色、位移、數字格式
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
    { type = "header", label = L["Font"] },
    { type = "dropdown", key = "font", label = L["Font"],
      items = function() return Specs.FontItems() end },
    { type = "dropdown", key = "fontOutline", label = L["Outline"], items = Specs.OUTLINES },

    { type = "header", label = L["Left text (rank and name)"] },
    { type = "slider", key = "leftFontSize", label = L["Font size"], min = 7, max = 24, step = 1 },
    { type = "toggle", key = "leftTextUseClassColor", label = L["Use the class color"] },
    { type = "color",  key = "leftTextColor", label = L["Text color"], hasAlpha = false },
    { type = "numbers", label = L["Offset"], fields = {
        { key = "leftTextOffsetX", label = "X" },
        { key = "leftTextOffsetY", label = "Y" },
    } },
    { type = "toggle", key = "hideRank", label = L["Hide the rank number"] },

    { type = "header", label = L["Right text (value)"] },
    { type = "slider", key = "rightFontSize", label = L["Font size"], min = 7, max = 24, step = 1 },
    { type = "toggle", key = "rightTextUseClassColor", label = L["Use the class color"] },
    { type = "color",  key = "rightTextColor", label = L["Text color"], hasAlpha = false },
    { type = "numbers", label = L["Offset"], fields = {
        { key = "rightTextOffsetX", label = "X" },
        { key = "rightTextOffsetY", label = "Y" },
    } },

    { type = "header", label = L["Numbers"] },
    { type = "dropdown", key = "numberFormat", label = L["Value format"], items = Specs.NUMBER_FORMATS },
    { type = "toggle", key = "showPercent", label = L["Append the share of the total"] },
    { type = "text",   label = L["The share is hidden while the API returns secret values (restricted content) — the totals cannot be added up there."] },
    { type = "toggle", key = "forceEnglishUnits", label = L["Force K / M / B units"] },
    { type = "text",   label = L["Chinese and Korean clients group numbers by 萬 / 억 by default. This forces the western K/M/B grouping instead; it does nothing on other clients."] },
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["Text"])
    local ctx = ns.Controls.MakeCtx(function() return ns.db.style end, Apply)
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx)
end

ns.RegisterCallback("ShowOptionsTab", "textTab", function(id)
    if id ~= "text" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)
