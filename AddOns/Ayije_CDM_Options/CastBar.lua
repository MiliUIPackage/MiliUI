local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L


local OVERRIDE_POINT_OPTIONS = {
    { value = "TOPLEFT",     label = L["Top Left"] },
    { value = "TOP",         label = L["Top"] },
    { value = "TOPRIGHT",    label = L["Top Right"] },
    { value = "LEFT",        label = L["Left"] },
    { value = "CENTER",      label = L["Center"] },
    { value = "RIGHT",       label = L["Right"] },
    { value = "BOTTOMLEFT",  label = L["Bottom Left"] },
    { value = "BOTTOM",      label = L["Bottom"] },
    { value = "BOTTOMRIGHT", label = L["Bottom Right"] },
}

local OVERRIDE_ANCHOR_OPTIONS = {
    { value = "screen",      label = L["Screen"] },
    { value = "playerFrame", label = L["Player Frame"] },
    { value = "essential",   label = L["Essential Viewer"] },
    { value = "utility",     label = L["Utility Viewer"] },
    { value = "resources",   label = L["Resources"] },
}

local function GetOptionLabel(options, value)
    for _, opt in ipairs(options) do
        if opt.value == value then return opt.label end
    end
    return value or ""
end

local function GetRowLabel(key)
    local Shared = ns.GroupEditorShared
    local prefix, rest = key:match("^(%w+):(.+)$")
    if prefix == "role" then
        if rest == "DPS" then return L["DPS"] end
        if rest == "TANK" then return L["Tank"] end
        if rest == "HEALER" then return L["Healer"] end
        return rest
    elseif prefix == "class" then
        local CLASS_LIST = Shared.GetClassCatalog()
        for _, classInfo in ipairs(CLASS_LIST) do
            if classInfo.classTag == rest then return classInfo.className end
        end
        return rest
    elseif prefix == "spec" then
        local specID = tonumber(rest)
        if specID then
            local _, specName, _, _, _, classFile = GetSpecializationInfoByID(specID)
            local CLASS_LIST = Shared.GetClassCatalog()
            for _, classInfo in ipairs(CLASS_LIST) do
                if classInfo.classTag == classFile and specName then
                    return classInfo.className .. " - " .. specName
                end
            end
            return specName or rest
        end
    end
    return key
end

local function CategoryRank(key)
    if key:sub(1, 5) == "role:" then return 1 end
    if key:sub(1, 6) == "class:" then return 2 end
    return 3
end

local function SortOverrideKeys(overrides)
    local keys = {}
    for k in pairs(overrides) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        local ra, rb = CategoryRank(a), CategoryRank(b)
        if ra ~= rb then return ra < rb end
        return GetRowLabel(a) < GetRowLabel(b)
    end)
    return keys
end

local function CreateOverrideRow(parent)
    local Shared = ns.GroupEditorShared
    local widget = {}

    local row = CreateFrame("Frame", nil, parent)
    widget.root = row

    local enabledWrap = UI.CreateModernCheckbox(row, "", false, function(checked)
        if widget.enabledCallback then widget.enabledCallback(checked) end
    end)
    enabledWrap:SetPoint("TOPLEFT", 4, -4)
    widget.enabledWrap = enabledWrap

    local label = row:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
    label:SetPoint("LEFT", enabledWrap.checkbox, "RIGHT", 8, 0)
    label:SetPoint("RIGHT", row, "RIGHT", -32, 0)
    label:SetJustifyH("LEFT")
    widget.label = label

    local deleteBtn = CreateFrame("Button", nil, row)
    deleteBtn:SetSize(20, 20)
    deleteBtn:SetPoint("TOPRIGHT", -4, -8)
    Shared.ApplyRemoveButtonText(deleteBtn)
    widget.deleteBtn = deleteBtn

    local fieldsFrame = CreateFrame("Frame", nil, row)
    fieldsFrame:SetPoint("TOPLEFT", enabledWrap.checkbox, "BOTTOMLEFT", 16, -6)
    fieldsFrame:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    widget.fieldsFrame = fieldsFrame

    local function MakeFieldRow(yOff, labelText, callbackKey)
        local wrap = UI.CreateModernCheckbox(fieldsFrame, "", false, function(checked)
            local cb = widget[callbackKey]
            if cb then cb(checked) end
        end)
        wrap:SetPoint("TOPLEFT", 0, yOff)

        local lbl = fieldsFrame:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        lbl:SetText(labelText)
        lbl:SetPoint("LEFT", wrap.checkbox, "RIGHT", 8, 0)
        lbl:SetWidth(110)
        lbl:SetJustifyH("LEFT")

        return wrap, lbl
    end

    local rowH = 32
    local y = -10

    local offsetYWrap, offsetYLbl = MakeFieldRow(y, L["Y Offset"], "offsetYCheckCallback")
    local offsetYSlider = UI.CreateModernSlider(fieldsFrame, "", -600, 600, -166, function(v)
        if widget.offsetYCallback then widget.offsetYCallback(v) end
    end, 0, 160)
    offsetYSlider:SetPoint("LEFT", offsetYLbl, "RIGHT", 4, 0)
    widget.offsetYWrap = offsetYWrap
    widget.offsetYSlider = offsetYSlider
    y = y - 40

    local anchorWrap, anchorLbl = MakeFieldRow(y, L["Anchor To:"], "anchorCallback")
    local anchorDD = CreateFrame("DropdownButton", nil, fieldsFrame, "WowStyle1DropdownTemplate")
    anchorDD:SetWidth(160)
    anchorDD:SetPoint("LEFT", anchorLbl, "RIGHT", 8, 0)
    widget.anchorWrap = anchorWrap
    widget.anchorDD = anchorDD
    y = y - rowH

    local anchorPointWrap, anchorPointLbl = MakeFieldRow(y, L["Anchor Point:"], "anchorPointCallback")
    local anchorPointDD = CreateFrame("DropdownButton", nil, fieldsFrame, "WowStyle1DropdownTemplate")
    anchorPointDD:SetWidth(160)
    anchorPointDD:SetPoint("LEFT", anchorPointLbl, "RIGHT", 8, 0)
    widget.anchorPointWrap = anchorPointWrap
    widget.anchorPointDD = anchorPointDD
    y = y - rowH

    local targetPointWrap, targetPointLbl = MakeFieldRow(y, L["Target Point:"], "targetPointCallback")
    local targetPointDD = CreateFrame("DropdownButton", nil, fieldsFrame, "WowStyle1DropdownTemplate")
    targetPointDD:SetWidth(160)
    targetPointDD:SetPoint("LEFT", targetPointLbl, "RIGHT", 8, 0)
    widget.targetPointWrap = targetPointWrap
    widget.targetPointDD = targetPointDD
    y = y - rowH

    fieldsFrame:SetHeight(math.max(1, -y + 4))

    local headerH = 32
    local fieldsH = -y + 4
    widget.rowHeight = headerH + 6 + fieldsH + 8
    row:SetSize(540, widget.rowHeight)

    return widget
end

local function BuildAnchoringPage(parent)
    local Shared = ns.GroupEditorShared

    local scrollChild, scrollFrame = UI.CreateScrollableTab(parent, "AyijeCDM_CastBarAnchoringScrollFrame", 1400, 460)
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -10, 20)
    scrollChild:ClearAllPoints()
    scrollChild:SetPoint("TOPLEFT", 35, -5)
    scrollChild:SetPoint("TOPRIGHT", -25, -5)
    local realScrollChild = scrollFrame:GetScrollChild()

    local function BuildAnchorOptions()
        local resourcesEnabled = CDM.db.resourcesEnabled ~= false
        local opts = {
            { value = "screen",      label = L["Screen"] },
            { value = "playerFrame", label = L["Player Frame"] },
            { value = "essential",   label = L["Essential Viewer"] },
            { value = "utility",     label = L["Utility Viewer"] },
        }
        if resourcesEnabled then
            opts[#opts + 1] = { value = "resources", label = L["Resources"] }
        end
        return opts
    end

    local function GetAnchorLabelDynamic(value)
        for _, opt in ipairs(BuildAnchorOptions()) do
            if opt.value == value then return opt.label end
        end
        return value or ""
    end

    local function GetPointLabel(value)
        return GetOptionLabel(OVERRIDE_POINT_OPTIONS, value)
    end

    local posHeader = UI.CreateHeader(scrollChild, L["Position"])
    posHeader:SetPoint("TOPLEFT", 0, 0)

    local anchorLabel = scrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    anchorLabel:SetText(L["Anchor To:"])
    anchorLabel:SetPoint("TOPLEFT", posHeader, "BOTTOMLEFT", 0, -15)

    local ddAnchor = CreateFrame("DropdownButton", nil, scrollChild, "WowStyle1DropdownTemplate")
    ddAnchor:SetPoint("TOPLEFT", anchorLabel, "BOTTOMLEFT", 0, -5)
    ddAnchor:SetWidth(200)
    ddAnchor:SetDefaultText(GetAnchorLabelDynamic(CDM.db.castBarAnchor or "resources"))
    UI.SetupValueDropdown(
        ddAnchor,
        BuildAnchorOptions,
        function() return CDM.db.castBarAnchor or "resources" end,
        function(value)
            CDM.db.castBarAnchor = value
            ddAnchor:SetDefaultText(GetAnchorLabelDynamic(value))
            API:Refresh("STYLE")
        end
    )

    local anchorPointLabel = scrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    anchorPointLabel:SetText(L["Anchor Point:"])
    anchorPointLabel:SetPoint("TOPLEFT", ddAnchor, "BOTTOMLEFT", 0, -10)

    local ddAnchorPoint = CreateFrame("DropdownButton", nil, scrollChild, "WowStyle1DropdownTemplate")
    ddAnchorPoint:SetPoint("TOPLEFT", anchorPointLabel, "BOTTOMLEFT", 0, -5)
    ddAnchorPoint:SetWidth(200)
    ddAnchorPoint:SetDefaultText(GetPointLabel(CDM.db.castBarAnchorPoint or "BOTTOM"))
    UI.SetupValueDropdown(
        ddAnchorPoint,
        OVERRIDE_POINT_OPTIONS,
        function() return CDM.db.castBarAnchorPoint or "BOTTOM" end,
        function(value)
            CDM.db.castBarAnchorPoint = value
            ddAnchorPoint:SetDefaultText(GetPointLabel(value))
            API:Refresh("STYLE")
        end
    )

    local targetPointLabel = scrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    targetPointLabel:SetText(L["Target Point:"])
    targetPointLabel:SetPoint("TOPLEFT", ddAnchorPoint, "BOTTOMLEFT", 0, -10)

    local ddTargetPoint = CreateFrame("DropdownButton", nil, scrollChild, "WowStyle1DropdownTemplate")
    ddTargetPoint:SetPoint("TOPLEFT", targetPointLabel, "BOTTOMLEFT", 0, -5)
    ddTargetPoint:SetWidth(200)
    ddTargetPoint:SetDefaultText(GetPointLabel(CDM.db.castBarTargetPoint or "TOP"))
    UI.SetupValueDropdown(
        ddTargetPoint,
        OVERRIDE_POINT_OPTIONS,
        function() return CDM.db.castBarTargetPoint or "TOP" end,
        function(value)
            CDM.db.castBarTargetPoint = value
            ddTargetPoint:SetDefaultText(GetPointLabel(value))
            API:Refresh("STYLE")
        end
    )

    local offsetXSlider = UI.CreateModernSlider(
        scrollChild,
        L["X Offset"],
        -800, 800,
        CDM.db.castBarOffsetX or 0,
        function(v)
            CDM.db.castBarOffsetX = UI.RoundToInt(v)
            API:Refresh("STYLE")
        end
    )
    offsetXSlider:SetPoint("TOPLEFT", ddTargetPoint, "BOTTOMLEFT", 0, -15)

    local offsetYSlider = UI.CreateModernSlider(
        scrollChild,
        L["Y Offset"],
        -600, 600,
        CDM.db.castBarOffsetY or -166,
        function(v)
            CDM.db.castBarOffsetY = UI.RoundToInt(v)
            API:Refresh("STYLE")
        end
    )
    offsetYSlider:SetPoint("TOPLEFT", offsetXSlider, "BOTTOMLEFT", 0, -10)

    local gateCB = UI.CreateModernCheckbox(
        scrollChild,
        L["Enable Overrides"],
        CDM.db.castBarOverridesEnabled == true,
        function(checked)
            CDM.db.castBarOverridesEnabled = checked and true or false
            API:Refresh("STYLE")
        end
    )
    gateCB:SetPoint("TOPLEFT", offsetYSlider, "BOTTOMLEFT", 0, -25)

    local overrideArea = CreateFrame("Frame", nil, scrollChild)
    overrideArea:SetPoint("TOPLEFT", gateCB, "BOTTOMLEFT", 0, -10)
    overrideArea:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)
    overrideArea:SetHeight(1)

    local addLabel = overrideArea:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    addLabel:SetText(L["Add Override"])
    addLabel:SetPoint("TOPLEFT", 0, 0)

    local addDD = CreateFrame("DropdownButton", nil, overrideArea, "WowStyle1DropdownTemplate")
    addDD:SetPoint("TOPLEFT", addLabel, "BOTTOMLEFT", 0, -5)
    addDD:SetWidth(220)
    addDD:SetDefaultText(L["Add Override"])

    local listContainer = CreateFrame("Frame", nil, overrideArea)
    listContainer:SetPoint("TOPLEFT", addDD, "BOTTOMLEFT", 0, -20)
    listContainer:SetPoint("RIGHT", overrideArea, "RIGHT", 0, 0)
    listContainer:SetHeight(1)

    local function UpdateScrollHeight()
        C_Timer.After(0, function()
            local top = posHeader:GetTop()
            local lastWidget = overrideArea:IsShown() and overrideArea or gateCB
            local bottom = lastWidget:GetBottom()
            if top and bottom then
                local h = top - bottom + 40
                scrollChild:SetHeight(h)
                realScrollChild:SetHeight(h)
            end
        end)
    end

    local function SetOverrideAreaShown(shown)
        overrideArea:SetShown(shown)
        UpdateScrollHeight()
    end
    SetOverrideAreaShown(CDM.db.castBarOverridesEnabled == true)

    gateCB.checkbox:HookScript("OnClick", function(self)
        SetOverrideAreaShown(self:GetChecked() and true or false)
    end)

    local rowPool = Shared.CreateWidgetPool(
        function(p) return CreateOverrideRow(p) end,
        function(widget)
            widget.enabledCallback = nil
            widget.anchorCallback = nil
            widget.anchorPointCallback = nil
            widget.targetPointCallback = nil
            widget.offsetYCheckCallback = nil
            widget.offsetYCallback = nil
            widget.deleteBtn:SetScript("OnClick", nil)
        end
    )

    local activeRows = {}

    local function LayoutRows()
        local y = 0
        for _, widget in ipairs(activeRows) do
            widget.root:ClearAllPoints()
            widget.root:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 0, y)
            widget.root:SetPoint("RIGHT", listContainer, "RIGHT", 0, 0)
            y = y - widget.rowHeight - 6
        end
        listContainer:SetHeight(math.max(1, -y))
        overrideArea:SetHeight(40 + 20 + 30 + math.max(1, -y) + 10)
        UpdateScrollHeight()
    end

    local RebuildOverrideList

    local function ConfigureRow(widget, key, data)
        widget.label:SetText(GetRowLabel(key))
        widget.enabledWrap:SetChecked(data.enabled == true)
        widget.enabledCallback = function(checked)
            data.enabled = checked and true or false
            API:Refresh("STYLE")
        end

        widget.deleteBtn:SetScript("OnClick", function()
            CDM.db.castBarOverrides[key] = nil
            API:Refresh("STYLE")
            RebuildOverrideList()
        end)

        local function WireDropdownField(wrap, dd, field, options, fallback, callbackKey)
            local function SetAppearance(on)
                dd:SetAlpha(on and 1 or 0.5)
                if dd.SetEnabled then dd:SetEnabled(on) end
            end
            local current = data[field]
            local function Seed()
                return (data.remembered and data.remembered[field]) or CDM.ResolveCastBarField(field, fallback)
            end
            wrap:SetChecked(current ~= nil)
            SetAppearance(current ~= nil)
            dd:SetDefaultText(GetOptionLabel(options, current or Seed()))
            widget[callbackKey] = function(checked)
                SetAppearance(checked)
                if checked then
                    data[field] = data[field] or Seed()
                    dd:SetDefaultText(GetOptionLabel(options, data[field]))
                else
                    data.remembered = data.remembered or {}
                    data.remembered[field] = data[field]
                    data[field] = nil
                end
                API:Refresh("STYLE")
            end
            UI.SetupValueDropdown(dd, options,
                function() return data[field] or Seed() end,
                function(value)
                    data[field] = value
                    if not wrap:GetChecked() then
                        wrap:SetChecked(true)
                        SetAppearance(true)
                    end
                    dd:SetDefaultText(GetOptionLabel(options, value))
                    API:Refresh("STYLE")
                end)
        end

        WireDropdownField(widget.anchorWrap, widget.anchorDD, "anchor", OVERRIDE_ANCHOR_OPTIONS, "resources", "anchorCallback")
        WireDropdownField(widget.anchorPointWrap, widget.anchorPointDD, "anchorPoint", OVERRIDE_POINT_OPTIONS, "BOTTOM", "anchorPointCallback")
        WireDropdownField(widget.targetPointWrap, widget.targetPointDD, "targetPoint", OVERRIDE_POINT_OPTIONS, "TOP", "targetPointCallback")

        do
            local wrap = widget.offsetYWrap
            local slider = widget.offsetYSlider
            local function SetAppearance(on)
                slider:SetAlpha(on and 1 or 0.5)
                if slider.Slider and slider.Slider.SetEnabled then slider.Slider:SetEnabled(on) end
            end
            local current = data.offsetY
            local function Seed()
                return (data.remembered and data.remembered.offsetY) or UI.RoundToInt(CDM.ResolveCastBarField("offsetY", -166))
            end
            wrap:SetChecked(current ~= nil)
            SetAppearance(current ~= nil)
            slider:UpdateUIValue(current or Seed())
            widget.offsetYCheckCallback = function(checked)
                SetAppearance(checked)
                if checked then
                    data.offsetY = data.offsetY or Seed()
                    slider:UpdateUIValue(data.offsetY)
                else
                    data.remembered = data.remembered or {}
                    data.remembered.offsetY = data.offsetY
                    data.offsetY = nil
                end
                API:Refresh("STYLE")
            end
            widget.offsetYCallback = function(value)
                local v = UI.RoundToInt(value)
                data.offsetY = v
                if not wrap:GetChecked() then
                    wrap:SetChecked(true)
                    SetAppearance(true)
                end
                API:Refresh("STYLE")
            end
        end
    end

    RebuildOverrideList = function()
        rowPool:ReleaseAll()
        activeRows = {}
        local overrides = CDM.db.castBarOverrides
        if not overrides or not next(overrides) then
            listContainer:SetHeight(1)
            overrideArea:SetHeight(40 + 20 + 30 + 1 + 10)
            UpdateScrollHeight()
            return
        end
        local keys = SortOverrideKeys(overrides)
        for _, key in ipairs(keys) do
            local widget = rowPool:Acquire(listContainer)
            activeRows[#activeRows + 1] = widget
            ConfigureRow(widget, key, overrides[key])
        end
        LayoutRows()
    end

    local function AddOverride(key)
        CDM.db.castBarOverrides = CDM.db.castBarOverrides or {}
        if CDM.db.castBarOverrides[key] then return end
        CDM.db.castBarOverrides[key] = { enabled = true }
        RebuildOverrideList()
        API:Refresh("STYLE")
    end

    local function Exists(key)
        return CDM.db.castBarOverrides and CDM.db.castBarOverrides[key] ~= nil
    end

    addDD:SetupMenu(function(_, root)
        for _, roleTok in ipairs({ "DPS", "TANK", "HEALER" }) do
            local key = "role:" .. roleTok
            if not Exists(key) then
                local lbl = roleTok == "DPS" and (L["DPS"])
                    or roleTok == "TANK" and (L["Tank"])
                    or (L["Healer"])
                root:CreateButton(lbl, function() AddOverride(key) end)
            end
        end

        root:CreateDivider()

        local CLASS_LIST, CLASS_SPECS = Shared.GetClassCatalog()
        for _, classInfo in ipairs(CLASS_LIST) do
            local color = RAID_CLASS_COLORS[classInfo.classTag]
            local coloredName = color and color:WrapTextInColorCode(classInfo.className) or classInfo.className
            local submenu = root:CreateButton(coloredName)
            local classKey = "class:" .. classInfo.classTag
            if not Exists(classKey) then
                local allLabel = string.format(L["All %s"], classInfo.className)
                submenu:CreateButton(allLabel, function() AddOverride(classKey) end)
            end
            local specs = CLASS_SPECS[classInfo.classTag]
            if specs and #specs > 0 then
                submenu:CreateDivider()
                for _, specInfo in ipairs(specs) do
                    local specKey = "spec:" .. specInfo.specID
                    if not Exists(specKey) then
                        submenu:CreateButton(specInfo.specName, function() AddOverride(specKey) end)
                    end
                end
            end
        end
    end)

    RebuildOverrideList()
    parent:HookScript("OnShow", UpdateScrollHeight)
end

local function CreateCastBarTab(page, tabId)
    local subTabs = UI.CreateSubTabBar(page, {
        { id = "general",   label = L["General"] },
        { id = "overrides", label = L["Anchoring"] },
    }, "general")

    local divider = page:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    local dividerH = divider:GetHeight()
    divider:SetPoint("TOPLEFT", subTabs.barFrame, "BOTTOMLEFT", -30, 0)
    divider:SetPoint("TOPRIGHT", subTabs.barFrame, "BOTTOMRIGHT", 30, 0)
    divider:SetHeight(dividerH)

    for _, id in ipairs({ "general", "overrides" }) do
        local pg = subTabs.subPages[id]
        pg:ClearAllPoints()
        pg:SetPoint("TOPLEFT", subTabs.barFrame, "BOTTOMLEFT", -30, -15)
        pg:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
    end

    page.controls.castBarPreviewEnabled = UI.CreateModernCheckbox(
        page,
        L["Show Preview"],
        CDM.castBarPreviewActive == true,
        function(checked)
            CDM.castBarPreviewActive = checked
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarPreviewEnabled:SetSize(140, 26)
    page.controls.castBarPreviewEnabled:SetPoint("TOPRIGHT", page, "TOPRIGHT", -20, -8)
    page.controls.castBarPreviewEnabled:SetFrameLevel(subTabs.barFrame:GetFrameLevel() + 10)
    page:HookScript("OnShow", function()
        page.controls.castBarPreviewEnabled:SetChecked(CDM.castBarPreviewActive == true)
    end)

    local scrollChild, scrollFrame = UI.CreateScrollableTab(subTabs.subPages.general, "AyijeCDM_CastBarScrollFrame", 700, 370)
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -10, 20)
    scrollChild:ClearAllPoints()
    scrollChild:SetPoint("TOPLEFT", 35, -5)
    scrollChild:SetPoint("TOPRIGHT", -25, -5)

    local layout = UI.CreateVerticalLayout(0)
    local function NextY(spacing) return layout:Next(spacing) end

    local enabled = CDM.db.castBarEnabled ~= false
    page.controls.castBarEnabled = UI.CreateModernCheckbox(
        scrollChild,
        L["Enable Cast Bar"],
        enabled,
        function(checked)
            CDM.db.castBarEnabled = checked
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarEnabled:SetPoint("TOPLEFT", -34, NextY(0))

    local blizzHidden = CDM.db.hideBlizzardCastBar or false
    page.controls.hideBlizzardCastBar = UI.CreateModernCheckbox(
        scrollChild,
        L["Hide Blizzard Cast Bar"],
        blizzHidden,
        function(checked)
            CDM.db.hideBlizzardCastBar = checked
            if checked and API.DisableBlizzardPlayerCastBar then
                API:DisableBlizzardPlayerCastBar()
            end
        end
    )
    page.controls.hideBlizzardCastBar:SetPoint("LEFT", page.controls.castBarEnabled, "RIGHT", 0, 0)
    NextY(35)

    local dimHeader = UI.CreateHeader(scrollChild, L["Dimensions"])
    dimHeader:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(30)

    page.controls.castBarWidthSlider = UI.CreateModernSlider(
        scrollChild,
        L["Width (0 = Auto)"],
        0, 1000,
        CDM.db.castBarWidth or 300,
        function(v)
            local value = UI.RoundToInt(v)
            if value > 0 and value < 60 then
                value = 60
                page.controls.castBarWidthSlider.Slider:SetValue(60)
            end
            CDM.db.castBarWidth = value
            page.UpdateAutoWidthLayout()
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarWidthSlider:SetPoint("TOPLEFT", 0, NextY(0))

    local autoSourceChecked = (CDM.db.castBarAutoWidthSource == "utility")
    page.controls.castBarAutoWidthSource = UI.CreateModernCheckbox(
        scrollChild,
        L["Match Utility Width"],
        autoSourceChecked,
        function(checked)
            CDM.db.castBarAutoWidthSource = checked and "utility" or "essential"
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarAutoWidthSource:SetPoint("TOPLEFT", page.controls.castBarWidthSlider, "BOTTOMLEFT", 0, -5)
    NextY(60)

    page.controls.castBarHeightSlider = UI.CreateModernSlider(
        scrollChild,
        L["Height"],
        8, 50,
        CDM.db.castBarHeight or 20,
        function(v)
            CDM.db.castBarHeight = UI.RoundToInt(v)
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarHeightSlider:SetPoint("TOPLEFT", 0, NextY(0))

    function page.UpdateAutoWidthLayout()
        local isAuto = (CDM.db.castBarWidth or 300) == 0
        page.controls.castBarAutoWidthSource:SetShown(isAuto)
        page.controls.castBarHeightSlider:ClearAllPoints()
        if isAuto then
            page.controls.castBarHeightSlider:SetPoint("TOPLEFT", page.controls.castBarAutoWidthSource, "BOTTOMLEFT", 0, -10)
        else
            page.controls.castBarHeightSlider:SetPoint("TOPLEFT", page.controls.castBarWidthSlider, "BOTTOMLEFT", 0, -10)
        end
    end
    page.UpdateAutoWidthLayout()
    NextY(60)

    local iconHeader = UI.CreateHeader(scrollChild, L["Spell Icon"])
    iconHeader:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(30)

    local showIcon = CDM.db.castBarShowIcon or false
    page.controls.castBarShowIcon = UI.CreateModernCheckbox(
        scrollChild,
        L["Show Spell Icon"],
        showIcon,
        function(checked)
            CDM.db.castBarShowIcon = checked
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarShowIcon:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(35)

    local iconPosLabel = scrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    iconPosLabel:SetText(L["Icon Position:"])
    iconPosLabel:SetPoint("TOPLEFT", 0, NextY(0))

    local ddIconPos = CreateFrame("DropdownButton", nil, scrollChild, "WowStyle1DropdownTemplate")
    ddIconPos:SetPoint("TOPLEFT", 0, NextY(20))
    ddIconPos:SetWidth(150)
    ddIconPos:SetDefaultText(CDM.db.castBarIconPosition or "LEFT")
    page.controls.castBarIconPositionDropdown = ddIconPos

    local iconPosOptions = {
        { value = "LEFT", label = L["Left"] },
        { value = "RIGHT", label = L["Right"] },
    }

    UI.SetupValueDropdown(
        ddIconPos,
        iconPosOptions,
        function() return CDM.db.castBarIconPosition or "LEFT" end,
        function(value)
            CDM.db.castBarIconPosition = value
            ddIconPos:SetDefaultText(value)
            API:Refresh("STYLE")
        end
    )
    NextY(50)

    page.controls.castBarIconGapSlider = UI.CreateModernSlider(
        scrollChild,
        L["Icon-Bar Gap"],
        -1, 20,
        CDM.db.castBarIconGap or 1,
        function(v)
            CDM.db.castBarIconGap = UI.RoundToInt(v)
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarIconGapSlider:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(60)

    local texHeader = UI.CreateHeader(scrollChild, L["Bar Texture"])
    texHeader:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(30)

    local useAtlas = CDM.db.castBarUseAtlasTextures ~= false
    page.controls.castBarUseAtlas = UI.CreateModernCheckbox(
        scrollChild,
        L["Use Blizzard Atlas Textures"],
        useAtlas,
        function(checked)
            CDM.db.castBarUseAtlasTextures = checked
            local showLSM = not checked
            if page.castBarLSMGroup then
                page.castBarLSMGroup:SetShown(showLSM)
            end
            if page.castBarTextHeader then
                page.castBarTextHeader:ClearAllPoints()
                if showLSM then
                    page.castBarTextHeader:SetPoint("TOPLEFT", page.castBarLSMGroup, "BOTTOMLEFT", 0, -10)
                else
                    page.castBarTextHeader:SetPoint("TOPLEFT", page.controls.castBarUseAtlas, "BOTTOMLEFT", 0, -15)
                end
            end
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarUseAtlas:SetPoint("TOPLEFT", 0, NextY(0))

    local lsmGroup = CreateFrame("Frame", nil, scrollChild)
    lsmGroup:SetSize(600, 310)
    lsmGroup:SetPoint("TOPLEFT", page.controls.castBarUseAtlas, "BOTTOMLEFT", 0, -10)
    page.castBarLSMGroup = lsmGroup

    lsmGroup:SetShown(not useAtlas)

    local lsmLayout = UI.CreateVerticalLayout(0)
    local function LsmNextY(spacing) return lsmLayout:Next(spacing) end

    local textureLabel = lsmGroup:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    textureLabel:SetText(L["Bar Texture:"])
    textureLabel:SetPoint("TOPLEFT", 0, LsmNextY(0))

    local ddTexture = CreateFrame("DropdownButton", nil, lsmGroup, "WowStyle1DropdownTemplate")
    ddTexture:SetPoint("TOPLEFT", 0, LsmNextY(20))
    ddTexture:SetWidth(220)
    ddTexture:SetDefaultText(CDM.db.castBarTexture or "Blizzard")
    page.controls.castBarTextureDropdown = ddTexture

    UI.SetupMediaDropdown(
        ddTexture,
        "statusbar",
        function() return CDM.db.castBarTexture or "Blizzard" end,
        function(name)
            CDM.db.castBarTexture = name
            API:Refresh("STYLE")
        end,
        function(name)
            ddTexture:SetDefaultText(name or "Blizzard")
        end
    )

    local bgTextureLabel = lsmGroup:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    bgTextureLabel:SetText(L["Background Texture:"])
    bgTextureLabel:SetPoint("TOPLEFT", 0, LsmNextY(50))

    local ddBgTexture = CreateFrame("DropdownButton", nil, lsmGroup, "WowStyle1DropdownTemplate")
    ddBgTexture:SetPoint("TOPLEFT", 0, LsmNextY(20))
    ddBgTexture:SetWidth(220)
    ddBgTexture:SetDefaultText(CDM.db.castBarBackgroundTexture or "Blizzard")
    page.controls.castBarBgTextureDropdown = ddBgTexture

    UI.SetupMediaDropdown(
        ddBgTexture,
        "statusbar",
        function() return CDM.db.castBarBackgroundTexture or "Blizzard" end,
        function(name)
            CDM.db.castBarBackgroundTexture = name
            API:Refresh("STYLE")
        end,
        function(name)
            ddBgTexture:SetDefaultText(name or "Blizzard")
        end
    )

    page.controls.castBarBackgroundColor = UI.CreateColorSwatch(lsmGroup, L["Background Color"], "castBarBackgroundColor", "STYLE")
    page.controls.castBarBackgroundColor:SetPoint("TOPLEFT", 0, LsmNextY(50))

    page.controls.castBarCastColor = UI.CreateColorSwatch(lsmGroup, L["Cast Color"], "castBarCastColor", "STYLE")
    page.controls.castBarCastColor:SetPoint("TOPLEFT", 0, LsmNextY(40))

    local useClassColor = CDM.db.castBarUseClassColor == true
    page.controls.castBarUseClassColor = UI.CreateModernCheckbox(
        lsmGroup,
        L["Class Color"],
        useClassColor,
        function(checked)
            CDM.db.castBarUseClassColor = checked
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarUseClassColor:SetPoint("LEFT", page.controls.castBarCastColor, "RIGHT", 20, 0)

    page.controls.castBarChannelColor = UI.CreateColorSwatch(lsmGroup, L["Channel Color"], "castBarChannelColor", "STYLE")
    page.controls.castBarChannelColor:SetPoint("TOPLEFT", 0, LsmNextY(40))

    page.controls.castBarUninterruptibleColor = UI.CreateColorSwatch(lsmGroup, L["Uninterruptible Color"], "castBarUninterruptibleColor", "STYLE")
    page.controls.castBarUninterruptibleColor:SetPoint("TOPLEFT", 0, LsmNextY(40))

    local textHeader = UI.CreateHeader(scrollChild, L["Text"])
    page.castBarTextHeader = textHeader
    if not useAtlas then
        textHeader:SetPoint("TOPLEFT", lsmGroup, "BOTTOMLEFT", 0, -10)
    else
        textHeader:SetPoint("TOPLEFT", page.controls.castBarUseAtlas, "BOTTOMLEFT", 0, -15)
    end

    page.controls.castBarFontSizeSlider = UI.CreateModernSlider(
        scrollChild,
        L["Font Size"],
        8, 24,
        CDM.db.castBarFontSize or 15,
        function(v)
            CDM.db.castBarFontSize = UI.RoundToInt(v)
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarFontSizeSlider:SetPoint("TOPLEFT", textHeader, "BOTTOMLEFT", 0, -15)

    local showName = CDM.db.castBarShowSpellName
    if showName == nil then showName = true end
    page.controls.castBarShowSpellName = UI.CreateModernCheckbox(
        scrollChild,
        L["Show Spell Name"],
        showName,
        function(checked)
            CDM.db.castBarShowSpellName = checked
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarShowSpellName:SetPoint("TOPLEFT", page.controls.castBarFontSizeSlider, "BOTTOMLEFT", 0, -10)

    page.controls.castBarNameMaxCharsSlider = UI.CreateModernSlider(
        scrollChild,
        L["Max Name Length (0 = Full)"],
        0, 30,
        CDM.db.castBarNameMaxChars or 0,
        function(v)
            CDM.db.castBarNameMaxChars = UI.RoundToInt(v)
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarNameMaxCharsSlider:SetPoint("TOPLEFT", page.controls.castBarShowSpellName, "BOTTOMLEFT", 0, -10)

    page.controls.castBarNameOffsetX = UI.CreateModernSlider(
        scrollChild,
        L["Name X Offset"],
        -50, 50,
        CDM.db.castBarNameOffsetX or 4,
        function(v)
            CDM.db.castBarNameOffsetX = UI.RoundToInt(v)
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarNameOffsetX:SetPoint("TOPLEFT", page.controls.castBarNameMaxCharsSlider, "BOTTOMLEFT", 0, -10)

    page.controls.castBarNameOffsetY = UI.CreateModernSlider(
        scrollChild,
        L["Name Y Offset"],
        -20, 20,
        CDM.db.castBarNameOffsetY or 0,
        function(v)
            CDM.db.castBarNameOffsetY = UI.RoundToInt(v)
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarNameOffsetY:SetPoint("TOPLEFT", page.controls.castBarNameOffsetX, "BOTTOMLEFT", 0, -10)

    local showTimer = CDM.db.castBarShowTimer
    if showTimer == nil then showTimer = true end
    page.controls.castBarShowTimer = UI.CreateModernCheckbox(
        scrollChild,
        L["Show Timer"],
        showTimer,
        function(checked)
            CDM.db.castBarShowTimer = checked
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarShowTimer:SetPoint("TOPLEFT", page.controls.castBarNameOffsetY, "BOTTOMLEFT", 0, -10)

    page.controls.castBarShowTotalDuration = UI.CreateModernCheckbox(
        scrollChild,
        L["Show Total Duration (e.g. 0.5/1.5)"],
        CDM.db.castBarShowTotalDuration == true,
        function(checked)
            CDM.db.castBarShowTotalDuration = checked
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarShowTotalDuration:SetPoint("TOPLEFT", page.controls.castBarShowTimer, "BOTTOMLEFT", 0, -10)

    page.controls.castBarTimerOffsetX = UI.CreateModernSlider(
        scrollChild,
        L["Timer X Offset"],
        -50, 50,
        CDM.db.castBarTimerOffsetX or -4,
        function(v)
            CDM.db.castBarTimerOffsetX = UI.RoundToInt(v)
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarTimerOffsetX:SetPoint("TOPLEFT", page.controls.castBarShowTotalDuration, "BOTTOMLEFT", 0, -10)

    page.controls.castBarTimerOffsetY = UI.CreateModernSlider(
        scrollChild,
        L["Timer Y Offset"],
        -20, 20,
        CDM.db.castBarTimerOffsetY or 0,
        function(v)
            CDM.db.castBarTimerOffsetY = UI.RoundToInt(v)
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarTimerOffsetY:SetPoint("TOPLEFT", page.controls.castBarTimerOffsetX, "BOTTOMLEFT", 0, -10)

    local showSpark = CDM.db.castBarShowSpark
    if showSpark == nil then showSpark = true end
    page.controls.castBarShowSpark = UI.CreateModernCheckbox(
        scrollChild,
        L["Show Spark"],
        showSpark,
        function(checked)
            CDM.db.castBarShowSpark = checked
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarShowSpark:SetPoint("TOPLEFT", page.controls.castBarTimerOffsetY, "BOTTOMLEFT", 0, -10)

    local _, playerClass = UnitClass("player")
    local specID = CDM.GetCurrentSpecID and CDM:GetCurrentSpecID()
    local hasEmpoweredCasts = (playerClass == "EVOKER") or (specID == 250) or (specID == 269)
    if hasEmpoweredCasts then
        local empHeader = UI.CreateHeader(scrollChild, L["Empowered Stages"])
        empHeader:SetPoint("TOPLEFT", page.controls.castBarShowSpark, "BOTTOMLEFT", 0, -15)

        page.controls.castBarEmpowerWindUpColor = UI.CreateColorSwatch(scrollChild, L["Wind Up Color"], "castBarEmpowerWindUpColor", "STYLE")
        page.controls.castBarEmpowerWindUpColor:SetPoint("TOPLEFT", empHeader, "BOTTOMLEFT", 0, -15)

        page.controls.castBarEmpowerStage1Color = UI.CreateColorSwatch(scrollChild, L["Stage 1 Color"], "castBarEmpowerStage1Color", "STYLE")
        page.controls.castBarEmpowerStage1Color:SetPoint("TOPLEFT", page.controls.castBarEmpowerWindUpColor, "BOTTOMLEFT", 0, -10)

        page.controls.castBarEmpowerStage2Color = UI.CreateColorSwatch(scrollChild, L["Stage 2 Color"], "castBarEmpowerStage2Color", "STYLE")
        page.controls.castBarEmpowerStage2Color:SetPoint("TOPLEFT", page.controls.castBarEmpowerStage1Color, "BOTTOMLEFT", 0, -10)

        -- Font of Magic talent: Preservation 375783, Devastation 411212, Augmentation 408083
        local hasFontOfMagic = IsPlayerSpell(375783) or IsPlayerSpell(411212) or IsPlayerSpell(408083)
        local lastAnchor = page.controls.castBarEmpowerStage2Color

        if hasFontOfMagic then
            page.controls.castBarEmpowerStage3Color = UI.CreateColorSwatch(scrollChild, L["Stage 3 Color"], "castBarEmpowerStage3Color", "STYLE")
            page.controls.castBarEmpowerStage3Color:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -10)
            lastAnchor = page.controls.castBarEmpowerStage3Color
        end

        page.controls.castBarEmpowerStage4Color = UI.CreateColorSwatch(scrollChild, L["Hold At Max Color"], "castBarEmpowerStage4Color", "STYLE")
        page.controls.castBarEmpowerStage4Color:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -10)
    end

    BuildAnchoringPage(subTabs.subPages.overrides)
end

API:RegisterConfigTab("castbar", L["Cast Bar"], CreateCastBarTab, 11.2)
