local _, BR = ...
local L = BR.L

-- ============================================================================
-- PET HELPERS MODULE
-- ============================================================================
-- Builds per-class lists of pet summon actions for expanded pet icons.
-- Each action has a spellID, icon, label, and sortOrder for display.

-- ============================================================================
-- TYPE DEFINITIONS
-- ============================================================================

---@class PetAction
---@field key string
---@field spellID number
---@field spellName string             -- Localized spell name for SecureActionButton casting
---@field icon number
---@field label string
---@field sortOrder number
---@field petFamily? string            -- Pet specialization (hunter only, e.g. "Ferocity")
---@field petSpecIcon? number          -- Spec ability icon texture (hunter only)
---@field petSpiritBeast? boolean      -- True if Spirit Beast family

---@class PetActionList : PetAction[]
---@field genericIndex? number  -- Preferred index for generic (collapsed) display mode

-- Hunter Call Pet spell IDs (Call Pet 1 through Call Pet 5)
local CALL_PET_SPELLS = { 883, 83242, 83243, 83244, 83245 }

-- Revive Pet spell ID
local REVIVE_PET = 982

-- Hunter pet spec → ability icon texture
local PET_SPEC_ICONS = {
    Cunning = 348567,
    Ferocity = 136224,
    Tenacity = 571585,
}

-- Warlock Summon Demon flyout ID
local SUMMON_DEMON_FLYOUT = 10

-- Warlock summon spell ID → short pet name (fallback: full spell name)
local WARLOCK_PET_NAMES = {
    [688] = "Imp",
    [697] = "Voidwalker",
    [691] = "Felhunter",
    [366222] = "Sayaad",
    [30146] = "Felguard",
}

-- Resolve Spirit Beast family name from Blizzard's creature family data (localized)
local SPIRIT_BEAST_FAMILY = (C_CreatureInfo.GetCreatureFamilyInfo(46) or {}).name or "Spirit Beast"

---Build hunter pet actions from stable info
---@return PetAction[]?
local function BuildHunterActions()
    -- MM Hunters don't use pets unless they have Unbreakable Bond
    if BR.StateHelpers.GetPlayerSpecId() == 254 and not IsPlayerSpell(1223323) then
        return nil
    end

    local canUseExotic = IsPlayerSpell(53270) -- Exotic Beasts (BM passive)
    local actions = {}
    local order = 0

    for slotIndex, spellID in ipairs(CALL_PET_SPELLS) do
        if IsPlayerSpell(spellID) then
            local info = C_StableInfo.GetStablePetInfo(slotIndex)
            if info and info.name and info.icon and (not info.isExotic or canUseExotic) then
                order = order + 1
                actions[#actions + 1] = {
                    key = "pet_action_" .. spellID,
                    spellID = spellID,
                    spellName = BR.GetSpellName(spellID),
                    icon = info.icon,
                    label = info.name,
                    sortOrder = order,
                    petFamily = info.specialization,
                    petSpecIcon = PET_SPEC_ICONS[info.specialization],
                    petSpiritBeast = info.familyName == SPIRIT_BEAST_FAMILY or nil,
                }
            end
        end
    end

    -- Add Revive Pet at the end if the player knows it and has callable pets
    if #actions > 0 and IsPlayerSpell(REVIVE_PET) then
        order = order + 1
        local icon = C_Spell.GetSpellTexture(REVIVE_PET)
        if icon then
            actions[#actions + 1] = {
                key = "pet_action_" .. REVIVE_PET,
                spellID = REVIVE_PET,
                spellName = BR.GetSpellName(REVIVE_PET),
                icon = icon,
                label = L["Label.RevivePet"],
                sortOrder = order,
            }
        end
    end

    return #actions > 0 and actions or nil
end

---Build warlock pet actions from the Summon Demon flyout
---@return PetAction[]?
local function BuildWarlockActions()
    local ok, _, _, numSlots, isKnown = pcall(GetFlyoutInfo, SUMMON_DEMON_FLYOUT)
    if not ok or not isKnown or not numSlots then
        return nil
    end

    local actions = {}
    local order = 0

    for i = 1, numSlots do
        local slotOk, spellID, _, slotIsKnown = pcall(GetFlyoutSlotInfo, SUMMON_DEMON_FLYOUT, i)
        if slotOk and spellID and slotIsKnown then
            local info = C_Spell.GetSpellInfo(spellID)
            if info then
                order = order + 1
                actions[#actions + 1] = {
                    key = "pet_action_" .. spellID,
                    spellID = spellID,
                    spellName = info.name,
                    icon = info.iconID,
                    label = WARLOCK_PET_NAMES[spellID] or info.name,
                    sortOrder = order,
                }
            end
        end
    end

    if #actions == 0 then
        return nil
    end

    -- Demonology: default to Felguard if known
    if BR.StateHelpers.GetPlayerSpecId() == 266 and IsPlayerSpell(30146) then
        actions.genericIndex = #actions
    end

    -- All specs: prefer Felhunter (interrupt) over first entry
    if not actions.genericIndex then
        for idx, action in ipairs(actions) do
            if action.spellID == 691 then -- Felhunter
                actions.genericIndex = idx
                break
            end
        end
    end

    return actions
end

-- Single-action pet spell ID → short pet name (fallback: full spell name)
local SINGLE_PET_NAMES = {
    [46584] = "Ghoul", -- Raise Dead (DK)
    [31687] = "Water Elemental", -- Summon Water Elemental (Mage)
}

---Build a single-action list for a given spell
---@param spellID number
---@return PetAction[]?
local function BuildSingleAction(spellID)
    if not IsPlayerSpell(spellID) then
        return nil
    end
    local info = C_Spell.GetSpellInfo(spellID)
    if not info then
        return nil
    end
    return {
        {
            key = "pet_action_" .. spellID,
            spellID = spellID,
            spellName = info.name,
            icon = info.iconID,
            label = SINGLE_PET_NAMES[spellID] or info.name,
            sortOrder = 1,
        },
    }
end

---Build a single Felguard summon action for "wrong pet" click-to-cast
---@return PetAction[]?
local function BuildFelguardAction()
    local spellID = 30146
    if not IsPlayerSpell(spellID) then
        return nil
    end
    local info = C_Spell.GetSpellInfo(spellID)
    if not info then
        return nil
    end
    return {
        {
            key = "pet_action_" .. spellID,
            spellID = spellID,
            spellName = info.name,
            icon = info.iconID,
            label = L["Label.Felguard"],
            sortOrder = 1,
        },
    }
end

-- Cached pet actions (rebuilt on spec/talent/stable changes, not every refresh)
local cachedActions = nil
local cacheValid = false

-- Maps pet class to its action-list builder function
local CLASS_PET_BUILDERS = {
    HUNTER = BuildHunterActions,
    WARLOCK = BuildWarlockActions,
    DEATHKNIGHT = function()
        return BuildSingleAction(46584)
    end, -- Raise Dead
    MAGE = function()
        return BuildSingleAction(31687)
    end, -- Summon Water Elemental
}

---Build and cache the list of pet summon actions for the given class.
---Returns cached result on subsequent calls until invalidated.
---@param class ClassName
---@return PetActionList?
local function GetPetActions(class)
    if cacheValid then
        return cachedActions
    end

    local builder = CLASS_PET_BUILDERS[class]
    cachedActions = builder and builder() or nil

    cacheValid = true
    return cachedActions
end

---Invalidate cached pet actions (call on spec/talent/stable changes).
local function InvalidatePetActions()
    cacheValid = false
    cachedActions = nil
end

-- Export
BR.PetHelpers = {
    REVIVE_PET_ID = REVIVE_PET,
    GetPetActions = GetPetActions,
    GetFelguardAction = BuildFelguardAction,
    InvalidatePetActions = InvalidatePetActions,
}
