------------------------------------------------------------
-- MiliUI Focuser
-- Shift+Click 設定焦點目標 + 自動上團隊標記
------------------------------------------------------------
MiliUI_Focuser = {}

local modifier = "shift"
local mouseButton = "1"

local focuserButton
local bindButton            -- override binding 的中繼按鈕（見 SetupFocuserButton）
local SetupFocuserButton    -- forward declaration（SetFocusHotkey 需要 lazy 建立）
local hookedFrames = {}

local function GetDB()
    if not MiliUI_DB then MiliUI_DB = {} end
    if MiliUI_DB.focuserEnabled == nil then MiliUI_DB.focuserEnabled = true end
    if MiliUI_DB.focuserAutoMark == nil then MiliUI_DB.focuserAutoMark = false end
    if MiliUI_DB.focuserMarkIndex == nil then MiliUI_DB.focuserMarkIndex = 0 end
    if MiliUI_DB.focuserClearMark == nil then MiliUI_DB.focuserClearMark = false end
    return MiliUI_DB
end

-- markOverride：用指定的標記編號組巨集（給 FocuserBar 的標記選單預存
-- 每個編號對應的巨集文字，讓安全快照能在戰鬥中換上）；nil = 用目前設定值
local function GetActiveMacro(markOverride)
    local db = GetDB()
    local index = markOverride or db.focuserMarkIndex
    local lines = {}
    if db.focuserClearMark and db.focuserAutoMark then
        table.insert(lines, "/tm [@focus,exists] 0")
    end
    table.insert(lines, "/focus [@mouseover,exists]")
    table.insert(lines, "/clearfocus [@mouseover,noexists]")
    if db.focuserAutoMark and index > 0 and index <= 8 then
        table.insert(lines, "/tm [@mouseover,exists] " .. index)
    end
    return table.concat(lines, "\n")
end

-- 單位框架不再各自存完整巨集，改用 type="click" 委派到 FocuserButton
-- （11.0.2 起巨集文字裡的 /click 不能再觸發另一個巨集按鈕，但 clickbutton
-- 屬性的委派不受此限）。好處：戰鬥中改標記圖示時，只要改 FocuserButton
-- 一顆的巨集就全面生效，而這件事可由標記選單的安全快照代做。

----------------------------------------------------------------------
-- 單位框架：shift+click 執行巨集（focus + mark 一次完成）
----------------------------------------------------------------------
local function SetFocusHotkey(frame)
    if not frame then return end
    if not frame.SetAttribute then return end
    if InCombatLockdown() then return end
    if not focuserButton then SetupFocuserButton() end

    frame:SetAttribute(modifier .. "-type" .. mouseButton, "click")
    frame:SetAttribute(modifier .. "-clickbutton" .. mouseButton, focuserButton)
    hookedFrames[frame] = true
end

local function ClearFocusHotkey(frame)
    if not frame then return end
    if not InCombatLockdown() then
        frame:SetAttribute(modifier .. "-type" .. mouseButton, nil)
        frame:SetAttribute(modifier .. "-clickbutton" .. mouseButton, nil)
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
function SetupFocuserButton()   -- 已於檔案上方 forward-declare
    if not focuserButton then
        focuserButton = CreateFrame("CheckButton", "FocuserButton", UIParent, "SecureActionButtonTemplate")
        focuserButton:SetSize(1, 1)   -- 需存在且顯示中才能被委派點擊
        focuserButton:RegisterForClicks("AnyDown", "AnyUp")
        -- 單位框架與綁定都用 type="click" 委派過來，delegate:Click() 只送
        -- 「放開」邊緣；照 BurstPotionHelper 的配方標記 pressAndHold 並同時
        -- 設 type / typerelease / type1，確保不論 cvar 設定都恰好執行一次
        focuserButton:SetAttribute("pressAndHoldAction", true)
        focuserButton:SetAttribute("type", "macro")
        focuserButton:SetAttribute("typerelease", "macro")
        focuserButton:SetAttribute("type1", "macro")
    end
    local macro = GetActiveMacro()
    focuserButton:SetAttribute("macrotext", macro)
    focuserButton:SetAttribute("macrotextrelease", macro)
    focuserButton:SetAttribute("macrotext1", macro)

    -- 綁定不直接掛在 FocuserButton 上（鍵綁會送下+上兩個邊緣，配上
    -- pressAndHold 會跑兩次巨集），改綁到中繼按鈕：由 cvar 門檻挑一個
    -- 邊緣執行 click 動作，再委派 FocuserButton 恰好一次
    if not bindButton then
        bindButton = CreateFrame("Button", "FocuserBindButton", UIParent, "SecureActionButtonTemplate")
        bindButton:SetSize(1, 1)
        bindButton:RegisterForClicks("AnyDown", "AnyUp")
        -- 無後綴與 1 後綴都設（屬性查找的相容寫法，抄 BurstPotionHelper）
        bindButton:SetAttribute("type", "click")
        bindButton:SetAttribute("clickbutton", focuserButton)
        bindButton:SetAttribute("type1", "click")
        bindButton:SetAttribute("clickbutton1", focuserButton)
    end
    ClearOverrideBindings(bindButton)
    SetOverrideBindingClick(bindButton, true, modifier .. "-BUTTON" .. mouseButton, "FocuserBindButton")
end

local function TeardownFocuserButton()
    if not bindButton then return end
    if not InCombatLockdown() then
        ClearOverrideBindings(bindButton)
    end
end

-- 戰鬥中改設定（標記圖示等）時，巨集屬性是保護的不能改，
-- 記下待辦，脫戰（PLAYER_REGEN_ENABLED）再套用
local pendingMacro = false

local function SwitchMacro()
    if InCombatLockdown() then
        pendingMacro = true
        return
    end
    pendingMacro = false
    -- 單位框架只是委派點擊，巨集本體只在 FocuserButton 上（三個變體都要更新）
    if focuserButton then
        local macro = GetActiveMacro()
        focuserButton:SetAttribute("macrotext", macro)
        focuserButton:SetAttribute("macrotextrelease", macro)
        focuserButton:SetAttribute("macrotext1", macro)
    end
    -- 同步標記選單各格子預存的巨集文字（戰鬥中換圖示用）
    if MiliUI_FocuserBar and MiliUI_FocuserBar.SyncCellMacros then
        MiliUI_FocuserBar.SyncCellMacros()
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
            if pendingMacro then
                SwitchMacro()   -- 補套戰鬥中被擋下的巨集更新（含 FocuserButton）
            end
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
        if MiliUI_FocuserBar then MiliUI_FocuserBar.Refresh() end   -- 記下待辦，脫戰套用
        return
    end
    if val then
        SetupFocuserButton()
        ApplyAllHotkeys()
    else
        RemoveAllHotkeys()
        TeardownFocuserButton()
    end
    -- 標記切換列跟著開關；放在 FocuserButton 就緒之後，選單建立時才拿得到 frame ref
    if MiliUI_FocuserBar then MiliUI_FocuserBar.Refresh() end
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
    if MiliUI_FocuserBar then MiliUI_FocuserBar.UpdateMarkIcon() end
end

-- 給 FocuserBar 用：標記選單的安全快照需要 FocuserButton 的 frame ref，
-- 以及每個標記編號對應的巨集文字（預存為格子屬性，戰鬥中換上）
function MiliUI_Focuser.GetFocuserButton()
    return focuserButton
end

function MiliUI_Focuser.GetMacroForMarkIndex(index)
    return GetActiveMacro(index)
end

function MiliUI_Focuser.IsClearMarkEnabled()
    return GetDB().focuserClearMark
end

function MiliUI_Focuser.SetClearMark(val)
    GetDB().focuserClearMark = val
    SwitchMacro()
end
