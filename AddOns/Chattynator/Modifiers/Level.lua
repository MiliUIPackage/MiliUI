---@class addonTableChattynator
local addonTable = select(2, ...)

local playerPattern = "(|Hplayer:[^|]+|h%[?)(|?c?)([^|]-)(|?r?)(%]?|h)"
local function Level(data)
  if data.typeInfo.player and data.typeInfo.player.level then
    data.text = data.text:gsub(playerPattern, function(x1, x2, x3, x4, x5)
      if x2 == "|c" then
        return x1 .. x2 .. x3:gsub("([fF][fF]%x%x%x%x%x%x)", "%1" .. data.typeInfo.player.level .. ":") .. x4 .. x5
      else
        return x1 .. x2 .. x3, data.typeInfo.player.level .. x4 .. x5
      end
    end, 1)
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
