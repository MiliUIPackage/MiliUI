
---------------------------------------------------------------
-- MiliUI Fix: TinyInspect-Remake Offhand Enchant Fix
-- 盾牌與副手物品（法器等）無法附魔，跳過缺附魔警告
-- Author: Mili
---------------------------------------------------------------

local GetItemInfoInstant = C_Item.GetItemInfoInstant

local OFFHAND_NO_ENCHANT_EQUIPLOC = {
    INVTYPE_SHIELD   = true,
    INVTYPE_HOLDABLE = true,
}

local function HideOffhandEnchantWarning(unit, parent)
    local frame = parent and parent.inspectFrame
    if not frame then return end

    local offhandLink
    local i = 1
    while frame["item"..i] do
        if frame["item"..i].index == 17 then
            offhandLink = frame["item"..i].link
            break
        end
        i = i + 1
    end

    if not offhandLink then return end

    local _, _, _, itemEquipLoc = GetItemInfoInstant(offhandLink)
    if not itemEquipLoc or not OFFHAND_NO_ENCHANT_EQUIPLOC[itemEquipLoc] then return end

    local slotLabel = _G["SECONDARYHANDSLOT"] or "SECONDARYHANDSLOT"
    i = 1
    while frame["xicon"..i] do
        local icon = frame["xicon"..i]
        if icon:IsShown() and icon.title and icon.title:find(slotLabel, 1, true) then
            icon:Hide()
        end
        i = i + 1
    end
end

local function TryHook()
    if type(ShowInspectItemListFrame) == "function" then
        hooksecurefunc("ShowInspectItemListFrame", HideOffhandEnchantWarning)
        return true
    end
end

if not TryHook() then
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self, _, addonName)
        if addonName == "TinyInspect-Remake" then
            TryHook()
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)
end
