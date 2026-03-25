-- English (Default Locale)
local L = LibStub("AceLocale-3.0"):NewLocale("MiliUI_BloodlustMusic", "enUS", true)

-- Addon
L["ADDON_NAME"] = "MiliUI BloodlustMusic"
L["ADDON_TITLE"] = "Bloodlust / Heroism Countdown"
L["LOADED_MSG"] = "|cff00ff00MiliUI BloodlustMusic:|r loaded — /blm to configure"

-- Settings Categories
L["SETTINGS_MAIN"] = "Bloodlust Music"
L["SETTINGS_MUSIC"] = "Music Settings"
L["SETTINGS_BAR"] = "Countdown Bar"
L["SETTINGS_MAIN_DESC"] = "Bloodlust music playback and countdown bar"
L["SELECT_SUBCATEGORY"] = "Please select a subcategory from the left:"
L["MUSIC_DESC"] = "Music playback, track selection, channel"
L["BAR_DESC"] = "Countdown bar appearance and position"

-- Music Settings
L["MUSIC_SETTINGS_TITLE"] = "Music Settings"
L["MUSIC_SETTINGS_DESC"] = "Configure bloodlust music playback"
L["ENABLE_MUSIC"] = "Enable Music"
L["ENABLE_MUSIC_DESC"] = "Play music when bloodlust is detected"
L["PLAY_MODE"] = "Play Mode"
L["PLAY_MODE_RANDOM"] = "Random"
L["PLAY_MODE_SEQUENTIAL"] = "Sequential"
L["PLAY_MODE_DESC"] = "Switch between random and sequential playback"
L["CHANNEL"] = "Audio Channel"
L["CHANNEL_DESC"] = "Select the audio channel for music playback"
L["CHANNEL_MASTER_DESC"] = "Controlled by Master Volume. Always audible even if Music/SFX is muted."
L["CHANNEL_SFX_DESC"] = "Controlled by Sound Effects volume. Bloodlust music volume follows your SFX slider."
L["PREVIEW"] = "Preview"
L["STOP_PREVIEW"] = "Stop"
L["TRACK_ENABLED"] = "Enabled"

-- Bar Settings
L["BAR_SETTINGS_TITLE"] = "Countdown Bar Settings"
L["BAR_SETTINGS_DESC"] = "Configure the bloodlust countdown bar"
L["ENABLE_BAR"] = "Enable Countdown Bar"
L["ENABLE_BAR_DESC"] = "Show countdown bar when bloodlust is active"
L["BAR_WIDTH"] = "Bar Width"
L["BAR_HEIGHT"] = "Bar Height"
L["RESET_POSITION"] = "Reset Position"
L["RESET_POSITION_DESC"] = "Reset countdown bar to default position"
L["TEST_BAR"] = "Test Bar"
L["TEST_BAR_DESC"] = "Show a test countdown bar"
L["HIDE_BAR"] = "Hide Bar"

-- Messages
L["MSG_MUSIC_PLAYING"] = "|cff00ff00BloodlustMusic:|r Now playing: %s"
L["MSG_POSITION_RESET"] = "|cff00ff00BloodlustMusic:|r Bar position reset"
