local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local ProfileIO = CDM and CDM.ProfileIO

local API = {}
_G["Ayije_CDM_API"] = API

function API:ExportProfile(profileKey)
    if not Ayije_CDMDB or not Ayije_CDMDB.profiles then return nil end
    local profile = Ayije_CDMDB.profiles[profileKey]
    if not profile then return nil end
    if not ProfileIO or not ProfileIO.ExportLegacyProfile then return nil end
    return ProfileIO:ExportLegacyProfile(profile, profileKey)
end

function CDM:DecodeProfileString(profileString)
    if not ProfileIO or not ProfileIO.DecodeProfileString then return nil, "invalid_profile_data" end
    return ProfileIO:DecodeProfileString(profileString)
end

function API:DecodeProfileString(profileString)
    return CDM:DecodeProfileString(profileString)
end

local function ReportWagoMutationError(prefix, errCode)
    local handler = geterrorhandler and geterrorhandler()
    if handler then
        handler(string.format("%s: %s", tostring(prefix), tostring(errCode)))
    end
end

function API:ImportProfile(profileString, profileKey)
    if InCombatLockdown() then
        ReportWagoMutationError("wago import blocked", "combat_blocked")
        return
    end

    local data, decodeErr = CDM:DecodeProfileString(profileString)
    if not data then
        ReportWagoMutationError("wago import decode failed", decodeErr or "invalid_profile_data")
        return
    end

    local ok, importErr = CDM:ImportProfileData(profileKey, data)
    if not ok then
        ReportWagoMutationError("wago import failed", importErr or "apply_failed")
        return
    end

    local specID = CDM:GetCurrentSpecID()
    if specID then
        CDM:InvalidateSpellRegistryCache(specID)
    end
end

function API:SetProfile(profileKey)
    local ok, errCode = CDM:SetProfile(profileKey)
    if not ok then
        ReportWagoMutationError("wago set profile failed", errCode or "apply_failed")
    end
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
