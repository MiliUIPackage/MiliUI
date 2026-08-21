do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
-------------------------------------------------------------------------------
-- YUI | Layout edit mode - panel
-------------------------------------------------------------------------------
local _, YUI = ...
if not YUI or not YUI.Layout or not YUI.Layout._private then return end

local Layout = YUI.Layout
local P = Layout._private
local GUI2 = P.GUI2
local CreateFrame = P.CreateFrame
local UIParent = P.UIParent
local IsShiftKeyDown = P.IsShiftKeyDown
local IsMouseButtonDown = P.IsMouseButtonDown
local GetMouseFocus = P.GetMouseFocus
local GetMouseFoci = P.GetMouseFoci
local GetTime = P.GetTime
local pairs = P.pairs
local ipairs = P.ipairs
local type = P.type
local tostring = P.tostring
local tonumber = P.tonumber
local math_abs = P.math_abs
local math_floor = P.math_floor
local math_max = P.math_max
local math_min = P.math_min
local string_gsub = P.string_gsub
local L = P.L
local Round = P.Round
local SafeCall = P.SafeCall
local ResolveEntryFrame = P.ResolveEntryFrame
local BuildAnchorTargetOptions = P.BuildAnchorTargetOptions
local ResolveBuiltinAnchorTarget = P.ResolveBuiltinAnchorTarget
local GetBuiltinAnchorPlaceholder = P.GetBuiltinAnchorPlaceholder
local IsBuiltinAnchorTarget = P.IsBuiltinAnchorTarget
local AnchorTargetDisplayText = P.AnchorTargetDisplayText
local NormalizeAnchorTargetAlias = P.NormalizeAnchorTargetAlias
local EvaluateAnchorTargetCandidate = P.EvaluateAnchorTargetCandidate
local ANCHOR_POINTS = P.ANCHOR_POINTS
local AnchorPointDisplayText = P.AnchorPointDisplayText
local CapturePlacement = P.CapturePlacement
local CaptureMoverPlacement = P.CaptureMoverPlacement or CapturePlacement
local WouldCreateAnchorCycle = P.WouldCreateAnchorCycle
local IsAnchorTargetDeclared = P.IsAnchorTargetDeclared
local GetOptions = P.GetOptions
local NormalizeGridDensity = P.NormalizeGridDensity
local SuppressNextOverlayClick = P.SuppressNextOverlayClick
local RefreshDragCoordinateInfo = P.RefreshDragCoordinateInfo
local HideDragCoordinateInfo = P.HideDragCoordinateInfo
local ApplyMoverPanelLayer = P.ApplyMoverPanelLayer
local SetArrowDirection = P.SetArrowDirection
local MOVER_PANEL_STRATA = P.MOVER_PANEL_STRATA
local MOVER_PANEL_FRAME_LEVEL = P.MOVER_PANEL_FRAME_LEVEL
local MOVER_REFRESH_INTERVAL = P.MOVER_REFRESH_INTERVAL
local OFFSET_MIN = P.OFFSET_MIN
local OFFSET_MAX = P.OFFSET_MAX
local PLACEMENT_PENDING = P.PLACEMENT_PENDING
local PLACEMENT_FALLBACK = P.PLACEMENT_FALLBACK
local PLACEMENT_SIMULATED = P.PLACEMENT_SIMULATED
local SELECTED_BORDER = P.SELECTED_BORDER
local ARROW_TEXTURE = P.ARROW_TEXTURE
local DEFAULT_GRID_DENSITY = P.DEFAULT_GRID_DENSITY or "medium"
local GameTooltip = _G.GameTooltip
local COLORED_YUI = "|cFFFF00FFY|r|cFFFF6666U|r|cFFFF9900I|r"

local function LayoutPanelTitleText()
    return string_gsub(L("layout.panel.title"), "^YUI", COLORED_YUI)
end

local function GetGridDensity()
    local options = GetOptions()
    local density = options.gridDensity
    density = NormalizeGridDensity and NormalizeGridDensity(density) or DEFAULT_GRID_DENSITY
    options.gridDensity = density
    return density
end

local function SetGridDensity(value)
    local options = GetOptions()
    options.gridDensity = NormalizeGridDensity and NormalizeGridDensity(value) or DEFAULT_GRID_DENSITY
    Layout:UpdateGrid()
end

local function GetGridDensityOptions()
    return {
        { text = L("layout.option.grid_density.very_low"), value = "veryLow" },
        { text = L("layout.option.grid_density.low"), value = "low" },
        { text = L("layout.option.grid_density.medium"), value = "medium" },
        { text = L("layout.option.grid_density.high"), value = "high" },
        { text = L("layout.option.grid_density.very_high"), value = "veryHigh" },
    }
end

function Layout:OpenFrameOptions(id)
    local entry = self.frames[id]
    if not entry then return false end
    self:SelectFrame(id)
    self:ShowMoverPanel(entry)
    if type(entry.spec.openOptions) == "function" then
        local ok = SafeCall("Layout:openOptions:" .. tostring(id), entry.spec.openOptions, ResolveEntryFrame(entry), entry, self)
        return ok
    end
    return true
end

function Layout:OpenPluginSettings(id)
    local entry = self.frames[id]
    if not entry then return false end
    if type(entry.spec.openPluginSettings) == "function" then
        local ok = SafeCall("Layout:openPluginSettings:" .. tostring(id), entry.spec.openPluginSettings, ResolveEntryFrame(entry), entry, self)
        return ok
    end
    return self:OpenFrameOptions(id)
end

function Layout:ShowControlPanel()
    local panel = self.controlPanel
    if not panel then
        if GUI2 and GUI2.CreateFrame then
            panel = GUI2:CreateFrame(UIParent, {
                name = "YUI_LayoutControlPanel",
                template = "BackdropTemplate",
                width = 380,
                height = 148,
                frameStrata = MOVER_PANEL_STRATA,
                clamped = true,
                movable = true,
            })
        else
            panel = CreateFrame("Frame", "YUI_LayoutControlPanel", UIParent, "BackdropTemplate")
            panel:SetSize(380, 148)
            panel:SetFrameStrata(MOVER_PANEL_STRATA)
        end
        if panel.SetFrameLevel then panel:SetFrameLevel(MOVER_PANEL_FRAME_LEVEL) end
        if panel.SetToplevel then panel:SetToplevel(false) end
        panel.yuiLayoutInternal = true
        panel:SetPoint("TOP", UIParent, "TOP", 0, -90)
        panel:SetMovable(true)
        panel:EnableMouse(true)
        panel:RegisterForDrag("LeftButton")
        panel:SetScript("OnDragStart", function(self)
            self.yuiLayoutControlDragging = true
            self:StartMoving()
        end)
        panel:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            self.yuiLayoutControlDragging = false
            self.yuiLayoutControlSuppressClick = true
        end)
        panel:SetScript("OnMouseUp", function(self, button)
            if self.yuiLayoutControlSuppressClick then
                self.yuiLayoutControlSuppressClick = false
                return
            end
            if self.yuiLayoutControlDragging then return end
            if button == "RightButton" and IsShiftKeyDown and IsShiftKeyDown() then
                Layout:HideControlPanel()
                return
            end
            local id = Layout.selectedId
            local entry = id and Layout.frames[id]
            if not entry then return end
            if button == "RightButton" then
                Layout:OpenPluginSettings(id)
            elseif button == "LeftButton" then
                Layout:ShowMoverPanel(entry)
            end
        end)
        if panel.SetBackdrop then
            panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            panel:SetBackdropColor(0.04, 0.05, 0.07, 0.86)
        end
        if GUI2 and GUI2.CreateBorder then GUI2:CreateBorder(panel, "color.border.accent") end

        local titlePlate = CreateFrame("Frame", nil, panel, "BackdropTemplate")
        titlePlate:SetSize(128, 34)
        titlePlate:SetPoint("TOP", panel, "TOP", 0, 20)
        if titlePlate.SetFrameLevel and panel.GetFrameLevel then
            titlePlate:SetFrameLevel(panel:GetFrameLevel() + 2)
        end
        if titlePlate.SetBackdrop then
            titlePlate:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            titlePlate:SetBackdropColor(0.04, 0.05, 0.07, 0.96)
        end
        if GUI2 and GUI2.CreateBorder then GUI2:CreateBorder(titlePlate, "color.border.default") end
        panel.titlePlate = titlePlate

        local title = GUI2:CreateText(titlePlate, LayoutPanelTitleText(), "font.size.md", "color.text.primary", "CENTER")
        title:SetPoint("CENTER")
        panel.title = title

        local hintLeft = GUI2:CreateText(panel, L("layout.panel.hint.left_click"), "font.size.md", "color.text.secondary", "CENTER")
        hintLeft:SetPoint("TOP", panel, "TOP", 0, -38)
        hintLeft:SetWidth(260)
        panel.hintLeft = hintLeft

        local hintRight = GUI2:CreateText(panel, L("layout.panel.hint.right_click"), "font.size.md", "color.text.secondary", "CENTER")
        hintRight:SetPoint("TOP", hintLeft, "BOTTOM", 0, -3)
        hintRight:SetWidth(260)
        panel.hintRight = hintRight

        local hintHide = GUI2:CreateText(panel, L("layout.panel.hint.shift_right_click"), "font.size.md", "color.text.secondary", "CENTER")
        hintHide:SetPoint("TOP", hintRight, "BOTTOM", 0, -3)
        hintHide:SetWidth(260)
        panel.hintHide = hintHide

        local controlsRow = CreateFrame("Frame", nil, panel)
        controlsRow:SetSize(352, 24)
        controlsRow:SetPoint("BOTTOM", panel, "BOTTOM", 0, 14)
        panel.controlsRow = controlsRow

        local snap = GUI2.Form:CreateCheckbox(panel, {
            label = L("layout.option.snap"),
            width = 70,
            height = 24,
            get = function() return GetOptions().snap end,
            set = function(value) GetOptions().snap = value and true or false end,
        })
        snap:SetPoint("LEFT", controlsRow, "LEFT", 0, 0)

        local grid = GUI2.Form:CreateCheckbox(panel, {
            label = L("layout.option.grid"),
            width = 62,
            height = 24,
            get = function() return GetOptions().showGrid end,
            set = function(value)
                GetOptions().showGrid = value and true or false
                Layout:UpdateGrid()
            end,
        })
        grid:SetPoint("LEFT", snap, "RIGHT", 2, 0)

        local gridDensity = GUI2.Form:CreateDropdown(panel, {
            width = 74,
            height = 24,
            options = GetGridDensityOptions,
            get = GetGridDensity,
            set = SetGridDensity,
        })
        gridDensity:SetPoint("LEFT", grid, "RIGHT", 2, 0)
        panel.gridDensity = gridDensity

        local done = GUI2.Form:CreateButton(panel, {
            text = L("layout.action.done"),
            width = 88,
            height = 24,
            onClick = function() Layout:CloseEditMode("panel") end,
        })
        done:SetPoint("RIGHT", controlsRow, "RIGHT", 0, 0)
        panel.doneButton = done

        self.controlPanel = panel
    end
    panel:Show()
    self:RefreshControlPanel()
end

function Layout:HideControlPanel()
    if self.controlPanel then self.controlPanel:Hide() end
end

function Layout:RefreshControlPanel()
    local panel = self.controlPanel
    if not panel then return end
    if panel.title then
        panel.title:SetText(LayoutPanelTitleText())
    end
    if panel.hintLeft then
        panel.hintLeft:SetText(L("layout.panel.hint.left_click"))
    end
    if panel.hintRight then
        panel.hintRight:SetText(L("layout.panel.hint.right_click"))
    end
    if panel.hintHide then
        panel.hintHide:SetText(L("layout.panel.hint.shift_right_click"))
    end
    if panel.doneButton and panel.doneButton.SetText then
        panel.doneButton:SetText(L("layout.action.done"))
    end
    if panel.gridDensity and panel.gridDensity.SetValue then
        panel.gridDensity:SetValue(GetGridDensity(), true)
    end
end

local function GetMoverPanelEntry()
    local id = Layout.moverPanelEntryId
    return id and Layout.frames[id] or nil
end

local function GetMoverPanelPlacement(entry)
    if not entry then return nil end
    local placement = Layout.moverPanelLiveId == entry.id and Layout.moverPanelLivePlacement or nil
    return placement or Layout:GetPlacement(entry.id)
end

local function TrimText(value)
    value = tostring(value or "")
    value = string_gsub(value, "^%s+", "")
    value = string_gsub(value, "%s+$", "")
    return value
end

local function DisplayAnchorTargetName(value)
    return AnchorTargetDisplayText and AnchorTargetDisplayText(value) or tostring(value or "")
end

local function DisplayAnchorPoint(value)
    return AnchorPointDisplayText and AnchorPointDisplayText(value) or tostring(value or "")
end

local function GetPersistentFrameName(frame)
    if frame == UIParent then return "UIParent" end
    if frame and frame.GetName then
        local name = frame:GetName()
        if name and name ~= "" and _G[name] == frame then
            return name
        end
    end
    return nil
end

local function IsLayoutInternalFrame(frame)
    local current = frame
    while current do
        if current.yuiLayoutInternal or current.yuiLayoutOverlay then
            return true
        end
        current = current.GetParent and current:GetParent() or nil
    end
    return false
end

local function GetLayoutOverlayEntry(frame)
    local current = frame
    while current do
        if current.yuiLayoutOverlay and current.yuiLayoutEntry then
            return current.yuiLayoutEntry
        end
        current = current.GetParent and current:GetParent() or nil
    end
    return nil
end

local function ResolveNamedAnchorTarget(name, entry)
    name = TrimText(name)
    if NormalizeAnchorTargetAlias then
        name = NormalizeAnchorTargetAlias(name)
    end
    if name == "" then return nil, name end
    if name == "UIParent" then return UIParent, "UIParent" end

    if IsBuiltinAnchorTarget and IsBuiltinAnchorTarget(name) then
        local frame = ResolveBuiltinAnchorTarget and ResolveBuiltinAnchorTarget(name)
        local status
        if not frame and GetBuiltinAnchorPlaceholder then
            frame = GetBuiltinAnchorPlaceholder(name)
            if frame then status = PLACEMENT_SIMULATED end
        end
        if frame then
            if IsLayoutInternalFrame(frame) and not frame.yuiLayoutAnchorPlaceholder then
                return nil, name
            end
            return frame, name, status
        end
        return nil, name, PLACEMENT_PENDING
    end

    local frame = _G[name]
    if frame and (frame.GetObjectType or frame.IsObjectType or frame.GetLeft) then
        if frame.IsForbidden and frame:IsForbidden() then
            return nil, name
        end
        if IsLayoutInternalFrame(frame) then
            return nil, name
        end
        return frame, name
    end
    if entry and IsAnchorTargetDeclared and IsAnchorTargetDeclared(entry, name) then
        return nil, name, PLACEMENT_PENDING
    end
    return nil, name, "invalid"
end

local function GetCurrentMouseFrame()
    if GetMouseFoci then
        local focus = GetMouseFoci()
        if type(focus) == "table" then
            return focus[1]
        end
        return focus
    end
    return GetMouseFocus and GetMouseFocus() or nil
end

local function GetPickableAnchorTarget(frame)
    local current = frame
    while current do
        if IsLayoutInternalFrame(current) then
            return nil, nil
        end
        local name = GetPersistentFrameName(current)
        if name then
            return current, name
        end
        current = current.GetParent and current:GetParent() or nil
    end
    return nil, nil
end

local SetAnchorPickerStatus

local function SetAnchorInputState(message, borderKey)
    local widgets = Layout.moverPanelWidgets
    if Layout.anchorPickerEntryId and SetAnchorPickerStatus then
        SetAnchorPickerStatus(message, borderKey)
    end
    if not widgets then return end
    local input = widgets.anchorName or widgets.anchorTarget
    if input and input.gui2Bg and GUI2 and GUI2.SetBorderColor then
        GUI2:SetBorderColor(input.gui2Bg, message and (borderKey or "color.border.error") or "color.border.default")
    end
    if widgets.anchorStatus then
        if message and message ~= "" then
            widgets.anchorStatus:SetText(message)
            widgets.anchorStatus:Show()
        else
            widgets.anchorStatus:SetText("")
            widgets.anchorStatus:Hide()
        end
    end
end

local function ReportPlacementError(reason)
    if reason ~= "offscreen" then return false end
    SetAnchorInputState(L("layout.position.offscreen_rejected"), "color.border.error")
    return true
end
P.ReportPlacementError = ReportPlacementError

local function CreateAnchorPickerStatusFrame()
    if Layout.anchorPickerStatusFrame then return Layout.anchorPickerStatusFrame end

    local width = 360
    local height = 34
    local frame
    if GUI2 and GUI2.CreateFrame then
        frame = GUI2:CreateFrame(UIParent, {
            name = "YUI_LayoutAnchorPickerStatus",
            template = "BackdropTemplate",
            width = width,
            height = height,
            frameStrata = MOVER_PANEL_STRATA,
        })
    else
        frame = CreateFrame("Frame", "YUI_LayoutAnchorPickerStatus", UIParent, "BackdropTemplate")
        frame:SetSize(width, height)
        frame:SetFrameStrata(MOVER_PANEL_STRATA)
    end
    frame.yuiLayoutInternal = true
    frame:SetSize(width, height)
    if frame.EnableMouse then frame:EnableMouse(false) end
    if frame.SetFrameLevel then frame:SetFrameLevel((MOVER_PANEL_FRAME_LEVEL or 80) + 3) end
    if frame.SetBackdrop then
        frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        frame:SetBackdropColor(0.04, 0.05, 0.07, 0.94)
    end
    if GUI2 and GUI2.CreateBorder then GUI2:CreateBorder(frame, SELECTED_BORDER) end

    local text
    if GUI2 and GUI2.CreateText then
        text = GUI2:CreateText(frame, "", "font.size.md", "color.text.primary")
    else
        text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    end
    text:SetPoint("LEFT", frame, "LEFT", 10, 0)
    text:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    text:SetJustifyH("CENTER")
    text:SetWordWrap(false)
    frame.text = text
    frame:Hide()
    Layout.anchorPickerStatusFrame = frame
    return frame
end

SetAnchorPickerStatus = function(message, borderKey)
    local frame = CreateAnchorPickerStatusFrame()
    if not message or message == "" then
        frame:Hide()
        return
    end
    frame:ClearAllPoints()
    frame:SetPoint("TOP", UIParent, "TOP", 0, -118)
    if GUI2 and GUI2.SetBorderColor then
        GUI2:SetBorderColor(frame, borderKey or "color.border.focus")
    end
    if frame.text then
        frame.text:SetText(message)
        if GUI2 and GUI2.SetTextColorKey then
            GUI2:SetTextColorKey(frame.text, borderKey == "color.border.error" and "color.state.error" or "color.text.primary")
        end
    end
    frame:Show()
end

local function RefreshAnchorPickerButton()
    local widgets = Layout.moverPanelWidgets
    local button = widgets and widgets.pickAnchor
    if not button then return end
    local picking = Layout.anchorPickerEntryId ~= nil
    if button.SetText then
        button:SetText(picking and L("layout.action.picking_frame") or L("layout.action.pick_frame"))
    end
    if button.SetSelected then
        button:SetSelected(picking)
    end
end

local PANEL_GAP = 8
local PANEL_POSITION_ORDER = { "right", "left", "below", "above" }

local function ApplyAnchorPanelLayer(panel)
    ApplyMoverPanelLayer(panel)
    if panel and panel.SetFrameLevel then
        panel:SetFrameLevel((MOVER_PANEL_FRAME_LEVEL or 900) + 1)
    end
end

local function ClampToScreen(value, minValue, maxValue)
    if maxValue < minValue then return minValue end
    return math_max(minValue, math_min(maxValue, value))
end

local function GetFrameRect(frame)
    if not frame or not frame.GetLeft then return nil end
    local left = frame:GetLeft()
    local right = frame:GetRight()
    local top = frame:GetTop()
    local bottom = frame:GetBottom()
    if not left or not right or not top or not bottom then return nil end
    return left, right, top, bottom
end

local function PlacePanelAt(panel, x, top)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", Round(x), Round(top))
end

local function PositionPanelNearFrame(panel, anchor)
    if not panel or not anchor then return false end

    local screenWidth = UIParent:GetWidth() or 0
    local screenHeight = UIParent:GetHeight() or 0
    local panelWidth = panel:GetWidth() or 0
    local panelHeight = panel:GetHeight() or 0
    local left, right, top, bottom = GetFrameRect(anchor)
    if not left or screenWidth <= 0 or screenHeight <= 0 or panelWidth <= 0 or panelHeight <= 0 then
        panel:ClearAllPoints()
        panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        return false
    end

    local centerX = (left + right) / 2
    local centerY = (top + bottom) / 2
    for _, side in ipairs(PANEL_POSITION_ORDER) do
        local x, y, fits
        if side == "right" then
            x = right + PANEL_GAP
            y = centerY + panelHeight / 2
            fits = x + panelWidth <= screenWidth
        elseif side == "left" then
            x = left - PANEL_GAP - panelWidth
            y = centerY + panelHeight / 2
            fits = x >= 0
        elseif side == "below" then
            x = centerX - panelWidth / 2
            y = bottom - PANEL_GAP
            fits = y - panelHeight >= 0
        else
            x = centerX - panelWidth / 2
            y = top + PANEL_GAP + panelHeight
            fits = y <= screenHeight
        end
        if fits then
            PlacePanelAt(panel, ClampToScreen(x, 0, screenWidth - panelWidth), ClampToScreen(y, panelHeight, screenHeight))
            return true
        end
    end

    PlacePanelAt(panel, ClampToScreen(right + PANEL_GAP, 0, screenWidth - panelWidth), ClampToScreen(centerY + panelHeight / 2, panelHeight, screenHeight))
    return true
end

local function ResolveAnchorTargetForEntry(id, name)
    local entry = Layout.frames[id]
    if not entry then return nil end

    local ok, normalized, reasonKey, target, status = EvaluateAnchorTargetCandidate(id, name)
    if not ok then
        SetAnchorInputState(L(reasonKey or "layout.position.invalid_anchor_target"), "color.border.error")
        return nil
    end
    return entry, target, normalized, status
end

local function InferAnchorPointPair(entry, targetFrame, targetName)
    local placement = entry and Layout:GetPlacement(entry.id) or nil
    local anchor = placement and placement.anchor or nil
    if anchor and NormalizeAnchorTargetAlias and NormalizeAnchorTargetAlias(anchor.relative or "UIParent") == targetName then
        return anchor.point or "CENTER", anchor.relativePoint or anchor.point or "CENTER"
    end

    local sourceFrame = ResolveEntryFrame(entry)
    local sourceLeft, sourceRight, sourceTop, sourceBottom = GetFrameRect(sourceFrame)
    local targetLeft, targetRight, targetTop, targetBottom = GetFrameRect(targetFrame)
    if not sourceLeft or not targetLeft then
        return (anchor and anchor.point) or "CENTER", (anchor and (anchor.relativePoint or anchor.point)) or "CENTER"
    end

    local sourceX = (sourceLeft + sourceRight) / 2
    local sourceY = (sourceTop + sourceBottom) / 2
    local targetX = (targetLeft + targetRight) / 2
    local targetY = (targetTop + targetBottom) / 2
    local dx = sourceX - targetX
    local dy = sourceY - targetY
    if math_abs(dx) >= math_abs(dy) then
        if dx >= 0 then
            return "LEFT", "RIGHT"
        end
        return "RIGHT", "LEFT"
    end
    if dy >= 0 then
        return "BOTTOM", "TOP"
    end
    return "TOP", "BOTTOM"
end

local function SetPendingAnchorSelection(entry, target, targetName)
    local point, relativePoint = InferAnchorPointPair(entry, target, targetName)
    Layout.pendingAnchorSourceId = entry.id
    Layout.pendingAnchorTargetName = targetName
    Layout.pendingAnchorPoint = point
    Layout.pendingAnchorRelativePoint = relativePoint
end

local function CreateMoverBlankClickLayer()
    if Layout.moverBlankClickFrame then return Layout.moverBlankClickFrame end

    local frame = CreateFrame("Button", "YUI_LayoutMoverBlankClick", UIParent)
    frame.yuiLayoutInternal = true
    frame:SetAllPoints(UIParent)
    frame:SetFrameStrata("LOW")
    frame:SetFrameLevel(1)
    frame:EnableMouse(true)
    frame:RegisterForClicks("LeftButtonUp")
    frame:SetScript("OnClick", function(_, button)
        if button == "LeftButton" and Layout.moverPanel and Layout.moverPanel:IsShown() then
            Layout:HideMoverPanel()
        end
    end)
    frame:Hide()
    Layout.moverBlankClickFrame = frame
    return frame
end

function Layout:RefreshMoverBlankClickLayer()
    local frame = self.moverBlankClickFrame
    local shouldShow = self.editing and self.moverPanel and self.moverPanel:IsShown() and not self.anchorPickerEntryId
    if shouldShow then
        frame = frame or CreateMoverBlankClickLayer()
        frame:Show()
    elseif frame then
        frame:Hide()
    end
end

function Layout:BeginAnchorPointConfirm(id, name)
    local entry, target, normalized = ResolveAnchorTargetForEntry(id, name)
    if not entry then return false end
    SetAnchorInputState(nil)
    SetPendingAnchorSelection(entry, target, normalized)
    if self.moverPanel then
        self.moverPanel:Hide()
    end
    self:ShowAnchorPanel(entry)
    self:RefreshOverlayVisuals()
    return true
end

function Layout:ApplyAnchorTargetName(id, name)
    return self:BeginAnchorPointConfirm(id, name)
end

function Layout:ConfirmAnchorPointSelection()
    local id = self.pendingAnchorSourceId
    local entry = id and self.frames[id]
    local targetName = self.pendingAnchorTargetName
    if not entry or not targetName then return false end

    local placement = self:GetPlacement(id)
    if not placement then return false end
    placement.anchor = placement.anchor or {}
    placement.offset = placement.offset or {}
    placement.anchor.point = self.pendingAnchorPoint or "CENTER"
    placement.anchor.relative = targetName
    placement.anchor.relativePoint = self.pendingAnchorRelativePoint or placement.anchor.point
    placement.offset.x = 0
    placement.offset.y = 0

    local applied, reason = self:CommitPlacementOrRestore(
        id,
        placement,
        "anchor"
    )
    if not applied then
        ReportPlacementError(reason)
        return false
    end

    self.pendingAnchorSourceId = nil
    self.pendingAnchorTargetName = nil
    self.pendingAnchorPoint = nil
    self.pendingAnchorRelativePoint = nil
    self:HideAnchorPanel()
    self:ShowMoverPanel(entry)
    return true
end

function Layout:CancelAnchorPointSelection()
    local id = self.pendingAnchorSourceId
    self.pendingAnchorSourceId = nil
    self.pendingAnchorTargetName = nil
    self.pendingAnchorPoint = nil
    self.pendingAnchorRelativePoint = nil
    self:HideAnchorPanel()
    if id and self.frames[id] then
        self:ShowMoverPanel(id)
    end
    return true
end

function Layout:PickAnchorTargetFromEntry(entry)
    local sourceId = self.anchorPickerEntryId
    if not sourceId or not entry then return false end

    local _, name = GetPickableAnchorTarget(ResolveEntryFrame(entry))
    if not name then
        SetAnchorInputState(L("layout.position.invalid_anchor_target"), "color.border.error")
        return false
    end
    local ok, normalized, reasonKey = EvaluateAnchorTargetCandidate(sourceId, entry)
    if not ok then
        SetAnchorInputState(L(reasonKey or "layout.position.invalid_anchor_target"), "color.border.error")
        return false
    end
    self.anchorPickerCandidate = normalized or name
    if self:BeginAnchorPointConfirm(sourceId, normalized or name) then
        self:StopAnchorTargetPicker(false)
        self:RefreshOverlayVisuals()
        return true
    end
    return false
end

function Layout:CommitAnchorTargetInput(editbox)
    local entry = GetMoverPanelEntry()
    if not entry then return false end
    return self:ApplyAnchorTargetName(entry.id, editbox and editbox:GetText() or nil)
end

function Layout:StopAnchorTargetPicker(restorePanel)
    local restoreId = self.anchorPickerEntryId
    self.anchorPickerEntryId = nil
    self.anchorPickerCandidate = nil
    self.anchorPickerWaitingForRelease = nil
    self.anchorPickerLeftDown = nil
    self.anchorPickerElapsed = nil
    if self.anchorPickerFrame then
        self.anchorPickerFrame:Hide()
        self.anchorPickerFrame:SetScript("OnUpdate", nil)
    end
    if self.anchorPickerStatusFrame then
        self.anchorPickerStatusFrame:Hide()
    end
    RefreshAnchorPickerButton()
    self:RefreshMoverBlankClickLayer()
    self:RefreshOverlayVisuals()
    if restorePanel and restoreId and self.frames[restoreId] then
        self:ShowMoverPanel(restoreId)
    end
end

function Layout:StartAnchorTargetPicker(id)
    if not self.frames[id] then return false end

    local picker = self.anchorPickerFrame
    if not picker then
        picker = CreateFrame("Frame", "YUI_LayoutAnchorPicker", UIParent)
        picker.yuiLayoutInternal = true
        picker:SetAllPoints(UIParent)
        if picker.EnableMouse then picker:EnableMouse(false) end
        self.anchorPickerFrame = picker
    end

    self.anchorPickerEntryId = id
    self.anchorPickerCandidate = nil
    self.anchorPickerWaitingForRelease = IsMouseButtonDown and IsMouseButtonDown("LeftButton") or false
    self.anchorPickerLeftDown = self.anchorPickerWaitingForRelease
    self.anchorPickerElapsed = 0
    if self.anchorPanel then self.anchorPanel:Hide() end
    self.anchorPanelOpen = false
    if self.moverPanel then self.moverPanel:Hide() end
    picker:SetScript("OnUpdate", function(_, elapsed) Layout:UpdateAnchorTargetPicker(elapsed) end)
    if picker.EnableKeyboard then picker:EnableKeyboard(true) end
    if picker.SetPropagateKeyboardInput then picker:SetPropagateKeyboardInput(true) end
    picker:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" then
            Layout:StopAnchorTargetPicker(true)
        end
    end)
    picker:Show()
    RefreshAnchorPickerButton()
    SetAnchorInputState(L("layout.position.pick_active"), "color.border.focus")
    self:RefreshMoverBlankClickLayer()
    self:RefreshOverlayVisuals()
    return true
end

function Layout:UpdateAnchorTargetPicker(elapsed)
    local id = self.anchorPickerEntryId
    if not id then return end

    self.anchorPickerElapsed = (self.anchorPickerElapsed or 0) + (elapsed or 0)
    if self.anchorPickerElapsed >= MOVER_REFRESH_INTERVAL then
        self.anchorPickerElapsed = 0
        local focus = GetCurrentMouseFrame()
        local overlayEntry = GetLayoutOverlayEntry(focus)
        local _, name
        if overlayEntry then
            _, name = GetPickableAnchorTarget(ResolveEntryFrame(overlayEntry))
        else
            _, name = GetPickableAnchorTarget(focus)
        end
        self.anchorPickerCandidate = name
    end

    if not IsMouseButtonDown then return end
    local leftDown = IsMouseButtonDown("LeftButton") == true
    if self.anchorPickerWaitingForRelease then
        if not leftDown then
            self.anchorPickerWaitingForRelease = nil
        end
    elseif leftDown and not self.anchorPickerLeftDown and self.anchorPickerCandidate then
        local name = self.anchorPickerCandidate
        local focus = GetCurrentMouseFrame()
        local overlayEntry = GetLayoutOverlayEntry(focus)
        if overlayEntry and overlayEntry.overlay then
            SuppressNextOverlayClick(overlayEntry.overlay)
            self:PickAnchorTargetFromEntry(overlayEntry)
        elseif self:BeginAnchorPointConfirm(id, name) then
            self:StopAnchorTargetPicker(false)
            self:RefreshOverlayVisuals()
        end
    end
    self.anchorPickerLeftDown = leftDown
end

local function CreatePanelLabel(parent, text, x, y, width)
    local label = GUI2:CreateText(parent, text, "font.size.md", "color.text.secondary")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 5)
    label:SetWidth(width)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    return label
end

local function CreateAnchorGridLine(parent)
    local line = GUI2:CreateTexture(parent, "color.border.subtle", "BACKGROUND")
    if line.SetAlpha then line:SetAlpha(0.78) end
    return line
end

local function SetAnchorGridTexturePaint(texture, paint)
    if not texture then return end
    if GUI2.SetTexturePaintKey then
        GUI2:SetTexturePaintKey(texture, paint)
    elseif texture.SetVertexColor and GUI2.GetColor then
        texture:SetVertexColor(GUI2:GetColor(paint))
    end
end

local function RefreshAnchorPointGridVisual(frame)
    if not frame then return end
    local disabled = frame.gui2Disabled == true
    local borderPaint = frame.hoverPoint and not disabled and "color.border.accent" or "color.border.subtle"
    local borderAlpha = disabled and 0.30 or (frame.hoverPoint and 0.95 or 0.78)

    if frame.borderLines then
        for _, line in ipairs(frame.borderLines) do
            SetAnchorGridTexturePaint(line, borderPaint)
            if line.SetAlpha then line:SetAlpha(borderAlpha) end
        end
    end

    if frame.buttons then
        for _, button in ipairs(frame.buttons) do
            local selected = button.anchorPointValue == frame.value
            local hovered = button.anchorPointValue == frame.hoverPoint
            local paint = "color.text.secondary"
            local alpha = 1
            if disabled then
                paint = "color.text.disabled"
                alpha = 0.35
            elseif selected then
                paint = "color.accent.primary"
            elseif hovered then
                paint = "color.text.primary"
            end
            SetAnchorGridTexturePaint(button.anchorPointDot, paint)
            if button.anchorPointDot and button.anchorPointDot.SetAlpha then
                button.anchorPointDot:SetAlpha(alpha)
            end
        end
    end
end

local function CreateAnchorPointGrid(parent, opts)
    opts = opts or {}
    local width = opts.width or 128
    local titleHeight = 18
    local hitSize = opts.hitSize or 22
    local dotSize = opts.dotSize or 8
    local rectWidth = math_min(opts.rectWidth or 104, width - 14)
    local rectHeight = opts.rectHeight or 62
    local rectX = Round((width - rectWidth) / 2)
    local rectY = -(titleHeight + 14)
    local height = opts.height or (titleHeight + 14 + rectHeight + 8)
    local frame = GUI2:CreateFrame(parent, {
        width = width,
        height = height,
    })
    frame.buttons = {}
    frame.borderLines = {}
    frame.value = opts.value or "CENTER"
    frame.onChange = opts.set

    local title = GUI2:CreateText(frame, opts.label or "", "font.size.sm", "color.text.secondary")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    title:SetJustifyH("CENTER")
    title:SetWordWrap(false)
    frame.title = title

    local lineSize = 1
    local top = CreateAnchorGridLine(frame)
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", rectX, rectY)
    top:SetSize(rectWidth, lineSize)
    frame.borderLines[#frame.borderLines + 1] = top

    local bottom = CreateAnchorGridLine(frame)
    bottom:SetPoint("TOPLEFT", frame, "TOPLEFT", rectX, rectY - rectHeight)
    bottom:SetSize(rectWidth, lineSize)
    frame.borderLines[#frame.borderLines + 1] = bottom

    local left = CreateAnchorGridLine(frame)
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", rectX, rectY)
    left:SetSize(lineSize, rectHeight)
    frame.borderLines[#frame.borderLines + 1] = left

    local right = CreateAnchorGridLine(frame)
    right:SetPoint("TOPLEFT", frame, "TOPLEFT", rectX + rectWidth, rectY)
    right:SetSize(lineSize, rectHeight)
    frame.borderLines[#frame.borderLines + 1] = right

    local pointX = {
        rectX,
        Round(rectX + (rectWidth / 2)),
        rectX + rectWidth,
    }
    local pointY = {
        rectY,
        Round(rectY - (rectHeight / 2)),
        rectY - rectHeight,
    }

    for index, point in ipairs(ANCHOR_POINTS or {}) do
        local col = ((index - 1) % 3)
        local row = math_floor((index - 1) / 3)
        local button = GUI2:CreateButtonFrame(frame, {
            width = hitSize,
            height = hitSize,
        })
        button:SetPoint("CENTER", frame, "TOPLEFT", pointX[col + 1], pointY[row + 1])
        button.anchorPointValue = point
        local dot = GUI2:CreateTexture(button, nil, "ARTWORK")
        dot:SetSize(dotSize, dotSize)
        dot:SetPoint("CENTER")
        button.anchorPointDot = dot
        button:SetScript("OnClick", function(self)
            if frame.gui2Disabled then return end
            if GameTooltip and GameTooltip:IsOwned(self) then
                YUI.HideGameTooltip()
            end
            frame:SetValue(self.anchorPointValue)
        end)
        button:SetScript("OnEnter", function(self)
            if frame.gui2Disabled then return end
            local value = self.anchorPointValue
            frame.hoverPoint = value
            RefreshAnchorPointGridVisual(frame)
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L("layout.position.select_anchor_point") .. ": " .. DisplayAnchorPoint(value))
                GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave", function(self)
            if frame.hoverPoint == self.anchorPointValue then
                frame.hoverPoint = nil
            end
            RefreshAnchorPointGridVisual(frame)
            if GameTooltip and GameTooltip:IsOwned(self) then
                YUI.HideGameTooltip()
            end
        end)
        frame.buttons[#frame.buttons + 1] = button
    end

    function frame:SetValue(value, silent)
        self.value = value or "CENTER"
        RefreshAnchorPointGridVisual(self)
        if not silent and self.onChange then
            self.onChange(self.value)
        end
    end

    function frame:SetDisabled(disabled)
        self.gui2Disabled = disabled and true or false
        for _, button in ipairs(self.buttons) do
            button.gui2Disabled = self.gui2Disabled
            if self.gui2Disabled then
                if GameTooltip and GameTooltip:IsOwned(button) then
                    YUI.HideGameTooltip()
                end
                if button.Disable then button:Disable() end
            elseif button.Enable then
                button:Enable()
            end
        end
        if self.gui2Disabled then self.hoverPoint = nil end
        RefreshAnchorPointGridVisual(self)
    end

    frame:SetValue(frame.value, true)
    return frame
end

local function CommitOffsetInput(axis, editbox)
    local entry = GetMoverPanelEntry()
    if not entry or not editbox then return false end
    if Layout.IsPlacementReady and not Layout:IsPlacementReady(entry.id) then
        Layout:RefreshMovementWidgets()
        return false
    end

    local value = tonumber(editbox:GetText())
    if not value then
        Layout:RefreshMovementWidgets()
        return false
    end
    value = math_max(OFFSET_MIN, math_min(OFFSET_MAX, Round(value)))

    local patch = {}
    patch[axis] = value
    local applied, reason = Layout:PatchPlacement(entry.id, patch)
    if not applied then
        ReportPlacementError(reason)
        Layout:RefreshMovementWidgets()
        return false
    end
    SetAnchorInputState(nil)
    return true
end

local function AddNudgeButton(parent, widgets, dx, dy, x, y, direction)
    local button = GUI2.Form:CreateButton(parent, {
        text = "",
        width = 28,
        height = 24,
        tone = "default",
        onClick = function()
            local entry = GetMoverPanelEntry()
            if entry and (not Layout.IsPlacementReady or Layout:IsPlacementReady(entry.id)) then
                local applied, reason = Layout:NudgeFrame(entry.id, dx, dy)
                if not applied then
                    ReportPlacementError(reason)
                else
                    SetAnchorInputState(nil)
                end
            end
        end,
    })
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    if button.text then button.text:SetText("") end
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ARROW_TEXTURE)
    if icon.SetBlendMode then icon:SetBlendMode("BLEND") end
    icon:SetSize(13, 13)
    icon:SetPoint("CENTER")
    SetArrowDirection(icon, direction)
    if icon.SetVertexColor then
        if GUI2 and GUI2.GetColor then
            icon:SetVertexColor(GUI2:GetColor("color.text.accent"))
        else
            icon:SetVertexColor(0.2, 0.72, 1, 1)
        end
    end
    button.icon = icon
    widgets.nudges[#widgets.nudges + 1] = button
    return button
end

function Layout:CreateMoverPanel()
    if self.moverPanel then return self.moverPanel end
    if not GUI2 or not GUI2.Form then return nil end

    local width = 400
    local height = 236
    local padding = 14
    local panel = GUI2:CreateFrame(UIParent, {
        name = "YUI_LayoutMoverPanel",
        template = "BackdropTemplate",
        width = width,
        height = height,
        clamped = true,
        frameStrata = MOVER_PANEL_STRATA,
    })
    panel:SetSize(width, height)
    panel.yuiLayoutInternal = true
    ApplyMoverPanelLayer(panel)
    panel:EnableMouse(true)
    if panel.SetBackdrop then
        panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        panel:SetBackdropColor(0.06, 0.07, 0.09, 0.92)
    end
    if GUI2.CreateBorder then GUI2:CreateBorder(panel, SELECTED_BORDER) end

    local widgets = self.moverPanelWidgets or {}
    self.moverPanelWidgets = widgets

    local title = GUI2:CreateText(panel, "", "font.size.lg", "color.text.accent")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", padding, -11)
    title:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -48, -11)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(true)
    widgets.title = title

    local close = GUI2:CreateCloseButton(panel, function()
        Layout:HideMoverPanel()
    end)
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -8)
    widgets.close = close

    CreatePanelLabel(panel, "X", padding, -44, 24)
    local offsetX = GUI2.Form:CreateEditBox(panel, {
        width = 84,
        height = 26,
        text = "0",
        onFocusLost = function(editbox)
            CommitOffsetInput("x", editbox)
        end,
    })
    offsetX:SetPoint("TOPLEFT", panel, "TOPLEFT", padding + 28, -44)
    offsetX:SetJustifyH("CENTER")
    offsetX:SetScript("OnEnterPressed", function(editbox)
        CommitOffsetInput("x", editbox)
        editbox:ClearFocus()
    end)
    offsetX:SetScript("OnEscapePressed", function(editbox)
        Layout:RefreshMovementWidgets()
        editbox:ClearFocus()
    end)
    widgets.offsetX = offsetX

    CreatePanelLabel(panel, "Y", padding, -78, 24)
    local offsetY = GUI2.Form:CreateEditBox(panel, {
        width = 84,
        height = 26,
        text = "0",
        onFocusLost = function(editbox)
            CommitOffsetInput("y", editbox)
        end,
    })
    offsetY:SetPoint("TOPLEFT", panel, "TOPLEFT", padding + 28, -78)
    offsetY:SetJustifyH("CENTER")
    offsetY:SetScript("OnEnterPressed", function(editbox)
        CommitOffsetInput("y", editbox)
        editbox:ClearFocus()
    end)
    offsetY:SetScript("OnEscapePressed", function(editbox)
        Layout:RefreshMovementWidgets()
        editbox:ClearFocus()
    end)
    widgets.offsetY = offsetY

    local resetWidth = 76
    local nudgeGroupWidth = 88
    local rightSafe = 20
    widgets.nudges = {}
    local nudgeX = width - padding - rightSafe - nudgeGroupWidth
    local nudgeY = -44
    AddNudgeButton(panel, widgets, 0, 1, nudgeX + 30, nudgeY, "up")
    AddNudgeButton(panel, widgets, -1, 0, nudgeX, nudgeY - 28, "left")
    AddNudgeButton(panel, widgets, 1, 0, nudgeX + 60, nudgeY - 28, "right")
    AddNudgeButton(panel, widgets, 0, -1, nudgeX + 30, nudgeY - 28, "down")

    local anchorY = -112
    local labelWidth = 78
    local controlX = padding + labelWidth
    local selectWidth = 72
    local targetWidth = width - padding * 2 - labelWidth - selectWidth - 8
    CreatePanelLabel(panel, L("layout.position.anchor_target"), padding, anchorY, labelWidth)
    local anchorTarget = GUI2.Form:CreateDropdown(panel, {
        width = targetWidth,
        height = 26,
        options = function()
            return BuildAnchorTargetOptions(GetMoverPanelEntry())
        end,
        get = function()
            local placement = GetMoverPanelPlacement(GetMoverPanelEntry())
            return placement and placement.anchor and placement.anchor.relative or "UIParent"
        end,
        set = function(value)
            local entry = GetMoverPanelEntry()
            if entry then Layout:BeginAnchorPointConfirm(entry.id, value) end
        end,
    })
    anchorTarget:SetPoint("TOPLEFT", panel, "TOPLEFT", controlX, anchorY)
    widgets.anchorTarget = anchorTarget

    local pickAnchor = GUI2.Form:CreateButton(panel, {
        text = L("layout.action.select_anchor_target"),
        width = selectWidth,
        height = 26,
        tone = "default",
        onClick = function()
            local entry = GetMoverPanelEntry()
            if entry then Layout:StartAnchorTargetPicker(entry.id) end
        end,
    })
    pickAnchor:SetPoint("LEFT", anchorTarget, "RIGHT", 8, 0)
    widgets.pickAnchor = pickAnchor

    local pointY = -148
    local summaryWidth = 100
    CreatePanelLabel(panel, L("layout.position.point"), padding, pointY, labelWidth)
    local pointSummary = GUI2.Form:CreateButton(panel, {
        text = "",
        width = summaryWidth,
        height = 26,
        tone = "default",
        onClick = function()
            local entry = GetMoverPanelEntry()
            local placement = GetMoverPanelPlacement(entry)
            local target = placement and placement.anchor and placement.anchor.relative or "UIParent"
            if entry then Layout:BeginAnchorPointConfirm(entry.id, target) end
        end,
    })
    pointSummary:SetPoint("TOPLEFT", panel, "TOPLEFT", controlX, pointY)
    widgets.pointSummary = pointSummary

    local relativeLabelX = controlX + summaryWidth + 16
    CreatePanelLabel(panel, L("layout.position.target_point"), relativeLabelX, pointY, 76)
    local relativePointSummary = GUI2.Form:CreateButton(panel, {
        text = "",
        width = summaryWidth,
        height = 26,
        tone = "default",
        onClick = function()
            local entry = GetMoverPanelEntry()
            local placement = GetMoverPanelPlacement(entry)
            local target = placement and placement.anchor and placement.anchor.relative or "UIParent"
            if entry then Layout:BeginAnchorPointConfirm(entry.id, target) end
        end,
    })
    relativePointSummary:SetPoint("TOPLEFT", panel, "TOPLEFT", relativeLabelX + 76, pointY)
    widgets.relativePointSummary = relativePointSummary

    local hint = GUI2:CreateText(panel, L("layout.hint.mousewheel_nudge"), "font.size.sm", "color.text.secondary")
    hint:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", padding, 18)
    hint:SetWidth(94)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(false)
    widgets.wheelHint = hint

    local reset = GUI2.Form:CreateButton(panel, {
        text = L("layout.action.reset_short"),
        width = resetWidth,
        height = 24,
        tone = "default",
        onClick = function()
            local entry = GetMoverPanelEntry()
            if not entry then return end
            local entryId = entry.id
            if YUI.Settings and YUI.Settings.ShowConfirmPopup then
                YUI.Settings:ShowConfirmPopup(L("layout.confirm.reset_selected"), function()
                    if Layout.frames[entryId] then Layout:ResetFrame(entryId) end
                end, {
                    titleText = L("layout.action.reset_selected"),
                    acceptTone = "danger",
                    cancelTone = "default",
                })
            else
                Layout:ResetFrame(entryId)
            end
        end,
    })
    reset:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -padding, 14)
    widgets.reset = reset

    panel:Hide()
    self.moverPanel = panel
    return panel
end

function Layout:CreateAnchorPanel()
    if self.anchorPanel then return self.anchorPanel end
    if not GUI2 or not GUI2.Form then return nil end

    local width = 392
    local height = 224
    local padding = 14
    local contentWidth = width - padding * 2
    local panel = GUI2:CreateFrame(UIParent, {
        name = "YUI_LayoutAnchorPanel",
        template = "BackdropTemplate",
        width = width,
        height = height,
        clamped = true,
        frameStrata = MOVER_PANEL_STRATA,
    })
    panel:SetSize(width, height)
    panel.yuiLayoutInternal = true
    ApplyAnchorPanelLayer(panel)
    panel:EnableMouse(true)
    if panel.SetBackdrop then
        panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        panel:SetBackdropColor(0.05, 0.06, 0.08, 0.94)
    end
    if GUI2.CreateBorder then GUI2:CreateBorder(panel, SELECTED_BORDER) end

    local widgets = self.moverPanelWidgets or {}
    self.moverPanelWidgets = widgets

    local title = GUI2:CreateText(panel, L("layout.action.anchor_settings"), "font.size.md", "color.text.primary")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", padding, -12)
    title:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -42, -12)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    widgets.anchorPanelTitle = title

    local close = GUI2:CreateCloseButton(panel, function()
        Layout:CancelAnchorPointSelection()
    end)
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)
    widgets.anchorClose = close

    local summary = GUI2:CreateText(panel, "", "font.size.sm", "color.text.secondary")
    summary:SetPoint("TOPLEFT", panel, "TOPLEFT", padding, -40)
    summary:SetWidth(contentWidth)
    summary:SetJustifyH("LEFT")
    summary:SetWordWrap(false)
    widgets.anchorSummary = summary

    local anchorStatus = GUI2:CreateText(panel, "", "font.size.sm", "color.state.warning")
    anchorStatus:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -4)
    anchorStatus:SetWidth(contentWidth)
    anchorStatus:SetJustifyH("LEFT")
    anchorStatus:SetWordWrap(false)
    anchorStatus:Hide()
    widgets.anchorStatus = anchorStatus

    local y = -78
    local gridGap = 20
    local gridWidth = math_floor((contentWidth - gridGap) / 2)
    local gridHeight = 114
    local point = CreateAnchorPointGrid(panel, {
        width = gridWidth,
        height = gridHeight,
        label = L("layout.position.point"),
        set = function(value)
            Layout.pendingAnchorPoint = value
            Layout:RefreshMovementWidgets()
        end,
    })
    point:SetPoint("TOPLEFT", panel, "TOPLEFT", padding, y)
    widgets.point = point

    local relativePoint = CreateAnchorPointGrid(panel, {
        width = gridWidth,
        height = gridHeight,
        label = L("layout.position.target_point"),
        set = function(value)
            Layout.pendingAnchorRelativePoint = value
            Layout:RefreshMovementWidgets()
        end,
    })
    relativePoint:SetPoint("TOPLEFT", point, "TOPRIGHT", gridGap, 0)
    widgets.relativePoint = relativePoint

    local confirm = GUI2.Form:CreateButton(panel, {
        text = L("common.confirm"),
        width = 112,
        height = 26,
        tone = "accent",
        onClick = function()
            Layout:ConfirmAnchorPointSelection()
        end,
    })
    confirm:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -padding, 12)
    widgets.anchorConfirm = confirm

    local cancel = GUI2.Form:CreateButton(panel, {
        text = L("common.cancel"),
        width = 112,
        height = 26,
        tone = "default",
        onClick = function()
            Layout:CancelAnchorPointSelection()
        end,
    })
    cancel:SetPoint("RIGHT", confirm, "LEFT", -8, 0)
    widgets.anchorCancel = cancel

    panel:Hide()
    self.anchorPanel = panel
    return panel
end

function Layout:PositionMoverPanel(entry)
    local panel = self.moverPanel
    local overlay = entry and entry.overlay
    if not panel or not overlay or not overlay:IsShown() then return end

    ApplyMoverPanelLayer(panel)
    PositionPanelNearFrame(panel, overlay)
    if self.anchorPanel and self.anchorPanel:IsShown() then
        self:PositionAnchorPanel(entry)
    end
end

function Layout:PositionAnchorPanel(entry)
    local panel = self.anchorPanel
    if not panel then return end

    local anchor = self.moverPanel and self.moverPanel:IsShown() and self.moverPanel or (entry and entry.overlay)
    if not anchor then return end
    ApplyAnchorPanelLayer(panel)
    PositionPanelNearFrame(panel, anchor)
end

function Layout:ShowAnchorPanel(entryOrId)
    if not self.editing then return false end
    local entry = type(entryOrId) == "string" and self.frames[entryOrId] or entryOrId or GetMoverPanelEntry()
    if not entry then return false end

    local panel = self:CreateAnchorPanel()
    if not panel then return false end
    if self.pendingAnchorSourceId ~= entry.id or not self.pendingAnchorTargetName then
        local placement = self:GetPlacement(entry.id)
        local targetName = placement and placement.anchor and placement.anchor.relative or "UIParent"
        local resolvedEntry, target, normalized = ResolveAnchorTargetForEntry(entry.id, targetName)
        if not resolvedEntry then return false end
        SetPendingAnchorSelection(entry, target, normalized)
    end
    self.anchorPanelOpen = true
    panel.entryId = entry.id
    panel.targetName = self.pendingAnchorTargetName
    panel:Show()
    self:PositionAnchorPanel(entry)
    self:RefreshMovementWidgets()
    ApplyAnchorPanelLayer(panel)
    return true
end

function Layout:HideAnchorPanel()
    self.anchorPanelOpen = false
    self:StopAnchorTargetPicker()
    if self.anchorPanel then
        self.anchorPanel.entryId = nil
        self.anchorPanel.targetName = nil
        self.anchorPanel:Hide()
    end
    self.pendingAnchorSourceId = nil
    self.pendingAnchorTargetName = nil
    self.pendingAnchorPoint = nil
    self.pendingAnchorRelativePoint = nil
    if self.moverPanel and self.moverPanel:IsShown() then
        self:RefreshMovementWidgets()
    end
    self:RefreshMoverBlankClickLayer()
end

function Layout:ShowMoverPanel(entryOrId)
    if not self.editing then return false end
    local entry = type(entryOrId) == "string" and self.frames[entryOrId] or entryOrId
    if not entry or not entry.overlay or not entry.overlay:IsShown() then return false end

    local panel = self:CreateMoverPanel()
    if not panel then return false end
    local keepAnchorPanelOpen = self.anchorPanelOpen == true and self.anchorPanel and self.anchorPanel:IsShown()
    if self.anchorPickerEntryId and self.anchorPickerEntryId ~= entry.id then
        self:StopAnchorTargetPicker()
    end
    self.moverPanelEntryId = entry.id
    panel.entryId = entry.id
    panel:Show()
    self:PositionMoverPanel(entry)
    self:RefreshMovementWidgets()
    ApplyMoverPanelLayer(panel)
    if keepAnchorPanelOpen then
        self:ShowAnchorPanel(entry)
    end
    self:RefreshMoverBlankClickLayer()
    return true
end

function Layout:RefreshDraggingMover(entry, force)
    if not entry then return end

    local now = GetTime and GetTime() or nil
    if not force and now and self.nextMoverPanelRefresh and now < self.nextMoverPanelRefresh then
        return
    end
    if now then
        self.nextMoverPanelRefresh = now + MOVER_REFRESH_INTERVAL
    end

    local placement = CaptureMoverPlacement(entry)
    if not placement then return end
    self.moverPanelLiveId = entry.id
    self.moverPanelLivePlacement = placement
    if RefreshDragCoordinateInfo then
        RefreshDragCoordinateInfo(entry, placement)
    end
    if self.moverPanelEntryId == entry.id and self.moverPanel and self.moverPanel:IsShown() then
        self:PositionMoverPanel(entry)
        self:RefreshMovementWidgets()
    end
    if self.selectedId == entry.id then
        self:RefreshAnchorLine()
    end
end

function Layout:HideMoverPanel(id)
    if id and self.moverPanelEntryId ~= id then return end
    local closedEntryId = self.moverPanelEntryId
    local deselectClosedEntry = closedEntryId and self.selectedId == closedEntryId
    if not self.editing then
        if HideDragCoordinateInfo then HideDragCoordinateInfo() end
        if self.hoverInfoFrame then self.hoverInfoFrame:Hide() end
        self.hoveredId = nil
    end
    self.anchorPanelOpen = false
    if self.anchorPanel then
        self.anchorPanel.entryId = nil
        self.anchorPanel.targetName = nil
        self.anchorPanel:Hide()
    end
    self:StopAnchorTargetPicker()
    self.pendingAnchorSourceId = nil
    self.pendingAnchorTargetName = nil
    self.pendingAnchorPoint = nil
    self.pendingAnchorRelativePoint = nil
    self.moverPanelEntryId = nil
    self.moverPanelLiveId = nil
    self.moverPanelLivePlacement = nil
    if self.moverPanel then
        self.moverPanel.entryId = nil
        self.moverPanel:Hide()
    end
    if deselectClosedEntry then
        self.selectedId = nil
        self:RefreshOverlayVisuals()
        self:RefreshControlPanel()
        self:RefreshSettingsPanel()
    end
    self:RefreshMoverBlankClickLayer()
end

local function RenderRegisteredOptions(parent, entry)
    local options = entry and (entry.options or entry.spec.options)
    if not options then return 0 end
    if type(options) == "function" then
        local ok, width, height = SafeCall("Layout:renderOptions:" .. tostring(entry.id), options, parent, entry, Layout)
        if ok then return tonumber(height) or 0 end
        return 0
    end
    if type(options) == "table" and YUI.Settings and YUI.Settings.RenderConfig then
        YUI.Settings:RenderConfig(parent, options)
        return 180
    end
    return 0
end

local function RenderSettings(parent)
    if not GUI2 then return end
    local widgets = {}
    Layout.settingsWidgets = widgets

    local width = math_min(parent:GetWidth() or 720, 720)
    local root = GUI2:CreateFrame(parent, { width = width, height = 1 })
    root:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)

    local y = 0
    local title = GUI2:CreateText(root, L("settings.layout.title"), "font.size.xl", "color.text.primary")
    title:SetPoint("TOPLEFT", root, "TOPLEFT", 0, y)
    y = y - 28

    local desc = GUI2:CreateText(root, L("settings.layout.desc"), "font.size.md", "color.text.secondary")
    desc:SetPoint("TOPLEFT", root, "TOPLEFT", 0, y)
    desc:SetWidth(width - 8)
    desc:SetJustifyH("LEFT")
    y = y - 44

    local open = GUI2.Form:CreateButton(root, {
        text = L("layout.action.open"),
        width = 116,
        onClick = function() Layout:OpenEditMode("settings") end,
    })
    open:SetPoint("TOPLEFT", root, "TOPLEFT", 0, y)

    local close = GUI2.Form:CreateButton(root, {
        text = L("layout.action.close"),
        width = 116,
        tone = "default",
        onClick = function() Layout:CloseEditMode("settings") end,
    })
    close:SetPoint("LEFT", open, "RIGHT", 10, 0)

    local resetAll = GUI2.Form:CreateButton(root, {
        text = L("layout.action.reset_all"),
        width = 116,
        tone = "default",
        onClick = function() Layout:ResetAllFrames() end,
    })
    resetAll:SetPoint("LEFT", close, "RIGHT", 10, 0)
    y = y - 42

    local snap = GUI2.Form:CreateCheckbox(root, {
        label = L("layout.option.snap"),
        width = 160,
        get = function() return GetOptions().snap end,
        set = function(value) GetOptions().snap = value and true or false end,
    })
    snap:SetPoint("TOPLEFT", root, "TOPLEFT", 0, y)

    local grid = GUI2.Form:CreateCheckbox(root, {
        label = L("layout.option.grid"),
        width = 160,
        get = function() return GetOptions().showGrid end,
        set = function(value)
            GetOptions().showGrid = value and true or false
            Layout:UpdateGrid()
        end,
    })
    grid:SetPoint("LEFT", snap, "RIGHT", 12, 0)

    local density = GUI2.Form:CreateDropdown(root, {
        width = 140,
        options = GetGridDensityOptions,
        get = GetGridDensity,
        set = SetGridDensity,
    })
    density:SetPoint("LEFT", grid, "RIGHT", 12, 0)

    local locked = GUI2.Form:CreateCheckbox(root, {
        label = L("layout.option.locked"),
        width = 160,
        get = function() return GetOptions().locked end,
        set = function(value) GetOptions().locked = value and true or false end,
    })
    locked:SetPoint("LEFT", density, "RIGHT", 12, 0)
    y = y - 44

    local selected = GUI2:CreateText(root, "", "font.size.md", "color.text.primary")
    selected:SetPoint("TOPLEFT", root, "TOPLEFT", 0, y)
    selected:SetWidth(width)
    selected:SetJustifyH("LEFT")
    widgets.selectedText = selected
    y = y - 30

    local actionsRow = GUI2:CreateFrame(root, { width = width, height = 30 })
    actionsRow:SetPoint("TOPLEFT", root, "TOPLEFT", 0, y)

    local resetSelected = GUI2.Form:CreateButton(actionsRow, {
        text = L("layout.action.reset_selected"),
        width = 126,
        tone = "default",
        onClick = function() if Layout.selectedId then Layout:ResetFrame(Layout.selectedId) end end,
    })
    resetSelected:SetPoint("LEFT", actionsRow, "LEFT", 0, 0)

    local plugin = GUI2.Form:CreateButton(actionsRow, {
        text = L("layout.action.plugin_settings"),
        width = 126,
        tone = "default",
        onClick = function() if Layout.selectedId then Layout:OpenPluginSettings(Layout.selectedId) end end,
    })
    plugin:SetPoint("LEFT", resetSelected, "RIGHT", 10, 0)
    y = y - 42

    local divider = GUI2:CreateDivider(root, width, nil, L("settings.layout.frames"), true)
    divider:SetPoint("TOPLEFT", root, "TOPLEFT", 0, y)
    y = y - 28

    widgets.frameButtons = {}
    if #Layout.order == 0 then
        local empty = GUI2:CreateText(root, L("settings.layout.no_frames"), "font.size.md", "color.text.secondary")
        empty:SetPoint("TOPLEFT", root, "TOPLEFT", 0, y)
        y = y - 28
    else
        for _, id in ipairs(Layout.order) do
            local entry = Layout.frames[id]
            local button = GUI2.Form:CreateButton(root, {
                text = entry.spec.title or id,
                width = width,
                height = 26,
                tone = "default",
                onClick = function()
                    Layout:SelectFrame(id)
                end,
            })
            button:SetPoint("TOPLEFT", root, "TOPLEFT", 0, y)
            widgets.frameButtons[id] = button
            y = y - 32
        end
    end

    local optionsParent = GUI2:CreateFrame(root, { width = width, height = 1 })
    optionsParent:SetPoint("TOPLEFT", root, "TOPLEFT", 0, y - 4)
    widgets.optionsParent = optionsParent
    local entry = Layout.selectedId and Layout.frames[Layout.selectedId]
    local optionsHeight = RenderRegisteredOptions(optionsParent, entry)
    optionsParent:SetHeight(math_max(optionsHeight, 1))
    y = y - optionsHeight - 12

    root:SetHeight(math_abs(y) + 20)
    Layout:RefreshSettingsPanel()
end
P.RenderSettings = RenderSettings

function Layout:RefreshMovementWidgets()
    local widgets = self.moverPanelWidgets
    if not widgets then return end

    local entry = GetMoverPanelEntry()
    local placement = entry and self.moverPanelLiveId == entry.id and self.moverPanelLivePlacement or nil
    placement = placement or (entry and self:GetPlacement(entry.id) or nil)
    local placementState = entry and self:GetPlacementState(entry.id) or nil
    local placementBlocked = placementState == PLACEMENT_PENDING or placementState == PLACEMENT_FALLBACK
    local disabled = placement == nil
    local controls = {
        widgets.close,
        widgets.reset,
        widgets.anchorClose,
        widgets.anchorConfirm,
        widgets.anchorCancel,
        widgets.pointSummary,
        widgets.relativePointSummary,
    }
    local placementControls = {
        widgets.point,
        widgets.relativePoint,
        widgets.offsetX,
        widgets.offsetY,
    }
    local anchorControls = {
        widgets.anchorTarget,
        widgets.pickAnchor,
    }
    if widgets.nudges then
        for _, button in ipairs(widgets.nudges) do
            controls[#controls + 1] = button
        end
    end
    for _, widget in ipairs(controls) do
        if widget and widget.SetDisabled then
            widget:SetDisabled(disabled)
        end
    end
    for _, widget in ipairs(anchorControls) do
        if widget and widget.SetDisabled then
            widget:SetDisabled(disabled or placementBlocked)
        end
    end
    for _, widget in ipairs(placementControls) do
        if widget and widget.SetDisabled then
            widget:SetDisabled(disabled or placementBlocked)
        end
    end
    if widgets.nudges then
        for _, button in ipairs(widgets.nudges) do
            if button and button.SetDisabled then button:SetDisabled(disabled or placementBlocked) end
        end
    end
    ApplyMoverPanelLayer(self.moverPanel)
    ApplyAnchorPanelLayer(self.anchorPanel)
    RefreshAnchorPickerButton()
    if widgets.title then
        widgets.title:SetText(entry and (entry.spec.title or entry.id) or L("settings.layout.position"))
    end
    if widgets.anchorPanelTitle then
        widgets.anchorPanelTitle:SetText(L("layout.action.anchor_settings"))
    end
    if disabled then
        SetAnchorInputState(nil)
        return
    end

    local anchor = placement.anchor or {}
    local offset = placement.offset or {}
    if widgets.anchorTarget and widgets.anchorTarget.SetValue then
        widgets.anchorTarget:SetValue(anchor.relative or "UIParent", true)
    end
    if self.anchorPickerEntryId ~= entry.id then
        if placementState == PLACEMENT_PENDING then
            SetAnchorInputState(L("layout.position.anchor_pending") .. ": " .. DisplayAnchorTargetName(entry.pendingAnchor or ""), "color.state.warning")
        elseif placementState == PLACEMENT_FALLBACK then
            SetAnchorInputState(L("layout.position.anchor_fallback") .. ": " .. DisplayAnchorTargetName(entry.pendingAnchor or ""), "color.state.warning")
        elseif placementState == PLACEMENT_SIMULATED then
            SetAnchorInputState(L("layout.position.anchor_simulated") .. ": " .. DisplayAnchorTargetName(entry.pendingAnchor or ""), "color.state.warning")
        else
            SetAnchorInputState(nil)
        end
    end
    local pendingForEntry = self.pendingAnchorSourceId == entry.id
    local displayPoint = pendingForEntry and self.pendingAnchorPoint or anchor.point or "CENTER"
    local displayRelativePoint = pendingForEntry and self.pendingAnchorRelativePoint or anchor.relativePoint or anchor.point or "CENTER"
    local displayRelative = pendingForEntry and self.pendingAnchorTargetName or anchor.relative or "UIParent"
    if widgets.anchorSummary then
        widgets.anchorSummary:SetText((entry.spec.title or entry.id) .. " -> " .. DisplayAnchorTargetName(displayRelative))
    end
    if widgets.pointSummary and widgets.pointSummary.SetText then
        widgets.pointSummary:SetText(DisplayAnchorPoint(displayPoint))
    end
    if widgets.relativePointSummary and widgets.relativePointSummary.SetText then
        widgets.relativePointSummary:SetText(DisplayAnchorPoint(displayRelativePoint))
    end
    if widgets.point and widgets.point.SetValue then
        widgets.point:SetValue(displayPoint, true)
    end
    if widgets.relativePoint and widgets.relativePoint.SetValue then
        widgets.relativePoint:SetValue(displayRelativePoint, true)
    end
    if widgets.offsetX and widgets.offsetX.SetValue and not widgets.offsetX:HasFocus() then
        widgets.offsetX:SetValue(Round(offset.x or 0), true)
    end
    if widgets.offsetY and widgets.offsetY.SetValue and not widgets.offsetY:HasFocus() then
        widgets.offsetY:SetValue(Round(offset.y or 0), true)
    end
end

function Layout:RefreshSettingsPanel()
    local widgets = self.settingsWidgets
    if not widgets then return end
    local entry = self.selectedId and self.frames[self.selectedId]
    if widgets.selectedText then
        local title = entry and (entry.spec.title or entry.id) or L("layout.none_selected")
        widgets.selectedText:SetText(L("layout.panel.selected") .. ": " .. title)
    end
    if widgets.frameButtons then
        for id, button in pairs(widgets.frameButtons) do
            if button.SetState then
                button:SetState(id == self.selectedId and "selected" or "normal")
            end
        end
    end
    self:RefreshMovementWidgets()
end
