local _, addon = ...
local L = addon.L

StaticPopupDialogs['ASTRAL_KEYS_REFRESH_CONFIRM_DIALOG'] = {
  text = L["Are you sure you want to refresh all key data?"],
  button1 = YES,
  button2 = NO,
  OnAccept = function(self, data, data2)
    local refresh = addon.RefreshData()
    if refresh then
      addon.UpdateFrames()
      StaticPopup_Show('ASTRAL_KEYS_REFRESH_SUCCESS_DIALOG')
    else
      StaticPopup_Show('ASTRAL_KEYS_REFRESH_FAILURE_DIALOG')
    end
  end,
  OnCancel = function()
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
}

StaticPopupDialogs['ASTRAL_KEYS_REFRESH_SUCCESS_DIALOG'] = {
  text = L["Refreshed key data."],
  button1 = OKAY,
  OnAccept = function()
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
}

StaticPopupDialogs['ASTRAL_KEYS_REFRESH_FAILURE_DIALOG'] = {
  text = L["You need to wait more than 30 seconds before refreshing again."],
  button1 = OKAY,
  OnAccept = function()
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
}