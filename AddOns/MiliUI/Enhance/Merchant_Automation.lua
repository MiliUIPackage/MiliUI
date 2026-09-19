------------------------------------------------------------
-- MiliUI: 商人自動化（現在只剩自動賣垃圾）
--
-- ⚠ **自動修裝 2026-09-19 搬去 MiliUI_InfoBar/Core/AutoRepair.lua 了。**
--   原本這支的主張是「行為一律住本體，不要寄居在某個顯示元件裡」——修裝這一半
--   不成立：它的設定入口早就長在資訊列的耐久方塊上（滑過就看得到、就按得到），
--   行為卻在本體，改一個開關要跨兩支插件找。搬過去之後兩者同住，而且那邊的
--   事件註冊跟方塊的啟用與否無關，「方塊關掉就連行為一起消失」的顧慮不存在。
--   賣垃圾沒有對應的顯示元件，留在本體。
--
-- 走暴雪自己的 C_MerchantFrame.SellAllJunkItems()，也就是商人視窗那顆「賣掉
-- 所有垃圾」按鈕按下去跑的同一支（MerchantFrame_OnSellAllJunkButtonConfirmed）。
-- 不自己一格一格 UseContainerItem 的理由：
--   * 「什麼算垃圾」的判定留在暴雪那邊，不會跟遊戲本體各講各話
--   * 伺服器端一次處理完，不用 ticker 重試，也不會撞上物品鎖定
-- ⚠ 這支 API 直接就賣了，不會跳確認視窗——確認視窗是那顆按鈕自己加的。
-- 賣了多少是掃背包前後相減算出來的，不是讀 GetMoney()：入帳非同步，相減出來的
-- 金額才是這一趟真正的成果。
--
-- 讀寫於 MiliUI_DB.merchant（sellJunk 預設開）。
-- ⚠ `autoRepair`／`guildRepair` 兩格**不再補預設值、也不要刪**：資訊列的一次性
--   遷移（Core/AutoRepair.lua）要讀舊值，玩家原本關掉的自動修裝才不會自己開回來。
------------------------------------------------------------
local _, ns = ...

local function GetDB()
    if not MiliUI_DB then MiliUI_DB = {} end
    local db = MiliUI_DB.merchant
    if type(db) ~= "table" then
        db = {}
        MiliUI_DB.merchant = db
    end
    if db.sellJunk == nil then db.sellJunk = true end
    -- autoRepair／guildRepair 刻意不補預設：那兩格已經是資訊列在管，這裡只是
    -- 讓舊存檔裡的值留著給它遷移用（檔頭）。補預設等於替一個不再由本體負責的
    -- 設定憑空生出值。
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
--
-- 修裝那半的偵測搬去資訊列了（Core/AutoRepair.lua 有自己的一份），這裡只剩
-- 賣垃圾——兩個開關各自獨立，合併成一個回傳值會在不相干的地方跳警告。
------------------------------------------------------------
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

local frame = CreateFrame("Frame")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_SHOW" then
        SellJunk()
        return
    end
    -- 兩邊都開著的話會各賣一次（後到的那次是空包彈，但還是講一聲比較好查）。
    -- 延後幾秒再說，不然會淹在登入時的一堆插件訊息裡。
    C_Timer.After(8, function()
        if not (GetDB().sellJunk and LeatrixJunkConflict()) then return end
        print("|cffff9900登入時偵測到 Leatrix Plus 也開著自動賣垃圾。請關掉其中一邊。|r")
    end)
end)

------------------------------------------------------------
-- 對外 API（給 Options/Tab_QoL.lua 用）
--
-- ⚠ 自動修裝那幾支（IsAutoRepair／SetAutoRepair／IsGuildRepair／SetGuildRepair／
--   LeatrixConflict）已經拿掉。資訊列拿「這支還在不在」當「本體是不是舊版」的
--   判準（Core/AutoRepair.lua 的 LegacyBodyHandlesRepair），所以不要為了相容
--   又補一個空殼回來——補了就會變成兩邊都不修。
------------------------------------------------------------
MiliUI_MerchantAutomation = {
    GetDB = GetDB,
    LeatrixJunkConflict = LeatrixJunkConflict,
    IsSellJunk = function() return GetDB().sellJunk end,
    SetSellJunk = function(v) GetDB().sellJunk = v and true or false end,
}
