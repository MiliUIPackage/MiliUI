---@class addonTableBaganator
local addonTable = select(2, ...)

function addonTable.Skins.IsAddOnLoading(name)
  local character = UnitGUID("player")
  if C_AddOns.GetAddOnEnableState(name, character) ~= Enum.AddOnEnableState.All or not C_AddOns.IsAddOnLoadable(name) then
    return false
  end
  for _, dep in ipairs({C_AddOns.GetAddOnDependencies(name)}) do
    if not addonTable.Skins.IsAddOnLoading(dep) then
      return false
    end
  end
  return true
end

function addonTable.Skins.ImmediateLoadingTrigger(callback)
  callback()
end

function addonTable.Skins.PlayerLoginLoadingTrigger(callback)
  local frame = CreateFrame("Frame")
  frame:RegisterEvent("PLAYER_LOGIN")
  frame:SetScript("OnEvent", function()
    frame:UnregisterEvent("PLAYER_LOGIN")
    callback()
  end)
end
