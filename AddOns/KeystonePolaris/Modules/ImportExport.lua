local AddOnName, KeystonePolaris = ...
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName)
local EXPORT_PREFIX = "!KeystonePolaris:"

-- ---------------------------------------------------------------------------
-- Import / Export Logic
-- ---------------------------------------------------------------------------

-- Shallow clone helper (reused here locally if needed, or we can make it global later)
local function CloneTable(tbl)
    if type(CopyTable) == "function" then return CopyTable(tbl) end
    local t = {}
    for k, v in pairs(tbl) do t[k] = v end
    return t
end

-- Dedicated copy window for long texts (multi-line, scrollable)
function KeystonePolaris:ShowCopyPopup(text)
    if not self.copyPopup then
        local f = CreateFrame("Frame", "KeystonePolarisCopyPopup", UIParent, "BackdropTemplate")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetToplevel(true)
        f:SetSize(700, 500)
        f:SetPoint("CENTER")
        -- Style aligné sur l'overlay Test Mode: fond sombre + bordure 1px or
        f:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\ChatFrame\\ChatFrameBackground", tile = true, tileSize = 16, edgeSize = 1 })
        f:SetBackdropColor(0, 0, 0, 1)
        f:SetBackdropBorderColor(1, 0.82, 0, 1)
        -- Renforcer la bordure 1px sur tous les côtés (comme Test Mode)
        if not f.border then f.border = {} end
        local br, bgc, bb, ba = 1, 0.82, 0, 1
        if not f.border.top then f.border.top = f:CreateTexture(nil, "BORDER") end
        f.border.top:SetColorTexture(br, bgc, bb, ba)
        f.border.top:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        f.border.top:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
        f.border.top:SetHeight(1)

        if not f.border.bottom then f.border.bottom = f:CreateTexture(nil, "BORDER") end
        f.border.bottom:SetColorTexture(br, bgc, bb, ba)
        f.border.bottom:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
        f.border.bottom:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
        f.border.bottom:SetHeight(1)

        if not f.border.left then f.border.left = f:CreateTexture(nil, "BORDER") end
        f.border.left:SetColorTexture(br, bgc, bb, ba)
        f.border.left:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        f.border.left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
        f.border.left:SetWidth(1)

        if not f.border.right then f.border.right = f:CreateTexture(nil, "BORDER") end
        f.border.right:SetColorTexture(br, bgc, bb, ba)
        f.border.right:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
        f.border.right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
        f.border.right:SetWidth(1)

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        title:SetPoint("TOP", 0, -12)
        title:SetText("Keystone Polaris — " .. L["Changelog"])
        title:SetTextColor(1, 0.82, 0, 1)

        local instr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        instr:SetPoint("TOPLEFT", 12, -40)
        instr:SetPoint("RIGHT", -12, 0)
        instr:SetJustifyH("LEFT")
        instr:SetText(L["COPY_INSTRUCTIONS"])
        -- Appliquer la police LSM si dispo, cohérente avec Test Mode
        local fontPath = self.LSM and self.LSM:Fetch('font', self.db and self.db.profile and self.db.profile.text and self.db.profile.text.font) or nil
        local baseSize = (self.db and self.db.profile and self.db.profile.general and self.db.profile.general.fontSize) or 12
        if fontPath then
            title:SetFont(fontPath, (baseSize or 12), "OUTLINE")
            instr:SetFont(fontPath, math.max(10, (baseSize or 12) - 6), "OUTLINE")
        end

        -- Séparateur sous le texte d'instruction
        local sep = f:CreateTexture(nil, "BORDER")
        sep:SetColorTexture(1, 0.82, 0, 0.25)
        sep:ClearAllPoints()
        sep:SetPoint("TOPLEFT", instr, "BOTTOMLEFT", 0, -10)
        sep:SetPoint("TOPRIGHT", instr, "BOTTOMRIGHT", 0, -10)
        sep:SetHeight(1)

        local scroll = CreateFrame("ScrollFrame", "KeystonePolarisCopyScroll", f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -10)
        scroll:SetPoint("BOTTOMRIGHT", -32, 44)

        local edit = CreateFrame("EditBox", "KeystonePolarisCopyEditBox", scroll)
        edit:SetMultiLine(true)
        edit:SetFontObject(ChatFontNormal)
        edit:SetAutoFocus(true)
        edit:SetWidth(scroll:GetWidth())
        edit:SetText("")
        scroll:SetScrollChild(edit)

        scroll:HookScript("OnSizeChanged", function(_, width)
            edit:SetWidth(width)
        end)

        local selectBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        selectBtn:SetSize(100, 22)
        selectBtn:SetPoint("BOTTOMLEFT", 12, 12)
        selectBtn:SetText(L["SELECT_ALL"])
        selectBtn:SetScript("OnClick", function()
            edit:SetFocus()
            edit:HighlightText()
        end)

        local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        closeBtn:SetSize(80, 22)
        closeBtn:SetPoint("BOTTOMRIGHT", -12, 12)
        closeBtn:SetText(OKAY or "OK")
        closeBtn:SetScript("OnClick", function() f:Hide() end)

        f:SetScript("OnShow", function()
            edit:SetFocus()
            edit:HighlightText()
        end)
        f:SetScript("OnKeyDown", function(_, key)
            if key == "ESCAPE" then f:Hide() end
        end)
        f:EnableKeyboard(true)

        f.editBox = edit
        self.copyPopup = f
    end

    local f = self.copyPopup
    if f and f.editBox then
        f.editBox:SetText(text or "")
        f:Show()
        -- Assurer l'affichage au-dessus des StaticPopup (ex: KPL_MIGRATION)
        local maxPopupLevel = 0
        for i = 1, 4 do
            local p = _G["StaticPopup" .. i]
            if p and p:IsShown() then
                local lvl = p:GetFrameLevel() or 0
                if lvl > maxPopupLevel then maxPopupLevel = lvl end
                -- Si une StaticPopup est en FULLSCREEN_DIALOG, garder la même strata
                if p:GetFrameStrata() == "FULLSCREEN_DIALOG" then
                    f:SetFrameStrata("FULLSCREEN_DIALOG")
                end
            end
        end
        local myLvl = f:GetFrameLevel() or 0
        if maxPopupLevel >= myLvl then
            f:SetFrameLevel(maxPopupLevel + 2)
        end
        f:Raise()
    end
end

-- Global export function for dungeon settings
function KeystonePolaris.ExportDungeonSettings(_, dungeonData, exportType, sectionName)
    -- Create export string
    local exportData
    if exportType == "dungeon" then
        exportData = {
            type = exportType,
            dungeon = sectionName,
            data = dungeonData
        }
    else
        exportData = {
            type = exportType,
            section = sectionName,
            data = dungeonData
        }
    end
    local serialized = LibStub("AceSerializer-3.0"):Serialize(exportData)
    local compressed = LibStub("LibDeflate"):CompressDeflate(serialized)
    local encoded = LibStub("LibDeflate"):EncodeForPrint(compressed)
    local exportString = EXPORT_PREFIX .. encoded

    -- Determine dialog text based on export type
    local dialogText
    if exportType == "all_dungeons" then
        dialogText = L["EXPORT_ALL_DIALOG_TEXT"]
    elseif exportType == "section" then
        dialogText = (L["EXPORT_SECTION_DIALOG_TEXT"]):format(sectionName)
    else
        dialogText = L["EXPORT_DIALOG_TEXT"]
    end

    -- Show export dialog
    StaticPopupDialogs["KPL_EXPORT_DIALOG"] = {
        text = dialogText,
        button1 = OKAY,
        hasEditBox = true,
        editBoxWidth = 350,
        maxLetters = 999999,
        OnShow = function(dialog)
            dialog.EditBox:SetText(exportString)
            dialog.EditBox:HighlightText()
            dialog.EditBox:SetFocus()
        end,
        EditBoxOnEscapePressed = function(editBox)
            editBox:GetParent():Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true
    }
    StaticPopup_Show("KPL_EXPORT_DIALOG")
end

-- Global import function for dungeon settings
function KeystonePolaris:ImportDungeonSettings(importString,
                                                        sectionName,
                                                        dungeonFilter)
    local addon = self
    local prefix = (addon.GetChatPrefix and addon:GetChatPrefix()) or "Keystone Polaris"
    local importPayload = importString
    if type(importPayload) == "string" then
        importPayload = importPayload:match("^%s*(.-)%s*$")
        if importPayload:sub(1, #EXPORT_PREFIX) == EXPORT_PREFIX then
            importPayload = importPayload:sub(#EXPORT_PREFIX + 1)
        end
    end

    local decoded = LibStub("LibDeflate"):DecodeForPrint(importPayload)
    if not decoded then
        print(prefix .. ": " .. L["IMPORT_ERROR"])
        return false
    end

    local decompressed = LibStub("LibDeflate"):DecompressDeflate(decoded)
    if not decompressed then
        print(prefix .. ": " .. L["IMPORT_ERROR"])
        return false
    end

    local success, importData = LibStub("AceSerializer-3.0"):Deserialize(
                                    decompressed)
    if not success then
        print(prefix .. ": " .. L["IMPORT_ERROR"])
        return false
    end

    local importCount = 0

    -- Handle different import types
    if importData.type == "all_dungeons" and importData.data then
        -- Import all dungeon data (filtered by dungeonFilter if provided)
        for dungeonKey, dungeonData in pairs(importData.data) do
            if not dungeonFilter or dungeonFilter[dungeonKey] then
                local dungeonId = addon:GetDungeonIdByKey(dungeonKey)
                if dungeonId and addon.DUNGEONS[dungeonId] then
                    if not addon.db.profile.advanced[dungeonKey] then
                        addon.db.profile.advanced[dungeonKey] = {}
                    end
                    for k, v in pairs(dungeonData) do
                        if type(v) == "table" then
                            addon.db.profile.advanced[dungeonKey][k] = CloneTable(v)
                        else
                            addon.db.profile.advanced[dungeonKey][k] = v
                        end
                    end
                    importCount = importCount + 1
                end
            end
        end
    elseif importData.type == "section" and importData.data then
        -- Import section data (filtered by dungeonFilter if provided)
        for dungeonKey, dungeonData in pairs(importData.data) do
            if not dungeonFilter or dungeonFilter[dungeonKey] then
                local dungeonId = addon:GetDungeonIdByKey(dungeonKey)
                if dungeonId and addon.DUNGEONS[dungeonId] then
                    if not addon.db.profile.advanced[dungeonKey] then
                        addon.db.profile.advanced[dungeonKey] = {}
                    end
                    for k, v in pairs(dungeonData) do
                        if type(v) == "table" then
                            addon.db.profile.advanced[dungeonKey][k] = CloneTable(v)
                        else
                            addon.db.profile.advanced[dungeonKey][k] = v
                        end
                    end
                    importCount = importCount + 1
                end
            end
        end
    elseif importData.dungeon then
        -- Handle single dungeon import for backward compatibility
        local dungeonKey = importData.dungeon
        if not dungeonFilter or dungeonFilter[dungeonKey] then
            local dungeonId = addon:GetDungeonIdByKey(dungeonKey)
            if dungeonId and addon.DUNGEONS[dungeonId] then
                if not addon.db.profile.advanced[dungeonKey] then
                    addon.db.profile.advanced[dungeonKey] = {}
                end
                for k, v in pairs(importData.data) do
                    if type(v) == "table" then
                        addon.db.profile.advanced[dungeonKey][k] = CloneTable(v)
                    else
                        addon.db.profile.advanced[dungeonKey][k] = v
                    end
                end
                addon:UpdateDungeonData()
                if addon.currentDungeonID and addon.BuildSectionOrder then
                    addon:BuildSectionOrder(addon.currentDungeonID)
                end
                LibStub("AceConfigRegistry-3.0"):NotifyChange(
                    "KeystonePolaris")
                if addon.UpdatePercentageText then addon:UpdatePercentageText() end
                print(prefix .. ": " ..
                          L["IMPORT_SUCCESS"]:format(
                              addon:GetDungeonDisplayName(dungeonKey)))
                return true
            end
        end
        print(prefix .. ": " .. L["IMPORT_ERROR"])
        return false
    else
        print(prefix .. ": " .. L["IMPORT_ERROR"])
        return false
    end

    -- Update data and notify of changes
    if importCount > 0 then
        addon:UpdateDungeonData()

        if addon.currentDungeonID and addon.BuildSectionOrder then
            addon:BuildSectionOrder(addon.currentDungeonID)
        end
        LibStub("AceConfigRegistry-3.0"):NotifyChange("KeystonePolaris")
        if addon.UpdatePercentageText then addon:UpdatePercentageText() end

        -- Determine success message based on import type
        if importData.type == "all_dungeons" then
            print(prefix .. ": " ..
                      (L["IMPORT_ALL_SUCCESS"]))
        elseif importData.type == "section" then
            local successTarget = sectionName or importData.section
            if not successTarget and dungeonFilter then
                local dungeonKey = next(dungeonFilter)
                if dungeonKey then
                    successTarget = addon:GetDungeonDisplayName(dungeonKey)
                end
            end

            if successTarget then
                print(prefix .. ": " ..
                          (L["IMPORT_SUCCESS"]):format(successTarget))
            else
                print(prefix .. ": " .. (L["IMPORT_ALL_SUCCESS"]))
            end
        end
        return true
    else
        print(prefix .. ": " .. (L["IMPORT_ERROR"]))
        return false
    end
end

-- Global function to create import dialog
function KeystonePolaris:ShowImportDialog(sectionName, dungeonFilter)
    local addon = self
    local dialogText

    if not sectionName then
        dialogText = L["IMPORT_ALL_DIALOG_TEXT"]
    else
        dialogText = (L["IMPORT_SECTION_DIALOG_TEXT"]):format(sectionName)
    end

    StaticPopupDialogs["KPL_IMPORT_DIALOG"] = {
        text = dialogText,
        button1 = OKAY,
        button2 = CANCEL,
        hasEditBox = true,
        editBoxWidth = 350,
        maxLetters = 999999,
        OnAccept = function(dialog)
            local importString = dialog.EditBox:GetText()
            addon:ImportDungeonSettings(importString, sectionName, dungeonFilter)
        end,
        EditBoxOnEscapePressed = function(editBox)
            editBox:GetParent():Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true
    }
    StaticPopup_Show("KPL_IMPORT_DIALOG")
end
