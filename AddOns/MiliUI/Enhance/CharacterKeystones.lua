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
            local resetTime = GetServerTime() + secs
            local lastReset = resetTime - SEVEN_DAYS
            if MiliUI_KeystoneDebug then
                print(string.format(
                    "|cff00ff00[Keystone]|r GetLastWeeklyReset: secsUntil=%d, nextReset=%s, lastReset=%s, serverNow=%s, localNow=%s",
                    secs,
                    date("%m/%d %H:%M", resetTime),
                    date("%m/%d %H:%M", lastReset),
                    date("%m/%d %H:%M", GetServerTime()),
                    date("%m/%d %H:%M", time())
                ))
            end
            return lastReset
        end
    end
    return GetServerTime() - SEVEN_DAYS
end

local function PruneOldRecords()
    local history = MiliUI_DB and MiliUI_DB.characterKeystones
    if not history then return end
    local cutoff = GetLastWeeklyReset()
    for key, data in pairs(history) do
        if not data.timestamp or data.timestamp < cutoff then
            if MiliUI_KeystoneDebug then
                print(string.format(
                    "|cff00ff00[Keystone]|r Prune: %s ts=%s cutoff=%s (差%ds)",
                    key,
                    data.timestamp and date("%m/%d %H:%M", data.timestamp) or "nil",
                    date("%m/%d %H:%M", cutoff),
                    (data.timestamp or 0) - cutoff
                ))
            end
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

-- 寶庫類型：Activities=M+, Raid=團本, RankedPvP=競技場, World=世界/深淵（與 PvP 互斥）
local VAULT_TYPES = {
    mplus = 1,
    raid  = 3,
    pvp   = 2,
    world = 6,
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
        if MiliUI_KeystoneDebug then
            print(string.format(
                "|cff00ff00[Keystone]|r Skip: %s 已存在相同記錄 map=%d lv=%d ts=%s",
                key, mapID, level,
                existing.timestamp and date("%m/%d %H:%M", existing.timestamp) or "nil"
            ))
        end
        return
    end

    local _, class = UnitClass("player")
    local now = GetServerTime()
    MiliUI_DB.characterKeystones[key] = {
        name  = UnitName("player"),
        realm = GetRealmName(),
        class = class,
        mapID = mapID,
        level = level,
        timestamp = now,
    }
    if MiliUI_KeystoneDebug then
        print(string.format(
            "|cff00ff00[Keystone]|r Save: %s map=%d lv=%d ts=%s",
            key, mapID, level, date("%m/%d %H:%M", now)
        ))
    end
end

--------------------------------------------------------------------------------
-- 寶庫資料層
--------------------------------------------------------------------------------
-- 本週寶庫最多計入的 M+ 場次（最高門檻＝8 場）
local MPLUS_MAX_RUNS = 8

-- 讀本週 M+ 場次，排序（level 降冪、同分 mapID 升冪），只取最高前 8 場
-- （寶庫最高門檻＝8 場，多的不影響獎勵，存清單長度即可當「X/8」用）
-- 參數 (false, true)：本週 + includeIncompleteRuns=true，與 Blizzard 寶庫 tooltip
-- (WeeklyRewardsActivityMixin:AddTopRunsToTooltip) 完全一致。
-- 注意：true 才會包含「超時但打完」(depleted) 的場次——這種場次算寶庫進度，
-- 用 false 會漏掉它們，導致清單場次數與寶庫格不符。
local function ReadOwnMythicRuns()
    if not (C_MythicPlus and C_MythicPlus.GetRunHistory) then return nil end
    local runs = C_MythicPlus.GetRunHistory(false, true)  -- 本週、含超時通關
    if not runs or #runs == 0 then return nil end
    table.sort(runs, function(a, b)
        if a.level == b.level then
            return (a.mapChallengeModeID or 0) < (b.mapChallengeModeID or 0)
        end
        return (a.level or 0) > (b.level or 0)
    end)
    local list = {}
    for i = 1, math.min(MPLUS_MAX_RUNS, #runs) do
        list[i] = { mapID = runs[i].mapChallengeModeID, level = runs[i].level or 0 }
    end
    return list
end

local function ReadOwnVaultSnapshot()
    if not C_WeeklyRewards or not C_WeeklyRewards.GetActivities then return nil end
    local snap = { timestamp = GetServerTime() }
    local anyData = false
    for trackName, enumVal in pairs(VAULT_TYPES) do
        local list = C_WeeklyRewards.GetActivities(enumVal)
        if list and #list > 0 then
            local slots = {}
            for i, info in ipairs(list) do
                slots[i] = {
                    threshold = info.threshold or 0,
                    progress  = info.progress or 0,
                    level     = info.level or 0,
                }
            end
            snap[trackName] = slots
            anyData = true
        end
    end
    -- 本週 M+ 場次清單（最高前 8 場，長度即「X/8」）
    local runs = ReadOwnMythicRuns()
    if runs then
        snap.mplusRuns = runs
        anyData = true
    end
    if not anyData then return nil end
    return snap
end

local function SaveVaultSnapshot()
    local snap = ReadOwnVaultSnapshot()
    if not snap then return end
    if not MiliUI_DB then MiliUI_DB = {} end
    if not MiliUI_DB.characterKeystones then MiliUI_DB.characterKeystones = {} end

    local key = GetCharacterKey()
    local rec = MiliUI_DB.characterKeystones[key]
    if not rec then
        -- 還沒有鑰石記錄但有寶庫進度（例如本週還沒拿過鑰石），建一筆空殼
        local _, class = UnitClass("player")
        rec = {
            name  = UnitName("player"),
            realm = GetRealmName(),
            class = class,
            mapID = 0,
            level = 0,
            timestamp = GetServerTime(),
        }
        MiliUI_DB.characterKeystones[key] = rec
    end
    rec.vault = snap

    if MiliUI_KeystoneDebug then
        local mp = snap.mplus
        local s = mp and string.format("M+ %d/%d/%d",
            (mp[1] and mp[1].level) or 0,
            (mp[2] and mp[2].level) or 0,
            (mp[3] and mp[3].level) or 0
        ) or "no M+"
        print(string.format("|cff00ff00[Keystone]|r Vault saved: %s @ %s",
            s, date("%m/%d %H:%M", snap.timestamp)))
    end
end

-- 事件 → 延遲讀寶庫 API，讓伺服器有時間把新資料推送過來；同窗內 dedupe 防 spam
local vaultRefreshTimer
local VAULT_REFRESH_DELAY = 3
local function ScheduleVaultRefresh(reason)
    if vaultRefreshTimer then
        if MiliUI_KeystoneDebug then
            print("|cff00ff00[Keystone]|r vault refresh queued (dedup), reason: " .. tostring(reason))
        end
        return
    end
    vaultRefreshTimer = C_Timer.NewTimer(VAULT_REFRESH_DELAY, function()
        vaultRefreshTimer = nil
        if MiliUI_KeystoneDebug then
            print("|cff00ff00[Keystone]|r vault refresh fire, reason: " .. tostring(reason))
        end
        SaveVaultSnapshot()
    end)
end

-- 團本難度（給 ENCOUNTER_END 過濾用）：14 普通, 15 英雄, 16 傳奇, 17 團搜
local RAID_DIFFICULTY_IDS = { [14] = true, [15] = true, [16] = true, [17] = true }

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
            SaveVaultSnapshot()
            return
        end

        if mapID == lastOwnMapID and level == lastOwnLevel then
            -- 鑰石沒變但寶庫可能有進度（剛跑完 M+）
            SaveVaultSnapshot()
            if (retry or 0) < KEY_CHECK_MAX_RETRY then
                ScheduleKeystoneCheck((retry or 0) + 1)
            end
            return
        end
        lastOwnMapID, lastOwnLevel = mapID, level
        if mapID > 0 and level > 0 then
            SaveKeystoneRecord(mapID, level)
        end
        SaveVaultSnapshot()
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

local function MatchSelfKeyword(msg)
    if type(msg) ~= "string" or msg == "" then return false end
    local lower = msg:lower()
    for _, kw in ipairs(SELF_REPORT_KEYWORDS) do
        if lower:find(kw, 1, true) then return true end
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
    { label = "角色",     width = 88,  align = "LEFT" },
    { label = "鑰石",     width = 132, align = "CENTER" },
    { label = "寶庫(M+)", width = 96,  align = "CENTER" },
    { label = "日期",     width = 50,  align = "CENTER" },
}

local VAULT_COL_INDEX  = 3
local DATE_COL_INDEX   = 4   -- 有 Syndicator 載入時會被調為 5
local SPARK_COL_INDEX  = nil -- 有 Syndicator 載入時會被設為 4
local PANEL_WIDTH      = 410 -- 有 Syndicator 載入時會加上虛無之核欄寬度

-- 星雲虛無之核（Midnight Season 1 賽季鍛造材料 currency）
local SPARK_CURRENCY_ID = 3418
local SPARK_COL_WIDTH   = 64  -- 「虛無之核」4 字寬度

-- 把 GetRealmName() 的結果規格化成 Syndicator 用的格式（移除空白、連字號、單引號）
local function NormalizeRealmName(realm)
    if not realm then return "" end
    return (realm:gsub("[%s%-']", ""))
end

-- 偵測 Syndicator 是否可用
local function HasSyndicator()
    return Syndicator and Syndicator.API and Syndicator.API.GetCurrencyInfo and true or false
end

-- 一次抓所有分身的虛無之核持有量；回傳 lookup table keyed by "Name-NormalizedRealm"
local function BuildSparkLookup()
    if not HasSyndicator() then return nil end
    local list = Syndicator.API.GetCurrencyInfo(SPARK_CURRENCY_ID, false, false)
    if not list then return nil end
    local map = {}
    for _, entry in ipairs(list) do
        local key = (entry.character or "") .. "-" .. (entry.realmNormalized or "")
        map[key] = entry.quantity or 0
    end
    return map
end

local rowPool = {}
local refreshCallback

--------------------------------------------------------------------------------
-- 寶庫 tooltip：顯示完整 3 軌道 + 快照時間
--------------------------------------------------------------------------------
local VAULT_TRACK_LABELS = {
    mplus = "M+",
    raid  = "團本",
    world = "世界",
    pvp   = "競技",
}

local LOCKED_CELL_R, LOCKED_CELL_G, LOCKED_CELL_B = 0.4, 0.4, 0.4
local UNLOCKED_PLAIN_R, UNLOCKED_PLAIN_G, UNLOCKED_PLAIN_B = 0.95, 0.95, 0.95

-- 對應寶庫物品稀有度：+10 以上=神話(傳說橘)，+2~+9=英雄(史詩紫)，+1=勇士(稀有藍)
local function VaultSlotQualityColor(level)
    if level >= 10 then
        local c = ITEM_QUALITY_COLORS[5] -- Legendary
        return c.r, c.g, c.b
    elseif level >= 2 then
        local c = ITEM_QUALITY_COLORS[4] -- Epic
        return c.r, c.g, c.b
    elseif level >= 1 then
        local c = ITEM_QUALITY_COLORS[3] -- Rare
        return c.r, c.g, c.b
    end
    return 0.4, 0.4, 0.4
end

-- 團本難度 ID → 顯示「難度名稱」+ 寶庫獎勵軌道對應的物品稀有度
-- DifficultyID: 14=普通, 15=英雄, 16=傳奇, 17=團搜
-- name 是難度名稱；quality 對應該難度給的寶庫軌道顏色（精兵/勇士/英雄/神話）
-- 軌道色參考 Enhance/TinyInspectRemake_TrackColors.lua 的 TRACK_COLORS
local RAID_DIFFICULTY_INFO = {
    [17] = { name = "團搜", quality = 2 }, -- 給精兵軌道 - 綠 (Uncommon)
    [14] = { name = "普通", quality = 3 }, -- 給勇士軌道 - 藍 (Rare)
    [15] = { name = "英雄", quality = 4 }, -- 給英雄軌道 - 紫 (Epic)
    [16] = { name = "傳奇", quality = 5 }, -- 給神話軌道 - 橘 (Legendary)
}

-- 解鎖格的顯示文字與顏色（依軌道與 level 決定）
-- 世界/競技軌道的 level 語義混亂（深淵 tier、世界任務、PvP 評分各自不同編碼），
-- 完成與否更實用，直接打勾就好
local function VaultCellDisplay(trackKey, slot)
    local level = slot.level
    if trackKey == "mplus" then
        local r, g, b = VaultSlotQualityColor(level)
        return "+" .. level, r, g, b
    end
    if trackKey == "raid" then
        local info = RAID_DIFFICULTY_INFO[level]
        if info then
            local q = ITEM_QUALITY_COLORS[info.quality]
            return info.name, q.r, q.g, q.b
        end
    end
    -- 用 Blizzard atlas 的勾勾圖示，避免繁中字型缺 ✓ 字符變豆腐
    return "|A:common-icon-checkmark:14:14|a", UNLOCKED_PLAIN_R, UNLOCKED_PLAIN_G, UNLOCKED_PLAIN_B
end

--------------------------------------------------------------------------------
-- 自製寶庫 tooltip：絕對定位 + 固定欄寬，避免不同寬度字元造成欄位錯位
-- 高度動態（依 M+ 場次清單行數），寬度固定
--------------------------------------------------------------------------------
local TT = {
    PAD           = 12,
    TITLE_H       = 22,
    ROW_H         = 18,
    SPACE         = 8,   -- 區塊間距
    RUNS_HEADER_H = 18,
    RUN_LINE_H    = 16,
    FOOTER_H      = 14,
    LABEL_W       = 44,
    CELL_W        = 50,
    ROW_COUNT     = 3,
    MAX_RUN_LINES = 8,   -- = MPLUS_MAX_RUNS
}
TT.WIDTH = TT.PAD * 2 + TT.LABEL_W + TT.CELL_W * 3

-- 把 M+ 場次格式化成一行：「+15  薩倫之淵」，等級依品質上色
local function FormatRunLine(run)
    local name = (C_ChallengeMode and C_ChallengeMode.GetMapUIInfo
        and C_ChallengeMode.GetMapUIInfo(run.mapID)) or "?"
    local r, g, b = VaultSlotQualityColor(run.level or 0)
    local hex = string.format("%02x%02x%02x",
        math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
    return string.format("|cff%s+%d|r  %s", hex, run.level or 0, name)
end

local vaultTooltip

local function CreateVaultTooltip()
    local f = CreateFrame("Frame", "MiliUI_VaultTooltip", UIParent, "BackdropTemplate")
    f:SetFrameStrata("TOOLTIP")
    -- 初始高度只是佔位，每次 ShowVaultTooltip 都會依內容重新 SetHeight
    f:SetSize(TT.WIDTH, TT.PAD * 2 + TT.TITLE_H + TT.ROW_H * TT.ROW_COUNT + TT.FOOTER_H)
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0, 0, 0, 0.92)
    f:SetBackdropBorderColor(0.6, 0.5, 0.25, 0.9)
    f:Hide()

    f.title = f:CreateFontString(nil, "OVERLAY")
    f.title:SetFont(barFont, 14, "OUTLINE")
    f.title:SetPoint("TOPLEFT", TT.PAD, -TT.PAD)
    f.title:SetTextColor(1, 0.84, 0)

    f.rows = {}
    for i = 1, TT.ROW_COUNT do
        local yOff = -(TT.PAD + TT.TITLE_H + (i - 1) * TT.ROW_H)
        local row = {}

        row.label = f:CreateFontString(nil, "OVERLAY")
        row.label:SetFont(barFont, 12, "OUTLINE")
        row.label:SetPoint("TOPLEFT", TT.PAD, yOff)
        row.label:SetSize(TT.LABEL_W, TT.ROW_H)
        row.label:SetJustifyH("LEFT")
        row.label:SetJustifyV("MIDDLE")
        row.label:SetWordWrap(false)
        row.label:SetTextColor(1, 0.84, 0)

        row.cells = {}
        for j = 1, 3 do
            local fs = f:CreateFontString(nil, "OVERLAY")
            fs:SetFont(barFont, 12, "OUTLINE")
            fs:SetPoint("TOPLEFT", TT.PAD + TT.LABEL_W + (j - 1) * TT.CELL_W, yOff)
            fs:SetSize(TT.CELL_W, TT.ROW_H)
            fs:SetJustifyH("CENTER")
            fs:SetJustifyV("MIDDLE")
            fs:SetWordWrap(false)
            row.cells[j] = fs
        end
        f.rows[i] = row
    end

    -- M+ 場次清單：標題 + 最多 8 行（位置在 ShowVaultTooltip 動態設定）
    f.runsHeader = f:CreateFontString(nil, "OVERLAY")
    f.runsHeader:SetFont(barFont, 12, "OUTLINE")
    f.runsHeader:SetSize(TT.WIDTH - TT.PAD * 2, TT.RUNS_HEADER_H)
    f.runsHeader:SetJustifyH("LEFT")
    f.runsHeader:SetJustifyV("MIDDLE")
    f.runsHeader:SetWordWrap(false)
    f.runsHeader:SetTextColor(1, 0.84, 0)
    f.runsHeader:Hide()

    f.runLines = {}
    for i = 1, TT.MAX_RUN_LINES do
        local fs = f:CreateFontString(nil, "OVERLAY")
        fs:SetFont(barFont, 12, "OUTLINE")
        fs:SetSize(TT.WIDTH - TT.PAD * 2, TT.RUN_LINE_H)
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("MIDDLE")
        fs:SetWordWrap(false)
        fs:SetTextColor(0.95, 0.95, 0.95)
        fs:Hide()
        f.runLines[i] = fs
    end

    f.snapshot = f:CreateFontString(nil, "OVERLAY")
    f.snapshot:SetFont(barFont, 11, "OUTLINE")
    f.snapshot:SetTextColor(0.6, 0.6, 0.6)

    -- 沒資料時顯示的提示（跨整個寬度，不受 row.label 寬度限制）
    f.noDataMain = f:CreateFontString(nil, "OVERLAY")
    f.noDataMain:SetFont(barFont, 12, "OUTLINE")
    f.noDataMain:SetPoint("TOPLEFT", TT.PAD, -(TT.PAD + TT.TITLE_H))
    f.noDataMain:SetTextColor(0.7, 0.7, 0.7)
    f.noDataMain:SetText("尚無寶庫資料")
    f.noDataMain:Hide()

    f.noDataSub = f:CreateFontString(nil, "OVERLAY")
    f.noDataSub:SetFont(barFont, 11, "OUTLINE")
    f.noDataSub:SetPoint("TOPLEFT", f.noDataMain, "BOTTOMLEFT", 0, -4)
    f.noDataSub:SetPoint("RIGHT", f, "RIGHT", -TT.PAD, 0)
    f.noDataSub:SetJustifyH("LEFT")
    f.noDataSub:SetTextColor(0.5, 0.5, 0.5)
    f.noDataSub:SetText("（角色尚未上線過或未開啟寶庫）")
    f.noDataSub:Hide()

    return f
end

local function ResetTooltipRows(tt)
    for i = 1, TT.ROW_COUNT do
        local row = tt.rows[i]
        row.label:SetText("")
        row.label:SetTextColor(1, 0.84, 0)
        for j = 1, 3 do
            row.cells[j]:SetText("")
            row.cells[j]:SetTextColor(LOCKED_CELL_R, LOCKED_CELL_G, LOCKED_CELL_B)
        end
    end
end

local function FillTooltipRow(row, trackKey, slots)
    row.label:SetText(VAULT_TRACK_LABELS[trackKey] or trackKey)
    for j = 1, 3 do
        local slot = slots and slots[j]
        local cell = row.cells[j]
        local unlocked = slot and (slot.level or 0) > 0
            and (slot.progress or 0) >= (slot.threshold or 0)
        if unlocked then
            local text, r, g, b = VaultCellDisplay(trackKey, slot)
            cell:SetText(text)
            cell:SetTextColor(r, g, b)
        else
            cell:SetText("·")
            cell:SetTextColor(LOCKED_CELL_R, LOCKED_CELL_G, LOCKED_CELL_B)
        end
    end
end

local function HideAllRunLines(tt)
    tt.runsHeader:Hide()
    for i = 1, TT.MAX_RUN_LINES do
        tt.runLines[i]:Hide()
    end
end

local function ShowVaultTooltip(owner, data)
    vaultTooltip = vaultTooltip or CreateVaultTooltip()
    local tt = vaultTooltip

    tt:ClearAllPoints()
    tt:SetPoint("TOPLEFT", owner, "TOPRIGHT", 6, 0)

    tt.title:SetText("本週寶庫 - " .. (data and data.name or "?"))
    ResetTooltipRows(tt)
    HideAllRunLines(tt)

    local vault = data and data.vault
    if not vault then
        tt.snapshot:Hide()
        tt.noDataMain:Show()
        tt.noDataSub:Show()
        tt:SetHeight(TT.PAD * 2 + TT.TITLE_H + 42)
        tt:Show()
        return
    end
    tt.noDataMain:Hide()
    tt.noDataSub:Hide()
    tt.snapshot:Show()

    -- 固定順序：團本 → M+ → 世界/競技（兩者擇一，視伺服器資料而定）
    local sequence = { "raid", "mplus" }
    if vault.world then
        sequence[#sequence + 1] = "world"
    elseif vault.pvp then
        sequence[#sequence + 1] = "pvp"
    end

    for i, key in ipairs(sequence) do
        FillTooltipRow(tt.rows[i], key, vault[key])
    end

    -- 從標題下方開始，依序往下排版並累計高度
    local y = TT.PAD + TT.TITLE_H + #sequence * TT.ROW_H

    -- M+ 場次清單
    local runs = vault.mplusRuns
    local nRuns = runs and #runs or 0
    if nRuns > 0 then
        y = y + TT.SPACE
        tt.runsHeader:ClearAllPoints()
        tt.runsHeader:SetPoint("TOPLEFT", TT.PAD, -y)
        tt.runsHeader:SetText(string.format("本週 M+ 紀錄 (%d/%d)", nRuns, MPLUS_MAX_RUNS))
        tt.runsHeader:Show()
        y = y + TT.RUNS_HEADER_H
        for i = 1, nRuns do
            local line = tt.runLines[i]
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", TT.PAD, -y)
            line:SetText(FormatRunLine(runs[i]))
            line:Show()
            y = y + TT.RUN_LINE_H
        end
    end

    -- 快照時間
    y = y + TT.SPACE
    tt.snapshot:ClearAllPoints()
    tt.snapshot:SetPoint("TOPLEFT", TT.PAD, -y)
    if vault.timestamp then
        tt.snapshot:SetText("快照時間：" .. date("%m/%d %H:%M", vault.timestamp))
    else
        tt.snapshot:SetText("")
    end
    y = y + TT.FOOTER_H + TT.PAD

    tt:SetHeight(y)
    tt:Show()
end

local function HideVaultTooltip()
    if vaultTooltip then vaultTooltip:Hide() end
end

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

    -- 寶庫欄：一個 sub-frame 含 3 個 cell 字串，整塊 hover 出 tooltip
    row.vaultArea = CreateFrame("Frame", nil, row)
    row.vaultArea:SetSize(COL_DEFS[VAULT_COL_INDEX].width, ROW_HEIGHT)
    row.vaultArea:SetPoint("LEFT", row, "LEFT", xOff, 0)
    row.vaultArea:EnableMouse(true)
    row.vaultCells = {}
    local cellWidth = COL_DEFS[VAULT_COL_INDEX].width / 3
    for i = 1, 3 do
        local fs = row.vaultArea:CreateFontString(nil, "OVERLAY")
        fs:SetFont(barFont, 12, "OUTLINE")
        fs:SetPoint("LEFT", row.vaultArea, "LEFT", (i - 1) * cellWidth, 0)
        fs:SetWidth(cellWidth)
        fs:SetJustifyH("CENTER")
        row.vaultCells[i] = fs
    end
    row.vaultArea:SetScript("OnEnter", function(self)
        ShowVaultTooltip(self, row.data)
    end)
    row.vaultArea:SetScript("OnLeave", HideVaultTooltip)
    xOff = xOff + COL_DEFS[VAULT_COL_INDEX].width + PADDING_X

    -- 虛無之核欄（只在 Syndicator 載入時建立）
    if SPARK_COL_INDEX then
        row.fsSpark = row:CreateFontString(nil, "OVERLAY")
        row.fsSpark:SetFont(barFont, 12, "OUTLINE")
        row.fsSpark:SetPoint("LEFT", row, "LEFT", xOff, 0)
        row.fsSpark:SetWidth(COL_DEFS[SPARK_COL_INDEX].width)
        row.fsSpark:SetJustifyH(COL_DEFS[SPARK_COL_INDEX].align)
        xOff = xOff + COL_DEFS[SPARK_COL_INDEX].width + PADDING_X
    end

    row.fsDate = row:CreateFontString(nil, "OVERLAY")
    row.fsDate:SetFont(barFont, 12, "OUTLINE")
    row.fsDate:SetPoint("LEFT", row, "LEFT", xOff, 0)
    row.fsDate:SetWidth(COL_DEFS[DATE_COL_INDEX].width)
    row.fsDate:SetJustifyH(COL_DEFS[DATE_COL_INDEX].align)

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

    -- 有 Syndicator 才加虛無之核欄；無此插件就維持 4 欄不顯示
    if HasSyndicator() then
        table.insert(COL_DEFS, 4, { label = "虛無之核", width = SPARK_COL_WIDTH, align = "CENTER" })
        SPARK_COL_INDEX = 4
        DATE_COL_INDEX  = 5
        PANEL_WIDTH     = PANEL_WIDTH + SPARK_COL_WIDTH + PADDING_X
    end

    ---------------------------------------------------------------------------
    -- 主面板：parented to KeystoneLootFrame
    ---------------------------------------------------------------------------
    local panel = CreateFrame("Frame", "MiliUI_CharacterKeystonesPanel", lootFrame, "BackdropTemplate")
    panel:SetSize(PANEL_WIDTH, 200)
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

    ---------------------------------------------------------------------------
    -- 提示面板：放在主面板下方，提醒分身 key 指令
    -- parented 到主 panel，會跟著主 panel 顯示/隱藏；anchor BOTTOM 跟主 panel 高度
    ---------------------------------------------------------------------------
    local tipPanel = CreateFrame("Frame", "MiliUI_CharacterKeystonesTipPanel", panel, "BackdropTemplate")
    tipPanel:SetSize(PANEL_WIDTH, 34)
    tipPanel:SetPoint("TOP", panel, "BOTTOM", 0, -6)
    tipPanel:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    tipPanel:SetBackdropColor(0.06, 0.06, 0.10, 0.92)
    tipPanel:SetBackdropBorderColor(0.6, 0.5, 0.25, 0.8)

    local tipText = tipPanel:CreateFontString(nil, "OVERLAY")
    tipText:SetFont(barFont, 12, "OUTLINE")
    tipText:SetPoint("CENTER", tipPanel, "CENTER", 0, 0)
    tipText:SetTextColor(0.9, 0.9, 0.9)
    tipText:SetText("|cffffd700提示|r：在隊伍頻道輸入 |cff00ff00「分身key」|r 可發送所有分身鑰石到隊伍頻道")

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

        -- 每次重整建立一次虛無之核 lookup，避免每 row 都掃一遍 Syndicator 資料
        local sparkLookup = SPARK_COL_INDEX and BuildSparkLookup() or nil

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

            if data.mapID and data.mapID > 0 and (data.level or 0) > 0 then
                local mapName = (C_ChallengeMode and C_ChallengeMode.GetMapUIInfo)
                    and C_ChallengeMode.GetMapUIInfo(data.mapID) or "?"
                row.fsKey:SetTextColor(unpack(VALUE_COLOR))
                row.fsKey:SetText(mapName .. " +" .. data.level)
            else
                row.fsKey:SetTextColor(0.5, 0.5, 0.5)
                row.fsKey:SetText("—")
            end

            -- 寶庫 M+ 三格：依該格鑰石等級對應寶庫物品稀有度上色（與遊戲內掉落對照表一致）
            local mplus = data.vault and data.vault.mplus
            for i = 1, 3 do
                local slot = mplus and mplus[i]
                local cell = row.vaultCells[i]
                if slot and (slot.level or 0) > 0
                    and (slot.progress or 0) >= (slot.threshold or 0) then
                    cell:SetText("+" .. slot.level)
                    cell:SetTextColor(VaultSlotQualityColor(slot.level))
                else
                    cell:SetText("·")
                    cell:SetTextColor(LOCKED_CELL_R, LOCKED_CELL_G, LOCKED_CELL_B)
                end
            end

            -- 虛無之核欄（Syndicator 載入時才有）
            if row.fsSpark then
                local lookupKey = (data.name or "") .. "-" .. NormalizeRealmName(data.realm)
                local count = sparkLookup and sparkLookup[lookupKey] or 0
                if count > 0 then
                    row.fsSpark:SetText(tostring(count))
                    row.fsSpark:SetTextColor(1, 0.84, 0)
                else
                    row.fsSpark:SetText("·")
                    row.fsSpark:SetTextColor(LOCKED_CELL_R, LOCKED_CELL_G, LOCKED_CELL_B)
                end
            end

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
        self:RegisterEvent("WEEKLY_REWARDS_UPDATE")
        -- 寶庫即時刷新觸發源（C 方案：細粒度事件 hook）
        self:RegisterEvent("ENCOUNTER_END")           -- 團本 BOSS
        self:RegisterEvent("PVP_MATCH_COMPLETE")      -- PvP 賽局結束
        self:RegisterEvent("LFG_COMPLETION_REWARD")   -- 探究/隨機副本/情景
        self:RegisterEvent("QUEST_TURNED_IN")         -- 世界任務（過 dedup 不會 spam）
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
                if MiliUI_KeystoneDebug then
                    print(string.format(
                        "|cff00ff00[Keystone]|r Baseline: map=%d lv=%d",
                        mapID, level
                    ))
                end
                if mapID > 0 and level > 0 then
                    SaveKeystoneRecord(mapID, level)
                end
                SaveVaultSnapshot()
            end
        end)
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        ScheduleKeystoneCheck(0)
    elseif event == "GOSSIP_CLOSED" then
        if IsKeystoneNpcGossip() then
            ScheduleKeystoneCheck(0)
        end
    elseif event == "WEEKLY_REWARDS_UPDATE" then
        if MiliUI_KeystoneDebug then
            print("|cff00ff00[Keystone]|r WEEKLY_REWARDS_UPDATE → ScheduleKeystoneCheck")
        end
        ScheduleKeystoneCheck(0)
    elseif event == "ENCOUNTER_END" then
        local _, _, difficultyID, _, success = ...
        if success == 1 and RAID_DIFFICULTY_IDS[difficultyID] then
            ScheduleVaultRefresh("ENCOUNTER_END diff=" .. tostring(difficultyID))
        end
    elseif event == "PVP_MATCH_COMPLETE" then
        ScheduleVaultRefresh("PVP_MATCH_COMPLETE")
    elseif event == "LFG_COMPLETION_REWARD" then
        ScheduleVaultRefresh("LFG_COMPLETION_REWARD")
    elseif event == "QUEST_TURNED_IN" then
        -- 不過濾，靠 ScheduleVaultRefresh 的 dedup 限頻；
        -- 一般主線/支線交任務也會 fire，但 3s 一次的代價可忽略
        ScheduleVaultRefresh("QUEST_TURNED_IN")
    end
end)

------------------------------------------------------------
-- 自我關鍵字偵測：hook 每個 ChatFrame 的 EditBox OnEnterPressed
-- 比 hook SendChatMessage 可靠 —— 後者可能被別的插件「替換」(非 hook) 掉，
-- 而 EditBox script 是 UI frame 上的 binding，無法被替換。
-- 完全避開 retail 12.x 的 secret-string 保護（不需碰 sender/GUID）。
------------------------------------------------------------
local SEND_CHAT_TYPES = {
    PARTY         = "PARTY",
    INSTANCE_CHAT = "INSTANCE_CHAT",
}

-- 1 秒 dedup：避免單一輸入透過多重路徑（typed + macro etc.）重複觸發
local lastTriggerTime = 0
local function MaybeSendReport(channel, src)
    local now = GetTime()
    if now - lastTriggerTime < 1 then
        if MiliUI_KeystoneDebug then
            print("|cff00ff00[Keystone]|r → 跳過 (dedup 1s 內已觸發過, src=" .. tostring(src) .. ")")
        end
        return
    end
    lastTriggerTime = now
    if MiliUI_KeystoneDebug then
        print("|cff00ff00[Keystone]|r → 觸發 SendKeystoneReport (src=" .. tostring(src) .. ")")
    end
    SendKeystoneReport(channel)
end

local function HookChatEditbox(editbox)
    if not editbox or editbox._miliKsHooked then return end
    editbox._miliKsHooked = true

    -- 在 OnTextChanged 期間記錄目前文字；OnEnterPressed 之後 Blizzard 會清空文字，
    -- 此時讀 GetText() 會是空字串，所以提前快取。
    editbox:HookScript("OnTextChanged", function(self)
        self._miliKsLastText = self:GetText()
    end)

    editbox:HookScript("OnEnterPressed", function(self)
        local msg = self._miliKsLastText
        self._miliKsLastText = nil
        if not msg or msg == "" then return end
        local chatType = self:GetAttribute("chatType")
        if MiliUI_KeystoneDebug then
            print(string.format("|cff00ff00[Keystone]|r edit hook: type=%s msg=%s",
                tostring(chatType), tostring(msg)))
        end
        local channel = SEND_CHAT_TYPES[chatType or ""]
        if not channel then return end
        if not MatchSelfKeyword(msg) then return end
        MaybeSendReport(channel, "edit")
    end)
end

-- 同時 hook 全域 SendChatMessage：對 /p 巨集 / SendChatMessage("...","PARTY") 之類
-- 不經 ChatEdit 的路徑也能命中（前提是該函式沒被別的插件 replace）。
hooksecurefunc("SendChatMessage", function(msg, chatType)
    local channel = SEND_CHAT_TYPES[chatType or ""]
    if not channel then return end
    if not MatchSelfKeyword(msg) then return end
    MaybeSendReport(channel, "send")
end)

local hookFrame = CreateFrame("Frame")
hookFrame:RegisterEvent("PLAYER_LOGIN")
hookFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        HookChatEditbox(_G["ChatFrame" .. i .. "EditBox"])
    end
end)

-- 開關 debug：/milikeydbg
SLASH_MILIKEYDBG1 = "/milikeydbg"
SlashCmdList.MILIKEYDBG = function()
    MiliUI_KeystoneDebug = not MiliUI_KeystoneDebug
    print("|cff00ff00[Keystone]|r debug:", MiliUI_KeystoneDebug and "ON" or "OFF")
end
