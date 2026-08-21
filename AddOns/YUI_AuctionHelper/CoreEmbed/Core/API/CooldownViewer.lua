do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...

YUI.API = YUI.API or {}

local CooldownViewer = YUI.API.CooldownViewer or {}
YUI.API.CooldownViewer = CooldownViewer

local CATEGORY_DEFINITIONS = {
    {
        key = "essential",
        enumKey = "Essential",
        required = true,
        display = true,
    },
    {
        key = "utility",
        enumKey = "Utility",
        required = true,
        display = true,
    },
    {
        key = "trackedBuff",
        enumKey = "TrackedBuff",
        required = true,
        display = true,
    },
    {
        key = "trackedBar",
        enumKey = "TrackedBar",
        required = true,
        display = true,
    },
    {
        key = "equipSlotEssential",
        enumKey = "EquipSlotEssential",
    },
    {
        key = "equipSlotTracked",
        enumKey = "EquipSlotTracked",
    },
    {
        key = "specAgnosticEssential",
        enumKey = "SpecAgnosticEssential",
    },
    {
        key = "specAgnosticTracked",
        enumKey = "SpecAgnosticTracked",
    },
}

local SPELL_CATEGORY_PRESENTATION = {
    [4] = {
        kind = "combatPotion",
        icon = "Interface/ICONS/INV_POTION_114",
    },
    [30] = {
        kind = "healthPotion",
        icon = "Interface/ICONS/INV_POTION_54",
    },
    [1711] = {
        kind = "healthstone",
        icon = "Interface/ICONS/Warlock_ Healthstone",
    },
    [2566] = {
        kind = "healthstone",
        icon = "Interface/ICONS/Warlock_ Bloodstone",
    },
}

local RUNTIME_VIEWERS = {
    essential = "EssentialCooldownViewer",
    utility = "UtilityCooldownViewer",
    trackedBuff = "BuffIconCooldownViewer",
    trackedBar = "BuffBarCooldownViewer",
}

local MAX_SUPPORTED_LAYOUT_DATA_VERSION = 5

CooldownViewer.AURA_REFRESH_EVENT =
    CooldownViewer.AURA_REFRESH_EVENT or "YUI_COOLDOWN_VIEWER_AURA_REFRESH"
CooldownViewer.AURA_ACTIVE_STATE_EVENT = CooldownViewer.AURA_ACTIVE_STATE_EVENT
    or "YUI_COOLDOWN_VIEWER_AURA_ACTIVE_STATE"
CooldownViewer.auraRefreshFrames = CooldownViewer.auraRefreshFrames
    or setmetatable({}, { __mode = "k" })
CooldownViewer.auraRefreshNotificationsEnabled =
    CooldownViewer.auraRefreshNotificationsEnabled == true
CooldownViewer.auraRefreshObservedFrames =
    CooldownViewer.auraRefreshObservedFrames
    or setmetatable({}, { __mode = "k" })
CooldownViewer.auraActiveStateObservedFrames =
    CooldownViewer.auraActiveStateObservedFrames
    or setmetatable({}, { __mode = "k" })
CooldownViewer.auraObservedViewers = CooldownViewer.auraObservedViewers
    or setmetatable({}, { __mode = "k" })
CooldownViewer.auraRefreshPendingFrames =
    CooldownViewer.auraRefreshPendingFrames
    or setmetatable({}, { __mode = "k" })
CooldownViewer.auraRefreshPendingIdentities =
    CooldownViewer.auraRefreshPendingIdentities or {}
CooldownViewer.auraRemovedInstances =
    CooldownViewer.auraRemovedInstances or {}
CooldownViewer.auraFullReconciles =
    CooldownViewer.auraFullReconciles or {}
CooldownViewer.auraIdentityByUnit = CooldownViewer.auraIdentityByUnit or {
    player = {},
    target = {},
}
CooldownViewer.auraRefreshViewerHooks =
    CooldownViewer.auraRefreshViewerHooks
    or setmetatable({}, { __mode = "k" })
CooldownViewer.auraRefreshStats = CooldownViewer.auraRefreshStats or {
    frameSignals = 0,
    frameSignalsCoalesced = 0,
    frameRefreshes = 0,
    durationUnavailable = 0,
    removalSignals = 0,
    fullUpdates = 0,
    authoritativeClears = 0,
    transientPreserves = 0,
    activeStateSignals = 0,
}

CooldownViewer.runtimeFrames = CooldownViewer.runtimeFrames or {}
CooldownViewer.auraStackSources = CooldownViewer.auraStackSources or {}
CooldownViewer.auraStackSourceSpecTag =
    CooldownViewer.auraStackSourceSpecTag or nil
CooldownViewer.auraStackSourcesReady =
    CooldownViewer.auraStackSourcesReady == true
for category in pairs(RUNTIME_VIEWERS) do
    CooldownViewer.runtimeFrames[category] =
        CooldownViewer.runtimeFrames[category]
        or setmetatable({}, { __mode = "v" })
end

local function GetSecurity()
    return YUI.API and YUI.API.Security
end

local function IsSecretValue(value)
    local security = GetSecurity()
    if security and security.IsSecretValue then
        return security.IsSecretValue(value) == true
    end
    local checker = _G.issecretvalue
    if not checker then return false end
    local ok, result = pcall(checker, value)
    return ok and result == true
end

local function SafeNumber(value)
    local security = GetSecurity()
    if security and security.SafeNumber then
        return security.SafeNumber(value)
    end
    if value == nil or IsSecretValue(value) then return nil end
    local ok, result = pcall(tonumber, value)
    if ok and not IsSecretValue(result) then return result end
    return nil
end

local function SafeBoolean(value)
    local security = GetSecurity()
    if security and security.SafeBoolean then
        return security.SafeBoolean(value)
    end
    if value == nil or IsSecretValue(value) then return nil end
    if type(value) == "boolean" then return value end
    return nil
end

local function SafeString(value)
    local security = GetSecurity()
    if security and security.SafeString then
        return security.SafeString(value)
    end
    if value == nil or IsSecretValue(value) then return nil end
    if type(value) == "string" then return value end
    return nil
end

local function SafeTable(value)
    if value == nil or IsSecretValue(value) then return nil end
    if type(value) == "table" then return value end
    return nil
end

local function SafeInteger(value)
    value = SafeNumber(value)
    if value and value == math.floor(value) then return value end
    return nil
end

local function SafePositiveInteger(value)
    value = SafeInteger(value)
    if value and value > 0 then return value end
    return nil
end

local function CopyNumberArray(value, positiveOnly)
    value = SafeTable(value)
    if not value then return {} end
    local copy = {}
    local seen = {}
    for index = 1, #value do
        local numberValue
        if positiveOnly then
            numberValue = SafePositiveInteger(value[index])
        else
            numberValue = SafeInteger(value[index])
        end
        if numberValue and not seen[numberValue] then
            seen[numberValue] = true
            copy[#copy + 1] = numberValue
        end
    end
    return copy
end

local function ResolveCategories()
    local enum = _G.Enum
        and _G.Enum.CooldownViewerCategory
    if type(enum) ~= "table" then return nil end

    local ordered = {}
    local sourceById = {}
    local displayById = {}
    for index = 1, #CATEGORY_DEFINITIONS do
        local definition = CATEGORY_DEFINITIONS[index]
        local categoryId = SafeInteger(enum[definition.enumKey])
        if categoryId == nil then
            if definition.required then return nil end
        else
            local resolved = {
                key = definition.key,
                id = categoryId,
                required = definition.required == true,
                display = definition.display == true,
            }
            ordered[#ordered + 1] = resolved
            sourceById[categoryId] = definition.key
            if definition.display then
                displayById[categoryId] = definition.key
            end
        end
    end
    return ordered, sourceById, displayById
end

local function IsFlagSet(flags, flag)
    flags = SafeInteger(flags)
    flag = SafeInteger(flag)
    if flags == nil or flag == nil or flag < 1 then return false end

    local flagsUtil = _G.FlagsUtil
    if type(flagsUtil) == "table"
        and type(flagsUtil.IsSet) == "function" then
        local ok, result = pcall(flagsUtil.IsSet, flags, flag)
        result = ok and SafeBoolean(result) or nil
        if result ~= nil then return result end
    end

    return math.floor(flags / flag) % 2 == 1
end

local function CopyLinkedSpellIDs(value)
    return CopyNumberArray(value, true)
end

local function GetLayoutKey(value)
    local numberValue = SafeInteger(value)
    if numberValue ~= nil then return numberValue end
    return SafeString(value)
end

local function ReadMember(object, key)
    return object[key]
end

local function SafeMethod(object, methodName, ...)
    if object == nil then return false end
    local methodOK, method = pcall(ReadMember, object, methodName)
    if not methodOK or type(method) ~= "function" then return false end
    return pcall(method, object, ...)
end

local function GetFrameCooldownID(frame)
    local ok, cooldownID = SafeMethod(frame, "GetCooldownID")
    cooldownID = ok and SafePositiveInteger(cooldownID) or nil
    if cooldownID then return cooldownID end

    local fieldOK, fieldValue = pcall(ReadMember, frame, "cooldownID")
    return fieldOK and SafePositiveInteger(fieldValue) or nil
end

local AURA_REFRESH_VIEWERS = {
    {
        key = "trackedBuff",
        globalName = "BuffIconCooldownViewer",
    },
    {
        key = "trackedBar",
        globalName = "BuffBarCooldownViewer",
    },
}

local function AddAuraRefreshStat(field, amount)
    local stats = CooldownViewer.auraRefreshStats
    stats[field] = (tonumber(stats[field]) or 0) + (amount or 1)
end

local function GetAuraIdentity(category, cooldownID)
    cooldownID = SafePositiveInteger(cooldownID)
    if (category ~= "trackedBuff" and category ~= "trackedBar")
        or not cooldownID then
        return nil
    end
    return "aura:cdm:" .. tostring(cooldownID)
end

local function HasBoundAuraState(state)
    return type(state) == "table"
        and state.durationMode == "aura"
        and state.cooldownActive == true
        and state.available == true
end

local FlushAuraFrameRefreshesCallback

function CooldownViewer:UntrackAuraState(state, identity)
    local unit = state and state.viewerAuraUnit
    local instanceID = state and state.viewerAuraInstanceID
    local unitMap = unit and self.auraIdentityByUnit[unit]
    if unitMap and instanceID and unitMap[instanceID] == identity then
        unitMap[instanceID] = nil
    end
end

function CooldownViewer:TrackAuraState(state, identity, unit, instanceID)
    self:UntrackAuraState(state, identity)
    local unitMap = unit and self.auraIdentityByUnit[unit]
    instanceID = SafePositiveInteger(instanceID)
    if unitMap and instanceID then unitMap[instanceID] = identity end
end

function CooldownViewer:QueryAuraInstance(unit, auraInstanceID)
    unit = SafeString(unit)
    auraInstanceID = SafePositiveInteger(auraInstanceID)
    local auraAPI = _G.C_UnitAuras
    if (unit ~= "player" and unit ~= "target") or not auraInstanceID
        or type(auraAPI) ~= "table"
        or type(auraAPI.GetAuraDataByAuraInstanceID) ~= "function" then
        return nil
    end
    local ok, aura = pcall(
        auraAPI.GetAuraDataByAuraInstanceID,
        unit,
        auraInstanceID
    )
    if not ok or IsSecretValue(aura) then return nil end
    return aura ~= nil
end

function CooldownViewer:GetAuraLifecycleEvidence(identity, state)
    if not identity then return nil end
    local removedInstanceID = self.auraRemovedInstances[identity]
    local fullUnit = self.auraFullReconciles[identity]
    self.auraRemovedInstances[identity] = nil
    self.auraFullReconciles[identity] = nil

    if removedInstanceID
        and state.viewerAuraUnit ~= nil
        and state.viewerAuraInstanceID == removedInstanceID then
        return false, "removed-instance"
    end
    if fullUnit and state.viewerAuraUnit == fullUnit
        and state.viewerAuraInstanceID ~= nil then
        local exists = self:QueryAuraInstance(
            fullUnit,
            state.viewerAuraInstanceID
        )
        if exists ~= nil then
            return exists, exists and "full-update-present"
                or "full-update-removed"
        end
    end
    return nil
end

function CooldownViewer:QueueAuraIdentityRefresh(identity)
    if self.auraRefreshNotificationsEnabled ~= true or not identity then
        return false
    end
    self.auraRefreshPendingIdentities[identity] = true
    if self.auraRefreshTimer then return true end
    if _G.C_Timer and type(_G.C_Timer.NewTimer) == "function" then
        self.auraRefreshTimer = _G.C_Timer.NewTimer(
            0,
            FlushAuraFrameRefreshesCallback
        )
        return true
    end
    return self:FlushAuraFrameRefreshes()
end

local function QueueFullAuraUnitRefresh(self, unitMap, unit)
    AddAuraRefreshStat("fullUpdates")
    for _, identity in pairs(unitMap) do
        self.auraFullReconciles[identity] = unit
        self:QueueAuraIdentityRefresh(identity)
    end
end

function CooldownViewer:OnUnitAura(_, unit, updateInfo)
    local unitMap = self.auraIdentityByUnit[unit]
    if not unitMap then return end
    if IsSecretValue(updateInfo) then
        QueueFullAuraUnitRefresh(self, unitMap, unit)
        return
    end
    updateInfo = SafeTable(updateInfo)
    if not updateInfo then return end

    local fullOK, fullValue = pcall(ReadMember, updateInfo, "isFullUpdate")
    if not fullOK or IsSecretValue(fullValue) then
        QueueFullAuraUnitRefresh(self, unitMap, unit)
        return
    end
    if SafeBoolean(fullValue) == true then
        QueueFullAuraUnitRefresh(self, unitMap, unit)
        return
    end

    local removedOK, removedValue = pcall(
        ReadMember,
        updateInfo,
        "removedAuraInstanceIDs"
    )
    if not removedOK or IsSecretValue(removedValue) then
        QueueFullAuraUnitRefresh(self, unitMap, unit)
        return
    end
    local removed = SafeTable(removedValue)
    if not removed then
        return
    end
    for index = 1, #removed do
        local instanceID = SafePositiveInteger(removed[index])
        local identity = instanceID and unitMap[instanceID]
        if identity then
            AddAuraRefreshStat("removalSignals")
            self.auraRemovedInstances[identity] = instanceID
            self:QueueAuraIdentityRefresh(identity)
        end
    end
end

function CooldownViewer:GetAuraRefreshRevision(frame)
    local state = frame and self.auraRefreshFrames[frame]
    return state and state.revision or nil
end

function CooldownViewer:OnAuraFrameRefreshed(category, frame)
    if self.auraRefreshNotificationsEnabled ~= true or not frame then return end
    local cooldownID = GetFrameCooldownID(frame)
    local identity = GetAuraIdentity(category, cooldownID)
    local refresh = self.auraRefreshFrames[frame]
    if not refresh then
        refresh = { revision = 0 }
        self.auraRefreshFrames[frame] = refresh
    end
    local previousIdentity = refresh.identity
    local previousCooldownID = refresh.cooldownID
    refresh.revision = refresh.revision + 1
    refresh.identity = identity
    refresh.cooldownID = cooldownID
    local cache = self.runtimeFrames[category]
    if cache then
        if previousCooldownID and previousCooldownID ~= cooldownID
            and cache[previousCooldownID] == frame then
            cache[previousCooldownID] = nil
        end
        if cooldownID then cache[cooldownID] = frame end
    end
    if YUI.Event and YUI.Event.Emit then
        if identity then self.auraRefreshPendingIdentities[identity] = nil end
        if previousIdentity then
            self.auraRefreshPendingIdentities[previousIdentity] = nil
        end
        YUI.Event:Emit(
            self.AURA_REFRESH_EVENT,
            identity,
            previousIdentity ~= identity and previousIdentity or nil,
            frame,
            category,
            cooldownID
        )
    end
end

function CooldownViewer:FlushAuraFrameRefreshes()
    self.auraRefreshTimer = nil
    if self.auraRefreshNotificationsEnabled ~= true then
        for frame in pairs(self.auraRefreshPendingFrames) do
            self.auraRefreshPendingFrames[frame] = nil
        end
        for identity in pairs(self.auraRefreshPendingIdentities) do
            self.auraRefreshPendingIdentities[identity] = nil
        end
        return false
    end
    local refreshed = false
    for frame in pairs(self.auraRefreshPendingFrames) do
        self.auraRefreshPendingFrames[frame] = nil
        local category = self.auraRefreshObservedFrames[frame]
        if category then
            AddAuraRefreshStat("frameRefreshes")
            self:OnAuraFrameRefreshed(category, frame)
            refreshed = true
        end
    end
    if YUI.Event and YUI.Event.Emit then
        for identity in pairs(self.auraRefreshPendingIdentities) do
            self.auraRefreshPendingIdentities[identity] = nil
            YUI.Event:Emit(self.AURA_REFRESH_EVENT, identity)
            refreshed = true
        end
    end
    return refreshed
end

FlushAuraFrameRefreshesCallback = function()
    CooldownViewer:FlushAuraFrameRefreshes()
end

function CooldownViewer:QueueAuraFrameRefresh(frame)
    if self.auraRefreshNotificationsEnabled ~= true or not frame then
        return false
    end
    AddAuraRefreshStat("frameSignals")
    if self.auraRefreshPendingFrames[frame] then
        AddAuraRefreshStat("frameSignalsCoalesced")
    else
        self.auraRefreshPendingFrames[frame] = true
    end
    if self.auraRefreshTimer then return true end
    if _G.C_Timer and type(_G.C_Timer.NewTimer) == "function" then
        self.auraRefreshTimer = _G.C_Timer.NewTimer(
            0,
            FlushAuraFrameRefreshesCallback
        )
        return true
    end
    return self:FlushAuraFrameRefreshes()
end

local function OnObservedAuraFrameRefresh(frame)
    CooldownViewer:QueueAuraFrameRefresh(frame)
end

function CooldownViewer:OnAuraFrameActiveStateChanged(frame)
    if self.auraRefreshNotificationsEnabled ~= true or not frame then
        return false
    end
    local category = self.auraActiveStateObservedFrames[frame]
    if category ~= "trackedBuff" then return false end
    local viewer = self.auraObservedViewers[frame]
    if not viewer or viewer ~= _G[RUNTIME_VIEWERS[category]] then
        return false
    end
    local cooldownID = GetFrameCooldownID(frame)
    local identity = GetAuraIdentity(category, cooldownID)
    if not identity then return false end
    AddAuraRefreshStat("activeStateSignals")
    if YUI.Event and YUI.Event.Emit then
        YUI.Event:Emit(
            self.AURA_ACTIVE_STATE_EVENT,
            identity,
            frame,
            category,
            cooldownID,
            viewer
        )
    end
    self:QueueAuraFrameRefresh(frame)
    return true
end

local function OnObservedAuraFrameActiveStateChanged(frame)
    CooldownViewer:OnAuraFrameActiveStateChanged(frame)
end

function CooldownViewer:ObserveAuraFrame(category, frame, viewer)
    if self.auraRefreshNotificationsEnabled ~= true
        or (category ~= "trackedBuff" and category ~= "trackedBar")
        or not frame then
        return false
    end
    local hook = _G.hooksecurefunc
    if type(hook) ~= "function" then return false end
    if viewer then self.auraObservedViewers[frame] = viewer end

    local refreshObserved = self.auraRefreshObservedFrames[frame] == category
    if not refreshObserved then
        local methodOK, method = pcall(ReadMember, frame, "RefreshData")
        if methodOK and type(method) == "function" then
            local ok = pcall(
                hook,
                frame,
                "RefreshData",
                OnObservedAuraFrameRefresh
            )
            if ok then
                self.auraRefreshObservedFrames[frame] = category
                refreshObserved = true
            end
        end
    end

    local activeStateObserved = category ~= "trackedBuff"
        or self.auraActiveStateObservedFrames[frame] == category
    if category == "trackedBuff" and not activeStateObserved then
        local methodOK, method = pcall(
            ReadMember,
            frame,
            "OnActiveStateChanged"
        )
        if methodOK and type(method) == "function" then
            local ok = pcall(
                hook,
                frame,
                "OnActiveStateChanged",
                OnObservedAuraFrameActiveStateChanged
            )
            if ok then
                self.auraActiveStateObservedFrames[frame] = category
                activeStateObserved = true
            end
        end
    end
    return refreshObserved and activeStateObserved
end

local function OnTrackedBuffFrameAcquired(viewer, frame)
    CooldownViewer:ObserveAuraFrame("trackedBuff", frame, viewer)
end

local function OnTrackedBarFrameAcquired(viewer, frame)
    CooldownViewer:ObserveAuraFrame("trackedBar", frame, viewer)
end

local AURA_ACQUIRE_CALLBACKS = {
    trackedBuff = OnTrackedBuffFrameAcquired,
    trackedBar = OnTrackedBarFrameAcquired,
}

function CooldownViewer:ObserveAuraViewer(category, viewer)
    if not viewer then return false end
    local observed = false
    local pool = viewer.itemFramePool
    if pool and type(pool.EnumerateActive) == "function" then
        local ok = pcall(function()
            for frame in pool:EnumerateActive() do
                observed = self:ObserveAuraFrame(category, frame, viewer)
                    or observed
            end
        end)
        if not ok then observed = false end
    end

    if self.auraRefreshViewerHooks[viewer] ~= category then
        local hook = _G.hooksecurefunc
        local callback = AURA_ACQUIRE_CALLBACKS[category]
        local methodOK, method = pcall(ReadMember, viewer, "OnAcquireItemFrame")
        if type(hook) == "function" and callback
            and methodOK and type(method) == "function" then
            local ok = pcall(
                hook,
                viewer,
                "OnAcquireItemFrame",
                callback
            )
            if ok then self.auraRefreshViewerHooks[viewer] = category end
        end
    end
    return observed or self.auraRefreshViewerHooks[viewer] == category
end

function CooldownViewer:CancelAuraRefreshLoadListener()
    if self.auraRefreshLoadListener and YUI.Event and YUI.Event.Off then
        YUI.Event:Off(self.auraRefreshLoadListener)
    end
    self.auraRefreshLoadListener = nil
end

function CooldownViewer:CancelAuraUnitListener()
    if self.auraUnitListener and YUI.Event and YUI.Event.Off then
        YUI.Event:Off(self.auraUnitListener)
    end
    self.auraUnitListener = nil
end

function CooldownViewer:InstallAuraRefreshHooks()
    if YUI.IsRetail == false then return false, "unsupported-client" end
    local installedAll = true
    for index = 1, #AURA_REFRESH_VIEWERS do
        local definition = AURA_REFRESH_VIEWERS[index]
        local viewer = _G[definition.globalName]
        if not self:ObserveAuraViewer(definition.key, viewer) then
            installedAll = false
        end
    end
    if installedAll then
        self:CancelAuraRefreshLoadListener()
        return true
    end
    return false, "viewer-unavailable"
end

function CooldownViewer:OnAuraRefreshAddonLoaded(_, addonName)
    if addonName ~= "Blizzard_CooldownViewer" then return end
    local installed = self:InstallAuraRefreshHooks()
    if installed and self.auraRefreshNotificationsEnabled == true
        and YUI.Event and YUI.Event.Emit then
        YUI.Event:Emit(self.AURA_REFRESH_EVENT)
    end
end

function CooldownViewer:SetAuraRefreshNotificationsEnabled(enabled)
    self.auraRefreshNotificationsEnabled = enabled == true
    if not self.auraRefreshNotificationsEnabled then
        if self.auraRefreshTimer and self.auraRefreshTimer.Cancel then
            self.auraRefreshTimer:Cancel()
        end
        self.auraRefreshTimer = nil
        for frame in pairs(self.auraRefreshPendingFrames) do
            self.auraRefreshPendingFrames[frame] = nil
        end
        for identity in pairs(self.auraRefreshPendingIdentities) do
            self.auraRefreshPendingIdentities[identity] = nil
        end
        for identity in pairs(self.auraRemovedInstances) do
            self.auraRemovedInstances[identity] = nil
        end
        for identity in pairs(self.auraFullReconciles) do
            self.auraFullReconciles[identity] = nil
        end
        for _, unitMap in pairs(self.auraIdentityByUnit) do
            for instanceID in pairs(unitMap) do unitMap[instanceID] = nil end
        end
        self:CancelAuraUnitListener()
        self:CancelAuraRefreshLoadListener()
        return true
    end
    if not self.auraUnitListener and YUI.Event and YUI.Event.On then
        self.auraUnitListener = YUI.Event:On(
            "UNIT_AURA",
            "OnUnitAura",
            self,
            {
                units = { "player", "target" },
                moduleId = "YUI.API.CooldownViewer",
            }
        )
    end
    local installed, code = self:InstallAuraRefreshHooks()
    if installed then return true end
    if not self.auraRefreshLoadListener and YUI.Event and YUI.Event.On then
        self.auraRefreshLoadListener = YUI.Event:On(
            "ADDON_LOADED",
            "OnAuraRefreshAddonLoaded",
            self,
            { moduleId = "YUI.API.CooldownViewer" }
        )
    end
    return false, code
end

local function FindFrameInArray(frames, cooldownID)
    if type(frames) ~= "table" then return nil end
    for index = 1, #frames do
        local frame = frames[index]
        if GetFrameCooldownID(frame) == cooldownID then return frame end
    end
    return nil
end

local function FindRuntimeFrame(viewer, cooldownID)
    if not viewer then return nil end
    local pool = viewer.itemFramePool
    if pool and type(pool.EnumerateActive) == "function" then
        for frame in pool:EnumerateActive() do
            if GetFrameCooldownID(frame) == cooldownID then return frame end
        end
    end

    local ok, container = SafeMethod(viewer, "GetItemContainerFrame")
    if ok and container then
        local layoutOK, frames = SafeMethod(container, "GetLayoutChildren")
        if layoutOK then
            local frame = FindFrameInArray(frames, cooldownID)
            if frame then return frame end
        end
    end

    local layoutOK, frames = SafeMethod(viewer, "GetLayoutChildren")
    if layoutOK then return FindFrameInArray(frames, cooldownID) end
    return nil
end

local function GetCachedRuntimeFrame(self, category, cooldownID)
    local globalName = RUNTIME_VIEWERS[category]
    cooldownID = SafePositiveInteger(cooldownID)
    if not globalName or not cooldownID then return nil end

    local cache = self.runtimeFrames[category]
    local cached = cache and cache[cooldownID]
    if cached then
        local cachedID = GetFrameCooldownID(cached)
        if cachedID == cooldownID then
            self:ObserveAuraFrame(category, cached)
            return cached
        end
        local combatOK, inCombat = pcall(_G.InCombatLockdown or function()
            return false
        end)
        inCombat = combatOK and SafeBoolean(inCombat) or false
        if cachedID == nil and inCombat == true then
            self:ObserveAuraFrame(category, cached)
            return cached
        end
        cache[cooldownID] = nil
    end
    return nil
end

function CooldownViewer:GetRuntimeFrame(category, cooldownID)
    local globalName = RUNTIME_VIEWERS[category]
    cooldownID = SafePositiveInteger(cooldownID)
    if not globalName or not cooldownID then return nil end

    local cached = GetCachedRuntimeFrame(self, category, cooldownID)
    if cached then return cached end

    local frame = FindRuntimeFrame(_G[globalName], cooldownID)
    local cache = self.runtimeFrames[category]
    if frame and cache then cache[cooldownID] = frame end
    if frame then self:ObserveAuraFrame(category, frame) end
    return frame
end

local function PreserveOrHideAuraState(
    adapter,
    state,
    identity,
    lifecycleExists,
    code
)
    if lifecycleExists == false and HasBoundAuraState(state) then
        adapter:UntrackAuraState(state, identity)
        AddAuraRefreshStat("authoritativeClears")
        local changed = state.cooldownActive ~= false
            or state.durationMode ~= "none"
            or state.available ~= false
            or state.secret ~= false
            or state.durationObject ~= nil
            or state.viewerAuraInstanceID ~= nil
        state.sourceKind = "aura"
        state.cooldownActive = false
        state.chargeActive = false
        state.durationMode = "none"
        state.durationObject = nil
        state.viewerAuraInstanceID = nil
        state.startTime = 0
        state.duration = 0
        state.modRate = 1
        state.displayCount = nil
        state.available = false
        state.isEnabled = true
        state.secret = false
        state.opaqueRevision = (tonumber(state.opaqueRevision) or 0) + 1
        return state, changed, code
    end
    if HasBoundAuraState(state) then
        AddAuraRefreshStat("transientPreserves")
        return state, false, code
    end
    return nil, false, code
end

function CooldownViewer:ReadAuraDisplay(category, cooldownID, state)
    state = type(state) == "table" and state or {}
    if YUI.IsRetail == false then return nil, false, "unsupported-client" end

    local identity = GetAuraIdentity(category, cooldownID)
    local lifecycleExists, lifecycleCode =
        self:GetAuraLifecycleEvidence(identity, state)

    local frame = self:GetRuntimeFrame(category, cooldownID)
    if not frame then
        return PreserveOrHideAuraState(
            self,
            state,
            identity,
            lifecycleExists,
            lifecycleCode or "frame-unavailable"
        )
    end

    local unitOK, unitValue = SafeMethod(frame, "GetAuraDataUnit")
    local viewerAuraUnit = unitOK and SafeString(unitValue) or nil
    if viewerAuraUnit ~= "player" and viewerAuraUnit ~= "target" then
        return PreserveOrHideAuraState(
            self,
            state,
            identity,
            lifecycleExists,
            lifecycleCode or "unit-unavailable"
        )
    end

    local activeOK, activeValue = SafeMethod(frame, "IsActive")
    local active
    if activeOK then active = SafeBoolean(activeValue) end
    if active == nil then
        return PreserveOrHideAuraState(
            self,
            state,
            identity,
            lifecycleExists,
            lifecycleCode or "active-unavailable"
        )
    end

    local durationObject
    local auraInstanceID
    local safeAuraInstanceID
    local detailCode
    if active then
        local instanceOK, instanceValue =
            SafeMethod(frame, "GetAuraSpellInstanceID")
        if instanceOK and instanceValue ~= nil then
            auraInstanceID = instanceValue
            safeAuraInstanceID = SafePositiveInteger(instanceValue)
            local auraAPI = _G.C_UnitAuras
            if type(auraAPI) ~= "table"
                or type(auraAPI.GetAuraDuration) ~= "function" then
                detailCode = "duration-api-unavailable"
            else
                local durationOK, value = pcall(
                    auraAPI.GetAuraDuration,
                    viewerAuraUnit,
                    auraInstanceID
                )
                if durationOK and value ~= nil then
                    durationObject = value
                else
                    detailCode = "duration-unavailable"
                end
            end
        else
            detailCode = "instance-unavailable"
        end
    end

    if active and durationObject == nil then
        AddAuraRefreshStat("durationUnavailable")
        if lifecycleExists == false or HasBoundAuraState(state) then
            return PreserveOrHideAuraState(
                self,
                state,
                identity,
                lifecycleExists,
                lifecycleCode or detailCode or "duration-unavailable"
            )
        end
    end

    if not active and HasBoundAuraState(state) then
        return PreserveOrHideAuraState(
            self,
            state,
            identity,
            lifecycleExists,
            lifecycleCode or "inactive-unconfirmed"
        )
    end

    local previousViewerAuraUnit = state.viewerAuraUnit
    local previousActive = state.cooldownActive == true
    local instanceChanged = safeAuraInstanceID ~= nil
        and safeAuraInstanceID ~= state.viewerAuraInstanceID
    local unitChanged = previousViewerAuraUnit ~= viewerAuraUnit
    local frameRevision = self:GetAuraRefreshRevision(frame)
    local refreshChanged = frameRevision ~= nil
        and frameRevision ~= state.viewerAuraRefreshRevision
    local opaqueRevision = tonumber(state.opaqueRevision) or 0
    if previousActive ~= active or instanceChanged or unitChanged
        or refreshChanged then
        opaqueRevision = opaqueRevision + 1
    end
    local durationMode = durationObject ~= nil and "aura" or "none"
    local changed = state.sourceKind ~= "aura"
        or state.cooldownActive ~= active
        or state.chargeActive ~= false
        or state.durationMode ~= durationMode
        or state.opaqueRevision ~= opaqueRevision
        or state.viewerAuraInstanceID ~= safeAuraInstanceID
        or state.viewerAuraRefreshRevision ~= frameRevision
        or unitChanged
        or state.startTime ~= 0
        or state.duration ~= 0
        or state.modRate ~= 1
        or state.displayCount ~= nil
        or state.available ~= active
        or state.isEnabled ~= true
        or state.secret ~= (durationObject ~= nil)

    self:TrackAuraState(
        state,
        identity,
        viewerAuraUnit,
        safeAuraInstanceID
    )
    state.sourceKind = "aura"
    state.cooldownActive = active
    state.chargeActive = false
    state.durationMode = durationMode
    state.durationObject = durationObject
    state.opaqueRevision = opaqueRevision
    state.viewerAuraInstanceID = safeAuraInstanceID
    state.viewerAuraRefreshRevision = frameRevision
    state.viewerAuraUnit = viewerAuraUnit
    state.startTime = 0
    state.duration = 0
    state.modRate = 1
    state.displayCount = nil
    state.available = active
    state.isEnabled = true
    state.secret = durationObject ~= nil
    return state, changed, detailCode
end

function CooldownViewer:GetAuraRefreshStats(target)
    target = target or {}
    for field, value in pairs(self.auraRefreshStats) do
        target[field] = tonumber(value) or 0
    end
    local pending = 0
    for _ in pairs(self.auraRefreshPendingFrames) do pending = pending + 1 end
    target.pendingFrames = pending
    local pendingIdentities = 0
    for _ in pairs(self.auraRefreshPendingIdentities) do
        pendingIdentities = pendingIdentities + 1
    end
    target.pendingIdentities = pendingIdentities
    return target
end

function CooldownViewer:ResetAuraRefreshStats()
    for field in pairs(self.auraRefreshStats) do
        self.auraRefreshStats[field] = 0
    end
end

function CooldownViewer:IsAvailable()
    if YUI.IsRetail == false then
        return false, "unsupported-client"
    end

    local api = _G.C_CooldownViewer
    if type(api) ~= "table"
        or type(api.GetCooldownViewerCategorySet) ~= "function"
        or type(api.GetCooldownViewerCooldownInfo) ~= "function"
        or type(api.GetLayoutData) ~= "function" then
        return false, "api-unavailable"
    end

    if type(api.IsCooldownViewerAvailable) ~= "function" then
        return true
    end

    local ok, available, failureReason =
        pcall(api.IsCooldownViewerAvailable)
    if ok then
        available = SafeBoolean(available)
    else
        available = nil
    end
    if available == true then return true end
    if not ok then return false, "availability-call-failed" end
    if available == nil then return false, "availability-secret" end
    return false, SafeString(failureReason) or "unavailable"
end

function CooldownViewer:GetCurrentSpecTag()
    local unitClass = _G.UnitClass
    local specializationAPI = _G.C_SpecializationInfo
    if type(unitClass) ~= "function"
        or type(specializationAPI) ~= "table"
        or type(specializationAPI.GetSpecialization) ~= "function" then
        return nil
    end

    local classOK, _, _, classID = pcall(unitClass, "player")
    local specOK, specIndex =
        pcall(specializationAPI.GetSpecialization)
    classID = classOK and SafePositiveInteger(classID) or nil
    specIndex = specOK and SafePositiveInteger(specIndex) or nil
    if not classID or not specIndex then return nil end
    return classID * 10 + specIndex
end

function CooldownViewer:GetLayoutSignature()
    local available, reason = self:IsAvailable()
    if not available then return nil, reason end

    local api = _G.C_CooldownViewer
    local ok, serializedLayout = pcall(api.GetLayoutData)
    serializedLayout = ok and SafeString(serializedLayout) or nil
    if not serializedLayout then return nil, "layout-read-failed" end
    return serializedLayout
end

function CooldownViewer:DecodeLayoutData(serializedData, specTag)
    serializedData = SafeString(serializedData)
    if not serializedData or serializedData == "" then
        return {
            hasCustomLayout = false,
            specTag = SafePositiveInteger(specTag),
            orderedCooldownIDs = {},
            categoryByCooldownID = {},
        }
    end

    local delimiterIndex = string.find(serializedData, "|", 1, true)
    if not delimiterIndex then return nil, "layout-version-missing" end

    local encodingVersion = SafePositiveInteger(
        string.sub(serializedData, 1, delimiterIndex - 1)
    )
    if encodingVersion ~= 1 then
        return nil, "layout-encoding-unsupported"
    end

    local encoding = _G.C_EncodingUtil
    local compression = _G.Enum and _G.Enum.CompressionMethod
    local deflate = compression
        and SafeInteger(compression.Deflate)
    if type(encoding) ~= "table"
        or type(encoding.DecodeBase64) ~= "function"
        or type(encoding.DecompressString) ~= "function"
        or type(encoding.DeserializeCBOR) ~= "function"
        or deflate == nil then
        return nil, "layout-decoder-unavailable"
    end

    local payload = string.sub(serializedData, delimiterIndex + 1)
    local ok, decoded = pcall(encoding.DecodeBase64, payload)
    decoded = ok and SafeString(decoded) or nil
    if not decoded then return nil, "layout-base64-invalid" end

    ok, decoded = pcall(
        encoding.DecompressString,
        decoded,
        deflate
    )
    decoded = ok and SafeString(decoded) or nil
    if not decoded then return nil, "layout-compression-invalid" end

    local data
    ok, data = pcall(encoding.DeserializeCBOR, decoded)
    data = ok and SafeTable(data) or nil
    if not data then return nil, "layout-payload-invalid" end

    local dataVersion = SafePositiveInteger(data[1])
    if not dataVersion
        or dataVersion > MAX_SUPPORTED_LAYOUT_DATA_VERSION then
        return nil, "layout-data-unsupported"
    end

    specTag = SafePositiveInteger(specTag)
    local result = {
        encodingVersion = encodingVersion,
        dataVersion = dataVersion,
        hasCustomLayout = false,
        specTag = specTag,
        orderedCooldownIDs = {},
        categoryByCooldownID = {},
    }
    if not specTag or dataVersion == 1 then return result end

    local activeLayouts = SafeTable(data[2])
    local layouts = SafeTable(data[3])
    if not activeLayouts or not layouts then return result end

    local layoutKey = GetLayoutKey(activeLayouts[specTag])
    if layoutKey == nil then return result end
    local specLayouts = SafeTable(layouts[specTag])
    local layout = specLayouts and SafeTable(specLayouts[layoutKey])
    if not layout then
        result.activeLayoutId = layoutKey
        result.activeLayoutStored = false
        return result
    end

    result.hasCustomLayout = true
    result.activeLayoutId = layoutKey
    result.activeLayoutStored = true
    result.orderedCooldownIDs = CopyNumberArray(layout[1], true)

    local categoryOverrides = SafeTable(layout[2])
    if categoryOverrides then
        for rawCategoryId, rawCooldownIDs in pairs(categoryOverrides) do
            local categoryId = SafeInteger(rawCategoryId)
            if categoryId ~= nil then
                local cooldownIDs =
                    CopyNumberArray(rawCooldownIDs, true)
                for index = 1, #cooldownIDs do
                    result.categoryByCooldownID[cooldownIDs[index]] =
                        categoryId
                end
            end
        end
    end
    return result
end

local function ReadCooldownInfo(api, cooldownID, defaultCategoryId)
    local ok, info = pcall(
        api.GetCooldownViewerCooldownInfo,
        cooldownID
    )
    info = ok and SafeTable(info) or nil
    if not info then return nil end
    local spellCategoryID = SafePositiveInteger(info.spellCategoryID)
    local presentation = SPELL_CATEGORY_PRESENTATION[spellCategoryID]

    return {
        cooldownID = SafePositiveInteger(info.cooldownID)
            or cooldownID,
        spellID = SafePositiveInteger(info.spellID),
        spellCategoryID = spellCategoryID,
        overrideSpellID =
            SafePositiveInteger(info.overrideSpellID),
        overrideTooltipSpellID =
            SafePositiveInteger(info.overrideTooltipSpellID),
        equipSlot = SafePositiveInteger(info.equipSlot),
        buffSlot = SafePositiveInteger(info.buffSlot),
        linkedSpellIDs = CopyLinkedSpellIDs(info.linkedSpellIDs),
        selfAura = SafeBoolean(info.selfAura),
        hasAura = SafeBoolean(info.hasAura),
        charges = SafeBoolean(info.charges),
        isKnown = SafeBoolean(info.isKnown),
        isInvisible = SafeBoolean(info.isInvisible),
        flags = SafeInteger(info.flags),
        sourceCategoryId =
            SafeInteger(info.category) or defaultCategoryId,
        presentationKind = presentation and presentation.kind or nil,
        presentationIcon = presentation and presentation.icon or nil,
    }
end

function CooldownViewer:ReadEntries(options)
    options = type(options) == "table" and options or {}
    local available, reason = self:IsAvailable()
    if not available then return nil, reason end

    local categories, sourceCategoryById, displayCategoryById =
        ResolveCategories()
    if not categories then return nil, "category-enum-unavailable" end

    local api = _G.C_CooldownViewer
    local allowUnlearned = options.allowUnlearned ~= false
    local includeHidden = options.includeHidden == true
    local infoById = {}
    local defaultOrder = {}
    local skipped = 0
    local skippedSources = 0

    local hideFlag = _G.Enum
        and _G.Enum.CooldownSetSpellFlags
        and _G.Enum.CooldownSetSpellFlags.HideByDefault
    local hideAuraFlag = _G.Enum
        and _G.Enum.CooldownSetSpellFlags
        and _G.Enum.CooldownSetSpellFlags.HideAura

    for categoryIndex = 1, #categories do
        local category = categories[categoryIndex]
        local ok, cooldownIDs = pcall(
            api.GetCooldownViewerCategorySet,
            category.id,
            allowUnlearned
        )
        cooldownIDs = ok and SafeTable(cooldownIDs) or nil
        if not cooldownIDs then
            if category.required then
                return nil, "category-read-failed:" .. category.key
            end
            skippedSources = skippedSources + 1
        else
            for index = 1, #cooldownIDs do
                local cooldownID =
                    SafePositiveInteger(cooldownIDs[index])
                if cooldownID and not infoById[cooldownID] then
                    local info = ReadCooldownInfo(
                        api,
                        cooldownID,
                        category.id
                    )
                    if info then
                        info.hiddenByDefault =
                            IsFlagSet(info.flags, hideFlag)
                        info.canUseAuraForCooldown = true
                        if hideAuraFlag ~= nil and info.flags ~= nil then
                            info.canUseAuraForCooldown =
                                not IsFlagSet(info.flags, hideAuraFlag)
                        end
                        infoById[cooldownID] = info
                        defaultOrder[#defaultOrder + 1] = cooldownID
                    else
                        skipped = skipped + 1
                    end
                elseif not cooldownID then
                    skipped = skipped + 1
                end
            end
        end
    end

    local specTag = self:GetCurrentSpecTag()
    local ok, serializedLayout = pcall(api.GetLayoutData)
    serializedLayout = ok and SafeString(serializedLayout) or nil
    if not ok or serializedLayout == nil then
        return nil, "layout-read-failed"
    end

    local layout, layoutCode =
        self:DecodeLayoutData(serializedLayout, specTag)
    if not layout then
        return nil, "layout-decode-failed:" .. tostring(layoutCode)
    end

    local effectiveOrder = {}
    local ordered = {}
    if layout.hasCustomLayout then
        for index = 1, #layout.orderedCooldownIDs do
            local cooldownID = layout.orderedCooldownIDs[index]
            if infoById[cooldownID] and not ordered[cooldownID] then
                ordered[cooldownID] = true
                effectiveOrder[#effectiveOrder + 1] = cooldownID
            end
        end
    end
    for index = 1, #defaultOrder do
        local cooldownID = defaultOrder[index]
        if not ordered[cooldownID] then
            ordered[cooldownID] = true
            effectiveOrder[#effectiveOrder + 1] = cooldownID
        end
    end

    local entries = {}
    local categoryCounts = {}
    local sourceCategoryCounts = {}
    local categoryOrder = {}
    local hidden = 0
    local metadataOnly = 0
    for index = 1, #effectiveOrder do
        local cooldownID = effectiveOrder[index]
        local info = infoById[cooldownID]
        local overrideCategory =
            layout.categoryByCooldownID[cooldownID]
        local sourceCategoryId = info.sourceCategoryId
        local sourceCategory = sourceCategoryById[sourceCategoryId]
        local effectiveCategoryId = overrideCategory
            or sourceCategoryId
        local displayCategory = displayCategoryById[effectiveCategoryId]
        local sourceIsDisplay =
            displayCategoryById[sourceCategoryId] ~= nil
        local isMetadataOnly = displayCategory == nil
            and sourceCategory ~= nil
            and not sourceIsDisplay
        local isHidden = sourceCategory == nil
            or (displayCategory == nil and not isMetadataOnly)
            or (displayCategory ~= nil
                and not includeHidden
                and overrideCategory == nil
                and info.hiddenByDefault)
            or (not allowUnlearned and info.isKnown == false)

        if isHidden then
            hidden = hidden + 1
        else
            sourceCategoryCounts[sourceCategory] =
                (sourceCategoryCounts[sourceCategory] or 0) + 1
            local displayOrder
            if displayCategory then
                categoryOrder[displayCategory] =
                    (categoryOrder[displayCategory] or 0) + 1
                displayOrder = categoryOrder[displayCategory]
                categoryCounts[displayCategory] =
                    (categoryCounts[displayCategory] or 0) + 1
            else
                metadataOnly = metadataOnly + 1
            end
            entries[#entries + 1] = {
                category = displayCategory,
                categoryID = displayCategory and effectiveCategoryId or nil,
                sourceCategory = sourceCategory,
                sourceCategoryID = sourceCategoryId,
                displayCategory = displayCategory,
                displayCategoryID = displayCategory
                    and effectiveCategoryId or nil,
                metadataOnly = isMetadataOnly,
                cooldownID = cooldownID,
                spellID = info.spellID,
                spellCategoryID = info.spellCategoryID,
                presentationKind = info.presentationKind,
                presentationIcon = info.presentationIcon,
                overrideSpellID = info.overrideSpellID,
                overrideTooltipSpellID =
                    info.overrideTooltipSpellID,
                equipSlot = info.equipSlot,
                buffSlot = info.buffSlot,
                linkedSpellIDs = info.linkedSpellIDs,
                selfAura = info.selfAura,
                hasAura = info.hasAura,
                canUseAuraForCooldown = info.canUseAuraForCooldown,
                charges = info.charges,
                isKnown = info.isKnown,
                isInvisible = info.isInvisible,
                flags = info.flags,
                order = displayOrder,
                globalOrder = index,
            }
        end
    end

    return entries, {
        allowUnlearned = allowUnlearned,
        specTag = specTag,
        hasCustomLayout = layout.hasCustomLayout == true,
        layoutDataVersion = layout.dataVersion,
        total = #defaultOrder,
        visible = #entries - metadataOnly,
        returned = #entries,
        metadataOnly = metadataOnly,
        hidden = hidden,
        skipped = skipped,
        skippedSources = skippedSources,
        categoryCounts = categoryCounts,
        sourceCategoryCounts = sourceCategoryCounts,
        writeBackCalls = 0,
    }
end

local function IndexAuraSpell(target, spellID, source)
    spellID = SafePositiveInteger(spellID)
    if spellID and target[spellID] == nil then target[spellID] = source end
end

function CooldownViewer:InvalidateAuraStackSources()
    for spellID in pairs(self.auraStackSources) do
        self.auraStackSources[spellID] = nil
    end
    self.auraStackSourceSpecTag = nil
    self.auraStackSourcesReady = false
end

function CooldownViewer:PrimeAuraStackSources(entries, specTag)
    if type(entries) ~= "table" then return false, "invalid-entries" end
    self:InvalidateAuraStackSources()
    for index = 1, #entries do
        local entry = entries[index]
        if entry.canUseAuraForCooldown == true
            and entry.displayCategory ~= nil then
            local source = {
                category = entry.category,
                cooldownID = entry.cooldownID,
            }
            IndexAuraSpell(self.auraStackSources, entry.spellID, source)
            IndexAuraSpell(
                self.auraStackSources,
                entry.overrideSpellID,
                source
            )
            IndexAuraSpell(
                self.auraStackSources,
                entry.overrideTooltipSpellID,
                source
            )
            local linked = entry.linkedSpellIDs
            for linkedIndex = 1, type(linked) == "table" and #linked or 0 do
                IndexAuraSpell(
                    self.auraStackSources,
                    linked[linkedIndex],
                    source
                )
            end
        end
    end
    self.auraStackSourceSpecTag = specTag or self:GetCurrentSpecTag()
    self.auraStackSourcesReady = true
    return true
end

function CooldownViewer:ResolveAuraStackSource(spellID)
    spellID = SafePositiveInteger(spellID)
    if not spellID then return nil, "invalid-spell" end
    local specTag = self:GetCurrentSpecTag()
    if self.auraStackSourcesReady ~= true
        or self.auraStackSourceSpecTag ~= specTag then
        self:InvalidateAuraStackSources()
        local entries, code = self:ReadEntries({
            allowUnlearned = true,
            includeHidden = true,
        })
        if not entries then return nil, code end
        self:PrimeAuraStackSources(entries, specTag)
    end
    local source = self.auraStackSources[spellID]
    if not source then return nil, "aura-source-unmapped" end
    return source
end

local function ReadFrameAuraInstanceID(frame)
    local ok, value = pcall(ReadMember, frame, "auraInstanceID")
    if ok and not IsSecretValue(value) and type(value) == "table" then
        local nestedOK, nested = pcall(ReadMember, value, "auraInstanceID")
        value = nestedOK and nested or nil
    end
    if ok and value ~= nil then return value end
    local methodOK, methodValue = SafeMethod(frame, "GetAuraSpellInstanceID")
    if methodOK then return methodValue end
    return nil
end

local function ReadFrameAuraUnit(frame)
    local ok, value = pcall(ReadMember, frame, "auraDataUnit")
    value = ok and SafeString(value) or nil
    if value then return value end
    local methodOK, methodValue = SafeMethod(frame, "GetAuraDataUnit")
    return methodOK and SafeString(methodValue) or nil
end

local function ReadAuraApplications(aura)
    if not aura then return nil, false, false end
    local ok, applications = pcall(ReadMember, aura, "applications")
    if not ok then return nil, false, false end
    if IsSecretValue(applications) then return applications, true, true end
    if type(applications) ~= "number" then
        ok, applications = pcall(ReadMember, aura, "charges")
        if not ok then return nil, false, false end
    end
    if IsSecretValue(applications) then return applications, true, true end
    if type(applications) ~= "number" then applications = 1 end
    return applications, false, true
end

local function ReadAuraByInstance(unit, auraInstanceID)
    local auraAPI = _G.C_UnitAuras
    if not (auraAPI and auraAPI.GetAuraDataByAuraInstanceID) then return nil end
    return auraAPI.GetAuraDataByAuraInstanceID(unit, auraInstanceID)
end

local function ReadFrameCachedAura(frame)
    local methodOK, aura = SafeMethod(frame, "GetAuraDataCached")
    if methodOK and aura then return aura end
    local fieldOK, fieldAura = pcall(ReadMember, frame, "auraDataCached")
    return fieldOK and fieldAura or nil
end

local function SetAuraStackUnavailable(state, status)
    local changed = state.sourceKind ~= "resource"
        or state.providerKind ~= "unit-aura-stacks"
        or state.available ~= false
        or state.secret ~= false
        or state.value ~= nil
        or state.backendStatus ~= status
    state.sourceKind = "resource"
    state.providerKind = "unit-aura-stacks"
    state.available = false
    state.secret = false
    state.value = nil
    state.valueRaw = nil
    state.rawValuesAvailable = false
    state.backendStatus = status
    return state, changed, status
end

function CooldownViewer:ReadAuraStackDisplay(
    category,
    cooldownID,
    state,
    cachedOnly,
    allowTransientSecret
)
    state = type(state) == "table" and state or {}
    if YUI.IsRetail == false then
        return state, false, "unsupported-client"
    end
    local frame
    if cachedOnly == true then
        frame = GetCachedRuntimeFrame(self, category, cooldownID)
    else
        frame = self:GetRuntimeFrame(category, cooldownID)
    end
    if not frame then
        return SetAuraStackUnavailable(state, "bridge-frame-unavailable")
    end

    local instanceOK, auraInstanceID = pcall(ReadFrameAuraInstanceID, frame)
    local instanceSecret = instanceOK and IsSecretValue(auraInstanceID)
    local instancePresent = instanceOK
        and not instanceSecret and auraInstanceID ~= nil
    local active = instancePresent and true or nil
    if active == nil then
        local activeOK, activeValue = SafeMethod(frame, "IsActive")
        if activeOK then active = SafeBoolean(activeValue) end
    end
    if active == nil then
        return SetAuraStackUnavailable(state, "bridge-active-unavailable")
    end

    local valueRaw, valueSecret, valuePresent
    local code = active and "bridge" or "bridge-inactive"
    if active then
        if instancePresent then
            local unit = ReadFrameAuraUnit(frame) or "player"
            local auraOK, aura = pcall(
                ReadAuraByInstance,
                unit,
                auraInstanceID
            )
            if auraOK and aura then
                valueRaw, valueSecret, valuePresent =
                    ReadAuraApplications(aura)
            end
        end
        if not valueSecret and valueRaw == nil then
            valueRaw, valueSecret, valuePresent =
                ReadAuraApplications(ReadFrameCachedAura(frame))
        end
        if instanceSecret then
            valueSecret = true
            code = "bridge"
        end
        if not valueSecret and valueRaw == nil then
            code = instanceSecret and code or "bridge-value-unavailable"
        end
    else
        valueRaw = 0
        valueSecret = false
        valuePresent = true
    end

    local value = not valueSecret and type(valueRaw) == "number"
        and valueRaw or nil
    local available = code == "bridge" or code == "bridge-inactive"
    local changed = state.sourceKind ~= "resource"
        or state.providerKind ~= "unit-aura-stacks"
        or state.available ~= available
        or state.secret ~= (valueSecret == true)
        or state.value ~= value
        or state.backendStatus ~= code
    state.sourceKind = "resource"
    state.providerKind = "unit-aura-stacks"
    state.available = available
    state.secret = valueSecret == true
    state.value = value
    state.valueRaw = nil
    state.rawValuesAvailable = false
    if available and valuePresent
        and (not valueSecret or allowTransientSecret == true) then
        state.valueRaw = valueRaw
        state.rawValuesAvailable = true
    end
    state.backendStatus = code
    if valueSecret then
        state.opaqueRevision = (state.opaqueRevision or 0) + 1
        changed = true
    end
    if available then return state, changed, nil end
    return state, changed, code
end
