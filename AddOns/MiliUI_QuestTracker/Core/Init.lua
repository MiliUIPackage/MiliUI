------------------------------------------------------------
-- MiliUI_QuestTracker 命名空間與啟動流程
--
-- 這支插件**不自己畫任務追蹤器**。暴雪的 ObjectiveTrackerFrame 仍然是唯一的
-- 渲染引擎，我們只做三件事：換掉它的字型／顏色／裝飾貼圖、在它旁邊加自己的
-- 背景與標題列、以及決定它什麼時候該收起來。
--
-- 為什麼寧可掛勾也不重寫：追蹤器的內容有一半是暴雪的共用 widget pool 畫的
-- （場景、UI widget），那個池子同時服務工具提示與地圖圖釘。自己重畫等於要複製
-- 那整套資料流；掛勾則只要守住 Core/Tracker.lua 那幾條規矩就好。
--
-- 啟動一律等到 PLAYER_LOGIN：自己的 SavedVariables 那時才在，
-- Blizzard_ObjectiveTracker 也已經載入完（它是基礎 UI 的一部分，比插件早）。
------------------------------------------------------------
local ADDON, ns = ...

ns.ADDON_NAME = ADDON
ns.VERSION    = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"
ns.DB_VERSION = 1

-- player token 不受 12.1 身分限制，讀職業是安全的
ns.playerClass = select(2, UnitClass("player"))

-- 聊天前綴與設定視窗標題共用這一個色，跟 TOC 的 [任務] 標籤同色
ns.PREFIX_COLOR = "|cff7FD65A"

function ns.Print(...)
    print(ns.PREFIX_COLOR .. "[" .. ns.L["MiliUI Quest Tracker"] .. "]|r", ...)
end

------------------------------------------------------------
-- 錯誤收集與封鎖動作攔截 —— 共用層 Libs/MiliUIWidgets/Errors.lua
--
-- 這支插件特別需要封鎖動作攔截：ObjectiveTrackerFrame 是編輯模式管的框，
-- 戰鬥中對它 Show()／Hide()／SetParent() 都會被封鎖。攔截器會直接點名是哪個
-- 函式被擋，省掉「為什麼首領戰時沒收起來」這種只能猜的回報。
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

_G.MiliUIQuestTracker = ns
