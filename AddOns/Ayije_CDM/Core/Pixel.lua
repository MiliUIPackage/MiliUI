local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local CDM_C = CDM.CONST

local math_floor = math.floor
local math_ceil = math.ceil

local Pixel = {}
CDM.Pixel = Pixel

local cachedPixelSize = 1
local cachedPhysH = 0
local cachedScale = 1

function Pixel.Update()
    local physH = select(2, GetPhysicalScreenSize())
    local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if physH and physH > 0 and scale and scale > 0 then
        if physH == cachedPhysH and scale == cachedScale then
            return
        end
        cachedPhysH = physH
        cachedScale = scale
        cachedPixelSize = 768 / (physH * scale)
    end
end

function Pixel.GetSize()
    return cachedPixelSize
end

function Pixel.Snap(value)
    if not value or value == 0 then return 0 end
    local px = value / cachedPixelSize
    if px >= 0 then
        return math_floor(px + 0.5) * cachedPixelSize
    else
        return math_ceil(px - 0.5) * cachedPixelSize
    end
end

function Pixel.HalfFloor(value)
    if not value or value == 0 then return 0 end
    local px = math_floor(value / cachedPixelSize + 0.5)
    return math_floor(px / 2) * cachedPixelSize
end

function Pixel.SnapEven(value)
    if not value or value == 0 then return 0 end
    local px = value / cachedPixelSize
    if px >= 0 then
        px = math_floor(px + 0.5)
    else
        px = math_ceil(px - 0.5)
    end
    if px % 2 ~= 0 then px = px + 1 end
    return px * cachedPixelSize
end

function Pixel.SetPoint(frame, point, relativeTo, relativePoint, x, y)
    if not frame then return end
    frame:SetPoint(
        point,
        relativeTo,
        relativePoint,
        Pixel.Snap(x or 0),
        Pixel.Snap(y or 0)
    )
end

function Pixel.SetSize(frame, w, h)
    if not frame then return end
    frame:SetSize(Pixel.Snap(w), Pixel.Snap(h))
end

function Pixel.FontSize(desiredPx)
    return desiredPx * cachedScale
end

function Pixel.DisableTextureSnap(tex)
    if not tex then return end
    if tex.SetSnapToPixelGrid then
        tex:SetSnapToPixelGrid(false)
    end
    if tex.SetTexelSnappingBias then
        tex:SetTexelSnappingBias(0)
    end
end

function Pixel.CreateSolidTexture(parent, layer, sublevel)
    local tex = parent:CreateTexture(nil, layer or "OVERLAY", nil, sublevel or 0)
    tex:SetTexture(CDM_C.TEX_WHITE8X8)
    if tex.SetHorizTile then tex:SetHorizTile(false) end
    if tex.SetVertTile then tex:SetVertTile(false) end
    Pixel.DisableTextureSnap(tex)
    return tex
end

function Pixel.IsOneBorderMode()
    local borderFile = CDM_C.GetConfigValue("borderFile", "Ayije_Thin")
    if borderFile == "None" then
        return false
    end
    if borderFile == "1 Pixel" then
        return true
    end
    local borderSize = CDM_C.GetConfigValue("borderSize", 16)
    return math.max(0, math_floor(borderSize / cachedPixelSize + 0.5)) <= 1
end

function Pixel.ApplyBorderLines(lines, anchor, px, r, g, b, a)
    local top, bottom, left, right = lines[1], lines[2], lines[3], lines[4]

    for _, line in ipairs(lines) do
        line:SetVertexColor(r, g, b, a)
        line:Show()
    end

    top:ClearAllPoints()
    top:SetPoint("TOPLEFT", anchor, "TOPLEFT", px, 0)
    top:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -px, 0)
    top:SetHeight(px)

    bottom:ClearAllPoints()
    bottom:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", px, 0)
    bottom:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -px, 0)
    bottom:SetHeight(px)

    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, 0)
    left:SetWidth(px)

    right:ClearAllPoints()
    right:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(px)
end

if UIParent then
    Pixel.Update()
end
