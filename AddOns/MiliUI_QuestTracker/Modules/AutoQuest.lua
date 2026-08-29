------------------------------------------------------------
-- 自動接任務／自動交任務
--
-- 完整的一趟交任務是四段，少一段就會停在半路等玩家點：
--   GOSSIP_SHOW / QUEST_GREETING  選到那個任務
--   QUEST_PROGRESS                「繼續」
--   QUEST_COMPLETE                 領獎勵
-- 接任務則是 QUEST_DETAIL（＋護送類的 QUEST_ACCEPT_CONFIRM）。
--
-- ⚠ **刻意不處理 QUEST_AUTOCOMPLETE。** 那條要呼叫 ShowQuestComplete()，而它會跑
--    暴雪的任務完成面板流程 —— 包含 ShowUIPanel 與往世界地圖框寫 UIPanel 屬性。
--    從插件的執行環境跑一次，那份狀態之後每次開地圖都會被讀到，戰鬥中的地圖圖釘
--    就會開始被封鎖。追蹤器上本來就有暴雪自己的「自動完成」彈窗，玩家點一下即可，
--    而且點完之後底下的 QUEST_COMPLETE 照樣會幫他領獎勵。
--
-- ⚠ 這裡完全不用 UnitGUID 記 NPC。12.1 之後 GUID 可能是秘密值，拿去當 table 的
--    key 會直接丟「cannot be indexed with secret keys」。「同一個 NPC 有多個任務
--    就別亂挑」用「可接任務不只一個就不挑」表達，語意一樣而且不必記住任何人。
------------------------------------------------------------
local _, ns = ...

ns.AutoQuest = {}
local AQ = ns.AutoQuest

local function Cfg() return ns.db and ns.db.automation end

-- 等「任務資料到齊」的上限。到了還沒等到就照樣按下去 —— 寧可失敗一次，
-- 也不要靜靜地不接。這是安全網，正常情況下不會走到。
-- /mquest delay <秒> 可以臨時改（session 內有效、不存檔）。
AQ.acceptTimeout = 1.5

-- 按下去之後多久查勤「到底接到了沒有」。要比伺服器來回久、又要短到玩家還沒走開
local VERIFY_AFTER = 0.8

------------------------------------------------------------
-- 事件追蹤（/mquest trace 開關，session 內有效、不存檔）
--
-- 「第一次必定失敗、第二次成功」這種**確定性**的症狀，猜是沒有用的 —— 要知道
-- 每一個事件當下的實際狀態，以及我們走了哪一條分支。開著它跑一次，把輸出貼回來。
------------------------------------------------------------
AQ.trace = false

local function Trace(fmt, ...)
    if not AQ.trace then return end
    local ok, line = pcall(string.format, fmt, ...)
    ns.Print("|cff88ccff[trace]|r " .. (ok and line or fmt))
end

-- 秘密值不能 tostring，任何從遊戲拿到的字串都先過這裡
local function Safe(v)
    if v == nil then return "nil" end
    if ns.Secret.IsSecret(v) then return "<secret>" end
    return tostring(v)
end

------------------------------------------------------------
-- 追蹤期間順便聽伺服器的紅字／黃字
--
-- ⚠ 這是一開始就該加的。伺服器拒絕一個動作時多半會送一則 UI_ERROR_MESSAGE
--   說原因（任務日誌滿了、不符合條件、已經接過…），而我們四輪都在猜「我們做錯
--   什麼」，完全沒去聽它有沒有直接講答案。
--
--   只在 trace 開著時註冊：UI_ERROR_MESSAGE 在戰鬥中很吵，平常不需要付這個派送成本。
local msgFrame

local function SetMessageCapture(on)
    if on then
        if not msgFrame then
            msgFrame = CreateFrame("Frame")
            msgFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
                -- arg1 是錯誤代碼、arg2 才是文字（UI_INFO_MESSAGE 同形）
                Trace("|cffff6666<%s>|r %s", event, Safe(arg2 or arg1))
            end)
        end
        msgFrame:RegisterEvent("UI_ERROR_MESSAGE")
        msgFrame:RegisterEvent("UI_INFO_MESSAGE")
    elseif msgFrame then
        msgFrame:UnregisterAllEvents()
    end
end
AQ.SetMessageCapture = SetMessageCapture

local function Paused()
    local c = Cfg()
    if not c then return true end
    return c.shiftSkip and IsShiftKeyDown()
end

------------------------------------------------------------
-- 「這個任務要花錢才能交」的守衛
--
-- 誤交一個要收金幣或貨幣的任務是**不可逆**的，所以這道閘預設開著。
-- 判斷方式跟暴雪面板看到的一致：需要的金錢直接問 API，需要的物品／貨幣則看
-- 進度頁上那幾格擺了什麼（那是唯讀，不會沾到任何東西）。
------------------------------------------------------------
local function QuestCostsSomething()
    if GetQuestMoneyToGet and (GetQuestMoneyToGet() or 0) > 0 then return true end
    for i = 1, 6 do
        local slot = _G["QuestProgressItem" .. i]
        if slot and slot:IsShown() and slot.type == "required" then
            if slot.objectType == "currency" then return true end
            if slot.objectType == "item" then
                -- 專業材料交出去跟花錢同一級：那些是拿去做東西的，不是任務道具
                local _, _, _, _, _, itemID = GetQuestItemInfo("required", i)
                if itemID then
                    local isReagent = select(17, C_Item.GetItemInfo(itemID))
                    if isReagent then return true end
                end
            end
        end
    end
    return false
end

local function CanTurnIn()
    local c = Cfg()
    if not c.autoTurnIn then return false end
    if Paused() then return false end
    if c.skipCostQuests and QuestCostsSomething() then return false end
    return true
end

local function CanAccept()
    local c = Cfg()
    if not c.autoAccept then return false end
    if Paused() then return false end
    return true
end

------------------------------------------------------------
-- 對話視窗
--
-- 對話選項裡出現帶顏色碼或角括號的項目時整個不動 —— 那是「跳過劇情」「換陣營」
-- 這類一按就回不去的特殊選項出現的場合，自動點任務很容易連帶把玩家推進去。
------------------------------------------------------------
local function GossipHasSpecialOption()
    if not (C_GossipInfo and C_GossipInfo.GetOptions) then return false end
    local options = C_GossipInfo.GetOptions()
    if type(options) ~= "table" then return false end
    for _, opt in ipairs(options) do
        local name = opt.name
        if type(name) == "string" and (name:find("|c", 1, true) or name:find("<", 1, true)) then
            return true
        end
    end
    return false
end

local function HandleGossip()
    if AQ.trace then
        local avail = C_GossipInfo.GetAvailableQuests and C_GossipInfo.GetAvailableQuests()
        local active = C_GossipInfo.GetActiveQuests and C_GossipInfo.GetActiveQuests()
        local opts = C_GossipInfo.GetOptions and C_GossipInfo.GetOptions()
        Trace("GOSSIP_SHOW  可接=%d 進行中=%d 對話選項=%d  autoAccept=%s preventMulti=%s shift=%s",
            avail and #avail or -1, active and #active or -1, opts and #opts or -1,
            Safe(Cfg().autoAccept), Safe(Cfg().preventMulti), Safe(IsShiftKeyDown()))
        if avail then
            for i, q in ipairs(avail) do
                Trace("   可接[%d] id=%s freq=%s trivial=%s",
                    i, Safe(q.questID), Safe(q.frequency), Safe(q.isTrivial))
            end
        end
    end

    if GossipHasSpecialOption() then
        Trace("GOSSIP：對話裡有帶色碼／角括號的選項 ⇒ 整個不動作")
        return
    end

    if CanTurnIn() and C_GossipInfo.GetActiveQuests then
        local active = C_GossipInfo.GetActiveQuests()
        if type(active) == "table" then
            for _, quest in ipairs(active) do
                if quest.isComplete and quest.questID then
                    C_GossipInfo.SelectActiveQuest(quest.questID)
                    return
                end
            end
        end
    end

    if CanAccept() and C_GossipInfo.GetAvailableQuests then
        local available = C_GossipInfo.GetAvailableQuests()
        if type(available) == "table" and #available > 0 then
            -- 不只一個可接時讓玩家自己挑：自動挑第一個等於幫他決定接哪一條
            if Cfg().preventMulti and #available > 1 then
                Trace("GOSSIP：可接任務有 %d 個 ⇒ 不自動挑（preventMulti）", #available)
                return
            end
            if available[1].questID then
                Trace("GOSSIP：SelectAvailableQuest(%s)", Safe(available[1].questID))
                C_GossipInfo.SelectAvailableQuest(available[1].questID)
            end
        end
    end
end

-- 舊式的多任務 NPC 走 QUEST_GREETING，那條路是索引不是 questID
local function HandleGreeting()
    if CanTurnIn() then
        for i = 1, (GetNumActiveQuests() or 0) do
            local _, isComplete = GetActiveTitle(i)
            if isComplete then
                SelectActiveQuest(i)
                return
            end
        end
    end
    if CanAccept() then
        local n = GetNumAvailableQuests() or 0
        if n > 0 then
            if Cfg().preventMulti and n > 1 then return end
            SelectAvailableQuest(1)
        end
    end
end

------------------------------------------------------------
-- 接受任務：觀察不到就用學的
--
-- 案例：週任「至暗之夜：阿塔烏特克寶庫」(98232) 第一次接必定失敗（視窗閃一下就關、
-- 沒進日誌），第二次成功；放棄之後重演；手動點永遠第一次就成功。
--
-- 七輪實測打掉的六個假設，每一條都不要再重走：
--   1. QuestGetAutoAccept() 殘留 —— 旗標兩次都是 false。
--   2. 對話／四選一的選取邏輯 —— 這條任務完全沒有 GOSSIP_SHOW。
--   3. 我們搶在暴雪的 QuestFrame 前面 —— 兩次的 QuestFrame:IsShown() 與接受鈕的
--      顯示／可按都是 true，延後一幀沒有改善。
--   4. 合成點擊 vs 硬體點擊 —— 等 3 秒之後我們自己按也會成功。
--   5. 獎勵資料還沒到 —— 失敗與成功那兩次的
--      GetNumQuestChoices/GetNumQuestRewards/GetQuestMoneyToGet 完全一樣。
--   6. 任務資料非同步載入 —— QUEST_DATA_LOAD_RESULT 在 0.00 秒就回 success=true。
--
-- 客戶端看得到的東西兩次完全一致，唯一能改變結果的是時間（0/0.25 秒失敗、1/3 秒
-- 成功），而且第二次連 0 秒都會成功。也就是說：**有一個只有伺服器知道的暖機，
-- 客戶端沒有任何訊號。**
--
-- 所以不猜門檻，改成量：預設立刻接（多數任務本來就沒問題），接不到就把那條任務
-- 記下來，下次遇到同一條先等再接。記進 SavedVariables，所以每條問題任務**一輩子
-- 只會失敗一次**。
--
-- ⚠ 為什麼不乾脆全部都等：固定秒數是「競態條件加上額外步驟」——挑短了隨伺服器
--   狀態時好時壞（最難回報的那種 bug），挑長了每一條任務都被拖慢。
------------------------------------------------------------
local pending   -- { questID = }：等待中的那一條，用來擋掉過期的計時器

local function MarkSlow(questID)
    local db = ns.db and ns.db.slowQuests
    if not db or db[questID] then return end
    db[questID] = true
    Trace("   %s 這條接不到 ⇒ 記起來，下次先等 %.2fs", Safe(questID), AQ.acceptTimeout)
end

local function DoAccept(questID, why)
    pending = nil
    local now = GetQuestID and GetQuestID() or 0
    if now ~= questID then
        -- 分辨兩種完全不同的情況，不然這行看起來一樣：
        --   已經在日誌裡 ⇒ 有人（多半是玩家自己）在我們之前接掉了
        --   不在日誌裡   ⇒ 視窗只是關掉了，任務沒接成
        local inLog = C_QuestLog and C_QuestLog.GetLogIndexForQuestID
            and C_QuestLog.GetLogIndexForQuestID(questID)
        Trace("   questID 變成 %s（原本 %s，%s）⇒ 放棄，不亂接", Safe(now), Safe(questID),
            inLog and "已經有人接走了" or "任務沒接成，視窗被關掉了")
        return
    end

    local btn = _G.QuestFrameAcceptButton
    if btn and btn:IsShown() and btn:IsEnabled() then
        Trace("   %s ⇒ 按下暴雪的接受鈕", why)
        btn:Click()
    else
        Trace("   %s ⇒ 接受鈕不可用，退回 AcceptQuest()", why)
        AcceptQuest()
    end

    -- 按完之後查勤：沒收到 QUEST_ACCEPTED 就代表這一次白按了。
    -- 這是整個機制的核心 —— 我們沒辦法**事先**知道哪條任務需要等，但可以**事後**
    -- 知道，然後下一次就對了
    C_Timer.After(VERIFY_AFTER, function()
        local ok = C_QuestLog and C_QuestLog.GetLogIndexForQuestID
            and C_QuestLog.GetLogIndexForQuestID(questID)
        if not ok then MarkSlow(questID) end
    end)
end

local function AcceptWhenReady(questID)
    local slow = ns.db and ns.db.slowQuests and ns.db.slowQuests[questID]
    if not slow then
        DoAccept(questID, "立刻")
        return
    end
    -- 記錄在案的問題任務：先等再按
    Trace("   %s 記錄在案 ⇒ 等 %.2fs 再按", Safe(questID), AQ.acceptTimeout)
    pending = { questID = questID }
    C_Timer.After(AQ.acceptTimeout, function()
        if pending and pending.questID == questID then
            DoAccept(questID, ("等了 %.2fs"):format(AQ.acceptTimeout))
        end
    end)
end

------------------------------------------------------------
-- 事件
------------------------------------------------------------
local function OnEvent(_, event)
    if not ns.db then return end

    -- 任務互動結束就把等待作廢，免得計時器醒來時接到另一條任務
    if event == "QUEST_FINISHED" or event == "QUEST_ACCEPTED" then
        pending = nil
    end
    if AQ.trace and event ~= "GOSSIP_SHOW" and event ~= "QUEST_DETAIL" then
        Trace("%s  currentQuestID=%s", event, Safe(GetQuestID and GetQuestID()))
    end

    if event == "GOSSIP_SHOW" then
        HandleGossip()

    elseif event == "QUEST_GREETING" then
        HandleGreeting()

    elseif event == "QUEST_DETAIL" then
        if not CanAccept() then return end
        -- 遊戲已經幫忙接掉的（世界任務、飛過去自動觸發的那種）只要把視窗收起來，
        -- 再 AcceptQuest 一次會在聊天視窗留下一則沒有意義的錯誤。
        --
        -- ⚠ 但「是不是已經接了」要問**狀態**，不要問 QuestGetAutoAccept()。
        --   那支描述的是「上一次的任務詳情是不是遊戲自動接的」，而它不保證在
        --   「對話 → 選任務 → QUEST_DETAIL」這條路上被重設。讀到上一趟殘留的 true
        --   就會走 CloseQuest()：視窗關掉、任務沒接 —— 症狀正是「第一次沒接到、
        --   再點一次就成功」。
        --
        --   改問「這個任務現在在不在我的任務日誌裡」。GetQuestID() 在 QUEST_DETAIL
        --   當下有效（12.1 仍在），而任務日誌是當下的事實，不會殘留上一趟的狀態。
        --   萬一 GetQuestID() 回 0，判斷會落到「不在日誌裡」⇒ 照樣 AcceptQuest()。
        --   那是比較好的失敗方向：自動接任務寧可多按一次，也不要靜靜地不接。
        local questID = GetQuestID and GetQuestID() or 0
        local alreadyInLog = questID ~= 0
            and C_QuestLog and C_QuestLog.GetLogIndexForQuestID
            and C_QuestLog.GetLogIndexForQuestID(questID)
        local qf = _G.QuestFrame
        local accept = _G.QuestFrameAcceptButton
        Trace("QUEST_DETAIL id=%s 標題=%s 日誌索引=%s QuestFrame顯示=%s 接受鈕顯示=%s/可按=%s ⇒ %s",
            Safe(questID), Safe(GetTitleText and GetTitleText()), Safe(alreadyInLog),
            Safe(qf and qf:IsShown()),
            Safe(accept and accept:IsShown()), Safe(accept and accept:IsEnabled()),
            alreadyInLog and "CloseQuest" or "延後後按接受鈕")

        if alreadyInLog then
            CloseQuest()
            return
        end

        -- 多數任務立刻接就好；少數不行的會被記下來、下次先等。
        -- 為什麼是這個形狀（以及六條走不通的路），寫在 AcceptWhenReady() 上面
        AcceptWhenReady(questID)
    elseif event == "QUEST_ACCEPT_CONFIRM" then
        -- 隊友分享的護送任務會多問一次
        if not CanAccept() then return end
        Trace("QUEST_ACCEPT_CONFIRM ⇒ ConfirmAcceptQuest")
        ConfirmAcceptQuest()
        StaticPopup_Hide("QUEST_ACCEPT")

    elseif event == "QUEST_PROGRESS" then
        if not CanTurnIn() then return end
        if IsQuestCompletable and IsQuestCompletable() then
            CompleteQuest()
        end

    elseif event == "QUEST_COMPLETE" then
        if not CanTurnIn() then return end
        -- 有得選的時候絕對不要幫玩家選。GetNumQuestChoices() 是 0（沒有選擇獎勵）
        -- 或 1（只有一個，等於沒得選）才動手
        local choices = GetNumQuestChoices() or 0
        if choices <= 1 then
            GetQuestReward(choices)
        end
    end
end

------------------------------------------------------------
-- 跟 Leatrix Plus 撞車的偵測
--
-- Leatrix 的執行期設定表是檔案內的 local，外面拿不到，所以沒辦法「幫他關掉」，
-- 也沒辦法即時同步 —— 只能讀他的 SavedVariables。那份是登入當下的值，玩家在
-- 遊戲中改了要等下次 /reload 我們才看得到，所以文案要講清楚是登入時的狀態。
--
-- ⚠ 米利UI 套組已經不內附 Leatrix Plus（2026-08-29 移除），這段仍然要留著：
--   玩家自己裝回來時 LeaPlusDB 才會存在，沒裝就靜音（同
--   MiliUI/Enhance/Merchant_Automation.lua 的判斷）。
------------------------------------------------------------
function AQ.LeatrixConflict()
    local db = _G.LeaPlusDB
    if type(db) ~= "table" then return nil end
    if db.AutomateQuests ~= "On" then return nil end
    local accept = db.AutoQuestRegular == "On"
        or db.AutoQuestDaily == "On"
        or db.AutoQuestWeekly == "On"
    local turnIn = db.AutoQuestCompleted == "On"
    if not (accept or turnIn) then return nil end
    return { accept = accept, turnIn = turnIn }
end

ns.RegisterCallback("Init", "autoquest", function()
    local evt = CreateFrame("Frame")
    for _, e in ipairs({
        "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_ACCEPT_CONFIRM",
        "QUEST_PROGRESS", "QUEST_COMPLETE",
        -- 下面這些我們沒有對應的分支，純粹是為了讓 /mquest trace 看得到完整時序：
        -- 「第一次失敗」很可能就發生在這幾個事件之間。
        -- ⚠ QUEST_REMOVED 是刻意加的：要排除「其實接到了、但馬上又被拿掉」這種
        --    可能 —— 那跟「根本沒接到」在畫面上長得一模一樣，但成因完全不同。
        "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_FINISHED", "GOSSIP_CLOSED",
    }) do
        evt:RegisterEvent(e)
    end
    evt:SetScript("OnEvent", OnEvent)

    -- 兩邊都開著的話會各自呼叫一次 AcceptQuest／GetQuestReward。第二次多半是
    -- 空包彈，但玩家看到的是「偶爾跳錯誤訊息」，不講他不會知道原因。
    -- 延後幾秒再說，不然會淹在登入時的一堆插件訊息裡
    C_Timer.After(8, function()
        local conflict = AQ.LeatrixConflict()
        if not conflict then return end
        local mine = Cfg()
        if not (mine.autoTurnIn or mine.autoAccept) then return end
        ns.Print("|cffff9900" .. ns.L["Leatrix Plus is also automating quests. Turn one of the two off, or they will both answer the same NPC."] .. "|r")
    end)
end)
