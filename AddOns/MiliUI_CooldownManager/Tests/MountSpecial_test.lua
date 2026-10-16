------------------------------------------------------------
-- 坐騎特效按鈕（Modules/MountSpecial.lua）的離線測試（不進 TOC）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/MountSpecial_test.lua
--
-- 覆蓋：
--   1. 預設值與面板登記（PANEL_KEYS／PANEL_ORDER 排最後／ConfigTable／DefaultFor／舊存檔合併）
--   2. 純函式：尺寸與字級夾值、跟著天空騎術條、位移夾值、顯示判斷（騎乘／載具／滑翔明文或秘密）
--   3. 上午版本的欄位搬家（skyriding.mountButton → mountspecial：對應、冪等、沒有舊表不動）
--   4. Visibility：EvaluatePanel 的 mountspecial 分支、PanelAlpha 不被「藏起冷卻管理器」藏、編輯模式全亮、關著不亮
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

local SECRET = setmetatable({}, {
    __tostring = function() return "<secret>" end,
    __eq = function() error("compared a secret") end,
    __lt = function() error("compared a secret") end,
    __le = function() error("compared a secret") end,
    __add = function() error("arithmetic on a secret") end,
})
local function IsSecret(v) return rawequal(v, SECRET) end

local Methods = {}
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
env.InCombatLockdown = function() return false end
env.CreateFrame = function(_, name) return Frame(name) end
env.UIParent = Frame("UIParent")
env.Enum = { CompressionMethod = { Deflate = 1 } }
env.C_Timer = { After = function() end }

-- 騎乘狀態的 API
local api = { mounted = true, vehicle = false, gliding = false }
env.IsMounted = function() return api.mounted end
env.UnitInVehicle = function() return api.vehicle end
env.UnitHasVehicleUI = function() return false end
env.C_PlayerInfo = { GetGlidingInfo = function() return api.gliding, true, 0 end }

local ns = {
    L = setmetatable({}, { __index = function(_, k) return k end }),
    IsSecret = IsSecret,
    RegisterCallback = function() end,
    Fire = function() end,
    Events = { Register = function() end, Unregister = function() end },
    Defer = function(fn, ...) fn(...) end,
    ReportError = function(e) print("ReportError: " .. tostring(e)) end,
    Write = function(frame, fn) fn(frame) return true end,
    P = { Scale = function(v) return v end, Pixel = function(v) return v end },
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
Load("Core/Visibility.lua")
Load("Modules/MountSpecial.lua")
local DB, Vis, MS = ns.DB, ns.Visibility, ns.MountSpecial

------------------------------------------------------------
-- 1. 預設值與面板登記
------------------------------------------------------------
local d = DB.BuildDefaults().profile
local md = d.mountspecial
check("預設：開、跟著天空騎術條", type(md) == "table" and md.enabled == true and md.followSky == true)
check("預設：錨在核心技能下方正中央 (0,-6)", type(md.anchor) == "table" and md.anchor.to == "essential" and md.anchor.point == "TOP"
    and md.anchor.relPoint == "BOTTOM" and md.anchor.x == 0 and md.anchor.y == -6)
check("預設：天空騎術條下方 (0,-6)、100×20、字級 12、MEDIUM", md.sky.x == 0 and md.sky.y == -6 and md.box.w == 100 and md.box.h == 20
    and md.fontSize == 12 and md.strata == "MEDIUM")
check("天空騎術的預設值不再帶 mountButton", d.skyriding.mountButton == nil)
check("PANEL_KEYS 有 mountspecial", DB.PANEL_KEYS.mountspecial == true and DB.IsPanel("mountspecial"))
eq("PANEL_ORDER：坐騎特效按鈕排最後", DB.PANEL_ORDER[#DB.PANEL_ORDER], "mountspecial")

ns.profile = DB.BuildDefaults().profile
local p = ns.profile
eq("ConfigTable(mountspecial)", DB.ConfigTable("mountspecial"), p.mountspecial)
eq("DefaultFor 字級", DB.DefaultFor("bar", "mountspecial", "fontSize"), 12)
eq("DefaultFor box.w", DB.DefaultFor("bar", "mountspecial", "box.w"), 100)
do
    local old = { theme = {}, castbar = { enabled = false }, bars = {}, skyriding = { enabled = false } }
    DB.MergeDefaults(old, DB.BuildDefaults().profile)
    check("舊存檔：補上 mountspecial（開著）", type(old.mountspecial) == "table" and old.mountspecial.enabled == true)
    check("舊存檔：天空騎術的值不動", old.skyriding.enabled == false)
end

------------------------------------------------------------
-- 2. 純函式
------------------------------------------------------------
local w, h, fs = MS.Dims({})
check("Dims：沒存 ＝ 100×20、12", w == 100 and h == 20 and fs == 12)
w, h, fs = MS.Dims({ box = { w = 9999, h = 1 }, fontSize = 99 })
check("Dims：夾值 400×12、40", w == 400 and h == 12 and fs == 40)
w, h, fs = MS.Dims(nil)
check("Dims：nil ＝ 預設", w == 100 and h == 20 and fs == 12)
eq("FollowSky：沒存 ＝ 開", MS.FollowSky({}), true)
eq("FollowSky：關", MS.FollowSky({ followSky = false }), false)
eq("FollowSky：不是表 ＝ 關", MS.FollowSky(nil), false)
local x, y = MS.SkyOffsetOf({})
check("SkyOffset：沒存 ＝ (0,-6)", x == 0 and y == -6)
x, y = MS.SkyOffsetOf({ sky = { x = -9999, y = 50 } })
check("SkyOffset：夾值 (-400, 50)", x == -400 and y == 50)

local on = { enabled = true }
eq("Shown：騎著、地面上 ⇒ 顯示", MS.Shown(on, { mounted = true, vehicle = false, gliding = false }), true)
eq("Shown：沒騎 ⇒ 藏", MS.Shown(on, { mounted = false, vehicle = false, gliding = false }), false)
eq("Shown：載具 ⇒ 藏", MS.Shown(on, { mounted = true, vehicle = true, gliding = false }), false)
eq("Shown：空中滑翔 ⇒ 藏", MS.Shown(on, { mounted = true, vehicle = false, gliding = true }), false)
eq("Shown：滑翔讀不到（nil）⇒ 藏", MS.Shown(on, { mounted = true, vehicle = false }), false)
eq("Shown：關掉 ⇒ 藏", MS.Shown({ enabled = false }, { mounted = true, vehicle = false, gliding = false }), false)
eq("Shown：沒存 enabled ＝ 開", MS.Shown({}, { mounted = true, vehicle = false, gliding = false }), true)
eq("Shown：狀態不是表 ⇒ 藏", MS.Shown(on, nil), false)

-- ReadState：秘密值一律當讀不到／不成立（不拿秘密比）
api.mounted, api.vehicle, api.gliding = true, false, false
local st = MS.ReadState()
check("ReadState：明文", st.mounted == true and st.vehicle == false and st.gliding == false)
api.gliding = SECRET
st = MS.ReadState()
eq("ReadState：isGliding 秘密 ⇒ nil", st.gliding, nil)
eq("Shown：isGliding 秘密 ⇒ 藏", MS.Shown(on, st), false)
api.mounted = SECRET
st = MS.ReadState()
eq("ReadState：IsMounted 秘密 ⇒ false", st.mounted, false)
api.mounted, api.gliding = true, false
env.C_PlayerInfo = nil
st = MS.ReadState()
eq("ReadState：沒有 GetGlidingInfo 的客戶端 ⇒ 不算滑翔", st.gliding, false)
env.C_PlayerInfo = { GetGlidingInfo = function() return api.gliding, true, 0 end }

------------------------------------------------------------
-- 3. 上午版本的欄位搬家
------------------------------------------------------------
do
    local cfg = DB.BuildDefaults().profile.mountspecial
    local sky = { mountButton = { enabled = false, width = 150, height = 30, x = 10, y = -20, size = 14 } }
    eq("Upgrade：有舊表 ⇒ 搬", MS.Upgrade(cfg, sky), true)
    check("Upgrade：開關、尺寸、字級、位移都對上", cfg.enabled == false and cfg.box.w == 150 and cfg.box.h == 30 and cfg.fontSize == 14
        and cfg.sky.x == 10 and cfg.sky.y == -20)
    eq("Upgrade：舊表清掉", sky.mountButton, nil)
    eq("Upgrade：再跑一次沒事（冪等）", MS.Upgrade(cfg, sky), false)
    check("Upgrade：再跑值不動", cfg.enabled == false and cfg.box.w == 150)
    local fresh = DB.BuildDefaults().profile.mountspecial
    eq("Upgrade：沒有舊表 ⇒ 不動", MS.Upgrade(fresh, { enabled = true }), false)
    check("Upgrade：沒有舊表值照預設", fresh.enabled == true and fresh.box.w == 100)
    eq("Upgrade：sky 不是表 ⇒ 不動", MS.Upgrade(fresh, nil), false)
    -- 舊表只有部分欄位：沒給的保留現值
    local part = DB.BuildDefaults().profile.mountspecial
    MS.Upgrade(part, { mountButton = { width = 120 } })
    check("Upgrade：只搬有的欄位", part.box.w == 120 and part.box.h == 20 and part.enabled == true and part.sky.y == -6)
end

------------------------------------------------------------
-- 4. Visibility
------------------------------------------------------------
local base = { combat = false, target = false, mounted = true, instance = false, group = "solo", mountButton = true }
eq("EvaluatePanel：該顯示 → 1", Vis.EvaluatePanel("mountspecial", { enabled = true }, base), 1)
eq("EvaluatePanel：關著 → 0", Vis.EvaluatePanel("mountspecial", { enabled = false }, base), 0)
eq("EvaluatePanel：上次判不顯示 → 0", Vis.EvaluatePanel("mountspecial", { enabled = true }, { mountButton = false }), 0)
eq("EvaluatePanel：不是表 → 0", Vis.EvaluatePanel("mountspecial", nil, base), 0)

-- PanelAlpha：天空騎術藏起冷卻管理器時，坐騎特效按鈕照亮；編輯模式全亮；關著 0；寵物對戰 0
ns.EditMode = { active = false }
p.mountspecial.enabled = true
local realVisible = MS.Visible
MS.Visible = function() return true end
local hide = { combat = false, target = false, mounted = true, petBattle = false, skyridingPanel = true, skyridingHideCdm = true, mountButton = true }
eq("PanelAlpha：藏起冷卻管理器時照亮", Vis.PanelAlpha("mountspecial", hide), 1)
eq("PanelAlpha：下一招圖示那種照樣被藏", Vis.PanelAlpha("castbar", hide), 0)
local shown = { combat = false, target = false, mounted = true, petBattle = false, mountButton = false }
eq("PanelAlpha：上次判不顯示 → 0", Vis.PanelAlpha("mountspecial", shown), 0)
eq("PanelAlpha：寵物對戰 → 0", Vis.PanelAlpha("mountspecial", { petBattle = true, mountButton = true }), 0)
ns.EditMode.active = true
eq("PanelAlpha：編輯模式全亮", Vis.PanelAlpha("mountspecial", shown), 1)
p.mountspecial.enabled = false
eq("PanelAlpha：關著編輯模式也不亮", Vis.PanelAlpha("mountspecial", shown), 0)
p.mountspecial.enabled = true
ns.EditMode.active = false
-- Snapshot 讀的是上次判的結果，不重讀 API
local s = Vis.Snapshot()
eq("Snapshot：mountButton 讀上次判斷", s.mountButton, true)
MS.Visible = function() return false end
s = Vis.Snapshot()
eq("Snapshot：變了跟著變", s.mountButton, false)
MS.Visible = realVisible
eq("Visible：沒 Refresh 過是 false", MS.Visible(), false)

print(("MountSpecial_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
