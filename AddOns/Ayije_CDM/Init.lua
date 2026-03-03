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

function CDM:RegisterUnitEvent(event, unit, handler)
    if not unitEventHandlers[event] then
        unitEventHandlers[event] = {}
        unitEventFrame:RegisterUnitEvent(event, unit)
    end
    if handler then
        for _, existing in ipairs(unitEventHandlers[event]) do
            if existing == handler then return end
        end
        table.insert(unitEventHandlers[event], handler)
    end
end

function CDM:UnregisterUnitEvent(event)
    if unitEventHandlers[event] then
        unitEventHandlers[event] = nil
        unitEventFrame:UnregisterEvent(event)
    end
end

function CDM:UnregisterUnitEventHandler(event, handler)
    if not unitEventHandlers[event] or not handler then return end
    for i = #unitEventHandlers[event], 1, -1 do
        if unitEventHandlers[event][i] == handler then
            table.remove(unitEventHandlers[event], i)
            break
        end
    end
    if #unitEventHandlers[event] == 0 then
        unitEventHandlers[event] = nil
        unitEventFrame:UnregisterEvent(event)
    end
end

unitEventFrame:SetScript("OnEvent", function(_, event, ...)
    local handlers = unitEventHandlers[event]
    if handlers then
        for i = #handlers, 1, -1 do
            if handlers[i] then
                handlers[i](event, ...)
            end
        end
    end
end)

CDM.RefreshCallbacks = {}
CDM._positionSliderUpdaters = {}
CDM._castBarSliderUpdater = nil

local sortedCallbacks = {}
local callbacksDirty = true
local refreshCallbackSeq = 0

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

function CDM:RegisterRefreshCallback(id, callback, priority)
    refreshCallbackSeq = refreshCallbackSeq + 1
    self.RefreshCallbacks[id] = {
        id = id,
        callback = callback,
        priority = priority or 50,
        seq = refreshCallbackSeq,
    }
    callbacksDirty = true
end

function CDM:UnregisterRefreshCallback(id)
    self.RefreshCallbacks[id] = nil
    callbacksDirty = true
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
local refreshThrottleFrame = CreateFrame("Frame")

local function ExecuteRefreshCallbacks()
    refreshPending = false

    if callbacksDirty then
        table.wipe(sortedCallbacks)
        for _, entry in pairs(CDM.RefreshCallbacks) do
            sortedCallbacks[#sortedCallbacks + 1] = entry
        end
        table.sort(sortedCallbacks, CallbackSort)
        callbacksDirty = false
    end

    for _, entry in ipairs(sortedCallbacks) do
        SafeInvokeCallback(entry.id, entry.callback)
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

function CDM:RefreshConfig()
    if not refreshPending then
        refreshPending = true
        refreshThrottleFrame:Show()
    end
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
