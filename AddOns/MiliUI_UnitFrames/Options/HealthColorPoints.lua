------------------------------------------------------------
-- 血量顏色點編輯器
--
-- 一列一個點：血量百分比 ＋ 顏色。存進 ns.db.global.healthColor.points，
-- 由 Core/Colors.lua 的 methods.healthcolor 組成顏色曲線交給引擎求值。
--
-- 為什麼開成獨立視窗而不是塞進「一般」分頁的一列：點數是可增減的，而分頁的表單
-- 是建一次就快取重用的（custom 那一列的高度在建立當下就固定了）。彈窗＋
-- W.CreateRowList 才有辦法長短自如。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

ns.HealthColorPoints = {}
local HCP = ns.HealthColorPoints

local POPUP_W, POPUP_H = 420, 380
local LIST_W, LIST_H   = 388, 250
local ROW_H            = 26
local MAX_POINTS       = 8     -- 再多也調不出人眼分得出來的差別，而且曲線只會更亂

local popup, list, onChanged

local function Points()
    local cfg = ns.db.global.healthColor
    if type(cfg) ~= "table" then
        cfg = { mode = "linear", points = {} }
        ns.db.global.healthColor = cfg
    end
    if type(cfg.points) ~= "table" then cfg.points = {} end
    return cfg.points
end

-- 全域顏色改了要讓每個框重畫（跟「一般」分頁其他控制項同一條路）
local function ApplyAll()
    for unitKey in pairs(ns.db.units) do
        if unitKey ~= "totem" then ns.ApplySettings(unitKey) end
    end
    if onChanged then onChanged() end
end

local function SortPoints()
    table.sort(Points(), function(a, b) return (a.pct or 0) < (b.pct or 0) end)
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
    row.label:SetText(L["At"])

    row.pct = W.CreateNumberBox(row, 52, 1, function(v)
        local p = Points()[row.index]
        if not p then return end
        if v < 0 then v = 0 elseif v > 100 then v = 100 end
        p.pct = v
        SortPoints()
        ApplyAll()
        Refresh()          -- 排序後這一列可能換位置了，整張重畫
    end)
    row.pct:SetPoint("LEFT", row.label, "RIGHT", 6, 0)

    row.pctSign = row:CreateFontString(nil, "OVERLAY")
    row.pctSign:SetFontObject(W.fontNormal)
    row.pctSign:SetPoint("LEFT", row.pct, "RIGHT", 4, 0)
    row.pctSign:SetText("%")

    row.swatch = W.CreateColorPicker(row, nil, false, function(r, g, b)
        local p = Points()[row.index]
        if not p then return end
        p.color = p.color or {}
        p.color.r, p.color.g, p.color.b, p.color.a = r, g, b, 1
        ApplyAll()
    end)
    row.swatch:SetPoint("LEFT", row.pctSign, "RIGHT", 12, 0)

    row.del = W.CreateButton(row, "X", "red", 20, 18)
    row.del:SetPoint("RIGHT", -8, 0)
    row.del:SetScript("OnClick", function()
        local pts = Points()
        -- 曲線至少要兩個點才有「漸層」可言，剩兩個就不讓再刪
        if #pts <= 2 or not row.index then return end
        tremove(pts, row.index)
        ApplyAll()
        Refresh()
    end)
end

local function UpdateRow(row, point, index)
    row.index = index
    row.pct:SetValue(point.pct or 0)
    row.swatch:SetColor(point.color or { r = 1, g = 1, b = 1, a = 1 })
    row.del:SetEnabled(#Points() > 2)
end

Refresh = function()
    if not (popup and popup:IsShown()) then return end
    SortPoints()
    list:Update(Points(), UpdateRow)
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

    local title = popup:CreateFontString(nil, "OVERLAY")
    title:SetFontObject(W.fontTitle)
    title:SetPoint("TOP", 0, -12)
    title:SetText(L["Health color points"])

    local hint = popup:CreateFontString(nil, "OVERLAY")
    hint:SetFontObject(W.fontSmall)
    hint:SetPoint("TOPLEFT", 16, -34)
    hint:SetPoint("RIGHT", popup, "RIGHT", -16, 0)
    hint:SetJustifyH("LEFT")
    hint:SetSpacing(2)
    hint:SetText(L["The bar takes the color of the point at that health, blending between points. The topmost point is full health."])

    list = W.CreateRowList(popup, LIST_W, LIST_H, ROW_H, BuildRow)
    list:SetPoint("TOPLEFT", 16, -62)

    local add = W.CreateButton(popup, L["Add point"], "accent", 110, 22)
    add:SetPoint("BOTTOMLEFT", 16, 12)
    add:SetScript("OnClick", function()
        local pts = Points()
        if #pts >= MAX_POINTS then return end
        -- 新點放在最後一個點與 100 之間的空隙，顏色沿用最後一個（先出現再讓人調）
        local last = pts[#pts]
        local pct = math.min(100, math.floor(((last and last.pct or 0) + 100) / 2))
        local c = (last and last.color) or { r = 1, g = 1, b = 1, a = 1 }
        tinsert(pts, { pct = pct, color = { r = c.r, g = c.g, b = c.b, a = 1 } })
        ApplyAll()
        Refresh()
    end)

    local reset = W.CreateButton(popup, L["Restore defaults"], "normal", 110, 22)
    reset:SetPoint("LEFT", add, "RIGHT", 8, 0)
    reset:SetScript("OnClick", function()
        ns.db.global.healthColor.points = {
            { pct = 0,   color = { r = 0.5, g = 0,   b = 0, a = 1 } },
            { pct = 50,  color = { r = 0.5, g = 0.5, b = 0, a = 1 } },
            { pct = 100, color = { r = 0,   g = 0.5, b = 0, a = 1 } },
        }
        ApplyAll()
        Refresh()
    end)

    local close = W.CreateButton(popup, L["Okay"], "accent", 100, 22)
    close:SetPoint("BOTTOMRIGHT", -16, 12)
    close:SetScript("OnClick", function() popup:Hide() end)
end

function HCP.Open(changedCallback)
    onChanged = changedCallback
    CreatePopup()
    if not popup then return end
    popup:Show()
    Refresh()
end

function HCP.Count()
    return #Points()
end
