local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L
local Shared = ns.GroupEditorShared or {}

local BAR_DISPLAY_NAMES = {
    Mana = L["Mana"], Rage = L["Rage"], Energy = L["Energy"], Focus = L["Focus"],
    ComboPoints = L["Combo Points"], Runes = L["Runes"], RunicPower = L["Runic Power"],
    SoulShards = L["Soul Shards"], LunarPower = L["Astral Power"], HolyPower = L["Holy Power"],
    Maelstrom = L["Maelstrom"], Chi = L["Chi"], Insanity = L["Insanity"],
    ArcaneCharges = L["Arcane Charges"], Fury = L["Fury"], Essence = L["Essence"],
    SoulFragments = L["Soul Fragments"], Stagger = L["Stagger"],
    MaelstromWeapon = L["Maelstrom Weapon"], DevourerSoulFragments = L["Devourer Souls"],
    Ironfur = L["Ironfur"], IgnorePain = L["Ignore Pain"], TipOfTheSpear = L["Tip of the Spear"],
}
ns.BAR_DISPLAY_NAMES = BAR_DISPLAY_NAMES

local function IsBarActiveForSpec(barKey, specID)
    if barKey == "Mana" then
        return CDM.MANA_SPECS and CDM.MANA_SPECS[specID] ~= nil
    end
    if not specID then return false end
    local specPowers = CDM.SPEC_POWER_MAP and CDM.SPEC_POWER_MAP[specID]
    if not specPowers then return false end
    local powerType = CDM.BAR_KEY_TO_POWER_TYPE and CDM.BAR_KEY_TO_POWER_TYPE[barKey]
    if not powerType then return false end
    if type(specPowers) == "table" then
        for _, pt in ipairs(specPowers) do
            if pt == powerType then return true end
        end
        return false
    end
    return specPowers == powerType
end
ns.IsBarActiveForSpec = IsBarActiveForSpec

local function GetSpecsForBar(classKey, barKey)
    if barKey == "Mana" then
        local manaSpecs = CDM.MANA_SPECS
        if not manaSpecs then return {} end
        local specs = {}
        for specID in pairs(manaSpecs) do
            local _, specName = GetSpecializationInfoByID(specID)
            if specName then
                specs[#specs + 1] = { specID = specID, specName = specName }
            end
        end
        table.sort(specs, function(a, b) return a.specID < b.specID end)
        return specs
    end

    local _, CLASS_SPECS = Shared.GetClassCatalog()
    local allSpecs = CLASS_SPECS and CLASS_SPECS[classKey] or {}

    local isDruidShared = classKey == "DRUID"
        and (barKey == "Rage" or barKey == "Energy" or barKey == "ComboPoints")

    local result = {}
    for _, specInfo in ipairs(allSpecs) do
        if isDruidShared or IsBarActiveForSpec(barKey, specInfo.specID) then
            result[#result + 1] = specInfo
        end
    end
    return result
end
ns.GetSpecsForBar = GetSpecsForBar

local PIP_BARS = {
    ComboPoints = true, HolyPower = true, Chi = true, ArcaneCharges = true,
    SoulShards = true, Runes = true, Essence = true, MaelstromWeapon = true,
    SoulFragments = true, DevourerSoulFragments = true, TipOfTheSpear = true,
}

local RECHARGING_BARS = {
    Runes = true, Essence = true,
}

local MAX_PIPS = {
    ComboPoints = { DRUID = 5, ROGUE = 7 },
    HolyPower = 5, Chi = 6, ArcaneCharges = 4,
    SoulShards = 5, Runes = 6, Essence = 6, MaelstromWeapon = 10,
    SoulFragments = 6, DevourerSoulFragments = 10, TipOfTheSpear = 3,
}

local function ResolveMaxPips(barKey, classKey)
    local v = MAX_PIPS[barKey]
    if type(v) == "table" then return v[classKey] or 5 end
    return v or 5
end

local VAR_LABELS = {
    always       = L["Always"],
    powerValue   = L["Power Value"],
    powerPercent = L["Power %"],
    powerFull    = L["Power Full"],
    spec         = L["Specialization"],
    pipRecharging = L["Pip Recharging"],
}

local CMP_OPTIONS = {
    { value = ">=", label = ">=" }, { value = ">", label = ">" },
    { value = "<=", label = "<=" }, { value = "<", label = "<" },
    { value = "==", label = "==" }, { value = "~=", label = "~=" },
}

local CMP_SPEC_OPTIONS = {
    { value = "==", label = "==" }, { value = "~=", label = "~=" },
}

local function GetConditions(classKey, barKey)
    return CDM:GetBarSettingForClass(classKey, barKey, "conditions")
end

local function SetConditions(classKey, barKey, conditions)
    if conditions and #conditions == 0 then conditions = nil end
    if conditions then
        for _, rule in ipairs(conditions) do
            local check = rule.check
            if check and check.op and check.op ~= "AND" then
                check.op = "AND"
            end
        end
    end
    CDM:SetBarSettingForClass(classKey, barKey, "conditions", conditions)
    API:Refresh("RESOURCES")
end

local function DefaultLeaf(barKey)
    if barKey == "SoulFragments" then
        return { var = "always" }
    end
    local var = PIP_BARS[barKey] and "powerValue" or "powerPercent"
    return { var = var, cmp = ">=", value = 0 }
end

local function NewRule(barKey)
    local rule = {
        check = DefaultLeaf(barKey),
        target = nil,
        overrides = {},
    }
    if barKey == "SoulFragments" then
        rule.target = 1
    end
    return rule
end


local function GetSpecList()
    local specs = {}
    local numSpecs = GetNumSpecializations()
    for i = 1, numSpecs do
        local id, name = GetSpecializationInfo(i)
        if id and name then
            specs[#specs + 1] = { value = id, label = name }
        end
    end
    return specs
end

local function BuildVarOptions(classKey, barKey)
    if barKey == "SoulFragments" then
        return { { value = "always", label = VAR_LABELS.always } }
    end
    local isPip = PIP_BARS[barKey]
    local opts = {
        { value = "powerValue",   label = VAR_LABELS.powerValue },
        { value = "powerFull",    label = VAR_LABELS.powerFull },
    }
    if not isPip then
        table.insert(opts, 2, { value = "powerPercent", label = VAR_LABELS.powerPercent })
    end
    if #GetSpecsForBar(classKey, barKey) > 1 then
        opts[#opts + 1] = { value = "spec", label = VAR_LABELS.spec }
    end
    if RECHARGING_BARS[barKey] then
        opts[#opts + 1] = { value = "pipRecharging", label = VAR_LABELS.pipRecharging }
    end
    return opts
end

local function BuildTargetOptions(barKey, classKey)
    local opts = {}
    if barKey ~= "SoulFragments" then
        opts[#opts + 1] = { value = "nil", label = L["All"] }
    end
    local maxPips = ResolveMaxPips(barKey, classKey)
    for i = 1, maxPips do
        opts[#opts + 1] = { value = tostring(i), label = L["Pip"] .. " " .. i }
    end
    return opts
end

local function CreateCheckRow(parent, check, classKey, barKey, onChange, registerDropdown)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(30)
    row:SetPoint("LEFT", 0, 0)
    row:SetPoint("RIGHT", 0, 0)

    local xOff = 0

    local varOpts = BuildVarOptions(classKey, barKey)
    local varDD = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
    varDD:SetPoint("LEFT", xOff, 0)
    varDD:SetWidth(130)
    varDD:SetDefaultText(VAR_LABELS[check.var] or check.var)
    UI.SetupValueDropdown(varDD, varOpts,
        function() return check.var end,
        function(val)
            check.var = val
            if val == "always" then
                check.cmp = nil
                check.value = nil
            elseif val == "powerFull" or val == "pipRecharging" then
                check.cmp = nil
                check.value = true
            elseif val == "spec" then
                check.cmp = "=="
                check.value = select(1, GetSpecializationInfo(GetSpecialization() or 1)) or 0
            else
                check.cmp = check.cmp or ">="
                check.value = check.value or 0
                if type(check.value) ~= "number" then check.value = 0 end
            end
            onChange()
        end)
    if registerDropdown then registerDropdown(varDD) end
    xOff = xOff + 135

    if check.var == "powerValue" or check.var == "powerPercent" then
        local cmpDD = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
        cmpDD:SetPoint("LEFT", xOff, 0)
        cmpDD:SetWidth(65)
        cmpDD:SetDefaultText(check.cmp or ">=")
        UI.SetupValueDropdown(cmpDD, CMP_OPTIONS,
            function() return check.cmp or ">=" end,
            function(val) check.cmp = val; onChange() end)
        if registerDropdown then registerDropdown(cmpDD) end
        xOff = xOff + 70

        local valBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        valBox:SetSize(55, 22)
        valBox:SetPoint("LEFT", xOff + 6, 0)
        valBox:SetAutoFocus(false)
        valBox:SetNumeric(false)
        valBox:SetText(tostring(check.value or 0))
        valBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        valBox:SetScript("OnEscapePressed", function(self)
            self:SetText(tostring(check.value or 0))
            self:ClearFocus()
        end)
        valBox:SetScript("OnEditFocusLost", function(self)
            local num = tonumber(self:GetText())
            if num and num ~= check.value then
                check.value = num
                onChange()
            end
        end)

        if check.var == "powerPercent" then
            local pctLabel = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            pctLabel:SetPoint("LEFT", valBox, "RIGHT", 3, 0)
            pctLabel:SetText("%")
        end
    elseif check.var == "spec" then
        local cmpDD = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
        cmpDD:SetPoint("LEFT", xOff, 0)
        cmpDD:SetWidth(65)
        cmpDD:SetDefaultText(check.cmp or "==")
        UI.SetupValueDropdown(cmpDD, CMP_SPEC_OPTIONS,
            function() return check.cmp or "==" end,
            function(val) check.cmp = val; onChange() end)
        if registerDropdown then registerDropdown(cmpDD) end
        xOff = xOff + 70

        local specList = GetSpecList()
        local specDD = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
        specDD:SetPoint("LEFT", xOff, 0)
        specDD:SetWidth(120)
        local specName = ""
        for _, s in ipairs(specList) do
            if s.value == check.value then specName = s.label; break end
        end
        specDD:SetDefaultText(specName ~= "" and specName or tostring(check.value))
        UI.SetupValueDropdown(specDD, specList,
            function() return check.value end,
            function(val) check.value = val; onChange() end)
        if registerDropdown then registerDropdown(specDD) end
    elseif check.var == "powerFull" then
        local toggleDD = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
        toggleDD:SetPoint("LEFT", xOff, 0)
        toggleDD:SetWidth(130)
        toggleDD:SetDefaultText(check.value == true and L["Is Full"] or L["Is Not Full"])
        UI.SetupValueDropdown(toggleDD, { { value = true, label = L["Is Full"] }, { value = false, label = L["Is Not Full"] } },
            function() return check.value end,
            function(val) check.value = val; onChange() end)
        if registerDropdown then registerDropdown(toggleDD) end
    elseif check.var == "pipRecharging" then
        local toggleDD = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
        toggleDD:SetPoint("LEFT", xOff, 0)
        toggleDD:SetWidth(150)
        toggleDD:SetDefaultText(check.value == true and L["Is Recharging"] or L["Is Not Recharging"])
        UI.SetupValueDropdown(toggleDD, { { value = true, label = L["Is Recharging"] }, { value = false, label = L["Is Not Recharging"] } },
            function() return check.value end,
            function(val) check.value = val; onChange() end)
        if registerDropdown then registerDropdown(toggleDD) end
    end

    local deleteBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    deleteBtn:SetSize(20, 20)
    deleteBtn:SetText("X")
    deleteBtn:SetPoint("RIGHT", 2, 0)
    row.deleteBtn = deleteBtn

    return row
end

local function CreateOverrideColorRow(parent, label, color, onChange)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(250, 24)

    local cb = UI.CreateModernCheckbox(row, label, color ~= nil, function(checked)
        if checked then
            onChange({ r = 1, g = 1, b = 1, a = 1 })
        else
            onChange(nil)
        end
    end)
    cb:SetPoint("LEFT", 0, 0)

    if color then
        local picker = UI.CreateSimpleColorPicker(row, color, function(r, g, b, a)
            onChange({ r = r, g = g, b = b, a = a or 1 })
        end, true)
        picker:SetPoint("LEFT", row, "LEFT", 150, 0)
        row.picker = picker
    end

    return row
end

local function ShowBarConditions(condPage, condManager, classKey, barKey)
    if not condManager then return end

    if barKey == "Stagger" or barKey == "Ironfur" or barKey == "IgnorePain" then
        condManager.Clear()
        return
    end

    local sf, rc = condManager.CreateScrollContent(1200)
    if not rc then return end

    local isPipBar = PIP_BARS[barKey] or false
    local conditions = GetConditions(classKey, barKey) or {}

    local function Rebuild()
        SetConditions(classKey, barKey, conditions)
        ShowBarConditions(condPage, condManager, classKey, barKey)
    end

    local yOff = 0

    local header = UI.CreateHeader(rc, BAR_DISPLAY_NAMES[barKey] or barKey)
    header:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 28

    for ruleIdx, rule in ipairs(conditions) do
        local ruleHeader = CreateFrame("Frame", nil, rc)
        ruleHeader:SetPoint("TOPLEFT", 0, yOff)
        ruleHeader:SetPoint("RIGHT", 0, 0)
        ruleHeader:SetHeight(24)

        local ruleLabel = ruleHeader:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
        ruleLabel:SetPoint("LEFT", 0, 0)
        ruleLabel:SetText(L["Rule"] .. " " .. ruleIdx)
        UI.SetTextSubtle(ruleLabel)

        local deleteRuleBtn = CreateFrame("Button", nil, ruleHeader, "UIPanelButtonTemplate")
        deleteRuleBtn:SetSize(20, 20)
        deleteRuleBtn:SetText("X")
        deleteRuleBtn:SetPoint("RIGHT", 2, 0)
        deleteRuleBtn:SetScript("OnClick", function()
            table.remove(conditions, ruleIdx)
            Rebuild()
        end)

        if ruleIdx > 1 then
            local moveUpBtn = CreateFrame("Button", nil, ruleHeader, "UIPanelButtonTemplate")
            moveUpBtn:SetSize(30, 20)
            moveUpBtn:SetText("Up")
            moveUpBtn:SetPoint("RIGHT", deleteRuleBtn, "LEFT", -2, 0)
            moveUpBtn:SetScript("OnClick", function()
                conditions[ruleIdx], conditions[ruleIdx - 1] = conditions[ruleIdx - 1], conditions[ruleIdx]
                Rebuild()
            end)
        end

        if ruleIdx < #conditions then
            local moveDownBtn = CreateFrame("Button", nil, ruleHeader, "UIPanelButtonTemplate")
            moveDownBtn:SetSize(30, 20)
            moveDownBtn:SetText("Dn")
            moveDownBtn:SetPoint("RIGHT", deleteRuleBtn, "LEFT", ruleIdx > 1 and -34 or -2, 0)
            moveDownBtn:SetScript("OnClick", function()
                conditions[ruleIdx], conditions[ruleIdx + 1] = conditions[ruleIdx + 1], conditions[ruleIdx]
                Rebuild()
            end)
        end

        yOff = yOff - 28

        if isPipBar then
            local targetLabel = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
            targetLabel:SetPoint("TOPLEFT", 4, yOff)
            targetLabel:SetText(L["Target:"])

            local targetOpts = BuildTargetOptions(barKey, classKey)
            local targetDD = CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate")
            targetDD:SetPoint("LEFT", targetLabel, "RIGHT", 8, 0)
            targetDD:SetWidth(100)
            local curTarget = rule.target and tostring(rule.target) or "nil"
            local targetText = L["All"]
            if rule.target then targetText = L["Pip"] .. " " .. rule.target end
            targetDD:SetDefaultText(targetText)
            if condManager.RegisterDropdown then condManager.RegisterDropdown(targetDD) end
            UI.SetupValueDropdown(targetDD, targetOpts,
                function() return rule.target and tostring(rule.target) or "nil" end,
                function(val)
                    rule.target = val ~= "nil" and tonumber(val) or nil
                    Rebuild()
                end)
            yOff = yOff - 32
        end

        local ifLabel = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
        ifLabel:SetPoint("TOPLEFT", 4, yOff)
        if ruleIdx == 1 then
            ifLabel:SetText(L["If:"])
        else
            ifLabel:SetText(L["Else If:"])
        end
        UI.SetTextSubtle(ifLabel)
        yOff = yOff - 20

        local check = rule.check
        local isCompound = check.op ~= nil
        local checks = isCompound and check.children or { check }

        for checkIdx, leaf in ipairs(checks) do
            if checkIdx > 1 then
                local opLabel = rc:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
                opLabel:SetPoint("TOPLEFT", 20, yOff)
                opLabel:SetText("AND")
                UI.SetTextMuted(opLabel)
                yOff = yOff - 16
            end

            local regDD = condManager and condManager.RegisterDropdown or nil
            local checkRow = CreateCheckRow(rc, leaf, classKey, barKey, Rebuild, regDD)
            checkRow:SetPoint("TOPLEFT", 20, yOff)
            checkRow.deleteBtn:SetScript("OnClick", function()
                if isCompound then
                    table.remove(checks, checkIdx)
                    if #checks == 1 then
                        rule.check = checks[1]
                    elseif #checks == 0 then
                        rule.check = DefaultLeaf(barKey)
                    end
                else
                    rule.check = DefaultLeaf(barKey)
                end
                Rebuild()
            end)
            yOff = yOff - 34
        end

        local addCheckBtn = CreateFrame("Button", nil, rc, "UIPanelButtonTemplate")
        addCheckBtn:SetSize(100, 20)
        addCheckBtn:SetPoint("TOPLEFT", 20, yOff)
        addCheckBtn:SetText(L["+ Add Check"])
        addCheckBtn:SetScript("OnClick", function()
            local newLeaf = DefaultLeaf(barKey)
            if isCompound then
                checks[#checks + 1] = newLeaf
            else
                rule.check = { op = "AND", children = { check, newLeaf } }
            end
            Rebuild()
        end)
        yOff = yOff - 28

        local thenLabel = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
        thenLabel:SetPoint("TOPLEFT", 4, yOff)
        thenLabel:SetText(L["Then:"])
        UI.SetTextSubtle(thenLabel)
        yOff = yOff - 22

        local ov = rule.overrides or {}

        if not rule.target then
            local alphaCb = UI.CreateModernCheckbox(rc, L["Alpha"], ov.alpha ~= nil, function(checked)
                if checked then
                    ov.alpha = 1.0
                else
                    ov.alpha = nil
                end
                rule.overrides = ov
                Rebuild()
            end)
            alphaCb:SetPoint("TOPLEFT", 20, yOff)

            if ov.alpha ~= nil then
                local alphaSlider = UI.CreateModernSlider(rc, "", 0, 100,
                    math.floor((ov.alpha or 1) * 100),
                    function(val)
                        ov.alpha = val / 100
                        rule.overrides = ov
                        SetConditions(classKey, barKey, conditions)
                    end, 0, 140)
                alphaSlider:SetPoint("LEFT", alphaCb.label, "RIGHT", 16, 0)
            end

            yOff = yOff - 28
        end

        local colorRow = CreateOverrideColorRow(rc, L["Bar Color"], ov.color, function(newColor)
            ov.color = CDM:DeepCopy(newColor)
            rule.overrides = ov
            Rebuild()
        end)
        colorRow:SetPoint("TOPLEFT", 20, yOff)
        yOff = yOff - 28

        local isFullCheck = rule.check and rule.check.var == "powerFull" and rule.check.value == true
        if not rule.target and not isFullCheck then
            local bgRow = CreateOverrideColorRow(rc, L["Background"], ov.bgColor, function(newColor)
                ov.bgColor = CDM:DeepCopy(newColor)
                rule.overrides = ov
                Rebuild()
            end)
            bgRow:SetPoint("TOPLEFT", 20, yOff)
            yOff = yOff - 28
        end

        if not rule.target then
            local tagColorRow = CreateOverrideColorRow(rc, L["Tag Color"], ov.tagColor, function(newColor)
                ov.tagColor = newColor and CDM:DeepCopy(newColor) or nil
                rule.overrides = ov
                Rebuild()
            end)
            tagColorRow:SetPoint("TOPLEFT", 20, yOff)
            yOff = yOff - 28
        end

        yOff = yOff - 30

        local divider = rc:CreateTexture(nil, "ARTWORK")
        divider:SetAtlas("Options_HorizontalDivider", true)
        divider:SetPoint("TOPLEFT", 0, yOff)
        divider:SetPoint("RIGHT", -10, 0)
        local dH = divider:GetHeight()
        divider:SetHeight(dH > 0 and dH or 2)
        yOff = yOff - 10
    end

    local addRuleBtn = CreateFrame("Button", nil, rc, "UIPanelButtonTemplate")
    addRuleBtn:SetSize(120, 24)
    addRuleBtn:SetPoint("TOPLEFT", 0, yOff)
    addRuleBtn:SetText(L["+ Add Rule"])
    addRuleBtn:SetScript("OnClick", function()
        conditions[#conditions + 1] = NewRule(barKey)
        Rebuild()
    end)
    yOff = yOff - 30

    rc:SetHeight(math.abs(yOff) + 20)
end

ns.ResourceConditionsUI = {
    ShowBarConditions = ShowBarConditions,
    PIP_BARS = PIP_BARS,
}
