---@class addonTableChattynator
local addonTable = select(2, ...)

function addonTable.CustomiseDialog.ImportData(import, name, overwrite)
  local previousSkin = addonTable.Config.CurrentProfile[addonTable.Config.Options.CURRENT_SKIN]
  if import.addon ~= "Chattynator" then
    return false, 1
  end

  if name:match("^_") then
    return false, 2
  end

  import.addon = nil
  import.version = nil
  import.kind = nil
  if overwrite and CHATTYNATOR_CONFIG.Profiles[name] then
    local old = addonTable.Config.CurrentProfile
    CHATTYNATOR_CONFIG.Profiles[name] = import
    if import.style and not import.designs[import.style] then
      import.style = import.designs_assigned["enemy"]
    end
    addonTable.Config.ChangeProfile(name, old)
  else
    if CHATTYNATOR_CONFIG.Profiles[name] then
      return false, 4
    end
    addonTable.Config.MakeProfile(name, false)
    local old = addonTable.Config.CurrentProfile
    CHATTYNATOR_CONFIG.Profiles[CHATTYNATOR_CURRENT_PROFILE] = import
    if import.style and not import.designs[import.style] then
      import.style = import.designs_assigned["enemy"]
    end
    addonTable.Config.ChangeProfile(CHATTYNATOR_CURRENT_PROFILE, old)
  end

  if addonTable.Config.CurrentProfile[addonTable.Config.Options.CURRENT_SKIN] ~= previousSkin then
    addonTable.Dialogs.ShowConfirm(addonTable.Locales.RELOAD_REQUIRED, YES, NO, function() ReloadUI() end)
  end

  return true
end
