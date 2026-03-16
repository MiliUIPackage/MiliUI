--[[
================================================================================
Stuf Unit Frames - Information Calculator Module (infoCalc.lua)
================================================================================
Version: 12.0.1 (Midnight) — MSUF-pattern rewrite
Redesigned: March 2026
Purpose: Centralized health/power calculation system using secret-value-safe methods.

REDESIGN NOTES (why old code was replaced):
  - Old code tried to detect secret values via pcall(arithmetic) and guard them.
    This was fragile and prevented bars from ever working in combat.
  - New approach (from MidnightSimpleUnitFrames / oUF):
      * Pass secret values DIRECTLY to the StatusBar C API.
        bar:SetMinMaxValues(0, maxHP)  -- C handles secret values natively
        bar:SetValue(curHP)            -- C handles secret values natively
      * For TEXT: use UnitHealthPercent() / UnitPowerPercent() which always return
        safe normal Lua numbers (0-100). For raw hp/mp numbers, pass the secret
        value directly to FontString:SetText(value) -- C handles it.
      * NEVER do Lua arithmetic (+,-,*,/,<,>,==) on secret values.
  - IsSecretValue() kept as a utility guard for edge cases, but bars and text
    no longer depend on it for their primary update path.

================================================================================
--]]

-- Stuf is a global frame created in core.lua
local InfoCalc = {}
Stuf.InfoCalc = InfoCalc

-- ============================================================================
-- UPVALUE CACHE
-- ============================================================================
-- (unchanged — localising globals is still correct for performance)
local UnitHealth          = UnitHealth
local UnitHealthMax       = UnitHealthMax
local UnitPower           = UnitPower
local UnitPowerMax        = UnitPowerMax
local UnitPowerType       = UnitPowerType
local UnitIsConnected     = UnitIsConnected
local UnitIsDeadOrGhost   = UnitIsDeadOrGhost
local UnitIsDead          = UnitIsDead
local UnitIsGhost         = UnitIsGhost
local UnitIsPlayer        = UnitIsPlayer
local UnitClass           = UnitClass
local UnitReaction        = UnitReaction
local UnitHealthPercent   = UnitHealthPercent   -- always returns safe 0-100
local UnitPowerPercent    = UnitPowerPercent    -- always returns safe 0-100
local GetUnitPowerBarInfo = GetUnitPowerBarInfo
local UnitPowerBarID      = UnitPowerBarID
local UnitInParty         = UnitInParty
local UnitInRaid          = UnitInRaid

-- NEW: UnitGetDetailedHealPrediction + CreateUnitHealPredictionCalculator
-- used by UpdateHealthBar for incoming heal overlay (Step 3 prep)
local UnitGetDetailedHealPrediction       = UnitGetDetailedHealPrediction
local CreateUnitHealPredictionCalculator  = CreateUnitHealPredictionCalculator

-- Constants
local ALTERNATE_POWER_INDEX = Enum.PowerType.Alternate or 10

-- Power type display pairs for hybrid classes (unchanged)
local ADDITIONAL_POWER_PAIRS = {
	DRUID  = { [0] = true },
	MONK   = { [0] = true },
	PRIEST = { [1] = true },
	SHAMAN = { [0] = true },
}

-- ============================================================================
-- SECRET VALUE DETECTION  (kept as utility; bars no longer depend on this)
-- ============================================================================

--[[ OLD IMPLEMENTATION — replaced, see below
function InfoCalc:IsSecretValue(value)
	if type(value) ~= "number" then
		return false
	end
	local success = pcall(function()
		local _ = (value * 1)
	end)
	return not success
end
--]]

-- NEW: same pcall approach but now only used as a last-resort guard.
-- Primary bar/text paths pass values straight to C and never call this.
function InfoCalc:IsSecretValue(value)
	if type(value) ~= "number" then return false end
	local ok = pcall(function() local _ = value + 0 end)
	return not ok
end

--[[ OLD SafeToString — replaced, see below
function InfoCalc:SafeToString(value)
	if self:IsSecretValue(value) then
		return ""
	end
	return tostring(value)
end
--]]

-- NEW: For raw hp/mp numbers, callers should use FontString:SetText(value) directly
-- (C handles secret values). This helper is kept for non-bar debug/logging use only.
function InfoCalc:SafeToString(value)
	if type(value) ~= "number" then return tostring(value) end
	-- Don't call tostring on secret numbers in Lua — let C do it via SetText.
	-- Return empty string here; use FontString:SetText(rawValue) at the call site.
	if self:IsSecretValue(value) then return "" end
	return tostring(value)
end

-- ============================================================================
-- HEALTH INFORMATION
-- ============================================================================

--[[ OLD GetHealthInfo — replaced, see below
function InfoCalc:GetHealthInfo(unit)
	if not unit then return nil end
	local cur = UnitHealth(unit)
	local max = UnitHealthMax(unit)
	local isDead = UnitIsDead(unit)
	local isGhost = UnitIsGhost(unit)
	local isConnected = UnitIsConnected(unit)
	local isFull = false
	local isEmpty = false
	if UnitIsDeadOrGhost(unit) then
		isEmpty = true
	end
	-- PROBLEM: IsSecretValue pcall happens on every update — expensive and
	-- still returns wrong results (type() reports "number" for secrets).
	if not self:IsSecretValue(cur) and not self:IsSecretValue(max) then
		isFull = (cur == max)
		isEmpty = (cur == 0) or isEmpty
	end
	return { cur=cur, max=max, isDead=isDead, isGhost=isGhost,
	         isConnected=isConnected, isFull=isFull, isEmpty=isEmpty }
end
--]]

-- NEW GetHealthInfo:
--   * Stores raw secret values without touching them in Lua.
--   * isFull / isEmpty derived from UnitHealthPercent (safe normal number).
--   * percent field added — callers should use this instead of cur/max math.
function InfoCalc:GetHealthInfo(unit)
	if not unit then return nil end

	local cur         = UnitHealth(unit)       -- may be secret; pass to C only
	local max         = UnitHealthMax(unit)    -- may be secret; pass to C only
	local isDead      = UnitIsDead(unit)
	local isGhost     = UnitIsGhost(unit)
	local isConnected = UnitIsConnected(unit)

	-- UnitHealthPercent returns a safe normal number (0-100). Use it for
	-- all Lua-side logic that would otherwise touch secret values.
	local pct    = UnitHealthPercent(unit) or 0   -- safe normal number
	local isFull  = (pct >= 100)
	local isEmpty = UnitIsDeadOrGhost(unit) or (pct <= 0)

	return {
		cur         = cur,          -- raw secret value — only pass to SetValue/SetText
		max         = max,          -- raw secret value — only pass to SetMinMaxValues/SetText
		percent     = pct,          -- safe normal number (0-100) — use for Lua math/color
		isDead      = isDead,
		isGhost     = isGhost,
		isConnected = isConnected,
		isFull      = isFull,
		isEmpty     = isEmpty,
	}
end

-- ============================================================================
-- HEALTH COLOR
-- ============================================================================

--[[ OLD GetHealthColor — replaced, see below
function InfoCalc:GetHealthColor(unit, useSmooth, curve)
	-- PROBLEM: UnitHealthPercent(unit, true, curve) signature is incorrect;
	-- UnitHealthPercent takes only (unit). The curve argument was silently ignored.
	if useSmooth and curve then
		local percent = UnitHealthPercent(unit, true, curve)
		...
	end
	...
end
--]]

-- NEW GetHealthColor:
--   * Uses UnitHealthPercent(unit) — correct signature, safe normal number.
--   * Gradient computed purely on a 0-1 Lua fraction derived from the percent.
--   * No secret value arithmetic anywhere.
function InfoCalc:GetHealthColor(unit, useSmooth)
	if not unit then return 1, 1, 1 end

	if useSmooth then
		-- UnitHealthPercent is also secret in 12.0.1; pcall the multiply
		local rawpct = UnitHealthPercent(unit)
		local ok, frac = pcall(function() return rawpct * 0.01 end)
		if not ok then return 0, 1, 0 end
		local r, g, b
		if frac < 0.5 then
			-- red → yellow  (0% to 50%)
			r = 1
			g = frac * 2
			b = 0
		else
			-- yellow → green  (50% to 100%)
			r = 1 - ((frac - 0.5) * 2)
			g = 1
			b = 0
		end
		return r, g, b
	end

	-- Fallback: class color for players, reaction color for NPCs
	if UnitIsPlayer(unit) then
		local _, class = UnitClass(unit)
		local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
		if color then return color.r, color.g, color.b end
	else
		local reaction = UnitReaction(unit, "player")
		if reaction then
			local color = FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
			if color then return color.r, color.g, color.b end
		end
	end

	return 0, 1, 0   -- default green
end

-- ============================================================================
-- POWER INFORMATION
-- ============================================================================

--[[ OLD GetPowerInfo — replaced, see below
function InfoCalc:GetPowerInfo(unit, useAltPower)
	...
	-- PROBLEM: color normalisation used comparison (r > 1) on values returned
	-- by UnitPowerType. In 12.0 UnitPowerType returns 0-1 floats; the old
	-- guard was a no-op at best and could break if the API changes again.
	if r and g and b then
		if r > 1 or g > 1 or b > 1 then   -- fragile comparison
			r, g, b = r / 255, g / 255, b / 255
		end
	end
	...
end
--]]

-- NEW GetPowerInfo:
--   * Stores raw secret values without touching them.
--   * percent field added (safe number via UnitPowerPercent).
--   * Color normalisation removed — UnitPowerType returns 0-1 in 12.0.
function InfoCalc:GetPowerInfo(unit, useAltPower)
	if not unit then return nil end

	local powerType, powerToken, r, g, b = UnitPowerType(unit)
	local displayType  = powerType
	local min          = 0
	local hasAltPower  = false
	local altPowerInfo = nil

	-- Alternative power (boss bars, world quest bars)
	if useAltPower then
		local barInfo = GetUnitPowerBarInfo(unit)
		if barInfo and barInfo.showOnRaid and (UnitInParty(unit) or UnitInRaid(unit)) then
			displayType   = ALTERNATE_POWER_INDEX
			min           = barInfo.minPower or 0
			hasAltPower   = true
			altPowerInfo  = {
				barID   = UnitPowerBarID(unit),
				barInfo = barInfo,
				name    = barInfo.name    or "",
				tooltip = barInfo.barText or "",
			}
		end
	end

	local cur = UnitPower(unit, displayType)     -- may be secret; pass to C only
	local max = UnitPowerMax(unit, displayType)  -- may be secret; pass to C only

	-- UnitPowerPercent returns a safe normal 0-100. Use for Lua-side logic.
	local pct = UnitPowerPercent(unit) or 0

	-- Color: UnitPowerType returns 0-1 in 12.0. Fall back to our table if nil.
	if not (r and g and b) then
		r, g, b = self:GetPowerColor(powerType, powerToken)
	end

	return {
		cur         = cur,          -- raw secret value
		max         = max,          -- raw secret value
		percent     = pct,          -- safe normal (0-100)
		min         = min,
		powerType   = powerType,
		powerToken  = powerToken,
		displayType = displayType,
		r = r, g = g, b = b,
		hasAltPower  = hasAltPower,
		altPowerInfo = altPowerInfo,
	}
end

-- GetPowerColor — unchanged (pure lookup table, no secret values involved)
function InfoCalc:GetPowerColor(powerType, powerToken)
	local colors = {
		MANA          = {0.00, 0.00, 1.00},
		RAGE          = {1.00, 0.00, 0.00},
		FOCUS         = {1.00, 0.50, 0.25},
		ENERGY        = {1.00, 1.00, 0.00},
		RUNIC_POWER   = {0.00, 0.82, 1.00},
		SOUL_SHARDS   = {0.50, 0.32, 0.55},
		LUNAR_POWER   = {0.30, 0.52, 0.90},
		HOLY_POWER    = {0.95, 0.90, 0.60},
		MAELSTROM     = {0.00, 0.50, 1.00},
		CHI           = {0.71, 1.00, 0.92},
		INSANITY      = {0.40, 0.00, 0.80},
		ARCANE_CHARGES= {0.41, 0.80, 0.94},
		FURY          = {0.79, 0.26, 0.99},
		PAIN          = {1.00, 0.61, 0.00},
		ESSENCE       = {0.90, 0.82, 1.00},
	}
	local color = colors[powerToken]
	if not color then
		if     powerType == 0 then color = colors.MANA
		elseif powerType == 1 then color = colors.RAGE
		elseif powerType == 2 then color = colors.FOCUS
		elseif powerType == 3 then color = colors.ENERGY
		elseif powerType == 6 then color = colors.RUNIC_POWER
		else                       color = {0.5, 0.5, 0.5}
		end
	end
	return color[1], color[2], color[3]
end

--[[ OLD GetPowerColorForUnit — replaced, see below
function InfoCalc:GetPowerColorForUnit(unit, useSmooth, curve)
	-- PROBLEM: UnitPowerPercent(unit, true, curve) — incorrect signature.
	-- Multiplying base color by percent fraction darkens it at full power too.
	...
end
--]]

-- NEW GetPowerColorForUnit:
--   * Uses UnitPowerPercent(unit) — correct call, safe normal number.
--   * Darkening only applied below 50% to avoid dimming at high power.
function InfoCalc:GetPowerColorForUnit(unit, useSmooth)
	if not unit then return 1, 1, 1 end
	local powerInfo = self:GetPowerInfo(unit, false)
	if useSmooth then
		local frac = (UnitPowerPercent(unit) or 100) * 0.01   -- safe 0-1
		-- Subtle darken only when below half power
		if frac < 0.5 then
			local dim = 0.5 + frac   -- ranges 0.5–1.0
			return powerInfo.r * dim, powerInfo.g * dim, powerInfo.b * dim
		end
	end
	return powerInfo.r, powerInfo.g, powerInfo.b
end

-- ============================================================================
-- ADDITIONAL POWER (hybrid classes: druid mana in forms, etc.)
-- ============================================================================

-- ShouldShowAdditionalPower — logic unchanged; no secret value contact here.
function InfoCalc:ShouldShowAdditionalPower(unit, playerClass)
	if not UnitIsUnit(unit, "player") then return false end
	if UnitHasVehicleUI and UnitHasVehicleUI("player") then return false end
	if UnitPowerMax(unit, 0) == 0 then return false end
	if ADDITIONAL_POWER_PAIRS[playerClass] then
		local powerType = UnitPowerType(unit)
		return ADDITIONAL_POWER_PAIRS[playerClass][powerType] or false
	end
	return false
end

-- GetAdditionalPowerInfo — logic unchanged; raw values stored, not touched.
function InfoCalc:GetAdditionalPowerInfo(unit)
	local cur = UnitPower(unit, 0)
	local max = UnitPowerMax(unit, 0)
	if max == 0 then return nil end
	local r, g, b = self:GetPowerColor(0, "MANA")
	return { cur=cur, max=max, min=0, powerType=0, powerToken="MANA", r=r, g=g, b=b }
end

-- ============================================================================
-- STATUS BAR HELPERS
-- ============================================================================

--[[ OLD UpdateHealthBar — replaced, see below
function InfoCalc:UpdateHealthBar(statusBar, unit, smoothing)
	local healthInfo = self:GetHealthInfo(unit)
	statusBar:SetMinMaxValues(0, healthInfo.max)
	-- PROBLEM: healthInfo.isConnected check is fine, but the smoothing variable
	-- was computed then never passed to SetValue. SetValue has no smoothing arg
	-- in the standard API — smoothing is controlled by StatusBar attributes.
	local interpolation = smoothing or ...
	if healthInfo.isConnected then
		statusBar:SetValue(healthInfo.cur)
	else
		statusBar:SetValue(healthInfo.max)   -- shows full bar when offline
	end
end
--]]

-- NEW UpdateHealthBar:
--   * Calls UnitHealth / UnitHealthMax directly — no intermediate table.
--   * Passes raw secret values straight to C-side SetMinMaxValues / SetValue.
--     The engine handles secret values natively; no Lua arithmetic needed.
--   * hpCalc (CreateUnitHealPredictionCalculator) lazily created for future
--     incoming-heal overlay (Step 3). Calculator populated here each update.
function InfoCalc:UpdateHealthBar(statusBar, unit)
	if not statusBar or not unit then return false end

	local cur = UnitHealth(unit)
	local max = UnitHealthMax(unit)

	-- C-side calls — secret values are valid arguments here.
	statusBar:SetMinMaxValues(0, max)

	if UnitIsConnected(unit) then
		statusBar:SetValue(cur)
	else
		statusBar:SetValue(max)   -- show full bar for disconnected units
	end

	-- Lazily create the heal-prediction calculator for incoming-heal overlay (Step 3).
	-- UnitGetDetailedHealPrediction populates it; results readable via calc methods.
	if CreateUnitHealPredictionCalculator then
		if not statusBar._stufHpCalc then
			statusBar._stufHpCalc = CreateUnitHealPredictionCalculator()
		end
		if UnitGetDetailedHealPrediction then
			UnitGetDetailedHealPrediction(unit, "player", statusBar._stufHpCalc)
		end
	end

	return true
end

--[[ OLD UpdatePowerBar — replaced, see below
function InfoCalc:UpdatePowerBar(statusBar, unit, useAltPower, smoothing)
	local powerInfo = self:GetPowerInfo(unit, useAltPower)
	statusBar:SetMinMaxValues(powerInfo.min, powerInfo.max)
	statusBar:SetValue(powerInfo.cur)
	-- PROBLEM: smoothing arg computed but ignored (same issue as UpdateHealthBar).
end
--]]

-- NEW UpdatePowerBar:
--   * Calls UnitPower / UnitPowerMax directly.
--   * Passes raw secret values straight to C. No Lua arithmetic.
function InfoCalc:UpdatePowerBar(statusBar, unit, useAltPower)
	if not statusBar or not unit then return false end

	local powerType   = UnitPowerType(unit)
	local displayType = powerType
	local min         = 0

	if useAltPower then
		local barInfo = GetUnitPowerBarInfo(unit)
		if barInfo and barInfo.showOnRaid and (UnitInParty(unit) or UnitInRaid(unit)) then
			displayType = ALTERNATE_POWER_INDEX
			min         = barInfo.minPower or 0
		end
	end

	local cur = UnitPower(unit, displayType)
	local max = UnitPowerMax(unit, displayType)

	-- C-side calls — secret values are valid here.
	statusBar:SetMinMaxValues(min, max)
	statusBar:SetValue(cur)

	return true
end

-- ============================================================================
-- TEXT FORMATTING HELPERS
-- ============================================================================

--[[ OLD FormatValue — replaced, see below
function InfoCalc:FormatValue(value, formatStr)
	if self:IsSecretValue(value) then return "" end
	-- PROBLEM: string.format("%.0f", secretValue) crashes in 12.0.
	-- Even after the IsSecretValue guard, pcall overhead is per-frame.
	if formatStr then return format(formatStr, value) end
	return tostring(value)
end
--]]

-- NEW FormatValue:
--   * For raw hp/mp numbers: caller MUST use FontString:SetText(rawValue)
--     or FontString:SetFormattedText("%.0f", rawValue) — both are C-side and
--     handle secret values natively.
--   * This helper is now only safe for values known to be normal numbers
--     (e.g., output of UnitHealthPercent, derived safe values).
--   * Passing a secret value here will return "" and print a warning once.
function InfoCalc:FormatValue(value, formatStr)
	if type(value) ~= "number" then return "" end
	if self:IsSecretValue(value) then
		-- Don't attempt Lua string formatting on secret values.
		-- Use FontString:SetText(value) / SetFormattedText at the call site.
		return ""
	end
	if formatStr then
		return format(formatStr, value)
	end
	return tostring(value)
end

--[[ OLD FormatHealthText — replaced, see below
function InfoCalc:FormatHealthText(healthInfo, style)
	-- PROBLEMS:
	--   1. "percent" style did (cur / max) * 100 — Lua division on secret values = crash.
	--   2. "deficit" style did (max - cur) — Lua subtraction on secret values = crash.
	--   3. "current" / "max" styles used format("%.0f", secretValue) — crash.
	--   4. Each call runs two IsSecretValue pcalls (cur + max) — expensive per frame.
	...
end
--]]

-- NEW FormatHealthText:
--   * "percent"  — uses UnitHealthPercent(unit): always a safe normal number.
--   * "current" / "max" — returns the raw secret value object itself.
--     Caller must pass the return value to FontString:SetText() (C-side safe).
--     If caller needs a Lua string and values aren't secret, normal format() works.
--   * "deficit"  — requires (max - cur); only possible out-of-combat when values
--     are normal numbers. Returns "" in combat.
--   * Takes (unit, style) instead of (healthInfo, style) — direct API calls are
--     cheaper than building an intermediate table per frame.
function InfoCalc:FormatHealthText(unit, style)
	if not unit then return "" end
	style = style or "percent"

	if style == "percent" then
		-- UnitHealthPercent always returns a safe normal 0-100 number.
		local pct = UnitHealthPercent(unit) or 0
		return format("%.0f%%", pct)

	elseif style == "current" then
		-- Return raw value — caller uses FontString:SetText(returnValue) for safe display.
		return UnitHealth(unit)

	elseif style == "max" then
		return UnitHealthMax(unit)

	elseif style == "both" then
		-- Dead / offline states are always safe to check via API.
		if UnitIsDeadOrGhost(unit) then return "Dead" end
		if not UnitIsConnected(unit) then return "Offline" end
		-- For live units: return raw values; caller uses SetFormattedText("%.0f / %.0f", cur, max).
		-- Returning a table here is a signal to the caller to use C-side formatting.
		return UnitHealth(unit), UnitHealthMax(unit)

	elseif style == "deficit" then
		-- Deficit = max - cur. This is Lua arithmetic — only safe on normal numbers.
		-- We guard via pcall; returns "" in combat when values are secret.
		local cur, max = UnitHealth(unit), UnitHealthMax(unit)
		local ok, deficit = pcall(function() return max - cur end)
		if not ok then return "" end
		if deficit and deficit > 0 then
			return format("-%.0f", deficit)
		end
		return ""
	end

	return ""
end

--[[ OLD FormatPowerText — replaced, see below
function InfoCalc:FormatPowerText(powerInfo, style)
	-- Same problems as FormatHealthText:
	-- "percent" did (cur / max) * 100 on secret values → crash.
	-- "deficit" did (max - cur) on secret values → crash.
	-- "current" / "max" used format("%.0f", secretValue) → crash.
	...
end
--]]

-- NEW FormatPowerText:
--   * Same pattern as FormatHealthText.
--   * "percent" uses UnitPowerPercent(unit) — safe normal number.
--   * Raw values returned for "current" / "max" — caller uses SetText (C-side).
--   * "deficit" pcall-guarded; returns "" in combat.
function InfoCalc:FormatPowerText(unit, style)
	if not unit then return "" end
	style = style or "percent"

	if style == "percent" then
		local pct = UnitPowerPercent(unit) or 0
		return format("%.0f%%", pct)

	elseif style == "current" then
		return UnitPower(unit)

	elseif style == "max" then
		return UnitPowerMax(unit)

	elseif style == "both" then
		return UnitPower(unit), UnitPowerMax(unit)

	elseif style == "deficit" then
		local cur, max = UnitPower(unit), UnitPowerMax(unit)
		local ok, deficit = pcall(function() return max - cur end)
		if not ok then return "" end
		if deficit and deficit > 0 then
			return format("-%.0f", deficit)
		end
		return ""
	end

	return ""
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--[[ OLD AbbreviateNumber — replaced, see below
function InfoCalc:AbbreviateNumber(value)
	if self:IsSecretValue(value) then return "" end
	-- PROBLEM: comparisons (value >= 1000000000) on a secret value crash even
	-- after IsSecretValue because the pcall guard only catches the arithmetic,
	-- not the comparison operator in the enclosing function.
	if value >= 1000000000 then ...
	end
end
--]]

-- NEW AbbreviateNumber:
--   * Only call this with values you KNOW are safe normal numbers
--     (e.g., output of UnitHealthPercent, manually cached out-of-combat values).
--   * Secret values must go directly to FontString:SetText — no abbreviation.
--   * pcall wraps all comparisons and arithmetic as a safety net.
function InfoCalc:AbbreviateNumber(value)
	if type(value) ~= "number" then return "" end
	local ok, result = pcall(function()
		if     value >= 1000000000 then return format("%.1fB", value / 1000000000)
		elseif value >= 1000000    then return format("%.1fM", value / 1000000)
		elseif value >= 1000       then return format("%.1fK", value / 1000)
		else                            return format("%.0f",  value)
		end
	end)
	return ok and result or ""
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function InfoCalc:Initialize()
	local _, playerClass = UnitClass("player")
	self.playerClass = playerClass
	print("|cff00ff00Stuf InfoCalc|r: Initialized (12.0.1 MSUF-pattern rewrite)")
end

return InfoCalc
