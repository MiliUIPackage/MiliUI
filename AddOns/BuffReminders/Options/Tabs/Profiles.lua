local _, BR = ...

-- ============================================================================
-- PROFILES TAB
-- ============================================================================
-- AceDB profile dropdown, per-spec profile mapping (LibDualSpec), and
-- import/export text areas.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton

local LayoutSectionHeader = BR.Options.Helpers.LayoutSectionHeader

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local SECTION_GAP = BR.Options.Constants.SECTION_GAP

local abs = math.abs

local function Build(ctx)
    local C = ctx.constants
    local PANEL_WIDTH = C.PANEL_WIDTH
    local COL_PADDING = C.COL_PADDING

    local profilesContent = ctx:CreateSimpleContent("profiles", 600)

    local profX = COL_PADDING
    local profLayout = Components.VerticalLayout(profilesContent, { x = profX, y = -10 })
    local RefreshProfileDropdown

    LayoutSectionHeader(profLayout, profilesContent, L["Options.ActiveProfile"])

    local profileDesc = profilesContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    profileDesc:SetText(L["Options.ActiveProfile.Desc"])
    profLayout:AddText(profileDesc, 12, COMPONENT_GAP)

    local function GetProfileOptions()
        local names = BR.Profiles.ListProfiles()
        local options = {}
        for _, name in ipairs(names) do
            options[#options + 1] = { value = name, label = name }
        end
        return options
    end

    local function GetOtherProfileOptions()
        local names = BR.Profiles.ListProfiles()
        local active = BR.Profiles.GetActiveProfileName()
        local options = { { value = "", label = L["Options.SelectProfile"] } }
        for _, name in ipairs(names) do
            if name ~= active then
                options[#options + 1] = { value = name, label = name }
            end
        end
        return options
    end

    local PROF_LABEL_WIDTH = 70
    local PROF_DROPDOWN_WIDTH = 150

    local profileRow = CreateFrame("Frame", nil, profilesContent)
    profileRow:SetSize(PANEL_WIDTH - COL_PADDING * 2, 26)

    local profileDropdown = Components.Dropdown(profileRow, {
        label = L["Options.Profile"],
        labelWidth = PROF_LABEL_WIDTH,
        width = PROF_DROPDOWN_WIDTH,
        options = GetProfileOptions(),
        get = function()
            return BR.Profiles.GetActiveProfileName()
        end,
        onChange = function(value)
            BR.Profiles.SwitchProfile(value)
            RefreshProfileDropdown()
            Components.RefreshAll()
        end,
    })
    profileDropdown:SetPoint("LEFT", 0, 0)

    local btnX = PROF_LABEL_WIDTH + PROF_DROPDOWN_WIDTH + 10

    local newProfileBtn = CreateButton(profileRow, L["Options.New"], function()
        StaticPopup_Show("BUFFREMINDERS_NEW_PROFILE")
    end)
    newProfileBtn:SetSize(50, 22)
    newProfileBtn:SetPoint("LEFT", btnX, 0)

    local resetProfileBtn = CreateButton(profileRow, L["Dialog.Reset"], function()
        StaticPopup_Show("BUFFREMINDERS_RESET_DEFAULTS")
    end)
    resetProfileBtn:SetSize(50, 22)
    resetProfileBtn:SetPoint("LEFT", btnX + 54, 0)

    profLayout:Add(profileRow, 26, COMPONENT_GAP)

    local copyDropdown = Components.Dropdown(profilesContent, {
        label = L["Options.CopyFrom"],
        labelWidth = PROF_LABEL_WIDTH,
        width = PROF_DROPDOWN_WIDTH,
        options = GetOtherProfileOptions(),
        get = function()
            return ""
        end,
        onChange = function(value)
            if value == "" then
                return
            end
            BR.Profiles.CopyProfile(value)
            Components.RefreshAll()
        end,
    })
    profLayout:Add(copyDropdown, 26, COMPONENT_GAP)

    local deleteDropdown = Components.Dropdown(profilesContent, {
        label = L["Options.Delete"],
        labelWidth = PROF_LABEL_WIDTH,
        width = PROF_DROPDOWN_WIDTH,
        options = GetOtherProfileOptions(),
        get = function()
            return ""
        end,
        onChange = function(value)
            if value == "" then
                return
            end
            BR.Profiles.DeleteProfile(value)
            RefreshProfileDropdown()
        end,
    })
    profLayout:Add(deleteDropdown, 26, SECTION_GAP)

    RefreshProfileDropdown = function()
        local opts = GetProfileOptions()
        local otherOpts = GetOtherProfileOptions()
        profileDropdown.dropdown:SetOptions(opts)
        profileDropdown:SetValue(BR.Profiles.GetActiveProfileName())
        copyDropdown.dropdown:SetOptions(otherOpts)
        copyDropdown:SetValue("")
        deleteDropdown.dropdown:SetOptions(otherOpts)
        deleteDropdown:SetValue("")
    end

    -- Per-spec profiles section (LibDualSpec)
    LayoutSectionHeader(profLayout, profilesContent, L["Options.PerSpecProfiles"])

    local specDesc = profilesContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    specDesc:SetText(L["Options.PerSpecProfiles.Desc"])
    profLayout:AddText(specDesc, 12, COMPONENT_GAP)

    local specEnabled = Components.Checkbox(profilesContent, {
        label = L["Options.PerSpecProfiles.Enable"],
        get = function()
            return BR.Profiles.IsPerSpecEnabled()
        end,
        onChange = function(checked)
            BR.Profiles.SetPerSpecEnabled(checked)
            Components.RefreshAll()
        end,
    })
    profLayout:Add(specEnabled, 20, COMPONENT_GAP)

    local numSpecs = GetNumSpecializations() or 0
    local specDropdowns = {}
    for i = 1, numSpecs do
        local _, specName = GetSpecializationInfo(i)
        if specName then
            local specDropdown = Components.Dropdown(profilesContent, {
                label = specName,
                labelWidth = 100,
                width = 150,
                options = GetProfileOptions(),
                get = function()
                    return BR.Profiles.GetSpecProfile(i)
                end,
                enabled = function()
                    return BR.Profiles.IsPerSpecEnabled()
                end,
                onChange = function(value)
                    BR.Profiles.SetSpecProfile(i, value)
                end,
            })
            profLayout:Add(specDropdown, 26, COMPONENT_GAP)
            specDropdowns[i] = specDropdown
        end
    end

    local baseRefreshProfileDropdown = RefreshProfileDropdown
    RefreshProfileDropdown = function()
        baseRefreshProfileDropdown()
        local opts = GetProfileOptions()
        for _, sd in pairs(specDropdowns) do
            sd.dropdown:SetOptions(opts)
        end
    end

    -- Export so popup dialogs (e.g. BUFFREMINDERS_NEW_PROFILE) can call it.
    BR.Options.RefreshProfileDropdown = function()
        RefreshProfileDropdown()
    end

    -- Export section
    LayoutSectionHeader(profLayout, profilesContent, L["Options.ExportSettings"])

    local exportDesc = profilesContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    exportDesc:SetText(L["Options.ExportSettings.Desc"])
    profLayout:AddText(exportDesc, 12, COMPONENT_GAP)

    local exportTextArea = Components.TextArea(profilesContent, {
        width = PANEL_WIDTH - COL_PADDING * 2,
        height = 50,
    })
    profLayout:Add(exportTextArea, 50, COMPONENT_GAP)

    local exportButton = CreateButton(profilesContent, L["Options.Export"], function()
        local exportString, err = BuffReminders:Export()
        if exportString then
            exportTextArea:SetText(exportString)
            exportTextArea:HighlightText()
            exportTextArea:SetFocus()
        else
            exportTextArea:SetText(L["CustomBuff.Error"] .. " " .. (err or L["Options.FailedExport"]))
        end
    end)
    profLayout:Add(exportButton, 22, SECTION_GAP)

    -- Import section
    LayoutSectionHeader(profLayout, profilesContent, L["Options.ImportSettings"])

    local importDesc = profilesContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    importDesc:SetText(
        L["Options.ImportSettings.DescPlain"] .. " |cffff6600" .. L["Options.ImportSettings.Overwrite"] .. "|r"
    )
    profLayout:AddText(importDesc, 12, COMPONENT_GAP)

    local importTextArea = Components.TextArea(profilesContent, {
        width = PANEL_WIDTH - COL_PADDING * 2,
        height = 50,
    })
    profLayout:Add(importTextArea, 50, COMPONENT_GAP)

    local importStatus = profilesContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    importStatus:SetWidth(PANEL_WIDTH - COL_PADDING * 2 - 120)
    importStatus:SetJustifyH("LEFT")
    importStatus:SetText("")

    local importButton = CreateButton(profilesContent, L["Options.Import"], function()
        local importString = importTextArea:GetText()
        local success, err = BuffReminders:Import(importString)
        if success then
            importStatus:SetText("|cff00ff00" .. L["Options.ImportSuccess"] .. "|r")
            StaticPopup_Show("BUFFREMINDERS_RELOAD_UI")
        else
            importStatus:SetText(
                "|cffff0000" .. L["CustomBuff.Error"] .. " " .. (err or L["Options.UnknownError"]) .. "|r"
            )
        end
    end)
    profLayout:Add(importButton, 22)
    importStatus:SetPoint("LEFT", importButton, "RIGHT", 10, 0)

    profilesContent:SetHeight(abs(profLayout:GetY()) + 50)
end

BR.Options.Tabs.Profiles = { Build = Build }
