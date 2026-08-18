local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
end
-------------------------------------------------------------------------------
-- YUI | Layout edit mode - overlay
-------------------------------------------------------------------------------
local _, YUI = ...
if not YUI or not YUI.Layout or not YUI.Layout._private then return end

local Layout = YUI.Layout
local P = Layout._private
local GUI2 = P.GUI2
local CreateFrame = P.CreateFrame
local UIParent = P.UIParent
local C_Timer = P.C_Timer
local IsShiftKeyDown = P.IsShiftKeyDown
local ipairs = P.ipairs
local tostring = P.tostring
local tonumber = P.tonumber
local math_abs = P.math_abs
local math_floor = P.math_floor
local math_max = P.math_max
local math_min = P.math_min
local math_pi = P.math_pi
local math_sqrt = P.math_sqrt
local string_gsub = P.string_gsub
local Round = P.Round
local SafeCall = P.SafeCall
local InCombat = P.InCombat
local ResolveSpecValue = P.ResolveSpecValue
local ResolveDefaultPlacement = P.ResolveDefaultPlacement
local ResolveEntryFrame = P.ResolveEntryFrame
local GetSavedPlacement = P.GetSavedPlacement
local GetOptions = P.GetOptions
local FindEntryByFrameName = P.FindEntryByFrameName
local NormalizeAnchorTargetName = P.NormalizeAnchorTargetName
local ResolveBuiltinAnchorTarget = P.ResolveBuiltinAnchorTarget
local GetBuiltinAnchorPlaceholder = P.GetBuiltinAnchorPlaceholder
local PointCoordinates = P.PointCoordinates
local CapturePlacement = P.CapturePlacement
local CaptureRelativePlacement = P.CaptureRelativePlacement
local PLACEMENT_PENDING = P.PLACEMENT_PENDING
local PLACEMENT_FALLBACK = P.PLACEMENT_FALLBACK
local PLACEMENT_SIMULATED = P.PLACEMENT_SIMULATED
local OVERLAY_STRATA = P.OVERLAY_STRATA
local OVERLAY_FRAME_LEVEL = P.OVERLAY_FRAME_LEVEL
local SELECTED_OVERLAY_FRAME_LEVEL = P.SELECTED_OVERLAY_FRAME_LEVEL
local ANCHOR_OVERLAY_FRAME_LEVEL = P.ANCHOR_OVERLAY_FRAME_LEVEL
local ANCHOR_LINE_FRAME_LEVEL = P.ANCHOR_LINE_FRAME_LEVEL
local ANCHOR_DOT_FRAME_LEVEL = P.ANCHOR_DOT_FRAME_LEVEL
local MOVER_PANEL_STRATA = P.MOVER_PANEL_STRATA
local MOVER_PANEL_FRAME_LEVEL = P.MOVER_PANEL_FRAME_LEVEL
local OVERLAY_BORDER = P.OVERLAY_BORDER
local SELECTED_BORDER = P.SELECTED_BORDER
local MOVER_COLOR_NORMAL = P.MOVER_COLOR_NORMAL
local MOVER_COLOR_SELECTED = P.MOVER_COLOR_SELECTED
local MOVER_COLOR_ANCHOR = P.MOVER_COLOR_ANCHOR
local MOVER_COLOR_SIMULATED = P.MOVER_COLOR_SIMULATED
local MOVER_COLOR_PLACEHOLDER = P.MOVER_COLOR_PLACEHOLDER
local MOVER_BG_NORMAL = P.MOVER_BG_NORMAL
local MOVER_BG_SELECTED = P.MOVER_BG_SELECTED
local MOVER_BG_ANCHOR = P.MOVER_BG_ANCHOR
local MOVER_BG_SIMULATED = P.MOVER_BG_SIMULATED
local MIN_OVERLAY_SIZE = P.MIN_OVERLAY_SIZE
local SNAP_RANGE = P.SNAP_RANGE
local GRID_SPACING = P.GRID_SPACING
local DEFAULT_GRID_DENSITY = P.DEFAULT_GRID_DENSITY or "medium"
local GRID_DENSITY_SPACING = P.GRID_DENSITY_SPACING or {}
local NormalizeGridDensity = P.NormalizeGridDensity
local ANCHOR_GUIDE_DOT_SIZE = P.ANCHOR_GUIDE_DOT_SIZE
local ANCHOR_GUIDE_DOT_SPACING = P.ANCHOR_GUIDE_DOT_SPACING
local ANCHOR_LINE_MIN_DISTANCE = P.ANCHOR_LINE_MIN_DISTANCE
local ANCHOR_DOT_SIZE = P.ANCHOR_DOT_SIZE
local ANCHOR_DOT_ALPHA = P.ANCHOR_DOT_ALPHA
local ANCHOR_DOT_TEXTURE = P.ANCHOR_DOT_TEXTURE
local NativeSetSnapPreview = P.NativeSetSnapPreview
local NativeClearSnapPreview = P.NativeClearSnapPreview
local NativeApplyMagnetism = P.NativeApplyMagnetism

local function SafeOverlayName(id)
    return string_gsub(tostring(id or "frame"), "[^%w_]", "_")
end

local function GetMoverBounds(entry)
    local frame = ResolveEntryFrame(entry)
    local spec = entry and entry.spec or {}
    local width
    local height
    local offsetX = 0
    local offsetY = 0

    if type(spec.getMoverBounds) == "function" then
        local ok, value, valueHeight, valueOffsetX, valueOffsetY = SafeCall("Layout:getMoverBounds:" .. tostring(entry.id), spec.getMoverBounds, frame, entry, Layout)
        if ok then
            if type(value) == "table" then
                width = tonumber(value.width)
                height = tonumber(value.height)
                offsetX = tonumber(value.offsetX or value.x) or 0
                offsetY = tonumber(value.offsetY or value.y) or 0
            else
                width = tonumber(value)
                height = tonumber(valueHeight)
                offsetX = tonumber(valueOffsetX) or 0
                offsetY = tonumber(valueOffsetY) or 0
            end
        end
    end

    width = width or (frame and frame.GetWidth and frame:GetWidth()) or 0
    height = height or (frame and frame.GetHeight and frame:GetHeight()) or 0
    width = math_max(width, spec.minWidth or MIN_OVERLAY_SIZE, MIN_OVERLAY_SIZE)
    height = math_max(height, spec.minHeight or MIN_OVERLAY_SIZE, MIN_OVERLAY_SIZE)
    return width, height, offsetX, offsetY
end

local function SetBorderColor(frame, colorKey)
    if GUI2 and GUI2.SetBorderColor and frame then
        GUI2:SetBorderColor(frame, colorKey)
    end
end
P.SetBorderColor = SetBorderColor

local function SetBorderRGB(frame, color)
    if GUI2 and GUI2.SetBorderColor and frame and color then
        GUI2:SetBorderColor(frame, color[1], color[2], color[3], color[4])
    end
end
P.SetBorderRGB = SetBorderRGB

local function SetTextColor(text, colorKey)
    if GUI2 and GUI2.SetTextColorKey and text then
        GUI2:SetTextColorKey(text, colorKey)
    end
end
P.SetTextColor = SetTextColor

local function SetTextRGB(text, color)
    if text and text.SetTextColor and color then
        text:SetTextColor(color[1], color[2], color[3], color[4] or 1)
        text.gui2ColorKey = nil
    end
end
P.SetTextRGB = SetTextRGB

local function SetArrowDirection(texture, direction)
    if not texture then return end

    local rotation = 0
    if direction == "down" then
        rotation = math_pi
    elseif direction == "left" then
        rotation = math_pi / 2
    elseif direction == "right" then
        rotation = -math_pi / 2
    end

    if texture.SetRotation then
        texture:SetRotation(rotation)
        return
    end
    if not texture.SetTexCoord then return end

    if direction == "down" then
        texture:SetTexCoord(1, 1, 1, 0, 0, 1, 0, 0)
    elseif direction == "left" then
        texture:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
    elseif direction == "right" then
        texture:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
    else
        texture:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1)
    end
end
P.SetArrowDirection = SetArrowDirection

local function ApplyMoverPanelLayer(panel)
    if not panel then return end
    if panel.SetFrameStrata then panel:SetFrameStrata(MOVER_PANEL_STRATA) end
    if panel.SetFrameLevel then panel:SetFrameLevel(MOVER_PANEL_FRAME_LEVEL) end
    if panel.SetToplevel then panel:SetToplevel(false) end
    SetBorderRGB(panel, MOVER_COLOR_SELECTED)
end
P.ApplyMoverPanelLayer = ApplyMoverPanelLayer

local function GetSelectedAnchorEntry()
    local selected = Layout.selectedId and Layout.frames[Layout.selectedId]
    if not selected then return nil end
    local placement = Layout.moverPanelLiveId == selected.id and Layout.moverPanelLivePlacement or nil
    placement = placement or (GetSavedPlacement(selected.id) or ResolveDefaultPlacement(selected))
    local relative = placement and placement.anchor and placement.anchor.relative
    if not relative then return nil end
    return FindEntryByFrameName(relative)
end

local function ApplyOverlayVisual(entry)
    local overlay = entry and entry.overlay
    if not overlay then return end

    local selected = Layout.selectedId == entry.id
    local anchorTarget = not selected and GetSelectedAnchorEntry()
    local isAnchorTarget = anchorTarget and anchorTarget.id == entry.id
    local simulated = entry.placementState == PLACEMENT_SIMULATED
    local border = simulated and MOVER_COLOR_SIMULATED or (selected and MOVER_COLOR_SELECTED or (isAnchorTarget and MOVER_COLOR_ANCHOR or MOVER_COLOR_NORMAL))
    local bg = simulated and MOVER_BG_SIMULATED or (selected and MOVER_BG_SELECTED or (isAnchorTarget and MOVER_BG_ANCHOR or MOVER_BG_NORMAL))
    if overlay.SetBackdropColor then
        overlay:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    end
    SetBorderRGB(overlay, border)
    if selected or isAnchorTarget or simulated then
        SetTextRGB(overlay.label, border)
    else
        SetTextColor(overlay.label, "color.text.primary")
    end
    if overlay.SetFrameLevel then
        overlay:SetFrameLevel(selected and SELECTED_OVERLAY_FRAME_LEVEL or (isAnchorTarget and ANCHOR_OVERLAY_FRAME_LEVEL or OVERLAY_FRAME_LEVEL))
    end
end

local function GetVisualFrameForEntry(entry)
    if entry and entry.overlay and entry.overlay:IsShown() then
        return entry.overlay
    end
    return ResolveEntryFrame(entry)
end

local function GetAnchorTargetVisualFrame(relative, preferPlaceholder)
    relative = NormalizeAnchorTargetName(relative)
    if relative == "" or relative == "UIParent" then return UIParent end

    local targetEntry = FindEntryByFrameName(relative)
    if targetEntry then
        return GetVisualFrameForEntry(targetEntry)
    end
    if preferPlaceholder then
        local placeholder = GetBuiltinAnchorPlaceholder and GetBuiltinAnchorPlaceholder(relative)
        if placeholder then
            return placeholder
        end
    end
    local builtinFrame = ResolveBuiltinAnchorTarget and ResolveBuiltinAnchorTarget(relative)
    if builtinFrame then
        return builtinFrame
    end
    local placeholder = GetBuiltinAnchorPlaceholder and GetBuiltinAnchorPlaceholder(relative)
    if placeholder then
        return placeholder
    end
    return _G[relative]
end

local function GetFramePointXY(frame, point)
    if not frame or not frame.GetWidth or not frame.GetHeight then return nil, nil end

    local left = frame.GetLeft and frame:GetLeft()
    local bottom = frame.GetBottom and frame:GetBottom()
    local width = frame:GetWidth() or 0
    local height = frame:GetHeight() or 0
    if (not left or not bottom) and frame == UIParent then
        left = left or 0
        bottom = bottom or 0
    end
    if not left or not bottom then return nil, nil end
    return PointCoordinates(left, bottom, width, height, point or "CENTER")
end

local function IsFrameShown(frame)
    if not frame then return false end
    if type(frame.IsShown) ~= "function" then return true end
    return frame:IsShown() == true
end

local function GetActivePlacement(entry)
    if Layout.moverPanelLiveId == entry.id and Layout.moverPanelLivePlacement then
        return Layout.moverPanelLivePlacement
    end
    return entry.pendingPlacement or GetSavedPlacement(entry.id) or ResolveDefaultPlacement(entry)
end

local function GetLogicalFrameSize(entry, fallbackWidth, fallbackHeight)
    local frame = ResolveEntryFrame(entry)
    local width = frame and frame.GetWidth and tonumber(frame:GetWidth()) or nil
    local height = frame and frame.GetHeight and tonumber(frame:GetHeight()) or nil
    width = (width and width > 0) and width or fallbackWidth or MIN_OVERLAY_SIZE
    height = (height and height > 0) and height or fallbackHeight or MIN_OVERLAY_SIZE
    return math_max(width, MIN_OVERLAY_SIZE), math_max(height, MIN_OVERLAY_SIZE)
end

local function PositionOverlayFromPlacement(entry, overlay, width, height, moverOffsetX, moverOffsetY)
    local placement = GetActivePlacement(entry)
    local anchor = placement and placement.anchor
    if not anchor then return false end

    local targetFrame = GetAnchorTargetVisualFrame(anchor.relative, entry.placementState == PLACEMENT_SIMULATED)
    local point = anchor.point or "CENTER"
    local targetX, targetY = GetFramePointXY(targetFrame, anchor.relativePoint or point)
    if not targetX or not targetY then return false end

    local sourceWidth, sourceHeight = GetLogicalFrameSize(entry, width, height)
    local sourcePointX, sourcePointY = PointCoordinates(0, 0, sourceWidth, sourceHeight, point)
    local offset = placement.offset
    local sourceCenterX = targetX + (offset and offset.x or 0) - (sourcePointX - sourceWidth / 2)
    local sourceCenterY = targetY + (offset and offset.y or 0) - (sourcePointY - sourceHeight / 2)

    overlay.yuiLayoutProxyWidth = sourceWidth
    overlay.yuiLayoutProxyHeight = sourceHeight
    overlay:ClearAllPoints()
    overlay:SetPoint("CENTER", UIParent, "BOTTOMLEFT", Round(sourceCenterX + (moverOffsetX or 0)), Round(sourceCenterY + (moverOffsetY or 0)))
    return true
end

local function CreateMoverProxyFrame(entry)
    local overlay = entry and entry.overlay
    if not overlay or not overlay.GetLeft then return nil end

    local left = overlay:GetLeft()
    local bottom = overlay:GetBottom()
    local width = overlay:GetWidth() or MIN_OVERLAY_SIZE
    local height = overlay:GetHeight() or MIN_OVERLAY_SIZE
    if not left or not bottom then return nil end

    local sourceWidth = overlay.yuiLayoutProxyWidth
    local sourceHeight = overlay.yuiLayoutProxyHeight
    if not sourceWidth or sourceWidth <= 0 or not sourceHeight or sourceHeight <= 0 then
        sourceWidth, sourceHeight = GetLogicalFrameSize(entry, width, height)
    end

    local sourceCenterX = left + width / 2 - (overlay.yuiLayoutMoverOffsetX or 0)
    local sourceCenterY = bottom + height / 2 - (overlay.yuiLayoutMoverOffsetY or 0)
    local sourceLeft = sourceCenterX - sourceWidth / 2
    local sourceBottom = sourceCenterY - sourceHeight / 2

    return {
        yuiLayoutMoverProxy = true,
        GetLeft = function() return sourceLeft end,
        GetBottom = function() return sourceBottom end,
        GetWidth = function() return sourceWidth end,
        GetHeight = function() return sourceHeight end,
    }
end

local function CaptureMoverPlacement(entry)
    local frame = ResolveEntryFrame(entry)
    if entry and entry.placementState == PLACEMENT_SIMULATED and not IsFrameShown(frame) then
        local sourceFrame = CreateMoverProxyFrame(entry)
        if sourceFrame and CaptureRelativePlacement then
            return CaptureRelativePlacement(entry, sourceFrame) or GetActivePlacement(entry)
        end
        return GetActivePlacement(entry)
    end
    return CapturePlacement(entry, frame)
end
P.CaptureMoverPlacement = CaptureMoverPlacement

local function SetLineColor(line, color)
    if not line or not color then return end
    if line.SetColorTexture then
        line:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    elseif line.SetVertexColor then
        line:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    end
end

local function GetPixelSize(region, desiredPixels, minPixels)
    desiredPixels = desiredPixels or 1
    minPixels = minPixels or desiredPixels

    local pixelUtil = PixelUtil
    if pixelUtil and pixelUtil.GetPixelToUIUnitFactor and pixelUtil.GetNearestPixelSize and region and region.GetEffectiveScale then
        local scale = region:GetEffectiveScale()
        if scale and scale > 0 then
            local okFactor, uiUnitFactor = pcall(pixelUtil.GetPixelToUIUnitFactor)
            if okFactor and type(uiUnitFactor) == "number" and uiUnitFactor > 0 then
                local uiUnits = uiUnitFactor * desiredPixels / scale
                local okSize, size = pcall(pixelUtil.GetNearestPixelSize, uiUnits, scale, minPixels)
                if okSize and type(size) == "number" and size > 0 then
                    return size
                end
            end
        end
    end

    return ((GUI2 and GUI2.mult) or 1) * desiredPixels
end

local function CreateAnchorLineFrame()
    if Layout.anchorLineFrame then return Layout.anchorLineFrame end

    local frame = CreateFrame("Frame", "YUI_LayoutAnchorLine", UIParent)
    frame.yuiLayoutInternal = true
    frame:SetAllPoints(UIParent)
    frame:SetFrameStrata(OVERLAY_STRATA)
    frame:SetFrameLevel(ANCHOR_LINE_FRAME_LEVEL)
    if frame.EnableMouse then frame:EnableMouse(false) end
    frame.segments = {}
    frame.dots = {}
    frame:Hide()
    Layout.anchorLineFrame = frame
    return frame
end

local function CreateAnchorDotFrame()
    if Layout.anchorDotFrame then return Layout.anchorDotFrame end

    local frame = CreateFrame("Frame", "YUI_LayoutAnchorDots", UIParent)
    frame.yuiLayoutInternal = true
    frame:SetAllPoints(UIParent)
    frame:SetFrameStrata(OVERLAY_STRATA)
    frame:SetFrameLevel(ANCHOR_DOT_FRAME_LEVEL)
    if frame.EnableMouse then frame:EnableMouse(false) end
    frame.dots = {}
    frame:Hide()
    Layout.anchorDotFrame = frame
    return frame
end

local function AcquireAnchorGuideDot(pool, index, size, color)
    local frame = CreateAnchorLineFrame()

    local dot = pool[index]
    if not dot then
        dot = frame:CreateTexture(nil, "ARTWORK")
        dot:SetTexture("Interface\\Buttons\\WHITE8x8")
        pool[index] = dot
    end
    local pixelSize = GetPixelSize(frame, size, 1)
    dot:SetSize(pixelSize, pixelSize)
    SetLineColor(dot, color)
    dot:Show()
    return dot
end

local function HideAnchorLine()
    local frame = Layout.anchorLineFrame
    if frame then
        if frame.segments then
            for _, line in ipairs(frame.segments) do
                line:Hide()
            end
        end
        if frame.dots then
            for _, line in ipairs(frame.dots) do
                line:Hide()
            end
        end
        frame:Hide()
    end

    local dotFrame = Layout.anchorDotFrame
    if dotFrame then
        if dotFrame.dots then
            for _, dot in ipairs(dotFrame.dots) do
                dot:Hide()
            end
        end
        dotFrame:Hide()
    end
end
P.HideAnchorLine = HideAnchorLine

local function AcquireAnchorDot(pool, index, color)
    local frame = CreateAnchorDotFrame()
    local dot = pool[index]
    if not dot then
        dot = frame:CreateTexture(nil, "OVERLAY")
        dot:SetTexture(ANCHOR_DOT_TEXTURE)
        dot:SetSize(ANCHOR_DOT_SIZE, ANCHOR_DOT_SIZE)
        pool[index] = dot
    end
    dot:SetSize(ANCHOR_DOT_SIZE, ANCHOR_DOT_SIZE)
    if dot.SetAlpha then
        dot:SetAlpha(ANCHOR_DOT_ALPHA)
    end
    if dot.SetVertexColor and color then
        dot:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    end
    dot:Show()
    return dot
end

local function DrawAnchorDot(pool, index, x, y, color)
    local dot = AcquireAnchorDot(pool, index, color)
    if not dot then return end
    dot:ClearAllPoints()
    dot:SetPoint("CENTER", UIParent, "BOTTOMLEFT", Round(x), Round(y))
end

function Layout:RefreshAnchorLine()
    if not self.editing then
        HideAnchorLine()
        return
    end

    local entry = self.selectedId and self.frames[self.selectedId]
    local placement = entry and self.moverPanelLiveId == entry.id and self.moverPanelLivePlacement or nil
    placement = placement or (entry and self:GetPlacement(entry.id) or nil)
    local anchor = placement and placement.anchor
    if not entry or not anchor then
        HideAnchorLine()
        return
    end

    local sourceFrame = GetVisualFrameForEntry(entry)
    local targetFrame = GetAnchorTargetVisualFrame(anchor.relative, entry.placementState == PLACEMENT_SIMULATED)
    local startX, startY = GetFramePointXY(sourceFrame, anchor.point)
    local endX, endY = GetFramePointXY(targetFrame, anchor.relativePoint or anchor.point)
    if not startX or not startY or not endX or not endY then
        HideAnchorLine()
        return
    end
    startX, startY = Round(startX), Round(startY)
    endX, endY = Round(endX), Round(endY)

    local dx = endX - startX
    local dy = endY - startY
    local distance = math_sqrt(dx * dx + dy * dy)

    local lineFrame = CreateAnchorLineFrame()
    local dotFrame = CreateAnchorDotFrame()
    dotFrame:Show()
    local startColor = entry.placementState == PLACEMENT_SIMULATED and MOVER_COLOR_SIMULATED or MOVER_COLOR_SELECTED
    local endColor = targetFrame and targetFrame.yuiLayoutAnchorPlaceholder and MOVER_COLOR_PLACEHOLDER or MOVER_COLOR_ANCHOR

    local used = 0
    if distance >= ANCHOR_LINE_MIN_DISTANCE then
        lineFrame:Show()
        local dirX = dx / distance
        local dirY = dy / distance
        local cursor = ANCHOR_GUIDE_DOT_SPACING
        while cursor < distance and used < 256 do
            used = used + 1
            local dot = AcquireAnchorGuideDot(lineFrame.segments, used, ANCHOR_GUIDE_DOT_SIZE, startColor)
            if dot then
                dot:ClearAllPoints()
                dot:SetPoint("CENTER", UIParent, "BOTTOMLEFT", Round(startX + dirX * cursor), Round(startY + dirY * cursor))
            end
            cursor = cursor + ANCHOR_GUIDE_DOT_SPACING
        end
    else
        lineFrame:Hide()
    end

    for index = used + 1, #lineFrame.segments do
        lineFrame.segments[index]:Hide()
    end
    DrawAnchorDot(dotFrame.dots, 1, startX, startY, startColor)
    DrawAnchorDot(dotFrame.dots, 2, endX, endY, endColor)
    for index = 3, #dotFrame.dots do
        dotFrame.dots[index]:Hide()
    end
end

local function AnchorOverlayToScreen(overlay)
    if not overlay then return false end
    if overlay.yuiLayoutScreenAnchored == true then return true end
    if not overlay.GetLeft or not overlay.GetBottom then return false end

    local left = overlay:GetLeft()
    local bottom = overlay:GetBottom()
    local width = overlay:GetWidth() or 0
    local height = overlay:GetHeight() or 0
    if not left or not bottom then return false end

    overlay:ClearAllPoints()
    overlay:SetPoint("CENTER", UIParent, "BOTTOMLEFT", Round(left + width / 2), Round(bottom + height / 2))
    overlay.yuiLayoutScreenAnchored = true
    return true
end

local function SyncFrameToOverlay(entry)
    local frame = ResolveEntryFrame(entry)
    local overlay = entry and entry.overlay
    if not frame or not overlay or not overlay:IsShown() then return end
    if entry.placementState == PLACEMENT_SIMULATED and not IsFrameShown(frame) then return end
    if not AnchorOverlayToScreen(overlay) then return end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", overlay, "CENTER", -(overlay.yuiLayoutMoverOffsetX or 0), -(overlay.yuiLayoutMoverOffsetY or 0))
end

local function CollectSnapCandidates(entry)
    local candidatesX = {}
    local candidatesY = {}
    local parentWidth = UIParent:GetWidth() or 0
    local parentHeight = UIParent:GetHeight() or 0

    candidatesX[#candidatesX + 1] = 0
    candidatesX[#candidatesX + 1] = parentWidth / 2
    candidatesX[#candidatesX + 1] = parentWidth
    candidatesY[#candidatesY + 1] = 0
    candidatesY[#candidatesY + 1] = parentHeight / 2
    candidatesY[#candidatesY + 1] = parentHeight

    for _, id in ipairs(Layout.order) do
        if id ~= entry.id then
            local other = Layout.frames[id]
            local frame = other and ResolveEntryFrame(other)
            if frame and frame:IsShown() and frame.GetLeft then
                local left = frame:GetLeft()
                local bottom = frame:GetBottom()
                local width = frame:GetWidth() or 0
                local height = frame:GetHeight() or 0
                if left and bottom then
                    candidatesX[#candidatesX + 1] = left
                    candidatesX[#candidatesX + 1] = left + width / 2
                    candidatesX[#candidatesX + 1] = left + width
                    candidatesY[#candidatesY + 1] = bottom
                    candidatesY[#candidatesY + 1] = bottom + height / 2
                    candidatesY[#candidatesY + 1] = bottom + height
                end
            end
        end
    end

    return candidatesX, candidatesY
end

local function BestDelta(values, candidates)
    local best = 0
    local bestDistance = SNAP_RANGE + 1
    for _, value in ipairs(values) do
        for _, target in ipairs(candidates) do
            local distance = math_abs(target - value)
            if distance <= SNAP_RANGE and distance < bestDistance then
                bestDistance = distance
                best = target - value
            end
        end
    end
    return best
end

local function SnapOverlay(entry)
    local options = GetOptions()
    if not options.snap then return end
    if ResolveSpecValue(entry, "snap", true) == false then return end
    local overlay = entry and entry.overlay
    if not overlay or not overlay.GetLeft then return end

    local left = overlay:GetLeft()
    local bottom = overlay:GetBottom()
    local width = overlay:GetWidth() or 0
    local height = overlay:GetHeight() or 0
    if not left or not bottom then return end

    local candidatesX, candidatesY = CollectSnapCandidates(entry)
    local dx = BestDelta({ left, left + width / 2, left + width }, candidatesX)
    local dy = BestDelta({ bottom, bottom + height / 2, bottom + height }, candidatesY)
    if dx == 0 and dy == 0 then return end

    overlay:ClearAllPoints()
    overlay:SetPoint("CENTER", UIParent, "BOTTOMLEFT", left + width / 2 + dx, bottom + height / 2 + dy)
end


local function SuppressNextOverlayClick(overlay)
    if not overlay then return end
    overlay.yuiLayoutSuppressClick = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0.25, function()
            if overlay then overlay.yuiLayoutSuppressClick = false end
        end)
    end
end
P.SuppressNextOverlayClick = SuppressNextOverlayClick

local function FinishDrag(entry)
    local overlay = entry and entry.overlay
    if not overlay then return end
    overlay:SetScript("OnUpdate", nil)
    overlay:StopMovingOrSizing()
    overlay.yuiLayoutDragging = false
    SuppressNextOverlayClick(overlay)
    NativeClearSnapPreview()
    if Layout.IsPlacementReady and not Layout:IsPlacementReady(entry.id) then
        Layout:UpdateOverlay(entry)
        return
    end
    if GetOptions().snap and ResolveSpecValue(entry, "snap", true) ~= false then
        NativeApplyMagnetism(overlay)
        SnapOverlay(entry)
    end
    SyncFrameToOverlay(entry)
    Layout.moverPanelLiveId = nil
    Layout.moverPanelLivePlacement = nil
    Layout:SetPlacement(entry.id, CaptureMoverPlacement(entry), true)
end

local function CreateOverlay(entry)
    if entry.overlay then return entry.overlay end
    local name = "YUI_LayoutOverlay_" .. SafeOverlayName(entry.id)
    local overlay
    if GUI2 and GUI2.CreateFrame then
        overlay = GUI2:CreateFrame(UIParent, {
            type = "Button",
            name = name,
            template = "BackdropTemplate",
            width = 120,
            height = 36,
            movable = true,
            clamped = true,
            frameStrata = OVERLAY_STRATA,
        })
    else
        overlay = CreateFrame("Button", name, UIParent, "BackdropTemplate")
        overlay:SetSize(120, 36)
        overlay:SetFrameStrata(OVERLAY_STRATA)
    end

    overlay.yuiLayoutEntry = entry
    overlay.yuiLayoutOverlay = true
    overlay:Hide()
    overlay:EnableMouse(true)
    overlay:SetMovable(true)
    overlay:SetClampedToScreen(true)
    overlay:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    overlay:RegisterForDrag("LeftButton")
    if overlay.EnableMouseWheel then overlay:EnableMouseWheel(true) end
    if overlay.EnableKeyboard then overlay:EnableKeyboard(true) end
    if overlay.SetPropagateKeyboardInput then overlay:SetPropagateKeyboardInput(true) end

    if overlay.SetBackdrop then
        overlay:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        overlay:SetBackdropColor(0.1, 0.55, 1, 0.13)
    end
    if GUI2 and GUI2.CreateBorder then
        GUI2:CreateBorder(overlay, OVERLAY_BORDER)
    end

    local label
    if GUI2 and GUI2.CreateText then
        label = GUI2:CreateText(overlay, "", "font.size.md", "color.text.primary")
    else
        label = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    end
    label:SetPoint("CENTER")
    label:SetJustifyH("CENTER")
    label:SetWordWrap(false)
    if label.GetFont and label.SetFont then
        local font, size = label:GetFont()
        if font and size then label:SetFont(font, size, "OUTLINE") end
    end
    overlay.label = label

    overlay:SetScript("OnEnter", function()
        if Layout.anchorPickerEntryId then return end
        Layout:SelectFrame(entry.id, true)
    end)
    overlay:SetScript("OnLeave", nil)
    overlay:SetScript("OnMouseDown", function(self, button)
        self.yuiLayoutShiftRightClick = button == "RightButton" and IsShiftKeyDown and IsShiftKeyDown() or nil
    end)
    overlay:SetScript("OnDragStart", function(self)
        if Layout.anchorPickerEntryId then return end
        if InCombat() then return end
        if GetOptions().locked then return end
        if Layout.IsPlacementReady and not Layout:IsPlacementReady(entry.id) then return end
        if ResolveSpecValue(entry, "movable", true) == false then return end
        if not AnchorOverlayToScreen(self) then return end
        self.yuiLayoutDragging = true
        self:StartMoving()
        NativeSetSnapPreview(self)
        self:SetScript("OnUpdate", function()
            SyncFrameToOverlay(entry)
            if Layout.RefreshDraggingMover then
                Layout:RefreshDraggingMover(entry)
            end
        end)
        Layout:SelectFrame(entry.id)
    end)
    overlay:SetScript("OnDragStop", function()
        FinishDrag(entry)
    end)
    overlay:SetScript("OnClick", function(self, button)
        if self.yuiLayoutSuppressClick then
            self.yuiLayoutSuppressClick = false
            self.yuiLayoutShiftRightClick = nil
            return
        end
        if Layout.anchorPickerEntryId then
            self.yuiLayoutShiftRightClick = nil
            if button == "LeftButton" then
                Layout:PickAnchorTargetFromEntry(entry)
            end
            return
        end
        if button == "RightButton" then
            local shiftRightClick = self.yuiLayoutShiftRightClick or (IsShiftKeyDown and IsShiftKeyDown())
            self.yuiLayoutShiftRightClick = nil
            if shiftRightClick then
                Layout:HideMoverOverlay(entry.id)
                return
            end
            Layout:SelectFrame(entry.id, true)
            Layout:OpenPluginSettings(entry.id)
        else
            if Layout.moverPanelEntryId == entry.id and Layout.moverPanel and Layout.moverPanel:IsShown() then
                Layout:HideMoverPanel(entry.id)
            else
                Layout:SelectFrame(entry.id, true)
            end
        end
    end)
    overlay:SetScript("OnMouseWheel", function(_, delta)
        local step = delta >= 0 and 1 or -1
        if IsShiftKeyDown and IsShiftKeyDown() then
            Layout:NudgeFrame(entry.id, step, 0)
        else
            Layout:NudgeFrame(entry.id, 0, step)
        end
    end)
    overlay:SetScript("OnKeyDown", function(_, key)
        local step = 1
        if key == "UP" then
            Layout:NudgeFrame(entry.id, 0, step)
        elseif key == "DOWN" then
            Layout:NudgeFrame(entry.id, 0, -step)
        elseif key == "LEFT" then
            Layout:NudgeFrame(entry.id, -step, 0)
        elseif key == "RIGHT" then
            Layout:NudgeFrame(entry.id, step, 0)
        end
    end)

    entry.overlay = overlay
    ApplyOverlayVisual(entry)
    return overlay
end

function Layout:HideMoverOverlay(id)
    local entry = id and self.frames[id]
    if not entry then return false end

    self.hiddenMoverOverlayIds = self.hiddenMoverOverlayIds or {}
    self.hiddenMoverOverlayIds[id] = true

    if self.moverPanelEntryId == id then
        self:HideMoverPanel(id)
    end
    if self.selectedId == id then
        self.selectedId = nil
        self:RefreshControlPanel()
        self:RefreshSettingsPanel()
    end
    if entry.overlay then
        entry.overlay:Hide()
        entry.overlay:SetScript("OnUpdate", nil)
        entry.overlay.yuiLayoutDragging = false
    end
    if type(entry.spec.onHideEditModePreview) == "function" then
        SafeCall("Layout:onHideEditModePreview:" .. tostring(id), entry.spec.onHideEditModePreview, ResolveEntryFrame(entry), entry, self)
    end
    self:RefreshOverlayVisuals()
    return true
end

function Layout:UpdateOverlay(entry)
    if type(entry) == "string" then entry = self.frames[entry] end
    if not entry then return end

    local overlay = CreateOverlay(entry)
    local frame = ResolveEntryFrame(entry)
    local placementState = entry.placementState
    local enabled = ResolveSpecValue(entry, "isEnabled", true) ~= false
    local showOnlyInEditMode = ResolveSpecValue(entry, "showOnlyInEditMode", false) == true
    local frameShown = IsFrameShown(frame)
    if frame and showOnlyInEditMode then
        if self.editing and placementState ~= PLACEMENT_PENDING and enabled then
            frame:Show()
        else
            frame:Hide()
        end
        frameShown = IsFrameShown(frame)
    end
    if self.hiddenMoverOverlayIds and self.hiddenMoverOverlayIds[entry.id] then
        overlay:Hide()
        if self.moverPanelEntryId == entry.id then
            self:HideMoverPanel(entry.id)
        end
        if self.selectedId == entry.id then
            self.selectedId = nil
            self:RefreshControlPanel()
            self:RefreshSettingsPanel()
            self:RefreshAnchorLine()
        end
        return
    end
    if placementState == PLACEMENT_PENDING or not self.editing or not frame or not enabled or (not frameShown and placementState ~= PLACEMENT_SIMULATED) then
        overlay:Hide()
        if self.moverPanelEntryId == entry.id then
            self:HideMoverPanel(entry.id)
        end
        if self.selectedId == entry.id then
            self:RefreshAnchorLine()
        end
        return
    end
    local width, height, offsetX, offsetY = GetMoverBounds(entry)
    overlay.yuiLayoutMoverOffsetX = offsetX
    overlay.yuiLayoutMoverOffsetY = offsetY
    overlay:SetSize(width, height)
    overlay.yuiLayoutProxyWidth = nil
    overlay.yuiLayoutProxyHeight = nil
    if placementState == PLACEMENT_SIMULATED and not frameShown then
        if not PositionOverlayFromPlacement(entry, overlay, width, height, offsetX, offsetY) then
            overlay:Hide()
            if self.moverPanelEntryId == entry.id then
                self:HideMoverPanel(entry.id)
            end
            if self.selectedId == entry.id then
                self:RefreshAnchorLine()
            end
            return
        end
    else
        overlay:ClearAllPoints()
        overlay:SetPoint("CENTER", frame, "CENTER", offsetX, offsetY)
    end
    overlay.yuiLayoutScreenAnchored = false
    if overlay.label then
        local title = entry.spec.title or entry.id
        if placementState == PLACEMENT_FALLBACK or placementState == PLACEMENT_SIMULATED then
            title = title .. " *"
        end
        overlay.label:SetText(title)
        overlay.label:SetWidth(math_max(width - 8, 10))
    end
    ApplyOverlayVisual(entry)
    overlay:Show()
    if self.moverPanelEntryId == entry.id and self.moverPanel and self.moverPanel:IsShown() then
        self:PositionMoverPanel(entry)
        self:RefreshMovementWidgets()
    end
    if self.selectedId == entry.id then
        self:RefreshAnchorLine()
    end
end

function Layout:RefreshOverlays()
    for _, id in ipairs(self.order) do
        self:UpdateOverlay(self.frames[id])
    end
end

function Layout:RefreshOverlayVisuals()
    for _, id in ipairs(self.order) do
        ApplyOverlayVisual(self.frames[id])
    end
    ApplyMoverPanelLayer(self.moverPanel)
    self:RefreshAnchorLine()
end

function Layout:CreateGrid()
    if self.grid then return self.grid end
    local grid = GUI2 and GUI2.CreateFrame and GUI2:CreateFrame(UIParent, {
        name = "YUI_LayoutGrid",
        width = UIParent:GetWidth(),
        height = UIParent:GetHeight(),
        frameStrata = OVERLAY_STRATA,
    }) or CreateFrame("Frame", "YUI_LayoutGrid", UIParent)
    grid:SetAllPoints(UIParent)
    grid:SetFrameStrata(OVERLAY_STRATA)
    grid:SetFrameLevel(1)
    grid.lines = {}
    grid:Hide()
    self.grid = grid
    return grid
end

function Layout:UpdateGrid()
    local options = GetOptions()
    if not self.editing or not options.showGrid then
        self:HideGrid()
        return
    end
    local density = NormalizeGridDensity and NormalizeGridDensity(options.gridDensity) or DEFAULT_GRID_DENSITY
    local spacing = GRID_DENSITY_SPACING[density] or GRID_SPACING
    local grid = self:CreateGrid()
    local width = UIParent:GetWidth() or 0
    local height = UIParent:GetHeight() or 0
    local needed = math_floor(width / spacing) + math_floor(height / spacing) + 4
    for index = #grid.lines + 1, needed do
        local tex = grid:CreateTexture(nil, "BACKGROUND")
        tex:SetColorTexture(0.2, 0.65, 1, 0.18)
        grid.lines[index] = tex
    end
    for _, tex in ipairs(grid.lines) do
        tex:Hide()
    end

    local lineIndex = 1
    local x = 0
    while x <= width do
        local tex = grid.lines[lineIndex]
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", grid, "TOPLEFT", x, 0)
        tex:SetSize(1, height)
        tex:Show()
        lineIndex = lineIndex + 1
        x = x + spacing
    end

    local y = 0
    while y <= height do
        local tex = grid.lines[lineIndex]
        tex:ClearAllPoints()
        tex:SetPoint("BOTTOMLEFT", grid, "BOTTOMLEFT", 0, y)
        tex:SetSize(width, 1)
        tex:Show()
        lineIndex = lineIndex + 1
        y = y + spacing
    end
    grid:Show()
end

function Layout:HideGrid()
    if self.grid then self.grid:Hide() end
end
