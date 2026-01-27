-- Swipe Module - Custom Active Buff/Debuff Coloring
--
-- Recolors the cooldown swipe using SetSwipeColor() on the Cooldown frame

local _, ns = ...

local Swipe = {}
ns.Swipe = Swipe

local LSM = LibStub("LibSharedMedia-3.0", true)

local areHooksInitialized = false

local viewersSettingKey = {
    EssentialCooldownViewer = "Essential",
    UtilityCooldownViewer = "Utility",
    BuffIconCooldownViewer = "BuffIcons",
}

local DEFAULT_SWIPE_COLORS = {
    cd = CooldownViewerConstants.ITEM_COOLDOWN_COLOR, -- CreateColor(0, 0, 0, 0.7);
    aura = CooldownViewerConstants.ITEM_AURA_COLOR, -- CreateColor(1, 0.95, 0.57, 0.7);
}

local function IsCustomSwipeEnabled()
    if not ns.db or not ns.db.profile then
        return false
    end
    return ns.db.profile.cooldownManager_customSwipeColor_enabled or false
end

local function GetCustomActiveSwipe()
    local r = ns.db.profile.cooldownManager_customActiveColor_r or 1
    local g = ns.db.profile.cooldownManager_customActiveColor_g or 0.95
    local b = ns.db.profile.cooldownManager_customActiveColor_b or 0.57
    local a = ns.db.profile.cooldownManager_customActiveColor_a or 0.69
    return r, g, b, a
end

local function GetCustomGCDSwipe()
    local r = ns.db.profile.cooldownManager_customCDSwipeColor_r or 0
    local g = ns.db.profile.cooldownManager_customCDSwipeColor_g or 0
    local b = ns.db.profile.cooldownManager_customCDSwipeColor_b or 0
    local a = ns.db.profile.cooldownManager_customCDSwipeColor_a or 0.69
    return r, g, b, a
end

local function ApplySwipeColor(iconCooldown, r, g, b, a)
    if not iconCooldown then
        return
    end
    if not IsCustomSwipeEnabled() then
        return
    end
    local current = CreateColor(r, g, b, a)
    local swipeType = nil
    for name, v in pairs(DEFAULT_SWIPE_COLORS) do
        if AreColorsEqual(current, v) then
            swipeType = name
            break
        end
    end
    if not swipeType then
        return
    end

    if swipeType == "aura" then
        local _r, _g, _b, _a = GetCustomActiveSwipe()
        iconCooldown:SetSwipeColor(_r, _g, _b, _a)
    elseif swipeType == "cd" then
        local _r, _g, _b, _a = GetCustomGCDSwipe()
        iconCooldown:SetSwipeColor(_r, _g, _b, _a)
    end
end

-- Hook into the icon to recolor the swipe when cooldowns change
local function HookIconCooldown(icon, viewerSettingName)
    if icon._cmcSwipeColorHooked then
        return
    end

    icon._cmcSwipeColorHooked = true
    hooksecurefunc(icon.Cooldown, "SetSwipeColor", function(self, r, g, b, a)
        if IsCustomSwipeEnabled() then
            ApplySwipeColor(self, r, g, b, a)
        end
    end)
end

-- Process all children of a viewer
local function ProcessViewer(viewerName)
    local viewer = _G[viewerName]
    if not viewer or not ns.Runtime:IsReady(viewerName) then
        return
    end

    local settingName = viewersSettingKey[viewerName]
    if not settingName then
        return
    end

    local children = { viewer:GetChildren() }
    for _, child in ipairs(children) do
        if child.Icon and child.Cooldown and not child._cmcSwipeColorHooked then
            HookIconCooldown(child, settingName)
        end
    end
end

function Swipe:RefreshViewer(viewerName)
    ProcessViewer(viewerName)
end

function Swipe:RefreshAll()
    for viewerName, _ in pairs(viewersSettingKey) do
        ProcessViewer(viewerName)
    end
end

function Swipe:Enable()
    if not areHooksInitialized then
        areHooksInitialized = true

        for viewerName, _ in pairs(viewersSettingKey) do
            local viewer = _G[viewerName]
            if viewer then
                hooksecurefunc(viewer, "RefreshLayout", function()
                    Swipe:RefreshViewer(viewerName)
                end)
            end
        end
    end

    self:RefreshAll()
end

function Swipe:Initialize()
    self:Enable()
end
