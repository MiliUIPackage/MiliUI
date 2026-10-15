---@class addonTablePlatynator
local addonTable = select(2, ...)

addonTable.Display.FlashingHighlightMixin = {}

function addonTable.Display.FlashingHighlightMixin:SetUnit(unit)
  self.unit = unit
  if self.unit then
    addonTable.Display.RegisterForColorEvents(self, self.details.autoColors)
  else
    self:Strip()
  end
end

function addonTable.Display.FlashingHighlightMixin:Strip()
  self.Animation:Stop()
end

function addonTable.Display.FlashingHighlightMixin:OnEvent(eventName)
  self:ColorEventHandler(eventName)
end
