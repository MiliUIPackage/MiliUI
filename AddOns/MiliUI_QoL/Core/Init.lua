------------------------------------------------------------
-- MiliUI_QoL 命名空間與啟動流程
--
-- 套組本體裡「只碰暴雪介面、不靠第三方」的便利功能整組拆出來的獨立插件。
-- 設定內容只有一份（Options/Controls.lua），宿主有兩種：本體的設定視窗（向本體註冊
-- 「便利功能」分頁），或沒裝本體時自己的視窗（Options/Host.lua 決定）。
--
-- 啟動順序：
--   ADDON_LOADED（自己的）→ DB.Init：TOC 宣告 OptionalDeps: MiliUI，本體一定先載入，
--                         那時 MiliUI_DB 已經在了，遷移在這裡就做得完；模組的
--                         PLAYER_LOGIN 處理器拿到的是搬好的值。
--   PLAYER_LOGIN          → ns.Fire("Init")：各模組與宿主在這裡開工。
------------------------------------------------------------
local ADDON, ns = ...

ns.ADDON_NAME = ADDON
ns.VERSION    = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"
ns.DB_VERSION = 1

ns.playerClass = select(2, UnitClass("player"))   -- player token 不受 12.1 身分限制，安全

ns.PREFIX_COLOR = "|cff338FFF"
ns.TITLE = "米利的便利功能"

function ns.Print(...)
    print(ns.PREFIX_COLOR .. "[" .. ns.TITLE .. "]|r", ...)
end

------------------------------------------------------------
-- 舊本體偵測
--
-- 「還帶著便利功能模組的舊版本體」＋「新的 QoL」同時載入時，搬過來的模組（修裝、賣垃圾、
-- 交任務……）會跑兩次。本體因為 OptionalDeps 一定先載入，所以檔案載入當下就判斷得出來。
--
-- 判準：本體的骰裝過濾全域還在（舊模組的指紋），**而且**本體沒有外掛分頁的註冊 API。
-- ⚠ 第二個條件不能省：拆分期間（本體已有 RegisterOptionsTab、模組分批搬走）骰裝過濾
--   還在本體，只看第一個條件會把開發中的本體當成舊版，「便利功能」分頁就永遠掛不上去。
--   拆分期間本體還留著的模組，QoL 這邊一定還沒有，不會重複執行。
-- ⚠ Phase 1 起骰裝過濾本身也搬進 QoL（Modules/BonusRoll_Filter.lua，沿用同一個全域名），
--   判準照樣成立：本檔在 TOC 排在 Core\ 那一批，早於 Modules\ 的任何一支，QoL 自己那份
--   還沒定義這個全域 ⇒ 此刻看得到的，一定是先載入的舊本體定義的。
--   ⚠ 所以**不要把本檔挪到 Modules\BonusRoll_Filter.lua 之後**，也不要在更早的檔案裡碰這個全域。
--
-- 每支從本體搬來的模組，檔頭第一行都是 `if ns.legacyCore then return end`。
-- 戰利品通知（Modules/LootToast.lua）是新功能，不受這道閘影響。
------------------------------------------------------------
ns.legacyCore = (_G.MiliUI_BonusRollFilter ~= nil)
    and not (type(_G.MiliUI) == "table" and type(_G.MiliUI.RegisterOptionsTab) == "function")

------------------------------------------------------------
-- 在地化字型：有本體就跟本體同一份（本體分頁跟獨立視窗長得一樣），沒有就照語系挑
------------------------------------------------------------
local LOCALE_FONTS = {
    zhTW = "Fonts\\blei00d.TTF",
    zhCN = "Fonts\\ARKai_T.ttf",
    koKR = "Fonts\\2002.TTF",
}
local DEFAULT_FONT = LOCALE_FONTS[GetLocale()] or "Fonts\\FRIZQT__.TTF"

function ns.Font()
    local S = type(_G.MiliUI) == "table" and _G.MiliUI.Style
    if S and type(S.Font) == "string" then return S.Font end
    return DEFAULT_FONT
end

------------------------------------------------------------
-- 12.x 的插件對外通訊限制閘（抄 MiliUI_Focus/Core/Init.lua；搬來的交易密語要用）
--
--   聊天訊息 SendChatMessage   → ns.IsChatRestricted()
--   插件訊息 SendAddonMessage  → ns.IsCommRestricted()
--
-- ⚠ 被擋的時候不是回傳失敗碼，是直接彈「介面功能因插件而失效」，送之前一定要先問。
-- ⚠ ChallengeMode 是「整趟鑰石」都算，不是只有戰鬥中。
------------------------------------------------------------
local function RestrictionActive(name)
    local t = Enum and Enum.AddOnRestrictionType and Enum.AddOnRestrictionType[name]
    if t == nil then return false end
    if not (C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive) then return false end
    return C_RestrictedActions.IsAddOnRestrictionActive(t) and true or false
end

function ns.IsChatRestricted()
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
        return C_ChatInfo.InChatMessagingLockdown() and true or false
    end
    return RestrictionActive("Chat") or RestrictionActive("Encounter")
        or RestrictionActive("ChallengeMode") or RestrictionActive("PvPMatch")
end

function ns.IsCommRestricted()
    if RestrictionActive("Encounter") or RestrictionActive("ChallengeMode")
       or RestrictionActive("PvPMatch") then
        return true
    end
    if IsEncounterInProgress and IsEncounterInProgress() then return true end
    if C_MythicPlus and C_MythicPlus.IsRunActive and C_MythicPlus.IsRunActive() then return true end
    if C_PvP and C_PvP.IsActiveBattlefield and C_PvP.IsActiveBattlefield() then return true end
    return false
end

------------------------------------------------------------
-- 錯誤收集與封鎖動作攔截 —— 共用層 Libs/MiliUIWidgets/Errors.lua
-- （ns.ReportError ／ ns.errors，/mqol debug 印得出來）
------------------------------------------------------------
ns.Errors.Install(function(line)
    ns.Print("|cffff5555" .. line .. "|r")
end)

------------------------------------------------------------
-- 啟動
------------------------------------------------------------
local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= ADDON then return end
        self:UnregisterEvent("ADDON_LOADED")
        ns.DB.Init()
        return
    end

    self:UnregisterEvent("PLAYER_LOGIN")
    if not ns.db then ns.DB.Init() end   -- 保底：ADDON_LOADED 漏接（不該發生）也不要整支停擺
    ns.Fire("Init")

    if ns.legacyCore then
        C_Timer.After(6, function()
            ns.Print("|cffff5555套組本體版本過舊，便利功能暫由舊本體提供，請更新米利UI套組。|r")
        end)
    end
end)

_G.MiliUIQoL = ns
