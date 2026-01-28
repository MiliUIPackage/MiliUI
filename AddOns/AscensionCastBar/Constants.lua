-------------------------------------------------------------------------------
-- Project: AscensionCastBar
-- Author: Aka-DoctorCode 
-- File: Constants.lua
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

AscensionCastBar.BAR_DEFAULT_FONT_PATH = "Interface\\AddOns\\AscensionCastBar\\COLLEGIA.ttf"

AscensionCastBar.CHANNEL_TICKS = {
    -- Warrior Spells
    [436358] = 3, -- Demolish
    -- Warlock Spells
    [234153] = 5, -- Drain Life
    [198590] = 5, -- Drain Soul
    [196447] = function() -- Channel Demonfire
        return IsPlayerSpell(387166) and 17 or 15
    end,
    -- Mage Spells
    [205021] = 8, -- Ray of Frost
    [12051] = 10, -- Evocation
    [5143] = function() -- Arcane Missiles
        return IsPlayerSpell(236628) and 7 or 5 -- Amplification
    end,
    -- Evoker Spells
    [356995] = function() -- Disintegrate
        return IsPlayerSpell(1219723) and 5 or 4 -- Azure Celerity
    end,
    -- Druid Spells
    [740] = 7, -- Tranquility
    [391528] = function() -- Convoke the Spirits
        local hasReducedTicks = IsPlayerSpell(393991) -- Elune's Guidance 
            or IsPlayerSpell(391548) -- Ashamane's Guidance
            or IsPlayerSpell(393414) -- Ursoc's Guidance
            or IsPlayerSpell(393371) -- Cenarius' Guidance
        if hasReducedTicks then
            return 12
        end
        return 16
    end,
    -- Demon Hunter
    [473728] = 22, -- Void Ray
    [198013] = 13, -- Eye Beam
    [212084] = 12, -- Fel Devastation
    -- Monk
    [113656] = 5, -- Fists of Fury
    [115175] = 12, -- Soothing Mist
    [117952] = 5, -- Crackling Jade Lightning
    [322729 or 101546] = 4, -- Spinning Crane Kick
    [443028] = 5, -- Celestial Conduit Mistweaver
    [1238989] = 5, -- Celestial Conduit Windwalker
    [115294] = function(duration) -- Mana Tea
        local UnitAura = _G.C_UnitAura
        if UnitAura then
            local auraData = UnitAura.GetAuraDataBySpellIdentifier("player", 115867)
            if auraData and auraData.applications and auraData.applications > 0 then
                return auraData.applications
            end
        end

        if duration and duration > 0 then
            local haste = _G.UnitSpellHaste("player") or 0
            local hasteMult = 1 + (haste / 100)
            local estimatedStacks = (duration * hasteMult) / 0.5
            return math.floor(estimatedStacks + 0.5)
        end
        return 1
    end,
    -- Priest Spells
    [15407] = 6, -- Mind Flay
    [391403] = 4, -- Mind Flay: Insanity
    [263165] = 5, -- Void Torrent
    [64843] = 5, -- Divine Hymn
    [47540] = function() --Penance
        return IsPlayerSpell(193134) and 4 or 3 -- Guiding Light
    end,
    -- Hunter Spells
    [257044] = function() -- Rapid Fire
        return IsPlayerSpell(459794) and 10 or 7 -- Quick Draw
    end,
    [1261193] = 4, -- Boomstick
    }

-- Hunter
--     Rapid Fire - 257044
--     Barrage - 120360


AscensionCastBar.ANIMATION_STYLE_PARAMS = {
    Comet = {
        tailOffset = -14.68,
        headLengthOffset = -23,
        tailLength = 200,
        tails = 4,
    },
    Orb = {
        rotationSpeed = 8,
        radiusMultiplier = 0.4,
        glowPulse = 1.0,
        tails = 4,
    },
    Pulse = {
        maxScale = 2.5,
        rippleCycle = 1,
        fadeSpeed = 1.0,
        tails = 4,
    },
    Starfall = {
        fallSpeed = 2.5,
        swayAmount = 8,
        particleSpeed = 3.8,
        tails = 4,
    },
    Flux = {
        jitterY = 3.5,
        jitterX = 2.5,
        driftMultiplier = 0.05,
        tails = 4,
    },
    Helix = {
        driftMultiplier = 0.1,
        amplitude = 0.4,
        waveSpeed = 8,
        tails = 4,
    },
    Wave = {
        waveCount = 3,
        waveSpeed = 0.4,
        amplitude = 0.05,
        waveWidth = 0.25,
        tails = 0, -- Wave no usa tails tradicionales
    },
    Glitch = {
        glitchChance = 0.1,
        maxOffset = 5,
        colorIntensity = 0.3,
        tails = 0,
    },
    Lightning = {
        lightningChance = 0.3,
        segmentCount = 3,
        tailCount = 0, -- Usa segments en lugar de tails
    }
}
