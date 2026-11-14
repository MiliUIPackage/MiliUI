---@class addonTableBaganator
local addonTable = select(2, ...)

local levels = {}

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LEVEL_UP")

local skillLineEvent = "SKILL_LINES_CHANGED"
if addonTable.Constants.IsForever then
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  frame:RegisterEvent(skillLineEvent)
end

frame:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_ENTERING_WORLD" or event == skillLineEvent then
    local changes = false

    local professions = {GetProfessions()}
    for _, profIndex in pairs(professions) do
      local _, _, skillLevel = GetProfessionInfo(profIndex)
      if levels[profIndex] ~= skillLevel then
        levels[profIndex] = skillLevel
        if event == skillLineEvent and skillLevel%5 == 0 then
          changes = true
        end
      end
    end

    if changes and addonTable.Config.Get("icon_mark_unusable") then
      Baganator.API.RequestItemButtonsRefresh({Baganator.Constants.RefreshReason.ItemWidgets})
    end

  else
    if addonTable.Config.Get("icon_mark_unusable") then
      Baganator.API.RequestItemButtonsRefresh({Baganator.Constants.RefreshReason.ItemWidgets})
    end
  end
end)
