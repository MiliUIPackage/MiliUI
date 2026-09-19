------------------------------------------------------------
-- 已收藏判定
--
-- `Collected.Is(index, itemID)` 回三種值：
--   true   已經有了 —— Dim 會把那一格變暗並打勾
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

-- itemID → true / false。**只記算得出來的**，算不出來（資料未到）不記
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

local function IsPetCollected(itemID)
    local speciesID = select(13, C_PetJournal.GetPetInfoByItemID(itemID))
    if not speciesID then return nil end
    local numCollected = C_PetJournal.GetNumCollectedInfo(speciesID)
    if not numCollected then return nil end
    return numCollected > 0
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
-- ⚠ 所以這一支吃的是**商人格的索引**而不是 itemID：GetMerchantItem 直接跟伺服器
--   要那一格的提示內容，不必自己組 item link（附魔卷軸那種帶參數的組不出來）。
local function IsRecipeKnown(index)
    local data = C_TooltipInfo.GetMerchantItem(index)
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
local function Compute(index, itemID, dim)
    if dim.pets then
        local v = IsPetCollected(itemID)
        if v ~= nil then return v end
    end
    if dim.mounts then
        local v = IsMountCollected(itemID)
        if v ~= nil then return v end
    end
    if dim.toys then
        local v = IsToyCollected(itemID)
        if v ~= nil then return v end
    end

    -- classID 拿不到＝物品資料還在路上，不是「不屬於任何類別」
    local classID = select(6, C_Item.GetItemInfoInstant(itemID))
    if classID == nil then return nil end

    if dim.recipes and classID == Enum.ItemClass.Recipe then
        return IsRecipeKnown(index)
    end
    if dim.housing and classID == Enum.ItemClass.Housing then
        return IsHousingCollected(itemID)
    end
    if dim.transmog
        and (classID == Enum.ItemClass.Weapon or classID == Enum.ItemClass.Armor) then
        -- 塑形要用 link 不用 itemID：外觀是掛在 item link 的修飾子上的
        return HasTransmog(GetMerchantItemLink(index))
    end

    return false
end

------------------------------------------------------------
-- Collected.Is(index, itemID) → true / false / nil
------------------------------------------------------------
function C.Is(index, itemID)
    -- ⚠ itemID 是 table 的 key。秘密值不能當 key（"cannot be indexed with
    --   secret keys" 是硬錯，會中斷整支重畫）
    if not itemID or issecret(itemID) then return nil end

    local hit = cache[itemID]
    if hit ~= nil then return hit end

    local dim = ns.db and ns.db.dim
    if not dim then return nil end

    local value = Compute(index, itemID, dim)
    if value == nil then
        sawUnknown = true
        return nil
    end

    cache[itemID] = value
    cacheCount = cacheCount + 1
    return value
end

function C.Count()
    return cacheCount
end

function C.Wipe()
    wipe(cache)
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

-- 收藏內容變了 → 清快取，商人開著就順便重刷（當場買一隻寵物就要當場變暗）
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
end

-- Dim 每跑完一輪叫一次：這一輪有格子回 nil 就掛上監聽，沒有就確保拔掉
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
        if event ~= "MERCHANT_CLOSED" then
            ns.Grid.Refresh()
        end
    end)
end
