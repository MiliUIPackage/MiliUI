------------------------------------------------------------
-- 資料庫：帳號層設定（MiliUI_ShoppingList_DB）＋ 角色層清單（..._CharDB）
--
-- 為什麼清單是角色層：專業是角色的，A 角色要做的藥水跟 B 角色的附魔沒有關係，
-- 混在一起等於每次開清單都要先過濾。設定（含銀行、只看缺少…）反過來是帳號層，
-- 那是玩家的使用習慣，不會換個角色就變。
--
-- ⚠ MergeDefaults 只補 nil：發佈後要改任何預設值，都得配一條遷移（版本閘＋值閘）。
------------------------------------------------------------
local _, ns = ...

ns.DB = {}
local DB = ns.DB

-- 滑桿範圍：設定頁與正規化共用，改一處兩邊一起動
DB.LIMITS = {
    fontSize     = { 9, 20 },
    priceGuard   = { 2, 10 },
    confirmAbove = { 0, 20000 },   -- 金
}

local function BuildDefaults()
    return {
        schemaVersion = ns.DB_VERSION,

        settings = {
            font     = "",
            fontSize = 12,

            -- 持有量要不要把銀行／材料銀行／戰隊銀行算進來。
            -- 預設關：多數人買材料是為了「現在就做」，而現在能用的只有背包裡的。
            includeBank = false,

            -- 只列還缺的材料
            onlyMissing = true,

            -- 連商店貨與手動忽略的那幾列一起列出來（變暗）。預設關。
            showHidden = false,

            -- 商店買得到的材料不列進採購清單（拍賣場上那幾筆掛單通常是天價，
            -- 而且列了也只會讓「還缺什麼」看起來比實際多）。認得哪些是商店貨
            -- 靠自己逛商店時記下來的，見 Modules/Vendor.lua。
            hideVendor = true,

            -- 同步遊戲內的追蹤配方。預設關 —— 遊戲的追蹤清單常常塞著一堆
            -- 「以後想做」的東西，一開就把採購清單淹掉。
            syncTracked = false,

            -- 開拍賣場時自動貼一片面板出來
            ahPanel = true,
            -- 面板出現後自動搜尋一次全部
            ahAutoSearch = true,

            -- 購買前要不要停下來讓玩家看價格。
            -- **預設關**：多數時候買的是幾十金的材料，每一筆都要按第二下很煩。
            -- ⚠ 關著也不是完全沒有煞車：天價保險（priceGuard）攔下來的那幾筆
            --   一律強制確認，那是這個開關關不掉的最後一道。
            confirmBuys = false,
            -- 開了確認之後，只有總價超過這個金額（金）才問。0 ＝ 每一筆都問。
            confirmAbove = 0,

            -- 天價保險：報價單價高於本次登入看過的最低價幾倍，就強制要你確認
            priceGuard = 3,
        },

        -- 視窗位置：main / options
        windows = {},

        -- 逛過的商店賣些什麼（帳號層：A 角色逛到的 B 角色也算數）
        -- [itemID] = 商店賣價
        vendorItems = {},
    }
end
DB.BuildDefaults = BuildDefaults

local function BuildCharDefaults()
    return {
        schemaVersion = ns.DB_VERSION,
        -- 配方清單。每筆：{ key, recipeID, name, icon, quantity, yield, source,
        --                   orderType, reagents = { ... } }
        recipes = {},
        -- 額外物品（Shift 點連結加進來的）。每筆：{ itemID, quantity }
        extras  = {},
        -- [材料組 key] = 玩家挑的品質階級（1/2/3）
        quality = {},
        -- [材料組 key] = true，玩家手動叫它不要再列出來的
        ignored = {},
    }
end
DB.BuildCharDefaults = BuildCharDefaults

-- nil-merge：只補缺的鍵，不動玩家已有的值
local function MergeDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then
                dst[k] = CopyTable(v)
            else
                MergeDefaults(dst[k], v)
            end
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

-- 把玩家（或舊版本）可能弄壞的值夾回合法範圍
local function Normalize(db)
    local s = db.settings
    local lo, hi = DB.LIMITS.fontSize[1], DB.LIMITS.fontSize[2]
    if type(s.fontSize) ~= "number" then s.fontSize = 12 end
    s.fontSize = math.min(hi, math.max(lo, math.floor(s.fontSize)))

    lo, hi = DB.LIMITS.priceGuard[1], DB.LIMITS.priceGuard[2]
    if type(s.priceGuard) ~= "number" then s.priceGuard = 3 end
    s.priceGuard = math.min(hi, math.max(lo, math.floor(s.priceGuard)))

    lo, hi = DB.LIMITS.confirmAbove[1], DB.LIMITS.confirmAbove[2]
    if type(s.confirmAbove) ~= "number" then s.confirmAbove = 0 end
    s.confirmAbove = math.min(hi, math.max(lo, math.floor(s.confirmAbove)))
end

function DB.Init()
    if type(MiliUI_ShoppingList_DB) ~= "table" then MiliUI_ShoppingList_DB = {} end
    if type(MiliUI_ShoppingList_CharDB) ~= "table" then MiliUI_ShoppingList_CharDB = {} end

    MergeDefaults(MiliUI_ShoppingList_DB, BuildDefaults())
    MergeDefaults(MiliUI_ShoppingList_CharDB, BuildCharDefaults())

    ns.db  = MiliUI_ShoppingList_DB
    ns.cdb = MiliUI_ShoppingList_CharDB
    Normalize(ns.db)

    -- 清單本體再擋一次型別：SavedVariables 是玩家改得到的檔案，而下游整支
    -- 都是 ipairs(list)，型別錯的話錯誤會落在很遠的地方。
    if type(ns.cdb.recipes) ~= "table" then ns.cdb.recipes = {} end
    if type(ns.cdb.extras)  ~= "table" then ns.cdb.extras  = {} end
    if type(ns.cdb.quality) ~= "table" then ns.cdb.quality = {} end
    if type(ns.cdb.ignored) ~= "table" then ns.cdb.ignored = {} end
    if type(ns.db.vendorItems) ~= "table" then ns.db.vendorItems = {} end
end

function DB.ResetSettings()
    if not ns.db then return end
    ns.db.settings = BuildDefaults().settings
    Normalize(ns.db)
    ns.Media.UpdateFonts()
    ns.Fire("SettingsChanged")
    ns.Fire("ListChanged")
end
