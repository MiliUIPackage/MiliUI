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
L["OPT_SPLIT_CONTEXT"]   = "Remember the choice per environment"

-- Per-environment memory contexts
L["CONTEXT_WORLD"]       = "World"
L["CONTEXT_PARTY"]       = "M+ / Dungeon"
L["CONTEXT_RAID"]        = "Raid"
L["CONTEXT_PVP"]         = "Battleground"
L["CONTEXT_ARENA"]       = "Arena"
L["CONTEXT_SCENARIO"]    = "Delve / Ritual"
L["CONTEXT_SHARED"]      = "shared (not split)"
L["CONTEXT_NO_POTION"]   = "no potion"
L["SETTINGS_CURRENT_CONTEXT"] = "Active memory: %s"
L["MSG_CONTEXT_APPLIED"] = "entered %s — applied its potion memory: |cff33ff33%s|r"
L["TIP_CONTEXT"]         = "Memory: |cff33ff33%s|r"

L["MACRO_HELP"]          = "Put this one line in your burst macro."
L["BTN_RESET_POS"]       = "Reset bar position"

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

-- MiliUIWidgets 共用層（元件庫只查這四個 key，見 Libs/MiliUIWidgets/README.md）
L["Apply"]               = "Apply"
L["Okay"]                = "Okay"
L["Cancel"]              = "Cancel"
L["Can't change settings during combat"] = "Can't change settings during combat"

-- Options window
L["TAB_GENERAL"]         = "General"
L["TAB_ABOUT"]           = "About"
L["SECTION_CONTEXT"]     = "Per-environment memory"
L["OPT_SPLIT_CONTEXT_DESC"] = "World, battleground, arena, M+, raid and delve each keep their own potion. Turn it off and every environment shares one choice."
L["ADD_FIELD_ID"]        = "Item ID"
L["BTN_SELECT_ALL"]      = "Select all"
L["MACRO_LABEL"]         = "Macro line"
L["VERSION_FORMAT"]      = "Version: %s"
L["OPEN_HINT"]           = "Use /mbh to open options"
L["BTN_OPEN_OPTIONS"]    = "Open options"
L["ABOUT_MACRO"]         = "Bind %s in your burst macro; the bar only decides which potion that macro drinks."
L["ABOUT_COMBAT"]        = "Switching works in combat: the click runs inside Blizzard's secure environment, so nothing is tainted and your macro is never edited."
L["ABOUT_SLASH"]         = "Commands: |cffffd200/mbh|r opens the options, |cffffd200/mbh reset|r puts the bar back to its default position."
L["ABOUT_AUTHOR"]        = "Author: Mili (MiliUI package)"
