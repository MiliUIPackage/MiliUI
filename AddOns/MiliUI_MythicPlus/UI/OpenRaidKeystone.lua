------------------------------------------------------------
-- 隊友鑰石廣播的精簡接收端（三種協定）
--
-- 原本內嵌整包 LibOpenRaid（880 KB，連同 AceComm／AceSerializer／CallbackHandler），
-- 但我們只用它一件事：聽 Details!／Plater 等插件的使用者廣播的鑰石。那包另外還
-- 常駐一支 0.05 秒的發送排程、每次 BAG_UPDATE 排計時器、追蹤冷卻與裝備。
-- 這裡只實作各協定裡「鑰石」那一種訊息，其餘全部不碰：
--
--   "LRS"  LibOpenRaid（Details!／Plater）
--          內容 = LibDeflate:EncodeForWoWAddonChannel(CompressDeflate(明文))
--          明文 "J"                                  → 請求：「把你的鑰石發過來」
--          明文 "K,等級,mapID,challengeMapID,classID,分數,mythicPlusMapID,specID" → 鑰石資料
--          出處：LibOpenRaid.lua 的 ~comms 與 ~keystones 兩段（CONST_LIB_VERSION 177）
--   "PITB" Details! 自己的玩家資訊廣播（只收）
--          內容 = Base64(Deflate(明文))，用原生 C_EncodingUtil 解
--          明文是一段「K…」或「F#段#段…」；K 段 = "K長度,等級,mapID,challengeMapID,classID,分數,…"
--   "EQKS" EnhanceQoL（只收）
--          內容 = LibDeflate 編碼＋壓縮，明文 "K,challengeMapID,等級"
--   後兩種的格式取自 AdvancedMythicTracker 的 Core/Comms.lua，本機沒有原插件可對照，
--   解不開就安靜略過（隊友的 LibKeystone 那條照常會回）。
--
-- 只收不回：別人發 "J" 時我們不回自己的鑰石；我們只發 LRS 的請求。
--
-- 對方送出時都走 AceComm：第一個位元組 \001／\002／\003 是多段訊息的頭／中／尾，
-- \004 是跳脫——內容本身剛好以 \001～\009 開頭時補在前面。多段的照 AceComm 規則接起來
-- （PITB 的「F#」整包可能超過一則的長度）。
-- 只收隊伍／團隊／副本頻道的；公會廣播用不到。
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

local function Store(sender, level, challengeMapID, rating)
    level, challengeMapID = tonumber(level), tonumber(challengeMapID)
    if not (level and challengeMapID) then return end
    data[sender] = { level = level, challengeMapID = challengeMapID, rating = tonumber(rating) or 0 }
    if onUpdate then onUpdate() end
end

local function Inflate(text)
    local decoded = LibDeflate:DecodeForWoWAddonChannel(text)
    return decoded and LibDeflate:DecompressDeflate(decoded)
end

local function ParseLRS(text, sender)
    local plain = Inflate(text)
    if type(plain) ~= "string" or plain:sub(1, 2) ~= "K," then return end
    local _, level, _, challengeMapID, _, rating = strsplit(",", plain)
    Store(sender, level, challengeMapID, rating)
end

local function ParseEQKS(text, sender)
    local plain = Inflate(text)
    if type(plain) ~= "string" then return end
    local kind, challengeMapID, level, extra = strsplit(",", plain)
    if kind == "K" and not extra then Store(sender, level, challengeMapID) end
end

local function ParsePITB(text, sender)
    if not (C_EncodingUtil and C_EncodingUtil.DecodeBase64 and C_EncodingUtil.DecompressString) then return end
    local ok, compressed = pcall(C_EncodingUtil.DecodeBase64, text)
    if not ok or type(compressed) ~= "string" then return end
    local ok2, plain = pcall(C_EncodingUtil.DecompressString, compressed, Enum.CompressionMethod.Deflate)
    if not ok2 or type(plain) ~= "string" then return end
    if plain:sub(1, 2) == "F#" then plain = plain:sub(3) end
    for section in plain:gmatch("[^#]+") do
        if section:sub(1, 1) == "K" then
            -- 段頭 "K" 後面第一欄是這串的長度，不是資料
            local _, level, _, challengeMapID, _, rating = strsplit(",", section:sub(2))
            Store(sender, level, challengeMapID, rating)
            return
        end
    end
end

local PARSERS = { [PREFIX] = ParseLRS, PITB = ParsePITB, EQKS = ParseEQKS }
local GROUP_CHANNELS = { PARTY = true, RAID = true, INSTANCE_CHAT = true }

-- AceComm 多段訊息的暫存：[前綴\t頻道\t寄件者] = { 片段… }
local spool = {}

local function OnMessage(prefix, text, channel, sender)
    local parse = PARSERS[prefix]
    if not (parse and GROUP_CHANNELS[channel] and LibDeflate) then return end
    sender = Ambiguate(sender, "none")
    if sender == UnitName("player") then return end

    local b = text:byte(1)
    if not b then return end
    if b >= 1 and b <= 3 then
        local key = prefix .. "\t" .. channel .. "\t" .. sender
        local body = text:sub(2)
        if b == 1 then
            spool[key] = { body }
        elseif spool[key] then
            local parts = spool[key]
            parts[#parts + 1] = body
            if b ~= 3 then return end
            spool[key] = nil
            text = table.concat(parts)
            b = nil
        end
        if b then return end
    elseif b == 4 then
        text = text:sub(2)                   -- AceComm 的跳脫
    elseif b <= 9 then
        return                               -- AceComm 不認得的控制字元
    end

    parse(text, sender)
end

for prefix in pairs(PARSERS) do C_ChatInfo.RegisterAddonMessagePrefix(prefix) end

local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent", function(_, _, prefix, text, channel, sender)
    prefix = Sec.PlainText(prefix)
    if not (prefix and PARSERS[prefix]) then return end
    text, channel, sender = Sec.PlainText(text), Sec.PlainText(channel), Sec.PlainText(sender)
    if not (text and channel and sender) then return end
    ns.Guard(OnMessage, prefix, text, channel, sender)
end)
