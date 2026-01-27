-- Keybinds

local _, ns = ...

local Keybinds = {}
ns.Keybinds = Keybinds

local LSM = LibStub("LibSharedMedia-3.0", true)

local CMC_KEYBIND_DEBUG = false
local PrintDebug = function(...)
    if CMC_KEYBIND_DEBUG then
        print("[CMC Keybinds]", ...)
    end
end

local isModuleEnabled = false
local areHooksInitialized = false

local function IsDominosLoaded()
    return C_AddOns.IsAddOnLoaded("Dominos")
end
local function IsElvUILoaded()
    return C_AddOns.IsAddOnLoaded("ElvUI")
end
local NUM_ACTIONBAR_BUTTONS = 12
local MAX_ACTION_SLOTS = 180

local viewersSettingKey = {
    EssentialCooldownViewer = "Essential",
    UtilityCooldownViewer = "Utility",
}

local DEFAULT_FONT_PATH = "Fonts\\FRIZQT__.TTF"

local function GetFontPath(fontName)
    if not fontName or fontName == "" then
        return DEFAULT_FONT_PATH
    end
    if LSM then
        local fontPath = LSM:Fetch("font", fontName)
        if fontPath then
            return fontPath
        end
    end
    return DEFAULT_FONT_PATH
end

local function IsKeybindEnabledForAnyViewer()
    if not ns.db or not ns.db.profile then
        return false
    end
    for _, viewerSettingName in pairs(viewersSettingKey) do
        local enabledKey = "cooldownManager_showKeybinds_" .. viewerSettingName
        if ns.db.profile[enabledKey] then
            return true
        end
    end
    return false
end

local function GetKeybindSettings(viewerSettingName)
    local defaults = {
        anchor = "CENTER",
        fontSize = 14,
        offsetX = 0,
        offsetY = 0,
    }
    if not ns.db or not ns.db.profile then
        return defaults
    end
    return {
        anchor = ns.db.profile["cooldownManager_keybindAnchor_" .. viewerSettingName] or defaults.anchor,
        fontSize = ns.db.profile["cooldownManager_keybindFontSize_" .. viewerSettingName] or defaults.fontSize,
        offsetX = ns.db.profile["cooldownManager_keybindOffsetX_" .. viewerSettingName] or defaults.offsetX,
        offsetY = ns.db.profile["cooldownManager_keybindOffsetY_" .. viewerSettingName] or defaults.offsetY,
    }
end

local function GetFormattedKeybind(key)
    if not key or key == "" then
        return ""
    end

    local upperKey = key:upper()

    upperKey = upperKey:gsub("SHIFT%-", "S")
    upperKey = upperKey:gsub("META%-", "M")
    upperKey = upperKey:gsub("CTRL%-", "C")
    upperKey = upperKey:gsub("ALT%-", "A")
    upperKey = upperKey:gsub("STRG%-", "ST") -- German Ctrl

    upperKey = upperKey:gsub("MOUSE%s?WHEEL%s?UP", "MWU")
    upperKey = upperKey:gsub("MOUSE%s?WHEEL%s?DOWN", "MWD")
    upperKey = upperKey:gsub("MOUSE%s?BUTTON%s?", "M")
    upperKey = upperKey:gsub("BUTTON", "M")

    upperKey = upperKey:gsub("NUMPAD%s?PLUS", "N+")
    upperKey = upperKey:gsub("NUMPAD%s?MINUS", "N-")
    upperKey = upperKey:gsub("NUMPAD%s?MULTIPLY", "N*")
    upperKey = upperKey:gsub("NUMPAD%s?DIVIDE", "N/")
    upperKey = upperKey:gsub("NUMPAD%s?DECIMAL", "N.")
    upperKey = upperKey:gsub("NUMPAD%s?ENTER", "NEnt")
    upperKey = upperKey:gsub("NUMPAD%s?", "N")
    upperKey = upperKey:gsub("NUM%s?", "N")

    upperKey = upperKey:gsub("PAGE%s?UP", "PGU")
    upperKey = upperKey:gsub("PAGE%s?DOWN", "PGD")
    upperKey = upperKey:gsub("INSERT", "INS")
    upperKey = upperKey:gsub("DELETE", "DEL")
    upperKey = upperKey:gsub("SPACEBAR", "Spc")
    upperKey = upperKey:gsub("ENTER", "Ent")
    upperKey = upperKey:gsub("ESCAPE", "Esc")
    upperKey = upperKey:gsub("TAB", "Tab")
    upperKey = upperKey:gsub("CAPS%s?LOCK", "Caps")
    upperKey = upperKey:gsub("HOME", "Hom")
    upperKey = upperKey:gsub("END", "End")

    return upperKey
end

local function CalculateActionSlot(buttonID, barType)
    local page = GetActionBarPage and GetActionBarPage() or 1
    local bonusOffset = GetBonusBarOffset and GetBonusBarOffset() or 0

    if barType == "main" then
        if bonusOffset > 0 then
            page = 6 + bonusOffset
        end
    elseif barType == "multibarbottomleft" then
        page = 5
    elseif barType == "multibarbottomright" then
        page = 6
    elseif barType == "multibarright" then
        page = 3
    elseif barType == "multibarleft" then
        page = 4
    elseif barType == "multibar5" then
        page = 13
    elseif barType == "multibar6" then
        page = 14
    elseif barType == "multibar7" then
        page = 15
    end

    return math.max(1, math.min(buttonID, NUM_ACTIONBAR_BUTTONS)) + ((math.max(1, page) - 1) * NUM_ACTIONBAR_BUTTONS)
end

-- Build slot -> bindingKey mapping
local function GetSlotToBindingMapping()
    local mapping = {}

    -- Main action bar
    for buttonID = 1, NUM_ACTIONBAR_BUTTONS do
        local slot = CalculateActionSlot(buttonID, "main")
        mapping[slot] = "ACTIONBUTTON" .. buttonID
    end

    local barMappings = {
        {
            barType = "multibarbottomleft",
            pattern = "MULTIACTIONBAR2BUTTON",
        },
        {
            barType = "multibarbottomright",
            pattern = "MULTIACTIONBAR1BUTTON",
        },
        { barType = "multibarright", pattern = "MULTIACTIONBAR3BUTTON" },
        { barType = "multibarleft", pattern = "MULTIACTIONBAR4BUTTON" },
        { barType = "multibar5", pattern = "MULTIACTIONBAR5BUTTON" },
        { barType = "multibar6", pattern = "MULTIACTIONBAR6BUTTON" },
        { barType = "multibar7", pattern = "MULTIACTIONBAR7BUTTON" },
    }

    for _, barData in ipairs(barMappings) do
        for buttonID = 1, NUM_ACTIONBAR_BUTTONS do
            local slot = CalculateActionSlot(buttonID, barData.barType)
            mapping[slot] = barData.pattern .. buttonID
        end
    end

    return mapping
end

-- Build slot -> keybind mapping (raw keys)
local function GetSlotToKeybindMapping()
    local slotMapping = GetSlotToBindingMapping()
    _WTD.slotMapping = slotMapping
    local result = {}

    for slot, bindingKey in pairs(slotMapping) do
        local key = GetBindingKey(bindingKey)
        if key and key ~= "" then
            result[slot] = key
        end
    end

    return result
end

local orderOfSlots = {
    ["blizz"] = {
        [2] = 5,
        [3] = 4,
        [4] = 2,
        [5] = 3,
        [6] = 12,
        [7] = 13,
        [8] = 14,
    },
}

_WTD = {}

function Keybinds:GetActionsTableBySpellId()
    PrintDebug("Building Actions Table By Spell ID")

    local mainBarStartSlot = 1
    local mainBarEndSlot = 12

    if GetBonusBarOffset() > 0 then
        mainBarStartSlot = 72 + (GetBonusBarOffset() - 1) * NUM_ACTIONBAR_BUTTONS + 1
        mainBarEndSlot = mainBarStartSlot + NUM_ACTIONBAR_BUTTONS - 1
    end
    if C_ActionBar.GetActionBarPage() == 2 then
        mainBarStartSlot = 13
        mainBarEndSlot = 24
    end
    local result = {}

    function analyzeRange(start, endd)
        for slot = start, endd do
            local actionType, id, subType = GetActionInfo(slot)
            if not result[id] then
                if (actionType == "macro" and subType == "spell") or (actionType == "spell") then
                    result[id] = slot
                elseif actionType == "macro" then
                    local macroSpellID = GetMacroSpell(id)
                    if macroSpellID then
                        result[macroSpellID] = slot
                    end
                end
            end
        end
    end
    analyzeRange(mainBarStartSlot, mainBarEndSlot)

    for i = 2, 8 do
        local slot = orderOfSlots["blizz"][i]
        analyzeRange((slot * 12) + 1, ((slot + 1) * 12))
    end
    return result
end

-- Build spellID -> formatted keybind mapping (one keybind per spell, one spell per keybind)
local function BuildSpellKeybindMapping()
    local spellIdToSlot = Keybinds:GetActionsTableBySpellId()
    local slotToKeybind = GetSlotToKeybindMapping()

    local spellToKeybind = {} -- spellID -> formatted keybind
    local usedKeybinds = {} -- keybind -> true (to ensure one spell per keybind)

    for spellID, slot in pairs(spellIdToSlot) do
        local rawKey = slotToKeybind[slot]
        if rawKey and rawKey ~= "" then
            local formattedKey = GetFormattedKeybind(rawKey)
            if formattedKey ~= "" and not usedKeybinds[formattedKey] then
                spellToKeybind[spellID] = formattedKey
                usedKeybinds[formattedKey] = true
            end
        end
    end
    _WTD.spellIdToSlot = spellIdToSlot
    _WTD.slotToKeybind = slotToKeybind
    _WTD.spellToKeybind = spellToKeybind

    return spellToKeybind
end

function Keybinds:FindKeybindForSpell(spellID, spellToKeybind)
    if not spellID or spellID == 0 then
        return ""
    end

    -- Direct match
    if spellToKeybind[spellID] then
        return spellToKeybind[spellID]
    end

    -- Try override spell
    local overrideSpellID = C_Spell.GetOverrideSpell(spellID)
    if overrideSpellID and spellToKeybind[overrideSpellID] then
        return spellToKeybind[overrideSpellID]
    end

    -- Try base spell
    local baseSpellID = C_Spell.GetBaseSpell(spellID)
    if baseSpellID and spellToKeybind[baseSpellID] then
        return spellToKeybind[baseSpellID]
    end

    return ""
end

local function GetOrCreateKeybindText(icon, viewerSettingName)
    if icon.cmcKeybindText and icon.cmcKeybindText.text then
        return icon.cmcKeybindText.text
    end

    local settings = GetKeybindSettings(viewerSettingName)
    icon.cmcKeybindText = CreateFrame("Frame", nil, icon, "BackdropTemplate")
    icon.cmcKeybindText:SetFrameLevel(icon:GetFrameLevel() + 4)
    local keybindText = icon.cmcKeybindText:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    keybindText:SetPoint(settings.anchor, icon, settings.anchor, settings.offsetX, settings.offsetY)
    keybindText:SetTextColor(1, 1, 1, 1)
    keybindText:SetShadowColor(0, 0, 0, 1)
    keybindText:SetShadowOffset(1, -1)
    keybindText:SetDrawLayer("OVERLAY", 7)

    icon.cmcKeybindText.text = keybindText
    return icon.cmcKeybindText.text
end

local function GetKeybindFontName()
    if ns.db and ns.db.profile and ns.db.profile.cooldownManager_keybindFontName then
        return ns.db.profile.cooldownManager_keybindFontName
    end
    return "Friz Quadrata TT"
end

local function ApplyKeybindTextSettings(icon, viewerSettingName)
    if not icon.cmcKeybindText then
        return
    end

    local settings = GetKeybindSettings(viewerSettingName)
    local keybindText = GetOrCreateKeybindText(icon, viewerSettingName)

    icon.cmcKeybindText:Show()
    keybindText:ClearAllPoints()
    keybindText:SetPoint(settings.anchor, icon, settings.anchor, settings.offsetX, settings.offsetY)
    local fontName = GetKeybindFontName()
    local fontPath = GetFontPath(fontName)
    local fontFlags = ns.db.profile.cooldownManager_keybindFontFlags or {}
    local fontFlag = ""
    for n, v in pairs(fontFlags) do
        if v == true then
            fontFlag = fontFlag .. n .. ","
        end
    end
    keybindText:SetFont(fontPath, settings.fontSize, fontFlag or "")
end

local function ExtractSpellIDFromIcon(icon)
    if icon.cooldownID then
        local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(icon.cooldownID)
        return info and info.spellID or nil
    end
    return nil
end

local function UpdateIconKeybind(icon, viewerSettingName, keybind)
    if not icon then
        return
    end

    local enabledKey = "cooldownManager_showKeybinds_" .. viewerSettingName
    if not ns.db.profile[enabledKey] then
        if icon.cmcKeybindText then
            icon.cmcKeybindText:Hide()
        end
        return
    end

    local keybindText = GetOrCreateKeybindText(icon, viewerSettingName)
    icon.cmcKeybindText:Show()
    keybindText:SetText(keybind)
    keybindText:Show()
    if not keybind or keybind == "" then
        if icon.cmcKeybindText then
            icon.cmcKeybindText:Hide()
        end
    end
end

local function UpdateViewerKeybinds(viewerName)
    local viewerFrame = _G[viewerName]
    if not viewerFrame then
        return
    end

    local settingName = viewersSettingKey[viewerName]
    if not settingName then
        return
    end

    PrintDebug("UpdateViewerKeybinds for", viewerName)

    local spellToKeybind = BuildSpellKeybindMapping()
    local usedKeybinds = {} -- Track keybinds already assigned to an icon in this viewer

    local children = { viewerFrame:GetChildren() }
    for _, child in ipairs(children) do
        if child.Icon then
            local spellID = ExtractSpellIDFromIcon(child)
            local keybind = ""

            if spellID then
                keybind = Keybinds:FindKeybindForSpell(spellID, spellToKeybind)
            end

            UpdateIconKeybind(child, settingName, keybind)
        end
    end
end

function Keybinds:UpdateViewerKeybinds(viewerName)
    UpdateViewerKeybinds(viewerName)
end

function Keybinds:UpdateAllKeybinds()
    for viewerName, _ in pairs(viewersSettingKey) do
        UpdateViewerKeybinds(viewerName)
        self:ApplyKeybindSettings(viewerName)
    end
end

function Keybinds:ApplyKeybindSettings(viewerName)
    local viewerFrame = _G[viewerName]
    if not viewerFrame then
        return
    end

    local settingName = viewersSettingKey[viewerName]
    if not settingName then
        return
    end

    local children = { viewerFrame:GetChildren() }
    for _, child in ipairs(children) do
        if child.cmcKeybindText then
            ApplyKeybindTextSettings(child, settingName)
        end
    end
end

local eventFrame = CreateFrame("Frame")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if not isModuleEnabled then
        return
    end

    PrintDebug("Event:", event)

    if
        event == "PLAYER_TALENT_UPDATE"
        or event == "SPELLS_CHANGED"
        or event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "TRAIT_CONFIG_UPDATED"
        or event == "PLAYER_REGEN_DISABLED"
        or event == "ACTIONBAR_HIDEGRID"
    then
        -- Delay slightly to let game state settle
        C_Timer.After(0, function()
            Keybinds:UpdateAllKeybinds()
        end)
    else
        Keybinds:UpdateAllKeybinds()
    end
end)

function Keybinds:Shutdown()
    PrintDebug("Shutting down module")

    isModuleEnabled = false
    eventFrame:UnregisterAllEvents()

    for viewerName, _ in pairs(viewersSettingKey) do
        local viewerFrame = _G[viewerName]
        if viewerFrame then
            local children = { viewerFrame:GetChildren() }
            for _, child in ipairs(children) do
                if child.cmcKeybindText then
                    child.cmcKeybindText:Hide()
                end
            end
        end
    end
end

function Keybinds:Enable()
    if isModuleEnabled then
        return
    end
    PrintDebug("Enabling module")

    isModuleEnabled = true

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
    eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    eventFrame:RegisterEvent("UPDATE_BINDINGS")
    eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
    eventFrame:RegisterEvent("SPELLS_CHANGED")
    eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("ACTIONBAR_HIDEGRID")
    eventFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")

    -- Hook into viewer layout refresh to update keybinds

    if not areHooksInitialized then
        if IsDominosLoaded() then
            ns.Addon:Print(
                "|cffff0000Dominos detected|r - keybinds module may not function correctly with Dominos action bars |cffff00002 and 7,8,9,10,11|r - Those are |cffff0000not supported yet.|r"
            )
        end

        if IsElvUILoaded() then
            ns.Addon:Print(
                "|cffff0000ElvUI detected|r - keybinds module may not function correctly with ElvUI action bars |cffff00002 and 7,8,9,10|r - Those are |cffff0000not supported yet.|r"
            )
        end
        areHooksInitialized = true

        for viewerName, _ in pairs(viewersSettingKey) do
            local viewerFrame = _G[viewerName]
            if viewerFrame then
                hooksecurefunc(viewerFrame, "RefreshLayout", function()
                    if not isModuleEnabled then
                        return
                    end
                    PrintDebug("RefreshLayout called for viewer:", viewerName)
                    UpdateViewerKeybinds(viewerName)
                end)
            end
        end
    end

    self:UpdateAllKeybinds()
end

function Keybinds:Disable()
    if not isModuleEnabled then
        return
    end
    PrintDebug("Disabling module")
    self:Shutdown()
end

function Keybinds:Initialize()
    if not IsKeybindEnabledForAnyViewer() then
        PrintDebug("Not initializing - no viewers enabled")
        return
    end

    PrintDebug("Initializing module")
    self:Enable()

    -- Cleanup old DB cache if present
    if ns.db and ns.db.profile then
        ns.db.profile.keybindCache = nil
    end
end

function Keybinds:OnSettingChanged(viewerSettingName)
    local shouldBeEnabled = IsKeybindEnabledForAnyViewer()

    if shouldBeEnabled and not isModuleEnabled then
        self:Enable()
    elseif not shouldBeEnabled and isModuleEnabled then
        self:Disable()
    elseif isModuleEnabled then
        if viewerSettingName then
            for viewerName, settingName in pairs(viewersSettingKey) do
                if settingName == viewerSettingName then
                    UpdateViewerKeybinds(viewerName)
                    self:ApplyKeybindSettings(viewerName)
                    return
                end
            end
        end
        self:UpdateAllKeybinds()
    end
end
