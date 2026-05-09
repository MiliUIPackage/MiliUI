
---------------------------------------------------------------
-- MiliUI Enhance: Keystone Auto Report
-- 功能一：隊伍聊天完全匹配 key / keys / !key / !keys / 鑰石 時，以 LibKS addon channel
--   協議 (DBM-Core 的 LibKeystone 同款) 主動向隊員請求鑰石資料，
--   彙整後貼到隊伍。多人安裝本 plugin 時以 CLAIM 協議做確定性
--   leader election，只有 GUID 最小者回報，沒有 race condition。
-- 功能二：自己的鑰石變動時 (M+ 完成、城內洗鑰石、洗降級等)，
--   自動在隊伍裡貼出鑰石連結。
-- Author: Mili
---------------------------------------------------------------

local KS_PREFIX        = "LibKS"      -- LibKeystone 協議共用前綴
local DEDUP_PREFIX     = "MiliUIKey"  -- 本 plugin 內部去重用
local RESPOND_THROTTLE = 3            -- 回應請求的節流秒數 (對齊 LibKeystone)
local CLAIM_WINDOW     = 1.8          -- 收集 CLAIM + keystone 資料的窗口
local REPLY_COOLDOWN   = 30           -- 送出回報後的冷卻秒數
local LINE_SPACING     = 0.15         -- 每行之間小延遲避免 server throttle

local KEY_CHECK_DELAY  = 1             -- 事件後每次 check 間隔秒數
local BASELINE_DELAY   = 10            -- 登入後設定基準值延遲
local KEYSTONE_NPC_IDS = {             -- 鑰石 NPC (洗 / 換 / 降)
    [197711] = true,   -- 主城
    [197915] = true,   -- 副本內
}

local hasLibKeystone = false  -- PLAYER_LOGIN 時 re-evaluate，避免 load order 誤判
local issecretvalue = _G.issecretvalue or function() return false end

local collected = {}
local claims = {}
local scheduledSend
local lastReply = 0
local lastRespondedAt = 0

local lastOwnMapID, lastOwnLevel = 0, 0
local baselineSet = false
local keyCheckTimer

local function GetOwnKeystone()
    local level, mapID, rating = 0, 0, 0
    if (C_MythicPlus) then
        if (C_MythicPlus.GetOwnedKeystoneLevel) then
            level = C_MythicPlus.GetOwnedKeystoneLevel() or 0
        end
        if (C_MythicPlus.GetOwnedKeystoneChallengeMapID) then
            mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID() or 0
        end
    end
    if (C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary) then
        local s = C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")
        if (s and s.currentSeasonScore) then
            rating = s.currentSeasonScore
        end
    end
    return level, mapID, rating
end

local function GetPartyChannel()
    if (IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) then
        return "INSTANCE_CHAT"
    elseif (IsInGroup()) then
        return "PARTY"
    end
end

local function RespondToKSRequest(channel)
    if (hasLibKeystone) then return end
    local now = GetTime()
    if (now - lastRespondedAt < RESPOND_THROTTLE) then return end
    lastRespondedAt = now
    local level, mapID, rating = GetOwnKeystone()
    C_ChatInfo.SendAddonMessage(KS_PREFIX,
        string.format("%d,%d,%d", level, mapID, rating), channel)
end

local function CollectSelfKeystone()
    local level, mapID, rating = GetOwnKeystone()
    if (level > 0 and mapID > 0) then
        collected[UnitName("player")] = { level = level, mapID = mapID, rating = rating }
    end
end

local function OnKSMessage(text, channel, sender)
    if (issecretvalue(text)) then return end
    if (type(text) ~= "string") then return end
    if (text == "R") then
        RespondToKSRequest(channel)
        return
    end
    local lvlStr, mapStr, rateStr = text:match("^(%-?%d+),(%-?%d+),(%d+)$")
    if (not lvlStr) then return end
    local level = tonumber(lvlStr)
    local mapID = tonumber(mapStr)
    if (not level or not mapID or level <= 0 or mapID <= 0) then return end
    collected[Ambiguate(sender, "none")] = {
        level = level,
        mapID = mapID,
        rating = tonumber(rateStr) or 0,
    }
end

local TRIGGER_KEYWORDS = { ["key"]=true, ["keys"]=true, ["!key"]=true, ["!keys"]=true, ["鑰石"]=true }

local function MatchKeyword(msg)
    if (issecretvalue(msg)) then return false end
    if (type(msg) ~= "string") then return false end
    return TRIGGER_KEYWORDS[msg:match("^%s*(.-)%s*$"):lower()] or false
end

local function FormatReply()
    local lines = {}
    for sender, info in pairs(collected) do
        local mapName = C_ChallengeMode and C_ChallengeMode.GetMapUIInfo
            and C_ChallengeMode.GetMapUIInfo(info.mapID) or "?"
        lines[#lines + 1] = string.format("%s: %s (+%d)", sender, mapName, info.level)
    end
    table.sort(lines)
    return lines
end

local function SendReply()
    local channel = GetPartyChannel()
    if (not channel) then return end
    local lines = FormatReply()
    if (#lines == 0) then return end
    lastReply = GetTime()
    C_ChatInfo.SendAddonMessage(DEDUP_PREFIX, "SENT", channel)
    for i, line in ipairs(lines) do
        C_Timer.After((i - 1) * LINE_SPACING, function()
            SendChatMessage(line, channel)
        end)
    end
end

local function OnTrigger()
    if (scheduledSend) then return end
    if (GetTime() - lastReply < REPLY_COOLDOWN) then return end
    local channel = GetPartyChannel()
    if (not channel) then return end
    local me = UnitGUID("player")
    if (not me) then return end

    wipe(collected)
    wipe(claims)
    claims[me] = true
    CollectSelfKeystone()

    C_ChatInfo.SendAddonMessage(KS_PREFIX, "R", channel)
    C_ChatInfo.SendAddonMessage(DEDUP_PREFIX, "CLAIM:" .. me, channel)

    scheduledSend = C_Timer.NewTimer(CLAIM_WINDOW, function()
        scheduledSend = nil
        local winner = me
        for id in pairs(claims) do
            if (id < winner) then winner = id end
        end
        if (winner == me) then
            SendReply()
        end
        wipe(collected)
        wipe(claims)
    end)
end

local function OnPeerDedup(text)
    if (issecretvalue(text)) then return end
    if (type(text) ~= "string") then return end
    if (text == "SENT") then
        if (scheduledSend) then
            scheduledSend:Cancel()
            scheduledSend = nil
        end
        lastReply = GetTime()
        wipe(collected)
        wipe(claims)
        return
    end
    local id = text:match("^CLAIM:(.+)$")
    if (id) then
        claims[id] = true
    end
end

-- === 自己鑰石變動自動貼出 ===

-- 掃背包找出當前身上的鑰石 hyperlink。
-- server 會把 addon 自己拼的 keystone 連結（affix 對不齊等）當作偽造剝掉外層
-- |H..|h，只留下純文字。直接用背包裡的真實連結就不會被過濾。
local function GetOwnedKeystoneHyperlink()
    if (not C_Container or not C_Container.GetContainerNumSlots
        or not C_Container.GetContainerItemInfo) then return nil end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if (info and type(info.hyperlink) == "string"
                and info.hyperlink:find("|Hkeystone:", 1, true)) then
                return info.hyperlink
            end
        end
    end
end

local function BuildKeystoneLink(mapID, level)
    if (not mapID or mapID <= 0 or not level or level <= 0) then return end
    return GetOwnedKeystoneHyperlink()
end

local function ReadOwnKeystoneState()
    local mapID, level = 0, 0
    if (C_MythicPlus) then
        if (C_MythicPlus.GetOwnedKeystoneChallengeMapID) then
            mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID() or 0
        end
        if (C_MythicPlus.GetOwnedKeystoneLevel) then
            level = C_MythicPlus.GetOwnedKeystoneLevel() or 0
        end
    end
    return mapID, level
end

local KEY_CHECK_MAX_RETRY = 6   -- 最多重試次數 (API 延遲時才需要)

local function ScheduleKeystoneCheck(retry)
    if (keyCheckTimer) then return end
    keyCheckTimer = C_Timer.NewTimer(KEY_CHECK_DELAY, function()
        keyCheckTimer = nil
        if (C_MythicPlus and C_MythicPlus.RequestRewards) then
            C_MythicPlus.RequestRewards()
        end
        local mapID, level = ReadOwnKeystoneState()

        if (not baselineSet) then
            lastOwnMapID, lastOwnLevel = mapID, level
            baselineSet = true
            return
        end

        if (mapID == lastOwnMapID and level == lastOwnLevel) then
            -- 沒變動：可能是 API 還沒更新，再試一次
            if ((retry or 0) < KEY_CHECK_MAX_RETRY) then
                ScheduleKeystoneCheck((retry or 0) + 1)
            end
            return
        end
        lastOwnMapID, lastOwnLevel = mapID, level

        if (mapID <= 0 or level <= 0) then return end

        local channel = GetPartyChannel()
        if (not channel) then return end
        local link = BuildKeystoneLink(mapID, level)
        if (link) then
            SendChatMessage("鑰石更新：" .. link, channel)
        end
    end)
end

local function CheckOwnKeystoneChanged()
    ScheduleKeystoneCheck(0)
end

local function SetBaselineIfNeeded()
    if (baselineSet) then return end
    local mapID, level = ReadOwnKeystoneState()
    lastOwnMapID, lastOwnLevel = mapID, level
    baselineSet = true
end

local function IsKeystoneNpcGossip()
    local guid = UnitGUID("npc") or UnitGUID("target")
    if (type(guid) ~= "string") then return false end
    if (issecretvalue(guid)) then return false end
    local ok, part = pcall(function() return select(6, strsplit("-", guid)) end)
    if (not ok) then return false end
    local id = tonumber(part)
    return id ~= nil and KEYSTONE_NPC_IDS[id] == true
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event, ...)
    if (event == "PLAYER_LOGIN") then
        hasLibKeystone = _G.LibStub and _G.LibStub("LibKeystone", true) ~= nil
        C_ChatInfo.RegisterAddonMessagePrefix(KS_PREFIX)
        C_ChatInfo.RegisterAddonMessagePrefix(DEDUP_PREFIX)
        self:RegisterEvent("CHAT_MSG_PARTY")
        self:RegisterEvent("CHAT_MSG_PARTY_LEADER")
        self:RegisterEvent("CHAT_MSG_INSTANCE_CHAT")
        self:RegisterEvent("CHAT_MSG_INSTANCE_CHAT_LEADER")
        self:RegisterEvent("CHAT_MSG_ADDON")
        self:RegisterEvent("CHALLENGE_MODE_COMPLETED")
        self:RegisterEvent("GOSSIP_CLOSED")
        C_Timer.After(BASELINE_DELAY, SetBaselineIfNeeded)
    elseif (event == "CHALLENGE_MODE_COMPLETED") then
        CheckOwnKeystoneChanged()
    elseif (event == "GOSSIP_CLOSED") then
        if (IsKeystoneNpcGossip()) then
            CheckOwnKeystoneChanged()
        end
    elseif (event == "CHAT_MSG_ADDON") then
        local prefix, text, channel, sender = ...
        if (prefix == KS_PREFIX) then
            OnKSMessage(text, channel, sender)
        elseif (prefix == DEDUP_PREFIX) then
            OnPeerDedup(text)
        end
    else
        local msg = ...
        if (MatchKeyword(msg)) then
            OnTrigger()
        end
    end
end)

