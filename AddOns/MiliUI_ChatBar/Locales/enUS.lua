-- English (Default Locale)
local L = LibStub("AceLocale-3.0"):NewLocale("MiliUI_ChatBar", "enUS", true)

-- Addon Name
L["ADDON_NAME"] = "MiliUI ChatBar"
L["ADDON_TITLE"] = "Quick Chat Bar"

-- Settings Categories
L["SETTINGS_CHANNELS"] = "Channel Settings"
L["SETTINGS_MAIN_DESC"] = "Quick chat bar addon settings"

-- Main Panel

-- General Settings
L["GENERAL_SETTINGS_TITLE"] = "General Settings"
L["LOCK_UNLOCK"] = "Lock/Unlock"
L["LOCK_UNLOCK_DESC"] = "Toggle whether the chat bar can be dragged"
L["RESET_POSITION"] = "Reset Position"
L["RESET_POSITION_DESC"] = "Reset chat bar to default position"
L["FONT_SIZE"] = "Font Size"
L["BUTTON_WIDTH"] = "Button Width"
L["BUTTON_HEIGHT"] = "Button Height"
L["RESET_ALL"] = "Reset All Settings"
L["RESET_ALL_DESC"] = "Reset all settings to default"
L["CONFIRM_RESET_ALL"] = "Are you sure you want to reset all settings?"

-- Channel Settings
L["CHANNEL_SETTINGS_TITLE"] = "Channel Settings"
L["CHANNEL_SETTINGS_DESC"] = "Show or hide individual channel buttons"

-- Context Menu
L["CONTEXT_OPEN_SETTINGS"] = "Open Settings"

-- Messages
L["MSG_LOCKED"] = "|cff00ff00MiliUI ChatBar:|r Locked"
L["MSG_UNLOCKED"] = "|cff00ff00MiliUI ChatBar:|r Unlocked"
L["MSG_RESET"] = "|cff00ff00MiliUI ChatBar:|r Position reset"

-- Channel Names
L["CHANNEL_SAY"] = "Say"
L["CHANNEL_YELL"] = "Yell"
L["CHANNEL_PARTY"] = "Party"
L["CHANNEL_INSTANCE"] = "Instance"
L["CHANNEL_RAID"] = "Raid"
L["CHANNEL_RAID_WARNING"] = "Raid Warning"
L["CHANNEL_GUILD"] = "Guild"
L["CHANNEL_WHISPER"] = "Whisper"
L["CHANNEL_EMOTE"] = "Emote"
L["CHANNEL_ROLL"] = "Roll"
L["CHANNEL_DBM"] = "DBM Pull"
L["CHANNEL_RESET"] = "Reset Instances"
L["CHANNEL_COMBATLOG"] = "Combat Log"

-- Short Labels (Button Text)
L["SHORT_SAY"] = "S"
L["SHORT_YELL"] = "Y"
L["SHORT_PARTY"] = "P"
L["SHORT_INSTANCE"] = "I"
L["SHORT_RAID"] = "R"
L["SHORT_GUILD"] = "G"
L["SHORT_WHISPER"] = "W"
L["SHORT_ROLL"] = "Rl"
L["SHORT_DBM"] = "Pl"
L["SHORT_RESET"] = "Rs"

-- Tooltips
L["TIP_DBM"] = "Left: Confirm | Middle: Pull 5s | Right: Pull 10s"
L["TIP_DBM_FORMAT"] = "Left: Confirm | Middle: Pull 5s | Right: Pull %ds"
L["TIP_RESET"] = "Left: Reset Instance | Right: Combat Log"

-- Pull Timer (native countdown)
L["DBM_PULL_SECONDS"] = "Pull Countdown Seconds"
L["DBM_PULL_SECONDS_DESC"] = "Set the countdown seconds for the pull timer (right-click)"

-- MiliUIWidgets 共用層（元件庫只查這四個 key，見 Libs/MiliUIWidgets/README.md）
L["Apply"]  = "Apply"
L["Okay"]   = "Okay"
L["Cancel"] = "Cancel"
L["Can't change settings during combat"] = "Can't change settings during combat"

-- Options window
L["TAB_GENERAL"]       = "General"
L["TAB_ABOUT"]         = "About"
L["ORIENTATION"]       = "Orientation"
L["ORIENT_HORIZONTAL"] = "Horizontal"
L["ORIENT_VERTICAL"]   = "Vertical"
L["SECTION_SIZE"]      = "Size"
L["SECTION_RESET"]     = "Reset"
L["VERSION_FORMAT"]    = "Version: %s"
L["OPEN_HINT"]         = "Use /mchatbar to open options"
L["BTN_OPEN_OPTIONS"]  = "Open options"
L["ABOUT_USAGE"]       = "Click a block to switch your chat channel. Drag the bar by its left edge when it is unlocked, or right-click it for a quick menu."
L["ABOUT_TAB"]         = "Commands: |cffffd200/mchatbar|r opens the options, |cffffd200/mchatbar reset|r puts the bar back to its default position."
L["ABOUT_AUTHOR"]      = "Author: Mili (MiliUI package)"
-- Anchoring / adaptive width
L["MENU_LOCK"]              = "Lock the bar"
L["GROUP_WITH_CHAT"]        = "Group with chat window"
L["GROUP_WITH_CHAT_DESC"]   = "Snap the bar to the chat window and keep it there when the chat window is moved or resized. Hold Shift while dropping the bar to place it freely."
L["MATCH_CHAT_WIDTH"]       = "Match chat window width"
L["MATCH_CHAT_WIDTH_DESC"]  = "Horizontal layout only: the bar is exactly as wide as the chat window."
L["AUTO_BUTTON_WIDTH"]      = "Auto button width"
L["AUTO_BUTTON_WIDTH_DESC"] = "Split that width evenly between the visible buttons. Button Width is then computed for you."
