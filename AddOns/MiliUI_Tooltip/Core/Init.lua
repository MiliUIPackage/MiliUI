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

------------------------------------------------------------
-- 錯誤收集與封鎖動作攔截 —— 共用層 Libs/MiliUIWidgets/Errors.lua
--
--   ns.ReportError  xpcall 的訊息處理器（三道守衛：防遞迴、err 本身可能是秘密
--                   字串、下游 handler 包 pcall）。記進 ns.errors 供 /mtip debug 印出，
--                   同時照常轉給全域 errorhandler（有裝 BugSack 就進 BugSack）。
--   封鎖動作攔截    ADDON_ACTION_FORBIDDEN 不是 Lua error、pcall 攔不住，
--                   但事件會點名是哪個插件的哪個函式。
------------------------------------------------------------
ns.Errors.Install(function(line)
    print(ns.PREFIX_COLOR .. "[米利的滑鼠提示]|r |cffff5555" .. line .. "|r")
end)

------------------------------------------------------------
-- 診斷記錄器（/mtip log 開關、/mtip logdump 印出）
-- 抓「戰鬥中敵方提示顯示成上一個友方」這類要看時序的問題用。
-- 關閉時每個記錄點只付一次 boolean 檢查。
------------------------------------------------------------
ns.logEnabled = false
ns.logBuf = {}

-- 值的安全描述：秘密值不讀內容，只標型別
function ns.Describe(v)
    if v == nil then return "nil" end
    if issecretvalue and issecretvalue(v) then return "secret<" .. type(v) .. ">" end
    if type(v) == "string" then return '"' .. v .. '"' end
    return tostring(v)
end

function ns.Log(fmt, ...)
    if not ns.logEnabled then return end
    local ok, line = pcall(string.format, fmt, ...)
    tinsert(ns.logBuf, ("[%.2f] %s"):format(GetTime() % 1000, ok and line or fmt))
    if #ns.logBuf > 150 then tremove(ns.logBuf, 1) end
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
            print("|cff4DD2FF[米利的滑鼠提示]|r |cffff5555" .. line .. "|r")
        end
    end)
end

_G.MiliUITip = ns
