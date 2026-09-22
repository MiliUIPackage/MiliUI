------------------------------------------------------------
-- 自動修裝：開商人視窗就把全身修好（不碰任何框）
--
-- ── 跟 MiliUI 本體的分工（2026-09-23）──
-- 9/19 從本體搬過來之後，**沒開資訊列的玩家就沒修裝了**，所以現在兩邊都有：
--   * 本體在 ⇒ 本體修（MiliUI/Enhance/Merchant_Automation.lua），這裡不修。
--     AR.IsEnabled／SetEnabled／IsGuild／SetGuild 轉去讀寫本體的
--     MiliUI_DB.merchant，所以耐久面板、「修裝」分頁、本體的便利功能分頁三個
--     入口改的是同一份設定。寫的時候順手抄一份進自己的 db.repair（鏡像）。
--   * 只有資訊列 ⇒ 用自己的 db.repair 修。
-- 「本體在不在」一律**呼叫當下**才問（CoreAPI），不能在檔案層快取：
-- 本體的 Enhance 模組不保證比這支先載入。
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

-- 本體的修裝 API。舊版本體（9/19～9/23 那段）只剩賣垃圾、沒有 IsAutoRepair，
-- 那時照樣由這裡修——判準是「那支 API 在不在」，不是「本體在不在」。
-- 反過來，9/19 之前的舊本體也有 IsAutoRepair，一樣整組讓給它，設定同一份。
local function CoreAPI()
    local api = _G.MiliUI_MerchantAutomation
    if type(api) == "table" and type(api.IsAutoRepair) == "function"
        and type(api.SetAutoRepair) == "function" then
        return api
    end
end

-- nil 當預設（開）：DB_DEFAULTS 會補上，這裡只是不讓存檔有洞時整組失效
function AR.IsEnabled()
    local core = CoreAPI()
    if core then return core.IsAutoRepair() and true or false end
    return Store().auto ~= false
end

function AR.SetEnabled(v)
    v = v and true or false
    local core = CoreAPI()
    if core then core.SetAutoRepair(v) end
    Store().auto = v
end

function AR.IsGuild()
    local core = CoreAPI()
    if core and core.IsGuildRepair then return core.IsGuildRepair() and true or false end
    return Store().guild == true
end

function AR.SetGuild(v)
    v = v and true or false
    local core = CoreAPI()
    if core and core.SetGuildRepair then core.SetGuildRepair(v) end
    Store().guild = v
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
    -- 本體會修就整組讓給它：兩邊都修的話第二下多半是空包彈，但「用不用公會
    -- 金庫」會變成看誰先跑到
    if CoreAPI() then return end
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
-- （這支只讀；要寫本體的設定一律走 SyncWithCore → 本體自己的 API。）
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

------------------------------------------------------------
-- 跟本體對齊設定
--
-- 兩份存檔只有一份是真相：本體在的時候是本體那份。db.repair.coreSync 記的是
-- 「上次登入時本體在不在」：
--   * 本體在、印記是 nil ⇒ 這是本體第一次出現（含 9/23 這次改版：9/19 以來玩家
--     是在資訊列上改的），或是本體被停用過一陣子、期間玩家在資訊列上改過 ⇒
--     把資訊列這份**推給本體**，蓋印記
--   * 本體在、印記已蓋 ⇒ 本體那份才是最新（可能在本體設定頁改過）⇒
--     **抄回資訊列**當鏡像，哪天本體被拔掉就從這份接著用
--   * 本體不在 ⇒ 印記清掉，下次本體回來時推過去
-- 要排在 MigrateFromMiliUI 之後：沒遷移過的玩家先從 MiliUI_DB 搬舊值進來，
-- 推回去的就是同一組值，不會把玩家原本關掉的修裝推成開的。
------------------------------------------------------------
local function SyncWithCore(store)
    local core = CoreAPI()
    if not core then
        store.coreSync = nil
        return
    end
    if not store.coreSync then
        core.SetAutoRepair(store.auto ~= false)
        if core.SetGuildRepair then core.SetGuildRepair(store.guild == true) end
        store.coreSync = true
    else
        store.auto = core.IsAutoRepair() and true or false
        if core.IsGuildRepair then store.guild = core.IsGuildRepair() and true or false end
    end
end
AR.SyncWithCore = function() SyncWithCore(Store()) end

ns.Events.Register("PLAYER_LOGIN", "autorepair", function()
    ns.InitDB()
    local store = Store()
    if store.migration == nil then
        store.migration = MigrateFromMiliUI(store) and "migrated" or "none"
    end
    SyncWithCore(store)

    -- 兩邊都開著的話會各修一次。第二次多半是空包彈，但「我明明關掉公會修裝了，
    -- 錢還是從公會扣」這種狀況只有講出來玩家才知道原因。延後幾秒再說，
    -- 不然會淹在登入時的一堆插件訊息裡。
    -- 本體在的時候本體自己會講（它才是會修的那邊），這裡不重複。
    C_Timer.After(8, function()
        if CoreAPI() then return end
        if not (AR.IsEnabled() and AR.LeatrixConflict()) then return end
        print(ns.PREFIX_COLOR .. L["ADDON_NAME"] .. "|r "
            .. "|cffff9900" .. L["MSG_LEATRIX_REPAIR_CONFLICT"] .. "|r")
    end)
end)
