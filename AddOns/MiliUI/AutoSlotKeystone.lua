local function AutoSlotKeystone()
    local validKey
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.hyperlink and string.find(info.hyperlink, "keystone:") then
                validKey = {bag, slot}
                break
            end
        end
        if validKey then break end
    end

    if validKey then
        if not CursorHasItem() then
            C_Container.PickupContainerItem(validKey[1], validKey[2])
            if CursorHasItem() then
                C_ChallengeMode.SlotKeystone()
            end
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "Blizzard_ChallengesUI" then
        if ChallengesKeystoneFrame then
            ChallengesKeystoneFrame:HookScript("OnShow", AutoSlotKeystone)
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

if C_AddOns.IsAddOnLoaded("Blizzard_ChallengesUI") and ChallengesKeystoneFrame then
    ChallengesKeystoneFrame:HookScript("OnShow", AutoSlotKeystone)
    frame:UnregisterEvent("ADDON_LOADED")
end
