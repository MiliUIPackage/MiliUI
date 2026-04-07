local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L

local function SaveOrder(specID, order)
    if not specID then return end
    if not CDM.db.racialsOrderPerSpec then CDM.db.racialsOrderPerSpec = {} end
    CDM.db.racialsOrderPerSpec[specID] = {}
    for i, id in ipairs(order) do
        CDM.db.racialsOrderPerSpec[specID][i] = id
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
    local startY = -(paddingY + titleOffset)

    local listContainer = CreateFrame("Frame", nil, window)
    listContainer:SetSize(contentWidth, 400)
    listContainer:SetPoint("TOPLEFT", paddingX, startY)

    local gold = { r = 1, g = 0.82, b = 0 }

    local addLabel = window:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    addLabel:SetText(L["Add Custom Spell or Item"])
    addLabel:SetTextColor(gold.r, gold.g, gold.b, 1)
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
    placeholderText:SetText("ID")
    placeholderText:SetTextColor(0.5, 0.5, 0.5, 0.7)
    editBox:SetScript("OnTextChanged", function(self)
        if self:GetText() == "" then placeholderText:Show() else placeholderText:Hide() end
    end)

    local addSpellBtn = CreateFrame("Button", nil, addRow, "UIPanelButtonTemplate")
    addSpellBtn:SetSize(60, 22)
    addSpellBtn:SetPoint("LEFT", editBox, "RIGHT", 6, 0)
    addSpellBtn:SetText(L["Spell"])

    local addItemBtn = CreateFrame("Button", nil, addRow, "UIPanelButtonTemplate")
    addItemBtn:SetSize(60, 22)
    addItemBtn:SetPoint("LEFT", addSpellBtn, "RIGHT", 4, 0)
    addItemBtn:SetText(L["Item"])

    local statusText = addRow:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
    statusText:SetPoint("LEFT", addItemBtn, "RIGHT", 8, 0)
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
    local pendingItemRetry = false

    local function DoAddEntry(isItem)
        local text = editBox:GetText()
        local id = tonumber(text)

        if not id or id <= 0 then
            SetStatus("|cffff4444" .. L["Enter a valid ID"] .. "|r")
            return
        end

        local displayName
        if isItem then
            displayName = C_Item.GetItemNameByID(id)
            if not displayName then
                SetStatus("|cffff4444" .. L["Loading item data, try again"] .. "|r")
                C_Item.RequestLoadItemDataByID(id)
                return
            end
        else
            displayName = C_Spell.GetSpellName(id)
            if not displayName then
                SetStatus("|cffff4444" .. L["Unknown spell ID"] .. "|r")
                return
            end
        end
        local ok = API:AddRacialEntry(id, isItem)
        if ok then
            editBox:SetText("")
            SetStatus("|cff44ff44" .. string.format(L["Added: %s"], displayName or tostring(id)) .. "|r")
            RebuildList()
        else
            SetStatus("|cffff4444" .. L["Already tracked"] .. "|r")
        end
    end

    addSpellBtn:SetScript("OnClick", function() DoAddEntry(false) end)
    addItemBtn:SetScript("OnClick", function() DoAddEntry(true) end)
    editBox:SetScript("OnEnterPressed", function(self) DoAddEntry(false); self:ClearFocus() end)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    RebuildList = function()
        pendingItemRetry = false
        UI.ClearChildren(listContainer)

        local specID = API:GetCurrentSpecID()
        local entries = API.GetOrderedRacialEntries(specID)
        local order = {}
        for _, entry in ipairs(entries) do
            order[#order + 1] = entry.id
        end

        local y = 0
        for idx, entry in ipairs(entries) do
            local id = entry.id
            local isItem = entry.isItem
            local isCustom = entry.isCustom

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
                API:ReinitRacialIcons()
                RebuildList()
            end)

            local btnDown = CreateFrame("Button", nil, arrowContainer)
            btnDown:SetSize(29, 29)
            btnDown:SetPoint("LEFT", btnUp, "RIGHT", 0, 0)
            btnDown:SetNormalAtlas("common-button-collapseExpand-down")
            btnDown:SetPushedAtlas("common-button-collapseExpand-down-pressed")
            btnDown:SetDisabledAtlas("common-button-collapseExpand-down-disabled")
            btnDown:SetHighlightAtlas("common-button-collapseExpand-hover")
            if idx == #entries then btnDown:SetEnabled(false) end

            btnDown:SetScript("OnClick", function()
                order[idx], order[idx + 1] = order[idx + 1], order[idx]
                SaveOrder(specID, order)
                API:ReinitRacialIcons()
                RebuildList()
            end)

            local iconAnchor
            if not isCustom then
                local isDisabled = CDM.db.racialsDisabled and CDM.db.racialsDisabled[id]
                local cb = UI.CreateModernCheckbox(
                    row, "", not isDisabled,
                    function(checked)
                        if not CDM.db.racialsDisabled then
                            CDM.db.racialsDisabled = {}
                        end
                        if checked then
                            CDM.db.racialsDisabled[id] = nil
                        else
                            CDM.db.racialsDisabled[id] = true
                        end
                        API:Refresh()
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

            local iconTex = row:CreateTexture(nil, "ARTWORK")
            iconTex:SetSize(20, 20)
            iconTex:SetPoint("LEFT", iconAnchor, "RIGHT", 4, 0)
            local texture = isItem and C_Item.GetItemIconByID(id) or C_Spell.GetSpellTexture(id)
            if texture then
                iconTex:SetTexture(texture)
                iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end

            local nameText = row:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
            nameText:SetPoint("LEFT", iconTex, "RIGHT", 6, 0)
            local name = isItem and C_Item.GetItemNameByID(id) or C_Spell.GetSpellName(id)
            nameText:SetText(name or tostring(id))

            if isItem and (not name or not texture) then
                C_Item.RequestLoadItemDataByID(id)
                if not pendingItemRetry then
                    pendingItemRetry = true
                    C_Timer.After(0.3, function()
                        pendingItemRetry = false
                        if overlay:IsShown() then
                            RebuildList()
                        end
                    end)
                end
            end

            if isCustom then
                local removeBtn = CreateFrame("Button", nil, row)
                removeBtn:SetSize(16, 16)
                removeBtn:SetPoint("LEFT", nameText, "RIGHT", 6, 0)

                local removeBtnText = removeBtn:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
                removeBtnText:SetPoint("CENTER")
                removeBtnText:SetText("|cffff4444X|r")
                removeBtn:SetFontString(removeBtnText)

                removeBtn:SetScript("OnClick", function()
                    API:RemoveRacialEntry(id)
                    RebuildList()
                end)
            end

            y = y + rowHeight
        end
    end

    overlay:HookScript("OnShow", function()
        SetStatus("")
        RebuildList()
    end)

    return overlay
end

local function CreateRacialsTab(page, tabId)
    local scrollChild = UI.CreateScrollableTab(page, "AyijeCDM_RacialsScrollFrame", 700, 370)

    local layout = UI.CreateVerticalLayout(0)
    local function NextY(spacing) return layout:Next(spacing) end

    local enabled = CDM.db.racialsEnabled
    if enabled == nil then enabled = true end
    local setControlsEnabled
    local function UpdateShowItemsAtZeroStacksState()
        local checkbox = page.controls.racialsShowItemsAtZeroStacks and page.controls.racialsShowItemsAtZeroStacks.checkbox
        local frame = page.controls.racialsShowItemsAtZeroStacks
        local controlsEnabled = CDM.db.racialsEnabled ~= false

        if checkbox then
            checkbox:SetEnabled(controlsEnabled)
        end
        if frame then
            frame:SetAlpha(controlsEnabled and 1 or 0.5)
        end
    end

    page.controls.racialsEnabled = UI.CreateModernCheckbox(
        scrollChild,
        L["Enable Racials"],
        enabled,
        function(checked)
            CDM.db.racialsEnabled = checked
            UpdateShowItemsAtZeroStacksState()
            if setControlsEnabled then setControlsEnabled(checked) end
            API:Refresh()
        end
    )
    page.controls.racialsEnabled:SetPoint("TOPLEFT", -34, NextY(0))

    local showItemsAtZeroStacks = CDM.db.racialsShowItemsAtZeroStacks or false
    page.controls.racialsShowItemsAtZeroStacks = UI.CreateModernCheckbox(
        scrollChild,
        L["Show Items at 0 Stacks"],
        showItemsAtZeroStacks,
        function(checked)
            CDM.db.racialsShowItemsAtZeroStacks = checked
            API:Refresh()
        end
    )
    page.controls.racialsShowItemsAtZeroStacks:SetPoint("LEFT", page.controls.racialsEnabled, "RIGHT", 0, 0)
    UpdateShowItemsAtZeroStacksState()
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
    NextY(30)

    page.racialsIconWidthSlider = UI.CreateModernSlider(
        scrollChild, L["Icon Width"], 20, 100,
        CDM.db.racialsIconWidth or 40,
        function(v)
            CDM.db.racialsIconWidth = UI.RoundToInt(v)
            API:Refresh()
        end
    )
    page.racialsIconWidthSlider:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(60)

    page.racialsIconHeightSlider = UI.CreateModernSlider(
        scrollChild, L["Icon Height"], 20, 100,
        CDM.db.racialsIconHeight or 36,
        function(v)
            CDM.db.racialsIconHeight = UI.RoundToInt(v)
            API:Refresh()
        end
    )
    page.racialsIconHeightSlider:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(60)

    local partyHeader = UI.CreateHeader(scrollChild, L["Party Frame Anchoring"])
    partyHeader:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(30)

    local UpdateControls

    page.racialsUsePartyFrameCheckbox = UI.CreateModernCheckbox(
        scrollChild,
        L["Anchor to Party Frame"],
        CDM.db.racialsUsePartyFrame or false,
        function(checked)
            CDM.db.racialsUsePartyFrame = checked
            UpdateControls()
            API:Refresh()
        end
    )
    page.racialsUsePartyFrameCheckbox:SetPoint("TOPLEFT", 0, NextY(0))

    local lblPartyFrameSide = scrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    lblPartyFrameSide:SetText(L["Side (relative to Party Frame)"])
    lblPartyFrameSide:SetPoint("TOPLEFT", page.racialsUsePartyFrameCheckbox, "BOTTOMLEFT", 0, -10)
    page.racialsPartyFrameSideLabel = lblPartyFrameSide

    local ddPartyFrameSide = CreateFrame("DropdownButton", nil, scrollChild, "WowStyle1DropdownTemplate")
    ddPartyFrameSide:SetPoint("TOPLEFT", lblPartyFrameSide, "BOTTOMLEFT", 0, -10)
    ddPartyFrameSide:SetWidth(180)
    ddPartyFrameSide:SetDefaultText(CDM.db.racialsPartyFrameSide or "LEFT")
    page.racialsPartyFrameSideDropdown = ddPartyFrameSide

    ddPartyFrameSide:SetupMenu(function(dropdown, rootDescription)
        local sides = {"LEFT", "RIGHT"}
        for _, side in ipairs(sides) do
            rootDescription:CreateButton(side, function()
                local currentSide = CDM.db.racialsPartyFrameSide or "LEFT"
                if currentSide ~= side then
                    local currentOffsetX = CDM.db.racialsPartyFrameOffsetX or -6
                    CDM.db.racialsPartyFrameOffsetX = -currentOffsetX
                    page.racialsPartyFrameOffsetXSlider:UpdateUIValue(-currentOffsetX)
                end
                CDM.db.racialsPartyFrameSide = side
                ddPartyFrameSide:SetDefaultText(side)
                API:Refresh()
            end)
        end
    end)

    page.racialsPartyFrameOffsetXSlider = UI.CreateModernSlider(
        scrollChild, L["Party Frame X Offset"], -100, 100,
        CDM.db.racialsPartyFrameOffsetX or -6,
        function(v)
            CDM.db.racialsPartyFrameOffsetX = UI.RoundToInt(v)
            API:Refresh()
        end
    )
    page.racialsPartyFrameOffsetXSlider:SetPoint("TOPLEFT", ddPartyFrameSide, "BOTTOMLEFT", 0, -15)

    page.racialsPartyFrameOffsetYSlider = UI.CreateModernSlider(
        scrollChild, L["Party Frame Y Offset"], -100, 100,
        CDM.db.racialsPartyFrameOffsetY or 19,
        function(v)
            CDM.db.racialsPartyFrameOffsetY = UI.RoundToInt(v)
            API:Refresh()
        end
    )
    page.racialsPartyFrameOffsetYSlider:SetPoint("TOPLEFT", page.racialsPartyFrameOffsetXSlider, "BOTTOMLEFT", 0, -10)

    local positionHeader = UI.CreateHeader(scrollChild, L["Position"], page.racialsUsePartyFrameCheckbox, -15)

    local lblAnchor = scrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    lblAnchor:SetText(L["Anchor Position (relative to Player Frame)"])
    lblAnchor:SetPoint("TOPLEFT", positionHeader, "BOTTOMLEFT", 0, -15)

    local ddAnchor = CreateFrame("DropdownButton", nil, scrollChild, "WowStyle1DropdownTemplate")
    ddAnchor:SetPoint("TOPLEFT", lblAnchor, "BOTTOMLEFT", 0, -10)
    ddAnchor:SetWidth(180)
    ddAnchor:SetDefaultText(CDM.db.racialsAnchorPoint or "TOPLEFT")
    page.racialsAnchorDropdown = ddAnchor

    UI.SetupPositionDropdown(
        ddAnchor,
        function() return CDM.db.racialsAnchorPoint or "TOPLEFT" end,
        function(pos)
            CDM.db.racialsAnchorPoint = pos
            ddAnchor:SetDefaultText(pos)
            API:Refresh()
        end,
        {"TOPLEFT", "BOTTOMLEFT", "TOPRIGHT", "BOTTOMRIGHT"}
    )

    page.racialsOffsetXSlider = UI.CreateModernSlider(
        scrollChild, L["X Offset"], -500, 500,
        CDM.db.racialsOffsetX or 0,
        function(v)
            CDM.db.racialsOffsetX = UI.RoundToInt(v)
            API:Refresh()
        end
    )
    page.racialsOffsetXSlider:SetPoint("TOPLEFT", ddAnchor, "BOTTOMLEFT", 0, -15)

    page.racialsOffsetYSlider = UI.CreateModernSlider(
        scrollChild, L["Y Offset"], -500, 500,
        CDM.db.racialsOffsetY or 0,
        function(v)
            CDM.db.racialsOffsetY = UI.RoundToInt(v)
            API:Refresh()
        end
    )
    page.racialsOffsetYSlider:SetPoint("TOPLEFT", page.racialsOffsetXSlider, "BOTTOMLEFT", 0, -10)

    local cooldownHeader = UI.CreateHeader(scrollChild, L["Cooldown"])

    page.racialsCooldownFontSizeSlider = UI.CreateModernSlider(
        scrollChild, L["Font Size"], 8, 32,
        CDM.db.racialsCooldownFontSize or 12,
        function(v)
            CDM.db.racialsCooldownFontSize = UI.RoundToInt(v)
            API:Refresh()
        end
    )
    page.racialsCooldownFontSizeSlider:SetPoint("TOPLEFT", cooldownHeader, "BOTTOMLEFT", 0, -15)

    local stacksHeader = UI.CreateHeader(scrollChild, L["Stacks"], page.racialsCooldownFontSizeSlider, -15)

    page.racialsChargeFontSizeSlider = UI.CreateModernSlider(
        scrollChild, L["Font Size"], 8, 32,
        CDM.db.racialsChargeFontSize or 15,
        function(v)
            CDM.db.racialsChargeFontSize = UI.RoundToInt(v)
            API:Refresh()
        end
    )
    page.racialsChargeFontSizeSlider:SetPoint("TOPLEFT", stacksHeader, "BOTTOMLEFT", 0, -15)

    page.racialsChargeColorPicker = UI.CreateColorSwatch(scrollChild, L["Color"], "racialsChargeColor")
    page.racialsChargeColorPicker:SetPoint("TOPLEFT", page.racialsChargeFontSizeSlider, "BOTTOMLEFT", 0, -10)

    local lblChargePos = scrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    lblChargePos:SetText(L["Text Position"])
    lblChargePos:SetPoint("TOPLEFT", page.racialsChargeColorPicker, "BOTTOMLEFT", 0, -10)

    local ddChargePos = CreateFrame("DropdownButton", nil, scrollChild, "WowStyle1DropdownTemplate")
    ddChargePos:SetPoint("TOPLEFT", lblChargePos, "BOTTOMLEFT", 0, -10)
    ddChargePos:SetWidth(180)
    ddChargePos:SetDefaultText(CDM.db.racialsChargePosition or "BOTTOMRIGHT")
    page.racialsChargePosDropdown = ddChargePos

    UI.SetupPositionDropdown(
        ddChargePos,
        function() return CDM.db.racialsChargePosition or "BOTTOMRIGHT" end,
        function(pos)
            CDM.db.racialsChargePosition = pos
            ddChargePos:SetDefaultText(pos)
            API:Refresh()
        end
    )

    page.racialsChargeOffsetXSlider = UI.CreateModernSlider(
        scrollChild, L["Text X Offset"], -20, 20,
        CDM.db.racialsChargeOffsetX or 0,
        function(v)
            CDM.db.racialsChargeOffsetX = UI.RoundToInt(v)
            API:Refresh()
        end
    )
    page.racialsChargeOffsetXSlider:SetPoint("TOPLEFT", ddChargePos, "BOTTOMLEFT", 0, -15)

    page.racialsChargeOffsetYSlider = UI.CreateModernSlider(
        scrollChild, L["Text Y Offset"], -20, 20,
        CDM.db.racialsChargeOffsetY or 0,
        function(v)
            CDM.db.racialsChargeOffsetY = UI.RoundToInt(v)
            API:Refresh()
        end
    )
    page.racialsChargeOffsetYSlider:SetPoint("TOPLEFT", page.racialsChargeOffsetXSlider, "BOTTOMLEFT", 0, -10)

    UpdateControls = function()
        local usePartyFrame = page.racialsUsePartyFrameCheckbox:GetChecked()

        lblPartyFrameSide:SetShown(usePartyFrame)
        ddPartyFrameSide:SetShown(usePartyFrame)
        page.racialsPartyFrameOffsetXSlider:SetShown(usePartyFrame)
        page.racialsPartyFrameOffsetYSlider:SetShown(usePartyFrame)

        positionHeader:SetShown(not usePartyFrame)
        lblAnchor:SetShown(not usePartyFrame)
        ddAnchor:SetShown(not usePartyFrame)
        page.racialsOffsetXSlider:SetShown(not usePartyFrame)
        page.racialsOffsetYSlider:SetShown(not usePartyFrame)

        cooldownHeader:ClearAllPoints()
        if usePartyFrame then
            cooldownHeader:SetPoint("TOPLEFT", page.racialsPartyFrameOffsetYSlider, "BOTTOMLEFT", 0, -15)
        else
            cooldownHeader:SetPoint("TOPLEFT", page.racialsOffsetYSlider, "BOTTOMLEFT", 0, -15)
        end
    end

    UpdateControls()

    setControlsEnabled = UI.SetupModuleToggle(scrollChild, page.controls.racialsEnabled)
    setControlsEnabled(enabled)
end

API:RegisterConfigTab("racials", L["Racials"], CreateRacialsTab, 9)
