------------------------------------------------------------
-- 設定資料：預設值、nil-merge
--
-- 這包的設定只有兩層：總開關 ＋ 每個視窗一個開關。
--
-- ⚠ **設定變更一律需要 /reload 才生效，沒有「還原」路徑。** 這是刻意的：
--   要還原就得記住每個暴雪區域原本的 alpha／顏色／材質，而那份紀錄一旦跟暴雪
--   改版對不上，還原出來的會是「既不是原樣也不是皮」的第三種狀態。少一條還原
--   路徑，就少一整類只在特定順序下才重現的 bug。
--
-- ⚠ MergeDefaults 只補 nil：發佈後要改任何預設值，都得配一條遷移（版本閘＋值閘）。
--   PoC 階段還沒有發佈過，所以這裡還沒有遷移段。
------------------------------------------------------------
local _, ns = ...

ns.DB = {}
local DB = ns.DB

ns.DB_VERSION = 1

local function BuildDefaults()
    return {
        schemaVersion = ns.DB_VERSION,
        optionsWindow = { x = 0, y = 0 },
        -- 總開關。關掉之後 /reload 就一份配方都不套。
        enabled = true,
        -- 每個視窗一個開關。key 與 Engine.Register 的 key 一致。
        windows = {
            gossip      = true,
            character   = true,
            achievement = true,
            quest       = true,
            mail        = true,
            friends     = true,
            -- 收藏視窗有四份配方（外框＋坐騎／玩具箱＋傳家寶／寵物／外觀），
            -- 共用這一個 key —— 玩家看到的是一個視窗
            collections = true,
            -- 地城與團隊：外框／地城搜尋／團隊搜尋／預組隊伍／玩家對玩家／傳奇鑰石
            -- 全部共用這一個 key（後三塊住在隨需載入的暴雪插件裡，走 Register 的 parts）
            pve         = true,
            merchant    = true,
            dressup     = true,
            itemupgrade = true,
            addonlist   = true,
        },
    }
end
DB.BuildDefaults = BuildDefaults

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

------------------------------------------------------------
-- 啟動
--
-- SavedVariables 的名字登記在 .claude/scripts/check_lua.py 的 ALLOWED_GLOBAL_WRITES。
------------------------------------------------------------
function DB.Init()
    if type(MiliUI_Skin_DB) ~= "table" then
        MiliUI_Skin_DB = {}
    end
    local db = MiliUI_Skin_DB

    MergeDefaults(db, BuildDefaults())
    db.schemaVersion = ns.DB_VERSION
    ns.db = db
    return db
end

------------------------------------------------------------
-- 這個視窗現在該不該套？（總開關 ＋ 個別開關）
-- 沒有 ns.db 表示還沒到 PLAYER_LOGIN，一律當成「還不能套」。
------------------------------------------------------------
function DB.IsWindowEnabled(key)
    local db = ns.db
    if not db or not db.enabled then return false end
    return db.windows[key] ~= false
end
