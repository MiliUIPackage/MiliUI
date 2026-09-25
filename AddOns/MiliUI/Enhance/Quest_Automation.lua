------------------------------------------------------------
-- MiliUI: 自動交接任務（基本型）
--
-- ── 跟米利的任務追蹤器的分工 ──
-- 進階型在 MiliUI_QuestTracker/Modules/AutoQuest.lua（多選一不挑、要花錢的不交、
-- 接不到的任務記起來下次先等…）。同一時間只有一邊在做：
--   * 任務追蹤器有載入 ⇒ 這支**完全不註冊任務事件**。設定頁的兩個開關透過
--     MiliUI_QuestAutomation 讀寫任務追蹤器那份，這裡的 MiliUI_DB.quest 只是鏡像，
--     哪天任務追蹤器被停用，就從鏡像接著用。
--   * 沒有任務追蹤器 ⇒ 這支用 MiliUI_DB.quest 做最基本的交任務／接任務。
-- ⚠ 判準是「MiliUI_QuestAutomation 那張表在不在」（任務追蹤器的 Api.lua 定義）。
--   它在檔案層就建好，所以本體 PLAYER_LOGIN 時一定看得到；但任務追蹤器的 ns.db
--   要等它自己的 PLAYER_LOGIN，讀寫設定的同步要延一幀。
--
-- ── 基本型做什麼 ──
--   交：對話裡選已完成的任務 →「繼續」→ 領獎勵（有得選的獎勵一律留給玩家）
--   接：對話裡只有一個可接任務才選 → 任務詳情頁按接受 → 護送類的確認
-- 不管怎樣都留著的閘（不開放設定，基本型就是這樣）：
--   * 按住 Shift 這一次不動作
--   * 對話選項有色碼或角括號（跳過劇情、換陣營這類按了回不去的）整個不動
--   * 要收金幣才能交的不交——誤交不可逆
--   * 可接任務不只一個不挑——自動挑第一個等於幫玩家決定
--
-- ⚠ 刻意不處理 QUEST_AUTOCOMPLETE：ShowQuestComplete() 會跑暴雪的任務面板流程、
--   往世界地圖框寫 UIPanel 屬性，從插件執行一次之後戰鬥中的地圖圖釘會被封鎖
--   （同任務追蹤器的註解）。
-- ⚠ 不記 NPC 的 GUID：12.1 之後可能是秘密值，當 table key 會崩潰。
-- ⚠ 少數任務（週任居多）詳情頁一出來就接會被伺服器丟掉，要再點一次。基本型不處理，
--   「記住哪些任務要先等」是任務追蹤器的進階功能。
------------------------------------------------------------
local _, ns = ...

local function GetDB()
    if not MiliUI_DB then MiliUI_DB = {} end
    local db = MiliUI_DB.quest
    if type(db) ~= "table" then
        db = {}
        MiliUI_DB.quest = db
    end
    -- 預設開，跟任務追蹤器的預設一致
    if db.autoTurnIn == nil then db.autoTurnIn = true end
    if db.autoAccept == nil then db.autoAccept = true end
    return db
end

local function Advanced()
    local api = _G.MiliUI_QuestAutomation
    if type(api) == "table" and type(api.IsAutoTurnIn) == "function"
        and type(api.SetAutoTurnIn) == "function" then
        return api
    end
end

------------------------------------------------------------
-- 設定（任務追蹤器在就讀寫它那份，順手抄一份鏡像）
------------------------------------------------------------
local function IsTurnIn()
    local adv = Advanced()
    if adv and adv.IsReady() then return adv.IsAutoTurnIn() end
    return GetDB().autoTurnIn
end

local function IsAccept()
    local adv = Advanced()
    if adv and adv.IsReady() then return adv.IsAutoAccept() end
    return GetDB().autoAccept
end

-- dirty：任務追蹤器不在的時候改過 ⇒ 下次它回來時把這邊的值推過去。
-- 沒改過就反過來以它為準（它那邊可能在標題列上被切過）。
local function SetTurnIn(v)
    v = v and true or false
    local db, adv = GetDB(), Advanced()
    db.autoTurnIn = v
    if adv and adv.IsReady() then adv.SetAutoTurnIn(v) else db.dirty = true end
end

local function SetAccept(v)
    v = v and true or false
    local db, adv = GetDB(), Advanced()
    db.autoAccept = v
    if adv and adv.IsReady() then adv.SetAutoAccept(v) else db.dirty = true end
end

local function SyncWithAdvanced()
    local adv = Advanced()
    if not (adv and adv.IsReady()) then return end
    local db = GetDB()
    if db.dirty then
        adv.SetAutoTurnIn(db.autoTurnIn)
        adv.SetAutoAccept(db.autoAccept)
        db.dirty = nil
    else
        db.autoTurnIn = adv.IsAutoTurnIn()
        db.autoAccept = adv.IsAutoAccept()
    end
end

------------------------------------------------------------
-- 閘
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

local function CanTurnIn()
    return GetDB().autoTurnIn and not IsShiftKeyDown()
end

local function CanAccept()
    return GetDB().autoAccept and not IsShiftKeyDown()
end

------------------------------------------------------------
-- 事件
------------------------------------------------------------
local function HandleGossip()
    if GossipHasSpecialOption() then return end

    if CanTurnIn() then
        for _, quest in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
            if quest.isComplete and quest.questID then
                C_GossipInfo.SelectActiveQuest(quest.questID)
                return
            end
        end
    end

    if CanAccept() then
        local available = C_GossipInfo.GetAvailableQuests() or {}
        if #available == 1 and available[1].questID then
            C_GossipInfo.SelectAvailableQuest(available[1].questID)
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
    if CanAccept() and (GetNumAvailableQuests() or 0) == 1 then
        SelectAvailableQuest(1)
    end
end

local function HandleDetail()
    if not CanAccept() then return end
    -- 遊戲已經幫忙接掉的（世界任務那類）只要收視窗。
    -- ⚠ 問任務日誌，不要問 QuestGetAutoAccept()：那支會殘留上一趟的 true，
    --   讀到就變成視窗關掉、任務沒接。
    local questID = GetQuestID and GetQuestID() or 0
    if questID ~= 0 and C_QuestLog.GetLogIndexForQuestID(questID) then
        CloseQuest()
        return
    end
    -- 走暴雪自己的接受鈕：PvP 任務的確認彈窗那類流程由它處理
    local btn = _G.QuestFrameAcceptButton
    if btn and btn:IsShown() and btn:IsEnabled() then
        btn:Click()
    else
        AcceptQuest()
    end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
    if event == "GOSSIP_SHOW" then
        HandleGossip()
    elseif event == "QUEST_GREETING" then
        HandleGreeting()
    elseif event == "QUEST_DETAIL" then
        HandleDetail()
    elseif event == "QUEST_ACCEPT_CONFIRM" then
        -- 隊友分享的護送任務會多問一次
        if not CanAccept() then return end
        ConfirmAcceptQuest()
        StaticPopup_Hide("QUEST_ACCEPT")
    elseif event == "QUEST_PROGRESS" then
        if not CanTurnIn() then return end
        if (GetQuestMoneyToGet() or 0) > 0 then return end
        if IsQuestCompletable() then CompleteQuest() end
    elseif event == "QUEST_COMPLETE" then
        if not CanTurnIn() then return end
        -- 0（沒得選）或 1（只有一個）才動手
        local choices = GetNumQuestChoices() or 0
        if choices <= 1 then GetQuestReward(choices) end
    end
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    GetDB()
    if Advanced() then
        -- 任務追蹤器接手：這支一個任務事件都不聽。它的 ns.db 在它自己的
        -- PLAYER_LOGIN 才建，延一幀再對設定
        C_Timer.After(0, SyncWithAdvanced)
        return
    end
    for _, e in ipairs({ "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL",
        "QUEST_ACCEPT_CONFIRM", "QUEST_PROGRESS", "QUEST_COMPLETE" }) do
        events:RegisterEvent(e)
    end
end)

------------------------------------------------------------
-- 對外 API（給 Options/Tab_QoL.lua）
------------------------------------------------------------
MiliUI_QuestBasic = {
    IsAutoTurnIn = IsTurnIn,
    SetAutoTurnIn = SetTurnIn,
    IsAutoAccept = IsAccept,
    SetAutoAccept = SetAccept,
    -- 任務追蹤器有載入 ⇒ 設定頁要多一顆「進階設定」按鈕
    Advanced = Advanced,
}
