------------------------------------------------------------
-- Configuration variables have moved to the in-game menu --
--           Do not change anything in this file          --
------------------------------------------------------------

local addon, TNI = ...

local LNR = LibStub("LibNameplateRegistry-1.0")

LibStub("AceAddon-3.0"):NewAddon(TNI, addon, "AceConsole-3.0")

--[=[@alpha@
local DEBUG = false

local function debugprint(...)
	if DEBUG then
		print("TNI DEBUG:", ...)
	end
end

_G.TNI = TNI
--@end-alpha@]=]


-----
-- Error callbacks
-----
local print, format = print, string.format

local function errorPrint(fatal, formatString, ...)
	local message = "|cffFF0000LibNameplateRegistry has encountered a" .. (fatal and " fatal" or "n") .. " error:|r"
	print("TargetNameplateIndicator:", message, format(formatString, ...))
end

function TNI:OnError_FatalIncompatibility(callback, incompatibilityType)
	local detailedMessage
	if incompatibilityType == "TRACKING: OnHide" or incompatibilityType == "TRACKING: OnShow" then
		detailedMessage = "LibNameplateRegistry missed several nameplate show and hide events."
	elseif incompatibilityType == "TRACKING: OnShow missed" then
		detailedMessage = "A nameplate was hidden but never shown."
	else
		detailedMessage = "Something has gone terribly wrong!"
	end

	errorPrint(true, "(Error Code: %s) %s", incompatibilityType, detailedMessage)
end

------
-- Initialisation
------

local defaults

do
	local function CreateUnitReactionTypeDefaults()
		return {
			enable = true,
			texture = "Interface\\AddOns\\TargetNameplateIndicator\\Textures\\Reticule",
			height = 70,
			width = 70,
			frameStrata = "BACKGROUND",
			opacity = 1,
			texturePoint = "BOTTOM",
			anchorPoint = "TOP",
			xOffset = 0,
			yOffset = 5,
		}
	end

	local function CreateUnitDefaults()
		return {
			enable = true,
			self = CreateUnitReactionTypeDefaults(),
			friendly = CreateUnitReactionTypeDefaults(),
			hostile = CreateUnitReactionTypeDefaults(),
		}
	end

	defaults = {
		profile = {
			target = {
				enable = true,
				self = {
					enable = true,
					texture = "Interface\\AddOns\\TargetNameplateIndicator\\Textures\\NeonWhiteArrow",
					height = 70,
					width = 70,
					opacity = 1,
					texturePoint = "BOTTOM",
					anchorPoint = "TOP",
					xOffset = 0,
					yOffset = -5,
				},
				friendly = {
					enable = true,
					texture = "Interface\\AddOns\\TargetNameplateIndicator\\Textures\\NeonGreenArrow",
					height = 70,
					width = 70,
					opacity = 1,
					texturePoint = "BOTTOM",
					anchorPoint = "TOP",
					xOffset = 0,
					yOffset = -5,
				},
				hostile = {
					enable = true,
					texture = "Interface\\AddOns\\TargetNameplateIndicator\\Textures\\NeonRedArrow",
					height = 70,
					width = 70,
					opacity = 1,
					texturePoint = "BOTTOM",
					anchorPoint = "TOP",
					xOffset = 0,
					yOffset = 22,
				}
			},
			mouseover = {
				enable = true,
				self = {
					enable = true,
					texture = "Interface\\AddOns\\TargetNameplateIndicator\\Textures\\whitearrow1",
					height = 70,
					width = 70,
					opacity = 1,
					texturePoint = "BOTTOM",
					anchorPoint = "TOP",
					xOffset = 0,
					yOffset = -10,
				},
				friendly = {
					enable = true,
					texture = "Interface\\AddOns\\TargetNameplateIndicator\\Textures\\greenarrow1",
					height = 70,
					width = 70,
					opacity = 1,
					texturePoint = "BOTTOM",
					anchorPoint = "TOP",
					xOffset = 0,
					yOffset = -10,
				},
				hostile = {
					enable = true,
					texture = "Interface\\AddOns\\TargetNameplateIndicator\\Textures\\redarrow1",
					height = 70,
					width = 70,
					opacity = 1,
					texturePoint = "BOTTOM",
					anchorPoint = "TOP",
					xOffset = 0,
					yOffset = 5,
				}
			},
			focus = {
				enable = true,
				self = {
					enable = true,
					texture = "Interface\\AddOns\\TargetNameplateIndicator\\Textures\\Q_WhiteTarget",
					height = 70,
					width = 70,
					opacity = 1,
					texturePoint = "BOTTOM",
					anchorPoint = "TOP",
					xOffset = 0,
					yOffset = -10,
				},
				friendly = {
					enable = true,
					texture = "Interface\\AddOns\\TargetNameplateIndicator\\Textures\\Q_GreenTarget",
					height = 70,
					width = 70,
					opacity = 1,
					texturePoint = "BOTTOM",
					anchorPoint = "TOP",
					xOffset = 0,
					yOffset = -12,
				},
				hostile = {
					enable = true,
					texture = "Interface\\AddOns\\TargetNameplateIndicator\\Textures\\Q_RedTarget",
					height = 70,
					width = 70,
					opacity = 1,
					texturePoint = "BOTTOM",
					anchorPoint = "TOP",
					xOffset = 0,
					yOffset = 16,
				}
			},
			targettarget = {
				enable = true,
				self = {
					enable = true,
					texture = "Interface\\AddOns\\TargetNameplateIndicator\\Textures\\whitearrow1",
					height = 70,
					width = 70,
					opacity = 1,
					texturePoint = "BOTTOM",
					anchorPoint = "TOP",
					xOffset = 0,
					yOffset = -10,
				},
				friendly = {
					enable = true,
					texture = "Interface\\AddOns\\TargetNameplateIndicator\\Textures\\bluearrow1",
					height = 70,
					width = 70,
					opacity = 1,
					texturePoint = "BOTTOM",
					anchorPoint = "TOP",
					xOffset = 0,
					yOffset = -10,
				},
				hostile = {
					enable = true,
					texture = "Interface\\AddOns\\TargetNameplateIndicator\\Textures\\PurpleArrow",
					height = 70,
					width = 70,
					opacity = 1,
					texturePoint = "BOTTOM",
					anchorPoint = "TOP",
					xOffset = 0,
					yOffset = 5,
				}
			}
		}
	}
end

function TNI:OnInitialize()
	LNR:Embed(self)
	self.db = LibStub("AceDB-3.0"):New("TargetNameplateIndicatorDB", defaults, true)
	self:RegisterOptions() -- Defined in options.lua

	self:LNR_RegisterCallback("LNR_ERROR_FATAL_INCOMPATIBILITY", "OnError_FatalIncompatibility")

	--[=[@alpha@
	if DEBUG then
		TNI:LNR_RegisterCallback("LNR_DEBUG", debugprint)
	end
	--@end-alpha@]=]
end

function TNI:OnEnable()
	for unit, indicator in pairs(self.Indicators) do
		indicator:Show()
	end
end

function TNI:OnDisable()
	for unit, indicator in pairs(self.Indicators) do
		indicator:Hide()
	end
end

function TNI:RefreshIndicator(unit)
	local indicator = self.Indicators[unit]

	if not indicator then
		error("Invalid unit \"" + unit + "\"")
	end

	indicator:Refresh()
end

------
-- Indicator functions
------

--- @type table<string, Indicator>
TNI.Indicators = {}

--- @class Indicator : Frame
--- @field Texture Texture
--- @field enabled boolean
--- @field unit string
--- @field priority number
--- @field LNR_RegisterCallback fun(self: Indicator, eventName: string, callbackName: string)
--- @field GetPlateByGUID fun(string) : Frame, table
local Indicator = {}

function Indicator:Update(nameplate)
	self.currentNameplate = nameplate
	self.Texture:ClearAllPoints()

	local unitConfig = TNI.db.profile[self.unit]
	if not unitConfig then return end -- 暫時修正
	local config = UnitIsUnit("player", self.unit) and unitConfig.self or
		UnitIsFriend("player", self.unit) and unitConfig.friendly or unitConfig.hostile

	self:SetShown(unitConfig.enable)
	self.enabled = unitConfig.enable;

	if nameplate and config.enable then
		local texture = config.texture
		if texture == "custom" then
			texture = config.textureCustom
		end

		self:SetFrameStrata(config.frameStrata or "BACKGROUND") -- 暫時修正
		self.Texture:Show()
		self.Texture:SetTexture(texture)
		self.Texture:SetSize(config.width, config.height)
		self.Texture:SetAlpha(config.opacity)
		self.Texture:SetPoint(config.texturePoint, nameplate, config.anchorPoint, config.xOffset, config.yOffset)
	else
		self.Texture:Hide()
	end
end

function Indicator:Refresh()
	self:Update(self.currentNameplate)
end

function Indicator:OnRecyclePlate(callback, nameplate, plateData)
	--[=[@alpha@
	debugprint("Callback fired (recycle)", self.unit, nameplate == self.currentNameplate)
	--@end-alpha@]=]

	if nameplate == self.currentNameplate then
		self:Update()
	end
end

-- Checks if other indicators are already displaying on this indicator's unit, hides lower priority indicators and returns true when this indicator should be shown.
--
-- - If no other indicator is displaying, this returns true.
-- - If a lower priority indicator is displaying, it is hidden and this returns true.
-- - If an equal or higher priority indicator is displaying, this returns false.
function Indicator:CheckAndHideLowerPriorityIndicators()
	for unit, indicator in pairs(TNI.Indicators) do
		if indicator.enabled and self.unit ~= indicator.unit and UnitIsUnit(self.unit, unit) then -- If the indicator is for a different unit token but it's the same unit,
			if self.priority > indicator.priority then                                      -- If this indicator is a higher priority, hide the other indicator and return true
				indicator:Update()
				return true
			else -- If this indicator is a lower or equal priority, return false
				return false
			end
		end
	end

	-- No other indicator is displaying, return true
	return true
end

-- Verfies that the current nameplate (if there is one) has a unit token and disables the indicator and throws an error if it doesn't.
-- Returns true if there's no issue.
function Indicator:VerifyNameplateUnitToken()
	if self.currentNameplate and not self.currentNameplate.namePlateUnitToken then
		TNI.db.profile[self.unit].enable = false
		self:Hide()

		error((
			"TargetNameplateIndicator: %s indicator found a nameplate without a unit token and as such is unable to function." ..
			" This is usually caused by AddOns that replace the default nameplates (e.g. EKPlates)." ..
			" This indicator will now be disabled until it's re-enabled in the options menu."
		):format(self.unit))
	end

	return true
end

local function CreateIndicator(unit, priority)
	local indicator = CreateFrame("Frame", "TargetNameplateIndicator_" .. unit)
	--- @cast indicator Indicator

	indicator:SetFrameStrata("BACKGROUND")
	indicator.Texture = indicator:CreateTexture("$parentTexture", "OVERLAY")

	indicator.unit = unit
	indicator.priority = priority

	LNR:Embed(indicator)
	Mixin(indicator, Indicator)

	indicator:LNR_RegisterCallback("LNR_ON_RECYCLE_PLATE", "OnRecyclePlate")

	indicator:SetScript("OnEvent", function(self, event, ...)
		self[event](self, ...)
	end)

	TNI.Indicators[unit] = indicator

	return indicator
end


------
-- Non-target Indicator functions
------

--- @class NonTargetIndicator : Indicator
local NonTargetIndicator = {}

function NonTargetIndicator:OnUpdate()
	-- If there's a current nameplate and it's still this indicator's unit, do nothing
	if self.currentNameplate and self:VerifyNameplateUnitToken() and UnitIsUnit(self.unit, self.currentNameplate.namePlateUnitToken) then
		return
	end

	-- If there isn't a current nameplate and this indicator's unit doesn't exist, do nothing
	if not self.currentNameplate and not UnitExists(self.unit) then
		return
	end

	local nameplate, plateData = self:GetPlateByGUID(UnitGUID(self.unit))

	local shouldDisplay = self:CheckAndHideLowerPriorityIndicators()

	--[=[@alpha@
	debugprint(self.unit, "changed", nameplate, "shouldDisplay?", shouldDisplay)
	--@end-alpha@]=]

	-- If the nameplate for this indicator's unit doesn't already have a higher priority indicator displaying on it, update the indicator; otherwise hide it.
	if shouldDisplay then
		self:Update(nameplate)
	else
		self:Update(nil)
	end
end

local function CreateNonTargetIndicator(unit, priority)
	local indicator = CreateIndicator(unit, priority)
	--- @cast indicator NonTargetIndicator

	Mixin(indicator, NonTargetIndicator)

	indicator:SetScript("OnUpdate", indicator.OnUpdate)

	return indicator
end


------
-- Target Indicator
------

--- @class TargetIndicator : Indicator
local TargetIndicator = CreateIndicator("target", 100)

function TargetIndicator:PLAYER_TARGET_CHANGED()
	local nameplate, plateData = self:GetPlateByGUID(UnitGUID("target"))

	--[=[@alpha@
	debugprint("Player target changed", nameplate)
	--@end-alpha@]=]

	if not nameplate then
		self:Update()
	end
end

function TargetIndicator:OnTargetPlateOnScreen(callback, nameplate, plateData)
	--[=[@alpha@
	debugprint("Callback fired (target found)")
	--@end-alpha@]=]

	local shouldDisplay = self:CheckAndHideLowerPriorityIndicators()

	if shouldDisplay then
		self:Update(nameplate)
	else
		self:Update()
	end
end

TargetIndicator:RegisterEvent("PLAYER_TARGET_CHANGED")
TargetIndicator:LNR_RegisterCallback("LNR_ON_TARGET_PLATE_ON_SCREEN", "OnTargetPlateOnScreen")


------
-- Mouseover Indicator
------

---@diagnostic disable-next-line: unused-local
local MouseoverIndicator = CreateNonTargetIndicator("mouseover", 10)


------
-- Focus Indicator
------

---@diagnostic disable-next-line: unused-local
local FocusIndicator = CreateNonTargetIndicator("focus", 90)


------
-- Target of Target Indicator
------

---@diagnostic disable-next-line: unused-local
local TargetOfTargetIndicator = CreateNonTargetIndicator("targettarget", 50)
