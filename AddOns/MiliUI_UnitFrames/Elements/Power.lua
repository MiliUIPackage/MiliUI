------------------------------------------------------------
-- 能量條：原生 StatusBar 秘密值直通
------------------------------------------------------------
local _, ns = ...

local Media, Colors = ns.Media, ns.Colors
local IsSecret = ns.IsSecret

local UnitPower, UnitPowerMax = UnitPower, UnitPowerMax

local function Build(uf, edb)
    local f = uf.elements.mpbar or ns.CreateElementBase(uf, "mpbar", "Frame", "BackdropTemplate")
    ns.ApplyElementBase(uf, f, edb)

    local texture = Media.BarTexture(ns.db.global.barTexture)
    local inset = (edb.border ~= false) and Media.BorderInset() or 0

    -- 背景兩種擺法（同血條）：沒設 bgLevel → 貼在 f 自己的 BACKGROUND 層（保證在 bar 之下）；
    -- 有設 bgLevel → 獨立框。不能一律獨立框又同層，繪製順序不保證
    if not f.bgOnSelf then
        f.bgOnSelf = f:CreateTexture(nil, "BACKGROUND")
    end
    f.bgOnSelf:ClearAllPoints()
    f.bgOnSelf:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
    f.bgOnSelf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)
    if not f.bgFrame then
        f.bgFrame = CreateFrame("Frame", nil, f)
        f.bgSeparate = f.bgFrame:CreateTexture(nil, "BACKGROUND")
        f.bgSeparate:SetAllPoints(f.bgFrame)
    end
    f.bgFrame:ClearAllPoints()
    f.bgFrame:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
    f.bgFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)
    if edb.bgLevel then
        f.bgFrame:SetFrameLevel(edb.bgLevel)
        f.bgFrame:Show()
        f.bgOnSelf:Hide()
        f.bg = f.bgSeparate
    else
        f.bgFrame:Hide()
        f.bgOnSelf:Show()
        f.bg = f.bgOnSelf
    end
    f.bg:SetTexture(texture)

    if not f.bar then
        f.bar = CreateFrame("StatusBar", nil, f)
    end
    f.bar:ClearAllPoints()
    f.bar:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
    f.bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)
    f.bar:SetStatusBarTexture(texture)
    f.bar:SetFrameLevel(edb.level or 0)

    -- 邊框層級 = 元件層級 +1。預設版面裡 mp 條(0) 壓在頭像(2) 底下、
    -- 只露出右下 8px 的錯位邊，邊框層級一高過頭像就會從半透明血條底下透出來
    if edb.border ~= false then
        if not f.borderFrame then
            f.borderFrame = CreateFrame("Frame", nil, f, "BackdropTemplate")
            f.borderFrame:SetAllPoints(f)
        end
        f.borderFrame:SetFrameLevel((edb.level or 0) + 1)
        Media.ApplyBorder(f.borderFrame, edb.borderColor)
        f.borderFrame:Show()
    elseif f.borderFrame then
        f.borderFrame:Hide()
    end

    f:Show()
end

local function Update(uf, edb, bucket)
    local f = uf.elements.mpbar
    if not f then return end
    local unit = uf.unit

    local interp = ns.BarInterp()
    if uf.isPreview then
        f.bar:SetMinMaxValues(0, 100)
        f.bar:SetValue(uf.cache.previewMP or 60, interp)
    else
        local maxPower = UnitPowerMax(unit)
        -- 明文且 <=0（無能量的 NPC）→ 顯示空條；秘密值直接放行給 C
        if not IsSecret(maxPower) and (maxPower or 0) <= 0 then
            f.bar:SetMinMaxValues(0, 1)
            f.bar:SetValue(0)
        else
            f.bar:SetMinMaxValues(0, maxPower)
            f.bar:SetValue(UnitPower(unit), interp)
        end
    end

    local frac = uf.cache.fracmp
    local r, g, b, a = Colors.Get(edb.colorMethod, uf, edb, frac, "barColor", "barAlpha")
    f.bar:GetStatusBarTexture():SetVertexColor(r, g, b, a)      -- 貼圖 API 吃秘密色（class 法）
    r, g, b, a = Colors.Get(edb.bgColorMethod, uf, edb, frac, "bgColor", "bgAlpha")
    f.bg:SetVertexColor(r, g, b, a)
end

ns.RegisterElement{
    name = "mpbar",
    order = 30,
    -- reaction：能量條的上色法一樣吃得到陣營（首領框預設的 bgColorMethod 就是
    -- classreactiondark）。hpbar 為了同一件事早就訂了，這裡以前漏掉 ⇒ 中立 NPC
    -- 轉敵對時血條換色、能量條卻停在舊色，要等下一次能量變動才跟上
    buckets = { "power", "powertype", "reaction" },
    build = Build,
    update = Update,
}
