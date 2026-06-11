
---------------------------------------------------------------
-- MiliUI Enhance: Keystone Auto Report (自己鑰石變動自動通報)
-- 自己的鑰石變動時，自動在隊伍裡貼出鑰石連結：
--   * M+ 完成：僅當你是本場「鑰石主人」時才通報
--     (完成後全隊都會拿到新鑰石，不判斷會讓非主人也誤報)。
--   * 在鑰石 NPC 主動洗 / 換 / 降鑰石：永遠通報。
--
-- 「查看隊友鑰石」(鑰石頁面面板、打字 key/鑰石 彙報全隊) 已移到
-- Enhance/PartyKeystone.lua，改用 LibOpenRaid + LibKeystone 可靠同步。
-- Author: Mili
---------------------------------------------------------------

local KEY_CHECK_DELAY     = 1   -- 事件後每次 check 間隔秒數
local BASELINE_DELAY      = 10  -- 登入後設定基準值延遲
local KEY_CHECK_MAX_RETRY = 6   -- 最多重試次數 (API 延遲時才需要)
local KEYSTONE_NPC_IDS = {      -- 鑰石 NPC (洗 / 換 / 降)
    [197711] = true,   -- 主城
    [197915] = true,   -- 副本內
}

local issecretvalue = _G.issecretvalue or function() return false end

local lastOwnMapID, lastOwnLevel = 0, 0
local baselineSet = false
local keyCheckTimer
local keystoneGossipOpen = false  -- GOSSIP_SHOW 當下判定是否為鑰石 NPC，供 GOSSIP_CLOSED 使用

local function GetPartyChannel()
    if (IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) then
        return "INSTANCE_CHAT"
    elseif (IsInGroup()) then
        return "PARTY"
    end
end

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

-- 判斷剛完成的副本是否使用「自己的」鑰石。
-- 完成 M+ 後隊伍每位成員都會獲得新鑰石，若不判斷，非鑰石主人也會誤報。
-- 完成前自己持有的鑰石 (lastOwnMapID/Level) 與本場副本的 mapID/level 相符者，才是鑰石主人。
-- 必須在事件當下 (鑰石尚未被換新前) 呼叫，lastOwnMapID/Level 此時仍為完成前的值。
local function CompletedWithOwnKeystone()
    if (not C_ChallengeMode or not C_ChallengeMode.GetCompletionInfo) then
        return false
    end
    local mapID, level = C_ChallengeMode.GetCompletionInfo()
    if (not mapID or mapID <= 0 or not level or level <= 0) then return false end
    return mapID == lastOwnMapID and level == lastOwnLevel
end

-- allowReport：是否允許把變動貼到隊伍 (NPC 洗鑰石永遠允許；副本完成僅 key 主人允許)。
-- 無論是否允許通報，偵測到的有效新鑰石都會更新 baseline，避免後續比對失準。
local function ScheduleKeystoneCheck(retry, allowReport)
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
                ScheduleKeystoneCheck((retry or 0) + 1, allowReport)
            end
            return
        end

        -- 暫時無鑰石的狀態 (剛完成、舊 key 已消耗但新 key 尚未發到手；或在副本內啟動 key)：
        -- 不覆寫 baseline (保留「完成前的 key」供 key 主人判斷)，且需繼續重試，
        -- 否則 key 主人會在這個空窗期被直接中止而漏報。
        if (mapID <= 0 or level <= 0) then
            if ((retry or 0) < KEY_CHECK_MAX_RETRY) then
                ScheduleKeystoneCheck((retry or 0) + 1, allowReport)
            end
            return
        end

        lastOwnMapID, lastOwnLevel = mapID, level

        if (not allowReport) then return end  -- 非本場 key 主人 / 被動取得，不通報

        local channel = GetPartyChannel()
        if (not channel) then return end
        local link = BuildKeystoneLink(mapID, level)
        if (link) then
            SendChatMessage("鑰石更新：" .. link, channel)
        end
    end)
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
        self:RegisterEvent("CHALLENGE_MODE_COMPLETED")
        self:RegisterEvent("GOSSIP_SHOW")
        self:RegisterEvent("GOSSIP_CLOSED")
        C_Timer.After(BASELINE_DELAY, SetBaselineIfNeeded)
    elseif (event == "CHALLENGE_MODE_COMPLETED") then
        -- 僅本場「key 主人」才通報，避免完成後每位隊員都被換新鑰石而誤報。
        ScheduleKeystoneCheck(0, CompletedWithOwnKeystone())
    elseif (event == "GOSSIP_SHOW") then
        -- 視窗開啟時 "npc" unit 仍有效，先判定是否為鑰石 NPC 並記下旗標。
        keystoneGossipOpen = IsKeystoneNpcGossip()
    elseif (event == "GOSSIP_CLOSED") then
        if (keystoneGossipOpen) then
            keystoneGossipOpen = false
            -- 在鑰石 NPC 主動洗 / 換 / 降鑰石，永遠允許通報。
            ScheduleKeystoneCheck(0, true)
        end
    end
end)
