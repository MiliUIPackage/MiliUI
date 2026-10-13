------------------------------------------------------------
-- 拍賣場：已收藏的變暗＋打勾
--
-- 判定走 Collected、畫法走 Dim 的標記器，這裡只負責「去哪裡找格子、拿什麼問」：
--
--   1. 瀏覽結果清單（BrowseResultsFrame.ItemList）的每一列
--      ⇒ 整列變暗、物品名稱欄的小圖示打勾
--   2. 點進去之後的購買頁頂端那一格物品（ItemBuyFrame／CommoditiesBuyFrame）
--      ⇒ 物品圖示變暗＋打勾。購買頁底下的拍賣清單不標：一頁全是同一件物品，
--        每列都勾只是噪音
--
-- 只處理暴雪原生的拍賣場清單。別的插件自己畫的購物清單不碰。
--
-- ## 掛點與 taint 紀律
--
-- 拍賣場的列跟直購／出價是同一條執行流（選一列 → 購買頁 → 直購），所以：
--   * **只用 hooksecurefunc 後置勾**，不 HookScript、不 RegisterCallback、
--     不碰任何 C_AuctionHouse 函式或購買按鈕
--   * **暴雪的列、格、按鈕上一個欄位都不寫**；只讀 `row.rowData`／`row.cells`／
--     `cell.Icon`，寫的只有 SetAlpha（C 端屬性，不是 Lua 欄位）與我們自己的打勾框
--   * **不呼叫清單的 Update／Refresh／SetDataProvider**：設定改了要重畫時，
--     自己走一遍目前看得到的列（ForEachFrame 是唯讀的），不去當 ScrollBox 的觸發者
--
-- 列是池化重用的：一列這次是坐騎、捲一下就變成藥水。所以每次 ScrollBox
-- 重新排版之後**看得到的每一列都重判一次**，勾與亮度不跟著列走殘影；
-- 打勾框記在 Dim 標記器的弱鍵表裡（key 是暴雪的格），不寫回列上。
--
-- 拍賣場的資料（itemKey、物品編號、寵物種類）不是秘密值；Collected 本身仍會
-- 擋秘密值，拿來當 key 前再檢查一次也不花什麼。
------------------------------------------------------------
local _, ns = ...

ns.AuctionHouse = {}
local AH = ns.AuctionHouse

local issecret = ns.Secret.IsSecret

-- 清單列的物品圖示只有 14px，勾縮到 11px、往右下溢出一點，不整顆蓋住圖示
local rowMarker
-- 購買頁頂端那一格跟商人的商品圖示差不多大，勾照商人那邊
local displayMarker

local browseBox
local displays = {}

local function Enabled()
    local db = ns.db
    return db and db.dim and db.dim.enabled and db.dim.auctionHouse
end

------------------------------------------------------------
-- itemKey → true / false / nil
--
-- 戰寵籠子的 itemKey 是「籠子物品＋battlePetSpeciesID」：籠子物品編號每隻都一樣，
-- 一定要照種類問，不然第一隻的結果會套到所有籠子上。
------------------------------------------------------------
local function IsKeyCollected(itemKey, link)
    if type(itemKey) ~= "table" then return nil end
    local speciesID = itemKey.battlePetSpeciesID
    if speciesID and not issecret(speciesID) and speciesID > 0 then
        return ns.Collected.IsSpecies(speciesID)
    end
    return ns.Collected.IsItem(itemKey.itemID, link)
end

------------------------------------------------------------
-- 瀏覽結果的一列
--
-- 名稱欄是那一列裡唯一同時有 Icon 與 IconBorder 的格；照欄位順序抓（cells[2]）
-- 的話，暴雪哪天在前面多插一欄就會抓錯。
------------------------------------------------------------
local scanEnabled = false

local function FindIconCell(row)
    local cells = row.cells
    if type(cells) ~= "table" then return nil end
    for _, cell in ipairs(cells) do
        if type(cell) == "table" and cell.Icon and cell.IconBorder then
            return cell
        end
    end
    return nil
end

local function MarkRow(row)
    local cell = FindIconCell(row)
    local collected
    if scanEnabled then
        local rowData = row.rowData
        if type(rowData) == "table" then
            collected = IsKeyCollected(rowData.itemKey)
        end
    end
    rowMarker:Set(row, cell, cell and cell.Icon, collected)
end

local function ScanBrowse()
    if not browseBox or not browseBox:IsVisible() then return end
    -- 清單第一次顯示前還沒有 view（暴雪在 OnShow 才 Init），這時候沒有列可走
    if not browseBox:GetView() then return end

    scanEnabled = Enabled() and true or false
    browseBox:ForEachFrame(MarkRow)

    if scanEnabled then
        -- 有列回 nil（物品資料還在路上）就掛上重試，資料到了再走一次
        ns.Collected.ArmRetry()
    end
end

------------------------------------------------------------
-- 購買頁頂端的物品格
--
-- 掛在 SetItemInternal 後面：設物品編號、設 itemKey、設背包位置三條路最後
-- 都走它，資料沒到時暴雪自己會在 GET_ITEM_INFO_RECEIVED 後再叫一次。
------------------------------------------------------------
local function MarkDisplay(display)
    local button = display.ItemButton
    if not button then return end

    local collected
    -- 不看 IsVisible：暴雪常在購買頁顯示之前就先把物品設好，這時候不判就要等到
    -- 下一次換物品才補得上
    if Enabled() and display:GetItem() ~= nil then
        collected = IsKeyCollected(display:GetItemKey(), display:GetItemLink())
    end
    displayMarker:Set(button, button, button, collected)
end

local function HookDisplay(display)
    if not display or type(display.SetItemInternal) ~= "function" then return end
    displays[#displays + 1] = display
    hooksecurefunc(display, "SetItemInternal", MarkDisplay)
end

------------------------------------------------------------
-- 設定改了／資料到了：重判目前看得到的東西
------------------------------------------------------------
function AH.Refresh()
    if not rowMarker then return end
    ScanBrowse()
    for _, display in ipairs(displays) do
        MarkDisplay(display)
    end
end

------------------------------------------------------------
-- 啟動：Blizzard_AuctionHouseUI 是隨選載入的，第一次開拍賣場才會進來
------------------------------------------------------------
local function Install()
    local frame = _G.AuctionHouseFrame
    if not frame then return false end

    local results = frame.BrowseResultsFrame
    local list = results and results.ItemList
    local box = list and list.ScrollBox
    if box and type(box.Update) == "function" and type(box.ForEachFrame) == "function" then
        browseBox = box
        -- Update 是 ScrollBox 重新排版的總出口：換資料、排序、捲動、改尺寸都會走到，
        -- 跑完的時候每一列的 rowData 都已經是這一輪的了
        hooksecurefunc(box, "Update", ScanBrowse)
    end

    local itemBuy = frame.ItemBuyFrame
    HookDisplay(itemBuy and itemBuy.ItemDisplay)

    local commodities = frame.CommoditiesBuyFrame
    local buyDisplay = commodities and commodities.BuyDisplay
    HookDisplay(buyDisplay and buyDisplay.ItemDisplay)

    return true
end

function AH.Init()
    rowMarker = ns.Dim.NewMarker(11, 3, -3)
    displayMarker = ns.Dim.NewMarker(14, 2, -2)

    if C_AddOns.IsAddOnLoaded("Blizzard_AuctionHouseUI") and Install() then
        return
    end

    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function(self, _, name)
        if name ~= "Blizzard_AuctionHouseUI" then return end
        self:UnregisterEvent("ADDON_LOADED")
        Install()
    end)
end
