-- 简体中文
local L = LibStub("AceLocale-3.0"):NewLocale("MiliUI_ChatBar", "zhCN")
if not L then return end

-- Addon Name
L["ADDON_NAME"] = "米利的快捷聊天栏"
L["ADDON_TITLE"] = "快捷聊天栏"

-- Settings Categories
L["SETTINGS_CHANNELS"] = "频道设置"
L["SETTINGS_MAIN_DESC"] = "快捷聊天栏插件设置"

-- Main Panel

-- General Settings
L["GENERAL_SETTINGS_TITLE"] = "常规设置"
L["LOCK_UNLOCK"] = "锁定/解锁"
L["LOCK_UNLOCK_DESC"] = "切换是否可以拖拽移动聊天栏"
L["RESET_POSITION"] = "重置位置"
L["RESET_POSITION_DESC"] = "将聊天栏移回默认位置"
L["FONT_SIZE"] = "字体大小"
L["BUTTON_WIDTH"] = "按钮宽度"
L["BUTTON_HEIGHT"] = "按钮高度"
L["RESET_ALL"] = "重置所有设置"
L["RESET_ALL_DESC"] = "将所有设置恢复默认值"
L["CONFIRM_RESET_ALL"] = "确定要重置所有设置吗？"

-- Channel Settings
L["CHANNEL_SETTINGS_TITLE"] = "频道设置"
L["CHANNEL_SETTINGS_DESC"] = "显示或隐藏各个频道按钮"

-- Context Menu
L["CONTEXT_LOCK_UNLOCK"] = "锁定/解锁"
L["CONTEXT_RESET_POSITION"] = "重置位置"
L["CONTEXT_TOGGLE_ORIENTATION"] = "切换方向"
L["CONTEXT_OPEN_SETTINGS"] = "打开设置"

-- Messages
L["MSG_LOCKED"] = "|cff00ff00米利的快捷聊天栏:|r 已锁定"
L["MSG_UNLOCKED"] = "|cff00ff00米利的快捷聊天栏:|r 已解锁"
L["MSG_RESET"] = "|cff00ff00米利的快捷聊天栏:|r 位置已重置"

-- Channel Names
L["CHANNEL_SAY"] = "说"
L["CHANNEL_YELL"] = "喊"
L["CHANNEL_PARTY"] = "队伍"
L["CHANNEL_INSTANCE"] = "副本"
L["CHANNEL_RAID"] = "团队"
L["CHANNEL_RAID_WARNING"] = "团队警告"
L["CHANNEL_GUILD"] = "公会"
L["CHANNEL_WHISPER"] = "密语"
L["CHANNEL_EMOTE"] = "表情"
L["CHANNEL_ROLL"] = "骰子"
L["CHANNEL_DBM"] = "DBM 开怪"
L["CHANNEL_RESET"] = "重置副本"
L["CHANNEL_COMBATLOG"] = "战斗记录"

-- Short Labels (Button Text)
L["SHORT_SAY"] = "说"
L["SHORT_YELL"] = "喊"
L["SHORT_PARTY"] = "队"
L["SHORT_INSTANCE"] = "副"
L["SHORT_RAID"] = "团"
L["SHORT_GUILD"] = "公"
L["SHORT_WHISPER"] = "密"
L["SHORT_ROLL"] = "骰"
L["SHORT_DBM"] = "开"
L["SHORT_RESET"] = "重"

-- Tooltips
L["TIP_DBM"] = "左键:确认 | 中键:倒数5秒 | 右键:倒数10秒"
L["TIP_DBM_FORMAT"] = "左键:确认 | 中键:倒数5秒 | 右键:倒数%d秒"
L["TIP_RESET"] = "左键:重置副本 | 右键:战斗记录"

-- Pull Timer (native countdown)
L["DBM_PULL_SECONDS"] = "开怪倒数秒数"
L["DBM_PULL_SECONDS_DESC"] = "设置开怪倒数秒数（右键）"

-- MiliUIWidgets 共用层（组件库只查这四个 key）
L["Apply"]  = "应用"
L["Okay"]   = "确定"
L["Cancel"] = "取消"
L["Can't change settings during combat"] = "战斗中无法调整设置"

-- 设置窗口
L["TAB_GENERAL"]       = "常规"
L["TAB_ABOUT"]         = "关于"
L["ORIENTATION"]       = "排列方向"
L["ORIENT_HORIZONTAL"] = "横向"
L["ORIENT_VERTICAL"]   = "竖向"
L["SECTION_SIZE"]      = "尺寸"
L["SECTION_RESET"]     = "重置"
L["VERSION_FORMAT"]    = "版本：%s"
L["OPEN_HINT"]         = "输入 /mchatbar 打开设置"
L["BTN_OPEN_OPTIONS"]  = "打开设置"
L["ABOUT_USAGE"]       = "点一格色块就切到那个聊天频道。解锁后可以拖动，右键聊天栏会弹出快捷菜单。"
L["ABOUT_TAB"]         = "命令：|cffffd200/mchatbar|r 打开设置，|cffffd200/mchatbar reset|r 把聊天栏放回左下角。"
L["ABOUT_AUTHOR"]      = "作者：米利（米利UI套组）"
