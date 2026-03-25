-- 简体中文
local L = LibStub("AceLocale-3.0"):NewLocale("MiliUI_BloodlustMusic", "zhCN")
if not L then return end

-- Addon
L["ADDON_NAME"] = "MiliUI 嗜血音乐"
L["ADDON_TITLE"] = "嗜血/英勇倒计时条"
L["LOADED_MSG"] = "|cff00ff00MiliUI 嗜血音乐:|r 已加载 — /blm 打开设置"

-- Settings Categories
L["SETTINGS_MAIN"] = "嗜血音乐"
L["SETTINGS_MUSIC"] = "音乐设置"
L["SETTINGS_BAR"] = "倒计时条"
L["SETTINGS_MAIN_DESC"] = "嗜血/英勇音乐播放与倒计时条"
L["SELECT_SUBCATEGORY"] = "请从左侧选择子类别："
L["MUSIC_DESC"] = "音乐播放、曲目选择、声道"
L["BAR_DESC"] = "倒计时条外观与位置"

-- Music Settings
L["MUSIC_SETTINGS_TITLE"] = "音乐设置"
L["MUSIC_SETTINGS_DESC"] = "设置嗜血音乐播放选项"
L["ENABLE_MUSIC"] = "启用音乐"
L["ENABLE_MUSIC_DESC"] = "检测到嗜血时播放音乐"
L["PLAY_MODE"] = "播放模式"
L["PLAY_MODE_RANDOM"] = "随机播放"
L["PLAY_MODE_SEQUENTIAL"] = "顺序播放"
L["PLAY_MODE_DESC"] = "在随机播放与顺序播放之间切换"
L["CHANNEL"] = "声道"
L["CHANNEL_DESC"] = "选择音乐播放的声道"
L["CHANNEL_MASTER_DESC"] = "使用主音量控制。即使关闭音乐或音效也能听到嗜血音乐。"
L["CHANNEL_SFX_DESC"] = "使用音效音量控制。嗜血音乐音量会跟随音效滑杆调整。"
L["PREVIEW"] = "试听"
L["STOP_PREVIEW"] = "停止"
L["TRACK_ENABLED"] = "启用"

-- Bar Settings
L["BAR_SETTINGS_TITLE"] = "倒计时条设置"
L["BAR_SETTINGS_DESC"] = "设置嗜血倒计时条的外观与位置"
L["ENABLE_BAR"] = "启用倒计时条"
L["ENABLE_BAR_DESC"] = "嗜血作用中时显示倒计时条"
L["BAR_WIDTH"] = "宽度"
L["BAR_HEIGHT"] = "高度"
L["RESET_POSITION"] = "重置位置"
L["RESET_POSITION_DESC"] = "将倒计时条移回默认位置"
L["TEST_BAR"] = "测试倒计时条"
L["TEST_BAR_DESC"] = "显示测试用倒计时条"
L["HIDE_BAR"] = "隐藏倒计时条"

-- Messages
L["MSG_MUSIC_PLAYING"] = "|cff00ff00嗜血音乐:|r 正在播放: %s"
L["MSG_POSITION_RESET"] = "|cff00ff00嗜血音乐:|r 倒计时条位置已重置"
