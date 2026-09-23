------------------------------------------------------------
-- 場次生命週期：開始 → 完成 → 存檔
--
-- 時間軸長這樣：
--
--   CHALLENGE_MODE_START        建 db.active，記下「開跑時有幾段戰鬥」當基準
--   （鑰石進行中）              插件限制整趟生效，什麼都讀不到，我們也不讀
--   CHALLENGE_MODE_COMPLETED    立刻抓完賽資訊（表頭）**當場存檔**，清 db.active，
--                               統計排重試，面板「待開」
--   CHALLENGE_MODE_COMPLETED_REWARDS／LOOT_CLOSED／PLAYER_ENTERING_WORLD
--                               任一個先到就開面板（統計還沒好就先顯示「正在等」）
--   +1s, +2s, ... 最多 30 次     限制解除、值變明碼之後，某一次會成功
--   統計寫回那一筆 → 重畫面板 → 開 120 秒的戰利品窗口（面板還沒開過就在這裡開）
--
-- ⚠ 為什麼不再「統計好了才存、才開」（舊做法，偶爾整場沒跳出來）：
--   存檔與開面板掛在一條 30 秒的重試鏈尾巴，鏈上任何一環斷掉 —— 重試途中報錯、
--   離開副本時 IsChallengeModeActive 還是 true 害 OnEnteringWorld 開了新場次
--   把世代 token 換掉、/reload —— 那一場就既沒存也沒開。
--   開面板的時機照 EllesmereUI 的 RunSummary：完賽當下存、領獎勵／關拾取／
--   離開副本開，統計晚到就原地補。
--
-- ⚠ 為什麼要重試而不是讀一次：
--   1. `Enum.AddOnRestrictionType.ChallengeMode` 涵蓋**整趟未完成的鑰石**，
--      而「完成」與「限制解除」不是同一個時刻；
--   2. 就算限制解了，別人的 GUID／名字要再過一會兒才從秘密值變回明碼。
--   兩件事都沒有官方的「好了」訊號，所以只能問到為止。問不到也要存
--   —— 有表頭的記錄比沒有記錄好。
--
-- ⚠ 世代 token（`gen`）：連打兩把時，上一把還在飛的重試不能寫進新的那一把。
--   每次開新場次就 +1，重試醒來先比對，不同就整個放棄。
--
-- ⚠ db.active 要進 SavedVariables。基準值（開跑時的最大 sessionID）是**當下才
--   問得到**的東西，中途 /reload 之後補不回來；存著的話重載回來還是同一趟。
------------------------------------------------------------
local _, ns = ...

ns.Recorder = {}
local R = ns.Recorder

local S = ns.Secret
local L = ns.L

-- 重試節奏：第一次 1 秒後，之後每 1 秒，最多 30 次（＝完賽後約半分鐘）
local RETRY_FIRST = 1.0
local RETRY_STEP  = 1.0
local RETRY_MAX   = 30

-- 中途被重置：離開跑超過這麼久才算「打到一半被清掉」，統計會不完整。
-- 開跑後幾秒內的重置多半是玩家（或別的工具）在開場順手清的，那反而是好事
local RESET_GRACE_SEC = 30

local frame
local gen = 0
local retrying = false

-- 完賽後還在補統計的那一筆（db.runs 裡的表本人）。重試只認它，不看 gen：
-- 補開場（partialStart）也會 +gen，拿 gen 當判準的話離開副本那一下就把重試斷了
local pendingRun
-- 已經收過 CHALLENGE_MODE_COMPLETED 的世代。事件重送時第二次直接略過，
-- 不然同一場會存兩筆
local completedGen
-- 等著開面板的那一筆
local showArmed

------------------------------------------------------------
-- 小工具
------------------------------------------------------------
local function Num(v) return S.PlainNumber(v) end
local function Bool(v) return S.ToBool(v) end
local function Text(v) return S.PlainText(v) end

local function PlayerTag()
    local name = UnitName("player") or "?"
    local realm = GetRealmName()
    if realm and realm ~= "" then return name .. "-" .. realm end
    return name
end

local function InChallenge()
    if not (C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive) then return false end
    return S.SafeBool(C_ChallengeMode.IsChallengeModeActive)
end

------------------------------------------------------------
-- 開始
------------------------------------------------------------
local FinishStats   -- 下面定義

local function StartActive(partial)
    local db = ns.db
    if not db then return end

    -- 真的開了下一把：上一把還在等的統計不會再來了，收掉（照樣標「沒讀到」）。
    -- 補開場（partial）不收 —— 那是 PEW／重載推出來的，不代表上一把結束了
    if not partial and pendingRun then FinishStats(pendingRun, true) end

    gen = gen + 1
    retrying = false

    local active = {
        startedAt = time(),
        baselineSessionID = ns.Snapshot.CurrentBaseline(),
        partialStart = partial or nil,
    }

    local mapID = Num(S.SafeCall(C_ChallengeMode.GetActiveChallengeMapID))
    active.mapID = mapID
    if mapID then
        local name, _, limit = S.SafeCall(C_ChallengeMode.GetMapUIInfo, mapID)
        active.mapName = Text(name)
        active.limitSec = Num(limit)
    end

    local level, affixIDs = S.SafeCall(C_ChallengeMode.GetActiveKeystoneInfo)
    active.level = Num(level)
    active.affixes = {}
    if type(affixIDs) == "table" then
        for _, id in ipairs(affixIDs) do
            local plain = Num(id)
            if plain then active.affixes[#active.affixes + 1] = plain end
        end
    end

    db.active = active
    ns.Probe.OnRunStart(active)
end

------------------------------------------------------------
-- 丟棄（沒完成就離開）
--
-- 雛形直接丟：半場的統計對不回任何「結果」，留著只會在清單裡變成一筆看不懂的東西。
------------------------------------------------------------
local function DiscardActive()
    local db = ns.db
    if not db or not db.active then return end
    gen = gen + 1
    retrying = false
    db.active = nil
end

------------------------------------------------------------
-- 完賽資訊 → run 的表頭
--
-- 欄位名以暴雪的 API 文件為準（ChallengeCompletionInfo）：
--   mapChallengeModeID / level / time / onTime / keystoneUpgradeLevels /
--   practiceRun / oldOverallDungeonScore / newOverallDungeonScore /
--   isMapRecord / isAffixRecord / isEligibleForScore / members
-- 每一個都過守衛：秘密值一律當作「這一欄沒有」。
------------------------------------------------------------
local function BuildRun(active, completion)
    local run = {
        v = ns.History.RUN_VERSION,
        id = time(),
        char = PlayerTag(),

        mapID    = active.mapID,
        mapName  = active.mapName,
        level    = active.level,
        affixes  = active.affixes,
        limitSec = active.limitSec,

        startedAt = active.startedAt,
        endedAt   = time(),

        statsFlags = {
            partialStart   = active.partialStart or nil,
            resetDuringRun = active.resetDuringRun or nil,
        },

        players = {},
    }

    if type(completion) == "table" then
        run.mapID    = Num(completion.mapChallengeModeID) or run.mapID
        run.level    = Num(completion.level) or run.level
        run.timeMs   = Num(completion.time)
        run.onTime   = Bool(completion.onTime)
        run.upgrades = Num(completion.keystoneUpgradeLevels)
        run.practiceRun   = Bool(completion.practiceRun)
        run.oldScore      = Num(completion.oldOverallDungeonScore)
        run.newScore      = Num(completion.newOverallDungeonScore)
        run.isMapRecord   = Bool(completion.isMapRecord)
        run.isAffixRecord = Bool(completion.isAffixRecord)
    end

    -- 時限：完賽資訊沒有這一欄，要另外問地圖
    if not run.limitSec and run.mapID then
        local _, _, limit = S.SafeCall(C_ChallengeMode.GetMapUIInfo, run.mapID)
        run.limitSec = Num(limit)
    end
    -- 副本名備援：顯示時優先現查，這份只是「查不到時還看得出是哪張圖」
    if not run.mapName and run.mapID then
        run.mapName = Text(S.SafeCall(C_ChallengeMode.GetMapUIInfo, run.mapID))
    end

    -- 死亡總數走官方 API：這個數字是對的，而統計裡的死亡列會被假死污染
    local deaths, lost = S.SafeCall(C_ChallengeMode.GetDeathCount)
    run.deaths = Num(deaths) or 0
    run.deathPenaltySec = Num(lost) or 0

    return run
end

------------------------------------------------------------
-- 開面板
--
-- 時機照 EllesmereUI：領獎勵（CHALLENGE_MODE_COMPLETED_REWARDS）、關拾取視窗、
-- 離開副本，三個誰先到誰開；統計補完時如果還沒開過，那裡再開一次當保底。
------------------------------------------------------------
local function RefreshPanel(run)
    -- 面板關著也要重填：發佈鈕的明暗跟著場次算，不重填就停在「正在等」
    if ns.Panel and ns.Panel.CurrentRun() == run then
        ns.Panel.SetRun(run)
    end
end

local function ShowArmed()
    local run = showArmed
    if not run then return end
    showArmed = nil
    if not (ns.db and ns.db.autoOpen and ns.Panel) then return end
    ns.Panel.SetRun(run)
    ns.Panel.Show()
end

------------------------------------------------------------
-- 統計收尾：寫回那一筆（它早就在 db.runs 裡了）
------------------------------------------------------------
FinishStats = function(run, gaveUp)
    if run ~= pendingRun then return end
    pendingRun = nil
    retrying = false
    run.statsPending = nil
    run.statsBaseline = nil
    if gaveUp then
        -- 問到最後還是問不到。表頭（時間、結果、評分變化）是完整的，
        -- 那些是真正「過了就回不來」的東西；統計那一區在面板上會說明它沒讀到
        run.statsSource = nil
        run.statsFlags = run.statsFlags or {}
        run.statsFlags.secretGaveUp = true
    end

    ns.Probe.OnRunCommitted(run)
    ns.Loot.Open(run)

    RefreshPanel(run)
    ShowArmed()
end

------------------------------------------------------------
-- 統計重試
------------------------------------------------------------
local function TryOnce(run, completion, attempt)
    local players, sourceOrReason, flags, combatSec, complete =
        ns.Snapshot.Take(run.statsBaseline or 0, completion)

    ns.Probe.OnStatsAttempt(attempt, players and (complete and "ok" or "partial") or sourceOrReason)

    -- 讀到了，而且沒缺人 ⇒ 收工。缺人的話再等一次（可能有人的身分還是秘密值），
    -- 但**最後一次一定收下**：已經讀到的五個人比「什麼都沒有」值錢太多
    if players and (complete or attempt >= RETRY_MAX) then
        run.players    = players
        run.statsSource = sourceOrReason
        run.combatSec   = combatSec
        run.statsFlags = run.statsFlags or {}
        if type(flags) == "table" then
            for k, v in pairs(flags) do run.statsFlags[k] = v end
        end
        FinishStats(run)
    end
end

-- ⚠ 讀取包在 Guard 裡、排程放在 Guard 外：某一次報錯只算「這次沒讀到」，
--   鏈不會斷（舊版鏈一斷，那一場就既沒存也沒開）
local function TryStats(run, completion, attempt)
    if run ~= pendingRun then return end       -- 已經收掉了（下一場開了、或已補完）
    ns.Guard(TryOnce, run, completion, attempt)
    if run ~= pendingRun then return end
    if attempt >= RETRY_MAX then
        ns.Guard(FinishStats, run, true)
        return
    end
    C_Timer.After(RETRY_STEP, function()
        TryStats(run, completion, attempt + 1)
    end)
end

local function StartStats(run, completion)
    pendingRun = run
    retrying = true
    C_Timer.After(RETRY_FIRST, function()
        TryStats(run, completion, 1)
    end)
end

------------------------------------------------------------
-- 完成
------------------------------------------------------------
local function OnCompleted()
    local db = ns.db
    if not db then return end

    -- 同一場的事件重送：已經存過了，不要再存一筆
    if completedGen == gen and db.active == nil then return end

    -- 沒有 active（登入前就開跑、或事件漏接）也要補一筆，不然整場白打
    if not db.active then StartActive(true) end
    local active = db.active
    if not active then return end
    completedGen = gen

    -- ⚠ 完賽資訊**立刻**讀：它是這個時刻才有的東西，等重試時多半已經被清掉了。
    --   （統計相反，統計要等。）
    local completion = S.SafeCall(C_ChallengeMode.GetChallengeCompletionInfo)
    if type(completion) ~= "table" then completion = nil end

    local run = BuildRun(active, completion)
    ns.Probe.OnRunCompleted(completion)

    -- **當場存檔**：之後不管重試斷在哪、玩家馬上 /reload，這一場都在清單裡。
    -- 基準值跟著存，/reload 回來還能接著補統計（見 ResumePending）
    run.statsPending = true
    run.statsBaseline = active.baselineSessionID or 0
    ns.History.Add(run)
    db.active = nil

    if pendingRun then FinishStats(pendingRun, true) end
    showArmed = run
    if ns.Panel then ns.Panel.SetRun(run) end

    StartStats(run, completion)
end

-- /reload 前還在等統計的那一筆：接著問。完賽資訊沒有了，名單改從隊伍裡讀
local function ResumePending()
    local db = ns.db
    local run = db and db.runs and db.runs[1]
    if type(run) ~= "table" or not run.statsPending then return end
    -- 很久以前留下來的（上一版 /reload 中斷、或當機）就別等了，直接標「沒讀到」
    if (time() - (tonumber(run.endedAt) or 0)) > 600 then
        pendingRun = run
        FinishStats(run, true)
        return
    end
    StartStats(run, nil)
end

------------------------------------------------------------
-- 戰鬥統計被重置
--
-- 重置會把分段清掉重編，基準值從此失去意義 ⇒ 歸零，改成「全部都算」。
-- 開跑後沒多久的重置是好事（那就是開場順手清的），拖久了才代表統計缺一截。
------------------------------------------------------------
local function OnMeterReset()
    local db = ns.db
    local active = db and db.active
    if not active then return end
    local elapsed = time() - (active.startedAt or 0)
    active.baselineSessionID = 0
    if elapsed > RESET_GRACE_SEC then
        active.resetDuringRun = true
    end
    ns.Probe.OnMeterReset(elapsed)
end

------------------------------------------------------------
-- 進出世界：補開場與收尾
------------------------------------------------------------
local function OnEnteringWorld()
    local db = ns.db
    if not db then return end
    -- 完賽後換地圖（通常是離開副本）＝開面板的時機之一
    ShowArmed()
    if InChallenge() then
        -- 鑰石裡重載／登入。沒有 active 就補一筆，並標記「不是從頭記的」。
        -- ⚠ 完賽後 IsChallengeModeActive 會一直是 true 到鑰石重置為止，剛完賽
        --   就換地圖時這裡也會進來 —— 那一場已經存了，不要再補一趟開場
        if not db.active and not pendingRun and completedGen ~= gen then
            StartActive(true)
        end
    elseif db.active then
        -- 已經不在鑰石裡 ⇒ 這一趟沒完成（完成的那一趟在 OnCompleted 就清掉 active 了）
        DiscardActive()
    end
end

------------------------------------------------------------
-- 事件
------------------------------------------------------------
function R.Init()
    if frame then return end
    frame = CreateFrame("Frame")

    frame:RegisterEvent("CHALLENGE_MODE_START")
    frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    frame:RegisterEvent("CHALLENGE_MODE_RESET")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    -- ⚠ 這個事件名不能猜，而且 RegisterEvent 對不存在的事件會拋錯 —— 包起來。
    --   註冊失敗的代價是「中途重置偵測不到」，不是崩潰，所以失敗只記不擋
    ns.SafeRegister(frame, "DAMAGE_METER_RESET")
    -- 開面板的時機（照 EllesmereUI）。前者名字同樣不能猜，包起來
    ns.SafeRegister(frame, "CHALLENGE_MODE_COMPLETED_REWARDS")
    frame:RegisterEvent("LOOT_CLOSED")

    frame:SetScript("OnEvent", function(_, event)
        if event == "CHALLENGE_MODE_START" then
            ns.Guard(StartActive, false)
        elseif event == "CHALLENGE_MODE_COMPLETED" then
            ns.Guard(OnCompleted)
        elseif event == "CHALLENGE_MODE_RESET" then
            -- ⚠ 這裡**不丟** db.active。這個事件跟 CHALLENGE_MODE_START 的先後沒有
            --   文件保證（插鑰石時副本會先重置一次）；如果它排在 START 後面，
            --   丟了就等於把剛記下的基準值丟掉，整趟退成「總計」備援。
            --   沒打完的場次有另外兩條路收：下一次 START 直接蓋掉、
            --   離開副本時 OnEnteringWorld 清掉。這裡只留給探針記時序
            ns.Guard(ns.Probe.OnChallengeReset)
        elseif event == "DAMAGE_METER_RESET" then
            ns.Guard(OnMeterReset)
        elseif event == "CHALLENGE_MODE_COMPLETED_REWARDS" or event == "LOOT_CLOSED" then
            ns.Guard(ShowArmed)
        elseif event == "PLAYER_ENTERING_WORLD" then
            ns.Guard(OnEnteringWorld)
        end
    end)

    ns.Guard(ResumePending)
    OnEnteringWorld()
end

------------------------------------------------------------
-- 狀態讀數（/mmp debug 與設定頁的「關於」用）
------------------------------------------------------------
function R.StatusText()
    local db = ns.db
    if not db then return L["Not ready"] end
    if db.active then return L["Recording a run"] end
    if retrying then return L["Waiting for the combat statistics"] end
    return L["Idle"]
end
