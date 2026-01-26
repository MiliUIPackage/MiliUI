-- Stacks

local _, ns = ...

local Stacks = {}
ns.Stacks = Stacks

local LSM = LibStub("LibSharedMedia-3.0", true)

local CMC_STACKS_DEBUG = false
local PrintDebug = function(...)
    if CMC_STACKS_DEBUG then
        print("[CMC Stacks]", ...)
    end
end

local viewerNames = {
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "BuffIconCooldownViewer",
}

local DEFAULT_FONT_PATH = "Fonts\\FRIZQT__.TTF"

local function GetFontPath(fontName)
    if not fontName or fontName == "" then
        return DEFAULT_FONT_PATH
    end

    if LSM then
        local fontPath = LSM:Fetch("font", fontName)
        if fontPath then
            return fontPath
        end
    end
    return DEFAULT_FONT_PATH
end

local function GetStackFontName()
    if ns.db and ns.db.profile and ns.db.profile.cooldownManager_stackFontName then
        return ns.db.profile.cooldownManager_stackFontName
    end
    return ns.DEFAULT_FONT_NAME or "Friz Quadrata TT"
end

local function GetViewerStackSettings(viewerName)
    local map = {
        EssentialCooldownViewer = {
            size = ns.db.profile.cooldownManager_stackFontSizeEssential,
            enabled = ns.db.profile.cooldownManager_stackAnchorEssential_enabled,
            point = ns.db.profile.cooldownManager_stackAnchorEssential_point,
            x = ns.db.profile.cooldownManager_stackAnchorEssential_offsetX,
            y = ns.db.profile.cooldownManager_stackAnchorEssential_offsetY,
        },
        UtilityCooldownViewer = {
            size = ns.db.profile.cooldownManager_stackFontSizeUtility,
            enabled = ns.db.profile.cooldownManager_stackAnchorUtility_enabled,
            point = ns.db.profile.cooldownManager_stackAnchorUtility_point,
            x = ns.db.profile.cooldownManager_stackAnchorUtility_offsetX,
            y = ns.db.profile.cooldownManager_stackAnchorUtility_offsetY,
        },
        BuffIconCooldownViewer = {
            size = ns.db.profile.cooldownManager_stackFontSizeBuffIcons,
            enabled = ns.db.profile.cooldownManager_stackAnchorBuffIcons_enabled,
            point = ns.db.profile.cooldownManager_stackAnchorBuffIcons_point,
            x = ns.db.profile.cooldownManager_stackAnchorBuffIcons_offsetX,
            y = ns.db.profile.cooldownManager_stackAnchorBuffIcons_offsetY,
        },
    }
    local cfg = map[viewerName]
    if not cfg then
        return nil, false, "BOTTOMRIGHT", 0, 0
    end
    return cfg.size, cfg.enabled, (cfg.point or "BOTTOMRIGHT"), (cfg.x or 0), (cfg.y or 0)
end

local function ApplyStackFont(viewerName, fontString, size)
    if not fontString or not size then
        return
    end

    local fontName = GetStackFontName()
    local fontPath = GetFontPath(fontName)
    local fontFlags = ns.db.profile.cooldownManager_stackFontFlags or {}
    local fontFlag = ""
    for n, v in pairs(fontFlags) do
        if v == true then
            fontFlag = fontFlag .. n .. ","
        end
    end
    fontString:SetFont(fontPath, size, fontFlag or "")
end

local function ApplyStackAnchor(fontString, parent, enabled, point, offsetX, offsetY)
    if not fontString or not parent or not enabled then
        return
    end
    fontString:ClearAllPoints()
    fontString:SetPoint(point, parent, point, offsetX or 0, offsetY or 0)
end

function Stacks:ApplyStackFonts(viewerName)
    local viewer = _G[viewerName]
    if not viewer then
        return
    end

    local fontSize, stackEnabled, stackPoint, stackX, stackY = GetViewerStackSettings(viewerName)
    if not stackEnabled then
        return
    end

    local children = { viewer:GetChildren() }
    for _, child in ipairs(children) do
        -- BuffIconCooldownViewer has Applications.Applications and other views have ChargeCount.Current
        local fs = child and child.Applications and child.Applications.Applications
            or child.ChargeCount and child.ChargeCount.Current

        if child.Applications and child.Applications.SetFrameLevel then
            child.Applications:SetFrameLevel(20)
        end
        if child.ChargeCount and child.ChargeCount.SetFrameLevel then
            child.ChargeCount:SetFrameLevel(20)
        end
        if fs then
            ApplyStackFont(viewerName, fs, fontSize)
            ApplyStackAnchor(fs, child, stackEnabled, stackPoint, stackX, stackY)
        end
    end
end

function Stacks:ApplyAllStackFonts()
    for _, viewerName in ipairs(viewerNames) do
        self:ApplyStackFonts(viewerName)
    end
end

function Stacks:OnSettingChanged()
    self:ApplyAllStackFonts()
end

function Stacks:Initialize()
    self:ApplyAllStackFonts()
end

EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", function()
    if ns.Stacks then
        ns.Stacks:OnSettingChanged()
    end
end)
