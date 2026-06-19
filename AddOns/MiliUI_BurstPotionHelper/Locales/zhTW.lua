-- 繁體中文
local L = LibStub("AceLocale-3.0"):NewLocale("MiliUI_BurstPotionHelper", "zhTW")
if not L then return end

L["SETTINGS_TITLE"]      = "爆發藥水助手"
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

L["MACRO_HELP"]          = "把這一行放進你的爆發巨集即可。"
L["BTN_COPY_MACRO"]      = "複製巨集指令"
L["BTN_RESET_POS"]       = "重置切換列位置"

L["COPY_TITLE"]          = "複製巨集指令"
L["COPY_HINT"]           = "按 Ctrl+C 複製，再用 Ctrl+V 貼進巨集裡。"

L["LABEL_FLEETING"]      = "大鍋"
L["LABEL_T3"]            = "高品質"
L["LABEL_T2"]            = "中品質"
L["LABEL_T1"]            = "一般品質"

L["MSG_LOADED"]          = "已載入。把 |cff33ff33%s|r 放進你的爆發巨集，點擊切換列上的藥水可快速切換藥水。"
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
