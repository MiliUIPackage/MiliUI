local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L

local RESOURCES_REFRESH_SCOPES = { "resources_visuals", "castbar_visuals", "trackers_layout", "viewers" }

local function RefreshResourcesConfig()
    if API.RefreshScopes then
        API:RefreshScopes(RESOURCES_REFRESH_SCOPES)
        return
    end
    API:RefreshConfig()
end

local function ForEachTagTextFrame(fn)
    if not CDM.TAGS or not CDM.TAGS.textFrames then return end
    for _, textFrame in pairs(CDM.TAGS.textFrames) do
        fn(textFrame)
    end
end

local function RefreshTagStyleAndText()
    ForEachTagTextFrame(function(textFrame)
        CDM.TAGS:UpdateTagStyle(textFrame)
        CDM.TAGS:UpdateTagText(textFrame)
    end)
end

local function RefreshTagPositions()
    ForEachTagTextFrame(function(textFrame)
        CDM.TAGS:UpdateTagPosition(textFrame)
    end)
end

local function RefreshTagStyle()
    ForEachTagTextFrame(function(textFrame)
        CDM.TAGS:UpdateTagStyle(textFrame)
    end)
end

local RESOURCE_COLOR_DEFS = {
    { key = "resourcesBackgroundColor", label = L["Background"], always = true },
    { key = "resourcesRageColor", label = L["Rage"] },
    { key = "resourcesEnergyColor", label = L["Energy"] },
    { key = "resourcesFocusColor", label = L["Focus"] },
    { key = "resourcesLunarPowerColor", label = L["Astral Power"] },
    { key = "resourcesMaelstromColor", label = L["Maelstrom"] },
    { key = "resourcesInsanityColor", label = L["Insanity"] },
    { key = "resourcesFuryColor", label = L["Fury"] },
    { key = "resourcesManaColor", label = L["Mana"] },
    { key = "resourcesEssenceColor", label = L["Essence"] },
    { key = "resourcesEssenceRechargingColor", label = L["Essence Recharging"] },
    { key = "resourcesComboPointsColor", label = L["Combo Points"] },
    { key = "resourcesComboPointsChargedColor", label = L["Charged"] },
    { key = "resourcesComboPointsChargedEmptyColor", label = L["Charged Empty"] },
    { key = "resourcesHolyPowerColor", label = L["Holy Power"] },
    { key = "resourcesSoulShardsColor", label = L["Soul Shards"] },
    { key = "resourcesSoulShardsRechargingColor", label = L["Soul Shards Partial"] },
    { key = "resourcesArcaneChargesColor", label = L["Arcane Charges"] },
    { key = "resourcesChiColor", label = L["Chi"] },
    { key = "resourcesRunicPowerColor", label = L["Runic Power"] },
    { key = "resourcesRunesReadyColor", label = L["Runes Ready"] },
    { key = "resourcesRunesRechargingColor", label = L["Runes Recharging"] },
    { key = "resourcesSoulFragmentsColor", label = L["Soul Fragments"] },
    { key = "resourcesDevourerSoulFragmentsColor", label = L["Devourer Souls"] },
    { key = "resourcesStaggerLightColor", label = L["Light (<30%)"] },
    { key = "resourcesStaggerModerateColor", label = L["Moderate (30-60%)"] },
    { key = "resourcesStaggerHeavyColor", label = L["Heavy (>60%)"] },
}

local CLASS_RESOURCE_KEYS = {
    DEATHKNIGHT = {
        "resourcesRunicPowerColor",
        "resourcesRunesReadyColor",
        "resourcesRunesRechargingColor",
    },
    DEMONHUNTER = {
        "resourcesFuryColor",
        "resourcesSoulFragmentsColor",
        "resourcesDevourerSoulFragmentsColor",
    },
    DRUID = {
        "resourcesManaColor",
        "resourcesRageColor",
        "resourcesEnergyColor",
        "resourcesComboPointsColor",
        "resourcesLunarPowerColor",
    },
    EVOKER = {
        "resourcesManaColor",
        "resourcesEssenceColor",
        "resourcesEssenceRechargingColor",
    },
    HUNTER = {
        "resourcesFocusColor",
    },
    MAGE = {
        "resourcesManaColor",
        "resourcesArcaneChargesColor",
    },
    MONK = {
        "resourcesManaColor",
        "resourcesEnergyColor",
        "resourcesChiColor",
        "resourcesStaggerLightColor",
        "resourcesStaggerModerateColor",
        "resourcesStaggerHeavyColor",
    },
    PALADIN = {
        "resourcesManaColor",
        "resourcesHolyPowerColor",
    },
    PRIEST = {
        "resourcesManaColor",
        "resourcesInsanityColor",
    },
    ROGUE = {
        "resourcesEnergyColor",
        "resourcesComboPointsColor",
        "resourcesComboPointsChargedColor",
        "resourcesComboPointsChargedEmptyColor",
    },
    SHAMAN = {
        "resourcesManaColor",
        "resourcesMaelstromColor",
    },
    WARLOCK = {
        "resourcesManaColor",
        "resourcesSoulShardsColor",
        "resourcesSoulShardsRechargingColor",
    },
    WARRIOR = {
        "resourcesRageColor",
    },
}

local function BuildClassResourceSet(playerClass)
    local keys = CLASS_RESOURCE_KEYS[playerClass]
    if not keys then
        return {}
    end

    local set = {}
    for _, key in ipairs(keys) do
        set[key] = true
    end
    return set
end

local function CreateResourcesTab(page, tabId)
    local resourcesScrollChild = UI.CreateScrollableTab(page, "AyijeCDM_ResourcesScrollFrame", 1250, 370)

    local layout = UI.CreateVerticalLayout(0)
    local function NextY(spacing) return layout:Next(spacing) end

    local enabled = CDM.db.resourcesEnabled
    if enabled == nil then enabled = true end
    local setControlsEnabled  -- forward declaration
    page.controls.resourcesEnabled = UI.CreateModernCheckbox(
        resourcesScrollChild,
        L["Enable Resources"],
        enabled,
        function(checked)
            CDM.db.resourcesEnabled = checked
            if not checked and CDM.db.castBarAnchorToResources then
                CDM.db.castBarAnchorToResources = false
            end
            if setControlsEnabled then setControlsEnabled(checked) end
            RefreshResourcesConfig()
        end
    )
    page.controls.resourcesEnabled:SetPoint("TOPLEFT", -34, NextY(0))
    NextY(35)

    local resourcesBarSizeHeader = UI.CreateHeader(resourcesScrollChild, L["Bar Dimensions"])
    resourcesBarSizeHeader:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(30)

    page.resourcesBarHeightSlider = UI.CreateModernSlider(
        resourcesScrollChild,
        L["Bar 1 Height"],
        4,
        40,
        CDM.db.resourcesBarHeight or 16,
        function(v)
            CDM.db.resourcesBarHeight = UI.RoundToInt(v)
            RefreshResourcesConfig()
        end
    )
    page.resourcesBarHeightSlider:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(60)

    page.resourcesBar2HeightSlider = UI.CreateModernSlider(
        resourcesScrollChild,
        L["Bar 2 Height"],
        4,
        40,
        CDM.db.resourcesBar2Height or 16,
        function(v)
            CDM.db.resourcesBar2Height = UI.RoundToInt(v)
            RefreshResourcesConfig()
        end
    )
    page.resourcesBar2HeightSlider:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(60)

    page.resourcesBarWidthSlider = UI.CreateModernSlider(
        resourcesScrollChild,
        L["Bar Width (0 = Auto)"],
        0,
        600,
        CDM.db.resourcesBarWidth or 0,
        function(v)
            local value = UI.RoundToInt(v)
            if value > 0 and value < 60 then
                value = 60
                page.resourcesBarWidthSlider.Slider:SetValue(60)
            end
            CDM.db.resourcesBarWidth = value
            RefreshResourcesConfig()
        end
    )
    page.resourcesBarWidthSlider:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(60)

    page.resourcesBarSpacingSlider = UI.CreateModernSlider(
        resourcesScrollChild,
        L["Bar Spacing (Vertical)"],
        -1,
        20,
        CDM.db.resourcesBarSpacing or 2,
        function(v)
            CDM.db.resourcesBarSpacing = UI.RoundToInt(v)
            RefreshResourcesConfig()
        end
    )
    page.resourcesBarSpacingSlider:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(50)

    page.unifiedBorderCheckbox = UI.CreateModernCheckbox(
        resourcesScrollChild,
        L["Unified Border (wrap all bars)"],
        CDM.db.resourcesUnifiedBorder,
        function(checked)
            CDM.db.resourcesUnifiedBorder = checked
            RefreshResourcesConfig()
        end
    )
    page.unifiedBorderCheckbox:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(30)

    page.moveBuffsDownCheckbox = UI.CreateModernCheckbox(
        resourcesScrollChild,
        L["Move buffs down dynamically"],
        CDM.db.resourcesMoveBuffsDown,
        function(checked)
            CDM.db.resourcesMoveBuffsDown = checked
            RefreshResourcesConfig()
        end
    )
    page.moveBuffsDownCheckbox:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(30)

    local manaSpecsTable = CDM.MANA_SPECS
    local currentSpecID = API:GetCurrentSpecID()
    if not currentSpecID and manaSpecsTable and not page.manaRetryScheduled then
        page.manaRetryScheduled = true
        C_Timer.After(0.5, function()
            if not ns.ConfigFrame or not ns.ConfigFrame:IsShown() then return end
            if not API:GetCurrentSpecID() then return end
            API:RebuildConfigFrame("resources")
        end)
    end
    if manaSpecsTable and currentSpecID and manaSpecsTable[currentSpecID] ~= nil then
        page.manaEnabledCheckbox = UI.CreateModernCheckbox(
            resourcesScrollChild,
            L["Show Mana Bar"],
            API:GetManaEnabled(),
            function(checked)
                API:SetManaEnabled(checked)
                RefreshResourcesConfig()
            end
        )
        page.manaEnabledCheckbox:SetPoint("TOPLEFT", 0, NextY(0))

        local manaPercentVal = CDM.db.resourcesManaPercentage
        if manaPercentVal == nil then manaPercentVal = false end
        page.manaPercentCheckbox = UI.CreateModernCheckbox(
            resourcesScrollChild,
            L["Display Mana as %"],
            manaPercentVal,
            function(checked)
                CDM.db.resourcesManaPercentage = checked
                if CDM.TAGS then
                    CDM.TAGS:UpdateAllTags()
                end
            end
        )
        page.manaPercentCheckbox:SetPoint("LEFT", page.manaEnabledCheckbox, "LEFT", 200, 0)
        NextY(30)
    end

    NextY(30)

    local barTextureLabel = resourcesScrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    barTextureLabel:SetText(L["Bar Texture:"])
    barTextureLabel:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(20)

    local ddBarTexture = CreateFrame("DropdownButton", nil, resourcesScrollChild, "WowStyle1DropdownTemplate")
    ddBarTexture:SetPoint("TOPLEFT", 0, NextY(0))
    ddBarTexture:SetWidth(220)
    ddBarTexture:SetDefaultText(CDM.db.resourcesBarTexture or L["Select Texture..."])
    page.barTextureDropdown = ddBarTexture

    UI.SetupMediaDropdown(
        ddBarTexture,
        "statusbar",
        function() return CDM.db.resourcesBarTexture end,
        function(name)
            CDM.db.resourcesBarTexture = name
            RefreshResourcesConfig()
        end,
        function(name)
            ddBarTexture:SetDefaultText(name)
        end
    )
    NextY(60)

    local bgTextureLabel = resourcesScrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    bgTextureLabel:SetText(L["Background Texture:"])
    bgTextureLabel:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(20)

    local ddBgTexture = CreateFrame("DropdownButton", nil, resourcesScrollChild, "WowStyle1DropdownTemplate")
    ddBgTexture:SetPoint("TOPLEFT", 0, NextY(0))
    ddBgTexture:SetWidth(220)
    ddBgTexture:SetDefaultText(CDM.db.resourcesBarBackgroundTexture or L["Select Texture..."])
    page.bgTextureDropdown = ddBgTexture

    UI.SetupMediaDropdown(
        ddBgTexture,
        "statusbar",
        function() return CDM.db.resourcesBarBackgroundTexture end,
        function(name)
            CDM.db.resourcesBarBackgroundTexture = name
            RefreshResourcesConfig()
        end,
        function(name)
            ddBgTexture:SetDefaultText(name)
        end
    )
    NextY(50)

    local resourcesPositionHeader = UI.CreateHeader(resourcesScrollChild, L["Position Offsets"])
    resourcesPositionHeader:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(30)

    page.resourcesOffsetXSlider = UI.CreateModernSlider(
        resourcesScrollChild,
        L["X Offset"],
        -600,
        600,
        CDM.db.resourcesOffsetX or 0,
        function(v)
            CDM.db.resourcesOffsetX = UI.RoundToInt(v)
            RefreshResourcesConfig()
        end
    )
    page.resourcesOffsetXSlider:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(60)

    page.resourcesOffsetYSlider = UI.CreateModernSlider(
        resourcesScrollChild,
        L["Y Offset"],
        -600,
        600,
        CDM.db.resourcesOffsetY or -200,
        function(v)
            CDM.db.resourcesOffsetY = UI.RoundToInt(v)
            RefreshResourcesConfig()
        end
    )
    page.resourcesOffsetYSlider:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(50)

    local resourcesColorsHeader = UI.CreateHeader(resourcesScrollChild, L["Power Type Colors"])
    resourcesColorsHeader:SetPoint("TOPLEFT", 0, NextY(0))

    local showAllColorsButton = CreateFrame("Button", nil, resourcesScrollChild, "UIPanelButtonTemplate")
    showAllColorsButton:SetSize(160, 22)
    showAllColorsButton:SetText(L["Show All Colors"])
    showAllColorsButton:SetPoint("LEFT", resourcesColorsHeader, "RIGHT", 12, -2)
    NextY(30)

    local _, playerClass = UnitClass("player")
    local classResourceSet = BuildClassResourceSet(playerClass)
    local colorItems = {}

    local function AddColorItem(def)
        local swatch = UI.CreateColorSwatch(resourcesScrollChild, def.label, def.key, RESOURCES_REFRESH_SCOPES)
        table.insert(colorItems, {
            frame = swatch,
            key = def.key,
            always = def.always,
            spacing = 60,
        })
        return swatch
    end

    local staggerNote = resourcesScrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    staggerNote:SetText(L["Stagger uses threshold colors: "] .. "|cFF85E685" .. L["Light"] .. "|r |cFFFFD95C" .. L["Moderate"] .. "|r |cFFFF6B6B" .. L["Heavy"] .. "|r")
    UI.SetTextMuted(staggerNote)

    for _, def in ipairs(RESOURCE_COLOR_DEFS) do
        if def.key == "resourcesStaggerLightColor" then
            table.insert(colorItems, {
                frame = staggerNote,
                isNote = true,
                onlyClass = "MONK",
                spacing = 25,
            })
        end

        local swatch = AddColorItem(def)
        if def.key == "resourcesBackgroundColor" then
            page.backgroundColorPicker = swatch
        end
    end

    local function LayoutColorItems(startY)
        local visibleItems = {}
        for _, item in ipairs(colorItems) do
            local showItem
            if item.isNote then
                showItem = (playerClass == item.onlyClass)
            else
                showItem = item.always or classResourceSet[item.key]
            end

            if showItem then
                table.insert(visibleItems, item)
            else
                item.frame:Hide()
            end
        end

        local y = startY
        for i, item in ipairs(visibleItems) do
            item.frame:Show()
            item.frame:ClearAllPoints()
            item.frame:SetPoint("TOPLEFT", 0, y)
            if i < #visibleItems then
                y = y - item.spacing
            end
        end

        return y
    end

    local colorsStartY = layout:Next(0)
    local colorsEndY = LayoutColorItems(colorsStartY)
    layout.y = colorsEndY
    NextY(50)

    local function CreateAllColorsOverlay()
        local overlay = UI.CreateModalOverlay()
        local window = overlay.window

        local swatchWidth = 250
        local columnCount = 3
        local columnGap = 26
        local paddingX = 18
        local paddingY = 14
        local titleOffset = 28
        local swatchRowSpacing = 34
        local headerSpacing = 18
        local sectionSpacing = 12
        local backgroundGap = 20

        local windowWidth = (paddingX * 2) + (swatchWidth * columnCount) + (columnGap * (columnCount - 1))

        local labelByKey = {}
        for _, def in ipairs(RESOURCE_COLOR_DEFS) do
            labelByKey[def.key] = def.label
        end

        local classOrder = {
            "WARRIOR",
            "PALADIN",
            "HUNTER",
            "ROGUE",
            "PRIEST",
            "DEATHKNIGHT",
            "SHAMAN",
            "MAGE",
            "WARLOCK",
            "MONK",
            "DRUID",
            "DEMONHUNTER",
            "EVOKER",
        }

        local classNames = {
            WARRIOR = L["Warrior"],
            PALADIN = L["Paladin"],
            HUNTER = L["Hunter"],
            ROGUE = L["Rogue"],
            PRIEST = L["Priest"],
            DEATHKNIGHT = L["Death Knight"],
            SHAMAN = L["Shaman"],
            MAGE = L["Mage"],
            WARLOCK = L["Warlock"],
            MONK = L["Monk"],
            DRUID = L["Druid"],
            DEMONHUNTER = L["Demon Hunter"],
            EVOKER = L["Evoker"],
        }

        local columns = {}
        for i = 1, columnCount do
            columns[i] = {
                x = paddingX + (i - 1) * (swatchWidth + columnGap),
                height = 0,
                classes = {},
            }
        end

        local function EstimateClassHeight(classKey)
            local keys = CLASS_RESOURCE_KEYS[classKey] or {}
            local swatchCount = 0
            for _, key in ipairs(keys) do
                if key ~= "resourcesManaColor" then
                    swatchCount = swatchCount + 1
                end
            end
            return headerSpacing + (swatchCount * swatchRowSpacing) + sectionSpacing
        end

        for _, classKey in ipairs(classOrder) do
            local bestColumn = columns[1]
            for i = 2, #columns do
                if columns[i].height < bestColumn.height then
                    bestColumn = columns[i]
                end
            end

            local sectionHeight = EstimateClassHeight(classKey)
            table.insert(bestColumn.classes, classKey)
            bestColumn.height = bestColumn.height + sectionHeight
        end

        local maxColumnHeight = 0
        for _, column in ipairs(columns) do
            if column.height > maxColumnHeight then
                maxColumnHeight = column.height
            end
        end

        local backgroundHeight = 30 + backgroundGap
        local windowHeight = paddingY + titleOffset + backgroundHeight + maxColumnHeight + paddingY
        window:SetSize(windowWidth, windowHeight)

        local backgroundSwatch = UI.CreateColorSwatch(window, L["Background"], "resourcesBackgroundColor", RESOURCES_REFRESH_SCOPES)
        backgroundSwatch:SetPoint("TOPLEFT", paddingX, -(paddingY + titleOffset))

        local manaSwatch = UI.CreateColorSwatch(window, L["Mana"], "resourcesManaColor", RESOURCES_REFRESH_SCOPES)
        manaSwatch:SetPoint("TOPLEFT", paddingX + swatchWidth + columnGap, -(paddingY + titleOffset))

        local startY = -(paddingY + titleOffset) - backgroundHeight
        local gold = (CDM.CONST and CDM.CONST.GOLD) or { r = 1, g = 0.82, b = 0, a = 1 }

        for _, column in ipairs(columns) do
            local y = startY
            for _, classKey in ipairs(column.classes) do
                local header = window:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
                header:SetPoint("TOPLEFT", column.x, y)
                header:SetText(classNames[classKey] or classKey)
                header:SetTextColor(gold.r, gold.g, gold.b, gold.a or 1)
                y = y - headerSpacing

                local keys = CLASS_RESOURCE_KEYS[classKey] or {}
                for _, key in ipairs(keys) do
                    if key ~= "resourcesManaColor" then  -- Mana shown globally next to Background
                        local label = labelByKey[key] or key
                        local swatch = UI.CreateColorSwatch(window, label, key, RESOURCES_REFRESH_SCOPES)
                        swatch:SetPoint("TOPLEFT", column.x, y)
                        y = y - swatchRowSpacing
                    end
                end

                y = y - sectionSpacing
            end
        end

        return overlay
    end

    local allColorsOverlay = CreateAllColorsOverlay()
    showAllColorsButton:SetScript("OnClick", function()
        allColorsOverlay:Show()
    end)

    local resourcesTagsHeader = UI.CreateHeader(resourcesScrollChild, L["Tags (Power Value Text)"])
    resourcesTagsHeader:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(30)

    local anchorOptions = {
        { value = "LEFT", label = L["Left"] },
        { value = "CENTER", label = L["Center"] },
        { value = "RIGHT", label = L["Right"] },
    }

    for barNum = 1, 2 do
        local isBar2 = (barNum == 2)
        local label = string.format(L["Bar %s"], barNum)
        local prefix = "bar" .. barNum
        local fontSizeKey = "resourcesBar" .. barNum .. "TagFontSize"
        local anchorKey = "resourcesBar" .. barNum .. "TagAnchor"
        local offsetXKey = "resourcesBar" .. barNum .. "TagOffsetX"
        local offsetYKey = "resourcesBar" .. barNum .. "TagOffsetY"
        local colorKey = "resourcesBar" .. barNum .. "TagColor"

        page[prefix .. "TagEnabledCheck"] = UI.CreateModernCheckbox(
            resourcesScrollChild,
            string.format(L["Enable %s Tag (current value)"], label),
            API:GetTagEnabled(isBar2),
            function(checked)
                API:SetTagEnabled(isBar2, checked)
                if CDM.TAGS then CDM.TAGS:UpdateAllTags() end
            end
        )
        page[prefix .. "TagEnabledCheck"]:SetPoint("TOPLEFT", 0, NextY(0))
        NextY(35)

        page[prefix .. "TagFontSizeSlider"] = UI.CreateModernSlider(
            resourcesScrollChild,
            string.format(L["%s Font Size"], label),
            8, 32,
            CDM.db[fontSizeKey] or 14,
            function(v)
                CDM.db[fontSizeKey] = UI.RoundToInt(v)
                RefreshTagStyleAndText()
            end
        )
        page[prefix .. "TagFontSizeSlider"]:SetPoint("TOPLEFT", 0, NextY(0))
        NextY(60)

        local anchorLabel = resourcesScrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
        anchorLabel:SetText(string.format(L["%s Anchor:"], label))
        anchorLabel:SetPoint("TOPLEFT", 0, NextY(0))
        NextY(20)

        local ddAnchor = CreateFrame("DropdownButton", nil, resourcesScrollChild, "WowStyle1DropdownTemplate")
        ddAnchor:SetPoint("TOPLEFT", 0, NextY(0))
        ddAnchor:SetWidth(150)
        ddAnchor:SetDefaultText(CDM.db[anchorKey] or "CENTER")
        page[prefix .. "AnchorDropdown"] = ddAnchor

        UI.SetupValueDropdown(
            ddAnchor,
            anchorOptions,
            function() return CDM.db[anchorKey] end,
            function(value)
                CDM.db[anchorKey] = value
                ddAnchor:SetDefaultText(value)
                RefreshTagPositions()
            end
        )
        NextY(60)

        page[prefix .. "TagOffsetXSlider"] = UI.CreateModernSlider(
            resourcesScrollChild,
            string.format(L["%s Offset X"], label),
            -50, 50,
            CDM.db[offsetXKey] or 0,
            function(v)
                CDM.db[offsetXKey] = UI.RoundToInt(v)
                RefreshTagPositions()
            end
        )
        page[prefix .. "TagOffsetXSlider"]:SetPoint("TOPLEFT", 0, NextY(0))
        NextY(60)

        page[prefix .. "TagOffsetYSlider"] = UI.CreateModernSlider(
            resourcesScrollChild,
            string.format(L["%s Offset Y"], label),
            -50, 50,
            CDM.db[offsetYKey] or 0,
            function(v)
                CDM.db[offsetYKey] = UI.RoundToInt(v)
                RefreshTagPositions()
            end
        )
        page[prefix .. "TagOffsetYSlider"]:SetPoint("TOPLEFT", 0, NextY(0))
        NextY(60)

        page[prefix .. "TagColorPicker"] = UI.CreateColorSwatch(resourcesScrollChild, string.format(L["%s Text Color"], label), colorKey, RESOURCES_REFRESH_SCOPES)
        page[prefix .. "TagColorPicker"].OnChange = RefreshTagStyle
        page[prefix .. "TagColorPicker"]:SetPoint("TOPLEFT", 0, NextY(0))
        NextY(50)
    end

    setControlsEnabled = UI.SetupModuleToggle(resourcesScrollChild, page.controls.resourcesEnabled)
    setControlsEnabled(enabled)
end

API:RegisterConfigTab("resources", L["Resources"], CreateResourcesTab, 10)

