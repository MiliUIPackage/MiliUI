---@class addonTablePlatynator
local addonTable = select(2, ...)

addonTable.Display.CastBarMixin = {}

local GetInterruptSpell = addonTable.Display.Utilities.GetInterruptSpellPriority

function addonTable.Display.CastBarMixin:PostInit()
  if self.details.background.applyColor then -- Apply tint to colours
    self.modColors = addonTable.Display.Utilities.TintAutoColors(self.details.autoColors, self.details.background.color)
  end

  self.showInterruptMarker = self.details.interruptMarker.asset ~= "none"
end

function addonTable.Display.CastBarMixin:SetUnit(unit)
  self.unit = unit
  if self.unit then

    addonTable.Cache:RegisterCallback(self.unit, "cast", function(state)
      if state.interrupted then
        self:ApplyInterrupt()
      elseif state.cast[1] == nil and state.channel[1] == nil then
        self:ClearCast()
      else
        self:ApplyCasting(state)
      end
    end)

    self:ApplyCasting(addonTable.Cache:Get(self.unit, "cast"))

    addonTable.Display.RegisterForColorEvents(self, self.details.autoColors)
  else
    self:StripInternal()
  end
end

function addonTable.Display.CastBarMixin:StripInternal()
  if self.timer then
    self.timer:Cancel()
    self.timer = nil
  end
  self.uninterruptibleCheck = nil

  self:UnregisterAllEvents()
  addonTable.Display.UnregisterForColorEvents(self)
end

function addonTable.Display.CastBarMixin:Strip()
  self:StripInternal()
  self.modColors = nil
end

function addonTable.Display.CastBarMixin:ApplyInterrupt()
  self:Show()
  self.statusBar:SetMinMaxValues(0, 1)
  self.statusBar:SetValue(1)
  self.interruptMarker:Hide()
end

function addonTable.Display.CastBarMixin:OnEvent(eventName, ...)
  if self:IsShown() then
    self:ColorEventHandler(eventName)
  end
end

function addonTable.Display.CastBarMixin:SetColor(r, g, b)
  if r == nil then
    self:Hide()
    return
  end

  self.statusBar:GetStatusBarTexture():SetVertexColor(r, g, b)
  self.marker:SetVertexColor(r, g, b)
  if self.details.background.applyColor then
    local mod = self.details.background.color
    if self.modColors then
      self.background:SetVertexColor(addonTable.Display.GetColor(self.modColors, self.colorState, self.unit))
    else
      self.background:SetVertexColor(r, g, b, mod.a)
    end
  end
end

function addonTable.Display.CastBarMixin:ClearCast()
  if self.timer then
    self.timer:Cancel()
    self.timer = nil
  end
  self:Hide()
  self.notInterruptible = nil
  self.uninterruptibleCheck = nil
end

function addonTable.Display.CastBarMixin:ApplyCasting(state)
  local isChanneled, isEmpowered = state.channelDuration ~= nil, state.empoweredDuration ~= nil
  local castDuration = state.empoweredDuration or state.channelDuration or state.castDuration

  if castDuration ~= nil then
    local notInterruptible
    if isChanneled then
      notInterruptible = state.channel[7]
    else
      notInterruptible = state.cast[8]
    end
    if notInterruptible == nil then
      notInterruptible = false
    end

    if self.timer then
      self.timer:Cancel()
      self.timer = nil
    end

    self.statusBar:SetTimerDuration(castDuration, nil, isChanneled and not isEmpowered and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime)
    local spellID, interruptDuration
    if self.showInterruptMarker then
      spellID, interruptDuration = GetInterruptSpell()
    end
    self.interruptMarker:SetShown(spellID ~= nil)
    self.interruptPositioner:SetShown(spellID ~= nil)
    if spellID then
      self:ReverseInterruptMarker(isChanneled and not isEmpowered)
      local total = castDuration:GetTotalDuration()
      self.interruptPositioner:SetMinMaxValues(0, total)
      self.interruptMarker:SetMinMaxValues(0, total)
      self.uninterruptibleCheck = C_CurveUtil.EvaluateColorValueFromBoolean(notInterruptible, 0, 1)
      self.interruptPositioner:SetValue(castDuration:GetElapsedDuration())
      self.interruptMarker:SetValue(interruptDuration:GetRemainingDuration())
      self:RefreshInterruptMarker()
      self.timer = C_Timer.NewTicker(0.1, function()
        self:RefreshInterruptMarker()
      end)
    end
    self:Show()
  else
    self:ClearCast()
  end
end

function addonTable.Display.CastBarMixin:RefreshInterruptMarker()
  local spellID, interruptDuration = GetInterruptSpell()
  if spellID then
    self.uninterruptibleCheck = C_CurveUtil.EvaluateColorValueFromBoolean(interruptDuration:IsZero(), 0, self.uninterruptibleCheck)
    self.interruptMarker:SetAlpha(self.uninterruptibleCheck)
  end
end
