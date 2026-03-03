local addon = TinyTooltip
if not addon then return end

local LibEvent = LibStub and LibStub:GetLibrary("LibEvent.7000", true)
if not LibEvent then return end

-- local function Debug(msg)
--     if not _G.ttDebug then return end
--     if not _G.ttDebugPrinted then
--         _G.ttDebugPrinted = true
--         local enabledText = "TinyTooltip DialogueUICompat: debug enabled"
--         if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
--             DEFAULT_CHAT_FRAME:AddMessage(enabledText)
--         else
--             print(enabledText)
--         end
--     end
--     local text = "TinyTooltip DialogueUICompat: " .. tostring(msg)
--     if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
--         DEFAULT_CHAT_FRAME:AddMessage(text)
--     else
--         print(text)
--     end
-- end
-- local function Debug(_)
-- end

-- local function Info(msg)
--     local text = "TinyTooltip DialogueUICompat: " .. tostring(msg)
--     if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
--         DEFAULT_CHAT_FRAME:AddMessage(text)
--     else
--         print(text)
--     end
-- end

-- Info("loaded (delayed)")
-- Info("enable debug: /ttdebug on | off")
--
-- SLASH_TINYTOOLTIPDIALOGUEDEBUG1 = "/ttdebug"
-- SlashCmdList.TINYTOOLTIPDIALOGUEDEBUG = function(msg)
--     local arg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
--     local enabled = (arg == "on" or arg == "1" or arg == "true")
--     local disabled = (arg == "off" or arg == "0" or arg == "false")
--     if enabled then
--         _G.ttDebug = true
--         _G.ttDebugPrinted = nil
--         Debug("debug enabled")
--     elseif disabled then
--         _G.ttDebug = false
--         _G.ttDebugPrinted = nil
--         Info("debug disabled")
--     else
--         Info("usage: /ttdebug on | off")
--     end
-- end

local function ApplyScaledTooltips()
    if not addon.db or not addon.db.general then return end
    local factor = addon._dialogueScaleFactor or 1
    local desired = addon.db.general.scale * factor
    addon._applyingDialogueScale = true
    for _, tip in ipairs(addon.tooltips or {}) do
        LibEvent:trigger("tooltip.scale", tip, desired)
    end
    addon._applyingDialogueScale = nil
end

local function EnableDialogueScale()
    -- Debug("EnableDialogueScale")
    addon._dialogueActive = true
    addon._dialogueScaleFactor = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    -- Debug("ScaleFactor=" .. tostring(addon._dialogueScaleFactor))
    ApplyScaledTooltips()
end

local function DisableDialogueScale()
    -- Debug("DisableDialogueScale")
    addon._dialogueActive = nil
    addon._dialogueScaleFactor = nil
    ApplyScaledTooltips()
end

local function HookDialogueUI()
    local dialogue = _G.DialogueUI
    local rtc = dialogue and dialogue.RewardTooltipCode
    if rtc then
        hooksecurefunc(rtc, "TakeOutGameTooltip", EnableDialogueScale)
        hooksecurefunc(rtc, "RestoreGameTooltip", DisableDialogueScale)
        -- Debug("HookDialogueUI: hooked TakeOutGameTooltip/RestoreGameTooltip")
    else
        -- Debug("HookDialogueUI: RewardTooltipCode not found, using scale-detect fallback")
    end
end

local function IsDialogueStack()
    if not debugstack then return false end
    local ok, stack = pcall(debugstack, 2, 6, 2)
    if not ok or type(stack) ~= "string" then return false end
    return stack:find("DialogueUI/Code/Dialogue/RewardTooltipCode.lua", 1, true) ~= nil
end

local function OnTooltipSetScale(tip, scale)
    if addon._applyingDialogueScale then return end
    local uiScale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local isDialogue = IsDialogueStack()
    -- Debug(("SetScale hook: name=%s scale=%s uiScale=%s isDialogue=%s"):format(
    --     (tip and tip.GetName and tip:GetName()) or tostring(tip),
    --     tostring(scale),
    --     tostring(uiScale),
    --     tostring(isDialogue)
    -- ))
    if isDialogue and scale and math.abs(scale - uiScale) < 0.0001 then
        if not addon._dialogueActive then
            -- Debug("Fallback: detected DialogueUI scale apply")
            EnableDialogueScale()
        end
        return
    end
    if isDialogue and scale and math.abs(scale - 1) < 0.0001 then
        if addon._dialogueActive then
            -- Debug("Fallback: detected DialogueUI restore")
            DisableDialogueScale()
        end
    end
end

local function HookTooltipScaleDetect()
    local tips = { GameTooltip, ShoppingTooltip1, ShoppingTooltip2, GarrisonFollowerTooltip }
    for _, tip in ipairs(tips) do
        if tip and tip.SetScale and not tip.TinyTooltipDialogueHooked then
            tip.TinyTooltipDialogueHooked = true
            hooksecurefunc(tip, "SetScale", function(self, scale)
                OnTooltipSetScale(self, scale)
            end)
            -- Debug("HookTooltipScaleDetect: hooked " .. ((tip.GetName and tip:GetName()) or tostring(tip)))
        end
    end
end

local function AdjustScaleIfDialogue(frame)
    if not addon._dialogueActive or addon._applyingDialogueScale then return end
    if not addon.db or not addon.db.general then return end
    local factor = addon._dialogueScaleFactor or 1
    local desired = addon.db.general.scale * factor
    if frame and frame.SetScale then
        addon._applyingDialogueScale = true
        frame:SetScale(desired)
        addon._applyingDialogueScale = nil
    end
end

LibEvent:attachTrigger("tooltip.scale", function(self, frame)
    AdjustScaleIfDialogue(frame)
end)

LibEvent:attachTrigger("tooltip:show", function(self, frame)
    AdjustScaleIfDialogue(frame)
end)

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, name)
    if name ~= "DialogueUI" then return end
    -- Debug("ADDON_LOADED DialogueUI")
    HookTooltipScaleDetect()
    HookDialogueUI()
end)

if IsAddOnLoaded and IsAddOnLoaded("DialogueUI") then
    -- Debug("DialogueUI already loaded")
    HookTooltipScaleDetect()
    HookDialogueUI()
end

HookTooltipScaleDetect()
