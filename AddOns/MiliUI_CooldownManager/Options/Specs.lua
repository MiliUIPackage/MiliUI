------------------------------------------------------------
-- 設定表單的規格與接線（條頁與主題頁共用）
--
--   Specs.Themed(mode, key)       圖示／文字／效果／音效四節（mode = "bar" | "theme"；key ＝ 哪一條，長條沒有按鍵文字那一節）
--   Specs.Layout(key)             版面（條頁）
--   Specs.Visibility()            顯示條件（條頁）
--   Specs.Anchor(key)             錨定（條頁）
--   Specs.MakeCtx(info, onApply)  info = { mode, key }；onApply(spec) 在值寫進去之後叫
--   Specs.BuildForm(parent, controls, ctx, width) → form（content／height／Refresh）
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
--   disabled function(info) → 真 ＝ 這一列停用：蓋一層暗色遮罩（擋點擊與右鍵重設，值不動）。
--            表單引擎（共用層）沒有停用狀態，遮罩是 BuildForm 自己畫的；每次套用後重判
--   reloadCheck  寫完（含右鍵重設）檢查圖示外觀要不要重載（Specs.CheckSkinReload）
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
local FixedSlotsRow      -- 版面那一節的固定格位列（定義在下面）
local GlowSampleRow      -- 發光的預覽圖示（定義在下面）

------------------------------------------------------------
-- 下拉清單
------------------------------------------------------------
local function GrowItems(kind)
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

local GLOW_ITEMS = {
    { text = L["Pixel"],          value = "pixel" },
    { text = L["Autocast"],       value = "autocast" },
    { text = L["Action button"],  value = "button" },
    { text = L["Proc"],           value = "proc" },
}

local SIDE_ITEMS = {
    { text = L["Left"],  value = "LEFT" },
    { text = L["Right"], value = "RIGHT" },
    { text = L["None"],  value = "NONE" },
}

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
}

-- 錨定的「邊」：本條貼在目標的哪一邊
local EDGE_ITEMS = {
    { text = L["Below it"],       value = "BELOW" },
    { text = L["Above it"],       value = "ABOVE" },
    { text = L["To its left"],    value = "LEFTOF" },
    { text = L["To its right"],   value = "RIGHTOF" },
}
local EDGE_POINTS = {
    BELOW   = { "TOP", "BOTTOM" },
    ABOVE   = { "BOTTOM", "TOP" },
    LEFTOF  = { "RIGHT", "LEFT" },
    RIGHTOF = { "LEFT", "RIGHT" },
}

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

local function Note(label, section)
    return { type = "text", label = label, section = section }
end

local function Nested(label, section)
    return { type = "header", label = label, nested = true, section = section }
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
function Specs.Themed(mode, key)
    local bar = mode == "bar"
    local list = {}
    local function add(...)
        for i = 1, select("#", ...) do
            local s = select(i, ...)
            if s then list[#list + 1] = s end
        end
    end

    -- 圖示
    add({ type = "header", label = L["Icons"] })
    if bar then add(OverrideRow("icon"), FollowToggle("icon"),
        Note(L["While checked, this section uses the Theme page. Uncheck it to give this bar its own values."])) end
    add(SkinRows())
    add(TS("icon", "dropdown", "border.texture", L["Border texture"], { items = BorderItems, disabled = MasqueOwns }),
        TS("icon", "slider", "border.size", L["Border size"], { min = 0, max = 4, step = 1, disabled = MasqueOwns }),
        TS("icon", "color", "border.color", L["Border color"], { disabled = MasqueOwns }),
        TS("icon", "slider", "icon.zoom", L["Icon zoom"], { min = 0, max = 0.2, step = 0.01, disabled = MasqueOwns }),
        Note(L["Crops the icon edges; 0 shows the whole texture."], "icon"),
        TS("icon", "color", "icon.swipeColor", L["Cooldown swipe color"], { hasAlpha = true }),
        TS("icon", "toggle", "icon.hideGCDSwipe", L["Hide GCD swipe"]),
        TS("icon", "toggle", "icon.desaturateOnCooldown", L["Desaturate on cooldown"]),
        TS("icon", "toggle", "icon.tooltips", L["Show tooltip on hover"]),
        Note(L["Off also hides Blizzard's own tooltip for these icons. Clicks still pass through."], "icon"))

    -- 文字
    add({ type = "header", label = L["Text"] })
    if bar then add(OverrideRow("text"), FollowToggle("text")) end
    -- 通用字型：每段文字的字型沒另外挑時用這個（條頁沒跟隨主題時也能改）
    add(TS("text", "dropdown", "font", L["General font"], { items = FontItems }),
        TS("text", "dropdown", "outline", L["Outline"], { items = OUTLINE_ITEMS }))
    add(Nested(L["Countdown"], "text"),
        FontTS("text", "cooldownText.font"),
        TS("text", "slider", "cooldownText.size", L["Font size"], { min = 6, max = 40, step = 1 }),
        TS("text", "color", "cooldownText.color", L["Color"]),
        TS("text", "slider", "cooldownText.decimalsBelow", L["Decimals below"], { min = 0, max = 10, step = 1 }),
        Note(L["Shows one decimal place under this many seconds; 0 never shows decimals."], "text"),
        TS("text", "toggle", "cooldownText.lowBelow", L["Color when low"], {
            get = function(info) return (tonumber(ReadThemed(info, "cooldownText.lowBelow")) or 0) > 0 end,
            set = function(info, on) WriteThemed(info, "cooldownText.lowBelow", on and 5 or 0) end,
        }),
        TS("text", "color", "cooldownText.lowColor", L["Low color"]),
        TS("text", "slider", "cooldownText.lowBelow", L["Low below (sec)"], { min = 0, max = 30, step = 1 }),
        Nested(L["Charges"], "text"),
        FontTS("text", "chargeText.font"),
        TS("text", "slider", "chargeText.size", L["Font size"], { min = 6, max = 30, step = 1 }),
        TS("text", "color", "chargeText.color", L["Color"]),
        TS("text", "dropdown", "chargeText.point", L["Anchor"], { items = POINT_ITEMS }),
        TS("text", "numbers", nil, L["Offset"], { sub = "chargeText", path = false,
            resetPaths = { "chargeText.x", "chargeText.y" },
            fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } }),
        Nested(L["Stacks"], "text"),
        FontTS("text", "stackText.font"),
        TS("text", "slider", "stackText.size", L["Font size"], { min = 6, max = 30, step = 1 }),
        TS("text", "color", "stackText.color", L["Color"]),
        TS("text", "dropdown", "stackText.point", L["Anchor"], { items = POINT_ITEMS }),
        TS("text", "numbers", nil, L["Offset"], { sub = "stackText", path = false,
            resetPaths = { "stackText.x", "stackText.y" },
            fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } }))

    -- 效果（發光、無損刷新、按鍵文字）＋淡出
    add({ type = "header", label = L["Effects"] })
    if bar then add(OverrideRow("glow"), FollowToggle("glow")) end
    add(Nested(L["Proc glow"], "glow"),
        TS("glow", "toggle", "glow.proc.enabled", L["Enable"]),
        Note(L["Replaces Blizzard's proc glow. When off, Blizzard's own glow shows."], "glow"),
        TS("glow", "dropdown", "glow.proc.type", L["Style"], { items = GLOW_ITEMS }),
        TS("glow", "color", "glow.proc.color", L["Color"]),
        GlowSampleRow("proc"),
        Nested(L["Ready glow"], "glow"),
        TS("glow", "toggle", "glow.ready.enabled", L["Enable"]),
        Note(L["Glows for a moment when a cooldown finishes. The global cooldown doesn't count."], "glow"),
        TS("glow", "dropdown", "glow.ready.type", L["Style"], { items = GLOW_ITEMS }),
        TS("glow", "color", "glow.ready.color", L["Color"]),
        GlowSampleRow("ready"),
        TS("glow", "slider", "glow.ready.duration", L["Duration (sec)"], { min = 1, max = 10, step = 1 }))
    -- 生效發光（增益）沒有統一設定：逐法術在預覽點圖示開、顏色也在那裡挑（使用者 2026-10-02 拿掉這一節）；
    -- 樣式固定用 glow.active 的預設（Core/DB.lua）
    add(Nested(L["Pandemic"], "glow"),
        TS("glow", "toggle", "pandemic.enabled", L["Color the border"]),
        Note(L["While a buff or debuff can be refreshed without losing time, its border turns this color."], "glow"),
        TS("glow", "color", "pandemic.color", L["Pandemic border color"]),
        TS("glow", "toggle", "pandemic.bars", L["Color bars too"]))
    -- 按鍵文字：長條與增益圖示列沒有這一節，引擎也不畫（Core/Keybinds.lua 的 NoKeybind）
    if not (bar and key and ns.Keybinds.NoKeybind(key)) then
        add(Nested(L["Keybind text"], "glow"),
            TS("glow", "toggle", "keybind.enabled", L["Show keybind text"]),
            FontTS("glow", "keybind.font"),
            TS("glow", "slider", "keybind.size", L["Font size"], { min = 6, max = 24, step = 1 }),
            TS("glow", "dropdown", "keybind.point", L["Anchor"], { items = POINT_ITEMS }),
            TS("glow", "numbers", nil, L["Offset"], { sub = "keybind", path = false,
                resetPaths = { "keybind.x", "keybind.y" },
                fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } }))
    end
    add(Nested(L["Fade"]))
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

    -- 音效：響什麼是逐法術設定（預覽裡點圖示）；主題頁放總開關與聲道，條頁只有覆寫數＋清除。
    -- 不掛 section：音效不走「跟隨全域主題」，條頁不蓋遮罩
    add({ type = "header", label = L["Sounds"] })
    if bar then
        add(OverrideRow("sound"),
            Note(L["Sounds are set per spell: click an icon in the preview above. The on/off switch and channel are on the Theme page."]))
    else
        add(TS(nil, "toggle", "sound.enabled", L["Enable"]),
            TS(nil, "dropdown", "sound.channel", L["Channel"], { items = CHANNEL_ITEMS }),
            Note(L["Which sound plays is set per spell: click an icon in a bar's preview. Nothing plays for 2 seconds after a loading screen, and the same spell doesn't repeat within 1.5 seconds."]))
    end
    return list
end

------------------------------------------------------------
-- 固定格位：條上有光環格、或這條可點擊時強制打開（勾選框停用、說明換成原因；存的值不動）
--
-- 表單引擎的 toggle 沒有「停用」這個狀態，所以自己畫一列（custom）：勾選框＋下一列灰字，
-- 灰字依狀態換三種說法（一般／有光環格／可點擊），高度取三種裡最高的那個（列高在建表單時就定了）。
------------------------------------------------------------
function FixedSlotsRow(key)
    local NORMAL = L["Buffs that aren't up keep their place as a dimmed icon, so the others don't shift."]
    local FORCED = L["Always on while this bar has aura slots: they need fixed positions, because they can't move during combat."]
    local FORCED_CLICK = L["Always on while this bar is clickable: the click targets can't move during combat."]
    -- 強制的原因：有光環格優先（兩者都成立時講光環格那句）；nil ＝ 沒有強制
    local function ForcedText()
        if ns.Catalog.BarHasAuraSlot(key) then return FORCED end
        if ns.DB.BarClickable(key) then return FORCED_CLICK end
        return nil
    end
    return { type = "custom", label = L["Keep empty slots for missing buffs"], h = 26, root = "bar",
             path = "layout.fixedSlots", key = "layout.fixedSlots",
             build = function(parent, x, y, width, ctx)
        local cb = W.CreateCheckButton(parent, nil, function(on)
            local b = ns.DB.BarTable(key)
            if not b or ForcedText() then return end
            b.layout.fixedSlots = on and true or false
            ctx.lastSpec = { level = "layout" }
            ctx.apply()
        end)
        cb:SetPoint("LEFT", parent, "TOPLEFT", x, y - 13)
        local fs = parent:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontSmall)
        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 30)
        fs:SetWidth(width)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        fs:SetText(FORCED)
        local h1 = fs:GetStringHeight() or 14
        fs:SetText(FORCED_CLICK)
        local h3 = fs:GetStringHeight() or 14
        fs:SetText(NORMAL)
        local h2 = fs:GetStringHeight() or 14
        local h = 30 + math.max(14, h1, h2, h3) + 8
        local function Refresh()
            local reason = ForcedText()
            local forced = reason ~= nil
            local b = ns.DB.BarTable(key)
            local v = b and type(b.layout) == "table" and b.layout.fixedSlots
            cb:SetChecked((forced or v) and true or false)
            cb:SetEnabled(not forced)
            cb:SetAlpha(forced and 0.5 or 1)
            fs:SetText(reason or NORMAL)
            fs:SetTextColor(forced and 1 or 0.65, forced and 0.82 or 0.65, forced and 0 or 0.65)
        end
        return h, Refresh
    end }
end

------------------------------------------------------------
-- 發光預覽：一顆樣本圖示一直亮著目前的樣式與顏色，切樣式當場看得到效果。
-- 引擎跟格子共用（ns.Glow.PaintOn／StopOn）；就緒發光在格子上只亮幾秒，樣本則常亮。
-- 表單引擎在值變了之後只叫 ctx.apply、不叫 refreshers ⇒ 包一層 ctx.apply 讓樣本跟著換。
------------------------------------------------------------
local SAMPLE_ICON = "Interface\\Icons\\Spell_Holy_HolyBolt"
local SAMPLE_SIZE = 36

function GlowSampleRow(which)
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
            local c = ReadThemed(ctx.info, "glow." .. which)
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

------------------------------------------------------------
-- 版面（條自己的欄位）
------------------------------------------------------------
function Specs.Layout(key)
    local bar = ns.DB.BarTable(key) or {}
    local kind = bar.kind == "bars" and "bars" or "icons"
    local list = { { type = "header", label = L["Layout"] } }
    local function add(s) list[#list + 1] = s end

    if kind == "icons" then
        add(BS("slider", "layout.maxPerRow", L["Icons per row"], { min = 1, max = 20, step = 1 }))
    end
    add(BS("slider", "layout.spacing", L["Spacing"], { min = 0, max = 20, step = 1 }))
    add(BS("dropdown", "layout.grow", L["Growth"], { items = GrowItems(kind) }))
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
            -- 可點擊：勾了之後固定格位被強制打開（下一列的原因字），所以排在它前面
            add(BS("toggle", "clickable", L["Clickable"], { level = "layout", refreshPage = true }))
            add(Note(L["Icons cast their spell or use their item when clicked, like action bar buttons. Aura slots are not affected."]))
        end
        if bar.source == "buffs" or bar.source == "custom" then
            add(FixedSlotsRow(key))
        end
    else
        add(BS("slider", "bar.width", L["Width"], { min = 0, max = 600, step = 1 }))
        add(Note(L["0 matches the first row of Essential Cooldowns."]))
        add(BS("slider", "bar.height", L["Height"], { min = 6, max = 60, step = 1 }))
        add(BS("dropdown", "bar.iconSide", L["Icon position"], { items = SIDE_ITEMS }))
        add(BS("slider", "bar.iconGap", L["Icon gap"], { min = 0, max = 10, step = 1 }))
        add(BS("dropdown", "bar.texture", L["Texture"], { items = TextureItems }))
        add(BS("color", "bar.color", L["Bar color"]))
        add(BS("color", "bar.bgColor", L["Background color"]))
        -- 長條上的名字／時間：字型與字級（層數跟著「文字」那一節的層數）
        add(Nested(L["Bar text"]))
        add(FontBS("bar.nameFont", L["Name font"]))
        add(BS("slider", "bar.nameSize", L["Name size"], { min = 6, max = 30, step = 1 }))
        add(FontBS("bar.timeFont", L["Time font"]))
        add(BS("slider", "bar.timeSize", L["Time size"], { min = 6, max = 30, step = 1 }))
    end
    return list
end

------------------------------------------------------------
-- 顯示條件
------------------------------------------------------------
function Specs.Visibility()
    return {
        { type = "header", label = L["Visibility"] },
        Nested(L["Show when"]),
        BS("toggle", "visibility.showCombat", L["In combat"]),
        BS("toggle", "visibility.showTarget", L["Has a target"]),
        Note(L["Leave both unchecked to always show. Check either to show only while one of them is true."]),
        Nested(L["Restrictions"]),
        BS("toggle", "visibility.hideMounted", L["Hide while mounted"]),
        BS("toggle", "visibility.onlyInstances", L["Only in instances"]),
        BS("dropdown", "visibility.group", L["Group"], { items = GROUP_ITEMS }),
        Note(L["Restrictions win over \"Show when\"."]),
    }
end

------------------------------------------------------------
-- 錨定
------------------------------------------------------------
-- 候選：左欄的條（barOrder）＋ 面板（資源條、自訂格子、施法條；它們不在 barOrder 裡）
local function AnchorItems(key)
    local items = { { text = L["None (own position)"], value = "none" } }
    local p = ns.profile
    local cand = {}
    for _, other in ipairs(p and p.barOrder or {}) do cand[#cand + 1] = other end
    for _, other in ipairs(ns.DB.PANEL_ORDER) do cand[#cand + 1] = other end
    for _, other in ipairs(cand) do
        if other ~= key and ns.DB.ConfigTable(other) and not ns.DB.AnchorWouldCycle(key, other) then
            items[#items + 1] = { text = ns.Options.PageTitle(other) or ns.Options.BarTitle(other), value = other }
        end
    end
    return items
end

local function EdgeOf(a)
    for id, pts in pairs(EDGE_POINTS) do
        if a.point == pts[1] and a.relPoint == pts[2] then return id end
    end
    return "BELOW"
end

-- opts（可省）：
--   other   true ＝ key 不是這張表單自己的條（資源條頁上的自訂格子）：讀寫走 root "bar@<key>"
--   header  小節標題（預設「錨定」）；nested ＝ 畫成小標題
function Specs.Anchor(key, opts)
    opts = opts or {}
    local bar = ns.DB.ConfigTable(key) or {}
    local anchored = type(bar.anchor) == "table"
    local root = opts.other and ("bar@" .. key) or "bar"
    local function AS(kind, path, label, extra)
        local s = BS(kind, path, label, extra)
        s.root = root
        return s
    end
    local list = {
        { type = "header", label = opts.header or L["Anchoring"], nested = opts.nested or nil },
        AS("dropdown", "anchor", L["Follow bar"], {
            items = AnchorItems(key), refreshPage = true, level = "structure",
            get = function()
                local a = ns.DB.GetPath(ns.DB.ConfigTable(key), "anchor")
                return type(a) == "table" and a.to or "none"
            end,
            set = function(_, v)
                local b = ns.DB.ConfigTable(key)
                if not b then return end
                if v == "none" then
                    -- 換成目前畫面上的位置，放開錨定的當下不跳
                    local pos = ns.EditMode and ns.EditMode.ReadPos and ns.EditMode.ReadPos(key)
                    if pos then b.pos = pos end
                    b.anchor = false
                else
                    local a = type(b.anchor) == "table" and b.anchor
                        or { point = "TOP", relPoint = "BOTTOM", x = 0, y = -1 }
                    a.to = v
                    b.anchor = a
                end
            end,
        }),
    }
    if anchored then
        list[#list + 1] = AS("dropdown", "anchor.point", L["Side"], {
            items = EDGE_ITEMS, level = "structure", resetPaths = { "anchor.point", "anchor.relPoint" },
            get = function()
                local a = ns.DB.GetPath(ns.DB.ConfigTable(key), "anchor")
                return type(a) == "table" and EdgeOf(a) or "BELOW"
            end,
            set = function(_, v)
                local a = ns.DB.GetPath(ns.DB.ConfigTable(key), "anchor")
                local pts = EDGE_POINTS[v]
                if type(a) == "table" and pts then a.point, a.relPoint = pts[1], pts[2] end
            end,
        })
        list[#list + 1] = AS("numbers", nil, L["Offset"], { sub = "anchor", path = false, level = "structure",
            resetPaths = { "anchor.x", "anchor.y" }, fallback = 0,
            fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } })
    end
    list[#list + 1] = Note(L["A bar that follows another moves with it. Dragging it in Edit Mode stops the following."])
    list[#list + 1] = Note(L["Elements that follow the same side of the same bar stack outward instead of overlapping."])
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
    for _, k in ipairs(keys) do
        local t = ns.DB.ConfigTable(k)
        local a = t and t.anchor
        if type(a) == "table" and type(a.to) == "string" then parts[#parts + 1] = k .. ">" .. a.to end
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
        type(layout.row2Size) == "table" and "r2" or "-",
        type(bar.anchor) == "table" and "a" or "-",
        table.concat(p and p.barOrder or {}, ","),
        Specs.AnchorGraphSig(),
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

    -- 每一節的上下緣（有 section 的列）
    local ranges = {}
    for _, row in ipairs(rows) do
        local sec = row.spec.section
        if sec then
            local r = ranges[sec]
            if not r then
                ranges[sec] = { top = row.top, bottom = row.bottom }
            else
                if row.top > r.top then r.top = row.top end
                if row.bottom < r.bottom then r.bottom = row.bottom end
            end
        end
    end
    if ctx.info.mode == "bar" then
        for sec, r in pairs(ranges) do
            local m = CreateFrame("Frame", nil, content, "BackdropTemplate")
            m:SetPoint("TOPLEFT", content, "TOPLEFT", 0, r.top)
            m:SetSize(width, math.max(1, r.top - r.bottom))
            m:SetFrameLevel(content:GetFrameLevel() + 40)
            m:EnableMouse(true)              -- 擋點擊；滾輪不擋（沒開 MouseWheel，照樣捲得動）
            m:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8" })
            m:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
            m:Hide()
            form.masks[sec] = m
        end
    end
    for _, row in ipairs(rows) do
        if RESETTABLE[row.spec.type] and not row.spec.noReset then ResetCatcher(content, row, ctx, x0) end
    end

    -- 停用的列：暗色遮罩蓋整列（層級在右鍵重設的接收框之上、跟隨遮罩之下）
    local gates, watchReload = {}, false
    for _, row in ipairs(rows) do
        local spec = row.spec
        if spec.reloadCheck then watchReload = true end
        if spec.disabled then
            local m = CreateFrame("Frame", nil, content, "BackdropTemplate")
            m:SetPoint("TOPLEFT", content, "TOPLEFT", 0, row.top)
            m:SetSize(width, math.max(1, row.top - row.bottom))
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
            for sec, m in pairs(self.masks) do m:SetShown(follow[sec] ~= false) end
        end
    end
    return form
end
