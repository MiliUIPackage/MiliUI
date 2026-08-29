------------------------------------------------------------
-- 設定資料
--
-- 刻意**只有一層、帳號共用**，不做設定檔（profile）。小地圖不是那種會想
-- 「輸出一套、治療一套」的東西；每個分身的小地圖長得不一樣只會讓人困惑。
--
-- ⚠ MergeDefaults 只補 nil。發佈之後要改任何預設值，都得配一條遷移
--   （版本閘＋值閘），不能直接改這裡的字面值 —— 已經玩過的人存檔裡有舊值，
--   改預設對他們完全無效。發佈前可以直接改。
------------------------------------------------------------
local _, ns = ...

ns.DB = {}
local DB = ns.DB

local function Color(r, g, b, a)
    return { r = r, g = g, b = b, a = a or 1 }
end

------------------------------------------------------------
-- 預設值
------------------------------------------------------------
local DEFAULTS = {
    ------------------------------------------------------------
    -- 地圖本體
    ------------------------------------------------------------
    enabled   = true,
    shape     = "square",       -- square | circle
    -- 暴雪原本的小地圖大約是 198。第一版給 172 太保守，實際擺上去比原本還小
    -- —— 「美化」不該讓東西變得更難讀。200 起跳，之後拉角落自己調。
    size      = 200,
    scale     = 1,
    -- 位置存 TOPRIGHT 相對 UIParent TOPRIGHT 的位移（x 為負、y 為負）。
    -- 小地圖是**釘在右上角**的東西，錨右上角才會在改變解析度或改尺寸時
    -- 留在原地；錨 CENTER 的話換螢幕就會跑掉。
    x = -18, y = -18,
    locked    = true,

    ------------------------------------------------------------
    -- 外觀（HUD 皮：黑透明底 ＋ 1px 職業色邊）
    ------------------------------------------------------------
    bgAlpha           = 0.80,
    borderClassColor  = true,
    borderAlpha       = 1,
    borderColor       = Color(0, 0, 0, 1),   -- borderClassColor = false 時才用

    font        = "default",
    fontOutline = "OUTLINE",                 -- NONE | OUTLINE | THICKOUTLINE
    fontSize    = 11,

    ------------------------------------------------------------
    -- 地圖上的元素
    --
    -- 三種顯示模式一律用同一組 token：always | mouseover | never。
    -- 用同一組字串是刻意的 —— 設定頁的下拉可以共用一份 items，
    -- 而且玩家看到的選項到處都一樣。
    ------------------------------------------------------------
    zoneText    = "always",      -- 區域名（貼在地圖上緣）
    coords      = "mouseover",   -- 座標（貼在地圖下緣）
    clock       = "always",      -- 時間
    -- 暴雪的雜物：邊框浮雕、指北針、時鐘按鈕。預設全關 —— 這些正是「美化」
    -- 要拿掉的東西。
    hideBlizzardArt = true,
    hideZoomButtons = true,
    -- 郵件／追蹤／副本難度這些是**功能**不是裝飾，預設留著，只是重新排位置。
    hideTracking    = false,
    hideMail        = false,
    hideCalendar    = false,
    -- 暴雪的「插件」隔間鈕。**預設關掉** —— 它在地圖旁邊是一塊寫著「插件」的
    -- 文字招牌，跟這套皮完全不同語言，而且它做的事（列出插件入口）跟我們的
    -- 按鈕收納重疊。要用的人自己開。
    showAddonCompartment = false,
    -- 滾輪縮放。方形地圖的四個角落不在暴雪的圓形滑鼠判定區內，
    -- 所以要靠自己的覆蓋層接（見 Map/Skin.lua）。
    scrollZoom      = true,

    ------------------------------------------------------------
    -- 插件按鈕收納（取代 MBB）
    ------------------------------------------------------------
    buttonBag  = true,
    btnSize    = 24,
    btnGap     = 3,
    btnColumns = 5,
    -- 常駐排貼哪一邊。**預設下方**：收納袋按鈕搬進資訊列之後，整個元件由上而下
    -- 就是「地圖 → 資訊列 → 常駐排」一路往下疊，釘出來的按鈕接在資訊列底下才
    -- 是同一條軸線上的下一段。選 top 會讓它跑到地圖**上面**，跟其他東西斷開。
    -- （bottom 會自動避開資訊列，接在它下緣，見 Map/Buttons.lua 的 Layout。）
    pinSide    = "bottom",       -- top | bottom | left | right
    -- 釘在地圖上的按鈕。**鍵是 frame 的名字**，不是索引 ——
    -- 索引會隨「今天載了哪些插件」變動，存索引等於每次登入釘到不同的按鈕。
    pinned     = {},

    ------------------------------------------------------------
    -- 資訊列（地圖下方：左公會、右好友）
    ------------------------------------------------------------
    infoBar          = true,
    infoBarHeight    = 18,
    infoBarGap       = 2,        -- 與地圖之間的縫
    infoBarAttached  = true,     -- 貼著地圖走；關掉就自己記位置
    infoBarX = -18, infoBarY = -210,
    infoBarFontSize  = 11,
    -- 三格各放什麼：guild | friends | bag | none
    --
    -- 預設把收納袋擺中間 —— 它是唯一的「固定寬正方形」，夾在兩塊等寬的文字
    -- 中間才對稱。選 none 的格子完全不佔位置，剩下的自動平分。
    infoSlot1 = "guild",
    infoSlot2 = "bag",
    infoSlot3 = "friends",
    -- 數字用職業色（＝強調色），標籤用白字。關掉就整條白字。
    infoAccentNumbers = true,
    -- 提示裡最多列幾個人。大公會不設上限會長出一條蓋滿螢幕的提示。
    tipMaxRows       = 30,
    -- 提示裡顯示所在區域
    tipShowZone      = true,
}

DB.DEFAULTS = DEFAULTS

------------------------------------------------------------
-- nil-merge
------------------------------------------------------------
local function MergeDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            MergeDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function DB.Get()
    return MiliUI_Minimap_DB
end

function DB.Init()
    MiliUI_Minimap_DB = MiliUI_Minimap_DB or {}
    local db = MiliUI_Minimap_DB

    db.dbVersion = db.dbVersion or ns.DB_VERSION
    MergeDefaults(db, DEFAULTS)

    -- 位置的健全性檢查：存檔可能是在別的解析度存的，或被手動編輯過。
    -- 飄到畫面外的視窗玩家救不回來（設定頁裡看不到它），所以夾一次。
    local halfW = (GetScreenWidth() or 1920)
    local halfH = (GetScreenHeight() or 1080)
    if type(db.x) ~= "number" or math.abs(db.x) > halfW then db.x = DEFAULTS.x end
    if type(db.y) ~= "number" or math.abs(db.y) > halfH then db.y = DEFAULTS.y end
    if type(db.infoBarX) ~= "number" or math.abs(db.infoBarX) > halfW then db.infoBarX = DEFAULTS.infoBarX end
    if type(db.infoBarY) ~= "number" or math.abs(db.infoBarY) > halfH then db.infoBarY = DEFAULTS.infoBarY end

    return db
end

function DB.ResetAll()
    local keep = MiliUI_Minimap_DB and MiliUI_Minimap_DB.optionsWindow
    MiliUI_Minimap_DB = { optionsWindow = keep }
    DB.Init()
    ns.Fire("ConfigChanged")
end

-- 設定視窗自己的位置：跟其他設定分開存，重置設定不該把視窗丟回畫面中央
function DB.OptionsWindow()
    local db = DB.Get()
    db.optionsWindow = db.optionsWindow or { x = 0, y = 0 }
    return db.optionsWindow
end
