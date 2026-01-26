local _, ns = ...

local ProfileAPI = {}
ns.ProfileAPI = ProfileAPI

local LibDeflate = LibStub("LibDeflate")
local LibSerialize = LibStub("LibSerialize")

local EXPORT_PREFIX = "CMC1:"

function ProfileAPI:GetProfiles()
    if not ns.db then
        return {}
    end
    local profiles = {}
    ns.db:GetProfiles(profiles)
    return profiles
end

function ProfileAPI:GetCurrentProfile()
    if not ns.db then
        return ""
    end
    return ns.db:GetCurrentProfile()
end

function ProfileAPI:SetProfile(profileName)
    if not ns.db then
        return
    end
    if profileName and profileName ~= "" then
        ns.db:SetProfile(profileName)
    end
end

function ProfileAPI:CreateProfile(profileName)
    if not ns.db then
        return false
    end
    if not profileName or profileName == "" then
        return false
    end
    ns.db:SetProfile(profileName)
    return true
end

function ProfileAPI:DeleteProfile(profileName)
    if not ns.db then
        return false
    end
    if not profileName or profileName == "" then
        return false
    end
    if profileName == ProfileAPI:GetCurrentProfile() then
        return false
    end
    local profiles = ProfileAPI:GetProfiles()
    local exists = false
    for _, name in ipairs(profiles) do
        if name == profileName then
            exists = true
            break
        end
    end
    if not exists then
        return false
    end
    ns.db:DeleteProfile(profileName)
    return true
end

function ProfileAPI:GetExportString()
    if not ns.db then
        return ""
    end

    local data = CopyTable(ns.db.profile)
    local serialized = LibSerialize:Serialize(data)
    local compressed = LibDeflate:CompressDeflate(serialized)
    local encoded = LibDeflate:EncodeForPrint(compressed)

    return EXPORT_PREFIX .. encoded
end

function ProfileAPI:GetExportStringByProfileName(profileName)
    if not ns.db or not ns.db.sv or not ns.db.sv.profiles or not ns.db.sv.profiles[profileName] then
        return ""
    end

    local data = CopyTable(ns.db.sv.profiles[profileName])
    local serialized = LibSerialize:Serialize(data)
    local compressed = LibDeflate:CompressDeflate(serialized)
    local encoded = LibDeflate:EncodeForPrint(compressed)

    return EXPORT_PREFIX .. encoded
end

function ProfileAPI:DecodeExportString(text)
    if not text or text == "" then
        return nil, "Empty input string."
    end

    local header = string.sub(text, 1, 5)
    if header ~= EXPORT_PREFIX then
        return nil, "Invalid format. Expected CMC1: prefix."
    end

    local payload = string.sub(text, 6)
    if not payload or payload == "" then
        return nil, "Empty payload."
    end

    local decoded = LibDeflate:DecodeForPrint(payload)
    if not decoded then
        return nil, "Failed to decode string."
    end

    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then
        return nil, "Failed to decompress data."
    end

    local success, data = LibSerialize:Deserialize(decompressed)
    if not success then
        return nil, "Failed to deserialize data."
    end

    return data
end

function ProfileAPI:ImportFromString(importString, profileName)
    if not ns.db then
        return false, "Database not initialized."
    end
    if not profileName or strtrim(profileName) == "" then
        return false, "Profile name is required."
    end

    local data, errorMsg = ProfileAPI:DecodeExportString(importString)
    if not data then
        return false, errorMsg or "Failed to decode import string."
    end

    local trimmedName = strtrim(profileName)
    ns.db:SetProfile(trimmedName)

    for key, value in pairs(data) do
        if type(value) == "table" then
            ns.db.profile[key] = CopyTable(value)
        else
            ns.db.profile[key] = value
        end
    end

    if ns.Addon and ns.Addon.RefreshConfig then
        ns.Addon:RefreshConfig()
    end
    return true
end

CooldownManagerCentered.ImportProfileFromString = ProfileAPI.ImportFromString
CooldownManagerCentered.ExportCurrentProfileToString = ProfileAPI.GetExportString
CooldownManagerCentered.ExportProfileToString = ProfileAPI.GetExportStringByProfileName
