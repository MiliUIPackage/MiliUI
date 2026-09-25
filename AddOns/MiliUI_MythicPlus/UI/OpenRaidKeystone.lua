------------------------------------------------------------
-- LibOpenRaid 鑰石協定的精簡接收端
--
-- 原本內嵌整包 LibOpenRaid（880 KB，連同 AceComm／AceSerializer／CallbackHandler），
-- 但我們只用它一件事：聽 Details!／Plater 等插件的使用者廣播的鑰石。那包另外還
-- 常駐一支 0.05 秒的發送排程、每次 BAG_UPDATE 排計時器、追蹤冷卻與裝備。
-- 這裡只實作協定裡的兩種訊息，其餘全部不碰：
--
--   前綴 "LRS"，內容 = LibDeflate:EncodeForWoWAddonChannel(CompressDeflate(明文))
--   明文 "J"                                  → 請求：「把你的鑰石發過來」
--   明文 "K,等級,mapID,challengeMapID,classID,分數,mythicPlusMapID,specID" → 鑰石資料
--
-- 只收不回：別人發 "J" 時我們不回自己的鑰石（隊友的 LibKeystone 那條還是會回）。
-- 協定出處：LibOpenRaid.lua 的 ~comms 與 ~keystones 兩段（CONST_LIB_VERSION 177）。
--
-- 對方送出時走 AceComm；短訊息 AceComm 原樣送出，所以這裡直接聽 CHAT_MSG_ADDON。
-- AceComm 的分框：第一個位元組 \001～\003 是多段訊息（只會是冷卻／裝備之類的大包，
-- 鑰石不會分段，略過）；\004 是跳脫——內容本身剛好以 \001～\009 開頭時補在前面。
------------------------------------------------------------
local _, ns = ...

local Sec = ns.Secret
local LibDeflate = LibStub and LibStub("LibDeflate", true)

local PREFIX = "LRS"

local ORK = {}
ns.OpenRaidKeystone = ORK

-- [名字] = { level, challengeMapID, rating }；名字格式同 GetUnitName(unit, true)
local data = {}
local onUpdate

function ORK.SetOnUpdate(fn) onUpdate = fn end

function ORK.GetKeystoneInfo(unit)
    local name = Sec.PlainText(GetUnitName(unit, true))
    return name and data[name]
end

-- 請求本身也要照協定壓縮編碼，對方的 LibOpenRaid 才解得開
local requestPayload
local function RequestPayload()
    if not requestPayload and LibDeflate then
        local p = LibDeflate:EncodeForWoWAddonChannel(LibDeflate:CompressDeflate("J", { level = 9 }))
        -- 對方的 AceComm 會把 \001～\009 開頭當控制字元，照它的規則補跳脫
        local b = p:byte(1)
        if b and b >= 1 and b <= 9 then p = "\004" .. p end
        requestPayload = p
    end
    return requestPayload
end

-- 跟原版一樣戰鬥中不發；12.1 首領戰／M+ 的通訊封鎖由 SendAddonMessage 自己擋，pcall 接住
local function Send(channel)
    local payload = RequestPayload()
    if not payload or InCombatLockdown() then return end
    pcall(C_ChatInfo.SendAddonMessage, PREFIX, payload, channel)
end

function ORK.RequestFromParty()
    if IsInGroup() and not IsInRaid() then
        Send(IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or "PARTY")
    end
end

function ORK.RequestFromRaid()
    if IsInRaid() then
        Send(IsInRaid(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or "RAID")
    end
end

local function OnMessage(text, sender)
    text, sender = Sec.PlainText(text), Sec.PlainText(sender)
    if not (text and sender and LibDeflate) then return end
    local b = text:byte(1)
    if not b then return end
    if b == 4 then
        text = text:sub(2)                   -- AceComm 的跳脫
    elseif b <= 9 then
        return                               -- 多段訊息，或 AceComm 不認得的控制字元
    end

    sender = Ambiguate(sender, "none")
    if sender == UnitName("player") then return end

    local decoded = LibDeflate:DecodeForWoWAddonChannel(text)
    local plain = decoded and LibDeflate:DecompressDeflate(decoded)
    if type(plain) ~= "string" or plain:sub(1, 2) ~= "K," then return end

    local _, level, _, challengeMapID, _, rating = strsplit(",", plain)
    level, challengeMapID = tonumber(level), tonumber(challengeMapID)
    if not (level and challengeMapID) then return end

    data[sender] = { level = level, challengeMapID = challengeMapID, rating = tonumber(rating) or 0 }
    if onUpdate then onUpdate() end
end

C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent", function(_, _, prefix, text, _, sender)
    if Sec.PlainText(prefix) ~= PREFIX then return end
    ns.Guard(OnMessage, text, sender)
end)
