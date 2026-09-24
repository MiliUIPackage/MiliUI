------------------------------------------------------------
-- 鑰石更新通報：自己的鑰石變了就在隊伍貼出新鑰石連結
--   * M+ 完成：只有本場「鑰石主人」才貼（完成後全隊都會拿到新鑰石，不判斷的話每個人都會貼）
--   * 在鑰石 NPC 洗／換／降鑰石：永遠貼
--
-- 2026-09-24 從 MiliUI 本體的 Enhance/KeystoneAutoReport.lua 搬過來，設定在「聊天」分頁
-- （db.announce.newKey）。跟原版不同的兩處：
--   1. 鑰石主人判斷改讀 C_ChallengeMode.GetChallengeCompletionInfo（Run/Recorder.lua 用的
--      同一支）；原版的 GetCompletionInfo 是舊 API，拿不到時會一律判成「不是主人」而漏貼。
--   2. 送出前過聊天限制閘：完賽當下 ChallengeMode／Chat 限制可能還沒解除，
--      被擋就再等一秒，最多等 SEND_MAX_WAIT 次。
------------------------------------------------------------
local _, ns = ...

ns.KeystoneReport = {}
local KR = ns.KeystoneReport

local L = ns.L
local S = ns.Secret

local KEY_CHECK_DELAY     = 1   -- 事件後每次檢查的間隔秒數
local BASELINE_DELAY      = 10  -- 登入後多久記基準值
local KEY_CHECK_MAX_RETRY = 6   -- 鑰石還沒換新時最多重試幾次
local SEND_MAX_WAIT       = 30  -- 聊天被限制時最多等幾秒
local KEYSTONE_NPC_IDS = {      -- 鑰石 NPC（洗／換／降）
    [197711] = true,   -- 主城
    [197915] = true,   -- 副本內
}

local lastOwnMapID, lastOwnLevel = 0, 0
local baselineSet = false
local keyCheckTimer
local keystoneGossipOpen = false  -- GOSSIP_SHOW 當下判定是不是鑰石 NPC，給 GOSSIP_CLOSED 用

local function Enabled()
    local a = ns.db and ns.db.announce
    return a and a.newKey and true or false
end

-- 背包裡的真實鑰石連結。
-- 伺服器會把插件自己拼的 keystone 連結（詞綴對不齊等）當成偽造，剝掉外層只剩純文字
local function OwnedKeystoneLink()
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local link = info and S.PlainText(info.hyperlink)
            if link and link:find("|Hkeystone:", 1, true) then return link end
        end
    end
end

local function ReadOwnKeystone()
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

-- 剛完成的是不是「自己的」鑰石：完成前手上那把跟本場的地圖、層數都對得上。
-- 必須在事件當下叫（鑰石換新之前，lastOwn* 還是完成前的值）
local function CompletedWithOwnKeystone()
    local mapID, level
    local info = S.SafeCall(C_ChallengeMode.GetChallengeCompletionInfo)
    if type(info) == "table" then
        mapID, level = S.PlainNumber(info.mapChallengeModeID), S.PlainNumber(info.level)
    elseif C_ChallengeMode.GetCompletionInfo then
        local m, l = S.SafeCall(C_ChallengeMode.GetCompletionInfo)
        mapID, level = S.PlainNumber(m), S.PlainNumber(l)
    end
    if not mapID or mapID <= 0 or not level or level <= 0 then return false end
    return mapID == lastOwnMapID and level == lastOwnLevel
end

local function ChatBlocked()
    return ns.RestrictionActive("Chat") or ns.RestrictionActive("ChallengeMode")
end

local function Send(link, waited)
    if not Enabled() then return end
    local channel = ns.PartyChannel()
    if not channel then return end
    if ChatBlocked() then
        if (waited or 0) < SEND_MAX_WAIT then
            C_Timer.After(1, function() ns.Guard(Send, link, (waited or 0) + 1) end)
        end
        return
    end
    SendChatMessage(L["New keystone: %s"]:format(link), channel)
end

-- allowReport：要不要貼（NPC 洗鑰石永遠要；完成只有主人要）。
-- 不管貼不貼，偵測到的有效新鑰石都會更新基準值，後面的比對才不會失準
local function ScheduleCheck(retry, allowReport)
    if keyCheckTimer then return end
    keyCheckTimer = C_Timer.NewTimer(KEY_CHECK_DELAY, function()
        keyCheckTimer = nil
        ns.Guard(function()
            if C_MythicPlus and C_MythicPlus.RequestRewards then C_MythicPlus.RequestRewards() end
            local mapID, level = ReadOwnKeystone()

            if not baselineSet then
                lastOwnMapID, lastOwnLevel = mapID, level
                baselineSet = true
                return
            end

            -- 沒變（API 還沒更新），或暫時沒鑰石（舊的用掉、新的還沒發）：再等一次。
            -- 後者不能覆寫基準值 —— 那是鑰石主人判斷要用的「完成前那把」
            if (mapID == lastOwnMapID and level == lastOwnLevel) or mapID <= 0 or level <= 0 then
                if (retry or 0) < KEY_CHECK_MAX_RETRY then
                    ScheduleCheck((retry or 0) + 1, allowReport)
                end
                return
            end

            lastOwnMapID, lastOwnLevel = mapID, level
            if not allowReport then return end
            local link = OwnedKeystoneLink()
            if link then Send(link) end
        end)
    end)
end

local function SetBaseline()
    if baselineSet then return end
    lastOwnMapID, lastOwnLevel = ReadOwnKeystone()
    baselineSet = true
end

local function IsKeystoneNpc()
    local guid = S.PlainText(UnitGUID("npc") or UnitGUID("target"))
    if not guid then return false end
    local id = tonumber((select(6, strsplit("-", guid))))
    return id ~= nil and KEYSTONE_NPC_IDS[id] == true
end

function KR.Init()
    local f = CreateFrame("Frame")
    f:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    f:RegisterEvent("GOSSIP_SHOW")
    f:RegisterEvent("GOSSIP_CLOSED")
    C_Timer.After(BASELINE_DELAY, function() ns.Guard(SetBaseline) end)
    f:SetScript("OnEvent", function(_, event)
        if event == "CHALLENGE_MODE_COMPLETED" then
            -- 關掉也照樣追基準值，之後打開時比對才不會把舊變動當成新的
            ns.Guard(function() ScheduleCheck(0, CompletedWithOwnKeystone()) end)
        elseif event == "GOSSIP_SHOW" then
            -- 視窗開著時 "npc" 這個 unit 還有效，先記下是不是鑰石 NPC
            local ok, isKeyNpc = ns.Guard(IsKeystoneNpc)
            keystoneGossipOpen = ok and isKeyNpc or false
        elseif event == "GOSSIP_CLOSED" then
            if keystoneGossipOpen then
                keystoneGossipOpen = false
                ScheduleCheck(0, true)
            end
        end
    end)
end
