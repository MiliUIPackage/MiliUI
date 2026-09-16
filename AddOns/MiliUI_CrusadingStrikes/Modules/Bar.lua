------------------------------------------------------------
-- 我們的條：鏡射暴雪冷卻管理器長條的進度，掛到目標名條的血條底下
--
-- ⚠⚠ 12.1 最重要的一條規矩就在這支：
--   `src:GetMinMaxValues()` / `src:GetValue()` 在戰鬥中是**秘密值**。原生 StatusBar
--   之間互傳是允許的（我們只當傳遞者），但餵進去之後**我們這個 frame 整個會被標成
--   帶秘密值** —— 之後 `bar:GetWidth()` / `GetValue()` / `GetBottom()` / `GetPoint()`
--   全部回秘密值，而且會沿著錨定鏈往下傳染。
--
--   所以本檔（以及整支插件）**任何地方都不讀這條的幾何或值**：
--     * 尺寸一律從設定推導（SetHeight / SetWidth），不回讀；
--     * 寬度要跟血條一樣時用「左右各錨一個點」，不是量血條再 SetWidth；
--     * 顯示狀態自己用一個 local 記著，不叫 bar:IsShown()；
--     * 顏色走貼圖的 SetVertexColor。
--   細節見 .claude/notes/wow-121-secret-values.md。
------------------------------------------------------------
local _, ns = ...

ns.Bar = {}
local Bar = ns.Bar

local bar, fillTex, bgTex
local borders = {}
local driver

-- 目前掛在哪：display / 血條 / 施法條 / 施法條是不是在血條下方
-- atWidgets 是當時那張 widgets 表本人：名條插件換設計時會把整批 widget 收回池子再取，
-- display 還是同一個、`IsShown()` 也還是真，但表換了一張 —— 我們手上的血條參照就過期了。
-- 比對表的身分是唯一便宜又抓得到這件事的辦法。
local atDisplay, atHealth, atCast, atCastBelow, atWidgets

-- 我們自己記顯示狀態，不問 bar:IsShown()（見檔頭）
local shown = false
local revealFrames = 0
local castShowing = false
local hiddenByCast = false

------------------------------------------------------------
-- 建立
------------------------------------------------------------
local function CreateBorder()
    for i = 1, 4 do
        borders[i] = bar:CreateTexture(nil, "OVERLAY")
    end
    local top, bottom, left, right = borders[1], borders[2], borders[3], borders[4]
    top:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", -1, 0)
    top:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 1, 0)
    top:SetHeight(1)
    bottom:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", -1, 0)
    bottom:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 1, 0)
    bottom:SetHeight(1)
    left:SetPoint("TOPRIGHT", bar, "TOPLEFT", 0, 1)
    left:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", 0, -1)
    left:SetWidth(1)
    right:SetPoint("TOPLEFT", bar, "TOPRIGHT", 0, 1)
    right:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", 0, -1)
    right:SetWidth(1)
end

local function Create()
    if bar then return end

    bar = CreateFrame("StatusBar", "MiliUICSAA_Bar", UIParent)
    bar:EnableMouse(false)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:Hide()

    -- ⚠ 條的材質物件**只在這裡取一次**，而且是在餵過任何秘密值之前。
    --   之後換材質是對這個物件 SetTexture，不再叫 bar:GetStatusBarTexture() ——
    --   帶秘密值的 frame 上該少問一次就少問一次。
    bar:SetStatusBarTexture(ns.Media.WHITE8X8)
    fillTex = bar:GetStatusBarTexture()

    bgTex = bar:CreateTexture(nil, "BACKGROUND")
    bgTex:SetAllPoints(bar)

    CreateBorder()

    driver = CreateFrame("Frame")
end

------------------------------------------------------------
-- 外觀
------------------------------------------------------------
local function Paint()
    local b = ns.db.bar
    local f, k = b.colorFill, b.colorBack

    if b.fillMode == "elapsed" then
        -- 已揮的時間左→右長出：反向填充讓「剩餘」那截貼在右邊，於是
        -- **兩層的角色互換** —— 條的材質當「還沒到的時間」的遮罩（back 色），
        -- 背景才是玩家看到的進度（fill 色）。不需要「貼圖錨在移動邊緣」那套技巧。
        -- back 色預設是半透明黑，疊在 fill 色上等於把還沒到的那截壓暗 ——
        -- 剛好就是套組的狀態規則（只換明暗不換色）。
        bar:SetReverseFill(true)
        if fillTex then fillTex:SetVertexColor(k.r, k.g, k.b, k.a or 1) end
        bgTex:SetVertexColor(f.r, f.g, f.b, f.a or 1)
    else
        -- 傳統倒數：剩餘時間由右往左縮短
        bar:SetReverseFill(false)
        if fillTex then fillTex:SetVertexColor(f.r, f.g, f.b, f.a or 1) end
        bgTex:SetVertexColor(k.r, k.g, k.b, k.a or 1)
    end

    for _, tex in ipairs(borders) do
        tex:SetColorTexture(0, 0, 0, 1)
        tex:SetShown(b.border and true or false)
    end
end

------------------------------------------------------------
-- 位置
--
-- 全部相對錨定。widthMode = "match" 用左右兩個錨點取寬 —— 這樣不必讀血條的寬度，
-- 而且名條插件的縮放改變時會自己跟上。
------------------------------------------------------------
local function ApplyPoints()
    if not atHealth then return end
    local b = ns.db.bar

    local anchorTo = atHealth
    hiddenByCast = false
    if atCast and castShowing then
        if b.castMode == "hide" then
            hiddenByCast = true
        elseif b.castMode == "below" and atCastBelow then
            anchorTo = atCast
        end
        -- "stay"，或施法條其實在血條上方 → 照舊掛在血條下
    end

    bar:ClearAllPoints()
    if b.widthMode == "match" then
        bar:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", b.offsetX, -b.gap)
        bar:SetPoint("TOPRIGHT", anchorTo, "BOTTOMRIGHT", b.offsetX, -b.gap)
    else
        bar:SetPoint("TOP", anchorTo, "BOTTOM", b.offsetX, -b.gap)
        bar:SetWidth(math.max(1, b.width))
    end
    bar:SetHeight(math.max(1, b.height))
end

------------------------------------------------------------
-- 顯示／隱藏（自己記狀態，不回讀）
------------------------------------------------------------
local function HideBar()
    if not shown then return end
    shown = false
    revealFrames = 0
    bar:Hide()
end

local function ShowBar()
    if shown then return end
    shown = true
    -- 第一次顯示壓兩幀：上一次的值還留在條上，不壓的話會先閃一格舊進度
    bar:SetAlpha(0)
    revealFrames = 2
    bar:Show()
end

------------------------------------------------------------
-- 每幀：鏡射
------------------------------------------------------------
local function OnUpdate()
    local item = ns.Source.GetTrackedItem()
    if not item or not ns.Source.IsItemActive(item) then
        HideBar()
        return
    end

    local src = item.Bar
    if not src or not src.GetValue then
        HideBar()
        return
    end

    -- 施法條的顯示狀態變了才重設錨點（IsShown 是明文布林，可以 if）
    local castNow = (atCast and atCast.IsShown and atCast:IsShown()) and true or false
    if castNow ~= castShowing then
        castShowing = castNow
        ApplyPoints()
    end
    if hiddenByCast then
        HideBar()
        return
    end

    ShowBar()

    -- ⚠ 這四行就是整支插件的重點：秘密值在兩個原生 StatusBar 之間直接轉手，
    --   中間沒有任何 Lua 的比較或算術。存進 local 是允許的。
    -- ⚠ 一定要先落地再餵：Lua 在最後一個參數位置會把多回傳值全部展開，而
    --   `StatusBar:SetValue` 的第二個參數在 12.x 是**插值模式** ——
    --   哪天 getter 多回一個值，直接串接就會變成餵了一個旗標進去（整條鋪滿）。
    local minValue, maxValue = src:GetMinMaxValues()
    bar:SetMinMaxValues(minValue, maxValue)
    local value = src:GetValue()
    bar:SetValue(value)

    if revealFrames > 0 then
        revealFrames = revealFrames - 1
        if revealFrames == 0 then bar:SetAlpha(1) end
    end
end

------------------------------------------------------------
-- 掛上／卸下
------------------------------------------------------------
local function Detach()
    if not bar then return end
    HideBar()
    if driver then driver:SetScript("OnUpdate", nil) end
    if atDisplay then
        bar:ClearAllPoints()
        bar:SetParent(UIParent)
    end
    atDisplay, atHealth, atCast, atCastBelow, atWidgets = nil, nil, nil, nil, nil
    castShowing, hiddenByCast = false, false
end

local function Attach(display, health, cast, castBelow)
    if atDisplay == display and atHealth == health and atCast == cast then
        if not driver:GetScript("OnUpdate") then driver:SetScript("OnUpdate", OnUpdate) end
        return
    end

    HideBar()
    atDisplay, atHealth, atCast, atCastBelow = display, health, cast, castBelow
    atWidgets = display.widgets
    castShowing, hiddenByCast = false, false

    -- parent 在 display 上就自動吃到名條的縮放、淡出與顯示狀態。
    -- frame level 不是秘密值，可以讀。
    bar:SetParent(display)
    bar:SetFrameStrata("MEDIUM")
    local level = health.GetFrameLevel and health:GetFrameLevel()
    bar:SetFrameLevel((tonumber(level) or 0) + 5)

    ApplyPoints()
    driver:SetScript("OnUpdate", OnUpdate)
end

------------------------------------------------------------
-- 對外
------------------------------------------------------------
function Bar.Refresh()
    if not bar or not ns.db then return end
    if not ns.isPaladin or not ns.db.enabled then
        Detach()
        return
    end
    if not ns.Source.GetTrackedItem() then
        Detach()
        return
    end

    -- 已經掛好而且還活著就不動（每 0.5 秒重掛一次等於每 0.5 秒 SetParent）
    if atDisplay and ns.Anchor.StillValid(atDisplay) and atDisplay.widgets == atWidgets then
        return
    end

    local display, health, cast, castBelow = ns.Anchor.Resolve()
    if not display or not health then
        Detach()
        return
    end
    Attach(display, health, cast, castBelow)
end

-- 目標／名條變了：手上的 display 一定要重解析，不能走 Refresh 的「還活著就不動」快路。
-- ⚠ 但重解析 ≠ 重掛：NAME_PLATE_UNIT_ADDED／REMOVED 對**每一個**進出畫面的名條都會派送，
--   這裡如果先 Detach 再 Attach，別的怪一冒出來我們的條就閃一下（reveal 那兩幀）並多做
--   一次 SetParent。解析結果跟手上的一樣就什麼都不做。
function Bar.Relocate()
    if not bar or not ns.db then return end
    if not ns.isPaladin or not ns.db.enabled or not ns.Source.GetTrackedItem() then
        Detach()
        return
    end
    local display, health, cast, castBelow = ns.Anchor.Resolve()
    if not display or not health then
        Detach()
        return
    end
    if display == atDisplay and health == atHealth and cast == atCast
        and display.widgets == atWidgets then
        return
    end
    Detach()
    Attach(display, health, cast, castBelow)
end

function Bar.ApplySettings()
    if not bar or not ns.db then return end
    local b = ns.db.bar

    local path = ns.Media.BarTexture(b.texture)
    if fillTex then fillTex:SetTexture(path) end
    bgTex:SetTexture(path)

    Paint()
    ApplyPoints()
    Bar.Relocate()
end

function Bar.GetDebugInfo()
    return {
        created   = bar ~= nil,
        attached  = atDisplay ~= nil,
        health    = atHealth ~= nil,
        cast      = atCast ~= nil,
        castBelow = atCastBelow and true or false,
        running   = driver ~= nil and driver:GetScript("OnUpdate") ~= nil,
    }
end

------------------------------------------------------------
-- 啟動
------------------------------------------------------------
local events = CreateFrame("Frame")

ns.RegisterCallback("Init", "bar", function()
    if not ns.isPaladin then return end   -- 非聖騎士：插件休眠，只留設定視窗

    Create()
    Bar.ApplySettings()
    ns.Source.Start()

    events:RegisterEvent("PLAYER_TARGET_CHANGED")
    events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    -- 事件的 unit token 一個都不讀（12.1 那可能是秘密字串），只當「該重看一次了」的訊號
    events:SetScript("OnEvent", function()
        Bar.Relocate()
    end)

    ns.poll.Add("anchor", 0.5, Bar.Refresh)
end)
