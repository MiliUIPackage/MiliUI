---@class addonTableBaganator
local addonTable = select(2, ...)
BaganatorSingleViewBankViewCharacterTabsAsBagsViewMixin = CreateFromMixins(BaganatorItemViewCommonBankViewCharacterTabsAsBagsViewMixin)

function BaganatorSingleViewBankViewCharacterTabsAsBagsViewMixin:GetSearchMatches()
  return self.Container.BankUnifiedLive.SearchMonitor:GetMatches()
end

function BaganatorSingleViewBankViewCharacterTabsAsBagsViewMixin:NotifyBagUpdate(updatedBags)
  self.Container.BankUnifiedLive:MarkBagsPending("bank", updatedBags)
end

function BaganatorSingleViewBankViewCharacterTabsAsBagsViewMixin:ShowTab(character, tabIndex, isLive)
  BaganatorItemViewCommonBankViewCharacterTabsAsBagsViewMixin.ShowTab(self, character, tabIndex, isLive)

  if self.BankMissingHint:IsShown() then
    return
  end

  self.Container.BankUnifiedLive:SetShown(self.isLive)
  self.Container.BankUnifiedCached:SetShown(not self.isLive)

  local bankWidth = addonTable.Config.Get(addonTable.Config.Options.BANK_VIEW_WIDTH)

  local refresh = self.refreshState[addonTable.Constants.RefreshReason.ItemData] or self.refreshState[addonTable.Constants.RefreshReason.ItemWidgets] or self.refreshState[addonTable.Constants.RefreshReason.ItemTextures] or self.refreshState[addonTable.Constants.RefreshReason.Flow] or self.refreshState[addonTable.Constants.RefreshReason.Layout]

  local activeBank

  if self.Container.BankUnifiedLive:IsShown() then
    activeBank = self.Container.BankUnifiedLive
  else
    activeBank = self.Container.BankUnifiedCached
  end

  if refresh then
    local characterData = Syndicator.API.GetCharacter(self.lastCharacter)
    local bagData = {}
    for _, tab in ipairs(characterData.bankTabs) do
      table.insert(bagData, tab.slots)
    end

    activeBank:ShowBags(bagData, self.lastCharacter, Syndicator.Constants.AllBankIndexes, nil, bankWidth)
  end

  self.searchToApply = self.searchToApply or refresh
  if self.searchToApply then
    local searchText = self:GetParent().SearchWidget.SearchBox:GetText()
    self:ApplySearch(searchText)
  end

  if self.refreshState[addonTable.Constants.RefreshReason.Layout] then
    local sideSpacing, topSpacing = addonTable.Utilities.GetSpacing()

    self.bankHeight = activeBank:GetHeight()

    activeBank:ClearAllPoints()
    activeBank:SetPoint("TOPLEFT", 0, 0)

    local all = {activeBank}
    addonTable.SingleViews.ComputeGamepadGrid(all, self:GetParent().SearchWidget.SearchBox, {isLive and self.DepositIntoReagentsBankButton or nil}, function(b)
      self.CurrencyWidget:AddGamepadUp(b)
    end)

    self.Container:SetSize(math.max(activeBank:GetWidth(), self:GetButtonsWidth(sideSpacing)), self.bankHeight)
  end

  addonTable.CallbackRegistry:TriggerEvent("ViewComplete")

  self:OnFinished()

  if self.refreshState[addonTable.Constants.RefreshReason.Layout] then
    self.CurrencyWidget:UpdateCurrencyTextPositions(self.Container:GetWidth() - self.buttonsWidth - 5, self.Container:GetWidth())
  end

  self:GetParent():OnTabFinished(activeBank.buttons[1], activeBank.buttons[#activeBank.buttons])
end

if table.freeze then
  table.freeze(BaganatorSingleViewBankViewCharacterTabsAsBagsViewMixin)
end
