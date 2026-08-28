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
L["CONTEXT_SHARED"]      = "shared (not split)"
L["SETTINGS_CURRENT_CONTEXT"] = "Active memory: %s"

L["MACRO_HELP"]          = "Put this one line in your burst macro."
L["BTN_RESET_POS"]       = "Reset bar position"

L["COPY_HINT"]           = "Press Ctrl+C to copy, then Ctrl+V into your macro."

-- Quality / variant labels

-- Messages

-- Bar tooltips

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
