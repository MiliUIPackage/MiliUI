------------------------------------------------------------
-- MiliUI: 任務多選獎勵標出「賣給商人最值錢」的那件
--
-- 交任務、獎勵可以挑一件的時候，在商人售價（單價 × 數量）最高的那一格畫一圈金框。
-- 只是標記，不替玩家選 —— 自動交任務遇到多選本來就停下來留給玩家（Enhance/
-- Quest_Automation.lua、MiliUI_QuestTracker 的 AutoQuest 都一樣），這裡補上「該選哪件」
-- 的參考。同價就全部標；售價全是 0（不能賣）就不標。
-- 讀寫於 MiliUI_DB.questRewardValue（boolean，預設 true）。
--
-- ## 範圍
--
-- 只管任務視窗（QuestFrame 的詳情頁與領獎頁，`QuestInfoFrame.questLog` 為假的那條路）。
-- 任務日誌／地圖的詳情走 GetQuestLogChoiceInfo，按鈕 ID 是「物品類獎勵的序號」而不是
-- 選項序號（Blizzard_UIPanels_Game/Mainline/QuestInfo.lua:784-794），兩套索引混在一起
-- 只為了「還沒交的任務先看看」不值得。
--
-- ## taint 紀律
--
--   * 掛點是全域函式 `QuestInfo_ShowRewards` 的 hooksecurefunc（排完獎勵格之後），
--     外加 QuestFrame 的 HookScript("OnHide") 收框。兩者都是安全掛勾，不在暴雪框上寫欄位。
--   * 獎勵格只讀：`button.type`／`button.objectType`（暴雪寫的）、`GetID()`、`IsShown()`。
--   * 金框是自己建的子框，參照存在自己的表裡（key 是按鈕），不寫 `button.xxx`。
--   * 刷新延一幀（C_Timer.After 0）：掛勾當下暴雪還在同一趟排版裡，讀到的位置／顯示狀態
--     不一定是最終值；也讓同一幀內的多次觸發只算一次。
--   * 售價讀不到（物品資料還沒快取）就整組不標、請求資料後等 GET_ITEM_INFO_RECEIVED 重算，
--     不拿部分資料猜贏家。
------------------------------------------------------------
local _, ns = ...

local BORDER = { 1, 0.82, 0, 0.95 }     -- 跟共用層 W.fontEmphasis 同一個黃
local FILL   = { 1, 0.82, 0, 0.10 }

local function GetDB()
    if not MiliUI_DB then MiliUI_DB = {} end
    if MiliUI_DB.questRewardValue == nil then MiliUI_DB.questRewardValue = true end
    return MiliUI_DB
end

local function IsEnabled() return GetDB().questRewardValue and true or false end

local function Plain(v)
    return not (issecretvalue and issecretvalue(v))
end

------------------------------------------------------------
-- 金框（每顆獎勵格一個，懶建、重用）
------------------------------------------------------------
local marks = setmetatable({}, { __mode = "k" })

local function GetMark(button)
    local m = marks[button]
    if m then return m end
    m = CreateFrame("Frame", nil, button)
    m:SetAllPoints(button)
    m:EnableMouse(false)
    local fill = m:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(unpack(FILL))
    local function Edge(p1, p2, horizontal)
        local t = m:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(unpack(BORDER))
        t:SetPoint(p1)
        t:SetPoint(p2)
        if horizontal then
            PixelUtil.SetHeight(t, 1)
        else
            PixelUtil.SetWidth(t, 1)
        end
    end
    Edge("TOPLEFT", "TOPRIGHT", true)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
    Edge("TOPLEFT", "BOTTOMLEFT", false)
    Edge("TOPRIGHT", "BOTTOMRIGHT", false)
    m:Hide()
    marks[button] = m
    return m
end

local function HideAll()
    for _, m in pairs(marks) do m:Hide() end
end

------------------------------------------------------------
-- 算出每個選項的總售價；任何一件讀不到就回 nil（整組不標）
------------------------------------------------------------
local pendingItems = {}     -- 等快取的 itemID，GET_ITEM_INFO_RECEIVED 對到才重算
local ev = CreateFrame("Frame")

local function ChoicePrices()
    local count = GetNumQuestChoices and GetNumQuestChoices()
    if not Plain(count) or type(count) ~= "number" or count <= 1 then return nil end

    local prices, best, waiting = {}, 0, false
    for i = 1, count do
        local lootType = GetQuestItemInfoLootType and GetQuestItemInfoLootType("choice", i) or 0
        if not Plain(lootType) then return nil end
        -- 0 = 物品；1 = 通貨（沒有售價，跳過不算）；其他型別不認得就整組放棄
        if lootType == 0 then
            local _, _, quantity, _, _, itemID = GetQuestItemInfo("choice", i)
            local link = GetQuestItemLink("choice", i)
            if not Plain(quantity) or not Plain(link) or not Plain(itemID) then return nil end
            local price = link and select(11, C_Item.GetItemInfo(link))
            if not Plain(price) then return nil end
            if type(price) ~= "number" then
                if type(itemID) == "number" and itemID > 0 then
                    pendingItems[itemID] = true
                    C_Item.RequestLoadItemDataByID(itemID)
                end
                waiting = true
            else
                local total = price * (tonumber(quantity) or 1)
                prices[i] = total
                if total > best then best = total end
            end
        elseif lootType ~= 1 then
            return nil
        end
    end
    if waiting then
        ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        return nil
    end
    if best <= 0 then return nil end
    return prices, best
end

local function QuestWindowShowing()
    local f = _G.QuestFrame
    if not f or not f:IsShown() then return false end
    local info = _G.QuestInfoFrame
    return info and not info.questLog
end

local function Refresh()
    HideAll()
    if not IsEnabled() or not QuestWindowShowing() then return end
    local prices, best = ChoicePrices()
    if not prices then return end
    local rewards = _G.QuestInfoRewardsFrame
    local buttons = rewards and rewards.RewardButtons
    if type(buttons) ~= "table" then return end
    for _, button in ipairs(buttons) do
        if button:IsShown() and button.type == "choice" and button.objectType == "item" then
            local id = button:GetID()
            if Plain(id) and prices[id] == best then GetMark(button):Show() end
        end
    end
end

local queued = false
local function Queue()
    if queued then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        Refresh()
    end)
end

ev:SetScript("OnEvent", function(self, event, itemID)
    if event == "GET_ITEM_INFO_RECEIVED" then
        if not pendingItems[itemID] then return end
        pendingItems[itemID] = nil
        if next(pendingItems) == nil then self:UnregisterEvent(event) end
        Queue()
    elseif event == "PLAYER_LOGIN" then
        self:UnregisterEvent(event)
        if type(_G.QuestInfo_ShowRewards) == "function" then
            hooksecurefunc("QuestInfo_ShowRewards", Queue)
        end
        if _G.QuestFrame then
            _G.QuestFrame:HookScript("OnHide", function()
                HideAll()
                wipe(pendingItems)
                ev:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
            end)
        end
    end
end)
ev:RegisterEvent("PLAYER_LOGIN")

------------------------------------------------------------
-- 對外（給 Options/Tab_QoL.lua 用）
------------------------------------------------------------
ns.QuestRewardValue = {
    IsEnabled = IsEnabled,
    SetEnabled = function(v)
        GetDB().questRewardValue = v and true or false
        Queue()
    end,
}
