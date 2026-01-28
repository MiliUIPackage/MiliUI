-------------------------------------------------------------------------------
-- Project: AscensionCastBar
-- Author: Aka-DoctorCode 
-- File: Config.lua
-- Version: 12.0.0
-------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code are the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in 
-- derivative works without express written permission.
-------------------------------------------------------------------------------
local ADDON_NAME = "Ascension Cast Bar"
local AscensionCastBar = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local LSM = LibStub("LibSharedMedia-3.0")

-- ==========================================================
-- DEFAULTS
-- ==========================================================

local BAR_DEFAULT_FONT_PATH = "Interface\\AddOns\\AscensionCastBar\\COLLEGIA.ttf"

local function CopyTable(orig)
    local copy = {}
    for key, value in pairs(orig) do
        if type(value) == "table" then
            copy[key] = CopyTable(value)
        else
            copy[key] = value
        end
    end
    return copy
end

AscensionCastBar.defaults = {
    profile = {
        showChannelTicks = true,
        -- channelTicksColor = {0, 0, 0, 1}, -- Color de ticks 
        channelTicksThickness = 1,
        
        height = 24,
        testAttached = false,

        -- Manual / Fallback Settings
        manualWidth = 270,
        manualHeight = 24,
        point = "CENTER",
        relativePoint = "CENTER",
        manualX = 0,
        manualY = -85,

        -- Empower Colors
        empowerStage1Color = { 0, 1, 0, 1 },    -- Green
        empowerStage2Color = { 1, 1, 0, 1 },    -- Yellow
        empowerStage3Color = { 1, 0.64, 0, 1 }, -- Orange
        empowerStage4Color = { 1, 0, 0, 1 },    -- Red
        empowerStage5Color = { 0.6, 0, 1, 1 },  -- Purple (Default)

        -- Channel Ticks
        showChannelTicks = true,
        channelTicksColor = { 1, 1, 1, 0.5 },
        channelTicksThickness = 1,

        -- Channel Colors
        useChannelColor = true,
        channelColor = { 0.5, 0.5, 1, 1 },
        channelBorderGlow = false,
        channelGlowColor = { 0, 0.8, 1, 1 },

        -- Fonts/Text
        spellNameFontSize = 14,
        timerFontSize = 14,
        fontPath = BAR_DEFAULT_FONT_PATH,
        fontColor = { 0.8078, 1, 0.9529, 1 },
        showSpellText = true,
        showTimerText = true,
        spellNameFontLSM = "Expressway, Bold",
        timerFontLSM = "Boris Black Bloxx",
        detachText = false,
        textX = 0,
        textY = 40,
        textWidth = 270,
        textBackdropEnabled = false,
        textBackdropColor = { 0, 0, 0, 0.5 },
        timerFormat = "Remaining",
        truncateSpellName = false,
        truncateLength = 30,

        -- Colors
        barColor = { 0, 0.0274, 0.2509, 1 },
        barLSMName = "Solid",
        useClassColor = false,

        -- Anim
        enableSpark = true,
        enableTails = true,
        animStyle = "Comet",
        sparkColor = { 0.937, 0.984, 1, 1 },
        glowColor = { 1, 1, 1, 1 },
        sparkIntensity = 1,
        glowIntensity = 0.5,
        sparkScale = 3,
        sparkOffset = 1.27,
        headLengthOffset = -23,

        -- Tail Colors
        tailLength = 200,
        tailOffset = -14.68,
        tail1Color = { 1, 0, 0.09, 1 },
        tail1Intensity = 1,
        tail1Length = 95,
        tail2Color = { 0, 0.98, 1, 1 },
        tail2Intensity = 0.42,
        tail2Length = 215,
        tail3Color = { 0, 1, 0.22, 1 },
        tail3Intensity = 0.68,
        tail3Length = 80,
        tail4Color = { 1, 0, 0.8, 1 },
        tail4Intensity = 0.61,
        tail4Length = 150,

        -- Icon
        showIcon = false,
        detachIcon = false,
        iconAnchor = "Left",
        iconSize = 24,
        iconX = 0,
        iconY = 0,

        -- BG
        bgColor = { 0, 0, 0, 0.65 },
        borderEnabled = true,
        borderColor = { 0, 0, 0, 1 },
        borderThickness = 2,

        -- Behavior
        hideTimerOnChannel = false,
        hideDefaultCastbar = true,
        reverseChanneling = false,
        showLatency = true,
        latencyColor = { 1, 0, 0, 0.5 },
        latencyMaxPercent = 1.0,

        -- CDM
        attachToCDM = true,
        cdmTarget = "Essential",
        cdmYOffset = 0,
        previewEnabled = false,
        testModeState = "Cast",

        -- Animation Parameters by Style
        animationParams = {
            Comet = {
                tailOffset = -14.68,
                headLengthOffset = -23,
                tailLength = 200,
            },
            Orb = {
                rotationSpeed = 8,
                radiusMultiplier = 0.4,
                glowPulse = 1.0,
            },
            Pulse = {
                maxScale = 2.5,
                rippleCycle = 1,
                fadeSpeed = 1.0,
            },
            Starfall = {
                fallSpeed = 2.5,
                swayAmount = 8,
                particleSpeed = 3.8,
            },
            Flux = {
                jitterY = 3.5,
                jitterX = 2.5,
                driftMultiplier = 0.05,
            },
            Helix = {
                driftMultiplier = 0.1,
                amplitude = 0.4,
                waveSpeed = 8,
            },
            Wave = {
                waveCount = 3,
                waveSpeed = 0.4,
                amplitude = 0.05,
                waveWidth = 0.25,
            },
            Glitch = {
                glitchChance = 0.1,
                maxOffset = 5,
                colorIntensity = 0.3,
            },
            Lightning = {
                lightningChance = 0.3,
                segmentCount = 3,
            }
        }
    }
}

-- ==========================================================
-- ACE CONFIG (OPTIONS)
-- ==========================================================

function AscensionCastBar:SetupOptions()
    local anchors = {
        ["CENTER"] = "Center",
    }

    local options = {
        name = ADDON_NAME,
        handler = AscensionCastBar,
        type = "group",
        args = {
            general = {
                name = "General",
                type = "group",
                order = 1,
                args = {
                    headerCommon = { name = "Test Mode", type = "header", order = 10 },
                    hideDefaultCastbar = {
                        name = "Hide Default Cast Bar",
                        desc = "Hides the standard Blizzard casting bar.",
                        type = "toggle",
                        order = 11,
                        get = function(info) return self.db.profile.hideDefaultCastbar end,
                        set = function(info, val)
                            self.db.profile.hideDefaultCastbar = val
                            self:UpdateDefaultCastBarVisibility()
                        end,
                    },
                    preview = {
                        name = "Test Mode",
                        desc = "Show a preview cast to configure visuals.",
                        type = "toggle",
                        order = 12,
                        get = function(info) return self.db.profile.previewEnabled end,
                        set = function(info, val)
                            self.db.profile.previewEnabled = val
                            if not val then self.db.profile.testAttached = false end -- Disable attached test if main off
                            self:ToggleTestMode(val)
                        end,
                    },
                    testModeState = {
                        name = "Test Animation",
                        desc = "Select the type of spell to preview.",
                        type = "select",
                        values = { ["Cast"] = "Cast", ["Channel"] = "Channel", ["Empowered"] = "Empowered" },
                        order = 13,
                        disabled = function() return not self.db.profile.previewEnabled end,
                        get = function(info) return self.db.profile.testModeState end,
                        set = function(info, val)
                            self.db.profile.testModeState = val
                            if self.db.profile.previewEnabled then self:ToggleTestMode(true) end
                        end,
                    },
                    headerManual = {
                        name = "Manual Position & Size",
                        type = "header",
                        order = 20,
                    },
                    point = {
                        name = "Anchor Point",
                        type = "select",
                        values = anchors,
                        order = 21,
                        get = function(info) return self.db.profile.point end,
                        set = function(info, val)
                            self.db.profile.point = val; self:UpdateAnchor()
                        end,
                    },
                    manualX = {
                        name = "X Offset",
                        type = "range",
                        min = -2000,
                        max = 2000,
                        step = 1,
                        order = 22,
                        get = function(info) return self.db.profile.manualX end,
                        set = function(info, val)
                            self.db.profile.manualX = val; self:UpdateAnchor()
                        end,
                    },
                    manualY = {
                        name = "Y Offset",
                        type = "range",
                        min = -2000,
                        max = 2000,
                        step = 1,
                        order = 23,
                        get = function(info) return self.db.profile.manualY end,
                        set = function(info, val)
                            self.db.profile.manualY = val; self:UpdateAnchor()
                        end,
                    },
                    manualWidth = {
                        name = "Width",
                        type = "range",
                        min = 100,
                        max = 1000,
                        step = 1,
                        order = 24,
                        get = function(info) return self.db.profile.manualWidth end,
                        set = function(info, val)
                            self.db.profile.manualWidth = val; self:UpdateAnchor()
                        end,
                    },
                    manualHeight = {
                        name = "Height",
                        type = "range",
                        min = 10,
                        max = 100,
                        step = 1,
                        order = 25,
                        get = function(info) return self.db.profile.manualHeight end,
                        set = function(info, val)
                            self.db.profile.manualHeight = val
                            if not self.db.profile.attachToCDM then
                                self.castBar:SetHeight(val)
                                self:UpdateSparkSize()
                                self:UpdateIcon()
                            end
                        end,
                    },
                }
            },
            attachment = {
                name = "Attachment",
                type = "group",
                order = 2,
                args = {
                    testAttached = {
                        name = "Test Attached Mode",
                        desc = "Force the bar to show in the 'Attached' position (simulated) to adjust settings.",
                        type = "toggle",
                        order = 0.5,
                        hidden = function() return not self.db.profile.attachToCDM end,
                        get = function(info) return self.db.profile.testAttached end,
                        set = function(info, val)
                            self.db.profile.testAttached = val
                            self.db.profile.previewEnabled = val -- Auto-enable preview
                            self:ToggleTestMode(val)
                            self:UpdateAnchor()                  -- Force update
                        end,
                    },
                    attachToCDM = {
                        name = "Enable Attachment",
                        desc = "Attempt to attach the cast bar to another frame (e.g. Player Frame, Action Bar).",
                        type = "toggle",
                        width = "full",
                        order = 1,
                        get = function(info) return self.db.profile.attachToCDM end,
                        set = function(info, val)
                            self.db.profile.attachToCDM = val; self:InitCDMHooks(); self:UpdateAnchor()
                        end,
                    },
                    height = {
                        name = "Height",
                        type = "range",
                        min = 10,
                        max = 100,
                        step = 1,
                        order = 1,
                        hidden = function() return not self.db.profile.attachToCDM end,
                        get = function(info) return self.db.profile.height end,
                        set = function(info, val)
                            self.db.profile.height = val
                            self.castBar:SetHeight(val)
                            self:UpdateSparkSize()
                            self:UpdateIcon()
                        end,
                    },
                    cdmTarget = {
                        name = "Attach Target",
                        type = "select",
                        style = "dropdown",
                        values = { 
                            ["Buffs"] = "Tracked Buffs (CDM)", 
                            ["Essential"] = "Essential Cooldowns (CDM)", 
                            ["Utility"] = "Utility Cooldowns (CDM)", 
                            ["PlayerFrame"] = "Player Frame",
                            ["PersonalResource"] = "Personal Resource Display",
                            ["ActionBar1"] = "Action Bar 1",
                            ["ActionBar2"] = "Action Bar 2",
                            ["ActionBar3"] = "Action Bar 3",
                            ["ActionBar4"] = "Action Bar 4",
                            ["ActionBar5"] = "Action Bar 5",
                            ["ActionBar6"] = "Action Bar 6",
                            ["ActionBar7"] = "Action Bar 7",
                            ["ActionBar8"] = "Action Bar 8",
                            ["BT4Bonus"] = "Bonus Action Bar (BT4)",
                            ["BT4Class1"] = "Class Bar 1 (BT4)",
                            ["BT4Class2"] = "Class Bar 2 (BT4)",
                            ["BT4Class3"] = "Class Bar 3 (BT4)",
                            ["BT4Class4"] = "Class Bar 4 (BT4)"
                        },
                        order = 2,
                        get = function(info) return self.db.profile.cdmTarget end,
                        set = function(info, val)
                            self.db.profile.cdmTarget = val; self:InitCDMHooks(); self:UpdateAnchor()
                        end,
                    },
                    cdmYOffset = {
                        name = "Y Offset",
                        type = "range",
                        min = -200,
                        max = 200,
                        step = 1,
                        order = 3,
                        get = function(info) return self.db.profile.cdmYOffset end,
                        set = function(info, val)
                            self.db.profile.cdmYOffset = val; self:UpdateAnchor()
                        end,
                    },
                },
            },
            visuals = {
                name = "Visuals",
                type = "group",
                order = 2,
                args = {
                    headerColors = { name = "Colors", type = "header", order = 0 },
                    useClassColor = {
                        name = "Use Class Color",
                        type = "toggle",
                        order = 1,
                        get = function(info) return self.db.profile.useClassColor end,
                        set = function(info, val)
                            self.db.profile.useClassColor = val; self:UpdateBarColor()
                        end,
                    },
                    barColor = {
                        name = "Bar Color",
                        type = "color",
                        hasAlpha = true,
                        order = 2,
                        get = function(info)
                            local c = self.db.profile.barColor; return c[1], c[2], c[3], c[4]
                        end,
                        set = function(info, r, g, b, a)
                            self.db.profile.barColor = { r, g, b, a }; self:UpdateBarColor()
                        end,
                    },
                    bgColor = {
                        name = "Background Color",
                        type = "color",
                        hasAlpha = true,
                        order = 3,
                        get = function(info)
                            local c = self.db.profile.bgColor; return c[1], c[2], c[3], c[4]
                        end,
                        set = function(info, r, g, b, a)
                            self.db.profile.bgColor = { r, g, b, a }; self:UpdateBackground()
                        end,
                    },
                    headerBorder = { name = "Border", type = "header", order = 10 },
                    borderEnabled = {
                        name = "Enable Border",
                        type = "toggle",
                        order = 11,
                        get = function(info) return self.db.profile.borderEnabled end,
                        set = function(info, val)
                            self.db.profile.borderEnabled = val; self:UpdateBorder()
                        end,
                    },
                    borderColor = {
                        name = "Border Color",
                        type = "color",
                        hasAlpha = true,
                        order = 12,
                        get = function(info)
                            local c = self.db.profile.borderColor; return c[1], c[2], c[3], c[4]
                        end,
                        set = function(info, r, g, b, a)
                            self.db.profile.borderColor = { r, g, b, a }; self:UpdateBorder()
                        end,
                    },
                    borderThickness = {
                        name = "Thickness",
                        type = "range",
                        min = 1,
                        max = 10,
                        step = 1,
                        order = 13,
                        get = function(info) return self.db.profile.borderThickness end,
                        set = function(info, val)
                            self.db.profile.borderThickness = val; self:UpdateBorder()
                        end,
                    },
                    headerIcon = { name = "Icon", type = "header", order = 20 },
                    showIcon = {
                        name = "Show Icon",
                        type = "toggle",
                        order = 21,
                        get = function(info) return self.db.profile.showIcon end,
                        set = function(info, val)
                            self.db.profile.showIcon = val; self:UpdateIcon()
                        end,
                    },
                    detachIcon = {
                        name = "Detach Icon",
                        type = "toggle",
                        order = 22,
                        get = function(info) return self.db.profile.detachIcon end,
                        set = function(info, val)
                            self.db.profile.detachIcon = val; self:UpdateIcon()
                        end,
                    },
                    iconAnchor = {
                        name = "Icon Position",
                        type = "select",
                        values = { ["Left"] = "Left", ["Right"] = "Right" },
                        order = 23,
                        get = function(info) return self.db.profile.iconAnchor end,
                        set = function(info, val)
                            self.db.profile.iconAnchor = val; self:UpdateIcon()
                        end,
                    },
                    iconSize = {
                        name = "Icon Size",
                        type = "range",
                        min = 10,
                        max = 128,
                        step = 1,
                        order = 24,
                        get = function(info) return self.db.profile.iconSize end,
                        set = function(info, val)
                            self.db.profile.iconSize = val; self:UpdateIcon()
                        end,
                    },
                    iconX = {
                        name = "Icon X",
                        type = "range",
                        min = -200,
                        max = 200,
                        step = 1,
                        order = 25,
                        get = function(info) return self.db.profile.iconX end,
                        set = function(info, val)
                            self.db.profile.iconX = val; self:UpdateIcon()
                        end,
                    },
                    iconY = {
                        name = "Icon Y",
                        type = "range",
                        min = -200,
                        max = 200,
                        step = 1,
                        order = 26,
                        get = function(info) return self.db.profile.iconY end,
                        set = function(info, val)
                            self.db.profile.iconY = val; self:UpdateIcon()
                        end,
                    },
                    headerCombat = { name = "Combat & Channels", type = "header", order = 30 },
                    -- CHANNELS
                    spacer1 = { name = " ", type = "description", order = 35 },
                    showChannelTicks = {
                        name = "Show Ticks",
                        type = "toggle",
                        order = 36,
                        get = function(info) return self.db.profile.showChannelTicks end,
                        set = function(info, val) self.db.profile.showChannelTicks = val end,
                    },
                    channelTicksThickness = {
                        name = "Tick Thickness",
                        type = "range",
                        min = 1,
                        max = 10,
                        step = 1,
                        order = 36.1,
                        disabled = function() return not self.db.profile.showChannelTicks end,
                        get = function(info) return self.db.profile.channelTicksThickness end,
                        set = function(info, val) self.db.profile.channelTicksThickness = val end,
                    },
                    channelTicksColor = {
                        name = "Tick Color",
                        type = "color",
                        hasAlpha = true,
                        order = 36.2,
                        disabled = function() return not self.db.profile.showChannelTicks end,
                        get = function(info)
                            local c = self.db.profile.channelTicksColor
                            return c[1], c[2], c[3], c[4]
                        end,
                        set = function(info, r, g, b, a)
                            self.db.profile.channelTicksColor = { r, g, b, a }
                        end,
                    },
                    headerEmpower = { name = "Empowered Spells", type = "header", order = 45 },
                    empowerStage1Color = {
                        name = "Stage 1 (Start)",
                        type = "color",
                        hasAlpha = true,
                        order = 46,
                        get = function(info)
                            local c = self.db.profile.empowerStage1Color; return c[1], c[2], c[3], c[4]
                        end,
                        set = function(info, r, g, b, a) self.db.profile.empowerStage1Color = { r, g, b, a } end,
                    },
                    empowerStage2Color = {
                        name = "Stage 2",
                        type = "color",
                        hasAlpha = true,
                        order = 47,
                        get = function(info)
                            local c = self.db.profile.empowerStage2Color; return c[1], c[2], c[3], c[4]
                        end,
                        set = function(info, r, g, b, a) self.db.profile.empowerStage2Color = { r, g, b, a } end,
                    },
                    empowerStage3Color = {
                        name = "Stage 3",
                        type = "color",
                        hasAlpha = true,
                        order = 48,
                        get = function(info)
                            local c = self.db.profile.empowerStage3Color; return c[1], c[2], c[3], c[4]
                        end,
                        set = function(info, r, g, b, a) self.db.profile.empowerStage3Color = { r, g, b, a } end,
                    },
                    empowerStage4Color = {
                        name = "Stage 4",
                        type = "color",
                        hasAlpha = true,
                        order = 49,
                        get = function(info)
                            local c = self.db.profile.empowerStage4Color; return c[1], c[2], c[3], c[4]
                        end,
                        set = function(info, r, g, b, a) self.db.profile.empowerStage4Color = { r, g, b, a } end,
                    },
                    empowerStage5Color = {
                        name = "Stage 5 (Max Hold)",
                        desc = "Color for the extra final stage.",
                        type = "color",
                        hasAlpha = true,
                        order = 50,
                        get = function(info)
                            local c = self.db.profile.empowerStage5Color; return c[1], c[2], c[3], c[4]
                        end,
                        set = function(info, r, g, b, a) self.db.profile.empowerStage5Color = { r, g, b, a } end,
                    },
                    useChannelColor = {
                        name = "Custom Channel Color",
                        desc = "Use a specific color for channeled spells.",
                        type = "toggle",
                        order = 37,
                        get = function(info) return self.db.profile.useChannelColor end,
                        set = function(info, val) self.db.profile.useChannelColor = val end,
                    },
                    channelColor = {
                        name = "Channel Bar Color",
                        type = "color",
                        hasAlpha = true,
                        order = 38,
                        disabled = function() return not self.db.profile.useChannelColor end,
                        get = function(info)
                            local c = self.db.profile.channelColor; return c[1], c[2], c[3], c[4]
                        end,
                        set = function(info, r, g, b, a) self.db.profile.channelColor = { r, g, b, a }; end,
                    },
                    channelBorderGlow = {
                        name = "Channel Glow",
                        desc = "Glow the border when channeling.",
                        type = "toggle",
                        order = 39,
                        get = function(info) return self.db.profile.channelBorderGlow end,
                        set = function(info, val) self.db.profile.channelBorderGlow = val end,
                    },
                    channelGlowColor = {
                        name = "Channel Glow Color",
                        type = "color",
                        hasAlpha = true,
                        order = 40,
                        disabled = function() return not self.db.profile.channelBorderGlow end,
                        get = function(info)
                            local c = self.db.profile.channelGlowColor; return c[1], c[2], c[3], c[4]
                        end,
                        set = function(info, r, g, b, a) self.db.profile.channelGlowColor = { r, g, b, a }; end,
                    },
                    reverseChanneling = {
                        name = "Reverse Channeling",
                        desc = "Fill bar instead of empty for channels.",
                        type = "toggle",
                        order = 41,
                        get = function(info) return self.db.profile.reverseChanneling end,
                        set = function(info, val) self.db.profile.reverseChanneling = val end,
                    },
                    showLatency = {
                        name = "Show Latency",
                        type = "toggle",
                        order = 34.5,
                        get = function(info) return self.db.profile.showLatency end,
                        set = function(info, val) self.db.profile.showLatency = val end,
                    },
                }
            },
            text = {
                name = "Text",
                type = "group",
                order = 3,
                args = {
                    showSpellText = {
                        name = "Show Spell Name",
                        type = "toggle",
                        order = 1,
                        get = function(info) return self.db.profile.showSpellText end,
                        set = function(info, val) self.db.profile.showSpellText = val end,
                    },
                    showTimerText = {
                        name = "Show Timer",
                        type = "toggle",
                        order = 2,
                        get = function(info) return self.db.profile.showTimerText end,
                        set = function(info, val) self.db.profile.showTimerText = val end,
                    },
                    hideTimerOnChannel = {
                        name = "Hide Timer on Channel",
                        type = "toggle",
                        order = 3,
                        get = function(info) return self.db.profile.hideTimerOnChannel end,
                        set = function(info, val) self.db.profile.hideTimerOnChannel = val end,
                    },
                    timerFormat = {
                        name = "Timer Format",
                        type = "select",
                        values = { ["Remaining"] = "Remaining", ["Duration"] = "Duration", ["Total"] = "Total" },
                        order = 4,
                        get = function(info) return self.db.profile.timerFormat end,
                        set = function(info, val) self.db.profile.timerFormat = val end,
                    },
                    truncateSpellName = {
                        name = "Truncate Name",
                        type = "toggle",
                        order = 5,
                        get = function(info) return self.db.profile.truncateSpellName end,
                        set = function(info, val) self.db.profile.truncateSpellName = val end,
                    },
                    truncateLength = {
                        name = "Max Characters",
                        type = "range",
                        min = 5,
                        max = 100,
                        step = 1,
                        order = 6,
                        get = function(info) return self.db.profile.truncateLength end,
                        set = function(info, val) self.db.profile.truncateLength = val end,
                    },
                    fontSizeSpell = {
                        name = "Spell Font Size",
                        type = "range",
                        min = 8,
                        max = 32,
                        step = 1,
                        order = 10,
                        get = function(info) return self.db.profile.spellNameFontSize end,
                        set = function(info, val)
                            self.db.profile.spellNameFontSize = val; self:ApplyFont()
                        end,
                    },
                    fontSizeTimer = {
                        name = "Timer Font Size",
                        type = "range",
                        min = 8,
                        max = 32,
                        step = 1,
                        order = 11,
                        get = function(info) return self.db.profile.timerFontSize end,
                        set = function(info, val)
                            self.db.profile.timerFontSize = val; self:ApplyFont()
                        end,
                    },
                    font = {
                        name = "Font",
                        type = "select",
                        values = function()
                            local fonts = {}
                            for _, name in ipairs(LSM:List("font")) do
                                fonts[name] = name
                            end
                            return fonts
                        end,
                        order = 12,
                        get = function(info) return self.db.profile.spellNameFontLSM end,
                        set = function(info, val)
                            self.db.profile.spellNameFontLSM = val
                            self.db.profile.timerFontLSM = val
                            self:ApplyFont()
                        end,
                    },
                }
            },
            animation = {
                name = "Animation",
                type = "group",
                order = 4,
                args = {
                    enableSpark = {
                        name = "Enable Spark",
                        type = "toggle",
                        order = 1,
                        get = function(info) return self.db.profile.enableSpark end,
                        set = function(info, val) self.db.profile.enableSpark = val end,
                    },
                    animStyle = {
                        name = "Animation Style",
                        type = "select",
                        order = 2,
                        values = {
                            ["Comet"] = "Comet",
                            ["Orb"] = "Orb",
                            ["Flux"] = "Flux",
                            ["Helix"] = "Helix",
                            ["Pulse"] = "Pulse",
                            ["Starfall"] = "Starfall",
                            ["Wave"] = "Wave",
                            ["Glitch"] = "Glitch",
                            ["Lightning"] = "Lightning",
                        },
                        get = function(info) return self.db.profile.animStyle end,
                        set = function(info, val)
                            self.db.profile.animStyle = val
                            -- Asegurarnos de que los parámetros existan para el estilo seleccionado
                            if not self.db.profile.animationParams[val] then
                                self.db.profile.animationParams[val] = CopyTable(self.ANIMATION_STYLE_PARAMS[val])
                            end
                        end,
                    },
                    -- PARÁMETROS ESPECÍFICOS POR ESTILO
                    styleSpecificGroup = {
                        name = "Style Specific Settings",
                        type = "group",
                        inline = true,
                        order = 2.5,
                        hidden = function()
                            local style = self.db.profile.animStyle
                            -- Ocultar si el estilo es Comet (ya tiene sus propias opciones en Tail Settings)
                            -- También ocultar si no hay parámetros específicos para el estilo
                            return style == "Comet" or not self.db.profile.animationParams[style]
                        end,
                        args = {
                            -- Orb Settings
                            orbRotationSpeed = {
                                name = "Rotation Speed",
                                type = "range",
                                min = 1,
                                max = 20,
                                step = 1,
                                order = 1,
                                hidden = function() return self.db.profile.animStyle ~= "Orb" end,
                                get = function(info)
                                    local style = self.db.profile.animStyle
                                    return self.db.profile.animationParams[style].rotationSpeed
                                end,
                                set = function(info, val)
                                    local style = self.db.profile.animStyle
                                    self.db.profile.animationParams[style].rotationSpeed = val
                                end,
                            },
                            orbRadius = {
                                name = "Orb Radius",
                                desc = "Distance from center (multiplier of bar height)",
                                type = "range",
                                min = 0.1,
                                max = 1.0,
                                step = 0.1,
                                order = 2,
                                hidden = function() return self.db.profile.animStyle ~= "Orb" end,
                                get = function(info)
                                    local style = self.db.profile.animStyle
                                    return self.db.profile.animationParams[style].radiusMultiplier
                                end,
                                set = function(info, val)
                                    local style = self.db.profile.animStyle
                                    self.db.profile.animationParams[style].radiusMultiplier = val
                                end,
                            },
                            orbGlowPulse = {
                                name = "Glow Pulse",
                                type = "range",
                                min = 0.1,
                                max = 2.0,
                                step = 0.1,
                                order = 3,
                                hidden = function() return self.db.profile.animStyle ~= "Orb" end,
                                get = function(info)
                                    local style = self.db.profile.animStyle
                                    return self.db.profile.animationParams[style].glowPulse
                                end,
                                set = function(info, val)
                                    local style = self.db.profile.animStyle
                                    self.db.profile.animationParams[style].glowPulse = val
                                end,
                            },
                            -- Pulse Settings
                            pulseMaxScale = {
                                name = "Max Ripple Scale",
                                type = "range",
                                min = 1.0,
                                max = 5.0,
                                step = 0.1,
                                order = 10,
                                hidden = function() return self.db.profile.animStyle ~= "Pulse" end,
                                get = function(info)
                                    local style = self.db.profile.animStyle
                                    return self.db.profile.animationParams[style].maxScale
                                end,
                                set = function(info, val)
                                    local style = self.db.profile.animStyle
                                    self.db.profile.animationParams[style].maxScale = val
                                end,
                            },
                            pulseRippleCycle = {
                                name = "Ripple Cycle",
                                desc = "Speed of ripple animation",
                                type = "range",
                                min = 0.5,
                                max = 3.0,
                                step = 0.1,
                                order = 11,
                                hidden = function() return self.db.profile.animStyle ~= "Pulse" end,
                                get = function(info)
                                    local style = self.db.profile.animStyle
                                    return self.db.profile.animationParams[style].rippleCycle
                                end,
                                set = function(info, val)
                                    local style = self.db.profile.animStyle
                                    self.db.profile.animationParams[style].rippleCycle = val
                                end,
                            },
                            -- Starfall Settings
                            starfallFallSpeed = {
                                name = "Fall Speed",
                                type = "range",
                                min = 1.0,
                                max = 10.0,
                                step = 0.5,
                                order = 20,
                                hidden = function() return self.db.profile.animStyle ~= "Starfall" end,
                                get = function(info)
                                    local style = self.db.profile.animStyle
                                    return self.db.profile.animationParams[style].fallSpeed
                                end,
                                set = function(info, val)
                                    local style = self.db.profile.animStyle
                                    self.db.profile.animationParams[style].fallSpeed = val
                                end,
                            },
                            starfallSwayAmount = {
                                name = "Sway Amount",
                                type = "range",
                                min = 0,
                                max = 20,
                                step = 1,
                                order = 21,
                                hidden = function() return self.db.profile.animStyle ~= "Starfall" end,
                                get = function(info)
                                    local style = self.db.profile.animStyle
                                    return self.db.profile.animationParams[style].swayAmount
                                end,
                                set = function(info, val)
                                    local style = self.db.profile.animStyle
                                    self.db.profile.animationParams[style].swayAmount = val
                                end,
                            },
                            -- Flux Settings
                            fluxJitterY = {
                                name = "Vertical Jitter",
                                type = "range",
                                min = 1.0,
                                max = 10.0,
                                step = 0.5,
                                order = 30,
                                hidden = function() return self.db.profile.animStyle ~= "Flux" end,
                                get = function(info)
                                    local style = self.db.profile.animStyle
                                    return self.db.profile.animationParams[style].jitterY
                                end,
                                set = function(info, val)
                                    local style = self.db.profile.animStyle
                                    self.db.profile.animationParams[style].jitterY = val
                                end,
                            },
                            fluxJitterX = {
                                name = "Horizontal Jitter",
                                type = "range",
                                min = 1.0,
                                max = 10.0,
                                step = 0.5,
                                order = 31,
                                hidden = function() return self.db.profile.animStyle ~= "Flux" end,
                                get = function(info)
                                    local style = self.db.profile.animStyle
                                    return self.db.profile.animationParams[style].jitterX
                                end,
                                set = function(info, val)
                                    local style = self.db.profile.animStyle
                                    self.db.profile.animationParams[style].jitterX = val
                                end,
                            },
                            -- Helix Settings
                            helixDriftMultiplier = {
                                name = "Drift Multiplier",
                                type = "range",
                                min = 0.01,
                                max = 0.3,
                                step = 0.01,
                                order = 40,
                                hidden = function() return self.db.profile.animStyle ~= "Helix" end,
                                get = function(info)
                                    local style = self.db.profile.animStyle
                                    return self.db.profile.animationParams[style].driftMultiplier
                                end,
                                set = function(info, val)
                                    local style = self.db.profile.animStyle
                                    self.db.profile.animationParams[style].driftMultiplier = val
                                end,
                            },
                            helixAmplitude = {
                                name = "Wave Amplitude",
                                desc = "Height of the wave (multiplier of bar height)",
                                type = "range",
                                min = 0.1,
                                max = 1.0,
                                step = 0.1,
                                order = 41,
                                hidden = function() return self.db.profile.animStyle ~= "Helix" end,
                                get = function(info)
                                    local style = self.db.profile.animStyle
                                    return self.db.profile.animationParams[style].amplitude
                                end,
                                set = function(info, val)
                                    local style = self.db.profile.animStyle
                                    self.db.profile.animationParams[style].amplitude = val
                                end,
                            },
                            helixWaveSpeed = {
                                name = "Wave Speed",
                                type = "range",
                                min = 1,
                                max = 20,
                                step = 1,
                                order = 42,
                                hidden = function() return self.db.profile.animStyle ~= "Helix" end,
                                get = function(info)
                                    local style = self.db.profile.animStyle
                                    return self.db.profile.animationParams[style].waveSpeed
                                end,
                                set = function(info, val)
                                    local style = self.db.profile.animStyle
                                    self.db.profile.animationParams[style].waveSpeed = val
                                end,
                            },
                            -- Wave Settings
                            waveCount = {
                                name = "Number of Waves",
                                type = "range",
                                min = 1,
                                max = 10,
                                step = 1,
                                order = 50,
                                hidden = function() return self.db.profile.animStyle ~= "Wave" end,
                                get = function(info)
                                    local style = self.db.profile.animStyle
                                    return self.db.profile.animationParams[style].waveCount
                                end,
                                set = function(info, val)
                                    local style = self.db.profile.animStyle
                                    self.db.profile.animationParams[style].waveCount = val
                                end,
                            },
                            waveSpeed = {
                                name = "Wave Speed",
                                type = "range",
                                min = 0.1,
                                max = 2.0,
                                step = 0.1,
                                order = 51,
                                hidden = function() return self.db.profile.animStyle ~= "Wave" end,
                                get = function(info)
                                    local style = self.db.profile.animStyle
                                    return self.db.profile.animationParams[style].waveSpeed
                                end,
                                set = function(info, val)
                                    local style = self.db.profile.animStyle
                                    self.db.profile.animationParams[style].waveSpeed = val
                                end,
                            },
                            waveAmplitude = {
                                name = "Wave Amplitude",
                                desc = "Height of the wave (multiplier of bar height)",
                                type = "range",
                                min = 0.01,
                                max = 0.2,
                                step = 0.01,
                                order = 52,
                                hidden = function() return self.db.profile.animStyle ~= "Wave" end,
                                get = function(info)
                                    local style = self.db.profile.animStyle
                                    return self.db.profile.animationParams[style].amplitude
                                end,
                                set = function(info, val)
                                    local style = self.db.profile.animStyle
                                    self.db.profile.animationParams[style].amplitude = val
                                end,
                            },
                            waveWidth = {
                                name = "Wave Width",
                                desc = "Width of each wave (multiplier of bar width)",
                                type = "range",
                                min = 0.1,
                                max = 0.5,
                                step = 0.05,
                                order = 53,
                                hidden = function() return self.db.profile.animStyle ~= "Wave" end,
                                get = function(info)
                                    local style = self.db.profile.animStyle
                                    return self.db.profile.animationParams[style].waveWidth
                                end,
                                set = function(info, val)
                                    local style = self.db.profile.animStyle
                                    self.db.profile.animationParams[style].waveWidth = val
                                end,
                            },
                            -- Glitch Settings
                            glitchChance = {
                                name = "Glitch Chance",
                                desc = "Probability of glitch effect",
                                type = "range",
                                min = 0.01,
                                max = 0.5,
                                step = 0.01,
                                order = 70,
                                hidden = function() return self.db.profile.animStyle ~= "Glitch" end,
                                get = function(info)
                                    local style = self.db.profile.animStyle
                                    return self.db.profile.animationParams[style].glitchChance
                                end,
                                set = function(info, val)
                                    local style = self.db.profile.animStyle
                                    self.db.profile.animationParams[style].glitchChance = val
                                end,
                            },
                            glitchMaxOffset = {
                                name = "Max Glitch Offset",
                                type = "range",
                                min = 1,
                                max = 20,
                                step = 1,
                                order = 71,
                                hidden = function() return self.db.profile.animStyle ~= "Glitch" end,
                                get = function(info)
                                    local style = self.db.profile.animStyle
                                    return self.db.profile.animationParams[style].maxOffset
                                end,
                                set = function(info, val)
                                    local style = self.db.profile.animStyle
                                    self.db.profile.animationParams[style].maxOffset = val
                                end,
                            },
                            -- Lightning Settings
                            lightningChance = {
                                name = "Lightning Chance",
                                type = "range",
                                min = 0.1,
                                max = 1.0,
                                step = 0.1,
                                order = 80,
                                hidden = function() return self.db.profile.animStyle ~= "Lightning" end,
                                get = function(info)
                                    local style = self.db.profile.animStyle
                                    return self.db.profile.animationParams[style].lightningChance
                                end,
                                set = function(info, val)
                                    local style = self.db.profile.animStyle
                                    self.db.profile.animationParams[style].lightningChance = val
                                end,
                            },
                            lightningSegmentCount = {
                                name = "Segment Count",
                                desc = "Number of lightning segments",
                                type = "range",
                                min = 1,
                                max = 10,
                                step = 1,
                                order = 81,
                                hidden = function() return self.db.profile.animStyle ~= "Lightning" end,
                                get = function(info)
                                    local style = self.db.profile.animStyle
                                    return self.db.profile.animationParams[style].segmentCount
                                end,
                                set = function(info, val)
                                    local style = self.db.profile.animStyle
                                    self.db.profile.animationParams[style].segmentCount = val
                                end,
                            },
                        }
                    },
                    headerTailSettings = { name = "Tail Settings", type = "header", order = 10 },
                    sparkIntensity = {
                        name = "Intensity",
                        type = "range",
                        min = 0,
                        max = 5,
                        step = 0.05,
                        order = 3,
                        get = function(info) return self.db.profile.sparkIntensity end,
                        set = function(info, val) self.db.profile.sparkIntensity = val end,
                    },
                    sparkScale = {
                        name = "Scale",
                        type = "range",
                        min = 0.5,
                        max = 3,
                        step = 0.1,
                        order = 4,
                        get = function(info) return self.db.profile.sparkScale end,
                        set = function(info, val)
                            self.db.profile.sparkScale = val; self:UpdateSparkSize()
                        end,
                    },
                    sparkOffset = {
                        name = "Horizontal Offset",
                        type = "range",
                        min = -100,
                        max = 100,
                        step = 0.1,
                        order = 4.5,
                        get = function(info) return self.db.profile.sparkOffset end,
                        set = function(info, val) self.db.profile.sparkOffset = val end,
                    },
                    sparkColor = {
                        name = "Spark Head Color",
                        type = "color",
                        hasAlpha = true,
                        order = 5,
                        get = function(info)
                            local c = self.db.profile.sparkColor; return c[1], c[2], c[3], c[4]
                        end,
                        set = function(info, r, g, b, a)
                            self.db.profile.sparkColor = { r, g, b, a }; self:UpdateSparkColors()
                        end,
                    },
                    enableTails = {
                        name = "Enable Tails",
                        type = "toggle",
                        order = 11,
                        get = function(info) return self.db.profile.enableTails end,
                        set = function(info, val) self.db.profile.enableTails = val end,
                    },
                    tail1Group = {
                        name = "Tail 1 (Primary)",
                        type = "group",
                        inline = true,
                        order = 12,
                        args = {
                            color = {
                                name = "Color",
                                type = "color",
                                hasAlpha = true,
                                order = 1,
                                get = function(info)
                                    local c = self.db.profile.tail1Color; return c[1], c[2], c[3], c[4]
                                end,
                                set = function(info, r, g, b, a)
                                    self.db.profile.tail1Color = { r, g, b, a }; self:UpdateSparkColors()
                                end,
                            },
                            intensity = {
                                name = "Intensity",
                                type = "range",
                                min = 0,
                                max = 5,
                                step = 0.05,
                                order = 2,
                                get = function(info) return self.db.profile.tail1Intensity end,
                                set = function(info, val) self.db.profile.tail1Intensity = val end,
                            },
                            length = {
                                name = "Length",
                                type = "range",
                                min = 10,
                                max = 400,
                                step = 1,
                                order = 3,
                                get = function(info) return self.db.profile.tail1Length end,
                                set = function(info, val)
                                    self.db.profile.tail1Length = val; self:UpdateSparkSize()
                                end,
                            },
                        }
                    },
                    tail2Group = {
                        name = "Tail 2",
                        type = "group",
                        inline = true,
                        order = 13,
                        args = {
                            color = {
                                name = "Color",
                                type = "color",
                                hasAlpha = true,
                                order = 1,
                                get = function(info)
                                    local c = self.db.profile.tail2Color; return c[1], c[2], c[3], c[4]
                                end,
                                set = function(info, r, g, b, a)
                                    self.db.profile.tail2Color = { r, g, b, a }; self:UpdateSparkColors()
                                end,
                            },
                            intensity = {
                                name = "Intensity",
                                type = "range",
                                min = 0,
                                max = 5,
                                step = 0.05,
                                order = 2,
                                get = function(info) return self.db.profile.tail2Intensity end,
                                set = function(info, val) self.db.profile.tail2Intensity = val end,
                            },
                            length = {
                                name = "Length",
                                type = "range",
                                min = 10,
                                max = 400,
                                step = 1,
                                order = 3,
                                get = function(info) return self.db.profile.tail2Length end,
                                set = function(info, val)
                                    self.db.profile.tail2Length = val; self:UpdateSparkSize()
                                end,
                            },
                        }
                    },
                    tail3Group = {
                        name = "Tail 3",
                        type = "group",
                        inline = true,
                        order = 14,
                        args = {
                            color = {
                                name = "Color",
                                type = "color",
                                hasAlpha = true,
                                order = 1,
                                get = function(info)
                                    local c = self.db.profile.tail3Color; return c[1], c[2], c[3], c[4]
                                end,
                                set = function(info, r, g, b, a)
                                    self.db.profile.tail3Color = { r, g, b, a }; self:UpdateSparkColors()
                                end,
                            },
                            intensity = {
                                name = "Intensity",
                                type = "range",
                                min = 0,
                                max = 5,
                                step = 0.05,
                                order = 2,
                                get = function(info) return self.db.profile.tail3Intensity end,
                                set = function(info, val) self.db.profile.tail3Intensity = val end,
                            },
                            length = {
                                name = "Length",
                                type = "range",
                                min = 10,
                                max = 400,
                                step = 1,
                                order = 3,
                                get = function(info) return self.db.profile.tail3Length end,
                                set = function(info, val)
                                    self.db.profile.tail3Length = val; self:UpdateSparkSize()
                                end,
                            },
                        }
                    },
                    tail4Group = {
                        name = "Tail 4",
                        type = "group",
                        inline = true,
                        order = 15,
                        args = {
                            color = {
                                name = "Color",
                                type = "color",
                                hasAlpha = true,
                                order = 1,
                                get = function(info)
                                    local c = self.db.profile.tail4Color; return c[1], c[2], c[3], c[4]
                                end,
                                set = function(info, r, g, b, a)
                                    self.db.profile.tail4Color = { r, g, b, a }; self:UpdateSparkColors()
                                end,
                            },
                            intensity = {
                                name = "Intensity",
                                type = "range",
                                min = 0,
                                max = 5,
                                step = 0.05,
                                order = 2,
                                get = function(info) return self.db.profile.tail4Intensity end,
                                set = function(info, val) self.db.profile.tail4Intensity = val end,
                            },
                            length = {
                                name = "Length",
                                type = "range",
                                min = 10,
                                max = 400,
                                step = 1,
                                order = 3,
                                get = function(info) return self.db.profile.tail4Length end,
                                set = function(info, val)
                                    self.db.profile.tail4Length = val; self:UpdateSparkSize()
                                end,
                            },
                        }
                    },
                    -- Botón de reset
                    resetStyleSettings = {
                        name = "Reset Current Style",
                        desc = "Reset all parameters for the current animation style to defaults",
                        type = "execute",
                        order = 100,
                        func = function()
                            local currentStyle = self.db.profile.animStyle
                            if currentStyle and AscensionCastBar.ANIMATION_STYLE_PARAMS[currentStyle] then
                                self.db.profile.animationParams[currentStyle] = CopyTable(AscensionCastBar
                                    .ANIMATION_STYLE_PARAMS[currentStyle])
                                AscensionCastBar:RefreshConfig()
                            end
                        end,
                    },
                }
            },
            profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
        }
    }

LibStub("AceConfig-3.0"):RegisterOptionsTable(ADDON_NAME, options)
self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(ADDON_NAME, ADDON_NAME)
end
