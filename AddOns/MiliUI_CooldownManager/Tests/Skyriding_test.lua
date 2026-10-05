------------------------------------------------------------
-- 天空騎術面板（Modules/Skyriding.lua）的離線測試（不進 TOC）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/Skyriding_test.lua
--
-- 覆蓋：
--   1. 預設值與面板登記（PANEL_KEYS／PANEL_ORDER 排最後／ConfigTable／舊存檔合併）
--   2. 顯示判斷 SR.Evaluate／SR.Active：秘密值或讀不到、德比賽跑、地面上充能全滿、專用動作條、
--      舊的獨立插件還載著（blocked）、兩排都關、API 拋錯
--   3. 版面：兩排都開／只開一排的高與 y、上下對調、格數（明文 maxCharges、讀不到 6、上限）
--   4. 速度：百分比換算、地區最高速度（巨龍群島系／競速／其他）、平滑、換色狀態（增益優先、時間啟發式容差）
--   5. 旋轉急衝的顯示時機
--   6. 接力的錨定決定（SR.RelayPlace）：資源條正常、關掉／收合、沒有錨定、錨定指回自己
--   7. Bars：接力時的實際錨點（資源條正常／關掉／收合／沒錨定）、不參與排開（StackKeys／StackTarget）、
--      不當別人的錨定目標；獨立擺放照常排開
--   8. Visibility：hideCdm 對條與面板 alpha 的影響（編輯模式不套用、天空騎術自己不受影響）、
--      舊插件還載著時面板編輯模式也是 0
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
-- 環境
------------------------------------------------------------
-- 秘密值的替身：任何比較／算術都會拋錯（用來證明程式沒有拿它比）
local SECRET = setmetatable({}, {
    __tostring = function() return "<secret>" end,
    __eq = function() error("compared a secret") end,
    __lt = function() error("compared a secret") end,
    __le = function() error("compared a secret") end,
    __add = function() error("arithmetic on a secret") end,
})
local function IsSecret(v) return rawequal(v, SECRET) end

-- 假框：記錄錨點與尺寸，其他方法一律 no-op
local Methods = {}
function Methods:SetPoint(p, rel, rp, x, y) self.points[#self.points + 1] = { p, rel, rp, x, y } end
function Methods:ClearAllPoints() self.points = {} end
function Methods:SetSize(w, h) self.w, self.h = w, h end
function Methods:GetSize() return self.w, self.h end
function Methods:Show() self.shown = true end
function Methods:Hide() self.shown = false end
function Methods:IsShown() return self.shown end
function Methods:GetFrameLevel() return 1 end
local function Frame(name)
    local f = { points = {}, w = 1, h = 1, shown = true, name = name }
    return setmetatable(f, { __index = function(_, k) return Methods[k] or function() end end })
end

local env = setmetatable({}, { __index = _G })
env._G = env
env.GetLocale = function() return "zhTW" end
env.UnitName = function() return "米利" end
env.GetRealmName = function() return "世界之樹" end
env.GetSpecialization = function() return 1 end
env.GetSpecializationInfo = function(i) return 60 + i end
local combat = false
env.InCombatLockdown = function() return combat end
env.CreateFrame = function(_, name) return Frame(name) end
env.UIParent = Frame("UIParent")
env.Enum = { CompressionMethod = { Deflate = 1 } }
env.C_Timer = { After = function() end }          -- 排程不跑（只驗結構級的直接套用）

-- 天空騎術的 API 狀態
local api = {
    powerBar = 631, bonusIndex = 0, bonusOffset = 0,
    gliding = false, canGlide = true, speed = 0,
    charges = 6, maxCharges = 6, throw = false,
}
env.UnitPowerBarID = function() if api.throw then error("boom") end return api.powerBar end
env.GetBonusBarIndex = function() return api.bonusIndex end
env.GetBonusBarOffset = function() return api.bonusOffset end
env.C_PlayerInfo = { GetGlidingInfo = function()
    if api.throw then error("boom") end
    return api.gliding, api.canGlide, api.speed
end }
env.C_Spell = { GetSpellCharges = function(id)
    if id ~= 372608 then return nil end
    return { currentCharges = api.charges, maxCharges = api.maxCharges, cooldownDuration = 10 }
end }
local now = 0
env.GetTime = function() now = now + 1; return now end    -- 每次都是新的一幀（不吃 memo）

local ns = {
    L = setmetatable({}, { __index = function(_, k) return k end }),
    IsSecret = IsSecret,
    RegisterCallback = function() end,
    Fire = function() end,
    Events = { Register = function() end, Unregister = function() end },
    Defer = function(fn, ...) fn(...) end,
    ReportError = function(e) print("ReportError: " .. tostring(e)) end,
    Write = function(frame, fn) fn(frame) return true end,
    Style = { ApplyPanel = function() end },
    P = { Scale = function(v) return v end },
}
ns.Secret = { BarInterp = function() return nil end }

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

Load("Core/DB.lua")
Load("Core/Layout.lua")
Load("Core/Visibility.lua")
Load("Modules/Skyriding.lua")
local DB, Vis, SR = ns.DB, ns.Visibility, ns.Skyriding

------------------------------------------------------------
-- 1. 預設值與面板登記
------------------------------------------------------------
local d = DB.BuildDefaults().profile
local sd = d.skyriding
check("預設值：有 skyriding 表", type(sd) == "table")
eq("預設：開", sd.enabled, true)
eq("預設：接力", sd.placement, "relay")
eq("預設：藏起冷卻管理器", sd.hideCdm, true)
eq("預設：不錨定", sd.anchor, false)
eq("預設：寬 0", sd.width, 0)
eq("預設：迴旋衝刺冷卻中才顯示", sd.surge, "cooldown")
check("PANEL_KEYS 有 skyriding", DB.PANEL_KEYS.skyriding == true and DB.IsPanel("skyriding"))
eq("PANEL_ORDER：排最後", DB.PANEL_ORDER[#DB.PANEL_ORDER], "skyriding")
ns.profile = d
eq("ConfigTable(skyriding)", DB.ConfigTable("skyriding"), d.skyriding)
do
    local old = { theme = {}, bars = {} }
    DB.MergeDefaults(old, DB.BuildDefaults().profile)
    check("舊存檔：補上 skyriding", type(old.skyriding) == "table" and old.skyriding.placement == "relay")
    eq("舊存檔：anchor 是 false（不灌表）", old.skyriding.anchor, false)
end

------------------------------------------------------------
-- 2. 顯示判斷
------------------------------------------------------------
local function St(t)
    local s = { blocked = false, powerBarID = 631, bonusIndex = 0, bonusOffset = 0,
                canGlide = true, isGliding = true, charges = 3, maxCharges = 6 }
    for k, v in pairs(t or {}) do s[k] = v end
    return s
end
local cfg = { enabled = true, hideGroundedFull = true }
local E = SR.Evaluate
eq("飛行中 → 顯示", E(cfg, St()), true)
eq("舊插件還載著 → 不顯示", E(cfg, St{ blocked = true }), false)
eq("關掉 → 不顯示", E({ enabled = false }, St()), false)
eq("兩排都關 ＝ 關掉", E({ showSpeed = false, showCharges = false }, St()), false)
eq("只開一排照常", E({ showSpeed = false }, St()), true)
eq("德比賽跑 → 不顯示", E(cfg, St{ powerBarID = 650 }), false)
do
    local st = St()
    st.powerBarID = nil
    eq("能量條 ID 讀不到 → 不顯示", E(cfg, st), false)
end
eq("能量條 ID 秘密 → 不顯示（不比較）", E(cfg, St{ powerBarID = SECRET }), false)
eq("沒有能量條（0）而且不在專用動作條 → 不顯示", E(cfg, St{ powerBarID = 0 }), false)
eq("canGlide 秘密 → 不顯示", E(cfg, St{ canGlide = SECRET, isGliding = true }), false)
eq("canGlide false → 不顯示", E(cfg, St{ canGlide = false }), false)
eq("專用動作條（11／5）→ 不看 canGlide", E(cfg, St{ canGlide = false, bonusIndex = 11, bonusOffset = 5 }), true)
eq("動作條 offset 不對 → 看 canGlide", E(cfg, St{ canGlide = false, bonusIndex = 11, bonusOffset = 1 }), false)
eq("地面上充能全滿 → 不顯示", E(cfg, St{ isGliding = false, charges = 6 }), false)
eq("地面上在回充 → 顯示", E(cfg, St{ isGliding = false, charges = 4 }), true)
eq("地面上充能全滿、hideGroundedFull 關 → 顯示", E({ hideGroundedFull = false }, St{ isGliding = false, charges = 6 }), true)
eq("isGliding 秘密 ＝ 地面上；充能全滿 → 不顯示", E(cfg, St{ isGliding = SECRET, charges = 6 }), false)
eq("地面上、充能秘密 → 不顯示（讀不到當不成立）", E(cfg, St{ isGliding = false, charges = SECRET }), false)
do
    local st = St{ isGliding = false }
    st.charges, st.maxCharges = nil, nil
    eq("地面上、充能讀不到 → 不顯示", E(cfg, st), false)
end
eq("飛行中、充能秘密 → 照樣顯示（不需要讀充能）", E(cfg, St{ charges = SECRET, maxCharges = SECRET }), true)
eq("不是表 → 不顯示", E(cfg, nil), false)

-- SR.Active：經過 API
ns.profile = DB.BuildDefaults().profile
api.gliding, api.charges = true, 6
eq("Active：飛行中", SR.Active(), true)
api.gliding = false
eq("Active：地面上充能全滿", SR.Active(), false)
api.charges = 2
eq("Active：地面上在回充", SR.Active(), true)
api.powerBar = 650
eq("Active：德比賽跑", SR.Active(), false)
api.powerBar = 631
api.throw = true
eq("Active：API 拋錯 → 不顯示", SR.Active(), false)
api.throw = false
ns.falconBlocked = true
eq("Active：舊插件還載著", SR.Active(), false)
ns.falconBlocked = nil
eq("HidesCdm：顯示中＋開著", SR.HidesCdm(true), true)
eq("HidesCdm：沒顯示", SR.HidesCdm(false), false)
ns.profile.skyriding.hideCdm = false
eq("HidesCdm：關掉", SR.HidesCdm(true), false)
ns.profile.skyriding.hideCdm = true

------------------------------------------------------------
-- 3. 版面
------------------------------------------------------------
do
    local g = SR.Geometry({ speedHeight = 8, chargeHeight = 10, gap = 1, speedOnTop = true })
    eq("兩排：總高", g.h, 19)
    eq("兩排：速度在上 y", g.speedY, 0)
    eq("兩排：充能 y", g.chargeY, 9)
    g = SR.Geometry({ speedHeight = 8, chargeHeight = 10, gap = 1, speedOnTop = false })
    eq("對調：充能 y", g.chargeY, 0)
    eq("對調：速度 y", g.speedY, 11)
    g = SR.Geometry({ speedHeight = 8, chargeHeight = 10, gap = 3, showSpeed = false })
    eq("只開充能：高（不加間距）", g.h, 10)
    eq("只開充能：速度高 0", g.speedH, 0)
    eq("只開充能：y", g.chargeY, 0)
    g = SR.Geometry({ speedHeight = 8, chargeHeight = 10, gap = 3, showCharges = false })
    eq("只開速度：高", g.h, 8)
    eq("只開速度：y", g.speedY, 0)
    g = SR.Geometry({})
    eq("沒存：預設 8＋1＋10", g.h, 19)
    g = SR.Geometry({ speedHeight = 999, chargeHeight = -3, gap = 99 })
    eq("夾值：速度 40", g.speedH, 40)
    eq("夾值：充能 1", g.chargeH, 1)
    eq("夾值：間距 20", g.gap, 20)

    eq("格數：明文 6", SR.CellCount(6), 6)
    eq("格數：明文 5", SR.CellCount(5), 5)
    eq("格數：讀不到 6", SR.CellCount(nil), 6)
    eq("格數：秘密 6", SR.CellCount(SECRET), 6)
    eq("格數：上限 12", SR.CellCount(40), 12)
    eq("格數：0 → 6", SR.CellCount(0), 6)
end

------------------------------------------------------------
-- 4. 速度
------------------------------------------------------------
eq("百分比：7 碼 ＝ 100%", SR.SpeedPct(7), 100)
eq("百分比：65 碼", SR.SpeedPct(65), 929)
eq("百分比：0 不顯示", SR.SpeedPct(0), nil)
eq("百分比：秘密不顯示", SR.SpeedPct(SECRET), nil)
eq("最高速：巨龍群島 100", SR.SpeedMax(2444, false), 100)
eq("最高速：甦醒海岸 2569 100", SR.SpeedMax(2569, false), 100)
eq("最高速：其他 85", SR.SpeedMax(2552, false), 85)
eq("最高速：競速中 100", SR.SpeedMax(2552, true), 100)
eq("最高速：讀不到 85", SR.SpeedMax(nil, false), 85)
eq("最高速：秘密 85（不當 key）", SR.SpeedMax(SECRET, false), 85)
eq("平滑：第一次直接到位", SR.Smooth(nil, 40), 40)
eq("平滑：往目標靠一半", SR.Smooth(40, 60), 50)
eq("平滑：夠近就到位", SR.Smooth(59.98, 60), 60)
eq("換色：天空之悅增益", SR.SpeedState(true, false, 10), "thrill")
eq("換色：增益優先於時間", SR.SpeedState(false, true, 5), "skim")
eq("換色：時間 6.003 → 天空之悅", SR.SpeedState(false, false, 6.003), "thrill")
eq("換色：時間 6.02（容差內）→ 天空之悅", SR.SpeedState(false, false, 6.02), "thrill")
eq("換色：時間 8.28 → 貼地", SR.SpeedState(false, false, 8.28), "skim")
eq("換色：時間 8.3（容差內）→ 貼地", SR.SpeedState(false, false, 8.3), "skim")
eq("換色：時間 10.35 → 一般", SR.SpeedState(false, false, 10.35), "low")
eq("換色：秘密時間 → 一般", SR.SpeedState(false, false, SECRET), "low")
eq("換色：讀不到 → 一般", SR.SpeedState(false, false, nil), "low")

------------------------------------------------------------
-- 5. 旋轉急衝
------------------------------------------------------------
eq("off：永遠不顯示", SR.SurgeShown("off", true), false)
eq("always：讀不到也顯示", SR.SurgeShown("always", nil), true)
eq("cooldown：冷卻中", SR.SurgeShown("cooldown", true), true)
eq("cooldown：好了", SR.SurgeShown("cooldown", false), false)
eq("cooldown：讀不到 → 不顯示", SR.SurgeShown("cooldown", nil), false)
eq("ready：好了", SR.SurgeShown("ready", false), true)
eq("ready：冷卻中", SR.SurgeShown("ready", true), false)
eq("ready：讀不到 → 不顯示", SR.SurgeShown("ready", nil), false)
eq("冷卻判斷：公共冷卻不算", SR.SurgeOnCooldown(1.5), false)
eq("冷卻判斷：真的冷卻", SR.SurgeOnCooldown(30), true)
eq("冷卻判斷：0 ＝ 好了", SR.SurgeOnCooldown(0), false)
eq("冷卻判斷：秘密 → nil", SR.SurgeOnCooldown(SECRET), nil)

------------------------------------------------------------
-- 6. 接力的錨定決定
------------------------------------------------------------
do
    local res = { anchor = { to = "essential", point = "BOTTOM", relPoint = "TOP", x = 0, y = 1 },
                  pos = { point = "CENTER", x = 5, y = -180 } }
    local kind, t = SR.RelayPlace(res, true, "BOTTOM")
    eq("資源條正常：錨", kind, "anchor")
    check("資源條正常：貼資源條的固定邊（BOTTOM 對 BOTTOM）", t.to == "resources" and t.point == "BOTTOM" and t.relPoint == "BOTTOM" and t.x == 0 and t.y == 0)
    kind, t = SR.RelayPlace(res, true, "TOP")
    check("資源條往下長：TOP 對 TOP", t.point == "TOP" and t.relPoint == "TOP")
    kind, t = SR.RelayPlace(res, true)
    check("沒給固定邊：預設 BOTTOM", t.point == "BOTTOM" and t.relPoint == "BOTTOM")
    kind, t = SR.RelayPlace(res, false)
    eq("資源條關掉／收合：用資源條的錨定", kind, "anchor")
    check("資源條關掉：同樣的 to／point／relPoint／x／y",
        t.to == "essential" and t.point == "BOTTOM" and t.relPoint == "TOP" and t.x == 0 and t.y == 1)
    res.anchor = false
    kind, t = SR.RelayPlace(res, false)
    eq("資源條沒錨定：pos", kind, "pos")
    check("資源條沒錨定：資源條的 pos", t.point == "CENTER" and t.x == 5 and t.y == -180)
    res.anchor = { to = "skyriding", point = "BOTTOM", relPoint = "TOP" }
    kind = SR.RelayPlace(res, false)
    eq("資源條錨在天空騎術上（成環）：退回 pos", kind, "pos")
    kind, t = SR.RelayPlace(nil, false)
    check("資源條沒有設定表：pos 預設 CENTER", kind == "pos" and t.point == "CENTER")
end

------------------------------------------------------------
-- 7. Bars：接力的實際錨點、排開
------------------------------------------------------------
do
    ns.profile = DB.BuildDefaults().profile
    local p = ns.profile
    ns.Layout.Snap = ns.Layout.Snap or function(v) return v end
    Load("Core/Bars.lua")
    local B = ns.Bars
    B.RegisterPanel("resources", { anchorPoint = "BOTTOM", collapsible = true })
    B.RegisterPanel("castbar", { anchorPoint = "CENTER" })
    B.RegisterPanel("skyriding", { anchorPoint = "TOP" })
    local sky, res, ess = B.Get("skyriding"), B.Get("resources"), B.Get("essential")
    local function Pt(f) return f.points[#f.points] or {} end
    -- 半像素補正（Bars 的 HalfPixelFix）最多加半個像素
    local function near(v, want) return type(v) == "number" and math.abs(v - want) <= 0.5 end

    check("接力：B.SkyRelay", B.SkyRelay())
    local pt = Pt(sky)
    check("接力：貼資源條的固定邊（BOTTOM 對 BOTTOM）", pt[1] == "BOTTOM" and pt[2] == res and pt[3] == "BOTTOM" and pt[4] == 0 and pt[5] == 0,
        tostring(pt[1]) .. "/" .. tostring(pt[3]))
    eq("接力：自己沒有排開目標", B.StackTarget("skyriding"), nil)

    -- 排開：施法條照舊貼在資源條外面（天空騎術不在疊裡）
    eq("接力：施法條排在資源條外面", B.StackTarget("castbar"), "resources")

    -- 資源條關掉：照資源條自己的錨定（核心技能上緣、y 1）
    p.resources.enabled = false
    B.ApplyStructure("resources")
    pt = Pt(sky)
    check("資源條關掉：貼核心技能（資源條的錨定）", pt[1] == "BOTTOM" and pt[2] == ess and pt[3] == "TOP" and pt[5] == 1)
    p.resources.enabled = true
    B.ApplyStructure("resources")
    pt = Pt(sky)
    check("資源條開回來：貼回資源條", pt[2] == res and pt[1] == "BOTTOM")

    -- 資源條收合（collapsible 面板高度 0）：同關掉
    B.SetPanelSize("resources", 100, 0)
    check("資源條收合：IsCollapsed", B.IsCollapsed("resources"))
    pt = Pt(sky)
    check("資源條收合：改用資源條的錨定", pt[2] == ess and pt[1] == "BOTTOM")
    B.SetPanelSize("resources", 100, 14)
    pt = Pt(sky)
    check("資源條展開：貼回資源條", pt[2] == res)

    -- 資源條關掉而且沒錨定：資源條的 pos、資源條的錨點那一邊
    p.resources.enabled = false
    p.resources.anchor = false
    p.resources.pos = { point = "CENTER", x = 3, y = -150 }
    B.ApplyStructure("resources")
    pt = Pt(sky)
    check("資源條沒錨定：貼 UIParent、資源條的錨點", pt[1] == "BOTTOM" and pt[2] == env.UIParent and pt[3] == "CENTER"
        and near(pt[4], 3) and near(pt[5], -150), table.concat({ tostring(pt[1]), tostring(pt[2] and pt[2].name), tostring(pt[3]), tostring(pt[4]), tostring(pt[5]) }, " "))
    p.resources.enabled = true
    p.resources.anchor = { to = "essential", point = "BOTTOM", relPoint = "TOP", x = 0, y = 1 }
    B.ApplyStructure("resources")

    -- 別人錨在接力中的天空騎術上：當它不存在（改用自己的 pos）
    p.castbar.anchor = { to = "skyriding", point = "BOTTOM", relPoint = "TOP", x = 0, y = 1 }
    eq("接力：別人不能錨在它身上", B.StackTarget("castbar"), nil)
    p.castbar.anchor = { to = "essential", point = "BOTTOM", relPoint = "TOP", x = 0, y = 1 }

    -- 獨立擺放：錨在核心技能上方 ⇒ 參與排開，排在資源條外面、施法條裡面
    p.skyriding.placement = "standalone"
    p.skyriding.anchor = { to = "essential", point = "BOTTOM", relPoint = "TOP", x = 0, y = 1 }
    check("獨立：不是接力", not B.SkyRelay())
    eq("獨立：天空騎術貼在資源條外面", B.StackTarget("skyriding"), "resources")
    eq("獨立：施法條改貼天空騎術外面", B.StackTarget("castbar"), "skyriding")
    B.SkyPlacementChanged()
    pt = Pt(sky)
    check("獨立：照自己的錨定貼（貼排開算出來的資源條）", pt[1] == "BOTTOM" and pt[2] == res and pt[3] == "TOP")
    p.skyriding.anchor = false
    p.skyriding.pos = { point = "CENTER", x = 0, y = -100 }
    B.ApplyStructure("skyriding")
    pt = Pt(sky)
    check("獨立、沒錨定：自己的 pos", pt[2] == env.UIParent and near(pt[5], -100))
    eq("獨立、沒錨定：施法條回到資源條外面", B.StackTarget("castbar"), "resources")
    p.skyriding.placement = "relay"
    B.SkyPlacementChanged()
    pt = Pt(sky)
    check("切回接力：貼回資源條", pt[2] == res and pt[1] == "BOTTOM")
end

------------------------------------------------------------
-- 8. Visibility：hideCdm
------------------------------------------------------------
do
    ns.profile = DB.BuildDefaults().profile
    ns.Setting = function() return nil end
    ns.EditMode = { active = false }
    local function S(t)
        local s = { combat = false, target = false, mounted = false, instance = false, group = "solo",
                    enemy = false, skyriding = false, housing = false, resting = false, vehicle = false,
                    skyridingPanel = false, skyridingHideCdm = false }
        for k, v in pairs(t or {}) do s[k] = v end
        return s
    end
    local on = S{ skyridingPanel = true, skyridingHideCdm = true }
    local keep = S{ skyridingPanel = true, skyridingHideCdm = false }
    eq("藏冷卻管理器：條 0", Vis.Alpha("essential", on), 0)
    eq("藏冷卻管理器：自訂條也 0", Vis.Alpha("buffs", on), 0)
    eq("hideCdm 關：條照常", Vis.Alpha("essential", keep), 1)
    eq("藏冷卻管理器：資源條 0", Vis.PanelAlpha("resources", on, 1), 0)
    eq("藏冷卻管理器：施法條 0", Vis.PanelAlpha("castbar", on), 0)
    eq("藏冷卻管理器：天空騎術自己 1", Vis.PanelAlpha("skyriding", on), 1)
    eq("天空騎術沒顯示：0", Vis.PanelAlpha("skyriding", S()), 0)
    eq("EvaluatePanel：Active → 1", Vis.EvaluatePanel("skyriding", { enabled = true }, on), 1)
    eq("EvaluatePanel：關掉 → 0", Vis.EvaluatePanel("skyriding", { enabled = false }, on), 0)
    ns.EditMode.active = true
    eq("編輯模式：條不套 hideCdm", Vis.Alpha("essential", on), 1)
    eq("編輯模式：資源條不套 hideCdm", Vis.PanelAlpha("resources", on, 1), 1)
    eq("編輯模式：天空騎術全亮", Vis.PanelAlpha("skyriding", S()), 1)
    ns.falconBlocked = true
    eq("舊插件還載著：天空騎術編輯模式也 0", Vis.PanelAlpha("skyriding", S()), 0)
    ns.falconBlocked = nil
    ns.EditMode.active = false

    -- Snapshot 帶上兩個欄位：讀的是 SR.Shown（上次 Refresh 判斷的結果），不重讀 API
    local SRm = ns.Skyriding
    local realShown = SRm.Shown
    local shown = true
    SRm.Shown = function() return shown end
    api.gliding, api.charges, api.powerBar, api.canGlide = true, 3, 631, true
    local s = Vis.Snapshot()
    eq("Snapshot：skyridingPanel", s.skyridingPanel, true)
    eq("Snapshot：skyridingHideCdm", s.skyridingHideCdm, true)
    ns.profile.skyriding.hideCdm = false
    s = Vis.Snapshot()
    eq("Snapshot：hideCdm 關", s.skyridingHideCdm, false)
    api.canGlide = false               -- API 變了但還沒 Refresh：快照照舊讀上次的結果
    s = Vis.Snapshot()
    eq("Snapshot：不重讀 API", s.skyridingPanel, true)
    shown = false
    s = Vis.Snapshot()
    eq("Snapshot：不在天空騎術", s.skyridingPanel, false)
    SRm.Shown = realShown
    eq("Shown：沒 Refresh 過是 false", SRm.Shown(), false)
end

print(("Skyriding_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
