------------------------------------------------------------
-- 設定資料：預設值、nil-merge
--
-- ⚠ MergeDefaults 只補 nil：發佈後要改任何預設值，都得配一條遷移（版本閘＋值閘）。
------------------------------------------------------------
local _, ns = ...

ns.DB = {}
local DB = ns.DB

-- 滑桿範圍：設定頁與 DB 正規化共用，改一處兩邊一起動
DB.LIMITS = {
    headerSize    = { 8, 24 },
    titleSize     = { 8, 24 },
    objectiveSize = { 8, 24 },
    bgAlpha       = { 0, 1 },
    barWidth      = { 150, 400 },
}

local function BuildDefaults()
    return {
        schemaVersion = ns.DB_VERSION,
        optionsWindow = { x = 0, y = 0 },

        -- 位置。編輯模式本來就管著追蹤器的位置，但拖一次太麻煩，所以只要玩家
        -- 用搬家遮罩拖過一次，之後就由我們接管：`set` 之後每次載入／版面套用
        -- 都把它貼回這裡記的座標。右鍵遮罩＝清掉，位置交還給編輯模式。
        -- 座標是 TOPLEFT 相對 UIParent TOPLEFT 的位移（y 為負），跟
        -- MiliUI_DamageMeters 的視窗同一套 —— 追蹤器的內容往下長，
        -- 用 CENTER 位移的話內容一多整條就會自己往上飄。
        position = { set = false, x = 0, y = 0 },

        -- 玩家自己按標題列摺起來的狀態。存檔的理由：摺疊是一個明確的意圖
        -- （「我現在不想看任務」），重載之後自己彈回來等於把那個意圖丟掉。
        -- 自動條件造成的摺疊**不寫進這裡**，那是暫時狀態。
        folded = false,

        appearance = {
            -- 字型。"" = 沿用暴雪原本的字型（每個 FontString 原字型不見得相同）
            font          = "",
            outline       = true,
            headerSize    = 15,
            titleSize     = 14,
            objectiveSize = 13,

            -- 文字顏色
            titleColor     = { r = 1.00, g = 0.91, b = 0.47 },  -- 任務標題（金）
            completedColor = { r = 0.25, g = 1.00, b = 0.35 },  -- 已完成（綠）
            focusColor     = { r = 0.87, g = 0.25, b = 1.00 },  -- 追蹤中（紫）
            objectiveColor = { r = 0.72, g = 0.72, b = 0.72 },  -- 目標行（灰）

            -- 區段標題（任務／成就／專業…）。預設吃職業色，關掉才讀 headerColor
            headerUseClass = true,
            headerColor    = { r = 1.00, g = 1.00, b = 1.00 },

            -- 背景：純色直角，蓋在追蹤器後面。
            -- ⚠ 顏色與不透明度是**套組共用值**，不是這支自己挑的：0x1A ＋ 0.8 跟
            --   MiliUI_DamageMeters 的視窗底一模一樣（那邊的常數叫 DARK_BG）。
            --   要改就兩邊一起改，不然兩個視窗擺在一起會看得出色差。
            --   標題列則跟傷害統計的標題列一樣走**不透明**，見 Chrome.ApplyStyle。
            background = false,
            bgColor    = { r = 0.102, g = 0.102, b = 0.102 },
            bgAlpha    = 0.8,

            -- 1px 分隔線（標題列下緣＋每個區段標題下緣），吃強調色
            dividers = true,

            -- 剝掉暴雪的裝飾貼圖（羊皮紙、光暈、緞帶）
            stripArt = true,

            -- 用暴雪現成的 Crosshair_* atlas 在區塊右上角標任務類型
            questIcons = true,

            -- 暴雪的「所有目標」主標題列。我們自己有一條，預設把它藏起來
            hideBlizzardHeader = true,

            -- 點區段標題（任務／成就…）就收合那一段。做法是把原生 +/- 鈕的
            -- 點擊區撐到整條 header 寬，點擊仍然走暴雪自己的 OnClick
            clickHeaderToCollapse = true,
        },

        titleBar = {
            enabled   = true,
            showCount = true,
            -- 點標題列摺疊整份清單
            clickToFold = true,
        },

        -- 自動摺疊條件。全部是「暫時摺疊」，離開該情境就自己展開，
        -- 不會蓋掉玩家手動摺疊的狀態
        visibility = {
            raidBoss   = true,   -- 團本首領戰中（預設唯一開著的）
            raid       = false,  -- 整趟團本副本
            arena      = false,
            battleground = false,
            dungeon    = false,
            combat     = false,
            -- M+：WarpDeplete 已經自己把追蹤器藏起來了，兩邊搶同一個 alpha 會打架。
            -- 預設關，設定頁那條有標注誰接管
            mythicPlus = false,
        },

        automation = {
            -- 預設開。安全網是底下那三個閘：有多個獎勵可選一律留給玩家、
            -- 要花金幣／貨幣／材料的不自動交、同一個 NPC 有多條可接就不亂挑。
            -- 標題列上的兩顆開關預設也顯示，隨時看得到現在是開是關
            autoTurnIn = true,
            autoAccept = true,
            -- 按住 Shift 暫停自動化（跟 Leatrix Plus 的預設方向一致）
            shiftSkip  = true,
            -- 同一個 NPC 有多個可接任務時不要亂挑，讓玩家自己選
            preventMulti = true,
            -- 要花金幣／貨幣才能交的任務不自動交（誤交會直接扣錢）
            skipCostQuests = true,
            -- 標題列上的開關 chip
            -- 自動接任務時要先等一下的那幾條，以及共用的等待秒數。
            --
            -- ⚠ 兩件事刻意分開：**哪些任務要等**逐條記（絕大多數不用，秒接秒交），
            --   **要等多久**全部共用一個值 —— 延遲的成因是伺服器暖機／連線來回，
            --   那是玩家連線的性質、不是某條任務的性質，針對單一任務調整沒有意義。
            --   共用還讓任何一條任務學到的教訓其他任務直接受惠，收斂快得多。
            --
            -- 不是設定，是**量出來的**：客戶端沒有任何訊號可以事先判斷哪條任務要等
            -- （六種都試過，記在 Modules/AutoQuest.lua），所以接不到就記起來、下次先等，
            -- 還是不行就每次加 0.1 秒往上收斂（上限 2 秒）。
            acceptWait = 0.5,

            -- questID → true
            -- ⚠ 存在帳號層級（TOC 是 SavedVariables 不是 PerCharacter）是刻意的：
            --   週任每隻分身都要跑，一隻角色踩過一次，其他分身直接就是對的。
            --
            -- 內建已知的 questID。MergeDefaults 對 table 是遞迴、對值只補 nil，
            -- 所以玩家已經有的原封不動、沒有的才補上；玩家手動移除過的由
            -- dismissedSlow 擋著不會被併回來。
            --
            -- 週任的 ID 每週換，但會**輪替**，蒐集幾輪就湊得齊 —— 這也是這張清單
            -- 值得內建的理由。要加就照下面的格式寫一行，順手把任務名稱留在註解裡：
            -- 只有編號的話，下次要判斷「這條還在不在輪替裡」會完全無從查起。
            --
            -- 2026-08-30 蒐集（「至暗之夜」那組四選一週任，四條都會秒接失敗）：
            slowQuests = {
                [93890] = true,   -- 至暗之夜：豐足
                [93910] = true,   -- 至暗之夜：狩獵
                [93912] = true,   -- 至暗之夜：團隊副本
                [98232] = true,   -- 至暗之夜：阿塔烏特克寶庫
            },

            -- 玩家自己從清單移除過的。
            --
            -- ⚠ 沒有這張表的話，內建清單一上線就會出現「移除了、下次登入又冒出來」——
            --   因為 nil-merge 分不出「玩家沒有過」跟「玩家刪掉了」，兩種都是 nil。
            --   玩家看到的是「移除鈕壞掉」，而且只有內建清單存在時才會發生，現在測不出來。
            --
            -- ⚠ 它只擋**內建預設值**被併回來，不擋實測。真的又接失敗時 Escalate 會把
            --   這裡的紀錄清掉重新學 —— 「我不要你預設塞給我」跟「量出來就是會失敗」
            --   是兩件事，後者該贏。
            dismissedSlow = {},

            showTurnInToggle = true,
            showAcceptToggle = true,
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
-- 值域夾制：滑桿範圍改小之後，舊存檔可能帶著超出範圍的值
------------------------------------------------------------
local function Clamp(tbl, key, limits)
    local v = tonumber(tbl[key])
    if not v then
        tbl[key] = BuildDefaults().appearance[key]
        return
    end
    if v < limits[1] then tbl[key] = limits[1] end
    if v > limits[2] then tbl[key] = limits[2] end
end

local function Normalize(db)
    -- 玩家拒絕過的，不要讓 MergeDefaults 又把內建清單併回來。
    -- ⚠ 順序：一定要在 MergeDefaults **之後**跑
    local au = db.automation
    if au and au.slowQuests and au.dismissedSlow then
        for questID in pairs(au.dismissedSlow) do
            au.slowQuests[questID] = nil
        end
    end

    local a = db.appearance
    Clamp(a, "headerSize",    DB.LIMITS.headerSize)
    Clamp(a, "titleSize",     DB.LIMITS.titleSize)
    Clamp(a, "objectiveSize", DB.LIMITS.objectiveSize)
    Clamp(a, "bgAlpha",       DB.LIMITS.bgAlpha)
end

function DB.Init()
    MiliUI_QuestTracker_DB = MiliUI_QuestTracker_DB or {}
    local db = MiliUI_QuestTracker_DB
    MergeDefaults(db, BuildDefaults())
    db.schemaVersion = ns.DB_VERSION
    Normalize(db)
    ns.db = db
    return db
end

------------------------------------------------------------
-- 還原預設值。⚠ 就地清空再重填，不能整個換掉 MiliUI_QuestTracker_DB ——
-- 各模組在 Init 時就抓著 ns.db 的參考了，換表等於它們全部還指著舊的那張。
------------------------------------------------------------
function DB.ResetAll()
    local db = ns.db
    if not db then return end
    wipe(db)
    MergeDefaults(db, BuildDefaults())
    db.schemaVersion = ns.DB_VERSION
    ns.Fire("SettingsChanged")
    ns.Fire("Apply")
end
