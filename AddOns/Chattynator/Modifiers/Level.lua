---@class addonTableChattynator
local addonTable = select(2, ...)

local playerPattern = "(|Hplayer:[^|]+|h%[?)(|?)([^|]-)(|?r?)(%]?|h)"
local function Level(data)
  if data.typeInfo.player and data.typeInfo.player.level then
    data.text = data.text:gsub(playerPattern, "%1%2%3 (" .. data.typeInfo.player.level .. ")%4|r%5")
  end
end

function addonTable.Modifiers.InitializeLevels()
  if not addonTable.Constants.IsMidnightNext and not addonTable.Constants.IsForever then
    return
  end

  if addonTable.Config.Get(addonTable.Config.Options.SHOW_LEVEL) then
    addonTable.Messages:AddLiveModifier(Level)
  end
  addonTable.CallbackRegistry:RegisterCallback("SettingChanged", function(_, settingName)
    if settingName == addonTable.Config.Options.SHOW_LEVEL then
      if addonTable.Config.Get(addonTable.Config.Options.SHOW_LEVEL) then
        addonTable.Messages:AddLiveModifier(Level)
      else
        addonTable.Messages:RemoveLiveModifier(Level)
      end
    end
  end)
end
