------------------------------------------------------------
-- 同步副本／首領筆記給隊友（跟「分享」不一樣）
--
--   分享  一次性快照。對方點連結、按儲存，**變成他自己的一份**，之後各走各的。
--   同步  持續的。作者開著同步，改了筆記就自動推給隊伍；隊友看到的永遠是作者
--         最新的版本，而且**不會變成他的**（不寫進他的 SavedVariables）。
--
-- 只同步副本／首領筆記（那是「做副本給隊友」的情境）。一般筆記不走這條。
--
-- ── 收到的一方 ──────────────────────────────────────────
-- 收到的同步筆記放**記憶體**，鍵在 (instanceID, 難度, 首領)。離開隊伍、重載、
-- 一段時間沒更新就丟掉 —— 它是別人的活資料，不該在你的存檔裡陰魂不散。
-- 顯示規則：**自己那一格沒寫東西**才自動顯示同步版（帶「由 X 同步」橫幅）；
-- 自己寫了就顯示自己的（你的東西優先），同步版留在選單裡隨時可切。
--
-- ⚠ 12.1：全程只讀自己的身分，不碰隊友的 Unit API（受限身分下是秘密值）。
--   「任何人都能廣播」正好不需要判斷誰是隊長，天然閃開這個坑。
------------------------------------------------------------
local _, ns = ...

ns.Sync = {}
local Sync = ns.Sync

local Notes, Comm = ns.Notes, ns.Comm

local STALE_SEC   = 1800    -- 收到的同步放 30 分鐘沒更新就算過期
local PUSH_DELAY  = 2       -- 改筆記後多久才推（合併連續編輯）
local ALL = Notes.DIFF_ALL

------------------------------------------------------------
-- 收到的一方：記憶體暫存
--
-- store[instanceID][diffKey][encKey] = { note, from, time }
-- encKey：首領用 encounterID，副本總覽用 0（table key 不能是 nil）
------------------------------------------------------------
local store = {}
local OVERVIEW_KEY = 0

local function EncKey(encounterID)
    return encounterID or OVERVIEW_KEY
end

local function Put(instanceID, diffKey, encounterID, note, from)
    diffKey = Notes.NormalizeDiffKey(diffKey)
    store[instanceID] = store[instanceID] or {}
    store[instanceID][diffKey] = store[instanceID][diffKey] or {}
    store[instanceID][diffKey][EncKey(encounterID)] = {
        note = note, from = from, time = GetTime(),
    }
end

-- 回傳 note, from；沒有或過期就回 nil
function Sync.Get(instanceID, encounterID, diffKey)
    diffKey = Notes.NormalizeDiffKey(diffKey)
    local byDiff = store[instanceID]
    if not byDiff then return nil end
    local bucket = byDiff[diffKey]
    local slot = bucket and bucket[EncKey(encounterID)]
    if not slot then return nil end
    if GetTime() - slot.time > STALE_SEC then return nil end
    return slot.note, slot.from
end

-- 這個副本有沒有任何同步進來的東西（給選單標記／浮動視窗判斷）
function Sync.HasAny(instanceID)
    local byDiff = store[instanceID]
    if not byDiff then return false end
    for _, bucket in pairs(byDiff) do
        for _, slot in pairs(bucket) do
            if GetTime() - slot.time <= STALE_SEC then return true end
        end
    end
    return false
end

local function ClearStore()
    if next(store) ~= nil then
        wipe(store)
        ns.Fire("SyncChanged")
    end
end

------------------------------------------------------------
-- 廣播的一方
--
-- broadcasting 存在設定裡（跨登入記得）。開著又在隊伍裡的話：
--   * 進副本 / 有人加入 / 重載完 → 把有寫過的副本筆記整批推一次
--   * 改某個副本的筆記 → 只重推那個副本（合併連續編輯）
--   * 收到隊友的「拉取」請求 → 重推
------------------------------------------------------------
local function IsBroadcasting()
    return ns.db and ns.db.settings.share.broadcast == true
end
Sync.IsBroadcasting = IsBroadcasting

function Sync.SetBroadcast(on)
    if not ns.db then return end
    ns.db.settings.share.broadcast = on and true or false
    ns.Fire("SyncChanged")
    if on then Sync.PushAll() end
end

function Sync.ToggleBroadcast()
    Sync.SetBroadcast(not IsBroadcasting())
end

-- 一筆同步筆記的線路內容：復用 Notes 的序列化（info 帶著 instanceID/enc/diff）
local function PushNote(note, instanceID, encounterID, diffKey)
    if not note or Notes.IsEmpty(note) then return end
    local payload = Notes.Serialize(note, {
        kind        = encounterID and "boss" or "instance",
        instanceID  = instanceID,
        encounterID = encounterID,
        diff        = Notes.NormalizeDiffKey(diffKey),
    })
    if payload then Comm.SendGroup("SYNC", payload) end
end

-- 推一個副本所有難度、所有首領裡有寫東西的
local function PushInstance(instanceID)
    local entry = Notes.InstanceEntry(instanceID, false)
    if not entry then return end
    for diffKey, bucket in pairs(entry.diffs) do
        if bucket.overview and not Notes.IsEmpty(bucket.overview) then
            PushNote(bucket.overview, instanceID, nil, diffKey)
        end
        for encID, note in pairs(bucket.bosses) do
            PushNote(note, instanceID, encID, diffKey)
        end
    end
end

-- 有寫過筆記的副本全推一次
function Sync.PushAll()
    if not IsBroadcasting() then return end
    if not Comm.GroupChannel() then return end
    for instanceID in pairs(ns.db.instanceNotes) do
        if type(instanceID) == "number" then PushInstance(instanceID) end
    end
end

-- 改筆記 → 只重推那個副本（合併連續編輯）
local pendingPush = {}
local function SchedulePush(instanceID)
    if not IsBroadcasting() then return end
    if not Comm.GroupChannel() then return end
    if pendingPush[instanceID] then return end
    pendingPush[instanceID] = true
    C_Timer.After(PUSH_DELAY, function()
        pendingPush[instanceID] = nil
        if IsBroadcasting() and Comm.GroupChannel() then PushInstance(instanceID) end
    end)
end
Sync.SchedulePush = SchedulePush

------------------------------------------------------------
-- 收訊
------------------------------------------------------------
local function OnSync(sender, payload)
    if ns.db.settings.share.syncAccept == "none" then return end
    local note, info = Notes.Deserialize(payload)
    if not note or type(info) ~= "table" then return end
    if type(info.instanceID) ~= "number" then return end
    if info.kind ~= "boss" and info.kind ~= "instance" then return end

    local from = Comm.ShortName(sender)
    Put(info.instanceID, info.diff, info.encounterID, note, from)
    ns.Fire("SyncChanged")
end

-- 拉取請求：payload 是想要的 instanceID（空＝全部）
local function OnRequest(sender, payload)
    if not IsBroadcasting() then return end
    if not Comm.GroupChannel() then return end
    local id = tonumber(payload)
    if id then PushInstance(id) else Sync.PushAll() end
end

-- 主動拉一次（重載後、或玩家手動）：請隊伍裡開著廣播的人推給我
function Sync.Request(instanceID)
    if ns.db.settings.share.syncAccept == "none" then return end
    Comm.SendGroup("SREQ", instanceID and tostring(instanceID) or "")
end

Comm.Register("SYNC", OnSync)
Comm.Register("SREQ", OnRequest)

------------------------------------------------------------
-- 事件
------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event)
    if event == "GROUP_ROSTER_UPDATE" then
        if not Comm.GroupChannel() then
            ClearStore()          -- 離開隊伍：別人的資料清掉
        elseif IsBroadcasting() then
            C_Timer.After(2, Sync.PushAll)   -- 有人加入，等名單穩再推
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        if Comm.GroupChannel() then
            -- 重載後兩件事：開著廣播就把自己的推出去，同時拉一次別人的回來
            if IsBroadcasting() then C_Timer.After(3, Sync.PushAll) end
            if ns.db.settings.share.syncAccept ~= "none" then
                C_Timer.After(3.5, function() Sync.Request() end)
            end
        end

    elseif event == "ZONE_CHANGED_NEW_AREA" then
        -- 進副本時把這個副本推一次（隊友剛好走進來要看得到）
        if IsBroadcasting() then
            C_Timer.After(2, function()
                local jInst = ns.Journal.CurrentInstance()
                if jInst then PushInstance(jInst) end
            end)
        end
    end
end)

ns.RegisterCallback("Init", "sync", function()
    ev:RegisterEvent("GROUP_ROSTER_UPDATE")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
end)
