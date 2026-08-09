---@class addonTablePlatynator
local addonTable = select(2, ...)

addonTable.Display.TargetHighlightMixin = {}

function addonTable.Display.TargetHighlightMixin:SetUnit(unit)
  self.unit = unit
  if unit then
    self:ApplyTarget()
    addonTable.Cache:RegisterCallback(unit, "target", function()
      self:ApplyTarget()
    end)
  end
end

function addonTable.Display.TargetHighlightMixin:Strip()
  self.ApplyTarget = nil
end

function addonTable.Display.TargetHighlightMixin:ApplyTarget()
  self:SetShown(addonTable.Cache:Get(self.unit, "target"))
end
