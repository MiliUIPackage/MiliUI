------------------------------------------------------------
-- 「施法條」分頁：專注目標施法監控、三態顏色、重要法術發光、唱法音效、斷法巨集
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W
local Specs = ns.Specs

local tab, scroll, refreshers

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

local function Apply()
    local cast = ns.db.cast
    -- 開了音效卻沒選過 → 給第一個內建音，否則勾了沒聲音
    if cast.soundEnabled and cast.sound == nil then
        cast.sound = Specs.SOUND_BUILTINS[1].value
    end
    ns.CastBar.Apply()
    RefreshAll()
end

------------------------------------------------------------
-- 斷法巨集（唯讀 + 全選讓玩家 Ctrl+C）
-- 斷法技能會隨專精／天賦變，所以文字每次刷新重新問一次，不烘死在建立那一刻
------------------------------------------------------------
local function BuildMacroRow(parent, x, y, width)
    local function MacroText()
        local spell = ns.CastBar.GetInterruptSpellName() or L["Spell name"]
        return "#showtooltip\n/cast [@focus,exists][@target] " .. spell
    end

    local box = W.CreateCopyBox(parent, math.min(width, 360), 44, MacroText, L["Select all"])
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 4)

    return box.totalHeight + 10, function() box:Refresh() end
end

-- 冷卻管理器接手了：黃字一行（W.fontEmphasis），沒接手時留空（表單是靜態的，列高不變）
local function BuildTakenOverRow(parent, x, y, width)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontEmphasis)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 2)
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    local function Refresh()
        fs:SetText(ns.CastBar.TakenOver() and L["MiliUI Cooldown Manager's focus cast bar is on, so this bar steps aside. Turn that one off to use this one."] or "")
    end
    Refresh()
    return 30, Refresh
end

local CONTROLS = {
    { type = "header", label = L["Focus cast bar"] },
    { type = "toggle", key = "monitor", label = L["Enable the focus cast bar"] },
    { type = "custom", label = "", build = BuildTakenOverRow },
    { type = "text",   label = L["Shows what your focus is casting and colors the bar by whether you can interrupt it. Drag it in Edit Mode."] },
    { type = "numbers", label = L["Size"], fields = {
        { key = "width",  label = L["W"] },
        { key = "height", label = L["H"] },
    } },
    { type = "numbers", label = L["Position"], fields = {
        { key = "x", label = "X" },
        { key = "y", label = "Y" },
    } },
    { type = "toggle", key = "showTarget", label = L["Show who the spell is aimed at"] },
    { type = "text",   label = L["The spell's target sits under the bar's right edge, smaller than the spell name, in the target's class color."] },
    { type = "toggle", key = "targetClassColor", label = L["Color the target's name by class"] },
    { type = "numbers", label = L["Target offset"], fields = {
        { key = "targetX", label = "X" },
        { key = "targetY", label = "Y" },
    } },

    { type = "header", label = L["Bar colors"] },
    { type = "color", key = "colorReady",  label = L["Interruptible (kick ready)"],   hasAlpha = false },
    { type = "color", key = "colorCD",     label = L["Interruptible (kick on CD)"],   hasAlpha = false },
    { type = "color", key = "colorImmune", label = L["Not interruptible"],            hasAlpha = false },
    { type = "button", label = "", text = L["Restore default colors"],
      onClick = function()
          local d = ns.DB.DEFAULT_COLORS
          ns.db.cast.colorReady  = CopyTable(d.ready)
          ns.db.cast.colorCD     = CopyTable(d.cd)
          ns.db.cast.colorImmune = CopyTable(d.immune)
          ns.CastBar.Apply()   -- 編輯模式的範例條用 ready 色，要立刻看得到
      end },

    { type = "header", label = L["Important spells"] },
    { type = "toggle", key = "glowImportant", label = L["Glow when the focus casts an important spell"] },
    { type = "toggle", key = "bangImportant", label = L["Add \"!\" before important spell names"] },
    { type = "text",   label = L["Blizzard decides which spells count as important."] },
    { type = "dropdown", key = "glowStyle", label = L["Glow style"], items = function() return {
          { text = L["Pixel lines (bar border)"],     value = "pixel" },
          { text = L["Autocast sparkles (bar border)"], value = "autocast" },
          { text = L["Proc glow (icon)"],             value = "proc" },
      } end },
    { type = "color",  key = "colorGlow", label = L["Glow color"], hasAlpha = false },

    { type = "header", label = L["Cast sound"] },
    { type = "toggle", key = "soundEnabled", label = L["Play a sound when the focus starts casting"] },
    { type = "text",   label = L["Independent of the cast bar. Since 12.1 the sound can't depend on whether the cast is interruptible or important (Blizzard made both secret values) — watch the bar color and glow instead."] },
    { type = "dropdown", key = "sound", label = L["Sound"], items = function() return Specs.SoundItems() end },
    { type = "button", label = "", text = L["Preview"], width = 80,
      onClick = function() ns.CastBar.PreviewSound() end },

    { type = "header", label = L["Interrupt macro"] },
    { type = "text",   label = L["Casts your interrupt on the focus, or on your current target if you have no focus. Click \"Select all\", press Ctrl+C, paste into a new macro."] },
    { type = "custom", label = L["Macro"], build = BuildMacroRow },
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["Cast bar"])
    local ctx = ns.Controls.MakeCtx(function() return ns.db.cast end, Apply)
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx)
end

-- 在編輯模式拖曳施法條會改到 x / y，設定頁開著的話跟著更新
ns.RegisterCallback("SettingsChanged", "castTab", function()
    if tab and tab:IsShown() then RefreshAll() end
end)

ns.RegisterCallback("ShowOptionsTab", "castTab", function(id)
    if id ~= "cast" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)
