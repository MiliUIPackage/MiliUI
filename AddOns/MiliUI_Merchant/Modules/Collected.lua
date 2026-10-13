------------------------------------------------------------
-- 已收藏判定
--
-- 三個入口，回傳值的語意相同：
--   `Collected.Is(index, itemID)`     商人格（配方提示／外觀連結照商品索引問）
--   `Collected.IsItem(itemID, link)`  只有物品編號（或連結）的地方，例如拍賣場
--   `Collected.IsSpecies(speciesID)`  戰寵籠子：同一個籠子物品裝的是不同的寵物，
--                                     只能照種類問
--
-- 回三種值：
--   true   已經有了 —— Dim 會把那一格變暗並打勾。「有了」包含兩種：收藏裡學會了，
--          **或者東西已經躺在背包／銀行裡還沒用掉**（見 OwnsCopy）
--   false  還沒有
--   nil    **資料還沒到** —— 這一格維持原樣，等下一輪再問
--
-- nil 跟 false 一定要分得開。商人視窗一打開，物品資料常常有幾格還在路上，
-- 那時候硬判成 false 就會快取住「沒有」，之後資料到了也不會再變暗（快取是
-- 以 itemID 為 key 的，錯一次就錯到關掉商人為止）。
--
-- 快取的理由：每一格每次重畫都會問一次，而暴雪的重畫是事件驅動的
-- （BAG_UPDATE、UNIT_INVENTORY_CHANGED 都會觸發），一趟買東西可以跑上十幾輪。
-- 一頁 60 格 × 六種判定 × 十幾輪，不快取就是每次開商人跑幾千次查表。
------------------------------------------------------------
local _, ns = ...

ns.Collected = {}
local C = ns.Collected

local issecret = ns.Secret.IsSecret

-- itemID → true / false / UNLEARNED。**只記算得出來的**，算不出來（資料未到）不記
--
-- UNLEARNED＝「是收藏品、但收藏裡還沒有」。這種不能直接記成 false：剛買下來的
-- 坐騎在**按下去學會之前**收藏裡查不到，但它就在背包裡 —— 這支功能存在的理由是
-- 「不要重複買」，所以買了就該暗，不是學了才暗。背包內容隨時在變，所以這一段
-- 不進快取、每一輪現場問（只有「還沒收藏的收藏品」會走到這裡，一頁沒幾格）。
local UNLEARNED = "unlearned"
local cache = {}
local cacheCount = 0

-- 這一輪有沒有哪一格回 nil。有的話才去等 GET_ITEM_INFO_RECEIVED
local sawUnknown = false

------------------------------------------------------------
-- 六種判定
--
-- ⚠ 每一支的回傳位置都查過暴雪的 API 文件，不要照別的插件的註解改：
--   C_PetJournal.GetPetInfoByItemID  第 13 個回傳才是 speciesID
--   C_MountJournal.GetMountInfoByID  第 11 個回傳才是 isCollected
--   C_Item.GetItemInfoInstant        第 6 / 7 個回傳是 classID / subClassID
--   C_HousingCatalog.GetCatalogEntryInfoByItem 回的是一整張表，**沒有**
--     `quantity` 這個欄位；持有數要自己把三個欄位加起來（見 IsHousingCollected）
------------------------------------------------------------

local function IsSpeciesCollected(speciesID)
    local numCollected = C_PetJournal.GetNumCollectedInfo(speciesID)
    if not numCollected then return nil end
    return numCollected > 0
end

local function IsPetCollected(itemID)
    local speciesID = select(13, C_PetJournal.GetPetInfoByItemID(itemID))
    if not speciesID then return nil end
    return IsSpeciesCollected(speciesID)
end

local function IsMountCollected(itemID)
    local mountID = C_MountJournal.GetMountFromItem(itemID)
    if not mountID then return nil end
    local isCollected = select(11, C_MountJournal.GetMountInfoByID(mountID))
    if isCollected == nil then return nil end
    return isCollected and true or false
end

local function IsToyCollected(itemID)
    -- GetToyInfo 回的第一個值就是 itemID；不是玩具的話整串都是 nil
    if not C_ToyBox.GetToyInfo(itemID) then return nil end
    return PlayerHasToy(itemID) and true or false
end

-- 配方沒有「查得到學會沒」的 API，唯一的來源是工具提示上那一行「已學會」。
-- ⚠ 提示從哪裡要由呼叫端決定（getTip(arg)）：商人格用 GetMerchantItem(索引) ——
--   直接跟伺服器要那一格的提示，不必自己組 item link（附魔卷軸那種帶參數的組不出來）；
--   拍賣場那種只有物品編號的地方才退回 GetHyperlink("item:編號")。
local function IsRecipeKnown(getTip, arg)
    local data = getTip(arg)
    if not data or not data.lines or #data.lines == 0 then return nil end
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        -- 提示內容在 12.1 不是秘密值，但這裡是拿去跟字串比對的地方，
        -- 撞上秘密字串就是當場崩潰，擋一下比較省事
        if text and not issecret(text) then
            if text == ITEM_SPELL_KNOWN then return true end
            -- 「正在取得物品資訊」那一行還在＝提示是半成品，「已學會」那行還沒到。
            -- 這時候回 false 會被快取住，要到關掉商人才翻得回來
            if text == RETRIEVING_ITEM_INFO then return nil end
        end
    end
    return false
end

local function IsHousingCollected(itemID)
    if not C_HousingCatalog or not C_HousingCatalog.GetCatalogEntryInfoByItem then
        return nil
    end
    local info = C_HousingCatalog.GetCatalogEntryInfoByItem(itemID)
    if not info then return nil end
    -- 「有了」= 倉庫裡的 ＋ 還沒領出來的 ＋ 已經擺出去的。
    -- 只看倉庫的話，全部擺進房子裡的那些會被判成沒有
    local owned = (info.totalNumStored or 0)
        + (info.remainingRedeemable or 0)
        + (info.totalNumPlaced or 0)
    return owned > 0
end

-- 背包、銀行、戰隊銀行裡有沒有這件東西。
-- ⚠ 不需要自己聽 BAG_UPDATE：暴雪的商人框本來就聽了，東西一進背包它就會重畫，
--   我們的掛勾跟著跑，這裡現場問到的就是新的數量。
local function OwnsCopy(itemID)
    local count = C_Item.GetItemCount(itemID, true, false, true, true)
    return (count or 0) > 0
end

local function HasTransmog(link)
    if not link or issecret(link) then return nil end
    return C_TransmogCollection.PlayerHasTransmogByItemInfo(link) and true or false
end

------------------------------------------------------------
-- 判定總管
--
-- 順序是「專屬 API 先、classID 判斷後」：寵物／坐騎／玩具各有一支直接對 itemID
-- 問的 API，問到就結案；配方／塑形／房屋裝飾才需要先看 classID。
--
-- 關掉的類別**整段跳過**，連 API 都不呼叫 —— 關掉一個類別本來就該連它的成本
-- 一起關掉。
------------------------------------------------------------
-- getTip／getLink 是「這件東西的提示／連結從哪裡要」，arg 是餵給它們的參數
-- （商人格是索引、其他地方是連結字串）。傳函式＋參數而不是傳閉包：
-- 這一支每一格每一輪都會跑，閉包等於每次都配一個新物件。
local function Compute(itemID, dim, getTip, getLink, arg)
    if dim.pets then
        local v = IsPetCollected(itemID)
        if v ~= nil then return v or UNLEARNED end
    end
    if dim.mounts then
        local v = IsMountCollected(itemID)
        if v ~= nil then return v or UNLEARNED end
    end
    if dim.toys then
        local v = IsToyCollected(itemID)
        if v ~= nil then return v or UNLEARNED end
    end

    -- classID 拿不到＝物品資料還在路上，不是「不屬於任何類別」
    local classID = select(6, C_Item.GetItemInfoInstant(itemID))
    if classID == nil then return nil end

    -- 這三類的 nil（資料未到）要原樣傳回去，false 才換成 UNLEARNED
    local v
    if dim.recipes and classID == Enum.ItemClass.Recipe then
        v = IsRecipeKnown(getTip, arg)
    elseif dim.housing and classID == Enum.ItemClass.Housing then
        v = IsHousingCollected(itemID)
    elseif dim.transmog
        and (classID == Enum.ItemClass.Weapon or classID == Enum.ItemClass.Armor) then
        -- 塑形要用 link 不用 itemID：外觀是掛在 item link 的修飾子上的
        v = HasTransmog(getLink(arg))
    else
        -- 不屬於任何開著的類別：藥水、材料這種東西「背包裡有」不代表不用再買
        return false
    end

    if v == false then return UNLEARNED end
    return v
end

------------------------------------------------------------
-- 共用的「查快取 → 算 → 記下來」
------------------------------------------------------------
local function Lookup(itemID, getTip, getLink, arg)
    -- ⚠ itemID 是 table 的 key。秘密值不能當 key（"cannot be indexed with
    --   secret keys" 是硬錯，會中斷整支重畫）
    if not itemID or issecret(itemID) then return nil end

    local value = cache[itemID]
    if value == nil then
        local dim = ns.db and ns.db.dim
        if not dim then return nil end

        value = Compute(itemID, dim, getTip, getLink, arg)
        if value == nil then
            sawUnknown = true
            return nil
        end

        cache[itemID] = value
        cacheCount = cacheCount + 1
    end

    if value == UNLEARNED then return OwnsCopy(itemID) end
    return value
end

------------------------------------------------------------
-- Collected.Is(index, itemID) → true / false / nil   （商人格）
------------------------------------------------------------
function C.Is(index, itemID)
    return Lookup(itemID, C_TooltipInfo.GetMerchantItem, GetMerchantItemLink, index)
end

------------------------------------------------------------
-- Collected.IsItem(itemID, link) → true / false / nil
--
-- link 可以不給：沒有的話用 "item:編號" 頂替。拍賣場的瀏覽結果只給 itemKey，
-- 拿不到帶修飾子的連結 —— 外觀照基本型判，跟商人格的快取共用同一張表。
------------------------------------------------------------
local function SameLink(link) return link end

local function HyperlinkTip(link)
    return C_TooltipInfo.GetHyperlink(link)
end

function C.IsItem(itemID, link)
    if not itemID or issecret(itemID) then return nil end
    if not link or issecret(link) then
        link = "item:" .. itemID
    end
    return Lookup(itemID, HyperlinkTip, SameLink, link)
end

------------------------------------------------------------
-- Collected.IsSpecies(speciesID) → true / false / nil
--
-- 戰寵籠子在背包裡只看得到「一個籠子」，數不出是哪一種寵物，所以這條**沒有**
-- 「買了還沒用也算」：種類沒收藏就是 false。寵物類別關掉時一律 false。
------------------------------------------------------------
local speciesCache = {}

function C.IsSpecies(speciesID)
    if not speciesID or issecret(speciesID) then return nil end

    local value = speciesCache[speciesID]
    if value ~= nil then return value end

    local dim = ns.db and ns.db.dim
    if not dim then return nil end
    if not dim.pets then
        value = false
    else
        value = IsSpeciesCollected(speciesID)
        if value == nil then
            sawUnknown = true
            return nil
        end
    end

    speciesCache[speciesID] = value
    cacheCount = cacheCount + 1
    return value
end

function C.Count()
    return cacheCount
end

function C.Wipe()
    wipe(cache)
    wipe(speciesCache)
    cacheCount = 0
end

------------------------------------------------------------
-- 事件
--
-- ⚠ GET_ITEM_INFO_RECEIVED **平常不註冊**：它在登入後的頭幾秒是每秒上百發的
--   事件（背包、工具提示、拍賣行都在要資料），掛著就等於替整個客戶端的物品
--   快取付一次派送成本。只有真的有格子回 nil 時才臨時掛上、刷完就拔掉。
------------------------------------------------------------
local watcher

-- 收藏內容變了 → 清快取，商人／拍賣場開著就順便重刷（當場學會一隻寵物就要當場變暗）
local COLLECTION_EVENTS = {
    "NEW_PET_ADDED",
    "NEW_MOUNT_ADDED",
    "NEW_TOY_ADDED",
    "NEW_RECIPE_LEARNED",
    "TRANSMOG_COLLECTION_UPDATED",
}

local retryScheduled = false

local function DoRetry()
    retryScheduled = false
    if watcher:IsEventRegistered("GET_ITEM_INFO_RECEIVED") then
        watcher:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
    end
    ns.Grid.Refresh()
    ns.AuctionHouse.Refresh()
end

-- Dim／拍賣場每跑完一輪叫一次：這一輪有格子回 nil 就掛上監聽，沒有就確保拔掉
function C.ArmRetry()
    if sawUnknown then
        sawUnknown = false
        if not watcher:IsEventRegistered("GET_ITEM_INFO_RECEIVED") then
            watcher:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        end
    elseif watcher:IsEventRegistered("GET_ITEM_INFO_RECEIVED") then
        watcher:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
    end
end

function C.Init()
    watcher = CreateFrame("Frame")
    watcher:RegisterEvent("MERCHANT_CLOSED")
    watcher:RegisterEvent("AUCTION_HOUSE_CLOSED")
    for _, event in ipairs(COLLECTION_EVENTS) do
        watcher:RegisterEvent(event)
    end

    watcher:SetScript("OnEvent", function(_, event)
        if event == "GET_ITEM_INFO_RECEIVED" then
            -- 一次資料回來會連發好幾十發，全部併成下一幀的一次重刷
            if retryScheduled then return end
            retryScheduled = true
            C_Timer.After(0, DoRetry)
            return
        end

        C.Wipe()
        if event ~= "MERCHANT_CLOSED" and event ~= "AUCTION_HOUSE_CLOSED" then
            ns.Grid.Refresh()
            ns.AuctionHouse.Refresh()
        end
    end)
end
