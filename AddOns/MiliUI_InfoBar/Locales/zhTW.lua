-- Traditional Chinese
local L = LibStub("AceLocale-3.0"):NewLocale("MiliUI_InfoBar", "zhTW")
if not L then return end

-- Addon
L["ADDON_NAME"] = "米利的資訊列"
L["BAR_NAME"] = "米利資訊列"

-- Bar labels (short prefixes shown on the bar itself)
L["LABEL_ILVL"] = "裝等"
L["LABEL_DURABILITY"] = "耐久"
L["LABEL_SPEC"] = "天賦"
L["LABEL_LOOTSPEC"] = "擲骰"
L["LABEL_CPU"] = "CPU"
L["LABEL_MEM"] = "記憶體"

-- Menus
L["MENU_LOADOUTS"] = "天賦配置"
L["MENU_NO_LOADOUTS"] = "（沒有已儲存的配置）"
L["MENU_LOOT_TITLE"] = "擲骰天賦"
L["MENU_LOOT_FOLLOW"] = "依目前專精（%s）"
L["MSG_COMBAT_LOADOUT"] = "戰鬥中無法切換天賦配置。"
L["MENU_OPEN_SETTINGS"] = "開啟設定"
L["MENU_HIDE_BUTTON"] = "隱藏「%s」按鈕"

-- Tabs
L["TAB_GENERAL"] = "一般"
L["TAB_BLOCKS"] = "區塊"
L["TAB_MICRO"] = "微型選單"
L["TAB_ABOUT"] = "關於"

-- General tab
L["SECTION_GENERAL"] = "一般"
L["ENABLE_BAR"] = "啟用資訊列"
L["ENABLE_BAR_DESC"] = "一條純色方底的橫列，裝著資訊區塊與微型選單。"
L["BAR_HEIGHT"] = "資訊列高度"
L["FONT_SIZE"] = "字級"
L["BLOCK_GAP"] = "區塊間距"
L["BLOCK_GAP_DESC"] = "0 ＝ 整條融成一長條：沒有間距也沒有隔線，只留最外框。"
L["SECTION_POSITION"] = "位置"
L["DRAG_HINT"] = "開著這個視窗時，直接拖曳資訊列上的遮罩即可移動（右鍵重設位置）；進入編輯模式也能拖。"
L["DRAG_LABEL"] = "拖曳移動"
L["RESET_POSITION"] = "重設位置"
L["MSG_POSITION_RESET"] = "資訊列位置已重設。"

-- Blocks tab
L["BLOCKS_DESC"] = "一顆方塊就是一個區塊。拖曳方塊可以調整順序，拖進「不顯示」（或直接點一下方塊）就能開關；滑過方塊看說明。輪詢類的區塊關著就零成本。"
L["BOARD_SHOWN"] = "顯示中（由左到右）"
L["BOARD_HIDDEN"] = "不顯示"
L["BLOCK_ILVL"] = "裝備等級"
L["BLOCK_ILVL_DESC"] = "裝備中的平均裝等。點擊開啟角色視窗。"
L["BLOCK_DURABILITY"] = "耐久度"
L["BLOCK_DURABILITY_DESC"] = "全身裝備的最低耐久百分比。點擊開啟角色視窗。"
L["BLOCK_MICROMENU"] = "微型選單"
L["BLOCK_MICROMENU_DESC"] = "取代原廠那排的按鈕。點擊會安全轉發給暴雪自己的按鈕，戰鬥中的行為跟原廠完全一致。"
L["BLOCK_SPEC"] = "天賦"
L["BLOCK_SPEC_DESC"] = "顯示啟用中的天賦配置（沒有配置就顯示專精）。左鍵開啟天賦視窗，右鍵切換配置。"
L["BLOCK_LOOTSPEC"] = "擲骰天賦"
L["BLOCK_LOOTSPEC_DESC"] = "點擊切換擲骰天賦——戰鬥中也能換。"
L["BLOCK_GOLD"] = "金幣"
L["BLOCK_CLOCK"] = "時間"
L["BLOCK_FPS"] = "畫面更新率"
L["BLOCK_MS"] = "延遲"
L["BLOCK_CPU"] = "插件 CPU"
L["BLOCK_CPU_DESC"] = "插件最近的每幀耗時，讀內建分析器（讀值免費）。裝有 MiliUI 本體時，點擊直接開啟效能監控。"
L["BLOCK_MEM"] = "Lua 記憶體"
L["BLOCK_MEM_DESC"] = "Lua 記憶體總量。只讀計數器——絕不觸發昂貴的逐插件記憶體掃描。裝有 MiliUI 本體時，點擊直接開啟效能監控。"
L["PERF_CLICK_HINT"] = "點擊開啟效能監控"
L["BLOCK_LOCATION"] = "所在地區"

-- Micro Menu tab
L["SECTION_MICRO_STYLE"] = "風格"
L["ICON_STYLE"] = "圖示風格"
L["ICON_STYLE_MONO"] = "單色"
L["ICON_STYLE_BLIZZARD"] = "官方彩色"
L["ICON_STYLE_DESC"] = "單色＝把官方圖示去飽和，滑過時染上職業色；官方彩色＝保留原本的圖。"
L["HIDE_BLIZZARD"] = "隱藏暴雪微型選單"
L["HIDE_BLIZZARD_DESC"] = "用安全機制隱藏原廠那排（不會造成污染）。編輯模式中它可能暫時出現，離開時會自動再藏起來。"
L["SECTION_MICRO_BUTTONS"] = "按鈕"
L["MICRO_BUTTONS_DESC"] = "選擇要在資訊列上顯示哪些按鈕。在資訊列上右鍵任一顆按鈕，也能開啟這頁或隱藏那顆按鈕。"

-- About
L["SETTINGS_MAIN_DESC"] = "純色方底的資訊列，整合微型選單：裝等、耐久、天賦、擲骰天賦、效能等等。"
L["ABOUT_SLASH"] = "指令：/mib 或 /miliinfobar"
L["ABOUT_AUTHOR"] = "作者：米利"

-- Blizzard options entry
L["OPEN_HINT"] = "輸入 /mib 開啟設定"
L["VERSION_FORMAT"] = "版本：%s"
L["BTN_OPEN_OPTIONS"] = "開啟設定"

-- MiliUIWidgets shared-layer contract (exactly these four keys)
L["Apply"]  = "套用"
L["Okay"]   = "確定"
L["Cancel"] = "取消"
L["Can't change settings during combat"] = "戰鬥中無法更改設定"
