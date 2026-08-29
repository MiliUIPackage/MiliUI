------------------------------------------------------------
-- 「外觀」分頁：字型、顏色、背景、標題列
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local tab, scroll, refreshers

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

-- 「移除暴雪的裝飾」是**單向**的：我們用 SetTexture("") 把貼圖清掉，而暴雪不會
-- 自己重設已經在畫面上的區塊，所以關掉它救不回那些圖。設定改了畫面沒動，玩家的
-- 第一個結論是插件壞了 —— 寧可跳一個對話框，也不要靜靜地沒反應。
local lastStripArt

local function Apply()
    ns.Fire("Apply")

    local now = ns.db.appearance.stripArt and true or false
    if lastStripArt == nil then lastStripArt = now end
    if lastStripArt and not now then
        ns.Options.AskReload(L["Blizzard's decorations only come back after a UI reload."])
    end
    lastStripArt = now
end

local function BuildControls()
    return {
        { type = "header", label = L["Position"] },
        { type = "text",   label = L["Open this window and a coloured overlay appears on the tracker: drag it to move, right-click to hand the position back to Edit Mode."] },
        { type = "text",   label = L["Edit Mode owns the tracker's position until you drag it once. After that this addon keeps putting it back where you left it, including after Edit Mode applies a layout."] },
        { type = "button", label = L["Position"], text = L["Hand back to Edit Mode"], color = "red",
          onClick = function() ns.Position.Reset() end },

        { type = "header", label = L["Text"] },
        { type = "dropdown", key = "font", label = L["Font"], items = ns.Media.FontItems },
        { type = "text",   label = L["Leave this on Blizzard's font to keep each line's original typeface and only change the sizes below."] },
        { type = "toggle", key = "outline", label = L["Outline"] },
        { type = "slider", key = "headerSize",    label = L["Section header size"], min = 8, max = 24, step = 1 },
        { type = "slider", key = "titleSize",     label = L["Quest title size"],    min = 8, max = 24, step = 1 },
        { type = "slider", key = "objectiveSize", label = L["Objective size"],      min = 8, max = 24, step = 1 },
        { type = "text",   label = L["Changing a size leaves Blizzard's cached row heights slightly off until the next quest update — the gaps close on their own. Forcing the tracker to re-lay out is the one thing this addon must never do."] },

        { type = "header", label = L["Colours"] },
        { type = "color",  key = "titleColor",     label = L["Quest title"],  hasAlpha = false },
        { type = "color",  key = "completedColor", label = L["Completed"],    hasAlpha = false },
        { type = "color",  key = "focusColor",     label = L["Tracked"],      hasAlpha = false },
        { type = "color",  key = "objectiveColor", label = L["Objective text"], hasAlpha = false },
        { type = "toggle", key = "headerUseClass", label = L["Section headers use your class colour"] },
        { type = "color",  key = "headerColor",    label = L["Section header colour"], hasAlpha = false },

        { type = "header", label = L["Background"] },
        { type = "toggle", key = "background", label = L["Draw a background"] },
        { type = "color",  key = "bgColor",    label = L["Background colour"], hasAlpha = false },
        { type = "slider", key = "bgAlpha",    label = L["Background opacity"],
          min = 0, max = 100, step = 5, scale = 100 },
        { type = "toggle", key = "dividers",   label = L["Hairline dividers"] },

        { type = "header", label = L["Tracker"] },
        { type = "toggle", key = "stripArt", label = L["Strip Blizzard's decorations"] },
        { type = "text",   label = L["Removes the parchment, ribbons and glows behind the tracker so the flat background reads cleanly."] },
        { type = "toggle", key = "questIcons", label = L["Quest type icons"] },
        { type = "text",   label = L["Marks campaign, legendary, important and recurring quests in the top-right corner of each block. This takes over the spot Blizzard's map pin button uses, so that button is hidden while this is on."] },
        { type = "toggle", key = "hideBlizzardHeader", label = L["Hide Blizzard's \"All Objectives\" header"] },
        { type = "toggle", key = "clickHeaderToCollapse", label = L["Click a section header to collapse it"] },
        { type = "text",   label = L["Widens the hit area of Blizzard's own +/- button across the whole header row. The click still runs Blizzard's code, not ours."] },

        { type = "header", label = L["MiliUI title bar"] },
        { type = "toggle", root = "titleBar", key = "enabled",     label = L["Show the title bar"] },
        { type = "toggle", root = "titleBar", key = "showCount",   label = L["Show the number of tracked items"] },
        { type = "toggle", root = "titleBar", key = "clickToFold", label = L["Click the title bar to fold the list"] },
    }
end

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["Appearance"])
    local ctx = ns.Controls.MakeCtx(function(spec)
        if spec.root == "titleBar" then return ns.db.titleBar end
        return ns.db.appearance
    end, Apply)
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, BuildControls(), ctx)
    lastStripArt = ns.db.appearance.stripArt and true or false
end

ns.RegisterCallback("ShowOptionsTab", "appearanceTab", function(id)
    if id ~= "appearance" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)

ns.RegisterCallback("SettingsChanged", "appearanceTab", function()
    if tab and tab:IsShown() then RefreshAll() end
end)
