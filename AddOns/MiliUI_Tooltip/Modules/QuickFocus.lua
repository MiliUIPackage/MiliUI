------------------------------------------------------------
-- 快速焦點：修飾鍵 + 左鍵點擊 mouseover 設焦點
-- SecureActionButton + override binding，只在脫戰時改綁定
------------------------------------------------------------
local _, ns = ...

local bindingFrame = CreateFrame("Frame")
local actionButton = CreateFrame("Button", "MiliUITip_QuickFocusButton", UIParent, "SecureActionButtonTemplate")
local pendingUpdate

actionButton:RegisterForClicks("AnyDown")
actionButton:SetAttribute("type1", "macro")
actionButton:SetAttribute("macrotext1", "/focus [@mouseover,exists]\n/clearfocus [@mouseover,noexists]")

local function Apply()
    if InCombatLockdown() then
        pendingUpdate = true
        return
    end
    pendingUpdate = nil
    ClearOverrideBindings(bindingFrame)
    local mod = ns.db and ns.db.general.quickFocusModKey or "none"
    local binding
    if mod == "alt" then
        binding = "ALT-BUTTON1"
    elseif mod == "ctrl" then
        binding = "CTRL-BUTTON1"
    elseif mod == "shift" then
        binding = "SHIFT-BUTTON1"
    end
    if binding and SetOverrideBindingClick then
        SetOverrideBindingClick(bindingFrame, true, binding, "MiliUITip_QuickFocusButton", "LeftButton")
    end
end
ns.ApplyQuickFocusBinding = Apply

bindingFrame:RegisterEvent("PLAYER_LOGIN")
bindingFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
bindingFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        Apply()
    elseif event == "PLAYER_REGEN_ENABLED" and pendingUpdate then
        Apply()
    end
end)
