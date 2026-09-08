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
    fontSize   = { 9, 20 },
    priceGuard = { 2, 10 },
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

            -- 只列還缺的材料（採購分頁的預設視角）
            onlyMissing = true,

            -- 同步遊戲內的追蹤配方。預設關 —— 遊戲的追蹤清單常常塞著一堆
            -- 「以後想做」的東西，一開就把採購清單淹掉。
            syncTracked = false,

            -- 開拍賣場時自動貼一片面板出來
            ahPanel = true,
            -- 面板出現後自動搜尋一次全部
            ahAutoSearch = true,

            -- 天價保險：報價單價高於本次登入看過的最低價幾倍，就把總價標紅
            priceGuard = 3,
        },

        -- 視窗位置：main / options
        windows = {},
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
end

function DB.ResetSettings()
    if not ns.db then return end
    ns.db.settings = BuildDefaults().settings
    Normalize(ns.db)
    ns.Media.UpdateFonts()
    ns.Fire("SettingsChanged")
    ns.Fire("ListChanged")
end
