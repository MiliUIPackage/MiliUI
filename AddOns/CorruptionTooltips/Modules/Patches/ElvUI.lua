local Addon = LibStub("AceAddon-3.0"):GetAddon("CorruptionTooltips")
local Module = Addon:NewModule("ElvUI", "AceHook-3.0")

local Icons, Config

function Module:OnInitialize()
    Icons = Addon:GetModule("Icons")
    Config = Addon:GetModule("Config")
end

function Module:OnEnable()
    if Config:GetOption("itemicon") ~= false then
        if IsAddOnLoaded("ElvUI") then
            self:SecureHook("ToggleBag", CorruptionTooltips_ElvUI_ToggleBag)
            self:SecureHook("OpenAllBags", CorruptionTooltips_ElvUI_ToggleBag)
            self:SecureHook("CloseAllBags", CorruptionTooltips_ElvUI_ToggleBag)
            self:SecureHook("ToggleAllBags", CorruptionTooltips_ElvUI_ToggleBag)

            local EVENTS = {
                ["UNIT_INVENTORY_CHANGED"] = true,
                ["PLAYER_SPECIALIZATION_CHANGED"] = true,
                ["BAG_UPDATE"] = true,
                ["BAG_NEW_ITEMS_UPDATED"] = true,
                ["QUEST_ACCEPTED"] = true,
                ["BAG_SLOT_FLAGS_UPDATED"] = true,
                ["BANK_BAG_SLOT_FLAGS_UPDATED"] = true,
                ["PLAYERBANKSLOTS_CHANGED"] = true,
                ["BANKFRAME_OPENED"] = true,
                ["START_LOOT_ROLL"] = true,
                ["MERCHANT_SHOW"] = true,
                ["VOID_STORAGE_OPEN"] = true,
                ["VOID_STORAGE_CONTENTS_UPDATE"] = true,
                ["GUILDBANKBAGSLOTS_CHANGED"] = true,
                ["PLAYERREAGENTBANKSLOTS_CHANGED"] = true,
            }
            for event, _ in pairs(EVENTS) do
                Addon.frame:RegisterEvent(event);
            end
            Addon.frame:HookScript("OnEvent", CorruptionTooltips_ElvUI_Update)
        end
    end
end

function CorruptionTooltips_ElvUI_ToggleBag()
    CorruptionTooltips_ElvUI_Update(nil, "BAG_UPDATE")
end

function CorruptionTooltips_ElvUI_Apply(button)
    if not button then return end

    local bag, slot = button.bagID, button.slotID
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

function CorruptionTooltips_ElvUI_Update(self, event, ...)
    -- Update event
    -- Bags
    for i=0,NUM_CONTAINER_FRAMES do
        for j=1,MAX_CONTAINER_ITEMS do
            local frame = _G["ElvUI_ContainerFrameBag"..i.."Slot"..j]
            if frame then
                CorruptionTooltips_ElvUI_Apply(frame)
            end
        end
    end
    -- Main Bank
    for i=1,28 do
        for j=1,MAX_CONTAINER_ITEMS do
            local frame = _G["ElvUI_BankContainerFrameBag-"..i.."Slot"..j]
            if frame then
                CorruptionTooltips_ElvUI_Apply(frame)
            end
        end
    end
    -- Bank Bags
    for i=1,NUM_CONTAINER_FRAMES do
        for j=1,MAX_CONTAINER_ITEMS do
            local frame = _G["ElvUI_BankContainerFrameBag"..i.."Slot"..j]
            if frame then
                CorruptionTooltips_ElvUI_Apply(frame)
            end
        end
    end
end
