------------------------------------------------------------
-- 探針：在遊戲裡量三件「只能實機驗證」的事
--
--   1. **完賽之後多久，值才不是秘密的？限制什麼時候解除？**
--      現在的重試節奏（1 秒一次、最多 30 次）是猜的。量完就知道該調成幾秒，
--      或者該改成聽某個事件。
--   2. **sessionID 真的單調遞增嗎？歷史分段夠不夠涵蓋整趟？策略 A 跟 B 差多少？**
--      策略 B 的正確性完全建立在這個假設上（Run/Snapshot.lua 檔頭有寫）。
--   3. **尾箱的戰利品走哪一個事件？參數是不是秘密值？**
--      Run/Loot.lua 賭的是 ENCOUNTER_LOOT_RECEIVED，那是未驗證的。
--
-- 設計上的三條規矩：
--
-- ⚠ **探針壞掉不能影響記錄。** 每一個進入點都包 xpcall；Recorder 對它的每一次
--   呼叫都是單向的通知，沒有任何回傳值被拿來做決定。
--
-- ⚠ **日誌裡永遠不能出現對秘密值的 tostring／串接。** `tostring(secret)` 是禁止
--   操作，而這支被叫到的時機**正好就是秘密值滿天飛的那幾秒** —— 探針自己炸掉是
--   最糟的結果。所有印出來的東西一律走 Safe()。
--
-- ⚠ **不要用 seterrorhandler 做探針。** 那會把全域錯誤處理器搶走；而且
--   `/reload` 會清掉 taint.log，要留證據得在同一次遊戲階段裡看完。
--
-- 預設關；`/mmp probe on` 之後持續到 `off`，狀態與日誌都進 SavedVariables
-- （reload 不丟，不然「重載一次就沒了」的東西量不出任何跨階段的行為）。
------------------------------------------------------------
local _, ns = ...

ns.Probe = {}
local Probe = ns.Probe

local S = ns.Secret
local L = ns.L

-- 完賽後排幾次取樣。最後一個（20 秒）之後就交給 Recorder 自己的重試
local SAMPLE_AT = { 0, 0.5, 1, 2, 5, 10, 20 }

-- 戰利品事件要聽多久。比功能端的 120 秒長：目的是「看看還有沒有別的事件會響」
local LOOT_WATCH_SEC = 180

-- 探針要聽的戰利品相關事件。⚠ 每一個都先確認過真的存在（拿不存在的名字
--   RegisterEvent 會拋錯），註冊仍然包起來，失敗記進日誌而不是擋下整支。
local LOOT_EVENTS = {
    "ENCOUNTER_LOOT_RECEIVED",
    "CHAT_MSG_LOOT",
    "SHOW_LOOT_TOAST",
    "BONUS_ROLL_RESULT",
}

local frame
local completedAt          -- 完賽的 GetTime()，日誌的相對秒數從這裡算
local lootWatchUntil
local meterResets = 0
local sessionUpdates = 0
local gen = 0

------------------------------------------------------------
-- 印一個「可能是秘密值」的東西
------------------------------------------------------------
local function Safe(v)
    if v == nil then return "nil" end
    if S.IsSecret(v) then return "<secret>" end
    local ok, str = pcall(tostring, v)
    return ok and str or "<unprintable>"
end
Probe.Safe = Safe

local function Enabled()
    return ns.db and ns.db.probe and ns.db.probe.enabled and true or false
end

------------------------------------------------------------
-- 寫一行
--
-- 格式：`12:34:56 +3.5s  訊息`。相對秒數是「離完賽多久」—— 那是所有問題的共同
-- 座標軸，絕對時間只是為了跟聊天記錄對得起來。
------------------------------------------------------------
local function Log(fmt, ...)
    if not Enabled() then return end
    local db = ns.db
    if not db or type(db.probe.log) ~= "table" then return end

    local body
    if select("#", ...) > 0 then
        local ok, str = pcall(string.format, fmt, ...)
        body = ok and str or fmt
    else
        body = fmt
    end

    local rel = ""
    if completedAt then rel = ("+%.1fs"):format(GetTime() - completedAt) end

    local line = ("%s %-7s %s"):format(date("%H:%M:%S"), rel, body)
    local log = db.probe.log
    log[#log + 1] = line
    while #log > ns.DB.PROBE_LOG_CAP do table.remove(log, 1) end
end
Probe.Log = Log

------------------------------------------------------------
-- 常用的取樣片段
------------------------------------------------------------
local function RestrictionLine()
    local parts = {}
    for _, name in ipairs(ns.RESTRICTION_TYPES) do
        parts[#parts + 1] = ("%s=%s"):format(name, ns.RestrictionActive(name) and "1" or "0")
    end
    return table.concat(parts, " ")
end

local function SessionLine()
    local n, lo, hi = ns.Snapshot.SessionRange()
    return ("sessions=%d min=%s max=%s"):format(n, tostring(lo), tostring(hi))
end

-- Overall 傷害第一名：這四個欄位是「什麼時候才變明碼」最直接的指標
local function TopSourceLine()
    if not ns.HAS_DM_API then return "dm=none" end
    local ST = Enum and Enum.DamageMeterSessionType
    local T  = Enum and Enum.DamageMeterType
    if not (ST and T) then return "dm=none" end
    local ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, ST.Overall, T.DamageDone)
    if not ok or type(session) ~= "table" then return "dm=call-failed" end
    local src = type(session.combatSources) == "table" and session.combatSources[1]
    if not src then return "dm=empty" end
    return ("top name=%s amount=%s guid=%s class=%s"):format(
        Safe(src.name), Safe(src.totalAmount), Safe(src.sourceGUID), Safe(src.classFilename))
end

------------------------------------------------------------
-- 完賽後的取樣
------------------------------------------------------------
local function Sample(myGen, label)
    if myGen ~= gen then return end
    if not Enabled() then return end

    Log("[%s] combat=%s %s", label, InCombatLockdown() and "1" or "0", RestrictionLine())
    Log("[%s] %s", label, SessionLine())
    Log("[%s] %s", label, TopSourceLine())

    local deaths, lost = S.SafeCall(C_ChallengeMode.GetDeathCount)
    Log("[%s] deaths=%s timeLost=%s", label, Safe(deaths), Safe(lost))
end

------------------------------------------------------------
-- 策略 A ／ B 並排比較
--
-- 完賽 +10 秒跑一次：兩邊同時算，逐玩家把傷害總量印出來。差多少一眼就看得出來
-- （也順便驗「分段加總」有沒有漏掉整段）。
------------------------------------------------------------
local function CompareStrategies(myGen, baseline, completion)
    if myGen ~= gen or not Enabled() then return end

    -- ⚠ Take 回四個值（players, source/reason, flags, combatSec）—— 一定要逐一接住
    --   再傳下去。直接把呼叫塞進另一支函式的參數位置，中間那個 flags 會被當成
    --   combatSec，印出來是一張表的位址（看起來像「秒數怪怪的」，其實是接錯）
    local function Dump(tag, players, source, combatSec)
        if not players then
            Log("[cmp] %s → 讀不到（%s）", tag, tostring(source))
            return
        end
        Log("[cmp] %s source=%s combatSec=%s", tag, tostring(source), tostring(combatSec))
        for _, p in ipairs(players) do
            Log("[cmp]   %-14s dmg=%-14s heal=%-12s deaths=%s",
                tostring(p.name), tostring(math.floor(p.dmg or 0)),
                tostring(math.floor(p.heal or 0)), tostring(p.deaths or 0))
        end
    end

    -- B：基準之後的分段
    local bPlayers, bSource, _, bSec = ns.Snapshot.Take(baseline or 0, completion)
    Dump("B(sessions)", bPlayers, bSource, bSec)
    -- A：把基準推到「比任何 sessionID 都大」，Take 就只剩總計那條路
    local aPlayers, aSource, _, aSec = ns.Snapshot.Take(math.huge, completion)
    Dump("A(overall)", aPlayers, aSource, aSec)
end

------------------------------------------------------------
-- Recorder 的通知點
------------------------------------------------------------
function Probe.OnRunStart(active)
    if not Enabled() then return end
    gen = gen + 1
    completedAt = nil
    meterResets, sessionUpdates = 0, 0
    Log("=== CHALLENGE_MODE_START mapID=%s level=%s baseline=%s",
        tostring(active.mapID), tostring(active.level), tostring(active.baselineSessionID))
    Log("start %s", RestrictionLine())
    Log("start %s", SessionLine())
end

-- 跟 CHALLENGE_MODE_START 誰先誰後是待驗證的（Recorder 因此不拿它當收尾訊號）
function Probe.OnChallengeReset()
    Log("CHALLENGE_MODE_RESET（db.active=%s）", (ns.db and ns.db.active) and "有" or "無")
end

function Probe.OnMeterReset(elapsedSec)
    if not Enabled() then return end
    meterResets = meterResets + 1
    Log("DAMAGE_METER_RESET #%d（開跑後 %d 秒）", meterResets, elapsedSec or -1)
end

function Probe.OnRunCompleted(completion)
    if not Enabled() then return end
    completedAt = GetTime()
    gen = gen + 1
    local myGen = gen

    Log("=== CHALLENGE_MODE_COMPLETED")
    if type(completion) ~= "table" then
        Log("completion = nil（API 沒給）")
    else
        -- 每一欄是不是秘密值，是「什麼時候才讀得到」最直接的答案
        for _, key in ipairs({
            "mapChallengeModeID", "level", "time", "onTime", "keystoneUpgradeLevels",
            "practiceRun", "oldOverallDungeonScore", "newOverallDungeonScore",
            "isMapRecord", "isAffixRecord", "isEligibleForScore",
        }) do
            Log("completion.%s = %s", key, Safe(completion[key]))
        end
        local members = completion.members
        if type(members) == "table" then
            for i, m in ipairs(members) do
                Log("completion.members[%d] guid=%s name=%s", i,
                    Safe(type(m) == "table" and m.memberGUID), Safe(type(m) == "table" and m.name))
            end
        else
            Log("completion.members = %s", Safe(members))
        end
    end

    for _, at in ipairs(SAMPLE_AT) do
        local label = ("+%.1fs"):format(at)
        if at == 0 then
            ns.Guard(Sample, myGen, label)
        else
            C_Timer.After(at, function() ns.Guard(Sample, myGen, label) end)
        end
    end

    local baseline = ns.db and ns.db.active and ns.db.active.baselineSessionID or 0
    C_Timer.After(10, function() ns.Guard(CompareStrategies, myGen, baseline, completion) end)

    lootWatchUntil = GetTime() + LOOT_WATCH_SEC
    Log("戰利品事件監聽開始，%d 秒", LOOT_WATCH_SEC)
end

function Probe.OnStatsAttempt(attempt, result)
    if not Enabled() then return end
    Log("快照第 %d 次 → %s", attempt, tostring(result))
end

function Probe.OnRunCommitted(run)
    if not Enabled() then return end
    Log("=== 存檔 statsSource=%s players=%d meterResets=%d sessionUpdates=%d",
        tostring(run.statsSource), run.players and #run.players or 0, meterResets, sessionUpdates)
end

------------------------------------------------------------
-- 事件
------------------------------------------------------------
local function OnEvent(_, event, ...)
    if not Enabled() then return end

    if event == "ADDON_RESTRICTION_STATE_CHANGED" then
        local t, state = ...
        -- ⚠ 派送當下 IsAddOnRestrictionActive 對「正在變的那個型別」一律回 false，
        --   所以這裡只記事件自己帶的兩個值；要看全貌得延一幀再問
        Log("ADDON_RESTRICTION_STATE_CHANGED type=%s state=%s", Safe(t), Safe(state))
        C_Timer.After(0, function()
            if Enabled() then Log("  （延一幀）%s", RestrictionLine()) end
        end)
        return
    end

    if event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" then
        -- 這個在戰鬥中是連續打的，只數次數，不逐次寫日誌（不然 400 行一下就滿了）
        sessionUpdates = sessionUpdates + 1
        return
    end

    if not lootWatchUntil or GetTime() > lootWatchUntil then return end

    if event == "ENCOUNTER_LOOT_RECEIVED" then
        local encounterID, itemID, itemLink, quantity, playerName, classFile = ...
        Log("LOOT encounter=%s item=%s link=%s qty=%s who=%s class=%s",
            Safe(encounterID), Safe(itemID), Safe(itemLink), Safe(quantity),
            Safe(playerName), Safe(classFile))
    elseif event == "CHAT_MSG_LOOT" then
        local msg, sender = ...
        Log("CHAT_MSG_LOOT msg=%s sender=%s", Safe(msg), Safe(sender))
    elseif event == "SHOW_LOOT_TOAST" then
        local typeID, itemLink, quantity = ...
        Log("SHOW_LOOT_TOAST type=%s link=%s qty=%s", Safe(typeID), Safe(itemLink), Safe(quantity))
    elseif event == "BONUS_ROLL_RESULT" then
        local rewardType, rewardLink = ...
        Log("BONUS_ROLL_RESULT type=%s link=%s", Safe(rewardType), Safe(rewardLink))
    end
end

function Probe.Init()
    if frame then return end
    frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", function(...) ns.Guard(OnEvent, ...) end)

    ns.SafeRegister(frame, "ADDON_RESTRICTION_STATE_CHANGED")
    ns.SafeRegister(frame, "DAMAGE_METER_COMBAT_SESSION_UPDATED")
    for _, e in ipairs(LOOT_EVENTS) do
        if not ns.SafeRegister(frame, e) then
            Log("RegisterEvent 失敗：%s（這個事件在這個客戶端不存在）", e)
        end
    end
end

------------------------------------------------------------
-- 指令
------------------------------------------------------------
function Probe.SetEnabled(on)
    if not ns.db then return end
    ns.db.probe.enabled = on and true or false
    if on then
        Log("探針開啟 v%s", ns.VERSION)
        Log("目前 %s", RestrictionLine())
        Log("目前 %s", SessionLine())
    end
end

function Probe.IsEnabled()
    return Enabled()
end

function Probe.Dump()
    local db = ns.db
    local log = db and db.probe and db.probe.log
    if type(log) ~= "table" or #log == 0 then
        ns.Print(L["The probe log is empty."])
        return
    end
    ns.Print((L["Probe log (%d lines)"]):format(#log))
    for _, line in ipairs(log) do
        print("  " .. line)
    end
end

function Probe.Clear()
    local db = ns.db
    if db and db.probe then wipe(db.probe.log) end
end
