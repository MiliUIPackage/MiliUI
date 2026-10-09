------------------------------------------------------------
-- MiliUI_BossTimeline 命名空間與啟動流程
--
-- 「米利的首領時間軸」三件事：
--   1. 重畫暴雪的首領時間軸（Timeline/Display.lua）—— 直式／橫式、文字、描邊、顏色、方形圖示
--   2. 標出每一條是誰放上去的（Timeline/Owners.lua）—— 暴雪／自己／其他插件
--   3. 自訂時間軸（Plans/）—— 玩家自己替首領排的提示，開戰後照秒數寫進暴雪時間軸
--
-- 為什麼自己重畫而不是改官方的樣式：
--   * 暴雪的 API 文件明講 `EncounterTimelineViewType.None`「建議給完全接管時間軸顯示的插件用」，
--     資料面（C_EncounterTimeline）本來就開放給插件讀，剩餘秒數、軌道、狀態都不是秘密值；
--     秘密的只有首領事件的名稱／圖示／顏色，而那些可以原封不動交給 SetTexture／SetText／
--     SetVertexColor 顯示（當傳遞者，不當讀取者）。
--   * 改官方的框要在暴雪自己的執行路徑裡動它的子框（pip、文字、邊框都是模板建的、還會被
--     scripted animation 重設），12.1 之後這種寫法正是「插件污染暴雪框」的典型入口；
--     直式／橫式也只有暴雪內建的兩種軌道配置，做不到「圖示改方框、文字換位置」這種程度。
--   * 自己畫才做得出設定頁裡的即時預覽 —— 同一支 Display 換一個假資料來源就是預覽。
--
-- 啟動一律等到 PLAYER_LOGIN：自己的 SavedVariables 那時才載入。
------------------------------------------------------------
local ADDON, ns = ...

ns.ADDON_NAME = ADDON
ns.VERSION    = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"
ns.DB_VERSION = 1

-- player token 讀職業不受 12.1 身分限制，安全
ns.playerClass = select(2, UnitClass("player"))

ns.PREFIX_COLOR = "|cffFF7F00"

function ns.Print(...)
    print(ns.PREFIX_COLOR .. "[" .. ns.L["MiliUI Boss Timeline"] .. "]|r", ...)
end

------------------------------------------------------------
-- 錯誤收集與封鎖動作攔截 —— 共用層 Libs/MiliUIWidgets/Errors.lua
--   ns.errors / ns.ReportError（xpcall 的訊息處理器，err 本身可能是秘密字串）
------------------------------------------------------------
ns.Errors.Install(function(line)
    ns.Print("|cffff5555" .. line .. "|r")
end)

------------------------------------------------------------
-- 啟動：初始化資料庫 → 通知各模組
------------------------------------------------------------
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    ns.DB.Init()
    ns.Fire("Init")
end)

_G.MiliUIBossTimeline = ns
