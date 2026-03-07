local _, BR = ...

-- Lua stdlib locals
local min = math.min

-- ============================================================================
-- BUFF DATA TABLES
-- ============================================================================
-- This file contains all buff definition tables.
-- Loaded after Core.lua so BR namespace is available.

-- ============================================================================
-- TYPE DEFINITIONS
-- ============================================================================

---@class RaidBuff
---@field spellID SpellID
---@field castSpellID? number Spell ID used for click-to-cast when different from the buff aura IDs
---@field key string
---@field name string
---@field class ClassName
---@field levelRequired? number

---@class PresenceBuff
---@field spellID SpellID
---@field key string
---@field name string
---@field class ClassName
---@field levelRequired? number
---@field missingText string
---@field groupId? string
---@field excludeSpellID? number
---@field displayIcon? number
---@field infoTooltip? string
---@field noExpirationGlow? boolean
---@field readyCheckOnly? boolean Only show during ready checks
---@field castOnOthers? boolean Buff exists on the target, not the caster (e.g., Soulstone)

---@class TargetedBuff
---@field spellID SpellID
---@field key string
---@field name string
---@field class ClassName
---@field missingText string
---@field groupId? string
---@field beneficiaryRole? RoleType
---@field excludeSpellID? number
---@field displayIcon? number
---@field requireSpecId? number
---@field infoTooltip? string
---@field clickMacro? fun(spellID: number): string
---@field casterBuffId? number Check this buff on the caster instead of scanning group

---@class SelfBuff
---@field spellID? SpellID
---@field key string
---@field name string
---@field class? ClassName
---@field missingText string
---@field groupId? string
---@field enchantID? number
---@field requiresBuffWithEnchant? boolean -- When true, require both enchant AND buff to be present (for Paladin Rites)
---@field castSpellID? number           -- Spell ID used for click-to-cast when different from spellID
---@field clickMacro? fun(spellID: number): string -- Macro text override for click-to-cast, receives castable spell ID
---@field buffIdOverride? number|number[]
---@field requireSpecId? number        -- Only show if player's current spec matches (WoW spec ID)
---@field requiresSpellID? number
---@field excludeSpellID? number
---@field displayIcon? number
---@field displaySpells? SpellID Spell IDs to show icons for in Options checkbox (subset of spellID)
---@field iconByRole? table<RoleType, number>
---@field infoTooltip? string
---@field customCheck? fun(): boolean?

---@class ConsumableBuff
---@field spellID? SpellID
---@field key string
---@field name string
---@field missingText string
---@field groupId? string
---@field checkWeaponEnchant? boolean Check if any weapon enchant exists (oils, stones, imbues)
---@field checkWeaponEnchantOH? boolean Check if off-hand weapon enchant exists
---@field excludeIfSpellKnown? number[] Don't show if player knows any of these spells
---@field buffIconID? number Check for any buff with this icon ID (e.g., 136000 for food)
---@field displaySpells? SpellID Spell IDs to show icons for in UI (subset of spellID)
---@field displayIcon? number|number[] Icon texture ID(s) to use instead of spell icon
---@field itemID? number|number[] Check if player has this item in inventory
---@field readyCheckOnly? boolean Only show during ready checks
---@field infoTooltip? string Tooltip text shown on hover (pipe-separated: title|description)
---@field visibilityCondition? fun(): boolean Custom function that gates visibility (return false to hide)

---@class BuffGroup
---@field displayName string

---@class CustomBuff
---@field spellID SpellID
---@field key string
---@field name string
---@field missingText? string
---@field class? ClassName
---@field requireSpecId? number
---@field requireSpellKnown? boolean -- Only show if player knows at least one of the tracked spells
---@field showWhenPresent? boolean  -- Show icon when buff IS on player (default: show when missing)
---@field glowMode? "whenGlowing"|"whenNotGlowing"|"disabled"  -- Action bar glow fallback mode: nil/"whenGlowing" = detect when glowing (default), "whenNotGlowing" = detect when NOT glowing, "disabled" = don't track glow
---@field castSpellID? number       -- Spell to cast on click (separate from tracked aura)
---@field castItemID? number        -- Item to use on click
---@field castMacro? string         -- Raw macro text for click action
---@field requireItemID? number    -- Only show if this item is equipped or in bags
---@field loadConditions? LoadConditions  -- Per-buff content visibility (nil = show everywhere)

---Check if the player is inside a delve (difficultyID 208)
---@return boolean
local function IsInDelve()
    local difficultyID = select(3, GetInstanceInfo())
    return difficultyID == 208
end
BR.IsInDelve = IsInDelve

---Check if the player's pet is on passive stance
---@return boolean? true if pet exists and is on passive, nil otherwise
local function IsPetOnPassive()
    if not UnitExists("pet") then
        return nil
    end
    for i = 1, NUM_PET_ACTION_SLOTS do
        local name, _, _, isActive = GetPetActionInfo(i)
        if name == "PET_MODE_PASSIVE" and isActive then
            return true
        end
    end
    return nil
end

---Build a clickMacro function for targeted buffs that remembers the last target (last target re-casting).
---Macro priority: last target > mouseover > current target > no target (self-cast or error).
---@param buffKey string The buff's key, used to look up the last target
---@return fun(spellID: number): string
local function TargetedClickMacro(buffKey)
    return function(spellID)
        local name = C_Spell.GetSpellName(spellID)
        local lastTarget = BR.StateHelpers and BR.StateHelpers.GetLastTarget(buffKey)
        if lastTarget then
            return "/cast [@" .. lastTarget .. ",help,nodead][@mouseover,help,nodead][@target,help,nodead][] " .. name
        end
        return "/cast [@mouseover,help,nodead][@target,help,nodead][] " .. name
    end
end

---@type table<string, RaidBuff[]|PresenceBuff[]|TargetedBuff[]|SelfBuff[]|ConsumableBuff[]|CustomBuff[]>
BR.BUFF_TABLES = {
    ---@type RaidBuff[]
    raid = {
        { spellID = { 1459, 432778 }, key = "intellect", name = "祕法智力", class = "MAGE", levelRequired = 8 }, -- 432778 = NPC version
        { spellID = 6673, key = "attackPower", name = "戰鬥怒吼", class = "WARRIOR", levelRequired = 10 },
        {
            spellID = {
                381732,
                381741,
                381746,
                381748,
                381749,
                381750,
                381751,
                381752,
                381753,
                381754,
                381756,
                381757,
                381758,
            },
            castSpellID = 364342,
            key = "bronze",
            name = "青銅龍的祝福",
            class = "EVOKER",
            levelRequired = 30,
        },
        {
            spellID = { 1126, 432661 },
            key = "versatility",
            name = "野性印記",
            class = "DRUID",
            levelRequired = 10,
        }, -- 432661 = NPC version
        { spellID = 21562, key = "stamina", name = "真言術：韌", class = "PRIEST", levelRequired = 10 },
        { spellID = 462854, key = "skyfury", name = "天怒", class = "SHAMAN", levelRequired = 16 },
    },
    ---@type PresenceBuff[]
    presence = {
        {
            spellID = { 381637, 5761 },
            key = "atrophicNumbingPoison",
            name = "萎縮/麻痺毒藥",
            class = "ROGUE",
            levelRequired = 80,
            missingText = "沒有\n毒藥",
        },
        {
            spellID = 465,
            key = "devotionAura",
            name = "虔誠光環",
            class = "PALADIN",
            levelRequired = 10,
            missingText = "沒有\n光環",
        },
        {
            spellID = 20707,
            key = "soulstone",
            name = "靈魂石",
            class = "WARLOCK",
            levelRequired = 13,
            missingText = "沒有\n魂石",
            readyCheckOnly = true,
            castOnOthers = true,
            noExpirationGlow = true,
        },
    },
    ---@type TargetedBuff[]
    targeted = {
        -- Beacons (alphabetical: Faith, Light)
        {
            spellID = 156910,
            key = "beaconOfFaith",
            name = "虔信信標",
            class = "PALADIN",
            missingText = "沒有\n信標",
            groupId = "beacons",
            requireSpecId = 65, -- Holy only
            clickMacro = TargetedClickMacro("beaconOfFaith"),
        },
        {
            spellID = 53563,
            key = "beaconOfLight",
            name = "聖光信標",
            class = "PALADIN",
            missingText = "沒有\n聖光",
            groupId = "beacons",
            requireSpecId = 65, -- Holy only
            excludeSpellID = 200025, -- Hide when Beacon of Virtue is known
            displayIcon = 236247, -- Force original icon (talents replace the texture)
            clickMacro = TargetedClickMacro("beaconOfLight"),
        },
        {
            spellID = 974,
            key = "earthShieldOthers",
            name = "大地之盾",
            class = "SHAMAN",
            missingText = "沒有\n大地盾",
            infoTooltip = "可能會顯示額外的圖示|在你施放這個之前，你可能會看到這個和水/閃電之盾提醒。我不知道你是想要自己的大地之盾，還是盟友的大地之盾+自己的水/閃電之盾。",
            clickMacro = TargetedClickMacro("earthShieldOthers"),
        },
        {
            spellID = 369459,
            key = "sourceOfMagic",
            name = "魔力之源",
            class = "EVOKER",
            beneficiaryRole = "HEALER",
            missingText = "沒有\n魔源",
            clickMacro = TargetedClickMacro("sourceOfMagic"),
        },
        {
            spellID = 360827,
            key = "blisteringScales",
            name = "極熾鱗片",
            class = "EVOKER",
            beneficiaryRole = "TANK",
            missingText = "沒有\n鱗片",
            requireSpecId = 1473, -- Augmentation
            requiresSpellID = 360827,
            clickMacro = TargetedClickMacro("blisteringScales"),
        },
        {
            spellID = 474750,
            casterBuffId = 474754, -- Check this combat-whitelisted buff on the caster instead of scanning group
            key = "symbioticRelationship",
            name = "共生關係",
            class = "DRUID",
            missingText = "沒有\n共生",
            clickMacro = TargetedClickMacro("symbioticRelationship"),
        },
    },
    ---@type SelfBuff[]
    self = {
        -- Mage Arcane Familiar
        {
            spellID = 205022,
            buffIdOverride = 210126,
            castSpellID = 1459,
            key = "arcaneFamiliar",
            name = "秘法魔寵",
            class = "MAGE",
            missingText = "沒有\n魔寵",
        },
        -- Warlock Grimoire of Sacrifice
        {
            spellID = 108503,
            buffIdOverride = 196099,
            key = "grimoireOfSacrifice",
            name = "犧牲魔典",
            class = "WARLOCK",
            missingText = "沒有\n魔典",
        },
        -- Paladin weapon rites (alphabetical: Adjuration, Sanctification)
        -- NOTE: Due to a Blizzard bug, when changing talents the buff drops but enchant remains.
        -- The effect doesn't work without the buff, so we check for BOTH enchant AND buff.
        {
            spellID = 433583,
            key = "riteOfAdjuration",
            name = "裁決儀式",
            class = "PALADIN",
            missingText = "沒有\n儀式",
            enchantID = 7144,
            buffIdOverride = 433584, -- Actual buff ID on player
            requiresBuffWithEnchant = true,
            clickMacro = function(spellID)
                return "/cast " .. C_Spell.GetSpellName(spellID) .. "\n/use 16"
            end,
            groupId = "paladinRites",
        },
        {
            spellID = 433568,
            key = "riteOfSanctification",
            name = "聖化儀式",
            class = "PALADIN",
            missingText = "沒有\n儀式",
            enchantID = 7143,
            buffIdOverride = 433550, -- Actual buff ID on player
            requiresBuffWithEnchant = true,
            clickMacro = function(spellID)
                return "/cast " .. C_Spell.GetSpellName(spellID) .. "\n/use 16"
            end,
            groupId = "paladinRites",
        },
        -- Rogue poisons: lethal (Instant, Wound, Deadly, Amplifying) and non-lethal (Numbing, Atrophic, Crippling)
        -- With Dragon-Tempered Blades (381801): need 2 lethal + 2 non-lethal
        -- Without talent: need 1 lethal + 1 non-lethal
        {
            displayIcon = 136242, -- Deadly Poison
            castSpellID = 315584, -- Instant Poison (baseline, ensures click-to-cast overlay is created)
            key = "roguePoisons",
            name = "盜賊毒藥",
            class = "ROGUE",
            missingText = "沒有\n自身\n毒藥",
            customCheck = function()
                local lethalPoisons = { 315584, 8679, 2823, 381664 } -- Instant, Wound, Deadly, Amplifying
                local nonLethalPoisons = { 5761, 381637, 3408 } -- Numbing, Atrophic, Crippling

                -- Count known and active poisons in each category
                local knownLethal, knownNonLethal = 0, 0
                local activeLethal, activeNonLethal = 0, 0

                for _, id in ipairs(lethalPoisons) do
                    if IsPlayerSpell(id) then
                        knownLethal = knownLethal + 1
                    end
                    local auraData
                    pcall(function()
                        auraData = C_UnitAuras.GetUnitAuraBySpellID("player", id)
                    end)
                    if auraData then
                        activeLethal = activeLethal + 1
                    end
                end

                for _, id in ipairs(nonLethalPoisons) do
                    if IsPlayerSpell(id) then
                        knownNonLethal = knownNonLethal + 1
                    end
                    local auraData
                    pcall(function()
                        auraData = C_UnitAuras.GetUnitAuraBySpellID("player", id)
                    end)
                    if auraData then
                        activeNonLethal = activeNonLethal + 1
                    end
                end

                -- Don't show if the player hasn't learned any poisons yet (e.g. low-level rogue)
                if knownLethal == 0 and knownNonLethal == 0 then
                    return nil
                end

                -- Dragon-Tempered Blades (381801): can have 2 of each
                local hasDragonTemperedBlades = IsPlayerSpell(381801)

                -- Only require as many as the player actually knows
                local requiredLethal = min(knownLethal, hasDragonTemperedBlades and 2 or 1)
                local requiredNonLethal = min(knownNonLethal, hasDragonTemperedBlades and 2 or 1)

                return activeLethal < requiredLethal or activeNonLethal < requiredNonLethal
            end,
            clickMacro = function()
                -- Priority: non-lethal (Atrophic > Numbing > Crippling), then lethal (Amplifying > Deadly > Instant > Wound)
                -- Balance: apply to whichever category has fewer active, prefer non-lethal when tied
                local nonLethalPriority = { 381637, 5761, 3408 } -- Atrophic, Numbing, Crippling
                local lethalPriority = { 381664, 2823, 315584, 8679 } -- Amplifying, Deadly, Instant, Wound

                local function countActiveAndFindMissing(poisons)
                    local active, missing = 0, nil
                    for _, id in ipairs(poisons) do
                        if IsPlayerSpell(id) then
                            local auraData
                            pcall(function()
                                auraData = C_UnitAuras.GetUnitAuraBySpellID("player", id)
                            end)
                            if auraData then
                                active = active + 1
                            elseif not missing then
                                missing = id
                            end
                        end
                    end
                    return active, missing
                end

                local activeNL, missingNL = countActiveAndFindMissing(nonLethalPriority)
                local activeL, missingL = countActiveAndFindMissing(lethalPriority)

                local castID = nil
                if missingNL and activeNL <= activeL then
                    castID = missingNL
                elseif missingL then
                    castID = missingL
                elseif missingNL then
                    castID = missingNL
                end

                if castID then
                    return "/cast " .. C_Spell.GetSpellName(castID)
                end
                return ""
            end,
        },
        -- Voidform (194249) replaces Shadowform temporarily
        {
            spellID = 232698,
            key = "shadowform",
            name = "暗影形態",
            class = "PRIEST",
            missingText = "沒有\n型態",
            buffIdOverride = { 232698, 194249 },
            noExpirationGlow = true, -- Voidform (short duration) replaces Shadowform; don't warn
        },
        -- Shaman weapon imbues (alphabetical: Earthliving, Flametongue, Windfury)
        {
            spellID = 382021,
            key = "earthlivingWeapon",
            name = "大地生命武器",
            class = "SHAMAN",
            missingText = "沒有\n大地生命",
            enchantID = 6498,
            groupId = "shamanImbues",
        },
        {
            spellID = 318038,
            key = "flametongueWeapon",
            name = "火舌武器",
            class = "SHAMAN",
            missingText = "沒有\n火舌",
            enchantID = 5400,
            groupId = "shamanImbues",
        },
        {
            spellID = 33757,
            key = "windfuryWeapon",
            name = "風怒武器",
            class = "SHAMAN",
            missingText = "沒有\n風怒",
            enchantID = 5401,
            groupId = "shamanImbues",
        },
        -- Icon fields:
        --   displayIcon     = Texture ID(s). Primary icon for Display frame + Options checkbox.
        --   displaySpells   = Spell ID(s). Icons for Options checkbox only (subset of spellID).
        --   iconByRole      = Role→SpellID. Dynamic Display frame icon based on player role.
        -- Priority: displayIcon > displaySpells > spellID[1]
        --
        -- Shaman shields (alphabetical: Earth, Lightning, Water)
        -- With Elemental Orbit: need Earth Shield (passive self-buff)
        {
            spellID = 974, -- Earth Shield spell (for icon and spell check)
            buffIdOverride = 383648, -- The passive buff to check for
            key = "earthShieldSelfEO",
            name = "大地之盾 (自身)",
            class = "SHAMAN",
            missingText = "沒有\n自身地盾",
            requiresSpellID = 383010,
            groupId = "shamanShields",
            displaySpells = 974, -- Earth Shield icon for group checkbox
        },
        -- With Elemental Orbit: need Lightning Shield or Water Shield
        {
            spellID = { 192106, 52127 },
            key = "waterLightningShieldEO",
            name = "水/閃電之盾",
            class = "SHAMAN",
            missingText = "沒有\n盾",
            requiresSpellID = 383010,
            groupId = "shamanShields",
            displaySpells = 192106, -- Lightning Shield icon for group checkbox
            iconByRole = { HEALER = 52127, DAMAGER = 192106, TANK = 192106 },
        },
        -- Without Elemental Orbit: need either Earth Shield, Lightning Shield, or Water Shield on self
        {
            spellID = { 974, 192106, 52127 },
            key = "shamanShieldBasic",
            name = "盾 (無天賦)",
            class = "SHAMAN",
            missingText = "沒有\n盾",
            excludeSpellID = 383010,
            groupId = "shamanShields",
            displaySpells = 52127, -- Water Shield icon for group checkbox
            iconByRole = { HEALER = 52127, DAMAGER = 192106, TANK = 192106 },
        },
    },
    ---@type SelfBuff[]
    pet = {
        -- Pet reminders (alphabetical: Frost Mage, Hunter, Passive, Unholy DK, Warlock)
        {
            displayIcon = 135862, -- Summon Water Elemental
            key = "frostMagePet",
            name = "水元素",
            class = "MAGE",
            missingText = "沒有\n寵物",
            requireSpecId = 64, -- Frost
            requiresSpellID = 31687,
            groupId = "pets",
            customCheck = function()
                return not UnitExists("pet")
            end,
        },
        {
            key = "hunterPet",
            name = "獵人寵物",
            class = "HUNTER",
            missingText = "沒有\n寵物",
            displayIcon = 132161,
            groupId = "pets",
            customCheck = function()
                -- MM Hunters don't use pets unless they have Unbreakable Bond
                if BR.StateHelpers.GetPlayerSpecId() == 254 and not IsPlayerSpell(1223323) then
                    return nil
                end
                return not UnitExists("pet") or UnitIsDead("pet") or nil
            end,
        },
        {
            key = "petPassive",
            name = "寵物被動",
            -- No class: applies to any class with a pet
            missingText = "被動\n寵物",
            displayIcon = 132311,
            customCheck = IsPetOnPassive,
        },
        {
            displayIcon = 1100170, -- Raise Dead
            key = "unholyPet",
            name = "穢邪食屍鬼",
            class = "DEATHKNIGHT",
            missingText = "沒有\n寵物",
            requireSpecId = 252, -- Unholy
            groupId = "pets",
            customCheck = function()
                return not UnitExists("pet")
            end,
        },
        {
            key = "warlockPet",
            name = "術士惡魔",
            class = "WARLOCK",
            missingText = "沒有\n寵物",
            displayIcon = 136082, -- Summon Demon flyout icon
            excludeSpellID = 108503, -- Grimoire of Sacrifice: pet intentionally sacrificed
            groupId = "pets",
            customCheck = function()
                return not UnitExists("pet")
            end,
        },
    },
    ---@type CustomBuff[]
    custom = {},
    ---@type ConsumableBuff[]
    consumable = {
        -- Augment Rune (The War Within + Midnight)
        {
            spellID = {
                1234969, -- Ethereal Augment Rune (TWW permanent) - highest priority
                1242347, -- Soulgorged Augment Rune (TWW raid drop) - persists through death
                453250, -- Crystallized Augment Rune (TWW) - single use
                393438, -- Draconic Augment Rune (Dragonflight) - legacy
                1264426, -- Void-Touched Augment Rune (Midnight)
                347901, -- Veiled Augment Rune (Shadowlands) - legacy
            },
            displaySpells = { 1234969, 1242347, 453250, 393438 }, -- Show rune icons in priority order
            key = "rune",
            name = "符文",
            missingText = "沒有\n符文",
            groupId = "rune",
        },
        -- Flasks (The War Within + Midnight)
        {
            spellID = {
                -- The War Within
                432021, -- Flask of Alchemical Chaos
                431971, -- Flask of Tempered Aggression
                431972, -- Flask of Tempered Swiftness
                431973, -- Flask of Tempered Versatility
                431974, -- Flask of Tempered Mastery
                -- Midnight
                1235057, -- Flask of Thalassian Resistance (Versatility)
                1235108, -- Flask of the Magisters (Mastery)
                1235110, -- Flask of the Blood Knights (Haste)
                1235111, -- Flask of the Shattered Sun (Critical Strike)
            },
            displaySpells = {
                -- Show only TWW flask icons in UI
                432021, -- Flask of Alchemical Chaos
                431971, -- Flask of Tempered Aggression
                431972, -- Flask of Tempered Swiftness
                431973, -- Flask of Tempered Versatility
                431974, -- Flask of Tempered Mastery
            },
            key = "flask",
            name = "精鍊",
            missingText = "沒有\n精鍊",
            groupId = "flask",
        },
        -- Food (all expansions - detected by icon ID)
        {
            buffIconID = 136000, -- All food buffs use this icon
            key = "food",
            name = "食物",
            missingText = "沒有\n食物",
            groupId = "food",
            displayIcon = 136000,
        },
        -- Delve Food (only when inside a delve with Brann or Valeera)
        {
            spellID = 442522,
            key = "delveFood",
            name = "探究食物",
            missingText = "沒有\n食物",
            groupId = "delveFood",
            noExpirationGlow = true, -- 10-min duration makes standard thresholds meaningless
            infoTooltip = "只限探究|只有當布萊恩或瓦莉拉在你的隊伍中時才會在探索內顯示。\n\n此增益效果的過期發光被禁用，因為其短暫的10分鐘持續時間會導致它始終發光。",
            visibilityCondition = BR.IsInDelve,
        },
        -- Weapon Buffs (oils, stones - but not for classes with imbues)
        {
            checkWeaponEnchant = true, -- Check if any weapon enchant exists
            key = "weaponBuff",
            name = "武器",
            missingText = "沒有\n武器\n增益",
            groupId = "weaponBuff",
            displayIcon = { 609892, 3622195, 3622196 }, -- Oil, Whetstone, Weightstone/Razorstone
            excludeIfSpellKnown = {
                -- Shaman imbues
                382021, -- Earthliving Weapon
                318038, -- Flametongue Weapon
                33757, -- Windfury Weapon
                -- Paladin rites
                433583, -- Rite of Adjuration
                433568, -- Rite of Sanctification
            },
        },
        -- Weapon Buff (Off-Hand) - only shown when off-hand slot has a weapon
        {
            checkWeaponEnchantOH = true,
            key = "weaponBuffOH",
            name = "武器(副手)",
            missingText = "沒有\n武器\n增益",
            groupId = "weaponBuff",
            displayIcon = { 609892, 3622195, 3622196 }, -- Oil, Whetstone, Weightstone/Razorstone
            excludeIfSpellKnown = {
                -- Shaman imbues
                382021, -- Earthliving Weapon
                318038, -- Flametongue Weapon
                33757, -- Windfury Weapon
                -- Paladin rites
                433583, -- Rite of Adjuration
                433568, -- Rite of Sanctification
            },
            visibilityCondition = function()
                return BR.BuffState.HasOffHandWeapon()
            end,
        },
        -- Healthstone (ready check only - checks inventory)
        {
            itemID = { 5512, 224464 }, -- Healthstone, Demonic Healthstone
            key = "healthstone",
            name = "治療石",
            class = "WARLOCK",
            missingText = "沒有\n治療石",
            groupId = "healthstone",
            displayIcon = 538745, -- Healthstone icon
            readyCheckOnly = true,
        },
    },
}

---@type table<string, BuffGroup>
BR.BuffGroups = {
    beacons = { displayName = "信標" },
    shamanImbues = { displayName = "薩滿灌魔" },
    paladinRites = { displayName = "聖騎士儀式" },
    pets = { displayName = "寵物" },
    shamanShields = { displayName = "薩滿盾" },
    -- Consumable groups
    flask = { displayName = "精鍊" },
    food = { displayName = "食物" },
    delveFood = { displayName = "探究食物" },
    rune = { displayName = "增強符文" },
    weaponBuff = { displayName = "武器增益" },
    healthstone = { displayName = "治療石!" },
}

-- Classes that benefit from each buff (BETA: class-level only, not spec-aware)
-- nil = everyone benefits, otherwise only listed classes are counted
BR.BuffBeneficiaries = {
    intellect = {
        MAGE = true,
        WARLOCK = true,
        PRIEST = true,
        DRUID = true,
        SHAMAN = true,
        MONK = true,
        EVOKER = true,
        PALADIN = true,
        DEMONHUNTER = true,
    },
    attackPower = {
        WARRIOR = true,
        ROGUE = true,
        HUNTER = true,
        DEATHKNIGHT = true,
        PALADIN = true,
        MONK = true,
        DRUID = true,
        DEMONHUNTER = true,
        SHAMAN = true,
    },
    -- stamina, versatility, skyfury, bronze = everyone benefits (nil)
}
