-- 繁體中文
local L = LibStub("AceLocale-3.0"):NewLocale("MiliUI_ChatBar", "zhTW")
if not L then return end

-- Addon Name
L["ADDON_NAME"] = "MiliUI 快捷聊天列"
L["ADDON_TITLE"] = "快捷聊天列"

-- Settings Categories
L["SETTINGS_MAIN"] = "快捷聊天列"
L["SETTINGS_GENERAL"] = "一般設定"
L["SETTINGS_CHANNELS"] = "頻道設定"
L["SETTINGS_MAIN_DESC"] = "快捷聊天列插件設定"

-- Main Panel
L["SELECT_SUBCATEGORY"] = "請選擇左側子選單進行設定："
L["GENERAL_DESC"] = "鎖定、位置、方向"
L["CHANNELS_DESC"] = "顯示/隱藏頻道按鈕"

-- General Settings
L["GENERAL_SETTINGS_TITLE"] = "一般設定"
L["GENERAL_SETTINGS_DESC"] = "設定快捷聊天列的外觀與位置"
L["LOCK_UNLOCK"] = "鎖定/解鎖"
L["LOCK_UNLOCK_DESC"] = "切換是否可以拖曳移動聊天列"
L["RESET_POSITION"] = "重置位置"
L["RESET_POSITION_DESC"] = "將聊天列移回預設位置"
L["TOGGLE_ORIENTATION"] = "切換垂直/水平"
L["TOGGLE_ORIENTATION_DESC"] = "在垂直與水平佈局之間切換"

-- Channel Settings
L["CHANNEL_SETTINGS_TITLE"] = "頻道設定"
L["CHANNEL_SETTINGS_DESC"] = "顯示或隱藏個別頻道按鈕"

-- Context Menu
L["CONTEXT_LOCK_UNLOCK"] = "鎖定/解鎖"
L["CONTEXT_RESET_POSITION"] = "重置位置"
L["CONTEXT_TOGGLE_ORIENTATION"] = "切換方向"
L["CONTEXT_OPEN_SETTINGS"] = "開啟設定"

-- Messages
L["MSG_LOCKED"] = "|cff00ff00MiliUI 快捷聊天列:|r 已鎖定"
L["MSG_UNLOCKED"] = "|cff00ff00MiliUI 快捷聊天列:|r 已解鎖"
L["MSG_RESET"] = "|cff00ff00MiliUI 快捷聊天列:|r 位置已重置"
L["MSG_HORIZONTAL"] = "|cff00ff00MiliUI 快捷聊天列:|r 水平模式"
L["MSG_VERTICAL"] = "|cff00ff00MiliUI 快捷聊天列:|r 垂直模式"

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
L["TIP_RESET"] = "左鍵:重置副本 | 中鍵:戰鬥記錄 | 右鍵:重載介面"

-- Dialogs
L["CONFIRM_RELOAD"] = "確定要重新載入介面嗎？"



