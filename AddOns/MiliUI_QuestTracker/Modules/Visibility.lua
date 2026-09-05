------------------------------------------------------------
-- 什麼時候該把清單摺起來
--
-- 兩個來源疊在一起：
--   * 手動 —— 玩家自己點標題列。這是一個明確的意圖，所以存檔，重載之後還在。
--   * 自動 —— 情境條件（團本首領戰之類）。這是暫時狀態，離開該情境就自己展開，
--             永遠不寫進存檔，否則玩家會發現「打完王之後清單再也回不來」。
--
-- 自動摺疊期間手動展開叫做「偷看」：這一趟保持展開，但**下一次**自動條件重新
-- 成立時再摺一次。沒有這層的話只有兩種都不好的行為——手動展開被下一幀的自動
-- 條件立刻摺回去（按鈕像壞的），或是偷看一次就永久關掉自動摺疊。
------------------------------------------------------------
local _, ns = ...

ns.Visibility = {}
local V = ns.Visibility
local T = ns.Tracker

local folded      = false   -- 目前實際狀態
local autoActive  = false   -- 上一次算出來的自動條件
local peeking     = false   -- 自動摺疊期間玩家手動展開了

-- GetInstanceInfo 每次評估都問一遍太浪費（戰鬥開始／結束都會走到這裡），
-- 而副本類型只在換區域時會變
local instanceType = "none"
local inEncounter  = false

local function RefreshInstanceType()
    instanceType = select(2, GetInstanceInfo()) or "none"
end

local function ComputeAuto()
    local v = ns.db and ns.db.visibility
    if not v then return false end

    if v.combat and InCombatLockdown() then return true end
    if v.arena and instanceType == "arena" then return true end
    if v.battleground and instanceType == "pvp" then return true end
    if v.raid and instanceType == "raid" then return true end
    if v.raidBoss and instanceType == "raid" and inEncounter then return true end
    if v.dungeon and instanceType == "party" then return true end
    if v.mythicPlus then
        -- 面板模組用副本資訊判斷（打完鑰石到出副本之前都算），跟面板同一個口徑；
        -- 它還沒載入時退回 IsChallengeModeActive
        if ns.MythicPlus and ns.MythicPlus.IsInChallenge() then return true end
        if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive
           and C_ChallengeMode.IsChallengeModeActive() then
            return true
        end
    end
    return false
end

function V.IsFolded() return folded end

function V.Evaluate()
    if not ns.db then return end
    local auto = ComputeAuto()

    -- 自動條件從「不成立」翻成「成立」＝新的一次自動摺疊，上一趟的偷看到此為止
    if auto and not autoActive then peeking = false end
    autoActive = auto

    local want = ns.db.folded or (auto and not peeking)
    if want == folded then return end
    folded = want
    T.SetHidden(folded)
    ns.Fire("FoldChanged", folded)
end

function V.ToggleManualFold()
    if not ns.db then return end
    if folded then
        ns.db.folded = false
        -- 自動條件還成立的話，這次展開只算偷看，不要把它記成永久偏好
        if autoActive then peeking = true end
    else
        ns.db.folded = true
        peeking = false
    end
    V.Evaluate()
end

------------------------------------------------------------
-- 事件
------------------------------------------------------------
ns.RegisterCallback("Init", "visibility", function()
    RefreshInstanceType()

    local evt = CreateFrame("Frame")
    for _, e in ipairs({
        "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
        "ENCOUNTER_START", "ENCOUNTER_END",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET",
    }) do
        evt:RegisterEvent(e)
    end
    evt:SetScript("OnEvent", function(_, event)
        if event == "ENCOUNTER_START" then
            inEncounter = true
        elseif event == "ENCOUNTER_END" then
            inEncounter = false
        elseif event == "PLAYER_ENTERING_WORLD" then
            -- 漏掉的 ENCOUNTER_END（傳送出去、斷線重連）會讓旗標卡在 true，
            -- 之後整趟都摺著。換場景一律清乾淨
            inEncounter = false
            RefreshInstanceType()
        elseif event == "ZONE_CHANGED_NEW_AREA" then
            RefreshInstanceType()
        end
        V.Evaluate()
    end)

    -- 存檔裡摺著就先摺起來。⚠ 直接呼叫 Evaluate 而不是等事件：登入時
    -- PLAYER_ENTERING_WORLD 已經在我們註冊之前派送過了
    if ns.db.folded then
        folded = false          -- 逼 Evaluate 看到狀態有變，真的去執行隱藏
        V.Evaluate()
    end
end)

ns.RegisterCallback("Apply", "visibility", function()
    V.Evaluate()
end)
