local _, ns = ...

local CooldownFont = {}
ns.CooldownFont = CooldownFont

local LSM = LibStub("LibSharedMedia-3.0", true)

local areHooksInitialized = false

local viewersSettingKey = {
    EssentialCooldownViewer = "Essential",
    UtilityCooldownViewer = "Utility",
    BuffIconCooldownViewer = "BuffIcons",
}
local function GetCooldownFontName()
    if ns.db and ns.db.profile and ns.db.profile.cooldownManager_cooldownFontName then
        return ns.db.profile.cooldownManager_cooldownFontName
    end
    return "Friz Quadrata TT"
end
local function GetViewerCooldownSettings(viewerName)
    local map = {
        EssentialCooldownViewer = {
            size = ns.db.profile.cooldownManager_cooldownFontSizeEssential,
            enabled = ns.db.profile.cooldownManager_cooldownFontSizeEssential_enabled,
            default = 20,
        },
        UtilityCooldownViewer = {
            size = ns.db.profile.cooldownManager_cooldownFontSizeUtility,
            enabled = ns.db.profile.cooldownManager_cooldownFontSizeUtility_enabled,
            default = 12,
        },
        BuffIconCooldownViewer = {
            size = ns.db.profile.cooldownManager_cooldownFontSizeBuffIcons,
            enabled = ns.db.profile.cooldownManager_cooldownFontSizeBuffIcons_enabled,
            default = 16,
        },
    }
    local cfg = map[viewerName]
    if not cfg then
        return nil, false, nil
    end
    return cfg.size, cfg.enabled, cfg.default
end

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

local defaultFontSize = {}

local function SetIconCooldownFont(icon, viewerName)
    if icon.Cooldown.GetCountdownFontString then
        local fontString = icon.Cooldown:GetCountdownFontString()
        local size, enabled, _size = GetViewerCooldownSettings(viewerName)
        if not enabled then
            return
        end
        if not size or size == 0 then
            fontString:SetTextColor(0, 0, 0, 0)
            return
        end
        fontString:SetTextColor(1, 1, 1, 1)

        if size == "NIL" then
            size = _size
        end

        local fontName = ns.db.profile.cooldownManager_cooldownFontName or "Friz Quadrata TT"
        local fontPath = GetFontPath(fontName)
        local fontFlags = ns.db.profile.cooldownManager_cooldownFontFlags or {}
        local fontFlag = ""
        for n, v in pairs(fontFlags) do
            if v == true then
                fontFlag = fontFlag .. n .. ","
            end
        end
        fontString:SetFont(fontPath, size, fontFlag or "")
    end
end

-- Process all children of a viewer
local function ProcessViewer(viewerName)
    local viewer = _G[viewerName]
    if not viewer or not ns.Runtime:IsReady(viewerName) then
        return
    end

    local children = { viewer:GetChildren() }
    for _, child in ipairs(children) do
        if child.Icon and child.Cooldown then
            SetIconCooldownFont(child, viewerName)
        end
    end
end

function CooldownFont:RefreshViewer(viewerName)
    ProcessViewer(viewerName)
end

function CooldownFont:RefreshAll()
    for viewerName, _ in pairs(viewersSettingKey) do
        ProcessViewer(viewerName)
    end
end

function CooldownFont:Enable()
    if not areHooksInitialized then
        areHooksInitialized = true

        for viewerName, _ in pairs(viewersSettingKey) do
            local viewer = _G[viewerName]
            if viewer then
                hooksecurefunc(viewer, "RefreshLayout", function()
                    CooldownFont:RefreshViewer(viewerName)
                end)
            end
        end
    end

    self:RefreshAll()
end

function CooldownFont:Initialize()
    self:Enable()
end
