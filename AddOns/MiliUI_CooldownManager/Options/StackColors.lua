------------------------------------------------------------
-- 增益長條的「層數換色」編輯器（逐法術面板那顆「層數換色（N）…」開的彈窗）
--
--   ns.StackColors.Open(barKey, cooldownID, changedCallback)
--   ns.StackColors.Count(barKey, cooldownID)
--
-- 一列一段：「層數 ≥ N」＋色票＋刪除，最多 3 段（ns.StackGate.MAX_COLORS），＋新增。
-- 存成逐法術覆寫 overrides[id].stackColors = { { at, color }, … }（寫入前一律過 StackGate.CleanColors：
-- 由低到高排、去重、上限 3）；刪光了清掉覆寫（SPELL_CONST 的 false ＝ 關）。
-- 引擎那一側（閘＋裁切框＋色塊）在 Core/StackGate.lua。照 Options/HealthThresholds.lua 的版面做。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

ns.StackColors = {}
local SC = ns.StackColors

local POPUP_W = 380
local LIST_W  = 348
local ROW_H   = 26
local PAD     = 16

local DEFAULT_COLOR = { r = 1, g = 0.5, b = 0, a = 1 }

local popup, list, addBtn, hint
local cur                      -- { key, id, onChanged }

local function SG() return ns.StackGate end

-- 目前的清單（清洗過的新表，可以直接改）
local function Current(key, id)
    local v = ns.SpellSetting(key, id, "stackColors")
    return SG().CleanColors(v) or {}
end

local function Save(items)
    if not cur then return end
    local clean = SG().CleanColors(items)
    ns.DB.SetOverride(cur.id, "stackColors", clean)      -- nil（刪光）＝ 清掉覆寫
    if cur.onChanged then cur.onChanged() end
end

local Refresh   -- 前向宣告

------------------------------------------------------------
-- 一列：「層數 ≥」＋數字框＋色票＋刪除
-- ⚠ 列會回收再用：handler 一律讀 row.index（Update 時才填），不把索引抓進 closure
------------------------------------------------------------
local function BuildRow(row)
    row.label = row:CreateFontString(nil, "OVERLAY")
    row.label:SetFontObject(W.fontNormal)
    row.label:SetPoint("LEFT", 8, 0)
    row.label:SetText(L["Stacks ≥"])

    row.num = W.CreateNumberBox(row, 44, 1, function(v)
        if not cur then return end
        local items = Current(cur.key, cur.id)
        local e = items[row.index]
        if not e then return end
        local n = SG().Threshold(v) or 1
        -- 跟別一段同門檻：不收（清洗會把其中一段丟掉，看起來像資料不見）
        for i, o in ipairs(items) do
            if i ~= row.index and o.at == n then Refresh() return end
        end
        e.at = n
        Save(items)
        Refresh()          -- 排序後這一列可能換位置了，整張重畫
    end)
    row.num:SetPoint("LEFT", row.label, "RIGHT", 6, 0)

    row.swatch = W.CreateColorPicker(row, nil, true, function(r, g, b, a)
        if not cur then return end
        local items = Current(cur.key, cur.id)
        local e = items[row.index]
        if not e then return end
        e.color = { r = r, g = g, b = b, a = a or 1 }
        Save(items)
    end)
    row.swatch:SetPoint("LEFT", row.num, "RIGHT", 12, 0)

    row.del = W.CreateButton(row, "X", "red", 20, 18)
    row.del:SetPoint("RIGHT", -8, 0)
    row.del:SetScript("OnClick", function()
        if not (cur and row.index) then return end
        local items = Current(cur.key, cur.id)
        table.remove(items, row.index)
        Save(items)
        Refresh()
    end)
end

local function UpdateRow(row, e, index)
    row.index = index
    row.num:SetValue(e.at or 1)
    row.swatch:SetColor(e.color or DEFAULT_COLOR)
end

Refresh = function()
    if not (popup and popup:IsShown() and cur) then return end
    local items = Current(cur.key, cur.id)
    list:Update(items, UpdateRow)
    -- 滿了就停用「新增」（做不了的動作不給按）
    addBtn:SetEnabled(#items < SG().MAX_COLORS)
end

------------------------------------------------------------
-- 視窗
------------------------------------------------------------
local function CreatePopup()
    if popup then return end
    local parent = ns.Options and ns.Options.panel
    if not parent then return end

    popup = W.CreateFrame(nil, parent, POPUP_W, 220)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(410)
    popup:SetBackdropBorderColor(W.Accent(1))
    popup:SetPoint("CENTER")
    popup:Hide()
    W.CloseOnEscape(popup)

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
    popup.title:SetText(L["Stack colors"])

    hint = popup:CreateFontString(nil, "OVERLAY")
    hint:SetFontObject(W.fontSmall)
    hint:SetTextColor(0.6, 0.6, 0.6)
    hint:SetPoint("TOPLEFT", PAD, -34)
    hint:SetWidth(POPUP_W - PAD * 2)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)
    hint:SetSpacing(2)
    hint:SetText(L["The bar takes the color of the highest stack count the buff has reached, and keeps its normal color below all of them. Up to 3."])

    list = W.CreateRowList(popup, LIST_W, ROW_H * SG().MAX_COLORS + 4, ROW_H, BuildRow)

    addBtn = W.CreateButton(popup, L["Add threshold"], "normal", 120, 22)
    W.FitButton(addBtn, 120, 22)
    addBtn:SetPoint("BOTTOMLEFT", PAD, 12)
    addBtn:SetScript("OnClick", function()
        if not cur then return end
        local items = Current(cur.key, cur.id)
        if #items >= SG().MAX_COLORS then return end
        -- 新的一段：比目前最高的多 1（沒有就從預設門檻開始），顏色先給橘色，一出現就看得到
        local last = items[#items]
        local at = last and math.min(SG().MAX_STACK, last.at + 1) or SG().DEFAULT_THRESHOLD
        for _, o in ipairs(items) do
            if o.at == at then return end                  -- 已經頂到 99
        end
        items[#items + 1] = { at = at, color = {
            r = DEFAULT_COLOR.r, g = DEFAULT_COLOR.g, b = DEFAULT_COLOR.b, a = 1 } }
        Save(items)
        Refresh()
    end)

    local close = W.CreateButton(popup, L["Okay"], "primary", 100, 22)
    close:SetPoint("BOTTOMRIGHT", -PAD, 12)
    close:SetScript("OnClick", function() popup:Hide() end)

    ns.RegisterCallback("OptionsHidden", "stackcolors", function() popup:Hide() end)
    ns.RegisterCallback("SpecChanged", "stackcolors", function() popup:Hide() end)
    ns.RegisterCallback("ProfileChanged", "stackcolors", function() popup:Hide() end)
end

-- 說明字換行後的高度量得到時（顯示之後）才排清單與視窗高度
local function Relayout()
    local hh = hint:GetStringHeight()
    hh = (type(hh) == "number" and hh > 0) and hh or 28
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", PAD, -34 - hh - 10)
    ns.P.Height(popup, 34 + hh + 10 + ROW_H * SG().MAX_COLORS + 4 + 12 + 22 + 12)
end

-- changedCallback：增刪改時叫（逐法術面板那顆按鈕的筆數、預覽、引擎跟著換）
function SC.Open(key, id, changedCallback)
    if id == nil then return end
    CreatePopup()
    if not popup then return end
    cur = { key = key, id = id, onChanged = changedCallback }
    popup:Show()
    Relayout()
    Refresh()
end

function SC.Close()
    if popup then popup:Hide() end
end

function SC.Count(key, id)
    local c = SG().CleanColors(ns.SpellSetting(key, id, "stackColors"))
    return c and #c or 0
end
