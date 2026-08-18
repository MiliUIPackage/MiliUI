local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
end
local _, YUI = ...

YUI.Animation = YUI.Animation or {}

local Animation = YUI.Animation
local CombatAPI = YUI.API and YUI.API.Combat or YUI.WOW_API

Animation.version = Animation.version or 1
Animation.defaults = Animation.defaults or {
    duration = 0.2,
    easing = "out",
    mode = "replace",
}

Animation.handles = Animation.handles or {}
Animation.byOwner = Animation.byOwner or {}
Animation.byTarget = Animation.byTarget or {}
Animation.activeCount = Animation.activeCount or 0
Animation.nextId = Animation.nextId or 0

function Animation:Now()
    if CombatAPI and CombatAPI.GetTime then
        return CombatAPI.GetTime()
    end
    if GetTime then
        return GetTime()
    end
    return 0
end

function Animation:IsInCombatLockdown()
    if CombatAPI and CombatAPI.InCombatLockdown then
        return CombatAPI.InCombatLockdown()
    end
    if InCombatLockdown then
        return InCombatLockdown() and true or false
    end
    return false
end

function Animation:IsProtectedTarget(target)
    if not target or type(target.IsProtected) ~= "function" then
        return false
    end
    local ok, protected = pcall(target.IsProtected, target)
    return ok and protected == true
end

function Animation:CanAnimateTarget(target, spec)
    if not target then
        return false, "missing-target"
    end

    if self:IsInCombatLockdown() and self:IsProtectedTarget(target) then
        return false, "protected-combat"
    end

    return true
end

function Animation:GetDefaultDuration(spec)
    if type(spec) == "table" and type(spec.duration) == "number" then
        return spec.duration
    end
    return self.defaults.duration
end

function Animation:GetDefaultMode(spec)
    if type(spec) == "table" and spec.mode then
        return spec.mode
    end
    return self.defaults.mode
end

function Animation:GetDefaultEasing(spec)
    if type(spec) == "table" and spec.easing then
        return spec.easing
    end
    return self.defaults.easing
end

local function SettleObject(object, fullRefresh)
    if not object then
        return
    end
    if object.UpdateGUI2PixelScale then
        pcall(object.UpdateGUI2PixelScale, object)
    elseif object.UpdatePixelScale then
        pcall(object.UpdatePixelScale, object)
    end
    if fullRefresh and object.RefreshTheme then
        pcall(object.RefreshTheme, object)
    end
end

function Animation:SettleTarget(target, fullRefresh)
    if not target then
        return
    end

    SettleObject(target, fullRefresh)
    if target.gui2AnimationRoot and target.gui2AnimationRoot ~= target then
        SettleObject(target.gui2AnimationRoot, fullRefresh)
    end
    if target.gui2AnimationTarget and target.gui2AnimationTarget ~= target then
        SettleObject(target.gui2AnimationTarget, fullRefresh)
    end
    if target.gui2Borders then
        SettleObject(target, fullRefresh)
    end
end
