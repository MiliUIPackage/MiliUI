local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

local IsSafeNumber = CDM.IsSafeNumber
local CDM_C = CDM.CONST
local VIEWERS = CDM_C.VIEWERS

local pairs = pairs
local next = next

CDM.GlowDirector = CDM.GlowDirector or {}
local GlowDirector = CDM.GlowDirector

local OWNER_KEY = "GlowDirector"

local framesByCdID = {}
local spellIDByCdID = {}
local cdIDsBySpellID = {}

local GetSpellCharges = C_Spell.GetSpellCharges
local C_Spell_IsSpellUsable = C_Spell.IsSpellUsable

local usableEventFrame = CreateFrame("Frame")
local usableBySpellID = {}
local watchedSpellCount = 0

local function RefreshUsableEventRegistration()
    if watchedSpellCount > 0 then
        usableEventFrame:RegisterEvent("SPELL_UPDATE_USABLE")
    else
        usableEventFrame:UnregisterEvent("SPELL_UPDATE_USABLE")
    end
end

local OnSpellEvent

local function HasChargeSource(frame)
    return frame.HasVisualDataSource_Charges and frame:HasVisualDataSource_Charges() or false
end

local function ComputeFrameReady(frame, spellID)
    if not usableBySpellID[spellID] then return false end
    local s = CDM.GetSpellWatchState(spellID)
    if not s then return false end
    local ci = GetSpellCharges(spellID)
    if ci and ci.maxCharges and ci.maxCharges > 1 then
        if not ci.isActive then return true end
        return HasChargeSource(frame)
    end
    return (not s.isActive) or s.isOnGCD
end

local function FanoutToFrames(cdID)
    local frames = framesByCdID[cdID]
    if not frames then return end
    local sync = CDM.SyncReadyGlowForFrame
    if not sync then return end
    local map = CDM._auraOverlayEnabled
    local entry = map and map[cdID] or nil
    local spellID = spellIDByCdID[cdID]
    for frame in pairs(frames) do
        sync(frame, entry, spellID, ComputeFrameReady(frame, spellID))
    end
end

OnSpellEvent = function(spellID, cooldownsChanged, chargesChanged)
    if not (cooldownsChanged or chargesChanged) then return end
    local cdIDs = cdIDsBySpellID[spellID]
    if not cdIDs then return end
    for cdID in pairs(cdIDs) do
        FanoutToFrames(cdID)
    end
end

local function HandleUsableEvent()
    for spellID, prev in pairs(usableBySpellID) do
        local usable = C_Spell_IsSpellUsable(spellID) and true or false
        if prev ~= usable then
            usableBySpellID[spellID] = usable
            local cdIDs = cdIDsBySpellID[spellID]
            if cdIDs then
                for cdID in pairs(cdIDs) do
                    FanoutToFrames(cdID)
                end
            end
        end
    end
end

usableEventFrame:SetScript("OnEvent", function(_, event)
    if event == "SPELL_UPDATE_USABLE" then
        HandleUsableEvent()
    end
end)

local function WatchCdIDForSpell(cdID, spellID)
    spellIDByCdID[cdID] = spellID
    local set = cdIDsBySpellID[spellID]
    if not set then
        set = {}
        cdIDsBySpellID[spellID] = set
        usableBySpellID[spellID] = C_Spell_IsSpellUsable(spellID) and true or false
        watchedSpellCount = watchedSpellCount + 1
        if watchedSpellCount == 1 then
            RefreshUsableEventRegistration()
        end
        if CDM.WatchSpell then
            CDM.WatchSpell(OWNER_KEY, spellID, OnSpellEvent)
        end
    end
    set[cdID] = true
end

local function UnwatchCdIDFromSpell(cdID)
    local spellID = spellIDByCdID[cdID]
    if not spellID then return end
    spellIDByCdID[cdID] = nil
    local set = cdIDsBySpellID[spellID]
    if set then
        set[cdID] = nil
        if not next(set) then
            cdIDsBySpellID[spellID] = nil
            usableBySpellID[spellID] = nil
            watchedSpellCount = watchedSpellCount - 1
            if watchedSpellCount == 0 then
                RefreshUsableEventRegistration()
            end
            if CDM.UnwatchSpell then
                CDM.UnwatchSpell(OWNER_KEY, spellID)
            end
        end
    end
end

local function UnregisterCdID(cdID)
    framesByCdID[cdID] = nil
    UnwatchCdIDFromSpell(cdID)
end

local function RemoveFrameFromCdID(frame, cdID)
    local set = framesByCdID[cdID]
    if not set then return end
    set[frame] = nil
    if not next(set) then
        UnregisterCdID(cdID)
    end
end

function GlowDirector:OnCooldownIDSet(frame)
    if not frame then return end
    local oldCdID = frame.cdmGlowDirectorCdID
    if oldCdID then
        RemoveFrameFromCdID(frame, oldCdID)
        frame.cdmGlowDirectorCdID = nil
    end

    local cdID = frame.cooldownID
    if not cdID then return end
    local readySet = CDM._readyGlowCooldownIDs
    if not readySet or not readySet[cdID] then return end

    local info = frame.cooldownInfo
    local spellID = info and (info.overrideSpellID or info.spellID)
    if not IsSafeNumber(spellID) then return end

    local set = framesByCdID[cdID]
    if not set then
        set = {}
        framesByCdID[cdID] = set
        WatchCdIDForSpell(cdID, spellID)
    end
    set[frame] = true
    frame.cdmGlowDirectorCdID = cdID

    FanoutToFrames(cdID)
end

function GlowDirector:OnCooldownIDCleared(frame)
    if not frame then return end
    local cdID = frame.cdmGlowDirectorCdID
    if not cdID then return end
    RemoveFrameFromCdID(frame, cdID)
    frame.cdmGlowDirectorCdID = nil
end

function GlowDirector:InstallAcquireResetHook(v)
    hooksecurefunc(v, "OnAcquireItemFrame", function(_, itemFrame)
        itemFrame.cdmGlowDirectorCdID = nil
        if itemFrame.cdmGlowLifecycleHooked then return end
        itemFrame.cdmGlowLifecycleHooked = true

        hooksecurefunc(itemFrame, "SetCooldownID", function(self)
            if self.cooldownID == self.cdmGlowDirectorCdID then return end
            GlowDirector:OnCooldownIDSet(self)
        end)

        hooksecurefunc(itemFrame, "ClearCooldownID", function(self)
            GlowDirector:OnCooldownIDCleared(self)
        end)

        hooksecurefunc(itemFrame, "SetOverrideSpell", function(self)
            if not self.cdmGlowDirectorCdID then return end
            GlowDirector:OnCooldownIDSet(self)
        end)
    end)
end

function GlowDirector:RefreshFrame(frame)
    if not frame then return end
    local sync = CDM.SyncReadyGlowForFrame
    if not sync then return end

    local cdID = frame.cooldownID
    local map = CDM._auraOverlayEnabled
    local entry = map and map[cdID] or nil

    local readySet = CDM._readyGlowCooldownIDs
    local registered = cdID and framesByCdID[cdID] and framesByCdID[cdID][frame]
    if not registered or not readySet or not readySet[cdID] then
        sync(frame, entry, nil, false)
        return
    end

    local spellID = spellIDByCdID[cdID]
    sync(frame, entry, spellID, ComputeFrameReady(frame, spellID))
end

function GlowDirector:RebuildIndex()
    wipe(framesByCdID)
    wipe(spellIDByCdID)
    wipe(cdIDsBySpellID)
    wipe(usableBySpellID)
    watchedSpellCount = 0
    RefreshUsableEventRegistration()
    if CDM.UnwatchAllSpells then
        CDM.UnwatchAllSpells(OWNER_KEY)
    end

    if not VIEWERS then return end
    CDM:ForEachActiveFrame({ VIEWERS.ESSENTIAL, VIEWERS.UTILITY }, function(frame)
        self:OnCooldownIDSet(frame)
        CDM:RefreshFrameVisuals(frame)
    end)
end
