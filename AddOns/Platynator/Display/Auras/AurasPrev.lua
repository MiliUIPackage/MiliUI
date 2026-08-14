---@class addonTablePlatynator
local addonTable = select(2, ...)

local auraFormatter, _auraPlainFormatter = addonTable.Display.Utilities.GetAuraNumericFormatter()

local LSM = LibStub("LibSharedMedia-3.0")

local pandemicPercentage = 0.3
local dispelColorMap = {
  ["Magic"] = CreateColorFromHexString("ff007ffb"),
  ["Curse"] = CreateColorFromHexString("ffb534ed"),
  ["Disease"] = CreateColorFromHexString("fffc982f"),
  ["Poison"] = CreateColorFromHexString("ffe5fb00"),
  [""] = CreateColorFromHexString("ffff0000"),
  ["Bleed"] = CreateColorFromHexString("fffc0318"),
}

local function GetAurasPoolLegacy(self)
  local borderAsset = LSM:Fetch("nineslice", "Platy: 1px")
  local dispelAsset = LSM:Fetch("nineslice", "Platy: 4px")
  return CreateFramePool("Frame", self, "PlatynatorNameplateBuffButtonTemplate", nil, false, function(frame)
    frame.Border = frame:CreateTexture(nil, "OVERLAY")
    frame.Border:SetAllPoints(true)
    frame.Border:SetScale(borderAsset.scaleModifier)
    frame.Border:SetTexture(borderAsset.file)
    frame.Border:SetTextureSliceMargins(borderAsset.margins.left, borderAsset.margins.top, borderAsset.margins.right, borderAsset.margins.bottom)
    frame.Border:SetVertexColor(0, 0, 0)
    frame.Cooldown.Text = frame.Cooldown:GetRegions()
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
      frame.Pandemic.Animation:Play()
      function frame.Pandemic:SetVertexColor(...)
        frame.Pandemic.Top:SetVertexColor(...)
        frame.Pandemic.Bottom:SetVertexColor(...)
        frame.Pandemic.Left:SetVertexColor(...)
        frame.Pandemic.Right:SetVertexColor(...)
      end
    end
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
    frame:SetScript("OnEnter", function()
      GameTooltip_SetDefaultAnchor(GameTooltip, frame)
      if GameTooltip.SetUnitAuraByAuraInstanceID then
        GameTooltip:SetUnitAuraByAuraInstanceID(self.unit, frame.auraInstanceID)
      elseif frame.auraIndex then
        if frame.auraIndex ~= -1 then
          GameTooltip:SetUnitAura(self.unit, frame.auraIndex, frame.auraFilter)
          GameTooltip:Show()
        end
      else
        local index = 1
        while true do
          local aura = C_UnitAuras.GetAuraDataByIndex(self.unit, index, frame.auraFilter)
          if not aura then
            break
          end
          if aura.auraInstanceID == frame.auraInstanceID then
            frame.auraIndex = index
            break
          end
          index = index + 1
        end

        if frame.auraIndex then
          GameTooltip:SetUnitAura(self.unit, frame.auraIndex, frame.auraFilter)
          GameTooltip:Show()
        else
          frame.auraIndex = -1
        end
      end
    end)
    frame:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
  end)
end

local function StyleAura(auraFrame, details)
  auraFrame.kind = details.kind

  auraFrame:EnableMouseMotion(details.showTooltips)

  auraFrame.CountFrame.Count:SetFontObject(addonTable.CurrentFont)
  auraFrame.CountFrame.Count:ClearAllPoints()
  addonTable.Display.ApplyAnchor(auraFrame.CountFrame.Count, details.texts.stacks.anchor, addonTable.CurrentFontUsesSmoothing and 1/details.texts.stacks.scale or 1)
  if addonTable.CurrentFontUsesSmoothing then
    auraFrame.CountFrame.Count:SetTextScale(1)
    auraFrame.CountFrame.Count:SetScale(details.texts.stacks.scale)
  else
    auraFrame.CountFrame.Count:SetTextScale(details.texts.stacks.scale)
    auraFrame.CountFrame.Count:SetScale(1)
  end
  local c1 = details.texts.stacks.color
  auraFrame.CountFrame.Count:SetTextColor(c1.r, c1.g, c1.b)
  auraFrame.CountFrame.Count:SetShown(details.texts.stacks.visible);

  auraFrame.Cooldown:SetHideCountdownNumbers(not details.texts.countdown.visible)

  if details.texts.countdown.visible then
    auraFrame.Cooldown.Text:SetFontObject(addonTable.CurrentFont)
    auraFrame.Cooldown.Text:ClearAllPoints()
    addonTable.Display.ApplyAnchor(auraFrame.Cooldown.Text, details.texts.countdown.anchor, addonTable.CurrentFontUsesSmoothing and 1/details.texts.countdown.scale or 1)
    if addonTable.CurrentFontUsesSmoothing then
      auraFrame.Cooldown.Text:SetTextScale(1)
      auraFrame.Cooldown.Text:SetScale(details.texts.countdown.scale)
    else
      auraFrame.Cooldown.Text:SetTextScale(details.texts.countdown.scale)
      auraFrame.Cooldown.Text:SetScale(1)
    end
    local c2 = details.texts.countdown.color
    auraFrame.Cooldown.Text:SetTextColor(c2.r, c2.g, c2.b)
    if addonTable.Constants.IsCooldownFormattingAvailable then
      if details.texts.countdown.showFractions then
        auraFrame.Cooldown:SetCountdownFormatter(auraFormatter)
      else
        auraFrame.Cooldown:SetCountdownFormatter(nil)
        auraFrame.Cooldown:SetCountdownAbbrevThreshold(20)
      end
    end
  end

  if auraFrame.CountFrame.Count.SetSmoothScaling then
    auraFrame.CountFrame.Count:SetSmoothScaling(addonTable.CurrentFontUsesSmoothing)
    auraFrame.Cooldown.Text:SetSmoothScaling(addonTable.CurrentFontUsesSmoothing)
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

function addonTable.Display.SetupLegacyAuras(self)
  self.AurasPools = {
    buffs = GetAurasPoolLegacy(self),
    debuffs = GetAurasPoolLegacy(self),
    crowdControl = GetAurasPoolLegacy(self),
  }
  self.AurasManager = addonTable.Utilities.InitFrameWithMixin(self, addonTable.Display.AurasManagerMixin)

  local function GetCallback(frame)
    local pool = self.AurasPools[frame:GetParent().kind]
    return function(data, auraFilter)
      if frame.items then
        for _, item in ipairs(frame.items) do
          pool:Release(item)
        end
        frame.items = nil
      end

      if not frame:GetParent():IsShown() then
        return
      end

      local pandemicDim = PixelUtil.ConvertPixelsToUIForRegion(1, frame)

      local details = frame:GetParent().details
      local step = PixelUtil.ConvertPixelsToUIForRegion(20 * (1 + details.padding), frame)
      local currentX = 0
      local currentY = 0
      local xOffset = 0
      local yOffset = 0
      if details.direction == "LEFT" then
        xOffset = -step
      elseif details.direction == "RIGHT" then
        xOffset = step
      else -- CENTER
        xOffset = step
        currentX = -(math.min(#data, details.limit) - 1) * step / 2
      end
      local anchor = details.anchor[1]
      if type(anchor) ~= "string" then
        anchor = "CENTER"
      end

      frame.items = {}
      for index, auraInstanceID in ipairs(data) do
        if index > details.limit then
          break
        end

        local aura = self.AurasManager:GetByInstanceID(auraInstanceID)
        local auraFrame = pool:Acquire()
        table.insert(frame.items, auraFrame)
        auraFrame:SetParent(frame)

        auraFrame.auraInstanceID = auraInstanceID
        auraFrame.auraIndex = nil
        auraFrame.auraFilter = auraFilter
        auraFrame.duration = aura.duration
        auraFrame.expirationTime = aura.expirationTime

        auraFrame.Icon:SetTexture(aura.icon);
        auraFrame.CountFrame.Count:SetText(aura.applicationsString)

        if auraFrame.styleIndex ~= self.styleIndex then
          auraFrame.styleIndex = self.styleIndex
          StyleAura(auraFrame, details)
          if details.showStealable then
            auraFrame.Pandemic:SetVertexColor(1, 171/255, 26/255)
          elseif details.showPandemic then
            auraFrame.Pandemic:SetVertexColor(1, 1, 1)
          end

          auraFrame.Pandemic:SetShown(details.showPandemic or details.showStealable)
          if auraFrame.Pandemic:IsShown() then
            auraFrame.Pandemic.Top:SetHeight(pandemicDim)
            auraFrame.Pandemic.Bottom:SetHeight(pandemicDim)
            auraFrame.Pandemic.Left:SetWidth(pandemicDim)
            auraFrame.Pandemic.Right:SetWidth(pandemicDim)
          end
        end

        if auraFrame.expirationTime then
          CooldownFrame_Set(auraFrame.Cooldown, aura.expirationTime - aura.duration, aura.duration, aura.duration > 0, true);
          if details.showPandemic then
            auraFrame.Pandemic:SetAlpha(aura.duration > 0 and aura.expirationTime - GetTime() <= aura.duration * pandemicPercentage and 1 or 0)
          end
          if details.showType then
            local color = dispelColorMap[aura.dispelName]
            if color then
              auraFrame.Dispel:SetAlpha(1)
              auraFrame.Dispel.Border:SetVertexColor(color.r, color.g, color.b)
            else
              auraFrame.Dispel:SetAlpha(0)
            end
          end
          if details.showStealable then
            auraFrame.Pandemic:SetShown(aura.isStealable)
          end
        else
          auraFrame.Cooldown:Clear()
          auraFrame.Pandemic:SetAlpha(0)
          auraFrame.Dispel:SetAlpha(0)
        end

        auraFrame:Show();

        PixelUtil.SetPoint(auraFrame, anchor, frame, anchor, currentX, currentY)
        currentX = currentX + xOffset
      end
    end
  end

  self.BuffDisplay.Wrapped = CreateFrame("Frame", nil, self.BuffDisplay)
  self.BuffDisplay.Wrapped:SetSize(10, 10)
  self.BuffDisplay.kind = "buffs"
  self.DebuffDisplay.Wrapped = CreateFrame("Frame", nil, self.DebuffDisplay)
  self.DebuffDisplay.Wrapped:SetSize(10, 10)
  self.DebuffDisplay.kind = "debuffs"
  self.CrowdControlDisplay.Wrapped = CreateFrame("Frame", nil, self.CrowdControlDisplay)
  self.CrowdControlDisplay.Wrapped:SetSize(10, 10)
  self.CrowdControlDisplay.kind = "crowdControl"

  self.AurasManager:SetDebuffsCallback(GetCallback(self.DebuffDisplay.Wrapped))
  self.AurasManager:SetBuffsCallback(GetCallback(self.BuffDisplay.Wrapped))
  self.AurasManager:SetCrowdControlCallback(GetCallback(self.CrowdControlDisplay.Wrapped))
end

function addonTable.Display:InitializeLegacyAurasWrappedAnchors(designInfo)
  if designInfo.debuffs then
    if self.DebuffDisplay.Wrapped then
      self.DebuffDisplay.Wrapped:ClearAllPoints()
      self.DebuffDisplay.Wrapped:SetPoint(designInfo.debuffs.anchor[1] or "CENTER")
      self.DebuffDisplay.Wrapped:SetScale(designInfo.debuffs.scale)
    end
  end

  if designInfo.buffs then
    if self.BuffDisplay.Wrapped then
      self.BuffDisplay.Wrapped:ClearAllPoints()
      self.BuffDisplay.Wrapped:SetScale(designInfo.buffs.scale)
      self.BuffDisplay.Wrapped:SetPoint(designInfo.buffs.anchor[1] or "CENTER")
    end
  end

  if designInfo.crowdControl then
    if self.CrowdControlDisplay.Wrapped then
      self.CrowdControlDisplay.Wrapped:ClearAllPoints()
      self.CrowdControlDisplay.Wrapped:SetScale(designInfo.crowdControl.scale)
      self.CrowdControlDisplay.Wrapped:SetPoint(designInfo.crowdControl.anchor[1] or "CENTER")
    end
  end
end

function addonTable.Display.InitializeWidgetsLegacyAuras(self, designInfo)
  addonTable.Display.InitializeLegacyAurasWrappedAnchors(self, designInfo)
  self.AurasManager:PostInit(designInfo.buffs, designInfo.debuffs, designInfo.crowdControl)

  self.BuffDisplay.enabled = designInfo.buffs ~= nil
  self.BuffDisplay.details = designInfo.buffs
  self.DebuffDisplay.enabled = designInfo.debuffs ~= nil
  self.DebuffDisplay.details = designInfo.debuffs
  self.CrowdControlDisplay.enabled = designInfo.crowdControl ~= nil
  self.CrowdControlDisplay.details = designInfo.crowdControl
end

function addonTable.Display.SetUnitUpdateLegacyAuras(self, unit)
  self.BuffDisplay:SetShown(unit and self.BuffDisplay.enabled)
  self.DebuffDisplay:SetShown(unit and self.DebuffDisplay.enabled)
  self.CrowdControlDisplay:SetShown(unit and self.CrowdControlDisplay.enabled)
end
