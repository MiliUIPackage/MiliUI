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

-- 開關只在啟動時讀一次（見 Modules/Skin.lua 結尾），所以這裡沒有「立刻套用」，
-- 只把值寫進設定
local function Apply()
end

local function BuildControls()
    return {
        { type = "header", label = L["Icon skin"] },
        { type = "toggle", key = "enabled", label = L["Frame the aura icons"] },
        { type = "text",   label = L["Draws a thin border around the buff and debuff icons, matching the rest of the MiliUI package. Weapon enchants get a purple border instead; debuffs keep Blizzard's dispel-type colours on the outside."] },
        { type = "text",   label = L["Takes effect after you reload the interface."] },
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
