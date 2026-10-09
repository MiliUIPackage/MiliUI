------------------------------------------------------------
-- 事件倉：把暴雪時間軸上的事件收成一份自己的清單
--
-- 資料全部來自 C_EncounterTimeline 的事件（ADDED／STATE_CHANGED／TRACK_CHANGED／
-- COLOR_CHANGED／REMOVED），畫面用的剩餘秒數每幀現問 GetEventTimeRemaining。
--
-- 秘密值規則（12.1）：
--   * id、source、duration、maxQueueDuration 是 NeverSecret —— 可以比、可以當 key
--   * 首領事件（source 0）的 spellName／spellID／iconFileID／severity／icons 在戰鬥中是秘密值
--     ⇒ 只存、只往下傳給 SetTexture／SetText，**不比較、不串字、不當 key**
--   * 剩餘秒數、軌道、狀態沒有 SecretWhenEncounterEvent，是明文；保險起見照樣過 PlainNumber，
--     洗不出明文就不畫那一條（而不是讓整個 OnUpdate 炸掉）
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret
local O = ns.Owners

ns.Events = {}
local E = ns.Events

local SOURCE = Enum.EncounterTimelineEventSource or { Encounter = 0, Script = 1, EditMode = 2 }
local STATE  = Enum.EncounterTimelineEventState or { Active = 0, Paused = 1, Finished = 2, Canceled = 3 }
local TRACK  = Enum.EncounterTimelineTrack or {}

local records = {}   -- [eventID] = rec

local function Safe(fn, ...)
    if not fn then return end
    return S.SafeCall(fn, ...)
end

local function SourceKind(rec)
    if rec.rawSource == SOURCE.Encounter then return "blizzard" end
    if rec.rawSource == SOURCE.EditMode then return "editmode" end
    return O.IsMine(rec.id) and "mine" or "other"
end

local function Refresh(rec)
    local state = S.PlainNumber(Safe(C_EncounterTimeline.GetEventState, rec.id))
    if state then rec.state = state end
    local track = S.PlainNumber(Safe(C_EncounterTimeline.GetEventTrack, rec.id))
    if track then rec.track = track end
end

local function Add(info)
    if type(info) ~= "table" then return end
    local id = info.id
    if not id or records[id] then return end
    local rec = {
        id        = id,
        rawSource = info.source,
        name      = info.spellName,      -- 首領事件：秘密字串
        icon      = info.iconFileID,     -- 首領事件：秘密 fileID
        duration  = S.PlainNumber(info.duration),
        added     = GetTime(),
    }
    rec.color = Safe(C_EncounterTimeline.GetEventColor, id)
    Refresh(rec)
    records[id] = rec
    rec.kind = SourceKind(rec)
    if rec.kind == "other" then
        rec.owner = O.Match(info.spellName, info.iconFileID, info.duration)
        if rec.owner then O.NoteSeen(rec.owner) end
    end
    ns.Fire("TimelineEventAdded", rec)
    ns.Fire("TimelineChanged")
end

-- Owners 的 hook 晚於事件到達時回頭認領
function E.ClaimRecent(entry, window)
    local now = GetTime()
    for _, rec in pairs(records) do
        if rec.kind == "other" and not rec.owner and now - rec.added <= window
            and O.SameRequest(entry, rec.name, rec.icon, rec.duration) then
            rec.owner = entry.addon
            O.NoteSeen(entry.addon)
            ns.Fire("TimelineChanged")
            return true
        end
    end
end

-- Scheduler 拿到 AddScriptEvent 的回傳值時，事件可能已經先進來了
function E.MarkMine(id)
    O.MarkMine(id)
    local rec = records[id]
    if rec then
        rec.kind, rec.owner = "mine", nil
        ns.Fire("TimelineChanged")
    end
end

function E.Get(id)
    return records[id]
end

function E.Iterate()
    return pairs(records)
end

-- 編輯模式的示範事件不算（進編輯模式時暴雪會放一組，那時候我們要畫的是自己的預覽）
function E.HasAny()
    for _, rec in pairs(records) do
        if rec.kind ~= "editmode" then return true end
    end
    return false
end

------------------------------------------------------------
-- 給畫面用的快照
--
-- out 是呼叫端重複使用的陣列（每幀一次，不要每幀建新表）。每一項：
--   key, id, kind, owner, name, icon, rem, duration, paused, queued, color
-- filter(kind) 回傳 false 的那一類不收。
------------------------------------------------------------
local itemPool = {}

function E.Collect(out, filter)
    local n = 0
    for id, rec in pairs(records) do
        local state = rec.state
        local alive = state ~= STATE.Finished and state ~= STATE.Canceled
        local visibleTrack = rec.track ~= TRACK.Indeterminate
        if alive and visibleTrack and rec.kind ~= "editmode" and (not filter or filter(rec.kind)) then
            local rem = S.PlainNumber(Safe(C_EncounterTimeline.GetEventTimeRemaining, id))
            if rem then
                n = n + 1
                local it = itemPool[n]
                if not it then
                    it = {}
                    itemPool[n] = it
                end
                it.key, it.id, it.kind, it.owner = id, id, rec.kind, rec.owner
                it.name, it.icon, it.color = rec.name, rec.icon, rec.color
                it.rem, it.duration = rem, rec.duration
                it.paused = state == STATE.Paused
                it.queued = rem <= 0 and not it.paused
                it.mock = nil
                out[n] = it
            end
        end
    end
    for i = n + 1, #out do out[i] = nil end
    return n
end

------------------------------------------------------------
-- 事件
------------------------------------------------------------
local frame = CreateFrame("Frame")

local function Recover()
    -- 重載介面或戰鬥中才登入：已經在時間軸上的事件不會再派一次 ADDED
    local list = Safe(C_EncounterTimeline.GetEventList)
    if type(list) ~= "table" then return end
    for _, id in ipairs(list) do
        if not records[id] then
            Add(Safe(C_EncounterTimeline.GetEventInfo, id))
        end
    end
end

local handlers = {
    ENCOUNTER_TIMELINE_EVENT_ADDED = function(info)
        Add(info)
    end,
    ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED = function(id)
        local rec = records[id]
        if rec then
            Refresh(rec)
            ns.Fire("TimelineChanged")
        end
    end,
    ENCOUNTER_TIMELINE_EVENT_TRACK_CHANGED = function(id)
        local rec = records[id]
        if rec then Refresh(rec) end
    end,
    ENCOUNTER_TIMELINE_EVENT_COLOR_CHANGED = function(id)
        local rec = records[id]
        if rec then rec.color = Safe(C_EncounterTimeline.GetEventColor, id) end
    end,
    ENCOUNTER_TIMELINE_EVENT_REMOVED = function(id)
        if records[id] then
            records[id] = nil
            O.Forget(id)
            ns.Fire("TimelineChanged")
        end
    end,
    PLAYER_ENTERING_WORLD = function()
        wipe(records)
        Recover()
        ns.Fire("TimelineChanged")
    end,
}

for event in pairs(handlers) do
    -- 舊客戶端沒有這組事件時 RegisterEvent 會報錯，包起來
    pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function(_, event, ...)
    xpcall(handlers[event], ns.ReportError, ...)
end)
