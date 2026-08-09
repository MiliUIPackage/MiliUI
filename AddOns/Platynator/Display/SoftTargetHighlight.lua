---@class addonTablePlatynator
local addonTable = select(2, ...)

addonTable.Display.SoftTargetHighlightMixin = {}

function addonTable.Display.SoftTargetHighlightMixin:SetUnit(unit)
  self.unit = unit
  if unit then
    self:ApplyTarget()
    addonTable.Cache:RegisterCallback(unit, "softTarget", function()
      self:ApplyTarget()
    end)
  end
end

function addonTable.Display.SoftTargetHighlightMixin:Strip()
  self.ApplyTarget = nil
end

function addonTable.Display.SoftTargetHighlightMixin:ApplyTarget()
  self:SetShown(addonTable.Cache:Get(self.unit, "softTarget"))
end
