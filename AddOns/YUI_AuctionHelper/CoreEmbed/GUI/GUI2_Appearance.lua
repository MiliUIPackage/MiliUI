do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local YUI = _G.YUI
YUI.GUI2 = YUI.GUI2 or {}

local GUI2 = YUI.GUI2
local CreateFrame = CreateFrame
local UIParent = UIParent
local ipairs = ipairs
local pairs = pairs
local type = type

GUI2.Appearance = GUI2.Appearance or {}
local Appearance = GUI2.Appearance

local DEFAULT_APPEARANCE = {
    basePreset = "midnight",
    userOptions = {
        motionStrength = "standard",
        density = "standard",
        iconShape = "rounded",
        settingsBackground = "artwork",
    },
    tokenOverrides = {},
}

local storedPresetApplied = false

local function GetProfile()
    if YUI.DB and YUI.DB.GetProfile then
        local profile = YUI.DB:GetProfile(YUI.ProductId or "suite")
        if type(profile) == "table" then
            return profile
        end
    end
    return nil
end

local function CopyDefaults(source)
    local copy = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            copy[key] = CopyDefaults(value)
        else
            copy[key] = value
        end
    end
    return copy
end

local function EnsureAppearanceDB()
    local profile = GetProfile()
    if type(profile) ~= "table" then
        return nil
    end

    if type(profile.Appearance) ~= "table" then
        profile.Appearance = CopyDefaults(DEFAULT_APPEARANCE)
    end

    local db = profile.Appearance
    if not db.basePreset then
        db.basePreset = DEFAULT_APPEARANCE.basePreset
    end
    if type(db.userOptions) ~= "table" then
        db.userOptions = CopyDefaults(DEFAULT_APPEARANCE.userOptions)
    end
    if type(db.tokenOverrides) ~= "table" then
        db.tokenOverrides = {}
    end

    for key, value in pairs(DEFAULT_APPEARANCE.userOptions) do
        if db.userOptions[key] == nil then
            db.userOptions[key] = value
        end
    end

    return db
end

local function ClearFrame(frame)
    if not frame then return end
    local keep = {}
    if frame.gui2Borders then
        keep[frame.gui2Borders.top] = true
        keep[frame.gui2Borders.bottom] = true
        keep[frame.gui2Borders.left] = true
        keep[frame.gui2Borders.right] = true
    end

    local children = { frame:GetChildren() }
    for _, child in ipairs(children) do
        child:Hide()
        child:SetParent(nil)
    end
    local regions = { frame:GetRegions() }
    for _, region in ipairs(regions) do
        if not keep[region] then
            region:Hide()
        end
    end
end

local function CreateHeader(parent, title, subtitle)
    local heading = GUI2:CreateText(parent, title, "font.size.title", "color.text.heading")
    heading:SetPoint("TOPLEFT", 18, -16)
    local body = GUI2:CreateText(parent, subtitle, "font.size.sm", "color.text.secondary")
    body:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -6)
    body:SetWidth(parent:GetWidth() - 36)
    body:SetWordWrap(true)
    return body
end

function Appearance:GetDB()
    return EnsureAppearanceDB()
end

function Appearance:PeekDB()
    local profile = GetProfile()
    if type(profile) ~= "table" then
        return nil
    end

    local db = profile.Appearance
    if type(db) == "table" then
        return db
    end

    return nil
end

function Appearance:ApplyStoredPreset()
    local db = self:PeekDB()
    if type(db) == "table" and db.basePreset then
        GUI2:SetPreset(db.basePreset)
        return true
    end
    return false
end

function Appearance:ApplyStoredPresetOnce()
    if storedPresetApplied then
        return true
    end

    if self:ApplyStoredPreset() then
        storedPresetApplied = true
        return true
    end

    return false
end

function Appearance:SetBasePreset(presetId, skipRender)
    local db = self:GetDB()
    if not db then return end
    db.basePreset = presetId or DEFAULT_APPEARANCE.basePreset
    GUI2:SetPreset(db.basePreset)
    if GUI2.Lab and GUI2.Lab.RefreshTheme then
        GUI2.Lab:RefreshTheme()
    end
    if not skipRender then
        self:Render()
    end
end

function Appearance:SetUserOption(key, value)
    local db = self:GetDB()
    if not db then return end
    db.userOptions[key] = value
    self:RenderPreview()
end

function Appearance:GetSettingsBackgroundMode()
    local db = self:GetDB()
    local mode = db and db.userOptions and db.userOptions.settingsBackground
    if mode == "solid" then
        return "solid"
    end
    return DEFAULT_APPEARANCE.userOptions.settingsBackground
end

function Appearance:SetSettingsBackgroundMode(mode)
    mode = mode == "solid" and "solid" or "artwork"
    local db = self:GetDB()
    if not db then return end
    db.userOptions.settingsBackground = mode
    if YUI.Settings and YUI.Settings.RefreshSettingsBackground then
        YUI.Settings:RefreshSettingsBackground()
    end
end

function Appearance:ResetCurrentPreset()
    local db = self:GetDB()
    if not db then return end
    local preset = db.basePreset or DEFAULT_APPEARANCE.basePreset
    db.userOptions = CopyDefaults(DEFAULT_APPEARANCE.userOptions)
    db.tokenOverrides = {}
    db.basePreset = preset
    GUI2:SetPreset(preset)
    self:Render()
end

function Appearance:Create()
    if self.frame then
        return self.frame
    end

    local frame = GUI2:CreatePanel(UIParent, {
        name = "YUI_GUI2_AppearanceFrame",
        width = 680,
        height = 520,
        surface = "color.surface.window",
        border = "color.border.strong",
        shadow = true,
        shadowKey = "shadow.popup.size",
    })
    frame:SetPoint("CENTER", 70, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:Hide()

    local close = GUI2:CreateCloseButton(frame, function()
        frame:Hide()
    end)
    close:SetPoint("TOPRIGHT", -14, -14)
    frame.close = close

    local content = GUI2:CreatePanel(frame, {
        surface = "color.surface.panel",
        border = "color.border.default",
    })
    content:SetPoint("TOPLEFT", 16, -58)
    content:SetPoint("BOTTOMRIGHT", -16, 16)
    frame.content = content

    self.frame = frame
    return frame
end

function Appearance:Open()
    local frame = self:Create()
    self:ApplyStoredPreset()
    self:Render()
    frame:Show()
end

function Appearance:Toggle()
    local frame = self:Create()
    if frame:IsShown() then
        frame:Hide()
    else
        self:Open()
    end
end

function Appearance:RenderPreview()
    if not self.previewPanel then return end
    ClearFrame(self.previewPanel)

    local db = self:GetDB()
    local options = db and db.userOptions or DEFAULT_APPEARANCE.userOptions

    local sampleButton = GUI2.Form:CreateButton(self.previewPanel, {
        text = "Preview button",
        width = 140,
        state = "selected",
    })
    sampleButton:SetPoint("TOPLEFT", 12, -12)

    local icon = GUI2:CreateIconSlot(self.previewPanel, {
        size = 42,
        shape = options.iconShape,
        selected = true,
        icon = "Interface\\Icons\\INV_Misc_Gear_01",
    })
    icon:SetPoint("LEFT", sampleButton, "RIGHT", 16, 0)

    local status = GUI2.Application:CreateStatusText(self.previewPanel, {
        width = 230,
        label = "Motion",
        value = options.motionStrength,
        tone = options.motionStrength == "off" and "warning" or "accent",
    })
    status:SetPoint("TOPLEFT", sampleButton, "BOTTOMLEFT", 0, -18)

    local text = GUI2:CreateText(self.previewPanel, "Theme options are saved with the active profile; advanced token editing is reserved for future tooling.", "font.size.sm", "color.text.secondary")
    text:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -10)
    text:SetWidth(self.previewPanel:GetWidth() - 24)
    text:SetWordWrap(true)
end

function Appearance:Render()
    local frame = self:Create()
    local content = frame.content
    ClearFrame(content)

    local db = self:GetDB()
    local options = db and db.userOptions or DEFAULT_APPEARANCE.userOptions
    local basePreset = db and db.basePreset or GUI2.activePresetId or DEFAULT_APPEARANCE.basePreset
    local selectedPresetId = GUI2.ResolvePresetId and GUI2:ResolvePresetId(basePreset) or basePreset

    CreateHeader(content, "主题外观 / Appearance", "GUI2 appearance options follow the active profile through YUI.DB.")

    local presetPanel = GUI2:CreatePanel(content, {
        width = 300,
        height = 178,
        surface = "color.surface.raised",
        border = "color.border.default",
        shadow = true,
    })
    presetPanel:SetPoint("TOPLEFT", 18, -84)
    local presetTitle = GUI2:CreateText(presetPanel, "Base Preset / 基础方案", "font.size.lg", "color.text.heading")
    presetTitle:SetPoint("TOPLEFT", 12, -10)

    local y = -42
    for _, preset in ipairs(GUI2:GetPresets()) do
        local button = GUI2.Form:CreateButton(presetPanel, {
            width = 256,
            text = GUI2:GetPresetDisplayName(preset),
            state = preset.id == selectedPresetId and "selected" or "normal",
            onClick = function()
                Appearance:SetBasePreset(preset.id)
            end,
        })
        button:SetPoint("TOPLEFT", 12, y)
        y = y - 34
    end

    local optionsPanel = GUI2:CreatePanel(content, {
        width = 318,
        height = 242,
        surface = "color.surface.raised",
        border = "color.border.default",
        shadow = true,
    })
    optionsPanel:SetPoint("TOPLEFT", presetPanel, "TOPRIGHT", 16, 0)
    local optionsTitle = GUI2:CreateText(optionsPanel, "User Options / 玩家选项", "font.size.lg", "color.text.heading")
    optionsTitle:SetPoint("TOPLEFT", 12, -10)

    local motionLabel = GUI2:CreateText(optionsPanel, "Motion strength", "font.size.sm", "color.text.secondary")
    motionLabel:SetPoint("TOPLEFT", 14, -44)
    local motion = GUI2.Form:CreateSegmentedControl(optionsPanel, {
        width = 276,
        value = options.motionStrength,
        items = {
            { text = "Off", value = "off" },
            { text = "Low", value = "low" },
            { text = "Std", value = "standard" },
            { text = "High", value = "high" },
        },
        onChange = function(value)
            Appearance:SetUserOption("motionStrength", value)
        end,
    })
    motion:SetPoint("TOPLEFT", motionLabel, "BOTTOMLEFT", 0, -6)

    local densityLabel = GUI2:CreateText(optionsPanel, "Density", "font.size.sm", "color.text.secondary")
    densityLabel:SetPoint("TOPLEFT", motion, "BOTTOMLEFT", 0, -14)
    local density = GUI2.Form:CreateSegmentedControl(optionsPanel, {
        width = 276,
        value = options.density,
        items = {
            { text = "Compact", value = "compact" },
            { text = "Standard", value = "standard" },
            { text = "Roomy", value = "roomy" },
        },
        onChange = function(value)
            Appearance:SetUserOption("density", value)
        end,
    })
    density:SetPoint("TOPLEFT", densityLabel, "BOTTOMLEFT", 0, -6)

    local shapeLabel = GUI2:CreateText(optionsPanel, "Icon shape", "font.size.sm", "color.text.secondary")
    shapeLabel:SetPoint("TOPLEFT", density, "BOTTOMLEFT", 0, -14)
    local shape = GUI2.Form:CreateSegmentedControl(optionsPanel, {
        width = 276,
        value = options.iconShape,
        items = {
            { text = "Square", value = "square" },
            { text = "Rounded", value = "rounded" },
            { text = "Circle", value = "circle" },
        },
        onChange = function(value)
            Appearance:SetUserOption("iconShape", value)
        end,
    })
    shape:SetPoint("TOPLEFT", shapeLabel, "BOTTOMLEFT", 0, -6)

    local preview = GUI2:CreatePanel(content, {
        width = 300,
        height = 156,
        surface = "color.surface.raised",
        border = "color.border.default",
        shadow = true,
    })
    preview:SetPoint("TOPLEFT", presetPanel, "BOTTOMLEFT", 0, -16)
    local previewTitle = GUI2:CreateText(preview, "Preview / 预览", "font.size.lg", "color.text.heading")
    previewTitle:SetPoint("TOPLEFT", 12, -10)
    local previewContent = CreateFrame("Frame", nil, preview)
    previewContent:SetPoint("TOPLEFT", 12, -40)
    previewContent:SetPoint("BOTTOMRIGHT", -12, 12)
    self.previewPanel = previewContent
    self:RenderPreview()

    local advanced = GUI2:CreatePanel(content, {
        width = 318,
        height = 92,
        surface = "color.surface.raised",
        border = "color.border.default",
        shadow = true,
    })
    advanced:SetPoint("TOPLEFT", optionsPanel, "BOTTOMLEFT", 0, -16)
    local advancedTitle = GUI2:CreateText(advanced, "Import / Export / 导入导出", "font.size.lg", "color.text.heading")
    advancedTitle:SetPoint("TOPLEFT", 12, -10)
    local reserved = GUI2:CreateText(advanced, "Format reserved: type = YUIAppearance, version = 1. Actual import/export is intentionally deferred.", "font.size.sm", "color.text.secondary")
    reserved:SetPoint("TOPLEFT", advancedTitle, "BOTTOMLEFT", 0, -8)
    reserved:SetWidth(292)
    reserved:SetWordWrap(true)

    local reset = GUI2.Form:CreateButton(content, {
        width = 220,
        text = "Reset current preset defaults",
        onClick = function()
            Appearance:ResetCurrentPreset()
        end,
    })
    reset:SetPoint("BOTTOMRIGHT", -18, 18)
end

if hooksecurefunc and YUI.OnProfileChanged then
    hooksecurefunc(YUI, "OnProfileChanged", function()
        Appearance:ApplyStoredPreset()
        if YUI.Settings and YUI.Settings.RefreshSettingsBackground then
            YUI.Settings:RefreshSettingsBackground()
        end
        if Appearance.frame and Appearance.frame:IsShown() then
            Appearance:Render()
        end
    end)
end

local function RegisterStoredPresetInit()
    if not YUI.Event then return end

    local owner = {}
    local function OnStoredPresetInit(event, arg1)
        if event == "ADDON_LOADED" and arg1 ~= YUI.AddonName then
            return
        end

        local applied = Appearance:ApplyStoredPresetOnce()
        if applied or event == "PLAYER_LOGIN" then
            YUI.Event:OffOwner(owner)
        end
    end

    YUI.Event:On("ADDON_LOADED", OnStoredPresetInit, owner)
    YUI.Event:On("PLAYER_LOGIN", OnStoredPresetInit, owner)
end

RegisterStoredPresetInit()
