------------------------------------------------------------
-- 「一般」分頁：開關、尺寸、位置
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

local CONTROLS = {
    { type = "header", label = L["SECTION_GENERAL"] },
    { type = "toggle", key = "enabled", label = L["ENABLE_BAR"] },
    { type = "text",   label = L["ENABLE_BAR_DESC"] },
    { type = "slider", key = "height",   label = L["BAR_HEIGHT"], min = 20, max = 36, step = 1 },
    { type = "slider", key = "fontSize", label = L["FONT_SIZE"],  min = 9,  max = 16, step = 1 },
    { type = "slider", key = "blockGap", label = L["BLOCK_GAP"],  min = 0,  max = 12, step = 1 },
    { type = "text",   label = L["BLOCK_GAP_DESC"] },

    { type = "header", label = L["SECTION_COLORS"] },
    -- 「配色」不是 DB 欄位，是從 bgColor/edgeColor 回推的（見 Init 的 ctx）
    { type = "dropdown", key = "colorPreset", label = L["COLOR_PRESET"], items = {
        { value = "pack",   text = L["COLOR_PRESET_PACK"] },
        { value = "solid",  text = L["COLOR_PRESET_SOLID"] },
        { value = "custom", text = L["COLOR_PRESET_CUSTOM"] },
    } },
    { type = "text",   label = L["COLOR_PRESET_DESC"] },
    { type = "color",  key = "bgColor",   label = L["BG_COLOR"],   hasAlpha = true },
    { type = "color",  key = "edgeColor", label = L["EDGE_COLOR"], hasAlpha = true },
    { type = "text",   label = L["COLORS_DESC"] },
    { type = "dropdown", key = "textColorMode", label = L["TEXT_COLOR_MODE"], items = {
        { value = "custom", text = L["TEXT_COLOR_CUSTOM"] },
        { value = "class",  text = L["TEXT_COLOR_CLASS"] },
    } },
    { type = "color",  key = "textColor", label = L["TEXT_COLOR"], hasAlpha = false },
    { type = "text",   label = L["TEXT_COLOR_DESC"] },

    { type = "header", label = L["SECTION_POSITION"] },
    { type = "text",   label = L["DRAG_HINT"] },
    { type = "button", label = "", text = L["RESET_POSITION"], width = 150,
      onClick = function()
          local db = ns.GetDB()
          -- nil = 回到「跟隨官方微型選單那排」的預設（見 Core/Bar.lua DefaultPosition）
          db.x, db.y = nil, nil
          ns.ApplyAll()
          print(ns.PREFIX_COLOR .. L["ADDON_NAME"] .. "|r " .. L["MSG_POSITION_RESET"])
      end },
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["TAB_GENERAL"])
    local ctx = ns.Controls.MakeCtx(function() return ns.GetDB() end, Apply)

    -- 「配色」是虛擬欄位：讀＝拿現在的顏色回頭比對，寫＝把那組 preset 的顏色
    -- 蓋進 bgColor/edgeColor。所以手動調過色票之後，下拉會自己變成「自訂」，
    -- 不需要另外記一個會跟顏色脫節的狀態欄位。
    local baseGet, baseSet = ctx.get, ctx.set
    ctx.get = function(spec)
        if spec.key == "colorPreset" then return ns.CurrentColorPreset() end
        return baseGet(spec)
    end
    ctx.set = function(spec, v)
        if spec.key == "colorPreset" then
            -- 選「自訂」是 no-op：它是狀態的描述，不是一組要套用的顏色
            if v ~= "custom" then ns.ApplyColorPreset(v) end
            return
        end
        baseSet(spec, v)
    end

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
