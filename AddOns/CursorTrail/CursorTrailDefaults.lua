--[[---------------------------------------------------------------------------
    File:   CursorTrailDefaults.lua
    Desc:   This file contains default settings for this addon.
-----------------------------------------------------------------------------]]

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Aliases to Globals                                ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

local Globals = _G
local _  -- Prevent tainting global _ .
----local DEFAULTS = _G.DEFAULTS  -- Blizzard's localized string: "Defaults"
local print = _G.print

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

kDefaultModelID = 166498  -- "Electric, Blue & Long"
kDefaultStrata = "HIGH"

kDefaultConfigKey = "Electric"  -- Max name length is kProfileNameMaxLetters!
kDefaultConfig =
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
kDefaultConfig[kDefaultConfigKey] = {
    ShapeFileName = nil,
    ModelID = kDefaultModelID,
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
    --UserShowOnlyInCombat = false,
    --UserShowMouseLook = false,
}
----------------________________________-----------------------------------
kDefaultConfig["Electric Large"] = {
    ShapeFileName = nil,
    ModelID = kDefaultModelID,
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
    --UserShowOnlyInCombat = false,
    --UserShowMouseLook = false,
}
----------------________________________-----------------------------------
kDefaultConfig["Electric Small"] = {
    ShapeFileName = nil,
    ModelID = kDefaultModelID,
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
    --UserShowOnlyInCombat = false,
    --UserShowMouseLook = false,
}
----------------________________________-----------------------------------
kDefaultConfig["Electric Huge"] = {
    ShapeFileName = nil,
    ModelID = kDefaultModelID,
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
    --UserShowOnlyInCombat = false,
    --UserShowMouseLook = false,
}
----------------________________________-----------------------------------
kDefaultConfig["Glow Purple"] = {
    ShapeFileName = nil,
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
    --UserShowOnlyInCombat = false,
    --UserShowMouseLook = false,
}
----------------________________________-----------------------------------
kDefaultConfig["Glow Purple Fade"] = {
    ShapeFileName = nil,
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
    --UserShowOnlyInCombat = false,
    --UserShowMouseLook = false,
}
----------------________________________-----------------------------------
kDefaultConfig["Glow Purple Fade 2"] = {
    ShapeFileName = nil,
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
    --UserShowOnlyInCombat = false,
    --UserShowMouseLook = false,
}
----------------________________________-----------------------------------
kDefaultConfig["Glow Soft Fade"] = {
    ShapeFileName = nil,
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
    --UserShowOnlyInCombat = false,
    --UserShowMouseLook = false,
}
----------------________________________-----------------------------------
kDefaultConfig["Glowing Star, Red"] = {
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
    --UserShowOnlyInCombat = false,
    --UserShowMouseLook = false,
}
----------------________________________-----------------------------------
kDefaultConfig["Ring & Electric Trail"] = {
    ShapeFileName = kMediaPath.."Ring 2.tga",
    ModelID = kDefaultModelID,
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
    --UserShowOnlyInCombat = false,
    --UserShowMouseLook = false,
}
----------------________________________-----------------------------------
kDefaultConfig["Ring Sparkle"] = {
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
    --UserShowOnlyInCombat = false,
    --UserShowMouseLook = false,
}
----------------________________________-----------------------------------
kDefaultConfig["Star Glow Green"] = {
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
    --UserShowOnlyInCombat = true,
    --UserShowMouseLook = false,
}
----------------________________________-----------------------------------
kDefaultConfig["Cross Yellow Pulse"] = {
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
    --UserShowOnlyInCombat = true,
    --UserShowMouseLook = false,
}
----------------________________________-----------------------------------
kDefaultConfig["Cross Glow Shadow"] = {
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
    --UserShowOnlyInCombat = false,
    --UserShowMouseLook = true,
}
----------------________________________-----------------------------------
kDefaultConfig["Ring & Bones"] = {
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
    --UserShowOnlyInCombat = true,
    --UserShowMouseLook = true,
}

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       RETAIL & WRATH WoW                                ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

if isRetailWoW() or isWrathWoW() then
    ----------------________________________-----------------------------------
    kDefaultConfig["Soul Skull Trail"] = {
        ShapeFileName = nil,
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
        --UserShowOnlyInCombat = false,
        --UserShowMouseLook = false,
    }
    ----------------________________________-----------------------------------
    kDefaultConfig["Ring & Soul Skull"] = {
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
        --UserShowOnlyInCombat = false,
        --UserShowMouseLook = false,
    }
    ----------------________________________-----------------------------------
    kDefaultConfig["Small Blue Green"] = {
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
        --UserShowOnlyInCombat = false,
        --UserShowMouseLook = false,
    }
    ----------------________________________-----------------------------------
    kDefaultConfig["Sphere Orange Swirl"] = {
        ShapeFileName = nil,
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
        --UserShowOnlyInCombat = true,
        --UserShowMouseLook = false,
    }
end

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       RETAIL WoW                                        ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

if isRetailWoW() then
    ----------------________________________-----------------------------------
    kDefaultConfig["Ring & Rainbow"] = {
        ShapeFileName = kMediaPath.."Ring 3.tga",
        ModelID = 1417024,  -- "Sparkling, Rainbow"
        ShapeColorR = 1, ShapeColorG = 0.882, ShapeColorB = 0.882,
        ShapeSparkle = false,
        -- - - - - - - - - - - - - - --
        UserShadowAlpha = 0.99,
        UserScale = 0.65,
        UserAlpha = 1,
        Strata = kDefaultStrata,
        UserOfsX = 0, UserOfsY = 0,
        -- - - - - - - - - - - - - - --
        FadeOut = false,
        --UserShowOnlyInCombat = true,
        --UserShowMouseLook = false,
    }
    ----------------________________________-----------------------------------
    kDefaultConfig["Star Flame"] = {
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
        --UserShowOnlyInCombat = false,
        --UserShowMouseLook = false,
    }
    ----------------________________________-----------------------------------
    kDefaultConfig["Swirly Green"] = {
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
        --UserShowOnlyInCombat = false,
        --UserShowMouseLook = true,
    }
    ----------------________________________-----------------------------------
    kDefaultConfig["Big Donut"] = {
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
        --UserShowOnlyInCombat = true,
        --UserShowMouseLook = false,
    }
end

--- End of File ---
