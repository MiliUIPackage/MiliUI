------------------------------------------------------------
-- MiliUI 版本檢測
-- 仿 DBM 的做法，透過 Addon Message 在公會 / 隊伍 / 團隊間
-- 互相廣播版本號（YYYYMMDD），收到比自己新的就提示一次。
--
-- 設計重點：
--   1. 版本號從 TOC 的「## Version」讀取，純整數比較。
--   2. 通道：公會（PLAYER_LOGIN 後）、隊伍 / 團隊（進場 + 名單變動）
--      皆有 30 秒節流。
--   3. 一個 session 只提示一次，避免洗版。
--   4. 自己發給自己的訊息不會誤觸發（版本相等不提示）。
------------------------------------------------------------

local AddonName, _ = ...
if AddonName ~= "MiliUI" then return end

local PREFIX = "MiliUI_VC"
local THROTTLE_SEC = 30
local NOTICE_DELAY = 8  -- 收到後延遲幾秒才提示，避免和登入訊息撞在一起

local C_ChatInfo = C_ChatInfo
local C_AddOns   = C_AddOns
local C_Timer    = C_Timer
local IsInGuild, IsInRaid, IsInGroup = IsInGuild, IsInRaid, IsInGroup
local GetTime    = GetTime
local UnitName   = UnitName
local GetRealmName = GetRealmName

-- 讀 TOC 版本號
local function ReadVersion()
    local meta = C_AddOns and C_AddOns.GetAddOnMetadata
    if not meta then return 0 end
    local v = meta(AddonName, "Version")
    return tonumber(v) or 0
end

local MY_VERSION = ReadVersion()
local hasNotified = false  -- 整場 session 只提示一次
local sendThrottle = {}    -- [channel] = lastSendTime

local function SendVersion(channel)
    if MY_VERSION == 0 then return end
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
    local now = GetTime()
    if sendThrottle[channel] and (now - sendThrottle[channel]) < THROTTLE_SEC then
        return
    end
    sendThrottle[channel] = now
    C_ChatInfo.SendAddonMessage(PREFIX, tostring(MY_VERSION), channel)
end

local function SendToGroupChannel()
    if IsInRaid() then
        SendVersion("RAID")
    elseif IsInGroup() then
        SendVersion("PARTY")
    end
end

local function ScheduleNotice()
    if hasNotified then return end
    hasNotified = true
    C_Timer.After(NOTICE_DELAY, function()
        print("|cff00ff00[MiliUI]|r 偵測到更新版本的米利UI，請記得更新插件來獲取更好的遊戲體驗！")
    end)
end

local function IsSelf(sender)
    if not sender then return false end
    -- sender 通常是 "Name-Realm"
    local me = UnitName("player")
    if not me then return false end
    if sender == me then return true end
    local realm = GetRealmName()
    if realm and sender == (me .. "-" .. realm:gsub("%s+", "")) then return true end
    return false
end

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
        if IsInGuild() then
            C_Timer.After(5, function() SendVersion("GUILD") end)
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        SendToGroupChannel()

    elseif event == "GROUP_ROSTER_UPDATE" then
        SendToGroupChannel()

    elseif event == "CHAT_MSG_ADDON" then
        local prefix, msg, _, sender = ...
        if prefix ~= PREFIX then return end
        if IsSelf(sender) then return end
        local theirVersion = tonumber(msg)
        if theirVersion and MY_VERSION > 0 and theirVersion > MY_VERSION then
            ScheduleNotice()
        end
    end
end)
