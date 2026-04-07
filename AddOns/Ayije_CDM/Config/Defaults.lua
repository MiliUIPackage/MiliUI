local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

CDM.defaults = {
    sizeEssRow1 = { w = 46, h = 40 },
    sizeEssRow2 = { w = 46, h = 40 },
    sizeUtility = { w = 46, h = 40 },
    sizeBuff = { w = 40, h = 36 },
    spacing = 1,
    maxRowEss = 9,
    utilityYOffset = 0,
    utilityWrap = false,
    maxRowUtil = 8,
    utilityUnlock = false,
    utilityXOffset = 0,
    utilityVertical = false,
    containerLocked = true,
    buffContainerLocked = true,

    -- BuffBar viewer settings
    buffBarContainerLocked = true,
    buffBarWidth = 0,               -- 0 = auto (match Essential row 1 width)
    buffBarHeight = 20,
    buffBarSpacing = 1,
    buffBarGrowDirection = "DOWN",   -- "UP" or "DOWN"
    buffBarIconPosition = "LEFT",   -- "LEFT", "RIGHT", "HIDDEN"
    buffBarIconGap = 1,             -- Gap between icon and bar
    buffBarShowName = true,
    buffBarNameMaxChars = 0,
    buffBarShowDuration = true,
    buffBarTexture = "Solid",
    buffBarColor = { r = 0.4, g = 0.6, b = 0.9, a = 1 },
    buffBarBackgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.8 },
    buffBarDualMode = false,        -- 2 bars per row: [bar-icon] [icon-bar]
    buffBarNameFontSize = 15,
    buffBarNameColor = { r = 1, g = 1, b = 1, a = 1 },
    buffBarNameOffsetX = 2,
    buffBarNameOffsetY = 0,
    buffBarDurationFontSize = 15,
    buffBarDurationColor = { r = 1, g = 1, b = 1, a = 1 },
    buffBarDurationOffsetX = -2,
    buffBarDurationOffsetY = 0,
    buffBarShowApplications = true,
    buffBarApplicationsFontSize = 15,
    buffBarApplicationsColor = { r = 1, g = 1, b = 1, a = 1 },
    buffBarApplicationsPosition = "CENTER",
    buffBarApplicationsOffsetX = 0,
    buffBarApplicationsOffsetY = 0,

    -- Assist
    rotationAssistEnabled = false,
    rotationAssistGlowRatio = 0.33,
    assistEnabled = false,
    assistFontSize = 15,
    assistColor = { r = 1, g = 1, b = 1, a = 1 },
    assistPosition = "TOPRIGHT",
    assistOffsetX = 0,
    assistOffsetY = 0,

    -- Press Overlay
    pressOverlayEnabled = false,
    pressOverlayTint = false,
    pressOverlayTintColor = { r = 1, g = 1, b = 1, a = 0.35 },
    pressOverlayHighlight = true,
    pressOverlayBorder = false,
    pressOverlayBorderColor = { r = 1, g = 1, b = 1, a = 1 },

    -- Module enable/disable toggles
    racialsEnabled = true,
    defensivesEnabled = true,
    trinketsEnabled = true,
    resourcesEnabled = true,
    externalsEnabled = true,

    -- Externals (ExternalDefensivesFrame) settings
    externalsIconWidth = 30,
    externalsIconHeight = 30,
    externalsCooldownFontSize = 15,
    externalsDisableBlink = true,

    -- Racials tracker settings
    racialsIconWidth = 40,
    racialsIconHeight = 36,
    racialsAnchorPoint = "BOTTOMLEFT",
    racialsOffsetX = 0,
    racialsOffsetY = 0,
    racialsChargeFontSize = 15,
    racialsChargeColor = { r = 1, g = 1, b = 1, a = 1 },
    racialsCooldownFontSize = 15,
    racialsChargePosition = "BOTTOM",
    racialsChargeOffsetX = 0,
    racialsChargeOffsetY = 0,
    racialsShowItemsAtZeroStacks = false,
    racialsCustomEntries = {},
    racialsOrderPerSpec = {},
    racialsDisabled = {},

    -- Defensives tracker settings
    defensivesIconWidth = 40,
    defensivesIconHeight = 36,
    defensivesAnchorPoint = "TOPRIGHT",
    defensivesOffsetX = 0,
    defensivesOffsetY = 0,
    defensivesChargeFontSize = 15,
    defensivesCooldownFontSize = 15,
    defensivesChargePosition = "TOP",
    defensivesChargeOffsetX = 0,
    defensivesChargeOffsetY = 0,
    defensivesDisabledSpells = {},
    defensivesCustomSpells = {},
    defensivesOrder = {},

    -- Trinkets tracker settings
    trinketsIconWidth = 40,
    trinketsIconHeight = 36,
    trinketsAnchorPoint = "TOPLEFT",
    trinketsOffsetX = 0,
    trinketsOffsetY = 0,
    trinketsCooldownFontSize = 15,
    trinketsShowPassive = true,
    trinketsMode = "independent",       -- "independent", "defensives", "essential"
    trinketsEssentialRow = 1,           -- 1 or 2 (which row trinkets appear in)
    trinketsEssentialPosition = "end",  -- "start" or "end"

    -- Party frame anchoring settings
    racialsUsePartyFrame = false,
    racialsPartyFrameSide = "LEFT",
    racialsPartyFrameOffsetX = -1,
    racialsPartyFrameOffsetY = 20,

    -- Resources module settings
    resourcesBarHeight = 16,
    resourcesBar2Height = 16,
    resourcesBarWidth = 0,
    resourcesBarSpacing = 1,
    resourcesOffsetX = 0,
    resourcesOffsetY = -200,
    resourcesUnifiedBorder = false,
    resourcesMoveBuffsDown = false,
    resourcesSmoothBars = true,
    resourcesBarTexture = "Solid",
    resourcesBarBackgroundTexture = "Solid",

    -- Power type colors
    resourcesRageColor = { r = 0.78, g = 0.26, b = 0.26, a = 1 },
    resourcesEnergyColor = { r = 1, g = 1, b = 0.34, a = 1 },
    resourcesFocusColor = { r = 1, g = 0.5, b = 0.25, a = 1 },
    resourcesTipOfTheSpearColor = { r = 0.9, g = 0.3, b = 0.15, a = 1 },
    resourcesComboPointsColor = { r = 1, g = 0.96, b = 0.41, a = 1 },
    resourcesComboPointsChargedColor = { r = 0.24, g = 0.60, b = 1.00, a = 1 },
    resourcesComboPointsChargedEmptyColor = { r = 0.12, g = 0.30, b = 0.50, a = 1 },
    resourcesBackgroundColor = { r = 0.2, g = 0.2, b = 0.2, a = 0.5 },

    -- Death Knight specific colors
    resourcesRunicPowerColor = { r = 0, g = 0.82, b = 1, a = 1 },
    resourcesRunesReadyColor = { r = 0.5, g = 0.8, b = 1, a = 1 },
    resourcesRunesRechargingColor = { r = 0.3, g = 0.3, b = 0.3, a = 1 },

    -- Druid / Balance
    resourcesLunarPowerColor = { r = 0.3, g = 0.52, b = 0.9, a = 1 },
    resourcesIronfurColor = { r = 0.153, g = 0.616, b = 1.0, a = 1 },
    resourcesFeralOverflowingColor = { r = 0.24, g = 0.60, b = 1.00, a = 1 },
    resourcesFeralOverflowingEmptyColor = { r = 0.12, g = 0.30, b = 0.50, a = 1 },

    -- Warrior / Protection
    resourcesIgnorePainColor = { r = 0.9, g = 0.8, b = 0.2, a = 1 },
    resourcesIgnorePainHideIcon = false,

    -- Shaman
    resourcesMaelstromColor = { r = 0, g = 0.5, b = 1, a = 1 },

    -- Priest / Shadow
    resourcesInsanityColor = { r = 0.4, g = 0, b = 0.8, a = 1 },

    -- Demon Hunter
    resourcesFuryColor = { r = 0.79, g = 0.26, b = 0.99, a = 1 },
    resourcesSoulFragmentsColor = { r = 0.0, g = 0.8, b = 0.0, a = 1 },  -- Vengeance DH Soul Fragments
    resourcesDevourerSoulFragmentsColor = { r = 0.11, g = 0.34, b = 0.71, a = 1 },  -- Devourer DH Souls

    -- Mana (all mana-using classes)
    resourcesManaColor = { r = 0.0, g = 0.56, b = 1.0, a = 1 },
    resourcesManaSettings = {},  -- per-spec mana enabled: [specID] = true/false, nil = use default
    resourcesManaPercentage = false,  -- show mana as percentage (no % sign) instead of raw value
    resourcesPrimaryResourceSettings = {},   -- per-spec: [specID] = false to hide, nil = show
    resourcesSecondaryResourceSettings = {}, -- per-spec: [specID] = false to hide, nil = show

    -- Evoker
    resourcesEssenceColor = { r = 0.16, g = 0.57, b = 0.49, a = 1 },
    resourcesEssenceRechargingColor = { r = 0.08, g = 0.28, b = 0.25, a = 1 },

    -- Warlock
    resourcesSoulShardsColor = { r = 0.58, g = 0.51, b = 0.79, a = 1 },
    resourcesSoulShardsRechargingColor = { r = 0.35, g = 0.30, b = 0.50, a = 1 },

    -- Paladin
    resourcesHolyPowerColor = { r = 0.95, g = 0.9, b = 0.6, a = 1 },

    -- Mage / Arcane
    resourcesArcaneChargesColor = { r = 0.1, g = 0.1, b = 0.98, a = 1 },

    -- Monk
    resourcesChiColor = { r = 0.71, g = 1, b = 0.92, a = 1 },
    -- Brewmaster Stagger (threshold-based colors like MonkStaggerBar)
    resourcesStaggerLightColor = { r = 0.52, g = 0.90, b = 0.52, a = 1 },    -- Light: <30% max health (green)
    resourcesStaggerModerateColor = { r = 1.0, g = 0.85, b = 0.36, a = 1 },  -- Moderate: 30-60% max health (yellow)
    resourcesStaggerHeavyColor = { r = 1.0, g = 0.42, b = 0.42, a = 1 },     -- Heavy: >60% max health (red)

    -- Resource Tags - Bar 1 (enabled is per-spec in resourcesTagSettings[specID])
    resourcesBar1TagFontSize = 15,
    resourcesBar1TagAnchor = "CENTER",
    resourcesBar1TagOffsetX = 0,
    resourcesBar1TagOffsetY = 0,
    resourcesBar1TagColor = { r = 1, g = 1, b = 1, a = 1 },

    -- Resource Tags - Bar 2 (enabled is per-spec in resourcesTagSettings[specID])
    resourcesBar2TagFontSize = 15,
    resourcesBar2TagAnchor = "CENTER",
    resourcesBar2TagOffsetX = 0,
    resourcesBar2TagOffsetY = 0,
    resourcesBar2TagColor = { r = 1, g = 1, b = 1, a = 1 },

    -- Per-spec tag enabled settings: resourcesTagSettings[specID] = { bar1Enabled, bar2Enabled }
    resourcesTagSettings = {},

    -- Player Cast Bar settings
    castBarEnabled = true,
    hideBlizzardCastBar = false,
    castBarWidth = 0,
    castBarAutoWidthSource = "essential",
    castBarHeight = 20,
    castBarFontSize = 15,
    castBarShowSpellName = true,
    castBarNameMaxChars = 0,
    castBarShowTimer = true,
    castBarShowSpark = true,
    castBarNameOffsetX = 2,
    castBarNameOffsetY = 4,
    castBarTimerOffsetX = -2,
    castBarTimerOffsetY = 4,
    castBarOffsetX = 0,
    castBarOffsetY = -166,
    castBarContainerLocked = true,
    castBarAnchorToResources = true,
    castBarResourcesSpacing = 2,
    castBarShowIcon = false,
    castBarIconPosition = "LEFT",   -- "LEFT" or "RIGHT"
    castBarIconGap = 1,
    castBarUseAtlasTextures = false,
    castBarTexture = "Solid",
    castBarBackgroundTexture = "Solid",
    castBarBackgroundColor = { r = 0.15, g = 0.15, b = 0.15, a = 0.8 },
    castBarUseClassColor = false,
    castBarCastColor = { r = 1.0, g = 0.7, b = 0.0, a = 1 },
    castBarChannelColor = { r = 0.0, g = 1.0, b = 0.0, a = 1 },
    castBarUninterruptibleColor = { r = 0.7, g = 0.7, b = 0.7, a = 1 },
    castBarEmpowerWindUpColor = { r = 0.45, g = 0.45, b = 0.55, a = 1 },
    castBarEmpowerStage1Color = { r = 0.26, g = 0.65, b = 1.0, a = 1 },
    castBarEmpowerStage2Color = { r = 0.26, g = 0.90, b = 0.55, a = 1 },
    castBarEmpowerStage3Color = { r = 1.0, g = 0.80, b = 0.0, a = 1 },
    castBarEmpowerStage4Color = { r = 1.0, g = 0.35, b = 0.0, a = 1 },

    borderFile = "1 Pixel",
    borderSize = 1,
    borderOffsetX = 0,
    borderOffsetY = 0,
    borderColor = { r = 0, g = 0, b = 0, a = 1 },
    spellRegistry = {},
    editModePositions = {},
    customBuffRegistry = {},
    ungroupedCustomBuffOrder = {},
    buffGroups = {},
    ungroupedBuffOverrides = {},
    cooldownGroups = {},
    ungroupedCooldownOverrides = {},

    -- Global Text Settings
    textFont = "Friz Quadrata TT",
    textFontOutline = "OUTLINE",

    -- Cooldown Timer Text
    cooldownFontSize = 15,
    essRow2CooldownFontSize = 15,
    utilityCooldownFontSize = 15,
    cooldownColor = { r = 1, g = 1, b = 1, a = 1 },
    -- ChargeCount
    chargeFontSize = 15,
    utilityChargeFontSize = 15,
    chargeColor = { r = 1, g = 1, b = 1, a = 1 },
    chargePosition = "BOTTOMRIGHT",
    chargeOffsetX = 0,
    chargeOffsetY = 0,

    -- Applications (buff stacks)
    countFontSize = 15,
    countColor = { r = 1, g = 1, b = 1, a = 1 },

    -- Buff cooldown timer text (applies to all buff containers)
    buffCooldownFontSize = 15,
    buffCooldownColor = { r = 1, g = 1, b = 1, a = 1 },

    -- Main buff stack position
    countPositionMain = "TOP",
    countOffsetXMain = 0,
    countOffsetYMain = 0,

    zoomIcons = true,
    zoomAmount = 0.08,
    hideIconOverlay = true,
    hideIconOverlayTexture = true,
    swipeColor = { r = 0, g = 0, b = 0, a = 0.6 },
    hideGCDSwipe = false,

    -- Glow Settings
    glowType = "pixel", -- "pixel", "autocast", "button", "proc"
    glowUseCustomColor = false,
    glowColor = { r = 0.95, g = 0.95, b = 0.32, a = 1 },

    -- Pixel Glow
    glowPixelLines = 8,
    glowPixelFrequency = 0.2,
    glowPixelLength = 0, -- 0 = auto
    glowPixelThickness = 2,
    glowPixelXOffset = 0,
    glowPixelYOffset = 0,

    -- Autocast Glow
    glowAutocastParticles = 4,
    glowAutocastFrequency = 0.2,
    glowAutocastScale = 1,
    glowAutocastXOffset = 0,
    glowAutocastYOffset = 0,

    -- Button Glow
    glowButtonFrequency = 0, -- 0 = default

    -- Proc Glow
    glowProcDuration = 1,
    glowProcXOffset = 0,
    glowProcYOffset = 0,

    -- Visual elements
    hideDebuffBorder = true,
    hidePandemicIndicator = true,
    hideCooldownBling = true,

    -- Fading
    fadingEnabled = false,
    fadingTriggerNoTarget = true,
    fadingTriggerOOC = false,
    fadingTriggerMounted = false,
    fadingOpacity = 30,
    fadingEssential = true,
    fadingUtility = true,
    fadingBuffs = true,
    fadingBuffBars = true,
    fadingRacials = true,
    fadingDefensives = true,
    fadingTrinkets = true,
    fadingResources = true,
}
