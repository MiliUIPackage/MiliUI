------------------------------------------------------------
-- 天空騎術面板（Modules/Skyriding.lua）的離線測試（不進 TOC）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/Skyriding_test.lua
--
-- 覆蓋：
--   1. 預設值與面板登記（PANEL_KEYS／PANEL_ORDER 排最後／ConfigTable／舊存檔合併）
--   2. 顯示判斷 SR.Evaluate／SR.Active：秘密值或讀不到、德比賽跑、地面上充能全滿、專用動作條、
--      舊的獨立插件還載著（blocked）、四列都關、API 拋錯
--   3. 版面：照 order 排四列、關掉的列不佔高也不多間距、四列都關＝關、order 的清洗與上下移、格數（活力：明文、讀不到 6；
--      重新振作：明文、讀不到 3）、活力底層疊不疊／文字來源、旋轉急衝秒數、圖示設定的清洗
--   3b. 發佈前的欄位搬家（SR.Upgrade）：每個舊欄位的對應、圖示一律關、冪等、沒有舊欄位不動、跑完舊欄位都是 nil
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
eq("預設：旋轉急衝圖示不顯示（有長條）", sd.rows.surge.icon.mode, "off")
eq("預設：圖示不在面板層", sd.surge, nil)
eq("預設：地面上充能全滿不隱藏", sd.hideGroundedFull, false)
eq("沒存 hideGroundedFull ＝ 關：地面上全滿照樣顯示", SR.Evaluate({ enabled = true }, { powerBarID = 631, bonusIndex = 11, bonusOffset = 5, isGliding = false, charges = 6, maxCharges = 6 }), true)
eq("預設順序", table.concat(sd.order, ","), "speed,surge,vigor,secondWind")
eq("預設：速度條開", sd.rows.speed.enabled, true)
eq("預設：旋轉急衝長條開", sd.rows.surge.enabled, true)
eq("預設：活力開", sd.rows.vigor.enabled, true)
eq("預設：重新振作關", sd.rows.secondWind.enabled, false)
eq("預設：電光開", sd.rows.surge.fx, true)
eq("預設：電光是閃電樣式", sd.rows.surge.fxStyle, "lightning")
eq("預設：填滿震動開", sd.rows.surge.shake, true)
eq("預設：旋轉急衝秒數開", sd.rows.surge.text.show, true)
eq("預設：活力文字開", sd.rows.vigor.text.show, true)
eq("預設：活力文字印活力", sd.rows.vigor.textSource, "vigor")
check("預設：活力文字白色、置中", sd.rows.vigor.text.color.r == 1 and sd.rows.vigor.text.anchor == "CENTER"
    and sd.rows.vigor.text.x == 0 and sd.rows.vigor.text.y == 0 and sd.rows.vigor.text.font == "INHERIT")
check("預設：速度文字靠右內縮 3", sd.rows.speed.text.anchor == "RIGHT" and sd.rows.speed.text.x == -3)
check("預設：材質跟資源條", sd.rows.speed.texture == "INHERIT" and sd.rows.vigor.bgTexture == "INHERIT")
check("預設：背景色 ＝ 資源條的暗底", sd.rows.speed.bgColor.r == 0.15 and sd.rows.speed.bgColor.a == 0.6)
check("預設：各列的背景色不是同一張表", sd.rows.speed.bgColor ~= sd.rows.vigor.bgColor)
check("預設：沒有第一階段的舊欄位", sd.speedOnTop == nil and sd.showSpeed == nil and sd.colors == nil and sd.chargeText == nil)
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
eq("四列都關 ＝ 關掉", E({ rows = { speed = { enabled = false }, surge = { enabled = false }, vigor = { enabled = false } } }, St()), false)
eq("只開重新振作照常", E({ rows = { speed = { enabled = false }, surge = { enabled = false }, vigor = { enabled = false },
    secondWind = { enabled = true } } }, St()), true)
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
eq("Active：地面上充能全滿（預設不隱藏）", SR.Active(), true)
ns.profile.skyriding.hideGroundedFull = true
eq("Active：地面上充能全滿、開了隱藏", SR.Active(), false)
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
    local function Rows(t)
        local r = {}
        for k, v in pairs(t) do r[k] = type(v) == "table" and v or { enabled = v } end
        return r
    end
    -- 預設順序：速度、旋轉急衝、活力（重新振作預設關）
    local g = SR.Geometry({ gap = 1, rows = Rows{ speed = { enabled = true, height = 8 }, surge = { enabled = true, height = 6 },
                                                  vigor = { enabled = true, height = 10 } } })
    eq("預設三列：清單", table.concat(g.list, ","), "speed,surge,vigor")
    eq("預設三列：速度 y", g.rows.speed.y, 0)
    eq("預設三列：旋轉急衝 y", g.rows.surge.y, 9)
    eq("預設三列：活力 y", g.rows.vigor.y, 16)
    eq("預設三列：總高 8+1+6+1+10", g.h, 26)
    eq("重新振作關：不佔位", g.rows.secondWind, nil)
    g = SR.Geometry({})
    eq("沒存：預設 8＋1＋6＋1＋10", g.h, 26)
    -- 照 order 排
    g = SR.Geometry({ gap = 2, order = { "vigor", "secondWind", "speed", "surge" },
                      rows = Rows{ secondWind = { enabled = true, height = 5 } } })
    eq("照 order：清單", table.concat(g.list, ","), "vigor,secondWind,speed,surge")
    eq("照 order：重新振作 y", g.rows.secondWind.y, 12)
    eq("照 order：速度 y", g.rows.speed.y, 19)
    eq("照 order：總高 10+2+5+2+8+2+6", g.h, 35)
    -- 關掉的列不佔高也不多間距
    g = SR.Geometry({ gap = 3, rows = Rows{ speed = false, surge = false } })
    eq("只開活力：高（不加間距）", g.h, 10)
    eq("只開活力：y", g.rows.vigor.y, 0)
    g = SR.Geometry({ gap = 3, rows = Rows{ surge = false } })
    eq("中間那列關掉：活力緊接速度", g.rows.vigor.y, 11)
    check("四列都關：等同關掉", not SR.Enabled({ rows = Rows{ speed = false, surge = false, vigor = false, secondWind = false } }))
    check("只開重新振作：還算開著", SR.Enabled({ rows = Rows{ speed = false, surge = false, vigor = false, secondWind = true } }))
    -- order 的清洗
    eq("order 缺 key：補在後面", table.concat(SR.Order({ order = { "vigor" } }), ","), "vigor,speed,surge,secondWind")
    eq("order 多 key／重複：丟掉", table.concat(SR.Order({ order = { "x", "surge", "surge", 3, "speed" } }), ","), "surge,speed,vigor,secondWind")
    eq("order 不是表：預設", table.concat(SR.Order({ order = "bad" }), ","), "speed,surge,vigor,secondWind")
    -- 上下移
    local c = { order = { "speed", "surge", "vigor", "secondWind" } }
    eq("上移", SR.MoveRow(c, "vigor", -1), true)
    eq("上移後", table.concat(c.order, ","), "speed,vigor,surge,secondWind")
    eq("最上面不能再上移", SR.MoveRow(c, "speed", -1), false)
    eq("最下面不能再下移", SR.MoveRow(c, "secondWind", 1), false)
    c = { order = { "secondWind" } }
    SR.MoveRow(c, "secondWind", 1)
    eq("缺 key 的 order 移動：寫回完整清單", table.concat(c.order, ","), "speed,secondWind,surge,vigor")
    -- 夾值
    g = SR.Geometry({ gap = 99, rows = Rows{ speed = { enabled = true, height = 999 }, vigor = { enabled = true, height = -3 },
                                             surge = { enabled = true, height = 0 } } })
    eq("夾值：速度 40", g.rows.speed.h, 40)
    eq("夾值：活力 1", g.rows.vigor.h, 1)
    eq("夾值：旋轉急衝 1", g.rows.surge.h, 1)
    eq("夾值：間距 20", g.gap, 20)

    eq("格數：明文 6", SR.CellCount(6), 6)
    eq("格數：明文 5", SR.CellCount(5), 5)
    eq("格數：讀不到 6", SR.CellCount(nil), 6)
    eq("格數：秘密 6", SR.CellCount(SECRET), 6)
    eq("格數：上限 12", SR.CellCount(40), 12)
    eq("格數：0 → 6", SR.CellCount(0), 6)
    eq("重新振作格數：明文 3", SR.SecondWindCount(3), 3)
    eq("重新振作格數：明文 2", SR.SecondWindCount(2), 2)
    eq("重新振作格數：讀不到 3", SR.SecondWindCount(nil), 3)
    eq("重新振作格數：秘密 3", SR.SecondWindCount(SECRET), 3)
    eq("重新振作格數：0 → 3", SR.SecondWindCount(0), 3)
    eq("重新振作格數：上限 12", SR.SecondWindCount(99), 12)

    -- 活力：重新振作那一列開著不疊、關著疊；文字來源
    eq("重新振作列關：疊", SR.VigorOverlay({}), true)
    eq("重新振作列關（明寫）：疊", SR.VigorOverlay({ rows = Rows{ secondWind = false } }), true)
    eq("重新振作列開：不疊", SR.VigorOverlay({ rows = Rows{ secondWind = true } }), false)
    eq("文字來源：預設活力", SR.VigorTextValue({}, 4, 2), 4)
    eq("文字來源：重新振作", SR.VigorTextValue({ rows = { vigor = { textSource = "secondWind" } } }, 4, 2), 2)
    eq("文字來源：重新振作讀不到 → nil", SR.VigorTextValue({ rows = { vigor = { textSource = "secondWind" } } }, 4, nil), nil)
    check("文字來源：秘密值原樣回", rawequal(SR.VigorTextValue({}, SECRET, 2), SECRET))

    -- 旋轉急衝秒數
    eq("秒數：無條件進位", SR.SurgeSeconds(110.2, 100), 11)
    eq("秒數：最後一點點印 1", SR.SurgeSeconds(100.01, 100), 1)
    eq("秒數：好了 → nil", SR.SurgeSeconds(100, 100), nil)
    eq("秒數：秘密 → nil", SR.SurgeSeconds(SECRET, 100), nil)
    eq("秒數：讀不到 → nil", SR.SurgeSeconds(nil, 100), nil)
    eq("文字錨點：LEFT", SR.TextPoint("LEFT"), "LEFT")
    eq("文字錨點：不認得 → CENTER", SR.TextPoint("TOPLEFT"), "CENTER")

    -- 旋轉急衝圖示
    local m, sz, sd2 = SR.SurgeIcon({})
    check("圖示：沒存 ＝ 關、24、右", m == "off" and sz == 24 and sd2 == "RIGHT")
    m, sz, sd2 = SR.SurgeIcon({ rows = { surge = { icon = { mode = "always", size = 99, side = "TOP" } } } })
    check("圖示：一直顯示、夾值 64、上", m == "always" and sz == 64 and sd2 == "TOP")
    m = SR.SurgeIcon({ rows = { surge = { icon = { mode = "bogus" } } } })
    eq("圖示：不認得的模式 ＝ 關", m, "off")
end

------------------------------------------------------------
-- 3b. 發佈前的欄位搬家（SR.Upgrade）
------------------------------------------------------------
do
    local function Old()
        -- 第一階段的存檔：合併預設值已經補上 rows（新預設），舊欄位還在
        local c = DB.BuildDefaults().profile.skyriding
        c.speedOnTop, c.showSpeed, c.showCharges, c.surgeBar = false, false, true, false
        c.speedHeight, c.chargeHeight, c.surgeHeight = 9, 12, 4
        c.speedText = "LEFT"
        c.speedColorOnCharges = true
        c.surgeFx, c.surgeShake = false, false
        c.chargeText, c.chargeTextSize, c.chargeTextFont, c.chargeTextOffset = false, 15, "思源黑體", { x = 2, y = -1 }
        c.colors = { charge = { r = 0.1, g = 0.2, b = 0.3 }, secondWind = { r = 0.4, g = 0.5, b = 0.6 },
                     lowSpeed = { r = 0.7, g = 0.7, b = 0.7 }, groundSkim = { r = 0.8, g = 0.6, b = 0.1 },
                     thrill = { r = 0.2, g = 0.9, b = 0.2 }, surge = { r = 0, g = 1, b = 1 }, chargeText = { r = 1, g = 1, b = 0 } }
        c.surge, c.surgeSize, c.surgeSide = "cooldown", 30, "LEFT"
        return c
    end
    local c = Old()
    eq("Upgrade：有舊欄位 → true", SR.Upgrade(c), true)
    local r = c.rows
    eq("showSpeed → speed.enabled", r.speed.enabled, false)
    eq("showCharges → vigor.enabled", r.vigor.enabled, true)
    eq("surgeBar → surge.enabled", r.surge.enabled, false)
    eq("speedHeight → speed.height", r.speed.height, 9)
    eq("chargeHeight → vigor.height", r.vigor.height, 12)
    eq("surgeHeight → surge.height", r.surge.height, 4)
    check("speedText LEFT → 文字靠左內縮 3", r.speed.text.show == true and r.speed.text.anchor == "LEFT" and r.speed.text.x == 3)
    eq("speedColorOnCharges → vigor.speedColor", r.vigor.speedColor, true)
    eq("surgeFx → surge.fx", r.surge.fx, false)
    eq("surgeShake → surge.shake", r.surge.shake, false)
    eq("chargeText → vigor.text.show", r.vigor.text.show, false)
    eq("chargeTextSize → vigor.text.size", r.vigor.text.size, 15)
    eq("chargeTextFont → vigor.text.font", r.vigor.text.font, "思源黑體")
    check("chargeTextOffset → vigor.text.x／y", r.vigor.text.x == 2 and r.vigor.text.y == -1)
    eq("colors.charge → vigor.color", r.vigor.color.r, 0.1)
    eq("colors.secondWind → vigor.secondWindColor", r.vigor.secondWindColor.b, 0.6)
    eq("colors.secondWind → secondWind.color", r.secondWind.color.g, 0.5)
    check("兩個重新振作色不是同一張表", r.vigor.secondWindColor ~= r.secondWind.color)
    check("速度三色", r.speed.colors.low.r == 0.7 and r.speed.colors.skim.r == 0.8 and r.speed.colors.thrill.g == 0.9)
    eq("colors.surge → surge.color", r.surge.color.g, 1)
    eq("colors.chargeText → vigor.text.color", r.vigor.text.color.b, 0)
    eq("speedOnTop=false → 活力排最上", table.concat(c.order, ","), "vigor,speed,surge,secondWind")
    eq("舊圖示 cooldown → 搬完一律關", r.surge.icon.mode, "off")
    check("圖示尺寸／位置照搬", r.surge.icon.size == 30 and r.surge.icon.side == "LEFT")
    local leftover = {}
    for _, k in ipairs({ "speedOnTop", "showSpeed", "showCharges", "surgeBar", "speedHeight", "chargeHeight", "surgeHeight",
                         "speedText", "speedColorOnCharges", "surgeFx", "surgeShake", "chargeText", "chargeTextSize",
                         "chargeTextFont", "chargeTextOffset", "colors", "surge", "surgeSize", "surgeSide" }) do
        if c[k] ~= nil then leftover[#leftover + 1] = k end
    end
    eq("舊欄位全部清掉", table.concat(leftover, ","), "")
    -- 冪等：跑第二次什麼都不動
    r.surge.icon.mode = "always"            -- 玩家之後自己打開
    local snap = table.concat({ r.speed.height, r.vigor.height, tostring(r.speed.enabled), table.concat(c.order, ",") }, "|")
    eq("Upgrade 第二次 → false", SR.Upgrade(c), false)
    eq("第二次：值不變", table.concat({ r.speed.height, r.vigor.height, tostring(r.speed.enabled), table.concat(c.order, ",") }, "|"), snap)
    eq("新格式已經是 always：不被改", r.surge.icon.mode, "always")
    -- 沒有舊欄位：不動
    local fresh = DB.BuildDefaults().profile.skyriding
    fresh.rows.surge.icon.mode = "always"
    eq("新存檔：Upgrade → false", SR.Upgrade(fresh), false)
eq("新存檔：旋轉急衝預設高 12", fresh.rows.surge.height, 12)
eq("新存檔：rev 記到最新", fresh.rev, SR.REV)
do
    -- rev 1：旋轉急衝還是舊預設 6 的改 12；調過別的值不動；做過一次就不再改
    local c = DB.BuildDefaults().profile.skyriding
    c.rows.surge.height = 6
    SR.Upgrade(c)
    eq("rev 1：舊預設 6 → 12", c.rows.surge.height, 12)
    c.rows.surge.height = 6
    SR.Upgrade(c)
    eq("rev 1：做過之後玩家自己改回 6 不再動", c.rows.surge.height, 6)
    local d = DB.BuildDefaults().profile.skyriding
    d.rows.surge.height = 9
    SR.Upgrade(d)
    eq("rev 1：調過別的值不動", d.rows.surge.height, 9)
end
    eq("新存檔：圖示照舊", fresh.rows.surge.icon.mode, "always")
    eq("新存檔：order 照舊", table.concat(fresh.order, ","), "speed,surge,vigor,secondWind")
    -- speedText OFF、speedOnTop true（順序不動）
    c = DB.BuildDefaults().profile.skyriding
    c.speedText, c.speedOnTop = "OFF", true
    SR.Upgrade(c)
    eq("speedText OFF → 不顯示", c.rows.speed.text.show, false)
    eq("speedOnTop true：順序不動", table.concat(c.order, ","), "speed,surge,vigor,secondWind")
    eq("只有部分舊欄位：圖示照樣強制關", c.rows.surge.icon.mode, "off")
    eq("不是表：false", SR.Upgrade(nil), false)
    -- rows 整張不見的舊存檔也搬得過去
    c = { enabled = true, showSpeed = false }
    SR.Upgrade(c)
    eq("沒有 rows 也建得出來", c.rows.speed.enabled, false)
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
