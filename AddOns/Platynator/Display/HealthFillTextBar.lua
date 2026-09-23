---@class addonTablePlatynator
local addonTable = select(2, ...)

addonTable.Display.HealthFillTextBarMixin = {}

function addonTable.Display.HealthFillTextBarMixin:PostInit()
  if self.details.background.applyColor then -- Apply tint to colours
    self.modColors = addonTable.Display.Utilities.TintAutoColors(self.details.autoColors, self.details.background.color)
  end
  self.calculator = CreateUnitHealPredictionCalculator()
  self.calculator:SetMaximumHealthMode(Enum.UnitMaximumHealthMode.WithAbsorbs)
  self.calculator:SetDamageAbsorbClampMode(Enum.UnitDamageAbsorbClampMode.MaximumHealth)

  self.animate = self.details.animate and Enum.StatusBarInterpolation.ExponentialEaseOut or Enum.StatusBarInterpolation.Immediate
end

function addonTable.Display.HealthFillTextBarMixin:SetUnit(unit)
  self.unit = unit
  if self.unit then
    self:RegisterUnitEvent("UNIT_HEALTH", self.unit)
    self:RegisterUnitEvent("UNIT_MAXHEALTH", self.unit)
    self:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", self.unit)
    self:RegisterUnitEvent("UNIT_NAME_UPDATE", self.unit)

    self.defaultText = UnitName(self.unit)
    self:SetText(self.defaultText)

    -- Disable animation for initial setup
    local animate = self.animate
    self.animate = nil
    self:UpdateHealth()
    self.animate = animate

    if self.details.showWhenWowDoes then
      self:RegisterUnitEvent("UNIT_HEALTH", self.unit)
      self:SetShown(UnitShouldDisplayName(self.unit))
      addonTable.Cache:RegisterCallback(unit, "target", function()
        self:SetShown(UnitIsUnit(self.unit, "target") or UnitShouldDisplayName(self.unit))
      end)
    end

    addonTable.Display.RegisterForColorEvents(self, self.details.autoColors)
  else
    self:UnregisterAllEvents()
    addonTable.Display.UnregisterForColorEvents(self)
  end
end

function addonTable.Display.HealthFillTextBarMixin:SetText(text)
  self.foreground:SetText(text)
  self.background:SetText(text)
  self.absorb:SetText(text)
  self.absorbPlacer:SetText(text)
end

function addonTable.Display.HealthFillTextBarMixin:Strip()
  self:UnregisterAllEvents()
  addonTable.Display.UnregisterForColorEvents(self)
  self.modColors = nil
  self.animate = nil
  self.calculator = nil

end

function addonTable.Display.HealthFillTextBarMixin:SetColor(...)
  self.foreground:SetTextColor(...)
  if not self.details.absorb.applyColor then
    self.absorb:SetTextColor(...)
  end
  if self.details.background.applyColor then
    local mod = self.details.background.color
    if self.modColors then
      self.background:SetTextColor(addonTable.Display.GetColor(self.modColors, self.colorState, self.unit))
    else
      local r, g, b = ...
      self.background:SetTextColor(r, g, b, mod.a)
    end
  end
end

function addonTable.Display.HealthFillTextBarMixin:UpdateHealth()
  UnitGetDetailedHealPrediction(self.unit, nil, self.calculator)

  self.calculator:SetMaximumHealthMode(Enum.UnitMaximumHealthMode.WithAbsorbs)
  local maxHealth = self.calculator:GetMaximumHealth()
  self.statusBar:SetMinMaxValues(0, maxHealth)

  self.statusBarAbsorb:SetMinMaxValues(0, maxHealth)

  local absorbs = self.calculator:GetDamageAbsorbs()
  self.statusBarAbsorb:SetValue(absorbs, self.animate)
  self.calculator:SetMaximumHealthMode(Enum.UnitMaximumHealthMode.Default)
  local newHealth = self.calculator:GetCurrentHealth()
  self.statusBar:SetValue(newHealth, self.animate)
end

function addonTable.Display.HealthFillTextBarMixin:OnEvent(eventName)
  if eventName == "UNIT_HEALTH" then
    self:UpdateHealth()
    if self.details.showWhenWowDoes then
      self:SetShown(UnitShouldDisplayName(self.unit))
    end
  elseif eventName == "UNIT_MAXHEALTH" then
    self:UpdateHealth()
  elseif eventName == "UNIT_ABSORB_AMOUNT_CHANGED" then
    self:UpdateHealth()
  elseif eventName == "UNIT_NAME_UPDATE" then
    self.defaultText = UnitName(self.unit)
    self:SetText(self.defaultText)
  end

  self:ColorEventHandler(eventName)
end

function addonTable.Display.HealthFillTextBarMixin:ApplyTextOverride()
  local override = addonTable.API.TextOverrides.name[self.unit]
  self:SetText(override or self.defaultText)
end
