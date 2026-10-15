---@class addonTablePlatynator
local addonTable = select(2, ...)

local LSM = LibStub("LibSharedMedia-3.0")

local auraFormatter, auraPlainFormatter = addonTable.Display.Utilities.GetAuraNumericFormatter()

function addonTable.Display.GeneratePandemicAnimation(frame)
  frame.Pandemic = CreateFrame("Frame", nil, frame)
  frame.Pandemic:SetAllPoints()
  frame.Pandemic.Animation = frame.Pandemic:CreateAnimationGroup()
  frame.Pandemic:SetFrameLevel(frame.Cooldown:GetFrameLevel() + 5)
  do
    frame.Pandemic.Top = frame.Pandemic:CreateTexture()
    frame.Pandemic.Top:SetPoint("TOPLEFT")
    frame.Pandemic.Top:SetPoint("TOPRIGHT")
    frame.Pandemic.Top:SetTexture("Interface/AddOns/Platynator/Assets/Special/pandemic.png")
    frame.Pandemic.Bottom = frame.Pandemic:CreateTexture()
    frame.Pandemic.Bottom:SetPoint("BOTTOMLEFT")
    frame.Pandemic.Bottom:SetPoint("BOTTOMRIGHT")
    frame.Pandemic.Bottom:SetTexture("Interface/AddOns/Platynator/Assets/Special/pandemic.png")
    frame.Pandemic.Bottom:SetRotation(math.pi)
    frame.Pandemic.Left = frame.Pandemic:CreateTexture()
    frame.Pandemic.Left:SetPoint("TOPLEFT")
    frame.Pandemic.Left:SetPoint("BOTTOMLEFT")
    frame.Pandemic.Left:SetTexture("Interface/AddOns/Platynator/Assets/Special/pandemic-90.png")
    frame.Pandemic.Right = frame.Pandemic:CreateTexture()
    frame.Pandemic.Right:SetPoint("TOPRIGHT")
    frame.Pandemic.Right:SetPoint("BOTTOMRIGHT")
    frame.Pandemic.Right:SetTexture("Interface/AddOns/Platynator/Assets/Special/pandemic-90.png")
    frame.Pandemic.Right:SetRotation(math.pi)

    local pandemicDim = 1
    frame.Pandemic.Top:SetHeight(pandemicDim)
    frame.Pandemic.Bottom:SetHeight(pandemicDim)
    frame.Pandemic.Left:SetWidth(pandemicDim)
    frame.Pandemic.Right:SetWidth(pandemicDim)

    local fb = frame.Pandemic.Animation:CreateAnimation("Flipbook")
    fb:SetFlipBookColumns(1)
    fb:SetFlipBookRows(11)
    fb:SetDuration(0.5)
    fb:SetTarget(frame.Pandemic.Top)
    local fb = frame.Pandemic.Animation:CreateAnimation("Flipbook")
    fb:SetFlipBookColumns(1)
    fb:SetFlipBookRows(11)
    fb:SetDuration(0.5)
    fb:SetTarget(frame.Pandemic.Bottom)
    local fb = frame.Pandemic.Animation:CreateAnimation("Flipbook")
    fb:SetFlipBookColumns(11)
    fb:SetFlipBookRows(1)
    fb:SetDuration(0.5)
    fb:SetTarget(frame.Pandemic.Left)
    local fb = frame.Pandemic.Animation:CreateAnimation("Flipbook")
    fb:SetFlipBookColumns(11)
    fb:SetFlipBookRows(1)
    fb:SetDuration(0.5)
    fb:SetTarget(frame.Pandemic.Right)
    frame.Pandemic.Animation:SetLooping("REPEAT")
    frame.Pandemic.Animation:Stop()
    function frame.Pandemic:SetVertexColor(...)
      frame.Pandemic.Top:SetVertexColor(...)
      frame.Pandemic.Bottom:SetVertexColor(...)
      frame.Pandemic.Left:SetVertexColor(...)
      frame.Pandemic.Right:SetVertexColor(...)
    end
  end
end

local function StyleAura(auraFrame, details, container)
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

  auraFrame.TextsContainer.Applications:SetSmoothScaling(addonTable.CurrentFontUsesSmoothing)
  auraFrame.TextsContainer.Countdown:SetSmoothScaling(addonTable.CurrentFontUsesSmoothing)

  auraFrame.Cooldown:SetDrawEdge(details.showSwipe)
  auraFrame.Cooldown:SetDrawSwipe(details.showSwipe)

  local width = PixelUtil.ConvertPixelsToUIForRegion(20, container)
  local height = PixelUtil.ConvertPixelsToUIForRegion(20 * details.height, container)
  auraFrame:SetSize(width, height)
  auraFrame.Border:SetSize(width, height)
  auraFrame.Icon:SetSize(width, height)
  local texBase = 0.95 * (1 - details.height) / 2
  auraFrame.Icon:SetTexCoord(0.05, 0.95, 0.05 + texBase, 0.95 - texBase)

  if addonTable.Constants.IsMidnightNext or addonTable.Constants.IsForever then
    auraFrame:ClearPandemicActiveAnimations()
    auraFrame:ClearPandemicRegions()
    auraFrame.Pandemic:SetShown(details.showPandemic)
    if details.showPandemic then
      auraFrame:AddPandemicRegion(auraFrame.Pandemic.Top)
      auraFrame:AddPandemicRegion(auraFrame.Pandemic.Left)
      auraFrame:AddPandemicRegion(auraFrame.Pandemic.Right)
      auraFrame:AddPandemicRegion(auraFrame.Pandemic.Bottom)
      auraFrame:AddPandemicActiveAnimation(auraFrame.Pandemic.Animation)
    end
  end

  auraFrame.Dispel:SetShown(details.showType)
end

local function GetAurasInitializerModern(container)
  local borderAsset = LSM:Fetch("nineslice", "Platy: 1px")
  local dispelAsset = LSM:Fetch("nineslice", "Platy: 4px")
  return function(frame)
    table.insert(container.frames, frame)
    frame:SetFlattensRenderLayers(true)
    frame.Icon = frame:CreateTexture(nil, "ARTWORK")
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

    if addonTable.Constants.IsMidnightNext or addonTable.Constants.IsForever then
      addonTable.Display.GeneratePandemicAnimation(frame)
      PixelUtil.SetRoundLayoutToNearestPixelRecursively(frame.Pandemic, true)
    end

    frame:SetApplicationCount(frame.TextsContainer.Applications, {})
    frame:SetIcon(frame.Icon)
    frame:SetDurationCooldown(frame.Cooldown)
    frame:AddDispelTypeTexture(frame.Dispel.Border, {showIcon = false, showWhenHarmful = true, showWhenHelpful = true, style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset})

    if container.details then
      StyleAura(frame, container.details, container)
    end
  end
end

addonTable.Display.AurasManagerNextMixin = {}

function addonTable.Display.AurasManagerNextMixin:OnLoad()
  self.buffs = CreateFrame("AuraContainer", nil, self, "CustomAuraContainerTemplate")
  self.debuffs = CreateFrame("AuraContainer", nil, self, "CustomAuraContainerTemplate")
  self.crowdControl = CreateFrame("AuraContainer", nil, self, "CustomAuraContainerTemplate")

  self.slots = CreateFrame("AuraContainer", nil, self, "CustomAuraContainerTemplate")

  self.buffs:SetEnabled(false)
  self.debuffs:SetEnabled(false)
  self.crowdControl:SetEnabled(false)
  self.slots:SetEnabled(false)

  self.initialSetup = true

  self.crowdControl.frames = {}
  self.buffs.frames = {}
  self.debuffs.frames = {}
  self.slots.framesByKey = {}
  self.slots.occupied = 0
  self.slots.available = 0

  addonTable.CallbackRegistry:RegisterCallback("SpecializationChanged", function()
    if not self.initialSetup then
      self:InitializeWidgets(self.parent, self.auraDetails, true)
      if self.unit then
        self:SetUnit(self.unit)
      end
    end
  end, self)
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
  local settings
  if kind == "crowdControl" then
    settings = addonTable.Config.Get(addonTable.Config.Options.AURA_FILTERS).crowdControl
  else
    settings = addonTable.Config.Get(addonTable.Config.Options.AURA_FILTERS)[addonTable.Display.Utilities.GetSpecializationID()][kind]
  end

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

local _, class = UnitClass("player")

-- MiliUI: lazy aura groups (local change, re-apply after upstream updates; see
-- .claude/notes/project-local-addon-forks.md).
-- Every AddAuraGroup makes Blizzard pre-build a batch of 10 aura buttons that can never
-- be freed, and the manager pre-allocates 40 displays per style -- 40 x ~7 groups x 10
-- buttons (~2800 buttons, ~250 MB of Lua heap measured 2026-09-27) before a single plate
-- is shown. Only the first PREWARM_SLOTS displays of each style declare their groups up
-- front (nameplate indices are handed out low-first); the rest declare them the first
-- time they get a unit.
local PREWARM_SLOTS = 16

local function ApplyGroups(container, details, groups, allowCreate)
  if allowCreate and (not container.groupsCount or container.groupsCount < #groups) then
    for i = container.groupsCount and container.groupsCount + 1 or 1, #groups do
      container:AddAuraGroup(tostring(i), "", {initializeFrame = GetAurasInitializerModern(container)})
    end
    container.groupsCount = #groups
  end
  local have = container.groupsCount or 0
  container.pendingGroups = have < #groups and groups or nil

  local padding = PixelUtil.ConvertPixelsToUIForRegion(20 * details.padding, container)

  for index, group in ipairs(groups) do
    if index > have then break end
    local key = tostring(index)
    container:SetAuraGroupFilterString(key, group[1])
    container:SetAuraGroupLayout(key, {elementSpacing = padding, lineSpacing = padding})
    container:SetAuraGroupCandidateFilters(key, group[2])
    container:SetAuraGroupMaxFrameCount(key, details.limit)
  end

  if have > #groups then
    for i = #groups + 1, have do
      container:SetAuraGroupMaxFrameCount(tostring(i), 0)
    end
  end
end

function addonTable.Display.AurasManagerNextMixin:GetFilters(kind, settings)
  local output = table.create(6)
  local include, exclude = ProcessSpells(kind)
  local includeFilter
  if kind == "buffs" then
    includeFilter = settings.filters.playerFromYou and "HELPFUL|PLAYER" or "HELPFUL"
  elseif kind == "debuffs" then
    includeFilter = settings.filters.fromYou and "HARMFUL|PLAYER" or "HARMFUL"
  elseif kind == "crowdControl" then
    includeFilter = settings.filters.fromYou and "HARMFUL|PLAYER" or "HARMFUL"
  end
  local start, tail, deduplicate = 0, 0, 0
  for i = 1, 2 do
    if include[i] then
      start = start + 1
      table.insert(output, {includeFilter, {includeSpellIDs = include[i]}})
    end
  end

  local deduplicateAllClasses = addonTable.Config.Get(addonTable.Config.Options.AURA_DEDUPLICATE)
  if kind == "debuffs" and deduplicateAllClasses[class] then
    for _, spellID in ipairs(deduplicateAllClasses[class]) do
      if not exclude[spellID] then
        deduplicate = deduplicate + 1
        exclude[spellID] = true
        table.insert(output, {includeFilter, {includeSpellIDs = {[spellID] = true}}})
      end
    end
  end

  if kind == "buffs" then
    local maxDuration = 300
    if settings.filters.showLongDurations then
      maxDuration = nil
    end
    local dispelTypes = nil
    if settings.filters.enrage or settings.filters.magic then
      dispelTypes = {}
      if settings.filters.enrage then
        dispelTypes["Enrage"] = true
      end
      if settings.filters.magic then
        dispelTypes["Magic"] = true
      end
    end

    table.insert(output, {"HELPFUL|PLAYER", {excludeSpellIDs = exclude, maxDuration = maxDuration}})
    if settings.filters.defensive then
      table.insert(output, {"HELPFUL|BIG_DEFENSIVE|!PLAYER", {excludeSpellIDs = exclude, maxDuration = maxDuration}})
      table.insert(output, {"HELPFUL|EXTERNAL_DEFENSIVE|!BIG_DEFENSIVE|!PLAYER", {excludeSpellIDs = exclude, maxDuration = maxDuration}})
      table.insert(output, {"HELPFUL|RAID_IN_COMBAT|!EXTERNAL_DEFENSIVE|!BIG_DEFENSIVE|!PLAYER", {excludeSpellIDs = exclude, maxDuration = maxDuration}})
    elseif settings.filters.important then
      table.insert(output, {"HELPFUL|!PLAYER", {excludeSpellIDs = exclude, isBossOrRoleAura = true, isFromPlayerOrPlayerPet = false, maxDuration = maxDuration}})
      table.insert(output, {"HELPFUL|IMPORTANT|!PLAYER", {excludeSpellIDs = exclude, isBossOrRoleAura = false, maxDuration = maxDuration}})
      if dispelTypes then
        table.insert(output, {"HELPFUL|!IMPORTANT|!PLAYER", {
          includeDispelTypes = dispelTypes,
          excludeSpellIDs = exclude,
          isBossOrRoleAura = false,
        }})
      end
      if settings.filters.dispellable then
        table.insert(output, {"HELPFUL|!IMPORTANT|!PLAYER", {excludeSpellIDs = exclude, excludeDispelTypes = dispelTypes, isStealable = true, maxDuration = maxDuration}})
      end
    else
      if settings.filters.dispellable or settings.filters.enrage or settings.filters.magic then
        if dispelTypes then
          table.insert(output, {"HELPFUL|!PLAYER", {excludeSpellIDs = exclude, includeDispelTypes = dispelTypes, maxDuration = maxDuration}})
        end
        if settings.filters.dispellable then
          table.insert(output, {"HELPFUL|!PLAYER", {excludeSpellIDs = exclude, isStealable = true, excludeDispelTypes = dispelTypes, maxDuration = maxDuration}})
        end
      else
        table.insert(output, {"HELPFUL|!PLAYER", {excludeSpellIDs = exclude}, maxDuration = maxDuration})
      end
    end
  elseif kind == "debuffs" then
    local playerFilter = ""
    if settings.filters.fromYou then
      playerFilter = "|PLAYER"
    end
    local nameplateShowAll = nil
    if not settings.filters.includeExtras then
      nameplateShowAll = false
    end
    if settings.filters.important then
      table.insert(output, {"HARMFUL|IMPORTANT|!CROWD_CONTROL" .. playerFilter, {excludeSpellIDs = exclude, nameplateShowAll = nameplateShowAll}})
      table.insert(output, {"HARMFUL|!IMPORTANT|!CROWD_CONTROL" .. playerFilter, {excludeSpellIDs = exclude, nameplateShowAll = nameplateShowAll, nameplateShowPersonal = true}})
    else
      table.insert(output, {"HARMFUL|!CROWD_CONTROL" .. playerFilter, {excludeSpellIDs = exclude, nameplateShowAll = nameplateShowAll}})
    end
  elseif kind == "crowdControl" then
    if settings.filters.fromYou then
      table.insert(output, {"HARMFUL|CROWD_CONTROL|PLAYER", {excludeSpellIDs = exclude}})
      if settings.filters.includeExtras then
        table.insert(output, {"HARMFUL|!CROWD_CONTROL|PLAYER", {nameplateShowAll = true}})
      end
    else
      table.insert(output, {"HARMFUL|CROWD_CONTROL", {excludeSpellIDs = exclude}})
      if settings.filters.includeExtras then
        table.insert(output, {"HARMFUL|!CROWD_CONTROL", {nameplateShowAll = true}})
      end
    end
  end

  if include[3] then
    table.insert(output, {includeFilter, {includeSpellIDs = include[3]}})
    tail = tail + 1
  end

  return output, start, tail, deduplicate
end

function addonTable.Display.AurasManagerNextMixin:InitializeWidgets(parent, auraDetails, doNotSize)
  self.auraDetails = auraDetails
  self.parent = parent

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
  self.slots:SetEnabled(false)

  -- MiliUI: lazy aura groups
  self.buffs.pendingGroups, self.debuffs.pendingGroups, self.crowdControl.pendingGroups = nil, nil, nil
  local allowCreate = self.unit ~= nil or (parent.miliPoolSlot or 1) <= PREWARM_SLOTS

  for kind, details in pairs(auraDetails) do
    local groups, start, tail, deduplicate = self:GetFilters(kind, details)

    self[kind].groupLiveCount = #groups
    self[kind].manualStart = start
    self[kind].manualTail = tail
    self[kind].manualDeduplicate = deduplicate

    self[kind]:SetScale(details.scale)
    self[kind]:SetPoint(directionMap[details.direction])
    self[kind]:SetFlowLayoutAnchorPoint(anchorMap[details.direction])

    ApplyGroups(self[kind], details, groups, allowCreate) -- MiliUI: lazy aura groups

    if not addonTable.Utilities.IsChangesRestricted() and not self.initialSetup and not doNotSize then
      for _, f in ipairs(self[kind].frames) do
        StyleAura(f, details, self[kind])
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
  if auras.manualDeduplicate > 0 then
    for i = auras.manualStart + 1, auras.manualStart + auras.manualDeduplicate do
      auras:SetAuraGroupMaxFrameCount(tostring(i), count > 0 and 1 or 0)
    end
  end
end

function addonTable.Display.AurasManagerNextMixin:ReleaseSlots()
  if addonTable.Utilities.IsChangesRestricted() then
    return
  end

  if self.slots.occupied > 0 then
    for i = 1, self.slots.occupied do
      self.slots:SetAuraSlotFilterString(tostring(i), "")
    end
  end
end

function addonTable.Display.AurasManagerNextMixin:AcquireSlot(height, point, filterString, spellID)
  self.slots.occupied = self.slots.occupied + 1
  local key = tostring(self.slots.occupied)
  if self.slots.available >= self.slots.occupied then
    local frame = self.slots.framesByKey[key]
    if not addonTable.Utilities.IsChangesRestricted() then
      frame.height = height
      frame:SetHeight(height)
    end
    self.slots:SetAuraSlotEnabled(key, true)
    self.slots:SetAuraSlotFilterString(key, filterString)
    self.slots:SetAuraSlotCandidateFilters(key, {
      includeSpellIDs = {[spellID] = true}
    })
    return self.slots.framesByKey[key]
  end

  local frame = self.slots:AddAuraSlot(key, filterString, {initializeFrame = function(auraFrame)
    auraFrame.key = key
    auraFrame.height = height
    auraFrame:SetSize(20, height)
    auraFrame:SetPoint(unpack(point))
    auraFrame:SetCollapsesLayout(true)
  end, candidateFilters = { includeSpellIDs = {[spellID] = true} } })

  if frame.RoundLayoutToNearestPixel then
    frame:RoundLayoutToNearestPixel(true)
  end
  self.slots.framesByKey[key] = frame

  self.slots.available = self.slots.available + 1

  return frame
end

function addonTable.Display.AurasManagerNextMixin:SetUnit(unit)
  self.unit = unit
  if not unit then
    self.buffs:SetEnabled(false)
    self.debuffs:SetEnabled(false)
    self.crowdControl:SetEnabled(false)
    self.slots:SetEnabled(false)
    return
  end

  -- MiliUI: lazy aura groups -- first unit on a display that skipped them at pool build
  for _, container in ipairs({self.buffs, self.debuffs, self.crowdControl}) do
    if container.pendingGroups and container.details then
      ApplyGroups(container, container.details, container.pendingGroups, true)
    end
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

  self.buffs:SetUnit(unit)
  self.debuffs:SetUnit(unit)
  self.crowdControl:SetUnit(unit)
  self.slots:SetUnit(unit)

  self.buffs:SetEnabled(self.buffs.details ~= nil and (not UnitTreatAsPlayerForDisplay(unit) or not addonTable.Display.Utilities.IsInRelevantInstance({delve = true})))
  self.debuffs:SetEnabled(self.debuffs.details ~= nil)
  self.crowdControl:SetEnabled(self.crowdControl.details ~= nil)
  self.slots:SetEnabled(self.slots.occupied > 0)
end
