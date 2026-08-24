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
    { type = "toggle", key = "hideBuiltinMeter", label = L["Hide Blizzard's built-in damage meter"] },
    { type = "text",   label = L["On by default — two meter windows on screen at once is confusing. But this only makes it invisible (transparent and click-through): the frame still exists, still updates, and still costs resources."] },
    { type = "text",   label = L["It is always visible again while Edit Mode is open, so you can still move it or switch it off there."] },
    { type = "custom", label = L["Really turn it off"], build = function(parent, x, y, width)
        local btn = ns.W.CreateButton(parent, L["Turn off the built-in meter"], "red", 220, 22)
        btn:SetPoint("LEFT", parent, "TOPLEFT", x, y - 13)
        local note = parent:CreateFontString(nil, "OVERLAY")
        note:SetFontObject(ns.W.fontSmall)
        note:SetPoint("LEFT", btn, "RIGHT", 8, 0)
        note:SetTextColor(0.6, 0.6, 0.6)

        local function Refresh()
            local on = ns.Builtin.IsEnabled()
            btn:SetEnabled(on == true)
            if on == true then
                note:SetText(L["Currently on"])
                note:SetTextColor(1, 0.7, 0.2)
            elseif on == false then
                note:SetText(L["Already off"])
                note:SetTextColor(0.45, 0.75, 0.45)
            else
                note:SetText("")
            end
        end
        btn:SetScript("OnClick", function()
            -- 這一步刻意只在玩家按下去才跑 —— 那是他的設定，我們不自動改
            if not ns.Builtin.Disable() then
                ns.Print(L["Could not change that setting; please use the game's Options panel."])
            end
            Refresh()
        end)
        return 26, Refresh
    end },
    { type = "text",   label = L["This flips the game's own setting (Options → Gameplay Enhancements → Damage Meter). It is a normal setting — you can turn it back on there at any time."] },

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
    { type = "text",   label = L["Resetting is still available from the right-click menu and from /mdm reset."] },

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
