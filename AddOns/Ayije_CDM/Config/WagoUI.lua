local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

local API = {}
_G["Ayije_CDM_API"] = API

function API:ExportProfile(profileKey)
    if not Ayije_CDMDB or not Ayije_CDMDB.profiles then return nil end
    local profile = Ayije_CDMDB.profiles[profileKey]
    if not profile then return nil end

    local data = CDM:DeepCopy(profile)

    local ok, cbor = pcall(C_EncodingUtil.SerializeCBOR, data)
    if not ok or not cbor then return nil end

    local ok2, compressed = pcall(C_EncodingUtil.CompressString, cbor)
    if not ok2 or not compressed then return nil end

    local ok3, base64 = pcall(C_EncodingUtil.EncodeBase64, compressed)
    if not ok3 or not base64 then return nil end

    return base64
end

function API:ImportProfile(profileString, profileKey)
    local data = self:DecodeProfileString(profileString)
    if not data then return end

    CDM:ImportProfileData(profileKey, data)

    local specID = CDM:GetCurrentSpecID()
    if specID then
        CDM:InvalidateSpellRegistryCache(specID)
    end
end

function API:DecodeProfileString(profileString)
    if not profileString or profileString == "" then return nil end

    local ok, compressed = pcall(C_EncodingUtil.DecodeBase64, profileString)
    if not ok or not compressed then return nil end

    local ok2, decompressed = pcall(C_EncodingUtil.DecompressString, compressed)
    if not ok2 or not decompressed then return nil end

    local ok3, data = pcall(C_EncodingUtil.DeserializeCBOR, decompressed)
    if not ok3 or not data then return nil end

    return data
end

function API:SetProfile(profileKey)
    CDM:SetProfile(profileKey)
end

function API:GetProfileKeys()
    local keys = {}
    if Ayije_CDMDB and Ayije_CDMDB.profiles then
        for name in pairs(Ayije_CDMDB.profiles) do
            keys[name] = true
        end
    end
    return keys
end

function API:GetCurrentProfileKey()
    return CDM:GetActiveProfileName() or "Default"
end

function API:OpenConfig()
    if InCombatLockdown() then return end
    if not C_AddOns.IsAddOnLoaded("Ayije_CDM_Options") then
        local loaded = C_AddOns.LoadAddOn("Ayije_CDM_Options")
        if not loaded then return end
    end
    CDM:ShowConfig()
end

function API:CloseConfig()
    local frame = _G["Ayije_CDMConfigFrame"]
    if frame and frame:IsShown() then
        frame:Hide()
    end
end
