------------------------------------------------------------
-- 統計快照：把「這一趟的戰鬥統計」讀成一張純 Lua 表
--
-- 資料全部來自遊戲內建的戰鬥統計 API（C_DamageMeter）—— 這支**沒有註冊
-- COMBAT_LOG_EVENT_UNFILTERED**，一行戰鬥記錄都不解析。代價是資料的定義權在
-- 暴雪手上（分段怎麼切、保留幾段都不是我們能決定的），好處是成本與團隊人數、
-- 施法頻率完全無關，而且鑰石裡不必每幀做事。
--
-- ⚠⚠ **存進 SavedVariables 的每一個值都必須是明碼。** 秘密值存不進去，而且下次
--   讀出來要比較／當 key／串字串全部會硬錯。所以這支的每一個取值點都先過守衛，
--   秘密的一律當作「這次沒讀到」，讓呼叫端排下一次重試。
--
-- ⚠ 絕對不要拿可能是秘密的值當 table key。`t[secret]` 是硬錯
--   （"cannot be indexed with secret keys"），不是回 nil。
--
-- ------------------------------------------------------------
-- 兩條策略
--
-- **B「分段加總」（主）**：鑰石開始時記下當時最大的 sessionID 當基準，完賽後把
-- 基準之後的每一段逐段加總。這樣拿到的正好是「這一趟」，不受玩家在鑰石前後打了
-- 什麼影響。
--
-- **A「總計」（備援）**：直接問 Overall 那一份。只有在鑰石開始前剛好重置過時才
-- 等於整趟，所以只在 B 走不通（分段被淘汰掉了）時才用，而且會標記出來。
--
-- ⚠ **策略 B 建立在「sessionID 單調遞增」這個假設上，而那是待驗證的。**
--   程式寫成「假設不成立也只是退到策略 A」，不會崩潰；探針（Debug/Probe.lua）
--   會把每次的最小／最大 sessionID 印出來，實機驗證過再回來收掉這段註解。
--
-- ------------------------------------------------------------
-- 已知不做的事（雛形）
--
-- * **假死不過濾。** 死亡列表裡假死會被算成一次死亡。要濾得監聽高頻事件抓法術
--   施放並記 GUID，而鑰石裡那些 GUID 多半是秘密值、當不了快取的 key ——
--   雛形先照實記，表頭的總死亡數另外走官方 API（那個數字是對的）。
-- * **寵物的傷害不併回主人。** API 給的是一列一個來源，併回去要拿寵物主人關係，
--   那在秘密值下同樣不穩。
------------------------------------------------------------
local _, ns = ...

ns.Snapshot = {}
local Snap = ns.Snapshot

local S = ns.Secret
local issecret = S.IsSecret

------------------------------------------------------------
-- 統計類型 → 我們存進 run.players 的欄位名
--
-- ⚠ 這張表**不能寫成 table constructor**：舊客戶端沒有 Enum.DamageMeterType 時
--   `{ [T.DamageDone] = ... }` 的 key 會是 nil，那是載入時就炸的硬錯。
--   逐筆檢查再塞，順便讓「暴雪哪天加一種統計類型」不必改結構。
--
-- 八種全部都存 —— 面板只顯示其中五欄，但**過了就回不來的資料不要省**。
------------------------------------------------------------
local TYPE_FIELDS = {}     -- { { type = <enum>, field = "dmg", perSec = "dps" }, ... }
local DEATHS_TYPE           -- 死亡型別要特別處理（一列一次死亡，不是一個總量）

do
    local T = Enum and Enum.DamageMeterType
    local defs = {
        { "DamageDone",           "dmg",        "dps" },
        { "HealingDone",          "heal",       "hps" },
        { "DamageTaken",          "taken" },
        { "AvoidableDamageTaken", "avoidable" },
        { "EnemyDamageTaken",     "enemyTaken" },
        { "Interrupts",           "interrupts" },
        { "Dispels",              "dispels" },
    }
    if T then
        for _, d in ipairs(defs) do
            local v = T[d[1]]
            if v ~= nil then
                TYPE_FIELDS[#TYPE_FIELDS + 1] = { type = v, field = d[2], perSec = d[3] }
            end
        end
        DEATHS_TYPE = T.Deaths
    end
end

Snap.TYPE_FIELDS = TYPE_FIELDS

------------------------------------------------------------
-- C_DamageMeter 包裝：全部包 pcall
--
-- ⚠ pcall 會把「getter 拒收秘密參數」變成靜默的空白 —— 該擋的要在呼叫**之前**
--   擋掉，不要靠 pcall 收尾。這裡的 pcall 只是「不讓一次拋錯打斷整趟快照」。
------------------------------------------------------------
local function GetSessionFromID(sessionID, dmType)
    if not ns.HAS_DM_API or dmType == nil then return nil end
    local ok, s = pcall(C_DamageMeter.GetCombatSessionFromID, sessionID, dmType)
    return ok and s or nil
end

local function GetSessionFromType(sessionType, dmType)
    if not ns.HAS_DM_API or dmType == nil or sessionType == nil then return nil end
    local ok, s = pcall(C_DamageMeter.GetCombatSessionFromType, sessionType, dmType)
    return ok and s or nil
end

-- { { sessionID, name, durationSeconds }, ... }
function Snap.AvailableSessions()
    if not ns.HAS_DM_API or not C_DamageMeter.GetAvailableCombatSessions then return nil end
    local ok, list = pcall(C_DamageMeter.GetAvailableCombatSessions)
    if not ok or type(list) ~= "table" then return nil end
    return list
end

-- 目前有幾段、最小與最大的 sessionID（全部要明碼才算數）
function Snap.SessionRange()
    local list = Snap.AvailableSessions()
    if not list then return 0 end
    local n, lo, hi = 0, nil, nil
    for _, s in ipairs(list) do
        local id = S.PlainNumber(s and s.sessionID)
        if id then
            n = n + 1
            if not lo or id < lo then lo = id end
            if not hi or id > hi then hi = id end
        end
    end
    return n, lo, hi
end

-- 鑰石開跑時的基準：此刻最大的 sessionID（一段都沒有就 0）
function Snap.CurrentBaseline()
    local _, _, hi = Snap.SessionRange()
    return hi or 0
end

------------------------------------------------------------
-- 隊伍白名單
--
-- 目的：把統計裡的怪、寵物、路過的人濾掉，只留這一隊五個人。
-- 兩個來源，能拿到哪個算哪個（兩個都可能整批是秘密值）：
--   1. 完賽資訊的 members[]（最準：那就是這一趟的名單）
--   2. player / party1-4 的 UnitGUID ＋ UnitName（隊友還在隊伍裡才有）
--
-- 回傳兩張**只含明碼**的查表（guid → true、name → true）。
------------------------------------------------------------
function Snap.BuildRoster(completion)
    local guids, names = {}, {}
    local n = 0

    local function AddGUID(v)
        local g = S.PlainText(v)
        if g and g ~= "" and not guids[g] then guids[g] = true; n = n + 1 end
    end
    local function AddName(v)
        local name = S.PlainText(v)
        if name and name ~= "" then names[name] = true end
    end

    if type(completion) == "table" and type(completion.members) == "table" then
        for _, m in ipairs(completion.members) do
            if type(m) == "table" then
                AddGUID(m.memberGUID)
                AddName(m.name)
            end
        end
    end

    AddGUID(UnitGUID("player"))
    AddName(UnitName("player"))
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) then
            AddGUID(S.SafeCall(UnitGUID, unit))
            AddName(S.SafeCall(UnitName, unit))
        end
    end

    return guids, names, n
end

------------------------------------------------------------
-- 一列來源 → 這是誰
--
-- 回傳 key（累加用的 table key，一定是明碼）, kind
--   kind = "member"      這一隊的人
--        = "other"       認得出來但不是這一隊（怪、寵物、別人）
--        = "unresolved"  身分整個讀不到（秘密值）——呼叫端要據此重試
------------------------------------------------------------
local function Identify(src, guids, names)
    local guid = S.PlainText(src.sourceGUID)
    if guid then
        return guid, guids[guid] and "member" or "other"
    end
    local name = S.PlainText(src.name)
    if name then
        return name, names[name] and "member" or "other"
    end
    -- GUID 與名字都是秘密值 ⇒ 認不出來。⚠ 不能猜、也不能拿秘密值當 key
    return nil, "unresolved"
end

------------------------------------------------------------
-- 累加
------------------------------------------------------------
local function EnsureEntry(acc, order, key)
    local e = acc[key]
    if e then return e end
    e = {
        key = key,
        dmg = 0, dps = 0, heal = 0, hps = 0,
        taken = 0, avoidable = 0, enemyTaken = 0,
        interrupts = 0, dispels = 0, deaths = 0,
    }
    acc[key] = e
    order[#order + 1] = e
    return e
end

-- 身分欄位只在「還沒填過」時填：同一個人會在八種統計裡各出現一次，
-- 每次都寫一遍是白做工，而且後面那次可能剛好是秘密值、把好的蓋掉
local function FillIdentity(e, src)
    if e.name == nil then
        local name = S.PlainText(src.name)
        if name then
            e.name = name
            -- "名字-伺服器"：伺服器另外存，顯示時才決定要不要接回去
            local short, realm = name:match("^([^%-]+)%-(.+)$")
            if short then e.name, e.realm = short, realm end
        end
    end
    if e.class == nil then
        local cls = S.PlainText(src.classFilename)
        if cls and cls ~= "" then e.class = cls end
    end
    if e.specIcon == nil then
        local icon = S.PlainNumber(src.specIconID)
        if icon and icon ~= 0 then e.specIcon = icon end
    end
    if e.isSelf == nil then
        -- isLocalPlayer 是文件標記的 NeverSecret，是唯一安全的身分判斷。
        -- 文件寫錯的話要退化成「不是自己」，不能退化成一個丟出來的比較。
        local own = S.ToBool(src.isLocalPlayer)
        if own == true then e.isSelf = true end
    end
end

------------------------------------------------------------
-- 吃一份 session、把它加進累加器
--
-- 回傳 unresolved 的列數：> 0 代表這一份裡有認不出來的人，快照要重試。
------------------------------------------------------------
local function Absorb(session, def, acc, order, guids, names)
    if type(session) ~= "table" then return 0 end
    local sources = session.combatSources
    if type(sources) ~= "table" then return 0 end

    local unresolved = 0
    for _, src in ipairs(sources) do
        if type(src) == "table" then
            local key, kind = Identify(src, guids, names)
            if kind == "unresolved" then
                unresolved = unresolved + 1
            elseif kind == "member" then
                local e = EnsureEntry(acc, order, key)
                FillIdentity(e, src)
                if def.deaths then
                    -- 死亡型別是**一列一次死亡**（每列自帶 deathRecapID 與死亡時刻），
                    -- 不是一個「死了幾次」的總量 —— 所以這裡是數列數，不是加總。
                    e.deaths = e.deaths + 1
                else
                    local amt = S.PlainNumber(src.totalAmount)
                    if amt then e[def.field] = e[def.field] + amt end
                    if def.perSec then
                        local ps = S.PlainNumber(src.amountPerSecond)
                        -- 每秒值只在策略 A 用得上（策略 B 自己除總戰鬥時間）。
                        -- 這裡先收著，由呼叫端決定用哪一份
                        if ps then e["_ps_" .. def.perSec] = (e["_ps_" .. def.perSec] or 0) + ps end
                    end
                end
            end
        end
    end
    return unresolved
end

------------------------------------------------------------
-- 分數：快照當下對 player / party1-4 問一次
--
-- 顏色**不存**（稀有度色是賽季規則，存下來的舊色以後會對不上），
-- 顯示時才用 C_ChallengeMode.GetDungeonScoreRarityColor 現算。
------------------------------------------------------------
local function ApplyScores(acc)
    if not (C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary) then return end
    local units = { "player", "party1", "party2", "party3", "party4" }
    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            local summary = S.SafeCall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, unit)
            local score = type(summary) == "table" and S.PlainNumber(summary.currentSeasonScore)
            if score then
                -- 對回哪一列：先用 GUID，秘密就退名字。兩個都不行就放棄這個人的分數
                local key = S.PlainText(S.SafeCall(UnitGUID, unit))
                local e = key and acc[key]
                if not e then
                    local name = S.PlainText(S.SafeCall(UnitName, unit))
                    e = name and acc[name]
                end
                if e then e.score = score end
            end
        end
    end
end

-- 職業／專精的補洞：統計來源沒給（秘密值）時，從單位本身再問一次
local function ApplyUnitIdentity(acc)
    local units = { "player", "party1", "party2", "party3", "party4" }
    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            local key = S.PlainText(S.SafeCall(UnitGUID, unit))
            local e = key and acc[key]
            if not e then
                local name = S.PlainText(S.SafeCall(UnitName, unit))
                e = name and acc[name]
            end
            if e and e.class == nil then
                -- ⚠ UnitClass 對非玩家會回單位的名字，所以先問 UnitIsPlayer。
                --   這裡的 unit 一定是隊友，但閘留著 —— 載具期間 token 的語意會變
                if S.SafeBool(UnitIsPlayer, unit) then
                    local cls = S.PlainText(select(2, S.SafeCall(UnitClass, unit)))
                    if cls and cls ~= "" then e.class = cls end
                end
            end
        end
    end
end

------------------------------------------------------------
-- 主入口
--
-- Snap.Take(baselineSessionID, completion)
--   → players, statsSource, flags, combatSec, complete    讀到了
--   → nil, reason                                          整份都讀不到（呼叫端排重試）
--
-- reason: "restricted" 受限／戰鬥中｜"noapi" 沒有統計 API｜"secret" 值還是秘密的
--
-- ⚠ `complete` 是「這一份有沒有缺人」，跟成功與否是**兩件事**。統計裡除了隊友還有
--   一堆怪與寵物，它們的身分在受限情境下同樣讀不出來 —— 把「有認不出來的列」
--   一律當成失敗的話，只要有一隻怪的 GUID 是秘密的，就會一路重試到放棄、
--   最後連已經讀到的五個人也一起丟掉。
--   判準因此改成：**認不出來的列 ＋ 還沒湊齊隊伍人數** 才算缺；湊齊了就表示
--   那些認不出來的是怪，不影響結果。呼叫端拿 complete 決定要不要再等一次。
------------------------------------------------------------
function Snap.Take(baselineSessionID, completion)
    if not ns.HAS_DM_API then return nil, "noapi" end
    if not ns.CanReadStats() then return nil, "restricted" end

    local guids, names, rosterSize = Snap.BuildRoster(completion)
    if rosterSize == 0 then
        -- 一個明碼身分都拿不到 ⇒ 就算讀到統計也對不回人身上
        return nil, "secret"
    end

    local flags = {}
    local acc, order = {}, {}
    local unresolved = 0
    local combatSec = 0
    local statsSource

    ------------------------------------------------------------
    -- 策略 B：基準之後的每一段
    ------------------------------------------------------------
    local list = Snap.AvailableSessions()
    local ids = {}
    local minID
    if list then
        for _, s in ipairs(list) do
            local id = S.PlainNumber(s and s.sessionID)
            if id then
                if not minID or id < minID then minID = id end
                if id > (baselineSessionID or 0) then
                    ids[#ids + 1] = { id = id, dur = S.PlainNumber(s.durationSeconds) or 0 }
                end
            end
        end
    end

    -- 截斷偵測：可用分段裡最小的 ID 已經跑到基準之後 ⇒ 鑰石前半段的分段被暴雪
    -- 淘汰掉了，加總起來會少一截。基準是 0（鑰石中途被重置過）時不算截斷。
    if (baselineSessionID or 0) > 0 and minID and minID > baselineSessionID + 1 then
        flags.truncated = true
    end

    if #ids > 0 and not flags.truncated then
        table.sort(ids, function(a, b) return a.id < b.id end)
        for _, entry in ipairs(ids) do
            combatSec = combatSec + entry.dur
            for _, def in ipairs(TYPE_FIELDS) do
                unresolved = unresolved + Absorb(GetSessionFromID(entry.id, def.type), def, acc, order, guids, names)
            end
            if DEATHS_TYPE ~= nil then
                unresolved = unresolved + Absorb(GetSessionFromID(entry.id, DEATHS_TYPE),
                    { deaths = true }, acc, order, guids, names)
            end
        end
        statsSource = "sessions"
    end

    ------------------------------------------------------------
    -- 策略 A：總計（分段用不上時）
    ------------------------------------------------------------
    if not statsSource then
        local ST = Enum and Enum.DamageMeterSessionType
        local overall = ST and ST.Overall
        if overall == nil then return nil, "noapi" end

        for _, def in ipairs(TYPE_FIELDS) do
            unresolved = unresolved + Absorb(GetSessionFromType(overall, def.type), def, acc, order, guids, names)
        end
        if DEATHS_TYPE ~= nil then
            unresolved = unresolved + Absorb(GetSessionFromType(overall, DEATHS_TYPE),
                { deaths = true }, acc, order, guids, names)
        end

        if C_DamageMeter.GetSessionDurationSeconds then
            combatSec = S.PlainNumber(S.SafeCall(C_DamageMeter.GetSessionDurationSeconds, overall)) or 0
        end
        statsSource = "overall"
    end

    -- 一個人都沒認出來 ⇒ 這一份完全沒用，讓呼叫端等下一次
    if #order == 0 then return nil, "secret" end

    -- 缺人判定（見檔頭的 complete 說明）
    local complete = (unresolved == 0) or (#order >= rosterSize)
    if not complete then flags.incompleteRoster = true end

    ApplyScores(acc)
    ApplyUnitIdentity(acc)

    ------------------------------------------------------------
    -- 每秒值
    --
    -- 策略 B：總量 ÷ 這一趟的戰鬥秒數（分段的 amountPerSecond 各算各的，加起來
    --         沒有意義 —— 那是「每一段各自的平均」的和）。
    -- 策略 A：直接用 API 給的 amountPerSecond，那本來就是 Overall 的平均。
    ------------------------------------------------------------
    for _, e in ipairs(order) do
        if statsSource == "overall" then
            e.dps = e._ps_dps or 0
            e.hps = e._ps_hps or 0
        elseif combatSec > 0 then
            e.dps = e.dmg / combatSec
            e.hps = e.heal / combatSec
        end
        e._ps_dps, e._ps_hps = nil, nil
        -- guid 與 name 分開存：key 可能是 GUID 也可能是名字（GUID 讀不到時）。
        -- 玩家 GUID 的格式是 "Player-<realmID>-<hex>"，認前綴就夠
        if e.key and e.key:match("^Player%-") then e.guid = e.key end
        if e.name == nil then e.name = "?" end
    end

    -- 照傷害由高到低。**在這裡排一次就存起來**：面板只負責畫，不做排序
    table.sort(order, function(a, b)
        if a.dmg ~= b.dmg then return a.dmg > b.dmg end
        return (a.name or "") < (b.name or "")
    end)

    for _, e in ipairs(order) do e.key = nil end

    return order, statsSource, flags, combatSec, complete
end
