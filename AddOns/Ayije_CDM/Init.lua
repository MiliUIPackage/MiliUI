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
CDM.resourcesHiddenBuffSet = {}

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

    local buf = {}
    for i = 1, count do
        buf[i] = handlers[i]
    end

    for i = count, 1, -1 do
        local handler = buf[i]
        if handler then
            handler(event, ...)
        end
    end
end)

CDM.RefreshCallbacks = {}
CDM.RefreshScopeRegistry = {}
CDM._positionSliderUpdaters = {}
CDM._castBarSliderUpdater = nil

local refreshCallbackList = {}
local refreshCallbackSeq = 0

local function FindInsertPosition(list, priority, seq)
    local lo, hi = 1, #list
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        local entry = list[mid]
        if entry.priority < priority or (entry.priority == priority and entry.seq < seq) then
            lo = mid + 1
        else
            hi = mid - 1
        end
    end
    return lo
end

local function SafeInvokeCallback(callbackID, callback, ...)
    local success, err = pcall(callback, ...)
    if not success then
        local L = CDM.L
        local msg = L and string.format(L["Callback error in '%s':"], callbackID) or ("Callback error in '" .. callbackID .. "':")
        print("|cffff0000[CDM] " .. msg .. "|r " .. tostring(err))
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

function CDM:RegisterRefreshCallback(id, callback, priority, scopes)
    if self.RefreshCallbacks[id] then
        self:UnregisterRefreshCallback(id)
    end

    refreshCallbackSeq = refreshCallbackSeq + 1
    local normalizedScopes = NormalizeRefreshScopeSet(scopes)
    RegisterRefreshScopeNames(normalizedScopes)
    local entry = {
        id = id,
        callback = callback,
        priority = priority or 50,
        seq = refreshCallbackSeq,
        scopes = normalizedScopes,
    }
    self.RefreshCallbacks[id] = entry
    local pos = FindInsertPosition(refreshCallbackList, entry.priority, entry.seq)
    table.insert(refreshCallbackList, pos, entry)
end

function CDM:UnregisterRefreshCallback(id)
    local entry = self.RefreshCallbacks[id]
    if not entry then return end
    self.RefreshCallbacks[id] = nil
    for i = #refreshCallbackList, 1, -1 do
        if refreshCallbackList[i] == entry then
            table.remove(refreshCallbackList, i)
            break
        end
    end
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

local function DispatchRefreshCallbacks(executeAll, scopeSet)
    if executeAll then
        for _, entry in ipairs(refreshCallbackList) do
            SafeInvokeCallback(entry.id, entry.callback)
        end
        return
    end

    for _, entry in ipairs(refreshCallbackList) do
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

    DispatchRefreshCallbacks(executeAll, scopeSet)
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
    DispatchRefreshCallbacks(true, nil)
end

function CDM:RefreshScopesNow(scopeNames)
    local normalizedScopes = NormalizeRefreshScopeSet(scopeNames)
    if not normalizedScopes then
        self:RefreshConfigNow()
        return
    end

    for scopeName in pairs(normalizedScopes) do
        if not self.RefreshScopeRegistry[scopeName] then
            self:RefreshConfigNow()
            return
        end
    end

    ClearQueuedRefreshState()
    DispatchRefreshCallbacks(false, normalizedScopes)
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
