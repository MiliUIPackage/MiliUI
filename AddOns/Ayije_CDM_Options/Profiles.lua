local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L
local switchDropdown = nil
local copyDropdown = nil
local deleteDropdown = nil
local defaultDropdown = nil
local renameEditBox = nil
local profilePage = nil
local specToggle = nil
local specSection = nil
local specDropdowns = {}

local function MapProfileActionError(errCode, fallback)
    if errCode == "combat_blocked" then
        return L["Cannot open config while in combat"]
    end
    if errCode == "profile_exists" then
        return L["Already exists"]
    end
    if errCode == "invalid_profile_name" then
        return L["Enter a name"]
    end
    if errCode == "same_profile_name" then
        return L["Already exists"]
    end
    if errCode == "apply_failed" or errCode == "db_not_initialized" then
        return L["Failed to apply profile"]
    end
    if errCode == "profile_not_found" then
        return L["Profile not found"]
    end
    if errCode == "source_is_active" then
        return L["Cannot copy active profile"]
    end
    if errCode == "cannot_delete_active_profile" then
        return L["Cannot delete active profile"]
    end
    return fallback or L["Invalid profile data"]
end

local function PrintActionError(errCode)
    print("|cffff0000[CDM]|r " .. MapProfileActionError(errCode))
end

local function SetupSwitchDropdown(dropdown)
    dropdown:SetupMenu(function(_, rootDescription)
        local profiles = API:GetProfileList()
        local current = API:GetActiveProfileName()
        for _, name in ipairs(profiles) do
            rootDescription:CreateRadio(name, function()
                return current == name
            end, function()
                local ok, errCode = API:SetProfile(name)
                if not ok then
                    PrintActionError(errCode)
                end
            end)
        end
    end)
end

local function SetupProfileDropdown(dropdown, excludeCurrent, onSelect)
    dropdown:SetupMenu(function(_, rootDescription)
        local profiles = API:GetProfileList()
        local current = API:GetActiveProfileName()
        for _, name in ipairs(profiles) do
            if not excludeCurrent or name ~= current then
                rootDescription:CreateButton(name, function()
                    onSelect(name)
                end)
            end
        end
    end)
end

local function SetupSpecDropdown(dropdown, specIndex)
    local assigned = API:GetSpecProfile(specIndex) or API:GetActiveProfileName()
    dropdown:SetDefaultText(assigned)
    dropdown:SetupMenu(function(_, rootDescription)
        local profiles = API:GetProfileList()
        for _, name in ipairs(profiles) do
            rootDescription:CreateRadio(name, function()
                return (API:GetSpecProfile(specIndex) or API:GetActiveProfileName()) == name
            end, function()
                local currentSpec = GetSpecialization()
                if currentSpec and specIndex == currentSpec then
                    local ok, errCode = API:SetProfile(name)
                    if not ok then
                        PrintActionError(errCode)
                        return
                    end
                end
                API:SetSpecProfile(specIndex, name)
                RefreshSpecDropdowns()
            end)
        end
    end)
end

local function RefreshSpecDropdowns()
    for i, dd in pairs(specDropdowns) do
        SetupSpecDropdown(dd, i)
    end
end

local function SetupDefaultProfileDropdown(dropdown)
    dropdown:SetDefaultText(Ayije_CDMDB.global.defaultProfile or "Default")
    dropdown:SetupMenu(function(_, rootDescription)
        local profiles = API:GetProfileList()
        local currentDefault = Ayije_CDMDB.global.defaultProfile or "Default"
        for _, name in ipairs(profiles) do
            rootDescription:CreateRadio(name, function()
                return currentDefault == name
            end, function()
                Ayije_CDMDB.global.defaultProfile = name
                dropdown:SetDefaultText(name)
            end)
        end
    end)
end

local function RefreshProfilesUI()
    if not profilePage then return end

    if switchDropdown then
        switchDropdown:SetDefaultText(API:GetActiveProfileName())
        SetupSwitchDropdown(switchDropdown)
    end

    if renameEditBox then
        renameEditBox:SetText(API:GetActiveProfileName())
    end

    if copyDropdown then
        SetupProfileDropdown(copyDropdown, true, function(name)
            StaticPopup_Show("AYIJE_CDM_CONFIRM_COPY_PROFILE", name, nil, { name = name })
        end)
    end

    if deleteDropdown then
        SetupProfileDropdown(deleteDropdown, true, function(name)
            StaticPopup_Show("AYIJE_CDM_CONFIRM_DELETE_PROFILE", name, nil, { name = name })
        end)
    end

    if defaultDropdown then
        SetupDefaultProfileDropdown(defaultDropdown)
    end

    if specToggle then
        specToggle:SetChecked(API:IsSpecProfileEnabled())
    end
    if specSection then
        if API:IsSpecProfileEnabled() then
            specSection:Show()
        else
            specSection:Hide()
        end
    end
    RefreshSpecDropdowns()
end

ns.RefreshProfilesTab = RefreshProfilesUI

local function CreateProfilesTab(page, tabId)
    profilePage = page

    local h2 = UI.CreateHeader(page, L["Current Profile"])
    h2:SetPoint("TOPLEFT", 35, -40)

    switchDropdown = CreateFrame("DropdownButton", nil, page, "WowStyle1DropdownTemplate")
    switchDropdown:SetPoint("TOPLEFT", h2, "BOTTOMLEFT", 0, -15)
    switchDropdown:SetWidth(200)
    switchDropdown:SetDefaultText(API:GetActiveProfileName())
    SetupSwitchDropdown(switchDropdown)

    local h3 = UI.CreateHeader(page, L["New Profile"])
    h3:SetPoint("TOPLEFT", switchDropdown, "BOTTOMLEFT", 0, -15)

    local newProfileRow = CreateFrame("Frame", nil, page)
    newProfileRow:SetSize(400, 28)
    newProfileRow:SetPoint("TOPLEFT", h3, "BOTTOMLEFT", 0, -15)

    local newEditBox = CreateFrame("EditBox", nil, newProfileRow, "InputBoxTemplate")
    newEditBox:SetSize(200, 28)
    newEditBox:SetPoint("LEFT", 0, 0)
    newEditBox:SetAutoFocus(false)
    newEditBox:SetMaxLetters(50)
    newEditBox:SetFontObject("AyijeCDM_Font14")

    local createBtn = CreateFrame("Button", nil, newProfileRow, "UIPanelButtonTemplate")
    createBtn:SetSize(80, 26)
    createBtn:SetPoint("LEFT", newEditBox, "RIGHT", 8, 0)
    createBtn:SetText(L["Create"])

    local createStatus = newProfileRow:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    createStatus:SetPoint("LEFT", createBtn, "RIGHT", 8, 0)

    createBtn:SetScript("OnClick", function()
        local name = newEditBox:GetText()
        if not name or name:match("^%s*$") then
            createStatus:SetText(L["Enter a name"])
            UI.SetTextError(createStatus)
            return
        end
        name = name:match("^%s*(.-)%s*$")  -- trim whitespace
        local ok, errCode = API:NewProfile(name)
        if ok then
            newEditBox:SetText("")
            createStatus:SetText("")
        else
            createStatus:SetText(MapProfileActionError(errCode, L["Already exists"]))
            UI.SetTextError(createStatus)
        end
    end)

    newEditBox:SetScript("OnEnterPressed", function(self)
        createBtn:Click()
        self:ClearFocus()
    end)

    newEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    local h4 = UI.CreateHeader(page, L["Copy From"])
    h4:SetPoint("TOPLEFT", newProfileRow, "BOTTOMLEFT", 0, -15)

    local copyDesc = page:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    copyDesc:SetPoint("TOPLEFT", h4, "BOTTOMLEFT", 0, -10)
    copyDesc:SetText(L["Copy all settings from another profile into the current one."])
    UI.SetTextMuted(copyDesc)

    copyDropdown = CreateFrame("DropdownButton", nil, page, "WowStyle1DropdownTemplate")
    copyDropdown:SetPoint("TOPLEFT", copyDesc, "BOTTOMLEFT", 0, -10)
    copyDropdown:SetWidth(200)
    copyDropdown:SetDefaultText(L["Select Source..."])
    SetupProfileDropdown(copyDropdown, true, function(name)
        StaticPopup_Show("AYIJE_CDM_CONFIRM_COPY_PROFILE", name, nil, { name = name })
    end)

    local h5 = UI.CreateHeader(page, L["Manage"])
    h5:SetPoint("TOPLEFT", copyDropdown, "BOTTOMLEFT", 0, -15)

    local renameRow = CreateFrame("Frame", nil, page)
    renameRow:SetSize(400, 28)
    renameRow:SetPoint("TOPLEFT", h5, "BOTTOMLEFT", 0, -15)

    renameEditBox = CreateFrame("EditBox", nil, renameRow, "InputBoxTemplate")
    renameEditBox:SetSize(200, 28)
    renameEditBox:SetPoint("LEFT", 0, 0)
    renameEditBox:SetAutoFocus(false)
    renameEditBox:SetMaxLetters(50)
    renameEditBox:SetFontObject("AyijeCDM_Font14")
    renameEditBox:SetText(API:GetActiveProfileName())

    local renameBtn = CreateFrame("Button", nil, renameRow, "UIPanelButtonTemplate")
    renameBtn:SetSize(80, 26)
    renameBtn:SetPoint("LEFT", renameEditBox, "RIGHT", 8, 0)
    renameBtn:SetText(L["Rename"])

    local renameStatus = renameRow:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    renameStatus:SetPoint("LEFT", renameBtn, "RIGHT", 8, 0)

    renameBtn:SetScript("OnClick", function()
        local name = renameEditBox:GetText()
        if not name or name:match("^%s*$") then
            renameStatus:SetText(L["Enter a name"])
            UI.SetTextError(renameStatus)
            return
        end
        name = name:match("^%s*(.-)%s*$")
        if name == API:GetActiveProfileName() then
            renameStatus:SetText("")
            return
        end
        local ok, errCode = API:RenameProfile(name)
        if ok then
            renameStatus:SetText("")
        else
            renameStatus:SetText(MapProfileActionError(errCode, L["Already exists"]))
            UI.SetTextError(renameStatus)
        end
    end)

    renameEditBox:SetScript("OnEnterPressed", function(self)
        renameBtn:Click()
        self:ClearFocus()
    end)

    renameEditBox:SetScript("OnEscapePressed", function(self)
        self:SetText(API:GetActiveProfileName())
        self:ClearFocus()
    end)

    local manageRow = CreateFrame("Frame", nil, page)
    manageRow:SetSize(400, 28)
    manageRow:SetPoint("TOPLEFT", renameRow, "BOTTOMLEFT", 0, -10)

    local resetBtn = CreateFrame("Button", nil, manageRow, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 26)
    resetBtn:SetPoint("LEFT", 0, 0)
    resetBtn:SetText(L["Reset Profile"])
    resetBtn:SetScript("OnClick", function()
        StaticPopup_Show("AYIJE_CDM_CONFIRM_RESET_PROFILE")
    end)

    deleteDropdown = CreateFrame("DropdownButton", nil, manageRow, "WowStyle1DropdownTemplate")
    deleteDropdown:SetPoint("LEFT", resetBtn, "RIGHT", 12, 0)
    deleteDropdown:SetWidth(160)
    deleteDropdown:SetDefaultText(L["Delete Profile..."])
    SetupProfileDropdown(deleteDropdown, true, function(name)
        StaticPopup_Show("AYIJE_CDM_CONFIRM_DELETE_PROFILE", name, nil, { name = name })
    end)

    local h6 = UI.CreateHeader(page, L["Default Profile for New Characters"])
    h6:SetPoint("TOPLEFT", manageRow, "BOTTOMLEFT", 0, -15)

    defaultDropdown = CreateFrame("DropdownButton", nil, page, "WowStyle1DropdownTemplate")
    defaultDropdown:SetPoint("TOPLEFT", h6, "BOTTOMLEFT", 0, -15)
    defaultDropdown:SetWidth(200)
    SetupDefaultProfileDropdown(defaultDropdown)

    local h7 = UI.CreateHeader(page, L["Specialization Profiles"])
    h7:SetPoint("TOPLEFT", defaultDropdown, "BOTTOMLEFT", 0, -15)

    specToggle = UI.CreateModernCheckbox(page, L["Auto-switch profile per specialization"], API:IsSpecProfileEnabled(), function(checked)
        API:SetSpecProfileEnabled(checked)
        if specSection then
            if checked then specSection:Show() else specSection:Hide() end
        end
    end)
    specToggle:SetPoint("TOPLEFT", h7, "BOTTOMLEFT", -2, -10)

    specSection = CreateFrame("Frame", nil, page)
    specSection:SetSize(600, 60)
    specSection:SetPoint("TOPLEFT", specToggle, "BOTTOMLEFT", 2, -10)

    local classId = select(3, UnitClass("player"))
    local numSpecs = C_SpecializationInfo.GetNumSpecializationsForClassID(classId)
    wipe(specDropdowns)

    for i = 1, numSpecs do
        local _, specName = GetSpecializationInfo(i)
        local col = (i - 1) * 150

        local label = specSection:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
        label:SetPoint("TOPLEFT", col, 0)
        label:SetText(specName or string.format(L["Spec %d"], i))
        UI.SetTextMuted(label)

        local dd = CreateFrame("DropdownButton", nil, specSection, "WowStyle1DropdownTemplate")
        dd:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
        dd:SetWidth(140)
        SetupSpecDropdown(dd, i)
        specDropdowns[i] = dd
    end

    if not API:IsSpecProfileEnabled() then
        specSection:Hide()
    end
end

API:RegisterConfigTab("profiles", L["Profiles"], CreateProfilesTab, 11.5)
