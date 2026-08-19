------------------------------------------------------------
-- 「召喚物」分頁
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W, Controls = ns.W, ns.Controls

local tab, scroll, content, rows
local refreshers

local CONTROLS = {
    { type = "toggle", key = "enabled", label = L["Show summons frame"] },
    { type = "text",   label = L["|cff4DD2FFWhile this tab is open the frame shows four demo summons|r (with running timer bars and countdowns) so you can line up position and size. Switch tabs or close the panel to go back to the real state."] },
    { type = "text",   label = L["Totems, Jade Serpent / Black Ox statues, Efflorescence and anything else you drop that sticks around for a while: Blizzard keeps them all in the same set of four slots, so they are managed together here. Style: icon capsules with a timer bar along the bottom."] },
    { type = "header", label = L["Position and size"] },
    { type = "text",   label = L["Offset from the bottom-left corner of the player frame (negative goes down), sharing coordinates with the resource bars, so it follows the player frame when you move it. You can also drag it in Edit Mode. The frame is always four slots wide, filling left to right."] },
    { type = "numbers", sub = "frame", label = L["Position"], fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } },
    { type = "slider", sub = "frame", key = "iconSize", label = L["Icon size"], min = 16, max = 64 },
    { type = "slider", sub = "frame", key = "spacing", label = L["Spacing"], min = 0, max = 16 },
    { type = "header", label = L["Color and order"] },
    { type = "dropdown", key = "colors", label = L["Timer bar color"],
      items = { { text = L["Class color"], value = "accent" }, { text = L["Element colors (fire / earth / water / air)"], value = "element" } } },
    { type = "toggle", key = "swapEarthFire", label = L["Swap earth and fire positions"] },
    { type = "header", label = L["Time remaining"] },
    { type = "toggle", key = "showTimeText", label = L["Show remaining seconds"] },
    { type = "text",   label = L["Turn this off to keep only the bar at the bottom. 12.1 sometimes won't hand over the remaining time; when that happens the number stays blank and the bar shows full."] },
    { type = "header", label = L["Reset"] },
    { type = "button", label = L["Restore defaults"], text = L["Restore summons defaults"], color = "red",
      confirm = L["Restore the summons frame settings to their defaults?"],
      onClick = function()
          ns.DB.ResetUnit("totem")
          if ns.TotemsApplySettings then ns.TotemsApplySettings() end
      end },
}

local function Init()
    if tab then return end
    -- 內容比面板高就會掉出去，一律走卷軸（同資源分頁）
    tab, scroll = ns.Options.MakeFormTab(L["Summons"])

    local ctx = Controls.MakeCtx(function() return ns.db.units.totem end, function()
        if ns.TotemsApplySettings then ns.TotemsApplySettings() end
    end)

    content, rows, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx, 620)
end

-- 換設定檔時，正開著的這一頁要重整。
-- ⚠ ctx 是現查 ns.db 所以**寫入**一直都正確，錯的是**控件顯示值** —— 那是 refresher
-- 推上去的，而 refresher 只在 ShowOptionsTab 跑。原本只有「單位」分頁訂了這個事件，
-- 所以停在這一頁換設定檔會看到顏色與滑桿全停在舊值，切走再切回來才對。
ns.RegisterCallback("ProfileChanged", "totemTabProfile", function()
    if tab and tab:IsShown() then
        for _, fn in ipairs(refreshers) do fn() end
    end
end)

ns.RegisterCallback("ShowOptionsTab", "totemTab", function(id)
    -- 沒放召喚物時框是空的，調位置等於對著空氣調 → 進這一頁就填示範內容
    if ns.TotemsSetPreview then ns.TotemsSetPreview(id == "totem") end
    if id ~= "totem" then
        if tab then tab:Hide() end
        return
    end
    Init()
    for _, fn in ipairs(refreshers) do fn() end
    tab:Show()
end)

------------------------------------------------------------
-- 設定搜尋（Options/Search.lua）
------------------------------------------------------------
-- ⚠ 職業判斷要跟 Options/Panel.lua 的分頁清單同一套（兩邊都讀 ns.TOTEM_CLASSES）。
-- 無條件註冊的話，法師搜「召喚物」會跳到一個根本沒有按鈕的分頁：高亮停在別的鈕上，
-- 而 ShowOptionsTab 照樣把它叫出來，還順手替一個用不到的職業建出召喚物框、
-- 鋪四個示範圖示。
if ns.TOTEM_CLASSES[ns.playerClass] then
ns.Search.Register("totem", {
    label = L["Summons"],
    enumerate = function(add) add(CONTROLS, L["Summons"]) end,
    jump = function(_, spec)
        Init()
        ns.Search.Reveal(scroll, content, rows, spec)
    end,
})
end
