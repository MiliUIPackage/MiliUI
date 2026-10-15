do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local YUI = _G.YUI
local GUI2 = YUI and YUI.GUI2
if not GUI2 then return end

local Assets = YUI.Assets
local issecretvalue = _G.issecretvalue
local function IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function Number(value, fallback)
    if IsSecret(value) then return fallback end
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return fallback end
    return value
end

local function Component(value, fallback)
    return math.max(0, math.min(1, Number(value, fallback)))
end

local bindings = setmetatable({}, { __mode = "k" })
local hookedFrames = setmetatable({}, { __mode = "k" })

local function InCombat()
    local combat = YUI.API and (YUI.API.Combat or YUI.API.Security)
    local query = combat and (combat.InCombatLockdown or combat.InCombat)
    return query and query() or (_G.InCombatLockdown and _G.InCombatLockdown()) or false
end

local function HideTexture(handle)
    if not handle.shown then return 0 end
    handle.texture:Hide()
    handle.shown = false
    return 1
end

GUI2.ShapeShadowDefaults = { color = { 0, 0, 0, 0.5 } }
GUI2.ShapeShadowMaterials = {}
for shape, aspect in pairs({
    square = 1, roundedSquare = 1, circle = 1,
    flatSquare = 1.35, flatRounded = 1.35,
    wideSquare = 10 / 9, wideRounded = 10 / 9,
}) do
    GUI2.ShapeShadowMaterials[shape] = {
        path = Assets:Core("gui2\\shapes\\shadow-" .. shape .. ".tga"),
        widthScale = 128 / 96,
        heightScale = 128 / (96 / aspect),
    }
end

-- Ownership stays in side tables; the frame's native scripts are preserved.
function GUI2:CreateShapeShadow(parent)
    if not parent or not parent.CreateTexture then return nil end
    if parent.IsForbidden and parent:IsForbidden() then return nil end
    local texture = parent:CreateTexture(nil, "BACKGROUND", nil, -8)
    texture:SetBlendMode("BLEND")
    if self.ApplyTexturePixelPolicy then self:ApplyTexturePixelPolicy(texture) end
    texture:Hide()
    return { texture = texture, parent = parent, shown = false }
end

function GUI2:HideShapeShadow(handle)
    if not handle then return 0 end
    if bindings[handle.parent] == handle then bindings[handle.parent] = nil end
    handle.contour, handle.boundStyle, handle.deferInCombat = nil, nil, nil
    handle.pending = nil
    return HideTexture(handle)
end

-- style: enabled/shape/color; geometry: anchor/width/height/offsetX/offsetY/allowLayout.
-- Configuration geometry is authoritative; native frame sizes are never queried.
function GUI2:ApplyShapeShadow(handle, style, geometry)
    if not handle or not style then return 0 end
    if IsSecret(style.enabled) or style.enabled ~= true then return self:HideShapeShadow(handle) end
    if not geometry or IsSecret(geometry.allowLayout) or geometry.allowLayout == false then
        handle.pending = true
        return 0
    end
    local width, height = Number(geometry.width, 0), Number(geometry.height, 0)
    if width <= 0 or height <= 0 or IsSecret(geometry.anchor) or not geometry.anchor then return self:HideShapeShadow(handle) end
    local shape = not IsSecret(style.shape) and style.shape or "square"
    local material = self.ShapeShadowMaterials[shape] or self.ShapeShadowMaterials.square
    local color = not IsSecret(style.color) and type(style.color) == "table" and style.color
        or self.ShapeShadowDefaults.color
    local r, g, b, a = Component(color[1], 0), Component(color[2], 0), Component(color[3], 0), Component(color[4], 0.5)
    if a <= 0 then return HideTexture(handle) end
    local writes, texture = 0, handle.texture
    if handle.path ~= material.path then
        texture:SetTexture(material.path)
        handle.path = material.path
        writes = writes + 1
    end
    local offsetX, offsetY = Number(geometry.offsetX, 0), Number(geometry.offsetY, 0)
    local renderWidth, renderHeight = width * material.widthScale, height * material.heightScale
    if handle.anchor ~= geometry.anchor or handle.width ~= renderWidth or handle.height ~= renderHeight
        or handle.offsetX ~= offsetX or handle.offsetY ~= offsetY then
        texture:ClearAllPoints()
        texture:SetPoint("CENTER", geometry.anchor, "CENTER", offsetX, offsetY)
        texture:SetSize(renderWidth, renderHeight)
        handle.anchor, handle.width, handle.height = geometry.anchor, renderWidth, renderHeight
        handle.offsetX, handle.offsetY = offsetX, offsetY
        writes = writes + 3
    end
    if handle.r ~= r or handle.g ~= g or handle.b ~= b or handle.a ~= a then
        texture:SetVertexColor(r, g, b, a)
        handle.r, handle.g, handle.b, handle.a = r, g, b, a
        writes = writes + 1
    end
    if not handle.shown then
        texture:Show()
        handle.shown = true
        writes = writes + 1
    end
    handle.pending = nil
    return writes
end

local function ReadContourSize(contour)
    if IsSecret(contour) or not contour then return nil end
    if contour.IsForbidden and contour:IsForbidden() then return nil end
    local ok, width, height
    if contour.GetSize then
        ok, width, height = pcall(contour.GetSize, contour)
    elseif contour.GetWidth and contour.GetHeight then
        ok, width = pcall(contour.GetWidth, contour)
        if ok then ok, height = pcall(contour.GetHeight, contour) end
    end
    if not ok then return nil end
    width, height = Number(width, nil), Number(height, nil)
    if not width or not height or width <= 0 or height <= 0 then return nil end
    return width, height
end

local OnBoundSizeChanged

local function RefreshBinding(handle)
    if handle.deferInCombat and InCombat() then
        handle.pending = true
        return 0
    end
    local parent = handle.parent
    if not hookedFrames[parent] then
        if not parent.HookScript then return GUI2:HideShapeShadow(handle) end
        local ok = pcall(parent.HookScript, parent, "OnSizeChanged", OnBoundSizeChanged)
        if not ok then return GUI2:HideShapeShadow(handle) end
        hookedFrames[parent] = true
    end
    local width, height = ReadContourSize(handle.contour)
    if not width then
        handle.pending = true
        return HideTexture(handle)
    end
    local geometry = handle.boundGeometry
    geometry.anchor, geometry.width, geometry.height = handle.contour, width, height
    handle.pending = nil
    return GUI2:ApplyShapeShadow(handle, handle.boundStyle, geometry)
end

OnBoundSizeChanged = function(frame)
    local handle = bindings[frame]
    if handle then RefreshBinding(handle) end
end

-- The visible contour, also used by the border, is the only geometry source.
function GUI2:BindShapeShadow(handle, style, contour, deferInCombat)
    if not handle or not style then return 0 end
    if IsSecret(style.enabled) or style.enabled ~= true then return self:HideShapeShadow(handle) end
    if IsSecret(contour) or not contour then return self:HideShapeShadow(handle) end
    local parent = handle.parent
    local previous = bindings[parent]
    if previous and previous ~= handle then self:HideShapeShadow(previous) end
    handle.boundGeometry = handle.boundGeometry or {}
    handle.contour, handle.boundStyle, handle.deferInCombat = contour, style, deferInCombat == true
    bindings[parent] = handle
    return RefreshBinding(handle)
end

-- Reuse the consumers' existing out-of-combat lifecycle; no extra event owner.
function GUI2:FlushShapeShadowBindings()
    if InCombat() then return 0 end
    local writes = 0
    for _, handle in pairs(bindings) do
        if handle.pending then writes = writes + RefreshBinding(handle) end
    end
    return writes
end
