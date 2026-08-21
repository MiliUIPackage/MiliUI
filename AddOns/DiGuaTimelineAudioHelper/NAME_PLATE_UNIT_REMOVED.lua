local addonName, addonTable = ...

local f = CreateFrame("Frame")
f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

f:SetScript("OnEvent", function(self, event, unit)
    if unit then
        if addonTable.SpellCastCounter then addonTable.SpellCastCounter[unit] = nil end
        if addonTable.SpellCastStartTime then addonTable.SpellCastStartTime[unit] = nil end
        if addonTable.SpellChannelStart then addonTable.SpellChannelStart[unit] = nil end
        if addonTable.SpellCastSuccessTriggered then addonTable.SpellCastSuccessTriggered[unit] = nil end
        if addonTable.SpellChannelCounter then addonTable.SpellChannelCounter[unit] = nil end
        if addonTable.UnitAbsorbAmountChanged then addonTable.UnitAbsorbAmountChanged[unit] = nil end
        
    end
end)