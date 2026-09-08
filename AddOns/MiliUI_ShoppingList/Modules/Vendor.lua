------------------------------------------------------------
-- 記住商店賣些什麼
--
-- 為什麼要自己記：**沒有 API 可以問「哪個商人賣這件東西」。**
-- `C_Item.GetItemInfo` 的 sellPrice 是商店**收購**你的價格，跟「商店有沒有在賣」
-- 是兩回事。Auctionator 之類的插件也是自己掃商人掃出來的。
--
-- 判準是 `numAvailable == -1`（無限供應）：那是「這個商人永遠買得到」的訊號。
-- 限量貨（每天補幾個的那種）不算，那種東西當成拍賣場材料處理才對。
--
-- 記在帳號層：A 角色逛到的，B 角色也算數。
------------------------------------------------------------
local _, ns = ...

-- ⚠ 舊的 GetMerchantItemInfo 在某些客戶端已經換成 C_MerchantFrame.GetItemInfo
--   （Auctionator 也帶著同一組退路）。這裡照抄，免得哪天又是「函式不存在」。
local GetMerchantItemInfo = GetMerchantItemInfo or function(index)
    local info = C_MerchantFrame.GetItemInfo(index)
    if info then
        return info.name, info.texture, info.price, info.stackCount, info.numAvailable,
               info.isPurchasable, info.isUsable, info.hasExtendedCost
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("MERCHANT_SHOW")
f:RegisterEvent("MERCHANT_UPDATE")

local function Scan()
    if not ns.db then return end
    local n = GetMerchantNumItems() or 0
    local learned = 0
    for i = 1, n do
        local itemID = GetMerchantItemID(i)
        if itemID then
            local _, _, price, stack, numAvailable, _, _, extendedCost = GetMerchantItemInfo(i)
            -- 要用金幣買、無限供應，才算「商店貨」
            if not extendedCost and numAvailable == -1 and price and price > 0 then
                local unit = price / math.max(1, stack or 1)
                if ns.db.vendorItems[itemID] ~= unit then
                    ns.db.vendorItems[itemID] = unit
                    learned = learned + 1
                end
            end
        end
    end
    if learned > 0 then ns.Fire("ListChanged") end
end

f:SetScript("OnEvent", function()
    -- 慢一幀：MERCHANT_SHOW 當下清單有時還沒填完
    C_Timer.After(0, Scan)
end)
