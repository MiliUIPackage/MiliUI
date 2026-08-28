------------------------------------------------------------
-- 「圖示樣式」分頁：光環圖示的 1px 邊框
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local tab, scroll, refreshers

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

-- 厚度即時套用；開關只在啟動時讀一次（hook 是單向的），要重載才生效
local function Apply()
    ns.Skin.Apply()
end

local function BuildControls()
    return {
        { type = "header", label = L["Icon skin"] },
        { type = "toggle", key = "enabled", label = L["Frame the aura icons"] },
        { type = "text",   label = L["Draws a thin border around the buff and debuff icons, matching the rest of the MiliUI package. Weapon enchants get a purple border. Debuff borders take the dispel-type colour whenever the aura is readable; in raids, Mythic+ and PvP the aura data is sealed, so those keep Blizzard's own dispel border art instead."] },
        { type = "text",   label = L["The switch takes effect after you reload the interface."] },
        { type = "slider", key = "inset", label = L["Border thickness"],
          min = 1, max = 4, step = 1 },
        { type = "slider", key = "spacing", label = L["Icon spacing"],
          min = 0, max = 10, step = 1 },
        { type = "text",   label = L["Spacing between the aura icons. This value takes over from the icon padding in Edit Mode's buff and debuff frame settings."] },
    }
end

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["Icon skin"])
    local ctx = ns.Controls.MakeCtx(function() return ns.db.skin end, Apply)
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, BuildControls(), ctx)
end

ns.RegisterCallback("ShowOptionsTab", "skinTab", function(id)
    if id ~= "skin" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)

ns.RegisterCallback("SettingsChanged", "skinTab", function()
    if tab and tab:IsShown() then RefreshAll() end
end)
