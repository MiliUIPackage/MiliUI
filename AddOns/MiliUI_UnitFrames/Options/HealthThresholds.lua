------------------------------------------------------------
-- 血量門檻編輯器（每個單位的血條各一組）
--
-- 一列一個門檻：血量百分比 ＋ 顏色。存進 udb.elements.hpbar.thresholds，
-- 由 Core/Colors.lua 的 Colors.Threshold 組成 Step 曲線交給引擎求值。
--
-- 為什麼開成獨立視窗而不是塞進單位分頁的一列：門檻數是可增減的，而分頁的表單
-- 是建一次就快取重用的（custom 那一列的高度在建立當下就固定了）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

ns.HealthThresholds = {}
local HT = ns.HealthThresholds

local POPUP_W, POPUP_H = 420, 360
local LIST_W, LIST_H   = 388, 230
local ROW_H            = 26
local MAX_POINTS       = 6     -- 分段再多也讀不出來，而且每一段都要一個曲線點

local popup, list, onChanged
local ctxUnitKey

local DEFAULT_COLOR = { r = 0.8, g = 0.1, b = 0.1, a = 1 }

local function EDB()
    if not ctxUnitKey then return nil end
    local udb = ns.GetUnitDB(ctxUnitKey)
    return udb and udb.elements and udb.elements.hpbar
end

-- 預設沒有這一格，第一次用才長出來（所以「恢復預設」會順便清空）
local function Thresholds()
    local edb = EDB()
    if not edb then return nil end
    if type(edb.thresholds) ~= "table" then edb.thresholds = {} end
    return edb.thresholds
end

local function Apply()
    if ctxUnitKey then ns.ApplySettings(ctxUnitKey) end
    if onChanged then onChanged() end
end

local function Sort()
    local list_ = Thresholds()
    if list_ then table.sort(list_, function(a, b) return (a.pct or 0) < (b.pct or 0) end) end
end

local Refresh   -- 前向宣告

------------------------------------------------------------
-- 一列：百分比數字框 ＋ 色票 ＋ 刪除
--
-- ⚠ 列會回收再用，所以 handler 一律讀 row.index（更新時才填），
-- 不要在這裡把索引抓進 closure —— 那樣刪掉一列之後就會動到別一列。
------------------------------------------------------------
local function BuildRow(row)
    row.label = row:CreateFontString(nil, "OVERLAY")
    row.label:SetFontObject(W.fontNormal)
    row.label:SetPoint("LEFT", 8, 0)
    row.label:SetText(L["Below"])

    row.pct = W.CreateNumberBox(row, 52, 5, function(v)
        local list_ = Thresholds()
        local t = list_ and list_[row.index]
        if not t then return end
        if v < 1 then v = 1 elseif v > 99 then v = 99 end
        t.pct = v
        Sort()
        Apply()
        Refresh()          -- 排序後這一列可能換位置了，整張重畫
    end)
    row.pct:SetPoint("LEFT", row.label, "RIGHT", 6, 0)

    row.pctSign = row:CreateFontString(nil, "OVERLAY")
    row.pctSign:SetFontObject(W.fontNormal)
    row.pctSign:SetPoint("LEFT", row.pct, "RIGHT", 4, 0)
    row.pctSign:SetText("%")

    row.swatch = W.CreateColorPicker(row, nil, false, function(r, g, b)
        local list_ = Thresholds()
        local t = list_ and list_[row.index]
        if not t then return end
        t.color = t.color or {}
        t.color.r, t.color.g, t.color.b, t.color.a = r, g, b, 1
        Apply()
    end)
    row.swatch:SetPoint("LEFT", row.pctSign, "RIGHT", 12, 0)

    row.del = W.CreateButton(row, "X", "red", 20, 18)
    row.del:SetPoint("RIGHT", -8, 0)
    row.del:SetScript("OnClick", function()
        local list_ = Thresholds()
        if not (list_ and row.index) then return end
        tremove(list_, row.index)
        Apply()
        Refresh()
    end)
end

local function UpdateRow(row, t, index)
    row.index = index
    row.pct:SetValue(t.pct or 0)
    row.swatch:SetColor(t.color or DEFAULT_COLOR)
end

Refresh = function()
    if not (popup and popup:IsShown()) then return end
    Sort()
    list:Update(Thresholds() or {}, UpdateRow)
end

------------------------------------------------------------
-- 視窗
------------------------------------------------------------
local function CreatePopup()
    if popup then return end
    local parent = ns.Options and ns.Options.panel
    if not parent then return end

    popup = W.CreateFrame(nil, parent, POPUP_W, POPUP_H)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(410)
    popup:SetBackdropBorderColor(W.Accent(1))
    popup:SetPoint("CENTER")
    popup:Hide()

    local mask = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    mask:SetAllPoints(parent)
    mask:SetFrameStrata("FULLSCREEN_DIALOG")
    mask:SetFrameLevel(400)
    mask:EnableMouse(true)
    mask:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8" })
    mask:SetBackdropColor(0.15, 0.15, 0.15, 0.7)
    mask:Hide()
    popup:SetScript("OnShow", function() mask:Show() end)
    popup:SetScript("OnHide", function() mask:Hide() end)

    popup.title = popup:CreateFontString(nil, "OVERLAY")
    popup.title:SetFontObject(W.fontTitle)
    popup.title:SetPoint("TOP", 0, -12)

    local hint = popup:CreateFontString(nil, "OVERLAY")
    hint:SetFontObject(W.fontSmall)
    hint:SetPoint("TOPLEFT", 16, -34)
    hint:SetPoint("RIGHT", popup, "RIGHT", -16, 0)
    hint:SetJustifyH("LEFT")
    hint:SetSpacing(2)
    hint:SetText(L["Lower thresholds win: with 50% orange and 20% red, the bar is red below 20, orange between 20 and 50, and keeps its normal color above 50."])

    list = W.CreateRowList(popup, LIST_W, LIST_H, ROW_H, BuildRow)
    list:SetPoint("TOPLEFT", 16, -68)

    local add = W.CreateButton(popup, L["Add threshold"], "accent", 120, 22)
    add:SetPoint("BOTTOMLEFT", 16, 12)
    add:SetScript("OnClick", function()
        local list_ = Thresholds()
        if not list_ or #list_ >= MAX_POINTS then return end
        -- 新的放在最低門檻的一半，顏色先給預設紅，讓它一出現就看得到
        local lowest = list_[1] and list_[1].pct or 70
        local pct = math.max(1, math.floor(lowest / 2))
        tinsert(list_, { pct = pct, color = {
            r = DEFAULT_COLOR.r, g = DEFAULT_COLOR.g, b = DEFAULT_COLOR.b, a = 1 } })
        Apply()
        Refresh()
    end)

    local close = W.CreateButton(popup, L["Okay"], "accent", 100, 22)
    close:SetPoint("BOTTOMRIGHT", -16, 12)
    close:SetScript("OnClick", function() popup:Hide() end)
end

function HT.Open(unitKey, changedCallback)
    ctxUnitKey, onChanged = unitKey, changedCallback
    CreatePopup()
    if not popup then return end
    popup.title:SetText(("%s — %s"):format(
        L["Health thresholds"], ns.UNIT_LABELS[unitKey] or unitKey))
    popup:Show()
    Refresh()
end

function HT.Count(unitKey)
    local udb = ns.GetUnitDB(unitKey)
    local edb = udb and udb.elements and udb.elements.hpbar
    local list_ = edb and edb.thresholds
    return (type(list_) == "table") and #list_ or 0
end
