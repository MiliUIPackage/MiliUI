--[[---------------------------------------------------------------------------
    Addon:  CursorTrail
    File:   CursorTrailModels_Classic.lua
    Desc:   This file contains a list of models used by this addon for Classic WoW.
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
        BaseStepX = 3420, BaseStepY = 3156,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [166471] = {  -- "spells/lifetap_state_chest.m2"
        Name = kCategory.Glow .. "Burning Cloud, Green",
        BaseScale = 0.05, BaseFacing = 0,
        BaseOfsX = 0.05, BaseOfsY = 0.015,
        BaseStepX = 3428, BaseStepY = 3146,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [166923] = {  -- "spells/soulfunnel_impact_chest.m2"
        Name = kCategory.Glow .. "Burning Cloud, Purple",
        BaseScale = 0.055, BaseFacing = 0,
        BaseOfsX = 0.06, BaseOfsY = 0.035,
        BaseStepX = 3430, BaseStepY = 3150,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [165728] = {  -- "spells/bloodlust_state_hand.m2"
        Name = kCategory.Glow .. "Cloud, Flame",
        BaseScale = 0.08, BaseFacing = 0,
        BaseOfsX = 0.225, BaseOfsY = -0.15,
        BaseStepX = 3420, BaseStepY = 3150,
        IsSkewed = true, HorizontalSlope = 2, 
    },
    [166255] = {  -- "spells/gouge_precast_state_hand.m2"
        Name = kCategory.Glow .. "Cloud, Purple",
        BaseScale = 0.1, BaseFacing = 0,
        BaseOfsX = 0.225, BaseOfsY = -0.15,
        BaseStepX = 3430, BaseStepY = 3150,
        IsSkewed = true, HorizontalSlope = 1, 
    },
    [166991] = {  -- "spells/summon_precast_hand.m2"
        Name = kCategory.Glow .. "Cloud, Purple (Soft)",
        BaseScale = 0.18, BaseFacing = 0,
        BaseOfsX = 0.925, BaseOfsY = -0.725,
        BaseStepX = 3408, BaseStepY = 3150,
        IsSkewed = true, HorizontalSlope = 6,
    },

    --~~~~~~~~~~~~~~~~~~~~~~~
    --[[     Objects       ]]
    --~~~~~~~~~~~~~~~~~~~~~~~
    
    [165751] = {  -- "spells/bonearmor_state_chest.m2"
        Name = kCategory.Object .. "Ring of Bones",
        BaseScale = 0.05, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = -1.125,
        BaseStepX = 3350, BaseStepY = 3100,
        IsSkewed = true, HorizontalSlope = 0,
    },
    
    --~~~~~~~~~~~~~~~~~~~~~~~~
    --[[   Spotty Trails    ]]
    --~~~~~~~~~~~~~~~~~~~~~~~~
    
    [166381] = {  -- "spells/ice_precast_low_hand.m2"
        Name = kCategory.Spots .. "Frost",
        BaseScale = 0.12, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = 0,
        BaseStepX = 3430, BaseStepY = 3150,
        IsSkewed = true, HorizontalSlope = 0, 
    },
    [166339] = {  -- "spells/holy_precast_uber_hand.m2"
        Name = kCategory.Spots .. "Pulsing, Holy",
        BaseScale = 0.11, BaseFacing = 0,
        BaseOfsX = 0.04, BaseOfsY = -0.033,
        BaseStepX = 3430, BaseStepY = 3155,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [165956] = {  -- "spells/dispel_low_recursive.m2"
        Name = kCategory.Spots .. "Sparkle, Yellow",
        BaseScale = 0.6, BaseFacing = 0,
        BaseOfsX = 0.03, BaseOfsY = -0.025,
        BaseStepX = 3430, BaseStepY = 3160,
        IsSkewed = true, HorizontalSlope = 0, 
    },
    [165943] = {  -- "spells/detectmagic_recursive.m2"
        Name = kCategory.Spots .. "Sparkle, Blue",
        BaseScale = 0.65, BaseFacing = 0,
        BaseOfsX = 0.03, BaseOfsY = -0.025,
        BaseStepX = 3430, BaseStepY = 3160,
        IsSkewed = true, HorizontalSlope = 0, 
    },

    --~~~~~~~~~~~~~~~~~~~~~~~~~
    --[[  Continuous Trails  ]]
    --~~~~~~~~~~~~~~~~~~~~~~~~~
    
    [166498] = {  -- "spells/lightningboltivus_missile.m2"    ****** DEFAULT ******
        Name = kCategory.Trail .. "Electric, Blue (Long)",
        BaseScale = 0.01, BaseFacing = 0,
        BaseOfsX = 0.0, BaseOfsY = 0.25,
        BaseStepX = 3442, BaseStepY = 3172,  -- To increase range, decrease #s.  To decrease range, increase #s.
        IsSkewed = true, HorizontalSlope = 0,
    },
    [166492] = {  -- "spells/lightning_precast_low_hand.m2"
        Name = kCategory.Trail .. "Electric, Blue",
        BaseScale = 0.1, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = 0,
        BaseStepX = 3430, BaseStepY = 3155,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [167214] = {  -- "spells/wrath_precast_hand.m2"
        Name = kCategory.Trail .. "Electric, Green Pulse",
        BaseScale = 0.08, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = 0,
        BaseStepX = 3430, BaseStepY = 3155,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [167229] = {  -- "spells/zig_missile.m2"
        Name = kCategory.Trail .. "Ghost",
        BaseScale = 0.02, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = 0,
        BaseStepX = 3430, BaseStepY = 3155,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [165648] = {  -- "spells/banish_chest.m2"
        Name = kCategory.Trail .. "Pulsing, Green",
        BaseScale = 0.019, BaseFacing = 0,
        BaseOfsX = -0.125, BaseOfsY = 2.9,
        BaseStepX = 3510, BaseStepY = 3330,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [166952] = {  -- "spells/sprint_impact_chest.m2"
        Name = kCategory.Trail .. "Sparkling, Green",
        BaseScale = 0.08, BaseFacing = 0,
        BaseOfsX = -0.05, BaseOfsY = -0.2,
        BaseStepX = 3440, BaseStepY = 3140,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [165784] = {  -- "spells/chargetrail.m2"
        Name = kCategory.Trail .. "Sparkling, Red",
        BaseScale = 0.05, BaseFacing = 0,
        BaseOfsX = 0.04, BaseOfsY = -0.18,
        BaseStepX = 3419, BaseStepY = 3140,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [166731] = {  -- "spells/ribbontrail.m2"
        Name = kCategory.Trail .. "Sparkling, White",
        BaseScale = 0.09, BaseFacing = 0,
        BaseOfsX = 0.1, BaseOfsY = -0.125,
        BaseStepX = 3420, BaseStepY = 3140,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [166694] = {  -- "spells/rejuvenation_impact_base.m2"
        Name = kCategory.Trail .. "Swirling, Nature",
        BaseScale = 0.022, BaseFacing = 0,
        BaseOfsX = -0.4, BaseOfsY = 8.1,
        BaseStepX = 3570, BaseStepY = 3590,
        IsSkewed = true, HorizontalSlope = -3,
        SkewTopMult = 0.995, SkewBottomMult = 1.05,  -- Has different side skewing.
    },
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