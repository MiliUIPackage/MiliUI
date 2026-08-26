------------------------------------------------------------
-- 「一般」分頁：字型／小地圖 ＋ 副本浮動視窗的行為
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
    { type = "toggle", sub = "minimap", key = "show", label = L["Minimap button"],
      hint = L["Show the notebook button on the minimap"] },

    { type = "header", label = L["Dungeon and raid notes"] },
    { type = "text", label = L["Notes bound to a dungeon or one of its bosses show up on their own in a small read-only window. Its checkboxes still work, and the box at the bottom appends a line to whatever note is on screen."] },
    { type = "text", label = L["Dungeon and boss notes are account-wide: every character sees the same ones, because a route or a thing to watch out for does not change from character to character."] },
    { type = "toggle", sub = "instance", key = "autoShow", label = L["Open on entering"],
      hint = L["Show the window when I walk into a dungeon I have notes for"] },
    { type = "toggle", sub = "instance", key = "autoBoss", label = L["Follow the boss"],
      hint = L["Switch to that boss's note when the fight starts"] },
    { type = "toggle", sub = "instance", key = "autoHide", label = L["Close on leaving"],
      hint = L["Hide the window when I leave the instance"] },
    { type = "toggle", sub = "instance", key = "onlyRaid", label = L["Raids only"],
      hint = L["Do not open it automatically in 5-player dungeons"] },
    { type = "toggle", sub = "instance", key = "quickAdd", label = L["Quick line box"],
      hint = L["Keep the \"jot a line down\" box at the bottom"] },
    { type = "toggle", sub = "instance", key = "locked", label = L["Locked"],
      hint = L["Stop the window from being dragged or resized"] },
    { type = "slider", sub = "instance", key = "alpha", label = L["Opacity"],
      min = LIMITS.overlayAlpha[1], max = LIMITS.overlayAlpha[2], step = 1 },
    { type = "slider", sub = "instance", key = "width", label = L["Width"],
      min = LIMITS.overlayW[1], max = LIMITS.overlayW[2], step = 10 },
    { type = "slider", sub = "instance", key = "height", label = L["Height"],
      min = LIMITS.overlayH[1], max = LIMITS.overlayH[2], step = 10 },

    { type = "header", label = L["Tags"] },
    { type = "text", label = L["Tag body"] },
    { type = "text", label = L["The combat timer starts on its own when a boss fight begins. Outside an instance, use the dungeon window's own menu to run a test timer instead."] },
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
