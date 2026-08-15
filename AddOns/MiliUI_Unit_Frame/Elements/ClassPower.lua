------------------------------------------------------------
-- 職業資源條（v1，聖騎聖能條做法推廣到全職業）
-- 母本：Stuf/bars.lua holybar —— N 格 Frame、WHITE8X8 fg/bg、
-- 1px 黑邊、`cur == i` 逐一 pcall 比對抽明文點數
--
-- 兩個元件：
--   classpower : 點數型分段條（聖能/連擊點/真氣/碎片/秘法充能/精華）＋DK 符文
--   manabar    : 型態外魔力小條（德魯伊/牧師/薩滿，主資源非法力時顯示）
-- 都是 player 專屬；player token 不受 12.1 身分限制，數值大多明文，
-- 但比較一律走 pcall 保險（抄 holybar）。
------------------------------------------------------------
local _, ns = ...

local Media = ns.Media
local CLASS = ns.playerClass

local SOLID = Media.WHITE8X8
local DIM = { r = 0.15, g = 0.15, b = 0.15, a = 0.6 }
local MAX_SEGMENTS = 10

local CLASS_POWER = {
    PALADIN     = { power = Enum.PowerType.HolyPower,     color = { r = 0.914, g = 0.678, b = 0.275 } },
    ROGUE       = { power = Enum.PowerType.ComboPoints,   color = { r = 1, g = 0.96, b = 0.41 } },
    DRUID       = { power = Enum.PowerType.ComboPoints,   color = { r = 1, g = 0.96, b = 0.41 }, catOnly = true },
    MONK        = { power = Enum.PowerType.Chi,           color = { r = 0.71, g = 1, b = 0.92 } },
    WARLOCK     = { power = Enum.PowerType.SoulShards,    color = { r = 0.58, g = 0.51, b = 0.79 } },
    MAGE        = { power = Enum.PowerType.ArcaneCharges, color = { r = 0.25, g = 0.35, b = 0.98 }, specIndex = 1 },
    EVOKER      = { power = Enum.PowerType.Essence,       color = { r = 0.28, g = 0.73, b = 0.92 } },
    DEATHKNIGHT = { runes = true,                         color = { r = 0.77, g = 0.12, b = 0.23 } },
}

local spec = CLASS_POWER[CLASS]

------------------------------------------------------------
-- classpower：分段條
------------------------------------------------------------
if spec then

local function MakeEdge(parent, p1, p2, w, h)
    local e = parent:CreateTexture(nil, "OVERLAY")
    e:SetTexture(SOLID)
    e:SetVertexColor(0, 0, 0, 1)
    e:SetPoint(p1)
    e:SetPoint(p2)
    if w then e:SetWidth(w) end
    if h then e:SetHeight(h) end
    return e
end

local function MakeSegment(f)
    local seg = CreateFrame("Frame", nil, f)
    local fg = seg:CreateTexture(nil, "ARTWORK")
    fg:SetTexture(SOLID)
    fg:SetAllPoints(seg)
    seg.fg = fg
    local bg = seg:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(SOLID)
    bg:SetAllPoints(seg)
    seg.bg = bg
    MakeEdge(seg, "TOPLEFT", "TOPRIGHT", nil, 1)
    MakeEdge(seg, "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
    MakeEdge(seg, "TOPLEFT", "BOTTOMLEFT", 1, nil)
    MakeEdge(seg, "TOPRIGHT", "BOTTOMRIGHT", 1, nil)
    return seg
end

-- 目前應顯示幾格（明文；player 端 API 不受限）
local function GetMaxSegments()
    if spec.runes then return 6 end
    if spec.catOnly then
        local form = GetShapeshiftFormID and GetShapeshiftFormID()
        if form ~= (CAT_FORM or 1) then return 0 end
    end
    if spec.specIndex then
        local cur = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization
                    and C_SpecializationInfo.GetSpecialization() or GetSpecialization and GetSpecialization()
        if cur ~= spec.specIndex then return 0 end
    end
    local maxp = ns.Desecret(UnitPowerMax("player", spec.power), 0)
    if maxp > MAX_SEGMENTS then maxp = MAX_SEGMENTS end
    return maxp
end

-- pcall 逐一比對抽明文點數（holybar 手法）
local function GetPoints(maxSeg)
    local cur = UnitPower("player", spec.power)
    for i = maxSeg, 1, -1 do
        local ok, match = pcall(function() return cur >= i end)
        if ok and match then return i end
    end
    return 0
end

local function Layout(f, edb, numSeg)
    local totalW = edb.totalw or 200
    local h = edb.h or 6
    local spacing = edb.spacing or 1
    if numSeg <= 0 then return end
    local segW = (totalW - spacing * (numSeg - 1)) / numSeg
    for i = 1, numSeg do
        local seg = f.segs[i]
        seg:SetSize(segW, h)
        seg:ClearAllPoints()
        if i == 1 then
            seg:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        else
            seg:SetPoint("LEFT", f.segs[i - 1], "RIGHT", spacing, 0)
        end
        seg:Show()
    end
    for i = numSeg + 1, MAX_SEGMENTS do
        if f.segs[i] then f.segs[i]:Hide() end
    end
    f:SetSize(totalW, h)
end

local function Build(uf, edb)
    if uf.unit ~= "player" then return end
    local f = uf.elements.classpower
    if not f then
        f = CreateFrame("Frame", nil, uf)
        f.ename = "classpower"
        f.segs = {}
        for i = 1, MAX_SEGMENTS do
            f.segs[i] = MakeSegment(f)
            f.segs[i]:Hide()
        end
        uf.elements.classpower = f
    end
    f:ClearAllPoints()
    -- holybar 語意：錨在框架底邊下方
    f:SetPoint("TOPLEFT", uf, "BOTTOMLEFT", edb.x or 0, edb.y or 0)
    f:SetFrameLevel(edb.level or 5)
    f.numSeg = 0
    f:Show()
end

local function Update(uf, edb, bucket)
    local f = uf.elements.classpower
    if not f then return end

    local numSeg = uf.isPreview and 5 or GetMaxSegments()
    if numSeg <= 0 then
        f:Hide()
        return
    end
    f:Show()
    if f.numSeg ~= numSeg then
        f.numSeg = numSeg
        Layout(f, edb, numSeg)
    end

    local cc = edb.color or spec.color
    local dc = edb.dimColor or DIM

    if spec.runes and not uf.isPreview then
        for i = 1, numSeg do
            local seg = f.segs[i]
            local ok, _, _, ready = pcall(GetRuneCooldown, i)
            if ok and ready then
                seg.fg:SetVertexColor(cc.r, cc.g, cc.b, edb.barAlpha or 1)
                seg.bg:SetVertexColor(cc.r * 0.3, cc.g * 0.3, cc.b * 0.3, 0.8)
            else
                seg.fg:SetVertexColor(dc.r, dc.g, dc.b, dc.a or 0.6)
                seg.bg:SetVertexColor(0, 0, 0, 0.4)
            end
        end
        return
    end

    local points = uf.isPreview and 3 or GetPoints(numSeg)
    for i = 1, numSeg do
        local seg = f.segs[i]
        if i <= points then
            seg.fg:SetVertexColor(cc.r, cc.g, cc.b, edb.barAlpha or 1)
            seg.bg:SetVertexColor(cc.r * 0.3, cc.g * 0.3, cc.b * 0.3, 0.8)
        else
            seg.fg:SetVertexColor(dc.r, dc.g, dc.b, dc.a or 0.6)
            seg.bg:SetVertexColor(0, 0, 0, 0.4)
        end
    end
end

ns.RegisterElement{
    name = "classpower",
    order = 35,
    buckets = { "power", "powertype" },
    build = Build,
    update = Update,
}

-- 型態/專精切換 → 重新評估格數（走 player 的 powertype 桶）
local function Reevaluate()
    local uf = ns.frames.player
    if uf and uf.elements.classpower then
        local edb = uf.db.elements.classpower
        if edb and edb.enabled ~= false then
            Update(uf, edb, "powertype")
        end
    end
end
ns.Events.Register("UPDATE_SHAPESHIFT_FORM", "classpower", Reevaluate)
ns.Events.Register("PLAYER_SPECIALIZATION_CHANGED", "classpower", Reevaluate)
if spec.runes then
    ns.Events.Register("RUNE_POWER_UPDATE", "classpower", Reevaluate)
end

end   -- if spec

------------------------------------------------------------
-- manabar：型態外魔力小條（DRUID / PRIEST / SHAMAN）
------------------------------------------------------------
if CLASS == "DRUID" or CLASS == "PRIEST" or CLASS == "SHAMAN" then

local MANA = (Enum.PowerType and Enum.PowerType.Mana) or 0

local function Build(uf, edb)
    if uf.unit ~= "player" then return end
    local f = uf.elements.manabar
    if not f then
        f = CreateFrame("Frame", nil, uf, "BackdropTemplate")
        f.ename = "manabar"
        f.bg = f:CreateTexture(nil, "BACKGROUND")
        f.bg:SetAllPoints(f)
        f.bg:SetTexture(Media.WHITE8X8)
        f.bar = CreateFrame("StatusBar", nil, f)
        f.bar:SetAllPoints(f)
        uf.elements.manabar = f
    end
    ns.ApplyElementBase(uf, f, edb)
    f.bar:SetStatusBarTexture(Media.BarTexture(ns.db.global.barTexture))
    f.bar:SetFrameLevel(edb.level or 6)
    local c = edb.color or { r = 0.3, g = 0.3, b = 1, a = 1 }
    f.bar:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
    f.bg:SetVertexColor(0, 0, 0, edb.bgAlpha or 0.4)
    f:Show()
end

local function Update(uf, edb, bucket)
    local f = uf.elements.manabar
    if not f then return end
    -- 主資源是法力時不顯示（powertype 已在 cache 消毒為明文）。
    -- 預覽孿生也照玩家「目前」的真實資源型態決定，否則會多出一條現實裡不存在的紫線
    local pt = uf.isPreview and ns.Desecret(UnitPowerType("player"), 0) or (uf.cache.powertype or 0)
    if pt == 0 then
        f:Hide()
        return
    end
    f:Show()
    if uf.isPreview then
        f.bar:SetMinMaxValues(0, 100)
        f.bar:SetValue(70)
    else
        f.bar:SetMinMaxValues(0, UnitPowerMax("player", MANA))
        f.bar:SetValue(UnitPower("player", MANA))
    end
end

ns.RegisterElement{
    name = "manabar",
    order = 36,
    buckets = { "power", "powertype" },
    build = Build,
    update = Update,
}

end
