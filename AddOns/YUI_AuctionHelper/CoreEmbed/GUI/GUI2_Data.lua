do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local YUI = _G.YUI
YUI.GUI2 = YUI.GUI2 or {}

local GUI2 = YUI.GUI2
local CreateFrame = CreateFrame
local math_ceil = math.ceil
local math_floor = math.floor
local math_max = math.max
local math_min = math.min

GUI2.Data = GUI2.Data or {}

local DEFAULT_PROGRESS_TEXTURE = "Interface\\Buttons\\WHITE8x8"
local PROJECTED_DRIVER_STYLE = {
    texture = DEFAULT_PROGRESS_TEXTURE,
    textureU0 = 0,
    textureU1 = 1,
    textureV0 = 0,
    textureV1 = 1,
    fillColor = { 1, 1, 1, 0 },
}

local function ConfigureMotion(frame, opts, owner)
    if not frame then return end
    opts = opts or {}
    frame.gui2Animate = opts.animate ~= false and opts.motion ~= false
    frame.gui2MotionOwner = owner or frame
end

local function InheritMotion(child, owner)
    if not child or not owner then return end
    child.gui2Animate = owner.gui2Animate
    child.gui2MotionOwner = owner
end

local function ParseSetOptions(setOptions)
    local silent = setOptions == true
    local animate = not silent
    local options = nil

    if type(setOptions) == "table" then
        options = setOptions
        silent = setOptions.silent == true
        if setOptions.animate ~= nil then
            animate = setOptions.animate == true
        else
            animate = not silent
        end
        if setOptions.motion == false then
            animate = false
        end
    end

    return silent, animate, options
end

local function NormalizeFillColor(r, g, b, a)
    if type(r) == "table" or type(r) == "string" then
        return r
    end
    if type(r) == "number" then
        return { r, g or 1, b or 1, a == nil and 1 or a }
    end
    return nil
end

local function CopyResolvedFillColor(source, target)
    local r, g, b, a
    if type(source) == "string" then
        r, g, b, a = GUI2:GetColor(source)
    elseif type(source) == "table" then
        r = source[1] or source.r
        g = source[2] or source.g
        b = source[3] or source.b
        a = source[4]
        if a == nil then a = source.a end
    end
    target[1] = r == nil and 1 or r
    target[2] = g == nil and 1 or g
    target[3] = b == nil and 1 or b
    target[4] = a == nil and 1 or a
    return target
end

local function IsProgressReverse(frame)
    if not frame then return false end
    if frame.orientation == "vertical" then
        return frame.fillDirection == "down"
            or frame.fillDirection == "reverse"
    end
    return frame.fillDirection == "right"
        or frame.fillDirection == "reverse"
end

local function GetProjectedDriverDirection(frame)
    local reverse = IsProgressReverse(frame)
    if frame.orientation == "vertical" then
        -- Retail SetTimerDuration moves the vertical fill Texture opposite to
        -- the documented SetValue projection. Game A/B fixes the driver by
        -- swapping only the native vertical fill style; the visible material
        -- keeps the authored logical direction below.
        return reverse and "forward" or "reverse"
    end
    return reverse and "reverse" or "forward"
end

local function LayoutProjectedProgressFill(frame)
    local clip = frame and frame.nativeFillClip
    local track = frame and frame.track
    local driver = frame and frame.nativeStatusBar
    local driverTexture = driver and driver.GetStatusBarTexture
        and driver:GetStatusBarTexture() or nil
    if not (clip and track and driverTexture) then return false end

    clip:ClearAllPoints()
    if frame.orientation == "vertical" then
        if IsProgressReverse(frame) then
            clip:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
            clip:SetPoint("TOPRIGHT", track, "TOPRIGHT", 0, 0)
            clip:SetPoint("BOTTOM", driverTexture, "BOTTOM", 0, 0)
        else
            clip:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 0, 0)
            clip:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", 0, 0)
            clip:SetPoint("TOP", driverTexture, "TOP", 0, 0)
        end
    elseif IsProgressReverse(frame) then
        clip:SetPoint("TOPRIGHT", track, "TOPRIGHT", 0, 0)
        clip:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", 0, 0)
        clip:SetPoint("LEFT", driverTexture, "LEFT", 0, 0)
    else
        clip:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
        clip:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 0, 0)
        clip:SetPoint("RIGHT", driverTexture, "RIGHT", 0, 0)
    end
    return true
end

local SetNativeProgressFillShown

local function ApplyProjectedDriverStyle(frame, force)
    local driver = frame and frame.nativeStatusBar
    if not (driver and frame.nativeVisibleStatusBar
        and GUI2.ApplyNativeStatusBarStyle) then
        return false
    end
    GUI2:ApplyNativeStatusBarStyle(
        driver,
        PROJECTED_DRIVER_STYLE,
        frame.orientation,
        GetProjectedDriverDirection(frame),
        force == true
    )
    local driverTexture = driver.GetStatusBarTexture
        and driver:GetStatusBarTexture() or nil
    if driverTexture and driverTexture.SetAlpha then
        driverTexture:SetAlpha(0)
        frame.gui2ProjectedDriverTexture = driverTexture
    end
    LayoutProjectedProgressFill(frame)
    return true
end

local function ApplyProjectedVisibleTextureLayer(frame)
    local visible = frame and frame.nativeVisibleStatusBar
    local texture = visible and visible.GetStatusBarTexture
        and visible:GetStatusBarTexture() or nil
    if not (texture and texture.SetDrawLayer) then return false end
    local layer = frame.gui2ProjectedFillDrawLayer or "ARTWORK"
    local subLevel = tonumber(frame.gui2ProjectedFillSubLevel) or 0
    if frame.gui2ProjectedVisibleTexture == texture
        and frame.gui2ProjectedAppliedDrawLayer == layer
        and frame.gui2ProjectedAppliedDrawSubLevel == subLevel then
        return false
    end
    texture:SetDrawLayer(layer, subLevel)
    frame.gui2ProjectedVisibleTexture = texture
    frame.gui2ProjectedAppliedDrawLayer = layer
    frame.gui2ProjectedAppliedDrawSubLevel = subLevel
    return true
end

function GUI2:EnsureProjectedStatusBarFill(frame, track, driver, opts)
    if not (frame and track and driver) then return nil end
    opts = opts or {}
    frame.track = track
    frame.nativeStatusBar = driver
    frame.orientation = opts.orientation
        or frame.orientation or "horizontal"
    frame.fillDirection = opts.fillDirection
        or frame.fillDirection
        or (frame.orientation == "vertical" and "up" or "left")
    frame.gui2ProjectedFillDrawLayer = opts.fillLayer
        or frame.gui2ProjectedFillDrawLayer or "ARTWORK"
    frame.gui2ProjectedFillSubLevel = tonumber(opts.fillSubLevel)
        or frame.gui2ProjectedFillSubLevel or 0

    local parent = opts.parent or track or driver
    local fillClip = frame.nativeFillClip
    if not fillClip then
        fillClip = CreateFrame("Frame", nil, parent)
        if not fillClip.SetClipsChildren then
            error("GUI2 projected native fill requires SetClipsChildren")
        end
        fillClip:SetClipsChildren(true)
        frame.nativeFillClip = fillClip
    end

    local visibleStatusBar = frame.nativeVisibleStatusBar
    if not visibleStatusBar then
        visibleStatusBar = CreateFrame("StatusBar", nil, fillClip)
        visibleStatusBar:SetMinMaxValues(0, 1)
        visibleStatusBar:SetValue(1)
        frame.nativeVisibleStatusBar = visibleStatusBar
    end
    visibleStatusBar:ClearAllPoints()
    visibleStatusBar:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
    visibleStatusBar:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", 0, 0)

    local baseLevel = tonumber(opts.frameLevel)
    if baseLevel == nil and parent.GetFrameLevel then
        baseLevel = parent:GetFrameLevel() or 0
    end
    baseLevel = baseLevel or 0
    local clipOffset = opts.clipFrameLevelOffset
    local visibleOffset = opts.visibleFrameLevelOffset
    if opts.preserveParentLayers == true then
        clipOffset = 0
        visibleOffset = 0
    end
    if fillClip.SetFrameLevel then
        fillClip:SetFrameLevel(baseLevel + (tonumber(clipOffset) or 2))
    end
    if visibleStatusBar.SetFrameLevel then
        visibleStatusBar:SetFrameLevel(
            baseLevel + (tonumber(visibleOffset) or 3)
        )
    end

    driver.gui2ProjectedVisibleStatusBar = visibleStatusBar
    driver.gui2ProjectedOwner = frame
    frame.statusBar = visibleStatusBar
    frame.gui2ProjectedFill = true
    ApplyProjectedDriverStyle(frame, true)
    return frame
end

function GUI2:LayoutProjectedStatusBarFill(frame)
    return LayoutProjectedProgressFill(frame)
end

function GUI2:RefreshProjectedStatusBarDriver(frame, force)
    return ApplyProjectedDriverStyle(frame, force)
end

function GUI2:RefreshProjectedStatusBarLayer(frame)
    return ApplyProjectedVisibleTextureLayer(frame)
end

function GUI2:SetProjectedStatusBarDirection(
    frame,
    orientation,
    fillDirection,
    force
)
    if not frame then return false end
    frame.orientation = orientation == "vertical"
        and "vertical" or "horizontal"
    frame.fillDirection = fillDirection
        or (frame.orientation == "vertical" and "up" or "left")
    return ApplyProjectedDriverStyle(frame, force)
end

function GUI2:SetProjectedStatusBarShown(frame, shown)
    SetNativeProgressFillShown(frame, shown)
end

function GUI2:ReleaseProjectedStatusBarFill(frame)
    if not frame then return end
    if frame.nativeFillClip then frame.nativeFillClip:Hide() end
    if frame.nativeVisibleStatusBar then
        frame.nativeVisibleStatusBar:Hide()
    end
    local driver = frame.nativeStatusBar
    local driverTexture = driver and driver.GetStatusBarTexture
        and driver:GetStatusBarTexture() or frame.gui2ProjectedDriverTexture
    if driverTexture and driverTexture.SetAlpha then
        driverTexture:SetAlpha(1)
    end
    if driver and driver.gui2ProjectedOwner == frame then
        driver.gui2ProjectedOwner = nil
        driver.gui2ProjectedVisibleStatusBar = nil
    end
end

SetNativeProgressFillShown = function(frame, shown)
    shown = shown == true
    if frame and frame.nativeStatusBar then
        frame.nativeStatusBar:SetShown(
            frame.nativeVisibleStatusBar and true or shown
        )
    end
    if frame and frame.nativeFillClip then
        frame.nativeFillClip:SetShown(shown)
    end
    if frame and frame.nativeVisibleStatusBar then
        frame.nativeVisibleStatusBar:SetShown(shown)
    end
end

local function ApplyProgressFillStyle(frame)
    if frame and frame.nativeStatusBar
        and GUI2.ApplyNativeStatusBarStyle then
        local style = frame.gui2NativeFillStyle or {}
        local fillColor = frame.gui2NativeFillColor
        if type(fillColor) ~= "table" then
            fillColor = {}
            frame.gui2NativeFillColor = fillColor
        end
        frame.gui2NativeFillStyle = style
        style.texture = type(frame.gui2FillTexture) == "string"
            and frame.gui2FillTexture ~= ""
            and frame.gui2FillTexture or DEFAULT_PROGRESS_TEXTURE
        style.fillColor = CopyResolvedFillColor(
            frame.gui2FillColor,
            fillColor
        )
        local appearanceBar = frame.nativeVisibleStatusBar
            or frame.nativeStatusBar
        GUI2:ApplyNativeStatusBarStyle(
            appearanceBar,
            style,
            frame.orientation,
            frame.fillDirection
        )
        if frame.nativeVisibleStatusBar then
            ApplyProjectedVisibleTextureLayer(frame)
        end
        if frame.nativeVisibleStatusBar then
            frame.nativeVisibleStatusBar:SetMinMaxValues(0, 1)
            frame.nativeVisibleStatusBar:SetValue(1)
            ApplyProjectedDriverStyle(frame)
        end
        return
    end
    local fill = frame and frame.fill
    if not fill then return end

    local texture = frame.gui2FillTexture
    local color = frame.gui2FillColor
    if type(texture) == "string" and texture ~= "" then
        fill.gui2PaintKey = nil
        fill:SetTexture(texture)
        if type(color) == "string" then
            fill:SetVertexColor(GUI2:GetColor(color))
        elseif type(color) == "table" then
            fill:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] == nil and 1 or color[4])
        else
            fill:SetVertexColor(1, 1, 1, 1)
        end
        return
    end

    if fill.SetVertexColor then
        fill:SetVertexColor(1, 1, 1, 1)
    end
    if type(color) == "table" then
        fill.gui2PaintKey = nil
        fill:SetColorTexture(color[1] or 1, color[2] or 1, color[3] or 1, color[4] == nil and 1 or color[4])
    else
        local colorKey = type(color) == "string" and color or "color.accent.primary"
        fill.gui2PaintKey = colorKey
        fill:SetColorTexture(GUI2:GetColor(colorKey))
    end
end

function GUI2.Data:CreateIconSlot(parent, opts)
    return GUI2:CreateIconSlot(parent, opts)
end

local function GetBadgeTextWidth(label)
    if not label then return 0 end
    if label.GetUnboundedStringWidth then
        local width = label:GetUnboundedStringWidth()
        if type(width) == "number" then
            return width
        end
    end
    if label.GetStringWidth then
        local width = label:GetStringWidth()
        if type(width) == "number" then
            return width
        end
    end
    return 0
end

local function LayoutBadge(frame)
    if not frame then return end

    local width = frame.gui2BadgeWidth or 82
    if frame.gui2BadgeAutoWidth then
        width = math_ceil(GetBadgeTextWidth(frame.text) + ((frame.gui2BadgePaddingX or 0) * 2))
    end
    width = math_max(frame.gui2BadgeMinWidth or 0, width)
    frame:SetSize(width, frame.gui2BadgeHeight or 22)
end

local SOLID_BADGE_SURFACES = {
    orange = "color.badge.orange",
    green = "color.badge.green",
    purple = "color.badge.purple",
}

-- table options support flat/solid reusable borderless filled badges.
-- Legacy (parent, text, tone) calls keep the original bordered appearance.
function GUI2.Data:CreateBadge(parent, text, tone)
    local opts
    local legacy = type(text) ~= "table"
    if legacy then
        opts = {
            text = text,
            tone = tone,
            width = 82,
            height = 22,
            autoWidth = false,
        }
    else
        opts = text
        tone = opts.tone
    end

    local solid = opts.variant == "solid"
    local flat = opts.variant == "flat"
    local customFill = solid or flat
    local solidToneSurface = customFill and SOLID_BADGE_SURFACES[tone]
    local surface = opts.surface
        or solidToneSurface
        or (customFill and "color.accent.fill")
        or (tone == "accent" and "color.accent.soft")
        or "color.surface.sunken"
    local textColor = opts.textColor
        or (solidToneSurface and "color.badge.text")
        or (customFill and "color.accent.text")
        or (tone == "accent" and "color.text.accent")
        or "color.text.primary"
    local border = opts.border
    if border == nil then
        if customFill then
            border = false
        elseif tone == "accent" then
            border = "color.border.accent"
        else
            border = "color.border.default"
        end
    end
    local height = math_max(1, tonumber(opts.height) or 22)
    local autoWidth = opts.autoWidth
    if autoWidth == nil then
        autoWidth = not legacy
    end
    local paddingX = math_max(0, tonumber(opts.paddingX) or 8)
    local configuredWidth = math_max(1, tonumber(opts.width) or (legacy and 82 or height))
    local minWidth = math_max(0, tonumber(opts.minWidth) or configuredWidth)
    local radiusKey = opts.radiusKey
    if radiusKey == nil and not legacy then
        radiusKey = "layout.radius.badge"
    end

    local frame
    if customFill then
        frame = GUI2:CreateSolidRoundedSurface(parent, {
            width = configuredWidth,
            height = height,
            surface = surface,
            radiusKey = radiusKey,
            radiusPixels = tonumber(opts.radiusPixels) or 4,
        })
        if border ~= false then
            GUI2:CreateBorder(frame, border)
        end
    else
        frame = GUI2:CreatePanel(parent, {
            width = configuredWidth,
            height = height,
            surface = surface,
            border = border,
            radiusKey = radiusKey,
        })
    end
    local label = GUI2:CreateText(
        frame,
        opts.text or "Badge",
        opts.fontSizeKey or opts.sizeKey or (customFill and "font.size.md" or "font.size.sm"),
        textColor
    )
    label:SetPoint("CENTER")
    if customFill then
        if label.SetShadowColor then label:SetShadowColor(0, 0, 0, 0) end
        if label.SetShadowOffset then label:SetShadowOffset(0, 0) end
    end

    frame.text = label
    frame.gui2BadgeHeight = height
    frame.gui2BadgeWidth = configuredWidth
    frame.gui2BadgeMinWidth = minWidth
    frame.gui2BadgePaddingX = paddingX
    frame.gui2BadgeAutoWidth = autoWidth == true
    frame.gui2BadgeSurface = surface
    frame.gui2BadgeBorder = border
    frame.gui2BadgeTextColor = textColor
    frame.gui2BadgeSolid = solid
    frame.gui2BadgeFlat = flat

    frame.SetText = function(self, value)
        self.text:SetText(value == nil and "" or tostring(value))
        LayoutBadge(self)
    end

    local baseRefreshTheme = frame.RefreshTheme
    frame.RefreshTheme = function(self)
        if baseRefreshTheme then
            baseRefreshTheme(self)
        elseif GUI2.RefreshPrimitive then
            GUI2:RefreshPrimitive(self)
        end
        if self.gui2BadgeBorder ~= false and self.gui2Borders then
            GUI2:SetBorderColor(self, self.gui2BadgeBorder)
        end
        GUI2:SetTextColorKey(self.text, self.gui2BadgeTextColor)
        if self.gui2BadgeAutoWidth then
            LayoutBadge(self)
        end
    end

    LayoutBadge(frame)
    return frame
end

function GUI2.Data:CreateTag(parent, text, tone)
    local frame = self:CreateBadge(parent, text or "Tag", tone)
    frame.gui2BadgeWidth = 66
    frame.gui2BadgeHeight = 20
    frame.gui2BadgeMinWidth = 66
    frame:SetSize(66, 20)
    return frame
end

function GUI2.Data:CreateInfoRow(parent, label, value)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(260, 26)
    local left = GUI2:CreateText(frame, label or "Label", "font.size.md", "color.text.secondary")
    left:SetPoint("LEFT", 0, 0)
    local right = GUI2:CreateText(frame, value or "Value", "font.size.md", "color.text.primary", "RIGHT")
    right:SetPoint("RIGHT", 0, 0)
    frame.label = left
    frame.value = right
    return frame
end

function GUI2.Data:CreateStatBlock(parent, opts)
    opts = opts or {}
    local frame = GUI2:CreatePanel(parent, {
        width = opts.width or 136,
        height = opts.height or 76,
        surface = "color.surface.panel",
        border = "color.border.default",
    })
    local label = GUI2:CreateText(frame, opts.label or "Latency", "font.size.sm", "color.text.secondary")
    label:SetPoint("TOPLEFT", 10, -10)
    local value = GUI2:CreateText(frame, opts.value or "24 ms", "font.size.title", opts.tone or "color.text.accent")
    value:SetPoint("BOTTOMLEFT", 10, 10)
    frame.label = label
    frame.value = value
    return frame
end

function GUI2.Data:CreateEmptyState(parent, opts)
    opts = opts or {}
    local frame = GUI2:CreatePanel(parent, {
        width = opts.width or 250,
        height = opts.height or 104,
        surface = "color.surface.sunken",
        border = "color.border.subtle",
    })
    local title = GUI2:CreateText(frame, opts.title or "No results", "font.size.lg", "color.text.heading")
    title:SetPoint("TOP", 0, -22)
    local body = GUI2:CreateText(frame, opts.body or "Change filters or try another preset.", "font.size.sm", "color.text.secondary")
    body:SetPoint("TOP", title, "BOTTOM", 0, -8)
    body:SetWidth((opts.width or 250) - 28)
    body:SetJustifyH("CENTER")
    frame.title = title
    frame.body = body
    return frame
end

function GUI2.Data:CreateList(parent, opts)
    opts = opts or {}
    local frame = GUI2:CreatePanel(parent, {
        width = opts.width or 260,
        height = opts.height or 120,
        surface = "color.surface.panel",
        border = "color.border.default",
    })
    local items = opts.items or { "Item one", "Item two", "Item three" }
    for i, item in ipairs(items) do
        local row = GUI2:CreatePanel(frame, {
            width = (opts.width or 260) - 16,
            height = 26,
            surface = i == 2 and "color.control.active" or "color.surface.raised",
            border = i == 2 and "color.border.accent" or "color.border.subtle",
        })
        row:SetPoint("TOPLEFT", 8, -8 - ((i - 1) * 32))
        local text = GUI2:CreateText(row, item, "font.size.sm", i == 2 and "color.text.accent" or "color.text.primary")
        text:SetPoint("LEFT", 8, 0)
    end
    return frame
end

function GUI2.Data:CreateTable(parent, opts)
    opts = opts or {}
    local width = opts.width or 360
    local rowHeight = opts.rowHeight or 24
    local headerY = opts.headerY or -10
    local dividerY = opts.dividerY or -32
    local rowStartY = opts.rowStartY or -44
    local columns = opts.columns or { "Name", "State", "Value" }
    local columnStep = math_floor((width - 20) / math_max(#columns, 1))
    local frame = GUI2:CreatePanel(parent, {
        width = width,
        height = opts.height or 132,
        surface = "color.surface.panel",
        border = "color.border.default",
    })
    local rows = opts.rows or {
        { "Clock", "Ready", "24" },
        { "YBar", "Active", "12" },
        { "GUI2", "Lab", "5B" },
    }
    for i, col in ipairs(columns) do
        local text = GUI2:CreateText(frame, col, "font.size.sm", "color.text.secondary")
        text:SetPoint("TOPLEFT", 10 + ((i - 1) * columnStep), headerY)
    end
    local divider = GUI2:CreateTexture(frame, "color.border.default", "OVERLAY")
    divider:SetPoint("TOPLEFT", 10, dividerY)
    divider:SetPoint("TOPRIGHT", -10, dividerY)
    divider:SetHeight(1)
    for r, row in ipairs(rows) do
        for c, cell in ipairs(row) do
            local text = GUI2:CreateText(frame, cell, "font.size.sm", c == 2 and "color.text.accent" or "color.text.primary")
            text:SetPoint("TOPLEFT", 10 + ((c - 1) * columnStep), rowStartY - ((r - 1) * rowHeight))
        end
    end
    return frame
end

local function ApplyProgressFill(frame)
    if not frame then return end
    local value = frame.value or 0
    if value < 0 then value = 0 end
    if value > 1 then value = 1 end

    local track = frame.track or frame
    local clip = frame.fillClip
    if frame.nativeStatusBar then
        frame.nativeStatusBar:SetMinMaxValues(0, 1)
        frame.nativeStatusBar:SetValue(value)
        SetNativeProgressFillShown(frame, value > 0)
        if frame.nativeVisibleStatusBar then
            frame.nativeVisibleStatusBar:SetMinMaxValues(0, 1)
            frame.nativeVisibleStatusBar:SetValue(1)
        end
    elseif frame.fill then
        local target = clip or frame.fill
        target:ClearAllPoints()
        if clip then
            frame.fill:ClearAllPoints()
            frame.fill:SetAllPoints(track)
        end
        if frame.orientation == "vertical" then
            local height = math_floor(frame.barHeight * value)
            target:SetWidth(frame.barWidth)
            target:SetHeight(math_max(height, 1))
            if frame.fillDirection == "down" then
                target:SetPoint("TOP", track, "TOP", 0, 0)
            else
                target:SetPoint("BOTTOM", track, "BOTTOM", 0, 0)
            end
        else
            local width = math_floor(frame.barWidth * value)
            target:SetWidth(math_max(width, 1))
            target:SetHeight(frame.barHeight)
            if frame.fillDirection == "right" then
                target:SetPoint("RIGHT", track, "RIGHT", 0, 0)
            else
                target:SetPoint("LEFT", track, "LEFT", 0, 0)
            end
        end
        target:SetShown(value > 0)
    end

    if frame.icon then
        if frame.iconPosition == "follow" then
            frame.icon:ClearAllPoints()
            frame.icon:SetSize(frame.iconSize, frame.iconSize)
            if frame.orientation == "vertical" then
                local half = math_floor(frame.iconSize / 2)
                local y = math_min(math_max(math_floor(frame.barHeight * value), half), frame.barHeight - half)
                frame.icon:SetPoint("CENTER", track, "BOTTOM", 0, y)
            else
                local half = math_floor(frame.iconSize / 2)
                local x = math_min(math_max(math_floor(frame.barWidth * value), half), frame.barWidth - half)
                frame.icon:SetPoint("CENTER", track, "LEFT", x, 0)
            end
        elseif frame.iconPosition == "center" then
            frame.icon:ClearAllPoints()
            frame.icon:SetPoint("CENTER", track, "CENTER", 0, 0)
        elseif frame.iconPosition == "follow-vertical" then
            frame.icon:ClearAllPoints()
            local y = math_floor(frame.barHeight * value)
            frame.icon:SetPoint("CENTER", track, "BOTTOM", 0, y)
        elseif frame.iconPosition == "follow-horizontal" then
            frame.icon:ClearAllPoints()
            local x = math_floor(frame.barWidth * value)
            frame.icon:SetPoint("CENTER", track, "LEFT", x, 0)
        end
    end
end

local function SetBorderTextureVisible(texture, visible)
    if not texture then return end
    if visible then
        texture:Show()
    else
        texture:Hide()
    end
end

local function RefreshProgressBorderOverlay(frame)
    if not frame or frame.gui2UseStatusBarBorder == true then return end
    local edges = frame.nativeBorderEdges
    local track = frame.track
    local source = track and track.gui2Borders
    if not (edges and track) then return end

    local desiredPixels = source and source.widthPixels
        or (source and GUI2:GetMetric(source.widthKey, 1)) or 1
    if GUI2.LayoutPixelBorder then
        GUI2:LayoutPixelBorder(edges, track, desiredPixels, 0, 0)
    else
        local size = GUI2.GetPixelSize
            and GUI2:GetPixelSize(track, desiredPixels, desiredPixels)
            or desiredPixels
        edges.top:SetHeight(size)
        edges.bottom:SetHeight(size)
        edges.left:SetWidth(size)
        edges.right:SetWidth(size)
    end

    if source then
        local r, g, b, a
        if source.colorR ~= nil then
            r, g, b, a = source.colorR, source.colorG,
                source.colorB, source.colorA
        else
            r, g, b, a = GUI2:GetColor(
                source.colorKey or "color.border.default"
            )
        end
        for _, edge in pairs(edges) do
            if edge.SetColorTexture then
                edge:SetColorTexture(r, g, b, a)
            elseif edge.SetVertexColor then
                edge:SetVertexColor(r, g, b, a)
            end
        end
    end
end

local function ApplyProgressBorderCollapse(frame)
    local trackBorders = frame and frame.track and frame.track.gui2Borders
    local borders = frame and frame.nativeBorderEdges or trackBorders
    if not borders then return end

    if frame.nativeBorderEdges and trackBorders then
        SetBorderTextureVisible(trackBorders.left, false)
        SetBorderTextureVisible(trackBorders.right, false)
        SetBorderTextureVisible(trackBorders.top, false)
        SetBorderTextureVisible(trackBorders.bottom, false)
    end

    if frame.gui2UseStatusBarBorder == true then
        return
    end

    SetBorderTextureVisible(borders.left, true)
    SetBorderTextureVisible(borders.right, true)
    SetBorderTextureVisible(borders.top, true)
    SetBorderTextureVisible(borders.bottom, true)

    if not (frame.collapseAdjacentBorder and frame.icon and (frame.iconGap or 0) <= 0) then
        return
    end

    if frame.iconPosition == "left" then
        SetBorderTextureVisible(borders.left, false)
    elseif frame.iconPosition == "right" then
        SetBorderTextureVisible(borders.right, false)
    elseif frame.iconPosition == "top" then
        SetBorderTextureVisible(borders.top, false)
    elseif frame.iconPosition == "bottom" or frame.iconPosition == "down" then
        SetBorderTextureVisible(borders.bottom, false)
    end
end

local function ResolveProgressGeometry(
    orientation,
    outerWidth,
    outerHeight,
    iconPosition,
    iconGap,
    iconSize,
    autoIconSize
)
    outerWidth = math_max(1, tonumber(outerWidth) or 1)
    outerHeight = math_max(1, tonumber(outerHeight) or 1)
    iconGap = math_max(0, tonumber(iconGap) or 0)

    if autoIconSize then
        if orientation == "vertical" then
            if iconPosition == "left" or iconPosition == "right" then
                iconSize = (outerWidth - iconGap) / 2
            else
                iconSize = outerWidth
            end
        elseif iconPosition == "top"
            or iconPosition == "bottom"
            or iconPosition == "down" then
            iconSize = (outerHeight - iconGap) / 2
        else
            iconSize = outerHeight
        end
    end
    iconSize = math_max(1, tonumber(iconSize) or 1)

    if iconPosition == "left" or iconPosition == "right" then
        iconSize = math_min(
            iconSize,
            outerHeight,
            math_max(1, outerWidth - iconGap - 1)
        )
    elseif iconPosition == "top"
        or iconPosition == "bottom"
        or iconPosition == "down" then
        iconSize = math_min(
            iconSize,
            outerWidth,
            math_max(1, outerHeight - iconGap - 1)
        )
    end

    local extraWidth = (iconPosition == "left"
        or iconPosition == "right") and (iconSize + iconGap) or 0
    local extraHeight = (iconPosition == "top"
        or iconPosition == "bottom"
        or iconPosition == "down") and (iconSize + iconGap) or 0
    return math_max(1, outerWidth - extraWidth),
        math_max(1, outerHeight - extraHeight),
        iconSize
end

local function LayoutProgressBar(frame)
    if not (frame and frame.track) then return end

    local iconPosition = frame.iconPosition
    local iconSize = frame.iconSize or 1
    local iconGap = frame.iconGap or 0
    local outerWidth = frame.outerWidth or 1
    local outerHeight = frame.outerHeight or 1
    local barWidth, barHeight
    barWidth, barHeight, iconSize = ResolveProgressGeometry(
        frame.orientation,
        outerWidth,
        outerHeight,
        iconPosition,
        iconGap,
        iconSize,
        frame.gui2IconAutoSize == true
    )
    frame.barWidth = barWidth
    frame.barHeight = barHeight
    frame.iconSize = iconSize

    if not GUI2:SetPixelSnappedSize(
        frame,
        outerWidth,
        outerHeight,
        1,
        1
    ) then
        frame:SetSize(outerWidth, outerHeight)
    end
    frame.track:ClearAllPoints()
    if not GUI2:SetPixelSnappedSize(
        frame.track,
        barWidth,
        barHeight,
        1,
        1
    ) then
        frame.track:SetSize(barWidth, barHeight)
    end

    if iconPosition == "left" then
        frame.track:SetPoint("LEFT", frame, "LEFT", iconSize + iconGap, 0)
    elseif iconPosition == "right" then
        frame.track:SetPoint("LEFT", frame, "LEFT", 0, 0)
    elseif iconPosition == "top" then
        frame.track:SetPoint("TOP", frame, "TOP", 0, -(iconSize + iconGap))
    elseif iconPosition == "bottom" or iconPosition == "down" then
        frame.track:SetPoint("TOP", frame, "TOP", 0, 0)
    else
        frame.track:SetPoint("CENTER", frame, "CENTER", 0, 0)
    end

    if frame.icon then
        frame.icon:ClearAllPoints()
        if not GUI2:SetPixelSnappedSize(
            frame.icon,
            iconSize,
            iconSize,
            1,
            1
        ) then
            frame.icon:SetSize(iconSize, iconSize)
        end
        if iconPosition == "left" then
            frame.icon:SetPoint("RIGHT", frame.track, "LEFT", -iconGap, 0)
        elseif iconPosition == "right" then
            frame.icon:SetPoint("LEFT", frame.track, "RIGHT", iconGap, 0)
        elseif iconPosition == "top" then
            frame.icon:SetPoint("BOTTOM", frame.track, "TOP", 0, iconGap)
        elseif iconPosition == "bottom" or iconPosition == "down" then
            frame.icon:SetPoint("TOP", frame.track, "BOTTOM", 0, -iconGap)
        elseif iconPosition == "center" then
            frame.icon:SetPoint("CENTER", frame.track, "CENTER", 0, 0)
        end
    end

    if frame.gui2ProjectedFill == true then
        -- Projected fills may be driven by secret native values that are not
        -- mirrored in frame.value. Resizing must only recompute the clip;
        -- replaying the public value path would overwrite that driver with 0.
        ApplyProjectedDriverStyle(frame)
    else
        ApplyProgressFill(frame)
    end
    ApplyProgressBorderCollapse(frame)
end

function GUI2.Data:CreateProgressBar(parent, opts)
    opts = opts or {}
    local vertical = opts.orientation == "vertical"
    local outerWidth = math_max(
        1,
        tonumber(opts.width) or (vertical and 34 or 260)
    )
    local outerHeight = math_max(
        1,
        tonumber(opts.height) or (vertical and 136 or 24)
    )
    local iconPosition = opts.iconPosition
    local followIconSize = opts.followIconSize or opts.iconSize or GUI2:GetMetric("layout.size.icon", 22)
    local iconGap = opts.iconGap or 0
    local autoIconSize = opts.iconSize == nil and iconPosition ~= "follow"
    local iconSize = iconPosition == "follow"
        and followIconSize or opts.iconSize
    local barWidth, barHeight
    barWidth, barHeight, iconSize = ResolveProgressGeometry(
        vertical and "vertical" or "horizontal",
        outerWidth,
        outerHeight,
        iconPosition,
        iconGap,
        iconSize,
        autoIconSize
    )
    local frame = GUI2:CreateFrame(parent, {
        width = outerWidth,
        height = outerHeight,
    })
    ConfigureMotion(frame, opts)
    local track = GUI2:CreatePanel(frame, {
        width = barWidth,
        height = barHeight,
        surface = "color.control.track",
        border = "color.border.default",
    })
    frame.track = track
    local baseTrackRefreshTheme = track.RefreshTheme
    track.RefreshTheme = function(trackFrame)
        if baseTrackRefreshTheme then
            baseTrackRefreshTheme(trackFrame)
        elseif GUI2.RefreshPrimitive then
            GUI2:RefreshPrimitive(trackFrame)
        end
        RefreshProgressBorderOverlay(frame)
        ApplyProgressBorderCollapse(frame)
    end
    InheritMotion(track, frame)
    frame.orientation = vertical and "vertical" or "horizontal"
    frame.fillDirection = opts.fillDirection or (vertical and "up" or "left")
    frame.iconPosition = iconPosition
    frame.iconGap = iconGap
    frame.outerWidth = outerWidth
    frame.outerHeight = outerHeight
    frame.barWidth = barWidth
    frame.barHeight = barHeight
    frame.iconSize = iconSize
    frame.gui2IconAutoSize = autoIconSize
    frame.collapseAdjacentBorder = opts.collapseAdjacentBorder == true
    frame.gui2FillTexture = opts.fillTexture
    frame.gui2FillColor = opts.fillColor or opts.fillKey or "color.accent.primary"

    if opts.nativeFill ~= false then
        local statusBar = CreateFrame("StatusBar", nil, track)
        statusBar:SetAllPoints(track)
        statusBar:SetMinMaxValues(0, 1)
        statusBar:SetValue(opts.value or 0)
        if statusBar.SetFrameLevel and track.GetFrameLevel then
            statusBar:SetFrameLevel((track:GetFrameLevel() or 0) + 1)
        end
        frame.nativeStatusBar = statusBar
        frame.statusBar = statusBar
        if opts.projectedFill == true then
            GUI2:EnsureProjectedStatusBarFill(
                frame,
                track,
                statusBar,
                {
                    parent = track,
                    orientation = frame.orientation,
                    fillDirection = frame.fillDirection,
                }
            )
        end
        if opts.nativeBorder ~= false and GUI2.EnsureStatusBarBorder then
            local borderOverlay = CreateFrame("Frame", nil, track)
            borderOverlay:SetAllPoints(track)
            if borderOverlay.SetFrameLevel and track.GetFrameLevel then
                borderOverlay:SetFrameLevel(
                    (track:GetFrameLevel() or 0)
                        + (frame.nativeVisibleStatusBar and 4 or 2)
                )
            end
            frame.nativeBorderOverlay = borderOverlay
            frame.nativeBorderEdges = GUI2:EnsureStatusBarBorder(borderOverlay)
            RefreshProgressBorderOverlay(frame)
        end
        ApplyProgressFillStyle(frame)
    else
        local fillParent = track
        local fillClip
        local candidateClip = CreateFrame("Frame", nil, track)
        if candidateClip.SetClipsChildren then
            candidateClip:SetClipsChildren(true)
            fillClip = candidateClip
            fillParent = fillClip
        else
            candidateClip:Hide()
        end
        local fill = GUI2:CreateTexture(fillParent, {
            texture = opts.fillTexture or DEFAULT_PROGRESS_TEXTURE,
            layer = "ARTWORK",
        })
        frame.fill = fill
        frame.fillClip = fillClip
        ApplyProgressFillStyle(frame)
        InheritMotion(fill, frame)
    end

    if iconPosition then
        local iconParent = iconPosition == "follow" and track or frame
        frame.icon = GUI2:CreateIconSlot(iconParent, {
            size = iconSize,
            rounded = opts.roundedIcon,
            icon = opts.icon,
            padding = opts.iconPadding or 0,
            variant = opts.iconVariant,
            countSink = opts.countSink,
            animate = opts.animate,
            motion = opts.motion,
        })
        InheritMotion(frame.icon, frame)
        if frame.icon.SetFrameLevel and track.GetFrameLevel then
            frame.icon:SetFrameLevel(track:GetFrameLevel() + 3)
        end
    end

    frame.SetFillTexture = function(self, texture)
        self.gui2FillTexture = type(texture) == "string" and texture ~= "" and texture or nil
        ApplyProgressFillStyle(self)
    end
    frame.SetFillColor = function(self, r, g, b, a)
        self.gui2FillColor = NormalizeFillColor(r, g, b, a) or "color.accent.primary"
        ApplyProgressFillStyle(self)
    end
    frame.SetFillDirection = function(self, direction)
        self.fillDirection = direction or (self.orientation == "vertical" and "up" or "left")
        ApplyProgressFillStyle(self)
        LayoutProjectedProgressFill(self)
        ApplyProgressFill(self)
    end
    frame.SetNativeFillShown = function(self, shown)
        SetNativeProgressFillShown(self, shown)
    end
    frame.RefreshProjectedDriverStyle = function(self, force)
        return ApplyProjectedDriverStyle(self, force)
    end
    frame.SetBarSize = function(self, width, height, nextIconSize)
        self.outerWidth = math_max(1, tonumber(width) or self.outerWidth or 1)
        self.outerHeight = math_max(1, tonumber(height) or self.outerHeight or 1)
        if nextIconSize ~= nil then
            self.iconSize = math_max(1, tonumber(nextIconSize) or self.iconSize or 1)
        end
        LayoutProgressBar(self)
    end
    frame.SetIcon = function(self, texture)
        if self.icon and self.icon.SetIcon then
            self.icon:SetIcon(texture)
        end
    end
    frame.RefreshTheme = function(self)
        if self.track and GUI2.RefreshPrimitive then
            GUI2:RefreshPrimitive(self.track)
        end
        ApplyProgressFillStyle(self)
        LayoutProjectedProgressFill(self)
        RefreshProgressBorderOverlay(self)
        if self.icon and self.icon.RefreshTheme then
            self.icon:RefreshTheme()
        end
        ApplyProgressFill(self)
        ApplyProgressBorderCollapse(self)
    end
    GUI2:RegisterThemeObject(frame)
    LayoutProgressBar(frame)
    frame.SetValue = function(self, value, setOptions)
        local _, animate, options = ParseSetOptions(setOptions)
        local targetValue = tonumber(value) or 0
        if targetValue < 0 then targetValue = 0 end
        if targetValue > 1 then targetValue = 1 end

        if animate and self.gui2ValueInitialized and GUI2.PlayControlMotion then
            local handle = GUI2:PlayControlMotion(self, "progress-value", {
                owner = options and options.owner or self,
                key = options and options.key or nil,
                from = self.value or 0,
                to = targetValue,
                duration = options and options.duration or nil,
                durationKey = "medium",
                easing = options and options.easing or "sineOut",
                onUpdate = function(nextValue)
                    self.value = nextValue
                    ApplyProgressFill(self)
                end,
            })
            if handle then
                return handle
            end
        end

        self.value = targetValue
        ApplyProgressFill(self)
        self.gui2ValueInitialized = true
    end
    frame:SetValue(opts.value or 0.5, true)
    return frame
end

local function CreateSection(parent, title, x, y, width, height)
    local panel = GUI2:CreatePanel(parent, {
        width = width,
        height = height,
        surface = "color.surface.raised",
        border = "color.border.default",
        shadow = true,
    })
    panel:SetPoint("TOPLEFT", x, y)
    local label = GUI2:CreateText(panel, title, "font.size.lg", "color.text.heading")
    label:SetPoint("TOPLEFT", 12, -10)
    return panel
end

function GUI2.Data:RenderLab(parent, lab)
    local width = parent:GetWidth() > 100 and parent:GetWidth() or 920
    lab:RenderHeader(parent, "数据展示（Data）", "用于展示列表、行数据、统计、标签、空状态和进度条，重点检查信息密度和分割线。")
    lab:RenderComponentList(parent, "组件清单（Component List）", {
        "徽标（Badge）", "标签（Tag）", "信息行（InfoRow）", "统计块（StatBlock）",
        "空状态（EmptyState）", "列表（List）", "表格（Table）", "进度条（ProgressBar）",
    })

    local left = CreateSection(parent, "行与表格（Rows / List / Table）", 18, -88, 300, 400)
    local info = self:CreateInfoRow(left, "当前方案", "午夜黑")
    info:SetPoint("TOPLEFT", 14, -42)
    local list = self:CreateList(left, { width = 260, height = 104, items = { "普通行", "选中行", "禁用外观行" } })
    list:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -8)
    local tableFrame = self:CreateTable(left, {
        width = 260,
        height = 104,
        rowHeight = 18,
        dividerY = -30,
        rowStartY = -42,
        columns = { "名称", "状态", "值" },
        rows = {
            { "时钟", "就绪", "24" },
            { "信息条", "启用", "12" },
            { "组件库", "审查", "5B" },
        },
    })
    tableFrame:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -8)

    local middle = CreateSection(parent, "状态与标签（Stats / Badge / Tag）", 334, -88, 260, 400)
    local stat1 = self:CreateStatBlock(middle, { width = 118, label = "内存", value = "42 MB" })
    stat1:SetPoint("TOPLEFT", 14, -42)
    local stat2 = self:CreateStatBlock(middle, { width = 118, label = "帧率", value = "144", tone = "color.state.success" })
    stat2:SetPoint("LEFT", stat1, "RIGHT", 12, 0)
    local badge = self:CreateBadge(middle, "启用", "accent")
    badge:SetPoint("TOPLEFT", stat1, "BOTTOMLEFT", 0, -12)
    local tag = self:CreateTag(middle, "团队", "normal")
    tag:SetPoint("LEFT", badge, "RIGHT", 10, 0)
    local icon = GUI2:CreateIconSlot(middle, { size = 34, icon = "Interface\\Icons\\INV_Misc_QuestionMark" })
    icon:SetPoint("TOPLEFT", badge, "BOTTOMLEFT", 0, -14)
    local icon2 = GUI2:CreateIconSlot(middle, { size = 34, rounded = true, icon = "Interface\\Icons\\INV_Misc_Coin_01" })
    icon2:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    local empty = self:CreateEmptyState(middle, { width = 246, height = 76, title = "空状态", body = "没有符合条件的数据。" })
    empty:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -8)

    local progress = CreateSection(parent, "进度条（ProgressBar）", 610, -88, width - 628, 400)
    local hTitle = GUI2:CreateText(progress, "横向", "font.size.md", "color.text.heading")
    hTitle:SetPoint("TOPLEFT", 14, -38)
    local h1Label = GUI2:CreateText(progress, "左侧图标", "font.size.sm", "color.text.secondary")
    h1Label:SetPoint("TOPLEFT", 14, -62)
    local p1 = self:CreateProgressBar(progress, { width = 198, height = 22, value = 0.72, iconPosition = "left", roundedIcon = true })
    p1:SetPoint("TOPLEFT", h1Label, "BOTTOMLEFT", 0, -4)
    local h2Label = GUI2:CreateText(progress, "右侧图标", "font.size.sm", "color.text.secondary")
    h2Label:SetPoint("TOPLEFT", p1, "BOTTOMLEFT", 0, -10)
    local p2 = self:CreateProgressBar(progress, { width = 198, height = 22, value = 0.38, fillDirection = "right", iconPosition = "right", roundedIcon = true })
    p2:SetPoint("TOPLEFT", h2Label, "BOTTOMLEFT", 0, -4)
    local h3Label = GUI2:CreateText(progress, "跟随图标", "font.size.sm", "color.text.secondary")
    h3Label:SetPoint("TOPLEFT", p2, "BOTTOMLEFT", 0, -10)
    local p3 = self:CreateProgressBar(progress, { width = 176, height = 22, value = 0.58, iconPosition = "follow", roundedIcon = true })
    p3:SetPoint("TOPLEFT", h3Label, "BOTTOMLEFT", 0, -4)

    local vTitle = GUI2:CreateText(progress, "竖向", "font.size.md", "color.text.heading")
    vTitle:SetPoint("TOPLEFT", 14, -226)
    local v1Label = GUI2:CreateText(progress, "上", "font.size.sm", "color.text.secondary")
    v1Label:SetPoint("TOPLEFT", 14, -250)
    local p4 = self:CreateProgressBar(progress, { orientation = "vertical", width = 28, height = 132, value = 0.46, iconPosition = "top", roundedIcon = true })
    p4:SetPoint("TOPLEFT", v1Label, "BOTTOMLEFT", 0, -4)
    local v2Label = GUI2:CreateText(progress, "下", "font.size.sm", "color.text.secondary")
    v2Label:SetPoint("TOPLEFT", p4, "TOPRIGHT", 26, 18)
    local p5 = self:CreateProgressBar(progress, { orientation = "vertical", width = 28, height = 132, value = 0.84, iconPosition = "bottom", roundedIcon = true })
    p5:SetPoint("TOPLEFT", v2Label, "BOTTOMLEFT", 0, -4)
    local v3Label = GUI2:CreateText(progress, "跟随", "font.size.sm", "color.text.secondary")
    v3Label:SetPoint("TOPLEFT", p5, "TOPRIGHT", 26, 18)
    local p6 = self:CreateProgressBar(progress, { orientation = "vertical", width = 28, height = 104, value = 0.66, iconPosition = "follow", roundedIcon = true })
    p6:SetPoint("TOPLEFT", v3Label, "BOTTOMLEFT", 0, -4)
end
