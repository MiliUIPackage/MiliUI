-- Config/Icons.lua - Icons Configuration Tab
-- Controls for secondary/tertiary buff categorization per spec

local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local L = Runtime.L
local CDM_C = CDM and CDM.CONST or {}
local IsSafeNumber = API.IsSafeNumber
local UI = ns.ConfigUI

local function CreateSpellsTab(page, tabId)
    local specIndex = GetSpecialization()
    local currentSpecID = specIndex and GetSpecializationInfo(specIndex) or nil

    local buffEntryFrames = {}
    local MAX_BUFF_DISPLAY = 14

    local NormalizeToBase = API.NormalizeToBase
    local eventRegistryTokens = ns.eventRegistryTokens or {}
    ns.eventRegistryTokens = eventRegistryTokens

    local RefreshSpellList, RefreshBuffOrderDisplay

    local function RefreshCurrentSpecID()
        local si = GetSpecialization()
        if si then
            currentSpecID = GetSpecializationInfo(si)
        else
            currentSpecID = nil
        end
    end

    local function OpenSpellBorderColorPicker(spellID, onColorApplied)
        local registry = API:GetSpellRegistry(currentSpecID)
        local customColor = registry and registry.colors and registry.colors[spellID]
        local currentColor = customColor
            or CDM_C.GetConfigValue("borderColor", {r = 1, g = 1, b = 1, a = 1})
        local prevR, prevG, prevB = currentColor.r, currentColor.g, currentColor.b

        local info = {
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                API:SaveSpell(currentSpecID, spellID, false, false, {r = r, g = g, b = b})
                API:RefreshConfig()
                if onColorApplied then
                    onColorApplied(r, g, b)
                end
            end,
            cancelFunc = function()
                if customColor then
                    API:SaveSpell(currentSpecID, spellID, false, false, {r = prevR, g = prevG, b = prevB})
                elseif CDM.db.spellRegistry and CDM.db.spellRegistry[currentSpecID] and
                       CDM.db.spellRegistry[currentSpecID].colors then
                    CDM.db.spellRegistry[currentSpecID].colors[spellID] = nil
                    API:InvalidateSpellRegistryCache(currentSpecID)
                end
                API:RefreshConfig()
                if onColorApplied then
                    onColorApplied(prevR, prevG, prevB)
                end
            end,
            r = currentColor.r,
            g = currentColor.g,
            b = currentColor.b,
            hasOpacity = false,
        }
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end

    local function BuildSecondaryTertiarySet()
        local excludeSet = {}
        local registry = API:GetSpellRegistry(currentSpecID)
        if registry then
            if registry.secondary then
                for _, id in ipairs(registry.secondary) do
                    excludeSet[id] = true
                    local baseID = NormalizeToBase(id)
                    if baseID then excludeSet[baseID] = true end
                end
            end
            if registry.tertiary then
                for _, id in ipairs(registry.tertiary) do
                    excludeSet[id] = true
                    local baseID = NormalizeToBase(id)
                    if baseID then excludeSet[baseID] = true end
                end
            end
        end
        return excludeSet
    end

    local function IsSecondaryOrTertiary(spellID, excludeSet)
        if not spellID then return false end
        if excludeSet[spellID] then return true end
        local baseID = NormalizeToBase(spellID)
        if baseID and excludeSet[baseID] then return true end
        return false
    end

    local function GetBuffOrder()
        local buffViewer = _G["BuffIconCooldownViewer"]
        local excludeSet = BuildSecondaryTertiarySet()

        if not buffViewer or not buffViewer.itemFramePool then
            return {}
        end

        local icons = {}
        local seen = {}
        for frame in buffViewer.itemFramePool:EnumerateActive() do
            local displayID = frame.GetSpellID and frame:GetSpellID()
            if not IsSafeNumber(displayID) then
                displayID = frame.GetBaseSpellID and frame:GetBaseSpellID()
            end
            if IsSafeNumber(displayID) then
                if not seen[displayID] then
                    seen[displayID] = true
                    if not IsSecondaryOrTertiary(displayID, excludeSet) then
                        local li = frame.layoutIndex
                        local safeLayoutIndex = IsSafeNumber(li) and li or 0
                        table.insert(icons, {
                            spellID = displayID,
                            layoutIndex = safeLayoutIndex,
                        })
                    end
                end
            end
        end
        table.sort(icons, function(a, b)
            if a.layoutIndex ~= b.layoutIndex then
                return a.layoutIndex < b.layoutIndex
            end
            return a.spellID < b.spellID
        end)

        local order = {}
        for _, data in ipairs(icons) do
            table.insert(order, data.spellID)
        end

        return order
    end

    ---------------------------------------------------------------
    -- LEFT SIDE: PRIMARY BUFF ORDER
    ---------------------------------------------------------------

    local function CreateBuffOrderDisplay()
        local buffOrderHeader = UI.CreateHeader(page, L["Primary Buff Order"])
        buffOrderHeader:SetPoint("TOPLEFT", 35, -40)

        local helperText = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        helperText:SetPoint("TOPLEFT", 35, -58)
        helperText:SetText(L["Press icon to color the border"])
        UI.SetTextDim(helperText)

        local buffListContainer = CreateFrame("Frame", nil, page)
        buffListContainer:SetPoint("TOPLEFT", 35, -75)
        buffListContainer:SetSize(200, 520)
        buffListContainer:Show()

        RefreshBuffOrderDisplay = function()
            RefreshCurrentSpecID()
            if not currentSpecID then
                return
            end

            local order = GetBuffOrder()

            for _, entry in ipairs(buffEntryFrames) do
                entry:Hide()
            end

            local displayCount = math.min(#order, MAX_BUFF_DISPLAY)
            for i = 1, displayCount do
                local spellID = order[i]
                local entry = buffEntryFrames[i]
                if not entry then
                    entry = CreateFrame("Frame", nil, buffListContainer)
                    entry:SetSize(190, 32)
                    entry:SetPoint("TOPLEFT", 0, -(i - 1) * 40)

                    local iconContainer = CreateFrame("Frame", nil, entry)
                    iconContainer:SetSize(28, 28)
                    iconContainer:SetPoint("LEFT", 0, 0)
                    entry.iconContainer = iconContainer

                    local icon = iconContainer:CreateTexture(nil, "ARTWORK")
                    icon:SetSize(28, 28)
                    icon:SetAllPoints()
                    CDM_C.ApplyIconTexCoord(icon, true)
                    entry.icon = icon

                    if CDM.BORDER and CDM.BORDER.CreateBorder then
                        CDM.BORDER:CreateBorder(iconContainer)
                    end

                    local iconButton = CreateFrame("Button", nil, iconContainer)
                    iconButton:SetAllPoints()
                    iconButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                    iconButton:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:AddLine(L["Click to change border color"])
                        GameTooltip:AddLine(L["Right-click to reset to default"], 0.5, 0.5, 0.5)
                        GameTooltip:Show()
                    end)
                    iconButton:SetScript("OnLeave", function()
                        GameTooltip:Hide()
                    end)
                    entry.iconButton = iconButton

                    local nameText = entry:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
                    nameText:SetPoint("LEFT", iconContainer, "RIGHT", 8, 6)
                    nameText:SetWidth(150)
                    nameText:SetJustifyH("LEFT")
                    UI.SetTextWhite(nameText)
                    entry.nameText = nameText

                    local idText = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    idText:SetPoint("LEFT", iconContainer, "RIGHT", 8, -8)
                    UI.SetTextMuted(idText)
                    entry.idText = idText

                    buffEntryFrames[i] = entry
                end

                entry:ClearAllPoints()
                entry:SetPoint("TOPLEFT", 0, -(i - 1) * 40)

                local spellTexture = C_Spell.GetSpellTexture(spellID)
                if spellTexture then
                    entry.icon:SetTexture(spellTexture)
                end

                local spellName = C_Spell.GetSpellName(spellID)
                entry.nameText:SetText(spellName or L["Unknown"])
                entry.idText:SetText("ID: " .. spellID)

                entry.spellID = spellID

                if entry.iconButton then
                    entry.iconButton:SetScript("OnClick", function(self, button)
                        if button == "RightButton" then
                            if CDM.db.spellRegistry and CDM.db.spellRegistry[currentSpecID] and
                               CDM.db.spellRegistry[currentSpecID].colors then
                                CDM.db.spellRegistry[currentSpecID].colors[spellID] = nil
                            end
                            API:InvalidateSpellRegistryCache(currentSpecID)
                            API:RefreshConfig()
                        else
                            OpenSpellBorderColorPicker(spellID, function(r, g, b)
                                if entry.iconContainer and entry.iconContainer.border then
                                    entry.iconContainer.border:SetBackdropBorderColor(r, g, b, 1)
                                end
                            end)
                        end
                    end)
                end

                local registry = API:GetSpellRegistry(currentSpecID)
                if registry and registry.colors and registry.colors[spellID] then
                    local customColor = registry.colors[spellID]
                    if entry.iconContainer and entry.iconContainer.border then
                        entry.iconContainer.border:SetBackdropBorderColor(customColor.r, customColor.g, customColor.b, 1)
                    end
                end

                entry:Show()
            end
        end

        local refreshQueued = false
        local function QueueBuffOrderRefresh(delay)
            if refreshQueued then return end
            refreshQueued = true
            C_Timer.After(delay or 0, function()
                refreshQueued = false
                if page and page:IsVisible() then
                    RefreshBuffOrderDisplay()
                end
            end)
        end

        return QueueBuffOrderRefresh
    end

    ---------------------------------------------------------------
    -- RIGHT SIDE: CATEGORY CONTAINERS
    ---------------------------------------------------------------
    local rightSideX = 281

    local ROW_HEIGHT_COLLAPSED = 28
    local ROW_HEIGHT_EXPANDED = 128
    local ROW_SPACING = 6
    local SUBPANEL_HEIGHT = 100

    local expandedSpellID = nil

    local function CreatePlaceholderRow(parent, slotIndex)
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(340, 28)
        row.isPlaceholder = true

        local text = row:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        text:SetPoint("CENTER", 0, 0)
        text:SetText(string.format(L["Empty Slot %d"], slotIndex))
        UI.SetTextFaint(text)

        return row
    end

    local function CreateCategoryContainer(parent, categoryName, yOffset)
        local container = CreateFrame("Frame", nil, parent, "InsetFrameTemplate3")
        container:SetPoint("TOPLEFT", rightSideX, yOffset)
        container:SetSize(360, 280)

        local header = UI.CreateHeader(container, categoryName)
        header:SetPoint("TOPLEFT", 10, -8)

        local contentContainer = CreateFrame("Frame", nil, container)
        contentContainer:SetPoint("TOP", 0, -35)
        contentContainer:SetSize(340, 230)
        contentContainer:SetClipsChildren(true)
        contentContainer.rowFrames = {}

        return container, contentContainer
    end

    local function CreateAddSpellRow(parent, category)
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(340, 28)
        row.isAddRow = true

        local ebSpellID = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        ebSpellID:SetSize(120, 20)
        ebSpellID:SetPoint("LEFT", 78, 0)
        ebSpellID:SetAutoFocus(false)
        ebSpellID:SetMaxLetters(10)
        UI.SetTextWhite(ebSpellID)

        local placeholder = row:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        placeholder:SetPoint("LEFT", ebSpellID, "LEFT", 5, 0)
        placeholder:SetText(L["Spell ID..."])
        UI.SetTextPlaceholder(placeholder)
        placeholder:Hide()

        ebSpellID:HookScript("OnEditFocusGained", function(self)
            placeholder:Hide()
        end)
        ebSpellID:HookScript("OnEditFocusLost", function(self)
            if self:GetText() == "" then
                placeholder:Show()
            end
        end)
        if ebSpellID:GetText() == "" then
            placeholder:Show()
        end

        local btnAdd = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btnAdd:SetSize(60, 22)
        btnAdd:SetPoint("LEFT", ebSpellID, "RIGHT", 5, 0)
        btnAdd:SetText(L["Add"])

        row.input = ebSpellID
        row.button = btnAdd
        row.category = category

        return row
    end

    local secContainer, secContent = CreateCategoryContainer(page, L["Secondary Group"], -25)
    local tertContainer, tertContent = CreateCategoryContainer(page, L["Tertiary Group"], -311)

    local function MoveSpell(spellID, currentCategory, direction)
        if not currentSpecID or not spellID then return end
        if CDM.SpellRegistry:Reorder(currentSpecID, spellID, currentCategory, direction) then
            API:InvalidateSpellRegistryCache(currentSpecID)
            RefreshSpellList()
            API:RefreshConfig()
        end
    end

    local function CreateSpellRow(parent, spellID, category, color)
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(340, 28)
        row.spellID = spellID
        row.category = category
        row.color = color

        local bgLeft = row:CreateTexture(nil, "BACKGROUND")
        bgLeft:SetAtlas("Options_ListExpand_Left", true)
        bgLeft:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)

        local bgRight = row:CreateTexture(nil, "BACKGROUND")
        bgRight:SetAtlas("Options_ListExpand_Right", true)
        bgRight:SetPoint("TOPRIGHT", row, "TOPRIGHT", -40, 0)
        row.bgRight = bgRight

        local leftWidth = bgLeft:GetWidth()
        local leftHeight = bgLeft:GetHeight()
        local rightWidth = bgRight:GetWidth()

        local bgMiddle = row:CreateTexture(nil, "BACKGROUND")
        bgMiddle:SetAtlas("_Options_ListExpand_Middle")
        bgMiddle:SetSize(340 - leftWidth - rightWidth - 40, leftHeight)
        bgMiddle:SetPoint("TOPLEFT", bgLeft, "TOPRIGHT", 0, 0)

        local btnExpand = CreateFrame("Button", nil, row)
        btnExpand:SetPoint("TOPLEFT", bgMiddle, "TOPLEFT", 0, 0)
        btnExpand:SetPoint("BOTTOMRIGHT", bgRight, "BOTTOMRIGHT", 0, 0)
        row.btnExpand = btnExpand

        local registry = CDM.db.spellRegistry and CDM.db.spellRegistry[currentSpecID]
        if not registry or not registry[category] then
            return row
        end

        local currentIndex = nil
        for i, id in ipairs(registry[category]) do
            if id == spellID then
                currentIndex = i
                break
            end
        end

        if not currentIndex then
            return row
        end

        local arrowContainer = CreateFrame("Frame", nil, row)
        arrowContainer:SetSize(58, 29)
        arrowContainer:SetPoint("TOPLEFT", 4, 0)

        local btnUp = CreateFrame("Button", nil, arrowContainer)
        btnUp:SetSize(29, 29)
        btnUp:SetPoint("LEFT", arrowContainer, "LEFT", 0, 0)
        btnUp:SetNormalAtlas("common-button-collapseExpand-up")
        btnUp:SetPushedAtlas("common-button-collapseExpand-up-pressed")
        btnUp:SetDisabledAtlas("common-button-collapseExpand-up-disabled")
        btnUp:SetHighlightAtlas("common-button-collapseExpand-hover")

        btnUp:SetScript("OnClick", function()
            MoveSpell(spellID, category, "up")
        end)

        if category == "secondary" and currentIndex == 1 then
            btnUp:SetEnabled(false)
        end

        local btnDown = CreateFrame("Button", nil, arrowContainer)
        btnDown:SetSize(29, 29)
        btnDown:SetPoint("LEFT", btnUp, "RIGHT", 0, 0)
        btnDown:SetNormalAtlas("common-button-collapseExpand-down")
        btnDown:SetPushedAtlas("common-button-collapseExpand-down-pressed")
        btnDown:SetDisabledAtlas("common-button-collapseExpand-down-disabled")
        btnDown:SetHighlightAtlas("common-button-collapseExpand-hover")

        btnDown:SetScript("OnClick", function()
            MoveSpell(spellID, category, "down")
        end)

        if category == "tertiary" and currentIndex == #registry.tertiary then
            btnDown:SetEnabled(false)
        end

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(24, 24)
        icon:SetPoint("TOP", row, "TOP", -60, -2)
        local spellTexture = C_Spell.GetSpellTexture(spellID)
        if spellTexture then
            icon:SetTexture(spellTexture)
        else
            icon:SetColorTexture(0.3, 0.3, 0.3)
        end

        local nameText = row:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        nameText:SetPoint("LEFT", icon, "RIGHT", 5, 0)
        local spellName = C_Spell.GetSpellName(spellID)
        nameText:SetText(spellName or L["Unknown"])
        UI.SetTextMuted(nameText)
        nameText:SetWidth(150)
        nameText:SetJustifyH("LEFT")

        local subPanel = CreateFrame("Frame", nil, row)
        subPanel:SetPoint("TOPLEFT", 0, -ROW_HEIGHT_COLLAPSED)
        subPanel:SetSize(340, SUBPANEL_HEIGHT)
        subPanel:Hide()
        row.subPanel = subPanel

        local colorLabel = subPanel:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        colorLabel:SetPoint("TOPLEFT", 8, -15)
        colorLabel:SetText(L["Border:"])
        UI.SetTextMuted(colorLabel)

        local colorPicker = UI.CreateSimpleColorPicker(subPanel, color, function(r, g, b)
            color.r, color.g, color.b = r, g, b
            API:SaveSpell(currentSpecID, spellID, category == "secondary", category == "tertiary", color)
            API:RefreshConfig()
        end)
        colorPicker:SetPoint("LEFT", colorLabel, "RIGHT", 6, 0)

        local glowCheckbox = UI.CreateModernCheckbox(
            subPanel,
            L["Enable Glow"],
            API:GetSpellGlowEnabled(currentSpecID, spellID),
            function(checked)
                API:SetSpellGlowEnabled(currentSpecID, spellID, checked)
            end
        )
        glowCheckbox:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 0, -10)
        UI.SetTextMuted(glowCheckbox.label)

        local glowColorLabel = subPanel:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        glowColorLabel:SetPoint("TOPLEFT", glowCheckbox, "BOTTOMLEFT", 0, -10)
        glowColorLabel:SetText(L["Glow Color:"])
        UI.SetTextMuted(glowColorLabel)

        local existingGlowColor = API:GetSpellGlowColor(currentSpecID, spellID) or { r = 1, g = 1, b = 1 }
        local glowColorPicker = UI.CreateSimpleColorPicker(subPanel, existingGlowColor, function(r, g, b)
            API:SetSpellGlowColor(currentSpecID, spellID, { r = r, g = g, b = b })
        end)
        glowColorPicker:SetPoint("LEFT", glowColorLabel, "RIGHT", 6, 0)

        function row:UpdateExpandState()
            self.isExpanded = (expandedSpellID == self.spellID)
            self:SetHeight(self.isExpanded and ROW_HEIGHT_EXPANDED or ROW_HEIGHT_COLLAPSED)
            self.subPanel:SetShown(self.isExpanded)
            self.bgRight:SetAtlas(
                self.isExpanded and "Options_ListExpand_Right_Expanded" or "Options_ListExpand_Right", true)
        end

        btnExpand:SetScript("OnClick", function()
            if expandedSpellID == spellID then
                expandedSpellID = nil
            else
                expandedSpellID = spellID
            end
            if row.onRepositionAll then
                row.onRepositionAll()
            end
        end)

        row:UpdateExpandState()

        function row:GetDynamicHeight()
            return (expandedSpellID == self.spellID) and ROW_HEIGHT_EXPANDED or ROW_HEIGHT_COLLAPSED
        end

        local btnRemove = CreateFrame("Button", nil, row)
        btnRemove:SetSize(32, 32)
        btnRemove:SetPoint("TOPRIGHT", -4, 2)
        btnRemove:SetNormalAtlas("128-RedButton-Exit")
        btnRemove:SetPushedAtlas("128-RedButton-Exit-Pressed")
        btnRemove:SetDisabledAtlas("128-RedButton-Exit-Disabled")
        btnRemove:SetHighlightAtlas("128-RedButton-Exit-Highlight")
        btnRemove:SetScript("OnClick", function()
            if expandedSpellID == spellID then
                expandedSpellID = nil
            end
            API:RemoveSpell(currentSpecID, spellID)
            RefreshSpellList()
            RefreshBuffOrderDisplay()
            API:RefreshConfig()
        end)

        row.btnUp = btnUp
        row.btnDown = btnDown
        row.btnRemove = btnRemove
        row.colorPicker = colorPicker

        return row
    end

    ---------------------------------------------------------------
    -- SPELL LIST MANAGER
    ---------------------------------------------------------------

    local function CreateSpellListManager()
        local function RepositionRows(contentContainer)
            local yOffset = 0
            for _, rowFrame in ipairs(contentContainer.rowFrames) do
                if rowFrame:IsShown() then
                    rowFrame:ClearAllPoints()
                    rowFrame:SetPoint("TOP", contentContainer, "TOP", 0, -yOffset)

                    if rowFrame.UpdateExpandState then
                        rowFrame:UpdateExpandState()
                    end

                    local height = (rowFrame.GetDynamicHeight and rowFrame:GetDynamicHeight()) or ROW_HEIGHT_COLLAPSED
                    yOffset = yOffset + height + ROW_SPACING
                end
            end
        end

        local function RepositionAll()
            RepositionRows(secContent)
            RepositionRows(tertContent)
        end

        local function PopulateCategory(registry, categoryName, contentContainer, spells)
            UI.ClearChildren(contentContainer)
            contentContainer.rowFrames = {}

            local spellCount = #spells

            for i, spellID in ipairs(spells) do
                local globalColor = CDM_C.GetConfigValue("borderColor", {r = 1, g = 1, b = 1, a = 1})
                local color = registry.colors[spellID] or {r = globalColor.r, g = globalColor.g, b = globalColor.b}
                local row = CreateSpellRow(contentContainer, spellID, categoryName, color)
                row:SetWidth(340)
                row.onRepositionAll = RepositionAll
                row:Show()
                table.insert(contentContainer.rowFrames, row)
            end

            if spellCount < 7 then
                local addRow = CreateAddSpellRow(contentContainer, categoryName)
                addRow:SetWidth(340)

                addRow.button:SetScript("OnClick", function()
                    if not currentSpecID then
                        print("|cffff0000" .. L["No specialization detected!"] .. "|r")
                        return
                    end

                    local inputSpellID = tonumber(addRow.input:GetText())
                    if not inputSpellID then
                        print("|cffff0000" .. L["Please enter a valid spell ID!"] .. "|r")
                        return
                    end

                    local spellName = C_Spell.GetSpellName(inputSpellID)
                    if not spellName then
                        print("|cffff0000" .. string.format(L["Spell ID %d does not exist!"], inputSpellID) .. "|r")
                        return
                    end

                    if #registry[categoryName] >= 7 then
                        print("|cffff0000" .. L["Category full (max 7 spells)"] .. "|r")
                        return
                    end

                    local isSecondary = (categoryName == "secondary")
                    local isTertiary = (categoryName == "tertiary")
                    local globalColor = CDM_C.GetConfigValue("borderColor", {r = 1, g = 1, b = 1, a = 1})
                    API:SaveSpell(currentSpecID, inputSpellID, isSecondary, isTertiary, {r = globalColor.r, g = globalColor.g, b = globalColor.b})

                    addRow.input:SetText("")

                    RefreshSpellList()
                    RefreshBuffOrderDisplay()
                    API:RefreshConfig()
                end)

                addRow.input:SetScript("OnEnterPressed", function()
                    addRow.button:Click()
                end)

                addRow:Show()
                table.insert(contentContainer.rowFrames, addRow)

                for i = spellCount + 2, 7 do
                    local placeholder = CreatePlaceholderRow(contentContainer, i)
                    placeholder:SetWidth(340)
                    placeholder:Show()
                    table.insert(contentContainer.rowFrames, placeholder)
                end
            end

            RepositionRows(contentContainer)
        end

        RefreshSpellList = function()
            if not currentSpecID then return end
            local registry = API:GetSpellRegistry(currentSpecID)
            PopulateCategory(registry, "secondary", secContent, registry.secondary)
            PopulateCategory(registry, "tertiary", tertContent, registry.tertiary)
        end
    end

    ---------------------------------------------------------------
    -- EVENT REGISTRATION
    ---------------------------------------------------------------

    local function RegisterTabEvents(QueueBuffOrderRefresh)
        page:HookScript("OnShow", function()
            RefreshCurrentSpecID()
            if currentSpecID then
                RefreshSpellList()
            end
            QueueBuffOrderRefresh(0.1)
        end)

        if EventRegistry then
            local function RefreshIfVisible()
                QueueBuffOrderRefresh(0)
            end

            if not eventRegistryTokens["Icons.CooldownViewerSettings.OnShow"] then
                eventRegistryTokens["Icons.CooldownViewerSettings.OnShow"] =
                    {
                        eventName = "CooldownViewerSettings.OnShow",
                        token = EventRegistry:RegisterCallback("CooldownViewerSettings.OnShow", RefreshIfVisible, CDM),
                    }
            end

            if not eventRegistryTokens["Icons.CooldownViewerSettings.OnHide"] then
                eventRegistryTokens["Icons.CooldownViewerSettings.OnHide"] =
                    {
                        eventName = "CooldownViewerSettings.OnHide",
                        token = EventRegistry:RegisterCallback("CooldownViewerSettings.OnHide", RefreshIfVisible, CDM),
                    }
            end

            if not eventRegistryTokens["Icons.CooldownViewerSettings.OnDataChanged"] then
                eventRegistryTokens["Icons.CooldownViewerSettings.OnDataChanged"] =
                    {
                        eventName = "CooldownViewerSettings.OnDataChanged",
                        token = EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", RefreshIfVisible, CDM),
                    }
            end

            if not eventRegistryTokens["Icons.CooldownViewerSettings.OnPendingChanges"] then
                eventRegistryTokens["Icons.CooldownViewerSettings.OnPendingChanges"] =
                    {
                        eventName = "CooldownViewerSettings.OnPendingChanges",
                        token = EventRegistry:RegisterCallback("CooldownViewerSettings.OnPendingChanges",
                            function()
                                RefreshIfVisible()
                            end, CDM),
                    }
            end
        end

        API:RegisterRefreshCallback("icons-spec-refresh", function()
            if page:IsVisible() then
                RefreshCurrentSpecID()
                RefreshSpellList()
                RefreshBuffOrderDisplay()
            end
        end, 30)
    end

    ---------------------------------------------------------------
    -- EXECUTE
    ---------------------------------------------------------------
    local QueueBuffOrderRefresh = CreateBuffOrderDisplay()
    CreateSpellListManager()
    RegisterTabEvents(QueueBuffOrderRefresh)
end

API:RegisterConfigTab("icons", L["Icons"], CreateSpellsTab, 7)
