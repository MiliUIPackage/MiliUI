local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local L = CDM.L
local ctx = CDM._LayoutCtx

local CDM_C = ctx.CDM_C
local VIEWERS = ctx.VIEWERS

local ResolveBaseSpellID = ctx.ResolveBaseSpellID
local GetLayoutConfig = ctx.GetLayoutConfig
local ComputeUtilityContainerSize = ctx.ComputeUtilityContainerSize

local utilityVisibleCountCache = {
    valid = false,
    count = 0,
}

function CDM:InvalidateUtilityVisibleCountCache()
    utilityVisibleCountCache.valid = false
end

local function ComputeUtilityVisibleCount()
    local utilityCount = 0
    local viewer = _G[VIEWERS.UTILITY]
    if viewer and viewer.itemFramePool then
        for frame in viewer.itemFramePool:EnumerateActive() do
            if frame:IsShown() then
                local spellID = ResolveBaseSpellID(frame)
                if spellID then
                    utilityCount = utilityCount + 1
                end
            end
        end
    end
    return utilityCount
end

local function GetUtilityVisibleCount()
    if utilityVisibleCountCache.valid then
        return utilityVisibleCountCache.count
    end

    local count = ComputeUtilityVisibleCount()
    utilityVisibleCountCache.count = count
    utilityVisibleCountCache.valid = true
    return count
end

function CDM:GetUtilityVisibleCount()
    return GetUtilityVisibleCount()
end

local Pixel = CDM.Pixel
local Snap = Pixel.Snap
local HalfFloor = Pixel.HalfFloor

local function SetUtilityAnchor(utilContainer, essContainer, utilHalfW, utilityXOffset, utilityYOffset, spacing)
    local essHalfW = HalfFloor(essContainer:GetWidth() or 0)
    Pixel.SetPoint(utilContainer, "TOPLEFT", essContainer, "BOTTOMLEFT", essHalfW - utilHalfW + utilityXOffset, -spacing + utilityYOffset)
end

local function AnchorMainLayoutContainer(frame, isBuffContainer, relativePoint, x, y, yOffset)
    if not frame then
        return
    end

    if isBuffContainer then
        Pixel.SetPoint(frame, "BOTTOM", UIParent, relativePoint, x, (y or 0) + (yOffset or 0))
        return
    end

    local halfW = HalfFloor(frame:GetWidth() or 0)
    Pixel.SetPoint(frame, "TOPLEFT", UIParent, relativePoint, x - halfW, y)
end

local function EnsureDBSubTable(parent, key)
    local t = parent[key]
    if not t then
        t = {}
        parent[key] = t
    end
    return t
end

local function SetRegionBlendMode(blendMode, ...)
    local n = select("#", ...)
    for i = 1, n do
        local region = select(i, ...)
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            region:SetBlendMode(blendMode)
        end
    end
end

function CDM:UpdateUtilityContainerPosition()
    if InCombatLockdown() then
        CDM.combatDirtyViewers[VIEWERS.UTILITY] = true
        return
    end

    local essContainer = self.anchorContainers[VIEWERS.ESSENTIAL]
    local utilContainer = self.anchorContainers[VIEWERS.UTILITY]
    local _, _, sizeUtility, _, spacing, _, utilityYOffset, maxRowUtil, utilityVertical, utilityXOffset = GetLayoutConfig()

    if not essContainer or not utilContainer then return end

    local utilityCount = GetUtilityVisibleCount()

    local containerWidth, containerHeight = ComputeUtilityContainerSize(
        utilityCount > 0 and utilityCount or 0, sizeUtility, spacing, maxRowUtil, utilityVertical
    )
    utilContainer:SetSize(Snap(containerWidth), Snap(containerHeight))

    local utilHalfW = HalfFloor(Snap(containerWidth))
    utilContainer:ClearAllPoints()
    SetUtilityAnchor(utilContainer, essContainer, utilHalfW, utilityXOffset, utilityYOffset, spacing)
end

local FALLBACK_POSITION = {
    point = "CENTER",
    x = 0,
    y = -201,
}

local FALLBACK_BUFF_POSITION = {
    point = "CENTER",
    x = 0,
    y = -149,
}

local function GetPositionSettings(viewerName, layoutName)
    local db = CDM.db
    if not db then
        local fallbackPosition = FALLBACK_POSITION
        if viewerName == VIEWERS.BUFF then
            fallbackPosition = FALLBACK_BUFF_POSITION
        end
        return fallbackPosition
    end

    local editModePositions = EnsureDBSubTable(db, "editModePositions")
    local viewerTable = EnsureDBSubTable(editModePositions, viewerName)
    local defaultY = -201
    if viewerName == VIEWERS.BUFF then
        defaultY = -149
    end

    if not viewerTable[layoutName] then
        viewerTable[layoutName] = {
            point = "CENTER",
            x = 0,
            y = defaultY
        }
    end

    return viewerTable[layoutName]
end

local FALLBACK_BUFF_BAR_POSITION = {
    point = "CENTER",
    x = 0,
    y = -324
}

local function GetBuffBarPositionSettings()
    local db = CDM.db
    if not db then
        return FALLBACK_BUFF_BAR_POSITION
    end

    local editModePositions = EnsureDBSubTable(db, "editModePositions")
    local viewerTable = EnsureDBSubTable(editModePositions, VIEWERS.BUFF_BAR)
    if not viewerTable.Default then
        viewerTable.Default = {
            point = "CENTER",
            x = 0,
            y = -324
        }
    end
    return viewerTable.Default
end

ctx.GetBuffBarPositionSettings = GetBuffBarPositionSettings

function CDM:GetBuffContainerYOffset()
    local moveBuffsDown = CDM_C.GetConfigValue("resourcesMoveBuffsDown", false)
    if moveBuffsDown and self.resourcesSpecReady then
        local hasBar2 = self.HasSecondaryResourceBar and self:HasSecondaryResourceBar()
        if not hasBar2 then
            local bar2Height = CDM_C.GetConfigValue("resourcesBar2Height", 16)
            local barSpacing = CDM_C.GetConfigValue("resourcesBarSpacing", 2)
            bar2Height = Snap(bar2Height or 0)
            barSpacing = Snap(barSpacing or 0)

            return -(bar2Height + barSpacing)
        end
    end
    return 0
end

function CDM:UpdateBuffContainerPosition()
    local buffContainer = self.anchorContainers[VIEWERS.BUFF]
    if not buffContainer then return end

    local savedPos = GetPositionSettings(VIEWERS.BUFF, "Default")
    local yOffset = self:GetBuffContainerYOffset()

    buffContainer:ClearAllPoints()
    AnchorMainLayoutContainer(buffContainer, true, savedPos.point, savedPos.x, savedPos.y, yOffset)

end

function CDM:ReanchorContainer(vName)
    if InCombatLockdown() then return end
    local container = self.anchorContainers and self.anchorContainers[vName]
    if not container then return end

    if vName == VIEWERS.ESSENTIAL then
        local savedPos = GetPositionSettings(VIEWERS.ESSENTIAL, "Default")
        container:ClearAllPoints()
        AnchorMainLayoutContainer(container, false, savedPos.point, savedPos.x, savedPos.y)
    elseif vName == VIEWERS.UTILITY then
        local essContainer = self.anchorContainers[VIEWERS.ESSENTIAL]
        if not essContainer then return end
        local _, _, _, _, spacing, _, utilityYOffset, _, _, utilityXOffset = GetLayoutConfig()
        local utilHalfW = HalfFloor(container:GetWidth())
        container:ClearAllPoints()
        SetUtilityAnchor(container, essContainer, utilHalfW, utilityXOffset, utilityYOffset, spacing)
    end
end

function CDM:UpdateEssentialContainerPosition()
    if InCombatLockdown() then
        CDM.combatDirtyViewers[VIEWERS.ESSENTIAL] = true
        return
    end

    self:ReanchorContainer(VIEWERS.ESSENTIAL)
    self:UpdateUtilityContainerPosition()
end

local function GetFramePointCoords(frame, point)
    if not frame or not point or not frame.GetLeft then return nil, nil end
    local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    local centerX, centerY = frame:GetCenter()
    if not (left and right and top and bottom and centerX and centerY) then return nil, nil end

    if point == "CENTER" then return centerX, centerY
    elseif point == "TOP" then return centerX, top
    elseif point == "BOTTOM" then return centerX, bottom
    elseif point == "LEFT" then return left, centerY
    elseif point == "RIGHT" then return right, centerY
    elseif point == "TOPLEFT" then return left, top
    elseif point == "TOPRIGHT" then return right, top
    elseif point == "BOTTOMLEFT" then return left, bottom
    elseif point == "BOTTOMRIGHT" then return right, bottom
    end
    return centerX, centerY
end

local function ResolveDraggedCoords(frame, anchorPoint, relativePoint, x, y)
    local anchorX, anchorY = GetFramePointCoords(frame, anchorPoint)
    local relX, relY = GetFramePointCoords(UIParent, relativePoint)
    if anchorX and relX then
        return anchorX - relX, anchorY - relY
    end
    return x, y
end

local function SetupDraggableContainer(container, lockKey, overlayOpts)
    overlayOpts = overlayOpts or {}

    local function IsLocked()
        return CDM_C.GetConfigValue(lockKey, true) ~= false
    end

    local function IsEditModeActive()
        local editModeFrame = _G.EditModeManagerFrame
        return CDM.isEditModeActive or (editModeFrame and editModeFrame:IsShown())
    end

    local isLocked = IsLocked()
    if not InCombatLockdown() then
        container:SetMovable(not isLocked)
        container:EnableMouse(not isLocked)
    end
    container:SetClampedToScreen(true)
    container:RegisterForDrag("LeftButton")

    container:SetScript("OnDragStart", function(self)
        if not InCombatLockdown() and not IsLocked() then
            self:StartMoving()
        end
    end)

    if not container.helperText then
        local helperText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        helperText:SetPoint("BOTTOM", container, "TOP", 0, 8)
        helperText:SetText(L["Click and drag to move - /cdm > Positions to lock"])
        helperText:SetTextColor(CDM_C.GOLD.r, CDM_C.GOLD.g, CDM_C.GOLD.b, 1)
        CDM_C.ApplyShadow(helperText)
        container.helperText = helperText
    end

    if not container.dragOverlay then
        local overlayParent = overlayOpts.parent or container
        local overlay = CreateFrame("Frame", nil, overlayParent, "NineSliceCodeTemplate")
        overlay:SetAllPoints(container)
        if overlayOpts.strata then
            overlay:SetFrameStrata(overlayOpts.strata)
        end
        if overlayOpts.level then
            overlay:SetFrameLevel(overlayOpts.level)
        else
            overlay:SetFrameLevel(container:GetFrameLevel() + 1)
        end
        overlay:EnableMouse(false)

        if NineSliceUtil and NineSliceUtil.ApplyLayout then
            local overlayLayout = {
                ["TopRightCorner"] = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = 8, y = 8 },
                ["TopLeftCorner"] = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = -8, y = 8 },
                ["BottomLeftCorner"] = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = -8, y = -8 },
                ["BottomRightCorner"] = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = 8, y = -8 },
                ["TopEdge"] = { atlas = "_%s-NineSlice-EdgeTop" },
                ["BottomEdge"] = { atlas = "_%s-NineSlice-EdgeBottom" },
                ["LeftEdge"] = { atlas = "!%s-NineSlice-EdgeLeft" },
                ["RightEdge"] = { atlas = "!%s-NineSlice-EdgeRight" },
                ["Center"] = { atlas = "%s-NineSlice-Center", x = -8, y = 8, x1 = 8, y1 = -8 },
            }
            NineSliceUtil.ApplyLayout(overlay, overlayLayout, "editmode-actionbar-highlight")
            SetRegionBlendMode("ADD", overlay:GetRegions())
            overlay:SetAlpha(0.4)
        end

        overlay:Hide()
        container.dragOverlay = overlay
    end

    local function UpdateHelperText()
        local unlocked = not IsLocked()
        if not InCombatLockdown() then
            container:SetMovable(unlocked)
            container:EnableMouse(unlocked)
        end
        if container.helperText then
            container.helperText:SetShown(unlocked)
        end
        if container.dragOverlay then
            container.dragOverlay:SetShown(unlocked and not IsEditModeActive())
        end
    end
    UpdateHelperText()
    container.UpdateHelperText = UpdateHelperText
    container.lockKey = lockKey
end

local function CreateBaseContainer(name)
    local container = _G[name] or CreateFrame("Frame", name, UIParent)
    container:SetParent(UIParent)
    container:SetFrameStrata(CDM_C.STRATA_MAIN)
    container:SetFrameLevel(10)
    if container.SetPreventSecretValues then
        container:SetPreventSecretValues(true)
    end
    return container
end

function CDM:GetOrCreateAnchorContainer(viewer)
    local sizeEssRow1, _, _, sizeBuff = GetLayoutConfig()
    local vName = viewer:GetName()

    if self.anchorContainers[vName] then
        return self.anchorContainers[vName]
    end

    if vName == VIEWERS.ESSENTIAL or vName == VIEWERS.BUFF then
        local container = CreateBaseContainer(vName .. "_CDM_Container")
        local initH = (vName == VIEWERS.ESSENTIAL) and sizeEssRow1.h or sizeBuff.h
        if vName == VIEWERS.ESSENTIAL then
            container:SetSize(Snap(400), Snap(initH))
        else
            container:SetSize(Pixel.SnapEven(400), Snap(initH))
        end

        self.anchorContainers[vName] = container
        self:UpdateEditModeSelectionOverlay(vName)

        local savedPos = GetPositionSettings(vName, "Default")
        container:ClearAllPoints()
        AnchorMainLayoutContainer(container, vName == VIEWERS.BUFF, savedPos.point, savedPos.x, savedPos.y)

        container:Show()

        return container
    elseif vName == VIEWERS.BUFF_BAR then
        local container = CreateBaseContainer(vName .. "_CDM_Container")
        container:SetSize(300, 200)

        SetupDraggableContainer(container, "buffBarContainerLocked", {
            parent = UIParent, strata = "DIALOG", level = 100
        })

        container:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()

            local _, _, relativePoint, x, y = self:GetPoint()
            if relativePoint and x and y then
                local growDirection = CDM_C.GetConfigValue("buffBarGrowDirection", "DOWN")
                local anchorPoint = growDirection == "DOWN" and "TOP" or "BOTTOM"
                x, y = ResolveDraggedCoords(self, anchorPoint, relativePoint, x, y)

                local settings = GetBuffBarPositionSettings()
                settings.point = relativePoint
                settings.x = Snap(x)
                settings.y = Snap(y)

                CDM:UpdateBuffBarContainerPosition()

                CDM:NotifyPositionSliderUpdate("buffBar", settings.x, settings.y, true)
            end
        end)

        self.anchorContainers[vName] = container
        self:UpdateEditModeSelectionOverlay(vName)

        self:UpdateBuffBarContainerPosition()

        container:Show()

        return container
    else
        local container = CreateBaseContainer(vName .. "_AnchorContainer")

        self.anchorContainers[vName] = container
        self:UpdateEditModeSelectionOverlay(vName)

        if vName == VIEWERS.UTILITY then
            self:UpdateUtilityContainerPosition()
        end

        container:Show()

        return container
    end
end

function CDM:UpdateContainerDragOverlays()
    if not self.anchorContainers then return end
    for _, container in pairs(self.anchorContainers) do
        if container and container.UpdateHelperText then
            container.UpdateHelperText()
        end
    end
end
