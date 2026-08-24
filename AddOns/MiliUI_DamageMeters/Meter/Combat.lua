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
local _needsFinalRefresh = false   -- 玩家不在戰鬥、團隊還在打：繼續輪詢直到全隊脫離
local _combatEndTime   = 0         -- 戰鬥結束的 GetTime()，同時當「已凍結」的哨兵
local _curViewFrozenDur = 0        -- 結束瞬間釘住的「本場」時長
local _regenTimestamp  = 0         -- 玩家離開戰鬥的 GetTime()
local _combatGen       = 0         -- 分段世代 token：延後執行的收尾用它判斷自己過期沒
local _sharedTicker, _timerTicker

-- 假死過的 GUID。C_DamageMeter 會給假死一個有效的 deathRecapID，
-- 光靠 deathRecapID > 0 篩不掉。UnitIsFeignDeath 在「假死接著真死」的轉換中
-- 可能還是 true，所以不能拿它來清快取。
local _feignDeathGUIDs = {}

------------------------------------------------------------
-- 對外查詢
------------------------------------------------------------
function C.IsInCombat() return _inCombat end
function C.IsInEncounter() return _inEncounter end
function C.Generation() return _combatGen end
function C.IsFeigned(guid) return _feignDeathGUIDs[guid] end

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
-- 假死快取清理
--
-- 在篩死亡列表之前跑：確定已經真的死了（血量 0）的 GUID 就把標記拿掉，
-- 否則「假死之後真的死了」那次會被舊標記吃掉、永遠不顯示。
------------------------------------------------------------
function C.CleanupFeignCache()
    if not next(_feignDeathGUIDs) then return end
    local function note(unit)
        if not UnitExists(unit) then return end
        local guid = D.PlainGUID(UnitGUID(unit))
        if not guid or not _feignDeathGUIDs[guid] then return end
        if UnitIsDeadOrGhost(unit) and not UnitIsFeignDeath(unit) then
            _feignDeathGUIDs[guid] = nil
        end
    end
    note("player")
    local n = GetNumGroupMembers() or 0
    if n > 0 then
        local prefix = IsInRaid() and "raid" or "party"
        local count = IsInRaid() and n or (n - 1)
        for i = 1, count do note(prefix .. i) end
    end
end

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
    if next(_feignDeathGUIDs) then wipe(_feignDeathGUIDs) end  -- 舊標記會誤篩掉新分段的真死
    _inCombat = true
    _combatEndTime = 0
    _curViewFrozenDur = 0
    _regenTimestamp = 0
    _needsFinalRefresh = false
    if ns.Windows and ns.Windows.InvalidateAll then ns.Windows.InvalidateAll() end
    if not _sharedTicker then C.StartTicker() end
    if ns.Windows and ns.Windows.AutoCurrentOnCombat then ns.Windows.AutoCurrentOnCombat() end
end

------------------------------------------------------------
-- 事件
------------------------------------------------------------
local combatFrame = CreateFrame("Frame")

local function OnEvent(_, event, ...)
    -- UNIT_SPELLCAST_SUCCEEDED 是這裡最高頻的事件，第一個判斷、用整數比較早退，
    -- 非假死的施法幾乎零成本
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if not unit then return end
        -- spellID 被 C_DamageMeter 污染時可能是秘密數字，比較它會丟錯；
        -- 沒有可用的 spellID 就沒辦法分類，直接放棄這次
        if D.IsSecret(spellID) then return end
        if spellID == 5384 then   -- 假死
            local guid = D.PlainGUID(UnitGUID(unit))
            if guid then _feignDeathGUIDs[guid] = true end
        end
        -- 不因為「後來又施了別的法」就清掉：假死中的獵人照樣有有效的 deathRecapID，
        -- 要等 CleanupFeignCache 確認真的死了才清
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
    -- 暴雪不為假死送 UNIT_AURA，戰鬥記錄也不可靠，只剩這條路
    combatFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    combatFrame:SetScript("OnEvent", function(...)
        xpcall(OnEvent, ns.ReportError, ...)
    end)

    pvpFrame:RegisterEvent("PVP_MATCH_COMPLETE")
    pvpFrame:RegisterEvent("PVP_MATCH_STATE_CHANGED")
    pvpFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    pvpFrame:SetScript("OnEvent", function()
        xpcall(OnPvPEvent, ns.ReportError)
    end)

    -- 進戰鬥時剛好在登入畫面之類的邊界情況：補一次狀態
    if UnitAffectingCombat("player") then BeginSegment() end
end)
