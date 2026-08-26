------------------------------------------------------------
-- 「堆疊層數」分頁：層數文字的錨點、位移與字型
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local LIMITS = ns.DB.LIMITS

local tab, scroll, refreshers

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

local function Apply()
    ns.AuraStyle.Apply()
end

local CONTROLS = {
    { type = "header", label = L["Stacks"] },
    { type = "toggle", key = "enabled", label = L["Move the stack count"] },
    { type = "text",   label = L["Sets where the stack number sits on the icon, and optionally its font."] },

    { type = "dropdown", key = "anchor", label = L["Position"], items = ns.Specs.ANCHORS },
    { type = "slider", key = "x", label = L["Horizontal offset"],
      min = LIMITS.countX[1], max = LIMITS.countX[2], step = 1 },
    { type = "slider", key = "y", label = L["Vertical offset"],
      min = LIMITS.countY[1], max = LIMITS.countY[2], step = 1 },
    { type = "text",   label = L["The offset is measured from the corner you picked above."] },

    { type = "dropdown", key = "font", label = L["Font"],
      items = function() return ns.Specs.FontItems() end },
    { type = "text",   label = L["Only the typeface changes — the stack number keeps Blizzard's own size."] },
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["Stacks"])
    local ctx = ns.Controls.MakeCtx(function() return ns.db.count end, Apply)
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx)
end

ns.RegisterCallback("ShowOptionsTab", "countTab", function(id)
    if id ~= "count" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)

ns.RegisterCallback("SettingsChanged", "countTab", function()
    if tab and tab:IsShown() then RefreshAll() end
end)
