------------------------------------------------------------
-- SavedVariables：MiliUI_CooldownManager_DB
--
--   MiliUI_CooldownManager_DB = {
--       schemaVersion, schemaVersionSeen,             -- 遷移鏈
--       minimap, optionsWindow,                       -- 帳號層，不跟設定檔走
--       profiles     = { ["Default"] = <profile>, … },
--       profileKeys  = { ["角色 - 伺服器"] = "Default" },            -- 每角色目前用哪份
--       specProfiles = { ["角色 - 伺服器"] = { enabled = bool, [專精序號] = "設定檔名" } },
--       charClasses  = { ["角色 - 伺服器"] = "PALADIN" },            -- 清單上色用
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
ns.DB_VERSION = 1

-- ⚠ 存進 SV 的 key，**不要翻譯**：翻了之後換客戶端語系就對不上。
DB.DEFAULT_PROFILE = "Default"

local function rgba(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end
local ResourcesDefaults, PipsDefaults, CastbarDefaults   -- 定義在 BuildDefaults 前面（前置宣告，免得變全域）

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
        },
        follow     = { text = true, icon = true, glow = true, fade = true },
        text = {}, icon = {}, glow = {}, fade = {},
        visibility = { showCombat = false, showTarget = false, hideMounted = false,
                       onlyInstances = false, group = "any" },   -- group: any | solo | party | raid
        bar        = o.bar or false,        -- kind = "bars" 才有
        strata     = "MEDIUM",
        clickable  = false,                 -- 點了施放／使用（只有自訂圖示群組讀，判準在 DB.BarClickable）
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
            showName  = true, nameSize = 16,
            showTime  = true, timeSize = 16,
            showStacks = true, stackSize = 12,
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
-- 資源條（Modules/Resources.lua）、自訂格子（Modules/Pips.lua）與施法條（Modules/Castbar.lua）
--
-- 三者都不在 bars 裡（不是暴雪檢視器、沒有版面／主題繼承），但**錨定語意跟條一樣**：
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
    MaelstromWeapon = { color = { r = 0.2,  g = 0.65, b = 1    } },
    TipOfTheSpear   = { color = { r = 1,    g = 0.6,  b = 0.2  } },
    SoulFragments   = { color = { r = 0.64, g = 0.19, b = 0.79 } },
    -- 2026-09-30 補齊的職業資源（冰刺冰藍、噬靈魂碎片同復仇的紫、戰士三種暖色系、鐵鬃棕）
    Icicles         = { color = { r = 0.44, g = 0.80, b = 1    } },
    DevourerFragments = { color = { r = 0.64, g = 0.19, b = 0.79 } },
    -- 醉仙緩勁三段：輕度（主色）／中度／重度，門檻在 staggerModerateAt／staggerHeavyAt
    Stagger         = { color         = { r = 0.52, g = 0.90, b = 0.52 },
                        moderateColor = { r = 1,    g = 0.85, b = 0.36 },
                        heavyColor    = { r = 1,    g = 0.42, b = 0.42 } },
    WhirlwindStacks = { color = { r = 0.90, g = 0.45, b = 0.20 } },
    SweepingStrikes = { color = { r = 0.85, g = 0.65, b = 0.35 } },
    IgnorePain      = { color = { r = 0.95, g = 0.80, b = 0.35 } },
    Ironfur         = { color = { r = 0.72, g = 0.52, b = 0.30 } },
    -- 光環剩餘時間條：黯黑力量（喚能師的古銅黑金）、秘法靈魂（秘法紫，跟秘法充能的藍分得開）
    EbonMight       = { color = { r = 0.80, g = 0.60, b = 0.20 } },
    ArcaneSoul      = { color = { r = 0.66, g = 0.40, b = 1    } },
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
        for field, c in pairs(fields) do t[field] = rgba(c.r, c.g, c.b, 1) end
        colors[key] = t
    end
    return {
        enabled       = true,
        pos           = { point = "CENTER", x = 0, y = -180 },
        -- 預設貼在核心技能上緣，往上長
        anchor        = { to = "essential", point = "BOTTOM", relPoint = "TOP", x = 0, y = 1 },
        width         = 0,                 -- 0 ＝ 跟核心技能第一列同寬
        rowHeight     = 14,                -- 使用者 2026-10-01 指定，不遷移
        rowSpacing    = 1,
        segmentSpacing = 0,                -- 點數型（聖能、連擊點…）的格距；0 ＝ 相鄰兩格共用 1px 邊（使用者 2026-10-01 指定，不遷移）
        fillDirection = "ltr",             -- ltr | rtl（點數型從右邊亮起）
        texture       = "solid",
        barAlpha      = 1,                 -- 填充色的不透明度
        smooth        = true,              -- 連續條的原生內插（引擎做，吃秘密值）
        -- 條上的數值：預設開、14 號字、置中（使用者 2026-10-01 指定，不遷移）
        showText      = true,
        textSize      = 14,
        runeText      = "countdown",       -- 死騎符文列的數字：countdown 每格秒數／count 中間顆數，showText 開著才有（見 Resources.lua 的 R.RuneText）
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
        -- 醉仙緩勁：中度／重度的門檻（% 最大生命）、滿條對應幾 % 最大生命
        staggerModerateAt = 30,
        staggerHeavyAt    = 60,
        staggerCeiling    = 100,
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
        -- [資源key] = false ＝ 關掉那一列；開放式、預設空
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
        texture       = "solid",
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
        showSpark     = true,
        ticks         = true,              -- 引導刻度
        latency       = true,              -- 延遲條
        hideBlizzard  = true,              -- 隱藏暴雪的玩家施法條（只解事件，見 Castbar.lua）
        interruptReady = false,            -- 自己的斷法就緒時換色
        fillDirection = "ltr",
        hideWhenNotCasting = true,         -- 沒在施法時 alpha 0（編輯模式中照樣全亮）
        strata        = "MEDIUM",
    }
end

function DB.BuildDefaults()
    -- 位置與往上長：使用者 2026-10-01 指定（照使用者調好的那份），不遷移
    local buffbars = LongBar{ source = "buffbars", grow = "CENTER_UP", pos = { point = "BOTTOM", x = 0, y = 524 } }

    return {
        account = {
            minimap       = { hide = false, angle = 215 },
            optionsWindow = { x = 0, y = 0, lastBar = "essential" },
        },
        profile = {
            theme = {
                font    = "提示訊息",        -- LibSharedMedia 名稱；沒有這個名稱的客戶端退回在地化字型
                outline = "OUTLINE",
                border  = { texture = "solid", size = 1, color = rgba(0, 0, 0, 1) },
                cooldownText = { size = 16, color = rgba(1, 1, 1), decimalsBelow = 3,
                                 lowColor = rgba(1, 0.3, 0.3), lowBelow = 5 },
                chargeText   = { size = 12, color = rgba(1, 1, 1), point = "BOTTOMRIGHT", x = 0, y = 0 },
                stackText    = { size = 12, color = rgba(1, 1, 1), point = "TOP",         x = 0, y = 0 },
                -- skin：圖示外觀 "miliui"（自己畫邊框／縮放）| "masque"（交給 Masque，Core/Masque.lua）；
                -- 舊存檔沒有這欄 ＝ 預設，不遷移
                icon  = { skin = "miliui", zoom = 0.08, swipeColor = rgba(0, 0, 0, 0.8), tooltips = true,
                          hideGCDSwipe = false, desaturateOnCooldown = true },
                -- 預設樣式：觸發＝觸發、就緒＝快捷鍵閃光（2026-10-01 使用者指定；舊存檔不遷移）
                glow  = {
                    proc  = { enabled = true,  type = "proc",  color = rgba(1, 0.85, 0, 1),
                              lines = 8, thickness = 2, frequency = 0.2 },
                    -- duration：冷卻轉好之後亮幾秒
                    ready = { enabled = false, type = "button", color = rgba(0.3, 1, 0.3, 1),
                              lines = 8, thickness = 2, frequency = 0.2, duration = 3 },
                },
                -- 淡出後的透明度；false ＝ 這個條件不淡
                -- 淡出：一個透明度；「不淡出的時機」任一成立就維持完整顯示（跟顯示條件的「時機 OR」同一套語彙）；
                -- 騎乘另外一個開關，勾了不看時機一律淡
                fade  = { enabled = true, alpha = 0.3, keepInCombat = true, keepWithTarget = true, whenMounted = false },
                -- 無損刷新（可以續壓的窗口）：邊框換色；bars ＝ 長條的條身也換色
                pandemic = { enabled = true, color = rgba(1, 0.5, 0, 1), bars = true },
                -- 按鍵文字：動作條上綁的鍵，縮寫後畫在圖示一角
                keybind  = { enabled = true, size = 10, point = "TOPRIGHT", x = 1, y = -1 },   -- 預設開、右上（使用者 2026-09-30 指定）
                -- 音效（Core/Sound.lua）：總開關與聲道；要響什麼是逐法術覆寫（readySound／gainSound／loseSound）。
                -- 不走條層繼承（不在 THEMED 裡），一律用 ns.Setting("theme", "sound.…") 讀
                sound    = { enabled = true, channel = "Master" },
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
            resources = ResourcesDefaults(),
            pips      = PipsDefaults(),
            castbar   = CastbarDefaults(),
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
    desaturate  = "icon.desaturateOnCooldown",
}
-- 沒有條層對應的覆寫欄位 → 固定預設
local SPELL_CONST = {
    hideCooldownText = false,
    hideStackText    = false,
    -- 音效：LibSharedMedia 的音效名；沒設（nil）或 false ＝ 無
    readySound       = false,
    gainSound        = false,
    loseSound        = false,
}
DB.SPELL_FALLBACK, DB.SPELL_CONST = SPELL_FALLBACK, SPELL_CONST

-- cooldownID：暴雪類別裡的項目用數字 cooldownID，自訂項目用 "c:<index>"。
-- ⚠ 它會拿來當 table key ⇒ 只能是從 C_CooldownViewer 讀到的明文，**不准是秘密值**。
-- specID 省略 ＝ 目前的專精。
function ns.SpellSetting(barKey, cooldownID, key, specID)
    local p = ns.profile
    if not p then return nil end
    specID = specID or ns.specID
    local spec = specID and p.spells and p.spells[specID]
    local o = spec and spec.overrides and cooldownID ~= nil and spec.overrides[cooldownID]
    if type(o) == "table" then
        local v = o[key]
        if v ~= nil then return v end
    end
    local path = SPELL_FALLBACK[key]
    if path then return ns.Setting(barKey, path) end
    return SPELL_CONST[key]
end

------------------------------------------------------------
-- 恢復預設（原地清空再灌：各處抓著的是這張表的參照）
------------------------------------------------------------
function DB.ResetProfile()
    local p = ns.profile
    if not p then return end
    Wipe(p)
    MergeDefaults(p, DB.BuildDefaults().profile)
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

-- 「面板」：資源條、自訂格子與施法條。不在 bars 裡、有自己的設定頁（自訂格子在資源條頁），
-- 但錨定／位置／編輯模式跟條同一套。
-- ⚠ key 是存檔內容（別的條的 anchor.to 會指向它），不要改名。
local PANEL_KEYS = { resources = true, pips = true, castbar = true }
DB.PANEL_KEYS = PANEL_KEYS
ns.PANEL_KEYS = PANEL_KEYS
-- 順序有意義：顯示條件照這個順序套、錨定候選照這個順序列
DB.PANEL_ORDER = { "resources", "pips", "castbar" }
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
    -- 自訂項目沒有「原本的暴雪那條」可以回去：光環格回增益圖示、法術／物品回核心技能
    for _, spec in pairs(type(p.spells) == "table" and p.spells or {}) do
        if type(spec) == "table" and type(spec.custom) == "table" then
            for _, e in ipairs(spec.custom) do
                if type(e) == "table" and e.bar == key then
                    e.bar = (e.kind == "aura") and "buffs" or "essential"
                end
            end
        end
    end
    for other, bar in pairs(p.bars) do
        if other ~= key and type(bar) == "table" and type(bar.anchor) == "table" and bar.anchor.to == key then
            bar.anchor = false
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
function DB.SpecSpells(create, specID)
    local p = ns.profile
    specID = specID or ns.specID
    if not (p and specID) then return nil end
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
    borderColor = "icon", desaturate = "icon",
    procGlow = "glow", readyGlow = "glow",
    hideCooldownText = "text", hideStackText = "text",
    -- 音效在條頁自成一節（「音效」：本條 N 個法術有音效、清除），不跟發光算在一起：
    -- 清發光覆寫不該順手把玩家挑好的音效清掉
    readySound = "sound", gainSound = "sound", loseSound = "sound",
}

-- v = nil 清掉那一格；整張空了就拿掉
function DB.SetOverride(cooldownID, field, v)
    if cooldownID == nil then return false end
    local sp = DB.SpecSpells(v ~= nil)
    if not sp then return false end
    local all = sp.overrides
    if type(all) ~= "table" then return false end
    local o = all[cooldownID]
    if type(o) ~= "table" then
        if v == nil then return true end
        o = {}
        all[cooldownID] = o
    end
    o[field] = v
    if next(o) == nil then all[cooldownID] = nil end
    return true
end

local function InGroup(field, group)
    return group == nil or DB.OVERRIDE_GROUP[field] == group
end

function DB.CountOverrides(ids, group)
    local sp = DB.SpecSpells(false)
    local all = sp and type(sp.overrides) == "table" and sp.overrides
    if not all then return 0 end
    local n = 0
    for _, id in ipairs(ids or {}) do
        local o = all[id]
        if type(o) == "table" then
            for field in pairs(o) do
                if InGroup(field, group) then n = n + 1; break end
            end
        end
    end
    return n
end

function DB.ClearOverrides(ids, group)
    local sp = DB.SpecSpells(false)
    local all = sp and type(sp.overrides) == "table" and sp.overrides
    if not all then return end
    for _, id in ipairs(ids or {}) do
        local o = all[id]
        if type(o) == "table" then
            for field in pairs(o) do
                if InGroup(field, group) then o[field] = nil end
            end
            if next(o) == nil then all[id] = nil end
        end
    end
end

------------------------------------------------------------
-- 自訂項目：spells[specID].custom = { { kind, spellID|itemID, filter, placeholder, bar }, … }
--
--   kind         "aura"（光環格）| "spell"（法術冷卻）| "item"（物品冷卻）| "slot"（裝備欄位：slot = 13／14，追蹤裝在那一格的物品）
--   filter       光環格才有："HELPFUL" | "HARMFUL"
--   placeholder  光環格才有：光環不在時畫去飽和的占位圖示
--   bar          放在哪一條（只收圖示類的條）
--
-- 在順序、隱藏、覆寫裡的 id 是 "c:<index>"。index 是陣列位置，所以**刪掉中間一筆時
-- 後面的 id 全部要往前挪**（DB.RemoveCustom 負責，不然第 3 筆的覆寫會跑到原本的第 4 筆上）。
------------------------------------------------------------
DB.CUSTOM_KINDS = { aura = true, spell = true, item = true, slot = true }

function DB.CustomID(i) return "c:" .. tostring(i) end

-- "c:3" → 3；不是自訂項目的 id 回 nil
function DB.CustomIndex(id)
    if type(id) ~= "string" then return nil end
    local n = id:match("^c:(%d+)$")
    return n and tonumber(n) or nil
end

function DB.CustomList(create, specID)
    local sp = DB.SpecSpells(create, specID)
    if not sp then return nil end
    if type(sp.custom) ~= "table" then
        if not create then return nil end
        sp.custom = {}
    end
    return sp.custom
end

-- id（"c:i"）→ 那一筆（不存在回 nil）
function DB.CustomEntry(id, specID)
    local i = DB.CustomIndex(id)
    local list = i and DB.CustomList(false, specID)
    local e = list and list[i]
    return type(e) == "table" and e or nil, i
end

-- 同一個專精裡已經有同樣的項目（同種類、同 ID、光環還要同 filter）
function DB.FindCustom(kind, id, filter, specID)
    for i, e in ipairs(DB.CustomList(false, specID) or {}) do
        if type(e) == "table" and e.kind == kind then
            local same
            if kind == "item" then same = e.itemID == id
            elseif kind == "slot" then same = e.slot == id
            else same = e.spellID == id and (kind ~= "aura" or (e.filter or "HELPFUL") == (filter or "HELPFUL")) end
            if same then return i end
        end
    end
    return nil
end

-- 新增，回傳 index（沒有專精 ⇒ nil）
function DB.AddCustom(entry)
    if type(entry) ~= "table" or not DB.CUSTOM_KINDS[entry.kind] then return nil end
    if entry.kind == "slot" and entry.slot ~= 13 and entry.slot ~= 14 then return nil end   -- 只有兩格飾品欄
    local list = DB.CustomList(true)
    if not list then return nil end
    list[#list + 1] = entry
    return #list
end

function DB.SetCustomBar(id, bar)
    local e = DB.CustomEntry(id)
    if not e or type(bar) ~= "string" then return false end
    e.bar = bar
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

function DB.RemoveCustom(id, specID)
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
    return true
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
