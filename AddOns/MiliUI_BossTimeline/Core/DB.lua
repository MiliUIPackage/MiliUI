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

        display = {
            enabled      = true,     -- 用本插件的畫法
            hideBlizzard = true,     -- 本插件的畫法開著時把暴雪那一條藏起來（只藏畫面，資料與音效照舊）
            orientation  = "vertical",
            x = 320, y = 60,         -- 相對 UIParent CENTER 的偏移
            scale = 1,
            -- 誰放上去的才畫：暴雪的首領技能／自己的自訂時間軸／其他插件
            sources = { blizzard = true, mine = true, other = true },

            -- 版面：直式橫式各一份（見檔頭）
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

        -- 自訂時間軸：[encounterID] = { name, enabled, difficulty, mrtVariant, entries = { { t, text, icon, spell, lead, enabled }, ... } }
        --   t     開戰後第幾秒「發生」（不是出現在時間軸的時間）
        --   lead  提前幾秒放上時間軸（＝這一條在時間軸上倒數多久）
        --   icon  fileID（數字）；spell 有填就用法術圖示、text 空白就用法術名稱
        plans = {},

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

        -- 自訂時間軸分頁要不要列出參考列（MRT 的整場時間軸、上一場的紀錄）
        planView = { mrt = true, recorded = true, mode = "timeline" },

        -- 最近一場首領戰（編輯器「新增首領」帶入用）
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
    db.schemaVersion = ns.DB_VERSION
    ns.db = db
    return db
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
