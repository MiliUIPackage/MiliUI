---@class addonTablePlatynator
local addonTable = select(2, ...)

local LSM = LibStub("LibSharedMedia-3.0")

local auraFormatter, auraPlainFormatter = addonTable.Display.Utilities.GetAuraNumericFormatter()

local function StyleAura(auraFrame, details)
  auraFrame.kind = details.kind

  auraFrame:EnableMouseMotion(details.showTooltips)

  auraFrame.TextsContainer.Applications:SetFontObject(addonTable.CurrentFont)
  auraFrame.TextsContainer.Applications:ClearAllPoints()
  addonTable.Display.ApplyAnchor(auraFrame.TextsContainer.Applications, details.texts.stacks.anchor, addonTable.CurrentFontUsesSmoothing and 1/details.texts.stacks.scale or 1)
  if addonTable.CurrentFontUsesSmoothing then
    auraFrame.TextsContainer.Applications:SetTextScale(1)
    auraFrame.TextsContainer.Applications:SetScale(details.texts.stacks.scale)
  else
    auraFrame.TextsContainer.Applications:SetTextScale(details.texts.stacks.scale)
    auraFrame.TextsContainer.Applications:SetScale(1)
  end
  local c1 = details.texts.stacks.color
  auraFrame.TextsContainer.Applications:SetTextColor(c1.r, c1.g, c1.b)
  auraFrame.TextsContainer.Applications:SetShown(details.texts.stacks.visible);

  auraFrame.TextsContainer.Countdown:SetShown(details.texts.countdown.visible)
  if details.texts.countdown.visible then
    auraFrame.TextsContainer.Countdown:SetFontObject(addonTable.CurrentFont)
    auraFrame.TextsContainer.Countdown:ClearAllPoints()
    addonTable.Display.ApplyAnchor(auraFrame.TextsContainer.Countdown, details.texts.countdown.anchor, addonTable.CurrentFontUsesSmoothing and 1/details.texts.countdown.scale or 1)
    if addonTable.CurrentFontUsesSmoothing then
      auraFrame.TextsContainer.Countdown:SetTextScale(1)
      auraFrame.TextsContainer.Countdown:SetScale(details.texts.countdown.scale)
    else
      auraFrame.TextsContainer.Countdown:SetTextScale(details.texts.countdown.scale)
      auraFrame.TextsContainer.Countdown:SetScale(1)
    end
    local c2 = details.texts.countdown.color
    auraFrame.TextsContainer.Countdown:SetTextColor(c2.r, c2.g, c2.b)
    auraFrame:ClearDurationText()
    if details.texts.countdown.showFractions then
      auraFrame:SetDurationText(auraFrame.TextsContainer.Countdown, {textFormatter = auraFormatter})
    else
      auraFrame:SetDurationText(auraFrame.TextsContainer.Countdown, {textFormatter = auraPlainFormatter})
    end
  end

  if auraFrame.TextsContainer.Applications.SetSmoothScaling then
    auraFrame.TextsContainer.Applications:SetSmoothScaling(addonTable.CurrentFontUsesSmoothing)
    auraFrame.TextsContainer.Countdown:SetSmoothScaling(addonTable.CurrentFontUsesSmoothing)
  end

  auraFrame.Cooldown:SetDrawEdge(details.showSwipe)
  auraFrame.Cooldown:SetDrawSwipe(details.showSwipe)

  PixelUtil.SetSize(auraFrame, 20, 20 * details.height)
  PixelUtil.SetSize(auraFrame.Border, 20, 20 * details.height)
  PixelUtil.SetSize(auraFrame.Icon, 20, 20 * details.height)
  local texBase = 0.95 * (1 - details.height) / 2
  auraFrame.Icon:SetTexCoord(0.05, 0.95, 0.05 + texBase, 0.95 - texBase)

  auraFrame.Dispel:SetShown(details.showType)
end

local function GetAurasInitializerModern(container)
  local borderAsset = LSM:Fetch("nineslice", "Platy: 1px")
  local dispelAsset = LSM:Fetch("nineslice", "Platy: 4px")
  return function(frame)
    table.insert(container.frames, frame)
    frame:SetFlattensRenderLayers(true)
    frame:SetSize(20, 20)
    frame.Icon = frame:CreateTexture(nil, "ARTWORK")
    frame.Icon:SetSize(20, 20)
    frame.Icon:SetPoint("CENTER")
    frame.Cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.Cooldown:SetDrawBling(false)
    frame.Cooldown:SetHideCountdownNumbers(true)
    frame.Cooldown:SetDrawEdge(true)
    frame.Cooldown:SetReverse(true)
    frame.TextsContainer = CreateFrame("Frame", nil, frame)
    frame.TextsContainer:SetAllPoints()
    frame.TextsContainer.Countdown = frame.TextsContainer:CreateFontString(nil, nil, "GameFontHighlight")
    frame.TextsContainer.Countdown:SetDrawLayer("OVERLAY", 1)
    frame.TextsContainer.Countdown:SetPoint("CENTER")
    frame.TextsContainer.Applications = frame.TextsContainer:CreateFontString(nil, nil, "GameFontHighlight")
    frame.TextsContainer.Applications:SetDrawLayer("OVERLAY", 2)
    frame.TextsContainer.Applications:SetPoint("BOTTOMRIGHT", 3, -2)

    frame.Border = frame:CreateTexture(nil, "OVERLAY")
    frame.Border:SetAllPoints(true)
    frame.Border:SetScale(borderAsset.scaleModifier)
    frame.Border:SetTexture(borderAsset.file)
    frame.Border:SetTextureSliceMargins(borderAsset.margins.left, borderAsset.margins.top, borderAsset.margins.right, borderAsset.margins.bottom)
    frame.Border:SetVertexColor(0, 0, 0)
    frame.Dispel = CreateFrame("Frame", nil, frame)
    frame.Dispel:SetAllPoints()
    do
      local dispelTexture = frame.Dispel:CreateTexture()
      dispelTexture:SetAllPoints()
      dispelTexture:SetScale(dispelAsset.scaleModifier)
      dispelTexture:SetTexture(dispelAsset.file)
      dispelTexture:SetTextureSliceMargins(dispelAsset.margins.left, dispelAsset.margins.top, dispelAsset.margins.right, dispelAsset.margins.bottom)
      dispelTexture:SetVertexColor(1, 0, 0)
      frame.Dispel.Border = dispelTexture
    end

    frame:SetApplicationCount(frame.TextsContainer.Applications, {})
    frame:SetIcon(frame.Icon)
    frame:SetDurationCooldown(frame.Cooldown)
    frame:SetAuraBorder(frame.Dispel.Border, {showIcon = false, showWhenHarmful = true, showWhenHelpful = true, style = 1})

    if container.details then
      StyleAura(frame, container.details)
    end
  end
end

addonTable.Display.AurasManagerNextMixin = {}

function addonTable.Display.AurasManagerNextMixin:OnLoad()
  self.buffs = CreateFrame("AuraContainer", nil, self, "CustomAuraContainerTemplate")
  self.debuffs = CreateFrame("AuraContainer", nil, self, "CustomAuraContainerTemplate")
  self.crowdControl = CreateFrame("AuraContainer", nil, self, "CustomAuraContainerTemplate")

  self.buffs:SetEnabled(false)
  self.debuffs:SetEnabled(false)
  self.crowdControl:SetEnabled(false)

  self.addedGroups = false

  self.crowdControl.frames = {}
  self.buffs.frames = {}
  self.debuffs.frames = {}
end

local directionMap = {
  LEFT = "RIGHT",
  CENTER = "CENTER",
  RIGHT = "LEFT",
}

local anchorMap = {
  LEFT = "TOPRIGHT",
  CENTER = "TOPLEFT",
  RIGHT = "TOPLEFT",
}

local function ProcessSpells(kind)
  local settings = addonTable.Config.Get(addonTable.Config.Options.AURA_FILTERS)[addonTable.Display.Utilities.GetSpecializationID()][kind]

  local include = {}
  local exclude = {}

  for spellID, priority in pairs(settings.include) do
    exclude[spellID] = true
    if not include[priority] then
      include[priority] = {}
    end
    include[priority][spellID] = true
  end

  for spellID in pairs(settings.exclude) do
    exclude[spellID] = true
  end

  return include, exclude
end

function addonTable.Display.AurasManagerNextMixin:GetFilters(kind, settings)
  local output = table.create(6)
  local include, exclude = ProcessSpells(kind)
  local includeFilter = kind == "buffs" and "HELPFUL|PLAYER" or kind == "debuffs" and "HARMFUL|PLAYER" or "HARMFUL"
  for i = 1, 2 do
    if include[i] then
      table.insert(output, {includeFilter, {includeSpellIDs = include[i]}})
    end
  end

  if kind == "buffs" then
    table.insert(output, {"HELPFUL|PLAYER", {excludeSpellIDs = exclude}})
    if settings.filters.defensive then
      table.insert(output, {"HELPFUL|BIG_DEFENSIVE|!PLAYER", {excludeSpellIDs = exclude}})
      table.insert(output, {"HELPFUL|EXTERNAL_DEFENSIVE|!PLAYER", {excludeSpellIDs = exclude}})
      table.insert(output, {"HELPFUL|RAID_IN_COMBAT|!PLAYER", {excludeSpellIDs = exclude}})
    elseif settings.filters.important then
      if settings.filters.enrage then
        table.insert(output, {"HELPFUL|IMPORTANT|!PLAYER", {excludeSpellIDs = exclude, excludeDispelTypes = {[""] = true}}})
        table.insert(output, {"HELPFUL|!PLAYER", {
          includeDispelTypes = {[""] = true},
          excludeSpellIDs = exclude,
        }})
        if settings.filters.dispelable then
          table.insert(output, {"HELPFUL|!IMPORTANT|!PLAYER", {excludeSpellIDs = exclude, excludeDispelTypes = {[""] = true}, isStealable = true}})
        end
      else
        table.insert(output, {"HELPFUL|IMPORTANT|!PLAYER", {excludeSpellIDs = exclude}})
        if settings.filters.dispelable then
          table.insert(output, {"HELPFUL|!IMPORTANT|!PLAYER", {excludeSpellIDs = exclude, isStealable = true}})
        end
      end
    else
      if settings.filters.enrage then
        table.insert(output, {"HELPFUL|!PLAYER", {includeDispelTypes = {[""] = true}}})
      elseif settings.filters.dispelable then
        table.insert(output, {"HELPFUL|!PLAYER", {excludeSpellIDs = exclude, isStealable = true}})
      else
        table.insert(output, {"HELPFUL|!PLAYER", {excludeSpellIDs = exclude}})
      end
    end
  elseif kind == "debuffs" then
    if settings.filters.fromYou then
      if settings.filters.important then
        table.insert(output, {"HARMFUL|IMPORTANT|PLAYER|!CROWD_CONTROL", {excludeSpellIDs = exclude}})
        table.insert(output, {"HARMFUL|!IMPORTANT|PLAYER|!CROWD_CONTROL", {excludeSpellIDs = exclude, nameplateShowPersonal = true}})
      else
        table.insert(output, {"HARMFUL|PLAYER|!CROWD_CONTROL", {excludeSpellIDs = exclude}})
      end
    else
      if settings.filters.important then
        table.insert(output, {"HARMFUL|IMPORTANT|!CROWD_CONTROL", {excludeSpellIDs = exclude}})
        table.insert(output, {"HARMFUL|!IMPORTANT|!CROWD_CONTROL", {excludeSpellIDs = exclude, nameplateShowPersonal = true}})
      else
        table.insert(output, {"HARMFUL|!CROWD_CONTROL", {excludeSpellIDs = exclude}})
      end
    end
  elseif kind == "crowdControl" then
    if settings.filters.fromYou then
      table.insert(output, {"HARMFUL|CROWD_CONTROL|PLAYER", {excludeSpellIDs = exclude}})
    else
      table.insert(output, {"HARMFUL|CROWD_CONTROL", {excludeSpellIDs = exclude}})
    end
  end

  if include[3] then
    table.insert(output, {includeFilter, {includeSpellIDs = include[3]}})
  end

  return output
end

function addonTable.Display.AurasManagerNextMixin:InitializeWidgets(parent, auraDetails)
  self.buffs:ClearAllPoints()
  self.debuffs:ClearAllPoints()
  self.crowdControl:ClearAllPoints()

  self.buffs.details = auraDetails.buffs
  self.debuffs.details = auraDetails.debuffs
  self.crowdControl.details = auraDetails.crowdControl

  self.buffs:Hide()
  self.buffs:SetParent(parent.BuffDisplay)
  self.debuffs:Hide()
  self.debuffs:SetParent(parent.DebuffDisplay)
  self.crowdControl:Hide()
  self.crowdControl:SetParent(parent.CrowdControlDisplay)

  for kind, details in pairs(auraDetails) do
    local groups = self:GetFilters(kind, details)

    if not self[kind].groupsCount or self[kind].groupsCount < #groups then
      for i = self[kind].groupsCount and self[kind].groupsCount + 1 or 1, #groups do
        self[kind]:AddAuraGroup(tostring(i), "HELPFUL|HARMFUL", {initializeFrame = GetAurasInitializerModern(self[kind])})
      end
      self[kind].groupsCount = #groups
    end

    self[kind]:SetScale(details.scale)
    self[kind]:SetPoint(directionMap[details.direction])
    self[kind]:SetFlowLayoutAnchorPoint(anchorMap[details.direction])

    local padding = PixelUtil.ConvertPixelsToUIForRegion(20 * details.padding, self[kind])

    for index, group in ipairs(groups) do
      local key = tostring(index)
      self[kind]:SetAuraGroupLayout(key, {elementSpacingX = padding, elementSpacingY = padding})
      self[kind]:SetAuraGroupFilterString(key, group[1])
      self[kind]:SetAuraGroupCandidateFilters(key, group[2])
      self[kind]:SetAuraGroupMaxFrameCount(key, details.limit)
    end

    if self[kind].groupsCount > #groups then
      for i = #groups + 1, self[kind].groupsCount do
        self[kind]:SetAuraGroupMaxFrameCount(tostring(i), 0)
      end
    end

    if not addonTable.Utilities.IsChangesRestricted() then
      for _, f in ipairs(self[kind].frames) do
        StyleAura(f, details)
      end
    end

    if details.direction == "LEFT" then
      self[kind]:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Left, AnchorUtil.FlowDirection.Up)
    else
      self[kind]:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Up)
    end

    self[kind]:Show()
  end
end

function addonTable.Display.AurasManagerNextMixin:SetUnit(unit, parent, auraDetails)
  if not unit then
    self.buffs:SetEnabled(false)
    self.debuffs:SetEnabled(false)
    self.crowdControl:SetEnabled(false)
    return
  end

  self.buffs:SetEnabled(true)
  self.debuffs:SetEnabled(true)
  self.crowdControl:SetEnabled(true)

  self.auraDetails = auraDetails

  self.buffs:SetUnit(unit)
  self.debuffs:SetUnit(unit)
  self.crowdControl:SetUnit(unit)
end
