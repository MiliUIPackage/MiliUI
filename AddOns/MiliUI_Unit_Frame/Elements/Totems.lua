------------------------------------------------------------
-- 圖騰框架（獨立框，樣式 A「圖示膠囊列」；樣式欄位保留切換空間）
--
-- 12.1：GetTotemInfo 回傳全秘密，只有 icon 是明文字串 →
--   icon 當「有圖騰」的 proxy；剩時用 pcall 抽 start+duration-GetTime()
--   （抽不到就滿條顯示）—— Stuf/bars.lua:1051-1070 的驗證解法
------------------------------------------------------------
local _, ns = ...

local Media = ns.Media
local CLASS = ns.playerClass

if not (CLASS == "SHAMAN" or CLASS == "DRUID" or CLASS == "DEATHKNIGHT" or CLASS == "PALADIN") then
    return
end

local NUM_SLOTS = MAX_TOTEMS or 4

-- 實際欄位：1=火 2=土 3=水 4=風（現代化元素色）
local ELEMENT_COLORS = {
    [1] = { r = 1, g = 0.42, b = 0.29 },     -- 火 #ff6b4a
    [2] = { r = 0.85, g = 0.70, b = 0.39 },  -- 土 #d8b263
    [3] = { r = 0.29, g = 0.76, b = 1 },     -- 水 #4ac3ff
    [4] = { r = 0.73, g = 0.66, b = 1 },     -- 風 #b9a8ff
}

local frame          -- MiliUIUF_Totem
local slots = {}     -- [i] = { btn, icon, bar, text, active, start, dur }
local ticker

local function GetDB()
    return ns.db.units.totem
end

local function SlotColor(i)
    local db = GetDB()
    if db.colors == "element" then
        return ELEMENT_COLORS[i] or ELEMENT_COLORS[1]
    end
    return RAID_CLASS_COLORS[CLASS] or { r = 0.7, g = 0.7, b = 0.7 }
end

local function CreateSlot(i)
    local db = GetDB()
    local size = db.frame.iconSize or 28

    local btn = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    btn:SetSize(size, size)
    Media.ApplyBorder(btn, nil, 1)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1 + 3)   -- 底部留 3px 給剩時條
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local barBG = btn:CreateTexture(nil, "BACKGROUND")
    barBG:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 1, 1)
    barBG:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    barBG:SetHeight(3)
    barBG:SetTexture(Media.WHITE8X8)
    barBG:SetVertexColor(0, 0, 0, 0.6)

    local bar = CreateFrame("StatusBar", nil, btn)
    bar:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 1, 1)
    bar:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    bar:SetHeight(3)
    bar:SetStatusBarTexture(Media.WHITE8X8)
    bar:SetFrameLevel(btn:GetFrameLevel() + 1)

    -- 倒數數字置中在圖示內（放圖示上方會戳進單位框）；獨立一層蓋在圖示與剩時條之上
    local textFrame = CreateFrame("Frame", nil, btn)
    textFrame:SetAllPoints(btn)
    textFrame:SetFrameLevel(btn:GetFrameLevel() + 2)
    local text = textFrame:CreateFontString(nil, "OVERLAY")
    Media.SetFont(text, 11, "OUTLINE", ns.db.global.font)
    text:SetPoint("CENTER", btn, "CENTER", 0, 1)
    text:SetTextColor(1, 1, 1)

    -- 滑鼠提示（不做點擊取消：12.1 的 DestroyTotem 受保護限制多，先不碰）
    btn:EnableMouse(true)
    local slotIndex = i
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        pcall(GameTooltip.SetTotem, GameTooltip, slotIndex)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:Hide()
    return { btn = btn, icon = icon, bar = bar, text = text }
end

-- 顯示順序：土/火對調（沿用使用者的 Stuf 習慣）
local function DisplayOrder()
    local db = GetDB()
    local order = {}
    for i = 1, NUM_SLOTS do order[i] = i end
    if db.swapEarthFire then
        order[1], order[2] = 2, 1
    end
    return order
end

-- 框固定四格寬、圖騰從左往右緊排：數量增減時位置不會飄
local function FrameSize()
    local db = GetDB()
    local size = db.frame.iconSize or 28
    local spacing = db.frame.spacing or 4
    return NUM_SLOTS * size + (NUM_SLOTS - 1) * spacing, size
end

local function Relayout()
    local db = GetDB()
    local spacing = db.frame.spacing or 4
    local prev
    for _, i in ipairs(DisplayOrder()) do
        local slot = slots[i]
        if slot and slot.active then
            slot.btn:ClearAllPoints()
            if not prev then
                slot.btn:SetPoint("LEFT", frame, "LEFT", 0, 0)
            else
                slot.btn:SetPoint("LEFT", prev, "RIGHT", spacing, 0)
            end
            prev = slot.btn
        end
    end
    frame:SetSize(FrameSize())
end

local function UpdateBars()
    for i = 1, NUM_SLOTS do
        local slot = slots[i]
        if slot and slot.active then
            -- start/dur 可能是秘密值：算術一律 pcall 逃逸
            local okR, remain = pcall(function() return slot.start + slot.dur - GetTime() end)
            local okT, total = pcall(function() return slot.dur + 0 end)
            if okR and okT and type(remain) == "number" and type(total) == "number" and total > 0 then
                if remain <= 0 then
                    slot.active = false
                    slot.btn:Hide()
                    Relayout()
                else
                    slot.bar:SetMinMaxValues(0, total)
                    slot.bar:SetValue(remain)
                    if remain < 60 then
                        slot.text:SetText(string.format("%d", math.ceil(remain)))
                    else
                        slot.text:SetText(string.format("%dm", math.ceil(remain / 60)))
                    end
                end
            else
                -- 抽不到剩時：滿條、無數字，靠 PLAYER_TOTEM_UPDATE 收
                slot.bar:SetMinMaxValues(0, 1)
                slot.bar:SetValue(1)
                slot.text:SetText("")
            end
        end
    end
end

local function Poll()
    local db = GetDB()
    if not db.enabled then
        if frame then frame:Hide() end
        return
    end
    local anyActive = false
    for i = 1, NUM_SLOTS do
        local slot = slots[i]
        if not slot then
            slots[i] = CreateSlot(i)
            slot = slots[i]
        end
        local _, _, startTime, duration, icon = GetTotemInfo(i)
        -- icon 是明文（字串路徑或數字 fileID），當存在 proxy——haveTotem 是秘密
        -- boolean 不能測。判斷式照 Stuf：truthiness + ~= ""（數字 fileID 也成立）
        if icon and icon ~= "" then
            slot.active = true
            slot.start = startTime
            slot.dur = duration
            slot.icon:SetTexture(icon)
            local c = SlotColor(i)
            slot.bar:SetStatusBarColor(c.r, c.g, c.b, 1)
            slot.btn:Show()
            anyActive = true
        else
            slot.active = false
            slot.btn:Hide()
        end
    end
    Relayout()
    UpdateBars()

    if anyActive then
        frame:Show()
        if not ticker then
            ticker = C_Timer.NewTicker(0.25, UpdateBars)
        end
    else
        frame:Hide()
        if ticker then ticker:Cancel(); ticker = nil end
    end
end

local function ApplyPosition()
    local db = GetDB()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", db.frame.x or 0, db.frame.y or 0)
end

local function Init()
    if frame then return end
    local db = GetDB()
    if not db or not db.enabled then return end

    frame = CreateFrame("Frame", "MiliUIUF_Totem", UIParent)
    frame:SetSize(FrameSize())
    frame:SetFrameStrata(ns.db.global.strata or "LOW")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:Hide()
    ApplyPosition()

    ns.totemFrame = frame
    ns.Events.Register("PLAYER_TOTEM_UPDATE", "totems", Poll)
    ns.Events.Register("PLAYER_ENTERING_WORLD", "totems_pew", Poll)
    Poll()
end

ns.RegisterCallback("Loaded", "totems", Init)
ns.TotemsApplySettings = function()
    if not frame then Init(); return end
    ApplyPosition()
    for i = 1, NUM_SLOTS do
        if slots[i] then
            slots[i].btn:Hide()
            slots[i] = nil
        end
    end
    Poll()
end
