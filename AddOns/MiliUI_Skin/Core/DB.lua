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
        -- 任務／對話走暴雪內建的「任務文字對比」深色檔（CVar `questTextContrast = 4`）。
        -- 實作在 `Skins/Quest.lua` 的事件框，**不是**某一份配方的 apply ——
        -- 它跟「任務視窗有沒有上皮」是兩件事，而且關掉時要有人把 CVar 還原。
        questDarkText = true,
        -- 記住玩家原本的 `questTextContrast`。`false` ＝ 還沒記過（只記第一次）。
        questContrastSaved = false,
        -- 背景走「直接建在暴雪框上的貼圖」那條路（第六輪）。
        -- ⚠ 這是一個**安全閥**，不是玩家設定，所以不放進設定視窗：
        --   萬一某個視窗的底跑掉、或是位置不對，把它設成 false 再 /reload，
        --   所有面板／內嵌框／進度條的底就整批退回第五輪的子框 overlay。
        regionBackdrop = true,
        -- 一次性重錨版面根框（Engine.ShiftRoot）。false ＝ 整批關掉，回到暴雪原本的位置
        relayout = true,
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
            -- 拍賣場與專業：兩個視窗都貼著「需要硬體事件」的動作（出價／直購／
            -- 建立拍賣／製作／接單／套用專精變更），所以各自獨立一個開關 ——
            -- 玩家一遇到「按了沒反應」就該先關掉對應的那一項。
            auctionhouse = true,
            professions  = true,
            dressup     = true,
            itemupgrade = true,
            addonlist   = true,
            -- 冒險指南（隨需載入 Blizzard_EncounterJournal）
            encounterjournal = true,
            -- 宏偉寶庫（隨需載入 Blizzard_WeeklyRewards）。選取／領取獎勵在
            -- 受保護、吃硬體事件的路徑上 ⇒ 跟下面那兩個特許視窗同一條，
            -- 各自獨立一個開關，出事先關這個。
            weeklyrewards = true,
            -- 第五輪的兩個特許視窗（只做純視覺、零 hook 進點擊路徑）。
            -- 預設開，但它們是整包唯一「按鈕通往受保護動作」的兩個視窗 ——
            -- 玩家一遇到「按了沒反應」就該先關掉這兩項，所以各自獨立一個開關。
            popup       = true,
            gamemenu    = true,
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
