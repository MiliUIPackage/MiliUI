------------------------------------------------------------
-- 拍賣場：搜尋報價 ＋ 購買（一律要按確認才成交）
--
-- 節流：拍賣場的查詢有伺服器節流，沒準備好就送會被丟掉。所有查詢都排進佇列，
-- 由 AUCTION_HOUSE_THROTTLED_SYSTEM_READY 放行。
--
-- ⚠⚠ `StartCommoditiesPurchase` / `ConfirmCommoditiesPurchase` 是**硬體事件閘**
--     底下的保護函式：只有在玩家「這一下點擊」的執行流裡呼叫才會放行，從事件
--     處理器（搜尋結果回來、上一筆買完）裡呼叫會直接被擋下，聊天列跳
--     `ADDON_ACTION_BLOCKED: StartCommoditiesPurchase()`（實測 2026-09-09）。
--     所以**買東西不可能全自動串接**，每一筆都要玩家自己按一下。這支的設計就是
--     照這個限制長的：插件負責把「下一步該按哪裡」端到同一個位置，不代按。
--
-- ⚠ 這支跟原作最大的差別：**沒有自動確認**。
--   商品：StartCommoditiesPurchase → COMMODITY_PRICE_UPDATED 拿到單價與總價
--         → 顯示確認列 → 玩家按確認才 ConfirmCommoditiesPurchase。
--   非商品：讀第一筆的一口價 → 顯示確認列 → 按確認才 PlaceBid。
--   花錢的動作永遠隔著一次明確的點擊，插件不會替玩家決定。
------------------------------------------------------------
local _, ns = ...

ns.Auction = {}
local Auction = ns.Auction
local L = ns.L

local PRICE_SORTS = {
    { sortOrder = Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price or 0, reverseSort = false },
}

-- 整批 SearchForItemKeys 的上限（暴雪端的硬限制）
local MAX_KEYS = 100

------------------------------------------------------------
-- 本次登入的狀態。**一律不進 SavedVariables**：報價幾分鐘就過期，
-- 存下來只會讓玩家照著昨天的價格做決定。
------------------------------------------------------------
local quotes  = {}   -- [itemID] = { unitPrice, quantity, isCommodity, itemKey, auctionID }
-- ⚠ [itemID] = true 代表「跑過**單筆**查詢、拿到逐筆掛單資料」。
--   整批瀏覽（SearchForItemKeys）只給均價與總量，**不夠買**：它不告訴你這件東西
--   是不是商品（isCommodity），GetItemSearchResultInfo 也讀不到東西 ——
--   直接照那份資料走非商品路徑，會得到「拍賣場上沒有人賣」的假結論（實測）。
local detailed = {}
local lowest  = {}   -- [itemID] = 本次登入看過的最低單價（天價保險的基準）
local queue   = {}
local busy    = false
local pendingQuote        -- 已送出報價請求，等 COMMODITY_PRICE_UPDATED
local pendingConfirm      -- 等玩家按確認
local pendingSearch       -- 單筆搜尋中的 itemID
local awaitSearch         -- 搜尋結果回來要接著買的 { itemID, quantity, fromQueue }
local searchedFor = {}    -- [itemID] = 這次購買已經為了它搜過一輪了（防止一直繞回去搜）
local buyQueue, queueAt, queueTotal = {}, 0, 0
local queueWaiting = false   -- 上一筆買完了，等玩家按「下一筆」
local status  = ""

-- alert = true：這一條是「玩家要知道才動得下去」的（沒人賣、錢不夠、再按一次），
-- 除了狀態列還直接印到聊天列。狀態列那行字小又在角落，實測回報看不到。
local statusAlert = false

local function SetStatus(text, alert)
    status = text or ""
    statusAlert = alert and true or false
    if alert and text and text ~= "" then ns.Print(text) end
    ns.Fire("AuctionChanged")
end

function Auction.Status()   return status, statusAlert end
function Auction.Quote(itemID) return itemID and quotes[itemID] or nil end
function Auction.Pending()  return pendingConfirm end

-- 批次購買進行到第幾筆（確認列拿去顯示進度；沒在跑就回 nil）
function Auction.QueueInfo()
    if queueTotal == 0 then return nil end
    return queueAt, queueTotal
end

function Auction.IsBusy()   return busy or #queue > 0 end

function Auction.IsOpen()
    return AuctionHouseFrame and AuctionHouseFrame:IsShown() and true or false
end

------------------------------------------------------------
-- 節流佇列
------------------------------------------------------------
local function Ready()
    if not C_AuctionHouse.IsThrottledMessageSystemReady then return true end
    return C_AuctionHouse.IsThrottledMessageSystemReady()
end

local function Run(action)
    if not Auction.IsOpen() then return false end
    if busy or not Ready() then
        queue[#queue + 1] = action
        return true
    end
    busy = true
    action()
    return true
end

local function Pump()
    busy = false
    if #queue == 0 then return end
    if not Ready() then return end
    local action = table.remove(queue, 1)
    busy = true
    action()
end

------------------------------------------------------------
-- 收報價
------------------------------------------------------------
local function Remember(itemID, unitPrice, quantity, isCommodity, itemKey, auctionID)
    -- ⚠ 0 不是價格：整批瀏覽對沒有掛單的物品會回 0，記下去清單上就會出現
    --   「單價 0 金、在售 0」那種看起來像免費的列。
    if not itemID or not unitPrice or unitPrice <= 0 then return end
    quotes[itemID] = {
        unitPrice   = unitPrice,
        quantity    = quantity or 0,
        isCommodity = isCommodity,
        itemKey     = itemKey,
        auctionID   = auctionID,
    }
    if not lowest[itemID] or unitPrice < lowest[itemID] then
        lowest[itemID] = unitPrice
    end
end

local function StoreBrowseResults()
    local results = C_AuctionHouse.GetBrowseResults()
    if type(results) ~= "table" then return end
    for _, r in ipairs(results) do
        local itemID = r.itemKey and r.itemKey.itemID
        if itemID then
            Remember(itemID, r.minPrice, r.totalQuantity, nil, r.itemKey)
        end
    end
end

local function StoreCommodity(itemID)
    if not itemID then return end
    local count = C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0
    if count <= 0 then
        quotes[itemID] = nil
        detailed[itemID] = nil
        return
    end
    local first = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, 1)
    if not first then return end
    local listed = 0
    if C_AuctionHouse.GetCommoditySearchResultsQuantity then
        listed = C_AuctionHouse.GetCommoditySearchResultsQuantity(itemID) or 0
    end
    if listed == 0 then
        for i = 1, count do
            local info = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
            listed = listed + ((info and info.quantity) or 0)
        end
    end
    Remember(itemID, first.unitPrice, listed, true, C_AuctionHouse.MakeItemKey(itemID))
    detailed[itemID] = true
end

local function StoreItem(itemKey)
    if not itemKey or not itemKey.itemID then return end
    local count = C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
    if count <= 0 then
        quotes[itemKey.itemID] = nil
        detailed[itemKey.itemID] = nil
        return
    end
    local first = C_AuctionHouse.GetItemSearchResultInfo(itemKey, 1)
    if not first then return end
    local listed = count
    if C_AuctionHouse.GetItemSearchResultsQuantity then
        listed = C_AuctionHouse.GetItemSearchResultsQuantity(itemKey) or count
    end
    Remember(itemKey.itemID, first.buyoutAmount, listed, false, itemKey, first.auctionID)
    detailed[itemKey.itemID] = true
end

------------------------------------------------------------
-- 搜尋
------------------------------------------------------------
function Auction.SearchAll()
    if not Auction.IsOpen() then
        SetStatus(L["Open the auction house to search and buy."], true)
        return
    end
    local rows = ns.List.Shopping({ includeReady = true, allRecipes = true })
    local keys, seen = {}, {}
    for _, row in ipairs(rows) do
        -- 商店貨與玩家手動忽略的不問價：問了也是白問，還占掉 100 筆的額度
        if row.itemID and not row.vendor and not row.ignored and not seen[row.itemID] then
            seen[row.itemID] = true
            keys[#keys + 1] = C_AuctionHouse.MakeItemKey(row.itemID)
            if #keys >= MAX_KEYS then break end
        end
    end
    if #keys == 0 then
        SetStatus(L["Nothing to buy yet."], true)
        return
    end
    SetStatus(L["Searching the auction house..."])
    Run(function() C_AuctionHouse.SearchForItemKeys(keys, PRICE_SORTS) end)
end

function Auction.SearchItem(itemID)
    if not itemID then return false end
    if not Auction.IsOpen() then
        SetStatus(L["Open the auction house to search and buy."], true)
        return false
    end
    pendingSearch = itemID
    SetStatus(L["Searching the auction house..."])
    Run(function()
        C_AuctionHouse.SendSearchQuery(C_AuctionHouse.MakeItemKey(itemID), PRICE_SORTS, false)
    end)
    return true
end

------------------------------------------------------------
-- 購買
--
-- 三種點擊路徑，共用同一段狀態機：
--   單筆「購買」   → 問價 → 確認列 → 成交
--   「全部購買」   → 把清單上還缺的東西排成佇列，一筆一筆走上面那條路，
--                    每一筆都還是要玩家按確認（這點不打折），但**不用再按第一下**
--   沒有報價時     → 自己去搜，結果回來就接著問價，不要求玩家「再按一次購買」
--
-- ⚠ 原本每買一樣東西要按三下（購買 → 再按一次購買 → 確認）。中間那下純粹是
--   插件自己還沒去搜，不是玩家該處理的事；現在自動接上。剩下的一下確認是
--   刻意留的 —— 花錢的動作永遠隔著一次明確的點擊。
------------------------------------------------------------
local function Overpriced(itemID, unitPrice)
    local base = lowest[itemID]
    if not base or base <= 0 or not unitPrice then return false end
    local guard = ns.db.settings.priceGuard or 3
    return unitPrice > base * guard
end

local StepQueue   -- 前向宣告：StartBuy 失敗時要跳下一筆

local function StopQueue(text, alert)
    buyQueue, queueAt, queueTotal = {}, 0, 0
    queueWaiting = false
    awaitSearch = nil
    wipe(searchedFor)
    if text then SetStatus(text, alert) end
end

function Auction.StartBuy(itemID, quantity, fromQueue)
    if not Auction.IsOpen() then
        SetStatus(L["Open the auction house to search and buy."], true)
        return
    end
    if pendingConfirm or pendingQuote then
        SetStatus(L["Finish the purchase in front of you first."], true)
        return
    end
    quantity = math.max(1, math.floor(tonumber(quantity) or 1))
    if not fromQueue then StopQueue() end

    -- ⚠ 判準是「有沒有跑過單筆查詢」，不是「有沒有報價」。整批瀏覽來的報價
    --   夠顯示、不夠買（見 detailed 的註解）。
    if not detailed[itemID] then
        -- ⚠ 一定要記「搜過了」：不記的話搜完回來還是沒有掛單，就會再搜一次，
        --   兩支函式互相呼叫變成無限迴圈。
        if searchedFor[itemID] then
            searchedFor[itemID] = nil
            awaitSearch = nil
            SetStatus(L["No one is selling %s."]:format(ns.List.ItemInfo(itemID).name), true)
            if fromQueue then StepQueue() end
            return
        end
        searchedFor[itemID] = true
        awaitSearch = { itemID = itemID, quantity = quantity, fromQueue = fromQueue }
        Auction.SearchItem(itemID)
        SetStatus(L["Asking the price — press buy again when it comes back."], true)
        return
    end
    searchedFor[itemID] = nil

    local quote = quotes[itemID]
    if not quote then
        SetStatus(L["No one is selling %s."]:format(ns.List.ItemInfo(itemID).name), true)
        if fromQueue then StepQueue() end
        return
    end

    if quote.isCommodity then
        if quote.quantity and quote.quantity > 0 then
            quantity = math.min(quantity, quote.quantity)
        end
        pendingQuote = { itemID = itemID, quantity = quantity, isCommodity = true }
        SetStatus(L["Asking for a quote..."])
        C_AuctionHouse.StartCommoditiesPurchase(itemID, quantity)
        return
    end

    -- 非商品：一件一單，價格就是那一筆的一口價，不用另外問
    local itemKey = quote.itemKey or C_AuctionHouse.MakeItemKey(itemID)
    local info = C_AuctionHouse.GetItemSearchResultInfo(itemKey, 1)
    if not info or not info.buyoutAmount or not info.auctionID then
        local name = ns.List.ItemInfo(itemID).name
        SetStatus(L["No one is selling %s."]:format(name))
        if fromQueue then StepQueue() end
        return
    end
    pendingConfirm = {
        itemID     = itemID,
        quantity   = info.quantity or 1,
        unitPrice  = info.buyoutAmount,
        totalPrice = info.buyoutAmount,
        auctionID  = info.auctionID,
        overpriced = Overpriced(itemID, info.buyoutAmount),
    }
    SetStatus(L["Check the price, then confirm."])
end

-- 搜尋結果回來了。
-- ⚠ **不能接著自動買**：StartCommoditiesPurchase 過不了硬體事件閘（見檔頭）。
--   只能把價格填上去、告訴玩家可以按了。
local function ResumeAfterSearch(itemID)
    local a = awaitSearch
    if not a or a.itemID ~= itemID then return end
    awaitSearch = nil
    if quotes[itemID] then
        SetStatus(L["Price is in — press buy again."], true)
    else
        SetStatus(L["No one is selling %s."]:format(ns.List.ItemInfo(itemID).name), true)
        if a.fromQueue then StepQueue() end
    end
end

------------------------------------------------------------
-- 批次購買
--
-- 一組一列、品質由玩家在列上挑（見 UI/Rows.lua），所以這裡直接照 row.itemID 買。
-- 保險起見還是照 row.key 去重一次 —— 資料層要是哪天又變成一個品質一列，
-- 這裡不去重就會買成兩倍。
------------------------------------------------------------
function Auction.BuyAll()
    if not Auction.IsOpen() then
        SetStatus(L["Open the auction house to search and buy."])
        return
    end
    local rows = ns.List.Shopping({ includeReady = true })
    local pick, order = {}, {}
    for _, row in ipairs(rows) do
        if (row.buy or 0) > 0 and row.itemID and not row.vendor and not row.ignored then
            local chosen = pick[row.key]
            if not chosen then
                pick[row.key] = row
                order[#order + 1] = row.key
            elseif row.unitPrice and (not chosen.unitPrice or row.unitPrice < chosen.unitPrice) then
                pick[row.key] = row
            end
        end
    end

    buyQueue = {}
    for _, key in ipairs(order) do
        local row = pick[key]
        buyQueue[#buyQueue + 1] = { itemID = row.itemID, quantity = row.buy }
    end
    if #buyQueue == 0 then
        StopQueue(L["Nothing left to buy."])
        return
    end
    queueAt, queueTotal = 0, #buyQueue
    StepQueue()
end

function StepQueue()
    queueAt = queueAt + 1
    local item = buyQueue[queueAt]
    if not item then
        StopQueue(L["The list is bought."], true)
        ns.Fire("ListChanged")
        return
    end
    Auction.StartBuy(item.itemID, item.quantity, true)
end
-- 等玩家按「下一筆」的狀態：回傳下一筆的 itemID 與進度
function Auction.QueueWaiting()
    if not queueWaiting then return nil end
    local nextItem = buyQueue[queueAt + 1]
    if not nextItem then return nil end
    return nextItem.itemID, queueAt + 1, queueTotal
end

-- 確認列的「下一筆」。**一定要從點擊呼叫**（見檔頭的硬體事件閘）
function Auction.Next()
    if not queueWaiting then return end
    queueWaiting = false
    StepQueue()
end


-- 確認列的「跳過」：這一筆不買，直接換下一筆
function Auction.Skip()
    if queueTotal == 0 then return end
    if pendingQuote or (pendingConfirm and not pendingConfirm.auctionID) then
        pcall(C_AuctionHouse.CancelCommoditiesPurchase)
    end
    pendingQuote, pendingConfirm = nil, nil
    StepQueue()
end

function Auction.Confirm()
    local p = pendingConfirm
    if not p then return end
    if GetMoney() < (p.totalPrice or 0) then
        SetStatus(L["Not enough gold."], true)
        return
    end
    if p.auctionID then
        C_AuctionHouse.PlaceBid(p.auctionID, p.totalPrice)
    else
        C_AuctionHouse.ConfirmCommoditiesPurchase(p.itemID, p.quantity)
    end
    SetStatus(L["Buying..."])
end

function Auction.Cancel()
    if pendingQuote or (pendingConfirm and not pendingConfirm.auctionID) then
        pcall(C_AuctionHouse.CancelCommoditiesPurchase)
    end
    pendingQuote, pendingConfirm = nil, nil
    StopQueue()
    SetStatus(L["Purchase cancelled."])
end

local function ClearPending()
    pendingQuote, pendingConfirm = nil, nil
end

------------------------------------------------------------
-- 事件
------------------------------------------------------------
local f = CreateFrame("Frame")
for _, event in ipairs({
    "AUCTION_HOUSE_SHOW",
    "AUCTION_HOUSE_CLOSED",
    "AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
    "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
    "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
    "AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
    "AUCTION_HOUSE_NEW_RESULTS_RECEIVED",
    "AUCTION_HOUSE_BROWSE_FAILURE",
    "COMMODITY_SEARCH_RESULTS_UPDATED",
    "ITEM_SEARCH_RESULTS_UPDATED",
    "COMMODITY_PRICE_UPDATED",
    "COMMODITY_PRICE_UNAVAILABLE",
    "COMMODITY_PURCHASE_SUCCEEDED",
    "COMMODITY_PURCHASE_FAILED",
    "ITEM_PURCHASED",
}) do
    f:RegisterEvent(event)
end

local function Finish(success)
    local p = pendingConfirm or pendingQuote
    local name = p and p.itemID and ns.List.ItemInfo(p.itemID).name or "?"
    ClearPending()
    if success then
        -- ⚠ 買到的東西是**寄信**過來的，收信前 GetItemCount 看不到 —— 不記一筆的話
        --   清單會繼續說「還缺 N 個」，玩家就再買一次。見 List.NoteBought。
        if p and p.itemID then ns.List.NoteBought(p.itemID, p.quantity or 1) end
        SetStatus(L["Bought %s x%d."]:format(name, (p and p.quantity) or 1), true)
        -- ⚠ 不能直接 StepQueue()：那會從事件處理器裡呼叫 StartCommoditiesPurchase，
        --   過不了硬體事件閘（見檔頭）。停在這裡，確認列會換成「下一筆」等玩家按。
        if queueTotal > 0 then queueWaiting = true end
        ns.Fire("ListChanged")
        return
    end
    -- 失敗就停下整批：可能是金幣不夠、掛單被搶走，繼續往下買只會連環出錯
    StopQueue()
    SetStatus(L["The purchase did not go through."], true)
    ns.Fire("ListChanged")
end

f:SetScript("OnEvent", function(_, event, a1, a2)
    if not ns.db then return end

    if event == "AUCTION_HOUSE_SHOW" then
        SetStatus(L["Auction house connected."])
        ns.Fire("AuctionOpened")

    elseif event == "AUCTION_HOUSE_CLOSED" then
        ClearPending()
        StopQueue()
        wipe(queue)
        wipe(detailed)
        busy, pendingSearch = false, nil
        SetStatus(L["Open the auction house to search and buy."])
        ns.Fire("AuctionClosed")

    elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
        Pump()

    elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED"
        or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED"
        or event == "AUCTION_HOUSE_NEW_RESULTS_RECEIVED" then
        StoreBrowseResults()
        Pump()
        SetStatus(L["Prices updated."])

    elseif event == "AUCTION_HOUSE_BROWSE_FAILURE" then
        Pump()
        SetStatus(L["The auction house did not answer. Try again."], true)

    elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        StoreCommodity(a1)
        Pump()
        if pendingSearch == a1 then pendingSearch = nil end
        SetStatus(L["Prices updated."])
        ResumeAfterSearch(a1)

    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
        StoreItem(a1)
        Pump()
        if a1 and pendingSearch == a1.itemID then pendingSearch = nil end
        SetStatus(L["Prices updated."])
        ResumeAfterSearch(a1 and a1.itemID)

    elseif event == "COMMODITY_PRICE_UPDATED" then
        local unitPrice, totalPrice = a1, a2
        local p = pendingQuote
        pendingQuote = nil
        if not p then return end
        pendingConfirm = {
            itemID     = p.itemID,
            quantity   = p.quantity,
            unitPrice  = unitPrice,
            totalPrice = totalPrice,
            overpriced = Overpriced(p.itemID, unitPrice),
        }
        SetStatus(L["Check the price, then confirm."])

    elseif event == "COMMODITY_PRICE_UNAVAILABLE" then
        ClearPending()
        StopQueue()
        SetStatus(L["That listing is gone. Search again."], true)

    elseif event == "COMMODITY_PURCHASE_SUCCEEDED" or event == "ITEM_PURCHASED" then
        Finish(true)

    elseif event == "COMMODITY_PURCHASE_FAILED" then
        Finish(false)
    end
end)
