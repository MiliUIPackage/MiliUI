------------------------------------------------------------
-- 「樣式」分頁：縮放、背景、邊框、字型、血條
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local Controls = ns.Controls
local Specs = ns.Specs

local tab, scroll, refreshers

local CONTROLS = {
    { type = "header", label = L["Scale and background"] },
    { type = "slider", key = "scale", label = L["Scale"], min = 0.5, max = 2, step = 0.05 },
    { type = "dropdown", key = "bgfile", label = L["Background texture"], items = function() return ns.Media.BackgroundItems() end },
    { type = "color",  key = "background", label = L["Background color"] },
    { type = "toggle", key = "mask", label = L["Top gradient sheen"] },

    { type = "header", label = L["Border"] },
    { type = "slider", key = "borderSize", label = L["Border thickness"], min = 0, max = 3, step = 1 },
    { type = "text",   label = L["0 = no border. Unit and item tooltips tint this border by class / reaction / quality."] },
    { type = "color",  key = "borderColor", label = L["Border color"] },

    { type = "header", label = L["Font"] },
    { type = "dropdown", key = "headerFont", label = L["Header font"], items = function() return ns.Media.FontItems() end },
    { type = "number", key = "headerFontSize", label = L["Header size"], step = 1 },
    { type = "dropdown", key = "headerFontFlag", label = L["Header outline"], items = Specs.FONT_FLAG_ITEMS },
    { type = "dropdown", key = "bodyFont", label = L["Body font"], items = function() return ns.Media.FontItems() end },
    { type = "number", key = "bodyFontSize", label = L["Body size"], step = 1 },
    { type = "dropdown", key = "bodyFontFlag", label = L["Body outline"], items = Specs.FONT_FLAG_ITEMS },
    { type = "text",   label = L["Size 0 keeps the game default. Fonts apply to every tooltip in the game."] },

    { type = "header", label = L["Health bar"] },
    { type = "toggle", root = "statusbar", key = "enable", label = L["Show health bar"] },
    { type = "dropdown", root = "statusbar", key = "position", label = L["Position"], items = Specs.BAR_POSITION_ITEMS },
    { type = "slider", root = "statusbar", key = "height", label = L["Height"], min = 2, max = 20, step = 1 },
    { type = "dropdown", root = "statusbar", key = "texture", label = L["Bar texture"], items = function() return ns.Media.BarTextureItems() end },
    { type = "dropdown", root = "statusbar", key = "textFormat", label = L["Text"], items = Specs.BAR_FORMAT_ITEMS },
    { type = "number", root = "statusbar", key = "fontSize", label = L["Text size"], step = 1 },
    { type = "dropdown", root = "statusbar", key = "color", label = L["Bar color"], items = Specs.BAR_COLOR_ITEMS },
    { type = "color",  root = "statusbar", key = "customColor", label = L["Custom bar color"], hasAlpha = false },

    { type = "header", label = L["Reset"] },
    { type = "button", label = L["Everything"], text = L["Restore all defaults"], color = "red",
      confirm = L["Restore every setting to defaults and reload the UI?"],
      onClick = function() ns.DB.ResetAll() end },
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["Style"])
    local ctx = Controls.MakeCtx(function(spec)
        if spec.root == "statusbar" then return ns.db.statusbar end
        return ns.db.general
    end, ns.ApplyAll)
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx, 640)
end

ns.RegisterCallback("ShowOptionsTab", "generalTab", function(id)
    if id ~= "general" then
        if tab then tab:Hide() end
        return
    end
    Init()
    for _, fn in ipairs(refreshers) do fn() end
    tab:Show()
end)
