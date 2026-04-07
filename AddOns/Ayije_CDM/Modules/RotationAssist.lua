local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local CDM_C = CDM.CONST
local VIEWERS = CDM_C.VIEWERS
local GetBaseSpellID = CDM.GetBaseSpellID
local NormalizeToBase = CDM.NormalizeToBase
local IsSafeNumber = CDM.IsSafeNumber

local isEnabled = false
local isACMHooked = false
local isReanchorHooked = false
local currentHighlightSpellID = nil
local inCombat = false
local highlightFrames = setmetatable({}, { __mode = "k" })

local dirtyFrame = CreateFrame("Frame")
dirtyFrame:Hide()

local VIEWER_NAMES = CDM_C.COOLDOWN_VIEWER_NAMES

local glowRatio = 0.33

local function CreateHighlightFrame(parent)
    local f = CreateFrame("Frame", nil, parent, "ActionBarButtonAssistedCombatHighlightTemplate")
    f:SetAllPoints()
    f:SetFrameLevel(parent:GetFrameLevel() + 5)
    f.Flipbook.Anim:Play()
    f.Flipbook.Anim:Stop()
    return f
end

local function ShowHighlight(frame)
    local hf = highlightFrames[frame]
    if not hf then
        hf = CreateHighlightFrame(frame)
        highlightFrames[frame] = hf
    end
    local w = frame:GetWidth()
    local h = frame:GetHeight()
    local ox = w * glowRatio
    local oy = h * glowRatio
    hf.Flipbook:ClearAllPoints()
    hf.Flipbook:SetPoint("TOPLEFT", frame, "TOPLEFT", -ox, oy)
    hf.Flipbook:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", ox, -oy)
    hf:Show()
    hf.Flipbook.Anim:Play()
    if not inCombat then
        hf.Flipbook.Anim:Stop()
    end
end

local function HideHighlight(frame)
    local hf = highlightFrames[frame]
    if hf then
        hf.Flipbook.Anim:Stop()
        hf:Hide()
    end
end

local function ClearAllHighlights()
    for _, hf in pairs(highlightFrames) do
        hf.Flipbook.Anim:Stop()
        hf:Hide()
    end
    wipe(highlightFrames)
end

local function RefreshHighlights()
    if not currentHighlightSpellID then
        ClearAllHighlights()
        return
    end

    for _, vName in ipairs(VIEWER_NAMES) do
        local viewer = _G[vName]
        if viewer and viewer.itemFramePool then
            for frame in viewer.itemFramePool:EnumerateActive() do
                local baseID = GetBaseSpellID(frame)
                if baseID and baseID == currentHighlightSpellID then
                    ShowHighlight(frame)
                else
                    HideHighlight(frame)
                end
            end
        end
    end
end

local function SafeNormalize(spellID)
    if not spellID or not IsSafeNumber(spellID) or spellID == 0 then
        return nil
    end
    return NormalizeToBase(spellID)
end

local function GetCurrentHighlightSpell()
    if not AssistedCombatManager then return nil end
    return SafeNormalize(AssistedCombatManager.lastNextCastSpellID)
end

local function PlayAllAnimations()
    for _, hf in pairs(highlightFrames) do
        if hf:IsShown() then
            hf.Flipbook.Anim:Play()
        end
    end
end

local function StopAllAnimations()
    for _, hf in pairs(highlightFrames) do
        if hf:IsShown() then
            hf.Flipbook.Anim:Stop()
        end
    end
end

local eventRegistryHandle = nil
local combatStateCallbackRegistered = false

local function SetCombatState(nextInCombat)
    inCombat = nextInCombat and true or false
    if inCombat then
        PlayAllAnimations()
    else
        StopAllAnimations()
    end
end

local function RegisterCombatStateListener()
    if combatStateCallbackRegistered then
        return
    end
    if CDM:RegisterCombatStateHandler(SetCombatState) then
        combatStateCallbackRegistered = true
    end
end

local function UnregisterCombatStateListener()
    if combatStateCallbackRegistered then
        CDM:UnregisterCombatStateHandler(SetCombatState)
        combatStateCallbackRegistered = false
    end
end

local function InstallHooks()
    if not isACMHooked then
        local acm = AssistedCombatManager
        if acm and acm.UpdateAllAssistedHighlightFramesForSpell then
            isACMHooked = true
            hooksecurefunc(acm, "UpdateAllAssistedHighlightFramesForSpell", function(_, spellID)
                if not isEnabled then return end
                local newSpellID = SafeNormalize(spellID)
                if newSpellID ~= currentHighlightSpellID then
                    currentHighlightSpellID = newSpellID
                    RefreshHighlights()
                end
            end)
        end
    end

    if not isReanchorHooked then
        isReanchorHooked = true
        hooksecurefunc(CDM, "ForceReanchor", function(_, viewer)
            if not isEnabled or not currentHighlightSpellID then return end
            local name = viewer and viewer.GetName and viewer:GetName()
            if name == VIEWERS.ESSENTIAL or name == VIEWERS.UTILITY then
                dirtyFrame:Show()
            end
        end)
    end
end

dirtyFrame:SetScript("OnUpdate", function(self)
    self:Hide()
    if isEnabled and currentHighlightSpellID then
        RefreshHighlights()
    end
end)

local function Enable()
    if isEnabled then return end
    isEnabled = true

    InstallHooks()

    RegisterCombatStateListener()

    SetCombatState(InCombatLockdown())

    if EventRegistry and EventRegistry.RegisterCallback then
        eventRegistryHandle = EventRegistry:RegisterCallback("AssistedCombatManager.OnSetUseAssistedHighlight", function()
            if not GetCVarBool("assistedCombatHighlight") and currentHighlightSpellID then
                currentHighlightSpellID = nil
                ClearAllHighlights()
            end
        end)
    end

    currentHighlightSpellID = GetCurrentHighlightSpell()
    RefreshHighlights()
end

local function Disable()
    if not isEnabled then return end

    ClearAllHighlights()
    currentHighlightSpellID = nil

    UnregisterCombatStateListener()

    if eventRegistryHandle and EventRegistry and EventRegistry.UnregisterCallback then
        EventRegistry:UnregisterCallback("AssistedCombatManager.OnSetUseAssistedHighlight", eventRegistryHandle)
        eventRegistryHandle = nil
    end

    dirtyFrame:Hide()
    isEnabled = false
end

CDM.RotationAssist = CDM.RotationAssist or {}

function CDM.RotationAssist:Initialize()
    CDM:RegisterRefreshCallback("rotationAssist", function()
        glowRatio = CDM.db.rotationAssistGlowRatio or 0.33
        local wantEnabled = CDM.db.rotationAssistEnabled
        if wantEnabled and not isEnabled then
            Enable()
        elseif not wantEnabled and isEnabled then
            Disable()
        end
        if isEnabled then
            if not isACMHooked then
                InstallHooks()
            end
            RefreshHighlights()
        end
    end, 56)
end
