local AddonName, Engine = ...;

local LibStub = LibStub;
local AceLocale = LibStub:GetLibrary("AceLocale-3.0");
local L = AceLocale:NewLocale(AddonName, "zhCN", false, false);
if not L then return end

-- 译者：枫聖御雷

-- Temporary locales for Midnight Compatibility Warning
L["COMPATIBILITY_WARNING"] = "Midnight Compatibility Warning"
L["COMPATIBILITY_WARNING_MESSAGE"] = "|cffff0000Some features are disabled on Midnight for now due to API restrictions:|r\n\n" ..
                                "|cff8888ff• Mob percentages on nameplates (MDT Integration)|r\n" ..
                                "|cff8888ff• Current pull tracking|r\n" ..
                                "|cff8888ff• Projected values|r\n\n" ..
                                "|cff8888ffThese features will be re-enabled once Blizzard releases the new Mythic+ API. There is currently no ETA for this.|r\n\n" ..
                                "All other features should remain available, sorry for the inconvenience.\n"

-- Dungeons Group
L["DUNGEONS"] = "当前赛季"
L["CURRENT_SEASON"] = "当前赛季"
L["NEXT_SEASON"] = "下个赛季"
L["REMIX"] = "Remix" -- To Translate
L["SEASON_ENDS_IN_ONE_MONTH"] = "Current season ends in less than one month." -- To Translate
L["SEASON_ENDS_IN_WEEKS"] = "Current season ends in less than %d weeks." -- To Translate
L["SEASON_ENDS_IN_DAYS"] = "Current season ends in %d days." -- To Translate
L["SEASON_ENDS_IN_TOMORROW"] = "Current season ends tomorrow." -- To Translate
L["SEASON_STARTS_IN_ONE_MONTH"] = "Next season starts in less than one month." -- To Translate
L["SEASON_STARTS_IN_WEEKS"] = "Next season starts in less than %d weeks." -- To Translate
L["SEASON_STARTS_IN_DAYS"] = "Next season starts in %d days." -- To Translate
L["SEASON_STARTS_IN_TOMORROW"] = "Next season starts tomorrow." -- To Translate

L["EXPANSION_MIDNIGHT"] = "Midnight" -- To Translate
L["EXPANSION_WW"] = "地心之战"
L["EXPANSION_DF"] = "巨龙时代"
L["EXPANSION_SL"] = "暗影国度"
L["EXPANSION_BFA"] = "争霸艾泽拉斯"
L["EXPANSION_LEGION"] = "军团再临"
L["EXPANSION_WOD"] = "Warlords of Draenor" -- To Translate
L["EXPANSION_CATA"] = "大地的裂变"
L["EXPANSION_WOTLK"] = "Wrath of the Lich King" -- To Translate

-- UI Strings
L["MODULES"] = "Modules" -- To Translate
L["MODULES_SUMMARY_HEADER"] = "Modules overview" -- To Translate
L["MODULES_SUMMARY_DESC"] = "Quick tour of available modules:\n\n• MythicDungeonTools Integration\n  > Mob Percentages\n\n• Group Reminder" -- To Translate
L["FINISHED"] = "地下城进度完成"
L["SECTION_DONE"] = "区域完成"
L["DONE"] = "区域进度完成"
L["DUNGEON_DONE"] = "地下城完成"
L["OPTIONS"] = "选项"
L["GENERAL_SETTINGS"] = "通用设置"
L["Changelog"] = "更新日志"
L["Version"] = "版本"
L["Important"] = "重要"
L["New"] = "新内容"
L["Bugfixes"] = "错误修复"
L["Improvment"] = "改进"
L["%month%-%day%-%year%"] = "%年%-%月%-%日%"
L["DEFAULT_PERCENTAGES"] = "默认进度百分比"
L["DEFAULT_PERCENTAGES_DESC"] = "This view shows the addon's built-in defaults and does not reflect your custom routes configuration." -- To Translate
L["ROUTES_DISCLAIMER"] = "By default, Keystone Polaris uses Raider.IO Weekly Routes (Beginner). Custom routes let you define your own different routes. To enable these routes, make sure to enable \"Custom routes\" in the addon's General Settings." -- To Translate
L["ADVANCED_SETTINGS"] = "自定义路线"
L["TANK_GROUP_HEADER"] = "首领进度百分比"
L["ROLES_ENABLED"] = "启用角色"
L["ROLES_ENABLED_DESC"] = "选择哪些角色会看到进度百分比并向团队通报"
L["LEADER"] = "队长"
L["TANK"] = "坦克"
L["HEALER"] = "治疗者"
L["DPS"] = "伤害输出者"
L["ENABLE"] = "Enable"
L["ENABLE_ADVANCED_OPTIONS"] = "启用自定义路线"
L["ADVANCED_OPTIONS_DESC"] = "这将允许你为每个首领之前设置自定义进度百分比目标，并选择是否在缺少进度时通知团队"
L["INFORM_GROUP"] = "通知团队"
L["INFORM_GROUP_DESC"] = "当缺少进度时向聊天频道发送消息"
L["SHOW_INFORM_GROUP_BUTTON"] = "Inform Group Button" -- TODO: To Translate
L["SHOW_INFORM_GROUP_BUTTON_DESC"] = "Show the Inform Group button on the addon's display" -- TODO: To Translate
L["MESSAGE_CHANNEL"] = "聊天频道"
L["MESSAGE_CHANNEL_DESC"] = "选择用于通知的聊天频道"
L["PARTY"] = "队伍"
L["SAY"] = "说"
L["YELL"] = "大喊"
L["PERCENTAGE"] = "百分比"
L["PERCENTAGE_DESC"] = "调整文本大小"
L["FONT"] = "字体"
L["FONT_SIZE"] = "字体大小"
L["FONT_SIZE_DESC"] = "调整文本大小"
L["POSITIONING"] = "位置调整"
L["COLORS"] = "颜色"
L["IN_PROGRESS"] = "进行中"
L["MISSING"] = "缺少"
L["FINISHED_COLOR"] = "Done" -- To Translate
L["VALIDATE"] = "确定"
L["CANCEL"] = "取消"
L["POSITION"] = "位置"
L["TOP"] = "上"
L["CENTER"] = "中"
L["BOTTOM"] = "下"
L["X_OFFSET"] = "水平位置"
L["Y_OFFSET"] = "垂直位置"
L["SHOW_ANCHOR"] = "显示定位锚点"
L["ANCHOR_TEXT"] = "< KPL 移动锚点 >"
L["RESET_DUNGEON"] = "重置为默认"
L["RESET_DUNGEON_DESC"] = "将此地下城中所有首领的进度百分比重置为其默认"
L["RESET_DUNGEON_CONFIRM"] = "你确定要将此地下城中所有首领的进度百分比重置为默认吗？"
L["RESET_ALL_DUNGEONS"] = "重置所有地下城"
L["RESET_ALL_DUNGEONS_DESC"] = "将所有地下城重置为其默认值"
L["RESET_ALL_DUNGEONS_CONFIRM"] = "你确定要将所有地下城重置为默认吗？"
L["NEW_SEASON_RESET_PROMPT"] = "新的大秘境赛季已开始。是否要将所有地下城值重置为默认？"
L["YES"] = "是"
L["NO"] = "否"
L["WE_STILL_NEED"] = "我们还需要"
L["NEW_ROUTES_RESET_PROMPT"] = "此版本中默认的地下城路线已更新。是否要将你当前的地下城路线重置为新的路线？"
L["RESET_ALL"] = "重置所有地下城"
L["RESET_CHANGED_ONLY"] = "仅重置有变化的"
L["CHANGED_ROUTES_DUNGEONS_LIST"] = "以下地下城有更新的路线："
L["BOSS"] = "Boss" -- To Translate
L["BOSS_ORDER"] = "Boss Order" -- To Translate
L["SHOW_COMPARTMENT_ICON"] = "Compartment icon" -- To Translate
L["SHOW_MINIMAP_ICON"] = "Minimap icon" -- To Translate
L["NEW_ROUTES_ALL_SEASON_PROMPT"] = "All dungeon routes for the current season have been updated. Do you want to reset all values to the new defaults?" -- TODO: To Translate

-- Commands / Help (To Translate)
L["COMMANDS_HEADER"] = "Commands"
L["COMMANDS_HELP_DESC"] = "Available slash commands:\n• /kpl or /polaris - Open options\n• /kpl reminder or /polaris reminder - Show last group reminder\n• /kpl help or /polaris help - Show this help"
L["COMMANDS_HELP_OPEN"] = "/kpl or /polaris - Open options"
L["COMMANDS_HELP_CHANGELOG"] = "/kpl changelog or /polaris changelog - Open changelog"
L["COMMANDS_HELP_REMINDER"] = "/kpl reminder or /polaris reminder - Show last group reminder"
L["COMMANDS_HELP_HELP"] = "/kpl help or /polaris help - Show this help"

-- Changelog
L["COPY_INSTRUCTIONS"] = "Select All, then Ctrl+C to copy. Optional: DeepL https://www.deepl.com/translator"
L["SELECT_ALL"] = "Select All"
L["TRANSLATE"] = "Translate"
L["TRANSLATE_DESC"] = "Copy this changelog in a popup to paste into your translator."

-- Test Mode
L["TEST_MODE"] = "Test Mode"
L["TEST_MODE_OVERLAY"] = "Keystone Polaris: Test Mode"
L["TEST_MODE_OVERLAY_HINT"] = "Preview is simulated. Right-click this hint to exit test mode and reopen settings."
L["TEST_MODE_DESC"] = "Show a live preview of your display configuration without being in a dungeon. This will:\n• Close the settings panel to reveal the preview\n• Show a dim overlay and a hint above the display\n• Simulate combat/out-of-combat every 3s to reveal projected values and pull%\nTip: Right-click the hint to exit Test Mode and reopen settings."
L["TEST_MODE_DISABLED"] = "Test Mode disabled automatically%s"
L["TEST_MODE_REASON_ENTERED_COMBAT"] = "entered combat"
L["TEST_MODE_REASON_STARTED_DUNGEON"] = "started dungeon"
L["TEST_MODE_REASON_CHANGED_ZONE"] = "changed zone"

-- Main Display
L["MAIN_DISPLAY"] = "Main Display"
L["SHOW_REQUIRED_PREFIX"] = "Show required text prefix"
L["SHOW_REQUIRED_PREFIX_DESC"] = "When the base value is numeric (e.g., 12.34%), prefix it with a label (e.g., 'Required:'). No prefix is added for DONE/SECTION/DUNGEON states."
L["LABEL"] = "Prefix"
L["REQUIRED_LABEL_DESC"] = "Label displayed before the numeric required percentage (e.g., 'Required: 12.34%').\n\nClear the field to reset to the default value."
L["SHOW_CURRENT_PERCENT"] = "Show current %"
L["SHOW_CURRENT_PERCENT_DESC"] = "Display the current overall enemy forces percent (from the scenario tracker)."
L["CURRENT_LABEL_DESC"] = "Label displayed before the current percentage value.\n\nClear the field to reset to the default value."
L["SHOW_CURRENT_PULL_PERCENT"] = "Show current pull % (MDT)"
L["SHOW_CURRENT_PULL_PERCENT_DESC"] = "Display the real current pull percent based on engaged mobs using MDT data."
L["PULL_LABEL_DESC"] = "Label displayed before the current pull percentage value.\n\nClear the field to reset to the default value."
L["USE_MULTI_LINE_LAYOUT"] = "Use multi-line layout"
L["USE_MULTI_LINE_LAYOUT_DESC"] = "Show each selected value on a new line."
L["SHOW_PROJECTED"] = "Show projected values"
L["SHOW_PROJECTED_DESC"] = "Append projected values: Current shows (Current + Pull). Required shows (Required - Pull)."
L["SINGLE_LINE_SEPARATOR"] = "Single-line separator"
L["SINGLE_LINE_SEPARATOR_DESC"] = "Separator used between items when not using multi-line layout."
L["FONT_ALIGN"] = "Font align"
L["FONT_ALIGN_DESC"] = "Horizontal alignment for the display text."
L["PREFIX_COLOR"] = "Prefixes color"
L["PREFIX_COLOR_DESC"] = "Color applied to labels/prefixes (Required, Current, Pull)."
L["MAX_WIDTH"] = "Max width (single-line)"
L["MAX_WIDTH_DESC"] = "Maximum width in pixels for single-line layout. 0 = automatic (no wrapping)."
L["REQUIRED_DEFAULT"] = "Required:"
L["CURRENT_DEFAULT"] = "Current:"
L["SECTION_REQUIRED_DEFAULT"] = "Total required for section:"
L["PULL_DEFAULT"] = "Pull:"

-- Section required prefix
L["SHOW_SECTION_REQUIRED_PREFIX"] = "Show section required"
L["SHOW_SECTION_REQUIRED_PREFIX_DESC"] = "Display the current overall enemy forces percent required for the current section without taking into account the progress already done."
L["SECTION_REQUIRED_LABEL_DESC"] = "Label displayed before the section required value.\n\nClear the field to reset to the default value."
L["SECTION_REQUIRED_DEFAULT"] = "Total required for section:"

L["FORMAT_MODE"] = "Text format"
L["FORMAT_MODE_DESC"] = "Select how to display the progress."
L["COUNT"] = "Count"

-- Export/Import
L["EXPORT_DUNGEON"] = "导出地下城"
L["EXPORT_DUNGEON_DESC"] = "导出此地下城的自定义百分比"
L["IMPORT_DUNGEON"] = "导入地下城"
L["IMPORT_DUNGEON_DESC"] = "导入此地下城的自定义百分比"
L["EXPORT_ALL_DUNGEONS"] = "导出所有地下城"
L["EXPORT_ALL_DUNGEONS_DESC"] = "导出所有地下城的设置。"
L["EXPORT_ALL_DIALOG_TEXT"] = "复制下面的字符串以分享你所有地下城的自定义百分比："
L["IMPORT_ALL_DUNGEONS"] = "导入所有地下城"
L["IMPORT_ALL_DUNGEONS_DESC"] = "导入所有地下城的设置。"
L["IMPORT_ALL_DIALOG_TEXT"] = "将下面的字符串粘贴以导入所有地下城的自定义百分比："
L["EXPORT_SECTION"] = "导出分组"
L["EXPORT_SECTION_DESC"] = "导出 %s 的所有地下城设置。"
L["EXPORT_SECTION_DIALOG_TEXT"] = "复制下面的字符串以分享你 %s 的自定义百分比："
L["IMPORT_SECTION"] = "导入分组"
L["IMPORT_SECTION_DESC"] = "导入 %s 的所有地下城设置。"
L["IMPORT_SECTION_DIALOG_TEXT"] = "将下面的字符串粘贴以导入 %s 的自定义百分比："
L["EXPORT_DIALOG_TEXT"] = "复制下面的字符串以分享你的自定义百分比："
L["IMPORT_DIALOG_TEXT"] = "将导出的字符串粘贴在下面："
L["IMPORT_SUCCESS"] = "成功导入 %s 的自定义路线。"
L["IMPORT_ALL_SUCCESS"] = "成功导入所有地下城的自定义路线。"
L["IMPORT_ERROR"] = "导入字符串无效"
L["IMPORT_DIFFERENT_DUNGEON"] = "导入了 %s 的设置。正在为该地下城打开选项。"

-- MDT Integration
L["MDT_INTEGRATION_FEATURES"] = "Mythic Dungeon Tools Integration Features"
L["MOB_PERCENTAGES_INFO"] = "• |cff00ff00Mob Percentages|r: Shows enemy forces contribution percentage on nameplates in M+ dungeons."
L["MOB_INDICATOR_INFO"] = "• |cff00ff00Mobs Indicators|r: Marks nameplates to show which enemies are included in your current MDT route pull."

-- Mob Percentages
L["MOB_PERCENTAGES"] = "Mob Percentages"
L["ENABLE_MOB_PERCENTAGES"] = "Enable Mob Percentages"
L["ENABLE_MOB_PERCENTAGES_DESC"] = "Show percentage contribution of each mob in Mythic+ dungeons"
L["MOB_PERCENTAGE_FONT_SIZE"] = "Font Size"
L["MOB_PERCENTAGE_FONT_SIZE_DESC"] = "Set the font size for mob percentage text"
L["MOB_PERCENTAGE_POSITION"] = "Position"
L["MOB_PERCENTAGE_POSITION_DESC"] = "Set the position of the percentage text relative to the nameplate"
L["RIGHT"] = "Right"
L["LEFT"] = "Left"
L["TOP"] = "Top"
L["BOTTOM"] = "Bottom"
L["MDT_WARNING"] = "This feature requires Mythic Dungeon Tools (MDT) addon to be installed."
L["MDT_FOUND"] = "Mythic Dungeon Tools found. Mob percentages will use MDT data."
L["MDT_LOADED"] = "Mythic Dungeon Tools loaded successfully."
L["MDT_NOT_FOUND"] = "Mythic Dungeon Tools not found. Mob percentages will not be shown. Please install MDT for this feature to work."
L["MDT_INTEGRATION"] = "MDT Integration"
L["MDT_SECTION_WARNING"] = "This section requires Mythic Dungeon Tools (MDT) addon to be installed."
L["DISPLAY_OPTIONS"] = "Display Options"
L["APPEARANCE_OPTIONS"] = "Appearance Options"
L["SHOW_PERCENTAGE"] = "Show Percentage"
L["SHOW_PERCENTAGE_DESC"] = "Show the percentage value for each mob"
L["SHOW_COUNT"] = "Show Count"
L["SHOW_COUNT_DESC"] = "Show the count value for each mob"
L["SHOW_TOTAL"] = "Show Total"
L["SHOW_TOTAL_DESC"] = "Show the total count needed for 100%"
L["TEXT_COLOR"] = "Font Color"
L["TEXT_COLOR_DESC"] = "Set the color of the nameplate text"
L["CUSTOM_FORMAT"] = "Text Format"
L["CUSTOM_FORMAT_DESC"] = "Enter a custom format. Use %s for percentage, %c for count, and %t for total. Examples: (%s), %s | %c/%t, %c, etc."
L["RESET_TO_DEFAULT"] = "Reset"
L["RESET_FORMAT_DESC"] = "Reset the text format to the default value (parentheses)"

-- Group Reminder (Popup labels)
L["KPL_GR_HEADER"] = "Group Reminder"
L["KPL_GR_TELEPORT_UNKNOWN"] = "Teleport spell not known"
L["KPL_GR_OPEN_REMINDER"] = "Open reminder"
L["KPL_GR_INVITED"] = "You have been invited to"
L["KPL_GR_AS_ROLE"] = "as a %s"
L["KPL_GR_SHOW_POPUP_WHEN_FULL"] = "Show popup again when the group is full" -- TODO: To Translate
L["KPL_GR_SHOW_POPUP_WHEN_FULL_DESC"] = "Reopen the reminder window when your Mythic+ group reaches 5 players." -- TODO: To Translate
L["KPL_GR_CHAT_COMMAND_INFO"] = "Tip: use |cffffd100/kpl reminder|r to show the last group reminder again." -- TODO: To Translate

-- Group Reminder (Options)
L["KPL_GR_DESC_LONG"] = "Displays a reminder popup and/or chat message when you are accepted into a Mythic+ group, with a button to teleport to the dungeon."
L["KPL_GR_NOTIFICATIONS"] = "Notifications"
L["KPL_GR_SUPPRESS_TOAST"] = "Suppress Blizzard quick-join toast"
L["KPL_GR_SUPPRESS_TOAST_DESC"] = "Hide the default Blizzard popup that appears at the bottom of the screen when invited."
L["KPL_GR_SHOW_POPUP"] = "Show popup"
L["KPL_GR_SHOW_POPUP_DESC"] = "Display the reminder window in the center of the screen."
L["KPL_GR_SHOW_CHAT"] = "Show chat message"
L["KPL_GR_SHOW_CHAT_DESC"] = "Print the reminder details in the chat window."
L["KPL_GR_TEST_CURRENT_SEASON"] = "Simulate current season acceptance"
L["KPL_GR_TEST_CURRENT_SEASON_DESC"] = "Show the group reminder using a dungeon from the current season."
L["KPL_GR_CONTENT"] = "Content"
L["KPL_GR_SHOW_DUNGEON"] = "Show dungeon name"
L["KPL_GR_SHOW_GROUP"] = "Show group name"
L["KPL_GR_SHOW_DESC"] = "Show group description"
L["KPL_GR_SHOW_ROLE"] = "Show applied role"
L["KPL_GR_SHOW_PLAYSTYLE"] = "Show group playstyle" -- TODO: To Translate
