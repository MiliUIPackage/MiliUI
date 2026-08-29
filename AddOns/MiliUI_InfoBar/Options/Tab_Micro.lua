------------------------------------------------------------
-- 「微型選單」分頁：圖示風格、隱藏暴雪那排、逐顆按鈕開關
--
-- 按鈕的標籤直接用 Core/MicroMenu.lua 定義裡的暴雪全域字串，
-- 各語系免費，這頁不需要自己的按鈕名語系 key。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local tab, scroll, refreshers

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

local function Apply()
    ns.ApplyAll()
    RefreshAll()
end

local function BuildControls()
    local controls = {
        { type = "header",   label = L["SECTION_MICRO_STYLE"] },
        { type = "dropdown", key = "iconStyle", label = L["ICON_STYLE"], items = {
            { value = "mono",     text = L["ICON_STYLE_MONO"] },
            { value = "blizzard", text = L["ICON_STYLE_BLIZZARD"] },
        } },
        { type = "text",   label = L["ICON_STYLE_DESC"] },
        { type = "toggle", key = "hideBlizzard", label = L["HIDE_BLIZZARD"] },
        { type = "text",   label = L["HIDE_BLIZZARD_DESC"] },

        { type = "header", label = L["SECTION_MICRO_BUTTONS"] },
        { type = "text",   label = L["MICRO_BUTTONS_DESC"] },
    }
    for _, def in ipairs(ns.MicroMenu.BUTTON_DEFS) do
        controls[#controls + 1] = {
            type = "toggle", key = def.key, sub = "micro",
            label = def.label or def.key,
        }
    end
    return controls
end

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["TAB_MICRO"])
    local ctx = ns.Controls.MakeCtx(function() return ns.GetDB() end, Apply)
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, BuildControls(), ctx)
end

ns.RegisterCallback("ShowOptionsTab", "microTab", function(id)
    if id ~= "micro" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)
