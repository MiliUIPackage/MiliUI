------------------------------------------------------------
-- 繁體中文
-- key＝英文原文，改 key 的時候記得同步這裡，不然會退回英文
------------------------------------------------------------
local _, ns = ...
if GetLocale() ~= "zhTW" then return end

local L = ns.L

L["[MiliUI CDM]"] = "[米利冷卻]"
L["%s and MiliUI Cooldown Manager both take over Blizzard's Cooldown Manager, so only one of them can be enabled."] = "%s 與米利的冷卻管理器都會接管暴雪的冷卻管理器，只能啟用其中一個。"
L["Disable %s and reload"] = "停用 %s 並重載"
L["Disable this addon for now"] = "先關閉本插件"
L["MiliUI Cooldown Manager"] = "米利的冷卻管理器"
L["Not implemented yet."] = "尚未實作。"
L["Essential Cooldowns"] = "核心技能"
L["Utility Cooldowns"] = "輔助技能"
L["Tracked Buffs"] = "增益圖示"
L["Tracked Bars"] = "增益長條"
L["Resource Bars"] = "資源條"
L["Cast Bar"] = "施法條"
L["Theme"] = "主題"
L["Profiles"] = "設定檔"
L["About"] = "關於"
L["Rearranges and restyles Blizzard's Cooldown Manager."] = "重新排列並美化暴雪的冷卻管理器。"
L["|cffffd200/mcdm|r or |cffffd200/miliuicdm|r opens or closes this window."] = "|cffffd200/mcdm|r 或 |cffffd200/miliuicdm|r 開啟／關閉這個視窗。"
L["Author: Mili (MiliUI package)"] = "作者：Mili（MiliUI 套組）"
L["Bars"] = "條"
L["Global"] = "全域"
L["+ New Group"] = "＋ 新增群組"
L["Custom groups are coming in a later version."] = "自訂群組會在之後的版本加入。"
L["Use /mcdm to open options"] = "輸入 /mcdm 開啟設定"
L["Version: %s"] = "版本：%s"
L["Open options"] = "開啟選項"
L["Left-click"] = "左鍵"
L["Toggle options"] = "開啟／關閉設定"
L["Options UI failed to load."] = "設定介面載入失敗。"
L["Minimap button shown."] = "已顯示小地圖按鈕。"
L["Minimap button hidden. Type /mcdm minimap to bring it back."] = "已隱藏小地圖按鈕，輸入 /mcdm minimap 可以叫回來。"
L["Apply"] = "套用"
L["Okay"] = "確定"
L["Cancel"] = "取消"
L["Can't change settings during combat"] = "無法在戰鬥中更改設定"
-- 編輯模式
L["Open this bar's settings"] = "開啟這條的設定"
L["Dragging stops it following %s"] = "拖曳會解除跟隨「%s」"
L["Cooldown Manager settings are in /mcdm, or click the gear at the top right of the blue box."] = "冷卻管理器的設定在 /mcdm，或點藍框右上角的齒輪。"
