------------------------------------------------------------
-- 自動修裝：開商人視窗就把全身修好（不碰任何框）
--
-- 2026-09-19 從 MiliUI 本體（Enhance/Merchant_Automation.lua）搬過來。設定入口
-- 早就長在耐久方塊上了（滑過就看得到、就按得到），行為卻住在另一支插件裡——
-- 「在哪裡改」跟「誰在做」對不起來。本體那邊現在只剩自動賣垃圾。
--
-- 流程：
--   1. 按住 Shift 這次不修——修裝是花錢的動作，一定要留一個當下就能取消的閘
--   2. CanMerchantRepair()：這個商人根本不提供修理就什麼都不做
--   3. GetRepairAllCost() 回 (花費, 修不修得起)
--   4. 公會金庫：RepairAllItems(1) 之後**再打一次** RepairAllItems()——
--      公會每日上限用完時第一下會失敗，第二下用個人的補完；全部由公會付掉的話
--      第二下是空包彈。這是行之有年的寫法，別自作聰明改成只打一次。
--
-- ⚠ **永遠在跑，不看耐久方塊有沒有啟用、也不看 db.enabled。** 這是行為不是顯示，
--   玩家把方塊收起來不代表他不想修裝了（同 Core/Warband.lua 的戰隊追蹤）。
--
-- 公會金庫預設關：花的是公會的錢，要不要用得由玩家自己說，不能替他決定。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

ns.AutoRepair = {}
local AR = ns.AutoRepair

------------------------------------------------------------
-- 設定（跟修裝按鈕的隱藏清單同住 db.repair）
------------------------------------------------------------
local function Store()
    local db = ns.GetDB()
    if type(db.repair) ~= "table" then db.repair = {} end
    return db.repair
end

-- nil 當預設（開）：DB_DEFAULTS 會補上，這裡只是不讓存檔有洞時整組失效
function AR.IsEnabled()
    return Store().auto ~= false
end

function AR.SetEnabled(v)
    Store().auto = v and true or false
end

function AR.IsGuild()
    return Store().guild == true
end

function AR.SetGuild(v)
    Store().guild = v and true or false
end

------------------------------------------------------------
-- 跟 Leatrix Plus 撞車的偵測
--
-- Leatrix 的執行期設定表是檔案內的 local，外面拿不到，所以沒辦法「幫他關掉」，
-- 也沒辦法即時同步——只能讀他的 SavedVariables。那份是登入當下的值，玩家在
-- 遊戲中改了要等下次 /reload 才看得到，所以文案要講清楚是登入時的狀態。
--
-- ⚠ 套組已經不內附 Leatrix Plus（2026-08-29 移除），這段仍然要**留著**：
--   玩家自己另外裝回來的時候 LeaPlusDB 才會存在；沒裝的話第一行就回 nil，
--   偵測自然靜音。留著的成本是零，拿掉的代價是那天沒人提醒。
------------------------------------------------------------
function AR.LeatrixConflict()
    local db = _G.LeaPlusDB
    if type(db) ~= "table" then return nil end
    if db.AutoRepairGear ~= "On" then return nil end
    return { guild = db.AutoRepairGuildFunds == "On" }
end

------------------------------------------------------------
-- 舊版本體的保險
--
-- 玩家只更新了資訊列、MiliUI 本體還停在「自己會修裝」的那一版時，兩邊會在
-- MERCHANT_SHOW 各修一次，而且「用不用公會金庫」要看誰先跑到。這種時候整組
-- 讓給本體（它讀的是玩家原本那份 MiliUI_DB.merchant，設定一致）。
-- **不做雙向同步**——兩份設定互相追著跑比多修一次難查得多。
------------------------------------------------------------
local function LegacyBodyHandlesRepair()
    local api = _G.MiliUI_MerchantAutomation
    return api ~= nil and type(api.IsAutoRepair) == "function"
end

local function CoinText(amount)
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinText then
        return C_CurrencyInfo.GetCoinText(amount)
    end
    return GetCoinTextureString(amount)
end

------------------------------------------------------------
-- 開商人視窗
------------------------------------------------------------
ns.Events.Register("MERCHANT_SHOW", "autorepair", function()
    if LegacyBodyHandlesRepair() then return end
    if not AR.IsEnabled() then return end
    if IsShiftKeyDown() then return end
    if not CanMerchantRepair() then return end

    local cost, canRepair = GetRepairAllCost()
    if not canRepair or not cost or cost <= 0 then return end

    local useGuild = AR.IsGuild() and IsInGuild() and CanGuildBankRepair()
    if useGuild then
        RepairAllItems(1)
        RepairAllItems()
    else
        RepairAllItems()
    end

    local msg = useGuild and L["MSG_REPAIRED_GUILD"] or L["MSG_REPAIRED"]
    print(ns.PREFIX_COLOR .. L["ADDON_NAME"] .. "|r " .. msg:format(CoinText(cost)))
end)

------------------------------------------------------------
-- 一次性遷移：把本體時期的兩個開關搬過來
--
-- 規矩同 Core/Warband.lua 的 MigrateFromMiliUI：PLAYER_LOGIN 才跑（MiliUI_DB 要
-- 等本體自己的 ADDON_LOADED 才存在）、**唯讀** MiliUI_DB 一個字都不寫、
-- 沒東西可搬也照樣蓋印記。
--
-- 只搬「跟預設不同」的那一半：預設值兩邊一樣，搬了也看不出差別，而且少一次
-- 寫入就少一次把髒資料抄進來的機會（型別不是 boolean 的一概不理）。
-- 不印訊息——這兩個開關搬過來之後玩家看得到的位置沒變（面板最上面兩列）。
------------------------------------------------------------
local function MigrateFromMiliUI(store)
    local old = _G.MiliUI_DB
    local merchant = (type(old) == "table") and old.merchant or nil
    if type(merchant) ~= "table" then return false end
    local moved = false
    if merchant.autoRepair == false then
        store.auto = false
        moved = true
    end
    if merchant.guildRepair == true then
        store.guild = true
        moved = true
    end
    return moved
end

ns.Events.Register("PLAYER_LOGIN", "autorepair", function()
    ns.InitDB()
    local store = Store()
    if store.migration == nil then
        store.migration = MigrateFromMiliUI(store) and "migrated" or "none"
    end

    -- 兩邊都開著的話會各修一次。第二次多半是空包彈，但「我明明關掉公會修裝了，
    -- 錢還是從公會扣」這種狀況只有講出來玩家才知道原因。延後幾秒再說，
    -- 不然會淹在登入時的一堆插件訊息裡。
    C_Timer.After(8, function()
        if LegacyBodyHandlesRepair() then return end
        if not (AR.IsEnabled() and AR.LeatrixConflict()) then return end
        print(ns.PREFIX_COLOR .. L["ADDON_NAME"] .. "|r "
            .. "|cffff9900" .. L["MSG_LEATRIX_REPAIR_CONFLICT"] .. "|r")
    end)
end)
