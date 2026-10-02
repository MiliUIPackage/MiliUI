------------------------------------------------------------
-- 戰鬥輔助（P2）的離線測試（不進 TOC）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/Assist_test.lua
--
-- 覆蓋：
--   1. 預設值（theme.assist、profile.assistIcon）、面板登記（PANEL_KEYS／PANEL_ORDER／ConfigTable／DefaultFor）、
--      舊存檔合併預設值後其他面板不受影響、錨定成環、刪條放開錨定
--   2. 下一招圖示的顯示條件（Visibility.EvaluatePanel 的 assistIcon 分支；既有三個面板不受第六個參數影響）、
--      編輯模式全亮、關著不亮
--   3. 「該不該輪詢」（Assist.ShouldPoll）、API 回傳的清洗（Normalize：秘密值不比較）、要亮的格（Targets）
--   4. 輪詢與醒目標示的流程（假 ticker、假 API、假法術索引、假 Glow）：開關、進出戰鬥、換建議、秘密值、
--      目標可攻擊／死了、API 不存在、醒目標示關掉全熄、AssistSpellChanged 廣播
--   5. Glow 的第四種發光 "assist"：預設色、G.Sync 不熄它、停放熄它、Counts 第五個值
--   6. 下一招圖示的尺寸夾值（AssistIcon.Size）
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

local env = setmetatable({}, { __index = _G })
env._G = env
env.UnitName = function() return "米利" end
env.GetRealmName = function() return "世界之樹" end
env.GetSpecialization = function() return 1 end
env.GetSpecializationInfo = function(i) return 60 + i end
env.UnitClass = function() return "聖騎士", "PALADIN", 2 end
env.GetLocale = function() return "zhTW" end
local combatLock = false
env.InCombatLockdown = function() return combatLock end
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

-- 單位狀態（Attackable 讀）
local unit = { exists = false, canAttack = false, dead = false }
env.UnitExists = function() return unit.exists end
env.UnitCanAttack = function() return unit.canAttack end
env.UnitIsDeadOrGhost = function() return unit.dead end

-- 戰鬥輔助的 API（nextID 可以是數字、nil、秘密值；throw ＝ 拋錯）
local api = { nextID = nil, throw = false, calls = 0, lastArg = "unset" }
local function MakeAPI()
    return { GetNextCastSpell = function(check)
        api.calls = api.calls + 1
        api.lastArg = check
        if api.throw then error("boom") end
        return api.nextID
    end }
end
env.C_AssistedCombat = MakeAPI()

-- 假 ticker：手動推一拍
local tickers = {}
env.C_Timer = {
    NewTicker = function(_, fn)
        local t = { fn = fn, cancelled = false }
        function t:Cancel() self.cancelled = true end
        tickers[#tickers + 1] = t
        return t
    end,
    After = function(_, fn) fn() end,
}
local function LiveTicker()
    for i = #tickers, 1, -1 do
        if not tickers[i].cancelled then return tickers[i] end
    end
    return nil
end
local function Tick()
    local t = LiveTicker()
    if t then t.fn() end
end

local handlers = {}
local fired = {}
local ns = {
    playerClass = "PALADIN",
    L = setmetatable({}, { __index = function(_, k) return k end }),
    IsSecret = IsSecret,
    RegisterCallback = function() end,
    Fire = function(event, ...) fired[#fired + 1] = { event = event, n = select("#", ...), ... } end,
    Events = {
        Register = function(event, key, fn) handlers[event] = handlers[event] or {}; handlers[event][key] = fn end,
        Unregister = function(event, key) if handlers[event] then handlers[event][key] = nil end end,
    },
    Defer = function(fn, ...) fn(...) end,
    ReportError = function(e) print("ReportError: " .. tostring(e)) end,
}
ns.Secret = { BarInterp = function() return nil end }
local function Fire(event, ...)
    for _, fn in pairs(handlers[event] or {}) do fn(...) end
end

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
local DB, Vis = ns.DB, ns.Visibility

------------------------------------------------------------
-- 1. 預設值與面板登記
------------------------------------------------------------
local d = DB.BuildDefaults().profile
local ta = d.theme.assist
check("主題預設：醒目標示關", type(ta) == "table" and ta.highlight == false)
check("主題預設：像素、8 條、2 粗、0.2", ta.type == "pixel" and ta.lines == 8 and ta.thickness == 2 and ta.frequency == 0.2)
check("主題預設：顏色 (0.25, 0.75, 1, 1)", ta.color.r == 0.25 and ta.color.g == 0.75 and ta.color.b == 1 and ta.color.a == 1)
check("主題：assist 不走條層繼承（不在 THEMED）", DB.THEMED.assist == nil)
local ai = d.assistIcon
check("圖示預設：關", type(ai) == "table" and ai.enabled == false)
check("圖示預設：位置 CENTER (0, -120)、不錨定", ai.pos.point == "CENTER" and ai.pos.x == 0 and ai.pos.y == -120 and ai.anchor == false)
check("圖示預設：44、只在戰鬥中、按鍵、GCD、MEDIUM", ai.size == 44 and ai.onlyCombat == true and ai.showKeybind == true
    and ai.showGCD == true and ai.strata == "MEDIUM")
check("PANEL_KEYS 有 assistIcon", DB.PANEL_KEYS.assistIcon == true and ns.PANEL_KEYS.assistIcon == true)
check("IsPanel(assistIcon)", DB.IsPanel("assistIcon"))
eq("PANEL_ORDER：排最後、前三個不變", table.concat(DB.PANEL_ORDER, ","), "resources,pips,castbar,assistIcon")

ns.profile = DB.BuildDefaults().profile
local p = ns.profile
eq("ConfigTable(assistIcon)", DB.ConfigTable("assistIcon"), p.assistIcon)
eq("ConfigTable(castbar) 照舊", DB.ConfigTable("castbar"), p.castbar)
eq("DefaultFor 圖示尺寸", DB.DefaultFor("bar", "assistIcon", "size"), 44)
eq("DefaultFor 圖示錨定", DB.DefaultFor("bar", "assistIcon", "anchor"), false)
check("DefaultFor 圖示位置是複本", DB.DefaultFor("bar", "assistIcon", "pos") ~= p.assistIcon.pos)
eq("DefaultFor 主題醒目標示", DB.DefaultFor("theme", nil, "assist.highlight"), false)
eq("ns.Setting 讀主題的 assist", ns.Setting("theme", "assist.type"), "pixel")

-- 舊存檔（沒有這兩張表）：合併預設值補上；其他面板的值不動
do
    local old = { theme = { font = "x" }, castbar = { enabled = false, height = 33 }, resources = { width = 123 },
                  bars = {}, pips = { enabled = false } }
    DB.MergeDefaults(old, DB.BuildDefaults().profile)
    check("舊存檔：補上 assistIcon（關著）", type(old.assistIcon) == "table" and old.assistIcon.enabled == false)
    check("舊存檔：補上 theme.assist（關著）", type(old.theme.assist) == "table" and old.theme.assist.highlight == false)
    check("舊存檔：施法條的值不動", old.castbar.enabled == false and old.castbar.height == 33)
    check("舊存檔：資源條／自訂格子的值不動", old.resources.width == 123 and old.pips.enabled == false)
    eq("舊存檔：圖示的 anchor 是 false（不灌表）", old.assistIcon.anchor, false)
end

-- 錨定：圖示錨在施法條上 ⇒ 施法條不能錨到圖示
p.assistIcon.anchor = { to = "castbar", point = "BOTTOM", relPoint = "TOP", x = 0, y = 1 }
check("施法條 → 下一招圖示會成環", DB.AnchorWouldCycle("castbar", "assistIcon"))
check("資源條 → 下一招圖示不會成環", not DB.AnchorWouldCycle("resources", "assistIcon"))
local g = DB.CreateBar("icons", "臨時")
p.assistIcon.anchor = { to = g, point = "TOP", relPoint = "BOTTOM", x = 0, y = -1 }
DB.DeleteBar(g)
eq("刪條：錨在它身上的下一招圖示放開", p.assistIcon.anchor, false)

------------------------------------------------------------
-- 2. 顯示條件
------------------------------------------------------------
local out = { combat = false, target = false, mounted = false, instance = false, group = "solo" }
local inC = { combat = true, target = false, mounted = false, instance = false, group = "solo" }
eq("圖示：關著 → 0", Vis.EvaluatePanel("assistIcon", { enabled = false, onlyCombat = false }, inC, 1, false, 123), 0)
eq("圖示：只在戰鬥中、脫戰 → 0", Vis.EvaluatePanel("assistIcon", { onlyCombat = true }, out, 1, false, 123), 0)
eq("圖示：只在戰鬥中、戰鬥中有建議 → 1", Vis.EvaluatePanel("assistIcon", { onlyCombat = true }, inC, 1, false, 123), 1)
eq("圖示：戰鬥中沒有建議 → 0", Vis.EvaluatePanel("assistIcon", { onlyCombat = true }, inC, 1, false, nil), 0)
eq("圖示：不限戰鬥、脫戰有建議 → 1", Vis.EvaluatePanel("assistIcon", { onlyCombat = false }, out, 1, false, 123), 1)
eq("圖示：onlyCombat 沒存 ＝ 預設開", Vis.EvaluatePanel("assistIcon", {}, out, 1, false, 123), 0)
eq("圖示：不是表 → 0", Vis.EvaluatePanel("assistIcon", nil, inC, 1, false, 123), 0)
eq("圖示：核心技能的淡出不帶過來", Vis.EvaluatePanel("assistIcon", { onlyCombat = false }, out, 0.3, false, 123), 1)
-- 既有三個面板：多給第六個參數不影響
eq("施法條：沒在施法 → 0（多給建議也一樣）", Vis.EvaluatePanel("castbar", { hideWhenNotCasting = true }, out, 1, false, 123), 0)
eq("資源條：跟核心技能淡（多給建議也一樣）", Vis.EvaluatePanel("resources", { fadeWithEssential = true }, out, 0.3, false, 123), 0.3)
eq("自訂格子：不跟 → 1（多給建議也一樣）", Vis.EvaluatePanel("pips", { fadeWithEssential = false }, out, 0.3, false, 123), 1)
-- PanelAlpha：編輯模式全亮（沒有建議也亮：畫問號）；關著的不亮
ns.EditMode = { active = true }
p.assistIcon.enabled = true
eq("PanelAlpha：編輯模式中全亮", Vis.PanelAlpha("assistIcon"), 1)
p.assistIcon.enabled = false
eq("PanelAlpha：關著的編輯模式中也是 0", Vis.PanelAlpha("assistIcon"), 0)
ns.EditMode = nil

------------------------------------------------------------
-- 3. 純函式
------------------------------------------------------------
Load("Core/Assist.lua")
local A = ns.Assist
local function S(t)
    local s = { api = true, highlight = false, icon = false, iconOnlyCombat = true, combat = false, attackable = false }
    for k, v in pairs(t or {}) do s[k] = v end
    return s
end
eq("ShouldPoll：都關 → 否", A.ShouldPoll(S{ combat = true, attackable = true }), false)
eq("ShouldPoll：醒目標示、戰鬥中 → 是", A.ShouldPoll(S{ highlight = true, combat = true }), true)
eq("ShouldPoll：醒目標示、脫戰有可攻擊目標 → 是", A.ShouldPoll(S{ highlight = true, attackable = true }), true)
eq("ShouldPoll：醒目標示、脫戰沒目標 → 否", A.ShouldPoll(S{ highlight = true }), false)
eq("ShouldPoll：只有圖示（只在戰鬥中）、脫戰有目標 → 否", A.ShouldPoll(S{ icon = true, attackable = true }), false)
eq("ShouldPoll：只有圖示（只在戰鬥中）、戰鬥中 → 是", A.ShouldPoll(S{ icon = true, combat = true }), true)
eq("ShouldPoll：只有圖示（不限戰鬥）、脫戰有目標 → 是", A.ShouldPoll(S{ icon = true, iconOnlyCombat = false, attackable = true }), true)
eq("ShouldPoll：只有圖示（不限戰鬥）、脫戰沒目標 → 否", A.ShouldPoll(S{ icon = true, iconOnlyCombat = false }), false)
eq("ShouldPoll：API 不存在 → 否", A.ShouldPoll(S{ api = false, highlight = true, combat = true }), false)
eq("ShouldPoll：不是表 → 否", A.ShouldPoll(nil), false)

eq("Normalize：正數", A.Normalize(12345, IsSecret), 12345)
eq("Normalize：nil", A.Normalize(nil, IsSecret), nil)
eq("Normalize：0", A.Normalize(0, IsSecret), nil)
eq("Normalize：負數", A.Normalize(-1, IsSecret), nil)
eq("Normalize：字串", A.Normalize("123", IsSecret), nil)
eq("Normalize：秘密值不比較、當沒有", A.Normalize(SECRET, IsSecret), nil)

local isAura = function(rec) return rec.barKey == "buffs" end
local rEss = { barKey = "essential" }
local rBuff = { barKey = "buffs" }
local rCSpell = { custom = true, kind = "spell", barKey = "custom" }
local rCItem = { custom = true, kind = "item", barKey = "custom" }
local rParked = { barKey = "essential", parked = true }
local rHidden = { custom = true, kind = "spell", hidden = true }
local entries = {
    { rec = rEss }, { rec = rBuff }, { rec = rCSpell }, { rec = rCItem }, { rec = rParked }, { rec = rHidden },
    { rec = rEss },                       -- 同一格又一次（spellID 與 overrideSpellID 都指到它）
    "壞資料", { owner = 1 },
}
local tg = A.Targets(entries, isAura)
eq("Targets：只留暴雪技能格與自訂法術", #tg, 2)
check("Targets：順序與內容", tg[1].rec == rEss and tg[2].rec == rCSpell)
eq("Targets：nil → 空", #A.Targets(nil, isAura), 0)

------------------------------------------------------------
-- 4. 輪詢與醒目標示的流程
------------------------------------------------------------
local lit, glowCalls = {}, { start = 0, stop = 0 }
ns.Glow = {
    Start = function(rec, which, _, c)
        assert(which == "assist")
        glowCalls.start = glowCalls.start + 1
        lit[rec] = c
    end,
    Stop = function(rec, which)
        assert(which == "assist")
        glowCalls.stop = glowCalls.stop + 1
        lit[rec] = nil
    end,
}
local index = {
    [100] = { { rec = rEss, key = "essential" }, { rec = rBuff, key = "buffs" } },
    [200] = { { rec = rCSpell, key = "g1" } },
}
ns.SpellIndex = { Lookup = function(id) return index[id] or {} end }
ns.Viewers = { AURA_KIND = { buffs = true, buffbars = true } }
local function LitCount()
    local n = 0
    for _ in pairs(lit) do n = n + 1 end
    return n
end
local function LastFired()
    local f = fired[#fired]
    return f and f.event, f and f[1]
end

p.theme.assist.highlight = false
p.assistIcon.enabled = false
A.Init()
eq("Init：都關 ⇒ 沒有 ticker", LiveTicker(), nil)
eq("Init：沒有建議", A.Current(), nil)

p.theme.assist.highlight = true
A.Refresh()
eq("醒目標示開、脫戰沒目標 ⇒ 沒有 ticker", LiveTicker(), nil)

api.nextID = 100
Fire("PLAYER_REGEN_DISABLED")
check("進戰鬥 ⇒ ticker 開", LiveTicker() ~= nil)
eq("開的那一刻就問一次（不等第一拍）", A.Current(), 100)
eq("問的是 checkForVisibleButton = false", api.lastArg, false)
check("建議 100 ⇒ 核心技能那格亮", lit[rEss] ~= nil)
eq("增益格不亮", lit[rBuff], nil)
eq("亮的格吃主題的 assist 表", lit[rEss], p.theme.assist)
local ev, arg1 = LastFired()
check("廣播 AssistSpellChanged(100)", ev == "AssistSpellChanged" and arg1 == 100)

local nFired = #fired
Tick()
eq("建議沒變 ⇒ 不廣播", #fired, nFired)
local startsBefore = glowCalls.start

api.nextID = 200
Tick()
eq("換建議 ⇒ 200", A.Current(), 200)
eq("舊的熄", lit[rEss], nil)
check("新的亮（自訂法術）", lit[rCSpell] ~= nil)
eq("只亮一格", LitCount(), 1)
check("換建議有畫新的", glowCalls.start > startsBefore)

api.nextID = 999                        -- 不在任何一條上
Tick()
eq("建議不在條上 ⇒ 什麼都不亮", LitCount(), 0)
eq("但建議照記（圖示要畫）", A.Current(), 999)

api.nextID = SECRET
Tick()
eq("秘密值 ⇒ 當沒有", A.Current(), nil)

api.throw = true
Tick()
eq("API 拋錯 ⇒ 當沒有、不炸", A.Current(), nil)
check("API 拋錯 ⇒ ticker 照跑（pcall 包著）", LiveTicker() ~= nil)
api.throw = false

api.nextID = 100
Tick()
check("回到 100 ⇒ 又亮", lit[rEss] ~= nil)
p.theme.assist.highlight = false
A.Reapply()
eq("醒目標示關掉 ⇒ 全熄", LitCount(), 0)
p.theme.assist.highlight = true
A.Reapply()
check("再打開 ⇒ 照目前建議亮回來", lit[rEss] ~= nil)

-- 脫戰、沒目標 ⇒ 停、建議清掉、全熄
Fire("PLAYER_REGEN_ENABLED")
eq("脫戰沒目標 ⇒ ticker 停", LiveTicker(), nil)
eq("停的時候建議清成 nil", A.Current(), nil)
eq("停的時候全熄", LitCount(), 0)
ev, arg1 = LastFired()
check("停的時候廣播 AssistSpellChanged(nil)", ev == "AssistSpellChanged" and fired[#fired].n == 1 and arg1 == nil)

-- 脫戰有可攻擊的目標 ⇒ 開；目標死了 ⇒ 下一拍自己停
unit.exists, unit.canAttack, unit.dead = true, true, false
Fire("PLAYER_TARGET_CHANGED")
check("脫戰、可攻擊的目標 ⇒ ticker 開", LiveTicker() ~= nil)
eq("而且有建議", A.Current(), 100)
unit.dead = true
Tick()
eq("目標死了 ⇒ 那一拍自己停", LiveTicker(), nil)
eq("目標死了 ⇒ 建議清掉", A.Current(), nil)
unit.dead = false
unit.canAttack = SECRET                  -- 秘密值 ⇒ 寧可多輪詢（當可攻擊）
Fire("PLAYER_TARGET_CHANGED")
check("可攻擊是秘密值 ⇒ 照樣輪詢", LiveTicker() ~= nil)
unit.canAttack = false
Fire("PLAYER_TARGET_CHANGED")
eq("友方目標 ⇒ 停", LiveTicker(), nil)
unit.exists = false

-- 只有圖示：只在戰鬥中 ⇒ 脫戰有目標也不輪詢；不限戰鬥 ⇒ 輪詢
p.theme.assist.highlight = false
p.assistIcon.enabled = true
unit.exists, unit.canAttack = true, true
A.Refresh()
eq("只有圖示（只在戰鬥中）、脫戰 ⇒ 不輪詢", LiveTicker(), nil)
p.assistIcon.onlyCombat = false
A.Refresh()
check("只有圖示（不限戰鬥）、脫戰有目標 ⇒ 輪詢", LiveTicker() ~= nil)
eq("醒目標示關著 ⇒ 有建議也不亮", LitCount(), 0)
p.assistIcon.enabled = false
A.Refresh()
eq("圖示也關 ⇒ 停", LiveTicker(), nil)

-- API 不存在 ⇒ 整個功能停用
p.theme.assist.highlight = true
env.C_AssistedCombat = nil
check("Available：沒有 API", not A.Available())
Fire("PLAYER_REGEN_DISABLED")
eq("API 不存在 ⇒ 不輪詢", LiveTicker(), nil)
env.C_AssistedCombat = MakeAPI()
check("Available：有 API", A.Available())
A.Refresh()
check("API 回來 ⇒ 輪詢", LiveTicker() ~= nil)
-- 重複 Refresh 不會多開 ticker
local nT = #tickers
A.Refresh()
A.Refresh()
eq("Refresh 冪等：不多開 ticker", #tickers, nT)
Fire("PLAYER_REGEN_ENABLED")
unit.exists = false
A.Refresh()
eq("收尾：停", LiveTicker(), nil)
check("DebugLine 是字串", type(A.DebugLine()) == "string")

------------------------------------------------------------
-- 5. Glow 的第四種發光
------------------------------------------------------------
local painted, stopped = {}, {}
ns.MiliUIGlow = {
    PixelGlow_Start = function(h, color, lines, freq, _, th, _, _, _, key)
        painted[#painted + 1] = { h = h, color = color, lines = lines, key = key, th = th }
    end,
    PixelGlow_Stop = function(h, key) stopped[#stopped + 1] = { h = h, key = key } end,
    AutoCastGlow_Stop = function() end, ButtonGlow_Stop = function() end, ProcGlow_Stop = function() end,
}
ns.Viewers = { AURA_KIND = { buffs = true, buffbars = true }, frames = {} }
ns.Custom = nil
ns.Sound = nil
ns.Decorate = nil
Load("Core/Glow.lua")
local G = ns.Glow
local ov = env.CreateFrame()
ov.level = 10
local grec = { overlay = ov, cooldownID = 5, barKey = "essential", claimKey = "essential", glowW = 40, glowH = 30 }
ns.Viewers.frames[{}] = grec
G.Start(grec, "assist", nil, {})
eq("assist：畫了一次", #painted, 1)
check("assist：預設色 (0.25, 0.75, 1)", painted[1].color[1] == 0.25 and painted[1].color[2] == 0.75 and painted[1].color[3] == 1)
eq("assist：key 是 assist", painted[1].key, "assist")
eq("assist：宿主層級在 overlay 上 3", grec.glowHosts.assist.level, 13)
G.Start(grec, "assist", nil, {})
eq("assist：同設定再叫不重畫", #painted, 1)
G.Sync({}, grec, "essential")
check("G.Sync 不熄 assist", grec.glowOn.assist ~= nil)
local _, _, _, _, nAssist = G.Counts()
eq("Counts 第五個值＝assist 格數", nAssist, 1)
G.OnParked(grec)
eq("停放熄 assist", grec.glowOn.assist, nil)
check("停放：Stop 的 key 是 assist", #stopped >= 1 and stopped[#stopped].key == "assist")
_, _, _, _, nAssist = G.Counts()
eq("Counts：熄了之後 0", nAssist, 0)

------------------------------------------------------------
-- 6. 下一招圖示的尺寸
------------------------------------------------------------
Load("Modules/AssistIcon.lua")
local AIc = ns.AssistIcon
eq("Size：沒存 → 44", AIc.Size({}), 44)
eq("Size：nil → 44", AIc.Size(nil), 44)
eq("Size：照存的", AIc.Size({ size = 60 }), 60)
eq("Size：太小夾到 16", AIc.Size({ size = 2 }), 16)
eq("Size：太大夾到 128", AIc.Size({ size = 999 }), 128)
eq("Size：字串照轉", AIc.Size({ size = "50" }), 50)
eq("Size：壞值 → 44", AIc.Size({ size = "x" }), 44)

print(("Assist_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
