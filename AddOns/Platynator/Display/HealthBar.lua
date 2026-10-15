---@class addonTablePlatynator
local addonTable = select(2, ...)

addonTable.Display.HealthBarMixin = {}

function addonTable.Display.HealthBarMixin:PostInit()
  if self.details.background.applyColor then -- Apply tint to colours
    self.modColors = addonTable.Display.Utilities.TintAutoColors(self.details.autoColors, self.details.background.color)
  end

  self.animate = self.details.animate and Enum.StatusBarInterpolation.ExponentialEaseOut or Enum.StatusBarInterpolation.Immediate
  self.isMarkerShown = self.marker:IsShown()
end

function addonTable.Display.HealthBarMixin:SetUnit(unit)
  self.unit = unit
  if self.unit then
    -- Disable animation for initial setup
    local animate = self.animate
    self.animate = nil
    local currentState = addonTable.Cache:Get(self.unit, "health")
    self:UpdateHealth(currentState)
    addonTable.Cache:RegisterCallback(self.unit, "health", function(state)
      self:UpdateHealth(state)

      if self.details.animate then
        self.statusBarCutaway:SetValue(self.oldHealth)
        self.statusBarCutawayAnimation:Play()
        self.oldHealth = self.newHealth
      end
    end)
    self.animate = animate

    if self.details.animate then
      self.oldHealth = currentState.absolute
      self.statusBarCutaway:SetAlpha(0)
    end

    addonTable.Display.RegisterForColorEvents(self, self.details.autoColors)
  else
    self:UnregisterAllEvents()
    self.statusBarCutawayAnimation:Stop()
    addonTable.Display.UnregisterForColorEvents(self)
  end
end

function addonTable.Display.HealthBarMixin:Strip()
  self:UnregisterAllEvents()
  self.statusBarCutawayAnimation:Stop()
  addonTable.Display.UnregisterForColorEvents(self)
  self.modColors = nil
  self.animate = nil
  self.calculator = nil

end

function addonTable.Display.HealthBarMixin:SetColor(r, g, b, a)
  self.statusBar:GetStatusBarTexture():SetVertexColor(r, g, b)
  self.statusBarCutaway:GetStatusBarTexture():SetVertexColor(r, g, b)
  if self.details.background.applyColor then
    local mod = self.details.background.color
    if self.modColors then
      self.background:SetVertexColor(addonTable.Display.GetColor(self.modColors, self.colorState, self.unit))
    else
      self.background:SetVertexColor(r, g, b, mod.a)
    end
  end
  self.marker:SetVertexColor(r, g, b)
end

function addonTable.Display.HealthBarMixin:UpdateHealth(state)
  self.statusBar:SetMinMaxValues(0, state.maxWithAbsorbs)

  self.statusBarCutaway:SetMinMaxValues(0, state.maxWithAbsorbs)
  self.statusBarAbsorb:SetMinMaxValues(0, state.maxWithAbsorbs)

  self.statusBarAbsorb:SetValue(state.absorbs, self.animate)
  self.newHealth = state.absolute
  self.statusBar:SetValue(self.newHealth, self.animate)

  if self.isMarkerShown then
    self:SetMarkerAlpha(state.markerAlpha)
  end
end

function addonTable.Display.HealthBarMixin:OnEvent(eventName)
  self:ColorEventHandler(eventName)
end
