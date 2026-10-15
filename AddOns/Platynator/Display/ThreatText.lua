---@class addonTablePlatynator
local addonTable = select(2, ...)

local InstanceOrParty = addonTable.Display.Utilities.IsInInstanceOrParty

addonTable.Display.ThreatTextMixin = {}

function addonTable.Display.ThreatTextMixin:PostInit()
  if self.details.showPercentSymbol then
    self.tail = "%"
  else
    self.tail = ""
  end

  self.partyOnly = self.details.showWhenGrouped

  self.value = self.details.value
end

function addonTable.Display.ThreatTextMixin:SetUnit(unit)
  self.unit = unit
  if self.unit then
    self:RegisterUnitEvent("UNIT_THREAT_LIST_UPDATE", unit)

    self:Update()

    addonTable.Display.RegisterForColorEvents(self, self.details.autoColors, self.details.color)
  else
    addonTable.Display.UnregisterForColorEvents(self)
    self:UnregisterAllEvents()
  end
end

function addonTable.Display.ThreatTextMixin:Strip()
  addonTable.Display.UnregisterForColorEvents(self)
  self:UnregisterAllEvents()
  self.tail = nil
  self.value = nil
end

function addonTable.Display.ThreatTextMixin:OnEvent(eventName)
  self:Update()

  if eventName ~= "UNIT_THREAT_LIST_UPDATE" then
    self:ColorEventHandler(eventName)
  end
end

function addonTable.Display.ThreatTextMixin:SetColor(r, g, b)
  if not r then
    local c = self.details.color
    r, g, b = c.r, c.g, c.b
  end
  self.text:SetTextColor(r, g, b)
end

function addonTable.Display.ThreatTextMixin:Update()
  self.text:SetText("")
  if not self.partyOnly or InstanceOrParty() then
    local _, _, scaled, raw = UnitDetailedThreatSituation("player", self.unit)
    local percentToShow = raw
    local prefix = ""
    if self.value == "raw" and UnitThreatSituation("player", self.unit) == 3 then
      percentToShow = UnitThreatPercentageOfLead("player", self.unit)
      prefix = "+"
    elseif self.value == "scaled" then
      percentToShow = scaled
    end

    if percentToShow then
      self.text:SetText(prefix .. C_StringUtil.RoundToNearestString(percentToShow) .. self.tail)
    end
  end
end
