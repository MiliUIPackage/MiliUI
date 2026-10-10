------------------------------------------------------------
-- 「一般」分頁：字型／小地圖
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local LIMITS = ns.DB.LIMITS

local tab, scroll, refreshers

local function Apply()
    ns.Media.UpdateFonts()
    ns.Fire("SettingsChanged")
end

local CONTROLS = {
    { type = "header", label = L["Appearance"] },
    { type = "dropdown", key = "font", label = L["Note font"],
      items = function() return ns.Media.FontItems() end },
    { type = "slider", key = "fontSize", label = L["Font size"],
      min = LIMITS.fontSize[1], max = LIMITS.fontSize[2], step = 1 },
    { type = "dropdown", key = "outline", label = L["Outline"], items = ns.Media.OUTLINE_ITEMS },
    { type = "toggle", sub = "minimap", key = "show", label = L["Minimap button"] },
    { type = "text", label = L["Show the notebook button on the minimap"] },
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["General"])
    local ctx = ns.Controls.MakeCtx(function() return ns.db.settings end, Apply)
    _, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx)
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
