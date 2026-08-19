------------------------------------------------------------
-- 「一般」分頁：全域樣式與顏色
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W, Controls = ns.W, ns.Controls
local Specs = ns.Specs        -- 下拉選項清單（Options/Specs_UF.lua，TOC 排在本檔之前）

local tab, scroll, content, rows
local refreshers

local function ApplyAll()
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
    { type = "dropdown", key = "oorStyle", label = L["Out of range look"], items = Specs.OOR_STYLE_ITEMS },
    { type = "text",   label = L["\"Dim\" lays a dark layer over the bars and keeps the numbers readable. \"Fade\" makes the whole frame transparent, so the background shows through and the bar color gets muddy."] },
    { type = "slider", key = "oorDim", label = L["Dim strength"], min = 0.2, max = 0.9, step = 0.05 },
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
    { type = "color", sub = "colors", key = "important", label = L["Important spell"], hasAlpha = false },
    { type = "color", sub = "colors", key = "interruptReady", label = L["Your interrupt is ready"], hasAlpha = false },
    { type = "text",   label = L["\"Your interrupt is ready\" tints the bar while your own interrupt is off cooldown, so you can see at a glance whether a cast is worth stopping. Enable it per unit under Units > Cast bar."] },

    { type = "header", label = L["Edit Mode grid"] },
    { type = "toggle", key = "snapToGrid", label = L["Snap to the grid while dragging"] },
    { type = "text",   label = L["Spacing follows Edit Mode's own grid; hold Shift while dragging to invert this."] },

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
    tab, scroll = ns.Options.MakeFormTab(L["Global style"])

    -- 小地圖那條是特例：它不在 ns.db.global 底下，而且欄位語意是反的
    -- （spec 問「要不要顯示」，DB 存的是 hide）。包一層而不是把特例塞進工廠。
    local ctx = Controls.MakeCtx(function() return ns.db.global end, ApplyAll)
    local baseGet, baseSet = ctx.get, ctx.set
    ctx.get = function(spec)
        if spec.root == "minimap" then return not ns.db.minimap.hide end
        return baseGet(spec)
    end
    ctx.set = function(spec, v)
        if spec.root == "minimap" then ns.SetMinimapButtonShown(v); return end
        baseSet(spec, v)
    end

    content, rows, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx, 640)
end

-- 換設定檔時，正開著的這一頁要重整。
-- ⚠ ctx 是現查 ns.db 所以**寫入**一直都正確，錯的是**控件顯示值** —— 那是 refresher
-- 推上去的，而 refresher 只在 ShowOptionsTab 跑。原本只有「單位」分頁訂了這個事件，
-- 所以停在這一頁換設定檔會看到顏色與滑桿全停在舊值，切走再切回來才對。
ns.RegisterCallback("ProfileChanged", "generalTabProfile", function()
    if tab and tab:IsShown() then
        for _, fn in ipairs(refreshers) do fn() end
    end
end)

ns.RegisterCallback("ShowOptionsTab", "generalTab", function(id)
    if id ~= "general" then
        if tab then tab:Hide() end
        return
    end
    Init()
    for _, fn in ipairs(refreshers) do fn() end
    tab:Show()
end)

------------------------------------------------------------
-- 設定搜尋（Options/Search.lua）
-- 列舉用的是 spec 表本身，不需要先把分頁建出來 —— 所以沒開過也搜得到
------------------------------------------------------------
ns.Search.Register("general", {
    label = L["General"],
    enumerate = function(add) add(CONTROLS, L["General"]) end,
    jump = function(_, spec)
        Init()
        ns.Search.Reveal(scroll, content, rows, spec)
    end,
})
