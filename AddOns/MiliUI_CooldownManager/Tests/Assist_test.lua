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
--   5. Glow 的第四種發光 "assist"：預設色、G.Sync 不熄它、停放熄它、Counts 第五個值；
--      就緒發光看資源（ReadyGate、等資源→事件→亮、秘密值 fail-open、自訂物品不檢查、取消等待的四種情況）
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
-- 5b. 就緒發光看資源（glow.ready.requireUsable）
------------------------------------------------------------
do
    eq("ReadyGate：沒開 ⇒ now", G.ReadyGate(false, false), "now")
    eq("ReadyGate：開了、可用 ⇒ now", G.ReadyGate(true, true), "now")
    eq("ReadyGate：開了、不可用 ⇒ wait", G.ReadyGate(true, false), "wait")
    eq("ReadyGate：開了、讀不到 ⇒ now（fail-open）", G.ReadyGate(true, nil), "now")

    local origSetting, origSpell, origAfter = ns.Setting, ns.SpellSetting, env.C_Timer.After
    local origCatalog, origSound = ns.Catalog, ns.Sound
    local req = true
    ns.Setting = function(bk, path)
        if path == "glow.ready.requireUsable" then return req end
        return origSetting(bk, path)
    end
    ns.SpellSetting = function(bk, id, key, spec)
        if key == "readyGlow" then return true end
        return origSpell(bk, id, key, spec)
    end
    env.C_Timer.After = function() end          -- 計時熄不跑：只看「有沒有亮」
    ns.MiliUIGlow.ButtonGlow_Start = function() end   -- 就緒發光預設樣式是快捷鍵閃光
    ns.Catalog = { Info = function(id) return { spellID = id * 10 } end }
    local usable = {}
    env.C_Spell = { IsSpellUsable = function(id) return usable[id] end }
    local rang = 0
    ns.Sound = { WantsReady = function() return true end, OnReady = function() rang = rang + 1 end }
    local function Waiting() return handlers.SPELL_UPDATE_USABLE and handlers.SPELL_UPDATE_USABLE.glow_ready_wait ~= nil end
    local function NewRec(id, extra)
        local r = { overlay = env.CreateFrame(), cooldownID = id, barKey = "essential", claimKey = "essential", glowW = 30, glowH = 30 }
        for k, v in pairs(extra or {}) do r[k] = v end
        return r
    end

    local r = NewRec(7)
    usable[70] = false
    local fired0 = G.readyFired
    G.FireReady(r)
    eq("資源不夠：不亮", G.readyFired, fired0)
    eq("資源不夠：記等待", r.readyPending, 7)
    eq("資源不夠：音效照響", rang, 1)
    check("資源不夠：註冊 SPELL_UPDATE_USABLE", Waiting())
    eq("等待中一格", G.PendingCount(), 1)
    Fire("SPELL_UPDATE_USABLE")
    eq("還是不夠：還在等", G.readyFired, fired0)
    usable[70] = true
    Fire("UNIT_POWER_FREQUENT", "player")
    eq("夠了：亮", G.readyFired, fired0 + 1)
    check("夠了：發光開著", r.glowOn and r.glowOn.ready ~= nil)
    eq("夠了：清掉等待", r.readyPending, nil)
    eq("夠了：音效不重響", rang, 1)
    check("沒人等了：解除事件", not Waiting())
    G.CooldownStarted(r)

    -- 秘密值／讀不到 ⇒ 照舊立刻亮（不拿秘密值比較）
    local r2 = NewRec(8)
    usable[80] = SECRET
    G.FireReady(r2)
    eq("秘密值：立刻亮", G.readyFired, fired0 + 2)
    eq("秘密值：不等", r2.readyPending, nil)
    env.C_Spell = { IsSpellUsable = function() error("boom") end }
    local r3 = NewRec(9)
    G.FireReady(r3)
    eq("pcall 失敗：立刻亮", G.readyFired, fired0 + 3)
    env.C_Spell = { IsSpellUsable = function(id) return usable[id] end }

    -- 沒開資源檢查：不可用也立刻亮
    req = false
    local r4 = NewRec(10)
    usable[100] = false
    G.FireReady(r4)
    eq("沒開：不可用也亮", G.readyFired, fired0 + 4)
    req = true

    -- 自訂物品不檢查；自訂法術用自己的 spellID（覆寫優先）
    local r5 = NewRec("c:1", { custom = true, kind = "item", itemID = 5 })
    G.FireReady(r5)
    eq("自訂物品：直接亮", G.readyFired, fired0 + 5)
    local r6 = NewRec("c:2", { custom = true, kind = "spell", spellID = 600, overrideID = 601 })
    usable[600], usable[601] = true, false
    G.FireReady(r6)
    eq("自訂法術：問覆寫的那個", r6.readyPending, "c:2")
    G.CooldownStarted(r6)
    eq("又用掉了：取消等待", r6.readyPending, nil)
    eq("取消後沒人等", G.PendingCount(), 0)
    check("取消後解除事件", not Waiting())

    -- 停放／被藏／換身分 ⇒ 取消，不亮
    local r7 = NewRec(11)
    usable[110] = false
    G.FireReady(r7)
    G.OnParked(r7)
    eq("停放：取消等待", r7.readyPending, nil)
    local r8 = NewRec(12)
    usable[120] = false
    G.FireReady(r8)
    r8.hidden = true
    usable[120] = true
    local f8 = G.readyFired
    Fire("SPELL_UPDATE_USABLE")
    eq("被藏：不亮", G.readyFired, f8)
    eq("被藏：取消等待", r8.readyPending, nil)
    local r9 = NewRec(13)
    usable[130] = false
    G.FireReady(r9)
    r9.cooldownID = 14                 -- 暴雪把框回收給別的法術
    usable[130], usable[140] = true, true
    Fire("SPELL_UPDATE_USABLE")
    eq("換身分：不亮", G.readyFired, f8)
    eq("換身分：取消等待", r9.readyPending, nil)
    check("全部清掉：解除事件", not Waiting())

    ns.Setting, ns.SpellSetting, env.C_Timer.After = origSetting, origSpell, origAfter
    ns.Catalog, ns.Sound, env.C_Spell = origCatalog, origSound, nil
    ns.MiliUIGlow.ButtonGlow_Start = nil
end

------------------------------------------------------------
-- 5c. 效能修整 E3 #12：就緒時一直亮（明文分支）冷卻中直接熄、就緒才亮；秘密分支照舊
--     E3 #13：無損刷新掛勾的無事路徑
------------------------------------------------------------
do
    local origSpell, origCreate, origDecorate = ns.SpellSetting, env.CreateFrame, ns.Decorate
    ns.SpellSetting = function(bk, id, key, spec)
        if key == "readyGlowMode" then return "whileReady" end
        if key == "readyGlow" then return true end
        return origSpell(bk, id, key, spec)
    end
    env.CreateFrame = function(...)
        local f = origCreate(...)
        function f:SetAlpha(a) self.alpha = a; self.fromBool = nil end
        function f:SetAlphaFromBoolean(b, t, fa) self.fromBool = { b, t, fa } end
        return f
    end
    ns.MiliUIGlow.ButtonGlow_Start = function() end
    local state = { kind = "plain", v = true }
    local synced = 0
    ns.Decorate = {
        CooldownState = function() return state.kind, state.v end,
        CdWorkSync = function() synced = synced + 1 end,
        cdWork = {},
    }
    local r = { overlay = env.CreateFrame(), cooldownID = 21, barKey = "essential", claimKey = "essential", glowW = 30, glowH = 30 }
    local owner = {}
    -- 明文、冷卻中 ⇒ 不亮（沒畫）、readyWhile 照舊 true（旗標＝開著這個模式）
    G.ApplyReadyState(r, owner)
    eq("明文冷卻中：readyWhile 照舊 true", r.readyWhile, true)
    check("明文冷卻中：發光沒開", not (r.glowOn and r.glowOn.ready))
    eq("readyWhile 從無到有：同步 cdWork 一次", synced, 1)
    -- 轉好 ⇒ 亮、宿主 alpha 1
    state.v = false
    G.ApplyReadyState(r, owner)
    check("明文就緒：發光開著", r.glowOn and r.glowOn.ready ~= nil)
    eq("明文就緒：宿主 alpha 1", r.glowHosts.ready.alpha, 1)
    eq("readyWhile 沒翻：不再同步", synced, 1)
    -- 用掉 ⇒ 直接熄（不是 alpha 0 照跑）、宿主 alpha 還原 1
    state.v = true
    G.ApplyReadyState(r, owner)
    check("明文冷卻中（用掉）：發光熄了", not r.glowOn.ready)
    eq("明文冷卻中（用掉）：宿主 alpha 1", r.glowHosts.ready.alpha, 1)
    -- 秘密分支：發光開著、交給 SetAlphaFromBoolean
    state.kind, state.v = "secret", SECRET
    G.ApplyReadyState(r, owner)
    check("秘密：發光開著", r.glowOn.ready ~= nil)
    check("秘密：SetAlphaFromBoolean(值, 1, 0)", r.glowHosts.ready.fromBool and r.glowHosts.ready.fromBool[1] == SECRET
        and r.glowHosts.ready.fromBool[2] == 1 and r.glowHosts.ready.fromBool[3] == 0)
    -- 判不出來：發光開著、alpha 0（照舊）
    state.kind, state.v = nil, nil
    G.ApplyReadyState(r, owner)
    check("判不出來：發光開著", r.glowOn.ready ~= nil)
    eq("判不出來：宿主 alpha 0", r.glowHosts.ready.alpha, 0)
    -- 模式關掉 ⇒ readyWhile 清掉、熄、同步 cdWork
    ns.SpellSetting = function(bk, id, key, spec)
        if key == "readyGlowMode" then return "timed" end
        return origSpell(bk, id, key, spec)
    end
    G.ApplyReadyState(r, owner)
    eq("模式關掉：readyWhile 清掉", r.readyWhile, nil)
    eq("模式關掉：同步 cdWork", synced, 2)

    -- #13 無損刷新：狀態沒變只記呼叫次數
    local item = {}
    local prec = { claimKey = "essential", cooldownID = 31 }
    ns.Viewers.frames[item] = prec
    local applied = 0
    local origApply = G.ApplyPandemic
    G.ApplyPandemic = function() applied = applied + 1 end
    local c0, ch0 = G.pandemicCalls, G.pandemicChanges
    G.OnShowPandemic(item)
    G.OnShowPandemic(item)
    G.OnShowPandemic(item)
    eq("無損刷新：叫三次", G.pandemicCalls, c0 + 3)
    eq("無損刷新：只變一次", G.pandemicChanges, ch0 + 1)
    eq("無損刷新：只套一次", applied, 1)
    eq("無損刷新：狀態記上", prec.pandemic, true)
    G.OnHidePandemic(item)
    G.OnHidePandemic(item)
    eq("無損刷新：熄一次", applied, 2)
    eq("無損刷新：狀態清掉", prec.pandemic, false)
    G.OnShowPandemic({})                -- 不認得的框（動作條）：立刻走
    eq("不認得的框：不套", applied, 2)
    G.ApplyPandemic = origApply

    ns.SpellSetting, env.CreateFrame, ns.Decorate = origSpell, origCreate, origDecorate
    ns.MiliUIGlow.ButtonGlow_Start = nil
end

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

------------------------------------------------------------
-- 7. 暴雪冷卻格的觸發事件自己聽（減益鎖住 GetSpellID 時暴雪會丟掉事件、還會誤判熄掉）
------------------------------------------------------------
do
    local G = ns.Glow
    local origSync, origViewers, origCatalog = G.SyncProc, ns.Viewers, ns.Catalog
    local synced = {}
    G.SyncProc = function(item, rec) synced[#synced + 1] = { item = item, on = rec.procActive } end
    local items = {}
    ns.Viewers = {
        AURA_KIND = { buffs = true, buffbars = true },
        frames = {},
        EnumerateItems = function(fn) for item, rec in pairs(items) do fn(item, rec) end end,
    }
    local infos = { [7] = { spellID = 206930 }, [8] = { spellID = 999 }, [9] = { equipSlot = 13 } }
    ns.Catalog = { Info = function(id) return infos[id] end }
    local hs, other, buff, cust = {}, {}, {}, {}
    local hsRec = { cooldownID = 7, barKey = "essential" }
    items[hs] = hsRec
    items[other] = { cooldownID = 8, barKey = "essential" }
    items[buff] = { cooldownID = 7, barKey = "buffs" }
    items[cust] = { cooldownID = 7, barKey = "essential", custom = true }
    ns.Viewers.frames[hs] = hsRec
    env.C_SpellBook = { FindSpellOverrideByID = function(id) if id == 206930 then return 433895 end return id end }
    local overlayed = { [433895] = true }
    env.C_SpellActivationOverlay = { IsSpellOverlayed = function(id) return overlayed[id] == true end }

    G.OnOverlayEvent(true, 433895)
    eq("當下的覆蓋法術認得到 ⇒ 亮", hsRec.procActive, true)
    eq("記下認到的 id", hsRec.procEventID, 433895)
    eq("只同步命中的那格", #synced, 1)
    eq("別的法術不碰", items[other].procActive, nil)
    eq("增益條不碰", items[buff].procActive, nil)
    eq("自訂框不碰", items[cust].procActive, nil)
    G.OnOverlayEvent(true, 433895)
    eq("已經亮著 ⇒ 不重複同步", #synced, 1)

    -- 暴雪 RefreshData 拿減益的 id 問 ⇒ HideAlert：還在觸發就擋掉
    G.OnHideAlert(nil, hs)
    eq("暴雪誤判的 HideAlert 擋掉", hsRec.procActive, true)

    -- 觸發用掉：覆蓋已經換回去了，靠記下的 id 認
    env.C_SpellBook.FindSpellOverrideByID = function(id) return id end
    overlayed[433895] = nil
    G.OnOverlayEvent(false, 433895)
    eq("熄：覆蓋換回去也認得到", hsRec.procActive, false)
    eq("熄：清掉記下的 id", hsRec.procEventID, nil)

    -- 不是我們認到的觸發：暴雪的 HideAlert 照常
    hsRec.procActive = true
    G.OnHideAlert(nil, hs)
    eq("沒有記下的 id ⇒ HideAlert 照常熄", hsRec.procActive, false)
    -- 記下的 id 已經不發光（漏了 HIDE 事件）⇒ 照常熄、清掉
    hsRec.procActive, hsRec.procEventID = true, 433895
    G.OnHideAlert(nil, hs)
    eq("已經不發光 ⇒ 照常熄", hsRec.procActive, false)
    eq("已經不發光 ⇒ 清掉 id", hsRec.procEventID, nil)

    -- 基本法術本身、秘密 id
    G.OnOverlayEvent(true, 206930)
    eq("基本法術也認", hsRec.procActive, true)
    hsRec.procActive, hsRec.procEventID = false, nil
    local ok = pcall(G.OnOverlayEvent, true, SECRET)
    check("秘密 id 不拋錯", ok)
    eq("秘密 id 不動", hsRec.procActive, false)

    G.SyncProc, ns.Viewers, ns.Catalog = origSync, origViewers, origCatalog
    env.C_SpellBook, env.C_SpellActivationOverlay = nil, nil
end

------------------------------------------------------------
-- 8. 充能滿了發光（G.SyncFull）
------------------------------------------------------------
do
    local G = ns.Glow
    local origSpell, origCatalog, origViewers, origDecorate = ns.SpellSetting, ns.Catalog, ns.Viewers, ns.Decorate
    local want = true
    ns.SpellSetting = function(bk, id, key, spec)
        if key == "fullGlow" then return want end
        return origSpell(bk, id, key, spec)
    end
    ns.Setting = ns.Setting or function() return nil end
    ns.Viewers = { AURA_KIND = { buffs = true, buffbars = true }, frames = {} }
    local infos = { [20] = { spellID = 2000, charges = true }, [21] = { spellID = 2100 }, [22] = { equipSlot = 13 } }
    ns.Catalog = { Info = function(id) return infos[id] end }
    local isCharge = { [2000] = true, [2500] = true, [3000] = true }
    ns.Decorate = { IsChargeSpell = function(_, id) return isCharge[id] == true end }
    local charges = {}            -- id → { maxCharges, isActive }
    env.C_Spell = { GetSpellCharges = function(id) return charges[id] end }
    env.C_SpellBook = nil

    local function Rec(id, barKey)
        local ov = env.CreateFrame(); ov.level = 10
        return { overlay = ov, cooldownID = id, barKey = barKey or "essential", claimKey = barKey or "essential",
                 glowW = 40, glowH = 40 }
    end
    local r = Rec(20)
    charges[2000] = { maxCharges = 2, isActive = false }
    G.SyncFull({}, r)
    check("滿了 ⇒ 亮", r.glowOn and r.glowOn.full ~= nil)
    check("事件註冊了", handlers.SPELL_UPDATE_CHARGES and handlers.SPELL_UPDATE_CHARGES.glow_full ~= nil)
    -- 用掉一層：SPELL_UPDATE_CHARGES ⇒ 熄
    charges[2000].isActive = true
    Fire("SPELL_UPDATE_CHARGES")
    eq("回充中 ⇒ 熄", r.glowOn.full, nil)
    -- 回滿
    charges[2000].isActive = false
    Fire("SPELL_UPDATE_CHARGES")
    check("回滿 ⇒ 再亮", r.glowOn.full ~= nil)
    -- 秘密的 isActive ⇒ 不亮（fail-closed），但繼續看著
    charges[2000].isActive = SECRET
    Fire("SPELL_UPDATE_CHARGES")
    eq("isActive 秘密 ⇒ 不亮", r.glowOn.full, nil)
    check("isActive 秘密 ⇒ 繼續看著", handlers.SPELL_UPDATE_CHARGES.glow_full ~= nil)
    charges[2000].isActive = false
    -- 當下的覆蓋法術
    env.C_SpellBook = { FindSpellOverrideByID = function(id) if id == 2000 then return 2500 end return id end }
    charges[2500] = { maxCharges = 3, isActive = true }
    G.SyncFull({}, r)
    eq("看當下的覆蓋那一招（回充中）", r.glowOn.full, nil)
    charges[2500].isActive = false
    G.SyncFull({}, r)
    check("覆蓋那一招滿了 ⇒ 亮", r.glowOn.full ~= nil)
    env.C_SpellBook = nil
    -- 關掉 ⇒ 熄、不看了、事件撤掉
    want = false
    G.SyncFull({}, r)
    eq("沒開 ⇒ 熄", r.glowOn.full, nil)
    eq("沒人看 ⇒ 事件撤掉", handlers.SPELL_UPDATE_CHARGES.glow_full, nil)
    want = true
    -- 不是充能技能／裝備欄／增益條：不亮也不看
    local r2, r3, r4 = Rec(21), Rec(22), Rec(20, "buffs")
    G.SyncFull({}, r2); G.SyncFull({}, r3); G.SyncFull({}, r4)
    check("非充能／裝備欄／增益條都不亮", not (r2.glowOn and r2.glowOn.full) and not (r3.glowOn and r3.glowOn.full)
        and not (r4.glowOn and r4.glowOn.full))
    eq("非充能不註冊事件", handlers.SPELL_UPDATE_CHARGES.glow_full, nil)
    -- 自訂法術
    local c = Rec("c:9"); c.custom = true; c.kind = "spell"; c.spellID = 3000; c.claimKey = nil; c.placedBar = "essential"
    charges[3000] = { maxCharges = 2, isActive = false }
    G.SyncFull({}, c)
    check("自訂法術滿了 ⇒ 亮", c.glowOn and c.glowOn.full ~= nil)
    -- 停放 ⇒ 熄、不看
    G.OnParked(c)
    eq("停放 ⇒ 熄", c.glowOn.full, nil)
    eq("停放 ⇒ 事件撤掉", handlers.SPELL_UPDATE_CHARGES.glow_full, nil)

    -- 三態（G.ReadFull，充能滿音效用）：滿／沒滿／讀不到分得開；不是充能技能 ⇒ isCharge false
    local rr = Rec(20)
    charges[2000] = { maxCharges = 2, isActive = false }
    local ic, st = G.ReadFull(rr, 2000)
    check("三態：滿", ic == true and st == true)
    charges[2000].isActive = true
    ic, st = G.ReadFull(rr, 2000)
    check("三態：沒滿（明文 false 不被吃成 nil）", ic == true and st == false)
    charges[2000].isActive = SECRET
    ic, st = G.ReadFull(rr, 2000)
    check("三態：秘密 ⇒ 讀不到", ic == true and st == nil)
    eq("FullState 包三態：讀不到 ⇒ false（發光 fail-closed）", G.FullState(rr, 2000), false)
    ic, st = G.ReadFull(rr, 2100)
    check("三態：不是充能技能", ic == false and st == nil)
    eq("FullState：不是充能技能 ⇒ nil", G.FullState(rr, 2100), nil)
    charges[2000].isActive = false
    -- 從 cooldownID 解法術（設定介面用）：暴雪冷卻格、增益條、裝備欄、自訂法術／物品
    ns.Catalog.SourceOf = function(id) return id == 23 and "buffs" or "essential" end
    infos[23] = { spellID = 2300 }
    infos["c:5"] = { custom = true, kind = "spell", spellID = 3000, overrideSpellID = 3100 }
    infos["c:6"] = { custom = true, kind = "item", itemID = 1 }
    eq("FullSpellOfID：暴雪冷卻格", G.FullSpellOfID(20), 2000)
    eq("FullSpellOfID：增益條 ⇒ nil", G.FullSpellOfID(23), nil)
    eq("FullSpellOfID：裝備欄 ⇒ nil", G.FullSpellOfID(22), nil)
    eq("FullSpellOfID：自訂法術用覆蓋", G.FullSpellOfID("c:5"), 3100)
    eq("FullSpellOfID：自訂物品 ⇒ nil", G.FullSpellOfID("c:6"), nil)
    eq("FullSpellOf 匯出", G.FullSpellOf(rr), 2000)
    ns.SpellSetting, ns.Catalog, ns.Viewers, ns.Decorate = origSpell, origCatalog, origViewers, origDecorate
    env.C_Spell = nil
end

print(("Assist_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
