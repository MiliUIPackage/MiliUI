-- 简体中文
local L = LibStub("AceLocale-3.0"):NewLocale("MiliUI_BurstPotionHelper", "zhCN")
if not L then return end

L["ADDON_NAME"]          = "米利的爆发药水助手"
L["SETTINGS_TITLE"]      = "米利的爆发药水助手"
L["SETTINGS_DESC"]       = "用一个小条切换你的爆发药水与品质，再用下方的宏喝下。"
L["SECTION_GENERAL"]     = "功能"
L["SECTION_MACRO"]       = "爆发宏"
L["SECTION_LIST"]        = "药水清单"

L["LIST_DESC"]           = "管理切换条要出现哪些药水。默认药水可停用或删除,也能自行新增。我之后改版新增的默认药水会自动出现在这里。"
L["BTN_ADD_ITEM"]        = "新增药水"
L["BTN_RESTORE_DEFAULTS"] = "恢复默认"
L["LABEL_CUSTOM"]        = "自定"
L["ADD_TITLE"]           = "新增药水"
L["ADD_HINT"]            = "输入物品 ID,或 Shift 点背包/聊天里的物品链接带入。"
L["ADD_INVALID"]         = "无效的物品 ID。"
L["ADD_EXISTS"]          = "这个药水已经在清单里了。"

L["OPT_PRINT"]           = "切换药水时在聊天框提示"
L["OPT_SHOW_BAR"]        = "显示药水切换条"
L["OPT_LOCK_BAR"]        = "锁定切换条位置（禁止拖动）"
L["OPT_RIGHTCLICK"]      = "右键图标直接使用该爆发药水"
L["OPT_SHOW_CD"]         = "在图标上显示药水冷却时间"
L["OPT_ITEM_TOOLTIP"]    = "鼠标悬停时显示道具信息"
L["OPT_SPLIT_CONTEXT"]   = "依环境分开记忆药水选择"

-- 分环境记忆
L["CONTEXT_WORLD"]       = "世界"
L["CONTEXT_PARTY"]       = "M+/地下城"
L["CONTEXT_RAID"]        = "团队"
L["CONTEXT_PVP"]         = "战场"
L["CONTEXT_ARENA"]       = "竞技场"
L["CONTEXT_SCENARIO"]    = "探索/仪式"
L["CONTEXT_SHARED"]      = "共用（未分开）"
L["CONTEXT_NO_POTION"]   = "不使用药水"
L["SETTINGS_CURRENT_CONTEXT"] = "当前套用的记忆：%s"
L["MSG_CONTEXT_APPLIED"] = "进入%s，已套用该环境的药水记忆：|cff33ff33%s|r"
L["TIP_CONTEXT"]         = "当前记忆：|cff33ff33%s|r"

L["MACRO_HELP"]          = "把这一行放进你的爆发宏即可。"
L["BTN_RESET_POS"]       = "重置切换条位置"

L["COPY_HINT"]           = "按 Ctrl+C 复制，再用 Ctrl+V 粘进宏里。"

L["LABEL_FLEETING"]      = "飞逝"
L["LABEL_T3"]            = "高品质"
L["LABEL_T2"]            = "中品质"
L["LABEL_T1"]            = "一般品质"

L["MSG_LOADED"]          = "已加载。把 |cff33ff33%s|r 放进你的爆发宏，点击切换条上的药水可快速切换药水。"
L["MSG_SWITCHED"]        = "已切换至 |cff33ff33%s|r x%d"
L["MSG_SWITCHED_Q"]      = "已切换至 |cff33ff33%s（%s）|r x%d"
L["MSG_DISABLED"]        = "已停用爆发药（宏不会喝药）"
L["MSG_NO_POTION"]       = "背包里找不到爆发药水。"
L["MSG_COLLAPSE_COMBAT"] = "战斗中无法即时收合/展开，将于离开战斗后套用。"

L["TIP_DRAG"]            = "拖动以移动"
L["TIP_LOCKED"]          = "已锁定"
L["TIP_COLLAPSE"]        = "左键：收合/展开"
L["TIP_SETTINGS"]        = "右键打开设置"
L["TIP_SELECT"]          = "左键：选择此药水"
L["TIP_USE"]             = "右键：直接使用此药水"
L["TIP_NONE"]            = "左键：不使用药水"

-- MiliUIWidgets 共用层（组件库只查这四个 key）
L["Apply"]               = "应用"
L["Okay"]                = "确定"
L["Cancel"]              = "取消"
L["Can't change settings during combat"] = "战斗中无法调整设置"

-- 设置窗口
L["TAB_GENERAL"]         = "常规"
L["TAB_ABOUT"]           = "关于"
L["SECTION_CONTEXT"]     = "分环境记忆"
L["OPT_SPLIT_CONTEXT_DESC"] = "世界、战场、竞技场、M+、团队、探秘各记一份；关掉就全部共用同一个选择。"
L["ADD_FIELD_ID"]        = "物品 ID"
L["BTN_SELECT_ALL"]      = "全选"
L["MACRO_LABEL"]         = "宏命令"
L["VERSION_FORMAT"]      = "版本：%s"
L["OPEN_HINT"]           = "输入 /mbh 打开设置"
L["BTN_OPEN_OPTIONS"]    = "打开设置"
L["ABOUT_MACRO"]         = "把 %s 绑进你的爆发宏；切换条只负责决定那个宏会喝哪一瓶。"
L["ABOUT_COMBAT"]        = "战斗中可以切换：点击是在暴雪的安全环境里执行的，不会污染，也不会去改你的宏内容。"
L["ABOUT_SLASH"]         = "命令：|cffffd200/mbh|r 打开设置，|cffffd200/mbh reset|r 把切换条放回默认位置。"
L["ABOUT_AUTHOR"]        = "作者：米利（米利UI套组）"
