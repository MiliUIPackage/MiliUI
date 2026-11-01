------------------------------------------------------------
-- 戰鬥狀態機與共用刷新 ticker
--
-- 「什麼時候算一場戰鬥」比想像中難：PLAYER_REGEN_ENABLED 一點都不可靠——
-- 連拉時它根本不觸發、PvP 回合之間全隊一直在戰鬥、玩家先死了但團隊還在打。
-- 這整支檔案的複雜度都是在補那些洞（各種邊界情況整理在
-- .claude/notes/wow-damagemeter-c-api-design.md）。
--
-- 效能上的兩個關鍵：
--   * ticker **只在戰鬥期間存在**，閒置時這支插件是零成本的。
--   * 一個 ticker 服務全部視窗，不是一個視窗一個。
------------------------------------------------------------
local _, ns = ...

ns.Combat = {}
local C = ns.Combat
local D = ns.Data

local TICK_DEFAULT = 1

------------------------------------------------------------
-- 狀態
------------------------------------------------------------
local _inCombat        = false
local _inEncounter     = false
-- 智慧顯示切「總計」前的緩衝秒數。打完立刻跳走的話最後一下的數字根本來不及看，
-- 而那一眼往往正是玩家在等的東西（尤其是收尾的爆發）。
local SMART_OVERALL_DELAY = 3

local _needsFinalRefresh = false   -- 玩家不在戰鬥、團隊還在打：繼續輪詢直到全隊脫離
local _combatEndTime   = 0         -- 戰鬥結束的 GetTime()，同時當「已凍結」的哨兵
local _curViewFrozenDur = 0        -- 結束瞬間釘住的「本場」時長
local _regenTimestamp  = 0         -- 玩家離開戰鬥的 GetTime()
local _combatGen       = 0         -- 分段世代 token：延後執行的收尾用它判斷自己過期沒
local _sharedTicker, _timerTicker

-- 判定成假死的 deathRecapID，判準見下面「假死：逐筆判定」那段
local _feignRecaps = {}

------------------------------------------------------------
-- 對外查詢
------------------------------------------------------------
function C.IsInCombat() return _inCombat end
function C.IsInEncounter() return _inEncounter end
function C.Generation() return _combatGen end
function C.IsFeigned(recapID) return _feignRecaps[recapID] end

local function ForEachWindow(fn)
    if ns.Windows and ns.Windows.ForEach then ns.Windows.ForEach(fn) end
end

------------------------------------------------------------
-- 「本場」的時長：整個插件唯一的來源
--
-- 戰鬥中直接讀 API 的 Current 分段——跟長條畫的是**同一個分段**，所以伺服器端
-- 換分段（連拉首領）時計時器會跟著歸零，不會有第二個時鐘各走各的。
-- 戰鬥結束後所有呼叫者都被閘掉，回傳凍結瞬間釘住的值。
------------------------------------------------------------
function C.CurrentDuration()
    if _combatEndTime > 0 then return _curViewFrozenDur end
    local d = D.GetSessionDuration(D.S.Current, nil)
    if d and not D.IsSecret(d) and type(d) == "number" then return d end
    return _curViewFrozenDur
end

-- 每個「戰鬥結束」的路口都要呼叫這支：停錶與釘住最終值必須是同一個動作，
-- 分開寫就會出現「時鐘停了但顯示的是下一個分段的 0:00」。
--   d >= pin 這條守衛：Current 若已經滾到新的（更短的）分段，保留上一個活值。
--   pin 在每次戰鬥開始都歸零，所以不會跨場帶著走。
local function FreezeCombat(ts)
    local d = D.GetSessionDuration(D.S.Current, nil)
    if d and not D.IsSecret(d) and type(d) == "number" and d >= _curViewFrozenDur then
        _curViewFrozenDur = d
    end
    _combatEndTime = ts or GetTime()
    if ns.Publish then ns.Publish.Refresh() end   -- 發佈鈕的打叉狀態跟著戰鬥狀態機走
    -- 智慧顯示的「脫戰 → 總計」掛在這裡：FreezeCombat 是所有戰鬥結束路徑的
    -- 唯一匯流點（五個出口的呼叫端都有 _combatEndTime 守衛，每個分段最多跑一次）。
    -- 一定要在讀完 Current 的時長**之後**才切走。
    --
    -- **不立刻切**，留 SMART_OVERALL_DELAY 秒讓玩家看完最後的數字。
    -- 這段期間畫面是靜止的（ticker 已經因為 _combatEndTime > 0 停掉、時長也凍結了），
    -- 所以緩衝完全不花成本 —— 就只是晚一點換一次視圖。
    --
    -- 守衛跟 ScheduleStopTicker 同一套：世代不符（緩衝期間又開打，M+ 連拉最常見）
    -- 就整個放棄 —— BeginSegment 已經把畫面切到「目前」，這個排隊中的切換再跑
    -- 就會在新戰鬥打到一半跳去總計。世代沒動但又活過來的路徑（隊友先開怪、
    -- 死著重載）看 _inCombat / _needsFinalRefresh。
    local gen = _combatGen
    C_Timer.After(SMART_OVERALL_DELAY, function()
        if gen ~= _combatGen then return end
        if _inCombat or _needsFinalRefresh then return end
        -- 滑鼠還停在任一視窗上就先不切，離開才切（Manager 那邊輪詢，世代守衛同這裡）
        if ns.Windows and ns.Windows.SmartApplyWhenMouseLeaves then
            ns.Windows.SmartApplyWhenMouseLeaves(gen)
        elseif ns.Windows and ns.Windows.SmartApply then
            ns.Windows.SmartApply(false, true)
        end
    end)
end

------------------------------------------------------------
-- 團隊是否還在戰鬥
--
-- 玩家死了／假死了，但首領還活著時，統計必須繼續更新。
------------------------------------------------------------
local function IsGroupInCombat()
    if UnitAffectingCombat("player") then return true end
    local n = GetNumGroupMembers() or 0
    if n == 0 then return false end
    local prefix = IsInRaid() and "raid" or "party"
    local count = IsInRaid() and n or (n - 1)
    for i = 1, count do
        local unit = prefix .. i
        if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and UnitAffectingCombat(unit) then
            return true
        end
    end
    return false
end
C.IsGroupInCombat = IsGroupInCombat

------------------------------------------------------------
-- Ticker
------------------------------------------------------------
local function TimerTick()
    ForEachWindow(function(W)
        if not W.curSessionID and W.UpdateTimerText then W.UpdateTimerText() end
    end)
end

local function StopTimerTicker()
    if _timerTicker then _timerTicker:Cancel(); _timerTicker = nil end
end

local function RefreshAll()
    C.ScanDeaths()   -- 先判定再畫：新的假死列才不會先閃出來一下
    ForEachWindow(function(W) W.Refresh() end)
end

local function SharedRefreshTick()
    -- 玩家已離開戰鬥、團隊還在打（玩家中途死了）
    if _needsFinalRefresh then
        local groupDone = not IsGroupInCombat()
        -- 保險絲：玩家離開戰鬥超過 5 秒還說團隊在打（治療的 HoT／API 延遲），強制收尾
        if not groupDone and _regenTimestamp > 0 and (GetTime() - _regenTimestamp) > 5 then
            groupDone = true
        end
        if groupDone then
            FreezeCombat(_regenTimestamp > 0 and _regenTimestamp or GetTime())
            _inCombat = false
            _needsFinalRefresh = false
            _regenTimestamp = 0
            RefreshAll()
            C.StopTicker()
            return
        end
        -- 團隊還在打：往下走正常刷新
    end
    if _combatEndTime > 0 or (not _inCombat and not _needsFinalRefresh) then
        C.StopTicker()
        return
    end
    RefreshAll()
end

function C.StartTicker()
    if _sharedTicker then _sharedTicker:Cancel() end
    local style = ns.DB.Style()
    local rate = (style and style.refreshRate) or TICK_DEFAULT
    _sharedTicker = C_Timer.NewTicker(rate, SharedRefreshTick)
    StopTimerTicker()
    -- 計時器另開一條 0.5 秒的：這樣即使刷新率調到 3 秒，標題上的時鐘還是每秒跳。
    -- UpdateTimerText 用「顯示的整數秒」做備忘，多出來的 tick 幾乎免費。
    _timerTicker = C_Timer.NewTicker(0.5, TimerTick)
end

function C.StopTicker()
    if _sharedTicker then _sharedTicker:Cancel(); _sharedTicker = nil end
    StopTimerTicker()
end

-- 刷新率改了：只有正在跑的時候才重建，閒置時什麼都不做（不要因為改個設定就開一個 ticker）
function C.RestartTicker()
    if _sharedTicker then C.StartTicker() end
end

-- ticker 死了但戰鬥還在繼續時把它救回來。
-- 會發生的原因：ScheduleStopTicker 的延後停止剛好落在「新一波已經開打」之後
-- （世代 token 擋掉大部分情況，但事件順序不是任何人保證的）。
-- 呼叫者是分段更新事件 —— 伺服器還在送新分段，就代表確實還在打。
function C.ReviveTicker()
    if _sharedTicker then return end
    if not (_inCombat or _needsFinalRefresh) then return end
    C.StartTicker()
end

-- 延後 delay 秒後停 ticker。世代不符（期間開了新分段）或還在戰鬥就整個放棄——
-- 否則「上一波剛結束、延後停止還在排隊時被拉了首領」會把新分段的 ticker 關掉。
local function ScheduleStopTicker(delay)
    local gen = _combatGen
    C_Timer.After(delay, function()
        if gen ~= _combatGen then return end
        if _inCombat or _needsFinalRefresh then return end
        C.StopTicker()
    end)
end

------------------------------------------------------------
-- 新分段開始
------------------------------------------------------------
local function BeginSegment()
    _combatGen = _combatGen + 1
    C.ScanDeaths()   -- 脫戰時沒有 ticker，開打前先對一次帳（期間被復活的獵人要扣掉）
    _inCombat = true
    _combatEndTime = 0
    _curViewFrozenDur = 0
    _regenTimestamp = 0
    _needsFinalRefresh = false
    if ns.Windows and ns.Windows.InvalidateAll then ns.Windows.InvalidateAll() end
    -- 預覽收掉：戰鬥中一定畫真資料。隊友先開怪那種不會有 PLAYER_REGEN_DISABLED，
    -- 要在這裡推（排在 SmartApply 前面，它切分段時的刷新才畫得到真資料）
    if ns.Preview then ns.Preview.Sync() end
    if not _sharedTicker then C.StartTicker() end
    if ns.Windows and ns.Windows.SmartApply then ns.Windows.SmartApply(true, true) end
    if ns.Publish then ns.Publish.Refresh() end
end

------------------------------------------------------------
-- 假死：逐筆判定
--
-- C_DamageMeter 的死亡一列就是一次死亡，假死也有自己的一列和有效的 deathRecapID。
-- 判定結果記在 deathRecapID 上，不記在人身上：
--   * 戰鬥中 sourceGUID／名字是秘密值，列對不回是誰；deathRecapID 與 classFilename
--     是文件標記的 NeverSecret，戰鬥中照樣能讀。
--   * 同一個人可以同時有假死和真死的列，記在人身上分不開。
--   * 假死在總計與歷史分段裡要繼續濾掉，所以開新分段**不清**。
--
-- 判準（新的獵人列第一次出現時）：隊上真的死著的獵人，比已經有對應死亡列的人數多
-- ⇒ 真死，否則 ⇒ 假死。比人數而不是看「有沒有人在假死」：假死可能一下就站起來了，
-- 別的獵人也可能早就死著。
--
-- 判不出來一律當真死（寧可多顯示一筆，不藏掉真的死亡）：/reload 之前就有的舊列、
-- 存活狀態讀到秘密值、PvP（敵方的列也可能是獵人）。
--
-- 不聽 5384 的施法事件：受限時 spellID 是秘密值，而它又是遊戲裡最高頻的事件之一。
-- 只掃「目前」分段：同一次死亡在總計與歷史分段是同一個 deathRecapID（未實機驗證，
-- /mdm debug 的 [deaths] 對得出來）。
------------------------------------------------------------
local BASELINE_SECS  = 5    -- 登入／換區／獵人剛入隊這段時間看到的列都當舊列，不判定
local RECHECK_HOLD   = 2    -- 多出一個死人之後，等對應的列這麼久才認定它不會來了
local RECHECK_WINDOW = 30   -- 最後一筆假死只在這段時間內可能被改回真死
local LOG_MAX        = 20

local _hunterUnits   = {}   -- 隊上的獵人（職業讀不到明文的也算，見 SyncHunters）
local _seenRecaps    = {}   -- 判定過的 deathRecapID
local _accountedDead = 0    -- 真的死著的獵人裡，已經有對應死亡列的人數
local _baselineUntil = 0
local _lastFeign, _lastFeignAt, _unexplainedAt, _recheckTicker
local _deathLog = {}

-- 真的死著的獵人有幾個。假死要扣掉，它的 UnitIsDeadOrGhost 也可能是 true。
-- 文件沒標這兩支會回秘密值，但真的讀到就回 nil（不知道），呼叫端當判不出來。
local function DeadHunters()
    local n = 0
    for i = 1, #_hunterUnits do
        local unit = _hunterUnits[i]
        local dead = UnitIsDeadOrGhost(unit)
        if D.IsSecret(dead) then return nil end
        if dead then
            local feign = UnitIsFeignDeath(unit)
            if D.IsSecret(feign) then return nil end
            if not feign then n = n + 1 end
        end
    end
    return n
end

local function Str(v)
    if D.IsSecret(v) then return "secret" end
    return tostring(v)
end

-- 除錯用：死亡回顧最後一筆的內容。要比對假死和真死的回顧差在哪就看這行
function C.RecapSummary(recapID)
    if not C_DeathRecap then return "no api" end
    local ok, events = pcall(C_DeathRecap.GetRecapEvents, recapID)
    if not ok then return "error" end
    if not events or #events == 0 then return "empty" end
    local ev = events[1]
    local okMax, maxHP = pcall(C_DeathRecap.GetRecapMaxHealth, recapID)
    return ("n=%d hp=%s/%s overkill=%s amount=%s event=%s"):format(#events,
        Str(ev.currentHP), Str(okMax and maxHP), Str(ev.overkill), Str(ev.amount), Str(ev.event))
end

-- 只記獵人的列，一次死亡才一筆，平常不花成本
local function LogDeath(rid, verdict, dead)
    if #_deathLog >= LOG_MAX then table.remove(_deathLog, 1) end
    local states = {}
    for i, unit in ipairs(_hunterUnits) do
        states[i] = ("%s dead=%s feign=%s"):format(unit,
            Str(UnitIsDeadOrGhost(unit)), Str(UnitIsFeignDeath(unit)))
    end
    _deathLog[#_deathLog + 1] = ("%.1f rid=%s %s deadNow=%s accounted=%s [%s] recap: %s"):format(
        GetTime(), tostring(rid), verdict, tostring(dead), tostring(_accountedDead),
        table.concat(states, ", "), C.RecapSummary(rid))
end

local function Classify(dead, isOld)
    if isOld then return "old" end
    if not dead then return "unreadable" end
    local _, instanceType = IsInInstance()
    if instanceType == "pvp" or instanceType == "arena" then return "pvp" end
    if dead > _accountedDead then return "real" end
    return "feign"
end

-- 複查的輪詢：脫戰時沒有 ticker，假死旗標卻可能在那之後才消失。戰鬥中 ticker 每次都會掃
local function RecheckTick()
    if not _lastFeign or _sharedTicker then return end
    if C.ScanDeaths() then ForEachWindow(function(W) W.Refresh() end) end
end

-- 回傳 true＝有列的判定變了（呼叫端自己決定要不要重畫）
function C.ScanDeaths()
    if #_hunterUnits == 0 then return false end
    local changed = false
    local now = GetTime()
    local dead = DeadHunters()
    local isOld = now < _baselineUntil
    if dead and (isOld or dead < _accountedDead) then _accountedDead = dead end

    local session = D.GetSession(D.S.Current, nil, D.T.Deaths)
    local sources = session and session.combatSources
    if sources then
        -- API 給的是最近的在前，舊的先判
        for i = #sources, 1, -1 do
            local src = sources[i]
            local rid = src.deathRecapID
            if not D.IsSecret(rid) and rid and rid > 0 and not _seenRecaps[rid] then
                _seenRecaps[rid] = true
                if D.SafeClass(src.classFilename) == "HUNTER" then
                    local verdict = Classify(dead, isOld)
                    if verdict == "real" then
                        _accountedDead = _accountedDead + 1
                        _lastFeign, _unexplainedAt = nil, nil   -- 這個死人有對應的列了，不必複查
                    elseif verdict == "feign" then
                        _feignRecaps[rid] = true
                        _lastFeign, _lastFeignAt = rid, now
                        changed = true
                        if _recheckTicker then _recheckTicker:Cancel() end
                        _recheckTicker = C_Timer.NewTicker(1, RecheckTick, RECHECK_WINDOW + RECHECK_HOLD)
                    end
                    LogDeath(rid, verdict, dead)
                end
            end
        end
    end

    -- 複查：假死接著真死時 UnitIsFeignDeath 可能還殘留 true，那一筆會被判成假死。
    -- 殘留消失後會多出一個沒有對應列的死人；對應的列也可能只是還在路上，
    -- 所以等 RECHECK_HOLD 秒，還是沒有才把最後一筆假死改回真死。
    if dead and _lastFeign and dead > _accountedDead then
        if now - _lastFeignAt > RECHECK_WINDOW then
            _lastFeign, _unexplainedAt = nil, nil
        elseif not _unexplainedAt then
            _unexplainedAt = now
        elseif now - _unexplainedAt >= RECHECK_HOLD then
            _feignRecaps[_lastFeign] = nil
            LogDeath(_lastFeign, "recheck-real", dead)
            _lastFeign, _unexplainedAt = nil, nil
            _accountedDead = _accountedDead + 1
            changed = true
        end
    else
        _unexplainedAt = nil
    end
    return changed
end

-- 分段全清（手動重置、進副本自動重置）：舊列都不在了，編號也可能重來
function C.ResetDeathTags()
    wipe(_seenRecaps)
    wipe(_feignRecaps)
    _lastFeign, _unexplainedAt = nil, nil
end

local function StartBaseline()
    _baselineUntil = GetTime() + BASELINE_SECS
    C.ScanDeaths()
    -- 結束前再掃一次：這段期間沒有任何刷新的話，舊列會拖到基準期過後才第一次被看到，
    -- 就被當成新列判定了
    C_Timer.After(BASELINE_SECS - 0.5, C.ScanDeaths)
end

------------------------------------------------------------
-- 隊上的獵人。沒有就整個不掃，單刷、大部分五人隊、城裡掛機的時間全部歸零。
-- 職業拿不到明文的也算進去：多算只會讓假死多顯示一筆，少算會把真死藏掉。
------------------------------------------------------------
local function NoteIfHunter(unit)
    if not UnitExists(unit) then return end
    local class = UnitClassBase and UnitClassBase(unit)
    if class == nil or D.IsSecret(class) or D.SafeClass(class) == "HUNTER" then
        _hunterUnits[#_hunterUnits + 1] = unit
    end
end

local function SyncHunters()
    local had = #_hunterUnits > 0
    wipe(_hunterUnits)
    local n = GetNumGroupMembers() or 0
    if IsInRaid() then
        -- raidN 已經包含自己，再算一次 player 會把同一個死人數成兩個
        for i = 1, n do NoteIfHunter("raid" .. i) end
    else
        if ns.playerClass == "HUNTER" then _hunterUnits[1] = "player" end
        for i = 1, n - 1 do NoteIfHunter("party" .. i) end
    end
    -- 沒人掃的這段期間累積的列，一樣是判不出來的舊列
    if #_hunterUnits > 0 and not had then StartBaseline() end
end

-- 給 /mdm debug 的 [deaths]
function C.DeathDebugLines()
    local feign = 0
    for _ in pairs(_feignRecaps) do feign = feign + 1 end
    local lines = {
        ("hunters=%s deadNow=%s accounted=%s feignTags=%d lastFeign=%s baselineLeft=%.1f"):format(
            table.concat(_hunterUnits, ","), tostring(DeadHunters()), tostring(_accountedDead),
            feign, tostring(_lastFeign), math.max(0, _baselineUntil - GetTime())),
        "verdict log (oldest first):",
    }
    for _, line in ipairs(_deathLog) do lines[#lines + 1] = "  " .. line end
    return lines
end

------------------------------------------------------------
-- 事件
------------------------------------------------------------
local combatFrame = CreateFrame("Frame")

local function OnEvent(_, event, ...)
    if event == "GROUP_ROSTER_UPDATE" then
        SyncHunters()
        return
    end

    if event == "UNIT_FLAGS" then
        -- 只在乎「副本內、自己不在戰鬥、ticker 沒跑」這一種情況，其餘一律早退
        if _inCombat or _sharedTicker or not IsInInstance() then return end
        local unit = ...
        if not unit then return end
        if not (strfind(unit, "^raid") or strfind(unit, "^party")) then return end
        if IsGroupInCombat() then
            -- 隊友先開怪了。預熱刷新，但**不設 _inCombat**——玩家可能整場都沒進戰鬥，
            -- 設了就沒有任何路徑會把它清掉。SharedRefreshTick 會自己在全隊脫離時收尾。
            _combatEndTime = 0
            _curViewFrozenDur = 0
            _needsFinalRefresh = true
            _combatGen = _combatGen + 1
            C.StartTicker()
        end
        return
    end

    if event == "ENCOUNTER_START" then
        _inEncounter = true
        -- 首領開打是硬分段邊界。連拉時 PLAYER_REGEN_DISABLED 不會再觸發，
        -- 只有這裡知道換場了。這裡刻意不記時間錨點：時長從 API 的 Current 分段推導，
        -- 在這裡同步讀一次反而會讀到開打前的舊值。
        BeginSegment()
        RefreshAll()
        return
    end

    if event == "ENCOUNTER_END" then
        _inEncounter = false
        local success = select(5, ...)   -- 1 = 擊殺，0 = 滅團
        -- 乾淨擊殺就提早收尾（PLAYER_REGEN_ENABLED 可能晚好幾秒）。
        -- 不是乾淨擊殺、而且團隊還在打（有人活著、還有小怪、AoE 到下一批），
        -- 就**不要**硬凍結，繼續跑到全隊真的脫離戰鬥。
        if _inCombat or _needsFinalRefresh then
            local gen = _combatGen
            C_Timer.After(0.5, function()      -- 讓暴雪先把分段資料收尾
                if gen ~= _combatGen then return end
                if _combatEndTime > 0 then return end
                if success ~= 1 and IsGroupInCombat() then
                    _needsFinalRefresh = true
                    if not _sharedTicker then C.StartTicker() end
                    return
                end
                FreezeCombat()
                _inCombat = false
                _needsFinalRefresh = false
                RefreshAll()
                ScheduleStopTicker(0.5)
            end)
        end
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        -- 保險：換區／重載之後隊伍組成可能跟上次算的不一樣，而 GROUP_ROSTER_UPDATE
        -- 不保證一定會跟著來（單人時本來就不會發）
        SyncHunters()
        StartBaseline()
        ------------------------------------------------------------
        -- 換區／離開副本 —— **一定要在這裡強制收尾**
        --
        -- 打到一半被傳出戰場、競技場結束、丟掉鑰石、爐石回城…這些情況
        -- PLAYER_REGEN_ENABLED 不保證送得到。沒有這一段的話 _inCombat 會一直是
        -- true，ticker 就在外面的世界一直跑下去（症狀：離開戰場之後計時器還在走、
        -- 統計還在刷新）。這是戰場／競技場最實際的一個問題。
        ------------------------------------------------------------
        if IsGroupInCombat() then
            -- 死著重載／觀戰中：別硬斷，照「隊友先開怪」那條路輪詢就好。
            -- 一樣不設 _inCombat —— 玩家可能自己根本沒進戰鬥。
            _inCombat = false
            _combatEndTime = 0
            _needsFinalRefresh = true
            if not _sharedTicker then C.StartTicker() end
        else
            local wasLive = _inCombat or _needsFinalRefresh or _inEncounter
            _inEncounter = false
            _inCombat = false
            _needsFinalRefresh = false
            C.StopTicker()
            -- 剛剛還在打就把計時器釘住，不然它會停在一個沒收尾的數字
            if wasLive and _combatEndTime == 0 then FreezeCombat() end
            RefreshAll()
        end
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        if C.IsPvPBlocked() then return end   -- PvP 賽後清場的傷害不該開新分段
        BeginSegment()
        return
    end

    -- PLAYER_REGEN_ENABLED
    _regenTimestamp = GetTime()
    -- 假死 + 團隊還在打：計時器繼續跑
    if UnitIsFeignDeath and UnitIsFeignDeath("player") and IsGroupInCombat() then return end
    -- 只清資料：離開戰鬥沒有任何外觀變動，清 _barCacheKey 等於白白重排四十條
    if ns.Windows and ns.Windows.InvalidateData then ns.Windows.InvalidateData() end

    if IsGroupInCombat() then
        _needsFinalRefresh = true   -- 讓 tick 輪詢到全隊脫離；先不凍結計時器
    else
        -- 守衛：ENCOUNTER_END 可能已經凍結過了，不要覆蓋成比較晚的時間
        if _combatEndTime == 0 then FreezeCombat() end
        _inCombat = false
        _needsFinalRefresh = false
        RefreshAll()
        local style = ns.DB.Style()
        ScheduleStopTicker((style and style.refreshRate) or TICK_DEFAULT)
    end

    -- 離開戰鬥 0.5 秒後補一次：API 要一點時間把秘密的 source GUID 解密，
    -- 解密前展開頁點不開
    C_Timer.After(0.5, RefreshAll)
end

------------------------------------------------------------
-- PvP 收尾
--
-- 競技場／純劣者之戰在回合之間 IsGroupInCombat() 一直是 true，
-- 賽末也不保證送 PLAYER_REGEN_ENABLED。只好自己看 C_PvP 的比賽狀態。
------------------------------------------------------------
local _pvpMatchActive = false
local _pvpBlockUntil = 0

function C.IsPvPBlocked()
    return GetTime() < _pvpBlockUntil
end

local pvpFrame = CreateFrame("Frame")
local function OnPvPEvent()
    if not C_PvP or not C_PvP.IsMatchActive then return end
    local active = C_PvP.IsMatchActive()
    if active and not _pvpMatchActive then
        _pvpMatchActive = true
    elseif not active and _pvpMatchActive then
        _pvpMatchActive = false
        C_Timer.After(1.5, function()
            if _pvpMatchActive then return end
            if _combatEndTime > 0 then return end
            FreezeCombat()
            _inCombat = false
            _needsFinalRefresh = false
            RefreshAll()
            ScheduleStopTicker(0.5)
            _pvpBlockUntil = GetTime() + 20   -- 擋掉賽後清場傷害開新分段
        end)
    end
end

------------------------------------------------------------
-- 重置
------------------------------------------------------------
function C.ResetData()
    D.ResetAll()
    _combatEndTime = 0
    _curViewFrozenDur = 0
    if ns.Windows then
        if ns.Windows.InvalidateAll then ns.Windows.InvalidateAll() end
        ns.Windows.ForEach(function(W)
            W.curSessionID = nil
            W._barCacheKey = nil
            W.Refresh()
        end)
    end
end

------------------------------------------------------------
-- 掛事件：等 Init（有 API 才掛，沒 API 的客戶端連事件都不要註冊）
------------------------------------------------------------
ns.RegisterCallback("Init", "combat", function()
    combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    -- 換區時強制收尾（離開戰場／競技場／副本時 REGEN_ENABLED 不保證送得到）
    combatFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    combatFrame:RegisterEvent("UNIT_FLAGS")
    combatFrame:RegisterEvent("ENCOUNTER_START")
    combatFrame:RegisterEvent("ENCOUNTER_END")
    -- 隊伍組成變了就重算「隊上有哪些獵人」
    combatFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    combatFrame:SetScript("OnEvent", function(...)
        xpcall(OnEvent, ns.ReportError, ...)
    end)
    SyncHunters()

    pvpFrame:RegisterEvent("PVP_MATCH_COMPLETE")
    pvpFrame:RegisterEvent("PVP_MATCH_STATE_CHANGED")
    pvpFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    pvpFrame:SetScript("OnEvent", function()
        xpcall(OnPvPEvent, ns.ReportError)
    end)

    -- 進戰鬥時剛好在登入畫面之類的邊界情況：補一次狀態
    if UnitAffectingCombat("player") then BeginSegment() end
end)
