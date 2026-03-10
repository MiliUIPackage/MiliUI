local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local CDM_C = CDM and CDM.CONST or {}

local watcherFrame = CreateFrame("Frame")
local dispatchPending = false
local dispatchFrame = CreateFrame("Frame")
dispatchFrame:Hide()
local hasCooldownPending = false
local hasChargesPending = false

local ownerWatches = {}
local spellRefCounts = {}
local activeSpellCount = 0
local unwatchScratch = {}

local GCD_SPELL_ID = CDM_C.GCD_SPELL_ID

local function RefreshWatcherEventRegistration()
    if activeSpellCount > 0 then
        watcherFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        watcherFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
    else
        watcherFrame:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
        watcherFrame:UnregisterEvent("SPELL_UPDATE_CHARGES")
    end
end

local function DoDispatchSpellWatchers()
    dispatchPending = false

    if activeSpellCount <= 0 then
        hasCooldownPending = false
        hasChargesPending = false
        return
    end

    local cooldownsChanged = hasCooldownPending
    local chargesChanged = hasChargesPending
    hasCooldownPending = false
    hasChargesPending = false

    if not cooldownsChanged and not chargesChanged then
        return
    end

    local gcdActive = false
    if cooldownsChanged and C_Spell and C_Spell.GetSpellCooldownDuration and GCD_SPELL_ID then
        gcdActive = (C_Spell.GetSpellCooldownDuration(GCD_SPELL_ID) ~= nil)
    end

    for _, owner in pairs(ownerWatches) do
        if next(owner.spells) and owner.callback then
            owner.callback(cooldownsChanged, chargesChanged, gcdActive)
        end
    end
end

dispatchFrame:SetScript("OnUpdate", function(self)
    self:Hide()
    DoDispatchSpellWatchers()
end)

local function QueueDispatchSpellWatchers()
    if dispatchPending or activeSpellCount <= 0 then
        return
    end

    dispatchPending = true
    dispatchFrame:Show()
end

watcherFrame:SetScript("OnEvent", function(_, event)
    if event == "SPELL_UPDATE_COOLDOWN" then
        hasCooldownPending = true
        QueueDispatchSpellWatchers()
    elseif event == "SPELL_UPDATE_CHARGES" then
        hasChargesPending = true
        QueueDispatchSpellWatchers()
    end
end)

local function GetOrCreateOwner(ownerKey, callback)
    local owner = ownerWatches[ownerKey]
    if owner then
        if type(callback) == "function" then
            owner.callback = callback
        end
        return owner
    end

    owner = {
        spells = {},
        callback = callback,
    }
    ownerWatches[ownerKey] = owner
    return owner
end

local function RemoveOwnerIfEmpty(ownerKey)
    local owner = ownerWatches[ownerKey]
    if not owner then
        return
    end
    if next(owner.spells) then
        return
    end
    ownerWatches[ownerKey] = nil
end

function CDM.WatchSpellState(ownerKey, spellID, callback)
    if not ownerKey or spellID == nil or type(callback) ~= "function" then
        return false
    end

    local owner = GetOrCreateOwner(ownerKey, callback)
    if owner.spells[spellID] then
        return true
    end

    owner.spells[spellID] = true

    local refCount = spellRefCounts[spellID] or 0
    if refCount <= 0 then
        activeSpellCount = activeSpellCount + 1
        RefreshWatcherEventRegistration()
    end
    spellRefCounts[spellID] = refCount + 1
    return true
end

function CDM.UnwatchSpellState(ownerKey, spellID)
    local owner = ownerWatches[ownerKey]
    if not owner or not owner.spells[spellID] then
        return false
    end

    owner.spells[spellID] = nil
    RemoveOwnerIfEmpty(ownerKey)

    local refCount = spellRefCounts[spellID]
    if not refCount then
        return true
    end

    refCount = refCount - 1
    if refCount <= 0 then
        spellRefCounts[spellID] = nil
        activeSpellCount = activeSpellCount - 1
        if activeSpellCount < 0 then
            activeSpellCount = 0
        end
        RefreshWatcherEventRegistration()
    else
        spellRefCounts[spellID] = refCount
    end
    return true
end

function CDM.UnwatchAllSpellStates(ownerKey)
    local owner = ownerWatches[ownerKey]
    if not owner then
        return
    end

    local count = 0
    for spellID in pairs(owner.spells) do
        count = count + 1
        unwatchScratch[count] = spellID
    end

    for i = 1, count do
        local spellID = unwatchScratch[i]
        CDM.UnwatchSpellState(ownerKey, spellID)
        unwatchScratch[i] = nil
    end
end
