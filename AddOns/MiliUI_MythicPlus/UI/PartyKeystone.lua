------------------------------------------------------------
-- 隊伍鑰石：傳奇鑰石頁（ChallengesFrame）右下角的隊友鑰石清單 ＋ 一鍵發到隊伍
-- ＋ 隊友在隊伍頻道打 key／鑰石 時回報全隊鑰石
--
-- 2026-09-24 從 MiliUI 本體的 Enhance/PartyKeystone.lua 搬過來。
-- 同步來源、推舉去重、通訊封鎖閘都照原樣；外觀改走 MiliUIWidgets（設定視窗皮），
-- 文字改走語系檔。設定：面板在「鑰石」分頁、打字回報在「聊天」分頁。
--
-- 同步來源（與 ElvUI_WindTools 同款，雙來源互補）：
--   1. LibOpenRaid 協定（主）—— Details!／Plater 等的使用者會廣播。只用得到收鑰石，
--      所以不內嵌整包函式庫，改用 UI/OpenRaidKeystone.lua 的精簡接收端（只收不回）。
--   2. LibKeystone （備）—— DBM／BigWigs 那套 PARTY／GUILD 請求協議，內嵌在 Libs/。
--
-- ⚠ 面板是 ChallengesFrame 的孩子（跟著它顯示／隱藏）。只建子框、不寫暴雪框的欄位。
------------------------------------------------------------
local _, ns = ...

ns.PartyKeystone = {}
local PK = ns.PartyKeystone

local L = ns.L
local S = ns.Style
local Sec = ns.Secret

local LibStub = _G.LibStub
local OR = ns.OpenRaidKeystone
local KS = LibStub and LibStub("LibKeystone", true)

local MAX_ROWS   = 5
local ROW_HEIGHT = 18
local PANEL_W    = 240
local PAD        = 10
local HEAD_H     = 32

-- 打字 key／鑰石 → 彙報全隊
local DEDUP_PREFIX   = "MiliUIKey"  -- 裝了 MiliUI 的隊友之間推舉發報者，避免重複貼（跟本體舊版同一個前綴）
local CLAIM_WINDOW   = 1.8          -- 等資料回來 ＋ 收集 CLAIM 的窗口
local REPLY_COOLDOWN = 30           -- 送出彙報後的冷卻秒數
local LINE_SPACING   = 0.15         -- 每行延遲，避免伺服器節流
local TRIGGER_KEYWORDS = { ["key"] = true, ["keys"] = true, ["!key"] = true, ["!keys"] = true, ["鑰石"] = true, ["钥石"] = true }

local panel
local Refresh, QueueRefresh

local function Cfg() return ns.db and ns.db.keystone end
local function AnnounceCfg() return ns.db and ns.db.announce end

------------------------------------------------------------
-- 資料層
------------------------------------------------------------
-- LibKeystone callback 收到的隊友資料；key 統一用 Ambiguate(name, "short")
local libKeystoneInfo = {}

if KS and KS.Register then
    local ksOwner = {}  -- LibKeystone 要求傳入「自己的」物件以辨識註冊者
    KS.Register(ksOwner, function(keyLevel, keyChallengeMapID, playerRating, sender)
        sender = Sec.PlainText(sender)
        if not sender then return end
        libKeystoneInfo[Ambiguate(sender, "short")] = {
            level = Sec.PlainNumber(keyLevel),
            challengeMapID = Sec.PlainNumber(keyChallengeMapID),
            rating = Sec.PlainNumber(playerRating),
        }
        if QueueRefresh then QueueRefresh() end
    end)
end

OR.SetOnUpdate(function()
    if QueueRefresh then QueueRefresh() end
end)

local function GetOwnKeystone()
    local mapID = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneChallengeMapID
        and C_MythicPlus.GetOwnedKeystoneChallengeMapID() or 0
    local level = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLevel
        and C_MythicPlus.GetOwnedKeystoneLevel() or 0
    mapID, level = Sec.PlainNumber(mapID) or 0, Sec.PlainNumber(level) or 0
    if mapID > 0 and level > 0 then
        return { level = level, challengeMapID = mapID }
    end
end

local function Valid(data)
    return data and (tonumber(data.level) or 0) > 0 and (tonumber(data.challengeMapID) or 0) > 0
end

-- 某個 unit 的鑰石：{ level, challengeMapID } 或 nil
local function GetUnitKeystone(unit)
    if not unit then return end
    if unit == "player" then return GetOwnKeystone() end
    if not UnitExists(unit) or not UnitIsPlayer(unit) then return end

    local data = OR.GetKeystoneInfo(unit)
    if not Valid(data) then
        local name = Sec.PlainText(GetUnitName(unit, true))
        local fb = name and libKeystoneInfo[Ambiguate(name, "short")]
        if fb then data = fb end
    end
    if Valid(data) then return data end
end

-- 向隊伍請求鑰石資料
local function RequestData()
    OR.RequestFromParty()
    OR.RequestFromRaid()
    -- LibKeystone 只認 PARTY／GUILD（副本內走 LibOpenRaid 協定，所以只在一般隊伍請求）
    if KS and KS.Request and IsInGroup(LE_PARTY_CATEGORY_HOME) then
        KS.Request("PARTY")
    end
end

-- player ＋ party1～4 中持有鑰石者：{ { unit =, data = }, ... }
local function CollectEntries()
    local entries = {}
    for i = 1, MAX_ROWS do
        local unit = (i == 1) and "player" or ("party" .. (i - 1))
        if unit == "player" or UnitExists(unit) then
            local data = GetUnitKeystone(unit)
            if data then entries[#entries + 1] = { unit = unit, data = data } end
        end
    end
    return entries
end

local function MapName(mapID)
    return Sec.PlainText((C_ChallengeMode.GetMapUIInfo(mapID))) or "?"
end

-- 聊天彙報：「玩家: 副本名 (+層數)」
local function EntriesToMessages(entries)
    local messages = {}
    for _, e in ipairs(entries) do
        local who = Sec.PlainText(UnitName(e.unit)) or "?"
        messages[#messages + 1] = string.format("%s: %s (+%d)", who, MapName(e.data.challengeMapID), e.data.level)
    end
    return messages
end

------------------------------------------------------------
-- 顯示輔助
------------------------------------------------------------
local function ColorName(unit)
    local name = Sec.PlainText(UnitName(unit)) or "?"
    local _, classFile = UnitClass(unit)
    local r, g, b = S.ClassColor(Sec.PlainText(classFile))
    if r then return S.Hex(r, g, b) .. name .. "|r" end
    return name
end

-- 層數上稀有度色（暴雪自己的配色）
local function ColorLevel(level)
    local str = "+" .. level
    if C_ChallengeMode and C_ChallengeMode.GetKeystoneLevelRarityColor then
        local c = C_ChallengeMode.GetKeystoneLevelRarityColor(level)
        if c and c.WrapTextInColorCode then return c:WrapTextInColorCode(str) end
    end
    return str
end

local function SendLines(lines, channel)
    for i, msg in ipairs(lines) do
        C_Timer.After((i - 1) * LINE_SPACING, function()
            SendChatMessage(msg, channel)
        end)
    end
end

------------------------------------------------------------
-- 面板
------------------------------------------------------------
local function BuildPanel()
    if panel then return panel end
    local parent = _G.ChallengesFrame
    if not parent then return end
    local W = ns.W

    panel = W.CreateFrame(nil, parent, PANEL_W, HEAD_H + ROW_HEIGHT + PAD)
    panel:SetBackdropColor(0.1, 0.1, 0.1, 1)
    panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 85)
    panel:SetFrameLevel(parent:GetFrameLevel() + 20)

    local title = S.NewText(panel, 13, S.TEXT)
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -PAD)
    title:SetText(L["Party keystones"])

    -- 「發送」是這一區的主動作；「更新」是次要
    local sendBtn = W.CreateButton(panel, L["Send"], "primary", 48, 20)
    sendBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -6)
    sendBtn:SetScript("OnClick", function()
        local channel = ns.PartyChannel()
        if not channel then return end
        local lines = panel.messages
        if not lines or #lines == 0 then return end
        SendLines(lines, channel)
    end)
    sendBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 3)
        GameTooltip:SetText(L["Post the party's keystones to party chat"], 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    sendBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
    panel.sendBtn = sendBtn

    local refreshBtn = W.CreateButton(panel, L["Refresh"], "normal", 48, 20)
    refreshBtn:SetPoint("RIGHT", sendBtn, "LEFT", -4, 0)
    refreshBtn:SetScript("OnClick", function()
        RequestData()
        Refresh()
    end)

    panel.rows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Frame", nil, panel)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -HEAD_H - (i - 1) * ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -HEAD_H - (i - 1) * ROW_HEIGHT)
        row.left = S.NewText(row, 12, S.TEXT)
        row.left:SetPoint("LEFT")
        row.right = S.NewText(row, 12, S.TEXT, "RIGHT")
        row.right:SetPoint("RIGHT")
        panel.rows[i] = row
    end
    return panel
end

Refresh = function()
    if not panel then return end
    local entries = CollectEntries()

    for i = 1, MAX_ROWS do
        local row, e = panel.rows[i], entries[i]
        if e then
            local name, _, _, texture = C_ChallengeMode.GetMapUIInfo(e.data.challengeMapID)
            name = Sec.PlainText(name) or "?"
            local icon = texture and ("|T" .. texture .. ":14:14:0:0|t ") or ""
            row.left:SetText(icon .. ColorLevel(e.data.level) .. " " .. name)
            row.right:SetText(ColorName(e.unit))
            row:Show()
        else
            row.left:SetText("")
            row.right:SetText("")
            row:Hide()
        end
    end

    local messages = EntriesToMessages(entries)
    panel.messages = messages
    panel.sendBtn:SetEnabled(#messages > 0 and IsInGroup())

    local n = #entries
    if n == 0 then
        local row = panel.rows[1]
        row.left:SetText(S.Hex(unpack(S.TEXT_DIM)) .. L["No keystone data yet…"] .. "|r")
        row.right:SetText("")
        row:Show()
        n = 1
    end
    panel:SetHeight(HEAD_H + n * ROW_HEIGHT + PAD)
end

-- 函式庫 callback 觸發的刷新：只在面板看得到時做，並節流合併連續事件
local refreshQueued = false
QueueRefresh = function()
    if not panel or not panel:IsVisible() then return end
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0.2, function()
        refreshQueued = false
        if panel and panel:IsVisible() then Refresh() end
    end)
end

local function Enabled()
    local c = Cfg()
    return c and c.partyPanel and true or false
end

local function OnChallengesShow()
    if not Enabled() then
        if panel then panel:Hide() end
        return
    end
    BuildPanel()
    if not panel then return end
    panel:Show()
    RequestData()
    Refresh()
    -- 資料常常晚一點才回來，再刷一次
    C_Timer.After(1, function() ns.Guard(Refresh) end)
end

local hooked = false
local function Hook()
    local cf = _G.ChallengesFrame
    if hooked or not cf then return end
    hooked = true
    cf:HookScript("OnShow", function() ns.Guard(OnChallengesShow) end)
    if cf:IsShown() then OnChallengesShow() end
end

function PK.Apply()
    local cf = _G.ChallengesFrame
    if cf and cf:IsShown() then
        OnChallengesShow()
    elseif panel and not Enabled() then
        panel:Hide()
    end
end

------------------------------------------------------------
-- 打字 key／鑰石 → 彙報全隊鑰石
-- 多人裝 MiliUI 時用 CLAIM 推舉 GUID 最小者發報，避免重複洗版。
------------------------------------------------------------
local claims = {}
local scheduledSend
local lastReply = 0

local function MatchKeyword(msg)
    msg = Sec.PlainText(msg)
    if not msg then return false end
    local word = msg:match("^%s*(.-)%s*$")
    return (word and TRIGGER_KEYWORDS[word:lower()]) or false
end

local function SendSummary()
    local channel = ns.PartyChannel()
    if not channel then return end
    local messages = EntriesToMessages(CollectEntries())
    if #messages == 0 then return end
    lastReply = GetTime()
    if not ns.IsCommRestricted() then
        C_ChatInfo.SendAddonMessage(DEDUP_PREFIX, "SENT", channel)
    end
    SendLines(messages, channel)
end

local function OnTrigger()
    local a = AnnounceCfg()
    if not (a and a.keyReply) then return end
    if scheduledSend then return end
    -- ⚠⚠ 通訊被封鎖時**整個不參加**，不是「照發但沒有去重」：推舉（CLAIM／SENT）
    --   完全靠 addon message，被封鎖時每個裝了 MiliUI 的隊友都會以為自己贏了
    --   ⇒ 同一份彙報被貼 N 次。那比「不回應」糟很多，而且是靜默的。
    if ns.IsCommRestricted() then return end
    if GetTime() - lastReply < REPLY_COOLDOWN then return end
    local channel = ns.PartyChannel()
    if not channel then return end
    local me = Sec.PlainText(UnitGUID("player"))
    if not me then return end

    wipe(claims)
    claims[me] = true

    RequestData()
    C_ChatInfo.SendAddonMessage(DEDUP_PREFIX, "CLAIM:" .. me, channel)

    -- CLAIM_WINDOW 同時用來等資料回來 ＋ 收集其他 MiliUI 的 CLAIM
    scheduledSend = C_Timer.NewTimer(CLAIM_WINDOW, function()
        scheduledSend = nil
        local winner = me
        for id in pairs(claims) do
            if id < winner then winner = id end
        end
        if winner == me then ns.Guard(SendSummary) end
        wipe(claims)
    end)
end

local function OnPeerDedup(text)
    text = Sec.PlainText(text)
    if not text then return end
    if text == "SENT" then
        -- 已經有別的 MiliUI 發了，取消自己的排程
        if scheduledSend then
            scheduledSend:Cancel()
            scheduledSend = nil
        end
        lastReply = GetTime()
        wipe(claims)
        return
    end
    local id = text:match("^CLAIM:(.+)$")
    if id then claims[id] = true end
end

------------------------------------------------------------
-- 啟動
------------------------------------------------------------
function PK.Init()
    C_ChatInfo.RegisterAddonMessagePrefix(DEDUP_PREFIX)
    ns.OnChallengesUI(Hook)

    local f = CreateFrame("Frame")
    f:RegisterEvent("GROUP_ROSTER_UPDATE")
    f:RegisterEvent("CHAT_MSG_ADDON")
    f:RegisterEvent("CHAT_MSG_PARTY")
    f:RegisterEvent("CHAT_MSG_PARTY_LEADER")
    f:RegisterEvent("CHAT_MSG_INSTANCE_CHAT")
    f:RegisterEvent("CHAT_MSG_INSTANCE_CHAT_LEADER")
    f:SetScript("OnEvent", function(_, event, ...)
        if event == "GROUP_ROSTER_UPDATE" then
            if panel and panel:IsVisible() then
                RequestData()
                C_Timer.After(1, function() ns.Guard(Refresh) end)
            end
        elseif event == "CHAT_MSG_ADDON" then
            local prefix, text = ...
            if Sec.PlainText(prefix) == DEDUP_PREFIX then ns.Guard(OnPeerDedup, text) end
        else
            if MatchKeyword((...)) then ns.Guard(OnTrigger) end
        end
    end)
end
