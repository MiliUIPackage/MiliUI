------------------------------------------------------------
-- 進新副本時自動重置
--
-- ════════════════════════════════════════════════════════════
-- 為什麼是一個下拉而不是兩個勾選
-- ════════════════════════════════════════════════════════════
-- 「要不要自動重置」＋「要不要先確認」兩個布林 = 四種狀態，但其中
-- 「不自動重置 ＋ 需要確認」是**無意義的組合** —— 第二個勾選必須跟著第一個
-- 變灰，玩家還得自己推理哪些組合有效。改成三選一的下拉：狀態剛好三個、
-- 沒有相依、沒有變灰的控件，而且標籤讀起來就是一句話（「進入新副本時 → 跳出確認」）。
-- 規則見 miliui-menu-design 技能。
--
-- ════════════════════════════════════════════════════════════
-- 什麼算「新副本」
-- ════════════════════════════════════════════════════════════
--   1. 進到一個**跟上次記錄不同**的副本（instanceID ＋ 難度）
--   2. 鑰石開始 —— 同一個副本連跑第二趟，1 認不出來，但那確實是新的一趟
--
-- 三個「不要吵人」的閘，每一個都對應一種實際會惹人厭的情況：
--   * **戰鬥中不跳** → 押到離開戰鬥再說（zone in 直接開打是常態）
--   * **沒有資料可重置就不問** → 問一個答案不影響任何事的問題是純噪音
--   * **登入／重載不跳** → 只記錄目前副本。在團隊裡重載一次就被問一次很煩
------------------------------------------------------------
local _, ns = ...

ns.AutoReset = {}
local A = ns.AutoReset
local D = ns.Data

local POPUP = "MILIUI_DAMAGEMETERS_AUTORESET"

local _pending          -- 戰鬥中先押著的副本名，離開戰鬥再處理

------------------------------------------------------------
-- 目前副本的識別字串。難度要算進去：同一個副本的英雄與傳奇是兩趟。
-- 不在副本裡回 nil。
------------------------------------------------------------
local function InstanceKey()
    local name, instType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
    if not instType or instType == "none" then return nil end
    return tostring(instanceID) .. ":" .. tostring(difficultyID), name
end

------------------------------------------------------------
-- 有東西可以重置嗎
--
-- 拿「總計」的傷害輸出當代表：它是唯一一定會有資料的類型，而且我們只要知道
-- 「有沒有」，不必讀值 —— 所以連秘密值都不必碰。
------------------------------------------------------------
local function HasData()
    local session = D.GetSession(D.S.Overall, nil, D.T.DamageDone)
    local sources = session and session.combatSources
    return sources ~= nil and #sources > 0
end

------------------------------------------------------------
-- 確認視窗
--
-- 用暴雪原生的 StaticPopup，不用我們設定面板那顆 —— 這個提示是「憑空冒出來」的，
-- 長得像遊戲原生對話框才不突兀，而且 ESC 關得掉、不必依賴設定視窗存在。
------------------------------------------------------------
StaticPopupDialogs[POPUP] = {
    text = "%s",
    button1 = YES,
    button2 = NO,
    OnAccept = function() ns.Combat.ResetData() end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,   -- 避開暴雪那個會 taint 的預設索引（老慣例）
}

local function Ask(instanceName)
    local text = ns.L["Entering %s. Reset the damage meter?"]
    StaticPopup_Show(POPUP, text:format(instanceName or "?"))
end

------------------------------------------------------------
-- 處理一趟「新的一趟開始了」
------------------------------------------------------------
local function Handle(instanceName)
    local s = ns.DB.Style()
    local mode = s and s.autoReset or "ask"
    if mode == "off" then return end

    -- 戰鬥中先押著：zone in 直接開打是常態，這時候跳確認只會擋事
    if InCombatLockdown() then
        _pending = instanceName or true
        return
    end
    _pending = nil

    -- 沒有資料可重置就不要問 —— 答案不影響任何事
    if not HasData() then return end

    if mode == "auto" then
        ns.Combat.ResetData()
    else
        Ask(instanceName)
    end
end

------------------------------------------------------------
-- 事件
------------------------------------------------------------
local f = CreateFrame("Frame")

local function OnEvent(_, event, isInitialLogin, isReloadingUi)
    if event == "PLAYER_REGEN_ENABLED" then
        -- 戰鬥中押下來的，現在補做
        if _pending then
            local name = (_pending ~= true) and _pending or nil
            _pending = nil
            Handle(name)
        end
        -- 沒答的提示到這時候已經過期了，收掉
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        -- 開打了，還掛著的確認已經沒有意義 —— 留著只會變成一個過期的彈窗
        StaticPopup_Hide(POPUP)
        return
    end

    local acc = ns.DB.Account()
    if not acc then return end

    if event == "CHALLENGE_MODE_START" then
        -- 鑰石開始就是新的一趟，即使副本跟上一趟相同
        local key, name = InstanceKey()
        acc.lastInstanceKey = key or acc.lastInstanceKey
        Handle(name)
        return
    end

    -- PLAYER_ENTERING_WORLD
    local key, name = InstanceKey()
    if not key then
        -- 出了副本：清掉記錄，下次進副本（即使是同一個）就算新的一趟
        acc.lastInstanceKey = nil
        return
    end
    -- 登入／重載只記錄不打擾：在團隊裡重載一次就被問一次很煩
    if isInitialLogin or isReloadingUi then
        acc.lastInstanceKey = key
        return
    end
    if acc.lastInstanceKey == key then return end
    acc.lastInstanceKey = key
    Handle(name)
end

ns.RegisterCallback("Init", "autoreset", function()
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("CHALLENGE_MODE_START")
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function(...)
        xpcall(OnEvent, ns.ReportError, ...)
    end)
end)
