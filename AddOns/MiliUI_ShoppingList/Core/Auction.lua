------------------------------------------------------------
-- 拍賣場：搜尋報價 ＋ 購買（一律要按確認才成交）
--
-- 節流：拍賣場的查詢有伺服器節流，沒準備好就送會被丟掉。所有查詢都排進佇列，
-- 由 AUCTION_HOUSE_THROTTLED_SYSTEM_READY 放行。
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
local lowest  = {}   -- [itemID] = 本次登入看過的最低單價（天價保險的基準）
local queue   = {}
local busy    = false
local pendingQuote        -- 已送出報價請求，等 COMMODITY_PRICE_UPDATED
local pendingConfirm      -- 等玩家按確認
local pendingSearch       -- 單筆搜尋中的 itemID
local status  = ""

local function SetStatus(text)
    status = text or ""
    ns.Fire("AuctionChanged")
end

function Auction.Status()   return status end
function Auction.Quote(itemID) return itemID and quotes[itemID] or nil end
function Auction.Pending()  return pendingConfirm end
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
    if not itemID or not unitPrice then return end
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
end

local function StoreItem(itemKey)
    if not itemKey or not itemKey.itemID then return end
    local count = C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
    if count <= 0 then
        quotes[itemKey.itemID] = nil
        return
    end
    local first = C_AuctionHouse.GetItemSearchResultInfo(itemKey, 1)
    if not first then return end
    local listed = count
    if C_AuctionHouse.GetItemSearchResultsQuantity then
        listed = C_AuctionHouse.GetItemSearchResultsQuantity(itemKey) or count
    end
    Remember(itemKey.itemID, first.buyoutAmount, listed, false, itemKey, first.auctionID)
end

------------------------------------------------------------
-- 搜尋
------------------------------------------------------------
function Auction.SearchAll()
    if not Auction.IsOpen() then
        SetStatus(L["Open the auction house to search and buy."])
        return
    end
    local rows = ns.List.Shopping({ includeReady = true })
    local keys, seen = {}, {}
    for _, row in ipairs(rows) do
        if row.itemID and not seen[row.itemID] then
            seen[row.itemID] = true
            keys[#keys + 1] = C_AuctionHouse.MakeItemKey(row.itemID)
            if #keys >= MAX_KEYS then break end
        end
    end
    if #keys == 0 then
        SetStatus(L["Nothing to buy yet."])
        return
    end
    SetStatus(L["Searching the auction house..."])
    Run(function() C_AuctionHouse.SearchForItemKeys(keys, PRICE_SORTS) end)
end

function Auction.SearchItem(itemID)
    if not itemID then return false end
    if not Auction.IsOpen() then
        SetStatus(L["Open the auction house to search and buy."])
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
-- 第一段：問價。商品要跟伺服器要一次報價（掛單會變，快取的價格不能當成交價）。
------------------------------------------------------------
local function Overpriced(itemID, unitPrice)
    local base = lowest[itemID]
    if not base or base <= 0 or not unitPrice then return false end
    local guard = ns.db.settings.priceGuard or 3
    return unitPrice > base * guard
end

function Auction.StartBuy(itemID, quantity)
    if not Auction.IsOpen() then
        SetStatus(L["Open the auction house to search and buy."])
        return
    end
    if pendingConfirm or pendingQuote then
        SetStatus(L["Finish the purchase in front of you first."])
        return
    end
    quantity = math.max(1, math.floor(tonumber(quantity) or 1))

    local quote = quotes[itemID]
    if not quote then
        Auction.SearchItem(itemID)
        SetStatus(L["No listings yet — searching. Press buy again."])
        return
    end

    if quote.isCommodity then
        local available = C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0
        if available <= 0 then
            Auction.SearchItem(itemID)
            SetStatus(L["No listings yet — searching. Press buy again."])
            return
        end
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
        Auction.SearchItem(itemID)
        SetStatus(L["No listings yet — searching. Press buy again."])
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

function Auction.Confirm()
    local p = pendingConfirm
    if not p then return end
    if GetMoney() < (p.totalPrice or 0) then
        SetStatus(L["Not enough gold."])
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
        SetStatus(L["Bought %s x%d."]:format(name, (p and p.quantity) or 1))
    else
        SetStatus(L["The purchase did not go through."])
    end
    ns.Fire("ListChanged")
end

f:SetScript("OnEvent", function(_, event, a1, a2)
    if not ns.db then return end

    if event == "AUCTION_HOUSE_SHOW" then
        SetStatus(L["Auction house connected."])
        ns.Fire("AuctionOpened")

    elseif event == "AUCTION_HOUSE_CLOSED" then
        ClearPending()
        wipe(queue)
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
        SetStatus(L["The auction house did not answer. Try again."])

    elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        StoreCommodity(a1)
        Pump()
        if pendingSearch == a1 then pendingSearch = nil end
        SetStatus(L["Prices updated."])

    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
        StoreItem(a1)
        Pump()
        if a1 and pendingSearch == a1.itemID then pendingSearch = nil end
        SetStatus(L["Prices updated."])

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
        SetStatus(L["That listing is gone. Search again."])

    elseif event == "COMMODITY_PURCHASE_SUCCEEDED" or event == "ITEM_PURCHASED" then
        Finish(true)

    elseif event == "COMMODITY_PURCHASE_FAILED" then
        Finish(false)
    end
end)
