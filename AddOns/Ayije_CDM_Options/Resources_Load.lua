local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L
local Shared = ns.GroupEditorShared or {}

local BAR_DISPLAY_NAMES = ns.BAR_DISPLAY_NAMES

local MODE_OPTIONS = {
    { value = "always",      label = L["Always"] },
    { value = "never",       label = L["Never"] },
    { value = "conditional", label = L["Conditional"] },
}

local COMBAT_OPTIONS = {
    { value = "nil",   label = L["Don't care"] },
    { value = "true",  label = L["In Combat"] },
    { value = "false", label = L["Out of Combat"] },
}

local function TristateToValue(str)
    if str == "true" then return true end
    if str == "false" then return false end
    return nil
end

local function ValueToTristate(val)
    if val == true then return "true" end
    if val == false then return "false" end
    return "nil"
end

local function GetLoad(classKey, barKey)
    return CDM:GetBarSettingForClass(classKey, barKey, "load")
end

local function SetLoad(classKey, barKey, load)
    if load and not next(load) then load = nil end
    CDM:SetBarSettingForClass(classKey, barKey, "load", load)
    API:Refresh("RESOURCES", "LAYOUT")
end

local function GetLoadMode(classKey, barKey)
    return CDM:GetBarSettingForClass(classKey, barKey, "loadMode") or "always"
end

local function SetLoadMode(classKey, barKey, mode)
    CDM:SetBarSettingForClass(classKey, barKey, "loadMode", mode)
    API:Refresh("RESOURCES", "LAYOUT")
end

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

    -- Druid form-swapping: any spec can bear into Rage or cat into Energy/ComboPoints.
    -- Ironfur (Guardian-only) and LunarPower (Balance-only) remain single-spec via SPEC_POWER_MAP.
    local isDruidShared = classKey == "DRUID"
        and (barKey == "Rage" or barKey == "Energy" or barKey == "ComboPoints")

    local result = {}
    for _, specInfo in ipairs(allSpecs) do
        if isDruidShared or ns.IsBarActiveForSpec(barKey, specInfo.specID) then
            result[#result + 1] = specInfo
        end
    end
    return result
end

local function SetDimmed(frame, dimmed)
    frame:SetAlpha(dimmed and 0.4 or 1)
end

local function ShowBarLoad(loadPage, loadManager, classKey, barKey)
    if not loadManager then return end

    local sf, rc = loadManager.CreateScrollContent(800)
    if not rc then return end

    local yOff = 0
    local gold = CDM.CONST.GOLD

    local header = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font18")
    header:SetText(BAR_DISPLAY_NAMES[barKey] or barKey)
    header:SetTextColor(gold.r, gold.g, gold.b, 1)
    header:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 30

    local modeLabel = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    modeLabel:SetText(L["Load Mode"])
    modeLabel:SetPoint("TOPLEFT", 0, yOff)

    local modeDD = CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate")
    modeDD:SetPoint("LEFT", modeLabel, "RIGHT", 10, 0)
    modeDD:SetWidth(150)
    modeDD:SetDefaultText(L[GetLoadMode(classKey, barKey)] or L["Always"])
    loadManager.RegisterDropdown(modeDD)
    UI.SetupValueDropdown(modeDD, MODE_OPTIONS,
        function() return GetLoadMode(classKey, barKey) end,
        function(val)
            SetLoadMode(classKey, barKey, val)
            ShowBarLoad(loadPage, loadManager, classKey, barKey)
        end)
    yOff = yOff - 40

    local condContainer = CreateFrame("Frame", nil, rc)
    condContainer:SetPoint("TOPLEFT", 0, yOff)
    condContainer:SetPoint("RIGHT", 0, 0)

    local isConditional = GetLoadMode(classKey, barKey) == "conditional"
    SetDimmed(condContainer, not isConditional)

    local cYOff = 0
    local load = GetLoad(classKey, barKey) or {}

    local function SaveLoad()
        local ld = {}
        if load.combat ~= nil then ld.combat = load.combat end
        if load.hideMounted then ld.hideMounted = true end
        if load.hideInFeralForm then ld.hideInFeralForm = true end
        if load.spec then
            local hasAny = false
            for _ in pairs(load.spec) do hasAny = true; break end
            if hasAny then ld.spec = load.spec end
        end
        SetLoad(classKey, barKey, ld)
    end

    local combatLabel = condContainer:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    combatLabel:SetText(L["Combat"])
    combatLabel:SetPoint("TOPLEFT", 0, cYOff)

    local combatDD = CreateFrame("DropdownButton", nil, condContainer, "WowStyle1DropdownTemplate")
    combatDD:SetPoint("LEFT", combatLabel, "RIGHT", 10, 0)
    combatDD:SetWidth(160)
    combatDD:SetDefaultText(L["Don't care"])
    if isConditional then loadManager.RegisterDropdown(combatDD) end
    UI.SetupValueDropdown(combatDD, COMBAT_OPTIONS,
        function() return ValueToTristate(load.combat) end,
        function(val)
            load.combat = TristateToValue(val)
            SaveLoad()
        end)
    if not isConditional then combatDD:SetEnabled(false) end
    cYOff = cYOff - 40

    local mountCB = UI.CreateModernCheckbox(condContainer, L["Hide when mounted"],
        load.hideMounted == true,
        function(val)
            load.hideMounted = val or nil
            SaveLoad()
        end)
    mountCB:SetPoint("TOPLEFT", 0, cYOff)
    if not isConditional then
        mountCB.checkbox:SetEnabled(false)
    end
    cYOff = cYOff - 40

    local _, playerClass = UnitClass("player")
    if barKey == "Mana" and playerClass == "DRUID" then
        local feralCB = UI.CreateModernCheckbox(condContainer, L["Hide in Cat or Bear Form"],
            load.hideInFeralForm == true,
            function(val)
                load.hideInFeralForm = val or nil
                SaveLoad()
            end)
        feralCB:SetPoint("TOPLEFT", 0, cYOff)
        if not isConditional then
            feralCB.checkbox:SetEnabled(false)
        end
        cYOff = cYOff - 40
    end

    local specs = GetSpecsForBar(classKey, barKey)
    if #specs > 1 then
        local specLabel = condContainer:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
        specLabel:SetText(L["Specialization"])
        specLabel:SetPoint("TOPLEFT", 0, cYOff)
        cYOff = cYOff - 24

        local specTable = load.spec

        for _, specInfo in ipairs(specs) do
            local specID = specInfo.specID
            local checked = specTable == nil or (specTable[specID] == true)

            local cb = UI.CreateModernCheckbox(condContainer, specInfo.specName, checked,
                function(val)
                    if not load.spec then
                        load.spec = {}
                        for _, si in ipairs(specs) do
                            load.spec[si.specID] = true
                        end
                    end
                    load.spec[specID] = val or nil

                    local allChecked = true
                    for _, si in ipairs(specs) do
                        if not load.spec[si.specID] then
                            allChecked = false
                            break
                        end
                    end
                    if allChecked then load.spec = nil end

                    SaveLoad()
                end)
            cb:SetPoint("TOPLEFT", 14, cYOff)
            if not isConditional then
                cb.checkbox:SetEnabled(false)
            end
            cYOff = cYOff - 28
        end
    end

    condContainer:SetHeight(math.abs(cYOff))

    rc:SetHeight(math.abs(yOff) + math.abs(cYOff) + 20)
end

ns.ResourceLoadUI = {
    ShowBarLoad = ShowBarLoad,
}
