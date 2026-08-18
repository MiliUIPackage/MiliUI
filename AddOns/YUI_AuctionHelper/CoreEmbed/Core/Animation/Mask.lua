local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
end
local _, YUI = ...
local Animation = YUI.Animation
if not Animation then return end

local Mask = Animation.Mask or {}
Animation.Mask = Mask

local Controller = {}
Controller.__index = Controller

local function Clamp01(value)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

function Controller:SetProgress(value)
    value = Clamp01(value)
    self.value = value

    local texture = self.texture
    if not texture or type(texture.SetTexCoord) ~= "function" then
        return value
    end

    local orientation = self.orientation
    local direction = self.direction
    if orientation == "vertical" then
        if direction == "down" then
            texture:SetTexCoord(0, 1, 0, value)
        else
            texture:SetTexCoord(0, 1, 1 - value, 1)
        end
    else
        if direction == "right" then
            texture:SetTexCoord(0, value, 0, 1)
        else
            texture:SetTexCoord(1 - value, 1, 0, 1)
        end
    end

    return value
end

function Controller:TweenTo(value, options)
    options = type(options) == "table" and options or {}
    return Animation:Tween({
        owner = options.owner or self.owner or self,
        target = self.texture,
        key = options.key or "mask-progress",
        from = self.value or 0,
        to = Clamp01(value),
        duration = options.duration or 0.2,
        easing = options.easing,
        onUpdate = function(nextValue)
            self:SetProgress(nextValue)
        end,
    })
end

function Mask:Create(texture, opts)
    opts = type(opts) == "table" and opts or {}
    local controller = setmetatable({
        texture = texture,
        owner = opts.owner,
        orientation = opts.orientation or "horizontal",
        direction = opts.direction or "right",
        value = 0,
    }, Controller)
    controller:SetProgress(opts.value or opts.progress or 0)
    return controller
end
