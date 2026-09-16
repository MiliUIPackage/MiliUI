------------------------------------------------------------
-- MiliUI_CrusadingStrikes 命名空間與啟動流程
--
-- 「德莫的征戰聖擊助手」：把征戰聖擊（普攻換成聖擊的天賦）的「距離下一刀還有多久」
-- 畫成一條進度條，貼在目標名條的血條底下。
--
-- 12.1 之後這個資訊**算不出來**：戰鬥記錄不給插件註冊、近戰普攻不派 SPELLCAST 事件、
-- 光環的剩餘時間是秘密值。唯一還走得通的是「鏡射暴雪自己畫好的那條」——冷卻管理器
-- 的「追蹤的增益」長條是 untainted 程式在餵值，原生 StatusBar 之間互傳秘密值是允許的。
-- 完整的排除清單與理由見 .claude/notes/project-miliui-crusadingstrikes.md。
--
-- 啟動一律等到 PLAYER_LOGIN：自己的 SavedVariables 那時才載入，暴雪的冷卻管理器
-- 框架也才存在。
------------------------------------------------------------
local ADDON, ns = ...

ns.ADDON_NAME = ADDON
ns.VERSION    = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"
ns.DB_VERSION = 1

-- player token 讀職業不受 12.1 身分限制，安全
ns.playerClass = select(2, UnitClass("player"))
ns.isPaladin   = ns.playerClass == "PALADIN"

ns.PREFIX_COLOR = "|cffF58CBA"

function ns.Print(...)
    print(ns.PREFIX_COLOR .. "[" .. ns.L["MiliUI Crusading Strikes"] .. "]|r", ...)
end

------------------------------------------------------------
-- 錯誤收集與封鎖動作攔截 —— 共用層 Libs/MiliUIWidgets/Errors.lua
--   ns.errors / ns.ReportError（xpcall 的訊息處理器，err 本身可能是秘密字串）
------------------------------------------------------------
ns.Errors.Install(function(line)
    ns.Print("|cffff5555" .. line .. "|r")
end)

------------------------------------------------------------
-- 共用輪詢 ticker
--
-- 兩件事要定期確認：追蹤的 CDM 長條還在不在（玩家可能中途改了追蹤清單），
-- 以及名條上的 Platynator display 還是不是同一個（換設計會整批重裝）。
-- 兩件都不值得每幀跑，也都不能只靠事件（沒有對應的事件）。
--
-- ⚠ 基礎心跳要比任何一個 interval 短，所以 0.25 配 0.5 的項目。
------------------------------------------------------------
ns.poll = ns.Metro.New(0.25, ns.ReportError)

------------------------------------------------------------
-- 啟動：初始化資料庫 → 通知各模組
--
-- 職業閘：非聖騎士只留設定視窗與指令（讓玩家看得到「這隻角色不是聖騎士，插件休眠」
-- 的說明），Source / Anchor / Bar 一概不啟動。不做專精閘 —— 非懲戒沒有那條
-- 追蹤的增益，Source 自然找不到東西，多一道閘只是多一個會過期的判斷。
------------------------------------------------------------
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    ns.DB.Init()
    ns.Fire("Init")
end)

_G.MiliUICrusadingStrikes = ns
