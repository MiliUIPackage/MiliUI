local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local API = CDM.API
local CDM_C = CDM.CONST
local SetPixelPerfectPoint = CDM_C.SetPixelPerfectPoint
local ToPixelCountForRegion = CDM_C.ToPixelCountForRegion
local PixelsToUIForRegion = CDM_C.PixelsToUIForRegion
local SetPointPixels = CDM_C.SetPointPixels

CDM.buffGroupContainers = {}

local containers = CDM.buffGroupContainers

local function GetXSide(point)
    if point == "LEFT" or point == "TOPLEFT" or point == "BOTTOMLEFT" then
        return "LEFT"
    elseif point == "RIGHT" or point == "TOPRIGHT" or point == "BOTTOMRIGHT" then
        return "RIGHT"
    end
    return "CENTER"
end

local function GetYSide(point)
    if point == "TOP" or point == "TOPLEFT" or point == "TOPRIGHT" then
        return "TOP"
    elseif point == "BOTTOM" or point == "BOTTOMLEFT" or point == "BOTTOMRIGHT" then
        return "BOTTOM"
    end
    return "CENTER"
end

local function ComposePoint(xSide, ySide)
    if ySide == "TOP" then
        if xSide == "LEFT" then return "TOPLEFT" end
        if xSide == "RIGHT" then return "TOPRIGHT" end
        return "TOP"
    elseif ySide == "BOTTOM" then
        if xSide == "LEFT" then return "BOTTOMLEFT" end
        if xSide == "RIGHT" then return "BOTTOMRIGHT" end
        return "BOTTOM"
    end
    if xSide == "LEFT" then return "LEFT" end
    if xSide == "RIGHT" then return "RIGHT" end
    return "CENTER"
end

local function DeriveSelfPoint(anchorPoint, grow)
    local point = anchorPoint or "CENTER"
    if grow == "CENTER_H" or grow == "CENTER_V" then
        return point
    end

    local xSide = GetXSide(point)
    local ySide = GetYSide(point)

    if grow == "RIGHT" then
        xSide = "LEFT"
    elseif grow == "LEFT" then
        xSide = "RIGHT"
    elseif grow == "DOWN" then
        ySide = "TOP"
    elseif grow == "UP" then
        ySide = "BOTTOM"
    end

    return ComposePoint(xSide, ySide)
end

local GetFrameData = CDM.GetFrameData
local NormalizeToBase = CDM.NormalizeToBase
local layoutCtx = CDM._LayoutCtx
local GetStableFrameSortID = layoutCtx and layoutCtx.GetStableFrameSortID

local nextGroupedStableSortID = 0

local function GetGroupedFrameStableSortID(frame)
    if GetStableFrameSortID then
        return GetStableFrameSortID(frame)
    end

    local frameData = GetFrameData(frame)
    local sortID = frameData.cdmStableSortID
    if sortID then
        return sortID
    end

    nextGroupedStableSortID = nextGroupedStableSortID + 1
    frameData.cdmStableSortID = nextGroupedStableSortID
    return nextGroupedStableSortID
end

local scratchSpellOrder = {}
local scratchSpellSlot = {}
local scratchActiveSpellIDs = {}
local scratchGroupSpellLookup = {}
local scratchPlaceholderBySpell = {}
local scratchSlotToRawSpell = {}
local spellVariantBaseCache = {}
local spellVariantOverrideCache = {}

local function GetConfiguredBorderColor()
    local fallback = (CDM.defaults and CDM.defaults.borderColor) or { r = 0, g = 0, b = 0, a = 1 }
    local color = CDM_C.GetConfigValue("borderColor", fallback)
    if type(color) ~= "table" then
        color = fallback
    end
    return color.r or 0, color.g or 0, color.b or 0, color.a or 1
end

local function BuildActiveSpellSet()
    local active = {}
    local buffViewer = _G["BuffIconCooldownViewer"]
    if buffViewer and buffViewer.itemFramePool then
        for frame in buffViewer.itemFramePool:EnumerateActive() do
            local candidates = CDM.GetSpellIDCandidates and CDM:GetSpellIDCandidates(frame, true)
            if candidates then
                for _, id in ipairs(candidates) do
                    active[id] = true
                end
            end
        end
    end
    return active
end

local function IsSpellActiveInViewer(spellID, cachedSet)
    if IsPlayerSpell(spellID) then return true end
    local baseID = NormalizeToBase(spellID)
    if baseID and baseID ~= spellID and IsPlayerSpell(baseID) then return true end
    if cachedSet then
        return cachedSet[spellID] or (baseID and cachedSet[baseID]) or false
    end
    return false
end

if API then
    function API:GetConfiguredBorderColor()
        return GetConfiguredBorderColor()
    end

    function API:BuildActiveSpellSet()
        return BuildActiveSpellSet()
    end

    function API:IsSpellActiveInViewer(spellID, cachedSet)
        return IsSpellActiveInViewer(spellID, cachedSet)
    end
end

local function ResolveSpellOverrideEntry(overrideMap, spellID)
    if not overrideMap or not spellID then return nil end
    if overrideMap[spellID] then return overrideMap[spellID] end
    local base = NormalizeToBase(spellID)
    if base and base ~= spellID and overrideMap[base] then return overrideMap[base] end
    return nil
end

local function IsUsableSpellID(id)
    return type(id) == "number" and id > 0 and id == math.floor(id)
end

local function ClearSpellVariantResolutionCaches()
    table.wipe(spellVariantBaseCache)
    table.wipe(spellVariantOverrideCache)
end

local function GetCachedBaseSpellID(spellID)
    if not IsUsableSpellID(spellID) then
        return nil
    end
    local cached = spellVariantBaseCache[spellID]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end
    local baseID = NormalizeToBase(spellID)
    spellVariantBaseCache[spellID] = IsUsableSpellID(baseID) and baseID or false
    return spellVariantBaseCache[spellID] ~= false and spellVariantBaseCache[spellID] or nil
end

local function GetOverrideSpellIfDifferent(spellID)
    if not IsUsableSpellID(spellID) or not C_Spell.GetOverrideSpell then
        return nil
    end
    local cached = spellVariantOverrideCache[spellID]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end
    local overrideID = C_Spell.GetOverrideSpell(spellID)
    if IsUsableSpellID(overrideID) and overrideID ~= spellID then
        spellVariantOverrideCache[spellID] = overrideID
        return overrideID
    end
    spellVariantOverrideCache[spellID] = false
    return nil
end

local function StoreVariantValue(target, spellID, value, preserveExisting)
    if type(target) ~= "table" or not IsUsableSpellID(spellID) then
        return
    end

    local function StoreValue(id)
        if not IsUsableSpellID(id) then return end
        if preserveExisting and target[id] ~= nil then return end
        target[id] = value
    end

    StoreValue(spellID)
    StoreValue(GetOverrideSpellIfDifferent(spellID))

    local baseID = GetCachedBaseSpellID(spellID)
    if baseID and baseID ~= spellID then
        StoreValue(baseID)
        StoreValue(GetOverrideSpellIfDifferent(baseID))
    end
end

local function ResolveVariantValue(sourceMap, spellID)
    if type(sourceMap) ~= "table" or not IsUsableSpellID(spellID) then
        return nil
    end

    local direct = sourceMap[spellID]
    if direct ~= nil then
        return direct
    end

    local baseID = GetCachedBaseSpellID(spellID)
    if baseID and baseID ~= spellID then
        local baseValue = sourceMap[baseID]
        if baseValue ~= nil then
            return baseValue
        end
    end

    local overrideID = GetOverrideSpellIfDifferent(spellID)
    if overrideID then
        local overrideValue = sourceMap[overrideID]
        if overrideValue ~= nil then
            return overrideValue
        end
    end

    if baseID and baseID ~= spellID then
        local baseOverrideID = GetOverrideSpellIfDifferent(baseID)
        if baseOverrideID then
            local baseOverrideValue = sourceMap[baseOverrideID]
            if baseOverrideValue ~= nil then
                return baseOverrideValue
            end
        end
    end

    return nil
end

local function BuildGroupSpellLookup(spells)
    table.wipe(scratchGroupSpellLookup)
    if type(spells) ~= "table" then
        return scratchGroupSpellLookup
    end

    for _, listedID in ipairs(spells) do
        if listedID then
            StoreVariantValue(scratchGroupSpellLookup, listedID, true, false)
        end
    end

    return scratchGroupSpellLookup
end

local function IsSpellEligible(spellID, groupSpellLookup, activeSpellSet)
    if not spellID then return false end

    -- Match placeholder eligibility to the same grouped buff registry used by runtime matching.
    local registryMatched = false
    if CDM.CheckIDAgainstRegistry then
        local matchType = CDM.CheckIDAgainstRegistry(spellID)
        if matchType == "buffgroup" then
            registryMatched = true
        end
    end

    -- Fallback for edge timing: if registry cache isn't ready yet, trust current group assignment.
    if not registryMatched then
        if type(groupSpellLookup) ~= "table" then
            return false
        end

        registryMatched = ResolveVariantValue(groupSpellLookup, spellID) == true
    end

    if not registryMatched then
        return false
    end

    -- Match options desaturation logic: known/talented spells are active,
    -- otherwise only spells currently seen in viewer are active.
    return IsSpellActiveInViewer(spellID, activeSpellSet)
end

local function IsSpellMarkedActive(spellID, activeSpellIDs)
    return ResolveVariantValue(activeSpellIDs, spellID) == true
end

local function BuildStaticSlotLayout(groupData, activeSpellIDs, activeSpellSet, groupSpellLookup)
    table.wipe(scratchSpellSlot)
    table.wipe(scratchPlaceholderBySpell)
    table.wipe(scratchSlotToRawSpell)
    local nextSlot = 0

    for _, sid in ipairs(groupData.spells or {}) do
        local base = GetCachedBaseSpellID(sid)
        local isActive = IsSpellMarkedActive(sid, activeSpellIDs)
        local ov = groupData.spellOverrides
        local spellOv = ov and (ov[sid] or (base and base ~= sid and ov[base])) or nil
        local isEligible = IsSpellEligible(sid, groupSpellLookup, activeSpellSet)
        local wantPlaceholder = spellOv and spellOv.placeholder and isEligible or false
        scratchPlaceholderBySpell[sid] = wantPlaceholder or nil

        if isActive or isEligible then
            scratchSlotToRawSpell[nextSlot] = sid
            StoreVariantValue(scratchSpellSlot, sid, nextSlot, true)
            nextSlot = nextSlot + 1
        end
    end

    return scratchSpellSlot, scratchPlaceholderBySpell, nextSlot
end

local placeholderPool = {}
local activePlaceholders = {}
local placeholderRefreshTimer = nil
local placeholderRetryCount = 0

local function DoPlaceholderRefresh()
    placeholderRefreshTimer = nil
    local sets = CDM.BuffGroupSets
    if not (sets and sets.groups) then
        local specID = CDM:GetCurrentSpecID()
        local hasData = specID and CDM.db and CDM.db.buffGroups and CDM.db.buffGroups[specID]
        if not specID or hasData then
            if placeholderRetryCount < 10 then
                placeholderRetryCount = placeholderRetryCount + 1
                placeholderRefreshTimer = C_Timer.NewTimer(0.15, DoPlaceholderRefresh)
            end
        end
        return
    end

    CDM:UpdateAllBuffGroupContainers()
    if CDM.QueueViewer then
        CDM:QueueViewer(CDM_C.VIEWERS.BUFF, true)
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

local function PositionFrameAtSlot(frame, container, idx, iconWPx, iconHPx, spacingPx, grow, layoutCount, anchorPoint, selfPoint)
    local xPx, yPx
    if grow == "RIGHT" then
        xPx, yPx = idx * (iconWPx + spacingPx), 0
    elseif grow == "LEFT" then
        xPx, yPx = -idx * (iconWPx + spacingPx), 0
    elseif grow == "UP" then
        xPx, yPx = 0, idx * (iconHPx + spacingPx)
    elseif grow == "DOWN" then
        xPx, yPx = 0, -idx * (iconHPx + spacingPx)
    elseif grow == "CENTER_H" then
        local startXPx = -math.floor((layoutCount - 1) * (iconWPx + spacingPx) / 2)
        xPx, yPx = startXPx + idx * (iconWPx + spacingPx), 0
    elseif grow == "CENTER_V" then
        local startYPx = math.floor((layoutCount - 1) * (iconHPx + spacingPx) / 2)
        xPx, yPx = 0, startYPx - idx * (iconHPx + spacingPx)
    end
    SetPointPixels(frame, selfPoint or "CENTER", container, anchorPoint or "CENTER", xPx or 0, yPx or 0, UIParent)
end

local function ApplyPlaceholderPixelBorder(frame, iconW, iconH)
    if not frame.pixelBorderLines then
        frame.pixelBorderLines = {}
        for i = 1, 4 do
            local line = frame:CreateTexture(nil, "OVERLAY", nil, 6)
            line:SetTexture(CDM_C.TEX_WHITE8X8)
            if line.SetSnapToPixelGrid then line:SetSnapToPixelGrid(false) end
            if line.SetTexelSnappingBias then line:SetTexelSnappingBias(0) end
            frame.pixelBorderLines[i] = line
        end
    end

    local onePx = CDM_C.GetPixelSizeForRegion(frame)
    local configuredSize = CDM_C.GetConfigValue("borderSize", 1) or 1
    local borderPixels = math.max(1, math.floor(configuredSize / onePx))
    local px = borderPixels * onePx
    local r, g, b, a = GetConfiguredBorderColor()

    local top, bottom, left, right = frame.pixelBorderLines[1], frame.pixelBorderLines[2], frame.pixelBorderLines[3], frame.pixelBorderLines[4]
    for _, line in ipairs(frame.pixelBorderLines) do
        line:SetVertexColor(r, g, b, a)
        line:Show()
    end

    top:ClearAllPoints()
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", px, 0)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -px, 0)
    top:SetHeight(px)

    bottom:ClearAllPoints()
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", px, 0)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -px, 0)
    bottom:SetHeight(px)

    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    left:SetWidth(px)

    right:ClearAllPoints()
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(px)
end

local function HidePlaceholderPixelBorder(frame)
    if frame.pixelBorderLines then
        for _, line in ipairs(frame.pixelBorderLines) do
            line:Hide()
        end
    end
end

local function ApplyPlaceholderVisuals(frame, spellID, iconW, iconH)
    local bsv = CDM.borderStyleVersion or 0
    local zoom = CDM.db and CDM.db.zoomIcons
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
    local phWPx = ToPixelCountForRegion(iconW, UIParent, 1)
    local phHPx = ToPixelCountForRegion(iconH, UIParent, 1)
    local phWSnapped = PixelsToUIForRegion(phWPx, UIParent)
    local phHSnapped = PixelsToUIForRegion(phHPx, UIParent)
    frame:SetSize(phWSnapped, phHSnapped)
    local tex = C_Spell.GetSpellTexture(spellID)
    if tex then
        frame.Icon:SetTexture(tex)
    else
        frame.Icon:SetColorTexture(0.15, 0.15, 0.15)
        frame._cdmPHSpellID = nil
    end
    CDM_C.ApplyIconTexCoord(frame.Icon, CDM.db and CDM.db.zoomIcons, phWSnapped, phHSnapped)
    frame.Icon:SetDesaturation(1)
    frame.Icon:SetAlpha(1)

    local isPixelBorder = CDM_C.IsPixelIconBorderMode and CDM_C.IsPixelIconBorderMode()
    if isPixelBorder then
        if frame.border then frame.border:Hide() end
        ApplyPlaceholderPixelBorder(frame, iconW, iconH)
    else
        HidePlaceholderPixelBorder(frame)
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
    end

    frame:Show()
end

local function AcquirePlaceholder(container, spellID, iconW, iconH)
    local frame = table.remove(placeholderPool)
    if not frame then
        frame = CreateFrame("Frame", nil, UIParent)
        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetSnapToPixelGrid(false)
        icon:SetTexelSnappingBias(0)
        frame.Icon = icon
        frame.isPlaceholder = true
    end
    frame:SetParent(container)
    frame:SetFrameLevel(1)
    ApplyPlaceholderVisuals(frame, spellID, iconW, iconH)
    if not frame:IsShown() then frame:Show() end
    return frame
end

local function ReleasePlaceholder(frame)
    frame:Hide()
    frame:ClearAllPoints()
    frame:SetParent(UIParent)
    placeholderPool[#placeholderPool + 1] = frame
end

local function ReleaseGroupPlaceholders(groupIndex)
    local group = activePlaceholders[groupIndex]
    if not group then return end
    for sid, frame in pairs(group) do
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
    local container = containers[groupIdx]
    if not container or pFrame:GetParent() ~= container then return end
    pFrame:SetAlpha(1)
end

local function OverrideCooldownText(t, pixelSize, color)
    if not t or not t.SetFont then return end
    if pixelSize then
        local fp, _, ff = t:GetFont()
        if fp then t:SetFont(fp, pixelSize, ff) end
    end
    if color then
        t:SetTextColor(color.r, color.g, color.b, color.a or 1)
    end
end

local function GetCooldownFontRegions(cd, frameData)
    local regions = frameData and frameData.cdmCdFontRegions
    if regions then
        return regions
    end
    regions = {}
    for ri = 1, select("#", cd:GetRegions()) do
        local region = select(ri, cd:GetRegions())
        if region and region.IsObjectType and region:IsObjectType("FontString") then
            regions[#regions + 1] = region
        end
    end
    if frameData then
        frameData.cdmCdFontRegions = regions
    end
    return regions
end

local function OverrideCooldownRegions(cd, pixelSize, color, frameData)
    local regions = GetCooldownFontRegions(cd, frameData)
    for _, region in ipairs(regions) do
        OverrideCooldownText(region, pixelSize, color)
    end
end

local function GetSpellOverride(groupData, spellID)
    return ResolveSpellOverrideEntry(groupData and groupData.spellOverrides, spellID)
end

local function SetCooldownTextHidden(frame, hidden, frameData)
    local cd = frame.Cooldown
    if cd then
        if cd.SetHideCountdownNumbers then
            cd:SetHideCountdownNumbers(hidden)
        end
        local t = cd.Text or cd.text
        if t then
            if hidden then t:Hide(); t:SetAlpha(0) else t:Show(); t:SetAlpha(1) end
        end
        local regions = GetCooldownFontRegions(cd, frameData)
        for _, region in ipairs(regions) do
            if hidden then region:Hide(); region:SetAlpha(0) else region:Show(); region:SetAlpha(1) end
        end
    end
    if frame.Time then
        if hidden then frame.Time:Hide(); frame.Time:SetAlpha(0) else frame.Time:Show(); frame.Time:SetAlpha(1) end
    end
    if frame.Duration then
        if hidden then frame.Duration:Hide(); frame.Duration:SetAlpha(0) else frame.Duration:Show(); frame.Duration:SetAlpha(1) end
    end
end

function CDM:RestoreCooldownTextIfHidden(frame)
    local frameData = GetFrameData(frame)
    if frameData.cdmCooldownTextHidden then
        SetCooldownTextHidden(frame, false, frameData)
        frameData.cdmCooldownTextHidden = nil
    end
end

local function HideFrameVisuals(frame, frameData)
    if frame.Icon then frame.Icon:SetAlpha(0) end
    if frame.Cooldown and frame.Cooldown.SetDrawSwipe then
        frame.Cooldown:SetDrawSwipe(false)
    end
    if frameData.borderFrame and frameData.borderFrame.border then
        frameData.borderFrame.border:Hide()
    end
    if frameData.pixelIconBorderFrame then
        frameData.pixelIconBorderFrame:Hide()
    end
    frameData.cdmVisualsHidden = true
end

local function RestoreFrameVisuals(frame, frameData)
    if frame.Icon then frame.Icon:SetAlpha(1) end
    if frame.Cooldown and frame.Cooldown.SetDrawSwipe then
        frame.Cooldown:SetDrawSwipe(true)
    end
    if frameData.borderFrame and frameData.borderFrame.border then
        frameData.borderFrame.border:Show()
    end
    if frameData.pixelIconBorderFrame then
        frameData.pixelIconBorderFrame:Show()
    end
    frameData.cdmVisualsHidden = nil
end

function CDM:RestoreVisualsIfHidden(frame)
    local frameData = GetFrameData(frame)
    if frameData.cdmVisualsHidden then
        RestoreFrameVisuals(frame, frameData)
    end
end

local function ApplyGlowForGroupedFrame(frame, specID)
    if not (frame and CDM.Glow) then return end
    if not specID then
        CDM.Glow:RequestBuffGlow(frame, false, nil, nil)
        return
    end

    local glowEnabled, glowColor, glowSourceID = false, nil, nil
    if CDM.ResolveBuffGlowState then
        glowEnabled, glowColor, glowSourceID = CDM:ResolveBuffGlowState(frame, specID, true)
    end
    CDM.Glow:RequestBuffGlow(frame, glowEnabled, glowColor, glowSourceID)
end

local function GetOrCreateGroupContainer(groupIndex)
    if containers[groupIndex] then
        return containers[groupIndex]
    end

    local name = "Ayije_CDM_BuffGroup" .. groupIndex
    local container = CreateFrame("Frame", name, UIParent)
    container:SetSize(1, 1)
    container:SetClampedToScreen(false)
    container:Show()

    containers[groupIndex] = container
    return container
end

local function GetContainerForAnchorTarget(anchorTarget)
    local anchorContainers = CDM.anchorContainers
    if not anchorContainers then return nil end
    if anchorTarget == "essential" then
        return anchorContainers[CDM_C.VIEWERS.ESSENTIAL]
    end
    if anchorTarget == "buff" then
        return anchorContainers[CDM_C.VIEWERS.BUFF]
    end
    return nil
end

local function AnchorContainerToTarget(container, targetContainer, anchorPoint, relativePoint, offsetX, offsetY)
    if not targetContainer or not targetContainer:IsShown() then
        container:Hide()
        return false
    end
    container:ClearAllPoints()
    SetPixelPerfectPoint(container, anchorPoint, targetContainer, relativePoint, offsetX, offsetY)
    if not container:IsShown() then
        container:Show()
    end
    return true
end

local function UpdateGroupContainerPosition(groupIndex, groupData)
    local container = containers[groupIndex]
    if not container or not groupData then return end

    local anchorTarget = groupData.anchorTarget or "screen"
    local anchorPoint = groupData.anchorPoint or "CENTER"
    local relativePoint = groupData.anchorRelativeTo or "CENTER"
    local offsetX = groupData.offsetX or 0
    local offsetY = groupData.offsetY or 0

    local iconW = groupData.iconWidth or 30
    local iconH = groupData.iconHeight or 30
    local iconWPx = ToPixelCountForRegion(iconW, UIParent, 1)
    local iconHPx = ToPixelCountForRegion(iconH, UIParent, 1)
    container:SetSize(PixelsToUIForRegion(iconWPx, UIParent), PixelsToUIForRegion(iconHPx, UIParent))

    if anchorTarget == "playerFrame" then
        CDM.AnchorToPlayerFrame(
            container,
            relativePoint,
            offsetX, offsetY,
            "CDM_BuffGroup_" .. groupIndex,
            false,
            anchorPoint
        )
    else
        local targetContainer = GetContainerForAnchorTarget(anchorTarget)
        if targetContainer then
            AnchorContainerToTarget(container, targetContainer, anchorPoint, relativePoint, offsetX, offsetY)
        else
            container:ClearAllPoints()
            SetPixelPerfectPoint(container, "CENTER", UIParent, "CENTER", offsetX, offsetY)
        end
    end
end

function CDM:CreateBuffGroupContainer(groupIndex)
    return GetOrCreateGroupContainer(groupIndex)
end

function CDM:UpdateBuffGroupContainerPosition(groupIndex)
    local sets = self.BuffGroupSets
    if not sets or not sets.groups then return end
    local groupData = sets.groups[groupIndex]
    if not groupData then return end
    UpdateGroupContainerPosition(groupIndex, groupData)
end

local CALLBACK_PREFIX = "CDM_BuffGroup_"
local registeredCallbackIndices = {}

local function SyncPositionCallbacks()
    local sets = CDM.BuffGroupSets
    local groups = sets and sets.groups
    local needed = {}

    if groups then
        for idx, gd in ipairs(groups) do
            if (gd.anchorTarget or "screen") == "playerFrame" then
                needed[idx] = true
            end
        end
    end

    for idx in pairs(needed) do
        if not registeredCallbackIndices[idx] then
            local capturedIdx = idx
            CDM.RegisterTrackerPositionCallback(CALLBACK_PREFIX .. capturedIdx, function()
                local s = CDM.BuffGroupSets
                local g = s and s.groups and s.groups[capturedIdx]
                if g and (g.anchorTarget or "screen") == "playerFrame" then
                    CDM.InvalidateTrackerAnchorCache(containers[capturedIdx])
                    UpdateGroupContainerPosition(capturedIdx, g)
                end
            end)
            registeredCallbackIndices[idx] = true
        end
    end

    local toRemove
    for idx in pairs(registeredCallbackIndices) do
        if not needed[idx] then
            if not toRemove then toRemove = {} end
            toRemove[#toRemove + 1] = idx
        end
    end
    if toRemove then
        for _, idx in ipairs(toRemove) do
            CDM.UnregisterTrackerPositionCallback(CALLBACK_PREFIX .. idx)
            registeredCallbackIndices[idx] = nil
        end
    end
end

function CDM:UpdateAllBuffGroupContainers()
    local sets = self.BuffGroupSets
    if not sets or not sets.groups then
        for idx, container in pairs(containers) do
            container:Hide()
            ReleaseGroupPlaceholders(idx)
        end
        SyncPositionCallbacks()
        return
    end

    local activeIndices = {}
    for groupIndex, groupData in ipairs(sets.groups) do
        local container = GetOrCreateGroupContainer(groupIndex)
        UpdateGroupContainerPosition(groupIndex, groupData)
        local at = groupData.anchorTarget or "screen"
        if not container:IsShown() and at ~= "essential" and at ~= "buff" and at ~= "playerFrame" then
            container:Show()
        end
        activeIndices[groupIndex] = true
    end

    for idx, container in pairs(containers) do
        if not activeIndices[idx] then
            container:Hide()
            ReleaseGroupPlaceholders(idx)
        end
    end

    SyncPositionCallbacks()
end

function CDM:PositionBuffGroupFrames(groupIndex, frames)
    ClearSpellVariantResolutionCaches()

    local sets = self.BuffGroupSets
    if not sets or not sets.groups then return end

    local groupData = sets.groups[groupIndex]
    if not groupData then return end

    local container = GetOrCreateGroupContainer(groupIndex)

    if not container:IsShown() then
        for _, frame in ipairs(frames) do
            frame:Hide()
        end
        ReleaseGroupPlaceholders(groupIndex)
        return
    end

    local grow = groupData.grow
    if grow ~= "RIGHT" and grow ~= "LEFT" and grow ~= "UP" and grow ~= "DOWN" and grow ~= "CENTER_H" and grow ~= "CENTER_V" then
        grow = "RIGHT"
    end
    local spacing = groupData.spacing or 4
    local iconW = groupData.iconWidth or 30
    local iconH = groupData.iconHeight or 30
    local anchorPoint = groupData.anchorPoint or "CENTER"
    local selfPoint = DeriveSelfPoint(anchorPoint, grow)
    local iconWPx = ToPixelCountForRegion(iconW, UIParent, 1)
    local iconHPx = ToPixelCountForRegion(iconH, UIParent, 1)
    local spacingPx = ToPixelCountForRegion(spacing, UIParent)
    local iconWSnapped = PixelsToUIForRegion(iconWPx, UIParent)
    local iconHSnapped = PixelsToUIForRegion(iconHPx, UIParent)
    local count = #frames
    local isStatic = groupData.staticDisplay and groupData.spells
    local layoutCount = isStatic and #groupData.spells or count

    container:SetSize(iconWSnapped, iconHSnapped)

    if count == 0 and not isStatic then
        ReleaseGroupPlaceholders(groupIndex)
        return
    end

    local spellSlot
    local activeSpellSet
    local placeholderBySpell
    if groupData.spells then
        table.wipe(scratchSpellOrder)
        for i, sid in ipairs(groupData.spells) do
            StoreVariantValue(scratchSpellOrder, sid, i, true)
        end
        if count > 1 then
            table.sort(frames, function(a, b)
                local aID = GetFrameData(a).buffCategorySpellID
                local bID = GetFrameData(b).buffCategorySpellID
                local aOrd = aID and scratchSpellOrder[aID] or 999
                local bOrd = bID and scratchSpellOrder[bID] or 999
                if aOrd ~= bOrd then return aOrd < bOrd end
                return GetGroupedFrameStableSortID(a) < GetGroupedFrameStableSortID(b)
            end)
        end
    end

    if isStatic then
        activeSpellSet = BuildActiveSpellSet()
        table.wipe(scratchActiveSpellIDs)
        for _, frame in ipairs(frames) do
            local sid = GetFrameData(frame).buffCategorySpellID
            if sid then
                StoreVariantValue(scratchActiveSpellIDs, sid, true, false)
            end
        end
        local groupSpellLookup = BuildGroupSpellLookup(groupData.spells)
        spellSlot, placeholderBySpell, layoutCount = BuildStaticSlotLayout(groupData, scratchActiveSpellIDs, activeSpellSet, groupSpellLookup)
        if layoutCount <= 0 then
            ReleaseGroupPlaceholders(groupIndex)
            return
        end
    else
        spellSlot = nil
    end


    local countPos = groupData.countPosition or "BOTTOMRIGHT"
    local countOX = groupData.countOffsetX or 0
    local countOY = groupData.countOffsetY or 0
    local countFS = groupData.countFontSize or 15
    local countColor = groupData.countColor or { r = 1, g = 1, b = 1, a = 1 }
    local cdFS = groupData.cooldownFontSize or 12
    local cdColor = groupData.cooldownColor or { r = 1, g = 1, b = 1 }
    local specID = CDM.GetCurrentSpecID and CDM:GetCurrentSpecID() or nil

    for i, frame in ipairs(frames) do
        local idx
        local rawSpellID
        if spellSlot then
            local sid = GetFrameData(frame).buffCategorySpellID
            if sid then
                idx = ResolveVariantValue(spellSlot, sid)
                if idx then
                    rawSpellID = scratchSlotToRawSpell[idx]
                end
            end
            idx = idx or (i - 1)
        else
            idx = i - 1
        end
        frame:SetParent(UIParent)
        frame:ClearAllPoints()
        frame:SetSize(iconWSnapped, iconHSnapped)
        if frame.Icon then
            CDM_C.ApplyIconTexCoord(frame.Icon, CDM.db and CDM.db.zoomIcons, iconWSnapped, iconHSnapped)
        end

        PositionFrameAtSlot(frame, container, idx, iconWPx, iconHPx, spacingPx, grow, layoutCount, anchorPoint, selfPoint)

        local frameData = GetFrameData(frame)
        local fSpellID = frameData.buffCategorySpellID
        local spellOv = GetSpellOverride(groupData, fSpellID)
        local useTextOv = spellOv and spellOv.textOverride

        local fCountPos = (useTextOv and spellOv.countPosition) or countPos
        local fCountOX  = (useTextOv and spellOv.countOffsetX)  or countOX
        local fCountOY  = (useTextOv and spellOv.countOffsetY)  or countOY
        local fCountFS  = (useTextOv and spellOv.countFontSize)  or countFS
        local fCountColor = (useTextOv and spellOv.countColor)  or countColor
        local fCdFS     = (useTextOv and spellOv.cooldownFontSize) or cdFS
        local fCdColor  = (useTextOv and spellOv.cooldownColor) or cdColor
        local fCdPixelSize = fCdFS and CDM_C.GetPixelFontSize(fCdFS)

        local countText = frame.Applications and frame.Applications.Applications
        if countText then
            local fCountPixelSize = fCountFS and CDM_C.GetPixelFontSize(fCountFS)
            if frameData.cdmLastCountFS ~= fCountPixelSize
                or frameData.cdmLastCountPos ~= fCountPos
                or frameData.cdmLastCountOX ~= fCountOX
                or frameData.cdmLastCountOY ~= fCountOY
                or frameData.cdmLastCountColorR ~= fCountColor.r
                or frameData.cdmLastCountColorG ~= fCountColor.g
                or frameData.cdmLastCountColorB ~= fCountColor.b then
                if fCountPixelSize then
                    local fontPath, _, fontFlags = countText:GetFont()
                    if fontPath then
                        countText:SetFont(fontPath, fCountPixelSize, fontFlags)
                    end
                end
                if fCountColor then
                    countText:SetTextColor(fCountColor.r, fCountColor.g, fCountColor.b, fCountColor.a or 1)
                end
                countText:ClearAllPoints()
                SetPixelPerfectPoint(countText, "CENTER", frame, fCountPos, fCountOX, fCountOY)
                frameData.cdmLastCountFS = fCountPixelSize
                frameData.cdmLastCountPos = fCountPos
                frameData.cdmLastCountOX = fCountOX
                frameData.cdmLastCountOY = fCountOY
                frameData.cdmLastCountColorR = fCountColor.r
                frameData.cdmLastCountColorG = fCountColor.g
                frameData.cdmLastCountColorB = fCountColor.b
            end
        end

        local fHideCooldown = spellOv and spellOv.hideCooldown

        if fHideCooldown then
            SetCooldownTextHidden(frame, true, frameData)
            frameData.cdmCooldownTextHidden = true
        else
            if frameData.cdmCooldownTextHidden then
                SetCooldownTextHidden(frame, false, frameData)
                frameData.cdmCooldownTextHidden = nil
            end
            if fCdFS or fCdColor then
                local cd = frame.Cooldown
                if cd then
                    OverrideCooldownText(cd.Text or cd.text, fCdPixelSize, fCdColor)
                    OverrideCooldownRegions(cd, fCdPixelSize, fCdColor, frameData)
                end
                OverrideCooldownText(frame.Time, fCdPixelSize, fCdColor)
                OverrideCooldownText(frame.Duration, fCdPixelSize, fCdColor)
            end
        end

        local fHideVisuals = spellOv and spellOv.hideVisuals

        if fHideVisuals then
            HideFrameVisuals(frame, frameData)
        elseif frameData.cdmVisualsHidden then
            RestoreFrameVisuals(frame, frameData)
        end

        if fHideVisuals then
            if CDM.Glow then CDM.Glow:RequestBuffGlow(frame, false, nil, nil) end
        else
            ApplyGlowForGroupedFrame(frame, specID)
        end

        if isStatic then
            frameData.cdmStaticGroupIdx = groupIndex
            frameData.cdmStaticGroupSpellID = rawSpellID
            frameData.cdmStaticPlaceholderEligible = rawSpellID and placeholderBySpell and placeholderBySpell[rawSpellID] and true or false
            if not frameData.cdmBuffGroupOnHideHooked then
                frameData.cdmBuffGroupOnHideHooked = true
                frame:HookScript("OnHide", OnGroupedBuffFrameHide)
            end
        else
            frameData.cdmStaticGroupIdx = nil
            frameData.cdmStaticGroupSpellID = nil
            frameData.cdmStaticPlaceholderEligible = nil
        end
    end

    if isStatic then
        local existing = activePlaceholders[groupIndex]
        if not existing then
            existing = {}
            activePlaceholders[groupIndex] = existing
        end
        for sid, pFrame in pairs(existing) do
            local wantPlaceholder = placeholderBySpell and placeholderBySpell[sid]
            if not spellSlot[sid] or not wantPlaceholder then
                ReleasePlaceholder(pFrame)
                existing[sid] = nil
            end
        end

        for _, sid in ipairs(groupData.spells) do
            local slotIdx = spellSlot[sid]
            local wantPlaceholder = placeholderBySpell and placeholderBySpell[sid]
            if slotIdx ~= nil and wantPlaceholder then
                local pFrame = existing[sid]
                if not pFrame then
                    pFrame = AcquirePlaceholder(container, sid, iconW, iconH)
                    existing[sid] = pFrame
                else
                    ApplyPlaceholderVisuals(pFrame, sid, iconW, iconH)
                end
                pFrame:ClearAllPoints()
                PositionFrameAtSlot(pFrame, container, slotIdx, iconWPx, iconHPx, spacingPx, grow, layoutCount, anchorPoint, selfPoint)
                pFrame:SetAlpha(IsSpellMarkedActive(sid, scratchActiveSpellIDs) and 0 or 1)
            end
        end
    else
        ReleaseGroupPlaceholders(groupIndex)
    end
end

CDM:RegisterRefreshCallback("buffGroups", function()
    local toRelease
    for idx in pairs(activePlaceholders) do
        if not toRelease then toRelease = {} end
        toRelease[#toRelease + 1] = idx
    end
    if toRelease then
        for _, idx in ipairs(toRelease) do
            ReleaseGroupPlaceholders(idx)
        end
    end
    CDM:MarkSpecDataDirty()
    CDM:RefreshSpecData()
    CDM:UpdateAllBuffGroupContainers()
    if CDM.QueueViewer then
        CDM:QueueViewer(CDM_C.VIEWERS.BUFF, true)
    end
end, 29, { "spec_data", "viewers", "trackers_layout" })

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
CDM:RegisterInternalCallback("OnTalentDataChanged", QueuePlaceholderReadinessRefresh)
CDM:RegisterInternalCallback("OnSpecStateChanged", OnPlaceholderSpecStateChanged)

function CDM:GetUngroupedBuffOverride(spellID)
    if not spellID then return nil end
    local specID = self.GetCurrentSpecID and self:GetCurrentSpecID()
    if not specID then return nil end
    local db = self.db
    if not db or not db.ungroupedBuffOverrides then return nil end
    local specOv = db.ungroupedBuffOverrides[specID]
    if not specOv then return nil end
    return ResolveSpellOverrideEntry(specOv, spellID)
end

function CDM:ApplyUngroupedBuffOverrides(frame)
    if not frame then return end
    local frameData = GetFrameData(frame)
    local ov
    if self.GetSpellIDCandidates then
        local candidates = self:GetSpellIDCandidates(frame, true)
        for _, candidateID in ipairs(candidates) do
            ov = self:GetUngroupedBuffOverride(candidateID)
            if ov then
                break
            end
        end
    end

    if not ov then
        local spellID = CDM.GetBaseSpellID and CDM.GetBaseSpellID(frame)
        if not spellID then return end
        ov = self:GetUngroupedBuffOverride(spellID)
    end
    if not ov then return end

    local db = self.db

    if ov.hideCooldown then
        SetCooldownTextHidden(frame, true, frameData)
        frameData.cdmCooldownTextHidden = true
    end

    if ov.hideVisuals then
        HideFrameVisuals(frame, frameData)
        if CDM.Glow then CDM.Glow:RequestBuffGlow(frame, false, nil, nil) end
    end

    local useTextOv = ov.textOverride

    if not ov.hideCooldown then
        local cdFS = (useTextOv and ov.cooldownFontSize) or (db and db.buffCooldownFontSize or 12)
        local cdColor = (useTextOv and ov.cooldownColor) or (db and db.buffCooldownColor)
        local cdPixelSize = cdFS and CDM_C.GetPixelFontSize(cdFS)
        local cd = frame.Cooldown
        if cd then
            OverrideCooldownText(cd.Text or cd.text, cdPixelSize, cdColor)
            OverrideCooldownRegions(cd, cdPixelSize, cdColor, frameData)
        end
        OverrideCooldownText(frame.Time, cdPixelSize, cdColor)
        OverrideCooldownText(frame.Duration, cdPixelSize, cdColor)
    end

    local countText = frame.Applications and frame.Applications.Applications
    if countText then
        local countFS = (useTextOv and ov.countFontSize) or (db and db.countFontSize or 15)
        local countColor = (useTextOv and ov.countColor) or (db and db.countColor)
        local countPos = (useTextOv and ov.countPosition) or (db and db.countPositionMain or "TOP")
        local countOX = (useTextOv and ov.countOffsetX) or (db and db.countOffsetXMain or 0)
        local countOY = (useTextOv and ov.countOffsetY) or (db and db.countOffsetYMain or 0)
        if countFS then
            local fontPath, _, fontFlags = countText:GetFont()
            if fontPath then
                countText:SetFont(fontPath, CDM_C.GetPixelFontSize(countFS), fontFlags)
            end
        end
        if countColor then
            countText:SetTextColor(countColor.r, countColor.g, countColor.b, countColor.a or 1)
        end
        countText:ClearAllPoints()
        SetPixelPerfectPoint(countText, "CENTER", frame, countPos, countOX, countOY)
    end
end
