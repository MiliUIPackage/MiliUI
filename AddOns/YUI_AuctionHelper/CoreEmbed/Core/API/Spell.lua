local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
end
local _, YUI = ...

YUI.API = YUI.API or {}
YUI.WOW_API = YUI.WOW_API or {}

local Spell = YUI.API.Spell or {}
YUI.API.Spell = Spell

local Legacy = YUI.WOW_API
local DEFAULT_ACTION_SLOT_SCAN_MAX = 180
local GCD_SPELL_ID = 61304
local cooldownProbeHost
local cooldownProbes = {}

local function IsSecretValue(value)
    local security = YUI.API and YUI.API.Security
    if security and security.IsSecretValue then
        return security.IsSecretValue(value) == true
    end

    if not issecretvalue then
        return false
    end

    local ok, isSecret = pcall(issecretvalue, value)
    return ok and isSecret == true
end

local function SafeRawValue(value)
    if IsSecretValue(value) or value == nil then
        return nil
    end
    return value
end

local function SafeNumberValue(value)
    if IsSecretValue(value) or value == nil then
        return nil
    end

    local ok, numberValue = pcall(tonumber, value)
    if ok and not IsSecretValue(numberValue) and numberValue ~= nil then
        return numberValue
    end
    return nil
end

local function SafeBooleanValue(value, fallback)
    if IsSecretValue(value) or value == nil then
        return fallback
    end
    if value == false or value == 0 then
        return false
    end
    if value == true or value == 1 then
        return true
    end
    return value and true or false
end

local function FirstSafeRawValue(...)
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if not IsSecretValue(value) and value ~= nil then
            return value
        end
    end
    return nil
end

local function FirstSafeNumberValue(...)
    for i = 1, select("#", ...) do
        local numberValue = SafeNumberValue(select(i, ...))
        if numberValue ~= nil then
            return numberValue
        end
    end
    return nil
end

local function FirstSafeBooleanValue(fallback, ...)
    for i = 1, select("#", ...) do
        local rawValue = select(i, ...)
        local boolValue = SafeBooleanValue(rawValue, nil)
        if boolValue ~= nil then
            return boolValue
        end
    end
    return fallback
end

local function NormalizeInfo(name, iconID, originalIconID, castTime, minRange, maxRange, spellID)
    if not name then return nil end

    return {
        name = name,
        iconID = iconID,
        originalIconID = originalIconID,
        castTime = castTime,
        minRange = minRange,
        maxRange = maxRange,
        spellID = spellID,
    }
end

local function GetInfoFromCSpell(spellID)
    if not C_Spell or not C_Spell.GetSpellInfo then return nil end

    local info = C_Spell.GetSpellInfo(spellID)
    if type(info) == "table" then
        return NormalizeInfo(
            info.name,
            info.iconID,
            info.originalIconID,
            info.castTime,
            info.minRange,
            info.maxRange,
            info.spellID
        )
    end

    return nil
end

local function GetInfoFromGlobal(spellID)
    if not GetSpellInfo then return nil end

    local name, _, iconID, castTime, minRange, maxRange, resolvedSpellID = GetSpellInfo(spellID)
    return NormalizeInfo(name, iconID, iconID, castTime, minRange, maxRange, resolvedSpellID or spellID)
end

function Spell.GetInfo(spellID)
    if not spellID then return nil end

    if YUI.IsRetail then
        return GetInfoFromCSpell(spellID) or GetInfoFromGlobal(spellID)
    end

    if YUI.IsMists then
        return GetInfoFromGlobal(spellID) or GetInfoFromCSpell(spellID)
    end

    if YUI.IsWrath then
        return GetInfoFromGlobal(spellID) or GetInfoFromCSpell(spellID)
    end

    return GetInfoFromGlobal(spellID) or GetInfoFromCSpell(spellID)
end

local function GetTextureFromCSpell(spellID)
    if C_Spell and C_Spell.GetSpellTexture then
        local texture = C_Spell.GetSpellTexture(spellID)
        if texture then return texture end
    end
    return nil
end

local function GetTextureFromGlobal(spellID)
    if GetSpellTexture then
        local texture = GetSpellTexture(spellID)
        if texture then return texture end
    end

    local info = GetInfoFromGlobal(spellID)
    return info and info.iconID or nil
end

function Spell.GetName(spellID)
    local info = Spell.GetInfo(spellID)
    return info and info.name or nil
end

function Spell.GetTexture(spellID)
    if not spellID then return nil end

    if YUI.IsRetail then
        return GetTextureFromCSpell(spellID) or GetTextureFromGlobal(spellID)
    end

    if YUI.IsMists then
        return GetTextureFromGlobal(spellID) or GetTextureFromCSpell(spellID)
    end

    if YUI.IsWrath then
        return GetTextureFromGlobal(spellID) or GetTextureFromCSpell(spellID)
    end

    return GetTextureFromGlobal(spellID) or GetTextureFromCSpell(spellID)
end

local function HasRangeFromCSpell(spellID)
    if C_Spell and C_Spell.SpellHasRange then
        local ok, result = pcall(C_Spell.SpellHasRange, spellID)
        if ok then
            return SafeBooleanValue(result, nil)
        end
    end
    return nil
end

local function HasRangeFromGlobal(spellID)
    if SpellHasRange then
        local ok, result = pcall(SpellHasRange, spellID)
        if ok then
            local normalized = SafeBooleanValue(result, nil)
            if normalized ~= nil then
                return normalized
            end
        end

        local name = Spell.GetName and Spell.GetName(spellID)
        if name then
            ok, result = pcall(SpellHasRange, name)
            if ok then
                return SafeBooleanValue(result, nil)
            end
        end
    end
    return nil
end

function Spell.HasRange(spellID)
    if not spellID then return nil end

    if YUI.IsRetail then
        local result = HasRangeFromCSpell(spellID)
        if result ~= nil then return result end
        return HasRangeFromGlobal(spellID)
    end

    local result = HasRangeFromGlobal(spellID)
    if result ~= nil then return result end
    return HasRangeFromCSpell(spellID)
end

local function IsInRangeFromCSpell(spellID, unit)
    if C_Spell and C_Spell.IsSpellInRange then
        local ok, result = pcall(C_Spell.IsSpellInRange, spellID, unit)
        if ok then
            return SafeBooleanValue(result, nil)
        end
    end
    return nil
end

local function IsInRangeFromGlobal(spellID, unit)
    if IsSpellInRange then
        local ok, result = pcall(IsSpellInRange, spellID, unit)
        if ok then
            local normalized = SafeBooleanValue(result, nil)
            if normalized ~= nil then
                return normalized
            end
        end

        local name = Spell.GetName and Spell.GetName(spellID)
        if name then
            ok, result = pcall(IsSpellInRange, name, unit)
            if ok then
                return SafeBooleanValue(result, nil)
            end
        end
    end
    return nil
end

function Spell.IsInRange(spellID, unit)
    if not spellID then return nil end
    unit = unit or "target"

    if YUI.IsRetail then
        local result = IsInRangeFromCSpell(spellID, unit)
        if result ~= nil then return result end
        return IsInRangeFromGlobal(spellID, unit)
    end

    local result = IsInRangeFromGlobal(spellID, unit)
    if result ~= nil then return result end
    return IsInRangeFromCSpell(spellID, unit)
end

local function NormalizeCooldown(startTime, duration, isEnabled, modRate)
    if IsSecretValue(startTime) then
        return nil
    end

    if type(startTime) == "table" then
        local info = startTime
        local safeStart = FirstSafeNumberValue(info.startTime, info.startTimeSeconds)
        local safeDuration = FirstSafeNumberValue(info.duration, info.durationSeconds)
        if safeStart == nil or safeDuration == nil then
            return nil
        end

        return {
            startTime = safeStart,
            duration = safeDuration,
            isEnabled = FirstSafeBooleanValue(true, info.isEnabled, info.enable, info.enableCooldownTimer),
            modRate = FirstSafeNumberValue(info.modRate) or 1,
        }
    end

    if IsSecretValue(duration) then
        return nil
    end

    if FirstSafeRawValue(startTime, duration, isEnabled, modRate) == nil then
        return nil
    end

    return {
        startTime = SafeNumberValue(startTime) or 0,
        duration = SafeNumberValue(duration) or 0,
        isEnabled = SafeBooleanValue(isEnabled, true),
        modRate = SafeNumberValue(modRate) or 1,
    }
end

local function GetCooldownFromCSpell(spellID)
    if not C_Spell or not C_Spell.GetSpellCooldown then return nil end
    local ok, startTime, duration, isEnabled, modRate = pcall(C_Spell.GetSpellCooldown, spellID)
    if ok then
        return NormalizeCooldown(startTime, duration, isEnabled, modRate)
    end
    return nil
end

local function GetCooldownFromGlobal(spellID)
    if not GetSpellCooldown then return nil end
    local ok, startTime, duration, isEnabled, modRate = pcall(GetSpellCooldown, spellID)
    if ok then
        return NormalizeCooldown(startTime, duration, isEnabled, modRate)
    end
    return nil
end

function Spell.GetCooldown(spellID)
    if not spellID then return nil end

    if YUI.IsRetail then
        return GetCooldownFromCSpell(spellID) or GetCooldownFromGlobal(spellID)
    end

    if YUI.IsMists then
        return GetCooldownFromGlobal(spellID) or GetCooldownFromCSpell(spellID)
    end

    if YUI.IsWrath then
        return GetCooldownFromGlobal(spellID) or GetCooldownFromCSpell(spellID)
    end

    return GetCooldownFromGlobal(spellID) or GetCooldownFromCSpell(spellID)
end

function Spell.GetCooldownDurationObject(spellID)
    spellID = SafeNumberValue(spellID)
    if not (spellID and C_Spell and C_Spell.GetSpellCooldownDuration) then
        return nil
    end

    local ok, durationObject = pcall(C_Spell.GetSpellCooldownDuration, spellID)
    if ok then
        return durationObject
    end
    return nil
end

local function ReadDurationObjectMethod(durationObject, methodName)
    if durationObject == nil or type(methodName) ~= "string" then
        return nil, false
    end
    local ok, value = pcall(function()
        local method = durationObject[methodName]
        if type(method) ~= "function" then
            return nil
        end
        return method(durationObject)
    end)
    if ok then
        return value, true
    end
    return nil, false
end

function Spell.GetCooldownDurationState(spellID)
    spellID = SafeNumberValue(spellID)
    if not spellID then
        return {
            ready = nil,
            remainingSeconds = nil,
            durationObject = nil,
            readyRaw = nil,
            reason = "no-spell",
            source = "duration-object",
        }
    end

    local durationObject = Spell.GetCooldownDurationObject(spellID)
    if not durationObject then
        return {
            ready = nil,
            remainingSeconds = nil,
            durationObject = nil,
            readyRaw = nil,
            reason = "no-duration-object",
            source = "duration-object",
        }
    end

    local readyRaw, readyRawOK = ReadDurationObjectMethod(durationObject, "IsZero")
    local ready = readyRawOK and SafeBooleanValue(readyRaw, nil) or nil
    local remainingRaw, remainingOK = ReadDurationObjectMethod(durationObject, "GetRemainingDuration")
    local remaining = remainingOK and SafeNumberValue(remainingRaw) or nil

    local reason = "unknown"
    if ready == true then
        remaining = 0
        reason = "ready"
    elseif ready == false then
        reason = "cooldown"
    elseif remaining ~= nil then
        if remaining > 0 then
            ready = false
            reason = "cooldown"
        else
            ready = true
            remaining = 0
            reason = "ready"
        end
    elseif readyRawOK == false then
        reason = "no-iszero"
    elseif remainingOK == false then
        reason = "no-remaining"
    end

    return {
        ready = ready,
        remainingSeconds = remaining,
        durationObject = durationObject,
        readyRaw = readyRaw,
        readyRawOK = readyRawOK,
        remainingRaw = remainingRaw,
        remainingRawOK = remainingOK,
        reason = reason,
        source = "duration-object",
    }
end

local function EnsureCooldownProbe(spellID)
    if not UIParent or not CreateFrame then
        return nil, "no-ui"
    end

    if not cooldownProbeHost then
        cooldownProbeHost = CreateFrame("Frame", nil, UIParent)
        cooldownProbeHost:SetSize(1, 1)
        cooldownProbeHost:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -8, -8)
        cooldownProbeHost:SetAlpha(0)
        cooldownProbeHost:EnableMouse(false)
        cooldownProbeHost:Show()
    end

    local probe = cooldownProbes[spellID]
    if probe then
        cooldownProbeHost:Show()
        return probe
    end

    local cooldown = CreateFrame("Cooldown", nil, cooldownProbeHost, "CooldownFrameTemplate")
    cooldown:SetAllPoints(cooldownProbeHost)
    if cooldown.SetDrawSwipe then cooldown:SetDrawSwipe(false) end
    if cooldown.SetDrawEdge then cooldown:SetDrawEdge(false) end
    if cooldown.SetDrawBling then cooldown:SetDrawBling(false) end
    if cooldown.SetHideCountdownNumbers then cooldown:SetHideCountdownNumbers(true) end
    cooldown:SetAlpha(0)
    cooldown:EnableMouse(false)
    probe = {
        spellID = spellID,
        cooldown = cooldown,
    }
    cooldownProbes[spellID] = probe
    return probe
end

local function ReadRetailCooldownInfo(spellID)
    if not (C_Spell and C_Spell.GetSpellCooldown) then return nil end
    local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
    if ok and type(info) == "table" then
        return info
    end
    return nil
end

local function IsGCDOnly(spellID)
    local info = ReadRetailCooldownInfo(spellID)
    if info and SafeBooleanValue(info.isOnGCD, nil) == true then
        return true
    end

    if spellID == GCD_SPELL_ID then
        return true
    end
    return false
end

function Spell.GetCooldownProbeState(spellID)
    spellID = SafeNumberValue(spellID)
    if not spellID then
        return {
            ready = nil,
            state = "unknown",
            reason = "no-spell",
            source = "native-cooldown-probe",
        }
    end

    if not YUI.IsRetail then
        local cd = Spell.GetCooldown(spellID)
        if type(cd) ~= "table" then
            return {
                ready = nil,
                state = "unknown",
                reason = "no-cooldown-api",
                source = "spell-api",
                spellID = spellID,
            }
        end
        local startTime = SafeNumberValue(cd.startTime)
        local duration = SafeNumberValue(cd.duration)
        local enabled = SafeBooleanValue(cd.isEnabled, true)
        if enabled == false or startTime == nil or duration == nil then
            return {
                ready = nil,
                state = "unknown",
                reason = enabled == false and "disabled" or "unsafe-values",
                source = "spell-api",
                spellID = spellID,
            }
        end
        if startTime <= 0 or duration <= 1.5 then
            return {
                ready = true,
                state = "ready",
                reason = "ready",
                source = "spell-api",
                spellID = spellID,
            }
        end
        local remaining = startTime + duration - GetTime()
        if remaining > 0 then
            return {
                ready = false,
                state = "cooldown",
                reason = "cooldown",
                source = "spell-api",
                spellID = spellID,
                remainingSeconds = remaining,
            }
        end
        return {
            ready = true,
            state = "ready",
            reason = "expired",
            source = "spell-api",
            spellID = spellID,
        }
    end

    local probe, probeReason = EnsureCooldownProbe(spellID)
    if not (probe and probe.cooldown) then
        return {
            ready = nil,
            state = "unknown",
            reason = probeReason or "no-probe",
            source = "native-cooldown-probe",
            spellID = spellID,
        }
    end

    local cooldown = probe.cooldown
    if cooldown.Clear then
        pcall(cooldown.Clear, cooldown)
    end

    local cooldownInfo = ReadRetailCooldownInfo(spellID)
    if cooldownInfo and SafeBooleanValue(cooldownInfo.isOnGCD, nil) == true then
        probe.lastState = "ready"
        return {
            ready = true,
            state = "ready",
            reason = "gcd-only",
            source = "native-cooldown-probe",
            spellID = spellID,
        }
    end
    if cooldownInfo and SafeBooleanValue(cooldownInfo.isActive, true) == false then
        probe.lastState = "ready"
        return {
            ready = true,
            state = "ready",
            reason = "inactive",
            source = "native-cooldown-probe",
            spellID = spellID,
        }
    end
    if IsGCDOnly(spellID) then
        probe.lastState = "ready"
        return {
            ready = true,
            state = "ready",
            reason = "gcd-only",
            source = "native-cooldown-probe",
            spellID = spellID,
        }
    end

    local durationObject = Spell.GetCooldownDurationObject(spellID)
    if not durationObject then
        return {
            ready = nil,
            state = "unknown",
            reason = "no-duration-object",
            source = "native-cooldown-probe",
            spellID = spellID,
        }
    end

    local setOK = false
    if cooldown.SetCooldownFromDurationObject then
        setOK = pcall(cooldown.SetCooldownFromDurationObject, cooldown, durationObject, true) == true
    end
    if not setOK then
        return {
            ready = nil,
            state = "unknown",
            reason = "set-failed",
            source = "native-cooldown-probe",
            spellID = spellID,
            durationObject = durationObject,
        }
    end

    local shown = cooldown.IsShown and cooldown:IsShown() == true
    local state = shown and "cooldown" or "ready"
    probe.lastState = state
    return {
        ready = not shown,
        state = state,
        reason = state,
        source = "native-cooldown-probe",
        spellID = spellID,
        durationObject = durationObject,
    }
end

function Spell.ClearCooldownProbe(spellID)
    spellID = SafeNumberValue(spellID)
    local probe = spellID and cooldownProbes[spellID] or nil
    if probe and probe.cooldown and probe.cooldown.Clear then
        pcall(probe.cooldown.Clear, probe.cooldown)
    end
    if probe then
        probe.lastState = nil
    end
end

local function GetMacroSpellID(macroID)
    macroID = SafeNumberValue(macroID)
    if not (macroID and GetMacroSpell) then return nil end

    local ok, _, _, spellID = pcall(GetMacroSpell, macroID)
    if ok then
        return SafeNumberValue(spellID)
    end
    return nil
end

function Spell.FindActionSlotForSpell(spellID, maxSlots)
    spellID = SafeNumberValue(spellID)
    if not (spellID and GetActionInfo) then
        return nil, "no-api"
    end

    maxSlots = SafeNumberValue(maxSlots) or DEFAULT_ACTION_SLOT_SCAN_MAX
    if maxSlots < 1 then maxSlots = DEFAULT_ACTION_SLOT_SCAN_MAX end

    for slot = 1, maxSlots do
        local shouldRead = true
        if HasAction then
            local ok, hasAction = pcall(HasAction, slot)
            hasAction = ok and SafeBooleanValue(hasAction, nil) or nil
            if hasAction == false then
                shouldRead = false
            end
        end

        if shouldRead then
            local ok, actionType, actionID = pcall(GetActionInfo, slot)
            if ok and not IsSecretValue(actionType) and not IsSecretValue(actionID) then
                local actionSpellID = SafeNumberValue(actionID)
                if actionType == "spell" and actionSpellID == spellID then
                    return slot, "spell-slot"
                elseif actionType == "macro" and GetMacroSpellID(actionID) == spellID then
                    return slot, "macro-slot"
                end
            end
        end
    end

    return nil, "no-slot"
end

function Spell.GetActionCooldown(spellID, actionSlot)
    actionSlot = SafeNumberValue(actionSlot)
    if not actionSlot then
        actionSlot = Spell.FindActionSlotForSpell(spellID)
    end
    if not actionSlot then
        return nil, "no-slot"
    end
    if not GetActionCooldown then
        return nil, "no-api", actionSlot
    end

    local ok, startTime, duration, isEnabled, modRate = pcall(GetActionCooldown, actionSlot)
    if not ok then
        return nil, "call-failed", actionSlot
    end

    local cooldown = NormalizeCooldown(startTime, duration, isEnabled, modRate)
    if cooldown then
        cooldown.actionSlot = actionSlot
        return cooldown, "ok", actionSlot
    end

    return nil, "unsafe", actionSlot
end

local function NormalizeCharges(currentCharges, maxCharges, cooldownStartTime, cooldownDuration, chargeModRate)
    if IsSecretValue(currentCharges) then
        return nil
    end

    if type(currentCharges) == "table" then
        local info = currentCharges
        currentCharges = FirstSafeNumberValue(info.currentCharges, info.charges)
        maxCharges = FirstSafeNumberValue(info.maxCharges, info.maxCharge)
        cooldownStartTime = FirstSafeNumberValue(info.cooldownStartTime, info.cooldownStart, info.startTime, info.startTimeSeconds)
        cooldownDuration = FirstSafeNumberValue(info.cooldownDuration, info.duration, info.durationSeconds)
        chargeModRate = FirstSafeNumberValue(info.chargeModRate, info.modRate)
    else
        currentCharges = SafeNumberValue(currentCharges)
        maxCharges = SafeNumberValue(maxCharges)
        cooldownStartTime = SafeNumberValue(cooldownStartTime)
        cooldownDuration = SafeNumberValue(cooldownDuration)
        chargeModRate = SafeNumberValue(chargeModRate)
    end

    if not currentCharges or not maxCharges or maxCharges <= 0 then
        return nil
    end

    cooldownStartTime = cooldownStartTime or 0
    cooldownDuration = cooldownDuration or 0
    chargeModRate = chargeModRate or 1

    return {
        currentCharges = currentCharges,
        maxCharges = maxCharges,
        cooldownStartTime = cooldownStartTime,
        cooldownDuration = cooldownDuration,
        chargeModRate = chargeModRate,
        isActive = currentCharges < maxCharges and cooldownStartTime > 0 and cooldownDuration > 0,
    }
end

local function GetChargesFromCSpell(spellID)
    if not C_Spell or not C_Spell.GetSpellCharges then return nil end
    local ok, currentCharges, maxCharges, cooldownStartTime, cooldownDuration, chargeModRate = pcall(C_Spell.GetSpellCharges, spellID)
    if ok then
        return NormalizeCharges(currentCharges, maxCharges, cooldownStartTime, cooldownDuration, chargeModRate)
    end
    return nil
end

local function GetChargesFromGlobal(spellID)
    if not GetSpellCharges then return nil end
    local ok, currentCharges, maxCharges, cooldownStartTime, cooldownDuration, chargeModRate = pcall(GetSpellCharges, spellID)
    if ok then
        return NormalizeCharges(currentCharges, maxCharges, cooldownStartTime, cooldownDuration, chargeModRate)
    end
    return nil
end

function Spell.GetCharges(spellID)
    if not spellID then return nil end

    if YUI.IsRetail then
        return GetChargesFromCSpell(spellID) or GetChargesFromGlobal(spellID)
    end

    if YUI.IsMists then
        return GetChargesFromGlobal(spellID) or GetChargesFromCSpell(spellID)
    end

    if YUI.IsWrath then
        return GetChargesFromGlobal(spellID) or GetChargesFromCSpell(spellID)
    end

    return GetChargesFromGlobal(spellID) or GetChargesFromCSpell(spellID)
end

local function IsKnownFromCSpellBook(spellID)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, result = pcall(C_SpellBook.IsSpellKnown, spellID)
        if ok then
            return SafeBooleanValue(result, nil)
        end
    end
    return nil
end

local function IsKnownFromGlobal(spellID)
    if IsSpellKnown then
        local ok, result = pcall(IsSpellKnown, spellID)
        if ok then
            return SafeBooleanValue(result, nil)
        end
    end
    return nil
end

local function QuerySpellBookBankBoolean(funcName, spellID, extraArg)
    if not (C_SpellBook and C_SpellBook[funcName]) then
        return nil
    end

    local func = C_SpellBook[funcName]
    local spellBanks = Enum and Enum.SpellBookSpellBank
    local sawFalse = false

    if spellBanks then
        local playerBank = spellBanks.Player
        local petBank = spellBanks.Pet
        for index = 1, 2 do
            local bank = index == 1 and playerBank or petBank
            if bank ~= nil then
                local ok, result
                if extraArg ~= nil then
                    ok, result = pcall(func, spellID, bank, extraArg)
                else
                    ok, result = pcall(func, spellID, bank)
                end
                if ok then
                    result = SafeBooleanValue(result, nil)
                    if result == true then
                        return true
                    elseif result == false then
                        sawFalse = true
                    end
                end
            end
        end
        if sawFalse then
            return false
        end
        return nil
    end

    local ok, result = pcall(func, spellID)
    if ok then
        return SafeBooleanValue(result, nil)
    end
    return nil
end

local function IsKnownOrInSpellBookFromCSpellBook(spellID)
    if not C_SpellBook then return nil end

    local result = QuerySpellBookBankBoolean("IsSpellInSpellBook", spellID)
    if result ~= nil then
        return result
    end

    if C_SpellBook.IsSpellKnownOrInSpellBook then
        result = QuerySpellBookBankBoolean("IsSpellKnownOrInSpellBook", spellID, true)
        if result ~= nil then
            return result
        end
    end

    result = IsKnownFromCSpellBook(spellID)
    if result ~= nil then
        return result
    end

    if C_SpellBook.FindSpellBookSlotForSpell then
        local ok, slotIndex = pcall(C_SpellBook.FindSpellBookSlotForSpell, spellID, true, true, false, false)
        if ok and SafeNumberValue(slotIndex) then
            return true
        end
    end

    return nil
end

function Spell.IsKnown(spellID)
    if not spellID then return false end

    local result
    if YUI.IsRetail then
        result = IsKnownFromCSpellBook(spellID)
        if result ~= nil then return result end
        return IsKnownFromGlobal(spellID) or false
    end

    if YUI.IsMists then
        result = IsKnownFromGlobal(spellID)
        if result ~= nil then return result end
        return IsKnownFromCSpellBook(spellID) or false
    end

    if YUI.IsWrath then
        result = IsKnownFromGlobal(spellID)
        if result ~= nil then return result end
        return IsKnownFromCSpellBook(spellID) or false
    end

    result = IsKnownFromGlobal(spellID)
    if result ~= nil then return result end
    return IsKnownFromCSpellBook(spellID) or false
end

function Spell.IsKnownOrInSpellBook(spellID)
    if not spellID then return false end

    local result
    if YUI.IsRetail then
        result = IsKnownOrInSpellBookFromCSpellBook(spellID)
        if result ~= nil then return result end
        result = IsKnownFromCSpellBook(spellID)
        if result ~= nil then return result end
        return IsKnownFromGlobal(spellID) or false
    end

    if YUI.IsMists or YUI.IsWrath then
        result = IsKnownFromGlobal(spellID)
        if result ~= nil then return result end
        result = IsKnownFromCSpellBook(spellID)
        if result ~= nil then return result end
        return IsKnownOrInSpellBookFromCSpellBook(spellID) or false
    end

    result = IsKnownFromGlobal(spellID)
    if result ~= nil then return result end
    result = IsKnownFromCSpellBook(spellID)
    if result ~= nil then return result end
    return IsKnownOrInSpellBookFromCSpellBook(spellID) or false
end

Legacy.GetSpellName = Spell.GetName
Legacy.GetSpellIcon = Spell.GetTexture
Legacy.SpellHasRange = Spell.HasRange
Legacy.IsSpellInRange = Spell.IsInRange
Legacy.GetSpellCooldownInfo = Spell.GetCooldown
Legacy.GetSpellCooldownDurationObject = Spell.GetCooldownDurationObject
Legacy.GetSpellCooldownDurationState = Spell.GetCooldownDurationState
Legacy.GetSpellCooldownProbeState = Spell.GetCooldownProbeState
Legacy.ClearSpellCooldownProbe = Spell.ClearCooldownProbe
Legacy.FindActionSlotForSpell = Spell.FindActionSlotForSpell
Legacy.GetSpellActionCooldownInfo = Spell.GetActionCooldown
Legacy.GetSpellChargesInfo = Spell.GetCharges
Legacy.IsSpellKnown = Spell.IsKnown
Legacy.IsSpellKnownOrInSpellBook = Spell.IsKnownOrInSpellBook
