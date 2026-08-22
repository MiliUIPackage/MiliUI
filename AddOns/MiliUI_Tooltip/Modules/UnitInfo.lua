------------------------------------------------------------
-- 單位資料層：GetUnitInfo（讀 API → raw 表）、GetUnitData（raw + elements 設定 →
-- 每列文字）、觀察裝等 / 成就點數的非同步快取。純資料，不碰任何 tooltip。
--
-- 秘密值策略：所有 Unit API 一律 SafeCall；字串組合只用串接與 format（合法）；
-- 需要比較 / 查表 / 字串運算的地方先 SafeValue / PlainText 洗成明文，洗不出來就跳過。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret
local L = ns.L
local Colors = ns.Colors

ns.UnitInfo = {}
local UnitInfo = ns.UnitInfo

local AFK, DND, PLAYER, BOSS, ELITE = AFK, DND, PLAYER, BOSS, ELITE
local MALE, FEMALE = MALE, FEMALE
local RARE = GARRISON_MISSION_RARE
local OFFLINE = FRIENDS_LIST_OFFLINE
local BASE_MOVEMENT_SPEED = BASE_MOVEMENT_SPEED or 7

local MEDIA = "Interface\\AddOns\\MiliUI_Tooltip\\Media\\"

------------------------------------------------------------
-- 圖標集
------------------------------------------------------------

-- 陣營圖示用扁平 atlas（任務日誌的陣營任務標）：TinyTooltip 內建的
-- UI-PVP-ALLIANCE/HORDE 是舊版帶金屬圓框的立體徽章，縮到 14px 只剩一坨。
-- 原本掛在 MiliUI/Enhance/TinyTooltipRemake_FactionIcon.lua，這裡改成內建。
-- atlas 被暴雪拿掉時退回舊貼圖，不要塞出一個綠框。
--
-- 要換款式就把下面 icons 表裡的 atlas 名（與寬高）換成這幾組：
--   社群面板款（純色符號、完全沒描邊，最扁平，但顏色偏暗）：
--     communities-icon-faction-alliance 12×14 ／ communities-icon-faction-horde 12×14
--   世界任務地圖款（小尺寸下最清楚、顏色最飽和）：
--     worldquest-icon-alliance 14×13 ／ worldquest-icon-horde 14×13
--   登入畫面剪影款（單色灰白、無陣營色；兩邊原生比例不同）：
--     CharacterSelection_Alliance_Icon 11×14 ／ CharacterSelection_Horde_Icon 8×14
local function FactionIcon(atlas, w, h, fallback)
    if type(CreateAtlasMarkup) == "function"
        and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        return CreateAtlasMarkup(atlas, w, h)
    end
    return fallback
end

local icons = {
    Alliance   = FactionIcon("questlog-questtypeicon-alliance", 14, 14,
        "|TInterface\\TargetingFrame\\UI-PVP-ALLIANCE:14:14:0:0:64:64:10:36:2:38|t"),
    Horde      = FactionIcon("questlog-questtypeicon-horde", 14, 14,
        "|TInterface\\TargetingFrame\\UI-PVP-HORDE:14:14:0:0:64:64:4:38:2:36|t"),
    Neutral    = "|TInterface\\Timer\\Panda-Logo:14|t",
    pvp        = "|TInterface\\TargetingFrame\\UI-PVP-FFA:14:14:0:0:64:64:10:36:0:38|t",
    class      = "|TInterface\\TargetingFrame\\UI-Classes-Circles:14:14:0:0:256:256:%d:%d:%d:%d|t",
    questboss  = "|TInterface\\TargetingFrame\\PortraitQuestBadge:0|t",
    friend     = ("|T%sfriend.blp:14:14:0:0:32:32:1:30:2:30|t"):format(MEDIA),
    bnetfriend = "|TInterface\\ChatFrame\\UI-ChatIcon-BattleNet:14:14:0:0:32:32:1:30:2:30|t",
    TANK       = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:0:19:22:41|t",
    HEALER     = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:20:39:1:20|t",
    DAMAGER    = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:20:39:22:41|t",
}
UnitInfo.icons = icons

local mountIconTag = ("|T%smount.tga:14:14:0:0|t"):format(MEDIA)
local mplusIconTag = ("|T%smplus.tga:14:14:0:0|t"):format(MEDIA)
local itemLevelIconTag = ("|T%sitem_level.blp:14:14:0:0|t"):format(MEDIA)
local achievementIconTag = (type(CreateAtlasMarkup) == "function" and CreateAtlasMarkup("storyheader-cheevoicon", 14, 14)) or "|A:storyheader-cheevoicon:14:14|a"

------------------------------------------------------------
-- 單項讀取
------------------------------------------------------------
local function GetRaidIcon(unit)
    local index = S.PlainNumber(S.SafeCall(GetRaidTargetIndex, unit))
    local icon = index and ICON_LIST and ICON_LIST[index]
    if icon then return icon .. "0|t" end
end

local function GetPVPIcon(unit)
    if S.SafeBool(UnitIsPVPFreeForAll, unit) then return icons.pvp end
end

local function GetRoleIcon(unit)
    local role = S.SafeValue(S.SafeCall(UnitGroupRolesAssigned, unit))
    if type(role) == "string" then return icons[strupper(role)] end
end
UnitInfo.GetRoleIcon = GetRoleIcon

local function GetClassIcon(class)
    class = S.PlainText(class)
    if not class then return end
    local coords = CLASS_ICON_TCOORDS[strupper(class)]
    if not coords then return end
    local x1, x2, y1, y2 = unpack(coords)
    return format(icons.class, x1 * 256, x2 * 256, y1 * 256, y2 * 256)
end

local function GetQuestBossIcon(unit)
    if UnitIsQuestBoss and S.SafeBool(UnitIsQuestBoss, unit) then return icons.questboss end
end

local function GetFriendIcon(unit)
    if not S.SafeBool(UnitIsPlayer, unit) then return end
    local guid = S.SafeValue(S.SafeCall(UnitGUID, unit))
    if not guid then return end
    if C_FriendList and S.SafeBool(C_FriendList.IsFriend, guid) then
        return icons.friend
    end
    if guid ~= UnitGUID("player") and C_BattleNet and C_BattleNet.GetAccountInfoByGUID then
        local info = S.SafeCall(C_BattleNet.GetAccountInfoByGUID, guid)
        if type(info) == "table" and info.isFriend then
            return icons.bnetfriend
        end
    end
end

local GetUnitSpeedAPI = GetUnitSpeed
local function GetMoveSpeed(unit)
    local _, speed, flightSpeed, swimSpeed = S.SafeCall(GetUnitSpeedAPI, unit)
    if S.SafeBool(UnitIsOtherPlayersPet, unit) then
        -- 保持原速
    elseif S.SafeBool(IsSwimming, unit) then
        speed = swimSpeed
    elseif IsFlying and S.SafeBool(IsFlying, unit) then
        speed = flightSpeed
    end
    speed = S.PlainNumber(speed)
    if not speed or speed == 0 then return end
    return speed / BASE_MOVEMENT_SPEED * 100 + 0.5
end

-- 頭銜：pvpName 去掉 name 的剩餘部分（字串運算 → 兩者都要明文）
local function GetTitle(name, pvpName)
    name, pvpName = S.PlainText(name), S.PlainText(pvpName)
    if not name or not pvpName or name == pvpName then return end
    local pos = string.find(pvpName, name, 1, true)
    local title = pvpName:gsub(name, "", 1)
    title = title:gsub(",", ""):gsub("，", "")
    title = strtrim(title)
    if title == "" then return end
    return title, pos ~= 1
end

local function GetGender(gender)
    gender = S.PlainNumber(gender)
    if gender == 2 then
        return MALE
    elseif gender == 3 then
        return FEMALE
    end
end

local function GetZone(unit, unitname, realm)
    if not IsInGroup() then return end
    unit = S.PlainText(unit)
    unitname = S.PlainText(unitname)
    if not unit or not unitname then return end
    local t, i = string.match(unit, "(.-)(%d+)")
    if i and t == "raid" then
        return select(7, GetRaidRosterInfo(i))
    elseif i and t == "party" then
        local fullname = unitname .. "-" .. tostring(S.PlainText(realm) or "")
        for j = 1, 5 do
            local name, _, _, _, _, _, zone = GetRaidRosterInfo(j)
            if name and not string.find(name, "-", 1, true) and name == unitname then
                return zone
            elseif name and string.find(name, "-", 1, true) and name == fullname then
                return zone
            end
        end
    end
end

local function GetMythicPlusScore(unit)
    if not S.SafeBool(UnitIsPlayer, unit) then return end
    if not (C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary) then return end
    local summary = S.SafeCall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, unit)
    if type(summary) ~= "table" then return end
    local score = S.PlainNumber(summary.currentSeasonScore)
    if not score then return end
    local color = summary.currentSeasonScoreColor or summary.color
    if not color and C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor then
        color = S.SafeCall(C_ChallengeMode.GetDungeonScoreRarityColor, score)
    end
    local bestLevel
    if type(summary.runs) == "table" then
        for _, run in ipairs(summary.runs) do
            local lv = run and S.PlainNumber(run.bestRunLevel)
            if lv and (not bestLevel or lv > bestLevel) then bestLevel = lv end
        end
    end
    return score, color, bestLevel
end

------------------------------------------------------------
-- 坐騎（光環掃描：12.1 光環變秘密後 index 讀取會硬炸，先問 ShouldAurasBeSecret）
------------------------------------------------------------
local function AurasAreSecret()
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, res = pcall(C_Secrets.ShouldAurasBeSecret)
        if ok and res then return true end
    end
    return false
end
UnitInfo.AurasAreSecret = AurasAreSecret

local function FindMountAura(unit)
    if not (C_MountJournal and C_MountJournal.GetMountFromSpell) then return end
    if AuraUtil and AuraUtil.ForEachAura then
        local auraName, mountID
        local ok = pcall(AuraUtil.ForEachAura, unit, "HELPFUL", nil, function(aura)
            if type(aura) ~= "table" or not aura.spellId then return end
            local mount = C_MountJournal.GetMountFromSpell(aura.spellId)
            if mount then
                auraName, mountID = aura.name, mount
                return true
            end
        end)
        if not ok then auraName, mountID = nil, nil end
        if auraName then return auraName, mountID end
    end
    if AurasAreSecret() then return end
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40 do
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
            if not ok or not aura then break end
            local mountID = C_MountJournal.GetMountFromSpell(aura.spellId)
            if mountID then return aura.name, mountID end
        end
    end
end

local function GetMountInfo(unit)
    if not (C_MountJournal and C_MountJournal.GetMountInfoByID) then return end
    if not S.SafeBool(UnitIsPlayer, unit) then return end
    local auraName, mountID = FindMountAura(unit)
    if not auraName then return end
    local name, isCollected
    if mountID then
        local ok, mountName, _, _, _, _, _, _, _, _, _, collected = pcall(C_MountJournal.GetMountInfoByID, mountID)
        if ok then name, isCollected = mountName, collected end
    end
    return name or auraName, isCollected
end

------------------------------------------------------------
-- 觀察裝等 / 成就點數：非同步快取（TTL 900s、節流 1.2s）
------------------------------------------------------------
local INSPECT_TTL, INSPECT_INTERVAL = 900, 1.2
local inspect = { cache = {}, pendingGUID = nil, pendingUnit = nil, lastRequestAt = 0, suspendedUntil = 0 }
local achieve = { cache = {}, pendingGUID = nil, lastRequestAt = 0, suspendedUntil = 0 }
UnitInfo.inspectState = inspect
UnitInfo.achieveState = achieve

local function SafeGuid(unit)
    if not S.SafeBool(UnitExists, unit) then return end
    return S.SafeCall(UnitGUID, unit)
end

-- 12.1：受限單位的 GUID 可能是秘密 → 不能當 table key、不能直接 ==
local function GuidEquals(a, b)
    if a == nil or b == nil then return false end
    local ok, same = pcall(function() return a == b end)
    return ok and same == true
end
UnitInfo.GuidEquals = GuidEquals

local function CacheGet(state, unit, field)
    local guid = S.SafeValue(SafeGuid(unit))   -- 秘密 GUID 不查表
    if not guid then return end
    local cached = state.cache[guid]
    if not cached then return end
    if (GetTime() - cached.time) > INSPECT_TTL then
        state.cache[guid] = nil
        return
    end
    return cached[field]
end

local function CachePut(state, guid, field, value)
    guid = S.SafeValue(guid)
    if not guid or type(value) ~= "number" then return end
    state.cache[guid] = { [field] = floor(value + 0.5), time = GetTime() }
end

local function GetUnitItemLevel(unit)
    if not S.SafeBool(UnitIsPlayer, unit) then return end
    if S.SafeBool(UnitIsUnit, unit, "player") and GetAverageItemLevel then
        local average, equipped = S.SafeCall(GetAverageItemLevel)
        equipped, average = S.PlainNumber(equipped), S.PlainNumber(average)
        if equipped and equipped > 0 then return equipped end
        if average and average > 0 then return average end
    end
    local cached = CacheGet(inspect, unit, "level")
    if cached then return cached end
    if C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
        local lv = S.PlainNumber(S.SafeCall(C_PaperDollInfo.GetInspectItemLevel, unit))
        if lv and lv > 0 then
            CachePut(inspect, SafeGuid(unit), "level", lv)
            return lv
        end
    end
end

local function GetUnitAchievementPoints(unit)
    if S.SafeBool(UnitIsUnit, unit, "player") then
        local points = S.PlainNumber(S.SafeCall(GetTotalAchievementPoints))
        if points and points >= 0 then return points end
        return
    end
    if not S.SafeBool(UnitIsPlayer, unit) then return end
    return CacheGet(achieve, unit, "points")
end

function UnitInfo.RequestInspect(unit)
    if not (NotifyInspect and CanInspect) then return end
    if not S.SafeBool(UnitExists, unit) then return end
    if not S.SafeBool(UnitIsPlayer, unit) then return end
    if S.SafeBool(UnitIsUnit, unit, "player") then return end
    if not S.SafeBool(CanInspect, unit) then return end
    local guid = S.SafeValue(SafeGuid(unit))
    if not guid then return end
    local now = GetTime()
    if (inspect.suspendedUntil or 0) > now then return end
    if InspectFrame and InspectFrame.IsShown and InspectFrame:IsShown() then return end
    local cached = inspect.cache[guid]
    if cached and (now - cached.time) <= INSPECT_TTL then return end
    if inspect.pendingGUID == guid then return end
    if (now - (inspect.lastRequestAt or 0)) < INSPECT_INTERVAL then return end
    if pcall(NotifyInspect, unit) then
        inspect.pendingGUID = guid
        inspect.pendingUnit = unit
        inspect.lastRequestAt = now
    end
end

function UnitInfo.RequestAchievements(unit)
    if not S.SafeBool(UnitExists, unit) then return end
    if not S.SafeBool(UnitIsPlayer, unit) then return end
    if S.SafeBool(UnitIsUnit, unit, "player") then return end
    if not S.SafeBool(CanInspect, unit) then return end
    local guid = S.SafeValue(SafeGuid(unit))
    if not guid then return end
    local now = GetTime()
    if (achieve.suspendedUntil or 0) > now then return end
    local cached = achieve.cache[guid]
    if cached and (now - cached.time) <= INSPECT_TTL then return end
    if achieve.pendingGUID == guid then return end
    if (now - (achieve.lastRequestAt or 0)) < INSPECT_INTERVAL then return end
    -- 成就比較視窗開著就不要搶
    if AchievementFrame and AchievementFrame.isComparison then return end
    if AchievementFrameComparison and AchievementFrameComparison.UnregisterEvent then
        pcall(AchievementFrameComparison.UnregisterEvent, AchievementFrameComparison, "INSPECT_ACHIEVEMENT_READY")
    end
    if ClearAchievementComparisonUnit then pcall(ClearAchievementComparisonUnit) end
    local ok, result = pcall(SetAchievementComparisonUnit, unit)
    if ok and result ~= false then
        achieve.pendingGUID = guid
        achieve.lastRequestAt = now
    end
end

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("INSPECT_READY")
    f:RegisterEvent("INSPECT_ACHIEVEMENT_READY")
    f:SetScript("OnEvent", function(_, event, guid)
        if event == "INSPECT_READY" then
            if not guid or not GuidEquals(guid, inspect.pendingGUID) then return end
            local unit
            if inspect.pendingUnit and GuidEquals(SafeGuid(inspect.pendingUnit), guid) then
                unit = inspect.pendingUnit
            elseif GuidEquals(SafeGuid("mouseover"), guid) then
                unit = "mouseover"
            elseif GuidEquals(SafeGuid("target"), guid) then
                unit = "target"
            end
            if unit and C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
                local lv = S.PlainNumber(S.SafeCall(C_PaperDollInfo.GetInspectItemLevel, unit))
                if lv and lv > 0 then CachePut(inspect, guid, "level", lv) end
            end
            if ClearInspectPlayer and not (InspectFrame and InspectFrame.IsShown and InspectFrame:IsShown()) then
                pcall(ClearInspectPlayer)
            end
            inspect.pendingGUID, inspect.pendingUnit = nil, nil
            if ns.RefreshUnitTip then ns.RefreshUnitTip(guid) end
        elseif event == "INSPECT_ACHIEVEMENT_READY" then
            if not achieve.pendingGUID then return end
            if guid and not GuidEquals(guid, achieve.pendingGUID) then return end
            local resolved = guid or achieve.pendingGUID
            local points = S.PlainNumber(S.SafeCall(GetComparisonAchievementPoints))
            if points and points >= 0 then CachePut(achieve, resolved, "points", points) end
            if ClearAchievementComparisonUnit then pcall(ClearAchievementComparisonUnit) end
            achieve.pendingGUID = nil
            if ns.RefreshUnitTip then ns.RefreshUnitTip(resolved) end
        end
    end)

    -- 玩家自己開觀察視窗時退讓 3 秒
    if InspectUnit then
        hooksecurefunc("InspectUnit", function()
            local now = GetTime()
            inspect.suspendedUntil = now + 3
            inspect.pendingGUID, inspect.pendingUnit = nil, nil
            achieve.suspendedUntil = now + 3
            achieve.pendingGUID = nil
        end)
    end
end

------------------------------------------------------------
-- raw 表（重用同一張，跟 TinyTooltip 一樣）
------------------------------------------------------------
local t = {}
function UnitInfo.GetUnitInfo(unit)
    if not unit or not S.SafeBool(UnitExists, unit) then
        wipe(t)
        t.unit = unit
        return t
    end

    local name, realm = S.SafeCall(UnitName, unit)
    local pvpName = S.SafeCall(UnitPVPName, unit)
    local gender = S.SafeCall(UnitSex, unit)
    local level = S.SafeCall(UnitLevel, unit)
    local effectiveLevel = UnitEffectiveLevel and S.SafeCall(UnitEffectiveLevel, unit) or level
    local raceName, race = S.SafeCall(UnitRace, unit)
    local className, class = S.SafeCall(UnitClass, unit)
    local factionGroup, factionName = S.SafeCall(UnitFactionGroup, unit)
    local reaction = S.SafeValue(S.SafeCall(UnitReaction, unit, "player"))
    local guildName, guildRank, guildIndex, guildRealm = S.SafeCall(GetGuildInfo, unit)
    local classif = S.SafeValue(S.SafeCall(UnitClassification, unit))
    local role = S.SafeValue(S.SafeCall(UnitGroupRolesAssigned, unit))
    local mplusScore, mplusColor, mplusBest = GetMythicPlusScore(unit)
    local isPlayer = S.SafeBool(UnitIsPlayer, unit)
    local itemLevel = isPlayer and GetUnitItemLevel(unit) or nil
    local achievementPoints = isPlayer and GetUnitAchievementPoints(unit) or nil
    local plainLevel = S.PlainNumber(level)

    t.raidIcon     = GetRaidIcon(unit)
    t.pvpIcon      = GetPVPIcon(unit)
    t.factionIcon  = S.PlainText(factionGroup) and icons[factionGroup] or nil
    t.classIcon    = GetClassIcon(class)
    t.roleIcon     = GetRoleIcon(unit)
    t.questIcon    = GetQuestBossIcon(unit)
    t.friendIcon   = GetFriendIcon(unit)
    t.factionName  = factionName
    t.role         = (type(role) == "string" and role ~= "NONE") and role or nil
    t.name         = name
    t.gender       = GetGender(gender)
    t.realm        = realm or GetRealmName()
    t.levelValue   = (plainLevel and plainLevel >= 0) and plainLevel or L["unknown"]
    t.itemLevel    = isPlayer and ((itemLevel and itemLevel > 0) and floor(itemLevel + 0.5) or L["unknown"]) or nil
    t.achievementPoints = isPlayer and ((achievementPoints and achievementPoints >= 0) and floor(achievementPoints + 0.5) or L["unknown"]) or nil
    t.className    = className
    t.raceName     = raceName
    t.guildName    = guildName
    t.guildRank    = guildRank
    t.guildIndex   = guildName and guildIndex or nil
    t.guildRealm   = guildRealm
    t.statusAFK    = S.SafeBool(UnitIsAFK, unit) and AFK or nil
    t.statusDND    = S.SafeBool(UnitIsDND, unit) and DND or nil
    t.statusDC     = (S.SafeValue(S.SafeCall(UnitIsConnected, unit), true) == false) and OFFLINE or nil
    t.reactionName = reaction and _G["FACTION_STANDING_LABEL" .. reaction] or nil
    t.creature     = S.SafeCall(UnitCreatureType, unit)
    t.classifBoss  = (S.PlainNumber(level) == -1 or classif == "worldboss") and BOSS or nil
    t.classifElite = classif == "elite" and ELITE or nil
    t.classifRare  = (classif == "rare" or classif == "rareelite") and RARE or nil
    t.isPlayer     = isPlayer and PLAYER or nil
    t.moveSpeed    = GetMoveSpeed(unit)
    t.zone         = GetZone(unit, t.name, t.realm)
    t.unit         = unit
    t.level        = level
    t.effectiveLevel = effectiveLevel or level
    t.race         = race
    t.class        = class
    t.factionGroup = factionGroup
    t.reaction     = reaction
    t.classif      = classif
    t.title, t.titleIsPrefix = GetTitle(name, pvpName)
    if t.classifBoss then t.classifElite = nil end
    -- 分數與括號拆開存：染色只染分數，括號（最佳層數）固定白色
    if mplusScore and mplusScore > 0 then
        t.mplusScoreNumber = floor(mplusScore + 0.5)
        t.mplusBestText = (mplusBest and mplusBest > 0) and (" (" .. mplusBest .. ")") or ""
        t.mplusScoreColor = mplusColor
    else
        t.mplusScoreNumber = 0
        t.mplusBestText = " (0)"
        t.mplusScoreColor = { r = 0.6, g = 0.6, b = 0.6 }
    end
    t.mountName = nil
    t.mountCollected = nil
    t.classSpecIcon = nil
    return t
end

-- 坐騎欄位另外填（只有元素開啟才掃光環）
function UnitInfo.FillMount(raw, unit)
    raw.mountName, raw.mountCollected = GetMountInfo(unit)
end

------------------------------------------------------------
-- 顯示條件與格式化
------------------------------------------------------------
function UnitInfo.CheckFilter(config, raw)
    if IsAltKeyDown() or IsControlKeyDown() then return true end
    if not config or not config.enable then return end
    local filter = config.filter
    if not filter or filter == "" or filter == "none" then return true end
    local key = strsplit(":", filter)
    local oppo
    key, oppo = key:gsub("not%s+", "")
    local func = Colors.filterfunc[key]
    if func then
        local res = func(raw, select(2, strsplit(":", filter)))
        if oppo > 0 then return not res end
        return res
    end
    return true
end

-- value 可能是秘密（名字等）：format 合法；hex 上色只在有明文 hex 時做
function UnitInfo.FormatData(value, config, raw, numericValue)
    local color, wildcard = config.color, config.wildcard or "%s"
    local prevNumeric
    if raw and numericValue ~= nil then
        prevNumeric = raw._numericColorValue
        raw._numericColorValue = numericValue
    end
    local hex
    if Colors.colorfunc[color] then
        hex = select(4, Colors.colorfunc[color](raw))
    elseif type(color) == "string" and color:match("^%x%x%x%x%x%x$") then
        hex = color
    end
    if raw and numericValue ~= nil then
        raw._numericColorValue = prevNumeric
    end
    if not hex or color == "" or color == "default" or color == "none" then
        return (wildcard):format(value)
    end
    return ("|cff" .. hex .. wildcard .. "|r"):format(value)
end

------------------------------------------------------------
-- raw + elements → data（每列一個字串陣列）
------------------------------------------------------------
local function PushLabeled(out, labelText, iconTag, useIcon, valueText)
    local labelPart
    if useIcon and iconTag then
        labelPart = iconTag .. "|cffffd200:|r"
    else
        labelPart = format("|cffffd100%s:|r", labelText)
    end
    tinsert(out, format("%s %s", labelPart, valueText))
end

function UnitInfo.GetUnitData(unit, elements, raw)
    local data = {}
    local namePos, titlePos
    if not raw then raw = UnitInfo.GetUnitInfo(unit) end
    local CheckFilter, FormatData = UnitInfo.CheckFilter, UnitInfo.FormatData
    for i, v in ipairs(elements) do
        data[i] = {}
        local out = data[i]
        namePos, titlePos = nil, nil
        for _, e in ipairs(v) do
            local config = elements[e]
            if e == "mount" then
                if CheckFilter(config, raw) and raw.mountName then
                    local nameText
                    if config.color and config.wildcard then
                        nameText = FormatData(raw.mountName, config, raw)
                    else
                        nameText = raw.mountName
                    end
                    local label = config.icon and (mountIconTag .. "|cffffd200:|r") or ("|cffffd200" .. L["Mount"] .. ":|r")
                    local statusText
                    if raw.mountCollected == true then
                        statusText = "|cff00ff00(" .. L["collected"] .. ")|r"
                    elseif raw.mountCollected == false then
                        statusText = "|cff999999(" .. L["uncollected"] .. ")|r"
                    end
                    if statusText then
                        tinsert(out, format("%s %s %s", label, nameText, statusText))
                    else
                        tinsert(out, format("%s %s", label, nameText))
                    end
                end
            elseif e == "className" then
                if CheckFilter(config, raw) and raw.className then
                    local classText
                    if config.color and config.wildcard then
                        classText = FormatData(raw.className, config, raw, raw.className)
                    else
                        classText = raw.className
                    end
                    if config.icon then
                        if raw.classSpecIcon then
                            classText = ("|T%s:14:14:0:0|t"):format(raw.classSpecIcon)
                        elseif type(raw.classIcon) == "string" then
                            classText = raw.classIcon
                        end
                    end
                    tinsert(out, classText)
                end
            elseif e == "mplusScore" then
                if CheckFilter(config, raw) and raw.mplusScoreNumber then
                    -- 只染分數；括號（最佳層數）固定白色（使用者定案）
                    local scorePart
                    if config.color and config.wildcard then
                        scorePart = FormatData(raw.mplusScoreNumber, config, raw, raw.mplusScoreNumber)
                    else
                        scorePart = tostring(raw.mplusScoreNumber)
                    end
                    local bestPart = (raw.mplusBestText and raw.mplusBestText ~= "")
                        and ("|cffffffff" .. raw.mplusBestText .. "|r") or ""
                    if config.icon then
                        tinsert(out, format("%s|cffffd200:|r %s%s", mplusIconTag, scorePart, bestPart))
                    else
                        tinsert(out, format("|cffffd100%s:|r %s%s", L["Mythic+ Score"], scorePart, bestPart))
                    end
                end
            elseif e == "itemLevel" then
                if CheckFilter(config, raw) and raw.itemLevel then
                    local valuePart
                    if tostring(raw.itemLevel) == L["unknown"] then
                        valuePart = "|cff999999" .. L["unknown"] .. "|r"
                    elseif config.color and config.wildcard then
                        valuePart = FormatData(raw.itemLevel, config, raw, raw.itemLevel)
                    else
                        valuePart = tostring(raw.itemLevel)
                    end
                    PushLabeled(out, L["ItemLevel"], itemLevelIconTag, config.icon, valuePart)
                end
            elseif e == "achievementPoints" then
                if CheckFilter(config, raw) and raw.achievementPoints ~= nil then
                    local valuePart
                    if tostring(raw.achievementPoints) == L["unknown"] then
                        valuePart = "|cff999999" .. L["unknown"] .. "|r"
                    elseif config.color and config.wildcard then
                        valuePart = FormatData(raw.achievementPoints, config, raw, raw.achievementPoints)
                    else
                        valuePart = tostring(raw.achievementPoints)
                    end
                    PushLabeled(out, L["Achievement"], achievementIconTag, config.icon, valuePart)
                end
            elseif CheckFilter(config, raw) and raw[e] then
                if e == "name" then namePos = #out + 1 end
                if e == "title" then titlePos = #out + 1 end
                if config.color and config.wildcard then
                    -- 頭銜是後綴時要排在名字後面（TinyTooltip 同款位置交換）
                    if e == "title" and namePos == #out and raw.titleIsPrefix then
                        tinsert(out, namePos, FormatData(raw[e], config, raw, raw[e]))
                    elseif e == "name" and titlePos == #out and not raw.titleIsPrefix then
                        tinsert(out, titlePos, FormatData(raw[e], config, raw, raw[e]))
                    else
                        tinsert(out, FormatData(raw[e], config, raw, raw[e]))
                    end
                else
                    tinsert(out, raw[e])
                end
            end
        end
    end
    for i = #data, 1, -1 do
        if not data[i][1] then tremove(data, i) end
    end
    return data
end

------------------------------------------------------------
-- 一列 → 一個字串（值可能是秘密 → 逐一 pcall、串接合法）
------------------------------------------------------------
function UnitInfo.JoinRow(list, sep)
    if type(list) ~= "table" then return "" end
    local out = {}
    for i = 1, #list do
        local v = list[i]
        if v ~= nil then
            local ok, s = pcall(function()
                if type(v) == "string" then return v end
                if type(v) == "number" then return tostring(v) end
            end)
            if ok and type(s) == "string" then
                out[#out + 1] = s
            end
        end
    end
    local ok, res = pcall(table.concat, out, sep or " ")
    if ok and type(res) == "string" then return res end
    return ""
end
