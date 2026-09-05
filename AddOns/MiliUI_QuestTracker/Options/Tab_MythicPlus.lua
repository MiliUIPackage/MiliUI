------------------------------------------------------------
-- 「傳奇鑰石」分頁：計時面板
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local tab, scroll, refreshers

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

local function Apply()
    ns.Fire("Apply")
end

local function BuildControls()
    return {
        { type = "header", label = L["Mythic+ timer"] },
        { type = "text",   label = L["While a keystone is running the list folds away and this panel takes its place under the title bar: timer with +2/+3 splits, key level and affixes, deaths, bosses with kill times, and the enemy forces bar. It needs \"During a Mythic+ run\" on the Folding tab to be on."] },
        { type = "toggle", key = "enabled",      label = L["Show the panel"] },
        { type = "toggle", key = "tooltipCount", label = L["Enemy forces in unit tooltips"] },

        { type = "header", label = L["Sizes"] },
        { type = "slider", key = "timerSize",     label = L["Timer size"],     min = 16, max = 48, step = 1 },
        { type = "slider", key = "keySize",       label = L["Key level size"], min = 10, max = 32, step = 1 },
        { type = "slider", key = "textSize",      label = L["Text size"],      min = 8,  max = 24, step = 1 },
        { type = "slider", key = "objectiveSize", label = L["Boss list size"], min = 8,  max = 24, step = 1 },
        { type = "slider", key = "barHeight",     label = L["Bar height"],     min = 4,  max = 24, step = 1 },
        { type = "text",   label = L["Font and outline follow the Appearance tab. Colours are fixed: white text, grey timer bars, gold forces bar, green for completed."] },
    }
end

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["Mythic+"])
    local ctx = ns.Controls.MakeCtx(function() return ns.db.mythicPlus end, Apply)
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, BuildControls(), ctx)
end

ns.RegisterCallback("ShowOptionsTab", "mythicPlusTab", function(id)
    if id ~= "mythicPlus" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)

ns.RegisterCallback("SettingsChanged", "mythicPlusTab", function()
    if tab and tab:IsShown() then RefreshAll() end
end)
