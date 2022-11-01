AuctionatorPanelConfigMixin = {}

function AuctionatorPanelConfigMixin:SetupPanel()
  self.cancel = function()
    self:Cancel()
  end

  self.okay = function()
    self:Save()
  end

  InterfaceOptions_AddCategory(self, "拍賣小助手")
end

function AuctionatorPanelConfigMixin:IndentationForSubSection()
  return "   "
end

-- Derive
function AuctionatorPanelConfigMixin:Cancel()
  Auctionator.Debug.Message("AuctionatorPanelConfigMixin:Cancel() Unimplemented")
end

-- Derive
function AuctionatorPanelConfigMixin:Save()
  Auctionator.Debug.Message("AuctionatorPanelConfigMixin:Save() Unimplemented")
end
