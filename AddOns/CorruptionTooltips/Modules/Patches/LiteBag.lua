local Addon = LibStub("AceAddon-3.0"):GetAddon("CorruptionTooltips")
local Module = Addon:NewModule("LiteBag", "AceHook-3.0")

local Icons, Config

function Module:OnInitialize()
    Icons = Addon:GetModule("Icons")
    Config = Addon:GetModule("Config")
end

function Module:OnEnable()
    if Config:GetOption("itemicon") ~= false then
        if IsAddOnLoaded("LiteBag") then
            self:SecureHook("LiteBagItemButton_Update", CorruptionTooltips_LiteBag_Update)
        end
    end
end

function CorruptionTooltips_LiteBag_Update(button)
    local bag, slot = button:GetParent():GetID(), button:GetID()
    if (bag == nil) or (slot == nil) or (bag == 0 and slot == 0) or (bag == 100 and slot == 0) then return end
    local itemLoc = ItemLocation:CreateFromBagAndSlot(bag, slot)

    if (not itemLoc:IsValid()) then
        Icons:ClearIcon(button)
        return
    end

    local itemLink = C_Item.GetItemLink(itemLoc)
    Icons:ApplyIcon(button, itemLink)
end
