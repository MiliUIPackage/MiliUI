------------------------------------------------------------
-- 天空騎術每一列自己的設定視窗（天空騎術頁「顯示哪些」每一列的「設定」開的）
--
--   ns.SkyridingSettings.Open(key)   key ∈ speed | surge | vigor | secondWind（已經開著就換成這一列）
--   ns.SkyridingSettings.Close()
--   ns.SkyridingSettings.Refresh()   開著就重讀（天空騎術頁改了會影響這裡的值時叫）
--
-- 殼是共用的（Options/SettingsWindow.lua，同資源條每種資源的設定視窗）。讀寫 profile.skyriding.rows.<key>.*，小節：
--   版面   高（1～40）
--   外觀   材質（第一項「跟隨資源條的外觀」＝INHERIT）、背景材質（跟隨資源條／跟填充相同（FILL）／各材質）、背景色（含透明度）、
--          前景色：速度＝三色（一般速度／快意翱翔／貼地飛掠）；旋轉急衝、重新振作＝一色；
--          活力＝一色＋「改用速度條的顏色」＋重新振作的底色（灰字：重新振作那一列開著時不畫）
--   文字   顯示（＋灰字說明印什麼）、（活力才有）內容（活力／重新振作次數）、位置（左／中／右）、X／Y 位移、字型、字級、顏色
--   效果   （旋轉急衝才有）滿的時候的電光、充滿後震動
--   圖示   （旋轉急衝才有）顯示時機、圖示尺寸、位置＋灰字（rows.surge.icon；原本在天空騎術頁上，使用者 2026-10-06 指定搬進來）
-- 停用的列（文字關著時的文字設定、改用速度條顏色時的前景色……）用 Specs 的 disabled 遮罩，不換表單
-- ⇒ 表單形狀只看是哪一列。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

ns.SkyridingSettings = {}
local SS = ns.SkyridingSettings

local KEY = "skyriding"
local WIDTH = 460

local function Cfg() return ns.DB.ConfigTable(KEY) end
local function SR() return ns.Skyriding end
local function Spell(which) return SR().SpellName(which) end

local function BS(kind, path, label, extra)
    local s = { type = kind, root = "bar", path = path, key = path, label = label }
    if extra then for k, v in pairs(extra) do s[k] = v end end
    return s
end

local function Note(label) return { type = "text", label = label } end

-- 材質：第一項「跟隨資源條的外觀」（INHERIT，資源條頁的材質）
local function TextureItems()
    local items = ns.Specs.TextureItems()
    table.insert(items, 1, { text = L["Follow the resource bar's look"], value = ns.Media.INHERIT })
    return items
end

-- 背景材質：跟隨資源條（資源條頁的背景材質）、跟填充相同（這一列自己的材質）、各材質
local function BgTextureItems()
    local items = ns.Specs.TextureItems()
    table.insert(items, 1, { text = L["Same as fill"], value = "FILL" })
    table.insert(items, 1, { text = L["Follow the resource bar's look"], value = ns.Media.INHERIT })
    return items
end

local ANCHOR_ITEMS = {
    { text = L["Left"],   value = "LEFT" },
    { text = L["Center"], value = "CENTER" },
    { text = L["Right"],  value = "RIGHT" },
}

local ICON_ITEMS = {
    { text = L["Don't show"],  value = "off" },
    { text = L["On cooldown"], value = "cooldown" },
    { text = L["When ready"],  value = "ready" },
    { text = L["Always"],      value = "always" },
}

local SIDE_ITEMS = {
    { text = L["Left"],   value = "LEFT" },
    { text = L["Right"],  value = "RIGHT" },
    { text = L["Top"],    value = "TOP" },
    { text = L["Bottom"], value = "BOTTOM" },
}

local function Row(key) return SR().RowCfg(Cfg(), key) end

local function TextOff(key)
    return function()
        local t = Row(key).text
        return not (type(t) == "table" and t.show)
    end
end

local function AppendLayout(add, key, base)
    add({ type = "header", label = L["Layout"] })
    add(BS("slider", base .. "height", L["Height"], { min = 1, max = 40, step = 1 }))
end

local function AppendLook(add, key, base)
    add({ type = "header", label = L["Appearance"] })
    add(BS("dropdown", base .. "texture", L["Texture"], { items = TextureItems,
        get = function() return ns.Specs.InheritOr(Row(key).texture) end }))
    add(BS("dropdown", base .. "bgTexture", L["Background texture"], { items = BgTextureItems,
        get = function() return ns.Specs.InheritOr(Row(key).bgTexture) end }))
    add(BS("color", base .. "bgColor", L["Background color"], { hasAlpha = true }))
    if key == "speed" then
        add(BS("color", base .. "colors.low", L["Normal speed"], { hasAlpha = false }))
        add(BS("color", base .. "colors.thrill", Spell("thrill"), { hasAlpha = false }))
        add(BS("color", base .. "colors.skim", Spell("skim"), { hasAlpha = false }))
    elseif key == "vigor" then
        add(BS("color", base .. "color", L["Color"], { hasAlpha = false,
            disabled = function() return Row("vigor").speedColor == true end }))
        add(BS("toggle", base .. "speedColor", L["Charges use the speed bar's color"]))
        add(BS("color", base .. "secondWindColor", L["%s underlay color"]:format(Spell("secondWind")), { hasAlpha = false,
            disabled = function() return SR().RowOn(Cfg(), "secondWind") end }))
        add(Note(L["Not drawn while the %s row is on."]:format(Spell("secondWind"))))
    else
        add(BS("color", base .. "color", L["Color"], { hasAlpha = false }))
    end
end

local function AppendText(add, key, base)
    local tb = base .. "text."
    local off = TextOff(key)
    add({ type = "header", label = L["Text"] })
    add(BS("toggle", tb .. "show", L["Show"]))
    if key == "speed" then
        add(Note(L["Your speed as a percent of running speed."]))
    elseif key == "surge" then
        add(Note(L["Seconds left on the cooldown; nothing while it's ready."]))
    elseif key == "vigor" then
        add(BS("dropdown", base .. "textSource", L["Number on the bar"], { disabled = off, items = {
            { text = L["Vigor"], value = "vigor" },
            { text = L["%s charges"]:format(Spell("secondWind")), value = "secondWind" },
        } }))
    else
        add(Note(L["How many %s charges you have."]:format(Spell("secondWind"))))
    end
    add(BS("dropdown", tb .. "anchor", L["Position"], { items = ANCHOR_ITEMS, disabled = off }))
    add(BS("numbers", nil, L["Offset"], { sub = base .. "text", path = false, disabled = off,
        resetPaths = { tb .. "x", tb .. "y" }, fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } }))
    add(BS("dropdown", tb .. "font", L["Font"], { items = ns.Specs.ElementFontItems, disabled = off,
        get = function()
            local t = Row(key).text
            return ns.Specs.InheritOr(type(t) == "table" and t.font or nil)
        end }))
    add(BS("slider", tb .. "size", L["Font size"], { min = 6, max = 40, step = 1, disabled = off }))
    add(BS("color", tb .. "color", L["Color"], { hasAlpha = false, disabled = off }))
end

-- 電光的樣式：閃電（自己畫的序列圖）／掃光
local FX_STYLE_ITEMS = {
    { text = L["Lightning"], value = "lightning" },
    { text = L["Sweep"],     value = "sweep" },
}

local function AppendSurge(add, base)
    add({ type = "header", label = L["Effects"] })
    add(BS("toggle", base .. "fx", L["Electric effect when full"]))
    add(BS("dropdown", base .. "fxStyle", L["Style"], { items = FX_STYLE_ITEMS,
        disabled = function() return Row("surge").fx == false end,
        get = function() return Row("surge").fxStyle == "sweep" and "sweep" or "lightning" end }))
    add(BS("toggle", base .. "shake", L["Shake after it fills up"]))

    local ib = base .. "icon."
    local function IconOff() return SR().SurgeIcon(Cfg()) == "off" end
    add({ type = "header", label = L["Icon"] })
    add(BS("dropdown", ib .. "mode", L["Show when"], { items = ICON_ITEMS,
        get = function() return (SR().SurgeIcon(Cfg())) end }))
    add(BS("slider", ib .. "size", L["Icon size"], { min = 12, max = 64, step = 1, disabled = IconOff }))
    add(BS("dropdown", ib .. "side", L["Icon position"], { items = SIDE_ITEMS, disabled = IconOff,
        get = function() return select(3, SR().SurgeIcon(Cfg())) end }))
    add(Note(L["Border, zoom and cooldown swipe follow the theme's icon settings."]))
end

local function Controls(key)
    local list = {}
    local function add(s) list[#list + 1] = s end
    local base = "rows." .. key .. "."
    AppendLayout(add, key, base)
    AppendLook(add, key, base)
    AppendText(add, key, base)
    if key == "surge" then AppendSurge(add, base) end
    return list
end

local win = ns.SettingsWindow.New({
    id        = "skyridingsettings",
    configKey = KEY,
    width     = WIDTH,
    controls  = Controls,
    signature = function(key) return key end,
    onApply   = function()
        if ns.Skyriding then ns.Skyriding.Apply() end
        if ns.EditMode and ns.EditMode.Editing() and ns.EditMode.RequestRefresh then ns.EditMode.RequestRefresh() end
    end,
    hideOn    = { "OptionsHidden", "ProfileChanged" },
})

local VALID = { speed = true, surge = true, vigor = true, secondWind = true }

function SS.Open(key)
    if not VALID[key] or not Cfg() or not SR() then return end
    SR().Upgrade(Cfg())
    win:Open(key, SR().RowName(key), SR().RowIcon(key))
end

function SS.Close() win:Close() end

function SS.Refresh() win:Refresh() end
