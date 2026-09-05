------------------------------------------------------------
-- 戰隊資訊：資料層
--
-- 記錄戰隊裡每隻角色的鑰石（升級／降級／領取時更新）、本週寶庫進度、
-- 探究懸賞圖狀態（拿過沒／用了沒）與鍍金儲物箱進度；週重置後自動清掉上週的。
-- 2026-09-05 從 MiliUI 本體的 Enhance/CharacterKeystones.lua 搬過來
--（那邊原本掛在 KeystoneLoot 視窗旁邊），第一次啟動會把 MiliUI_DB 裡的舊記錄
-- 搬過來一次（見下面「一次性遷移」）。
--
-- 這支只管資料與隊伍頻道輸出；表格面板在 Core/WarbandPopup.lua，
-- 資訊列上的方塊在 Core/Blocks.lua。
--
-- 資料放在 MiliUI_InfoBar_DB.warband.characters，key 是「角色名-伺服器」：
--   { name, realm, class（classFile）, mapID, level, timestamp,
--     vault = { timestamp, mplus / raid / pvp / world = 三格, mplusRuns,
--               bounty = { got, count }, stash = { cur, max, trusted } } }
-- ⚠ 追蹤**永遠在跑**、不看方塊有沒有啟用：要看的是「其他角色」的資料，
--   而那些資料只能在登入那隻角色的時候記。全部走事件，零輪詢。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local S = ns.Secret

ns.Warband = {}
local Warband = ns.Warband

local SEVEN_DAYS = 7 * 24 * 60 * 60

local debugOn = false
local function Debug(fmt, ...)
    if debugOn then
        print("|cff00ff00[Warband]|r " .. string.format(fmt, ...))
    end
end

function Warband.ToggleDebug()
    debugOn = not debugOn
    return debugOn
end

------------------------------------------------------------
-- 儲存區與監聽者
------------------------------------------------------------
local function Store()
    local db = ns.GetDB()
    if type(db.warband) ~= "table" then db.warband = {} end
    if type(db.warband.characters) ~= "table" then db.warband.characters = {} end
    return db.warband
end

function Warband.Records()
    return Store().characters
end

function Warband.Count()
    local n = 0
    for _ in pairs(Store().characters) do n = n + 1 end
    return n
end

-- 資料變了通知方塊與面板重畫；逐個 xpcall，一個壞掉不連坐
local listeners = {}

function Warband.AddListener(key, fn)
    listeners[key] = fn
end

function Warband.RemoveListener(key)
    listeners[key] = nil
end

local function Notify()
    for _, fn in pairs(listeners) do
        xpcall(fn, ns.ReportError)
    end
end

------------------------------------------------------------
-- 週重置與清理
------------------------------------------------------------
local function GetLastWeeklyReset()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local secs = C_DateAndTime.GetSecondsUntilWeeklyReset()
        if secs and secs > 0 then
            return GetServerTime() + secs - SEVEN_DAYS
        end
    end
    return GetServerTime() - SEVEN_DAYS
end

-- 角色「最後上線記錄」時間：鑰石記錄時間與寶庫快照時間取較新者
-- （鑰石沒換 rec.timestamp 整週不動；寶庫快照每次上線都會刷新）。
-- 週清理、列表排序、日期欄都用這個值。
local function GetRecordLastSeen(data)
    local ts = data.timestamp or 0
    local vaultTs = data.vault and data.vault.timestamp or 0
    if vaultTs > ts then ts = vaultTs end
    return ts
end
Warband.LastSeen = GetRecordLastSeen

local function PruneOldRecords()
    local history = Store().characters
    local cutoff = GetLastWeeklyReset()
    for key, data in pairs(history) do
        local ts = GetRecordLastSeen(data)
        if ts == 0 or ts < cutoff then
            Debug("Prune: %s", key)
            history[key] = nil
        end
    end
end

------------------------------------------------------------
-- 常數
------------------------------------------------------------
local KEY_CHECK_DELAY     = 1
local KEY_CHECK_MAX_RETRY = 6
local BASELINE_DELAY      = 10

local KEYSTONE_NPC_IDS = {
    [197711] = true,
    [197915] = true,
}

-- 寶庫類型：Activities=M+, Raid=團本, RankedPvP=競技場, World=世界/深淵（與 PvP 互斥）
local VAULT_TYPES = {
    mplus = 1,
    raid  = 3,
    pvp   = 2,
    world = 6,
}

-- 本週寶庫最多計入的 M+ 場次（最高門檻＝8 場）
local MPLUS_MAX_RUNS = 8
Warband.MPLUS_MAX_RUNS = MPLUS_MAX_RUNS

-- 探究者懸賞圖（每週掉一張的藏寶圖）
-- 「本週拿過沒」看隱藏追蹤任務 86371 —— 換季換的是物品，這個旗標任務不變，
-- 每週重置（做法同 Plumber GameTooltip_DelvesItem.lua）。
-- 「用了沒」沒有旗標可查，用「拿過＋身上已經沒有」推論；每隻角色在線上時
-- 記自己的數量，所以不會有「圖在別隻身上」的誤判。
local BOUNTY_FLAG_QUEST = 86371
local BOUNTY_ITEM_ID    = 274374 -- Midnight S2；⚠ 每季要換（照 Plumber MID_Activity.lua 的 Seasonal.DelveBountyItemID）
Warband.BOUNTY_ICON     = 1064187

-- 鍍金儲物箱（每週前幾次高階豐收探究的額外寶箱）
-- 讀探究難度選擇器的 UI widget（法術顯示）文字，從 tooltip 抓「x/y」——沒有直接的進度
-- API，這是 Blizzard 自己在探究介面顯示進度的資料源。上限不寫死，跟著 tooltip 的分母走。
--
-- widget ID 每個資料片/區域一組（WidgetTag=delveDifficultyScaling、OrderIndex=6），改版
-- 會換，所以照 Plumber DelvesDashboard 掃整串候選，取第一個吐出這顆法術的。
--
-- ⚠ 讀值有兩種可信度：
--   spellInfo.shownState == 1（或 UPDATE_UI_WIDGET 剛觸發的窗口內）＝活資料，權威值；
--   否則是離開探究區域後留在 widget 裡的殘值——可能是舊的，也可能是預設的 0/x。
-- 殘值不是垃圾：Plumber 就是靠它在任何地方都顯示得出進度。所以殘值照收，但只能「往上
-- 加」，不能把已存的值改小；而 untrusted 讀到 0 一律當沒讀到（那才是預設殘值的樣子）。
local STASH_WIDGET_IDS = {
    7591,                                            -- Midnight
    7193, 6794, 6729, 6728, 6727, 6726, 6725, 6724,  -- TWW 各區
    6723, 6722, 6721, 6720, 6719, 6718, 6659,
}
local STASH_WIDGET_LOOKUP = {}
for _, id in ipairs(STASH_WIDGET_IDS) do STASH_WIDGET_LOOKUP[id] = true end
local STASH_SPELL_ID  = 1216211
local stashTrustedUntil = 0  -- UPDATE_UI_WIDGET（候選 ID）觸發時往後推 5 秒

-- 回傳 { cur, max, trusted } 或 nil；trusted 代表這是活資料（可當權威值覆蓋）
local function ReadOwnGildedStash(reason)
    local getter = C_UIWidgetManager and C_UIWidgetManager.GetSpellDisplayVisualizationInfo
    if not getter then return nil end
    local eventWindow = GetTime() < stashTrustedUntil
    local stale
    for _, widgetID in ipairs(STASH_WIDGET_IDS) do
        local ok, info = pcall(getter, widgetID)
        local spellInfo = ok and info and info.spellInfo
        if spellInfo and spellInfo.spellID == STASH_SPELL_ID then
            local tip = S.PlainText(spellInfo.tooltip)
            local cur, max
            if tip then
                cur, max = string.match(tip, "(%d+)%s*/%s*(%d+)")
                cur, max = tonumber(cur), tonumber(max)
            end
            local trusted = (spellInfo.shownState == 1) or eventWindow
            Debug("Stash(%s): widget=%d shown=%s trusted=%s parsed=%s/%s",
                tostring(reason), widgetID, tostring(spellInfo.shownState),
                tostring(trusted), tostring(cur), tostring(max))
            if cur and max and max > 0 then
                if trusted then
                    return { cur = cur, max = max, trusted = true }
                elseif cur > 0 and not stale then
                    -- 殘值：先留著，繼續找有沒有哪個 widget 是活的
                    stale = { cur = cur, max = max }
                end
            end
        end
    end
    return stale
end

------------------------------------------------------------
-- 自己的鑰石
------------------------------------------------------------
local lastOwnMapID, lastOwnLevel = 0, 0
local baselineSet = false
local keyCheckTimer

local function GetCharacterKey()
    return UnitName("player") .. "-" .. GetRealmName()
end

local function ReadOwnKeystoneState()
    local mapID, level = 0, 0
    if C_MythicPlus then
        if C_MythicPlus.GetOwnedKeystoneChallengeMapID then
            mapID = S.PlainNumber(C_MythicPlus.GetOwnedKeystoneChallengeMapID()) or 0
        end
        if C_MythicPlus.GetOwnedKeystoneLevel then
            level = S.PlainNumber(C_MythicPlus.GetOwnedKeystoneLevel()) or 0
        end
    end
    return mapID, level
end
Warband.OwnKeystone = ReadOwnKeystoneState

function Warband.MapName(mapID)
    if not mapID or mapID <= 0 then return "?" end
    local name = C_ChallengeMode and C_ChallengeMode.GetMapUIInfo
        and C_ChallengeMode.GetMapUIInfo(mapID)
    return S.PlainText(name) or "?"
end

-- 方塊上那幾個字：「地城名 +12」，沒鑰石就「—」
function Warband.OwnKeystoneText()
    local mapID, level = ReadOwnKeystoneState()
    if mapID > 0 and level > 0 then
        return Warband.MapName(mapID) .. " +" .. level
    end
    return "—"
end

local function SaveKeystoneRecord(mapID, level)
    local history = Store().characters
    local key = GetCharacterKey()
    local existing = history[key]
    if existing and existing.mapID == mapID and existing.level == level then
        return false
    end

    local _, class = UnitClass("player")
    history[key] = {
        name  = UnitName("player"),
        realm = GetRealmName(),
        class = class,
        mapID = mapID,
        level = level,
        timestamp = GetServerTime(),
        -- 鑰石換了寶庫沒換：舊快照留著
        vault = existing and existing.vault or nil,
    }
    Debug("Save: %s map=%d lv=%d", key, mapID, level)
    return true
end

------------------------------------------------------------
-- 寶庫資料層
------------------------------------------------------------
-- 讀本週 M+ 場次，排序（level 降冪、同分 mapID 升冪），只取最高前 8 場
-- （寶庫最高門檻＝8 場，多的不影響獎勵，存清單長度即可當「X/8」用）
-- 參數 (false, true)：本週 + includeIncompleteRuns=true，與 Blizzard 寶庫 tooltip
-- (WeeklyRewardsActivityMixin:AddTopRunsToTooltip) 完全一致。
-- 注意：true 才會包含「超時但打完」(depleted) 的場次——這種場次算寶庫進度，
-- 用 false 會漏掉它們，導致清單場次數與寶庫格不符。
local function ReadOwnMythicRuns()
    if not (C_MythicPlus and C_MythicPlus.GetRunHistory) then return nil end
    local runs = C_MythicPlus.GetRunHistory(false, true)
    if not runs or #runs == 0 then return nil end
    table.sort(runs, function(a, b)
        if a.level == b.level then
            return (a.mapChallengeModeID or 0) < (b.mapChallengeModeID or 0)
        end
        return (a.level or 0) > (b.level or 0)
    end)
    local list = {}
    for i = 1, math.min(MPLUS_MAX_RUNS, #runs) do
        list[i] = { mapID = runs[i].mapChallengeModeID, level = runs[i].level or 0 }
    end
    return list
end

local function ReadOwnVaultSnapshot()
    if not C_WeeklyRewards or not C_WeeklyRewards.GetActivities then return nil end
    local snap = { timestamp = GetServerTime() }
    local anyData = false
    for trackName, enumVal in pairs(VAULT_TYPES) do
        local list = C_WeeklyRewards.GetActivities(enumVal)
        if list and #list > 0 then
            local slots = {}
            for i, info in ipairs(list) do
                slots[i] = {
                    threshold = info.threshold or 0,
                    progress  = info.progress or 0,
                    level     = info.level or 0,
                }
            end
            snap[trackName] = slots
            anyData = true
        end
    end
    local runs = ReadOwnMythicRuns()
    if runs then
        snap.mplusRuns = runs
        anyData = true
    end
    -- 懸賞圖：got=本週掉過（含銀行/戰團銀行的持有量；不含 uses）
    snap.bounty = {
        got   = C_QuestLog.IsQuestFlaggedCompleted(BOUNTY_FLAG_QUEST) and true or false,
        count = C_Item.GetItemCount(BOUNTY_ITEM_ID, true, false, true, true) or 0,
    }
    if snap.bounty.got then anyData = true end
    -- 鍍金儲物箱進度（讀不到或不可信就回 nil，由 SaveVaultSnapshot 沿用上次的值）
    snap.stash = ReadOwnGildedStash("snapshot")
    if not anyData then return nil end
    return snap
end

local function SaveVaultSnapshot()
    local snap = ReadOwnVaultSnapshot()
    if not snap then return false end
    local history = Store().characters
    local key = GetCharacterKey()
    local rec = history[key]
    if not rec then
        -- 還沒有鑰石記錄但有寶庫進度（例如本週還沒拿過鑰石），建一筆空殼
        local _, class = UnitClass("player")
        rec = {
            name  = UnitName("player"),
            realm = GetRealmName(),
            class = class,
            mapID = 0,
            level = 0,
            timestamp = GetServerTime(),
        }
        history[key] = rec
    end
    -- 冷快取防護：剛登入或快速 relog 的短 session，旗標/widget 可能讀到假的空值。
    -- 懸賞圖旗標與儲物箱進度在一週內只會單向前進（週重置由 PruneOldRecords 整筆清掉，
    -- 不會跨週殘留），所以永遠不用「更差」的讀值蓋掉已存的。
    local prev = rec.vault
    if prev then
        local pb = prev.bounty
        if pb and pb.got and not snap.bounty.got then
            -- 旗標讀到 false 視為冷快取；count 同樣不可信，一併沿用上次的
            snap.bounty.got = true
            snap.bounty.count = pb.count or 0
        end
        -- 儲物箱：活資料是權威值（只擋兩個活資料之間變小的冷快取）；殘值只能往上加
        local ps, nsx = prev.stash, snap.stash
        if not nsx then
            snap.stash = ps
        elseif ps then
            if nsx.trusted then
                if ps.trusted and ps.max == nsx.max and (ps.cur or 0) > (nsx.cur or 0) then
                    nsx.cur = ps.cur
                end
            elseif not (ps.max == nsx.max and (nsx.cur or 0) > (ps.cur or 0)) then
                snap.stash = ps
            end
        end
    end
    rec.vault = snap
    Debug("Vault saved @ %s", date("%m/%d %H:%M", snap.timestamp))
    return true
end

-- 向伺服器請求最新的寶庫＋M+資料。
-- 重點：C_WeeklyRewards.GetActivities / C_MythicPlus.GetRunHistory 讀的是「客戶端快取」，
-- 這快取只有靠這兩個請求才會刷新（與 Blizzard 寶庫 UI 開啟時做的事一致）：
--   OnUIInteract()  → 觸發 WEEKLY_REWARDS_UPDATE（刷新寶庫進度 GetActivities）
--   RequestMapInfo() → 觸發 CHALLENGE_MODE_MAPS_UPDATE（刷新 M+ 場次 GetRunHistory）
-- 資料到達後，由這兩個事件呼叫 SnapshotAndRefresh 真正存檔（那時才是新資料）。
-- 用 GetTime 節流，避免世界任務等高頻事件狂打伺服器。
local lastVaultRequest = 0
local VAULT_REQUEST_THROTTLE = 2
local function RequestVaultData(reason)
    local now = GetTime()
    if now - lastVaultRequest < VAULT_REQUEST_THROTTLE then return end
    lastVaultRequest = now
    if C_MythicPlus and C_MythicPlus.RequestMapInfo then
        C_MythicPlus.RequestMapInfo()
    end
    if C_WeeklyRewards and C_WeeklyRewards.OnUIInteract then
        C_WeeklyRewards.OnUIInteract()
    end
    Debug("RequestVaultData: %s", tostring(reason))
end
Warband.RequestVaultData = RequestVaultData

-- 寶庫資料到達後存檔並通知（debounce 合併 update 事件的連發）
local snapshotDebounceTimer
local function SnapshotAndRefresh(reason)
    if snapshotDebounceTimer then snapshotDebounceTimer:Cancel() end
    snapshotDebounceTimer = C_Timer.NewTimer(0.3, function()
        snapshotDebounceTimer = nil
        SaveVaultSnapshot()
        Debug("SnapshotAndRefresh: %s", tostring(reason))
        Notify()
    end)
end

-- 團本難度（給 ENCOUNTER_END 過濾用）：14 普通, 15 英雄, 16 傳奇, 17 團搜
local RAID_DIFFICULTY_IDS = { [14] = true, [15] = true, [16] = true, [17] = true }

-- 只負責追蹤鑰石（GetOwnedKeystone 永遠是最新的，不需請求伺服器）。
-- 寶庫/M+場次的刷新走 RequestVaultData → update 事件 → SnapshotAndRefresh。
local function ScheduleKeystoneCheck(retry)
    if keyCheckTimer then return end
    keyCheckTimer = C_Timer.NewTimer(KEY_CHECK_DELAY, function()
        keyCheckTimer = nil
        local mapID, level = ReadOwnKeystoneState()

        if not baselineSet then
            lastOwnMapID, lastOwnLevel = mapID, level
            baselineSet = true
            if mapID > 0 and level > 0 then
                SaveKeystoneRecord(mapID, level)
            end
            Notify()
            return
        end

        if mapID == lastOwnMapID and level == lastOwnLevel then
            if (retry or 0) < KEY_CHECK_MAX_RETRY then
                ScheduleKeystoneCheck((retry or 0) + 1)
            end
            return
        end
        lastOwnMapID, lastOwnLevel = mapID, level
        if mapID > 0 and level > 0 then
            SaveKeystoneRecord(mapID, level)
        end
        -- 記錄有沒有變都通知：方塊上的字讀的是即時 API，不是記錄
        Notify()
    end)
end

local function IsKeystoneNpcGossip()
    -- 兩個都先洗成明文再 or：對可能是秘密值的原始回傳做真值判斷不安全
    local guid = S.PlainText(UnitGUID("npc")) or S.PlainText(UnitGUID("target"))
    if not guid then return false end
    local ok, part = pcall(function() return select(6, strsplit("-", guid)) end)
    if not ok then return false end
    local id = tonumber(part)
    return id ~= nil and KEYSTONE_NPC_IDS[id] == true
end

-- 開面板時：先用當前快取即時顯示（鑰石永遠最新；寶庫可能稍舊），
-- 同時向伺服器請求最新寶庫/M+資料，資料到達後由 update 事件補上。
function Warband.RefreshOwn(reason)
    local mapID, level = ReadOwnKeystoneState()
    if mapID > 0 and level > 0 then
        SaveKeystoneRecord(mapID, level)
        lastOwnMapID, lastOwnLevel = mapID, level
        baselineSet = true
    end
    SaveVaultSnapshot()
    PruneOldRecords()
    RequestVaultData(reason or "refresh")
end

function Warband.Delete(key)
    local history = Store().characters
    if history[key] == nil then return false end
    history[key] = nil
    Notify()
    return true
end

-- 依「最後上線記錄」新→舊排好的清單：{ key =, data = }
function Warband.SortedRecords()
    PruneOldRecords()
    local list = {}
    for key, data in pairs(Store().characters) do
        list[#list + 1] = { key = key, data = data }
    end
    table.sort(list, function(a, b)
        local ta, tb = GetRecordLastSeen(a.data), GetRecordLastSeen(b.data)
        if ta ~= tb then return ta > tb end
        return a.key < b.key
    end)
    return list
end

------------------------------------------------------------
-- 星雲虛無之核（Midnight 賽季鍛造材料 currency）—— 有裝 Syndicator 才有
--
-- 名字都叫「星雲虛無之核」，光靠 GetCurrencyInfo 查得到數量分不出誰是當季的 ——
-- 過季的還會留著舊餘額，PTR 期間的追蹤用代碼也查得到數量。判準是「有沒有出現在
-- 角色貨幣面板」：當季的會列出來，其餘的不會。所以下面拿候選清單去比對面板實際
-- 列出的項目。之後新賽季只要在這裡補一個代碼。
--
-- 2026-08-13 遊戲內實測（Midnight S2 開賽週）：貨幣面板列出的是 3418，也就是
-- **S2 沿用 S1 的代碼、沒有換新的**。
------------------------------------------------------------
local SPARK_CURRENCY_IDS = {
    3418, -- Midnight Season 1 & 2
}
local SPARK_CURRENCY_SET = {}
for _, id in ipairs(SPARK_CURRENCY_IDS) do SPARK_CURRENCY_SET[id] = true end

local resolvedSparkID  -- 掃到面板結果後快取；一場遊戲內當季代碼不會變

function Warband.HasSyndicator()
    return Syndicator and Syndicator.API and Syndicator.API.GetCurrencyInfo and true or false
end

-- 把 GetRealmName() 的結果規格化成 Syndicator 用的格式（移除空白、連字號、單引號）
local function NormalizeRealmName(realm)
    if not realm then return "" end
    return (realm:gsub("[%s%-']", ""))
end

-- 掃角色貨幣面板，回傳第一個落在候選清單裡的代碼。
-- 收合的分類標題底下的項目不會被列舉，所以掃不到不代表沒有 —— 那種情況回 nil 交給
-- 備援處理，而且不快取，下次刷新（玩家可能已經把分類展開）再試一次。
local function ScanCurrencyListForSpark()
    local size = C_CurrencyInfo.GetCurrencyListSize()
    if not size or size == 0 then return nil end
    for i = 1, size do
        local info = C_CurrencyInfo.GetCurrencyListInfo(i)
        if info and not info.isHeader then
            local link = C_CurrencyInfo.GetCurrencyListLink(i)
            local id = link and C_CurrencyInfo.GetCurrencyIDFromLink(link)
            if id and SPARK_CURRENCY_SET[id] then
                return id
            end
        end
    end
    return nil
end

-- 面板掃不到時的備援：取候選裡最新、而且這個角色見過的那個。
local function FallbackSparkID()
    local best
    for _, id in ipairs(SPARK_CURRENCY_IDS) do
        local info = C_CurrencyInfo.GetCurrencyInfo(id)
        if info and info.discovered then best = id end
    end
    return best or SPARK_CURRENCY_IDS[#SPARK_CURRENCY_IDS]
end

local function GetSparkCurrencyID()
    if resolvedSparkID then return resolvedSparkID end
    resolvedSparkID = ScanCurrencyListForSpark()
    return resolvedSparkID or FallbackSparkID()
end

-- 一次抓所有分身的持有量；回傳 lookup keyed by "Name-NormalizedRealm"，沒 Syndicator 回 nil
function Warband.SparkLookup()
    if not Warband.HasSyndicator() then return nil end
    local list = Syndicator.API.GetCurrencyInfo(GetSparkCurrencyID(), false, false)
    if not list then return nil end
    local map = {}
    for _, entry in ipairs(list) do
        local key = (entry.character or "") .. "-" .. (entry.realmNormalized or "")
        map[key] = entry.quantity or 0
    end
    return map
end

function Warband.SparkKey(data)
    return (data.name or "") .. "-" .. NormalizeRealmName(data.realm)
end

------------------------------------------------------------
-- 隊伍頻道輸出
------------------------------------------------------------
function Warband.PartyChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    elseif IsInRaid() then
        return "RAID"
    elseif IsInGroup() then
        return "PARTY"
    end
end

local function ClassLabel(data)
    local className = data.class
        and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[data.class]
    return className and ("[" .. className .. "] ") or ""
end

-- 單筆：「[職業] 名字 地城名 +12」
function Warband.FormatKeystoneMessage(data)
    return ClassLabel(data) .. (data.name or "?") .. " "
        .. Warband.MapName(data.mapID) .. " +" .. (data.level or 0)
end

local LINE_SPACING = 0.15

-- 全部分身：一行一隻，新→舊，只列有鑰石的
function Warband.SendReport(channel)
    if not channel then return end
    local entries = {}
    for _, entry in ipairs(Warband.SortedRecords()) do
        if (entry.data.level or 0) > 0 then
            entries[#entries + 1] = entry.data
        end
    end
    if #entries == 0 then return end
    for i, data in ipairs(entries) do
        local line = string.format("%s%s: %s (+%d)",
            ClassLabel(data), data.name or "?", Warband.MapName(data.mapID), data.level or 0)
        C_Timer.After((i - 1) * LINE_SPACING, function()
            SendChatMessage(line, channel)
        end)
    end
end

------------------------------------------------------------
-- 自我關鍵字：自己在隊伍頻道輸入關鍵字時，回報所有分身鑰石
--
-- hook 每個 ChatFrame 的 EditBox OnEnterPressed —— 比 hook SendChatMessage 可靠
-- （後者可能被別的插件「替換」掉，而 EditBox script 是 UI frame 上的 binding，無法被替換）。
-- 同時也掛 hooksecurefunc(SendChatMessage) 接 /p 巨集那條路。
-- 完全避開 12.x 的 secret-string 保護（不需碰 sender/GUID）。
------------------------------------------------------------
local SELF_REPORT_KEYWORDS = { "分身鑰石", "分身key" }
do
    local kw = L["WARBAND_KEYWORD"]
    if type(kw) == "string" and kw ~= "" then
        table.insert(SELF_REPORT_KEYWORDS, 1, kw)
    end
end

function Warband.Keyword()
    return SELF_REPORT_KEYWORDS[1]
end

local function MatchSelfKeyword(msg)
    msg = S.PlainText(msg)
    if not msg or msg == "" then return false end
    local lower = msg:lower()
    for _, kw in ipairs(SELF_REPORT_KEYWORDS) do
        if lower:find(kw:lower(), 1, true) then return true end
    end
    return false
end

local SEND_CHAT_TYPES = {
    PARTY         = "PARTY",
    INSTANCE_CHAT = "INSTANCE_CHAT",
}

-- 1 秒 dedup：避免單一輸入透過多重路徑（typed + macro etc.）重複觸發
local lastTriggerTime = 0
local function MaybeSendReport(channel)
    local now = GetTime()
    if now - lastTriggerTime < 1 then return end
    lastTriggerTime = now
    Warband.SendReport(channel)
end

local function HookChatEditbox(editbox)
    if not editbox or editbox._miliWbHooked then return end
    editbox._miliWbHooked = true

    -- 在 OnTextChanged 期間記錄目前文字；OnEnterPressed 之後 Blizzard 會清空文字，
    -- 此時讀 GetText() 會是空字串，所以提前快取。
    editbox:HookScript("OnTextChanged", function(self)
        self._miliWbLastText = self:GetText()
    end)

    editbox:HookScript("OnEnterPressed", function(self)
        local msg = self._miliWbLastText
        self._miliWbLastText = nil
        if not msg or msg == "" then return end
        local channel = SEND_CHAT_TYPES[self:GetAttribute("chatType") or ""]
        if not channel then return end
        if not MatchSelfKeyword(msg) then return end
        MaybeSendReport(channel)
    end)
end

hooksecurefunc("SendChatMessage", function(msg, chatType)
    local channel = SEND_CHAT_TYPES[chatType or ""]
    if not channel then return end
    if not MatchSelfKeyword(msg) then return end
    MaybeSendReport(channel)
end)

------------------------------------------------------------
-- 一次性遷移：MiliUI_DB.characterKeystones → 自己的 SavedVariables
--
-- 這組功能原本住在 MiliUI 本體，記錄存在 MiliUI_DB。照 MiliUI_Focus 的規矩：
--   * 印記 store.migration：nil = 還沒查過，"migrated" / "none" = 查過了。
--     **只要不是 nil 就永遠不再讀 MiliUI_DB**。沒東西可搬也蓋印記，不然每次登入
--     都要再看一次。
--   * 全程唯讀，不動 MiliUI_DB 一個字（玩家還在用套組的其他功能）。
--   * ResetDB 會把 db.warband 整包留著（記錄是資料不是設定，印記也在裡面）。
------------------------------------------------------------
local function MigrateFromMiliUI(store)
    local old = _G.MiliUI_DB
    if type(old) ~= "table" or type(old.characterKeystones) ~= "table" then return 0 end
    local moved = 0
    for key, rec in pairs(old.characterKeystones) do
        if type(rec) == "table" and store.characters[key] == nil then
            store.characters[key] = CopyTable(rec)
            moved = moved + 1
        end
    end
    return moved
end

------------------------------------------------------------
-- 事件
------------------------------------------------------------
local function OnEvent(event, ...)
    if event == "CHALLENGE_MODE_COMPLETED" then
        ScheduleKeystoneCheck(0)
        RequestVaultData(event)
    elseif event == "GOSSIP_CLOSED" then
        if IsKeystoneNpcGossip() then
            ScheduleKeystoneCheck(0)
        end
    elseif event == "PLAYER_LOGOUT" then
        -- 剛從寶庫領到本週鑰石後馬上登出，這之間沒有任何既有事件會重讀鑰石，
        -- 而 ScheduleKeystoneCheck 走 C_Timer 在登出瞬間不會執行 → 這裡同步補抓。
        -- 懸賞圖入手/用掉也常發生在最後一次快照之後，一併補存；讀的是快取，同步呼叫沒問題。
        local mapID, level = ReadOwnKeystoneState()
        if mapID > 0 and level > 0 then
            SaveKeystoneRecord(mapID, level)
        end
        SaveVaultSnapshot()
    -- 「資料已刷新」事件 → 直接存檔（此刻 GetActivities/GetRunHistory 才是新的）
    elseif event == "WEEKLY_REWARDS_UPDATE" then
        -- 領寶庫會給本週鑰石，但不觸發 CHALLENGE_MODE_COMPLETED / 鑰石 NPC gossip
        ScheduleKeystoneCheck(0)
        SnapshotAndRefresh(event)
    elseif event == "CHALLENGE_MODE_MAPS_UPDATE" then
        SnapshotAndRefresh(event)
    -- 「活動完成」事件 → 請求最新資料（等上面兩個事件回來才存）
    elseif event == "ENCOUNTER_END" then
        local _, _, difficultyID, _, success = ...
        if success == 1 and RAID_DIFFICULTY_IDS[difficultyID] then
            RequestVaultData(event)
        end
    elseif event == "PVP_MATCH_COMPLETE" or event == "LFG_COMPLETION_REWARD"
        or event == "QUEST_TURNED_IN" then
        RequestVaultData(event)
    elseif event == "BAG_UPDATE_DELAYED" then
        -- 撿到／用掉懸賞圖不會觸發上面任何寶庫事件，這裡便宜地比對一下，
        -- 狀態真的變了才走完整快照（SnapshotAndRefresh 自帶 debounce）
        local rec = Store().characters[GetCharacterKey()]
        local saved = rec and rec.vault and rec.vault.bounty
        local got   = C_QuestLog.IsQuestFlaggedCompleted(BOUNTY_FLAG_QUEST) and true or false
        local count = C_Item.GetItemCount(BOUNTY_ITEM_ID, true, false, true, true) or 0
        -- 與 SaveVaultSnapshot 相同的合併方向：讀到 false 視為冷快取、不算變化
        if saved and saved.got and not got then
            got, count = true, saved.count or 0
        end
        local changed
        if saved then
            changed = (saved.got ~= got) or ((saved.count or 0) ~= count)
        else
            changed = got or count > 0
        end
        if changed then
            SnapshotAndRefresh("bounty changed")
        end
    elseif event == "UPDATE_UI_WIDGET" then
        -- 高頻事件，先用 widgetID 守衛；命中才開信任窗口並排快照
        -- （SnapshotAndRefresh 的 0.3s debounce 落在 5 秒窗口內，讀值必被採信）
        local widgetInfo = ...
        if widgetInfo and STASH_WIDGET_LOOKUP[widgetInfo.widgetID] then
            stashTrustedUntil = GetTime() + 5
            SnapshotAndRefresh("stash widget")
        end
    elseif event == "ACTIVE_DELVE_DATA_UPDATE" or event == "ZONE_CHANGED_NEW_AREA" then
        -- 難度選擇器的 widget 只有在探究區域內是活資料，換區後補抓一次。
        -- 資料不一定跟事件同時到（Plumber 也延遲 0.5 秒），所以再排一次延遲快照。
        SnapshotAndRefresh(event)
        C_Timer.After(2, function() SnapshotAndRefresh(event .. " +2s") end)
    end
end

local TRACK_EVENTS = {
    "CHALLENGE_MODE_COMPLETED", "GOSSIP_CLOSED", "PLAYER_LOGOUT",
    "WEEKLY_REWARDS_UPDATE", "CHALLENGE_MODE_MAPS_UPDATE",
    "ENCOUNTER_END", "PVP_MATCH_COMPLETE", "LFG_COMPLETION_REWARD", "QUEST_TURNED_IN",
    "BAG_UPDATE_DELAYED", "UPDATE_UI_WIDGET",
    -- 只有 Plumber 在用這個事件名，萬一哪版被移除，ns.Events 內部的 pcall 會接住
    "ACTIVE_DELVE_DATA_UPDATE", "ZONE_CHANGED_NEW_AREA",
}

------------------------------------------------------------
-- 啟動：所有初始化都等 PLAYER_LOGIN（MiliUI_DB 要等 MiliUI 自己的 ADDON_LOADED
-- 才存在，等到 PLAYER_LOGIN 就不必猜載入順序）
------------------------------------------------------------
ns.Events.Register("PLAYER_LOGIN", "warband", function()
    ns.InitDB()
    local store = Store()

    if store.migration == nil then
        local moved = MigrateFromMiliUI(store)
        store.migration = moved > 0 and "migrated" or "none"
        if moved > 0 then
            -- 只講一次（印記已寫入，下次登入不會再進來）
            C_Timer.After(5, function()
                print(ns.PREFIX_COLOR .. L["ADDON_NAME"] .. "|r "
                    .. L["MSG_WARBAND_MIGRATED"]:format(moved))
            end)
        end
    end

    PruneOldRecords()
    -- 儲物箱 0/x 一律還原成「無資料」：顯示上兩者都是灰點，而 0 多半是探究區域外
    -- 讀到的預設殘值。真實的 0 進度下次靠近探究時會重新讀到，不損失資訊
    for _, data in pairs(store.characters) do
        if data.vault and data.vault.stash and (data.vault.stash.cur or 0) == 0 then
            data.vault.stash = nil
        end
    end

    for _, ev in ipairs(TRACK_EVENTS) do
        ns.Events.Register(ev, "warband", function(...) OnEvent(ev, ...) end)
    end

    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        HookChatEditbox(_G["ChatFrame" .. i .. "EditBox"])
    end

    C_Timer.After(BASELINE_DELAY, function()
        if baselineSet then return end
        local mapID, level = ReadOwnKeystoneState()
        lastOwnMapID, lastOwnLevel = mapID, level
        baselineSet = true
        Debug("Baseline: map=%d lv=%d", mapID, level)
        if mapID > 0 and level > 0 then
            SaveKeystoneRecord(mapID, level)
        end
        SaveVaultSnapshot()
        RequestVaultData("login baseline")
        Notify()
    end)
end)

------------------------------------------------------------
-- /mib stash：探測鍍金儲物箱 widget（在探究內、外各跑一次，把輸出貼回來）
------------------------------------------------------------
function Warband.ProbeStash()
    local getter = C_UIWidgetManager and C_UIWidgetManager.GetSpellDisplayVisualizationInfo
    if not getter then
        print("|cff00ff00[Warband]|r 此版本沒有 GetSpellDisplayVisualizationInfo")
        return
    end
    for _, id in ipairs(STASH_WIDGET_IDS) do
        local ok, info = pcall(getter, id)
        local si = ok and info and info.spellInfo
        if si then
            print(string.format(
                "|cff00ff00[Warband]|r widget %d: wShown=%s spellID=%s shown=%s tip=%s",
                id, tostring(info.shownState), tostring(si.spellID),
                tostring(si.shownState), tostring(S.PlainText(si.tooltip))))
        end
    end
    local read = ReadOwnGildedStash("probe")
    print(string.format("|cff00ff00[Warband]|r 目前判定：%s",
        read and string.format("%d/%d（%s）", read.cur, read.max,
            read.trusted and "活資料" or "殘值") or "讀不到"))
    -- 掃描附近的 widget ID，找其他帶「x/y」文字的候選（改版後 ID 可能換）
    local hits = 0
    for id = 7400, 7800 do
        if not STASH_WIDGET_LOOKUP[id] then
            local ok2, info2 = pcall(getter, id)
            local tip2 = ok2 and info2 and info2.spellInfo and S.PlainText(info2.spellInfo.tooltip)
            if tip2 and tip2:match("%d+%s*/%s*%d+") then
                hits = hits + 1
                print(string.format("  候選 widget %d (shown=%s): %s",
                    id, tostring(info2.spellInfo.shownState), tip2:sub(1, 120)))
            end
        end
    end
    print(string.format("|cff00ff00[Warband]|r 掃描完成：7400–7800 有 %d 個候選。", hits))
end
