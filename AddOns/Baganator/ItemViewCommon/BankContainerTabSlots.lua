---@class addonTableBaganator
local addonTable = select(2, ...)

addonTable.ItemViewCommon.BankContainerTabSlotsMixin = {}

function addonTable.ItemViewCommon.BankContainerTabSlotsMixin:OnLoad()
  self.buyPool = CreateFramePool("ItemButton", self, "BaganatorRetailCachedItemButtonTemplate,BankPanelPurchaseButtonScriptTemplate", nil, false, function(button)
    button:UpdateTextures()
    button:SetItemDetails({})
    button.SlotBackground:SetVertexColor(1, 0, 0)
    button:HookScript("OnClick", function()
      PlaySound(SOUNDKIT.IG_MAINMENU_OPTION);
    end)
    button:SetScript("OnEnter", function()
      GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
      GameTooltip:SetText(LINK_FONT_COLOR:WrapTextInColorCode(addonTable.Locales.BUY_BANK_BAG_SLOT))
      local cost = C_Bank.FetchNextPurchasableBankTabData(self.purchaseKind).tabCost
      if cost > GetMoney() then
        GameTooltip:AddLine(addonTable.Locales.COST_X:format(RED_FONT_COLOR:WrapTextInColorCode(addonTable.Utilities.GetMoneyString(cost, true))))
      else
        GameTooltip:AddLine(addonTable.Locales.COST_X:format(WHITE_FONT_COLOR:WrapTextInColorCode(addonTable.Utilities.GetMoneyString(cost, true))))
      end
      GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
  end, math.max(#Syndicator.Constants.AllBankIndexes, #Syndicator.Constants.AllWarbandIndexes))

  self.cachedPool = CreateFramePool("ItemButton", self, "BaganatorRetailCachedItemButtonTemplate", nil, false, function(button)
    button:UpdateTextures()
  end)
  self.livePool = CreateFramePool("ItemButton", self, "BaganatorRetailLiveContainerItemButtonTemplate", nil, false, function(button)
    button:UpdateTextures()
  end)

  Syndicator.CallbackRegistry:RegisterCallback("BagCacheUpdate",  function(_, character, updatedBags)
    addonTable.ReportEntry()
    if updatedBags.containerBags == nil or updatedBags.containerBags.bank then
      if self:IsVisible() then
        self:Update(character, self.isLive)
      end
    end
  end)
end

function addonTable.ItemViewCommon.BankContainerTabSlotsMixin:SetMode(mode)
  self.mode = mode

  if mode == "characterBank" then
    self.purchaseKind = Enum.BankType.Character
    self:SetID(Enum.BagIndex.Characterbanktab)
    self.config = addonTable.Config.Options.BANK_ONLY_VIEW_SHOW_BAG_SLOTS
    self.indexes = Syndicator.Constants.AllBankIndexes
  elseif mode == "warbandBank" then
    self.purchaseKind = Enum.BankType.Account
    self:SetID(Enum.BagIndex.Accountbanktab)
    self.config = addonTable.Config.Options.BANK_ONLY_VIEW_SHOW_BAG_SLOTS
    self.indexes = Syndicator.Constants.AllWarbandIndexes
  end
end

function addonTable.ItemViewCommon.BankContainerTabSlotsMixin:Update(character, isLive)
  self.isLive = isLive

  local containerInfo = Syndicator.API.GetCharacter(character).containerInfo

  if not containerInfo or not containerInfo[self.mode] then
    self:Hide()
    return
  end
  self:Show()

  self.cachedPool:ReleaseAll()
  self.livePool:ReleaseAll()
  self.buyPool:ReleaseAll()

  local anyShown = false
  local showLive = isLive and addonTable.Config.Get(self.config)
  local lastSlot
  if isLive then
    for index = 2, math.min(#containerInfo[self.mode] + 1, C_Bank.FetchMaxNumBankTabs(self.purchaseKind)) do
      local info = containerInfo[self.mode][index]
      anyShown = showLive
      local slot
      if info then
        slot = self.livePool:Acquire()
        slot:SetID(index)
        slot:SetItemDetails(info)
        slot:SetItemButtonCount(C_Container.GetContainerNumFreeSlots(self.indexes[index]))
        slot.extendedFrame:Hide()
        slot:EnableMouse(true)
      else
        slot = self.buyPool:Acquire()
        slot:SetAttribute("overrideBankType", self.purchaseKind)
      end
      slot:Show()

      if lastSlot then
        slot:SetPoint("TOPLEFT", lastSlot, "TOPRIGHT")
      else
        slot:SetPoint("BOTTOMLEFT")
      end
      lastSlot = slot
    end
  end

  -- Show cached bag slots when viewing cached bags for other characters
  if not isLive then
    local showCached = addonTable.Config.Get(self.config)
    for index = 2, #containerInfo[self.mode] do
      local info = containerInfo[self.mode][index]
      anyShown = showCached
      local details = CopyTable(info or {})
      if info.itemID then
        details.itemCount = addonTable.Utilities.CountEmptySlots(Syndicator.API.GetCharacter(character).bankTabs[index].slots)
      end

      local slot = self.cachedPool:Acquire()
      if lastSlot then
        slot:SetPoint("TOPLEFT", lastSlot, "TOPRIGHT")
      else
        slot:SetPoint("BOTTOMLEFT")
      end
      slot:Show()
      slot:SetItemDetails(details)
      lastSlot = slot
    end
  end

  self:SetHeight(anyShown and 39 or 0)
end
