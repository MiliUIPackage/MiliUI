------------------------------------------------------------
-- 簡體中文
-- key＝英文原文，改 key 的時候記得同步這裡，不然會退回英文
------------------------------------------------------------
local _, ns = ...
if GetLocale() ~= "zhCN" then return end

local L = ns.L

L["[MiliUI CDM]"] = "[米利冷却]"
L["%s and MiliUI Cooldown Manager both take over Blizzard's Cooldown Manager, so only one of them can be enabled."] = "%s 与米利的冷却管理器都会接管暴雪的冷却管理器，只能启用其中一个。"
L["Disable %s and reload"] = "停用 %s 并重载"
L["Disable this addon for now"] = "先关闭本插件"
L["MiliUI Cooldown Manager"] = "米利的冷却管理器"
L["Not implemented yet."] = "尚未实现。"
L["Essential Cooldowns"] = "核心技能"
L["Utility Cooldowns"] = "辅助技能"
L["Tracked Buffs"] = "增益图标"
L["Tracked Bars"] = "增益条"
L["Resource Bars"] = "资源条"
L["Cast Bar"] = "施法条"
L["Theme"] = "主题"
L["Profiles"] = "配置"
L["About"] = "关于"
L["Rearranges and restyles Blizzard's Cooldown Manager."] = "重新排列并美化暴雪的冷却管理器。"
L["|cffffd200/mcdm|r or |cffffd200/miliuicdm|r opens or closes this window."] = "|cffffd200/mcdm|r 或 |cffffd200/miliuicdm|r 打开／关闭这个窗口。"
L["Author: Mili (MiliUI package)"] = "作者：Mili（MiliUI 套组）"
L["Bars"] = "条"
L["Global"] = "全局"
L["+ New Group"] = "＋ 新建组"
L["Custom groups are coming in a later version."] = "自定义组会在之后的版本加入。"
L["Use /mcdm to open options"] = "输入 /mcdm 打开设置"
L["Version: %s"] = "版本：%s"
L["Open options"] = "打开设置"
L["Left-click"] = "左键"
L["Toggle options"] = "开启／关闭设置"
L["Options UI failed to load."] = "设置界面载入失败。"
L["Minimap button shown."] = "已显示小地图按钮。"
L["Minimap button hidden. Type /mcdm minimap to bring it back."] = "已隐藏小地图按钮，输入 /mcdm minimap 可以恢复。"
L["Apply"] = "应用"
L["Okay"] = "确定"
L["Cancel"] = "取消"
L["Can't change settings during combat"] = "无法在战斗中更改设置"
-- 編輯模式
L["Open this bar's settings"] = "打开这条的设置"
L["Dragging stops it following %s"] = "拖动会解除对“%s”的跟随"
L["Cooldown Manager settings are in /mcdm, or click the gear at the top right of the blue box."] = "冷却管理器的设置在 /mcdm，或点击蓝框右上角的齿轮。"
