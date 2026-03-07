local _, BR = ...

-- ============================================================================
-- BUFF STATE MODULE
-- ============================================================================
-- Pure data layer: computes "what buffs are missing" without any UI concerns.
-- Display layer subscribes to BuffStateChanged events to render.

-- ============================================================================
-- TYPE DEFINITIONS
-- ============================================================================

---@class BuffStateEntry
---@field key string                         -- "intellect", "devotionAura", etc.
---@field category CategoryName              -- "raid", "presence", "targeted", "self", "pet", "consumable", "custom"
---@field sortOrder number                   -- Position within category for display ordering
---@field visible boolean                    -- Should show?
---@field displayType "count"|"missing"|"expiring"
---@field countText string?                  -- "17/20" for raid buffs, "5m" for expiring consumables
---@field missingText string?                -- "NO\nAURA" for non-raid
---@field expiringTime number?               -- Seconds remaining if expiring
---@field shouldGlow boolean                 -- Expiration glow?
---@field iconByRole table<RoleType,number>? -- Role-based icon override
---@field rebuffWarning boolean?             -- Consumable rebuff pulsing border?
---@field isEating boolean?                 -- Food entry: player is currently eating
---@field eatingExpirationTime number?      -- GetTime()-based expiration of eating aura
---@field petActions PetActionList?           -- Expanded pet summon actions

-- Lua stdlib locals (avoid repeated global lookups in hot paths)
local floor = math.floor
local tinsert = table.insert

-- Buff tables from Buffs.lua (via BR namespace)
local BUFF_TABLES = BR.BUFF_TABLES
local BuffBeneficiaries = BR.BuffBeneficiaries

-- Local aliases
local RaidBuffs = BUFF_TABLES.raid
local PresenceBuffs = BUFF_TABLES.presence
local TargetedBuffs = BUFF_TABLES.targeted
local SelfBuffs = BUFF_TABLES.self
local PetBuffs = BUFF_TABLES.pet
local Consumables = BUFF_TABLES.consumable
local CustomBuffs = BUFF_TABLES.custom

-- ============================================================================
-- MODULE STATE
-- ============================================================================

---@class BuffState
---@field entries table<string, BuffStateEntry>
---@field lastUpdate number
local BuffState = {
    entries = {},
    lastUpdate = 0,
}

-- Cache player class (set once on init via SetPlayerClass)
local playerClass = nil

-- Ready check state (set via SetReadyCheckState)
local inReadyCheck = false

-- Vehicle state (set via SetInVehicle)
local inVehicle = false

-- Combat/encounter state (set via SetInCombat by the Display layer)
-- IMPORTANT: This flag is the single source of truth for "are aura queries restricted?"
-- within State.lua. It covers BOTH combat lockdown AND boss encounters.
--
-- Why not just call InCombatLockdown()? Because ENCOUNTER_START fires BEFORE
-- InCombatLockdown() returns true — the player isn't in combat until their first hostile
-- action lands on the boss. During that window (potentially hundreds of ms while a spell
-- is traveling), the aura API is already restricted but InCombatLockdown() still returns
-- false. Non-whitelisted spells (e.g. Devotion Aura 465) silently return nil from
-- C_UnitAuras.GetUnitAuraBySpellID, causing false "missing" flashes.
--
-- The Display layer sets this flag on ENCOUNTER_START, PLAYER_REGEN_DISABLED, etc.,
-- ensuring State.lua sees the restricted state as early as possible.
local inCombat = false

-- ============================================================================
-- CACHED VALUES (invalidated by specific events)
-- ============================================================================

-- Content type cache (invalidated on PLAYER_ENTERING_WORLD)
local cachedContentType = nil

-- Difficulty cache (invalidated alongside content type)
local cachedDifficultyKey = nil

local DUNGEON_DIFFICULTY_KEYS = {
    [1] = "normal", -- Normal
    [2] = "heroic", -- Heroic
    [23] = "mythic", -- Mythic
    [8] = "mythicPlus", -- Mythic Keystone
    [24] = "timewalking", -- Timewalking
    [205] = "follower", -- Follower Dungeon
}

local RAID_DIFFICULTY_KEYS = {
    [17] = "lfr", -- Looking for Raid
    [14] = "normal", -- Normal
    [15] = "heroic", -- Heroic
    [16] = "mythic", -- Mythic
}

-- Maps content type to the DB key holding its difficulty sub-filter
local CONTENT_DIFF_DB_KEYS = {
    scenario = "scenarioDifficulty",
    dungeon = "dungeonDifficulty",
    raid = "raidDifficulty",
}

-- Talent/spell knowledge cache (invalidated on PLAYER_SPECIALIZATION_CHANGED)
local cachedSpellKnowledge = {}

-- Spec ID cache (invalidated on PLAYER_SPECIALIZATION_CHANGED)
local cachedSpecId = nil

-- Player role cache (invalidated on PLAYER_SPECIALIZATION_CHANGED)
local cachedPlayerRole = nil

-- Off-hand weapon cache (invalidated on equipment/spec change)
local cachedHasOffHandWeapon = nil

-- Item ownership cache (invalidated on BAG_UPDATE_DELAYED, PLAYER_EQUIPMENT_CHANGED)
---@type table<number, boolean>
local cachedItemOwnership = {}

-- Weapon enchant info for current refresh cycle (set once per BuffState.Refresh())
local currentWeaponEnchants = {
    hasMainHand = false,
    mainHandID = nil,
    mainHandExpiration = nil,
    hasOffHand = false,
    offHandID = nil,
    offHandExpiration = nil,
}

-- Valid group members for current refresh cycle (set once per BuffState.Refresh())
-- Each entry: { unit = "raid1", class = "WARRIOR", isPlayer = true }
---@type {unit: string, class: string, isPlayer: boolean}[]
local currentValidUnits = {}

-- Whether NPCs should be included in buff counting for the current refresh cycle.
-- True in follower dungeons and delves where NPC companions can receive buffs.
local includeNPCsInCounting = false

-- Note: inCombat (set via SetInCombat) is used by CountMissingBuff to skip NPCs during
-- combat/encounters — NPC buff spell IDs aren't on the Blizzard aura whitelist.

-- Aura-safe spell whitelist loaded from Data/CombatSafeSpells.lua
local COMBAT_SAFE_SPELLS = BR.COMBAT_SAFE_SPELLS

---Determine if a buff's detection method works in aura-restricted contexts (combat + M+ keystones).
---Non-aura detection (weapon enchants, inventory checks) is always safe.
---Aura-based detection requires all queried spell IDs to be in the Blizzard whitelist.
---@param buff table Any buff table entry (RaidBuff, SelfBuff, ConsumableBuff, etc.)
---@return boolean
local function IsAuraTrackable(buff)
    -- Non-aura detection is always safe in restricted contexts
    if buff.checkWeaponEnchant or buff.checkWeaponEnchantOH then
        return true
    end
    if buff.itemID and not buff.spellID and not buff.buffIconID then
        return true
    end

    -- Enchant-only detection (no aura check needed)
    if buff.enchantID and not buff.requiresBuffWithEnchant then
        return true
    end

    -- buffIconID (GetAuraDataByIndex iteration) is not safe in restricted contexts
    if buff.buffIconID then
        return false
    end

    -- Determine which spell IDs actually get queried via UnitHasBuff
    local idsToCheck = buff.casterBuffId or buff.buffIdOverride or buff.spellID

    -- No aura spell IDs (e.g., pure customCheck pet buffs)
    if not idsToCheck then
        return true
    end

    -- All queried spell IDs must be in the whitelist
    if type(idsToCheck) == "number" then
        return COMBAT_SAFE_SPELLS[idsToCheck] ~= nil
    end
    for _, id in ipairs(idsToCheck) do
        if not COMBAT_SAFE_SPELLS[id] then
            return false
        end
    end
    return true
end

-- Last target cache: runtime-only map of buffKey -> {name, class} for targeted buffs.
-- When a targeted buff is found on someone, we remember their name so the click macro
-- can re-target them automatically. Not persisted to SavedVariables.
---@type table<string, {name: string, class: string}>
local lastTargets = {}

---Get the last known target for a targeted buff
---@param buffKey string
---@return string? name Character name (with realm) of the last known target
---@return string? class English class token (e.g. "PALADIN")
local function GetLastTarget(buffKey)
    local entry = lastTargets[buffKey]
    if entry then
        return entry.name, entry.class
    end
    return nil, nil
end

-- Pool of reusable unit entry tables (avoids creating new tables each refresh)
---@type {unit: string, class: string, isPlayer: boolean}[]
local unitEntryPool = {}
local unitEntryPoolSize = 0

---Get a unit entry from the pool or create a new one
---@param unit string
---@param class string
---@param isPlayer boolean
---@return {unit: string, class: string, isPlayer: boolean}
local function AcquireUnitEntry(unit, class, isPlayer)
    local entry
    if unitEntryPoolSize > 0 then
        entry = unitEntryPool[unitEntryPoolSize]
        unitEntryPool[unitEntryPoolSize] = nil
        unitEntryPoolSize = unitEntryPoolSize - 1
        entry.unit = unit
        entry.class = class
        entry.isPlayer = isPlayer
    else
        entry = { unit = unit, class = class, isPlayer = isPlayer }
    end
    return entry
end

---Return all current unit entries to the pool for reuse
local function RecycleUnitEntries()
    for i = 1, #currentValidUnits do
        unitEntryPoolSize = unitEntryPoolSize + 1
        unitEntryPool[unitEntryPoolSize] = currentValidUnits[i]
        currentValidUnits[i] = nil
    end
end

-- Max level per class for current refresh cycle (players only, for caster availability checks)
---@type table<ClassName, number>
local classMaxLevels = {}

---Get the player's current spec ID (cached)
---@return number?
local function GetPlayerSpecId()
    if cachedSpecId then
        return cachedSpecId
    end
    local specIndex = GetSpecialization()
    if specIndex then
        cachedSpecId = GetSpecializationInfo(specIndex)
    end
    return cachedSpecId
end

---Get the player's current role (cached)
---@return RoleType?
local function GetPlayerRole()
    if cachedPlayerRole then
        return cachedPlayerRole
    end
    local specIndex = GetSpecialization()
    if specIndex then
        cachedPlayerRole = GetSpecializationRole(specIndex)
    end
    return cachedPlayerRole
end

---Check if player knows a spell (cached version of IsPlayerSpell)
---@param spellID number
---@return boolean
local function IsPlayerSpellCached(spellID)
    if cachedSpellKnowledge[spellID] ~= nil then
        return cachedSpellKnowledge[spellID]
    end
    local knows = IsPlayerSpell(spellID)
    cachedSpellKnowledge[spellID] = knows
    return knows
end

---Check if player has an item equipped or in bags (cached)
---@param itemID number
---@return boolean
local function HasItemInBagsOrEquipped(itemID)
    if cachedItemOwnership[itemID] ~= nil then
        return cachedItemOwnership[itemID]
    end
    local owned = false
    -- Check bags first via C_Item.GetItemCount
    local ok, count = pcall(C_Item.GetItemCount, itemID)
    if ok and count and count > 0 then
        owned = true
    else
        -- Check equipment slots 1-19
        for slot = 1, 19 do
            if GetInventoryItemID("player", slot) == itemID then
                owned = true
                break
            end
        end
    end
    cachedItemOwnership[itemID] = owned
    return owned
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

---Check if a unit is a valid group member for buff tracking
---Excludes: non-existent, dead/ghost, disconnected, hostile (cross-faction in open world)
---@param unit string
---@return boolean
local function IsValidGroupMember(unit)
    return UnitExists(unit)
        and not UnitIsDeadOrGhost(unit)
        and UnitIsConnected(unit)
        and UnitCanAssist("player", unit)
        and UnitIsVisible(unit)
end

---Build the list of valid units for the current refresh cycle
---Called once at the start of BuffState.Refresh()
local function BuildValidUnitCache()
    RecycleUnitEntries()
    wipe(classMaxLevels)

    -- Determine if NPCs should count for buff tracking this refresh.
    -- Follower dungeons and delves (scenarios) have NPC companions that can receive buffs.
    -- Other content (e.g., Legion artifact quests) has allied NPCs that cannot.
    do
        -- Default: exclude NPCs from buff counting.
        -- Only whitelist specific content where NPC companions can receive player buffs.
        local difficultyID = select(3, GetInstanceInfo())
        includeNPCsInCounting = difficultyID == 205 or difficultyID == 208 -- Follower dungeon / Delves
    end

    local inRaid = IsInRaid()
    local groupSize = GetNumGroupMembers()

    if groupSize == 0 then
        -- Solo player
        local _, class = UnitClass("player")
        currentValidUnits[1] = AcquireUnitEntry("player", class, true)
        classMaxLevels[class] = UnitLevel("player")
        return
    end

    for i = 1, groupSize do
        local unit
        if inRaid then
            unit = "raid" .. i
        else
            if i == 1 then
                unit = "player"
            else
                unit = "party" .. (i - 1)
            end
        end

        if IsValidGroupMember(unit) then
            local _, class = UnitClass(unit)
            local isPlayer = UnitIsPlayer(unit)
            currentValidUnits[#currentValidUnits + 1] = AcquireUnitEntry(unit, class, isPlayer)
            -- Track max level per class (players only, for buff caster checks)
            if isPlayer and class then
                local level = UnitLevel(unit)
                if not classMaxLevels[class] or level > classMaxLevels[class] then
                    classMaxLevels[class] = level
                end
            end
        end
    end

    -- Prune last targets: remove entries for players no longer in the group
    for buffKey, entry in pairs(lastTargets) do
        local found = false
        for _, data in ipairs(currentValidUnits) do
            if GetUnitName(data.unit, true) == entry.name then
                found = true
                break
            end
        end
        if not found then
            lastTargets[buffKey] = nil
        end
    end
end

---Check if any group member of the given class meets the level requirement
---Uses classMaxLevels cache built at start of refresh cycle
---@param requiredClass ClassName
---@param levelRequired? number
---@return boolean
local function HasCasterForBuff(requiredClass, levelRequired)
    local maxLevel = classMaxLevels[requiredClass]
    if not maxLevel then
        return false
    end
    return not levelRequired or maxLevel >= levelRequired
end

---Check if unit has a specific buff (handles single spellID or table of spellIDs)
---@param unit string
---@param spellIDs SpellID
---@return boolean hasBuff
---@return number? remainingTime
---@return string? sourceUnit
local function UnitHasBuff(unit, spellIDs)
    if type(spellIDs) ~= "table" then
        spellIDs = { spellIDs }
    end

    local hasBuff, remaining, source
    pcall(function()
        for _, id in ipairs(spellIDs) do
            local auraData = C_UnitAuras.GetUnitAuraBySpellID(unit, id)
            if auraData then
                hasBuff = true
                if auraData.expirationTime and auraData.expirationTime > 0 then
                    remaining = auraData.expirationTime - GetTime()
                end
                source = auraData.sourceUnit
                return
            end
        end
    end)

    return hasBuff or false, remaining, source
end

---Format remaining time in seconds to a short string (e.g., "5m" or "30s")
---@param seconds number
---@return string
local function FormatRemainingTime(seconds)
    local mins = floor(seconds / 60)
    if mins > 0 then
        return mins .. "m"
    else
        return floor(seconds) .. "s"
    end
end

---Get the effective setting key for a buff (groupId if present, otherwise individual key)
---@param buff RaidBuff|PresenceBuff|TargetedBuff|SelfBuff
---@return string
local function GetBuffSettingKey(buff)
    return buff.groupId or buff.key
end

---Check if a buff is enabled (defaults to true if not explicitly set to false)
---@param key string
---@return boolean
local function IsBuffEnabled(key)
    local db = BR.profile
    return db.enabledBuffs[key] ~= false
end

---Get the current content type based on instance/zone (cached)
---@return "openWorld"|"dungeon"|"scenario"|"raid"|"housing"
local function GetCurrentContentType()
    if cachedContentType then
        return cachedContentType
    end

    -- Check housing before instance type (housing zones may report as instanced)
    if
        C_Housing
        and (
            (C_Housing.IsInsideHouseOrPlot and C_Housing.IsInsideHouseOrPlot())
            or (C_Housing.IsOnNeighborhoodMap and C_Housing.IsOnNeighborhoodMap())
        )
    then
        cachedContentType = "housing"
        return cachedContentType
    end

    -- Delves report inInstance=false but instanceType="scenario" and difficultyID=208;
    -- check difficultyID first so they are correctly classified as scenarios.
    local difficultyID = select(3, GetInstanceInfo())
    if difficultyID == 208 then
        cachedContentType = "scenario"
        return cachedContentType
    end

    local inInstance, instanceType = IsInInstance()
    if not inInstance then
        cachedContentType = "openWorld"
    elseif instanceType == "raid" then
        cachedContentType = "raid"
    elseif instanceType == "scenario" then
        cachedContentType = "scenario"
    else
        cachedContentType = "dungeon"
    end

    return cachedContentType
end

---Get the current difficulty key (cached)
---Only caches valid keys; returns nil (retried next call) if the API returns
---an unmapped difficultyID (e.g. 0 during a loading transition).
---@return string? difficultyKey or nil if not in a dungeon/raid or unknown difficulty
local function GetCurrentDifficultyKey()
    if cachedDifficultyKey ~= nil then
        return cachedDifficultyKey
    end
    local difficultyID = select(3, GetInstanceInfo())
    local contentType = GetCurrentContentType()
    if contentType == "dungeon" then
        local key = DUNGEON_DIFFICULTY_KEYS[difficultyID]
        if key then
            cachedDifficultyKey = key
        end
        return key
    elseif contentType == "raid" then
        local key = RAID_DIFFICULTY_KEYS[difficultyID]
        if key then
            cachedDifficultyKey = key
        end
        return key
    elseif contentType == "scenario" then
        local key = difficultyID == 208 and "delves" or "others"
        cachedDifficultyKey = key
        return key
    end
    return nil
end

---Check if a category should be visible for the current content type
---@param category CategoryName
---@return boolean
local function IsCategoryVisibleForContent(category)
    if inVehicle and category ~= "raid" and category ~= "presence" then
        return false
    end
    local db = BR.profile
    if not db.categoryVisibility then
        return true
    end
    local visibility = db.categoryVisibility[category]
    if not visibility then
        return true
    end
    local contentType = GetCurrentContentType()
    if visibility[contentType] == false then
        return false
    end
    -- Check difficulty sub-filter
    local diffKey = GetCurrentDifficultyKey()
    if diffKey then
        local diffDbKey = CONTENT_DIFF_DB_KEYS[contentType]
        local diffTable = diffDbKey and visibility[diffDbKey]
        if diffTable then
            return diffTable[diffKey] ~= false
        end
    end
    -- Per-category ready check filter
    local catSettings = db.categorySettings and db.categorySettings[category]
    if catSettings and catSettings.showOnlyOnReadyCheck and not inReadyCheck then
        return false
    end
    return true
end

---Check if a custom buff should be visible based on its per-buff loadConditions
---@param buff CustomBuff
---@return boolean
local function IsCustomBuffVisibleForContent(buff)
    if inVehicle then
        return false
    end
    local lc = buff.loadConditions
    if not lc then
        return true
    end -- nil = show everywhere

    local contentType = GetCurrentContentType()
    if lc[contentType] == false then
        return false
    end

    -- Difficulty sub-filter
    local diffKey = GetCurrentDifficultyKey()
    if diffKey then
        local diffDbKey = CONTENT_DIFF_DB_KEYS[contentType]
        local diffTable = diffDbKey and lc[diffDbKey]
        if diffTable then
            return diffTable[diffKey] ~= false
        end
    end

    -- Per-buff ready check filter
    if lc.readyCheckOnly and not inReadyCheck then
        return false
    end

    -- Level filter
    if lc.levelFilter then
        local playerLevel = UnitLevel("player")
        local maxLevel = GetMaxLevelForPlayerExpansion()
        if lc.levelFilter == "maxLevel" and playerLevel < maxLevel then
            return false
        elseif lc.levelFilter == "belowMaxLevel" and playerLevel >= maxLevel then
            return false
        end
    end

    return true
end

---Determine visibility and scan scope for a buff based on tracking mode.
---Raid buffs go on everyone, so "scan group" means showing coverage numbers.
---Presence buffs live on the caster, so "scan group" means finding if anyone has the aura.
---@param trackingMode string
---@param buffClass ClassName
---@param category "raid"|"presence"
---@param hasCaster boolean
---@param castOnOthers? boolean Buff exists on the target, not the caster (e.g., Soulstone)
---@return { show: boolean, playerOnly: boolean }
local function GetTrackingScope(trackingMode, buffClass, category, hasCaster, castOnOthers)
    if not hasCaster then
        return { show = false, playerOnly = false }
    end
    if trackingMode == "my_buffs" and buffClass ~= playerClass then
        return { show = false, playerOnly = false }
    end

    if trackingMode == "personal" then
        -- Presence buffs from other classes exist only on the caster, not on you.
        -- castOnOthers buffs (Soulstone) are someone else's responsibility in personal mode.
        if category == "presence" and (buffClass ~= playerClass or castOnOthers) then
            return { show = false, playerOnly = false }
        end
        return { show = true, playerOnly = true }
    elseif trackingMode == "smart" then
        local isMyClass = buffClass == playerClass
        -- Raid: scan group if I'm the caster (show coverage), just check me otherwise
        -- Presence: just check me if I'm the caster, scan group to find other casters
        --   castOnOthers: always scan group (the buff is on the target, not on me)
        if category == "raid" then
            return { show = true, playerOnly = not isMyClass }
        else
            return { show = true, playerOnly = isMyClass and not castOnOthers }
        end
    elseif trackingMode == "my_buffs" then
        -- Raid: scan group to show coverage numbers
        -- Presence: just check if my own aura is active
        --   castOnOthers: scan group (the buff is on someone else)
        return { show = true, playerOnly = category == "presence" and not castOnOthers }
    else
        -- "all" mode: always scan the full group
        return { show = true, playerOnly = false }
    end
end

-- ============================================================================
-- BUFF CHECK FUNCTIONS
-- ============================================================================

---Count group members missing a buff
---Uses currentValidUnits cache built at start of refresh cycle
---@param spellIDs SpellID
---@param buffKey? string Used for class benefit filtering
---@param playerOnly? boolean Only check the player, not the group
---@return number missing
---@return number total
---@return number? minRemaining
local function CountMissingBuff(spellIDs, buffKey, playerOnly)
    local missing = 0
    local total = 0
    local minRemaining = nil
    local beneficiaries = BuffBeneficiaries[buffKey]

    if playerOnly or #currentValidUnits <= 1 then
        -- Solo/player-only: check if player benefits
        if beneficiaries and not beneficiaries[playerClass] then
            return 0, 0, nil -- player doesn't benefit, skip
        end
        total = 1
        local hasBuff, remaining = UnitHasBuff("player", spellIDs)
        if not hasBuff then
            missing = 1
        elseif remaining then
            minRemaining = remaining
        end
        return missing, total, minRemaining
    end

    for _, data in ipairs(currentValidUnits) do
        -- Skip NPCs unless in whitelisted content. During combat, also skip NPCs here:
        -- NPC-cast raid buff spell IDs (e.g., 432661) aren't combat-whitelisted, so
        -- UnitHasBuff returns nil causing false missing counts. Targeted buffs (HasPresenceBuff,
        -- IsPlayerBuffActive) use player-cast spell IDs that ARE whitelisted, so they
        -- still include NPCs via the unchanged includeNPCsInCounting check.
        if data.isPlayer or (includeNPCsInCounting and not inCombat) then
            -- Check if unit's class benefits from this buff
            if not beneficiaries or beneficiaries[data.class] then
                total = total + 1
                local hasBuff, remaining = UnitHasBuff(data.unit, spellIDs)
                if not hasBuff then
                    missing = missing + 1
                elseif remaining then
                    if not minRemaining or remaining < minRemaining then
                        minRemaining = remaining
                    end
                end
            end
        end
    end

    return missing, total, minRemaining
end

---Check if anyone in the group has a presence buff active
---Uses currentValidUnits cache built at start of refresh cycle
---@param spellIDs SpellID
---@param playerOnly? boolean Only check the player, not the group
---@return boolean hasBuff
---@return number? minRemaining
local function HasPresenceBuff(spellIDs, playerOnly)
    if playerOnly or #currentValidUnits <= 1 then
        local hasBuff, remaining = UnitHasBuff("player", spellIDs)
        return hasBuff, remaining
    end

    local minRemaining = nil
    local found = false

    for _, data in ipairs(currentValidUnits) do
        -- Skip NPCs in content where they can't receive player buffs
        if data.isPlayer or includeNPCsInCounting then
            local hasBuff, remaining = UnitHasBuff(data.unit, spellIDs)
            if hasBuff then
                found = true
                if remaining then
                    if not minRemaining or remaining < minRemaining then
                        minRemaining = remaining
                    end
                else
                    return true, nil -- no expiration, no need to keep scanning
                end
            end
        end
    end

    return found, minRemaining
end

---Check if player's buff is active on anyone in the group
---Uses currentValidUnits cache built at start of refresh cycle
---@param spellID number
---@param role? RoleType Only check units with this role
---@return boolean
---@return number? minRemaining
---@return string? targetUnit Unit ID of a non-player target with the buff (for last target cache)
local function IsPlayerBuffActive(spellID, role)
    local minRemaining = nil
    local targetUnit = nil
    for _, data in ipairs(currentValidUnits) do
        -- Skip NPCs in content where they can't receive player buffs
        if data.isPlayer or includeNPCsInCounting then
            if not role or UnitGroupRolesAssigned(data.unit) == role then
                local hasBuff, remaining, sourceUnit = UnitHasBuff(data.unit, spellID)
                if hasBuff and sourceUnit and UnitIsUnit(sourceUnit, "player") then
                    -- Track first non-player target for last target cache
                    if not targetUnit and not UnitIsUnit(data.unit, "player") then
                        targetUnit = data.unit
                    end
                    if not remaining then
                        return true, nil, targetUnit
                    end
                    if not minRemaining or remaining < minRemaining then
                        minRemaining = remaining
                    end
                end
            end
        end
    end
    return minRemaining ~= nil, minRemaining, targetUnit
end

---Check if player should cast their targeted buff (returns true if a beneficiary needs it)
---@param spellIDs SpellID
---@param requiredClass ClassName
---@param beneficiaryRole? RoleType
---@param requireSpecId? number
---@param buffKey? string Used for last target cache
---@return boolean? shouldShow Returns nil if player can't provide this buff
---@return number? remainingTime
local function ShouldShowTargetedBuff(spellIDs, requiredClass, beneficiaryRole, requireSpecId, buffKey, casterBuffId)
    if playerClass ~= requiredClass then
        return nil
    end
    if requireSpecId and GetPlayerSpecId() ~= requireSpecId then
        return nil
    end

    local spellID = (type(spellIDs) == "table" and spellIDs[1] or spellIDs) --[[@as number]]
    if not IsPlayerSpellCached(spellID) then
        return nil
    end

    -- Targeted buffs require a group (you cast them on others)
    if GetNumGroupMembers() == 0 then
        return nil
    end

    if casterBuffId then
        -- Shortcut: check if the caster has this buff on themselves (combat-safe spell ID)
        local hasBuff, remaining = UnitHasBuff("player", casterBuffId)
        -- Update last target cache by scanning group for the original buff.
        -- Only out of combat/encounter: the target-side spell may not be on the aura whitelist,
        -- so UnitHasBuff would return nil and incorrectly clear the cache.
        if buffKey and not inCombat then
            if hasBuff then
                local foundTarget = false
                for _, data in ipairs(currentValidUnits) do
                    if not UnitIsUnit(data.unit, "player") then
                        local targetHas = UnitHasBuff(data.unit, spellIDs)
                        if targetHas then
                            local name = GetUnitName(data.unit, true)
                            if name then
                                local _, class = UnitClass(data.unit)
                                local existing = lastTargets[buffKey]
                                if existing then
                                    existing.name = name
                                    existing.class = class
                                else
                                    lastTargets[buffKey] = { name = name, class = class }
                                end
                                foundTarget = true
                                break
                            end
                        end
                    end
                end
                if not foundTarget then
                    lastTargets[buffKey] = nil
                end
            end
            -- If not active, keep old last target so macro still targets them after it falls off
        end
        return not hasBuff, remaining
    end

    local isActive, remaining, targetUnit = IsPlayerBuffActive(spellID, beneficiaryRole)

    -- Update last target cache
    if buffKey then
        if targetUnit then
            local name = GetUnitName(targetUnit, true) -- include realm
            if name then
                local _, class = UnitClass(targetUnit)
                local existing = lastTargets[buffKey]
                if existing then
                    existing.name = name
                    existing.class = class
                else
                    lastTargets[buffKey] = { name = name, class = class }
                end
            end
        elseif isActive then
            -- Buff found but only on player — clear last target
            lastTargets[buffKey] = nil
        end
        -- If not active at all, keep old last target so macro still targets them after it falls off
    end

    return not isActive, remaining
end

-- Categories where the "player knows this spell" check should be skipped.
-- Custom buffs track buffs the user *receives*, not necessarily casts.
local SKIP_SPELL_KNOWN_CATEGORIES = { custom = true }

---Check if player should cast their self buff or weapon imbue (returns true if missing)
---@param spellID SpellID
---@param requiredClass ClassName
---@param enchantID? number For weapon imbues, checks if this enchant is on either weapon
---@param requiresSpell? number Only show if player knows this spell
---@param excludeSpell? number Hide if player knows this spell
---@param buffIdOverride? number|number[] Separate buff ID(s) to check (if different from spellID)
---@param customCheck? fun(): boolean? Custom check function for complex buff logic
---@param requireSpecId? number Only show if player's current spec matches (WoW spec ID)
---@param skipSpellKnownCheck? boolean Skip the "player knows spell" check (for custom buffs)
---@param requiresBuffWithEnchant? boolean When true, require both enchant AND buff (for Paladin Rites)
---@return boolean? Returns nil if player can't/shouldn't use this buff
local function ShouldShowSelfBuff(
    spellID,
    requiredClass,
    enchantID,
    requiresSpell,
    excludeSpell,
    buffIdOverride,
    customCheck,
    requireSpecId,
    skipSpellKnownCheck,
    requiresBuffWithEnchant
)
    if requiredClass and playerClass ~= requiredClass then
        return nil
    end
    if requireSpecId and GetPlayerSpecId() ~= requireSpecId then
        return nil
    end

    -- Spell knowledge checks (before spell availability check for talent/ability-gated buffs)
    if requiresSpell and not IsPlayerSpellCached(requiresSpell) then
        return nil
    end
    if excludeSpell and IsPlayerSpellCached(excludeSpell) then
        return nil
    end

    -- Custom check function takes precedence over standard checks
    if customCheck then
        return customCheck()
    end

    -- For buffs with multiple spellIDs (like shields), check if player knows ANY of them
    -- Skip for custom buffs (they track received buffs, not cast buffs)
    if not skipSpellKnownCheck then
        ---@type number[]
        local spellIDs
        if type(spellID) == "table" then
            spellIDs = spellID
        else
            spellIDs = { spellID }
        end
        local knowsAnySpell = false
        for _, id in ipairs(spellIDs) do
            if IsPlayerSpellCached(id) then
                knowsAnySpell = true
                break
            end
        end
        if not knowsAnySpell then
            return nil
        end
    end

    -- Weapon imbue: check if this specific enchant is on either weapon
    if enchantID then
        local hasEnchant = currentWeaponEnchants.mainHandID == enchantID or currentWeaponEnchants.offHandID == enchantID

        -- For Paladin Rites: require BOTH enchant AND buff (Blizzard bug workaround)
        if requiresBuffWithEnchant then
            local hasBuff, _ = UnitHasBuff("player", buffIdOverride or spellID)
            return not (hasEnchant and hasBuff)
        end

        -- Standard enchant-only check
        return not hasEnchant
    end

    -- Regular buff check - use buffIdOverride if provided, otherwise use spellID
    local hasBuff, _ = UnitHasBuff("player", buffIdOverride or spellID)
    return not hasBuff
end

-- Icon ID for the eating channel aura (consistent across all food types)
-- Shared via BR namespace: also used by BuffReminders.lua for the display icon
BR.EATING_AURA_ICON = 133950
local EATING_AURA_ICON = BR.EATING_AURA_ICON

-- Event-driven eating state: tracked via UNIT_AURA payload, no per-render scanning.
local eatingAuraInstanceID = nil

---Check if the player is currently eating (reads cached flag, O(1))
---@return boolean
local function IsPlayerEating()
    return eatingAuraInstanceID ~= nil
end

---Full aura scan to seed eating state (call once on init / reload)
local function ScanEatingState()
    eatingAuraInstanceID = nil
    local i = 1
    local auraData = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
    while auraData do
        local ok, match = pcall(function()
            return auraData.icon == EATING_AURA_ICON
        end)
        if ok and match then
            eatingAuraInstanceID = auraData.auraInstanceID
            return
        end
        i = i + 1
        auraData = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
    end
end

---Update eating state from UNIT_AURA payload (called on every player UNIT_AURA)
---@param updateInfo table? The updateInfo payload from UNIT_AURA
local function UpdateEatingState(updateInfo)
    if not updateInfo then
        return
    end
    if updateInfo.addedAuras then
        for _, aura in ipairs(updateInfo.addedAuras) do
            local ok, match = pcall(function()
                return aura.icon == EATING_AURA_ICON
            end)
            if ok and match then
                eatingAuraInstanceID = aura.auraInstanceID
                break
            end
        end
    end
    if updateInfo.removedAuraInstanceIDs and eatingAuraInstanceID then
        for _, id in ipairs(updateInfo.removedAuraInstanceIDs) do
            if id == eatingAuraInstanceID then
                eatingAuraInstanceID = nil
                break
            end
        end
    end
end

---Get expiration time of the eating aura (O(1) lookup via cached instance ID)
---@return number? expirationTime GetTime()-based expiration, nil if not eating or no duration
local function GetEatingExpirationTime()
    if not eatingAuraInstanceID then
        return nil
    end
    local ok, auraData = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, "player", eatingAuraInstanceID)
    if not ok or not auraData or not auraData.expirationTime or auraData.expirationTime == 0 then
        return nil
    end
    return auraData.expirationTime
end

---Check if player is missing a consumable buff, weapon enchant, or inventory item (returns true if missing)
---@param spellIDs? SpellID
---@param buffIconID? number
---@param checkWeaponEnchant? boolean
---@param itemID? number|number[]
---@return boolean shouldShow
---@return number? remainingTime seconds remaining if buff is present and has a duration
local function ShouldShowConsumableBuff(spellIDs, buffIconID, checkWeaponEnchant, checkWeaponEnchantOH, itemID)
    -- Check buff auras by spell ID
    if spellIDs then
        local spellList = type(spellIDs) == "table" and spellIDs or { spellIDs }
        for _, id in ipairs(spellList) do
            local hasBuff, remaining = UnitHasBuff("player", id)
            if hasBuff then
                return false, remaining -- Has at least one of the consumable buffs
            end
        end
    end

    -- Check buff auras by icon ID (e.g., food buffs all use icon 136000)
    if buffIconID then
        local i = 1
        local auraData = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        while auraData do
            local success, iconMatches = pcall(function()
                return auraData.icon == buffIconID
            end)
            if success and iconMatches then
                local remaining = nil
                if auraData.expirationTime and auraData.expirationTime > 0 then
                    remaining = auraData.expirationTime - GetTime()
                end
                return false, remaining -- Has a buff with this icon
            end
            i = i + 1
            auraData = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        end
    end

    -- Check if any weapon enchant exists (oils, stones, shaman imbues, etc.)
    if checkWeaponEnchant then
        if currentWeaponEnchants.hasMainHand then
            local remaining = currentWeaponEnchants.mainHandExpiration
                    and (currentWeaponEnchants.mainHandExpiration / 1000)
                or nil
            return false, remaining -- Has a weapon enchant
        end
    end

    -- Check if off-hand weapon enchant exists
    if checkWeaponEnchantOH then
        if currentWeaponEnchants.hasOffHand then
            local remaining = currentWeaponEnchants.offHandExpiration
                    and (currentWeaponEnchants.offHandExpiration / 1000)
                or nil
            return false, remaining
        end
    end

    -- Check inventory for item
    if itemID then
        local itemList = type(itemID) == "table" and itemID or { itemID }
        for _, id in ipairs(itemList) do
            local ok, count = pcall(C_Item.GetItemCount, id, false, true)
            if ok and count and count > 0 then
                return false, nil -- Has the item in inventory
            end
        end
    end

    -- If we have nothing to check, return false
    if not spellIDs and not buffIconID and not checkWeaponEnchant and not checkWeaponEnchantOH and not itemID then
        return false, nil
    end

    return true, nil -- Missing all consumable buffs/enchants/items
end

---Check if buff passes common pre-conditions
---@param buff table Any buff type with optional pre-check fields
---@param presentClasses? table<ClassName, boolean>
---@param db table Database settings
---@return boolean passes
local function PassesPreChecks(buff, presentClasses, db)
    -- Custom visibility condition
    if buff.visibilityCondition and not buff.visibilityCondition() then
        return false
    end

    -- Ready check only (can be overridden per-buff via readyCheckOnlyOverrides)
    if buff.readyCheckOnly and not inReadyCheck then
        local overrides = db.readyCheckOnlyOverrides
        local settingKey = buff.groupId or buff.key
        if not overrides or overrides[settingKey] ~= false then
            return false
        end
    end

    -- Class filtering
    if buff.class then
        local trackingMode = db.buffTrackingMode
        if trackingMode == "my_buffs" and buff.class ~= playerClass then
            return false
        end
        if presentClasses and not presentClasses[buff.class] then
            return false
        end
    end

    -- Talent exclusion
    if buff.excludeSpellID and IsPlayerSpellCached(buff.excludeSpellID) then
        return false
    end

    -- Spell knowledge exclusion
    if buff.excludeIfSpellKnown then
        for _, spellID in ipairs(buff.excludeIfSpellKnown) do
            if IsPlayerSpellCached(spellID) then
                return false
            end
        end
    end

    return true
end

-- ============================================================================
-- BUFF STATE API
-- ============================================================================

---Get a single entry by key
---@param key string
---@return BuffStateEntry?
function BuffState.GetEntry(key)
    return BuffState.entries[key]
end

---Pre-built per-category lists of visible entries (populated by Refresh)
---@type table<CategoryName, BuffStateEntry[]>
BuffState.visibleByCategory = {}

---Create or update an entry
---@param key string
---@param category CategoryName
---@param sortOrder? number Position within category for display ordering
---@return BuffStateEntry
local function GetOrCreateEntry(key, category, sortOrder)
    if not BuffState.entries[key] then
        ---@type BuffStateEntry
        BuffState.entries[key] = {
            key = key,
            category = category,
            sortOrder = sortOrder or 0,
            visible = false,
            displayType = "missing",
            shouldGlow = false,
        }
    end
    return BuffState.entries[key]
end

---Mark an entry as visible+missing with optional glow
---@param entry BuffStateEntry
---@param missingText? string
---@param glowEnabled boolean
local function SetEntryMissing(entry, missingText, glowEnabled)
    entry.visible = true
    entry.displayType = "missing"
    entry.missingText = missingText
    entry.shouldGlow = glowEnabled
end

---If remaining time is below threshold, mark entry as visible+expiring with glow.
---@param entry BuffStateEntry
---@param remaining? number
---@param threshold number
---@param shouldGlow boolean
---@return boolean wasSet true if the entry was marked as expiring
local function TrySetEntryExpiring(entry, remaining, threshold, shouldGlow)
    if remaining and remaining < threshold then
        entry.visible = true
        entry.displayType = "expiring"
        entry.expiringTime = remaining
        entry.countText = FormatRemainingTime(remaining)
        entry.shouldGlow = shouldGlow
        return true
    end
    return false
end

---Recompute all buff states
function BuffState.Refresh()
    local db = BR.profile
    if not db then
        return
    end

    -- Invalidate off-hand weapon cache each refresh cycle (cheap lazy re-check)
    cachedHasOffHandWeapon = nil

    -- Reset all entries to not visible
    for _, entry in pairs(BuffState.entries) do
        entry.visible = false
        entry.shouldGlow = false
        entry.countText = nil
        entry.missingText = nil
        entry.expiringTime = nil
        entry.rebuffWarning = nil -- legacy field, still cleared for safety
        entry.isEating = nil
        entry.eatingExpirationTime = nil
        entry.petActions = nil
    end

    -- Build valid unit cache once per refresh cycle
    BuildValidUnitCache()

    -- Fetch weapon enchant info once per refresh cycle
    local hasMain, mainExp, _, mainID, hasOff, offExp, _, offID = GetWeaponEnchantInfo()
    currentWeaponEnchants.hasMainHand = hasMain or false
    currentWeaponEnchants.mainHandID = mainID
    currentWeaponEnchants.mainHandExpiration = mainExp
    currentWeaponEnchants.hasOffHand = hasOff or false
    currentWeaponEnchants.offHandID = offID
    currentWeaponEnchants.offHandExpiration = offExp

    local trackingMode = db.buffTrackingMode
    -- Aura API is restricted in combat/encounters (inCombat set by Display layer)
    -- and during M+ keystones (always restricted regardless of combat state).
    local isAuraRestricted = inCombat or GetCurrentDifficultyKey() == "mythicPlus"
    local hideExpiring = isAuraRestricted and db.hideExpiringInCombat ~= false

    -- Per-category glow/expiration settings (inherits from defaults via GetCategorySetting)
    local function GetCategoryGlowSettings(cat)
        local glowEnabled = BR.Config.GetCategorySetting(cat, "showExpirationGlow") ~= false
        local threshold = (BR.Config.GetCategorySetting(cat, "expirationThreshold") or 15) * 60
        return glowEnabled, threshold
    end

    -- Process raid buffs (coverage - need everyone to have them)
    local raidVisible = IsCategoryVisibleForContent("raid")
    local raidGlow, raidThreshold = GetCategoryGlowSettings("raid")
    for i, buff in ipairs(RaidBuffs) do
        local entry = GetOrCreateEntry(buff.key, "raid", i)
        local scope =
            GetTrackingScope(trackingMode, buff.class, "raid", HasCasterForBuff(buff.class, buff.levelRequired))

        if IsBuffEnabled(buff.key) and raidVisible and scope.show then
            local missing, total, minRemaining = CountMissingBuff(buff.spellID, buff.key, scope.playerOnly)

            if missing > 0 then
                entry.visible = true
                entry.displayType = "count"
                local buffed = total - missing
                entry.countText = scope.playerOnly and "" or (buffed .. "/" .. total)
                entry.shouldGlow = raidGlow
                if minRemaining and minRemaining < raidThreshold then
                    entry.expiringTime = minRemaining
                end
            elseif not hideExpiring then
                TrySetEntryExpiring(entry, minRemaining, raidThreshold, raidGlow)
            end
        end
    end

    -- Process presence buffs (need at least 1 person to have them)
    local presenceVisible = IsCategoryVisibleForContent("presence")
    local presGlow, presThreshold = GetCategoryGlowSettings("presence")
    for i, buff in ipairs(PresenceBuffs) do
        local entry = GetOrCreateEntry(buff.key, "presence", i)
        local scope = GetTrackingScope(
            trackingMode,
            buff.class,
            "presence",
            HasCasterForBuff(buff.class, buff.levelRequired),
            buff.castOnOthers
        )
        local readyCheckOk = not buff.readyCheckOnly or inReadyCheck
        if not readyCheckOk then
            local overrides = db.readyCheckOnlyOverrides
            local overrideKey = buff.groupId or buff.key
            readyCheckOk = overrides and overrides[overrideKey] == false
        end
        local showBuff = presenceVisible and readyCheckOk and scope.show
        if (not isAuraRestricted or IsAuraTrackable(buff)) and IsBuffEnabled(buff.key) and showBuff then
            local hasBuff, minRemaining = HasPresenceBuff(buff.spellID, scope.playerOnly)

            if not hasBuff then
                SetEntryMissing(entry, buff.missingText, presGlow)
            elseif not buff.noExpirationGlow and not hideExpiring then
                TrySetEntryExpiring(entry, minRemaining, presThreshold, presGlow)
            end
        end
    end

    -- Process targeted buffs (player's own buff responsibility)
    local targetedVisible = IsCategoryVisibleForContent("targeted")
    local targGlow, targThreshold = GetCategoryGlowSettings("targeted")
    for i, buff in ipairs(TargetedBuffs) do
        local entry = GetOrCreateEntry(buff.key, "targeted", i)
        local settingKey = GetBuffSettingKey(buff)

        if
            (not isAuraRestricted or IsAuraTrackable(buff))
            and IsBuffEnabled(settingKey)
            and targetedVisible
            and PassesPreChecks(buff, nil, db)
        then
            local shouldShow, remaining = ShouldShowTargetedBuff(
                buff.spellID,
                buff.class,
                buff.beneficiaryRole,
                buff.requireSpecId,
                buff.key,
                buff.casterBuffId
            )

            if shouldShow then
                SetEntryMissing(entry, buff.missingText, targGlow)
            elseif shouldShow == false and not hideExpiring then
                TrySetEntryExpiring(entry, remaining, targThreshold, targGlow)
            end
        end
    end

    -- Process self buffs (player's own buff on themselves, including weapon imbues)
    local selfVisible = IsCategoryVisibleForContent("self")
    local selfGlow, selfThreshold = GetCategoryGlowSettings("self")
    for i, buff in ipairs(SelfBuffs) do
        local entry = GetOrCreateEntry(buff.key, "self", i)
        local settingKey = buff.groupId or buff.key

        if (not isAuraRestricted or IsAuraTrackable(buff)) and IsBuffEnabled(settingKey) and selfVisible then
            local shouldShow = ShouldShowSelfBuff(
                buff.spellID,
                buff.class,
                buff.enchantID,
                buff.requiresSpellID,
                buff.excludeSpellID,
                buff.buffIdOverride,
                buff.customCheck,
                buff.requireSpecId,
                nil, -- skipSpellKnownCheck
                buff.requiresBuffWithEnchant
            )
            if shouldShow then
                SetEntryMissing(entry, buff.missingText, selfGlow)
                entry.iconByRole = buff.iconByRole
            elseif shouldShow == false and not buff.enchantID and not buff.noExpirationGlow and not hideExpiring then
                -- Buff present but maybe expiring (enchants don't track expiration here)
                local _, remaining = UnitHasBuff("player", buff.buffIdOverride or buff.spellID)
                TrySetEntryExpiring(entry, remaining, selfThreshold, selfGlow)
            end
        end
    end

    -- Process pet buffs (pet summon reminders — no expiration tracking)
    local petVisible = IsCategoryVisibleForContent("pet")
    if BR.profile.hidePetWhileMounted ~= false and IsMounted() then
        petVisible = false
    end
    local petPassiveHidden = BR.profile.petPassiveOnlyInCombat and not UnitAffectingCombat("player")
    local petGlow = GetCategoryGlowSettings("pet")
    for i, buff in ipairs(PetBuffs) do
        local entry = GetOrCreateEntry(buff.key, "pet", i)
        local settingKey = buff.groupId or buff.key

        if IsBuffEnabled(settingKey) and petVisible and not (buff.key == "petPassive" and petPassiveHidden) then
            local shouldShow = ShouldShowSelfBuff(
                buff.spellID,
                buff.class,
                buff.enchantID,
                buff.requiresSpellID,
                buff.excludeSpellID,
                buff.buffIdOverride,
                buff.customCheck,
                buff.requireSpecId,
                nil, -- skipSpellKnownCheck
                buff.requiresBuffWithEnchant
            )
            if shouldShow then
                SetEntryMissing(entry, buff.missingText, petGlow)
                entry.iconByRole = buff.iconByRole
                -- Expanded pet actions (individual summon spell icons)
                if buff.groupId == "pets" and BR.PetHelpers then
                    local actions = BR.PetHelpers.GetPetActions(playerClass)
                    if actions and #actions > 0 then
                        entry.petActions = actions
                    end
                end
            end
        end
    end

    -- Process consumable buffs
    local consumableVisible = IsCategoryVisibleForContent("consumable")
    local consGlow, consThreshold = GetCategoryGlowSettings("consumable")
    local delveFoodOnly = db.defaults and db.defaults.delveFoodOnly and BR.IsInDelve()
    for i, buff in ipairs(Consumables) do
        local entry = GetOrCreateEntry(buff.key, "consumable", i)
        local settingKey = buff.groupId or buff.key

        local hasCaster = not buff.class or HasCasterForBuff(buff.class, buff.levelRequired)
        if
            (not isAuraRestricted or IsAuraTrackable(buff))
            and IsBuffEnabled(settingKey)
            and consumableVisible
            and hasCaster
            and PassesPreChecks(buff, nil, db)
            and not (buff.key ~= "delveFood" and delveFoodOnly)
        then
            local shouldShow, remainingTime = ShouldShowConsumableBuff(
                buff.spellID,
                buff.buffIconID,
                buff.checkWeaponEnchant,
                buff.checkWeaponEnchantOH,
                buff.itemID
            )
            if shouldShow then
                SetEntryMissing(entry, buff.missingText, consGlow)
            elseif not buff.noExpirationGlow and not hideExpiring then
                TrySetEntryExpiring(entry, remainingTime, consThreshold, consGlow)
            end
            -- Eating state for food entries (display uses this for icon override + countdown)
            if entry.visible and buff.key == "food" then
                entry.isEating = IsPlayerEating()
                if entry.isEating then
                    entry.eatingExpirationTime = GetEatingExpirationTime()
                end
            end
        end
    end

    -- Process custom buffs (user-defined, flows through ShouldShowSelfBuff like self/pet)
    local customGlow, customThreshold = GetCategoryGlowSettings("custom")
    local skipSpellKnown = SKIP_SPELL_KNOWN_CATEGORIES["custom"]
    for i, buff in ipairs(CustomBuffs) do
        local entry = GetOrCreateEntry(buff.key, "custom", i)
        local settingKey = buff.groupId or buff.key

        local shouldProcess = (not isAuraRestricted or IsAuraTrackable(buff))
            and IsBuffEnabled(settingKey)
            and IsCustomBuffVisibleForContent(buff)

        -- If requireSpellKnown is true, check if player knows at least one spell
        if shouldProcess and buff.requireSpellKnown then
            local spellIDs = type(buff.spellID) == "table" and buff.spellID or { buff.spellID }
            local knowsAnySpell = false
            for _, spellID in ipairs(spellIDs) do
                if IsPlayerSpellCached(spellID) then
                    knowsAnySpell = true
                    break
                end
            end
            if not knowsAnySpell then
                shouldProcess = false
            end
        end

        if shouldProcess then
            local gateItemID = buff.requireItemID or buff.castItemID
            if gateItemID and not HasItemInBagsOrEquipped(gateItemID) then
                shouldProcess = false
            end
        end

        if shouldProcess then
            local shouldShow = ShouldShowSelfBuff(
                buff.spellID,
                buff.class,
                buff.enchantID,
                buff.requiresSpellID,
                buff.excludeSpellID,
                buff.buffIdOverride,
                buff.customCheck,
                buff.requireSpecId,
                skipSpellKnown,
                buff.requiresBuffWithEnchant
            )
            local wantPresent = buff.showWhenPresent
            local show = (wantPresent and shouldShow == false) or (not wantPresent and shouldShow)
            if show then
                SetEntryMissing(entry, buff.missingText, customGlow)
            elseif not show and shouldShow ~= nil and not buff.enchantID and not hideExpiring then
                -- Buff is present (not missing), check if expiring
                local _, remaining = UnitHasBuff("player", buff.buffIdOverride or buff.spellID)
                TrySetEntryExpiring(entry, remaining, customThreshold, customGlow)
            end
        end
    end

    -- Build visibleByCategory in one pass from entries (reuse sub-tables)
    for _, list in pairs(BuffState.visibleByCategory) do
        wipe(list)
    end
    for _, entry in pairs(BuffState.entries) do
        if entry.visible then
            local cat = entry.category
            if not BuffState.visibleByCategory[cat] then
                BuffState.visibleByCategory[cat] = {}
            end
            tinsert(BuffState.visibleByCategory[cat], entry)
        end
    end

    -- Check if each category's entries are already sorted by sortOrder
    for _, list in pairs(BuffState.visibleByCategory) do
        local sorted = true
        for j = 2, #list do
            if list[j].sortOrder < list[j - 1].sortOrder then
                sorted = false
                break
            end
        end
        ---@diagnostic disable-next-line: inject-field
        list._sorted = sorted
    end

    BuffState.lastUpdate = GetTime()

    -- Fire event so display can update
    BR.CallbackRegistry:TriggerEvent("BuffStateChanged")
end

---Set the player class (called once on init)
---@param class ClassName
function BuffState.SetPlayerClass(class)
    playerClass = class
end

---Set the ready check state
---@param state boolean
function BuffState.SetReadyCheckState(state)
    inReadyCheck = state
end

---Get the ready check state
---@return boolean
function BuffState.GetReadyCheckState()
    return inReadyCheck
end

---Set the vehicle state
---@param state boolean
function BuffState.SetInVehicle(state)
    inVehicle = state
end

---Get the vehicle state
---@return boolean
function BuffState.GetInVehicle()
    return inVehicle
end

---Set the combat/encounter state (single source of truth for aura restrictions)
---Called by the Display layer on ENCOUNTER_START, PLAYER_REGEN_DISABLED, etc.
---@param state boolean
function BuffState.SetInCombat(state)
    inCombat = state
end

-- ============================================================================
-- CACHE INVALIDATION
-- ============================================================================

---Invalidate content type cache (call on PLAYER_ENTERING_WORLD)
function BuffState.InvalidateContentTypeCache()
    cachedContentType = nil
    cachedDifficultyKey = nil
end

---Invalidate spec ID cache (call on PLAYER_ENTERING_WORLD, PLAYER_SPECIALIZATION_CHANGED)
function BuffState.InvalidateSpecCache()
    cachedSpecId = nil
    cachedPlayerRole = nil
end

---Get the player's current role (cached, invalidated on spec change)
---@return RoleType?
BuffState.GetPlayerRole = GetPlayerRole

---Invalidate spell knowledge cache (call on PLAYER_SPECIALIZATION_CHANGED)
function BuffState.InvalidateSpellCache()
    cachedSpellKnowledge = {}
    cachedSpecId = nil
    cachedPlayerRole = nil
end

---Check if off-hand slot has a weapon (cached)
---@return boolean
function BuffState.HasOffHandWeapon()
    if cachedHasOffHandWeapon == nil then
        local offhandItemID = GetInventoryItemID("player", 17) -- INVSLOT_OFFHAND
        if not offhandItemID then
            cachedHasOffHandWeapon = false
        else
            local _, _, _, _, _, itemClassID = GetItemInfoInstant(offhandItemID)
            cachedHasOffHandWeapon = itemClassID == 2 -- Enum.ItemClass.Weapon
        end
    end
    return cachedHasOffHandWeapon
end

---Invalidate off-hand weapon cache (call on PLAYER_EQUIPMENT_CHANGED, PLAYER_SPECIALIZATION_CHANGED)
function BuffState.InvalidateOffHandCache()
    cachedHasOffHandWeapon = nil
end

---Invalidate item ownership cache (call on BAG_UPDATE_DELAYED, PLAYER_EQUIPMENT_CHANGED)
function BuffState.InvalidateItemCache()
    cachedItemOwnership = {}
end

-- Export utility functions that display layer still needs
BR.StateHelpers = {
    GetPlayerSpecId = GetPlayerSpecId,
    FormatRemainingTime = FormatRemainingTime,
    UpdateEatingState = UpdateEatingState,
    ScanEatingState = ScanEatingState,
    GetEatingExpirationTime = GetEatingExpirationTime,
    GetCurrentContentType = GetCurrentContentType,
    IsCategoryVisibleForContent = IsCategoryVisibleForContent,
    GetBuffSettingKey = GetBuffSettingKey,
    IsBuffEnabled = IsBuffEnabled,
    GetLastTarget = GetLastTarget,
}

-- Export the module
BR.BuffState = BuffState
