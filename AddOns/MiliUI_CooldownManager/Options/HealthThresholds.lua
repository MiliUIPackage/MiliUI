------------------------------------------------------------
-- 資源條血量列的門檻編輯器（血量的設定視窗「顏色」那一段開的彈窗，Options/ResourceSettings.lua）
--
-- 一列一個門檻：血量百分比 ＋ 顏色。存進 profile.resources.healthThresholds，
-- 由 Modules/Resources.lua 的 R.HealthCurvePoints 組成 Step 曲線交給引擎求值。
-- 照套組單位框架的血量門檻編輯器改（同一套語意與版面）。
--
-- 為什麼開成獨立視窗而不是塞進設定視窗的一列：門檻數是可增減的，而設定視窗的表單
-- 是照形狀建一次就快取重用的（custom 那一列的高度在建立當下就固定了）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

ns.HealthThresholds = {}
local HT = ns.HealthThresholds

local POPUP_W, POPUP_H = 420, 360
local LIST_W, LIST_H   = 388, 230
local ROW_H            = 26

local popup, list, addBtn, onChanged

local DEFAULT_COLOR = { r = 0.8, g = 0.1, b = 0.1, a = 1 }

local function Cfg() return ns.DB.ConfigTable("resources") end

-- 分段再多也讀不出來，而且每一段都要一個曲線點（上限跟引擎同一個數）
local function MaxPoints()
    return (ns.Resources and ns.Resources.HEALTH_MAX_THRESHOLDS) or 6
end

local function Thresholds()
    local cfg = Cfg()
    if not cfg then return nil end
    if type(cfg.healthThresholds) ~= "table" then cfg.healthThresholds = {} end
    return cfg.healthThresholds
end

local function Apply()
    if ns.Resources and ns.Resources.Apply then ns.Resources.Apply() end
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
        table.remove(list_, row.index)
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
    local list_ = Thresholds() or {}
    list:Update(list_, UpdateRow)
    -- 滿了就停用「新增」（做不了的動作不給按）
    addBtn:SetEnabled(#list_ < MaxPoints())
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
    popup.title:SetText(L["Health thresholds"])

    local hint = popup:CreateFontString(nil, "OVERLAY")
    hint:SetFontObject(W.fontSmall)
    hint:SetPoint("TOPLEFT", 16, -34)
    hint:SetPoint("RIGHT", popup, "RIGHT", -16, 0)
    hint:SetJustifyH("LEFT")
    hint:SetSpacing(2)
    hint:SetText(L["Lower thresholds win: with 50% orange and 20% red, the bar is red below 20, orange between 20 and 50, and keeps its normal color above 50."])

    list = W.CreateRowList(popup, LIST_W, LIST_H, ROW_H, BuildRow)
    list:SetPoint("TOPLEFT", 16, -68)

    addBtn = W.CreateButton(popup, L["Add threshold"], "normal", 120, 22)
    -- 右邊到「確定」之間空著（彈窗 420 寬），長譯文撐開也碰不到它
    W.FitButton(addBtn, 120, 22)
    addBtn:SetPoint("BOTTOMLEFT", 16, 12)
    addBtn:SetScript("OnClick", function()
        local list_ = Thresholds()
        if not list_ or #list_ >= MaxPoints() then return end
        -- 新的放在最低門檻的一半，顏色先給預設紅，讓它一出現就看得到
        local lowest = list_[1] and list_[1].pct or 70
        local pct = math.max(1, math.floor(lowest / 2))
        table.insert(list_, { pct = pct, color = {
            r = DEFAULT_COLOR.r, g = DEFAULT_COLOR.g, b = DEFAULT_COLOR.b, a = 1 } })
        Apply()
        Refresh()
    end)

    local close = W.CreateButton(popup, L["Okay"], "primary", 100, 22)
    close:SetPoint("BOTTOMRIGHT", -16, 12)
    close:SetScript("OnClick", function() popup:Hide() end)
end

-- changedCallback：門檻增刪時叫（設定頁那顆按鈕的筆數跟著換）
function HT.Open(changedCallback)
    onChanged = changedCallback
    CreatePopup()
    if not popup then return end
    popup:Show()
    Refresh()
end

-- 開它的設定視窗收起來時一起收
function HT.Close()
    if popup then popup:Hide() end
end

function HT.Count()
    local cfg = Cfg()
    local list_ = cfg and cfg.healthThresholds
    return (type(list_) == "table") and #list_ or 0
end
