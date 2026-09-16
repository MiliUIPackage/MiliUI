------------------------------------------------------------
-- 設定資料：預設值 ＋ nil-merge
--
-- ⚠ MergeDefaults 只補 nil：發佈後要改任何預設值，都得配一條遷移（版本閘＋值閘）。
--   發佈前可以直接改。這支目前是 v1，還沒有遷移。
------------------------------------------------------------
local _, ns = ...

ns.DB = {}
local DB = ns.DB

local function Color(r, g, b, a)
    return { r = r, g = g, b = b, a = a or 1 }
end

-- 預設填充色＝聖騎士職業色（RAID_CLASS_COLORS.PALADIN）。寫死數值而不是查表：
-- 這是存進 SavedVariables 的值，之後玩家可以自己改，不該跟著遊戲的色表浮動。
local DEFAULT_FILL = Color(0.9568, 0.5490, 0.7294, 1)
local DEFAULT_BACK = Color(0, 0, 0, 0.6)
DB.DEFAULT_FILL = DEFAULT_FILL
DB.DEFAULT_BACK = DEFAULT_BACK

local function BuildDefaults()
    return {
        schemaVersion = ns.DB_VERSION,
        optionsWindow = { x = 0, y = 0 },
        enabled = true,
        bar = {
            -- 尺寸單位是「名條 display 的座標系」：我們把條掛在 Platynator 的
            -- display 底下，所以它會跟著那個名條的縮放一起縮，不必自己換算。
            height    = 4,
            widthMode = "match",    -- "match" = 兩端錨在血條上（跟血條同寬）；"custom" = 用 width
            width     = 120,
            gap       = 2,          -- 血條底邊 → 我們的條頂邊
            offsetX   = 0,
            -- "elapsed"   已揮的時間左→右長出（預設，看的是「下一刀快到了」）
            -- "remaining" 傳統倒數（剩餘時間由右往左縮短）
            fillMode  = "elapsed",
            texture   = "default",  -- LSM statusbar 名稱；"default" = Core/Media.lua 的自動挑選
            colorFill = CopyTable(DEFAULT_FILL),
            colorBack = CopyTable(DEFAULT_BACK),
            border    = true,       -- 1px 黑邊（套組 HUD 皮：黑底、直角）
            castMode  = "below",    -- 施法條顯示時："below" 移到施法條下方 / "hide" 隱藏 / "stay" 不動
            showStacks = false,     -- 鏡射層數文字（實驗性，見 Modules/Bar.lua）
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

function DB.Init()
    if type(MiliUI_CrusadingStrikes_DB) ~= "table" then
        MiliUI_CrusadingStrikes_DB = {}
    end
    local db = MiliUI_CrusadingStrikes_DB
    MergeDefaults(db, BuildDefaults())
    db.schemaVersion = ns.DB_VERSION
    ns.db = db
    return db
end

-- 只還原「條」那一組，視窗位置留著（玩家把設定視窗擺在哪跟外觀無關）
function DB.ResetBar()
    if not ns.db then return end
    ns.db.bar = CopyTable(BuildDefaults().bar)
    ns.db.enabled = true
end

function DB.ResetAll()
    MiliUI_CrusadingStrikes_DB = {}
    ReloadUI()
end
