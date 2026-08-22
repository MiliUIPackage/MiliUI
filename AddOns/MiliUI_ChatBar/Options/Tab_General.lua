------------------------------------------------------------
-- 「一般」分頁：鎖定、排列方向、字級與按鈕尺寸、開怪倒數秒數、重置
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

local tab, scroll, refreshers
local resetAllPopup

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

-- 每一格的副作用都是「讀 DB 現值再重套」，重複呼叫無害 ⇒ 不分辨改的是哪一格，
-- 整組重套一次就好
local function Apply()
    ns.InitDB()
    ns.UpdateMoverState()      -- 鎖定
    ns.UpdateFontSize()        -- 字級
    ns.UpdateButtonSize()      -- 按鈕寬高
    ns.UpdateLayout()          -- 排列方向
    ns.UpdateDBMButton()       -- 開怪倒數秒數（巨集內文與工具提示）
    RefreshAll()
end

local function OrientationItems()
    return {
        { text = L["ORIENT_HORIZONTAL"], value = "HORIZONTAL" },
        { text = L["ORIENT_VERTICAL"],   value = "VERTICAL" },
    }
end

local CONTROLS = {
    { type = "header", label = L["GENERAL_SETTINGS_TITLE"] },
    { type = "toggle", key = "Locked", label = L["LOCK_UNLOCK"] },
    { type = "text",   label = L["LOCK_UNLOCK_DESC"] },
    { type = "dropdown", key = "Orientation", label = L["ORIENTATION"], items = OrientationItems },

    { type = "header", label = L["SECTION_SIZE"] },
    { type = "slider", key = "FontSize",     label = L["FONT_SIZE"],     min = 6,  max = 24, step = 1 },
    { type = "slider", key = "ButtonWidth",  label = L["BUTTON_WIDTH"],  min = 10, max = 60, step = 1 },
    { type = "slider", key = "ButtonHeight", label = L["BUTTON_HEIGHT"], min = 4,  max = 30, step = 1 },

    { type = "header", label = L["CHANNEL_DBM"] },
    { type = "slider", key = "DBMPullSeconds", label = L["DBM_PULL_SECONDS"], min = 1, max = 30, step = 1 },
    { type = "text",   label = L["DBM_PULL_SECONDS_DESC"] },

    { type = "header", label = L["SECTION_RESET"] },
    { type = "button", label = "", text = L["RESET_POSITION"], width = 160,
      onClick = function() ns.ResetPosition() end },
    { type = "text",   label = L["RESET_POSITION_DESC"] },
    { type = "button", label = "", text = L["RESET_ALL"], color = "red", width = 160,
      onClick = function()
          -- 確認彈窗自己開：spec 的 confirm 會在按下確定後跑 refreshers，
          -- 而這一條的結局是 ReloadUI，refreshers 沒有意義
          if not resetAllPopup then
              resetAllPopup = W.CreateConfirmPopup(ns.Options.panel, 340,
                  L["CONFIRM_RESET_ALL"], function() ns.ResetAll() end)
          end
          resetAllPopup:Show()
      end },
    { type = "text",   label = L["RESET_ALL_DESC"] },
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["GENERAL_SETTINGS_TITLE"])
    local ctx = ns.Controls.MakeCtx(function()
        ns.InitDB()
        return MiliUI_ChatBar_DB.Chatbar
    end, Apply)
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

-- 聊天列的右鍵選單也會改鎖定／方向，設定頁開著的話跟著更新
ns.RegisterCallback("SettingsChanged", "generalTab", function()
    if tab and tab:IsVisible() then RefreshAll() end
end)
