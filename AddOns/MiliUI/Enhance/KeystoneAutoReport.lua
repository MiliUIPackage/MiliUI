
---------------------------------------------------------------
-- MiliUI Enhance: Keystone Auto Report
-- 功能一：隊伍聊天偵測到 key / keys / 鑰匙 / 鑰石 關鍵字
--   (排除 !key / !keys 與超連結內) 時，以 LibKS addon channel
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

local KEYSTONE_ITEM_ID = 180653        -- Mythic Keystone item ID
local KEY_LINK_COLOR   = "ffa335ee"    -- epic purple
local KEY_CHECK_DELAY  = 3             -- 事件後延遲秒數 (等 API 更新)
local BASELINE_DELAY   = 10            -- 登入後設定基準值延遲

local hasLibKeystone = false  -- PLAYER_LOGIN 時 re-evaluate，避免 load order 誤判

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

local function MatchKeyword(msg)
    if (not msg or msg == "") then return false end
    -- 去除超連結，避免 |Hkeystone:...|h[鑰石:...]|h 這種別人貼的鑰石連結觸發
    local stripped = msg:gsub("|H.-|h.-|h", " ")
    local lower = stripped:lower()
    if (lower:find("鑰匙", 1, true) or lower:find("鑰石", 1, true)) then
        return true
    end
    local pos = 1
    while (pos) do
        local s, e = lower:find("key", pos, true)
        if (not s) then break end
        local prev = (s > 1) and lower:sub(s - 1, s - 1) or ""
        local after = lower:sub(e + 1, e + 1)
        local isWordStart = prev == "" or not prev:match("[%w]")
        local notExcluded = prev ~= "!"
        local isWordEnd
        if (after == "s") then
            local after2 = lower:sub(e + 2, e + 2)
            isWordEnd = after2 == "" or not after2:match("[%w]")
        else
            isWordEnd = after == "" or not after:match("[%w]")
        end
        if (isWordStart and notExcluded and isWordEnd) then
            return true
        end
        pos = e + 1
    end
    return false
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

local function GetCurrentAffixIDs()
    local a1, a2, a3 = 0, 0, 0
    if (C_MythicPlus and C_MythicPlus.GetCurrentAffixes) then
        local affixes = C_MythicPlus.GetCurrentAffixes()
        if (affixes) then
            a1 = (affixes[1] and affixes[1].id) or 0
            a2 = (affixes[2] and affixes[2].id) or 0
            a3 = (affixes[3] and affixes[3].id) or 0
        end
    end
    return a1, a2, a3
end

local function BuildKeystoneLink(mapID, level)
    if (not mapID or mapID <= 0 or not level or level <= 0) then return end
    local mapName = (C_ChallengeMode and C_ChallengeMode.GetMapUIInfo
        and C_ChallengeMode.GetMapUIInfo(mapID)) or "?"
    local a1, a2, a3 = 0, 0, 0
    if (level >= 10) then
        a1, a2, a3 = GetCurrentAffixIDs()
    elseif (level >= 7) then
        a1, a2 = GetCurrentAffixIDs()
    elseif (level >= 4) then
        a1 = (GetCurrentAffixIDs())
    end
    return string.format("|c%s|Hkeystone:%d:%d:%d:%d:%d:%d:0:0|h[%s: %s (%d)]|h|r",
        KEY_LINK_COLOR, KEYSTONE_ITEM_ID, mapID, level, a1, a2, a3,
        "鑰石", mapName, level)
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

local function CheckOwnKeystoneChanged()
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

        if (mapID == lastOwnMapID and level == lastOwnLevel) then return end
        lastOwnMapID, lastOwnLevel = mapID, level

        if (mapID <= 0 or level <= 0) then return end

        local channel = GetPartyChannel()
        if (not channel) then return end
        local link = BuildKeystoneLink(mapID, level)
        if (link) then
            SendChatMessage(link, channel)
        end
    end)
end

local function SetBaselineIfNeeded()
    if (baselineSet) then return end
    local mapID, level = ReadOwnKeystoneState()
    lastOwnMapID, lastOwnLevel = mapID, level
    baselineSet = true
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
    elseif (event == "CHALLENGE_MODE_COMPLETED" or event == "GOSSIP_CLOSED") then
        CheckOwnKeystoneChanged()
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
