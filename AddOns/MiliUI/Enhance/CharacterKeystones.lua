--------------------------------------------------------------------------------
-- CharacterKeystones
-- 記錄各角色當前鑰石（升級/降級/獲得時更新），在 KeystoneLoot addon 視窗左側顯示
-- 週重置後自動清除上週資料
-- 面板 parent 到 KeystoneLootFrame，跟隨其顯示/隱藏與拖曳
--------------------------------------------------------------------------------

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

local HEADER_COLOR = { 1, 0.84, 0, 1 }
local VALUE_COLOR  = { 0.90, 0.90, 0.90, 1 }
local SEVEN_DAYS   = 7 * 24 * 60 * 60

local function GetLastWeeklyReset()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local secs = C_DateAndTime.GetSecondsUntilWeeklyReset()
        if secs and secs > 0 then
            return (time() + secs) - SEVEN_DAYS
        end
    end
    return time() - SEVEN_DAYS  -- 後備：當作 7 天前
end

local function PruneOldRecords()
    local history = MiliUI_DB and MiliUI_DB.characterKeystones
    if not history then return end
    local cutoff = GetLastWeeklyReset()
    for key, data in pairs(history) do
        if not data.timestamp or data.timestamp < cutoff then
            history[key] = nil
        end
    end
end

local KEY_CHECK_DELAY    = 1
local KEY_CHECK_MAX_RETRY = 6
local BASELINE_DELAY     = 10

local KEYSTONE_NPC_IDS = {
    [197711] = true,
    [197915] = true,
}

local lastOwnMapID, lastOwnLevel = 0, 0
local baselineSet = false
local keyCheckTimer

--------------------------------------------------------------------------------
-- 資料層
--------------------------------------------------------------------------------
local function GetCharacterKey()
    return UnitName("player") .. "-" .. GetRealmName()
end

local function ReadOwnKeystoneState()
    local mapID, level = 0, 0
    if C_MythicPlus then
        if C_MythicPlus.GetOwnedKeystoneChallengeMapID then
            mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID() or 0
        end
        if C_MythicPlus.GetOwnedKeystoneLevel then
            level = C_MythicPlus.GetOwnedKeystoneLevel() or 0
        end
    end
    return mapID, level
end

local function SaveKeystoneRecord(mapID, level)
    if not MiliUI_DB then MiliUI_DB = {} end
    if not MiliUI_DB.characterKeystones then MiliUI_DB.characterKeystones = {} end

    local key = GetCharacterKey()
    local existing = MiliUI_DB.characterKeystones[key]
    if existing and existing.mapID == mapID and existing.level == level then
        return
    end

    local _, class = UnitClass("player")
    MiliUI_DB.characterKeystones[key] = {
        name  = UnitName("player"),
        realm = GetRealmName(),
        class = class,
        mapID = mapID,
        level = level,
        timestamp = time(),
    }
end

local function ScheduleKeystoneCheck(retry)
    if keyCheckTimer then return end
    keyCheckTimer = C_Timer.NewTimer(KEY_CHECK_DELAY, function()
        keyCheckTimer = nil
        if C_MythicPlus and C_MythicPlus.RequestRewards then
            C_MythicPlus.RequestRewards()
        end
        local mapID, level = ReadOwnKeystoneState()

        if not baselineSet then
            lastOwnMapID, lastOwnLevel = mapID, level
            baselineSet = true
            if mapID > 0 and level > 0 then
                SaveKeystoneRecord(mapID, level)
            end
            return
        end

        if mapID == lastOwnMapID and level == lastOwnLevel then
            if (retry or 0) < KEY_CHECK_MAX_RETRY then
                ScheduleKeystoneCheck((retry or 0) + 1)
            end
            return
        end
        lastOwnMapID, lastOwnLevel = mapID, level
        if mapID > 0 and level > 0 then
            SaveKeystoneRecord(mapID, level)
        end
    end)
end

local function IsKeystoneNpcGossip()
    local guid = UnitGUID("npc") or UnitGUID("target")
    if type(guid) ~= "string" then return false end
    local ok, part = pcall(function() return select(6, strsplit("-", guid)) end)
    if not ok then return false end
    local id = tonumber(part)
    return id ~= nil and KEYSTONE_NPC_IDS[id] == true
end

--------------------------------------------------------------------------------
-- 隊伍頻道輸出
--------------------------------------------------------------------------------
local function GetPartyChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    elseif IsInRaid() then
        return "RAID"
    elseif IsInGroup() then
        return "PARTY"
    end
end

--------------------------------------------------------------------------------
-- 自我關鍵字偵測：自己在隊伍頻道輸入關鍵字時，回報七天內所有分身鑰石
--------------------------------------------------------------------------------
local SELF_REPORT_KEYWORDS = { "分身鑰石", "分身key" }
local LINE_SPACING = 0.15

local CHAT_EVENT_TO_CHANNEL = {
    CHAT_MSG_PARTY                = "PARTY",
    CHAT_MSG_PARTY_LEADER         = "PARTY",
    CHAT_MSG_INSTANCE_CHAT        = "INSTANCE_CHAT",
    CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT",
}

local function MatchSelfKeyword(msg)
    if type(msg) ~= "string" or msg == "" then return false end
    for _, kw in ipairs(SELF_REPORT_KEYWORDS) do
        if msg:find(kw, 1, true) then return true end
    end
    return false
end

local function FormatAltReportLine(data)
    local className = data.class
        and (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[data.class])
        or nil
    local mapName = (C_ChallengeMode and C_ChallengeMode.GetMapUIInfo)
        and C_ChallengeMode.GetMapUIInfo(data.mapID) or "?"
    local prefix = className and ("[" .. className .. "] ") or ""
    return string.format("%s%s: %s (+%d)",
        prefix, data.name or "?", mapName, data.level or 0)
end

local function SendKeystoneReport(channel)
    if not channel then return end

    PruneOldRecords()
    local history = MiliUI_DB and MiliUI_DB.characterKeystones
    if not history then return end

    local entries = {}
    for _, data in pairs(history) do
        if (data.level or 0) > 0 then
            entries[#entries + 1] = data
        end
    end

    if #entries == 0 then return end
    table.sort(entries, function(a, b) return (a.timestamp or 0) > (b.timestamp or 0) end)

    for i, data in ipairs(entries) do
        local line = FormatAltReportLine(data)
        C_Timer.After((i - 1) * LINE_SPACING, function()
            SendChatMessage(line, channel)
        end)
    end
end

local function FormatKeystoneMessage(data)
    local name = data.name or "?"
    local classKey = data.class
    local className = classKey
        and (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classKey])
        or nil
    local mapName = (C_ChallengeMode and C_ChallengeMode.GetMapUIInfo)
        and C_ChallengeMode.GetMapUIInfo(data.mapID) or "?"
    local prefix = className and ("[" .. className .. "] ") or ""
    return prefix .. name .. " " .. mapName .. " +" .. (data.level or 0)
end

--------------------------------------------------------------------------------
-- UI
--------------------------------------------------------------------------------
local ROW_HEIGHT    = 28
local HEADER_HEIGHT = 28
local TABLE_TOP     = -40
local TABLE_LEFT    = 14
local PADDING_X     = 4

local COL_DEFS = {
    { label = "角色", width = 90,  align = "LEFT" },
    { label = "鑰石", width = 150, align = "CENTER" },
    { label = "日期", width = 50,  align = "CENTER" },
}

local rowPool = {}
local refreshCallback

local function ShowRowContextMenu(row)
    if not row.data or not row.key then return end
    local channel = GetPartyChannel()
    MenuUtil.CreateContextMenu(row, function(_, root)
        root:CreateTitle(row.data.name or row.key)
        root:CreateButton("刪除記錄", function()
            if MiliUI_DB and MiliUI_DB.characterKeystones then
                MiliUI_DB.characterKeystones[row.key] = nil
            end
            if refreshCallback then refreshCallback() end
        end)
        if channel then
            root:CreateButton("發到隊伍", function()
                local ch = GetPartyChannel()
                if ch then
                    SendChatMessage(FormatKeystoneMessage(row.data), ch)
                end
            end)
        end
    end)
end

local function GetOrCreateRow(parent, index)
    if rowPool[index] then return rowPool[index] end

    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:EnableMouse(true)

    row.altBg = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.altBg:SetColorTexture(0.10, 0.10, 0.14, 0.15)
    row.altBg:SetAllPoints()

    row.highlight = row:CreateTexture(nil, "BACKGROUND", nil, 2)
    row.highlight:SetColorTexture(1, 0.84, 0, 0.08)
    row.highlight:SetAllPoints()
    row.highlight:Hide()
    row:SetScript("OnEnter", function() row.highlight:Show() end)
    row:SetScript("OnLeave", function() row.highlight:Hide() end)
    row:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            -- 延後到下一個 frame 避免 MenuUtil 在 OnMouseUp 同呼叫鏈下造成 taint 傳播
            C_Timer.After(0, function() ShowRowContextMenu(self) end)
        end
    end)

    local xOff = 0
    row.fsName = row:CreateFontString(nil, "OVERLAY")
    row.fsName:SetFont(barFont, 12, "OUTLINE")
    row.fsName:SetPoint("LEFT", row, "LEFT", xOff, 0)
    row.fsName:SetWidth(COL_DEFS[1].width)
    row.fsName:SetJustifyH(COL_DEFS[1].align)
    xOff = xOff + COL_DEFS[1].width + PADDING_X

    row.fsKey = row:CreateFontString(nil, "OVERLAY")
    row.fsKey:SetFont(barFont, 12, "OUTLINE")
    row.fsKey:SetPoint("LEFT", row, "LEFT", xOff, 0)
    row.fsKey:SetWidth(COL_DEFS[2].width)
    row.fsKey:SetJustifyH(COL_DEFS[2].align)
    xOff = xOff + COL_DEFS[2].width + PADDING_X

    row.fsDate = row:CreateFontString(nil, "OVERLAY")
    row.fsDate:SetFont(barFont, 12, "OUTLINE")
    row.fsDate:SetPoint("LEFT", row, "LEFT", xOff, 0)
    row.fsDate:SetWidth(COL_DEFS[3].width)
    row.fsDate:SetJustifyH(COL_DEFS[3].align)

    rowPool[index] = row
    return row
end

local setupDone = false

local function SetupCharacterKeystones()
    if setupDone then return end

    -- 需要 KeystoneLoot addon 的主視窗做為錨點與父框
    local lootFrame = _G["KeystoneLootFrame"]
    if not lootFrame then return end

    setupDone = true

    ---------------------------------------------------------------------------
    -- 主面板：parented to KeystoneLootFrame
    ---------------------------------------------------------------------------
    local panel = CreateFrame("Frame", "MiliUI_CharacterKeystonesPanel", lootFrame, "BackdropTemplate")
    panel:SetSize(330, 200)
    panel:SetPoint("TOPRIGHT", lootFrame, "TOPLEFT", -8, 0)
    panel:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(0.06, 0.06, 0.10, 0.92)
    panel:SetBackdropBorderColor(0.6, 0.5, 0.25, 0.8)

    local title = panel:CreateFontString(nil, "OVERLAY")
    title:SetFont(barFont, 14, "OUTLINE")
    title:SetPoint("TOP", panel, "TOP", 0, -14)
    title:SetTextColor(unpack(HEADER_COLOR))
    title:SetText("角色鑰石記錄")

    -- 「全部發送」按鈕（在隊伍時才顯示）
    local sendAllBtn = CreateFrame("Button", nil, panel, "BackdropTemplate")
    sendAllBtn:SetSize(70, 20)
    sendAllBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -10)
    sendAllBtn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    sendAllBtn:SetBackdropColor(0.15, 0.15, 0.22, 0.9)
    sendAllBtn:SetBackdropBorderColor(0.6, 0.5, 0.25, 0.8)
    local sendAllText = sendAllBtn:CreateFontString(nil, "OVERLAY")
    sendAllText:SetFont(barFont, 11, "OUTLINE")
    sendAllText:SetPoint("CENTER", 0, 0)
    sendAllText:SetTextColor(1, 0.84, 0, 1)
    sendAllText:SetText("全部發送")

    sendAllBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.25, 0.25, 0.35, 1)
        self:SetBackdropBorderColor(0.8, 0.7, 0.3, 1)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("全部發送", 1, 0.84, 0)
        GameTooltip:AddLine("發送所有角色鑰石列表到隊伍頻道", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    sendAllBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.15, 0.15, 0.22, 0.9)
        self:SetBackdropBorderColor(0.6, 0.5, 0.25, 0.8)
        GameTooltip:Hide()
    end)
    sendAllBtn:SetScript("OnClick", function()
        local ch = GetPartyChannel()
        if ch then SendKeystoneReport(ch) end
    end)

    local function UpdateSendAllVisibility()
        sendAllBtn:SetShown(IsInGroup())
    end
    UpdateSendAllVisibility()
    sendAllBtn:RegisterEvent("GROUP_ROSTER_UPDATE")
    sendAllBtn:SetScript("OnEvent", UpdateSendAllVisibility)

    -- 表頭
    local xOffset = TABLE_LEFT
    for _, col in ipairs(COL_DEFS) do
        local fs = panel:CreateFontString(nil, "OVERLAY")
        fs:SetFont(barFont, 12, "OUTLINE")
        fs:SetPoint("TOPLEFT", panel, "TOPLEFT", xOffset, TABLE_TOP)
        fs:SetWidth(col.width)
        fs:SetJustifyH(col.align)
        fs:SetTextColor(unpack(HEADER_COLOR))
        fs:SetText(col.label)
        xOffset = xOffset + col.width + PADDING_X
    end

    local headerLine = panel:CreateTexture(nil, "ARTWORK")
    headerLine:SetColorTexture(0.6, 0.5, 0.25, 0.6)
    headerLine:SetHeight(1)
    headerLine:SetPoint("TOPLEFT", panel, "TOPLEFT", TABLE_LEFT - 4, TABLE_TOP - HEADER_HEIGHT + 2)
    headerLine:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -TABLE_LEFT + 4, TABLE_TOP - HEADER_HEIGHT + 2)

    local noDataText = panel:CreateFontString(nil, "OVERLAY")
    noDataText:SetFont(barFont, 12, "OUTLINE")
    noDataText:SetPoint("TOP", panel, "TOP", 0, TABLE_TOP - HEADER_HEIGHT - 20)
    noDataText:SetTextColor(0.5, 0.5, 0.5)
    noDataText:SetText("尚無鑰石記錄")
    noDataText:Hide()

    local rowStartY = TABLE_TOP - HEADER_HEIGHT - 8
    local sorted = {}
    local function sortByTimestamp(a, b)
        return (a.data.timestamp or 0) > (b.data.timestamp or 0)
    end

    local function PopulateList()
        PruneOldRecords()
        local history = MiliUI_DB and MiliUI_DB.characterKeystones
        if not history or not next(history) then
            noDataText:Show()
            for i = 1, #rowPool do rowPool[i]:Hide() end
            panel:SetHeight((-TABLE_TOP) + HEADER_HEIGHT + 50)
            return
        end
        noDataText:Hide()

        for i = #sorted, 1, -1 do sorted[i] = nil end
        for key, data in pairs(history) do
            sorted[#sorted + 1] = { key = key, data = data }
        end
        table.sort(sorted, sortByTimestamp)

        for idx, entry in ipairs(sorted) do
            local data = entry.data

            local row = GetOrCreateRow(panel, idx)
            local yPos = rowStartY - (idx - 1) * ROW_HEIGHT
            row:SetPoint("TOPLEFT", panel, "TOPLEFT", TABLE_LEFT, yPos)
            row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -TABLE_LEFT, yPos)
            row.key = entry.key
            row.data = data
            row:Show()

            row.altBg:SetShown(idx % 2 == 0)

            local classColor = RAID_CLASS_COLORS[data.class]
            if classColor then
                row.fsName:SetTextColor(classColor.r, classColor.g, classColor.b)
            else
                row.fsName:SetTextColor(unpack(VALUE_COLOR))
            end
            row.fsName:SetText(data.name or entry.key)

            local mapName = (C_ChallengeMode and C_ChallengeMode.GetMapUIInfo)
                and C_ChallengeMode.GetMapUIInfo(data.mapID) or "?"
            row.fsKey:SetTextColor(unpack(VALUE_COLOR))
            row.fsKey:SetText(mapName .. " +" .. (data.level or 0))

            row.fsDate:SetTextColor(unpack(VALUE_COLOR))
            row.fsDate:SetText(date("%m/%d", data.timestamp or 0))
        end

        for i = #sorted + 1, #rowPool do
            rowPool[i]:Hide()
        end

        local numRows = #sorted
        panel:SetHeight((-TABLE_TOP) + HEADER_HEIGHT + 6 + (numRows * ROW_HEIGHT) + 24)
    end

    refreshCallback = PopulateList

    -- 每次顯示時填充（更新 stale 狀態）
    panel:HookScript("OnShow", PopulateList)
    if panel:IsVisible() then PopulateList() end
end

--------------------------------------------------------------------------------
-- 載入：UI 掛載 - 等 KeystoneLoot addon 載入
--------------------------------------------------------------------------------
local uiFrame = CreateFrame("Frame")
uiFrame:RegisterEvent("ADDON_LOADED")
uiFrame:RegisterEvent("PLAYER_LOGIN")
uiFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "KeystoneLoot" then
        SetupCharacterKeystones()
        if setupDone then self:UnregisterEvent("ADDON_LOADED") end
    elseif event == "PLAYER_LOGIN" then
        -- 後備：若 KeystoneLoot 已載入則直接設定；
        -- 若到此仍未載入（被停用），主動解除 ADDON_LOADED 避免持續監聽
        if not setupDone and C_AddOns.IsAddOnLoaded("KeystoneLoot") then
            SetupCharacterKeystones()
        end
        self:UnregisterEvent("ADDON_LOADED")
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

if C_AddOns.IsAddOnLoaded("KeystoneLoot") then
    SetupCharacterKeystones()
    if setupDone then uiFrame:UnregisterEvent("ADDON_LOADED") end
end

--------------------------------------------------------------------------------
-- 載入：資料追蹤
--------------------------------------------------------------------------------
local dataFrame = CreateFrame("Frame")
dataFrame:RegisterEvent("PLAYER_LOGIN")
dataFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        self:RegisterEvent("CHALLENGE_MODE_COMPLETED")
        self:RegisterEvent("GOSSIP_CLOSED")
        self:RegisterEvent("CHAT_MSG_PARTY")
        self:RegisterEvent("CHAT_MSG_PARTY_LEADER")
        self:RegisterEvent("CHAT_MSG_INSTANCE_CHAT")
        self:RegisterEvent("CHAT_MSG_INSTANCE_CHAT_LEADER")
        -- 一次性遷移舊資料：keystoneHistory → characterKeystones
        if MiliUI_DB and MiliUI_DB.keystoneHistory and not MiliUI_DB.characterKeystones then
            MiliUI_DB.characterKeystones = MiliUI_DB.keystoneHistory
            MiliUI_DB.keystoneHistory = nil
        end
        PruneOldRecords()
        C_Timer.After(BASELINE_DELAY, function()
            if not baselineSet then
                local mapID, level = ReadOwnKeystoneState()
                lastOwnMapID, lastOwnLevel = mapID, level
                baselineSet = true
                if mapID > 0 and level > 0 then
                    SaveKeystoneRecord(mapID, level)
                end
            end
        end)
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        ScheduleKeystoneCheck(0)
    elseif event == "GOSSIP_CLOSED" then
        if IsKeystoneNpcGossip() then
            ScheduleKeystoneCheck(0)
        end
    elseif CHAT_EVENT_TO_CHANNEL[event] then
        local text, sender = ...
        if sender and sender ~= "" then
            local senderShort = sender:match("^([^-]+)") or sender
            if senderShort == UnitName("player") and MatchSelfKeyword(text) then
                SendKeystoneReport(CHAT_EVENT_TO_CHANNEL[event])
            end
        end
    end
end)
