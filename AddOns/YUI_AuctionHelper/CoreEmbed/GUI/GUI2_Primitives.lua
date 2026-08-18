local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
end
local YUI = _G.YUI
YUI.GUI2 = YUI.GUI2 or {}

local GUI2 = YUI.GUI2
local Assets = YUI.Assets

local CreateFrame = CreateFrame
local CreateColor = CreateColor
local STANDARD_TEXT_FONT = STANDARD_TEXT_FONT
local UIParent = UIParent
local C_Timer = C_Timer
local FrameAPI = YUI.API and YUI.API.Frame or YUI.WOW_API
local UnitAPI = YUI.API and YUI.API.Unit or YUI.WOW_API
local math_ceil = math.ceil
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_cos = math.cos
local math_sin = math.sin
local math_pi = math.pi
local string_format = string.format
local table_insert = table.insert
local table_remove = table.remove
local unpack = unpack
local ipairs = ipairs
local select = select
local pcall = pcall
local type = type
local GetScrollFrameScrollBar

local function GetCoreText(key, fallback)
    local locale = YUI.Locale
    if locale and locale.Get then
        local core = locale:Get("Core")
        local value = core and core[key]
        if value and value ~= key then
            return value
        end
    end
    return fallback
end

GUI2.Primitives = GUI2.Primitives or {}
GUI2.ThemeObjects = GUI2.ThemeObjects or {}
GUI2.PixelObjects = GUI2.PixelObjects or {}
GUI2.mult = GUI2.mult or 1
local DEFAULT_TEXT_FONT = GUI2.GetDefaultFont and GUI2:GetDefaultFont() or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

local COLOR_TOKENS = {
    bg = "color.surface.window",
    nav = "color.surface.nav",
    header = "color.surface.header",
    border = "color.border.default",
    border_highlight = "color.border.accent",
    shadow = "color.overlay.shadow",
    text = "color.text.primary",
    text_highlight = "color.text.accent",
    button = "color.control.bg",
    button_hover = "color.control.hover",
    button_active = "color.control.pressed",
    disabled = "color.control.disabled",
    enabled = "color.accent.primary",
    class = "color.class.primary",
}

local function GetClassColor()
    local _, class = UnitAPI.UnitClass("player")
    local color = UnitAPI.GetClassColor(class)
    if color then
        return color.r, color.g, color.b, 1
    end
    return GUI2:GetColor("color.class.primary", { 0.15, 0.55, 1, 1 })
end

GUI2.Colors = GUI2.Colors or setmetatable({}, {
    __index = function(_, key)
        if key == "class" then
            return { GetClassColor() }
        end
        local token = COLOR_TOKENS[key]
        if token and GUI2.GetColor then
            return { GUI2:GetColor(token) }
        end
        return nil
    end,
})

GUI2.Colors_Hex = GUI2.Colors_Hex or setmetatable({}, {
    __index = function(_, key)
        local r, g, b, a
        if key == "class" then
            r, g, b, a = GetClassColor()
            if CreateColor then
                return CreateColor(r, g, b, a or 1):GenerateHexColor()
            end
            return string_format("ff%02x%02x%02x", math_floor((r or 1) * 255 + 0.5), math_floor((g or 1) * 255 + 0.5), math_floor((b or 1) * 255 + 0.5))
        end
        local token = COLOR_TOKENS[key]
        if token and GUI2.GetColor then
            r, g, b, a = GUI2:GetColor(token)
            if CreateColor then
                return CreateColor(r, g, b, a or 1):GenerateHexColor()
            end
            return string_format("ff%02x%02x%02x", math_floor((r or 1) * 255 + 0.5), math_floor((g or 1) * 255 + 0.5), math_floor((b or 1) * 255 + 0.5))
        end
        return nil
    end,
})

GUI2.Fonts = GUI2.Fonts or {}
GUI2.Fonts.normal = DEFAULT_TEXT_FONT
GUI2.Fonts.header = DEFAULT_TEXT_FONT
GUI2.Fonts.size_normal = GUI2.Fonts.size_normal or 14
GUI2.Fonts.size_header = GUI2.Fonts.size_header or 16
GUI2.Fonts.size_title = GUI2.Fonts.size_title or 20

local function ResolveColor(gui, keyOrR, g, b, a, fallbackKey)
    if type(keyOrR) == "number" then
        return keyOrR, g or 0, b or 0, a == nil and 1 or a, nil
    end

    if type(keyOrR) == "table" then
        local color = keyOrR.type == "solid" and keyOrR.value or keyOrR
        return color[1] or 1, color[2] or 1, color[3] or 1, color[4] == nil and 1 or color[4], nil
    end

    return gui:GetColor(keyOrR or fallbackKey or "color.border.default")
end

local function IsJustify(value)
    return value == "LEFT" or value == "CENTER" or value == "RIGHT"
end

local function LooksLikeTexturePath(value)
    return type(value) == "string" and (value:find("\\", 1, true) or value:find("/", 1, true) or value:find("%.") or value:find("^Interface"))
end

local MIN_ICON_SIZE = 12
local MIN_ICON_BUTTON_SIZE = 20
local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local DEFAULT_ICON_TEXCOORDS = { 0.08, 0.92, 0.08, 0.92 }
local NATIVE_FRAME_TOOLTIP_LAYOUT = "TooltipDefaultLayout"
local NATIVE_FRAME_TOOLTIP_OUTSET = 5
local NATIVE_FRAME_TOOLTIP_FALLBACK_EDGE = "Interface\\Tooltips\\UI-Tooltip-Border"
local NATIVE_FRAME_TOOLTIP_FALLBACK_EDGE_SIZE = 16
local GLYPH_TEXTURES = {
    dropdownDown = Assets:Core("gui2\\glyphs\\dropdown-down-12.tga"),
}

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

    return (GUI2.mult or 1) * desiredPixels
end

function GUI2:GetPixelSize(region, desiredPixels, minPixels)
    return GetPixelSize(region, desiredPixels, minPixels)
end

local function RefreshPixelObject(object)
    if not object then return end
    if object.UpdatePixelScale then
        object:UpdatePixelScale()
    end
    if object.UpdateGUI2PixelLayout then
        object:UpdateGUI2PixelLayout()
    end
end

local function QueuePixelObjectRefresh(object)
    if not object or object.gui2PixelRefreshQueued then return end
    object.gui2PixelRefreshQueued = true

    local function Refresh()
        object.gui2PixelRefreshQueued = false
        RefreshPixelObject(object)
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, Refresh)
    else
        Refresh()
    end
end

function GUI2:UpdatePixelScale()
    local _, height = FrameAPI.GetPhysicalScreenSize()
    local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()

    if height and height > 0 and scale and scale > 0 then
        self.mult = 768 / height / scale
    else
        self.mult = 1
    end

    for _, object in ipairs(self.PixelObjects) do
        RefreshPixelObject(object)
    end
end

function GUI2:QueuePixelRefresh()
    if self.gui2PixelRefreshQueued then return end
    self.gui2PixelRefreshQueued = true

    local gui = self
    local function Refresh()
        gui.gui2PixelRefreshQueued = false
        gui:UpdatePixelScale()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, Refresh)
    else
        Refresh()
    end
end

if not GUI2.PixelScaleFrame then
    local pixelScaleOwner = {}
    local function OnPixelScaleEvent()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.1, function()
                GUI2:UpdatePixelScale()
            end)
        else
            GUI2:UpdatePixelScale()
        end
    end

    if YUI.Event then
        YUI.Event:On("UI_SCALE_CHANGED", OnPixelScaleEvent, pixelScaleOwner)
        YUI.Event:On("DISPLAY_SIZE_CHANGED", OnPixelScaleEvent, pixelScaleOwner)
        YUI.Event:On("PLAYER_ENTERING_WORLD", OnPixelScaleEvent, pixelScaleOwner)
    end
    GUI2.PixelScaleFrame = pixelScaleOwner
end

GUI2:UpdatePixelScale()

local function PreparePixelTexture(texture)
    if not texture then return end
    if texture.SetSnapToPixelGrid then
        pcall(texture.SetSnapToPixelGrid, texture, false)
    end
    if texture.SetTexelSnappingBias then
        pcall(texture.SetTexelSnappingBias, texture, 0)
    end
end

local function ApplyPaint(texture, paintKey)
    if not texture then return end
    local r, g, b, a = GUI2:GetColor(paintKey)
    texture:SetColorTexture(r, g, b, a)
end

local function GetFrameRadius(frame)
    local key = frame and frame.gui2RadiusKey or "layout.radius.panel"
    local radius = GUI2:GetMetric(key or "layout.radius.panel", 0)
    if type(radius) ~= "number" or radius <= 0 then
        return 0
    end
    return radius
end

local function GetNativeFrameBorderStyle(frame)
    return frame and frame.gui2NativeFrameBorderStyle == "tooltip" and "tooltip" or "window"
end

local function ShouldUseNativeFrameBorder(frame)
    return frame and frame.gui2NativeFrameBorder and GetNativeFrameBorderStyle(frame) == "tooltip" and GUI2:GetToken("backdrop.nativeFrameBorder.enabled") == true
end

local function GetNativeFrameBorderSpec(frame)
    return frame.gui2NativeFrameBorderLayout or NATIVE_FRAME_TOOLTIP_LAYOUT,
        NATIVE_FRAME_TOOLTIP_FALLBACK_EDGE,
        NATIVE_FRAME_TOOLTIP_FALLBACK_EDGE_SIZE
end

local function BuildBackdrop(frame)
    local radius = GetFrameRadius(frame)
    if radius <= 0 then
        frame.gui2RoundedBackdrop = false
        return {
            bgFile = "Interface\\Buttons\\WHITE8x8",
        }
    end

    local edgeSize = math_max(8, radius * 2)
    local inset = math_max(1, math_floor(radius * 0.65))
    frame.gui2RoundedBackdrop = true
    return {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = edgeSize,
        insets = { left = inset, right = inset, top = inset, bottom = inset },
    }
end

local function SetBorderTextureVisibility(frame, shown)
    if not frame or not frame.gui2Borders then return end
    if shown then
        frame.gui2Borders.top:Show()
        frame.gui2Borders.bottom:Show()
        frame.gui2Borders.left:Show()
        frame.gui2Borders.right:Show()
    else
        frame.gui2Borders.top:Hide()
        frame.gui2Borders.bottom:Hide()
        frame.gui2Borders.left:Hide()
        frame.gui2Borders.right:Hide()
    end
end

local function HideNativeFrameBorder(frame)
    if frame and frame.gui2NativeBorder then
        frame.gui2NativeBorder:Hide()
    end
    if frame and frame.gui2NativeFallbackBorder then
        frame.gui2NativeFallbackBorder:Hide()
    end
    if frame then
        frame.gui2NativeBorderActive = false
        frame.gui2NativeFallbackBorderActive = false
    end
end

local function HasNativeFrameBorder(frame)
    return frame and frame.gui2NativeBorderActive == true
end

local function AnchorNativeFrameBorder(border, frame)
    local outset = GUI2:GetMetric("backdrop.nativeFrameBorder.tooltip.outset", NATIVE_FRAME_TOOLTIP_OUTSET)
    if type(outset) ~= "number" then
        outset = NATIVE_FRAME_TOOLTIP_OUTSET
    end
    outset = math_max(0, outset)
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", frame, "TOPLEFT", -outset, outset)
    border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", outset, -outset)
end

local function ApplyNativeFallbackFrameBorder(frame, edgeFile, edgeSize)
    local border = frame.gui2NativeFallbackBorder
    if not border then
        local ok, created = pcall(CreateFrame, "Frame", nil, frame, "BackdropTemplate")
        if not ok or not created then
            frame.gui2NativeBorderActive = false
            frame.gui2NativeFallbackBorderActive = false
            return false
        end
        border = created
        border:SetFrameLevel(frame:GetFrameLevel() + 1)
        frame.gui2NativeFallbackBorder = border
    end

    border:SetFrameLevel(frame:GetFrameLevel() + 1)
    AnchorNativeFrameBorder(border, frame)
    border:SetBackdrop({
        edgeFile = edgeFile,
        edgeSize = edgeSize,
    })
    border:SetBackdropBorderColor(GUI2:GetColor((frame.gui2Borders and frame.gui2Borders.colorKey) or "color.border.default"))
    border:Show()
    frame.gui2NativeBorderActive = true
    frame.gui2NativeFallbackBorderActive = true
    return true
end

local function ApplyNativeTooltipFill(frame, border)
    if not border or not border.Center then return end
    local r, g, b, a = GUI2:GetColor(frame.gui2Surface or "color.surface.popup")
    border.Center:SetVertexColor(r, g, b, a)
    border.Center:Show()
end

local function ApplyNativeFrameBorder(frame)
    if not ShouldUseNativeFrameBorder(frame) then
        HideNativeFrameBorder(frame)
        return false
    end

    local layout, fallbackEdge, fallbackEdgeSize = GetNativeFrameBorderSpec(frame)
    if not NineSliceUtil or not NineSliceUtil.ApplyLayoutByName then
        if frame.gui2NativeBorder then
            frame.gui2NativeBorder:Hide()
        end
        return ApplyNativeFallbackFrameBorder(frame, fallbackEdge, fallbackEdgeSize)
    end

    local border = frame.gui2NativeBorder
    if not border then
        local ok, created = pcall(CreateFrame, "Frame", nil, frame, "NineSlicePanelTemplate")
        if not ok or not created then
            return ApplyNativeFallbackFrameBorder(frame, fallbackEdge, fallbackEdgeSize)
        end
        border = created
        border:SetFrameLevel(frame:GetFrameLevel() + 1)
        frame.gui2NativeBorder = border
    end

    border:SetFrameLevel(frame:GetFrameLevel() + 1)
    AnchorNativeFrameBorder(border, frame)
    local ok = pcall(NineSliceUtil.ApplyLayoutByName, border, layout)
    if not ok then
        border:Hide()
        return ApplyNativeFallbackFrameBorder(frame, fallbackEdge, fallbackEdgeSize)
    end

    if frame.gui2NativeFallbackBorder then
        frame.gui2NativeFallbackBorder:Hide()
    end
    ApplyNativeTooltipFill(frame, border)
    border:Show()
    frame.gui2NativeBorderActive = true
    frame.gui2NativeFallbackBorderActive = false
    return true
end

local function ApplyNativeBackdropBorder(frame, r, g, b, a)
    if frame and frame.gui2NativeFallbackBorderActive and frame.gui2NativeFallbackBorder and frame.gui2NativeFallbackBorder.SetBackdropBorderColor then
        frame.gui2NativeFallbackBorder:SetBackdropBorderColor(r, g, b, a)
        return true
    end
    if frame and frame.gui2RoundedBackdrop and frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(r, g, b, a)
        return true
    end
    return false
end

function GUI2:RegisterThemeObject(object)
    if not object or object.gui2ThemeRegistered then return object end
    object.gui2ThemeRegistered = true
    table_insert(self.ThemeObjects, object)
    return object
end

function GUI2:SetTextColorKey(text, colorKey, fallback)
    if not text then return end
    text.gui2ColorKey = colorKey or "color.text.primary"
    text.gui2ColorFallback = fallback
    text:SetTextColor(self:GetColor(text.gui2ColorKey, fallback))
    self:RegisterThemeObject(text)
end

function GUI2:SetTexturePaintKey(texture, paintKey)
    if not texture then return end
    texture.gui2PaintKey = paintKey or "color.surface.panel"
    ApplyPaint(texture, texture.gui2PaintKey)
    self:RegisterThemeObject(texture)
end

function GUI2:SetDropdownGlyphColor(glyph, colorKey)
    if not glyph then return end
    if glyph.gui2Component == "Glyph" then
        self:SetGlyphColor(glyph, colorKey)
    elseif glyph.SetColorKey then
        glyph:SetColorKey(colorKey)
    elseif glyph.SetTextColor then
        self:SetTextColorKey(glyph, colorKey)
    elseif glyph.SetColorTexture then
        self:SetTexturePaintKey(glyph, colorKey)
    end
end

function GUI2:RefreshThemeObjects()
    local objects = self.ThemeObjects
    if not objects then return end

    for index = #objects, 1, -1 do
        local object = objects[index]
        if not object then
            table_remove(objects, index)
        else
            if object.RefreshTheme then
                object:RefreshTheme()
            elseif object.SetTextColor and object.gui2ColorKey then
                object:SetTextColor(self:GetColor(object.gui2ColorKey, object.gui2ColorFallback))
            elseif object.SetColorTexture and object.gui2PaintKey then
                ApplyPaint(object, object.gui2PaintKey)
            elseif object.gui2Surface or object.gui2Borders or object.gui2Shadow then
                self:RefreshPrimitive(object)
            end
        end
    end
end

local function BindConfigItem(item)
    if not item or not item.key then return end

    if not item.get then
        item.get = function()
            if YUI and YUI.getConfigByKey then
                return YUI:getConfigByKey(item.key, item.default)
            end
            return item.default
        end
    end

    if not item.set then
        item.set = function(value)
            if YUI and YUI.setConfigByKey then
                YUI:setConfigByKey(item.key, value)
            end
        end
    end
end

local function GetItemValue(item)
    if not item then return nil end
    BindConfigItem(item)
    local value = item.get and item.get() or item.default
    return value
end

local function SetItemValue(item, widget, value)
    if item and item.set then item.set(value) end
    if item and item.onChange then item.onChange(widget, value) end
end

function GUI2:CreateFrame(parent, opts)
    opts = opts or {}
    local frameType = opts.type or opts.frameType or "Frame"
    local frame = CreateFrame(frameType, opts.name, parent, opts.template)
    frame.gui2RadiusKey = opts.radiusKey or opts.radius or frame.gui2RadiusKey
    frame.gui2NativeFrameBorder = opts.nativeFrameBorder == true
    frame.gui2NativeFrameBorderStyle = opts.nativeFrameBorderStyle or opts.nativeBorderStyle
    frame.gui2NativeFrameBorderLayout = opts.nativeFrameBorderLayout or opts.nativeBorderLayout

    if opts.width and opts.height then
        frame:SetSize(opts.width, opts.height)
    elseif opts.width then
        frame:SetWidth(opts.width)
    elseif opts.height then
        frame:SetHeight(opts.height)
    end

    if opts.allPoints then
        if opts.allPoints == true then
            if parent then
                frame:SetAllPoints(parent)
            else
                frame:SetAllPoints()
            end
        else
            frame:SetAllPoints(opts.allPoints)
        end
    end
    if opts.frameStrata or opts.strata then
        frame:SetFrameStrata(opts.frameStrata or opts.strata)
    end
    if opts.frameLevel or opts.level then
        frame:SetFrameLevel(opts.frameLevel or opts.level)
    end
    if opts.toplevel ~= nil and frame.SetToplevel then
        frame:SetToplevel(opts.toplevel and true or false)
    end
    if opts.mouse ~= nil then
        frame:EnableMouse(opts.mouse and true or false)
    elseif opts.enableMouse ~= nil then
        frame:EnableMouse(opts.enableMouse and true or false)
    end
    if opts.mouseWheel ~= nil and frame.EnableMouseWheel then
        frame:EnableMouseWheel(opts.mouseWheel and true or false)
    end
    if opts.movable ~= nil and frame.SetMovable then
        frame:SetMovable(opts.movable and true or false)
    end
    if (opts.clamped ~= nil or opts.clampedToScreen ~= nil) and frame.SetClampedToScreen then
        frame:SetClampedToScreen((opts.clamped ~= false and opts.clamped ~= nil) or opts.clampedToScreen == true)
    end
    if opts.drag and frame.RegisterForDrag then
        if type(opts.drag) == "table" then
            frame:RegisterForDrag(unpack(opts.drag))
        else
            frame:RegisterForDrag(opts.drag == true and "LeftButton" or opts.drag)
        end
        frame:SetScript("OnDragStart", opts.onDragStart or frame.StartMoving)
        frame:SetScript("OnDragStop", opts.onDragStop or frame.StopMovingOrSizing)
    end
    if opts.hidden then
        frame:Hide()
    end

    if opts.surface or opts.backdrop then
        self:ApplyBackdrop(frame, opts.surface or opts.backdrop)
    end
    if opts.border then
        self:CreateBorder(frame, opts.border)
    end
    if opts.shadow then
        self:CreateShadow(frame, opts.shadowKey)
    end

    frame.gui2FrameKind = opts.kind or frameType
    return frame
end

function GUI2:CreateButtonFrame(parent, opts)
    opts = opts or {}
    opts.type = "Button"
    opts.radiusKey = opts.radiusKey or "layout.radius.control"
    local button = self:CreateFrame(parent, opts)
    if button.EnableMouse then button:EnableMouse(true) end
    if button.RegisterForClicks then
        button:RegisterForClicks(opts.clicks or "AnyUp")
    end
    if opts.onClick then
        button:SetScript("OnClick", opts.onClick)
    end
    return button
end

function GUI2:CreateScrollFrame(parent, opts)
    opts = opts or {}
    local template = opts.template
    if template == nil then
        template = "UIPanelScrollFrameTemplate"
    elseif template == false then
        template = nil
    end
    local scroll = self:CreateFrame(parent, {
        type = "ScrollFrame",
        name = opts.name,
        template = template,
        width = opts.width,
        height = opts.height,
        mouseWheel = opts.mouseWheel,
    })

    if opts.child ~= false then
        local child = self:CreateFrame(scroll, {
            name = opts.childName,
            width = opts.childWidth or opts.width or 1,
            height = opts.childHeight or opts.height or 1,
        })
        scroll:SetScrollChild(child)
        scroll.child = child
        scroll.scrollChild = child
    end

    self:SkinScrollBar(scroll)
    return scroll
end

function GUI2:ApplyBackdrop(frame, surfaceKey)
    if not frame or not frame.SetBackdrop then return end
    frame.gui2Surface = surfaceKey or "color.surface.panel"
    local hasNativeFrameBorder = ApplyNativeFrameBorder(frame)
    frame:SetBackdrop(BuildBackdrop(frame))
    frame:SetBackdropColor(self:GetColor(frame.gui2Surface))
    if frame.gui2RoundedBackdrop and frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(self:GetColor((frame.gui2Borders and frame.gui2Borders.colorKey) or "color.border.default"))
    end
    if frame.gui2Borders then
        self:SetBorderColor(frame, frame.gui2Borders.colorKey)
        SetBorderTextureVisibility(frame, not frame.gui2RoundedBackdrop and not hasNativeFrameBorder)
    end
    self:RegisterThemeObject(frame)
end

local function UpdateBorderPixelScale(self)
    if not self.gui2Borders then return end
    local desiredPixels = GUI2:GetMetric(self.gui2Borders.widthKey or "border.width.hairline", 1)
    local size = GUI2:GetPixelSize(self, desiredPixels, 1)
    self.gui2Borders.top:SetHeight(size)
    self.gui2Borders.bottom:SetHeight(size)
    self.gui2Borders.left:SetWidth(size)
    self.gui2Borders.right:SetWidth(size)
end

local function HookPixelRefresh(frame, script)
    if not frame or not frame.HookScript then return end
    if frame.HasScript and not frame:HasScript(script) then return end
    frame:HookScript(script, QueuePixelObjectRefresh)
end

function GUI2:CreateBorder(frame, colorKey, g, b, a)
    if not frame or frame.gui2Borders then return end
    local r, g2, b2, a2, resolvedKey = ResolveColor(self, colorKey, g, b, a, "color.border.default")
    local widthKey = "border.width.hairline"
    local size = self:GetPixelSize(frame, self:GetMetric(widthKey, 1), 1)

    local top = frame:CreateTexture(nil, "OVERLAY")
    PreparePixelTexture(top)
    top:SetPoint("TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", 0, 0)
    top:SetHeight(size)
    top:SetColorTexture(r, g2, b2, a2)

    local bottom = frame:CreateTexture(nil, "OVERLAY")
    PreparePixelTexture(bottom)
    bottom:SetPoint("BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(size)
    bottom:SetColorTexture(r, g2, b2, a2)

    local left = frame:CreateTexture(nil, "OVERLAY")
    PreparePixelTexture(left)
    left:SetPoint("TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", 0, 0)
    left:SetWidth(size)
    left:SetColorTexture(r, g2, b2, a2)

    local right = frame:CreateTexture(nil, "OVERLAY")
    PreparePixelTexture(right)
    right:SetPoint("TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", 0, 0)
    right:SetWidth(size)
    right:SetColorTexture(r, g2, b2, a2)

    frame.gui2Borders = {
        top = top,
        bottom = bottom,
        left = left,
        right = right,
        colorKey = resolvedKey or colorKey or "color.border.default",
        colorR = resolvedKey and nil or r,
        colorG = resolvedKey and nil or g2,
        colorB = resolvedKey and nil or b2,
        colorA = resolvedKey and nil or a2,
        widthKey = widthKey,
    }
    frame.borders = {
        top,
        bottom,
        left,
        right,
    }

    frame.UpdateGUI2PixelScale = UpdateBorderPixelScale
    frame.UpdatePixelScale = UpdateBorderPixelScale
    table_insert(self.PixelObjects, frame)
    if not frame.gui2PixelRefreshHooks then
        frame.gui2PixelRefreshHooks = true
        HookPixelRefresh(frame, "OnShow")
        HookPixelRefresh(frame, "OnSizeChanged")
    end
    ApplyNativeBackdropBorder(frame, r, g2, b2, a2)
    SetBorderTextureVisibility(frame, not frame.gui2RoundedBackdrop and not HasNativeFrameBorder(frame))
    self:RegisterThemeObject(frame)
    QueuePixelObjectRefresh(frame)
end

function GUI2:SetBorderColor(frame, colorKey, g, b, a)
    if not frame or not frame.gui2Borders then return end
    local r, g2, b2, a2, resolvedKey = ResolveColor(self, colorKey or frame.gui2Borders.colorKey, g, b, a, "color.border.default")
    frame.gui2Borders.top:SetColorTexture(r, g2, b2, a2)
    frame.gui2Borders.bottom:SetColorTexture(r, g2, b2, a2)
    frame.gui2Borders.left:SetColorTexture(r, g2, b2, a2)
    frame.gui2Borders.right:SetColorTexture(r, g2, b2, a2)
    frame.gui2Borders.colorKey = resolvedKey or (type(colorKey) == "string" and colorKey or frame.gui2Borders.colorKey)
    if type(colorKey) == "number" then
        frame.gui2Borders.colorR = r
        frame.gui2Borders.colorG = g2
        frame.gui2Borders.colorB = b2
        frame.gui2Borders.colorA = a2
    end
    ApplyNativeBackdropBorder(frame, r, g2, b2, a2)
    SetBorderTextureVisibility(frame, not frame.gui2RoundedBackdrop and not HasNativeFrameBorder(frame))
end

function GUI2:CreateShadow(frame, shadowKey)
    if not frame or frame.gui2Shadow then return end
    local size = self:GetMetric(shadowKey or "shadow.panel.size", 3)
    local shadow = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    shadow:SetPoint("TOPLEFT", -size, size)
    shadow:SetPoint("BOTTOMRIGHT", size, -size)
    shadow:SetFrameLevel(frame:GetFrameLevel() > 0 and frame:GetFrameLevel() - 1 or 0)
    shadow:SetBackdrop({
        edgeFile = Assets:Core("images\\GlowTex.tga"),
        edgeSize = size,
        insets = { left = size, right = size, top = size, bottom = size },
    })
    shadow:SetBackdropBorderColor(self:GetColor("color.overlay.shadow"))
    frame.gui2Shadow = shadow
    frame.shadow = shadow
    self:RegisterThemeObject(frame)
end

local function NormalizeGlowStyle(style)
    if style == "none" or style == "pixel" or style == "soft" or style == "button" or style == "autocast" or style == "proc" or style == "pulse" then
        return style
    end
    return "soft"
end

local function UsesPixelGlowSegments(style)
    if style == "pixel" then
        return true
    end
    return false
end

local function UsesNativeGlow(style)
    if style == "button" or style == "autocast" or style == "proc" then
        return true
    end
    return false
end

local function GlowNeedsAnimation(style)
    if UsesPixelGlowSegments(style) or UsesNativeGlow(style) or style == "pulse" then
        return true
    end
    return false
end

local function GetDefaultGlowLines(style)
    if style == "pixel" then
        return 4
    end
    if style == "autocast" then
        return 4
    end
    return 1
end

local GLOW_SIZE_MIN = 0.25
local GLOW_SIZE_MAX = 5
local GLOW_EXPAND_MIN = -1
local GLOW_EXPAND_MAX = 1
local GLOW_LEGACY_SIZE_BASE = 10
local GLOW_LEGACY_EXPAND_BASE = 24
local GLOW_AXIS_EXPAND_SCALE = 0.25
local GLOW_STYLE_OUTSET_SCALE = {
    soft = 0.09,
    button = 0.20,
    autocast = 0,
    proc = 0.20,
    pulse = 0.12,
}
local GLOW_STYLE_EDGE_SCALE = {
    soft = 0.18,
    pulse = 0.16,
}

local function ClampGlowSize(value)
    value = tonumber(value)
    if value == nil then value = 1 end
    if value > GLOW_SIZE_MAX then
        value = value / GLOW_LEGACY_SIZE_BASE
    end
    if value < GLOW_SIZE_MIN then return GLOW_SIZE_MIN end
    if value > GLOW_SIZE_MAX then return GLOW_SIZE_MAX end
    return value
end

local function ClampGlowExpansion(value)
    value = tonumber(value) or 0
    if value > GLOW_EXPAND_MAX or value < GLOW_EXPAND_MIN then
        value = value / GLOW_LEGACY_EXPAND_BASE
    end
    if value < GLOW_EXPAND_MIN then return GLOW_EXPAND_MIN end
    if value > GLOW_EXPAND_MAX then return GLOW_EXPAND_MAX end
    return value
end

local function ClampGlowUnit(value, fallback)
    value = tonumber(value)
    if value == nil then value = fallback or 1 end
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function ClampGlowLines(value)
    value = math_floor(tonumber(value) or 1)
    if value < 1 then return 1 end
    if value > 20 then return 20 end
    return value
end

local function ClampGlowThickness(value)
    value = math_floor(tonumber(value) or 1)
    if value < 1 then return 1 end
    if value > 20 then return 20 end
    return value
end

local function ClampGlowLength(value)
    value = math_floor(tonumber(value) or 18)
    if value < 4 then return 4 end
    if value > 128 then return 128 end
    return value
end

local function ClampGlowSpeed(value)
    value = tonumber(value)
    if value == nil then value = 0.65 end
    if value < 0 then return 0 end
    if value > 4 then return 4 end
    return value
end

local function NormalizeGlowPhase(value)
    value = tonumber(value) or 0
    value = value - math_floor(value)
    if value < 0 then
        value = value + 1
    end
    return value
end

local function SnapGlowValue(glow, value, pixel)
    pixel = pixel or GUI2:GetPixelSize(glow, 1, 1)
    value = tonumber(value) or 0
    if pixel and pixel > 0 then
        return math_floor(value / pixel + 0.5) * pixel
    end
    return value
end

local function GetGlowTargetSize(glow, target)
    target = target or (glow and glow.gui2GlowTarget) or glow
    local width = target and target.GetWidth and (target:GetWidth() or 0) or 0
    local height = target and target.GetHeight and (target:GetHeight() or 0) or 0
    if width <= 0 and glow and glow.GetWidth then
        width = glow:GetWidth() or 0
    end
    if height <= 0 and glow and glow.GetHeight then
        height = glow:GetHeight() or 0
    end
    if width <= 0 then width = 32 end
    if height <= 0 then height = 32 end
    return width, height, math_min(width, height)
end

local function GetGlowOffsetXY(glow, target, pixel)
    pixel = pixel or GUI2:GetPixelSize(glow, 1, 1)
    local width, height = GetGlowTargetSize(glow, target)
    return
        SnapGlowValue(glow, ClampGlowExpansion(glow and glow.gui2GlowOffsetX) * width * GLOW_AXIS_EXPAND_SCALE, pixel),
        SnapGlowValue(glow, ClampGlowExpansion(glow and glow.gui2GlowOffsetY) * height * GLOW_AXIS_EXPAND_SCALE, pixel)
end

local function ResolveGlowOutset(glow, style)
    local _, _, base = GetGlowTargetSize(glow)
    local size = ClampGlowSize(glow and glow.gui2GlowSize)
    local scale = GLOW_STYLE_OUTSET_SCALE[style] or GLOW_STYLE_OUTSET_SCALE.soft
    return math_max(0, base * scale * size)
end

local function ResolveGlowEdgeSize(glow, style)
    local _, _, base = GetGlowTargetSize(glow)
    local size = ClampGlowSize(glow and glow.gui2GlowSize)
    local scale = GLOW_STYLE_EDGE_SCALE[style] or GLOW_STYLE_EDGE_SCALE.soft
    return math_max(GUI2:GetPixelSize(glow, 1, 1), base * scale * size)
end

local function SetGlowTargetPoints(glow, target, outset)
    if not (glow and target) then return end
    local pixel = GUI2:GetPixelSize(glow, 1, 1)
    local expandX, expandY = GetGlowOffsetXY(glow, target, pixel)
    outset = SnapGlowValue(glow, tonumber(outset) or 0, pixel)
    local horizontal = SnapGlowValue(glow, outset + expandX, pixel)
    local vertical = SnapGlowValue(glow, outset + expandY, pixel)
    local targetWidth = target.GetWidth and (target:GetWidth() or 0) or 0
    local targetHeight = target.GetHeight and (target:GetHeight() or 0) or 0
    if targetWidth > pixel * 2 then
        horizontal = math_max(horizontal, -(targetWidth / 2 - pixel))
    elseif horizontal < 0 then
        horizontal = 0
    end
    if targetHeight > pixel * 2 then
        vertical = math_max(vertical, -(targetHeight / 2 - pixel))
    elseif vertical < 0 then
        vertical = 0
    end
    glow:ClearAllPoints()
    glow:SetPoint("TOPLEFT", target, "TOPLEFT", -horizontal, vertical)
    glow:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", horizontal, -vertical)
end

local function SetGlowTextureShown(texture, shown)
    if not texture then return end
    if shown then
        texture:Show()
    else
        texture:Hide()
    end
end

local function HideLegacyPixelGlowSides(line)
    if not line then return end
    SetGlowTextureShown(line.top, false)
    SetGlowTextureShown(line.bottom, false)
    SetGlowTextureShown(line.left, false)
    SetGlowTextureShown(line.right, false)
    SetGlowTextureShown(line.segment, false)
end

local function EnsurePixelGlowLine(glow, index)
    glow.gui2PixelLines = glow.gui2PixelLines or {}
    local line = glow.gui2PixelLines[index]
    if not line then
        line = {}
        glow.gui2PixelLines[index] = line
    end

    line.parts = line.parts or {}
    for partIndex = 1, 4 do
        if not line.parts[partIndex] then
            line.parts[partIndex] = glow:CreateTexture(nil, "OVERLAY")
            PreparePixelTexture(line.parts[partIndex])
        end
    end
    return line
end

local function SetPixelGlowLineShown(line, shown)
    if not line then return end
    HideLegacyPixelGlowSides(line)
    if line.parts then
        for _, texture in ipairs(line.parts) do
            SetGlowTextureShown(texture, shown)
        end
    end
end

local function HidePixelGlowLines(glow)
    if not (glow and glow.gui2PixelLines) then return end
    for _, line in ipairs(glow.gui2PixelLines) do
        SetPixelGlowLineShown(line, false)
    end
end

local function StopAnimationGroup(group)
    if group and group.Stop then
        group:Stop()
    end
end

local function PlayAnimationGroup(group)
    if group and group.Play and not (group.IsPlaying and group:IsPlaying()) then
        group:Play()
    end
end

local function SetTextureAtlasSafe(texture, atlas)
    if not (texture and texture.SetAtlas and atlas) then return false end
    local ok = pcall(texture.SetAtlas, texture, atlas, false)
    return ok == true
end

local BUTTON_GLOW_TEXTURE = "Interface\\SpellActivationOverlay\\IconAlert"
local BUTTON_GLOW_ANTS_TEXTURE = "Interface\\SpellActivationOverlay\\IconAlertAnts"
local BUTTON_GLOW_COORDS = {
    spark = { 0.00781250, 0.61718750, 0.00390625, 0.26953125 },
    innerGlow = { 0.00781250, 0.50781250, 0.27734375, 0.52734375 },
    innerGlowOver = { 0.00781250, 0.50781250, 0.53515625, 0.78515625 },
    outerGlow = { 0.00781250, 0.50781250, 0.27734375, 0.52734375 },
    outerGlowOver = { 0.00781250, 0.50781250, 0.53515625, 0.78515625 },
}
local BUTTON_GLOW_TEXTURE_ORDER = { "spark", "innerGlow", "innerGlowOver", "outerGlow", "outerGlowOver", "ants" }
local BUTTON_GLOW_ALPHA_SCALE = 1.12

local AUTOCAST_SHINE_TEXTURE = YUI.IsRetail and "Interface\\Artifacts\\Artifacts" or "Interface\\ItemSocketingFrame\\UI-ItemSockets"
local AUTOCAST_SHINE_COORDS = YUI.IsRetail
    and { 0.8115234375, 0.9169921875, 0.8798828125, 0.9853515625 }
    or { 0.3984375, 0.4453125, 0.40234375, 0.44921875 }
local AUTOCAST_PARTICLE_SIZES = { 7, 6, 5, 4 }

local function ResolveButtonGlowAlpha(alpha)
    alpha = tonumber(alpha) or 1
    if alpha <= 0 then return 0 end
    return math_min(1, alpha * BUTTON_GLOW_ALPHA_SCALE)
end

local function CreateButtonGlowTexture(frame, key, layer)
    local texture = frame:CreateTexture(nil, layer or "ARTWORK")
    texture:SetPoint("CENTER")
    texture:SetBlendMode("ADD")
    if key == "ants" then
        texture:SetTexture(BUTTON_GLOW_ANTS_TEXTURE)
    else
        texture:SetTexture(BUTTON_GLOW_TEXTURE)
        local coords = BUTTON_GLOW_COORDS[key]
        if coords then
            texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        end
    end
    texture:SetAlpha(0)
    return texture
end

local function CreateButtonScaleAnim(group, target, order, duration, x, y, delay)
    local scale = group:CreateAnimation("Scale")
    scale:SetChildKey(target)
    scale:SetOrder(order)
    scale:SetDuration(duration)
    scale:SetScale(x, y)
    if delay then
        scale:SetStartDelay(delay)
    end
end

local function CreateButtonAlphaAnim(group, target, order, duration, fromAlpha, toAlpha, delay, appear)
    local alpha = group:CreateAnimation("Alpha")
    alpha:SetChildKey(target)
    alpha:SetOrder(order)
    alpha:SetDuration(duration)
    alpha:SetFromAlpha(fromAlpha)
    alpha:SetToAlpha(toAlpha)
    if delay then
        alpha:SetStartDelay(delay)
    end
    if appear then
        table_insert(group.appear, alpha)
    else
        table_insert(group.fade, alpha)
    end
end

local function UpdateButtonGlowAlphaAnimations(frame, alpha)
    if not (frame and frame.animIn) then return end
    alpha = alpha or 1
    for _, anim in ipairs(frame.animIn.appear) do
        anim:SetToAlpha(alpha)
    end
    for _, anim in ipairs(frame.animIn.fade) do
        anim:SetFromAlpha(alpha)
    end
end

local function ApplyButtonGlowStableState(frame)
    if not frame then return end
    local width = frame.GetWidth and (frame:GetWidth() or 0) or 0
    local height = frame.GetHeight and (frame:GetHeight() or 0) or 0
    if width <= 0 or height <= 0 then return end
    local alpha = frame.gui2ButtonGlowAlpha or 1

    frame.spark:SetSize(width, height)
    frame.spark:SetAlpha(0)
    frame.innerGlow:SetSize(width, height)
    frame.innerGlow:SetAlpha(0)
    frame.innerGlowOver:SetAlpha(0)
    frame.outerGlow:SetSize(width, height)
    frame.outerGlow:SetAlpha(alpha)
    frame.outerGlowOver:SetAlpha(0)
    frame.ants:SetSize(width * 0.85, height * 0.85)
    frame.ants:SetAlpha(alpha)
end

local function ButtonGlowAnimInOnPlay(group)
    local frame = group:GetParent()
    local width = frame.GetWidth and (frame:GetWidth() or 0) or 0
    local height = frame.GetHeight and (frame:GetHeight() or 0) or 0
    if width <= 0 or height <= 0 then return end
    local alpha = frame.gui2ButtonGlowAlpha or 1
    local sparkAlpha = frame.gui2ButtonGlowTinted and alpha * 0.3 or alpha

    frame.spark:SetSize(width, height)
    frame.spark:SetAlpha(sparkAlpha)
    frame.innerGlow:SetSize(width / 2, height / 2)
    frame.innerGlow:SetAlpha(alpha)
    frame.innerGlowOver:SetAlpha(alpha)
    frame.outerGlow:SetSize(width * 2, height * 2)
    frame.outerGlow:SetAlpha(alpha)
    frame.outerGlowOver:SetAlpha(alpha)
    frame.ants:SetSize(width * 0.85, height * 0.85)
    frame.ants:SetAlpha(0)
    frame:Show()
end

local function ButtonGlowAnimInOnFinished(group)
    ApplyButtonGlowStableState(group:GetParent())
end

local function ButtonGlowAnimInOnStop(group)
    local frame = group:GetParent()
    frame.spark:SetAlpha(0)
    frame.innerGlow:SetAlpha(0)
    frame.innerGlowOver:SetAlpha(0)
    frame.outerGlowOver:SetAlpha(0)
end

local function EnsureButtonGlowAnimations(frame)
    if frame.animIn then return end

    frame.animIn = frame:CreateAnimationGroup()
    frame.animIn.appear = {}
    frame.animIn.fade = {}
    CreateButtonScaleAnim(frame.animIn, "spark", 1, 0.2, 1.5, 1.5)
    CreateButtonAlphaAnim(frame.animIn, "spark", 1, 0.2, 0, 1, nil, true)
    CreateButtonScaleAnim(frame.animIn, "innerGlow", 1, 0.3, 2, 2)
    CreateButtonScaleAnim(frame.animIn, "innerGlowOver", 1, 0.3, 2, 2)
    CreateButtonAlphaAnim(frame.animIn, "innerGlowOver", 1, 0.3, 1, 0, nil, false)
    CreateButtonScaleAnim(frame.animIn, "outerGlow", 1, 0.3, 0.5, 0.5)
    CreateButtonScaleAnim(frame.animIn, "outerGlowOver", 1, 0.3, 0.5, 0.5)
    CreateButtonAlphaAnim(frame.animIn, "outerGlowOver", 1, 0.3, 1, 0, nil, false)
    CreateButtonScaleAnim(frame.animIn, "spark", 1, 0.2, 2 / 3, 2 / 3, 0.2)
    CreateButtonAlphaAnim(frame.animIn, "spark", 1, 0.2, 1, 0, 0.2, false)
    CreateButtonAlphaAnim(frame.animIn, "innerGlow", 1, 0.2, 1, 0, 0.3, false)
    CreateButtonAlphaAnim(frame.animIn, "ants", 1, 0.2, 0, 1, 0.3, true)
    frame.animIn:SetScript("OnPlay", ButtonGlowAnimInOnPlay)
    frame.animIn:SetScript("OnStop", ButtonGlowAnimInOnStop)
    frame.animIn:SetScript("OnFinished", ButtonGlowAnimInOnFinished)
end

local function ResetButtonGlowFrame(frame)
    if not frame then return end
    StopAnimationGroup(frame.animIn)
    frame.gui2ButtonGlowStarted = false
    for _, texture in ipairs(frame.textures or {}) do
        texture:SetAlpha(0)
    end
    frame:Hide()
end

local function StartButtonGlowFrame(frame)
    if not frame or frame.gui2ButtonGlowStarted then return end
    frame.gui2ButtonGlowStarted = true
    UpdateButtonGlowAlphaAnimations(frame, frame.gui2ButtonGlowAlpha or 1)
    if frame.animIn then
        frame.animIn:Play()
    else
        ApplyButtonGlowStableState(frame)
    end
end

local function ApplyButtonGlowColor(frame, r, g2, b2, alpha)
    if not frame then return end
    alpha = ResolveButtonGlowAlpha(alpha)
    frame.gui2ButtonGlowAlpha = alpha
    frame.gui2ButtonGlowTinted = not ((r or 1) >= 0.98 and (g2 or 1) >= 0.98 and (b2 or 1) >= 0.98)
    for _, texture in ipairs(frame.textures or {}) do
        if texture.SetDesaturated then
            texture:SetDesaturated(frame.gui2ButtonGlowTinted and 1 or nil)
        end
        if texture.SetVertexColor then
            if frame.gui2ButtonGlowTinted then
                texture:SetVertexColor(r or 1, g2 or 1, b2 or 1)
            else
                texture:SetVertexColor(1, 1, 1)
            end
        end
    end
    UpdateButtonGlowAlphaAnimations(frame, alpha)
    if frame.gui2ButtonGlowStarted and not (frame.animIn and frame.animIn:IsPlaying()) then
        ApplyButtonGlowStableState(frame)
    end
end

local function EnsureButtonGlowFrame(glow)
    if glow.gui2ButtonGlow then
        return glow.gui2ButtonGlow
    end

    local frame = CreateFrame("Frame", nil, glow)
    frame:Hide()
    frame.textures = {}
    frame.spark = CreateButtonGlowTexture(frame, "spark", "BACKGROUND")
    frame.innerGlow = CreateButtonGlowTexture(frame, "innerGlow", "ARTWORK")
    frame.innerGlowOver = CreateButtonGlowTexture(frame, "innerGlowOver", "ARTWORK")
    frame.outerGlow = CreateButtonGlowTexture(frame, "outerGlow", "ARTWORK")
    frame.outerGlowOver = CreateButtonGlowTexture(frame, "outerGlowOver", "ARTWORK")
    frame.innerGlowOver:ClearAllPoints()
    frame.innerGlowOver:SetPoint("TOPLEFT", frame.innerGlow, "TOPLEFT")
    frame.innerGlowOver:SetPoint("BOTTOMRIGHT", frame.innerGlow, "BOTTOMRIGHT")
    frame.outerGlowOver:ClearAllPoints()
    frame.outerGlowOver:SetPoint("TOPLEFT", frame.outerGlow, "TOPLEFT")
    frame.outerGlowOver:SetPoint("BOTTOMRIGHT", frame.outerGlow, "BOTTOMRIGHT")
    frame.ants = CreateButtonGlowTexture(frame, "ants", "OVERLAY")
    for _, key in ipairs(BUTTON_GLOW_TEXTURE_ORDER) do
        frame.textures[#frame.textures + 1] = frame[key]
    end
    frame.gui2ButtonGlowAlpha = 1
    EnsureButtonGlowAnimations(frame)
    glow.gui2ButtonGlow = frame
    return frame
end

local function EnsureAutoCastGlow(glow)
    if glow.gui2AutoCastFrame then
        return glow.gui2AutoCastFrame
    end

    local frame = CreateFrame("Frame", nil, glow)
    frame:SetAllPoints(glow)
    frame:Hide()
    frame.textures = {}
    frame.timer = { 0, 0, 0, 0 }
    glow.gui2AutoCastFrame = frame
    return frame
end

local function EnsureAutoCastParticle(frame, index)
    local texture = frame.textures[index]
    if texture then
        return texture
    end

    texture = frame:CreateTexture(nil, "OVERLAY")
    texture:SetTexture(AUTOCAST_SHINE_TEXTURE)
    texture:SetTexCoord(AUTOCAST_SHINE_COORDS[1], AUTOCAST_SHINE_COORDS[2], AUTOCAST_SHINE_COORDS[3], AUTOCAST_SHINE_COORDS[4])
    texture:SetBlendMode("ADD")
    texture:Hide()
    frame.textures[index] = texture
    return texture
end

local function EnsureProcGlow(glow)
    if glow.gui2ProcFrame or glow.gui2ProcFallback then
        return glow.gui2ProcFrame or glow.gui2ProcFallback
    end

    local ok, frame = pcall(CreateFrame, "Frame", nil, glow, "ActionButtonSpellAlertTemplate")
    if ok and frame then
        frame:SetAllPoints(glow)
        frame:Hide()
        glow.gui2ProcFrame = frame
        return frame
    end

    local fallback = CreateFrame("Frame", nil, glow)
    fallback:SetAllPoints(glow)
    fallback:Hide()
    local texture = fallback:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints(fallback)
    texture:SetBlendMode("ADD")
    if not SetTextureAtlasSafe(texture, "UI-HUD-ActionBar-Proc-Loop-Flipbook") then
        texture:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
        texture:SetTexCoord(0.00781250, 0.50781250, 0.53515625, 0.78515625)
    end
    fallback.Texture = texture
    glow.gui2ProcFallback = fallback
    return fallback
end

local function EnsurePulseGlowFrame(glow)
    if glow.gui2PulseFrame then
        return glow.gui2PulseFrame
    end

    local frame = CreateFrame("Frame", nil, glow, "BackdropTemplate")
    frame:SetPoint("CENTER", glow, "CENTER", 0, 0)
    frame:Hide()
    glow.gui2PulseFrame = frame
    return frame
end

local function HidePulseGlow(glow)
    if glow and glow.gui2PulseFrame then
        glow.gui2PulseFrame:Hide()
    end
end

local function HideNativeGlow(glow)
    if not glow then return end
    if glow.gui2ButtonGlow then
        ResetButtonGlowFrame(glow.gui2ButtonGlow)
    end
    if glow.gui2AutoCastFrame then
        glow.gui2AutoCastFrame:Hide()
    end
    if glow.gui2ProcFrame then
        StopAnimationGroup(glow.gui2ProcFrame.ProcStartAnim)
        StopAnimationGroup(glow.gui2ProcFrame.ProcLoop)
        glow.gui2ProcFrame:Hide()
    end
    if glow.gui2ProcFallback then
        glow.gui2ProcFallback:Hide()
    end
end

local function ApplyButtonGlowLayout(glow)
    local frame = EnsureButtonGlowFrame(glow)
    local target = glow.gui2GlowTarget or glow
    local width = target.GetWidth and target:GetWidth() or glow:GetWidth() or 0
    local height = target.GetHeight and target:GetHeight() or glow:GetHeight() or 0
    if width <= 0 or height <= 0 then
        width = glow.GetWidth and glow:GetWidth() or 1
        height = glow.GetHeight and glow:GetHeight() or 1
    end
    if frame.SetFrameLevel and glow.GetFrameLevel then
        frame:SetFrameLevel((glow:GetFrameLevel() or 0) + 1)
    end

    local frameWidth = glow.GetWidth and glow:GetWidth() or 0
    local frameHeight = glow.GetHeight and glow:GetHeight() or 0
    if frameWidth <= 0 or frameHeight <= 0 then
        local outset = ResolveGlowOutset(glow, "button")
        frameWidth = math_max(1, width + outset * 2)
        frameHeight = math_max(1, height + outset * 2)
    end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", glow, "CENTER", 0, 0)
    frame:SetSize(frameWidth, frameHeight)
    if frame.gui2ButtonGlowStarted and not (frame.animIn and frame.animIn:IsPlaying()) then
        ApplyButtonGlowStableState(frame)
    end
    return frame
end

local function ApplyPulseGlowLayout(glow)
    local frame = EnsurePulseGlowFrame(glow)
    local width = glow.GetWidth and glow:GetWidth() or 0
    local height = glow.GetHeight and glow:GetHeight() or 0
    if width <= 0 or height <= 0 then
        local targetWidth, targetHeight = GetGlowTargetSize(glow)
        local outset = ResolveGlowOutset(glow, "pulse")
        width = targetWidth + outset * 2
        height = targetHeight + outset * 2
    end
    local edgeSize = ResolveGlowEdgeSize(glow, "pulse")
    if frame.gui2PulseEdgeSize ~= edgeSize then
        frame:SetBackdrop({
            edgeFile = Assets:Core("images\\GlowTex.tga"),
            edgeSize = edgeSize,
            insets = { left = edgeSize, right = edgeSize, top = edgeSize, bottom = edgeSize },
        })
        frame.gui2PulseEdgeSize = edgeSize
    end
    width = math_max(1, width)
    height = math_max(1, height)
    if frame.gui2PulseWidth ~= width or frame.gui2PulseHeight ~= height then
        frame:SetSize(width, height)
        frame.gui2PulseWidth = width
        frame.gui2PulseHeight = height
    end
    if frame.SetFrameLevel and glow.GetFrameLevel then
        frame:SetFrameLevel((glow:GetFrameLevel() or 0) + 1)
    end
    frame:Show()
    return frame
end

local function ActivateNativeGlow(glow, style)
    if not (glow and glow.IsShown and glow:IsShown()) then return end
    HideNativeGlow(glow)

    if style == "button" then
        local frame = ApplyButtonGlowLayout(glow)
        ApplyButtonGlowColor(
            frame,
            glow.gui2GlowResolvedR or glow.gui2ColorR or 1,
            glow.gui2GlowResolvedG or glow.gui2ColorG or 1,
            glow.gui2GlowResolvedB or glow.gui2ColorB or 1,
            glow.gui2GlowResolvedAlpha or glow.gui2GlowAlpha or 1
        )
        frame:Show()
    elseif style == "autocast" then
        local frame = EnsureAutoCastGlow(glow)
        frame:SetAllPoints(glow)
        frame:Show()
    elseif style == "proc" then
        local frame = EnsureProcGlow(glow)
        frame:Show()
        StopAnimationGroup(frame.ProcStartAnim)
        if frame.ProcStartFlipbook then
            frame.ProcStartFlipbook:Hide()
        end
        if frame.ProcLoop then
            PlayAnimationGroup(frame.ProcLoop)
        elseif frame.Texture then
            frame.Texture:Show()
        end
    end
end

local function GetPixelGlowSide(width, height, position)
    if position < width then
        return "TOP", position, width - position
    end
    if position < width + height then
        return "RIGHT", position - width, width + height - position
    end
    if position < width * 2 + height then
        local x = width - (position - width - height)
        return "BOTTOM", x, x
    end
    local y = position - width * 2 - height
    return "LEFT", y, height - y
end

local function PlacePixelGlowPiece(glow, texture, side, sidePosition, thickness, length, offset, pixel)
    if not texture then return end
    texture:ClearAllPoints()
    if side == "TOP" then
        local x = SnapGlowValue(glow, sidePosition, pixel)
        texture:SetSize(SnapGlowValue(glow, length, pixel), thickness)
        texture:SetPoint("BOTTOMLEFT", glow, "TOPLEFT", x, offset - thickness / 2)
    elseif side == "RIGHT" then
        local y = SnapGlowValue(glow, sidePosition, pixel)
        texture:SetSize(thickness, SnapGlowValue(glow, length, pixel))
        texture:SetPoint("TOPLEFT", glow, "TOPRIGHT", offset - thickness / 2, -y)
    elseif side == "BOTTOM" then
        local x = SnapGlowValue(glow, sidePosition, pixel)
        texture:SetSize(SnapGlowValue(glow, length, pixel), thickness)
        texture:SetPoint("TOPRIGHT", glow, "BOTTOMLEFT", x, -(offset - thickness / 2))
    else
        local y = SnapGlowValue(glow, sidePosition, pixel)
        texture:SetSize(thickness, SnapGlowValue(glow, length, pixel))
        texture:SetPoint("BOTTOMRIGHT", glow, "BOTTOMLEFT", -(offset - thickness / 2), y)
    end
    texture:Show()
end

local function PlacePixelGlowSegment(glow, line, position, thickness, length, offset, pixel)
    if not (line and line.parts) then return end
    local width = glow.GetWidth and glow:GetWidth() or 0
    local height = glow.GetHeight and glow:GetHeight() or 0
    local perimeter = (width + height) * 2
    if perimeter <= 0 then
        SetPixelGlowLineShown(line, false)
        return
    end

    position = position % perimeter
    thickness = math_max(pixel, SnapGlowValue(glow, thickness, pixel))
    length = math_max(pixel, SnapGlowValue(glow, length, pixel))
    offset = SnapGlowValue(glow, offset, pixel)

    local partIndex = 1
    local remaining = length
    local current = position
    while remaining >= pixel and partIndex <= #line.parts do
        local side, sidePosition, sideRemaining = GetPixelGlowSide(width, height, current)
        sideRemaining = SnapGlowValue(glow, sideRemaining, pixel)
        if sideRemaining < pixel then
            current = (current + pixel) % perimeter
        else
            local pieceLength = math_min(remaining, sideRemaining)
            if pieceLength >= pixel then
                PlacePixelGlowPiece(glow, line.parts[partIndex], side, sidePosition, thickness, pieceLength, offset, pixel)
                partIndex = partIndex + 1
            end
            current = (current + pieceLength) % perimeter
            remaining = remaining - pieceLength
        end
    end

    for index = partIndex, #line.parts do
        SetGlowTextureShown(line.parts[index], false)
    end
end

local function UpdateButtonGlowFrame(glow, elapsed)
    local frame = ApplyButtonGlowLayout(glow)
    local alpha = ResolveButtonGlowAlpha(glow.gui2GlowResolvedAlpha or glow.gui2GlowAlpha or 1)

    frame.gui2ButtonGlowAlpha = alpha
    UpdateButtonGlowAlphaAnimations(frame, alpha)
    StartButtonGlowFrame(frame)

    if type(AnimateTexCoords) == "function" then
        local speed = math_max(0.2, ClampGlowSpeed(glow.gui2GlowSpeed))
        AnimateTexCoords(frame.ants, 256, 256, 48, 48, 22, elapsed or 0, 0.25 / speed * 0.01)
    end
    frame:Show()
end

local function PlaceAutoCastParticle(frame, texture, position, width, height)
    local rightLimit = height + width
    local bottomLimit = height * 2 + width
    texture:ClearAllPoints()
    if position > bottomLimit then
        texture:SetPoint("CENTER", frame, "BOTTOMRIGHT", -position + bottomLimit, 0)
    elseif position > rightLimit then
        texture:SetPoint("CENTER", frame, "TOPRIGHT", 0, -position + rightLimit)
    elseif position > height then
        texture:SetPoint("CENTER", frame, "TOPLEFT", position - height, 0)
    else
        texture:SetPoint("CENTER", frame, "BOTTOMLEFT", 0, position)
    end
end

local function UpdateAutoCastGlowLayout(glow)
    local frame = EnsureAutoCastGlow(glow)
    if frame.SetFrameLevel and glow.GetFrameLevel then
        frame:SetFrameLevel((glow:GetFrameLevel() or 0) + 1)
    end
    local lineCount = ClampGlowLines(glow.gui2GlowLines or GetDefaultGlowLines("autocast"))
    local total = lineCount * #AUTOCAST_PARTICLE_SIZES
    local width = frame.GetWidth and frame:GetWidth() or 0
    local height = frame.GetHeight and frame:GetHeight() or 0
    local perimeter = (width + height) * 2
    local alpha = glow.gui2GlowResolvedAlpha or glow.gui2GlowAlpha or 1
    local scale = math_max(0.5, (tonumber(glow.gui2GlowSize) or 8) / 8)
    local elapsed = glow.gui2GlowNativeElapsed or 0

    if perimeter <= 0 then
        for _, texture in ipairs(frame.textures) do
            texture:Hide()
        end
        return
    end

    local textureIndex = 0
    for layer, size in ipairs(AUTOCAST_PARTICLE_SIZES) do
        local layerAlpha = alpha * (1 - (layer - 1) * 0.12)
        local layerProgress = (elapsed / layer) % 1
        for index = 1, lineCount do
            textureIndex = textureIndex + 1
            local texture = EnsureAutoCastParticle(frame, textureIndex)
            local position = ((index / lineCount + layerProgress) % 1) * perimeter
            if texture.SetVertexColor then
                texture:SetVertexColor(glow.gui2GlowResolvedR or 1, glow.gui2GlowResolvedG or 1, glow.gui2GlowResolvedB or 1, 1)
            end
            texture:SetSize(size * scale, size * scale)
            texture:SetAlpha(layerAlpha)
            PlaceAutoCastParticle(frame, texture, position, width, height)
            texture:Show()
        end
    end

    for index = total + 1, #frame.textures do
        frame.textures[index]:Hide()
    end
end

local UpdatePixelGlowLayout
local RefreshGlowAnimation

local function GlowOnUpdate(object, elapsed)
    if not object or not object.IsShown or not object:IsShown() then
        if object and object.SetScript then
            object:SetScript("OnUpdate", nil)
        end
        return
    end

    local style = NormalizeGlowStyle(object.gui2GlowStyle)
    if UsesPixelGlowSegments(style) then
        object.gui2GlowPhase = NormalizeGlowPhase((object.gui2GlowPhase or 0) + (elapsed or 0) * ClampGlowSpeed(object.gui2GlowSpeed))
        if UpdatePixelGlowLayout then
            UpdatePixelGlowLayout(object)
        end
        return
    end

    if style == "pulse" then
        object.gui2GlowPulse = (object.gui2GlowPulse or 0) + (elapsed or 0) * math_max(0.2, ClampGlowSpeed(object.gui2GlowSpeed))
        local pulse = 0.5 - 0.5 * math_cos(object.gui2GlowPulse * math_pi * 2)
        local frame = ApplyPulseGlowLayout(object)
        frame:SetScale(0.94 + 0.10 * pulse)
        frame:SetAlpha((object.gui2GlowResolvedAlpha or object.gui2GlowAlpha or 1) * (0.40 + 0.55 * pulse))
        object:SetAlpha(1)
        return
    end

    if UsesNativeGlow(style) then
        object.gui2GlowNativeElapsed = (object.gui2GlowNativeElapsed or 0) + (elapsed or 0) * math_max(0.2, ClampGlowSpeed(object.gui2GlowSpeed))
        if style == "button" then
            UpdateButtonGlowFrame(object, elapsed)
        elseif style == "autocast" then
            UpdateAutoCastGlowLayout(object)
        elseif style == "proc" and object.gui2ProcFallback and object.gui2ProcFallback.Texture then
            local pulse = 0.5 + 0.5 * math_sin(object.gui2GlowNativeElapsed * math_pi * 2)
            object.gui2ProcFallback.Texture:SetAlpha(0.55 + 0.45 * pulse)
        end
        return
    end

    object:SetAlpha(1)
    object:SetScript("OnUpdate", nil)
end

RefreshGlowAnimation = function(glow)
    if not glow then return end
    local style = NormalizeGlowStyle(glow.gui2GlowStyle)
    if style == "none" then
        HideNativeGlow(glow)
        HidePulseGlow(glow)
        glow:SetScript("OnUpdate", nil)
        glow:SetAlpha(0)
        return
    end
    if style ~= "pulse" then
        HidePulseGlow(glow)
    end
    local shown = glow.IsShown and glow:IsShown()
    if shown and UsesNativeGlow(style) then
        ActivateNativeGlow(glow, style)
    else
        HideNativeGlow(glow)
    end
    if shown and GlowNeedsAnimation(style) then
        if style ~= "pulse" then
            glow:SetAlpha(1)
        end
        glow:SetScript("OnUpdate", GlowOnUpdate)
    else
        glow:SetScript("OnUpdate", nil)
        glow:SetAlpha(1)
    end
end

UpdatePixelGlowLayout = function(glow)
    if not glow or not UsesPixelGlowSegments(glow.gui2GlowStyle) then return end

    local lineCount = ClampGlowLines(glow.gui2GlowLines)
    local pixel = GUI2:GetPixelSize(glow, 1, 1)
    local thickness = GUI2:GetPixelSize(glow, ClampGlowThickness(glow.gui2GlowThickness), 1)
    local length = GUI2:GetPixelSize(glow, ClampGlowLength(glow.gui2GlowLength), 1)
    local offset = GUI2:GetPixelSize(glow, tonumber(glow.gui2GlowOffset) or 0, 0)
    local width = glow.GetWidth and glow:GetWidth() or 0
    local height = glow.GetHeight and glow:GetHeight() or 0
    local perimeter = (width + height) * 2
    if perimeter <= 0 then
        HidePixelGlowLines(glow)
        return
    end

    for index = 1, lineCount do
        local line = EnsurePixelGlowLine(glow, index)
        local position = (NormalizeGlowPhase(glow.gui2GlowPhase) + (index - 1) / lineCount) * perimeter
        PlacePixelGlowSegment(glow, line, position, thickness, length, offset, pixel)
    end

    if glow.gui2PixelLines then
        for index = lineCount + 1, #glow.gui2PixelLines do
            SetPixelGlowLineShown(glow.gui2PixelLines[index], false)
        end
    end
end

local function ApplyGlowColor(glow)
    if not glow then return end
    local r, g2, b2, a2
    if glow.gui2ColorKey then
        r, g2, b2, a2 = ResolveColor(GUI2, glow.gui2ColorKey, nil, nil, nil, "color.border.accent")
    else
        r, g2, b2, a2 = glow.gui2ColorR or 1, glow.gui2ColorG or 1, glow.gui2ColorB or 1, glow.gui2ColorA == nil and 1 or glow.gui2ColorA
    end

    local alpha = a2
    if glow.gui2GlowAlpha ~= nil then
        alpha = alpha * glow.gui2GlowAlpha
    end
    glow.gui2GlowResolvedR = r
    glow.gui2GlowResolvedG = g2
    glow.gui2GlowResolvedB = b2
    glow.gui2GlowResolvedAlpha = alpha

    if UsesPixelGlowSegments(glow.gui2GlowStyle) then
        local lineCount = ClampGlowLines(glow.gui2GlowLines)
        local falloff = tonumber(glow.gui2GlowFalloff)
        if falloff == nil then falloff = 0.18 end
        for index = 1, lineCount do
            local line = EnsurePixelGlowLine(glow, index)
            local progress = lineCount > 1 and ((index - 1) / (lineCount - 1)) or 0
            local lineAlpha = alpha * math_max(0, 1 - (progress * falloff))
            if line.parts then
                for _, texture in ipairs(line.parts) do
                    if texture.SetColorTexture then
                        texture:SetColorTexture(r, g2, b2, lineAlpha)
                    end
                end
            end
        end
    elseif UsesNativeGlow(glow.gui2GlowStyle) then
        if glow.gui2GlowStyle == "button" and glow.gui2ButtonGlow then
            ApplyButtonGlowColor(glow.gui2ButtonGlow, r, g2, b2, alpha)
        end
        if glow.gui2AutoCastFrame and glow.gui2AutoCastFrame.textures then
            for _, texture in ipairs(glow.gui2AutoCastFrame.textures) do
                if texture.SetVertexColor then
                    texture:SetVertexColor(r, g2, b2, 1)
                end
            end
        end
        if glow.gui2ProcFrame then
            local procFrame = glow.gui2ProcFrame
            if procFrame.ProcLoopFlipbook and procFrame.ProcLoopFlipbook.SetVertexColor then
                procFrame.ProcLoopFlipbook:SetVertexColor(r, g2, b2, alpha)
            end
            if procFrame.ProcStartFlipbook and procFrame.ProcStartFlipbook.SetVertexColor then
                procFrame.ProcStartFlipbook:SetVertexColor(r, g2, b2, alpha)
            end
        end
        if glow.gui2ProcFallback and glow.gui2ProcFallback.Texture and glow.gui2ProcFallback.Texture.SetVertexColor then
            glow.gui2ProcFallback.Texture:SetVertexColor(r, g2, b2, alpha)
        end
    elseif glow.gui2GlowStyle == "pulse" and glow.gui2PulseFrame and glow.gui2PulseFrame.SetBackdropBorderColor then
        glow.gui2PulseFrame:SetBackdropBorderColor(r, g2, b2, alpha)
    elseif glow.SetBackdropBorderColor then
        glow:SetBackdropBorderColor(r, g2, b2, alpha)
    end
end

local function ApplyGlowStyle(glow)
    if not glow or not glow.gui2GlowTarget then return end

    local target = glow.gui2GlowTarget
    local style = NormalizeGlowStyle(glow.gui2GlowStyle)
    glow.gui2GlowStyle = style
    if glow.SetFrameLevel and target.GetFrameLevel then
        local targetLevel = target:GetFrameLevel() or 0
        if UsesNativeGlow(style) then
            glow:SetFrameLevel(targetLevel + 4)
        elseif UsesPixelGlowSegments(style) then
            glow:SetFrameLevel(targetLevel + 3)
        else
            glow:SetFrameLevel(math_max(targetLevel - 1, 0))
        end
    end

    if style == "none" then
        HidePixelGlowLines(glow)
        HideNativeGlow(glow)
        HidePulseGlow(glow)
        SetGlowTargetPoints(glow, target, 0)
        if glow.SetBackdrop then
            glow:SetBackdrop(nil)
        end
        RefreshGlowAnimation(glow)
        return
    end

    if UsesPixelGlowSegments(style) then
        HidePulseGlow(glow)
        SetGlowTargetPoints(glow, target, 0)
        if glow.SetBackdrop then
            glow:SetBackdrop(nil)
        end
        UpdatePixelGlowLayout(glow)
        ApplyGlowColor(glow)
        RefreshGlowAnimation(glow)
        return
    end

    HidePixelGlowLines(glow)

    if UsesNativeGlow(style) then
        HidePulseGlow(glow)
        if glow.SetBackdrop then
            glow:SetBackdrop(nil)
        end
        SetGlowTargetPoints(glow, target, ResolveGlowOutset(glow, style))
        ActivateNativeGlow(glow, style)
        ApplyGlowColor(glow)
        RefreshGlowAnimation(glow)
        return
    end

    HideNativeGlow(glow)

    if style == "pulse" then
        if glow.SetBackdrop then
            glow:SetBackdrop(nil)
        end
        SetGlowTargetPoints(glow, target, ResolveGlowOutset(glow, style))
        ApplyPulseGlowLayout(glow)
        ApplyGlowColor(glow)
        RefreshGlowAnimation(glow)
        return
    end

    HidePulseGlow(glow)
    local size = ResolveGlowEdgeSize(glow, style)
    SetGlowTargetPoints(glow, target, ResolveGlowOutset(glow, style))
    glow:SetBackdrop({
        edgeFile = Assets:Core("images\\GlowTex.tga"),
        edgeSize = size,
        insets = { left = size, right = size, top = size, bottom = size },
    })
    ApplyGlowColor(glow)
    RefreshGlowAnimation(glow)
end

function GUI2:CreateGlow(frame, opts)
    if not frame then return nil end
    opts = opts or {}
    if frame.gui2Glow then
        frame.gui2Glow:SetGlowParams(opts)
        return frame.gui2Glow
    end

    local glow = CreateFrame("Frame", opts.name, frame, "BackdropTemplate")
    glow.gui2GlowTarget = frame
    glow:EnableMouse(false)
    if glow.SetFrameLevel and frame.GetFrameLevel then
        glow:SetFrameLevel(math_max((frame:GetFrameLevel() or 0) - 1, 0))
    end

    glow.SetGlowColor = function(object, colorKey, g, b, a)
        local r, g2, b2, a2, resolvedKey = ResolveColor(GUI2, colorKey or object.gui2ColorKey, g, b, a, "color.border.accent")
        object.gui2ColorKey = resolvedKey or (type(colorKey) == "string" and colorKey or nil)
        object.gui2ColorR = resolvedKey and nil or r
        object.gui2ColorG = resolvedKey and nil or g2
        object.gui2ColorB = resolvedKey and nil or b2
        object.gui2ColorA = resolvedKey and nil or a2
        ApplyGlowColor(object)
    end

    glow.SetGlowShown = function(object, shown)
        local currentlyShown = object.IsShown and object:IsShown()
        if shown then
            if not currentlyShown then
                object:Show()
                RefreshGlowAnimation(object)
            end
        else
            if currentlyShown then
                object:Hide()
                RefreshGlowAnimation(object)
            end
        end
    end

    glow.SetGlowParams = function(object, params)
        params = type(params) == "table" and params or {}
        if params.style ~= nil then
            object.gui2GlowStyle = NormalizeGlowStyle(params.style)
        elseif not object.gui2GlowStyle then
            object.gui2GlowStyle = "soft"
        end
        if params.size ~= nil then object.gui2GlowSize = ClampGlowSize(params.size) end
        if params.sizeKey ~= nil then object.gui2GlowSizeKey = params.sizeKey end
        if params.lines ~= nil then
            object.gui2GlowLines = ClampGlowLines(params.lines)
        elseif object.gui2GlowLines == nil then
            object.gui2GlowLines = GetDefaultGlowLines(object.gui2GlowStyle)
        end
        if params.thickness ~= nil then object.gui2GlowThickness = ClampGlowThickness(params.thickness) end
        if params.length ~= nil then object.gui2GlowLength = ClampGlowLength(params.length) end
        if params.speed ~= nil then object.gui2GlowSpeed = ClampGlowSpeed(params.speed) end
        if params.phase ~= nil then object.gui2GlowPhase = NormalizeGlowPhase(params.phase) end
        if params.gap ~= nil then object.gui2GlowGap = tonumber(params.gap) or object.gui2GlowGap end
        if params.offset ~= nil then object.gui2GlowOffset = tonumber(params.offset) or object.gui2GlowOffset end
        if params.offsetX ~= nil then object.gui2GlowOffsetX = ClampGlowExpansion(params.offsetX) end
        if params.offsetY ~= nil then object.gui2GlowOffsetY = ClampGlowExpansion(params.offsetY) end
        if params.xOffset ~= nil then object.gui2GlowOffsetX = ClampGlowExpansion(params.xOffset) end
        if params.yOffset ~= nil then object.gui2GlowOffsetY = ClampGlowExpansion(params.yOffset) end
        if params.alpha ~= nil then object.gui2GlowAlpha = ClampGlowUnit(params.alpha, object.gui2GlowAlpha or 1) end
        if params.falloff ~= nil then object.gui2GlowFalloff = ClampGlowUnit(params.falloff, object.gui2GlowFalloff or 0.18) end

        object.gui2GlowLines = ClampGlowLines(object.gui2GlowLines or GetDefaultGlowLines(object.gui2GlowStyle))
        object.gui2GlowSize = ClampGlowSize(object.gui2GlowSize)
        object.gui2GlowThickness = ClampGlowThickness(object.gui2GlowThickness)
        object.gui2GlowLength = ClampGlowLength(object.gui2GlowLength)
        object.gui2GlowSpeed = ClampGlowSpeed(object.gui2GlowSpeed)
        object.gui2GlowPhase = NormalizeGlowPhase(object.gui2GlowPhase)
        object.gui2GlowGap = tonumber(object.gui2GlowGap) or 0
        object.gui2GlowOffset = tonumber(object.gui2GlowOffset) or 0
        object.gui2GlowOffsetX = ClampGlowExpansion(object.gui2GlowOffsetX)
        object.gui2GlowOffsetY = ClampGlowExpansion(object.gui2GlowOffsetY)
        if object.gui2GlowAlpha == nil then object.gui2GlowAlpha = 1 end
        if object.gui2GlowFalloff == nil then object.gui2GlowFalloff = 0.18 end

        if params.colorKey ~= nil or params.color ~= nil then
            object:SetGlowColor(params.colorKey or params.color)
        else
            ApplyGlowColor(object)
        end
        ApplyGlowStyle(object)
    end

    glow.SetGlowStyle = function(object, style)
        object:SetGlowParams({ style = style })
    end

    glow.RefreshTheme = function(object)
        ApplyGlowStyle(object)
    end
    glow.UpdateGUI2PixelLayout = UpdatePixelGlowLayout
    glow.UpdatePixelScale = UpdatePixelGlowLayout

    frame.gui2Glow = glow
    frame.glow = glow
    table_insert(self.PixelObjects, glow)
    if not glow.gui2PixelRefreshHooks then
        glow.gui2PixelRefreshHooks = true
        HookPixelRefresh(glow, "OnShow")
        HookPixelRefresh(glow, "OnSizeChanged")
    end
    self:RegisterThemeObject(glow)

    glow:SetGlowColor(opts.colorKey or opts.color or "color.border.accent")
    glow:SetGlowParams(opts)
    if opts.hidden ~= false then
        glow:SetGlowShown(false)
    else
        glow:SetGlowShown(true)
    end
    QueuePixelObjectRefresh(glow)
    return glow
end

function GUI2:CreatePanel(parent, opts)
    opts = opts or {}
    local frame = self:CreateFrame(parent, {
        type = "Frame",
        name = opts.name,
        template = opts.template or "BackdropTemplate",
        width = opts.width,
        height = opts.height,
        radiusKey = opts.radiusKey or "layout.radius.panel",
        nativeFrameBorder = opts.nativeFrameBorder,
        nativeFrameBorderStyle = opts.nativeFrameBorderStyle,
        nativeFrameBorderLayout = opts.nativeFrameBorderLayout,
    })
    self:ApplyBackdrop(frame, opts.surface or "color.surface.panel")
    self:CreateBorder(frame, opts.border or "color.border.default")
    if opts.shadow then
        self:CreateShadow(frame, opts.shadowKey)
    end
    frame.gui2Surface = opts.surface or "color.surface.panel"
    frame.RefreshTheme = function(object)
        GUI2:RefreshPrimitive(object)
    end
    self:RegisterThemeObject(frame)
    return frame
end

function GUI2:CreateText(parent, text, sizeKey, colorKey, justifyH)
    if type(text) == "table" then
        local opts = text
        text = opts.text
        sizeKey = opts.sizeKey or opts.fontSizeKey or opts.size
        colorKey = opts.colorKey or opts.color
        justifyH = opts.justifyH or opts.justify
    elseif type(sizeKey) == "number" then
        if IsJustify(colorKey) then
            justifyH = colorKey
            colorKey = nil
        end
    end

    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    local size = type(sizeKey) == "number" and sizeKey or self:GetMetric(sizeKey or "font.size.md", 13)
    local font = self:GetFont("font.family.body")
    if self.Fonts and type(sizeKey) == "number" then
        font = self.Fonts.normal or font
    end
    fs:SetFont(font, size)
    fs.gui2ColorKey = (type(colorKey) == "string" and not IsJustify(colorKey)) and colorKey or "color.text.primary"
    fs:SetTextColor(self:GetColor(fs.gui2ColorKey))
    fs:SetShadowColor(0, 0, 0, 0.6)
    fs:SetShadowOffset(1, -1)
    if justifyH then
        fs:SetJustifyH(justifyH)
    end
    if text then
        fs:SetText(text)
    end
    self:RegisterThemeObject(fs)
    return fs
end

function GUI2:CreateTexture(parent, paintKey, widthOrLayer, height, layer, isAtlas)
    local opts
    if type(paintKey) == "table" then
        opts = paintKey
        paintKey = opts.paint or opts.paintKey or opts.colorKey
        widthOrLayer = opts.width
        height = opts.height
        layer = opts.layer
        isAtlas = opts.isAtlas
    elseif type(widthOrLayer) == "string" then
        layer = widthOrLayer
        widthOrLayer = nil
    end

    local texture = parent:CreateTexture(opts and opts.name or nil, layer or "ARTWORK", opts and opts.template or nil, opts and opts.subLevel or opts and opts.sublevel or nil)
    local source = opts and (opts.texture or opts.source)
    local atlas = opts and opts.atlas

    local hasPaint = paintKey ~= nil

    if atlas and texture.SetAtlas then
        texture:SetAtlas(atlas)
    elseif source or LooksLikeTexturePath(paintKey) or isAtlas then
        local texturePath = source or paintKey
        if isAtlas and texture.SetAtlas then
            texture:SetAtlas(texturePath)
        else
            texture:SetTexture(texturePath)
        end
    elseif hasPaint then
        texture.gui2PaintKey = paintKey or "color.surface.panel"
        ApplyPaint(texture, texture.gui2PaintKey)
        self:RegisterThemeObject(texture)
    end

    if widthOrLayer and height then
        texture:SetSize(widthOrLayer, height)
    elseif widthOrLayer then
        texture:SetWidth(widthOrLayer)
    elseif height then
        texture:SetHeight(height)
    end

    return texture
end

function GUI2:SetIconTexture(texture, source, fallback)
    if not texture then return end
    local iconSource = source
    if iconSource == nil then
        iconSource = fallback
    end
    if iconSource == nil then
        iconSource = DEFAULT_ICON
    end
    texture:SetTexture(iconSource)
    return texture
end

function GUI2:ApplyTexturePixelPolicy(texture, policy)
    if not texture or policy == false then return texture end
    local snapToPixelGrid = false
    local texelSnappingBias = 0
    if type(policy) == "table" then
        if policy.snapToPixelGrid ~= nil then
            snapToPixelGrid = policy.snapToPixelGrid and true or false
        end
        if policy.texelSnappingBias ~= nil then
            texelSnappingBias = policy.texelSnappingBias
        end
    end
    if texture.SetTexelSnappingBias then
        texture:SetTexelSnappingBias(texelSnappingBias)
    end
    if texture.SetSnapToPixelGrid then
        texture:SetSnapToPixelGrid(snapToPixelGrid)
    end
    texture.gui2PixelPolicy = policy or true
    return texture
end

function GUI2:CreateIcon(parent, opts)
    if not parent then return end
    if type(opts) ~= "table" then
        opts = { icon = opts }
    else
        opts = opts or {}
    end

    local icon = parent:CreateTexture(opts.name, opts.layer or "ARTWORK", opts.template, opts.subLevel or opts.sublevel)
    self:ApplyTexturePixelPolicy(icon, opts.pixelPolicy)
    local useAtlas = opts.atlas and icon.SetAtlas
    if useAtlas then
        icon:SetAtlas(opts.atlas)
    else
        self:SetIconTexture(icon, opts.icon or opts.texture or opts.source, opts.fallbackIcon or DEFAULT_ICON)
    end

    if opts.texCoords then
        icon:SetTexCoord(unpack(opts.texCoords))
    elseif opts.crop ~= false and not useAtlas then
        icon:SetTexCoord(unpack(DEFAULT_ICON_TEXCOORDS))
    elseif not useAtlas then
        icon:SetTexCoord(0, 1, 0, 1)
    end

    if opts.fillParent then
        local padding = opts.padding or 0
        if padding == 0 then
            icon:SetAllPoints(parent)
        else
            icon:SetPoint("TOPLEFT", padding, -padding)
            icon:SetPoint("BOTTOMRIGHT", -padding, padding)
        end
    else
        local width = opts.width or opts.size
        local height = opts.height or opts.size
        if not opts.allowTiny then
            if width then width = math_max(width, MIN_ICON_SIZE) end
            if height then height = math_max(height, MIN_ICON_SIZE) end
        end
        if width and height then
            icon:SetSize(width, height)
        elseif width then
            icon:SetWidth(width)
        elseif height then
            icon:SetHeight(height)
        end
    end

    if opts.alpha ~= nil then
        icon:SetAlpha(opts.alpha)
    end
    if opts.desaturated ~= nil and icon.SetDesaturated then
        icon:SetDesaturated(opts.desaturated and true or false)
    end
    if opts.vertexColor then
        icon:SetVertexColor(unpack(opts.vertexColor))
    end
    return icon
end

local function ResolveGlyphTexture(opts)
    local key = opts.glyph or opts.name or opts.textureKey
    return opts.icon or opts.texture or opts.source or GLYPH_TEXTURES[key] or GLYPH_TEXTURES.dropdownDown
end

function GUI2:SetGlyphColor(glyph, colorKey)
    if not glyph then return end
    glyph.gui2ColorKey = colorKey or glyph.gui2ColorKey or "color.text.accent"
    if glyph.icon and glyph.icon.SetVertexColor then
        glyph.icon:SetVertexColor(self:GetColor(glyph.gui2ColorKey))
    end
    self:RegisterThemeObject(glyph)
    return glyph
end

function GUI2:CreateGlyph(parent, opts)
    if not parent then return end
    if type(opts) ~= "table" then
        opts = { glyph = opts }
    else
        opts = opts or {}
    end
    local size = math_max(opts.size or MIN_ICON_SIZE, MIN_ICON_SIZE)
    local glyph = self:CreateFrame(parent, {
        name = opts.name,
        width = size,
        height = size,
    })
    glyph.gui2Component = "Glyph"
    glyph.gui2Glyph = opts.glyph or "dropdownDown"
    glyph.gui2ColorKey = opts.colorKey or opts.color or "color.text.accent"
    glyph.icon = self:CreateIcon(glyph, {
        icon = ResolveGlyphTexture(opts),
        fallbackIcon = ResolveGlyphTexture(opts),
        crop = false,
        fillParent = true,
        pixelPolicy = opts.pixelPolicy,
    })
    glyph.SetColorKey = function(frame, colorKey)
        GUI2:SetGlyphColor(frame, colorKey)
    end
    glyph.RefreshTheme = function(frame)
        GUI2:SetGlyphColor(frame, frame.gui2ColorKey)
    end
    self:SetGlyphColor(glyph, glyph.gui2ColorKey)
    return glyph
end

function GUI2:CreateBackdrop(frame, opts)
    if not frame then return end
    local surfaceKey = "color.surface.window"
    local borderKey = "color.border.default"
    local shadow = true
    local shadowKey
    local nativeFrameBorder = false
    local nativeFrameBorderStyle
    local nativeFrameBorderLayout
    if type(opts) == "table" then
        surfaceKey = opts.surface or surfaceKey
        borderKey = opts.border or borderKey
        shadow = opts.shadow ~= false
        shadowKey = opts.shadowKey
        nativeFrameBorder = opts.nativeFrameBorder == true
        nativeFrameBorderStyle = opts.nativeFrameBorderStyle
        nativeFrameBorderLayout = opts.nativeFrameBorderLayout
    else
        shadow = opts ~= false
    end
    if not frame.backdrop then
        frame.backdrop = self:CreateFrame(frame, {
            template = "BackdropTemplate",
            allPoints = true,
            nativeFrameBorder = nativeFrameBorder,
            nativeFrameBorderStyle = nativeFrameBorderStyle,
            nativeFrameBorderLayout = nativeFrameBorderLayout,
        })
        frame.backdrop:SetFrameLevel(frame:GetFrameLevel() > 0 and frame:GetFrameLevel() - 1 or 0)
    else
        frame.backdrop.gui2NativeFrameBorder = nativeFrameBorder
        frame.backdrop.gui2NativeFrameBorderStyle = nativeFrameBorderStyle
        frame.backdrop.gui2NativeFrameBorderLayout = nativeFrameBorderLayout
    end
    self:ApplyBackdrop(frame.backdrop, surfaceKey)
    self:CreateBorder(frame.backdrop, borderKey)
    self:SetBorderColor(frame.backdrop, borderKey)
    if shadow then
        self:CreateShadow(frame, shadowKey)
    end
    return frame.backdrop
end

local BUTTON_STYLES = {
    successFilled = {
        surface = { 0.0, 0.5, 0.0, 1 },
        hoverSurface = { 0.05, 0.65, 0.08, 1 },
        pressedSurface = { 0.0, 0.34, 0.0, 1 },
        border = { 0.2, 0.85, 0.2, 1 },
        hoverBorder = { 0.2, 0.85, 0.2, 1 },
        pressedBorder = { 0.12, 0.6, 0.12, 1 },
        text = "color.text.accent",
        hoverText = "color.text.accent",
        pressedText = "color.text.accent",
    },
    grayFilled = {
        surface = { 0.3, 0.3, 0.3, 1 },
        hoverSurface = { 0.4, 0.4, 0.4, 1 },
        pressedSurface = { 0.2, 0.2, 0.2, 1 },
        border = { 0.5, 0.5, 0.5, 1 },
        hoverBorder = { 0.62, 0.62, 0.62, 1 },
        pressedBorder = { 0.38, 0.38, 0.38, 1 },
        text = "color.text.accent",
        hoverText = "color.text.accent",
        pressedText = "color.text.accent",
    },
}

local BUTTON_STYLE_FIELDS = {
    "gui2SurfaceToken",
    "gui2HoverSurfaceToken",
    "gui2PressedSurfaceToken",
    "gui2BorderToken",
    "gui2HoverBorderToken",
    "gui2PressedBorderToken",
    "gui2TextColorKey",
    "gui2HoverTextColorKey",
    "gui2PressedTextColorKey",
}

local function CaptureButtonStyleDefaults(button)
    if not button or button.gui2ButtonStyleDefaults then return end
    local defaults = {}
    for _, field in ipairs(BUTTON_STYLE_FIELDS) do
        defaults[field] = button[field]
    end
    button.gui2ButtonStyleDefaults = defaults
end

local function RestoreButtonStyleDefaults(button)
    if not button then return end
    local defaults = button.gui2ButtonStyleDefaults
    if defaults then
        for _, field in ipairs(BUTTON_STYLE_FIELDS) do
            button[field] = defaults[field]
        end
    else
        for _, field in ipairs(BUTTON_STYLE_FIELDS) do
            button[field] = nil
        end
    end
    button.gui2ButtonStyleName = nil
end

function GUI2:ApplyButtonStyle(button, styleName)
    if not button then return button end

    local style = styleName and BUTTON_STYLES[styleName] or nil
    if not style then
        RestoreButtonStyleDefaults(button)
    else
        CaptureButtonStyleDefaults(button)
        button.gui2ButtonStyleName = styleName
        button.gui2SurfaceToken = style.surface
        button.gui2HoverSurfaceToken = style.hoverSurface or style.surface
        button.gui2PressedSurfaceToken = style.pressedSurface or style.surface
        button.gui2BorderToken = style.border
        button.gui2HoverBorderToken = style.hoverBorder or style.border
        button.gui2PressedBorderToken = style.pressedBorder or style.border
        button.gui2TextColorKey = style.text
        button.gui2HoverTextColorKey = style.hoverText or style.text
        button.gui2PressedTextColorKey = style.pressedText or style.text
    end

    if button.RefreshTheme then
        button:RefreshTheme()
    end
    return button
end

local function GetButtonStateTokens(button, state)
    local surface = button.gui2SurfaceToken or "color.control.bg"
    local border = button.gui2BorderToken or "color.border.default"
    local text = button.gui2TextColorKey or "color.text.accent"

    if state == "hover" then
        surface = button.gui2HoverSurfaceToken or "color.control.hover"
        border = button.gui2HoverBorderToken or "color.border.accent"
        text = button.gui2HoverTextColorKey or "color.text.primary"
    elseif state == "pressed" then
        surface = button.gui2PressedSurfaceToken or "color.control.pressed"
        border = button.gui2PressedBorderToken or "color.border.strong"
        text = button.gui2PressedTextColorKey or "color.text.primary"
    elseif state == "selected" then
        surface = button.gui2SelectedSurfaceToken or "color.control.active"
        border = button.gui2SelectedBorderToken or "color.border.accent"
        text = button.gui2SelectedTextColorKey or "color.text.accent"
    elseif state == "locked" then
        surface = button.gui2LockedSurfaceToken or "color.control.locked"
        border = button.gui2LockedBorderToken or "color.border.locked"
        text = button.gui2LockedTextColorKey or "color.text.locked"
    elseif state == "disabled" then
        surface = "color.control.disabled"
        border = "color.border.subtle"
        text = "color.text.disabled"
    end

    return surface, border, text
end

local function GetButtonColor(value)
    if type(value) == "table" then
        local color = value.type == "solid" and value.value or value
        return color[1] or 1, color[2] or 1, color[3] or 1, color[4] == nil and 1 or color[4]
    end
    return GUI2:GetColor(value)
end

local function GetButtonRestingState(button)
    if button and button.gui2Locked then
        return "locked"
    end
    if button and button.gui2Selected then
        return "selected"
    end
    return "normal"
end

local function ApplyButtonTheme(button, state)
    if not button then return end
    state = state or button.gui2State or "normal"
    button.gui2State = state

    local surface, border, text = GetButtonStateTokens(button, state)
    button.gui2Surface = surface
    if button.SetBackdropColor then
        button:SetBackdropColor(GetButtonColor(surface))
    end
    GUI2:SetBorderColor(button, border)

    if button.text then
        if button.gui2CustomTextColor and state == "normal" then
            button.text:SetTextColor(unpack(button.gui2CustomTextColor))
        else
            button.text:SetTextColor(GetButtonColor(text))
            button.text.gui2ColorKey = type(text) == "string" and text or nil
        end
    end
    if button.icon and button.icon.SetVertexColor and not button.gui2PreserveIconColor then
        button.icon:SetVertexColor(GetButtonColor(text))
    end
end

local function ApplyButtonCompatibility(button)
    if not button or button.gui2ButtonCompat then return button end
    button.gui2ButtonCompat = true

    button.SetState = function(self, state)
        self.gui2Disabled = state == "disabled"
        self.gui2Locked = state == "locked"
        self.gui2Selected = not self.gui2Locked and state == "selected"
        ApplyButtonTheme(self, state)
    end
    button.SetSelected = function(self, selected)
        self.gui2Locked = false
        self.gui2Selected = selected and true or false
        ApplyButtonTheme(self, self.gui2Selected and "selected" or "normal")
    end
    button.SetText = function(self, value)
        if self.text then
            self.text:SetText(value or "")
        end
    end
    button.GetFontString = function(self)
        return self.text
    end
    button.SetTextColor = function(self, r, g, b, a)
        self.gui2CustomTextColor = { r, g, b, a == nil and 1 or a }
        if self.text then
            self.text:SetTextColor(r, g, b, a == nil and 1 or a)
        end
    end
    button.RefreshTheme = function(self)
        ApplyButtonTheme(self, self.gui2Disabled and "disabled" or GetButtonRestingState(self))
    end

    return button
end

local function WireButtonScripts(button, preserveTextPoint)
    if not button or button.gui2ButtonScripts then return end
    button.gui2ButtonScripts = true

    button:SetScript("OnEnter", function(self)
        if self.gui2Disabled then return end
        if self.gui2Locked then
            ApplyButtonTheme(self, "locked")
            return
        end
        ApplyButtonTheme(self, "hover")
    end)
    button:SetScript("OnLeave", function(self)
        if self.gui2Disabled then return end
        if self.text and not preserveTextPoint then
            self.text:SetPoint("CENTER", 0, 0)
        end
        ApplyButtonTheme(self, GetButtonRestingState(self))
    end)
    button:SetScript("OnMouseDown", function(self)
        if self.gui2Disabled then return end
        ApplyButtonTheme(self, "pressed")
        if self.text and not preserveTextPoint then
            self.text:SetPoint("CENTER", 1, -1)
        end
    end)
    button:SetScript("OnMouseUp", function(self)
        if self.gui2Disabled then return end
        if self.text and not preserveTextPoint then
            self.text:SetPoint("CENTER", 0, 0)
        end
        ApplyButtonTheme(self, (self:IsMouseOver() and not self.gui2Locked) and "hover" or GetButtonRestingState(self))
    end)
end

local function SkinButton(button, opts)
    opts = opts or {}
    if not button then return end
    if not button.SetBackdrop then
        return button
    end

    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    button.gui2SurfaceToken = opts.surface or button.gui2SurfaceToken or "color.control.bg"
    button.gui2BorderToken = opts.border or button.gui2BorderToken or "color.border.default"
    button.gui2TextColorKey = opts.textColor or button.gui2TextColorKey or "color.text.accent"
    button.gui2HoverTextColorKey = opts.hoverTextColor or button.gui2HoverTextColorKey or "color.text.primary"
    if opts.border ~= false then
        GUI2:CreateBorder(button, button.gui2BorderToken)
    end
    ApplyButtonCompatibility(button)
    if not opts.noScripts then
        WireButtonScripts(button, opts.preserveTextPoint)
    end
    GUI2:RegisterThemeObject(button)
    button:RefreshTheme()
    return button
end

function GUI2:CreateButton(parent, text, width, height)
    if not parent then return end

    local button
    if self.Form and self.Form.CreateButton then
        button = self.Form:CreateButton(parent, {
            text = text or "",
            width = width or 100,
            height = height or 24,
        })
    else
        button = self:CreateButtonFrame(parent, {
            template = "BackdropTemplate",
            width = width or 100,
            height = height or 24,
        })
        button.text = self:CreateText(button, text or "", "font.size.md", "color.text.accent")
        button.text:SetPoint("CENTER")
    end

    button:SetSize(width or button:GetWidth() or 100, height or button:GetHeight() or 24)
    SkinButton(button, { textColor = "color.text.accent" })
    return button
end

function GUI2:CreateIconButton(parent, opts)
    if not parent then return end
    opts = opts or {}

    local size = math_max(opts.size or opts.height or opts.width or self:GetMetric("layout.size.icon", 20), MIN_ICON_BUTTON_SIZE)
    local width = math_max(opts.width or size, MIN_ICON_BUTTON_SIZE)
    local height = math_max(opts.height or size, MIN_ICON_BUTTON_SIZE)
    local button = self:CreateButtonFrame(parent, {
        name = opts.name,
        template = opts.template or "BackdropTemplate",
        width = width,
        height = height,
        radiusKey = opts.radiusKey or "layout.radius.icon",
        clicks = opts.clicks,
        onClick = opts.onClick,
    })
    button.gui2Component = "IconButton"
    button.gui2PreserveIconColor = opts.preserveIconColor ~= false
    SkinButton(button, {
        surface = opts.surface or "color.control.bg",
        border = opts.border or "color.border.subtle",
        textColor = opts.iconColor or "color.text.secondary",
        hoverTextColor = opts.hoverIconColor or "color.text.primary",
        preserveTextPoint = true,
    })
    button.gui2HoverSurfaceToken = opts.hoverSurface or button.gui2HoverSurfaceToken
    button.gui2HoverBorderToken = opts.hoverBorder or button.gui2HoverBorderToken
    button.gui2PressedSurfaceToken = opts.pressedSurface or button.gui2PressedSurfaceToken
    button.gui2PressedBorderToken = opts.pressedBorder or button.gui2PressedBorderToken
    button.gui2SelectedSurfaceToken = opts.selectedSurface or button.gui2SelectedSurfaceToken
    button.gui2SelectedBorderToken = opts.selectedBorder or button.gui2SelectedBorderToken

    local icon = self:CreateIcon(button, {
        icon = opts.icon or opts.texture,
        fallbackIcon = opts.fallbackIcon,
        texCoords = opts.texCoords,
        crop = opts.crop,
        layer = opts.layer,
        fillParent = true,
        padding = opts.padding or 0,
    })
    button.icon = icon

    local function SetIconPadding(frame, padding)
        frame.gui2IconPadding = padding or 0
        frame.icon:ClearAllPoints()
        if frame.gui2IconPadding == 0 then
            frame.icon:SetAllPoints(frame)
        else
            frame.icon:SetPoint("TOPLEFT", frame.gui2IconPadding, -frame.gui2IconPadding)
            frame.icon:SetPoint("BOTTOMRIGHT", -frame.gui2IconPadding, frame.gui2IconPadding)
        end
    end

    button.SetIcon = function(frame, texture)
        GUI2:SetIconTexture(frame.icon, texture, opts.fallbackIcon)
    end
    button.SetIconPadding = SetIconPadding
    SetIconPadding(button, opts.padding or 0)

    if opts.tooltip and button.HookScript then
        button:HookScript("OnEnter", function(frame)
            if frame.gui2Disabled then return end
            GameTooltip:SetOwner(frame, opts.tooltipAnchor or "ANCHOR_RIGHT")
            GameTooltip:SetText(opts.tooltip)
            GameTooltip:Show()
        end)
        button:HookScript("OnLeave", function()
            YUI.HideGameTooltip()
        end)
    end

    button:RefreshTheme()
    return button
end

function GUI2:CreateBlizzardIconButton(parent, opts)
    if not parent then return end
    opts = opts or {}

    local size = opts.size or opts.width or opts.height or 24
    local button = CreateFrame("Button", opts.name, parent)
    button:SetSize(size, size)
    if button.RegisterForClicks then button:RegisterForClicks(opts.clicks or "AnyUp") end

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    button.icon = icon

    local atlas = opts.atlas
    if atlas == nil and not opts.texture and not opts.icon and YUI and YUI.IsRetail then
        atlas = "mechagon-projects"
    end

    if atlas and icon.SetAtlas then
        icon:SetAtlas(atlas)
    else
        icon:SetTexture(opts.texture or opts.icon or "Interface\\Icons\\INV_Misc_Gear_01")
        if opts.texCoords then
            icon:SetTexCoord(unpack(opts.texCoords))
        elseif opts.crop ~= false then
            icon:SetTexCoord(unpack(DEFAULT_ICON_TEXCOORDS))
        end
    end

    local normalColor = opts.normalColor or { 0.8, 0.8, 0.8, 1 }
    local hoverColor = opts.hoverColor or { 1, 0.82, 0, 1 }
    icon:SetVertexColor(unpack(normalColor))

    button:SetScript("OnEnter", function(frame)
        if frame.icon then frame.icon:SetVertexColor(unpack(hoverColor)) end
        if opts.tooltip then
            GameTooltip:SetOwner(frame, opts.tooltipAnchor or "ANCHOR_TOP")
            GameTooltip:SetText(opts.tooltip)
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function(frame)
        if frame.icon then frame.icon:SetVertexColor(unpack(normalColor)) end
        YUI.HideGameTooltip()
    end)
    if opts.onClick then
        button:SetScript("OnClick", function(frame, ...)
            YUI.HideGameTooltip()
            opts.onClick(frame, ...)
        end)
    end

    return button
end

local function ApplyIconSlotSurface(slot, surfaceKey)
    if slot.SetBackdropColor then
        slot:SetBackdropColor(GUI2:GetColor(surfaceKey))
    elseif slot.gui2Bg then
        slot.gui2Bg:SetColorTexture(GUI2:GetColor(surfaceKey))
    end
    slot.gui2Surface = surfaceKey
end

local function ApplyIconSlotState(slot, state)
    if not slot then return end
    state = state or slot.gui2State or "normal"
    slot.gui2State = state

    local surface = "color.surface.sunken"
    local border = "color.border.default"
    local iconAlpha = 1
    local textColor = "color.text.primary"

    if state == "selected" or state == "active" then
        surface = "color.control.active"
        border = "color.border.accent"
        textColor = "color.text.accent"
    elseif state == "hover" then
        surface = "color.control.hover"
        border = "color.border.accent"
    elseif state == "disabled" then
        surface = "color.control.disabled"
        border = "color.border.subtle"
        iconAlpha = 0.35
        textColor = "color.text.disabled"
    elseif state == "warning" then
        border = "color.state.warning"
        textColor = "color.state.warning"
    elseif state == "danger" then
        border = "color.state.error"
        textColor = "color.state.error"
    end

    if slot.gui2Variant ~= "bare" then
        ApplyIconSlotSurface(slot, surface)
        GUI2:SetBorderColor(slot, border)
    end
    if slot.icon then
        slot.icon:SetAlpha(iconAlpha)
    end
    if slot.count then
        slot.count:SetTextColor(GUI2:GetColor(textColor))
    end
    if slot.disabledOverlay then
        if state == "disabled" then
            slot.disabledOverlay:Show()
        else
            slot.disabledOverlay:Hide()
        end
    end
end

function GUI2:CreateIconSlot(parent, opts)
    if not parent then return end
    opts = opts or {}
    local size = math_max(opts.size or self:GetMetric("layout.size.icon", 22), MIN_ICON_SIZE)
    local clickable = opts.onClick ~= nil
    local variant = opts.variant or "surface"
    local slot

    if variant == "bare" then
        slot = CreateFrame(clickable and "Button" or "Frame", opts.name, parent)
        slot:SetSize(size, size)
    elseif clickable and self.CreateIconButton then
        local padding = opts.padding
        if padding == nil then
            padding = 0
        end
        slot = self:CreateIconButton(parent, {
            name = opts.name,
            size = size,
            icon = opts.icon or DEFAULT_ICON,
            fallbackIcon = opts.fallbackIcon or DEFAULT_ICON,
            texCoords = opts.texCoords,
            crop = opts.crop,
            padding = padding,
            surface = "color.surface.sunken",
            border = opts.selected and "color.border.accent" or "color.border.default",
            radiusKey = opts.radiusKey or "layout.radius.icon",
            preserveIconColor = true,
        })
    else
        slot = self:CreatePanel(parent, {
            width = size,
            height = size,
            surface = "color.surface.sunken",
            border = opts.selected and "color.border.accent" or "color.border.default",
            radiusKey = opts.radiusKey or "layout.radius.icon",
        })
    end

    slot.gui2Component = "IconSlot"
    slot.gui2Variant = variant
    slot.gui2Shape = opts.shape or (opts.rounded and "rounded" or "square")
    slot.gui2RoundedIntent = slot.gui2Shape ~= "square"
    slot.gui2Selected = opts.selected and true or false
    slot.gui2Animate = opts.animate ~= false and opts.motion ~= false
    slot.gui2MotionOwner = slot

    local padding = opts.padding
    if padding == nil then
        padding = 0
    end
    local icon = slot.icon
    if not icon then
        icon = self:CreateIcon(slot, {
            icon = opts.icon,
            fallbackIcon = opts.fallbackIcon or DEFAULT_ICON,
            texCoords = opts.texCoords,
            crop = opts.crop,
            fillParent = true,
            padding = padding,
        })
        slot.icon = icon
    end
    if icon then
        icon.gui2Animate = slot.gui2Animate
        icon.gui2MotionOwner = slot
    end

    local overlay = slot:CreateTexture(nil, "OVERLAY")
    overlay:SetAllPoints(icon)
    overlay:SetColorTexture(0, 0, 0, 0.48)
    overlay:Hide()
    slot.disabledOverlay = overlay

    if opts.count then
        local count = self:CreateText(slot, tostring(opts.count), "font.size.sm", "color.text.primary", "RIGHT")
        count:SetPoint("BOTTOMRIGHT", -2, 1)
        slot.count = count
    end

    slot.SetIcon = function(frame, texture)
        GUI2:SetIconTexture(frame.icon, texture, opts.fallbackIcon or DEFAULT_ICON)
    end
    slot.SetCount = function(frame, count)
        if not frame.count then
            frame.count = GUI2:CreateText(frame, "", "font.size.sm", "color.text.primary", "RIGHT")
            frame.count:SetPoint("BOTTOMRIGHT", -2, 1)
        end
        frame.count:SetText(count and tostring(count) or "")
    end
    slot.SetState = function(frame, state)
        if state == "selected" or state == "active" then
            frame.gui2Selected = true
        elseif state == "normal" then
            frame.gui2Selected = false
        end
        ApplyIconSlotState(frame, state)
    end
    slot.SetSelected = function(frame, selected)
        frame.gui2Selected = selected and true or false
        ApplyIconSlotState(frame, frame.gui2Selected and "selected" or "normal")
    end
    slot.RefreshTheme = function(frame)
        ApplyIconSlotState(frame, frame.gui2State)
    end
    self:RegisterThemeObject(slot)

    if clickable then
        slot:RegisterForClicks(opts.clicks or "AnyUp")
        slot:SetScript("OnClick", opts.onClick)
        slot:SetScript("OnEnter", function(frame)
            if frame.gui2State == "disabled" then return end
            ApplyIconSlotState(frame, "hover")
        end)
        slot:SetScript("OnLeave", function(frame)
            ApplyIconSlotState(frame, frame.gui2Selected and "selected" or "normal")
        end)
    end

    slot:SetState(opts.disabled and "disabled" or (opts.selected and "selected" or (opts.state or "normal")))
    return slot
end

function GUI2:CreateIconGrid(parent, opts)
    if not parent then return end
    opts = opts or {}
    local items = opts.items or {}
    local columns = opts.columns or 4
    local itemSize = opts.itemSize or 34
    local spacing = opts.spacing or 8
    local padding = opts.padding or 10
    local rows = math_ceil(#items / columns)
    if rows < 1 then rows = 1 end

    local width = opts.width or ((columns * itemSize) + ((columns - 1) * spacing) + (padding * 2))
    local height = opts.height or ((rows * itemSize) + ((rows - 1) * spacing) + (padding * 2))
    local grid = self:CreatePanel(parent, {
        width = width,
        height = height,
        surface = opts.surface or "color.surface.panel",
        border = opts.border or "color.border.default",
    })
    grid.gui2Component = "IconGrid"
    grid.slots = {}

    for i, item in ipairs(items) do
        local slot = self:CreateIconSlot(grid, {
            size = itemSize,
            icon = item.icon,
            fallbackIcon = item.fallbackIcon,
            texCoords = item.texCoords,
            crop = item.crop,
            shape = item.shape,
            rounded = item.rounded,
            variant = item.variant,
            padding = item.padding,
            selected = item.selected,
            disabled = item.disabled,
            count = item.count,
            onClick = item.onClick,
        })
        local row = math_floor((i - 1) / columns)
        local col = (i - 1) % columns
        slot:SetPoint("TOPLEFT", padding + (col * (itemSize + spacing)), -(padding + (row * (itemSize + spacing))))
        grid.slots[i] = slot
    end

    return grid
end

function GUI2:CreateCloseButton(parent, onClick)
    if not parent then return end
    local normalColor = { 0.5, 0.1, 0.1, 1 }
    local hoverColor = { 0.8, 0.2, 0.2, 1 }
    local pressedColor = { 0.4, 0.1, 0.1, 1 }
    local borderColor = { 0, 0, 0, 1 }
    local button = self:CreateButtonFrame(parent, {
        template = "BackdropTemplate",
        width = 16,
        height = 16,
        radiusKey = "layout.radius.control",
    })
    SkinButton(button, {
        surface = normalColor,
        border = borderColor,
        textColor = "color.accent.text",
        hoverTextColor = "color.accent.text",
    })
    button.gui2HoverSurfaceToken = hoverColor
    button.gui2HoverBorderToken = borderColor
    button.gui2PressedSurfaceToken = pressedColor
    button.gui2PressedBorderToken = borderColor
    button:SetScript("OnClick", onClick)
    button:RefreshTheme()
    return button
end

function GUI2:CreateNavButton(parent, text, icon, width, height)
    if not parent then return end

    local buttonHeight = height or 40
    local button = self:CreateButtonFrame(parent, {
        template = "BackdropTemplate",
        width = width or 150,
        height = buttonHeight,
    })
    button.gui2SurfaceToken = "color.surface.nav"
    button.gui2HoverSurfaceToken = "color.control.hover"
    button.gui2TextColorKey = "color.text.primary"
    button.gui2HoverTextColorKey = "color.text.accent"
    SkinButton(button, {
        surface = "color.surface.nav",
        border = false,
        textColor = "color.text.primary",
        preserveTextPoint = true,
    })

    local label = self:CreateText(button, text or "", "font.size.md", "color.text.primary")
    label:SetWordWrap(false)
    button.text = label
    button.gui2FullText = text or ""

    if icon then
        local iconTex = self:CreateIcon(button, {
            icon = icon,
            size = buttonHeight - 14,
        })
        iconTex:SetPoint("LEFT", 15, 0)
        button.icon = iconTex
        button.gui2PreserveIconColor = true

        local iconBg = self:CreateFrame(button, {
            template = "BackdropTemplate",
            allPoints = iconTex,
        })
        iconBg:SetFrameLevel(button:GetFrameLevel())
        button.iconBg = iconBg

        label:SetPoint("LEFT", iconTex, "RIGHT", 15, 0)
        label:SetPoint("RIGHT", -10, 0)
        label:SetJustifyH("LEFT")
    else
        label:SetPoint("LEFT", 8, 0)
        label:SetPoint("RIGHT", -8, 0)
        label:SetJustifyH("CENTER")
    end

    function button:SetText(value)
        self.gui2FullText = value or ""
        if self.text then
            self.text:SetText(self.gui2FullText)
        end
    end

    local function ShowOverflowTooltip(frame)
        if not (GameTooltip and frame and frame.text and frame.gui2FullText and frame.gui2FullText ~= "") then
            return
        end
        local textWidth = frame.text:GetStringWidth() or 0
        local availableWidth = frame.text:GetWidth() or 0
        if availableWidth > 0 and textWidth > availableWidth + 1 then
            GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
            GameTooltip:SetText(frame.gui2FullText, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end

    local hl = self:CreateTexture(button, "color.control.hover", "BACKGROUND")
    hl:SetAllPoints()
    hl:SetAlpha(0.35)
    hl:Hide()
    button.hl = hl

    local sel = self:CreateTexture(button, "color.nav.indicator", "OVERLAY")
    sel:SetWidth(4)
    sel:SetPoint("TOPLEFT", 0, 0)
    sel:SetPoint("BOTTOMLEFT", 0, 0)
    sel:Hide()
    button.sel = sel

    local selBg = self:CreateTexture(button, "color.control.active", "BACKGROUND")
    selBg:SetAllPoints()
    selBg:SetAlpha(0.55)
    selBg:Hide()
    button.selBg = selBg

    button:SetScript("OnEnter", function(frame)
        if frame.hl then frame.hl:Show() end
        ApplyButtonTheme(frame, "hover")
        ShowOverflowTooltip(frame)
    end)
    button:SetScript("OnLeave", function(frame)
        if frame.hl then frame.hl:Hide() end
        ApplyButtonTheme(frame, frame.gui2Selected and "selected" or "normal")
        if GameTooltip and GameTooltip:IsOwned(frame) then
            YUI.HideGameTooltip()
        end
    end)
    button.RefreshTheme = function(frame)
        ApplyButtonTheme(frame, frame.gui2Selected and "selected" or "normal")
        if frame.hl then GUI2:SetTexturePaintKey(frame.hl, "color.control.hover") end
        if frame.sel then GUI2:SetTexturePaintKey(frame.sel, "color.nav.indicator") end
        if frame.selBg then GUI2:SetTexturePaintKey(frame.selBg, "color.control.active") end
    end
    button:RefreshTheme()
    return button
end

function GUI2:SkinSlider(slider)
    if not slider then return end

    if slider.SetBackdrop then
        slider:SetBackdrop(nil)
    end

    if slider.GetNumRegions then
        for i = 1, slider:GetNumRegions() do
            local region = select(i, slider:GetRegions())
            if region and region.GetObjectType and region:GetObjectType() == "Texture" and region ~= slider:GetThumbTexture() then
                region:SetTexture(nil)
                region:SetAlpha(0)
                region:Hide()
            end
        end
    end

    if not slider.gui2Bg then
        local bg = self:CreatePanel(slider, {
            surface = "color.control.track",
            border = "color.border.default",
        })
        bg:SetPoint("TOPLEFT", 0, -5)
        bg:SetPoint("BOTTOMRIGHT", 0, 5)
        bg:SetFrameLevel(math_max(slider:GetFrameLevel() - 1, 0))
        slider.gui2Bg = bg
    end

    local thumb = slider:GetThumbTexture()
    if not thumb then
        thumb = slider:CreateTexture(nil, "ARTWORK")
        slider:SetThumbTexture(thumb)
    end
    thumb:SetTexture("Interface\\Buttons\\WHITE8x8")
    thumb:SetSize(8, 14)
    self:SetTexturePaintKey(thumb, "color.control.thumb")
    slider.gui2Thumb = thumb

    if not slider.gui2SliderScripts then
        slider.gui2SliderScripts = true
        slider:HookScript("OnEnter", function(frame)
            if frame.gui2Bg then GUI2:SetBorderColor(frame.gui2Bg, "color.border.accent") end
        end)
        slider:HookScript("OnLeave", function(frame)
            if frame.gui2Bg then GUI2:SetBorderColor(frame.gui2Bg, "color.border.default") end
        end)
    end

    slider.RefreshTheme = function(frame)
        if frame.gui2Bg then GUI2:RefreshPrimitive(frame.gui2Bg) end
        if frame.gui2Thumb then GUI2:SetTexturePaintKey(frame.gui2Thumb, "color.control.thumb") end
    end
    self:RegisterThemeObject(slider)
    slider:RefreshTheme()
    return slider
end

function GUI2:CreateSlider(parent, item)
    if self.Form and self.Form.CreateSlider then
        return self.Form:CreateSlider(parent, item or {})
    end
end

function GUI2:CreateDropdownArrowGlyph(parent)
    local marker = self:CreateTexture(parent, {
        paint = "color.accent.primary",
        layer = "ARTWORK",
        width = 6,
        height = 6,
    })
    marker.gui2Component = "DropdownIndicator"
    return marker
end

function GUI2:SkinDropdownButton(button)
    if not button then return end
    if not button.bg then
        button.bg = self:CreatePanel(button, {
            surface = "color.control.bg",
            border = "color.border.default",
        })
        button.bg:SetAllPoints()
        button.bg:SetFrameLevel(math_max(button:GetFrameLevel() - 1, 0))
    end

    local text = button.GetFontString and button:GetFontString() or button.text
    if not text then
        text = self:CreateText(button, "", "font.size.md", "color.text.primary")
        button.text = text
    end
    text:ClearAllPoints()
    text:SetPoint("LEFT", 8, 0)
    text:SetPoint("RIGHT", -24, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    self:SetTextColorKey(text, "color.text.primary")

    if not button.arrow then
        button.arrow = self:CreateDropdownArrowGlyph(button)
    end
    button.arrow:ClearAllPoints()
    button.arrow:SetPoint("RIGHT", -9, 0)

    button.RefreshTheme = function(frame)
        if frame.bg then GUI2:RefreshPrimitive(frame.bg) end
        if frame.text then GUI2:SetTextColorKey(frame.text, "color.text.primary") end
        if frame.arrow then GUI2:SetDropdownGlyphColor(frame.arrow, "color.accent.primary") end
    end
    button:SetScript("OnEnter", function(frame)
        if frame.bg then GUI2:SetBorderColor(frame.bg, "color.border.accent") end
        if frame.arrow then GUI2:SetDropdownGlyphColor(frame.arrow, "color.accent.primary") end
    end)
    button:SetScript("OnLeave", function(frame)
        if frame.bg then GUI2:SetBorderColor(frame.bg, "color.border.default") end
        if frame.arrow then GUI2:SetDropdownGlyphColor(frame.arrow, "color.accent.primary") end
    end)
    self:RegisterThemeObject(button)
    button:RefreshTheme()
    return button
end

local DROPDOWN_ANIMATION_KEY = "dropdown"
local DROPDOWN_ANIMATION_DISTANCE = 10
local DROPDOWN_ANIMATION_DURATION = 0.12

local function PlayDropdownArrowMotion(anchor, open)
    if not anchor or not anchor.arrow or not GUI2.PlayControlMotion then
        return
    end
    GUI2:PlayControlMotion(anchor.arrow, "dropdown-arrow", {
        owner = anchor,
        durationKey = "quick",
        effects = {
            { type = "rotation", fromDegrees = open and 0 or 180, toDegrees = open and 180 or 0 },
        },
    })
end

function GUI2:CloseDropdown(animated)
    local frame = self.DropdownFrame
    if not frame then return false end
    local anchor = frame.anchor

    if frame.blocker then
        frame.blocker:Hide()
    end
    frame.anchor = nil
    PlayDropdownArrowMotion(anchor, false)

    if not frame:IsShown() then
        frame.gui2DropdownClosing = nil
        return false
    end

    if animated ~= false and self.SlideOut then
        frame.gui2DropdownClosing = true
        frame:EnableMouse(false)
        self:SlideOut(frame, {
            owner = frame,
            key = DROPDOWN_ANIMATION_KEY,
            to = frame.gui2DropdownSlideOutTo or "top",
            distance = DROPDOWN_ANIMATION_DISTANCE,
            duration = DROPDOWN_ANIMATION_DURATION,
            hide = true,
            onFinished = function()
                frame.gui2DropdownClosing = nil
                frame:EnableMouse(true)
            end,
        })
    else
        frame.gui2DropdownClosing = nil
        frame:EnableMouse(true)
        frame:Hide()
    end
    return true
end

function GUI2:OpenDropdown(parent, options, onSelect, selectedValue, width)
    if not parent or not options then return end
    local rowHeight = 28
    local menuPadding = 2
    local checkColumnWidth = 18
    local checkSize = 6
    local checkInset = 6
    local previewLeftInset = 14
    local previewBorderInset = 2
    local optionIconSize = 18
    local optionIconGap = 6
    local actionButtonSize = 22
    local actionButtonGap = 4
    local actionButtonInset = 4
    local maxMenuHeight = 300
    local needsScrollBar = (#options * rowHeight) > (maxMenuHeight - (menuPadding * 2))
    local scrollRightInset = needsScrollBar and 16 or menuPadding

    local function HasOptionIcon(option)
        return type(option) == "table" and (option.iconData ~= nil or option.icon ~= nil or option.texture ~= nil or option.atlas ~= nil)
    end

    local function ApplyOptionIcon(texture, option)
        if not texture or not HasOptionIcon(option) then return false end

        local iconData = option.iconData
        local icons = YUI.API and YUI.API.Icons
        if type(iconData) == "table" and icons and icons.ApplyIcon and icons.ApplyIcon(texture, iconData) then
            local texCoord = option.texCoord or option.texCoords
            if texCoord then
                texture:SetTexCoord(unpack(texCoord))
            end
            texture:SetAlpha(1)
            texture:Show()
            return true
        end

        if option.atlas and texture.SetAtlas then
            texture:SetTexture(nil)
            texture:SetAtlas(option.atlas, false)
        else
            local source = option.icon or option.texture
            if source == nil then return false end
            texture:SetTexture(source)
        end
        local texCoord = option.texCoord or option.texCoords
        if texCoord then
            texture:SetTexCoord(unpack(texCoord))
        else
            texture:SetTexCoord(0, 1, 0, 1)
        end
        texture:SetVertexColor(1, 1, 1, 1)
        texture:SetAlpha(1)
        texture:SetBlendMode(option.blendMode or "BLEND")
        texture:Show()
        return true
    end

    local function LayoutOptionIcon(row, option)
        local textLeft = checkColumnWidth
        if row.optionIcon then
            row.optionIcon:Hide()
            row.optionIcon:SetTexture(nil)
        end
        if HasOptionIcon(option) and row.optionIcon then
            local size = option.iconSize or optionIconSize
            row.optionIcon:SetSize(size, size)
            row.optionIcon:ClearAllPoints()
            row.optionIcon:SetPoint("LEFT", checkColumnWidth + 2, 0)
            if ApplyOptionIcon(row.optionIcon, option) then
                textLeft = checkColumnWidth + 2 + size + optionIconGap
            end
        end
        return textLeft
    end

    local function HasOptionAction(option)
        return type(option) == "table" and type(option.actionFunc) == "function"
    end

    local function RefreshOptionActionButton(row, option)
        if not row then return 0 end
        if not HasOptionAction(option) then
            if row.actionButton then
                row.actionButton:Hide()
            end
            return 0
        end

        if not row.actionButton then
            local action = CreateFrame("Button", nil, row, "BackdropTemplate")
            action:RegisterForClicks("AnyUp")
            if action.SetPropagateMouseClicks then
                action:SetPropagateMouseClicks(false)
            end
            action.bg = self:CreatePanel(action, {
                surface = "color.control.bg",
                border = "color.border.default",
            })
            action.bg:SetAllPoints()
            if action.bg.SetFrameLevel and action.GetFrameLevel then
                action.bg:SetFrameLevel((action:GetFrameLevel() or 0) + 1)
            end
            action.icon = self:CreateIcon(action.bg, {
                atlas = option.actionAtlas or option.actionIconAtlas,
                icon = option.actionIcon or option.actionTexture,
                crop = false,
                fillParent = true,
                padding = option.actionIconPadding or 5,
            })
            row.actionButton = action
        end

        local action = row.actionButton
        local size = option.actionSize or actionButtonSize
        action:SetSize(size, size)
        action:ClearAllPoints()
        action:SetPoint("RIGHT", row, "RIGHT", -actionButtonInset, 0)
        action.gui2DropdownOption = option
        if action.bg and action.bg.SetFrameLevel and action.GetFrameLevel then
            action.bg:SetFrameLevel((action:GetFrameLevel() or 0) + 1)
        end
        if action.icon then
            if (option.actionAtlas or option.actionIconAtlas) and action.icon.SetAtlas then
                action.icon:SetTexture(nil)
                action.icon:SetAtlas(option.actionAtlas or option.actionIconAtlas, false)
            elseif option.actionIcon or option.actionTexture then
                action.icon:SetTexture(nil)
                action.icon:SetTexture(option.actionIcon or option.actionTexture)
                if action.icon.SetTexCoord then
                    action.icon:SetTexCoord(0, 1, 0, 1)
                end
            else
                self:SetIconTexture(action.icon, nil)
            end
            if action.icon.SetVertexColor and self.GetColor then
                action.icon:SetVertexColor(self:GetColor("color.text.accent"))
            end
            action.icon:Show()
        end
        action:SetScript("OnClick", function(button)
            local actionOption = button.gui2DropdownOption
            if actionOption and actionOption.actionFunc then
                actionOption.actionFunc(actionOption, row, button)
            end
        end)
        action:SetScript("OnEnter", function(button)
            if button.bg then GUI2:SetBorderColor(button.bg, "color.border.accent") end
            local actionOption = button.gui2DropdownOption
            if GameTooltip and actionOption and actionOption.actionTooltip then
                GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
                GameTooltip:SetText(actionOption.actionTooltip, 1, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        action:SetScript("OnLeave", function(button)
            if button.bg then GUI2:SetBorderColor(button.bg, "color.border.default") end
            if GameTooltip and GameTooltip:IsOwned(button) then
                YUI.HideGameTooltip()
            end
        end)
        action:Show()
        return size + actionButtonGap + actionButtonInset
    end

    if not self.DropdownFrame then
        local frame = self:CreatePanel(UIParent, {
            name = "YUI_GUI2_DropdownMenu",
            surface = "color.surface.popup",
            border = "color.popup.border",
            shadow = true,
        })
        frame:SetFrameStrata("TOOLTIP")
        frame:SetFrameLevel(9000)
        frame:SetClampedToScreen(true)
        frame:EnableMouse(true)
        frame:Hide()
        if UISpecialFrames then
            table_insert(UISpecialFrames, "YUI_GUI2_DropdownMenu")
        end

        local blocker = self:CreateFrame(UIParent, {
            type = "Button",
            frameStrata = "TOOLTIP",
            frameLevel = 8900,
            allPoints = true,
            mouse = true,
            hidden = true,
        })
        blocker:SetScript("OnClick", function()
            GUI2:CloseDropdown(true)
        end)
        frame.blocker = blocker

        local scroll = self:CreateScrollFrame(frame, {
            template = "UIPanelScrollFrameTemplate",
        })
        scroll:SetPoint("TOPLEFT", menuPadding, -menuPadding)
        scroll:SetPoint("BOTTOMRIGHT", -menuPadding, menuPadding)
        frame.scrollFrame = scroll
        frame.scrollChild = scroll.child
        frame.buttons = {}
        frame:SetScript("OnHide", function()
            if frame.blocker then frame.blocker:Hide() end
            frame.anchor = nil
            frame.gui2DropdownClosing = nil
            frame:EnableMouse(true)
        end)
        self.DropdownFrame = frame
    end

    local frame = self.DropdownFrame
    if frame:IsShown() and frame.anchor == parent then
        self:CloseDropdown(true)
        return true
    end

    if frame:IsShown() and frame.anchor and frame.anchor ~= parent then
        PlayDropdownArrowMotion(frame.anchor, false)
    end

    frame.gui2DropdownClosing = nil
    frame:EnableMouse(true)
    frame.anchor = parent
    frame:SetParent(UIParent)

    local dropdownWidth = width or parent:GetWidth() or 160
    local contentWidth = math_max(dropdownWidth - menuPadding - scrollRightInset, 1)
    frame:SetWidth(dropdownWidth)
    frame.scrollFrame:ClearAllPoints()
    frame.scrollFrame:SetPoint("TOPLEFT", menuPadding, -menuPadding)
    frame.scrollFrame:SetPoint("BOTTOMRIGHT", -scrollRightInset, menuPadding)
    frame.scrollChild:SetWidth(contentWidth)

    for _, button in ipairs(frame.buttons) do
        button:Hide()
    end

    local function UpdateDropdownSeparator(row, index)
        if not row or not row.separator then return end
        local rowOption = options[index]
        local nextOption = options[index + 1]
        local rowSelected = rowOption and (rowOption.checked == true or (selectedValue ~= nil and rowOption.value == selectedValue))
        local nextSelected = nextOption and (nextOption.checked == true or (selectedValue ~= nil and nextOption.value == selectedValue))
        if index < #options and rowOption and not rowSelected and not nextSelected then
            row.separator:Show()
        else
            row.separator:Hide()
        end
    end

    local function HasDropdownPreview(row)
        return row and row.bgPreview and row.bgPreview:IsShown()
    end

    local function LayoutDropdownPreview(row)
        if not HasDropdownPreview(row) then
            if row and row.gui2Borders then
                SetBorderTextureVisibility(row, false)
            end
            return false
        end
        row.bgPreview:ClearAllPoints()
        row.bgPreview:SetPoint("TOPLEFT", previewLeftInset, -previewBorderInset)
        row.bgPreview:SetPoint("BOTTOMRIGHT", -previewBorderInset, previewBorderInset)
        if row.text then
            row.text:ClearAllPoints()
            row.text:SetPoint("LEFT", previewLeftInset + 8, 0)
            row.text:SetPoint("RIGHT", -10, 0)
            row.text:SetWidth(math_max(row:GetWidth() - previewLeftInset - 18, 1))
        end
        if row.optionIcon then
            row.optionIcon:Hide()
        end
        if row.selectedEdge then
            row.selectedEdge:Hide()
        end
        return true
    end

    local function SetDropdownPreviewState(row, state)
        if not LayoutDropdownPreview(row) then return false end
        if not row.gui2Borders then
            self:CreateBorder(row, "color.border.accent")
        end
        if state == "hover" then
            self:SetBorderColor(row, "color.border.focus")
            SetBorderTextureVisibility(row, true)
        elseif row.gui2Selected then
            self:SetBorderColor(row, "color.border.accent")
            SetBorderTextureVisibility(row, true)
        else
            SetBorderTextureVisibility(row, false)
        end
        return true
    end

    local height = 0
    local selectedIndex
    for i, option in ipairs(options) do
        local opt = option
        local rowIndex = i
        local button = frame.buttons[i]
        if not button then
            button = self:CreateButtonFrame(frame.scrollChild, {
                template = "BackdropTemplate",
                height = rowHeight,
                radiusKey = "layout.radius.control",
            })
            local rowBg = self:CreateTexture(button, "color.surface.popup", "BACKGROUND")
            rowBg:SetAllPoints(button)
            button.rowBg = rowBg

            local check = self:CreateTexture(button, "color.accent.primary", "OVERLAY")
            check:SetSize(checkSize, checkSize)
            check:SetPoint("LEFT", checkInset, 0)
            button.check = check

            local optionIcon = self:CreateTexture(button, { layer = "ARTWORK" })
            optionIcon:Hide()
            button.optionIcon = optionIcon

            local selectedEdge = self:CreateTexture(button, "color.border.accent", "OVERLAY")
            selectedEdge:SetPoint("TOPLEFT", 0, 0)
            selectedEdge:SetPoint("BOTTOMLEFT", 0, 0)
            selectedEdge:SetWidth(GetPixelSize(button, 2, 1))
            selectedEdge:Hide()
            button.selectedEdge = selectedEdge

            local label = self:CreateText(button, "", "font.size.md", "color.text.primary")
            label:SetPoint("LEFT", checkColumnWidth, 0)
            label:SetPoint("RIGHT", -10, 0)
            label:SetJustifyH("LEFT")
            label:SetWordWrap(false)
            button.text = label

            local separator = button:CreateTexture(nil, "OVERLAY")
            PreparePixelTexture(separator)
            separator:SetPoint("BOTTOMLEFT", checkColumnWidth, 0)
            separator:SetPoint("BOTTOMRIGHT", -8, 0)
            separator:SetHeight(GetPixelSize(button, 1, 1))
            button.separator = separator
            frame.buttons[i] = button
        end

        button:Show()
        button:SetPoint("TOPLEFT", 0, -height)
        button:SetPoint("TOPRIGHT", 0, -height)
        button:SetHeight(rowHeight)
        button:SetWidth(contentWidth)
        local isSelected = opt.checked == true or (selectedValue ~= nil and opt.value == selectedValue)
        button.gui2Selected = isSelected
        if button.gui2Selected then
            selectedIndex = rowIndex
        end
        local textLeft = LayoutOptionIcon(button, opt)
        local actionWidth = RefreshOptionActionButton(button, opt)
        local textRight = -(10 + actionWidth)
        if button.text then
            button.text:ClearAllPoints()
            button.text:SetPoint("LEFT", textLeft, 0)
            button.text:SetPoint("RIGHT", textRight, 0)
            button.text:SetWidth(math_max(button:GetWidth() - textLeft - 10 - actionWidth, 1))
            button.text:SetFont(self:GetFont("font.family.body"), self:GetMetric("font.size.md", 13), "")
            button.text:SetJustifyH("LEFT")
            button.text:SetWordWrap(false)
        end
        if button.rowBg then
            self:SetTexturePaintKey(button.rowBg, isSelected and "color.control.active" or "color.surface.popup")
        end
        if button.selectedEdge then
            if isSelected then
                button.selectedEdge:Show()
                self:SetTexturePaintKey(button.selectedEdge, "color.border.accent")
            else
                button.selectedEdge:Hide()
            end
        end
        if button.separator then
            button.separator:SetColorTexture(self:GetColor("color.border.subtle"))
            button.separator:ClearAllPoints()
            button.separator:SetPoint("BOTTOMLEFT", textLeft, 0)
            button.separator:SetPoint("BOTTOMRIGHT", -(8 + actionWidth), 0)
            UpdateDropdownSeparator(button, rowIndex)
        end
        button.text:SetText(opt.text or "")
        if isSelected then
            button.check:Show()
        else
            button.check:Hide()
        end
        self:SetTextColorKey(button.text, isSelected and "color.text.accent" or "color.text.primary")
        if button.check then
            self:SetTexturePaintKey(button.check, "color.accent.primary")
        end

        if button.bgPreview then
            button.bgPreview:Hide()
            button.bgPreview:SetTexture(nil)
        end
        if opt.render then
            opt.render(button)
        end
        local isPreviewRow = SetDropdownPreviewState(button, button.gui2Selected and "selected" or "normal")
        if isPreviewRow and button.rowBg then
            self:SetTexturePaintKey(button.rowBg, "color.surface.popup")
        end

        button:SetScript("OnClick", function()
            if opt.func then opt.func() end
            if onSelect then onSelect(opt.value, opt) end
            GUI2:CloseDropdown(true)
        end)
        button:SetScript("OnEnter", function(self)
            local previewRow = SetDropdownPreviewState(self, "hover")
            if self.rowBg and not previewRow then GUI2:SetTexturePaintKey(self.rowBg, "color.control.hover") end
            if self.selectedEdge then
                if previewRow then
                    self.selectedEdge:Hide()
                else
                    self.selectedEdge:Show()
                    GUI2:SetTexturePaintKey(self.selectedEdge, "color.border.accent")
                end
            end
            local previous = frame.buttons[rowIndex - 1]
            if previous and previous.separator then previous.separator:Hide() end
            if self.separator then self.separator:Hide() end
            if self.text then GUI2:SetTextColorKey(self.text, "color.text.accent") end
        end)
        button:SetScript("OnLeave", function(self)
            local previewRow = SetDropdownPreviewState(self, self.gui2Selected and "selected" or "normal")
            if self.rowBg then
                GUI2:SetTexturePaintKey(self.rowBg, previewRow and "color.surface.popup" or (self.gui2Selected and "color.control.active" or "color.surface.popup"))
            end
            if self.selectedEdge then
                if previewRow then
                    self.selectedEdge:Hide()
                elseif self.gui2Selected then
                    self.selectedEdge:Show()
                    GUI2:SetTexturePaintKey(self.selectedEdge, "color.border.accent")
                else
                    self.selectedEdge:Hide()
                end
            end
            UpdateDropdownSeparator(frame.buttons[rowIndex - 1], rowIndex - 1)
            UpdateDropdownSeparator(self, rowIndex)
            if self.text then GUI2:SetTextColorKey(self.text, self.gui2Selected and "color.text.accent" or "color.text.primary") end
        end)
        height = height + rowHeight
    end

    frame.scrollChild:SetHeight(height)
    local finalHeight = math_min(height + (menuPadding * 2), maxMenuHeight)
    frame:SetHeight(finalHeight)
    frame.scrollFrame:SetVerticalScroll(0)

    local openFrom = "top"
    local closeTo = "top"
    local parentBottom = parent.GetBottom and parent:GetBottom()
    local parentTop = parent.GetTop and parent:GetTop()
    local screenHeight = UIParent and UIParent.GetHeight and UIParent:GetHeight()
    frame:ClearAllPoints()
    if parentBottom and parentTop and screenHeight and parentBottom - finalHeight - 8 < 0 and screenHeight - parentTop > finalHeight + 8 then
        frame:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 0, 2)
        openFrom = "bottom"
        closeTo = "bottom"
    else
        frame:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, -2)
    end
    frame.gui2DropdownSlideOutTo = closeTo

    local function AlignDropdownScrollBar()
        local scrollBar = GetScrollFrameScrollBar(frame.scrollFrame)
        if not scrollBar then return end

        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPLEFT", frame.scrollFrame, "TOPRIGHT", 4, 0)
        scrollBar:SetPoint("BOTTOMLEFT", frame.scrollFrame, "BOTTOMRIGHT", 4, 0)
        scrollBar:SetWidth(10)
        scrollBar.gui2ThumbWidth = 4
        scrollBar.gui2MinThumbHeight = 14
        if scrollBar.gui2Track then
            scrollBar.gui2Track:Hide()
        end
        if scrollBar.ScrollUpButton then scrollBar.ScrollUpButton:Hide() end
        if scrollBar.ScrollDownButton then scrollBar.ScrollDownButton:Hide() end
        if scrollBar.UpdateVisualTrack then scrollBar:UpdateVisualTrack() end
        if scrollBar.UpdateVisualThumb then scrollBar:UpdateVisualThumb() end
    end

    if needsScrollBar then
        AlignDropdownScrollBar()
        if frame.scrollFrame.ScrollBar then frame.scrollFrame.ScrollBar:Show() end
        if selectedIndex and selectedIndex > 1 then
            local viewportHeight = finalHeight - (menuPadding * 2)
            local selectedTop = (selectedIndex - 1) * rowHeight
            local selectedBottom = selectedTop + rowHeight
            if selectedBottom > viewportHeight then
                local maxScroll = math_max(0, height - viewportHeight)
                local targetScroll = selectedTop - math_floor((viewportHeight - rowHeight) / 2)
                targetScroll = math_max(0, math_min(maxScroll, targetScroll))
                frame.scrollFrame:SetVerticalScroll(targetScroll)
            end
        end
    else
        if frame.scrollFrame.ScrollBar then
            if frame.scrollFrame.ScrollBar.visualThumb then frame.scrollFrame.ScrollBar.visualThumb:Hide() end
            frame.scrollFrame.ScrollBar:Hide()
        end
    end

    self:RefreshPrimitive(frame)
    frame:Show()
    local scrollBar = GetScrollFrameScrollBar(frame.scrollFrame)
    if scrollBar and scrollBar.UpdateVisualThumb then scrollBar:UpdateVisualThumb() end
    if frame.blocker then frame.blocker:Show() end
    PlayDropdownArrowMotion(parent, true)
    if self.SlideIn then
        self:SlideIn(frame, {
            owner = frame,
            key = DROPDOWN_ANIMATION_KEY,
            from = openFrom,
            distance = DROPDOWN_ANIMATION_DISTANCE,
            duration = DROPDOWN_ANIMATION_DURATION,
        })
    elseif frame.SetAlpha then
        frame:SetAlpha(1)
    end
    return true
end

function GUI2:CreateDropdown(parent, item)
    if self.Form and self.Form.CreateDropdown then
        return self.Form:CreateDropdown(parent, item or {})
    end
end

function GUI2:SkinEditBox(editbox)
    if not editbox then return end

    if editbox.SetBackdrop then
        editbox:SetBackdrop(nil)
    end

    if editbox.GetName then
        local name = editbox:GetName()
        if name then
            local left = _G[name .. "Left"]
            local middle = _G[name .. "Middle"]
            local right = _G[name .. "Right"]
            if left then left:Hide() end
            if middle then middle:Hide() end
            if right then right:Hide() end
        end
    end

    if not editbox.gui2Bg then
        local bg = self:CreatePanel(editbox, {
            surface = "color.control.bg",
            border = "color.border.default",
        })
        bg:SetPoint("TOPLEFT", -2, 0)
        bg:SetPoint("BOTTOMRIGHT", 2, 0)
        bg:SetFrameLevel(math_max(editbox:GetFrameLevel() - 1, 0))
        editbox.gui2Bg = bg
    end

    if editbox.SetTextColor then
        editbox:SetTextColor(self:GetColor("color.text.primary"))
    end
    if editbox.SetFont then
        editbox:SetFont(self:GetFont("font.family.body"), self:GetMetric("font.size.md", 13), "")
    end

    if not editbox.gui2EditBoxScripts then
        editbox.gui2EditBoxScripts = true
        editbox:HookScript("OnEnter", function(frame)
            if frame.gui2Bg then GUI2:SetBorderColor(frame.gui2Bg, "color.border.accent") end
        end)
        editbox:HookScript("OnLeave", function(frame)
            if frame.gui2Bg and not frame:HasFocus() then GUI2:SetBorderColor(frame.gui2Bg, "color.border.default") end
        end)
        editbox:HookScript("OnEditFocusGained", function(frame)
            if frame.gui2Bg then GUI2:SetBorderColor(frame.gui2Bg, "color.border.focus") end
        end)
        editbox:HookScript("OnEditFocusLost", function(frame)
            if frame.gui2Bg then GUI2:SetBorderColor(frame.gui2Bg, "color.border.default") end
        end)
    end

    editbox.RefreshTheme = function(frame)
        if frame.gui2Bg then GUI2:RefreshPrimitive(frame.gui2Bg) end
        if frame.SetTextColor then frame:SetTextColor(GUI2:GetColor("color.text.primary")) end
    end
    self:RegisterThemeObject(editbox)
    editbox:RefreshTheme()
    return editbox
end

function GUI2:CreateEditBox(parent, opts)
    opts = opts or {}
    if self.Form and self.Form.CreateEditBox then
        local editbox = self.Form:CreateEditBox(parent, opts)
        self:SkinEditBox(editbox)
        return editbox
    end
end

function GUI2:CreateColorPicker(parent, item)
    if self.Form and self.Form.CreateColorPicker then
        return self.Form:CreateColorPicker(parent, item or {})
    end
end

function GUI2:SkinCheckBox(cb)
    if not cb then return end

    if cb.SetNormalTexture then cb:SetNormalTexture("") end
    if cb.SetPushedTexture then cb:SetPushedTexture("") end
    if cb.SetHighlightTexture then cb:SetHighlightTexture("") end
    if cb.SetBackdrop then cb:SetBackdrop(nil) end

    if not cb.bg then
        cb.bg = self:CreatePanel(cb, {
            width = 16,
            height = 16,
            surface = "color.control.bg",
            border = "color.border.default",
        })
        cb.bg:SetPoint("LEFT", 0, 0)
        cb.bg:SetFrameLevel(cb:GetFrameLevel())
    end

    if not cb.gui2Check then
        cb.gui2Check = self:CreateTexture(cb, "color.text.accent", "ARTWORK")
        cb.gui2Check:SetPoint("TOPLEFT", cb.bg, "TOPLEFT", 3, -3)
        cb.gui2Check:SetPoint("BOTTOMRIGHT", cb.bg, "BOTTOMRIGHT", -3, 3)
        if cb.SetCheckedTexture then cb:SetCheckedTexture(cb.gui2Check) end
    end

    if cb.text then
        cb.text:ClearAllPoints()
        cb.text:SetPoint("LEFT", cb.bg, "RIGHT", 6, -1)
        self:SetTextColorKey(cb.text, "color.text.primary")
    end

    cb.RefreshTheme = function(frame)
        if frame.bg then
            frame.bg.gui2Surface = frame:GetChecked() and "color.control.active" or "color.control.bg"
            GUI2:RefreshPrimitive(frame.bg)
            GUI2:SetBorderColor(frame.bg, frame:GetChecked() and "color.border.accent" or "color.border.default")
        end
        if frame.gui2Check then GUI2:SetTexturePaintKey(frame.gui2Check, "color.text.accent") end
        if frame.text then GUI2:SetTextColorKey(frame.text, "color.text.primary") end
    end
    if not cb.gui2CheckBoxScripts then
        cb.gui2CheckBoxScripts = true
        cb:HookScript("OnEnter", function(frame)
            if frame.bg then GUI2:SetBorderColor(frame.bg, "color.border.accent") end
        end)
        cb:HookScript("OnLeave", function(frame)
            if frame.bg then GUI2:SetBorderColor(frame.bg, frame:GetChecked() and "color.border.accent" or "color.border.default") end
        end)
        cb:HookScript("OnClick", function(frame)
            if frame.RefreshTheme then frame:RefreshTheme() end
        end)
    end
    self:RegisterThemeObject(cb)
    cb:RefreshTheme()
    return cb
end

function GUI2:CreateCheckBox(parent, item)
    if self.Form and self.Form.CreateCheckbox then
        return self.Form:CreateCheckbox(parent, item or {})
    end
end

GetScrollFrameScrollBar = function(scrollFrame)
    if not scrollFrame then return end
    local scrollBar = scrollFrame.ScrollBar
    if not scrollBar and scrollFrame.GetName then
        local name = scrollFrame:GetName()
        if name then
            scrollBar = _G[name .. "ScrollBar"]
        end
    end
    return scrollBar
end

local function UpdateVisualScrollThumb(scrollBar)
    if not scrollBar or not scrollBar.visualThumb then return end

    local scrollFrame = scrollBar.gui2ScrollFrame
    local trackHeight = scrollBar.GetHeight and scrollBar:GetHeight() or 0
    if not trackHeight or trackHeight <= 0 then return end

    local viewportHeight = scrollFrame and scrollFrame.GetHeight and scrollFrame:GetHeight() or trackHeight
    if not viewportHeight or viewportHeight <= 0 then
        viewportHeight = trackHeight
    end

    local contentHeight
    local scrollChild = scrollFrame and ((scrollFrame.GetScrollChild and scrollFrame:GetScrollChild()) or scrollFrame.scrollChild or scrollFrame.child)
    if scrollChild and scrollChild.GetHeight then
        contentHeight = scrollChild:GetHeight()
    end

    local minValue, maxValue = 0, 0
    if scrollBar.GetMinMaxValues then
        minValue, maxValue = scrollBar:GetMinMaxValues()
    end
    local range = math_max(0, (maxValue or 0) - (minValue or 0))
    if scrollFrame and scrollFrame.GetVerticalScrollRange then
        range = math_max(range, scrollFrame:GetVerticalScrollRange() or 0)
    end
    if contentHeight and contentHeight > 0 then
        range = math_max(range, contentHeight - viewportHeight)
    end
    contentHeight = math_max(contentHeight or 0, viewportHeight + range)

    if range <= 0 or contentHeight <= viewportHeight then
        scrollBar.visualThumb:Hide()
        return
    end

    local minThumbHeight = math_min(trackHeight, scrollBar.gui2MinThumbHeight or 16)
    local thumbHeight = math_floor(trackHeight * (viewportHeight / contentHeight) + 0.5)
    thumbHeight = math_max(minThumbHeight, math_min(trackHeight, thumbHeight))

    local value = scrollFrame and scrollFrame.GetVerticalScroll and scrollFrame:GetVerticalScroll() or 0
    if scrollBar.GetValue then
        value = math_max(value, (scrollBar:GetValue() or 0) - (minValue or 0))
    end
    value = math_max(0, math_min(range, value))

    local movableHeight = math_max(0, trackHeight - thumbHeight)
    local offset = range > 0 and math_floor((value / range) * movableHeight + 0.5) or 0
    local thumbWidth = GetPixelSize(scrollBar, scrollBar.gui2ThumbWidth or 4, 1)

    scrollBar.visualThumb:ClearAllPoints()
    scrollBar.visualThumb:SetPoint("TOP", scrollBar, "TOP", 0, -offset)
    scrollBar.visualThumb:SetSize(thumbWidth, math_max(1, thumbHeight))
    scrollBar.visualThumb:Show()
end

local function UpdateVisualScrollTrack(scrollBar)
    if not scrollBar or not scrollBar.gui2TrackLine then return end
    scrollBar.gui2TrackLine:ClearAllPoints()
    scrollBar.gui2TrackLine:SetPoint("TOP", scrollBar, "TOP", 0, 0)
    scrollBar.gui2TrackLine:SetPoint("BOTTOM", scrollBar, "BOTTOM", 0, 0)
    scrollBar.gui2TrackLine:SetWidth(GetPixelSize(scrollBar, scrollBar.gui2TrackLineWidth or 1, 1))
    scrollBar.gui2TrackLine:Show()
end

function GUI2:SkinScrollBar(scrollFrame)
    if not scrollFrame then return end

    local scrollBar = GetScrollFrameScrollBar(scrollFrame)
    if not scrollBar then return true end
    scrollFrame.gui2ScrollBar = scrollBar
    scrollBar.gui2ScrollFrame = scrollFrame

    if scrollBar.ScrollUpButton then
        scrollBar.ScrollUpButton:Hide()
        scrollBar.ScrollUpButton:SetScript("OnShow", function(button) button:Hide() end)
    end
    if scrollBar.ScrollDownButton then
        scrollBar.ScrollDownButton:Hide()
        scrollBar.ScrollDownButton:SetScript("OnShow", function(button) button:Hide() end)
    end

    if scrollBar.SetBackdrop then
        scrollBar:SetBackdrop(nil)
    end

    if scrollBar.gui2Track then
        scrollBar.gui2Track:Hide()
    end
    if not scrollBar.gui2TrackLine then
        scrollBar.gui2TrackLine = scrollBar:CreateTexture(nil, "BACKGROUND")
        PreparePixelTexture(scrollBar.gui2TrackLine)
    end
    self:SetTexturePaintKey(scrollBar.gui2TrackLine, scrollBar.gui2TrackLineToken or "color.border.subtle")
    scrollBar.UpdateVisualTrack = UpdateVisualScrollTrack
    scrollBar:UpdateVisualTrack()

    local thumb = scrollBar:GetThumbTexture()
    if thumb then
        thumb:SetTexture(nil)
        thumb:SetAlpha(0)
        thumb:Hide()
    end

    if not scrollBar.visualThumb then
        scrollBar.visualThumb = scrollBar:CreateTexture(nil, "ARTWORK")
        PreparePixelTexture(scrollBar.visualThumb)
    end
    scrollBar.visualThumb:SetTexture("Interface\\Buttons\\WHITE8x8")
    self:SetTexturePaintKey(scrollBar.visualThumb, "color.control.thumb")
    scrollBar.gui2ThumbWidth = scrollBar.gui2ThumbWidth or 4
    scrollBar.UpdateVisualThumb = UpdateVisualScrollThumb

    if not scrollBar.gui2VisualThumbScripts then
        scrollBar.gui2VisualThumbScripts = true
        if scrollBar.HookScript then
            scrollBar:HookScript("OnValueChanged", UpdateVisualScrollThumb)
            scrollBar:HookScript("OnShow", UpdateVisualScrollThumb)
        end
        if scrollFrame.HookScript then
            scrollFrame:HookScript("OnScrollRangeChanged", function(frame)
                local bar = frame.gui2ScrollBar or GetScrollFrameScrollBar(frame)
                if bar and bar.UpdateVisualThumb then bar:UpdateVisualThumb() end
            end)
            scrollFrame:HookScript("OnVerticalScroll", function(frame)
                local bar = frame.gui2ScrollBar or GetScrollFrameScrollBar(frame)
                if bar and bar.UpdateVisualThumb then bar:UpdateVisualThumb() end
            end)
            scrollFrame:HookScript("OnShow", function(frame)
                local bar = frame.gui2ScrollBar or GetScrollFrameScrollBar(frame)
                if bar and bar.UpdateVisualThumb then bar:UpdateVisualThumb() end
            end)
        end
    end

    scrollBar.RefreshTheme = function(bar)
        if bar.gui2Track then bar.gui2Track:Hide() end
        if bar.gui2TrackLine then
            GUI2:SetTexturePaintKey(bar.gui2TrackLine, bar.gui2TrackLineToken or "color.border.subtle")
        end
        if bar.UpdateVisualTrack then bar:UpdateVisualTrack() end
        if bar.visualThumb then GUI2:SetTexturePaintKey(bar.visualThumb, "color.control.thumb") end
        if bar.UpdateVisualThumb then bar:UpdateVisualThumb() end
    end
    self:RegisterThemeObject(scrollBar)
    scrollBar:RefreshTheme()
    return true
end

function GUI2:CreateSwitch(parent, item)
    if not parent or not item then return end
    if self.Form and self.Form.CreateSwitch then
        if item.label then
            local switchWidth = item.width or 60
            local switchHeight = item.height or 24
            local container = self:CreateFrame(parent, {
                width = switchWidth,
                height = switchHeight,
            })
            local label = self:CreateText(container, item.label, "font.size.md", "color.text.primary")
            label:SetPoint("LEFT", 0, 0)
            container.text = label
            local switch = self.Form:CreateSwitch(container, item)
            switch:SetPoint("LEFT", label, "RIGHT", 10, 0)
            container.switch = switch
            container:SetWidth(label:GetStringWidth() + 10 + switchWidth)
            container:SetHeight(switchHeight)
            container.gui2Disabled = item.disabled and true or false
            container.GetValue = function(frame)
                if frame.switch and frame.switch.GetValue then
                    return frame.switch:GetValue()
                end
            end
            container.GetChecked = function(frame)
                if frame.switch and frame.switch.GetChecked then
                    return frame.switch:GetChecked()
                end
            end
            container.SetValue = function(frame, value, silent)
                if frame.switch and frame.switch.SetValue then
                    frame.switch:SetValue(value, silent)
                end
            end
            container.SetChecked = function(frame, checked, silent)
                if frame.switch and frame.switch.SetChecked then
                    frame.switch:SetChecked(checked, silent)
                end
            end
            container.SetDisabled = function(frame, disabled)
                frame.gui2Disabled = disabled and true or false
                if frame.text then
                    GUI2:SetTextColorKey(frame.text, frame.gui2Disabled and "color.text.disabled" or "color.text.primary")
                end
                if frame.switch and frame.switch.SetDisabled then
                    frame.switch:SetDisabled(frame.gui2Disabled)
                elseif frame.switch then
                    if frame.gui2Disabled and frame.switch.Disable then
                        frame.switch:Disable()
                    elseif frame.switch.Enable then
                        frame.switch:Enable()
                    end
                end
            end
            container.RefreshTheme = function(frame)
                if frame.text then
                    GUI2:SetTextColorKey(frame.text, frame.gui2Disabled and "color.text.disabled" or "color.text.primary")
                end
                if frame.switch and frame.switch.RefreshTheme then frame.switch:RefreshTheme() end
            end
            container:SetDisabled(container.gui2Disabled)
            self:RegisterThemeObject(container)
            return container
        end
        return self.Form:CreateSwitch(parent, item)
    end
    BindConfigItem(item)

    local width = item.width or 60
    local height = item.height or 24
    local offValue = item.offValue
    if offValue == nil then offValue = item.leftValue end
    if offValue == nil then offValue = false end
    local onValue = item.onValue
    if onValue == nil then onValue = item.rightValue end
    if onValue == nil then onValue = true end
    local offText = item.offText or item.leftText or GetCoreText("common.off", "OFF")
    local onText = item.onText or item.rightText or GetCoreText("common.on", "ON")

    local container = self:CreateFrame(parent, {
        width = width,
        height = height,
    })
    local switchParent = container
    local switchPoint = { "LEFT", 0, 0 }

    if item.label then
        local label = self:CreateText(container, item.label, "font.size.md", "color.text.primary")
        label:SetPoint("LEFT", 0, 0)
        container.text = label
        switchPoint = { "LEFT", label, "RIGHT", 10, 0 }
        container:SetWidth(label:GetStringWidth() + 10 + width)
    end

    local switch = self:CreateButtonFrame(switchParent, {
        template = "BackdropTemplate",
        width = width,
        height = height,
    })
    switch:SetPoint(unpack(switchPoint))
    switch:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    self:CreateBorder(switch, "color.border.default")

    local thumb = self:CreatePanel(switch, {
        width = item.thumbWidth or 8,
        height = height - 6,
        surface = "color.control.thumb",
        border = "color.border.subtle",
    })
    switch.thumb = thumb

    local text = self:CreateText(switch, "", "font.size.md", "color.text.primary")
    switch.text = text

    local function UpdateState(value)
        local enabled = value == onValue
        if enabled then
            switch.currentValue = onValue
        else
            switch.currentValue = offValue
        end
        switch.gui2Surface = enabled and "color.control.active" or "color.control.track"
        local colorKey = enabled and (item.onColorKey or item.rightColorKey) or (item.offColorKey or item.leftColorKey)
        local color = enabled and (item.onColor or item.rightColor) or (item.offColor or item.leftColor)
        if colorKey then
            switch:SetBackdropColor(GUI2:GetColor(colorKey))
        elseif color then
            switch:SetBackdropColor(unpack(color))
        else
            switch:SetBackdropColor(GUI2:GetColor(switch.gui2Surface))
        end
        GUI2:SetBorderColor(switch, enabled and "color.border.accent" or "color.border.default")
        thumb:ClearAllPoints()
        text:ClearAllPoints()
        if enabled then
            thumb:SetPoint("RIGHT", -3, 0)
            text:SetPoint("LEFT", 3, 0)
            text:SetText(onText)
            GUI2:SetTextColorKey(text, item.onTextColorKey or item.rightTextColorKey or "color.text.primary")
        else
            thumb:SetPoint("LEFT", 3, 0)
            text:SetPoint("RIGHT", -3, 0)
            text:SetText(offText)
            GUI2:SetTextColorKey(text, item.offTextColorKey or item.leftTextColorKey or "color.text.secondary")
        end
    end

    switch.SetValue = function(frame, value, silent)
        UpdateState(value)
        if not silent then
            SetItemValue(item, frame, frame.currentValue)
        end
    end
    switch.RefreshTheme = function(frame)
        GUI2:ApplyBackdrop(frame, frame.gui2Surface or "color.control.track")
        UpdateState(frame.currentValue)
        if frame.thumb then GUI2:RefreshPrimitive(frame.thumb) end
    end
    switch:SetScript("OnClick", function(frame)
        if frame.currentValue == onValue then
            frame:SetValue(offValue)
        else
            frame:SetValue(onValue)
        end
    end)
    switch:SetScript("OnEnter", function(frame)
        GUI2:SetBorderColor(frame, "color.border.accent")
    end)
    switch:SetScript("OnLeave", function(frame)
        GUI2:SetBorderColor(frame, frame.currentValue == onValue and "color.border.accent" or "color.border.default")
    end)

    local value = GetItemValue(item)
    if value ~= onValue and value ~= offValue then value = offValue end
    switch:SetValue(value, true)
    container.switch = switch
    self:RegisterThemeObject(switch)

    if not item.label then
        switch:SetParent(parent)
        switch:ClearAllPoints()
        return switch
    end
    return container
end

function GUI2:CreateModSwitch(parent, item)
    local app = self.Application
    if app and app.CreateModSwitch then
        return app:CreateModSwitch(parent, item)
    end
end

function GUI2:CreateTable(parent, item)
    if not parent or not item then return end

    local width = item.width or 600
    local height = item.height or 400
    local rowHeight = item.rowHeight or 24
    local columns = item.columns or item.headers or {}
    local rows = item.data or {}
    local headerHeight = 24

    local container = self:CreatePanel(parent, {
        width = width,
        height = height,
        surface = "color.surface.panel",
        border = "color.border.default",
    })

    local header = self:CreatePanel(container, {
        height = headerHeight,
        surface = "color.surface.header",
        border = "color.border.subtle",
    })
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    container.header = header

    local xOffset = 0
    for index, column in ipairs(columns) do
        local columnWidth = column.width or (width / math_max(#columns, 1))
        local headerText = self:CreateText(header, column.name or column.text or "", "font.size.sm", "color.text.heading")
        headerText:SetPoint("LEFT", xOffset + 6, 0)
        headerText:SetWidth(columnWidth - 12)
        headerText:SetJustifyH("LEFT")
        if index < #columns then
            local divider = self:CreateTexture(header, "color.border.subtle", "ARTWORK")
            divider:SetSize(1, headerHeight - 8)
            divider:SetPoint("LEFT", xOffset + columnWidth, 0)
        end
        xOffset = xOffset + columnWidth
    end

    local scrollFrame = self:CreateScrollFrame(container, {
        template = "UIPanelScrollFrameTemplate",
    })
    scrollFrame:SetPoint("TOPLEFT", 1, -headerHeight - 2)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 3)
    local child = scrollFrame.child
    child:SetWidth(width - 26)
    container.scrollFrame = scrollFrame
    container.rowFrames = {}

    local function UpdateRows()
        for _, row in ipairs(container.rowFrames) do
            row:Hide()
        end

        local yOffset = 0
        for i, rowData in ipairs(rows) do
            local row = container.rowFrames[i]
            if not row then
                row = GUI2:CreateButtonFrame(child, {
                    template = "BackdropTemplate",
                    width = width - 26,
                    height = rowHeight,
                })
                row.gui2SurfaceToken = "color.surface.panel"
                SkinButton(row, {
                    surface = "color.surface.panel",
                    textColor = "color.text.primary",
                    preserveTextPoint = true,
                })
                row.cells = {}
                local cellX = 0
                for j, column in ipairs(columns) do
                    local columnWidth = column.width or (width / math_max(#columns, 1))
                    local cell = GUI2:CreateText(row, "", "font.size.sm", "color.text.primary")
                    cell:SetPoint("LEFT", cellX + 6, 0)
                    cell:SetWidth(columnWidth - 12)
                    cell:SetJustifyH("LEFT")
                    row.cells[j] = cell
                    cellX = cellX + columnWidth
                end
                container.rowFrames[i] = row
            end

            row:Show()
            row:SetPoint("TOPLEFT", 0, -yOffset)
            row:SetPoint("TOPRIGHT", 0, -yOffset)
            row.gui2SurfaceToken = i % 2 == 0 and "color.surface.raised" or "color.surface.panel"
            row:RefreshTheme()

            for j, column in ipairs(columns) do
                local value = column.key and rowData[column.key] or rowData[j]
                if row.cells[j] then
                    row.cells[j]:SetText(value or "")
                end
            end

            yOffset = yOffset + rowHeight
        end
        child:SetHeight(yOffset)
    end

    container.UpdateRows = UpdateRows
    UpdateRows()
    return container
end

function GUI2:CreateDivider(parent, width, height, label, alignLeft)
    if type(height) == "string" and label == nil then
        label = height
        height = nil
    end

    local centeredLabel = label and alignLeft == false
    local frame = self:CreateFrame(parent, {
        width = width or 320,
        height = height or 22,
    })

    local function CreateLine()
        local line = frame:CreateTexture(nil, "ARTWORK")
        PreparePixelTexture(line)
        line:SetHeight(GetPixelSize(frame, 1, 1))
        return line
    end

    local line = CreateLine()
    frame.gui2DividerLine = line

    if label then
        local text = self:CreateText(frame, label, "font.size.md", "color.text.heading")
        frame.gui2DividerText = text
        frame.gui2DividerHeading = true
        frame.gui2DividerCentered = centeredLabel

        if centeredLabel then
            text:SetPoint("CENTER", frame, "CENTER", 0, 0)
            text:SetJustifyH("CENTER")

            local rightLine = CreateLine()
            line:SetPoint("LEFT", 0, 0)
            line:SetPoint("RIGHT", text, "LEFT", -10, 0)
            rightLine:SetPoint("LEFT", text, "RIGHT", 10, 0)
            rightLine:SetPoint("RIGHT", 0, 0)
            frame.gui2DividerRightLine = rightLine
        else
            text:SetPoint("LEFT", 0, 0)
            line:SetPoint("LEFT", text, "RIGHT", 8, 0)
            line:SetPoint("RIGHT", 0, 0)
        end
    else
        line:SetPoint("LEFT", 0, 0)
        line:SetPoint("RIGHT", 0, 0)
        self:SetTexturePaintKey(line, "color.border.subtle")
    end

    frame.RefreshTheme = function(divider)
        local dividerLine = divider.gui2DividerLine
        if not dividerLine then return end

        if divider.gui2DividerHeading then
            if divider.gui2DividerText then
                GUI2:SetTextColorKey(divider.gui2DividerText, "color.text.heading")
            end

            local r, g, b = GUI2:GetColor("color.text.heading")
            if divider.gui2DividerCentered and dividerLine.SetGradient then
                dividerLine:SetColorTexture(1, 1, 1, 1)
                dividerLine:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.08), CreateColor(r, g, b, 0.88))
            elseif divider.gui2DividerCentered and dividerLine.SetGradientAlpha then
                dividerLine:SetGradientAlpha("HORIZONTAL", r, g, b, 0.08, r, g, b, 0.88)
            elseif dividerLine.SetGradient then
                dividerLine:SetColorTexture(1, 1, 1, 1)
                dividerLine:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.88), CreateColor(r, g, b, 0.08))
            elseif dividerLine.SetGradientAlpha then
                dividerLine:SetGradientAlpha("HORIZONTAL", r, g, b, 0.88, r, g, b, 0.08)
            else
                dividerLine:SetColorTexture(r, g, b, 0.72)
            end

            if divider.gui2DividerRightLine then
                if divider.gui2DividerRightLine.SetGradient then
                    divider.gui2DividerRightLine:SetColorTexture(1, 1, 1, 1)
                    divider.gui2DividerRightLine:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.88), CreateColor(r, g, b, 0.08))
                elseif divider.gui2DividerRightLine.SetGradientAlpha then
                    divider.gui2DividerRightLine:SetGradientAlpha("HORIZONTAL", r, g, b, 0.88, r, g, b, 0.08)
                else
                    divider.gui2DividerRightLine:SetColorTexture(r, g, b, 0.72)
                end
            end
        else
            GUI2:SetTexturePaintKey(dividerLine, "color.border.subtle")
        end
    end
    frame:RefreshTheme()
    self:RegisterThemeObject(frame)
    return frame
end

function GUI2:CreateSwatch(parent, label, paintKey, width, height)
    local frame = self:CreateFrame(parent, {
        template = "BackdropTemplate",
        width = width or 150,
        height = height or 42,
    })
    self:ApplyBackdrop(frame, "color.surface.raised")
    self:CreateBorder(frame, "color.border.default")

    local chip = frame:CreateTexture(nil, "ARTWORK")
    chip:SetPoint("TOPLEFT", 6, -6)
    chip:SetPoint("BOTTOMLEFT", 6, 6)
    chip:SetWidth(34)
    ApplyPaint(chip, paintKey)

    local text = self:CreateText(frame, label, "font.size.sm", "color.text.primary")
    text:SetPoint("LEFT", chip, "RIGHT", 8, 0)
    text:SetPoint("RIGHT", -6, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)

    frame.gui2Surface = "color.surface.raised"
    frame.gui2Swatch = chip
    frame.gui2SwatchKey = paintKey
    frame.gui2Label = text
    return frame
end

function GUI2:RefreshPrimitive(frame)
    if not frame then return end
    if frame.gui2Surface and frame.SetBackdropColor then
        self:ApplyBackdrop(frame, frame.gui2Surface)
        frame:SetBackdropColor(self:GetColor(frame.gui2Surface))
    end
    if frame.gui2Borders then
        self:SetBorderColor(frame, frame.gui2Borders.colorKey)
        RefreshPixelObject(frame)
    end
    if frame.gui2Shadow and frame.gui2Shadow.SetBackdropBorderColor then
        frame.gui2Shadow:SetBackdropBorderColor(self:GetColor("color.overlay.shadow"))
    end
    if frame.gui2Swatch and frame.gui2SwatchKey then
        ApplyPaint(frame.gui2Swatch, frame.gui2SwatchKey)
    end
end
