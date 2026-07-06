local _, BR = ...

-- ============================================================================
-- IMPORT/EXPORT FUNCTIONS
-- ============================================================================

local LibDeflate = LibStub:GetLibrary("LibDeflate")

-- Prefix scheme: !BR_<TAG>_<payload> where TAG is one or more letters.
-- Legacy strings (!BR_<base64>) have no tag; standard base64 never contains '_',
-- so the tagged-pattern match is unambiguous.
local LEGACY_PREFIX = "!BR_"
local COMPRESSED_PREFIX = "!BR_C_"
local TAG_PATTERN = "^!BR_(%a+)_(.*)$"
local DEFLATE_CONFIG = { level = 9 }

-- Deep copy a table
local function DeepCopy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for k, v in pairs(orig) do
            copy[k] = DeepCopy(v)
        end
    else
        copy = orig
    end
    return copy
end

-- Detect the format of a prefixed import string.
-- Returns (payload, tag) or (nil, nil) if the prefix is missing/unknown.
-- tag == "" for legacy uncompressed strings, "C" for deflate-compressed strings.
local function StripPrefix(str)
    local tag, payload = str:match(TAG_PATTERN)
    if tag then
        return payload, tag
    end
    if str:sub(1, #LEGACY_PREFIX) == LEGACY_PREFIX then
        return str:sub(#LEGACY_PREFIX + 1), ""
    end
    return nil, nil
end

-- Serialize a Lua table to a deflate-compressed, print-encoded payload (no prefix).
local function SerializeTable(tbl)
    local success, cbor = pcall(C_EncodingUtil.SerializeCBOR, tbl)
    if not success then
        return nil
    end
    local compressed = LibDeflate:CompressDeflate(cbor, DEFLATE_CONFIG)
    if not compressed then
        return nil
    end
    return LibDeflate:EncodeForPrint(compressed)
end

-- Deserialize a prefixed import string back to a Lua table.
-- Accepts both the legacy !BR_<base64(cbor)> and the new !BR_C_<print(deflate(cbor))> formats.
local function DeserializeTable(str)
    if not str or str:trim() == "" then
        return nil, "Empty input"
    end

    local payload, tag = StripPrefix(str)
    if not payload then
        return nil, "Invalid import string (missing prefix)"
    end

    local cbor
    if tag == "" then
        local ok, decoded = pcall(C_EncodingUtil.DecodeBase64, payload)
        if not ok or not decoded then
            return nil, "Invalid format: not valid base64"
        end
        cbor = decoded
    elseif tag == "C" then
        local decoded = LibDeflate:DecodeForPrint(payload)
        if not decoded then
            return nil, "Invalid format: not valid print encoding"
        end
        local decompressed = LibDeflate:DecompressDeflate(decoded)
        if not decompressed then
            return nil, "Invalid format: failed to decompress"
        end
        cbor = decompressed
    else
        return nil, "Invalid format: unknown tag '" .. tag .. "'"
    end

    local ok, data = pcall(C_EncodingUtil.DeserializeCBOR, cbor)
    if not ok or type(data) ~= "table" then
        return nil, "Invalid data: failed to deserialize"
    end

    return data
end

-- Export settings to a serialized string (only includes valid settings from defaults + customBuffs)
-- If sourceProfile is provided, exports from that table instead of the active profile.
local function ExportSettings(sourceProfile)
    local defaults = BR.defaults
    local prof = sourceProfile or BR.profile
    local export = {}

    -- Only export fields that exist in defaults
    for key in pairs(defaults) do
        if prof[key] ~= nil then
            export[key] = DeepCopy(prof[key])
        end
    end

    -- Also include custom buffs
    if prof.customBuffs then
        export.customBuffs = DeepCopy(prof.customBuffs)
    end

    -- Also include detached icon positions
    if prof.detachedIcons then
        export.detachedIcons = DeepCopy(prof.detachedIcons)
    end

    local result = SerializeTable(export)
    if not result then
        return nil, "Failed to serialize settings"
    end
    return COMPRESSED_PREFIX .. result
end

-- Import settings from a prefixed import string (full replacement of exported keys)
local function ImportSettings(prefixedStr)
    local defaults = BR.defaults
    local data, err = DeserializeTable(prefixedStr)
    if not data then
        return false, err
    end

    -- Wipe all exportable keys first so import is a full replacement, not a merge.
    -- This ensures keys present in the current profile but absent from the import
    -- string are cleared (e.g. old customBuffs, disabled enabledBuffs entries).
    for key in pairs(defaults) do
        if key ~= "minimap" then
            BR.profile[key] = nil
        end
    end
    BR.profile.customBuffs = nil
    BR.profile.detachedIcons = nil

    -- Apply imported data
    for k, v in pairs(data) do
        BR.profile[k] = DeepCopy(v)
    end

    -- Back-compat: pre-v44 export strings carry the legacy boolean tracking
    -- overrides instead of the per-context mode enums. Migrations don't re-run on
    -- import, so map them here (mirrors migration [44]) and clear the stale keys.
    -- Guard on the OLD key only: the new mode keys already hold a value in the
    -- profile (AceDB defaults), so a `p.outsideInstancesMode == nil` check would
    -- never fire and the legacy boolean would be dropped without converting.
    local p = BR.profile
    if p.selfOnlyOutsideInstances ~= nil then
        p.outsideInstancesMode = p.selfOnlyOutsideInstances and "self_only" or "default"
    end
    if p.hideOthersInCombat ~= nil then
        p.combatMode = p.hideOthersInCombat and "my_buffs" or "default"
    end
    if p.myBuffsOnlyWhileLeveling ~= nil then
        p.levelingMode = p.myBuffsOnlyWhileLeveling and "my_buffs" or "default"
    end
    p.selfOnlyOutsideInstances = nil
    p.hideOthersInCombat = nil
    p.myBuffsOnlyWhileLeveling = nil

    -- Ensure defaults sub-table exists and has the metatable (DeepCopy produces
    -- a plain table, and old export strings may not include a defaults key at all).
    if not BR.profile.defaults then
        BR.profile.defaults = {}
    end
    setmetatable(BR.profile.defaults, { __index = defaults.defaults })

    return true
end

-- ============================================================================
-- PUBLIC API (for external addon integration)
-- ============================================================================

--- PUBLIC API - used by Wago UI and other external addons. Do not remove or rename.
--- Export settings to a prefixed string that can be imported by other addons.
--- If profileKey is nil or matches the active profile, exports the active profile.
--- Otherwise reads from AceDB's raw saved variables.
--- @param profileKey string|nil Optional profile name to export
--- @return string|nil Encoded settings string with !BR_C_ prefix, or nil on error
--- @return string|nil Error message if export failed
function BuffReminders:Export(profileKey)
    local sourceProfile
    if profileKey and BR.aceDB and profileKey ~= BR.aceDB:GetCurrentProfile() then
        local rawProfile = BR.aceDB.sv and BR.aceDB.sv.profiles and BR.aceDB.sv.profiles[profileKey]
        if rawProfile then
            -- Wrap raw SV table with defaults so unset keys resolve the same as the active profile
            local profileDefaults = BR.aceDB.defaults and BR.aceDB.defaults.profile
            if profileDefaults then
                sourceProfile = setmetatable({}, {
                    __index = function(_, k)
                        local v = rawProfile[k]
                        if v ~= nil then
                            return v
                        end
                        return profileDefaults[k]
                    end,
                })
            else
                sourceProfile = rawProfile
            end
        end
        -- If rawProfile is nil, sourceProfile stays nil -> exports active profile (backward compat)
    end

    return ExportSettings(sourceProfile)
end

--- PUBLIC API - used by Wago UI and other external addons. Do not remove or rename.
--- Import settings from a prefixed string. Accepts both legacy (!BR_) and compressed
--- (!BR_C_) formats; the format is detected from the prefix tag.
--- If profileKey is provided, creates or switches to that profile before applying.
--- @param importString string The encoded settings string
--- @param profileKey string|nil Optional profile name to import into
--- @return boolean success Whether the import succeeded
--- @return string|nil error Error message if import failed
function BuffReminders:Import(importString, profileKey)
    if not importString or type(importString) ~= "string" then
        return false, "Invalid import string"
    end

    -- Validate prefix before any profile mutation so a malformed string can't
    -- create or switch profiles as a side effect.
    if not StripPrefix(importString) then
        return false, "Invalid import string (missing prefix)"
    end

    -- Use BatchOperation to suppress the intermediate refresh from SetProfile
    -- so we get a single RefreshAfterProfileChange after data is applied.
    local importSuccess, importErr
    BR.Profiles.BatchOperation(function()
        -- Switch to the target profile if specified (creates it if needed)
        if profileKey and type(profileKey) == "string" and BR.aceDB then
            BR.aceDB:SetProfile(profileKey)
        end
        importSuccess, importErr = ImportSettings(importString)
    end)

    if not importSuccess then
        return false, importErr
    end
    return true
end

--- PUBLIC API - Decode an import string without applying it.
--- Accepts both legacy (!BR_) and compressed (!BR_C_) formats.
--- @param importString string The encoded settings string
--- @return table|nil data Decoded settings table, or nil on error
--- @return string|nil error Error message if decode failed
function BuffReminders:DecodeProfileString(importString)
    if not importString or type(importString) ~= "string" then
        return nil, "Invalid import string"
    end
    return DeserializeTable(importString)
end

--- PUBLIC API - Return all existing profile keys in { [key] = true } format.
--- @return table<string, boolean>
function BuffReminders:GetProfileKeys()
    local result = {}
    for _, name in ipairs(BR.Profiles.ListProfiles()) do
        result[name] = true
    end
    return result
end

--- PUBLIC API - Return the key of the currently active profile.
--- @return string
function BuffReminders:GetCurrentProfileKey()
    return BR.Profiles.GetActiveProfileName()
end

--- PUBLIC API - Switch to an existing or new profile by key.
--- @param profileKey string
function BuffReminders:SetProfile(profileKey)
    if type(profileKey) ~= "string" then
        return
    end
    BR.Profiles.SwitchProfile(profileKey)
end

-- ============================================================================
-- WagoUI Pack API (thin wrappers matching expected method names)
-- ============================================================================

function BuffReminders:ExportProfile(profileKey)
    return self:Export(profileKey)
end

function BuffReminders:ImportProfile(profileString, profileKey)
    return self:Import(profileString, profileKey)
end

function BuffReminders:OpenConfig()
    BR.Options.Show()
end

function BuffReminders:CloseConfig()
    BR.Options.Hide()
end

BuffRemindersAPI = BuffReminders

-- Export module
BR.ImportExport = {
    DeepCopy = DeepCopy,
    Export = ExportSettings,
    Import = ImportSettings,
}
