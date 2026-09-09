------------------------------------------------------------
-- 資料層：配方清單 → 採購清單
--
-- 分層：
--   配方項目   存「每做一份要什麼材料」＋「要做幾份」，材料需求是兩者相乘
--   採購清單   把所有配方（＋額外物品）的材料彙總成一張表，
--              同一種材料的各品質以 1★ 的 itemID 當 key 合併成一組
--   採購列     一組可以有兩列（1★／2★）—— 需要／持有／需買是**整組**的數字，
--              單價／在售／購買才是那一列自己的
--
-- ⚠ 名字與圖示一律**現查不存檔**。加入清單那一刻物品快取常常還是空的，存下去
--   就會在 SavedVariables 裡留一筆永遠的「未知」，而且之後怎麼重整都不會變。
--   存的只有 itemID、數量與旗標。
------------------------------------------------------------
local _, ns = ...

ns.List = {}
local List = ns.List
local L = ns.L

------------------------------------------------------------
-- 小工具
------------------------------------------------------------
local UNKNOWN_ICON = 134400   -- INV_Misc_QuestionMark

function List.Money(copper)
    copper = tonumber(copper)
    if not copper then return "—" end
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        return C_CurrencyInfo.GetCoinTextureString(copper)
    end
    return tostring(math.floor(copper / 10000)) .. "g"
end

-- 清單欄位用的短版：一格塞不下「1234金56銀78銅」，而且採購清單上真正要比的
-- 是金的量級。滿一金就只印金，不到一金才退回完整寫法。
local GOLD_ICON = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:1:0|t"

function List.MoneyShort(copper)
    copper = tonumber(copper)
    if not copper then return "—" end
    if copper >= 10000 then
        return BreakUpLargeNumbers(math.floor(copper / 10000)) .. GOLD_ICON
    end
    return List.Money(copper)
end

-- 物品資訊：查不到就丟一張佔位表並要求載入，等 GET_ITEM_INFO_RECEIVED 再重畫
function List.ItemInfo(itemID)
    if not itemID then return nil end
    local name, link, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
    if not name then
        C_Item.RequestLoadItemDataByID(itemID)
        return {
            itemID  = itemID,
            name    = L["Loading..."],
            icon    = UNKNOWN_ICON,
            quality = 1,
            pending = true,
        }
    end
    return {
        itemID  = itemID,
        name    = name,
        icon    = icon or UNKNOWN_ICON,
        quality = quality or 1,
        link    = link,
        pending = false,
    }
end

------------------------------------------------------------
-- 持有量
--
-- 拆成「背包」與「銀行」兩個數字，設定的 includeBank 只決定要不要把銀行那截
-- 算進需求，**不決定要不要顯示** —— 開關關著時銀行那格變暗但還是印出來，
-- 玩家才知道東西其實在銀行、不用再買一份。
--
-- 一次重算裡每個 itemID 只問一次：一張 40 列的清單 × 三個品質 × 兩次呼叫，
-- 不快取的話每次 BAG_UPDATE 都要跑幾百次背包掃描。
------------------------------------------------------------
local countCache = {}

function List.Invalidate()
    wipe(countCache)
end

function List.Counts(itemID)
    if not itemID then return 0, 0 end
    local c = countCache[itemID]
    if c then return c[1], c[2] end
    local bags = C_Item.GetItemCount(itemID) or 0
    -- includeBank, includeUses, includeReagentBank, includeAccountBank
    local all  = C_Item.GetItemCount(itemID, true, false, true, true) or 0
    local bank = math.max(0, all - bags)
    countCache[itemID] = { bags, bank }
    return bags, bank
end

------------------------------------------------------------
-- 已經買了、但還在信箱裡的量
--
-- 拍賣場買到的東西是**寄信**過來的，收信前 `GetItemCount` 一個都看不到 ——
-- 清單會一直說「還缺 10 個」，玩家就會再買一次。
--
-- 沒有辦法在不開信箱的情況下讀信箱內容（`GetInboxNumItems` 只有站在信箱前才有值），
-- 所以改記自己買了什麼：買下當時的背包量存一份，之後 `背包量 − 當時的量` 就是
-- 已經領到的部分，剩下的還在路上。東西一收進背包這筆就自己歸零，不用手動清。
--
-- ⚠ 只留在記憶體裡，不進 SavedVariables。信可能被退回、被刪、過期，存下去就會
--   留一筆永遠減不掉的幻影持有量 —— 那比多買一次糟糕得多。
------------------------------------------------------------
local inTransit = {}   -- [itemID] = { qty = 買了幾個, bags = 買下當時的背包量 }

function List.NoteBought(itemID, quantity)
    if not itemID or not quantity or quantity <= 0 then return end
    local rec = inTransit[itemID]
    if rec then
        rec.qty = rec.qty + quantity
    else
        local bags = List.Counts(itemID)
        inTransit[itemID] = { qty = quantity, bags = bags }
    end
end

function List.InTransit(itemID)
    local rec = itemID and inTransit[itemID]
    if not rec then return 0 end
    local bags = List.Counts(itemID)
    local arrived = math.max(0, bags - rec.bags)
    local left = rec.qty - arrived
    if left <= 0 then
        inTransit[itemID] = nil
        return 0
    end
    return left
end

------------------------------------------------------------
-- 品質（★）
--
-- 一個材料槽的 reagents 陣列就是它的各個品質。用 1★ 的 itemID 當整組的 key：
-- 玩家買哪個品質是他的事，需求量是共用的。
------------------------------------------------------------
function List.StarIDs(itemID, alts)
    local ids = {}
    if itemID then ids[#ids + 1] = itemID end
    for _, id in ipairs(alts or {}) do
        if id then ids[#ids + 1] = id end
    end
    local byTier, any = {}, false
    for _, id in ipairs(ids) do
        local tier = C_TradeSkillUI.GetItemReagentQualityByItemInfo(id)
        if tier then
            byTier[tier] = id
            any = true
        end
    end
    if any then return byTier end
    -- 沒有品質階級的材料（多數任務材料、部分基礎素材）只有一個 id
    return { [1] = ids[1] }
end

------------------------------------------------------------
-- 商店買得到的材料
--
-- ⚠ **沒有 API 可以問「哪個商人賣這件東西」。** 客戶端只知道商店的**收購**價
--   （GetItemInfo 的 sellPrice），永遠不知道你沒去過的商人開價多少。
--   所以只能自己逛到才算數：Modules/Vendor.lua 在你開任何商人視窗時，
--   把「無限供應」（numAvailable == -1）的貨記進帳號層的 vendorItems。
--   認不出來的時候玩家可以右鍵那一列自己忽略掉。
------------------------------------------------------------
function List.VendorPrice(itemID)
    return itemID and ns.db.vendorItems[itemID] or nil
end

-- ⚠ 只看**玩家挑的那個品質**，不是整組。
--   瓶子那種東西商店只賣低星，高星要去拍賣場買 —— 整組一起判定的話，玩家想買
--   高星也會被藏起來（實測回報）。挑 1★ 就是商店貨、挑 2★ 就是拍賣場貨。
function List.IsVendorItem(itemID)
    return List.VendorPrice(itemID) ~= nil
end

------------------------------------------------------------
-- 玩家選了哪個品質
--
-- 同一個材料的 1★／2★ 是**同一筆需求**，不是兩筆 —— 玩家要挑一個買。
-- 一開始沒挑就給「有報價之中最便宜的」，挑過就記住（角色層）。
------------------------------------------------------------
function List.Tiers(starIDs)
    local out = {}
    for tier = 1, 3 do
        if starIDs[tier] then out[#out + 1] = tier end
    end
    return out
end

function List.ChosenTier(key, starIDs)
    local tiers = List.Tiers(starIDs)
    local picked = ns.cdb.quality[key]
    for _, tier in ipairs(tiers) do
        if tier == picked then return tier end
    end
    -- 沒挑過：有報價的挑最便宜，都沒報價就挑最低品質
    local best, bestPrice
    for _, tier in ipairs(tiers) do
        local q = ns.Auction and ns.Auction.Quote(starIDs[tier])
        if q and q.unitPrice and (not bestPrice or q.unitPrice < bestPrice) then
            best, bestPrice = tier, q.unitPrice
        end
    end
    return best or tiers[1]
end

-- itemID 是「換過去的那個品質」的 id。換品質就順手問一次價：新挑的那個多半
-- 還沒報過價，而「單價 -、購買鈕灰的」那一列看起來就像切壞了 —— 玩家不會知道
-- 那只是還沒搜。拍賣場沒開就什麼都不做（搜不了，也不該跳訊息洗版）。
function List.SetTier(key, tier, itemID)
    ns.cdb.quality[key] = tier
    if itemID and ns.Auction and ns.Auction.IsOpen() and not ns.Auction.Quote(itemID) then
        ns.Auction.SearchItem(itemID)
    end
    ns.Fire("ListChanged")
end

------------------------------------------------------------
-- 只看某一個配方
--
-- 點配方區的某一列，下面的採購表就只算那個配方的材料，「搜尋全部／全部購買」
-- 也跟著只做那一份。**不進存檔**：這是「我現在在弄哪一個」，不是設定。
------------------------------------------------------------
local filterKey

function List.Filter() return filterKey end

function List.SetFilter(key)
    filterKey = key
    ns.Fire("ListChanged")
end

function List.ToggleFilter(key)
    List.SetFilter(filterKey == key and nil or key)
end

------------------------------------------------------------
-- 手動忽略
--
-- 「這個材料不用列給我看」。玩家自己按的，所以不需要猜對 —— 也是商店材料
-- 判斷失準時的逃生門。
------------------------------------------------------------
function List.IsIgnored(key)
    return ns.cdb.ignored[key] and true or false
end

function List.ToggleIgnore(key)
    ns.cdb.ignored[key] = (not ns.cdb.ignored[key]) or nil
    ns.Fire("ListChanged")
end

function List.ClearIgnored()
    wipe(ns.cdb.ignored)
    ns.Fire("ListChanged")
end

function List.QualityMarkup(itemID)
    if not itemID then return "" end
    local info = C_TradeSkillUI.GetItemReagentQualityInfo(itemID)
    if info and info.iconChat then
        return CreateAtlasMarkup(info.iconChat, 17, 17)
    end
    return ""
end

------------------------------------------------------------
-- 買不到的材料
--
-- 火花類是綁定貨幣物品，拍賣場沒有、算進採購清單只會讓「還缺 N 樣」永遠歸不了零。
-- ⚠ itemID 每季會多一個，清單過期不會壞（還有名字比對兜底），但補一下比較準。
------------------------------------------------------------
local SPARK_IDS = {
    [211296] = true,   -- 預兆火花
    [230906] = true,   -- 命運火花
    [231756] = true,   -- 星光火花
    [232875] = true,   -- 光輝火花
    [274476] = true,   -- 潮汐火花
}

function List.IsSpark(itemID, name)
    if not itemID then return false end
    if SPARK_IDS[itemID] then return true end
    if not name then
        local info = List.ItemInfo(itemID)
        name = info and not info.pending and info.name
    end
    if type(name) ~= "string" or name == "" then return false end
    if name:find("火花", 1, true) then return true end
    local lower = name:lower()
    return lower:find("spark of", 1, true) ~= nil
        or lower:find("fractured spark", 1, true) ~= nil
        or lower:find("splintered spark", 1, true) ~= nil
end

------------------------------------------------------------
-- 配方清單
------------------------------------------------------------
local function Recipes() return ns.cdb.recipes end
local function Extras()  return ns.cdb.extras end

function List.Find(key)
    for i, r in ipairs(Recipes()) do
        if r.key == key then return r, i end
    end
end

function List.FindExtra(itemID)
    for i, e in ipairs(Extras()) do
        if e.itemID == itemID then return e, i end
    end
end

-- data = { recipeID, name, icon, yield, source, orderType, reagents }
--   reagents 每筆 { itemID, alts, perCraft, optional }
-- quantity = 要做幾份（次數）
--
-- ⚠ 已經在清單裡的配方是**覆寫**數量、不是累加。原作是累加，實際用起來
--   「再按一次加入」的直覺是「我要做這麼多」，累加只會愈按愈多。
function List.AddRecipe(data, quantity, sourceKey)
    if not data or not data.recipeID then return nil end
    quantity = math.max(1, math.floor(tonumber(quantity) or 1))

    -- key 帶來源：同一個配方從製作頁與代工下單頁加進來，材料槽的內容
    -- （品質分配、玩家選的可選材料）本來就不一樣，硬合成一筆會互相蓋掉。
    local key = (sourceKey or data.source or "craft") .. ":" .. data.recipeID
    local existing = List.Find(key)
    local entry = existing or {}
    entry.key       = key
    entry.recipeID  = data.recipeID
    entry.name      = data.name or entry.name or ("#" .. data.recipeID)
    entry.icon      = data.icon or entry.icon
    entry.yield     = math.max(1, math.floor(tonumber(data.yield) or 1))
    entry.source    = data.source or "craft"
    entry.orderType = data.orderType
    entry.quantity  = quantity
    entry.reagents  = data.reagents or entry.reagents or {}
    if not existing then
        table.insert(Recipes(), entry)
    end
    ns.Fire("ListChanged")
    return entry, existing ~= nil
end

function List.SetQuantity(key, quantity)
    local entry = List.Find(key)
    if not entry then return end
    entry.quantity = math.max(1, math.floor(tonumber(quantity) or 1))
    ns.Fire("ListChanged")
    return entry
end

function List.Remove(key)
    local entry, i = List.Find(key)
    if not entry then return end
    table.remove(Recipes(), i)
    if filterKey == key then filterKey = nil end
    ns.Fire("ListChanged")
    return entry
end

function List.AddExtra(itemID, quantity)
    if not itemID then return nil end
    quantity = math.max(1, math.floor(tonumber(quantity) or 1))
    local entry = List.FindExtra(itemID)
    if entry then
        entry.quantity = entry.quantity + quantity
    else
        entry = { itemID = itemID, quantity = quantity }
        table.insert(Extras(), entry)
    end
    ns.Fire("ListChanged")
    return entry
end

function List.SetExtraQuantity(itemID, quantity)
    local entry = List.FindExtra(itemID)
    if not entry then return end
    entry.quantity = math.max(1, math.floor(tonumber(quantity) or 1))
    ns.Fire("ListChanged")
    return entry
end

function List.RemoveExtra(itemID)
    local entry, i = List.FindExtra(itemID)
    if not entry then return end
    table.remove(Extras(), i)
    ns.Fire("ListChanged")
    return entry
end

function List.IsEmpty()
    return #Recipes() == 0 and #Extras() == 0
end

function List.ClearAll()
    wipe(Recipes())
    wipe(Extras())
    filterKey = nil
    ns.Fire("ListChanged")
end

------------------------------------------------------------
-- 一筆配方還缺什麼（配方分頁展開的明細）
------------------------------------------------------------
local function IncludeBank()
    return ns.db.settings.includeBank and true or false
end

-- 一組（＝同一材料的所有品質）的持有量：背包／銀行／還在信箱
local function GroupCounts(starIDs)
    local bags, bank, transit = 0, 0, 0
    local seen = {}
    for _, id in pairs(starIDs) do
        if id and not seen[id] then
            seen[id] = true
            local b, k = List.Counts(id)
            bags, bank = bags + b, bank + k
            transit = transit + List.InTransit(id)
        end
    end
    return bags, bank, transit
end

function List.RecipeDetail(entry)
    local lines, missing = {}, 0
    for _, r in ipairs(entry.reagents or {}) do
        local starIDs = List.StarIDs(r.itemID, r.alts)
        local bags, bank, transit = GroupCounts(starIDs)
        local have = bags + transit + (IncludeBank() and bank or 0)
        local need = (r.perCraft or 1) * (entry.quantity or 1)
        local buy  = math.max(0, need - have)
        if buy > 0 and not List.IsSpark(r.itemID) then
            missing = missing + buy
        end
        lines[#lines + 1] = {
            itemID   = r.itemID,
            starIDs  = starIDs,
            optional = r.optional,
            need     = need,
            bags     = bags,
            bank     = bank,
            transit  = transit,
            buy      = buy,
            noTrade  = List.IsSpark(r.itemID),
        }
    end
    return lines, missing
end

-- 整張清單「還要去拍賣場買幾個」。走 Shopping 而不是自己加總 —— 商店貨與
-- 手動忽略的那幾筆不能算進來，不然畫面上明明沒有那幾列，數字卻對不起來。
function List.MissingTotal()
    local rows = List.Shopping({ includeReady = true })
    local total = 0
    for _, r in ipairs(rows) do
        if not r.vendor and not r.ignored then total = total + (r.buy or 0) end
    end
    return total
end

------------------------------------------------------------
-- 採購清單
--
-- opts.includeReady   true = 不套「只看缺少」（搜尋全部要連已備齊的一起報價）
------------------------------------------------------------
function List.Shopping(opts)
    local groups, order = {}, {}

    local function Add(itemID, alts, amount, optional, sourceName)
        if not itemID or amount <= 0 then return end
        if List.IsSpark(itemID) then return end   -- 拍賣場沒有，列了也買不到
        local starIDs = List.StarIDs(itemID, alts)
        local key = starIDs[1] or itemID
        local g = groups[key]
        if not g then
            g = { key = key, starIDs = starIDs, need = 0, optional = true, sources = {} }
            groups[key] = g
            order[#order + 1] = g
        end
        g.need = g.need + amount
        -- 只要有一個來源是必備的，整組就是必備
        if not optional then g.optional = false end
        if sourceName then g.sources[#g.sources + 1] = sourceName end
    end

    -- 只看某一個配方時，額外物品也不算 —— 它們不屬於任何配方
    local only = filterKey
    for _, entry in ipairs(Recipes()) do
        if not only or entry.key == only then
            for _, r in ipairs(entry.reagents or {}) do
                Add(r.itemID, r.alts, (r.perCraft or 1) * (entry.quantity or 1), r.optional, entry.name)
            end
        end
    end
    if not only then
        for _, e in ipairs(Extras()) do
            Add(e.itemID, nil, e.quantity or 1, false, L["Extra items"])
        end
    end

    -- 一組**一列**：品質是玩家在那一列上挑的，不是兩筆需求
    local rows, missingRows, estimate, vendorHidden = {}, 0, 0, 0
    local onlyMissing = ns.db.settings.onlyMissing and not (opts and opts.includeReady)
    -- 「顯示已隱藏」打開時，商店貨與手動忽略的那幾列照樣列出來（變暗），
    -- 玩家才有機會在上面改品質、或把忽略取消掉
    local showHidden  = ns.db.settings.showHidden
    local hideVendor  = ns.db.settings.hideVendor and not showHidden
                        and not (opts and opts.includeReady)
    for _, g in ipairs(order) do
        local bags, bank, transit = GroupCounts(g.starIDs)
        local have = bags + transit + (IncludeBank() and bank or 0)
        local buy  = math.max(0, g.need - have)
        if buy > 0 then missingRows = missingRows + 1 end

        local tier   = List.ChosenTier(g.key, g.starIDs)
        local itemID = g.starIDs[tier]
        local quote  = ns.Auction and ns.Auction.Quote(itemID)
        local vendor = List.IsVendorItem(itemID)
        local ignored = List.IsIgnored(g.key)

        if buy > 0 and quote and quote.unitPrice and not vendor and not ignored then
            estimate = estimate + quote.unitPrice * buy
        end

        local hide = (onlyMissing and buy <= 0 and transit <= 0)
                  or (hideVendor and vendor)
                  or (ignored and not showHidden)
        if hideVendor and vendor and buy > 0 then vendorHidden = vendorHidden + 1 end

        if not hide then
            rows[#rows + 1] = {
                key       = g.key,
                starIDs   = g.starIDs,
                tiers     = List.Tiers(g.starIDs),
                tier      = tier,
                itemID    = itemID,
                optional  = g.optional,
                sources   = g.sources,
                need      = g.need,
                bags      = bags,
                bank      = bank,
                transit   = transit,
                buy       = buy,
                vendor    = vendor,
                ignored   = ignored,
                unitPrice = quote and quote.unitPrice,
                listed    = quote and quote.quantity,
            }
        end
    end
    return rows, missingRows, estimate, vendorHidden
end

-- 已經買齊的配方整筆移除（清單愈長愈難看出還有什麼要做）
function List.ClearReady()
    local kept, removed = {}, 0
    for _, entry in ipairs(Recipes()) do
        local _, missing = List.RecipeDetail(entry)
        if missing > 0 then
            kept[#kept + 1] = entry
        else
            removed = removed + 1
        end
    end
    if removed > 0 then
        ns.cdb.recipes = kept
        ns.Fire("ListChanged")
    end
    return removed
end

------------------------------------------------------------
-- 刷新節流
--
-- 背包一動就是一串 BAG_UPDATE，接著一個 BAG_UPDATE_DELAYED；銀行那邊還會
-- 再補幾個自己的事件。整批塌成 0.2 秒一次重算，順便把持有量快取清掉。
------------------------------------------------------------
local pending = false
local function Schedule()
    if pending then return end
    pending = true
    C_Timer.After(0.2, function()
        pending = false
        List.Invalidate()
        ns.Fire("ListChanged")
    end)
end

-- ⚠ 事件名要照抄自真的在用它的插件，不要憑印象寫：RegisterEvent 收到不存在的
--   名字會**丟 Lua error**，而錯誤發生在檔案層 —— 整支 List.lua 從那一行起
--   就不再執行（ImportTracked、追蹤配方的監聽全部沒掛上），症狀跟「事件沒收到」
--   完全不一樣。
--   11.2 的銀行改版把材料銀行併成銀行分頁，`PLAYERREAGENTBANKSLOTS_CHANGED`
--   與 `REAGENTBANK_UPDATE` 隨之消失（Syndicator 只在舊版銀行版面才註冊它們）。
--   分頁本身是容器，所以 BAG_UPDATE_DELAYED 已經涵蓋大部分變動。
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("BAG_UPDATE_DELAYED")
watcher:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
watcher:RegisterEvent("BANK_TABS_CHANGED")
watcher:RegisterEvent("PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED")
watcher:RegisterEvent("GET_ITEM_INFO_RECEIVED")
watcher:SetScript("OnEvent", function(_, event)
    if not ns.db then return end
    if event == "GET_ITEM_INFO_RECEIVED" then
        -- 名字補回來只要重畫，持有量沒變，不用清快取
        if not pending then
            pending = true
            C_Timer.After(0.2, function()
                pending = false
                ns.Fire("ListChanged")
            end)
        end
        return
    end
    Schedule()
end)

------------------------------------------------------------
-- 同步遊戲內的追蹤配方（預設關）
--
-- 只加不減：玩家在遊戲裡取消追蹤時**不動**我們的清單 —— 追蹤是「我在看這個」，
-- 採購清單是「我要買這些」，兩件事的生命週期不一樣。
------------------------------------------------------------
function List.ImportTracked()
    if not ns.db.settings.syncTracked then return 0 end
    local ids = C_TradeSkillUI.GetRecipesTracked and C_TradeSkillUI.GetRecipesTracked(false)
    if type(ids) ~= "table" then return 0 end
    local added = 0
    for _, recipeID in ipairs(ids) do
        if not List.Find("craft:" .. recipeID) then
            local data = ns.Schematic and ns.Schematic.FromRecipeID(recipeID)
            if data then
                List.AddRecipe(data, 1, "craft")
                added = added + 1
            end
        end
    end
    return added
end

local tracker = CreateFrame("Frame")
tracker:RegisterEvent("TRACKED_RECIPE_UPDATE")
tracker:SetScript("OnEvent", function()
    if not ns.db or not ns.db.settings.syncTracked then return end
    C_Timer.After(0.1, function() List.ImportTracked() end)
end)
