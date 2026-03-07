local AddonName = "Ayije_CDM"

local CDM = CreateFrame("Frame")
CDM.eventHandlers = {}

_G[AddonName] = CDM

local API = {}
CDM.API = API
setmetatable(API, {
    __index = CDM,
    __newindex = function(_, key, value)
        CDM[key] = value
    end,
})

CDM.defensivesHiddenSet = {}

local nativeRegisterEvent = CDM.RegisterEvent
local nativeUnregisterEvent = CDM.UnregisterEvent

function CDM:RegisterEvent(event, handler)
    if not self.eventHandlers[event] then
        self.eventHandlers[event] = {}
        nativeRegisterEvent(CDM, event)
    end
    if handler then
        for _, existingHandler in ipairs(self.eventHandlers[event]) do
            if existingHandler == handler then
                return
            end
        end
        table.insert(self.eventHandlers[event], handler)
    end
end

function CDM:UnregisterEvent(event)
    if self.eventHandlers[event] then
        self.eventHandlers[event] = nil
        nativeUnregisterEvent(CDM, event)
    end
end

function CDM:UnregisterEventHandler(event, handler)
    if not self.eventHandlers[event] or not handler then return end
    local handlers = self.eventHandlers[event]
    for i = #handlers, 1, -1 do
        if handlers[i] == handler then
            table.remove(handlers, i)
            if #handlers == 0 then
                self.eventHandlers[event] = nil
                nativeUnregisterEvent(CDM, event)
            end
            return
        end
    end
end

CDM:SetScript("OnEvent", function(self, event, ...)
    local handlers = self.eventHandlers[event]
    if handlers then
        for i = #handlers, 1, -1 do
            local handler = handlers[i]
            if handler then
                handler(event, ...)
            end
        end
    end
end)

local unitEventFrame = CreateFrame("Frame")
local unitEventHandlers = {}
local unitEventDispatchBuffer = {}

local function EnsureUnitEventBucket(event, unit)
    local bucket = unitEventHandlers[event]
    if bucket then
        return bucket
    end

    bucket = {
        list = {},
        lookup = {},
    }
    unitEventHandlers[event] = bucket
    unitEventFrame:RegisterUnitEvent(event, unit)
    return bucket
end

function CDM:RegisterUnitEvent(event, unit, handler)
    if type(event) ~= "string" or event == "" then return end

    local bucket = EnsureUnitEventBucket(event, unit)
    if type(handler) ~= "function" then return end
    if bucket.lookup[handler] then return end

    bucket.lookup[handler] = true
    bucket.list[#bucket.list + 1] = handler
end

function CDM:UnregisterUnitEvent(event)
    if type(event) ~= "string" or event == "" then return end
    local bucket = unitEventHandlers[event]
    if not bucket then return end

    unitEventHandlers[event] = nil
    unitEventFrame:UnregisterEvent(event)
end

function CDM:UnregisterUnitEventHandler(event, handler)
    if type(event) ~= "string" or event == "" then return end
    if type(handler) ~= "function" then return end

    local bucket = unitEventHandlers[event]
    if not bucket then return end
    if not bucket.lookup[handler] then return end

    bucket.lookup[handler] = nil
    local handlers = bucket.list
    for i = #handlers, 1, -1 do
        if handlers[i] == handler then
            table.remove(handlers, i)
            break
        end
    end

    if #handlers == 0 then
        unitEventHandlers[event] = nil
        unitEventFrame:UnregisterEvent(event)
    end
end

unitEventFrame:SetScript("OnEvent", function(_, event, ...)
    local bucket = unitEventHandlers[event]
    if not bucket then return end

    local handlers = bucket.list
    local count = #handlers
    if count == 0 then return end
    if count == 1 then
        local handler = handlers[1]
        if handler then
            handler(event, ...)
        end
        return
    end

    table.wipe(unitEventDispatchBuffer)
    for i = 1, count do
        unitEventDispatchBuffer[i] = handlers[i]
    end

    for i = count, 1, -1 do
        local handler = unitEventDispatchBuffer[i]
        if handler then
            handler(event, ...)
        end
    end
end)

CDM.RefreshCallbacks = {}
CDM.RefreshScopeRegistry = {}
CDM._positionSliderUpdaters = {}
CDM._castBarSliderUpdater = nil

local sortedCallbacks = {}
local callbacksDirty = true
local refreshCallbackSeq = 0
local refreshScopeSeq = 0

local function CallbackSort(a, b)
    if a.priority ~= b.priority then
        return a.priority < b.priority
    end
    return a.seq < b.seq
end

local L = CDM.L

local function SafeInvokeCallback(callbackID, callback, ...)
    local success, err = pcall(callback, ...)
    if not success then
        print("|cffff0000[CDM] " .. string.format(L["Callback error in '%s':"], callbackID) .. "|r " .. tostring(err))
    end
end

local function NormalizeRefreshScopeSet(scopeNames)
    if type(scopeNames) == "string" then
        if scopeNames == "" then
            return nil
        end
        return { [scopeNames] = true }
    end
    if type(scopeNames) ~= "table" then
        return nil
    end

    local normalized = {}
    for key, value in pairs(scopeNames) do
        local scopeName
        if type(key) == "number" then
            scopeName = value
        elseif value then
            scopeName = key
        end
        if type(scopeName) == "string" and scopeName ~= "" then
            normalized[scopeName] = true
        end
    end

    if not next(normalized) then
        return nil
    end

    return normalized
end

local function RegisterRefreshScopeNames(scopeSet)
    if not scopeSet then return end
    for scopeName in pairs(scopeSet) do
        CDM.RefreshScopeRegistry[scopeName] = true
    end
end

local function ScopeSetToLabel(scopeSet)
    if not scopeSet then
        return ""
    end
    local labels = {}
    for scopeName in pairs(scopeSet) do
        labels[#labels + 1] = scopeName
    end
    table.sort(labels)
    return table.concat(labels, ",")
end

local function DebugRefresh(message)
    if not CDM.debugRefreshScopes then
        return
    end
    print("|cff00ccff[CDM Refresh]|r " .. message)
end

function CDM:RegisterRefreshCallback(id, callback, priority, scopes)
    refreshCallbackSeq = refreshCallbackSeq + 1
    local normalizedScopes = NormalizeRefreshScopeSet(scopes)
    RegisterRefreshScopeNames(normalizedScopes)
    self.RefreshCallbacks[id] = {
        id = id,
        callback = callback,
        priority = priority or 50,
        seq = refreshCallbackSeq,
        scopes = normalizedScopes,
    }
    callbacksDirty = true
end

function CDM:UnregisterRefreshCallback(id)
    self.RefreshCallbacks[id] = nil
    callbacksDirty = true
end

function CDM:RegisterRefreshScope(scopeName, callback, priority)
    if type(scopeName) ~= "string" or scopeName == "" then return nil end
    if type(callback) ~= "function" then return nil end

    refreshScopeSeq = refreshScopeSeq + 1
    local scopeID = "__scope__" .. scopeName .. "__" .. tostring(refreshScopeSeq)
    self:RegisterRefreshCallback(scopeID, callback, priority, { scopeName })
    return scopeID
end

function CDM:RegisterRefreshCallbackScope(id, scopeNames)
    if type(id) ~= "string" or id == "" then return false end
    local entry = self.RefreshCallbacks[id]
    if not entry then return false end

    local normalizedScopes = NormalizeRefreshScopeSet(scopeNames)
    if not normalizedScopes then return false end

    if not entry.scopes then
        entry.scopes = {}
    end
    for scopeName in pairs(normalizedScopes) do
        entry.scopes[scopeName] = true
    end
    RegisterRefreshScopeNames(entry.scopes)
    return true
end

function CDM:ClearRefreshCallbackScopes(id)
    if type(id) ~= "string" or id == "" then return false end
    local entry = self.RefreshCallbacks[id]
    if not entry then return false end
    entry.scopes = nil
    return true
end

function CDM:RegisterCastBarSliderUpdater(callback)
    if type(callback) ~= "function" then return end
    self._castBarSliderUpdater = callback
end

function CDM:UnregisterCastBarSliderUpdater()
    self._castBarSliderUpdater = nil
end

function CDM:NotifyCastBarSliderUpdate(offsetX, offsetY)
    local callback = self._castBarSliderUpdater
    if callback then
        SafeInvokeCallback("castbar-slider-updater", callback, offsetX, offsetY)
    end
end

function CDM:RegisterPositionSliderUpdater(name, callback)
    if type(name) ~= "string" or name == "" then return end
    if type(callback) ~= "function" then return end
    self._positionSliderUpdaters[name] = callback
end

function CDM:UnregisterPositionSliderUpdater(name)
    if name == nil then
        wipe(self._positionSliderUpdaters)
        return
    end
    self._positionSliderUpdaters[name] = nil
end

function CDM:NotifyPositionSliderUpdate(name, x, y, useRawSlider)
    if type(name) ~= "string" or name == "" then return end
    local callback = self._positionSliderUpdaters[name]
    if callback then
        SafeInvokeCallback("position-slider-updater:" .. name, callback, x, y, useRawSlider)
    end
end

local refreshPending = false
local refreshPendingAll = false
local refreshPendingScopes = {}
local refreshThrottleFrame = CreateFrame("Frame")

local function RebuildSortedRefreshCallbacks()
    if callbacksDirty then
        table.wipe(sortedCallbacks)
        for _, entry in pairs(CDM.RefreshCallbacks) do
            sortedCallbacks[#sortedCallbacks + 1] = entry
        end
        table.sort(sortedCallbacks, CallbackSort)
        callbacksDirty = false
    end
end

local function ShouldRunEntryForScopeSet(entry, scopeSet)
    if not entry or not entry.scopes then
        return false
    end
    for scopeName in pairs(scopeSet) do
        if entry.scopes[scopeName] then
            return true
        end
    end
    return false
end

local function DispatchRefreshCallbacks(executeAll, scopeSet, reasonLabel)
    RebuildSortedRefreshCallbacks()

    if executeAll then
        DebugRefresh(reasonLabel or "dispatch:full")
        for _, entry in ipairs(sortedCallbacks) do
            SafeInvokeCallback(entry.id, entry.callback)
        end
        return
    end

    if CDM.refreshScopeDebugFallbackToFull then
        DebugRefresh("dispatch:scoped_fallback_full:" .. ScopeSetToLabel(scopeSet))
        for _, entry in ipairs(sortedCallbacks) do
            SafeInvokeCallback(entry.id, entry.callback)
        end
        return
    end

    DebugRefresh(reasonLabel or ("dispatch:scoped:" .. ScopeSetToLabel(scopeSet)))
    for _, entry in ipairs(sortedCallbacks) do
        if ShouldRunEntryForScopeSet(entry, scopeSet) then
            SafeInvokeCallback(entry.id, entry.callback)
        end
    end
end

local function ExecuteRefreshCallbacks()
    refreshPending = false

    local executeAll = refreshPendingAll or not next(refreshPendingScopes)
    local scopeSet = refreshPendingScopes
    refreshPendingAll = false
    refreshPendingScopes = {}

    DispatchRefreshCallbacks(executeAll, scopeSet, executeAll and "dispatch:full" or ("dispatch:scoped:" .. ScopeSetToLabel(scopeSet)))
end

refreshThrottleFrame:SetScript("OnUpdate", function(self)
    if refreshPending then
        ExecuteRefreshCallbacks()
    end
    if not refreshPending then
        self:Hide()
    end
end)
refreshThrottleFrame:Hide()

local function ClearQueuedRefreshState()
    refreshPending = false
    refreshPendingAll = false
    table.wipe(refreshPendingScopes)
    refreshThrottleFrame:Hide()
end

local function QueueRefreshAll()
    refreshPendingAll = true
    table.wipe(refreshPendingScopes)
    if not refreshPending then
        refreshPending = true
        refreshThrottleFrame:Show()
    end
end

local function QueueRefreshScopes(scopeNames)
    local normalizedScopes = NormalizeRefreshScopeSet(scopeNames)
    if not normalizedScopes then
        QueueRefreshAll()
        return
    end

    if refreshPendingAll then
        return
    end

    for scopeName in pairs(normalizedScopes) do
        if not CDM.RefreshScopeRegistry[scopeName] then
            DebugRefresh("unknown_scope:" .. scopeName .. ":fallback_full")
            QueueRefreshAll()
            return
        end
    end

    for scopeName in pairs(normalizedScopes) do
        refreshPendingScopes[scopeName] = true
    end

    if not refreshPending then
        refreshPending = true
        refreshThrottleFrame:Show()
    end
end

function CDM:RefreshConfig()
    QueueRefreshAll()
end

function CDM:RefreshScope(scopeName)
    if type(scopeName) ~= "string" or scopeName == "" then
        QueueRefreshAll()
        return
    end
    QueueRefreshScopes({ scopeName })
end

function CDM:RefreshScopes(scopeNames)
    QueueRefreshScopes(scopeNames)
end

function CDM:RefreshConfigNow()
    ClearQueuedRefreshState()
    DispatchRefreshCallbacks(true, nil, "dispatch:full:immediate")
end

function CDM:RefreshScopeNow(scopeName)
    if type(scopeName) ~= "string" or scopeName == "" then
        self:RefreshConfigNow()
        return
    end
    self:RefreshScopesNow({ scopeName })
end

function CDM:RefreshScopesNow(scopeNames)
    local normalizedScopes = NormalizeRefreshScopeSet(scopeNames)
    if not normalizedScopes then
        self:RefreshConfigNow()
        return
    end

    for scopeName in pairs(normalizedScopes) do
        if not self.RefreshScopeRegistry[scopeName] then
            DebugRefresh("unknown_scope:" .. scopeName .. ":fallback_full_now")
            self:RefreshConfigNow()
            return
        end
    end

    ClearQueuedRefreshState()
    DispatchRefreshCallbacks(false, normalizedScopes, "dispatch:scoped:immediate:" .. ScopeSetToLabel(normalizedScopes))
end

function CDM:IsRefreshScopeRegistered(scopeName)
    if type(scopeName) ~= "string" or scopeName == "" then
        return false
    end
    return self.RefreshScopeRegistry[scopeName] == true
end

function CDM.IsSafeNumber(value)
    return value ~= nil
       and type(value) == "number"
       and not issecretvalue(value)
end

EventUtil.ContinueOnAddOnLoaded(AddonName, function()
    if CDM.InitializeDB then
        CDM:InitializeDB()
    end

    if CDM.OnEnable then
        CDM:OnEnable()
    end
end)
