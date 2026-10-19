------------------------------------------------------------
-- Modules/PotionWindow.lua 的離線自我測試（不進 TOC，遊戲不會載入）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/PotionWindow_test.lua
--
-- 覆蓋：純函式——候選表（排除治療／法力／治療石／隱形、secs 覆寫、真的 Presets 認得流光藥劑）、Open（重複派送、取代）、到期；
-- 遊戲裡那半用 stub 跑一輪：秘密 spellID 只記數、不認得的不排、下一幀才開、換瓶、到期收掉、死亡收掉。
-- 載進自己的環境表：這支測試一個全域都不寫。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local PATH = here .. "/../Modules/PotionWindow.lua"
local PRESETS = here .. "/../Core/Presets.lua"

local passed, failed = 0, 0
local function check(name, cond, detail)
    if cond then passed = passed + 1 else
        failed = failed + 1
        print("FAIL  " .. name .. (detail and ("  (" .. tostring(detail) .. ")") or ""))
    end
end
local function eq(name, got, want)
    check(name, got == want, "got " .. tostring(got) .. ", want " .. tostring(want))
end

local function LoadFile(path, env, ns)
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

------------------------------------------------------------
-- 1. 純函式（沒有任何 WoW 全域也載得起來）
------------------------------------------------------------
local ns = {}
LoadFile(PATH, setmetatable({}, { __index = _G }), ns)
local PW = ns.PotionWindow

local P = {
    ITEMS = {
        { key = "healthPotion", items = { 1, 2 } },
        { key = "luster",       items = { 10, 11 } },
        { key = "reckless",     items = { 20, 21 } },
        { key = "invisibility", items = { 30 } },
    },
    ITEM_NO_BUFF = { healthPotion = true },
    ITEM_NOT_COMBAT = { invisibility = true },
    AURAS = {
        { key = "healthPotion", ids = { 400 } },
        { key = "luster",       ids = { 500, 501 } },
        { key = "reckless",     ids = { 600 }, secs = 25 },
        { key = "invisibility", ids = { 700 } },
        { key = "bloodlust",    ids = { 2825 } },
    },
}
local cand = PW.BuildCandidates(P)
check("候選：流光的兩個增益 ID", cand[500] and cand[501] and cand[500].key == "luster")
eq("候選：沒寫 secs ＝ 30", cand[500].secs, 30)
eq("候選：secs 覆寫", cand[600].secs, 25)
check("候選：治療藥水（ITEM_NO_BUFF）不收", cand[400] == nil)
check("候選：隱形（ITEM_NOT_COMBAT）不收", cand[700] == nil)
check("候選：不是物品組的光環（嗜血）不收", cand[2825] == nil)
check("候選：壞輸入回空表", next(PW.BuildCandidates(nil)) == nil and next(PW.BuildCandidates({})) == nil)

-- 真的 Presets：流光藥劑 1295132（2026-10-20 實機：施放事件帶的就是這個）認得、隱形 1236551 不認得
do
    local pns = {}
    LoadFile(PRESETS, setmetatable({}, { __index = _G }), pns)
    local real = PW.BuildCandidates(pns.Presets)
    check("真 Presets：流光藥劑認得", real[1295132] ~= nil and real[1295132].secs == 30)
    check("真 Presets：隱形不認得", real[1236551] == nil)
    check("真 Presets：嗜血不認得", real[2825] == nil)
end

local s = PW.New()
check("Open：第一次 true", PW.Open(s, 500, 100, 30))
eq("Open：起點", s.s, 100)
eq("Remaining", PW.Remaining(s, 110), 20)
check("Open：50ms 內同一個法術重複派送 false", not PW.Open(s, 500, 100.03, 30))
check("Open：過了 50ms 同一瓶算新的（重新起算）", PW.Open(s, 500, 105, 30) and s.s == 105)
check("Open：換瓶取代", PW.Open(s, 600, 106, 25) and s.id == 600 and s.d == 25)
check("Open：秒數壞掉退 30", PW.Open(s, 500, 200, nil) and s.d == 30)
check("ActiveAt：到期前 true", PW.ActiveAt(s, 229.9))
check("ActiveAt：到期 false", not PW.ActiveAt(s, 230))
eq("Remaining：過期不回負數", PW.Remaining(s, 300), 0)
PW.Reset(s)
check("Reset 之後沒有視窗", s.id == nil and not PW.ActiveAt(s, 200))
eq("Remaining：沒有視窗 0", PW.Remaining(nil, 1), 0)

------------------------------------------------------------
-- 2. 遊戲裡那半（stub）
------------------------------------------------------------
do
    local now = 1000
    local timers, deferred, handlers = {}, {}, {}
    local notified, potionChanged = 0, 0
    local SECRET = setmetatable({}, { __tostring = function() return "SECRET" end })
    local env = setmetatable({
        GetTime = function() return now end,
        C_Timer = { After = function(d, fn) timers[#timers + 1] = { at = now + d, fn = fn } end },
        C_Spell = { GetSpellName = function(id) return "法術" .. id end },
    }, { __index = _G })
    env._G = env                                      -- 模組用 _G.GetTime：指回 stub
    local gns = {
        Presets = P,
        IsSecret = function(v) return v == SECRET end,
        Defer = function(fn, ...) deferred[#deferred + 1] = { fn = fn, args = { ... } } end,
        Events = { Register = function(ev, key, fn) handlers[ev] = fn end },
        Bars = { RequestAll = function() notified = notified + 1 end },
        Custom = { PotionChanged = function() potionChanged = potionChanged + 1 end, Records = function() return {} end },
    }
    local loaded
    gns.RegisterCallback = function(ev, key, fn) if ev == "Loaded" then loaded = fn end end
    LoadFile(PATH, env, gns)
    local G = gns.PotionWindow
    check("Loaded 有掛", loaded ~= nil)
    loaded()
    local function RunDeferred()
        local q = deferred
        deferred = {}
        local up = table.unpack or unpack            -- ⚠ 不能寫成 a and f() or g()：or 會截掉第二個回傳值
        for _, d in ipairs(q) do d.fn(up(d.args)) end
    end
    local function RunTimers()
        local q = timers
        timers = {}
        for _, t in ipairs(q) do
            if t.at <= now then t.fn() else timers[#timers + 1] = t end
        end
    end
    local cast = handlers.UNIT_SPELLCAST_SUCCEEDED
    check("註冊施放事件", cast ~= nil and handlers.PLAYER_DEAD ~= nil)

    cast("player", "guid", SECRET)
    eq("秘密 spellID：只記數", G.probe.secret, 1)
    check("秘密 spellID：不排", #deferred == 0)
    cast("player", "guid", 12345)
    check("不認得的法術：不排", #deferred == 0)

    cast("player", "guid", 500)
    check("認得的：當下還沒開（下一幀才做）", G.State() == nil)
    RunDeferred()
    local id, st0, d = G.State()
    check("下一幀開了視窗", id == 500 and st0 == 1000 and d == 30)
    check("開了通知 Custom 與 Bars", potionChanged == 1 and notified == 1)
    check("Active", G.Active())

    now = 1010
    cast("player", "guid", 600)
    RunDeferred()
    id, st0, d = G.State()
    check("換瓶：取代、重新起算", id == 600 and st0 == 1010 and d == 25)

    now = 1034.9
    RunTimers()
    check("到期前（舊世代的計時器不收）", G.State() ~= nil)
    now = 1035.1
    RunTimers()
    check("到期收掉", G.State() == nil and not G.Active())
    check("收掉也通知", notified == 3)

    now = 1100
    cast("player", "guid", 501)
    RunDeferred()
    check("再喝一瓶", G.State() == 501)
    handlers.PLAYER_DEAD()
    RunDeferred()
    check("死亡收掉", G.State() == nil)
    check("DebugLine 是字串", type(G.DebugLine()) == "string")
end

print(("PotionWindow_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
