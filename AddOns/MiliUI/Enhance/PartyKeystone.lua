--------------------------------------------------------------------------------
-- PartyKeystone
-- 在 M+ 鑰石頁面 (ChallengesFrame) 右下角顯示隊友鑰石，並提供一鍵發送到隊伍頻道。
--
-- 同步來源 (與 ElvUI_WindTools 同款，雙來源互補)：
--   1. LibOpenRaid (主) — Details!/Plater/WindTools 等會主動廣播，副本內外都可靠。
--   2. LibKeystone  (備) — DBM/BigWigs/AngryKeystones 那套 PARTY/GUILD 請求協議。
-- 兩個函式庫已內嵌於 MiliUI/Libs，靠 LibStub 去重，不依賴其他插件是否安裝。
--
-- 為什麼舊版看不到隊友 key：原本只手刻了 LibKeystone 式協議，且在副本內用
-- INSTANCE_CHAT 發請求 (真正的 LibKeystone 只認 PARTY/GUILD → 無人回應)，
-- 又完全不接 LibOpenRaid 的主動廣播 (副本內唯一可靠來源)。改用這兩個函式庫即解決。
--
-- 設計風格：深色半透明面板 + 金色邊框，與 Enhance/ChallengesUI_Buttons.lua 一致。
--------------------------------------------------------------------------------

local LibStub = _G.LibStub
local OR = LibStub and LibStub("LibOpenRaid-1.0", true)
local KS = LibStub and LibStub("LibKeystone", true)

-- Locale-aware font (對齊 ChallengesUI_Buttons)
local barFont
if LOCALE_koKR then
    barFont = "Fonts\\2002.TTF"
elseif LOCALE_zhCN then
    barFont = "Fonts\\ARKai_T.ttf"
elseif LOCALE_zhTW then
    barFont = "Fonts\\blei00d.TTF"
else
    barFont = "Fonts\\FRIZQT__.TTF"
end

local MAX_ROWS = 5
local ROW_HEIGHT = 17

-- 功能一（打字 key/鑰石 → 彙報全隊）相關
local DEDUP_PREFIX   = "MiliUIKey"  -- MiliUI 之間推舉發報者用，避免多人重複貼
local CLAIM_WINDOW   = 1.8          -- 等資料回來 + 收集 CLAIM 的窗口
local REPLY_COOLDOWN = 30           -- 送出彙報後的冷卻秒數
local LINE_SPACING   = 0.15         -- 每行延遲避免 server throttle
local TRIGGER_KEYWORDS = { ["key"]=true, ["keys"]=true, ["!key"]=true, ["!keys"]=true, ["鑰石"]=true }
local issecretvalue = _G.issecretvalue or function() return false end

local Refresh        -- forward declaration（面板實際刷新）
local QueueRefresh   -- forward declaration（節流 + 僅可見時刷新，供函式庫 callback 用）
local panel

--------------------------------------------------------------------------------
-- 資料層
--------------------------------------------------------------------------------
-- LibKeystone callback 收到的隊友資料；key 統一用 Ambiguate(name, "short")
local libKeystoneInfo = {}

if (KS and KS.Register) then
    local ksOwner = {}  -- LibKeystone 要求傳入「自己的」物件以辨識註冊者
    KS.Register(ksOwner, function(keyLevel, keyChallengeMapID, playerRating, sender)
        if (not sender) then return end
        libKeystoneInfo[Ambiguate(sender, "short")] = {
            level = keyLevel,
            challengeMapID = keyChallengeMapID,
            rating = playerRating,
        }
        if (QueueRefresh) then QueueRefresh() end
    end)
end

-- LibOpenRaid 收到新資料時刷新面板
if (OR and OR.RegisterCallback) then
    local orOwner = {
        KeystoneUpdate = function()
            if (QueueRefresh) then QueueRefresh() end
        end,
    }
    OR.RegisterCallback(orOwner, "KeystoneUpdate", "KeystoneUpdate")
end

local function GetOwnKeystone()
    local mapID = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneChallengeMapID
        and C_MythicPlus.GetOwnedKeystoneChallengeMapID() or 0
    local level = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLevel
        and C_MythicPlus.GetOwnedKeystoneLevel() or 0
    if (mapID and level and mapID > 0 and level > 0) then
        return { level = level, challengeMapID = mapID }
    end
end

-- 取得某 unit 的鑰石資料，回傳 { level, challengeMapID } 或 nil
local function GetUnitKeystone(unit)
    if (not unit) then return end
    if (UnitIsUnit(unit, "player")) then
        return GetOwnKeystone()
    end
    if (not UnitExists(unit) or not UnitIsPlayer(unit)) then return end

    -- 主來源：LibOpenRaid
    local data
    if (OR and OR.GetKeystoneInfo) then
        data = OR.GetKeystoneInfo(unit)
    end

    -- 備援：LibKeystone（主來源沒資料時）
    if (not data or not data.level or data.level == 0
        or not data.challengeMapID or data.challengeMapID == 0) then
        local name = GetUnitName(unit, true)
        local key = name and Ambiguate(name, "short")
        local fb = key and libKeystoneInfo[key]
        if (fb) then data = fb end
    end

    if (data and data.level and data.level > 0
        and data.challengeMapID and data.challengeMapID > 0) then
        return data
    end
end

-- 向隊伍 / 公會請求鑰石資料
local function RequestData()
    if (OR) then
        if (OR.RequestKeystoneDataFromParty) then OR.RequestKeystoneDataFromParty() end
        if (IsInRaid() and OR.RequestKeystoneDataFromRaid) then OR.RequestKeystoneDataFromRaid() end
    end
    -- LibKeystone 僅支援 PARTY/GUILD（副本內走 LibOpenRaid，故只在一般隊伍請求）
    if (KS and KS.Request and IsInGroup(LE_PARTY_CATEGORY_HOME)) then
        KS.Request("PARTY")
    end
end

-- 對外暴露，供其他模組取用可靠資料
_G.MiliUI_PartyKeystone = {
    GetUnit = GetUnitKeystone,
    Request = RequestData,
}

-- 蒐集隊員 (player + party1~4) 中持有鑰石者，回傳 { {unit=, data=}, ... }
local function CollectEntries()
    local entries = {}
    for i = 1, MAX_ROWS do
        local unit = (i == 1) and "player" or ("party" .. (i - 1))
        if (unit == "player" or UnitExists(unit)) then
            local data = GetUnitKeystone(unit)
            if (data) then
                entries[#entries + 1] = { unit = unit, data = data }
            end
        end
    end
    return entries
end

-- 轉成聊天彙報文字： "玩家: 副本名 (+層數)"
local function EntriesToMessages(entries)
    local messages = {}
    for _, e in ipairs(entries) do
        local name = C_ChallengeMode.GetMapUIInfo(e.data.challengeMapID) or "?"
        messages[#messages + 1] = string.format("%s: %s (+%d)", UnitName(e.unit), name, e.data.level)
    end
    return messages
end

--------------------------------------------------------------------------------
-- 顯示輔助
--------------------------------------------------------------------------------
local function ColorName(unit)
    local name = UnitName(unit) or "?"
    local _, classFile = UnitClass(unit)
    local color = classFile and C_ClassColor and C_ClassColor.GetClassColor
        and C_ClassColor.GetClassColor(classFile)
    if (not color and classFile and RAID_CLASS_COLORS) then
        color = RAID_CLASS_COLORS[classFile]
    end
    if (color and color.WrapTextInColorCode) then
        return color:WrapTextInColorCode(name)
    elseif (color) then
        return string.format("|cff%02x%02x%02x%s|r",
            (color.r or 1) * 255, (color.g or 1) * 255, (color.b or 1) * 255, name)
    end
    return name
end

local function ColorLevel(level)
    local str = "+" .. level
    if (C_ChallengeMode and C_ChallengeMode.GetKeystoneLevelRarityColor) then
        local c = C_ChallengeMode.GetKeystoneLevelRarityColor(level)
        if (c and c.WrapTextInColorCode) then
            return c:WrapTextInColorCode(str)
        end
    end
    return str
end

local function GetSendChannel()
    if (IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) then
        return "INSTANCE_CHAT"
    elseif (IsInGroup()) then
        return "PARTY"
    end
end

--------------------------------------------------------------------------------
-- UI 建立
--------------------------------------------------------------------------------
local function CreateStyledButton(parent, width, height)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(0.15, 0.15, 0.22, 1)
    btn:SetBackdropBorderColor(0.45, 0.40, 0.20, 1)
    local text = btn:CreateFontString(nil, "OVERLAY")
    text:SetFont(barFont, 12, "OUTLINE")
    text:SetPoint("CENTER")
    text:SetTextColor(1, 0.84, 0, 1)
    btn.label = text
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.25, 0.25, 0.35, 1)
        self:SetBackdropBorderColor(0.8, 0.7, 0.3, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.15, 0.15, 0.22, 1)
        self:SetBackdropBorderColor(0.45, 0.40, 0.20, 1)
    end)
    return btn
end

local function BuildPanel()
    if (panel) then return panel end
    local parent = _G.ChallengesFrame
    if (not parent) then return end

    panel = CreateFrame("Frame", "MiliUI_PartyKeystoneFrame", parent, "BackdropTemplate")
    panel:SetSize(230, 150)
    panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 85)
    panel:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(0.08, 0.08, 0.12, 0.9)
    panel:SetBackdropBorderColor(0.6, 0.5, 0.25, 0.8) -- 金色邊框

    local title = panel:CreateFontString(nil, "OVERLAY")
    title:SetFont(barFont, 12, "OUTLINE")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -8)
    title:SetTextColor(1, 0.84, 0, 1)
    title:SetText("隊伍鑰石")

    -- 發送按鈕
    local sendBtn = CreateStyledButton(panel, 48, 18)
    sendBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -6)
    sendBtn.label:SetText("發送")
    sendBtn:SetScript("OnClick", function()
        local channel = GetSendChannel()
        if (not channel) then
            print("|cffffe00a[MiliUI]|r 你不在隊伍中。")
            return
        end
        local lines = panel.messages
        if (not lines or #lines == 0) then return end
        for i, msg in ipairs(lines) do
            C_Timer.After((i - 1) * 0.15, function()
                SendChatMessage(msg, channel)
            end)
        end
    end)
    sendBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.25, 0.25, 0.35, 1)
        self:SetBackdropBorderColor(0.8, 0.7, 0.3, 1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 3)
        GameTooltip:AddLine("把隊伍鑰石送到隊伍頻道")
        GameTooltip:Show()
    end)
    sendBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.15, 0.15, 0.22, 1)
        self:SetBackdropBorderColor(0.45, 0.40, 0.20, 1)
        GameTooltip:Hide()
    end)
    panel.sendBtn = sendBtn

    -- 重新整理按鈕
    local refreshBtn = CreateStyledButton(panel, 48, 18)
    refreshBtn:SetPoint("RIGHT", sendBtn, "LEFT", -5, 0)
    refreshBtn.label:SetText("更新")
    refreshBtn:SetScript("OnClick", function()
        RequestData()
        if (Refresh) then Refresh() end
    end)
    panel.refreshBtn = refreshBtn

    -- 資料列
    panel.rows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Frame", nil, panel)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -28 - (i - 1) * ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -28 - (i - 1) * ROW_HEIGHT)

        local left = row:CreateFontString(nil, "OVERLAY")
        left:SetFont(barFont, 12, "OUTLINE")
        left:SetPoint("LEFT", row, "LEFT", 0, 0)
        left:SetJustifyH("LEFT")

        local right = row:CreateFontString(nil, "OVERLAY")
        right:SetFont(barFont, 12, "OUTLINE")
        right:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        right:SetJustifyH("RIGHT")

        row.left, row.right = left, right
        panel.rows[i] = row
    end

    return panel
end

--------------------------------------------------------------------------------
-- 刷新內容
--------------------------------------------------------------------------------
Refresh = function()
    if (not panel) then return end

    local entries = CollectEntries()

    for i = 1, MAX_ROWS do
        local row = panel.rows[i]
        local e = entries[i]
        if (e) then
            local name, _, _, texture = C_ChallengeMode.GetMapUIInfo(e.data.challengeMapID)
            name = name or "?"
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
    if (n == 0) then
        panel.rows[1].left:SetText("|cff999999尚無鑰石資料…|r")
        panel.rows[1].right:SetText("")
        panel.rows[1]:Show()
        n = 1
    end
    panel:SetHeight(28 + n * ROW_HEIGHT + 8)
end

-- 函式庫 callback 觸發的刷新：僅在面板實際可見時才做，並節流合併連續事件
-- (公會/團隊鑰石廣播可能很頻繁，避免在面板隱藏時做白工)。
local refreshQueued = false
QueueRefresh = function()
    if (not panel or not panel:IsVisible()) then return end
    if (refreshQueued) then return end
    refreshQueued = true
    C_Timer.After(0.2, function()
        refreshQueued = false
        if (panel and panel:IsVisible()) then
            Refresh()
        end
    end)
end

--------------------------------------------------------------------------------
-- 功能一：隊伍聊天打字 key / keys / !key / !keys / 鑰石 → 彙報全隊鑰石
-- 資料來自 LibOpenRaid + LibKeystone（與面板同源，可靠）。
-- 多人裝 MiliUI 時用 CLAIM 推舉 GUID 最小者發報，避免重複洗版。
--------------------------------------------------------------------------------
local claims = {}
local scheduledSend
local lastReply = 0

local function MatchKeyword(msg)
    if (issecretvalue(msg)) then return false end
    if (type(msg) ~= "string") then return false end
    local word = msg:match("^%s*(.-)%s*$")
    return (word and TRIGGER_KEYWORDS[word:lower()]) or false
end

local function SendSummary()
    local channel = GetSendChannel()
    if (not channel) then return end
    local messages = EntriesToMessages(CollectEntries())
    if (#messages == 0) then return end
    lastReply = GetTime()
    C_ChatInfo.SendAddonMessage(DEDUP_PREFIX, "SENT", channel)
    for i, line in ipairs(messages) do
        C_Timer.After((i - 1) * LINE_SPACING, function()
            SendChatMessage(line, channel)
        end)
    end
end

local function OnTrigger()
    if (scheduledSend) then return end
    if (GetTime() - lastReply < REPLY_COOLDOWN) then return end
    local channel = GetSendChannel()
    if (not channel) then return end
    local me = UnitGUID("player")
    if (not me) then return end

    wipe(claims)
    claims[me] = true

    RequestData()  -- 觸發 LibOpenRaid / LibKeystone 回傳隊友資料
    C_ChatInfo.SendAddonMessage(DEDUP_PREFIX, "CLAIM:" .. me, channel)

    -- CLAIM_WINDOW 同時用來等資料回來 + 收集其他 MiliUI 的 CLAIM
    scheduledSend = C_Timer.NewTimer(CLAIM_WINDOW, function()
        scheduledSend = nil
        local winner = me
        for id in pairs(claims) do
            if (id < winner) then winner = id end
        end
        if (winner == me) then
            SendSummary()
        end
        wipe(claims)
    end)
end

local function OnPeerDedup(text)
    if (issecretvalue(text)) then return end
    if (type(text) ~= "string") then return end
    if (text == "SENT") then
        -- 已有別的 MiliUI 發報，取消自己的排程
        if (scheduledSend) then
            scheduledSend:Cancel()
            scheduledSend = nil
        end
        lastReply = GetTime()
        wipe(claims)
        return
    end
    local id = text:match("^CLAIM:(.+)$")
    if (id) then
        claims[id] = true
    end
end

--------------------------------------------------------------------------------
-- 載入 / 事件
--------------------------------------------------------------------------------
local function Setup()
    if (not _G.ChallengesFrame) then return end
    BuildPanel()
    if (not panel) then return end
    if (not panel._hooked) then
        panel._hooked = true
        _G.ChallengesFrame:HookScript("OnShow", function()
            RequestData()
            Refresh()
            -- 資料可能稍晚才回來，延遲再刷新一次
            C_Timer.After(1, Refresh)
        end)
    end
    if (_G.ChallengesFrame:IsShown()) then
        RequestData()
        Refresh()
        C_Timer.After(1, Refresh)
    end
end

C_ChatInfo.RegisterAddonMessagePrefix(DEDUP_PREFIX)

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("GROUP_ROSTER_UPDATE")
loader:RegisterEvent("CHAT_MSG_ADDON")
loader:RegisterEvent("CHAT_MSG_PARTY")
loader:RegisterEvent("CHAT_MSG_PARTY_LEADER")
loader:RegisterEvent("CHAT_MSG_INSTANCE_CHAT")
loader:RegisterEvent("CHAT_MSG_INSTANCE_CHAT_LEADER")
loader:SetScript("OnEvent", function(self, event, ...)
    if (event == "ADDON_LOADED") then
        local arg1 = ...
        if (arg1 == "Blizzard_ChallengesUI") then
            Setup()
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif (event == "GROUP_ROSTER_UPDATE") then
        if (panel and panel:IsVisible()) then
            RequestData()
            C_Timer.After(1, Refresh)
        end
    elseif (event == "CHAT_MSG_ADDON") then
        local prefix, text = ...
        if (prefix == DEDUP_PREFIX) then
            OnPeerDedup(text)
        end
    else
        -- CHAT_MSG_PARTY / PARTY_LEADER / INSTANCE_CHAT / INSTANCE_CHAT_LEADER
        local msg = ...
        if (MatchKeyword(msg)) then
            OnTrigger()
        end
    end
end)

if (C_AddOns.IsAddOnLoaded("Blizzard_ChallengesUI")) then
    Setup()
    loader:UnregisterEvent("ADDON_LOADED")
end
