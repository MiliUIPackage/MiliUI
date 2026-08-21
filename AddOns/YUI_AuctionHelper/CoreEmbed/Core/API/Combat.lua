do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...

YUI.API = YUI.API or {}
YUI.WOW_API = YUI.WOW_API or {}

local Combat = YUI.API.Combat or {}
YUI.API.Combat = Combat

local Legacy = YUI.WOW_API

function Combat.GetTime()
    if GetTime then
        return GetTime()
    end

    return 0
end

function Combat.InCombatLockdown()
    local Security = YUI.API and YUI.API.Security
    if Security and Security.InCombatLockdown then
        return Security.InCombatLockdown()
    end

    if InCombatLockdown then
        return InCombatLockdown()
    end

    return false
end

function Combat.UnitAffectingCombat(unit)
    unit = unit or "player"
    if UnitAffectingCombat then
        return UnitAffectingCombat(unit) == true
    end

    return Combat.InCombatLockdown() == true
end

Legacy.GetTime = Combat.GetTime
Legacy.InCombatLockdown = Combat.InCombatLockdown
Legacy.UnitAffectingCombat = Combat.UnitAffectingCombat
