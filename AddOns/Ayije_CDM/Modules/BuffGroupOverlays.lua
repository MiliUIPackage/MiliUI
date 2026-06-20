local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local L = CDM.L
local pairs, ipairs = pairs, ipairs
local CreateFrame = CreateFrame
local NineSliceUtil = NineSliceUtil
local SetRegionBlendMode = CDM.SetRegionBlendMode

local UNGROUPED_LABEL = (L and L["Ungrouped"]) or "Ungrouped"

local OVERLAY_LAYOUT = {
    ["TopRightCorner"]    = { atlas = "%s-NineSlice-Corner",     mirrorLayout = true, x = 8,  y = 8 },
    ["TopLeftCorner"]     = { atlas = "%s-NineSlice-Corner",     mirrorLayout = true, x = -8, y = 8 },
    ["BottomLeftCorner"]  = { atlas = "%s-NineSlice-Corner",     mirrorLayout = true, x = -8, y = -8 },
    ["BottomRightCorner"] = { atlas = "%s-NineSlice-Corner",     mirrorLayout = true, x = 8,  y = -8 },
    ["TopEdge"]           = { atlas = "_%s-NineSlice-EdgeTop" },
    ["BottomEdge"]        = { atlas = "_%s-NineSlice-EdgeBottom" },
    ["LeftEdge"]          = { atlas = "!%s-NineSlice-EdgeLeft" },
    ["RightEdge"]         = { atlas = "!%s-NineSlice-EdgeRight" },
    ["Center"]            = { atlas = "%s-NineSlice-Center", x = -8, y = 8, x1 = 8, y1 = -8 },
}

local OVERLAY_PADDING = 2
local LABEL_GAP = 4

local overlayPool = {}
local activeOverlays = {}
local buffGroupsTabActive = false

local function CreateOverlay()
    local overlay = CreateFrame("Frame", nil, UIParent, "NineSliceCodeTemplate")
    overlay:SetFrameStrata("BACKGROUND")
    overlay:EnableMouse(false)
    if NineSliceUtil and NineSliceUtil.ApplyLayout then
        NineSliceUtil.ApplyLayout(overlay, OVERLAY_LAYOUT, "editmode-actionbar-highlight")
        if SetRegionBlendMode then
            SetRegionBlendMode("ADD", overlay:GetRegions())
        end
        overlay:SetAlpha(0.4)
    end
    local label = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("BOTTOM", overlay, "TOP", 0, LABEL_GAP)
    label:SetIgnoreParentAlpha(true)
    overlay.label = label
    overlay:Hide()
    return overlay
end

local function AcquireOverlay()
    local overlay = table.remove(overlayPool)
    if not overlay then
        overlay = CreateOverlay()
    end
    return overlay
end

local function ReleaseOverlay(overlay)
    overlay:Hide()
    overlay:ClearAllPoints()
    overlayPool[#overlayPool + 1] = overlay
end

local function IsBlizzardPanelVisible()
    return CooldownViewerSettings and CooldownViewerSettings:IsVisible() or false
end

local function ShouldShowOverlays()
    return buffGroupsTabActive or IsBlizzardPanelVisible()
end

local function GetGroupName(groupIdx)
    local sets = CDM.BuffGroupSets
    local groups = sets and sets.groups
    local gd = groups and groups[groupIdx]
    if gd and gd.name and gd.name ~= "" then
        return gd.name
    end
    return "Group " .. groupIdx
end

local function FindShownExtremes(frames)
    local first, last
    for _, f in ipairs(frames) do
        if f:IsShown() then
            if not first then first = f end
            last = f
        end
    end
    return first, last
end

local function ResolveExtremeCorners(grow, firstShown, lastShown)
    if grow == "LEFT" or grow == "UP" then
        return lastShown, firstShown
    end
    return firstShown, lastShown
end

local function ApplyFrameAnchoredOverlay(overlay, firstShown, lastShown, grow, groupIdx, label)
    local tlFrame, brFrame = ResolveExtremeCorners(grow, firstShown, lastShown)
    overlay:ClearAllPoints()
    overlay:SetPoint("TOPLEFT",     tlFrame, "TOPLEFT",     -OVERLAY_PADDING,  OVERLAY_PADDING)
    overlay:SetPoint("BOTTOMRIGHT", brFrame, "BOTTOMRIGHT",  OVERLAY_PADDING, -OVERLAY_PADDING)
    overlay.groupIdx = groupIdx
    overlay.label:SetText(label)
    overlay:SetShown(ShouldShowOverlays())
end

local function GetGroupGrow(groupIdx)
    local sets = CDM.BuffGroupSets
    local groups = sets and sets.groups
    local gd = groups and groups[groupIdx]
    return gd and gd.grow or "RIGHT"
end

function CDM:UpdateBuffGroupOverlays(tempBuffGroups, tempBuff)
    for groupIdx, overlay in pairs(activeOverlays) do
        ReleaseOverlay(overlay)
        activeOverlays[groupIdx] = nil
    end

    if not ShouldShowOverlays() then return end

    if tempBuffGroups then
        for groupIdx, groupFrames in pairs(tempBuffGroups) do
            if groupFrames and #groupFrames > 0 then
                local first, last = FindShownExtremes(groupFrames)
                if first then
                    local overlay = AcquireOverlay()
                    activeOverlays[groupIdx] = overlay
                    ApplyFrameAnchoredOverlay(overlay, first, last, GetGroupGrow(groupIdx), groupIdx, GetGroupName(groupIdx))
                end
            end
        end
    end

    if tempBuff and #tempBuff > 0 then
        local first, last = FindShownExtremes(tempBuff)
        if first then
            local overlay = AcquireOverlay()
            activeOverlays["__ungrouped"] = overlay
            ApplyFrameAnchoredOverlay(overlay, first, last, "RIGHT", nil, UNGROUPED_LABEL)
        end
    end
end

function CDM:RefreshBuffGroupOverlayVisibility()
    local show = ShouldShowOverlays()
    for _, overlay in pairs(activeOverlays) do
        overlay:SetShown(show)
    end
end

function CDM:RefreshBuffGroupOverlayLabels()
    for _, overlay in pairs(activeOverlays) do
        if overlay.groupIdx then
            overlay.label:SetText(GetGroupName(overlay.groupIdx))
        end
    end
end

function CDM:SetBuffGroupsTabActive(active)
    active = active and true or false
    if buffGroupsTabActive == active then return end
    buffGroupsTabActive = active
    if active then
        local v = _G[CDM.CONST.VIEWERS.BUFF]
        if v then self:RepositionBuffViewer(v) end
    else
        self:RefreshBuffGroupOverlayVisibility()
    end
end

local function RegisterBlizzardPanelCallbacks()
    local registry = EventRegistry
    if not (registry and registry.RegisterCallback) then return end
    local owner = {}
    registry:RegisterCallback("CooldownViewerSettings.OnShow", function()
        CDM:RefreshBuffGroupOverlayVisibility()
    end, owner)
    registry:RegisterCallback("CooldownViewerSettings.OnHide", function()
        CDM:RefreshBuffGroupOverlayVisibility()
    end, owner)
end
RegisterBlizzardPanelCallbacks()
