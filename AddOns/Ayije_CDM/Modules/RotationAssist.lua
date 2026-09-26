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

local dirtyFrame = CreateFrame("Frame")
dirtyFrame:Hide()

local VIEWER_NAMES = CDM_C.COOLDOWN_VIEWER_NAMES

local glowRatio = 0.33
local assistStyle = "square"

-- "blizzard": the action-bar ant flipbook, scaled out by glowRatio.
-- "square":   the same cyan, drawn as a hard 2px frame over the icon edge plus a
--             1px-per-step halo outside it. Plain textures on our own child frame:
--             no Blizzard template, and no geometry read from the viewer item.
local SQUARE_COLOR = { 0.30, 0.82, 1.00 }
local SQUARE_EDGE_PX = 2
local SQUARE_HALO_ALPHA = { 0.60, 0.36, 0.18, 0.07 }

local Pixel = CDM.Pixel

local function CreateFlipbookFrame(parent)
    local f = CreateFrame("Frame", nil, parent, "ActionBarButtonAssistedCombatHighlightTemplate")
    f:SetAllPoints()
    f:SetFrameLevel(parent:GetFrameLevel() + 5)
    f.Flipbook.Anim:Play()
    f.Flipbook.Anim:Stop()
    return f
end

local function NewRing(host, layer, sublevel, alpha, additive)
    local ring = {}
    for i = 1, 4 do
        local tex = Pixel.CreateSolidTexture(host, layer, sublevel)
        tex:SetVertexColor(SQUARE_COLOR[1], SQUARE_COLOR[2], SQUARE_COLOR[3], alpha)
        if additive then tex:SetBlendMode("ADD") end
        ring[i] = tex
    end
    return ring
end

-- Lays out a ring whose outer edge is `out` pixels outside `anchor` and is `thick`
-- pixels wide. Top/bottom span the full width; left/right fill the gap between them
-- so corners are drawn exactly once.
local function LayoutRing(ring, anchor, px, out, thick)
    local o, t = out * px, thick * px
    local top, bottom, left, right = ring[1], ring[2], ring[3], ring[4]
    top:ClearAllPoints()
    top:SetPoint("TOPLEFT", anchor, "TOPLEFT", -o, o)
    top:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", o, o - t)
    bottom:ClearAllPoints()
    bottom:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", -o, -o)
    bottom:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", o, -o + t)
    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", anchor, "TOPLEFT", -o, o - t)
    left:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT", -o + t, -o + t)
    right:ClearAllPoints()
    right:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", o, o - t)
    right:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", o - t, -o + t)
end

local function CreateSquareFrame(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints()
    f:SetFrameLevel(parent:GetFrameLevel() + 5)

    -- Edge sits inside the icon (over its 1px border) so it never spills into the
    -- neighbour; only the soft halo reaches outward.
    f.edge = NewRing(f, "OVERLAY", 7, 1, false)

    local halo = CreateFrame("Frame", nil, f)
    halo:SetAllPoints()
    f.halo = halo
    f.haloRings = {}
    for i, a in ipairs(SQUARE_HALO_ALPHA) do
        f.haloRings[i] = NewRing(halo, "ARTWORK", 0, a, true)
    end

    -- Breathing halo in combat stands in for the flipbook's marching ants.
    local anim = halo:CreateAnimationGroup()
    anim:SetLooping("BOUNCE")
    local fade = anim:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.35)
    fade:SetDuration(0.6)
    fade:SetSmoothing("IN_OUT")
    f.anim = anim
    return f
end

local function LayoutSquareFrame(f)
    local px = Pixel.GetSize()
    if f.layoutPx == px then return end
    f.layoutPx = px
    LayoutRing(f.edge, f, px, 0, SQUARE_EDGE_PX)
    for i, ring in ipairs(f.haloRings) do
        LayoutRing(ring, f, px, i, 1)
    end
end

-- One frame table per style: frames can't be destroyed, so switching styles just
-- hides the other set and keeps it pooled for a switch back.
local highlightFramesByStyle = {
    blizzard = setmetatable({}, { __mode = "k" }),
    square = setmetatable({}, { __mode = "k" }),
}

local function GetAnim(hf)
    return hf.anim or hf.Flipbook.Anim
end

local function ShowHighlight(frame)
    local frames = highlightFramesByStyle[assistStyle]
    local hf = frames[frame]
    if assistStyle == "square" then
        if not hf then
            hf = CreateSquareFrame(frame)
            frames[frame] = hf
        end
        LayoutSquareFrame(hf)
    else
        if not hf then
            hf = CreateFlipbookFrame(frame)
            frames[frame] = hf
        end
        local w = frame:GetWidth()
        local h = frame:GetHeight()
        local ox = w * glowRatio
        local oy = h * glowRatio
        hf.Flipbook:ClearAllPoints()
        hf.Flipbook:SetPoint("TOPLEFT", frame, "TOPLEFT", -ox, oy)
        hf.Flipbook:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", ox, -oy)
    end
    hf:Show()
    local anim = GetAnim(hf)
    anim:Play()
    if not inCombat then
        anim:Stop()
    end
end

local function HideHighlight(frame)
    local hf = highlightFramesByStyle[assistStyle][frame]
    if hf then
        GetAnim(hf):Stop()
        hf:Hide()
    end
end

local function ClearAllHighlights()
    for _, frames in pairs(highlightFramesByStyle) do
        for _, hf in pairs(frames) do
            GetAnim(hf):Stop()
            hf:Hide()
        end
    end
end

local function SafeNormalize(spellID)
    if not spellID or not IsSafeNumber(spellID) or spellID == 0 then
        return nil
    end
    local stable = CDM.ResolveStableBase and CDM:ResolveStableBase(spellID)
    if stable then return stable end
    return NormalizeToBase(spellID)
end

local function RefreshHighlights()
    if not currentHighlightSpellID then
        ClearAllHighlights()
        return
    end

    CDM:ForEachActiveFrame(VIEWER_NAMES, function(frame)
        local baseID = SafeNormalize(GetBaseSpellID(frame))
        if baseID and baseID == currentHighlightSpellID then
            ShowHighlight(frame)
        else
            HideHighlight(frame)
        end
    end)
end

local function IsHighlightCVarEnabled()
    return GetCVarBool("assistedCombatHighlight")
end

local function GetCurrentHighlightSpell()
    if not IsHighlightCVarEnabled() then return nil end
    if not C_AssistedCombat or not C_AssistedCombat.GetNextCastSpell then return nil end
    return SafeNormalize(C_AssistedCombat.GetNextCastSpell(false))
end

local function PlayAllAnimations()
    for _, hf in pairs(highlightFramesByStyle[assistStyle]) do
        if hf:IsShown() then
            GetAnim(hf):Play()
        end
    end
end

local function StopAllAnimations()
    for _, hf in pairs(highlightFramesByStyle[assistStyle]) do
        if hf:IsShown() then
            GetAnim(hf):Stop()
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
            if IsHighlightCVarEnabled() then
                currentHighlightSpellID = GetCurrentHighlightSpell()
                RefreshHighlights()
            elseif currentHighlightSpellID then
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
        local nextStyle = CDM.db.rotationAssistStyle == "blizzard" and "blizzard" or "square"
        if nextStyle ~= assistStyle then
            ClearAllHighlights()
            assistStyle = nextStyle
        end
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
    end, 56, { "STYLE" })
end
