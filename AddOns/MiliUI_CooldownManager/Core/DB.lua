------------------------------------------------------------
-- SavedVariables：MiliUI_CooldownManager_DB
--
--   MiliUI_CooldownManager_DB = {
--       schemaVersion, schemaVersionSeen,             -- 遷移鏈
--       minimap, optionsWindow,                       -- 帳號層，不跟設定檔走
--       customSounds, customSoundNext,                -- 自訂語音清單（帳號層，見 Core/Sound.lua）
--       profiles     = { ["Default"] = <profile>, … },
--       profileKeys  = { ["角色 - 伺服器"] = "Default" },            -- 每角色目前用哪份
--       specProfiles = { ["角色 - 伺服器"] = { enabled = bool, [專精序號] = "設定檔名" } },
--       charClasses  = { ["角色 - 伺服器"] = "PALADIN" },            -- 清單上色用
--       diag, perfLog,                                -- 開發用：診斷記錄（Core/Diag.lua）／脫戰印這一場的計數（/mcdm perf log）
--   }
--
-- 設定視窗的位置與上次停在哪一頁放帳號層（跟單位框架同一個理由）：換設定檔不該讓
-- 視窗跳位置，而切到另一份設定檔時「上次那一頁」可能是那份沒有的自訂群組。
--
-- ⚠ 預設值合併規則（堵死 boolean 陷阱）：
--   * 使用者值只補 nil、永不覆蓋
--   * **預設值裡不放「用 nil 表示關閉」的欄位**：預設是表或數字的欄位，玩家關掉之後
--     若存成 nil，下次合併又會被補回預設 ⇒ 關不掉。「沒有／不要」一律存 false
--     （anchor = false、row2Size = false、fade.whenMounted = false…）。
--
-- ⚠ 顏色一律 { r, g, b, a }（表單引擎的色票直接讀寫這個形狀）。
------------------------------------------------------------
local _, ns = ...

ns.DB = {}
local DB = ns.DB

-- schemaVersion。加 MIGRATIONS 條目時一起 bump；**號碼不要重用**。
ns.DB_VERSION = 4

-- ⚠ 存進 SV 的 key，**不要翻譯**：翻了之後換客戶端語系就對不上。
DB.DEFAULT_PROFILE = "Default"

------------------------------------------------------------
-- 寫入世代（讀取端 memo 的作廢點；效能修整 E2，2026-10-04）
--
--   DB.overrideGen  逐法術覆寫、專精表（spells[spec] 的 order／groupOf／hidden／overrides）、自訂項目有任何寫入就 +1
--                   讀的人：Catalog.Replacements 的 memo、Decorate.Apply 的前置鍵（SpellStyle 讀覆寫；IconOverrideOf
--                   也看「這個 id 是不是光環格」＝自訂清單，所以自訂項目的寫入一併 +1）
--   DB.customGen    自訂項目（三層清單、一筆的欄位）有任何寫入就 +1
--                   讀的人：EffectiveCustom 的 memo、Catalog.CustomInfo 的 memo
-- 作廢點一律放在**寫入的出口**：SpecSpells／CustomList／ScopeList／OverrideTable 的 create=true（＝呼叫端要寫）、
-- SetOverride／DropOverrideTable／ClearOverrides、增刪搬複製自訂項目、DeleteBar、Activate（換設定檔）、
-- ResetProfile、ImportProfile、換專精。拿到表之後直接改欄位的少數地方（設定頁改 hideUnknown／placeholder、
-- 刪自訂語音時清覆寫、匯入的待對應覆寫）自己叫 DB.TouchCustom／DB.TouchOverrides。
-- 讀取端另外都有「每幀戳記」當第二道保險：漏掉一個作廢點最多錯到這一幀結束。
------------------------------------------------------------
DB.overrideGen, DB.customGen = 0, 0
function DB.TouchOverrides() DB.overrideGen = DB.overrideGen + 1 end
function DB.TouchCustom()
    DB.customGen = DB.customGen + 1
    DB.overrideGen = DB.overrideGen + 1
end

local function rgba(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end
local ResourcesDefaults, PipsDefaults, CastbarDefaults, AssistIconDefaults   -- 定義在 BuildDefaults 前面（前置宣告，免得變全域）

-- 「整張表當一個值」的預設：設定檔裡**沒有這個鍵**才整張給，已經有（含空表）就一個字都不合併。
-- 給內容是使用者自己的清單、但預設不是空的那種表用（資源條的上色規則）：逐元素合併會把預設規則的
-- 欄位灌進玩家自己的規則裡，而規則刪光之後也會被補回來。
local ATOMIC = setmetatable({}, { __mode = "k" })
local function Atomic(t) ATOMIC[t] = true; return t end

-- 規則一條的寫法（同 Modules/ResourceConditions.lua）：點數 >= value 時換色
local function AtLeast(value, r, g, b)
    return { check = { var = "powerValue", cmp = ">=", value = value }, overrides = { color = rgba(r, g, b, 1) } }
end

------------------------------------------------------------
-- 預設值
--
-- 數值取套組目前出貨的那組：核心 46×40、輔助 26×24、增益 40×36、間距 1、每列 8、
-- 字型「提示訊息」＋描邊、發光 pixel、長條往下長；位置核心 (0,-202)／增益 (0,-149)／
-- 長條 BOTTOM (0,300)，輔助錨在自訂格子下方、自訂格子錨在核心下方（核心 → 自訂格子 → 輔助；
-- 沒有自訂格子時那一層高度 0，輔助照舊貼在核心下方）。
--
-- 位置 pos：{ point, x, y }。point 同時是容器的錨點與 UIParent 的對應點
-- （CENTER 偏移就是 point = "CENTER"）。存的是**錨點那一邊**的座標，
-- 圖示增減時那一邊不動。
--
-- 條的 text／icon／glow／fade 四張子表：follow 對應那一項為 true 時完全不讀，
-- 讀的是 theme（見檔尾的 ns.Setting）。預設給空表、什麼都不複製；
-- 取不到的值一律退回 theme，所以子表只需要放「跟主題不一樣的那幾格」。
------------------------------------------------------------
local function IconBar(o)
    return {
        kind       = "icons",               -- icons | bars
        source     = o.source,              -- essential | utility | buffs | buffbars | custom
        pos        = o.pos,
        anchor     = o.anchor or false,     -- false ＝ 不錨在別條上；或 { to, point, relPoint, x, y }
        layout     = {
            maxPerRow  = o.maxPerRow or 8,
            spacing    = 1,
            grow       = o.grow or "CENTER_DOWN",   -- <CENTER|LEFT|RIGHT>_<DOWN|UP>（橫向）或 <DOWN|UP>_<RIGHT|LEFT>（直向）
            size       = { w = o.w, h = o.h },
            row2Size   = false,                     -- false ＝ 第二列起跟第一列同尺寸；或 { w, h }
            fixedSlots = o.fixedSlots or false,     -- 增益不在時保留空位
            -- 格數上限＋溢出（2026-10-04，F1；舊存檔沒有 ＝ 0／false ＝ 不限，不遷移；規則在 Core/Overflow.lua）。
            -- 只有圖示類的條讀（長條類也帶著這兩欄，用不到）
            maxIcons   = 0,                         -- 0 ＝ 不限；1～20
            overflowTo = false,                     -- false 或另一條圖示類的條的 key
        },
        follow     = { text = true, icon = true, glow = true, fade = true },
        text = {}, icon = {}, glow = {}, fade = {},
        visibility = { showCombat = false, showTarget = false, hideMounted = false,
                       onlyInstances = false, group = "any",     -- group: any | solo | party | raid
                       -- 2026-10-03 加的三個（舊存檔沒有 ＝ false，不遷移；見 Core/Visibility.lua）
                       showEnemy = false, hideSkyriding = false, hideHousing = false,
                       -- 2026-10-04 加的兩個（F5；舊存檔沒有 ＝ false，不遷移）
                       hideResting = false, hideVehicle = false },
        bar        = o.bar or false,        -- kind = "bars" 才有
        strata     = "MEDIUM",
        clickable  = false,                 -- 點了施放／使用（只有自訂圖示群組讀，判準在 DB.BarClickable）
        -- 跟著游標（只有自訂圖示群組、沒有光環格、沒勾可點擊時讀；判準在 Core/Cursor.lua 的 Eligible）
        cursor     = { enabled = false, x = 20, y = -20 },
    }
end

-- 長條（kind = "bars"）：增益長條與「長條群組」共用
local function LongBar(o)
    local b = IconBar{
        source = o.source, pos = o.pos,
        maxPerRow = 1, grow = o.grow or "CENTER_DOWN", w = 200, h = 20,
        bar = {
            width     = 0,                  -- 0 ＝ 跟核心技能第一列同寬
            height    = 20,
            texture   = "solid",
            color     = rgba(0.4, 0.6, 0.9, 1),
            bgColor   = rgba(0.1, 0.1, 0.1, 0.8),
            iconSide  = "LEFT",             -- LEFT | RIGHT | NONE
            iconGap   = 1,
            showName  = true, nameSize = 16, nameFont = "INHERIT",   -- 字型 "INHERIT" ＝ 跟隨通用字型
            showTime  = true, timeSize = 16, timeFont = "INHERIT",
            showStacks = true, stackSize = 12,
            spark     = false,              -- 填充末端的火花（暴雪條的 Pip）；false ＝ 藏（舊行為）
            -- 2026-10-04 加的三組（F8；舊存檔沒有 ＝ false ＝ 舊行為，不遷移）
            gradient  = false,              -- false | { color2 = rgba, dir = "H" | "V" }：填充從 color 漸變到 color2
            chargeSegments  = false,        -- 自訂法術的充能：條身分成 maxCharges 段（Modules/Custom.lua）
            chargeLineColor = rgba(0, 0, 0, 0.6),   -- 分段的分隔線顏色
            vertical  = false,              -- 整條直向（填充由下往上、圖示在上／下、條並排）
        },
    }
    b.kind = "bars"
    return b
end

-- 自訂群組的預設形狀（新增群組、右鍵「重設為預設」都照這個）。
-- 只給版面與位置；text／icon／glow／fade 是空表、follow 全 true ⇒ 什麼都不複製。
function DB.NewBarTable(kind, name)
    local b
    if kind == "bars" then
        b = LongBar{ source = "custom", pos = { point = "CENTER", x = 0, y = 0 } }
    else
        b = IconBar{ source = "custom", pos = { point = "CENTER", x = 0, y = 0 }, w = 36, h = 36 }
    end
    b.name = name
    return b
end

------------------------------------------------------------
-- 資源條（Modules/Resources.lua）、自訂格子（Modules/Pips.lua）、施法條（Modules/Castbar.lua）
-- 與下一招圖示（Modules/AssistIcon.lua）
--
-- 四者都不在 bars 裡（不是暴雪檢視器、沒有版面／主題繼承），但**錨定語意跟條一樣**：
-- pos ＝ { point, x, y }、anchor ＝ false 或 { to, point, relPoint, x, y }，容器走
-- Core/Bars.lua 的 RegisterPanel（ApplyStructure、編輯模式、磁吸都是同一套）。
-- DB.ConfigTable(key) 是「條或面板」的統一取表出口。
--
-- 資源顏色的預設（單一來源）：每一種資源的主色；連擊點數多兩格充能色。
-- 盜賊「超級充能器」／野德「滿溢之力」讓某幾格變成充能點，已填滿用 chargedColor、
-- 還沒填到用暗一階的 chargedEmptyColor（打滿之前就看得出哪幾格是充能格）。
-- ⚠ 公開 API（Api.lua 的 GetResourceColors）回的是設定檔裡**這幾張表的參照**，
--   預設值本身每次 BuildDefaults 都是全新深複製，不會被外面改到。
------------------------------------------------------------
local RESOURCE_COLORS = {
    Mana            = { color = { r = 0.2,   g = 0.5,   b = 1     } },
    Rage            = { color = { r = 0.78,  g = 0.25,  b = 0.25  } },
    Energy          = { color = { r = 1,     g = 0.96,  b = 0.41  } },
    Focus           = { color = { r = 1,     g = 0.5,   b = 0.25  } },
    RunicPower      = { color = { r = 0,     g = 0.82,  b = 1     } },
    LunarPower      = { color = { r = 0.3,   g = 0.52,  b = 0.9   } },
    Maelstrom       = { color = { r = 0,     g = 0.5,   b = 1     } },
    Insanity        = { color = { r = 0.4,   g = 0,     b = 0.8   } },
    Fury            = { color = { r = 0.788, g = 0.259, b = 0.992 } },
    HolyPower       = { color = { r = 0.914, g = 0.678, b = 0.275 } },
    ComboPoints     = { color             = { r = 1,    g = 0.96, b = 0.41 },
                        chargedColor      = { r = 0.24, g = 0.60, b = 1.00 },
                        chargedEmptyColor = { r = 0.12, g = 0.30, b = 0.50 } },
    Chi             = { color = { r = 0.71, g = 1,    b = 0.92 } },
    SoulShards      = { color = { r = 0.58, g = 0.51, b = 0.79 } },
    ArcaneCharges   = { color = { r = 0.25, g = 0.35, b = 0.98 } },
    Essence         = { color = { r = 0.28, g = 0.73, b = 0.92 } },
    Runes           = { color = { r = 0.77, g = 0.12, b = 0.23 } },
    -- 氣漩武器：overflowColor 是摺成 5 格（maelstromFold）時上層（第 6～10 層）的顏色，跟主色的藍分得開
    MaelstromWeapon = { color         = { r = 0.2,  g = 0.65, b = 1    },
                        overflowColor = { r = 1,    g = 0.82, b = 0.2  } },
    TipOfTheSpear   = { color = { r = 1,    g = 0.6,  b = 0.2  } },
    SoulFragments   = { color = { r = 0.64, g = 0.19, b = 0.79 } },
    -- 2026-09-30 補齊的職業資源（冰刺冰藍、噬靈魂碎片同復仇的紫、戰士三種暖色系、鐵鬃棕）
    Icicles         = { color = { r = 0.44, g = 0.80, b = 1    } },
    DevourerFragments = { color = { r = 0.64, g = 0.19, b = 0.79 } },
    -- 醉仙緩勁：輕度（主色）／中度／重度，門檻在 staggerModerateAt／staggerHeavyAt；
    -- 另有第 3／4 段（預設關，staggerTier3At／staggerTier4At）
    Stagger         = { color         = { r = 0.52, g = 0.90, b = 0.52 },
                        moderateColor = { r = 1,    g = 0.85, b = 0.36 },
                        heavyColor    = { r = 1,    g = 0.42, b = 0.42 },
                        tier3Color    = { r = 1,    g = 0.2,  b = 0.8  },
                        tier4Color    = { r = 0.75, g = 0.2,  b = 1    } },
    WhirlwindStacks = { color = { r = 0.90, g = 0.45, b = 0.20 } },
    SweepingStrikes = { color = { r = 0.85, g = 0.65, b = 0.35 } },
    IgnorePain      = { color = { r = 0.95, g = 0.80, b = 0.35 } },
    Ironfur         = { color = { r = 0.72, g = 0.52, b = 0.30 } },
    -- 光環剩餘時間條：黯黑力量（喚能師的古銅黑金）、秘法靈魂（秘法紫，跟秘法充能的藍分得開）
    EbonMight       = { color = { r = 0.80, g = 0.60, b = 0.20 } },
    ArcaneSoul      = { color = { r = 0.66, g = 0.40, b = 1    } },
    -- 征戰聖擊：照德莫的征戰聖擊助手的預設（聖騎職業色填充、黑底 60%）；底色帶 alpha
    CrusadingStrikes = { color     = { r = 0.9568, g = 0.5490, b = 0.7294 },
                         backColor = { r = 0, g = 0, b = 0, a = 0.6 } },
    -- 血量：預設走職業色（healthClassColor），這是關掉職業色時的顏色
    Health          = { color = { r = 0.2,  g = 0.8,  b = 0.2  } },
}
DB.RESOURCE_COLORS = RESOURCE_COLORS

-- 萬／億縮寫是中日韓的讀法；其他語系預設 K／M
local CJK = { zhTW = true, zhCN = true, koKR = true }

ResourcesDefaults = function()
    local colors = {}
    for key, fields in pairs(RESOURCE_COLORS) do
        local t = {}
        for field, c in pairs(fields) do t[field] = rgba(c.r, c.g, c.b, c.a or 1) end
        colors[key] = t
    end
    return {
        enabled       = true,
        pos           = { point = "CENTER", x = 0, y = -180 },
        -- 預設貼在核心技能上緣，往上長
        anchor        = { to = "essential", point = "BOTTOM", relPoint = "TOP", x = 0, y = 1 },
        width         = 0,                 -- 0 ＝ 跟核心技能第一列同寬
        textFont      = "INHERIT",         -- 條上數字的字型（自訂格子也照這個）；"INHERIT" ＝ 跟隨主題的通用字型
        rowHeight     = 14,                -- 使用者 2026-10-01 指定，不遷移。沒有控件了：只當 heights 沒設的列的起始值
        heights       = {},                -- [資源key] = 列高（所有專精共用；每種資源設定視窗的「高」）
        -- [資源key] = { follow, texture, bgTexture, barAlpha, bgAlpha, bgCustom, bgColor, smooth, showText, textFont, textSize }：
        -- 每種資源自己的外觀（設定視窗的「外觀」那一節）。開放式、預設空；follow 沒存 ＝ 跟下面這幾欄（全域）。
        -- 引擎讀 Modules/Resources.lua 的 R.StyleFor 回的代理表
        style         = {},
        rowSpacing    = 1,
        segmentSpacing = 0,                -- 點數型（聖能、連擊點…）的格距；0 ＝ 相鄰兩格共用 1px 邊（使用者 2026-10-01 指定，不遷移）
        fillDirection = "ltr",             -- ltr | rtl（點數型從右邊亮起）
        texture       = "solid",
        bgTexture     = "INHERIT",         -- 空的那截（背景）的材質；"INHERIT" ＝ 跟填充同一張（自訂格子也照這個）
        barAlpha      = 1,                 -- 填充色的不透明度
        -- 背景（空的那截）：bgAlpha 乘在預設深淺上（1 ＝ 原樣、0 ＝ 透明）；bgCustom 勾了才用 bgColor 換掉自動推的底色
        bgAlpha       = 1,
        bgCustom      = false,
        bgColor       = { r = 0.15, g = 0.15, b = 0.15, a = 1 },
        smooth        = true,              -- 連續條的原生內插（引擎做，吃秘密值）
        -- 條上的數值：預設開、14 號字、置中（使用者 2026-10-01 指定，不遷移）
        showText      = true,
        textSize      = 14,
        runeText      = "countdown",       -- 死騎符文列的數字：countdown 每格秒數／count 中間顆數，showText 開著才有（見 Resources.lua 的 R.RuneText）
        runeQueued    = true,              -- 排隊中（還沒開始轉）的符文也算：印總等待秒數、填充照整段等待時間走（見 Resources.lua 的 R.RuneProgress）
        manaAbbrev    = CJK[GetLocale and GetLocale() or ""] and "wan" or "k",   -- none | k | wan
        manaPercent   = false,             -- 法力列印百分比而不是數值
        -- 血量列（每個專精都是候選、預設關）：數字縮寫沿用 manaAbbrev
        healthPercent = false,             -- 血量列印百分比而不是數值
        healthClassColor = true,           -- 用職業色；關掉用 colors.Health.color
        healthThresholdEnabled = false,    -- 門檻換色（低於門檻換那一筆的顏色，C 端求值）
        healthThresholds = {},             -- { { pct = 1..99, color = { r, g, b, a } }, … }，最多 6 筆
        -- 列的順序：資源 key 的陣列，整份設定檔共用（不分專精）；不在裡面的照專精清單排在後面
        -- （Modules/Resources.lua 的 R.ApplyOrder）。空 ＝ 全部照預設
        order         = {},
        -- 醉仙緩勁：中度／重度的門檻（% 最大生命）、滿條對應幾 % 最大生命（1～300）
        staggerModerateAt = 30,
        staggerHeavyAt    = 60,
        staggerCeiling    = 100,
        -- 醉仙緩勁第 3／4 段（重度之上再分兩段換色）：預設關
        staggerTier3Enabled = false,
        staggerTier3At      = 90,
        staggerTier4Enabled = false,
        staggerTier4At      = 150,
        -- 氣漩武器 10 層摺成 5 格兩層（上層用 colors.MaelstromWeapon.overflowColor）。預設關：
        -- 使用者 2026-10-01 調好的 ≥9／≥10 兩段換色是照 10 格寫的
        maelstromFold = false,
        -- 秘法靈魂的數字（showText 開著才有）：seconds 剩餘秒數／gcd 剩幾個 GCD
        arcaneSoulText = "seconds",
        -- 征戰聖擊列（懲戒）：自己的高度與填充方向，預設照德莫的征戰聖擊助手（高 4、已揮的時間長出來）
        crusadingHeight = 4,                   -- 沒有控件了：只當 heights.CrusadingStrikes 沒設時的起始值
        crusadingFill   = "elapsed",           -- elapsed | remaining
        crusadingHideBar = true,               -- 這一列顯示時，增益長條上的征戰聖擊自動藏起來
        -- [資源key] = { rule, … }：開放式鍵值表。預設只給新設定檔（Atomic：已有 conditions 的設定檔不合併，
        -- 規則刪光也不會被補回來）。聖能／氣旋武器的兩段換色是使用者 2026-10-01 調好的
        conditions    = Atomic({
            HolyPower = {
                AtLeast(5, 0.914, 0.286, 0.361),
                AtLeast(3, 0.914, 0.424, 0.851),
            },
            MaelstromWeapon = {
                AtLeast(10, 1, 0.231, 0.318),
                AtLeast(9, 1, 0.596, 0.984),
            },
        }),
        -- 這個專精要顯示哪些：[specID] = { [資源key] = true／false }（nil ＝ 照那個專精的預設，
        -- 見 Modules/Resources.lua 的 R.RowOn／R.SetRow）；開放式、預設空。v3 以前是平面的 [資源key]
        rows          = {},
        -- 自訂格子：[specID] = { { kind = "charges"|"stacks", spellID, max, color, showTime, showWhen, enabled }, … }
        -- 開放式、預設空。畫在自己的面板（profile.pips、Modules/Pips.lua），樣式沿用這張表
        customRows    = {},
        colors        = colors,
        -- 載入條件：任一成立就整條藏（alpha 0）
        loadConditions = { hideMounted = false, onlyCombat = false },
        -- 跟核心技能條一起淡（取核心技能現在的 alpha，含它的顯示條件與淡出）
        fadeWithEssential = true,
        strata        = "MEDIUM",
    }
end

-- 自訂格子的面板：只有位置／錨定／開關／淡出是自己的（清單與樣式在 profile.resources）
PipsDefaults = function()
    return {
        enabled       = true,
        pos           = { point = "CENTER", x = 0, y = -250 },
        -- 預設貼在核心技能下緣、往下長（使用者 2026-09-30 指定）。輔助技能也跟著核心技能的下方，
        -- 兩個同一邊 ⇒ 自動排開，格子在內、輔助在外（Core/Layout.lua 的 StackTarget）
        anchor        = { to = "essential", point = "TOP", relPoint = "BOTTOM", x = 0, y = -1 },
        -- 跟核心技能條一起淡（同資源條）
        fadeWithEssential = true,
        -- 載入條件：任一成立就整個面板藏（alpha 0），同資源條；兩邊各自一份
        loadConditions = { hideMounted = false, onlyCombat = false },
        strata        = "MEDIUM",
    }
end

CastbarDefaults = function()
    return {
        enabled       = true,
        pos           = { point = "CENTER", x = 0, y = -260 },
        -- 預設跟舊套組一樣的位置：核心技能上方、資源條的外面（兩個都跟著核心技能的上方，自動排開），
        -- 寬度跟核心技能同寬
        anchor        = { to = "essential", point = "BOTTOM", relPoint = "TOP", x = 0, y = 1 },
        width         = 0,                 -- 0 ＝ 跟核心技能第一列同寬（含圖示）
        height        = 20,
        font          = "INHERIT",         -- 文字字型；"INHERIT" ＝ 跟隨主題的通用字型
        texture       = "blizzard",        -- 暴雪施法條的漸層圖（去色後照下面的顏色染）；v2 起的預設（使用者 2026-10-02 指定）
        bgColor       = rgba(0.1, 0.1, 0.1, 0.8),
        colors        = {
            cast            = rgba(0.906, 0.424, 0.2),
            channel         = rgba(0.906, 0.424, 0.2),
            uninterruptible = rgba(0.529, 0.529, 0.529),
            interrupted     = rgba(1, 0.204, 0.145),
            interruptReady  = rgba(1, 0.741, 0),
            -- 蓄力施法：走到第幾階就換那一階的顏色
            empowerStage1   = rgba(0.35, 0.75, 0.35),
            empowerStage2   = rgba(0.95, 0.80, 0.20),
            empowerStage3   = rgba(1.00, 0.50, 0.15),
            empowerStage4   = rgba(0.90, 0.20, 0.20),
        },
        useClassColor = true,              -- 施法／引導共用職業色（蓄力、不可打斷照疊）；舊套組預設就是職業色
        showIcon      = true,
        iconSide      = "LEFT",            -- LEFT | RIGHT
        iconGap       = 1,
        showName      = true,
        nameMaxChars  = 0,                 -- 0 ＝ 不限
        showTime      = true,
        timeFormat    = "remainTotal",     -- remainTotal | elapsedTotal | remain | elapsed
        textSize      = 12,
        -- 名字／時間的位移（2026-10-04，玩家要求）：錨點固定（名字錨左緣、時間錨右緣、都是垂直中線），
        -- 預設 y ＝ 0 ⇒ 被動垂直置中；x 是離邊的留白。舊存檔靠 MergeDefaults 補上，不遷移
        nameOffset    = { x = 4, y = 0 },
        timeOffset    = { x = -4, y = 0 },
        showSpark     = true,
        interruptShake = true,             -- 被打斷或施法失敗時震動一下
        ticks         = true,              -- 引導刻度
        latency       = true,              -- 延遲條
        hideBlizzard  = true,              -- 隱藏暴雪的玩家施法條（只解事件，見 Castbar.lua）
        interruptReady = false,            -- 自己的斷法就緒時換色
        fillDirection = "ltr",
        hideWhenNotCasting = true,         -- 沒在施法時 alpha 0（編輯模式中照樣全亮）
        strata        = "MEDIUM",
    }
end

-- 下一招圖示（Modules/AssistIcon.lua，面板 assistIcon）：戰鬥輔助建議的下一招，純顯示、不能點。
-- 預設關；舊存檔沒有這張表 ＝ 合併預設值補上（關著），不遷移
AssistIconDefaults = function()
    return {
        enabled     = false,
        pos         = { point = "CENTER", x = 0, y = -120 },
        anchor      = false,
        size        = 44,
        onlyCombat  = true,                -- 只在戰鬥中顯示（編輯模式中照樣全亮）
        showKeybind = true,                -- 按鍵文字（樣式照主題的 keybind）
        showGCD     = true,                -- 公共冷卻轉圈
        strata      = "MEDIUM",
    }
end

function DB.BuildDefaults()
    -- 位置與往上長：使用者 2026-10-01 指定（照使用者調好的那份），不遷移
    local buffbars = LongBar{ source = "buffbars", grow = "CENTER_UP", pos = { point = "BOTTOM", x = 0, y = 524 } }

    return {
        account = {
            minimap       = { hide = false, angle = 215 },
            optionsWindow = { x = 0, y = 0, lastBar = "essential" },
            customSounds    = {},           -- { { id, name, path }, … }：path 是 AddOns 底下的相對路徑
            customSoundNext = 1,
        },
        profile = {
            theme = {
                font    = "提示訊息",        -- LibSharedMedia 名稱；沒有這個名稱的客戶端退回在地化字型
                outline = "OUTLINE",
                border  = { texture = "solid", size = 1, color = rgba(0, 0, 0, 1) },
                -- 每段文字的 font："INHERIT" ＝ 跟隨上面的通用字型（ns.Media.ElementFont）
                cooldownText = { size = 16, color = rgba(1, 1, 1), decimalsBelow = 3,
                                 lowColor = rgba(1, 0.3, 0.3), lowBelow = 5, font = "INHERIT" },
                chargeText   = { size = 12, color = rgba(1, 1, 1), point = "BOTTOMRIGHT", x = 0, y = 0, font = "INHERIT" },
                stackText    = { size = 12, color = rgba(1, 1, 1), point = "TOP",         x = 0, y = 0, font = "INHERIT",
                                 -- 長條（kind = "bars"）的層數錨在圖示的哪一角；舊存檔沒有 ＝ 合併預設補成右下（舊行為）
                                 barPoint = "BOTTOMRIGHT" },
                -- skin：圖示外觀 "miliui"（自己畫邊框／縮放）| "masque"（交給 Masque，Core/Masque.lua）；
                -- 舊存檔沒有這欄 ＝ 預設，不遷移
                icon  = { skin = "miliui", zoom = 0.08, swipeColor = rgba(0, 0, 0, 0.8), tooltips = true,
                          -- 按鍵鏡射（Core/Keybinds.lua）：按下這格的綁定鍵時亮一層白。長條類／增益圖示列不做。
                          -- 舊存檔沒有這兩欄 ＝ 合併預設值補成關，行為不變、不遷移
                          pressFlash = false, pressFlashAlpha = 0.35,
                          hideGCDSwipe = false, desaturateOnCooldown = true,
                          -- 暴雪的減益類型邊框（打在目標上的魔法／詛咒…減益會框一圈驅散色）：預設藏
                          hideDebuffBorder = true,
                          -- 冷卻狀態（核心／輔助、自訂法術／物品／飾品欄；增益類不適用）：
                          -- "none" 不變｜"dim" 冷卻中變暗（cdStateAlpha）｜"hideOnCD" 冷卻中看不到｜"hideReady" 轉好時看不到。
                          -- 舊存檔沒有這欄 ＝ "none"（合併預設值補上），行為不變、不遷移
                          cdState = "none", cdStateAlpha = 0.4,
                          -- 增益持續中顯示持續時間（核心／輔助）：技能用掉後暴雪先倒增益、增益掉了才倒冷卻。
                          -- false ＝ 蓋掉增益那一段、直接倒技能真正的冷卻（Core/Decorate.lua）。
                          -- 預設 true ＝ 暴雪原本的行為；舊存檔沒有這欄 ＝ 合併預設值補成 true，行為不變、不遷移
                          showAuraTime = true,
                          -- colorDuration／durationColor：增益那一段的倒數數字換這個顏色（Core/Text.lua 的 ApplyPhaseColor）。
                          -- 預設開（使用者拍板：舊存檔沒有這兩欄 ＝ 合併預設值補成開，不套「舊存檔行為不變」）
                          colorDuration = true, durationColor = rgba(1, 0.85, 0.1),
                          -- 增益那一段自己的低秒顏色（門檻共用 cooldownText.lowBelow；粉，比聖騎粉重一點）與轉圈背景色（淡黃）
                          durationLowColor = rgba(0.95, 0.45, 0.70), durationSwipeColor = rgba(1, 0.9, 0.5, 0.5),
                          -- 沒有物品時隱藏（自訂物品：主＋替代品包包裡全都沒有）／被動飾品不顯示（飾品欄與代畫格：
                          -- 那一格裝的東西沒有使用效果）。收掉＝讓位（Core/Bars.lua 的 Relayout；固定格位的條留空格）。
                          -- hideNoItem 預設關；hidePassiveTrinket 預設開（使用者拍板：舊存檔沒有這欄 ＝ 合併預設值補成開，
                          -- 不套「舊存檔行為不變」）
                          hideNoItem = false, hidePassiveTrinket = true },
                -- 預設樣式：觸發＝觸發、就緒＝快捷鍵閃光（2026-10-01 使用者指定；舊存檔不遷移）
                glow  = {
                    proc  = { enabled = true,  type = "proc",  color = rgba(1, 0.85, 0, 1),
                              lines = 8, thickness = 2, frequency = 0.2 },
                    -- mode：timed 亮 duration 秒／untilUsed 亮到用掉（回充照秒數）／whileReady 就緒時一直亮（Core/Glow.lua）
                    -- requireUsable：資源不夠時先不亮、等到夠了才亮（Core/Glow.lua）
                    ready = { enabled = false, type = "button", color = rgba(0.3, 1, 0.3, 1),
                              lines = 8, thickness = 2, frequency = 0.2, duration = 3, mode = "timed", requireUsable = false },
                    -- 生效發光：跟觸發／就緒同一套（條層開關＋樣式），**預設關**，玩家在個別法術上打開（overrides[id].activeGlow）
                    active = { enabled = false, type = "pixel", color = rgba(0.95, 0.95, 0.32, 1),
                               lines = 8, thickness = 2, frequency = 0.2 },
                    -- 充能滿了發光：充能技能每一層都回滿時一直亮（Core/Glow.lua 的 SyncFull）。同一套繼承，**預設關**
                    full = { enabled = false, type = "pixel", color = rgba(1, 0.55, 0.2, 1),
                             lines = 8, thickness = 2, frequency = 0.2 },
                },
                -- 淡出後的透明度；false ＝ 這個條件不淡
                -- 淡出：一個透明度；「不淡出的時機」任一成立就維持完整顯示（跟顯示條件的「時機 OR」同一套語彙）；
                -- 騎乘另外一個開關，勾了不看時機一律淡
                fade  = { enabled = true, alpha = 0.3, keepInCombat = true, keepWithTarget = true, whenMounted = false },
                -- 無損刷新（可以續壓的窗口）：邊框換色；bars ＝ 長條的條身也換色
                pandemic = { enabled = true, color = rgba(1, 0.5, 0, 1), bars = true },
                -- 按鍵文字：動作條上綁的鍵，縮寫後畫在圖示一角
                keybind  = { enabled = true, size = 10, point = "TOPRIGHT", x = 1, y = -1, font = "INHERIT" },   -- 預設開、右上（使用者 2026-09-30 指定）
                -- 音效（Core/Sound.lua）：總開關與聲道；要響什麼是逐法術覆寫（readySound／gainSound／loseSound／fullSound／stackSound）。
                -- 不走條層繼承（不在 THEMED 裡），一律用 ns.Setting("theme", "sound.…") 讀
                sound    = { enabled = true, channel = "Master" },
                -- 戰鬥輔助的下一招醒目標示（Core/Assist.lua）：建議的那一招在任何一條上就亮一圈。
                -- 不走條層繼承（不在 THEMED 裡），一律用 ns.Setting("theme", "assist.…") 讀。預設關、不遷移
                assist   = { highlight = false, type = "pixel", color = rgba(0.25, 0.75, 1, 1),
                             lines = 8, thickness = 2, frequency = 0.2 },
            },
            bars = {
                essential = IconBar{ source = "essential", pos = { point = "CENTER", x = 0, y = -202 },
                                     w = 46, h = 40 },
                utility   = IconBar{ source = "utility",   pos = { point = "CENTER", x = 0, y = -250 },
                                     w = 26, h = 24,
                                     anchor = { to = "essential", point = "TOP", relPoint = "BOTTOM",
                                                x = 0, y = -1 } },
                -- 預設在施法條上方（使用者 2026-10-01 指定，不遷移）：錨在核心技能上方，
                -- 排開順序施法條在前 ⇒ 實際貼在施法條外緣；施法條關掉就接到資源條外面
                buffs     = IconBar{ source = "buffs",     pos = { point = "CENTER", x = 0, y = -149 },
                                     w = 40, h = 36, grow = "CENTER_UP",
                                     anchor = { to = "essential", point = "BOTTOM", relPoint = "TOP",
                                                x = 0, y = 1 } },
                buffbars  = buffbars,
            },
            barOrder = { "essential", "utility", "buffs", "buffbars" },   -- 左欄順序，自訂群組接在後面
            spells   = {},                  -- [specID] = { order, groupOf, hidden, overrides, custom }
            -- 自訂項目的寬層（customShared 戰隊層／customClass[classFile] 職業層／customNextUID）刻意**不放預設值**：
            -- 沒有這兩張表 ＝ 只有專精層（舊存檔照舊），第一次加進去時才建（DB.ScopeList）
            resources = ResourcesDefaults(),
            pips      = PipsDefaults(),
            castbar   = CastbarDefaults(),
            assistIcon = AssistIconDefaults(),
        },
    }
end

------------------------------------------------------------
-- 明確 nil-merge：只補 nil、不覆蓋使用者值
------------------------------------------------------------
local function MergeDefaults(dst, src)
    for k, v in pairs(src) do
        local cur = dst[k]
        if type(v) == "table" then
            local fresh = cur == nil
            if fresh then
                cur = {}
                dst[k] = cur
            end
            -- 使用者存了 false（例如 anchor = false）就尊重它，不把預設的表灌進去
            -- Atomic 的表：剛建的才灌，設定檔裡原本就有的（含空表）不碰
            if type(cur) == "table" and (fresh or not ATOMIC[v]) then
                MergeDefaults(cur, v)
            end
        elseif cur == nil then
            dst[k] = v
        end
    end
end
DB.MergeDefaults = MergeDefaults

local function DeepCopy(t)
    local o = {}
    for k, v in pairs(t) do o[k] = type(v) == "table" and DeepCopy(v) or v end
    return o
end
DB.DeepCopy = DeepCopy

local function Wipe(t)
    for k in pairs(t) do t[k] = nil end
    return t
end

-- 長條要不要反向填充（fillDirection：ltr 從左到右／rtl 從右到左）。
-- 缺鍵或不認得的值一律當從左到右。資源條與施法條那一階段會用到。
function ns.FillReversed(edb)
    return type(edb) == "table" and edb.fillDirection == "rtl"
end

------------------------------------------------------------
-- 遷移
--
-- MIGRATIONS[版本] = function(profile) … end：把一份設定檔補到那個版本要做的事。
-- 只動「還是舊預設值」的欄位（值閘），使用者調過的不碰。
-- 匯入字串帶著自己的版本號，走 DB.MigrateProfile 單獨補，不動帳號層的 schemaVersion。
------------------------------------------------------------
local MIGRATIONS = {
    -- v1：初版。沒有舊資料要搬，留著當第一個條目與寫法範本。
    [1] = function(profile) end,
    -- v2（2026-10-02）：施法條材質的預設從純色改成「暴雪施法條」（使用者指定要遷移）。
    -- 值閘：還是舊預設（"solid"）或沒存的才換；玩家選過別的材質（含從另一支插件匯入的）不碰
    [2] = function(profile)
        local cb = profile.castbar
        if type(cb) ~= "table" then return end
        if cb.texture == nil or cb.texture == "solid" then cb.texture = "blizzard" end
    end,
    -- v3（2026-10-02）：資源條「這個專精要顯示哪些」改成分專精存。舊的平面 rows[key] = true／false
    -- 攤到每個「這個 key 是候選」的專精（值跟那個專精的預設不同才寫），平面的鍵拿掉。
    -- 專精 → 候選的資料在 Modules/Resources.lua（R.MigrateFlatRows）：遷移在登入時（DB.Init）／匯入時跑，
    -- 那時 TOC 裡的檔案都載完了。萬一沒有 ns.Resources 就什麼都不動（平面的鍵留著；新版讀 rows[specID]
    -- 時會略過字串鍵，只是那幾個開關回到預設）
    [3] = function(profile)
        local res = profile.resources
        if type(res) ~= "table" or type(res.rows) ~= "table" then return end
        local R = ns.Resources
        if not (R and R.MigrateFlatRows) then return end
        R.MigrateFlatRows(res.rows)
    end,
    -- v4（2026-10-03）：逐法術「持續時間顏色」從三態（false 不換色／色表 條層關著也換）拆成跟主題頁同一套：
    -- colorDuration 開關＋ durationColor 純顏色。行為不變地搬：false → colorDuration=false、顏色清掉；
    -- 色表 → colorDuration=true（原本「條層關著也換」）、顏色留著。已經有 colorDuration 的不碰。
    [4] = function(profile)
        local spells = profile.spells
        if type(spells) ~= "table" then return end
        for _, spec in pairs(spells) do
            local all = type(spec) == "table" and spec.overrides
            if type(all) == "table" then
                for _, o in pairs(all) do
                    if type(o) == "table" then
                        local dc = o.durationColor
                        if dc == false then
                            if o.colorDuration == nil then o.colorDuration = false end
                            o.durationColor = nil
                        elseif type(dc) == "table" and o.colorDuration == nil then
                            o.colorDuration = true
                        end
                    end
                end
            end
        end
    end,
}
DB.MIGRATIONS = MIGRATIONS

function DB.MigrateProfile(profile, fromVersion)
    if type(profile) ~= "table" then return end
    local from = tonumber(fromVersion) or 0
    for v = from + 1, ns.DB_VERSION do
        local step = MIGRATIONS[v]
        if step then
            local ok, err = pcall(step, profile)
            if not ok and ns.ReportError then ns.ReportError(err) end
        end
    end
end

function DB.Migrate(sv)
    -- 起點取 max(目前版本, 曾經看過的最高版本)：跑過新版又退版、再升回來時，
    -- 那幾步已經生效過，重跑會把玩家在新版刻意調回去的值又改掉。
    local seen = math.max(sv.schemaVersion or 0, sv.schemaVersionSeen or 0)
    for _, profile in pairs(sv.profiles or {}) do
        DB.MigrateProfile(profile, seen)
    end
end

------------------------------------------------------------
-- 角色與設定檔
------------------------------------------------------------
local function CharKey()
    return (UnitName("player") or "?") .. " - " .. (GetRealmName() or "?")
end
DB.CharKey = CharKey

local function SV() return MiliUI_CooldownManager_DB end

function DB.Init()
    local fresh = type(MiliUI_CooldownManager_DB) ~= "table"
    if fresh then MiliUI_CooldownManager_DB = {} end
    local sv = MiliUI_CooldownManager_DB

    if fresh or sv.schemaVersion == nil then
        -- 全新的 SV 不必跑遷移：預設值本來就是最新的形狀
        sv.schemaVersion = ns.DB_VERSION
    elseif sv.schemaVersion > ns.DB_VERSION then
        -- 來自較新版：對齊到目前版本，但記住看過第幾版（見 DB.Migrate）
        sv.schemaVersionSeen = math.max(sv.schemaVersionSeen or 0, sv.schemaVersion)
        sv.schemaVersion = ns.DB_VERSION
    elseif sv.schemaVersion < ns.DB_VERSION then
        DB.Migrate(sv)
        sv.schemaVersion = ns.DB_VERSION
    end
    if (sv.schemaVersionSeen or 0) < sv.schemaVersion then
        sv.schemaVersionSeen = sv.schemaVersion
    end

    sv.profiles     = sv.profiles or {}
    sv.profileKeys  = sv.profileKeys or {}
    sv.specProfiles = sv.specProfiles or {}
    sv.charClasses  = sv.charClasses or {}

    local key = CharKey()
    sv.charClasses[key] = ns.playerClass

    local defaults = DB.BuildDefaults()
    MergeDefaults(sv, defaults.account)

    -- 綁了專精就照專精挑，否則照這隻角色上次用的那份
    local name = DB.ProfileForSpec(ns.specIndex) or sv.profileKeys[key]
    if type(name) ~= "string" or not sv.profiles[name] then
        name = DB.DEFAULT_PROFILE
    end
    sv.profiles[name] = sv.profiles[name] or {}
    sv.profileKeys[key] = name
    return DB.Activate(name)
end

------------------------------------------------------------
-- 啟用一份設定檔：補預設值 → 重指 ns.profile → 記名字。
-- 登入與換設定檔走同一支，兩條路不會漂掉。
--
-- ⚠ 合併一定要在這裡跑，不能只在登入時對目前那份跑：別份設定檔可能是在某個鍵
-- 加進預設值**之前**建的，切過去會缺鍵。
------------------------------------------------------------
function DB.Activate(name)
    local sv = SV()
    local p = sv and sv.profiles and sv.profiles[name]
    if not p then return nil end
    MergeDefaults(p, DB.BuildDefaults().profile)
    ns.sv, ns.profile, ns.profileName = sv, p, name
    DB.TouchCustom()                      -- 換了一整份設定檔：讀取端的 memo 全部作廢
    return p
end

-- name 省略 ＝ 目前這份
function DB.GetProfile(name)
    if name == nil then return ns.profile end
    local sv = SV()
    return sv and sv.profiles and sv.profiles[name]
end

function DB.ListProfiles()
    local out = {}
    for name in pairs((SV() or {}).profiles or {}) do out[#out + 1] = name end
    table.sort(out)
    return out
end

local function CleanName(name)
    if type(name) ~= "string" then return "" end
    return (name:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- 從預設值建一份新的
function DB.CreateProfile(name)
    name = CleanName(name)
    if name == "" then return false, "empty" end
    local sv = SV()
    if sv.profiles[name] then return false, "exists" end
    sv.profiles[name] = DeepCopy(DB.BuildDefaults().profile)
    return true, name
end

-- 從現有的一份複製出新的（兩份絕不共用子表）
function DB.CopyProfile(from, to)
    to = CleanName(to)
    if to == "" then return false, "empty" end
    local sv = SV()
    local src = sv.profiles[from]
    if not src then return false, "nosource" end
    if sv.profiles[to] then return false, "exists" end
    sv.profiles[to] = DeepCopy(src)
    return true, to
end

-- 刪掉指定那份。預設那份不給刪；指著它的角色／專精一律改回預設。
function DB.DeleteProfile(name)
    local sv = SV()
    if name == DB.DEFAULT_PROFILE or not sv.profiles[name] then return false end
    sv.profiles[name] = nil
    for k, v in pairs(sv.profileKeys) do
        if v == name then sv.profileKeys[k] = DB.DEFAULT_PROFILE end
    end
    for _, map in pairs(sv.specProfiles) do
        for idx, v in pairs(map) do
            if v == name then map[idx] = nil end
        end
    end
    if ns.profileName == name then DB.SwitchProfile(DB.DEFAULT_PROFILE) end
    return true
end

------------------------------------------------------------
-- 換設定檔：一律即時生效，不重載（沒有任何選項需要 /reload）
--
-- 引擎與設定介面都透過 ns.Setting 讀當下的 ns.profile，沒有人抓著舊表的參照，
-- 所以換指標之後廣播 "ProfileChanged" 讓各模組重套即可。
-- 戰鬥中整個延到脫戰（重套會動到容器層），不做「一半即時一半排隊」。
------------------------------------------------------------
local pendingProfile
local profileWatcher = CreateFrame("Frame")
profileWatcher:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local name = pendingProfile
    pendingProfile = nil
    if name then DB.SwitchProfile(name) end
end)

function DB.SwitchProfile(name)
    local sv = SV()
    if not (sv and sv.profiles and sv.profiles[name]) then return false end
    sv.profileKeys[CharKey()] = name        -- 永遠要記（下次登入靠它認得回來）
    if name == ns.profileName then
        -- 戰鬥中先選了 B（排隊）又改回目前這份：排隊的要取消，否則脫戰會跳到 B
        if pendingProfile then
            pendingProfile = nil
            profileWatcher:UnregisterEvent("PLAYER_REGEN_ENABLED")
        end
        return true
    end
    if InCombatLockdown() then
        pendingProfile = name
        profileWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
        return true
    end
    DB.Activate(name)
    ns.Fire("ProfileChanged", name)
    return true
end

------------------------------------------------------------
-- 設定檔綁專精
--
-- specProfiles[角色] = { enabled = bool, [專精序號] = 設定檔名 }
-- 用專精**序號**（1-4）而不是 specID：這張表是逐角色的，序號在同一隻角色上是固定的，
-- 設定介面也直接照序號列出來。
------------------------------------------------------------
local function SpecMap(create)
    local sv = SV()
    local key = CharKey()
    local map = sv.specProfiles[key]
    if not map and create then
        map = { enabled = false }
        sv.specProfiles[key] = map
    end
    return map
end

function DB.IsSpecProfilesEnabled()
    local map = SpecMap(false)
    return map and map.enabled == true or false
end

function DB.SetSpecProfilesEnabled(on)
    SpecMap(true).enabled = on and true or false
    if on then DB.ApplySpecProfile() end
end

-- name = nil 清掉那個專精的綁定
function DB.SetSpecProfile(specIndex, name)
    if type(specIndex) ~= "number" then return false end
    if name ~= nil and not SV().profiles[name] then return false end
    SpecMap(true)[specIndex] = name
    if specIndex == ns.specIndex then DB.ApplySpecProfile() end
    return true
end

-- 這個專精綁了哪份（沒開、沒綁、或那份已經不存在 → nil）
function DB.ProfileForSpec(specIndex)
    if type(specIndex) ~= "number" then return nil end
    local map = SpecMap(false)
    if not (map and map.enabled) then return nil end
    local name = map[specIndex]
    if type(name) == "string" and SV().profiles[name] then return name end
    return nil
end

function DB.ApplySpecProfile()
    local name = DB.ProfileForSpec(ns.specIndex)
    if name and name ~= ns.profileName then DB.SwitchProfile(name) end
end

local function OnSpecMaybeChanged()
    local before = ns.specID
    ns.RefreshSpec()
    if ns.specID == before then return end
    DB.TouchCustom()                      -- 專精換了：「目前專精」的覆寫／自訂清單是另一張表
    DB.ApplySpecProfile()
    ns.Fire("SpecChanged", ns.specID)
end

if ns.Events then
    ns.Events.Register("PLAYER_SPECIALIZATION_CHANGED", "db_spec", OnSpecMaybeChanged, "player")
    -- 新角色／剛登入時 GetSpecialization() 可能還是 nil，而之後不一定會補一發
    -- PLAYER_SPECIALIZATION_CHANGED ⇒ 進場時再對一次（沒變就什麼都不做）
    ns.Events.Register("PLAYER_ENTERING_WORLD", "db_spec", OnSpecMaybeChanged)
end

------------------------------------------------------------
-- 取值：ns.Setting(barKey, path) ／ ns.SpellSetting(barKey, cooldownID, key)
--
-- **引擎與設定介面一律走這兩支，不准各自去翻表。** 三層繼承，沒有複製：
--
--   theme ──(條的 follow 那一項 ≠ false)──▶ bars[barKey] ──▶ spells[spec].overrides[id]
--
-- path 是點分字串，**用主題的形狀寫**（"cooldownText.size"、"border.color"、
-- "glow.proc.type"、"icon.zoom"、"fade.alpha"），不管條把它存在哪張子表：
--
--   第一段           跟著 follow 的哪一項   條自己存在
--   font／outline     text                  bars[k].text.<path>
--   cooldownText／chargeText／stackText
--                     text                  bars[k].text.<path>
--   border            icon                  bars[k].icon.<path>
--   icon              icon                  bars[k].<path>（icon.zoom → bars[k].icon.zoom）
--   glow              glow                  bars[k].<path>
--   pandemic／keybind glow                  bars[k].glow.<path>
--   fade              fade                  bars[k].<path>
--   其他（layout、pos、anchor、visibility、bar、kind…）
--                     不繼承                 bars[k].<path>
--
-- 條沒跟隨、但自己那一格沒存值 → 退回 theme。所以關掉「跟隨全域」的當下什麼都不會變，
-- 玩家改了哪一格才有哪一格。barKey 給 nil 或 "theme" ＝ 直接讀主題（主題頁用）。
--
-- 回傳的表（顏色、尺寸）是設定本身的參照，**唯讀**。要改走設定介面的寫入路徑。
------------------------------------------------------------
local THEMED = {
    font         = { follow = "text", sub = "text" },
    outline      = { follow = "text", sub = "text" },
    cooldownText = { follow = "text", sub = "text" },
    chargeText   = { follow = "text", sub = "text" },
    stackText    = { follow = "text", sub = "text" },
    border       = { follow = "icon", sub = "icon" },
    icon         = { follow = "icon" },
    glow         = { follow = "glow" },
    pandemic     = { follow = "glow", sub = "glow" },
    keybind      = { follow = "glow", sub = "glow" },
    fade         = { follow = "fade" },
}
DB.THEMED = THEMED

local splitCache = {}
local function Split(path)
    local segs = splitCache[path]
    if not segs then
        segs = {}
        for seg in string.gmatch(path, "[^%.]+") do segs[#segs + 1] = seg end
        splitCache[path] = segs
    end
    return segs
end

local function Dig(t, segs)
    for i = 1, #segs do
        if type(t) ~= "table" then return nil end
        t = t[segs[i]]
    end
    return t
end

function ns.Setting(barKey, path)
    local p = ns.profile
    if not p or type(path) ~= "string" then return nil end
    local segs = Split(path)
    local theme = p.theme
    if barKey == nil or barKey == "theme" then return Dig(theme, segs) end

    local bar = p.bars and p.bars[barKey]
    local group = THEMED[segs[1]]
    if not group then return Dig(bar, segs) end      -- 條自己的欄位，不繼承

    if type(bar) == "table" then
        local follow = bar.follow
        if type(follow) == "table" and follow[group.follow] == false then
            local v
            if group.sub then v = Dig(bar[group.sub], segs) else v = Dig(bar, segs) end
            if v ~= nil then return v end
        end
    end
    return Dig(theme, segs)
end

-- 逐法術覆寫可以蓋掉的欄位 → 沒覆寫時退回條層的哪個 path
local SPELL_FALLBACK = {
    borderColor = "border.color",
    procGlow    = "glow.proc.enabled",
    readyGlow   = "glow.ready.enabled",
    -- 生效期間發光：跟觸發／就緒同一套（條層開關預設關，逐法術蓋）
    activeGlow  = "glow.active.enabled",
    -- 充能滿了發光：同一套（條層開關預設關，逐法術蓋）
    fullGlow    = "glow.full.enabled",
    -- 就緒發光亮多久（timed／untilUsed／whileReady）與資源檢查：逐法術可以蓋（Core/Glow.lua 的 ReadyMode／RequireUsable）
    readyGlowMode   = "glow.ready.mode",
    readyGlowUsable = "glow.ready.requireUsable",
    desaturate  = "icon.desaturateOnCooldown",
    -- 冷卻狀態：逐法術可以蓋模式；變暗的透明度逐法術沒有控件（吃條的值），欄位照樣登記
    cdState      = "icon.cdState",
    cdStateAlpha = "icon.cdStateAlpha",
    -- 增益持續時間那一段的換色（逐法術跟條層同一套五個欄位、同一套連動，Core/Decorate.lua 的 SpellStyle）：
    --   colorDuration      三態 nil 跟隨條／true 換色／false 不換色（引擎讀 SpellSetting 的布林）
    --   durationColor      色表＝這一招的字色；nil 跟隨條
    --   durationLowColor   色表＝這一招的低秒字色；nil 跟隨條
    --   durationSwipeColor 色表＝這一招的轉圈背景色；nil 跟隨條
    -- 三個顏色只在「顯示增益持續時間」與「換色」都生效時才用得上（跟主題頁的停用規則一樣）。
    -- （v4 之前 durationColor 兼作開關：false ＝ 不換色、色表 ＝ 條層關著也換；MIGRATIONS[4] 拆成 colorDuration）
    colorDuration      = "icon.colorDuration",
    durationColor      = "icon.durationColor",
    durationLowColor   = "icon.durationLowColor",
    durationSwipeColor = "icon.durationSwipeColor",
    -- 增益持續中顯示持續時間：nil 跟隨條／true 顯示／false 不顯示（引擎讀 SpellSetting 的布林，
    -- 設定頁要三態走 ns.SpellOverride）
    showAuraTime  = "icon.showAuraTime",
    -- 沒有物品時隱藏（自訂物品）／被動飾品不顯示（飾品欄、代畫格）：nil 跟隨條／true／false（Core/Catalog.lua 的 HideReason）
    hideNoItem         = "icon.hideNoItem",
    hidePassiveTrinket = "icon.hidePassiveTrinket",
}
-- 沒有條層對應的覆寫欄位 → 固定預設
local SPELL_CONST = {
    hideCooldownText = false,
    hideStackText    = false,
    -- 生效發光脫戰也亮（預設）；false ＝ 只在戰鬥中亮。自訂光環格不適用（發光烘在受保護的按鈕裡）
    activeGlowOutOfCombat = true,
    -- 層數門檻（暴雪的增益 item 才有，Core/StackGate.lua）：stackGlow ＝ 門檻 N（1～99）、stackColors ＝
    -- { { at, color }, … } 最多 5 筆（增益長條）。false ＝ 關；樣式／顏色（stackGlowType／stackGlowColor）
    -- 沒設（nil）＝ glow.active 的預設
    stackGlow        = false,
    stackColors      = false,
    -- 層數發光的比較子（F4）：">=" | "<=" | "==" | ">" | "<"；沒覆寫 ＝ ">="（舊存檔的「到 N 以上」不變）。
    -- 只影響層數發光；層數換色維持「到 N 以上」
    stackGlowOp      = ">=",
    -- 增益長條的層數當填充（{ max = N }）與層數刻度（{ at = {…}|"all", max = N, color }）；false ＝ 關
    stackBar         = false,
    stackTicks       = false,
    -- 音效：LibSharedMedia 的音效名；沒設（nil）或 false ＝ 無
    readySound       = false,
    gainSound        = false,
    loseSound        = false,
    -- 充能滿音效（充能技能每一層都回滿的那一刻）、層數增加音效（增益每多一層；引擎播，AddAuraSound）
    fullSound        = false,
    stackSound       = false,
    -- 語音播報（文字轉語音，Core/Sound.lua）：false ＝ 關、true ＝ 念法術名、字串 ＝ 念那段字（空字串也念法術名）。
    -- 層數增加音效沒有語音播報（引擎播的，Lua 端沒有訊號）
    readySpeak       = false,
    gainSpeak        = false,
    loseSpeak        = false,
    fullSpeak        = false,
    -- 自訂圖示：貼圖檔案編號（正整數）；false ＝ 用原本的圖示（Core/Decorate.lua 的 IconOverrideOf）
    customIcon       = false,
    -- 效果不在時變暗（只有逐法術、預設不勾；暴雪的冷卻格才有效，Core/Decorate.lua）：
    -- 圖示沒在倒增益／減益時間就變暗（變暗程度吃條的 cdStateAlpha）
    dimNoAura        = false,
    -- 以增益取代（核心／輔助的暴雪技能才有，Core/Catalog.lua 的 Replacements）：增益圖示列的 cooldownID；
    -- false ＝ 不取代
    replaceWith      = false,
    -- 以增益取代時，頂著這一格的增益用這一招的增益時間樣式（colorDuration／三個顏色，跟這一招自己先倒增益那段同一套）；
    -- false ＝ 照增益原本的倒數樣式（不換色）
    replaceAuraStyle = true,
    -- 無增益時保留空位（暴雪的增益圖示／增益長條的 item 才有，Core/Bars.lua 的 Relayout／Occupancy，F7）：
    -- true ＝ 增益不在時那一格照留、畫占位（長條類照條的 layout.emptyStyle），跟固定格位同一條路；false ＝ 收合。
    -- 條的固定格位開著／被強制時每一格本來就保留，這個勾不起作用。（光環格的占位存在那一筆自訂項目上，不是這個欄位）
    placeholder      = false,
}
DB.SPELL_FALLBACK, DB.SPELL_CONST = SPELL_FALLBACK, SPELL_CONST

-- cooldownID：暴雪類別裡的項目用數字 cooldownID，自訂項目用 "c:<index>"（專精層）／"k:<uid>"（職業層）／
-- "w:<uid>"（戰隊層），見下面「自訂項目」。
-- ⚠ 它會拿來當 table key ⇒ 只能是從 C_CooldownViewer 讀到的明文，**不准是秘密值**。
-- specID 省略 ＝ 目前的專精。
-- 覆寫存在哪：暴雪的項目與專精層的自訂項目在 spells[specID].overrides[id]；職業層／戰隊層的自訂項目
-- **跟著那一筆走**（entry.overrides），所有看得到它的專精讀同一份（DB.OverrideTable 是唯一分流點）。
-- 只讀覆寫本身（沒覆寫 ＝ nil，不退回條層）：要分得出「跟隨」與「覆寫成跟條一樣的值」的地方用
function ns.SpellOverride(cooldownID, key, specID)
    if not ns.profile then return nil end
    local o = DB.OverrideTable(cooldownID, false, specID)
    if type(o) == "table" then return o[key] end
    return nil
end

function ns.SpellSetting(barKey, cooldownID, key, specID)
    if not ns.profile then return nil end
    local v = ns.SpellOverride(cooldownID, key, specID)
    if v ~= nil then return v end
    local path = SPELL_FALLBACK[key]
    if path then return ns.Setting(barKey, path) end
    return SPELL_CONST[key]
end

-- 沒覆寫時這個欄位的值從哪來（單一法術小窗的「（跟隨…）」用）：
--   "theme" 條在這一節跟隨全域主題／"bar" 條在這一節用自己的值／nil 沒有可跟隨的（固定預設）
function DB.SpellFallbackSource(barKey, field)
    local path = SPELL_FALLBACK[field]
    if not path then return nil end
    if barKey == nil or barKey == "theme" then return "theme" end
    local group = THEMED[Split(path)[1]]
    local bar = ns.profile and ns.profile.bars and ns.profile.bars[barKey]
    local follow = type(bar) == "table" and bar.follow
    if group and type(follow) == "table" and follow[group.follow] == false then return "bar" end
    return "theme"
end

------------------------------------------------------------
-- 恢復預設（原地清空再灌：各處抓著的是這張表的參照）
------------------------------------------------------------
function DB.ResetProfile()
    local p = ns.profile
    if not p then return end
    Wipe(p)
    MergeDefaults(p, DB.BuildDefaults().profile)
    DB.TouchCustom()
    ns.Fire("ProfileChanged", ns.profileName)
end

------------------------------------------------------------
-- 設定介面的寫入路徑
--
-- 讀值一律走 ns.Setting；**寫**條上的主題欄位要照 THEMED 決定落在哪張子表，
-- 這裡是唯一知道的地方（設定介面、測試都走這幾支，不各自翻表）。
--
--   DB.GetPath(t, path) / DB.SetPath(t, path, v)   點分路徑，SetPath 沿路補表
--   DB.OwnGet(barKey, path)       條「自己存的」那一格（沒存 → nil，不退回主題）
--   DB.OwnSet(barKey, path, v)    寫條自己的那一格；v = nil ＝ 清掉、改回跟主題
--   DB.DefaultFor(root, barKey, path)   預設值（右鍵「重設為預設」用；回傳複本）
------------------------------------------------------------
function DB.GetPath(t, path)
    if type(path) ~= "string" then return nil end
    return Dig(t, Split(path))
end

function DB.SetPath(t, path, v)
    if type(t) ~= "table" or type(path) ~= "string" then return false end
    local segs = Split(path)
    for i = 1, #segs - 1 do
        local k = segs[i]
        if type(t[k]) ~= "table" then t[k] = {} end
        t = t[k]
    end
    t[segs[#segs]] = v
    return true
end

-- 條上存這個 path 的完整路徑（主題欄位多一層子表），不是主題欄位回原 path
function DB.BarStoragePath(path)
    local first = type(path) == "string" and path:match("^[^%.]+")
    local group = first and THEMED[first]
    if group and group.sub then return group.sub .. "." .. path end
    return path
end

local function BarTable(barKey)
    local p = ns.profile
    local b = p and type(p.bars) == "table" and p.bars[barKey]
    return type(b) == "table" and b or nil
end
DB.BarTable = BarTable

function DB.OwnGet(barKey, path)
    return DB.GetPath(BarTable(barKey), DB.BarStoragePath(path))
end

function DB.OwnSet(barKey, path, v)
    local bar = BarTable(barKey)
    if not bar then return false end
    return DB.SetPath(bar, DB.BarStoragePath(path), v)
end

local BUILTIN = { essential = true, utility = true, buffs = true, buffbars = true }
function DB.IsBuiltinBar(key) return BUILTIN[key] == true end

-- 「可點擊」的唯一判準（Bars／設定頁／Core/Clickable.lua 都問這支）：只有自訂的圖示群組。
-- 內建條與長條型群組有這欄也不讀（nil 當 false，不做遷移）
function DB.BarClickable(key)
    local b = BarTable(key)
    return (b ~= nil and b.kind == "icons" and b.source == "custom" and b.clickable == true) and true or false
end

-- 「面板」：資源條、自訂格子、施法條與下一招圖示。不在 bars 裡、有自己的設定頁（自訂格子在資源條頁、
-- 下一招圖示在戰鬥輔助頁），但錨定／位置／編輯模式跟條同一套。
-- ⚠ key 是存檔內容（別的條的 anchor.to 會指向它），不要改名。
local PANEL_KEYS = { resources = true, pips = true, castbar = true, assistIcon = true }
DB.PANEL_KEYS = PANEL_KEYS
ns.PANEL_KEYS = PANEL_KEYS
-- 順序有意義：顯示條件照這個順序套、錨定候選照這個順序列（下一招圖示排最後）
DB.PANEL_ORDER = { "resources", "pips", "castbar", "assistIcon" }
function DB.IsPanel(key) return PANEL_KEYS[key] == true end

-- 條或面板的設定表（錨定、位置、編輯模式、設定頁的 root "bar" 一律走這支）
function DB.ConfigTable(key)
    if PANEL_KEYS[key] then
        local p = ns.profile
        local t = p and p[key]
        return type(t) == "table" and t or nil
    end
    return BarTable(key)
end

local function CopyValue(v)
    if type(v) == "table" then return DeepCopy(v) end
    return v
end

-- root：
--   "theme" 在主題頁 ＝ 主題的預設；在條頁（barKey 給了）＝ nil（條沒存 ＝ 跟主題）
--   "bar"   條自己的欄位：四條檢視器照預設值、自訂群組照 NewBarTable
function DB.DefaultFor(root, barKey, path)
    local d = DB.BuildDefaults().profile
    if root == "theme" then
        if barKey == nil or barKey == "theme" then return CopyValue(DB.GetPath(d.theme, path)) end
        return nil
    end
    local ref = PANEL_KEYS[barKey] and d[barKey] or d.bars[barKey]
    if not ref then
        local bar = BarTable(barKey)
        ref = DB.NewBarTable(bar and bar.kind or "icons", bar and bar.name)
    end
    return CopyValue(DB.GetPath(ref, path))
end

------------------------------------------------------------
-- 自訂群組
------------------------------------------------------------
function DB.NextBarKey()
    local p = ns.profile
    local bars = p and p.bars or {}
    local n = 1
    while bars["g" .. n] ~= nil do n = n + 1 end
    return "g" .. n
end

-- 新增：kind = "icons" | "bars"。回傳 key
function DB.CreateBar(kind, name)
    local p = ns.profile
    if not p then return nil end
    local key = DB.NextBarKey()
    p.bars[key] = DB.NewBarTable(kind == "bars" and "bars" or "icons", CleanName(name))
    p.barOrder = type(p.barOrder) == "table" and p.barOrder or {}
    p.barOrder[#p.barOrder + 1] = key
    return key
end

-- 刪除：四條檢視器不給刪。指向它的 groupOf、它的排序、錨在它身上的條一併處理
-- （錨在它身上的條改成不錨定；位置由呼叫端先換算好寫進 pos，這裡不碰畫面）
function DB.DeleteBar(key)
    local p = ns.profile
    if not p or BUILTIN[key] or type(p.bars) ~= "table" or not p.bars[key] then return false end
    for _, spec in pairs(type(p.spells) == "table" and p.spells or {}) do
        if type(spec) == "table" then
            if type(spec.groupOf) == "table" then
                for id, g in pairs(spec.groupOf) do
                    if g == key then spec.groupOf[id] = nil end
                end
            end
            if type(spec.order) == "table" then spec.order[key] = nil end
        end
    end
    -- 自訂項目沒有「原本的暴雪那條」可以回去：光環格（含飾品欄增益）回增益圖示、法術／物品回核心技能（三層都是）
    local function Rehome(list)
        for _, e in ipairs(list) do
            if type(e) == "table" and e.bar == key then
                e.bar = (e.kind == "aura" or e.kind == "slotbuff") and "buffs" or "essential"
            end
        end
    end
    for _, spec in pairs(type(p.spells) == "table" and p.spells or {}) do
        if type(spec) == "table" and type(spec.custom) == "table" then Rehome(spec.custom) end
    end
    DB.EachWideList(p, Rehome)          -- 定義在下面「自訂項目」那一節
    DB.TouchCustom()                    -- groupOf／order 與自訂項目的 bar 都可能改了
    for other, bar in pairs(p.bars) do
        if other ~= key and type(bar) == "table" and type(bar.anchor) == "table" and bar.anchor.to == key then
            bar.anchor = false
        end
        -- 溢出到它的條：目標清掉（＝不限顆數）。群組的 key 會被下一個新群組重用（NextBarKey），留著會指到新的那條
        if other ~= key and type(bar) == "table" and type(bar.layout) == "table" and bar.layout.overflowTo == key then
            bar.layout.overflowTo = false
        end
    end
    for pk in pairs(PANEL_KEYS) do
        local t = p[pk]
        if type(t) == "table" and type(t.anchor) == "table" and t.anchor.to == key then t.anchor = false end
    end
    p.bars[key] = nil
    if type(p.barOrder) == "table" then
        for i = #p.barOrder, 1, -1 do
            if p.barOrder[i] == key then table.remove(p.barOrder, i) end
        end
    end
    return true
end

-- 錨定成環：key 錨到 to 之後，沿著 to 的錨定鏈會不會走回 key
function DB.AnchorWouldCycle(key, to)
    local seen, cur = { [key] = true }, to
    while cur do
        if seen[cur] then return true end
        seen[cur] = true
        local b = DB.ConfigTable(cur)
        local a = type(b) == "table" and b.anchor
        cur = (type(a) == "table" and type(a.to) == "string") and a.to or nil
    end
    return false
end

------------------------------------------------------------
-- 逐專精的法術表：spells[specID] = { order, groupOf, hidden, overrides, custom }
------------------------------------------------------------
-- create ＝ 呼叫端要寫 ⇒ 這裡就是作廢點（DB.overrideGen）；只讀一律傳 false
function DB.SpecSpells(create, specID)
    local p = ns.profile
    specID = specID or ns.specID
    if not (p and specID) then return nil end
    if create then DB.TouchOverrides() end
    if type(p.spells) ~= "table" then
        if not create then return nil end
        p.spells = {}
    end
    local sp = p.spells[specID]
    if type(sp) ~= "table" then
        if not create then return nil end
        sp = {}
        p.spells[specID] = sp
    end
    if create then
        for _, k in ipairs({ "order", "groupOf", "hidden", "overrides" }) do
            if type(sp[k]) ~= "table" then sp[k] = {} end
        end
    end
    return sp
end

-- 覆寫欄位 → 設定頁的哪一節（「本條 N 個法術有覆寫」「清除覆寫」用）
DB.OVERRIDE_GROUP = {
    borderColor = "icon", desaturate = "icon", cdState = "icon", cdStateAlpha = "icon", customIcon = "icon",
    showAuraTime = "icon", dimNoAura = "icon",
    -- 沒有物品時隱藏／被動飾品不顯示：條層的開關在「圖示」節 ⇒ 同一組（條頁「清除圖示覆寫」一起清，回到條層的值）
    hideNoItem = "icon", hidePassiveTrinket = "icon",
    -- 以增益取代：決定格子放誰，不是外觀 ⇒ 自成一組（條頁「清除外觀覆寫」不會把它清掉；跟天賦條件同一個理由）
    replaceWith = "replace", replaceAuraStyle = "replace",
    procGlow = "glow", readyGlow = "glow", readyGlowMode = "glow", readyGlowUsable = "glow",
    -- 生效發光跟觸發／就緒同一組（2026-10-03 改成同一套繼承）；activeGlowColor／activeGlowType 是舊存檔的殘留，
    -- 留在這一組讓「清除發光覆寫」順手清掉
    activeGlow = "glow", activeGlowColor = "glow", activeGlowType = "glow", activeGlowOutOfCombat = "glow",
    fullGlow = "glow",
    -- 層數門檻也是逐法術挑的：自成一組，條頁「清除發光覆寫」不會清掉
    stackGlow = "stack", stackGlowType = "stack", stackGlowColor = "stack", stackColors = "stack",
    stackGlowOp = "stack", stackBar = "stack", stackTicks = "stack",
    hideCooldownText = "text", hideStackText = "text",
    colorDuration = "icon", durationColor = "icon", durationLowColor = "icon", durationSwipeColor = "icon",
    -- 音效在條頁自成一節（「音效」：本條 N 個法術有音效、清除），不跟發光算在一起：
    -- 清發光覆寫不該順手把玩家挑好的音效清掉
    readySound = "sound", gainSound = "sound", loseSound = "sound", fullSound = "sound", stackSound = "sound",
    -- 語音播報跟音效同一節（同一個觸發點、同一個總開關）
    readySpeak = "sound", gainSpeak = "sound", loseSpeak = "sound", fullSpeak = "sound",
    -- 天賦條件（Core/Catalog.lua，{ spellID, mode }）：決定格子在不在，不是外觀；自成一組，清外觀覆寫不會清掉它
    talentCond = "talent",
    -- 無增益時保留空位（F7）：決定格子在不在，不是外觀；自成一組，清外觀覆寫不會清掉它
    placeholder = "slot",
}

-- 某個 id 的覆寫表（{ 欄位 = 值 }）。唯一的分流點：
--   職業層／戰隊層的自訂項目（"k:"／"w:"）→ 那一筆自己身上的 entry.overrides
--   其餘（暴雪的數字 id、專精層的 "c:"）→ spells[specID].overrides[id]
-- create ＝ 沒有就建（那一筆不存在時照樣回 nil），也是「呼叫端要寫」的宣告 ⇒ DB.overrideGen 的作廢點。
-- 只回表（2026-10-04 之前第二個回傳值是「拿掉這張表」的閉包：每次讀覆寫都配置一個，SpellStyle 一次讀十幾個）；
-- 整張拿掉改叫 DB.DropOverrideTable。
function DB.OverrideTable(cooldownID, create, specID)
    if cooldownID == nil then return nil end
    local scope = DB.ParseCustomID(cooldownID)
    if scope == "class" or scope == "shared" then
        local e = DB.CustomEntry(cooldownID)
        if type(e) ~= "table" then return nil end
        if create then DB.TouchOverrides() end
        if type(e.overrides) ~= "table" then
            if not create then return nil end
            e.overrides = {}
        end
        return e.overrides
    end
    local sp = DB.SpecSpells(create, specID)       -- create ⇒ SpecSpells 已經 +1
    local all = sp and type(sp.overrides) == "table" and sp.overrides
    if not all then return nil end
    local o = all[cooldownID]
    if type(o) ~= "table" then
        if not create then return nil end
        o = {}
        all[cooldownID] = o
    end
    return o
end

-- 某個 id 的覆寫表整張拿掉（OverrideTable 的分流照抄：寬層的自訂項目拿掉那一筆身上的，其餘拿掉專精表裡的）
function DB.DropOverrideTable(cooldownID, specID)
    if cooldownID == nil then return end
    local scope = DB.ParseCustomID(cooldownID)
    if scope == "class" or scope == "shared" then
        local e = DB.CustomEntry(cooldownID)
        if type(e) == "table" and e.overrides ~= nil then
            e.overrides = nil
            DB.TouchOverrides()
        end
        return
    end
    local sp = DB.SpecSpells(false, specID)
    local all = sp and type(sp.overrides) == "table" and sp.overrides
    if all and all[cooldownID] ~= nil then
        all[cooldownID] = nil
        DB.TouchOverrides()
    end
end

-- v = nil 清掉那一格；整張空了就拿掉
function DB.SetOverride(cooldownID, field, v)
    if cooldownID == nil then return false end
    local o = DB.OverrideTable(cooldownID, v ~= nil)
    if not o then
        -- 清一個本來就沒有的覆寫 ＝ 成功（那一筆不存在時照舊回 false）
        if v ~= nil then return false end
        local scope = DB.ParseCustomID(cooldownID)
        if scope == "class" or scope == "shared" then return DB.CustomEntry(cooldownID) ~= nil end
        local sp = DB.SpecSpells(false)
        return sp ~= nil and type(sp.overrides) == "table"
    end
    o[field] = v
    DB.TouchOverrides()                   -- 清掉（v = nil）那條路沒有經過 create
    if next(o) == nil then DB.DropOverrideTable(cooldownID) end
    return true
end

-- 某個 id 的覆寫整張拿掉（單一法術小窗的「還原此法術」）
function DB.ResetOverrides(cooldownID)
    DB.DropOverrideTable(cooldownID)
end

-- 某個 id 有沒有任何覆寫
function DB.HasOverrides(cooldownID)
    local o = DB.OverrideTable(cooldownID, false)
    return o ~= nil and next(o) ~= nil
end

local function InGroup(field, group)
    return group == nil or DB.OVERRIDE_GROUP[field] == group
end

function DB.CountOverrides(ids, group)
    local n = 0
    for _, id in ipairs(ids or {}) do
        local o = DB.OverrideTable(id, false)
        if type(o) == "table" then
            for field in pairs(o) do
                if InGroup(field, group) then n = n + 1; break end
            end
        end
    end
    return n
end

function DB.ClearOverrides(ids, group)
    for _, id in ipairs(ids or {}) do
        local o = DB.OverrideTable(id, false)
        if type(o) == "table" then
            for field in pairs(o) do
                if InGroup(field, group) then o[field] = nil end
            end
            DB.TouchOverrides()
            if next(o) == nil then DB.DropOverrideTable(id) end
        end
    end
end

------------------------------------------------------------
-- 自訂項目：spells[specID].custom = { { kind, spellID|itemID, filter, placeholder, bar }, … }
--
--   kind         "aura"（光環格）| "spell"（法術冷卻）| "item"（物品冷卻）| "slot"（裝備欄位：slot = 13／14，追蹤裝在那一格的物品）
--                | "slotbuff"（飾品欄增益：slot = 13／14、buff = N（暴雪的 buffSlot，正整數、不設上限、缺 ＝ 1），
--                  那件飾品第 N 個增益生效時才出現的光環格；身分「slotbuff:<slot>:<N>」，同一層同槽同 N 只能一筆）
--   filter       光環格才有："HELPFUL" | "HARMFUL"
--   placeholder  光環格才有：光環不在時畫去飽和的占位圖示
--   bar          放在哪一條（只收圖示類的條）
--   alts         物品才有（選用）：替代品 { itemID, … }，顯示「主＋alts」裡第一個包包裡有的（Modules/Custom.lua）
--   spellIDs     光環格才有（選用，只認增益）：主 ID 以外也算這一格的法術 { spellID, … }
--   ⚠ 兩個選用欄位舊存檔都沒有 ＝ 行為跟以前一樣；判重（FindCustom）、身分都只看主的那個 ID。
--
-- 在順序、隱藏、覆寫裡的 id 是 "c:<index>"。index 是陣列位置，所以**刪掉中間一筆時
-- 後面的 id 全部要往前挪**（DB.RemoveCustom 負責，不然第 3 筆的覆寫會跑到原本的第 4 筆上）。
--
-- ── 三層範圍（2026-10-03）：戰隊 ＞ 職業 ＞ 專精，窄的蓋寬的 ─────────────────────
--   profile.customShared            戰隊層：用這份設定檔的每個角色、每個專精都看得到
--   profile.customClass[classFile]  職業層：這個職業的所有專精
--   spells[specID].custom           專精層（上面那張，不動）
--   兩張新表的一筆跟專精層同形狀，另外多：
--     uid          穩定編號（設定檔層的流水號 profile.customNextUID，兩層共用一個號碼空間）；
--                  id 是 "k:<uid>"（職業）／"w:<uid>"（戰隊），刪掉別筆也不會變（不用挪位）
--     overrides    這一筆的逐法術覆寫（跟著項目走；所有看得到它的專精讀同一份）
--     hideUnknown  這個角色用不到（法術沒學）時整格不列；nil／true ＝ 不列（預設），false ＝ 照舊畫問號格
--   順序、隱藏、群組仍存在專精層（spells[specID].order[bar] 可以放 "k:3"／"w:7"）。
--   種類多一個 "racial"（種族技能）：沒有 spellID，照這個角色的種族解析成學會的那一個（Presets.ResolveRacial）；
--   解不到 ＝ 當成沒學（不列）。
--   **窄的蓋寬的**：同一個身分（同種類＋同主 ID，光環還要同 filter）在多層都有時只有最窄的那層生效，
--   寬的那筆對這個專精當不存在（DB.ResolveScopes，純函式）。
--   舊存檔沒有這兩張表 ＝ 只有專精層，行為跟以前一樣（不遷移、DB_VERSION 不動）。
------------------------------------------------------------
DB.CUSTOM_KINDS = { aura = true, spell = true, item = true, slot = true, slotbuff = true, racial = true }

-- 範圍：越大越窄（窄的蓋寬的）
DB.SCOPE_RANK = { shared = 1, class = 2, spec = 3 }
DB.SCOPE_ORDER = { "shared", "class", "spec" }
local SCOPE_PREFIX = { spec = "c", class = "k", shared = "w" }
local PREFIX_SCOPE = { c = "spec", k = "class", w = "shared" }

function DB.CustomID(i) return "c:" .. tostring(i) end

-- 範圍＋編號 → id（專精層的編號是陣列位置、另外兩層是 uid）
function DB.ScopedCustomID(scope, key)
    local pre = SCOPE_PREFIX[scope]
    if not pre or key == nil then return nil end
    return pre .. ":" .. tostring(key)
end

-- **解析自訂項目 id 的唯一出口**：
--   "c:3" → "spec", 3（陣列位置）｜"k:5" → "class", 5（uid）｜"w:7" → "shared", 7（uid）
--   不是自訂項目的 id（數字 cooldownID、格式不對）→ nil
function DB.ParseCustomID(id)
    if type(id) ~= "string" then return nil end
    local pre, n = id:match("^(%a):(%d+)$")
    local scope = pre and PREFIX_SCOPE[pre]
    if not scope then return nil end
    return scope, tonumber(n)
end

-- "c:3" → 3；不是專精層自訂項目的 id 回 nil（"k:"／"w:" 也是 nil：它們沒有陣列位置）
function DB.CustomIndex(id)
    local scope, n = DB.ParseCustomID(id)
    if scope == "spec" then return n end
    return nil
end

local function PositiveInt(v)
    return type(v) == "number" and v > 0 and v == math.floor(v)
end

-- 某一層的清單（"spec" ＝ 這個專精的 custom；"class" ＝ 這個角色職業的；"shared" ＝ 戰隊層）
-- create ＝ 呼叫端要寫 ⇒ DB.customGen 的作廢點（"spec" 走 CustomList，同一個規矩）
function DB.ScopeList(scope, create, specID)
    if scope == "spec" then return DB.CustomList(create, specID) end
    local p = ns.profile
    if not p then return nil end
    if create then DB.TouchCustom() end
    if scope == "shared" then
        if type(p.customShared) ~= "table" then
            if not create then return nil end
            p.customShared = {}
        end
        return p.customShared
    elseif scope == "class" then
        local cls = ns.playerClass
        if type(cls) ~= "string" or cls == "" then return nil end
        if type(p.customClass) ~= "table" then
            if not create then return nil end
            p.customClass = {}
        end
        local list = p.customClass[cls]
        if type(list) ~= "table" then
            if not create then return nil end
            list = {}
            p.customClass[cls] = list
        end
        return list
    end
    return nil
end

local function FindUID(list, uid)
    if type(list) ~= "table" or uid == nil then return nil end
    for pos, e in ipairs(list) do
        if type(e) == "table" and e.uid == uid then return e, pos end
    end
    return nil
end

-- 每一張寬層清單（戰隊層＋所有職業的）：fn(list)
local function EachWideList(p, fn)
    if type(p) ~= "table" then return end
    if type(p.customShared) == "table" then fn(p.customShared) end
    if type(p.customClass) == "table" then
        for _, list in pairs(p.customClass) do
            if type(list) == "table" then fn(list) end
        end
    end
end
DB.EachWideList = EachWideList

-- 新的 uid：流水號；比現有的最大 uid 小（匯入的設定檔、手改過的存檔）就從最大的下一號接
function DB.NextCustomUID()
    local p = ns.profile
    if not p then return nil end
    local n = PositiveInt(p.customNextUID) and p.customNextUID or 1
    local maxSeen = 0
    EachWideList(p, function(list)
        for _, e in ipairs(list) do
            if type(e) == "table" and PositiveInt(e.uid) and e.uid > maxSeen then maxSeen = e.uid end
        end
    end)
    if n <= maxSeen then n = maxSeen + 1 end
    p.customNextUID = n + 1
    return n
end

-- 身分：同種類＋同主 ID（光環還要同 filter）。判重、窄蓋寬、池化都看這個。種族技能（還沒解析的那一筆）是 "racial"
function DB.CustomIdentity(e)
    if type(e) ~= "table" then return nil end
    local k = e.kind
    if k == "racial" then return "racial" end
    if k == "item" then return e.itemID ~= nil and ("item:" .. tostring(e.itemID)) or nil end
    if k == "slot" then return e.slot ~= nil and ("slot:" .. tostring(e.slot)) or nil end
    if k == "slotbuff" then
        if e.slot == nil then return nil end
        return "slotbuff:" .. tostring(e.slot) .. ":" .. tostring(PositiveInt(e.buff) and e.buff or 1)
    end
    if e.spellID == nil then return nil end
    if k == "spell" then return "spell:" .. tostring(e.spellID) end
    if k == "aura" then
        return "aura:" .. tostring(e.spellID) .. ":" .. (e.filter == "HARMFUL" and "HARMFUL" or "HELPFUL")
    end
    return nil
end

-- 這一筆在這個角色身上長什麼樣（純函式；opts 由呼叫端注入）：
--   opts.racial()        → 這個角色學會的種族技能 spellID（解不到 nil）
--   opts.isKnown(id)     → 學了沒（false ＝ 沒學；nil／true ＝ 學了或讀不到）
-- 種族技能 ⇒ 換成一筆唯讀的法術「視圖」（metatable 讀原本那筆：bar、placeholder、overrides 都是原本的）；
-- 寬層（職業／戰隊）的法術沒學而且 hideUnknown 沒關 ⇒ nil（整格不列）。回 nil ＝ 這個專精當它不存在。
function DB.CustomView(raw, scope, opts)
    if type(raw) ~= "table" then return raw end
    opts = opts or {}
    local view = raw
    if raw.kind == "racial" then
        local sid = opts.racial and opts.racial()
        if not PositiveInt(sid) then return nil end
        view = setmetatable({ kind = "spell", spellID = sid, racial = true }, { __index = raw })
    end
    if scope ~= "spec" and raw.hideUnknown ~= false and view.kind == "spell" and opts.isKnown then
        if opts.isKnown(view.spellID) == false then return nil end
    end
    return view
end

-- 三層合併（純函式）：sharedList／classList／specList 是三層的原始清單，resolve(raw, scope) → 視圖或 nil
-- （省略 ＝ 原樣）。回傳 { { id, key, entry, raw, scope }, … }，戰隊 → 職業 → 專精的順序接；
-- 同一個身分只留最窄那層的（同一層的重複照留，匯入帶進來的重複項由 Custom.Sync 自己分 key）。
-- 寬層沒有 uid 的壞資料跳過（沒有 id 可以放進順序表）。
function DB.ResolveScopes(sharedList, classList, specList, resolve)
    local items = {}
    local function Take(list, scope)
        if type(list) ~= "table" then return end
        for i, raw in ipairs(list) do
            local key
            if scope == "spec" then
                key = i
            elseif type(raw) == "table" and PositiveInt(raw.uid) then
                key = raw.uid
            end
            if key then
                local view = raw
                if resolve then view = resolve(raw, scope) end
                if view ~= nil then
                    items[#items + 1] = { id = DB.ScopedCustomID(scope, key), key = key, entry = view, raw = raw, scope = scope }
                end
            end
        end
    end
    Take(sharedList, "shared")
    Take(classList, "class")
    Take(specList, "spec")
    local RANK = DB.SCOPE_RANK
    local narrow = {}
    for _, it in ipairs(items) do
        local k = DB.CustomIdentity(it.entry)
        if k and (narrow[k] or 0) < RANK[it.scope] then narrow[k] = RANK[it.scope] end
    end
    local out = {}
    for _, it in ipairs(items) do
        local k = DB.CustomIdentity(it.entry)
        if not k or narrow[k] == RANK[it.scope] then out[#out + 1] = it end
    end
    return out
end

-- 遊戲裡的 opts：學了沒（Catalog.SpellKnown，讀不到當學了）、種族（UnitRace 的英文 token，明文才收）。
-- 同一幀裡重複問的結果共用（Catalog.Bar／Info 一輪排版會問很多次），換幀就作廢
local runtimeCache, runtimeAt = {}, nil
local function RuntimeFresh()
    local now = _G.GetTime and _G.GetTime() or nil
    if now == nil or now ~= runtimeAt then
        runtimeCache = {}
        runtimeAt = now
    end
    return runtimeCache
end

local function RuntimeKnown(spellID)
    local C = ns.Catalog
    if not (C and C.SpellKnown) then return nil end
    local cache = RuntimeFresh()
    local v = cache[spellID]
    if v == nil then
        v = C.SpellKnown(spellID) and true or false
        cache[spellID] = v
    end
    return v
end

local function PlayerRace()
    local fn = _G.UnitRace
    if type(fn) ~= "function" then return nil end
    local ok, _, race = pcall(fn, "player")
    if not ok or race == nil or (ns.IsSecret and ns.IsSecret(race)) then return nil end
    return type(race) == "string" and race or nil
end

local function RuntimeRacial()
    local P = ns.Presets
    if not (P and P.ResolveRacial) then return nil end
    local cache = RuntimeFresh()
    if cache.racial == nil then
        cache.racial = P.ResolveRacial(PlayerRace(), RuntimeKnown) or false
    end
    return cache.racial or nil
end

local RUNTIME_OPTS = { isKnown = RuntimeKnown, racial = RuntimeRacial }
local function RuntimeView(raw, scope) return DB.CustomView(raw, scope, RUNTIME_OPTS) end

-- 這個專精實際生效的自訂項目（三層合併、窄蓋寬、種族技能解析、用不到的不列）。
-- Catalog／Custom.Sync／設定頁都吃這支；一輪排版會被叫很多次（每條的 Catalog.Bar、BarHasAuraSlot、CustomEntry…）。
-- memo（效能修整 E2）：DB.customGen、GetTime() 戳記、專精、設定檔四樣都相同才回上一次的表。
--   * customGen 是寫入出口的作廢點（見檔頭「寫入世代」）⇒ 同一幀寫完立刻讀也拿得到新的
--   * 每幀戳記是第二道保險，也讓「學了沒」「種族技能解成哪一個」（RuntimeFresh，本來就是每幀）跟著換幀重算
--   * 讀不到 GetTime（離線測試）⇒ 不 memo
-- ⚠ 回傳的表（連同裡面每一項）**呼叫端不准改**：同一幀的其他呼叫拿到的是同一張
local effMemo = { gen = -1 }
function DB.EffectiveCustom(specID)
    local p = ns.profile
    if not p then return {} end
    local spec = specID or ns.specID
    local now = _G.GetTime and _G.GetTime() or nil
    local m = effMemo
    if now ~= nil and m.at == now and m.gen == DB.customGen and m.spec == spec and m.profile == p then
        return m.list
    end
    local list = DB.ResolveScopes(DB.ScopeList("shared", false), DB.ScopeList("class", false),
        DB.CustomList(false, specID), RuntimeView)
    m.gen, m.at, m.spec, m.profile, m.list = DB.customGen, now, spec, p, list
    return list
end

-- 生效清單裡的那一項（不在 ＝ nil）
function DB.EffectiveItem(id)
    if not DB.ParseCustomID(id) then return nil end
    for _, it in ipairs(DB.EffectiveCustom()) do
        if it.id == id then return it end
    end
    return nil
end

function DB.CustomList(create, specID)
    local sp = DB.SpecSpells(create, specID)
    if not sp then return nil end
    if create then DB.TouchCustom() end
    if type(sp.custom) ~= "table" then
        if not create then return nil end
        sp.custom = {}
    end
    return sp.custom
end

-- id → 存著的那一筆（原始資料，不是種族技能解析後的視圖；不存在回 nil）。第二個回傳值是編號
-- （專精層的陣列位置／寬層的 uid）、第三個是範圍
function DB.CustomEntry(id, specID)
    local scope, key = DB.ParseCustomID(id)
    if not scope then return nil end
    if scope == "spec" then
        local list = DB.CustomList(false, specID)
        local e = list and list[key]
        return type(e) == "table" and e or nil, key, scope
    end
    local e = FindUID(DB.ScopeList(scope, false), key)
    return e, key, scope
end

-- 這一層已經有同身分的（種族技能：這一層已經有一筆種族技能）→ 位置或 nil
function DB.FindInScope(scope, e, specID)
    local want = DB.CustomIdentity(e)
    if not want then return nil end
    for pos, x in ipairs(DB.ScopeList(scope, false, specID) or {}) do
        if DB.CustomIdentity(x) == want then return pos end
    end
    return nil
end

-- 這個專精現在看得到的（任何一層，窄蓋寬之後）裡有沒有同身分的 → 那一項的 id 或 nil
-- 種族技能那一筆：比原本那筆的種類（這一層有種族技能就算），也比解析後的法術
function DB.FindEffective(e)
    local want = DB.CustomIdentity(e)
    if not want then return nil end
    for _, it in ipairs(DB.EffectiveCustom()) do
        if DB.CustomIdentity(it.entry) == want or DB.CustomIdentity(it.raw) == want then return it.id end
    end
    return nil
end

-- 同一個專精裡已經有同樣的項目（同種類、同 ID、光環還要同 filter）。
-- 飾品欄增益（kind "slotbuff"）：id ＝ 槽、filter 的位置放第幾個增益（缺 ＝ 1）
function DB.FindCustom(kind, id, filter, specID)
    for i, e in ipairs(DB.CustomList(false, specID) or {}) do
        if type(e) == "table" and e.kind == kind then
            local same
            if kind == "item" then same = e.itemID == id
            elseif kind == "slot" then same = e.slot == id
            elseif kind == "slotbuff" then
                same = e.slot == id and (PositiveInt(e.buff) and e.buff or 1) == (PositiveInt(filter) and filter or 1)
            else same = e.spellID == id and (kind ~= "aura" or (e.filter or "HELPFUL") == (filter or "HELPFUL")) end
            if same then return i end
        end
    end
    return nil
end

-- 某一筆在 specID 那個專精裡有沒有同樣的（同種類同主 ID；光環還要同 filter）→ index 或 nil
function DB.FindCustomLike(e, specID)
    if type(e) ~= "table" then return nil end
    local id
    local filter = e.filter
    if e.kind == "item" then id = e.itemID
    elseif e.kind == "slot" then id = e.slot
    elseif e.kind == "slotbuff" then id, filter = e.slot, e.buff
    else id = e.spellID end
    if id == nil then return nil end
    return DB.FindCustom(e.kind, id, filter, specID)
end

-- 裝備欄位／飾品欄增益的槽對不對（其他種類一律 true）
local function SlotEntryOK(entry)
    local C = ns.Catalog
    if entry.kind == "slot" then return (C and C.CUSTOM_SLOTS[entry.slot]) == true end
    if entry.kind == "slotbuff" then
        return (C and C.SLOTBUFF_SLOTS and C.SLOTBUFF_SLOTS[entry.slot]) == true
            and (entry.buff == nil or PositiveInt(entry.buff))
    end
    return true
end

-- 新增（專精層），回傳 index（沒有專精 ⇒ nil）
function DB.AddCustom(entry)
    if type(entry) ~= "table" or not DB.CUSTOM_KINDS[entry.kind] then return nil end
    if not SlotEntryOK(entry) then return nil end
    local list = DB.CustomList(true)
    if not list then return nil end
    list[#list + 1] = entry
    return #list
end

-- 新增到某一層，回傳 id（"c:<i>"／"k:<uid>"／"w:<uid>"；失敗 nil）。寬層的那一筆配 uid、hideUnknown 預設開
function DB.AddCustomTo(scope, entry)
    if scope == nil or scope == "spec" then
        local i = DB.AddCustom(entry)
        return i and DB.CustomID(i) or nil
    end
    if not DB.SCOPE_RANK[scope] then return nil end
    if type(entry) ~= "table" or not DB.CUSTOM_KINDS[entry.kind] then return nil end
    if not SlotEntryOK(entry) then return nil end
    if not ns.specID then return nil end          -- 跟專精層同一個前提（設定頁要先有專精）
    local list = DB.ScopeList(scope, true)
    if not list then return nil end
    entry.uid = DB.NextCustomUID()
    entry.overrides = nil
    if entry.hideUnknown == nil then entry.hideUnknown = true end
    list[#list + 1] = entry
    return DB.ScopedCustomID(scope, entry.uid)
end

function DB.SetCustomBar(id, bar)
    local e = DB.CustomEntry(id)
    if not e or type(bar) ~= "string" then return false end
    e.bar = bar
    DB.TouchCustom()                      -- Catalog.CustomInfo 的 memo 帶著 bar
    return true
end

-- 刪掉第 i 筆，後面的 "c:j" 全部改成 "c:(j-1)"（順序、隱藏、覆寫、群組）
local function Shift(id, removed)
    local j = DB.CustomIndex(id)
    if not j then return id end
    if j == removed then return false end
    if j > removed then return DB.CustomID(j - 1) end
    return id
end

-- 某個 id 在一個專精表裡改名（順序、隱藏、群組；覆寫一併搬，寬層的覆寫本來就不在這裡）。new ＝ nil ＝ 拿掉
local function RenameIn(sp, old, new)
    if type(sp) ~= "table" then return end
    if type(sp.order) == "table" then
        for bar, ids in pairs(sp.order) do
            if type(ids) == "table" then
                local out = {}
                for _, v in ipairs(ids) do
                    if v == old then
                        if new ~= nil then out[#out + 1] = new end
                    else
                        out[#out + 1] = v
                    end
                end
                sp.order[bar] = out
            end
        end
    end
    for _, field in ipairs({ "hidden", "groupOf", "overrides" }) do
        local t = sp[field]
        if type(t) == "table" and t[old] ~= nil then
            local v = t[old]
            t[old] = nil
            if new ~= nil then t[new] = v end
        end
    end
end

-- 所有專精表都拿掉這個 id（寬層的一筆刪掉／搬走時）
local function PurgeEverywhere(id, exceptSp)
    local p = ns.profile
    for _, sp in pairs(p and type(p.spells) == "table" and p.spells or {}) do
        if sp ~= exceptSp then RenameIn(sp, id, nil) end
    end
end

function DB.RemoveCustom(id, specID)
    local scope, key = DB.ParseCustomID(id)
    if scope == "class" or scope == "shared" then
        -- 寬層：uid 穩定，不用挪位；所有專精的順序／隱藏／群組裡的這個 id 一起清掉（覆寫跟著那一筆走了）
        local list = DB.ScopeList(scope, false)
        local _, pos = FindUID(list, key)
        if not pos then return false end
        table.remove(list, pos)
        PurgeEverywhere(id)
        DB.TouchCustom()
        return true
    end
    local i = DB.CustomIndex(id)
    local sp = DB.SpecSpells(false, specID)
    local list = sp and type(sp.custom) == "table" and sp.custom
    if not (i and list and list[i] ~= nil) then return false end
    table.remove(list, i)
    if type(sp.order) == "table" then
        for bar, ids in pairs(sp.order) do
            if type(ids) == "table" then
                local out = {}
                for _, v in ipairs(ids) do
                    local nv = Shift(v, i)
                    if nv then out[#out + 1] = nv end
                end
                sp.order[bar] = out
            end
        end
    end
    for _, field in ipairs({ "hidden", "overrides", "groupOf" }) do
        local t = sp[field]
        if type(t) == "table" then
            local moved = {}
            for k, v in pairs(t) do
                if DB.CustomIndex(k) then moved[k] = v end
            end
            for k in pairs(moved) do t[k] = nil end
            for k, v in pairs(moved) do
                local nk = Shift(k, i)
                if nk then t[nk] = v end
            end
        end
    end
    DB.TouchCustom()                      -- 清單挪位、覆寫跟著挪
    return true
end

------------------------------------------------------------
-- 範圍切換：把一筆連覆寫搬到另一層（配新 id），回傳新 id；失敗 nil, 原因（"bad"｜"missing"｜"exists"）
--
--   * 專精 → 寬層：目前專精的順序／隱藏／群組裡的舊 id 換成新 id，覆寫從 spells[spec].overrides 搬到那一筆身上；
--     專精層那一筆照 RemoveCustom 拿掉（後面的 "c:j" 往前挪）
--   * 寬層 → 專精：只搬到**目前專精**（追加到尾端）；目前專精的舊 id 換成新 id，其他專精的舊 id 清掉
--     （其他專精就看不到了，設定頁會先問）
--   * 寬層 ↔ 寬層：配新 uid，所有專精的舊 id 換成新 id
--   目標層已經有同身分的 ⇒ "exists"（不合併、不動）。往寬搬時**其他專精**若已有同身分的自己那筆，
--   照「窄的蓋寬的」自然不會重複，不自動刪。
------------------------------------------------------------
function DB.MoveCustomScope(id, newScope)
    local scope, key = DB.ParseCustomID(id)
    if not scope or not DB.SCOPE_RANK[newScope] then return nil, "bad" end
    if scope == newScope then return id end
    local raw = DB.CustomEntry(id)
    if type(raw) ~= "table" then return nil, "missing" end
    if not ns.specID then return nil, "bad" end
    if DB.FindInScope(newScope, raw) then return nil, "exists" end

    local ov
    if scope == "spec" then
        local sp = DB.SpecSpells(false)
        ov = sp and type(sp.overrides) == "table" and sp.overrides[id] or nil
    else
        ov = raw.overrides
    end
    local copy = DeepCopy(raw)
    copy.uid, copy.overrides = nil, nil
    local hasOv = type(ov) == "table" and next(ov) ~= nil

    local newID
    if newScope == "spec" then
        local list = DB.CustomList(true)
        if not list then return nil, "bad" end
        list[#list + 1] = copy
        newID = DB.CustomID(#list)
    else
        local list = DB.ScopeList(newScope, true)
        if not list then return nil, "bad" end
        copy.uid = DB.NextCustomUID()
        if copy.hideUnknown == nil then copy.hideUnknown = true end
        if hasOv then copy.overrides = DeepCopy(ov) end
        list[#list + 1] = copy
        newID = DB.ScopedCustomID(newScope, copy.uid)
    end

    local cur = DB.SpecSpells(true)
    if scope == "spec" then
        -- 舊的覆寫已經搬到新那筆身上：先拿掉，RenameIn 才不會把它搬到新 id 底下
        if type(cur.overrides) == "table" then cur.overrides[id] = nil end
        RenameIn(cur, id, newID)
        DB.RemoveCustom(id)
        DB.TouchCustom()                  -- 覆寫跟著搬（RemoveCustom 也 +1，這裡寫明出口）
        return newID
    end
    -- 舊的在寬層
    if newScope == "spec" then
        RenameIn(cur, id, newID)
        if hasOv then cur.overrides[newID] = DeepCopy(ov) end
        PurgeEverywhere(id, cur)
    else
        local p = ns.profile
        for _, sp in pairs(type(p.spells) == "table" and p.spells or {}) do RenameIn(sp, id, newID) end
    end
    local list = DB.ScopeList(scope, false)
    local _, pos = FindUID(list, key)
    if pos then table.remove(list, pos) end
    DB.TouchCustom()                      -- 舊的拿掉、覆寫跟著搬
    return newID
end

------------------------------------------------------------
-- 複製到其他專精
--
-- 目前專精的第 id 筆深複製、追加到 spells[target].custom 尾端；它在目前專精的覆寫（overrides[id]）
-- 一併複製到目標的新 id 底下。bar 照抄（條是設定檔層、各專精共用）。
-- 目標已有同種類同主 ID（光環同 filter）⇒ 回 false 不動。成功回新的 index。
------------------------------------------------------------
function DB.CopyCustomEntry(id, targetSpecID)
    if targetSpecID == nil or targetSpecID == ns.specID then return false end
    if DB.ParseCustomID(id) ~= "spec" then return false end      -- 寬層本來就每個專精都看得到
    local e = DB.CustomEntry(id)
    if not e or not DB.CUSTOM_KINDS[e.kind] then return false end
    if DB.FindCustomLike(e, targetSpecID) then return false end
    local list = DB.CustomList(true, targetSpecID)
    if not list then return false end
    list[#list + 1] = DeepCopy(e)
    local n = #list
    local sp = DB.SpecSpells(false)
    local o = sp and type(sp.overrides) == "table" and sp.overrides[id]
    if type(o) == "table" and next(o) ~= nil then
        local tsp = DB.SpecSpells(true, targetSpecID)
        tsp.overrides[DB.CustomID(n)] = DeepCopy(o)
    end
    DB.TouchCustom()
    return n
end

-- 這個職業的專精：{ { id, name, icon }, … }（讀不到回空表）
function DB.ClassSpecs()
    local out = {}
    local num = GetNumSpecializations
    local info = GetSpecializationInfo
    if type(num) ~= "function" or type(info) ~= "function" then return out end
    local ok, n = pcall(num)
    if not ok or type(n) ~= "number" then return out end
    for i = 1, n do
        local ok2, id, name, _, icon = pcall(info, i)
        if ok2 and type(id) == "number" and id > 0 then
            out[#out + 1] = { id = id, name = type(name) == "string" and name or tostring(id), icon = icon }
        end
    end
    return out
end

------------------------------------------------------------
-- 設定檔：改名、取不重複的名字、匯入
------------------------------------------------------------
function DB.RenameProfile(old, new)
    new = CleanName(new)
    local sv = SV()
    if new == "" then return false, "empty" end
    if old == DB.DEFAULT_PROFILE or not sv.profiles[old] then return false, "nosource" end
    if old == new then return true, new end
    if sv.profiles[new] then return false, "exists" end
    sv.profiles[new], sv.profiles[old] = sv.profiles[old], nil
    for k, v in pairs(sv.profileKeys) do
        if v == old then sv.profileKeys[k] = new end
    end
    for _, map in pairs(sv.specProfiles) do
        for idx, v in pairs(map) do
            if v == old then map[idx] = new end
        end
    end
    if ns.profileName == old then ns.profileName = new end
    return true, new
end

-- 撞名自動加序號：「名字」→「名字 (2)」→「名字 (3)」…
function DB.UniqueProfileName(base)
    base = CleanName(base)
    if base == "" then base = "Imported" end
    local sv = SV()
    if not sv.profiles[base] then return base end
    local n = 2
    while sv.profiles[("%s (%d)"):format(base, n)] do n = n + 1 end
    return ("%s (%d)"):format(base, n)
end

-- 匯入一律建成新的一份（不覆蓋現有的）。profile 是解碼出來的表（呼叫端已驗過形狀），
-- fromVersion 是字串裡帶的 schemaVersion。回傳實際用的名字。
function DB.ImportProfile(profile, fromVersion, name)
    if type(profile) ~= "table" then return nil end
    name = DB.UniqueProfileName(name)
    local copy = DeepCopy(profile)
    DB.MigrateProfile(copy, fromVersion)
    SV().profiles[name] = copy
    DB.TouchCustom()                      -- 新的一份（不是目前這份）；照 plan 一律作廢，便宜
    return name
end

------------------------------------------------------------
-- 匯出／匯入字串
--
--   "MILICDM!1!" ＋ Base64( Deflate( CBOR{ schemaVersion, name, profile } ) )
--
-- 只帶**目前這份設定檔**：帳號層（小地圖、視窗位置、其他設定檔、專精綁定）不跟字串跑。
-- 解碼失敗回 nil, 原因代碼（empty／prefix／noapi／base64／inflate／cbor／shape／newer），
-- 給玩家看的字由設定介面照代碼翻。
------------------------------------------------------------
DB.WIRE_PREFIX = "MILICDM!1!"

local function EU() return C_EncodingUtil end

local function DeflateMethod()
    return Enum and Enum.CompressionMethod and Enum.CompressionMethod.Deflate
end

function DB.EncodeProfile(profile, name)
    local eu = EU()
    if not (eu and eu.SerializeCBOR and eu.CompressString and eu.EncodeBase64) then return nil, "noapi" end
    local payload = { schemaVersion = ns.DB_VERSION, name = name or ns.profileName, profile = profile or ns.profile }
    local ok, cbor = pcall(eu.SerializeCBOR, payload)
    if not ok or type(cbor) ~= "string" then return nil, "cbor" end
    local ok2, packed = pcall(eu.CompressString, cbor, DeflateMethod())
    if not ok2 or type(packed) ~= "string" then return nil, "inflate" end
    local ok3, b64 = pcall(eu.EncodeBase64, packed)
    if not ok3 or type(b64) ~= "string" then return nil, "base64" end
    return DB.WIRE_PREFIX .. b64
end

function DB.DecodeProfileString(text)
    if type(text) ~= "string" then return nil, "empty" end
    text = text:gsub("%s+", "")
    if text == "" then return nil, "empty" end
    if text:sub(1, #DB.WIRE_PREFIX) ~= DB.WIRE_PREFIX then return nil, "prefix" end
    local eu = EU()
    if not (eu and eu.DecodeBase64 and eu.DecompressString and eu.DeserializeCBOR) then return nil, "noapi" end
    local ok, packed = pcall(eu.DecodeBase64, text:sub(#DB.WIRE_PREFIX + 1))
    if not ok or type(packed) ~= "string" then return nil, "base64" end
    local ok2, cbor = pcall(eu.DecompressString, packed, DeflateMethod())
    if not ok2 or type(cbor) ~= "string" then return nil, "inflate" end
    local ok3, data = pcall(eu.DeserializeCBOR, cbor)
    if not ok3 or type(data) ~= "table" then return nil, "cbor" end
    -- 形狀要驗，不能只看版本號：這張表會直接變成一份設定檔，型別不對的話要等到
    -- 切過去才炸，那時已經建好了
    local v, profile = data.schemaVersion, data.profile
    if type(v) ~= "number" or type(profile) ~= "table" then return nil, "shape" end
    for _, k in ipairs({ "theme", "bars", "spells" }) do
        if profile[k] ~= nil and type(profile[k]) ~= "table" then return nil, "shape" end
    end
    if type(profile.bars) == "table" then
        for _, bar in pairs(profile.bars) do
            if type(bar) ~= "table" then return nil, "shape" end
        end
    end
    -- 自訂項目的寬層（戰隊／職業）：形狀不對的直接丟掉（不擋整份匯入；舊版的字串本來就沒有這兩張表）
    if profile.customShared ~= nil and type(profile.customShared) ~= "table" then profile.customShared = nil end
    if profile.customClass ~= nil then
        if type(profile.customClass) ~= "table" then
            profile.customClass = nil
        else
            for cls, list in pairs(profile.customClass) do
                if type(cls) ~= "string" or type(list) ~= "table" then profile.customClass[cls] = nil end
            end
        end
    end
    if profile.customNextUID ~= nil and type(profile.customNextUID) ~= "number" then profile.customNextUID = nil end
    if v > ns.DB_VERSION then return nil, "newer" end
    if type(data.name) ~= "string" then data.name = nil end
    return data
end

-- 審閱頁用：帶了哪幾條檢視器、幾個自訂群組（與名字）
function DB.SummarizeProfile(profile)
    local builtin, custom = {}, {}
    for key, bar in pairs(type(profile) == "table" and type(profile.bars) == "table" and profile.bars or {}) do
        if BUILTIN[key] then
            builtin[#builtin + 1] = key
        elseif type(bar) == "table" then
            custom[#custom + 1] = type(bar.name) == "string" and bar.name or key
        end
    end
    local order = { essential = 1, utility = 2, buffs = 3, buffbars = 4 }
    table.sort(builtin, function(a, b) return order[a] < order[b] end)
    table.sort(custom)
    return builtin, custom
end
