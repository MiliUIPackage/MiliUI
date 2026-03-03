-- Config/ImportExport.lua - Profile Import/Export
-- Uses C_EncodingUtil APIs (Patch 11.1.5+) for CBOR serialization and compression

local AddonName = "Ayije_CDM"
local Runtime = _G[AddonName]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L

-- =========================================================================
-- EXPORT/IMPORT CONFIGURATION
-- =========================================================================

local ConfigKeys = ns.ConfigKeys or {}
local exportCategories = ConfigKeys.categories or {}
local exportCategoryOrder = ConfigKeys.order or {}
local METADATA_KEYS = { version = true, addon = true, timestamp = true, profileName = true }
local importExportLastStatus = nil

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

local function BuildKeysToExport(selectedCategories)
    local keysToExport = {}
    for categoryId, categoryDef in pairs(exportCategories) do
        if not selectedCategories or selectedCategories[categoryId] then
            for _, key in ipairs(categoryDef.keys) do
                keysToExport[key] = true
            end
        end
    end
    return keysToExport
end

local function BuildValidKeys()
    local validKeys = {}
    for key in pairs(METADATA_KEYS) do
        validKeys[key] = true
    end
    for _, categoryDef in pairs(exportCategories) do
        for _, key in ipairs(categoryDef.keys) do
            validKeys[key] = true
        end
    end
    return validKeys
end

-- =========================================================================
-- CORE EXPORT/IMPORT FUNCTIONS
-- =========================================================================

--- Export profile to Base64 string
-- @param categories table Optional table of category names to include (nil = all)
-- @return string Base64 encoded profile string
function API:ExportProfile(categories)
    local profile = {
        version = 1,
        addon = AddonName,
        timestamp = time(),
        profileName = CDM.activeProfileName,
    }

    -- Collect keys from selected categories
    local keysToExport = BuildKeysToExport(categories)

    -- Copy values from SavedVariables
    for key in pairs(keysToExport) do
        local value = CDM.db[key]
        if value ~= nil then
            -- Deep copy tables to avoid reference issues
            if type(value) == "table" then
                profile[key] = API:DeepCopy(value)
            else
                profile[key] = value
            end
        end
    end

    -- Serialize with CBOR, compress, and encode to Base64
    local success, cbor = pcall(C_EncodingUtil.SerializeCBOR, profile)
    if not success then
        print("|cffff0000[CDM Export]|r " .. string.format(L["Serialization failed: %s"], tostring(cbor)))
        return nil
    end

    local compressOk, compressed = pcall(C_EncodingUtil.CompressString, cbor)
    if not compressOk or not compressed then
        print("|cffff0000[CDM Export]|r " .. string.format(L["Compression failed: %s"], tostring(compressed)))
        return nil
    end

    local encodeOk, base64 = pcall(C_EncodingUtil.EncodeBase64, compressed)
    if not encodeOk or not base64 then
        print("|cffff0000[CDM Export]|r " .. string.format(L["Base64 encoding failed: %s"], tostring(base64)))
        return nil
    end

    return "!ACDM:" .. base64
end

--- Import profile from Base64 string
-- @param encodedString string Base64 encoded profile string
-- @return boolean success, string message
function API:ImportProfile(encodedString)
    if not encodedString or encodedString == "" then
        return false, L["No import string provided"]
    end

    -- Clean up the string (remove whitespace)
    encodedString = encodedString:gsub("%s+", "")

    -- Strip prefix if present
    if encodedString:sub(1, 6) == "!ACDM:" then
        encodedString = encodedString:sub(7)
    end

    -- Decode Base64
    local success, compressed = pcall(C_EncodingUtil.DecodeBase64, encodedString)
    if not success or not compressed then
        return false, L["Invalid Base64 encoding"]
    end

    -- Decompress
    local decompressed
    success, decompressed = pcall(C_EncodingUtil.DecompressString, compressed)
    if not success or not decompressed then
        return false, L["Decompression failed"]
    end

    -- Deserialize CBOR
    local profile
    success, profile = pcall(C_EncodingUtil.DeserializeCBOR, decompressed)
    if not success or not profile then
        return false, L["Invalid profile data"]
    end

    -- Validate profile
    if not profile.version or not profile.addon then
        return false, L["Missing profile metadata"]
    end

    if profile.addon ~= AddonName then
        return false, string.format(L["Profile is for a different addon: %s"], tostring(profile.addon))
    end

    -- Validate profile version (allow forward compatibility for minor versions)
    if type(profile.version) ~= "number" or profile.version < 1 then
        return false, L["Invalid profile version"]
    end

    -- Build whitelist of valid keys from exportCategories
    local validKeys = BuildValidKeys()

    local function IsValidType(key, value)
        local default = CDM.defaults[key]
        if default == nil then return true end
        return type(value) == type(default)
    end

    -- Determine profile name (deduplicate if it already exists)
    local profileName = profile.profileName or "Imported"
    local baseName = profileName
    local suffix = 1
    while Ayije_CDMDB.profiles[profileName] do
        suffix = suffix + 1
        profileName = baseName .. " (" .. suffix .. ")"
    end

    -- Create new profile with defaults
    local newProfile = {}
    for key, value in pairs(CDM.defaults) do
        if type(value) == "table" then
            newProfile[key] = API:DeepCopy(value)
        else
            newProfile[key] = value
        end
    end

    -- Apply imported settings over defaults
    local imported = 0
    for key, value in pairs(profile) do
        if validKeys[key] and not METADATA_KEYS[key] and IsValidType(key, value) then
            if type(value) == "table" then
                newProfile[key] = API:DeepCopy(value)
            else
                newProfile[key] = value
            end
            imported = imported + 1
        end
    end

    -- Register and activate the new profile
    local ok, importErr = API:ImportProfileData(profileName, newProfile)
    if not ok then
        return false, importErr or L["Failed to import profile"]
    end

    -- Invalidate spell registry cache
    if API.InvalidateSpellRegistryCache then
        local specIndex = GetSpecialization()
        if specIndex then
            local specID = GetSpecializationInfo(specIndex)
            if specID then
                API:InvalidateSpellRegistryCache(specID)
            end
        end
    end

    return true, string.format(L["Imported %d settings as '%s'"], imported, profileName)
end

-- =========================================================================
-- UI CREATION
-- =========================================================================

local function CreateImportExportTab(page, tabId)
    -- Export Section
    local exportHeader = UI.CreateHeader(page, L["Export Profile"])
    exportHeader:SetPoint("TOPLEFT", 35, -40)

    local exportDesc = page:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    exportDesc:SetPoint("TOPLEFT", exportHeader, "BOTTOMLEFT", 0, -15)
    exportDesc:SetText(L["Select categories to include, then click Export."])
    UI.SetTextMuted(exportDesc)

    -- Category checkboxes
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

    -- Export button
    local exportBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    exportBtn:SetSize(120, 26)
    local rowCount = math.max(1, math.ceil(categoryCount / 3))
    local exportBtnYOffset = -12 - (rowCount * rowHeight) - 8
    exportBtn:SetPoint("TOPLEFT", exportDesc, "BOTTOMLEFT", 0, exportBtnYOffset)
    exportBtn:SetText(L["Export"])

    -- Export result editbox (read-only, for copying)
    local exportBoxLabel = page:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    exportBoxLabel:SetPoint("TOPLEFT", exportBtn, "BOTTOMLEFT", 0, -16)
    exportBoxLabel:SetText(L["Export String (Ctrl+C to copy):"])
    UI.SetTextMuted(exportBoxLabel)

    local exportBoxFrame, exportEditBox = UI.CreateScrollableEditBox(page, 420, 80, 380)
    exportBoxFrame:SetPoint("TOPLEFT", exportBoxLabel, "BOTTOMLEFT", 0, -4)

    exportBtn:SetScript("OnClick", function()
        -- Gather selected categories
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

    -- Import Section
    local importHeader = UI.CreateHeader(page, L["Import Profile"], exportBoxFrame, -15)

    local importDesc = page:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    importDesc:SetPoint("TOPLEFT", importHeader, "BOTTOMLEFT", 0, -15)
    importDesc:SetText(L["Paste an export string below and click Import."])
    UI.SetTextMuted(importDesc)

    local importBoxFrame, importEditBox = UI.CreateScrollableEditBox(page, 420, 80, 380)
    importBoxFrame:SetPoint("TOPLEFT", importDesc, "BOTTOMLEFT", 0, -8)

    -- Import button
    local importBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    importBtn:SetSize(120, 26)
    importBtn:SetPoint("TOPLEFT", importBoxFrame, "BOTTOMLEFT", 0, -6)
    importBtn:SetText(L["Import"])

    -- Import status text
    local importStatus = page:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    importStatus:SetPoint("LEFT", importBtn, "RIGHT", 12, 0)
    importStatus:SetText("")
    UI.SetTextMuted(importStatus)

    local savedImportStatus = importExportLastStatus
    if savedImportStatus and savedImportStatus.message then
        importStatus:SetText(savedImportStatus.message)
        if savedImportStatus.success then
            UI.SetTextSuccess(importStatus)
        else
            UI.SetTextError(importStatus)
        end
    end

    importBtn:SetScript("OnClick", function()
        local importString = importEditBox:GetText()
        local success, message = API:ImportProfile(importString)
        importExportLastStatus = {
            success = success,
            message = message,
        }

        if success then
            importEditBox:SetText("")
            if API.RebuildConfigFrame then
                API:RebuildConfigFrame("importexport")
            else
                importStatus:SetText(message)
                UI.SetTextSuccess(importStatus)
            end
        else
            importStatus:SetText(message)
            UI.SetTextError(importStatus)
        end
    end)

    -- Clear button
    local clearBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    clearBtn:SetSize(80, 26)
    clearBtn:SetPoint("LEFT", importBtn, "RIGHT", 8, 0)
    clearBtn:SetText(L["Clear"])
    clearBtn:SetScript("OnClick", function()
        importExportLastStatus = nil
        importEditBox:SetText("")
        importStatus:SetText("")
        UI.SetTextMuted(importStatus)
    end)

    -- Adjust status position after clear button
    importStatus:ClearAllPoints()
    importStatus:SetPoint("LEFT", clearBtn, "RIGHT", 12, 0)
end

-- Register this tab
API:RegisterConfigTab("importexport", L["Import/Export"], CreateImportExportTab, 12)
