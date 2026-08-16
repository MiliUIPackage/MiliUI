------------------------------------------------------------
-- 資源條（DB key 仍叫 classpower —— 原本只有「職業點數」，現在是多列資源引擎）
--
-- 顯示範圍對齊 Ayije_CDM/Modules/Resources.lua：專精 → 該專精要看的資源清單。
-- 每一列自己決定長相：
--   pip  分段（點數型：聖能／連擊點數／真氣／碎片／充能／精華／符文，以及光環堆疊型）
--   bar  連續長條（怒氣／能量／集中值／符文能量／星能／元能／狂亂值／復仇之怒）
--
-- ⚠ **不做法力**：法力已經有單位框自己的能量條（mpbar）與型態外魔力小條（manabar），
-- 資源條再列一次是重複。Ayije_CDM 有 MANA_SPECS 那張表是因為它的資源條是獨立 HUD、
-- 沒有單位框可靠——我們的情境不同，照抄反而多一條。
--
-- 12.1 注意：玩家自己的 UnitPower/UnitPowerMax 是明文，但仍一律過 Desecret/pcall
-- （進載具、被控時來源會變）。光環堆疊走 spellID 查詢（12.1 仍開放），層數可能是
-- 秘密值 → Desecret 後才拿來比大小。
------------------------------------------------------------
local _, ns = ...

local Media = ns.Media
local CLASS = ns.playerClass

local SOLID = Media.WHITE8X8
local DIM = { r = 0.15, g = 0.15, b = 0.15, a = 0.6 }
local MAX_SEGMENTS = 10
local PT = Enum.PowerType

------------------------------------------------------------
-- 資源定義
------------------------------------------------------------
-- mode   pip / bar
-- power  Enum.PowerType（標準資源）
-- aura   光環 spellID（層數當點數）
-- cast   GetSpellCastCount 的 spellID
-- fill   pip 專用的特殊填充：rune（符文冷卻）／essence（精華回充）
local RESOURCES = {
    Rage            = { name = "怒氣",     mode = "bar", power = PT.Rage,          color = { r = 0.78, g = 0.25, b = 0.25 } },
    Energy          = { name = "能量",     mode = "bar", power = PT.Energy,        color = { r = 1,    g = 0.96, b = 0.41 } },
    Focus           = { name = "集中值",   mode = "bar", power = PT.Focus,         color = { r = 1,    g = 0.5,  b = 0.25 } },
    RunicPower      = { name = "符文能量", mode = "bar", power = PT.RunicPower,    color = { r = 0,    g = 0.82, b = 1    } },
    LunarPower      = { name = "星能",     mode = "bar", power = PT.LunarPower,    color = { r = 0.3,  g = 0.52, b = 0.9  } },
    Maelstrom       = { name = "元能",     mode = "bar", power = PT.Maelstrom,     color = { r = 0,    g = 0.5,  b = 1    } },
    Insanity        = { name = "狂亂值",   mode = "bar", power = PT.Insanity,      color = { r = 0.4,  g = 0,    b = 0.8  } },
    Fury            = { name = "復仇之怒", mode = "bar", power = PT.Fury,          color = { r = 0.788,g = 0.259,b = 0.992} },
    HolyPower       = { name = "聖能",     mode = "pip", power = PT.HolyPower,     color = { r = 0.914,g = 0.678,b = 0.275} },
    ComboPoints     = { name = "連擊點數", mode = "pip", power = PT.ComboPoints,   color = { r = 1,    g = 0.96, b = 0.41 } },
    Chi             = { name = "真氣",     mode = "pip", power = PT.Chi,           color = { r = 0.71, g = 1,    b = 0.92 } },
    SoulShards      = { name = "靈魂碎片", mode = "pip", power = PT.SoulShards,    color = { r = 0.58, g = 0.51, b = 0.79 } },
    ArcaneCharges   = { name = "秘法充能", mode = "pip", power = PT.ArcaneCharges, color = { r = 0.25, g = 0.35, b = 0.98 } },
    Essence         = { name = "精華",     mode = "pip", power = PT.Essence,       color = { r = 0.28, g = 0.73, b = 0.92 } },
    Runes           = { name = "符文",     mode = "pip", power = PT.Runes,         color = { r = 0.77, g = 0.12, b = 0.23 }, fill = "rune" },
    -- 光環／技能次數型（Ayije_CDM 的 custom power，資料來源都是明文 API）
    -- 中文名一律取自 Ayije_CDM/Locales/zhTW.lua（使用者已對過官方譯名，別自己翻）
    MaelstromWeapon = { name = "氣漩武器", mode = "pip", aura = 344179, max = 10,  passive = 187880, color = { r = 0.2,  g = 0.65, b = 1    } },
    TipOfTheSpear   = { name = "長矛之尖", mode = "pip", aura = 260286, max = 3,   passive = 260285, color = { r = 1,    g = 0.6,  b = 0.2  } },
    SoulFragments   = { name = "靈魂碎片", mode = "pip", cast = 228477, max = 6,   passive = 203981, color = { r = 0.64, g = 0.19, b = 0.79 } },
}

-- 專精 → 資源清單（照抄 Ayije_CDM/Modules/Resources.lua 的 SPEC_POWER_MAP）
local SPEC_RESOURCES = {
    [71]  = { "Rage" },                          [72]  = { "Rage" },
    [73]  = { "Rage" },                          -- 防戰的「無視苦痛」是吸收量，12.1 秘密值，不做
    [65]  = { "HolyPower" },                     [66]  = { "HolyPower" },  [70] = { "HolyPower" },
    [253] = { "Focus" },                         [254] = { "Focus" },
    [255] = { "Focus", "TipOfTheSpear" },
    [259] = { "Energy", "ComboPoints" },         [260] = { "Energy", "ComboPoints" },
    [261] = { "Energy", "ComboPoints" },
    [258] = { "Insanity" },
    [250] = { "RunicPower", "Runes" },           [251] = { "RunicPower", "Runes" },
    [252] = { "RunicPower", "Runes" },
    [262] = { "Maelstrom" },                     [263] = { "MaelstromWeapon" },
    [62]  = { "ArcaneCharges" },
    [265] = { "SoulShards" },                    [266] = { "SoulShards" },  [267] = { "SoulShards" },
    [268] = { "Energy" },                        -- 釀酒的「醉仙緩勁」是吸收量，同上不做
    [269] = { "Energy", "Chi" },
    [102] = { "LunarPower" },                    [103] = { "Energy", "ComboPoints" },
    [104] = { "Rage" },                          -- 「鐵鬃」同為吸收量
    [105] = {},
    [577] = { "Fury" },                          [581] = { "Fury", "SoulFragments" },
    [1480] = { "Fury" },
    [1467] = { "Essence" },                      [1468] = { "Essence" },  [1473] = { "Essence" },
}

local function CurrentSpecID()
    local idx = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization
                and C_SpecializationInfo.GetSpecialization()
                or (GetSpecialization and GetSpecialization())
    if not idx then return nil end
    local id = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo
               and C_SpecializationInfo.GetSpecializationInfo(idx)
               or (GetSpecializationInfo and GetSpecializationInfo(idx))
    return id
end

------------------------------------------------------------
-- 取值（全部明文；拿不到就回 nil 讓那一列自己隱藏）
------------------------------------------------------------
local function AuraStacks(spellID)
    local get = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    if not get then return 0 end
    local ok, a = pcall(get, spellID)
    if not ok or not a then return 0 end
    return ns.Desecret(a.applications, 0) or 0
end

local function GetValue(key)
    local def = RESOURCES[key]
    if not def then return nil end
    if def.aura then return AuraStacks(def.aura), def.max end
    if def.cast then
        local fn = C_Spell and C_Spell.GetSpellCastCount
        if not fn then return 0, def.max end
        local ok, n = pcall(fn, def.cast)
        return (ok and ns.Desecret(n, 0)) or 0, def.max
    end
    local cur = ns.Desecret(UnitPower("player", def.power), 0) or 0
    local max = ns.Desecret(UnitPowerMax("player", def.power), 0) or 0
    return cur, max
end

------------------------------------------------------------
-- 天賦判斷
--
-- 兩層，跟 Ayije_CDM 一致：
--   1. 德魯伊看「現在的型態」而不是專精（熊=怒氣、貓=能量+連擊點、梟=星能、其餘法力）
--      —— GetDruidPrimaryPowerType 的邏輯
--   2. 標準資源看 `UnitPowerMax > 0`。沒點到那個天賦時上限就是 0，
--      這比硬寫一張天賦表可靠得多（暴雪改天賦樹也不用跟著改）
--   3. 光環堆疊型沒有 UnitPowerMax 可查 → 查被動是否已學（IsSpellKnown）。
--      被動 ID 萬一寫錯會誤判，所以再加一條保險：**目前有層數就一律顯示**，
--      最壞情況是「平常不出現、用起來才出現」，不會整個消失。
------------------------------------------------------------
local DRUID_BEAR, DRUID_CAT = 5, 1

local function DruidPowerType(specID)
    local form = GetShapeshiftFormID and GetShapeshiftFormID()
    if form == DRUID_BEAR then return PT.Rage end
    if form == DRUID_CAT then return PT.Energy end
    if specID == 102 then return PT.LunarPower end
    return PT.Mana
end

local function SpellKnown(id)
    if not id then return true end
    local fn = C_SpellBook and C_SpellBook.IsSpellKnown
    if not fn then return true end          -- API 不在就放行，寧可多顯示
    local ok, known = pcall(fn, id)
    if not ok then return true end
    return known and true or false
end

-- 給 /muf debug 用：這個資源為什麼在／不在
local gateLog = {}
function ns.ResourceGateLog() return gateLog end

local function Available(key)
    local def = RESOURCES[key]
    if not def then return false, "沒有定義" end
    if def.aura or def.cast then
        if SpellKnown(def.passive) then return true, "被動已學" end
        local cur = GetValue(key)
        if (cur or 0) > 0 then return true, "被動查不到但目前有層數" end
        return false, "被動未學（天賦沒點）"
    end
    local _, max = GetValue(key)
    if (max or 0) <= 0 then return false, "上限 0（天賦沒點／此型態沒有）" end
    return true, "上限 " .. tostring(max)
end

-- 現在的主資源（暗牧的狂亂值、戰士的怒氣、盜賊的能量…）。
-- 這些單位框自己的「能量條」(mpbar) 已經在畫了，資源條再列一次是重複 →
-- 一律從候選裡剔除。剩下的就是真正的「副資源」：連擊點數、聖能、真氣、
-- 碎片、充能、精華、符文，以及光環堆疊型那幾個。
local function PrimaryPowerType()
    return ns.Desecret(UnitPowerType("player"), nil)
end

-- 這個專精「可以顯示」哪些資源（不看使用者開關，但已套天賦／型態判斷）
--
-- ⚠ 有快取：ActiveRows 每次 Update 都會叫它，而能量類的 UNIT_POWER_FREQUENT
-- 一秒好幾次——不快取的話等於每幀重查一輪天賦與上限。
-- 專精／型態／天賦／上限變動時由 Reevaluate 清掉。
local cachedList, cachedSpec

function ns.InvalidateResourceCandidates() cachedList = nil end

function ns.ResourceCandidates()
    if cachedList then return cachedList, cachedSpec end
    local specID = CurrentSpecID()
    local raw = {}

    if CLASS == "DRUID" then
        -- 型態決定一切（專精只用來分辨梟德）
        local pt = DruidPowerType(specID)
        if pt == PT.Rage then
            raw = { "Rage" }
        elseif pt == PT.Energy then
            raw = { "Energy", "ComboPoints" }
        elseif pt == PT.LunarPower then
            raw = { "LunarPower" }
        end
    else
        for _, key in ipairs(SPEC_RESOURCES[specID or 0] or {}) do
            raw[#raw + 1] = key
        end
    end
    wipe(gateLog)
    local primary = PrimaryPowerType()
    local list = {}
    for _, key in ipairs(raw) do
        local def = RESOURCES[key]
        local ok, why
        if def and def.power and primary and def.power == primary then
            ok, why = false, "主資源（單位框的能量條已經在顯示）"
        else
            ok, why = Available(key)
        end
        gateLog[key] = (ok and "顯示：" or "隱藏：") .. why
        if ok then list[#list + 1] = key end
    end
    cachedList, cachedSpec = list, specID
    return list, specID
end

function ns.ResourceInfo(key) return RESOURCES[key] end

-- 實際要畫的清單（套上使用者開關）
local function ActiveRows(edb)
    local cand = ns.ResourceCandidates()
    local off = edb.resources or {}
    local rows = {}
    for _, key in ipairs(cand) do
        if off[key] ~= false and RESOURCES[key] then
            rows[#rows + 1] = key
        end
    end
    return rows
end

------------------------------------------------------------
-- 列的建構
------------------------------------------------------------
-- 分段的黑邊是疊在填充「之上」的貼圖（不是內縮），所以不會露縫；
-- 但線寬同樣要換算成整數實體像素，否則 Retina 上四邊粗細不一致
local function MakeEdge(parent, p1, p2, w, h)
    local e = parent:CreateTexture(nil, "OVERLAY")
    e:SetTexture(SOLID)
    e:SetVertexColor(0, 0, 0, 1)
    e:SetPoint(p1)
    e:SetPoint(p2)
    if w then e:SetWidth(ns.P.Scale(w)) end
    if h then e:SetHeight(ns.P.Scale(h)) end
    return e
end

local function MakeSegment(row)
    local seg = CreateFrame("Frame", nil, row)
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

local function MakeRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row.segs = {}
    for i = 1, MAX_SEGMENTS do
        row.segs[i] = MakeSegment(row)
        row.segs[i]:Hide()
    end
    -- 連續長條用
    row.barBG = row:CreateTexture(nil, "BACKGROUND")
    row.barBG:SetAllPoints(row)
    row.barBG:SetTexture(SOLID)
    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetAllPoints(row)
    row.bar:SetFrameLevel(row:GetFrameLevel() + 1)
    -- 數值掛在獨立的高層 frame 上：直接建在 bar 上會被填充貼圖和黑邊壓過去
    row.textFrame = CreateFrame("Frame", nil, row.bar)
    row.textFrame:SetAllPoints(row.bar)
    row.textFrame:SetFrameLevel(row.bar:GetFrameLevel() + 10)
    row.text = row.textFrame:CreateFontString(nil, "OVERLAY")
    row.text:SetDrawLayer("OVERLAY", 7)
    row.text:SetJustifyH("CENTER")
    row.text:SetJustifyV("MIDDLE")
    row.text:SetTextColor(1, 1, 1, 1)
    row.text:SetShadowColor(0, 0, 0, 1)
    row.text:SetShadowOffset(1, -1)
    row.text:SetPoint("CENTER", row.textFrame, "CENTER", 0, 0)
    -- ⚠ 邊框要建在 row.bar 上，不能建在 row 上：bar 是層級更高的子 frame，
    -- 它的填充貼圖會蓋過 row 自己的 OVERLAY，黑框就看不見了
    row.barEdges = {
        MakeEdge(row.bar, "TOPLEFT", "TOPRIGHT", nil, 1),
        MakeEdge(row.bar, "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1),
        MakeEdge(row.bar, "TOPLEFT", "BOTTOMLEFT", 1, nil),
        MakeEdge(row.bar, "TOPRIGHT", "BOTTOMRIGHT", 1, nil),
    }
    row:Hide()
    return row
end

-- 一列的版面：pip 依段數切；bar 就整條
local function LayoutRow(row, key, edb, numSeg)
    local def = RESOURCES[key]
    local totalW = ns.P.Scale(edb.totalw or 200)
    local h = ns.P.Scale(edb.h or 6)
    row:SetSize(totalW, h)

    local isPip = def.mode == "pip" and numSeg and numSeg > 0
    for _, e in ipairs(row.barEdges) do e:SetShown(not isPip) end
    row.barBG:SetShown(not isPip)
    row.bar:SetShown(not isPip)
    row.text:SetShown(not isPip and (edb.showText and true or false))

    if not isPip then
        for i = 1, MAX_SEGMENTS do row.segs[i]:Hide() end
        row.bar:SetStatusBarTexture(Media.BarTexture(ns.db.global.barTexture))
        Media.SetPixelFont(row.text, edb.textSize or 10, "OUTLINE", ns.db.global.font)
        row.text:SetTextColor(1, 1, 1, 1)
        return
    end

    local spacing = ns.P.Scale(edb.spacing or 1)
    -- 格寬是除出來的小數 → 一定要對齊實體像素，不然每格寬度／間距會忽大忽小
    local rawW, rawGap = edb.totalw or 200, edb.spacing or 1
    local segW = ns.P.Scale((rawW - rawGap * (numSeg - 1)) / numSeg)
    for i = 1, numSeg do
        local seg = row.segs[i]
        seg:SetSize(segW, h)
        seg:ClearAllPoints()
        if i == 1 then
            seg:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        else
            seg:SetPoint("LEFT", row.segs[i - 1], "RIGHT", spacing, 0)
        end
        seg:Show()
    end
    for i = numSeg + 1, MAX_SEGMENTS do row.segs[i]:Hide() end
end

-- 一列現在要幾格（bar 回 0）
local function SegmentsFor(key, isPreview)
    local def = RESOURCES[key]
    if def.mode ~= "pip" then return 0 end
    if isPreview then return math.min(MAX_SEGMENTS, def.max or 5) end
    if def.max then return def.max end
    local _, max = GetValue(key)
    if not max or max <= 0 then return 0 end
    return math.min(MAX_SEGMENTS, max)
end

------------------------------------------------------------
-- 元件
------------------------------------------------------------
local function Build(uf, edb)
    if uf.unit ~= "player" then return end
    local f = uf.elements.classpower
    if not f then
        f = CreateFrame("Frame", nil, uf)
        f.ename = "classpower"
        f.rows = {}
        uf.elements.classpower = f
    end
    f:ClearAllPoints()
    -- holybar 語意：錨在框架底邊下方
    f:SetPoint("TOPLEFT", uf, "BOTTOMLEFT", ns.P.Scale(edb.x or 0), ns.P.Scale(edb.y or 0))
    f:SetFrameLevel(edb.level or 5)
    f.sig = nil          -- 逼下一次 Update 重排
    f:Show()
end

-- 目前這組列的指紋：清單或格數變了就重排
local function Signature(rows, isPreview)
    local parts = {}
    for i, key in ipairs(rows) do
        parts[i] = key .. ":" .. SegmentsFor(key, isPreview)
    end
    return table.concat(parts, "|")
end

local function Relayout(f, edb, rows, isPreview)
    local h = ns.P.Scale(edb.h or 6)
    local gap = ns.P.Scale(edb.rowSpacing or 2)
    local prev
    for i, key in ipairs(rows) do
        local row = f.rows[i]
        if not row then
            row = MakeRow(f)
            f.rows[i] = row
        end
        row.key = key
        row:ClearAllPoints()
        if prev then
            row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -gap)
        else
            row:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        end
        LayoutRow(row, key, edb, SegmentsFor(key, isPreview))
        row:Show()
        prev = row
    end
    for i = #rows + 1, #f.rows do f.rows[i]:Hide() end
    local n = #rows
    f:SetSize(ns.P.Scale(edb.totalw or 200), n > 0 and (n * h + (n - 1) * gap) or 1)
end

local function PaintPip(row, def, edb, numSeg, filled)
    local cc = def.color
    local dc = edb.dimColor or DIM
    for i = 1, numSeg do
        local seg = row.segs[i]
        if i <= filled then
            seg.fg:SetVertexColor(cc.r, cc.g, cc.b, edb.barAlpha or 1)
            seg.bg:SetVertexColor(cc.r * 0.3, cc.g * 0.3, cc.b * 0.3, 0.8)
        else
            seg.fg:SetVertexColor(dc.r, dc.g, dc.b, dc.a or 0.6)
            seg.bg:SetVertexColor(0, 0, 0, 0.4)
        end
    end
end

local function UpdateRow(row, edb, isPreview)
    local key = row.key
    local def = RESOURCES[key]
    if not def then return end
    local cc = def.color

    if def.mode == "pip" then
        local numSeg = SegmentsFor(key, isPreview)
        if numSeg <= 0 then return end
        if def.fill == "rune" and not isPreview then
            -- 符文：每格看自己的冷卻，不是「有幾點」
            local dc = edb.dimColor or DIM
            for i = 1, numSeg do
                local seg = row.segs[i]
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
        local filled = isPreview and math.min(3, numSeg) or (GetValue(key) or 0)
        PaintPip(row, def, edb, numSeg, filled)
        return
    end

    -- 連續條
    local cur, max
    if isPreview then
        cur, max = 62, 100
    else
        cur, max = GetValue(key)
    end
    if not max or max <= 0 then
        row.bar:SetMinMaxValues(0, 1)
        row.bar:SetValue(0)
        row.text:SetText("")
        return
    end
    row.bar:SetMinMaxValues(0, max)
    row.bar:SetValue(cur or 0)
    row.bar:SetStatusBarColor(cc.r, cc.g, cc.b, edb.barAlpha or 1)
    row.barBG:SetVertexColor(cc.r * 0.25, cc.g * 0.25, cc.b * 0.25, edb.bgAlpha or 0.8)
    if edb.showText then
        row.text:SetFormattedText("%d", cur or 0)
    end
end

local function Update(uf, edb, bucket)
    local f = uf.elements.classpower
    if not f then return end
    local isPreview = uf.isPreview and true or false

    local rows = ActiveRows(edb)
    if #rows == 0 then
        f:Hide()
        return
    end
    f:Show()

    local sig = Signature(rows, isPreview)
    if f.sig ~= sig then
        f.sig = sig
        Relayout(f, edb, rows, isPreview)
    end
    for i = 1, #rows do
        UpdateRow(f.rows[i], edb, isPreview)
    end
end

ns.RegisterElement{
    name = "classpower",
    order = 35,
    buckets = { "power", "powertype" },
    build = Build,
    update = Update,
}

-- 型態／專精／符文／光環變動 → 重新評估（清單和格數都可能變）
local function Reevaluate()
    ns.InvalidateResourceCandidates()
    local uf = ns.frames.player
    if uf and uf.elements.classpower then
        local edb = uf.db.elements.classpower
        if edb and edb.enabled ~= false then
            uf.elements.classpower.sig = nil
            Update(uf, edb, "powertype")
        end
    end
end
ns.ResourceReevaluate = Reevaluate

ns.Events.Register("UPDATE_SHAPESHIFT_FORM", "classpower", Reevaluate)
ns.Events.Register("PLAYER_SPECIALIZATION_CHANGED", "classpower", Reevaluate)
ns.Events.Register("RUNE_POWER_UPDATE", "classpower", Reevaluate)
-- 天賦換了 → 資源上限與被動都可能變（沒點的天賦 UnitPowerMax 會是 0）
ns.Events.Register("PLAYER_TALENT_UPDATE", "classpower_talent", Reevaluate)
ns.Events.Register("TRAIT_CONFIG_UPDATED", "classpower_trait", Reevaluate)
ns.Events.Register("UNIT_MAXPOWER", "classpower_maxpower", function(unit)
    if unit == "player" then Reevaluate() end
end)
-- 光環堆疊型資源（漩渦之武／矛尖／靈魂碎片）沒有 UNIT_POWER 可用，只能吃 UNIT_AURA。
-- 團隊戰裡 UNIT_AURA 很吵，所以只有「這個職業真的有這種資源」才註冊
local AURA_DRIVEN_CLASSES = { SHAMAN = true, HUNTER = true, DEMONHUNTER = true }
if AURA_DRIVEN_CLASSES[CLASS] then
ns.Events.Register("UNIT_AURA", "classpower_aura", function(unit)
    if unit ~= "player" then return end
    local uf = ns.frames.player
    local edb = uf and uf.db.elements.classpower
    if not (uf and edb and edb.enabled ~= false and uf.elements.classpower) then return end
    for _, row in ipairs(uf.elements.classpower.rows or {}) do
        local def = row.key and RESOURCES[row.key]
        if row:IsShown() and def and (def.aura or def.cast) then
            UpdateRow(row, edb, uf.isPreview)
        end
    end
end)
end

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
        -- 外觀跟資源條的列一致：底色 + 疊在上面的四條 1px 黑邊
        -- （邊建在 bar 上，不然 bar 的填充會蓋掉它，跟資源列同一個坑）
        f.edges = {
            MakeEdge(f.bar, "TOPLEFT", "TOPRIGHT", nil, 1),
            MakeEdge(f.bar, "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1),
            MakeEdge(f.bar, "TOPLEFT", "BOTTOMLEFT", 1, nil),
            MakeEdge(f.bar, "TOPRIGHT", "BOTTOMRIGHT", 1, nil),
        }
        uf.elements.manabar = f
    end
    -- 設定完全獨立（自己的 x/y/w/h/顏色）。跟資源條一致的只有兩件事：
    --   * 錨點語意：TOPLEFT 對單位框的 BOTTOMLEFT，也就是「掛在框下方、Y 往下為負」
    --   * 外觀：底色 + 四邊 1px 黑邊
    -- 預設值排在資源條「上面一點」，兩條不重疊（見 Core/DB.lua）
    f:SetSize(ns.P.Scale(edb.w or 200), ns.P.Scale(edb.h or 6))
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", uf, "BOTTOMLEFT", ns.P.Scale(edb.x or 0), ns.P.Scale(edb.y or 0))
    f:SetFrameLevel(edb.level or 6)
    f:SetAlpha(edb.alpha or 1)

    f.bar:SetStatusBarTexture(Media.BarTexture(ns.db.global.barTexture))
    f.bar:SetFrameLevel(edb.level or 6)
    -- 預設吃全域的「法力藍」，跟能量條的法力同一個顏色
    local c = edb.color or (ns.db.global.colors.power and ns.db.global.colors.power[0])
              or { r = 0.2, g = 0.5, b = 1, a = 1 }
    f.bar:SetStatusBarColor(c.r, c.g, c.b, (c.a or 1) * (edb.barAlpha or 1))
    -- 底色比照資源列：主色的 25%
    f.bg:SetVertexColor(c.r * 0.25, c.g * 0.25, c.b * 0.25, edb.bgAlpha or 0.8)
    for _, e in ipairs(f.edges) do e:SetShown(edb.border ~= false) end
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
