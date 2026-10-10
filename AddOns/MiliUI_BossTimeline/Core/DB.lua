------------------------------------------------------------
-- 設定資料：預設值 ＋ nil-merge
--
-- ⚠ MergeDefaults 只補 nil：發佈後要改任何預設值，都得配一條遷移（版本閘＋值閘）。
--   發佈前可以直接改。遷移寫在 DB.Init 裡，一條一個版本閘。
--
-- 版面（長度、時間範圍、圖示大小、文字放哪邊）直式橫式**各存一份**：同一個玩家常常
-- 直式擺在螢幕側邊、橫式擺在角色腳下，兩邊合適的尺寸差很多，共用一組數字等於每次切換
-- 都要重調。樣式（字型、描邊、顏色、邊框）兩邊共用 —— 那是「長相」，跟擺法無關。
------------------------------------------------------------
local _, ns = ...

ns.DB = {}
local DB = ns.DB

local function Color(r, g, b, a)
    return { r = r, g = g, b = b, a = a or 1 }
end

local function BuildDefaults()
    return {
        schemaVersion = ns.DB_VERSION,
        optionsWindow = { x = 0, y = 0 },
        -- 設定視窗開著時，畫面上的時間軸也用假資料跑（看得到實際位置與大小、可以直接拖）
        previewOnScreen = true,
        seenIntro = false,           -- 第一次開設定視窗的導覽看過了沒
        showAdvanced = false,        -- 一般分頁的進階設定展開了沒

        display = {
            enabled      = true,     -- 用本插件的畫法
            hideBlizzard = true,     -- 本插件的畫法開著時把暴雪那一條藏起來（只藏畫面，資料與音效照舊）
            orientation  = "vertical",
            x = 320, y = 60,         -- 相對 UIParent CENTER 的偏移
            scale = 1,
            -- 什麼時候顯示：always＝有東西就畫；instance＝只在副本裡（野外首領、世界任務不畫）
            visibility = "always",
            oocAlpha   = 1,          -- 戰鬥外的透明度（戰鬥中一律 1）
            -- 誰放上去的才畫：暴雪的首領技能／自己的自訂時間軸／其他插件
            sources = { blizzard = true, mine = true, other = true },

            -- 版面：直式／橫式／計時條各一份（見檔頭）
            --   length    軸長（px）
            --   window    軸的另一端代表幾秒後；更遠的事件先不畫，進範圍才滑進來
            --   flip      false＝「現在」在下面（直式）／左邊（橫式），事件往那邊走
            --   textSide  "after"＝名稱在圖示右邊（直式）／下面（橫式）；"before" 反過來
            vertical = {
                length = 320, window = 30, iconSize = 30, spacing = 2,
                flip = false, textSide = "after", showName = true,
            },
            horizontal = {
                length = 420, window = 30, iconSize = 30, spacing = 2,
                flip = false, textSide = "after", showName = false,
            },

            -- 計時條：長度＝條寬、圖示大小＝條高、flip＝由下往上排（最快到的在最下面）、
            -- textSide 不用（名稱在條裡面）
            bars = {
                length = 220, window = 30, iconSize = 22, spacing = 2,
                flip = false, textSide = "after", showName = true,
            },
            bar = {
                texture = "default",
                color   = Color(0.25, 0.55, 0.9, 1),
                bgColor = Color(0, 0, 0, 0.5),
            },

            icon = {
                border        = true,               -- 方框：1px 硬邊
                borderColor   = Color(0, 0, 0, 1),
                useEventColor = false,              -- 邊框改用暴雪給這個技能的顏色（DBM 之類設過的也算）
                zoom          = true,               -- 裁掉圖示原本的圓角外框
                indicators    = true,               -- 坦克／治療／致命之類的小圖示
            },
            name = {
                font = "default", size = 12, outline = "OUTLINE", shadow = false,
                color = Color(1, 1, 1, 1),
                showOwner = true,                   -- 非暴雪的條在名稱前標出是哪個插件加的
            },
            countdown = {
                show = true,
                font = "default", size = 13, outline = "OUTLINE",
                color = Color(1, 1, 1, 1),
                decimals = true,                    -- 剩 3 秒以內顯示到小數一位
            },
            highlight = {
                time  = 5,                          -- 剩幾秒內算「快到了」
                color = Color(1, 0.25, 0.25, 1),    -- 快到時的邊框色
                countdownColor = Color(1, 0.82, 0, 1),
            },
            track = {
                show = true, thickness = 2, color = Color(1, 1, 1, 0.25),
                ticks = true,                       -- 每 5 秒一格刻度，10 的倍數標數字
                background = false, bgColor = Color(0, 0, 0, 0.35),
            },
        },

        -- 自訂時間軸：[encounterID] = 首領（結構見 Plans/Plans.lua 檔頭）
        --   name       首領名稱（顯示用）
        --   journal    冒險指南首領 ID（頭像用，選填）
        --   display    模型 displayInfo（選填，找到一次就存）
        --   instance   冒險指南副本 ID（側欄分組用，選填）
        --   profiles = { [profileID] = { id, name, difficulties, active, entries, mrtVariant, source, author, createdAt, updatedAt } }
        -- entries 每一條：{ t, lead, spell, icon, text, sound, soundWhen, tts, roles, class, anchor, enabled }
        --   t     開戰後第幾秒「發生」（不是出現在時間軸的時間）
        --   lead  提前幾秒放上時間軸（＝這一條在時間軸上倒數多久）
        --   icon  fileID（數字）；spell 有填就用法術圖示、text 空白就用法術名稱
        -- ⚠ v1 是 plans[encounterID]（一隻首領一份），DB.Init 遷移成這個結構
        bosses = {},

        -- 上一次打這隻首領時，時間軸上出現過什麼（給編輯器當唯讀參考）
        -- [encounterID] = { name, difficulty, events = { { t, d, src, owner, text } } }
        --   暴雪的事件名稱與圖示在戰鬥中是秘密值，存不下來 —— 只記得「第幾秒有一個暴雪事件」
        recorded = {},

        -- 首領技能各自的設定（Plans/Abilities.lua）：
        -- [encounterEventID] = { color, highlight, soundHighlight, soundCast, hide, spell }
        abilities = {},

        -- 戰鬥中認首領技能（Timeline/Identify.lua）：DBM 的回呼、MRT 對時間
        identify = { dbm = true, mrt = true },
        -- 首領技能分頁手動加過的首領：[encounterID] = 名稱
        abilityBosses = {},

        -- 自訂時間軸分頁：要不要列出參考列（MRT 的整場時間軸、上一場的紀錄）、側欄展開沒、上次看到哪
        --   instance  側欄目前的副本（冒險指南副本 ID，或 "other"＝其他首領）
        --   boss／difficulty／profile  上次看的首領戰 ID／難度分頁／設定檔 ID（都可能是 nil）
        planView = { mrt = true, recorded = true, mode = "timeline", sidebar = true },

        -- 最近一場首領戰（手動輸入首領戰 ID 時帶入用）
        lastEncounter = nil,
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

function DB.Init()
    if type(MiliUI_BossTimeline_DB) ~= "table" then
        MiliUI_BossTimeline_DB = {}
    end
    local db = MiliUI_BossTimeline_DB
    MergeDefaults(db, BuildDefaults())
    -- 遷移要在 MergeDefaults 之後：新存檔的 schemaVersion 由預設值補成目前版本，不會誤跑；
    -- 舊存檔的 schemaVersion 是舊值（MergeDefaults 只補 nil）
    if (db.schemaVersion or 1) < 2 then DB.MigrateV2(db) end
    db.schemaVersion = ns.DB_VERSION
    ns.db = db
    return db
end

------------------------------------------------------------
-- v1 → v2：plans[encounterID]（一隻首領一份時間軸，難度是它的欄位）→ bosses[encounterID].profiles
--
-- 每隻舊首領變成一份「我的設定」：生效狀態照舊（enabled）、難度照舊（0＝全部 → nil）。
-- 舊表搬到 db.plansV1Backup 留一版當保險（下個版本可刪），db.plans 清掉。
-- 冪等：已經有 plansV1Backup（遷移過）或沒有 plans 就什麼都不做；同一隻首領已經有
-- 「從 v1 搬來」的設定檔也跳過，不會重複。
------------------------------------------------------------
function DB.MigrateV2(db)
    local old = db.plans
    if type(old) ~= "table" then
        db.plans = nil
        return
    end
    db.bosses = type(db.bosses) == "table" and db.bosses or {}
    local now = time()
    -- profileID 要全域唯一：同一秒建好幾份，只靠亂數可能撞
    local used = {}
    for _, boss in pairs(db.bosses) do
        for pid in pairs(type(boss) == "table" and boss.profiles or {}) do used[pid] = true end
    end
    for encID, plan in pairs(old) do
        if type(encID) == "number" and type(plan) == "table" then
            local boss = db.bosses[encID]
            if not boss then
                boss = { name = plan.name, journal = plan.journal, display = plan.display, profiles = {} }
                db.bosses[encID] = boss
            end
            boss.profiles = boss.profiles or {}
            local done = false
            for _, p in pairs(boss.profiles) do
                if p.migratedV1 then done = true end
            end
            if not done then
                local id
                repeat
                    id = "p" .. now .. "_" .. math.random(1000, 9999)
                until not used[id]
                used[id] = true
                local diff = tonumber(plan.difficulty) or 0
                boss.profiles[id] = {
                    id           = id,
                    name         = ns.L["My plan"],
                    difficulties = diff ~= 0 and { [diff] = true } or nil,
                    active       = plan.enabled ~= false,
                    entries      = type(plan.entries) == "table" and CopyTable(plan.entries) or {},
                    mrtVariant   = plan.mrtVariant,
                    source       = "local",
                    createdAt    = now,
                    updatedAt    = now,
                    migratedV1   = true,
                }
            end
        end
    end
    -- 保險：下個版本可刪（連同這一行）。條目是複本，之後改設定檔不會動到備份
    db.plansV1Backup = db.plansV1Backup or old
    db.plans = nil
end

-- 目前方向的版面那一份
function DB.Layout()
    local d = ns.db.display
    return d[d.orientation] or d.vertical
end

-- 只還原外觀，位置、自訂時間軸、紀錄都留著
function DB.ResetStyle()
    if not ns.db then return end
    local keep = ns.db.display
    local fresh = CopyTable(BuildDefaults().display)
    fresh.x, fresh.y = keep.x, keep.y
    fresh.orientation = keep.orientation
    ns.db.display = fresh
end

function DB.ResetAll()
    MiliUI_BossTimeline_DB = {}
    ReloadUI()
end
