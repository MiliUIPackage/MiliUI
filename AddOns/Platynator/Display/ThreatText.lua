---@class addonTablePlatynator
local addonTable = select(2, ...)

local inInstanceOrParty = false
local instanceTracker = CreateFrame("Frame")
instanceTracker:RegisterEvent("PLAYER_ENTERING_WORLD")
instanceTracker:RegisterEvent("ZONE_CHANGED_NEW_AREA")
instanceTracker:RegisterEvent("INSTANCE_GROUP_SIZE_CHANGED")
instanceTracker:SetScript("OnEvent", function(_, event)
  inInstanceOrParty = addonTable.Display.Utilities.IsInRelevantInstance({dungeon = true, raid = true, delve = true, pvp = true}) or IsInGroup()
end)

addonTable.Display.ThreatTextMixin = {}

function addonTable.Display.ThreatTextMixin:PostInit()
  if self.details.showPercentSymbol then
    self.tail = "%"
  else
    self.tail = ""
  end

  self.partyOnly = self.details.showWhenGrouped
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
  if not self.partyOnly or inInstanceOrParty then
    local _, _, percentage = UnitDetailedThreatSituation("player", self.unit)

    if percentage then
      self.text:SetText(C_StringUtil.RoundToNearestString(percentage) .. self.tail)
    end
  end
end
