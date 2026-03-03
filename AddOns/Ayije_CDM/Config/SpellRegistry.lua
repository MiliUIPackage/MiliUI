-- Config/SpellRegistry.lua

local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

CDM.SpellRegistry = {}

local secondarySet = {}
local tertiarySet = {}
local colorRegistry = {}
local currentSpecID = nil
local cacheValid = false

CDM.registryCache = CDM.registryCache or {}

-- =========================================================================
-- INTERNAL HELPERS
-- =========================================================================

local function InvalidateCache()
    cacheValid = false
    if currentSpecID then
        CDM.registryCache[currentSpecID] = nil
    end
end

local function RebuildCache(specID)
    table.wipe(secondarySet)
    table.wipe(tertiarySet)
    table.wipe(colorRegistry)

    if CDM.registryCache[specID] then
        local success, cached = pcall(C_EncodingUtil.DeserializeCBOR, CDM.registryCache[specID])
        if success and cached then
            if cached.secondarySet then
                for id, idx in pairs(cached.secondarySet) do
                    secondarySet[id] = idx
                end
            end
            if cached.tertiarySet then
                for id, idx in pairs(cached.tertiarySet) do
                    tertiarySet[id] = idx
                end
            end
            if cached.colorRegistry then
                for id, color in pairs(cached.colorRegistry) do
                    colorRegistry[id] = color
                end
            end
            cacheValid = true
            currentSpecID = specID
            return
        end
    end

    local registry = CDM.db and CDM.db.spellRegistry and CDM.db.spellRegistry[specID]
    if not registry then
        cacheValid = true
        currentSpecID = specID
        return
    end

    if registry.secondary then
        for i, id in ipairs(registry.secondary) do
            secondarySet[id] = i
        end
    end

    if registry.tertiary then
        for i, id in ipairs(registry.tertiary) do
            tertiarySet[id] = i
        end
    end

    if registry.colors then
        for id, color in pairs(registry.colors) do
            colorRegistry[id] = color
        end
    end

    cacheValid = true
    currentSpecID = specID

    local success, cbor = pcall(C_EncodingUtil.SerializeCBOR, {
        secondarySet = secondarySet,
        tertiarySet = tertiarySet,
        colorRegistry = colorRegistry
    })
    if success then
        CDM.registryCache[specID] = cbor
    end
end

local function EnsureCache(specID)
    if not cacheValid or currentSpecID ~= specID then
        RebuildCache(specID)
    end
end

local function AddUniqueToArray(array, spellID)
    for _, id in ipairs(array) do
        if id == spellID then return false end
    end
    table.insert(array, spellID)
    return true
end

local function RemoveFromArray(array, spellID)
    for i = #array, 1, -1 do
        if array[i] == spellID then
            table.remove(array, i)
            return true
        end
    end
    return false
end

local function FindArrayValueIndex(array, spellID)
    for i, id in ipairs(array) do
        if id == spellID then
            return i
        end
    end
    return nil
end

local function CreateEmptyRegistry()
    return {
        secondary = {},
        tertiary = {},
        colors = {}
    }
end

local function IsEmptyTable(t)
    return type(t) == "table" and next(t) == nil
end

local function IsRegistrySpecEmpty(node)
    if type(node) ~= "table" then return true end
    if not IsEmptyTable(node.secondary) then return false end
    if not IsEmptyTable(node.tertiary) then return false end
    if not IsEmptyTable(node.colors) then return false end
    if node.glowEnabled ~= nil and not IsEmptyTable(node.glowEnabled) then return false end
    if node.glowColors ~= nil and not IsEmptyTable(node.glowColors) then return false end
    return true
end

local function CompactRegistrySpec(specID, profile)
    local db = profile or CDM.db
    if type(db) ~= "table" or type(db.spellRegistry) ~= "table" then return end
    local node = db.spellRegistry[specID]
    if not node then return end

    if IsEmptyTable(node.glowEnabled) then node.glowEnabled = nil end
    if IsEmptyTable(node.glowColors) then node.glowColors = nil end

    if IsRegistrySpecEmpty(node) then
        db.spellRegistry[specID] = nil
    end

    if IsEmptyTable(db.spellRegistry) then
        db.spellRegistry = nil
    end
end

local function EnsureRegistryStructure(specID)
    if not CDM.db then return nil end
    if not CDM.db.spellRegistry then
        CDM.db.spellRegistry = {}
    end
    if not CDM.db.spellRegistry[specID] then
        CDM.db.spellRegistry[specID] = { secondary = {}, tertiary = {}, colors = {} }
    end
    return CDM.db.spellRegistry[specID]
end

-- =========================================================================
-- PUBLIC API - LOOKUPS (O(1))
-- =========================================================================

function CDM.SpellRegistry:IsSecondary(specID, spellID)
    EnsureCache(specID)
    return secondarySet[spellID] or false
end

function CDM.SpellRegistry:IsTertiary(specID, spellID)
    EnsureCache(specID)
    return tertiarySet[spellID] or false
end

function CDM.SpellRegistry:GetColor(specID, spellID)
    EnsureCache(specID)
    return colorRegistry[spellID]
end

function CDM.SpellRegistry:GetSecondarySet(specID)
    EnsureCache(specID)
    return secondarySet
end

function CDM.SpellRegistry:GetTertiarySet(specID)
    EnsureCache(specID)
    return tertiarySet
end

function CDM.SpellRegistry:GetColorRegistry(specID)
    EnsureCache(specID)
    return colorRegistry
end

-- =========================================================================
-- PUBLIC API - MUTATIONS
-- =========================================================================

function CDM.SpellRegistry:Save(specID, spellID, isSecondary, isTertiary, color)
    local registry = EnsureRegistryStructure(specID)
    if not registry then return end

    local secondaryIndex = FindArrayValueIndex(registry.secondary, spellID)
    local tertiaryIndex = FindArrayValueIndex(registry.tertiary, spellID)

    local wasSecondary = secondaryIndex ~= nil
    local wasTertiary = tertiaryIndex ~= nil
    local stayingInPlace = (wasSecondary and isSecondary) or (wasTertiary and isTertiary)

    if not stayingInPlace then
        if secondaryIndex then
            table.remove(registry.secondary, secondaryIndex)
        end
        if tertiaryIndex then
            table.remove(registry.tertiary, tertiaryIndex)
        end

        if isSecondary then
            AddUniqueToArray(registry.secondary, spellID)
        end
        if isTertiary then
            AddUniqueToArray(registry.tertiary, spellID)
        end
    end

    if color then
        registry.colors[spellID] = { r = color.r, g = color.g, b = color.b, a = color.a or 1 }
    end

    InvalidateCache()
end

function CDM.SpellRegistry:Remove(specID, spellID)
    if not CDM.db or not CDM.db.spellRegistry then return end
    local registry = CDM.db.spellRegistry[specID]
    if not registry then return end

    RemoveFromArray(registry.secondary, spellID)
    RemoveFromArray(registry.tertiary, spellID)
    registry.colors[spellID] = nil

    if registry.glowEnabled then
        registry.glowEnabled[spellID] = nil
    end
    if registry.glowColors then
        registry.glowColors[spellID] = nil
    end

    CompactRegistrySpec(specID)
    InvalidateCache()
end

function CDM.SpellRegistry:Reorder(specID, spellID, fromCategory, direction)
    local registry = EnsureRegistryStructure(specID)
    if not registry or not registry[fromCategory] then return false end

    local index = FindArrayValueIndex(registry[fromCategory], spellID)
    if not index then return false end

    local otherCategory = (fromCategory == "secondary") and "tertiary" or "secondary"

    if direction == "up" then
        if index > 1 then
            registry[fromCategory][index], registry[fromCategory][index - 1] =
                registry[fromCategory][index - 1], registry[fromCategory][index]
        elseif fromCategory == "tertiary" then
            table.remove(registry[fromCategory], index)
            table.insert(registry[otherCategory], spellID)
        else
            return false
        end
    elseif direction == "down" then
        if index < #registry[fromCategory] then
            registry[fromCategory][index], registry[fromCategory][index + 1] =
                registry[fromCategory][index + 1], registry[fromCategory][index]
        elseif fromCategory == "secondary" then
            table.remove(registry[fromCategory], index)
            table.insert(registry[otherCategory], 1, spellID)
        else
            return false
        end
    else
        return false
    end

    InvalidateCache()
    return true
end

function CDM.SpellRegistry:Refresh(specID)
    RebuildCache(specID)
end

function CDM.SpellRegistry:GetRaw(specID)
    if not CDM.db or not CDM.db.spellRegistry then
        return CreateEmptyRegistry()
    end

    local registry = CDM.db.spellRegistry[specID]
    if not registry then
        return CreateEmptyRegistry()
    end

    local copy = CreateEmptyRegistry()

    if registry.secondary then
        for i, id in ipairs(registry.secondary) do
            copy.secondary[i] = id
        end
    end

    if registry.tertiary then
        for i, id in ipairs(registry.tertiary) do
            copy.tertiary[i] = id
        end
    end

    if registry.colors then
        for id, color in pairs(registry.colors) do
            copy.colors[id] = { r = color.r, g = color.g, b = color.b, a = color.a }
        end
    end

    return copy
end

-- =========================================================================
-- DEBUG API
-- =========================================================================

function CDM.SpellRegistry:GetCacheStatus()
    local secondaryCount = 0
    local tertiaryCount = 0
    local colorCount = 0

    for _ in pairs(secondarySet) do secondaryCount = secondaryCount + 1 end
    for _ in pairs(tertiarySet) do tertiaryCount = tertiaryCount + 1 end
    for _ in pairs(colorRegistry) do colorCount = colorCount + 1 end

    return {
        valid = cacheValid,
        specID = currentSpecID,
        secondaryCount = secondaryCount,
        tertiaryCount = tertiaryCount,
        colorCount = colorCount,
    }
end

-- =========================================================================
-- COMPACTION API
-- =========================================================================

function CDM.SpellRegistry:CompactSpec(specID)
    CompactRegistrySpec(specID)
end

function CDM.SpellRegistry:CompactAll(profile)
    local db = profile or CDM.db
    if type(db) ~= "table" or type(db.spellRegistry) ~= "table" then return end

    local specIDs = {}
    for specID in pairs(db.spellRegistry) do
        specIDs[#specIDs + 1] = specID
    end

    for _, specID in ipairs(specIDs) do
        CompactRegistrySpec(specID, db)
    end
end
