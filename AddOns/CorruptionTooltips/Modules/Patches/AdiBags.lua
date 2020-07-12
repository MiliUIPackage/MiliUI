local Addon = LibStub("AceAddon-3.0"):GetAddon("CorruptionTooltips")
local Module = Addon:NewModule("AdiBags")

local Icons, Config, Scanner, debounce

function Module:OnInitialize()
    Icons = Addon:GetModule("Icons")
    Config = Addon:GetModule("Config")
    Scanner = Addon:GetModule("Scanner")
end

function Module:OnEnable()
    if Config:GetOption("itemicon") ~= false then
        if IsAddOnLoaded("AdiBags") then
            LibStub('ABEvent-1.0').RegisterMessage("CorruptionTooltips", "AdiBags_BagOpened", CorruptionTooltips_AdiBags_Update)
            LibStub('ABEvent-1.0').RegisterMessage("CorruptionTooltips", "AdiBags_ForceFullLayout", CorruptionTooltips_AdiBags_Update)
        end
    end
end

function CorruptionTooltips_AdiBags_Apply(button)
    if not button then return end

    local bag, slot = button.bag, button.slot
    -- need to catch 0, 0 and 100, 0 here because the bank frame doesn't
    -- load everything immediately, so the OnUpdate needs to run until those frames are opened.
    if (bag == nil) or (slot == nil) or (bag == 0 and slot == 0) or (bag == 100 and slot == 0) then return end
    local itemLoc = ItemLocation:CreateFromBagAndSlot(bag, slot)

    if (not itemLoc:IsValid()) then
        Icons:ClearIcon(button)
        return
    end

    local itemLink = C_Item.GetItemLink(itemLoc)
    Icons:ApplyIcon(button, itemLink)
end

function CorruptionTooltips_AdiBags_Update()
    if debounce ~= true then
        debounce = true
        C_Timer.After(.5, function()
            debounce = false
            for i=1,600 do
                local frame = _G["AdiBagsItemButton"..i]
                if frame then
                    C_Timer.After(.5, function() CorruptionTooltips_AdiBags_Apply(frame) end)
                end
            end
            for i=1,28 do
                local frame = _G["AdiBagsBankItemButton"..i]
                if frame then
                    C_Timer.After(.5, function() CorruptionTooltips_AdiBags_Apply(frame) end)
                end
            end
        end)
    end
end
