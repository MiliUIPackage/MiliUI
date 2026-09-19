------------------------------------------------------------
-- 定位：目標名條上的血條／施法條
--
-- 這支只做一件事：回答「現在該把條掛在哪個框底下」。它讀的是名條插件**公開在
-- 框架物件上的欄位**（跨插件互通的常見做法），不複製對方任何程式碼。
--
-- 12.1 紅線（逐條對照 .claude/notes/wow-121-secret-values.md）：
--   * 不讀任何幾何（GetTop / GetBottom / GetWidth 一律不叫）—— 位置全部用相對錨點，
--     寬度用「兩端各錨一個點」取得。名條上的東西帶秘密幾何時，讀了就是崩潰。
--   * 不拿事件的 unit token 去比對（12.1 那可能是秘密字串），一律重問
--     GetNamePlateForUnit("target")。
--   * 不對別人的框寫欄位、不掛勾別人的腳本。施法條在不在，Bar 每幀讀一次
--     IsShown() 就夠了（我們本來就每幀在跑）。
------------------------------------------------------------
local _, ns = ...

ns.Anchor = {}
local Anchor = ns.Anchor

------------------------------------------------------------
-- 「施法條在血條下方嗎」
--
-- 用設計檔上的**明文數字**算，不是量畫面：每個條的錨點寫成一個陣列
-- （空 = 置中；3 元素 = {point, x, y}；2 元素 = {x, y} 置中對齊；1 元素 = 只有 point），
-- 高度是 rawHeight × scale。兩者都是設計資料，不是秘密值。
--
-- 為什麼要判斷：施法條被擺在血條**上方**的設計不少，那種情況下「讓位到施法條下方」
-- 會把我們的條丟到血條中間。判不出來就當作不讓位。
------------------------------------------------------------
local function VerticalRange(widget)
    if not widget then return end
    local details = widget.details
    if type(details) ~= "table" then return end

    local h = tonumber(widget.rawHeight)
    if not h then return end
    h = h * (tonumber(details.scale) or 1)

    local anchor = details.anchor
    if type(anchor) ~= "table" then return end

    local point, y = "CENTER", 0
    local n = #anchor
    if n >= 3 then
        point, y = anchor[1], tonumber(anchor[3]) or 0
    elseif n == 2 then
        point, y = "CENTER", tonumber(anchor[2]) or 0
    elseif n == 1 then
        point, y = anchor[1], 0
    end
    if type(point) ~= "string" then return end

    if point:find("TOP") then
        return y, y - h
    elseif point:find("BOTTOM") then
        return y + h, y
    end
    return y + h / 2, y - h / 2
end

-- ⚠ 比**中心點**，不比邊緣。設計檔常讓施法條的頂邊往上疊進血條底邊一點點，
--   好讓兩條的邊框併成一條線 —— 套組預設的設計就疊了 1.29 單位
--   （血條底 -8.79、施法條頂 -7.50）。原本「頂邊要低於底邊、容忍 0.5」的寫法
--   會把這種設計判成「不在下方」，讓位就靜悄悄地不發生（2026-09-19 實機）。
--   中心點對互疊不敏感，施法條擺在血條上方的設計一樣分得出來。
local function CastIsBelowHealth(health, cast)
    if not cast then return false end
    local healthTop, healthBottom = VerticalRange(health)
    local castTop, castBottom = VerticalRange(cast)
    if not healthTop or not castTop then return false end
    return (castTop + castBottom) / 2 < (healthTop + healthBottom) / 2
end

------------------------------------------------------------
-- 找框
--
-- 名條插件對每個名條預先配置多個 display，同時只有一個在用；判準是
-- 「有 widgets 表、有 unit、而且顯示中」。找不到就是沒裝那支插件，或名條被簡化了。
------------------------------------------------------------
local function FindDisplay(nameplate)
    local kids = { nameplate:GetChildren() }
    for _, child in ipairs(kids) do
        if type(child) == "table"
            and type(child.widgets) == "table"
            and child.unit ~= nil            -- 只比 nil，不讀值（可能是秘密字串）
            and child.IsShown and child:IsShown() then
            return child
        end
    end
end

local function FindBars(display)
    local widgets = display.widgets
    if type(widgets) ~= "table" then return end
    local health, cast
    for _, w in ipairs(widgets) do
        if type(w) == "table" and w.kind == "bars" and type(w.details) == "table" then
            local kind = w.details.kind
            if kind == "health" then
                health = health or w
            elseif kind == "cast" then
                cast = cast or w
            end
        end
    end
    return health, cast
end

-- → display, healthWidget, castWidget, castIsBelow（都可能是 nil）
local function ResolveNameplate()
    if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return end
    local nameplate = C_NamePlate.GetNamePlateForUnit("target")
    if not nameplate then return end

    local display = FindDisplay(nameplate)
    if not display then return end

    local health, cast = FindBars(display)
    if not health then return end

    return display, health, cast, CastIsBelowHealth(health, cast)
end

------------------------------------------------------------
-- display 還活著嗎（給輪詢用的便宜檢查）
--
-- 名條插件換設計時會把整批 display 收回池子重裝，那時候我們手上的參照還在，
-- 只是不再屬於任何單位。
------------------------------------------------------------
function Anchor.StillValid(display)
    if type(display) ~= "table" then return false end
    if display.unit == nil then return false end
    if not display.IsShown or not display:IsShown() then return false end
    return type(display.widgets) == "table"
end

------------------------------------------------------------
-- 另一個宿主：冷卻管理器插件的聖能條
--
-- 那支插件把每種資源的條放在一張公開的表裡，鍵是 Enum.PowerType。我們只拿那個框來
-- 當錨點與 parent（吃到它的縮放、淡出與顯示狀態），**不寫它任何欄位、不掛勾它的腳本、
-- 不讀它的幾何** —— 等寬用「左右各錨一個點」，跟名條那邊同一招。
-- 它不走訪子框（查過），所以 parent 過去不會被當成它自己的格子處理。
-- ⚠ 反方向不成立：別讓它的任何框錨到我們的條上 —— 我們的條餵過秘密值，
--   秘密幾何會沿錨定鏈傳給依附它的框。我們依附別人沒事。
------------------------------------------------------------
local HOLY_POWER = Enum and Enum.PowerType and Enum.PowerType.HolyPower or 9

function Anchor.ResolveResource()
    local host = _G.Ayije_CDM
    local bars = type(host) == "table" and host.resourceBars
    local bar = type(bars) == "table" and bars[HOLY_POWER]
    if type(bar) ~= "table" or not bar.IsShown then return end
    if not bar:IsShown() then return end       -- 換專精／停用資源條時它是藏著的
    return bar
end

function Anchor.ResourceStillValid(bar)
    return type(bar) == "table" and bar.IsShown and bar:IsShown() and true or false
end

function Anchor.IsResourceMode(mode)
    return mode == "resourceAbove" or mode == "resourceBelow"
end

-- → display, anchorWidget, castWidget, castIsBelow（都可能是 nil）
-- 聖能條模式下 display 與 anchorWidget 是同一個框，沒有施法條。
function Anchor.Resolve(mode)
    if Anchor.IsResourceMode(mode) then
        local bar = Anchor.ResolveResource()
        if not bar then return end
        return bar, bar, nil, false
    end
    return ResolveNameplate()
end
