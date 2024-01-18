--[[
	Abstract class with utility methods for managing tooltips.
  All Rights Reserved
--]]

local ADDON, Addon = ...
local Tipped = Addon.Parented:NewClass('Tipped')

function Tipped:OnLeave()
  if GameTooltip:IsOwned(self) then
    GameTooltip:Hide()
  end

  if BattlePetTooltip then
    BattlePetTooltip:Hide()
  end
end

function Tipped:GetTipAnchor()
  return self, self:IsFarLeft() and 'ANCHOR_LEFT' or 'ANCHOR_RIGHT'
end

function Tipped:IsFarLeft()
  return self:GetRight() > (GetScreenWidth() / 2)
end