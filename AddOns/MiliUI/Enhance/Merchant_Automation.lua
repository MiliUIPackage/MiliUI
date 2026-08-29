------------------------------------------------------------
-- MiliUI: 商人自動化
--
-- 開商人視窗時自動發生的事：先賣垃圾，再修裝。這類「行為」跟顯示元件無關，
-- 一律住在本體，不要各自去挑一個不相干的元件寄居——住在本體才不會因為某個
-- 方塊被關掉就連設定入口一起消失。
--
-- 「先賣後修」的順序沒有辦法讓賣來的錢救到這一次的修裝（入帳是伺服器非同步
-- 回來的，趕不上同一幀的 GetRepairAllCost()），但反過來排也沒有任何好處。
--
-- ── 自動賣垃圾 ──
-- 走暴雪自己的 C_MerchantFrame.SellAllJunkItems()，也就是商人視窗那顆「賣掉
-- 所有垃圾」按鈕按下去跑的同一支（MerchantFrame_OnSellAllJunkButtonConfirmed）。
-- 不自己一格一格 UseContainerItem 的理由：
--   * 「什麼算垃圾」的判定留在暴雪那邊，不會跟遊戲本體各講各話
--   * 伺服器端一次處理完，不用 ticker 重試，也不會撞上物品鎖定
-- ⚠ 這支 API 直接就賣了，不會跳確認視窗——確認視窗是那顆按鈕自己加的。
-- 賣了多少是掃背包前後相減算出來的，不是讀 GetMoney()：入帳非同步，會跟同一次
-- 開商人的修裝花費混在一起，相減出來的金額是錯的。
--
-- ── 自動修裝 ──
-- 流程照 Leatrix Plus 的 RepairFunc（Leatrix_Plus.lua 的 "Repair automatically"）：
--   1. 按住 Shift 這次不修——修裝是花錢的動作，一定要留一個當下就能取消的閘
--   2. CanMerchantRepair()：這個商人根本不提供修理就什麼都不做
--   3. GetRepairAllCost() 回 (花費, 修不修得起)
--   4. 公會金庫：RepairAllItems(1) 之後**再打一次** RepairAllItems()——
--      公會每日上限用完時第一下會失敗，第二下用個人的補完；全部由公會付掉的話
--      第二下是空包彈。這是 Leatrix 用了很久的寫法，別自作聰明改成只打一次。
--
-- 讀寫於 MiliUI_DB.merchant（autoRepair 預設開、sellJunk 預設開、guildRepair
-- 預設關）。公會金庫花的是公會的錢，要不要用得由玩家自己說，不能替他決定。
------------------------------------------------------------
local _, ns = ...

local function GetDB()
    if not MiliUI_DB then MiliUI_DB = {} end
    local db = MiliUI_DB.merchant
    if type(db) ~= "table" then
        db = {}
        MiliUI_DB.merchant = db
    end
    if db.autoRepair == nil then db.autoRepair = true end
    if db.sellJunk == nil then db.sellJunk = true end
    if db.guildRepair == nil then db.guildRepair = false end
    return db
end

------------------------------------------------------------
-- 跟 Leatrix Plus 撞車的偵測（做法同 MiliUI_QuestTracker/Modules/AutoQuest.lua）
--
-- Leatrix 的執行期設定表是檔案內的 local，外面拿不到，所以沒辦法「幫他關掉」，
-- 也沒辦法即時同步——只能讀他的 SavedVariables。那份是登入當下的值，玩家在
-- 遊戲中改了要等下次 /reload 才看得到，所以文案要講清楚是登入時的狀態。
--
-- ⚠ 套組已經不內附 Leatrix Plus（2026-08-29 移除），這段仍然要**留著**：
--   玩家自己另外裝回來的時候 LeaPlusDB 才會存在；沒裝的話下面第一行就回 nil，
--   偵測自然靜音。留著的成本是零，拿掉的代價是那天沒人提醒。
------------------------------------------------------------
local function LeatrixConflict()
    local db = _G.LeaPlusDB
    if type(db) ~= "table" then return nil end
    if db.AutoRepairGear ~= "On" then return nil end
    return { guild = db.AutoRepairGuildFunds == "On" }
end

-- 賣垃圾那邊是另一個開關，跟修裝各自獨立，所以分成兩支——不要合併成一個
-- 回傳值，資訊列的修裝選單只認修裝那一邊，混在一起會在不相干的地方跳警告。
local function LeatrixJunkConflict()
    local db = _G.LeaPlusDB
    if type(db) ~= "table" then return nil end
    if db.AutoSellJunk ~= "On" then return nil end
    return true
end

local function CoinText(amount)
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinText then
        return C_CurrencyInfo.GetCoinText(amount)
    end
    return GetCoinTextureString(amount)
end

------------------------------------------------------------
-- 自動賣垃圾
------------------------------------------------------------
local POOR = (Enum and Enum.ItemQuality and Enum.ItemQuality.Poor) or 0
-- 0 是背包，最後一格是材料包；常數不在就退回 5（4 個包包 ＋ 材料包）
local LAST_BAG = _G.NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5

-- 回傳背包裡的垃圾件數與總賣價。賣完之後再掃一次相減，就是這一趟實際的成果——
-- 不必猜 SellAllJunkItems() 什麼時候跑完，也不會把賣不掉的那些算進去。
local function ScanJunk()
    local count, value = 0, 0
    for bag = 0, LAST_BAG do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            -- hasNoValue 的東西商人不收，暴雪的垃圾計數也不算它
            if info and info.quality == POOR and not info.hasNoValue then
                count = count + 1
                local price = info.itemID and select(11, C_Item.GetItemInfo(info.itemID))
                local stack = info.stackCount
                -- 沒進快取的物品讀不到價格；件數照算，金額就少算這一筆
                if type(price) == "number" and type(stack) == "number" then
                    value = value + price * stack
                end
            end
        end
    end
    return count, value
end

local function SellJunk()
    local db = GetDB()
    if not db.sellJunk then return end
    if IsShiftKeyDown() then return end
    if not (C_MerchantFrame and C_MerchantFrame.SellAllJunkItems) then return end
    -- 有些玩法（遊戲規則）整個關掉這個功能，那時暴雪自己也不長那顆按鈕
    if C_MerchantFrame.IsSellAllJunkEnabled and not C_MerchantFrame.IsSellAllJunkEnabled() then
        return
    end

    local before, valueBefore = ScanJunk()
    if before <= 0 then return end

    C_MerchantFrame.SellAllJunkItems()

    -- 延後回報：這個商人不收東西（ERR_VENDOR_DOESNT_BUY）時一件都不會少，
    -- 當場就印「已賣出」是在說謊。等背包真的變了再講。
    C_Timer.After(1, function()
        local after, valueAfter = ScanJunk()
        local sold = before - after
        if sold <= 0 then return end
        local gained = valueBefore - valueAfter
        print("|cff00FFFFMiliUI|r " .. (gained > 0
            and ("已賣出 " .. sold .. " 件垃圾，得到 " .. CoinText(gained) .. "。")
            or  ("已賣出 " .. sold .. " 件垃圾。")))
    end)
end

------------------------------------------------------------
-- 自動修裝
------------------------------------------------------------
local function AutoRepair()
    local db = GetDB()
    if not db.autoRepair then return end
    if IsShiftKeyDown() then return end
    if not CanMerchantRepair() then return end

    local cost, canRepair = GetRepairAllCost()
    if not canRepair or not cost or cost <= 0 then return end

    local useGuild = db.guildRepair and IsInGuild() and CanGuildBankRepair()
    if useGuild then
        RepairAllItems(1)
        RepairAllItems()
    else
        RepairAllItems()
    end

    print("|cff00FFFFMiliUI|r " .. (useGuild
        and ("已修裝，花費 " .. CoinText(cost) .. "（優先使用公會金庫）。")
        or  ("已修裝，花費 " .. CoinText(cost) .. "。")))
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_SHOW" then
        SellJunk()
        AutoRepair()
        return
    end
    -- 兩邊都開著的話會各自做一次。修裝的第二次多半是空包彈，但「我明明關掉
    -- 公會修裝了，錢還是從公會扣」這種狀況只有講出來玩家才知道原因。
    -- 延後幾秒再說，不然會淹在登入時的一堆插件訊息裡。
    C_Timer.After(8, function()
        local db = GetDB()
        local repairClash = db.autoRepair and LeatrixConflict()
        local junkClash = db.sellJunk and LeatrixJunkConflict()
        if not (repairClash or junkClash) then return end
        local what = repairClash and junkClash and "自動修裝與自動賣垃圾"
            or (repairClash and "自動修裝" or "自動賣垃圾")
        print("|cffff9900登入時偵測到 Leatrix Plus 也開著" .. what .. "。請關掉其中一邊。"
            .. (repairClash and "兩支插件會各修一次，「優先使用公會金庫」不一定是勝出的那邊。" or "") .. "|r")
    end)
end)

------------------------------------------------------------
-- 對外 API（給 Options/Tab_Enhance.lua 與 MiliUI_InfoBar 的耐久方塊用）
------------------------------------------------------------
MiliUI_MerchantAutomation = {
    GetDB = GetDB,
    LeatrixConflict = LeatrixConflict,
    LeatrixJunkConflict = LeatrixJunkConflict,
    IsAutoRepair = function() return GetDB().autoRepair end,
    SetAutoRepair = function(v) GetDB().autoRepair = v and true or false end,
    IsSellJunk = function() return GetDB().sellJunk end,
    SetSellJunk = function(v) GetDB().sellJunk = v and true or false end,
    IsGuildRepair = function() return GetDB().guildRepair end,
    SetGuildRepair = function(v) GetDB().guildRepair = v and true or false end,
}
