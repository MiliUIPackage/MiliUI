local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local Shared = ns.GroupEditorShared
local L = Runtime.L

local function CreateBlacklistOverlay()
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

    local titleText = window:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    titleText:SetText(L["Trinket Blacklist"])
    titleText:SetPoint("TOPLEFT", window, "TOPLEFT", paddingX, -(paddingY + 16))

    local listContainer = CreateFrame("Frame", nil, window)
    listContainer:SetSize(contentWidth, 400)
    listContainer:SetPoint("TOPLEFT", paddingX, startY)

    local addLabel = window:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    addLabel:SetText(L["Add Item"])
    addLabel:SetTextColor(CDM.CONST.GOLD.r, CDM.CONST.GOLD.g, CDM.CONST.GOLD.b, 1)
    addLabel:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", paddingX, paddingY + 56)

    local addRow = CreateFrame("Frame", nil, window)
    addRow:SetSize(400, 26)
    addRow:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", paddingX, paddingY + 8)

    local editBox = CreateFrame("EditBox", nil, addRow, "InputBoxTemplate")
    editBox:SetSize(120, 22)
    editBox:SetPoint("LEFT", addRow, "LEFT", 6, 0)
    editBox:SetAutoFocus(false)
    editBox:SetNumeric(true)
    editBox:SetMaxLetters(7)

    UI.AttachPlaceholder(editBox, L["Item ID"])

    local addBtn = CreateFrame("Button", nil, addRow, "UIPanelButtonTemplate")
    addBtn:SetSize(60, 22)
    addBtn:SetPoint("LEFT", editBox, "RIGHT", 6, 0)
    addBtn:SetText(L["Add"])

    local statusText = window:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
    statusText:SetPoint("BOTTOMLEFT", addRow, "TOPLEFT", 0, 4)
    statusText:SetPoint("BOTTOMRIGHT", addRow, "TOPRIGHT", 0, 4)
    statusText:SetJustifyH("LEFT")
    statusText:SetWordWrap(false)
    statusText:SetText("")

    local SetStatus = UI.CreateTimedStatus(statusText)

    local RebuildList
    local pendingLoads = {}

    local function EnsureItemInfo(itemID)
        if pendingLoads[itemID] then return end
        if C_Item.GetItemInfo(itemID) then return end
        pendingLoads[itemID] = true
        C_Item.RequestLoadItemDataByID(itemID)
        local item = Item:CreateFromItemID(itemID)
        item:ContinueOnItemLoad(function()
            pendingLoads[itemID] = nil
            if overlay:IsShown() then RebuildList() end
        end)
    end

    RebuildList = function()
        UI.ClearChildren(listContainer)

        local list = CDM.db.trinketsBlacklist
        if not list then return end

        local y = 0
        for idx, itemID in ipairs(list) do
            local row = CreateFrame("Frame", nil, listContainer)
            row:SetSize(contentWidth, rowHeight)
            row:SetPoint("TOPLEFT", 0, -y)

            local iconTex = row:CreateTexture(nil, "ARTWORK")
            iconTex:SetSize(20, 20)
            iconTex:SetPoint("LEFT", row, "LEFT", 8, 0)
            local texture = C_Item.GetItemIconByID(itemID)
            if texture and texture ~= 0 then
                iconTex:SetTexture(texture)
                CDM.CONST.ApplyIconTexCoord(iconTex, CDM.CONST.GetEffectiveZoomAmount())
            end

            local nameText = row:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
            nameText:SetPoint("LEFT", iconTex, "RIGHT", 6, 0)
            local name = C_Item.GetItemInfo(itemID)
            if name then
                nameText:SetText(name)
            else
                nameText:SetText(tostring(itemID) .. " " .. L["(loading...)"])
                EnsureItemInfo(itemID)
            end

            local removeBtn = CreateFrame("Button", nil, row)
            removeBtn:SetSize(16, 16)
            removeBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            Shared.ApplyRemoveButtonText(removeBtn)

            removeBtn:SetScript("OnClick", function()
                table.remove(list, idx)
                RebuildList()
                API:Refresh("TRACKERS")
            end)

            y = y + rowHeight
        end
    end

    local function DoAddItem()
        local text = editBox:GetText()
        local itemID = tonumber(text)
        if not itemID or itemID <= 0 then
            SetStatus("|cffff4444" .. L["Enter a valid item ID"] .. "|r")
            return
        end
        if not C_Item.DoesItemExistByID(itemID) then
            SetStatus("|cffff4444" .. L["Unknown item ID"] .. "|r")
            return
        end

        local list = CDM.db.trinketsBlacklist
        if not list then
            list = {}
            CDM.db.trinketsBlacklist = list
        end
        for i = 1, #list do
            if list[i] == itemID then
                SetStatus("|cffff4444" .. L["Already blacklisted"] .. "|r")
                return
            end
        end

        list[#list + 1] = itemID
        editBox:SetText("")
        local name = C_Item.GetItemInfo(itemID) or tostring(itemID)
        SetStatus("|cff44ff44" .. string.format(L["Added: %s"], name) .. "|r")
        RebuildList()
        API:Refresh("TRACKERS")
    end

    addBtn:SetScript("OnClick", DoAddItem)
    editBox:SetScript("OnEnterPressed", function(self)
        DoAddItem()
        self:ClearFocus()
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    overlay:HookScript("OnShow", function()
        RebuildList()
        SetStatus("")
    end)

    return overlay
end

local MODE_OPTIONS = {
    { value = "independent", label = L["Independent"] },
    { value = "defensives",  label = L["Append to Defensives"] },
    { value = "essential",   label = L["Append to Spells"] },
}

local ROW_OPTIONS = {
    { value = 1, label = L["Row 1"] },
    { value = 2, label = L["Row 2"] },
}

local POSITION_OPTIONS = {
    { value = "start", label = L["Start"] },
    { value = "end",   label = L["End"] },
}

local function GetCurrentMode()
    return CDM.db.trinketsMode or "independent"
end

local function GetModeLabel(mode)
    return UI.GetOptionLabel(MODE_OPTIONS, mode, L["Independent"])
end

local function GetRowLabel(row)
    return UI.GetOptionLabel(ROW_OPTIONS, row, L["Row 1"])
end

local function GetPositionLabel(pos)
    return UI.GetOptionLabel(POSITION_OPTIONS, pos, L["End"])
end

local function CreateTrinketsTab(page, tabId)
    local scrollChild = UI.CreateScrollableTab(page, "AyijeCDM_TrinketsScrollFrame", 700, 500)

    local layout = UI.CreateVerticalLayout(0)
    local function NextY(spacing) return layout:Next(spacing) end

    local iconSizeControls = {}
    local positionControls = {}
    local cooldownControls = {}
    local essentialOnlyControls = {}

    local enabled = CDM.db.trinketsEnabled ~= false
    local setControlsEnabled
    page.controls.trinketsEnabled = UI.CreateModernCheckbox(
        scrollChild,
        L["Enable Trinkets"],
        enabled,
        function(checked)
            CDM.db.trinketsEnabled = checked
            if setControlsEnabled then setControlsEnabled(checked) end
            API:Refresh("TRACKERS")
        end
    )
    page.controls.trinketsEnabled:SetPoint("TOPLEFT", -34, NextY(0))

    local manageBlacklistBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
    manageBlacklistBtn:SetSize(160, 22)
    manageBlacklistBtn:SetText(L["Manage Blacklist"])
    manageBlacklistBtn:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -10, -2)

    local blacklistOverlay = CreateBlacklistOverlay()
    manageBlacklistBtn:SetScript("OnClick", function()
        blacklistOverlay:Show()
    end)

    NextY(35)

    local layoutHeader = UI.CreateHeader(scrollChild, L["Layout Mode"])
    layoutHeader:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(25)

    local lblMode = scrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    lblMode:SetText(L["Display Mode"])
    lblMode:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(30)

    local ddMode = CreateFrame("DropdownButton", nil, scrollChild, "WowStyle1DropdownTemplate")
    ddMode:SetPoint("TOPLEFT", 0, NextY(0))
    ddMode:SetWidth(200)
    ddMode:SetDefaultText(GetModeLabel(GetCurrentMode()))
    page.controls.trinketsMode = ddMode
    local lblRow = scrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    lblRow:SetText(L["Row"])
    lblRow:SetPoint("TOPLEFT", ddMode, "BOTTOMLEFT", 0, -15)
    table.insert(essentialOnlyControls, lblRow)

    local ddRow = CreateFrame("DropdownButton", nil, scrollChild, "WowStyle1DropdownTemplate")
    ddRow:SetPoint("TOPLEFT", lblRow, "BOTTOMLEFT", 0, -10)
    ddRow:SetWidth(150)
    ddRow:SetDefaultText(GetRowLabel(CDM.db.trinketsEssentialRow or 1))
    page.controls.trinketsEssentialRow = ddRow
    table.insert(essentialOnlyControls, ddRow)

    UI.SetupValueDropdown(ddRow, ROW_OPTIONS,
        function() return CDM.db.trinketsEssentialRow or 1 end,
        function(value, label)
            CDM.db.trinketsEssentialRow = value
            ddRow:SetDefaultText(label)
            API:Refresh("TRACKERS")
        end
    )

    local lblPos = scrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    lblPos:SetText(L["Position in Row"])
    lblPos:SetPoint("TOPLEFT", ddRow, "BOTTOMLEFT", 0, -15)
    table.insert(essentialOnlyControls, lblPos)

    local ddPos = CreateFrame("DropdownButton", nil, scrollChild, "WowStyle1DropdownTemplate")
    ddPos:SetPoint("TOPLEFT", lblPos, "BOTTOMLEFT", 0, -10)
    ddPos:SetWidth(150)
    ddPos:SetDefaultText(GetPositionLabel(CDM.db.trinketsEssentialPosition or "end"))
    page.controls.trinketsEssentialPosition = ddPos
    table.insert(essentialOnlyControls, ddPos)

    UI.SetupValueDropdown(ddPos, POSITION_OPTIONS,
        function() return CDM.db.trinketsEssentialPosition or "end" end,
        function(value, label)
            CDM.db.trinketsEssentialPosition = value
            ddPos:SetDefaultText(label)
            API:Refresh("TRACKERS")
        end
    )

    local showPassiveDefault = CDM.db.trinketsShowPassive ~= false

    page.controls.trinketsShowPassive = UI.CreateModernCheckbox(
        scrollChild,
        L["Show Passive Trinkets"],
        showPassiveDefault,
        function(checked)
            CDM.db.trinketsShowPassive = checked
            API:Refresh("TRACKERS")
        end
    )
    page.controls.trinketsShowPassive:SetPoint("TOPLEFT", ddMode, "BOTTOMLEFT", 0, -15)
    lblRow:ClearAllPoints()
    lblRow:SetPoint("TOPLEFT", page.controls.trinketsShowPassive, "BOTTOMLEFT", 0, -15)

    local iconSizeHeader = UI.CreateHeader(scrollChild, L["Icon Size"])
    iconSizeHeader:SetPoint("TOPLEFT", page.controls.trinketsShowPassive, "BOTTOMLEFT", 34, -20)
    table.insert(iconSizeControls, iconSizeHeader)

    page.controls.trinketsIconWidthSlider = UI.CreateModernSlider(
        scrollChild,
        L["Icon Width"],
        20, 100,
        CDM.db.trinketsIconWidth or 40,
        function(v)
            CDM.db.trinketsIconWidth = UI.RoundToInt(v)
            API:Refresh("TRACKERS")
        end
    )
    page.controls.trinketsIconWidthSlider:SetPoint("TOPLEFT", iconSizeHeader, "BOTTOMLEFT", 0, -15)
    table.insert(iconSizeControls, page.controls.trinketsIconWidthSlider)

    page.controls.trinketsIconHeightSlider = UI.CreateModernSlider(
        scrollChild,
        L["Icon Height"],
        20, 100,
        CDM.db.trinketsIconHeight or 36,
        function(v)
            CDM.db.trinketsIconHeight = UI.RoundToInt(v)
            API:Refresh("TRACKERS")
        end
    )
    page.controls.trinketsIconHeightSlider:SetPoint("TOPLEFT", page.controls.trinketsIconWidthSlider, "BOTTOMLEFT", 0, -20)
    table.insert(iconSizeControls, page.controls.trinketsIconHeightSlider)

    local positionHeader = UI.CreateHeader(scrollChild, L["Position"])
    positionHeader:SetPoint("TOPLEFT", page.controls.trinketsIconHeightSlider, "BOTTOMLEFT", 0, -20)
    table.insert(positionControls, positionHeader)

    local lblAnchor = scrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    lblAnchor:SetText(L["Anchor Position (relative to Player Frame)"])
    lblAnchor:SetPoint("TOPLEFT", positionHeader, "BOTTOMLEFT", 0, -15)
    table.insert(positionControls, lblAnchor)

    local ddAnchor = CreateFrame("DropdownButton", nil, scrollChild, "WowStyle1DropdownTemplate")
    ddAnchor:SetPoint("TOPLEFT", lblAnchor, "BOTTOMLEFT", 0, -10)
    ddAnchor:SetWidth(180)
    ddAnchor:SetDefaultText(CDM.db.trinketsAnchorPoint or "TOPLEFT")
    page.controls.trinketsAnchorDropdown = ddAnchor
    table.insert(positionControls, ddAnchor)

    UI.SetupPositionDropdown(
        ddAnchor,
        function() return CDM.db.trinketsAnchorPoint or "TOPLEFT" end,
        function(pos)
            CDM.db.trinketsAnchorPoint = pos
            ddAnchor:SetDefaultText(pos)
            API:Refresh("TRACKERS")
        end,
        {"TOPLEFT", "BOTTOMLEFT", "TOPRIGHT", "BOTTOMRIGHT"}
    )

    page.controls.trinketsOffsetXSlider = UI.CreateModernSlider(
        scrollChild,
        L["X Offset"],
        -500, 500,
        CDM.db.trinketsOffsetX or 0,
        function(v)
            CDM.db.trinketsOffsetX = UI.RoundToInt(v)
            API:Refresh("TRACKERS")
        end
    )
    page.controls.trinketsOffsetXSlider:SetPoint("TOPLEFT", ddAnchor, "BOTTOMLEFT", 0, -15)
    table.insert(positionControls, page.controls.trinketsOffsetXSlider)

    page.controls.trinketsOffsetYSlider = UI.CreateModernSlider(
        scrollChild,
        L["Y Offset"],
        -500, 500,
        CDM.db.trinketsOffsetY or 0,
        function(v)
            CDM.db.trinketsOffsetY = UI.RoundToInt(v)
            API:Refresh("TRACKERS")
        end
    )
    page.controls.trinketsOffsetYSlider:SetPoint("TOPLEFT", page.controls.trinketsOffsetXSlider, "BOTTOMLEFT", 0, -20)
    table.insert(positionControls, page.controls.trinketsOffsetYSlider)

    local cooldownHeader = UI.CreateHeader(scrollChild, L["Cooldown"])
    table.insert(cooldownControls, cooldownHeader)

    page.controls.trinketsCooldownFontSizeSlider = UI.CreateModernSlider(
        scrollChild,
        L["Font Size"],
        8, 32,
        CDM.db.trinketsCooldownFontSize or 12,
        function(v)
            CDM.db.trinketsCooldownFontSize = UI.RoundToInt(v)
            API:Refresh("TRACKERS")
        end
    )
    page.controls.trinketsCooldownFontSizeSlider:SetPoint("TOPLEFT", cooldownHeader, "BOTTOMLEFT", 0, -15)
    table.insert(cooldownControls, page.controls.trinketsCooldownFontSizeSlider)

    local function UpdateSectionVisibility()
        local mode = GetCurrentMode()
        local isEssential = (mode == "essential")
        local isIndependent = (mode == "independent")

        for _, ctrl in ipairs(essentialOnlyControls) do
            ctrl:SetShown(isEssential)
        end

        for _, ctrl in ipairs(iconSizeControls) do
            ctrl:SetShown(not isEssential)
        end

        for _, ctrl in ipairs(positionControls) do
            ctrl:SetShown(isIndependent)
        end

        for _, ctrl in ipairs(cooldownControls) do
            ctrl:SetShown(not isEssential)
        end

        cooldownHeader:ClearAllPoints()
        if isIndependent then
            cooldownHeader:SetPoint("TOPLEFT", page.controls.trinketsOffsetYSlider, "BOTTOMLEFT", 0, -20)
        else
            cooldownHeader:SetPoint("TOPLEFT", page.controls.trinketsIconHeightSlider, "BOTTOMLEFT", 0, -20)
        end
    end

    UI.SetupValueDropdown(ddMode, MODE_OPTIONS,
        function() return GetCurrentMode() end,
        function(value, label)
            CDM.db.trinketsMode = value
            ddMode:SetDefaultText(label)
            UpdateSectionVisibility()
            API:Refresh("TRACKERS")
        end
    )

    UpdateSectionVisibility()

    setControlsEnabled = UI.SetupModuleToggle(scrollChild, page.controls.trinketsEnabled)
    setControlsEnabled(enabled)
end

API:RegisterConfigTab("trinkets", L["Trinkets"], CreateTrinketsTab, 11.1)
