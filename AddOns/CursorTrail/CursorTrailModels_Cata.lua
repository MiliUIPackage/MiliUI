--[[---------------------------------------------------------------------------
    File:   CursorTrailModels_Cata.lua
    Desc:   This file contains a list of models used by this addon for Classic Cataclysm.
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

CatColor1 = "|cff9ACEDF"
CatColor2 = "|cffFFA000"
CatColor3 = "|cffFFFA81"
CatColor4 = "|cffF98CB6"
kCategory = {
    Glow    = CatColor1.."發光 - |r",    -- Effects that do not have any motion trail.
    Object  = CatColor2.."發光 - |r",  -- Effects that are shapes or images, and have no motion trail.
    Spots   = CatColor3.."間歇軌跡 - |r",   -- Effects that have an intermittent motion trail.
    Trail   = CatColor4.."連續軌跡 - |r",   -- Effects that have a continuous motion trail.
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
        Name = kCategory.Glow .. "藍色亮光",
        BaseScale = 0.05, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = 0,
        BaseStepX = 3420, BaseStepY = 3156,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [166471] = {  -- "spells/lifetap_state_chest.m2"
        Name = kCategory.Glow .. "綠色亮光",
        BaseScale = 0.05, BaseFacing = 0,
        BaseOfsX = 0.05, BaseOfsY = 0.035,
        BaseStepX = 3428, BaseStepY = 3146,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [166294] = {  -- "spells/healrag_state_chest.m2"
        Name = kCategory.Glow .. "紅色亮光",
        UseSetTransform = true, BaseScale = 0.02,
        ----BaseRotX = 0, BaseRotY = 0, BaseRotZ = 0,
        ----BaseOfsX = 0, BaseOfsY = 0, BaseOfsZ = 0,
    },
    [166923] = {  -- "spells/soulfunnel_impact_chest.m2"
        Name = kCategory.Glow .. "紫色亮光",
        BaseScale = 0.055, BaseFacing = 0,
        BaseOfsX = 0.06, BaseOfsY = 0.037,
        BaseStepX = 3430, BaseStepY = 3150,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [166028] = {  -- "spells/enchantments/spellsurgeglow_high.m2"
        Name = kCategory.Glow .. "藍色雲霧",
        BaseScale = 0.23, BaseFacing = 0,
        BaseOfsX = 0.145, BaseOfsY = 0.925,
        BaseStepX = 3460, BaseStepY = 3190,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [165728] = {  -- "spells/bloodlust_state_hand.m2"
        Name = kCategory.Glow .. "火焰雲霧",
        BaseScale = 0.09, BaseFacing = 0,
        BaseOfsX = 0.025, BaseOfsY = -0.025,
        BaseStepX = 3420, BaseStepY = 3150,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [166255] = {  -- "spells/gouge_precast_state_hand.m2"
        Name = kCategory.Glow .. "紫色雲霧",
        BaseScale = 0.11, BaseFacing = 0,
        BaseOfsX = 0.14, BaseOfsY = 0.004,
        BaseStepX = 3430, BaseStepY = 3150,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [166991] = {  -- "spells/summon_precast_hand.m2"
        Name = kCategory.Glow .. "紫色雲霧 (柔和)",
        BaseScale = 0.18, BaseFacing = 0,
        BaseOfsX = 0.175, BaseOfsY = 0.025,
        BaseStepX = 3438, BaseStepY = 3150,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [166029] = {  -- "spells/enchantments/sunfireglow_high.m2"
        Name = kCategory.Glow .. "星雲",
        UseSetTransform = true, BaseScale = 0.08,
        ----BaseRotX = 0, BaseRotY = 0, BaseRotZ = 0,
        BaseOfsX = -1, BaseOfsY = 1, BaseOfsZ = 0,
    },
    [166640] = {  -- "spells/piercingstrike_cast_hand.m2"
        Name = kCategory.Glow .. "紅色電流",
        UseSetTransform = true, BaseScale = 0.025,
        BaseRotX = 90, BaseRotY = 90, BaseRotZ = 0,
        ----BaseOfsX = 0, BaseOfsY = 0, BaseOfsZ = 0,
    },
    [166054] = {  -- "spells/explosivetrap_recursive.m2"
        Name = kCategory.Glow .. "火焰",
        UseSetTransform = true, BaseScale = 0.05,
        ----BaseRotX = 0, BaseRotY = 0, BaseRotZ = 0,
        BaseOfsX = 0, BaseOfsY = 4, BaseOfsZ = 0,
    },
    [166594] = {  -- "spells/movementimmunity_base.m2"
        Name = kCategory.Glow .. "免疫細胞",
        UseSetTransform = true, BaseScale = 0.01,
        ----BaseRotX = 0, BaseRotY = 0, BaseRotZ = 0,
        ----BaseOfsX = 0, BaseOfsY = 0, BaseOfsZ = 0,
    },

    --~~~~~~~~~~~~~~~~~~~~~~~
    --[[     Objects       ]]
    --~~~~~~~~~~~~~~~~~~~~~~~

    [165778] = {  -- "spells/catmark.m2"
        Name = kCategory.Object .. "紫色箭頭",
        BaseScale = 0.06, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = 8.125,
        BaseStepX = 3570, BaseStepY = 3620,
        IsSkewed = true, HorizontalSlope = 0,
        SkewTopMult = 0.995, SkewBottomMult = 1.05,  -- Has different side skewing.
    },
    [343980] = {  -- "spells/catmark_green.m2"
        Name = kCategory.Object .. "綠色箭頭",
        BaseScale = 0.06, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = 8.125,
        BaseStepX = 3580, BaseStepY = 3560,
        IsSkewed = true, HorizontalSlope = 0,
        SkewTopMult = 0.995, SkewBottomMult = 1.05,  -- Has different side skewing.
    },
    [343983] = {  -- "spells/catmark_white.m2"
        Name = kCategory.Object .. "白色箭頭",
        BaseScale = 0.06, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = 8.1,
        BaseStepX = 3580, BaseStepY = 3520,
        IsSkewed = true, HorizontalSlope = 0,
        SkewTopMult = 0.995, SkewBottomMult = 1.05,  -- Has different side skewing.
    },
    [166453] = {  -- "spells/layonhands_low_head.m2"
        Name = kCategory.Object .. "雙手",
        UseSetTransform = true, BaseScale = 0.019,
        BaseRotX = 0, BaseRotY = 0, BaseRotZ = 270,
        ----BaseOfsX = 0, BaseOfsY = 0, BaseOfsZ = 0,
    },
    [166316] = {  -- "spells/valentines_lookingforloveheart.m2"
        Name = kCategory.Object .. "愛心",
        UseSetTransform = true, BaseScale = 0.021,
        ----BaseRotX = 0, BaseRotY = 0, BaseRotZ = 0,
        ----BaseOfsX = 0, BaseOfsY = 0, BaseOfsZ = 0,
    },
    [166334] = {  -- "spells/holy_precast_high_base.m2"
        Name = kCategory.Object .. "黃色環形",
        UseSetTransform = true, BaseScale = 0.008,
        ----BaseRotX = 0, BaseRotY = 0, BaseRotZ = 0,
        ----BaseOfsX = 0, BaseOfsY = 0, BaseOfsZ = 0,
    },
    [166338] = {  -- "spells/holy_precast_uber_base.m2"
        Name = kCategory.Object .. "黃色環形 2",
        UseSetTransform = true, BaseScale = 0.008,
        ----BaseRotX = 0, BaseRotY = 0, BaseRotZ = 0,
        ----BaseOfsX = 0, BaseOfsY = 0, BaseOfsZ = 0,
    },
    [165751] = {  -- "spells/bonearmor_state_chest.m2"
        Name = kCategory.Object .. "骸骨風暴",
        BaseScale = 0.05, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = -1.1,
        BaseStepX = 3380, BaseStepY = 3080,
        IsSkewed = true, HorizontalSlope = 0,
    },
--~     [166543] = {  -- "spells/manatideinfuse_base.m2"
--~         Name = kCategory.Object .. "Swirl, Pulsing, Blue",
--~         UseSetTransform = true, BaseScale = 0.0014,
--~         ----BaseRotX = 0, BaseRotY = 0, BaseRotZ = 0,
--~         ----BaseOfsX = 0, BaseOfsY = 0, BaseOfsZ = 0,
--~     },
    [165595] = {  -- "spells/arcanetorrent.m2"
        Name = kCategory.Object .. "藍色洪流",
        UseSetTransform = true, BaseScale = 0.004,
        ----BaseRotX = 0, BaseRotY = 0, BaseRotZ = 0,
        ----BaseOfsX = 0, BaseOfsY = 0, BaseOfsZ = 0,
    },
    [519019] = {  -- "spells/arcanetorrent_fiery.m2"
        Name = kCategory.Object .. "紅色洪流",
        UseSetTransform = true, BaseScale = 0.004,
        ----BaseRotX = 0, BaseRotY = 0, BaseRotZ = 0,
        ----BaseOfsX = 0, BaseOfsY = 0, BaseOfsZ = 0,
    },

    --~~~~~~~~~~~~~~~~~~~~~~~~
    --[[   Spotty Trails    ]]
    --~~~~~~~~~~~~~~~~~~~~~~~~

    [240855] = {  -- "spells/demolisher_missile.m2"
        Name = kCategory.Spots .. "火焰",
        BaseScale = 0.04, BaseFacing = 0,
        BaseOfsX = 0.85, BaseOfsY = -0.505,
        BaseStepX = 3404, BaseStepY = 3130,
        IsSkewed = true, HorizontalSlope = 6,
    },
--~     [1617293] = { -- "spells/7fx_kiljaeden_focuseddreadflame_precast.m2"
--~         Name = kCategory.Spots .. "火球",
--~         BaseScale = 0.09, BaseFacing = 0,
--~         BaseOfsX = 0, BaseOfsY = 0,
--~         BaseStepX = 3300, BaseStepY = 3140,
--~         IsSkewed = true, HorizontalSlope = 0,
--~         SkewTopMult = 0.95, SkewBottomMult = 1.06,
--~     },
    [166566] = {  -- "spells/missile_flare.m2"
        Name = kCategory.Spots .. "光亮",
        UseSetTransform = true, BaseScale = 0.03,
        ----BaseRotX = 0, BaseRotY = 0, BaseRotZ = 0,
        BaseOfsX = -0.1, BaseOfsY = 0.2, BaseOfsZ = 0,
    },
    [166381] = {  -- "spells/ice_precast_low_hand.m2"
        Name = kCategory.Spots .. "冰霜",
        BaseScale = 0.12, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = 0.05,
        BaseStepX = 3430, BaseStepY = 3150,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [240902] = {  -- "spells/forsakencatapult_missile.m2"
        Name = kCategory.Spots .. "瘟疫雲",
        BaseScale = 0.06, BaseFacing = 0,
        BaseOfsX = -0.225, BaseOfsY = -0.25,
        BaseStepX = 3420, BaseStepY = 3130,
        IsSkewed = true, HorizontalSlope = -3,
    },
    [347886] = {  -- "spells/goo_flow_statepurple.m2"
        Name = kCategory.Spots .. "紫色漣漪",
        BaseScale = 0.003, BaseFacing = 0,
        BaseOfsX = -0.275, BaseOfsY = 1.85,
        BaseStepX = 3493, BaseStepY = 3243,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [166339] = {  -- "spells/holy_precast_uber_hand.m2"
        Name = kCategory.Spots .. "聖光",
        BaseScale = 0.11, BaseFacing = 0,
        BaseOfsX = 0.04, BaseOfsY = -0.008,
        BaseStepX = 3430, BaseStepY = 3155,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [165956] = {  -- "spells/dispel_low_recursive.m2"
        Name = kCategory.Spots .. "黃色閃光",
        BaseScale = 0.6, BaseFacing = 0,
        BaseOfsX = 0.03, BaseOfsY = -0.025,
        BaseStepX = 3430, BaseStepY = 3160,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [165943] = {  -- "spells/detectmagic_recursive.m2"
        Name = kCategory.Spots .. "藍色閃光",
        BaseScale = 0.65, BaseFacing = 0,
        BaseOfsX = 0.03, BaseOfsY = -0.025,
        BaseStepX = 3430, BaseStepY = 3160,
        IsSkewed = true, HorizontalSlope = 0,
    },
--~     [530075] = {  -- "infinite_timebomb_reticule.m2"
--~         Name = kCategory.Spots .. "Circle",
--~         BaseScale = 0.004, BaseFacing = 0,
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
--~     [975870] = {  -- "cfx_warlock_demonbolt_missle01.m2"
--~         Name = kCategory.Spots .. "Swirling, Purple & Orange",
--~         BaseScale = 0.025, BaseFacing = 0,
--~         BaseOfsX = 0.0, BaseOfsY = 1.35,
--~         BaseStepX = 3458, BaseStepY = 3240,
--~         IsSkewed = true, HorizontalSlope = 0,
--~     },

    --~~~~~~~~~~~~~~~~~~~~~~~~~
    --[[  Continuous Trails  ]]
    --~~~~~~~~~~~~~~~~~~~~~~~~~

    [166492] = {  -- "spells/lightning_precast_low_hand.m2"
        Name = kCategory.Trail .. "藍色閃電",
        BaseScale = 0.1, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = 0.025,
        BaseStepX = 3430, BaseStepY = 3155,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [166498] = {  -- "spells/lightningboltivus_missile.m2"    ****** DEFAULT ******
        Name = kCategory.Trail .. "藍色閃電 (長)",
        BaseScale = 0.01, BaseFacing = 0,
        BaseOfsX = 0.0, BaseOfsY = -0.725,
        BaseStepX = 3422, BaseStepY = 3102,  -- To increase range, decrease #s.  To decrease range, increase #s.
        IsSkewed = true, HorizontalSlope = 0,
    },
    [166491] = {  -- "spells/lightning_fel_precast_low_hand.m2"
        Name = kCategory.Trail .. "綠色閃電",
        BaseScale = 0.11, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = 0,
        BaseStepX = 3430, BaseStepY = 3155,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [167214] = {  -- "spells/wrath_precast_hand.m2"
        Name = kCategory.Trail .. "綠色閃電脈衝",
        BaseScale = 0.08, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = 0,
        BaseStepX = 3430, BaseStepY = 3155,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [165693] = {  -- "spells/blessingoffreedom_state.m2"
        Name = kCategory.Trail .. "自由祝福",
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
        Name = kCategory.Trail .. "綠色脈動",
        BaseScale = 0.03, BaseFacing = 0,
        BaseOfsX = -0.025, BaseOfsY = 0.6,
        BaseStepX = 3500, BaseStepY = 3180,
        IsSkewed = true, HorizontalSlope = 0,
        SkewTopMult = 1, SkewBottomMult = 1.115,  -- Has different side skewing.
    },
    [165653] = {  -- "spells/banish_chest_yellow.m2"
        Name = kCategory.Trail .. "黃色脈動",
        BaseScale = 0.02, BaseFacing = 0,
        BaseOfsX = -0.375, BaseOfsY = -0.1,
        BaseStepX = 3480, BaseStepY = 3140,
        IsSkewed = true, HorizontalSlope = -3,
        SkewTopMult = 1, SkewBottomMult = 1.125,  -- Has different side skewing.
    },
    [166926] = {  -- "spells/soulshatter_missile.m2"
        Name = kCategory.Trail .. "靈魂骸骨",
        BaseScale = 0.14, BaseFacing = 0,
        BaseOfsX = 0, BaseOfsY = 0,
        BaseStepX = 3430, BaseStepY = 3155,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [166426] = {  -- "spells/intervenetrail.m2"
        Name = kCategory.Trail .. "藍色",
        BaseScale = 0.08, BaseFacing = 0,
        BaseOfsX = 0.1, BaseOfsY = 0.5,
        BaseStepX = 3460, BaseStepY = 3200,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [166952] = {  -- "spells/sprint_impact_chest.m2"
        Name = kCategory.Trail .. "綠色",
        BaseScale = 0.08, BaseFacing = 0,
        BaseOfsX = 0.05, BaseOfsY = -0.2,
        BaseStepX = 3440, BaseStepY = 3140,
        IsSkewed = true, HorizontalSlope = 0,
    },
--~     [1417024] = {  -- "spells/ribbontrail_rainbow.m2"
--~         Name = kCategory.Trail .. "彩虹",
--~         BaseScale = 0.08, BaseFacing = 0,
--~         BaseOfsX = 0, BaseOfsY = -0.175,
--~         BaseStepX = 3430, BaseStepY = 3150,
--~         IsSkewed = true, HorizontalSlope = 0,
--~     },
    [165784] = {  -- "spells/chargetrail.m2"
        Name = kCategory.Trail .. "紅色",
        BaseScale = 0.05, BaseFacing = 0,
        BaseOfsX = 0.04, BaseOfsY = -0.15,
        BaseStepX = 3419, BaseStepY = 3140,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [166731] = {  -- "spells/ribbontrail.m2"
        Name = kCategory.Trail .. "白色",
        BaseScale = 0.09, BaseFacing = 0,
        BaseOfsX = 0.05, BaseOfsY = -0.125,
        BaseStepX = 3420, BaseStepY = 3140,
        IsSkewed = true, HorizontalSlope = 0,
    },
    [166159] = {  -- "spells/firestrike_missile_low.m2"
        Name = kCategory.Trail .. "旋轉火球",
        UseSetTransform = true, BaseScale = 0.008,
        BaseRotX = 0, BaseRotY = 270, BaseRotZ = 270,
        ----BaseOfsX = 0, BaseOfsY = 0, BaseOfsZ = 0,
    },
    [166694] = {  -- "spells/rejuvenation_impact_base.m2"
        Name = kCategory.Trail .. "自然療癒",
        BaseScale = 0.022, BaseFacing = 0,
        BaseOfsX = -0.4, BaseOfsY = 8.1,
        BaseStepX = 3570, BaseStepY = 3590,
        IsSkewed = true, HorizontalSlope = -3,
        SkewTopMult = 0.995, SkewBottomMult = 1.05,  -- Has different side skewing.
    },
    [240896] = {  -- "spells/firebomb_missle.m2"
        Name = kCategory.Trail .. "旋轉橘色球體",
        UseSetTransform = true, BaseScale = 0.0032,
        BaseRotX = 270, BaseRotY = 23, BaseRotZ = 270,
        ----BaseOfsX = 0, BaseOfsY = 0, BaseOfsZ = 0,
    },
--~     [1536474] = {  -- "cfx_monk_chiorbit_missile.m2"
--~         Name = kCategory.Trail .. "Cloud, Blue & Green",
--~         BaseScale = 0.1, BaseFacing = 0,
--~         BaseOfsX = 0.15, BaseOfsY = 0.10,
--~         BaseStepX = 3420, BaseStepY = 3156,
--~         IsSkewed = true, HorizontalSlope = 0,
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
table.sort(kSortedModelChoices,
        function(data1, data2)
            local name1 = data1.Name
            local name2 = data2.Name
            -- Ignore color codes when comparing names.
            if name1:sub(1,2) == "|c" then name1 = name1:sub(11) end
            if name2:sub(1,2) == "|c" then name2 = name2:sub(11) end
            return (name1 < name2)
        end)

--- End of File ---