local _, ns = ...

local ProfileSettings = {}
ns.ProfileSettings = ProfileSettings

local SettingsLib = LibStub("LibEQOLSettingsMode-1.0")

ProfileSettings._pendingExportString = nil
ProfileSettings._pendingImportString = nil

StaticPopupDialogs["CMC_CREATE_NEW_PROFILE"] = {
    text = "Enter a name for the new profile:",
    button1 = "Create",
    button2 = "Cancel",
    hasEditBox = true,
    maxLetters = 32,
    OnAccept = function(self)
        local editBox = self.editBox or (self.GetEditBox and self:GetEditBox())
        local text = editBox:GetText()
        if text and strtrim(text) ~= "" then
            local trimmed = strtrim(text)
            local profiles = ns.ProfileAPI:GetProfiles()
            local exists = false
            for _, name in ipairs(profiles) do
                if name:lower() == trimmed:lower() then
                    exists = true
                    break
                end
            end
            if exists then
                ns.Addon:Print("A profile with that name already exists.")
            else
                if ns.ProfileAPI:CreateProfile(trimmed) then
                    ns.Addon:Print("Created and switched to profile: " .. trimmed)
                end
            end
        else
            ns.Addon:Print("Please enter a valid profile name.")
        end
    end,
    OnShow = function(self)
        local editBox = self.editBox or (self.GetEditBox and self:GetEditBox())
        editBox:SetText("")
        editBox:SetFocus()
    end,
    EditBoxOnEnterPressed = function(self)
        StaticPopup_OnClick(self:GetParent(), 1)
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["CMC_CONFIRM_DELETE_PROFILE"] = {
    text = "Are you sure you want to delete the profile:\n\n|cffff0000%s|r\n\nThis cannot be undone.",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function(self, profileName)
        if profileName and ns.ProfileAPI:DeleteProfile(profileName) then
            ns.Addon:Print("Deleted profile: " .. profileName)
        else
            ns.Addon:Print("Failed to delete profile.")
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["CMC_EXPORT_PROFILE"] = {
    text = "Copy this export string (Ctrl+C):\n\nProfile: |cff00ff00%s|r",
    button1 = "Close",
    hasEditBox = true,
    editBoxWidth = 350,
    OnShow = function(self, data)
        local exportString = ns.ProfileSettings._pendingExportString or ""
        local editBox = self.editBox or (self.GetEditBox and self:GetEditBox())
        editBox:SetText(exportString)
        editBox:SetFocus()
        editBox:HighlightText()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["CMC_IMPORT_PROFILE_STRING"] = {
    text = "Paste the profile export string below:",
    button1 = "Next",
    button2 = "Cancel",
    hasEditBox = true,
    editBoxWidth = 350,
    OnAccept = function(self)
        local editBox = self.editBox or (self.GetEditBox and self:GetEditBox())
        local text = editBox:GetText()
        if text and strtrim(text) ~= "" then
            local data, errorMsg = ns.ProfileAPI:DecodeExportString(text)
            if data then
                ns.ProfileSettings._pendingImportString = text
                StaticPopup_Show("CMC_IMPORT_PROFILE_NAME")
            else
                ns.Addon:Print("|cffff0000Import Error:|r " .. (errorMsg or "Invalid import string."))
            end
        else
            ns.Addon:Print("Please paste a valid export string.")
        end
    end,
    OnShow = function(self)
        local editBox = self.editBox or (self.GetEditBox and self:GetEditBox())
        editBox:SetText("")
        editBox:SetFocus()
    end,
    EditBoxOnEnterPressed = function(self)
        StaticPopup_OnClick(self:GetParent(), 1)
    end,
    EditBoxOnEscapePressed = function(self)
        ns.ProfileSettings._pendingImportString = nil
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["CMC_IMPORT_PROFILE_NAME"] = {
    text = "Enter a name for the imported profile:",
    button1 = "Import",
    button2 = "Cancel",
    hasEditBox = true,
    maxLetters = 32,
    OnAccept = function(self)
        local editBox = self.editBox or (self.GetEditBox and self:GetEditBox())
        local profileName = editBox:GetText()
        local importString = ns.ProfileSettings._pendingImportString

        if not importString then
            ns.Addon:Print("|cffff0000Import Error:|r No import data found.")
            return
        end

        if profileName and strtrim(profileName) ~= "" then
            local trimmed = strtrim(profileName)
            local success, errorMsg = ns.ProfileAPI:ImportFromString(importString, trimmed)
            if success then
                ns.Addon:Print("|cff00ff00Successfully imported profile:|r " .. trimmed)
            else
                ns.Addon:Print("|cffff0000Import Error:|r " .. (errorMsg or "Failed to import profile."))
            end
        else
            ns.Addon:Print("Please enter a valid profile name.")
        end

        ns.ProfileSettings._pendingImportString = nil
    end,
    OnShow = function(self)
        local editBox = self.editBox or (self.GetEditBox and self:GetEditBox())
        editBox:SetFocus()
    end,
    OnCancel = function()
        ns.ProfileSettings._pendingImportString = nil
    end,
    EditBoxOnEnterPressed = function(self)
        StaticPopup_OnClick(self:GetParent(), 1)
    end,
    EditBoxOnEscapePressed = function(self)
        ns.ProfileSettings._pendingImportString = nil
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function ProfileSettings:BuildSettings(parentCategory)
    local profileCategory = SettingsLib:CreateCategory(parentCategory, "Profiles", false)
    ns.WilduSettings.SettingsLayout.profileCategory = profileCategory

    SettingsLib:CreateText(profileCategory, {
        name = "Manage your addon profiles.",
    })

    SettingsLib:CreateDropdown(profileCategory, {
        prefix = "CMC_",
        key = "profile_current",
        name = "Active Profile",
        default = "",
        optionfunc = function()
            local profiles = ns.ProfileAPI:GetProfiles()
            local values = {}
            for _, name in ipairs(profiles) do
                values[name] = name
            end
            return values
        end,
        get = function()
            return ns.ProfileAPI:GetCurrentProfile()
        end,
        set = function(value)
            if value and value ~= ns.ProfileAPI:GetCurrentProfile() then
                ns.ProfileAPI:SetProfile(value)
            end
        end,
    })

    SettingsLib:CreateButton(profileCategory, {
        text = "Create New",
        func = function()
            StaticPopup_Show("CMC_CREATE_NEW_PROFILE")
        end,
        desc = "Create a new profile with a custom name.",
    })

    SettingsLib:CreateHeader(profileCategory, {
        name = "Import / Export",
    })

    SettingsLib:CreateButton(profileCategory, {
        text = "Export",
        func = function()
            local exportString = ns.ProfileAPI:GetExportString()
            if exportString and exportString ~= "" then
                ns.ProfileSettings._pendingExportString = exportString
                local currentProfile = ns.ProfileAPI:GetCurrentProfile()
                StaticPopup_Show("CMC_EXPORT_PROFILE", currentProfile)
            else
                ns.Addon:Print("Failed to generate export string.")
            end
        end,
        desc = "Export current profile as a shareable string.",
    })

    SettingsLib:CreateButton(profileCategory, {
        text = "Import",
        func = function()
            StaticPopup_Show("CMC_IMPORT_PROFILE_STRING")
        end,
        desc = "Import a profile from an export string.",
    })

    SettingsLib:CreateHeader(profileCategory, {
        name = "|cffff0000Delete Profile|r",
    })

    SettingsLib:CreateDropdown(profileCategory, {
        prefix = "CMC_",
        key = "profile_delete",
        name = "Select Profile to Delete",
        default = "",
        optionfunc = function()
            local profiles = ns.ProfileAPI:GetProfiles()
            local values = { [""] = "Select a profile..." }
            local current = ns.ProfileAPI:GetCurrentProfile()
            for _, name in ipairs(profiles) do
                if name ~= current then
                    values[name] = name
                end
            end
            return values
        end,
        get = function()
            return ""
        end,
        set = function(value)
            if value and value ~= "" then
                StaticPopup_Show("CMC_CONFIRM_DELETE_PROFILE", value, nil, value)
            end
        end,
        desc = "Select a profile to delete (cannot delete active profile).",
    })
end
