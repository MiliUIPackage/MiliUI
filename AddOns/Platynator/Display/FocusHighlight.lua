---@class addonTablePlatynator
local addonTable = select(2, ...)

addonTable.Display.FocusHighlightMixin = {}

function addonTable.Display.FocusHighlightMixin:SetUnit(unit)
  self.unit = unit
  if unit then
    self:ApplyFocus()
    addonTable.Cache:RegisterCallback(unit, "focus", function()
      self:ApplyFocus()
    end)
  end
end

function addonTable.Display.FocusHighlightMixin:Strip()
  self.ApplyFocus = nil
end

function addonTable.Display.FocusHighlightMixin:ApplyFocus()
  self:SetShown(addonTable.Cache:Get(self.unit, "focus"))
end
