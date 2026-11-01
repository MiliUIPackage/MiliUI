------------------------------------------------------------
-- Meter/Combat.lua 的假死逐筆判定的離線測試（不進 TOC）
--
--   lua AddOns/MiliUI_DamageMeters/Tests/FeignDeath_test.lua
--
-- 覆蓋：假死藏掉、真死留著、判定跨分段不消失、假死接著真死（含旗標殘留的複查）、
-- 多獵人的人數帳、舊列不判定、判不出來一律當真死、沒獵人不掃。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."

local pass, fail = 0, 0
local function check(name, cond)
    if cond then
        pass = pass + 1
    else
        fail = fail + 1
        print("✗ " .. name)
    end
end

local SECRET = setmetatable({}, { __tostring = function() error("tostring on secret") end })

-- 每個情境一份全新的環境與 Combat.lua
local function Setup(opts)
    opts = opts or {}
    local env = {
        now = 100, units = {}, rows = {}, apiCalls = 0, instanceType = "none",
        raid = opts.raid or false, timers = {}, tickers = {}, handlers = {},
    }
    env.memberCount = opts.members or 0
    env.recap = {}

    -- WoW 的全域放這張表，再當 Combat.lua 的環境，不寫進真的 _G
    local G = setmetatable({}, { __index = _G })
    G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    G.strfind = string.find
    G.GetTime = function() return env.now end
    G.CreateFrame = function()
        local f = { RegisterEvent = function() end, UnregisterEvent = function() end }
        f.SetScript = function(_, _, fn) f.script = fn; env.handlers[#env.handlers + 1] = f end
        return f
    end
    G.C_Timer = {
        After = function(d, fn) env.timers[#env.timers + 1] = { at = env.now + d, fn = fn } end,
        NewTicker = function(_, fn)
            local t = { fn = fn, Cancel = function(self) self.dead = true end }
            env.tickers[#env.tickers + 1] = t
            return t
        end,
    }
    G.UnitExists = function(u) return env.units[u] ~= nil end
    G.UnitClassBase = function(u) return env.units[u] and env.units[u].class end
    G.UnitIsDeadOrGhost = function(u) return env.units[u] and env.units[u].dead or false end
    G.UnitIsFeignDeath = function(u) return env.units[u] and env.units[u].feign or false end
    G.UnitAffectingCombat = function() return false end
    G.GetNumGroupMembers = function() return env.memberCount end
    G.IsInRaid = function() return env.raid end
    G.IsInInstance = function() return env.instanceType ~= "none", env.instanceType end
    G.C_DeathRecap = {
        GetRecapEvents = function() return env.recap end,
        GetRecapMaxHealth = function() return SECRET end,
    }
    G.C_PvP = { IsMatchActive = function() return false end }

    local callbacks = {}
    local D = {
        S = { Current = 0, Overall = 1 }, T = { Deaths = 9 },
        IsSecret = function(v) return v == SECRET end,
        SafeClass = function(c) if c == nil or c == SECRET or c == "" then return nil end return c end,
        GetSessionDuration = function() return 0 end,
    }
    D.GetSession = function()
        env.apiCalls = env.apiCalls + 1
        return { combatSources = env.rows }
    end
    local ns = {
        Data = D, playerClass = opts.playerClass or "HUNTER",
        DB = { Style = function() return {} end },
        ReportError = function(e) error(e, 0) end,
        RegisterCallback = function(name, _, fn) callbacks[name] = fn end,
    }

    assert(loadfile(here .. "/../Meter/Combat.lua", "t", G))("MiliUI_DamageMeters", ns)
    env.C = ns.Combat

    env.units.player = { class = ns.playerClass }
    for u, class in pairs(opts.group or {}) do env.units[u] = { class = class } end

    function env.Fire(event, ...) env.handlers[1].script(env.handlers[1], event, ...) end
    function env.Advance(secs)
        env.now = env.now + secs
        for i = #env.timers, 1, -1 do
            local t = env.timers[i]
            if t.at <= env.now then table.remove(env.timers, i); t.fn() end
        end
    end
    -- API 給的是最近的在前
    function env.AddRow(rid, class) table.insert(env.rows, 1, { deathRecapID = rid, classFilename = class or "HUNTER" }) end
    function env.Feigned(rid) return env.C.IsFeigned(rid) == true end

    callbacks.Init()
    env.Advance(6)   -- 走完登入的基準期
    return env
end

------------------------------------------------------------
-- 單一獵人
------------------------------------------------------------
do
    local e = Setup()
    e.units.player.dead, e.units.player.feign = true, true
    e.AddRow(1)
    e.C.ScanDeaths()
    check("假死（還躺著）判成假死", e.Feigned(1))

    e.units.player.dead, e.units.player.feign = false, false
    e.AddRow(2)
    e.C.ScanDeaths()
    check("假死（已經站起來）判成假死", e.Feigned(2))

    e.units.player.dead = true
    e.AddRow(3)
    e.C.ScanDeaths()
    check("真死留著", not e.Feigned(3))
    e.Advance(5); e.C.ScanDeaths()
    check("真死之後複查不會動到前一筆假死", e.Feigned(2))

    e.units.player.dead = false
    e.C.ScanDeaths()
    e.units.player.dead = true
    e.AddRow(4)
    e.C.ScanDeaths()
    check("復活之後再死一次還是真死", not e.Feigned(4))
end

do
    local e = Setup()
    e.AddRow(1)
    e.C.ScanDeaths()
    e.Fire("PLAYER_REGEN_DISABLED")
    check("假死的判定撐過下一場", e.Feigned(1))
end

------------------------------------------------------------
-- 假死接著真死：旗標殘留
------------------------------------------------------------
do
    local e = Setup()
    e.units.player.dead, e.units.player.feign = true, true
    e.AddRow(1)
    e.C.ScanDeaths()
    e.AddRow(2)          -- 其實真死了，旗標還沒消失
    e.C.ScanDeaths()
    check("旗標殘留時先判成假死", e.Feigned(2))

    e.units.player.feign = false
    e.C.ScanDeaths()
    check("旗標剛消失時先等對應的列", e.Feigned(2))
    e.Advance(2.1)
    check("複查有回報變動", e.C.ScanDeaths() == true)
    check("等不到新列就改回真死", not e.Feigned(2))
    check("更早那筆假死不受影響", e.Feigned(1))
end

do
    local e = Setup()
    e.AddRow(1)
    e.C.ScanDeaths()
    e.units.player.dead = true    -- 假死站起來之後真死，列慢了一點才到
    e.C.ScanDeaths()
    e.Advance(1); e.C.ScanDeaths()
    e.Advance(0.5)
    e.AddRow(2)
    e.C.ScanDeaths()
    e.Advance(5); e.C.ScanDeaths()
    check("列晚到：新列是真死", not e.Feigned(2))
    check("列晚到：假死維持假死", e.Feigned(1))
end

do
    local e = Setup()
    e.AddRow(1)
    e.C.ScanDeaths()
    e.units.player.dead = true    -- 這次真死已經有列了，假死不必再複查
    e.AddRow(2)
    e.C.ScanDeaths()
    e.units.player.dead = false
    e.C.ScanDeaths()
    e.units.player.dead = true    -- 復活又死，這次沒有列
    e.C.ScanDeaths()
    e.Advance(3); e.C.ScanDeaths()
    check("複查過的假死不會被下一次死亡改掉", e.Feigned(1))
end

do
    local e = Setup()
    e.AddRow(1)
    e.C.ScanDeaths()
    e.Advance(31)
    e.units.player.dead = true    -- 假死很久之後死了，但這次沒有死亡列
    e.C.ScanDeaths()
    e.Advance(3); e.C.ScanDeaths()
    check("超過複查期限不改舊的假死", e.Feigned(1))
end

------------------------------------------------------------
-- 多獵人
------------------------------------------------------------
do
    local e = Setup({ playerClass = "MAGE", members = 3, group = { party1 = "HUNTER", party2 = "HUNTER" } })
    e.Fire("GROUP_ROSTER_UPDATE")
    e.units.party1.dead = true
    e.AddRow(1)
    e.C.ScanDeaths()
    check("A 真死", not e.Feigned(1))

    e.units.party2.dead, e.units.party2.feign = true, true
    e.AddRow(2)
    e.C.ScanDeaths()
    check("A 死著、B 假死", e.Feigned(2))

    e.units.party1.dead = false
    e.C.ScanDeaths()
    e.units.party1.dead = true
    e.AddRow(3)
    e.C.ScanDeaths()
    check("B 假死中、A 復活後又真死", not e.Feigned(3))
end

do
    local e = Setup({ raid = true, members = 3, group = { raid1 = "HUNTER", raid2 = "HUNTER", raid3 = "MAGE" } })
    e.Fire("GROUP_ROSTER_UPDATE")
    e.units.raid1.dead = true
    e.units.player.dead = true    -- raid1 就是自己，不能數成兩個
    e.AddRow(1)
    e.C.ScanDeaths()
    check("團隊裡自己真死", not e.Feigned(1))
    e.units.raid2.dead, e.units.raid2.feign = true, true
    e.AddRow(2)
    e.C.ScanDeaths()
    check("團隊裡不把自己數兩次", e.Feigned(2))
end

------------------------------------------------------------
-- 判不出來一律當真死
------------------------------------------------------------
do
    local e = Setup()
    e.AddRow(1, "MAGE")
    e.C.ScanDeaths()
    check("非獵人的列不判定", not e.Feigned(1))

    e.AddRow(2, SECRET)
    e.C.ScanDeaths()
    check("職業是秘密值不判定", not e.Feigned(2))

    e.AddRow(SECRET)
    e.C.ScanDeaths()
    check("秘密 rid 不會丟錯", true)

    e.AddRow(0)
    e.C.ScanDeaths()
    check("rid 0 不判定", not e.Feigned(0))
end

do
    local e = Setup()
    e.units.player.dead = SECRET
    e.AddRow(1)
    e.C.ScanDeaths()
    check("存活狀態是秘密值當真死", not e.Feigned(1))
end

do
    local e = Setup()
    e.instanceType = "arena"
    e.AddRow(1)
    e.C.ScanDeaths()
    check("PvP 不判定", not e.Feigned(1))
end

do
    local e = Setup()
    e.AddRow(1)
    e.Fire("PLAYER_ENTERING_WORLD")   -- /reload 或換區：這時看到的列都是舊的
    check("基準期內的舊列不判定", not e.Feigned(1))
    e.AddRow(2)
    e.Advance(4.6)                     -- 基準期結束前的掃描把它收進舊列
    e.Advance(1)
    e.C.ScanDeaths()
    check("基準期結束前的掃描會收掉舊列", not e.Feigned(2))
    e.AddRow(3)
    e.C.ScanDeaths()
    check("基準期過後才開始判定", e.Feigned(3))
end

do
    local e = Setup()
    e.units.player.dead = true
    e.Fire("PLAYER_ENTERING_WORLD")    -- 死著重載：這個死人已經有舊列了
    e.Advance(6)
    e.C.ScanDeaths()
    e.units.player.dead = false
    e.C.ScanDeaths()
    e.AddRow(1)
    e.C.ScanDeaths()
    check("死著重載之後的帳是對的", e.Feigned(1))
end

------------------------------------------------------------
-- 隊上沒獵人
------------------------------------------------------------
do
    local e = Setup({ playerClass = "MAGE" })
    local before = e.apiCalls
    e.AddRow(1)
    e.C.ScanDeaths()
    check("沒獵人不問 API", e.apiCalls == before)
    check("沒獵人不判定", not e.Feigned(1))

    -- 獵人入隊：之前累積的列當舊列
    e.memberCount = 2
    e.units.party1 = { class = "HUNTER" }
    e.Fire("GROUP_ROSTER_UPDATE")
    e.Advance(6); e.C.ScanDeaths()
    check("獵人入隊前的列不判定", not e.Feigned(1))
    e.AddRow(2)
    e.C.ScanDeaths()
    check("獵人入隊之後開始判定", e.Feigned(2))
end

------------------------------------------------------------
-- 重置
------------------------------------------------------------
do
    local e = Setup()
    e.AddRow(1)
    e.C.ScanDeaths()
    check("重置前是假死", e.Feigned(1))
    e.C.ResetDeathTags()
    check("重置清掉判定", not e.Feigned(1))
end

------------------------------------------------------------
-- 除錯輸出：秘密值不能丟錯
------------------------------------------------------------
do
    local e = Setup()
    e.recap[1] = { currentHP = SECRET, overkill = 12, amount = SECRET, event = "SWING_DAMAGE" }
    local s = e.C.RecapSummary(1)
    check("回顧摘要照實印", s == "n=1 hp=secret/secret overkill=12 amount=secret event=SWING_DAMAGE")
    e.recap[1] = nil
    check("沒有回顧", e.C.RecapSummary(1) == "empty")

    e.units.player.feign, e.units.player.dead = SECRET, true
    e.AddRow(1)
    e.C.ScanDeaths()
    local lines = e.C.DeathDebugLines()
    check("verdict log 有記判不出來的列", lines[3] and lines[3]:find("rid=1 unreadable", 1, true) ~= nil)
end

print(("FeignDeath: %d passed, %d failed"):format(pass, fail))
if fail > 0 then os.exit(1) end
