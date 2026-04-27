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

CDM.resourcesHiddenBuffSet = {}

local nativeRegisterEvent = CDM.RegisterEvent

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

CDM:SetScript("OnEvent", function(self, event, ...)
    local handlers = self.eventHandlers[event]
    if handlers then
        for i = 1, #handlers do
            handlers[i](event, ...)
        end
    end
end)

CDM.RefreshCallbacks = {}
CDM._positionSliderUpdaters = {}

local refreshCallbackList = {}
local refreshCallbackSeq = 0

local function InsertSorted(list, entry)
    for i = 1, #list do
        local e = list[i]
        if entry.priority < e.priority or (entry.priority == e.priority and entry.seq < e.seq) then
            table.insert(list, i, entry)
            return
        end
    end
    table.insert(list, entry)
end

function CDM:RegisterRefreshCallback(id, callback, priority, scopes)
    if self.RefreshCallbacks[id] then
        self:UnregisterRefreshCallback(id)
    end

    refreshCallbackSeq = refreshCallbackSeq + 1
    local scopeSet
    if scopes then
        scopeSet = {}
        for _, s in ipairs(scopes) do scopeSet[s] = true end
    end
    local entry = {
        id = id,
        callback = callback,
        priority = priority or 50,
        seq = refreshCallbackSeq,
        scopes = scopeSet,
    }
    self.RefreshCallbacks[id] = entry
    InsertSorted(refreshCallbackList, entry)
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
        callback(x, y, useRawSlider)
    end
end

local refreshPending = false
local refreshAll = false
local pendingScopes = {}
local scratchScopes = {}
local refreshThrottleFrame = CreateFrame("Frame")

local function ShouldRunEntry(entry, scopeSet)
    if not entry.scopes then return true end
    for scope in pairs(scopeSet) do
        if entry.scopes[scope] then return true end
    end
    return false
end

local function DispatchRefreshCallbacks(scopeSet)
    if scopeSet then
        for _, entry in ipairs(refreshCallbackList) do
            if ShouldRunEntry(entry, scopeSet) then
                entry.callback()
            end
        end
    else
        for _, entry in ipairs(refreshCallbackList) do
            entry.callback()
        end
    end
end

local function ExecuteRefreshCallbacks()
    refreshPending = false
    local scopeSet
    if not refreshAll then
        scopeSet = pendingScopes
        pendingScopes = scratchScopes
        scratchScopes = scopeSet
    end
    refreshAll = false
    DispatchRefreshCallbacks(scopeSet)
    if scopeSet then
        wipe(scopeSet)
    end
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

function CDM:Refresh(...)
    local n = select("#", ...)
    if n == 0 then
        refreshAll = true
    else
        for i = 1, n do
            pendingScopes[select(i, ...)] = true
        end
    end
    if not refreshPending then
        refreshPending = true
        refreshThrottleFrame:Show()
    end
end


function CDM.IsSafeNumber(value)
    return value ~= nil
       and type(value) == "number"
       and canaccessvalue(value)
end

EventUtil.ContinueOnAddOnLoaded(AddonName, function()
    if CDM.InitializeDB then
        CDM:InitializeDB()
    end

    if CDM.OnEnable then
        CDM:OnEnable()
    end
end)
