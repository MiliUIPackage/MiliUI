------------------------------------------------------------
-- 「一般」分頁：視窗數量、刷新率、磁吸、互動行為
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local Specs = ns.Specs

local tab, scroll, refreshers

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

local function Apply()
    ns.Builtin.ApplySetting()
    ns.Windows.ApplyStyle()
    RefreshAll()
end

local CONTROLS = {
    { type = "header", label = L["Windows"] },
    { type = "slider", key = "windowCount", root = "db", label = L["Number of windows"],
      min = 1, max = 5, step = 1 },
    { type = "text",   label = L["Each window has its own meter type and segment. Set them up on the \"Per window\" tab, or right-click a window."] },

    { type = "header", label = L["Update"] },
    { type = "slider", key = "refreshRate", label = L["Refresh rate (seconds)"],
      min = 0.25, max = 3, step = 0.25 },
    { type = "text",   label = L["The refresh timer only exists while you are in combat, so this does not cost anything when idle. Blizzard does the tallying (C_DamageMeter) — this addon only draws it, which is why it stays cheap even in a 20-player raid."] },

    { type = "header", label = L["Blizzard's built-in meter"] },
    { type = "toggle", key = "disableBuiltinMeter", label = L["Turn off Blizzard's built-in damage meter"] },
    { type = "text",   label = L["On by default. Two meters running at once pays the cost twice and puts two overlapping windows on your screen. This flips the game's own setting (Options → Gameplay Enhancements → Damage Meter); unchecking this box turns it back on."] },

    { type = "header", label = L["Snapping"] },
    { type = "toggle", key = "snapEnabled", label = L["Snap windows to each other"] },
    { type = "text",   label = L["While dragging or resizing, edges and sizes stick to the other meter windows. A single window can be excluded from its right-click menu."] },
    { type = "slider", key = "snapThreshold", label = L["Snap distance (pixels)"],
      min = 2, max = 20, step = 1 },

    { type = "header", label = L["Interaction"] },
    { type = "toggle", key = "showPinnedSelf", label = L["Pin your own row when it scrolls out of view"] },
    { type = "toggle", key = "showHoverTooltip", label = L["Show a spell preview on hover"] },
    { type = "dropdown", key = "breakdownAnchor", label = L["Preview position"],
      items = Specs.BREAKDOWN_ANCHORS },
    { type = "toggle", key = "showSpellTooltips", label = L["Show the game tooltip on breakdown rows"] },
    { type = "toggle", key = "hideResetButton", label = L["Hide the reset button in the title bar"] },
    { type = "toggle", key = "hideSettingsButton", label = L["Hide the settings button in the title bar"] },
    { type = "text",   label = L["Both on by default. The gear opens the same menu as right-clicking the window, and resetting is destructive enough that it should not sit under a stray click — right-click still has both, and /mdm reset works too."] },

    { type = "header", label = L["Data"] },
    { type = "button", label = L["Combat data"], text = L["Reset all segments"], color = "red",
      confirm = L["Clear every recorded segment? This affects Blizzard's damage meter too."],
      onClick = function() ns.Combat.ResetData() end },
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["General"])
    -- windowCount 住在 db 的最上層，其餘都在 db.style。
    -- root == "db" 是這個分頁唯一的例外，所以不走 MakeCtx 的單一 root。
    local ctx = {
        get = function(spec)
            local t = (spec.root == "db") and ns.db or ns.db.style
            return t[spec.key]
        end,
        set = function(spec, v)
            if spec.root == "db" then
                if spec.key == "windowCount" then
                    ns.db.windowCount = math.floor(v + 0.5)
                    ns.DB.Init()          -- 補齊新視窗的預設值
                    ns.Windows.Rebuild()
                    return
                end
                ns.db[spec.key] = v
            else
                ns.db.style[spec.key] = v
            end
        end,
        apply = Apply,
    }
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx)
end

ns.RegisterCallback("ShowOptionsTab", "generalTab", function(id)
    if id ~= "general" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)
