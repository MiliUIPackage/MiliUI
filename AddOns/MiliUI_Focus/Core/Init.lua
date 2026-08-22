------------------------------------------------------------
-- MiliUI_Focus 命名空間與啟動流程
--
-- 這是原本 MiliUI 套組裡「焦點目標」那一整組功能（Shift+點擊設焦點／自動團隊標記／
-- 標記切換列／隊友標記同步／焦點施法條）拆出來的獨立插件。
--
-- 啟動一律等到 PLAYER_LOGIN：
--   * 自己的 SavedVariables 那時已經載入；
--   * 首次啟動要讀 MiliUI 的 MiliUI_DB 做一次性遷移，而那份 SV 要等 MiliUI 自己的
--     ADDON_LOADED 才會出現。等到 PLAYER_LOGIN 就不必猜插件載入順序。
------------------------------------------------------------
local ADDON, ns = ...

ns.ADDON_NAME = ADDON
ns.VERSION    = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"
ns.DB_VERSION = 1

ns.playerClass = select(2, UnitClass("player"))   -- player token 不受 12.1 身分限制，安全

ns.PREFIX_COLOR = "|cff00FFFF"

function ns.Print(...)
    print(ns.PREFIX_COLOR .. "[" .. ns.L["MiliUI Focus"] .. "]|r", ...)
end

-- 錯誤收集：xpcall 隔離不能變成黑洞——記下最近的錯誤供 /mfocus debug 印出，
-- 同時照常轉給全域 errorhandler（BugSack 有裝就進 BugSack）
ns.errors = {}
function ns.ReportError(err)
    tinsert(ns.errors, tostring(err))
    if #ns.errors > 10 then tremove(ns.errors, 1) end
    local handler = geterrorhandler()
    if handler then handler(err) end
end

------------------------------------------------------------
-- 封鎖／禁止動作攔截（同 MiliUI_UnitFrames / MiliUI_Tooltip 的做法）
-- ADDON_ACTION_FORBIDDEN 不是 Lua error、pcall 攔不住；事件會點名插件與函式，
-- 抓下來直接印出，taint 傳染第一時間就看得到兇手。
-- 本插件有安全按鈕與覆寫綁定，這條線特別值得留著。
------------------------------------------------------------
do
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ADDON_ACTION_FORBIDDEN")
    watcher:RegisterEvent("ADDON_ACTION_BLOCKED")
    local seen = {}
    watcher:SetScript("OnEvent", function(_, event, addonName, funcName)
        if addonName ~= ADDON then return end
        local line = ("%s: %s (combat=%s)"):format(
            event == "ADDON_ACTION_FORBIDDEN" and "FORBIDDEN" or "BLOCKED",
            tostring(funcName), tostring(InCombatLockdown() and true or false))
        tinsert(ns.errors, line)
        if #ns.errors > 10 then tremove(ns.errors, 1) end
        local key = tostring(funcName)
        if not seen[key] then
            seen[key] = true
            ns.Print("|cffff5555" .. line .. "|r")
        end
    end)
end

------------------------------------------------------------
-- 啟動：初始化資料庫 → 通知各模組
------------------------------------------------------------
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    ns.DB.Init()
    ns.Fire("Init")

    -- 舊版米利UI套組還帶著同一組功能的話，兩邊會各自建一顆巨集按鈕、各開一條
    -- 標記列、宣告送兩次。這種情況只會發生在「裝了新插件但套組沒更新」，
    -- 講一次就好（不自動停用：玩家可能是刻意留著舊的在比對）。
    if _G.MiliUI_Focuser then
        C_Timer.After(6, function()
            ns.Print("|cffff5555" .. ns.L["The MiliUI package still has its own focus module loaded. Update the package — otherwise both will run (two marker bars, doubled announcements)."] .. "|r")
        end)
    end
end)

_G.MiliUIFocus = ns
