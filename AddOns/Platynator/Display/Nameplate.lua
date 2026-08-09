---@class addonTablePlatynator
local addonTable = select(2, ...)

addonTable.Display.NameplateMixin = {}
function addonTable.Display.NameplateMixin:OnLoad()
  self:SetFlattensRenderLayers(true)
  self:SetCollapsesLayout(true)
  self:SetScript("OnEvent", self.OnEvent)

  self.widgets = {}

  self.SoftTargetIcon = self:CreateTexture(nil, "OVERLAY")
  self.SoftTargetIcon:SetSize(34, 34)
  self.SoftTargetIcon:SetPoint("BOTTOM", self, "TOP", -1, 24)
  self.SoftTargetIcon:Hide()

  self.BuffDisplay = CreateFrame("Frame", nil, self)
  self.BuffDisplay:SetSize(10, 10)
  self.BuffDisplay:SetFlattensRenderLayers(true)
  self.DebuffDisplay = CreateFrame("Frame", nil, self)
  self.DebuffDisplay:SetSize(10, 10)
  self.DebuffDisplay:SetFlattensRenderLayers(true)
  self.CrowdControlDisplay = CreateFrame("Frame", nil, self)
  self.CrowdControlDisplay:SetSize(10, 10)
  self.CrowdControlDisplay:SetFlattensRenderLayers(true)

  self:SetSize(10, 10)

  self.casting = false

  self.sizeChangeCount = -1

  if not addonTable.Constants.IsMidnightNext then
    addonTable.Display.SetupLegacyAuras(self)
  else
    self.AurasManager = addonTable.Utilities.InitFrameWithMixin(self, addonTable.Display.AurasManagerNextMixin)
  end
end


function addonTable.Display.NameplateMixin:OnSizeChanged()
  -- Optimisation to avoid recalculating anchors/sizes while nameplate scales up/down
  self.sizeChangeCount = 0
  self:SetScript("OnUpdate", function()
    self.sizeChangeCount = self.sizeChangeCount + 1
    if self.sizeChangeCount >= 2 then
      self:ApplyPixelPerfectSizing()
      self:SetScript("OnUpdate", nil)
    end
  end)
end

-- Avoid pixel-perfecting the alignment if the scale hasn't changed, or its
-- shrinking cause the nameplate is disappearing
function addonTable.Display.NameplateMixin:ShouldNotSize()
  -- Detect sizing down, which we should ignore
  if not self.unit then
    return true
  end
  local scale = self:GetEffectiveScale()
  return scale == self.lastScale or scale < self.offsetScale
end

function addonTable.Display.NameplateMixin:LayerWidgets()
  addonTable.Display.LayerWidgets(self.widgets)
end

function addonTable.Display.NameplateMixin:ApplyPixelPerfectSizing()
  if self:ShouldNotSize() then
    return
  end
  for _, w in ipairs(self.widgets) do
    if w:IsShown() then
      w:ApplyAnchor()
      w:ApplySize()
    else
      w.pixelPerfectRequired = true
    end
  end
  self.lastScale = self:GetEffectiveScale()
end

function addonTable.Display.NameplateMixin:InitializeWidgets(design, scaleOffset, scaleMod)
  self.offsetScale = (scaleOffset or 1) * UIParent:GetEffectiveScale() * addonTable.Config.Get(addonTable.Config.Options.GLOBAL_SCALE)
  self.scale = design.scale * scaleMod

  self.lastScale = self:GetEffectiveScale()

  self.unit = nil
  self:UpdateVisual()

  if self.widgets then
    addonTable.Display.ReleaseWidgets(self.widgets)
    self.widgets = nil
  end
  self.widgets = addonTable.Display.GetWidgets(design, self)

  local auras = design.auras
  local designInfo = {}
  for _, a in ipairs(auras) do
    designInfo[a.kind] = a
  end
  self:AnchorAuras(designInfo)
  if not addonTable.Constants.IsMidnightNext then
    addonTable.Display.InitializeWidgetsLegacyAuras(self, designInfo)
  else
    self.AurasManager:InitializeWidgets(self, designInfo)
  end

  if self:GetScript("OnSizeChanged") == nil then
    self:SetScript("OnSizeChanged", self.OnSizeChanged)
  end
  self:SetScript("OnUpdate", nil)
end

function addonTable.Display.NameplateMixin:Install(nameplate, offsetY)
  self:Show()
  self:SetFrameStrata("BACKGROUND")
  self:SetPoint("CENTER", nameplate, "CENTER", 0, offsetY)
  self:SetSize(10, 10)

  -- We force a sizing immediately to avoid 0 size widgets breaking the textures from the Blizz animations
  self:ApplyPixelPerfectSizing()
  if self.widgets then
    addonTable.Display.LayerWidgets(self.widgets)
  end
  self:SetScript("OnUpdate", nil)
end

function addonTable.Display.NameplateMixin:SetUnit(unit)
  self.SoftTargetIcon:Hide()

  self.interactUnit = unit
  if unit and (not UnitNameplateShowsWidgetsOnly or not UnitNameplateShowsWidgetsOnly(unit)) and not UnitIsGameObject(unit) then
    self.unit = unit

    if UnitCanAttack("player", self.unit) and addonTable.Config.Get(addonTable.Config.Options.OUT_OF_RANGE_ALPHA) ~= 1 then
      addonTable.Cache:RegisterCallback(self.unit, "range", function(state)
        self.inRange = state
        self:UpdateVisual()
      end)
      self.inRange = addonTable.Cache:Get(self.unit, "range")
    else
      self.inRange = true
    end

    if UnitCanAttack("player", self.unit) and addonTable.Config.Get(addonTable.Config.Options.NOT_IN_PULL_ALPHA) ~= 1 then
      self:RegisterEvent("PLAYER_REGEN_ENABLED")
      self:RegisterEvent("PLAYER_REGEN_DISABLED")

      self.inCombat = addonTable.Display.Utilities.IsInCombatWith(self.unit)
      addonTable.Cache:RegisterCallback(self.unit, "combat", function(inCombat)
        self.inCombat = inCombat
        self:UpdateVisual()
      end)
    else
      self.inCombat = true
    end

    for _, w in ipairs(self.widgets) do
      w:Show()
      w:SetUnit(self.unit)
    end

    addonTable.Cache:Get(unit, "target")
    addonTable.Cache:Get(unit, "softTarget")
    addonTable.Cache:Get(unit, "mouseover")
    addonTable.Cache:Get(unit, "focus")

    addonTable.Cache:RegisterCallback(unit, "target", function()
      self:UpdateVisual()
    end)

    addonTable.Cache:RegisterCallback(unit, "softTarget", function()
      self:UpdateVisual()
    end)

    addonTable.Cache:RegisterCallback(unit, "mouseover", function()
      self:UpdateVisual()
    end)

    addonTable.Cache:RegisterCallback(unit, "focus", function()
      self:UpdateVisual()
    end)

    if not addonTable.Constants.IsMidnightNext then
      addonTable.Display.SetUnitUpdateLegacyAuras(self, self.unit)
    end
    self.AurasManager:SetUnit(self.unit)


    self:UpdateCastingState(addonTable.Cache:Get(self.unit, "cast"))
    addonTable.Cache:RegisterCallback(self.unit, "cast", function(state)
      local old = self.casting
      self:UpdateCastingState(state)
      if old ~= self.casting then
        self:UpdateVisual()
      end
    end)

    addonTable.CallbackRegistry:RegisterCallback("TextOverrideUpdated", function(_, unit)
      if unit ~= self.unit then
        return
      end
      for _, w in ipairs(self.widgets) do
        if w.ApplyTextOverride then
          w:ApplyTextOverride()
        end
      end
    end, self)
  else
    self.unit = nil
    for _, w in ipairs(self.widgets) do
      w:SetUnit(nil)
      w:Hide()
    end

    if not addonTable.Constants.IsMidnightNext then
      addonTable.Display.SetUnitUpdateLegacyAuras(self, nil)
    end
    self.AurasManager:SetUnit(nil)

    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self:UnregisterEvent("PLAYER_REGEN_DISABLED")

    self:UnregisterAllEvents()
    self.casting = false

    addonTable.CallbackRegistry:UnregisterCallback("TextOverrideUpdated", self)
  end

  self:UpdateVisual()
end

function addonTable.Display.NameplateMixin:AnchorAuras(designInfo)
  self.DebuffDisplay.enabled = false
  self.BuffDisplay.enabled = false
  self.CrowdControlDisplay.enabled = false
  local defaultSize = 20
  if designInfo.debuffs then
    self.DebuffDisplay.enabled = true
    self.DebuffDisplay:ClearAllPoints()
    self.DebuffDisplay:SetFrameStrata("MEDIUM")
    self.DebuffDisplay:SetFrameLevel(addonTable.Constants.LayerFrameLevelStep * designInfo.debuffs.layer + 450)
    self.DebuffDisplay.details = designInfo.debuffs
    PixelUtil.SetSize(self.DebuffDisplay, defaultSize * designInfo.debuffs.scale, defaultSize * designInfo.debuffs.scale)
    addonTable.Display.ApplyAnchor(self.DebuffDisplay, designInfo.debuffs.anchor)
  end
  if designInfo.buffs then
    self.BuffDisplay.enabled = true
    self.BuffDisplay:ClearAllPoints()
    self.BuffDisplay:SetFrameStrata("MEDIUM")
    self.BuffDisplay:SetFrameLevel(addonTable.Constants.LayerFrameLevelStep * designInfo.buffs.layer + 450 + 10)
    self.BuffDisplay.details = designInfo.buffs
    PixelUtil.SetSize(self.BuffDisplay, defaultSize * designInfo.buffs.scale, defaultSize * designInfo.buffs.scale)
    addonTable.Display.ApplyAnchor(self.BuffDisplay, designInfo.buffs.anchor)
  end
  if designInfo.crowdControl then
    self.CrowdControlDisplay.enabled = true
    self.CrowdControlDisplay:ClearAllPoints()
    self.CrowdControlDisplay:SetFrameStrata("MEDIUM")
    self.CrowdControlDisplay:SetFrameLevel(addonTable.Constants.LayerFrameLevelStep * designInfo.crowdControl.layer + 450 + 20)
    self.CrowdControlDisplay.details = designInfo.crowdControl
    PixelUtil.SetSize(self.CrowdControlDisplay, defaultSize * designInfo.crowdControl.scale, defaultSize * designInfo.crowdControl.scale)
    addonTable.Display.ApplyAnchor(self.CrowdControlDisplay, designInfo.crowdControl.anchor)
  end
end

function addonTable.Display.NameplateMixin:UpdateCastingState(state)
  self.casting = state.cast[1] ~= nil or state.channel[1] ~= nil
end

function addonTable.Display.NameplateMixin:OnEvent()
  self:UpdateVisual()
end

function addonTable.Display.NameplateMixin:UpdateVisual()
  local scaleMod = (addonTable.Constants.IsHitTestPointsAvailable and not addonTable.Constants.IsMists) and 1 or UIParent:GetEffectiveScale()
  if not self.unit then
    self:SetAlpha(1)
    self:SetScale(self.scale * addonTable.Config.Get(addonTable.Config.Options.GLOBAL_SCALE) * scaleMod)
    return
  end

  local scale = 1
  local alpha = 0
  local isTarget = UnitIsUnit("target", self.unit) or UnitIsUnit("softenemy", self.unit) or UnitIsUnit("softfriend", self.unit)
  if isTarget then
    alpha = 1
  else
    local isMouseover = UnitIsUnit("mouseover", self.unit)
    if isMouseover then
      alpha = math.max(alpha, addonTable.Config.Get(addonTable.Config.Options.MOUSEOVER_ALPHA))
    end
    if self.casting then
      scale = addonTable.Config.Get(addonTable.Config.Options.CAST_SCALE)
      alpha = math.max(alpha, addonTable.Config.Get(addonTable.Config.Options.CAST_ALPHA))
    end
    if not isMouseover and not self.casting then
      alpha = addonTable.Config.Get(addonTable.Config.Options.NOT_TARGET_ALPHA)
    end
  end
  if not self.inRange then
    alpha = alpha * addonTable.Config.Get(addonTable.Config.Options.OUT_OF_RANGE_ALPHA)
  end
  if not self.inCombat and UnitAffectingCombat("player") then
    alpha = alpha * addonTable.Config.Get(addonTable.Config.Options.NOT_IN_PULL_ALPHA)
  end
  self:SetScale(self.scale * scale * addonTable.Config.Get(addonTable.Config.Options.GLOBAL_SCALE) * scaleMod)
  self:SetAlpha(alpha)
end

function addonTable.Display.NameplateMixin:UpdateSoftInteract()
  -- From Blizzard code, modified
  local doEnemyIcon = GetCVarBool("SoftTargetIconEnemy")
  local doFriendIcon = GetCVarBool("SoftTargetIconFriend")
  local doInteractIcon = GetCVarBool("SoftTargetIconInteract")
  local hasCursorTexture = false
  if ((doEnemyIcon and UnitIsUnit(self.interactUnit, "softenemy")) or
    (doFriendIcon and UnitIsUnit(self.interactUnit, "softfriend")) or
    (doInteractIcon and UnitIsUnit(self.interactUnit, "softinteract"))
    ) then
    hasCursorTexture = SetUnitCursorTexture(self.SoftTargetIcon, self.interactUnit)
  end
  self.SoftTargetIcon:SetShown(hasCursorTexture)
end

local pandemicPercentage = 0.3
local pandemicCurve
if C_CurveUtil then
  pandemicCurve = C_CurveUtil.CreateCurve()
  pandemicCurve:SetType(Enum.LuaCurveType.Step)
  pandemicCurve:AddPoint(0, 1)
  pandemicCurve:AddPoint(pandemicPercentage, 0)
end
function addonTable.Display.NameplateMixin:UpdateAurasForPandemic()
  local time = GetTime()
  if self.DebuffDisplay.details and self.DebuffDisplay.details.showPandemic and self.DebuffDisplay.Wrapped.items then
    for _, item in ipairs(self.DebuffDisplay.Wrapped.items) do
      if item.durationSecret then
        item.Pandemic:SetAlpha(C_CurveUtil.EvaluateColorValueFromBoolean(item.durationSecret:IsZero(), 0, item.durationSecret:EvaluateRemainingPercent(pandemicCurve)))
      elseif item.expirationTime then
        item.Pandemic:SetAlpha(item.duration > 0 and item.expirationTime - time <= item.duration * pandemicPercentage and 1 or 0)
      end
    end
  end
end
