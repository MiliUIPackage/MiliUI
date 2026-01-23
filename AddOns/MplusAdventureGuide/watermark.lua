local addonName, addon = ...

function addon:initWatermark()
    if not addon.db.profile.watermark then return end

    for _, tbl in ipairs({PaperDollItemsFrame.EquipmentSlots, PaperDollItemsFrame.WeaponSlots}) do
        for _, slot in ipairs(tbl) do
            local slotEntered
            
            slot:HookScript("OnEnter", function()
                slotEntered = true
                local itemLink = GetInventoryItemLink("player", slot:GetID())
                if not itemLink then return end
                local itemRedundancySlot = C_ItemUpgrade.GetHighWatermarkSlotForItem(itemLink)
                if not itemRedundancySlot then return end
                local characterHighWatermark, accountHighWatermark = C_ItemUpgrade.GetHighWatermarkForSlot(itemRedundancySlot)
                if (not characterHighWatermark) or (not accountHighWatermark) then return end
                GameTooltip:AddLine("|cFFFFA500"..TRADESKILL_RECIPE_LEVEL_TOOLTIP_HIGHEST_RANK..": "..characterHighWatermark.." ("..ITEM_UPGRADE_DISCOUNT_TOOLTIP_ACCOUNT_WIDE.." "..accountHighWatermark..")|r")
                GameTooltip:Show()
            end)
            
            slot:HookScript("OnLeave", function()
                slotEntered = false
            end)
            
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
                if tooltip ~= GameTooltip then return end
                if slotEntered then
                    local itemLink = GetInventoryItemLink("player", slot:GetID())
                    if not itemLink then return end
                    local itemRedundancySlot = C_ItemUpgrade.GetHighWatermarkSlotForItem(itemLink)
                    local characterHighWatermark, accountHighWatermark = C_ItemUpgrade.GetHighWatermarkForSlot(itemRedundancySlot)
                    if (not characterHighWatermark) or (not accountHighWatermark) then return end
                    GameTooltip:AddLine("|cFFFFA500"..TRADESKILL_RECIPE_LEVEL_TOOLTIP_HIGHEST_RANK..": "..characterHighWatermark.." ("..ITEM_UPGRADE_DISCOUNT_TOOLTIP_ACCOUNT_WIDE.." "..accountHighWatermark..")|r")
                    GameTooltip:Show()
                end
            end)
        end
    end
end
