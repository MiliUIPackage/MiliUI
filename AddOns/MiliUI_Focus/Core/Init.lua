------------------------------------------------------------
-- MiliUI_Focus 命名空間與啟動流程
--
-- 這是原本 MiliUI 套組裡「專注目標」那一整組功能（Shift+點擊設專注目標／自動團隊標記／
-- 標記切換列／隊友標記同步／專注目標施法條）拆出來的獨立插件。
--
-- 啟動一律等到 PLAYER_LOGIN：
--   * 自己的 SavedVariables 那時已經載入；
--   * 首次啟動要讀 MiliUI 的 MiliUI_DB 做一次性遷移，而那份 SV 要等 MiliUI 自己的
--     ADDON_LOADED 才會出現。等到 PLAYER_LOGIN 就不必猜插件載入順序。
------------------------------------------------------------
local ADDON, ns = ...

ns.ADDON_NAME = ADDON
ns.VERSION    = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"
ns.DB_VERSION = 2   -- v2：zhTW 宣告內容的「焦點」正名為「專注目標」（見 Core/DB.lua）

ns.playerClass = select(2, UnitClass("player"))   -- player token 不受 12.1 身分限制，安全

ns.PREFIX_COLOR = "|cff00FFFF"

function ns.Print(...)
    print(ns.PREFIX_COLOR .. "[" .. ns.L["MiliUI Focus"] .. "]|r", ...)
end

------------------------------------------------------------
-- 12.x 的插件對外通訊限制閘
--
-- Midnight 起遊戲會在特定情境把插件的「對外送訊息」整組關掉。⚠ 被擋的時候
-- **不是回傳失敗碼，是直接彈「介面功能因插件而失效」那個紅字對話框**，所以每一次
-- 送之前都要先問過，不要賭。兩條路各有各的閘：
--
--   聊天訊息 SendChatMessage   → ns.IsChatRestricted()
--   插件訊息 SendAddonMessage  → ns.IsCommRestricted()
--
-- 情境由 Enum.AddOnRestrictionType 定義（12.0 新增，12.0.5 補上 Chat）：
-- Combat / Encounter / ChallengeMode / PvPMatch / Map / Chat。
-- ⚠ **ChallengeMode 是「整趟鑰石」都算，不是只有戰鬥中** —— 這就是「M+ 隊伍裡
--   宣告一直送不出去」的成因，跟有沒有在打怪無關。
-- ⚠ 封鎖期間連「把字填進聊天輸入框」都不准（ChatFrameUtil.InsertLink 一樣被擋，
--   Auctionator／Baganator／Chattynator 都是這樣擋的），所以沒有「幫玩家填好、
--   他自己按 Enter」這條降級路，只能把內容印在本地讓他自己打。
------------------------------------------------------------
local function RestrictionActive(name)
    local t = Enum and Enum.AddOnRestrictionType and Enum.AddOnRestrictionType[name]
    if t == nil then return false end
    if not (C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive) then return false end
    return C_RestrictedActions.IsAddOnRestrictionActive(t) and true or false
end

-- 插件現在能不能送聊天訊息。InChatMessagingLockdown 就是暴雪給這題的正解
-- （MRT／Chattynator／Auctionator 都只問它），API 不在才退回情境判斷。
function ns.IsChatRestricted()
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
        return C_ChatInfo.InChatMessagingLockdown() and true or false
    end
    return RestrictionActive("Chat") or RestrictionActive("Encounter")
        or RestrictionActive("ChallengeMode") or RestrictionActive("PvPMatch")
end

-- 插件現在能不能送 addon message。注意這只擋「送」，**不清掉已經收到的資料** ——
-- M+ 開始前在隊伍裡收到的隊友設定，整趟鑰石都還用得上，正是最需要它的場合。
function ns.IsCommRestricted()
    if RestrictionActive("Encounter") or RestrictionActive("ChallengeMode")
       or RestrictionActive("PvPMatch") then
        return true
    end
    -- C_RestrictedActions 不在時的等價判斷
    if IsEncounterInProgress and IsEncounterInProgress() then return true end
    if C_MythicPlus and C_MythicPlus.IsRunActive and C_MythicPlus.IsRunActive() then return true end
    if C_PvP and C_PvP.IsActiveBattlefield and C_PvP.IsActiveBattlefield() then return true end
    return false
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
