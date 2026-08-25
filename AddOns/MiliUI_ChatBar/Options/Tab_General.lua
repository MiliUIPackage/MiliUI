------------------------------------------------------------
-- 「一般」分頁：鎖定、跟聊天視窗同組、排列方向、字級與按鈕尺寸、
--               自適應寬度、開怪倒數秒數、重置
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

local tab, scroll, refreshers
local resetAllPopup

local function RefreshAll()
    if not refreshers then return end
    ns.InitDB()   -- 自畫的那兩列會直接讀 DB 判斷該不該變灰，先保證表在
    for _, fn in ipairs(refreshers) do fn() end
end

-- 每一格的副作用都是「讀 DB 現值再重套」，重複呼叫無害 ⇒ 不分辨改的是哪一格，
-- 整組重套一次就好
local function Apply()
    ns.InitDB()
    ns.UpdateMoverState()      -- 鎖定
    if ns.Anchor then          -- 跟聊天視窗同組
        ns.Anchor.OnSettingsChanged()
    end
    ns.UpdateFontSize()        -- 字級
    ns.UpdateButtonSize()      -- 按鈕寬高（順帶重排，自適應寬度也是在重排時算的）
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

------------------------------------------------------------
-- 可以變灰停用的一列
--
-- 共用層（Libs/MiliUIWidgets/Controls.lua）沒有「停用」這個概念，而那包是逐字
-- 複製到七個插件的 vendor —— 為了這裡兩條規則去動它等於七個插件一起改。
-- 只有這支用得到的東西照 README 的規矩走 custom spec：自己畫標籤、自己變灰。
--
-- 停用＝**灰**（看得到值但知道現在不是自己在管）＋ **關掉滑鼠**（點不動）。
-- 只變灰不關滑鼠是最糟的一種：看起來停用、拉下去卻真的會改到 DB。
------------------------------------------------------------
local LABEL_W = (ns.WidgetsEnv and ns.WidgetsEnv.LABEL_W) or 128
local LABEL_GAP = 12
local CONTROL_W = 230
local ROW_H, ROW_H_TALL = 26, 30

local function CustomLabel(parent, text, cx, y, h)
    -- 座標跟共用層的 MakeLabel 對齊：控件欄左緣 cx 往回推一個標籤欄＋間距
    local x0 = cx - LABEL_W - LABEL_GAP
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontNormal)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x0, y)
    fs:SetPoint("TOPRIGHT", parent, "TOPLEFT", x0 + LABEL_W, y)
    fs:SetHeight(h)
    fs:SetJustifyH("RIGHT")
    fs:SetJustifyV("MIDDLE")
    fs:SetWordWrap(true)
    fs:SetText(text or "")
    return fs
end

local function Dim(on, label, ...)
    local a = on and 1 or 0.35
    label:SetAlpha(a)
    for i = 1, select("#", ...) do
        select(i, ...):SetAlpha(a)
    end
end

-- 按鈕寬度：勾了「按鈕寬度自適應」就由程式算，這條變灰不能動
local ButtonWidthRow = {
    type = "custom", h = ROW_H_TALL,
    build = function(parent, cx, y, _, ctx)
        local spec = { key = "ButtonWidth" }
        local label = CustomLabel(parent, L["BUTTON_WIDTH"], cx, y, ROW_H_TALL)
        local s = W.CreateSlider(parent, 10, 60, CONTROL_W, 1, nil, function(v)
            ctx.set(spec, v)
            ctx.apply()
        end)
        s:SetPoint("LEFT", parent, "TOPLEFT", cx, y - ROW_H_TALL / 2)
        return ROW_H_TALL, function()
            s:SetValue(tonumber(ctx.get(spec)) or 25)
            local cb = MiliUI_ChatBar_DB.Chatbar
            local auto = cb.MatchChatWidth and cb.AutoButtonWidth
            Dim(not auto, label, s)
            s.slider:EnableMouse(not auto)
            s.editBox:EnableMouse(not auto)
            if auto then s.editBox:ClearFocus() end
        end
    end,
}

-- 按鈕寬度自適應：沒開「總寬度對齊聊天視窗」就沒有總寬度可分，這條變灰
local AutoButtonWidthRow = {
    type = "custom", h = ROW_H,
    build = function(parent, cx, y, _, ctx)
        local spec = { key = "AutoButtonWidth" }
        local label = CustomLabel(parent, L["AUTO_BUTTON_WIDTH"], cx, y, ROW_H)
        local box = W.CreateCheckButton(parent, nil, function(checked)
            ctx.set(spec, checked)
            ctx.apply()
        end)
        box:SetPoint("LEFT", parent, "TOPLEFT", cx, y - ROW_H / 2)
        return ROW_H, function()
            box:SetChecked(ctx.get(spec) and true or false)
            local on = MiliUI_ChatBar_DB.Chatbar.MatchChatWidth and true or false
            Dim(on, label, box)
            box:SetEnabled(on)
        end
    end,
}

local CONTROLS = {
    { type = "header", label = L["GENERAL_SETTINGS_TITLE"] },
    { type = "toggle", key = "Locked", label = L["LOCK_UNLOCK"] },
    { type = "text",   label = L["LOCK_UNLOCK_DESC"] },
    { type = "toggle", key = "GroupWithChat", label = L["GROUP_WITH_CHAT"] },
    { type = "text",   label = L["GROUP_WITH_CHAT_DESC"] },
    { type = "dropdown", key = "Orientation", label = L["ORIENTATION"], items = OrientationItems },

    { type = "header", label = L["SECTION_SIZE"] },
    { type = "slider", key = "FontSize",     label = L["FONT_SIZE"],     min = 6,  max = 24, step = 1 },
    ButtonWidthRow,
    { type = "slider", key = "ButtonHeight", label = L["BUTTON_HEIGHT"], min = 4,  max = 30, step = 1 },
    { type = "toggle", key = "MatchChatWidth", label = L["MATCH_CHAT_WIDTH"] },
    { type = "text",   label = L["MATCH_CHAT_WIDTH_DESC"] },
    AutoButtonWidthRow,
    { type = "text",   label = L["AUTO_BUTTON_WIDTH_DESC"] },

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

-- 聊天列的右鍵選單也會改鎖定／同組／方向，設定頁開著的話跟著更新
ns.RegisterCallback("SettingsChanged", "generalTab", function()
    if tab and tab:IsVisible() then RefreshAll() end
end)
