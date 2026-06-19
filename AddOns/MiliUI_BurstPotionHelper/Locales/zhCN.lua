-- 简体中文
local L = LibStub("AceLocale-3.0"):NewLocale("MiliUI_BurstPotionHelper", "zhCN")
if not L then return end

L["ADDON_NAME"]          = "MiliUI 爆发药水助手"
L["SETTINGS_TITLE"]      = "爆发药水助手"
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

L["MACRO_HELP"]          = "把这一行放进你的爆发宏即可。"
L["BTN_COPY_MACRO"]      = "复制宏命令"
L["BTN_RESET_POS"]       = "重置切换条位置"

L["COPY_TITLE"]          = "复制宏命令"
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
