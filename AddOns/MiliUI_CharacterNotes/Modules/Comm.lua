------------------------------------------------------------
-- 插件通訊：切塊、排隊、重組，按訊息型別派送
--
-- 分享（一次性快照）與同步（持續更新）都走這一支，不各帶一份幾乎一樣的
-- 切塊／重組引擎 —— 那種重複正是這個套組最忌諱的（同一個 bug 要修兩次）。
--
-- 線路格式：`<TYPE>:<token>:<seq>:<total>:<piece>`
--   TYPE   純大寫字母，是訊息型別（OFFER / SYNC / SREQ…）
--   token  純英數，區分同時進行的多筆傳輸
--   piece  一段 payload；切點永遠落在 UTF-8 字元邊界
--
-- ⚠ 12.1：首領戰進行中／M+ 計時中／PvP 戰場中會封鎖插件訊息。這只擋「送」，
--   已經收到的照樣留著。
------------------------------------------------------------
local _, ns = ...

ns.Comm = {}
local Comm = ns.Comm

local PREFIX     = "MiliUI_CN"
local CHUNK_SIZE = 220        -- 插件訊息上限 255，留空間給表頭
local MAX_CHUNKS = 64
local SEND_INTERVAL = 0.2

local outQueue = {}
local pumping  = false
local incoming = {}   -- [sender.."\t"..type.."\t"..token] = { parts, total, time }
local handlers = {}   -- [TYPE] = function(sender, payload)

------------------------------------------------------------
-- 限制／自我判斷
------------------------------------------------------------
function Comm.IsRestricted()
    if IsEncounterInProgress and IsEncounterInProgress() then return true end
    if C_MythicPlus and C_MythicPlus.IsRunActive and C_MythicPlus.IsRunActive() then return true end
    if C_PvP and C_PvP.IsActiveBattlefield and C_PvP.IsActiveBattlefield() then return true end
    return false
end

function Comm.IsSelf(sender)
    if not sender or ns.issecret(sender) then return false end
    local me = UnitName("player")
    if not me or ns.issecret(me) then return false end
    if sender == me then return true end
    local realm = GetRealmName()
    return realm ~= nil and sender == (me .. "-" .. realm:gsub("%s+", ""))
end

-- "Name-Realm" → "Name"（顯示用；跨服同名機率極低）
function Comm.ShortName(sender)
    if not sender or ns.issecret(sender) then return nil end
    return sender:match("^([^-]+)") or sender
end

function Comm.GroupChannel()
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
    return nil
end

------------------------------------------------------------
-- 送
------------------------------------------------------------
local TOKEN_CHARS = "abcdefghijklmnopqrstuvwxyz0123456789"
local function NewToken()
    local t = {}
    for i = 1, 6 do
        local n = math.random(#TOKEN_CHARS)
        t[i] = TOKEN_CHARS:sub(n, n)
    end
    return table.concat(t)
end

-- ⚠ 不能在 UTF-8 字元中間切：半個中文字經過聊天管線不保證原封不動送到對面。
-- 切點往回退到字元邊界；退不了（資料本來就壞）就照原樣切，至少不會卡死。
local function SplitChunks(s, size)
    local out, i, n = {}, 1, #s
    while i <= n do
        local j = math.min(n, i + size - 1)
        if j < n then
            local k = j + 1
            while k > i do
                local b = s:byte(k)
                if b < 0x80 or b >= 0xC0 then break end
                k = k - 1
            end
            if k > i then j = k - 1 end
        end
        out[#out + 1] = s:sub(i, j)
        i = j + 1
    end
    return out
end

local function Pump()
    local job = table.remove(outQueue, 1)
    if not job then
        pumping = false
        return
    end
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        pcall(C_ChatInfo.SendAddonMessage, PREFIX, job.msg, job.channel, job.target)
    end
    C_Timer.After(SEND_INTERVAL, Pump)
end

local function Queue(msg, channel, target)
    outQueue[#outQueue + 1] = { msg = msg, channel = channel, target = target }
    if not pumping then
        pumping = true
        C_Timer.After(0, Pump)
    end
end

-- 回傳 true＝送出（排進佇列）、false＝沒送（頻道不對／被封鎖／太長）
function Comm.Send(msgType, payload, channel, target)
    if type(msgType) ~= "string" or not channel then return false end
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false end
    if Comm.IsRestricted() then return false end

    local pieces = SplitChunks(payload or "", CHUNK_SIZE)
    if #pieces == 0 then pieces = { "" } end
    if #pieces > MAX_CHUNKS then return false end

    local token, total = NewToken(), #pieces
    for i = 1, total do
        Queue(("%s:%s:%d:%d:%s"):format(msgType, token, i, total, pieces[i]), channel, target)
    end
    return true
end

-- 送給整個隊伍／團隊；回傳 true＝有送
function Comm.SendGroup(msgType, payload)
    local ch = Comm.GroupChannel()
    if not ch then return false end
    return Comm.Send(msgType, payload, ch)
end

------------------------------------------------------------
-- 收
------------------------------------------------------------
function Comm.Register(msgType, fn)
    handlers[msgType] = fn
end

local function Prune()
    local now = GetTime()
    for k, v in pairs(incoming) do
        if now - v.time > 60 then incoming[k] = nil end
    end
end

local function OnMessage(msg, sender)
    if Comm.IsSelf(sender) then return end
    if not sender or ns.issecret(sender) then return end

    local msgType, token, seq, total, piece =
        msg:match("^(%u+):(%w+):(%d+):(%d+):(.*)$")
    if not msgType or not handlers[msgType] then return end
    seq, total = tonumber(seq), tonumber(total)
    if not seq or not total or total < 1 or total > MAX_CHUNKS then return end
    if seq < 1 or seq > total then return end

    Prune()

    local key = sender .. "\t" .. msgType .. "\t" .. token
    local slot = incoming[key]
    if not slot or slot.total ~= total then
        slot = { parts = {}, total = total, time = GetTime() }
        incoming[key] = slot
    end
    slot.parts[seq] = piece
    slot.time = GetTime()

    for i = 1, total do
        if slot.parts[i] == nil then return end
    end
    incoming[key] = nil

    local ok, err = pcall(handlers[msgType], sender, table.concat(slot.parts))
    if not ok then ns.ReportError(err) end
end

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(_, event, ...)
    if event ~= "CHAT_MSG_ADDON" then return end
    local prefix, msg, _, sender = ...
    if prefix == PREFIX then OnMessage(msg, sender) end
end)

ns.RegisterCallback("Init", "comm", function()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    end
    f:RegisterEvent("CHAT_MSG_ADDON")
end)
