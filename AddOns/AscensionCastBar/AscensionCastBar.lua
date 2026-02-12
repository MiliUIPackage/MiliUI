-------------------------------------------------------------------------------
-- Project: AscensionCastBar
-- Author: Aka-DoctorCode 
-- File: AscensionCastBar.lua
-- Version: 40
-------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code are the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in 
-- derivative works without express written permission.
-------------------------------------------------------------------------------
local ADDON_NAME = "Ascension Cast Bar"
local AscensionCastBar = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceEvent-3.0", "AceConsole-3.0", "AceHook-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

-- ==========================================================
-- INITIALIZATION
-- ==========================================================

function AscensionCastBar:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("AscensionCastBarDB", self.defaults, "Default")

    local LibDualSpec = LibStub("LibDualSpec-1.0", true)
    if LibDualSpec then
        LibDualSpec:EnhanceDatabase(self.db, "Ascension Cast Bar")
    end

    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")

    self:SetupOptions()
    
    -- Llama a CreateBar definido en UI.lua (Versión Correcta)
    self:CreateBar() 
end

function AscensionCastBar:OnEnable()
    self:ValidateAnimationParams()
    self:UpdateDefaultCastBarVisibility()
    self:InitCDMHooks() -- Definido en UI.lua

    -- Register Events
    -- Estas funciones (HandleCastStart/Stop) ahora usarán las versiones de Logic.lua
    self:RegisterEvent("ADDON_LOADED", "InitCDMHooks")
    self:RegisterEvent("UNIT_SPELLCAST_START", "HandleCastStart")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", "HandleCastStart")
    self:RegisterEvent("UNIT_SPELLCAST_STOP", "HandleCastStop")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", "HandleCastStop")
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", "HandleCastStop")
    self:RegisterEvent("UNIT_SPELLCAST_FAILED", "HandleCastStop")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateDefaultCastBarVisibility")
    
    -- Eventos de Nameplates para anclaje dinámico
    self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

    -- Empowered Events
    pcall(function()
        self:RegisterEvent("UNIT_SPELLCAST_EMPOWER_START", "HandleCastStart")
        self:RegisterEvent("UNIT_SPELLCAST_EMPOWER_STOP", "HandleCastStop")
        self:RegisterEvent("UNIT_SPELLCAST_EMPOWER_UPDATE", "HandleCastStart")
    end)

    -- Chat Commands
    self:RegisterChatCommand("acb", "OpenConfig")
    self:RegisterChatCommand("ascensioncastbar", "OpenConfig")

    self:RefreshConfig()

    if self.castBar then
        self.castBar:Hide()
        self:UpdateAnchor()
    end
end

function AscensionCastBar:RefreshConfig()
    -- Todas estas funciones deben existir en UI.lua
    self:ValidateAnimationParams()
    self:UpdateAnchor()
    self:UpdateSparkSize()
    self:UpdateIcon()
    self:ApplyFont()
    self:UpdateBarColor()
    self:UpdateBackground()
    self:UpdateBorder()
    self:UpdateTextLayout()
    self:UpdateTextVisibility()
    self:UpdateSparkColors()
    self:UpdateDefaultCastBarVisibility()
end

-- ==========================================================
-- HELPER FUNCTIONS (Non-UI, Non-Logic)
-- ==========================================================

function AscensionCastBar:ClampAlpha(v)
    v = tonumber(v) or 0
    if v ~= v then return 0 end                   -- NaN
    if math.abs(v) == math.huge then return 1 end -- Infinite
    if v < 0 then v = 0 elseif v > 1 then v = 1 end
    return v
end

function AscensionCastBar:GetBlizzardCastBars()
    local frames = {}
    if _G["CastingBarFrame"] then table.insert(frames, _G["CastingBarFrame"]) end
    if _G["PlayerCastingBarFrame"] then table.insert(frames, _G["PlayerCastingBarFrame"]) end
    return frames
end

function AscensionCastBar:UpdateDefaultCastBarVisibility()
    local hide = self.db.profile.hideDefaultCastbar
    local frames = self:GetBlizzardCastBars()

    for _, frame in ipairs(frames) do
        if frame then
            if hide then
                frame:UnregisterAllEvents()
                frame:Hide()
            else
                frame:RegisterEvent("UNIT_SPELLCAST_START")
                frame:RegisterEvent("UNIT_SPELLCAST_STOP")
                frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
                frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
            end
        end
    end
end

function AscensionCastBar:NAME_PLATE_UNIT_ADDED(event, unit)
    if unit == "player" and self.db.profile.cdmTarget == "PersonalResource" then
        self:UpdateAnchor()
    end
end

function AscensionCastBar:NAME_PLATE_UNIT_REMOVED(event, unit)
    if unit == "player" and self.db.profile.cdmTarget == "PersonalResource" then
        self:UpdateAnchor()
    end
end

function AscensionCastBar:OpenConfig()
    LibStub("AceConfigDialog-3.0"):Open(ADDON_NAME)
    local widget = LibStub("AceConfigDialog-3.0").OpenFrames[ADDON_NAME]
    if widget and widget.frame then
        widget.frame:SetWidth(440)
        widget.frame:SetHeight(500)
        widget.frame:SetBackdropColor(0, 0, 0, 1)
    end
end

-- ==========================================================
-- ANIMATION PARAMETERS VALIDATION
-- ==========================================================

function AscensionCastBar:ResetAnimationParams(style)
    if style and self.ANIMATION_STYLE_PARAMS[style] then
        self.db.profile.animationParams[style] = CopyTable(self.ANIMATION_STYLE_PARAMS[style])
    else
        for styleName, defaults in pairs(self.ANIMATION_STYLE_PARAMS) do
            self.db.profile.animationParams[styleName] = CopyTable(defaults)
        end
    end
    self:RefreshConfig()
end

function AscensionCastBar:ValidateAnimationParams()
    local db = self.db.profile
    if not db.animationParams then db.animationParams = {} end
    
    -- Ensure defaults exist
    if self.ANIMATION_STYLE_PARAMS then
        for styleName, defaults in pairs(self.ANIMATION_STYLE_PARAMS) do
            if not db.animationParams[styleName] then
                db.animationParams[styleName] = {}
            end
            for key, value in pairs(defaults) do
                if db.animationParams[styleName][key] == nil then
                    db.animationParams[styleName][key] = value
                end
            end
        end
    end
end

-- Helper local para CopyTable si no existe
local function CopyTable(orig)
    local copy = {}
    for key, value in pairs(orig) do
        if type(value) == "table" then copy[key] = CopyTable(value) else copy[key] = value end
    end
    return copy
end
