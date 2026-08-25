-- 繁體中文
local L = LibStub("AceLocale-3.0"):NewLocale("MiliUI_ChatBar", "zhTW")
if not L then return end

-- Addon Name
L["ADDON_NAME"] = "米利的快捷聊天列"
L["ADDON_TITLE"] = "快捷聊天列"

-- Settings Categories
L["SETTINGS_CHANNELS"] = "頻道設定"
L["SETTINGS_MAIN_DESC"] = "快捷聊天列插件設定"

-- Main Panel

-- General Settings
L["GENERAL_SETTINGS_TITLE"] = "一般設定"
L["LOCK_UNLOCK"] = "鎖定/解鎖"
L["LOCK_UNLOCK_DESC"] = "切換是否可以拖曳移動聊天列"
L["RESET_POSITION"] = "重置位置"
L["RESET_POSITION_DESC"] = "將聊天列移回預設位置"
L["FONT_SIZE"] = "字體大小"
L["BUTTON_WIDTH"] = "按鈕寬度"
L["BUTTON_HEIGHT"] = "按鈕高度"
L["RESET_ALL"] = "重置所有設定"
L["RESET_ALL_DESC"] = "將所有設定恢復預設值"
L["CONFIRM_RESET_ALL"] = "確定要重置所有設定嗎？"

-- Channel Settings
L["CHANNEL_SETTINGS_TITLE"] = "頻道設定"
L["CHANNEL_SETTINGS_DESC"] = "顯示或隱藏個別頻道按鈕"

-- Context Menu
L["CONTEXT_OPEN_SETTINGS"] = "開啟設定"

-- Messages
L["MSG_LOCKED"] = "|cff00ff00米利的快捷聊天列:|r 已鎖定"
L["MSG_UNLOCKED"] = "|cff00ff00米利的快捷聊天列:|r 已解鎖"
L["MSG_RESET"] = "|cff00ff00米利的快捷聊天列:|r 位置已重置"

-- Channel Names
L["CHANNEL_SAY"] = "說"
L["CHANNEL_YELL"] = "喊"
L["CHANNEL_PARTY"] = "隊伍"
L["CHANNEL_INSTANCE"] = "副本"
L["CHANNEL_RAID"] = "團隊"
L["CHANNEL_RAID_WARNING"] = "團隊警告"
L["CHANNEL_GUILD"] = "公會"
L["CHANNEL_WHISPER"] = "密語"
L["CHANNEL_EMOTE"] = "表情"
L["CHANNEL_ROLL"] = "骰子"
L["CHANNEL_DBM"] = "DBM 開怪"
L["CHANNEL_RESET"] = "重置副本"
L["CHANNEL_COMBATLOG"] = "戰鬥記錄"

-- Short Labels (Button Text)
L["SHORT_SAY"] = "說"
L["SHORT_YELL"] = "喊"
L["SHORT_PARTY"] = "隊"
L["SHORT_INSTANCE"] = "副"
L["SHORT_RAID"] = "團"
L["SHORT_GUILD"] = "公"
L["SHORT_WHISPER"] = "密"
L["SHORT_ROLL"] = "骰"
L["SHORT_DBM"] = "開"
L["SHORT_RESET"] = "重"

-- Tooltips
L["TIP_DBM"] = "左鍵:確認 | 中鍵:倒數5秒 | 右鍵:倒數10秒"
L["TIP_DBM_FORMAT"] = "左鍵:確認 | 中鍵:倒數5秒 | 右鍵:倒數%d秒"
L["TIP_RESET"] = "左鍵:重置副本 | 右鍵:戰鬥記錄"

-- Pull Timer (native countdown)
L["DBM_PULL_SECONDS"] = "開怪倒數秒數"
L["DBM_PULL_SECONDS_DESC"] = "設定開怪倒數秒數（右鍵）"

-- MiliUIWidgets 共用層（元件庫只查這四個 key）
L["Apply"]  = "套用"
L["Okay"]   = "確定"
L["Cancel"] = "取消"
L["Can't change settings during combat"] = "戰鬥中無法調整設定"

-- 設定視窗
L["TAB_GENERAL"]       = "一般"
L["TAB_ABOUT"]         = "關於"
L["ORIENTATION"]       = "排列方向"
L["ORIENT_HORIZONTAL"] = "橫向"
L["ORIENT_VERTICAL"]   = "直向"
L["SECTION_SIZE"]      = "尺寸"
L["SECTION_RESET"]     = "重置"
L["VERSION_FORMAT"]    = "版本：%s"
L["OPEN_HINT"]         = "輸入 /mchatbar 開啟設定"
L["BTN_OPEN_OPTIONS"]  = "開啟設定"
L["ABOUT_USAGE"]       = "點一格色塊就切到那個聊天頻道。解鎖後可以拖曳移動，右鍵聊天列會跳出快捷選單。"
L["ABOUT_TAB"]         = "指令：|cffffd200/mchatbar|r 開啟設定，|cffffd200/mchatbar reset|r 把聊天列放回預設位置。"
L["ABOUT_AUTHOR"]      = "作者：米利（米利UI套組）"
-- 磁吸與自適應寬度
L["MENU_LOCK"]              = "鎖定聊天列"
L["GROUP_WITH_CHAT"]        = "聊天列與聊天視窗同組"
L["GROUP_WITH_CHAT_DESC"]   = "聊天列吸附在聊天視窗上，聊天視窗被拖動或改變大小時跟著走。拖曳時按住 Shift 放開就不吸附。"
L["MATCH_CHAT_WIDTH"]       = "總寬度對齊聊天視窗"
L["MATCH_CHAT_WIDTH_DESC"]  = "僅橫向排列：聊天列的總寬度跟聊天視窗一樣寬。"
L["AUTO_BUTTON_WIDTH"]      = "按鈕寬度自適應"
L["AUTO_BUTTON_WIDTH_DESC"] = "把總寬度平分給看得到的按鈕，此時「按鈕寬度」由程式決定、不能調整。"
