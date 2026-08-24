------------------------------------------------------------
-- 設定資料：預設值、nil-merge、每視窗設定
--
-- 分兩層：
--   db.style     外觀與行為，**所有視窗共用**（跟 EUI 一樣——每視窗一套外觀
--                只會讓設定頁變成五份一模一樣的表單，沒人會分開調）
--   db.windows[] 每視窗自己的：統計類型、分段、位置、尺寸、鎖定、顯示條件
--
-- ⚠ MergeDefaults 只補 nil：發佈後要改任何預設值，都得配一條遷移（版本閘＋值閘）。
--   發佈前可以直接改。
------------------------------------------------------------
local _, ns = ...

ns.DB = {}
local DB = ns.DB

DB.MAX_WINDOWS = 5

local function Color(r, g, b, a)
    return { r = r, g = g, b = b, a = a or 1 }
end

------------------------------------------------------------
-- 每視窗預設值
--
-- 位置存 TOPLEFT 相對 UIParent TOPLEFT 的位移（y 為負）。
-- 不用編輯模式技能推薦的 CENTER 位移，因為這是**可縮放**的視窗：
-- 錨 CENTER 的話從右下角拉大會讓整個框往左上漂，錨 TOPLEFT 才是「標題列不動、
-- 往右下長」的直覺行為。x/y = nil 代表還沒擺過，第一次顯示時算螢幕中央偏上。
------------------------------------------------------------
function DB.NewWindow(idx)
    return {
        curDMType  = Enum.DamageMeterType and Enum.DamageMeterType.DamageDone or 0,
        curSession = Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Current or 0,
        x = nil, y = nil,
        width = 300, height = 200,
        locked = false,
        hideTimer = false,
        snapDisabled = false,
        -- 分段連動：勾了的視窗切分段時會一起切（看同一場戰鬥的不同統計類型時很有用）
        syncSegments = false,
        -- 戰鬥開始時，正在看歷史分段的視窗自動跳回「本場」。
        -- 預設關：翻舊分段通常是刻意在比對，開打就被搶走視線很惱人。
        autoCurrentOnCombat = false,
        -- 顯示條件
        visibility = "always",   -- always | combat | instance | group
        hideInDungeon = false,
        hideInRaid = false,
        hideInPvP = false,
        hideOutOfInstance = false,
    }
end

local function BuildDefaults()
    return {
        schemaVersion = ns.DB_VERSION,
        optionsWindow = { x = 0, y = 0 },
        -- 我們是不是關掉過玩家的內建傷害統計。true = 欠著一個還原，
        -- 玩家把「自動關閉內建統計」關掉時要把 CVar 還回去（見 Meter/Builtin.lua）
        builtinRestore = false,
        -- 上一次記錄到的副本（instanceID:難度）。用來判斷「這是不是新的一趟」。
        -- 帳號層：這是這台機器當下在哪裡，不是玩家調的設定，不能跟著匯出字串跑。
        lastInstanceKey = nil,

        style = {
            ------------------------------------------------------------
            -- 更新
            ------------------------------------------------------------
            -- 秒。ticker 只在戰鬥期間存在，所以這個值不影響閒置成本，
            -- 只影響戰鬥中的 CPU。0.5 秒在 40 列的規模下仍然便宜
            -- （每次 tick 只有可視列的 SetValue/SetText），但數字跳動明顯順很多。
            refreshRate = 0.5,

            ------------------------------------------------------------
            -- 長條
            ------------------------------------------------------------
            barHeight  = 18,
            barSpacing = 2,
            -- fill = 實心填滿；line-bottom / line-top = 只在列的上/下緣畫一條
            -- 會跟著數值長短的細線（圖示與文字照舊，長條本身退成一條線）
            barStyle = "line-bottom",
            barLineHeight = 2,
            -- 套組共用的預設材質，跟 MiliUI_UnitFrames 的血條同一張圖。
            -- "solid" = 純色白貼圖，其餘走 LSM 名稱。
            barTexture = "tuktex",
            barFillAlpha = 1,
            barColorMode = "class",     -- class | accent | custom
            barColor = Color(0.35, 0.55, 0.8),
            barBgColor = Color(0, 0, 0, 0),
            barBgUseClassColor = false,
            barBorderSize = 0,
            barBorderColor = Color(0, 0, 0, 1),

            ------------------------------------------------------------
            -- 圖示
            ------------------------------------------------------------
            -- 刻意只有三種：專精圖示（暴雪內建 fileID）／暴雪職業圖示（內建 sprite）／無。
            -- 不帶自己的圖檔——這個 repo 玩家會整包 clone，多一套 sprite 就是多幾 MB。
            iconStyle = "spec",         -- none | spec | class
            iconZoom  = 0.06,

            ------------------------------------------------------------
            -- 文字
            ------------------------------------------------------------
            font = "default",
            fontOutline = "OUTLINE",    -- NONE | OUTLINE | THICKOUTLINE
            leftFontSize  = 12,
            rightFontSize = 12,
            leftTextUseClassColor  = false,
            rightTextUseClassColor = false,
            leftTextColor  = Color(1, 1, 1),
            rightTextColor = Color(1, 1, 1),
            leftTextOffsetX = 0, leftTextOffsetY = 0,
            rightTextOffsetX = 0, rightTextOffsetY = 0,
            hideRank = false,
            -- 0 = 只顯示每秒值，1 = 只顯示總量，2 = 總量 (每秒)，3 = 總量 | 每秒
            numberFormat = 2,
            -- CJK 客戶端預設用 萬/億 分級；勾起來強制 K/M/B（非 CJK 客戶端無作用）
            forceEnglishUnits = false,
            showPercent = true,

            ------------------------------------------------------------
            -- 視窗
            ------------------------------------------------------------
            bgColor = Color(0, 0, 0, 0.75),
            borderSize = 0,
            borderColor = Color(0, 0, 0, 1),

            ------------------------------------------------------------
            -- 標題列
            ------------------------------------------------------------
            hdrHeight   = 22,
            hdrFontSize = 12,
            hdrBgColor  = Color(0x1B/255, 0x1B/255, 0x1B/255, 1),
            hdrBottomBorderSize = 0,
            hdrBottomBorderColor = Color(0, 0, 0, 1),
            -- 標題文字職業色：預設用玩家自己的職業色（跟 MiliUI 其他插件的
            -- 強調色同一個來源）。關掉就用下面的自訂色。
            hdrTextUseClassColor = true,
            hdrTextColor = Color(1, 1, 1),
            hdrTextOffX = 0, hdrTextOffY = 0,
            -- 比標題列（22）矮一點：按鈕跟列等高的話，一排圖示看起來會像貼滿的貼紙
            hdrIconSize = 20,
            -- 預設開：標題列平常只留標題與計時器，滑過去才長出按鈕。
            -- 藏起來的按鈕不佔位置，所以標題能用滿整條（見 Win.FitTitle）。
            hdrMouseoverIcons = true,
            -- 預設藏起來：重置是不可逆的動作，不該擺在一顆隨手就會點到的按鈕上。
            -- 右鍵選單與 /mdm reset 都還在。
            hideResetButton = true,
            -- 齒輪那顆開的**就是右鍵選單**，功能完全重複 —— 預設也藏起來，
            -- 標題列少兩顆按鈕、標題就多兩顆按鈕的寬度可以用。
            hideSettingsButton = true,

            ------------------------------------------------------------
            -- 行為
            ------------------------------------------------------------
            showPinnedSelf    = true,   -- 自己掉出可視範圍時把那一列釘在上/下緣
            showHoverTooltip  = true,   -- 滑過長條顯示法術預覽
            showSpellTooltips = true,   -- 展開頁滑過法術顯示遊戲工具提示
            breakdownAnchor   = "row",  -- row | center | left | right
            -- 只要這支插件開著，就主動把暴雪內建的傷害統計關掉（CVar
            -- damageMeterEnabled）。**預設開**：兩份統計同時算是白花的成本，
            -- 兩個框同時出現也只是讓人困惑。關掉這個選項會把 CVar 還回去。
            disableBuiltinMeter = true,
            -- 進入新副本時要不要重置：off / ask（預設）/ auto。
            -- 三選一而不是「自動重置」＋「先確認」兩個勾選 —— 那樣會多出一個
            -- 無意義的組合，理由寫在 Meter/AutoReset.lua 的檔頭。
            autoReset = "ask",
            -- 視窗互相磁吸（拖曳與縮放時吸附其他統計視窗的邊緣與尺寸）
            snapEnabled   = true,
            snapThreshold = 6,
        },

        windowCount = 1,
        windows = nil,   -- DB.Init 補
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
-- 存取器
--
-- 一律走函式現查，不快取設定表：換設定檔／還原預設值時就不必到處失效，
-- 而且成本只是一次 table 索引。
------------------------------------------------------------
function DB.Style()
    return ns.db and ns.db.style
end

function DB.Win(idx)
    local db = ns.db
    if not db then return nil end
    db.windows = db.windows or {}
    if not db.windows[idx] then
        db.windows[idx] = DB.NewWindow(idx)
    end
    return db.windows[idx]
end

local function ClampCount(n)
    n = tonumber(n) or 1
    if n < 1 then return 1 end
    if n > DB.MAX_WINDOWS then return DB.MAX_WINDOWS end
    return math.floor(n)
end

function DB.WindowCount()
    return ClampCount(ns.db and ns.db.windowCount)
end

------------------------------------------------------------
-- 補齊視窗設定：至少一個，而且每一個都補齊欄位（玩家可能是從舊版升上來的）
--
-- ⚠ 讀的是**傳進來的那份設定檔**，不是 ns.db。DB.Activate 在 ns.db 指過去之前
-- 就要算視窗數，讀 ns.db 的話登入那次永遠拿到 nil ⇒ 視窗數每次登入都被壓回 1，
-- 多視窗設定活不過一次重載。
------------------------------------------------------------
function DB.EnsureWindows(profile)
    local p = profile or ns.db
    if not p then return 1 end
    p.windows = p.windows or {}
    local count = ClampCount(p.windowCount)
    p.windowCount = count
    for i = 1, count do
        if type(p.windows[i]) ~= "table" then
            p.windows[i] = DB.NewWindow(i)
        else
            MergeDefaults(p.windows[i], DB.NewWindow(i))
        end
    end
    -- 超出數量的殘留設定留著不刪：玩家把視窗數調回去時位置還在
    return count
end

------------------------------------------------------------
-- 設定檔
--
-- SV 結構：
--   MiliUI_DamageMeters_DB = {
--       schemaVersion, optionsWindow, builtinRestore, charClasses,  -- 帳號層
--       profiles    = { ["Default"] = { style=, windowCount=, windows= } },
--       profileKeys = { ["米利 - 世界之樹"] = "Default" },            -- 每角色指標
--   }
--
-- ns.db **就是那份設定檔本身**，不是另外組一張扁平表。這樣 ns.db.style /
-- ns.db.windows / ns.db.windowCount 的既有讀寫點全部不用改，而且純量寫入
-- （ns.db.windowCount = 3）也真的會落進 SV。
-- 帳號層的東西改走 DB.Account()：視窗位置（Options/Panel.lua）與「欠著一個
-- CVar 還原」的旗標（Meter/Builtin.lua）—— 後者是這台機器的狀態，
-- 絕對不能跟著設定檔或匯出字串跑。
--
-- 換設定檔一律 ReloadUI：每個統計視窗的框架、Rows 的池化列、Options 的
-- refresher 全都抓著舊表的參照，而換設定檔是罕見的刻意操作，重載最乾淨，
-- 也跟既有的「匯入並重載」一致。
------------------------------------------------------------
-- ⚠ 這是存進 SV 的 key，**不要翻譯**：翻了之後換客戶端語系就對不上，
-- 使用者會看到一份空白設定。顯示名稱由 Options 那邊翻（共用／角色專屬／自訂）。
DB.DEFAULT_PROFILE = "Default"

-- 「角色專屬」用保留前綴而不是另開一張表：這樣切換／刪除／匯出匯入全部共用
-- 同一套邏輯，不用到處寫特例。
local CHAR_PREFIX = "char:"

-- 一份設定檔裝哪些鍵。沒列到的頂層鍵就是帳號層的。
-- ⚠ 加新區塊時這裡要一起加，不然它會變成帳號層、切設定檔時不跟著換。
-- windows 不在這裡：它的預設值是 nil（由 DB.EnsureWindows 生），
-- 但**匯出匯入與深拷貝要帶著它走**，所以那幾支各自處理。
local PROFILE_KEYS = { "style", "windowCount", "windows" }

-- 一份全新設定檔。每次呼叫都是新表（BuildDefaults 自己就重建），
-- 所以拿去塞進 profiles 不會跟別份共用子表。
local function ProfileDefaults()
    local d = BuildDefaults()
    local out = {}
    for _, k in ipairs(PROFILE_KEYS) do out[k] = d[k] end
    return out
end
DB.ProfileDefaults = ProfileDefaults

-- 帳號層（SV 根）。視窗位置、內建統計還原旗標、角色職業表住這裡。
function DB.Account()
    return MiliUI_DamageMeters_DB
end

local function CharKey()
    return (UnitName("player") or "?") .. " - " .. (GetRealmName() or "?")
end
DB.CharKey = CharKey

function DB.CharProfileKey()
    return CHAR_PREFIX .. CharKey()
end

function DB.IsCharProfile(name)
    return type(name) == "string" and name:sub(1, #CHAR_PREFIX) == CHAR_PREFIX
end

-- "char:米利 - 世界之樹" → "米利 - 世界之樹"（顯示層要用）
function DB.CharProfileOwner(name)
    if not DB.IsCharProfile(name) then return nil end
    return name:sub(#CHAR_PREFIX + 1)
end

-- 那隻角色的職業（沒登入過就查不到，回 nil）
function DB.CharClass(charKey)
    local db = MiliUI_DamageMeters_DB
    return db and db.charClasses and db.charClasses[charKey]
end

-- 深拷貝：兩份設定檔絕不能共用同一張子表
local function DeepCopy(t)
    local o = {}
    for k, v in pairs(t) do o[k] = type(v) == "table" and DeepCopy(v) or v end
    return o
end

-- 全部列出來，包含**別隻角色**的角色專屬——刻意的：想直接切去用別隻角色調好的
-- 版面，或從他那份複製一份出來，都靠這個。
function DB.ListProfiles()
    local out = {}
    for name in pairs(MiliUI_DamageMeters_DB.profiles or {}) do out[#out + 1] = name end
    table.sort(out)
    return out
end

------------------------------------------------------------
-- 遷移
------------------------------------------------------------
-- 帳號層：style / windowCount / windows 原本住在 SV 最上層，具名設定檔上線後要
-- 搬進「共用」那份。判準用**結構**而不是版本號：這支的 schemaVersion 還只是佔位，
-- 而真正要問的問題就是「有沒有 profiles」。搬完把頂層那幾個鍵清掉，
-- 不留兩份會漂掉的資料。builtinRestore 與 optionsWindow 不在名單裡，原地留著。
local function MigrateAccount(db)
    if db.profiles then return end
    local moved
    for _, k in ipairs(PROFILE_KEYS) do
        if db[k] ~= nil then
            moved = moved or {}
            moved[k] = db[k]
            db[k] = nil
        end
    end
    if moved then
        db.profiles = { [DB.DEFAULT_PROFILE] = moved }
    end
end

-- 設定檔層：[版本號] = 把一份設定檔補到那個版本要做的事。
-- 目前是空的（還沒發佈過需要遷移的預設值變更）。發佈之後改任何預設值都要在這裡
-- 加一條並 bump ns.DB_VERSION——通則是「只動還等於舊預設值的欄位」（值閘），
-- 使用者調過的不碰。
--
-- 為什麼跟帳號層拆開：**匯入字串**帶著自己的 schemaVersion，可能比目前舊。那一份
-- 要補遷移，但不能把帳號層的版本號降下去——降了會讓遷移在所有設定檔上重跑一次。
local PROFILE_MIGRATIONS = {}

function DB.MigrateProfile(profile, fromVersion)
    if type(profile) ~= "table" then return end
    local from = tonumber(fromVersion) or 1
    for v = from + 1, ns.DB_VERSION do
        local step = PROFILE_MIGRATIONS[v]
        if step then pcall(step, profile) end
    end
end

------------------------------------------------------------
-- 啟用一份設定檔
--
-- 補齊預設值 → 指給 ns.db → 記下名字。登入與換設定檔走同一支，兩條路不會漂掉。
--
-- ⚠ MergeDefaults 一定要在這裡跑，不能只在登入時對「目前這一份」跑：別份設定檔
-- 可能是在某個鍵加進 BuildDefaults **之前**建立的，直接切過去會缺鍵。
------------------------------------------------------------
function DB.Activate(name)
    local db = MiliUI_DamageMeters_DB
    local p = db.profiles and db.profiles[name]
    if not p then return nil end
    MergeDefaults(p, ProfileDefaults())
    DB.EnsureWindows(p)
    ns.db = p
    ns.profileName = name
    return p
end

function DB.Init()
    if type(MiliUI_DamageMeters_DB) ~= "table" then
        MiliUI_DamageMeters_DB = {}
    end
    local db = MiliUI_DamageMeters_DB
    MigrateAccount(db)
    -- 尚未發佈、沒有遷移鏈；schemaVersion 先佔位，發佈後改預設值要配遷移
    db.schemaVersion = ns.DB_VERSION

    -- 帳號層預設值（設定視窗位置、內建統計還原旗標）
    local defaults = BuildDefaults()
    MergeDefaults(db, { optionsWindow = defaults.optionsWindow,
                        builtinRestore = defaults.builtinRestore })

    db.profiles = db.profiles or {}
    db.profileKeys = db.profileKeys or {}
    -- 角色 → 職業。設定檔清單要用職業色顯示「角色-伺服器」，而別隻角色的職業
    -- 沒有 API 可查，只能靠每隻角色登入時自己記一筆。
    -- ⚠ 存在帳號層而不是設定檔裡：設定檔會被深拷貝／重新灌種子，放進去會被帶錯。
    db.charClasses = db.charClasses or {}
    db.charClasses[CharKey()] = ns.playerClass

    local key = CharKey()
    local name = db.profileKeys[key]
    if type(name) ~= "string" or not db.profiles[name] then
        name = DB.DEFAULT_PROFILE
        db.profileKeys[key] = name
    end
    db.profiles[name] = db.profiles[name] or {}
    return DB.Activate(name)
end

------------------------------------------------------------
-- 三種設定檔
--   共用      key = "Default"，所有角色的預設，不給刪
--   角色專屬  key = "char:<角色> - <伺服器>"，第一次選才建立，來源由彈窗問
--   自訂      使用者自己命名的
------------------------------------------------------------
-- 寫入角色專屬那份。seed 只接受這三種，**沒有預設值**——來源一律由使用者在切換前
-- 的選擇彈窗指定（見 Options/Tab_Share.lua），這裡不替他猜。
--   "current"  目前正在用的那份（眼前看到的樣子）
--   "shared"   共用那份
--   "fresh"    全新預設值
-- ⚠ 會覆蓋既有內容，呼叫端必須先問過。
function DB.SeedCharProfile(seed)
    local db = MiliUI_DamageMeters_DB
    local key = DB.CharProfileKey()
    if seed == "fresh" then
        db.profiles[key] = ProfileDefaults()
        return key
    end
    local src
    if seed == "shared" then
        src = db.profiles[DB.DEFAULT_PROFILE]
    elseif seed == "current" then
        src = db.profiles[ns.profileName]
    end
    if not src then return nil end
    db.profiles[key] = DeepCopy(src)
    return key
end

-- copyFrom = nil 代表從預設值建立
function DB.CreateProfile(name, copyFrom)
    name = type(name) == "string" and name:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if name == "" then return false, "empty" end
    if DB.IsCharProfile(name) then return false, "reserved" end   -- char: 是保留前綴
    local db = MiliUI_DamageMeters_DB
    if db.profiles[name] then return false, "exists" end
    if copyFrom then
        local src = db.profiles[copyFrom]
        if not src then return false, "nosource" end
        db.profiles[name] = DeepCopy(src)
    else
        db.profiles[name] = ProfileDefaults()
    end
    return true
end

-- 刪掉指定那份，指著它的角色改回共用。共用本身不給刪。
function DB.DeleteProfile(name)
    local db = MiliUI_DamageMeters_DB
    if name == DB.DEFAULT_PROFILE or not db.profiles[name] then return false end
    db.profiles[name] = nil
    -- 指著它的角色全部改回共用，不然下次登入會看到一份空白設定
    for k, v in pairs(db.profileKeys) do
        if v == name then db.profileKeys[k] = DB.DEFAULT_PROFILE end
    end
    return true
end

-- 換設定檔：寫下指標再重載。
-- ⚠ profileKeys 一定要在 ReloadUI **之前**寫，重載之後就是靠它認得回來。
function DB.SwitchProfile(name)
    local db = MiliUI_DamageMeters_DB
    if not (db.profiles and db.profiles[name]) then return false end
    db.profileKeys[CharKey()] = name
    if name == ns.profileName then return true end
    ReloadUI()
    return true
end

------------------------------------------------------------
-- 恢復預設
------------------------------------------------------------
-- 目前這份設定檔全部恢復預設後重載。
-- ⚠ 只動這一份，其他設定檔與帳號層（設定視窗位置、內建統計還原旗標）不碰——
-- 有設定檔系統之後，「重置」把整個帳號炸掉太超過了。想從零開始就切到一份新的。
-- ⚠ 這是**設定**的重置，跟 /mdm reset（清掉記錄的戰鬥分段）是兩件事。
function DB.ResetAll()
    local db = MiliUI_DamageMeters_DB
    local name = db and db.profileKeys and db.profileKeys[CharKey()]
    if db and name and db.profiles then
        db.profiles[name] = ProfileDefaults()
    end
    ReloadUI()
end
