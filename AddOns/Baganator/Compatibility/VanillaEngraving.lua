-- Needed to keep rune information updated for equipment sets and item button
-- icons
if C_Engraving and C_Engraving.IsEngravingEnabled() then
  local frame = CreateFrame("Frame")
  frame:RegisterEvent("PLAYER_LOGIN")
  frame:RegisterEvent("ENGRAVING_MODE_CHANGED")
  frame:RegisterEvent("RUNE_UPDATED")
  frame:SetScript("OnEvent", function()
    local start = debugprofilestop()
    C_Engraving.RefreshRunesList()
    if Baganator.Config.Get(Baganator.Config.Options.DEBUG_TIMERS) then
      print("refreshruneslist", debugprofilestop() - start)
    end
  end)
end
