
-------------------------------------
-- Core Author:M
-------------------------------------

TinyTooltip = {}
local addonFolderName = ...
if (type(addonFolderName) ~= "string" or addonFolderName == "") then
    addonFolderName = "TinyTooltip-Remake"
end
local addonTexturePath = ("Interface\\AddOns\\%s\\texture\\"):format(addonFolderName)
local addonIconPath = ("Interface\\AddOns\\%s\\icon\\"):format(addonFolderName)

local LibEvent = LibStub:GetLibrary("LibEvent.7000")
local LibMedia = LibStub:GetLibrary("LibSharedMedia-3.0", true)

local AFK = AFK
local DND = DND
local MALE = MALE
local BOSS = BOSS
local DEAD = DEAD
local ELITE = ELITE
local FEMALE = FEMALE
local TARGET = TARGET
local PLAYER = PLAYER
local RARE = GARRISON_MISSION_RARE
local OFFLINE = FRIENDS_LIST_OFFLINE
local BASE_MOVEMENT_SPEED = BASE_MOVEMENT_SPEED or 7
local TOOLTIP_UPDATE_TIME = TOOLTIP_UPDATE_TIME or 0.2

--BLZ function (Fixed for classic WOW)
local UnitEffectiveLevel = UnitEffectiveLevel or function() end
local UnitGroupRolesAssigned = UnitGroupRolesAssigned or function() end
local UnitIsQuestBoss = UnitIsQuestBoss or function() end
local IsFlying = IsFlying or function() end
local C_BattleNet_GetAccountInfoByGUID = C_BattleNet and C_BattleNet.GetAccountInfoByGUID or function() end


local addon = TinyTooltip

local function ResolveSpellIdFromSpellToken(spellToken)
    if (type(spellToken) == "number") then
        return spellToken
    end
    if (type(spellToken) == "string" and spellToken ~= "" and C_Spell and C_Spell.GetSpellInfo) then
        local okInfo, spellInfo = pcall(C_Spell.GetSpellInfo, spellToken)
        if (okInfo and type(spellInfo) == "table" and type(spellInfo.spellID) == "number") then
            return spellInfo.spellID
        end
    end
end

local function ResolveMacroSpellIdFromTooltip(tooltip)
    if (not tooltip or not tooltip.GetPrimaryTooltipData) then return end
    local okData, data = pcall(tooltip.GetPrimaryTooltipData, tooltip)
    if (not okData or type(data) ~= "table") then return end
    local lines = data.lines
    if (type(lines) ~= "table" or type(lines[1]) ~= "table") then return end
    local tooltipID = lines[1].tooltipID
    if (type(tooltipID) == "number") then
        return tooltipID
    end
end

local function ResolveMacroPayload(tooltip, macroId)
    local spellId = ResolveMacroSpellIdFromTooltip(tooltip)
    if (spellId) then
        return spellId
    end
    if (type(macroId) == "number" and type(GetMacroSpell) == "function") then
        local okMacro, a, b, c = pcall(GetMacroSpell, macroId)
        if (okMacro) then
            spellId = ResolveSpellIdFromSpellToken(a) or ResolveSpellIdFromSpellToken(b) or ResolveSpellIdFromSpellToken(c)
            if (spellId) then
                return spellId
            end
        end
    end
    if (type(macroId) == "number" and type(GetMacroItem) == "function") then
        local okItem, macroItem = pcall(GetMacroItem, macroId)
        if (okItem and macroItem) then
            local okInfo, _, itemLink = pcall(GetItemInfo, macroItem)
            if (okInfo and type(itemLink) == "string" and itemLink ~= "") then
                return nil, itemLink
            end
            if (type(macroItem) == "string" and macroItem ~= "") then
                return nil, macroItem
            end
        end
    end
end

local function ResolveTooltipSpellId(tooltip)
    if (not tooltip or type(tooltip.GetSpell) ~= "function") then return end
    local okSpell, _, spellToken = pcall(tooltip.GetSpell, tooltip)
    if (okSpell) then
        local spellId = ResolveSpellIdFromSpellToken(spellToken)
        if (spellId) then
            return spellId
        end
    end
    return ResolveMacroSpellIdFromTooltip(tooltip)
end

local function ResolveTooltipItemLink(tooltip)
    if (not tooltip or type(tooltip.GetItem) ~= "function") then return end
    local okItem, _, itemLink = pcall(tooltip.GetItem, tooltip)
    if (okItem and type(itemLink) == "string" and itemLink ~= "") then
        return itemLink
    end
end

local function ResolveActionPayload(tooltip, actionSlot)
    if (type(actionSlot) == "number" and type(GetActionInfo) == "function") then
        local okAction, actionType, actionId = pcall(GetActionInfo, actionSlot)
        if (okAction and actionType == "spell") then
            local spellId = ResolveSpellIdFromSpellToken(actionId)
            if (spellId) then
                return spellId
            end
        elseif (okAction and actionType == "item" and actionId) then
            local okInfo, _, itemLink = pcall(GetItemInfo, actionId)
            if (okInfo and type(itemLink) == "string" and itemLink ~= "") then
                return nil, itemLink
            end
        elseif (okAction and actionType == "macro") then
            return ResolveMacroPayload(tooltip, actionId)
        end
    end

    -- Some action kinds (e.g. mount/flyout style actions) don't provide a direct spell id via GetActionInfo.
    -- In those cases, read the resolved tooltip payload after SetAction has populated it.
    local tooltipSpellId = ResolveTooltipSpellId(tooltip)
    if (tooltipSpellId) then
        return tooltipSpellId
    end
    local tooltipItemLink = ResolveTooltipItemLink(tooltip)
    if (tooltipItemLink) then
        return nil, tooltipItemLink
    end
end

local function SafeHideNineSlice(tip)
    if (not tip or not tip.NineSlice) then return end
    local ns = tip.NineSlice
    if (type(ns) == "table" and ns.Hide) then
        ns:Hide()
        return
    end
    if (type(ns) == "userdata" and ns.IsObjectType) then
        if (ns:IsObjectType("Region") and ns.Hide) then
            ns:Hide()
        end
    end
end

addon.SafeHideNineSlice = SafeHideNineSlice

-- language & global vars
addon.L, addon.G = {}, {}
setmetatable(addon.L, {__index = function(_, k) return k end})
setmetatable(addon.G, {__index = function(_, k) return _G[k] or k end})

-- tooltips
addon.tooltips = {
    GameTooltip,
    EmbeddedItemTooltip,
    ItemRefTooltip,
    ShoppingTooltip1,
    ShoppingTooltip2,
    WorldMapTooltip,
    ItemRefShoppingTooltip1,
    ItemRefShoppingTooltip2,
    NamePlateTooltip,
}

-- 圖標集
addon.icons = {
    Alliance   = "|TInterface\\TargetingFrame\\UI-PVP-ALLIANCE:14:14:0:0:64:64:10:36:2:38|t",
    Horde      = "|TInterface\\TargetingFrame\\UI-PVP-HORDE:14:14:0:0:64:64:4:38:2:36|t",
    Neutral    = "|TInterface\\Timer\\Panda-Logo:14|t",
    pvp        = "|TInterface\\TargetingFrame\\UI-PVP-FFA:14:14:0:0:64:64:10:36:0:38|t",
    class      = "|TInterface\\TargetingFrame\\UI-Classes-Circles:14:14:0:0:256:256:%d:%d:%d:%d|t",
    battlepet  = "|TInterface\\Timer\\Panda-Logo:15|t",
    pettype    = "|TInterface\\TargetingFrame\\PetBadge-%s:14|t",
    questboss  = "|TInterface\\TargetingFrame\\PortraitQuestBadge:0|t",
    friend     = ("|T%sfriend.blp:14:14:0:0:32:32:1:30:2:30|t"):format(addonTexturePath),
    bnetfriend = "|TInterface\\ChatFrame\\UI-ChatIcon-BattleNet:14:14:0:0:32:32:1:30:2:30|t",
    TANK       = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:0:19:22:41|t",
    HEALER     = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:20:39:1:20|t",
    DAMAGER    = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:20:39:22:41|t",
}

local mountCollectionIconTag = ("|T%smount.tga:14:14:0:0|t"):format(addonIconPath)
local mplusScoreIconTag = ("|T%smplus.tga:14:14:0:0|t"):format(addonIconPath)
local itemLevelIconTag = ("|T%sitem_level.blp:14:14:0:0|t"):format(addonIconPath)
local achievementPointsIconTag = (type(CreateAtlasMarkup) == "function" and CreateAtlasMarkup("storyheader-cheevoicon", 14, 14)) or "|A:storyheader-cheevoicon:14:14|a"

-- 背景
addon.bgs = {
    gradual = "Interface\\Buttons\\GreyscaleRamp64",
    dark    = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    alpha   = "Interface\\Tooltips\\UI-Tooltip-Background",
    rock    = "Interface\\FrameGeneral\\UI-Background-Rock",
    marble  = "Interface\\FrameGeneral\\UI-Background-Marble",
}

--配置 (对elements鍵的值进行合并校验,不含factionBig,npcTitle键)
local function AutoValidateElements(src, dst)
    local keys = {}
    local hasItemLevel = false
    local hasAchievementPoints = false
    for k, v in ipairs(dst) do
        keys[k] = true
        for i = #v, 1, -1 do
            if (v[i] == "itemLevel" and src.itemLevel) then
                if (hasItemLevel) then
                    tremove(v, i)
                else
                    hasItemLevel = true
                    keys[v[i]] = true
                end
            elseif (v[i] == "achievementPoints" and src.achievementPoints) then
                if (hasAchievementPoints) then
                    tremove(v, i)
                else
                    hasAchievementPoints = true
                    keys[v[i]] = true
                end
            else
                keys[v[i]] = true
            end
        end
    end
    for k, v in pairs(src) do
        if (type(k) ~= "number" and not dst[k]) then
            dst[k] = (type(v) == "table") and CopyTable(v) or v
            if (k == "factionBig" or k == "npcTitle" or k == "itemLevel" or k == "achievementPoints") then
            elseif (not keys[k]) then
                if (not dst[1]) then dst[1] = {} end
                tinsert(dst[1], 1, k)
            end
        end
    end
    if (src.itemLevel and not hasItemLevel) then
        tinsert(dst, { "itemLevel" })
    end
    if (src.achievementPoints and not hasAchievementPoints) then
        tinsert(dst, { "achievementPoints" })
    end
    return dst
end

local function GetMythicPlusScore(unit)
    local function SafeCall(fn, ...)
        local ok, a, b, c, d = pcall(fn, ...)
        if ok then return a, b, c, d end
    end
    if (not unit or not UnitIsPlayer or not SafeCall(UnitIsPlayer, unit)) then return end
    if (C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary) then
        local summary = SafeCall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, unit)
        if (summary and summary.currentSeasonScore) then
            local score = summary.currentSeasonScore
            local color = summary.currentSeasonScoreColor or summary.color
            if (not color and C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor) then
                color = C_ChallengeMode.GetDungeonScoreRarityColor(score)
            end
            local bestLevel
            if (summary.runs and type(summary.runs) == "table") then
                for _, run in ipairs(summary.runs) do
                    if (run and run.bestRunLevel and (not bestLevel or run.bestRunLevel > bestLevel)) then
                        bestLevel = run.bestRunLevel
                    end
                end
            end
            return score, color, bestLevel
        end
    end
end

local INSPECT_CACHE_TTL = 900
local INSPECT_REQUEST_INTERVAL = 1.2
addon.inspectState = addon.inspectState or {
    cache = {},
    pendingGUID = nil,
    pendingUnit = nil,
    lastRequestAt = 0,
    suspendedUntil = 0,
}

local ACHIEVEMENT_CACHE_TTL = 900
local ACHIEVEMENT_REQUEST_INTERVAL = 1.2
addon.achievementInspectState = addon.achievementInspectState or {
    cache = {},
    pendingGUID = nil,
    lastRequestAt = 0,
    suspendedUntil = 0,
}
local achievementSummaryGuardInstalled = false

local function EnsureAchievementComparisonSummaryGuard()
    if (achievementSummaryGuardInstalled) then return end
    if (type(AchievementFrameComparison_UpdateStatusBars) ~= "function") then return end
    local original = AchievementFrameComparison_UpdateStatusBars
    AchievementFrameComparison_UpdateStatusBars = function(id, ...)
        if (id == "summary") then
            return
        end
        return original(id, ...)
    end
    achievementSummaryGuardInstalled = true
end

local function GetCachedInspectItemLevel(unit)
    local state = addon.inspectState
    if (not state or not state.cache or not unit or not UnitGUID) then return end
    local guid = UnitGUID(unit)
    if (not guid) then return end
    local cached = state.cache[guid]
    if (not cached or type(cached.level) ~= "number" or type(cached.time) ~= "number") then return end
    local now = GetTime and GetTime() or 0
    if ((now - cached.time) > INSPECT_CACHE_TTL) then
        state.cache[guid] = nil
        return
    end
    return cached.level
end

local function CacheInspectItemLevel(guid, level)
    if (not guid or type(level) ~= "number" or level <= 0) then return end
    local state = addon.inspectState
    if (not state or not state.cache) then return end
    state.cache[guid] = {
        level = floor(level + 0.5),
        time = GetTime and GetTime() or 0,
    }
end

local function GetCachedAchievementPoints(unit)
    local state = addon.achievementInspectState
    if (not state or not state.cache or not unit or not UnitGUID) then return end
    local guid = UnitGUID(unit)
    if (not guid) then return end
    local cached = state.cache[guid]
    if (not cached or type(cached.points) ~= "number" or type(cached.time) ~= "number") then return end
    local now = GetTime and GetTime() or 0
    if ((now - cached.time) > ACHIEVEMENT_CACHE_TTL) then
        state.cache[guid] = nil
        return
    end
    return cached.points
end

local function CacheAchievementPoints(guid, points)
    if (not guid or type(points) ~= "number" or points < 0) then return end
    local state = addon.achievementInspectState
    if (not state or not state.cache) then return end
    state.cache[guid] = {
        points = floor(points + 0.5),
        time = GetTime and GetTime() or 0,
    }
end

local function GetUnitItemLevel(unit)
    local function SafeCall(fn, ...)
        local ok, a, b, c = pcall(fn, ...)
        if ok then return a, b, c end
    end
    if (not unit or not UnitIsPlayer or not SafeCall(UnitIsPlayer, unit)) then return end

    if (UnitIsUnit and SafeCall(UnitIsUnit, unit, "player") and GetAverageItemLevel) then
        local average, equipped = SafeCall(GetAverageItemLevel)
        if (type(equipped) == "number" and equipped > 0) then
            return equipped
        end
        if (type(average) == "number" and average > 0) then
            return average
        end
    end

    local cachedInspectLevel = GetCachedInspectItemLevel(unit)
    if (type(cachedInspectLevel) == "number" and cachedInspectLevel > 0) then
        return cachedInspectLevel
    end

    if (C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel) then
        local inspectLevel = SafeCall(C_PaperDollInfo.GetInspectItemLevel, unit)
        if (type(inspectLevel) == "number" and inspectLevel > 0) then
            if (UnitGUID) then
                CacheInspectItemLevel(UnitGUID(unit), inspectLevel)
            end
            return inspectLevel
        end
    end
end

local function GetUnitAchievementPoints(unit)
    local function SafeCall(fn, ...)
        local ok, a, b, c = pcall(fn, ...)
        if ok then return a, b, c end
    end
    if (not unit) then return end

    local isSelf = false
    if (UnitGUID) then
        local unitGUID = SafeCall(UnitGUID, unit)
        local playerGUID = SafeCall(UnitGUID, "player")
        if (unitGUID and playerGUID and unitGUID == playerGUID) then
            isSelf = true
        end
    end
    if ((not isSelf) and UnitIsUnit and SafeCall(UnitIsUnit, unit, "player")) then
        isSelf = true
    end

    if (isSelf) then
        local points = SafeCall(GetTotalAchievementPoints)
        if (type(points) == "number" and points >= 0) then
            return points
        end
    end

    if (not SafeCall(UnitIsPlayer, unit)) then return end

    local cachedPoints = GetCachedAchievementPoints(unit)
    if (type(cachedPoints) == "number" and cachedPoints >= 0) then
        return cachedPoints
    end

    -- Other players are filled asynchronously via INSPECT_ACHIEVEMENT_READY cache.
end

function addon:RequestInspectItemLevel(unit)
    local function SafeBool(fn, ...)
        local ok, value = pcall(fn, ...)
        if (ok and value == true) then
            return true
        end
        return false
    end
    if (not unit or not NotifyInspect or not CanInspect) then return end
    if (not SafeBool(UnitExists, unit)) then return end
    if (not SafeBool(UnitIsPlayer, unit)) then return end
    if (SafeBool(UnitIsUnit, unit, "player")) then return end
    if (not SafeBool(CanInspect, unit)) then return end

    local guid = UnitGUID and UnitGUID(unit)
    if (not guid) then return end

    local state = self.inspectState
    if (not state) then return end
    local now = GetTime and GetTime() or 0
    if ((state.suspendedUntil or 0) > now) then
        return
    end
    if (InspectFrame and InspectFrame.IsShown and InspectFrame:IsShown()) then
        return
    end
    local cached = state.cache and state.cache[guid]
    if (cached and cached.time and (now - cached.time) <= INSPECT_CACHE_TTL) then
        return
    end
    if (state.pendingGUID == guid) then
        return
    end
    if ((now - (state.lastRequestAt or 0)) < INSPECT_REQUEST_INTERVAL) then
        return
    end

    local ok = pcall(NotifyInspect, unit)
    if (ok) then
        state.pendingGUID = guid
        state.pendingUnit = unit
        state.lastRequestAt = now
    end
end

function addon:RequestInspectAchievementPoints(unit)
    local function SafeBool(fn, ...)
        local ok, value = pcall(fn, ...)
        if (ok and value == true) then
            return true
        end
        return false
    end
    if (not unit) then return end
    if (not SafeBool(UnitExists, unit)) then return end
    if (not SafeBool(UnitIsPlayer, unit)) then return end
    if (SafeBool(UnitIsUnit, unit, "player")) then return end
    if (not SafeBool(CanInspect, unit)) then return end

    local guid = UnitGUID and UnitGUID(unit)
    if (not guid) then return end
    local playerGUID = UnitGUID and UnitGUID("player")
    if (playerGUID and guid == playerGUID) then return end

    local state = self.achievementInspectState
    if (not state) then return end
    local now = GetTime and GetTime() or 0
    if ((state.suspendedUntil or 0) > now) then
        return
    end
    local cached = state.cache and state.cache[guid]
    if (cached and cached.time and (now - cached.time) <= ACHIEVEMENT_CACHE_TTL) then
        return
    end
    if (state.pendingGUID == guid) then
        return
    end
    if ((now - (state.lastRequestAt or 0)) < ACHIEVEMENT_REQUEST_INTERVAL) then
        return
    end

    EnsureAchievementComparisonSummaryGuard()

    if (AchievementFrameComparison and AchievementFrameComparison.UnregisterEvent) then
        pcall(AchievementFrameComparison.UnregisterEvent, AchievementFrameComparison, "INSPECT_ACHIEVEMENT_READY")
    end
    if (AchievementFrame and AchievementFrame.isComparison) then
        return
    end
    if (ClearAchievementComparisonUnit) then
        pcall(ClearAchievementComparisonUnit)
    end

    local ok, result = pcall(SetAchievementComparisonUnit, unit)
    if (ok) then
        if (result ~= false) then
            state.pendingGUID = guid
            state.lastRequestAt = now
        end
    end
end

local function GetUnitGuidSafe(unit)
    if (not unit or not UnitExists or not UnitGUID) then return end
    local okExists, exists = pcall(UnitExists, unit)
    if (not okExists or not exists) then return end
    local okGuid, value = pcall(UnitGUID, unit)
    if (okGuid) then
        return value
    end
end

local function SafeGuidEquals(left, right)
    if (not left or not right) then
        return false
    end
    local ok, same = pcall(function()
        return left == right
    end)
    return ok and same == true
end

local function ResolveAsyncTooltipRefreshUnit(guid)
    if (not guid or not GameTooltip or not GameTooltip.IsShown or not GameTooltip:IsShown()) then
        return
    end

    local mouseoverGuid = GetUnitGuidSafe("mouseover")
    if (SafeGuidEquals(mouseoverGuid, guid)) then
        return "mouseover"
    end
    local currentGuid = GameTooltip._tinyUnitGUID
    if (SafeGuidEquals(currentGuid, guid)) then
        return false
    end
end

do
    local inspectEventFrame = CreateFrame("Frame")
    inspectEventFrame:RegisterEvent("INSPECT_READY")
    inspectEventFrame:SetScript("OnEvent", function(_, event, guid)
        if (event ~= "INSPECT_READY" or not guid) then return end
        local state = addon.inspectState
        if (not state) then return end
        if (not SafeGuidEquals(guid, state.pendingGUID)) then return end

        local unit
        if (state.pendingUnit and SafeGuidEquals(GetUnitGuidSafe(state.pendingUnit), guid)) then
            unit = state.pendingUnit
        elseif (SafeGuidEquals(GetUnitGuidSafe("mouseover"), guid)) then
            unit = "mouseover"
        elseif (SafeGuidEquals(GetUnitGuidSafe("target"), guid)) then
            unit = "target"
        end

        if (unit and C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel) then
            local ok, inspectLevel = pcall(C_PaperDollInfo.GetInspectItemLevel, unit)
            if (ok and type(inspectLevel) == "number" and inspectLevel > 0) then
                CacheInspectItemLevel(guid, inspectLevel)
            end
        end

        if (ClearInspectPlayer and (not InspectFrame or not InspectFrame.IsShown or not InspectFrame:IsShown())) then
            pcall(ClearInspectPlayer)
        end
        state.pendingGUID = nil
        state.pendingUnit = nil

        local refreshUnit = ResolveAsyncTooltipRefreshUnit(guid)
        if (refreshUnit) then
            LibEvent:trigger("tooltip:unit", GameTooltip, refreshUnit)
        elseif (refreshUnit == false) then
            pcall(GameTooltip.Hide, GameTooltip)
        end
    end)

    if (InspectUnit and hooksecurefunc) then
        hooksecurefunc("InspectUnit", function()
            local s = addon.inspectState
            if (not s) then return end
            local now = GetTime and GetTime() or 0
            s.suspendedUntil = now + 3
            s.pendingGUID = nil
            s.pendingUnit = nil
            local a = addon.achievementInspectState
            if (a) then
                a.suspendedUntil = now + 3
                a.pendingGUID = nil
            end
        end)
    end
end

do
    local achievementEventFrame = CreateFrame("Frame")
    achievementEventFrame:RegisterEvent("INSPECT_ACHIEVEMENT_READY")
    achievementEventFrame:SetScript("OnEvent", function(_, event, guid)
        if (event ~= "INSPECT_ACHIEVEMENT_READY") then return end
        local state = addon.achievementInspectState
        if (not state or not state.pendingGUID) then return end
        if (guid and not SafeGuidEquals(guid, state.pendingGUID)) then return end

        local resolvedGUID = guid or state.pendingGUID

        local points
        local ok, value = pcall(GetComparisonAchievementPoints)
        if (ok and type(value) == "number" and value >= 0) then
            points = value
        end
        if (type(points) == "number" and points >= 0) then
            CacheAchievementPoints(resolvedGUID, points)
        end

        if (ClearAchievementComparisonUnit) then
            pcall(ClearAchievementComparisonUnit)
        end
        state.pendingGUID = nil

        local refreshUnit = ResolveAsyncTooltipRefreshUnit(resolvedGUID)
        if (refreshUnit) then
            LibEvent:trigger("tooltip:unit", GameTooltip, refreshUnit)
        elseif (refreshUnit == false) then
            pcall(GameTooltip.Hide, GameTooltip)
        end
    end)
end

--字符型数字键转为数字键
function addon:FixNumericKey(t)
    local key
    local tbl = {}
    for k, v in pairs(t) do
        if (type(k) == "string" and string.match(k,"^[1-9]%d*$")) then
            key = tonumber(k)
            t[k] = nil
            tbl[key] = v
        end
    end
    for k, v in pairs(tbl) do
        if (not t[k]) then t[k] = v end
    end
    for k, v in pairs(t) do
        if (type(v) == "table") then
            t[k] = self:FixNumericKey(v)
        end
    end
    return t
end

-- 配置合併
function addon:MergeVariable(src, dst)
    if (type(src) ~= "table") then return dst end
    if (type(dst) ~= "table") then
        return CopyTable(src)
    end

    for k, v in pairs(src) do
        if (dst[k] == nil) then
            dst[k] = (type(v) == "table") and CopyTable(v) or v
        elseif (type(v) == "table" and type(dst[k]) == "table" and k~="elements") then
            self:MergeVariable(v, dst[k])
        elseif (type(v) == "table" and type(dst[k]) == "table" and k=="elements") then
            dst[k] = AutoValidateElements(v, dst[k])
        end
    end
    return dst
end

--自动调整宽度
function addon:AutoSetTooltipWidth(tooltip)
    local width, w = 80
    local measuredLines = 0
    local totalLines = tooltip:NumLines()
    local currentMinWidth
    if (tooltip.GetMinimumWidth) then
        local okMin, minValue = pcall(tooltip.GetMinimumWidth, tooltip)
        if (okMin and type(minValue) == "number" and not (issecretvalue and issecretvalue(minValue))) then
            currentMinWidth = minValue
        end
    end
    for i = 1, tooltip:NumLines() do
        local line = _G[tooltip:GetName() .. "TextLeft" .. i]
        local ok, value = pcall(function()
            if (not line) then return end
            local frameWidth
            if (line.GetWidth) then
                frameWidth = line:GetWidth()
            end
            if (type(frameWidth) == "number" and not (issecretvalue and issecretvalue(frameWidth))) then
                return frameWidth
            end
            local strWidth
            if (line.GetStringWidth) then
                strWidth = line:GetStringWidth()
            end
            if (type(strWidth) == "number" and not (issecretvalue and issecretvalue(strWidth))) then
                return strWidth
            end
        end)
        if (ok) then
            local okType, isNum = pcall(function()
                return type(value) == "number"
            end)
            if (okType and isNum and not (issecretvalue and issecretvalue(value))) then
                measuredLines = measuredLines + 1
                local okMax, newWidth = pcall(function()
                    return max(width, value)
                end)
                if (okMax) then
                    width = newWidth
                end
            end
        end
    end
    width = width + 6
    local showFactionBig = false
    if (tooltip and tooltip.BigFactionIcon and tooltip.BigFactionIcon.IsShown) then
        local okShown, isShown = pcall(tooltip.BigFactionIcon.IsShown, tooltip.BigFactionIcon)
        showFactionBig = okShown and isShown == true
    end
    if (showFactionBig) then
        width = width + 30
    end
    if (measuredLines == 0) then
        return currentMinWidth or width
    end
    if (measuredLines < totalLines and type(currentMinWidth) == "number") then
        width = max(width, currentMinWidth)
    end
    tooltip:SetMinimumWidth(width)
    tooltip:Show()
    return width
end

-- 找行
function addon:FindLine(tooltip, keyword)
    local line, text
    for i = 2, tooltip:NumLines() do
        line = _G[tooltip:GetName() .. "TextLeft" .. i]
        local ok, value = pcall(function() return line and line:GetText() end)
        if (ok) then
            local okType, isStr = pcall(function() return type(value) == "string" end)
            if (okType and isStr) then
                local okNe, notEmpty = pcall(function() return value ~= "" end)
                if (okNe and notEmpty) then
                    local okFind, found = pcall(function() return strfind(value, keyword) end)
                    if (okFind and found) then
                        return line, i, _G[tooltip:GetName() .. "TextRight" .. i]
                    end
                end
            end
        end
    end
end

-- 刪行
function addon:HideLine(tooltip, keyword)
    local line, text
    for i = 2, tooltip:NumLines() do
        line = _G[tooltip:GetName() .. "TextLeft" .. i]
        local ok, value = pcall(function() return line and line:GetText() end)
        if (ok) then
            local okType, isStr = pcall(function() return type(value) == "string" end)
            if (okType and isStr) then
                local okNe, notEmpty = pcall(function() return value ~= "" end)
                if (okNe and notEmpty) then
                    local okFind, found = pcall(function() return strfind(value, keyword) end)
                    if (okFind and found) then
                        line:SetText(nil)
                        break
                    end
                end
            end
        end
    end
end

-- 刪行
function addon:HideLines(tooltip, number, endNumber)
    endNumber = endNumber or 999
    for i = number, tooltip:NumLines() do
        if (endNumber >= i) then
            _G[tooltip:GetName() .. "TextLeft" .. i]:SetText(nil)
        end
    end
end

-- 取行
function addon:GetLine(tooltip, number)
    local num = tooltip:NumLines()
    if (number > num) then
        tooltip:AddLine(" ")
        return self:GetLine(tooltip, num+1)
    end
    return _G[tooltip:GetName() .. "TextLeft" .. number], _G[tooltip:GetName() .. "TextRight" .. number]
end

-- 顔色
function addon:GetHexColor(color, g, b)
    if (g and b) then
        return ("%02x%02x%02x"):format(color*255, g*255, b*255)
    elseif color.r then
        return ("%02x%02x%02x"):format(color.r*255, color.g*255, color.b*255)
    else
        local r, g, b = unpack(color)
        return ("%02x%02x%02x"):format(r*255, g*255, b*255)
    end
end

-- 顔色
function addon:GetRGBColor(hex)
    if (not hex) then return 1, 1, 1 end
    if (string.match(hex, "^%x%x%x%x%x%x$")) then
        local r = tonumber(strsub(hex,1,2),16) or 255
        local g = tonumber(strsub(hex,3,4),16) or 255
        local b = tonumber(strsub(hex,5,6),16) or 255
        return r/255, g/255, b/255
    end
    return 1, 1, 1
end

--字體
function addon:GetFont(font, default)
    if (font == "default") then
        font = default
    elseif (font and _G[font]) then
        font = _G[font].GetFont and _G[font]:GetFont()
    elseif(font and LibMedia and LibMedia:IsValid("font", font)) then
        font = LibMedia:Fetch("font", font)
    end
    return font or default
end

--背景
function addon:GetBgFile(bgvalue)
    if (type(bgvalue) ~= "string" or bgvalue == "") then
        return
    end
    if (self.bgs[bgvalue]) then
        return self.bgs[bgvalue]
    end
    -- Only resolve through LSM when the key is registered; otherwise
    -- keep custom/raw texture paths untouched.
    if (LibMedia and LibMedia:IsValid("background", bgvalue)) then
        return LibMedia:Fetch("background", bgvalue)
    end
    return bgvalue
end

--Bar
function addon:GetBarFile(bgvalue)
    if (bgvalue and LibMedia and LibMedia:IsValid("statusbar", bgvalue)) then
        return LibMedia:Fetch("statusbar", bgvalue)
    else
        return bgvalue
    end
end

--GetUnit
function addon:GetTooltipUnit(tooltip)
    if (not tooltip.GetUnit) then return end
    local unit = select(2, tooltip:GetUnit())
    return unit
end

-- 任務怪
function addon:GetQuestBossIcon(unit)
    if UnitIsQuestBoss(unit) then
        return self.icons.questboss
    end
end

-- PVP圖標
function addon:GetPVPIcon(unit)
    if (UnitIsPVPFreeForAll(unit)) then
        return self.icons.pvp
    end
end

-- 角色圖標
function addon:GetRoleIcon(unit)
    local role = UnitGroupRolesAssigned(unit)
    if (role) then
        return self.icons[strupper(role)]
    end
end

-- 陣營圖標
function addon:GetFactionIcon(factionGroup)
    return self.icons[factionGroup]
end

-- 標記圖標
function addon:GetRaidIcon(unit)
    local okIndex, index = pcall(GetRaidTargetIndex, unit)
    if (not okIndex or type(index) ~= "number") then return end
    local okIcon, icon = pcall(function()
        return ICON_LIST and ICON_LIST[index]
    end)
    if (not okIcon or not icon) then return end
    return icon .. "0|t"
end

-- 職業圖標
function addon:GetClassIcon(class)
    if (not class) then return end
    local x1, x2, y1, y2 = unpack(CLASS_ICON_TCOORDS[strupper(class)])
    return format(self.icons.class, x1*256, x2*256, y1*256, y2*256)
end

--好友图标
function addon:GetFriendIcon(unit)
    if (UnitIsPlayer(unit)) then
        local guid = UnitGUID(unit)
        if (guid and C_FriendList.IsFriend(guid)) then
            return self.icons.friend
        end
        if (guid and guid~=UnitGUID("player")) then
            local accountInfo = C_BattleNet_GetAccountInfoByGUID(guid)
            if (accountInfo and accountInfo.isFriend) then
                return self.icons.bnetfriend
            end
        end
    end
end

-- 戰寵
function addon:GetBattlePet(unit)
    if (UnitIsWildBattlePet(unit) or UnitIsBattlePetCompanion(unit)) then
        local petType = UnitBattlePetType(unit)
        return self.icons.battlepet, format(self.icons.pettype, PET_TYPE_SUFFIX[petType] or "")
    end
end

-- 移動速度
function addon:GetUnitSpeed(unit)
    local _, speed, flightSpeed, swimSpeed = GetUnitSpeed(unit)
    if (not speed or speed == 0) then return end
    speed = speed/BASE_MOVEMENT_SPEED*100
    swimSpeed = swimSpeed/BASE_MOVEMENT_SPEED*100
	flightSpeed = flightSpeed/BASE_MOVEMENT_SPEED*100
	if (UnitIsOtherPlayersPet(unit)) then
    elseif (IsSwimming(unit)) then
		speed = swimSpeed
	elseif (IsFlying(unit)) then
		speed = flightSpeed
	end
    return speed+0.5
end

-- 頭銜 @param2:true為前綴
function addon:GetTitle(name, pvpName)
    if (not pvpName) then return end
    if (name == pvpName) then return end
    local pos = string.find(pvpName, name)
    local title = pvpName:gsub(name, "", 1)
    title = title:gsub(",", ""):gsub("，", "")
    title = strtrim(title)
    return title, pos ~= 1
end

-- 性別
function addon:GetGender(gender)
    if (gender == 2) then
        return MALE, "male"
    elseif (gender == 3) then
        return FEMALE, "female"
    end
end

-- NPC頭銜
function addon:GetNpcTitle(tip)
    local line, index = self:FindLine(tip, "^"..LEVEL)
    if (not line or index <= 2) then return end
    return self:GetLine(tip, 2)
end

--地區
function addon:GetZone(unit, unitname, realm)
    if not IsInGroup() then return end
    local t, i = string.match(unit, "(.-)(%d+)")
    if (i and t == "raid") then
        return select(7, GetRaidRosterInfo(i))
    elseif (i and t == "party") then
        local name, zone
        local fullname = unitname .. "-" .. realm
        for j = 1, 5 do
            name, _, _, _, _, _, zone = GetRaidRosterInfo(j)
            if (name and not string.find(name, "-") and name == unitname) then
                return zone
            elseif (name and string.find(name, "-") and name == fullname) then
                return zone
            end
        end
    end
end

-- 全信息
local t = {}
function addon:GetUnitInfo(unit)
    local function SafeCall(fn, ...)
        local ok, a, b, c, d, e, f, g, h, i, j = pcall(fn, ...)
        if ok then return a, b, c, d, e, f, g, h, i, j end
    end
    local function SafeBool(fn, ...)
        local ok, value = pcall(fn, ...)
        if (not ok) then
            return false
        end
        local okEval, result = pcall(function()
            return value == true
        end)
        if (okEval) then
            return result
        end
        return false
    end
    if (not unit or not SafeBool(UnitExists, unit)) then
        t.unit = unit
        return t
    end

    local name, realm = SafeCall(UnitName, unit)
    local pvpName = SafeCall(UnitPVPName, unit)
    local gender = SafeCall(UnitSex, unit)
    local level = SafeCall(UnitLevel, unit)
    local effectiveLevel = SafeCall(UnitEffectiveLevel, unit)
    local raceName, race = SafeCall(UnitRace, unit)
    local className, class = SafeCall(UnitClass, unit)
    local factionGroup, factionName = SafeCall(UnitFactionGroup, unit)
    local reaction = SafeCall(UnitReaction, unit, "player")
    local guildName, guildRank, guildIndex, guildRealm = SafeCall(GetGuildInfo, unit)
    local classif = SafeCall(UnitClassification, unit)
    local role = SafeCall(UnitGroupRolesAssigned, unit)
    local mplusScore, mplusColor, mplusBest = GetMythicPlusScore(unit)
    local isPlayer = SafeBool(UnitIsPlayer, unit)
    local itemLevel = isPlayer and GetUnitItemLevel(unit)
    local achievementPoints = isPlayer and GetUnitAchievementPoints(unit)

    t.raidIcon     = self:GetRaidIcon(unit)
    t.pvpIcon      = self:GetPVPIcon(unit)
    t.factionIcon  = self:GetFactionIcon(factionGroup)
    t.classIcon    = self:GetClassIcon(class)
    t.roleIcon     = self:GetRoleIcon(unit)
    t.questIcon    = self:GetQuestBossIcon(unit)
    t.friendIcon   = self:GetFriendIcon(unit)
    --t.battlepetIcon = self:GetBattlePet(unit)
    t.factionName  = factionName
    t.role         = role ~= "NONE" and role
    t.name         = name
    t.gender       = self:GetGender(gender)
    t.realm        = realm or GetRealmName()
    t.levelValue   = (type(level) == "number" and level >= 0) and level or "??"
    t.itemLevel = isPlayer and ((type(itemLevel) == "number" and itemLevel > 0) and floor(itemLevel + 0.5) or "??") or nil
    t.achievementPoints = isPlayer and ((type(achievementPoints) == "number" and achievementPoints >= 0) and floor(achievementPoints + 0.5) or "??") or nil
    t.className    = className
    t.raceName     = raceName
    t.guildName    = guildName
    t.guildRank    = guildRank
    t.guildIndex   = guildName and guildIndex
    t.guildRealm   = guildRealm
    t.statusAFK    = SafeBool(UnitIsAFK, unit) and AFK
    t.statusDND    = SafeBool(UnitIsDND, unit) and DND
    t.statusDC     = SafeBool(UnitIsConnected, unit) == false and OFFLINE
    t.reactionName = reaction and _G["FACTION_STANDING_LABEL"..reaction]
    t.creature     = SafeCall(UnitCreatureType, unit)
    t.mplusScore = nil
    t.mplusScoreValue = nil
    t.mplusScoreColor = nil
    t.classifBoss  = (level==-1 or classif == "worldboss") and BOSS
    t.classifElite = classif == "elite" and ELITE
    t.classifRare  = (classif == "rare" or classif == "rareelite") and RARE
    t.isPlayer     = isPlayer and PLAYER
    t.moveSpeed    = self:GetUnitSpeed(unit)
    t.zone         = self:GetZone(unit, t.name, t.realm)
    local label = self.L and self.L["Mythic+ Score"] or "M+ Score"
    if (mplusScore and mplusScore > 0) then
        local bestText = (mplusBest and mplusBest > 0) and (" (" .. mplusBest .. ")") or ""
        t.mplusScore = format("%s: %d%s", label, floor(mplusScore + 0.5), bestText)
        t.mplusScoreValue = format("%d%s", floor(mplusScore + 0.5), bestText)
        t.mplusScoreColor = mplusColor
    else
        t.mplusScore = format("%s: %d (%d)", label, 0, 0)
        t.mplusScoreValue = "0 (0)"
        t.mplusScoreColor = { r = 0.6, g = 0.6, b = 0.6 }
    end
    t.unit         = unit                     --unit
    t.level        = level                    --1~123|-1
    t.effectiveLevel = effectiveLevel or level
    t.race         = race                     --nil|NightElf|Troll...
    t.class        = class                    --DRUID|HUNTER...
    t.factionGroup = factionGroup             --Alliance|Horde|Neutral
    t.reaction     = reaction                 --nil|1|2|3|4|5|6|7|8
    t.classif      = classif                  --normal|worldboss|elite|rare|rareelite
    t.title, t.titleIsPrefix = self:GetTitle(name, pvpName)
    if (t.classifBoss) then t.classifElite = false end
    return t
end

-- Filter
function addon:CheckFilter(config, raw)
    if (IsAltKeyDown() or IsControlKeyDown()) then return true end
    if (not config.enable) then return end
    if (config.filter == "" or config.filter == "none") then
        return true
    end
    if (config.filter) then
        local key, oppo, func
        key = strsplit(":", config.filter)
        key, oppo = key:gsub("not%s+", "")
        func = self.filterfunc[key]
        if (func) then
            local res = func(raw, select(2,strsplit(":", config.filter)))
            if (oppo > 0) then
                return not res
            else
                return res
            end
        end
    end
    return true
end

-- 格式化數據
function addon:FormatData(value, config, raw, numericValue)
    local color, wildcard = config.color, config.wildcard
    local prevNumericValue
    if (raw and numericValue ~= nil) then
        prevNumericValue = raw._numericColorValue
        raw._numericColorValue = numericValue
    end
    if (self.colorfunc[color]) then
        color = select(4, self.colorfunc[color](raw))
    end
    if (raw and numericValue ~= nil) then
        raw._numericColorValue = prevNumericValue
    end
    if (color == "" or color == "default" or color == "none") then
        return (wildcard):format(value)
    else
        if (type(color)=="table") then color = self:GetHexColor(color) end
        return ("|cff"..color..wildcard.."|r"):format(value)
    end
end

-- 獲取數據
function addon:GetUnitData(unit, elements, raw)
    local data = {}
    local config, name, title
    if (not raw) then
        raw = self:GetUnitInfo(unit)
    end
    for i, v in ipairs(elements) do
        data[i] = {}
        for ii, e in ipairs(v) do
            config = elements[e]
            if (e == "mount") then
                if (self:CheckFilter(config, raw) and raw.mountName) then
                    local labelText = (self.L and self.L.Mount) or MOUNT or "Mount"
                    local label = "|cffffd200" .. labelText .. ":|r"
                    local nameText
                    if (config and config.color and config.wildcard) then
                        nameText = self:FormatData(raw.mountName, config, raw)
                    else
                        nameText = raw.mountName
                    end
                    if (config and config.icon) then
                        label = mountCollectionIconTag .. "|cffffd200:|r"
                    end
                    local statusText
                    if (raw.mountCollected == true) then
                        local collectedText = (self.L and self.L.collected) or "collected"
                        statusText = "|cff00ff00(" .. collectedText .. ")|r"
                    elseif (raw.mountCollected == false) then
                        local uncollectedText = (self.L and self.L.uncollected) or "uncollected"
                        statusText = "|cff999999(" .. uncollectedText .. ")|r"
                    end
                    if (statusText) then
                        tinsert(data[i], format("%s %s %s", label, nameText, statusText))
                    else
                        tinsert(data[i], format("%s %s", label, nameText))
                    end
                end
            elseif (e == "className") then
                if (self:CheckFilter(config, raw) and raw.className) then
                    local classText
                    if (config and config.color and config.wildcard) then
                        classText = self:FormatData(raw.className, config, raw, raw.className)
                    else
                        classText = raw.className
                    end
                    if (config and config.icon) then
                        local classIconText
                        if (raw.classSpecIcon and raw.classSpecIcon ~= "") then
                            classIconText = ("|T%s:14:14:0:0|t"):format(raw.classSpecIcon)
                        elseif (type(raw.classIcon) == "string" and raw.classIcon ~= "") then
                            classIconText = raw.classIcon
                        end
                        if (classIconText and classIconText ~= "") then
                            classText = classIconText
                        end
                    end
                    tinsert(data[i], classText)
                end
            elseif (e == "mplusScore") then
                if (self:CheckFilter(config, raw) and raw.mplusScore) then
                    local scoreText = raw.mplusScoreValue or raw.mplusScore
                    if (type(scoreText) ~= "string") then
                        scoreText = tostring(scoreText or "")
                    elseif (not raw.mplusScoreValue) then
                        local parsed = scoreText:match(":%s*(.+)$")
                        if (parsed and parsed ~= "") then
                            scoreText = parsed
                        end
                    end
                    if (config and config.color and config.wildcard) then
                        scoreText = self:FormatData(scoreText, config, raw, scoreText)
                    end
                    if (config and config.icon) then
                        tinsert(data[i], format("%s|cffffd200:|r %s", mplusScoreIconTag, scoreText))
                    else
                        local fullText
                        if (config and config.color and config.wildcard) then
                            fullText = self:FormatData(raw.mplusScore, config, raw, raw.mplusScore)
                        else
                            fullText = raw.mplusScore
                        end
                        tinsert(data[i], fullText)
                    end
                end
            elseif (e == "itemLevel") then
                if (self:CheckFilter(config, raw) and raw.itemLevel) then
                    local labelText = (self.L and self.L.ItemLevel) or "ItemLevel"
                    local labelPart
                    if (config and config.icon) then
                        labelPart = itemLevelIconTag .. "|cffffd200:|r"
                    else
                        labelPart = format("|cffffd100%s:|r", labelText)
                    end
                    local itemLevelValue = raw.itemLevel
                    local valuePart
                    if (tostring(itemLevelValue) == "??") then
                        local unknownText = "??"
                        if (config and config.wildcard) then
                            local ok, formatted = pcall(function()
                                return (config.wildcard):format("??")
                            end)
                            if (ok and type(formatted) == "string" and formatted ~= "") then
                                unknownText = formatted
                            end
                        end
                        valuePart = "|cff999999" .. unknownText .. "|r"
                    elseif (config and config.color and config.wildcard) then
                        valuePart = self:FormatData(raw.itemLevel, config, raw, raw.itemLevel)
                    else
                        valuePart = tostring(itemLevelValue)
                    end
                    tinsert(data[i], format("%s %s", labelPart, valuePart))
                end
            elseif (e == "achievementPoints") then
                if (self:CheckFilter(config, raw) and raw.achievementPoints ~= nil) then
                    local labelText = (self.L and self.L.Achievement) or "Achievement"
                    local labelPart
                    if (config and config.icon) then
                        labelPart = achievementPointsIconTag .. "|cffffd200:|r"
                    else
                        labelPart = format("|cffffd100%s:|r", labelText)
                    end
                    local pointValue = raw.achievementPoints
                    local valuePart
                    if (tostring(pointValue) == "??") then
                        local unknownText = "??"
                        if (config and config.wildcard) then
                            local ok, formatted = pcall(function()
                                return (config.wildcard):format("??")
                            end)
                            if (ok and type(formatted) == "string" and formatted ~= "") then
                                unknownText = formatted
                            end
                        end
                        valuePart = "|cff999999" .. unknownText .. "|r"
                    elseif (config and config.color and config.wildcard) then
                        valuePart = self:FormatData(pointValue, config, raw, pointValue)
                    else
                        valuePart = tostring(pointValue)
                    end
                    tinsert(data[i], format("%s %s", labelPart, valuePart))
                end
            elseif (self:CheckFilter(config, raw) and raw[e]) then
                if (e == "name") then name = #data[i]+1 end   --name位置
                if (e == "title") then title = #data[i]+1 end --title位置
                if (config.color and config.wildcard) then
                    if (e == "title" and name == #data[i] and raw.titleIsPrefix) then
                        tinsert(data[i], name, self:FormatData(raw[e], config, raw, raw[e]))
                    elseif (e == "name" and title == #data[i] and not raw.titleIsPrefix) then
                        tinsert(data[i], title, self:FormatData(raw[e], config, raw, raw[e]))
                    else
                        tinsert(data[i], self:FormatData(raw[e], config, raw, raw[e]))
                    end
                else
                    tinsert(data[i], raw[e])
                end
            end
        end
    end
    for i = #data, 1, -1 do
        if (not data[i][1]) then tremove(data, i) end
    end
    return data
end

-- HookScript
function addon:TinyHookScript(script, func, scripts)
    if (self:HasScript(script)) then
        self:HookScript(script, func)
    elseif (scripts) then
        for _, newscript in ipairs(scripts) do
            if (self[newscript]) then
                hooksecurefunc(self, newscript, func)
            end
        end
    end
end


addon.filterfunc, addon.colorfunc = {}, {}

addon.colorfunc.class = function(raw)
    if (CUSTOM_CLASS_COLORS) then
        local color = CUSTOM_CLASS_COLORS[raw.class]
        if color then
            return color.r, color.g, color.b, addon:GetHexColor(color.r, color.g, color.b)
        end
        return 1, 1, 1, "ffffff"
    end
    local r, g, b = GetClassColor(raw.class)
    return r, g, b, addon:GetHexColor(r, g, b)
end

addon.colorfunc.mplus = function(raw)
    local c = raw and raw.mplusScoreColor
    if (c and c.r and c.g and c.b) then
        return c.r, c.g, c.b, addon:GetHexColor(c.r, c.g, c.b)
    end
    return 1, 1, 1, "ffffff"
end

addon.colorfunc.itemLevel = function(raw)
    local value = raw and tonumber(raw._numericColorValue or raw.itemLevel)
    if (not value) then
        return 0.6, 0.6, 0.6, "999999"
    end
    local color
    if (value >= 233) then
        color = ITEM_QUALITY_COLORS[4]
    elseif (value >= 220) then
        color = ITEM_QUALITY_COLORS[3]
    elseif (value >= 0) then
        color = ITEM_QUALITY_COLORS[2]
    end
    if (color and color.r and color.g and color.b) then
        return color.r, color.g, color.b, addon:GetHexColor(color)
    end
    return 1, 1, 1, "ffffff"
end

addon.colorfunc.level = function(raw)
    local color = GetCreatureDifficultyColor(raw.effectiveLevel>0 and raw.effectiveLevel or 999)
    return color.r, color.g, color.b, addon:GetHexColor(color)
end

addon.colorfunc.reaction = function(raw)
    local color = FACTION_BAR_COLORS[raw.reaction or 4]
    return color.r, color.g, color.b, addon:GetHexColor(color)
end

addon.colorfunc.itemQuality = function(raw)
    local color = ITEM_QUALITY_COLORS[raw.itemQuality or 0]
    return color.r, color.g, color.b, addon:GetHexColor(color)
end

addon.colorfunc.selection = function(raw)
    local r, g, b = UnitSelectionColor(raw.unit)
    return r, g, b, addon:GetHexColor(r, g, b)
end

addon.colorfunc.faction = function(raw)
    if (raw.factionGroup == "Neutral") then
        return 0.9, 0.7, 0, "e5b200"
    elseif (raw.factionGroup == UnitFactionGroup("player")) then
        return 0, 1, 0.2, "00cc33"
    else
        return 1, 0.2, 0, "dd3300"
    end
end

addon.filterfunc.reaction6 = function(raw, reaction)
    return (raw.reaction or 4) >= 6
end

addon.filterfunc.reaction5 = function(raw, reaction)
    return (raw.reaction or 4) >= 5
end

addon.filterfunc.reaction = function(raw, reaction)
    return (raw.reaction or 4) >= (tonumber(reaction) or 5)
end

addon.filterfunc.inraid = function(raw)
    return IsInRaid()
end

addon.filterfunc.incombat = function(raw)
    return InCombatLockdown()
end

addon.filterfunc.samerealm = function(raw)
    return raw.realm == GetRealmName()
end

addon.filterfunc.samecrossrealm = function(raw)
    return UnitRealmRelationship(raw.unit) ~= LE_REALM_RELATION_COALESCED
end

addon.filterfunc.inpvp = function(raw)
    return select(2, IsInInstance()) == "pvp"
end

addon.filterfunc.inarena = function(raw)
    return select(2, IsInInstance()) == "arena"
end

addon.filterfunc.ininstance = function(raw)
    return IsInInstance()
end

addon.filterfunc.sameguild = function(raw)
    local name, _, _, server = GetGuildInfo("player")
    if (name and name == raw.guildName and server == raw.guildRealm) then
        return true
    end
end

LibEvent:attachTrigger("tooltip.scale", function(self, frame, scale)
    frame:SetScale(scale)
end)

local function SafeSetOwner(frame, parent, anchor, ...)
    if (not frame or not frame.SetOwner) then return end
    if (parent and parent.IsForbidden and parent:IsForbidden()) then
        parent = UIParent
    end
    local ok = pcall(frame.SetOwner, frame, parent, anchor, ...)
    return ok
end

LibEvent:attachTrigger("tooltip.anchor.cursor", function(self, frame, parent)
    SafeSetOwner(frame, parent, "ANCHOR_CURSOR")
end)

LibEvent:attachTrigger("tooltip.anchor.cursor.right", function(self, frame, parent, offsetX, offsetY)
    SafeSetOwner(frame, parent, "ANCHOR_CURSOR_RIGHT", tonumber(offsetX) or 36, tonumber(offsetY) or -12)
end)

LibEvent:attachTrigger("tooltip.anchor.static", function(self, frame, parent, offsetX, offsetY, anchorPoint)
    local anchor = select(2, frame:GetPoint())
    if (anchor == UIParent or anchor == GameTooltipDefaultContainer) then
        frame:ClearAllPoints()
        frame:SetPoint(anchorPoint or "BOTTOMRIGHT", UIParent, anchorPoint or "BOTTOMRIGHT", tonumber(offsetX) or (-CONTAINER_OFFSET_X), tonumber(offsetY) or CONTAINER_OFFSET_Y)
    end
end)

LibEvent:attachTrigger("tooltip.anchor.none", function(self, frame, parent)
    SafeSetOwner(frame, parent, "ANCHOR_NONE")
    frame:Hide()
end)

local DEFAULT_TOOLTIP_BACKDROP = {
    bgFile   = "Interface\\RaidFrame\\UI-RaidFrame-GroupBg",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 14,
    insets   = {left = 3, right = 3, top = 3, bottom = 3},
}

local NINE_SLICE_BORDER_PARTS = {
    "TopLeftCorner",
    "TopRightCorner",
    "BottomLeftCorner",
    "BottomRightCorner",
    "TopEdge",
    "BottomEdge",
    "LeftEdge",
    "RightEdge",
}

local function IsNoBorderCorner(corner)
    if (type(corner) ~= "string") then return false end
    local lowered = string.lower(corner)
    return lowered == "none" or lowered == "off" or lowered == "disabled"
end

local function ShouldHideNativeNineSliceBorder(corner)
    if (IsNoBorderCorner(corner)) then
        return true
    end
    if (corner == "angular") then
        return true
    end
    if (corner ~= "default" and LibMedia and LibMedia:IsValid("border", corner)) then
        return true
    end
    return false
end

local function SetNineSliceBorderShown(tip, shown)
    local ns = tip and tip.NineSlice
    if (not ns) then return end
    if (ns.SetBorderShown) then
        pcall(ns.SetBorderShown, ns, shown)
    end
    if (ns.SetBorderVisible) then
        pcall(ns.SetBorderVisible, ns, shown)
    end
    for _, regionName in ipairs(NINE_SLICE_BORDER_PARTS) do
        local region = ns[regionName]
        if (region) then
            if (region.SetShown) then
                pcall(region.SetShown, region, shown)
            elseif (shown and region.Show) then
                pcall(region.Show, region)
            elseif (not shown and region.Hide) then
                pcall(region.Hide, region)
            end
            if (region.SetAlpha) then
                pcall(region.SetAlpha, region, shown and 1 or 0)
            end
        end
    end
end

local function CopyBackdropInfo(src)
    if (CopyTable) then
        return CopyTable(src)
    end
    local dst = {}
    for k, v in pairs(src or {}) do
        if (type(v) == "table") then
            dst[k] = {}
            for kk, vv in pairs(v) do
                dst[k][kk] = vv
            end
        else
            dst[k] = v
        end
    end
    return dst
end

local function EnsureBackdropSupport(tip)
    if (not tip) then return false end
    if (tip.SetBackdrop and tip.SetBackdropColor and tip.SetBackdropBorderColor) then
        return true
    end
    if (BackdropTemplateMixin and Mixin) then
        local ok = pcall(Mixin, tip, BackdropTemplateMixin)
        if (ok and tip.SetBackdrop and tip.SetBackdropColor and tip.SetBackdropBorderColor) then
            return true
        end
    end
    return false
end

local function EnsureNativeStyleData(tip)
    if (not tip) then return end
    if (not tip._tinyBackdrop) then
        tip._tinyBackdrop = CopyBackdropInfo(DEFAULT_TOOLTIP_BACKDROP)
    end
    if (not tip._tinyBackdropColor) then
        tip._tinyBackdropColor = {0, 0, 0, 0.9}
    end
    if (not tip._tinyBackdropBorderColor) then
        tip._tinyBackdropBorderColor = {0.6, 0.6, 0.6, 0.8}
    end
    if (not tip._tinyBorderCorner) then
        tip._tinyBorderCorner = "default"
    end
    if (not tip._tinyBorderSize) then
        tip._tinyBorderSize = 1
    end
end

local function GetStyleBackdrop(tip)
    EnsureNativeStyleData(tip)
    return tip and tip._tinyBackdrop
end

local function ResolveBackgroundFile(bgvalue)
    local bgfile = addon:GetBgFile(bgvalue)
    if (not bgfile and type(bgvalue) == "string" and bgvalue ~= "") then
        bgfile = bgvalue
    end
    return bgfile
end

local function SyncGlobalBackgroundFile(tip)
    if (not tip or not addon or not addon.db or not addon.db.general) then return end
    local backdrop = GetStyleBackdrop(tip)
    if (not backdrop) then return end
    local bgfile = ResolveBackgroundFile(addon.db.general.bgfile)
    if (bgfile and backdrop.bgFile ~= bgfile) then
        backdrop.bgFile = bgfile
    end
end

local function GetStyleBackdropColor(tip)
    EnsureNativeStyleData(tip)
    if (tip and tip._tinyBackdropColor) then
        return unpack(tip._tinyBackdropColor)
    end
    return 0, 0, 0, 0.9
end

local function GetStyleBackdropBorderColor(tip)
    EnsureNativeStyleData(tip)
    if (tip and tip._tinyBackdropBorderColor) then
        return unpack(tip._tinyBackdropBorderColor)
    end
    return 0.6, 0.6, 0.6, 0.8
end

local function TintNineSliceBorder(tip, r, g, b, a)
    local ns = tip and tip.NineSlice
    if (not ns) then return end
    if (ns.SetBorderColor) then
        pcall(ns.SetBorderColor, ns, r, g, b, a)
    end
    for _, regionName in ipairs(NINE_SLICE_BORDER_PARTS) do
        local region = ns[regionName]
        if (region and region.SetVertexColor) then
            pcall(region.SetVertexColor, region, r, g, b, a)
        end
    end
end

local function TintNineSliceBackground(tip)
    local ns = tip and tip.NineSlice
    if (not ns) then return end

    local backdrop = GetStyleBackdrop(tip)
    local bgFile = backdrop and backdrop.bgFile
    local r, g, b, a = GetStyleBackdropColor(tip)
    local alpha = min(1, max(0, tonumber(a) or 1))
    local tintR, tintG, tintB = r, g, b

    local center = ns.Center
    if (not center) then
        if (ns.SetCenterColor) then
            pcall(ns.SetCenterColor, ns, tintR, tintG, tintB, alpha)
        end
        return
    end
    if (center.SetDrawLayer) then
        -- Keep tooltip background behind all text/icon fontstrings.
        pcall(center.SetDrawLayer, center, "BACKGROUND", -8)
    end
    if (center.SetBlendMode) then
        pcall(center.SetBlendMode, center, "BLEND")
    end
    if (center.SetAtlas) then
        pcall(center.SetAtlas, center, nil)
    end
    if (center.SetTexture) then
        if (bgFile) then
            pcall(center.SetTexture, center, bgFile)
        else
            pcall(center.SetTexture, center, "Interface\\Buttons\\WHITE8X8")
        end
    end
    if (center.SetTexCoord) then
        pcall(center.SetTexCoord, center, 0, 1, 0, 1)
    end
    if (center.SetVertexColor) then
        -- Apply color once; alpha is handled via SetAlpha below.
        pcall(center.SetVertexColor, center, tintR, tintG, tintB, 1)
    end
    if (center.SetAlpha) then
        pcall(center.SetAlpha, center, alpha)
    end
end

local UpdateStyleMaskVisibility

local function SetStyleBackdropColor(tip, r, g, b, a)
    if (not tip) then return end
    EnsureNativeStyleData(tip)
    tip._tinyBackdropColor = {tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0, tonumber(a) or 0.9}
    local hasNineSliceBackdrop = tip.NineSlice and tip.NineSlice.SetBackdrop
    if (tip.SetBackdropColor and not hasNineSliceBackdrop) then
        pcall(tip.SetBackdropColor, tip, tip._tinyBackdropColor[1], tip._tinyBackdropColor[2], tip._tinyBackdropColor[3], tip._tinyBackdropColor[4])
    end
    TintNineSliceBackground(tip)
    UpdateStyleMaskVisibility(tip)
end

local function SetStyleBackdropBorderColor(tip, r, g, b, a)
    if (not tip) then return end
    EnsureNativeStyleData(tip)
    tip._tinyBackdropBorderColor = {tonumber(r) or 0.6, tonumber(g) or 0.6, tonumber(b) or 0.6, tonumber(a) or 0.8}
    local hasNineSliceBackdrop = tip.NineSlice and tip.NineSlice.SetBackdrop
    if (tip.SetBackdropBorderColor and not hasNineSliceBackdrop) then
        pcall(tip.SetBackdropBorderColor, tip, tip._tinyBackdropBorderColor[1], tip._tinyBackdropBorderColor[2], tip._tinyBackdropBorderColor[3], tip._tinyBackdropBorderColor[4])
    end
    TintNineSliceBorder(tip, tip._tinyBackdropBorderColor[1], tip._tinyBackdropBorderColor[2], tip._tinyBackdropBorderColor[3], tip._tinyBackdropBorderColor[4])
end

local function EnsureStyleMask(tip)
    if (not tip) then return end
    if (tip._tinyMask) then return tip._tinyMask end
    local mask = tip:CreateTexture(nil, "OVERLAY")
    mask:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    mask:SetPoint("TOPLEFT", 3, -3)
    mask:SetPoint("BOTTOMRIGHT", tip, "TOPRIGHT", -3, -32)
    mask:SetBlendMode("ADD")
    if (mask.SetGradient) then
        mask:SetGradient("VERTICAL", CreateColor(0,0,0,0), CreateColor(0.9,0.9,0.9,0.4))
    end
    mask:Hide()
    tip._tinyMask = mask
    return mask
end

UpdateStyleMaskVisibility = function(tip)
    local mask = EnsureStyleMask(tip)
    if (not mask) then return end
    local show = (tip and tip._tinyMaskEnabled) and true or false
    if (show) then
        local _, _, _, a = GetStyleBackdropColor(tip)
        local alpha = tonumber(a) or 0
        if (alpha <= 0.01) then
            show = false
        else
            if (mask.SetAlpha) then
                pcall(mask.SetAlpha, mask, min(1, max(0, alpha)))
            end
        end
    end
    if (show) then
        mask:Show()
    else
        mask:Hide()
    end
end

local function ApplyBorderCorner(tip, corner)
    EnsureNativeStyleData(tip)
    local backdrop = GetStyleBackdrop(tip)
    if (not backdrop) then return end
    if (type(corner) == "string" and corner ~= "") then
        tip._tinyBorderCorner = corner
    else
        tip._tinyBorderCorner = "default"
    end
    local insets = backdrop.insets
    if (type(insets) ~= "table") then
        insets = {}
        backdrop.insets = insets
    end
    if (tip._tinyBorderCorner == "angular") then
        local size = tonumber(tip._tinyBorderSize) or 1
        backdrop.edgeFile = "Interface\\Buttons\\WHITE8X8"
        backdrop.edgeSize = size
        insets.top = size
        insets.left = size
        insets.right = size
        insets.bottom = size
        local mask = EnsureStyleMask(tip)
        if (mask) then
            mask:ClearAllPoints()
            mask:SetPoint("TOPLEFT", 1, -1)
            mask:SetPoint("BOTTOMRIGHT", tip, "TOPRIGHT", -1, -32)
        end
    elseif (IsNoBorderCorner(tip._tinyBorderCorner)) then
        backdrop.edgeFile = nil
        backdrop.edgeSize = 0
        insets.top = 0
        insets.left = 0
        insets.right = 0
        insets.bottom = 0
        local mask = EnsureStyleMask(tip)
        if (mask) then
            mask:ClearAllPoints()
            mask:SetPoint("TOPLEFT", 0, 0)
            mask:SetPoint("BOTTOMRIGHT", tip, "TOPRIGHT", 0, -32)
        end
    elseif (tip._tinyBorderCorner ~= "default" and LibMedia and LibMedia:IsValid("border", tip._tinyBorderCorner)) then
        local mediaBorder = LibMedia:Fetch("border", tip._tinyBorderCorner)
        if (mediaBorder and mediaBorder ~= "") then
            backdrop.edgeFile = mediaBorder
            backdrop.edgeSize = 14
            insets.top = 3
            insets.left = 3
            insets.right = 3
            insets.bottom = 3
        else
            backdrop.edgeFile = nil
            backdrop.edgeSize = 0
            insets.top = 0
            insets.left = 0
            insets.right = 0
            insets.bottom = 0
        end
        local mask = EnsureStyleMask(tip)
        if (mask) then
            mask:ClearAllPoints()
            mask:SetPoint("TOPLEFT", 3, -3)
            mask:SetPoint("BOTTOMRIGHT", tip, "TOPRIGHT", -3, -32)
        end
    else
        backdrop.edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border"
        backdrop.edgeSize = 14
        insets.top = 3
        insets.left = 3
        insets.right = 3
        insets.bottom = 3
        local mask = EnsureStyleMask(tip)
        if (mask) then
            mask:ClearAllPoints()
            mask:SetPoint("TOPLEFT", 3, -3)
            mask:SetPoint("BOTTOMRIGHT", tip, "TOPRIGHT", -3, -32)
        end
    end
end

local function ApplyNativeBackdrop(tip)
    if (not tip) then return false end
    EnsureNativeStyleData(tip)
    SyncGlobalBackgroundFile(tip)
    local hasBackdropSupport = EnsureBackdropSupport(tip)
    local hasNineSliceBackdrop = tip.NineSlice and tip.NineSlice.SetBackdrop
    local shouldHideNativeNineSliceBorder = ShouldHideNativeNineSliceBorder(tip._tinyBorderCorner)
    if (tip._tinyApplyingNativeBackdrop) then return false end
    tip._tinyApplyingNativeBackdrop = true

    local backdropInfo = tip._tinyBackdrop and CopyBackdropInfo(tip._tinyBackdrop)
    if (hasBackdropSupport and tip.SetBackdrop and backdropInfo and not hasNineSliceBackdrop) then
        pcall(tip.SetBackdrop, tip, backdropInfo)
    end
    if (tip.NineSlice) then
        if (tip.NineSlice.SetBackdrop and backdropInfo) then
            pcall(tip.NineSlice.SetBackdrop, tip.NineSlice, CopyBackdropInfo(backdropInfo))
        end
    end

    local r, g, b, a = GetStyleBackdropColor(tip)
    local rr, gg, bb, aa = GetStyleBackdropBorderColor(tip)
    if (hasBackdropSupport and tip.SetBackdropColor and not hasNineSliceBackdrop) then
        pcall(tip.SetBackdropColor, tip, r, g, b, a)
    end
    if (hasBackdropSupport and tip.SetBackdropBorderColor and not hasNineSliceBackdrop) then
        pcall(tip.SetBackdropBorderColor, tip, rr, gg, bb, aa)
    end
    if (tip.NineSlice) then
        -- Center tint/alpha is handled by TintNineSliceBackground.
        if (tip.NineSlice.SetBackdropBorderColor) then
            pcall(tip.NineSlice.SetBackdropBorderColor, tip.NineSlice, rr, gg, bb, aa)
        end
        SetNineSliceBorderShown(tip, not shouldHideNativeNineSliceBorder)
    end
    TintNineSliceBackground(tip)
    TintNineSliceBorder(tip, rr, gg, bb, aa)
    UpdateStyleMaskVisibility(tip)
    tip._tinyApplyingNativeBackdrop = nil
    return true
end

local function InstallNativeBackdropLocks(tip)
    if (not tip or tip._tinyNativeLocksInstalled) then return end

    local function Reapply(frame)
        if (not frame or not frame._tinyNativeStyle) then return end
        if (frame._tinyApplyingNativeBackdrop) then return end
        if (frame.IsForbidden and frame:IsForbidden()) then return end
        ApplyNativeBackdrop(frame)
    end

    local function HookBackdropMethods(frame, owner)
        if (not frame) then return end
        local parent = owner or frame
        if (frame.ApplyBackdrop) then
            hooksecurefunc(frame, "ApplyBackdrop", function() Reapply(parent) end)
        end
        if (frame.SetBackdrop) then
            hooksecurefunc(frame, "SetBackdrop", function() Reapply(parent) end)
        end
        if (frame.ClearBackdrop) then
            hooksecurefunc(frame, "ClearBackdrop", function() Reapply(parent) end)
        end
        if (frame.SetBackdropColor) then
            hooksecurefunc(frame, "SetBackdropColor", function() Reapply(parent) end)
        end
        if (frame.SetBackdropBorderColor) then
            hooksecurefunc(frame, "SetBackdropBorderColor", function() Reapply(parent) end)
        end
        if (frame.SetCenterColor) then
            hooksecurefunc(frame, "SetCenterColor", function() Reapply(parent) end)
        end
        if (frame.SetBorderColor) then
            hooksecurefunc(frame, "SetBorderColor", function() Reapply(parent) end)
        end
    end

    HookBackdropMethods(tip, tip)
    if (tip.NineSlice) then
        HookBackdropMethods(tip.NineSlice, tip)
    end
    tip._tinyNativeLocksInstalled = true
end

LibEvent:attachTrigger("tooltip.style.mask", function(self, frame, boolean)
    LibEvent:trigger("tooltip.style.init", frame)
    frame._tinyMaskEnabled = not not boolean
    UpdateStyleMaskVisibility(frame)
end)

LibEvent:attachTrigger("tooltip.style.background", function(self, frame, r, g, b, a)
    LibEvent:trigger("tooltip.style.init", frame)
    local rr, gg, bb, aa = GetStyleBackdropColor(frame)
    if (rr ~= r or gg ~= g or bb ~= b or aa ~= a) then
        SetStyleBackdropColor(frame, r or rr, g or gg, b or bb, tonumber(a or aa or 0.9))
    end
    ApplyNativeBackdrop(frame)
end)

LibEvent:attachTrigger("tooltip.style.bgfile", function(self, frame, bgvalue)
    LibEvent:trigger("tooltip.style.init", frame)
    local backdrop = GetStyleBackdrop(frame)
    if (not backdrop) then return end
    local bgfile = ResolveBackgroundFile(bgvalue)
    if (not bgfile) then return end
    if (backdrop.bgFile ~= bgfile) then
        backdrop.bgFile = bgfile
    end
    ApplyNativeBackdrop(frame)
end)

local function ReapplyGlobalBackgroundFile(frame)
    if (not frame or not addon or not addon.db or not addon.db.general) then return end
    LibEvent:trigger("tooltip.style.bgfile", frame, addon.db.general.bgfile)
end

LibEvent:attachTrigger("tooltip:unit, tooltip:item, tooltip:spell, tooltip:aura", function(self, frame)
    ReapplyGlobalBackgroundFile(frame)
end)

LibEvent:attachTrigger("tooltip.style.border.size", function(self, frame, size)
    LibEvent:trigger("tooltip.style.init", frame)
    frame._tinyBorderSize = tonumber(size) or frame._tinyBorderSize or 1
    if (frame._tinyBorderCorner == "angular") then
        ApplyBorderCorner(frame, frame._tinyBorderCorner)
        ApplyNativeBackdrop(frame)
    end
end)

LibEvent:attachTrigger("tooltip.style.border.corner", function(self, frame, corner)
    LibEvent:trigger("tooltip.style.init", frame)
    ApplyBorderCorner(frame, corner)
    ApplyNativeBackdrop(frame)
end)

LibEvent:attachTrigger("tooltip.style.border.color", function(self, frame, r, g, b, a)
    LibEvent:trigger("tooltip.style.init", frame)
    local rr, gg, bb, aa = GetStyleBackdropBorderColor(frame)
    SetStyleBackdropBorderColor(frame, r or rr, g or gg, b or bb, a or aa)
    ApplyNativeBackdrop(frame)
end)

local defaultHeaderFont, defaultHeaderSize, defaultHeaderFlag = GameTooltipHeaderText:GetFont()
local function NormalizeFontFlag(flag, defaultFlag)
    -- SetFont third param accepts only specific flags; "NORMAL" is invalid in WoW.
    -- Map "NORMAL" to empty string (no outline), and "default"/empty to current default flag.
    if (type(flag) ~= "string" or flag == "") then
        return defaultFlag
    end
    if (flag == "default") then
        return defaultFlag
    end
    if (flag == "NORMAL") then
        return ""
    end
    return flag
end
LibEvent:attachTrigger("tooltip.style.font.header", function(self, frame, fontObject, fontSize, fontFlag)
    local font, size, flag = GameTooltipHeaderText:GetFont()
    if (fontObject == "default" and fontSize == "default" and fontFlag == "default") then
        if (size == defaultHeaderSize and flag == defaultHeaderFlag) then
            return
        end
    end
    font = addon:GetFont(fontObject, defaultHeaderFont)
    if (fontSize == "default") then
        size = defaultHeaderSize
    elseif (type(fontSize) == "number") then
        size = fontSize
    end
    flag = NormalizeFontFlag(fontFlag, defaultHeaderFlag) or flag
    GameTooltipHeaderText:SetFont(font, size, flag)
end)

local defaultBodyFont, defaultBodySize, defaultBodyFlag = GameTooltipText:GetFont()
LibEvent:attachTrigger("tooltip.style.font.body", function(self, frame, fontObject, fontSize, fontFlag)
    local font, size, flag = GameTooltipText:GetFont()
    font = addon:GetFont(fontObject, defaultBodyFont)
    if (fontSize == "default") then
        size = defaultBodySize
    elseif (type(fontSize) == "number") then
        size = fontSize
    end
    flag = NormalizeFontFlag(fontFlag, defaultBodyFlag) or flag
    GameTooltipText:SetFont(font, size, flag)
end)

LibEvent:attachTrigger("tooltip.statusbar.height", function(self, height)
    GameTooltipStatusBar:SetHeight(height or 12)
    local general = addon.db.general
    if (GameTooltip and GameTooltip._tinyStatusBarUnitActive and not general.statusbarHide and (general.statusbarHeight or 12) > 0) then
        GameTooltipStatusBar:Show()
    else
        GameTooltipStatusBar:Hide()
    end
end)

LibEvent:attachTrigger("tooltip.statusbar.text", function(self, boolean)
    local showText = not not boolean
    local showPercent = addon.db.general.statusbarPercent
    GameTooltipStatusBar.forceHideText = not (showText or showPercent)
end)

LibEvent:attachTrigger("tooltip.statusbar.visible", function(self, hide)
    if (hide) then
        GameTooltipStatusBar:Hide()
        return
    end
    local general = addon.db.general
    if (GameTooltip and GameTooltip._tinyStatusBarUnitActive and not general.statusbarHide and (general.statusbarHeight or 12) > 0) then
        GameTooltipStatusBar:Show()
    else
        GameTooltipStatusBar:Hide()
    end
end)

LibEvent:attachTrigger("tooltip:unit", function(self, tip)
    if (tip ~= GameTooltip) then return end
    GameTooltip._tinyStatusBarUnitActive = true
    local general = addon.db.general
    if (not general.statusbarHide and (general.statusbarHeight or 12) > 0) then
        GameTooltipStatusBar:Show()
    else
        GameTooltipStatusBar:Hide()
    end
end)

LibEvent:attachTrigger("tooltip:item, tooltip:spell, tooltip:aura, tooltip:cleared, tooltip:hide", function(self, tip)
    if (tip ~= GameTooltip) then return end
    GameTooltip._tinyStatusBarUnitActive = false
    GameTooltipStatusBar:Hide()
end)

LibEvent:attachTrigger("tooltip.statusbar.font", function(self, font, size, flag)
    if (size ~= nil and type(size) ~= "number") then size = nil end
    if (not GameTooltipStatusBar.TextString) then return end
    local origFont, origSize, origFlag = GameTooltipStatusBar.TextString:GetFont()
    font = addon:GetFont(font, NumberFontNormal:GetFont())
    flag = NormalizeFontFlag(flag, "THINOUTLINE") or origFlag
    if (font ~= origFont or size ~= origSize or flag ~= origFlag) then
        GameTooltipStatusBar.TextString:SetFont(font or origFont, size or origSize, flag or origFlag)
    end
end)

LibEvent:attachTrigger("tooltip.statusbar.texture", function(self, bgvalue)
    GameTooltipStatusBar:SetStatusBarTexture(addon:GetBarFile(bgvalue))
end)

LibEvent:attachTrigger("tooltip.statusbar.position", function(self, position, offsetX, offsetY)
    LibEvent:trigger("tooltip.style.init", GameTooltip)
    local backdrop = GetStyleBackdrop(GameTooltip) or DEFAULT_TOOLTIP_BACKDROP
    GameTooltipStatusBar:ClearAllPoints()
    if (not GameTooltipStatusBar:IsShown()) then position = "" end
    if (position == "bottom") then
        local edgeSize = tonumber(backdrop.edgeSize) or 14
        local offset = backdrop.edgeFile == "Interface\\Tooltips\\UI-Tooltip-Border" and 5 or edgeSize + 1
        if (not offsetX or offsetX == 0) then offsetX = offset end
        if (not offsetY or offsetY == 0) then offsetY = -offset end
        GameTooltipStatusBar:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", offsetX, 2)
        GameTooltipStatusBar:SetPoint("TOPRIGHT", GameTooltip, "BOTTOMRIGHT", -offsetX, 2)
    elseif (position == "top") then
        local edgeSize = tonumber(backdrop.edgeSize) or 14
        local offset = backdrop.edgeFile == "Interface\\Tooltips\\UI-Tooltip-Border" and 4 or edgeSize
        if (not offsetX or offsetX == 0) then offsetX = offset end
        if (not offsetY or offsetY == 0) then offsetY = offset end
        GameTooltipStatusBar:SetPoint("BOTTOMLEFT", GameTooltip, "TOPLEFT", offsetX, -4)
        GameTooltipStatusBar:SetPoint("BOTTOMRIGHT", GameTooltip, "TOPRIGHT", -offsetX, -4)
    else
        local offset = backdrop.edgeFile == "Interface\\Tooltips\\UI-Tooltip-Border" and 2 or 0
        GameTooltipStatusBar:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", offset, -1)
        GameTooltipStatusBar:SetPoint("TOPRIGHT", GameTooltip, "BOTTOMRIGHT", -offset, -1)
    end
end)

LibEvent:attachTrigger("tooltip.style.init", function(self, tip)
    if (not tip or tip._tinyNativeStyle) then return end
    EnsureNativeStyleData(tip)
    EnsureBackdropSupport(tip)
    tip._tinyNativeStyle = true
    if (tip._tinyMaskEnabled == nil and addon and addon.db and addon.db.general) then
        tip._tinyMaskEnabled = not not addon.db.general.mask
    end
    EnsureStyleMask(tip)
    ApplyBorderCorner(tip, tip._tinyBorderCorner)
    ApplyNativeBackdrop(tip)
    InstallNativeBackdropLocks(tip)

    tip.TinyHookScript = addon.TinyHookScript
    tip:HookScript("OnShow", function(self)
        ApplyNativeBackdrop(self)
        LibEvent:trigger("tooltip:show", self)
    end)
    tip:HookScript("OnHide", function(self) LibEvent:trigger("tooltip:hide", self) end)

    -- for 10.0
    if (tip.ProcessInfo) then
        hooksecurefunc(tip, "ProcessInfo", function(self, info)
            if (not info or not info.tooltipData) then return end
            local flag = info.tooltipData.type
            local guid = info.tooltipData.guid
            local getterName = info.getterName or info.tooltipData.getterName
            local didTypedBackdropUpdate = false
            local function SafeEquals(a, b)
                local ok, res = pcall(function() return a == b end)
                return ok and res
            end
            local function GetTooltipSpellId(tt)
                if (not tt or not tt.GetSpell) then return end
                local ok, _, spellId = pcall(tt.GetSpell, tt)
                if (ok and type(spellId) == "number") then
                    return spellId
                end
            end
            local isAura = SafeEquals(flag, 7)
            if (not isAura and getterName) then
                isAura = getterName == "GetUnitDebuffByAuraInstanceID"
                    or getterName == "GetUnitBuffByAuraInstanceID"
                    or getterName == "GetUnitAuraByAuraInstanceID"
            end
            local isMacro = getterName == "GetMacro"
            --0 物品
            if (SafeEquals(flag, 0)) then
                local link
                if (self.GetItem) then
                    link = select(2, self:GetItem())
                else
                    link = select(2, GetItemInfo(info.tooltipData.id))
                end
                LibEvent:trigger("tooltip:item", self, link)
                didTypedBackdropUpdate = true
            --1 技能
            elseif (SafeEquals(flag, 1)) then
                LibEvent:trigger("tooltip:spell", self, GetTooltipSpellId(self))
                didTypedBackdropUpdate = true
            --2 角色
            elseif (SafeEquals(flag, 2)) then
                if (not self.GetUnit) then return end
                local unit = select(2, self:GetUnit())
                if (unit) then
                    LibEvent:trigger("tooltip:unit", self, unit, guid, flag)
                    didTypedBackdropUpdate = true
                end
            --7 BUFF|DEBUFF
            elseif (isAura) then
                LibEvent:trigger("tooltip:aura", self, info.tooltipData.args)
                didTypedBackdropUpdate = true
            --25 宏命令
            elseif (isMacro) then
                local macroSpellId, macroItemLink
                if (info.tooltipData and type(info.tooltipData.id) == "number") then
                    macroSpellId, macroItemLink = ResolveMacroPayload(self, info.tooltipData.id)
                else
                    macroSpellId, macroItemLink = ResolveMacroPayload(self)
                end
                if (macroItemLink) then
                    LibEvent:trigger("tooltip:item", self, macroItemLink)
                    didTypedBackdropUpdate = true
                elseif (macroSpellId) then
                    LibEvent:trigger("tooltip:spell", self, macroSpellId)
                    didTypedBackdropUpdate = true
                end
            --4 交互体
            --5 货币
            --9 战宠
            --10 坐骑
            --14 装备管理
            --19 玩具
            --21 小地图的点
            --23 任务
            end
            if (not didTypedBackdropUpdate) then
                ReapplyGlobalBackgroundFile(self)
            end
        end)
    end

    tip:TinyHookScript("OnEvent",
        function(self, event, ...)
            LibEvent:trigger("tooltip:event", self, event, ...)
        end
    )
    tip:TinyHookScript("OnTooltipSetUnit",
        function(self)
            local unit = select(2, self:GetUnit())
            if (not unit) then return end
            LibEvent:trigger("tooltip:unit", self, unit)
        end
    )
    tip:TinyHookScript("OnTooltipSetItem",
        function(self)
            local link = select(2, self:GetItem())
            LibEvent:trigger("tooltip:item", self, link)
        end
    )
    tip:TinyHookScript("OnTooltipSetSpell",
        function(self)
            local spellId
            if (self.GetSpell) then
                local ok, _, sid = pcall(self.GetSpell, self)
                if (ok and type(sid) == "number") then
                    spellId = sid
                end
            end
            LibEvent:trigger("tooltip:spell", self, spellId)
        end
    )
    tip:TinyHookScript("OnTooltipCleared",
        function(self)
            LibEvent:trigger("tooltip:cleared", self)
        end
    )

    if (tip == GameTooltip or tip.identity == "diy") then
        if (not tip.BigFactionIcon) then
            tip.BigFactionIcon = tip:CreateTexture(nil, "OVERLAY")
            tip.BigFactionIcon:SetPoint("TOPRIGHT", tip, "TOPRIGHT", 18, 0)
            tip.BigFactionIcon:SetBlendMode("ADD")
            tip.BigFactionIcon:SetScale(0.24)
            tip.BigFactionIcon:SetAlpha(0.40)
        end
        tip:TinyHookScript("OnUpdate",
            function(self, elapsed)
                self.updateElapsed = (self.updateElapsed or 0) + elapsed
                if (self.updateElapsed >= TOOLTIP_UPDATE_TIME) then
                    self.updateElapsed = 0
                    LibEvent:trigger("gametooltip:update", self)
                end
            end
        )
    end
    LibEvent:trigger("tooltip:init", tip)
    for _, v in pairs(addon.tooltips) do
        if (tip == v) then return end
    end
    addon.tooltips[#addon.tooltips+1] = tip
end)

if (SharedTooltip_SetBackdropStyle) then
    hooksecurefunc("SharedTooltip_SetBackdropStyle", function(self, style, embedded)
        if (self and self._tinyNativeStyle) then
            ApplyNativeBackdrop(self)
        end
    end)
end

if (GameTooltip_SetBackdropStyle) then
    hooksecurefunc("GameTooltip_SetBackdropStyle", function(self, style)
        if (self and self._tinyNativeStyle) then
            ApplyNativeBackdrop(self)
        end
    end)
end

LibEvent:attachTrigger("TINYTOOLTIP_GENERAL_INIT", function(self)
    addon._lastScale = addon.db.general.scale
    LibEvent:trigger("tooltip.style.font.header", GameTooltip, addon.db.general.headerFont, addon.db.general.headerFontSize, addon.db.general.headerFontFlag)
    LibEvent:trigger("tooltip.style.font.body", GameTooltip, addon.db.general.bodyFont, addon.db.general.bodyFontSize, addon.db.general.bodyFontFlag)
    LibEvent:trigger("tooltip.statusbar.height", addon.db.general.statusbarHeight)
    LibEvent:trigger("tooltip.statusbar.text", addon.db.general.statusbarText)
    LibEvent:trigger("tooltip.statusbar.visible", addon.db.general.statusbarHide)
    LibEvent:trigger("tooltip.statusbar.font", addon.db.general.statusbarFont, addon.db.general.statusbarFontSize, addon.db.general.statusbarFontFlag)
    LibEvent:trigger("tooltip.statusbar.texture", addon.db.general.statusbarTexture)
    for _, tip in pairs(addon.tooltips) do
        LibEvent:trigger("tooltip.style.init", tip)
        LibEvent:trigger("tooltip.scale", tip, addon.db.general.scale)
        LibEvent:trigger("tooltip.style.mask", tip, addon.db.general.mask)
        LibEvent:trigger("tooltip.style.bgfile", tip, addon.db.general.bgfile)
        LibEvent:trigger("tooltip.style.border.corner", tip, addon.db.general.borderCorner)
        LibEvent:trigger("tooltip.style.border.size", tip, addon.db.general.borderSize)
        LibEvent:trigger("tooltip.style.border.color", tip, unpack(addon.db.general.borderColor))
        LibEvent:trigger("tooltip.style.background", tip, unpack(addon.db.general.background))
    end
end)

hooksecurefunc("GameTooltip_SetDefaultAnchor", function(self, parent)
    LibEvent:trigger("tooltip:anchor", self, parent)
end)

if (GameTooltip and type(GameTooltip.SetAction) == "function") then
    hooksecurefunc(GameTooltip, "SetAction", function(tooltip, slot)
        local spellId, itemLink = ResolveActionPayload(tooltip, slot)
        if (itemLink) then
            LibEvent:trigger("tooltip:item", tooltip, itemLink)
        elseif (spellId) then
            LibEvent:trigger("tooltip:spell", tooltip, spellId)
        end
    end)
end

if (GameTooltip and type(GameTooltip.SetMacro) == "function") then
    hooksecurefunc(GameTooltip, "SetMacro", function(tooltip, macroId)
        local spellId, itemLink = ResolveMacroPayload(tooltip, macroId)
        if (itemLink) then
            LibEvent:trigger("tooltip:item", tooltip, itemLink)
        elseif (spellId) then
            LibEvent:trigger("tooltip:spell", tooltip, spellId)
        end
    end)
end


-- tooltip:init
-- tooltip:anchor
-- tooltip:show
-- tooltip:hide
-- tooltip:unit
-- tooltip:item
-- tooltip:spell
--x tooltip:quest
--x tooltip:cleared
