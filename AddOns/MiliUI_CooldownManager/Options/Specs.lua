------------------------------------------------------------
-- 設定表單的規格與接線（條頁與主題頁共用）
--
--   Specs.Themed(mode, key)       淡出（版面分頁）＋圖示／文字／效果／音效四節（mode = "bar" | "theme"；key ＝ 哪一條，長條沒有快捷鍵文字那一節）
--   Specs.Layout(key)             版面（條頁）
--   Specs.Visibility()            顯示條件（條頁）
--   Specs.Anchor(key)             錨定（條頁）：摘要＋「設定」鈕，內容在錨定視窗（Options/AnchorWindow.lua）
--   Specs.MakeCtx(info, onApply)  info = { mode, key }；onApply(spec) 在值寫進去之後叫
--   Specs.BuildForm(parent, controls, ctx, width) → form（content／height／Refresh）
--   Specs.SplitTabs(controls) ／ Specs.CreateTabStrip(...)  主題頁與條頁的分頁（檔尾，J）
--   Specs.FilterSubTab(specs, cur)  分頁裡的子分頁（倒數文字的冷卻｜增益持續時間，K）
--
-- 每條 spec 除了 Controls 要的欄位，另外帶：
--   root     "theme"：主題形狀的欄位（ns.Setting 的 path，條頁讀的是三層繼承後的值、
--            寫進條自己的子表；主題頁直接讀寫 profile.theme）
--            "bar"：條自己的欄位（版面、長條、顯示條件、錨定），不繼承
--            "bar@<key>"：同 "bar"，但讀寫**別的**條或面板（資源條頁上的自訂格子位置／錨定寫進
--            profile.pips）。帶在 root 上是因為 numbers 型的子格只會把 root／sub 往下傳
--   path     點分路徑（numbers 用 sub ＋ 欄位 key 拼）
--   section  "icon" | "text" | "glow" | "fade"：條頁勾著「跟隨全域主題」時整節蓋遮罩
--   get/set  自訂的讀寫（開關型的淡出、第二列尺寸、錨定…），收 info
--   refreshPage  寫完要重建表單（有列會出現／消失）
--   level    真實條的重排等級（預設 layout；錨定是 structure）
--   resetPaths  右鍵「重設為預設」要清哪些 path（預設就是 path）
--   fallback／fallbacks  重設時預設表沒有值的退路（fallbacks[path] 先、fallback 後）
--   disabled function(info) → 真 ＝ 這一列停用：蓋一層暗色遮罩（擋點擊與右鍵重設，值不動）。
--            表單引擎（共用層）沒有停用狀態，遮罩是 BuildForm 自己畫的；每次套用後重判
--   reloadCheck  寫完（含右鍵重設）檢查圖示外觀要不要重載（Specs.CheckSkinReload）
--   tab      頂層 header 才帶：這一節放在哪個分頁（Specs.SplitTabs；沒分頁的頁不看）
--   subTab   "cooldown" | "duration" | "charges" | "stacks"：只進那個子分頁的表單（K；Specs.FilterSubTab）
--   subGroup "cd" | "cs"：subTab 屬於哪一組子分頁（Specs.SUBTAB_GROUPS）
--   demo     示意的鍵（"gcd"、"readyFlash"、"debuffBorder"、"pandemic"、"chargeSwipe"…）：勾選框右邊掛示意「!」
--            （Specs.DemoMark，鍵的清單在那一節的 DEMOS）
--
-- ⚠ 條頁的主題欄位**讀的是繼承後的值**：沒跟隨、但這一格自己沒存的，看到的是主題的值。
--   顏色若直接回主題那張表，Controls 的色票會就地改掉主題（它拿到表就直接寫 r/g/b）。
--   所以條頁的主題顏色回一個代理表：讀照繼承、第一次寫才把值複製進條自己的子表。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W = ns.W

ns.Specs = {}
local Specs = ns.Specs

local LABEL_W = ns.WidgetsEnv.LABEL_W or 128
local EmptyModeRow       -- 版面那一節的「增益不在時」列（定義在下面）
local BarCfg, BlizzBarLook   -- 長條的外觀（bar.look）：這條的 bar 子表／生效的是不是暴雪樣式（定義在下面，GradientRows 前）
local CursorRow          -- 錨定那一節的「跟著游標」列（定義在下面）
local GlowSampleRow      -- 發光的預覽圖示（定義在下面）

------------------------------------------------------------
-- 下拉清單
------------------------------------------------------------
local function GrowItems(kind, vertical)
    if kind == "bars" and vertical then
        -- 直向長條（F8c）：條並排；值是直向圖示那組「伸展_換列」（Core/Layout.lua 的 VerticalBarGrow）
        return {
            { text = L["Align top, add bars to the right"],    value = "DOWN_RIGHT" },
            { text = L["Align top, add bars to the left"],     value = "DOWN_LEFT" },
            { text = L["Align bottom, add bars to the right"], value = "UP_RIGHT" },
            { text = L["Align bottom, add bars to the left"],  value = "UP_LEFT" },
        }
    end
    if kind == "bars" then
        return {
            { text = L["Downward"], value = "CENTER_DOWN" },
            { text = L["Upward"],   value = "CENTER_UP" },
        }
    end
    return {
        -- 橫向（值是「對齊_換列」；靠左 ＝ 往右長、靠右 ＝ 往左長，文字講伸展方向）
        { text = L["Grow outward from center, new rows below"], value = "CENTER_DOWN" },
        { text = L["Grow outward from center, new rows above"], value = "CENTER_UP" },
        { text = L["Grow right, new rows below"],               value = "LEFT_DOWN" },
        { text = L["Grow right, new rows above"],               value = "LEFT_UP" },
        { text = L["Grow left, new rows below"],                value = "RIGHT_DOWN" },
        { text = L["Grow left, new rows above"],                value = "RIGHT_UP" },
        -- 直向（值是「伸展_換列」，Core/Layout.lua 的 ParseColumn）
        { text = L["Grow down, new rows to the right"],         value = "DOWN_RIGHT" },
        { text = L["Grow down, new rows to the left"],          value = "DOWN_LEFT" },
        { text = L["Grow up, new rows to the right"],           value = "UP_RIGHT" },
        { text = L["Grow up, new rows to the left"],            value = "UP_LEFT" },
    }
end

local POINT_ITEMS = {
    { text = L["Top left"],     value = "TOPLEFT" },
    { text = L["Top"],          value = "TOP" },
    { text = L["Top right"],    value = "TOPRIGHT" },
    { text = L["Left"],         value = "LEFT" },
    { text = L["Center"],       value = "CENTER" },
    { text = L["Right"],        value = "RIGHT" },
    { text = L["Bottom left"],  value = "BOTTOMLEFT" },
    { text = L["Bottom"],       value = "BOTTOM" },
    { text = L["Bottom right"], value = "BOTTOMRIGHT" },
}
Specs.POINT_ITEMS = POINT_ITEMS           -- 單一法術小窗的「文字」分頁（Options/SpellPopover.lua）也用這張

local GLOW_ITEMS = {
    { text = L["Pixel"],          value = "pixel" },
    { text = L["Autocast"],       value = "autocast" },
    { text = L["Action button"],  value = "button" },
    { text = L["Proc"],           value = "proc" },
    { text = L["Border only"],    value = "border" },   -- 只變邊框顏色：不動畫，粗細滑桿是那一圈的寬（Core/Glow.lua）
}
Specs.GLOW_ITEMS = GLOW_ITEMS

-- 就緒發光亮多久（glow.ready.mode，Core/Glow.lua）
local READY_MODE_ITEMS = {
    { text = L["A few seconds"],         value = "timed" },
    { text = L["Until used"],            value = "untilUsed" },
    { text = L["Whenever it's ready"],   value = "whileReady" },
}

-- 冷卻狀態（icon.cdState，Core/Decorate.lua 的冷卻狀態效果）
local CDSTATE_ITEMS = {
    { text = L["No change"],              value = "none" },
    { text = L["Dim while on cooldown"],  value = "dim" },
    { text = L["Hide while on cooldown"], value = "hideOnCD" },
    { text = L["Hide when ready"],        value = "hideReady" },
}
Specs.CDSTATE_ITEMS = CDSTATE_ITEMS

-- 非正方形圖示：裁切保持比例（預設）｜拉伸（Layout.IconTexCoord）
local ASPECT_ITEMS = {
    { text = L["Crop to keep proportions"], value = "crop" },
    { text = L["Stretch to fit"],           value = "stretch" },
}

-- 圖示形狀（icon.shape，Core/Shape.lua）：米利樣式才有，Masque 模式由皮決定
local SHAPE_ITEMS = {
    { text = L["Square"],  value = "square" },
    { text = L["Rounded"], value = "rounded" },
    { text = L["Circle"],  value = "circle" },
}

local SIDE_ITEMS = {
    { text = L["Left"],  value = "LEFT" },
    { text = L["Right"], value = "RIGHT" },
    { text = L["None"],  value = "NONE" },
}
-- 直向長條（F8c）：同一個欄位，LEFT ＝ 上、RIGHT ＝ 下
local SIDE_ITEMS_V = {
    { text = L["Top"],    value = "LEFT" },
    { text = L["Bottom"], value = "RIGHT" },
    { text = L["None"],   value = "NONE" },
}

-- 「增益不在時」三態的選項（條層的版面列、單一法術小窗共用；每次給一份新表，呼叫端會改第一項）
function Specs.EmptyModeItems(isBars)
    return {
        { text = L["Hide, others move over"], value = "collapse" },
        { text = L["Hide, keep the slot"],    value = "blank" },
        { text = isBars and L["Empty bar in its place"] or L["Dimmed icon in its place"], value = "dim" },
    }
end

-- 選中那一項的說明（灰字）
function Specs.EmptyModeDesc(mode, isBars)
    if mode == "collapse" then
        return L["While a buff is missing, its slot closes up and the ones after it move over. It slides back in when the buff returns."]
    elseif mode == "blank" then
        return L["While a buff is missing, its slot stays empty, so the others don't shift."]
    end
    return isBars and L["While a buff is missing, an empty bar holds its slot, so the others don't shift."]
        or L["While a buff is missing, a dimmed icon holds its slot, so the others don't shift."]
end

-- 「往前補」不能選的原因；nil ＝ 能選。
-- 條層那一列（EmptyModeRow）：Bars.CollapseLocked 成立時叫——問的是「選了往前補之後還有沒有保護框」，飾品／藥水的增益疊層
-- 不算（選了往前補疊層就關掉，Catalog.BarOverlaysSuppressed）。原因照 Catalog.BarAuraFlow 的 why，說法點名格子與解法：
--   混排（mixed）：列出這條的光環格（最多 3 個）＋「移到別條、或這條只留光環格」；
--   這條自己沒有光環格、是被溢出來源條的光環格鎖住：點名來源條＋「移走那條的光環格、或取消它的溢出」；
--   某一格自己設了留空位／暗圖示（spell）：點名那幾格＋「改回跟隨條」；其餘（rings／clickable／overflow／row2）照舊一句。
-- forSpell（逐法術那一列，Bars.SpellEmptyForced）：單格選往前補不會關疊層，鎖是生效值——條層鎖住時同上；條只有光環格、
-- 但條層沒選收合 ⇒ EMPTY_FORCED_BAR；條只是被自己的疊層逼成固定格位 ⇒ 指向條層的往前補（EMPTY_FORCED_OVERLAY）。
-- EMPTY_FORCED（原本那句「有光環格或會顯示增益的飾品欄」）只剩當退路（判不出是哪一種時），語系條目不刪
Specs.EMPTY_FORCED = L["This bar has aura slots or trinkets showing their buff. They can't move during combat, so slots can't close up."]
Specs.EMPTY_FORCED_CLICK = L["This bar is clickable. The click targets can't move during combat, so slots can't close up."]
Specs.EMPTY_FORCED_MIXED = L["Aura slots %s share this bar with other slots. Aura slots can't move during combat, so slots can't close up. Move the aura slots to another bar, or keep only aura slots on this bar, and slots can close up."]
Specs.EMPTY_FORCED_FROM = L["The overflow source bar “%s” has aura slots. Aura slots that overflow here can't move during combat, so slots can't close up. Move those aura slots off that bar, or turn off its overflow, and slots can close up."]
Specs.EMPTY_FORCED_SPELL = L["Aura slots %s are set to leave their slot empty or show a dimmed icon, so slots can't close up. Set them back to follow the bar, and slots can close up."]
Specs.EMPTY_FORCED_OVERLAY = L["Trinkets or potions on this bar are showing their buff, and those can't move during combat. Set the whole bar to “Hide, others move over” (their buff overlays turn off), and this slot can close up too."]
Specs.EMPTY_FORCED_WHY = {
    mixed     = Specs.EMPTY_FORCED,
    rings     = L["Aura slots on a ring bar keep their ring, so slots can't close up."],
    clickable = Specs.EMPTY_FORCED_CLICK,
    overflow  = L["This bar has aura slots and sends or receives overflow icons, so slots can't close up."],
    spell     = L["An aura slot on this bar is set to leave its slot empty or show a dimmed icon, so slots can't close up."],
    row2      = L["This bar has aura slots and a different second-row size, so slots can't close up."],
}
Specs.EMPTY_FORCED_BAR = L["Aura slots only move over when the whole bar is set to “Hide, others move over”."]
-- 條層那一列的黃字提示（W.fontEmphasis，在底部灰字說明正上方）：Specs.EmptyModeHint 的兩種
Specs.EMPTY_HINT = {
    will = L["Picking “Hide, others move over” turns off the buff overlays of trinkets and potions on this bar (no buff duration or proc glow)."],
    off  = L["This bar is set to “Hide, others move over”, so trinkets and potions on it don't show their buff overlays (buff duration, proc glow)."],
}

-- 格子名字的清單：最多 3 個，超過寫「等 N 格」（N ＝ 總數）
function Specs.SlotNameList(ids)
    local names = {}
    for i, id in ipairs(ids) do
        if i > 3 then break end
        local inf = ns.Catalog.Info(id)
        names[#names + 1] = inf and inf.name or tostring(id)
    end
    local s = table.concat(names, L[", "])
    if #ids > 3 then s = L["%s and others (%d in all)"]:format(s, #ids) end
    return s
end

function Specs.EmptyModeForcedText(key, forSpell)
    local C = ns.Catalog
    if C.BarHasAuraSlot(key, true) then
        local ok, why = C.BarAuraFlow(key)
        if not ok then
            local own = C.BarAuraSlotIDs(key)
            if #own == 0 then
                -- 自己沒有光環格：鎖在溢出來源條的光環格（Catalog.OverflowAuraSources）
                local src = C.OverflowAuraSources(key)
                if #src > 0 then
                    local names = {}
                    for i, k in ipairs(src) do names[i] = ns.Options.PageTitle(k) or ns.Options.BarTitle(k) or k end
                    return Specs.EMPTY_FORCED_FROM:format(table.concat(names, L[", "]))
                end
                return Specs.EMPTY_FORCED
            end
            if why == "mixed" then return Specs.EMPTY_FORCED_MIXED:format(Specs.SlotNameList(own)) end
            if why == "spell" then
                local cells = {}
                for _, id in ipairs((C.BarBase(key))) do
                    local m = ns.SpellSetting(key, id, "emptyMode")
                    if C.IsAuraSlot(id) and (m == "blank" or m == "dim") then cells[#cells + 1] = id end
                end
                if #cells > 0 then return Specs.EMPTY_FORCED_SPELL:format(Specs.SlotNameList(cells)) end
            end
            return Specs.EMPTY_FORCED_WHY[why] or Specs.EMPTY_FORCED
        end
        if forSpell then return Specs.EMPTY_FORCED_BAR end
        return nil
    end
    if ns.DB.BarClickable(key) then return Specs.EMPTY_FORCED_CLICK end
    -- 逐法術：條只是被自己的飾品／藥水疊層逼成固定格位（條層選往前補就解開）
    if forSpell and C.BarHasAuraSlot(key) then return Specs.EMPTY_FORCED_OVERLAY end
    return nil
end

-- 條層那一列要不要黃字提示 → "will"｜"off"｜nil（進 BarSignature：出不出現決定列高）
--   will：往前補能選（沒被 CollapseLocked 鎖住）、現在疊層還在（沒 suppress）、而且這條有「不看往前補的話會疊」的格子
--   off ：條層選了往前補、疊層已經關掉（BarOverlaysSuppressed）、而且有那種格子
function Specs.EmptyModeHint(key)
    local C, B = ns.Catalog, ns.Bars
    if not (C and B and B.CollapseLocked and C.BarOverlaysSuppressed) then return nil end
    if not ns.DB.BarTable(key) or ns.DB.BarIsRings(key) then return nil end
    if not C.BarHasOverlayCandidates(key) then return nil end
    if C.BarOverlaysSuppressed(key) then return "off" end
    if B.CollapseLocked(key) then return nil end
    return "will"
end

local GROUP_ITEMS = {
    { text = L["Any"],   value = "any" },
    { text = L["Solo"],  value = "solo" },
    { text = L["Party"], value = "party" },
    { text = L["Raid"],  value = "raid" },
}

-- 音效聲道（PlaySoundFile 的第二個參數；值是暴雪的聲道名，不翻）
local CHANNEL_ITEMS = {
    { text = L["Master"],        value = "Master" },
    { text = L["Sound effects"], value = "SFX" },
    { text = L["Music"],         value = "Music" },
    { text = L["Ambience"],      value = "Ambience" },
    { text = L["Dialog"],        value = "Dialog" },
}

local OUTLINE_ITEMS = {
    { text = L["None"],          value = "" },
    { text = L["Outline"],       value = "OUTLINE" },
    { text = L["Thick outline"], value = "THICKOUTLINE" },
    -- 單色＝關掉反鋸齒：像素字體用（一般字型選了邊緣會有鋸齒）
    { text = L["Monochrome outline"],       value = "MONOCHROME,OUTLINE" },
    { text = L["Monochrome thick outline"], value = "MONOCHROME,THICKOUTLINE" },
}
Specs.OUTLINE_ITEMS = OUTLINE_ITEMS       -- 自訂格子每一列的數字描邊（Options/Tab_Resources.lua）也用這張

-- 倒數的時間格式（Core/Text.lua 的 TimeFormat）：例子裡的「分」照客戶端語系（暴雪冷卻倒數的全域字串，引擎印的就是它）
local function TimeFormatItems()
    local m = ns.Text.UnitFormat("COOLDOWN_DURATION_MIN", "%dm")
    return {
        { text = L["Minutes (%s)"]:format(m:format(2) .. " → 90"), value = "minutes" },
        { text = L["Minutes:seconds (%s)"]:format(m:format(3) .. " → 2:00"), value = "mmss" },
    }
end

local function MediaItems(first, kind)
    return function()
        local items = { first }
        for _, name in ipairs(ns.Media.List(kind)) do
            items[#items + 1] = { text = name, value = name }
        end
        return items
    end
end
local BorderItems  = MediaItems({ text = L["Solid"], value = "solid" }, "border")
local TextureItems = MediaItems({ text = L["Solid"], value = "solid" }, "statusbar")
local FontItems    = MediaItems({ text = L["Default font"], value = "DEFAULT" }, "font")
Specs.TextureItems, Specs.FontItems = TextureItems, FontItems

-- 各段文字自己的字型：第一項「跟隨通用字型」（存 "INHERIT"），接著同通用字型的清單
local function ElementFontItems()
    local items = FontItems()
    table.insert(items, 1, { text = L["Follow general font"], value = ns.Media.INHERIT })
    return items
end
Specs.ElementFontItems = ElementFontItems

-- 下拉的值：沒存過（舊存檔、自訂群組）一律顯示成「跟隨通用字型」
local function InheritOr(v)
    return (type(v) == "string" and v ~= "") and v or ns.Media.INHERIT
end
Specs.InheritOr = InheritOr

------------------------------------------------------------
-- 讀寫（主題欄位在條頁與主題頁走不同的表）
------------------------------------------------------------
local function PathOf(spec)
    if spec.path then return spec.path end
    if spec.sub then return spec.sub .. "." .. spec.key end
    return spec.key
end
Specs.PathOf = PathOf

local function ReadThemed(info, path)
    if info.mode == "theme" then return ns.Setting("theme", path) end
    return ns.Setting(info.key, path)
end

local function WriteThemed(info, path, v)
    local p = ns.profile
    if not p then return end
    if info.mode == "theme" then
        ns.DB.SetPath(p.theme, path, v)
    else
        ns.DB.OwnSet(info.key, path, v)
    end
end
Specs.ReadThemed, Specs.WriteThemed = ReadThemed, WriteThemed

-- 代理表本身沒有狀態（每次存取都現讀 ns.Setting／現寫 DB.OwnSet），換設定檔也照樣對 ⇒
-- 以 key|path 快取，表單每次刷新都 ctx.get 不必每次配一張新表
local proxyCache = {}
local function ColorProxy(key, path)
    local ck = tostring(key) .. "|" .. tostring(path)
    local hit = proxyCache[ck]
    if hit then return hit end
    local proxy = setmetatable({}, {
        __index = function(_, k)
            local c = ns.Setting(key, path)
            return type(c) == "table" and c[k] or nil
        end,
        __newindex = function(_, k, v)
            local own = ns.DB.OwnGet(key, path)
            if type(own) ~= "table" then
                own = {}
                local src = ns.Setting(key, path)
                if type(src) == "table" then
                    for kk, vv in pairs(src) do own[kk] = vv end
                end
                ns.DB.OwnSet(key, path, own)
            end
            own[k] = v
        end,
    })
    proxyCache[ck] = proxy
    return proxy
end

-- root 是 "bar@<key>" 時的目標；其他回 nil（讀寫表單自己的 info.key）
local function TargetOf(spec)
    local r = spec and spec.root
    return type(r) == "string" and r:match("^bar@(.+)$") or nil
end
Specs.TargetOf = TargetOf

function Specs.MakeCtx(info, onApply)
    local ctx
    ctx = ns.Controls.MakeCtx(function() return {} end, function()
        onApply(ctx.lastSpec)
    end)
    ctx.info = info
    ctx.get = function(spec)
        if spec.get then return spec.get(info) end
        local path = PathOf(spec)
        if spec.root == "theme" then
            if info.mode ~= "theme" and spec.type == "color" then return ColorProxy(info.key, path) end
            return ReadThemed(info, path)
        end
        return ns.DB.GetPath(ns.DB.ConfigTable(TargetOf(spec) or info.key), path)
    end
    ctx.set = function(spec, v)
        ctx.lastSpec = spec
        if spec.set then spec.set(info, v) return end
        local path = PathOf(spec)
        if spec.root == "theme" then
            WriteThemed(info, path, v)
        else
            ns.DB.SetPath(ns.DB.ConfigTable(TargetOf(spec) or info.key), path, v)
        end
    end
    return ctx
end

------------------------------------------------------------
-- spec 小工具
------------------------------------------------------------
local function Merge(s, extra)
    if extra then for k, v in pairs(extra) do s[k] = v end end
    return s
end

local function TS(section, kind, path, label, extra)
    return Merge({ type = kind, root = "theme", path = path, key = path, label = label, section = section }, extra)
end

local function BS(kind, path, label, extra)
    return Merge({ type = kind, root = "bar", path = path, key = path, label = label }, extra)
end

-- 某段文字的字型下拉（主題繼承那一類）
local function FontTS(section, path)
    return TS(section, "dropdown", path, L["Font"], { items = ElementFontItems,
        get = function(info) return InheritOr(ReadThemed(info, path)) end })
end

-- 某段文字的字型下拉（條自己的欄位）
local function FontBS(path, label)
    return BS("dropdown", path, label, { items = ElementFontItems,
        get = function(info) return InheritOr(ns.DB.GetPath(ns.DB.ConfigTable(info.key), path)) end })
end

-- 錨點九宮格（取代錨點下拉）：3×3 小方格對應圖示的九個角／邊／中心，選中的塗職業色，右邊灰字寫名稱。
-- 讀寫照一般主題欄位（ctx.get／ctx.set 看 root／path），右鍵標籤照樣重設（resettable）
local POINT_TEXT = {}
for _, it in ipairs(POINT_ITEMS) do POINT_TEXT[it.value] = it.text end
local GRID_CELL, GRID_GAP, GRID_PAD = 14, 2, 4
local GRID_IDLE, GRID_HOVER = { 0.28, 0.28, 0.28, 1 }, { 0.45, 0.45, 0.45, 1 }

local function PointGridTS(section, path, label, fallback)
    local side = GRID_CELL * 3 + GRID_GAP * 2
    local spec = TS(section, "custom", path, label, { resettable = true, h = side + GRID_PAD * 2 })
    spec.build = function(parent, x, y, _, ctx)
        local holder = CreateFrame("Frame", nil, parent)
        holder:SetSize(side, side)
        holder:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - GRID_PAD)
        local name = parent:CreateFontString(nil, "OVERLAY")
        name:SetFontObject(W.fontSmall)
        name:SetTextColor(0.65, 0.65, 0.65)
        name:SetPoint("LEFT", holder, "RIGHT", 8, 0)
        local cells, cur = {}, nil
        local function Paint()
            for _, b in ipairs(cells) do
                if b.point == cur then b:SetBackdropColor(W.Accent(1))
                else b:SetBackdropColor(unpack(b.hover and GRID_HOVER or GRID_IDLE)) end
            end
            name:SetText(POINT_TEXT[cur] or "")
        end
        for i, it in ipairs(POINT_ITEMS) do
            local b = CreateFrame("Button", nil, holder, "BackdropTemplate")
            b:SetSize(GRID_CELL, GRID_CELL)
            b:SetPoint("TOPLEFT", ((i - 1) % 3) * (GRID_CELL + GRID_GAP), -math.floor((i - 1) / 3) * (GRID_CELL + GRID_GAP))
            W.Stylize(b, GRID_IDLE, { 0, 0, 0, 1 })
            b.point = it.value
            b:SetScript("OnEnter", function() b.hover = true; Paint() end)
            b:SetScript("OnLeave", function() b.hover = false; Paint() end)
            b:SetScript("OnClick", function()
                if cur == it.value then return end
                cur = it.value
                ctx.set(spec, cur)
                ctx.apply()
                Paint()
            end)
            cells[i] = b
        end
        return spec.h, function()
            cur = ctx.get(spec) or fallback
            Paint()
        end
    end
    return spec
end

local function Note(label, section)
    return { type = "text", label = label, section = section }
end

local function Nested(label, section)
    return { type = "header", label = label, nested = true, section = section }
end

------------------------------------------------------------
-- 子分頁（K：倒數文字的「冷卻｜增益持續時間」）
--
-- 表單引擎沒有「藏列」：子分頁的每一個選擇各是一張表單（同分頁的做法往下一層）。spec 帶 subTab 的列
-- 只進那個子分頁的表單（Specs.FilterSubTab）；子分頁鈕那一列（SubTabRow）點了叫 ctx.onSubTab(id)，
-- 頁面換一張表單、捲動位置不動（子分頁鈕上面的列兩張表單一模一樣）。目前選哪個存在 ctx.subTab（頁面建表單時填）。
-- 一張表單可以有好幾組子分頁（SUBTAB_GROUPS），spec 的 subGroup 講是哪一組
-- 卡片（L）：子分頁鈕＋底下一張卡片包住子分頁的列（W.CreateTabCard）。卡片是 content 上的貼圖 ⇒ 列與遮罩都在它上面；
-- 鈕列這一列建卡片、記在 ctx.tabCards[組]，底緣等 BuildForm 排完才知道（同一組最後一個帶 subTab 的列）
------------------------------------------------------------
local SUBTAB_DEFS = {
    { id = "cooldown", label = L["Cooldown"] },
    { id = "duration", label = L["Buff duration"] },
}
Specs.SUBTAB_DEFS = SUBTAB_DEFS

-- 子分頁卡片的「!」說明（W.CreateTabCard 的 help）：兩種各一行，名稱上強調黃（共用層 W.EMPHASIS_COLOR）
function Specs.SubTabHelp()
    local c = W.EMPHASIS_COLOR or { r = 1, g = 0.82, b = 0 }
    local hex = string.format("ff%02x%02x%02x", math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))
    local function Y(t) return "|c" .. hex .. t .. "|r" end
    return L["%s: the countdown while the spell recharges."]:format(Y(L["Cooldown"])) .. "\n"
        .. L["%s: the countdown of a buff, on buff icons and in the part where a spell shows its buff's time first."]:format(Y(L["Buff duration"]))
end

-- 子分頁組（一張表單可以有好幾張卡片，各自選）：
--   cd  倒數的「冷卻｜增益持續時間」（K）
--   cs  「充能｜層數」（兩節控件幾乎一樣；拆成兩節時表單太長、法術小窗超出螢幕，使用者 2026-10-06）
-- 頁面記目前的選擇在一張表 { cd = id, cs = id }（ctx.subTab），表單快取 key 用 Specs.SubTabKey
-- labels：卡片裡會出現的標籤（所有組一起量最長的那個定卡片左緣，兩張卡片才對齊）；gap：鈕列上方多留的距離（cs 緊接在 cd 卡片底下）
local SUBTAB_GROUPS = {
    cd = { tabs = SUBTAB_DEFS, help = Specs.SubTabHelp, gap = 0,
           labels = { "Decimals below", "Color when low", "Low color", "Low below (sec)" } },
    cs = { tabs = { { id = "charges", label = L["Charges"] }, { id = "stacks", label = L["Stacks"] } }, gap = 10,
           labels = { "Hide charges", "Hide stacks", "Font", "Font size", "Color", "Anchor", "Anchor (bars)", "Offset" } },
}
Specs.SUBTAB_GROUPS = SUBTAB_GROUPS
local SUBTAB_ORDER = { "cd", "cs" }

-- 新頁面的選擇表：每組第一個
function Specs.NewSubTabs()
    local t = {}
    for g, def in pairs(SUBTAB_GROUPS) do t[g] = def.tabs[1].id end
    return t
end

local SUBTAB_BTN_H, SUBTAB_BTN_MIN_W = 20, 56
-- 卡片（L，W.CreateTabCard）：左右邊跟設定列同寬（見 SubTabRow）；
-- 上緣＝子分頁鈕列底，底＝這張表單同一組最後一個帶 subTab 的列（BuildForm 排完之後補）
local CARD_TOP = 4
-- 卡片左右界：控件欄起點 x 往左扣「標籤與控件的間距＋最長標籤＋內距」，往右到標準控件寬＋內距（共用層 Controls 的版面常數）
local CARD_GAP, CARD_PAD_X, CARD_CTRL_W, CARD_LABEL_MAX = 12, 10, 230, 128

-- 卡片裡的列：控件欄收在卡片右緣內（說明灰字在卡片裡換行、下拉不撐出卡片；共用層 Controls 的 maxW）
local function Sub(id, spec, group)
    if spec then
        spec.subTab = id
        spec.subGroup = group or "cd"
        spec.maxW = CARD_CTRL_W
    end
    return spec
end
Specs.Sub = Sub

local function SubTabRow(group)
    group = group or "cd"
    local def = SUBTAB_GROUPS[group]
    return { type = "custom", noReset = true, build = function(parent, x, y, width, ctx)
        local sel = type(ctx.subTab) == "table" and ctx.subTab or {}
        local tc = W.CreateTabCard(parent, {
            tabs = def.tabs, tabHeight = SUBTAB_BTN_H, tabMinWidth = SUBTAB_BTN_MIN_W,
            help = def.help,
            selected = sel[group] or def.tabs[1].id,
            onSelect = function(id)
                if id ~= sel[group] and ctx.onSubTab then ctx.onSubTab(group, id) end
            end,
        })
        -- 卡片跟上面的設定列同寬（使用者 2026-10-06：「太胖了，應該和上面一樣的縮排」）：
        -- 左緣＝卡片裡最長的標籤再外推一點（標籤欄靠右對齊，長度依語系），右緣＝控件欄的右緣（標準控件寬）
        -- 量的是**每一組**的標籤：一張表單有兩張卡片時左緣要對齊（使用者 2026-10-06）
        local measure = parent:CreateFontString(nil, "OVERLAY")
        measure:SetFontObject(W.fontNormal)
        local labelW = 0
        for _, g in pairs(SUBTAB_GROUPS) do
            for _, k in ipairs(g.labels) do
                measure:SetText(L[k])
                labelW = math.max(labelW, math.ceil(measure:GetStringWidth() or 0))
            end
        end
        measure:Hide()
        labelW = math.min(labelW, CARD_LABEL_MAX)
        local left = math.max(0, x - CARD_GAP - labelW - CARD_PAD_X)
        local right = math.min(x + width, x + CARD_CTRL_W + CARD_PAD_X)
        local top = CARD_TOP + def.gap
        local h = tc:Place(left, y - top, right - left)
        ctx.tabCards = ctx.tabCards or {}
        -- x：卡片裡停用列的遮罩只蓋卡片內（BuildForm）
        ctx.tabCards[group] = { card = tc, x = { left = left, right = right } }
        local function Paint() tc:Select(sel[group] or def.tabs[1].id) end
        Paint()
        return top + h + W.TAB_CARD_PAD, Paint
    end }
end

-- 帶 subTab 的列所在卡片的左右界：給 BuildForm 的停用遮罩用（ctx.tabCardX 是資源設定小窗自己的單一卡片）
local function CardX(ctx, spec)
    if not spec.subTab then return nil end
    local cards = ctx.tabCards
    local c = cards and cards[spec.subGroup or "cd"]
    if c then return c.x end
    return ctx.tabCardX
end

-- → 這個子分頁要的列（沒帶 subTab 的列一律留下）, 這串列有沒有子分頁
-- cur：選擇表（{ cd = id, cs = id }，Specs.NewSubTabs）；字串＝只有一組、spec 不分組（資源設定小窗自己的子分頁）
function Specs.FilterSubTab(specs, cur)
    local out, has = {}, false
    for _, spec in ipairs(specs) do
        if spec.subTab then has = true end
        local keep = not spec.subTab
        if not keep then
            if type(cur) == "table" then
                local g = spec.subGroup or "cd"
                keep = spec.subTab == (cur[g] or SUBTAB_GROUPS[g].tabs[1].id)
            else
                keep = spec.subTab == (cur or SUBTAB_DEFS[1].id)
            end
        end
        if keep then out[#out + 1] = spec end
    end
    return out, has
end

-- 表單快取 key 的子分頁那一段（每組依序接起來）
function Specs.SubTabKey(cur)
    local parts = {}
    for _, g in ipairs(SUBTAB_ORDER) do parts[#parts + 1] = cur[g] or SUBTAB_GROUPS[g].tabs[1].id end
    return table.concat(parts, "/")
end

-- 「本條 N 個法術有覆寫 ［清除覆寫］」：畫在小節標題那一行的右側，本身不佔高度
local function OverrideRow(group)
    return { type = "custom", h = 0, noReset = true, build = function(parent, x, y, width, ctx)
        local btn = W.CreateButton(parent, L["Clear overrides"], "normal", 90, 18)
        W.FitButton(btn, 90, 18)
        -- 小節標題的字在這一列上方 12 左右（HEADER_H 24 的中線）
        btn:SetPoint("RIGHT", parent, "TOPLEFT", x + width, y + 12)
        local fs = parent:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontSmall)
        fs:SetPoint("RIGHT", btn, "LEFT", -8, 0)
        fs:SetTextColor(0.65, 0.65, 0.65)
        local confirm
        local function Ids()
            local out, hid = ns.Catalog.Bar(ctx.info.key, true)
            for _, id in ipairs(hid or {}) do out[#out + 1] = id end
            return out
        end
        btn:SetScript("OnClick", function()
            if not confirm then
                confirm = W.CreateConfirmPopup(ns.Options.panel, 320,
                    L["Clear this section's per-spell overrides on this bar?"], function()
                        ns.DB.ClearOverrides(Ids(), group)
                        ctx.lastSpec = { level = "layout" }
                        ctx.apply()
                        if ctx.form then ctx.form:Refresh() end
                    end)
            end
            confirm:Show()
        end)
        local function Refresh()
            local n = ns.DB.CountOverrides(Ids(), group)
            fs:SetText(L["%d spells on this bar have overrides"]:format(n))
            fs:SetShown(n > 0)
            btn:SetShown(n > 0)
        end
        return 0, Refresh
    end }
end

-- 自訂語音那一列：按鈕寫著目前筆數，點開是編輯器（Options/CustomSounds.lua）
local function CustomSoundsRow()
    return { type = "custom", label = L["Custom sounds"], h = 30, noReset = true, build = function(parent, x, y)
        local btn = W.CreateButton(parent, "", "normal", 160, 22)
        btn:SetPoint("LEFT", parent, "TOPLEFT", x, y - 15)
        local function UpdateText()
            btn:SetText(L["Edit list (%d)"]:format(ns.CustomSounds.Count()))
            W.FitButton(btn, 160, 22)
        end
        btn:SetScript("OnClick", function() ns.CustomSounds.Open(UpdateText) end)
        UpdateText()
        return 30, UpdateText
    end }
end

local function FollowToggle(group)
    -- 圖示那一節的跟隨：開關一切換，這條實際要的圖示外觀（米利／Masque）可能就變了
    return BS("toggle", "follow." .. group, L["Follow global theme"],
        { refreshPage = true, level = "layout", reloadCheck = group == "icon" or nil })
end

------------------------------------------------------------
-- 圖示外觀（米利／Masque）
--
-- 值是 icon.skin，跟其他圖示設定一樣走主題 → 條的繼承。切換**要重載才生效**（Core/Masque.lua：
-- 每條的模式登入時就定了）⇒ 值寫進去之後，只要有哪一條「設定要的」跟「現在畫的」不同就問要不要重載；
-- 取消就留著設定、下次重載生效，同一個組合不再追問。
-- 選 Masque 時，交給 Masque 的那幾項（邊框材質／粗細／顏色、圖示縮放）停用。
-- 判斷看**設定值**（Desired）而不是現在畫面上的樣子：玩家選了 Masque，那幾格就已經不歸這裡管。
------------------------------------------------------------
local SKIN_ITEMS = {
    { text = L["MiliUI style"], value = "miliui" },
    { text = "Masque",          value = "masque" },
}

local function SkinKey(info) return info.mode == "theme" and "theme" or info.key end

local function MasqueOwns(info)
    return ns.Masque and ns.Masque.Desired(SkinKey(info)) == "masque" or false
end

-- 邊框那三列：交給 Masque、或長條的暴雪樣式（原生長條沒有邊框，只在無損刷新期間照這三格亮一圈）時停用
local function BorderOff(info)
    return MasqueOwns(info) or BlizzBarLook(info)
end

local reloadPopup, askedSig
function Specs.CheckSkinReload()
    local Mq = ns.Masque
    if not (Mq and Mq.NeedsReload()) then return end
    local sig = Mq.ModesSig()
    if sig == askedSig then return end
    askedSig = sig
    if not reloadPopup then
        reloadPopup = W.CreateConfirmPopup(ns.Options.panel, 320,
            L["The icon style change takes effect after reloading the UI. Reload now?"], function() ReloadUI() end)
    end
    reloadPopup:Show()
end

-- 「開啟 Masque 設定」：只在這條現在真的交給 Masque 的時候能按（群組登入時才建，
-- 還沒重載的話 Masque 裡找不到我們）
local function MasqueOptionsRow()
    return { type = "custom", h = 30, section = "icon", noReset = true, build = function(parent, x, y, width, ctx)
        local btn = W.CreateButton(parent, L["Open Masque settings"], "normal", 140, 22)
        W.FitButton(btn, 140, 22)
        btn:SetPoint("LEFT", parent, "TOPLEFT", x, y - 15)
        btn:SetScript("OnClick", function() ns.Masque.OpenOptions() end)
        local function Refresh()
            btn:SetEnabled(ns.Masque.Mode(SkinKey(ctx.info)) == "masque")
        end
        return 30, Refresh
    end }
end

-- 圖示形狀與陰影的說明列：平常是灰字；圖示外觀選 Masque 時換成黃字（形狀與陰影交給皮，上面三列停用）。
-- 寫法同 CursorRow（表單引擎的灰字列不會換字），高度取兩種說法裡最高的
local function ShapeNoteRow()
    local NORMAL = L["Rounded and circle also shape the border, the cooldown swipe and the key press flash. Non-square icons stretch the shape. Bars and rings stay square."]
    local MSQ = L["With Masque as the icon style, the skin decides the shape and shadow."]
    return { type = "custom", section = "icon", noReset = true, h = 26, build = function(parent, x, y, width, ctx)
        local fs = parent:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontSmall)
        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 4)
        fs:SetWidth(width)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        local tallest = 14
        for _, t in ipairs({ NORMAL, MSQ }) do
            fs:SetText(t)
            tallest = math.max(tallest, fs:GetStringHeight() or 14)
        end
        local function Refresh()
            local msq = MasqueOwns(ctx.info)
            fs:SetFontObject(msq and W.fontEmphasis or W.fontSmall)
            fs:SetText(msq and MSQ or NORMAL)
        end
        return math.max(26, tallest + 10), Refresh
    end }
end

local function SkinRows()
    local available = ns.Masque and ns.Masque.Available()
    local rows = {
        TS("icon", "dropdown", "icon.skin", L["Icon style"], {
            items = SKIN_ITEMS, reloadCheck = true,
            get = function(info) return ReadThemed(info, "icon.skin") or "miliui" end,
            disabled = function() return not (ns.Masque and ns.Masque.Available()) end,
        }),
    }
    if available then
        rows[#rows + 1] = Note(L["Masque draws the border, icon crop and swipe texture with the skin picked in its own settings; text, colors and glows stay here. Switching needs a UI reload."], "icon")
        rows[#rows + 1] = MasqueOptionsRow()
    else
        rows[#rows + 1] = Note(L["Install Masque to pick its skins here."], "icon")
    end
    return unpack(rows)
end

------------------------------------------------------------
-- 圖示／文字／效果（條頁與主題頁同一份）
------------------------------------------------------------
-- 長條上的名字／時間（條自己的欄位，不跟主題）：放在「文字」分頁、長條類的條才有
-- （原本在「版面」分頁最底下，玩家找不到「顯示名字」，2026-10-07 搬過來）。
-- 名字開關：直向不畫名字（「垂直」的灰字寫了原因）⇒ 直向時開關本身也停用；名字關掉或直向 ⇒ 名字字型／字級兩列停用
local function BarTextRows()
    local function IsVertical(info) return ns.DB.GetPath(ns.DB.ConfigTable(info.key), "bar.vertical") and true or false end
    local function NoName(info)
        return IsVertical(info) or not ns.DB.GetPath(ns.DB.ConfigTable(info.key), "bar.showName")
    end
    local nf = FontBS("bar.nameFont", L["Name font"])
    nf.disabled = NoName
    return {
        Nested(L["Bar text"]),
        BS("toggle", "bar.showName", L["Show name"], { disabled = IsVertical }),
        nf,
        BS("slider", "bar.nameSize", L["Name size"], { min = 6, max = 30, step = 1, disabled = NoName }),
        -- 名字／秒數的位移（整條共用；秒數的逐法術偏移疊在上面）：字型的行高把下伸部留在底下，置中後看起來偏上
        BS("numbers", nil, L["Name offset"], { sub = "bar.nameOffset", path = false, disabled = NoName,
            resetPaths = { "bar.nameOffset.x", "bar.nameOffset.y" }, fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } }),
        FontBS("bar.timeFont", L["Time font"]),
        BS("slider", "bar.timeSize", L["Time size"], { min = 6, max = 30, step = 1 }),
        BS("numbers", nil, L["Time offset"], { sub = "bar.timeOffset", path = false,
            resetPaths = { "bar.timeOffset.x", "bar.timeOffset.y" }, fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } }),
    }
end

function Specs.Themed(mode, key)
    local bar = mode == "bar"
    local list = {}
    local function add(...)
        for i = 1, select("#", ...) do
            local s = select(i, ...)
            if s then list[#list + 1] = s end
        end
    end
    -- 增益兩條（內建）沒有冷卻：觸發發光（技能的觸發亮框）、就緒發光、冷卻中去飽和、隱藏 GCD 轉圈都用不到
    local auraBar = bar and key and ns.DB.IsBuiltinBar(key) and ns.Viewers.AURA_KIND[key] and true or false
    local function CD(s) if auraBar then return nil end return s end
    -- 反過來：核心／輔助（內建的冷卻兩條）沒有光環，減益邊框用不到
    local cdBar = bar and key and ns.DB.IsBuiltinBar(key) and not ns.Viewers.AURA_KIND[key] and true or false
    local function AU(s) if cdBar then return nil end return s end
    -- 冷卻狀態效果：增益兩條（內建）與長條類的條用不到（長條上的自訂冷卻也不套：Decorate 對長條不給 cdState）
    local bt = bar and key and ns.DB.BarTable(key)
    local barsKind = type(bt) == "table" and bt.kind == "bars" or false
    local function CS(s) if auraBar or barsKind then return nil end return s end
    -- 長條類的條：倒數與充能的文字樣式用不到（長條的秒數字型／字級在「長條」節；秒數是暴雪每幀寫的，
    -- 小數門檻與低秒變色都換不了），只留層數
    local function NB(s) if barsKind then return nil end return s end
    -- 反過來只有長條類的條（與主題頁）才出：長條上圖示的位置
    local function BO(s) if bar and not barsKind then return nil end return s end
    local barsVertical = barsKind and type(bt.bar) == "table" and bt.bar.vertical and true or false
    -- 按鍵鏡射：長條類與增益圖示列不做（Core/Keybinds.lua 的 NoKeybind 同時涵蓋兩者）
    local noPress = bar and key and ns.Keybinds.NoKeybind(key) or false
    local function NK(s) if noPress then return nil end return s end
    local function NotDim(info) return (ReadThemed(info, "icon.cdState") or "none") ~= "dim" end
    -- 像素發光的線條數／粗細：粗細像素與「只變邊框顏色」吃；線條數像素與自動施法都吃（玩家回報邊框太粗、以前習慣設 1）
    local function NoThickness(path)
        return function(info)
            local t = ReadThemed(info, path) or "pixel"
            return t ~= "pixel" and t ~= "border"
        end
    end
    local function NoLines(path)
        return function(info)
            local t = ReadThemed(info, path) or "pixel"
            return t ~= "pixel" and t ~= "autocast"
        end
    end
    local function AuraTimeOff(info) return ReadThemed(info, "icon.showAuraTime") == false end
    local function DurationOff(info) return AuraTimeOff(info) or not ReadThemed(info, "icon.colorDuration") end
    -- 增益持續時間的變色顏色／變色秒數：只有增益持續時間的低秒變色（I）用得到 ⇒ 開關關著就停用
    -- （換色那一段的字色是「增益持續時間顏色」，低秒那一段的顏色不歸換色開關管：Text.BuffTiming）
    local function BuffLowOff(info) return not ReadThemed(info, "cooldownText.buffLowColor") end
    -- 冷卻那一組同理：開關 lowColorOn 關著時變色顏色／變色秒數停用（跟增益持續時間那組一樣蓋遮罩）。
    -- 開關只認 false 是關（引擎 Text.CdLowBelow 同一個判準：沒存 ＝ 開）
    local function CdLowOff(info) return ReadThemed(info, "cooldownText.lowColorOn") == false end

    -- 淡出：歸「版面」分頁（整條怎麼出現，跟圖示的長相無關；使用者 2026-10-06 從「效果」搬來）。
    -- 主題頁因此多一個「版面」分頁排最前面；條頁接在版面與錨定後面（Tab_Bar 的 Concat 順序）
    -- 小地圖按鈕（帳號層 minimap.hide，不跟設定檔走）：主題頁「版面」分頁的第一列（還沒有分頁 header ⇒ SplitTabs 歸第一個分頁＝版面）
    if not bar then
        add({ type = "toggle", label = L["Show minimap button"], noReset = true,
            get = function() return ns.IsMinimapButtonShown() end,
            set = function(_, v) ns.SetMinimapButtonShown(v and true or false) end })
    end
    add({ type = "header", label = L["Fade"], tab = "layout" })
    if bar then add(BS("toggle", "follow.fade", L["Follow global theme"], { refreshPage = true })) end
    add(TS("fade", "toggle", "fade.enabled", L["Fade the bar"]),
        TS("fade", "slider", "fade.alpha", L["Faded opacity"], { min = 0, max = 100, step = 5, scale = 100 }),
        Note(L["0 hides it completely."], "fade"),
        Nested(L["Stay fully visible when"], "fade"),
        TS("fade", "toggle", "fade.keepInCombat", L["In combat"]),
        TS("fade", "toggle", "fade.keepWithTarget", L["Has a target"]),
        Note(L["Any checked condition that holds keeps the bar fully visible. With none checked it stays faded whenever fading is on."], "fade"),
        TS("fade", "toggle", "fade.whenMounted", L["Always fade while mounted"]),
        Note(L["Mounted or in a vehicle: fades regardless of the conditions above."], "fade"))

    -- 圖示
    add({ type = "header", label = L["Icons"], tab = "icon" })
    if bar then add(OverrideRow("icon"), FollowToggle("icon"),
        Note(L["While checked, this section uses the Theme page. Uncheck it to give this bar its own values."])) end
    add(SkinRows())
    -- 長條上圖示的位置（主題欄位 icon.barIconSide；長條類的條才讀，2026-10-24 從條頁「版面」搬來）：直向的條字換成上／下
    add(BO(TS("icon", "dropdown", "icon.barIconSide", L["Icon position"], { items = barsVertical and SIDE_ITEMS_V or SIDE_ITEMS,
            get = function(info) return ReadThemed(info, "icon.barIconSide") or "LEFT" end })),
        BO(Note(barsKind and L["“None” hides the icon; the bar takes the whole cell."]
            or L["Long bars only. “None” hides the icon; the bar takes the whole cell. On a vertical bar, left means top and right means bottom."], "icon")))
    add(TS("icon", "dropdown", "border.texture", L["Border texture"], { items = BorderItems, disabled = BorderOff }),
        TS("icon", "slider", "border.size", L["Border size"], { min = 0, max = 4, step = 1, disabled = BorderOff }),
        TS("icon", "color", "border.color", L["Border color"], { disabled = BorderOff }),
        TS("icon", "slider", "icon.zoom", L["Icon zoom"], { min = 0, max = 0.2, step = 0.01, disabled = MasqueOwns }),
        Note(L["Crops the icon edges; 0 shows the whole texture."], "icon"),
        TS("icon", "dropdown", "icon.aspect", L["Non-square icons"], { items = ASPECT_ITEMS, disabled = MasqueOwns,
            get = function(info) return ReadThemed(info, "icon.aspect") or "crop" end }),
        -- 圖示形狀與陰影（Core/Shape.lua）：長條類的條不套（NB）；Masque 模式由皮決定 ⇒ 三列停用、說明換黃字
        NB(TS("icon", "dropdown", "icon.shape", L["Icon shape"], { items = SHAPE_ITEMS, disabled = MasqueOwns,
            get = function(info) return ns.Shape.Normalize(ReadThemed(info, "icon.shape")) end })),
        NB(TS("icon", "toggle", "icon.shadow", L["Icon shadow"], { disabled = MasqueOwns })),
        NB(TS("icon", "slider", "icon.shadowAlpha", L["Shadow opacity"], { min = 10, max = 100, step = 5, scale = 100,
            disabled = function(info) return MasqueOwns(info) or not ReadThemed(info, "icon.shadow") end })),
        NB(ShapeNoteRow()),
        TS("icon", "color", "icon.swipeColor", L["Cooldown swipe color"], { hasAlpha = true }),
        -- demo：勾選框右邊的「!」，滑過演開與關的差別（Specs.DemoMark）
        CD(TS("icon", "toggle", "icon.hideGCDSwipe", L["Hide GCD swipe"], { demo = "gcd" })),
        -- 暴雪的就緒閃光（Core/Decorate.lua 的 DimReadyFlash）：增益兩條沒有這個動畫 ⇒ 不出現
        CD(TS("icon", "toggle", "icon.hideReadyFlash", L["Hide ready flash"], { demo = "readyFlash" })),
        CD(Note(L["Blizzard plays a short flash over the icon just before its cooldown ends."], "icon")),
        CD(TS("icon", "toggle", "icon.desaturateOnCooldown", L["Desaturate on cooldown"])),
        CS(TS("icon", "dropdown", "icon.cdState", L["Cooldown state"], { items = CDSTATE_ITEMS,
            get = function(info) return ReadThemed(info, "icon.cdState") or "none" end })),
        CS(TS("icon", "slider", "icon.cdStateAlpha", L["Dimmed opacity"],
            { min = 10, max = 90, step = 5, scale = 100, disabled = NotDim })),
        CS(Note(L["Hidden icons keep their place. The global cooldown doesn't count, and a spell with a charge left counts as ready. Buffs aren't affected."], "icon")),
        -- 增益持續中顯示持續時間（核心／輔助才有「先倒增益」那一段：增益兩條與長條類的條不顯示）
        CS(TS("icon", "toggle", "icon.showAuraTime", L["Show buff duration"])),
        CS(Note(L["After you use a spell that gives you a buff, the icon counts down the buff first and the cooldown after it ends. Off shows the cooldown right away."], "icon")),
        -- 增益那一段的倒數換色：開關關著時沒有那一段可換色 ⇒ 兩列停用
        CS(TS("icon", "toggle", "icon.colorDuration", L["Recolor buff duration"], { disabled = AuraTimeOff })),
        CS(TS("icon", "color", "icon.durationColor", L["Buff duration color"], { disabled = DurationOff })),
        -- 增益持續時間的變色顏色（icon.durationLowColor）搬到「文字」節增益持續時間那一組（J），資料路徑不變
        CS(TS("icon", "color", "icon.durationSwipeColor", L["Buff duration swipe color"], { hasAlpha = true, disabled = DurationOff })),
        CS(Note(L["After you use a spell that gives you a buff, the countdown shows the buff's remaining time first and the cooldown only after it ends. This colors that first part."], "icon")),
        AU(TS("icon", "toggle", "icon.hideDebuffBorder", L["Hide debuff type border"], { demo = "debuffBorder" })),
        AU(Note(L["Blizzard frames debuffs you track (on your target) in their dispel-type color."], "icon")),
        -- 沒有物品時隱藏（自訂物品）／被動飾品不顯示（飾品欄、代畫格）：收掉＝讓位（Core/Bars.lua）；逐法術小窗可以蓋
        TS("icon", "toggle", "icon.hideNoItem", L["Hide when none in bags"]),
        Note(L["Items you added yourself don't show once none are left in your bags (alternatives count too), and the icons after them move up. Bars with fixed slots keep the slot empty."], "icon"),
        TS("icon", "toggle", "icon.hidePassiveTrinket", L["Hide passive trinkets"]),
        Note(L["Equipment slot icons don't show while the equipped item has no use effect, such as a passive trinket. Trinket buff icons don't show while the trinket has no buff to track. Empty slots still show."], "icon"),
        TS("icon", "toggle", "icon.tooltips", L["Show tooltip on hover"]),
        Note(L["Off also hides Blizzard's own tooltip for these icons. Clicks still pass through."], "icon"),
        -- 按鍵鏡射（Core/Keybinds.lua）：長條類與增益圖示列不做（同按鍵文字的 NoKeybind），條頁不出現這三列
        NK(TS("icon", "toggle", "icon.pressFlash", L["Flash on key press"])),
        NK(Note(L["Flashes when you press the key bound to this spell's action bar slot. Clicking Blizzard's action bar doesn't count; bars from ElvUI, Bartender4 or Dominos flash on clicks too."], "icon")),
        NK(TS("icon", "slider", "icon.pressFlashAlpha", L["Flash opacity"],
            { min = 10, max = 80, step = 5, scale = 100,
              disabled = function(info) return not ReadThemed(info, "icon.pressFlash") end })),
        -- 回充的長相（Core/Decorate.lua）：三個都是改掉暴雪原本的（不畫轉圈、畫邊緣、顯示倒數），預設全關。
        -- 增益兩條與長條類的條用不到（同冷卻狀態效果的 CS）
        CS(Nested(L["While recharging"], "icon")),
        CS(TS("icon", "toggle", "icon.chargeSwipe", L["Show cooldown swipe"], { demo = "chargeSwipe" })),
        CS(Note(L["A spell with charges, while it still has one left and the next one comes back: Blizzard only draws a bright line at the edge of the swipe. Turn this on to darken the icon too, like a normal cooldown."], "icon")),
        CS(TS("icon", "toggle", "icon.chargeHideEdge", L["Hide edge line"], { demo = "chargeEdge" })),
        CS(TS("icon", "toggle", "icon.chargeHideTimer", L["Hide recharge countdown"], { demo = "chargeTimer" })),
        CS(Note(L["Hides the seconds until the next charge only while you still have one left. With none left, the cooldown countdown shows as usual."], "icon")))

    -- 文字
    add({ type = "header", label = L["Text"], tab = "text" })
    if bar then add(OverrideRow("text"), FollowToggle("text")) end
    -- 通用字型：每段文字的字型沒另外挑時用這個（條頁沒跟隨主題時也能改）
    add(TS("text", "dropdown", "font", L["General font"], { items = FontItems }),
        TS("text", "dropdown", "outline", L["Outline"], { items = OUTLINE_ITEMS }))
    add(NB(Nested(L["Countdown"], "text")),
        NB(FontTS("text", "cooldownText.font")),
        NB(TS("text", "slider", "cooldownText.size", L["Font size"], { min = 6, max = 40, step = 1 })),
        NB(TS("text", "color", "cooldownText.color", L["Color"])),
        -- 錨點＋偏移（玩家回報 2026-10-17：粗描邊時字體感覺偏左上，想微調）。逐法術彈窗本來就有這兩列，
        -- 這裡補條層／主題那一層；圓環形狀另走 Layout.RingTextPlace，不吃這兩欄
        NB(PointGridTS("text", "cooldownText.point", L["Anchor"], "CENTER")),
        NB(TS("text", "numbers", nil, L["Offset"], { sub = "cooldownText", path = false,
            resetPaths = { "cooldownText.x", "cooldownText.y" },
            fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } })),
        -- 時間格式（玩家回報 2026-10-21：想要 1:59 那種）：冷卻與增益持續時間共用一個 ⇒ 放在子分頁上面
        NB(TS("text", "dropdown", "cooldownText.timeFormat", L["Time format"], { items = TimeFormatItems,
            get = function(info) return ns.Text.TimeFormatOf(ReadThemed(info, "cooldownText.timeFormat")) end })),
        NB(Note(L["Minutes: over 90 seconds shows whole minutes, rounded up. Minutes:seconds: two minutes or less shows minutes and seconds, longer shows whole minutes. Applies to cooldowns and buff durations."], "text")),
        -- 從小數門檻開始分兩個子分頁「冷卻｜增益持續時間」（K）：同一組四列（小數門檻、低秒變色、變色顏色、變色秒數），
        -- 標籤不帶前綴（子分頁已經講了是哪一種）。子分頁鈕那一列不歸任何 section，但夾在文字那一段裡 ⇒
        -- 文字跟隨時跟卡片一起被文字的遮罩蓋住（BuildForm）
        NB(SubTabRow()),
        -- 冷卻：低秒變色的開關（lowColorOn）與變色秒數（lowBelow）分兩欄，取消勾選不動秒數（2026-10-06 拆開，舊存檔 MIGRATIONS[5]）
        NB(Sub("cooldown", TS("text", "slider", "cooldownText.decimalsBelow", L["Decimals below"], { min = 0, max = 10, step = 1 }))),
        NB(Sub("cooldown", Note(L["Shows one decimal place under this many seconds; 0 never shows decimals."], "text"))),
        NB(Sub("cooldown", TS("text", "toggle", "cooldownText.lowColorOn", L["Color when low"]))),
        NB(Sub("cooldown", TS("text", "color", "cooldownText.lowColor", L["Low color"], { disabled = CdLowOff }))),
        -- 拉桿最小 1：關交給上面的勾選（跟增益持續時間那組一樣從 1 起）
        NB(Sub("cooldown", TS("text", "slider", "cooldownText.lowBelow", L["Low below (sec)"],
            { min = 1, max = 30, step = 1, disabled = CdLowOff }))),
        -- 增益持續時間（I／J）：自己的小數門檻、低秒變色開關、變色顏色、變色秒數。長條類的條沒有
        -- （秒數是暴雪寫的／整數）。變色顏色的資料在 icon.durationLowColor（跟「圖示」那一節的跟隨與覆寫分組），
        -- 所以那一列的 section 是 icon：條頁勾著圖示跟隨時蓋的是圖示的遮罩
        NB(Sub("duration", TS("text", "slider", "cooldownText.buffDecimalsBelow", L["Decimals below"], { min = 0, max = 10, step = 1 }))),
        NB(Sub("duration", Note(L["Shows one decimal place under this many seconds; 0 never shows decimals."], "text"))),
        NB(Sub("duration", TS("text", "toggle", "cooldownText.buffLowColor", L["Color when low"]))),
        NB(Sub("duration", TS("icon", "color", "icon.durationLowColor", L["Low color"], { disabled = BuffLowOff }))),
        NB(Sub("duration", TS("text", "slider", "cooldownText.buffLowBelow", L["Low below (sec)"],
            { min = 1, max = 30, step = 1, disabled = BuffLowOff }))))
    -- 充能｜層數（cs 組子分頁）：兩節控件幾乎一樣 ⇒ 一張卡片切換（使用者 2026-10-06：選單太長超出螢幕）。
    -- 長條類的條沒有充能 ⇒ 不出卡片，層數照舊是一個小節
    local function StackOffset()
        return TS("text", "numbers", nil, L["Offset"], { sub = "stackText", path = false,
            resetPaths = { "stackText.x", "stackText.y" },
            fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } })
    end
    -- 長條的層數另存一個錨點（圖示小、預設右下）：主題頁兩個都列，長條類的條頁只列這個、標籤就叫「錨點」
    local function StackBarPoint()
        return (not bar or barsKind) and PointGridTS("text", "stackText.barPoint",
            bar and L["Anchor"] or L["Anchor (bars)"], "BOTTOMRIGHT") or nil
    end
    if barsKind then
        add(Nested(L["Stacks"], "text"),
            FontTS("text", "stackText.font"),
            TS("text", "slider", "stackText.size", L["Font size"], { min = 6, max = 30, step = 1 }),
            TS("text", "color", "stackText.color", L["Color"]),
            StackBarPoint(),
            StackOffset())
    else
        local function C(spec) return Sub("charges", spec, "cs") end
        local function K(spec) return Sub("stacks", spec, "cs") end
        add(SubTabRow("cs"),
            C(FontTS("text", "chargeText.font")),
            C(TS("text", "slider", "chargeText.size", L["Font size"], { min = 6, max = 30, step = 1 })),
            C(TS("text", "color", "chargeText.color", L["Color"])),
            C(PointGridTS("text", "chargeText.point", L["Anchor"], "BOTTOMRIGHT")),
            C(TS("text", "numbers", nil, L["Offset"], { sub = "chargeText", path = false,
                resetPaths = { "chargeText.x", "chargeText.y" },
                fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } })),
            K(FontTS("text", "stackText.font")),
            K(TS("text", "slider", "stackText.size", L["Font size"], { min = 6, max = 30, step = 1 })),
            K(TS("text", "color", "stackText.color", L["Color"])),
            K(PointGridTS("text", "stackText.point", L["Anchor"], "TOP")),
            K(StackBarPoint()),
            K(StackOffset()))
    end
    -- 快捷鍵文字（v8 起歸文字，使用者 2026-10-12 從效果搬來）：長條與增益圖示列沒有這一節，引擎也不畫
    -- （Core/Keybinds.lua 的 NoKeybind）。長條類的條本來就沒有 ⇒ 不會夾在下面的長條文字前面
    if not (bar and key and ns.Keybinds.NoKeybind(key)) then
        add(Nested(L["Keybind text"], "text"),
            TS("text", "toggle", "keybind.enabled", L["Show keybind text"]),
            Note(L["Shows the key bound to this spell's action bar slot on the icon, such as 1, Q or S-E."], "text"),
            FontTS("text", "keybind.font"),
            TS("text", "slider", "keybind.size", L["Font size"], { min = 6, max = 24, step = 1 }),
            PointGridTS("text", "keybind.point", L["Anchor"], "TOPRIGHT"),
            TS("text", "numbers", nil, L["Offset"], { sub = "keybind", path = false,
                resetPaths = { "keybind.x", "keybind.y" },
                fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } }))
    end
    -- 長條文字排在文字這一節的**最後**：跟隨遮罩蓋的是 section 第一列到最後一列的整塊矩形，
    -- 這幾列是條自己的欄位（不跟主題），夾在中間會跟著被蓋住
    if barsKind and bar then add(unpack(BarTextRows())) end

    -- 效果（發光、無損刷新）
    add({ type = "header", label = L["Effects"], tab = "glow" })
    if bar then add(OverrideRow("glow"), FollowToggle("glow")) end
    if not auraBar then
        add(Nested(L["Proc glow"], "glow"),
            TS("glow", "toggle", "glow.proc.enabled", L["Enable"], { demo = "procGlow" }),
            Note(L["Replaces Blizzard's proc glow. When off, Blizzard's own glow shows."], "glow"),
            TS("glow", "dropdown", "glow.proc.type", L["Style"], { items = GLOW_ITEMS }),
            TS("glow", "color", "glow.proc.color", L["Color"]),
            TS("glow", "slider", "glow.proc.lines", L["Lines"], { min = 2, max = 16, step = 1, disabled = NoLines("glow.proc.type") }),
            TS("glow", "slider", "glow.proc.thickness", L["Thickness"], { min = 1, max = 4, step = 1, disabled = NoThickness("glow.proc.type") }),
            GlowSampleRow("proc"),
            Nested(L["Ready glow"], "glow"),
            TS("glow", "toggle", "glow.ready.enabled", L["Enable"]),
            Note(L["Glows when a cooldown is ready. The global cooldown doesn't count."], "glow"),
            TS("glow", "dropdown", "glow.ready.type", L["Style"], { items = GLOW_ITEMS }),
            TS("glow", "color", "glow.ready.color", L["Color"]),
            TS("glow", "slider", "glow.ready.lines", L["Lines"], { min = 2, max = 16, step = 1, disabled = NoLines("glow.ready.type") }),
            TS("glow", "slider", "glow.ready.thickness", L["Thickness"], { min = 1, max = 4, step = 1, disabled = NoThickness("glow.ready.type") }),
            GlowSampleRow("ready"),
            TS("glow", "dropdown", "glow.ready.mode", L["Glow for"], { items = READY_MODE_ITEMS, demo = "readyMode" }),
            Note(L["\"Until used\" starts when a cooldown finishes, so after a reload it waits for the first use. Spells with charges still go out after the duration."], "glow"),
            TS("glow", "slider", "glow.ready.duration", L["Duration (sec)"], { min = 1, max = 10, step = 1,
                disabled = function(info) return (ReadThemed(info, "glow.ready.mode") or "timed") == "whileReady" end }),
            TS("glow", "toggle", "glow.ready.requireUsable", L["Wait for resources"],
                { disabled = function(info) return (ReadThemed(info, "glow.ready.mode") or "timed") == "whileReady" end }),
            Note(L["If the cooldown is ready but you lack the resources, the glow waits until you have enough."], "glow"),
            -- 充能滿了發光（Core/Glow.lua 的 SyncFull）：同一套開關＋樣式，預設關
            Nested(L["Glow at max charges"], "glow"),
            TS("glow", "toggle", "glow.full.enabled", L["Enable"]),
            Note(L["Glows while a spell with charges has all of them back. Spells without charges never glow."], "glow"),
            TS("glow", "dropdown", "glow.full.type", L["Style"], { items = GLOW_ITEMS }),
            TS("glow", "color", "glow.full.color", L["Color"]),
            TS("glow", "slider", "glow.full.lines", L["Lines"], { min = 2, max = 16, step = 1, disabled = NoLines("glow.full.type") }),
            TS("glow", "slider", "glow.full.thickness", L["Thickness"], { min = 1, max = 4, step = 1, disabled = NoThickness("glow.full.type") }),
            GlowSampleRow("full"))
    end
    -- 生效期間發光：跟觸發／就緒同一套（開關、樣式、顏色、線條、粗細、預覽，跟隨主題的繼承也一樣；使用者 2026-10-03）。
    -- 預設關：多半只在幾個法術上個別打開（預覽點圖示）
    add(Nested(L["Glow during buff"], "glow"),
        TS("glow", "toggle", "glow.active.enabled", L["Enable"]),
        Note(L["Glows while the buff is up; on Essential and Utility, while the icon shows the buff's time. Off by default: turn it on for single spells by clicking their icon in the preview."], "glow"),
        TS("glow", "dropdown", "glow.active.type", L["Style"], { items = GLOW_ITEMS }),
        TS("glow", "color", "glow.active.color", L["Color"]),
        TS("glow", "slider", "glow.active.lines", L["Lines"], { min = 2, max = 16, step = 1, disabled = NoLines("glow.active.type") }),
        TS("glow", "slider", "glow.active.thickness", L["Thickness"], { min = 1, max = 4, step = 1, disabled = NoThickness("glow.active.type") }),
        GlowSampleRow("active"))
    add(Nested(L["Pandemic"], "glow"),
        TS("glow", "toggle", "pandemic.enabled", L["Color the border"], { demo = "pandemic" }),
        Note(L["While a buff or debuff can be refreshed without losing time, its border turns this color."], "glow"),
        TS("glow", "color", "pandemic.color", L["Pandemic border color"]),
        TS("glow", "toggle", "pandemic.bars", L["Color bars too"], { demo = "pandemicBars" }))
    -- 音效：響什麼是逐法術設定（預覽裡點圖示）；主題頁放總開關與聲道，條頁只有覆寫數＋清除。
    -- 不掛 section：音效不走「跟隨全域主題」，條頁不蓋遮罩
    add({ type = "header", label = L["Sounds"], tab = "sound" })
    if bar then
        add(OverrideRow("sound"),
            Note(L["Sounds are set per spell: click an icon in the preview above. The on/off switch and channel are on the Theme page."]))
    else
        add(TS(nil, "toggle", "sound.enabled", L["Enable"]),
            TS(nil, "dropdown", "sound.channel", L["Channel"], { items = CHANNEL_ITEMS }),
            CustomSoundsRow(),
            Note(L["Which sound plays is set per spell: click an icon in a bar's preview. Nothing plays for 2 seconds after a loading screen, and the same spell doesn't repeat within 1.5 seconds."]))
    end
    return list
end

------------------------------------------------------------
-- 增益不在時（條層 layout.emptyMode）：三態下拉＋下一列灰字。收合／留空位／暗圖示（長條類：空長條）。
-- 「往前補」能不能選看 Bars.CollapseLocked（選了之後會不會成立：飾品／藥水的增益疊層選了往前補就關掉，不算數）；
-- 鎖住時那一項灰掉（選了不寫）、灰字換成原因（黃字色）；存的值不動，條件解除就回來。顯示的選中值是 Bars.BarEmptyMode 的生效值
-- （存著往前補、但疊層還活著時退回的暗圖示／留空位）。
-- 選往前補同時寫 layout.collapseChosen = true（Catalog.BarOverlaysSuppressed 只認這個：每條的預設值本來就是 collapse，
-- 只看存值會讓所有人的飾品增益與觸發發光在更新後一起消失）；選別的清掉。
-- 黃字提示（Specs.EmptyModeHint，W.fontEmphasis）：整列寬、在灰字說明正上方；出不出現進 BarSignature ⇒ 變了整張表單換形狀
-- （refreshPage），列高在建表單時照當下的狀態定。下拉自己建（表單引擎的下拉清單建表時就定了、也沒有停用項），
-- 灰字的高度取所有說法裡最高的。
------------------------------------------------------------
local LOCKED = "locked"
function EmptyModeRow(key, isBars)
    local FORCED, FORCED_CLICK = Specs.EMPTY_FORCED, Specs.EMPTY_FORCED_CLICK
    local function Items(forced)
        local items = Specs.EmptyModeItems(isBars)
        if forced then
            items[1] = { text = "|cff808080" .. items[1].text .. "|r", value = LOCKED }
        end
        return items
    end
    return { type = "custom", label = L["While the buff is missing"], h = 26, root = "bar",
             path = "layout.emptyMode", key = "layout.emptyMode",
             build = function(parent, x, y, width, ctx)
        local dd
        local Refresh
        dd = W.CreateDropdown(parent, 180, Items(false), function(value)
            local b = ns.DB.BarTable(key)
            if not b or value == LOCKED then Refresh() return end
            if type(b.layout) ~= "table" then b.layout = {} end
            b.layout.emptyMode = value
            b.layout.collapseChosen = (value == "collapse") or nil
            ctx.lastSpec = { level = "layout", refreshPage = true }
            ctx.apply()
        end)
        dd:SetMaxWidth(width)
        dd:SetPoint("LEFT", parent, "TOPLEFT", x, y - 13)
        -- 示意「!」（Specs.DemoMark）：下拉右邊，演三個選項各自的結果
        Specs.DemoMark(parent, isBars and "emptyModeBars" or "emptyMode", L["While the buff is missing"])
            :SetPoint("LEFT", dd, "RIGHT", 10, 0)
        -- 黃字提示：只在建表單當下需要時建（列高跟著加）；之後狀態變了由 BarSignature 換表單
        local hint = Specs.EmptyModeHint(key)
        local hintFS, hintH = nil, 0
        if hint then
            hintFS = parent:CreateFontString(nil, "OVERLAY")
            hintFS:SetFontObject(W.fontEmphasis)
            hintFS:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 30)
            hintFS:SetWidth(width)
            hintFS:SetJustifyH("LEFT")
            hintFS:SetWordWrap(true)
            hintFS:SetText(Specs.EMPTY_HINT[hint])
            hintH = math.max(14, hintFS:GetStringHeight() or 14) + 4
        end
        local fs = parent:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontSmall)
        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 30 - hintH)
        fs:SetWidth(width)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        local tallest = 14
        local texts = { FORCED, FORCED_CLICK, Specs.EMPTY_FORCED_FROM, Specs.EmptyModeDesc("collapse"),
            Specs.EmptyModeDesc("blank"), Specs.EmptyModeDesc("dim", isBars) }
        for _, t in pairs(Specs.EMPTY_FORCED_WHY) do texts[#texts + 1] = t end
        -- 點名格子的兩句：拿三個長名字的佔位量（真的名字在 Refresh 才填）
        local sample = L["%s and others (%d in all)"]:format(table.concat({ "WWWWWWWWWW", "WWWWWWWWWW", "WWWWWWWWWW" }, L[", "]), 9)
        texts[#texts + 1] = Specs.EMPTY_FORCED_MIXED:format(sample)
        texts[#texts + 1] = Specs.EMPTY_FORCED_SPELL:format(sample)
        for _, t in ipairs(texts) do
            fs:SetText(t)
            tallest = math.max(tallest, fs:GetStringHeight() or 14)
        end
        local h = 30 + hintH + tallest + 8
        Refresh = function()
            local mode = ns.Bars.BarEmptyMode(key)
            local locked = ns.Bars.CollapseLocked(key)
            dd:SetItems(Items(locked))
            dd:SetSelectedValue(mode)
            local reason = locked and (Specs.EmptyModeForcedText(key) or FORCED) or nil
            fs:SetText(reason or Specs.EmptyModeDesc(mode, isBars))
            fs:SetTextColor(reason and 1 or 0.65, reason and 0.82 or 0.65, reason and 0 or 0.65)
            if hintFS then
                local now = Specs.EmptyModeHint(key)
                hintFS:SetText(now and Specs.EMPTY_HINT[now] or "")
            end
        end
        return h, Refresh
    end }
end

------------------------------------------------------------
-- 跟著游標（自訂圖示群組，Core/Cursor.lua）：勾選框＋下一列灰字。條上有光環格、或勾了可點擊時不能跟
-- （容器變保護框，戰鬥中不能移）：勾選框停用、灰字換成原因（黃字）；存的值不動，條件解除就回來。
-- 寫法同 EmptyModeRow（表單引擎的控件沒有停用狀態），高度取三種說法裡最高的。
------------------------------------------------------------
function CursorRow(key)
    local NORMAL = L["The group stays next to your mouse pointer. It goes back to its own position in Edit Mode and while this window is open."]
    local NO_AURA = L["Not available while this group has aura slots or trinkets showing their buff: they can't move during combat."]
    local NO_CLICK = L["Not available while this group is clickable: the click targets can't move during combat."]
    local function Blocked()
        local b = ns.DB.BarTable(key)
        local ok, why = ns.Cursor.Eligible(b, ns.Catalog.BarHasAuraSlot(key))
        if ok then return nil end
        if why == "aura" then return NO_AURA end
        if why == "click" then return NO_CLICK end
        return nil
    end
    return { type = "custom", label = L["Follow the mouse pointer"], h = 26, root = "bar",
             path = "cursor.enabled", key = "cursor.enabled",
             build = function(parent, x, y, width, ctx)
        local cb = W.CreateCheckButton(parent, nil, function(on)
            local b = ns.DB.BarTable(key)
            if not b or Blocked() then return end
            if type(b.cursor) ~= "table" then b.cursor = { x = ns.Cursor.DEFAULT_X, y = ns.Cursor.DEFAULT_Y } end
            b.cursor.enabled = on and true or false
            ctx.lastSpec = { level = "structure" }
            ctx.apply()
        end)
        cb:SetPoint("LEFT", parent, "TOPLEFT", x, y - 13)
        local fs = parent:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontSmall)
        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 30)
        fs:SetWidth(width)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        local hs = {}
        for i, t in ipairs({ NO_AURA, NO_CLICK, NORMAL }) do
            fs:SetText(t)
            hs[i] = fs:GetStringHeight() or 14
        end
        local h = 30 + math.max(14, hs[1], hs[2], hs[3]) + 8
        local function Refresh()
            local reason = Blocked()
            local blocked = reason ~= nil
            local b = ns.DB.BarTable(key)
            local v = b and type(b.cursor) == "table" and b.cursor.enabled == true
            cb:SetChecked((v and not blocked) and true or false)
            cb:SetEnabled(not blocked)
            cb:SetAlpha(blocked and 0.5 or 1)
            fs:SetText(reason or NORMAL)
            fs:SetTextColor(blocked and 1 or 0.65, blocked and 0.82 or 0.65, blocked and 0 or 0.65)
        end
        return h, Refresh
    end }
end

------------------------------------------------------------
-- 發光預覽：一顆樣本圖示一直亮著目前的樣式與顏色，切樣式當場看得到效果。
-- 引擎跟格子共用（ns.Glow.PaintOn／StopOn）；就緒發光在格子上只亮幾秒，樣本則常亮。
-- 表單引擎在值變了之後只叫 ctx.apply、不叫 refreshers ⇒ 包一層 ctx.apply 讓樣本跟著換。
-- path（可省）：樣式表在主題的哪裡，預設 "glow.<which>"（戰鬥輔助頁的醒目標示是 "assist"）
------------------------------------------------------------
local SAMPLE_ICON = "Interface\\Icons\\Spell_Holy_HolyBolt"
local SAMPLE_SIZE = 36

function GlowSampleRow(which, path)
    path = path or ("glow." .. which)
    return { type = "custom", label = L["Preview"], h = SAMPLE_SIZE + 8, section = "glow", noReset = true,
             build = function(parent, x, y, width, ctx)
        local f = CreateFrame("Frame", nil, parent)
        f:SetSize(SAMPLE_SIZE, SAMPLE_SIZE)
        f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 4)
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 1)
        local icon = f:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
        icon:SetTexture(SAMPLE_ICON)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local host = CreateFrame("Frame", nil, f)
        host:SetAllPoints()
        host:SetFrameLevel(f:GetFrameLevel() + 2)

        local shown, sig
        local function Refresh()
            local G = ns.Glow
            if not (G and G.PaintOn) then return end
            local c = ReadThemed(ctx.info, path)
            c = type(c) == "table" and c or {}
            local col = type(c.color) == "table" and c.color or {}
            local now = table.concat({ tostring(c.type), tostring(col.r), tostring(col.g),
                tostring(col.b), tostring(col.a), tostring(c.lines), tostring(c.thickness),
                tostring(c.frequency) }, "|")
            if shown and now == sig then return end
            if shown then G.StopOn(host, shown, which) end
            shown = G.PaintOn(host, c, which, which, false)
            sig = now
        end
        local apply = ctx.apply
        ctx.apply = function(...)
            apply(...)
            Refresh()
        end
        return SAMPLE_SIZE + 8, Refresh
    end }
end
Specs.GlowSampleRow = function(which, path) return GlowSampleRow(which, path) end

------------------------------------------------------------
-- 設定的示意「!」（使用者 2026-10-25：只有文字很難懂）：勾選框／下拉右邊一個「!」小方塊（樣式同子分頁卡片的「!」），
-- 滑過彈出一塊提示皮，幾顆自己畫的樣本格並排、一直循環演「關閉」與「開啟」的差別（關閉＝暴雪原本或現況）。
-- 只給活預覽演不出來的那幾個：要靠遊戲狀況才出現的東西（GCD、目標身上的減益、增益消失、充能、暴雪自己畫的閃光）。
-- 樣本不套主題的邊框／字型：要看的只是那個開關的差別。
-- 彈窗整個介面共用一塊（框刪不掉 ⇒ 第一次滑過才建）；每個示意是一塊面板（DEMOS[id].build，第一次用到才建、之後藏／顯示）：
--   panel.cells        一排樣本（各帶 w／h／cap 說明字／Inset 顯示時換算 1px 的內縮）
--   panel:Layout()     量字、擺格子（顯示之後叫：字寬字高要框顯示過才量得到）→ panel.w／panel.h
--   panel:Reset(now)   循環從頭（顯示時叫）
--   panel:Tick(now)    每幀（彈窗的 OnUpdate）
-- 主題頁／條頁（spec.demo，BuildForm 擺位置；EmptyModeRow 自己擺）與逐法術小窗（TOGGLES 的 demo、增益不在時那一列）
-- 都叫 Specs.DemoMark(parent, id, 標題)；id 可以是函式（顯示那一刻才決定是哪個示意）
------------------------------------------------------------
do
    local SIZE, PAD, GAP, CAP_GAP = 40, 10, 14, 4
    local WHITE = "Interface\\BUTTONS\\WHITE8X8"
    local DOT_ICON = "Interface\\Icons\\Spell_Shadow_ShadowWordPain"
    local DEMOS = {}
    local popup

    local function Caption(parent, text)
        local fs = parent:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontSmall)
        fs:SetTextColor(0.65, 0.65, 0.65)
        fs:SetJustifyH("CENTER")
        fs:SetText(text or "")
        return fs
    end

    -- 樣本格：黑底內縮 1px 當邊框（bg 露出來的那一圈）、圖示、轉圈（倒數自己寫，不受「顯示冷卻倒數」那個 CVar 影響）、
    -- 覆蓋層上的倒數字與角落數字、底下的說明字
    local function NewCell(parent, icon, size)
        size = size or SIZE
        local c = CreateFrame("Frame", nil, parent)
        c:SetSize(size, size)
        c.w, c.h = size, size
        c.bg = ns.P.NoSnap(c:CreateTexture(nil, "BACKGROUND"))
        c.bg:SetAllPoints()
        c.bg:SetColorTexture(0, 0, 0, 1)
        c.icon = ns.P.NoSnap(c:CreateTexture(nil, "ARTWORK"))
        c.icon:SetTexture(icon or SAMPLE_ICON)
        c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local ok, cd = pcall(CreateFrame, "Cooldown", nil, c, "CooldownFrameTemplate")
        if ok and cd then
            cd:SetAllPoints(c.icon)
            cd:SetHideCountdownNumbers(true)
            cd:SetDrawBling(false)
            cd:SetDrawEdge(false)
            cd:SetDrawSwipe(false)
            pcall(cd.SetSwipeTexture, cd, WHITE, 1, 1, 1, 1)
            cd:SetSwipeColor(0, 0, 0, 0.8)         -- 主題預設的轉圈色（icon.swipeColor）
            c.cd = cd
        end
        local ov = CreateFrame("Frame", nil, c)
        ov:SetAllPoints()
        ov:SetFrameLevel(c:GetFrameLevel() + 5)
        c.ov = ov
        c.time = ov:CreateFontString(nil, "OVERLAY")
        ns.Media.SetFont(c.time, size >= 36 and 16 or 11, "OUTLINE")
        c.time:SetPoint("CENTER")
        c.corner = ov:CreateFontString(nil, "OVERLAY")
        ns.Media.SetFont(c.corner, 12, "OUTLINE")
        c.corner:SetPoint("BOTTOMRIGHT", -2, 2)
        c.cap = Caption(parent)
        c.cap:SetPoint("TOP", c, "BOTTOM", 0, -CAP_GAP)
        function c:Inset()                         -- 邊框粗細在顯示時換算（1px 規則 ③）
            local px = ns.P.Pixel(1)
            self.icon:ClearAllPoints()
            self.icon:SetPoint("TOPLEFT", self, "TOPLEFT", px, -px)
            self.icon:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -px, px)
        end
        return c
    end

    -- 樣本長條：黑底、左邊方形圖示、右邊條身（白貼圖、職業色填充、暗底），時間字靠右
    local BAR_W, BAR_H = 110, 20
    local function NewBar(parent, icon, w, h)
        w, h = w or BAR_W, h or BAR_H
        local c = CreateFrame("Frame", nil, parent)
        c:SetSize(w, h)
        c.w, c.h = w, h
        c.bg = ns.P.NoSnap(c:CreateTexture(nil, "BACKGROUND"))
        c.bg:SetAllPoints()
        c.bg:SetColorTexture(0, 0, 0, 1)
        c.icon = ns.P.NoSnap(c:CreateTexture(nil, "ARTWORK"))
        c.icon:SetTexture(icon or SAMPLE_ICON)
        c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        c.body = CreateFrame("StatusBar", nil, c)
        c.body:SetStatusBarTexture(WHITE)
        ns.P.NoSnap(c.body)
        c.body:SetMinMaxValues(0, 1)
        c.body:SetValue(1)
        c.body:SetStatusBarColor(W.Accent(1))
        local track = ns.P.NoSnap(c.body:CreateTexture(nil, "BACKGROUND"))
        track:SetAllPoints()
        track:SetColorTexture(0.1, 0.1, 0.1, 1)
        c.ov = CreateFrame("Frame", nil, c)
        c.ov:SetAllPoints()
        c.ov:SetFrameLevel(c.body:GetFrameLevel() + 5)
        c.time = c.ov:CreateFontString(nil, "OVERLAY")
        ns.Media.SetFont(c.time, 11, "OUTLINE")
        c.time:SetPoint("RIGHT", c.body, "RIGHT", -3, 0)
        c.cap = Caption(parent)
        c.cap:SetPoint("TOP", c, "BOTTOM", 0, -CAP_GAP)
        function c:Inset()
            local px = ns.P.Pixel(1)
            self.icon:ClearAllPoints()
            self.icon:SetPoint("TOPLEFT", self, "TOPLEFT", px, -px)
            self.icon:SetSize(self.h - 2 * px, self.h - 2 * px)
            self.body:ClearAllPoints()
            self.body:SetPoint("TOPLEFT", self.icon, "TOPRIGHT", px, 0)
            self.body:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -px, px)
        end
        return c
    end

    local function SetCD(c, now, dur)
        if c.cd then c.cd:SetCooldown(now, dur) end
    end
    local function ClearCD(c)
        if c.cd then c.cd:Clear() end
    end
    -- 秒數變了才寫字
    local function PutTime(c, left)
        if c.shownLeft ~= left then
            c.shownLeft = left
            c.time:SetText(left and tostring(left) or "")
        end
    end

    -- 一排樣本橫向排開：欄寬＝樣本寬與說明字取大；panel.status（可省）排在底下再一行，寬度照 statusTexts 裡最長的量
    local function RowLayout(panel)
        local x, h = 0, 0
        for _, c in ipairs(panel.cells) do
            if c.Inset then c:Inset() end
            local colW = math.max(c.w, math.ceil(c.cap:GetStringWidth()))
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", panel, "TOPLEFT", x + math.floor((colW - c.w) / 2), 0)
            x = x + colW + GAP
            h = math.max(h, c.h + CAP_GAP + math.ceil(c.cap:GetStringHeight()))
        end
        local w = x - GAP
        if panel.status then
            local cur = panel.status:GetText()
            for _, t in ipairs(panel.statusTexts or {}) do
                panel.status:SetText(t)
                w = math.max(w, math.ceil(panel.status:GetStringWidth()))
            end
            panel.status:SetText(cur or "")
            panel.status:ClearAllPoints()
            panel.status:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -(h + 6))
            h = h + 6 + math.ceil(panel.status:GetStringHeight())
        end
        panel.w, panel.h = w, h
        panel:SetSize(math.max(1, w), math.max(1, h))
    end

    local function NewPanel(parent)
        local p = CreateFrame("Frame", nil, parent)
        p.cells = {}
        p.Layout = RowLayout
        return p
    end

    local function TwoCells(p, icon, swipe)
        local off, on = NewCell(p, icon), NewCell(p, icon)
        off.cap:SetText(L["Off"])
        on.cap:SetText(L["On"])
        if swipe then
            if off.cd then off.cd:SetDrawSwipe(true) end
            if on.cd then on.cd:SetDrawSwipe(true) end
        end
        p.cells[1], p.cells[2] = off, on
        return off, on
    end

    ------------------------------------------------------------
    -- 回充的長相（三個開關各一個）：六秒回充循環。關閉＝暴雪原本（不畫轉圈、畫邊緣亮線、顯示倒數），開啟只改那一項；
    -- 隱藏回充倒數多一格「充能用完」：倒數照常（Core/Decorate.lua 的 ApplyChargeLook——沒充能時暴雪餵的是一般冷卻，不算回充）
    ------------------------------------------------------------
    local BLIZZ = { edge = true, time = true, charges = 1 }
    local CHARGE_LOOKS = {
        chargeSwipe = { { L["Off"], BLIZZ }, { L["On"], { swipe = true, edge = true, time = true, charges = 1 } } },
        chargeEdge  = { { L["Off"], BLIZZ }, { L["On"], { time = true, charges = 1 } } },
        chargeTimer = { { L["Off"], BLIZZ }, { L["On"], { edge = true, charges = 1 } },
                        { L["On (no charges)"], { swipe = true, time = true, charges = 0 } } },
    }
    local CHARGE_DUR = 6
    local function BuildCharge(parent, defs)
        local p = NewPanel(parent)
        for i, def in ipairs(defs) do
            local c = NewCell(p)
            local look = def[2]
            c.look = look
            c.cap:SetText(def[1])
            c.icon:SetDesaturated(look.charges == 0)     -- 主題預設冷卻中去飽和
            c.corner:SetText(tostring(look.charges))
            if c.cd then
                c.cd:SetDrawSwipe(look.swipe and true or false)
                c.cd:SetDrawEdge(look.edge and true or false)
            end
            p.cells[i] = c
        end
        function p:Reset(now)
            self.start = now
            for _, c in ipairs(self.cells) do SetCD(c, now, CHARGE_DUR) end
        end
        function p:Tick(now)
            if now >= self.start + CHARGE_DUR then self:Reset(now) end
            local left = math.ceil(self.start + CHARGE_DUR - now)
            for _, c in ipairs(self.cells) do PutTime(c, c.look.time and left or nil) end
        end
        return p
    end
    for id, defs in pairs(CHARGE_LOOKS) do
        DEMOS[id] = { build = function(parent) return BuildCharge(parent, defs) end }
    end

    ------------------------------------------------------------
    -- 隱藏 GCD 轉圈：每施放任何法術，所有就緒的圖示都跑一次公共冷卻的短轉圈。關閉＝跑，開啟＝不跑
    ------------------------------------------------------------
    local GCD_PERIOD, GCD_DUR = 2.2, 1.2
    DEMOS.gcd = { build = function(parent)
        local p = NewPanel(parent)
        local off = TwoCells(p, nil, false)
        if off.cd then off.cd:SetDrawSwipe(true) end
        function p:Reset(now)
            self.start = now
            SetCD(off, now, GCD_DUR)
        end
        function p:Tick(now)
            if now >= self.start + GCD_PERIOD then self:Reset(now) end
        end
        return p
    end }

    ------------------------------------------------------------
    -- 隱藏減益類型邊框：暴雪對追蹤中的減益（目標身上你的減益）在圖示外框一圈驅散類型色
    -- （CooldownViewerItemDebuffBorderTemplate：錨在圖示外 3px，圖集 ui-debuff-border-<類型>-noicon，
    -- AuraUtil.SetAuraBorderAtlas）。關閉＝有那一圈（示意畫魔法的紫），開啟＝沒有。那一圈比我們的 1px 邊框大一圈 ⇒ 兩層外框
    ------------------------------------------------------------
    DEMOS.debuffBorder = { build = function(parent)
        local p = NewPanel(parent)
        local off = TwoCells(p, DOT_ICON, false)
        local ring = ns.P.NoSnap(off.ov:CreateTexture(nil, "BACKGROUND"))
        ring:SetPoint("TOPLEFT", off.icon, "TOPLEFT", -3, 3)
        ring:SetPoint("BOTTOMRIGHT", off.icon, "BOTTOMRIGHT", 3, -3)
        ring:SetAtlas("ui-debuff-border-magic-noicon")
        return p
    end }

    ------------------------------------------------------------
    -- 無損刷新邊框變色：增益／減益還能不損失時間就刷新的那一段（暴雪的 PandemicStateFrame 旗標），overlay 邊框換成設定色；
    -- 「條也上色」長條條身也換（Core/Glow.lua 的 ApplyPandemic）。示意跑六秒的減益，最後三成邊框（／條身）變色
    ------------------------------------------------------------
    local PAN_DUR, PAN_FRAC = 6, 0.3
    local function PandemicColor()
        local c = ns.Setting("theme", "pandemic.color")
        if type(c) ~= "table" then return 1, 0.5, 0, 1 end
        return c.r or 1, c.g or 0.5, c.b or 0, 1
    end
    DEMOS.pandemic = { build = function(parent)
        local p = NewPanel(parent)
        local off, on = TwoCells(p, DOT_ICON, true)
        function p:Reset(now)
            self.start, self.lit = now, nil
            SetCD(off, now, PAN_DUR)
            SetCD(on, now, PAN_DUR)
            on.bg:SetColorTexture(0, 0, 0, 1)
        end
        function p:Tick(now)
            if now >= self.start + PAN_DUR then self:Reset(now) end
            local rem = self.start + PAN_DUR - now
            local left = math.ceil(rem)
            PutTime(off, left)
            PutTime(on, left)
            local lit = rem <= PAN_DUR * PAN_FRAC
            if lit ~= self.lit then
                self.lit = lit
                if lit then on.bg:SetColorTexture(PandemicColor()) else on.bg:SetColorTexture(0, 0, 0, 1) end
            end
        end
        return p
    end }
    DEMOS.pandemicBars = { build = function(parent)
        local p = NewPanel(parent)
        local off, on = NewBar(p, DOT_ICON), NewBar(p, DOT_ICON)
        off.cap:SetText(L["Off"])
        on.cap:SetText(L["On"])
        p.cells[1], p.cells[2] = off, on
        function p:Reset(now)
            self.start, self.lit = now, nil
            for _, c in ipairs(self.cells) do c.body:SetStatusBarColor(W.Accent(1)) end
            on.bg:SetColorTexture(0, 0, 0, 1)
        end
        function p:Tick(now)
            if now >= self.start + PAN_DUR then self:Reset(now) end
            local rem = self.start + PAN_DUR - now
            local frac, left = rem / PAN_DUR, math.ceil(rem)
            for _, c in ipairs(self.cells) do
                c.body:SetValue(frac)
                PutTime(c, left)
            end
            local lit = rem <= PAN_DUR * PAN_FRAC
            if lit ~= self.lit then
                self.lit = lit
                if lit then
                    local r, g, b = PandemicColor()
                    on.body:SetStatusBarColor(r, g, b, 1)
                    on.bg:SetColorTexture(r, g, b, 1)
                else
                    on.body:SetStatusBarColor(W.Accent(1))
                    on.bg:SetColorTexture(0, 0, 0, 1)
                end
            end
        end
        return p
    end }

    ------------------------------------------------------------
    -- 效果不在時變暗（逐法術）：暴雪這一格沒在倒你的光環時間（目標身上沒有你的減益、或沒有目標）⇒ 整格乘上變暗透明度
    -- （icon.cdStateAlpha）。示意兩段輪流：三秒「目標身上有你的減益」（倒減益時間）、三秒「沒有」（就緒；開啟的那格變暗）
    ------------------------------------------------------------
    local DIM_PHASE = 3
    DEMOS.dimNoAura = { build = function(parent)
        local p = NewPanel(parent)
        local off, on = TwoCells(p, DOT_ICON, true)
        p.status = Caption(p)
        p.status:SetJustifyH("LEFT")
        p.statusTexts = { L["Your debuff is on the target"], L["No debuff on the target"] }
        function p:Reset(now)
            self.start, self.has = now, nil
        end
        function p:Tick(now)
            if now >= self.start + DIM_PHASE * 2 then self:Reset(now) end
            local has = now - self.start < DIM_PHASE
            if has ~= self.has then
                self.has = has
                if has then
                    SetCD(off, now, DIM_PHASE)
                    SetCD(on, now, DIM_PHASE)
                    on:SetAlpha(1)
                    self.status:SetText(self.statusTexts[1])
                else
                    ClearCD(off)
                    ClearCD(on)
                    PutTime(off, nil)
                    PutTime(on, nil)
                    on:SetAlpha(tonumber(ns.Setting("theme", "icon.cdStateAlpha")) or 0.4)
                    self.status:SetText(self.statusTexts[2])
                end
            end
            if has then
                local left = math.ceil(self.start + DIM_PHASE - now)
                PutTime(off, left)
                PutTime(on, left)
            end
        end
        return p
    end }

    ------------------------------------------------------------
    -- 增益不在時（條層 layout.emptyMode／逐法術 emptyMode）三態：中間那格的增益每 2.5 秒消失、回來，三欄各畫一種結果：
    -- 往前補（後面的往前移）、留空位、暗圖示佔位（長條類：空長條）。三格用三個不同的圖示，才看得出誰移了
    ------------------------------------------------------------
    local EM_PHASE, EM_SIZE, EM_GAP = 2.5, 24, 3
    local EM_BAR_W, EM_BAR_H = 72, 12
    local EM_ICONS = { "Interface\\Icons\\Spell_Nature_Rejuvenation", "Interface\\Icons\\Spell_Holy_PowerWordShield",
                       "Interface\\Icons\\Spell_Holy_Renew" }
    local function BuildEmpty(parent, isBars)
        local p = NewPanel(parent)
        for i, it in ipairs(Specs.EmptyModeItems(isBars)) do
            local col = CreateFrame("Frame", nil, p)
            col.mode, col.cells = it.value, {}
            if isBars then
                col.w, col.h = EM_BAR_W, EM_BAR_H * 3 + EM_GAP * 2
            else
                col.w, col.h = EM_SIZE * 3 + EM_GAP * 2, EM_SIZE
            end
            col:SetSize(col.w, col.h)
            for j = 1, 3 do
                local c = isBars and NewBar(col, EM_ICONS[j], EM_BAR_W, EM_BAR_H) or NewCell(col, EM_ICONS[j], EM_SIZE)
                c.cap:Hide()
                col.cells[j] = c
            end
            col.cap = Caption(p, it.text)
            col.cap:SetPoint("TOP", col, "BOTTOM", 0, -CAP_GAP)
            function col:Inset()
                for _, c in ipairs(self.cells) do c:Inset() end
            end
            function col:Place(c, slot)
                c:ClearAllPoints()
                if isBars then
                    c:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(slot - 1) * (EM_BAR_H + EM_GAP))
                else
                    c:SetPoint("TOPLEFT", self, "TOPLEFT", (slot - 1) * (EM_SIZE + EM_GAP), 0)
                end
            end
            function col:Apply(missing)
                local mid, last = self.cells[2], self.cells[3]
                mid:SetShown(not missing or self.mode == "dim")
                self:Place(last, (missing and self.mode == "collapse") and 2 or 3)
                if self.mode == "dim" then
                    mid.icon:SetDesaturated(missing)
                    if isBars then mid.body:SetValue(missing and 0 or 1) else mid:SetAlpha(missing and 0.5 or 1) end
                end
            end
            p.cells[i] = col
        end
        function p:Reset(now)
            self.start, self.missing = now, nil
            for _, col in ipairs(self.cells) do
                for j, c in ipairs(col.cells) do col:Place(c, j) end
            end
        end
        function p:Tick(now)
            local missing = ((now - self.start) % (EM_PHASE * 2)) >= EM_PHASE
            if missing ~= self.missing then
                self.missing = missing
                for _, col in ipairs(self.cells) do col:Apply(missing) end
            end
        end
        return p
    end
    DEMOS.emptyMode     = { build = function(parent) return BuildEmpty(parent, false) end }
    DEMOS.emptyModeBars = { build = function(parent) return BuildEmpty(parent, true) end }

    ------------------------------------------------------------
    -- 隱藏就緒閃光：暴雪在冷卻結束前 0.75 秒蓋在圖示上播的翻頁動畫（item.CooldownFlash：圖集 UI-HUD-ActionBar-GCD-Flipbook、
    -- 11 列 2 行 22 格 0.75 秒，同快捷列 GCD 結束的那一下）。示意跑四秒冷卻＋一秒就緒，關閉的那格結束前播同一段
    ------------------------------------------------------------
    local RF_DUR, RF_PERIOD, RF_LEAD = 4, 5, 0.75
    DEMOS.readyFlash = { build = function(parent)
        local p = NewPanel(parent)
        local off, on = TwoCells(p, nil, true)
        local flash = off.ov:CreateTexture(nil, "BACKGROUND")
        flash:SetAllPoints(off.icon)
        flash:SetAtlas("UI-HUD-ActionBar-GCD-Flipbook")
        flash:SetAlpha(0)
        local ag = flash:CreateAnimationGroup()
        local fb = ag:CreateAnimation("FlipBook")
        fb:SetOrder(1)
        fb:SetDuration(RF_LEAD)
        fb:SetFlipBookRows(11)
        fb:SetFlipBookColumns(2)
        fb:SetFlipBookFrames(22)
        fb:SetFlipBookFrameWidth(0)
        fb:SetFlipBookFrameHeight(0)
        ag:SetScript("OnFinished", function() flash:SetAlpha(0) end)
        function p:Reset(now)
            self.start, self.fired, self.ready = now, false, false
            SetCD(off, now, RF_DUR)
            SetCD(on, now, RF_DUR)
            off.icon:SetDesaturated(true)          -- 主題預設冷卻中去飽和
            on.icon:SetDesaturated(true)
        end
        function p:Tick(now)
            if now >= self.start + RF_PERIOD then self:Reset(now) end
            local rem = self.start + RF_DUR - now
            if rem > 0 then
                local left = math.ceil(rem)
                PutTime(off, left)
                PutTime(on, left)
                if not self.fired and rem <= RF_LEAD then
                    self.fired = true
                    flash:SetAlpha(1)
                    ag:Stop()
                    ag:Play()
                end
            elseif not self.ready then
                self.ready = true
                PutTime(off, nil)
                PutTime(on, nil)
                off.icon:SetDesaturated(false)
                on.icon:SetDesaturated(false)
            end
        end
        return p
    end }

    ------------------------------------------------------------
    -- 發光宿主（同發光預覽 GlowSampleRow）：格子上面一層自己的框，PaintOn 畫在它身上；Stop 時 StopOn
    ------------------------------------------------------------
    local function GlowHost(c)
        local h = CreateFrame("Frame", nil, c)
        h:SetAllPoints()
        h:SetFrameLevel(c:GetFrameLevel() + 2)
        return h
    end
    local function StyleCopy(path, fallbackType)
        local c = ns.Setting("theme", path)
        local out = { type = fallbackType }
        if type(c) == "table" then for k, v in pairs(c) do out[k] = v end end
        return out
    end
    local function GlowOn(c, style, which)
        if c.glowOn then return end
        c.glowOn = ns.Glow.PaintOn(c.glowHost, style, which, "demo", which == "proc") or nil
    end
    local function GlowOff(c, which)
        if not c.glowOn then return end
        ns.Glow.StopOn(c.glowHost, c.glowOn, "demo")
        c.glowOn = nil
    end

    ------------------------------------------------------------
    -- 觸發發光「啟用」：關＝暴雪自己的觸發發光（ActionButtonSpellAlertManager，同快捷列那一圈），開＝我們的樣式（主題 glow.proc）
    ------------------------------------------------------------
    DEMOS.procGlow = { build = function(parent)
        local p = NewPanel(parent)
        local off, on = TwoCells(p, nil, false)
        on.glowHost = GlowHost(on)
        function p:Reset(now)
            local mgr = _G.ActionButtonSpellAlertManager
            if mgr and mgr.ShowAlert then pcall(mgr.ShowAlert, mgr, off) end
            GlowOn(on, StyleCopy("glow.proc", "proc"), "proc")
        end
        function p:Stop()
            local mgr = _G.ActionButtonSpellAlertManager
            if mgr and mgr.HideAlert then pcall(mgr.HideAlert, mgr, off) end
            GlowOff(on, "proc")
        end
        return p
    end }

    ------------------------------------------------------------
    -- 就緒發光「發光持續」三選一：一個循環走四段——剛重載（就緒、還沒用過）→ 用掉、冷卻三秒 → 就緒四秒 → 用掉。
    --   幾秒：就緒後亮 duration 秒（示意最多三秒）；直到使用：從冷卻結束亮到被用掉，剛重載那段不亮；
    --   就緒期間一直：只要就緒就亮，剛重載那段也亮（Core/Glow.lua 檔頭）
    ------------------------------------------------------------
    local RM_FRESH, RM_CD, RM_READY = 2, 3, 4
    DEMOS.readyMode = { build = function(parent)
        local p = NewPanel(parent)
        for i, it in ipairs(READY_MODE_ITEMS) do
            local c = NewCell(p)
            c.mode = it.value
            c.cap:SetText(it.text)
            c.glowHost = GlowHost(c)
            if c.cd then c.cd:SetDrawSwipe(true) end
            p.cells[i] = c
        end
        p.status = Caption(p)
        p.status:SetJustifyH("LEFT")
        p.statusTexts = { L["After a reload, not used yet"], L["On cooldown"], L["Ready"] }
        local function Lit(mode, t, dur)
            if t < RM_FRESH then return mode == "whileReady" end
            if t < RM_FRESH + RM_CD then return false end
            if mode == "timed" then return t < RM_FRESH + RM_CD + dur end
            return true
        end
        function p:Reset(now)
            self.start, self.seg = now, nil
            self.dur = math.min(tonumber(ns.Setting("theme", "glow.ready.duration")) or 3, 3)
            self.style = StyleCopy("glow.ready", "button")
            for _, c in ipairs(self.cells) do
                ClearCD(c)
                PutTime(c, nil)
                c.icon:SetDesaturated(false)
            end
        end
        function p:Stop()
            for _, c in ipairs(self.cells) do GlowOff(c, "ready") end
        end
        function p:Tick(now)
            local total = RM_FRESH + RM_CD + RM_READY
            if now >= self.start + total then self:Reset(now) end
            local t = now - self.start
            local seg = t < RM_FRESH and 1 or t < RM_FRESH + RM_CD and 2 or 3
            if seg ~= self.seg then
                self.seg = seg
                self.status:SetText(self.statusTexts[seg])
                for _, c in ipairs(self.cells) do
                    if seg == 2 then SetCD(c, now, RM_CD) end
                    c.icon:SetDesaturated(seg == 2)
                    if seg ~= 2 then PutTime(c, nil) end
                end
            end
            if seg == 2 then
                local left = math.ceil(self.start + RM_FRESH + RM_CD - now)
                for _, c in ipairs(self.cells) do PutTime(c, left) end
            end
            for _, c in ipairs(self.cells) do
                if Lit(c.mode, t, self.dur) then GlowOn(c, self.style, "ready") else GlowOff(c, "ready") end
            end
        end
        return p
    end }

    ------------------------------------------------------------
    -- 層數發光（逐法術）：層數每 0.6 秒加一、到 5 停一秒、歸零；到門檻（示意用預設的 ≥ 3）就亮生效發光的樣式（主題 glow.active）
    ------------------------------------------------------------
    local SG_STEP, SG_MAX, SG_HOLD = 0.6, 5, 1.2
    DEMOS.stackGlow = { build = function(parent)
        local p = NewPanel(parent)
        local c = NewCell(p, "Interface\\Icons\\Spell_Nature_Rejuvenation")
        c.cap:SetText("≥ " .. ns.StackGate.DEFAULT_THRESHOLD)
        c.glowHost = GlowHost(c)
        p.cells[1] = c
        function p:Reset(now)
            self.start, self.n = now, nil
            self.style = StyleCopy("glow.active", "pixel")
        end
        function p:Stop() GlowOff(c, "active") end
        function p:Tick(now)
            local t = now - self.start
            if t >= SG_STEP * SG_MAX + SG_HOLD then self:Reset(now); t = 0 end
            local n = math.min(SG_MAX, math.floor(t / SG_STEP))
            if n ~= self.n then
                self.n = n
                c.corner:SetText(n > 0 and tostring(n) or "")
                if n >= ns.StackGate.DEFAULT_THRESHOLD then GlowOn(c, self.style, "active") else GlowOff(c, "active") end
            end
        end
        return p
    end }

    ------------------------------------------------------------
    -- 長條「充能分段」（自訂法術、有充能）：三充能，現有兩顆、第三顆在回充六秒；滿了停一秒、用掉一顆再回充。
    --   關＝整條畫下一顆的回充進度（舊行為）＋角落充能數；開＝條身分三段：現有充能滿格、回充那一段從空跑到滿、1px 分隔線
    --   （Modules/Custom.lua 的「充能分段」）
    ------------------------------------------------------------
    local CSG_MAX, CSG_RECHARGE, CSG_HOLD = 3, 6, 1
    DEMOS.chargeSegments = { build = function(parent)
        local p = NewPanel(parent)
        local off, on = NewBar(p), NewBar(p)
        off.cap:SetText(L["Off"])
        on.cap:SetText(L["On"])
        for _, c in ipairs({ off, on }) do
            c.count = c.ov:CreateFontString(nil, "OVERLAY")
            ns.Media.SetFont(c.count, 11, "OUTLINE")
            c.count:SetPoint("BOTTOMRIGHT", c.icon, "BOTTOMRIGHT", -1, 1)
        end
        -- 分段：計數填充（現有充能）、進度填充（回充那一段）、分隔線，都畫在條身上（條身自己的填充調透明）
        on.body:GetStatusBarTexture():SetAlpha(0)
        local segFill = ns.P.NoSnap(on.body:CreateTexture(nil, "ARTWORK", nil, 1))
        segFill:SetTexture(WHITE)
        segFill:SetPoint("TOPLEFT", on.body, "TOPLEFT", 0, 0)
        segFill:SetPoint("BOTTOMLEFT", on.body, "BOTTOMLEFT", 0, 0)
        local segProg = ns.P.NoSnap(on.body:CreateTexture(nil, "ARTWORK", nil, 1))
        segProg:SetTexture(WHITE)
        segProg:SetPoint("TOPLEFT", segFill, "TOPRIGHT", 0, 0)
        segProg:SetPoint("BOTTOMLEFT", segFill, "BOTTOMRIGHT", 0, 0)
        local ticks = {}
        for k = 1, CSG_MAX - 1 do
            local t = ns.P.NoSnap(on.body:CreateTexture(nil, "ARTWORK", nil, 2))
            t:SetTexture(WHITE)
            t:SetVertexColor(0, 0, 0, 1)
            ticks[k] = t
        end
        local function Paint(charges, frac)
            local r, g, b = W.Accent(1)
            segFill:SetVertexColor(r, g, b, 1)
            segProg:SetVertexColor(r, g, b, 1)
            local bw = on.body:GetWidth() or 0
            segFill:SetWidth(math.max(0.001, bw * charges / CSG_MAX))
            segProg:SetWidth(math.max(0.001, bw / CSG_MAX * frac))
            local px = ns.P.Pixel(1)
            for k, t in ipairs(ticks) do
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", on.body, "TOPLEFT", bw * k / CSG_MAX - px / 2, 0)
                t:SetPoint("BOTTOMLEFT", on.body, "BOTTOMLEFT", bw * k / CSG_MAX - px / 2, 0)
                t:SetWidth(px)
            end
        end
        function p:Reset(now)
            self.start = now
        end
        function p:Tick(now)
            local t = now - self.start
            if t >= CSG_RECHARGE + CSG_HOLD then self:Reset(now); t = 0 end
            local full = t >= CSG_RECHARGE
            local charges = full and CSG_MAX or CSG_MAX - 1
            local frac = full and 0 or t / CSG_RECHARGE
            local left = full and nil or math.ceil(CSG_RECHARGE - t)
            off.body:SetValue(full and 1 or frac)
            PutTime(off, left)
            PutTime(on, left)
            for _, c in ipairs({ off, on }) do c.count:SetText(tostring(charges)) end
            Paint(charges, frac)
        end
        return p
    end }

    ------------------------------------------------------------
    -- 增益長條的層數（逐法術）：一個會疊層的增益，每 1.2 秒加一層到 5、八秒後掉光。
    --   層數當填充：關＝條身畫剩餘時間（往下掉）、開＝條身畫層數／5（往上跳），兩邊都印層數
    --   層數刻度：條身上第 k 層的位置畫 1px 刻度（Core/StackGate.lua）
    ------------------------------------------------------------
    local SB_STEP, SB_MAX, SB_DUR = 1.2, 5, 8
    local function StackCount(c)
        c.stacks = c.ov:CreateFontString(nil, "OVERLAY")
        ns.Media.SetFont(c.stacks, 11, "OUTLINE")
        c.stacks:SetPoint("CENTER", c.body, "CENTER", 0, 0)
    end
    local function StackTick(c, n)
        local col = ns.StackGate.TICK_COLOR
        c.ticks = {}
        for k = 1, n - 1 do
            local t = ns.P.NoSnap(c.body:CreateTexture(nil, "ARTWORK", nil, 2))
            t:SetTexture(WHITE)
            t:SetVertexColor(col.r, col.g, col.b, col.a)
            c.ticks[k] = t
        end
        function c:PlaceTicks()
            local bw, px = self.body:GetWidth() or 0, ns.P.Pixel(1)
            for k, t in ipairs(self.ticks) do
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", self.body, "TOPLEFT", bw * k / n - px / 2, 0)
                t:SetPoint("BOTTOMLEFT", self.body, "BOTTOMLEFT", bw * k / n - px / 2, 0)
                t:SetWidth(px)
            end
        end
    end
    local function BuildStacks(parent, which)
        local p = NewPanel(parent)
        local off, on = NewBar(p, "Interface\\Icons\\Spell_Nature_Rejuvenation"), NewBar(p, "Interface\\Icons\\Spell_Nature_Rejuvenation")
        off.cap:SetText(L["Off"])
        on.cap:SetText(L["On"])
        StackCount(off)
        StackCount(on)
        if which == "ticks" then StackTick(on, SB_MAX) end
        p.cells[1], p.cells[2] = off, on
        function p:Reset(now)
            self.start = now
            if on.PlaceTicks then on:PlaceTicks() end
        end
        function p:Tick(now)
            local t = now - self.start
            if t >= SB_DUR + 0.8 then self:Reset(now); t = 0 end
            local up = t < SB_DUR
            local n = up and math.min(SB_MAX, math.floor(t / SB_STEP) + 1) or 0
            local timeFrac = up and (SB_DUR - t) / SB_DUR or 0
            local left = up and math.ceil(SB_DUR - t) or nil
            off.body:SetValue(timeFrac)
            on.body:SetValue(which == "fill" and n / SB_MAX or timeFrac)
            PutTime(off, left)
            PutTime(on, left)
            for _, c in ipairs(self.cells) do c.stacks:SetText(n >= 2 and tostring(n) or "") end
        end
        return p
    end
    DEMOS.stacksAsFill = { build = function(parent) return BuildStacks(parent, "fill") end }
    DEMOS.stackTicks   = { build = function(parent) return BuildStacks(parent, "ticks") end }

    ------------------------------------------------------------
    -- 以增益取代（逐法術）：技能放出去、增益掛三秒、冷卻八秒。關＝技能格照倒冷卻，增益另外出現在增益圖示列；
    --   開＝增益掛著的那三秒這一格換成增益圖示＋增益倒數，增益消失再換回技能的冷卻（增益不再出現在增益圖示列）
    ------------------------------------------------------------
    local RW_BUFF, RW_CD, RW_READY = 3, 8, 1
    local RW_SPELL, RW_AURA = "Interface\\Icons\\Spell_Holy_PowerWordShield", "Interface\\Icons\\Spell_Holy_Renew"
    DEMOS.replaceWith = { build = function(parent)
        local p = NewPanel(parent)
        -- 關：兩格並排（技能格＋增益圖示列上的增益），整組當一欄
        local col = CreateFrame("Frame", nil, p)
        col.w, col.h = SIZE * 2 + 6, SIZE
        col:SetSize(col.w, col.h)
        local spell, buff = NewCell(col, RW_SPELL), NewCell(col, RW_AURA)
        spell.cap:Hide()
        buff.cap:Hide()
        spell:SetPoint("TOPLEFT", col, "TOPLEFT", 0, 0)
        buff:SetPoint("TOPLEFT", col, "TOPLEFT", SIZE + 6, 0)
        if spell.cd then spell.cd:SetDrawSwipe(true) end
        if buff.cd then buff.cd:SetDrawSwipe(true) end
        col.cap = Caption(p, L["Off"])
        col.cap:SetPoint("TOP", col, "BOTTOM", 0, -CAP_GAP)
        function col:Inset() spell:Inset(); buff:Inset() end
        -- 開：一格換圖
        local on = NewCell(p, RW_SPELL)
        on.cap:SetText(L["On"])
        if on.cd then on.cd:SetDrawSwipe(true) end
        p.cells[1], p.cells[2] = col, on
        function p:Reset(now)
            self.start, self.seg = now, nil
        end
        function p:Tick(now)
            local t = now - self.start
            if t >= RW_CD + RW_READY then self:Reset(now); t = 0 end
            local seg = t < RW_BUFF and 1 or t < RW_CD and 2 or 3
            if seg ~= self.seg then
                self.seg = seg
                if seg == 1 then
                    SetCD(spell, now, RW_CD)
                    spell.icon:SetDesaturated(true)
                    SetCD(buff, now, RW_BUFF)
                    buff:Show()
                    on.icon:SetTexture(RW_AURA)
                    on.icon:SetDesaturated(false)
                    SetCD(on, now, RW_BUFF)
                elseif seg == 2 then
                    buff:Hide()
                    on.icon:SetTexture(RW_SPELL)
                    on.icon:SetDesaturated(true)
                    SetCD(on, now - RW_BUFF, RW_CD)
                else
                    spell.icon:SetDesaturated(false)
                    on.icon:SetDesaturated(false)
                    PutTime(spell, nil)
                    PutTime(on, nil)
                end
            end
            if seg == 1 then
                PutTime(spell, math.ceil(RW_CD - t))
                PutTime(buff, math.ceil(RW_BUFF - t))
                PutTime(on, math.ceil(RW_BUFF - t))
            elseif seg == 2 then
                PutTime(spell, math.ceil(RW_CD - t))
                PutTime(on, math.ceil(RW_CD - t))
            end
        end
        return p
    end }

    ------------------------------------------------------------
    -- 符文（資源條）：六顆，一顆轉好、三顆在回充、兩顆排隊（同時只有三顆在轉，Modules/Resources_Rows.lua）。
    --   符文上的數字：每顆在轉的印剩餘秒數 vs 中間印一個轉好的顆數
    --   計入等待中的符文：關＝排隊的那兩顆空著、輪到才開始填；開＝從用掉那一刻起跨整段等待慢慢填、印到轉好的秒數
    ------------------------------------------------------------
    local RUNE_N, RUNE_W, RUNE_H, RUNE_GAP, RUNE_T = 6, 18, 14, 2, 9
    local RUNE_C = { 0.77, 0.12, 0.23 }
    -- 每顆的回充區間 [從, 到]（相對循環起點）：1 轉好；2～4 在轉；5、6 排隊（等 2、3 轉好才輪到）
    local RUNE_SPAN = { nil, { -2, 2 }, { -1, 3 }, { 0, 4 }, { 2, 6 }, { 3, 7 } }
    local function NewRuneRow(parent)
        local c = CreateFrame("Frame", nil, parent)
        c.w, c.h = RUNE_N * RUNE_W + (RUNE_N - 1) * RUNE_GAP, RUNE_H
        c:SetSize(c.w, c.h)
        c.segs = {}
        for i = 1, RUNE_N do
            local s = CreateFrame("StatusBar", nil, c)
            s:SetSize(RUNE_W, RUNE_H)
            s:SetPoint("LEFT", c, "LEFT", (i - 1) * (RUNE_W + RUNE_GAP), 0)
            s:SetStatusBarTexture(WHITE)
            ns.P.NoSnap(s)
            s:SetMinMaxValues(0, 1)
            local bg = ns.P.NoSnap(s:CreateTexture(nil, "BACKGROUND"))
            bg:SetAllPoints()
            bg:SetColorTexture(RUNE_C[1] * 0.2, RUNE_C[2] * 0.2, RUNE_C[3] * 0.2, 1)
            local ov = CreateFrame("Frame", nil, s)
            ov:SetAllPoints()
            ov:SetFrameLevel(s:GetFrameLevel() + 2)
            s.timer = ov:CreateFontString(nil, "OVERLAY")
            ns.Media.SetFont(s.timer, 9, "OUTLINE")
            s.timer:SetPoint("CENTER")
            c.segs[i] = s
        end
        local ov = CreateFrame("Frame", nil, c)
        ov:SetAllPoints()
        ov:SetFrameLevel(c:GetFrameLevel() + 5)
        c.count = ov:CreateFontString(nil, "OVERLAY")
        ns.Media.SetFont(c.count, 11, "OUTLINE")
        c.count:SetPoint("CENTER")
        c.cap = Caption(parent)
        c.cap:SetPoint("TOP", c, "BOTTOM", 0, -CAP_GAP)
        -- text："countdown"｜"count"；queued：計入等待中的符文
        function c:Paint(t, text, queued)
            local ready = 0
            for i, s in ipairs(self.segs) do
                local span = RUNE_SPAN[i]
                local isReady = not span or t >= span[2]
                local prog, sec
                if isReady then
                    prog = 1
                    ready = ready + 1
                else
                    local from = span[1]
                    local waiting = t < from
                    if waiting and not queued then
                        prog = 0
                    else
                        local start = queued and math.min(from, 0) or from
                        prog = (t - start) / (span[2] - start)
                        sec = math.ceil(span[2] - t)
                    end
                end
                s:SetValue(prog)
                if isReady then s:SetStatusBarColor(RUNE_C[1], RUNE_C[2], RUNE_C[3], 1)
                else s:SetStatusBarColor(RUNE_C[1] * 0.6, RUNE_C[2] * 0.6, RUNE_C[3] * 0.6, 1) end
                local txt = (text == "countdown" and sec) and tostring(sec) or ""
                if s.shown ~= txt then
                    s.shown = txt
                    s.timer:SetText(txt)
                end
            end
            local ct = text == "count" and tostring(ready) or ""
            if self.shownCount ~= ct then
                self.shownCount = ct
                self.count:SetText(ct)
            end
        end
        return c
    end
    local function BuildRunes(parent, defs)
        local p = NewPanel(parent)
        for i, d in ipairs(defs) do
            local c = NewRuneRow(p)
            c.cap:SetText(d[1])
            c.text, c.queued = d[2], d[3]
            p.cells[i] = c
        end
        function p:Reset(now) self.start = now end
        function p:Tick(now)
            local t = now - self.start
            if t >= RUNE_T then self:Reset(now); t = 0 end
            for _, c in ipairs(self.cells) do c:Paint(t, c.text, c.queued) end
        end
        return p
    end
    DEMOS.runeText = { build = function(parent)
        return BuildRunes(parent, { { L["Seconds left on each rune"], "countdown", true }, { L["Ready runes count"], "count", true } })
    end }
    DEMOS.runeQueued = { build = function(parent)
        return BuildRunes(parent, { { L["Off"], "countdown", false }, { L["On"], "countdown", true } })
    end }

    ------------------------------------------------------------
    -- 氣漩武器「折疊成 5 段」（資源條）：層數 0→10 每 0.45 秒加一、滿了停一秒。關＝十格；開＝五格，第 6～10 層疊在同五格上、
    --   用溢出色（colors.MaelstromWeapon.overflowColor，Modules/Resources.lua 的「氣漩武器摺疊」）
    ------------------------------------------------------------
    local MW_STEP, MW_MAX, MW_HOLD, MW_H, MW_GAP = 0.45, 10, 1, 12, 2
    local MW_C, MW_OVER = { 0.2, 0.65, 1 }, { 1, 0.82, 0.2 }
    local function NewSegRow(parent, n, segW)
        local c = CreateFrame("Frame", nil, parent)
        c.w, c.h = n * segW + (n - 1) * MW_GAP, MW_H
        c:SetSize(c.w, c.h)
        c.segs = {}
        for i = 1, n do
            local s = CreateFrame("Frame", nil, c)
            s:SetSize(segW, MW_H)
            s:SetPoint("LEFT", c, "LEFT", (i - 1) * (segW + MW_GAP), 0)
            s.bg = ns.P.NoSnap(s:CreateTexture(nil, "BACKGROUND"))
            s.bg:SetAllPoints()
            s.bg:SetColorTexture(MW_C[1] * 0.2, MW_C[2] * 0.2, MW_C[3] * 0.2, 1)
            s.fill = ns.P.NoSnap(s:CreateTexture(nil, "ARTWORK"))
            s.fill:SetAllPoints()
            s.fill:SetColorTexture(MW_C[1], MW_C[2], MW_C[3], 1)
            s.fill:Hide()
            c.segs[i] = s
        end
        c.cap = Caption(parent)
        c.cap:SetPoint("TOP", c, "BOTTOM", 0, -CAP_GAP)
        return c
    end
    DEMOS.maelstromFold = { build = function(parent)
        local p = NewPanel(parent)
        local off = NewSegRow(p, MW_MAX, 9)
        local on = NewSegRow(p, MW_MAX / 2, 20)
        off.cap:SetText(L["Off"])
        on.cap:SetText(L["On"])
        p.cells[1], p.cells[2] = off, on
        function p:Reset(now) self.start, self.n = now, nil end
        function p:Tick(now)
            local t = now - self.start
            if t >= MW_STEP * (MW_MAX + 1) + MW_HOLD then self:Reset(now); t = 0 end
            local n = math.min(MW_MAX, math.floor(t / MW_STEP))
            if n == self.n then return end
            self.n = n
            for i, s in ipairs(off.segs) do s.fill:SetShown(i <= n) end
            local half = MW_MAX / 2
            for i, s in ipairs(on.segs) do
                s.fill:SetShown(i <= n)
                if i <= n - half then s.fill:SetColorTexture(MW_OVER[1], MW_OVER[2], MW_OVER[3], 1)
                else s.fill:SetColorTexture(MW_C[1], MW_C[2], MW_C[3], 1) end
            end
        end
        return p
    end }

    ------------------------------------------------------------
    -- 天空騎術「位置」三選一：小版面圖，每 2.5 秒在地面／天空騎術之間切。上面一排四顆＝核心技能、底下一條＝資源條、
    --   三條細的＝天空騎術列。接力（核心技能的位置）＝騎上去時那一排換成三條細的；接力（資源條的位置）＝那一條換成；
    --   獨立＝兩個都留著，三條細的出現在自己的位置
    ------------------------------------------------------------
    local SK_PHASE, SK_W, SK_ICON, SK_BAR_H, SK_GAP = 2.5, 64, 10, 6, 5
    local function SkyIcons(parent)
        local f = CreateFrame("Frame", nil, parent)
        f:SetSize(SK_ICON * 4 + 3 * 2, SK_ICON)
        for i = 1, 4 do
            local t = ns.P.NoSnap(f:CreateTexture(nil, "ARTWORK"))
            t:SetSize(SK_ICON, SK_ICON)
            t:SetPoint("LEFT", f, "LEFT", (i - 1) * (SK_ICON + 2), 0)
            t:SetColorTexture(0.55, 0.55, 0.55, 1)
        end
        return f
    end
    local function SkyBar(parent, w, h, r, g, b)
        local f = CreateFrame("Frame", nil, parent)
        f:SetSize(w, h)
        local t = ns.P.NoSnap(f:CreateTexture(nil, "ARTWORK"))
        t:SetAllPoints()
        t:SetColorTexture(r, g, b, 1)
        return f
    end
    local function SkyBars(parent)
        local f = CreateFrame("Frame", nil, parent)
        local h = 3
        f:SetSize(SK_W, h * 3 + 2 * 2)
        local colors = { { 0.3, 0.8, 1 }, { 1, 0.75, 0.2 }, { 0.5, 0.9, 0.4 } }
        for i = 1, 3 do
            local b = SkyBar(f, SK_W, h, unpack(colors[i]))
            b:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(i - 1) * (h + 2))
        end
        return f
    end
    DEMOS.skyPlacement = { build = function(parent)
        local p = NewPanel(parent)
        local defs = { { "essential", L["Relay (Essential Cooldowns' spot)"] }, { "resources", L["Relay (resource bar's spot)"] },
                       { "standalone", L["Standalone"] } }
        local slotH = { SK_ICON, SK_BAR_H, 13 }
        for i, d in ipairs(defs) do
            local col = CreateFrame("Frame", nil, p)
            col.mode = d[1]
            col.w, col.h = SK_W, SK_ICON + SK_GAP + SK_BAR_H + SK_GAP + 13
            col:SetSize(col.w, col.h)
            col.icons = SkyIcons(col)
            col.icons:SetPoint("TOP", col, "TOP", 0, 0)
            col.res = SkyBar(col, SK_W, SK_BAR_H, W.Accent(1))
            col.res:SetPoint("TOP", col, "TOP", 0, -(SK_ICON + SK_GAP))
            col.sky = SkyBars(col)
            col.cap = Caption(p, d[2])
            col.cap:SetPoint("TOP", col, "BOTTOM", 0, -CAP_GAP)
            function col:Apply(flying)
                self.icons:SetShown(not (flying and self.mode == "essential"))
                self.res:SetShown(not (flying and self.mode == "resources"))
                self.sky:SetShown(flying)
                self.sky:ClearAllPoints()
                if self.mode == "essential" then
                    self.sky:SetPoint("TOP", self, "TOP", 0, 0)
                elseif self.mode == "resources" then
                    self.sky:SetPoint("TOP", self, "TOP", 0, -(SK_ICON + SK_GAP))
                else
                    self.sky:SetPoint("TOP", self, "TOP", 0, -(SK_ICON + SK_GAP + SK_BAR_H + SK_GAP))
                end
            end
            p.cells[i] = col
        end
        p.status = Caption(p)
        p.status:SetJustifyH("LEFT")
        p.statusTexts = { L["On the ground"], L["Skyriding"] }
        function p:Reset(now) self.start, self.flying = now, nil end
        function p:Tick(now)
            local flying = ((now - self.start) % (SK_PHASE * 2)) >= SK_PHASE
            if flying == self.flying then return end
            self.flying = flying
            self.status:SetText(self.statusTexts[flying and 2 or 1])
            for _, col in ipairs(self.cells) do col:Apply(flying) end
        end
        return p
    end }

    ------------------------------------------------------------
    -- 彈窗與「!」
    ------------------------------------------------------------
    local function Popup()
        if popup then return popup end
        popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        popup:SetFrameStrata("TOOLTIP")
        popup:SetClampedToScreen(true)
        popup:Hide()
        popup.title = popup:CreateFontString(nil, "OVERLAY")
        popup.title:SetFontObject(W.fontNormal)
        popup.title:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD, -PAD)
        popup.panels = {}
        popup:SetScript("OnUpdate", function(self)
            -- 設定視窗在滑鼠還停著時被關掉：不一定等得到 OnLeave
            if not (self.owner and self.owner:IsVisible()) then self:Hide() return end
            local p = self.panel
            if p and p.Tick then p:Tick(GetTime()) end
        end)
        popup:SetScript("OnHide", function(self)
            if self.panel then
                if self.panel.Stop then self.panel:Stop() end
                self.panel:Hide()
            end
            self.panel, self.owner = nil, nil
        end)
        return popup
    end

    local function Show(owner, id, label)
        local def = DEMOS[id]
        if not def then return end
        local pop = Popup()
        if pop.panel and pop.panel ~= pop.panels[id] then
            if pop.panel.Stop then pop.panel:Stop() end
            pop.panel:Hide()
        end
        local panel = pop.panels[id]
        if not panel then
            panel = def.build(pop)
            pop.panels[id] = panel
        end
        ns.Style.ApplyTooltipPanel(pop)              -- 1px 邊在顯示時換算（1px 規則 ③）
        pop.title:SetText(label or "")
        pop:ClearAllPoints()
        pop:SetPoint("BOTTOMLEFT", owner, "TOPRIGHT", 4, 4)   -- 同 GameTooltip 的 ANCHOR_RIGHT
        pop.owner, pop.panel = owner, panel
        panel:Show()
        pop:Show()
        panel:Layout()
        local top = PAD + math.ceil(pop.title:GetStringHeight()) + 8
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", pop, "TOPLEFT", PAD, -top)
        pop:SetSize(math.max(panel.w, math.ceil(pop.title:GetStringWidth())) + PAD * 2, top + panel.h + PAD)
        if panel.Reset then panel:Reset(GetTime()) end
    end

    -- id：DEMOS 的鍵（或回傳鍵的函式）；label：彈窗標題（那一列的名字）。位置由呼叫端錨
    function Specs.DemoMark(parent, id, label)
        local m = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        ns.P.Size(m, 16, 16)
        W.Stylize(m, { 0.1, 0.1, 0.1, 0.9 }, { 0.4, 0.4, 0.4, 1 })
        local q = m:CreateFontString(nil, "OVERLAY")
        q:SetFontObject(W.fontSmall)
        q:SetPoint("CENTER", m, "CENTER", 0, 0)
        q:SetText("!")
        q:SetTextColor(0.6, 0.6, 0.6)
        m:EnableMouse(true)
        m:SetScript("OnEnter", function(self)
            q:SetTextColor(1, 1, 1)
            Show(self, type(id) == "function" and id() or id, label)
        end)
        m:SetScript("OnLeave", function()
            q:SetTextColor(0.6, 0.6, 0.6)
            if popup then popup:Hide() end
        end)
        return m
    end
end

------------------------------------------------------------
-- 版面（條自己的欄位）
------------------------------------------------------------
------------------------------------------------------------
-- 格數上限＋溢出（Core/Overflow.lua）：「最多顆數」滑桿＋灰字、「超出的放到」下拉＋灰字。圖示類的條才有。
--   * 下拉的候選：其他圖示類、自己沒設上限的條（接收條不能再溢出）；目前存的目標就算不成立也列出來（灰字寫原因）
--   * 自己沒設上限時下拉停用（值不動）
--   * 被別條指為接收條（那條有設上限）：滑桿停用、灰字寫原因
-- 誰指到誰、誰有上限都進 BarSignature（自己的上限除外：拖滑桿過 0 不能整張表單重建），所以候選清單與原因字
-- 在建表單時算就準
------------------------------------------------------------
local function OverflowRows(key)
    local O, C = ns.Overflow, ns.Catalog
    local cfgOf = C.BarCfgOf
    local keys = C.BarKeys()
    local function Title(k) return ns.Options.BarTitle(k) or tostring(k) end
    local rows = {}
    local recv = O.Receivers(keys, cfgOf)[key]
    local function Receiving() return O.Receivers(C.BarKeys(), cfgOf)[key] ~= nil end
    rows[#rows + 1] = BS("slider", "layout.maxIcons", L["Max icons"], { min = 0, max = O.MAX, step = 1,
        fallback = 0,
        get = function() return O.MaxOf(cfgOf(key)) end,
        disabled = Receiving })
    if recv then
        local names = {}
        for i, k in ipairs(recv) do names[i] = Title(k) end
        rows[#rows + 1] = Note(L["This bar takes the overflow from %s, so it can't have a limit of its own."]
            :format(table.concat(names, " / ")))
    else
        rows[#rows + 1] = Note(L["0 means no limit. Icons past the limit move to the bar chosen below."])
    end

    local cur = O.TargetKey(cfgOf(key))
    local items = { { text = L["None"], value = "none" } }
    for _, k in ipairs(keys) do
        local b = cfgOf(k)
        if k ~= key and (k == cur or (b.kind ~= "bars" and O.MaxOf(b) == 0)) then
            items[#items + 1] = { text = Title(k), value = k }
        end
    end
    rows[#rows + 1] = BS("dropdown", "layout.overflowTo", L["Overflow to"], { items = items, refreshPage = true,
        resetPaths = { "layout.overflowTo" },
        get = function()
            local to = O.TargetKey(cfgOf(key))
            return (to and cfgOf(to)) and to or "none"
        end,
        set = function(_, v)
            local b = ns.DB.BarTable(key)
            if not b then return end
            if type(b.layout) ~= "table" then b.layout = {} end
            b.layout.overflowTo = (v ~= "none" and v ~= key) and v or false
        end,
        disabled = function() return O.MaxOf(cfgOf(key)) <= 0 end })
    -- 存的目標不成立的原因（跟自己的上限無關的那三種）；成立或沒選就是一般說明
    local why
    if cur and cur ~= key then
        local t = cfgOf(cur)
        if not t then why = "missing"
        elseif t.kind == "bars" then why = "notIcons"
        elseif O.MaxOf(t) > 0 then why = "capped" end
    end
    if why == "notIcons" then
        rows[#rows + 1] = Note(L["%s shows bars, not icons, so the number of icons isn't limited."]:format(Title(cur)))
    elseif why == "capped" then
        rows[#rows + 1] = Note(L["%s has a limit of its own, so the number of icons isn't limited."]:format(Title(cur)))
    else
        rows[#rows + 1] = Note(L["Without a target, the number of icons isn't limited."])
    end
    return rows
end

-- 表單簽章裡的溢出那一段：別條的「有沒有上限／指到誰／類型」＋自己指到誰（自己的上限不進：見 OverflowRows）
function Specs.OverflowSig(key)
    local O, C = ns.Overflow, ns.Catalog
    if not (O and C and C.BarKeys) then return "" end
    local parts = {}
    for _, k in ipairs(C.BarKeys()) do
        local b = C.BarCfgOf(k)
        local to = O.TargetKey(b) or "-"
        if k == key then
            parts[#parts + 1] = "@>" .. to
        else
            parts[#parts + 1] = k .. (b.kind == "bars" and "b" or "i") .. (O.MaxOf(b) > 0 and "#" or "") .. ">" .. to
        end
    end
    return table.concat(parts, ",")
end

-- 長條的外觀（bar.look）：米利樣式／暴雪樣式
local BAR_LOOK_ITEMS = {
    { text = L["MiliUI style"],   value = "miliui" },
    { text = L["Blizzard style"], value = "blizzard" },
}
-- 這條自己的 bar 子表（沒有 ＝ 空表，只讀）
function BarCfg(info)
    local b = info and ns.DB.ConfigTable(info.key)
    return type(b) == "table" and type(b.bar) == "table" and b.bar or {}
end
-- 這條現在**生效**的是暴雪樣式（直向＋暴雪存著也算米利，見 Decorate.BarLook）。條頁以外（主題頁）一律 false
function BlizzBarLook(info)
    if not info or info.mode == "theme" then return false end
    local b = info.key and ns.DB.ConfigTable(info.key)
    if type(b) ~= "table" or b.kind ~= "bars" then return false end
    return ns.Decorate.BarLook(b.bar) == "blizzard"
end

-- 漸層填充（bar.gradient，F8a）：勾選＋方向＋終點色＋灰字。關 ＝ false；勾下去給一組預設
-- （方向橫、終點色＝條色往白混一半）。方向與終點色沒勾時停用、右鍵不重設（整組由勾選那列重設）
local GRADIENT_DIR_ITEMS = {
    { text = L["Horizontal"], value = "H" },
    { text = L["Vertical"],   value = "V" },
}
local function GradientRows(key)
    local function Cfg(info)
        local b = ns.DB.ConfigTable(info and info.key or key)
        return type(b) == "table" and type(b.bar) == "table" and b.bar or nil
    end
    local function On(info)
        local bar = Cfg(info)
        return bar ~= nil and ns.Decorate.CleanGradient(bar.gradient) ~= nil
    end
    return {
        BS("toggle", "bar.gradient", L["Gradient"], {
            get = function(info) return On(info) end,
            set = function(info, on)
                local bar = Cfg(info)
                if not bar then return end
                if on then
                    local c = type(bar.color) == "table" and bar.color or {}
                    local function mix(v, d) return ((tonumber(v) or d) + 1) / 2 end
                    bar.gradient = { dir = "H", color2 = { r = mix(c.r, 0.4), g = mix(c.g, 0.6), b = mix(c.b, 0.9),
                                                           a = tonumber(c.a) or 1 } }
                else
                    bar.gradient = false
                end
            end }),
        BS("dropdown", "bar.gradient.dir", L["Gradient direction"], { items = GRADIENT_DIR_ITEMS, noReset = true,
            get = function(info)
                local bar = Cfg(info)
                local g = bar and type(bar.gradient) == "table" and bar.gradient or nil
                return (g and g.dir == "V") and "V" or "H"
            end,
            set = function(info, v)
                local bar = Cfg(info)
                if bar and type(bar.gradient) == "table" then bar.gradient.dir = (v == "V") and "V" or "H" end
            end,
            disabled = function(info) return not On(info) end }),
        BS("color", "bar.gradient.color2", L["Gradient end color"], { noReset = true,
            get = function(info)
                local bar = Cfg(info)
                local g = bar and type(bar.gradient) == "table" and bar.gradient or nil
                return g and type(g.color2) == "table" and g.color2 or nil
            end,
            set = function(info, c)
                local bar = Cfg(info)
                if bar and type(bar.gradient) == "table" and type(c) == "table" then bar.gradient.color2 = c end
            end,
            disabled = function(info) return not On(info) end }),
        Note(L["The fill fades from the bar color to the end color: left to right when horizontal, bottom to top when vertical."]),
    }
end

------------------------------------------------------------
-- 圓環顯示（layout.style ＝ "rings"；Core/Layout.lua 的 ComputeRings、Core/Decorate.lua 的「圓環顯示」）：
-- 圖示類的條最上面一列「顯示樣式」（切換時整張表單重建：BarSignature 帶著 style）。圓環條只收增益 ⇒ 這一列只在
-- 增益圖示列與自訂圖示群組出現（核心／輔助沒有）。圓環時每列上限／成長方向／
-- 第二列尺寸／間距／可點擊藏起來（同心圓用不到），換成下面這幾列；格數上限＋溢出、增益不在時照常
------------------------------------------------------------
local STYLE_ITEMS = {
    { text = L["Icons"], value = "icons" },
    { text = L["Rings"], value = "rings" },
}
local RING_DIR_ITEMS = {
    { text = L["Inside out"],  value = "outward" },
    { text = L["Outside in"],  value = "inward" },
}
local RING_TIME_ITEMS = {
    { text = L["Ring top"],   value = "top" },
    { text = L["Don't show"], value = "hide" },
}

local function RingTable(info)
    local b = ns.DB.ConfigTable(info.key)
    if type(b) ~= "table" then return nil end
    if type(b.ring) ~= "table" then b.ring = {} end
    return b.ring
end

-- 職業色（填色 false）時色票顯示的顏色：每次一張新表（色票停用中，不會被就地改）
local function ClassColorTable()
    local r, g, b = ns.Style.Accent()
    return { r = r, g = g, b = b, a = 1 }
end

local function RingRows(key, add)
    local LY = ns.Layout
    local T, G, I = LY.RING_THICK, LY.RING_GAP, LY.RING_ICON
    local function ClassFill(info)
        local r = ns.DB.GetPath(ns.DB.ConfigTable(info.key), "ring.fillColor")
        return type(r) ~= "table"
    end
    local function IconOff(info)
        return not ns.DB.GetPath(ns.DB.ConfigTable(info.key), "ring.showIcon")
    end
    add(BS("slider", "layout.size.w", L["Inner ring diameter"], { min = 16, max = 600, step = 1 }))
    add(BS("slider", "ring.thickness", L["Ring width"], { min = T.min, max = T.max, step = 1 }))
    add(BS("slider", "ring.gap", L["Ring gap"], { min = G.min, max = G.max, step = 1 }))
    add(BS("dropdown", "ring.direction", L["Ring direction"], { items = RING_DIR_ITEMS }))
    add(Note(L["Inside out puts the first item on the innermost ring; outside in puts it on the outermost."]))
    add(BS("color", "ring.trackColor", L["Track color"], { hasAlpha = true }))
    add(BS("toggle", "ring.fillColor", L["Use class color"], {
        get = function(info) return ClassFill(info) end,
        set = function(info, on)
            local ring = RingTable(info)
            if not ring then return end
            ring.fillColor = on and false or ClassColorTable()      -- 取消勾選：從現在的職業色開始調
        end }))
    add(BS("color", "ring.fillColor", L["Fill color"], { hasAlpha = true, noReset = true,
        get = function(info)
            local c = ns.DB.GetPath(ns.DB.ConfigTable(info.key), "ring.fillColor")
            return type(c) == "table" and c or ClassColorTable()
        end,
        disabled = ClassFill }))
    add(BS("dropdown", "ring.timeText", L["Countdown text"], { items = RING_TIME_ITEMS }))
    add(BS("toggle", "ring.showIcon", L["Show spell icon"]))
    add(BS("slider", "ring.iconSize", L["Icon size"], { min = I.min, max = I.max, step = 1, disabled = IconOff }))
    add(Note(L["The icon covers the neighboring rings when it's bigger than the ring width plus the gap."]))
end

function Specs.Layout(key)
    local bar = ns.DB.BarTable(key) or {}
    local kind = bar.kind == "bars" and "bars" or "icons"
    local list = { { type = "header", label = L["Layout"], tab = "layout" } }
    local function add(s) list[#list + 1] = s end

    local rings = kind == "icons" and ns.DB.BarIsRings(key)
    -- 顯示樣式：圓環條只收增益 ⇒ 只有增益圖示列與自訂圖示群組有這一列（核心／輔助沒有；存著 rings 的當圖示看，DB.BarIsRings）
    if kind == "icons" and ns.DB.RingsAllowed(bar.source) then
        add(BS("dropdown", "layout.style", L["Display style"], { items = STYLE_ITEMS, refreshPage = true,
            get = function(info) return ns.DB.BarIsRings(info.key) and "rings" or "icons" end }))
        if rings then
            add(Note(L["Each item becomes a ring around the same center, and the lit part shrinks as time runs out. Ring bars only take buffs, and don't draw glows or keybinds."]))
        end
        -- 增益圖示列：整條轉圓環通常不是想要的，引導去開圓環群組、只挑幾個效果
        if bar.source == "buffs" then
            add(Note(L["To show only a few effects as rings, add a ring group in the left column, then click each effect in the preview and set “On bar” to it."]))
        end
    end
    if rings then
        for _, row in ipairs(OverflowRows(key)) do add(row) end
        RingRows(key, add)
        if bar.source == "buffs" or bar.source == "custom" then
            add(EmptyModeRow(key))
            add(Note(L["Set it to “Hide, keep the slot” to keep each effect on the same ring."]))
        end
        return list
    end

    if kind == "icons" then
        add(BS("slider", "layout.maxPerRow", L["Icons per row"], { min = 1, max = 20, step = 1 }))
        for _, row in ipairs(OverflowRows(key)) do add(row) end
    end
    add(BS("slider", "layout.spacing", L["Spacing"], { min = 0, max = 20, step = 1 }))
    local vertical = kind == "bars" and type(bar.bar) == "table" and bar.bar.vertical and true or false
    if kind == "bars" then
        -- 長條的 grow 兩套值互通（Layout.Compute 兩邊都認）：顯示時換成這個方向那一套的值
        add(BS("dropdown", "layout.grow", L["Growth"], { items = GrowItems(kind, vertical),
            get = function(info)
                local g = ns.DB.GetPath(ns.DB.ConfigTable(info.key), "layout.grow")
                if vertical then
                    local a, b = ns.Layout.VerticalBarGrow(g)
                    return a .. "_" .. b
                end
                local col = ns.Layout.ParseColumn(g)
                if col then return "CENTER_" .. col end
                local _, v = ns.Layout.ParseGrow(g)
                return "CENTER_" .. v
            end }))
    else
        add(BS("dropdown", "layout.grow", L["Growth"], { items = GrowItems(kind) }))
    end
    if kind == "icons" then
        add(BS("numbers", nil, L["Icon size"], { sub = "layout.size", path = false, resetPaths = { "layout.size" },
            fields = { { key = "w", label = L["W"] }, { key = "h", label = L["H"] } } }))
        add(BS("toggle", "layout.row2Size", L["Separate size for row 2+"], {
            refreshPage = true,
            get = function() return type(ns.DB.GetPath(ns.DB.BarTable(key), "layout.row2Size")) == "table" end,
            set = function(_, on)
                local b = ns.DB.BarTable(key)
                if not b then return end
                if on then
                    local size = b.layout and b.layout.size or {}
                    b.layout.row2Size = { w = tonumber(size.w) or 36, h = tonumber(size.h) or 36 }
                else
                    b.layout.row2Size = false
                end
            end,
        }))
        if type(bar.layout) == "table" and type(bar.layout.row2Size) == "table" then
            add(BS("numbers", nil, L["Row 2+ size"], { sub = "layout.row2Size", path = false,
                resetPaths = { "layout.row2Size" }, refreshPage = true,
                fields = { { key = "w", label = L["W"] }, { key = "h", label = L["H"] } } }))
        end
        if bar.source == "custom" then
            -- 可點擊：勾了之後「增益不在時」不能選往前補（那一列的原因字），所以排在它前面
            add(BS("toggle", "clickable", L["Clickable"], { level = "layout", refreshPage = true }))
            add(Note(L["Icons cast their spell or use their item when clicked, like action bar buttons. Aura slots are not affected."]))
        end
        if bar.source == "buffs" or bar.source == "custom" then
            add(EmptyModeRow(key))
        end
    else
        add(BS("slider", "bar.width", L["Width"], { min = 0, max = 600, step = 1 }))
        add(Note(L["0 matches the first row of Essential Cooldowns."]))
        add(BS("slider", "bar.height", L["Height"], { min = 6, max = 60, step = 1 }))
        -- 直向（F8c）：整條轉 90 度；表單要換圖示位置的字與成長方向的選項 ⇒ 重建。
        -- 外觀＝暴雪樣式時停用（暴雪樣式只有橫向；原因寫在「外觀」下面那一句）——看的是生效值（BarLook），
        -- 兩個都存著的舊值（直向＋暴雪）時直向這格照樣能關，不會兩格互鎖
        add(BS("toggle", "bar.vertical", L["Vertical"], { refreshPage = true, disabled = BlizzBarLook }))
        add(Note(L["The bar stands upright and fills from the bottom; bars line up side by side. Width is the bar's length and height its thickness. Names aren't shown, and the time sits at the top of the bar."]))
        add(BS("toggle", "bar.reverseFill", L["Reverse fill"]))
        add(Note(L["Fills from the right instead of the left (from the top when vertical)."]))
        -- 圖示位置 2026-10-24 搬到「圖示」節（主題欄位 icon.barIconSide，跟隨主題；直向時那邊的字換成上／下）
        add(BS("slider", "bar.iconGap", L["Icon gap"], { min = 0, max = 10, step = 1 }))
        -- 充能分段（F8b，Modules/Custom.lua）：只對自己加的、有充能的法術；分隔線色沒勾時停用
        add(BS("toggle", "bar.chargeSegments", L["Charge segments"], { demo = "chargeSegments" }))
        add(BS("color", "bar.chargeLineColor", L["Divider color"], { hasAlpha = true,
            disabled = function(info) return not ns.DB.GetPath(ns.DB.ConfigTable(info.key), "bar.chargeSegments") end }))
        add(Note(L["Spells with charges that you added yourself: one segment per charge, and the one recharging fills up."]))
        -- 邊緣陰影（Core/Decorate.lua 的 D.BarShadow → Core/Shape.lua）：整個 item 一圈；暴雪樣式沒有邊框也就不畫陰影
        local function ShadowOff(info)
            return BlizzBarLook(info) or not ns.DB.GetPath(ns.DB.ConfigTable(info.key), "bar.shadow")
        end
        add(BS("toggle", "bar.shadow", L["Shadow"], { refreshPage = true, disabled = BlizzBarLook }))
        add(BS("slider", "bar.shadowSize", L["Shadow size"], { min = 1, max = 8, step = 1, disabled = ShadowOff }))
        add(BS("slider", "bar.shadowAlpha", L["Shadow opacity"], { min = 10, max = 100, step = 5, scale = 100,
            disabled = ShadowOff }))
        add(Note(L["Drawn around the whole bar, icon included. Blizzard style has no shadow."]))
        if bar.source == "buffbars" or bar.source == "custom" then
            -- 空長條＝EllesmereUI 長條「未作用時隱藏」關掉時那一條；留空位＝它圖示的 Keep Buffs in Same Place
            add(EmptyModeRow(key, true))
        end
        -- 外觀（米利／暴雪樣式，Core/Decorate.lua 的「長條的暴雪樣式」）：直向時停用（暴雪樣式只有橫向）。
        -- 暴雪樣式時材質、底色、漸層停用；「條色」那一列改讀寫 bar.blizzardColor（兩個顏色分開存）
        add(BS("dropdown", "bar.look", L["Appearance"], { items = BAR_LOOK_ITEMS, refreshPage = true,
            get = function(info) return BarCfg(info).look == "blizzard" and "blizzard" or "miliui" end,
            disabled = function(info) return BarCfg(info).vertical and true or false end }))
        add(Note(L["Blizzard style only works on horizontal bars."]))
        local blizzLook = ns.Decorate.BarLook(type(bar.bar) == "table" and bar.bar or nil) == "blizzard"
        add(BS("dropdown", "bar.texture", L["Texture"], { items = TextureItems, disabled = BlizzBarLook }))
        if blizzLook then
            -- 舊的自訂群組沒有這一欄（預設值只在 NewBarTable）：第一次讀時補上預設的橘色，色票才有表可以就地改
            add(BS("color", "bar.blizzardColor", L["Bar color"], {
                get = function(info)
                    local b = BarCfg(info)
                    if b.look == "blizzard" and type(b.blizzardColor) ~= "table" then
                        local d = ns.Decorate.BLIZZ_COLOR
                        b.blizzardColor = { r = d.r, g = d.g, b = d.b, a = d.a }
                    end
                    return b.blizzardColor
                end }))
        else
            add(BS("color", "bar.color", L["Bar color"]))
        end
        add(BS("color", "bar.bgColor", L["Background color"], { disabled = BlizzBarLook }))
        for _, row in ipairs(GradientRows(key)) do
            if blizzLook then row.disabled = BlizzBarLook end
            add(row)
        end
        add(BS("toggle", "bar.spark", L["Show spark"]))
        add(Note(L["A bright marker at the moving end of the bar."]))
    end
    return list
end

------------------------------------------------------------
-- 顯示條件
------------------------------------------------------------
function Specs.Visibility()
    return {
        { type = "header", label = L["Visibility"], tab = "visibility" },
        Nested(L["Show when"]),
        BS("toggle", "visibility.showCombat", L["In combat"]),
        BS("toggle", "visibility.showTarget", L["Has a target"]),
        BS("toggle", "visibility.showEnemy", L["Has a hostile target"]),
        Note(L["Leave all unchecked to always show. Check any to show only while one of them is true."]),
        Nested(L["Restrictions"]),
        BS("toggle", "visibility.hideMounted", L["Hide while mounted"]),
        BS("toggle", "visibility.hideSkyriding", L["Hide while skyriding"]),
        Note(L["While on a mount that can skyride, even on the ground."]),
        BS("toggle", "visibility.hideHousing", L["Hide in housing"]),
        Note(L["While inside a house or on a housing plot."]),
        BS("toggle", "visibility.hideResting", L["Hide while resting"]),
        Note(L["While in an inn or a major city."]),
        BS("toggle", "visibility.hideVehicle", L["Hide in vehicle"]),
        Note(L["Only while in a vehicle; riding a mount does not count. \"Hide while mounted\" covers both."]),
        BS("toggle", "visibility.onlyInstances", L["Only in instances"]),
        BS("dropdown", "visibility.group", L["Group"], { items = GROUP_ITEMS }),
        Note(L["Restrictions win over \"Show when\"."]),
    }
end

------------------------------------------------------------
-- 錨定
--
-- 表單裡只放一列摘要（「核心技能，上緣中點 → 下緣中點」／「自己的位置」）＋「設定」鈕；跟著誰、雙九宮格、偏移都在
-- 錨定視窗（Options/AnchorWindow.lua）。這裡出借給視窗的零件（只有一份）：
--   Specs.AnchorTargetSpec(key, root, disabled)  「跟著哪條走」下拉（候選＋寫入規則）
--   Specs.FrameNameRow(key, disabled)            指定框架名稱的輸入列
--   Specs.EmphasisNote(text)                     黃字一句
--   Specs.ExternalUnresolved(key)                錨在外部目標上、但現在用的是自己的備用位置
--   Specs.AnchorTargetLabel(to)                  錨定目標的顯示名（條／面板的頁名、單位框、框名）
--   Specs.ANCHOR_POINT_TEXT[point]               錨點在「錨定」語境的名字（上緣中點、左上角…）
--   Specs.AnchorCursorGate(key)                  跟著游標開著時錨定停用的判斷（不能跟游標的條回 nil）
------------------------------------------------------------
-- 候選：左欄的條（barOrder）＋ 面板（資源條、自訂格子、施法條；它們不在 barOrder 裡）
local ANCHOR_SEP = "__sep"
local function AnchorItems(key)
    local items = { { text = L["None (own position)"], value = "none" } }
    local p = ns.profile
    local cand = {}
    for _, other in ipairs(p and p.barOrder or {}) do cand[#cand + 1] = other end
    for _, other in ipairs(ns.DB.PANEL_ORDER) do cand[#cand + 1] = other end
    local dormant = ns.Bars and ns.Bars.Dormant
    for _, other in ipairs(cand) do
        -- 跟著游標的條、接力中的天空騎術不能被錨定（Core/Bars.lua 把它們當不存在）。
        -- 獨立擺放的資源列（"res:<key>"）不在候選裡（不當別人的目標）；它自己的候選＝資源條的候選＋資源條本身
        if other ~= key and ns.DB.ConfigTable(other) and not ns.DB.AnchorWouldCycle(key, other)
            and not (ns.Cursor and ns.Cursor.Configured(other))
            and not (dormant and dormant(other)) then
            items[#items + 1] = { text = ns.Options.PageTitle(other) or ns.Options.BarTitle(other), value = other }
        end
    end
    -- 外部目標（Core/Anchor.lua）：分隔線＋六個單位框（A.UNITS）＋指定框架名稱。分隔線選了不寫入（set 擋掉）。
    -- 分隔線用 ASCII 減號：歐語字型不一定有全形橫線
    local A = ns.Anchor
    if A then
        items[#items + 1] = { text = "|cff555555" .. string.rep("-", 24) .. "|r", value = ANCHOR_SEP }
        for _, u in ipairs(A.UNITS) do
            local to = "unit:" .. u
            items[#items + 1] = { text = A.Label(to), value = to }
        end
        items[#items + 1] = { text = L["Frame by name"], value = "frame:" }
    end
    return items
end

-- 指定框架名稱的輸入列：輸入時即時驗證（找不到／是本插件自己的條／不是框架 ⇒ 紅字，不寫入），
-- 按 Enter 或離開輸入框時通過驗證才寫進 anchor.to ＝ "frame:<名字>"
local function FrameNameRow(key, disabled)
    local REASON = {
        missing  = L["No frame has this name right now."],
        own      = L["That's one of this addon's bars: pick it from the list above instead."],
        notframe = L["That name isn't a frame."],
    }
    local HINT = L["Type the frame's global name. /fstack shows the name of the frame under the mouse."]
    local FOUND = L["Found."]
    local function Cur()
        local a = ns.DB.GetPath(ns.DB.ConfigTable(key), "anchor")
        local kind, name = ns.Anchor.Parse(type(a) == "table" and a.to or nil)
        return kind == "frame" and name or ""
    end
    return { type = "custom", label = L["Frame name"], noReset = true, disabled = disabled, h = 26,
             build = function(parent, x, y, width, ctx)
        local eb = W.CreateEditBox(parent, math.min(width, 220), 20)
        eb:SetPoint("LEFT", parent, "TOPLEFT", x, y - 13)
        local fs = parent:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontSmall)
        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 30)
        fs:SetWidth(width)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        local tallest = 14
        for _, t in ipairs({ HINT, FOUND, REASON.missing, REASON.own, REASON.notframe }) do
            fs:SetText(t)
            tallest = math.max(tallest, fs:GetStringHeight() or 14)
        end
        local function Show(name)
            local ok, why = ns.Anchor.CheckName(name)
            if ok then
                fs:SetText(FOUND)
                fs:SetTextColor(0.65, 0.65, 0.65)
            elseif why == "empty" then
                fs:SetText(HINT)
                fs:SetTextColor(0.65, 0.65, 0.65)
            else
                fs:SetText(REASON[why] or REASON.missing)
                fs:SetTextColor(1, 0.3, 0.3)
            end
        end
        local function Commit(self)
            local name = (self:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if name == Cur() then return end
            if not ns.Anchor.CheckName(name) then Show(name) return end
            local b = ns.DB.ConfigTable(key)
            if not (b and type(b.anchor) == "table") then return end
            b.anchor.to = "frame:" .. name
            ns.Anchor.Invalidate()
            ctx.lastSpec = { level = "structure", refreshPage = true }
            ctx.apply()
        end
        eb:SetScript("OnTextChanged", function(self, user) if user then Show(self:GetText()) end end)
        eb:SetScript("OnEnterPressed", function(self) Commit(self); self:ClearFocus() end)
        eb:HookScript("OnEditFocusLost", Commit)
        return 30 + tallest + 8, function()
            local cur = Cur()
            eb:SetText(cur)
            eb:SetCursorPosition(0)
            Show(cur)
        end
    end }
end

-- 黃字（W.fontEmphasis）一句：外部目標解析不到時，放在錨定目標下拉底下
local function EmphasisNote(text)
    return { type = "custom", noReset = true, h = 22, build = function(parent, x, y, width)
        local fs = parent:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontEmphasis)
        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 4)
        fs:SetWidth(width)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        fs:SetText(text)
        return math.max(22, (fs:GetStringHeight() or 14) + 10)
    end }
end

-- 這條錨在外部目標上、但現在用的是自己的備用位置（解析不到，或 SetPoint 被擋）
local function ExternalUnresolved(key)
    local A = ns.Anchor
    if not A then return false end
    local bar = ns.DB.ConfigTable(key)
    if A.Unresolved(bar) then return true end
    return (ns.Bars and ns.Bars.AnchorFailed and ns.Bars.AnchorFailed(key)) and true or false
end

Specs.FrameNameRow, Specs.EmphasisNote, Specs.ExternalUnresolved = FrameNameRow, EmphasisNote, ExternalUnresolved

-- 錨點在「錨定」語境的名字：九宮格選的是「這條的哪一點貼在目標的哪一點」，用「上緣中點」「左上角」比單字「上」「左上」清楚
local ANCHOR_POINT_TEXT = {
    TOPLEFT     = L["top-left corner"],
    TOP         = L["top edge"],
    TOPRIGHT    = L["top-right corner"],
    LEFT        = L["left edge"],
    CENTER      = L["center"],
    RIGHT       = L["right edge"],
    BOTTOMLEFT  = L["bottom-left corner"],
    BOTTOM      = L["bottom edge"],
    BOTTOMRIGHT = L["bottom-right corner"],
}
Specs.ANCHOR_POINT_TEXT = ANCHOR_POINT_TEXT
-- 新錨定（第一次選目標）的預設，也是舊存檔沒寫 point／relPoint 時的讀法：這條的上緣貼目標的下緣
Specs.ANCHOR_DEFAULT_POINT, Specs.ANCHOR_DEFAULT_REL = "TOP", "BOTTOM"

-- 錨定目標的顯示名：條／面板走頁名，單位框／具名框走 Anchor.Label
function Specs.AnchorTargetLabel(to)
    if type(to) ~= "string" then return "" end
    local A = ns.Anchor
    if A and A.IsExternal(to) then return A.Label(to) end
    return ns.Options.PageTitle(to) or ns.Options.BarTitle(to) or to
end

-- 跟著游標（自訂圖示群組才有）開著時，錨定／位置那幾列停用（值不動，關掉就回來）。不能跟游標的條回 nil
function Specs.AnchorCursorGate(key)
    local bar = ns.DB.BarTable(key)
    if not (bar and bar.kind == "icons" and bar.source == "custom") then return nil end
    return function() return ns.Cursor and ns.Cursor.Configured(key) or false end
end

-- 「跟著哪條走」下拉：候選（AnchorItems）＋寫入規則**只有這一份**（錨定視窗用）。
--   「無」＝把畫面上的位置換算成 pos、放開錨定的當下不跳；第一次選外部目標記 fallback；
--   已經是某個具名框時再選一次「指定框架名稱」名字留著；分隔線不寫入。
-- root：讀寫哪一條（錨定視窗一律 "bar@<key>"）；disabled：Specs 的停用機制（跟著游標時）
function Specs.AnchorTargetSpec(key, root, disabled)
    return { type = "dropdown", root = root, path = "anchor", key = "anchor", label = L["Follow bar"],
             items = AnchorItems(key), refreshPage = true, level = "structure", disabled = disabled,
        get = function()
            local a = ns.DB.GetPath(ns.DB.ConfigTable(key), "anchor")
            local to = type(a) == "table" and a.to or "none"
            -- 具名框一律顯示成「指定框架名稱」，名字在下一列的輸入框
            if type(to) == "string" and to:sub(1, 6) == "frame:" then return "frame:" end
            return to
        end,
        set = function(_, v)
            if v == ANCHOR_SEP then return end
            local b = ns.DB.ConfigTable(key)
            if not b then return end
            if v == "none" then
                -- 換成目前畫面上的位置，放開錨定的當下不跳
                local pos = ns.EditMode and ns.EditMode.ReadPos and ns.EditMode.ReadPos(key)
                if pos then b.pos = pos end
                b.anchor = false
            else
                local old = type(b.anchor) == "table" and b.anchor or nil
                local a = old or { point = Specs.ANCHOR_DEFAULT_POINT, relPoint = Specs.ANCHOR_DEFAULT_REL, x = 0, y = -1 }
                local A = ns.Anchor
                if A and A.IsExternal(v) then
                    -- 第一次選外部目標：記下現在畫面上的位置，目標解析不到時退回這裡（Core/Anchor.lua 的 A.Fallback）
                    if not (old and A.IsExternal(old.to)) then
                        local pos = ns.EditMode and ns.EditMode.ReadPos and ns.EditMode.ReadPos(key)
                            or (type(b.pos) == "table" and b.pos) or nil
                        if pos then
                            a.fallback = { point = pos.point or "CENTER", x = tonumber(pos.x) or 0, y = tonumber(pos.y) or 0 }
                        end
                    end
                    -- 已經是某個具名框時再選一次「指定框架名稱」：名字留著
                    if v == "frame:" and old and type(old.to) == "string" and old.to:sub(1, 6) == "frame:" then v = old.to end
                else
                    a.fallback = nil
                end
                a.to = v
                b.anchor = a
            end
        end,
    }
end

-- 摘要一行：沒錨定「自己的位置」；有錨定「<目標>，<這條的點> → <目標的點>」，目標解析不到時後面接黃字「（找不到）」
local function AnchorSummary(key)
    local a = ns.DB.GetPath(ns.DB.ConfigTable(key), "anchor")
    if type(a) ~= "table" then return L["Own position"] end
    local mine = ANCHOR_POINT_TEXT[a.point or Specs.ANCHOR_DEFAULT_POINT] or tostring(a.point)
    local theirs = ANCHOR_POINT_TEXT[a.relPoint or Specs.ANCHOR_DEFAULT_REL] or tostring(a.relPoint)
    local text = L["%s, %s → %s"]:format(Specs.AnchorTargetLabel(a.to), mine, theirs)
    if ExternalUnresolved(key) then
        local c = W.EMPHASIS_COLOR
        text = text .. (" |cff%02x%02x%02x"):format(math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5)) .. L["(not found)"] .. "|r"
    end
    return text
end
Specs.AnchorSummary = AnchorSummary

-- 摘要列：左邊灰字摘要、緊接著一顆「設定」鈕（跟資源條頁每一列那顆同字同尺寸）開錨定視窗。
-- 跟著游標時整列蓋停用遮罩（Specs 的 disabled 機制）、按鈕 Disable；這條的錨定視窗開著就收掉
local SUMMARY_H = 26
local function AnchorSummaryRow(key, gate)
    local btn
    local spec = { type = "custom", label = L["Anchoring"], h = SUMMARY_H, noReset = true }
    if gate then
        -- 表單每次套用後都重判停用（BuildForm 的 gates）：按鈕狀態與視窗一起跟著
        spec.disabled = function(info)
            local off = gate(info) and true or false
            if btn then btn:SetEnabled(not off) end
            if off and ns.AnchorWindow and ns.AnchorWindow.Current() == key then ns.AnchorWindow.Close() end
            return off
        end
    end
    spec.build = function(parent, x, y, width)
        local fs = parent:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontSmall)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        fs:SetPoint("LEFT", parent, "TOPLEFT", x, y - SUMMARY_H / 2)
        local b = W.CreateButton(parent, L["Settings"], "normal", 70, 20)
        local bw = W.FitButton(b, 70, 20)
        b:SetPoint("LEFT", fs, "RIGHT", 10, 0)
        b:SetScript("OnClick", function() if ns.AnchorWindow then ns.AnchorWindow.Open(key) end end)
        btn = b
        -- 摘要太長（歐語＋長框名）就截在按鈕前面，按鈕永遠在控件欄裡
        local maxW = math.max(40, width - bw - 10)
        return SUMMARY_H, function()
            fs:SetText(AnchorSummary(key))
            local w = fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth() or 0
            fs:SetWidth(math.min(math.ceil(w) + 1, maxW))
            if gate then b:SetEnabled(not gate()) end
        end
    end
    return spec
end

-- opts（可省）：
--   other   true ＝ key 不是這張表單自己的條（資源條頁上的自訂格子）：讀寫走 root "bar@<key>"
--   header  小節標題（預設「錨定」）；nested ＝ 畫成小標題
-- 錨定視窗的讀寫一律 root "bar@<key>"，所以 other 只影響這裡「位置」那一列
function Specs.Anchor(key, opts)
    opts = opts or {}
    local bar = ns.DB.ConfigTable(key) or {}
    local anchored = type(bar.anchor) == "table"
    local root = opts.other and ("bar@" .. key) or "bar"
    -- 跟著游標開著（而且條件成立）時錨定／位置那幾列停用（值不動，關掉就回來）
    local gate = (not opts.other) and Specs.AnchorCursorGate(key) or nil
    local list = {
        -- 分頁：條頁的錨定跟版面同一頁（Specs.SplitTabs）；沒分頁的頁（施法條、資源條…）不看這欄
        { type = "header", label = opts.header or L["Anchoring"], nested = opts.nested or nil,
          tab = not opts.nested and "layout" or nil },
    }
    -- 自訂的圖示群組：跟著游標（勾選＋原因字）、離游標的位移
    if gate then
        list[#list + 1] = CursorRow(key)
        list[#list + 1] = BS("numbers", nil, L["Offset from the pointer"], { sub = "cursor", path = false,
            resetPaths = { "cursor.x", "cursor.y" }, fallback = 0,
            disabled = function() return not gate() end,
            fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } })
    end
    -- 跟著誰、哪一點貼哪一點、偏移：都在錨定視窗（Options/AnchorWindow.lua），這裡只留摘要＋開窗鈕
    list[#list + 1] = AnchorSummaryRow(key, gate)
    if not anchored then
        -- 自己的位置：pos 的偏移（相對畫面上 pos.point 那一點；拖曳／方向鍵改的就是它）
        list[#list + 1] = BS("numbers", nil, L["Position"], { root = root, sub = "pos", path = false, level = "structure",
            resetPaths = { "pos" }, disabled = gate,
            fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } })
    end
    list[#list + 1] = Note(L["Hover a bar and press the arrow keys to nudge it by 1 (Shift: 10)."])
    list[#list + 1] = Note(L["A bar that follows another moves with it. Dragging it in Edit Mode stops the following."])
    list[#list + 1] = Note(L["Elements that follow the same side of the same bar stack outward instead of overlapping."])
    list[#list + 1] = Note(L["It can also follow the player, target, focus, pet or target-of-target frame of whichever unit frames are loaded, or any frame by name. A frame hidden for lack of a unit still holds the position."])
    -- 天空騎術接力的對象：這個位置在天空騎術時由那個面板接手（只放灰字，不放按鈕；切換在天空騎術頁）
    if not opts.other and ns.Bars and ns.Bars.SkyRelayTo and ns.Bars.SkyRelayTo() == key then
        list[#list + 1] = Note(L["While skyriding, the skyriding bars take over this spot (Skyriding page, Position: Relay)."])
    end
    return list
end

-- 整張錨定圖（誰錨在誰身上）：錨定下拉的候選要排除成環的，候選清單是建表單當下算的，
-- 別條的錨定一變，這條的候選就過期了 ⇒ 圖本身進表單的形狀簽章
function Specs.AnchorGraphSig()
    local p = ns.profile
    local parts = {}
    local keys = {}
    for k in pairs(p and p.bars or {}) do keys[#keys + 1] = k end
    for _, k in ipairs(ns.DB.PANEL_ORDER) do keys[#keys + 1] = k end
    table.sort(keys)
    -- 天空騎術接力／獨立擺放一切換，它在不在錨定候選裡就跟著變
    local relayTo = ns.Bars and ns.Bars.SkyRelayTo and ns.Bars.SkyRelayTo()
    if relayTo then parts[#parts + 1] = "sky:relay:" .. relayTo end
    -- 閒置的面板不是錨定候選（觸發牌堆的列換專精就會進出閒置）
    local dormant = ns.Bars and ns.Bars.Dormant
    if dormant then
        for _, k in ipairs(ns.DB.PANEL_ORDER) do
            if dormant(k) then parts[#parts + 1] = k .. "z" end
        end
    end
    for _, k in ipairs(keys) do
        local t = ns.DB.ConfigTable(k)
        local a = t and t.anchor
        if type(a) == "table" and type(a.to) == "string" then
            parts[#parts + 1] = k .. ">" .. a.to
            -- 外部目標解析不到：表單多一列黃字
            if ExternalUnresolved(k) then parts[#parts + 1] = k .. "!" end
        end
        -- 跟著游標的條不是錨定候選：開關一變，別條的候選清單就過期
        if ns.Cursor and ns.Cursor.Configured(k) then parts[#parts + 1] = k .. "~" end
    end
    return table.concat(parts, ",")
end

-- 表單的「形狀」：有列會出現或消失的設定。形狀一樣就重用建好的表單（frame 刪不掉）
function Specs.BarSignature(key)
    local bar = ns.DB.BarTable(key) or {}
    local layout = type(bar.layout) == "table" and bar.layout or {}
    local p = ns.profile
    return table.concat({
        tostring(bar.kind), tostring(bar.source),
        -- 顯示樣式（圖示／圓環）：兩種的版面列完全不同
        ns.DB.BarIsRings(key) and "rings" or "-",
        type(layout.row2Size) == "table" and "r2" or "-",
        type(bar.anchor) == "table" and "a" or "-",
        table.concat(p and p.barOrder or {}, ","),
        Specs.AnchorGraphSig(),
        Specs.OverflowSig(key),
        -- 「增益不在時」那一列的黃字提示出不出現（列高跟著變，EmptyModeRow）
        "eh:" .. tostring(Specs.EmptyModeHint(key) or "-"),
    }, "|")
end

------------------------------------------------------------
-- 表單：Controls.Build ＋ 跟隨遮罩 ＋ 右鍵重設
------------------------------------------------------------
local RESETTABLE = { toggle = true, slider = true, number = true, numbers = true, color = true, dropdown = true }

local function ResetSpec(ctx, spec)
    local info = ctx.info
    local paths = spec.resetPaths or { PathOf(spec) }
    local p = ns.profile
    if not p then return end
    for _, path in ipairs(paths) do
        if spec.root == "theme" then
            if info.mode == "theme" then
                ns.DB.SetPath(p.theme, path, ns.DB.DefaultFor("theme", nil, path))
            else
                ns.DB.OwnSet(info.key, path, nil)
            end
        else
            local target = TargetOf(spec) or info.key
            local v = ns.DB.DefaultFor("bar", target, path)
            -- fallbacks：每個 path 各自的退路（錨點九宮格一次重設 point／relPoint 兩個不同的值）
            if v == nil and spec.fallbacks then v = spec.fallbacks[path] end
            if v == nil then v = spec.fallback end
            ns.DB.SetPath(ns.DB.ConfigTable(target), path, v)
        end
    end
    ctx.lastSpec = spec
    ctx.apply()
    if ctx.form then ctx.form:Refresh() end
end

local function ResetCatcher(content, row, ctx, x0)
    local spec = row.spec
    local f = CreateFrame("Frame", nil, content)
    f:SetPoint("TOPLEFT", content, "TOPLEFT", x0, row.top)
    f:SetSize(LABEL_W, math.max(1, row.top - row.bottom))
    f:SetFrameLevel(content:GetFrameLevel() + 5)
    f:EnableMouse(true)
    f:SetScript("OnMouseUp", function(self, button)
        if button ~= "RightButton" then return end
        if W.Menu.IsOpenFor(self) then W.Menu.Hide() return end
        W.Menu.Show({
            { text = spec.label or "", isTitle = true },
            { text = L["Reset to default"], onClick = function() ResetSpec(ctx, spec) end },
        }, self)
    end)
    return f
end

function Specs.BuildForm(parent, controls, ctx, width)
    local content = CreateFrame("Frame", nil, parent)
    content:SetPoint("TOPLEFT")
    content:SetSize(width, 1)
    local x0 = 4
    local height, refreshers, rows = ns.Controls.Build(content, controls, ctx, x0, -4, width)
    local form = { content = content, height = height + 20, refreshers = refreshers, rows = rows, masks = {}, ctx = ctx }
    content:SetHeight(form.height)
    ctx.form = form

    -- 子分頁的卡片（L）：底緣＝最後一個帶 subTab 的列（底下接的是小節標題，上方本來就留了 HEADER_GAP，內距吃得下）
    if ctx.tabCard then
        local last
        for _, row in ipairs(rows) do
            if row.spec.subTab then last = row end
        end
        if last then ctx.tabCard:SetBottom(last.bottom - W.TAB_CARD_PAD) else ctx.tabCard:SetBottom(nil) end
    end
    for group, c in pairs(ctx.tabCards or {}) do
        local last
        for _, row in ipairs(rows) do
            if row.spec.subTab and (row.spec.subGroup or "cd") == group then last = row end
        end
        if last then c.card:SetBottom(last.bottom - W.TAB_CARD_PAD) else c.card:SetBottom(nil) end
        c.lastRow = last
    end

    -- 跟隨遮罩的範圍：一個 section 一個矩形（這張表單裡它的第一列到最後一列，中間夾的子分頁鈕、卡片、
    -- 別節的列都蓋進去）。子分頁鈕與卡片框也要一起暗（使用者 2026-10-06：只蓋列、鈕和框線亮著＝「遮罩全錯」）。
    -- 代價：文字跟隨時，夾在裡面那一列歸「圖示」管的（增益持續時間的變色顏色，J）也被蓋住、子分頁切不過去。
    -- 整段都在同一張卡片裡（例如只有那一列的「圖示」）⇒ 左右收在卡片框線內
    local runs, bySec = {}, {}
    for _, row in ipairs(rows) do
        local sec = row.spec.section
        if sec then
            local cx = CardX(ctx, row.spec)
            -- 卡片的最後一列：卡片底緣比列底多一段內距，遮罩要蓋到框線
            local bottom = row.bottom
            local card = row.spec.subTab and ctx.tabCards and ctx.tabCards[row.spec.subGroup or "cd"]
            if card and card.lastRow == row then bottom = bottom - W.TAB_CARD_PAD - 1 end
            local r = bySec[sec]
            if r then
                r.bottom = bottom
                if r.cx ~= cx then r.cx = nil end
            else
                r = { sec = sec, top = row.top, bottom = bottom, cx = cx }
                bySec[sec] = r
                runs[#runs + 1] = r
            end
        end
    end
    if ctx.info.mode == "bar" then
        for _, r in ipairs(runs) do
            local m = CreateFrame("Frame", nil, content, "BackdropTemplate")
            local mx, mw = 0, width
            if r.cx then mx, mw = r.cx.left + 1, r.cx.right - r.cx.left - 2 end
            m:SetPoint("TOPLEFT", content, "TOPLEFT", mx, r.top)
            m:SetSize(mw, math.max(1, r.top - r.bottom))
            m:SetFrameLevel(content:GetFrameLevel() + 40)
            m:EnableMouse(true)              -- 擋點擊；滾輪不擋（沒開 MouseWheel，照樣捲得動）
            m:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8" })
            m:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
            m:Hide()
            m.sec = r.sec
            form.masks[#form.masks + 1] = m
        end
    end
    for _, row in ipairs(rows) do
        if (RESETTABLE[row.spec.type] or row.spec.resettable) and not row.spec.noReset then ResetCatcher(content, row, ctx, x0) end
        -- 示意「!」（spec.demo）：勾選框（18px）右邊，跟它垂直置中。層級在兩種遮罩之下：整節跟隨／停用時一起暗、滑不到
        if row.spec.demo then
            -- 控件多寬就排在它右邊：勾選框 18、下拉照共用層的標準寬（卡片裡收窄成 maxW）
            local ctrlW = row.spec.type == "toggle" and 18 or math.min(CARD_CTRL_W, row.spec.maxW or CARD_CTRL_W)
            local m = Specs.DemoMark(content, row.spec.demo, row.spec.label)
            m:SetPoint("LEFT", content, "TOPLEFT", x0 + LABEL_W + CARD_GAP + ctrlW + 12, (row.top + row.bottom) / 2)
        end
    end

    -- 停用的列：暗色遮罩蓋整列（層級在右鍵重設的接收框之上、跟隨遮罩之下）
    local gates, watchReload = {}, false
    for _, row in ipairs(rows) do
        local spec = row.spec
        if spec.reloadCheck then watchReload = true end
        if spec.disabled then
            local m = CreateFrame("Frame", nil, content, "BackdropTemplate")
            -- 子分頁卡片裡的列：遮罩左右收在卡片框線內（不然整個表單寬，會凸出卡片兩側）
            local mx, mw = 0, width
            local cx = CardX(ctx, spec)
            if cx then mx, mw = cx.left + 1, cx.right - cx.left - 2 end
            m:SetPoint("TOPLEFT", content, "TOPLEFT", mx, row.top)
            m:SetSize(mw, math.max(1, row.top - row.bottom))
            m:SetFrameLevel(content:GetFrameLevel() + 30)
            m:EnableMouse(true)
            m:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8" })
            m:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
            m:Hide()
            -- 整節已經被跟隨遮罩蓋住（條頁）就不再疊一層
            gates[#gates + 1] = function()
                local covered = false
                if ctx.info.mode == "bar" and spec.section then
                    local bar = ns.DB.BarTable(ctx.info.key)
                    local follow = bar and type(bar.follow) == "table" and bar.follow or {}
                    covered = follow[spec.section] ~= false
                end
                m:SetShown((not covered and spec.disabled(ctx.info)) and true or false)
            end
        end
    end
    form.gates = gates
    -- 表單引擎在值變了之後只叫 ctx.apply（不叫 refreshers）⇒ 包一層：停用狀態重判、圖示外觀問重載
    if #gates > 0 or watchReload then
        local apply = ctx.apply
        ctx.apply = function(...)
            apply(...)
            for _, g in ipairs(gates) do g() end
            local last = ctx.lastSpec
            if last and last.reloadCheck then Specs.CheckSkinReload() end
        end
    end

    function form:Refresh()
        for _, fn in ipairs(self.refreshers) do fn() end
        for _, g in ipairs(self.gates) do g() end
        if ctx.info.mode == "bar" then
            local bar = ns.DB.BarTable(ctx.info.key)
            local follow = bar and type(bar.follow) == "table" and bar.follow or {}
            for _, m in ipairs(self.masks) do m:SetShown(follow[m.sec] ~= false) end
        end
    end
    return form
end

------------------------------------------------------------
-- 分頁（主題頁／條頁，J）
--
-- 表單引擎不動：頂層 header 帶一個 tab 欄位（"layout"…），Specs.SplitTabs 把一串 spec 照它切成幾份，
-- 每一份各自 BuildForm 成一張表單，頁面只顯示目前那一張（每張表單一個 ctx：BuildForm 會把 ctx.form
-- 指向自己、包 ctx.apply）。沒帶 tab 的 header（小標題、沒分頁的頁）跟著上一個分頁走；
-- 第一個 header 之前的列歸第一個分頁。分頁鈕跟單一法術小窗同一款（accent-hover ＋ W.CreateButtonGroup），
-- 放不下就換行（W.FlowLayout）。
------------------------------------------------------------
local TAB_DEFS = {
    { id = "layout",     label = L["Layout"] },        -- 版面＋錨定＋淡出
    { id = "visibility", label = L["Visibility"] },
    { id = "icon",       label = L["Icons"] },
    { id = "text",       label = L["Text"] },
    { id = "glow",       label = L["Effects"] },
    { id = "sound",      label = L["Sounds"] },
}
Specs.TAB_DEFS = TAB_DEFS

-- → byTab（id → spec 清單）, ids（有東西的分頁，照 TAB_DEFS 的順序）
function Specs.SplitTabs(controls)
    local byTab, cur = {}, nil
    for _, spec in ipairs(controls) do
        if spec.type == "header" and spec.tab then cur = spec.tab end
        local id = cur or TAB_DEFS[1].id
        local t = byTab[id]
        if not t then t = {}; byTab[id] = t end
        t[#t + 1] = spec
    end
    local ids = {}
    for _, d in ipairs(TAB_DEFS) do
        if byTab[d.id] then ids[#ids + 1] = d.id end
    end
    return byTab, ids
end

-- 分頁鈕列：strip:SetTabs(ids, cur) 只顯示 ids 裡的鈕、高亮 cur、換行排好，回傳高度（也設成 strip 的高）。
-- 點鈕叫 onSelect(id)
local TAB_BTN_H, TAB_BTN_MIN_W = 20, 56
function Specs.CreateTabStrip(parent, width, onSelect)
    local strip = CreateFrame("Frame", nil, parent)
    strip:SetSize(width, TAB_BTN_H)
    local btns, byId = {}, {}
    for i, d in ipairs(TAB_DEFS) do
        local b = W.CreateButton(strip, d.label, "accent-hover", TAB_BTN_MIN_W, TAB_BTN_H)
        W.FitButton(b, TAB_BTN_MIN_W, TAB_BTN_H)
        b.id = d.id
        btns[i], byId[d.id] = b, b
    end
    local highlight = W.CreateButtonGroup(btns, function(id) onSelect(id) end)
    function strip:SetTabs(ids, cur)
        local has = {}
        for _, id in ipairs(ids) do has[id] = true end
        local list = {}
        for _, b in ipairs(btns) do
            b:SetShown(has[b.id] == true)
            if has[b.id] then list[#list + 1] = b end
        end
        if byId[cur] then highlight(byId[cur]) end
        local _, h = W.FlowLayout(strip, list, width, 4, 4, TAB_BTN_H)
        strip:SetHeight(h)
        return h
    end
    return strip
end
