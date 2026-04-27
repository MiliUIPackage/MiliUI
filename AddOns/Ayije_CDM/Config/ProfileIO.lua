local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

CDM.ProfileIO = CDM.ProfileIO or {}
local ProfileIO = CDM.ProfileIO

local WIRE_PREFIX = "!ACDM:"

local function CopyValue(value)
    if type(value) == "table" then
        return CDM:DeepCopy(value)
    end
    return value
end

local function NormalizeWireString(profileString)
    if type(profileString) ~= "string" then return nil end
    if profileString == "" then return nil end

    local normalized = profileString:gsub("[%s%z]", "")
    local _, prefixEnd = normalized:find(WIRE_PREFIX, 1, true)
    if prefixEnd then
        normalized = normalized:sub(prefixEnd + 1)
    end
    if normalized == "" then
        return nil
    end
    return normalized
end

function ProfileIO:EncodePayload(payload)
    local ok, cbor = pcall(C_EncodingUtil.SerializeCBOR, payload)
    if not ok or not cbor then
        return nil, "serialization_failed", cbor
    end

    local okCompressed, compressed = pcall(C_EncodingUtil.CompressString, cbor)
    if not okCompressed or not compressed then
        return nil, "compression_failed", compressed
    end

    local okBase64, base64 = pcall(C_EncodingUtil.EncodeBase64, compressed)
    if not okBase64 or not base64 then
        return nil, "base64_failed", base64
    end

    return WIRE_PREFIX .. base64
end

function ProfileIO:DecodePayload(profileString)
    local normalized = NormalizeWireString(profileString)
    if not normalized then
        return nil, "empty"
    end

    local okDecode, compressed = pcall(C_EncodingUtil.DecodeBase64, normalized)
    if not okDecode or not compressed then
        return nil, "invalid_base64"
    end

    local okDecompress, decompressed = pcall(C_EncodingUtil.DecompressString, compressed)
    if not okDecompress or not decompressed then
        return nil, "decompression_failed"
    end

    local okDeserialize, payload = pcall(C_EncodingUtil.DeserializeCBOR, decompressed)
    if not okDeserialize or type(payload) ~= "table" then
        return nil, "invalid_profile_data"
    end

    return payload
end

function ProfileIO:DecodeProfileString(profileString)
    local payload, errCode = self:DecodePayload(profileString)
    if not payload then
        return nil, errCode
    end
    local data
    if type(payload) == "table" and type(payload.data) == "table" and payload.profile_export_version then
        data = payload.data
    else
        data = payload
    end
    if type(data) ~= "table" then
        return nil, "invalid_profile_data"
    end
    return data
end

function ProfileIO:ExportLegacyProfile(profileData, profileName)
    if type(profileData) ~= "table" then return nil end
    local now = time()
    local payload = {
        profile_export_version = 1,
        name = profileName,
        profileName = profileName,
        data = CDM:DeepCopy(profileData),
        version = 1,
        addon = AddonName,
        timestamp = now,
    }
    return self:EncodePayload(payload)
end

function ProfileIO:ExportSegmentedProfile(profileData, selectedCategories, categoryDefs, profileName)
    if type(profileData) ~= "table" then return nil end

    local keySet = {}
    if type(categoryDefs) == "table" then
        for categoryId, categoryDef in pairs(categoryDefs) do
            if (not selectedCategories) or selectedCategories[categoryId] then
                local keys = categoryDef and categoryDef.keys
                if type(keys) == "table" then
                    for _, key in ipairs(keys) do
                        keySet[key] = true
                    end
                end
            end
        end
    end
    if not next(keySet) then
        return nil, "no_categories_selected"
    end

    local filtered = {}
    for key in pairs(keySet) do
        local value = profileData[key]
        if value ~= nil then
            filtered[key] = CopyValue(value)
        end
    end

    local segments = {}
    if type(categoryDefs) == "table" then
        for categoryId in pairs(categoryDefs) do
            if (not selectedCategories) or selectedCategories[categoryId] then
                segments[#segments + 1] = categoryId
            end
        end
        table.sort(segments)
    end

    local now = time()
    local payload = {
        profile_export_version = 1,
        profileName = profileName,
        toc_version = select(4, GetBuildInfo()),
        addon_version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(AddonName, "Version") or nil,
        segments = segments,
        data = filtered,
        addon = AddonName,
        timestamp = now,
    }
    return self:EncodePayload(payload)
end

local function IsValidImportedType(defaults, key, value)
    local defaultValue = defaults and defaults[key]
    if defaultValue == nil then
        return true, nil
    end
    return type(defaultValue) == type(value), type(defaultValue)
end

local function ResolveImportedProfileName(baseName, existingProfiles)
    local profileName = (baseName and baseName ~= "") and baseName or "Imported"
    if not existingProfiles or not existingProfiles[profileName] then
        return profileName
    end
    local rootName = profileName:match("^(.-)%s*%(%d+%)$") or profileName
    local suffix = 0
    profileName = rootName
    while existingProfiles[profileName] do
        suffix = suffix + 1
        profileName = rootName .. " (" .. suffix .. ")"
    end
    return profileName
end

function ProfileIO:BuildImportProfile(payload, addonName, defaults, categoryDefs, metadataKeys, legacyMigrationKeys, existingProfiles)
    local profileData, envelope
    if type(payload) == "table" and type(payload.data) == "table" and payload.profile_export_version then
        profileData = payload.data
        envelope = payload
    else
        profileData = payload
    end
    if type(profileData) ~= "table" then
        return nil, { code = "invalid_profile_data" }
    end

    addonName = addonName or AddonName
    local sourceAddon = payload.addon

    if not envelope then
        if payload.version == nil or payload.addon == nil then
            return nil, { code = "missing_profile_metadata" }
        end
        if type(payload.version) ~= "number" or payload.version < 1 then
            return nil, { code = "invalid_profile_version" }
        end
    elseif payload.profile_export_version and (type(payload.profile_export_version) ~= "number" or payload.profile_export_version < 1) then
        return nil, { code = "invalid_profile_version" }
    end

    if not sourceAddon then
        return nil, { code = "missing_profile_metadata" }
    end

    if sourceAddon ~= addonName then
        return nil, { code = "wrong_addon", addon = tostring(sourceAddon) }
    end

    defaults = defaults or {}
    metadataKeys = metadataKeys or {}
    legacyMigrationKeys = legacyMigrationKeys or {}

    local validKeys = {}
    if type(metadataKeys) == "table" then
        for key in pairs(metadataKeys) do
            validKeys[key] = true
        end
    end
    if type(categoryDefs) == "table" then
        for _, categoryDef in pairs(categoryDefs) do
            local keys = categoryDef and categoryDef.keys
            if type(keys) == "table" then
                for _, key in ipairs(keys) do
                    validKeys[key] = true
                end
            end
        end
    end

    local newProfile = {}
    local importedCount = 0
    local skippedCount = 0
    for key, value in pairs(profileData) do
        if validKeys[key] and not metadataKeys[key] then
            local isValidType = IsValidImportedType(defaults, key, value)
            if isValidType then
                newProfile[key] = CopyValue(value)
                importedCount = importedCount + 1
            else
                skippedCount = skippedCount + 1
            end
        end
    end

    for _, key in ipairs(legacyMigrationKeys) do
        if profileData[key] ~= nil and newProfile[key] == nil then
            newProfile[key] = CopyValue(profileData[key])
        end
    end

    local requestedName = payload.profileName or payload.name or "Imported"
    local profileName = ResolveImportedProfileName(requestedName, existingProfiles)

    return {
        profileName = profileName,
        profileData = newProfile,
        importedCount = importedCount,
        skippedCount = skippedCount,
    }
end
