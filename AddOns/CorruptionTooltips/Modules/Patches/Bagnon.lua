local Addon = LibStub("AceAddon-3.0"):GetAddon("CorruptionTooltips")
local Module = Addon:NewModule("Bagnon", "AceHook-3.0")

local Icons, Config

function Module:OnInitialize()
    Icons = Addon:GetModule("Icons")
    Config = Addon:GetModule("Config")
end

function Module:OnEnable()
    if Config:GetOption("itemicon") ~= false then
        if IsAddOnLoaded("Bagnon") then
            self:SecureHook(Bagnon.Item, "Update", CorruptionTooltips_Bagnon_Update)
            self:SecureHook(Bagnon.Item, "UpdateBorder", CorruptionTooltips_Bagnon_UpdateBorder)
        end
    end
end

function CorruptionTooltips_Bagnon_Update(button)
    if not button then return end
    local bag, slot = button:GetParent():GetID(), button:GetID()
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

function CorruptionTooltips_Bagnon_UpdateBorder(button)
    if not button.info.link then return end

    local itemLink = button.info.link
    if IsCorruptedItem(itemLink) then
        button.IconOverlay:SetShown(true)
    end
end
