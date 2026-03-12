--[[
================================================================================
Stuf Unit Frames - Information Calculator Module (infoCalc.lua)
================================================================================
Version: 11.0.7+ (Secret Value Compatible)
Created: February 2, 2026
Purpose: Centralized health/power calculation system using secret-value-safe methods

This module provides a clean API for retrieving unit health, power, and status
information without performing arithmetic on secret values.

Based on oUF (UnhaltedUnitFrames) patterns and WoW 11.0.7+ secret value system.

================================================================================
USAGE EXAMPLE:
================================================================================

local InfoCalc = Stuf.InfoCalc

-- Get health info for a unit
local healthInfo = InfoCalc:GetHealthInfo("player")
-- Returns: { cur, max, isDead, isGhost, isConnected, isFull, isEmpty }

-- Get power info for a unit  
local powerInfo = InfoCalc:GetPowerInfo("player")
-- Returns: { cur, max, min, powerType, powerToken, r, g, b, hasAltPower }

-- Check if a value is secret
local isSecret = InfoCalc:IsSecretValue(someValue)

-- Get safe color for health (works with secret values)
local r, g, b = InfoCalc:GetHealthColor(unit, smoothGradient)

================================================================================
--]]

-- Stuf is a global frame created in core.lua
local InfoCalc = {}
Stuf.InfoCalc = InfoCalc

-- Cache frequently used functions
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerType = UnitPowerType
local UnitIsConnected = UnitIsConnected
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsDead = UnitIsDead
local UnitIsGhost = UnitIsGhost
local UnitIsPlayer = UnitIsPlayer
local UnitClass = UnitClass
local UnitReaction = UnitReaction
local UnitHealthPercent = UnitHealthPercent
local UnitPowerPercent = UnitPowerPercent
local GetUnitPowerBarInfo = GetUnitPowerBarInfo
local UnitPowerBarID = UnitPowerBarID
local GetUnitPowerBarInfoByID = GetUnitPowerBarInfoByID
local UnitInParty = UnitInParty
local UnitInRaid = UnitInRaid

-- Constants
local ALTERNATE_POWER_INDEX = Enum.PowerType.Alternate or 10

-- Power type display pairs for hybrid classes
local ADDITIONAL_POWER_PAIRS = {
	DRUID = { [0] = true },   -- Show mana in cat/bear form
	MONK = { [0] = true },    -- Show mana in Stance of the Spirited Crane
	PRIEST = { [1] = true },  -- Show mana in Shadowform
	SHAMAN = { [0] = true },  -- Show mana in certain forms
}

--------------------------------------------------------------------------------
-- SECRET VALUE DETECTION
--------------------------------------------------------------------------------

--[[
	Detects if a value is a "secret value" that cannot be used in arithmetic.
	
	@param value - The value to check
	@return boolean - true if value is secret, false otherwise
--]]
function InfoCalc:IsSecretValue(value)
	if type(value) ~= "number" then
		return false
	end
	
	-- Try to perform arithmetic - will fail on secret values
	local success = pcall(function() 
		local _ = (value * 1) 
	end)
	
	return not success
end

--[[
	Safely converts a value to string, handling secret values.
	
	@param value - The value to convert
	@return string - String representation or empty string for secret values
--]]
function InfoCalc:SafeToString(value)
	if self:IsSecretValue(value) then
		return ""
	end
	return tostring(value)
end

--------------------------------------------------------------------------------
-- HEALTH INFORMATION
--------------------------------------------------------------------------------

--[[
	Gets comprehensive health information for a unit.
	Stores raw values only - no arithmetic on secret values!
	
	@param unit - Unit ID (e.g., "player", "target", "party1")
	@return table - Health information:
		{
			cur = current health (raw value, may be secret),
			max = max health (raw value, may be secret),
			isDead = boolean,
			isGhost = boolean,
			isConnected = boolean,
			isFull = boolean (safe check using API),
			isEmpty = boolean (safe check using API)
		}
--]]
function InfoCalc:GetHealthInfo(unit)
	if not unit then return nil end
	
	local cur = UnitHealth(unit)
	local max = UnitHealthMax(unit)
	local isDead = UnitIsDead(unit)
	local isGhost = UnitIsGhost(unit)
	local isConnected = UnitIsConnected(unit)
	
	-- Safe boolean checks without arithmetic
	local isFull = false
	local isEmpty = false
	
	-- Use API functions for state detection instead of comparisons
	if UnitIsDeadOrGhost(unit) then
		isEmpty = true
	end
	
	-- For isFull, we can only use percentage check
	if not self:IsSecretValue(cur) and not self:IsSecretValue(max) then
		-- If values aren't secret, we can compare safely
		isFull = (cur == max)
		isEmpty = (cur == 0) or isEmpty
	end
	
	return {
		cur = cur,
		max = max,
		isDead = isDead,
		isGhost = isGhost,
		isConnected = isConnected,
		isFull = isFull,
		isEmpty = isEmpty,
	}
end

--[[
	Gets health color for a unit using safe methods.
	Uses UnitHealthPercent for smooth gradients (secret-value safe).
	
	@param unit - Unit ID
	@param useSmooth - boolean, use smooth gradient if true
	@param curve - optional curve function for smooth coloring
	@return r, g, b - Color values (0-1 range)
--]]
function InfoCalc:GetHealthColor(unit, useSmooth, curve)
	if not unit then return 1, 1, 1 end
	
	-- Use UnitHealthPercent for smooth coloring (this is secret-value safe!)
	if useSmooth and curve then
		local percent = UnitHealthPercent(unit, true, curve)
		if percent then
			-- Gradient from red (low) -> yellow (medium) -> green (high)
			local r, g, b
			if percent < 0.5 then
				-- Red to yellow (0% to 50%)
				r = 1
				g = percent * 2
				b = 0
			else
				-- Yellow to green (50% to 100%)
				r = 1 - ((percent - 0.5) * 2)
				g = 1
				b = 0
			end
			return r, g, b
		end
	end
	
	-- Fallback: class color for players, reaction color for NPCs
	if UnitIsPlayer(unit) then
		local _, class = UnitClass(unit)
		local color = RAID_CLASS_COLORS[class]
		if color then
			return color.r, color.g, color.b
		end
	else
		local reaction = UnitReaction(unit, "player")
		if reaction then
			local color = FACTION_BAR_COLORS[reaction]
			if color then
				return color.r, color.g, color.b
			end
		end
	end
	
	-- Default green
	return 0, 1, 0
end

--------------------------------------------------------------------------------
-- POWER INFORMATION
--------------------------------------------------------------------------------

--[[
	Gets comprehensive power information for a unit.
	Handles primary power, alternative power, and additional power.
	
	@param unit - Unit ID
	@param useAltPower - boolean, check for alternative power
	@return table - Power information:
		{
			cur = current power (raw value, may be secret),
			max = max power (raw value, may be secret),
			min = minimum power value (usually 0, but not always),
			powerType = power type index,
			powerToken = power type token string,
			r = red component (0-1) for power color,
			g = green component (0-1) for power color,
			b = blue component (0-1) for power color,
			hasAltPower = boolean, true if alternative power exists,
			altPowerInfo = table or nil (only if hasAltPower is true)
		}
--]]
function InfoCalc:GetPowerInfo(unit, useAltPower)
	if not unit then return nil end
	
	local powerType, powerToken, r, g, b = UnitPowerType(unit)
	local displayType = powerType
	local min = 0
	local hasAltPower = false
	local altPowerInfo = nil
	
	-- Check for alternative power (boss encounters, quests)
	if useAltPower then
		local barInfo = GetUnitPowerBarInfo(unit)
		if barInfo and barInfo.showOnRaid and (UnitInParty(unit) or UnitInRaid(unit)) then
			displayType = ALTERNATE_POWER_INDEX
			min = barInfo.minPower or 0
			hasAltPower = true
			
			altPowerInfo = {
				barID = UnitPowerBarID(unit),
				barInfo = barInfo,
				name = barInfo.name or "",
				tooltip = barInfo.barText or "",
			}
		end
	end
	
	local cur = UnitPower(unit, displayType)
	local max = UnitPowerMax(unit, displayType)
	
	-- Handle color from UnitPowerType
	if r and g and b then
		-- API may return 0-255 or 0-1 range - normalize it
		if r > 1 or g > 1 or b > 1 then
			r, g, b = r / 255, g / 255, b / 255
		end
	else
		-- Fallback to standard power colors
		r, g, b = self:GetPowerColor(powerType, powerToken)
	end
	
	return {
		cur = cur,
		max = max,
		min = min,
		powerType = powerType,
		powerToken = powerToken,
		displayType = displayType,
		r = r,
		g = g,
		b = b,
		hasAltPower = hasAltPower,
		altPowerInfo = altPowerInfo,
	}
end

--[[
	Gets standard power type colors.
	
	@param powerType - Power type index
	@param powerToken - Power type token string
	@return r, g, b - Color values (0-1 range)
--]]
function InfoCalc:GetPowerColor(powerType, powerToken)
	-- Standard power colors
	local colors = {
		MANA = {0.00, 0.00, 1.00},
		RAGE = {1.00, 0.00, 0.00},
		FOCUS = {1.00, 0.50, 0.25},
		ENERGY = {1.00, 1.00, 0.00},
		RUNIC_POWER = {0.00, 0.82, 1.00},
		SOUL_SHARDS = {0.50, 0.32, 0.55},
		LUNAR_POWER = {0.30, 0.52, 0.90},
		HOLY_POWER = {0.95, 0.90, 0.60},
		MAELSTROM = {0.00, 0.50, 1.00},
		CHI = {0.71, 1.00, 0.92},
		INSANITY = {0.40, 0.00, 0.80},
		ARCANE_CHARGES = {0.41, 0.80, 0.94},
		FURY = {0.79, 0.26, 0.99},
		PAIN = {1.00, 0.61, 0.00},
		ESSENCE = {0.90, 0.82, 1.00},
	}
	
	-- Try token first, then type index
	local color = colors[powerToken]
	if not color then
		-- Fallback by type index
		if powerType == 0 then color = colors.MANA
		elseif powerType == 1 then color = colors.RAGE
		elseif powerType == 2 then color = colors.FOCUS
		elseif powerType == 3 then color = colors.ENERGY
		elseif powerType == 6 then color = colors.RUNIC_POWER
		else color = {0.5, 0.5, 0.5} -- Gray fallback
		end
	end
	
	return color[1], color[2], color[3]
end

--[[
	Gets power color for a unit using safe methods.
	Uses UnitPowerPercent for smooth gradients (secret-value safe).
	
	@param unit - Unit ID
	@param useSmooth - boolean, use smooth gradient if true
	@param curve - optional curve function for smooth coloring
	@return r, g, b - Color values (0-1 range)
--]]
function InfoCalc:GetPowerColorForUnit(unit, useSmooth, curve)
	if not unit then return 1, 1, 1 end
	
	local powerInfo = self:GetPowerInfo(unit, false)
	
	-- Use UnitPowerPercent for smooth coloring (secret-value safe!)
	if useSmooth and curve then
		local percent = UnitPowerPercent(unit, true, curve)
		if percent then
			-- Apply gradient to base power color
			local baseR, baseG, baseB = powerInfo.r, powerInfo.g, powerInfo.b
			local darkenFactor = percent  -- Darken when low
			return baseR * darkenFactor, baseG * darkenFactor, baseB * darkenFactor
		end
	end
	
	return powerInfo.r, powerInfo.g, powerInfo.b
end

--------------------------------------------------------------------------------
-- ADDITIONAL POWER (for hybrid classes)
--------------------------------------------------------------------------------

--[[
	Checks if a unit should display additional power (e.g., mana for druids).
	
	@param unit - Unit ID
	@param playerClass - Player class token (e.g., "DRUID")
	@return boolean - true if additional power should be shown
--]]
function InfoCalc:ShouldShowAdditionalPower(unit, playerClass)
	if not UnitIsUnit(unit, "player") then
		return false
	end
	
	-- Don't show in vehicles
	if UnitHasVehicleUI("player") then
		return false
	end
	
	-- Check if max additional power > 0
	if UnitPowerMax(unit, 0) == 0 then
		return false
	end
	
	-- Check class-specific display rules
	if ADDITIONAL_POWER_PAIRS[playerClass] then
		local powerType = UnitPowerType(unit)
		return ADDITIONAL_POWER_PAIRS[playerClass][powerType]
	end
	
	return false
end

--[[
	Gets additional power information (always uses MANA index 0).
	
	@param unit - Unit ID (should be "player")
	@return table - Additional power info or nil
--]]
function InfoCalc:GetAdditionalPowerInfo(unit)
	local cur = UnitPower(unit, 0)
	local max = UnitPowerMax(unit, 0)
	
	if max == 0 then
		return nil
	end
	
	local r, g, b = self:GetPowerColor(0, "MANA")
	
	return {
		cur = cur,
		max = max,
		min = 0,
		powerType = 0,
		powerToken = "MANA",
		r = r,
		g = g,
		b = b,
	}
end

--------------------------------------------------------------------------------
-- STATUS BAR HELPERS
--------------------------------------------------------------------------------

--[[
	Updates a StatusBar with health values using secret-value-safe methods.
	
	@param statusBar - StatusBar frame
	@param unit - Unit ID
	@param smoothing - Smoothing mode (Enum.StatusBarInterpolation.Smooth or .Immediate)
	@return boolean - true if successful
--]]
function InfoCalc:UpdateHealthBar(statusBar, unit, smoothing)
	if not statusBar or not unit then return false end
	
	local healthInfo = self:GetHealthInfo(unit)
	if not healthInfo then return false end
	
	-- Set range
	statusBar:SetMinMaxValues(0, healthInfo.max)
	
	-- Set value with smoothing
	local interpolation = smoothing or (Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Smooth) or 0
	
	if healthInfo.isConnected then
		statusBar:SetValue(healthInfo.cur)
	else
		-- Show full bar when disconnected
		statusBar:SetValue(healthInfo.max)
	end
	
	return true
end

--[[
	Updates a StatusBar with power values using secret-value-safe methods.
	
	@param statusBar - StatusBar frame
	@param unit - Unit ID
	@param useAltPower - boolean, check for alternative power
	@param smoothing - Smoothing mode (Enum.StatusBarInterpolation.Smooth or .Immediate)
	@return boolean - true if successful
--]]
function InfoCalc:UpdatePowerBar(statusBar, unit, useAltPower, smoothing)
	if not statusBar or not unit then return false end
	
	local powerInfo = self:GetPowerInfo(unit, useAltPower)
	if not powerInfo then return false end
	
	-- Set range (may have non-zero minimum!)
	statusBar:SetMinMaxValues(powerInfo.min, powerInfo.max)
	
	-- Set value with smoothing
	statusBar:SetValue(powerInfo.cur)
	
	return true
end

--------------------------------------------------------------------------------
-- TEXT FORMATTING HELPERS
--------------------------------------------------------------------------------

--[[
	Formats a value for text display, handling secret values safely.
	Returns empty string for secret values since they can't be converted.
	
	@param value - The value to format
	@param formatStr - Optional format string (e.g., "%.0f")
	@return string - Formatted value or empty string
--]]
function InfoCalc:FormatValue(value, formatStr)
	if self:IsSecretValue(value) then
		return ""
	end
	
	if formatStr then
		return format(formatStr, value)
	end
	
	return tostring(value)
end

--[[
	Formats health text in various styles.
	Returns safe fallback text for secret values.
	
	@param healthInfo - Table from GetHealthInfo()
	@param style - "current", "max", "both", "percent", "deficit"
	@return string - Formatted text
--]]
function InfoCalc:FormatHealthText(healthInfo, style)
	if not healthInfo then return "" end
	
	style = style or "both"
	
	-- Check if values are secret
	local curIsSecret = self:IsSecretValue(healthInfo.cur)
	local maxIsSecret = self:IsSecretValue(healthInfo.max)
	
	if style == "current" then
		if curIsSecret then return "" end
		return self:FormatValue(healthInfo.cur, "%.0f")
		
	elseif style == "max" then
		if maxIsSecret then return "" end
		return self:FormatValue(healthInfo.max, "%.0f")
		
	elseif style == "both" then
		if curIsSecret or maxIsSecret then
			-- Fallback for secret values
			if healthInfo.isDead then return "Dead"
			elseif healthInfo.isGhost then return "Ghost"
			elseif not healthInfo.isConnected then return "Offline"
			else return ""
			end
		end
		return format("%.0f / %.0f", healthInfo.cur, healthInfo.max)
		
	elseif style == "percent" then
		-- Can't calculate percent with secret values
		if curIsSecret or maxIsSecret then return "" end
		local percent = (healthInfo.cur / healthInfo.max) * 100
		return format("%.0f%%", percent)
		
	elseif style == "deficit" then
		-- Can't calculate deficit with secret values
		if curIsSecret or maxIsSecret then return "" end
		local deficit = healthInfo.max - healthInfo.cur
		if deficit > 0 then
			return format("-%.0f", deficit)
		end
		return ""
	end
	
	return ""
end

--[[
	Formats power text in various styles.
	Returns safe fallback text for secret values.
	
	@param powerInfo - Table from GetPowerInfo()
	@param style - "current", "max", "both", "percent", "deficit"
	@return string - Formatted text
--]]
function InfoCalc:FormatPowerText(powerInfo, style)
	if not powerInfo then return "" end
	
	style = style or "both"
	
	-- Check if values are secret
	local curIsSecret = self:IsSecretValue(powerInfo.cur)
	local maxIsSecret = self:IsSecretValue(powerInfo.max)
	
	if style == "current" then
		if curIsSecret then return "" end
		return self:FormatValue(powerInfo.cur, "%.0f")
		
	elseif style == "max" then
		if maxIsSecret then return "" end
		return self:FormatValue(powerInfo.max, "%.0f")
		
	elseif style == "both" then
		if curIsSecret or maxIsSecret then return "" end
		return format("%.0f / %.0f", powerInfo.cur, powerInfo.max)
		
	elseif style == "percent" then
		-- Can't calculate percent with secret values
		if curIsSecret or maxIsSecret then return "" end
		local percent = (powerInfo.cur / powerInfo.max) * 100
		return format("%.0f%%", percent)
		
	elseif style == "deficit" then
		-- Can't calculate deficit with secret values
		if curIsSecret or maxIsSecret then return "" end
		local deficit = powerInfo.max - powerInfo.cur
		if deficit > 0 then
			return format("-%.0f", deficit)
		end
		return ""
	end
	
	return ""
end

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------

--[[
	Abbreviates large numbers for display (K, M, B).
	
	@param value - Number to abbreviate
	@return string - Abbreviated value
--]]
function InfoCalc:AbbreviateNumber(value)
	if self:IsSecretValue(value) then
		return ""
	end
	
	if value >= 1000000000 then
		return format("%.1fB", value / 1000000000)
	elseif value >= 1000000 then
		return format("%.1fM", value / 1000000)
	elseif value >= 1000 then
		return format("%.1fK", value / 1000)
	else
		return format("%.0f", value)
	end
end

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

--[[
	Initializes the InfoCalc module.
	Call this once when Stuf loads.
--]]
function InfoCalc:Initialize()
	-- Any initialization needed
	-- Could cache player class here, etc.
	local _, playerClass = UnitClass("player")
	self.playerClass = playerClass
	
	print("|cff00ff00Stuf InfoCalc|r: Information Calculator initialized (Secret-value safe)")
end

-- Return the module
return InfoCalc
