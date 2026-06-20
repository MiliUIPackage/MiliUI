local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

local pairs = pairs
local next = next
local type = type
local C_Spell_GetSpellCooldown = C_Spell.GetSpellCooldown
local IsSafeNumber = CDM.IsSafeNumber

local GCD_CATEGORY = Constants.SpellCooldownConsts.GLOBAL_RECOVERY_CATEGORY

local watcherFrame = CreateFrame("Frame")
local dispatchFrame = CreateFrame("Frame")
dispatchFrame:Hide()
local dispatchPending = false

local ownerWatches = {}
local spellOwners = {}
local spellState = {}
local pendingByOwner = {}
local activeSpellCount = 0

local flagsPool = {}
local flagsPoolCount = 0

local function AcquireFlags()
    local flags
    if flagsPoolCount > 0 then
        flags = flagsPool[flagsPoolCount]
        flagsPool[flagsPoolCount] = nil
        flagsPoolCount = flagsPoolCount - 1
        flags.cd = false
        flags.ch = false
    else
        flags = { cd = false, ch = false }
    end
    return flags
end

local function ReleaseFlags(flags)
    flagsPoolCount = flagsPoolCount + 1
    flagsPool[flagsPoolCount] = flags
end

local function RefreshWatcherEventRegistration()
    if activeSpellCount > 0 then
        watcherFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        watcherFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
        watcherFrame:RegisterEvent("SPELLS_CHANGED")
    else
        watcherFrame:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
        watcherFrame:UnregisterEvent("SPELL_UPDATE_CHARGES")
        watcherFrame:UnregisterEvent("SPELLS_CHANGED")
    end
end

local function ReadInitialState(spellID)
    local info = C_Spell_GetSpellCooldown(spellID)
    return {
        isActive = info and info.isActive or false,
        isOnGCD = false,
    }
end

local function QueueOwner(ownerKey, spellID, flagName)
    local pending = pendingByOwner[ownerKey]
    if not pending then
        pending = {}
        pendingByOwner[ownerKey] = pending
    end
    local flags = pending[spellID]
    if not flags then
        flags = AcquireFlags()
        pending[spellID] = flags
    end
    flags[flagName] = true
end

local function FireOwnersFor(spellID, flagName)
    local owners = spellOwners[spellID]
    if not owners then return end
    for ownerKey in pairs(owners) do
        QueueOwner(ownerKey, spellID, flagName)
    end
    if not dispatchPending then
        dispatchPending = true
        dispatchFrame:Show()
    end
end

local function RefreshCooldownState(spellID, force)
    local state = spellState[spellID]
    if not state then return end
    local info = C_Spell_GetSpellCooldown(spellID)
    if not info then return end
    local newActive = info.isActive and true or false
    local newOnGCD  = info.isOnGCD  and true or false
    if not force and state.isActive == newActive and state.isOnGCD == newOnGCD then return end
    state.isActive = newActive
    state.isOnGCD  = newOnGCD
    FireOwnersFor(spellID, "cd")
end

local function HandleCooldownEvent()
    for sid in pairs(spellState) do
        RefreshCooldownState(sid)
    end
end

local function HandleChargesEvent()
    for sid in pairs(spellOwners) do
        FireOwnersFor(sid, "ch")
    end
end

local function HandleSpellsChanged()
    for sid in pairs(spellOwners) do
        local state = spellState[sid]
        if state then
            local info = C_Spell_GetSpellCooldown(sid)
            if info then
                state.isActive = info.isActive and true or false
            end
        end
        FireOwnersFor(sid, "cd")
    end
end

watcherFrame:SetScript("OnEvent", function(_, event, spellID, baseSpellID, _category, startRecoveryCategory)
    if event == "SPELL_UPDATE_COOLDOWN" then
        if startRecoveryCategory == GCD_CATEGORY or spellID == nil then
            HandleCooldownEvent()
        elseif IsSafeNumber(spellID) and spellState[spellID] then
            RefreshCooldownState(spellID, true)
        elseif IsSafeNumber(baseSpellID) and spellState[baseSpellID] then
            RefreshCooldownState(baseSpellID, true)
        end
    elseif event == "SPELL_UPDATE_CHARGES" then
        HandleChargesEvent()
    elseif event == "SPELLS_CHANGED" then
        HandleSpellsChanged()
    end
end)

local function DoDispatch()
    dispatchPending = false
    for ownerKey, pending in pairs(pendingByOwner) do
        local owner = ownerWatches[ownerKey]
        if owner and owner.callback then
            for spellID, flags in pairs(pending) do
                pending[spellID] = nil
                owner.callback(spellID, flags.cd, flags.ch)
                ReleaseFlags(flags)
            end
        else
            for spellID, flags in pairs(pending) do
                pending[spellID] = nil
                ReleaseFlags(flags)
            end
        end
        pendingByOwner[ownerKey] = nil
    end
end

dispatchFrame:SetScript("OnUpdate", function(self)
    self:Hide()
    DoDispatch()
end)

local function AddSpellToOwner(ownerKey, spellID)
    local owner = ownerWatches[ownerKey]
    if owner.spells[spellID] then return end
    owner.spells[spellID] = true
    local owners = spellOwners[spellID]
    if not owners then
        owners = {}
        spellOwners[spellID] = owners
        spellState[spellID] = ReadInitialState(spellID)
        activeSpellCount = activeSpellCount + 1
        if activeSpellCount == 1 then
            RefreshWatcherEventRegistration()
        end
    end
    owners[ownerKey] = true
end

local function RemoveSpellFromOwner(ownerKey, spellID)
    local owner = ownerWatches[ownerKey]
    if not owner or not owner.spells[spellID] then return end
    owner.spells[spellID] = nil
    local owners = spellOwners[spellID]
    if owners then
        owners[ownerKey] = nil
        if not next(owners) then
            spellOwners[spellID] = nil
            spellState[spellID] = nil
            activeSpellCount = activeSpellCount - 1
            if activeSpellCount <= 0 then
                activeSpellCount = 0
                RefreshWatcherEventRegistration()
            end
        end
    end
    local pending = pendingByOwner[ownerKey]
    if pending and pending[spellID] then
        ReleaseFlags(pending[spellID])
        pending[spellID] = nil
    end
end

function CDM.GetSpellWatchState(spellID)
    return spellState[spellID]
end

function CDM.WatchSpell(ownerKey, spellID, callback)
    if not ownerKey or spellID == nil or type(callback) ~= "function" then
        return false
    end
    local owner = ownerWatches[ownerKey]
    if owner then
        owner.callback = callback
    else
        owner = { callback = callback, spells = {} }
        ownerWatches[ownerKey] = owner
    end
    AddSpellToOwner(ownerKey, spellID)
    return true
end

function CDM.UnwatchSpell(ownerKey, spellID)
    local owner = ownerWatches[ownerKey]
    if not owner or not owner.spells[spellID] then
        return false
    end
    RemoveSpellFromOwner(ownerKey, spellID)
    if not next(owner.spells) then
        ownerWatches[ownerKey] = nil
        pendingByOwner[ownerKey] = nil
    end
    return true
end

function CDM.UnwatchAllSpells(ownerKey)
    local owner = ownerWatches[ownerKey]
    if not owner then return false end
    for sid in pairs(owner.spells) do
        local owners = spellOwners[sid]
        if owners then
            owners[ownerKey] = nil
            if not next(owners) then
                spellOwners[sid] = nil
                spellState[sid] = nil
                activeSpellCount = activeSpellCount - 1
            end
        end
    end
    if activeSpellCount <= 0 then
        activeSpellCount = 0
        RefreshWatcherEventRegistration()
    end
    local pending = pendingByOwner[ownerKey]
    if pending then
        for sid, flags in pairs(pending) do
            pending[sid] = nil
            ReleaseFlags(flags)
        end
        pendingByOwner[ownerKey] = nil
    end
    ownerWatches[ownerKey] = nil
    return true
end

function CDM.CreateSpellEntryDispatcher(opts)
    local watchOwnerKey    = opts.watchOwnerKey
    local getEntrySpellID  = opts.getEntrySpellID
    local getEntryFrame    = opts.getEntryFrame
    local updateIcon       = opts.updateIcon
    local shouldDispatch   = opts.shouldDispatch
    local onNeedFullUpdate = opts.onNeedFullUpdate

    local entryBySpellID = {}
    local dispatcher = {}

    local function OnSpellEvent(spellID, cdChanged, chChanged)
        if not (cdChanged or chChanged) then return end
        if shouldDispatch and not shouldDispatch() then return end
        if onNeedFullUpdate and onNeedFullUpdate() then return end
        local entry = entryBySpellID[spellID]
        if not entry then return end
        local frame = getEntryFrame(entry)
        if not frame then return end
        updateIcon(frame, cdChanged, chChanged)
    end

    function dispatcher.SetEntries(entries)
        CDM.UnwatchAllSpells(watchOwnerKey)
        for sid in pairs(entryBySpellID) do entryBySpellID[sid] = nil end
        if not entries then return end
        for _, entry in ipairs(entries) do
            local sid = getEntrySpellID(entry)
            if sid then
                entryBySpellID[sid] = entry
                CDM.WatchSpell(watchOwnerKey, sid, OnSpellEvent)
            end
        end
    end

    function dispatcher.Clear()
        CDM.UnwatchAllSpells(watchOwnerKey)
        for sid in pairs(entryBySpellID) do entryBySpellID[sid] = nil end
    end

    return dispatcher
end
