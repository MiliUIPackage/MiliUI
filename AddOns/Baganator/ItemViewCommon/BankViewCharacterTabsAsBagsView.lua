
---@class addonTableBaganator
local addonTable = select(2, ...)

BaganatorItemViewCommonBankViewCharacterTabsAsBagsViewMixin = {}

function BaganatorItemViewCommonBankViewCharacterTabsAsBagsViewMixin:OnLoad()
  self.bankType = Enum.BankType.Character

  addonTable.Utilities.AddBagSortManager(self) -- self.sortManager
  addonTable.Utilities.AddBagTransferManager(self) -- self.transferManager

  addonTable.Utilities.AddScrollBar(self)

  self.BagSlots = CreateFrame("Frame", nil, self)
  self.BagSlots:SetSize(10, 10)
  Mixin(self.BagSlots, addonTable.ItemViewCommon.BankContainerTabSlotsMixin)
  self.BagSlots:OnLoad()
  self.BagSlots:SetMode("characterBank")

  addonTable.CallbackRegistry:RegisterCallback("SearchTextChanged",  function(_, text)
    if self:IsVisible() then
      self:ApplySearch(text)
    end
  end)

  self.refreshState = {}
  for _, value in pairs(addonTable.Constants.RefreshReason) do
    self.refreshState[value] = true
  end

  Syndicator.CallbackRegistry:RegisterCallback("BagCacheUpdate",  function(_, character, updates)
    self:SetLiveCharacter(character)
    self:NotifyBagUpdate(updates)
    if next(updates.bank) then
      self.refreshState[addonTable.Constants.RefreshReason.ItemData] = true
    end
    if updates.containerBags.bank then
      self.refreshState[addonTable.Constants.RefreshReason.Layout] = true
    end
    if character == self.liveCharacter and self:IsVisible() and next(self.refreshState) ~= nil then
      self:GetParent():UpdateView()
    end
  end)

  addonTable.CallbackRegistry:RegisterCallback("RefreshStateChange",  function(_, refreshState)
    self.refreshState = Mixin(self.refreshState, refreshState)

    for _, layout in ipairs(self.Container.Layouts) do
      layout:UpdateRefreshState(refreshState)
    end

    if self:IsVisible() then
      self:GetParent():UpdateView()
    end
  end)

  Syndicator.CallbackRegistry:RegisterCallback("CharacterDeleted", function(_, character)
    if self.lastCharacter == character then
      self.lastCharacter = self.liveCharacter
    end
    if self:IsVisible() then
      self:GetParent():UpdateView()
    end
  end)

  addonTable.CallbackRegistry:RegisterCallback("CharacterSelect", function(_, character)
    if character ~= self.lastCharacter then
      self.refreshState[addonTable.Constants.RefreshReason.ItemData] = true
      self.refreshState[addonTable.Constants.RefreshReason.Layout] = true
      self.refreshState[addonTable.Constants.RefreshReason.Character] = true
      if self:IsVisible() then
        self.lastCharacter = character
        self:GetParent():UpdateView()
      else
        self.lastCharacter = character
      end
    end
  end)

  addonTable.CallbackRegistry:RegisterCallback("SettingChanged",  function(_, settingName)
    if not self.lastCharacter then
      return
    end
    if settingName == addonTable.Config.Options.BANK_ONLY_VIEW_SHOW_BAG_SLOTS and self:IsVisible() then
      self.BagSlots:Update(self.lastCharacter, self.isLive)
      self:OnFinished(true)
    end
  end)

  self.ToggleAllCharacters:SetPoint("TOPLEFT", self, addonTable.Constants.ButtonFrameOffset, -1 + addonTable.Constants.ButtonFrameOffsetTop)

  addonTable.Gamepad.LinkButtons(self.ToggleBagSlotsButton, "Right", self:GetParent().CustomiseButton)

  addonTable.Skins.AddFrame("Button", self.DepositReagentsButton)
end

local function GetUnifiedSortData()
  local bagData = {}
  for _, tab in ipairs(Syndicator.API.GetCharacter(Syndicator.API.GetCurrentCharacter()).bankTabs) do
    table.insert(bagData, tab.slots)
  end
  local indexesToUse = {}
  for index, bagID in ipairs(Syndicator.Constants.AllBankIndexes) do
    indexesToUse[index] = true
  end

  return bagData, indexesToUse
end

function BaganatorItemViewCommonBankViewCharacterTabsAsBagsViewMixin:SetLiveCharacter(character)
  self.liveCharacter = character
end

function BaganatorItemViewCommonBankViewCharacterTabsAsBagsViewMixin:ApplySearch(text)
  if not self:IsVisible() then
    return
  end

  for _, layout in ipairs(self.Container.Layouts) do
    if layout:IsShown() then
      layout:ApplySearch(text)
    end
  end
end

function BaganatorItemViewCommonBankViewCharacterTabsAsBagsViewMixin:DoSort(isReverse)
  local bagChecks = addonTable.Sorting.GetBagUsageChecks(Syndicator.Constants.AllBankIndexes)
  local function DoSortInternal()
    local bagData, indexesToUse = GetUnifiedSortData()
    local status = addonTable.Sorting.ApplyBagOrdering(
      bagData,
      Syndicator.Constants.AllBankIndexes,
      indexesToUse,
      bagChecks,
      isReverse,
      false,
      0
    )
    self.sortManager:Apply(status, DoSortInternal, function() end)
  end
  DoSortInternal()
end

function BaganatorItemViewCommonBankViewCharacterTabsAsBagsViewMixin:OnShow()
  self.transferState = {}
end

function BaganatorItemViewCommonBankViewCharacterTabsAsBagsViewMixin:CombineStacks(callback)
  local bagData = GetUnifiedSortData()
  addonTable.Sorting.CombineStacks(
    bagData,
    Syndicator.Constants.AllBankIndexes,
    function(status)
      self.sortManager:Apply(status, function()
        self:CombineStacks(callback)
      end, function()
        callback()
      end)
    end
  )
end

function BaganatorItemViewCommonBankViewCharacterTabsAsBagsViewMixin:CombineStacksAndSort(isReverse)
  local sortMethod = addonTable.Config.Get(addonTable.Config.Options.SORT_METHOD)

  if not addonTable.Sorting.IsModeAvailable(sortMethod) then
    addonTable.Config.ResetOne(addonTable.Config.Options.SORT_METHOD)
    sortMethod = addonTable.Config.Get(addonTable.Config.Options.SORT_METHOD)
  end

  if addonTable.API.ExternalContainerSorts[sortMethod] then
    if addonTable.Config.Get(addonTable.Config.Options.SORT_START_AT_BOTTOM) then
      isReverse = not isReverse
    end
    addonTable.API.ExternalContainerSorts[sortMethod].callback(isReverse, Baganator.API.Constants.ContainerType.CharacterBank)
  elseif sortMethod == "combine_stacks_only" then
    self:CombineStacks(function() end)
  else
    self:CombineStacks(function()
      self:DoSort(isReverse)
    end)
  end
end

function BaganatorItemViewCommonBankViewCharacterTabsAsBagsViewMixin:RemoveSearchMatches(getItems)
  local matches = (getItems and getItems()) or self:GetSearchMatches()

  local bagSlots = addonTable.Transfers.GetBagsSlots(
    Syndicator.API.GetCharacter(Syndicator.API.GetCurrentCharacter()).bags,
    Syndicator.Constants.AllBagIndexes
  )

  local status = addonTable.Transfers.FromBagsToBags(matches, Syndicator.Constants.AllBagIndexes, bagSlots)

  self.transferManager:Apply(status, {"BagCacheUpdate"}, function()
    self:RemoveSearchMatches(getItems)
  end, function()
    self.transferState = {}
  end)
end

-- Used to ensure translated button text doesn't cause buttons to overlap
function BaganatorItemViewCommonBankViewCharacterTabsAsBagsViewMixin:GetButtonsWidth(sideSpacing)
  return addonTable.Constants.ButtonFrameOffset + sideSpacing - 2
end

function BaganatorItemViewCommonBankViewCharacterTabsAsBagsViewMixin:ResetToLive()
  self.lastCharacter = self.liveCharacter
end

function BaganatorItemViewCommonBankViewCharacterTabsAsBagsViewMixin:UpdateView()
  self:ShowTab(self.lastCharacter, self:GetParent().liveBankActive and self.lastCharacter == self.liveCharacter)
end

function BaganatorItemViewCommonBankViewCharacterTabsAsBagsViewMixin:ShowTab(character, isLive)
  if self.isLive ~= isLive or character ~= self.lastCharacter then
    self.refreshState[addonTable.Constants.RefreshReason.ItemData] = true
    self.refreshState[addonTable.Constants.RefreshReason.Character] = true
  end
  self.lastCharacter = character

  self.isLive = isLive

  self.searchToApply = self.searchToApply or self.refreshState[addonTable.Constants.RefreshReason.Searches] or self.refreshState[addonTable.Constants.RefreshReason.ItemData] or self.refreshState[addonTable.Constants.RefreshReason.ItemWidgets]

  local characterData = Syndicator.API.GetCharacter(self.lastCharacter)

  addonTable.Utilities.AddGeneralDropSlot(self, function()
    local bagData = {}
    for index, tab in ipairs(Syndicator.API.GetCharacter(self.lastCharacter).bankTabs) do
      table.insert(bagData, tab.slots)
    end
    return bagData
  end, Syndicator.Constants.AllBankIndexes)

  if not characterData then
    self:GetParent():SetTitle("")
    return
  else
    self:GetParent():SetTitle(addonTable.Locales.XS_BANK:format(characterData.details.character))
  end

  local characterBank = characterData.bankTabs and characterData.bankTabs[1]

  local isBankData = characterBank and #characterBank.slots ~= 0
  self.BankMissingHint:SetShown(not isBankData)
  self:GetParent().SearchWidget:SetShown(addonTable.Config.Get(addonTable.Config.Options.SHOW_SEARCH_BOX) and isBankData)

  if self.BankMissingHint:IsShown() then
    if self.isLive and C_Bank.CanPurchaseBankTab(Enum.BankType.Character) then
      self.BankMissingHint:SetText(addonTable.Locales.CHARACTER_BANK_NOT_PURCHASED_FOREVER_HINT)
    elseif self.isLive and C_Bank.FetchBankLockedReason(Enum.BankType.Account) == Enum.BankLockedReason.BankDisabled then
      self.BankMissingHint:SetText(BANK_LOCKED_REASON_BANK_DISABLED)
    else
      self.BankMissingHint:SetText(addonTable.Locales.BANK_DATA_MISSING_HINT:format(characterData.details.character))
    end
  end

  self:GetParent().AllButtons = {}
  tAppendAll(self:GetParent().AllButtons, self:GetParent().AllFixedButtons)
  tAppendAll(self:GetParent().AllButtons, self.TopButtons)

  local sideSpacing, topSpacing = addonTable.Utilities.GetSpacing()

  self.DepositReagentsButton:SetShown(self.isLive)
  if self.isLive then
    self.buttonsWidth = self.DepositReagentsButton:GetWidth() + 10
    table.insert(self:GetParent().AllButtons, self.DepositIntoReagentsBankButton)
    self.DepositReagentsButton:ClearAllPoints()
    self.DepositReagentsButton:SetPoint("LEFT", self, addonTable.Constants.ButtonFrameOffset + sideSpacing - 2, 0)
    self.DepositReagentsButton:SetPoint("BOTTOM", self, 0, 6)
  else
    self.buttonsWidth = 0
  end

  if self.CurrencyWidget.lastCharacter ~= self.lastCharacter then
    self.CurrencyWidget:UpdateCurrencies(character)
  end

  self.BagSlots:SetPoint("BOTTOMLEFT", self, "TOPLEFT", addonTable.Constants.ButtonFrameOffset, 0)
  self.BagSlots:Update(character, isLive)

  addonTable.Gamepad.LinkButtons(self.ToggleAllCharacters, "Down", self:GetParent().SearchWidget.SearchBox)
  addonTable.Gamepad.LinkButtons(self.ToggleBagSlotsButton, "Down", self:GetParent().SearchWidget.SearchBox)

  if self.BankMissingHint:IsShown() then
    for _, layout in ipairs(self.Container.Layouts) do
      layout:Hide()
    end

    self:SetSize(
      math.max(400, self.BankMissingHint:GetWidth()) + sideSpacing * 2 + addonTable.Constants.ButtonFrameOffset + 40,
      80 + topSpacing / 2
    )

    self.CurrencyWidget:UpdateCurrencyTextPositions(self.BankMissingHint:GetWidth())

    addonTable.CallbackRegistry:TriggerEvent("ViewComplete")

    self:GetParent():OnTabFinished()
  end
end

function BaganatorItemViewCommonBankViewCharacterTabsAsBagsViewMixin:OnFinished(character, isLive)
  if self.BankMissingHint:IsShown() then
    return
  end

  local sideSpacing, topSpacing, searchSpacing = addonTable.Utilities.GetSpacing()

  local buttonPadding = 3

  self:SetSize(10, 10)
  local externalVerticalSpacing = self:GetParent().Tabs[1] and self:GetParent().Tabs[1]:IsShown() and (self:GetParent():GetBottom() - self:GetParent().Tabs[1]:GetBottom() + 5) or 0
  externalVerticalSpacing = externalVerticalSpacing + (self.BagSlots:GetHeight() > 0 and (self.BagSlots:GetTop() - self:GetTop()) or 0)
  local screenHeightSpace = UIParent:GetHeight() / self:GetParent():GetScale() - externalVerticalSpacing
  local spaceOccupied = self.Container:GetHeight() + 50 + searchSpacing + topSpacing / 2 + buttonPadding + self.CurrencyWidget:GetExtraHeight()

  self:SetSize(
    self.Container:GetWidth() + sideSpacing * 2 + addonTable.Constants.ButtonFrameOffset - 2,
    math.min(spaceOccupied, screenHeightSpace)
  )

  self.Container:SetHeight(math.max(self.Container:GetHeight(), self:GetHeight() - spaceOccupied + self.Container:GetHeight()))

  self:UpdateScroll(50 + searchSpacing + topSpacing * 1/4 + externalVerticalSpacing + buttonPadding + self.CurrencyWidget:GetExtraHeight(), self:GetParent():GetScale())
end

function BaganatorItemViewCommonBankViewCharacterTabsAsBagsViewMixin:ToggleBagSlots()
  addonTable.Config.Set(addonTable.Config.Options.BANK_ONLY_VIEW_SHOW_BAG_SLOTS, not addonTable.Config.Get(addonTable.Config.Options.BANK_ONLY_VIEW_SHOW_BAG_SLOTS))
end

if table.freeze then
  table.freeze(BaganatorItemViewCommonBankViewCharacterTabsAsBagsViewMixin)
end
