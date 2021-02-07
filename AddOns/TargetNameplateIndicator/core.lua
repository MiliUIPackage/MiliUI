------------------------------------------------------
-- Configuration variables have moved to config.lua --
--        Do not change anything in this file       --
------------------------------------------------------

-- List globals here for Mikk's FindGlobals script
-- GLOBALS: LibStub, UnitIsUnit, UnitGUID, UnitIsFriend, UnitExists, CreateFrame, Mixin, print, pairs, error

local addon, TNI = ...

local LNR = LibStub("LibNameplateRegistry-1.0")

LibStub("AceAddon-3.0"):NewAddon(TNI, addon, "AceConsole-3.0")


--[===[@debug@
local DEBUG = false

local function debugprint(...)
	if DEBUG then
		print("TNI DEBUG:", ...)
	end
end
--@end-debug@]===]

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
			}
		}
	}
end

function TNI:OnInitialize()
	LNR:Embed(self)
	self.db = LibStub("AceDB-3.0"):New("TargetNameplateIndicatorDB", defaults, true)
	self:RegisterOptions() -- Defined in options.lua

	self:LNR_RegisterCallback("LNR_ERROR_FATAL_INCOMPATIBILITY", "OnError_FatalIncompatibility")

	--[===[@debug@
	if DEBUG then
		TNI:LNR_RegisterCallback("LNR_DEBUG", debugprint)
	end
	--@end-debug@]===]
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
TNI.Indicators = {}

local Indicator = {}

function Indicator:Update(nameplate)
	self.currentNameplate = nameplate
	self.Texture:ClearAllPoints()

	local unitConfig = TNI.db.profile[self.unit]
	-- 暫時修正
	if not unitConfig then return end
	local config = UnitIsUnit("player", self.unit) and unitConfig.self or UnitIsFriend("player", self.unit) and unitConfig.friendly or unitConfig.hostile

	self:SetShown(unitConfig.enable)

	if nameplate and config.enable then
		self.Texture:Show()
		self.Texture:SetTexture(config.texture)
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
	--[===[@debug@
	debugprint("Callback fired (recycle)", self.unit, nameplate == self.currentNameplate)
	--@end-debug@]===]

	if nameplate == self.currentNameplate then
		self:Update()
	end
end

-- Are other indicators already displaying on this indicator's unit?
function Indicator:AreOtherIndicatorsDisplayed()
	for unit, indicator in pairs(TNI.Indicators) do
		if self.unit ~= indicator.unit and UnitIsUnit(self.unit, unit) then -- If the indicator is for a different unit token but it's the same unit, return true
			return true
		end
	end

	return false
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

local function CreateIndicator(unit)
	-- 暫時加上 UIParent
	local indicator = CreateFrame("Frame", "TargetNameplateIndicator_" .. unit, UIParent)
	indicator:SetFrameStrata("BACKGROUND")
	indicator.Texture = indicator:CreateTexture("$parentTexture", "OVERLAY")

	indicator.unit = unit

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
-- Target Indicator
------

local TargetIndicator = CreateIndicator("target")

function TargetIndicator:PLAYER_TARGET_CHANGED()
	local nameplate, plateData = self:GetPlateByGUID(UnitGUID("target"))

	--[===[@debug@
	debugprint("Player target changed", nameplate)
	--@end-debug@]===]

	if not nameplate then
		self:Update()
	end
end

function TargetIndicator:OnTargetPlateOnScreen(callback, nameplate, plateData)
	--[===[@debug@
	debugprint("Callback fired (target found)")
	--@end-debug@]===]

	self:Update(nameplate)
end

TargetIndicator:RegisterEvent("PLAYER_TARGET_CHANGED")
TargetIndicator:LNR_RegisterCallback("LNR_ON_TARGET_PLATE_ON_SCREEN", "OnTargetPlateOnScreen")

------
-- Mouseover Indicator
------

local MouseoverIndicator = CreateIndicator("mouseover")

function MouseoverIndicator:OnUpdate()
	-- If there's a current nameplate and it's still the mouseover unit, do nothing
	if self.currentNameplate and self:VerifyNameplateUnitToken() and UnitIsUnit("mouseover", self.currentNameplate.namePlateUnitToken) then return end

	-- If there isn't a current nameplate and there's no mouseover unit, do nothing
	if not self.currentNameplate and not UnitExists("mouseover") then return end

	local nameplate, plateData = self:GetPlateByGUID(UnitGUID("mouseover"))

	local areOtherIndicatorsDisplayed = self:AreOtherIndicatorsDisplayed()

	--[===[@debug@
	debugprint("Player mouseover changed", nameplate, "areOtherIndicatorsDisplayed?", areOtherIndicatorsDisplayed)
	--@end-debug@]===]

	-- If the player has their mouse over a unit that doesn't already have an indicator displaying on it, update the mouseover indicator; otherwise hide it
	if not areOtherIndicatorsDisplayed then
		self:Update(nameplate)
	else
		self:Update(nil)
	end
end

MouseoverIndicator:SetScript("OnUpdate", MouseoverIndicator.OnUpdate)


------
-- Focus Indicator
------

local FocusIndicator = CreateIndicator("focus")

function FocusIndicator:OnUpdate()
	-- If there's a current nameplate and it's still the focus unit, do nothing
	if self.currentNameplate and self:VerifyNameplateUnitToken() and UnitIsUnit("focus", self.currentNameplate.namePlateUnitToken) then return end

	-- If there isn't a current nameplate and there's no focus unit, do nothing
	if not self.currentNameplate and not UnitExists("focus") then return end

	local nameplate, plateData = self:GetPlateByGUID(UnitGUID("focus"))

	local areOtherIndicatorsDisplayed = self:AreOtherIndicatorsDisplayed()

	--[===[@debug@
	debugprint("Player focus changed", nameplate, "areOtherIndicatorsDisplayed?", areOtherIndicatorsDisplayed)
	--@end-debug@]===]

	-- If the player has their focus set to a unit that doesn't already have an indicator displaying on it, update the focus indicator; otherwise hide it
	if not areOtherIndicatorsDisplayed then
		self:Update(nameplate)
	else
		self:Update(nil)
	end
end

FocusIndicator:SetScript("OnUpdate", FocusIndicator.OnUpdate)
