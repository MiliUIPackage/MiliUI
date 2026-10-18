------------------------------------------------------------
-- MiliUI_CharacterNotes 命名空間與啟動流程
--
-- 這支插件原本是 MiliUI 套組裡的 Enhance/CharacterNotes.lua，2026-08-26 拆成
-- 獨立插件，同時多了兩件套組版沒有的事：
--   * 副本／首領筆記（走進副本、首領戰開打時自己跳出來的唯讀小視窗）
--   * 用聊天連結把筆記分享給隊友
--
-- 啟動一律等到 PLAYER_LOGIN：
--   * 自己的 SavedVariables 那時已經載入；
--   * 首次啟動要讀 MiliUI 的 MiliUI_DB / MiliUI_CharDB 做一次性遷移，而那兩份 SV
--     要等 MiliUI 自己的 ADDON_LOADED 才會出現。等到 PLAYER_LOGIN 就不必猜載入順序。
------------------------------------------------------------
local ADDON, ns = ...

ns.ADDON_NAME = ADDON
ns.VERSION    = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"
ns.DB_VERSION = 1

-- player token 不受 12.1 身分限制，讀職業是安全的
ns.playerClass = select(2, UnitClass("player"))

-- 聊天前綴、設定視窗標題與分享連結共用這一個色，跟 TOC 的 [筆記] 標籤同色
ns.PREFIX_COLOR = "|cffE8C56C"

function ns.Print(...)
    print(ns.PREFIX_COLOR .. "[" .. ns.L["MiliUI Character Notes"] .. "]|r", ...)
end

-- 12.1：任何從別人身上讀來的字串都有可能是秘密值，拿去當 table key 或
-- 串接都會直接崩潰。整包統一走這一支擋。
ns.issecret = issecretvalue or function() return false end

------------------------------------------------------------
-- 錯誤收集與封鎖動作攔截 —— 共用層 Libs/MiliUIWidgets/Errors.lua
--
--   ns.ReportError  xpcall 的訊息處理器（三道守衛：防遞迴、err 本身可能是秘密
--                   字串、下游 handler 包 pcall）。記進 ns.errors 供 /mnote debug 印出，
--                   同時照常轉給全域 errorhandler（有裝 BugSack 就進 BugSack）。
--   封鎖動作攔截    ADDON_ACTION_FORBIDDEN 不是 Lua error、pcall 攔不住，
--                   但事件會點名是哪個插件的哪個函式。
------------------------------------------------------------
ns.Errors.Install(function(line)
    ns.Print("|cffff5555" .. line .. "|r")
end)

------------------------------------------------------------
-- 目前角色的 key（帳號層資料表用它分身；跨服同名靠伺服器名區分）
------------------------------------------------------------
function ns.CurrentCharKey()
    local name  = UnitName("player") or "?"
    local realm = GetNormalizedRealmName() or GetRealmName() or ""
    return name .. "-" .. realm, name, realm
end

------------------------------------------------------------
-- 啟動：初始化資料庫 → 通知各模組
------------------------------------------------------------
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    ns.DB.Init()
    ns.Media.UpdateFonts()      -- 字型物件要等 DB 才知道玩家挑了什麼
    ns.Fire("Init")

    -- 舊版米利UI套組還帶著同一支功能的話，兩邊會各開一個筆記視窗、各掛一顆小地圖
    -- 按鈕，而且寫的是不同的 SavedVariables（在這裡新增的筆記，套組那邊看不到）。
    -- 講一次就好（不自動停用：玩家可能是刻意留著舊的在核對資料）。
    -- ⚠ 判斷要放在計時器**裡面**：那支也是等 PLAYER_LOGIN 才建視窗，誰先誰後不保證。
    C_Timer.After(6, function()
        if not _G.MiliUI_CharacterNotesFrame then return end
        ns.Print("|cffff5555" .. ns.L["The MiliUI package still has its own character notes module loaded. Update the package — otherwise you will have two notebooks that do not share data."] .. "|r")
    end)
end)

_G.MiliUICharacterNotes = ns
