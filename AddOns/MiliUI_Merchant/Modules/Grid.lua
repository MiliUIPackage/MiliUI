------------------------------------------------------------
-- 商品格：補建、排版、視窗尺寸
--
-- 整支插件的核心就三步：
--   1. 照設定的列×欄補建 `MerchantItem13` … `MerchantItemN`（用暴雪自己的
--      `MerchantItemTemplate`，所以點擊、拖曳、工具提示、拆堆疊全部是暴雪的）
--   2. 把 `MERCHANT_ITEMS_PER_PAGE` 寫成那個數字 —— **這是唯一寫出去的暴雪全域**
--   3. 暴雪每次重畫完，把格子排成我們要的形狀、視窗調成對應的大小
--
-- ⚠ 格子一定要有**全域名字**：`MerchantItemTemplate` 裡的子元件全部用 `$parent`
--   命名（`$parentItemButton`、`$parentMoneyFrame`、`$parentName`…），而暴雪的
--   重畫迴圈是拿 `_G["MerchantItem"..i.."MoneyFrame"]` 去找它們的。匿名 frame
--   建得起來，但那一格永遠是空的，而且不會報錯。
--
-- ⚠ **暴雪的框上一個欄位都不寫。** 包含我們自己建的第 13 格以後 —— 它們跑的是
--   暴雪的處理器，一視同仁。要記東西就記在這支自己的 local 裡。
------------------------------------------------------------
local _, ns = ...

ns.Grid = {}
local Grid = ns.Grid

------------------------------------------------------------
-- 常數（全部照 Blizzard_UIPanels_Game/MerchantFrame.xml 的原始數字）
------------------------------------------------------------
local CELL_W, CELL_H     = 153, 44     -- MerchantItemTemplate 的尺寸
local ORIGIN_X, ORIGIN_Y = 11, -69     -- MerchantItem1 錨在 MerchantFrame TOPLEFT
local COL_PITCH          = CELL_W + 12 -- 165：格寬 ＋ 水平間距
local ROW_PITCH          = CELL_H + 8  -- 52：商人分頁的垂直間距
local BUYBACK_ROW_PITCH  = CELL_H + 15 -- 59：買回分頁的垂直間距（暴雪排得比較鬆）
local BASE_W, BASE_H     = 336, 444    -- 原尺寸
local BASE_ROWS, BASE_COLS = 5, 2      -- 原尺寸下的列×欄
local BUYBACK_COLS       = 2           -- 買回分頁固定 2 欄 × 6 列 = 12 格
local STOCK_CELLS        = 12          -- 暴雪自己建好的格子數（1…12）

------------------------------------------------------------
-- 狀態
------------------------------------------------------------
-- 目前存在的格子數（只增不減：frame 刪不掉，多的只能 Hide）
local created = STOCK_CELLS

-- /mmerchant debug 用的計數器。掛勾跑了幾次、其中幾次是「框根本沒開」被閘掉的
Grid.stats = { hookRuns = 0, hookGated = 0 }

local gearButton

------------------------------------------------------------
-- 補建格子
--
-- ⚠ 只增不刪。frame 在魔獸裡是刪不掉的（`:Hide()` 只是藏起來，物件永遠留著），
--   所以玩家把欄數調小再調大時，我們重用舊的那幾個而不是再建一批。
------------------------------------------------------------
local function EnsureCells(n)
    for i = created + 1, n do
        CreateFrame("Frame", "MerchantItem" .. i, MerchantFrame, "MerchantItemTemplate")
    end
    if n > created then created = n end
end

------------------------------------------------------------
-- 排版：1…count 排成 cols 欄，其餘藏起來
--
-- 方向固定「先左到右、再上到下」—— 暴雪原本的 1..12 就是這個順序
-- （1 2 / 3 4 / 5 6 …），改成直排會讓看慣的人每次都要重新找東西。
--
-- ⚠ **每次重畫都要排一遍，不能只在尺寸變動時排。** 暴雪的
--   `MerchantFrame_UpdateMerchantInfo` 結尾固定會把 3/5/7/9 四格的 TOPLEFT
--   重設回兩欄排版（買回分頁換成另一組間距），不重排的話那四格會每次跳回去。
------------------------------------------------------------
local function LayoutCells(count, cols, rowPitch)
    for i = 1, created do
        local cell = _G["MerchantItem" .. i]
        if cell then
            if i <= count then
                local row = math.ceil(i / cols)
                local col = i - (row - 1) * cols
                cell:ClearAllPoints()
                cell:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT",
                    ORIGIN_X + (col - 1) * COL_PITCH,
                    ORIGIN_Y - (row - 1) * rowPitch)
                cell:Show()
            else
                cell:Hide()
            end
        end
    end
end

------------------------------------------------------------
-- 視窗尺寸
--
-- 比對的是**框當下的實際尺寸**而不是自己記的上一次值：記的那份只要有別人
-- （或暴雪自己）動過一次就會失準，而失準的方向是「該調的時候不調」。
------------------------------------------------------------
local function ApplySize(w, h)
    local curW, curH = MerchantFrame:GetWidth(), MerchantFrame:GetHeight()
    if math.abs((curW or 0) - w) < 0.5 and math.abs((curH or 0) - h) < 0.5 then
        return
    end
    MerchantFrame:SetSize(w, h)
end

------------------------------------------------------------
-- 目前的一頁格數
------------------------------------------------------------
function Grid.PerPage()
    local db = ns.db
    if not db then return STOCK_CELLS end
    return db.rows * db.cols
end

------------------------------------------------------------
-- 一次性重錨
--
-- 這兩個元件原本是掛在「會被我們搬走的東西」上的，而暴雪的 Lua **不會**再重錨
-- 它們（只有 3/5/7/9 那四格會被重設）。所以在原尺寸下換成等價的絕對錨點，
-- 之後就一勞永逸：
--
--   MerchantBuyBackItem   原本錨 MerchantItem10 的 BOTTOMLEFT (30, -53)。
--                         第 10 格一被搬到別的位置，買回格就跟著飛走。
--   MerchantNextPageButton 原本錨 MerchantFrame BOTTOMLEFT (310, 96)，
--                         視窗一變寬就停在左半邊。
--
-- 換算過的數字在原尺寸（336×444）下與原本**完全同一個點**，所以把插件關掉也
-- 不會留下位移。
------------------------------------------------------------
local function ReanchorOnce()
    if MerchantBuyBackItem then
        MerchantBuyBackItem:ClearAllPoints()
        MerchantBuyBackItem:SetPoint("TOPLEFT", MerchantFrame, "BOTTOMLEFT", 206, 70)
    end
    if MerchantNextPageButton then
        MerchantNextPageButton:ClearAllPoints()
        MerchantNextPageButton:SetPoint("CENTER", MerchantFrame, "BOTTOMRIGHT", -26, 96)
    end
end

------------------------------------------------------------
-- 齒輪鈕：設定入口長在用得到它的地方
--
-- 擺在商人視窗自己的篩選鈕左邊。要調「一頁幾格」的時刻幾乎一定是站在商人面前
-- 的時候，那時候叫人去打指令或翻設定選單是沒有道理的。
------------------------------------------------------------
local function CreateGearButton()
    local b = CreateFrame("Button", nil, MerchantFrame)
    b:SetSize(16, 16)

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    if C_Texture.GetAtlasInfo("worldquest-icon-engineering") then
        icon:SetAtlas("worldquest-icon-engineering")
    else
        icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    end
    -- 狀態只換明暗、不換色：閒置壓暗，滑過回到全亮
    icon:SetVertexColor(0.65, 0.65, 0.65)

    b:SetScript("OnEnter", function(self)
        icon:SetVertexColor(1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.L["MiliUI Merchant"], 1, 1, 1)
        GameTooltip:AddLine(ns.L["Click to change how many rows and columns of goods to show."], nil, nil, nil, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function()
        icon:SetVertexColor(0.65, 0.65, 0.65)
        GameTooltip:Hide()
    end)
    b:SetScript("OnClick", function() ns.OpenOptions() end)

    -- 篩選鈕本身會被遊戲規則整顆關掉（`MerchantFilterDisabled`），但**隱藏的框
    -- 照樣有矩形**，所以錨在它身上不會因為它被藏起來而跑位。真的沒有那顆鈕的
    -- 舊客戶端才退回自己算位置。
    local dropdown = MerchantFrame.FilterDropdown
    if dropdown then
        b:SetPoint("RIGHT", dropdown, "LEFT", -4, 0)
    else
        b:SetPoint("TOPRIGHT", MerchantFrame, "TOPRIGHT", -167, -38)
    end
    return b
end

------------------------------------------------------------
-- 重刷：商人框開著才有意義
------------------------------------------------------------
function Grid.Refresh()
    if ns.dormant or not ns.db then return end
    if not MerchantFrame or not MerchantFrame:IsShown() then return end
    MerchantFrame_Update()
end

------------------------------------------------------------
-- 套用設定（設定頁改了列／欄數、或還原預設值）
--
-- ⚠ **不直接寫 `MerchantFrame.page`。** 格數變大之後原本的第 3 頁可能根本不存在，
--   但那個欄位是暴雪的，寫進去就是把污染直接種在它的重畫流程裡。改成一路按
--   「上一頁」退回來 —— 那是暴雪自己的函式，頁碼、按鈕狀態、拆堆疊視窗全部由它
--   處理，我們只負責讀。
------------------------------------------------------------
function Grid.Apply()
    if ns.dormant or not ns.db then return end

    local perPage = Grid.PerPage()
    EnsureCells(perPage)
    MERCHANT_ITEMS_PER_PAGE = perPage

    -- ⚠ 收藏快取記的是「照**當時開著的類別**算出來的結果」：塑形關著的時候，
    --   一件護甲會被記成 false。類別勾起來之後不清快取，那一格要到關掉商人
    --   才會變暗 —— 看起來就是「勾了沒反應」。
    ns.Collected.Wipe()

    if not MerchantFrame:IsShown() then return end

    if MerchantFrame.selectedTab == 1 then
        local numItems = GetMerchantNumItems() or 0
        local maxPage = math.max(1, math.ceil(numItems / perPage))
        -- 上限只是防呆：正常情況下最多退幾頁是算得出來的，
        -- 但 page 是別人的欄位，拿它當迴圈條件就該給一個出口
        local guard = 0
        while (tonumber(MerchantFrame.page) or 1) > maxPage and guard < 64 do
            MerchantPrevPageButton_OnClick()
            guard = guard + 1
        end
    end

    MerchantFrame_Update()
end

------------------------------------------------------------
-- 掛勾
--
-- ⚠ 第一行一定要有 `IsShown` 閘。暴雪在 `MerchantFrame_OnLoad` 就註冊了
--   `BAG_UPDATE` 與 `UNIT_INVENTORY_CHANGED`，所以商人框**沒開的時候照樣會跑
--   `MerchantFrame_Update`** —— 登入後光是背包整理就能跑上千次。少了這個閘，
--   那上千次全部會變成「重排 N 個格子 ＋ 量視窗尺寸」的空轉。
------------------------------------------------------------
local function OnMerchantInfo()
    Grid.stats.hookRuns = Grid.stats.hookRuns + 1
    if not MerchantFrame:IsShown() then
        Grid.stats.hookGated = Grid.stats.hookGated + 1
        return
    end

    local db = ns.db
    local perPage = Grid.PerPage()
    ApplySize(BASE_W + (db.cols - BASE_COLS) * COL_PITCH,
              BASE_H + (db.rows - BASE_ROWS) * ROW_PITCH)
    LayoutCells(perPage, db.cols, ROW_PITCH)
end

------------------------------------------------------------
-- 買回分頁：暴雪固定畫 12 格、視窗回到原尺寸
--
-- ⚠ 暴雪的買回分頁只會 `Show()` 第 11、12 格 —— 它假設 1…10 永遠顯示著
--   （在它的世界裡那十格從來沒被藏過）。我們把 1…12 全部重新 Show 一次。
------------------------------------------------------------
local function OnBuybackInfo()
    Grid.stats.hookRuns = Grid.stats.hookRuns + 1
    if not MerchantFrame:IsShown() then
        Grid.stats.hookGated = Grid.stats.hookGated + 1
        return
    end

    ApplySize(BASE_W, BASE_H)
    LayoutCells(STOCK_CELLS, BUYBACK_COLS, BUYBACK_ROW_PITCH)

    -- 買回的東西沒有「已收藏」的概念（是自己剛賣掉的），alpha 一律還原
    for i = 1, STOCK_CELLS do
        local cell = _G["MerchantItem" .. i]
        if cell then cell:SetAlpha(1) end
    end
    ns.Dim.HideAll()
end

------------------------------------------------------------
-- 啟動
------------------------------------------------------------
function Grid.Init()
    local perPage = Grid.PerPage()
    EnsureCells(perPage)
    MERCHANT_ITEMS_PER_PAGE = perPage

    ReanchorOnce()
    gearButton = CreateGearButton()

    hooksecurefunc("MerchantFrame_UpdateMerchantInfo", OnMerchantInfo)
    hooksecurefunc("MerchantFrame_UpdateBuybackInfo", OnBuybackInfo)
end

------------------------------------------------------------
-- /mmerchant debug 用
------------------------------------------------------------
function Grid.CreatedCells()
    return created
end
