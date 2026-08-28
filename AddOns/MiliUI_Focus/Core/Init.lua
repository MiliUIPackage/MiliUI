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

------------------------------------------------------------
-- 錯誤收集與封鎖動作攔截 —— 共用層 Libs/MiliUIWidgets/Errors.lua
--
--   ns.ReportError  xpcall 的訊息處理器（三道守衛：防遞迴、err 本身可能是秘密
--                   字串、下游 handler 包 pcall）。記進 ns.errors 供 /mfocus debug 印出，
--                   同時照常轉給全域 errorhandler（有裝 BugSack 就進 BugSack）。
--   封鎖動作攔截    ADDON_ACTION_FORBIDDEN 不是 Lua error、pcall 攔不住，
--                   但事件會點名是哪個插件的哪個函式。
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
