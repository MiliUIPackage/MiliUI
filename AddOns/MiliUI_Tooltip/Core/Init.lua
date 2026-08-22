------------------------------------------------------------
-- MiliUI_Tooltip 命名空間與常數
--
-- 這是 TinyTooltip 的自製重寫版，taint 圍堵設計見 Core/Hooks.lua 檔頭的
-- 「接觸面清單」。任何要碰暴雪物件的新程式碼都必須先過那張清單。
------------------------------------------------------------
local ADDON, ns = ...

ns.ADDON_NAME = ADDON
ns.VERSION    = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"
ns.DB_VERSION = 1            -- schemaVersion。尚未發佈、沒有遷移鏈；發佈後改預設值要配遷移

ns.playerClass = select(2, UnitClass("player"))   -- player token 不受 12.1 身分限制，安全

-- 錯誤收集：xpcall 隔離不能變成黑洞——記下最近的錯誤供 /mtip debug 印出，
-- 同時照常轉給全域 errorhandler（BugSack 有裝就進 BugSack）
ns.errors = {}
function ns.ReportError(err)
    tinsert(ns.errors, tostring(err))
    if #ns.errors > 10 then tremove(ns.errors, 1) end
    local handler = geterrorhandler()
    if handler then handler(err) end
end

------------------------------------------------------------
-- 封鎖／禁止動作攔截（同 MiliUI_UnitFrames 的做法）
-- ADDON_ACTION_FORBIDDEN 不是 Lua error、pcall 攔不住；事件會點名插件與函式，
-- 抓下來直接印出，taint 傳染第一時間就看得到兇手。
------------------------------------------------------------
do
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ADDON_ACTION_FORBIDDEN")
    watcher:RegisterEvent("ADDON_ACTION_BLOCKED")
    local seen = {}
    watcher:SetScript("OnEvent", function(_, event, addonName, funcName)
        if addonName ~= ADDON then return end
        local line = ("%s：%s（戰鬥中=%s）"):format(
            event == "ADDON_ACTION_FORBIDDEN" and "禁止動作" or "封鎖動作",
            tostring(funcName), tostring(InCombatLockdown() and true or false))
        tinsert(ns.errors, line)
        if #ns.errors > 10 then tremove(ns.errors, 1) end
        local key = tostring(funcName)
        if not seen[key] then
            seen[key] = true
            print("|cff4DD2FF[米利滑鼠提示]|r |cffff5555" .. line .. "|r")
        end
    end)
end

_G.MiliUITip = ns
