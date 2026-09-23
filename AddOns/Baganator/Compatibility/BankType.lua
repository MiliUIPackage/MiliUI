local _, addonTable = ...

function Addon_SetBankType(type)
end

function Addon_GetBankType()
  local bankFrame = addonTable.ViewManagement.GetBankFrame()
	return bankFrame and bankFrame:GetBankType() or 0
end
