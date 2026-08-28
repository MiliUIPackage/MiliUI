-- 繁體中文
local L = LibStub("AceLocale-3.0"):NewLocale("MiliUI_BurstPotionHelper", "zhTW")
if not L then return end

L["ADDON_NAME"]          = "米利的爆發藥水助手"
L["SETTINGS_TITLE"]      = "米利的爆發藥水助手"
L["SETTINGS_DESC"]       = "用一個小列切換你的爆發藥水與品質，再用下方的巨集喝下。"
L["SECTION_GENERAL"]     = "功能"
L["SECTION_MACRO"]       = "爆發巨集"
L["SECTION_LIST"]        = "藥水清單"

L["LIST_DESC"]           = "管理切換列要出現哪些藥水。預設藥水可停用或刪除,也能自行新增。我之後改版新增的預設藥水會自動出現在這裡。"
L["BTN_ADD_ITEM"]        = "新增藥水"
L["BTN_RESTORE_DEFAULTS"] = "恢復預設"
L["LABEL_CUSTOM"]        = "自訂"
L["ADD_TITLE"]           = "新增藥水"
L["ADD_HINT"]            = "輸入物品 ID,或 Shift 點背包/聊天裡的物品連結帶入。"
L["ADD_INVALID"]         = "無效的物品 ID。"
L["ADD_EXISTS"]          = "這個藥水已經在清單裡了。"

L["OPT_PRINT"]           = "切換藥水時在聊天框提示"
L["OPT_SHOW_BAR"]        = "顯示藥水切換列"
L["OPT_LOCK_BAR"]        = "鎖定切換列位置（禁止拖動）"
L["OPT_RIGHTCLICK"]      = "右鍵圖示直接使用該爆發藥水"
L["OPT_SHOW_CD"]         = "在圖示上顯示藥水冷卻時間"
L["OPT_ITEM_TOOLTIP"]    = "滑鼠移過時顯示道具資訊"
L["OPT_SPLIT_CONTEXT"]   = "依環境分開記憶藥水選擇"

-- 分環境記憶
L["CONTEXT_WORLD"]       = "世界"
L["CONTEXT_PARTY"]       = "M+／地城"
L["CONTEXT_RAID"]        = "團隊"
L["CONTEXT_PVP"]         = "戰場"
L["CONTEXT_ARENA"]       = "競技場"
L["CONTEXT_SCENARIO"]    = "探究／儀式"
L["CONTEXT_SHARED"]      = "共用（未分開）"
L["CONTEXT_NO_POTION"]   = "不使用藥水"
L["SETTINGS_CURRENT_CONTEXT"] = "目前套用的記憶：%s"
L["MSG_CONTEXT_APPLIED"] = "進入%s，已套用該環境的藥水記憶：|cff33ff33%s|r"
L["TIP_CONTEXT"]         = "目前記憶：|cff33ff33%s|r"

L["MACRO_HELP"]          = "把這一行放進你的爆發巨集即可。"
L["BTN_RESET_POS"]       = "重置切換列位置"

L["COPY_HINT"]           = "按 Ctrl+C 複製，再用 Ctrl+V 貼進巨集裡。"

L["LABEL_FLEETING"]      = "大鍋"
L["LABEL_T3"]            = "高品質"
L["LABEL_T2"]            = "中品質"
L["LABEL_T1"]            = "一般品質"

L["MSG_SWITCHED"]        = "已切換至 |cff33ff33%s|r x%d"
L["MSG_SWITCHED_Q"]      = "已切換至 |cff33ff33%s（%s）|r x%d"
L["MSG_DISABLED"]        = "已停用爆發藥水"
L["MSG_NO_POTION"]       = "背包裡找不到爆發藥水。"
L["MSG_COLLAPSE_COMBAT"] = "戰鬥中無法即時收合／展開，將於離開戰鬥後套用。"

L["TIP_DRAG"]            = "拖動以移動"
L["TIP_LOCKED"]          = "已鎖定"
L["TIP_COLLAPSE"]        = "左鍵：收合／展開"
L["TIP_SETTINGS"]        = "右鍵開啟設定"
L["TIP_SELECT"]          = "左鍵：選擇此藥水"
L["TIP_USE"]             = "右鍵：直接使用此藥水"
L["TIP_NONE"]            = "左鍵：不使用藥水"

-- MiliUIWidgets 共用層（元件庫只查這四個 key）
L["Apply"]               = "套用"
L["Okay"]                = "確定"
L["Cancel"]              = "取消"
L["Can't change settings during combat"] = "戰鬥中無法調整設定"

-- 設定視窗
L["TAB_GENERAL"]         = "一般"
L["TAB_ABOUT"]           = "關於"
L["SECTION_CONTEXT"]     = "分環境記憶"
L["OPT_SPLIT_CONTEXT_DESC"] = "世界、戰場、競技場、M+、團隊、探究各記一份；關掉就全部共用同一個選擇。"
L["ADD_FIELD_ID"]        = "物品 ID"
L["BTN_SELECT_ALL"]      = "全選"
L["MACRO_LABEL"]         = "巨集指令"
L["VERSION_FORMAT"]      = "版本：%s"
L["OPEN_HINT"]           = "輸入 /mbh 開啟設定"
L["BTN_OPEN_OPTIONS"]    = "開啟設定"
L["ABOUT_MACRO"]         = "把 %s 綁進你的爆發巨集；切換列只負責決定那個巨集會喝哪一瓶。"
L["ABOUT_COMBAT"]        = "戰鬥中可以切換：點擊是在暴雪的安全環境裡執行的，不會污染，也不會去改你的巨集內容。"
L["ABOUT_SLASH"]         = "指令：|cffffd200/mbh|r 開啟設定，|cffffd200/mbh reset|r 把切換列放回預設位置。"
L["ABOUT_AUTHOR"]        = "作者：米利（米利UI套組）"
