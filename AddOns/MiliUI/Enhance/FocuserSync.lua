------------------------------------------------------------
-- MiliUI Focuser 隊友標記同步
-- 在隊伍／團隊裡互相廣播「我的焦點自動標記是哪一號」，讓標記切換列的
-- tooltip 能顯示隊友設定（撞號一眼看得出來），宣告時也一併帶上。
--
-- 通訊沿用 VersionCheck.lua 的配方（私有前綴 + IsCommRestricted 擋門）。
------------------------------------------------------------
local AddonName = ...
if AddonName ~= "MiliUI" then return end

MiliUI_FocuserSync = {}

local PREFIX = "MiliUI_FM"

-- 協定：`<版本>:<標記編號>[:r]`
--   標記編號 0 = 對方有裝米利UI但沒開自動標記
--   結尾 :r  = 這是「回覆」，收到回覆不再回覆（避免互相回不停）
local PROTOCOL = 1

local SEND_THROTTLE  = 5     -- 自己主動送的最短間隔
local REPLY_THROTTLE = 10    -- 收到別人廣播後，多久內不重複回覆
local PEER_STALE_SEC = 1800  -- 超過這麼久沒更新就不顯示（30 分鐘）

local C_ChatInfo, C_Timer = C_ChatInfo, C_Timer
local IsInRaid, IsInGroup = IsInRaid, IsInGroup
local GetTime, UnitName, GetRealmName = GetTime, UnitName, GetRealmName
local GetNumGroupMembers = GetNumGroupMembers

-- 12.1 的秘密值：名字有可能是秘密字串，拿它當 table key 會直接崩潰
-- （"cannot be indexed with secret keys"）。所有名字進表前都先擋一次。
local issecret = issecretvalue or function() return false end

-- peers[短名] = { index = 0..8, time = GetTime() }
local peers = {}
local lastSend = 0

----------------------------------------------------------------------
-- 通訊
----------------------------------------------------------------------
-- 12.1：首領戰進行中／M+ 計時中／PvP 戰場中會封鎖 addon message（抄 Cell 的
-- IsCommRestricted）。注意這只擋「送」，**不清掉已經收到的資料** —— M+ 開始
-- 前在隊伍裡收到的設定，整趟鑰石都還用得上，正是最需要它的場合。
local function IsCommRestricted()
    if IsEncounterInProgress and IsEncounterInProgress() then return true end
    if C_MythicPlus and C_MythicPlus.IsRunActive and C_MythicPlus.IsRunActive() then return true end
    if C_PvP and C_PvP.IsActiveBattlefield and C_PvP.IsActiveBattlefield() then return true end
    return false
end

local function GroupChannel()
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
    return nil
end

local function MyIndex()
    if MiliUI_Focuser and MiliUI_Focuser.GetEffectiveMarkIndex then
        return MiliUI_Focuser.GetEffectiveMarkIndex()
    end
    return 0
end

local function Send(isReply)
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
    local channel = GroupChannel()
    if not channel then return end
    -- 擋在節流之前：被封鎖的嘗試不該吃掉節流窗口（同 VersionCheck 的理由）
    if IsCommRestricted() then return end
    local now = GetTime()
    if not isReply and (now - lastSend) < SEND_THROTTLE then return end
    lastSend = now
    local msg = PROTOCOL .. ":" .. MyIndex() .. (isReply and ":r" or "")
    C_ChatInfo.SendAddonMessage(PREFIX, msg, channel)
end

local function IsSelf(sender)
    if not sender or issecret(sender) then return false end
    local me = UnitName("player")
    if not me or issecret(me) then return false end
    if sender == me then return true end
    local realm = GetRealmName()
    return realm ~= nil and sender == (me .. "-" .. realm:gsub("%s+", ""))
end

-- "Name-Realm" → "Name"。跨服同名機率極低，而這只是給 tooltip 看的
local function ShortName(sender)
    if not sender or issecret(sender) then return nil end
    return sender:match("^([^-]+)") or sender
end

----------------------------------------------------------------------
-- 名單維護
----------------------------------------------------------------------
-- 回傳目前隊伍／團隊成員的短名集合；名字是秘密值時回 nil 代表「不確定」，
-- 呼叫端就跳過清理（寧可留著過期資料也不要誤刪或崩潰）
local function GroupShortNames()
    if not IsInGroup() then return {} end
    local set, unknown = {}, false
    local n = GetNumGroupMembers() or 0
    local prefix, count
    if IsInRaid() then prefix, count = "raid", n else prefix, count = "party", n - 1 end
    for i = 1, count do
        local name = UnitName(prefix .. i)
        if name == nil or issecret(name) then
            unknown = true
        else
            set[name] = true
        end
    end
    if unknown then return nil end
    return set
end

local function PrunePeers()
    if not IsInGroup() then
        wipe(peers)
        return
    end
    local set = GroupShortNames()
    if not set then return end   -- 名字讀不到，這次不清
    for name in pairs(peers) do
        if not set[name] then peers[name] = nil end
    end
end

----------------------------------------------------------------------
-- 對外
----------------------------------------------------------------------
-- 回傳陣列 { { name = 短名, index = 0..8 }, ... }
-- 先依標記編號排序（沒設定的 0 排最後），同編號再依名字
function MiliUI_FocuserSync.GetPeers()
    local list, now = {}, GetTime()
    for name, info in pairs(peers) do
        if (now - info.time) <= PEER_STALE_SEC then
            list[#list + 1] = { name = name, index = info.index }
        end
    end
    table.sort(list, function(a, b)
        local ka = a.index == 0 and 99 or a.index
        local kb = b.index == 0 and 99 or b.index
        if ka ~= kb then return ka < kb end
        return a.name < b.name
    end)
    return list
end

function MiliUI_FocuserSync.IsRestricted()
    return IsCommRestricted()
end

-- 自己的設定改了 → 主動廣播（會順便引來隊友回覆，資料一起補齊）
function MiliUI_FocuserSync.Broadcast()
    Send(false)
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- 進場／重載後主動報到。隊友收到會回覆，等於同時把他們的設定要回來
        -- （光靠 GROUP_ROSTER_UPDATE 不夠：自己重載 UI 時別人的名單沒變動）
        C_Timer.After(3, function() Send(false) end)

    elseif event == "GROUP_ROSTER_UPDATE" then
        PrunePeers()
        C_Timer.After(2, function() Send(false) end)   -- 等名單穩定再送

    elseif event == "CHAT_MSG_ADDON" then
        local prefix, msg, _, sender = ...
        if prefix ~= PREFIX then return end
        if IsSelf(sender) then return end

        local ver, index, tag = msg:match("^(%d+):(%d+):?(%a*)$")
        if tonumber(ver) ~= PROTOCOL then return end
        index = tonumber(index)
        if not index or index < 0 or index > 8 then return end

        local name = ShortName(sender)
        if not name then return end
        peers[name] = { index = index, time = GetTime() }

        -- 對方是主動廣播（不是回覆）→ 回一則，讓他也知道我的設定。
        -- 回覆不會再引發回覆，所以不可能無限來回。
        if tag ~= "r" and (GetTime() - lastSend) >= REPLY_THROTTLE then
            lastSend = GetTime()
            -- 錯開 0.5~2.5 秒，避免整團同時回造成瞬間爆量
            C_Timer.After(0.5 + math.random() * 2, function() Send(true) end)
        end
    end
end)
