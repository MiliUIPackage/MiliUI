local frame = CreateFrame("Frame")
-- Avoid confirmation dialogs for sales to vendors
frame:SetScript("OnEvent", function()
  SellCursorItem()
end)

function Baganator.Transfers.VendorItems(toSell)
  frame:RegisterEvent("MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL")
  local sold = 0
  for _, item in ipairs(toSell) do
    local location = ItemLocation:CreateFromBagAndSlot(item.bagID, item.slotID)
    if C_Item.DoesItemExist(location) and not item.hasNoValue then
      C_Container.UseContainerItem(item.bagID, item.slotID)
      sold = sold + 1
      -- Limit sold to the most that can be bought back from the merchant if
      -- clicked by mistaked
      if sold >= 12 then
        break
      end
    end
  end
  if sold == 0 then
    UIErrorsFrame:AddMessage(BAGANATOR_L_THE_MERCHANT_DOESNT_WANT_ANY_OF_THOSE_ITEMS, 1.0, 0.1, 0.1, 1.0)
  end
  frame:UnregisterEvent("MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL")

  return Baganator.Constants.SortStatus.Complete
end
