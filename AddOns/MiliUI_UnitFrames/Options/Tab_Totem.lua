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
    tab = CreateFrame("Frame", nil, ns.Options.panel)
    tab:SetAllPoints(ns.Options.panel)
    tab:Hide()

    local title = W.CreateSectionTitle(tab, L["Summons"], 660)
    title:SetPoint("TOPLEFT", 16, -14)

    -- 同資源分頁：內容比面板高就會掉出去，一律走卷軸
    local holder = CreateFrame("Frame", nil, tab)
    holder:SetPoint("TOPLEFT", 16, -44)
    holder:SetPoint("BOTTOMRIGHT", -8, 10)
    scroll = W.CreateScrollFrame(holder)

    content = CreateFrame("Frame", nil, scroll.child)
    content:SetPoint("TOPLEFT")
    content:SetSize(620, 1)

    local ctx = {
        get = function(spec)
            local t = Controls.Resolve(ns.db.units.totem, spec)
            return t and t[spec.key]
        end,
        set = function(spec, v)
            local t = Controls.Resolve(ns.db.units.totem, spec)
            if t then t[spec.key] = v end
        end,
        apply = function()
            if ns.TotemsApplySettings then ns.TotemsApplySettings() end
        end,
    }

    local height, r, built = Controls.Build(content, CONTROLS, ctx, 4, -4, 620)
    rows = built
    content:SetHeight(height + 20)
    scroll:SetContentHeight(height + 20)
    refreshers = r
end

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
ns.Search.Register("totem", {
    label = L["Summons"],
    enumerate = function(add) add(CONTROLS, L["Summons"]) end,
    jump = function(_, spec)
        Init()
        ns.Search.Reveal(scroll, content, rows, spec)
    end,
})
