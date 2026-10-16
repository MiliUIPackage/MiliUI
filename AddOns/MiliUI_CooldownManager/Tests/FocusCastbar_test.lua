------------------------------------------------------------
-- 專注目標施法條（面板 focuscast）的離線測試（不進 TOC）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/FocusCastbar_test.lua
--
-- 覆蓋：
--   1. 預設值（profile.focuscast：開、錨在施法條上方、三態顏色）、面板登記（PANEL_KEYS／PANEL_ORDER／ConfigTable／DefaultFor）、
--      舊存檔合併預設值補上（開著）、錨定成環、刪條放開錨定
--   2. 顯示條件（Visibility.EvaluatePanel 的 focuscast 分支跟施法條同一條；PanelAlpha 問 ns.FocusCastbar.IsActive 不問 ns.Castbar）
--   3. 排開（Layout.StackTarget）：預設貼施法條；施法條關掉接到核心技能、排在資源條那一串外面；增益圖示排到它外面；
--      專注目標施法條關掉時別人照舊
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
local env = setmetatable({}, { __index = _G })
env._G = env
env.UnitName = function() return "米利" end
env.GetRealmName = function() return "世界之樹" end
env.GetSpecialization = function() return 1 end
env.GetSpecializationInfo = function(i) return 60 + i end
env.UnitClass = function() return "聖騎士", "PALADIN", 2 end
env.GetLocale = function() return "zhTW" end
env.InCombatLockdown = function() return false end
env.GetTime = function() return 0 end
env.CreateFrame = function()
    local f = { level = 1 }
    function f:RegisterEvent() end
    function f:UnregisterEvent() end
    function f:SetScript() end
    function f:SetPoint() end
    function f:SetSize() end
    function f:SetFrameLevel(l) self.level = l end
    function f:GetFrameLevel() return self.level end
    return f
end
env.Enum = { CompressionMethod = { Deflate = 1 } }
env.C_Timer = { NewTicker = function() return { Cancel = function() end } end, After = function(_, fn) fn() end }

local handlers = {}
local ns = {
    playerClass = "PALADIN",
    L = setmetatable({}, { __index = function(_, k) return k end }),
    IsSecret = function() return false end,
    RegisterCallback = function() end,
    Fire = function() end,
    Events = {
        Register = function(event, key, fn) handlers[event] = handlers[event] or {}; handlers[event][key] = fn end,
        Unregister = function(event, key) if handlers[event] then handlers[event][key] = nil end end,
    },
    Defer = function(fn, ...) fn(...) end,
    ReportError = function(e) print("ReportError: " .. tostring(e)) end,
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
Load("Core/Layout.lua")
Load("Core/Visibility.lua")
local DB, Lay, Vis = ns.DB, ns.Layout, ns.Visibility

------------------------------------------------------------
-- 1. 預設值與面板登記
------------------------------------------------------------
local d = DB.BuildDefaults().profile
local fc = d.focuscast
check("預設：有這張表、關著（2026-10-16 改口）", type(fc) == "table" and fc.enabled == false)
check("預設：錨在施法條上方（這條的下緣貼施法條的上緣）", type(fc.anchor) == "table" and fc.anchor.to == "castbar"
    and fc.anchor.point == "BOTTOM" and fc.anchor.relPoint == "TOP")
check("預設：寬 0（跟核心技能第一列）、高 20、套組材質 MiliUI Satin", fc.width == 0 and fc.height == 20 and fc.texture == "MiliUI Satin")
check("預設：施法者名字、條尾斷法圖示都開", fc.showCaster == true and fc.showKick == true)
check("預設：三態顏色（就緒金、冷卻橘、不可中斷灰）", fc.colors.ready.r == 1 and fc.colors.ready.g == 0.741
    and fc.colors.cd.r == 0.906 and fc.colors.immune.r == 0.529)
check("預設：重要法術發光＋「!」、像素跑線", fc.glowImportant == true and fc.bangImportant == true and fc.glowStyle == "pixel")
check("預設：被打斷印斷法者、沒在施法時隱藏", fc.showInterrupter == true and fc.hideWhenNotCasting == true)
check("預設：pos 在施法條預設位置的上面一點", fc.pos.point == "CENTER" and fc.pos.y > d.castbar.pos.y)
check("PANEL_KEYS 有 focuscast", DB.PANEL_KEYS.focuscast == true and ns.PANEL_KEYS.focuscast == true)
check("IsPanel(focuscast)", DB.IsPanel("focuscast"))
eq("PANEL_ORDER：專注目標施法條緊接在施法條後面", table.concat(DB.PANEL_ORDER, ","), "resources,pips,custombars,procdeck,castbar,focuscast,assistIcon,skyriding,mountspecial")

ns.profile = DB.BuildDefaults().profile
local p = ns.profile
eq("ConfigTable(focuscast)", DB.ConfigTable("focuscast"), p.focuscast)
eq("DefaultFor 高度", DB.DefaultFor("bar", "focuscast", "height"), 20)
eq("DefaultFor 錨定目標", DB.DefaultFor("bar", "focuscast", "anchor").to, "castbar")
check("DefaultFor 位置是複本", DB.DefaultFor("bar", "focuscast", "pos") ~= p.focuscast.pos)

-- 舊存檔（沒有這張表）：合併預設值補上（開著）；其他面板的值不動
do
    local old = { theme = { font = "x" }, castbar = { enabled = false, height = 33 }, resources = { width = 123 }, bars = {} }
    DB.MergeDefaults(old, DB.BuildDefaults().profile)
    check("舊存檔：補上 focuscast（關著、錨施法條）", type(old.focuscast) == "table" and old.focuscast.enabled == false
        and old.focuscast.anchor.to == "castbar")
    check("舊存檔：施法條的值不動", old.castbar.enabled == false and old.castbar.height == 33)
end

-- 錨定：預設錨在施法條上 ⇒ 施法條不能錨到它；資源條可以
check("施法條 → 專注目標施法條會成環", DB.AnchorWouldCycle("castbar", "focuscast"))
check("資源條 → 專注目標施法條不會成環", not DB.AnchorWouldCycle("resources", "focuscast"))
check("專注目標施法條 → 核心技能不會成環", not DB.AnchorWouldCycle("focuscast", "essential"))
local g = DB.CreateBar("icons", "臨時")
p.focuscast.anchor = { to = g, point = "TOP", relPoint = "BOTTOM", x = 0, y = -1 }
DB.DeleteBar(g)
eq("刪條：錨在它身上的專注目標施法條放開", p.focuscast.anchor, false)
p.focuscast.anchor = { to = "castbar", point = "BOTTOM", relPoint = "TOP", x = 0, y = 1 }

------------------------------------------------------------
-- 2. 顯示條件
------------------------------------------------------------
local s = { combat = false, target = false, mounted = false, instance = false, group = "solo" }
eq("關著 → 0", Vis.EvaluatePanel("focuscast", { enabled = false, hideWhenNotCasting = false }, s, 1, true), 0)
eq("沒在施法 → 0", Vis.EvaluatePanel("focuscast", { hideWhenNotCasting = true }, s, 1, false), 0)
eq("施法中 → 1", Vis.EvaluatePanel("focuscast", { hideWhenNotCasting = true }, s, 1, true), 1)
eq("不隱藏 → 1", Vis.EvaluatePanel("focuscast", { hideWhenNotCasting = false }, s, 1, false), 1)
eq("hideWhenNotCasting 沒存 ＝ 預設隱藏", Vis.EvaluatePanel("focuscast", {}, s, 1, false), 0)
eq("核心技能的淡出不帶過來", Vis.EvaluatePanel("focuscast", { hideWhenNotCasting = false }, s, 0.3, false), 1)
-- PanelAlpha：問的是 ns.FocusCastbar.IsActive，不是玩家施法條（預設關，這一段先打開）
p.focuscast.enabled = true
ns.EditMode = { active = false }
ns.Castbar = { IsActive = function() return true end }
ns.FocusCastbar = { IsActive = function() return false end }
eq("PanelAlpha：玩家在唱、專注目標沒在唱 → 0", Vis.PanelAlpha("focuscast", s), 0)
eq("PanelAlpha：玩家施法條照自己的", Vis.PanelAlpha("castbar", s), 1)
ns.FocusCastbar.IsActive = function() return true end
eq("PanelAlpha：專注目標在唱 → 1", Vis.PanelAlpha("focuscast", s), 1)
ns.EditMode.active = true
ns.FocusCastbar.IsActive = function() return false end
eq("PanelAlpha：編輯模式全亮", Vis.PanelAlpha("focuscast", s), 1)
ns.EditMode.active = false
p.focuscast.enabled = false
eq("PanelAlpha：關著 → 0", Vis.PanelAlpha("focuscast", s), 0)
p.focuscast.enabled = true           -- 後面的排開測試用自己的 cfg，這裡留開著無妨

------------------------------------------------------------
-- 3. 排開
------------------------------------------------------------
do
    local ABOVE = function(to, off) return { to = to, point = "BOTTOM", relPoint = "TOP", x = 0, y = off or 1 } end
    local BELOW = function(to, off) return { to = to, point = "TOP", relPoint = "BOTTOM", x = 0, y = off or -1 } end
    local RANK = { resources = 1, pips = 2, utility = 3, castbar = 4, focuscast = 4.5, buffs = 5, buffbars = 6, essential = 7 }
    local function rank(k) return RANK[k] or 100 end
    local function resolver(cfg)
        local keys = {}
        for k in pairs(cfg) do keys[#keys + 1] = k end
        table.sort(keys)
        local function cfgOf(k) return cfg[k] end
        return function(k) return Lay.StackTarget(k, cfgOf, keys, rank) end
    end
    local cfg = {
        essential = { anchor = false },
        resources = { enabled = true, anchor = ABOVE("essential") },
        castbar   = { enabled = true, anchor = ABOVE("essential") },
        focuscast = { enabled = true, anchor = ABOVE("castbar") },
        buffs     = { enabled = true, anchor = ABOVE("essential") },
        pips      = { enabled = true, anchor = BELOW("essential") },
        utility   = { enabled = true, anchor = BELOW("essential") },
    }
    local T = resolver(cfg)
    eq("預設：施法條貼資源條外面", T("castbar"), "resources")
    eq("預設：專注目標施法條貼施法條", T("focuscast"), "castbar")
    eq("預設：增益圖示排到專注目標施法條外面", T("buffs"), "focuscast")
    cfg.focuscast.enabled = false
    eq("專注目標施法條關掉：增益圖示貼回施法條", T("buffs"), "castbar")
    cfg.focuscast.enabled = true
    cfg.castbar.enabled = false
    eq("施法條關掉：專注目標施法條接到核心技能、貼資源條外面", T("focuscast"), "resources")
    eq("施法條關掉：增益圖示排到專注目標施法條外面", T("buffs"), "focuscast")
    cfg.castbar.enabled = true
    cfg.castbar.anchor = false
    eq("施法條自己擺：專注目標施法條照字面跟著它", T("focuscast"), "castbar")
    eq("施法條自己擺：增益圖示貼資源條外面", T("buffs"), "resources")
    cfg.castbar.anchor = ABOVE("essential")
    cfg.focuscast.anchor = BELOW("castbar")
    eq("改成施法條下方（那邊是資源條那一疊）：排到核心技能下方那一疊的最外面", T("focuscast"), "utility")
    cfg.focuscast.anchor = ABOVE("essential")
    eq("改錨核心技能上方：照排名排在施法條外面", T("focuscast"), "castbar")
end

------------------------------------------------------------
-- 4. 模組的純函式：顯示名字（施法者＋分隔＋法術名）、斷法圖示要不要畫；自帶材質的解析
------------------------------------------------------------
do
    local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end,
        __concat = function(a, b) return (type(a) == "table" and "<s>" or a) .. (type(b) == "table" and "<s>" or b) end })
    ns.IsSecret = function(v) return rawequal(v, SECRET) end
    env.C_CurveUtil = nil
    env.C_Spell = nil
    env.CreateFrame = function() error("module must not create frames at load") end
    env.GetLocale = function() return "enUS" end
    Load("Modules/Castbar.lua")
    Load("Modules/FocusCastbar.lua")
    local FC = ns.FocusCastbar
    eq("顯示名字：施法者＋法術", FC.DisplayName("張三", "治療鍊", true, 0), "張三: 治療鍊")
    eq("顯示名字：關掉施法者", FC.DisplayName("張三", "治療鍊", false, 0), "治療鍊")
    eq("顯示名字：沒有施法者", FC.DisplayName(nil, "治療鍊", true, 0), "治療鍊")
    eq("顯示名字：截字只截法術名", FC.DisplayName("張三", "Fireball", true, 4), "張三: Fire…")
    eq("顯示名字：秘密的施法者只串接", FC.DisplayName(SECRET, "治療鍊", true, 3), "<s>: 治療鍊")
    eq("顯示名字：秘密的法術名不截", FC.DisplayName("張三", SECRET, true, 3), "張三: <s>")
    ns.Interrupt = { SpellID = function() return 57994 end }
    eq("斷法圖示：有斷法、開著 → 法術 ID", FC.KickSpell({ showKick = true }), 57994)
    eq("斷法圖示：關掉 → nil", FC.KickSpell({ showKick = false }), nil)
    eq("斷法圖示：沒存 ＝ 開", FC.KickSpell({}), 57994)
    ns.Interrupt.SpellID = function() return nil end
    eq("斷法圖示：這個專精沒有斷法 → nil", FC.KickSpell({ showKick = true }), nil)
    env.LibStub = nil
    Load("Core/Media.lua")
    eq("自製材質：名字直接解到自己的檔（不問 LSM）", ns.Media.Texture("MiliUI Satin"), ns.Media.BAR_TEXTURE)
    check("自製材質：路徑在本插件的 Media", ns.Media.BAR_TEXTURE:find("MiliUI_CooldownManager\\Media\\miliui_satin.png", 1, true) ~= nil)
    eq("材質：solid 照舊", ns.Media.Texture("solid"), ns.Media.WHITE8X8)
    -- v11：只上線一天的舊名字換成自製的；玩家自己選的不碰
    local m = { focuscast = { texture = "MiliUI TukTex" } }
    DB.MIGRATIONS[11](m)
    eq("v11：舊名字換成 MiliUI Satin", m.focuscast.texture, "MiliUI Satin")
    local m3 = { focuscast = { texture = "MiliUI Glass" } }
    DB.MIGRATIONS[11](m3)
    eq("v11：Glass 也換成 Satin", m3.focuscast.texture, "MiliUI Satin")
    local m2 = { focuscast = { texture = "Smooth" } }
    DB.MIGRATIONS[11](m2)
    eq("v11：玩家選的材質不動", m2.focuscast.texture, "Smooth")
    DB.MIGRATIONS[11]({})
    check("v11：沒有這張表不報錯", true)
    check("DB_VERSION 升到 12", ns.DB_VERSION == 12)
    local v = { focuscast = { enabled = true } }
    DB.MIGRATIONS[12](v)
    eq("v12：10-15 那版寫進存檔的開翻成關", v.focuscast.enabled, false)
    local v2 = { focuscast = { enabled = false } }
    DB.MIGRATIONS[12](v2)
    eq("v12：本來就關的不動", v2.focuscast.enabled, false)
    DB.MIGRATIONS[12]({})
    check("v12：沒有這張表不報錯", true)
end

print(("FocusCastbar_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
