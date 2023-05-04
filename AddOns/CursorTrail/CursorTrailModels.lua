--[[---------------------------------------------------------------------------
    Addon:  CursorTrail
    File:   CursorTrailModels.lua
    Desc:   This file contains a list of models used by this addon for Retail WoW.
-----------------------------------------------------------------------------]]

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Aliases to Globals                                ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

local Globals = _G
local _  -- Prevent tainting global _ .
local pairs = _G.pairs
local print = _G.print
local table = _G.table
local tonumber = _G.tonumber

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Declare Namespace                                 ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

local CursorTrail = _G.CursorTrail or {}
if (not _G.CursorTrail) then _G.CursorTrail = CursorTrail end

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Remap Global Environment                          ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

setfenv(1, _G.CursorTrail)  -- Everything after this uses our namespace rather than _G.

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Constants                                         ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- Model Constants:
kBaseMult = 0.0001  -- A mulitplier applied to base values to reduce the # of decimal positions needed.
kCategory = {
    Glow    = "Glow - ",    -- Effects that do not have any motion trail.
    Object  = "Object - ",  -- Effects that are shapes or images, and have no motion trail.
    Spots   = "Spots - ",   -- Effects that have an intermittent motion trail.
    Trail   = "Trail - ",   -- Effects that have a continuous motion trail.
}
kModelConstants = 
{
    -- NOTES:
    --   [] To increase the range of motion across the screen, decrease BaseStepX and/or BaseStepY.
    --      To decrease  "    "   "    "      "     "    "     increase    "         "      "     .
    --   [] To find a model's ID, go to "https://wow.tools/files" and search for the model's 
    --      file name (excluding the path).  Choose M2 file types, not MDX.
    
    [0] = {  -- "None.  (Don't show a model effect.)"
        Name = kStr_None,
        BaseScale = 1.0, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = 0,
        BaseStepX = 0, BaseStepY = 0,
        IsSkewed = false, HorizontalSlope = 0,
    },
    
    --~~~~~~~~~~~~~~~~~~~~~~~~
    --[[       Glows        ]]
    --~~~~~~~~~~~~~~~~~~~~~~~~

    [166538] = {  -- "spells/manafunnel_impact_chest.m2"
        Name = kCategory.Glow .. "Burning Cloud, Blue",
        BaseScale = 0.05, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = 0,
        BaseStepX = 3430, BaseStepY = 3156,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [166471] = {  -- "spells/lifetap_state_chest.m2"
        Name = kCategory.Glow .. "Burning Cloud, Green",
        BaseScale = 0.05, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = -0.01,
        BaseStepX = 3428, BaseStepY = 3146,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [166923] = {  -- "spells/soulfunnel_impact_chest.m2"
        Name = kCategory.Glow .. "Burning Cloud, Purple",
        BaseScale = 0.055, BaseFacing = 0,
        BaseOfsX = 0.46, BaseOfsY = 0.035,
        BaseStepX = 3430, BaseStepY = 3150,
        IsSkewed = true, HorizontalSlope = 4,
    },
    [166028] = {  -- "spells/enchantments/spellsurgeglow_high.m2"
        Name = kCategory.Glow .. "Cloud, Blue",
        BaseScale = 0.23, BaseFacing = 0,
        BaseOfsX = 0.22, BaseOfsY = 0.35,
        BaseStepX = 3430, BaseStepY = 3160,
        IsSkewed = true, HorizontalSlope = 0, 
    },
    [165728] = {  -- "spells/bloodlust_state_hand.m2"
        Name = kCategory.Glow .. "雲朵, 火焰",
        BaseScale = 0.09, BaseFacing = 0,
        BaseOfsX = 0.05, BaseOfsY = 0.15,
        BaseStepX = 3440, BaseStepY = 3170,
        IsSkewed = true, HorizontalSlope = 0, 
    },
    [166255] = {  -- "spells/gouge_precast_state_hand.m2"
        Name = kCategory.Glow .. "雲朵, 紫",
        BaseScale = 0.11, BaseFacing = 0,
        BaseOfsX = 0.025, BaseOfsY = -0.025,
        BaseStepX = 3430, BaseStepY = 3150,
        IsSkewed = true, HorizontalSlope = 0, 
    },
    [166991] = {  -- "spells/summon_precast_hand.m2"
        Name = kCategory.Glow .. "雲朵, 紫 (柔軟)",
        BaseScale = 0.18, BaseFacing = 0,
        BaseOfsX = 0.075, BaseOfsY = -0.15,
        BaseStepX = 3428, BaseStepY = 3150,
        IsSkewed = true, HorizontalSlope = 0, 
    },

    --~~~~~~~~~~~~~~~~~~~~~~~
    --[[     Objects       ]]
    --~~~~~~~~~~~~~~~~~~~~~~~
    
    [165778] = {  -- "spells/catmark.m2"
        Name = kCategory.Object .. "貓咪痕跡, 紫",
        BaseScale = 0.06, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = 8.2,
        BaseStepX = 3590, BaseStepY = 3600,
        IsSkewed = true, HorizontalSlope = 0, 
        SkewTopMult = 0.995, SkewBottomMult = 1.05,  -- Has different side skewing.
    },
    [343980] = {  -- "spells/catmark_green.m2"
        Name = kCategory.Object .. "貓咪痕跡, 綠",
        BaseScale = 0.06, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = 8.2,
        BaseStepX = 3590, BaseStepY = 3600,
        IsSkewed = true, HorizontalSlope = 0, 
        SkewTopMult = 0.995, SkewBottomMult = 1.05,  -- Has different side skewing.
    },
    [343983] = {  -- "spells/catmark_white.m2"
        Name = kCategory.Object .. "貓咪痕跡, 白",
        BaseScale = 0.06, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = 8.2,
        BaseStepX = 3590, BaseStepY = 3600,
        IsSkewed = true, HorizontalSlope = 0, 
        SkewTopMult = 0.995, SkewBottomMult = 1.05,  -- Has different side skewing.
    },
    [165751] = {  -- "spells/bonearmor_state_chest.m2"
        Name = kCategory.Object .. "骨頭之環",
        BaseScale = 0.05, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = -1.15,
        BaseStepX = 3380, BaseStepY = 3080,
        IsSkewed = true, HorizontalSlope = 0, 
    },
    
    --~~~~~~~~~~~~~~~~~~~~~~~~
    --[[   Spotty Trails    ]]
    --~~~~~~~~~~~~~~~~~~~~~~~~
    
    [240855] = {  -- "spells/demolisher_missile.m2"
        Name = kCategory.Spots .. "火",
        BaseScale = 0.04, BaseFacing = 0,
        BaseOfsX = -0.15, BaseOfsY = 0.72,
        BaseStepX = 3454, BaseStepY = 3200,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [1617293] = { -- "spells/7fx_kiljaeden_focuseddreadflame_precast.m2"
        Name = kCategory.Spots .. "火球",
        BaseScale = 0.09, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = 0,
        BaseStepX = 3300, BaseStepY = 3140,
        IsSkewed = true, HorizontalSlope = 0,
        SkewTopMult = 0.95, SkewBottomMult = 1.06,
    },
    [166381] = {  -- "spells/ice_precast_low_hand.m2"
        Name = kCategory.Spots .. "冰",
        BaseScale = 0.12, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = 0,
        BaseStepX = 3430, BaseStepY = 3150,
        IsSkewed = true, HorizontalSlope = 0, 
    },
    [240902] = {  -- "spells/forsakencatapult_missile.m2"
        Name = kCategory.Spots .. "瘟疫雲",
        BaseScale = 0.06, BaseFacing = 0,
        BaseOfsX = -0.45, BaseOfsY = -0.35,
        BaseStepX = 3420, BaseStepY = 3130,
        IsSkewed = true, HorizontalSlope = -3, 
    },
    [347886] = {  -- "spells/goo_flow_statepurple.m2"
        Name = kCategory.Spots .. "污水, 紫",
        BaseScale = 0.003, BaseFacing = 0,
        BaseOfsX = -0.25, BaseOfsY = 3.875,
        BaseStepX = 3513, BaseStepY = 3363,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [166339] = {  -- "spells/holy_precast_uber_hand.m2"
        Name = kCategory.Spots .. "脈動, 聖光",
        BaseScale = 0.11, BaseFacing = 0,
        BaseOfsX = 0.061, BaseOfsY = -0.035,
        BaseStepX = 3430, BaseStepY = 3155,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [165956] = {  -- "spells/dispel_low_recursive.m2"
        Name = kCategory.Spots .. "火花, 黃",
        BaseScale = 0.6, BaseFacing = 0,
        BaseOfsX = -0.015, BaseOfsY = -0.025,
        BaseStepX = 3430, BaseStepY = 3160,
        IsSkewed = true, HorizontalSlope = 0, 
    },
    [165943] = {  -- "spells/detectmagic_recursive.m2"
        Name = kCategory.Spots .. "火花, 藍",
        BaseScale = 0.65, BaseFacing = 0,
        BaseOfsX = -0.01, BaseOfsY = -0.025,
        BaseStepX = 3430, BaseStepY = 3160,
        IsSkewed = true, HorizontalSlope = 0, 
    },

--~     [530075] = {  -- "infinite_timebomb_reticule.m2"
--~         Name = kCategory.Spots .. "Circle",
--~         BaseScale = 0.004, BaseFacing = TODO,
--~         BaseOfsX = 0, BaseOfsY = 1.75,
--~         BaseStepX = 3350, BaseStepY = 3100,
--~         IsSkewed = true, HorizontalSlope = 0, 
--~     },    
--~     [1685852] = {  -- "cfx_warlock_demonboltfel_missle.m2"
--~         Name = kCategory.Spots .. "Swirling, Purple & Green",
--~         BaseScale = 0.025, BaseFacing = 0,
--~         BaseOfsX = 0.0, BaseOfsY = -0.1,
--~         BaseStepX = 3408, BaseStepY = 3150,
--~         IsSkewed = true, HorizontalSlope = 0, 
--~     },
    
    [975870] = {  -- "cfx_warlock_demonbolt_missle01.m2"
        Name = kCategory.Spots .. "旋流, 紫 & 橘",
        BaseScale = 0.025, BaseFacing = 0,
        BaseOfsX = 0.0, BaseOfsY = 1.35,
        BaseStepX = 3458, BaseStepY = 3240,
        IsSkewed = true, HorizontalSlope = 0, 
    },
    
    --~~~~~~~~~~~~~~~~~~~~~~~~~
    --[[  Continuous Trails  ]]
    --~~~~~~~~~~~~~~~~~~~~~~~~~
    
    [166498] = {  -- "spells/lightningboltivus_missile.m2"    ****** DEFAULT ******
        Name = kCategory.Trail .. "電子, 藍 (長)",
        BaseScale = 0.06, BaseFacing = 0,
        BaseOfsX = 0.1, BaseOfsY = 0.15,
        BaseStepX = 472, BaseStepY = 472,  -- To increase range, decrease #s.  To decrease range, increase #s.
        IsSkewed = false, HorizontalSlope = 0,
    },
    [166492] = {  -- "spells/lightning_precast_low_hand.m2"
        Name = kCategory.Trail .. "電子, 藍",
        BaseScale = 0.1, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = 0,
        BaseStepX = 3430, BaseStepY = 3155,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [166491] = {  -- "spells/lightning_fel_precast_low_hand.m2"
        Name = kCategory.Trail .. "電子, 綠",
        BaseScale = 0.11, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = 0,
        BaseStepX = 3430, BaseStepY = 3155,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [167214] = {  -- "spells/wrath_precast_hand.m2"
        Name = kCategory.Trail .. "電子, 綠色脈衝",
        BaseScale = 0.08, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = 0,
        BaseStepX = 3430, BaseStepY = 3155,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [165693] = {  -- "spells/blessingoffreedom_state.m2"
        Name = kCategory.Trail .. "自由",
        BaseScale = 0.022, BaseFacing = 0,
        BaseOfsX = 0.12, BaseOfsY = 7.7,
        BaseStepX = 3570, BaseStepY = 3563,
        IsSkewed = true, HorizontalSlope = 0,
        SkewTopMult = 0.995, SkewBottomMult = 1.05,  -- Has different side skewing.
    },
    [167229] = {  -- "spells/zig_missile.m2"
        Name = kCategory.Trail .. "鬼魂",
        BaseScale = 0.02, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = 0,
        BaseStepX = 3430, BaseStepY = 3155,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [165648] = {  -- "spells/banish_chest.m2"
        Name = kCategory.Trail .. "脈動, 綠",
        BaseScale = 0.03, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = -1.875,
        BaseStepX = 3380, BaseStepY = 3060,
        IsSkewed = true, HorizontalSlope = 0,
        SkewTopMult = 0.98, SkewBottomMult = 1.115,  -- Has different side skewing.
    },
    [165653] = {  -- "spells/banish_chest_yellow.m2"
        Name = kCategory.Trail .. "脈動, 黃",
        BaseScale = 0.02, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = -1.875,
        BaseStepX = 3380, BaseStepY = 3050,
        IsSkewed = true, HorizontalSlope = 0,
        SkewTopMult = 0.98, SkewBottomMult = 1.115,  -- Has different side skewing.
    },
    [166926] = {  -- "spells/soulshatter_missile.m2"
        Name = kCategory.Trail .. "靈魂頭骨",
        BaseScale = 0.14, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = 0,
        BaseStepX = 3430, BaseStepY = 3155,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [166426] = {  -- "spells/intervenetrail.m2"
        Name = kCategory.Trail .. "閃耀, 藍",
        BaseScale = 0.08, BaseFacing = 0,
        BaseOfsX = 0.1, BaseOfsY = 0.5,
        BaseStepX = 3460, BaseStepY = 3200,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [166952] = {  -- "spells/sprint_impact_chest.m2"
        Name = kCategory.Trail .. "閃耀, 綠",
        BaseScale = 0.08, BaseFacing = 0,
        BaseOfsX = 0.05, BaseOfsY = -0.2,
        BaseStepX = 3440, BaseStepY = 3140,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [1417024] = {  -- "spells/ribbontrail_rainbow.m2"
        Name = kCategory.Trail .. "閃耀, 彩虹",
        BaseScale = 0.08, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = -0.175,
        BaseStepX = 3430, BaseStepY = 3150,
        IsSkewed = true, HorizontalSlope = 0,
    },    
    [165784] = {  -- "spells/chargetrail.m2"
        Name = kCategory.Trail .. "閃耀, 紅",
        BaseScale = 0.05, BaseFacing = 0,
        BaseOfsX = 0.04, BaseOfsY = -0.18,
        BaseStepX = 3419, BaseStepY = 3140,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [166731] = {  -- "spells/ribbontrail.m2"
        Name = kCategory.Trail .. "閃耀, 白",
        BaseScale = 0.09, BaseFacing = 0,
        BaseOfsX = 0.05, BaseOfsY = -0.25,
        BaseStepX = 3420, BaseStepY = 3140,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [166694] = {  -- "spells/rejuvenation_impact_base.m2"
        Name = kCategory.Trail .. "旋流, 自然",
        BaseScale = 0.022, BaseFacing = 0,
        BaseOfsX = -1.3, BaseOfsY = 8.075,
        BaseStepX = 3550, BaseStepY = 3600,
        IsSkewed = true, HorizontalSlope = -8,
        SkewTopMult = 0.995, SkewBottomMult = 1.05,  -- Has different side skewing.
    },
    [240896] = {  -- "spells/firebomb_missle.m2"
        Name = kCategory.Trail .. "旋流, 橘",
        BaseScale = 0.01, BaseFacing = 0,
        BaseOfsX = 0.007, BaseOfsY = 0.109,
        BaseStepX = 3432, BaseStepY = 3155,
        IsSkewed = true, HorizontalSlope = 0, 
    },
    [1536474] = {  -- "cfx_monk_chiorbit_missile.m2"
        Name = kCategory.Trail .. "雲朵, 藍 & 綠",
        BaseScale = 0.1, BaseFacing = 0,
        BaseOfsX = 0.15, BaseOfsY = 0.10,
        BaseStepX = 3420, BaseStepY = 3156,
        IsSkewed = true, HorizontalSlope = 0,
    },
    
    --~~~~~~~~~~~~~~~~~~~~~~~~
    --[[      Unused        ]]
    --~~~~~~~~~~~~~~~~~~~~~~~~

--~     [166026] = {  -- "spells/enchantments/soulfrostglow_high.m2"
--~         Name = kCategory.Glow .. "Cloud, Black & Blue",
--~         BaseScale = 0.17, BaseFacing = 0,
--~         BaseOfsX = -0.08, BaseOfsY = -0.15,
--~         BaseStepX = 3430, BaseStepY = 3160,
--~         IsSkewed = true, HorizontalSlope = 0, 
--~     },
--~ TODO    [166784] = {  -- "spells/seedofcorruption_state.m2"
--~         Name = kCategory.Glow .. "zzzCloud, Corruption",
--~         BaseScale = 0.05, BaseFacing = 0,
--~         BaseOfsX = 0, BaseOfsY = 0,
--~         BaseStepX = 3330, BaseStepY = 3330,
--~         IsSkewed = true, HorizontalSlope = 0, 
--~     },
--~ TODO    [166000] = {  -- "spells/enchantments/disintigrateglow_high.m2"
--~         Name = kCategory.Glow .. "zzzCloud, Executioner",
--~         BaseScale = 0.1, BaseFacing = 0,
--~         BaseOfsX = 0, BaseOfsY = 0,
--~         BaseStepX = 3330, BaseStepY = 3330,
--~         IsSkewed = true, HorizontalSlope = 0, 
--~     },
--~     [166029] = {  -- "spells/enchantments/sunfireglow_high.m2"
--~         Name = kCategory.Glow .. "Cloud, Fire",
--~         BaseScale = 0.18, BaseFacing = 0,
--~         BaseOfsX = 0.35, BaseOfsY = -0.025,
--~         BaseStepX = 3420, BaseStepY = 3150,
--~         IsSkewed = true, HorizontalSlope = 0, 
--~     },
--~ TODO    [166396] = {  -- "spells/icyenchant_high.m2"
--~         Name = kCategory.Glow .. "zzzCloud, Frost",
--~         BaseScale = 0.05, BaseFacing = 0,
--~         BaseOfsX = 0, BaseOfsY = 0,
--~         BaseStepX = 3330, BaseStepY = 3330,
--~         IsSkewed = true, HorizontalSlope = 0, 
--~     },
--~     [166334] = {  -- "spells/holy_precast_high_base.m2"
--~         Name = kCategory.Glow .. "zzzRing, Holy",
--~         BaseScale = 0.05, BaseFacing = 0,
--~         BaseOfsX = 0, BaseOfsY = 0,
--~         BaseStepX = 3330, BaseStepY = 3330,
--~         IsSkewed = true, HorizontalSlope = 0, 
--~     },
--~     [165759] = {  -- "spells/brillianceaura.m2"
--~         Name = kCategory.Glow .. "zzzRing, Pulsing, Blue",
--~         BaseScale = 0.05, BaseFacing = 0,
--~         BaseOfsX = 0, BaseOfsY = 0,
--~         BaseStepX = 3330, BaseStepY = 3330,
--~         IsSkewed = true, HorizontalSlope = 0, 
--~     },
--~     [166379] = {  -- "spells/ice_precast_high_hand.m2"
--~         Name = kCategory.Glow .. "zzzRing, Frost",
--~         BaseScale = 0.05, BaseFacing = 0,
--~         BaseOfsX = 0, BaseOfsY = 0,
--~         BaseStepX = 3330, BaseStepY = 3330,
--~         IsSkewed = true, HorizontalSlope = 0, 
--~     },
--~     [167152] = {  -- "spells/vengeance_state_hand.m2"
--~         Name = kCategory.Glow .. "zzzRing, Vengeance",
--~         BaseScale = 0.05, BaseFacing = 0,
--~         BaseOfsX = 0, BaseOfsY = 0,
--~         BaseStepX = 3330, BaseStepY = 3330,
--~         IsSkewed = true, HorizontalSlope = 0, 
--~     },
--~     [166822] = {  -- "spells/shadowmissile.m2"
--~         Name = kCategory.Glow .. "zzzSimple, Black",
--~         BaseScale = 0.05, BaseFacing = 0,
--~         BaseOfsX = 0, BaseOfsY = 0,
--~         BaseStepX = 3330, BaseStepY = 3330,
--~         IsSkewed = true, HorizontalSlope = 0, 
--~     },
--~     [166604] = {  -- "spells/nature_precast_chest.m2"
--~         Name = kCategory.Glow .. "zzzSimple, Green",
--~         BaseScale = 0.05, BaseFacing = 0,
--~         BaseOfsX = 0, BaseOfsY = 0,
--~         BaseStepX = 3330, BaseStepY = 3330,
--~         IsSkewed = true, HorizontalSlope = 0, 
--~     },
--~     [166030] = {  -- "spells/enchantments/whiteflame_low.m2"
--~         Name = kCategory.Glow .. "zzzSimple, White",
--~         BaseScale = 0.05, BaseFacing = 0,
--~         BaseOfsX = 0, BaseOfsY = 0,
--~         BaseStepX = 3330, BaseStepY = 3330,
--~         IsSkewed = true, HorizontalSlope = 0, 
--~     },
--~     [166248] = {  -- "spells/goblin_weather_machine_lightning.m2"
--~         Name = kCategory.Glow .. "zzzWeather, Lightning",
--~         BaseScale = 0.05, BaseFacing = 0,
--~         BaseOfsX = 0, BaseOfsY = 0,
--~         BaseStepX = 3330, BaseStepY = 3330,
--~         IsSkewed = true, HorizontalSlope = 0, 
--~     },
--~     [166251] = {  -- "spells/goblin_weather_machine_sunny.m2"
--~         Name = kCategory.Glow .. "zzzWeather, Sun",
--~         BaseScale = 0.05, BaseFacing = 0,
--~         BaseOfsX = 0, BaseOfsY = 0,
--~         BaseStepX = 3330, BaseStepY = 3330,
--~         IsSkewed = true, HorizontalSlope = 0, 
--~     },
--~     [166250] = {  -- "spells/goblin_weather_machine_snow.m2"
--~         Name = kCategory.Glow .. "zzzWeather, Snow",
--~         BaseScale = 0.05, BaseFacing = 0,
--~         BaseOfsX = 0, BaseOfsY = 0,
--~         BaseStepX = 3330, BaseStepY = 3330,
--~         IsSkewed = true, HorizontalSlope = 0, 
--~     },
--~     [166247] = {  -- "spells/goblin_weather_machine_cloudy.m2"
--~         Name = kCategory.Glow .. "zzzWeather, Cloudy",
--~         BaseScale = 0.05, BaseFacing = 0,
--~         BaseOfsX = 0, BaseOfsY = 0,
--~         BaseStepX = 3330, BaseStepY = 3330,
--~         IsSkewed = true, HorizontalSlope = 0, 
--~     },
--~     [165568] = {  -- "spells/arcane_form_precast.m2"
--~         Name = kCategory.Spots .. "Dust, Arcane",
--~         BaseScale = 0.045, BaseFacing = 0.7,
--~         BaseOfsX = 0, BaseOfsY = 6.7,
--~         BaseStepX = 2975, BaseStepY = 3000,
--~         IsSkewed = false, HorizontalSlope = 0,
--~     },
--~     [166112] = {  -- "spells/fire_form_precast.m2"
--~         Name = kCategory.Spots .. "Dust, Embers",
--~         BaseScale = 0.05, BaseFacing = 0.7,
--~         BaseOfsX = 1.275, BaseOfsY = 8.15,
--~         BaseStepX = 3580, BaseStepY = 3470,
--~         IsSkewed = true, HorizontalSlope = 0, 
--~         SkewTopMult = 0.995, SkewBottomMult = 1.05,  -- Has different side skewing.
--~     },
--~     [166322] = {  -- "spells/holy_form_precast.m2"
--~         Name = kCategory.Spots .. "Dust, Holy",
--~         BaseScale = 0.05, BaseFacing = 0.7,
--~         BaseOfsX = 0.15, BaseOfsY = 8.05,
--~         BaseStepX = 3580, BaseStepY = 3500,
--~         IsSkewed = true, HorizontalSlope = 0, 
--~         SkewTopMult = 0.995, SkewBottomMult = 1.05,  -- Has different side skewing.
--~     },
--~     [166209] = {  -- "spells/frost_form_precast.m2"
--~         Name = kCategory.Spots .. "Dust, Ice Shards",
--~         BaseScale = 0.05, BaseFacing = 0.7,
--~         BaseOfsX = -0.25, BaseOfsY = 7.4,
--~         BaseStepX = 3590, BaseStepY = 3500,
--~         IsSkewed = true, HorizontalSlope = 0, 
--~         SkewTopMult = 0.995, SkewBottomMult = 1.05,  -- Has different side skewing.
--~     },
--~     [166792] = {  -- "spells/shadow_form_precast.m2"
--~         Name = kCategory.Spots .. "Dust, Shadow",
--~         BaseScale = 0.05, BaseFacing = 0.7,
--~         BaseOfsX = 0.35, BaseOfsY = 7.15,
--~         BaseStepX = 3590, BaseStepY = 3500,
--~         IsSkewed = true, HorizontalSlope = 0, 
--~         SkewTopMult = 0.995, SkewBottomMult = 1.05,  -- Has different side skewing.
--~     },
--~ NOTHING SEEN.
--~     [166109] = {  -- "spells/fire_blue_precast_uber_hand.m2"
--~         Name = kCategory.Spots .. "zzzFire, Blue",
--~         BaseScale = 0.9, BaseFacing = 0,
--~         BaseOfsX = 0, BaseOfsY = 0,
--~         BaseStepX = 3330, BaseStepY = 3330,
--~         IsSkewed = false, HorizontalSlope = 0, 
--~     },
--~ VERY JUMPY (SLUGGISH).
--~     [166071] = {  -- "spells/fel_fire_precast_hand.m2"
--~         Name = kCategory.Spots .. "Fire, Fel",
--~         BaseScale = 0.1, BaseFacing = 0,
--~         BaseOfsX = -1.25, BaseOfsY = 0.425,
--~         BaseStepX = 3420, BaseStepY = 3200,
--~         IsSkewed = true, HorizontalSlope = -12, 
--~     },
--~ VERY JUMPY (SLUGGISH).
--~     [166073] = {  -- "spells/fire_precast_uber_hand.m2"
--~         Name = kCategory.Spots .. "zzzFire, Light Green",
--~         BaseScale = 0.1, BaseFacing = 0,
--~         BaseOfsX = -1.375, BaseOfsY = -0.625,
--~         BaseStepX = 3410, BaseStepY = 3130,
--~         IsSkewed = true, HorizontalSlope = -12, 
--~     },
--~ NOTHING SEEN.
--~     [166405] = {  -- "spells/incinerate_impact_base.m2"
--~         Name = kCategory.Spots .. "zzzFire, Periodic Red & Blue",
--~         BaseScale = 0.05, BaseFacing = 0,
--~         BaseOfsX = 0, BaseOfsY = 0,
--~         BaseStepX = 3330, BaseStepY = 3330,
--~         IsSkewed = true, HorizontalSlope = 0, 
--~     },
--~ NOTHING SEEN.
--~     [166409] = {  -- "spells/incinerateblue_low_base.m2"
--~         Name = kCategory.Spots .. "zzzFire, Wavy Purple",
--~         BaseScale = 0.5, BaseFacing = 2.3,
--~         BaseOfsX = 0, BaseOfsY = 0,
--~         BaseStepX = 3330, BaseStepY = 3330,
--~         IsSkewed = true, HorizontalSlope = 0, 
--~     },
--~ NOTHING SEEN.
--~     [165839] = {  -- "spells/cripple_state_chest.m2"
--~         Name = kCategory.Spots .. "zzzShadow Cloud",
--~         BaseScale = 0.05, BaseFacing = 0,
--~         BaseOfsX = 0, BaseOfsY = 0,
--~         BaseStepX = 3330, BaseStepY = 3330,
--~         IsSkewed = true, HorizontalSlope = 0, 
--~     },
--~ NOTHING SEEN.
--~     [166468] = {  -- "spells/lifebloom_state.m2"
--~         Name = kCategory.Spots .. "zzzSparks, Periodic Healing",
--~         BaseScale = 0.05, BaseFacing = 0,
--~         BaseOfsX = 0, BaseOfsY = 0,
--~         BaseStepX = 3330, BaseStepY = 3330,
--~         IsSkewed = true, HorizontalSlope = 0, 
--~     },
--~ NOTHING SEEN.
--~     [166404] = {  -- "spells/immolationtrap_recursive.m2"
--~         Name = kCategory.Spots .. "zzzSparks, Red",
--~         BaseScale = 0.05, BaseFacing = 0,
--~         BaseOfsX = 0, BaseOfsY = 0,
--~         BaseStepX = 3330, BaseStepY = 3330,
--~         IsSkewed = true, HorizontalSlope = 0, 
--~     },
--~     [166173] = {  -- "spells/firstaid_hand.m2"
--~         Name = kCategory.Trail .. "First Aid",
--~         BaseScale = 0.1, BaseFacing = 0,
--~         BaseOfsX = 0.035, BaseOfsY = -0.025,
--~         BaseStepX = 3430, BaseStepY = 3155,
--~         IsSkewed = true, HorizontalSlope = 0,
--~     },
--~     [166811] = {  -- "spells/shadow_precast_uber_hand.m2"
--~         Name = kCategory.Trail .. "Shadow",
--~         BaseScale = 0.09, BaseFacing = 0,
--~         BaseOfsX = -0.65, BaseOfsY = 0.5,
--~         BaseStepX = 3430, BaseStepY = 3185,
--~         IsSkewed = true, HorizontalSlope = 0,
--~     },
--~     [166797] = {  -- "spells/shadow_impactdd_med_base.m2"
--~         Name = kCategory.Trail .. "Swirling, Black",
--~         BaseScale = 0.04, BaseFacing = 0,
--~         BaseOfsX = 0, BaseOfsY = -0.2,
--~         BaseStepX = 3440, BaseStepY = 3185,
--~         IsSkewed = true, HorizontalSlope = 0,
--~     },
--~     [165723] = {  -- "spells/bloodbolt_chest.m2"
--~         Name = kCategory.Trail .. "Swirling, Blood",
--~         BaseScale = 0.03, BaseFacing = 0,
--~         BaseOfsX = 0.1, BaseOfsY = -0.05,
--~         BaseStepX = 3440, BaseStepY = 3175,
--~         IsSkewed = true, HorizontalSlope = 0,
--~     },
--~     [165649] = {  -- "spells/banish_chest_blue.m2"
--~         Name = kCategory.Trail .. "Swirling, Blue",
--~         BaseScale = 0.03, BaseFacing = 0,
--~         BaseOfsX = 0, BaseOfsY = -1.9,
--~         BaseStepX = 3380, BaseStepY = 3050,
--~         IsSkewed = true, HorizontalSlope = 0,
--~     },
--~     [165651] = {  -- "spells/banish_chest_purple.m2"
--~         Name = kCategory.Trail .. "Swirling, Purple",
--~         BaseScale = 0.03, BaseFacing = 0,
--~         BaseOfsX = 0, BaseOfsY = 8.27,
--~         BaseStepX = 2445, BaseStepY = 2450,
--~         IsSkewed = false, HorizontalSlope = 0,
--~     },
--~     [165650] = {  -- "spells/banish_chest_dark.m2"
--~         Name = kCategory.Trail .. "Swirling, Shadow",
--~         BaseScale = 0.03, BaseFacing = 0,
--~         BaseOfsX = 0, BaseOfsY = -1.875,
--~         BaseStepX = 3380, BaseStepY = 3050,
--~         IsSkewed = true, HorizontalSlope = 0,
--~     },
--~     [165652] = {  -- "spells/banish_chest_white.m2"
--~         Name = kCategory.Trail .. "Swirling, White",
--~         BaseScale = 0.02, BaseFacing = 0,
--~         BaseOfsX = 0, BaseOfsY = -1.875,
--~         BaseStepX = 3380, BaseStepY = 3050,
--~         IsSkewed = true, HorizontalSlope = 0,
--~     },
--~ NOTHING SEEN.
--~     [166333] = {  -- "spells/holy_missile_uber.m2"
--~         Name = kCategory.Trail .. "zzzHoly Bright",
--~         BaseScale = 0.05, BaseFacing = 0,
--~         BaseOfsX = 0, BaseOfsY = 0,
--~         BaseStepX = 3330, BaseStepY = 3330,
--~         IsSkewed = false, HorizontalSlope = 0,
--~     },
--~     [165560] = {  -- "spells/alliancectfflag_spell.m2"
--~         Name = kCategory.Trail .. "Holy Glow, Blue & Long",
--~         BaseScale = 0.02, BaseFacing = 0,
--~         BaseOfsX = -0.25, BaseOfsY = 9.05,
--~         BaseStepX = 3600, BaseStepY = 3640,
--~         IsSkewed = true, HorizontalSlope = 0,
--~         SkewTopMult = 0.995, SkewBottomMult = 1.05,  -- Has different side skewing.
--~     },
--~     [166362] = {  -- "spells/huntersmark_impact_chest.m2"
--~         Name = kCategory.Object .. "Hunters Mark",
--~         BaseScale = 0.06, BaseFacing = 0,
--~         BaseOfsX = 0.025, BaseOfsY = -0.01,
--~         BaseStepX = 3430, BaseStepY = 3160,    
--~         IsSkewed = true, HorizontalSlope = 0, 
--~     },
--~     [166546] = {  -- "spells/markofwild_impact_head.m2"
--~         Name = kCategory.Object .. "Mark of the Wild",
--~         BaseScale = 0.05, BaseFacing = 0,
--~         BaseOfsX = 0, BaseOfsY = 6.925,
--~         BaseStepX = 3550, BaseStepY = 3520,
--~         IsSkewed = true, HorizontalSlope = 0,
--~         SkewTopMult = 0.995, SkewBottomMult = 1.05,  -- Has different side skewing.
--~     },      
--~     [410697] = {
--~         Name = "zzzTEST",
--~         BaseScale = 1, BaseFacing = 0,
--~         BaseOfsX = 0, BaseOfsY = 0,
--~         BaseStepX = 3330, BaseStepY = 3330,
--~         IsSkewed = true, HorizontalSlope = 0,
--~         ----SkewTopMult = 0.995, SkewBottomMult = 1.05,  -- Has different side skewing.
--~     },
}

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- Sorted List of Models:
kSortedModelChoices = {}
local modelID, modelData
for modelID, modelData in pairs(kModelConstants) do
    local index = #kSortedModelChoices + 1
    kSortedModelChoices[index] = modelData
    kSortedModelChoices[index].sortedID = modelID
end
table.sort(kSortedModelChoices, function(data1, data2) return (data1.Name < data2.Name); end)

--- End of File ---