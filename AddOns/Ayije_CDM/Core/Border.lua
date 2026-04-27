local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local BORDER = {}
CDM.BORDER = BORDER
local CDM_C = CDM.CONST

local LSM = LibStub("LibSharedMedia-3.0", true)

if LSM then
    LSM:Register("border", "Ayije_Thin", "Interface\\AddOns\\Ayije_CDM\\Media\\Borders\\Ayije_Thin.tga")
    LSM:Register("border", "Ayije_Empty", "Interface\\AddOns\\Ayije_CDM\\Media\\Borders\\Ayije_Empty.tga")
    LSM:Register("border", "1 Pixel", "Interface\\Buttons\\WHITE8X8")
end

BORDER.activeBorders = setmetatable({}, { __mode = "k" })
local DEFAULT_BORDER_COLOR = { r = 1, g = 1, b = 1, a = 1 }
local GetFrameData = CDM.GetFrameData

local math_floor = math.floor
local math_max = math.max

local function SetBorderColor(border, color)
    border:SetBackdropBorderColor(color.r, color.g, color.b, color.a)
    border.backdropBorderColor = color
    border.backdropBorderColorAlpha = color.a
end

local function DisableBorderSharpening(border)
    if NineSliceUtil and NineSliceUtil.DisableSharpening then
        NineSliceUtil.DisableSharpening(border)
    end
end

local cachedBorderDef = nil
local cachedBorderFile = nil
local cachedBorderSize = nil
local cachedBorderOnePixel = nil
local lastAppliedBorderDef = nil

local function GetBorderDef()
    local borderKey = CDM_C.GetConfigValue("borderFile", "Ayije_Thin")
    local borderFile
    if LSM then
        local path = LSM:Fetch("border", borderKey)
        if path and path ~= "" then borderFile = path end
    end
    if not borderFile and borderKey ~= "None" then
        borderFile = "Interface\\AddOns\\Ayije_CDM\\Media\\Borders\\Ayije_Thin.tga"
    end

    local offsetX = CDM_C.GetConfigValue("borderOffsetX", -8)
    local offsetY = CDM_C.GetConfigValue("borderOffsetY", 8)

    if not borderFile then return nil, offsetX, offsetY end

    local Pixel = CDM.Pixel
    local rawBorderSize = CDM_C.GetConfigValue("borderSize", 16)
    local onePixel = Pixel.GetSize()
    if not cachedBorderDef
        or cachedBorderFile ~= borderFile
        or cachedBorderSize ~= rawBorderSize
        or cachedBorderOnePixel ~= onePixel
    then
        local borderPixels = math_max(1, math_floor(rawBorderSize / onePixel))
        local borderSize = borderPixels * onePixel
        local insetPixels = math_floor(borderPixels / 2)
        local insetSize = insetPixels * onePixel
        cachedBorderDef = {
            bgFile = nil,
            edgeFile = borderFile,
            tileSize = 0,
            edgeSize = borderSize,
            insets = { left = insetSize, right = insetSize, top = insetSize, bottom = insetSize }
        }
        cachedBorderFile = borderFile
        cachedBorderSize = rawBorderSize
        cachedBorderOnePixel = onePixel
    end

    return cachedBorderDef, offsetX, offsetY
end

local function ApplyBorderPoints(frame, border, meta, offsetX, offsetY)
    border:ClearAllPoints()

    local anchor = meta.anchor1 or (meta.backdrop and frame.backdrop or frame)
    local p1 = meta.p1 or offsetX
    local p2 = meta.p2 or offsetY
    local p3 = meta.p3 or -offsetX
    local p4 = meta.p4 or -offsetY

    local anchor2 = meta.anchor2 or anchor
    local Pixel = CDM.Pixel
    local w = anchor:GetWidth()
    local h = anchor:GetHeight()

    if w and w > 0 and h and h > 0 then
        local borderW = w + p3 - p1
        local borderH = h + p2 - p4
        if borderW > 0 and borderH > 0 then
            Pixel.SetPoint(border, "TOPLEFT", anchor, "TOPLEFT", p1, p2)
            Pixel.SetPoint(border, "BOTTOMRIGHT", anchor2, "BOTTOMRIGHT", p3, p4)
            return
        end
    end

    border:SetPoint("TOPLEFT", anchor, "TOPLEFT", p1, p2)
    border:SetPoint("BOTTOMRIGHT", anchor2, "BOTTOMRIGHT", p3, p4)
end

function BORDER:CreateBorder(frame, opts)
    if not frame then return end
    if frame:GetObjectType() == "Texture" then frame = frame:GetParent() end

    opts = opts or {}
    local frameLevel = opts.frameLevel
    local offsets = opts.offsets
    local p1 = offsets and offsets[1]
    local p2 = offsets and offsets[2]
    local p3 = offsets and offsets[3]
    local p4 = offsets and offsets[4]
    local backdrop = opts.backdrop
    local event = opts.event
    local anchors = opts.anchors
    local anchor1 = anchors and anchors[1]
    local anchor2 = anchors and anchors[2]
    local forceUpdate = opts.forceUpdate

    local meta = BORDER.activeBorders[frame]
    if not meta then
        meta = {}
        BORDER.activeBorders[frame] = meta
    end
    meta.frameLevel = frameLevel
    meta.p1 = p1
    meta.p2 = p2
    meta.p3 = p3
    meta.p4 = p4
    meta.backdrop = backdrop
    meta.anchor1 = anchor1
    meta.anchor2 = anchor2

    if not forceUpdate and frame.border then return end

    local borderDef, offsetX, offsetY = GetBorderDef()

    local border = frame.border
    if not border then
        border = CreateFrame("Frame", nil, (backdrop and frame.backdrop or frame), "BackdropTemplate")
        frame.border = border
    end

    border:SetFrameLevel((frameLevel and frame:GetFrameLevel() + frameLevel) or frame:GetFrameLevel() + 2)

    if not borderDef then
        border:SetBackdrop(nil)
        border:Hide()
        return
    end

    border:SetBackdrop(borderDef)
    DisableBorderSharpening(border)
    border:Show()
    ApplyBorderPoints(frame, border, meta, offsetX, offsetY)

    local frameData = GetFrameData(frame)
    local color = frameData.cdmBorderColorOverride or CDM_C.GetConfigValue("borderColor", DEFAULT_BORDER_COLOR)
    SetBorderColor(border, color)

    if event then
        if not frameData.cdmBorderHooked then
            frameData.cdmBorderHooked = true
            frame:HookScript("OnEnter", function()
                border:SetBackdropBorderColor(1, 0.78, 0.03, 1)
            end)
            frame:HookScript("OnLeave", function()
                local fd = GetFrameData(frame)
                local c = fd.cdmBorderColorOverride or CDM_C.GetConfigValue("borderColor", DEFAULT_BORDER_COLOR)
                SetBorderColor(border, c)
            end)
        end
    end
end

function BORDER:UpdateBorder(frame)
    if not frame then return end
    local meta = BORDER.activeBorders[frame]
    if not meta then return end
    if not frame.border then return end

    local borderDef, offsetX, offsetY = GetBorderDef()
    if not borderDef then
        frame.border:SetBackdrop(nil)
        frame.border:Hide()
    else
        frame.border:SetBackdrop(borderDef)
        DisableBorderSharpening(frame.border)
        frame.border:Show()
        local frameData = GetFrameData(frame)
        local color = frameData.cdmBorderColorOverride or frameData.cdmResolvedBorderColor or CDM_C.GetConfigValue("borderColor", DEFAULT_BORDER_COLOR)
        SetBorderColor(frame.border, color)
        ApplyBorderPoints(frame, frame.border, meta, offsetX, offsetY)
    end
end

function BORDER:UpdateAllBorders()
    CDM.borderStyleVersion = (CDM.borderStyleVersion or 0) + 1

    local borderDef, offsetX, offsetY = GetBorderDef()
    local color = CDM_C.GetConfigValue("borderColor", DEFAULT_BORDER_COLOR)
    local defChanged = borderDef ~= lastAppliedBorderDef
    lastAppliedBorderDef = borderDef

    for frame, meta in pairs(BORDER.activeBorders) do
        if frame.border then
            if not borderDef then
                if defChanged then
                    frame.border:SetBackdrop(nil)
                end
                frame.border:Hide()
            else
                if defChanged then
                    frame.border:SetBackdrop(borderDef)
                    DisableBorderSharpening(frame.border)
                end
                frame.border:Show()
                local frameData = GetFrameData(frame)
                local c = frameData.cdmBorderColorOverride or frameData.cdmResolvedBorderColor or color
                SetBorderColor(frame.border, c)
                ApplyBorderPoints(frame, frame.border, meta, offsetX, offsetY)
            end
        end
    end
end

local function UpdateAllBorderColorSurfaces(frame, frameData, color)
    if frame.border then
        SetBorderColor(frame.border, color)
    end
    local wrapperBorder = frameData.borderFrame and frameData.borderFrame.border
    if wrapperBorder then
        SetBorderColor(wrapperBorder, color)
    end
end

function BORDER:ApplyBorderColorOverride(frame, color)
    if not frame then return end
    local frameData = GetFrameData(frame)
    frameData.cdmBorderColorOverride = color
    UpdateAllBorderColorSurfaces(frame, frameData, color)
end

function BORDER:RestoreToCurrentBorderColor(frame)
    if not frame then return end
    local frameData = GetFrameData(frame)
    frameData.cdmBorderColorOverride = nil
    UpdateAllBorderColorSurfaces(frame, frameData, frameData.cdmResolvedBorderColor or CDM_C.GetConfigValue("borderColor", DEFAULT_BORDER_COLOR))
end

CDM:RegisterRefreshCallback("borders", function()
    CDM.BORDER:UpdateAllBorders()
end, 25, { "STYLE" })
