------------------------------------------------------------
-- MiliUI Focuser
-- Shift+Click 設定焦點目標 + 自動上團隊標記
------------------------------------------------------------
MiliUI_Focuser = {}

local modifier = "shift"
local mouseButton = "1"

local focuserButton
local hookedFrames = {}

local function GetDB()
    if not MiliUI_DB then MiliUI_DB = {} end
    if MiliUI_DB.focuserEnabled == nil then MiliUI_DB.focuserEnabled = true end
    if MiliUI_DB.focuserAutoMark == nil then MiliUI_DB.focuserAutoMark = false end
    if MiliUI_DB.focuserMarkIndex == nil then MiliUI_DB.focuserMarkIndex = 0 end
    if MiliUI_DB.focuserClearMark == nil then MiliUI_DB.focuserClearMark = false end
    return MiliUI_DB
end

local function GetActiveMacro()
    local db = GetDB()
    local lines = {}
    if db.focuserClearMark and db.focuserAutoMark then
        table.insert(lines, "/tm [@focus,exists] 0")
    end
    table.insert(lines, "/focus [@mouseover,exists]")
    table.insert(lines, "/clearfocus [@mouseover,noexists]")
    if db.focuserAutoMark and db.focuserMarkIndex > 0 and db.focuserMarkIndex <= 8 then
        table.insert(lines, "/tm [@mouseover,exists] " .. db.focuserMarkIndex)
    end
    return table.concat(lines, "\n")
end

----------------------------------------------------------------------
-- 單位框架：shift+click 執行巨集（focus + mark 一次完成）
----------------------------------------------------------------------
local function SetFocusHotkey(frame)
    if not frame then return end
    if not frame.SetAttribute then return end
    if InCombatLockdown() then return end

    frame:SetAttribute(modifier .. "-type" .. mouseButton, "macro")
    frame:SetAttribute(modifier .. "-macrotext" .. mouseButton, GetActiveMacro())
    hookedFrames[frame] = true
end

local function ClearFocusHotkey(frame)
    if not frame then return end
    if not InCombatLockdown() then
        frame:SetAttribute(modifier .. "-type" .. mouseButton, nil)
        frame:SetAttribute(modifier .. "-macrotext" .. mouseButton, nil)
        hookedFrames[frame] = false
    end
end

local defaultFrameNames = {
    "PetFrame",
    "TargetFrame",
    "TargetFrameToT",
    "TargetFrameToTTargetFrame",
    "PartyMemberFrame1",
    "PartyMemberFrame2",
    "PartyMemberFrame3",
    "PartyMemberFrame4",
    "PartyMemberFrame1PetFrame",
    "PartyMemberFrame2PetFrame",
    "PartyMemberFrame3PetFrame",
    "PartyMemberFrame4PetFrame",
    "PartyMemberFrame1TargetFrame",
    "PartyMemberFrame2TargetFrame",
    "PartyMemberFrame3TargetFrame",
    "PartyMemberFrame4TargetFrame",
    "Stuf.units.player",
    "Stuf.units.target",
    "Stuf.units.targettarget",
    "Stuf.units.focus",
    "Stuf.units.focustarget",
    "Stuf.units.pet",
    "Stuf.units.pettarget",
}

local function ApplyAllHotkeys()
    if InCombatLockdown() then return end
    for _, name in ipairs(defaultFrameNames) do
        local f = _G[name]
        if f then SetFocusHotkey(f) end
    end
    for _, plate in pairs(C_NamePlate.GetNamePlates()) do
        SetFocusHotkey(plate)
    end
end

local function RemoveAllHotkeys()
    if InCombatLockdown() then return end
    for frame in pairs(hookedFrames) do
        ClearFocusHotkey(frame)
    end
end

local function CreateFrame_Hook(type, name, parent, template)
    if not GetDB().focuserEnabled then return end
    if template == "SecureUnitButtonTemplate" or template == "SecureUnitButtonTemplate,BackdropTemplate" then
        SetFocusHotkey(_G[name])
    end
end

----------------------------------------------------------------------
-- FocuserButton：override binding 處理名條 / 世界目標
----------------------------------------------------------------------
local function SetupFocuserButton()
    if not focuserButton then
        focuserButton = CreateFrame("CheckButton", "FocuserButton", UIParent, "SecureActionButtonTemplate")
        focuserButton:SetAttribute("type1", "macro")
        focuserButton:RegisterForClicks("AnyDown")
    end
    focuserButton:SetAttribute("macrotext1", GetActiveMacro())
    ClearOverrideBindings(focuserButton)
    SetOverrideBindingClick(focuserButton, true, modifier .. "-BUTTON" .. mouseButton, "FocuserButton")
end

local function TeardownFocuserButton()
    if not focuserButton then return end
    if not InCombatLockdown() then
        ClearOverrideBindings(focuserButton)
    end
end

local function SwitchMacro()
    if InCombatLockdown() then return end
    local macro = GetActiveMacro()
    if focuserButton then
        focuserButton:SetAttribute("macrotext1", macro)
    end
    for frame in pairs(hookedFrames) do
        if hookedFrames[frame] and frame.SetAttribute then
            frame:SetAttribute(modifier .. "-macrotext" .. mouseButton, macro)
        end
    end
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
hooksecurefunc("CreateFrame", CreateFrame_Hook)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        local db = GetDB()
        if db.focuserEnabled then
            SetupFocuserButton()
            ApplyAllHotkeys()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if GetDB().focuserEnabled then
            ApplyAllHotkeys()
        end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if GetDB().focuserEnabled then
            local plate = C_NamePlate.GetNamePlateForUnit(arg1)
            if plate then SetFocusHotkey(plate) end
        end
    end
end)

-- 公開 API
function MiliUI_Focuser.IsEnabled()
    return GetDB().focuserEnabled
end

function MiliUI_Focuser.SetEnabled(val)
    local db = GetDB()
    db.focuserEnabled = val
    if InCombatLockdown() then
        print("|cffff6600[MiliUI]|r 戰鬥中無法切換，請離開戰鬥後重載介面。")
        return
    end
    if val then
        SetupFocuserButton()
        ApplyAllHotkeys()
    else
        RemoveAllHotkeys()
        TeardownFocuserButton()
    end
end

function MiliUI_Focuser.IsAutoMarkEnabled()
    return GetDB().focuserAutoMark
end

function MiliUI_Focuser.SetAutoMark(val)
    GetDB().focuserAutoMark = val
    SwitchMacro()
end

function MiliUI_Focuser.GetMarkIndex()
    return GetDB().focuserMarkIndex
end

function MiliUI_Focuser.SetMarkIndex(index)
    GetDB().focuserMarkIndex = index
    SwitchMacro()
end

function MiliUI_Focuser.IsClearMarkEnabled()
    return GetDB().focuserClearMark
end

function MiliUI_Focuser.SetClearMark(val)
    GetDB().focuserClearMark = val
    SwitchMacro()
end
