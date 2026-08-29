------------------------------------------------------------
-- MiliUI: 商人自動化
--
-- 開商人視窗時自動發生的事。目前只有自動修裝；賣垃圾之類的以後加在這裡，
-- 不要再各自去挑一個不相干的元件寄居——這類「行為」跟顯示元件無關，
-- 住在本體才不會因為某個方塊被關掉就連設定入口一起消失。
--
-- 流程照 Leatrix Plus 的 RepairFunc（Leatrix_Plus.lua 的 "Repair automatically"）：
--   1. 按住 Shift 這次不修——修裝是花錢的動作，一定要留一個當下就能取消的閘
--   2. CanMerchantRepair()：這個商人根本不提供修理就什麼都不做
--   3. GetRepairAllCost() 回 (花費, 修不修得起)
--   4. 公會金庫：RepairAllItems(1) 之後**再打一次** RepairAllItems()——
--      公會每日上限用完時第一下會失敗，第二下用個人的補完；全部由公會付掉的話
--      第二下是空包彈。這是 Leatrix 用了很久的寫法，別自作聰明改成只打一次。
--
-- 讀寫於 MiliUI_DB.merchant（autoRepair 預設開、guildRepair 預設關）。
-- 公會金庫花的是公會的錢，要不要用得由玩家自己說，不能替他決定。
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
-- ⚠ 這段在 Leatrix 被移除之後要**留著**：那時 LeaPlusDB 這個全域不存在，
--   下面第一行就回 nil，偵測自然靜音。留著的成本是零，拿掉的代價是哪天又裝
--   回來（或裝了別的同功能插件）就沒人提醒了。
------------------------------------------------------------
local function LeatrixConflict()
    local db = _G.LeaPlusDB
    if type(db) ~= "table" then return nil end
    if db.AutoRepairGear ~= "On" then return nil end
    return { guild = db.AutoRepairGuildFunds == "On" }
end

local function CoinText(amount)
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinText then
        return C_CurrencyInfo.GetCoinText(amount)
    end
    return GetCoinTextureString(amount)
end

local function OnMerchantShow()
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
        OnMerchantShow()
        return
    end
    -- 兩邊都開著的話會各自呼叫一次 RepairAllItems。第二次多半是空包彈，
    -- 但「我明明關掉公會修裝了，錢還是從公會扣」這種狀況只有講出來玩家才知道原因。
    -- 延後幾秒再說，不然會淹在登入時的一堆插件訊息裡。
    C_Timer.After(8, function()
        if not GetDB().autoRepair then return end
        if not LeatrixConflict() then return end
        print("|cffff9900登入時偵測到 Leatrix Plus 也開著自動修裝。請關掉其中一邊，"
            .. "否則兩支插件會各修一次，「優先使用公會金庫」不一定是勝出的那邊。|r")
    end)
end)

------------------------------------------------------------
-- 對外 API（給 Options/Tab_Enhance.lua 與 MiliUI_InfoBar 的耐久方塊用）
------------------------------------------------------------
MiliUI_MerchantAutomation = {
    GetDB = GetDB,
    LeatrixConflict = LeatrixConflict,
    IsAutoRepair = function() return GetDB().autoRepair end,
    SetAutoRepair = function(v) GetDB().autoRepair = v and true or false end,
    IsGuildRepair = function() return GetDB().guildRepair end,
    SetGuildRepair = function(v) GetDB().guildRepair = v and true or false end,
}
