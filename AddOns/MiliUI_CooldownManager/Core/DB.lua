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
--     （anchor = false、row2Size = false、fade.mounted = false…）。
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

------------------------------------------------------------
-- 預設值
--
-- 數值取套組目前出貨的那組：核心 46×40、輔助 26×24、增益 40×36、間距 1、每列 8、
-- 字型「提示訊息」＋描邊、發光 pixel、長條往下長；位置核心 (0,-202)／增益 (0,-149)／
-- 長條 BOTTOM (0,300)，輔助錨在核心下方。
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
            grow       = o.grow or "CENTER_DOWN",   -- <CENTER|LEFT|RIGHT>_<DOWN|UP>
            size       = { w = o.w, h = o.h },
            row2Size   = false,                     -- false ＝ 第二列起跟第一列同尺寸；或 { w, h }
            fixedSlots = o.fixedSlots or false,     -- 增益不在時保留空位
        },
        follow     = { text = true, icon = true, glow = true, fade = true },
        text = {}, icon = {}, glow = {}, fade = {},
        visibility = { showCombat = false, showTarget = false, hideMounted = true,
                       onlyInstances = false, group = "any" },   -- group: any | solo | party | raid
        bar        = o.bar or false,        -- kind = "bars" 才有
        strata     = "MEDIUM",
    }
end

function DB.BuildDefaults()
    local buffbars = IconBar{
        source = "buffbars", pos = { point = "BOTTOM", x = 0, y = 300 },
        maxPerRow = 1, grow = "CENTER_DOWN", w = 200, h = 20,
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
    buffbars.kind = "bars"

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
                icon  = { zoom = 0.08, swipeColor = rgba(0, 0, 0, 0.8),
                          hideGCDSwipe = true, desaturateOnCooldown = true },
                glow  = {
                    proc  = { enabled = true,  type = "pixel", color = rgba(1, 0.85, 0, 1),
                              lines = 8, thickness = 2, frequency = 0.2 },
                    ready = { enabled = false, type = "pixel", color = rgba(0.3, 1, 0.3, 1),
                              lines = 8, thickness = 2, frequency = 0.2 },
                },
                -- 淡出後的透明度；false ＝ 這個條件不淡
                fade  = { outOfCombat = false, noTarget = 0.3, mounted = false },
                pandemic = { color = rgba(1, 0.5, 0, 1), bars = true },
            },
            bars = {
                essential = IconBar{ source = "essential", pos = { point = "CENTER", x = 0, y = -202 },
                                     w = 46, h = 40 },
                utility   = IconBar{ source = "utility",   pos = { point = "CENTER", x = 0, y = -250 },
                                     w = 26, h = 24,
                                     anchor = { to = "essential", point = "TOP", relPoint = "BOTTOM",
                                                x = 0, y = -1 } },
                buffs     = IconBar{ source = "buffs",     pos = { point = "CENTER", x = 0, y = -149 },
                                     w = 40, h = 36, grow = "CENTER_UP", fixedSlots = true },
                buffbars  = buffbars,
            },
            barOrder = { "essential", "utility", "buffs", "buffbars" },   -- 左欄順序，自訂群組接在後面
            spells   = {},                  -- [specID] = { order, groupOf, hidden, overrides, custom }
            -- 資源條與施法條的完整欄位在它們那一階段補；這裡先放位置與錨定
            resources = { enabled = true, pos = { point = "CENTER", x = 0, y = -180 },
                          anchor = { to = "essential", point = "BOTTOM", relPoint = "TOP", x = 0, y = 1 } },
            castbar   = { enabled = true, pos = { point = "CENTER", x = 0, y = -260 },
                          anchor = false, latency = true, ticks = true },
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
            if cur == nil then
                cur = {}
                dst[k] = cur
            end
            -- 使用者存了 false（例如 anchor = false）就尊重它，不把預設的表灌進去
            if type(cur) == "table" then MergeDefaults(cur, v) end
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
-- "glow.proc.type"、"icon.zoom"、"fade.mounted"），不管條把它存在哪張子表：
--
--   第一段           跟著 follow 的哪一項   條自己存在
--   font／outline     text                  bars[k].text.<path>
--   cooldownText／chargeText／stackText
--                     text                  bars[k].text.<path>
--   border            icon                  bars[k].icon.<path>
--   icon              icon                  bars[k].<path>（icon.zoom → bars[k].icon.zoom）
--   glow              glow                  bars[k].<path>
--   pandemic          glow                  bars[k].glow.<path>
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
