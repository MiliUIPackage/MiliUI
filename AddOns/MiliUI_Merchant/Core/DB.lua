------------------------------------------------------------
-- 設定資料：預設值、nil-merge
--
-- ⚠ MergeDefaults 只補 nil：發佈後要改任何預設值，都得配一條遷移（版本閘＋值閘）。
------------------------------------------------------------
local _, ns = ...

ns.DB = {}
local DB = ns.DB

-- 滑桿範圍：設定頁與 DB 正規化共用，改一處兩邊一起動。
--
-- 上限不是隨便取的：欄數 6 讓視窗寬到 996（1600 寬的畫面還放得下一半），
-- 列數 10 讓視窗高到 704。再往上就會有玩家在 1080p 上看到視窗超出畫面，
-- 而商人視窗是 toplevel、拖得動但拖不回被裁掉的那一截。
DB.LIMITS = {
    rows = { 5, 10 },
    cols = { 2, 6 },
}

local function BuildDefaults()
    return {
        schemaVersion = ns.DB_VERSION,
        optionsWindow = { x = 0, y = 0 },

        -- 5×4 = 20 格。原廠是 2×5＝10 格，欄數加寬比列數加高划算：
        -- 商品格本來就是寬的（153×44），往右長一欄只多 165px
        rows = 5,
        cols = 4,

        -- 格子的排列順序：across＝先往右（暴雪原本的 1 2 / 3 4）、down＝先往下排滿一欄
        order = "across",

        -- Shift 點商品、想買的量超過一組時換成批量購買視窗（Modules/BulkBuy.lua）
        bulkBuy = true,

        dim = {
            enabled = true,

            pets    = true,
            mounts  = true,
            toys    = true,
            recipes = true,

            -- 塑形預設關：判定只看「這個外觀學過沒」，不看職業能不能穿，
            -- 而且套組裡已經有插件在商品圖示上畫塑形角標了，兩套一起上太吵
            transmog = false,

            -- 房屋裝飾預設關：裝飾品常常要買好幾個擺滿一整間房，
            -- 「有了一個」不等於「不用再買」
            housing  = false,

            -- 拍賣場的搜尋結果與點進去的購買頁也套同一套判定（Modules/AuctionHouse.lua）
            auctionHouse = true,
        },
    }
end
DB.BuildDefaults = BuildDefaults

-- nil-merge：只補缺的鍵，不動玩家已有的值（共用層 Libs/MiliUIDB.lua，行為與原本那份相同）
local MergeDefaults = ns.MiliUIDB.MergeDefaults

------------------------------------------------------------
-- 值域夾制
--
-- ⚠ 這一支不只是「滑桿範圍改小之後的舊存檔」：rows/cols 直接決定我們要建幾個
--   frame、以及寫進 MERCHANT_ITEMS_PER_PAGE 的數字。存檔壞掉（手改、或別的
--   插件寫進來）時，沒有這道閘就是拿一個 nil 或 5000 去乘。
------------------------------------------------------------
local function Clamp(db, key)
    local limits = DB.LIMITS[key]
    local v = tonumber(db[key])
    if not v then
        db[key] = BuildDefaults()[key]
        return
    end
    v = math.floor(v + 0.5)
    if v < limits[1] then v = limits[1] end
    if v > limits[2] then v = limits[2] end
    db[key] = v
end

DB.ORDERS = { across = true, down = true }

local function Normalize(db)
    Clamp(db, "rows")
    Clamp(db, "cols")
    if not DB.ORDERS[db.order] then db.order = BuildDefaults().order end
end

function DB.Init()
    MiliUI_Merchant_DB = MiliUI_Merchant_DB or {}
    local db = MiliUI_Merchant_DB
    MergeDefaults(db, BuildDefaults())
    db.schemaVersion = ns.DB_VERSION
    Normalize(db)
    ns.db = db
    return db
end

------------------------------------------------------------
-- 還原預設值。⚠ 就地清空再重填，不能整個換掉 MiliUI_Merchant_DB ——
-- 各模組在 Init 時就抓著 ns.db 的參考了，換表等於它們全部還指著舊的那張。
------------------------------------------------------------
function DB.ResetAll()
    local db = ns.db
    if not db then return end
    wipe(db)
    MergeDefaults(db, BuildDefaults())
    db.schemaVersion = ns.DB_VERSION
    ns.Collected.Wipe()
    ns.Grid.Apply()
    ns.AuctionHouse.Refresh()
end
