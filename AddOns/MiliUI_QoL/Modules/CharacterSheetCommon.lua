------------------------------------------------------------
-- MiliUI_QoL: 角色面板自建功能的共用件（2026-10-15 從 MiliUI_Skin 的 Extras/ 整組搬來）
--
-- 四支功能：自建屬性清單（CharacterStats.lua）、角色面板右上角的齒輪＋右側設定面板
-- （CharacterStatsSettings.lua）、畫面上顯示屬性（StatsHud.lua）、稱號頁搜尋
-- （CharacterTitles.lua）。這裡放它們共用的東西：啟動、顏色、自畫底與邊、細捲軸、
-- 編輯狀態的廣播、找不到暴雪物件時的記錄。計算層在 vendor 的 `Libs/MiliUIStats.lua`
-- （`ns.Stats`）：列定義、暴雪算法、秘密值畫法、分區色。
--
-- 這幾支**不是皮**：自己的框、自己讀 API、自己畫列，疊在暴雪的面板上，暴雪原本那一份
-- `SetAlpha(0)` 藏起來照跑。對暴雪物件的規矩：零欄位寫入，只准 SetAlpha（走 `X.Neutralize`）、
-- HookScript、hooksecurefunc、把自己的框錨到／掛在暴雪框底下。每支模組的檔頭有自己的
-- 接觸面清單。
--
-- 啟動：PLAYER_LOGIN（`ns.Fire("Init")`）之後建。戰鬥中（戰鬥中 /reload）延到
-- PLAYER_REGEN_ENABLED——我們會把子框掛到暴雪的面板底下，戰鬥中不動暴雪框的子框清單。
-- 開關關掉就整支不建——沒有「建了再藏」這條路，關掉就是暴雪原本的樣子，所以要 /reload。
--
-- 有裝 MiliUI_Skin 時：Skin 照常替角色面板換皮，我們的清單疊在它上面；Skin 問
-- `MiliUIQoL.StatsListEnabled()` 決定要不要替（看不見的）暴雪屬性列上色。
-- 沒裝 Skin：清單擺在暴雪原生的底圖上（自己的字、自己的線，底是暴雪的）。
------------------------------------------------------------
local _, ns = ...

local P = ns.P
local S = ns.Secret
local Stats = ns.Stats

ns.CharSheet = {}
local X = ns.CharSheet

local WHITE = "Interface\\BUTTONS\\WHITE8X8"

------------------------------------------------------------
-- 設定
------------------------------------------------------------
function X.DB()
    return ns.db and ns.db.charSheet
end

function X.IsEnabled(key)
    local db = X.DB()
    if not db then return false end
    return db[key] ~= false
end

-- 對外（MiliUI_Skin 問）：自建屬性清單有沒有開。看設定不看建好沒——Skin 的掛勾在
-- PLAYER_LOGIN 就裝，那時我們可能還沒建（戰鬥中延後）
function ns.StatsListEnabled()
    return X.IsEnabled("statsPanel")
end

------------------------------------------------------------
-- 顏色（值照共用層 Libs/MiliUIWidgets/Widgets.lua 與 MiliUI_Skin 的 Tokens：
-- 面板填色 0.115、內嵌 0.08、勾選框 0.28、灰字 0.65；職業色走 Env.Accent）
------------------------------------------------------------
local C = {
    fill        = { 0.115, 0.115, 0.115, 1 },
    fillInset   = { 0.08, 0.08, 0.08, 1 },
    fillCheck   = { 0.28, 0.28, 0.28, 1 },
    border      = { 0, 0, 0, 1 },
    text        = { 1, 1, 1 },
    textDim     = { 0.65, 0.65, 0.65 },
    -- 分區標題兩側那兩條髮絲線的 alpha：線比字弱一階
    statRuleAlpha = 0.8,
    -- 屬性列裡標籤與數值之間那條引導線：白 6%
    statLeader  = { 1, 1, 1, 0.06 },
    highlightAlpha = 0.08,
    rowAccentSize  = 2,
    scrollThumb      = { 0.35, 0.35, 0.35, 1 },
    scrollTrack      = { 0.08, 0.08, 0.08, 1 },
    scrollThumbHover = { 0.5, 0.5, 0.5, 1 },
    scrollThumbSize  = 6,
    -- 勾選框（同共用層 W.CreateCheckButton 那張勾：24 高、貼圖裡佔 0.64、框 18）
    checkBoxSize = 18,
    checkGlyphHeight = 24,
    checkOutlineGlyphFrac = 0.64,
    checkOutlineTexture = "Interface\\AddOns\\MiliUI_QoL\\Libs\\MiliUIWidgets\\Media\\check-outline.tga",
}
X.C = C

function X.Accent()
    return ns.WidgetsEnv.Accent()
end

-- 選中態的底色：職業色壓暗到跟 fill 同一個亮度區間（同 MiliUI_Skin 的 T.AccentFill）
function X.AccentFill(alpha)
    local r, g, b = X.Accent()
    return r * 0.45, g * 0.45, b * 0.45, alpha or 1
end

function X.Font()
    return ns.Font()
end

-- HUD 皮的底（0.102 灰 alpha 0.8 ＋ 1px 職業色邊，.claude/notes/project-miliui-hud-skin.md）
X.HUD_FILL = { 0.102, 0.102, 0.102, 0.8 }

------------------------------------------------------------
-- 暴雪物件：只准這三種接觸
------------------------------------------------------------
-- 找不到的暴雪物件只記錄不報錯（暴雪改版會改名，要能降級成「少一塊」而不是整支掛掉）。
-- /mqol debug 印得出來。
X.missing = {}
local missingSeen = {}
function X.Missing(name)
    if missingSeen[name] then return end
    missingSeen[name] = true
    X.missing[#X.missing + 1] = name
end

-- 藏起來照跑：只 SetAlpha(0)，不 Hide（會被暴雪自己的 Show 打回來、還會跟編輯模式打架）
function X.Neutralize(frame, name)
    if not frame then
        X.Missing(name)
        return
    end
    pcall(frame.SetAlpha, frame, 0)
end

-- 讀暴雪框的層級（明碼數字才回；讀不到就回 nil，呼叫端自己給預設）
function X.TargetLevel(frame)
    if not frame or type(frame.GetFrameLevel) ~= "function" then return nil end
    local ok, lv = pcall(frame.GetFrameLevel, frame)
    if not ok then return nil end
    return S.PlainNumber(lv)
end

------------------------------------------------------------
-- 登記與啟動
--
-- 每支模組在檔案層呼叫 `X.Register(key, build)`；`key` ＝ `db.charSheet` 裡那個開關
-- （`nil` ＝ 永遠建，只看模組有沒有載入）。
------------------------------------------------------------
local modules = {}
X.built = {}

function X.Register(key, build)
    modules[#modules + 1] = { key = key, build = build }
end

local function BuildAll()
    for _, m in ipairs(modules) do
        local id = m.key or m.build
        if not X.built[id] and (m.key == nil or X.IsEnabled(m.key)) then
            local ok = xpcall(m.build, ns.ReportError)
            -- 出錯也記成已處理：重試只會在每次脫戰再炸一次
            X.built[id] = ok and "built" or "error"
        end
    end
end

local waiter
function X.Boot()
    if not InCombatLockdown() then
        BuildAll()
        return
    end
    if not waiter then
        waiter = CreateFrame("Frame")
        waiter:SetScript("OnEvent", function(self)
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            BuildAll()
        end)
    end
    waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
end

ns.RegisterCallback("Init", "CharSheet", function()
    Stats.SetStrings(X.STRINGS)
    Stats.SetErrorHandler(ns.ReportError)
    X.Boot()
end)

------------------------------------------------------------
-- 語系：暴雪沒有的兩個區標題（其餘標題一律用暴雪的 GlobalStrings）
------------------------------------------------------------
local LOCALE_STRINGS = {
    zhTW = { secondary = "次要屬性", tertiary = "第三屬性" },
    zhCN = { secondary = "次要属性", tertiary = "第三属性" },
}
X.STRINGS = LOCALE_STRINGS[GetLocale()] or { secondary = "Secondary Stats", tertiary = "Tertiary Stats" }

-- 數值顯示方式的下拉選項（齒輪面板與設定頁同一組）。
-- 「評等」玩家不直覺，選項裡一律叫「數值」（使用者 2026-10-15）
function X.ValueFormatItems()
    return {
        { text = "百分比", value = "pct" },
        { text = "數值", value = "rating" },
        { text = "百分比 (數值)", value = "pct_rating" },
        { text = "數值 (百分比)", value = "rating_pct" },
    }
end

------------------------------------------------------------
-- 自畫的底與邊（不用暴雪的 backdrop 模板——它自帶的 OnSizeChanged Lua 會跑進暴雪的
-- 執行堆疊；這幾個框掛在暴雪面板底下）
--
-- 一張底 ＋ 四條邊，邊寬 1 個實體像素（見下面 FramePixel）。回傳一張可換色的表：
--   bd:SetFill(c)／bd:SetBorder(c)     c ＝ { r, g, b, a }（或 nil 不變）
--   bd:SetFillShown(on)／bd:SetBorderShown(on)
--   bd:Relayout()                      重算邊寬（X.RelayoutPixels() 一次全跑）
------------------------------------------------------------
local function Paint(tex, c)
    tex:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
end

-- 1 個實體像素換成 frame 自己座標的 UI 單位：基準是**框自己的**有效縮放（StatsHud 會
-- SetScale），讀不到或秘密就退 P.Pixel。
-- ⚠ 不能只在建立時算一次：這幾支在 PLAYER_LOGIN 建，那時 UI 縮放還不一定是最終值 ⇒
--   建出來的底／邊／髮絲線都登記起來，顯示／排版時叫 X.RelayoutPixels() 重算、變了才重設。
-- 貼圖一律關像素貼齊（P.NoSnap）。規則全文：.claude/notes/wow-1px-border-rules.md
local function FramePixel(frame)
    local ok, scale = pcall(frame.GetEffectiveScale, frame)
    scale = ok and S.PlainNumber(scale)
    if not (scale and scale > 0) then return P.Pixel(1) end
    return PixelUtil.GetPixelToUIUnitFactor() / scale
end

local pixelObjs = {}   -- 框刪不掉 ⇒ 強參照也不會漏

function X.RelayoutPixels()
    for i = 1, #pixelObjs do pixelObjs[i]:Relayout() end
end

function X.Backdrop(frame, fill, border)
    local bd = {}
    local bg = P.NoSnap(frame:CreateTexture(nil, "BACKGROUND", nil, -8))
    bg:SetTexture(WHITE)
    bg:SetAllPoints(frame)
    bd.bg = bg

    local t = P.NoSnap(frame:CreateTexture(nil, "BORDER"))
    t:SetPoint("TOPLEFT"); t:SetPoint("TOPRIGHT")
    local b = P.NoSnap(frame:CreateTexture(nil, "BORDER"))
    b:SetPoint("BOTTOMLEFT"); b:SetPoint("BOTTOMRIGHT")
    local l = P.NoSnap(frame:CreateTexture(nil, "BORDER"))
    l:SetPoint("TOPLEFT"); l:SetPoint("BOTTOMLEFT")
    local r = P.NoSnap(frame:CreateTexture(nil, "BORDER"))
    r:SetPoint("TOPRIGHT"); r:SetPoint("BOTTOMRIGHT")
    bd.edges = { t, b, l, r }
    for _, e in ipairs(bd.edges) do e:SetTexture(WHITE) end

    -- 邊寬：跟上次一樣就不動
    function bd:Relayout()
        local px = FramePixel(frame)
        if self.px == px then return end
        self.px = px
        t:SetHeight(px); b:SetHeight(px)
        l:SetWidth(px); r:SetWidth(px)
    end
    bd:Relayout()
    pixelObjs[#pixelObjs + 1] = bd

    function bd:SetFill(c)
        if c then Paint(bg, c) end
    end
    function bd:SetBorder(c)
        if not c then return end
        for _, e in ipairs(self.edges) do Paint(e, c) end
    end
    function bd:SetFillShown(on)
        bg:SetShown(on and true or false)
    end
    function bd:SetBorderShown(on)
        for _, e in ipairs(self.edges) do e:SetShown(on and true or false) end
    end

    bd:SetFill(fill or C.fill)
    bd:SetBorder(border or C.border)
    return bd
end

-- 髮絲線：1 個**實體**像素（P.Pixel 的語意，不是 P.Scale——1440p 以上 P.Scale(1) 是 2px）
function X.Hairline(parent, color, layer)
    local tex = P.NoSnap(parent:CreateTexture(nil, layer or "ARTWORK"))
    tex:SetTexture(WHITE)
    tex:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    local line = {}
    function line:Relayout()
        local px = FramePixel(parent)
        if self.px == px then return end
        self.px = px
        tex:SetHeight(px)
    end
    line:Relayout()
    pixelObjs[#pixelObjs + 1] = line
    return tex
end

------------------------------------------------------------
-- 屬性清單的「編輯狀態」（角色面板右上角的齒輪開的設定面板開著＝on）
--
-- 不存檔：每次登入都是關的。狀態放在這裡（而不是 CharacterStatsSettings.lua），因為
-- 清單與畫面顯示都要聽——誰先載入都一樣。
------------------------------------------------------------
local editing = false
local editListeners = {}

function X.IsEditing()
    return editing
end

function X.OnEditChanged(fn)
    editListeners[#editListeners + 1] = fn
end

function X.SetEditing(on)
    on = on and true or false
    if on == editing then return end
    editing = on
    for _, fn in ipairs(editListeners) do
        xpcall(fn, ns.ReportError, on)
    end
end

-- 「屬性的設定改了」：清單與畫面顯示各自登記重畫（顏色、隱藏、排序、評等…）
local changeListeners = {}

function X.OnStatsChanged(fn)
    changeListeners[#changeListeners + 1] = fn
end

function X.NotifyStatsChanged(what)
    for _, fn in ipairs(changeListeners) do
        xpcall(fn, ns.ReportError, what)
    end
end

------------------------------------------------------------
-- 捲動容器 ＋ 套組那種細捲軸
--
-- 不用 `ScrollFrameTemplate`：它帶的是暴雪的 MinimalScrollBar（兩端兩顆立體箭頭），
-- 要的是套組設定視窗那種長相——軌道上一條置中的細條，沒有箭頭。整支只碰自己建的框。
--
-- 回傳 scroll（ScrollFrame）。用法：
--   scroll.child                    捲動內容，寬度自動跟著 scroll 走
--   scroll:SetContentHeight(h)      內容高度變了就叫
--   scroll:ScrollToTop()
-- opts.step：滾輪一格捲多少（預設 32）
------------------------------------------------------------
local BAR_GAP = 3        -- 內容與軌道之間
local THUMB_MIN = 16

function X.CreateScroll(parent, opts)
    opts = opts or {}
    local step = opts.step or 32
    local barW = C.scrollThumbSize

    local scroll = CreateFrame("ScrollFrame", nil, parent)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    scroll.child = child

    local track = CreateFrame("Frame", nil, parent)
    track:SetWidth(barW)
    track:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, 0)
    track:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 0, 0)
    track:SetFrameLevel(scroll:GetFrameLevel() + 5)
    local trackTex = track:CreateTexture(nil, "BACKGROUND")
    trackTex:SetAllPoints()
    trackTex:SetColorTexture(C.scrollTrack[1], C.scrollTrack[2], C.scrollTrack[3], C.scrollTrack[4] or 1)

    local thumb = CreateFrame("Button", nil, track)
    thumb:SetWidth(barW)
    thumb:SetPoint("TOP", track, "TOP", 0, 0)
    thumb:SetHeight(THUMB_MIN)
    local thumbTex = thumb:CreateTexture(nil, "ARTWORK")
    thumbTex:SetAllPoints()
    local function PaintThumb(hover)
        local c = hover and C.scrollThumbHover or C.scrollThumb
        thumbTex:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
    end
    PaintThumb(false)

    local contentH = 0
    local dragging, dragStartY, dragStartOffset

    local function ViewHeight()
        local h = S.PlainNumber(scroll:GetHeight())
        return h or 0
    end

    local function Range()
        return math.max(0, contentH - ViewHeight())
    end

    local function UpdateThumb()
        local view = ViewHeight()
        local range = Range()
        if range <= 0 or view <= 0 then
            track:Hide()
            return
        end
        track:Show()
        local th = math.max(THUMB_MIN, view * view / contentH)
        thumb:SetHeight(th)
        local offset = scroll:GetVerticalScroll() or 0
        local y = (view - th) * (offset / range)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, -y)
    end

    local function SetOffset(v)
        local range = Range()
        if v < 0 then v = 0 elseif v > range then v = range end
        scroll:SetVerticalScroll(v)
        UpdateThumb()
    end
    scroll.SetOffset = function(_, v) SetOffset(v) end

    -- 內容寬度：軌道顯示時讓出軌道寬 ＋ 間距（軌道不顯示也讓——內容寬不跟著跳）
    local function SyncWidth()
        local w = S.PlainNumber(scroll:GetWidth())
        if w and w > 0 then child:SetWidth(math.max(1, w - barW - BAR_GAP)) end
    end

    function scroll:SetContentHeight(h)
        contentH = h or 0
        child:SetHeight(math.max(1, contentH))
        SyncWidth()
        SetOffset(scroll:GetVerticalScroll() or 0)
    end

    function scroll:ScrollToTop()
        SetOffset(0)
    end

    function scroll:ContentWidth()
        local w = S.PlainNumber(scroll:GetWidth()) or 0
        return math.max(1, w - barW - BAR_GAP)
    end

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        SetOffset((scroll:GetVerticalScroll() or 0) - delta * step)
    end)
    scroll:SetScript("OnSizeChanged", function()
        SyncWidth()
        SetOffset(scroll:GetVerticalScroll() or 0)
    end)

    thumb:SetScript("OnEnter", function() PaintThumb(true) end)
    thumb:SetScript("OnLeave", function() if not dragging then PaintThumb(false) end end)
    thumb:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        local _, y = GetCursorPosition()
        dragging = true
        dragStartY = y / (self:GetEffectiveScale() or 1)
        dragStartOffset = scroll:GetVerticalScroll() or 0
        self:SetScript("OnUpdate", function(me)
            local _, cy = GetCursorPosition()
            cy = cy / (me:GetEffectiveScale() or 1)
            local view = ViewHeight()
            local room = view - (me:GetHeight() or 0)
            if room <= 0 then return end
            SetOffset(dragStartOffset + (dragStartY - cy) * Range() / room)
        end)
    end)
    thumb:SetScript("OnMouseUp", function(self)
        dragging = false
        self:SetScript("OnUpdate", nil)
        if not self:IsMouseOver() then PaintThumb(false) end
    end)
    -- 點軌道空白處：往那個方向翻一頁
    track:EnableMouse(true)
    track:SetScript("OnMouseDown", function(self)
        local _, cy = GetCursorPosition()
        cy = cy / (self:GetEffectiveScale() or 1)
        local top = thumb:GetTop()
        local page = ViewHeight() * 0.9
        local cur = scroll:GetVerticalScroll() or 0
        if top and cy > top then SetOffset(cur - page) else SetOffset(cur + page) end
    end)

    track:Hide()
    return scroll
end
