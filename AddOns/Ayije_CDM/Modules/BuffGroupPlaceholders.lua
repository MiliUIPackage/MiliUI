local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local CDM_C = CDM.CONST
local Pixel = CDM.Pixel
local Snap = Pixel.Snap

CDM.BuffGroupPlaceholders = CDM.BuffGroupPlaceholders or {}

local GetFrameData = CDM.GetFrameData

local math_max = math.max
local math_floor = math.floor
local ipairs = ipairs
local pairs = pairs
local next = next

local placeholderPool = {}
local activePlaceholders = {}
local placeholderRefreshTimer = nil
local placeholderRetryCount = 0

local function GetConfiguredBorderColor()
    local fallback = (CDM.defaults and CDM.defaults.borderColor) or { r = 0, g = 0, b = 0, a = 1 }
    local color = CDM_C.GetConfigValue("borderColor", fallback)
    if type(color) ~= "table" then
        color = fallback
    end
    return color.r or 0, color.g or 0, color.b or 0, color.a or 1
end

CDM.GetConfiguredBorderColor = GetConfiguredBorderColor

local function DoPlaceholderRefresh()
    placeholderRefreshTimer = nil

    local sets = CDM.BuffGroupSets
    if not (sets and sets.groups) then
        local specID = CDM:GetCurrentSpecID()
        local hasData = specID and CDM.db and CDM.db.buffGroups and CDM.db.buffGroups[specID]
        if not specID then
            return
        end
        if not hasData then
            return
        end
        if placeholderRetryCount < 10 then
            placeholderRetryCount = placeholderRetryCount + 1
            placeholderRefreshTimer = C_Timer.NewTimer(0.15, DoPlaceholderRefresh)
        end
        return
    end

    CDM:UpdateAllBuffGroupContainers()
    local buffViewer = _G[CDM_C.VIEWERS.BUFF]
    if buffViewer and CDM.ForceReanchor then
        CDM:ForceReanchor(buffViewer)
    end

    local talentReady = not C_ClassTalents or not C_ClassTalents.GetActiveConfigID or C_ClassTalents.GetActiveConfigID()
    if not talentReady and placeholderRetryCount < 10 then
        placeholderRetryCount = placeholderRetryCount + 1
        placeholderRefreshTimer = C_Timer.NewTimer(0.15, DoPlaceholderRefresh)
    else
        placeholderRetryCount = 0
    end
end

local function QueuePlaceholderRefresh()
    if placeholderRefreshTimer then
        placeholderRefreshTimer:Cancel()
    end
    placeholderRetryCount = 0
    placeholderRefreshTimer = C_Timer.NewTimer(0, DoPlaceholderRefresh)
end

local function ApplyPlaceholderVisuals(frame, spellID, iconW, iconH)
    local bsv = CDM.borderStyleVersion or 0
    local zoom = CDM_C.GetEffectiveZoomAmount()
    if frame._cdmPHSpellID == spellID and frame._cdmPHW == iconW
        and frame._cdmPHH == iconH and frame._cdmPHBSV == bsv
        and frame._cdmPHZoom == zoom then
        return
    end

    frame._cdmPHSpellID = spellID
    frame._cdmPHW = iconW
    frame._cdmPHH = iconH
    frame._cdmPHBSV = bsv
    frame._cdmPHZoom = zoom

    local phWSnapped = Snap(iconW)
    local phHSnapped = Snap(iconH)
    frame:SetSize(phWSnapped, phHSnapped)

    local tex = C_Spell.GetSpellTexture(spellID)
    if tex then
        frame.Icon:SetTexture(tex)
    else
        frame.Icon:SetColorTexture(0.15, 0.15, 0.15)
        frame._cdmPHSpellID = nil
    end

    CDM_C.ApplyIconTexCoord(frame.Icon, zoom, phWSnapped, phHSnapped)
    frame.Icon:SetDesaturation(1)
    frame.Icon:SetAlpha(1)

    if CDM.BORDER and CDM.BORDER.CreateBorder then
        CDM.BORDER:CreateBorder(frame)
        if CDM.BORDER.activeBorders then
            CDM.BORDER.activeBorders[frame] = nil
        end
        if frame.border then
            local r, g, b, a = GetConfiguredBorderColor()
            frame.border:SetBackdropBorderColor(r, g, b, a)
        end
    end

    frame:Show()
end

local function AcquirePlaceholder(container, spellID, iconW, iconH)
    local frame = table.remove(placeholderPool)
    if not frame then
        frame = CreateFrame("Frame", nil, UIParent)
        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        Pixel.DisableTextureSnap(icon)
        frame.Icon = icon
        frame.isPlaceholder = true
    end

    if frame:GetParent() ~= container then
        frame:SetParent(container)
    end
    frame:SetFrameLevel(1)
    ApplyPlaceholderVisuals(frame, spellID, iconW, iconH)
    if not frame:IsShown() then frame:Show() end
    return frame
end

local function ReleasePlaceholder(frame)
    frame:Hide()
    frame:ClearAllPoints()
    if frame:GetParent() ~= UIParent then
        frame:SetParent(UIParent)
    end
    placeholderPool[#placeholderPool + 1] = frame
end

local function ReleaseGroupPlaceholders(groupIndex)
    local group = activePlaceholders[groupIndex]
    if not group then return end
    for _, frame in pairs(group) do
        ReleasePlaceholder(frame)
    end
    activePlaceholders[groupIndex] = nil
end

local function OnGroupedBuffFrameHide(frame)
    local frameData = GetFrameData(frame)
    if not frameData.cdmStaticPlaceholderEligible then return end
    local groupIdx = frameData.cdmStaticGroupIdx
    local spellID = frameData.cdmStaticGroupSpellID
    if not groupIdx or not spellID then return end
    local group = activePlaceholders[groupIdx]
    if not group then return end
    local pFrame = group[spellID]
    if not pFrame then return end
    local containers = CDM.buffGroupContainers
    local container = containers and containers[groupIdx]
    if not container or pFrame:GetParent() ~= container then return end
    pFrame:SetAlpha(1)
end

local function SyncGroupedFrameState(frame, groupIndex, rawSpellID, placeholderEligible)
    if not frame then
        return
    end

    local frameData = GetFrameData(frame)
    frameData.cdmStaticGroupIdx = groupIndex
    frameData.cdmStaticGroupSpellID = rawSpellID
    frameData.cdmStaticPlaceholderEligible = placeholderEligible and true or nil

    if groupIndex and rawSpellID and not frameData.cdmBuffGroupOnHideHooked then
        frameData.cdmBuffGroupOnHideHooked = true
        frame:HookScript("OnHide", OnGroupedBuffFrameHide)
    end
end

local function ReconcileGroupPlaceholders(groupIndex, opts)
    if not groupIndex or type(opts) ~= "table" then
        return
    end

    local spellSlot = opts.spellSlot
    local placeholderBySpell = opts.placeholderBySpell
    local groupData = opts.groupData
    if type(spellSlot) ~= "table" or type(groupData) ~= "table" or type(groupData.spells) ~= "table" then
        ReleaseGroupPlaceholders(groupIndex)
        return
    end

    local existing = activePlaceholders[groupIndex]
    if not existing then
        existing = {}
        activePlaceholders[groupIndex] = existing
    end

    for sid, pFrame in pairs(existing) do
        local wantPlaceholder = placeholderBySpell and placeholderBySpell[sid]
        if spellSlot[sid] == nil or not wantPlaceholder then
            ReleasePlaceholder(pFrame)
            existing[sid] = nil
        end
    end

    local positionFrameAtSlot = opts.positionFrameAtSlot
    local isSpellMarkedActive = opts.isSpellMarkedActive
    if type(positionFrameAtSlot) ~= "function" or type(isSpellMarkedActive) ~= "function" then
        return
    end

    for _, sid in ipairs(groupData.spells) do
        local slotIdx = spellSlot[sid]
        local wantPlaceholder = placeholderBySpell and placeholderBySpell[sid]
        if slotIdx ~= nil and wantPlaceholder then
            local pFrame = existing[sid]
            if not pFrame then
                pFrame = AcquirePlaceholder(opts.container, sid, opts.iconW, opts.iconH)
                existing[sid] = pFrame
            else
                ApplyPlaceholderVisuals(pFrame, sid, opts.iconW, opts.iconH)
            end
            pFrame:ClearAllPoints()
            positionFrameAtSlot(
                pFrame,
                opts.container,
                slotIdx,
                opts.iconWPx,
                opts.iconHPx,
                opts.spacingPx,
                opts.grow,
                opts.layoutCount,
                opts.anchorPoint,
                opts.selfPoint
            )
            pFrame:SetAlpha(isSpellMarkedActive(sid, opts.activeSpellIDs) and 0 or 1)
        end
    end

    if not next(existing) then
        activePlaceholders[groupIndex] = nil
    end
end

local function ReleaseAllPlaceholders()
    local toRelease
    for idx in pairs(activePlaceholders) do
        if not toRelease then
            toRelease = {}
        end
        toRelease[#toRelease + 1] = idx
    end

    if not toRelease then
        return
    end

    for _, idx in ipairs(toRelease) do
        ReleaseGroupPlaceholders(idx)
    end
end

local function QueuePlaceholderReadinessRefresh()
    QueuePlaceholderRefresh()
end

local function OnPlaceholderSpecStateChanged(unit)
    if unit and unit ~= "player" then
        return
    end
    QueuePlaceholderRefresh()
end

CDM:RegisterEvent("PLAYER_ENTERING_WORLD", QueuePlaceholderReadinessRefresh)
CDM:RegisterTalentDataHandler(QueuePlaceholderReadinessRefresh)
CDM:RegisterSpecStateHandler(OnPlaceholderSpecStateChanged)

CDM.BuffGroupPlaceholders.SyncGroupedFrameState = SyncGroupedFrameState
CDM.BuffGroupPlaceholders.ReconcileGroup = ReconcileGroupPlaceholders
CDM.BuffGroupPlaceholders.ReleaseGroup = ReleaseGroupPlaceholders
CDM.BuffGroupPlaceholders.ReleaseAll = ReleaseAllPlaceholders
