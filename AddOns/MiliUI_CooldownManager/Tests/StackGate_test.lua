------------------------------------------------------------
-- 層數門檻（Core/StackGate.lua）的離線自我測試（不進 TOC）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/StackGate_test.lua
--
-- 覆蓋：閘的算式（GateRange）、發光閘外擴量（Margin）、門檻清洗（Threshold）、stackColors 的清洗
-- （排序、去重、上限 5、壞資料丟掉）、層數當填充／刻度（ParseTicks、CleanTicks、刻度位置與 x、條身寬、
-- 填充條取代時間層、色塊改錨、刻度框層級、預覽）、設定組合（Config／GlowStyle）與簽章；
-- 用假框（記錄 SetMinMaxValues／SetValue）測「餵秘密 sentinel 時不比較、原樣轉交」、
-- 讀層數的順序（getter → auraInstanceID 退路 → 0）、生效狀態只在該看的時候看、
-- 後掛勾的提早 return、停放與重新放格、長條換色把暴雪條調透明／還原、無損刷新後重調、
-- 與生效發光互斥（Glow.SyncActive）、預覽走層數發光的樣式（Glow.PreviewActive）、
-- 比較子（F4：Op 清洗、GateSpec 五種 op、巢狀閘的父子鏈與錨點、每層都餵、永不成立整組藏）。
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
local function near(name, got, want)
    check(name, type(got) == "number" and math.abs(got - want) < 1e-9, "got " .. tostring(got) .. ", want " .. tostring(want))
end

------------------------------------------------------------
-- 秘密值替身：任何比較、算術、串接、tostring、長度都直接拋錯（污染端碰秘密值的下場）
------------------------------------------------------------
local secrets = setmetatable({}, { __mode = "k" })
local function boom() error("touched a secret value", 2) end
local SECRET_MT = {
    __eq = boom, __lt = boom, __le = boom, __add = boom, __sub = boom, __mul = boom, __div = boom,
    __mod = boom, __unm = boom, __concat = boom, __len = boom, __call = boom, __tostring = boom,
    __index = boom, __newindex = boom,
}
local function Secret()
    local s = setmetatable({}, SECRET_MT)
    secrets[s] = true
    return s
end
local function IsSecret(v) return type(v) == "table" and secrets[v] == true end

------------------------------------------------------------
-- 假框：記下寫入；不認得的方法一律當 no-op
------------------------------------------------------------
local created = {}
local function NoOp() end
local FRAME_MT = {}
FRAME_MT.__index = function(_, k)
    local m = rawget(FRAME_MT, k)
    if m then return m end
    if type(k) == "string" and k:match("^%u") then return NoOp end     -- 方法（大寫開頭）才當 no-op
    return nil
end
function FRAME_MT.SetMinMaxValues(f, a, b) f.min, f.max = a, b end
function FRAME_MT.SetValue(f, v) f.value = v; f.sets = (f.sets or 0) + 1 end
function FRAME_MT.Show(f) f.shown = true end
function FRAME_MT.Hide(f) f.shown = false end
function FRAME_MT.SetShown(f, v) f.shown = v and true or false end
function FRAME_MT.IsShown(f) return f.shown ~= false end
function FRAME_MT.SetFrameLevel(f, l) f.level = l end
function FRAME_MT.GetFrameLevel(f) return f.level or 1 end
function FRAME_MT.SetVertexColor(f, r, g, b, a) f.color = { r, g, b, a } end
function FRAME_MT.SetAlpha(f, a) f.alpha = a end
function FRAME_MT.SetSize(f, w, h) f.w, f.h = w, h end
function FRAME_MT.SetPoint(f, ...) f.points = f.points or {}; f.points[#f.points + 1] = { ... } end
function FRAME_MT.ClearAllPoints(f) f.points = {} end
function FRAME_MT.SetAllPoints(f, rel) f.allPoints = rel end
function FRAME_MT.SetClipsChildren(f, v) f.clips = v end
function FRAME_MT.SetParent(f, p) f.parent = p end
function FRAME_MT.SetTexture(f, t) f.texture = t end
local function Tex() return setmetatable({ kind = "Texture" }, FRAME_MT) end
function FRAME_MT.CreateTexture(f)
    local t = Tex()
    f.textures = f.textures or {}
    f.textures[#f.textures + 1] = t
    return t
end
function FRAME_MT.SetStatusBarTexture(f) f.fill = f.fill or Tex() end
function FRAME_MT.GetStatusBarTexture(f) return f.fill end
local function NewFrame(kind, parent)
    local f = setmetatable({ kind = kind, parent = parent, shown = true }, FRAME_MT)
    created[#created + 1] = f
    return f
end

------------------------------------------------------------
-- 環境
------------------------------------------------------------
local env = setmetatable({}, { __index = _G })
env._G = env
local hooks = {}             -- 物件 → 方法名 → { fn, … }
env.hooksecurefunc = function(obj, name, fn)
    hooks[obj] = hooks[obj] or {}
    hooks[obj][name] = hooks[obj][name] or {}
    table.insert(hooks[obj][name], fn)
end
env.CreateFrame = function(kind, _, parent) return NewFrame(kind, parent) end
env.InCombatLockdown = function() return false end
local auraByIID = {}
env.C_UnitAuras = {
    GetAuraDataByAuraInstanceID = function(unit, iid)
        local t = auraByIID[iid]
        if t then t.askedUnit = unit end
        return t
    end,
}
env.C_AddOns = { IsAddOnLoaded = function() return false end }
env.C_Timer = { After = function() end }

local overrides = {}         -- id → { field = v }
local settings = {
    ["glow.active"] = { type = "pixel", color = { r = 0.95, g = 0.95, b = 0.32, a = 1 }, lines = 8, thickness = 2, frequency = 0.2 },
    ["bar"] = { texture = "solid", color = { r = 0.4, g = 0.6, b = 0.9, a = 1 }, bgColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.8 } },
    ["kind"] = "bars",
}
local CONST = { stackGlowOp = ">=", stackGlow = false, stackColors = false, stackBar = false, stackTicks = false, activeGlow = false, activeGlowOutOfCombat = true }

local painted, stopped = {}, {}
local ns = {
    IsSecret = IsSecret,
    Guard = function(fn) return fn end,
    Setting = function(_, path) return settings[path] end,
    SpellSetting = function(_, id, key)
        local o = overrides[id]
        if o and o[key] ~= nil then return o[key] end
        return CONST[key]
    end,
    Media = { Texture = function(t) return "tex:" .. tostring(t) end },
    Viewers = { frames = setmetatable({}, { __mode = "k" }), AURA_KIND = { buffs = true, buffbars = true } },
    Events = { Register = function() end, Unregister = function() end },
    MiliUIGlow = {},
    Catalog = { Info = function() return nil end },
}

local function Load(rel)
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
Load("Core/Glow.lua")
Load("Core/StackGate.lua")
local SG, G = ns.StackGate, ns.Glow

-- 發光引擎替身：記下畫在哪個宿主、什麼樣式（Glow.PaintOn／StopOn 照常跑，換掉底下的 LCG）
local LCG = ns.MiliUIGlow
LCG.PixelGlow_Start = function(h, color, _, _, _, _, _, _, _, key) painted[#painted + 1] = { h = h, t = "pixel", key = key, color = color } end
LCG.PixelGlow_Stop = function(h, key) stopped[#stopped + 1] = { h = h, t = "pixel", key = key } end
LCG.AutoCastGlow_Start = function(h, color, _, _, _, _, _, key) painted[#painted + 1] = { h = h, t = "autocast", key = key, color = color } end
LCG.AutoCastGlow_Stop = function(h, key) stopped[#stopped + 1] = { h = h, t = "autocast", key = key } end
LCG.ButtonGlow_Start = function(h, color) painted[#painted + 1] = { h = h, t = "button", color = color } end
LCG.ButtonGlow_Stop = function(h) stopped[#stopped + 1] = { h = h, t = "button" } end
LCG.ProcGlow_Start = function(h, o) painted[#painted + 1] = { h = h, t = "proc", key = o.key } end
LCG.ProcGlow_Stop = function(h, key) stopped[#stopped + 1] = { h = h, t = "proc", key = key } end

local function Fire(obj, name, ...)
    for _, fn in ipairs((hooks[obj] or {})[name] or {}) do fn(obj, ...) end
end

------------------------------------------------------------
-- 1. 純函式
------------------------------------------------------------
do
    local a, b = SG.GateRange(5)
    eq("GateRange(5) min", a, 4); eq("GateRange(5) max", b, 5)
    a, b = SG.GateRange(1)
    eq("GateRange(1) min", a, 0); eq("GateRange(1) max", b, 1)
    -- 引擎夾值的語意：層數 ≥ n 滿、≤ n-1 空（用明文模擬 StatusBar 的填充比例）
    local function Fill(n, v)
        local lo, hi = SG.GateRange(n)
        local x = (math.max(lo, math.min(hi, v)) - lo) / (hi - lo)
        return x
    end
    eq("門檻 3、層數 2 ⇒ 空", Fill(3, 2), 0)
    eq("門檻 3、層數 3 ⇒ 滿", Fill(3, 3), 1)
    eq("門檻 3、層數 10 ⇒ 滿", Fill(3, 10), 1)
    eq("門檻 1、層數 0 ⇒ 空", Fill(1, 0), 0)

    local mx, my = SG.Margin(36, 36)
    near("外擴：36 ⇒ 14.4", mx, 14.4); near("外擴：36 ⇒ 14.4（垂直）", my, 14.4)
    mx, my = SG.Margin(20, 20)
    eq("外擴至少 12", mx, 12); eq("外擴至少 12（垂直）", my, 12)
    mx, my = SG.Margin(200, 20)
    near("長條：水平照寬", mx, 80); eq("長條：垂直至少 12", my, 12)
    mx = SG.Margin(nil, nil)
    eq("尺寸讀不到也有 12", mx, 12)

    eq("門檻 3", SG.Threshold(3), 3)
    eq("門檻 2.7 取整", SG.Threshold(2.7), 2)
    eq("門檻 0 ＝ 關", SG.Threshold(0), nil)
    eq("門檻負數 ＝ 關", SG.Threshold(-2), nil)
    eq("門檻超過 99 夾回", SG.Threshold(150), 99)
    eq("門檻字串 ＝ 關", SG.Threshold("3"), nil)
    eq("門檻 false ＝ 關", SG.Threshold(false), nil)
    eq("門檻 nil ＝ 關", SG.Threshold(nil), nil)
    eq("門檻 NaN ＝ 關", SG.Threshold(0 / 0), nil)
end

------------------------------------------------------------
-- 2. stackColors 清洗
------------------------------------------------------------
do
    eq("nil ⇒ nil", SG.CleanColors(nil), nil)
    eq("false ⇒ nil", SG.CleanColors(false), nil)
    eq("空表 ⇒ nil", SG.CleanColors({}), nil)
    local red, green, blue, gold = { r = 1, g = 0, b = 0, a = 1 }, { r = 0, g = 1, b = 0 }, { r = 0, g = 0, b = 1, a = 0.5 }, { r = 1, g = 0.8, b = 0, a = 1 }
    local out = SG.CleanColors({
        { at = 5, color = red },
        { at = 2, color = green },
        "garbage",
        { at = 0, color = blue },               -- 門檻壞
        { at = 3, color = "nope" },             -- 顏色壞
        { at = 2, color = blue },               -- 重複門檻：留第一筆
        { at = 9, color = gold },
        { at = 7, color = blue },
        { at = 12, color = red },
        { at = 11, color = green },
        { at = 15, color = gold },              -- 第 6 筆：超過上限 5
    })
    eq("上限是 5", SG.MAX_COLORS, 5)
    eq("留 5 筆", #out, 5)
    eq("由低到高 1", out[1].at, 2); eq("由低到高 2", out[2].at, 5); eq("由低到高 3", out[3].at, 7)
    eq("由低到高 4", out[4].at, 9); eq("由低到高 5", out[5].at, 11)
    eq("重複門檻留第一筆（綠）", out[1].color.g, 1)
    eq("沒給 a ⇒ 1", out[1].color.a, 1)
    eq("a 保留", out[3].color.a, 0.5)
    check("是新表（不改原資料）", out[1].color ~= green)
    out = SG.CleanColors({ { at = 120, color = red } })
    eq("門檻夾到 99", out[1].at, 99)
end

------------------------------------------------------------
-- 2b. 層數當填充／刻度的純函式
------------------------------------------------------------
do
    local function list(t) return type(t) == "table" and table.concat(t, ",") or tostring(t) end
    -- ParseTicks
    eq("留白 ⇒ all", SG.ParseTicks("", 10), "all")
    eq("空白字 ⇒ all", SG.ParseTicks("   ", 10), "all")
    eq("nil ⇒ all", SG.ParseTicks(nil, 10), "all")
    eq("all ⇒ all", SG.ParseTicks("all", 10), "all")
    eq("ALL 不分大小寫", SG.ParseTicks(" ALL ", 10), "all")
    eq("1,5,8", list(SG.ParseTicks("1,5,8", 10)), "1,5,8")
    eq("排序", list(SG.ParseTicks("8, 1 ,5", 10)), "1,5,8")
    eq("去重", list(SG.ParseTicks("3,3,2,3", 10)), "2,3")
    eq("空白分隔也收", list(SG.ParseTicks("2 4", 10)), "2,4")
    eq("全形逗號也收", list(SG.ParseTicks("2，4", 10)), "2,4")
    eq("亂字丟掉、留能用的", list(SG.ParseTicks("x,2,y", 10)), "2")
    eq("全是亂字 ⇒ nil", SG.ParseTicks("abc", 10), nil)
    eq("超過 max 丟掉（第 max 層是右緣也丟）", list(SG.ParseTicks("2,5,9,10,12", 10)), "2,5,9")
    eq("全超過 ⇒ nil", SG.ParseTicks("10,20", 10), nil)
    eq("小數與 0、負數丟掉", list(SG.ParseTicks("0,-1,2.5,3", 10)), "3")
    eq("不是字串 ⇒ nil", SG.ParseTicks(5, 10), nil)
    eq("TicksText(all) ＝ 留白", SG.TicksText("all"), "")
    eq("TicksText(list)", SG.TicksText({ 1, 5, 8 }), "1,5,8")

    -- BarMax／CleanTicks
    eq("BarMax false", SG.BarMax(false), nil)
    eq("BarMax 沒有 max", SG.BarMax({}), nil)
    eq("BarMax 5", SG.BarMax({ max = 5 }), 5)
    eq("BarMax 夾到 99", SG.BarMax({ max = 300 }), 99)
    eq("CleanTicks false", SG.CleanTicks(false, nil), nil)
    local t = SG.CleanTicks({ at = "all" }, nil)
    eq("沒 max ⇒ 預設 5", t.n, 5)
    eq("預設顏色黑 0.6", t.color.a, 0.6)
    t = SG.CleanTicks({ at = { 8, 1, 1, "x" }, max = 10, color = { r = 1, g = 1, b = 1 } }, nil)
    eq("at 清洗", list(t.at), "1,8"); eq("用自己的 max", t.n, 10); eq("顏色沒 a ⇒ 1", t.color.a, 1)
    t = SG.CleanTicks({ at = "all", max = 10 }, 4)
    eq("有層數當填充 ⇒ 用它的 N", t.n, 4)
    eq("at 壞掉 ⇒ all", SG.CleanTicks({ at = {} }, nil).at, "all")
    eq("N ＝ 1 畫不出 ⇒ nil", SG.CleanTicks({ at = "all" }, 1), nil)

    -- 刻度位置與 x
    eq("all、N=5 ⇒ 1～4", list(SG.TickPositions(5, "all")), "1,2,3,4")
    eq("指定、只留 1～N-1", list(SG.TickPositions(5, { 1, 5, 8 })), "1")
    eq("N=1 ⇒ 沒有", #SG.TickPositions(1, "all"), 0)
    near("x ＝ 寬×k/N", SG.TickX(200, 5, 1), 40)
    near("x 第 4 條", SG.TickX(200, 5, 4), 160)
    near("x 寬 0", SG.TickX(0, 5, 2), 0)
    eq("N 0 不除以 0", SG.TickX(100, 0, 1), 0)
    eq("條身寬：左圖示", SG.BodyWidth(220, 20, "LEFT", 2), 198)
    eq("條身寬：右圖示", SG.BodyWidth(220, 20, "RIGHT", 0), 200)
    eq("條身寬：沒圖示", SG.BodyWidth(220, 20, "NONE", 5), 220)
    eq("條身寬不為負", SG.BodyWidth(10, 20, "LEFT", 0), 0)
    -- 直向（F8c）：格子 w ＝ 粗細、h ＝ 條長；圖示 w×w
    eq("條身長：直向上圖示", SG.BodyWidth(20, 220, "LEFT", 2, true), 198)
    eq("條身長：直向沒圖示", SG.BodyWidth(20, 220, "NONE", 2, true), 220)
    near("預覽填 2/N", SG.PreviewFill(5), 0.4)
    eq("預覽 N=1 滿", SG.PreviewFill(1), 1)
end

------------------------------------------------------------
-- 3. 設定組合與簽章
------------------------------------------------------------
do
    eq("不是增益 ⇒ nil", SG.Config("essential", 10, false, false), nil)
    eq("自訂項目 id ⇒ nil", SG.Config("buffs", "c:1", true, false), nil)
    eq("沒設 ⇒ nil", SG.Config("buffs", 10, true, false), nil)
    overrides[10] = { stackGlow = 4, stackGlowType = "autocast" }
    local cfg = SG.Config("buffs", 10, true, false)
    eq("門檻", cfg.glow, 4)
    eq("樣式覆寫", cfg.style.type, "autocast")
    eq("顏色退回 glow.active", cfg.style.color.r, 0.95)
    eq("圖示沒有換色", cfg.colors, nil)
    overrides[10].stackColors = { { at = 3, color = { r = 1, g = 0, b = 0 } } }
    cfg = SG.Config("buffs", 10, true, false)
    eq("圖示即使存了換色也不用", cfg.colors, nil)
    cfg = SG.Config("buffbars", 10, true, true)
    eq("長條有換色", #cfg.colors, 1)
    overrides[11] = { stackColors = { { at = 3, color = { r = 1, g = 0, b = 0 } } } }
    cfg = SG.Config("buffbars", 11, true, true)
    eq("只有換色：沒有發光", cfg.glow, nil)
    eq("只有換色：沒有樣式", cfg.style, nil)

    local c1 = SG.Config("buffbars", 10, true, true)
    local s1 = SG.Signature(c1, 36, 36, settings.bar)
    eq("同輸入同簽章", SG.Signature(SG.Config("buffbars", 10, true, true), 36, 36, settings.bar), s1)
    check("尺寸進簽章", SG.Signature(c1, 40, 36, settings.bar) ~= s1)
    overrides[10].stackGlow = 5
    check("門檻進簽章", SG.Signature(SG.Config("buffbars", 10, true, true), 36, 36, settings.bar) ~= s1)
    overrides[10].stackGlow = 4
    overrides[10].stackGlowColor = { r = 0, g = 1, b = 0, a = 1 }
    check("發光顏色進簽章", SG.Signature(SG.Config("buffbars", 10, true, true), 36, 36, settings.bar) ~= s1)
    overrides[10].stackGlowColor = nil
    overrides[10].stackColors[1].color = { r = 0, g = 0, b = 1 }
    check("換色顏色進簽章", SG.Signature(SG.Config("buffbars", 10, true, true), 36, 36, settings.bar) ~= s1)
    check("條身材質進簽章", SG.Signature(c1, 36, 36, { texture = "other" }) ~= s1)
    eq("沒設定沒有簽章", SG.Signature(nil, 1, 1), nil)
    -- 漸層（F8a）：條身底下那一層的原色填充套同一個漸層 ⇒ 進簽章
    local gbar = { texture = "solid", color = settings.bar.color, bgColor = settings.bar.bgColor,
                   gradient = { dir = "H", color2 = { r = 1, g = 1, b = 1, a = 1 } } }
    local sg1 = SG.Signature(c1, 36, 36, gbar)
    check("漸層進簽章", sg1 ~= s1)
    gbar.gradient.dir = "V"
    check("漸層方向進簽章", SG.Signature(c1, 36, 36, gbar) ~= sg1)
    gbar.gradient = false
    eq("漸層 false ＝ 沒漸層的簽章", SG.Signature(c1, 36, 36, gbar), s1)

    -- 層數當填充／刻度：只有長條才有；進簽章
    overrides[12] = { stackBar = { max = 5 } }
    eq("圖示沒有層數當填充", SG.Config("buffs", 12, true, false), nil)
    local cb = SG.Config("buffbars", 12, true, true)
    eq("長條：層數當填充 N", cb.stackBar, 5)
    check("層數當填充算條身底下那一層", SG.HasLayers(cb))
    local sb = SG.Signature(cb, 220, 20, settings.bar)
    overrides[12].stackBar = { max = 6 }
    check("N 進簽章", SG.Signature(SG.Config("buffbars", 12, true, true), 220, 20, settings.bar) ~= sb)
    overrides[12].stackBar = { max = 5 }
    overrides[12].stackTicks = { at = "all" }
    local ct = SG.Config("buffbars", 12, true, true)
    eq("刻度跟著層數當填充的 N", ct.ticks.n, 5)
    local st = SG.Signature(ct, 220, 20, settings.bar)
    check("刻度進簽章", st ~= sb)
    overrides[12].stackTicks = { at = { 2 } }
    check("刻度位置進簽章", SG.Signature(SG.Config("buffbars", 12, true, true), 220, 20, settings.bar) ~= st)
    overrides[12].stackTicks = { at = "all", color = { r = 1, g = 0, b = 0, a = 1 } }
    check("刻度顏色進簽章", SG.Signature(SG.Config("buffbars", 12, true, true), 220, 20, settings.bar) ~= st)
    check("圖示邊進簽章（條身寬）", SG.Signature(ct, 220, 20, { texture = "solid", iconSide = "NONE" })
        ~= SG.Signature(ct, 220, 20, { texture = "solid" }))
    overrides[13] = { stackTicks = { at = "all", max = 8 } }
    local c13 = SG.Config("buffbars", 13, true, true)
    eq("只有刻度：用自己的 max", c13.ticks.n, 8)
    eq("只有刻度：沒有層數當填充", c13.stackBar, nil)
    overrides[10], overrides[11], overrides[12], overrides[13] = nil, nil, nil, nil
end

------------------------------------------------------------
-- 3b. 比較子（F4）：Op 清洗、GateSpec、Config／簽章
------------------------------------------------------------
-- 一組條件在明文層數 v 下成立嗎（模擬閘的幾何：fill ＝ v ≥ b；rest ＝ v ≤ a）
local function SpecHolds(spec, v)
    if not spec then return false end
    for _, c in ipairs(spec) do
        if c.side == "fill" then
            if not (v >= c.b) then return false end
        else
            if not (v <= c.a) then return false end
        end
    end
    return true
end
do
    eq("Op 沒設 ⇒ >=", SG.Op(nil), ">=")
    eq("Op false ⇒ >=", SG.Op(false), ">=")
    eq("Op 亂寫 ⇒ >=", SG.Op("=>"), ">=")
    eq("Op 數字 ⇒ >=", SG.Op(3), ">=")
    for _, op in ipairs({ ">=", "<=", "==", ">", "<" }) do eq("Op 收 " .. op, SG.Op(op), op) end
    eq("OPS 五種", #SG.OPS, 5)
    check("< 1 永不成立", SG.Never("<", 1))
    check("< 2 會成立", not SG.Never("<", 2))
    check("<= 1 會成立", not SG.Never("<=", 1))

    local truth = {
        [">="] = function(v, n) return v >= n end,
        [">"]  = function(v, n) return v > n end,
        ["<="] = function(v, n) return v >= 1 and v <= n end,
        ["<"]  = function(v, n) return v >= 1 and v < n end,
        ["=="] = function(v, n) return v == n end,
    }
    local depth = { [">="] = 1, [">"] = 1, ["<="] = 2, ["<"] = 2, ["=="] = 2 }
    for _, op in ipairs(SG.OPS) do
        for _, n in ipairs({ 1, 2, 5, 99 }) do
            local spec = SG.GateSpec(op, n)
            local tag = op .. " " .. n
            if op == "<" and n <= 1 then
                eq("GateSpec " .. tag .. " 永不成立 ⇒ nil", spec, nil)
            else
                check("GateSpec " .. tag .. " 有清單", type(spec) == "table")
                eq("GateSpec " .. tag .. " 層數", spec and #spec, depth[op])
                check("GateSpec " .. tag .. " 不超過 MAX_GATES", spec and #spec <= SG.MAX_GATES)
                local ok = true
                for _, c in ipairs(spec or {}) do
                    if not (c.b == c.a + 1 and c.a >= 0 and (c.side == "fill" or c.side == "rest")) then ok = false end
                end
                check("GateSpec " .. tag .. " 每層是寬 1 的閘", ok)
                for v = 0, 101 do
                    if SpecHolds(spec, v) ~= truth[op](v, n) then
                        check("GateSpec " .. tag .. " 層數 " .. v, false, "幾何算出 " .. tostring(SpecHolds(spec, v)))
                        break
                    end
                end
            end
        end
    end
    -- 照 plan 的表逐條對
    local s = SG.GateSpec(">=", 5)
    check(">= 5 ＝ (4,5) fill", s[1].a == 4 and s[1].b == 5 and s[1].side == "fill")
    s = SG.GateSpec(">", 5)
    check("> 5 ＝ (5,6) fill", s[1].a == 5 and s[1].b == 6 and s[1].side == "fill")
    s = SG.GateSpec("<=", 5)
    check("<= 5 ＝ (5,6) rest ＋ (0,1) fill", s[1].a == 5 and s[1].side == "rest" and s[2].a == 0 and s[2].b == 1 and s[2].side == "fill")
    s = SG.GateSpec("<", 5)
    check("< 5 ＝ (4,5) rest ＋ (0,1) fill", s[1].a == 4 and s[1].b == 5 and s[1].side == "rest" and s[2].a == 0 and s[2].side == "fill")
    s = SG.GateSpec("==", 5)
    check("== 5 ＝ (4,5) fill ＋ (5,6) rest", s[1].a == 4 and s[1].side == "fill" and s[2].a == 5 and s[2].b == 6 and s[2].side == "rest")
    eq("亂 op 退回 >=", #SG.GateSpec("??", 3), 1)
    eq("門檻壞掉 ⇒ nil", SG.GateSpec(">=", 0), nil)
    eq("門檻過大夾到 99", SG.GateSpec(">=", 500)[1].b, 99)

    -- Config：沒設 op ＝ >=（舊存檔）、亂 op 清成 >=、op 進簽章
    overrides[14] = { stackGlow = 3 }
    local c = SG.Config("buffs", 14, true, false)
    eq("舊存檔沒有 op ⇒ >=", c.op, ">=")
    eq("舊存檔閘照舊 (2,3) fill", c.gates[1].a, 2)
    eq("舊存檔一層閘", #c.gates, 1)
    local s0 = SG.Signature(c, 36, 36, settings.bar)
    overrides[14].stackGlowOp = "bogus"
    eq("亂 op ⇒ >=", SG.Config("buffs", 14, true, false).op, ">=")
    eq("亂 op 簽章同 >=", SG.Signature(SG.Config("buffs", 14, true, false), 36, 36, settings.bar), s0)
    overrides[14].stackGlowOp = "=="
    local ce = SG.Config("buffs", 14, true, false)
    eq("op ==", ce.op, "==")
    eq("== 兩層閘", #ce.gates, 2)
    check("op 進簽章", SG.Signature(ce, 36, 36, settings.bar) ~= s0)
    overrides[14] = { stackGlow = 1, stackGlowOp = "<" }
    local cn = SG.Config("buffs", 14, true, false)
    eq("< 1：門檻還在（跟生效發光互斥）", cn.glow, 1)
    eq("< 1：沒有閘", cn.gates, nil)
    overrides[14] = { stackGlowOp = "<=" }
    eq("只有 op 沒有門檻 ⇒ 沒設定", SG.Config("buffs", 14, true, false), nil)
    overrides[14] = { stackGlow = 3, stackGlowOp = "<=", stackColors = { { at = 2, color = { r = 1, g = 0, b = 0 } } } }
    local cc = SG.Config("buffbars", 14, true, true)
    eq("換色不吃比較子（照舊 at）", cc.colors[1].at, 2)
    overrides[14] = nil
end

------------------------------------------------------------
-- 4. 餵值：秘密 sentinel 原樣轉交、讀的順序
------------------------------------------------------------
-- 假的暴雪增益 item（圖示或長條）
local function Item(opts)
    opts = opts or {}
    local it = NewFrame("Frame")
    it.auraData = opts.auraData
    it.active = opts.active
    if not opts.noGetter then
        function it:GetAuraDataCached() return self.auraData end
    else
        it.GetAuraDataCached = false                -- 假框對大寫鍵回 no-op：明確標成沒有
    end
    it.Bar = false
    function it:GetAuraDataUnit() return self.unit end
    function it:IsActive() return self.active end
    function it:RefreshApplications() end
    function it:OnActiveStateChanged() end
    if opts.bar then
        it.Bar = NewFrame("StatusBar", it)
        it.Bar:SetStatusBarTexture("x")
        it.Bar.BarBG = Tex()
        it.Bar.level = 511
    end
    return it
end

local function Rec(item, barKey, id)
    local rec = { barKey = barKey, cooldownID = id, overlay = NewFrame("Frame", item) }
    rec.overlay.level = 20
    ns.Viewers.frames[item] = rec
    SG.HookItem(item, rec)
    return rec
end

do
    local S = Secret()
    overrides[20] = { stackGlow = 3 }
    local it = Item({ auraData = { applications = S }, active = true })
    local rec = Rec(it, "buffs", 20)
    SG.Apply(it, rec, "buffs", 36, 36, false)
    local gate = rec.stackUI.glow.gate
    eq("閘 min", gate.min, 2); eq("閘 max", gate.max, 3)
    check("秘密層數原樣轉交（同一個物件）", rawequal(gate.value, S))
    eq("最近一次是秘密", SG.last, "secret")
    check("裁切框有開裁切", rec.stackUI.glow.clip.clips == true)
    eq("裁切框錨在閘的填充貼圖上", rec.stackUI.glow.clip.points[1][2], gate.fill)
    eq("宿主尺寸照排版", rec.stackUI.glow.host.w, 36)
    local mx = SG.Margin(36, 36)
    eq("閘比格子大一圈（TOPLEFT x）", gate.points[1][4], -mx)
    eq("宿主不錨在閘上（錨 overlay 中央）", rec.stackUI.glow.host.points[1][2], rec.overlay)
    check("發光畫在宿主上", painted[#painted] and painted[#painted].h == rec.stackUI.glow.host and painted[#painted].key == "stack")
    eq("rec 上記著畫了什麼", rec.stackGlowOn, "pixel")

    -- RefreshApplications 後掛勾：層數變了
    it.auraData = { applications = 5 }
    Fire(it, "RefreshApplications")
    eq("明文層數直接餵", gate.value, 5)
    eq("最近一次是明文", SG.last, "plain")
    -- 光環不在：0
    it.auraData = nil
    Fire(it, "RefreshApplications")
    eq("光環不在 ⇒ 0", gate.value, 0)
    eq("種類 none", SG.last, "none")
    -- applications 是明文 nil ⇒ 0
    it.auraData = {}
    Fire(it, "RefreshApplications")
    eq("applications nil ⇒ 0", gate.value, 0)
    -- RefreshApplications 那一刻不看 IsActive（暴雪還沒 RefreshActive）
    it.active = false
    it.auraData = { applications = 4 }
    Fire(it, "RefreshApplications")
    eq("RefreshApplications 不看過期的 IsActive", gate.value, 4)
    -- OnActiveStateChanged：明文 false ⇒ 0
    Fire(it, "OnActiveStateChanged")
    eq("沒生效 ⇒ 0", gate.value, 0)
    eq("種類 inactive", SG.last, "inactive")
    -- IsActive 是秘密值：不知道 ⇒ 照讀層數
    it.active = Secret()
    Fire(it, "OnActiveStateChanged")
    eq("生效狀態是秘密 ⇒ 照讀層數", gate.value, 4)
    it.active = true

    -- getter 取值拋錯（表不能讀）⇒ 退路：auraInstanceID
    it.auraData = setmetatable({}, { __index = function() error("cannot be accessed") end })
    rawset(it, "auraInstanceID", 777)
    it.unit = "target"
    local S2 = Secret()
    auraByIID[777] = { applications = S2 }
    Fire(it, "RefreshApplications")
    check("getter 拋錯 ⇒ 用 auraInstanceID 問", rawequal(gate.value, S2))
    eq("unit 照 GetAuraDataUnit", auraByIID[777].askedUnit, "target")
    -- 秘密的 auraInstanceID 不拿來問（退回 0）
    rawset(it, "auraInstanceID", Secret())
    Fire(it, "RefreshApplications")
    eq("秘密 auraInstanceID ⇒ 0", gate.value, 0)
    -- 沒有 getter 的 item：退路 unit 讀不到用 player
    local it2 = Item({ noGetter = true, active = true })
    rawset(it2, "auraInstanceID", 778)
    auraByIID[778] = { applications = 2 }
    local rec2 = Rec(it2, "buffs", 20)
    SG.Apply(it2, rec2, "buffs", 36, 36, false)
    eq("沒有 getter ⇒ 退路", rec2.stackUI.glow.gate.value, 2)
    eq("unit 讀不到 ⇒ player", auraByIID[778].askedUnit, "player")

    -- 換了身分還沒重套：掛勾不餵
    local sets = gate.sets
    rec.cooldownID = 99
    Fire(it, "RefreshApplications")
    eq("身分換了 ⇒ 不餵", gate.sets, sets)
    rec.cooldownID = 20
    overrides[20] = nil
end

------------------------------------------------------------
-- 4b. 比較子的巢狀閘：父子鏈、每層錨點、每層都餵同一個秘密值、op 換了重建、永不成立整組藏
------------------------------------------------------------
do
    local S = Secret()
    overrides[25] = { stackGlow = 3, stackGlowOp = "<=" }
    local it = Item({ auraData = { applications = S }, active = true })
    local rec = Rec(it, "buffs", 25)
    SG.Apply(it, rec, "buffs", 36, 36, false)
    local gs = rec.stackUI.glow
    eq("<= 兩層", gs.depth, 2)
    local g1, g2 = gs.levels[1], gs.levels[2]
    eq("外層閘的父框是 overlay", g1.gate.parent, rec.overlay)
    eq("外層裁切框的父框是 overlay", g1.clip.parent, rec.overlay)
    eq("內層閘的父框是外層裁切框", g2.gate.parent, g1.clip)
    eq("內層裁切框的父框是外層裁切框", g2.clip.parent, g1.clip)
    check("兩層都開裁切", g1.clip.clips and g2.clip.clips)
    check("外層 (3,4)", g1.gate.min == 3 and g1.gate.max == 4)
    check("內層 (0,1)", g2.gate.min == 0 and g2.gate.max == 1)
    -- 外層 rest：TOPLEFT 錨填充貼圖 TOPRIGHT、BOTTOMRIGHT 錨閘 BOTTOMRIGHT
    local p = g1.clip.points
    check("rest：TOPLEFT → 填充貼圖 TOPRIGHT", p[1][1] == "TOPLEFT" and p[1][2] == g1.gate.fill and p[1][3] == "TOPRIGHT")
    check("rest：BOTTOMRIGHT → 閘 BOTTOMRIGHT", p[2][1] == "BOTTOMRIGHT" and p[2][2] == g1.gate and p[2][3] == "BOTTOMRIGHT")
    local q = g2.clip.points
    check("fill：兩點都錨填充貼圖", q[1][2] == g2.gate.fill and q[2][2] == g2.gate.fill and q[2][3] == "BOTTOMRIGHT")
    local mx = SG.Margin(36, 36)
    eq("內層閘也錨 overlay（明文幾何）", g2.gate.points[1][2], rec.overlay)
    eq("內層閘同一個外擴", g2.gate.points[1][4], -mx)
    eq("宿主在最內層裁切框底下", gs.hostParent, g2.clip)
    eq("宿主錨 overlay 中央", gs.host.points[1][2], rec.overlay)
    check("兩層都餵同一個秘密值", rawequal(g1.gate.value, S) and rawequal(g2.gate.value, S))
    check("發光畫著", rec.stackGlowOn ~= nil)
    it.auraData = { applications = 2 }
    Fire(it, "RefreshApplications")
    check("掛勾也兩層都餵", g1.gate.value == 2 and g2.gate.value == 2)

    -- 換成 >=：一層、宿主回外層裁切框、內層藏
    overrides[25].stackGlowOp = ">="
    SG.Apply(it, rec, "buffs", 36, 36, false)
    eq(">= 一層", gs.depth, 1)
    eq("宿主回到外層裁切框", gs.hostParent, g1.clip)
    eq("宿主真的 SetParent 了", gs.host.parent, g1.clip)
    eq("內層閘藏", g2.gate.shown, false)
    eq("外層換回 fill 錨", g1.clip.points[1][2], g1.gate.fill)
    eq("外層換回 fill 錨（TOPLEFT）", g1.clip.points[1][3], "TOPLEFT")
    check("外層 (2,3)", g1.gate.min == 2 and g1.gate.max == 3)
    local sets2 = g2.gate.sets
    Fire(it, "RefreshApplications")
    eq("藏起來的內層不再餵", g2.gate.sets, sets2)

    -- ==：內層 rest
    overrides[25].stackGlowOp = "=="
    SG.Apply(it, rec, "buffs", 36, 36, false)
    eq("== 兩層", gs.depth, 2)
    eq("== 重用同一顆內層", gs.levels[2], g2)
    eq("== 內層 rest", g2.clip.points[1][3], "TOPRIGHT")
    eq("== 宿主在內層", gs.host.parent, g2.clip)

    -- 停放／重新放格：兩層一起藏、一起亮
    G.OnParked(rec)
    check("停放 ⇒ 兩層藏", g1.gate.shown == false and g2.clip.shown == false)
    SG.Feed(it, rec)
    check("重新放格 ⇒ 兩層亮", g1.gate.shown and g2.clip.shown)

    -- < 1：永不成立 ⇒ 整組藏、發光不畫
    overrides[25] = { stackGlow = 1, stackGlowOp = "<" }
    SG.Apply(it, rec, "buffs", 36, 36, false)
    eq("< 1 ⇒ 發光不畫", rec.stackGlowOn, nil)
    check("< 1 ⇒ 閘全藏", g1.gate.shown == false and g2.gate.shown == false)
    local sets1 = g1.gate.sets
    Fire(it, "RefreshApplications")
    eq("< 1 ⇒ 不餵", g1.gate.sets, sets1)
    SG.Feed(it, rec)
    eq("< 1 ⇒ 重新放格也不畫", rec.stackGlowOn, nil)
    overrides[25] = nil
    SG.Apply(it, rec, "buffs", 36, 36, false)
end

------------------------------------------------------------
-- 5. 沒設定的格：掛勾第一行就走、Apply 不建任何框
------------------------------------------------------------
do
    local before = #created
    local it = Item({ auraData = { applications = 3 }, active = true })
    local rec = Rec(it, "buffs", 30)
    local afterItem = #created
    SG.Apply(it, rec, "buffs", 36, 36, false)
    eq("沒設定 ⇒ 不建框", #created, afterItem)
    eq("沒設定 ⇒ rec.stackCfg nil", rec.stackCfg, nil)
    Fire(it, "RefreshApplications")
    eq("沒設定 ⇒ 不建框（掛勾後）", #created, afterItem)
    check("item 本身有建", afterItem > before)
    -- 核心技能的 item 不掛
    local it3 = Item({})
    local hooked = SG.hooked
    Rec(it3, "essential", 31)
    eq("不是增益的 item 不掛 RefreshApplications", SG.hooked, hooked)
    -- 自訂項目
    local it4 = Item({})
    ns.Viewers.frames[it4] = nil
    local rec4 = { custom = true, barKey = "buffs", cooldownID = "c:1", overlay = NewFrame("Frame") }
    SG.HookItem(it4, rec4)
    eq("自訂項目不掛", SG.hooked, hooked)
    overrides["c:1"] = { stackGlow = 2 }
    SG.Apply(it4, rec4, "buffs", 36, 36, false)
    eq("自訂項目沒有層數設定", rec4.stackCfg, nil)
    overrides["c:1"] = nil
end

------------------------------------------------------------
-- 6. 長條換色：閘一段一組、高的疊在上面、暴雪條調透明、停放還原
------------------------------------------------------------
do
    overrides[40] = { stackColors = {
        { at = 5, color = { r = 1, g = 0, b = 0, a = 1 } },
        { at = 2, color = { r = 0, g = 1, b = 0, a = 1 } },
    } }
    local S = Secret()
    local it = Item({ bar = true, auraData = { applications = S }, active = true })
    local rec = Rec(it, "buffbars", 40)
    SG.Apply(it, rec, "buffbars", 220, 20, true)
    local ui = rec.stackUI
    check("沒開發光就沒有發光閘", ui.glow == nil)
    local s1, s2 = ui.colors[1], ui.colors[2]
    eq("第 1 段是低門檻", s1.gate.max, 2); eq("第 2 段是高門檻", s2.gate.max, 5)
    check("高門檻疊在上面", s2.gate.level > s1.gate.level and s2.clip.level > s1.clip.level)
    check("整組在條身底下", s2.clip.level < 511 and ui.under.level < s1.gate.level)
    eq("色塊錨在暴雪條的填充貼圖", s1.tex.allPoints, it.Bar.fill)
    eq("原色填充也錨在暴雪條的填充貼圖", ui.under.base.allPoints, it.Bar.fill)
    eq("色塊顏色", s2.tex.color[1], 1)
    check("兩段都收到同一個秘密值", rawequal(s1.gate.value, S) and rawequal(s2.gate.value, S))
    eq("暴雪條的填充調透明", it.Bar.fill.color[4], 0)
    eq("暴雪條的底色調透明", it.Bar.BarBG.color[4], 0)
    eq("我們的底色照設定", ui.under.bg.color[4], 0.8)

    -- 無損刷新把條身換回原色之後重調
    it.Bar.fill:SetVertexColor(0.4, 0.6, 0.9, 1)
    SG.Reconceal(it, rec)
    eq("Reconceal 後又是透明", it.Bar.fill.color[4], 0)

    -- 停放：藏、還原暴雪條；重新放格：亮回來、再調透明
    G.OnParked(rec)
    eq("停放 ⇒ 根框藏", ui.under.shown, false)
    eq("停放 ⇒ 暴雪填充還原", it.Bar.fill.color[4], 1)
    eq("停放 ⇒ 暴雪底色還原", it.Bar.BarBG.color[4], 0.8)
    local sets = s1.gate.sets
    Fire(it, "RefreshApplications")
    eq("停放中掛勾不餵", s1.gate.sets, sets)
    SG.Feed(it, rec)
    eq("重新放格 ⇒ 根框亮", ui.under.shown, true)
    eq("重新放格 ⇒ 又是透明", it.Bar.fill.color[4], 0)
    check("重新放格 ⇒ 餵了", s1.gate.sets > sets)

    -- 少一段：多的藏起來（框留著重用）
    overrides[40].stackColors = { { at = 3, color = { r = 0, g = 0, b = 1, a = 1 } } }
    SG.Apply(it, rec, "buffbars", 220, 20, true)
    eq("同一顆閘重用", ui.colors[1], s1)
    eq("新門檻", s1.gate.max, 3)
    eq("多的那段藏起來", s2.gate.shown, false)

    -- 拿掉設定：全收、暴雪條還原
    overrides[40] = nil
    SG.Apply(it, rec, "buffbars", 220, 20, true)
    eq("拿掉設定 ⇒ rec.stackCfg nil", rec.stackCfg, nil)
    eq("拿掉設定 ⇒ 根框藏", ui.under.shown, false)
    eq("拿掉設定 ⇒ 暴雪填充還原", it.Bar.fill.color[4], 1)
end

------------------------------------------------------------
-- 6b. 層數當填充＋刻度：填充條取代時間層、色塊錨在填充條上、刻度位置照我們的條寬
------------------------------------------------------------
do
    overrides[41] = { stackBar = { max = 5 }, stackTicks = { at = { 1, 3, 9 }, color = { r = 1, g = 1, b = 1, a = 1 } },
        stackColors = { { at = 3, color = { r = 1, g = 0, b = 0, a = 1 } } } }
    local S = Secret()
    local it = Item({ bar = true, auraData = { applications = S }, active = true })
    it.Bar.Pip = Tex()
    local rec = Rec(it, "buffbars", 41)
    SG.Apply(it, rec, "buffbars", 220, 20, true)
    local ui = rec.stackUI
    local fb = ui.fillBar
    check("有填充條", fb ~= nil and fb.shown)
    eq("填充條 0～N（min）", fb.min, 0); eq("填充條 0～N（max）", fb.max, 5)
    check("填充條收到秘密層數原樣", rawequal(fb.value, S))
    eq("填充條錨在條身", fb.allPoints, it.Bar)
    eq("時間那層不畫", ui.under.base.shown, false)
    eq("填充條顏色照條", fb.fill.color[1], 0.4)
    eq("色塊錨在填充條的填充貼圖（不是暴雪的）", ui.colors[1].tex.allPoints, fb.fill)
    check("填充條在根框之上、色塊之下", fb.level > ui.under.level and fb.level < ui.colors[1].gate.level)
    local tf = ui.ticks
    check("刻度框在色塊之上、條身之下", tf.level > ui.colors[1].gate.level and tf.level < 511)
    local lines = tf.tickLines
    eq("只畫 1～N-1 的指定位置（1、3）", #lines, 2)
    -- 條身寬 ＝ 220 − 20（圖示）− 0（間距）＝ 200；x ＝ 200×k/5
    eq("第 1 條 x", lines[1].points[1][4], 40)
    eq("第 2 條 x", lines[2].points[1][4], 120)
    eq("刻度錨在條身左緣", lines[1].points[1][2], it.Bar)
    eq("刻度顏色", lines[1].color[1], 1)
    eq("暴雪火花調透明（跟時間走）", it.Bar.Pip.alpha, 0)
    eq("暴雪填充調透明", it.Bar.fill.color[4], 0)

    -- 條寬變了：刻度跟著重算（簽章有 w）
    SG.Apply(it, rec, "buffbars", 120, 20, true)
    eq("條寬 120 ⇒ 第 1 條 x 20", lines[1].points[1][4], 20)

    -- 改成全部：線數變多、池化重用
    local first = lines[1]
    overrides[41].stackTicks = { at = "all" }
    SG.Apply(it, rec, "buffbars", 120, 20, true)
    eq("all ⇒ 4 條", #tf.tickLines, 4)
    eq("貼圖重用", tf.tickLines[1], first)
    eq("預設顏色", tf.tickLines[1].color[4], 0.6)
    overrides[41].stackTicks = { at = { 2 } }
    SG.Apply(it, rec, "buffbars", 120, 20, true)
    eq("少了 ⇒ 多的藏", tf.tickLines[2].shown, false)

    -- 直向長條（F8c）：填充條轉直向、刻度改水平線（離底緣 y ＝ 條身長 × k/N）
    settings.bar.vertical = true
    local orient
    fb.SetOrientation = function(_, o) orient = o end
    overrides[41].stackTicks = { at = "all" }
    SG.Apply(it, rec, "buffbars", 20, 220, true)
    eq("直向：填充條直向", orient, "VERTICAL")
    -- 條身長 ＝ 220 − 20（圖示 w×w）＝ 200；第 1 條 y ＝ 40
    eq("直向：刻度錨底緣", tf.tickLines[1].points[1][1], "BOTTOMLEFT")
    eq("直向：第 1 條 y", tf.tickLines[1].points[1][5], 40)
    eq("直向：水平線的兩點", tf.tickLines[1].points[2][1], "BOTTOMRIGHT")
    settings.bar.vertical = nil
    SG.Apply(it, rec, "buffbars", 120, 20, true)
    eq("切回橫向：填充條橫向", orient, "HORIZONTAL")
    overrides[41].stackTicks = { at = { 2 } }

    -- 拿掉層數當填充（只留換色）：時間層回來、填充條藏、色塊改錨暴雪的填充
    overrides[41].stackBar = nil
    overrides[41].stackTicks = nil
    SG.Apply(it, rec, "buffbars", 220, 20, true)
    eq("時間層回來", ui.under.base.shown, true)
    eq("填充條藏", fb.shown, false)
    eq("色塊錨回暴雪填充", ui.colors[1].tex.allPoints, it.Bar.fill)
    eq("刻度框藏", tf.shown, false)

    -- 只有刻度：也是條身底下那一層（暴雪的調透明、我們畫底色）
    overrides[41] = { stackTicks = { at = "all", max = 4 } }
    SG.Apply(it, rec, "buffbars", 220, 20, true)
    eq("只有刻度 ⇒ 根框亮", ui.under.shown, true)
    eq("只有刻度 ⇒ 暴雪填充透明", it.Bar.fill.color[4], 0)
    eq("只有刻度 ⇒ 3 條", (function() local n = 0 for _, l in ipairs(tf.tickLines) do if l.shown then n = n + 1 end end return n end)(), 3)

    -- 停放還原
    G.OnParked(rec)
    eq("停放 ⇒ 暴雪填充還原", it.Bar.fill.color[4], 1)
    overrides[41] = nil
    SG.Apply(it, rec, "buffbars", 220, 20, true)
    eq("拿掉 ⇒ 根框藏", ui.under.shown, false)
end

------------------------------------------------------------
-- 6c. 預覽的假長條：層數當填充記 N、刻度畫在假條上；不適用時清掉
------------------------------------------------------------
do
    overrides[42] = { stackBar = { max = 4 }, stackTicks = { at = "all" } }
    local c = NewFrame("Frame")
    c.Bar = NewFrame("StatusBar", c)
    c.aura = true
    SG.ApplyPreview(c, "buffbars", 42, 220, 20)
    eq("預覽記著 N", c.stackPreviewMax, 4)
    eq("預覽刻度 3 條", #c.Bar.tickLines, 3)
    eq("預覽刻度錨在假條", c.Bar.tickLines[1].points[1][2], c.Bar)
    c.custom = "aura"
    SG.ApplyPreview(c, "buffbars", 42, 220, 20)
    eq("自訂光環格 ⇒ 沒有", c.stackPreviewMax, nil)
    eq("自訂光環格 ⇒ 刻度藏", c.Bar.tickLines[1].shown, false)
    overrides[42] = nil
end

------------------------------------------------------------
-- 7. 發光：停放熄、重新放格重畫；跟生效發光互斥；預覽走層數樣式
------------------------------------------------------------
do
    overrides[50] = { stackGlow = 2, activeGlow = true }
    local it = Item({ auraData = { applications = 3 }, active = true })
    local rec = Rec(it, "buffs", 50)
    rec.claimKey = "buffs"
    SG.Apply(it, rec, "buffs", 36, 36, false)
    check("層數發光畫著", rec.stackGlowOn ~= nil)
    G.SyncActive(it, rec, "buffs")
    check("開了層數發光 ⇒ 生效發光不畫", not (rec.glowOn and rec.glowOn.active))
    -- 層數發光關掉 ⇒ 生效發光回來
    overrides[50].stackGlow = nil
    SG.Apply(it, rec, "buffs", 36, 36, false)
    eq("層數發光關掉 ⇒ 宿主熄", rec.stackGlowOn, nil)
    G.SyncActive(it, rec, "buffs")
    check("層數發光關掉 ⇒ 生效發光亮", rec.glowOn and rec.glowOn.active ~= nil)
    overrides[50].stackGlow = 2
    SG.Apply(it, rec, "buffs", 36, 36, false)
    G.SyncActive(it, rec, "buffs")
    check("再開 ⇒ 生效發光熄", not (rec.glowOn and rec.glowOn.active))

    G.OnParked(rec)
    eq("停放 ⇒ 層數發光熄", rec.stackGlowOn, nil)
    eq("停放 ⇒ 閘藏", rec.stackUI.glow.gate.shown, false)
    SG.Feed(it, rec)
    check("重新放格 ⇒ 重畫", rec.stackGlowOn ~= nil)
    eq("重新放格 ⇒ 閘亮", rec.stackUI.glow.gate.shown, true)

    -- 預覽：層數發光開著 ⇒ 照它的樣式（顏色覆寫）
    overrides[50].stackGlowColor = { r = 0, g = 0, b = 1, a = 1 }
    local host = NewFrame("Frame")
    G.PreviewActive(host, "buffs", 50)
    local last = painted[#painted]
    check("預覽畫在 host 上", last.h == host)
    eq("預覽用層數發光的顏色", last.color[3], 1)
    -- 層數發光關掉：預覽換回生效發光
    overrides[50].stackGlow = nil
    G.PreviewActive(host, "buffs", 50)
    last = painted[#painted]
    eq("預覽換回生效發光的顏色（條層 glow.active）", last.color[1], 0.95)
    -- 自訂項目（字串 id）不走層數
    overrides["c:2"] = { stackGlow = 2 }
    local host2 = NewFrame("Frame")
    local n = #painted
    G.PreviewActive(host2, "buffs", "c:2")
    eq("自訂光環格的預覽不吃層數發光", #painted, n)
    overrides[50], overrides["c:2"] = nil, nil
end

------------------------------------------------------------
-- 7b. 冷卻格的生效發光：看 rec.auraFlag（暴雪正在倒增益時間），不看 IsActive
------------------------------------------------------------
do
    overrides[60] = { activeGlow = true }
    local it = Item({ active = true })
    local rec = Rec(it, "essential", 60)
    rec.claimKey = "essential"
    G.SyncActive(it, rec, "essential")
    check("冷卻格：沒在倒增益 ⇒ 不亮（IsActive 是真也不算）", not (rec.glowOn and rec.glowOn.active))
    rec.auraFlag = true
    G.SyncActive(it, rec, "essential")
    check("冷卻格：倒增益中 ⇒ 亮", rec.glowOn and rec.glowOn.active ~= nil)
    rec.auraFlag = false
    G.SyncActive(it, rec, "essential")
    check("冷卻格：增益掉了 ⇒ 熄", not (rec.glowOn and rec.glowOn.active))
    overrides[60].activeGlow = nil
    rec.auraFlag = true
    G.SyncActive(it, rec, "essential")
    check("冷卻格：沒開這個法術 ⇒ 不亮", not (rec.glowOn and rec.glowOn.active))
end

------------------------------------------------------------
-- 8. 已還給暴雪：什麼都不做
------------------------------------------------------------
do
    overrides[60] = { stackGlow = 2 }
    local it = Item({ auraData = { applications = 3 }, active = true })
    local rec = Rec(it, "buffs", 60)
    ns.released = true
    SG.Apply(it, rec, "buffs", 36, 36, false)
    eq("released ⇒ 不建", rec.stackCfg, nil)
    ns.released = nil
    overrides[60] = nil
end

check("debug 行組得出來", type(SG.DebugLine()) == "string")

print(("StackGate_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
