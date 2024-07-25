local addonName, addon = ...

function addon:initCurrencyTransferAllButton()
    if not addon.db.profile.currencyTransferAllButton then return end

    local allButton = CreateFrame("Button", "CurrencyTransferAllButton", CurrencyTransferMenu.AmountSelector, "UIPanelButtonTemplate")
    allButton:SetSize(50, 22)
    allButton:SetScript("OnClick", function()
        local amount = CurrencyTransferMenu.SourceBalancePreview.BalanceInfo.Amount:GetText():gsub(",", "")
        CurrencyTransferMenu.AmountSelector.InputBox:SetText(tonumber(amount))
        CurrencyTransferMenu.AmountSelector.InputBox:ValidateAndSetValue()
    end)
    allButton:SetPoint("TOPRIGHT", CurrencyTransferMenu.AmountSelector.InputBox, "TOPLEFT")
    allButton:SetText(ALL)

end
