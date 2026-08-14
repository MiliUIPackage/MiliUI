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
    frame:SetAuraBorder(frame.Dispel.Border, {showIcon = false, showWhenHarmful = true, showWhenHelpful = true, style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset})

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

  self.initialSetup = true

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
  local includeFilter
  if kind == "buffs" then
    includeFilter = "HELPFUL|PLAYER"
  elseif kind == "debuffs" then
    includeFilter = settings.fromYou and "HARMFUL|PLAYER" or "HARMFUL"
  elseif kind == "crowdControl" then
    includeFilter = settings.fromYou and "HARMFUL|PLAYER" or "HARMFUL"
  end
  local start, tail = 0, 0
  for i = 1, 2 do
    if include[i] then
      start = start + 1
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
    tail = tail + 1
  end

  return output, start, tail
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

  self.buffs:SetEnabled(false)
  self.debuffs:SetEnabled(false)
  self.crowdControl:SetEnabled(false)

  for kind, details in pairs(auraDetails) do
    local groups, start, tail = self:GetFilters(kind, details)

    self[kind].groupLiveCount = #groups
    self[kind].manualStart = start
    self[kind].manualTail = tail

    if not self[kind].groupsCount or self[kind].groupsCount < #groups then
      for i = self[kind].groupsCount and self[kind].groupsCount + 1 or 1, #groups do
        self[kind]:AddAuraGroup(tostring(i), "", {initializeFrame = GetAurasInitializerModern(self[kind])})
      end
      self[kind].groupsCount = #groups
    end

    self[kind]:SetScale(details.scale)
    self[kind]:SetPoint(directionMap[details.direction])
    self[kind]:SetFlowLayoutAnchorPoint(anchorMap[details.direction])

    local padding = PixelUtil.ConvertPixelsToUIForRegion(20 * details.padding, self[kind])

    for index, group in ipairs(groups) do
      local key = tostring(index)
      self[kind]:SetAuraGroupFilterString(key, group[1])
      self[kind]:SetAuraGroupLayout(key, {elementSpacing = padding, lineSpacing = padding})
      self[kind]:SetAuraGroupCandidateFilters(key, group[2])
      self[kind]:SetAuraGroupMaxFrameCount(key, details.limit)
    end

    if self[kind].groupsCount > #groups then
      for i = #groups + 1, self[kind].groupsCount do
        self[kind]:SetAuraGroupMaxFrameCount(tostring(i), 0)
      end
    end

    if not addonTable.Utilities.IsChangesRestricted() and not self.initialSetup then
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

  self.initialSetup = false
end

local function ApplyStartTailCount(auras, count)
  if auras.manualStart > 0 then
    for i = 1, auras.manualStart do
      auras:SetAuraGroupMaxFrameCount(tostring(i), count)
    end
  end
  if auras.manualTail > 0 then
    for i = auras.groupLiveCount, auras.groupLiveCount - auras.manualTail do
      auras:SetAuraGroupMaxFrameCount(tostring(i), count)
    end
  end
end

function addonTable.Display.AurasManagerNextMixin:SetUnit(unit, parent, auraDetails)
  if not unit then
    self.buffs:SetEnabled(false)
    self.debuffs:SetEnabled(false)
    self.crowdControl:SetEnabled(false)
    return
  end

  if UnitCanAssist("player", unit) then
    if self.debuffs.details then
      ApplyStartTailCount(self.debuffs, 0)
    end
    if self.crowdControl.details then
      ApplyStartTailCount(self.crowdControl, 0)
    end
    if self.buffs.details then
      ApplyStartTailCount(self.buffs, self.buffs.details.limit)
      self.buffs:SetAuraGroupMaxFrameCount(tostring(self.buffs.manualStart + 1), self.buffs.details.limit)
      for i = self.buffs.manualStart + 2, self.buffs.groupLiveCount - self.buffs.manualTail do
        self.buffs:SetAuraGroupMaxFrameCount(tostring(i), 0)
      end
    end
  else
    if self.debuffs.details then
      ApplyStartTailCount(self.debuffs, self.debuffs.details.limit)
    end
    if self.crowdControl.details then
      ApplyStartTailCount(self.crowdControl, self.crowdControl.details.limit)
    end
    if self.buffs.details then
      ApplyStartTailCount(self.buffs, 0)
      self.buffs:SetAuraGroupMaxFrameCount(tostring(self.buffs.manualStart + 1), 0)
      for i = self.buffs.manualStart + 2, self.buffs.groupLiveCount - self.buffs.manualTail do
        self.buffs:SetAuraGroupMaxFrameCount(tostring(i), self.buffs.details.limit)
      end
    end
  end

  self.buffs:SetEnabled(self.debuffs.details ~= nil and (not UnitTreatAsPlayerForDisplay(unit) or not addonTable.Display.Utilities.IsInRelevantInstance({delve = true})))
  self.debuffs:SetEnabled(self.buffs.details ~= nil)
  self.crowdControl:SetEnabled(self.crowdControl.details ~= nil)

  self.auraDetails = auraDetails

  self.buffs:SetUnit(unit)
  self.debuffs:SetUnit(unit)
  self.crowdControl:SetUnit(unit)
end
