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

local math_floor = math.floor
local math_max = math.max

local function SetBorderColor(border, color)
    border:SetBackdropBorderColor(color.r, color.g, color.b, color.a)
    border.backdropBorderColor = color
    border.backdropBorderColorAlpha = color.a
end

local function DisableBorderSharpening(border)
    NineSliceUtil.DisableSharpening(border)
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

local function ApplyBorderPoints(host, border, offsetX, offsetY)
    border:ClearAllPoints()

    local Pixel = CDM.Pixel
    local w = host:GetWidth()
    local h = host:GetHeight()

    if w and w > 0 and h and h > 0 then
        local borderW = w - 2 * offsetX
        local borderH = h + 2 * offsetY
        if borderW > 0 and borderH > 0 then
            Pixel.SetPoint(border, "TOPLEFT", host, "TOPLEFT", offsetX, offsetY)
            Pixel.SetPoint(border, "BOTTOMRIGHT", host, "BOTTOMRIGHT", -offsetX, -offsetY)
            return
        end
    end

    border:SetPoint("TOPLEFT", host, "TOPLEFT", offsetX, offsetY)
    border:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -offsetX, -offsetY)
end

local function ApplyBorderToEntry(host, border, borderDef, offsetX, offsetY, defChanged)
    if not borderDef then
        if defChanged then
            border:SetBackdrop(nil)
        end
        border:Hide()
        return
    end
    if defChanged then
        border:SetBackdrop(borderDef)
        DisableBorderSharpening(border)
    end
    border:Show()
    local entry = BORDER.activeBorders[host]
    SetBorderColor(border, BORDER:ResolveCurrentBorderColor((entry and entry.colorFrame) or host))
    ApplyBorderPoints(host, border, offsetX, offsetY)
end

function BORDER:CreateBorder(host, forceUpdate)
    if not host then return end
    if host:GetObjectType() == "Texture" then host = host:GetParent() end

    local entry = BORDER.activeBorders[host]
    if not entry then
        entry = {}
        BORDER.activeBorders[host] = entry
    end

    if not forceUpdate and entry.border then return entry.border end

    local border = entry.border or host.cdmBorder
    if not border then
        border = CreateFrame("Frame", nil, host, "BackdropTemplate")
    end
    entry.border = border
    border:SetFrameLevel(host:GetFrameLevel() + 2)

    local borderDef, offsetX, offsetY = GetBorderDef()
    ApplyBorderToEntry(host, border, borderDef, offsetX, offsetY, true)
    return border
end

function BORDER:ResolveCurrentBorderColor(frame)
    if frame.cdmPandemicActive and frame.cdmPandemicAppliedColor then
        return frame.cdmPandemicAppliedColor
    end
    return frame.cdmBorderColorOverride
        or frame.cdmResolvedBorderColor
        or CDM_C.GetConfigValue("borderColor", DEFAULT_BORDER_COLOR)
end

function BORDER:SetBorderSuppressed(host, suppressed)
    local entry = host and BORDER.activeBorders[host]
    if not entry then return end
    if suppressed then
        entry.suppressed = true
        if entry.border then entry.border:Hide() end
    else
        entry.suppressed = nil
    end
end

function BORDER:UpdateBorder(host)
    if not host then return end
    local entry = BORDER.activeBorders[host]
    if not entry or not entry.border or entry.suppressed then return end

    local borderDef, offsetX, offsetY = GetBorderDef()
    ApplyBorderToEntry(host, entry.border, borderDef, offsetX, offsetY, true)
end

function BORDER:UpdateAllBorders()
    CDM.borderStyleVersion = (CDM.borderStyleVersion or 0) + 1

    local borderDef, offsetX, offsetY = GetBorderDef()
    local defChanged = borderDef ~= lastAppliedBorderDef
    lastAppliedBorderDef = borderDef

    for host, entry in pairs(BORDER.activeBorders) do
        if entry.border and not entry.suppressed then
            ApplyBorderToEntry(host, entry.border, borderDef, offsetX, offsetY, defChanged)
        end
    end
end

local function UpdateAllBorderColorSurfaces(frame, color)
    if frame and frame.cdmBorder then
        SetBorderColor(frame.cdmBorder, color)
    end
end

function BORDER:ApplyBorderColorOverride(frame, color)
    if not frame then return end
    frame.cdmBorderColorOverride = color
    if frame.cdmPandemicActive then return end
    UpdateAllBorderColorSurfaces(frame, color)
end

function BORDER:RestoreToCurrentBorderColor(frame)
    if not frame then return end
    frame.cdmBorderColorOverride = nil
    if frame.cdmPandemicActive then return end
    UpdateAllBorderColorSurfaces(frame, BORDER:ResolveCurrentBorderColor(frame))
end

function BORDER:ApplyPandemicBorderColor(frame, color, includeBuffBar)
    if not frame then return end
    frame.cdmPandemicAppliedColor = color
    UpdateAllBorderColorSurfaces(frame, color)
    if includeBuffBar and frame.cdmBarBorder then
        SetBorderColor(frame.cdmBarBorder, color)
        frame.cdmPandemicBarBorderColored = true
    end
end

function BORDER:ClearPandemicBorderColor(frame)
    if not frame then return end
    frame.cdmPandemicAppliedColor = nil
    UpdateAllBorderColorSurfaces(frame, BORDER:ResolveCurrentBorderColor(frame))
    if frame.cdmPandemicBarBorderColored and frame.cdmBarBorder then
        SetBorderColor(frame.cdmBarBorder, BORDER:ResolveCurrentBorderColor(frame))
        frame.cdmPandemicBarBorderColored = nil
    end
end

function BORDER:CommitResolvedBorderColor(frame, r, g, b)
    local resolved = frame.cdmResolvedBorderColor
    if not resolved then
        resolved = {}
        frame.cdmResolvedBorderColor = resolved
    end
    resolved.r = r
    resolved.g = g
    resolved.b = b
    resolved.a = 1

    if frame.cdmPandemicActive or frame.cdmBorderColorOverride then
        return resolved
    end

    UpdateAllBorderColorSurfaces(frame, resolved)
    return resolved
end

CDM:RegisterRefreshCallback("borders", function()
    CDM.BORDER:UpdateAllBorders()
end, 25, { "STYLE" })

function BORDER:InstallAcquireResetHook(v)
    hooksecurefunc(v, "OnAcquireItemFrame", function(_, itemFrame)
        if itemFrame.cdmPandemicActive then
            itemFrame.cdmPandemicActive = false
            BORDER:ClearPandemicBorderColor(itemFrame)
        end
        itemFrame.cdmBorderVersion = nil
        itemFrame.cdmIconBorderVersion = nil
        itemFrame.cdmBarBorderVersion = nil
    end)
end
