local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L
local Shared = ns.GroupEditorShared or {}

local function OnResourcesSpecChanged()
    if not ns.ConfigFrame or not ns.ConfigFrame:IsShown() then return end
    C_Timer.After(0.3, function()
        if not ns.ConfigFrame or not ns.ConfigFrame:IsShown() then return end
        API:RebuildConfigFrame("resources")
    end)
end
API:RegisterSpecStateHandler(OnResourcesSpecChanged)

local CLASS_ORDER = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT",
    "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER",
}

local CLASS_DISPLAY_NAMES = {
    WARRIOR = L["Warrior"], PALADIN = L["Paladin"], HUNTER = L["Hunter"],
    ROGUE = L["Rogue"], PRIEST = L["Priest"], DEATHKNIGHT = L["Death Knight"],
    SHAMAN = L["Shaman"], MAGE = L["Mage"], WARLOCK = L["Warlock"],
    MONK = L["Monk"], DRUID = L["Druid"], DEMONHUNTER = L["Demon Hunter"],
    EVOKER = L["Evoker"],
}

local BAR_DISPLAY_NAMES = ns.BAR_DISPLAY_NAMES

local IsBarActiveForSpec = ns.IsBarActiveForSpec

local SECONDARY_COLOR_FIELDS = {
    Runes = { { key = "rechargingColor", label = L["Recharging"] } },
    Essence = { { key = "rechargingColor", label = L["Recharging"] } },
    SoulShards = { { key = "rechargingColor", label = L["Partial Fill"] } },
    ComboPoints = {
        ROGUE = {
            { key = "chargedColor", label = L["Charged"] },
            { key = "chargedEmptyColor", label = L["Charged Empty"] },
        },
        DRUID = {
            { key = "overflowingColor", label = L["Overflowing"] },
            { key = "overflowingEmptyColor", label = L["Overflowing Empty"] },
        },
    },
    Stagger = {
        { key = "lightColor", label = L["Light (<30%)"] },
        { key = "moderateColor", label = L["Moderate (30-60%)"] },
        { key = "heavyColor", label = L["Heavy (>60%)"] },
    },
}

local LEFT_INSET = Shared.LEFT_INSET or 35
local SCROLL_LEFT_PAD = Shared.SCROLL_LEFT_PAD or 54
local LEFT_WIDTH = 200
local RIGHT_X = 260
local ROW_HEIGHT = 24
local GROUP_HEADER_H = 28
local SLIDER_LABEL_W = 130
local SLIDER_W = 220

local function CreateBarColorPicker(parent, label, classKey, barKey, settingKey)
    local color = CDM:GetBarSettingForClass(classKey, barKey, settingKey) or { r = 1, g = 1, b = 1 }

    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(250, 22)

    local nameText = row:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    nameText:SetPoint("LEFT", 0, 0)
    nameText:SetText(label)

    local picker = UI.CreateSimpleColorPicker(row, color, function(r, g, b, a)
        CDM:SetBarSettingForClass(classKey, barKey, settingKey, { r = r, g = g, b = b, a = a or 1 })
        API:Refresh("RESOURCES")
    end, true)
    picker:SetPoint("LEFT", nameText, "RIGHT", 8, 0)

    row.picker = picker
    row.nameText = nameText
    return row
end


local function CreateResourcesTab(page, tabId)
    local _, playerClass = UnitClass("player")
    local currentSpecID = API:GetCurrentSpecID()

    local selectedClassKey = nil
    local selectedBarKey = nil
    local selectedGlobal = false
    local hasMana = false
    if currentSpecID then
        local manaLoad = CDM:GetBarSettingForClass("General", "Mana", "load")
        local loadSpec = manaLoad and manaLoad.spec
        if type(loadSpec) == "table" and loadSpec[currentSpecID] == true then
            hasMana = true
        end
    end
    local expandedGroups = { [playerClass] = true }
    if hasMana then expandedGroups.General = true end

    page.controls = page.controls or {}
    local enabled = CDM.db.resourcesEnabled ~= false
    page.controls.resourcesEnabled = UI.CreateModernCheckbox(
        page, L["Enable Resources"], enabled,
        function(checked)
            CDM.db.resourcesEnabled = checked
            API:Refresh("RESOURCES", "LAYOUT")
        end
    )
    page.controls.resourcesEnabled:SetPoint("TOPLEFT", 1, -40)

    local leftScroll = CreateFrame("ScrollFrame", nil, page, "ScrollFrameTemplate")
    leftScroll:SetPoint("TOPLEFT", LEFT_INSET - SCROLL_LEFT_PAD, -92)
    leftScroll:SetPoint("BOTTOMLEFT", LEFT_INSET - SCROLL_LEFT_PAD, 20)
    leftScroll:SetWidth(LEFT_WIDTH + SCROLL_LEFT_PAD)
    local leftChild = CreateFrame("Frame", nil, leftScroll)
    leftChild:SetSize(LEFT_WIDTH + SCROLL_LEFT_PAD, 1200)
    leftScroll:SetScrollChild(leftChild)

    local rightArea = CreateFrame("Frame", nil, page)
    rightArea:SetPoint("TOPLEFT", RIGHT_X, -12)
    rightArea:SetPoint("BOTTOMRIGHT", -10, 20)

    local subTabs = UI.CreateSubTabBar(rightArea, {
        { id = "display", label = L["Display"] },
        { id = "conditions", label = L["Conditions"] },
        { id = "load", label = L["Load"] },
    }, "display")

    local divider = rightArea:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    local dividerH = divider:GetHeight()
    divider:ClearAllPoints()
    divider:SetPoint("TOPLEFT", subTabs.barFrame, "BOTTOMLEFT", -30, 0)
    divider:SetPoint("TOPRIGHT", subTabs.barFrame, "BOTTOMRIGHT", 30, 0)
    divider:SetHeight(dividerH)

    for _, id in ipairs({ "display", "conditions", "load" }) do
        local pg = subTabs.subPages[id]
        pg:ClearAllPoints()
        pg:SetPoint("TOPLEFT", subTabs.barFrame, "BOTTOMLEFT", -30, -15)
        pg:SetPoint("BOTTOMRIGHT", rightArea, "BOTTOMRIGHT", 0, 0)
    end

    local displayPage = subTabs.subPages.display

    local rightPlaceholder = displayPage:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    rightPlaceholder:SetPoint("CENTER")
    rightPlaceholder:SetText(L["Select a resource bar to configure"])
    UI.SetTextMuted(rightPlaceholder)

    local rightManager = Shared.CreateRightPanelManager and Shared.CreateRightPanelManager(displayPage, rightPlaceholder, Shared.DestroyFrame)

    local condPage = subTabs.subPages.conditions
    local condPlaceholder = condPage:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    condPlaceholder:SetPoint("CENTER")
    condPlaceholder:SetText(L["Select a resource bar to configure"])
    UI.SetTextMuted(condPlaceholder)

    local condManager = Shared.CreateRightPanelManager and Shared.CreateRightPanelManager(condPage, condPlaceholder, Shared.DestroyFrame)

    local currentSubTab = "display"
    local origSelectTab = subTabs.selectTab
    subTabs.selectTab = function(id) currentSubTab = id; origSelectTab(id) end

    local loadPage = subTabs.subPages.load
    local loadPlaceholder = loadPage:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    loadPlaceholder:SetPoint("CENTER")
    loadPlaceholder:SetText(L["Select a resource bar to configure"])
    UI.SetTextMuted(loadPlaceholder)

    local loadManager = Shared.CreateRightPanelManager and Shared.CreateRightPanelManager(loadPage, loadPlaceholder, Shared.DestroyFrame)

    local HEADER_W = 198
    local BAR_ROW_INDENT = 14
    local BAR_ROW_WIDTH = HEADER_W - BAR_ROW_INDENT

    local barRowPool = Shared.CreateWidgetPool and Shared.CreateWidgetPool(
        function(parent)
            local row = CreateFrame("Button", nil, parent)
            row:SetSize(BAR_ROW_WIDTH, ROW_HEIGHT)

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetPoint("TOPLEFT", -BAR_ROW_INDENT, 0)
            bg:SetPoint("BOTTOMRIGHT", 0, 0)
            bg:Hide()
            row.bg = bg

            local nameText = row:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
            nameText:SetPoint("LEFT", 4, 0)
            row.nameText = nameText

            row.root = row
            return { root = row, bg = bg, nameText = nameText }
        end,
        function(widget)
            widget.root:Hide()
            widget.root:ClearAllPoints()
            widget.bg:Hide()
        end
    )

    local headerPool = Shared.CreateWidgetPool and Shared.CreateWidgetPool(
        function(parent)
            local header = Shared.CreateExpandableHeader(parent, 0, false, "", false)
            if header.deleteBtn then header.deleteBtn:Hide() end
            header.root = header.row
            return header
        end,
        function(widget)
            if widget.row then
                widget.row:Hide()
                widget.row:ClearAllPoints()
            end
        end
    )

    local function ShowBarSettings(classKey, barKey)
        selectedClassKey = classKey
        selectedBarKey = barKey
        if not rightManager then return end

        local _, rc = rightManager.CreateScrollContent(1200)
        if not rc then return end

        local yOff = -6
        local gold = CDM.CONST.GOLD

        local nameHeader = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font18")
        nameHeader:SetText(BAR_DISPLAY_NAMES[barKey] or barKey)
        nameHeader:SetTextColor(gold.r, gold.g, gold.b, 1)
        nameHeader:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 30

        local copyDropdown = CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate")
        copyDropdown:SetWidth(160)
        copyDropdown:SetPoint("TOPRIGHT", rc, "TOPRIGHT", 0, 0)
        copyDropdown:SetDefaultText(L["Copy settings from..."])

        copyDropdown:SetupMenu(function(_, rootDescription)
            local CLASS_BARS = CDM.CLASS_BARS
            if not CLASS_BARS then return end

            local function AddClassGroup(groupKey, groupLabel)
                local bars = CLASS_BARS[groupKey]
                if not bars or #bars == 0 then return end
                local anyAvailable = false
                for _, otherBarKey in ipairs(bars) do
                    if not (groupKey == classKey and otherBarKey == barKey) then
                        anyAvailable = true
                        break
                    end
                end
                if not anyAvailable then return end

                local color = RAID_CLASS_COLORS[groupKey]
                local displayLabel = color and color:WrapTextInColorCode(groupLabel) or groupLabel
                local submenu = rootDescription:CreateButton(displayLabel)
                for _, otherBarKey in ipairs(bars) do
                    if not (groupKey == classKey and otherBarKey == barKey) then
                        local label = BAR_DISPLAY_NAMES[otherBarKey] or otherBarKey
                        local sourceClassKey = groupKey
                        local sourceBarKey   = otherBarKey
                        submenu:CreateButton(label, function()
                            if CDM.CopyBarSettings then
                                CDM.CopyBarSettings(sourceClassKey, sourceBarKey, classKey, barKey)
                            end
                            ShowBarSettings(classKey, barKey)
                        end)
                    end
                end
            end

            AddClassGroup("General", L["General"])
            for _, orderedClassKey in ipairs(CLASS_ORDER) do
                AddClassGroup(orderedClassKey, CLASS_DISPLAY_NAMES[orderedClassKey] or orderedClassKey)
            end
        end)

        local heightSlider = UI.CreateModernSlider(rc, L["Height"], 4, 40,
            CDM:GetBarSettingForClass(classKey, barKey, "height") or 16,
            function(v)
                CDM:SetBarSettingForClass(classKey, barKey, "height", UI.RoundToInt(v))
                API:Refresh("RESOURCES", "LAYOUT")
            end, SLIDER_LABEL_W, SLIDER_W)
        heightSlider:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 60

        local widthSlider = UI.CreateModernSlider(rc, L["Width (0 = Auto)"], 0, 600,
            CDM:GetBarSettingForClass(classKey, barKey, "width") or 0,
            function(v)
                local value = UI.RoundToInt(v)
                if value > 0 and value < 60 then value = 60 end
                CDM:SetBarSettingForClass(classKey, barKey, "width", value)
                API:Refresh("RESOURCES")
            end, SLIDER_LABEL_W, SLIDER_W)
        widthSlider:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 60

        local colorHeader = UI.CreateHeader(rc, L["Colors"])
        colorHeader:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 25

        if barKey ~= "Stagger" then
            local colorPicker = CreateBarColorPicker(rc, L["Bar Color"], classKey, barKey, "color")
            colorPicker:SetPoint("TOPLEFT", 0, yOff)
            yOff = yOff - 28
        end

        local bgColorPicker = CreateBarColorPicker(rc, L["Background"], classKey, barKey, "bgColor")
        bgColorPicker:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 28

        local secondaries = SECONDARY_COLOR_FIELDS[barKey]
        if secondaries and not secondaries[1] then
            secondaries = secondaries[classKey]
        end
        if secondaries then
            for _, field in ipairs(secondaries) do
                local sp = CreateBarColorPicker(rc, field.label, classKey, barKey, field.key)
                sp:SetPoint("TOPLEFT", 0, yOff)
                yOff = yOff - 28
            end
        end
        yOff = yOff - 10

        local textureHeader = UI.CreateHeader(rc, L["Textures"])
        textureHeader:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 25

        local barTextureLabel = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
        barTextureLabel:SetText(L["Bar Texture:"])
        barTextureLabel:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 20

        local ddBarTexture = CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate")
        ddBarTexture:SetPoint("TOPLEFT", 0, yOff)
        ddBarTexture:SetWidth(200)
        ddBarTexture:SetDefaultText(CDM:GetBarSettingForClass(classKey, barKey, "barTexture") or "Solid")
        if rightManager and rightManager.RegisterDropdown then rightManager.RegisterDropdown(ddBarTexture) end
        UI.SetupMediaDropdown(ddBarTexture, "statusbar",
            function() return CDM:GetBarSettingForClass(classKey, barKey, "barTexture") end,
            function(name) CDM:SetBarSettingForClass(classKey, barKey, "barTexture", name); API:Refresh("RESOURCES") end,
            function(name) ddBarTexture:SetDefaultText(name) end)
        yOff = yOff - 50

        local bgTextureLabel = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
        bgTextureLabel:SetText(L["Background Texture:"])
        bgTextureLabel:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 20

        local ddBgTexture = CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate")
        ddBgTexture:SetPoint("TOPLEFT", 0, yOff)
        ddBgTexture:SetWidth(200)
        ddBgTexture:SetDefaultText(CDM:GetBarSettingForClass(classKey, barKey, "bgTexture") or "Solid")
        if rightManager and rightManager.RegisterDropdown then rightManager.RegisterDropdown(ddBgTexture) end
        UI.SetupMediaDropdown(ddBgTexture, "statusbar",
            function() return CDM:GetBarSettingForClass(classKey, barKey, "bgTexture") end,
            function(name) CDM:SetBarSettingForClass(classKey, barKey, "bgTexture", name); API:Refresh("RESOURCES") end,
            function(name) ddBgTexture:SetDefaultText(name) end)
        yOff = yOff - 60

        local SMOOTH_ELIGIBLE = {Mana=1,Rage=1,Energy=1,Focus=1,RunicPower=1,LunarPower=1,Maelstrom=1,Insanity=1,Fury=1}
        if SMOOTH_ELIGIBLE[barKey] then
            local smoothCB = UI.CreateModernCheckbox(rc, L["Smooth Fill"],
                CDM:GetBarSettingForClass(classKey, barKey, "smoothBars") ~= false,
                function(checked)
                    CDM:SetBarSettingForClass(classKey, barKey, "smoothBars", checked)
                    API:Refresh("RESOURCES")
                end)
            smoothCB:SetPoint("TOPLEFT", 0, yOff)
            yOff = yOff - 35
        end

        local posHeader = UI.CreateHeader(rc, L["Position"])
        posHeader:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 25

        local anchorToLabel = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
        anchorToLabel:SetText(L["Anchor To:"])
        anchorToLabel:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 20

        local generalBarSet = {}
        local generalBars = CDM.CLASS_BARS and CDM.CLASS_BARS["General"]
        if generalBars then
            for _, k in ipairs(generalBars) do generalBarSet[k] = true end
        end

        local function WouldCreateCycle(candidateKey)
            local visited = { [barKey] = true }
            local current = candidateKey
            while current do
                if visited[current] then return true end
                visited[current] = true
                local ck = generalBarSet[current] and "General" or classKey
                current = CDM:GetBarSettingForClass(ck, current, "anchorTo")
                if not current or current == "screen" or current == "essential"
                   or current == "playerFrame" then
                    return false
                end
            end
            return false
        end

        local anchorToOptions = {
            { value = "screen", label = L["Screen"] },
            { value = "playerFrame", label = L["Player Frame"] },
            { value = "essential", label = L["Essential Viewer"] },
        }
        local compatClassKey = classKey
        if classKey == "General" then
            local _, pc = UnitClass("player")
            compatClassKey = pc or classKey
        end

        local classBars = CDM.CLASS_BARS and CDM.CLASS_BARS[classKey]
        if classBars then
            for _, otherKey in ipairs(classBars) do
                if otherKey ~= barKey
                   and CDM.AreBarKeysSpecCompatible(compatClassKey, barKey, otherKey)
                   and not WouldCreateCycle(otherKey) then
                    anchorToOptions[#anchorToOptions + 1] = {
                        value = otherKey,
                        label = BAR_DISPLAY_NAMES[otherKey] or otherKey,
                    }
                end
            end
        end
        if classKey ~= "General" and generalBars then
            for _, otherKey in ipairs(generalBars) do
                if otherKey ~= barKey
                   and CDM.AreBarKeysSpecCompatible(compatClassKey, barKey, otherKey)
                   and not WouldCreateCycle(otherKey) then
                    anchorToOptions[#anchorToOptions + 1] = {
                        value = otherKey,
                        label = BAR_DISPLAY_NAMES[otherKey] or otherKey,
                    }
                end
            end
        end

        local currentAnchorTo = CDM:GetBarSettingForClass(classKey, barKey, "anchorTo") or "screen"

        local ddAnchorTo = CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate")
        ddAnchorTo:SetPoint("TOPLEFT", 0, yOff)
        ddAnchorTo:SetWidth(200)
        ddAnchorTo:SetDefaultText(UI.GetOptionLabel(anchorToOptions, currentAnchorTo, currentAnchorTo))
        if rightManager and rightManager.RegisterDropdown then rightManager.RegisterDropdown(ddAnchorTo) end
        UI.SetupValueDropdown(ddAnchorTo, anchorToOptions,
            function() return CDM:GetBarSettingForClass(classKey, barKey, "anchorTo") or "screen" end,
            function(value)
                CDM:SetBarSettingForClass(classKey, barKey, "anchorTo", value)
                API:Refresh("RESOURCES", "LAYOUT")
                ShowBarSettings(classKey, barKey)
            end)
        yOff = yOff - 50

        local isBarAnchor = currentAnchorTo ~= "screen" and currentAnchorTo ~= "playerFrame" and currentAnchorTo ~= "essential"

        if currentAnchorTo == "screen" then
            local offsetXSlider = UI.CreateModernSlider(rc, L["X Offset"], -600, 600,
                CDM:GetBarSettingForClass(classKey, barKey, "offsetX") or 0,
                function(v)
                    CDM:SetBarSettingForClass(classKey, barKey, "offsetX", UI.RoundToInt(v))
                    API:Refresh("RESOURCES")
                end, SLIDER_LABEL_W, SLIDER_W)
            offsetXSlider:SetPoint("TOPLEFT", 0, yOff)
            yOff = yOff - 60

            local offsetYSlider = UI.CreateModernSlider(rc, L["Y Offset"], -600, 600,
                CDM:GetBarSettingForClass(classKey, barKey, "offsetY") or -200,
                function(v)
                    CDM:SetBarSettingForClass(classKey, barKey, "offsetY", UI.RoundToInt(v))
                    API:Refresh("RESOURCES")
                end, SLIDER_LABEL_W, SLIDER_W)
            offsetYSlider:SetPoint("TOPLEFT", 0, yOff)
            yOff = yOff - 60

        elseif isBarAnchor then
            local spacingSlider = UI.CreateModernSlider(rc, L["Bar Spacing"], -50, 50,
                CDM:GetBarSettingForClass(classKey, barKey, "barSpacing") or 1,
                function(v)
                    CDM:SetBarSettingForClass(classKey, barKey, "barSpacing", UI.RoundToInt(v))
                    API:Refresh("RESOURCES")
                end, SLIDER_LABEL_W, SLIDER_W)
            spacingSlider:SetPoint("TOPLEFT", 0, yOff)
            yOff = yOff - 60

            local stackDirLabel = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
            stackDirLabel:SetText(L["Stack Direction:"])
            stackDirLabel:SetPoint("TOPLEFT", 0, yOff)
            yOff = yOff - 20

            local stackOptions = {
                { value = "below", label = L["Below"] },
                { value = "above", label = L["Above"] },
                { value = "right", label = L["Right of"] },
                { value = "left", label = L["Left of"] },
            }
            local aP = CDM:GetBarSettingForClass(classKey, barKey, "anchorPoint") or "TOP"
            local tP = CDM:GetBarSettingForClass(classKey, barKey, "anchorTargetPoint") or "BOTTOM"
            local currentDir = "below"
            if aP == "BOTTOM" and tP == "TOP" then currentDir = "above"
            elseif aP == "LEFT" and tP == "RIGHT" then currentDir = "right"
            elseif aP == "RIGHT" and tP == "LEFT" then currentDir = "left"
            end

            local ddStackDir = CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate")
            ddStackDir:SetPoint("TOPLEFT", 0, yOff)
            ddStackDir:SetWidth(150)
            for _, opt in ipairs(stackOptions) do
                if opt.value == currentDir then ddStackDir:SetDefaultText(opt.label) break end
            end
            if rightManager and rightManager.RegisterDropdown then rightManager.RegisterDropdown(ddStackDir) end
            UI.SetupValueDropdown(ddStackDir, stackOptions,
                function() return currentDir end,
                function(value)
                    local newAP, newTP
                    if value == "below" then newAP, newTP = "TOP", "BOTTOM"
                    elseif value == "above" then newAP, newTP = "BOTTOM", "TOP"
                    elseif value == "right" then newAP, newTP = "LEFT", "RIGHT"
                    elseif value == "left" then newAP, newTP = "RIGHT", "LEFT"
                    end
                    CDM:SetBarSettingForClass(classKey, barKey, "anchorPoint", newAP)
                    CDM:SetBarSettingForClass(classKey, barKey, "anchorTargetPoint", newTP)
                    API:Refresh("RESOURCES")
                    ShowBarSettings(classKey, barKey)
                end)
            yOff = yOff - 50

        else
            local anchorPts = {
                { value = "TOPLEFT", label = "TOPLEFT" }, { value = "TOP", label = "TOP" },
                { value = "TOPRIGHT", label = "TOPRIGHT" }, { value = "LEFT", label = "LEFT" },
                { value = "CENTER", label = "CENTER" }, { value = "RIGHT", label = "RIGHT" },
                { value = "BOTTOMLEFT", label = "BOTTOMLEFT" }, { value = "BOTTOM", label = "BOTTOM" },
                { value = "BOTTOMRIGHT", label = "BOTTOMRIGHT" },
            }

            local apLabel = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
            apLabel:SetText(L["Bar Anchor Point:"])
            apLabel:SetPoint("TOPLEFT", 0, yOff)
            yOff = yOff - 20

            local ddAP = CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate")
            ddAP:SetPoint("TOPLEFT", 0, yOff)
            ddAP:SetWidth(150)
            ddAP:SetDefaultText(CDM:GetBarSettingForClass(classKey, barKey, "anchorPoint") or "BOTTOM")
            if rightManager and rightManager.RegisterDropdown then rightManager.RegisterDropdown(ddAP) end
            UI.SetupValueDropdown(ddAP, anchorPts,
                function() return CDM:GetBarSettingForClass(classKey, barKey, "anchorPoint") or "BOTTOM" end,
                function(value)
                    CDM:SetBarSettingForClass(classKey, barKey, "anchorPoint", value)
                    ddAP:SetDefaultText(value)
                    API:Refresh("RESOURCES")
                end)
            yOff = yOff - 50

            local rpLabel = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
            rpLabel:SetText(L["Target Point:"])
            rpLabel:SetPoint("TOPLEFT", 0, yOff)
            yOff = yOff - 20

            local ddTP = CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate")
            ddTP:SetPoint("TOPLEFT", 0, yOff)
            ddTP:SetWidth(150)
            ddTP:SetDefaultText(CDM:GetBarSettingForClass(classKey, barKey, "anchorTargetPoint") or "TOP")
            if rightManager and rightManager.RegisterDropdown then rightManager.RegisterDropdown(ddTP) end
            UI.SetupValueDropdown(ddTP, anchorPts,
                function() return CDM:GetBarSettingForClass(classKey, barKey, "anchorTargetPoint") or "TOP" end,
                function(value)
                    CDM:SetBarSettingForClass(classKey, barKey, "anchorTargetPoint", value)
                    ddTP:SetDefaultText(value)
                    API:Refresh("RESOURCES")
                end)
            yOff = yOff - 50

            local offsetXSlider = UI.CreateModernSlider(rc, L["X Offset"], -600, 600,
                CDM:GetBarSettingForClass(classKey, barKey, "offsetX") or 0,
                function(v)
                    CDM:SetBarSettingForClass(classKey, barKey, "offsetX", UI.RoundToInt(v))
                    API:Refresh("RESOURCES")
                end, SLIDER_LABEL_W, SLIDER_W)
            offsetXSlider:SetPoint("TOPLEFT", 0, yOff)
            yOff = yOff - 60

            local offsetYSlider = UI.CreateModernSlider(rc, L["Y Offset"], -600, 600,
                CDM:GetBarSettingForClass(classKey, barKey, "offsetY") or 0,
                function(v)
                    CDM:SetBarSettingForClass(classKey, barKey, "offsetY", UI.RoundToInt(v))
                    API:Refresh("RESOURCES")
                end, SLIDER_LABEL_W, SLIDER_W)
            offsetYSlider:SetPoint("TOPLEFT", 0, yOff)
            yOff = yOff - 60
        end

        local tagHeader = UI.CreateHeader(rc, L["Tag (Value Text)"])
        tagHeader:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 30

        local tagEnabledCB = UI.CreateModernCheckbox(rc, L["Enable Tag"],
            CDM:GetBarSettingForClass(classKey, barKey, "tagEnabled") ~= false,
            function(checked)
                CDM:SetBarSettingForClass(classKey, barKey, "tagEnabled", checked)
                API:Refresh("RESOURCES")
            end)
        tagEnabledCB:SetPoint("TOPLEFT", 0, yOff)

        if barKey == "TipOfTheSpear" then
            local tosTimeCB = UI.CreateModernCheckbox(rc, L["Show aura time"],
                CDM:GetBarSettingForClass(classKey, barKey, "tagShowAuraTime") == true,
                function(checked)
                    CDM:SetBarSettingForClass(classKey, barKey, "tagShowAuraTime", checked)
                    API:Refresh("RESOURCES")
                end)
            tosTimeCB:SetPoint("LEFT", tagEnabledCB, "LEFT", 150, 0)
        end

        yOff = yOff - 35

        local tagFontSlider = UI.CreateModernSlider(rc, L["Font Size"], 8, 32,
            CDM:GetBarSettingForClass(classKey, barKey, "tagFontSize") or 15,
            function(v)
                CDM:SetBarSettingForClass(classKey, barKey, "tagFontSize", UI.RoundToInt(v))
                API:Refresh("RESOURCES")
            end, SLIDER_LABEL_W, SLIDER_W)
        tagFontSlider:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 60

        local tagAnchorOptions = {
            { value = "LEFT", label = L["Left"] },
            { value = "CENTER", label = L["Center"] },
            { value = "RIGHT", label = L["Right"] },
        }
        local tagAnchorLabel = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
        tagAnchorLabel:SetText(L["Tag Anchor:"])
        tagAnchorLabel:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 20

        local ddTagAnchor = CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate")
        ddTagAnchor:SetPoint("TOPLEFT", 0, yOff)
        ddTagAnchor:SetWidth(150)
        ddTagAnchor:SetDefaultText(CDM:GetBarSettingForClass(classKey, barKey, "tagAnchor") or "CENTER")
        if rightManager and rightManager.RegisterDropdown then rightManager.RegisterDropdown(ddTagAnchor) end
        UI.SetupValueDropdown(ddTagAnchor, tagAnchorOptions,
            function() return CDM:GetBarSettingForClass(classKey, barKey, "tagAnchor") end,
            function(value)
                CDM:SetBarSettingForClass(classKey, barKey, "tagAnchor", value)
                ddTagAnchor:SetDefaultText(value)
                API:Refresh("RESOURCES")
            end)
        yOff = yOff - 60

        local tagColorPicker = CreateBarColorPicker(rc, L["Tag Color"], classKey, barKey, "tagColor")
        tagColorPicker:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 28

        local tagXSlider = UI.CreateModernSlider(rc, L["Tag X Offset"], -200, 200,
            CDM:GetBarSettingForClass(classKey, barKey, "tagOffsetX") or 0,
            function(v)
                CDM:SetBarSettingForClass(classKey, barKey, "tagOffsetX", UI.RoundToInt(v))
                API:Refresh("RESOURCES")
            end, SLIDER_LABEL_W, SLIDER_W)
        tagXSlider:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 60

        local tagYSlider = UI.CreateModernSlider(rc, L["Tag Y Offset"], -50, 50,
            CDM:GetBarSettingForClass(classKey, barKey, "tagOffsetY") or 0,
            function(v)
                CDM:SetBarSettingForClass(classKey, barKey, "tagOffsetY", UI.RoundToInt(v))
                API:Refresh("RESOURCES")
            end, SLIDER_LABEL_W, SLIDER_W)
        tagYSlider:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 40

        if barKey == "Mana" then
            local pctCB = UI.CreateModernCheckbox(rc, L["Display as %"],
                CDM:GetBarSettingForClass(classKey, barKey, "displayAsPercent") == true,
                function(checked)
                    CDM:SetBarSettingForClass(classKey, barKey, "displayAsPercent", checked)
                    API:Refresh("RESOURCES")
                end)
            pctCB:SetPoint("TOPLEFT", 0, yOff)
            yOff = yOff - 35
        end

        if barKey == "IgnorePain" then
            local hideIconCB = UI.CreateModernCheckbox(rc, L["Hide Icon"],
                CDM:GetBarSettingForClass(classKey, barKey, "hideIcon") == true,
                function(checked)
                    CDM:SetBarSettingForClass(classKey, barKey, "hideIcon", checked)
                    API:Refresh("RESOURCES")
                end)
            hideIconCB:SetPoint("TOPLEFT", 0, yOff)
            yOff = yOff - 35
        end

        rc:SetHeight(math.abs(yOff) + 20)
    end

    local BuildLeftPanel

    local globalRow
    do
        local row = CreateFrame("Button", nil, leftChild)
        row:SetSize(BAR_ROW_WIDTH, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", SCROLL_LEFT_PAD + BAR_ROW_INDENT, -4)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetPoint("TOPLEFT", -BAR_ROW_INDENT, 0)
        bg:SetPoint("BOTTOMRIGHT", 0, 0)
        bg:Hide()

        local nameText = row:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
        nameText:SetPoint("LEFT", 4, 0)
        nameText:SetText(L["Global"])

        row.bg = bg
        row.nameText = nameText
        globalRow = row
    end

    local function ShowGlobalSettings()
        if not rightManager then return end
        local _, rc = rightManager.CreateScrollContent(400)
        if not rc then return end

        local gold = CDM.CONST.GOLD
        local nameHeader = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font18")
        nameHeader:SetText(L["Global"])
        nameHeader:SetTextColor(gold.r, gold.g, gold.b, 1)
        nameHeader:SetPoint("TOPLEFT", 0, 0)

        local yOff = -40

        local cbUnified = UI.CreateModernCheckbox(rc, L["Wrap bars and display textured separators"],
            CDM.db.unifiedBorder == true,
            function(checked)
                CDM.db.unifiedBorder = checked and true or nil
                API:Refresh("RESOURCES", "LAYOUT")
            end)
        cbUnified:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 35

        local cbMoveBuffs = UI.CreateModernCheckbox(rc, L["Anchor buff icons to resources"],
            CDM.db.moveBuffsDown == true,
            function(checked)
                CDM.db.moveBuffsDown = checked and true or nil
                API:Refresh("RESOURCES", "LAYOUT")
            end)
        cbMoveBuffs:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 45

        local offsetSlider = UI.CreateModernSlider(rc, L["Y Offset"], -300, 300,
            tonumber(CDM.db.moveBuffsDownOffset) or 0,
            function(v)
                CDM.db.moveBuffsDownOffset = UI.RoundToInt(v)
                API:Refresh("RESOURCES", "LAYOUT")
            end, SLIDER_LABEL_W, SLIDER_W)
        offsetSlider:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 50

        local fallbackOptions = {
            { value = "essential",    label = L["Essential"] },
            { value = "lastResource", label = L["Last resource"] },
            { value = "saved",        label = L["Buff viewer X/Y"] },
        }

        local fallbackLabel = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
        fallbackLabel:SetText(L["Fallback when no resources"])
        fallbackLabel:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 20

        local ddFallback = CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate")
        ddFallback:SetPoint("TOPLEFT", 0, yOff)
        ddFallback:SetWidth(200)
        local currentFallback = CDM.db.moveBuffsDownFallback or "lastResource"
        ddFallback:SetDefaultText(UI.GetOptionLabel(fallbackOptions, currentFallback, currentFallback))
        if rightManager and rightManager.RegisterDropdown then rightManager.RegisterDropdown(ddFallback) end
        UI.SetupValueDropdown(ddFallback, fallbackOptions,
            function() return CDM.db.moveBuffsDownFallback or "lastResource" end,
            function(value, label)
                CDM.db.moveBuffsDownFallback = value
                ddFallback:SetDefaultText(label)
                API:Refresh("RESOURCES", "LAYOUT")
            end)
        yOff = yOff - 50

        local comingSoon = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
        comingSoon:SetText(L["More options coming soon..."])
        comingSoon:SetPoint("TOPLEFT", 0, yOff)
        UI.SetTextMuted(comingSoon)
        yOff = yOff - 30

        rc:SetHeight(math.abs(yOff) + 20)
    end

    local function SetSubTabButton(id, shown)
        local btn = subTabs.tabButtons and subTabs.tabButtons[id]
        if not btn then return end
        if shown then btn:Show() else btn:Hide() end
    end

    local function ToggleGroupExpand(groupKey)
        expandedGroups[groupKey] = not expandedGroups[groupKey]
        BuildLeftPanel()
    end

    local function SelectGlobal()
        selectedGlobal = true
        selectedClassKey = nil
        selectedBarKey = nil
        ShowGlobalSettings()
        if condManager and condManager.Clear then condManager.Clear() end
        if loadManager and loadManager.Clear then loadManager.Clear() end
        SetSubTabButton("conditions", false)
        SetSubTabButton("load", false)
        if currentSubTab ~= "display" then subTabs.selectTab("display") end
        BuildLeftPanel()
    end

    local function SelectBar(classKey, barKey)
        selectedGlobal = false
        selectedClassKey = classKey
        selectedBarKey = barKey
        ShowBarSettings(classKey, barKey)
        local condUI = ns.ResourceConditionsUI
        if condUI and condUI.ShowBarConditions then
            condUI.ShowBarConditions(condPage, condManager, classKey, barKey)
        end
        local loadUI = ns.ResourceLoadUI
        if loadUI and loadUI.ShowBarLoad then
            loadUI.ShowBarLoad(loadPage, loadManager, classKey, barKey)
        end
        SetSubTabButton("load", true)
        local condBtn = subTabs.tabButtons and subTabs.tabButtons["conditions"]
        if condBtn then
            if barKey == "Stagger" or barKey == "Ironfur" or barKey == "IgnorePain" then
                condBtn:Hide()
                if currentSubTab == "conditions" then subTabs.selectTab("display") end
            else
                condBtn:Show()
            end
        end
        BuildLeftPanel()
    end

    globalRow:SetScript("OnClick", SelectGlobal)
    globalRow:SetScript("OnEnter", function()
        if not selectedGlobal then
            globalRow.bg:SetAtlas("Options_List_Hover")
            globalRow.bg:Show()
        end
    end)
    globalRow:SetScript("OnLeave", function()
        if not selectedGlobal then
            globalRow.bg:Hide()
        end
    end)

    BuildLeftPanel = function()
        if barRowPool then barRowPool:ReleaseAll() end
        if headerPool then headerPool:ReleaseAll() end

        if selectedGlobal then
            globalRow.bg:SetAtlas("Options_List_Active")
            globalRow.bg:Show()
            UI.SetTextWhite(globalRow.nameText)
        else
            globalRow.bg:Hide()
            UI.SetTextSubtle(globalRow.nameText)
        end

        local yOff = -ROW_HEIGHT - 10
        local CLASS_BARS = CDM.CLASS_BARS
        if not CLASS_BARS then return end

        local groups = { { key = "General", label = L["General"] } }
        for _, classKey in ipairs(CLASS_ORDER) do
            groups[#groups + 1] = { key = classKey, label = CLASS_DISPLAY_NAMES[classKey] or classKey }
        end

        for _, group in ipairs(groups) do
            local groupKey = group.key
            local bars = CLASS_BARS[groupKey]
            if bars and #bars > 0 then
                local isExpanded = expandedGroups[groupKey]

                if headerPool then
                    local h = headerPool:Acquire(leftChild)
                    Shared.ConfigureExpandableHeader(h, yOff, isExpanded, group.label, false)
                    h.row:SetSize(HEADER_W, GROUP_HEADER_H)
                    if h.deleteBtn then h.deleteBtn:Hide() end
                    if h.selectBtn then
                        h.selectBtn:SetScript("OnClick", function()
                            ToggleGroupExpand(groupKey)
                        end)
                    end
                    if h.expandBtn then
                        h.expandBtn:SetScript("OnClick", function()
                            ToggleGroupExpand(groupKey)
                        end)
                    end
                end

                yOff = yOff - GROUP_HEADER_H

                if isExpanded and barRowPool then
                    for _, barKey in ipairs(bars) do
                        local widget = barRowPool:Acquire(leftChild)
                        local row = widget.root
                        row:SetPoint("TOPLEFT", SCROLL_LEFT_PAD + BAR_ROW_INDENT, yOff)

                        widget.nameText:SetText(BAR_DISPLAY_NAMES[barKey] or barKey)

                        local isSelected = (selectedClassKey == groupKey and selectedBarKey == barKey)
                        local isActive = IsBarActiveForSpec(barKey, currentSpecID)

                        if isSelected then
                            widget.bg:SetAtlas("Options_List_Active")
                            widget.bg:Show()
                            UI.SetTextWhite(widget.nameText)
                        else
                            widget.bg:Hide()
                            if isActive then
                                UI.SetTextSubtle(widget.nameText)
                            else
                                UI.SetTextMuted(widget.nameText)
                            end
                        end

                        row:SetScript("OnClick", function() SelectBar(groupKey, barKey) end)
                        row:SetScript("OnEnter", function()
                            if not isSelected then
                                widget.bg:SetAtlas("Options_List_Hover")
                                widget.bg:Show()
                            end
                        end)
                        row:SetScript("OnLeave", function()
                            if not (selectedClassKey == groupKey and selectedBarKey == barKey) then
                                widget.bg:Hide()
                            end
                        end)

                        yOff = yOff - ROW_HEIGHT
                    end
                end
            end
        end

        leftChild:SetHeight(math.abs(yOff) + 10)
    end

    BuildLeftPanel()
end

API:RegisterConfigTab("resources", L["Resources"], CreateResourcesTab, 10)
