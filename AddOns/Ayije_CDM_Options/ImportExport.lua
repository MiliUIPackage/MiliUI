local AddonName = "Ayije_CDM"
local Runtime = _G[AddonName]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L
local ProfileIO = CDM.ProfileIO

local ConfigKeys = ns.ConfigKeys or {}
local exportCategories = ConfigKeys.categories or {}
local exportCategoryOrder = ConfigKeys.order or {}
local METADATA_KEYS = { version = true, addon = true, timestamp = true, profileName = true }
local IMPORT_STATUS_SUCCESS_DURATION = 3

local LEGACY_MIGRATION_KEYS = {
    "sizeBuffSecondary", "sizeBuffTertiary",
    "buffSecondaryOffsetX", "buffSecondaryOffsetY",
    "buffTertiaryOffsetX", "buffTertiaryOffsetY",
    "buffSecondaryHorizontal", "buffTertiaryHorizontal",
    "countPositionSec", "countOffsetXSec", "countOffsetYSec",
    "countPositionTert", "countOffsetXTert", "countOffsetYTert",
}
local importExportLastStatus = nil
local importExportStatusTimer = nil
local activeStatusFontString = nil

local function CancelImportStatusTimer()
    if importExportStatusTimer then
        importExportStatusTimer:Cancel()
        importExportStatusTimer = nil
    end
end

ns.CancelImportStatusTimer = CancelImportStatusTimer

local function ClearImportStatus(fontString)
    CancelImportStatusTimer()
    importExportLastStatus = nil
    if fontString then
        fontString:SetText("")
        UI.SetTextMuted(fontString)
    end
end

local function ApplyImportStatus(fontString)
    local status = importExportLastStatus
    CancelImportStatusTimer()
    if not fontString then
        return
    end

    if not status or not status.message then
        fontString:SetText("")
        UI.SetTextMuted(fontString)
        return
    end

    if status.expiresAt and status.expiresAt <= GetTime() then
        ClearImportStatus(fontString)
        return
    end

    fontString:SetText(status.message)
    if status.success then
        UI.SetTextSuccess(fontString)
    else
        UI.SetTextError(fontString)
    end

    if status.expiresAt then
        importExportStatusTimer = C_Timer.NewTimer(math.max(0, status.expiresAt - GetTime()), function()
            importExportStatusTimer = nil
            importExportLastStatus = nil
            if fontString then
                fontString:SetText("")
                UI.SetTextMuted(fontString)
            end
        end)
    end
end

local function SetImportStatus(fontString, success, message)
    importExportLastStatus = {
        success = success,
        message = message,
        expiresAt = success and (GetTime() + IMPORT_STATUS_SUCCESS_DURATION) or nil,
    }
    ApplyImportStatus(activeStatusFontString or fontString)
end

local function MapImportErrorCode(errCode)
    if errCode == "invalid_base64" then
        return L["Invalid Base64 encoding"]
    end
    if errCode == "decompression_failed" then
        return L["Decompression failed"]
    end
    if errCode == "combat_blocked" then
        return L["Cannot open config while in combat"]
    end
    if errCode == "invalid_profile_version" then
        return L["Invalid profile version"]
    end
    if errCode == "missing_profile_metadata" then
        return L["Missing profile metadata"]
    end
    if errCode == "wrong_addon" then
        return L["Profile is for a different addon"]
    end
    if errCode == "empty" then
        return L["No import string provided"]
    end
    if errCode == "type_mismatch" then
        return L["Invalid profile data"]
    end
    if errCode == "apply_failed" then
        return L["Failed to import profile"]
    end
    return L["Invalid profile data"]
end

local function GetCategoryOrder()
    if exportCategoryOrder and #exportCategoryOrder > 0 then
        return exportCategoryOrder
    end

    local ordered = {}
    for categoryId in pairs(exportCategories) do
        ordered[#ordered + 1] = categoryId
    end
    table.sort(ordered)
    return ordered
end

function API:ExportProfile(categories)
    if not ProfileIO or not ProfileIO.ExportSegmentedProfile then
        return nil
    end

    local exportString, errCode, errValue = ProfileIO:ExportSegmentedProfile(
        CDM.db,
        categories,
        exportCategories,
        CDM.activeProfileName
    )

    if exportString then
        return exportString
    end

    if errCode == "serialization_failed" then
        print("|cffff0000[CDM Export]|r " .. string.format(L["Serialization failed: %s"], tostring(errValue)))
    elseif errCode == "compression_failed" then
        print("|cffff0000[CDM Export]|r " .. string.format(L["Compression failed: %s"], tostring(errValue)))
    elseif errCode == "base64_failed" then
        print("|cffff0000[CDM Export]|r " .. string.format(L["Base64 encoding failed: %s"], tostring(errValue)))
    elseif errCode == "no_categories_selected" then
        print("|cffff0000[CDM Export]|r " .. L["Select at least one category to export."])
    end
    return nil
end

function API:ImportProfile(encodedString)
    if not encodedString or encodedString == "" then
        return false, L["No import string provided"]
    end

    if not ProfileIO then
        return false, L["Invalid profile data"]
    end

    local payload, decodeErr = ProfileIO:DecodePayload(encodedString)
    if not payload then
        return false, MapImportErrorCode(decodeErr)
    end

    local prepared, buildErr = ProfileIO:BuildImportProfile(payload, {
        addonName = AddonName,
        metadataKeys = METADATA_KEYS,
        categoryDefs = exportCategories,
        defaults = CDM.defaults,
        legacyMigrationKeys = LEGACY_MIGRATION_KEYS,
        existingProfiles = Ayije_CDMDB and Ayije_CDMDB.profiles,
    })
    if not prepared then
        local code = buildErr and buildErr.code
        if code == "missing_profile_metadata" then
            return false, MapImportErrorCode(code)
        end
        if code == "wrong_addon" then
            return false, string.format(L["Profile is for a different addon: %s"], tostring(buildErr.addon))
        end
        if code == "type_mismatch" then
            return false, string.format(L["Type mismatch on key '%s': expected %s, got %s"], tostring(buildErr.key), tostring(buildErr.expected), tostring(buildErr.actual))
        end
        return false, MapImportErrorCode(code)
    end

    local ok, importErr = API:ImportProfileData(prepared.profileName, prepared.profileData)
    if not ok then
        local mapped = MapImportErrorCode(importErr)
        return false, mapped or importErr or L["Failed to import profile"]
    end

    if API.InvalidateSpellRegistryCache then
        local specIndex = GetSpecialization()
        if specIndex then
            local specID = GetSpecializationInfo(specIndex)
            if specID then
                API:InvalidateSpellRegistryCache(specID)
            end
        end
    end

    return true, string.format(L["Imported %d settings as '%s'"], prepared.importedCount, prepared.profileName)
end

local function CreateImportExportTab(page, tabId)
    local exportHeader = UI.CreateHeader(page, L["Export Profile"])
    exportHeader:SetPoint("TOPLEFT", 35, -40)

    local exportDesc = page:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    exportDesc:SetPoint("TOPLEFT", exportHeader, "BOTTOMLEFT", 0, -15)
    exportDesc:SetText(L["Select categories to include, then click Export."])
    UI.SetTextMuted(exportDesc)

    local checkboxes = {}
    local sortedCategories = GetCategoryOrder()
    local categoryCount = 0
    local columnWidth = 155
    local labelWidth = 115
    local rowHeight = 36

    for i, categoryId in ipairs(sortedCategories) do
        local categoryDef = exportCategories[categoryId]
        if categoryDef then
            categoryCount = categoryCount + 1
            local checkbox = UI.CreateModernCheckbox(
                page,
                categoryDef.label,
                true,  -- default checked
                nil    -- no immediate callback needed
            )

            local col = (categoryCount - 1) % 3
            local row = math.floor((categoryCount - 1) / 3)
            checkbox:SetPoint("TOPLEFT", exportDesc, "BOTTOMLEFT", col * columnWidth, -12 - (row * rowHeight))
            checkbox:SetSize(columnWidth - 10, rowHeight)
            if checkbox.label then
                checkbox.label:SetWidth(labelWidth)
                checkbox.label:SetJustifyH("LEFT")
                checkbox.label:SetWordWrap(true)
            end

            checkboxes[categoryId] = checkbox
        end
    end

    local exportBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    exportBtn:SetSize(120, 26)
    local rowCount = math.max(1, math.ceil(categoryCount / 3))
    local exportBtnYOffset = -12 - (rowCount * rowHeight) - 8
    exportBtn:SetPoint("TOPLEFT", exportDesc, "BOTTOMLEFT", 0, exportBtnYOffset)
    exportBtn:SetText(L["Export"])

    local exportBoxLabel = page:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    exportBoxLabel:SetPoint("TOPLEFT", exportBtn, "BOTTOMLEFT", 0, -16)
    exportBoxLabel:SetText(L["Export String (Ctrl+C to copy):"])
    UI.SetTextMuted(exportBoxLabel)

    local exportBoxFrame, exportEditBox = UI.CreateScrollableEditBox(page, 420, 80, 380)
    exportBoxFrame:SetPoint("TOPLEFT", exportBoxLabel, "BOTTOMLEFT", 0, -4)

    exportBtn:SetScript("OnClick", function()
        local selectedCategories = {}
        for categoryId, checkbox in pairs(checkboxes) do
            if checkbox:GetChecked() then
                selectedCategories[categoryId] = true
            end
        end

        local exportString = API:ExportProfile(selectedCategories)
        if exportString then
            exportEditBox:SetText(exportString)
            exportEditBox:HighlightText()
            exportEditBox:SetFocus()
            print("|cff00ff00[CDM]|r " .. L["Profile exported! Copy the string above."])
        else
            exportEditBox:SetText("")
            print("|cffff0000[CDM]|r " .. L["Export failed."])
        end
    end)

    local importHeader = UI.CreateHeader(page, L["Import Profile"], exportBoxFrame, -15)

    local importDesc = page:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    importDesc:SetPoint("TOPLEFT", importHeader, "BOTTOMLEFT", 0, -15)
    importDesc:SetText(L["Paste an export string below and click Import."])
    UI.SetTextMuted(importDesc)

    local importBoxFrame, importEditBox = UI.CreateScrollableEditBox(page, 420, 80, 380)
    importBoxFrame:SetPoint("TOPLEFT", importDesc, "BOTTOMLEFT", 0, -8)

    local importBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    importBtn:SetSize(120, 26)
    importBtn:SetPoint("TOPLEFT", importBoxFrame, "BOTTOMLEFT", 0, -6)
    importBtn:SetText(L["Import"])

    local importStatus = page:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    importStatus:SetPoint("LEFT", importBtn, "RIGHT", 12, 0)
    importStatus:SetText("")
    UI.SetTextMuted(importStatus)
    activeStatusFontString = importStatus
    ApplyImportStatus(importStatus)

    importBtn:SetScript("OnClick", function()
        local importString = importEditBox:GetText()
        local success, message = API:ImportProfile(importString)
        SetImportStatus(importStatus, success, message)

        -- RebuildConfigFrame is already triggered by ImportProfileData
        -- via QueueCanonicalProfileRefresh; no explicit call needed here.
    end)

    local clearBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    clearBtn:SetSize(80, 26)
    clearBtn:SetPoint("LEFT", importBtn, "RIGHT", 8, 0)
    clearBtn:SetText(L["Clear"])
    clearBtn:SetScript("OnClick", function()
        importEditBox:SetText("")
        ClearImportStatus(importStatus)
    end)

    importStatus:ClearAllPoints()
    importStatus:SetPoint("LEFT", clearBtn, "RIGHT", 12, 0)
end

API:RegisterConfigTab("importexport", L["Import/Export"], CreateImportExportTab, 12)
