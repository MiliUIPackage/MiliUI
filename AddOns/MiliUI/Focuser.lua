local modifier = "shift"
local mouseButton = "1"

local function SetFocusHotkey(frame)
    frame:SetAttribute(modifier.."-type"..mouseButton, "focus")
end

local function CreateFrame_Hook(type, name, parent, template)
    if template == "SecureUnitButtonTemplate" or template == "SecureUnitButtonTemplate,BackdropTemplate" then
        SetFocusHotkey(_G[name])
    end
end

hooksecurefunc("CreateFrame", CreateFrame_Hook)

local f = CreateFrame("CheckButton", "FocuserButton", UIParent, "SecureActionButtonTemplate")
f:SetAttribute("type1", "macro")
f:SetAttribute("macrotext", "/focus mouseover")
f:RegisterForClicks("AnyDown", "AnyUp")
SetOverrideBindingClick(FocuserButton, true, modifier.."-BUTTON"..mouseButton, "FocuserButton")

local duf = {
    PetFrame,
    PartyMemberFrame1,
    PartyMemberFrame2,
    PartyMemberFrame3,
    PartyMemberFrame4,
    PartyMemberFrame1PetFrame,
    PartyMemberFrame2PetFrame,
    PartyMemberFrame3PetFrame,
    PartyMemberFrame4PetFrame,
    PartyMemberFrame1TargetFrame,
    PartyMemberFrame2TargetFrame,
    PartyMemberFrame3TargetFrame,
    PartyMemberFrame4TargetFrame,
    TargetFrame,
    TargetFrameToT,
    TargetFrameToTTargetFrame,
}

for i, frame in pairs(duf) do
SetFocusHotkey(frame)
end