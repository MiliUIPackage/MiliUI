------------------------------------------------------------
-- 「一般」分頁：全域樣式與顏色
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W, Controls = ns.W, ns.Controls

local tab, scroll
local refreshers

local function ApplyAll()
    -- 格線參數改了要立刻重畫（設定面板通常就是在編輯模式裡開著的）
    if ns.UpdateEditGrid then ns.UpdateEditGrid() end
    for unitKey in pairs(ns.db.units) do
        if unitKey == "totem" then
            if ns.TotemsApplySettings then ns.TotemsApplySettings() end
        else
            ns.ApplySettings(unitKey)
        end
    end
end

local CONTROLS = {
    -- items 傳的是函式不是表：材質／字型清單要等 LibSharedMedia 與其他插件註冊完才算得準，
    -- 檔案層先算好會列不全（見 Core/Media.lua 與 Controls.Build 的 dropdown 分支）
    { type = "header", label = L["Texture and font"] },
    { type = "dropdown", key = "barTexture", label = L["Bar texture"], items = ns.Media.BarTextureItems },
    { type = "text",   label = L["Shared by every health bar, power bar, cast bar and resource bar. Textures from other addons appear here when any installed addon ships LibSharedMedia."] },
    { type = "dropdown", key = "font", label = L["Font"], items = ns.Media.FontItems },
    { type = "text",   label = L["\"Default\" follows your client language, so Chinese and Korean render properly. Extra entries appear only when an installed addon ships LibSharedMedia."] },

    { type = "header", label = L["Border"] },
    { type = "slider", key = "borderSize", label = L["Border thickness"], min = 0, max = 3, step = 1 },
    { type = "text",   label = L["0 = no border. Shared by every unit frame, health bar and power bar."] },
    { type = "color",  key = "borderColor", label = L["Border color"] },

    { type = "header", label = L["Numbers and animation"] },
    { type = "dropdown", key = "numberFormat", label = L["Number abbreviation"], items = {
        { text = L["By locale (wan/yi for Chinese, K/M otherwise)"], value = "auto" },
        { text = L["Wan / Yi"], value = "wan" },
        { text = "K／M", value = "km" },
        { text = L["No abbreviation (thousands separator)"], value = "raw" },
    } },
    { type = "text",   label = L["Health and power numbers are abbreviated by the game (12.1 secret values can't be used in addon arithmetic), so only these official formats are available."] },
    { type = "dropdown", key = "percentDecimals", label = L["Percent decimals"], items = {
        { text = L["Integer (85%)"], value = 0 }, { text = L["One decimal (85.3%)"], value = 1 },
    } },
    { type = "toggle", key = "smoothBars", label = L["Smooth health and power bars"] },
    { type = "text",   label = L["Uses the engine's built-in interpolation (native in 12.x, works with secret values), so bars slide instead of jumping."] },

    { type = "header", label = L["Fade"] },
    { type = "slider", key = "oorAlpha", label = L["Out of range transparency"], min = 0.1, max = 1, step = 0.05 },
    { type = "slider", key = "oocAlpha", label = L["Out of combat transparency"], min = 0.1, max = 1, step = 0.05 },
    { type = "text",   label = L["Which frames fade, and on which of the two conditions, is set per unit under Units > Frame. With both on, whichever is more transparent wins."] },

    { type = "header", label = L["Mouseover"] },
    { type = "color",  key = "highlightColor", label = L["Highlight color"] },
    { type = "slider", key = "highlightSize", label = L["Highlight thickness"], min = 1, max = 4, step = 1 },
    { type = "text",   label = L["The border drawn while the cursor is over a frame. Which frames get it is set per unit, under Units > Frame."] },

    { type = "header", label = L["Health colors"] },
    { type = "text",   label = L["The \"health gradient\" method interpolates between these two; gray is used for dead / offline / out-of-range text."] },
    { type = "color", sub = "colors", key = "hpGreen", label = L["Healthy"] },
    { type = "color", sub = "colors", key = "hpRed",   label = L["Critical"] },
    { type = "color", sub = "colors", key = "gray",    label = L["Gray"] },

    { type = "header", label = L["Cast bar colors"] },
    { type = "text",   label = L["Every cast bar shares these colors; whether \"non-interruptible\" applies is set per unit. The defaults match the Platynator nameplate preset that ships with MiliUI, so the same cast state reads the same on both."] },
    { type = "color", sub = "colors", key = "cast",    label = L["Casting"], hasAlpha = false },
    { type = "color", sub = "colors", key = "channel", label = L["Channeling"], hasAlpha = false },
    { type = "color", sub = "colors", key = "empowered", label = L["Empowered"], hasAlpha = false },
    { type = "color", sub = "colors", key = "complete", label = L["Completed"], hasAlpha = false },
    { type = "color", sub = "colors", key = "fail",    label = L["Failed / interrupted"], hasAlpha = false },
    { type = "color", sub = "colors", key = "notInterruptible", label = L["Non-interruptible"], hasAlpha = false },
    { type = "color", sub = "colors", key = "interruptReady", label = L["Your interrupt is ready"], hasAlpha = false },
    { type = "text",   label = L["\"Your interrupt is ready\" tints the bar while your own interrupt is off cooldown, so you can see at a glance whether a cast is worth stopping. Enable it per unit under Units > Cast bar."] },

    { type = "header", label = L["Edit Mode grid"] },
    { type = "toggle", key = "gridShow", label = L["Show grid"] },
    { type = "toggle", key = "gridSnap", label = L["Snap frames to the grid"] },
    { type = "slider", key = "gridSize", label = L["Grid spacing"], min = 8, max = 128, step = 4 },
    { type = "slider", key = "gridAlpha", label = L["Grid transparency"], min = 0.05, max = 1, step = 0.05 },
    { type = "text",   label = L["The grid appears only while Blizzard's Edit Mode is open. It is drawn outward from the center of the screen, matching how frame positions are stored, and the red cross marks that center. Hold Shift while dragging to invert snapping."] },

    { type = "header", label = L["Tooltips"] },
    { type = "toggle", key = "showTooltip", label = L["Show unit tooltip"] },
    { type = "toggle", key = "tooltipHideInCombat", label = L["Hide during combat"] },
    { type = "text",   label = L["Aura tooltips are drawn by the game (12.1 addons can't read aura contents); they follow this same toggle."] },

    { type = "header", label = L["Preview"] },
    { type = "number", key = "previewBossDisplayID", label = L["Demo model ID"], step = 1 },
    { type = "text",   label = L["The displayID used for the 3D model of hostile preview units (target / focus / boss). 131474 = Xal'atath in her 12.x form (the default), 117121 = her TWW form. Enter 0 to use your own character."] },

    { type = "header", label = L["Layer"] },
    { type = "dropdown", key = "strata", label = L["Frame layer"], items = {
        { text = L["Background"], value = "BACKGROUND" },
        { text = L["Low"],        value = "LOW" },
        { text = L["Medium"],     value = "MEDIUM" },
        { text = L["High"],       value = "HIGH" },
    } },
    { type = "text",   label = L["Which layer every unit frame sits on. Raise it if another addon draws over the frames; the default Low keeps them beneath most windows."] },

    { type = "header", label = L["Minimap"] },
    { type = "toggle", root = "minimap", key = "show", label = L["Show minimap button"] },

    { type = "header", label = L["Reset"] },
    { type = "button", label = L["Global style"], text = L["Restore global style defaults"], color = "red",
      confirm = L["Restore global styling — borders, numbers, colors — to defaults? Per-unit settings are untouched."],
      onClick = function()
          ns.DB.ResetGlobal()
          for unitKey in pairs(ns.db.units) do
              if unitKey == "totem" then
                  if ns.TotemsApplySettings then ns.TotemsApplySettings() end
              else
                  ns.ApplySettings(unitKey)
              end
          end
      end },
    { type = "text", label = L["Per-unit reset lives at the bottom of Units > Frame; restore-everything lives on the Profile tab."] },
}

local function Init()
    if tab then return end
    tab = CreateFrame("Frame", nil, ns.Options.panel)
    tab:SetAllPoints(ns.Options.panel)
    tab:Hide()

    local title = W.CreateSectionTitle(tab, L["Global style"], 660)
    title:SetPoint("TOPLEFT", 16, -14)

    local scrollHolder = CreateFrame("Frame", nil, tab)
    scrollHolder:SetPoint("TOPLEFT", 16, -44)
    scrollHolder:SetPoint("BOTTOMRIGHT", -8, 10)
    scroll = W.CreateScrollFrame(scrollHolder)

    local content = CreateFrame("Frame", nil, scroll.child)
    content:SetPoint("TOPLEFT")
    content:SetSize(640, 1)

    local ctx = {
        get = function(spec)
            if spec.root == "minimap" then
                return not ns.db.minimap.hide
            end
            local t = Controls.Resolve(ns.db.global, spec)
            return t[spec.key]
        end,
        set = function(spec, v)
            if spec.root == "minimap" then
                ns.SetMinimapButtonShown(v)
                return
            end
            local t = Controls.Resolve(ns.db.global, spec)
            t[spec.key] = v
        end,
        apply = ApplyAll,
    }

    local height, r = Controls.Build(content, CONTROLS, ctx, 4, -4, 640)
    content:SetHeight(height + 20)
    scroll:SetContentHeight(height + 20)
    refreshers = r
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
