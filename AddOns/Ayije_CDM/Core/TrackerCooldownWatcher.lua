local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

local getItemCooldown = C_Container and C_Container.GetItemCooldown
local getInventoryItemCooldown = GetInventoryItemCooldown

local watcherFrame = CreateFrame("Frame")
local evaluatePending = false
local activeTargetCount = 0

local ownerTargets = {}
local itemWatches = {}
local slotWatches = {}
local unwatchItemScratch = {}
local unwatchSlotScratch = {}

local function NormalizeCooldown(startTime, duration, enable)
    return startTime or 0, duration or 0, enable or 0
end

local function PopulateCooldownState(watch, startTime, duration, enable)
    startTime, duration, enable = NormalizeCooldown(startTime, duration, enable)
    watch.startTime = startTime
    watch.duration = duration
    watch.enable = enable
    watch.isActive = (enable == 1 and startTime > 0 and duration > 0)
    watch.readyTime = watch.isActive and (startTime + duration) or nil
end

local function UpdateCooldownStateIfChanged(watch, startTime, duration, enable)
    startTime, duration, enable = NormalizeCooldown(startTime, duration, enable)
    if watch.startTime == startTime and watch.duration == duration and watch.enable == enable then
        return false
    end
    PopulateCooldownState(watch, startTime, duration, enable)
    return true
end

local function NotifyWatchCallbacks(kind, id, watch)
    for _, callback in pairs(watch.callbacks) do
        callback(kind, id, watch.startTime, watch.duration, watch.enable, watch.isActive, watch.readyTime)
    end
end

local function EvaluateItemWatches()
    if not getItemCooldown then
        return
    end

    for itemID, watch in pairs(itemWatches) do
        if UpdateCooldownStateIfChanged(watch, getItemCooldown(itemID)) then
            NotifyWatchCallbacks("item", itemID, watch)
        end
    end
end

local function EvaluateSlotWatches()
    if not getInventoryItemCooldown then
        return
    end

    for slotID, watch in pairs(slotWatches) do
        if UpdateCooldownStateIfChanged(watch, getInventoryItemCooldown("player", slotID)) then
            NotifyWatchCallbacks("slot", slotID, watch)
        end
    end
end

local function DoEvaluateCooldownWatches()
    evaluatePending = false
    if activeTargetCount <= 0 then
        return
    end

    EvaluateItemWatches()
    EvaluateSlotWatches()
end

local function QueueEvaluateCooldownWatches()
    if evaluatePending or activeTargetCount <= 0 then
        return
    end

    evaluatePending = true
    C_Timer.After(0, DoEvaluateCooldownWatches)
end

watcherFrame:SetScript("OnEvent", function(_, event)
    if event == "BAG_UPDATE_COOLDOWN" then
        QueueEvaluateCooldownWatches()
    end
end)

local function RefreshWatcherEventRegistration()
    if activeTargetCount > 0 then
        watcherFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    else
        watcherFrame:UnregisterEvent("BAG_UPDATE_COOLDOWN")
    end
end

local function GetOrCreateOwnerTargets(ownerKey)
    local owner = ownerTargets[ownerKey]
    if owner then
        return owner
    end

    owner = {
        items = {},
        slots = {},
    }
    ownerTargets[ownerKey] = owner
    return owner
end

local function RemoveOwnerTargetsIfEmpty(ownerKey)
    local owner = ownerTargets[ownerKey]
    if not owner then
        return
    end
    if next(owner.items) or next(owner.slots) then
        return
    end
    ownerTargets[ownerKey] = nil
end

local function CreateWatchAndPrime(kind, id)
    local watch = {
        callbacks = {},
        startTime = 0,
        duration = 0,
        enable = 0,
        isActive = false,
        readyTime = nil,
    }

    if kind == "item" and getItemCooldown then
        PopulateCooldownState(watch, getItemCooldown(id))
    elseif kind == "slot" and getInventoryItemCooldown then
        PopulateCooldownState(watch, getInventoryItemCooldown("player", id))
    end

    return watch
end

local function WatchTarget(watches, kind, ownerKey, id, callback)
    if not ownerKey or id == nil or type(callback) ~= "function" then
        return false
    end

    local watch = watches[id]
    if not watch then
        watch = CreateWatchAndPrime(kind, id)
        watches[id] = watch
        activeTargetCount = activeTargetCount + 1
        RefreshWatcherEventRegistration()
    end

    local hadOwner = (watch.callbacks[ownerKey] ~= nil)
    watch.callbacks[ownerKey] = callback

    if not hadOwner then
        local owner = GetOrCreateOwnerTargets(ownerKey)
        if kind == "item" then
            owner.items[id] = true
        else
            owner.slots[id] = true
        end
    end

    return true
end

local function UnwatchTarget(watches, kind, ownerKey, id)
    local watch = watches[id]
    if not watch or not watch.callbacks[ownerKey] then
        return false
    end

    watch.callbacks[ownerKey] = nil

    local owner = ownerTargets[ownerKey]
    if owner then
        if kind == "item" then
            owner.items[id] = nil
        else
            owner.slots[id] = nil
        end
        RemoveOwnerTargetsIfEmpty(ownerKey)
    end

    if not next(watch.callbacks) then
        watches[id] = nil
        activeTargetCount = activeTargetCount - 1
        if activeTargetCount < 0 then
            activeTargetCount = 0
        end
        RefreshWatcherEventRegistration()
    end

    return true
end

function CDM.WatchItemCooldown(ownerKey, itemID, callback)
    return WatchTarget(itemWatches, "item", ownerKey, itemID, callback)
end

function CDM.WatchInventorySlotCooldown(ownerKey, slotID, callback)
    return WatchTarget(slotWatches, "slot", ownerKey, slotID, callback)
end

function CDM.UnwatchAllCooldowns(ownerKey)
    local owner = ownerTargets[ownerKey]
    if not owner then
        return
    end

    local itemCount = 0
    for itemID in pairs(owner.items) do
        itemCount = itemCount + 1
        unwatchItemScratch[itemCount] = itemID
    end
    local slotCount = 0
    for slotID in pairs(owner.slots) do
        slotCount = slotCount + 1
        unwatchSlotScratch[slotCount] = slotID
    end

    for i = 1, itemCount do
        local itemID = unwatchItemScratch[i]
        UnwatchTarget(itemWatches, "item", ownerKey, itemID)
        unwatchItemScratch[i] = nil
    end

    for i = 1, slotCount do
        local slotID = unwatchSlotScratch[i]
        UnwatchTarget(slotWatches, "slot", ownerKey, slotID)
        unwatchSlotScratch[i] = nil
    end
end
