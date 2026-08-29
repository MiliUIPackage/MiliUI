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
    if GossipHasSpecialOption() then return end

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
            if Cfg().preventMulti and #available > 1 then return end
            if available[1].questID then
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
-- 事件
------------------------------------------------------------
local function OnEvent(_, event)
    if not ns.db then return end

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
        if alreadyInLog then
            CloseQuest()
        else
            AcceptQuest()
        end

    elseif event == "QUEST_ACCEPT_CONFIRM" then
        -- 隊友分享的護送任務會多問一次
        if not CanAccept() then return end
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
