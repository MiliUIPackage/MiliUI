---@class addonTablePlatynator
local addonTable = select(2, ...)

local curve = addonTable.Display.Utilities.Get01HiddenCurve()

addonTable.Display.HealthTextMixin = {}

local significantFiguresCaches = {}

function addonTable.Display.HealthTextMixin:PostInit()
  if self.details.significantFigures > 0 then
    if not significantFiguresCaches[self.details.significantFigures] then
      local breakpoints = {
        {breakpoint = 100, fractionDivisor = 10^(self.details.significantFigures - 3), significandDivisor = 1/10^(self.details.significantFigures - 3), abbreviation = "", abbreviationIsGlobal = false},
        {breakpoint = 10, fractionDivisor = 10^(self.details.significantFigures - 2), significandDivisor = 1/10^(self.details.significantFigures - 2), abbreviation = "", abbreviationIsGlobal = false},
        {breakpoint = 1/1000000000000000, fractionDivisor = 10^(self.details.significantFigures - 1), significandDivisor = 1/10^(self.details.significantFigures - 1), abbreviation = "", abbreviationIsGlobal = false},
      }
      significantFiguresCaches[self.details.significantFigures] = {config = CreateAbbreviateConfig(breakpoints)}
    end
    self.abbreviateData = significantFiguresCaches[self.details.significantFigures]
  end

  if self.details.showPercentSymbol then
    self.percentTail = "%"
  else
    self.percentTail = ""
  end
  self.formatMultiple = self.details.formatMultiple
  self.hideAuto = self.details.hideWhen01
end

function addonTable.Display.HealthTextMixin:SetUnit(unit)
  self.unit = unit
  if self.unit then
    self:UpdateText(addonTable.Cache:Get(self.unit, "health"))
    addonTable.Cache:RegisterCallback(self.unit, "health", function(state)
      self:UpdateText(state)
    end)
  else
    self:UnregisterAllEvents()
  end
end

function addonTable.Display.HealthTextMixin:Strip()
  self:UnregisterAllEvents()
  self.abbreviateData = nil
  self.abbreviateCallback = nil
  self.percentTail = nil
  self.formatMultiple = nil
  self.PostInit = nil
  self.text:SetAlpha(1)
end

function addonTable.Display.HealthTextMixin:UpdateText(state)
  if UnitIsDeadOrGhost(self.unit) then
    self.text:SetText("0")
    if self.hideAuto then
      self.text:SetAlpha(0)
    end
  else
    local values = {
      percentage = "",
      absolute = AbbreviateNumbers(state.absolute),
    }
    local types = self.details.displayTypes
    local value = state.percent
    if self.abbreviateData then
      values.percentage = AbbreviateNumbers(value, self.abbreviateData) .. self.percentTail
    else
      values.percentage = C_StringUtil.RoundToNearestString(value) .. self.percentTail
    end
    if #types == 2 then
      self.text:SetFormattedText(self.formatMultiple, values[types[1]], values[types[2]])
    elseif #types == 1 then
      self.text:SetFormattedText("%s", values[types[1]])
    end

    if self.hideAuto then
      self.text:SetAlpha(state.markerAlpha)
    end
  end
end
