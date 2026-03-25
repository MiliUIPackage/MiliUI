-- 繁體中文
local L = LibStub("AceLocale-3.0"):NewLocale("MiliUI_BloodlustMusic", "zhTW")
if not L then return end

-- Addon
L["ADDON_NAME"] = "MiliUI 嗜血音樂"
L["ADDON_TITLE"] = "嗜血/英勇倒數條"
L["LOADED_MSG"] = "|cff00ff00MiliUI 嗜血音樂:|r 已載入 — /blm 開啟設定"

-- Settings Categories
L["SETTINGS_MAIN"] = "嗜血音樂"
L["SETTINGS_MUSIC"] = "音樂設定"
L["SETTINGS_BAR"] = "倒數條"
L["SETTINGS_MAIN_DESC"] = "嗜血/英勇音樂播放與倒數條"
L["SELECT_SUBCATEGORY"] = "請選擇左側子選單進行設定："
L["MUSIC_DESC"] = "音樂播放、曲目選擇、聲道"
L["BAR_DESC"] = "倒數條外觀與位置"

-- Music Settings
L["MUSIC_SETTINGS_TITLE"] = "音樂設定"
L["MUSIC_SETTINGS_DESC"] = "設定嗜血音樂播放選項"
L["ENABLE_MUSIC"] = "啟用音樂"
L["ENABLE_MUSIC_DESC"] = "偵測到嗜血時播放音樂"
L["PLAY_MODE"] = "播放模式"
L["PLAY_MODE_RANDOM"] = "隨機播放"
L["PLAY_MODE_SEQUENTIAL"] = "依序播放"
L["PLAY_MODE_DESC"] = "在隨機播放與依序播放之間切換"
L["CHANNEL"] = "聲道"
L["CHANNEL_DESC"] = "選擇音樂播放的聲道"
L["CHANNEL_MASTER_DESC"] = "使用主音量控制。即使關閉音樂或音效也能聽到嗜血音樂。"
L["CHANNEL_SFX_DESC"] = "使用音效音量控制。嗜血音樂音量會跟隨音效滑桿調整。"
L["PREVIEW"] = "試聽"
L["STOP_PREVIEW"] = "停止"
L["TRACK_ENABLED"] = "啟用"

-- Bar Settings
L["BAR_SETTINGS_TITLE"] = "倒數條設定"
L["BAR_SETTINGS_DESC"] = "設定嗜血倒數條的外觀與位置"
L["ENABLE_BAR"] = "啟用倒數條"
L["ENABLE_BAR_DESC"] = "嗜血作用中時顯示倒數條"
L["BAR_WIDTH"] = "寬度"
L["BAR_HEIGHT"] = "高度"
L["RESET_POSITION"] = "重置位置"
L["RESET_POSITION_DESC"] = "將倒數條移回預設位置"
L["TEST_BAR"] = "測試倒數條"
L["TEST_BAR_DESC"] = "顯示測試用倒數條"
L["HIDE_BAR"] = "隱藏倒數條"

-- Messages
L["MSG_MUSIC_PLAYING"] = "|cff00ff00嗜血音樂:|r 正在播放: %s"
L["MSG_POSITION_RESET"] = "|cff00ff00嗜血音樂:|r 倒數條位置已重置"
