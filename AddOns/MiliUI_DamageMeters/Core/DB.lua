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
        -- 戰鬥開始時，正在看歷史分段的視窗自動跳回「本場」
        autoCurrentOnCombat = true,
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
-- 一律走函式現查，不快取設定表：換 profile／還原預設值時就不必到處失效，
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

function DB.WindowCount()
    local db = ns.db
    if not db then return 1 end
    local n = tonumber(db.windowCount) or 1
    if n < 1 then n = 1 end
    if n > DB.MAX_WINDOWS then n = DB.MAX_WINDOWS end
    return n
end

function DB.Init()
    if type(MiliUI_DamageMeters_DB) ~= "table" then
        MiliUI_DamageMeters_DB = {}
    end
    local db = MiliUI_DamageMeters_DB

    MergeDefaults(db, BuildDefaults())

    -- 至少一個視窗，而且每一個都補齊欄位（玩家可能是從舊版升上來的）
    db.windows = db.windows or {}
    local count = DB.WindowCount()
    db.windowCount = count
    for i = 1, count do
        if type(db.windows[i]) ~= "table" then
            db.windows[i] = DB.NewWindow(i)
        else
            MergeDefaults(db.windows[i], DB.NewWindow(i))
        end
    end
    -- 超出數量的殘留設定留著不刪：玩家把視窗數調回去時位置還在

    db.schemaVersion = ns.DB_VERSION
    ns.db = db
    return db
end

function DB.ResetAll()
    MiliUI_DamageMeters_DB = nil
    ReloadUI()
end
