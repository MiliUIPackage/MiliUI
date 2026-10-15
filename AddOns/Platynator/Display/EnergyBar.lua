---@class addonTablePlatynator
local addonTable = select(2, ...)

addonTable.Display.EnergyBarMixin = {}

function addonTable.Display.EnergyBarMixin:PostInit()
  self.forceShow = true
  for _, value in pairs(self.details.mobTypes) do
    self.forceShow = self.forceShow and not value
  end
end

function addonTable.Display.EnergyBarMixin:SetUnit(unit)
  self.unit = unit
  if self.unit then
    if not self.forceShow and (UnitIsPlayer(unit) or UnitTreatAsPlayerForDisplay and UnitTreatAsPlayerForDisplay(unit)) then
      self:Hide()
      return
    end

    local numKind = UnitPowerType(self.unit)

    local isDelveRelevant = false
    local isDungeonOrRaidRelevant = false
    if not self.forceShow then
      isDelveRelevant = addonTable.Display.Utilities.IsInRelevantInstance({delve = true}) and self.details.mobTypes[addonTable.Display.Utilities.GetDelveType(self.unit)]
      isDungeonOrRaidRelevant = addonTable.Display.Utilities.IsInRelevantInstance({dungeon = true, raid = true}) and self.details.mobTypes[addonTable.Display.Utilities.GetEliteType(self.unit)]
    end

    if self.details.powerTypes[addonTable.Constants.PowerMap[numKind]] and (self.forceShow or isDelveRelevant or isDungeonOrRaidRelevant) then
      self.powerKind = numKind

      self:RegisterUnitEvent("UNIT_POWER_UPDATE", self.unit)
      self:RegisterUnitEvent("UNIT_MAXPOWER", self.unit)
      self:UpdateValue()

      if not self.forceShow then
        addonTable.CallbackRegistry:RegisterCallback("EncounterUpdate", function()
          self:SetShown(addonTable.Display.Utilities.ShouldShowEnergy())
        end, self)
        self:SetShown(addonTable.Display.Utilities.ShouldShowEnergy())
      end

      addonTable.Display.RegisterForColorEvents(self, self.details.autoColors)
    else
      self:Hide()
    end
  else
    self:StripInternal()
  end
end

function addonTable.Display.EnergyBarMixin:SetColor(...)
  self.statusBar:GetStatusBarTexture():SetVertexColor(...)
  if self.details.background.applyColor then
    local mod = self.details.background.color
    if self.modColors then
      self.background:SetVertexColor(addonTable.Display.GetColor(self.modColors, self.colorState, self.unit))
    else
      local r, g, b = ...
      self.background:SetVertexColor(r, g, b, mod.a)
    end
  end
  self.marker:SetVertexColor(...)
end

function addonTable.Display.EnergyBarMixin:StripInternal()
  self:UnregisterAllEvents()
  addonTable.Display.UnregisterForColorEvents(self)
  addonTable.CallbackRegistry:UnregisterCallback("EncounterUpdate", self)

  self.powerKind = nil
end

function addonTable.Display.EnergyBarMixin:Strip()
  self:StripInternal()
  self.forceShow = nil
end

function addonTable.Display.EnergyBarMixin:UpdateValue()
  local maxPower = UnitPowerMax(self.unit, self.powerKind)
  local currentPower = UnitPower(self.unit, self.powerKind)

  self.statusBar:SetMinMaxValues(0, maxPower)
  self.statusBar:SetValue(currentPower)

  if self.forceShow then
    self:SetAlpha(maxPower)
  end
end

function addonTable.Display.EnergyBarMixin:OnEvent()
  self:UpdateValue()
end
