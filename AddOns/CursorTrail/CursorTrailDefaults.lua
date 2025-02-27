--[[---------------------------------------------------------------------------
    File:   CursorTrailDefaults.lua
    Desc:   This file contains default settings for this addon.
-----------------------------------------------------------------------------]]

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Aliases to Globals                                ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

local Globals = _G
local _  -- Prevent tainting global _ .
local assert = _G.assert
local CopyTable = _G.CopyTable
----local DEFAULTS = _G.DEFAULTS  -- Blizzard's localized string: "Defaults"
local pairs = _G.pairs
----local print = _G.print

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

kDefaultModelID = (isRetailWoW() and 1417024 or 166498 )  -- "Electric, Blue & Long"
kDefaultStrata = "HIGH"

kNoChange = nil  -- Must be nil so compareToDefaultProfile() in UDProfiles.lua can work.

-- The main table.
kDefaultConfig =  -- Initialize this variable to an empty table.
{
    -- NOTES:
    --      Default names are limited to kProfileNameMaxLetters characters (defined in ProfilesUI.lua).
    --
    --      UserScale          - User model scale.  It is 1/100th the value shown in the UI.
    --      UserAlpha          - Solid = 1.0.  Transparent = 0.0
    --      UserShadowAlpha    - Solid = 0.99.  Transparent = 0.0
    --      UserOfsX, UserOfsY - User model offsets are 1/10th the values shown in the UI.
}

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       ALL WoW VERSIONS                                  ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

----------------________________________-----------------------------------
kDefaultConfig["閃電"] = {  -- [ Keywords: kDefaultConfigKey ]
    MasterScale = 1,
    Layers = {
        [1] = {
            IsLayerEnabled = true,
            ShapeFileName = kShape_None,
            ModelID = 166498,
            ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0,
            UserScale = 1,
            UserAlpha = 1,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = true,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = kNoChange,
        },
    },
}
----------------________________________-----------------------------------
kDefaultConfig["閃電黑白環"] = {
    MasterScale = 1,
    Layers = {
        [1] = {
            IsLayerEnabled = true,
            ShapeFileName = kMediaPath.."Ring Soft 1.tga",
            ModelID = 166498,  -- "Electric, Blue & Long"
            ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0,
            UserScale = 1,
            UserAlpha = 1,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = true,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = false,
        },
        [2] = {
            IsLayerEnabled = true,
            ShapeFileName = kMediaPath.."Ring 1.tga",
            ModelID = 0,
            ShapeColorR = 0, ShapeColorG = 0, ShapeColorB = 0,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0,
            UserScale = 1.15,
            UserAlpha = 1,
            Strata = "BACKGROUND",
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = true,
        },
        [3] = {
            IsLayerEnabled = true,
            ShapeFileName = kMediaPath.."Ring 1.tga",
            ModelID = 0,
            ShapeColorR = 0.5, ShapeColorG = 0.5, ShapeColorB = 0.5,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0,
            UserScale = 1.27,
            UserAlpha = 0.25,
            Strata = "BACKGROUND",
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = true,
        },
    },
}
----------------________________________-----------------------------------
kDefaultConfig["閃電-大"] = {
    MasterScale = 1,
    Layers = {
        [1] = {
            IsLayerEnabled = true,
            ShapeFileName = kShape_None,
            ModelID = 166498,
            ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0,
            UserScale = 1.35,
            UserAlpha = 0.50,
            Strata = kDefaultStrata,
            UserOfsX = 1.0, UserOfsY = -0.9,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = kNoChange,
        },
    },
}
----------------________________________-----------------------------------
kDefaultConfig["閃電-小"] = {
    MasterScale = 1,
    Layers = {
        [1] = {
            IsLayerEnabled = true,
            ShapeFileName = kShape_None,
            ModelID = 166498,
            ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0,
            UserScale = 0.50,
            UserAlpha = 1,
            Strata = kDefaultStrata,
            UserOfsX = 3.4, UserOfsY = -2.8,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = kNoChange,
        },
    },
}
----------------________________________-----------------------------------
kDefaultConfig["閃電-巨大"] = {
    MasterScale = 1,
    Layers = {
        [1] = {
            IsLayerEnabled = true,
            ShapeFileName = kShape_None,
            ModelID = 166498,
            ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0.30,
            UserScale = 1.8,
            UserAlpha = 0.65,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = kNoChange,
        },
    },
}
----------------________________________-----------------------------------
kDefaultConfig["紫光"] = {
    MasterScale = 1,
    Layers = {
        [1] = {
            IsLayerEnabled = true,
            ShapeFileName = kShape_None,
            ModelID = 166923,  -- "Burning Cloud, Purple"
            ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0,
            UserScale = 2.0,
            UserAlpha = 1,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = kNoChange,
        },
    },
}
----------------________________________-----------------------------------
kDefaultConfig["紫光-淡出"] = {
    MasterScale = 1,
    Layers = {
        [1] = {
            IsLayerEnabled = true,
            ShapeFileName = kShape_None,
            ModelID = 166923,  -- "Burning Cloud, Purple"
            ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0,
            UserScale = 2.5,
            UserAlpha = 1,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = true,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = kNoChange,
        },
    },
}
----------------________________________-----------------------------------
kDefaultConfig["紫光-淡出2"] = {
    MasterScale = 1,
    Layers = {
        [1] = {
            IsLayerEnabled = true,
            ShapeFileName = kShape_None,
            ModelID = 166923,  -- "Burning Cloud, Purple"
            ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0.50,
            UserScale = 1.5,
            UserAlpha = 0.80,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0.025,
            -- - - - - - - - - - - - - - --
            FadeOut = true,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = kNoChange,
        },
    },
}
----------------________________________-----------------------------------
kDefaultConfig["光暈-淡出"] = {
    MasterScale = 1,
    Layers = {
        [1] = {
            IsLayerEnabled = true,
            ShapeFileName = kShape_None,
            ModelID = 166991,  -- "Cloud, Purple (Soft)"
            ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0,
            UserScale = 2.4,
            UserAlpha = 1,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = true,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = kNoChange,
        },
    },
}
----------------________________________-----------------------------------
kDefaultConfig["紅色發光星星"] = {
    MasterScale = 1,
    Layers = {
        [1] = {
            IsLayerEnabled = true,
            ShapeFileName = kMediaPath.."Star 1.tga",
            ModelID = 166294,  -- "Burning Cloud, Red"
            ShapeColorR = 1, ShapeColorG = 0.502, ShapeColorB = 0,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0.35,
            UserScale = 1.05,
            UserAlpha = 1,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = kNoChange,
        },
        [2] = {
            IsLayerEnabled = true,
            ShapeFileName = kShape_None,
            ModelID = 166159,  -- "Trail - Swirling, Firestrike"
            ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0,
            UserScale = 1,
            UserAlpha = 1,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = kNoChange,
        },
    },
}
----------------________________________-----------------------------------
kDefaultConfig["環形和閃電"] = {
    MasterScale = 1,
    Layers = {
        [1] = {
            IsLayerEnabled = true,
            ShapeFileName = kMediaPath.."Ring 2.tga",
            ModelID = 166498,
            ShapeColorR = 0, ShapeColorG = 1, ShapeColorB = 1,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0.3,
            UserScale = 0.9,
            UserAlpha = 1,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = kNoChange,
        },
        [2] = {
            IsLayerEnabled = true,
            ShapeFileName = kMediaPath.."Ring Soft 4.tga",
            ModelID = 0,
            ShapeColorR = 0, ShapeColorG = 0, ShapeColorB = 0,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0,
            UserScale = 0.98,
            UserAlpha = 0.65,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = kNoChange,
        },
    },
}
----------------________________________-----------------------------------
kDefaultConfig["環形-黑邊"] = {
    MasterScale = 0.9,
    Layers = {
        [1] = {
            IsLayerEnabled = true,
            ShapeFileName = kMediaPath.."Ring 2.tga",
            ModelID = 0,
            ShapeColorR = 0.992, ShapeColorG = 0.792, ShapeColorB = 0.635,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0.3,
            UserScale = 0.9,
            UserAlpha = 1,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = kNoChange,
        },
        [2] = {
            IsLayerEnabled = true,
            ShapeFileName = kMediaPath.."Ring Soft 4.tga",
            ModelID = 0,
            ShapeColorR = 0, ShapeColorG = 0, ShapeColorB = 0,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0,
            UserScale = 0.98,
            UserAlpha = 0.65,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = kNoChange,
        },
    },
}
----------------________________________-----------------------------------
kDefaultConfig["環形-黯淡"] = {
    MasterScale = 0.9,
    Layers = {
        [1] = {
            IsLayerEnabled = true,
            ShapeFileName = kMediaPath.."Ring 2.tga",
            ModelID = 0,
            ShapeColorR = 0.992, ShapeColorG = 0.792, ShapeColorB = 0.635,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0,
            UserScale = 0.9,
            UserAlpha = 1,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = false,
        },
        [2] = {
            IsLayerEnabled = true,
            ShapeFileName = kMediaPath.."Ring Soft 2.tga",
            ModelID = 0,
            ShapeColorR = 0.992, ShapeColorG = 0.792, ShapeColorB = 0.635,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0.05,
            UserScale = 0.9,
            UserAlpha = 0.3,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = true,
        },
        [3] = {
            IsLayerEnabled = true,
            ShapeFileName = kMediaPath.."Ring Soft 4.tga",
            ModelID = 0,
            ShapeColorR = 0, ShapeColorG = 0, ShapeColorB = 0,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0,
            UserScale = 0.99,
            UserAlpha = 0.65,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = true,
        },
    },
}----------------________________________-----------------------------------
kDefaultConfig["環形-閃爍"] = {
    MasterScale = 1,
    Layers = {
        [1] = {
            IsLayerEnabled = true,
            ShapeFileName = kMediaPath.."Ring 3.tga",
            ModelID = 0,
            ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
            ShapeSparkle = true,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0.65,
            UserScale = 0.65,
            UserAlpha = 1,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = kNoChange,
        },
    },
}
----------------________________________-----------------------------------
kDefaultConfig["星星-黑邊"] = {
    MasterScale = 1.25,
    Layers = {
        [1] = {
            IsLayerEnabled = true,
            ShapeFileName = kMediaPath.."Star 1.tga",
            ModelID = 0,
            ShapeColorR = 0.992, ShapeColorG = 0.792, ShapeColorB = 0.635,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0,
            UserScale = 1.14,
            UserAlpha = 1,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = kNoChange,
        },
        [2] = {
            IsLayerEnabled = true,
            ShapeFileName = kMediaPath.."Star 1.tga",
            ModelID = 0,
            ShapeColorR = 0, ShapeColorG = 0, ShapeColorB = 0,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0,
            UserScale = 0.83,
            UserAlpha = 1,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = kNoChange,
        },
        [3] = {
            IsLayerEnabled = true,
            ShapeFileName = kShape_None,
            ModelID = 0,
            ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0.1,
            UserScale = 0.75,
            UserAlpha = 1,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = kNoChange,
        },
    },
}
----------------________________________-----------------------------------
kDefaultConfig["星星-雙重"] = {
    MasterScale = 1.25,
    Layers = {
        [1] = {
            IsLayerEnabled = true,
            ShapeFileName = kMediaPath.."Star 1.tga",
            ModelID = 0,
            ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0,
            UserScale = 1.14,
            UserAlpha = 1,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = kNoChange,
        },
        [2] = {
            IsLayerEnabled = true,
            ShapeFileName = kMediaPath.."Star 1.tga",
            ModelID = 0,
            ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0,
            UserScale = 0.83,
            UserAlpha = 1,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = kNoChange,
        },
        [3] = {
            IsLayerEnabled = true,
            ShapeFileName = kShape_None,
            ModelID = 0,
            ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0.2,
            UserScale = 0.75,
            UserAlpha = 1,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = kNoChange,
        },
    },
}
----------------________________________-----------------------------------
kDefaultConfig["星星-綠光"] = {
    MasterScale = 1,
    Layers = {
        [1] = {
            IsLayerEnabled = true,
            ShapeFileName = kMediaPath.."Star 1.tga",
            ModelID = 167214,  -- "Trail - Electric, Green Pulse"
            ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0,
            UserScale = 1,
            UserAlpha = 0.88,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0.025,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = kNoChange,
        },
    },
}
----------------________________________-----------------------------------
kDefaultConfig["十字黃色脈動"] = {
    MasterScale = 1,
    Layers = {
        [1] = {
            IsLayerEnabled = true,
            ShapeFileName = kMediaPath.."Cross 2.tga",
            ModelID = 166339,  -- "Spots - Pulsing, Holy"
            ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 0,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0.55,
            UserScale = 1.06,
            UserAlpha = 0.85,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = kNoChange,
        },
    },
}
----------------________________________-----------------------------------
kDefaultConfig["十字暗影光暈"] = {
    MasterScale = 1,
    Layers = {
        [1] = {
            IsLayerEnabled = true,
            ShapeFileName = kMediaPath.."Cross 2.tga",
            ModelID = 166255,  -- "Glow - Cloud, Purple"
            ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0.99,
            UserScale = 0.88,
            UserAlpha = 1,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = kNoChange,
        },
    },
}
----------------________________________-----------------------------------
kDefaultConfig["環形和骸骨"] = {
    MasterScale = 1,
    Layers = {
        [1] = {
            IsLayerEnabled = true,
            ShapeFileName = kMediaPath.."Ring Soft 2.tga",
            ModelID = 165751,  -- "Object - Ring of Bones"
            ShapeColorR = 1, ShapeColorG = 0.882, ShapeColorB = 0.882,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0.44,
            UserScale = 0.75,
            UserAlpha = 1,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0.05,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = kNoChange,
        },
    },
}

----------------________________________-----------------------------------
kDefaultConfig["紅色十字線和圈"] = {
    MasterScale = 1,
    Layers = {
        [1] = {
            IsLayerEnabled = true,
            ShapeFileName = kMediaPath.."Cross 1.tga",
            ModelID = 0,  -- None.
            ShapeColorR = 1, ShapeColorG = 0, ShapeColorB = 0,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0,
            UserScale = 0.75,
            UserAlpha = 1,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = true,
        },
        [2] = {
            IsLayerEnabled = true,
            ShapeFileName = kMediaPath.."Ring 1.tga",
            ModelID = 165784,  -- "Trail - Sparkling, Red"
            ShapeColorR = 1, ShapeColorG = 0, ShapeColorB = 0,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0.2,
            UserScale = 1.15,
            UserAlpha = 1,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = true,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = false,
        },
    },
}

----------------________________________-----------------------------------
kDefaultConfig["大環形-發綠光"] = {
    MasterScale = 1,
    Layers = {
        [1] = {
            IsLayerEnabled = true,
            ShapeFileName = kMediaPath.."Ring 1.tga",
            ModelID = 0,
            ShapeColorR = 1, ShapeColorG = 0.761, ShapeColorB = 0,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0.15,
            UserScale = 1.26,
            UserAlpha = 1,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = true,
        },
        [2] = {
            IsLayerEnabled = true,
            ShapeFileName = kMediaPath.."Ring Soft 3.tga",
            ModelID = 0,
            ShapeColorR = 0.502, ShapeColorG = 1, ShapeColorB = 0,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0,
            UserScale = 1.35,
            UserAlpha = 1,
            Strata = "BACKGROUND",
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = true,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = false,
        },
    },
}
----------------________________________-----------------------------------
kDefaultConfig["邪惡之眼"] = {
    MasterScale = 1,
    Layers = {
        [1] = {
            IsLayerEnabled = true,
            ShapeFileName = kShape_None,
            ModelID = 166334,  -- "Object - Ring, Yellow"
            ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0,
            UserScale = 1,
            UserAlpha = 0.85,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = kNoChange,
        },
        [2] = {
            IsLayerEnabled = true,
            ShapeFileName = 458999,  -- "Ring (Meat)"
            ModelID = 166334,  -- "Object - Ring, Yellow"
            ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 0.5,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0,
            UserScale = 1.15,
            UserAlpha = 1,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = kNoChange,
        },
        [3] = {
            IsLayerEnabled = true,
            ShapeFileName = kShape_None,
            ModelID = 166159,  -- "Trail - Swirling, Firestrike"
            ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0,
            UserScale = 1.15,
            UserAlpha = 1,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = true,
            UserShowOnlyInCombat = kNoChange,
            UserShowMouseLook = false,
        },
    },
}
----------------________________________-----------------------------------
kDefaultConfig["(這裡開始)"] = {
    MasterScale = 1,
    Layers = {
        [1] = {
            IsLayerEnabled = true,
            ShapeFileName = kMediaPath.."Cross 1.tga",
            ModelID = 0,  -- None.
            ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0,
            UserScale = 1,
            UserAlpha = 1,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = false,
            UserShowMouseLook = false,
        },
        [2] = {
            IsLayerEnabled = false,
            ShapeFileName = kMediaPath.."Ring 1.tga",
            ModelID = 0,  -- None.
            ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
            ShapeSparkle = false,
            -- - - - - - - - - - - - - - --
            UserShadowAlpha = 0,
            UserScale = 1,
            UserAlpha = 1,
            Strata = kDefaultStrata,
            UserOfsX = 0, UserOfsY = 0,
            -- - - - - - - - - - - - - - --
            FadeOut = false,
            UserShowOnlyInCombat = false,
            UserShowMouseLook = false,
        },
    },
}

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       RETAIL, CATA & WRATH WoW                          ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

if isWrathWoW_Min() then
    ----------------________________________-----------------------------------
    kDefaultConfig["冰冷"] = {
        MasterScale = 1,
        Layers = {
            [1] = {
                IsLayerEnabled = true,
                ShapeFileName = kShape_None,
                ModelID = 166028,  -- "Glow - Cloud, Blue"
                ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
                ShapeSparkle = false,
                -- - - - - - - - - - - - - - --
                UserShadowAlpha = 0,
                UserScale = 2.6,
                UserAlpha = 1,
                Strata = kDefaultStrata,
                UserOfsX = 0, UserOfsY = 0,
                -- - - - - - - - - - - - - - --
                FadeOut = false,
                UserShowOnlyInCombat = kNoChange,
                UserShowMouseLook = kNoChange,
            },
            [2] = {
                IsLayerEnabled = true,
                ShapeFileName = 458995,  -- "Ring (Ice)"
                ModelID = 166538,  -- "Glow - Burning Cloud, Blue"
                ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
                ShapeSparkle = false,
                -- - - - - - - - - - - - - - --
                UserShadowAlpha = 0.2,
                UserScale = 1.15,
                UserAlpha = 1,
                Strata = kDefaultStrata,
                UserOfsX = 0, UserOfsY = 0,
                -- - - - - - - - - - - - - - --
                FadeOut = false,
                UserShowOnlyInCombat = kNoChange,
                UserShowMouseLook = kNoChange,
            },
        },
    }
    ----------------________________________-----------------------------------
    kDefaultConfig["靈魂骸骨"] = {
        MasterScale = 1,
        Layers = {
            [1] = {
                IsLayerEnabled = true,
                ShapeFileName = kShape_None,
                ModelID = 166926,  -- "Soul Skull"
                ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
                ShapeSparkle = false,
                -- - - - - - - - - - - - - - --
                UserShadowAlpha = 0,
                UserScale = 1.5,
                UserAlpha = 1,
                Strata = kDefaultStrata,
                UserOfsX = 0, UserOfsY = 0,
                -- - - - - - - - - - - - - - --
                FadeOut = false,
                UserShowOnlyInCombat = kNoChange,
                UserShowMouseLook = kNoChange,
            },
        },
    }
    ----------------________________________-----------------------------------
    kDefaultConfig["環形和靈魂骸骨"] = {
        MasterScale = 1,
        Layers = {
            [1] = {
                IsLayerEnabled = true,
                ShapeFileName = kMediaPath.."Ring Soft 2.tga",
                ModelID = 166926,  -- "Soul Skull"
                ShapeColorR = 0.984, ShapeColorG = 0.714, ShapeColorB = 0.82,
                ShapeSparkle = false,
                -- - - - - - - - - - - - - - --
                UserShadowAlpha = 0.3,
                UserScale = 0.7,
                UserAlpha = 1,
                Strata = kDefaultStrata,
                UserOfsX = 0, UserOfsY = 0,
                -- - - - - - - - - - - - - - --
                FadeOut = false,
                UserShowOnlyInCombat = kNoChange,
                UserShowMouseLook = kNoChange,
            },
        },
    }
    ----------------________________________-----------------------------------
    kDefaultConfig["藍綠合"] = {
        MasterScale = 1,
        Layers = {
            [1] = {
                IsLayerEnabled = true,
                ShapeFileName = kMediaPath.."Glow Reversed.tga",
                ModelID = 166491,  -- "Trail - Electric, Green"
                ShapeColorR = 0, ShapeColorG = 0, ShapeColorB = 1,
                ShapeSparkle = false,
                -- - - - - - - - - - - - - - --
                UserShadowAlpha = 0,
                UserScale = 0.42,
                UserAlpha = 0.88,
                Strata = kDefaultStrata,
                UserOfsX = 0, UserOfsY = 0.05,
                -- - - - - - - - - - - - - - --
                FadeOut = false,
                UserShowOnlyInCombat = kNoChange,
                UserShowMouseLook = kNoChange,
            },
        },
    }
    ----------------________________________-----------------------------------
    kDefaultConfig["橘球"] = {
        MasterScale = 1,
        Layers = {
            [1] = {
                IsLayerEnabled = true,
                ShapeFileName = kShape_None,
                ModelID = 240896,  -- "Trail - Swirling, Orange"
                ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
                ShapeSparkle = false,
                -- - - - - - - - - - - - - - --
                UserShadowAlpha = 0.5,
                UserScale = 1,
                UserAlpha = 0.88,
                Strata = kDefaultStrata,
                UserOfsX = 0, UserOfsY = (isVanillaWoW() and -2.2) or 0,
                -- - - - - - - - - - - - - - --
                FadeOut = false,
                UserShowOnlyInCombat = kNoChange,
                UserShowMouseLook = kNoChange,
            },
        },
    }
end

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       RETAIL WoW                                        ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

if isRetailWoW() then
	----------------________________________-----------------------------------
    kDefaultConfig["我愛彩虹"] = {
        MasterScale = 1,
		Layers = {
            [1] = {
                IsLayerEnabled = true,
                ShapeFileName = nil,
                ModelID = 1417024,  -- "Sparkling, Rainbow"
                ShapeColorR = 1, ShapeColorG = 0.882, ShapeColorB = 0.882,
                ShapeSparkle = false,
                -- - - - - - - - - - - - - - --
                UserShadowAlpha = 0,
                UserScale = 1.17,
                UserAlpha = 1,
                Strata = kDefaultStrata,
                UserOfsX = 0, UserOfsY = 0,
                -- - - - - - - - - - - - - - --
                FadeOut = false,
                --UserShowOnlyInCombat = true,
                --UserShowMouseLook = true,
            },
        },
    }
    ----------------________________________-----------------------------------
    kDefaultConfig["華麗滾珠轉軸"] = {
        MasterScale = 1,
        Layers = {
            [1] = {
                IsLayerEnabled = true,
                ShapeFileName = kShape_None,
                ModelID = 1414694,  -- "Object - Pentagon Flashers"
                ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
                ShapeSparkle = false,
                -- - - - - - - - - - - - - - --
                UserShadowAlpha = 0,
                UserScale = 1.5,
                UserAlpha = 1,
                Strata = kDefaultStrata,
                UserOfsX = 0, UserOfsY = 0,
                -- - - - - - - - - - - - - - --
                FadeOut = false,
                UserShowOnlyInCombat = kNoChange,
                UserShowMouseLook = kNoChange,
            },
            [2] = {
                IsLayerEnabled = true,
                ShapeFileName = 457566,  -- "Ring (Atramedes)"
                ModelID = 1536474,  -- "Trail - Cloud, Blue & Green"
                ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
                ShapeSparkle = false,
                -- - - - - - - - - - - - - - --
                UserShadowAlpha = 0,
                UserScale = 1.17,
                UserAlpha = 1,
                Strata = kDefaultStrata,
                UserOfsX = 0, UserOfsY = 0,
                -- - - - - - - - - - - - - - --
                FadeOut = false,
                UserShowOnlyInCombat = kNoChange,
                UserShowMouseLook = kNoChange,
            },
        },
    }
    ----------------________________________-----------------------------------
    kDefaultConfig["環形和彩虹"] = {
        MasterScale = 1,
        Layers = {
            [1] = {
                IsLayerEnabled = true,
                ShapeFileName = kMediaPath.."Ring Soft 2.tga",
                ModelID = 1417024,  -- "Sparkling, Rainbow"
                ShapeColorR = 1, ShapeColorG = 0.882, ShapeColorB = 0.882,
                ShapeSparkle = false,
                -- - - - - - - - - - - - - - --
                UserShadowAlpha = 0.7,
                UserScale = 0.88,
                UserAlpha = 1,
                Strata = kDefaultStrata,
                UserOfsX = 0, UserOfsY = 0,
                -- - - - - - - - - - - - - - --
                FadeOut = false,
                UserShowOnlyInCombat = kNoChange,
                UserShowMouseLook = true,
            },
            [2] = {
                IsLayerEnabled = true,
                ShapeFileName = kMediaPath.."Ring Soft 2.tga",
                ModelID = 0,
                ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
                ShapeSparkle = true,
                -- - - - - - - - - - - - - - --
                UserShadowAlpha = 0,
                UserScale = 1.07,
                UserAlpha = 1,
                Strata = kDefaultStrata,
                UserOfsX = 0, UserOfsY = 0,
                -- - - - - - - - - - - - - - --
                FadeOut = true,
                UserShowOnlyInCombat = kNoChange,
                UserShowMouseLook = false,
            },
        },
    }
    ----------------________________________-----------------------------------
    kDefaultConfig["環形和彩虹 2"] = {
        MasterScale = 1,
        Layers = {
            [1] = {
                IsLayerEnabled = true,
                ShapeFileName = kShape_None,
                ModelID = 165943,  -- "Sparkle, Blue"
                ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
                ShapeSparkle = false,
                -- - - - - - - - - - - - - - --
                UserShadowAlpha = 0,
                UserScale = 1.5,
                UserAlpha = 1,
                Strata = kDefaultStrata,
                UserOfsX = 0, UserOfsY = 0,
                -- - - - - - - - - - - - - - --
                FadeOut = false,
                UserShowOnlyInCombat = kNoChange,
                UserShowMouseLook = kNoChange,
            },
            [2] = {
                IsLayerEnabled = true,
                ShapeFileName = kMediaPath.."Ring 2.tga",
                ModelID = 1417024,  -- "Sparkling, Rainbow"
                ShapeColorR = 1, ShapeColorG = 0.592, ShapeColorB = 0,
                ShapeSparkle = false,
                -- - - - - - - - - - - - - - --
                UserShadowAlpha = 0.3,
                UserScale = 0.9,
                UserAlpha = 1,
                Strata = kDefaultStrata,
                UserOfsX = 0, UserOfsY = 0,
                -- - - - - - - - - - - - - - --
                FadeOut = false,
                UserShowOnlyInCombat = kNoChange,
                UserShowMouseLook = kNoChange,
            },
            [3] = {
                IsLayerEnabled = true,
                ShapeFileName = kMediaPath.."Ring Soft 4.tga",
                ModelID = 0,
                ShapeColorR = 0, ShapeColorG = 0, ShapeColorB = 0,
                ShapeSparkle = false,
                -- - - - - - - - - - - - - - --
                UserShadowAlpha = 0,
                UserScale = 0.98,
                UserAlpha = 0.65,
                Strata = kDefaultStrata,
                UserOfsX = 0, UserOfsY = 0,
                -- - - - - - - - - - - - - - --
                FadeOut = false,
                UserShowOnlyInCombat = kNoChange,
                UserShowMouseLook = kNoChange,
            },
        },
    }
    ----------------________________________-----------------------------------
    kDefaultConfig["星星-火焰"] = {
        MasterScale = 1,
        Layers = {
            [1] = {
                IsLayerEnabled = true,
                ShapeFileName = kMediaPath.."Star 1.tga",
                ModelID = 1617293,  -- "Spots - Fire Orb"
                ShapeColorR = 1, ShapeColorG = 0.502, ShapeColorB = 0,
                ShapeSparkle = false,
                -- - - - - - - - - - - - - - --
                UserShadowAlpha = 0.35,
                UserScale = 1,
                UserAlpha = 1,
                Strata = kDefaultStrata,
                UserOfsX = 0, UserOfsY = 0,
                -- - - - - - - - - - - - - - --
                FadeOut = false,
                UserShowOnlyInCombat = kNoChange,
                UserShowMouseLook = kNoChange,
            },
        },
    }
    ----------------________________________-----------------------------------
    kDefaultConfig["綠色螺旋"] = {
        MasterScale = 1,
        Layers = {
            [1] = {
                IsLayerEnabled = true,
                ShapeFileName = kMediaPath.."Swirl.tga",
                ModelID = 975870,  -- "Spots - Swirling, Purple & Orange"
                ShapeColorR = 0.502, ShapeColorG = 1, ShapeColorB = 0,
                ShapeSparkle = false,
                -- - - - - - - - - - - - - - --
                UserShadowAlpha = 0,
                UserScale = 0.8,
                UserAlpha = 1,
                Strata = kDefaultStrata,
                UserOfsX = 0.15, UserOfsY = -0.15,
                -- - - - - - - - - - - - - - --
                FadeOut = false,
                UserShowOnlyInCombat = kNoChange,
                UserShowMouseLook = kNoChange,
            },
        },
    }
    ----------------________________________-----------------------------------
    kDefaultConfig["大甜甜圈"] = {
        MasterScale = 1,
        Layers = {
            [1] = {
                IsLayerEnabled = true,
                ShapeFileName = kMediaPath.."Glow Reversed.tga",
                ModelID = 1417024,  -- "Sparkling, Rainbow"
                ShapeColorR = 1, ShapeColorG = 0.475, ShapeColorB = 0.906,
                ShapeSparkle = false,
                -- - - - - - - - - - - - - - --
                UserShadowAlpha = 0,
                UserScale = 1.17,
                UserAlpha = 1,
                Strata = kDefaultStrata,
                UserOfsX = 0, UserOfsY = 0,
                -- - - - - - - - - - - - - - --
                FadeOut = false,
                UserShowOnlyInCombat = kNoChange,
                UserShowMouseLook = kNoChange,
            },
        },
    }
    ----------------________________________-----------------------------------
    kDefaultConfig["火球"] = {
        MasterScale = 1,
        Layers = {
            [1] = {
                IsLayerEnabled = true,
                ShapeFileName = kShape_None,
                ModelID = 166159,  -- "Trail - Swirling, Firestrike"
                ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
                ShapeSparkle = false,
                -- - - - - - - - - - - - - - --
                UserShadowAlpha = 0.12,
                UserScale = 1.5,
                UserAlpha = 1,
                Strata = kDefaultStrata,
                UserOfsX = 0, UserOfsY = 0,
                -- - - - - - - - - - - - - - --
                FadeOut = false,
                UserShowOnlyInCombat = kNoChange,
                UserShowMouseLook = false,
            },
            [2] = {
                IsLayerEnabled = true,
                ShapeFileName = kShape_None,
                ModelID = 1513210,  -- "Trail - Solar Wrath"
                ShapeColorR = 1, ShapeColorG = 1, ShapeColorB = 1,
                ShapeSparkle = false,
                -- - - - - - - - - - - - - - --
                UserShadowAlpha = 0,
                UserScale = 1.5,
                UserAlpha = 1,
                Strata = kDefaultStrata,
                UserOfsX = 0, UserOfsY = 0,
                -- - - - - - - - - - - - - - --
                FadeOut = false,
                UserShowOnlyInCombat = kNoChange,
                UserShowMouseLook = true,
            },
        },
    }
end

kDefaultConfigKey = (isRetailWoW() and "我愛彩虹" or "閃電")  -- Used when the addon is first installed.
assert( kDefaultConfig[kDefaultConfigKey] )

kNewConfigKey = "(這裡開始)"  -- Used when user creates a new profile.
assert( kDefaultConfig[kNewConfigKey] )

-------------------------------------------------------------------------------
-- Copy default values into layers that don't have any data yet.
kDefaultConfigLayer = kDefaultConfig[kNewConfigKey].Layers[2]
for name, data in pairs(kDefaultConfig) do
    assert( data.Layers and data.Layers[1] and data.Layers[1].IsLayerEnabled, 'Structure error in default data for "' .. name .. '".' )
    for i = 1, kMaxLayers do
        if not data.Layers[i] then
            data.Layers[i] = CopyTable(kDefaultConfigLayer)
            data.Layers[i].IsLayerEnabled = false
            ----data.Layers[i].FadeOut = kNoChange
            ----data.Layers[i].UserShowOnlyInCombat = kNoChange
            ----data.Layers[i].UserShowMouseLook = kNoChange
        end
    end
end

--- End of File ---
