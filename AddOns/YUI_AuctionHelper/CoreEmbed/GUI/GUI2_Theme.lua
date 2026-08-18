local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
end
local YUI = _G.YUI
YUI.GUI2 = YUI.GUI2 or {}

local GUI2 = YUI.GUI2
local UnitAPI = YUI.API and YUI.API.Unit or YUI.WOW_API

local type, pairs, ipairs = type, pairs, ipairs
local unpack = unpack
local GetLocale = GetLocale
local STANDARD_TEXT_FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

GUI2.version = "5C-Lab"

local BLIZZARD_GOLD = { 1.00, 0.82, 0.00, 1 }
local YUI_BLUE = { 0.00, 0.60, 1.00, 1 }
local LOCALE_TEXT_FONTS = {
    zhCN = "Fonts\\ARKai_T.ttf",
    zhTW = "Fonts\\bLEI00D.ttf",
    koKR = "Fonts\\2002.TTF",
    ruRU = "Fonts\\FRIZQT___CYR.TTF",
}

function GUI2:GetDefaultFont()
    local locale = GetLocale and GetLocale()
    return LOCALE_TEXT_FONTS[locale] or STANDARD_TEXT_FONT
end

local function CopyValue(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for k, v in pairs(value) do
        copy[k] = CopyValue(v)
    end
    return copy
end

local function Color(r, g, b, a)
    return {
        type = "solid",
        value = { r, g, b, a == nil and 1 or a },
    }
end

local function Gradient(fallback, direction, stops)
    return {
        type = "gradient",
        fallback = fallback,
        direction = direction or "horizontal",
        stops = stops,
    }
end

local function ResolveClassColor()
    local _, class = UnitAPI.UnitClass("player")
    local color = UnitAPI.GetClassColor(class)
    if color then
        return { color.r, color.g, color.b, 1 }
    end
    return { 0.15, 0.55, 1, 1 }
end

local function SetAccentTokens(tokens, accent)
    -- Accent 是稳定主题强调色，不能承载玩家职业身份。
    tokens["color.accent.primary"] = Color(accent[1], accent[2], accent[3], accent[4] or 1)
    tokens["color.accent.soft"] = Color(accent[1], accent[2], accent[3], 0.16)
    tokens["color.accent.strong"] = Color(accent[1], accent[2], accent[3], 0.88)
    tokens["color.accent.fill"] = Color(accent[1] * 0.72, accent[2] * 0.72, accent[3] * 0.72, 1)
    tokens["color.accent.text"] = Color(1, 1, 1, 1)
    tokens["color.text.accent"] = Color(accent[1], accent[2], accent[3], 1)
    tokens["color.text.heading"] = Color(accent[1], accent[2], accent[3], 1)
    tokens["color.border.accent"] = Color(accent[1], accent[2], accent[3], 0.82)
end

local function SetClassTokens(tokens, classColor)
    -- 职业色只通过 color.class.* 显式用于角色/职业身份点缀。
    tokens["color.class.primary"] = Color(classColor[1], classColor[2], classColor[3], classColor[4] or 1)
    tokens["color.class.soft"] = Color(classColor[1], classColor[2], classColor[3], 0.16)
    tokens["color.class.border"] = Color(classColor[1], classColor[2], classColor[3], 0.70)
    tokens["color.class.fill"] = Color(classColor[1] * 0.72, classColor[2] * 0.72, classColor[3] * 0.72, 1)
    tokens["color.class.text"] = Color(classColor[1], classColor[2], classColor[3], 1)
end

local function SetInteractionTokens(tokens, interaction)
    tokens["color.interaction.primary"] = Color(interaction[1], interaction[2], interaction[3], interaction[4] or 1)
    tokens["color.interaction.soft"] = Color(interaction[1], interaction[2], interaction[3], 0.14)
    tokens["color.interaction.hover"] = Color(interaction[1] * 0.18, interaction[2] * 0.30, interaction[3] * 0.42, 0.88)
    tokens["color.interaction.active"] = Color(interaction[1] * 0.16, interaction[2] * 0.36, interaction[3] * 0.56, 0.92)
    tokens["color.interaction.fill"] = Color(interaction[1], interaction[2] * 0.72, interaction[3] * 0.82, 1)
    tokens["color.interaction.border"] = Color(interaction[1], interaction[2], interaction[3], 0.82)
    tokens["color.interaction.text"] = Color(0.72, 0.90, 1.00, 1)

    tokens["color.accent.primary"] = CopyValue(tokens["color.interaction.primary"])
    tokens["color.accent.soft"] = CopyValue(tokens["color.interaction.soft"])
    tokens["color.accent.strong"] = Color(interaction[1], interaction[2], interaction[3], 0.90)
    tokens["color.accent.fill"] = CopyValue(tokens["color.interaction.fill"])
    tokens["color.border.accent"] = CopyValue(tokens["color.interaction.border"])
    tokens["color.border.focus"] = CopyValue(tokens["color.interaction.border"])
end

local function AddCommonTokens(tokens)
    tokens["color.state.success"] = Color(0.21, 0.75, 0.38, 1)
    tokens["color.state.warning"] = Color(0.95, 0.70, 0.22, 1)
    tokens["color.state.error"] = Color(0.95, 0.25, 0.25, 1)
    tokens["color.state.info"] = Color(0.30, 0.62, 0.98, 1)
    tokens["color.state.danger"] = Color(0.92, 0.18, 0.18, 1)

    local defaultFont = GUI2:GetDefaultFont()
    tokens["font.family.body"] = defaultFont
    tokens["font.family.heading"] = defaultFont
    tokens["font.size.sm"] = 11
    tokens["font.size.md"] = 13
    tokens["font.size.lg"] = 15
    tokens["font.size.title"] = 20

    tokens["layout.gap.inline"] = 8
    tokens["layout.gap.stack"] = 10
    tokens["layout.gap.section"] = 18
    tokens["layout.padding.controlX"] = 10
    tokens["layout.padding.controlY"] = 6
    tokens["layout.padding.panel"] = 14
    tokens["layout.padding.popup"] = 12
    tokens["layout.height.control"] = 26
    tokens["layout.height.row"] = 28
    tokens["layout.height.menuItem"] = 26
    tokens["layout.form.rowHeight"] = 32
    tokens["layout.form.labelWidth"] = 120
    tokens["layout.form.controlWidth"] = 220
    tokens["layout.form.valueWidth"] = 56
    tokens["layout.form.gap"] = 10
    tokens["layout.form.rowGap"] = 10
    tokens["layout.form.sectionGap"] = 18
    tokens["layout.form.width.compact"] = 112
    tokens["layout.form.width.normal"] = 180
    tokens["layout.form.width.wide"] = 220
    tokens["layout.size.icon"] = 22
    tokens["layout.size.iconButton"] = 28
    tokens["layout.radius.panel"] = 0
    tokens["layout.radius.control"] = 0
    tokens["layout.radius.icon"] = 0

    tokens["color.control.choice.left"] = CopyValue(tokens["color.control.hover"] or tokens["color.control.track"] or tokens["color.control.bg"])
    tokens["color.control.choice.right"] = CopyValue(tokens["color.control.active"] or tokens["color.interaction.active"] or tokens["color.control.bg"])
    tokens["color.control.locked"] = Color(0.260, 0.185, 0.055, 0.86)
    tokens["color.border.locked"] = CopyValue(tokens["color.state.warning"])
    tokens["color.text.locked"] = CopyValue(tokens["color.state.warning"])

    tokens["border.width.hairline"] = 1
    tokens["shadow.panel.size"] = 3
    tokens["shadow.popup.size"] = 5

    tokens["color.nav.indicator"] = CopyValue(tokens["color.border.accent"] or tokens["color.border.default"])
    tokens["color.popup.border"] = CopyValue(tokens["color.border.default"])
    tokens["color.baritem.hover"] = CopyValue(tokens["color.control.hover"])
    tokens["color.baritem.hoverBorder"] = CopyValue(tokens["color.border.accent"])
    tokens["color.baritem.hoverText"] = CopyValue(tokens["color.text.accent"])
end

local function BuildMidnightTokens()
    local tokens = {}

    tokens["color.surface.base"] = Color(0.040, 0.045, 0.055, 0.96)
    tokens["color.surface.window"] = Color(0.073, 0.083, 0.100, 0.96)
    tokens["color.surface.panel"] = Color(0.095, 0.105, 0.125, 0.94)
    tokens["color.surface.raised"] = Color(0.122, 0.135, 0.158, 0.96)
    tokens["color.surface.sunken"] = Color(0.052, 0.060, 0.074, 0.96)
    tokens["color.surface.popup"] = Color(0.098, 0.125, 0.150, 0.985)
    tokens["color.surface.header"] = Color(0.084, 0.095, 0.116, 0.96)
    tokens["color.surface.nav"] = Color(0.060, 0.069, 0.088, 0.96)

    tokens["color.text.primary"] = Color(0.92, 0.94, 0.96, 1)
    tokens["color.text.secondary"] = Color(0.72, 0.76, 0.80, 1)
    tokens["color.text.muted"] = Color(0.48, 0.52, 0.58, 1)
    tokens["color.text.disabled"] = Color(0.34, 0.36, 0.40, 1)

    tokens["color.border.default"] = Color(0.22, 0.26, 0.32, 1)
    tokens["color.border.subtle"] = Color(0.15, 0.18, 0.22, 0.92)
    tokens["color.border.strong"] = Color(0.32, 0.38, 0.46, 1)
    tokens["color.border.focus"] = Color(0.24, 0.62, 0.95, 0.9)
    tokens["color.border.error"] = Color(0.85, 0.20, 0.20, 1)

    tokens["color.control.bg"] = Color(0.060, 0.072, 0.090, 1)
    tokens["color.control.hover"] = Color(0.020, 0.095, 0.155, 0.92)
    tokens["color.control.pressed"] = Color(0.078, 0.090, 0.112, 1)
    tokens["color.control.active"] = Color(0.000, 0.145, 0.235, 0.92)
    tokens["color.control.disabled"] = Color(0.06, 0.065, 0.075, 0.8)
    tokens["color.control.track"] = Color(0.052, 0.060, 0.075, 1)
    tokens["color.control.thumb"] = Color(0.72, 0.78, 0.85, 1)

    tokens["color.overlay.shadow"] = Color(0, 0, 0, 0.60)
    tokens["color.overlay.highlight"] = Color(0.45, 0.70, 1, 0.16)

    local classColor = ResolveClassColor()
    SetAccentTokens(tokens, BLIZZARD_GOLD)
    SetInteractionTokens(tokens, YUI_BLUE)
    SetClassTokens(tokens, classColor)
    AddCommonTokens(tokens)
    tokens["color.nav.indicator"] = CopyValue(tokens["color.class.primary"])
    tokens["color.baritem.hover"] = Color(classColor[1], classColor[2], classColor[3], 0.22)
    tokens["color.baritem.hoverBorder"] = CopyValue(tokens["color.class.border"])
    tokens["color.baritem.hoverText"] = CopyValue(tokens["color.class.text"])
    tokens["color.dropdown.arrow.default"] = CopyValue(tokens["color.border.default"])
    tokens["color.dropdown.arrow.hover"] = CopyValue(tokens["color.interaction.text"])
    return tokens
end

local function BuildNativeGildedTokens()
    local tokens = {}

    tokens["color.surface.base"] = Color(0.071, 0.078, 0.086, 0.96)
    tokens["color.surface.window"] = Color(0.102, 0.114, 0.129, 0.96)
    tokens["color.surface.panel"] = Color(0.125, 0.141, 0.165, 0.94)
    tokens["color.surface.raised"] = Color(0.165, 0.188, 0.212, 0.96)
    tokens["color.surface.sunken"] = Color(0.055, 0.063, 0.071, 0.96)
    tokens["color.surface.popup"] = Color(0.165, 0.141, 0.094, 0.985)
    tokens["color.surface.header"] = Color(0.102, 0.114, 0.129, 0.96)
    tokens["color.surface.nav"] = Color(0.071, 0.078, 0.086, 0.96)

    tokens["color.text.primary"] = Color(0.949, 0.941, 0.918, 1)
    tokens["color.text.secondary"] = Color(0.788, 0.753, 0.667, 1)
    tokens["color.text.muted"] = Color(0.553, 0.525, 0.471, 1)
    tokens["color.text.disabled"] = Color(0.373, 0.357, 0.322, 1)

    tokens["color.border.default"] = Color(0.227, 0.200, 0.149, 0.88)
    tokens["color.border.subtle"] = Color(0.161, 0.141, 0.110, 0.84)
    tokens["color.border.strong"] = Color(0.459, 0.365, 0.173, 0.95)
    tokens["color.border.focus"] = Color(0.725, 0.522, 0.133, 0.95)
    tokens["color.border.error"] = Color(0.85, 0.20, 0.20, 1)

    tokens["color.control.bg"] = Color(0.102, 0.114, 0.129, 1)
    tokens["color.control.hover"] = Color(0.176, 0.157, 0.110, 0.86)
    tokens["color.control.pressed"] = Color(0.071, 0.078, 0.086, 1)
    tokens["color.control.active"] = Color(0.424, 0.290, 0.086, 0.72)
    tokens["color.control.disabled"] = Color(0.063, 0.067, 0.071, 0.78)
    tokens["color.control.track"] = Color(0.055, 0.063, 0.071, 1)
    tokens["color.control.thumb"] = Color(0.851, 0.706, 0.318, 1)

    tokens["color.overlay.shadow"] = Color(0, 0, 0, 0.60)
    tokens["color.overlay.highlight"] = Color(0.945, 0.824, 0.541, 0.13)

    local classColor = ResolveClassColor()
    SetAccentTokens(tokens, { 0.851, 0.706, 0.318, 1 })
    SetClassTokens(tokens, classColor)
    AddCommonTokens(tokens)
    tokens["color.accent.strong"] = Color(0.945, 0.824, 0.541, 0.92)
    tokens["color.accent.fill"] = Color(0.725, 0.522, 0.133, 1)
    tokens["color.accent.text"] = Color(0.071, 0.078, 0.086, 1)
    tokens["color.text.heading"] = Color(0.945, 0.824, 0.541, 1)
    tokens["color.text.accent"] = Color(0.851, 0.706, 0.318, 1)
    tokens["color.border.accent"] = Color(0.725, 0.522, 0.133, 0.86)
    tokens["color.state.warning"] = Color(0.945, 0.824, 0.541, 1)
    tokens["color.nav.indicator"] = CopyValue(tokens["color.class.primary"])
    tokens["color.popup.border"] = CopyValue(tokens["color.border.strong"])
    tokens["color.baritem.hover"] = Color(classColor[1], classColor[2], classColor[3], 0.22)
    tokens["color.baritem.hoverBorder"] = CopyValue(tokens["color.class.border"])
    tokens["color.baritem.hoverText"] = CopyValue(tokens["color.class.text"])
    tokens["color.control.locked"] = Color(0.424, 0.290, 0.086, 0.72)
    tokens["color.border.locked"] = CopyValue(tokens["color.state.warning"])
    tokens["color.text.locked"] = CopyValue(tokens["color.state.warning"])
    tokens["color.modswitch.active"] = Color(0.725, 0.522, 0.133, 0.56)
    tokens["color.modswitch.activeHover"] = Color(0.851, 0.706, 0.318, 0.64)
    tokens["color.dropdown.arrow.default"] = CopyValue(tokens["color.text.accent"])
    tokens["color.dropdown.arrow.hover"] = CopyValue(tokens["color.text.primary"])
    tokens["layout.radius.panel"] = 0
    tokens["layout.radius.control"] = 0
    tokens["layout.radius.icon"] = 0
    tokens["backdrop.nativeFrameBorder.enabled"] = true
    tokens["backdrop.nativeFrameBorder.tooltip.outset"] = 5
    return tokens
end

local function BuildAstralVioletTokens()
    local tokens = {}

    tokens["color.surface.base"] = Color(0.018, 0.024, 0.050, 0.97)
    tokens["color.surface.window"] = Color(0.036, 0.044, 0.090, 0.96)
    tokens["color.surface.panel"] = Color(0.050, 0.061, 0.118, 0.94)
    tokens["color.surface.raised"] = Color(0.070, 0.082, 0.154, 0.96)
    tokens["color.surface.sunken"] = Color(0.025, 0.032, 0.070, 0.96)
    tokens["color.surface.popup"] = Color(0.074, 0.066, 0.156, 0.985)
    tokens["color.surface.header"] = Color(0.058, 0.062, 0.135, 0.96)
    tokens["color.surface.nav"] = Color(0.033, 0.039, 0.083, 0.96)

    tokens["color.text.primary"] = Color(0.930, 0.945, 1.000, 1)
    tokens["color.text.secondary"] = Color(0.720, 0.760, 0.880, 1)
    tokens["color.text.muted"] = Color(0.490, 0.530, 0.680, 1)
    tokens["color.text.disabled"] = Color(0.320, 0.350, 0.480, 1)

    tokens["color.border.default"] = Color(0.150, 0.170, 0.300, 0.92)
    tokens["color.border.subtle"] = Color(0.100, 0.120, 0.220, 0.86)
    tokens["color.border.strong"] = Color(0.270, 0.290, 0.480, 0.95)
    tokens["color.border.focus"] = Color(0.000, 0.720, 0.920, 0.92)
    tokens["color.border.error"] = Color(0.85, 0.20, 0.20, 1)

    tokens["color.control.bg"] = Color(0.060, 0.069, 0.137, 1)
    tokens["color.control.hover"] = Color(0.050, 0.145, 0.230, 0.92)
    tokens["color.control.pressed"] = Color(0.038, 0.047, 0.104, 1)
    tokens["color.control.active"] = Color(0.160, 0.120, 0.420, 0.92)
    tokens["color.control.disabled"] = Color(0.044, 0.050, 0.095, 0.78)
    tokens["color.control.track"] = Color(0.025, 0.032, 0.070, 1)
    tokens["color.control.thumb"] = Color(0.560, 0.620, 0.880, 1)

    tokens["color.interaction.primary"] = Color(0.000, 0.720, 0.920, 1)
    tokens["color.interaction.soft"] = Color(0.000, 0.720, 0.920, 0.12)
    tokens["color.interaction.hover"] = Color(0.050, 0.145, 0.230, 0.92)
    tokens["color.interaction.active"] = Color(0.055, 0.105, 0.260, 0.94)
    tokens["color.interaction.fill"] = Color(0.000, 0.460, 0.640, 1)
    tokens["color.interaction.border"] = Color(0.000, 0.680, 0.920, 0.82)
    tokens["color.interaction.text"] = Color(0.740, 0.920, 1.000, 1)

    tokens["color.overlay.shadow"] = Color(0, 0, 0, 0.62)
    tokens["color.overlay.highlight"] = Color(0.430, 0.360, 0.960, 0.14)

    local classColor = ResolveClassColor()
    SetAccentTokens(tokens, { 0.480, 0.420, 0.960, 1 })
    SetClassTokens(tokens, classColor)
    AddCommonTokens(tokens)
    tokens["color.text.heading"] = Color(0.960, 0.970, 1.000, 1)
    tokens["color.text.accent"] = Color(0.820, 0.900, 1.000, 1)
    tokens["color.accent.text"] = Color(0.980, 0.985, 1.000, 1)
    tokens["color.state.info"] = CopyValue(tokens["color.interaction.primary"])
    tokens["color.nav.indicator"] = CopyValue(tokens["color.class.primary"])
    tokens["color.popup.border"] = CopyValue(tokens["color.border.strong"])
    tokens["color.baritem.hover"] = Color(classColor[1], classColor[2], classColor[3], 0.22)
    tokens["color.baritem.hoverBorder"] = CopyValue(tokens["color.class.border"])
    tokens["color.baritem.hoverText"] = CopyValue(tokens["color.class.text"])
    tokens["color.dropdown.arrow.default"] = CopyValue(tokens["color.text.muted"])
    tokens["color.dropdown.arrow.hover"] = CopyValue(tokens["color.interaction.text"])
    return tokens
end

GUI2.skins = {
    ["modern-dark"] = {
        id = "modern-dark",
        name = "Modern Dark",
        radius = "low",
    },
    ["gilded-gray"] = {
        id = "gilded-gray",
        name = "Native Gilded",
        radius = "low",
    },
    ["astral-violet"] = {
        id = "astral-violet",
        name = "Astral Violet",
        radius = "low",
    },
}

GUI2.presets = {
    {
        id = "midnight",
        nameKey = "settings.appearance.preset.midnight",
        name = "Midnight Cobalt",
        skin = "modern-dark",
        buildTokens = BuildMidnightTokens,
    },
    {
        id = "gilded",
        nameKey = "settings.appearance.preset.gilded",
        name = "Graphite Gilded",
        skin = "gilded-gray",
        buildTokens = BuildNativeGildedTokens,
    },
    {
        id = "astral-violet",
        nameKey = "settings.appearance.preset.astral_violet",
        name = "Astral Violet",
        skin = "astral-violet",
        buildTokens = BuildAstralVioletTokens,
    },
}

GUI2.presetAliases = {
    class = "gilded",
}

function GUI2:GetPresets()
    return self.presets
end

function GUI2:ResolvePresetId(id)
    id = id or self.activePresetId or "midnight"
    if self.presetAliases and self.presetAliases[id] then
        id = self.presetAliases[id]
    end
    return id
end

function GUI2:GetPreset(id)
    id = self:ResolvePresetId(id)
    for _, preset in ipairs(self.presets) do
        if preset.id == id then
            return preset
        end
    end
    return self.presets[1]
end

function GUI2:GetPresetDisplayName(presetOrId)
    local preset = presetOrId
    if type(presetOrId) ~= "table" then
        preset = self:GetPreset(presetOrId)
    end
    if type(preset) ~= "table" then
        return tostring(presetOrId or "")
    end

    if preset.nameKey and YUI.Locale and YUI.Locale.Get then
        local locale = YUI.Locale:Get("Core")
        local name = locale and locale[preset.nameKey]
        if type(name) == "string" and name ~= "" and name ~= preset.nameKey then
            return name
        end
    end

    return preset.name or preset.id or ""
end

GUI2.tokenProviders = GUI2.tokenProviders or {}

local function ApplyTokenProviders(tokens, preset)
    for _, provider in pairs(GUI2.tokenProviders) do
        provider(tokens, preset)
    end
end

function GUI2:CreateSolidPaint(r, g, b, a)
    return Color(r, g, b, a)
end

function GUI2:RegisterTokenProvider(namespace, provider)
    if type(namespace) ~= "string" or namespace == "" or type(provider) ~= "function" then
        return false
    end

    self.tokenProviders = self.tokenProviders or {}
    self.tokenProviders[namespace] = provider

    if self.tokens then
        provider(self.tokens, self.activePreset)
    end

    return true
end

function GUI2:SetPreset(id)
    local preset = self:GetPreset(id)
    self.activePresetId = preset.id
    self.activePreset = preset
    self.activeSkin = self.skins[preset.skin]
    self.tokens = preset.buildTokens and preset.buildTokens() or {}
    ApplyTokenProviders(self.tokens, preset)

    if self.RefreshThemeObjects then
        self:RefreshThemeObjects()
    end
    if self.Lab and self.Lab.RefreshTheme then
        self.Lab:RefreshTheme()
    end
    if YUI.Settings and YUI.Settings.RefreshGUI2Theme then
        YUI.Settings:RefreshGUI2Theme()
    end
    if YUI.YBar and YUI.YBar.RefreshGUI2IconSlots then
        YUI.YBar:RefreshGUI2IconSlots()
    end
    if YUI.YBar and YUI.YBar.RefreshGUI2StatusTexts then
        YUI.YBar:RefreshGUI2StatusTexts()
    end
    if YUI.YBar and YUI.YBar.RefreshGUI2ThemedTexts then
        YUI.YBar:RefreshGUI2ThemedTexts()
    end
    if YUI.YBar and YUI.YBar.RefreshGUI2ThemedTextures then
        YUI.YBar:RefreshGUI2ThemedTextures()
    end
    if YUI.YBar and YUI.YBar.RefreshGUI2MiniProgressLines then
        YUI.YBar:RefreshGUI2MiniProgressLines()
    end
    if YUI.YBar and YUI.YBar.RefreshGUI2PanelHoverChromes then
        YUI.YBar:RefreshGUI2PanelHoverChromes()
    end
    if YUI.YBar and YUI.YBar.RefreshGUI2BarItems then
        YUI.YBar:RefreshGUI2BarItems()
    end
    if YUI.YBar and YUI.YBar.RefreshGUI2PopIconMenus then
        YUI.YBar:RefreshGUI2PopIconMenus()
    end

    return preset
end

function GUI2:GetActivePreset()
    if not self.activePreset then
        self:SetPreset("midnight")
    end
    return self.activePreset
end

function GUI2:GetActiveSkin()
    if not self.activeSkin then
        self:SetPreset("midnight")
    end
    return self.activeSkin
end

function GUI2:GetToken(key)
    if not self.tokens then
        self:SetPreset("midnight")
    end
    return self.tokens and self.tokens[key]
end

function GUI2:GetPaint(key, fallback)
    local value = self:GetToken(key)
    if value then
        return value
    end
    if type(fallback) == "table" and fallback.type then
        return fallback
    end
    if type(fallback) == "table" then
        return Color(fallback[1], fallback[2], fallback[3], fallback[4])
    end
    return Color(1, 1, 1, 1)
end

function GUI2:GetColor(key, fallback)
    local paint = self:GetPaint(key, fallback)
    if paint.type == "solid" then
        return unpack(paint.value)
    end
    if paint.type == "gradient" then
        local color = paint.fallback
        if not color and paint.stops and paint.stops[1] then
            color = paint.stops[1].color
        end
        color = color or fallback or { 1, 1, 1, 1 }
        return color[1], color[2], color[3], color[4] or 1
    end
    if type(paint) == "table" then
        return paint[1] or 1, paint[2] or 1, paint[3] or 1, paint[4] or 1
    end
    return 1, 1, 1, 1
end

function GUI2:GetFont(key)
    local value = self:GetToken(key)
    if type(value) == "string" then
        return value
    end
    if type(value) == "table" then
        return value.path or value.fallback or self:GetDefaultFont()
    end
    return self:GetDefaultFont()
end

function GUI2:GetMetric(key, fallback)
    local value = self:GetToken(key)
    if type(value) == "number" then
        return value
    end
    return fallback or 0
end

function GUI2:CreateGradientPaint(fallback, startColor, endColor)
    return Gradient(fallback, "horizontal", {
        { offset = 0, color = startColor },
        { offset = 1, color = endColor },
    })
end

GUI2:SetPreset(GUI2.activePresetId or "midnight")
