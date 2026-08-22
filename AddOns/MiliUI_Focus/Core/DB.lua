------------------------------------------------------------
-- 設定資料：預設值、nil-merge、從 MiliUI 套組一次性遷移
--
-- ⚠ MergeDefaults 只補 nil：發佈後要改任何預設值，都得配一條遷移
--   （版本閘＋值閘）。發佈前可以直接改。
------------------------------------------------------------
local _, ns = ...

ns.DB = {}
local DB = ns.DB

local function Color(r, g, b, a)
    return { r = r, g = g, b = b, a = a or 1 }
end

-- 施法條三態顏色：抄套組 Platynator 預設值的 autoColors
--   ready  可斷法（斷法可用）  金黃
--   cd     可斷法但斷法冷卻中  橘
--   immune 不可中斷            灰
local DEFAULT_COLORS = {
    ready  = Color(1, 0.7411764860153198, 0),
    cd     = Color(0.9058824181556702, 0.4235294461250305, 0.2000000178813934),
    immune = Color(0.5294117647058824, 0.5294117647058824, 0.5294117647058824),
}
DB.DEFAULT_COLORS = DEFAULT_COLORS

------------------------------------------------------------
-- 預設標記編號：隨機挑一個
--
-- 為什麼隨機而不是固定 1 號：整隊人都裝這支的話，固定值等於所有人預設盯同一個
-- 符號，開起自動標記就全員撞號（Sync 的撞號提醒會一次跳一整排）。先錯開，
-- 大部分情況下不必手動喬。只挑一次——存進 SV 之後就是玩家自己的設定了。
-- 注意這跟 autoMark 預設關並不衝突：號碼先備好，玩家哪天打開就直接是錯開的。
--
-- 排除 7（叉叉）與 8（骷髏）：這兩個是團隊慣例的擊殺順序／風箏記號，通常由隊長
-- 指定，被自動標記搶走會直接干擾指揮。
local MARK_POOL = { 1, 2, 3, 4, 5, 6 }

function DB.RandomMarkIndex()
    return MARK_POOL[math.random(#MARK_POOL)]
end

local function BuildDefaults()
    return {
        schemaVersion = ns.DB_VERSION,
        optionsWindow = { x = 0, y = 0 },
        focus = {
            enabled = true,
            -- hotkey：自訂快捷鍵的綁定字串（"F"、"ALT-CTRL-G"、"BUTTON4"…），
            -- nil = 未設定。Shift+左鍵那組是固定的，不受這個影響。
            hotkey = nil,
            -- 自動標記預設關：這是會動到別人畫面的行為（標記是全隊看得到的），
            -- 預設就替玩家把記號蓋到怪身上太主動，讓他自己開。
            autoMark = false,
            markIndex = 0,          -- 0 = 還沒挑過；DB.Init 收尾時隨機補一個
            noOverwriteMark = true,
        },
        bar = {
            shown = false,
            announceText = ns.L["My focus interrupt target is {icon}!"],
            -- x / y = nil：第一次顯示時算出畫面中央偏下的位置（見 Modules/MarkBar.lua）
            x = nil, y = nil,
        },
        cast = {
            monitor = true,
            x = 0,
            y = 260,
            width = 220,
            height = 22,
            colorReady  = CopyTable(DEFAULT_COLORS.ready),
            colorCD     = CopyTable(DEFAULT_COLORS.cd),
            colorImmune = CopyTable(DEFAULT_COLORS.immune),
            -- 12.1 起無法依斷法狀態挑音效（見 Modules/CastBar.lua 的 HandleSound），
            -- 只剩「開始唱法就播一次」
            soundEnabled = false,
            sound = nil,
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
-- 從 MiliUI 套組遷移（只做一次）
--
-- 這組功能原本住在 MiliUI 的 Enhance/Focuser*.lua，設定攤平存在 MiliUI_DB。
-- 獨立成插件之後第一次啟動時，把那些值搬過來，玩家不用重設一遍。
--
-- ⚠ 只搬一次。搬完（或確認沒東西可搬）就在自己的 SV 蓋上 miliuiMigration 印記，
--   之後**永遠不再看 MiliUI_DB**——否則玩家在這裡改的設定，會被 MiliUI 那份
--   舊值一再蓋回去。印記在則一切以本插件的設定為準。
-- ⚠ 全程唯讀，不動 MiliUI_DB 一個字（玩家可能還在用套組的其他功能）。
------------------------------------------------------------
-- { 新表, 新鍵, 舊鍵 }；舊值是 nil 就跳過（沒設定過的不覆蓋預設值）
local FLAT_MAP = {
    { "focus", "enabled",         "focuserEnabled" },
    { "focus", "hotkey",          "focuserHotkey" },
    { "focus", "autoMark",        "focuserAutoMark" },
    { "focus", "markIndex",       "focuserMarkIndex" },
    { "focus", "noOverwriteMark", "focuserNoOverwriteMark" },
    { "bar",   "shown",           "focuserBarShown" },
    { "bar",   "announceText",    "focuserAnnounceText" },
    { "bar",   "x",               "focuserBarX" },
    { "bar",   "y",               "focuserBarY" },
}

-- MiliUI_DB.focusCast.* → db.cast.*
local CAST_MAP = {
    monitor      = "monitor",
    x            = "x",
    y            = "y",
    width        = "width",
    height       = "height",
    soundEnabled = "soundCastEnabled",
    sound        = "soundCast",
}

-- 舊的顏色是 { r, g, b } 陣列，這裡是 { r =, g =, b =, a = }
local CAST_COLOR_MAP = {
    colorReady  = "colorReady",
    colorCD     = "colorCD",
    colorImmune = "colorImmune",
}

local function MigrateFromMiliUI(db)
    local old = _G.MiliUI_DB
    if type(old) ~= "table" then return false end

    local moved = 0
    for _, entry in ipairs(FLAT_MAP) do
        local root, key, oldKey = entry[1], entry[2], entry[3]
        local v = old[oldKey]
        if v ~= nil then
            db[root][key] = v
            moved = moved + 1
        end
    end

    local oldCast = old.focusCast
    if type(oldCast) == "table" then
        for key, oldKey in pairs(CAST_MAP) do
            local v = oldCast[oldKey]
            if v ~= nil then
                db.cast[key] = v
                moved = moved + 1
            end
        end
        for key, oldKey in pairs(CAST_COLOR_MAP) do
            local c = oldCast[oldKey]
            if type(c) == "table" and tonumber(c[1]) then
                db.cast[key] = Color(c[1], c[2], c[3])
                moved = moved + 1
            end
        end
    end

    return moved > 0, moved
end

-- 手動重跑（/mfocus migrate）：玩家第一次啟動時剛好把 MiliUI 停用，
-- 自動遷移那次就會什麼都搬不到。這條路讓他事後補搬，代價是覆蓋現有設定，
-- 所以只在明確下指令時才跑。
function DB.RunMigration()
    if type(MiliUI_Focus_DB) ~= "table" then return false, 0 end
    local ok, moved = MigrateFromMiliUI(MiliUI_Focus_DB)
    MiliUI_Focus_DB.miliuiMigration = ok and "migrated" or "none"
    return ok, moved or 0
end

function DB.Init()
    if type(MiliUI_Focus_DB) ~= "table" then
        MiliUI_Focus_DB = {}
    end
    local db = MiliUI_Focus_DB

    -- 順序很重要：先補齊預設值（遷移要寫進 db.focus / db.bar / db.cast 這些子表），
    -- 再看要不要遷移。兩者都跑完才是玩家看到的設定。
    MergeDefaults(db, BuildDefaults())

    if db.miliuiMigration == nil then
        local ok, moved = MigrateFromMiliUI(db)
        db.miliuiMigration = ok and "migrated" or "none"
        if ok then
            -- 只講一次（印記已寫入，下次登入不會再進來）
            C_Timer.After(5, function()
                ns.Print(ns.L["Imported your focus settings from the MiliUI package."]
                    .. " (" .. moved .. ")")
            end)
        end
    end

    -- 標記編號一定要落在 1~8。設定頁的下拉與標記列的選單都只給 1~8，玩家選不出 0，
    -- 所以 0 只會來自「全新安裝」或「從舊套組搬來但從沒選過圖示」。留 0 的話，
    -- 玩家一打開自動標記就會遇到「開了卻什麼都沒標」（巨集少一行）。
    local f = db.focus
    if type(f.markIndex) ~= "number" or f.markIndex < 1 or f.markIndex > 8 then
        f.markIndex = DB.RandomMarkIndex()
    end

    db.schemaVersion = ns.DB_VERSION
    ns.db = db
    return db
end

function DB.ResetAll()
    -- 印記要留著：整包清掉的話，下次登入又會從 MiliUI_DB 搬一次舊設定回來，
    -- 玩家按的「還原預設值」等於沒按
    MiliUI_Focus_DB = { miliuiMigration = "reset" }
    ReloadUI()
end
