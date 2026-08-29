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
