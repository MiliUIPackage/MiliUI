local addonName = ... ---@type string 'Falcon'
local ns = select(2,...) ---@class (partial) namespace
local F = ns.Flags
---@class (partial) Falcon
---@field Center table
---@field Label table
---@field Selection table
---@field shadow Texture
local Falcon = ns.Falcon
---@class FalconSettings : Frame
local FalconSettings = CreateFrame('frame')

local API = ns.API
local LEM = ns.LEM
local MutableData = ns.MutableData

---@class defaultPosition
---@field point FramePoint
---@field x number
---@field y number
---@field scale number
local defaultPosition = {
  point = 'BOTTOM',
  x = 0.5,
  y = 200,
  scale = 1,
}

---@class defaultTableData
---@field point FramePoint
---@field x number
---@field y number
---@field scale number
---@field TextPosition string
---@field hideWhenGroundedAndFull boolean
---@field noDisplayText boolean
local defaultTableData = {
  point = 'BOTTOM',
  x = 0.5,
  y = 200,
  scale = 1,
  Version = 1,
  TextPosition = 'RIGHT',
  InsideGlowColor = { r = 1, g = 1, b = 1, a = 0},
  BackgroundColor = { r = 0.2, g = 0.2, b = 0.2, a = 1},
  BorderColor = { r = 0, g = 0, b = 0, a = 1},
  ChargeColor = { r = 0.0, g = 0.67, b = 0.98, a = 1 },
  ShadowColor = { r = 0.0, g = 0.0, b = 0.0, a = 0.4 },
  CurrentStyle = 'Clean',
  CurrentTexture = { Name = 'Falcon Smooth', Texture = 'Interface\\AddOns\\Falcon\\Media\\Statusbar\\FalconSmooth.tga' },
  DefaultTexture = { Name = 'Falcon Smooth', Texture = 'Interface\\AddOns\\Falcon\\Media\\Statusbar\\FalconSmooth.tga' },
  hideWhenGroundedAndFull = false,
  mutedSoundsBitfield = 0,
  noDisplayText = false,
  secondWindMode = 1,
  SpeedColor = { r = 0.5490, g = 0.8118, b = 0.3882, a = 1 },
  whirlingSurgeMode = 0,
  whirlingSurgeState = 1,
  BarBehaviourFlags = 0,
  Styles = {
    Clean = {
      ChargeHeight = 14,
      Padding = 0,
      SpeedHeight = 14,
      SwapPositions = false,
      Width = 36,
    }
  }
}
ns.defaultTableData = defaultTableData

local LibSharedMedia = LibStub('LibSharedMedia-3.0')

ns.SharedMediaTextures = {
  { Name = 'Falcon Light', Texture = 'Interface\\AddOns\\Falcon\\Media\\Statusbar\\FalconLight.tga' },
  { Name = 'Falcon Shaded', Texture = 'Interface\\AddOns\\Falcon\\Media\\Statusbar\\FalconShaded.tga' },
  { Name = 'Falcon Smooth', Texture = 'Interface\\AddOns\\Falcon\\Media\\Statusbar\\FalconSmooth.tga' },
}

ns.MediaNames = {}
if LibSharedMedia then
  for _, v in ipairs(ns.SharedMediaTextures) do
    ns.MediaNames[v.Name] = true
    LibSharedMedia:Register('statusbar', v.Name, v.Texture)
  end
end

local SECOND_WIND_OPTIONS_LIST = {
  { id = 0, state = 'Disabled' },
  { id = 1, state = 'Integrated' },
}

local barBehaviourRequirementMask = bit.bor(F.BarBehaviour.HIDE_CHARGES, F.BarBehaviour.HIDE_SPEED)

local BARBEHAVIOUR_OPTION_LIST = {
  { id = F.BarBehaviour.HIDE_CHARGES, state = 'Hide Charges' },
  { id = F.BarBehaviour.HIDE_SPEED, state = 'Hide Speed' },
  { id = F.BarBehaviour.HIDE_GROUNDED, state = 'Hide when grounded', requirementMask = barBehaviourRequirementMask },
  { id = F.BarBehaviour.HIDE_FULL_GROUNDED, state = 'Hide when fully charged and grounded', requirementMask = barBehaviourRequirementMask },
}

-- To be added
local WHIRLING_SURGE_OPTIONS_SHOWNSTATE_LIST = {
  { id = 0, state = 'Disabled' },
  { id = 1, state = 'Show on Cooldown' },
  { id = 2, state = 'Hide on Cooldown' },
  { id = 3, state = 'Always Show' }
}

local sounds = {
  ['groundSkimming'] = { 1695571 },
  ['fastFlying'] =     { 1841696 },
  ['landingStomp'] = {
    1489050, 1489051, 1489052, 1489053,
  },
  ['skywardAscent'] = {
    840091, 840093, 840095, 840097, 840099, 840101, 840103, 564163
  },
  ['surgeForward'] = { 1378204 }, -- 1378204 is also Lift Off
  ['mountedWind'] = { 2066599 },
  ['flapping'] = { 564161, 564163, 564164, 564165, 564166, 564167, 564168, 564169, 564170, 564173},

  -- mounts
  ['renewedProtoDrake'] = {
    4634942, 4634944, 4634946,
  },
  ['windborneVelocidrake'] = {
    4663454, 4663456, 4663458, 4663460, 4663462, 4663464, 4663466,
  },
  ['highlandDrake'] = {
    4633280, 4633282, 4633284, 4633286, 4633288, 4633290,
    4641087, 4641089, 4641091, 4641093, 4641095, 4641097,
    4641099, 4633316, 4634009, 4634011, 4634013, 4634015,
    4634017, 4634019, 4634021,
  },
  ['windingSlitherdrake'] = {
    5163128, 5163130, 5163132, 5163134, 5163136, 5163138, 5163140,
  },
  ['algarianStormrider'] = {
    5357752, 5357769, 5357771, 5357773, 5357775, 5356559,
    5356561, 5356563, 5356565, 5356567, 5356569, 5356571,
    5356837, 5356839, 5356841, 5356843, 5356845, 5356847,
    5356849,
  },
  ['anurelosFlamesGuidance'] = {
    4683513, 4683515, 4683517, 4683519, 4683521, 4683523,
    4683525, 4683527, 4683529, 4683531, 4683533, 4683535,
    4683537, 4683539, 4683541, 4683543, 4683545, 4683547,
    4683549, 4683551, 5482244, 5482246, 5482248, 5482250,
    5482335, 5482337, 5482339, 5482341, 5482343, 5482345,
    5482347, 5482373, 5482375, 5482377, 5482379, 5482381,
    5482383, 5482385, 5482177, 5482179, 5482181,
  },
  ['grottoNetherwingDrake'] = {
    4633370, 4633372, 4633374, 4633376, 4633378, 4633380, 4633382,
  },
}

local SOUND_OPTIONS = {
  -- Order matters for Dropdown.
  { id = 2, name = 'Ground Skimming',              key = 'groundSkimming' },
  { id = 3, name = 'Surge Forward/Lift Off',       key = 'surgeForward' },
  { id = 4, name = 'Skyward Ascent',               key = 'skywardAscent' },
  { id = 5, name = 'Ground Landing Stomp',         key = 'landingStomp' },

  { id = 20, name = 'Algarian Stormrider', key = 'algarianStormrider', mountID = 1792},
  { id = 21, name = "Anu'relos, Flame's Guidance", key = 'anurelosFlamesGuidance', mountID = 1818 },
  { id = 22, name = 'Grotto Netherwing Drake', key = 'grottoNetherwingDrake', mountID = 1744 },
  { id = 23, name = 'Highland Drake', key = 'highlandDrake', mountID = 1563 },
  { id = 24, name = 'Renewed Proto-Drake', key = 'renewedProtoDrake', mountID = 1589 },
  { id = 25, name = 'Windborne Velocidrake', key = 'windborneVelocidrake', mountID = 1590 },
  { id = 26, name = 'Winding Slitherdrake', key = 'windingSlitherdrake', mountID = 1588 },
}

function FalconSettings:IsSoundChecked(id)
  local mask = bit.lshift(1, id - 1)
  return bit.band(FalconAddOnDB.Settings['FalconGlobalSettings'].mutedSoundsBitfield, mask) ~= 0
end

function FalconSettings:SetSoundChecked(id)
  local mask = bit.lshift(1, id - 1)
  local settings = FalconAddOnDB.Settings['FalconGlobalSettings']
  if self:IsSoundChecked(id) then
    settings.mutedSoundsBitfield = bit.bxor(settings.mutedSoundsBitfield, mask)
  else
    settings.mutedSoundsBitfield = bit.bor(settings.mutedSoundsBitfield, mask)
  end
  FalconSettings:ApplyMutedSoundsState()
end

function FalconSettings:ResetSounds()
  FalconAddOnDB.Settings['FalconGlobalSettings'].mutedSoundsBitfield = 0
  self:ApplyMutedSoundsState()
  FalconSettings.SoundsDropdown:GenerateMenu()
end

function FalconSettings:ApplyMutedSoundsState()
  for i, option in ipairs(SOUND_OPTIONS) do
    local soundKey = option.key
    if soundKey then
      local soundIDs = sounds[soundKey]

      if self:IsSoundChecked(option.id) then
        for _, soundID in ipairs(soundIDs) do
          MuteSoundFile(soundID)
        end
      else
        for _, soundID in ipairs(soundIDs) do
          UnmuteSoundFile(soundID)
        end
      end
    end
  end
end

---@param layoutName string
---@return string
function FalconSettings:GetCurrentLayoutName(layoutName, forceGlobal)
  if FalconAddOnDB.FalconGlobalSettingsEnabled or forceGlobal then
    return 'FalconGlobalSettings'
  end
  return layoutName
end

local function CancelPositionTicker()
  if Falcon.positionTicker then
    Falcon.positionTicker:Cancel()
  end
end

local function StartFixPosition()
  CancelPositionTicker()
  Falcon.positionTicker = C_Timer.NewTicker(0.1, function()
    API:FixPosition(Falcon)
  end, 1)
end

---@param target table
---@param default table
local function UpdateTable(target, default)
  for k, v in pairs(default) do
    if type(v) == 'table' then
      if type(target[k]) == 'table' then
        UpdateTable(target[k], v)
      else
        target[k] = v
      end
    elseif target[k] == nil then
      target[k] = v
    end
  end
end

---@param targetDB table
---@param key string
---@return table
local function EnsureSettings(targetDB, key)
  targetDB[key] = targetDB[key] or {}
  UpdateTable(targetDB[key], defaultTableData)
  return targetDB[key]
end

---@param layoutName string
function FalconSettings:SetupLayout(layoutName)
  FalconAddOnDB = FalconAddOnDB or {} ---@diagnostic disable-line
  FalconAddOnDB.Settings = FalconAddOnDB.Settings or {} ---@diagnostic disable-line
  FalconAddOnDB.FalconGlobalSettingsEnabled = FalconAddOnDB.FalconGlobalSettingsEnabled or false
  layoutName = self:GetCurrentLayoutName(layoutName)
  FalconAddOnDB.Settings[layoutName] = EnsureSettings(FalconAddOnDB.Settings, layoutName)
  FalconAddOnDB.Settings['FalconGlobalSettings'] = EnsureSettings(FalconAddOnDB.Settings, 'FalconGlobalSettings')
  ---@type defaultTableData
  local layout = FalconAddOnDB.Settings[layoutName]
  Falcon:ClearAllPoints()
  Falcon:SetPoint(layout.point, layout.x, layout.y)

  MutableData.hideWhenGroundedAndFull = layout.hideWhenGroundedAndFull
  MutableData.shadowColor = layout.ShadowColor
  MutableData.noDisplayText = layout.noDisplayText
  MutableData.chargeColor = layout.ChargeColor
  MutableData.speedColor = layout.SpeedColor
  MutableData.backgroundColor = layout.BackgroundColor
  MutableData.borderColor = layout.BorderColor
  MutableData.secondWindMode = FalconAddOnDB.Settings['FalconGlobalSettings'].secondWindMode
  MutableData.InsideGlowColor = layout.InsideGlowColor
  MutableData.whirlingSurgeState = layout.whirlingSurgeState
  local config = layout.Styles[layout.CurrentStyle]
  layout.CurrentTexture = layout.CurrentTexture or config.CurrentTexture or defaultTableData.DefaultTexture
  config.CurrentTexture = nil
  local texture = LibSharedMedia:Fetch('statusbar', layout.CurrentTexture.Name, true)
  if not texture then
    layout.CurrentTexture = defaultTableData.DefaultTexture
    texture = defaultTableData.DefaultTexture.Texture
  end
  layout.textPosition = nil -- Remove from existing tables.
  if layout.TextPosition == 'RIGHT' then
    Falcon.TextDisplay.Text:SetJustifyH('RIGHT')
  elseif layout.TextPosition == 'LEFT' then
    Falcon.TextDisplay.Text:SetJustifyH('LEFT')
  end
  Falcon.SpeedBar:SetStatusBarTexture(texture --[[@as Texture]])
  Falcon.SpeedBar:SetStatusBarColor(layout.SpeedColor.r, layout.SpeedColor.g, layout.SpeedColor.b, layout.SpeedColor.a)
  Falcon.SpeedBar.insideGlow:SetVertexColor(layout.InsideGlowColor.r, layout.InsideGlowColor.g, layout.InsideGlowColor.b, layout.InsideGlowColor.a)
  Falcon.SpeedBar.tick:SetColorTexture(layout.BorderColor.r, layout.BorderColor.g, layout.BorderColor.b, layout.BorderColor.a)
  Falcon.SpeedBarBG.outline:SetVertexColor(layout.BorderColor.r, layout.BorderColor.g, layout.BorderColor.b, layout.BorderColor.a)
  Falcon.SpeedBarBG.Background:SetTexture(texture)
  Falcon.SpeedBarBG.Background:SetVertexColor(layout.BackgroundColor.r, layout.BackgroundColor.g, layout.BackgroundColor.b, layout.BackgroundColor.a)
  Falcon.SpeedBarBG.shadow:SetVertexColor(layout.ShadowColor.r, layout.ShadowColor.g, layout.ShadowColor.b, layout.ShadowColor.a)
  Falcon.shadow:SetVertexColor(layout.ShadowColor.r, layout.ShadowColor.g, layout.ShadowColor.b, layout.ShadowColor.a)
  Falcon.ChargesParent.shadow:SetVertexColor(layout.ShadowColor.r, layout.ShadowColor.g, layout.ShadowColor.b, 0)
  Falcon.WhirlingSurge.outline:SetVertexColor(layout.BorderColor.r, layout.BorderColor.g, layout.BorderColor.b, layout.BorderColor.a)
  Falcon.WhirlingSurge.shadow:SetVertexColor(layout.ShadowColor.r, layout.ShadowColor.g, layout.ShadowColor.b, layout.ShadowColor.a)
  for i = 1, Falcon.num_charges do
    ---@class ChargeBar : StatusBar
    ---@field insideGlow Texture
    local chargeBar = Falcon.ChargeBars[i]
    ---@class ChargeBarBG
    ---@field outline Texture
    ---@field Background Texture
    ---@field shadow Texture
    local chargesBG = Falcon.ChargeBGs[i]
    local secondWindBar = Falcon.SecondWindBars[i]
    chargesBG.outline:SetVertexColor(layout.BorderColor.r, layout.BorderColor.g, layout.BorderColor.b, layout.BorderColor.a)
    chargesBG.Background:SetTexture(texture)
    chargesBG.Background:SetVertexColor(layout.BackgroundColor.r, layout.BackgroundColor.g, layout.BackgroundColor.b, layout.BackgroundColor.a)
    chargesBG.shadow:SetVertexColor(layout.ShadowColor.r, layout.ShadowColor.g, layout.ShadowColor.b, layout.ShadowColor.a)
    chargeBar:SetStatusBarColor(layout.ChargeColor.r, layout.ChargeColor.g, layout.ChargeColor.b, layout.ChargeColor.a)
    chargeBar:SetStatusBarTexture(texture)
    chargeBar.insideGlow:SetVertexColor(layout.InsideGlowColor.r, layout.InsideGlowColor.g, layout.InsideGlowColor.b, layout.InsideGlowColor.a)
    secondWindBar:SetStatusBarColor(layout.ChargeColor.r, layout.ChargeColor.g, layout.ChargeColor.b, layout.ChargeColor.a * 0.5)
    secondWindBar:SetStatusBarTexture(texture)
  end

  -- Initalize
  Falcon:UpdateUISizes(config.Width, config.SpeedHeight, config.ChargeHeight, config.Padding, config.SwapPositions, layout.BarBehaviourFlags)
  --API:FixPosition(Falcon)
  FalconSettings:ApplyMutedSoundsState()
end

local function OnPositionChanged(frame, layoutName, point, x, y)
  layoutName = FalconSettings:GetCurrentLayoutName(layoutName)
  point, x, y = API:FixPosition(frame)
  FalconAddOnDB.Settings[layoutName].point = point
  FalconAddOnDB.Settings[layoutName].x = x
  FalconAddOnDB.Settings[layoutName].y = y
end

Falcon.editModeName = 'Falcon'
LEM:AddFrame(Falcon, OnPositionChanged, defaultPosition)
LEM:AddFrameSettings(Falcon, {
  {
    name = 'Use Global Settings',
    kind = LEM.SettingType.Checkbox,
    default = false,
    get = function()
      return FalconAddOnDB.FalconGlobalSettingsEnabled
    end,
    set = function(layoutName, value, fromReset)
      if fromReset then
        layoutName = FalconSettings:GetCurrentLayoutName(layoutName)
        FalconSettings:SetupLayout(layoutName)
        LEM:RefreshFrameSettings(Falcon)
      else
        FalconAddOnDB.FalconGlobalSettingsEnabled = value
        layoutName = FalconSettings:GetCurrentLayoutName(layoutName)
        FalconSettings:SetupLayout(layoutName)
        LEM:RefreshFrameSettings(Falcon)
      end
    end,
  },
  {
    name = 'Texture',
    kind = LEM.SettingType.Dropdown,
    default = defaultTableData.DefaultTexture.Texture,
    set = function()
      local texture = defaultTableData.DefaultTexture.Texture
      Falcon.SpeedBar:SetStatusBarTexture(texture)
      Falcon.SpeedBarBG.Background:SetTexture(texture)
      for i = 1, Falcon.num_charges do
        local chargeBarBG = Falcon.ChargeBGs[i]
        local chargeBar = Falcon.ChargeBars[i]
        local secondWindBar = Falcon.SecondWindBars[i]
        chargeBarBG.Background:SetTexture(texture) ---@diagnostic disable-line: undefined-field
        secondWindBar:SetStatusBarTexture(texture)
        chargeBar:SetStatusBarTexture(texture)
      end
      local layoutName = FalconSettings:GetCurrentLayoutName(LEM:GetActiveLayoutName())
      FalconAddOnDB.Settings[layoutName].CurrentTexture = { Name = defaultTableData.DefaultTexture.Name }
    end,
    generator = function(owner, rootDescription)
      FalconSettings.SoundsDropdown = owner
      owner.ShouldShowTooltip = nop
      local getFunc = function(value)
        local layoutName = FalconSettings:GetCurrentLayoutName(LEM:GetActiveLayoutName())
        return FalconAddOnDB.Settings[layoutName].CurrentTexture.Name == value
      end
      local setFunc = function(value)
        local texture = LibSharedMedia:Fetch('statusbar', value)
        if texture then
          Falcon.SpeedBar:SetStatusBarTexture(texture)
          Falcon.SpeedBarBG.Background:SetTexture(texture)
          for i = 1, Falcon.num_charges do
            local chargeBarBG = Falcon.ChargeBGs[i]
            local chargeBar = Falcon.ChargeBars[i]
            local secondWindBar = Falcon.SecondWindBars[i]
            chargeBarBG.Background:SetTexture(texture) ---@diagnostic disable-line: undefined-field
            secondWindBar:SetStatusBarTexture(texture)
            chargeBar:SetStatusBarTexture(texture)
          end
          local layoutName = FalconSettings:GetCurrentLayoutName(LEM:GetActiveLayoutName())
          FalconAddOnDB.Settings[layoutName].CurrentTexture = { Name = value }
        end
      end
      rootDescription:SetScrollMode(400)
      rootDescription:CreateTitle('Included');
      for _, key in ipairs(ns.SharedMediaTextures) do
        if key.Name == 'Falcon Smooth' then
          rootDescription:CreateCheckbox('Falcon Smooth (Default)', getFunc, setFunc, key.Name)
        else
          rootDescription:CreateCheckbox(key.Name, getFunc, setFunc, key.Name)
        end
      end
      rootDescription:CreateSpacer();
      rootDescription:CreateTitle('Shared Media');
      for _, name in ipairs(LibSharedMedia:List('statusbar')) do
        if not ns.MediaNames[name] then
          rootDescription:CreateCheckbox(name, getFunc, setFunc, name)
        end
      end
    end,
  },
  {
    name = 'Inside Color',
    kind = LEM.SettingType.ColorPicker,
    default = CreateColor(defaultTableData.InsideGlowColor.r, defaultTableData.InsideGlowColor.g, defaultTableData.InsideGlowColor.b, defaultTableData.InsideGlowColor.a),
    hasOpacity = true,
    get = function(layoutName)
      return CreateColor(MutableData.InsideGlowColor.r, MutableData.InsideGlowColor.g, MutableData.InsideGlowColor.b, MutableData.InsideGlowColor.a)
    end,
    set = function(layoutName, value)
      layoutName = FalconSettings:GetCurrentLayoutName(layoutName)
      local r, g, b, a = value:GetRGBA()
      MutableData.InsideGlowColor = { r = r, g = g, b = b, a = a}
      FalconAddOnDB.Settings[layoutName].InsideGlowColor = MutableData.InsideGlowColor
      Falcon.SpeedBar.insideGlow:SetVertexColor(r, g, b ,a)
      for i = 1, 6 do
        local charges = Falcon.ChargeBars[i]
        charges.insideGlow:SetVertexColor(r, g, b ,a) ---@diagnostic disable-line: undefined-field
      end
    end,
  },
  {
    name = 'Speed Color',
    kind = LEM.SettingType.ColorPicker,
    default = CreateColor(defaultTableData.SpeedColor.r, defaultTableData.SpeedColor.g, defaultTableData.SpeedColor.b, 1),
    hasOpacity = true,
    get = function(layoutName)
      return CreateColor(MutableData.speedColor.r, MutableData.speedColor.g, MutableData.speedColor.b, MutableData.speedColor.a)
    end,
    set = function(layoutName, value)
      layoutName = FalconSettings:GetCurrentLayoutName(layoutName)
      local r, g, b, a = value:GetRGBA()
      MutableData.speedColor = { r = r, g = g, b = b, a = a}
      FalconAddOnDB.Settings[layoutName].SpeedColor = MutableData.speedColor
      Falcon.SpeedBar:SetStatusBarColor(r, g, b, a)
    end,
  },
  {
    name = 'Charge Color',
    kind = LEM.SettingType.ColorPicker,
    default = CreateColor(defaultTableData.ChargeColor.r, defaultTableData.ChargeColor.g, defaultTableData.ChargeColor.b, defaultTableData.ChargeColor.a),
    hasOpacity = true,
    get = function(layoutName)
      return CreateColor(MutableData.chargeColor.r, MutableData.chargeColor.g, MutableData.chargeColor.b, MutableData.chargeColor.a)
    end,
    set = function(layoutName, value)
      layoutName = FalconSettings:GetCurrentLayoutName(layoutName)
      local r, g, b, a = value:GetRGBA()
      MutableData.chargeColor = { r = r, g = g, b = b, a = a}
      FalconAddOnDB.Settings[layoutName].ChargeColor = MutableData.chargeColor
      for i = 1, Falcon.num_charges do
        local chargeBar = Falcon.ChargeBars[i]
        local secondWindBar = Falcon.SecondWindBars[i]
        secondWindBar:SetStatusBarColor(r, g, b, a * 0.5)
        chargeBar:SetStatusBarColor(r, g, b, a)
      end
    end,
  },
  {
    name = 'Border Color',
    kind = LEM.SettingType.ColorPicker,
    default = CreateColor(defaultTableData.BorderColor.r, defaultTableData.BorderColor.g, defaultTableData.BorderColor.b, defaultTableData.BorderColor.a),
    hasOpacity = true,
    get = function(layoutName)
      return CreateColor(MutableData.borderColor.r, MutableData.borderColor.g, MutableData.borderColor.b, MutableData.borderColor.a)
    end,
    set = function(layoutName, value)
      layoutName = FalconSettings:GetCurrentLayoutName(layoutName)
      local r, g, b, a = value:GetRGBA()
      MutableData.borderColor = { r = r, g = g, b = b, a = a}
      FalconAddOnDB.Settings[layoutName].BorderColor = MutableData.borderColor
      Falcon.SpeedBarBG.outline:SetVertexColor(r, g, b, a)
      Falcon.SpeedBar.tick:SetColorTexture(r, g, b, a)
      Falcon.WhirlingSurge.outline:SetVertexColor(r, g, b, a)
      for i = 1, Falcon.num_charges do
        local chargesBG = Falcon.ChargeBGs[i]
        chargesBG.outline:SetVertexColor(r, g, b, a) ---@diagnostic disable-line
      end
    end,
  },
  {
    name = 'Shadow Color',
    kind = LEM.SettingType.ColorPicker,
    default = CreateColor(defaultTableData.ShadowColor.r, defaultTableData.ShadowColor.g, defaultTableData.ShadowColor.b, defaultTableData.ShadowColor.a),
    hasOpacity = true,
    get = function(layoutName)
      return CreateColor(MutableData.shadowColor.r, MutableData.shadowColor.g, MutableData.shadowColor.b, MutableData.shadowColor.a)
    end,
    set = function(layoutName, value)
      layoutName = FalconSettings:GetCurrentLayoutName(layoutName)
      local r, g, b, a = value:GetRGBA()
      MutableData.shadowColor = { r = r, g = g, b = b, a = a}
      FalconAddOnDB.Settings[layoutName].ShadowColor = MutableData.shadowColor
      Falcon.SpeedBarBG.shadow:SetVertexColor(r, g, b, a)
      Falcon.shadow:SetVertexColor(r, g, b, a)
      Falcon.ChargesParent.shadow:SetVertexColor(r, g, b, a)
      Falcon.WhirlingSurge.shadow:SetVertexColor(r, g, b, a)
      for i = 1, 6 do
        local chargesBG = Falcon.ChargeBGs[i]
        chargesBG.shadow:SetVertexColor(r, g, b, a) ---@diagnostic disable-line: undefined-field
      end
      Falcon:UpdateShadow()
    end,
  },
  {
    name = 'Background Color',
    kind = LEM.SettingType.ColorPicker,
    default = CreateColor(defaultTableData.BackgroundColor.r, defaultTableData.BackgroundColor.g, defaultTableData.BackgroundColor.b, defaultTableData.BackgroundColor.a),
    hasOpacity = true,
    get = function(layoutName)
      return CreateColor(MutableData.backgroundColor.r, MutableData.backgroundColor.g, MutableData.backgroundColor.b, MutableData.backgroundColor.a)
    end,
    set = function(layoutName, value)
      layoutName = FalconSettings:GetCurrentLayoutName(layoutName)
      local r, g, b, a = value:GetRGBA()
      MutableData.backgroundColor = { r = r, g = g, b = b, a = a}
      FalconAddOnDB.Settings[layoutName].BackgroundColor = MutableData.backgroundColor
      Falcon.SpeedBarBG.Background:SetVertexColor(r, g, b, a)
      for i = 1, Falcon.num_charges do
        local chargesBG = Falcon.ChargeBGs[i]
        chargesBG.Background:SetVertexColor(r, g, b, a) ---@diagnostic disable-line: undefined-field
      end
    end,
  },
  {
    name = 'Swap Positions',
    kind = LEM.SettingType.Checkbox,
    default = false,
    get = function(layoutName)
      local layoutName = FalconSettings:GetCurrentLayoutName(layoutName)
      local CurrentStyle = FalconAddOnDB.Settings[layoutName].CurrentStyle
      return FalconAddOnDB.Settings[layoutName].Styles[CurrentStyle].SwapPositions ---@diagnostic disable-line: undefined-field
    end,
    set = function(layoutName, value)
      layoutName = FalconSettings:GetCurrentLayoutName(layoutName)
      local CurrentStyle = FalconAddOnDB.Settings[layoutName].CurrentStyle
      FalconAddOnDB.Settings[layoutName].Styles[CurrentStyle].SwapPositions = value
      Falcon:UpdateUISizes(nil, nil, nil, nil, value)
    end,
  },
  {
    name = 'Cell Width',
    kind = LEM.SettingType.Slider,
    default = defaultTableData.Styles.Clean.Width,
    get = function(layoutName)
      layoutName = FalconSettings:GetCurrentLayoutName(layoutName)
      local CurrentStyle = FalconAddOnDB.Settings[layoutName].CurrentStyle
      ---@diagnostic disable-next-line: undefined-field
      return FalconAddOnDB.Settings[layoutName].Styles[CurrentStyle].Width
    end,
    set = function(layoutName, value)
      layoutName = FalconSettings:GetCurrentLayoutName(layoutName)
      local CurrentStyle = FalconAddOnDB.Settings[layoutName].CurrentStyle
      FalconAddOnDB.Settings[layoutName].Styles[CurrentStyle].Width = value
      Falcon:UpdateUISizes(value)
      StartFixPosition()
    end,
    minValue = 10,
    maxValue = 100,
    valueStep = 1,
    formatter = function(value)
      return value
    end,
  },
  {
    name = 'Speed Height',
    kind = LEM.SettingType.Slider,
    default = defaultTableData.Styles.Clean.SpeedHeight,
    get = function(layoutName)
      layoutName = FalconSettings:GetCurrentLayoutName(layoutName)
      local CurrentStyle = FalconAddOnDB.Settings[layoutName].CurrentStyle
      return FalconAddOnDB.Settings[layoutName].Styles[CurrentStyle].SpeedHeight ---@diagnostic disable-line: undefined-field
    end,
    set = function(layoutName, value)
      layoutName = FalconSettings:GetCurrentLayoutName(layoutName)
      local CurrentStyle = FalconAddOnDB.Settings[layoutName].CurrentStyle
      FalconAddOnDB.Settings[layoutName].Styles[CurrentStyle].SpeedHeight = value
      Falcon:UpdateUISizes(nil, value)
      StartFixPosition()
    end,
    minValue = 6,
    maxValue = 50,
    valueStep = 1,
    formatter = function(value)
      return value
    end,
  },
  {
    name = 'Charge Height',
    kind = LEM.SettingType.Slider,
    default = defaultTableData.Styles.Clean.ChargeHeight,
    get = function(layoutName)
      layoutName = FalconSettings:GetCurrentLayoutName(layoutName)
      local CurrentStyle = FalconAddOnDB.Settings[layoutName].CurrentStyle
      return FalconAddOnDB.Settings[layoutName].Styles[CurrentStyle].ChargeHeight ---@diagnostic disable-line: undefined-field
    end,
    set = function(layoutName, value)
      layoutName = FalconSettings:GetCurrentLayoutName(layoutName)
      local CurrentStyle = FalconAddOnDB.Settings[layoutName].CurrentStyle
      FalconAddOnDB.Settings[layoutName].Styles[CurrentStyle].ChargeHeight = value
      Falcon:UpdateUISizes(nil, nil, value)
      StartFixPosition()
    end,
    minValue = 6,
    maxValue = 50,
    valueStep = 1,
    formatter = function(value)
      return value
    end,
  },
  {
    name = 'Padding',
    kind = LEM.SettingType.Slider,
    default = defaultTableData.Styles.Clean.Padding,
    get = function(layoutName)
      layoutName = FalconSettings:GetCurrentLayoutName(layoutName)
      local CurrentStyle = FalconAddOnDB.Settings[layoutName].CurrentStyle
      return FalconAddOnDB.Settings[layoutName].Styles[CurrentStyle].Padding ---@diagnostic disable-line: undefined-field
    end,
    set = function(layoutName, value)
      layoutName = FalconSettings:GetCurrentLayoutName(layoutName)
      local CurrentStyle = FalconAddOnDB.Settings[layoutName].CurrentStyle
      FalconAddOnDB.Settings[layoutName].Styles[CurrentStyle].Padding = value
      Falcon:UpdateUISizes(nil, nil, nil, value)
      StartFixPosition()
    end,
    minValue = 0,
    maxValue = 40,
    valueStep = 1,
    formatter = function(value)
      return value
    end,
  },
  {
  name = 'Bar Behaviour',
  kind = LEM.SettingType.Dropdown,
  default = 0,
  set = function(layoutName, value)
    local activeLayout = FalconSettings:GetCurrentLayoutName(LEM:GetActiveLayoutName())
    FalconAddOnDB.Settings[activeLayout].BarBehaviourFlags = value
    FalconSettings.BarBehaviourFlagsDropdown:GenerateMenu()
    Falcon:UpdateUISizes(nil, nil, nil, nil, nil, value)
  end,
  generator = function(owner, rootDescription)
    FalconSettings.BarBehaviourFlagsDropdown = owner
    owner.ShouldShowTooltip = nop

    local function GetActiveLayout()
      return FalconSettings:GetCurrentLayoutName(LEM:GetActiveLayoutName())
    end

    local getFunc = function(mask)
      local currentFlags = FalconAddOnDB.Settings[GetActiveLayout()].BarBehaviourFlags
      return FlagsUtil.IsAnySet(currentFlags, mask)
    end

    local function updateFlags(current, mask, groupMask)
      if bit.band(current, mask) ~= 0 then
        return bit.band(current, bit.bnot(mask))
      end
      return bit.bor(bit.band(current, bit.bnot(groupMask)), mask)
    end

    local setFunc = function(mask)
      local settings = FalconAddOnDB.Settings[GetActiveLayout()]
      local current = settings.BarBehaviourFlags

      local visMask = bit.bor(F.BarBehaviour.HIDE_CHARGES, F.BarBehaviour.HIDE_SPEED)
      local condMask = bit.bor(F.BarBehaviour.HIDE_GROUNDED, F.BarBehaviour.HIDE_FULL_GROUNDED)

      if bit.band(mask, visMask) ~= 0 then
        settings.BarBehaviourFlags = updateFlags(current, mask, mask)
      else
        settings.BarBehaviourFlags = updateFlags(current, mask, condMask)
      end
      Falcon:UpdateUISizes(nil, nil, nil, nil, nil, settings.BarBehaviourFlags)
    end

    rootDescription:CreateTitle('Visibility')
    for i, option in ipairs(BARBEHAVIOUR_OPTION_LIST) do
      if i == 3 then
        rootDescription:CreateSpacer()
        rootDescription:CreateTitle('Conditional')
      end

      local checkbox = rootDescription:CreateCheckbox(option.state, getFunc, setFunc, option.id)

      if option.requirementMask then
        checkbox:SetEnabled(function(self)
          local isEnabled = getFunc(option.requirementMask)
          return isEnabled
        end)
      end
    end
  end,
  },
  {
    name = 'Mute Sounds',
    kind = LEM.SettingType.Dropdown,
    default = 0,
    set = function()
      FalconSettings:ResetSounds()
    end,
    generator = function(owner, rootDescription)
      FalconSettings.SoundsDropdown = owner
      owner.ShouldShowTooltip = nop
      local getFunc = function(value)
        return FalconSettings:IsSoundChecked(value)
      end
      local setFunc = function(value)
        FalconSettings:SetSoundChecked(value)
      end

      rootDescription:CreateTitle('Skyriding Sounds');
      for i, option in ipairs(SOUND_OPTIONS) do
        if option.key and not option.mountID then
          rootDescription:CreateCheckbox(option.name, getFunc, setFunc, option.id)
        end
      end
      local dividerAndTitleCreated = false
      local function CreateDividerAndTitle()
        if not dividerAndTitleCreated then
          rootDescription:CreateSpacer();
          rootDescription:CreateTitle('Mount Sounds');
          dividerAndTitleCreated = true
        end
      end
        for i, option in ipairs(SOUND_OPTIONS) do
          if option.key and option.mountID then
            local isCollected = select(11,C_MountJournal.GetMountInfoByID(option.mountID))
            if isCollected then
              CreateDividerAndTitle()
              rootDescription:CreateCheckbox(option.name, getFunc, setFunc, option.id)
            end
          end
        end
    end,
  },
  {
    name = 'Second Wind',
    kind = LEM.SettingType.Dropdown,
    default = 1,
    set = function(layoutName, value)
      FalconAddOnDB.Settings['FalconGlobalSettings'].secondWindMode = value
      MutableData.secondWindMode = value
      FalconSettings.SecondWindDropdown:GenerateMenu()
      Falcon:UpdateUI()
    end,
    generator = function(owner, rootDescription)
      FalconSettings.SecondWindDropdown = owner
      owner.ShouldShowTooltip = nop
      local getFunc = function(value)
          return FalconAddOnDB.Settings['FalconGlobalSettings'].secondWindMode == value
      end
      local setFunc = function(value)
        FalconAddOnDB.Settings['FalconGlobalSettings'].secondWindMode = value
        MutableData.secondWindMode = value
        Falcon:UpdateUI()
      end

      for _, option in ipairs(SECOND_WIND_OPTIONS_LIST) do
        if option.state then
          rootDescription:CreateRadio(option.state, getFunc, setFunc, option.id)
        end
      end
    end,
  },
  {
    name = 'Whirling Surge',
    kind = LEM.SettingType.Dropdown,
    default = 1,
    set = function(layoutName, value)
      local layoutName = FalconSettings:GetCurrentLayoutName(LEM:GetActiveLayoutName())
      FalconAddOnDB.Settings[layoutName].whirlingSurgeState = value
      MutableData.whirlingSurgeState = value
      FalconSettings.WhirlingSurgeDropdown:GenerateMenu()
    end,
    generator = function(owner, rootDescription)
      FalconSettings.WhirlingSurgeDropdown = owner
      owner.ShouldShowTooltip = nop

      local getFuncState = function(value)
        local layoutName = FalconSettings:GetCurrentLayoutName(LEM:GetActiveLayoutName())
        return FalconAddOnDB.Settings[layoutName].whirlingSurgeState == value
      end

      local setFuncState = function(value)
        local layoutName = FalconSettings:GetCurrentLayoutName(LEM:GetActiveLayoutName())
        FalconAddOnDB.Settings[layoutName].whirlingSurgeState = value
        MutableData.whirlingSurgeState = value
      end

      for _, option in ipairs(WHIRLING_SURGE_OPTIONS_SHOWNSTATE_LIST) do
        if option.state then
          rootDescription:CreateCheckbox(option.state, getFuncState, setFuncState, option.id)
        end
      end
    end,
  },
  {
    name = 'Text Position',
    kind = LEM.SettingType.Dropdown,
    default = 'RIGHT',
    get = function(layoutName)
      layoutName = FalconSettings:GetCurrentLayoutName(layoutName)
      return FalconAddOnDB.Settings[layoutName].TextPosition
    end,
    set = function(layoutName, value)
      layoutName = FalconSettings:GetCurrentLayoutName(layoutName)
      FalconAddOnDB.Settings[layoutName].TextPosition = value
      if value == 'RIGHT' then
        Falcon.TextDisplay.Text:SetJustifyH('RIGHT')
      elseif value == 'LEFT' then
        Falcon.TextDisplay.Text:SetJustifyH('LEFT')
      end
    end,
    values = {
      {text = 'Right', value = 'RIGHT'},
      {text = 'Left', value = 'LEFT'},
    },
  },
  {
    name = 'Hide speed text',
    kind = LEM.SettingType.Checkbox,
    default = false,
    get = function(layoutName)
      layoutName = FalconSettings:GetCurrentLayoutName(layoutName)
      return FalconAddOnDB.Settings[layoutName].noDisplayText
    end,
    set = function(layoutName, value)
      layoutName = FalconSettings:GetCurrentLayoutName(layoutName)
      FalconAddOnDB.Settings[layoutName].noDisplayText = value
      MutableData.noDisplayText = value
      if value then
        Falcon.TextDisplay:Hide()
      end
    end,
  },
  {
    name = 'Hide when grounded and fully charged',
    kind = LEM.SettingType.Checkbox,
    default = false,
    get = function(layoutName)
      layoutName = FalconSettings:GetCurrentLayoutName(layoutName)
      return FalconAddOnDB.Settings[layoutName].hideWhenGroundedAndFull
    end,
    set = function(layoutName, value)
      layoutName = FalconSettings:GetCurrentLayoutName(layoutName)
      FalconAddOnDB.Settings[layoutName].hideWhenGroundedAndFull = value
      MutableData.hideWhenGroundedAndFull = value
    end,
  },
  {
    name = 'Disable Skyriding game effects',
    kind = LEM.SettingType.Checkbox,
    default = false,
    get = function(layoutName)
      return not C_CVar.GetCVarBool('AdvFlyingDynamicFOVEnabled') and not C_CVar.GetCVarBool('DriveDynamicFOVEnabled')
    end,
    set = function(layoutName, value)
      SetCVar('AdvFlyingDynamicFOVEnabled', not value)
      SetCVar('DriveDynamicFOVEnabled', not value)

      local settingEffects = Settings.GetSetting('DisableAdvancedFlyingFullScreenEffects')
      if settingEffects then
        settingEffects:ApplyValue(not value)
      end

      local settingVFX = Settings.GetSetting('DisableAdvancedFlyingVelocityVFX')
      if settingVFX then
        settingVFX:ApplyValue(not value)
      end
    end,
  },
})

local function SetEditModeSelectionState(alpha, isLabelVisible)
  Falcon.Selection.Center:SetAlpha(alpha)
  if isLabelVisible then
    Falcon.Selection.Label:Show()
  else
    Falcon.Selection.Label:Hide()
  end
end

Falcon.Selection:HookScript('OnLeave', function(self)
  if self.isSelected then
    SetEditModeSelectionState(0, false)
  else
    SetEditModeSelectionState(1, false)
  end
end)

LEM.internal.dialog:HookScript('OnHide', function(self)
  if not Falcon.Selection.isSelected then
    SetEditModeSelectionState(1, false)
  end
end)

LEM:RegisterCallback('enter', function()
  Falcon.AnimHide:Stop()
  Falcon.SpeedBar:SetScript('OnUpdate', nil)
  Falcon:SetScript('OnUpdate', nil)
  Falcon.SpeedBar:SetValue(0.65)
  Falcon.SpeedBar:SetAlpha(1)
  Falcon.SpeedBar.tick:Show()
  Falcon.TextDisplay.AnimShow:Play()
  Falcon.TextDisplay.Text:SetText(' 456 ')
  for i = 1, math.max(1, Falcon.num_charges) do
    if (i == Falcon.num_charges) then
      Falcon.SecondWindBars[i]:SetValue(0)
      Falcon.ChargeBars[i]:SetValue(0)
    elseif (i == Falcon.num_charges - 1) then
      Falcon.ChargeBars[i]:SetValue(0)
    elseif (i > Falcon.num_charges / 2) then
      Falcon.SecondWindBars[i]:SetValue(1)
    else
      Falcon.ChargeBars[i]:SetValue(1)
    end
  end
  Falcon.Selection:ClearAllPoints()
  Falcon.Selection:SetPoint('TOPLEFT', Falcon, 'TOPLEFT', -5, 5)
	Falcon.Selection:SetPoint('BOTTOMRIGHT', Falcon, 'BOTTOMRIGHT', 5, -5)
  Falcon:SetAlpha(1)
  Falcon:Show()
end)

LEM:RegisterCallback('exit', function()
  if not API:IsSkyriding() or ((C_Secrets and C_Secrets.ShouldSpellAuraBeSecret(369968))) then
    Falcon:SetAlpha(0)
    Falcon:Hide()
  end
  Falcon.TextDisplay.AnimHide:Play()
  Falcon.TextDisplay.Text:SetText('')
  Falcon.SpeedBar:SetValue(0)
  Falcon.SpeedBar.tick:Hide()
  Falcon:UpdateUI()
  API:FixPosition(Falcon)
end)

LEM:RegisterCallback('create', function(layoutName, _, sourceLayoutName)
  if sourceLayoutName and FalconAddOnDB.Settings[sourceLayoutName] then
    FalconAddOnDB.Settings[layoutName] = CopyTable(FalconAddOnDB.Settings[sourceLayoutName])
  end
end)

LEM:RegisterCallback('layout', function(layoutName)
  FalconSettings:SetupLayout(layoutName)
end)

LEM:RegisterCallback('rename', function(layoutName, newLayoutName)
  FalconAddOnDB.Settings[newLayoutName] = CopyTable(FalconAddOnDB.Settings[layoutName])
  FalconAddOnDB.Settings[layoutName] = nil
  FalconSettings:SetupLayout(newLayoutName)
end)

LEM:RegisterCallback('delete', function(layoutName)
  FalconAddOnDB.Settings[layoutName] = nil
end)

hooksecurefunc(UIParent, 'SetScale', function()
  -- ElvUI and and whatever other addons may not trigger UI_SCALE_CHANGED when changing scale
  Falcon:UpdateUISizes()
  API:FixPosition(Falcon)
end)

function FalconSettings:OnEvent(e, ...)
  if e == 'PLAYER_LOGIN' then
    self:RegisterEvent('DISPLAY_SIZE_CHANGED')
  end
  Falcon:UpdateUISizes()
  StartFixPosition()
end

function FalconSettings:OnLoad()
  self:SetScript('OnEvent', self.OnEvent)
  self:RegisterEvent('PLAYER_LOGIN')
end

FalconSettings:OnLoad()

SLASH_FALCON1 = '/FALCON'
function SlashCmdList.FALCON(msg)
  print('To access Falcon setting press Escape and click on Edit Mode, then click on the Falcon UI')
end