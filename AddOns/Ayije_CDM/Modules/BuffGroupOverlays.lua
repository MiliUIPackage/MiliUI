local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local L = CDM.L
local pairs, ipairs = pairs, ipairs
local math_huge = math.huge
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

local function ComputeRectForFrames(frames)
    local left, right, top, bottom = math_huge, -math_huge, -math_huge, math_huge
    local count = 0
    for _, frame in ipairs(frames) do
        if frame:IsShown() then
            local fl = frame:GetLeft()
            local fr = frame:GetRight()
            local ft = frame:GetTop()
            local fb = frame:GetBottom()
            if fl and fr and ft and fb then
                if fl < left then left = fl end
                if fr > right then right = fr end
                if ft > top then top = ft end
                if fb < bottom then bottom = fb end
                count = count + 1
            end
        end
    end
    if count == 0 then return nil end
    return left, right, top, bottom
end

local function ApplyRect(overlay, left, right, top, bottom, groupIdx, label)
    overlay:ClearAllPoints()
    local pad = OVERLAY_PADDING
    overlay:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left - pad,  bottom - pad)
    overlay:SetPoint("TOPRIGHT",   UIParent, "BOTTOMLEFT", right + pad, top + pad)
    overlay.groupIdx = groupIdx
    overlay.label:SetText(label)
    overlay:SetShown(ShouldShowOverlays())
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
                local l, r, t, b = ComputeRectForFrames(groupFrames)
                if l then
                    local overlay = AcquireOverlay()
                    activeOverlays[groupIdx] = overlay
                    ApplyRect(overlay, l, r, t, b, groupIdx, GetGroupName(groupIdx))
                end
            end
        end
    end

    if tempBuff and #tempBuff > 0 then
        local l, r, t, b = ComputeRectForFrames(tempBuff)
        if l then
            local overlay = AcquireOverlay()
            activeOverlays["__ungrouped"] = overlay
            ApplyRect(overlay, l, r, t, b, nil, UNGROUPED_LABEL)
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
    self:RefreshBuffGroupOverlayVisibility()
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
