-------------------------------------------------------------------------------
-- Project: AscensionCastBar
-- Author: Aka-DoctorCode 
-- File: Config.lua
-- Version: 40
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

        -- Fonts/Text
        spellNameFontSize = 14,
        timerFontSize = 14,
        fontPath = BAR_DEFAULT_FONT_PATH,
        fontColor = { 0.8, 1, 0.95, 1 },
        outlineColor = { 0, 0, 0, 1 },
        outlineThickness = 1,
        showSpellText = true,
        showTimerText = true,
        spellNameFontLSM = "Expressway, Bold",
        timerFontLSM = "Boris Black Bloxx",
        outline = "OUTLINE",
        useSharedColor = true,
        timerColor = { 0.8, 1, 0.95, 1 },
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
        barColor = { 0, 0, 0.25, 1 },
        barLSMName = "Solid",
        useClassColor = false,

        -- Anim
        enableSpark = true,
        enableTails = true,
        animStyle = "Comet",
        sparkColor = { 1, 1, 1, 0.9 },
        glowColor = { 1, 1, 1, 1 },
        sparkIntensity = 1,
        glowIntensity = 0.5,
        sparkScale = 3,
        sparkOffset = 0,
        headLengthOffset = 0,

        -- Tail Colors
        tailLength = 200,
        tailOffset = 0,
        tail1Color = { 1, 0, 0, 1 },
        tail1Intensity = 1,
        tail1Length = 95,
        tail2Color = { 0, 1, 1, 1 },
        tail2Intensity = 0.4,
        tail2Length = 215,
        tail3Color = { 0, 1, 0.2, 1 },
        tail3Intensity = 0.6,
        tail3Length = 80,
        tail4Color = { 1, 0, 0.8, 1 },
        tail4Intensity = 0.6,
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
        latencyMaxPercent = 0.5,

        -- CDM
        attachToCDM = true,
        cdmTarget = "Essential",
        cdmYOffset = 0,
        previewEnabled = false,
        testModeState = "Cast",

        -- Animation Parameters by Style
        animationParams = {
            Comet = {
                tailOffset = 0,
                headLengthOffset = 0,
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
    local defaults = self.defaults.profile
    -- Helper para obtener fuentes (Evita errores si LSM no carga)
    local function GetFontList()
        local fonts = {}
        if LSM then
            for _, name in ipairs(LSM:List("font")) do
                fonts[name] = name
            end
        end
        return fonts
    end

    -- Helper para obtener texturas (Evita el error AceGUIWidgetLSMlists)
    local function GetStatusBarList()
        local textures = {}
        if LSM then
            for _, name in ipairs(LSM:List("statusbar")) do
                textures[name] = name
            end
        end
        return textures
    end

    local AceGUI = LibStub("AceGUI-3.0")
    local hasLSMWidgets = AceGUI and (AceGUI.WidgetRegistry["LSM30_Statusbar"] ~= nil)

    local anchors = {
        ["CENTER"] = "Center",
        ["TOP"] = "Top",
        ["BOTTOM"] = "Bottom",
        ["LEFT"] = "Left",
        ["RIGHT"] = "Right",
    }

    local options = {
        name = "Ascension Cast Bar",
        handler = AscensionCastBar,
        type = "group",
        childGroups = "tab", -- Interfaz con pestañas
        args = {
            -- ==========================================================
            -- TAB 1: GENERAL (Positioning, Size, Testing)
            -- ==========================================================
            general = {
                name = "General & Layout",
                type = "group",
                order = 1,
                args = {
                    -- SECTION: TEST MODE
                    headerTest = { name = "Setup & Testing", type = "header", order = 1 },
                    preview = {
                        name = "Enable Test Mode",
                        desc = "Shows a preview bar to help you configure the layout.",
                        type = "toggle",
                        width = "full",
                        order = 2,
                        get = function(info) return self.db.profile.previewEnabled end,
                        set = function(info, val)
                            self.db.profile.previewEnabled = val
                            if not val then self.db.profile.testAttached = false end
                            self:ToggleTestMode(val)
                        end,
                    },
                    testModeState = {
                        name = "Animation Type",
                        desc = "Simulate different spell types.",
                        type = "select",
                        values = { ["Cast"] = "Normal Cast", ["Channel"] = "Channel", ["Empowered"] = "Empowered" },
                        order = 3,
                        disabled = function() return not self.db.profile.previewEnabled end,
                        get = function(info) return self.db.profile.testModeState end,
                        set = function(info, val)
                            self.db.profile.testModeState = val
                            if self.db.profile.previewEnabled then self:ToggleTestMode(true) end
                        end,
                    },
                    hideDefaultCastbar = {
                        name = "Hide Blizzard Cast Bar",
                        type = "toggle",
                        order = 4,
                        get = function(info) return self.db.profile.hideDefaultCastbar end,
                        set = function(info, val)
                            self.db.profile.hideDefaultCastbar = val
                            self:UpdateDefaultCastBarVisibility()
                        end,
                    },

                    -- SECTION: SIZE
                    headerSize = { name = "Dimensions", type = "header", order = 10 },
                    manualWidth = {
                        name = "Bar Width",
                        type = "range", min = 50, max = 1000, step = 1,
                        order = 11,
                        get = function(info) return self.db.profile.manualWidth end,
                        set = function(info, val) self.db.profile.manualWidth = val; self:UpdateAnchor() end,
                    },
                    height = {
                        name = "Bar Height",
                        type = "range", min = 10, max = 150, step = 1,
                        order = 12,
                        get = function(info) return self.db.profile.manualHeight end,
                        set = function(info, val)
                            self.db.profile.manualHeight = val
                            self.db.profile.height = val
                            self.castBar:SetHeight(val)
                            self:UpdateSparkSize()
                            self:UpdateIcon()
                        end,
                    },

                    -- SECTION: POSITIONING
                    headerPos = { name = "Positioning", type = "header", order = 20 },
                    attachToCDM = {
                        name = "Attach to UI Frame",
                        desc = "Attaches the bar to UI elements (like PlayerFrame) automatically.",
                        type = "toggle",
                        width = "full",
                        order = 21,
                        get = function(info) return self.db.profile.attachToCDM end,
                        set = function(info, val)
                            self.db.profile.attachToCDM = val; self:InitCDMHooks(); self:UpdateAnchor()
                        end,
                    },
                    testAttached = {
                        name = "Test Attachment", -- Renamed
                        desc = "Toggle between testing the attached position (ON) or the manual position (OFF).",
                        type = "toggle",
                        width = "full",
                        order = 22,
                        hidden = function() return not self.db.profile.attachToCDM end,
                        get = function(info) return self.db.profile.testAttached end,
                        set = function(info, val)
                            self.db.profile.testAttached = val
                            self.db.profile.previewEnabled = true -- Auto-enable preview
                            self:ToggleTestMode(true)
                            self:UpdateAnchor()
                        end,
                    },
                    -- Coordinates Group
                    posGroup = {
                        name = "Coordinates",
                        type = "group",
                        inline = true,
                        order = 23,
                        args = {
                            -- Manual
                            point = {
                                name = "Anchor Point",
                                type = "select", values = anchors,
                                order = 1,
                                hidden = function() return self.db.profile.attachToCDM end,
                                get = function(info) return self.db.profile.point end,
                                set = function(info, val) self.db.profile.point = val; self:UpdateAnchor() end,
                            },
                            relativePoint = {
                                name = "Relative Point",
                                desc = "The point on the parent frame (or screen) to anchor to.",
                                type = "select", values = anchors,
                                order = 1.5,
                                hidden = function() return self.db.profile.attachToCDM end,
                                get = function(info) return self.db.profile.relativePoint end,
                                set = function(info, val) self.db.profile.relativePoint = val; self:UpdateAnchor() end,
                            },
                            manualX = {
                                name = "X Offset", type = "range", min = -2000, max = 2000, step = 1, order = 2,
                                hidden = function() return self.db.profile.attachToCDM end,
                                get = function(info) return self.db.profile.manualX end,
                                set = function(info, val) self.db.profile.manualX = val; self:UpdateAnchor() end,
                            },
                            manualY = {
                                name = "Y Offset", type = "range", min = -2000, max = 2000, step = 1, order = 3,
                                hidden = function() return self.db.profile.attachToCDM end,
                                get = function(info) return self.db.profile.manualY end,
                                set = function(info, val) self.db.profile.manualY = val; self:UpdateAnchor() end,
                            },
                            -- Attached
                            cdmTarget = {
                                name = "Attach Target",
                                type = "select", style = "dropdown", width = "normal",
                                order = 1,
                                hidden = function() return not self.db.profile.attachToCDM end,
                                get = function(info) return self.db.profile.cdmTarget end,
                                set = function(info, val) self.db.profile.cdmTarget = val; self:InitCDMHooks(); self:UpdateAnchor() end,
                                
                                -- 1. THE DISPLAY NAMES (The text the user sees)
                                values = { 
                                    -- Standard Frames
                                    ["PlayerFrame"] = "Player Frame",
                                    ["PersonalResource"] = "Personal Resource Display",
                                    
                                    -- CDM Specific
                                    ["Buffs"] = "Tracked Buffs (CDM)", 
                                    ["Essential"] = "Essential Cooldowns (CDM)", 
                                    ["Utility"] = "Utility Cooldowns (CDM)",
                                    
                                    -- Standard Action Bars
                                    ["ActionBar1"] = "Action Bar 1",
                                    ["ActionBar2"] = "Action Bar 2",
                                    ["ActionBar3"] = "Action Bar 3",
                                    ["ActionBar4"] = "Action Bar 4",
                                    ["ActionBar5"] = "Action Bar 5",
                                    ["ActionBar6"] = "Action Bar 6",
                                    ["ActionBar7"] = "Action Bar 7",
                                    ["ActionBar8"] = "Action Bar 8",

                                    -- Bartender4 Support
                                    ["BT4Bar1"] = "Bartender Bar 1",
                                    ["BT4Bar2"] = "Bartender Bar 2",
                                    ["BT4Bar3"] = "Bartender Bar 3",
                                    ["BT4Bar4"] = "Bartender Bar 4",
                                    ["BT4Bar5"] = "Bartender Bar 5",
                                    ["BT4Bar6"] = "Bartender Bar 6",
                                    ["BT4Bar7"] = "Bartender Bar 7",
                                    ["BT4Bar8"] = "Bartender Bar 8",
                                    ["BT4Bar9"] = "Bartender Bar 9",
                                    ["BT4Bar10"] = "Bartender Bar 10",
                                    ["BT4PetBar"] = "Bartender Pet Bar",
                                    ["BT4StanceBar"] = "Bartender Stance Bar",
                                },

                                -- 2. THE SORTING ORDER (The list of KEYS in the desired order)
                                sorting = {
                                    "PlayerFrame", "PersonalResource", "Buffs", "Essential", "Utility", "ActionBar1", "ActionBar2", "ActionBar3", "ActionBar4", "ActionBar5", "ActionBar6", "ActionBar7", "ActionBar8", "BT4Bar1", "BT4Bar2", "BT4Bar3", "BT4Bar4", "BT4Bar5", "BT4Bar6", "BT4Bar7", "BT4Bar8", "BT4Bar9", "BT4Bar10", "BT4PetBar", "BT4StanceBar"
                                },
                            },
                            cdmYOffset = {
                                name = "Vertical Offset", type = "range", min = -200, max = 200, step = 1, order = 2,
                                hidden = function() return not self.db.profile.attachToCDM end,
                                get = function(info) return self.db.profile.cdmYOffset end,
                                set = function(info, val) self.db.profile.cdmYOffset = val; self:UpdateAnchor() end,
                            },
                        }
                    }
                }
            },

            -- ==========================================================
            -- TAB 2: APPEARANCE (Colors, Textures, Icons)
            -- ==========================================================
            appearance = {
                name = "Style & Colors",
                type = "group",
                order = 2,
                args = {
                    headerBar = { name = "Bar Style", type = "header", order = 1 },
                    barTexture = {
                        name = "Texture",
                        type = "select",
                        dialogControl = hasLSMWidgets and "LSM30_Statusbar" or nil, 
                        values = GetStatusBarList,
                        order = 2,
                        get = function(info) return self.db.profile.barLSMName end,
                        set = function(info, val) self.db.profile.barLSMName = val; self:UpdateBarTexture() end,
                    },
                    useClassColor = {
                        name = "Use Class Color",
                        type = "toggle", order = 2.1,
                        get = function(info) return self.db.profile.useClassColor end,
                        set = function(info, val) self.db.profile.useClassColor = val; self:UpdateBarColor() end,
                    },
                    barColor = {
                        name = "Bar Color",
                        type = "color", hasAlpha = true, order = 3,
                        disabled = function() return self.db.profile.useClassColor end,
                        get = function(info) local c = self.db.profile.barColor; return c[1], c[2], c[3], c[4] end,
                        set = function(info, r, g, b, a) self.db.profile.barColor = { r, g, b, a }; self:UpdateBarColor() end,
                    },
                    barColorReset = {
                        name = "Reset", type = "execute", width = "half", order = 3.1,
                        func = function() self.db.profile.barColor = {unpack(defaults.barColor)}; self:UpdateBarColor() end,
                    },
                    bgColor = {
                        name = "Background Color",
                        type = "color", hasAlpha = true, order = 4,
                        get = function(info) local c = self.db.profile.bgColor; return c[1], c[2], c[3], c[4] end,
                        set = function(info, r, g, b, a) self.db.profile.bgColor = { r, g, b, a }; self:UpdateBackground() end,
                    },
                    bgColorReset = {
                        name = "Reset", type = "execute", width = "half", order = 4.1,
                        func = function() self.db.profile.bgColor = {unpack(defaults.bgColor)}; self:UpdateBackground() end,
                    },
                    
                    headerBorder = { name = "Border", type = "header", order = 10 },
                    borderEnabled = {
                        name = "Enable Border",
                        type = "toggle", order = 11,
                        get = function(info) return self.db.profile.borderEnabled end,
                        set = function(info, val) self.db.profile.borderEnabled = val; self:UpdateBorder() end,
                    },
                    borderColor = {
                        name = "Border Color",
                        type = "color", hasAlpha = true, order = 12,
                        disabled = function() return not self.db.profile.borderEnabled end,
                        get = function(info) local c = self.db.profile.borderColor; return c[1], c[2], c[3], c[4] end,
                        set = function(info, r, g, b, a) self.db.profile.borderColor = { r, g, b, a }; self:UpdateBorder() end,
                    },
                    borderColorReset = {
                        name = "Reset", type = "execute", width = "half", order = 12.1,
                        disabled = function() return not self.db.profile.borderEnabled end,
                        func = function() self.db.profile.borderColor = {unpack(defaults.borderColor)}; self:UpdateBorder() end,
                    },
                    borderThickness = {
                        name = "Thickness", type = "range", min = 1, max = 10, step = 1, order = 13,
                        disabled = function() return not self.db.profile.borderEnabled end,
                        get = function(info) return self.db.profile.borderThickness end,
                        set = function(info, val) self.db.profile.borderThickness = val; self:UpdateBorder() end,
                    },

                    headerIcon = { name = "Spell Icon", type = "header", order = 20 },
                    showIcon = {
                        name = "Show Icon",
                        type = "toggle", order = 21,
                        get = function(info) return self.db.profile.showIcon end,
                        set = function(info, val) self.db.profile.showIcon = val; self:UpdateIcon() end,
                    },
                    iconGroup = {
                        name = "Icon Settings",
                        type = "group", inline = true, order = 22,
                        hidden = function() return not self.db.profile.showIcon end,
                        args = {
                            detachIcon = {
                                name = "Detach", type = "toggle", order = 1,
                                get = function(info) return self.db.profile.detachIcon end,
                                set = function(info, val) self.db.profile.detachIcon = val; self:UpdateIcon() end,
                            },
                            iconAnchor = {
                                name = "Position", type = "select", values = { ["Left"] = "Left", ["Right"] = "Right" }, order = 2,
                                get = function(info) return self.db.profile.iconAnchor end,
                                set = function(info, val) self.db.profile.iconAnchor = val; self:UpdateIcon() end,
                            },
                            iconSize = {
                                name = "Size", type = "range", min = 10, max = 128, step = 1, order = 3,
                                get = function(info) return self.db.profile.iconSize end,
                                set = function(info, val) self.db.profile.iconSize = val; self:UpdateIcon() end,
                            },
                            iconX = {
                                name = "X Offset", type = "range", min = -200, max = 200, step = 1, order = 4,
                                get = function(info) return self.db.profile.iconX end,
                                set = function(info, val) self.db.profile.iconX = val; self:UpdateIcon() end,
                            },
                            iconY = {
                                name = "Y Offset", type = "range", min = -200, max = 200, step = 1, order = 5,
                                get = function(info) return self.db.profile.iconY end,
                                set = function(info, val) self.db.profile.iconY = val; self:UpdateIcon() end,
                            },
                        }
                    }
                }
            },

            -- ==========================================================
            -- TAB 3: TEXT (Fonts, Labels)
            -- ==========================================================
            text = {
                name = "Text & Fonts",
                type = "group",
                order = 3,
                args = {
                    headerFont = { name = "Global Font Settings", type = "header", order = 1 },
                    font = {
                        name = "Font Face",
                        type = "select",
                        dialogControl = hasLSMWidgets and "LSM30_Font" or nil,
                        values = GetFontList,
                        order = 2,
                        get = function(info) return self.db.profile.spellNameFontLSM end,
                        set = function(info, val)
                            self.db.profile.spellNameFontLSM = val; self.db.profile.timerFontLSM = val; self:ApplyFont()
                        end,
                    },
                    outline = {
                        name = "Font Outline",
                        type = "select", values = { ["NONE"] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick Outline", ["MONOCHROME"] = "Monochrome" },
                        order = 3,
                        get = function(info) return self.db.profile.outline end,
                        set = function(info, val) self.db.profile.outline = val; self:ApplyFont() end,
                    },
                    headerName = { name = "Spell Name", type = "header", order = 10 },
                    showSpellText = {
                        name = "Show Name",
                        type = "toggle", order = 11,
                        get = function(info) return self.db.profile.showSpellText end,
                        set = function(info, val) self.db.profile.showSpellText = val; self:UpdateTextVisibility() end,
                    },
                    truncateSpellName = {
                        name = "Truncate Name",
                        type = "toggle", order = 11.1,
                        get = function(info) return self.db.profile.truncateSpellName end,
                        set = function(info, val) self.db.profile.truncateSpellName = val end,
                    },
                    truncateLength = {
                        name = "Max Characters",
                        type = "range", min = 5, max = 100, step = 1, order = 11.2,
                        disabled = function() return not self.db.profile.truncateSpellName end,
                        get = function(info) return self.db.profile.truncateLength end,
                        set = function(info, val) self.db.profile.truncateLength = val end,
                    },
                    fontSizeSpell = {
                        name = "Size", type = "range", min = 8, max = 32, step = 1, order = 12,
                        get = function(info) return self.db.profile.spellNameFontSize end,
                        set = function(info, val) self.db.profile.spellNameFontSize = val; self:ApplyFont() end,
                    },
                    fontColor = {
                        name = "Color", type = "color", hasAlpha = true, order = 13,
                        get = function(info) local c = self.db.profile.fontColor; return c[1], c[2], c[3], c[4] end,
                        set = function(info, r, g, b, a) self.db.profile.fontColor = { r, g, b, a }; self:ApplyFont() end,
                    },
                    fontColorReset = {
                        name = "Reset", type = "execute", width = "half", order = 13.1,
                        func = function() self.db.profile.fontColor = {unpack(defaults.fontColor)}; self:ApplyFont() end,
                    },
                    headerTimer = { name = "Timer", type = "header", order = 20 },
                    showTimerText = {
                        name = "Show Timer", type = "toggle", order = 21,
                        get = function(info) return self.db.profile.showTimerText end,
                        set = function(info, val) self.db.profile.showTimerText = val end,
                    },
                    hideTimerOnChannel = {
                        name = "Hide on Channel",
                        type = "toggle", order = 21.1,
                        get = function(info) return self.db.profile.hideTimerOnChannel end,
                        set = function(info, val) self.db.profile.hideTimerOnChannel = val end,
                    },
                    timerFormat = {
                        name = "Format", type = "select", values = { ["Remaining"] = "Remaining", ["Duration"] = "Duration", ["Total"] = "Total" }, order = 22,
                        get = function(info) return self.db.profile.timerFormat end,
                        set = function(info, val) self.db.profile.timerFormat = val end,
                    },
                    fontSizeTimer = {
                        name = "Size", type = "range", min = 8, max = 32, step = 1, order = 23,
                        get = function(info) return self.db.profile.timerFontSize end,
                        set = function(info, val) self.db.profile.timerFontSize = val; self:ApplyFont() end,
                    },
                    useSharedColor = {
                        name = "Use Shared Color", desc = "Use same color as Spell Name.", type = "toggle", order = 24,
                        get = function(info) return self.db.profile.useSharedColor end,
                        set = function(info, val) self.db.profile.useSharedColor = val; self:ApplyFont() end,
                    },
                    timerColor = {
                        name = "Timer Color", type = "color", hasAlpha = true, order = 25,
                        disabled = function() return self.db.profile.useSharedColor end,
                        get = function(info) local c = self.db.profile.timerColor; return c[1], c[2], c[3], c[4] end,
                        set = function(info, r, g, b, a) self.db.profile.timerColor = { r, g, b, a }; self:ApplyFont() end,
                    },
                    timerColorReset = {
                        name = "Reset", type = "execute", width = "half", order = 25.1,
                        disabled = function() return self.db.profile.useSharedColor end,
                        func = function() self.db.profile.timerColor = {unpack(defaults.timerColor)}; self:ApplyFont() end,
                    },
                    headerTextPos = { name = "Positioning & Backdrop", type = "header", order = 14 },
                    detachText = {
                        name = "Detach Text", type = "toggle", order = 15,
                        get = function(info) return self.db.profile.detachText end,
                        set = function(info, val) self.db.profile.detachText = val; self:UpdateTextLayout() end,
                    },
                    textX = {
                        name = "X Offset", type = "range", min = -200, max = 200, step = 1, order = 16,
                        hidden = function() return not self.db.profile.detachText end,
                        get = function(info) return self.db.profile.textX end,
                        set = function(info, val) self.db.profile.textX = val; self:UpdateTextLayout() end,
                    },
                    textY = {
                        name = "Y Offset", type = "range", min = -200, max = 200, step = 1, order = 17,
                        hidden = function() return not self.db.profile.detachText end,
                        get = function(info) return self.db.profile.textY end,
                        set = function(info, val) self.db.profile.textY = val; self:UpdateTextLayout() end,
                    },
                    textWidth = {
                        name = "Text Area Width", type = "range", min = 50, max = 500, step = 1, order = 18,
                        hidden = function() return not self.db.profile.detachText end,
                        get = function(info) return self.db.profile.textWidth end,
                        set = function(info, val) self.db.profile.textWidth = val; self:UpdateTextLayout() end,
                    },
                    textBackdropEnabled = {
                        name = "Enable Backdrop", type = "toggle", order = 19,
                        get = function(info) return self.db.profile.textBackdropEnabled end,
                        set = function(info, val) self.db.profile.textBackdropEnabled = val; self:UpdateTextLayout() end,
                    },
                    textBackdropColor = {
                        name = "Backdrop Color", type = "color", hasAlpha = true, order = 36,
                        hidden = function() return not self.db.profile.textBackdropEnabled end,
                        get = function(info) local c = self.db.profile.textBackdropColor; return c[1], c[2], c[3], c[4] end,
                        set = function(info, r, g, b, a) self.db.profile.textBackdropColor = { r, g, b, a }; self:UpdateTextLayout() end,
                    },
                    textBackdropColorReset = {
                        name = "Reset", type = "execute", width = "half", order = 36.1,
                        hidden = function() return not self.db.profile.textBackdropEnabled end,
                        func = function() self.db.profile.textBackdropColor = {unpack(defaults.textBackdropColor)}; self:UpdateTextLayout() end,
                    },
                    -- TEXT POSITIONING & BACKDROP
                    headerTextPos = { name = "Positioning & Backdrop", type = "header", order = 30 },
                    detachText = {
                        name = "Detach Text", type = "toggle", order = 31,
                        get = function(info) return self.db.profile.detachText end,
                        set = function(info, val) self.db.profile.detachText = val; self:UpdateTextLayout() end,
                    },
                    textX = {
                        name = "X Offset", type = "range", min = -200, max = 200, step = 1, order = 32,
                        hidden = function() return not self.db.profile.detachText end,
                        get = function(info) return self.db.profile.textX end,
                        set = function(info, val) self.db.profile.textX = val; self:UpdateTextLayout() end,
                    },
                    textY = {
                        name = "Y Offset", type = "range", min = -200, max = 200, step = 1, order = 33,
                        hidden = function() return not self.db.profile.detachText end,
                        get = function(info) return self.db.profile.textY end,
                        set = function(info, val) self.db.profile.textY = val; self:UpdateTextLayout() end,
                    },
                    textWidth = {
                        name = "Text Area Width", type = "range", min = 50, max = 500, step = 1, order = 34,
                        hidden = function() return not self.db.profile.detachText end,
                        get = function(info) return self.db.profile.textWidth end,
                        set = function(info, val) self.db.profile.textWidth = val; self:UpdateTextLayout() end,
                    },
                    textBackdropEnabled = {
                        name = "Enable Backdrop", type = "toggle", order = 35,
                        get = function(info) return self.db.profile.textBackdropEnabled end,
                        set = function(info, val) self.db.profile.textBackdropEnabled = val; self:UpdateTextLayout() end,
                    },
                    textBackdropColor = {
                        name = "Backdrop Color", type = "color", hasAlpha = true, order = 36,
                        hidden = function() return not self.db.profile.textBackdropEnabled end,
                        get = function(info) local c = self.db.profile.textBackdropColor; return c[1], c[2], c[3], c[4] end,
                        set = function(info, r, g, b, a) self.db.profile.textBackdropColor = { r, g, b, a }; self:UpdateTextLayout() end,
                    },
                    textBackdropColorReset = {
                        name = "Reset", type = "execute", width = "half", order = 36.1,
                        hidden = function() return not self.db.profile.textBackdropEnabled end,
                        func = function() self.db.profile.textBackdropColor = {unpack(defaults.textBackdropColor)}; self:UpdateTextLayout() end,
                    },
                }
            },

            -- ==========================================================
            -- TAB 4: MECHANICS (Latency, Empower, Channels)
            -- ==========================================================
            mechanics = {
                name = "Mechanics",
                type = "group",
                order = 4,
                args = {
                    headerLatency = { name = "Latency", type = "header", order = 1 },
                    showLatency = {
                        name = "Show Latency", type = "toggle", order = 2,
                        get = function(info) return self.db.profile.showLatency end,
                        set = function(info, val) 
                            self.db.profile.showLatency = val
                            if self.db.profile.previewEnabled then self:UpdateLatencyBar(self.castBar) end
                        end,
                    },
                    latencyColor = {
                        name = "Latency Color", type = "color", hasAlpha = true, order = 34.6,
                        get = function(info) local c = self.db.profile.latencyColor; return c[1], c[2], c[3], c[4] end,
                        set = function(info, r, g, b, a) self.db.profile.latencyColor = { r, g, b, a } end,
                    },
                    latencyColorReset = {
                        name = "Reset", type = "execute", width = "half", order = 34.7,
                        func = function() self.db.profile.latencyColor = {unpack(defaults.latencyColor)} end,
                    },
                    latencyMaxPercent = {
                        name = "Max Width %", desc = "Sets the maximum width percentage of the cast bar that the latency indicator can occupy.", type = "range", min = 0.1, max = 1.0, step = 0.05, order = 34.8,
                        get = function(info) return self.db.profile.latencyMaxPercent end,
                        set = function(info, val) 
                            self.db.profile.latencyMaxPercent = val 
                            if self.db.profile.previewEnabled then self:UpdateLatencyBar(self.castBar) end
                        end,
                    },

                    headerChannel = { name = "Channeled Spells", type = "header", order = 10 },
                    reverseChanneling = {
                        name = "Reverse Channel", desc = "Fill bar instead of empty.", type = "toggle", order = 11,
                        get = function(info) return self.db.profile.reverseChanneling end,
                        set = function(info, val) self.db.profile.reverseChanneling = val; if self.db.profile.previewEnabled then self:ToggleTestMode(true) end end,
                    },
                    showChannelTicks = {
                        name = "Show Ticks", type = "toggle", order = 12,
                        get = function(info) return self.db.profile.showChannelTicks end,
                        set = function(info, val) 
                            self.db.profile.showChannelTicks = val
                            if self.db.profile.previewEnabled and self.db.profile.testModeState == "Channel" then
                                self:UpdateTicks(234153, 0, 10)
                            end
                        end,
                    },
                    channelTicksThickness = {
                        name = "Tick Thickness", type = "range", min = 1, max = 10, step = 1, order = 12.1,
                        disabled = function() return not self.db.profile.showChannelTicks end,
                        get = function(info) return self.db.profile.channelTicksThickness end,
                        set = function(info, val) 
                            self.db.profile.channelTicksThickness = val
                            if self.db.profile.previewEnabled and self.db.profile.testModeState == "Channel" then
                                self:UpdateTicks(234153, 0, 10)
                            end
                        end,
                    },
                    channelTicksColor = {
                        name = "Tick Color", type = "color", hasAlpha = true, order = 12.2,
                        disabled = function() return not self.db.profile.showChannelTicks end,
                        get = function(info) local c = self.db.profile.channelTicksColor; return c[1], c[2], c[3], c[4] end,
                        set = function(info, r, g, b, a) 
                            self.db.profile.channelTicksColor = { r, g, b, a }
                            if self.db.profile.previewEnabled and self.db.profile.testModeState == "Channel" then
                                self:UpdateTicks(234153, 0, 10)
                            end
                        end,
                    },
                    channelTicksColorReset = {
                        name = "Reset", type = "execute", width = "half", order = 12.3,
                        disabled = function() return not self.db.profile.showChannelTicks end,
                        func = function() 
                            self.db.profile.channelTicksColor = {unpack(defaults.channelTicksColor)} 
                            if self.db.profile.previewEnabled and self.db.profile.testModeState == "Channel" then
                                self:UpdateTicks(234153, 0, 10)
                            end
                        end,
                    },
                    
                    headerChannelStyle = { name = "Channel Styling", type = "header", order = 13 },
                    useChannelColor = {
                        name = "Custom Channel Color", type = "toggle", order = 13.1,
                        get = function(info) return self.db.profile.useChannelColor end,
                        set = function(info, val) self.db.profile.useChannelColor = val; self:UpdateBarColor() end,
                    },
                    channelColor = {
                        name = "Channel Color", type = "color", hasAlpha = true, order = 13.2,
                        disabled = function() return not self.db.profile.useChannelColor end,
                        get = function(info) local c = self.db.profile.channelColor; return c[1], c[2], c[3], c[4] end,
                        set = function(info, r, g, b, a) self.db.profile.channelColor = { r, g, b, a }; self:UpdateBarColor() end,
                    },
                    channelColorReset = {
                        name = "Reset", type = "execute", width = "half", order = 13.25,
                        disabled = function() return not self.db.profile.useChannelColor end,
                        func = function() self.db.profile.channelColor = {unpack(defaults.channelColor)}; self:UpdateBarColor() end,
                    },
                    headerEmpower = { name = "Empowered Spells (Evoker)", type = "header", order = 20 },
                    empowerStage1Color = {
                        name = "Stage 1", type = "color", hasAlpha = true, order = 21,
                        get = function(info) local c = self.db.profile.empowerStage1Color; return c[1], c[2], c[3], c[4] end,
                        set = function(info, r, g, b, a) self.db.profile.empowerStage1Color = { r, g, b, a } end,
                    },
                    empowerStage1ColorReset = {
                        name = "Reset", type = "execute", width = "half", order = 21.1,
                        func = function() self.db.profile.empowerStage1Color = {unpack(defaults.empowerStage1Color)}; self:UpdateBarColor() end,
                    },
                    empowerStage2Color = {
                        name = "Stage 2", type = "color", hasAlpha = true, order = 22,
                        get = function(info) local c = self.db.profile.empowerStage2Color; return c[1], c[2], c[3], c[4] end,
                        set = function(info, r, g, b, a) self.db.profile.empowerStage2Color = { r, g, b, a } end,
                    },
                    empowerStage2ColorReset = {
                        name = "Reset", type = "execute", width = "half", order = 22.1,
                        func = function() self.db.profile.empowerStage2Color = {unpack(defaults.empowerStage2Color)}; self:UpdateBarColor() end,
                    },
                    empowerStage3Color = {
                        name = "Stage 3", type = "color", hasAlpha = true, order = 23,
                        get = function(info) local c = self.db.profile.empowerStage3Color; return c[1], c[2], c[3], c[4] end,
                        set = function(info, r, g, b, a) self.db.profile.empowerStage3Color = { r, g, b, a } end,
                    },
                    empowerStage3ColorReset = {
                        name = "Reset", type = "execute", width = "half", order = 23.1,
                        func = function() self.db.profile.empowerStage3Color = {unpack(defaults.empowerStage3Color)}; self:UpdateBarColor() end,
                    },
                    empowerStage4Color = {
                        name = "Stage 4", type = "color", hasAlpha = true, order = 24,
                        get = function(info) local c = self.db.profile.empowerStage4Color; return c[1], c[2], c[3], c[4] end,
                        set = function(info, r, g, b, a) self.db.profile.empowerStage4Color = { r, g, b, a } end,
                    },
                    empowerStage4ColorReset = {
                        name = "Reset", type = "execute", width = "half", order = 24.1,
                        func = function() self.db.profile.empowerStage4Color = {unpack(defaults.empowerStage4Color)}; self:UpdateBarColor() end,
                    },
                    empowerStage5Color = {
                        name = "Stage 5", type = "color", hasAlpha = true, order = 25,
                        get = function(info) local c = self.db.profile.empowerStage5Color; return c[1], c[2], c[3], c[4] end,
                        set = function(info, r, g, b, a) self.db.profile.empowerStage5Color = { r, g, b, a } end,
                    },
                    empowerStage5ColorReset = {
                        name = "Reset", type = "execute", width = "half", order = 25.1,
                        func = function() self.db.profile.empowerStage5Color = {unpack(defaults.empowerStage5Color)}; self:UpdateBarColor() end,
                    },
                }
            },

            -- ==========================================================
            -- TAB 5: ANIMATION (Visual FX)
            -- ==========================================================
            animation = {
                name = "Visual FX",
                type = "group",
                order = 5,
                args = {
                    animStyle = {
                        name = "Main Style", type = "select", order = 1,
                        values = {
                            ["Comet"] = "Comet", ["Orb"] = "Orb", ["Flux"] = "Flux",
                            ["Helix"] = "Helix", ["Pulse"] = "Pulse", ["Starfall"] = "Starfall",
                            ["Wave"] = "Wave", ["Glitch"] = "Glitch", ["Lightning"] = "Lightning",
                        },
                        get = function(info) return self.db.profile.animStyle end,
                        set = function(info, val)
                            self.db.profile.animStyle = val
                            if not self.db.profile.animationParams[val] then
                                self.db.profile.animationParams[val] = CopyTable(self.ANIMATION_STYLE_PARAMS[val])
                            end
                        end,
                    },
                    headerGlobalFX = { name = "Global Glow & Offsets", type = "header", order = 2.1 },
                    glowColor = {
                        name = "Global Glow Color", type = "color", hasAlpha = true, order = 2.2,
                        get = function(info) local c = self.db.profile.glowColor; return c[1], c[2], c[3], c[4] end,
                        set = function(info, r, g, b, a) self.db.profile.glowColor = { r, g, b, a }; self:UpdateSparkColors() end,
                    },
                    glowIntensity = {
                        name = "Glow Intensity", type = "range", min = 0, max = 5, step = 0.1, order = 2.3,
                        get = function(info) return self.db.profile.glowIntensity end,
                        set = function(info, val) self.db.profile.glowIntensity = val end,
                    },
                    headLengthOffset = {
                        name = "Head Offset (Global)", type = "range", min = -100, max = 100, step = 1, order = 2.4,
                        get = function(info) return self.db.profile.headLengthOffset end,
                        set = function(info, val) self.db.profile.headLengthOffset = val end,
                    },
                    tailOffset = {
                        name = "Tail Offset (Global)", type = "range", min = -100, max = 100, step = 1, order = 2.41,
                        get = function(info) return self.db.profile.tailOffset end,
                        set = function(info, val) self.db.profile.tailOffset = val end,
                    },
                    tailLength = {
                        name = "Tail Length (Global)", type = "range", min = 10, max = 500, step = 1, order = 2.42,
                        get = function(info) return self.db.profile.tailLength end,
                        set = function(info, val) self.db.profile.tailLength = val; self:UpdateSparkSize() end,
                    },
                    enableSpark = {
                        name = "Enable Spark", type = "toggle", order = 2,
                        get = function(info) return self.db.profile.enableSpark end,
                        set = function(info, val) self.db.profile.enableSpark = val end,
                    },
                    
                    -- GLOBAL FX SETTINGS
                    headerGlobalFX = { name = "Global Glow & Offsets", type = "header", order = 5 },
                    glowColor = {
                        name = "Global Glow Color", type = "color", hasAlpha = true, order = 6,
                        get = function(info) local c = self.db.profile.glowColor; return c[1], c[2], c[3], c[4] end,
                        set = function(info, r, g, b, a) self.db.profile.glowColor = { r, g, b, a }; self:UpdateSparkColors() end,
                    },
                    glowColorReset = {
                        name = "Reset", type = "execute", width = "half", order = 6.1,
                        func = function() self.db.profile.glowColor = {unpack(defaults.glowColor)}; self:UpdateSparkColors() end,
                    },
                    glowIntensity = {
                        name = "Glow Intensity", type = "range", min = 0, max = 5, step = 0.1, order = 7,
                        get = function(info) return self.db.profile.glowIntensity end,
                        set = function(info, val) self.db.profile.glowIntensity = val end,
                    },
                    headLengthOffset = {
                        name = "Head Offset (Global)", type = "range", min = -100, max = 100, step = 1, order = 8,
                        get = function(info) return self.db.profile.headLengthOffset end,
                        set = function(info, val) self.db.profile.headLengthOffset = val end,
                    },
                    tailOffset = {
                        name = "Tail Offset (Global)", type = "range", min = -100, max = 100, step = 1, order = 9,
                        get = function(info) return self.db.profile.tailOffset end,
                        set = function(info, val) self.db.profile.tailOffset = val end,
                    },
                    tailLength = {
                        name = "Tail Length (Global)", type = "range", min = 10, max = 500, step = 1, order = 9.5,
                        get = function(info) return self.db.profile.tailLength end,
                        set = function(info, val) 
                            self.db.profile.tailLength = val
                            self.db.profile.tail1Length = val
                            self.db.profile.tail2Length = val
                            self.db.profile.tail3Length = val
                            self.db.profile.tail4Length = val
                            self:UpdateSparkSize() 
                        end,
                    },

                    -- TAIL CONFIGURATION
                    headerTails = { name = "Spark & Tail Colors", type = "header", order = 10 },
                    sparkColor = {
                        name = "Spark Head Color", type = "color", hasAlpha = true, order = 11,
                        get = function(info) local c = self.db.profile.sparkColor; return c[1], c[2], c[3], c[4] end,
                        set = function(info, r, g, b, a) self.db.profile.sparkColor = { r, g, b, a }; self:UpdateSparkColors() end,
                    },  
                    sparkColorReset = {
                        name = "Reset", type = "execute", width = "half", order = 11.05,
                        func = function() self.db.profile.sparkColor = {unpack(defaults.sparkColor)}; self:UpdateSparkColors() end,
                    },
                    sparkIntensity = {
                        name = "Spark Intensity", type = "range", min = 0, max = 5, step = 0.05, order = 11.1,
                        get = function(info) return self.db.profile.sparkIntensity end,
                        set = function(info, val) self.db.profile.sparkIntensity = val end,
                    },
                    sparkScale = {
                        name = "Spark Scale", type = "range", min = 0.5, max = 3, step = 0.1, order = 11.2,
                        get = function(info) return self.db.profile.sparkScale end,
                        set = function(info, val) self.db.profile.sparkScale = val; self:UpdateSparkSize() end,
                    },
                    sparkOffset = {
                        name = "Spark X Offset", type = "range", min = -100, max = 100, step = 0.1, order = 11.3,
                        get = function(info) return self.db.profile.sparkOffset end,
                        set = function(info, val) self.db.profile.sparkOffset = val end,
                    },
                    
                    enableTails = {
                        name = "Enable Tails", type = "toggle", order = 12,
                        get = function(info) return self.db.profile.enableTails end,
                        set = function(info, val) self.db.profile.enableTails = val end,
                    },
                    
                    -- Tails (Inline groups)
                    tail1Group = {
                        name = "Tail 1 (Primary)", type = "group", inline = true, order = 13,
                        args = {
                            color = {
                                name = "Color", type = "color", hasAlpha = true, order = 1,
                                get = function(info) local c = self.db.profile.tail1Color; return c[1], c[2], c[3], c[4] end,
                                set = function(info, r, g, b, a) self.db.profile.tail1Color = { r, g, b, a }; self:UpdateSparkColors() end,
                            },
                            colorReset = {
                                name = "Reset", type = "execute", width = "half", order = 1.1,
                                func = function() self.db.profile.tail1Color = {unpack(defaults.tail1Color)}; self:UpdateSparkColors() end,
                            },
                            intensity = {
                                name = "Intensity", type = "range", min = 0, max = 5, step = 0.05, order = 2,
                                get = function(info) return self.db.profile.tail1Intensity end,
                                set = function(info, val) self.db.profile.tail1Intensity = val end,
                            },
                            length = {
                                name = "Length", type = "range", min = 10, max = 400, step = 1, order = 3,
                                get = function(info) return self.db.profile.tail1Length end,
                                set = function(info, val) self.db.profile.tail1Length = val; self:UpdateSparkSize() end,
                            },
                        }
                    },
                    tail2Group = {
                        name = "Tail 2", type = "group", inline = true, order = 14,
                        args = {
                            color = {
                                name = "Color", type = "color", hasAlpha = true, order = 1,
                                get = function(info) local c = self.db.profile.tail2Color; return c[1], c[2], c[3], c[4] end,
                                set = function(info, r, g, b, a) self.db.profile.tail2Color = { r, g, b, a }; self:UpdateSparkColors() end,
                            },
                            colorReset = {
                                name = "Reset", type = "execute", width = "half", order = 1.1,
                                func = function() self.db.profile.tail2Color = {unpack(defaults.tail2Color)}; self:UpdateSparkColors() end,
                            },
                            intensity = {
                                name = "Intensity", type = "range", min = 0, max = 5, step = 0.05, order = 2,
                                get = function(info) return self.db.profile.tail2Intensity end,
                                set = function(info, val) self.db.profile.tail2Intensity = val end,
                            },
                            length = {
                                name = "Length", type = "range", min = 10, max = 400, step = 1, order = 3,
                                get = function(info) return self.db.profile.tail2Length end,
                                set = function(info, val) self.db.profile.tail2Length = val; self:UpdateSparkSize() end,
                            },
                        }
                    },
                    tail3Group = {
                        name = "Tail 3", type = "group", inline = true, order = 15,
                        args = {
                            color = {
                                name = "Color", type = "color", hasAlpha = true, order = 1,
                                get = function(info) local c = self.db.profile.tail3Color; return c[1], c[2], c[3], c[4] end,
                                set = function(info, r, g, b, a) self.db.profile.tail3Color = { r, g, b, a }; self:UpdateSparkColors() end,
                            },
                            colorReset = {
                                name = "Reset", type = "execute", width = "half", order = 1.1,
                                func = function() self.db.profile.tail3Color = {unpack(defaults.tail3Color)}; self:UpdateSparkColors() end,
                            },
                            intensity = {
                                name = "Intensity", type = "range", min = 0, max = 5, step = 0.05, order = 2,
                                get = function(info) return self.db.profile.tail3Intensity end,
                                set = function(info, val) self.db.profile.tail3Intensity = val end,
                            },
                            length = {
                                name = "Length", type = "range", min = 10, max = 400, step = 1, order = 3,
                                get = function(info) return self.db.profile.tail3Length end,
                                set = function(info, val) self.db.profile.tail3Length = val; self:UpdateSparkSize() end,
                            },
                        }
                    },
                    tail4Group = {
                        name = "Tail 4", type = "group", inline = true, order = 16,
                        args = {
                            color = {
                                name = "Color", type = "color", hasAlpha = true, order = 1,
                                get = function(info) local c = self.db.profile.tail4Color; return c[1], c[2], c[3], c[4] end,
                                set = function(info, r, g, b, a) self.db.profile.tail4Color = { r, g, b, a }; self:UpdateSparkColors() end,
                            },
                            colorReset = {
                                name = "Reset", type = "execute", width = "half", order = 1.1,
                                func = function() self.db.profile.tail4Color = {unpack(defaults.tail4Color)}; self:UpdateSparkColors() end,
                            },
                            intensity = {
                                name = "Intensity", type = "range", min = 0, max = 5, step = 0.05, order = 2,
                                get = function(info) return self.db.profile.tail4Intensity end,
                                set = function(info, val) self.db.profile.tail4Intensity = val end,
                            },
                            length = {
                                name = "Length", type = "range", min = 10, max = 400, step = 1, order = 3,
                                get = function(info) return self.db.profile.tail4Length end,
                                set = function(info, val) self.db.profile.tail4Length = val; self:UpdateSparkSize() end,
                            },
                        }
                    },

                    -- ADVANCED STYLE PARAMETERS
                    headerAdvanced = { name = "Advanced Style Settings", type = "header", order = 20 },
                    styleSpecificGroup = {
                        name = "Fine Tune Animation",
                        type = "group", inline = true, order = 21,
                        hidden = function()
                            local style = self.db.profile.animStyle
                            return style == "Comet" or not self.db.profile.animationParams[style]
                        end,
                        args = {
                             -- Orb Settings
                             orbRotationSpeed = {
                                name = "Rotation Speed", type = "range", min = 1, max = 20, step = 1, order = 1,
                                hidden = function() return self.db.profile.animStyle ~= "Orb" end,
                                get = function(info) return self.db.profile.animationParams["Orb"].rotationSpeed end,
                                set = function(info, val) self.db.profile.animationParams["Orb"].rotationSpeed = val end,
                            },
                            orbRadius = {
                                name = "Orb Radius", type = "range", min = 0.1, max = 1.0, step = 0.1, order = 2,
                                hidden = function() return self.db.profile.animStyle ~= "Orb" end,
                                get = function(info) return self.db.profile.animationParams["Orb"].radiusMultiplier end,
                                set = function(info, val) self.db.profile.animationParams["Orb"].radiusMultiplier = val end,
                            },
                            orbGlowPulse = {
                                name = "Glow Pulse", type = "range", min = 0.1, max = 2.0, step = 0.1, order = 3,
                                hidden = function() return self.db.profile.animStyle ~= "Orb" end,
                                get = function(info) return self.db.profile.animationParams["Orb"].glowPulse end,
                                set = function(info, val) self.db.profile.animationParams["Orb"].glowPulse = val end,
                            },
                            -- Pulse Settings
                            pulseMaxScale = {
                                name = "Max Scale", type = "range", min = 1.0, max = 5.0, step = 0.1, order = 10,
                                hidden = function() return self.db.profile.animStyle ~= "Pulse" end,
                                get = function(info) return self.db.profile.animationParams["Pulse"].maxScale end,
                                set = function(info, val) self.db.profile.animationParams["Pulse"].maxScale = val end,
                            },
                            pulseRippleCycle = {
                                name = "Ripple Cycle", type = "range", min = 0.5, max = 3.0, step = 0.1, order = 11,
                                hidden = function() return self.db.profile.animStyle ~= "Pulse" end,
                                get = function(info) return self.db.profile.animationParams["Pulse"].rippleCycle end,
                                set = function(info, val) self.db.profile.animationParams["Pulse"].rippleCycle = val end,
                            },
                            pulseFadeSpeed = { -- RESTAURADO: Faltaba
                                name = "Fade Speed", type = "range", min = 0.1, max = 3.0, step = 0.1, order = 12,
                                hidden = function() return self.db.profile.animStyle ~= "Pulse" end,
                                get = function(info) return self.db.profile.animationParams["Pulse"].fadeSpeed end,
                                set = function(info, val) self.db.profile.animationParams["Pulse"].fadeSpeed = val end,
                            },
                            -- Starfall Settings
                            starfallFallSpeed = {
                                name = "Fall Speed", type = "range", min = 1.0, max = 10.0, step = 0.5, order = 20,
                                hidden = function() return self.db.profile.animStyle ~= "Starfall" end,
                                get = function(info) return self.db.profile.animationParams["Starfall"].fallSpeed end,
                                set = function(info, val) self.db.profile.animationParams["Starfall"].fallSpeed = val end,
                            },
                            starfallSwayAmount = {
                                name = "Sway Amount", type = "range", min = 0, max = 20, step = 1, order = 21,
                                hidden = function() return self.db.profile.animStyle ~= "Starfall" end,
                                get = function(info) return self.db.profile.animationParams["Starfall"].swayAmount end,
                                set = function(info, val) self.db.profile.animationParams["Starfall"].swayAmount = val end,
                            },
                            starfallParticleSpeed = { -- RESTAURADO: Faltaba
                                name = "Particle Speed", type = "range", min = 0.1, max = 10.0, step = 0.1, order = 22,
                                hidden = function() return self.db.profile.animStyle ~= "Starfall" end,
                                get = function(info) return self.db.profile.animationParams["Starfall"].particleSpeed end,
                                set = function(info, val) self.db.profile.animationParams["Starfall"].particleSpeed = val end,
                            },
                            -- Flux Settings
                            fluxJitterY = {
                                name = "Vertical Jitter", type = "range", min = 1.0, max = 10.0, step = 0.5, order = 30,
                                hidden = function() return self.db.profile.animStyle ~= "Flux" end,
                                get = function(info) return self.db.profile.animationParams["Flux"].jitterY end,
                                set = function(info, val) self.db.profile.animationParams["Flux"].jitterY = val end,
                            },
                            fluxJitterX = {
                                name = "Horizontal Jitter", type = "range", min = 1.0, max = 10.0, step = 0.5, order = 31,
                                hidden = function() return self.db.profile.animStyle ~= "Flux" end,
                                get = function(info) return self.db.profile.animationParams["Flux"].jitterX end,
                                set = function(info, val) self.db.profile.animationParams["Flux"].jitterX = val end,
                            },
                            fluxDrift = { -- RESTAURADO: Faltaba
                                name = "Drift Speed", type = "range", min = 0, max = 1, step = 0.01, order = 32,
                                hidden = function() return self.db.profile.animStyle ~= "Flux" end,
                                get = function(info) return self.db.profile.animationParams["Flux"].driftMultiplier end,
                                set = function(info, val) self.db.profile.animationParams["Flux"].driftMultiplier = val end,
                            },
                            -- Helix Settings
                            helixDriftMultiplier = {
                                name = "Drift Multiplier", type = "range", min = 0.01, max = 0.3, step = 0.01, order = 40,
                                hidden = function() return self.db.profile.animStyle ~= "Helix" end,
                                get = function(info) return self.db.profile.animationParams["Helix"].driftMultiplier end,
                                set = function(info, val) self.db.profile.animationParams["Helix"].driftMultiplier = val end,
                            },
                            helixAmplitude = {
                                name = "Wave Amplitude", type = "range", min = 0.1, max = 1.0, step = 0.1, order = 41,
                                hidden = function() return self.db.profile.animStyle ~= "Helix" end,
                                get = function(info) return self.db.profile.animationParams["Helix"].amplitude end,
                                set = function(info, val) self.db.profile.animationParams["Helix"].amplitude = val end,
                            },
                            helixWaveSpeed = {
                                name = "Wave Speed", type = "range", min = 1, max = 20, step = 1, order = 42,
                                hidden = function() return self.db.profile.animStyle ~= "Helix" end,
                                get = function(info) return self.db.profile.animationParams["Helix"].waveSpeed end,
                                set = function(info, val) self.db.profile.animationParams["Helix"].waveSpeed = val end,
                            },
                            -- Wave Settings
                            waveCount = {
                                name = "Wave Count", type = "range", min = 1, max = 10, step = 1, order = 50,
                                hidden = function() return self.db.profile.animStyle ~= "Wave" end,
                                get = function(info) return self.db.profile.animationParams["Wave"].waveCount end,
                                set = function(info, val) self.db.profile.animationParams["Wave"].waveCount = val end,
                            },
                            waveSpeed = {
                                name = "Wave Speed", type = "range", min = 0.1, max = 2.0, step = 0.1, order = 51,
                                hidden = function() return self.db.profile.animStyle ~= "Wave" end,
                                get = function(info) return self.db.profile.animationParams["Wave"].waveSpeed end,
                                set = function(info, val) self.db.profile.animationParams["Wave"].waveSpeed = val end,
                            },
                            waveAmplitude = {
                                name = "Amplitude", type = "range", min = 0.01, max = 0.2, step = 0.01, order = 52,
                                hidden = function() return self.db.profile.animStyle ~= "Wave" end,
                                get = function(info) return self.db.profile.animationParams["Wave"].amplitude end,
                                set = function(info, val) self.db.profile.animationParams["Wave"].amplitude = val end,
                            },
                            waveWidth = {
                                name = "Width", type = "range", min = 0.1, max = 0.5, step = 0.05, order = 53,
                                hidden = function() return self.db.profile.animStyle ~= "Wave" end,
                                get = function(info) return self.db.profile.animationParams["Wave"].waveWidth end,
                                set = function(info, val) self.db.profile.animationParams["Wave"].waveWidth = val end,
                            },
                            -- Glitch Settings
                            glitchChance = {
                                name = "Glitch Intensity", type = "range", min = 0.01, max = 0.5, step = 0.01, order = 70,
                                hidden = function() return self.db.profile.animStyle ~= "Glitch" end,
                                get = function(info) return self.db.profile.animationParams["Glitch"].glitchChance end,
                                set = function(info, val) self.db.profile.animationParams["Glitch"].glitchChance = val end,
                            },
                            glitchMaxOffset = {
                                name = "Max Glitch Offset", type = "range", min = 1, max = 20, step = 1, order = 71,
                                hidden = function() return self.db.profile.animStyle ~= "Glitch" end,
                                get = function(info) return self.db.profile.animationParams["Glitch"].maxOffset end,
                                set = function(info, val) self.db.profile.animationParams["Glitch"].maxOffset = val end,
                            },
                            glitchColorIntensity = {
                                name = "Color Intensity", type = "range", min = 0, max = 1, step = 0.05, order = 72,
                                hidden = function() return self.db.profile.animStyle ~= "Glitch" end,
                                get = function(info) return self.db.profile.animationParams["Glitch"].colorIntensity end,
                                set = function(info, val) self.db.profile.animationParams["Glitch"].colorIntensity = val end,
                            },
                            -- Lightning Settings
                            lightningChance = {
                                name = "Frequency", type = "range", min = 0.1, max = 1.0, step = 0.1, order = 80,
                                hidden = function() return self.db.profile.animStyle ~= "Lightning" end,
                                get = function(info) return self.db.profile.animationParams["Lightning"].lightningChance end,
                                set = function(info, val) self.db.profile.animationParams["Lightning"].lightningChance = val end,
                            },
                            lightningSegmentCount = {
                                name = "Segment Count", type = "range", min = 1, max = 10, step = 1, order = 81,
                                hidden = function() return self.db.profile.animStyle ~= "Lightning" end,
                                get = function(info) return self.db.profile.animationParams["Lightning"].segmentCount end,
                                set = function(info, val) self.db.profile.animationParams["Lightning"].segmentCount = val end,
                            },
                        }
                    },
                    resetStyleSettings = {
                        name = "Reset Animation Defaults",
                        type = "execute",
                        width = "full",
                        order = 100,
                        func = function()
                            local currentStyle = self.db.profile.animStyle
                            if currentStyle and defaults.animationParams[currentStyle] then
                                self.db.profile.animationParams[currentStyle] = CopyTable(defaults.animationParams[currentStyle])
                            end

                            -- Reset Global Anim Settings
                            local keysToReset = {
                                "enableSpark", "enableTails", "sparkColor", "glowColor", 
                                "sparkIntensity", "glowIntensity", "sparkScale", "sparkOffset", "headLengthOffset",
                                "tailLength", "tailOffset",
                                "tail1Color", "tail1Intensity", "tail1Length",
                                "tail2Color", "tail2Intensity", "tail2Length",
                                "tail3Color", "tail3Intensity", "tail3Length",
                                "tail4Color", "tail4Intensity", "tail4Length",
                            }

                            for _, key in ipairs(keysToReset) do
                                if type(defaults[key]) == "table" then
                                    self.db.profile[key] = CopyTable(defaults[key])
                                else
                                    self.db.profile[key] = defaults[key]
                                end
                            end

                            self:UpdateSparkColors()
                            self:UpdateSparkSize()
                            LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON_NAME)
                        end,
                    },
                }
            },
            
            profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
        }
    }

    local LibDualSpec = LibStub("LibDualSpec-1.0", true)
    if LibDualSpec then
        LibDualSpec:EnhanceOptions(options.args.profiles, self.db)
    end

    LibStub("AceConfig-3.0"):RegisterOptionsTable(ADDON_NAME, options)
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(ADDON_NAME, ADDON_NAME)
end
