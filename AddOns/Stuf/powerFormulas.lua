--[[
================================================================================
oUF Power System Reference for Stuf Unit Frames
================================================================================

This document extracts key patterns and formulas from the oUF (UnhaltedUnitFrames)
framework for handling health, power, and alternative power systems.

SOURCE: UnhaltedUnitFrames/Libraries/oUF
LICENSE: MIT License (see below)

Copyright (c) 2006-2026 Trond A Ekseth <troeks@gmail.com>
Copyright (c) 2016-2026 Val Voronov <i.lightspark@gmail.com>
Copyright (c) 2016-2026 Adrian L Lange <contact@p3lim.net>
Copyright (c) 2016-2026 Rainrider <rainrider.wow@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

================================================================================
KEY PRINCIPLE: NO ARITHMETIC ON VALUES
================================================================================

oUF's approach to handling WoW's secret value system:

1. NEVER perform arithmetic operations on health/power values
2. NEVER compare secret values (no <, >, ==, etc.)
3. Store raw current and max values directly
4. Let StatusBar:SetValue() handle the display automatically
5. Use UnitPowerPercent() and UnitHealthPercent() only for coloring

================================================================================
HEALTH BAR IMPLEMENTATION (from elements/health.lua)
================================================================================

Core Update Function:
--------------------
local function Update(self, event, unit)
	if(not unit or self.unit ~= unit) then return end
	local element = self.Health

	if(element.PreUpdate) then
		element:PreUpdate(unit)
	end

	-- GET VALUES: No arithmetic here!
	local cur, max = UnitHealth(unit), UnitHealthMax(unit)
	
	-- SET RANGE: StatusBar handles this internally
	element:SetMinMaxValues(0, max)

	-- SET VALUE: Let StatusBar do the display math
	if(UnitIsConnected(unit)) then
		element:SetValue(cur, element.smoothing)
	else
		element:SetValue(max, element.smoothing)
	end

	-- STORE VALUES: For callbacks, not for calculation!
	element.cur = cur
	element.max = max

	-- TEMP LOSS: Handle max health reduction
	local lossPerc = 0
	if(element.TempLoss) then
		lossPerc = GetUnitTotalModifiedMaxHealthPercent(unit)
		element.TempLoss:SetValue(lossPerc, element.smoothing)
	end

	if(element.PostUpdate) then
		element:PostUpdate(unit, cur, max, lossPerc)
	end
end

Key Points:
-----------
✓ Store cur and max directly - no division
✓ StatusBar:SetValue(cur, smoothing) - bar displays automatically
✓ NO calculations like: cur/max, (cur/max)*100, max-cur
✓ Values stored in element.cur and element.max for reference only

Registered Events:
-----------------
self:RegisterEvent('UNIT_HEALTH', Update)
self:RegisterEvent('UNIT_MAXHEALTH', Update)
self:RegisterEvent('UNIT_MAX_HEALTH_MODIFIERS_CHANGED', Update)

================================================================================
HEALTH BAR COLORING (from elements/health.lua)
================================================================================

Color Update Function:
---------------------
local function UpdateColor(self, event, unit)
	if(not unit or self.unit ~= unit) then return end
	local element = self.Health

	local color
	
	-- Priority-based color selection
	if(element.colorDisconnected and not UnitIsConnected(unit)) then
		color = self.colors.disconnected
	elseif(element.colorTapping and not UnitPlayerControlled(unit) and UnitIsTapDenied(unit)) then
		color = self.colors.tapped
	elseif(element.colorThreat and not UnitPlayerControlled(unit) and UnitThreatSituation('player', unit)) then
		color = self.colors.threat[UnitThreatSituation('player', unit)]
	elseif(element.colorClass and (UnitIsPlayer(unit) or UnitInPartyIsAI(unit)))
		or (element.colorClassNPC and not (UnitIsPlayer(unit) or UnitInPartyIsAI(unit)))
		or (element.colorClassPet and UnitPlayerControlled(unit) and not UnitIsPlayer(unit)) then
		local _, class = UnitClass(unit)
		color = self.colors.class[class]
	elseif(element.colorSelection and unitSelectionType(unit, element.considerSelectionInCombatHostile)) then
		color = self.colors.selection[unitSelectionType(unit, element.considerSelectionInCombatHostile)]
	elseif(element.colorReaction and UnitReaction(unit, 'player')) then
		color = self.colors.reaction[UnitReaction(unit, 'player')]
	
	-- CRITICAL: Use UnitHealthPercent for smooth coloring only!
	elseif(element.colorSmooth and self.colors.health:GetCurve()) then
		color = UnitHealthPercent(unit, true, self.colors.health:GetCurve())
	
	elseif(element.colorHealth) then
		color = self.colors.health
	end

	if(color) then
		element:GetStatusBarTexture():SetVertexColor(color:GetRGB())
	end

	if(element.PostUpdateColor) then
		element:PostUpdateColor(unit, color)
	end
end

Key Points:
-----------
✓ UnitHealthPercent() ONLY used for coloring, never for display
✓ GetCurve() provides smooth gradient coloring
✓ Color priority system prevents conflicts
✓ NO arithmetic on cur/max values

Color Events:
------------
self:RegisterEvent('UNIT_CONNECTION', ColorPath)     -- for colorDisconnected
self:RegisterEvent('UNIT_FLAGS', ColorPath)          -- for colorSelection
self:RegisterEvent('UNIT_FACTION', ColorPath)        -- for colorTapping/colorReaction
self:RegisterEvent('UNIT_THREAT_LIST_UPDATE', ColorPath) -- for colorThreat

================================================================================
POWER BAR IMPLEMENTATION (from elements/power.lua)
================================================================================

Core Update Function:
--------------------
local function Update(self, event, unit)
	if(self.unit ~= unit) then return end
	local element = self.Power

	if(element.PreUpdate) then
		element:PreUpdate(unit)
	end

	-- ALTERNATE POWER HANDLING
	local displayType, min
	if(element.displayAltPower) then
		displayType, min = element:GetDisplayPower(unit)
	end

	-- GET VALUES: No arithmetic!
	local cur, max = UnitPower(unit, displayType), UnitPowerMax(unit, displayType)
	min = min or 0
	
	-- SET RANGE AND VALUE
	element:SetMinMaxValues(min, max)

	if(UnitIsConnected(unit)) then
		element:SetValue(cur, element.smoothing)
	else
		element:SetValue(max, element.smoothing)
	end

	-- STORE VALUES
	element.cur = cur
	element.min = min
	element.max = max
	element.displayType = displayType

	if(element.PostUpdate) then
		element:PostUpdate(unit, cur, min, max)
	end
end

Alternative Power Detection:
---------------------------
local ALTERNATE_POWER_INDEX = Enum.PowerType.Alternate or 10

local function GetDisplayPower(_, unit)
	local barInfo = GetUnitPowerBarInfo(unit)
	if(barInfo and barInfo.showOnRaid and (UnitInParty(unit) or UnitInRaid(unit))) then
		return ALTERNATE_POWER_INDEX, barInfo.minPower
	end
	-- Returns nil if no alt power, falls back to primary power
end

Key Points:
-----------
✓ Supports alternative power (boss encounters, quests)
✓ Falls back to primary power type automatically
✓ Minimum value support (some powers don't start at 0)
✓ NO arithmetic on power values

Registered Events:
-----------------
self:RegisterEvent('UNIT_POWER_FREQUENT', Update)  -- if frequentUpdates
self:RegisterEvent('UNIT_POWER_UPDATE', Update)    -- default
self:RegisterEvent('UNIT_DISPLAYPOWER', Update)
self:RegisterEvent('UNIT_MAXPOWER', Update)
self:RegisterEvent('UNIT_POWER_BAR_HIDE', Update)
self:RegisterEvent('UNIT_POWER_BAR_SHOW', Update)

================================================================================
POWER BAR COLORING (from elements/power.lua)
================================================================================

Color Update Function:
---------------------
local function UpdateColor(self, event, unit)
	if(self.unit ~= unit) then return end
	local element = self.Power

	local r, g, b, color, atlas
	
	-- Standard color checks (disconnected, tapping, threat)
	if(element.colorDisconnected and not UnitIsConnected(unit)) then
		color = self.colors.disconnected
	elseif(element.colorTapping and not UnitPlayerControlled(unit) and UnitIsTapDenied(unit)) then
		color = self.colors.tapped
	elseif(element.colorThreat and not UnitPlayerControlled(unit) and UnitThreatSituation('player', unit)) then
		color = self.colors.threat[UnitThreatSituation('player', unit)]
	
	-- POWER TYPE COLOR
	elseif(element.colorPower) then
		if(element.displayType) then
			color = self.colors.power[element.displayType]
		end

		if(not color) then
			local pType, pToken, altR, altG, altB = UnitPowerType(unit)
			color = self.colors.power[pToken]

			-- Handle alternative colors from API
			if(not color and altR) then
				r, g, b = altR, altG, altB
				if(r > 1 or g > 1 or b > 1) then
					-- BUG FIX: Colors may be 0-1 or 0-255 range
					r, g, b = r / 255, g / 255, b / 255
				end
			else
				color = self.colors.power[pType] or self.colors.power.MANA
			end
		end

		-- ATLAS TEXTURE SUPPORT
		if(element.colorPowerAtlas and color) then
			atlas = color:GetAtlas()
		end

		-- SMOOTH GRADIENT COLOR
		if(element.colorPowerSmooth and color and color:GetCurve()) then
			color = UnitPowerPercent(unit, true, color:GetCurve())
		end
	
	-- Class/selection/reaction colors
	elseif(element.colorClass and (UnitIsPlayer(unit) or UnitInPartyIsAI(unit)))
		or (element.colorClassNPC and not (UnitIsPlayer(unit) or UnitInPartyIsAI(unit)))
		or (element.colorClassPet and UnitPlayerControlled(unit) and not UnitIsPlayer(unit)) then
		local _, class = UnitClass(unit)
		color = self.colors.class[class]
	elseif(element.colorSelection and unitSelectionType(unit, element.considerSelectionInCombatHostile)) then
		color = self.colors.selection[unitSelectionType(unit, element.considerSelectionInCombatHostile)]
	elseif(element.colorReaction and UnitReaction(unit, 'player')) then
		color = self.colors.reaction[UnitReaction(unit, 'player')]
	end

	-- APPLY COLOR OR ATLAS
	if(atlas) then
		element:SetStatusBarTexture(atlas)
		element:GetStatusBarTexture():SetVertexColor(1, 1, 1)
	else
		if(element.__texture) then
			element:SetStatusBarTexture(element.__texture)
		end

		if(b) then
			element:GetStatusBarTexture():SetVertexColor(r, g, b)
		elseif(color) then
			element:GetStatusBarTexture():SetVertexColor(color:GetRGB())
		end
	end

	if(element.PostUpdateColor) then
		element:PostUpdateColor(unit, color, r, g, b)
	end
end

Power Type Constants:
--------------------
Enum.PowerType.Mana = 0
Enum.PowerType.Rage = 1
Enum.PowerType.Focus = 2
Enum.PowerType.Energy = 3
Enum.PowerType.ComboPoints = 4
Enum.PowerType.Runes = 5
Enum.PowerType.RunicPower = 6
Enum.PowerType.SoulShards = 7
Enum.PowerType.LunarPower = 8
Enum.PowerType.HolyPower = 9
Enum.PowerType.Alternate = 10
Enum.PowerType.Maelstrom = 11
Enum.PowerType.Chi = 12
Enum.PowerType.Insanity = 13
Enum.PowerType.ArcaneCharges = 16
Enum.PowerType.Fury = 17
Enum.PowerType.Pain = 18
Enum.PowerType.Essence = 19

Key Points:
-----------
✓ UnitPowerType() returns type, token, and optional RGB values
✓ Color lookup by token (e.g., "MANA") then type (e.g., 0)
✓ Atlas textures can replace standard textures
✓ UnitPowerPercent() ONLY for smooth gradient coloring
✓ Bug fix for color range (0-1 vs 0-255)

================================================================================
ALTERNATIVE POWER BAR (from elements/alternativepower.lua)
================================================================================

This handles encounter-specific power bars (boss fights, quests).

Update Function:
---------------
local ALTERNATE_POWER_INDEX = Enum.PowerType.Alternate or 10
local ALTERNATE_POWER_NAME = 'ALTERNATE'

local function Update(self, event, unit, powerType)
	if(self.unit ~= unit or powerType ~= ALTERNATE_POWER_NAME) then return end
	local element = self.AlternativePower

	if(element.PreUpdate) then
		element:PreUpdate()
	end

	local cur, max, min
	local barInfo = element.__barInfo
	if(barInfo) then
		cur = UnitPower(unit, ALTERNATE_POWER_INDEX)
		max = UnitPowerMax(unit, ALTERNATE_POWER_INDEX)
		min = barInfo.minPower
		element:SetMinMaxValues(min, max)
		element:SetValue(cur, element.smoothing)
	end

	element.cur = cur
	element.min = min
	element.max = max

	if(element.PostUpdate) then
		return element:PostUpdate(unit, cur, min, max)
	end
end

Visibility Control:
------------------
local function Visibility(self, event, unit)
	if(unit ~= self.unit) then return end
	local element = self.AlternativePower

	local barID = UnitPowerBarID(unit)
	local barInfo = GetUnitPowerBarInfoByID(barID)
	element.__barID = barID
	element.__barInfo = barInfo
	
	if(barInfo and (barInfo.showOnRaid and (UnitInParty(unit) or UnitInRaid(unit))
		or not barInfo.hideFromOthers
		or UnitIsUnit(unit, 'player')))
	then
		self:RegisterEvent('UNIT_POWER_UPDATE', Path)
		self:RegisterEvent('UNIT_MAXPOWER', Path)
		element:Show()
		Path(self, event, unit, ALTERNATE_POWER_NAME)
	else
		self:UnregisterEvent('UNIT_POWER_UPDATE', Path)
		self:UnregisterEvent('UNIT_MAXPOWER', Path)
		element:Hide()
	end
end

Key Functions:
-------------
UnitPowerBarID(unit) - Get the power bar ID for alt power
GetUnitPowerBarInfoByID(barID) - Get bar info including:
  .minPower - Minimum value (not always 0!)
  .showOnRaid - Show in raid frames
  .hideFromOthers - Hide from non-player units

Events:
------
self:RegisterEvent('UNIT_POWER_BAR_SHOW', Visibility)
self:RegisterEvent('UNIT_POWER_BAR_HIDE', Visibility)

================================================================================
ADDITIONAL POWER BAR (from elements/additionalpower.lua)
================================================================================

This handles additional power for hybrid classes (e.g., Mana for Balance druids).

Display Pairs:
-------------
-- From Blizzard's ALT_POWER_BAR_PAIR_DISPLAY_INFO
element.displayPairs = {
	DRUID = {
		[0] = true,  -- Show mana when in cat/bear/guardian form
	},
	MONK = {
		[0] = true,  -- Show mana when in Stance of the Spirited Crane
	},
	PRIEST = {
		[1] = true,  -- Show mana when in Shadowform
	},
	SHAMAN = {
		[0] = true,  -- Show mana when in certain forms
	},
}

Update Function:
---------------
local ADDITIONAL_POWER_BAR_NAME = 'MANA'
local ADDITIONAL_POWER_BAR_INDEX = 0

local function Update(self, event, unit, powerType)
	if(not (unit and UnitIsUnit(unit, 'player') and powerType == ADDITIONAL_POWER_BAR_NAME)) then return end
	local element = self.AdditionalPower

	if(element.PreUpdate) then
		element:PreUpdate(unit)
	end

	local cur, max = UnitPower('player', ADDITIONAL_POWER_BAR_INDEX), UnitPowerMax('player', ADDITIONAL_POWER_BAR_INDEX)
	element:SetMinMaxValues(0, max)
	element:SetValue(cur, element.smoothing)

	element.cur = cur
	element.max = max

	if(element.PostUpdate) then
		return element:PostUpdate(cur, max)
	end
end

Visibility Logic:
----------------
local function Visibility(self, event, unit)
	local element = self.AdditionalPower
	local shouldEnable

	if(not UnitHasVehicleUI('player')) then
		if(UnitPowerMax(unit, ADDITIONAL_POWER_BAR_INDEX) ~= 0) then
			if(element.displayPairs[playerClass]) then
				local powerType = UnitPowerType(unit)
				shouldEnable = element.displayPairs[playerClass][powerType]
			end
		end
	end

	-- Show/hide based on shouldEnable
	if(shouldEnable and not isEnabled) then
		ElementEnable(self)
	elseif(not shouldEnable and isEnabled) then
		ElementDisable(self)
	end
end

Key Points:
-----------
✓ Only for player unit
✓ Class-specific display rules
✓ Auto-hide in vehicles
✓ Check if max power > 0 before showing

================================================================================
STATUSBAR SMOOTHING
================================================================================

oUF uses WoW's built-in StatusBar interpolation system:

Smoothing Options:
-----------------
Enum.StatusBarInterpolation.Immediate = 0  -- No smoothing (instant)
Enum.StatusBarInterpolation.Smooth = 1     -- Smooth transition

Usage:
-----
element.smoothing = Enum.StatusBarInterpolation.Smooth
element:SetValue(newValue, element.smoothing)

This is built into WoW's StatusBar widget - no custom smoothing code needed!

================================================================================
CRITICAL DIFFERENCES FROM STUF
================================================================================

STUF'S OLD APPROACH (BROKEN):
-----------------------------
1. Calculate fraction: frac = current / total
2. Compare values: if current == 0, if current >= total
3. Calculate percentages: frac * 100
4. Calculate deficits: total - current
5. Store calculated values: cache.frachp, cache.perchp

oUF'S APPROACH (WORKS):
----------------------
1. Get raw values: cur, max = UnitHealth(unit), UnitHealthMax(unit)
2. Store raw values: element.cur = cur, element.max = max
3. Set bar directly: element:SetValue(cur)
4. StatusBar handles display automatically
5. Use UnitHealthPercent/UnitPowerPercent ONLY for coloring

WHY STUF NEEDS TO CHANGE:
-------------------------
✗ Cache stores calculated fractions (frachp, fracmp, perchp, percmp)
✗ These are used everywhere in text.lua, bars.lua, core.lua
✗ Secret values break ALL arithmetic operations
✗ Can't convert secret values to regular numbers

MIGRATION PATH:
--------------
1. Store raw cur/max in cache instead of fractions
2. Let StatusBar widgets display automatically
3. Remove all arithmetic on health/power values
4. Use percentage functions ONLY for coloring
5. Update text formatting to handle raw values

================================================================================
COMPLETE API REFERENCE
================================================================================

Health Functions:
----------------
UnitHealth(unit) - Returns current health (may be secret value)
UnitHealthMax(unit) - Returns max health (may be secret value)
UnitHealthPercent(unit, omitDecimal, curve) - Returns health percentage for COLORING
GetUnitTotalModifiedMaxHealthPercent(unit) - Returns temp max health reduction percent
UnitIsConnected(unit) - Check if unit is online
UnitIsDeadOrGhost(unit) - Check if dead/ghost

Power Functions:
---------------
UnitPower(unit, type) - Returns current power (may be secret value)
UnitPowerMax(unit, type) - Returns max power (may be secret value)
UnitPowerType(unit) - Returns type, token, altR, altG, altB
UnitPowerPercent(unit, omitDecimal, curve) - Returns power percentage for COLORING
UnitPowerBarID(unit) - Get alternative power bar ID
GetUnitPowerBarInfo(unit) - Get power bar info for primary/alt power
GetUnitPowerBarInfoByID(barID) - Get power bar info by ID

StatusBar Methods:
-----------------
bar:SetMinMaxValues(min, max) - Set the range
bar:SetValue(value, interpolation) - Set current value with optional smoothing
bar:GetStatusBarTexture() - Get the texture object
texture:SetVertexColor(r, g, b, a) - Set the color
bar:SetStatusBarTexture(texture) - Set the texture

Color Methods (ColorMixin):
--------------------------
color:GetRGB() - Returns r, g, b (0-1 range)
color:GetAtlas() - Returns atlas name (if available)
color:GetCurve() - Returns curve function for smooth gradients

================================================================================
EXAMPLE: COMPLETE HEALTH BAR SETUP
================================================================================

-- Create the StatusBar
local Health = CreateFrame('StatusBar', nil, self)
Health:SetHeight(20)
Health:SetPoint('TOP')
Health:SetPoint('LEFT')
Health:SetPoint('RIGHT')

-- Set default texture
Health:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])

-- Configure smoothing
Health.smoothing = Enum.StatusBarInterpolation.Smooth

-- Configure coloring
Health.colorDisconnected = true
Health.colorTapping = true
Health.colorClass = true
Health.colorReaction = true
Health.colorHealth = true

-- Update function
local function UpdateHealth(self, event, unit)
	if self.unit ~= unit then return end
	
	-- Get raw values - NO ARITHMETIC!
	local cur, max = UnitHealth(unit), UnitHealthMax(unit)
	
	-- Update bar - StatusBar handles the display math
	Health:SetMinMaxValues(0, max)
	if UnitIsConnected(unit) then
		Health:SetValue(cur, Health.smoothing)
	else
		Health:SetValue(max, Health.smoothing)
	end
	
	-- Store for callbacks (not for calculation!)
	Health.cur = cur
	Health.max = max
	
	-- Update color
	local color = self.colors.health
	if Health.colorClass and UnitIsPlayer(unit) then
		local _, class = UnitClass(unit)
		color = self.colors.class[class]
	end
	
	if color then
		Health:GetStatusBarTexture():SetVertexColor(color:GetRGB())
	end
end

-- Register events
self:RegisterEvent('UNIT_HEALTH', UpdateHealth)
self:RegisterEvent('UNIT_MAXHEALTH', UpdateHealth)

================================================================================
CONCLUSION
================================================================================

The key takeaway: NEVER do arithmetic on health/power values in WoW's modern
secret value system. Let StatusBar widgets handle all display calculations by
passing raw cur/max values directly to SetValue().

For text display, accept that some features (percentages, deficits) cannot
work with secret values and must either be hidden or use fallback values.

This reference document should help guide Stuf's migration to be compatible
with WoW's secret value protection system.

--]]
