------------------------------------------------------------
-- 只有光環格的條：引擎補位（H1）
--   Catalog.BarAuraFlow 的六個條件（各一個反例）、Bars.BarEmptyMode 的 forced 新定義／AuraFlow／SpellEmptyForced、
--   Layout.FlowParams（成長方向 × 對齊、每列的像素預算，並用暴雪 AnchorUtil.ApplyFlowLayout 的換列判準模擬驗證）、
--   Custom.PlaceFlow（假容器記 AddAuraGroup：group 參數表的形狀、建立順序、按鈕大小、簽章與池化、戰鬥中延後、補踢、收起來）、
--   Bars.Relayout 在補位模式下交給 PlaceFlow
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/AuraFlow_test.lua
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."

local passed, failed = 0, 0
local function check(name, cond, detail)
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL  " .. name .. (detail and ("  (" .. tostring(detail) .. ")") or ""))
    end
end
local function eq(name, got, want)
    check(name, got == want, "got " .. tostring(got) .. ", want " .. tostring(want))
end

------------------------------------------------------------
-- 環境（同 Custom_test 的骨架）
------------------------------------------------------------
local env = setmetatable({}, { __index = _G })
env._G = env
env.UnitName = function() return "米利" end
env.GetRealmName = function() return "世界之樹" end
local combat = false
env.InCombatLockdown = function() return combat end
env.GetSpecialization = function() return 1 end
env.GetSpecializationInfo = function(i) return 60 + i end
env.UnitClass = function() return "聖騎士", "PALADIN", 2 end
env.Enum = {
    CompressionMethod = { Deflate = 1 },
    CooldownViewerCategory = { Essential = 0, Utility = 1, TrackedBuff = 2, TrackedBar = 3 },
    CooldownSetSpellFlags = { HideByDefault = 2 },
}
env.canaccessvalue = function() return true end
env.CDM_HIDE_INVISIBLE_ITEMS = false
local SETS = { [0] = { 11, 12 }, [1] = { 21 }, [2] = { 31, 32 }, [3] = { 41 } }
env.C_CooldownViewer = {
    GetCooldownViewerCategorySet = function(cat) return SETS[cat] or {} end,
    GetCooldownViewerCooldownInfo = function(id)
        return { cooldownID = id, spellID = id * 100, category = math.floor(id / 10) - 1, isKnown = true, flags = 0 }
    end,
    GetLayoutData = function() return "" end,
}
env.C_Spell = {
    GetSpellTexture = function(id) return 900000 + id end,
    GetSpellName = function(id) return "法術" .. id end,
    GetOverrideSpell = function(id) return id end,
}
env.C_SpellBook = { IsSpellKnown = function() return true end }
env.C_Item = {
    GetItemIconByID = function(id) return 800000 + id end,
    GetItemNameByID = function(id) return "物品" .. id end,
    GetItemInfoInstant = function(id) return id, "", "", "", 800000 + id end,
}

-- 假框：任何大寫開頭的方法都記帳（次數、最後一次的參數、呼叫順序）
local FIELDS = { Bar = true, Timer = true, Cooldown = true, ChargeCooldown = true, ChargeCount = true, Icon = true,
                 Name = true, Duration = true, BarBG = true, Pip = true, Applications = true, Current = true,
                 SpellActivationAlert = true, SetBarContent = true, Seg = true, ph = true, skin = true }
local function Obj(otype, parent)
    local o = { otype = otype, parent = parent, shown = true, calls = {}, order = {}, level = 1 }
    setmetatable(o, { __index = function(t, k)
        if FIELDS[k] or type(k) ~= "string" or not k:match("^%u") then return nil end
        local fn = function(_, ...)
            t.calls[k] = (t.calls[k] or 0) + 1
            t["last_" .. k] = { ... }
            t.order[#t.order + 1] = k
        end
        rawset(t, k, fn)
        return fn
    end })
    function o:Hide() self.shown = false; self.order[#self.order + 1] = "Hide" end
    function o:Show() self.shown = true; self.order[#self.order + 1] = "Show" end
    function o:SetShown(v) self.shown = v and true or false end
    function o:IsShown() return self.shown end
    function o:SetParent(p2) self.parent = p2 end
    function o:GetParent() return self.parent end
    function o:GetFrameLevel() return self.level end
    function o:SetFrameLevel(v) self.level = v end
    function o:CreateTexture() return Obj("Texture", self) end
    function o:CreateFontString() return Obj("FontString", self) end
    function o:CreateMaskTexture() return Obj("MaskTexture", self) end
    function o:SetText(v) self.text = v end
    o.hooks = {}
    function o:HookScript(ev, fn) self.hooks[ev] = fn end
    function o:SetScript() end
    if otype == "AuraContainer" then
        o.groups = {}
        function o:AddAuraGroup(key, filter, opts)
            self.groups[#self.groups + 1] = { key = key, filter = filter, opts = opts }
            self.order[#self.order + 1] = "AddAuraGroup"
        end
        function o:SetUnit(u) self.unit = u; self.order[#self.order + 1] = "SetUnit" end
        function o:SetEnabled(v) self.enabled = v; self.order[#self.order + 1] = "SetEnabled" end
    end
    return o
end
env.CreateFrame = function(otype, _, parent) return Obj(otype, parent) end
env.UIParent = Obj("Frame")
function env.UIParent:GetEffectiveScale() return 1 end
env.AnchorUtil = { FlowLayoutAxis = { Horizontal = 0, Vertical = 1 }, FlowDirection = { Left = -1, Right = 1, Up = 1, Down = -1 } }

local regen = {}
local ns = {
    playerClass = "PALADIN",
    IsSecret = function() return false end,
    Events = { Register = function(ev, key, fn) if ev == "PLAYER_REGEN_ENABLED" then regen[key] = fn end end,
               Unregister = function(ev, key) if ev == "PLAYER_REGEN_ENABLED" then regen[key] = nil end end },
    Defer = function(fn, ...) fn(...) end,
    Fire = function() end,
    ReportError = function(err) print("ReportError: " .. tostring(err)) end,
}
function ns.RefreshSpec() ns.specIndex = 1; ns.specID = 61 end

local function load(rel)
    local path = here .. "/../" .. rel
    local chunk, err
    if setfenv then
        chunk, err = loadfile(path)
        if chunk then setfenv(chunk, env) end
    else
        chunk, err = loadfile(path, "t", env)
    end
    assert(chunk, err)
    chunk("MiliUI_CooldownManager", ns)
end
load("Core/DB.lua")
load("Core/Catalog.lua")
load("Core/Overflow.lua")
load("Core/MasqueShape.lua")
load("Core/Layout.lua")
load("Modules/Custom.lua")
load("Core/Text.lua")
local RealText = ns.Text
local DB, C, CU, Lay = ns.DB, ns.Catalog, ns.Custom, ns.Layout
ns.RefreshSpec()
DB.Init()
C.Refresh("test")

-- 外觀相關的 stub（AuraStyle／InitAuraButton 要的那幾支）
ns.P = { Scale = function(v) return v end }
ns.Text = {
    SpellText = RealText.SpellText, BarTimePlace = RealText.BarTimePlace, Color = RealText.Color, EMPTY = RealText.EMPTY,
    BuffTiming = RealText.BuffTiming, LabelStyle = RealText.LabelStyle, LabelPlace = RealText.LabelPlace, LabelSig = RealText.LabelSig,
    SetFont = function() end, PixelScale = function() return 1 end,
    PlainFormatter = function(d) return { formatter = true, decimals = d } end,
}
ns.Media = { SetFont = function() end, Font = function(t) return "font:" .. tostring(t) end,
             ElementFont = function(own, gen) if own ~= nil and own ~= "INHERIT" then return own end return gen end,
             Texture = function(t) return "tex:" .. tostring(t) end }
ns.Decorate = { Apply = function() end, IconOverrideOf = function() return nil end, ApplyItemAlpha = function() end,
                ApplyPlaceholder = function() end }
ns.Glow = { OnParked = function() end, Sync = function() end }
ns.Keybinds = { Apply = function() end, Invalidate = function() end }
local soundSyncs = 0
ns.Sound = { RequestAuraSync = function() soundSyncs = soundSyncs + 1 end }
local writes = 0
ns.Write = function(frame, fn) writes = writes + 1; fn(frame) return true end
ns.Clickable = { Enabled = function(key) return DB.BarClickable(key) end, Release = function() end,
                 EndBar = function() end, Place = function() end }

------------------------------------------------------------
-- 1. Catalog.BarAuraFlow：成立條件六項（各一個反例）
------------------------------------------------------------
local list = DB.CustomList(true)
for i = #list, 1, -1 do list[i] = nil end
local g = DB.CreateBar("icons", "光環")
local iA = DB.AddCustom({ kind = "aura", spellID = 700, filter = "HELPFUL", bar = g })
local iB = DB.AddCustom({ kind = "aura", spellID = 710, filter = "HELPFUL", bar = g })
local iC = DB.AddCustom({ kind = "aura", spellID = 720, filter = "HELPFUL", spellIDs = { 721, 722 }, bar = g })
local idA, idB, idC = "c:" .. iA, "c:" .. iB, "c:" .. iC
local bg = DB.BarTable(g)
bg.layout = bg.layout or {}

local ok, why = C.BarAuraFlow(g)
check("只有光環格 ⇒ 成立", ok and why == nil, tostring(why))
check("只有光環格的條仍然 BarHasAuraSlot", C.BarHasAuraSlot(g))

bg.layout.style = "rings"
ok, why = C.BarAuraFlow(g)
check("反例：圓環條 ⇒ rings", not ok and why == "rings", tostring(why))
bg.layout.style = nil

local iS = DB.AddCustom({ kind = "spell", spellID = 500, bar = g })
ok, why = C.BarAuraFlow(g)
check("反例：混了自訂法術 ⇒ mixed", not ok and why == "mixed", tostring(why))
DB.RemoveCustom("c:" .. iS)
ok, why = C.BarAuraFlow("essential")
check("反例：核心（暴雪的 item）⇒ mixed", not ok and why == "mixed", tostring(why))
ok, why = C.BarAuraFlow("nope")
check("條不存在 ⇒ 不成立", not ok)
local gEmpty = DB.CreateBar("icons", "空的")
check("沒有格的條 ⇒ 不成立", not C.BarAuraFlow(gEmpty))

bg.clickable = true
ok, why = C.BarAuraFlow(g)
check("反例：可點擊 ⇒ clickable", not ok and why == "clickable", tostring(why))
bg.clickable = nil

bg.layout.maxIcons, bg.layout.overflowTo = 1, "utility"
ok, why = C.BarAuraFlow(g)
check("反例：溢出的來源 ⇒ overflow", not ok and why == "overflow", tostring(why))
bg.layout.maxIcons, bg.layout.overflowTo = nil, nil
local ut = DB.BarTable("utility")
ut.layout = ut.layout or {}
ut.layout.maxIcons, ut.layout.overflowTo = 1, g
ok, why = C.BarAuraFlow(g)
check("反例：溢出的接收條 ⇒ overflow", not ok and why == "overflow", tostring(why))
ut.layout.maxIcons, ut.layout.overflowTo = nil, nil

DB.SetOverride(idB, "emptyMode", "blank")
ok, why = C.BarAuraFlow(g)
check("反例：某一格留空位 ⇒ spell", not ok and why == "spell", tostring(why))
DB.SetOverride(idB, "emptyMode", "dim")
ok, why = C.BarAuraFlow(g)
check("反例：某一格暗圖示 ⇒ spell", not ok and why == "spell", tostring(why))
DB.SetOverride(idB, "emptyMode", "collapse")
check("某一格自己選收合 ⇒ 照樣成立", (C.BarAuraFlow(g)))
DB.SetOverride(idB, "emptyMode", nil)

bg.layout.row2Size = { w = 20, h = 20 }
ok, why = C.BarAuraFlow(g)
check("反例：第二列尺寸 ⇒ row2", not ok and why == "row2", tostring(why))
bg.layout.row2Size = false
check("第二列尺寸 false ⇒ 成立", (C.BarAuraFlow(g)))

------------------------------------------------------------
-- 2. Bars：forced 新定義、AuraFlow、SpellEmptyForced
------------------------------------------------------------
ns.Diag = { Note = function() end }
ns.Style = { ApplyPanel = function() end }
ns.Viewers = { AURA_KIND = { buffs = true, buffbars = true }, frames = {}, EnsureScale = function() end,
               Get = function() return nil end }
load("Core/Bars.lua")
local B = ns.Bars

local mode, forced = B.BarEmptyMode(g)
check("只有光環格、沒存 ⇒ 收合、不 forced", mode == "collapse" and forced == false, tostring(mode) .. "/" .. tostring(forced))
check("AuraFlow：收合 ⇒ 補位", B.AuraFlow(g))
bg.layout.emptyMode = "dim"
mode, forced = B.BarEmptyMode(g)
check("選暗圖示 ⇒ dim、不 forced（可以改回收合）", mode == "dim" and forced == false)
check("AuraFlow：暗圖示 ⇒ 不補位", not B.AuraFlow(g))
local _, sf = B.SpellEmptyForced(g)
check("SpellEmptyForced：條沒在補位 ⇒ 單格不能收合", sf == true)
DB.SetOverride(idA, "emptyMode", "collapse")
eq("單格存收合、條暗圖示 ⇒ 跟隨條", (B.EmptyMode(g, idA)), "dim")
DB.SetOverride(idA, "emptyMode", nil)
bg.layout.emptyMode = "collapse"
local _, sf2 = B.SpellEmptyForced(g)
check("SpellEmptyForced：補位中 ⇒ 單格不 forced", sf2 == false)
mode, forced = B.BarEmptyMode("essential")
check("核心（混排）⇒ forced（BarHasAuraSlot 不成立時本來就不 forced）", forced == C.BarHasAuraSlot("essential"))
local iS2 = DB.AddCustom({ kind = "spell", spellID = 500, bar = g })
mode, forced = B.BarEmptyMode(g)
check("混了自訂法術 ⇒ forced、收合退回暗圖示", forced == true and mode == "dim")
check("混排 ⇒ 不補位", not B.AuraFlow(g))
DB.RemoveCustom("c:" .. iS2)
bg.clickable = true
mode, forced = B.BarEmptyMode(g)
check("可點擊 ⇒ forced", forced == true)
check("可點擊 ⇒ 不補位", not B.AuraFlow(g))
bg.clickable = nil
bg.layout.row2Size = { w = 20, h = 20 }
check("第二列尺寸 ⇒ forced", select(2, B.BarEmptyMode(g)) == true)
bg.layout.row2Size = nil
check("沒有光環格的條：收合照常、不補位", not B.AuraFlow("utility") and select(2, B.BarEmptyMode("utility")) == false)

------------------------------------------------------------
-- 3. Layout.FlowParams：成長方向 × 對齊、每列的像素預算
------------------------------------------------------------
local function FP(grow, kind, extra)
    local l = { size = { w = 30, h = 20 }, spacing = 2, grow = grow, maxPerRow = 4 }
    for k, v in pairs(extra or {}) do l[k] = v end
    return Lay.FlowParams(l, kind or "icons")
end
local function Shape(fp) return table.concat({ fp.axis, fp.point, fp.flowPoint, fp.hDir, fp.vDir }, ",") end
-- 橫排：point 跟 Compute 的 anchorPoint 一樣（容器自己的錨點負責對齊），元素一律從左邊那個角往右長
for _, c in ipairs({
    { "CENTER_DOWN", "H,TOP,TOPLEFT,RIGHT,DOWN" },
    { "LEFT_DOWN",   "H,TOPLEFT,TOPLEFT,RIGHT,DOWN" },
    { "RIGHT_DOWN",  "H,TOPRIGHT,TOPLEFT,RIGHT,DOWN" },
    { "CENTER_UP",   "H,BOTTOM,BOTTOMLEFT,RIGHT,UP" },
    { "LEFT_UP",     "H,BOTTOMLEFT,BOTTOMLEFT,RIGHT,UP" },
    { "RIGHT_UP",    "H,BOTTOMRIGHT,BOTTOMLEFT,RIGHT,UP" },
    -- 直排：起點那個角，往伸展方向排、往換列方向開下一列
    { "DOWN_RIGHT",  "V,TOPLEFT,TOPLEFT,RIGHT,DOWN" },
    { "DOWN_LEFT",   "V,TOPRIGHT,TOPRIGHT,LEFT,DOWN" },
    { "UP_RIGHT",    "V,BOTTOMLEFT,BOTTOMLEFT,RIGHT,UP" },
    { "UP_LEFT",     "V,BOTTOMRIGHT,BOTTOMRIGHT,LEFT,UP" },
}) do
    local fp = FP(c[1])
    eq("FlowParams " .. c[1], Shape(fp), c[2])
    -- 容器的錨點必須跟 Compute 的 anchorPoint 一致（條容器的錨點那一邊不動）
    local _, _, _, ap = Lay.Compute({ 1, 2, 3 }, { size = { w = 30, h = 20 }, spacing = 2, grow = c[1], maxPerRow = 4 }, "icons")
    eq("FlowParams " .. c[1] .. "：point ＝ Compute 的錨點", FP(c[1]).point, ap)
end
eq("壞值退回 CENTER_DOWN", Shape(FP("x")), "H,TOP,TOPLEFT,RIGHT,DOWN")
-- 預算：橫排主軸是寬、直排主軸是高
local fp = FP("CENTER_DOWN")
eq("預算（橫）＝ 4×30＋3×2＋15", fp.lineSize, 4 * 30 + 3 * 2 + 15)
eq("每列 4", fp.perLine, 4)
fp = FP("DOWN_RIGHT")
eq("預算（直）＝ 4×20＋3×2＋10", fp.lineSize, 4 * 20 + 3 * 2 + 10)
fp = Lay.FlowParams({ size = { w = 30, h = 30 }, spacing = 2 }, "icons")
check("沒設每列上限 ⇒ 不換列", fp.perLine == nil and fp.lineSize == nil)
fp = Lay.FlowParams({ size = { w = 30, h = 30 }, spacing = -3, maxPerRow = 0 }, "icons")
check("間距不小於 0、每列至少 1", fp.spacing == 0 and fp.perLine == 1)
-- 長條：一列一條（橫向：point TOP／BOTTOM；直向：照直排）
fp = Lay.FlowParams({ size = { w = 200, h = 20 }, spacing = 1, grow = "CENTER_UP", maxPerRow = 1 }, "bars")
eq("橫向長條：往上長", Shape(fp), "H,BOTTOM,BOTTOMLEFT,RIGHT,UP")
eq("橫向長條：一列一條", fp.perLine, 1)
eq("橫向長條：預算 ＝ 條長＋半條", fp.lineSize, 300)
fp = Lay.FlowParams({ size = { w = 20, h = 200 }, spacing = 1, grow = "CENTER_DOWN", maxPerRow = 1, vertical = true }, "bars")
eq("直向長條：往右並排", Shape(fp), "V,TOPLEFT,TOPLEFT,RIGHT,DOWN")
eq("直向長條：預算照條長", fp.lineSize, 300)

-- 照暴雪 AnchorUtil.ApplyFlowLayout 的換列判準模擬（每格一個 group、maxFrameCount 1、groupSpacing 0）：
-- 每放一個元素游標前進「元素＋elementSpacing」；linePrimarySize > 0 且 linePrimarySize ＋ 元素 > 預算 ⇒ 換列
local function Simulate(n, main, sp, budget, groupSpacing)
    local lines, line, used, xs = {}, 0, 0, {}
    local cursor = 0
    for i = 1, n do
        if i > 1 and (groupSpacing or 0) > 0 then
            if used > 0 and used + groupSpacing > budget then
                lines[#lines + 1] = line; line, used, cursor = 0, 0, 0
            else
                cursor, used = cursor + groupSpacing, used + groupSpacing
            end
        end
        local nextUsed = used > 0 and used + main or main
        if used > 0 and nextUsed > budget then
            lines[#lines + 1] = line; line, used, cursor = 0, 0, 0
            nextUsed = main
        end
        xs[i] = cursor
        cursor = cursor + main + sp
        used = nextUsed + sp
        line = line + 1
    end
    lines[#lines + 1] = line
    return lines, xs
end
fp = FP("CENTER_DOWN")
local lines, xs = Simulate(9, fp.w, fp.spacing, fp.lineSize)
eq("模擬：9 格、每列 4 ⇒ 4／4／1", table.concat(lines, "/"), "4/4/1")
eq("模擬：格距 ＝ 格寬＋條的間距（elementSpacing 帶）", xs[2] - xs[1], fp.w + fp.spacing)
local _, xs2 = Simulate(3, fp.w, fp.spacing, fp.lineSize, fp.spacing)
eq("模擬：groupSpacing 也給間距 ⇒ 變兩倍（所以留 0）", xs2[2] - xs2[1], fp.w + 2 * fp.spacing)
local fpOdd = Lay.FlowParams({ size = { w = 30.4, h = 30.4 }, spacing = 1.3, maxPerRow = 5 }, "icons")
lines = Simulate(11, fpOdd.w, fpOdd.spacing, fpOdd.lineSize)
eq("模擬：小數尺寸照樣每列 5", table.concat(lines, "/"), "5/5/1")
lines = Simulate(4, 30, 0, Lay.FlowParams({ size = { w = 30, h = 30 }, spacing = 0, maxPerRow = 2 }, "icons").lineSize)
eq("模擬：間距 0、每列 2", table.concat(lines, "/"), "2/2")
lines = Simulate(3, 200, 1, 300)
eq("模擬：長條一列一條", table.concat(lines, "/"), "1/1/1")
-- FlowSig：參數變了就變
local s1 = Lay.FlowSig(FP("CENTER_DOWN"))
check("FlowSig：同參數同簽章", s1 == Lay.FlowSig(FP("CENTER_DOWN")))
check("FlowSig：換對齊", s1 ~= Lay.FlowSig(FP("LEFT_DOWN")))
check("FlowSig：換每列上限", s1 ~= Lay.FlowSig(FP("CENTER_DOWN", nil, { maxPerRow = 5 })))
check("FlowSig：換尺寸", s1 ~= Lay.FlowSig(FP("CENTER_DOWN", nil, { size = { w = 31, h = 20 } })))
check("FlowSig：換間距", s1 ~= Lay.FlowSig(FP("CENTER_DOWN", nil, { spacing = 3 })))

------------------------------------------------------------
-- 4. Custom.PlaceFlow：group 參數表、建立順序、按鈕大小、簽章與池化、戰鬥中延後、補踢、收起來
------------------------------------------------------------
CU.Sync()
local recA, recB, recC = CU.Get(idA), CU.Get(idB), CU.Get(idC)
local cont = Obj("Frame")
cont.level = 10
local layout = { size = { w = 30, h = 30 }, spacing = 2, grow = "CENTER_DOWN", maxPerRow = 4 }
local fp0 = Lay.FlowParams(layout, "icons")
local rect = { x = 0, y = 0, w = 30, h = 30 }
local function PlaceAll(recs, fpx, gen)
    local l = {}
    for i, r in ipairs(recs) do
        CU.Place(r, cont, rect, g, gen, true)
        l[i] = { rec = r, r = rect }
    end
    CU.PlaceFlow(g, cont, l, fpx, gen)
    return CU.FlowOf(g)
end
-- 先放成固定格位（持有框顯示著），再切成補位：自己的持有框要收起來
CU.Place(recA, cont, rect, g, 1)
local holderA = recA.frame
check("固定格位：持有框顯示、有自己的容器", holderA.shown and recA.container ~= nil)
local builds0 = CU.builds
local fl = PlaceAll({ recA, recB, recC }, fp0, 2)
check("補位：建了補位那一份", fl and fl.active)
eq("補位：自己的持有框收起來", holderA.shown, false)
eq("補位：rec 照樣記放在哪條（音效登記）", recA.placedBar, g)
eq("補位：rec.flowBar", recA.flowBar, g)
check("補位：音效對帳有叫", soundSyncs > 0)
local h = fl.holder
eq("補位持有框：parent 條容器", h:GetParent(), cont)
eq("補位持有框：層級 c＋2", h.level, 12)
check("補位持有框：SetAllPoints(條容器)、顯示", h.last_SetAllPoints and h.last_SetAllPoints[1] == cont and h.shown)
local c = fl.container
check("補位：一顆 AuraContainer", c and c.otype == "AuraContainer")
eq("補位：建了一次", CU.builds, builds0 + 1)
eq("容器：單點錨在持有框的 fp.point", table.concat({ c.last_SetPoint[1], tostring(c.last_SetPoint[2] == h), c.last_SetPoint[3],
    c.last_SetPoint[4], c.last_SetPoint[5] }, ","), "TOP,true,TOP,0,0")
check("容器：沒有 SetAllPoints（要讓它自己設大小）", c.calls.SetAllPoints == nil)
eq("容器：unit player", c.unit, "player")
eq("容器：三個 group", #c.groups, 3)
-- 建立順序：SetUnit → AddAuraGroup… → flow setter → SetEnabled 最後
local seq = {}
for _, k in ipairs(c.order) do
    if k == "SetUnit" or k == "AddAuraGroup" or k == "SetEnabled" or k:match("^SetFlowLayout") then seq[#seq + 1] = k end
end
eq("建立順序", table.concat(seq, ","), "SetUnit,AddAuraGroup,AddAuraGroup,AddAuraGroup,SetFlowLayoutAxis,SetFlowLayoutAnchorPoint,"
    .. "SetFlowLayoutGrowthDirection,SetFlowLayoutPadding,SetFlowLayoutMaximumLineSize,SetEnabled")
eq("SetEnabled(true)", c.enabled, true)
-- group 參數表的形狀
local g1, g3 = c.groups[1], c.groups[3]
eq("group key g1", g1.key, "g1")
eq("group filter", g1.filter, "HELPFUL")
eq("maxFrameCount 1", g1.opts.maxFrameCount, 1)
check("includeSpellIDs ＝ 那一格的法術", g1.opts.candidateFilters.includeSpellIDs[700] == true)
check("多法術：includeSpellIDs 全部", g3.opts.candidateFilters.includeSpellIDs[720] and g3.opts.candidateFilters.includeSpellIDs[721]
    and g3.opts.candidateFilters.includeSpellIDs[722])
local VALID_OPTS = { templateNames = true, initializeFrame = true, candidateFilters = true, sortMethod = true, sortDirection = true,
                     maxFrameCount = true, layout = true }
local VALID_LAYOUT = { elementWidth = true, elementHeight = true, elementSpacing = true, lineSpacing = true, groupSpacing = true,
                       groupLineSpacing = true, forceNewLine = true, layoutIndex = true }
local bad = {}
for _, gr in ipairs(c.groups) do
    for k in pairs(gr.opts) do if not VALID_OPTS[k] then bad[#bad + 1] = k end end
    for k in pairs(gr.opts.layout) do if not VALID_LAYOUT[k] then bad[#bad + 1] = "layout." .. k end end
end
eq("options／layout 沒有暴雪不認的鍵（會被靜靜丟掉）", table.concat(bad, ","), "")
local L1 = g1.opts.layout
eq("layoutIndex ＝ 順序", g3.opts.layout.layoutIndex, 3)
eq("elementWidth／Height ＝ 格子", L1.elementWidth .. "x" .. L1.elementHeight, "30x30")
eq("elementSpacing ＝ 條的間距", L1.elementSpacing, 2)
eq("groupSpacing ＝ 0（不然間距變兩倍）", L1.groupSpacing, 0)
eq("lineSpacing／groupLineSpacing ＝ 條的間距", L1.lineSpacing .. "/" .. L1.groupLineSpacing, "2/2")
-- flow setter
eq("SetFlowLayoutAxis 橫", c.last_SetFlowLayoutAxis[1], 0)
eq("SetFlowLayoutAnchorPoint", c.last_SetFlowLayoutAnchorPoint[1], "TOPLEFT")
eq("SetFlowLayoutGrowthDirection 右／下", c.last_SetFlowLayoutGrowthDirection[1] .. "," .. c.last_SetFlowLayoutGrowthDirection[2], "1,-1")
eq("SetFlowLayoutMaximumLineSize 像素預算", c.last_SetFlowLayoutMaximumLineSize[1], 4 * 30 + 3 * 2 + 15)
eq("setter 結果記下來", fl.applied and fl.applied.SetFlowLayoutAxis, "ok")
-- 一支 setter 斷言失敗不影響後面的
do
    local cx = Obj("AuraContainer")
    function cx:SetFlowLayoutAnchorPoint() error("bad point") end
    local res = CU.ApplyFlowLayout(cx, fp0)
    check("setter 各自 pcall：壞一支、後面照套", res.SetFlowLayoutAnchorPoint ~= "ok" and res.SetFlowLayoutMaximumLineSize == "ok"
        and cx.last_SetFlowLayoutMaximumLineSize ~= nil)
    local cy = Obj("AuraContainer")
    CU.ApplyFlowLayout(cy, Lay.FlowParams({ size = { w = 30, h = 30 } }, "icons"))
    check("不換列 ⇒ MaximumLineSize(nil)", cy.last_SetFlowLayoutMaximumLineSize and cy.last_SetFlowLayoutMaximumLineSize[1] == nil)
end
-- initializeFrame：按鈕只給大小（flow layout 自己錨），不鋪滿容器
do
    local btn = Obj("Frame")
    local got = {}
    function btn:SetIcon(t) got.icon = t end
    function btn:SetDurationCooldown(cd) got.cd = cd end
    function btn:SetDurationText(fs) got.text = fs end
    function btn:SetApplicationCount(fs) got.count = fs end
    recA.lastError = nil
    g1.opts.initializeFrame(btn)
    eq("initializeFrame 沒有錯誤", recA.lastError, nil)
    eq("按鈕大小 ＝ 格子", btn.last_SetSize and (btn.last_SetSize[1] .. "x" .. btn.last_SetSize[2]), "30x30")
    check("按鈕不 SetAllPoints／ClearAllPoints（位置交給 flow layout）", btn.calls.SetAllPoints == nil and btn.calls.ClearAllPoints == nil)
    check("圖示、轉圈照交", got.icon and got.cd)
end
-- 固定格位的按鈕照舊鋪滿（Seat 沒 cell）
do
    local hc = recA.container
    local btn = Obj("Frame")
    function btn:SetIcon() end
    function btn:SetDurationCooldown() end
    function btn:SetDurationText() end
    function btn:SetApplicationCount() end
    -- 固定格位的容器走 AddAuraSlot：假容器沒定義 ⇒ 用持有框上那顆的 slot 參數
    if hc and hc.slot then
        hc.slot.opts.initializeFrame(btn)
        check("固定格位：按鈕 SetAllPoints(容器)", btn.last_SetAllPoints and btn.last_SetAllPoints[1] == hc)
    else
        passed = passed + 1
    end
end

-- 簽章：同樣的東西再放一次 ⇒ 不換、不建
local sig0 = fl.sig
fl = PlaceAll({ recA, recB, recC }, fp0, 3)
eq("同簽章：不建", CU.builds, builds0 + 1)
eq("同簽章：同一顆容器", fl.container, c)
-- 無關的設定（條的透明度、錨定）⇒ 簽章不變
bg.alpha = 0.5
bg.anchor = { to = "essential", point = "TOP", relPoint = "BOTTOM", x = 0, y = -4 }
fl = PlaceAll({ recA, recB, recC }, fp0, 4)
eq("無關設定：簽章不變", fl.sig, sig0)
bg.alpha, bg.anchor = nil, nil
-- 換順序 ⇒ 換一顆
fl = PlaceAll({ recB, recA, recC }, fp0, 5)
check("換順序：簽章變", fl.sig ~= sig0)
check("換順序：新容器、舊的收起來", fl.container ~= c and c.shown == false)
eq("換順序：第一個 group 是 B 的法術", next(fl.container.groups[1].opts.candidateFilters.includeSpellIDs), 710)
local cOrder = fl.container
-- 換樣式（這一格的邊框色）⇒ 換一顆
DB.SetOverride(idA, "borderColor", { r = 1, g = 0, b = 0, a = 1 })
fl = PlaceAll({ recA, recB, recC }, fp0, 6)
check("換樣式：簽章變", fl.sig ~= sig0)
local cStyle = fl.container
DB.SetOverride(idA, "borderColor", nil)
-- 換尺寸 ⇒ 換一顆
local fpBig = Lay.FlowParams({ size = { w = 40, h = 40 }, spacing = 2, grow = "CENTER_DOWN", maxPerRow = 4 }, "icons")
fl = PlaceAll({ recA, recB, recC }, fpBig, 7)
check("換尺寸：簽章變", fl.sig ~= sig0 and fl.container ~= cStyle)
eq("換尺寸：group 的元素寬跟著", fl.container.groups[1].opts.layout.elementWidth, 40)
-- 換回最初 ⇒ 從池子拿回同一顆（不建）
local b1 = CU.builds
fl = PlaceAll({ recA, recB, recC }, fp0, 8)
eq("換回原樣：拿回池子裡那一顆", fl.container, c)
eq("換回原樣：不建", CU.builds, b1)
check("換回原樣：顯示＋補踢（Hide→Show→SetEnabled）", c.shown and c.enabled)
check("其他簽章的容器收起來", cOrder.shown == false and cStyle.shown == false)

-- 戰鬥中：只記旗標，脫戰建
combat = true
local b2 = CU.builds
fl = PlaceAll({ recC, recB, recA }, fp0, 9)
eq("戰鬥中換順序：不建", CU.builds, b2)
eq("戰鬥中：舊容器照舊", fl.container, c)
check("戰鬥中：記旗標、登記脫戰", fl.pending == true and regen.custom ~= nil)
local pb = CU.PendingCounts()
check("PendingCounts 算進補位", pb >= 1)
combat = false
CU.OnRegen()
check("脫戰：建好", fl.pending == nil and fl.container ~= c and CU.builds == b2 + 1)
eq("脫戰：第一個 group 是 C", fl.container.groups[1].opts.candidateFilters.includeSpellIDs[720], true)

-- 補踢：補位持有框 OnShow（戰鬥中記旗標，脫戰踢）
do
    local cc = fl.container
    cc.enabled = nil
    h.hooks.OnShow()
    eq("OnShow：戰鬥外直接補踢", cc.enabled, true)
    combat = true
    cc.enabled = nil
    h.hooks.OnShow()
    check("OnShow：戰鬥中記旗標", fl.pendingKick == true and cc.enabled == nil)
    combat = false
    CU.OnRegen()
    eq("脫戰補踢", cc.enabled, true)
end

-- 認不到法術的格（飾品欄增益解不出來）：不建 group、簽章記 "-"
do
    local groups, sigx = CU.FlowGroups({ key = g, fp = fp0, recs = { recA, { kind = "aura", filter = "HELPFUL", frames = {},
        slotBuff = { slot = 13, buff = 9 }, cooldownID = "c:99", shape = "icons" } } })
    eq("認不到法術的格：不建 group", #groups, 1)
    check("認不到法術的格：簽章帶 \"-\"", sigx:sub(-3) == "||-")
end

-- 收起來：這一輪沒補位（EndBar 的 gen 不同）⇒ 補位持有框 Hide（走 ns.Write），容器留在池裡
do
    local nPool = 0
    for _ in pairs(fl.containers) do nPool = nPool + 1 end
    CU.EndBar(g, 999)
    check("EndBar：補位收起來", fl.active == false and h.shown == false)
    local n2 = 0
    for _ in pairs(fl.containers) do n2 = n2 + 1 end
    eq("EndBar：容器池不動", n2, nPool)
    check("Counts：算進容器池", CU.Counts().containers >= nPool)
    -- 回到固定格位：自己的持有框重新顯示
    CU.Place(recA, cont, rect, g, 1000)
    check("回固定格位：持有框重新顯示、flowBar 清掉", recA.frame.shown and recA.flowBar == nil)
end
-- 條被刪：EndFlush 收
do
    fl = PlaceAll({ recA, recB, recC }, fp0, 1001)
    check("再補位：顯示", fl.active and h.shown)
    local saved = ns.profile.bars[g]
    ns.profile.bars[g] = nil
    CU.EndFlush()
    check("EndFlush：條不在了 ⇒ 收", fl.active == false and h.shown == false)
    ns.profile.bars[g] = saved
end

------------------------------------------------------------
-- 5. Bars.Relayout：補位的條交給 PlaceFlow；混排的條照舊每格 Place
------------------------------------------------------------
do
    CU.Sync()
    local before = CU.FlowOf(g)
    B.Relayout(g, 2, {}, 2000)
    local f2 = CU.FlowOf(g)
    check("Relayout：補位的條走 PlaceFlow", f2 and f2.active and f2.gen == 2000)
    eq("Relayout：三格都進補位", #(f2.recs or {}), 3)
    eq("Relayout：同一份（不另建）", f2, before)
    check("Relayout：每格的持有框收著", CU.Get(idA).frame.shown == false and CU.Get(idB).frame.shown == false)
    eq("Relayout：格子尺寸照條的設定", f2.fp.w, Lay.FlowParams(DB.BarTable(g).layout, "icons").w)
    -- 改成暗圖示：不補位 ⇒ 每格回固定格位、補位收起來
    bg.layout.emptyMode = "dim"
    B.Relayout(g, 2, {}, 2001)
    check("Relayout：暗圖示 ⇒ 補位收起來", f2.active == false)
    check("Relayout：暗圖示 ⇒ 每格持有框顯示", CU.Get(idA).frame.shown and CU.Get(idA).flowBar == nil)
    bg.layout.emptyMode = nil
    B.Relayout(g, 2, {}, 2002)
    check("Relayout：改回收合 ⇒ 再補位", f2.active and CU.Get(idA).frame.shown == false)
end

print(("AuraFlow_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
