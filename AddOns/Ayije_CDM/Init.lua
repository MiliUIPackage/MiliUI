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
CDM._castBarSliderUpdater = nil

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

function CDM:RegisterRefreshCallback(id, callback, priority)
    if self.RefreshCallbacks[id] then
        self:UnregisterRefreshCallback(id)
    end

    refreshCallbackSeq = refreshCallbackSeq + 1
    local entry = {
        id = id,
        callback = callback,
        priority = priority or 50,
        seq = refreshCallbackSeq,
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
        callback(offsetX, offsetY)
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
local refreshThrottleFrame = CreateFrame("Frame")

local function DispatchRefreshCallbacks()
    for _, entry in ipairs(refreshCallbackList) do
        entry.callback()
    end
end

local function ExecuteRefreshCallbacks()
    refreshPending = false
    DispatchRefreshCallbacks()
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

local function QueueRefresh()
    if not refreshPending then
        refreshPending = true
        refreshThrottleFrame:Show()
    end
end

function CDM:Refresh()
    QueueRefresh()
end

function CDM:RefreshNow()
    refreshPending = false
    refreshThrottleFrame:Hide()
    DispatchRefreshCallbacks()
end

CDM.RefreshConfig = CDM.Refresh
CDM.RefreshScopes = CDM.Refresh

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
