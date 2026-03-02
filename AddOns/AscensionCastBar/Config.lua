-------------------------------------------------------------------------------
-- Project: AscensionCastBar
-- Author: Aka-DoctorCode
-- File: Config.lua
-- Version: V45
-------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code are the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in
-- derivative works without express written permission.
-------------------------------------------------------------------------------
local ADDON_NAME = "Ascension Cast Bar"
---@class AscensionCastBar
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
        height = 24,
        testAttached = false,

        -- Manual / Fallback Settings
        manualWidth = 220,
        manualHeight = 24,
        point = "CENTER",
        relativePoint = "CENTER",
        manualX = 0,
        manualY = -130,

        -- Empower Colors
        empowerStage1Color = { 0, 1, 0, 1 },    -- Green
        empowerStage2Color = { 1, 1, 0, 1 },    -- Yellow
        empowerStage3Color = { 1, 0.64, 0, 1 }, -- Orange
        empowerStage4Color = { 1, 0, 0, 1 },    -- Red
        empowerStage5Color = { 0.6, 0, 1, 1 },  -- Purple (Default)
        empowerWidthScale = false,

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
        barLSMName = "TukTex",
        useClassColor = true,

        -- Anim
        enableSpark = false,
        enableTails = false,
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
    -- Helper to get fonts (Avoids errors if LSM doesn't load)
    local function GetFontList()
        local fonts = {}
        if LSM then
            for _, name in ipairs(LSM:List("font")) do
                fonts[name] = name
            end
        end
        return fonts
    end

    -- Helper to get textures (Avoids AceGUIWidgetLSMlists error)
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
        ["CENTER"] = "中央",
        ["TOP"] = "上",
        ["BOTTOM"] = "下",
        ["LEFT"] = "左",
        ["RIGHT"] = "右",
    }

    local options = {
        name = "施法條美化",
        handler = AscensionCastBar,
        type = "group",
        childGroups = "tab", -- Tabbed interface
        args = {
            -- ==========================================================
            -- TAB 1: GENERAL (Positioning, Size, Testing)
            -- ==========================================================
            general = {
                name = "一般與佈局",
                type = "group",
                order = 1,
                args = {
                    -- SECTION: TEST MODE
                    headerTest = { name = "設定與測試", type = "header", order = 1 },
                    preview = {
                        name = "啟用測試模式",
                        desc = "顯示預覽條以協助你調整佈局。",
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
                        name = "動畫類型",
                        desc = "模擬不同的施法類型。",
                        type = "select",
                        values = { ["Cast"] = "普通施法", ["Channel"] = "引導", ["Empowered"] = "蓄力" },
                        order = 3,
                        disabled = function() return not self.db.profile.previewEnabled end,
                        get = function(info) return self.db.profile.testModeState end,
                        set = function(info, val)
                            self.db.profile.testModeState = val
                            if self.db.profile.previewEnabled then self:ToggleTestMode(true) end
                        end,
                    },
                    hideDefaultCastbar = {
                        name = "隱藏暴雪內建施法條",
                        type = "toggle",
                        order = 4,
                        get = function(info) return self.db.profile.hideDefaultCastbar end,
                        set = function(info, val)
                            self.db.profile.hideDefaultCastbar = val
                            self:UpdateDefaultCastBarVisibility()
                        end,
                    },

                    -- SECTION: SIZE
                    headerSize = { name = "尺寸", type = "header", order = 10 },
                    manualWidth = {
                        name = "施法條寬度",
                        type = "range",
                        min = 50,
                        max = 1000,
                        step = 1,
                        order = 11,
                        get = function(info) return self.db.profile.manualWidth end,
                        set = function(info, val)
                            self.db.profile.manualWidth = val; self:UpdateAnchor()
                        end,
                    },
                    height = {
                        name = "施法條高度",
                        type = "range",
                        min = 10,
                        max = 150,
                        step = 1,
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
                    headerPos = { name = "位置", type = "header", order = 20 },
                    attachToCDM = {
                        name = "附著到 UI 框架",
                        desc = "自動將施法條附著到 UI 元素（如玩家框架）。",
                        type = "toggle",
                        width = "full",
                        order = 21,
                        get = function(info) return self.db.profile.attachToCDM end,
                        set = function(info, val)
                            self.db.profile.attachToCDM = val; self:InitCDMHooks(); self:UpdateAnchor()
                        end,
                    },
                    testAttached = {
                        name = "測試附著",
                        desc = "切換為測試附著位置（開啟）或手動位置（關閉）。",
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
                        name = "座標",
                        type = "group",
                        inline = true,
                        order = 23,
                        args = {
                            -- Manual
                            point = {
                                name = "錨點",
                                type = "select",
                                values = anchors,
                                order = 1,
                                hidden = function() return self.db.profile.attachToCDM end,
                                get = function(info) return self.db.profile.point end,
                                set = function(info, val)
                                    self.db.profile.point = val; self:UpdateAnchor()
                                end,
                            },
                            relativePoint = {
                                name = "相對錨點",
                                desc = "錨定到父框架（或螢幕）上的位置。",
                                type = "select",
                                values = anchors,
                                order = 1.5,
                                hidden = function() return self.db.profile.attachToCDM end,
                                get = function(info) return self.db.profile.relativePoint end,
                                set = function(info, val)
                                    self.db.profile.relativePoint = val; self:UpdateAnchor()
                                end,
                            },
                            manualX = {
                                name = "X 偏移",
                                type = "range",
                                min = -2000,
                                max = 2000,
                                step = 1,
                                order = 2,
                                hidden = function() return self.db.profile.attachToCDM end,
                                get = function(info) return self.db.profile.manualX end,
                                set = function(info, val)
                                    self.db.profile.manualX = val; self:UpdateAnchor()
                                end,
                            },
                            manualY = {
                                name = "Y 偏移",
                                type = "range",
                                min = -2000,
                                max = 2000,
                                step = 1,
                                order = 3,
                                hidden = function() return self.db.profile.attachToCDM end,
                                get = function(info) return self.db.profile.manualY end,
                                set = function(info, val)
                                    self.db.profile.manualY = val; self:UpdateAnchor()
                                end,
                            },
                            -- Attached
                            cdmTarget = {
                                name = "附著目標",
                                type = "select",
                                style = "dropdown",
                                width = "normal",
                                order = 1,
                                hidden = function() return not self.db.profile.attachToCDM end,
                                get = function(info) return self.db.profile.cdmTarget end,
                                set = function(info, val)
                                    self.db.profile.cdmTarget = val; self:InitCDMHooks(); self:UpdateAnchor()
                                end,

                                -- 1. THE DISPLAY NAMES (The text the user sees)
                                values = {
                                    -- 標準框架
                                    ["PlayerFrame"] = "玩家框架",
                                    ["PersonalResource"] = "個人資源顯示",

                                    -- CDM 專用
                                    ["Buffs"] = "追蹤增益 (CDM)",
                                    ["Essential"] = "核心冷卻 (CDM)",
                                    ["Utility"] = "實用冷卻 (CDM)",

                                    -- 標準動作條
                                    ["ActionBar1"] = "動作條 1",
                                    ["ActionBar2"] = "動作條 2",
                                    ["ActionBar3"] = "動作條 3",
                                    ["ActionBar4"] = "動作條 4",
                                    ["ActionBar5"] = "動作條 5",
                                    ["ActionBar6"] = "動作條 6",
                                    ["ActionBar7"] = "動作條 7",
                                    ["ActionBar8"] = "動作條 8",

                                    -- Bartender4 支援
                                    ["BT4Bar1"] = "Bartender 快捷列 1",
                                    ["BT4Bar2"] = "Bartender 快捷列 2",
                                    ["BT4Bar3"] = "Bartender 快捷列 3",
                                    ["BT4Bar4"] = "Bartender 快捷列 4",
                                    ["BT4Bar5"] = "Bartender 快捷列 5",
                                    ["BT4Bar6"] = "Bartender 快捷列 6",
                                    ["BT4Bar7"] = "Bartender 快捷列 7",
                                    ["BT4Bar8"] = "Bartender 快捷列 8",
                                    ["BT4Bar9"] = "Bartender 快捷列 9",
                                    ["BT4Bar10"] = "Bartender 快捷列 10",
                                    ["BT4PetBar"] = "Bartender 寵物列",
                                    ["BT4StanceBar"] = "Bartender 姿態列",
                                },

                                -- 2. THE SORTING ORDER (The list of KEYS in the desired order)
                                sorting = {
                                    "PlayerFrame", "PersonalResource", "Buffs", "Essential", "Utility", "ActionBar1",
                                    "ActionBar2", "ActionBar3", "ActionBar4", "ActionBar5", "ActionBar6", "ActionBar7",
                                    "ActionBar8", "BT4Bar1", "BT4Bar2", "BT4Bar3", "BT4Bar4", "BT4Bar5", "BT4Bar6",
                                    "BT4Bar7", "BT4Bar8", "BT4Bar9", "BT4Bar10", "BT4PetBar", "BT4StanceBar"
                                },
                            },
                            cdmYOffset = {
                                name = "垂直偏移",
                                type = "range",
                                min = -200,
                                max = 200,
                                step = 1,
                                order = 2,
                                hidden = function() return not self.db.profile.attachToCDM end,
                                get = function(info) return self.db.profile.cdmYOffset end,
                                set = function(info, val)
                                    self.db.profile.cdmYOffset = val; self:UpdateAnchor()
                                end,
                            },
                        }
                    }
                }
            },

            -- ==========================================================
            -- TAB 2: APPEARANCE (Colors, Textures, Icons)
            -- ==========================================================
            appearance = {
                name = "樣式與顏色",
                type = "group",
                order = 2,
                args = {
                    headerBar = { name = "施法條樣式", type = "header", order = 1 },
                    barTexture = {
                        name = "材質",
                        type = "select",
                        dialogControl = hasLSMWidgets and "LSM30_Statusbar" or nil,
                        values = GetStatusBarList,
                        order = 2,
                        get = function(info) return self.db.profile.barLSMName end,
                        set = function(info, val)
                            self.db.profile.barLSMName = val; self:UpdateBarTexture()
                        end,
                    },
                    useClassColor = {
                        name = "使用職業顏色",
                        type = "toggle",
                        order = 2.1,
                        get = function(info) return self.db.profile.useClassColor end,
                        set = function(info, val)
                            self.db.profile.useClassColor = val; self:UpdateBarColor()
                        end,
                    },
                    barColor = {
                        name = "施法條顏色",
                        type = "color",
                        hasAlpha = true,
                        order = 3,
                        disabled = function() return self.db.profile.useClassColor end,
                        get = function(info)
                            local c = self.db.profile.barColor; return c[1], c[2], c[3], c[4]
                        end,
                        set = function(info, r, g, b, a)
                            self.db.profile.barColor = { r, g, b, a }; self:UpdateBarColor()
                        end,
                    },
                    barColorReset = {
                        name = "重置",
                        type = "execute",
                        width = "half",
                        order = 3.1,
                        func = function()
                            self.db.profile.barColor = { unpack(defaults.barColor) }; self:UpdateBarColor()
                        end,
                    },
                    bgColor = {
                        name = "背景顏色",
                        type = "color",
                        hasAlpha = true,
                        order = 4,
                        get = function(info)
                            local c = self.db.profile.bgColor; return c[1], c[2], c[3], c[4]
                        end,
                        set = function(info, r, g, b, a)
                            self.db.profile.bgColor = { r, g, b, a }; self:UpdateBackground()
                        end,
                    },
                    bgColorReset = {
                        name = "重置",
                        type = "execute",
                        width = "half",
                        order = 4.1,
                        func = function()
                            self.db.profile.bgColor = { unpack(defaults.bgColor) }; self:UpdateBackground()
                        end,
                    },

                    headerBorder = { name = "邊框", type = "header", order = 10 },
                    borderEnabled = {
                        name = "啟用邊框",
                        type = "toggle",
                        order = 11,
                        get = function(info) return self.db.profile.borderEnabled end,
                        set = function(info, val)
                            self.db.profile.borderEnabled = val; self:UpdateBorder()
                        end,
                    },
                    borderColor = {
                        name = "邊框顏色",
                        type = "color",
                        hasAlpha = true,
                        order = 12,
                        disabled = function() return not self.db.profile.borderEnabled end,
                        get = function(info)
                            local c = self.db.profile.borderColor; return c[1], c[2], c[3], c[4]
                        end,
                        set = function(info, r, g, b, a)
                            self.db.profile.borderColor = { r, g, b, a }; self:UpdateBorder()
                        end,
                    },
                    borderColorReset = {
                        name = "重置",
                        type = "execute",
                        width = "half",
                        order = 12.1,
                        disabled = function() return not self.db.profile.borderEnabled end,
                        func = function()
                            self.db.profile.borderColor = { unpack(defaults.borderColor) }; self:UpdateBorder()
                        end,
                    },
                    borderThickness = {
                        name = "厚度",
                        type = "range",
                        min = 1,
                        max = 10,
                        step = 1,
                        order = 13,
                        disabled = function() return not self.db.profile.borderEnabled end,
                        get = function(info) return self.db.profile.borderThickness end,
                        set = function(info, val)
                            self.db.profile.borderThickness = val; self:UpdateBorder()
                        end,
                    },

                    headerIcon = { name = "法術圖示", type = "header", order = 20 },
                    showIcon = {
                        name = "顯示圖示",
                        type = "toggle",
                        order = 21,
                        get = function(info) return self.db.profile.showIcon end,
                        set = function(info, val)
                            self.db.profile.showIcon = val; self:UpdateIcon()
                        end,
                    },
                    iconGroup = {
                        name = "圖示設定",
                        type = "group",
                        inline = true,
                        order = 22,
                        hidden = function() return not self.db.profile.showIcon end,
                        args = {
                            detachIcon = {
                                name = "分離",
                                type = "toggle",
                                order = 1,
                                get = function(info) return self.db.profile.detachIcon end,
                                set = function(info, val)
                                    self.db.profile.detachIcon = val; self:UpdateIcon()
                                end,
                            },
                            iconAnchor = {
                                name = "位置",
                                type = "select",
                                values = { ["Left"] = "左", ["Right"] = "右" },
                                order = 2,
                                get = function(info) return self.db.profile.iconAnchor end,
                                set = function(info, val)
                                    self.db.profile.iconAnchor = val; self:UpdateIcon()
                                end,
                            },
                            iconSize = {
                                name = "大小",
                                type = "range",
                                min = 10,
                                max = 128,
                                step = 1,
                                order = 3,
                                get = function(info) return self.db.profile.iconSize end,
                                set = function(info, val)
                                    self.db.profile.iconSize = val; self:UpdateIcon()
                                end,
                            },
                            iconX = {
                                name = "X 偏移",
                                type = "range",
                                min = -200,
                                max = 200,
                                step = 1,
                                order = 4,
                                get = function(info) return self.db.profile.iconX end,
                                set = function(info, val)
                                    self.db.profile.iconX = val; self:UpdateIcon()
                                end,
                            },
                            iconY = {
                                name = "Y 偏移",
                                type = "range",
                                min = -200,
                                max = 200,
                                step = 1,
                                order = 5,
                                get = function(info) return self.db.profile.iconY end,
                                set = function(info, val)
                                    self.db.profile.iconY = val; self:UpdateIcon()
                                end,
                            },
                        }
                    }
                }
            },

            -- ==========================================================
            -- TAB 3: TEXT (Fonts, Labels)
            -- ==========================================================
            text = {
                name = "文字與字型",
                type = "group",
                order = 3,
                args = {
                    headerFont = { name = "全域字型設定", type = "header", order = 1 },
                    font = {
                        name = "字型",
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
                        name = "字型描邊",
                        type = "select",
                        values = { ["NONE"] = "無", ["OUTLINE"] = "描邊", ["THICKOUTLINE"] = "粗描邊", ["MONOCHROME"] = "單色" },
                        order = 3,
                        get = function(info) return self.db.profile.outline end,
                        set = function(info, val)
                            self.db.profile.outline = val; self:ApplyFont()
                        end,
                    },
                    headerName = { name = "法術名稱", type = "header", order = 10 },
                    showSpellText = {
                        name = "顯示名稱",
                        type = "toggle",
                        order = 11,
                        get = function(info) return self.db.profile.showSpellText end,
                        set = function(info, val)
                            self.db.profile.showSpellText = val; self:UpdateTextVisibility()
                        end,
                    },
                    truncateSpellName = {
                        name = "截斷名稱",
                        type = "toggle",
                        order = 11.1,
                        get = function(info) return self.db.profile.truncateSpellName end,
                        set = function(info, val) self.db.profile.truncateSpellName = val end,
                    },
                    truncateLength = {
                        name = "最大字數",
                        type = "range",
                        min = 5,
                        max = 100,
                        step = 1,
                        order = 11.2,
                        disabled = function() return not self.db.profile.truncateSpellName end,
                        get = function(info) return self.db.profile.truncateLength end,
                        set = function(info, val) self.db.profile.truncateLength = val end,
                    },
                    fontSizeSpell = {
                        name = "大小",
                        type = "range",
                        min = 8,
                        max = 32,
                        step = 1,
                        order = 12,
                        get = function(info) return self.db.profile.spellNameFontSize end,
                        set = function(info, val)
                            self.db.profile.spellNameFontSize = val; self:ApplyFont()
                        end,
                    },
                    fontColor = {
                        name = "顏色",
                        type = "color",
                        hasAlpha = true,
                        order = 13,
                        get = function(info)
                            local c = self.db.profile.fontColor; return c[1], c[2], c[3], c[4]
                        end,
                        set = function(info, r, g, b, a)
                            self.db.profile.fontColor = { r, g, b, a }; self:ApplyFont()
                        end,
                    },
                    fontColorReset = {
                        name = "重置",
                        type = "execute",
                        width = "half",
                        order = 13.1,
                        func = function()
                            self.db.profile.fontColor = { unpack(defaults.fontColor) }; self:ApplyFont()
                        end,
                    },
                    headerTimer = { name = "計時器", type = "header", order = 20 },
                    showTimerText = {
                        name = "顯示計時器",
                        type = "toggle",
                        order = 21,
                        get = function(info) return self.db.profile.showTimerText end,
                        set = function(info, val) self.db.profile.showTimerText = val end,
                    },
                    hideTimerOnChannel = {
                        name = "引導時隱藏",
                        type = "toggle",
                        order = 21.1,
                        get = function(info) return self.db.profile.hideTimerOnChannel end,
                        set = function(info, val) self.db.profile.hideTimerOnChannel = val end,
                    },
                    timerFormat = {
                        name = "格式",
                        type = "select",
                        values = { ["Remaining"] = "剩餘時間", ["Duration"] = "已用時間", ["Total"] = "總時間" },
                        order = 22,
                        get = function(info) return self.db.profile.timerFormat end,
                        set = function(info, val) self.db.profile.timerFormat = val end,
                    },
                    fontSizeTimer = {
                        name = "大小",
                        type = "range",
                        min = 8,
                        max = 32,
                        step = 1,
                        order = 23,
                        get = function(info) return self.db.profile.timerFontSize end,
                        set = function(info, val)
                            self.db.profile.timerFontSize = val; self:ApplyFont()
                        end,
                    },
                    useSharedColor = {
                        name = "使用共用顏色",
                        desc = "使用與法術名稱相同的顏色。",
                        type = "toggle",
                        order = 24,
                        get = function(info) return self.db.profile.useSharedColor end,
                        set = function(info, val)
                            self.db.profile.useSharedColor = val; self:ApplyFont()
                        end,
                    },
                    timerColor = {
                        name = "計時器顏色",
                        type = "color",
                        hasAlpha = true,
                        order = 25,
                        disabled = function() return self.db.profile.useSharedColor end,
                        get = function(info)
                            local c = self.db.profile.timerColor; return c[1], c[2], c[3], c[4]
                        end,
                        set = function(info, r, g, b, a)
                            self.db.profile.timerColor = { r, g, b, a }; self:ApplyFont()
                        end,
                    },
                    timerColorReset = {
                        name = "重置",
                        type = "execute",
                        width = "half",
                        order = 25.1,
                        disabled = function() return self.db.profile.useSharedColor end,
                        func = function()
                            self.db.profile.timerColor = { unpack(defaults.timerColor) }; self:ApplyFont()
                        end,
                    },
                    -- TEXT POSITIONING & BACKDROP
                    headerTextPos = { name = "位置與背景板", type = "header", order = 30 },
                    detachText = {
                        name = "分離文字",
                        type = "toggle",
                        order = 31,
                        get = function(info) return self.db.profile.detachText end,
                        set = function(info, val)
                            self.db.profile.detachText = val; self:UpdateTextLayout()
                        end,
                    },
                    textX = {
                        name = "X 偏移",
                        type = "range",
                        min = -200,
                        max = 200,
                        step = 1,
                        order = 32,
                        hidden = function() return not self.db.profile.detachText end,
                        get = function(info) return self.db.profile.textX end,
                        set = function(info, val)
                            self.db.profile.textX = val; self:UpdateTextLayout()
                        end,
                    },
                    textY = {
                        name = "Y 偏移",
                        type = "range",
                        min = -200,
                        max = 200,
                        step = 1,
                        order = 33,
                        hidden = function() return not self.db.profile.detachText end,
                        get = function(info) return self.db.profile.textY end,
                        set = function(info, val)
                            self.db.profile.textY = val; self:UpdateTextLayout()
                        end,
                    },
                    textWidth = {
                        name = "文字區域寬度",
                        type = "range",
                        min = 50,
                        max = 500,
                        step = 1,
                        order = 34,
                        hidden = function() return not self.db.profile.detachText end,
                        get = function(info) return self.db.profile.textWidth end,
                        set = function(info, val)
                            self.db.profile.textWidth = val; self:UpdateTextLayout()
                        end,
                    },
                    textBackdropEnabled = {
                        name = "啟用背景板",
                        type = "toggle",
                        order = 35,
                        get = function(info) return self.db.profile.textBackdropEnabled end,
                        set = function(info, val)
                            self.db.profile.textBackdropEnabled = val; self:UpdateTextLayout()
                        end,
                    },
                    textBackdropColor = {
                        name = "背景板顏色",
                        type = "color",
                        hasAlpha = true,
                        order = 36,
                        hidden = function() return not self.db.profile.textBackdropEnabled end,
                        get = function(info)
                            local c = self.db.profile.textBackdropColor; return c[1], c[2], c[3], c[4]
                        end,
                        set = function(info, r, g, b, a)
                            self.db.profile.textBackdropColor = { r, g, b, a }; self:UpdateTextLayout()
                        end,
                    },
                    textBackdropColorReset = {
                        name = "重置",
                        type = "execute",
                        width = "half",
                        order = 36.1,
                        hidden = function() return not self.db.profile.textBackdropEnabled end,
                        func = function()
                            self.db.profile.textBackdropColor = { unpack(defaults.textBackdropColor) }; self
                                :UpdateTextLayout()
                        end,
                    },
                }
            },

            -- ==========================================================
            -- TAB 4: MECHANICS (Latency, Empower, Channels)
            -- ==========================================================
            mechanics = {
                name = "機制",
                type = "group",
                order = 4,
                args = {
                    headerLatency = { name = "延遲", type = "header", order = 1 },
                    showLatency = {
                        name = "顯示延遲",
                        type = "toggle",
                        order = 2,
                        get = function(info) return self.db.profile.showLatency end,
                        set = function(info, val)
                            self.db.profile.showLatency = val
                            if self.db.profile.previewEnabled then self:UpdateLatencyBar(self.castBar) end
                        end,
                    },
                    latencyColor = {
                        name = "延遲顏色",
                        type = "color",
                        hasAlpha = true,
                        order = 34.6,
                        get = function(info)
                            local c = self.db.profile.latencyColor; return c[1], c[2], c[3], c[4]
                        end,
                        set = function(info, r, g, b, a) self.db.profile.latencyColor = { r, g, b, a } end,
                    },
                    latencyColorReset = {
                        name = "重置",
                        type = "execute",
                        width = "half",
                        order = 34.7,
                        func = function() self.db.profile.latencyColor = { unpack(defaults.latencyColor) } end,
                    },
                    latencyMaxPercent = {
                        name = "最大寬度 %",
                        desc = "設定延遲指示器可佔用施法條的最大寬度百分比。",
                        type = "range",
                        min = 0.1,
                        max = 1.0,
                        step = 0.05,
                        order = 34.8,
                        get = function(info) return self.db.profile.latencyMaxPercent end,
                        set = function(info, val)
                            self.db.profile.latencyMaxPercent = val
                            if self.db.profile.previewEnabled then self:UpdateLatencyBar(self.castBar) end
                        end,
                    },

                    headerChannel = { name = "引導法術", type = "header", order = 10 },
                    reverseChanneling = {
                        name = "反向引導",
                        desc = "填充施法條而非清空。",
                        type = "toggle",
                        order = 11,
                        get = function(info) return self.db.profile.reverseChanneling end,
                        set = function(info, val)
                            self.db.profile.reverseChanneling = val; if self.db.profile.previewEnabled then
                                self
                                    :ToggleTestMode(true)
                            end
                        end,
                    },
                    showChannelTicks = {
                        name = "顯示刻度",
                        type = "toggle",
                        order = 12,
                        get = function(info) return self.db.profile.showChannelTicks end,
                        set = function(info, val)
                            self.db.profile.showChannelTicks = val
                            if self.db.profile.previewEnabled and self.db.profile.testModeState == "Channel" then
                                self:UpdateTicks(234153, 0, 10)
                            end
                        end,
                    },
                    channelTicksThickness = {
                        name = "刻度厚度",
                        type = "range",
                        min = 1,
                        max = 10,
                        step = 1,
                        order = 12.1,
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
                        name = "刻度顏色",
                        type = "color",
                        hasAlpha = true,
                        order = 12.2,
                        disabled = function() return not self.db.profile.showChannelTicks end,
                        get = function(info)
                            local c = self.db.profile.channelTicksColor; return c[1], c[2], c[3], c[4]
                        end,
                        set = function(info, r, g, b, a)
                            self.db.profile.channelTicksColor = { r, g, b, a }
                            if self.db.profile.previewEnabled and self.db.profile.testModeState == "Channel" then
                                self:UpdateTicks(234153, 0, 10)
                            end
                        end,
                    },
                    channelTicksColorReset = {
                        name = "重置",
                        type = "execute",
                        width = "half",
                        order = 12.3,
                        disabled = function() return not self.db.profile.showChannelTicks end,
                        func = function()
                            self.db.profile.channelTicksColor = { unpack(defaults.channelTicksColor) }
                            if self.db.profile.previewEnabled and self.db.profile.testModeState == "Channel" then
                                self:UpdateTicks(234153, 0, 10)
                            end
                        end,
                    },

                    headerChannelStyle = { name = "引導樣式", type = "header", order = 13 },
                    useChannelColor = {
                        name = "自訂引導顏色",
                        type = "toggle",
                        order = 13.1,
                        get = function(info) return self.db.profile.useChannelColor end,
                        set = function(info, val)
                            self.db.profile.useChannelColor = val; self:UpdateBarColor()
                        end,
                    },
                    channelColor = {
                        name = "引導顏色",
                        type = "color",
                        hasAlpha = true,
                        order = 13.2,
                        disabled = function() return not self.db.profile.useChannelColor end,
                        get = function(info)
                            local c = self.db.profile.channelColor; return c[1], c[2], c[3], c[4]
                        end,
                        set = function(info, r, g, b, a)
                            self.db.profile.channelColor = { r, g, b, a }; self:UpdateBarColor()
                        end,
                    },
                    channelColorReset = {
                        name = "重置",
                        type = "execute",
                        width = "half",
                        order = 13.25,
                        disabled = function() return not self.db.profile.useChannelColor end,
                        func = function()
                            self.db.profile.channelColor = { unpack(defaults.channelColor) }; self:UpdateBarColor()
                        end,
                    },
                    headerEmpower = { name = "蓄力法術（喚龍師）", type = "header", order = 20 },
                    empowerWidthScale = {
                        name = "縮放施法條寬度",
                        desc = "在蓄力階段增加施法條的水平長度。",
                        type = "toggle",
                        width = "full",
                        order = 20.1,
                        get = function(info) return self.db.profile.empowerWidthScale end,
                        set = function(info, val)
                            self.db.profile.empowerWidthScale = val; self:UpdateBarColor()
                        end,
                    },
                    empowerStage1Color = {
                        name = "階段 1",
                        type = "color",
                        hasAlpha = true,
                        order = 21,
                        get = function(info)
                            local c = self.db.profile.empowerStage1Color; return c[1], c[2], c[3], c[4]
                        end,
                        set = function(info, r, g, b, a) self.db.profile.empowerStage1Color = { r, g, b, a } end,
                    },
                    empowerStage1ColorReset = {
                        name = "重置",
                        type = "execute",
                        width = "half",
                        order = 21.1,
                        func = function()
                            self.db.profile.empowerStage1Color = { unpack(defaults.empowerStage1Color) }; self
                                :UpdateBarColor()
                        end,
                    },
                    empowerStage2Color = {
                        name = "階段 2",
                        type = "color",
                        hasAlpha = true,
                        order = 22,
                        get = function(info)
                            local c = self.db.profile.empowerStage2Color; return c[1], c[2], c[3], c[4]
                        end,
                        set = function(info, r, g, b, a) self.db.profile.empowerStage2Color = { r, g, b, a } end,
                    },
                    empowerStage2ColorReset = {
                        name = "重置",
                        type = "execute",
                        width = "half",
                        order = 22.1,
                        func = function()
                            self.db.profile.empowerStage2Color = { unpack(defaults.empowerStage2Color) }; self
                                :UpdateBarColor()
                        end,
                    },
                    empowerStage3Color = {
                        name = "階段 3",
                        type = "color",
                        hasAlpha = true,
                        order = 23,
                        get = function(info)
                            local c = self.db.profile.empowerStage3Color; return c[1], c[2], c[3], c[4]
                        end,
                        set = function(info, r, g, b, a) self.db.profile.empowerStage3Color = { r, g, b, a } end,
                    },
                    empowerStage3ColorReset = {
                        name = "重置",
                        type = "execute",
                        width = "half",
                        order = 23.1,
                        func = function()
                            self.db.profile.empowerStage3Color = { unpack(defaults.empowerStage3Color) }; self
                                :UpdateBarColor()
                        end,
                    },
                    empowerStage4Color = {
                        name = "階段 4",
                        type = "color",
                        hasAlpha = true,
                        order = 24,
                        get = function(info)
                            local c = self.db.profile.empowerStage4Color; return c[1], c[2], c[3], c[4]
                        end,
                        set = function(info, r, g, b, a) self.db.profile.empowerStage4Color = { r, g, b, a } end,
                    },
                    empowerStage4ColorReset = {
                        name = "重置",
                        type = "execute",
                        width = "half",
                        order = 24.1,
                        func = function()
                            self.db.profile.empowerStage4Color = { unpack(defaults.empowerStage4Color) }; self
                                :UpdateBarColor()
                        end,
                    },
                    empowerStage5Color = {
                        name = "階段 5",
                        type = "color",
                        hasAlpha = true,
                        order = 25,
                        get = function(info)
                            local c = self.db.profile.empowerStage5Color; return c[1], c[2], c[3], c[4]
                        end,
                        set = function(info, r, g, b, a) self.db.profile.empowerStage5Color = { r, g, b, a } end,
                    },
                    empowerStage5ColorReset = {
                        name = "重置",
                        type = "execute",
                        width = "half",
                        order = 25.1,
                        func = function()
                            self.db.profile.empowerStage5Color = { unpack(defaults.empowerStage5Color) }; self
                                :UpdateBarColor()
                        end,
                    },
                }
            },

            -- ==========================================================
            -- TAB 5: ANIMATION (Visual FX)
            -- ==========================================================
            animation = {
                name = "視覺特效",
                type = "group",
                order = 5,
                args = {
                    animStyle = {
                        name = "主要樣式",
                        type = "select",
                        order = 1,
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
                            if not self.db.profile.animationParams[val] then
                                self.db.profile.animationParams[val] = CopyTable(self.ANIMATION_STYLE_PARAMS[val])
                            end
                        end,
                    },
                    enableSpark = {
                        name = "啟用火花",
                        type = "toggle",
                        order = 2,
                        get = function(info) return self.db.profile.enableSpark end,
                        set = function(info, val) self.db.profile.enableSpark = val end,
                    },

                    -- GLOBAL FX SETTINGS
                    headerGlobalFX = { name = "全域光暈與偏移", type = "header", order = 5 },
                    glowColor = {
                        name = "全域光暈顏色",
                        type = "color",
                        hasAlpha = true,
                        order = 6,
                        get = function(info)
                            local c = self.db.profile.glowColor; return c[1], c[2], c[3], c[4]
                        end,
                        set = function(info, r, g, b, a)
                            self.db.profile.glowColor = { r, g, b, a }; self:UpdateSparkColors()
                        end,
                    },
                    glowColorReset = {
                        name = "重置",
                        type = "execute",
                        width = "half",
                        order = 6.1,
                        func = function()
                            self.db.profile.glowColor = { unpack(defaults.glowColor) }; self:UpdateSparkColors()
                        end,
                    },
                    glowIntensity = {
                        name = "光暈強度",
                        type = "range",
                        min = 0,
                        max = 5,
                        step = 0.1,
                        order = 7,
                        get = function(info) return self.db.profile.glowIntensity end,
                        set = function(info, val) self.db.profile.glowIntensity = val end,
                    },
                    headLengthOffset = {
                        name = "頭部偏移（全域）",
                        type = "range",
                        min = -100,
                        max = 100,
                        step = 1,
                        order = 8,
                        get = function(info) return self.db.profile.headLengthOffset end,
                        set = function(info, val) self.db.profile.headLengthOffset = val end,
                    },
                    tailOffset = {
                        name = "尾部偏移（全域）",
                        type = "range",
                        min = -100,
                        max = 100,
                        step = 1,
                        order = 9,
                        get = function(info) return self.db.profile.tailOffset end,
                        set = function(info, val) self.db.profile.tailOffset = val end,
                    },
                    tailLength = {
                        name = "尾部長度（全域）",
                        type = "range",
                        min = 10,
                        max = 500,
                        step = 1,
                        order = 9.5,
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
                    headerTails = { name = "火花與尾巴顏色", type = "header", order = 10 },
                    sparkColor = {
                        name = "火花頭部顏色",
                        type = "color",
                        hasAlpha = true,
                        order = 11,
                        get = function(info)
                            local c = self.db.profile.sparkColor; return c[1], c[2], c[3], c[4]
                        end,
                        set = function(info, r, g, b, a)
                            self.db.profile.sparkColor = { r, g, b, a }; self:UpdateSparkColors()
                        end,
                    },
                    sparkColorReset = {
                        name = "重置",
                        type = "execute",
                        width = "half",
                        order = 11.05,
                        func = function()
                            self.db.profile.sparkColor = { unpack(defaults.sparkColor) }; self:UpdateSparkColors()
                        end,
                    },
                    sparkIntensity = {
                        name = "火花強度",
                        type = "range",
                        min = 0,
                        max = 5,
                        step = 0.05,
                        order = 11.1,
                        get = function(info) return self.db.profile.sparkIntensity end,
                        set = function(info, val) self.db.profile.sparkIntensity = val end,
                    },
                    sparkScale = {
                        name = "火花縮放",
                        type = "range",
                        min = 0.5,
                        max = 3,
                        step = 0.1,
                        order = 11.2,
                        get = function(info) return self.db.profile.sparkScale end,
                        set = function(info, val)
                            self.db.profile.sparkScale = val; self:UpdateSparkSize()
                        end,
                    },
                    sparkOffset = {
                        name = "火花 X 偏移",
                        type = "range",
                        min = -100,
                        max = 100,
                        step = 0.1,
                        order = 11.3,
                        get = function(info) return self.db.profile.sparkOffset end,
                        set = function(info, val) self.db.profile.sparkOffset = val end,
                    },

                    enableTails = {
                        name = "啟用尾巴",
                        type = "toggle",
                        order = 12,
                        get = function(info) return self.db.profile.enableTails end,
                        set = function(info, val) self.db.profile.enableTails = val end,
                    },

                    -- Tails (Inline groups)
                    tail1Group = {
                        name = "尾巴 1（主要）",
                        type = "group",
                        inline = true,
                        order = 13,
                        args = {
                            color = {
                                name = "顏色",
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
                            colorReset = {
                                name = "重置",
                                type = "execute",
                                width = "half",
                                order = 1.1,
                                func = function()
                                    self.db.profile.tail1Color = { unpack(defaults.tail1Color) }; self:UpdateSparkColors()
                                end,
                            },
                            intensity = {
                                name = "強度",
                                type = "range",
                                min = 0,
                                max = 5,
                                step = 0.05,
                                order = 2,
                                get = function(info) return self.db.profile.tail1Intensity end,
                                set = function(info, val) self.db.profile.tail1Intensity = val end,
                            },
                            length = {
                                name = "長度",
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
                        name = "尾巴 2",
                        type = "group",
                        inline = true,
                        order = 14,
                        args = {
                            color = {
                                name = "顏色",
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
                            colorReset = {
                                name = "重置",
                                type = "execute",
                                width = "half",
                                order = 1.1,
                                func = function()
                                    self.db.profile.tail2Color = { unpack(defaults.tail2Color) }; self:UpdateSparkColors()
                                end,
                            },
                            intensity = {
                                name = "強度",
                                type = "range",
                                min = 0,
                                max = 5,
                                step = 0.05,
                                order = 2,
                                get = function(info) return self.db.profile.tail2Intensity end,
                                set = function(info, val) self.db.profile.tail2Intensity = val end,
                            },
                            length = {
                                name = "長度",
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
                        name = "尾巴 3",
                        type = "group",
                        inline = true,
                        order = 15,
                        args = {
                            color = {
                                name = "顏色",
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
                            colorReset = {
                                name = "重置",
                                type = "execute",
                                width = "half",
                                order = 1.1,
                                func = function()
                                    self.db.profile.tail3Color = { unpack(defaults.tail3Color) }; self:UpdateSparkColors()
                                end,
                            },
                            intensity = {
                                name = "強度",
                                type = "range",
                                min = 0,
                                max = 5,
                                step = 0.05,
                                order = 2,
                                get = function(info) return self.db.profile.tail3Intensity end,
                                set = function(info, val) self.db.profile.tail3Intensity = val end,
                            },
                            length = {
                                name = "長度",
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
                        name = "尾巴 4",
                        type = "group",
                        inline = true,
                        order = 16,
                        args = {
                            color = {
                                name = "顏色",
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
                            colorReset = {
                                name = "重置",
                                type = "execute",
                                width = "half",
                                order = 1.1,
                                func = function()
                                    self.db.profile.tail4Color = { unpack(defaults.tail4Color) }; self:UpdateSparkColors()
                                end,
                            },
                            intensity = {
                                name = "強度",
                                type = "range",
                                min = 0,
                                max = 5,
                                step = 0.05,
                                order = 2,
                                get = function(info) return self.db.profile.tail4Intensity end,
                                set = function(info, val) self.db.profile.tail4Intensity = val end,
                            },
                            length = {
                                name = "長度",
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

                    -- ADVANCED STYLE PARAMETERS
                    headerAdvanced = { name = "進階樣式設定", type = "header", order = 20 },
                    styleSpecificGroup = {
                        name = "微調動畫",
                        type = "group",
                        inline = true,
                        order = 21,
                        hidden = function()
                            local style = self.db.profile.animStyle
                            return style == "Comet" or not self.db.profile.animationParams[style]
                        end,
                        args = {
                            -- Orb Settings
                            orbRotationSpeed = {
                                name = "旋轉速度",
                                type = "range",
                                min = 1,
                                max = 20,
                                step = 1,
                                order = 1,
                                hidden = function() return self.db.profile.animStyle ~= "Orb" end,
                                get = function(info) return self.db.profile.animationParams["Orb"].rotationSpeed end,
                                set = function(info, val) self.db.profile.animationParams["Orb"].rotationSpeed = val end,
                            },
                            orbRadius = {
                                name = "球體半徑",
                                type = "range",
                                min = 0.1,
                                max = 1.0,
                                step = 0.1,
                                order = 2,
                                hidden = function() return self.db.profile.animStyle ~= "Orb" end,
                                get = function(info) return self.db.profile.animationParams["Orb"].radiusMultiplier end,
                                set = function(info, val) self.db.profile.animationParams["Orb"].radiusMultiplier = val end,
                            },
                            orbGlowPulse = {
                                name = "光暈脈動",
                                type = "range",
                                min = 0.1,
                                max = 2.0,
                                step = 0.1,
                                order = 3,
                                hidden = function() return self.db.profile.animStyle ~= "Orb" end,
                                get = function(info) return self.db.profile.animationParams["Orb"].glowPulse end,
                                set = function(info, val) self.db.profile.animationParams["Orb"].glowPulse = val end,
                            },
                            -- Pulse Settings
                            pulseMaxScale = {
                                name = "最大縮放",
                                type = "range",
                                min = 1.0,
                                max = 5.0,
                                step = 0.1,
                                order = 10,
                                hidden = function() return self.db.profile.animStyle ~= "Pulse" end,
                                get = function(info) return self.db.profile.animationParams["Pulse"].maxScale end,
                                set = function(info, val) self.db.profile.animationParams["Pulse"].maxScale = val end,
                            },
                            pulseRippleCycle = {
                                name = "漣漪週期",
                                type = "range",
                                min = 0.5,
                                max = 3.0,
                                step = 0.1,
                                order = 11,
                                hidden = function() return self.db.profile.animStyle ~= "Pulse" end,
                                get = function(info) return self.db.profile.animationParams["Pulse"].rippleCycle end,
                                set = function(info, val) self.db.profile.animationParams["Pulse"].rippleCycle = val end,
                            },
                            pulseFadeSpeed = { -- RESTORED: Was missing
                                name = "淡化速度",
                                type = "range",
                                min = 0.1,
                                max = 3.0,
                                step = 0.1,
                                order = 12,
                                hidden = function() return self.db.profile.animStyle ~= "Pulse" end,
                                get = function(info) return self.db.profile.animationParams["Pulse"].fadeSpeed end,
                                set = function(info, val) self.db.profile.animationParams["Pulse"].fadeSpeed = val end,
                            },
                            -- Starfall Settings
                            starfallFallSpeed = {
                                name = "下落速度",
                                type = "range",
                                min = 1.0,
                                max = 10.0,
                                step = 0.5,
                                order = 20,
                                hidden = function() return self.db.profile.animStyle ~= "Starfall" end,
                                get = function(info) return self.db.profile.animationParams["Starfall"].fallSpeed end,
                                set = function(info, val) self.db.profile.animationParams["Starfall"].fallSpeed = val end,
                            },
                            starfallSwayAmount = {
                                name = "擺動幅度",
                                type = "range",
                                min = 0,
                                max = 20,
                                step = 1,
                                order = 21,
                                hidden = function() return self.db.profile.animStyle ~= "Starfall" end,
                                get = function(info) return self.db.profile.animationParams["Starfall"].swayAmount end,
                                set = function(info, val) self.db.profile.animationParams["Starfall"].swayAmount = val end,
                            },
                            starfallParticleSpeed = { -- RESTORED: Was missing
                                name = "粒子速度",
                                type = "range",
                                min = 0.1,
                                max = 10.0,
                                step = 0.1,
                                order = 22,
                                hidden = function() return self.db.profile.animStyle ~= "Starfall" end,
                                get = function(info) return self.db.profile.animationParams["Starfall"].particleSpeed end,
                                set = function(info, val) self.db.profile.animationParams["Starfall"].particleSpeed = val end,
                            },
                            -- Flux Settings
                            fluxJitterY = {
                                name = "垂直抱動",
                                type = "range",
                                min = 1.0,
                                max = 10.0,
                                step = 0.5,
                                order = 30,
                                hidden = function() return self.db.profile.animStyle ~= "Flux" end,
                                get = function(info) return self.db.profile.animationParams["Flux"].jitterY end,
                                set = function(info, val) self.db.profile.animationParams["Flux"].jitterY = val end,
                            },
                            fluxJitterX = {
                                name = "水平抱動",
                                type = "range",
                                min = 1.0,
                                max = 10.0,
                                step = 0.5,
                                order = 31,
                                hidden = function() return self.db.profile.animStyle ~= "Flux" end,
                                get = function(info) return self.db.profile.animationParams["Flux"].jitterX end,
                                set = function(info, val) self.db.profile.animationParams["Flux"].jitterX = val end,
                            },
                            fluxDrift = { -- RESTORED: Was missing
                                name = "漂移速度",
                                type = "range",
                                min = 0,
                                max = 1,
                                step = 0.01,
                                order = 32,
                                hidden = function() return self.db.profile.animStyle ~= "Flux" end,
                                get = function(info) return self.db.profile.animationParams["Flux"].driftMultiplier end,
                                set = function(info, val) self.db.profile.animationParams["Flux"].driftMultiplier = val end,
                            },
                            -- Helix Settings
                            helixDriftMultiplier = {
                                name = "漂移乘數",
                                type = "range",
                                min = 0.01,
                                max = 0.3,
                                step = 0.01,
                                order = 40,
                                hidden = function() return self.db.profile.animStyle ~= "Helix" end,
                                get = function(info) return self.db.profile.animationParams["Helix"].driftMultiplier end,
                                set = function(info, val) self.db.profile.animationParams["Helix"].driftMultiplier = val end,
                            },
                            helixAmplitude = {
                                name = "波幅",
                                type = "range",
                                min = 0.1,
                                max = 1.0,
                                step = 0.1,
                                order = 41,
                                hidden = function() return self.db.profile.animStyle ~= "Helix" end,
                                get = function(info) return self.db.profile.animationParams["Helix"].amplitude end,
                                set = function(info, val) self.db.profile.animationParams["Helix"].amplitude = val end,
                            },
                            helixWaveSpeed = {
                                name = "波速",
                                type = "range",
                                min = 1,
                                max = 20,
                                step = 1,
                                order = 42,
                                hidden = function() return self.db.profile.animStyle ~= "Helix" end,
                                get = function(info) return self.db.profile.animationParams["Helix"].waveSpeed end,
                                set = function(info, val) self.db.profile.animationParams["Helix"].waveSpeed = val end,
                            },
                            -- Wave Settings
                            waveCount = {
                                name = "波數",
                                type = "range",
                                min = 1,
                                max = 10,
                                step = 1,
                                order = 50,
                                hidden = function() return self.db.profile.animStyle ~= "Wave" end,
                                get = function(info) return self.db.profile.animationParams["Wave"].waveCount end,
                                set = function(info, val) self.db.profile.animationParams["Wave"].waveCount = val end,
                            },
                            waveSpeed = {
                                name = "波速",
                                type = "range",
                                min = 0.1,
                                max = 2.0,
                                step = 0.1,
                                order = 51,
                                hidden = function() return self.db.profile.animStyle ~= "Wave" end,
                                get = function(info) return self.db.profile.animationParams["Wave"].waveSpeed end,
                                set = function(info, val) self.db.profile.animationParams["Wave"].waveSpeed = val end,
                            },
                            waveAmplitude = {
                                name = "振幅",
                                type = "range",
                                min = 0.01,
                                max = 0.2,
                                step = 0.01,
                                order = 52,
                                hidden = function() return self.db.profile.animStyle ~= "Wave" end,
                                get = function(info) return self.db.profile.animationParams["Wave"].amplitude end,
                                set = function(info, val) self.db.profile.animationParams["Wave"].amplitude = val end,
                            },
                            waveWidth = {
                                name = "寬度",
                                type = "range",
                                min = 0.1,
                                max = 0.5,
                                step = 0.05,
                                order = 53,
                                hidden = function() return self.db.profile.animStyle ~= "Wave" end,
                                get = function(info) return self.db.profile.animationParams["Wave"].waveWidth end,
                                set = function(info, val) self.db.profile.animationParams["Wave"].waveWidth = val end,
                            },
                            -- Glitch Settings
                            glitchChance = {
                                name = "故障強度",
                                type = "range",
                                min = 0.01,
                                max = 0.5,
                                step = 0.01,
                                order = 70,
                                hidden = function() return self.db.profile.animStyle ~= "Glitch" end,
                                get = function(info) return self.db.profile.animationParams["Glitch"].glitchChance end,
                                set = function(info, val) self.db.profile.animationParams["Glitch"].glitchChance = val end,
                            },
                            glitchMaxOffset = {
                                name = "最大故障偏移",
                                type = "range",
                                min = 1,
                                max = 20,
                                step = 1,
                                order = 71,
                                hidden = function() return self.db.profile.animStyle ~= "Glitch" end,
                                get = function(info) return self.db.profile.animationParams["Glitch"].maxOffset end,
                                set = function(info, val) self.db.profile.animationParams["Glitch"].maxOffset = val end,
                            },
                            glitchColorIntensity = {
                                name = "顏色強度",
                                type = "range",
                                min = 0,
                                max = 1,
                                step = 0.05,
                                order = 72,
                                hidden = function() return self.db.profile.animStyle ~= "Glitch" end,
                                get = function(info) return self.db.profile.animationParams["Glitch"].colorIntensity end,
                                set = function(info, val) self.db.profile.animationParams["Glitch"].colorIntensity = val end,
                            },
                            -- Lightning Settings
                            lightningChance = {
                                name = "頻率",
                                type = "range",
                                min = 0.1,
                                max = 1.0,
                                step = 0.1,
                                order = 80,
                                hidden = function() return self.db.profile.animStyle ~= "Lightning" end,
                                get = function(info) return self.db.profile.animationParams["Lightning"].lightningChance end,
                                set = function(info, val)
                                    self.db.profile.animationParams["Lightning"].lightningChance =
                                        val
                                end,
                            },
                            lightningSegmentCount = {
                                name = "分段數",
                                type = "range",
                                min = 1,
                                max = 10,
                                step = 1,
                                order = 81,
                                hidden = function() return self.db.profile.animStyle ~= "Lightning" end,
                                get = function(info) return self.db.profile.animationParams["Lightning"].segmentCount end,
                                set = function(info, val) self.db.profile.animationParams["Lightning"].segmentCount = val end,
                            },
                        }
                    },
                    resetStyleSettings = {
                        name = "重置動畫預設值",
                        type = "execute",
                        width = "full",
                        order = 100,
                        func = function()
                            local currentStyle = self.db.profile.animStyle
                            if currentStyle and defaults.animationParams[currentStyle] then
                                self.db.profile.animationParams[currentStyle] = CopyTable(defaults.animationParams
                                    [currentStyle])
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
