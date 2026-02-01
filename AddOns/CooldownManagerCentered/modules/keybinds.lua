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
local spellIDToKeyBindCache = {}

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

local ButtonRowsPrefix = {
    ["blizzard"] = {
        [1] = "ActionButton",
        [2] = "MultiBarBottomLeftButton",
        [3] = "MultiBarBottomRightButton",
        [4] = "MultiBarRightButton",
        [5] = "MultiBarLeftButton",
        [6] = "MultiBar5Button",
        [7] = "MultiBar6Button",
        [8] = "MultiBar7Button",
    },
    ["elvui"] = {
        [1] = "ElvUI_Bar1Button",
        [2] = "ElvUI_Bar2Button",
        [3] = "ElvUI_Bar3Button",
        [4] = "ElvUI_Bar4Button",
        [5] = "ElvUI_Bar5Button",
        [6] = "ElvUI_Bar6Button",
        [7] = "ElvUI_Bar7Button",
        [8] = "ElvUI_Bar8Button",
        [9] = "ElvUI_Bar9Button",
        [10] = "ElvUI_Bar10Button",
        [11] = nil,
        [12] = nil,
        [13] = "ElvUI_Bar13Button",
        [14] = "ElvUI_Bar14Button",
        [15] = "ElvUI_Bar15Button",
    },
    ["dominos"] = {
        [1] = "DominosActionButton",
        [2] = "DominosActionButton",
        [3] = "MultiBarRightActionButton",
        [4] = "MultiBarLeftActionButton",
        [5] = "MultiBarBottomRightActionButton",
        [6] = "MultiBarBottomLeftActionButton",
        [7] = "DominosActionButton",
        [8] = "DominosActionButton",
        [9] = "DominosActionButton",
        [10] = "DominosActionButton",
        [11] = "DominosActionButton",
        [12] = "MultiBar5ActionButton",
        [13] = "MultiBar6ActionButton",
        [14] = "MultiBar7ActionButton",
    },
}

function Keybinds:GetActionsTableBySpellId(slotToKeybind)
    PrintDebug("Building Actions Table By Spell ID")

    local spellIdToKeyBind = {}

    local function assignResultForSlot(slot, keyBind)
        local actionType, id, subType = GetActionInfo(slot)
        if not spellIdToKeyBind[id] then
            if (actionType == "macro" and subType == "spell") or (actionType == "spell") then
                spellIdToKeyBind[id] = keyBind
            elseif actionType == "macro" then
                local macroSpellID = GetMacroSpell(id)
                if macroSpellID then
                    spellIdToKeyBind[macroSpellID] = keyBind
                end
            end
        end
    end
    if DominosActionButton1 then
        for i = 1, 14 do
            local bar = ButtonRowsPrefix["dominos"][i]

            if bar then
                for j = 1, 12 do
                    local buttonName = bar
                    if bar == "DominosActionButton" then
                        buttonName = bar .. ((i - 1) * 12 + j)
                    else
                        buttonName = bar .. j
                    end
                    local button = _G[buttonName]
                    local slot = button and button.action
                    local keyBind = button and button.HotKey and button.HotKey:GetText()
                    if button and slot and keyBind and keyBind ~= "●" then
                        assignResultForSlot(slot, keyBind)
                    end
                end
            end
        end
    elseif BT4Button1 then
        for i = 1, 180 do
            local button = _G["BT4Button" .. i]

            if button then
                local slot = button and button.action
                local keyBind = button and button.HotKey and button.HotKey:GetText()
                if button and slot and keyBind and keyBind ~= "●" then
                    assignResultForSlot(slot, keyBind)
                end
            end
        end
    elseif ElvUI_Bar1Button1 then
        for i = 1, 15 do
            local bar = ButtonRowsPrefix["elvui"][i]

            if bar then
                for j = 1, 12 do
                    local buttonName = bar .. j
                    local button = _G[buttonName]
                    local slot = button and button.action
                    if button and slot and button.config then
                        local keyBind = GetBindingKey(button.config.keyBoundTarget)
                        if keyBind then
                            assignResultForSlot(slot, keyBind)
                        end
                    end
                end
            end
        end
    else
        for i = 1, 8 do
            local bar = ButtonRowsPrefix["blizzard"][i]

            if bar then
                for j = 1, 12 do
                    local buttonName = bar .. j
                    local button = _G[buttonName]
                    local slot = button and button.action
                    local keyBoundTarget = button and button.commandName
                    if button and slot and keyBoundTarget then
                        local keyBind = GetBindingKey(keyBoundTarget)
                        if keyBind then
                            assignResultForSlot(slot, keyBind)
                        end
                    end
                end
            end
        end
    end
    return spellIdToKeyBind
end
_WTD = {}
local function BuildSpellKeyBindMapping()
    local spellIDToKeyBind = Keybinds:GetActionsTableBySpellId()

    local spellIDToKeyBindFormatted = {}

    for spellID, rawKey in pairs(spellIDToKeyBind) do
        if rawKey and rawKey ~= "" and rawKey ~= "●" and not spellIDToKeyBindFormatted[spellID] then
            local formattedKey = GetFormattedKeybind(rawKey)
            if formattedKey ~= "" then
                spellIDToKeyBindFormatted[spellID] = formattedKey
            end
        end
    end
    for spellID, keyBind in pairs(spellIDToKeyBindCache) do
        if not spellIDToKeyBindFormatted[spellID] then
            spellIDToKeyBindFormatted[spellID] = keyBind
        end
    end
    _WTD.spellIdToKeyBind = spellIDToKeyBind
    _WTD.spellIDToFormattedKeyBind = spellIDToKeyBindFormatted
    spellIDToKeyBindCache = spellIDToKeyBindFormatted
    return spellIDToKeyBindFormatted
end

function Keybinds:FindKeyBindForSpell(spellID, spellToKeybind)
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

    local spellToKeybind = BuildSpellKeyBindMapping()

    local children = { viewerFrame:GetChildren() }
    for _, child in ipairs(children) do
        if child.Icon then
            local spellID = ExtractSpellIDFromIcon(child)
            local keybind = ""

            if spellID then
                keybind = Keybinds:FindKeyBindForSpell(spellID, spellToKeybind)
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
        event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "UPDATE_BINDINGS"
        or event == "ACTIONBAR_HIDEGRID"
        or event == "UPDATE_BONUS_ACTIONBAR"
    then
        spellIDToKeyBindCache = {}
    end

    C_Timer.After(0.1, function()
        Keybinds:UpdateAllKeybinds()
    end)
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
    eventFrame:RegisterEvent("UPDATE_BINDINGS")
    eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("ACTIONBAR_HIDEGRID")
    eventFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")

    -- Hook into viewer layout refresh to update keybinds

    if not areHooksInitialized then
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
