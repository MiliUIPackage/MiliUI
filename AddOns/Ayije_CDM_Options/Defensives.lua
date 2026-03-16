local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L

local CDM_C = CDM.CONST
local BUILTIN_SET = CDM_C.DEFENSIVE_SPELLS_SET
local DEFENSIVE_SPELLS = CDM_C.DEFENSIVE_SPELLS
local _, playerClassTag = UnitClass("player")

local CLASS_LIST = {}
local CLASS_SPECS = {}

for i = 1, GetNumClasses() do
    local className, classTag, classID = GetClassInfo(i)
    if classTag and DEFENSIVE_SPELLS[classTag] then
        local color = RAID_CLASS_COLORS[classTag]
        CLASS_LIST[#CLASS_LIST + 1] = {
            classTag = classTag,
            className = className,
            classID = classID,
            r = color and color.r or 1,
            g = color and color.g or 1,
            b = color and color.b or 1,
        }
        local specs = {}
        for j = 1, GetNumSpecializationsForClassID(classID) do
            local specID, specName = GetSpecializationInfoForClassID(classID, j)
            if specID then
                specs[#specs + 1] = { specID = specID, specName = specName }
            end
        end
        CLASS_SPECS[classTag] = specs
    end
end

table.sort(CLASS_LIST, function(a, b) return a.className < b.className end)

local function SaveOrder(specID, order)
    if not specID then return end
    if not CDM.db.defensivesOrder then CDM.db.defensivesOrder = {} end
    CDM.db.defensivesOrder[specID] = {}
    for i, id in ipairs(order) do
        CDM.db.defensivesOrder[specID][i] = id
    end
end

local function CreateSpellsOverlay()
    local overlay = UI.CreateModalOverlay()
    local window = overlay.window

    local paddingX = 18
    local paddingY = 14
    local titleOffset = 28
    local windowWidth = 419
    local windowHeight = 524

    window:SetSize(windowWidth, windowHeight)

    local rowHeight = 29
    local contentWidth = windowWidth - paddingX * 2
    local startY = -(paddingY + titleOffset + 14)
    local gold = (CDM.CONST and CDM.CONST.GOLD) or { r = 1, g = 0.82, b = 0, a = 1 }

    local selectedClassTag = playerClassTag
    local selectedSpecID = API:GetCurrentSpecID()

    local function IsViewingPlayerSpec()
        return selectedClassTag == playerClassTag and selectedSpecID == API:GetCurrentSpecID()
    end

    local listContainer = CreateFrame("Frame", nil, window)
    listContainer:SetSize(contentWidth, 400)
    listContainer:SetPoint("TOPLEFT", paddingX, startY)

    local specDropdown = CreateFrame("DropdownButton", nil, window, "WowStyle1DropdownTemplate")
    specDropdown:SetWidth(200)
    specDropdown:SetPoint("TOPRIGHT", window, "TOPRIGHT", -paddingX, -(paddingY + 16))
    specDropdown:SetDefaultText(L["Current Spec"])

    local addLabel = window:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    addLabel:SetText(L["Add Custom Spell"])
    addLabel:SetTextColor(gold.r, gold.g, gold.b, gold.a or 1)
    addLabel:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", paddingX, paddingY + 36)

    local addRow = CreateFrame("Frame", nil, window)
    addRow:SetSize(400, 26)
    addRow:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", paddingX, paddingY + 8)

    local editBox = CreateFrame("EditBox", nil, addRow, "InputBoxTemplate")
    editBox:SetSize(120, 22)
    editBox:SetPoint("LEFT", addRow, "LEFT", 6, 0)
    editBox:SetAutoFocus(false)
    editBox:SetNumeric(true)
    editBox:SetMaxLetters(7)

    local placeholderText = editBox:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    placeholderText:SetPoint("LEFT", editBox, "LEFT", 2, 0)
    placeholderText:SetText(L["Spell ID"])
    placeholderText:SetTextColor(0.5, 0.5, 0.5, 0.7)
    editBox:SetScript("OnTextChanged", function(self)
        if self:GetText() == "" then placeholderText:Show() else placeholderText:Hide() end
    end)

    local addBtn = CreateFrame("Button", nil, addRow, "UIPanelButtonTemplate")
    addBtn:SetSize(60, 22)
    addBtn:SetPoint("LEFT", editBox, "RIGHT", 6, 0)
    addBtn:SetText(L["Add"])

    local statusText = addRow:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
    statusText:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
    statusText:SetPoint("RIGHT", window, "RIGHT", -paddingX, 0)
    statusText:SetJustifyH("LEFT")
    statusText:SetWordWrap(false)
    statusText:SetText("")

    local statusTimer
    local function SetStatus(text)
        statusText:SetText(text)
        if statusTimer then statusTimer:Cancel() end
        if text ~= "" then
            statusTimer = C_Timer.NewTimer(2, function() statusText:SetText("") end)
        end
    end

    local RebuildList

    local function SetSelection(classTag, specID)
        selectedClassTag = classTag
        selectedSpecID = specID
        if IsViewingPlayerSpec() then
            specDropdown:SetDefaultText(L["Current Spec"])
        else
            local specName = ""
            local className = ""
            local specs = CLASS_SPECS[classTag]
            if specs then
                for _, s in ipairs(specs) do
                    if s.specID == specID then
                        specName = s.specName
                        break
                    end
                end
            end
            for _, c in ipairs(CLASS_LIST) do
                if c.classTag == classTag then
                    className = c.className
                    break
                end
            end
            specDropdown:SetDefaultText(className .. " - " .. specName)
        end
        RebuildList()
    end

    specDropdown:SetupMenu(function(_, rootDescription)
        rootDescription:CreateRadio(L["Current Spec"], function()
            return IsViewingPlayerSpec()
        end, function()
            SetSelection(playerClassTag, API:GetCurrentSpecID())
        end)
        rootDescription:CreateDivider()
        for _, classInfo in ipairs(CLASS_LIST) do
            local color = RAID_CLASS_COLORS[classInfo.classTag]
            local coloredName = color and color:WrapTextInColorCode(classInfo.className) or classInfo.className
            local submenu = rootDescription:CreateButton(coloredName)
            local specs = CLASS_SPECS[classInfo.classTag]
            if specs then
                for _, specInfo in ipairs(specs) do
                    submenu:CreateRadio(specInfo.specName, function()
                        return selectedClassTag == classInfo.classTag and selectedSpecID == specInfo.specID
                    end, function()
                        SetSelection(classInfo.classTag, specInfo.specID)
                    end)
                end
            end
        end
    end)

    RebuildList = function()
        UI.ClearChildren(listContainer)

        local specID = selectedSpecID
        local isPlayerSpec = IsViewingPlayerSpec()
        local filterFn = isPlayerSpec and API.IsSpecSpell or nil
        local order = API.GetOrderedDefensiveSpells(specID, filterFn, selectedClassTag)
        local y = 0

        for idx, spellID in ipairs(order) do
            local isCustom = not BUILTIN_SET[spellID]

            local row = CreateFrame("Frame", nil, listContainer)
            row:SetSize(contentWidth, rowHeight)
            row:SetPoint("TOPLEFT", 0, -y)

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
            if idx == 1 then btnUp:SetEnabled(false) end

            btnUp:SetScript("OnClick", function()
                order[idx], order[idx - 1] = order[idx - 1], order[idx]
                SaveOrder(specID, order)
                if isPlayerSpec and CDM.ReinitDefensiveIcons then API:ReinitDefensiveIcons() end
                RebuildList()
            end)

            local btnDown = CreateFrame("Button", nil, arrowContainer)
            btnDown:SetSize(29, 29)
            btnDown:SetPoint("LEFT", btnUp, "RIGHT", 0, 0)
            btnDown:SetNormalAtlas("common-button-collapseExpand-down")
            btnDown:SetPushedAtlas("common-button-collapseExpand-down-pressed")
            btnDown:SetDisabledAtlas("common-button-collapseExpand-down-disabled")
            btnDown:SetHighlightAtlas("common-button-collapseExpand-hover")
            if idx == #order then btnDown:SetEnabled(false) end

            btnDown:SetScript("OnClick", function()
                order[idx], order[idx + 1] = order[idx + 1], order[idx]
                SaveOrder(specID, order)
                if isPlayerSpec and CDM.ReinitDefensiveIcons then API:ReinitDefensiveIcons() end
                RebuildList()
            end)

            local iconAnchor
            if not isCustom then
                local specDisabled = CDM.db.defensivesDisabledSpells and CDM.db.defensivesDisabledSpells[specID]
                local isDisabled = specDisabled and specDisabled[spellID]
                local cb = UI.CreateModernCheckbox(
                    row, "", not isDisabled,
                    function(checked)
                        if not CDM.db.defensivesDisabledSpells then
                            CDM.db.defensivesDisabledSpells = {}
                        end
                        if not CDM.db.defensivesDisabledSpells[specID] then
                            CDM.db.defensivesDisabledSpells[specID] = {}
                        end
                        if checked then
                            CDM.db.defensivesDisabledSpells[specID][spellID] = nil
                        else
                            CDM.db.defensivesDisabledSpells[specID][spellID] = true
                        end
                        API:RefreshConfig()
                    end
                )
                cb:SetSize(26, rowHeight)
                cb:SetPoint("LEFT", arrowContainer, "RIGHT", 4, 0)
                iconAnchor = cb
            else
                local spacer = CreateFrame("Frame", nil, row)
                spacer:SetSize(26, rowHeight)
                spacer:SetPoint("LEFT", arrowContainer, "RIGHT", 4, 0)
                iconAnchor = spacer
            end

            local displayID = API.GetEffectiveSpellID(spellID)

            local iconTex = row:CreateTexture(nil, "ARTWORK")
            iconTex:SetSize(20, 20)
            iconTex:SetPoint("LEFT", iconAnchor, "RIGHT", 4, 0)
            local texture = C_Spell.GetSpellTexture(displayID)
            if texture then
                iconTex:SetTexture(texture)
                iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end

            local nameText = row:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
            nameText:SetPoint("LEFT", iconTex, "RIGHT", 6, 0)
            nameText:SetText(C_Spell.GetSpellName(displayID) or tostring(spellID))

            if isCustom then
                local removeBtn = CreateFrame("Button", nil, row)
                removeBtn:SetSize(16, 16)
                removeBtn:SetPoint("LEFT", nameText, "RIGHT", 6, 0)
                removeBtn:SetNormalFontObject("AyijeCDM_Font14")
                removeBtn:SetHighlightFontObject("AyijeCDM_Font14")

                local removeBtnText = removeBtn:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
                removeBtnText:SetPoint("CENTER")
                removeBtnText:SetText("|cffff4444X|r")
                removeBtn:SetFontString(removeBtnText)

                removeBtn:SetScript("OnClick", function()
                    API:RemoveDefensiveSpell(spellID, specID)
                    RebuildList()
                end)
            end

            y = y + rowHeight
        end
    end

    local function DoAddSpell()
        local text = editBox:GetText()
        local spellID = tonumber(text)
        if not spellID or spellID <= 0 then
            SetStatus("|cffff4444" .. L["Enter a valid spell ID"] .. "|r")
            return
        end

        local spellName = C_Spell.GetSpellName(spellID)
        if not spellName then
            SetStatus("|cffff4444" .. L["Unknown spell ID"] .. "|r")
            return
        end

        if IsViewingPlayerSpec() and not API.IsSpecSpell(spellID) then
            SetStatus("|cffff4444" .. L["Not available for spec"] .. "|r")
            return
        end

        local ok = API:AddDefensiveSpell(spellID, selectedSpecID)
        if ok then
            editBox:SetText("")
            SetStatus("|cff44ff44" .. string.format(L["Added: %s"], spellName) .. "|r")
            RebuildList()
        else
            SetStatus("|cffff4444" .. L["Already tracked"] .. "|r")
        end
    end

    addBtn:SetScript("OnClick", DoAddSpell)
    editBox:SetScript("OnEnterPressed", function(self)
        DoAddSpell()
        self:ClearFocus()
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    overlay:HookScript("OnShow", function()
        selectedClassTag = playerClassTag
        selectedSpecID = API:GetCurrentSpecID()
        specDropdown:SetDefaultText(L["Current Spec"])
        RebuildList()
        SetStatus("")
    end)

    return overlay
end

local function CreateDefensivesTab(page, tabId)
    local scrollChild = UI.CreateScrollableTab(page, "AyijeCDM_DefensivesScrollFrame", 700, 370)

    local layout = UI.CreateVerticalLayout(0)
    local function NextY(spacing) return layout:Next(spacing) end

    local enabled = CDM.db.defensivesEnabled
    if enabled == nil then enabled = true end
    local setControlsEnabled  -- forward declaration
    page.controls.defensivesEnabled = UI.CreateModernCheckbox(
        scrollChild,
        L["Enable Defensives"],
        enabled,
        function(checked)
            CDM.db.defensivesEnabled = checked
            if setControlsEnabled then setControlsEnabled(checked) end
            API:RefreshConfig()
        end
    )
    page.controls.defensivesEnabled:SetPoint("TOPLEFT", -34, NextY(0))
    NextY(35)

    local hideFromViewers = CDM.db.defensivesHideFromViewers
    if hideFromViewers == nil then hideFromViewers = false end
    page.controls.defensivesHideFromViewers = UI.CreateModernCheckbox(
        scrollChild,
        L["Hide tracked defensives from Essential/Utility viewers"],
        hideFromViewers,
        function(checked)
            CDM.db.defensivesHideFromViewers = checked
            API:RefreshConfig()
        end
    )
    page.controls.defensivesHideFromViewers:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(35)

    local spellsHeader = UI.CreateHeader(scrollChild, L["Tracked Spells"])
    spellsHeader:SetPoint("TOPLEFT", 0, NextY(0))

    local manageSpellsButton = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
    manageSpellsButton:SetSize(160, 22)
    manageSpellsButton:SetText(L["Manage Spells"])
    manageSpellsButton:SetPoint("LEFT", spellsHeader, "RIGHT", 12, -2)
    NextY(30)

    local spellsOverlay = CreateSpellsOverlay()
    manageSpellsButton:SetScript("OnClick", function()
        spellsOverlay:Show()
    end)

    local iconSizeHeader = UI.CreateHeader(scrollChild, L["Icon Size"])
    iconSizeHeader:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(15)

    page.defensivesIconWidthSlider = UI.CreateModernSlider(
        scrollChild,
        L["Icon Width"],
        20, 100,
        CDM.db.defensivesIconWidth or 40,
        function(v)
            CDM.db.defensivesIconWidth = UI.RoundToInt(v)
            API:RefreshConfig()
        end
    )
    page.defensivesIconWidthSlider:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(60)

    page.defensivesIconHeightSlider = UI.CreateModernSlider(
        scrollChild,
        L["Icon Height"],
        20, 100,
        CDM.db.defensivesIconHeight or 36,
        function(v)
            CDM.db.defensivesIconHeight = UI.RoundToInt(v)
            API:RefreshConfig()
        end
    )
    page.defensivesIconHeightSlider:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(60)

    local positionHeader = UI.CreateHeader(scrollChild, L["Position"])
    positionHeader:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(15)

    local lblAnchor = scrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    lblAnchor:SetText(L["Anchor Position (relative to Player Frame)"])
    lblAnchor:SetPoint("TOPLEFT", 0, NextY(0))

    local ddAnchor = CreateFrame("DropdownButton", nil, scrollChild, "WowStyle1DropdownTemplate")
    ddAnchor:SetPoint("TOPLEFT", lblAnchor, "BOTTOMLEFT", 0, -10)
    ddAnchor:SetWidth(180)
    ddAnchor:SetDefaultText(CDM.db.defensivesAnchorPoint or "TOPLEFT")
    page.defensivesAnchorDropdown = ddAnchor
    NextY(45)

    UI.SetupPositionDropdown(
        ddAnchor,
        function() return CDM.db.defensivesAnchorPoint or "TOPLEFT" end,
        function(pos)
            CDM.db.defensivesAnchorPoint = pos
            ddAnchor:SetDefaultText(pos)
            API:RefreshConfig()
        end,
        {"TOPLEFT", "BOTTOMLEFT", "TOPRIGHT", "BOTTOMRIGHT"}
    )

    page.defensivesOffsetXSlider = UI.CreateModernSlider(
        scrollChild,
        L["X Offset"],
        -500, 500,
        CDM.db.defensivesOffsetX or 0,
        function(v)
            CDM.db.defensivesOffsetX = UI.RoundToInt(v)
            API:RefreshConfig()
        end
    )
    page.defensivesOffsetXSlider:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(60)

    page.defensivesOffsetYSlider = UI.CreateModernSlider(
        scrollChild,
        L["Y Offset"],
        -500, 500,
        CDM.db.defensivesOffsetY or 0,
        function(v)
            CDM.db.defensivesOffsetY = UI.RoundToInt(v)
            API:RefreshConfig()
        end
    )
    page.defensivesOffsetYSlider:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(60)

    local cooldownHeader = UI.CreateHeader(scrollChild, L["Cooldown"])
    cooldownHeader:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(15)

    page.defensivesCooldownFontSizeSlider = UI.CreateModernSlider(
        scrollChild,
        L["Font Size"],
        8, 32,
        CDM.db.defensivesCooldownFontSize or 12,
        function(v)
            CDM.db.defensivesCooldownFontSize = UI.RoundToInt(v)
            API:RefreshConfig()
        end
    )
    page.defensivesCooldownFontSizeSlider:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(60)

    local stacksHeader = UI.CreateHeader(scrollChild, L["Stacks"])
    stacksHeader:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(15)

    page.defensivesChargeFontSizeSlider = UI.CreateModernSlider(
        scrollChild,
        L["Font Size"],
        8, 32,
        CDM.db.defensivesChargeFontSize or 10,
        function(v)
            CDM.db.defensivesChargeFontSize = UI.RoundToInt(v)
            API:RefreshConfig()
        end
    )
    page.defensivesChargeFontSizeSlider:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(60)

    local lblChargePos = scrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    lblChargePos:SetText(L["Text Position"])
    lblChargePos:SetPoint("TOPLEFT", 0, NextY(0))

    local ddChargePos = CreateFrame("DropdownButton", nil, scrollChild, "WowStyle1DropdownTemplate")
    ddChargePos:SetPoint("TOPLEFT", lblChargePos, "BOTTOMLEFT", 0, -10)
    ddChargePos:SetWidth(180)
    ddChargePos:SetDefaultText(CDM.db.defensivesChargePosition or "BOTTOMRIGHT")
    page.defensivesChargePosDropdown = ddChargePos
    NextY(45)

    UI.SetupPositionDropdown(
        ddChargePos,
        function() return CDM.db.defensivesChargePosition or "BOTTOMRIGHT" end,
        function(pos)
            CDM.db.defensivesChargePosition = pos
            ddChargePos:SetDefaultText(pos)
            API:RefreshConfig()
        end
    )

    page.defensivesChargeOffsetXSlider = UI.CreateModernSlider(
        scrollChild,
        L["Text X Offset"],
        -20, 20,
        CDM.db.defensivesChargeOffsetX or 0,
        function(v)
            CDM.db.defensivesChargeOffsetX = UI.RoundToInt(v)
            API:RefreshConfig()
        end
    )
    page.defensivesChargeOffsetXSlider:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(60)

    page.defensivesChargeOffsetYSlider = UI.CreateModernSlider(
        scrollChild,
        L["Text Y Offset"],
        -20, 20,
        CDM.db.defensivesChargeOffsetY or 0,
        function(v)
            CDM.db.defensivesChargeOffsetY = UI.RoundToInt(v)
            API:RefreshConfig()
        end
    )
    page.defensivesChargeOffsetYSlider:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(60)

    setControlsEnabled = UI.SetupModuleToggle(scrollChild, page.controls.defensivesEnabled)
    setControlsEnabled(enabled)
end

API:RegisterConfigTab("defensives", L["Defensives"], CreateDefensivesTab, 10.1)
