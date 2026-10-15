---@class addonTablePlatynator
local addonTable = select(2, ...)

local InstanceOrParty = addonTable.Display.Utilities.IsInInstanceOrParty

addonTable.Display.ThreatDifferentialTextMixin = {}

function addonTable.Display.ThreatDifferentialTextMixin:PostInit()
  self.partyOnly = self.details.showWhenGrouped
end

function addonTable.Display.ThreatDifferentialTextMixin:SetUnit(unit)
  self.unit = unit
  if self.unit then
    self.isTarget = addonTable.Cache:Get(self.unit, "target")
    addonTable.Cache:RegisterCallback(self.unit, "target", function(state)
      self.isTarget = state

      if self.isTarget then
        self:RegisterUnitEvent("UNIT_THREAT_LIST_UPDATE", unit)
      else
        self:UnregisterEvent("UNIT_THREAT_LIST_UPDATE")
      end
      self:Update()
    end)

    if self.isTarget then
      self:RegisterUnitEvent("UNIT_THREAT_LIST_UPDATE", unit)
    end


    self:Update()

    addonTable.Display.RegisterForColorEvents(self, self.details.autoColors, self.details.color)
  else
    addonTable.Display.UnregisterForColorEvents(self)
    self:UnregisterAllEvents()
  end
end

function addonTable.Display.ThreatDifferentialTextMixin:Strip()
  addonTable.Display.UnregisterForColorEvents(self)
  self:UnregisterAllEvents()
  self.tail = nil
  self.value = nil
end

function addonTable.Display.ThreatDifferentialTextMixin:SetColor(r, g, b)
  if not r then
    local c = self.details.color
    r, g, b = c.r, c.g, c.b
  end
  self.text:SetTextColor(r, g, b)
end

function addonTable.Display.ThreatDifferentialTextMixin:OnEvent(eventName)
  self:Update()

  if eventName ~= "UNIT_THREAT_LIST_UPDATE" then
    self:ColorEventHandler(eventName)
  end
end

function addonTable.Display.ThreatDifferentialTextMixin:Update()
  self.text:SetText("")
  if self.partyOnly and not InstanceOrParty() then
    return
  end

  if self.isTarget and addonTable.Cache:Get(self.unit, "combat") then
    local _, _, _, _, absolute = UnitDetailedThreatSituation("player", "target")
    if absolute == nil then
      absolute = nil
    end
    local max = 0
    if IsInRaid() then
      for i = 1, 40 do
        if UnitExists("raid" .. i) and not UnitIsUnit("player", "raid" .. i) then
          local _, _, _, _, raider = UnitDetailedThreatSituation("raid" .. i, "target")
          local _, _, _, _, pet = UnitDetailedThreatSituation("raidpet" .. i, "target")
          if raider then
            max = math.max(max, raider)
          end
          if pet then
            max = math.max(max, pet)
          end
        end
      end
    elseif IsInGroup() then
      for i = 1, 4 do
        if UnitExists("party" .. i) then
          local _, _, _, _, party = UnitDetailedThreatSituation("party" .. i, "target")
          local _, _, _, _, pet = UnitDetailedThreatSituation("partypet" .. i, "target")
          if party then
            max = math.max(max, party)
          end
          if pet then
            max = math.max(max, pet)
          end
        end
      end
    end

    local final = (absolute or 0) - max
    
    local display = tostring(AbbreviateLargeNumbers(math.abs(final)))
    if final > 0 then
      display = "+" .. display
    elseif final < 0 then
      display = "-" .. display
    end

    self.lastValue = display

    self.text:SetText(display)
  end
end
