-- English (Default Locale)
local L = LibStub("AceLocale-3.0"):NewLocale("MiliUI_InfoBar", "enUS", true)

-- Addon
L["ADDON_NAME"] = "MiliUI InfoBar"
L["BAR_NAME"] = "MiliUI InfoBar"

-- Bar labels (short prefixes shown on the bar itself)
L["LABEL_ILVL"] = "iLvl"
L["LABEL_DURABILITY"] = "Dura"
L["LABEL_SPEC"] = "Spec"
L["LABEL_LOOTSPEC"] = "Loot"
L["LABEL_CPU"] = "CPU"
L["LABEL_MEM"] = "Mem"

-- Menus
L["MENU_LOADOUTS"] = "Talent loadouts"
L["MENU_NO_LOADOUTS"] = "(no saved loadouts)"
L["MENU_LOOT_TITLE"] = "Loot specialization"
L["MENU_LOOT_FOLLOW"] = "Current specialization (%s)"
L["MSG_COMBAT_LOADOUT"] = "Can't switch talent loadouts in combat."
L["MENU_OPEN_SETTINGS"] = "Open settings"
L["MENU_HIDE_BUTTON"] = "Hide the %s button"

-- Tabs
L["TAB_GENERAL"] = "General"
L["TAB_BLOCKS"] = "Blocks"
L["TAB_MICRO"] = "Micro Menu"
L["TAB_ABOUT"] = "About"

-- General tab
L["SECTION_GENERAL"] = "General"
L["ENABLE_BAR"] = "Enable info bar"
L["ENABLE_BAR_DESC"] = "A flat one-row bar holding info blocks and the micro menu."
L["BAR_HEIGHT"] = "Bar height"
L["FONT_SIZE"] = "Font size"
L["BLOCK_GAP"] = "Block spacing"
L["BLOCK_GAP_DESC"] = "At 0 the bar fuses into one solid strip — no gaps and no divider lines, only the outer border."
L["SECTION_POSITION"] = "Position"
L["DRAG_HINT"] = "While this window is open, drag the overlay on the bar to move it (right-click resets). Edit Mode dragging works too."
L["DRAG_LABEL"] = "Drag to move"
L["RESET_POSITION"] = "Reset position"
L["MSG_POSITION_RESET"] = "Bar position has been reset."

-- Blocks tab
L["BLOCKS_DESC"] = "Each chip is one block. Drag chips to reorder them, drag into Hidden (or just click a chip) to toggle. Hover a chip for details. Polling blocks cost nothing while hidden."
L["BOARD_SHOWN"] = "Shown (left to right)"
L["BOARD_HIDDEN"] = "Hidden"
L["BLOCK_ILVL"] = "Item level"
L["BLOCK_ILVL_DESC"] = "Average equipped item level. Click to open the character panel."
L["BLOCK_DURABILITY"] = "Durability"
L["BLOCK_DURABILITY_DESC"] = "Lowest durability percentage across equipped items. Click to open the character panel."
L["BLOCK_MICROMENU"] = "Micro menu"
L["BLOCK_MICROMENU_DESC"] = "Replacement micro menu buttons. Clicks pass through to Blizzard's own buttons, so combat behavior is identical to the default UI."
L["BLOCK_SPEC"] = "Talents"
L["BLOCK_SPEC_DESC"] = "Shows the active talent loadout (or spec). Left-click opens talents; right-click switches loadouts."
L["BLOCK_LOOTSPEC"] = "Loot specialization"
L["BLOCK_LOOTSPEC_DESC"] = "Click to switch loot specialization — works in combat."
L["BLOCK_GOLD"] = "Gold"
L["BLOCK_CLOCK"] = "Clock"
L["BLOCK_FPS"] = "FPS"
L["BLOCK_MS"] = "Latency"
L["BLOCK_CPU"] = "Addon CPU"
L["BLOCK_CPU_DESC"] = "Recent per-frame time spent in addons, read from the built-in profiler (reading it is free). With MiliUI installed, click to open the performance monitor."
L["BLOCK_MEM"] = "Lua memory"
L["BLOCK_MEM_DESC"] = "Total Lua memory. Reads a counter only — never triggers the expensive per-addon memory scan. With MiliUI installed, click to open the performance monitor."
L["PERF_CLICK_HINT"] = "Click to open the performance monitor"
L["BLOCK_LOCATION"] = "Location"

-- Micro Menu tab
L["SECTION_MICRO_STYLE"] = "Style"
L["ICON_STYLE"] = "Icon style"
L["ICON_STYLE_MONO"] = "Monochrome"
L["ICON_STYLE_BLIZZARD"] = "Blizzard colors"
L["ICON_STYLE_DESC"] = "Monochrome desaturates Blizzard's icons and tints them on hover with your class color; Blizzard colors keeps the original art."
L["HIDE_BLIZZARD"] = "Hide Blizzard's micro menu"
L["HIDE_BLIZZARD_DESC"] = "Hides the default row via a secure handler (safe against taint). It may reappear inside Edit Mode and is re-hidden on exit."
L["SECTION_MICRO_BUTTONS"] = "Buttons"
L["MICRO_BUTTONS_DESC"] = "Choose which buttons appear on the bar. Right-clicking a button on the bar opens this page or hides that button."

-- About
L["SETTINGS_MAIN_DESC"] = "A flat info bar that replaces the micro menu: item level, durability, talents, loot spec, performance and more."
L["ABOUT_SLASH"] = "Commands: /mib or /miliinfobar"
L["ABOUT_AUTHOR"] = "Author: Mili"

-- Blizzard options entry
L["OPEN_HINT"] = "Use /mib to open options"
L["VERSION_FORMAT"] = "Version: %s"
L["BTN_OPEN_OPTIONS"] = "Open options"

-- MiliUIWidgets shared-layer contract (exactly these four keys)
L["Apply"]  = "Apply"
L["Okay"]   = "Okay"
L["Cancel"] = "Cancel"
L["Can't change settings during combat"] = "Can't change settings during combat"
