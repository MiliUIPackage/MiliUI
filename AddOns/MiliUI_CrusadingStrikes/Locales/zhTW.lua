local _, ns = ...
if GetLocale() ~= "zhTW" then return end
local L = ns.L

-- 共用層（MiliUIWidgets）
L["Apply"] = "套用"
L["Okay"] = "確定"
L["Cancel"] = "取消"
L["Can't change settings during combat"] = "戰鬥中無法調整設定"

-- 插件名稱與分頁
L["MiliUI Crusading Strikes"] = "德莫的征戰聖擊助手"
L["General"] = "一般"
L["Appearance"] = "外觀"
L["About"] = "關於"

-- 一般分頁
L["Crusading Strikes helper"] = "征戰聖擊助手"
L["Enable"] = "啟用"
L["Draws a bar under your target's nameplate health bar showing how long until the next Crusading Strikes swing."] = "在目標名條的血條下方畫一條進度條，顯示距離下一次征戰聖擊還有多久。"
L["Status"] = "狀態"

L["Class:"] = "角色職業:"
L["Paladin"] = "聖騎士"
L["Not a paladin — the addon is asleep on this character"] = "不是聖騎士，插件在這隻角色上休眠"
L["Nameplates:"] = "名條:"
L["Platynator is loaded"] = "Platynator 已載入"
L["Platynator is not loaded — there is no nameplate to attach to"] = "Platynator 未載入，沒有可以掛上去的名條"
L["Cooldown Manager:"] = "冷卻管理器:"
L["Enabled"] = "已啟用"
L["Disabled"] = "未啟用"
L["Crusading Strikes tracking:"] = "征戰聖擊追蹤:"
L["In the Tracked Bars row"] = "已在「追蹤的量條」列"
L["Not found"] = "未找到"
L["Can't check during combat"] = "戰鬥中無法檢查"
L["Unknown"] = "無法判斷"
L["bar found"] = "已找到長條"
L["Open Blizzard's Cooldown Manager (Edit Mode → Cooldown Manager) and put Crusading Strikes into the Tracked Bars row. That row can be shrunk or moved off screen, but it must not be turned off."] = "打開暴雪的「冷卻管理器」（編輯模式 → 冷卻管理器），把「征戰聖擊」加進「追蹤的量條」列。那一列可以縮小或移到畫面外，但不能關閉。"

L["Cast bar"] = "施法條"
L["When a cast bar shows"] = "施法條出現時"
L["Move below the cast bar"] = "移到施法條下方"
L["Hide the bar"] = "隱藏這條"
L["Leave it where it is"] = "不要動"
L["Only applies when the nameplate design puts its cast bar below the health bar; designs that put it above are left alone."] = "只有在名條設計把施法條放在血條下方時才會讓位；施法條在血條上方的設計不會動。"


-- 外觀分頁
L["Size and position"] = "尺寸與位置"
L["Height"] = "高度"
L["Width"] = "寬度"
L["Match the health bar"] = "跟血條同寬"
L["Fixed width"] = "固定寬度"
L["Gap below the health bar"] = "與血條的間距"
L["Horizontal offset"] = "水平位移"
L["Fill"] = "填充"
L["Direction"] = "填充方向"
L["Elapsed — grows left to right"] = "已揮的時間，左→右長出"
L["Remaining — counts down"] = "剩餘時間，倒數縮短"
L["Texture"] = "材質"
L["Default"] = "預設"
L["Fill color"] = "填充顏色"
L["Background color"] = "背景顏色"
L["1px black border"] = "1 像素黑邊"
L["Restore defaults"] = "還原預設值"
L["Restore every setting on this addon to its default?"] = "把這支插件的所有設定還原成預設值？"

-- 關於分頁
L["Shows how long until your next Crusading Strikes swing, as a bar under your target's nameplate health bar."] = "把距離下一次征戰聖擊還有多久畫成一條進度條，貼在目標名條的血條下方。"
L["The timing is mirrored straight from Blizzard's Cooldown Manager bar, so it stays accurate in raids and Mythic+."] = "計時直接鏡射暴雪冷卻管理器的長條，所以在團隊首領戰與傳奇鑰石地下城裡一樣準。"
L["Commands: |cffffd200/dermo|r opens the options, |cffffd200/dermo check|r prints a diagnosis, |cffffd200/dermo reset|r restores the defaults"] = "指令: |cffffd200/dermo|r 開啟設定、|cffffd200/dermo check|r 印出診斷、|cffffd200/dermo reset|r 還原預設值"
L["Author: Mili (MiliUI package)"] = "作者: Mili（米利UI套組）"

-- 暴雪入口頁
L["Use /dermo to open options"] = "輸入 /dermo 開啟設定"
L["Version: %s"] = "版本: %s"
L["Open options"] = "開啟設定"

-- /dermo check
L["yes"] = "有"
L["no"] = "沒有"
L["active"] = "作用中"
L["secret id"] = "編號是秘密值"
L["Paladin:"] = "聖騎士:"
L["Enabled:"] = "已啟用:"
L["Platynator loaded:"] = "Platynator 已載入:"
L["Attached:"] = "已掛上名條:"
L["Health bar:"] = "血條:"
L["Cast bar:"] = "施法條:"
L["cast bar sits below:"] = "施法條在血條下方:"
L["mirroring:"] = "鏡射中:"
L["Errors:"] = "錯誤紀錄:"

-- 隱藏暴雪那條
L["Hide the Crusading Strikes bar in the Cooldown Manager"] = "隱藏冷卻管理器裡的征戰聖擊量條"
L["Only that one bar; the others stay. It is made transparent rather than turned off, because Blizzard only updates a bar while it is shown and this addon mirrors those updates."] = "只隱藏這一條，其他量條照舊。做法是變透明而不是關閉：暴雪只在那條顯示中才更新它的值，本插件鏡射的就是那些值。"
L["Blizzard bar hidden"] = "暴雪那條已隱藏"
