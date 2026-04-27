local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local res = CDM._Res

local CDM_C = CDM and CDM.CONST or {}
local IsSafeNumber = CDM.IsSafeNumber
local Pixel = CDM.Pixel
local Snap = Pixel.Snap
local GetTime = GetTime
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local canaccessvalue = canaccessvalue
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitStagger = UnitStagger
local UnitHealthMax = UnitHealthMax
local InCombatLockdown = InCombatLockdown
local GetRuneCooldown = GetRuneCooldown
local UnitPartialPower = UnitPartialPower
local table_sort = table.sort
local table_wipe = table.wipe
local table_remove = table.remove
local GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID
local IsSpellKnown = C_SpellBook.IsSpellKnown

local POWER_TYPES = res.POWER_TYPES
local CUSTOM_POWER_TYPES = res.CUSTOM_POWER_TYPES
local SetStatusBarColorIfChanged = res.SetStatusBarColorIfChanged
local UpdateBarPositions = res.UpdateBarPositions
local GetPowerColor = res.GetPowerColor

local DEVOURER_BASE_SOULS_MAX = 50
local DEVOURER_SOUL_GLUTTON_REDUCED_MAX = 35
local DEVOURER_VOID_META_SOULS_MAX = 40

local IRONFUR_SPELL_ID = 192081
local MANGLE_SPELL_ID = 33917
local FRENZIED_REGEN_SPELL_ID = 22842
local BEAR_FORM_POWER_TYPE = Enum.PowerType.Rage
local CAT_FORM_POWER_TYPE = Enum.PowerType.Energy
local GUARDIAN_OF_ELUNE_DURATION = 15
local IGNORE_PAIN_SPELL_ID = 190456
local IRONFUR_UPDATE_INTERVAL = 0.021

local brewmasterCombatCallbackRegistered = false

local maelstromInstanceID
local maelstromStacks = 0

local feralOverflowingInstanceID
local feralOverflowingStacks = 0

local tipOfTheSpearInstanceID
local tipOfTheSpearStacks = 0
local tipOfTheSpearExpirationTime

local devourerResourceInstanceID
local devourerResourceStacks = 0
local devourerCollapsingStarInstanceID
local devourerCollapsingStarStacks = 0
local devourerVoidMetaInstanceID

local ironfurExpiries = {}
local ironfurDurations = {}
local guardianOfEluneExpiry = 0
local ironfurBaseDuration = 7
local hasGuardianOfElune = false
local hasFluidicForce = false
local ironfurUpdateTicker = nil
local StartIronfurTicker, StopIronfurTicker

local ignorePainFrame = nil
local ignorePainScanRetries = 0

local staggerUpdateTicker = nil
local StartStaggerTicker, StopStaggerTicker

local runeUpdateTicker = nil
local runePowerUpdatePending = false
local runePowerDispatchFrame = CreateFrame("Frame")
runePowerDispatchFrame:Hide()

local cachedFontPath
local cachedFontSize
local cachedFontOutline
local cachedFontColor
local cachedRuneReadyColor
local cachedRuneRechargingColor
local cachedEssenceReadyColor
local cachedEssenceRechargingColor
local cachedBar2TagEnabled = false
local cachedBar2OffsetX = 0
local cachedBar2OffsetY = 0

local function RefreshTrackerFontCache()
    CDM_C.RefreshBaseFontCache()
    cachedFontPath = CDM_C.GetBaseFontPath()
    cachedFontOutline = CDM_C.GetBaseFontOutline()
    cachedFontSize = CDM:GetBarSetting("Runes", "tagFontSize") or 14
    cachedFontColor = CDM:GetBarSetting("Runes", "tagColor") or CDM_C.WHITE
    cachedRuneReadyColor = CDM:GetBarSetting("Runes", "color") or CDM_C.WHITE
    cachedRuneRechargingColor = CDM:GetBarSetting("Runes", "rechargingColor") or cachedRuneReadyColor
    cachedEssenceReadyColor = GetPowerColor(POWER_TYPES.Essence)
    cachedEssenceRechargingColor = CDM:GetBarSetting("Essence", "rechargingColor") or cachedEssenceReadyColor
    cachedBar2TagEnabled = CDM:GetBarSetting("Runes", "tagEnabled") ~= false
    cachedBar2OffsetX = CDM:GetBarSetting("Runes", "tagOffsetX") or 0
    cachedBar2OffsetY = CDM:GetBarSetting("Runes", "tagOffsetY") or 0
end

local function RefreshCachedRuneTimerSlot()
    local _, playerClass = UnitClass("player")
    if playerClass ~= "DEATHKNIGHT" then return end
    RefreshTrackerFontCache()
end

local function UpdateTagTextForPowerType(powerType)
    if CDM.TAGS and CDM.TAGS.textFrames[powerType] then
        CDM.TAGS:UpdateTagText(CDM.TAGS.textFrames[powerType])
    end
end

local GetDevourerSoulMax

local function IsDevourerSoulGluttonKnown()
    if not CDM_C.DEVOURER_SOUL_GLUTTON_TALENT_SPELL_ID then
        return false
    end
    return IsSpellKnown(CDM_C.DEVOURER_SOUL_GLUTTON_TALENT_SPELL_ID)
end

GetDevourerSoulMax = function()
    if IsDevourerSoulGluttonKnown() then
        return DEVOURER_SOUL_GLUTTON_REDUCED_MAX
    end
    return DEVOURER_BASE_SOULS_MAX
end

local function GetDevourerSoulValueMax()
    local max = GetDevourerSoulMax()
    if not CDM_C.DEVOURER_VOID_METAMORPHOSIS_SPELL_ID then
        return 0, max, false
    end

    local inVoidMetamorphosis = devourerVoidMetaInstanceID ~= nil
    if inVoidMetamorphosis then
        max = DEVOURER_VOID_META_SOULS_MAX
    end
    local current = inVoidMetamorphosis and devourerCollapsingStarStacks or devourerResourceStacks
    if current < 0 then
        current = 0
    elseif current > max then
        current = max
    end

    return current, max, inVoidMetamorphosis
end

CDM.GetDevourerSoulValueMax = GetDevourerSoulValueMax

local runeDataCache = {}
for i = 1, 6 do
    runeDataCache[i] = {
        runeIndex = i,
        startTime = 0,
        duration = 0,
        isReady = false,
        remaining = 0
    }
end

local runeSortOrder = {1, 2, 3, 4, 5, 6}
local MAX_VISIBLE_RECHARGING = 3

local function CompareRuneOrder(a, b)
    local runeA = runeDataCache[a]
    local runeB = runeDataCache[b]
    if runeA.isReady and not runeB.isReady then
        return true
    elseif not runeA.isReady and runeB.isReady then
        return false
    end
    return runeA.remaining < runeB.remaining
end

local function CollectRuneData()
    local now = GetTime()
    local hasRecharging = false

    for i = 1, 6 do
        local startTime, duration, runeIsReady = GetRuneCooldown(i)
        local remaining = 0

        if not runeIsReady and startTime and duration and duration > 0 then
            remaining = (startTime + duration) - now
            if remaining < 0 then remaining = 0 end
            hasRecharging = true
        end

        local entry = runeDataCache[i]
        entry.runeIndex = i
        entry.startTime = startTime
        entry.duration = duration
        entry.isReady = runeIsReady
        entry.remaining = remaining
    end

    for i = 1, 6 do
        runeSortOrder[i] = i
    end

    table_sort(runeSortOrder, CompareRuneOrder)

    return hasRecharging
end

local function UpdateStaggerBar()
    local bar = CDM.resourceBars[CUSTOM_POWER_TYPES.Stagger]
    if not bar or not bar:IsShown() then
        return
    end

    local stagger = UnitStagger("player")
    local maxHealth = UnitHealthMax("player")

    if not stagger or not maxHealth or maxHealth == 0 then
        return
    end

    bar:SetMinMaxValues(0, maxHealth)
    bar:SetValue(stagger, Enum.StatusBarInterpolation.ExponentialEaseOut)

    local pct = 0
    local isStaggerSecret = (type(stagger) == "number" and not canaccessvalue(stagger)) or
                            (type(maxHealth) == "number" and not canaccessvalue(maxHealth))
    if not isStaggerSecret and type(stagger) == "number" and type(maxHealth) == "number" then
        pct = stagger / maxHealth
    end

    local colorTier = 0
    if pct >= 0.6 then
        colorTier = 2
    elseif pct >= 0.3 then
        colorTier = 1
    end

    if bar._lastColorTier ~= colorTier then
        bar._lastColorTier = colorTier
        local color
        if colorTier == 2 then
            color = CDM:GetBarSetting("Stagger", "heavyColor")
        elseif colorTier == 1 then
            color = CDM:GetBarSetting("Stagger", "moderateColor")
        else
            color = CDM:GetBarSetting("Stagger", "lightColor")
        end
        bar:SetStatusBarColor(color.r, color.g, color.b, color.a)
    end

    bar.staggerPercent = pct * 100

    UpdateTagTextForPowerType(CUSTOM_POWER_TYPES.Stagger)

    if not isStaggerSecret and type(stagger) == "number" and stagger == 0 and not InCombatLockdown() and staggerUpdateTicker then
        StopStaggerTicker()
    end
end

StartStaggerTicker = function()
    if staggerUpdateTicker then
        return
    end
    staggerUpdateTicker = C_Timer.NewTicker(0.05, UpdateStaggerBar)
end

StopStaggerTicker = function()
    if staggerUpdateTicker then
        staggerUpdateTicker:Cancel()
        staggerUpdateTicker = nil
    end
end

local function RefreshIronfurTalents()
    ironfurBaseDuration = IsSpellKnown(393611) and 9 or 7
    hasGuardianOfElune = IsSpellKnown(155578)
    hasFluidicForce = IsSpellKnown(441678)
end

local function PruneExpiredIronfurStacks()
    local now = GetTime()
    while #ironfurExpiries > 0 and ironfurExpiries[1] <= now do
        table_remove(ironfurExpiries, 1)
        table_remove(ironfurDurations, 1)
    end
end

local function UpdateIronfurBar()
    PruneExpiredIronfurStacks()

    local stackCount = #ironfurExpiries

    local bar = CDM.resourceBars[CUSTOM_POWER_TYPES.Ironfur]
    if not bar or not bar:IsShown() then
        if stackCount == 0 and not InCombatLockdown() and ironfurUpdateTicker then
            StopIronfurTicker()
        end
        return
    end

    local now = GetTime()

    local longestIdx = 0
    local fillPct = 0
    if stackCount > 0 then
        local maxExpiry = 0
        for i = 1, stackCount do
            if ironfurExpiries[i] > maxExpiry then
                maxExpiry = ironfurExpiries[i]
                longestIdx = i
            end
        end
        fillPct = math_max(0, (ironfurExpiries[longestIdx] - now) / ironfurDurations[longestIdx])
        bar:SetValue(fillPct, Enum.StatusBarInterpolation.Immediate)
    else
        bar:SetValue(0, Enum.StatusBarInterpolation.Immediate)
        if not InCombatLockdown() and ironfurUpdateTicker then
            StopIronfurTicker()
        end
    end

    if not bar.ironfurTicks then bar.ironfurTicks = {} end
    local barWidth = bar:GetWidth()
    local onePixel = Pixel.GetSize()

    for i = 1, stackCount do
        local tick = bar.ironfurTicks[i]
        if not tick then
            tick = Pixel.CreateSolidTexture(bar, "OVERLAY", 7)
            tick:SetVertexColor(1, 1, 1, 1)
            bar.ironfurTicks[i] = tick
        end

        local stackPct
        if i == longestIdx then
            stackPct = fillPct
        else
            stackPct = math_max(0, math_min(1, (ironfurExpiries[i] - now) / ironfurDurations[i]))
        end
        local xOffset = stackPct * barWidth
        local snappedXOffset = Snap(xOffset)
        local tickWidth = 2 * onePixel
        local tickHeight = bar:GetHeight()
        if tick._cdmLastIronfurTickX ~= snappedXOffset then
            tick:ClearAllPoints()
            tick:SetPoint("RIGHT", bar, "LEFT", snappedXOffset, 0)
            tick._cdmLastIronfurTickX = snappedXOffset
        end
        if tick._cdmLastIronfurTickWidth ~= tickWidth or tick._cdmLastIronfurTickHeight ~= tickHeight then
            tick:SetSize(tickWidth, tickHeight)
            tick._cdmLastIronfurTickWidth = tickWidth
            tick._cdmLastIronfurTickHeight = tickHeight
        end
        tick:Show()
    end
    for i = stackCount + 1, #bar.ironfurTicks do
        bar.ironfurTicks[i]:Hide()
    end

    UpdateTagTextForPowerType(CUSTOM_POWER_TYPES.Ironfur)
end

StartIronfurTicker = function()
    if ironfurUpdateTicker then return end
    ironfurUpdateTicker = C_Timer.NewTicker(IRONFUR_UPDATE_INTERVAL, UpdateIronfurBar)
end

StopIronfurTicker = function()
    if not ironfurUpdateTicker then return end
    ironfurUpdateTicker:Cancel()
    ironfurUpdateTicker = nil
end

local function ClearIronfurState()
    table_wipe(ironfurExpiries)
    table_wipe(ironfurDurations)
    StopIronfurTicker()
    local bar = CDM.resourceBars[CUSTOM_POWER_TYPES.Ironfur]
    if bar and bar:IsShown() then
        bar:SetValue(0, Enum.StatusBarInterpolation.Immediate)
        if bar.ironfurTicks then
            for _, tick in ipairs(bar.ironfurTicks) do tick:Hide() end
        end
        UpdateTagTextForPowerType(CUSTOM_POWER_TYPES.Ironfur)
    end
end

function CDM:GetIronfurStackCount()
    PruneExpiredIronfurStacks()
    return #ironfurExpiries
end

local function ClearIgnorePainState()
    ignorePainFrame = nil
    local bar = CDM.resourceBars[CUSTOM_POWER_TYPES.IgnorePain]
    if bar and bar:IsShown() then
        bar:SetValue(0)
        bar.ignorePainSecretValue = nil
        UpdateTagTextForPowerType(CUSTOM_POWER_TYPES.IgnorePain)
    end
end

local function OnIgnorePainSetText(frame, value)
    if ignorePainFrame ~= frame then return end
    local bar = CDM.resourceBars[CUSTOM_POWER_TYPES.IgnorePain]
    if not bar or not bar:IsShown() then return end
    if type(value) ~= "number" then
        bar:SetValue(0)
        bar.ignorePainSecretValue = nil
        UpdateTagTextForPowerType(CUSTOM_POWER_TYPES.IgnorePain)
        return
    end
    bar:SetValue(value)
    bar.ignorePainSecretValue = value
    UpdateTagTextForPowerType(CUSTOM_POWER_TYPES.IgnorePain)
end

function CDM:NotifyBuffFrameSpellID(frame, spellID)
    if not res.GetIsEnabled() or res.GetCurrentSpecID() ~= 73 then return end

    if spellID == IGNORE_PAIN_SPELL_ID then
        ignorePainFrame = frame
        local frameData = CDM.GetFrameData(frame)
        if not frameData.cdmIgnorePainHooked then
            frameData.cdmIgnorePainHooked = true
            local appFS = frame.Applications and frame.Applications.Applications
            if appFS then
                hooksecurefunc(appFS, "SetText", function(self, val)
                    OnIgnorePainSetText(frame, val)
                end)
            end
        end
    elseif ignorePainFrame == frame then
        ClearIgnorePainState()
    end
end

function CDM:GetIgnorePainValue()
    local bar = CDM.resourceBars[CUSTOM_POWER_TYPES.IgnorePain]
    return bar and bar.ignorePainSecretValue or 0
end

local function ScanForIgnorePainFrame()
    if not res.GetIsEnabled() or res.GetCurrentSpecID() ~= 73 then return end
    if ignorePainFrame then return end

    local viewer = _G.BuffIconCooldownViewer
    if not viewer or not viewer.itemFramePool then return end

    local GetBaseSpellID = CDM.GetBaseSpellID
    for frame in viewer.itemFramePool:EnumerateActive() do
        local baseID = GetBaseSpellID(frame)
        if baseID then
            CDM:NotifyBuffFrameSpellID(frame, baseID)
            if ignorePainFrame then return end
        end
    end

    if not ignorePainFrame and ignorePainScanRetries < 3 then
        ignorePainScanRetries = ignorePainScanRetries + 1
        C_Timer.After(0.5, ScanForIgnorePainFrame)
    end
end

local function SeedMaelstrom()
    local a = GetPlayerAuraBySpellID(CDM_C.MAELSTROM_WEAPON_SPELL_ID)
    maelstromInstanceID = a and a.auraInstanceID or nil
    maelstromStacks = a and a.applications or 0
end

local function UpdateMaelstromBar()
    return maelstromStacks, res.MAX_MAELSTROM_WEAPON
end

local function SeedFeralOverflowing()
    local a = GetPlayerAuraBySpellID(CDM_C.FERAL_OVERFLOWING_POWER_SPELL_ID)
    feralOverflowingInstanceID = a and a.auraInstanceID or nil
    feralOverflowingStacks = a and a.applications or 0
end

local function GetFeralOverflowingStacks()
    return feralOverflowingStacks
end

local function SeedTipOfTheSpear()
    local a = GetPlayerAuraBySpellID(CDM_C.TIP_OF_THE_SPEAR_SPELL_ID)
    tipOfTheSpearInstanceID = a and a.auraInstanceID or nil
    tipOfTheSpearStacks = a and a.applications or 0
    tipOfTheSpearExpirationTime = a and a.expirationTime or nil
end

local function UpdateTipOfTheSpearBar()
    return tipOfTheSpearStacks, res.MAX_TIP_OF_THE_SPEAR
end

function CDM:GetTipOfTheSpearStacks()
    return tipOfTheSpearStacks
end

function CDM:GetTipOfTheSpearExpirationTime()
    return tipOfTheSpearExpirationTime
end

local function ApplyRuneStates(bar, readyColor, rechargingColor, textEnabled)
    local hasRecharging = CollectRuneData()

    local readyCount = 0
    for i = 1, 6 do
        if runeDataCache[i].isReady then readyCount = readyCount + 1 end
    end

    local rechargingShown = 0
    for i, pip in ipairs(bar.pips) do
        local runeIndex = runeSortOrder[i]
        local rune = runeDataCache[runeIndex]
        if not rune then
            pip:SetValue(0, Enum.StatusBarInterpolation.Immediate)
            if pip.timerText then
                pip.timerText:Hide()
            end
        elseif rune.isReady then
            pip:SetValue(1, Enum.StatusBarInterpolation.Immediate)
            SetStatusBarColorIfChanged(pip, readyColor)
            if pip.timerText then
                pip.timerText:Hide()
            end
        elseif rune.startTime and rune.duration and rune.duration > 0 then
            rechargingShown = rechargingShown + 1
            if rechargingShown <= MAX_VISIBLE_RECHARGING then
                local now = GetTime()
                local elapsed = now - rune.startTime
                local progress = elapsed / rune.duration
                if progress < 0 then progress = 0 end
                if progress > 1 then progress = 1 end

                pip:SetValue(progress, Enum.StatusBarInterpolation.Immediate)
                SetStatusBarColorIfChanged(pip, rechargingColor)

                if pip.timerText and textEnabled then
                    if rune.remaining > 0 then
                        local displayValue = math_floor(rune.remaining)
                        if pip._lastDisplayValue ~= displayValue then
                            pip._lastDisplayValue = displayValue
                            pip.timerText:SetFormattedText("%d", displayValue)
                        end
                        pip.timerText:Show()
                    else
                        if pip._lastDisplayValue ~= 0 then
                            pip._lastDisplayValue = 0
                        end
                        pip.timerText:Hide()
                    end
                end
            else
                pip:SetValue(0, Enum.StatusBarInterpolation.Immediate)
                SetStatusBarColorIfChanged(pip, rechargingColor)
                if pip.timerText then
                    pip.timerText:Hide()
                end
            end
        else
            pip:SetValue(0, Enum.StatusBarInterpolation.Immediate)
            if pip.timerText then
                pip.timerText:Hide()
            end
        end
    end

    if res.ApplyPipConditions then
        res.ApplyPipConditions(bar, POWER_TYPES.Runes, readyCount, 6)
    end

    return hasRecharging
end

local function UpdateRuneProgress(bar)
    if not bar or not bar:IsShown() or not bar.hasRunesRecharging then
        if runeUpdateTicker then
            runeUpdateTicker:Cancel()
            runeUpdateTicker = nil
            if bar then bar.hasRunesRecharging = false end
        end
        return
    end

    if not cachedRuneReadyColor then
        RefreshTrackerFontCache()
    end

    ApplyRuneStates(bar, cachedRuneReadyColor, cachedRuneRechargingColor, cachedBar2TagEnabled)
end

local function RuneProgressTick()
    UpdateRuneProgress(CDM.resourceBars[POWER_TYPES.Runes])
end

local function UpdateRuneCooldowns(bar)
    if not bar or not bar.pips or bar.powerType ~= POWER_TYPES.Runes or not bar:IsShown() then
        return
    end

    if not cachedFontPath or not cachedRuneReadyColor then
        RefreshTrackerFontCache()
    end

    local textEnabled = cachedBar2TagEnabled

    if textEnabled then
        local pixelSize = Pixel.FontSize(cachedFontSize)
        local cachedColor = bar._lastRuneFontColor
        local colorChanged = (not cachedColor) or
            cachedColor.r ~= cachedFontColor.r or
            cachedColor.g ~= cachedFontColor.g or
            cachedColor.b ~= cachedFontColor.b or
            cachedColor.a ~= cachedFontColor.a

        local styleChanged = colorChanged or
            bar._lastRuneFontPath ~= cachedFontPath or
            bar._lastRuneFontSize ~= pixelSize or
            bar._lastRuneFontOutline ~= cachedFontOutline or
            bar._lastRuneOffsetX ~= cachedBar2OffsetX or
            bar._lastRuneOffsetY ~= cachedBar2OffsetY

        if styleChanged then
            for _, pip in ipairs(bar.pips) do
                if pip.timerText then
                    pip.timerText:SetIgnoreParentScale(true)
                    pip.timerText:SetFont(cachedFontPath, pixelSize, cachedFontOutline)
                    pip.timerText:SetTextColor(cachedFontColor.r, cachedFontColor.g, cachedFontColor.b, cachedFontColor.a)
                    pip.timerText:ClearAllPoints()
                    pip.timerText:SetPoint("CENTER", pip.timerFrame, "CENTER", cachedBar2OffsetX, cachedBar2OffsetY)
                end
            end

            bar._lastRuneFontPath = cachedFontPath
            bar._lastRuneFontSize = pixelSize
            bar._lastRuneFontOutline = cachedFontOutline
            bar._lastRuneOffsetX = cachedBar2OffsetX
            bar._lastRuneOffsetY = cachedBar2OffsetY
            cachedColor = cachedColor or {}
            cachedColor.r = cachedFontColor.r
            cachedColor.g = cachedFontColor.g
            cachedColor.b = cachedFontColor.b
            cachedColor.a = cachedFontColor.a
            bar._lastRuneFontColor = cachedColor
        end
    end

    local hasRecharging = ApplyRuneStates(bar, cachedRuneReadyColor, cachedRuneRechargingColor, textEnabled)

    if hasRecharging and not runeUpdateTicker then
        runeUpdateTicker = C_Timer.NewTicker(0.05, RuneProgressTick)
        bar.hasRunesRecharging = true
    elseif not hasRecharging and runeUpdateTicker then
        runeUpdateTicker:Cancel()
        runeUpdateTicker = nil
        bar.hasRunesRecharging = false
    end
end

local function EssenceFillingPipOnUpdate(pip)
    pip:SetValue(UnitPartialPower("player", POWER_TYPES.Essence) / 1000, Enum.StatusBarInterpolation.Immediate)
end

local function ApplyEssenceStates(bar, current, max, readyColor, rechargingColor)
    for i, pip in ipairs(bar.pips) do
        if not pip:IsShown() then break end
        if i <= current then
            pip:SetScript("OnUpdate", nil)
            pip:SetValue(1, Enum.StatusBarInterpolation.Immediate)
            SetStatusBarColorIfChanged(pip, readyColor)
        elseif i == current + 1 and current < max then
            pip:SetValue(UnitPartialPower("player", POWER_TYPES.Essence) / 1000, Enum.StatusBarInterpolation.Immediate)
            SetStatusBarColorIfChanged(pip, rechargingColor)
            pip:SetScript("OnUpdate", EssenceFillingPipOnUpdate)
        else
            pip:SetScript("OnUpdate", nil)
            pip:SetValue(0, Enum.StatusBarInterpolation.Immediate)
            SetStatusBarColorIfChanged(pip, rechargingColor)
        end
    end
end

local function UpdateEssenceCooldowns(bar)
    if not bar or not bar.pips or bar.powerType ~= POWER_TYPES.Essence or not bar:IsShown() then
        if bar and bar.pips then
            for _, pip in ipairs(bar.pips) do
                pip:SetScript("OnUpdate", nil)
            end
        end
        if bar then bar.hasEssenceRecharging = false end
        return
    end

    local readyColor = cachedEssenceReadyColor or GetPowerColor(POWER_TYPES.Essence)
    local rechargingColor = cachedEssenceRechargingColor or readyColor

    local current = UnitPower("player", POWER_TYPES.Essence)
    local max = UnitPowerMax("player", POWER_TYPES.Essence)

    if bar._essencePrevCurrent ~= current then
        bar._essencePrevCurrent = current
        UpdateTagTextForPowerType(POWER_TYPES.Essence)
    end

    ApplyEssenceStates(bar, current, max, readyColor, rechargingColor)
    bar.hasEssenceRecharging = (current < max)
end

local function OnSpellUpdateUses(event, spellID, baseSpellID)
    if spellID ~= CDM_C.SOUL_CLEAVE_SPELL_ID and baseSpellID ~= CDM_C.SOUL_CLEAVE_SPELL_ID then return end
    res.UpdateBarValue(CUSTOM_POWER_TYPES.SoulFragments)
end

local function OnPlayerRegenDisabled()
    StartStaggerTicker()
end

local function OnPlayerRegenEnabled()
    local currentStagger = UnitStagger("player") or 0
    if IsSafeNumber(currentStagger) and currentStagger > 0 then
        StartStaggerTicker()
        return
    end
    StopStaggerTicker()
end

local function OnBrewmasterCombatStateChanged(isInCombat)
    if res.GetCurrentSpecID() ~= 268 then
        return
    end
    if isInCombat then
        OnPlayerRegenDisabled()
        return
    end
    OnPlayerRegenEnabled()
end

local function RegisterBrewmasterCombatStateListener()
    if brewmasterCombatCallbackRegistered then
        return
    end
    if CDM:RegisterCombatStateHandler(OnBrewmasterCombatStateChanged) then
        brewmasterCombatCallbackRegistered = true
    end
end

local function UnregisterBrewmasterCombatStateListener()
    if brewmasterCombatCallbackRegistered then
        CDM:UnregisterCombatStateHandler(OnBrewmasterCombatStateChanged)
        brewmasterCombatCallbackRegistered = false
    end
end

local function OnUnitMaxHealth()
    UpdateStaggerBar()
end

local function OnMaelstromUnitAura(event, unit, info)
    if unit ~= "player" then return end
    if not info or info.isFullUpdate then
        SeedMaelstrom()
    else
        if info.addedAuras then
            for _, a in ipairs(info.addedAuras) do
                if IsSafeNumber(a.spellId) and a.spellId == CDM_C.MAELSTROM_WEAPON_SPELL_ID then
                    maelstromInstanceID = a.auraInstanceID
                    maelstromStacks = a.applications or 0
                end
            end
        end
        if maelstromInstanceID and info.updatedAuraInstanceIDs then
            for _, id in ipairs(info.updatedAuraInstanceIDs) do
                if id == maelstromInstanceID then
                    local a = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, id)
                    maelstromStacks = a and a.applications or 0
                end
            end
        end
        if maelstromInstanceID and info.removedAuraInstanceIDs then
            for _, id in ipairs(info.removedAuraInstanceIDs) do
                if id == maelstromInstanceID then
                    maelstromInstanceID = nil
                    maelstromStacks = 0
                end
            end
        end
    end
    res.UpdateBarValue(CUSTOM_POWER_TYPES.MaelstromWeapon)
end

local function OnFeralOverflowingUnitAura(event, unit, info)
    if unit ~= "player" then return end
    if not info or info.isFullUpdate then
        SeedFeralOverflowing()
    else
        if info.addedAuras then
            for _, a in ipairs(info.addedAuras) do
                if IsSafeNumber(a.spellId) and a.spellId == CDM_C.FERAL_OVERFLOWING_POWER_SPELL_ID then
                    feralOverflowingInstanceID = a.auraInstanceID
                    feralOverflowingStacks = a.applications or 0
                end
            end
        end
        if feralOverflowingInstanceID and info.updatedAuraInstanceIDs then
            for _, id in ipairs(info.updatedAuraInstanceIDs) do
                if id == feralOverflowingInstanceID then
                    local a = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, id)
                    feralOverflowingStacks = a and a.applications or 0
                end
            end
        end
        if feralOverflowingInstanceID and info.removedAuraInstanceIDs then
            for _, id in ipairs(info.removedAuraInstanceIDs) do
                if id == feralOverflowingInstanceID then
                    feralOverflowingInstanceID = nil
                    feralOverflowingStacks = 0
                end
            end
        end
    end
    res.UpdateBarValue(POWER_TYPES.ComboPoints)
end

local function OnTipOfTheSpearUnitAura(event, unit, info)
    if unit ~= "player" then return end
    if not info or info.isFullUpdate then
        SeedTipOfTheSpear()
    else
        if info.addedAuras then
            for _, a in ipairs(info.addedAuras) do
                if IsSafeNumber(a.spellId) and a.spellId == CDM_C.TIP_OF_THE_SPEAR_SPELL_ID then
                    tipOfTheSpearInstanceID = a.auraInstanceID
                    tipOfTheSpearStacks = a.applications or 0
                    tipOfTheSpearExpirationTime = a.expirationTime
                end
            end
        end
        if tipOfTheSpearInstanceID and info.updatedAuraInstanceIDs then
            for _, id in ipairs(info.updatedAuraInstanceIDs) do
                if id == tipOfTheSpearInstanceID then
                    local a = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, id)
                    tipOfTheSpearStacks = a and a.applications or 0
                    tipOfTheSpearExpirationTime = a and a.expirationTime or nil
                end
            end
        end
        if tipOfTheSpearInstanceID and info.removedAuraInstanceIDs then
            for _, id in ipairs(info.removedAuraInstanceIDs) do
                if id == tipOfTheSpearInstanceID then
                    tipOfTheSpearInstanceID = nil
                    tipOfTheSpearStacks = 0
                    tipOfTheSpearExpirationTime = nil
                end
            end
        end
    end
    res.UpdateBarValue(CUSTOM_POWER_TYPES.TipOfTheSpear)
end

local function SeedDevourer()
    local resourceAura = GetPlayerAuraBySpellID(CDM_C.DEVOURER_RESOURCE_AURA_SPELL_ID)
    devourerResourceInstanceID = resourceAura and resourceAura.auraInstanceID or nil
    devourerResourceStacks = resourceAura and resourceAura.applications or 0

    local collapsingStarAura = CDM_C.DEVOURER_COLLAPSING_STAR_SPELL_ID
        and GetPlayerAuraBySpellID(CDM_C.DEVOURER_COLLAPSING_STAR_SPELL_ID) or nil
    devourerCollapsingStarInstanceID = collapsingStarAura and collapsingStarAura.auraInstanceID or nil
    devourerCollapsingStarStacks = collapsingStarAura and collapsingStarAura.applications or 0

    local voidMetaAura = CDM_C.DEVOURER_VOID_METAMORPHOSIS_SPELL_ID
        and GetPlayerAuraBySpellID(CDM_C.DEVOURER_VOID_METAMORPHOSIS_SPELL_ID) or nil
    devourerVoidMetaInstanceID = voidMetaAura and voidMetaAura.auraInstanceID or nil
end

local function OnDevourerUnitAura(event, unit, info)
    if unit ~= "player" then return end
    local wasInVoidMeta = devourerVoidMetaInstanceID ~= nil

    if not info or info.isFullUpdate then
        SeedDevourer()
    else
        if info.addedAuras then
            for _, a in ipairs(info.addedAuras) do
                if IsSafeNumber(a.spellId) then
                    if a.spellId == CDM_C.DEVOURER_RESOURCE_AURA_SPELL_ID then
                        devourerResourceInstanceID = a.auraInstanceID
                        devourerResourceStacks = a.applications or 0
                    elseif a.spellId == CDM_C.DEVOURER_COLLAPSING_STAR_SPELL_ID then
                        devourerCollapsingStarInstanceID = a.auraInstanceID
                        devourerCollapsingStarStacks = a.applications or 0
                    elseif a.spellId == CDM_C.DEVOURER_VOID_METAMORPHOSIS_SPELL_ID then
                        devourerVoidMetaInstanceID = a.auraInstanceID
                    end
                end
            end
        end
        if info.updatedAuraInstanceIDs then
            for _, id in ipairs(info.updatedAuraInstanceIDs) do
                if id == devourerResourceInstanceID then
                    local a = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, id)
                    devourerResourceStacks = a and a.applications or 0
                elseif id == devourerCollapsingStarInstanceID then
                    local a = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, id)
                    devourerCollapsingStarStacks = a and a.applications or 0
                end
            end
        end
        if info.removedAuraInstanceIDs then
            for _, id in ipairs(info.removedAuraInstanceIDs) do
                if id == devourerResourceInstanceID then
                    devourerResourceInstanceID = nil
                    devourerResourceStacks = 0
                elseif id == devourerCollapsingStarInstanceID then
                    devourerCollapsingStarInstanceID = nil
                    devourerCollapsingStarStacks = 0
                elseif id == devourerVoidMetaInstanceID then
                    devourerVoidMetaInstanceID = nil
                end
            end
        end
    end

    local nowInVoidMeta = devourerVoidMetaInstanceID ~= nil
    if nowInVoidMeta ~= wasInVoidMeta then
        UpdateBarPositions()
        return
    end

    res.UpdateBarValue(CUSTOM_POWER_TYPES.DevourerSoulFragments)
end

local function OnDevourerSpellsChanged()
    if res.GetCurrentSpecID() ~= 1480 then
        return
    end
    CDM:UpdateResources()
end

local function OnGuardianSpellCastSucceeded(event, unit, castGUID, spellID)
    if res.GetCurrentSpecID() ~= 104 then return end

    if spellID == IRONFUR_SPELL_ID then
        local now = GetTime()
        local bonus = (hasGuardianOfElune and now < guardianOfEluneExpiry) and 3 or 0
        if bonus > 0 then guardianOfEluneExpiry = 0 end
        local duration = ironfurBaseDuration + bonus
        local n = #ironfurExpiries + 1
        ironfurExpiries[n] = now + duration
        ironfurDurations[n] = duration
        UpdateIronfurBar()
        StartIronfurTicker()
    elseif spellID == MANGLE_SPELL_ID then
        if hasGuardianOfElune then
            guardianOfEluneExpiry = GetTime() + GUARDIAN_OF_ELUNE_DURATION
        end
    elseif spellID == FRENZIED_REGEN_SPELL_ID then
        if hasGuardianOfElune and GetTime() < guardianOfEluneExpiry then
            guardianOfEluneExpiry = 0
        end
    end
end

local function OnIronfurPlayerDead()
    ClearIronfurState()
    guardianOfEluneExpiry = 0
end

local function EnableVengeanceSoulTracking()
    res.RegisterResEvent("SPELL_UPDATE_USES", OnSpellUpdateUses)
    C_Timer.After(0.1, function()
        res.UpdateBarValue(CUSTOM_POWER_TYPES.SoulFragments)
    end)
end

local function DisableVengeanceSoulTracking()
    res.UnregisterResEvent("SPELL_UPDATE_USES")
end

local function EnableBrewmasterTracking()
    RegisterBrewmasterCombatStateListener()
    res.RegisterResUnitEvent("UNIT_MAXHEALTH", "player", OnUnitMaxHealth)

    local currentStagger = UnitStagger("player") or 0
    if InCombatLockdown() or (IsSafeNumber(currentStagger) and currentStagger > 0) then
        StartStaggerTicker()
    end
end

local function DisableBrewmasterTracking()
    UnregisterBrewmasterCombatStateListener()
    res.UnregisterResUnitEvent("UNIT_MAXHEALTH")
    StopStaggerTicker()
end

local function EnableMaelstromTracking()
    SeedMaelstrom()
    res.RegisterResUnitEvent("UNIT_AURA", "player", OnMaelstromUnitAura)
    C_Timer.After(0.1, function()
        res.UpdateBarValue(CUSTOM_POWER_TYPES.MaelstromWeapon)
    end)
end

local function DisableMaelstromTracking()
    res.UnregisterResUnitEvent("UNIT_AURA")
    maelstromInstanceID = nil
    maelstromStacks = 0
end

local function EnableFeralOverflowingTracking()
    SeedFeralOverflowing()
    res.RegisterResUnitEvent("UNIT_AURA", "player", OnFeralOverflowingUnitAura)
    C_Timer.After(0.1, function()
        res.UpdateBarValue(POWER_TYPES.ComboPoints)
    end)
end

local function DisableFeralOverflowingTracking()
    res.UnregisterResUnitEvent("UNIT_AURA")
    feralOverflowingInstanceID = nil
    feralOverflowingStacks = 0
    res.UpdateBarValue(POWER_TYPES.ComboPoints)
end

local function EnableTipOfTheSpearTracking()
    SeedTipOfTheSpear()
    res.RegisterResUnitEvent("UNIT_AURA", "player", OnTipOfTheSpearUnitAura)
    C_Timer.After(0.1, function()
        res.UpdateBarValue(CUSTOM_POWER_TYPES.TipOfTheSpear)
    end)
end

local function DisableTipOfTheSpearTracking()
    res.UnregisterResUnitEvent("UNIT_AURA")
    tipOfTheSpearInstanceID = nil
    tipOfTheSpearStacks = 0
    tipOfTheSpearExpirationTime = nil
end

local function EnableDevourerTracking()
    SeedDevourer()
    res.RegisterResUnitEvent("UNIT_AURA", "player", OnDevourerUnitAura)
    res.RegisterResEvent("SPELLS_CHANGED", OnDevourerSpellsChanged)
    C_Timer.After(0.1, function()
        res.UpdateBarValue(CUSTOM_POWER_TYPES.DevourerSoulFragments)
    end)
end

local function DisableDevourerTracking()
    res.UnregisterResUnitEvent("UNIT_AURA")
    res.UnregisterResEvent("SPELLS_CHANGED")
    devourerResourceInstanceID = nil
    devourerResourceStacks = 0
    devourerCollapsingStarInstanceID = nil
    devourerCollapsingStarStacks = 0
    devourerVoidMetaInstanceID = nil
end

local function EnableGuardianTracking()
    RefreshIronfurTalents()
    res.RegisterResUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", OnGuardianSpellCastSucceeded)
    res.RegisterResEvent("PLAYER_DEAD", OnIronfurPlayerDead)
end

local function RefreshGuardianTracking()
    RefreshIronfurTalents()
end

local function DisableGuardianTracking()
    res.UnregisterResUnitEvent("UNIT_SPELLCAST_SUCCEEDED")
    res.UnregisterResEvent("PLAYER_DEAD")
    ClearIronfurState()
end

local function RefreshIgnorePainVisibility()
    local hideIcon = CDM:GetBarSetting("IgnorePain", "hideIcon") == true
    CDM.resourcesHiddenBuffSet[IGNORE_PAIN_SPELL_ID] = hideIcon or nil
end

local function StartIgnorePainTracking()
    RefreshIgnorePainVisibility()
    ignorePainScanRetries = 0
    C_Timer.After(0.2, ScanForIgnorePainFrame)
end

local function StopIgnorePainTracking()
    CDM.resourcesHiddenBuffSet[IGNORE_PAIN_SPELL_ID] = nil
    ClearIgnorePainState()
end

local function RunePowerBatchCallback()
    runePowerUpdatePending = false
    local bar = CDM.resourceBars[POWER_TYPES.Runes]
    if bar and bar:IsShown() then
        UpdateRuneCooldowns(bar)
    end
end

runePowerDispatchFrame:SetScript("OnUpdate", function(self)
    self:Hide()
    RunePowerBatchCallback()
end)

local function OnRunePowerUpdate(event, runeIndex, isEnergize)
    if runePowerUpdatePending then return end
    runePowerUpdatePending = true
    runePowerDispatchFrame:Show()
end

local function OnTrackerProfileApplied()
    cachedFontPath = nil
    cachedFontSize = nil
    cachedFontOutline = nil
    cachedFontColor = nil
    cachedRuneReadyColor = nil
    cachedRuneRechargingColor = nil
    cachedEssenceReadyColor = nil
    cachedEssenceRechargingColor = nil
    cachedBar2TagEnabled = false
    cachedBar2OffsetX = 0
    cachedBar2OffsetY = 0
end

local function DisableAllTrackerTickers()
    if runeUpdateTicker then
        runeUpdateTicker:Cancel()
        runeUpdateTicker = nil
    end
    local essenceBar = CDM.resourceBars and CDM.resourceBars[POWER_TYPES.Essence]
    if essenceBar and essenceBar.pips then
        for _, pip in ipairs(essenceBar.pips) do
            pip:SetScript("OnUpdate", nil)
        end
        essenceBar.hasEssenceRecharging = false
    end
    guardianOfEluneExpiry = 0
    maelstromInstanceID = nil
    maelstromStacks = 0
    feralOverflowingInstanceID = nil
    feralOverflowingStacks = 0
    tipOfTheSpearInstanceID = nil
    tipOfTheSpearStacks = 0
    tipOfTheSpearExpirationTime = nil
    devourerResourceInstanceID = nil
    devourerResourceStacks = 0
    devourerCollapsingStarInstanceID = nil
    devourerCollapsingStarStacks = 0
    devourerVoidMetaInstanceID = nil
end

local function OnShapeshiftGuardianCheck(currentPowerType)
    local inBearForm = (currentPowerType == BEAR_FORM_POWER_TYPE)
    local inCatForm = (currentPowerType == CAT_FORM_POWER_TYPE)
    if not inBearForm and not (inCatForm and hasFluidicForce) then
        ClearIronfurState()
    end
end

res.IsRuneRecharging = function(pipIndex)
    local runeIndex = runeSortOrder[pipIndex]
    local rune = runeIndex and runeDataCache[runeIndex]
    return rune and not rune.isReady or false
end
res.IsEssenceRecharging = function(pipIndex)
    local current = UnitPower("player", POWER_TYPES.Essence)
    local max = UnitPowerMax("player", POWER_TYPES.Essence)
    return pipIndex == current + 1 and current < max
end

res.UpdateIronfurBar = UpdateIronfurBar
res.UpdateStaggerBar = UpdateStaggerBar
res.UpdateMaelstromBar = UpdateMaelstromBar
res.UpdateRuneCooldowns = UpdateRuneCooldowns
res.UpdateEssenceCooldowns = UpdateEssenceCooldowns
res.UpdateTagTextForPowerType = UpdateTagTextForPowerType
res.GetDevourerSoulValueMax = GetDevourerSoulValueMax
res.OnRunePowerUpdate = OnRunePowerUpdate
res.RefreshTrackerFontCache = RefreshTrackerFontCache
res.RefreshCachedRuneTimerSlot = RefreshCachedRuneTimerSlot
res.OnTrackerProfileApplied = OnTrackerProfileApplied
res.DisableAllTrackerTickers = DisableAllTrackerTickers
res.OnShapeshiftGuardianCheck = OnShapeshiftGuardianCheck
res.RefreshIgnorePainVisibility = RefreshIgnorePainVisibility
res.RefreshIronfurTalents = RefreshIronfurTalents
res.EnableVengeanceSoulTracking = EnableVengeanceSoulTracking
res.DisableVengeanceSoulTracking = DisableVengeanceSoulTracking
res.EnableBrewmasterTracking = EnableBrewmasterTracking
res.DisableBrewmasterTracking = DisableBrewmasterTracking
res.EnableMaelstromTracking = EnableMaelstromTracking
res.DisableMaelstromTracking = DisableMaelstromTracking
res.GetFeralOverflowingStacks = GetFeralOverflowingStacks
res.EnableFeralOverflowingTracking = EnableFeralOverflowingTracking
res.DisableFeralOverflowingTracking = DisableFeralOverflowingTracking
res.UpdateTipOfTheSpearBar = UpdateTipOfTheSpearBar
res.EnableTipOfTheSpearTracking = EnableTipOfTheSpearTracking
res.DisableTipOfTheSpearTracking = DisableTipOfTheSpearTracking
res.EnableDevourerTracking = EnableDevourerTracking
res.DisableDevourerTracking = DisableDevourerTracking
res.EnableGuardianTracking = EnableGuardianTracking
res.RefreshGuardianTracking = RefreshGuardianTracking
res.DisableGuardianTracking = DisableGuardianTracking
res.StartIgnorePainTracking = StartIgnorePainTracking
res.StopIgnorePainTracking = StopIgnorePainTracking
