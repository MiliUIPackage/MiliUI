local Addon = LibStub("AceAddon-3.0"):GetAddon("CorruptionTooltips")
local Module = Addon:NewModule("ArkInventory", "AceHook-3.0")

local Icons, Config

function Module:OnInitialize()
    Icons = Addon:GetModule("Icons")
    Config = Addon:GetModule("Config")
end

function Module:OnEnable()
    if Config:GetOption("itemicon") ~= false then
        if IsAddOnLoaded("ArkInventory") then
            self:SecureHook( ArkInventory.API, "ItemFrameUpdated", CorruptionTooltips_ArkInventory_Update )
        end
    end
end

function CorruptionTooltips_ArkInventory_Apply(frame)
    if not frame then return end
    if not frame.ARK_Data then return end
    local itemLink = nil
    if ArkInventory.API.LocationIsOffline( loc_id ) or not ( loc_id == ArkInventory.Const.Location.Bag or loc_id == ArkInventory.Const.Location.Bank ) then
        local i = ArkInventory.API.ItemFrameItemTableGet( frame )
        if i and i.h then
            itemLink = i.h
        end
    end
    Icons:ApplyIcon(frame, itemLink)
end

function CorruptionTooltips_ArkInventory_Update(frame)
    CorruptionTooltips_ArkInventory_Apply(frame)
end
