------------------------------------------------------------
-- MiliUI_DamageMeters 命名空間與啟動流程
--
-- 這支插件是「渲染器」，不是統計引擎：所有加總由暴雪 12.0 起的 C_DamageMeter
-- 做完，這裡只負責把資料畫成長條。因此它**完全不註冊
-- COMBAT_LOG_EVENT_UNFILTERED**——CPU 成本只跟「可見列數 × 刷新率」成長，
-- 跟團隊人數與戰鬥記錄流量無關。設計理由見 .claude/notes/wow-damagemeter-c-api-design.md。
--
-- 啟動一律等到 PLAYER_LOGIN：SavedVariables 那時才保證載入，也不必猜插件順序。
------------------------------------------------------------
local ADDON, ns = ...

ns.ADDON_NAME = ADDON
ns.VERSION    = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"
ns.DB_VERSION = 2

-- player token 不受 12.1 身分限制，讀職業是安全的
ns.playerClass = select(2, UnitClass("player"))
ns.playerGUID  = UnitGUID("player")

-- 聊天前綴與設定視窗標題共用這一個色，跟 TOC 的 [統計] 標籤同色。
-- 00FFFF 是套組的既有用色（Focus 的 [專注]、BurstPotionHelper 的 [巨集]、
-- DamageMeterTools 的 [統計] 都是它）—— 兩支統計插件在列表裡相鄰，同色才像一組。
ns.PREFIX_COLOR = "|cff00FFFF"

function ns.Print(...)
    print(ns.PREFIX_COLOR .. "[" .. ns.L["MiliUI Damage Meters"] .. "]|r", ...)
end

------------------------------------------------------------
-- 錯誤收集與封鎖動作攔截 —— 共用層 Libs/MiliUIWidgets/Errors.lua
--
--   ns.ReportError  xpcall 的訊息處理器（三道守衛：防遞迴、err 本身可能是秘密
--                   字串、下游 handler 包 pcall）。記進 ns.errors 供 /mdm debug 印出，
--                   同時照常轉給全域 errorhandler（有裝 BugSack 就進 BugSack）。
--   封鎖動作攔截    ADDON_ACTION_FORBIDDEN 不是 Lua error、pcall 攔不住，
--                   但事件會點名是哪個插件的哪個函式。
------------------------------------------------------------
ns.Errors.Install(function(line)
    ns.Print("|cffff5555" .. line .. "|r")
end)

------------------------------------------------------------
-- 客戶端閘：C_DamageMeter 是 12.0 才有的 API。沒有它這支插件無事可做，
-- 與其在每個呼叫點散一堆 nil 檢查，不如開檔就判斷一次、講一句話然後裝死。
------------------------------------------------------------
ns.HAS_API = (C_DamageMeter ~= nil
    and C_DamageMeter.GetCombatSessionFromType ~= nil
    and Enum ~= nil and Enum.DamageMeterType ~= nil)

------------------------------------------------------------
-- 啟動
------------------------------------------------------------
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    ns.DB.Init()
    ns.Media.RegisterSharedMedia()   -- LSM 比我們晚載入時，開檔那次會沒註冊到

    if not ns.HAS_API then
        C_Timer.After(6, function()
            ns.Print("|cffff5555" .. ns.L["This client has no C_DamageMeter API (needs patch 12.0 or later); the addon is idle."] .. "|r")
        end)
        return
    end

    ns.Fire("Init")
end)

_G.MiliUIDamageMeters = ns
