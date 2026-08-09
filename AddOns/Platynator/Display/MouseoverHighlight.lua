---@class addonTablePlatynator
local addonTable = select(2, ...)

addonTable.Display.MouseoverHighlightMixin = {}

function addonTable.Display.MouseoverHighlightMixin:SetUnit(unit)
  self.unit = unit
  if unit then
    self:ApplyMouseover()
    if not self.details.includeTarget then
      addonTable.Cache:RegisterCallback(unit, "target", function()
        self:ApplyMouseover()
      end)
    end
    addonTable.Cache:RegisterCallback(unit, "mouseover", function()
      self:ApplyMouseover()
    end)
  end
end

function addonTable.Display.MouseoverHighlightMixin:Strip()
  self.ApplyMouseover = nil
end

function addonTable.Display.MouseoverHighlightMixin:ApplyMouseover()
  self:SetShown(addonTable.Cache:Get(self.unit, "mouseover") and (self.details.includeTarget or not addonTable.Cache:Get(self.unit, "target")))
end
