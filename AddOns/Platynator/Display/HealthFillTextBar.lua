---@class addonTablePlatynator
local addonTable = select(2, ...)

addonTable.Display.HealthFillTextBarMixin = {}

function addonTable.Display.HealthFillTextBarMixin:PostInit()
  if self.details.background.applyColor then -- Apply tint to colours
    self.modColors = addonTable.Display.Utilities.TintAutoColors(self.details.autoColors, self.details.background.color)
  end

  self.animate = self.details.animate and Enum.StatusBarInterpolation.ExponentialEaseOut or Enum.StatusBarInterpolation.Immediate
end

function addonTable.Display.HealthFillTextBarMixin:SetUnit(unit)
  self.unit = unit
  if self.unit then
    self:RegisterUnitEvent("UNIT_NAME_UPDATE", self.unit)

    self:SaveName()
    self:SetText(self.defaultText)

    -- Disable animation for initial setup
    local animate = self.animate
    self.animate = nil
    self:UpdateHealth(addonTable.Cache:Get(self.unit, "health"))
    addonTable.Cache:RegisterCallback(self.unit, "health", function(state)
      self:UpdateHealth(state)
    end)
    self.animate = animate

    if self.details.showWhenWowDoes then
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

function addonTable.Display.HealthFillTextBarMixin:UpdateHealth(state)
  self.statusBar:SetMinMaxValues(0, state.maxWithAbsorbs)

  self.statusBarAbsorb:SetMinMaxValues(0, state.maxWithAbsorbs)

  self.statusBarAbsorb:SetValue(state.absorbs, self.animate)
  self.statusBar:SetValue(state.absolute, self.animate)
end

function addonTable.Display.HealthFillTextBarMixin:OnEvent(eventName)
  if eventName == "UNIT_HEALTH" then
    if self.details.showWhenWowDoes then
      self:SetShown(UnitShouldDisplayName(self.unit))
    end
  elseif eventName == "UNIT_NAME_UPDATE" then
    self:SaveName()
    self:SetText(self.defaultText)
  end

  self:ColorEventHandler(eventName)
end

function addonTable.Display.HealthFillTextBarMixin:SaveName()
  if UnitIsPlayer(self.unit) and RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled() then
    local part1, part2 = UnitName(self.unit)
    self.defaultText = part1 and part2 and part1 .. Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR .. part2 or part1
  else
    self.defaultText = UnitName(self.unit)
  end
end

function addonTable.Display.HealthFillTextBarMixin:ApplyTextOverride()
  local override = addonTable.API.TextOverrides.name[self.unit]
  self:SetText(override or self.defaultText)
end
