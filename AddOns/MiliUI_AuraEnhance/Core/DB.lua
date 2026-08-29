------------------------------------------------------------
-- 設定資料：預設值、nil-merge、一次性遷移
--
-- ⚠ MergeDefaults 只補 nil：發佈後要改任何預設值，都得配一條遷移（版本閘＋值閘）。
------------------------------------------------------------
local _, ns = ...

ns.DB = {}
local DB = ns.DB

-- 堆疊層數可以錨在圖示的哪八個位置（設定頁的下拉與這裡共用一份）
DB.ANCHORS = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true,
    LEFT = true, RIGHT = true,
    BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

-- 滑桿範圍：設定頁與 DB 正規化共用，改一處兩邊一起動
DB.LIMITS = {
    fontSize = { 7, 16 },
    yOffset  = { -10, 20 },
    countX   = { -20, 20 },
    countY   = { -20, 20 },
}

local function BuildDefaults()
    return {
        schemaVersion = ns.DB_VERSION,
        optionsWindow = { x = 0, y = 0 },
        duration = {
            enabled  = true,
            -- font：LibSharedMedia 的字型名稱；"" = 沿用暴雪原本的字型
            -- （1.x 版存的是完整路徑，Media.OptionalFont 兩種都吃）
            font     = "",
            fontSize = 12,
            outline  = true,
            yOffset  = 6,
        },
        count = {
            enabled = true,
            font    = "",
            anchor  = "TOP",
            x       = 0,
            y       = 0,
        },
        -- 圖示外觀樣式。預設開：套組本來就內建一支專做這件事的插件，
        -- 這裡接手它的位置，預設關掉的話玩家更新完會覺得功能不見了。
        skin = {
            enabled = true,
            -- 邊框厚度（框架單位）
            inset   = 1,
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
-- 一次性遷移（只做一次）
--
-- 這組功能有兩份前身，兩份的設定都是攤平的一張表：
--   1. 獨立發佈的 1.x 版（MiliUI_AuraEnhanceDB）—— 同一個資料夾名，等於就地升級
--   2. MiliUI 套組的 Enhance/BuffDurationStyle.lua（MiliUI_DB.buffDuration）
-- 先看 1 再看 2：玩家兩邊都有值的話，獨立版才是他最近在調的那份。
--
-- ⚠ 只搬一次。搬完（或確認沒東西可搬）就蓋上 migration 印記，之後**永遠不再看**
--   那兩份——否則玩家在這裡改的設定會被舊值一再蓋回去。
-- ⚠ 全程唯讀，不動 MiliUI_DB 一個字（玩家可能還在用套組的其他功能）。
------------------------------------------------------------
-- { 新表, 新鍵, 舊鍵 }；舊值是 nil 就跳過（沒設定過的不覆蓋預設值）
local FLAT_MAP = {
    { "duration", "enabled",  "enabled" },
    { "duration", "font",     "fontFace" },
    { "duration", "fontSize", "fontSize" },
    { "duration", "outline",  "outline" },
    { "duration", "yOffset",  "yOffset" },
    { "count",    "enabled",  "countEnabled" },
    { "count",    "font",     "countFontFace" },
    { "count",    "anchor",   "countAnchor" },
    { "count",    "x",        "countXOffset" },
    { "count",    "y",        "countYOffset" },
}

local function MoveFlat(db, old)
    if type(old) ~= "table" then return 0 end
    local moved = 0
    for _, m in ipairs(FLAT_MAP) do
        local v = old[m[3]]
        if v ~= nil then
            db[m[1]][m[2]] = v
            moved = moved + 1
        end
    end
    return moved
end

-- 舊版的字型欄位存的是**完整路徑**，新版存 LibSharedMedia 的名稱。
-- 兩種寫法都跑得動（Media.OptionalFont 都吃），差別在設定頁的下拉：
-- 路徑對不到清單裡的任何一筆，那顆下拉就會顯示一長串路徑。能對回名稱就轉。
local function PathToToken(value)
    if type(value) ~= "string" or value == "" or not value:find("[\\/]") then
        return value
    end
    local lsm = ns.Media.LSM()
    if not lsm then return value end
    local ok, hash = pcall(lsm.HashTable, lsm, "font")
    if not ok or type(hash) ~= "table" then return value end
    for name, path in pairs(hash) do
        if path == value then return name end
    end
    return value
end

-- 回傳 來源代號, 搬了幾個欄位
function DB.RunMigration(db)
    db = db or MiliUI_AuraEnhance_DB

    local from
    local moved = MoveFlat(db, _G.MiliUI_AuraEnhanceDB)
    if moved > 0 then
        from = "standalone"
    else
        moved = MoveFlat(db, _G.MiliUI_DB and _G.MiliUI_DB.buffDuration)
        from = moved > 0 and "package" or "none"
    end

    if moved > 0 then
        db.duration.font = PathToToken(db.duration.font)
        db.count.font = PathToToken(db.count.font)
    end
    return from, moved
end

------------------------------------------------------------
-- 正規化：SavedVariables 是玩家（或舊版本）寫進來的，不保證還在範圍內
------------------------------------------------------------
local function Clamp(v, range, fallback)
    if type(v) ~= "number" then return fallback end
    return math.max(range[1], math.min(range[2], math.floor(v + 0.5)))
end

local function Normalize(db)
    local d, c, def = db.duration, db.count, BuildDefaults()
    d.fontSize = Clamp(d.fontSize, DB.LIMITS.fontSize, def.duration.fontSize)
    d.yOffset  = Clamp(d.yOffset,  DB.LIMITS.yOffset,  def.duration.yOffset)
    c.x = Clamp(c.x, DB.LIMITS.countX, def.count.x)
    c.y = Clamp(c.y, DB.LIMITS.countY, def.count.y)
    -- 錨點寫錯的話 SetPoint 會直接拋錯，退回預設比讓它炸掉好
    if not DB.ANCHORS[c.anchor] then c.anchor = def.count.anchor end
end

------------------------------------------------------------
-- 啟動
------------------------------------------------------------
function DB.Init()
    if type(MiliUI_AuraEnhance_DB) ~= "table" then
        MiliUI_AuraEnhance_DB = {}
    end
    local db = MiliUI_AuraEnhance_DB

    -- 順序很重要：先補齊預設值（遷移要寫進 db.duration / db.count 這兩張子表），
    -- 再看要不要遷移。
    MergeDefaults(db, BuildDefaults())

    if db.migration == nil then
        local from, moved = DB.RunMigration(db)
        db.migration = from
        if from ~= "none" then
            -- 只講一次（印記已寫入，下次登入不會再進來）
            local msg = (from == "package")
                and ns.L["Imported your aura settings from the MiliUI package."]
                or ns.L["Imported your settings from the previous version."]
            C_Timer.After(5, function()
                ns.Print(msg .. " (" .. moved .. ")")
            end)
        end
    end

    Normalize(db)
    db.schemaVersion = ns.DB_VERSION
    ns.db = db
    return db
end

------------------------------------------------------------
-- 恢復預設
--
-- 就地覆寫兩張子表，不整包換掉：模組把 db.duration / db.count 抓成 upvalue
-- （hook 是熱路徑），換成新表的話它們會繼續指著舊的那份。
-- 保留 optionsWindow 與 migration 印記——印記清掉的話下次登入又會從舊 SV
-- 搬一次回來，玩家按的「還原預設值」等於沒按。
------------------------------------------------------------
function DB.ResetAll()
    local db = ns.db
    if not db then return end
    local def = BuildDefaults()
    for _, section in ipairs({ "duration", "count", "skin" }) do
        wipe(db[section])
        for k, v in pairs(def[section]) do
            db[section][k] = v
        end
    end
    -- 樣式先跑、文字後跑：樣式會把層數搬進自己的包裝框，文字樣式接著才把它搬到
    -- 覆蓋層，順序反過來位置設定會慢一拍
    ns.AuraStyle.Apply()
    ns.Fire("SettingsChanged")
end
