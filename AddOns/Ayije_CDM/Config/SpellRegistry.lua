-- Config/SpellRegistry.lua

local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

CDM.SpellRegistry = {}

local colorRegistry = {}
local currentSpecID = nil
local cacheValid = false

-- =========================================================================
-- INTERNAL HELPERS
-- =========================================================================

local function InvalidateCache()
    cacheValid = false
end

local function RebuildCache(specID)
    table.wipe(colorRegistry)

    local registry = CDM.db and CDM.db.spellRegistry and CDM.db.spellRegistry[specID]
    if not registry then
        cacheValid = true
        currentSpecID = specID
        return
    end

    if registry.colors then
        for id, color in pairs(registry.colors) do
            colorRegistry[id] = color
        end
    end

    cacheValid = true
    currentSpecID = specID
end

local function EnsureCache(specID)
    if not cacheValid or currentSpecID ~= specID then
        RebuildCache(specID)
    end
end

local function CreateEmptyRegistry()
    return {
        colors = {}
    }
end

local function IsEmptyTable(t)
    return type(t) == "table" and next(t) == nil
end

local function IsRegistrySpecEmpty(node)
    if type(node) ~= "table" then return true end
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
        CDM.db.spellRegistry[specID] = { colors = {} }
    end
    return CDM.db.spellRegistry[specID]
end

-- =========================================================================
-- PUBLIC API - LOOKUPS (O(1))
-- =========================================================================

function CDM.SpellRegistry:GetColor(specID, spellID)
    EnsureCache(specID)
    if colorRegistry[spellID] then return colorRegistry[spellID] end
    local base = CDM.NormalizeToBase and CDM.NormalizeToBase(spellID)
    if base and base ~= spellID and colorRegistry[base] then return colorRegistry[base] end
    local stable = CDM.ResolveStableBase and CDM:ResolveStableBase(spellID)
    if stable and stable ~= spellID and stable ~= base and colorRegistry[stable] then return colorRegistry[stable] end
    return nil
end

function CDM.SpellRegistry:GetColorRegistry(specID)
    EnsureCache(specID)
    return colorRegistry
end

-- =========================================================================
-- PUBLIC API - MUTATIONS
-- =========================================================================

function CDM.SpellRegistry:Save(specID, spellID, color)
    local registry = EnsureRegistryStructure(specID)
    if not registry then return end

    if not registry.colors then registry.colors = {} end

    if color then
        registry.colors[spellID] = { r = color.r, g = color.g, b = color.b, a = color.a or 1 }
    end
    local base = CDM.NormalizeToBase and CDM.NormalizeToBase(spellID)
    if base and base ~= spellID then registry.colors[base] = nil end
    local stable = CDM.ResolveStableBase and CDM:ResolveStableBase(spellID)
    if stable and stable ~= spellID and stable ~= base then registry.colors[stable] = nil end

    InvalidateCache()
end

function CDM.SpellRegistry:ClearColor(specID, spellID)
    if not CDM.db or not CDM.db.spellRegistry then return end
    local registry = CDM.db.spellRegistry[specID]
    if not registry or not registry.colors then return end

    registry.colors[spellID] = nil
    local base = CDM.NormalizeToBase and CDM.NormalizeToBase(spellID)
    if base and base ~= spellID then registry.colors[base] = nil end
    local stable = CDM.ResolveStableBase and CDM:ResolveStableBase(spellID)
    if stable and stable ~= spellID and stable ~= base then registry.colors[stable] = nil end

    CompactRegistrySpec(specID)
    InvalidateCache()
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
    local colorCount = 0
    for _ in pairs(colorRegistry) do colorCount = colorCount + 1 end

    return {
        valid = cacheValid,
        specID = currentSpecID,
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
