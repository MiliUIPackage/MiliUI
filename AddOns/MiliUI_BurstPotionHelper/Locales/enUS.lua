-- English (Default Locale)
local L = LibStub("AceLocale-3.0"):NewLocale("MiliUI_BurstPotionHelper", "enUS", true)
if not L then return end

L["ADDON_NAME"]          = "MiliUI Burst Potion Helper"

-- Settings panel
L["SETTINGS_TITLE"]      = "Burst Potion Helper"
L["SETTINGS_DESC"]       = "Switch your burst potion and quality from a small bar, then drink it with the macro below."
L["SECTION_GENERAL"]     = "Options"
L["SECTION_MACRO"]       = "Burst macro"
L["SECTION_LIST"]        = "Potion list"

L["LIST_DESC"]           = "Manage which potions appear on the bar. Built-in potions can be disabled or deleted, and you can add your own. Potions added as new defaults in a future update will show up here automatically."
L["BTN_ADD_ITEM"]        = "Add potion"
L["BTN_RESTORE_DEFAULTS"] = "Restore defaults"
L["LABEL_CUSTOM"]        = "custom"
L["ADD_TITLE"]           = "Add a potion"
L["ADD_HINT"]            = "Type an item ID, or Shift-click an item in your bags / chat to fill it in."
L["ADD_INVALID"]         = "Invalid item ID."
L["ADD_EXISTS"]          = "That potion is already in the list."

L["OPT_PRINT"]           = "Announce in chat when switching potion"
L["OPT_SHOW_BAR"]        = "Show the potion switch bar"
L["OPT_LOCK_BAR"]        = "Lock the bar position"
L["OPT_RIGHTCLICK"]      = "Right-click an icon to use that potion immediately"
L["OPT_SHOW_CD"]         = "Show potion cooldown on the icons"
L["OPT_ITEM_TOOLTIP"]    = "Show item info in the tooltip"

L["MACRO_HELP"]          = "Put this one line in your burst macro."
L["BTN_COPY_MACRO"]      = "Copy macro command"
L["BTN_RESET_POS"]       = "Reset bar position"

L["COPY_TITLE"]          = "Copy macro command"
L["COPY_HINT"]           = "Press Ctrl+C to copy, then Ctrl+V into your macro."

-- Quality / variant labels
L["LABEL_FLEETING"]      = "Fleeting"
L["LABEL_T3"]            = "High quality"
L["LABEL_T2"]            = "Medium quality"
L["LABEL_T1"]            = "Normal quality"

-- Messages
L["MSG_LOADED"]          = "loaded. Bind |cff33ff33%s|r in your burst macro; click a potion on the bar to switch quickly."
L["MSG_SWITCHED"]        = "switched to |cff33ff33%s|r x%d"
L["MSG_SWITCHED_Q"]      = "switched to |cff33ff33%s (%s)|r x%d"
L["MSG_DISABLED"]        = "burst potion disabled — the macro won't drink anything."
L["MSG_NO_POTION"]       = "no burst potions found in your bags."
L["MSG_COLLAPSE_COMBAT"] = "can't collapse/expand in combat — it will apply when you leave combat."

-- Bar tooltips
L["TIP_DRAG"]            = "Drag to move"
L["TIP_LOCKED"]          = "Locked"
L["TIP_COLLAPSE"]        = "Left-click: collapse / expand"
L["TIP_SETTINGS"]        = "Right-click for settings"
L["TIP_SELECT"]          = "Left-click: select this potion"
L["TIP_USE"]             = "Right-click: use this potion"
L["TIP_NONE"]            = "Left-click: use no potion"
