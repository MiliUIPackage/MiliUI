------------------------------------------------------------
-- 資訊列本體：DB、事件樞紐、輪詢、方塊工廠、版面、編輯模式拖曳
--
-- 結構是「一條 bar ＋ 一排 tile」。每個區塊（Core/Blocks.lua、Core/MicroMenu.lua）
-- 產出一到多顆 tile，這裡只負責把啟用中的區塊照 order 排成一列。
--
-- ⚠ 戰鬥紀律（照 EllesmereUI DataBars 實測過的規則）：
--   micromenu 區塊的按鈕是 secure frame，bar 因此成為隱式保護框——連同所有
--   tile 在戰鬥中都不能 Show/Hide/SetPoint/SetSize（ADDON_ACTION_BLOCKED）。
--   所以 ApplyAll 與 Layout 在戰鬥中一律整包延到 PLAYER_REGEN_ENABLED；
--   戰鬥中允許的只有 SetText / SetVertexColor / SetAlpha。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local P = ns.P
local S = ns.Secret

local WHITE = "Interface\\Buttons\\WHITE8X8"

------------------------------------------------------------
-- 視覺常數：跟 Chattynator 側邊按鈕（MiliUI/Enhance/Chattynator_ButtonStyle.lua）
-- 同一套語彙——純色方底、1px 直角硬邊、滑過換職業色。
-- 邊框 0.30 的理由也一樣：這排東西坐在會動的遊戲畫面上，
-- 純黑描不出方形，拉亮到 0.30 才立得起來。
------------------------------------------------------------
-- 底色與框線色是可設定的（設定 > 一般），預設值在 Config.lua 的 DB_DEFAULTS。
-- 按下去的暗色不另外開設定：從底色推導（乘 PUSHED_MUL），玩家換了底色它自動跟著，
-- 而且永遠比底色暗——開成獨立設定只會多一個能調到「按下去比較亮」的坑。
local PUSHED_MUL = 0.35
local HIGHLIGHT  = { 1, 1, 1, 0.13 }   -- 滑過的白薄膜，疊在任何底色上都成立

local TILE_GAP  = 2   -- 同一區塊內 tile 的間距
local BLOCK_GAP = 6   -- 區塊之間的間距（內小外大，這排才讀得成「一組一組」）
local PAD_X     = 8   -- 文字 tile 的左右內距

-- ⚠ 這一行要在下面幾支取色函式**之前**：宣告在後面的話，它們裡面的 `db`
-- 會被當成全域（永遠 nil），色票就靜默失效、永遠讀預設值。
local db

local function BgColor()
    local c = db and db.bgColor or ns.DB_DEFAULTS.bgColor
    return c.r, c.g, c.b, c.a
end

local function EdgeColor()
    local c = db and db.edgeColor or ns.DB_DEFAULTS.edgeColor
    return c.r, c.g, c.b, c.a
end

local function PushedColor()
    local r, g, b, a = BgColor()
    return r * PUSHED_MUL, g * PUSHED_MUL, b * PUSHED_MUL, a
end

-- 文字強調色＝數值那半的顏色。標籤那半在 Blocks.lua 用 |cffaaaaaa 寫死成灰，
-- 而 |r 是「還原成 FontString 的基準色」——所以這裡設基準色就只染到數值，
-- 不必去動每一支 getText。
local function TextColor()
    local mode = db and db.textColorMode or ns.DB_DEFAULTS.textColorMode
    if mode == "class" then
        return ns.W.Accent(1)
    end
    local c = db and db.textColor or ns.DB_DEFAULTS.textColor
    return c.r, c.g, c.b, c.a
end

----------------------------------------------------------------------
-- SavedVariables（`local db` 宣告在上面的取色函式之前）
----------------------------------------------------------------------
local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function ns.InitDB()
    if db then return db end
    MiliUI_InfoBar_DB = MiliUI_InfoBar_DB or {}
    db = MiliUI_InfoBar_DB
    CopyDefaults(ns.DB_DEFAULTS, db)
    -- 一次性遷移：v1 的預設位置寫死 (0,-420) 而且當時拖曳是壞的，清掉讓
    -- 「跟隨官方微型選單那排」的新預設接手。真的拖去那個座標的人不存在
    -- （拖曳從沒動過）。
    if db.posVersion == nil then
        db.posVersion = 2
        if db.x == 0 and db.y == -420 then
            db.x, db.y = nil, nil
        end
    end
    -- 配色預設值演進：只搬「還停在上一版預設」的存檔，自己挑過顏色的一概不動。
    --   v2：框線 0.30（看得見的灰框）→ 跟底色同色（看不出有框）
    --   v3：不透明 0.115 → 套組標準的半透明灰（跟傷害統計／聊天視窗同一個底）
    local cv = db.colorVersion or 1
    if cv < 2 then
        local e = db.edgeColor
        if type(e) == "table" and e.r == 0.30 and e.g == 0.30 and e.b == 0.30 then
            e.r, e.g, e.b, e.a = db.bgColor.r, db.bgColor.g, db.bgColor.b, db.bgColor.a
        end
    end
    if cv < 3 then
        local b, e = db.bgColor, db.edgeColor
        if type(b) == "table" and b.r == 0.115 and b.g == 0.115 and b.b == 0.115 and b.a == 1
           and type(e) == "table" and e.r == 0.115 and e.g == 0.115 and e.b == 0.115 then
            ns.ApplyColorPreset("pack")
        end
    end
    db.colorVersion = 3
    return db
end

----------------------------------------------------------------------
-- 配色 preset：把某一組 preset 的顏色寫進 bgColor / edgeColor
--
-- ⚠ 一定要**原地改欄位**、不要換掉整張 color 表：設定頁的色票每次 refresh
-- 都重讀 db.bgColor，換表雖然也讀得到，但 ResetDB 那類原地清空的路徑就會
-- 出現兩張表打架。統一成原地改，只有一種行為要記。
----------------------------------------------------------------------
local function CopyColor(dst, src)
    dst.r, dst.g, dst.b, dst.a = src.r, src.g, src.b, src.a
end

function ns.GetColorPreset(id)
    for _, p in ipairs(ns.COLOR_PRESETS) do
        if p.id == id then return p end
    end
end

function ns.ApplyColorPreset(id)
    local p = ns.GetColorPreset(id)
    if not (p and db) then return end
    CopyColor(db.bgColor, p.bg)
    CopyColor(db.edgeColor, p.edge)
end

-- 現在的顏色屬於哪一組 preset（都對不上就是 "custom"）。
-- 下拉選單的顯示值走這支——preset 不存進 DB，所以不可能出現
-- 「下拉說是 A、顏色其實是 B」的狀態。
local function SameColor(c, ref)
    return type(c) == "table"
       and c.r == ref.r and c.g == ref.g and c.b == ref.b and (c.a or 1) == ref.a
end

function ns.CurrentColorPreset()
    if not db then return "custom" end
    for _, p in ipairs(ns.COLOR_PRESETS) do
        if SameColor(db.bgColor, p.bg) and SameColor(db.edgeColor, p.edge) then
            return p.id
        end
    end
    return "custom"
end

function ns.GetDB()
    return db or ns.InitDB()
end

----------------------------------------------------------------------
-- 脫戰延遲佇列：同 key 只留最後一筆，PLAYER_REGEN_ENABLED 統一沖掉
----------------------------------------------------------------------
local deferred = {}

function ns.Defer(key, fn)
    if not InCombatLockdown() then
        fn()
        return
    end
    deferred[key] = fn
end

local function FlushDeferred()
    if not next(deferred) then return end
    local batch = deferred
    deferred = {}
    for _, fn in pairs(batch) do
        xpcall(fn, ns.ReportError)
    end
end

----------------------------------------------------------------------
-- 事件樞紐：一個 frame 服務所有區塊，逐項 xpcall 隔離
-- （一支區塊拋錯不能讓同事件的其他區塊跟著啞掉）
----------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local subs = {}

ns.Events = {}

function ns.Events.Register(event, key, fn)
    local t = subs[event]
    if not t then
        t = {}
        subs[event] = t
        -- pcall：清單裡萬一有這個 client 不存在的事件名，不要讓整包載入炸掉
        pcall(eventFrame.RegisterEvent, eventFrame, event)
    end
    t[key] = fn
end

function ns.Events.Unregister(event, key)
    local t = subs[event]
    if not t then return end
    t[key] = nil
    if not next(t) then
        subs[event] = nil
        pcall(eventFrame.UnregisterEvent, eventFrame, event)
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local t = subs[event]
    if not t then return end
    for _, fn in pairs(t) do
        xpcall(fn, ns.ReportError, ...)
    end
end)

----------------------------------------------------------------------
-- 共用輪詢：沒有啟用中的輪詢區塊時 ticker 整支不存在（Metro 的行為），
-- 所以「不開 fps／時鐘那幾個區塊就零常駐成本」是結構保證，不是約定
----------------------------------------------------------------------
ns.Poll = ns.Metro.New(0.5, ns.ReportError)

----------------------------------------------------------------------
-- Tile 工廠
--
-- 每顆 tile 是一顆 Button：底色貼圖＋四條 1px 邊＋（文字 tile）置中的 FontString。
-- 寬度由文字量出來存進 desiredW，實際 SetSize 交給 Layout ——
-- 戰鬥中 SetText 照做、幾何一律凍結，脫戰的那次 Layout 補齊。
----------------------------------------------------------------------
local bar
local allTiles = {}
local layoutQueued = false

local function Docked()
    return db and db.dock and db.dock ~= "none" and db.dock or nil
end

-- 框線色，「跟底色同色就不畫」的規則在這裡：邊是疊在底色之上的，半透明時
-- 兩層 0.8 會疊成 0.96，邊緣就浮出一圈比中間更深的框——正好是「同色＝看不出
-- 有框」想避免的東西。
local function EdgeColorOrHidden()
    local r, g, b, a = EdgeColor()
    local br, bg_, bb = BgColor()
    if r == br and g == bg_ and b == bb then a = 0 end
    return r, g, b, a
end

local function ApplyEdgeColor(tile, hover)
    local edges = tile.edges
    if hover then
        local r, g, b = ns.W.Accent(1)
        for _, e in ipairs(edges) do e:SetVertexColor(r, g, b, 1) end
    elseif Docked() then
        -- 停靠時底與框線由整條 bar 畫（見 ApplyBarChrome），tile 自己的不畫，
        -- 否則兩層半透明疊在一起、tile 的區域會比空白區深一階
        for _, e in ipairs(edges) do e:SetVertexColor(0, 0, 0, 0) end
    else
        for _, e in ipairs(edges) do e:SetVertexColor(EdgeColorOrHidden()) end
    end
end

ns.ApplyEdgeColor = ApplyEdgeColor

-- 停靠時整條 bar 的底與上下框線（tile 之間的空白也要有底）。
-- 不停靠就藏起來，底由每顆 tile 自己畫（原本的樣子）。
local function ApplyBarChrome()
    if not (bar and bar.bg) then return end
    local docked = Docked() ~= nil
    bar.bg:SetShown(docked)
    if docked then bar.bg:SetVertexColor(BgColor()) end
    local r, g, b, a = EdgeColorOrHidden()
    for _, e in ipairs(bar.edges) do
        e:SetShown(docked)
        e:SetVertexColor(r, g, b, a)
    end
end

-- 換過底色／框線色之後重新套到每一顆 tile（含已經建好、現在沒顯示的）。
-- 滑鼠正停在上面的那顆維持職業色，不然拖著色票調色時焦點那顆會被抹掉。
local function ApplyColors()
    local docked = Docked() ~= nil
    for _, tile in ipairs(allTiles) do
        if tile.bg then
            local r, g, b, a = BgColor()
            tile.bg:SetVertexColor(r, g, b, docked and 0 or a)
        end
        if tile.edges then ApplyEdgeColor(tile, tile:IsMouseMotionFocus()) end
        if tile.text then tile.text:SetTextColor(TextColor()) end
    end
    ApplyBarChrome()
end

function ns.CreateTile(name, opts)
    opts = opts or {}
    local tile = CreateFrame("Button", name, bar, opts.template)
    tile.desiredW = ns.GetDB().height

    local bg = tile:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(WHITE)
    bg:SetVertexColor(BgColor())
    tile.bg = bg

    local edges = {}
    for i = 1, 4 do
        local e = tile:CreateTexture(nil, "BORDER")
        e:SetTexture(WHITE)
        edges[i] = e
    end
    edges[1]:SetPoint("TOPLEFT");    edges[1]:SetPoint("TOPRIGHT")
    edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT")
    edges[3]:SetPoint("TOPLEFT");    edges[3]:SetPoint("BOTTOMLEFT")
    edges[4]:SetPoint("TOPRIGHT");   edges[4]:SetPoint("BOTTOMRIGHT")
    local px = P.Scale(1)
    edges[1]:SetHeight(px); edges[2]:SetHeight(px)
    edges[3]:SetWidth(px);  edges[4]:SetWidth(px)
    tile.edges = edges
    ApplyEdgeColor(tile, false)

    if opts.text then
        local fs = tile:CreateFontString(nil, "OVERLAY")
        fs:SetFont(ns.LOCALE_FONT, ns.GetDB().fontSize, "")
        fs:SetPoint("CENTER")
        fs:SetJustifyH("CENTER")
        fs:SetWordWrap(false)
        fs:SetTextColor(TextColor())
        tile.text = fs
    end

    if opts.clickable then
        tile:EnableMouse(true)
        tile:RegisterForClicks("AnyUp")
        -- 底色的滑過亮階交給引擎的 highlight 貼圖（白 0.13 疊 0.115 ≈ 0.23），
        -- 職業色那半（1px 邊）走 OnEnter/OnLeave —— 跟 Chattynator 按鈕同一句話：
        -- 明暗說「它現在怎麼了」，職業色說「焦點在這」。
        tile:SetHighlightTexture(WHITE)
        local hl = tile:GetHighlightTexture()
        hl:SetVertexColor(HIGHLIGHT[1], HIGHLIGHT[2], HIGHLIGHT[3], HIGHLIGHT[4])
        tile:SetPushedTextOffset(0, 0)
        tile:HookScript("OnEnter", function(self) ApplyEdgeColor(self, true) end)
        tile:HookScript("OnLeave", function(self) ApplyEdgeColor(self, false) end)
        tile:HookScript("OnMouseDown", function(self)
            self.bg:SetVertexColor(PushedColor())
        end)
        tile:HookScript("OnMouseUp", function(self)
            self.bg:SetVertexColor(BgColor())
        end)
    else
        -- 純顯示的 tile 不吃滑鼠：資訊列不該擋住底下的遊戲畫面點擊
        tile:EnableMouse(false)
    end

    -- 文字變了才量寬、寬變了才要求重排 —— 每秒輪詢的區塊大多數 tick
    -- 在這裡就短路掉了
    function tile:SetTileText(str)
        if not self.text or self._lastText == str then return end
        self._lastText = str
        self.text:SetText(str)
        local w = math.ceil(self.text:GetStringWidth()) + PAD_X * 2
        if w ~= self.desiredW then
            self.desiredW = w
            ns.RequestLayout()
        end
    end

    function tile:ApplyFont(size)
        if self.text then
            self.text:SetFont(ns.LOCALE_FONT, size, "")
            -- 字級變了寬度也會變，重量一次
            local str = self._lastText
            self._lastText = nil
            if str then self:SetTileText(str) end
        end
    end

    allTiles[#allTiles + 1] = tile
    tile:Hide()
    return tile
end

----------------------------------------------------------------------
-- 版面：啟用中的區塊照 order 排成一列，bar 自動縮放成內容寬
----------------------------------------------------------------------
local instances = {}      -- key -> 區塊實例
ns.Instances = instances

local function EnabledInstancesInOrder()
    local list = {}
    for _, def in ipairs(ns.BLOCK_DEFS) do
        local cfg = db.blocks[def.key]
        local inst = instances[def.key]
        if cfg and cfg.enabled and inst then
            list[#list + 1] = { inst = inst, order = cfg.order or 0 }
        end
    end
    table.sort(list, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.inst.key < b.inst.key   -- 同序號用 key 決勝，重排才不會抖
    end)
    return list
end

local function Layout()
    if not bar then return end
    -- bar 是 secure 按鈕的祖先＝隱式保護框，戰鬥中的幾何變更會被封鎖；
    -- 凍結現狀，脫戰一次補齊
    if InCombatLockdown() then
        ns.Defer("layout", Layout)
        return
    end

    local h = db.height
    local blockGap = db.blockGap or BLOCK_GAP
    -- 區塊間距縮到比預設 tile 間距還小時，同區塊內的間距跟著收——
    -- 不然「區塊之間 0、按鈕之間 2」會讀成反過來的群組
    local tileGap = math.min(TILE_GAP, blockGap)
    local merged = (blockGap == 0)

    -- 先收集「要顯示的 tile ＋ 它前面該留多少間距」，再一次排出去。
    -- 分兩段是為了知道每個 tile 的前一顆是誰——鏈式錨定要用（見下）。
    local shownList, gapBefore = {}, {}
    local list = EnabledInstancesInOrder()
    for i, entry in ipairs(list) do
        local first = true
        for _, tile in ipairs(entry.inst.tiles) do
            if not tile._blockHidden then
                shownList[#shownList + 1] = tile
                -- 同區塊內用 tileGap，跨區塊用 blockGap；整條第一顆沒有前間距
                gapBefore[#shownList] = (#shownList == 1) and 0
                    or (first and blockGap or tileGap)
                first = false
            else
                tile:Hide()
            end
        end
    end

    -- ⚠ 位置**鏈式錨定**在前一顆的右緣，不是從 bar 左緣累加算出來的絕對 x。
    -- P.Size 會把寬度捨到像素格，跟我們累加用的 desiredW 差那麼一點點；
    -- 累加式定位會把這個誤差一路疊上去，跨過一個像素就在某兩塊之間露出一條縫
    -- （間距 0 卻有空隙的成因，2026-08-29 實測）。錨在右緣就由引擎保證貼齊，
    -- 誤差不會累積。
    -- 先量總寬（尺寸要先設好，GetWidth 才是捨入後的實際值），停靠時的對齊要用它
    local total = 0
    for i, tile in ipairs(shownList) do
        P.Size(tile, tile.desiredW, h)
        total = total + P.Scale(gapBefore[i]) + tile:GetWidth()
    end

    -- 停靠時內容在整寬的 bar 裡置中／靠左／靠右；起點偏移捨到像素格，
    -- 不然第一顆從半個像素開始，整條都糊
    local startX = 0
    local docked = db.dock and db.dock ~= "none"
    if docked then
        local barW = bar:GetWidth() or 0
        local align = db.dockAlign or "center"
        if align == "center" then
            startX = (barW - total) / 2
        elseif align == "right" then
            startX = barW - total
        end
        if startX < 0 then startX = 0 end
        local px = P.Scale(1)
        startX = math.floor(startX / px + 0.5) * px
    end

    for i, tile in ipairs(shownList) do
        local gap = P.Scale(gapBefore[i])
        tile:ClearAllPoints()
        if i == 1 then
            tile:SetPoint("LEFT", bar, "LEFT", startX, 0)
        else
            tile:SetPoint("LEFT", shownList[i - 1], "RIGHT", gap, 0)
        end
        tile:Show()
    end

    -- 間距 0 ＝整條融成一長條：tile 貼死之後左右隔線會疊成雙線，
    -- 中間的直向邊全部收掉、只留最外緣那兩條；上下邊本來就會連成連續線
    for i, tile in ipairs(shownList) do
        tile.edges[3]:SetShown(not merged or i == 1)
        tile.edges[4]:SetShown(not merged or i == #shownList)
    end

    if total < 1 then total = 1 end
    if docked then
        -- 停靠時寬度由兩角錨定決定（填滿整邊），SetSize 會把它打回去
        bar:SetHeight(P.Scale(h))
    else
        bar:SetSize(total, P.Scale(h))
    end
    ApplyBarChrome()
end

function ns.RequestLayout()
    if layoutQueued then return end
    layoutQueued = true
    C_Timer.After(0, function()
        layoutQueued = false
        Layout()
    end)
end

----------------------------------------------------------------------
-- 位置：CENTER 偏移存 SavedVariables（跟解析度/UI 縮放脫鉤），
-- 編輯模式拖曳來改。做法照 wow-editmode-draggable 技能。
--
-- 玩家沒拖過（db.x/db.y 為 nil）時，預設位置**跟隨官方微型選單那排**——
-- 讀 MicroMenuContainer 的中心（讀取不污染；被我們藏起來也還有 rect，
-- 錨點都在）。GetCenter 回的是框自己座標系的值，要用有效縮放換到
-- UIParent 座標才能當 CENTER 偏移。
----------------------------------------------------------------------
local function DefaultPosition()
    local c = _G.MicroMenuContainer
    if c and c.GetCenter then
        local cx, cy = c:GetCenter()
        if cx and cy then
            local scale = (c.GetEffectiveScale and c:GetEffectiveScale() or 1)
                        / UIParent:GetEffectiveScale()
            local ux, uy = UIParent:GetCenter()
            return math.floor(cx * scale - ux + 0.5), math.floor(cy * scale - uy + 0.5)
        end
    end
    return 0, -420
end

----------------------------------------------------------------------
-- 停靠：把 UIParent 往內縮一條
--
-- 整個介面（暴雪的、插件的）都錨在 UIParent 上，UIParent 自己錨在螢幕。
-- 把它的上緣往下拉一條的高度，錨在上緣的東西全部自動讓開、錨在中間的下來
-- 一半、錨在下緣的不動；編輯模式的版面是相對 UIParent 存的，會一起位移。
-- 資訊列自己則錨在 UIParent 那個邊的**外面**（父層不裁切，畫得出來）。
-- 關掉停靠就把 UIParent 放回螢幕四角，所有東西一步到位回原位，不必記任何
-- 框的原始位置。
--
-- 2026-09-05 使用者實測：進出戰鬥、進出編輯模式都不會被打回去。
-- 換解析度／改 UI 縮放沒驗證過，那兩個事件保險起見再貼一次。
--
-- ⚠ 只在需要改變時才動 UIParent：每次 ApplyAll 都 ClearAllPoints 會讓
--   所有錨在它身上的框重新結算版面，沒事別碰。
----------------------------------------------------------------------
----------------------------------------------------------------------
-- UIParent 的上緣不是我們一個人的：暴雪 Blizzard_UIParentUtil 的
-- UpdateUIParentPosition() 會把它往下推「Mac 瀏海高度」與「除錯列高度」的最大值
-- （`UIParent:SetPoint("TOPLEFT", 0, -topOffset)`），而且會在鑰石開始等時機重跑
-- ——2026-09-05 使用者實測，跑完 GetPoint 看到的就是它寫的 `-0`。
-- 所以停靠的內縮要**疊在它的偏移上**：它算出 top，我們寫 top + 一條；還原時也不是
-- 貼回 0，而是交還它算的那個值。掛勾它：它一跑完我們就補上自己的那一條。
--
-- ⚠ 只在需要改變時才動 UIParent：每次 ClearAllPoints 會讓所有錨在它身上的框
--   重新結算版面，沒事別碰。自己貼的時候 applyingInset 擋住方法掛勾，免得追著自己跑。
----------------------------------------------------------------------
local appliedDock, appliedInset = "none", 0
local applyingInset = false
local blizzTopOffset = 0      -- 暴雪最近一次算出來的上緣偏移（正值＝往下推多少）

-- 讀 UIParent 現在的 TOPLEFT 偏移（找點不用假設順序）
local function CurrentTopOffset()
    for i = 1, UIParent:GetNumPoints() do
        local point, _, _, _, y = UIParent:GetPoint(i)
        if point == "TOPLEFT" then return -(y or 0) end
    end
    return 0
end

local function DockInset()
    if not (db and db.enabled and db.dock and db.dock ~= "none" and db.dockPush) then
        return "none", 0
    end
    return db.dock, P.Scale(db.height)
end

local function ApplyInset(force)
    local side, h = DockInset()
    if not force and side == appliedDock and h == appliedInset then return end
    appliedDock, appliedInset = side, h
    applyingInset = true
    UIParent:ClearAllPoints()
    local top = blizzTopOffset + ((side == "top") and h or 0)
    local bottom = (side == "bottom") and h or 0
    UIParent:SetPoint("TOPLEFT",     nil, "TOPLEFT",     0, -top)
    UIParent:SetPoint("BOTTOMRIGHT", nil, "BOTTOMRIGHT", 0, bottom)
    applyingInset = false
end
ns.ApplyInset = ApplyInset

-- 暴雪那支跑完：記下它的值，停靠中就把自己的那一條疊回去。
-- 這是主力；下面的方法掛勾只是保險（給沒走這支函式的重設）。
if type(UpdateUIParentPosition) == "function" then
    hooksecurefunc("UpdateUIParentPosition", function()
        if applyingInset then return end
        blizzTopOffset = CurrentTopOffset()
        if appliedDock ~= "none" and db and not InCombatLockdown() then
            ApplyInset(true)
            if ns.ApplyBarPosition then ns.ApplyBarPosition() end
        end
    end)
end

local insetRepairQueued = false
local function QueueInsetRepair()
    if applyingInset or insetRepairQueued then return end
    if appliedDock == "none" then return end   -- 沒停靠就沒什麼好修
    insetRepairQueued = true
    C_Timer.After(0, function()
        insetRepairQueued = false
        if db and not InCombatLockdown() then
            ApplyInset(true)
            ns.ApplyBarPosition()
        end
    end)
end
hooksecurefunc(UIParent, "ClearAllPoints", QueueInsetRepair)
hooksecurefunc(UIParent, "SetAllPoints",   QueueInsetRepair)
hooksecurefunc(UIParent, "SetPoint",       QueueInsetRepair)

local function Docked()
    return db and db.dock and db.dock ~= "none" and db.dock or nil
end

-- 框線色，「跟底色同色就不畫」的規則在這裡：邊是疊在底色之上的，半透明時
-- 兩層 0.8 會疊成 0.96，邊緣就浮出一圈比中間更深的框——正好是「同色＝看不出
-- 有框」想避免的東西。
local function EdgeColorOrHidden()
    local r, g, b, a = EdgeColor()
    local br, bg_, bb = BgColor()
    if r == br and g == bg_ and b == bb then a = 0 end
    return r, g, b, a
end

local function ApplyEdgeColor(tile, hover)
    local edges = tile.edges
    if hover then
        local r, g, b = ns.W.Accent(1)
        for _, e in ipairs(edges) do e:SetVertexColor(r, g, b, 1) end
    elseif Docked() then
        -- 停靠時底與框線由整條 bar 畫（見 ApplyBarChrome），tile 自己的不畫，
        -- 否則兩層半透明疊在一起、tile 的區域會比空白區深一階
        for _, e in ipairs(edges) do e:SetVertexColor(0, 0, 0, 0) end
    else
        for _, e in ipairs(edges) do e:SetVertexColor(EdgeColorOrHidden()) end
    end
end

ns.ApplyEdgeColor = ApplyEdgeColor

-- 停靠時整條 bar 的底與上下框線（tile 之間的空白也要有底）。
-- 不停靠就藏起來，底由每顆 tile 自己畫（原本的樣子）。
local function ApplyBarChrome()
    if not (bar and bar.bg) then return end
    local docked = Docked() ~= nil
    bar.bg:SetShown(docked)
    if docked then bar.bg:SetVertexColor(BgColor()) end
    local r, g, b, a = EdgeColorOrHidden()
    for _, e in ipairs(bar.edges) do
        e:SetShown(docked)
        e:SetVertexColor(r, g, b, a)
    end
end

-- 換過底色／框線色之後重新套到每一顆 tile（含已經建好、現在沒顯示的）。
-- 滑鼠正停在上面的那顆維持職業色，不然拖著色票調色時焦點那顆會被抹掉。
local function ApplyColors()
    local docked = Docked() ~= nil
    for _, tile in ipairs(allTiles) do
        if tile.bg then
            local r, g, b, a = BgColor()
            tile.bg:SetVertexColor(r, g, b, docked and 0 or a)
        end
        if tile.edges then ApplyEdgeColor(tile, tile:IsMouseMotionFocus()) end
        if tile.text then tile.text:SetTextColor(TextColor()) end
    end
    ApplyBarChrome()
end

function ns.CreateTile(name, opts)
    opts = opts or {}
    local tile = CreateFrame("Button", name, bar, opts.template)
    tile.desiredW = ns.GetDB().height

    local bg = tile:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(WHITE)
    bg:SetVertexColor(BgColor())
    tile.bg = bg

    local edges = {}
    for i = 1, 4 do
        local e = tile:CreateTexture(nil, "BORDER")
        e:SetTexture(WHITE)
        edges[i] = e
    end
    edges[1]:SetPoint("TOPLEFT");    edges[1]:SetPoint("TOPRIGHT")
    edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT")
    edges[3]:SetPoint("TOPLEFT");    edges[3]:SetPoint("BOTTOMLEFT")
    edges[4]:SetPoint("TOPRIGHT");   edges[4]:SetPoint("BOTTOMRIGHT")
    local px = P.Scale(1)
    edges[1]:SetHeight(px); edges[2]:SetHeight(px)
    edges[3]:SetWidth(px);  edges[4]:SetWidth(px)
    tile.edges = edges
    ApplyEdgeColor(tile, false)

    if opts.text then
        local fs = tile:CreateFontString(nil, "OVERLAY")
        fs:SetFont(ns.LOCALE_FONT, ns.GetDB().fontSize, "")
        fs:SetPoint("CENTER")
        fs:SetJustifyH("CENTER")
        fs:SetWordWrap(false)
        fs:SetTextColor(TextColor())
        tile.text = fs
    end

    if opts.clickable then
        tile:EnableMouse(true)
        tile:RegisterForClicks("AnyUp")
        -- 底色的滑過亮階交給引擎的 highlight 貼圖（白 0.13 疊 0.115 ≈ 0.23），
        -- 職業色那半（1px 邊）走 OnEnter/OnLeave —— 跟 Chattynator 按鈕同一句話：
        -- 明暗說「它現在怎麼了」，職業色說「焦點在這」。
        tile:SetHighlightTexture(WHITE)
        local hl = tile:GetHighlightTexture()
        hl:SetVertexColor(HIGHLIGHT[1], HIGHLIGHT[2], HIGHLIGHT[3], HIGHLIGHT[4])
        tile:SetPushedTextOffset(0, 0)
        tile:HookScript("OnEnter", function(self) ApplyEdgeColor(self, true) end)
        tile:HookScript("OnLeave", function(self) ApplyEdgeColor(self, false) end)
        tile:HookScript("OnMouseDown", function(self)
            self.bg:SetVertexColor(PushedColor())
        end)
        tile:HookScript("OnMouseUp", function(self)
            self.bg:SetVertexColor(BgColor())
        end)
    else
        -- 純顯示的 tile 不吃滑鼠：資訊列不該擋住底下的遊戲畫面點擊
        tile:EnableMouse(false)
    end

    -- 文字變了才量寬、寬變了才要求重排 —— 每秒輪詢的區塊大多數 tick
    -- 在這裡就短路掉了
    function tile:SetTileText(str)
        if not self.text or self._lastText == str then return end
        self._lastText = str
        self.text:SetText(str)
        local w = math.ceil(self.text:GetStringWidth()) + PAD_X * 2
        if w ~= self.desiredW then
            self.desiredW = w
            ns.RequestLayout()
        end
    end

    function tile:ApplyFont(size)
        if self.text then
            self.text:SetFont(ns.LOCALE_FONT, size, "")
            -- 字級變了寬度也會變，重量一次
            local str = self._lastText
            self._lastText = nil
            if str then self:SetTileText(str) end
        end
    end

    allTiles[#allTiles + 1] = tile
    tile:Hide()
    return tile
end

----------------------------------------------------------------------
-- 版面：啟用中的區塊照 order 排成一列，bar 自動縮放成內容寬
----------------------------------------------------------------------
local instances = {}      -- key -> 區塊實例
ns.Instances = instances

local function EnabledInstancesInOrder()
    local list = {}
    for _, def in ipairs(ns.BLOCK_DEFS) do
        local cfg = db.blocks[def.key]
        local inst = instances[def.key]
        if cfg and cfg.enabled and inst then
            list[#list + 1] = { inst = inst, order = cfg.order or 0 }
        end
    end
    table.sort(list, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.inst.key < b.inst.key   -- 同序號用 key 決勝，重排才不會抖
    end)
    return list
end

local function Layout()
    if not bar then return end
    -- bar 是 secure 按鈕的祖先＝隱式保護框，戰鬥中的幾何變更會被封鎖；
    -- 凍結現狀，脫戰一次補齊
    if InCombatLockdown() then
        ns.Defer("layout", Layout)
        return
    end

    local h = db.height
    local blockGap = db.blockGap or BLOCK_GAP
    -- 區塊間距縮到比預設 tile 間距還小時，同區塊內的間距跟著收——
    -- 不然「區塊之間 0、按鈕之間 2」會讀成反過來的群組
    local tileGap = math.min(TILE_GAP, blockGap)
    local merged = (blockGap == 0)

    -- 先收集「要顯示的 tile ＋ 它前面該留多少間距」，再一次排出去。
    -- 分兩段是為了知道每個 tile 的前一顆是誰——鏈式錨定要用（見下）。
    local shownList, gapBefore = {}, {}
    local list = EnabledInstancesInOrder()
    for i, entry in ipairs(list) do
        local first = true
        for _, tile in ipairs(entry.inst.tiles) do
            if not tile._blockHidden then
                shownList[#shownList + 1] = tile
                -- 同區塊內用 tileGap，跨區塊用 blockGap；整條第一顆沒有前間距
                gapBefore[#shownList] = (#shownList == 1) and 0
                    or (first and blockGap or tileGap)
                first = false
            else
                tile:Hide()
            end
        end
    end

    -- ⚠ 位置**鏈式錨定**在前一顆的右緣，不是從 bar 左緣累加算出來的絕對 x。
    -- P.Size 會把寬度捨到像素格，跟我們累加用的 desiredW 差那麼一點點；
    -- 累加式定位會把這個誤差一路疊上去，跨過一個像素就在某兩塊之間露出一條縫
    -- （間距 0 卻有空隙的成因，2026-08-29 實測）。錨在右緣就由引擎保證貼齊，
    -- 誤差不會累積。
    -- 先量總寬（尺寸要先設好，GetWidth 才是捨入後的實際值），停靠時的對齊要用它
    local total = 0
    for i, tile in ipairs(shownList) do
        P.Size(tile, tile.desiredW, h)
        total = total + P.Scale(gapBefore[i]) + tile:GetWidth()
    end

    -- 停靠時內容在整寬的 bar 裡置中／靠左／靠右；起點偏移捨到像素格，
    -- 不然第一顆從半個像素開始，整條都糊
    local startX = 0
    local docked = db.dock and db.dock ~= "none"
    if docked then
        local barW = bar:GetWidth() or 0
        local align = db.dockAlign or "center"
        if align == "center" then
            startX = (barW - total) / 2
        elseif align == "right" then
            startX = barW - total
        end
        if startX < 0 then startX = 0 end
        local px = P.Scale(1)
        startX = math.floor(startX / px + 0.5) * px
    end

    for i, tile in ipairs(shownList) do
        local gap = P.Scale(gapBefore[i])
        tile:ClearAllPoints()
        if i == 1 then
            tile:SetPoint("LEFT", bar, "LEFT", startX, 0)
        else
            tile:SetPoint("LEFT", shownList[i - 1], "RIGHT", gap, 0)
        end
        tile:Show()
    end

    -- 間距 0 ＝整條融成一長條：tile 貼死之後左右隔線會疊成雙線，
    -- 中間的直向邊全部收掉、只留最外緣那兩條；上下邊本來就會連成連續線
    for i, tile in ipairs(shownList) do
        tile.edges[3]:SetShown(not merged or i == 1)
        tile.edges[4]:SetShown(not merged or i == #shownList)
    end

    if total < 1 then total = 1 end
    if docked then
        -- 停靠時寬度由兩角錨定決定（填滿整邊），SetSize 會把它打回去
        bar:SetHeight(P.Scale(h))
    else
        bar:SetSize(total, P.Scale(h))
    end
    ApplyBarChrome()
end

function ns.RequestLayout()
    if layoutQueued then return end
    layoutQueued = true
    C_Timer.After(0, function()
        layoutQueued = false
        Layout()
    end)
end

----------------------------------------------------------------------
-- 位置：CENTER 偏移存 SavedVariables（跟解析度/UI 縮放脫鉤），
-- 編輯模式拖曳來改。做法照 wow-editmode-draggable 技能。
--
-- 玩家沒拖過（db.x/db.y 為 nil）時，預設位置**跟隨官方微型選單那排**——
-- 讀 MicroMenuContainer 的中心（讀取不污染；被我們藏起來也還有 rect，
-- 錨點都在）。GetCenter 回的是框自己座標系的值，要用有效縮放換到
-- UIParent 座標才能當 CENTER 偏移。
----------------------------------------------------------------------
local function DefaultPosition()
    local c = _G.MicroMenuContainer
    if c and c.GetCenter then
        local cx, cy = c:GetCenter()
        if cx and cy then
            local scale = (c.GetEffectiveScale and c:GetEffectiveScale() or 1)
                        / UIParent:GetEffectiveScale()
            local ux, uy = UIParent:GetCenter()
            return math.floor(cx * scale - ux + 0.5), math.floor(cy * scale - uy + 0.5)
        end
    end
    return 0, -420
end

----------------------------------------------------------------------
-- 停靠：把 UIParent 往內縮一條
--
-- 整個介面（暴雪的、插件的）都錨在 UIParent 上，UIParent 自己錨在螢幕。
-- 把它的上緣往下拉一條的高度，錨在上緣的東西全部自動讓開、錨在中間的下來
-- 一半、錨在下緣的不動；編輯模式的版面是相對 UIParent 存的，會一起位移。
-- 資訊列自己則錨在 UIParent 那個邊的**外面**（父層不裁切，畫得出來）。
-- 關掉停靠就把 UIParent 放回螢幕四角，所有東西一步到位回原位，不必記任何
-- 框的原始位置。
--
-- 2026-09-05 使用者實測：進出戰鬥、進出編輯模式都不會被打回去。
-- 換解析度／改 UI 縮放沒驗證過，那兩個事件保險起見再貼一次。
--
-- ⚠ 只在需要改變時才動 UIParent：每次 ApplyAll 都 ClearAllPoints 會讓
--   所有錨在它身上的框重新結算版面，沒事別碰。
----------------------------------------------------------------------
local appliedDock, appliedInset = "none", 0
local applyingInset = false

local function DockInset()
    if not (db and db.enabled and db.dock and db.dock ~= "none" and db.dockPush) then
        return "none", 0
    end
    return db.dock, P.Scale(db.height)
end

local function ApplyInset(force)
    local side, h = DockInset()
    if not force and side == appliedDock and h == appliedInset then return end
    appliedDock, appliedInset = side, h
    applyingInset = true
    UIParent:ClearAllPoints()
    if side == "top" then
        UIParent:SetPoint("TOPLEFT",     nil, "TOPLEFT",     0, -h)
        UIParent:SetPoint("BOTTOMRIGHT", nil, "BOTTOMRIGHT", 0, 0)
    elseif side == "bottom" then
        UIParent:SetPoint("TOPLEFT",     nil, "TOPLEFT",     0, 0)
        UIParent:SetPoint("BOTTOMRIGHT", nil, "BOTTOMRIGHT", 0, h)
    else
        UIParent:SetAllPoints(nil)
    end
    applyingInset = false
end
ns.ApplyInset = ApplyInset

-- ⚠ 鑰石開始（CHALLENGE_MODE_START）那一刻 UIParent 的錨點會被放回螢幕四角——
-- 2026-09-05 使用者實測；資訊列還錨在縮出來的那條上，被夾回螢幕頂端壓在小地圖上。
-- 戰鬥與編輯模式不會。誰重設的沒查到，所以不猜事件，直接掛在 UIParent 的錨點方法上。
-- 兩道保險：(1) 進世界強制重貼；(2) 掛勾 UIParent 的錨點重設，不管是誰放回去的，
-- 下一幀再貼一次。自己貼的時候用 applyingInset 擋住，免得掛勾追著自己跑。
local insetRepairQueued = false
local function QueueInsetRepair()
    if applyingInset or insetRepairQueued then return end
    if appliedDock == "none" then return end   -- 沒停靠就沒什麼好修
    insetRepairQueued = true
    C_Timer.After(0, function()
        insetRepairQueued = false
        if db and not InCombatLockdown() then
            ApplyInset(true)
            ns.ApplyBarPosition()
        end
    end)
end
hooksecurefunc(UIParent, "ClearAllPoints", QueueInsetRepair)
hooksecurefunc(UIParent, "SetAllPoints",   QueueInsetRepair)
hooksecurefunc(UIParent, "SetPoint",       QueueInsetRepair)

local function ApplyPosition()
    if not bar or InCombatLockdown() then return end
    local side = Docked()
    if side then
        -- 有推開（UIParent 已內縮）就錨在它外面那一條；沒推開就貼在它裡面的邊上
        local h = db.dockPush and P.Scale(db.height) or 0
        bar:ClearAllPoints()
        if side == "top" then
            bar:SetPoint("TOPLEFT",  UIParent, "TOPLEFT",  0, h)
            bar:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, h)
        else
            bar:SetPoint("BOTTOMLEFT",  UIParent, "BOTTOMLEFT",  0, -h)
            bar:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, -h)
        end
        return
    end
    local x, y = db.x, db.y
    if x == nil or y == nil then
        x, y = DefaultPosition()
    end
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

ns.ApplyBarPosition = ApplyPosition

local function SavePosition()
    local cx, cy = UIParent:GetCenter()
    local fx, fy = bar:GetCenter()
    if not (cx and fx) then return end
    db.x = math.floor(fx - cx + 0.5)
    db.y = math.floor(fy - cy + 0.5)
end

----------------------------------------------------------------------
-- 編輯模式拖曳
--
-- 不用 StartMoving：實測在「保護框＋編輯模式」這條路上拖不動，套組裡
-- 真正在動的實作（MiliUI_DamageMeters 的 Meter/Move.lua）也是自己算——
-- 記下按下那一刻的游標與框位置，拖曳中每幀用游標差值 ClearAllPoints/
-- SetPoint 重定位（OOC 對保護框合法，編輯模式必然 OOC）。driver 只在
-- 拖曳中存在 OnUpdate，平常零成本。
----------------------------------------------------------------------
local editSelection
local isInEditMode = false
local dragState
local dragDriver

local function EndBarDrag()
    if not dragState then return end
    dragState = nil
    if dragDriver then dragDriver:Hide() end
    SavePosition()
    ApplyPosition()
end

local function DragTick()
    local d = dragState
    if not d then return end
    -- 有些情況收不到 OnDragStop（滑鼠移出視窗、被別的框吃掉），自己確認一次
    if not IsMouseButtonDown("LeftButton") or InCombatLockdown() then
        EndBarDrag()
        return
    end
    local scale = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    local dx, dy = cx / scale - d.cx, cy / scale - d.cy
    local pl, pt = UIParent:GetLeft(), UIParent:GetTop()
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", (d.left + dx) - pl, (d.top + dy) - pt)
end

local function BeginBarDrag()
    if not bar or InCombatLockdown() then return end
    if Docked() then return end   -- 停靠中位置由邊決定，拖了也會被貼回去
    local left, top = bar:GetLeft(), bar:GetTop()
    if not (left and top) then return end
    local scale = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    dragState = { cx = cx / scale, cy = cy / scale, left = left, top = top }
    if not dragDriver then
        dragDriver = CreateFrame("Frame")
        dragDriver:Hide()
        dragDriver:SetScript("OnUpdate", DragTick)
    end
    dragDriver:Show()
end

-- 選取框在 EnsureBar 就先建好（不要等進了編輯模式才建——在暴雪的 OnShow
-- 執行路徑裡建框是沒驗證過的時序，套組裡在動的實作全都是開檔就建）。
-- 模板建立包 pcall：DamageMeters 的實作就是這樣防的，建不出來就自己畫一個
-- 藍框頂著，拖曳照常。
local function EnsureEditSelection()
    if editSelection or not bar then return end
    local ok, sel = pcall(CreateFrame, "Frame", nil, bar, "EditModeSystemSelectionTemplate")
    if ok and sel then
        -- ⚠ 模板的 XML 綁了 OnMouseDown → EditModeManagerFrame:SelectSystem(self.parent)。
        -- 我們不是真的 Edit Mode 系統，讓它跑下去就是把 bar 塞進暴雪的選取流程
        -- （報錯＋染污編輯模式）。點一下不拖曳的行為改成 no-op。
        sel:SetScript("OnMouseDown", function() end)
        sel.system = {
            GetSystemName = function() return L["BAR_NAME"] end,
        }
    else
        sel = CreateFrame("Frame", nil, bar, "BackdropTemplate")
        sel:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = P.Scale(1) })
        sel:SetBackdropColor(0.25, 0.6, 1, 0.15)
        sel:SetBackdropBorderColor(0.25, 0.6, 1, 0.9)
        sel:EnableMouse(true)
        sel.ShowHighlighted = sel.Show
        sel.isFallback = true
    end
    sel:SetAllPoints(bar)
    sel:Hide()
    sel:RegisterForDrag("LeftButton")
    sel:SetScript("OnDragStart", BeginBarDrag)
    sel:SetScript("OnDragStop", EndBarDrag)
    editSelection = sel
end

----------------------------------------------------------------------
-- 設定視窗開著時的搬家遮罩（跟編輯模式是兩套視覺，這套是職業色）
--
-- 照 MiliUI_Minimap 的約定：開設定多半就是要調位置，直接蓋一層
-- 「拖曳移動」的遮罩，左鍵拖、右鍵回預設位置。遮罩蓋在所有 tile 上面，
-- 順便擋掉誤點 secure 按鈕。它是保護框的子層，Show/Hide 走 ns.Defer。
----------------------------------------------------------------------
local settingsOverlay

local function EnsureSettingsOverlay()
    if settingsOverlay or not bar then return end
    local o = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    o:SetAllPoints(bar)
    o:SetFrameLevel(bar:GetFrameLevel() + 50)
    o:EnableMouse(true)
    o:RegisterForDrag("LeftButton")
    o:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = P.Scale(1) })
    local r, g, b = ns.W.Accent(1)
    o:SetBackdropColor(r, g, b, 0.18)
    o:SetBackdropBorderColor(r, g, b, 0.9)
    local label = o:CreateFontString(nil, "OVERLAY")
    label:SetFont(ns.LOCALE_FONT, 12, "OUTLINE")
    label:SetPoint("CENTER")
    label:SetText(L["DRAG_LABEL"])
    o.label = label
    o:SetScript("OnDragStart", BeginBarDrag)
    o:SetScript("OnDragStop", EndBarDrag)
    -- 右鍵叫回預設位置（跟小地圖同一套約定：拖到看不見是必然會發生的意外）
    o:SetScript("OnMouseUp", function(_, btn)
        if btn ~= "RightButton" then return end
        db.x, db.y = nil, nil
        ApplyPosition()
    end)
    o:Hide()
    settingsOverlay = o
end

-- Options/Panel.lua 的 OnShow/OnHide 呼叫這個
function ns.SetBarMoveOverlayShown(shown)
    if shown and not (db and db.enabled and bar) then return end
    ns.Defer("move-overlay", function()
        if shown and bar then
            EnsureSettingsOverlay()
            if settingsOverlay then
                settingsOverlay.label:SetText(Docked() and L["DOCKED_LABEL"] or L["DRAG_LABEL"])
                settingsOverlay:Show()
            end
        elseif settingsOverlay then
            EndBarDrag()
            settingsOverlay:Hide()
        end
    end)
end

local function UpdateEditModeState()
    if isInEditMode and db and db.enabled and bar then
        EnsureEditSelection()
        editSelection:ShowHighlighted()
    elseif editSelection then
        -- 編輯模式被戰鬥強制關閉時這裡可能已在 lockdown，Hide 保護子框會被封鎖
        ns.Defer("editsel-hide", function()
            if not isInEditMode and editSelection then editSelection:Hide() end
        end)
    end
end

-- 三層掛勾：檔案層 → Blizzard_EditMode 載入時 → PLAYER_LOGIN 保底
local editModeHooked = false
local function OnEditModeEnter()
    isInEditMode = true
    UpdateEditModeState()
end
local function OnEditModeExit()
    isInEditMode = false
    UpdateEditModeState()
    -- 編輯模式會把被我們藏起來的暴雪微型選單重新 Show 出來，
    -- 離開時強制重推一次 hider 修回去
    if ns.MicroMenu then ns.MicroMenu.UpdateBlizzardHidden(true) end
end

local function HookEditMode()
    if editModeHooked then return end
    if not EditModeManagerFrame then return end
    editModeHooked = true
    EditModeManagerFrame:HookScript("OnShow", OnEditModeEnter)
    EditModeManagerFrame:HookScript("OnHide", OnEditModeExit)
    -- 第三重訊號：直接掛在方法上。只要編輯模式真的啟動，EnterEditMode 一定
    -- 執行——不管管理視窗的 Show/Hide 或 EventRegistry 的派送有什麼時序妖
    if EditModeManagerFrame.EnterEditMode then
        hooksecurefunc(EditModeManagerFrame, "EnterEditMode", OnEditModeEnter)
    end
    if EditModeManagerFrame.ExitEditMode then
        hooksecurefunc(EditModeManagerFrame, "ExitEditMode", OnEditModeExit)
    end
    if EditModeManagerFrame:IsShown() then
        OnEditModeEnter()
    end
end

HookEditMode()
if not editModeHooked and EventUtil and EventUtil.ContinueOnAddOnLoaded then
    EventUtil.ContinueOnAddOnLoaded("Blizzard_EditMode", HookEditMode)
end

-- 官方訊號：EnterEditMode/ExitEditMode 內部就會發這兩個 EventRegistry 事件
-- （Blizzard_EditMode/Shared/EditModeManager.lua），不依賴管理視窗的
-- Show/Hide 時序。跟上面的掛勾並存，全部冪等，誰先到都一樣。
if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("EditMode.Enter", OnEditModeEnter, "MiliUIInfoBar")
    EventRegistry:RegisterCallback("EditMode.Exit", OnEditModeExit, "MiliUIInfoBar")
end

----------------------------------------------------------------------
-- /mib debug：編輯模式整合的現場診斷
----------------------------------------------------------------------
function ns.PrintDebug()
    local function onoff(v) return v and "是" or "否" end
    print(ns.PREFIX_COLOR .. "MiliUI_InfoBar debug|r")
    print("  EditModeManagerFrame：" .. (EditModeManagerFrame and "存在" or "nil")
        .. (EditModeManagerFrame and (EditModeManagerFrame:IsShown() and "／顯示中" or "／隱藏") or ""))
    print("  掛勾完成：" .. onoff(editModeHooked) .. "　編輯模式中：" .. onoff(isInEditMode))
    if editSelection then
        print("  選取框：" .. (editSelection.isFallback and "備援自畫框" or "官方模板")
            .. (editSelection:IsShown() and "／顯示中" or "／隱藏")
            .. "　尺寸 " .. math.floor((editSelection:GetWidth() or 0) + 0.5)
            .. "x" .. math.floor((editSelection:GetHeight() or 0) + 0.5)
            .. "　level " .. editSelection:GetFrameLevel()
            .. "　strata " .. tostring(editSelection:GetFrameStrata()))
    else
        print("  選取框：nil（沒建立）")
    end
    print("  資訊列：" .. (bar and "存在" or "nil")
        .. (bar and (bar:IsShown() and "／顯示中" or "／隱藏") or ""))
    if ns.MicroMenu and ns.MicroMenu.DebugInfo then
        ns.MicroMenu.DebugInfo()
    end
end

----------------------------------------------------------------------
-- Bar 本體
----------------------------------------------------------------------
local function EnsureBar()
    if bar then return end
    bar = CreateFrame("Frame", "MiliUIInfoBar", UIParent)
    bar:SetFrameStrata("MEDIUM")
    bar:SetMovable(true)
    bar:SetUserPlaced(false)
    bar:SetClampedToScreen(true)
    P.Size(bar, 100, db.height)
    ns.BarFrame = bar

    -- 整條的底與上下左右 1px 框線：只在停靠時顯示（ApplyBarChrome）
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetTexture(WHITE)
    bar.bg:Hide()
    bar.edges = {}
    for i = 1, 4 do
        local e = bar:CreateTexture(nil, "BORDER")
        e:SetTexture(WHITE)
        e:Hide()
        bar.edges[i] = e
    end
    bar.edges[1]:SetPoint("TOPLEFT");    bar.edges[1]:SetPoint("TOPRIGHT")
    bar.edges[2]:SetPoint("BOTTOMLEFT"); bar.edges[2]:SetPoint("BOTTOMRIGHT")
    bar.edges[3]:SetPoint("TOPLEFT");    bar.edges[3]:SetPoint("BOTTOMLEFT")
    bar.edges[4]:SetPoint("TOPRIGHT");   bar.edges[4]:SetPoint("BOTTOMRIGHT")
    local px = P.Scale(1)
    bar.edges[1]:SetHeight(px); bar.edges[2]:SetHeight(px)
    bar.edges[3]:SetWidth(px);  bar.edges[4]:SetWidth(px)

    -- 停靠時寬度是兩角錨定算出來的，第一次排版時可能還是 0；寬一變就重排
    bar:SetScript("OnSizeChanged", function(self, w)
        if self._lastW == w then return end
        self._lastW = w
        if db and db.dock and db.dock ~= "none" then ns.RequestLayout() end
    end)

    ApplyPosition()
    EnsureEditSelection()
    EnsureSettingsOverlay()

    -- 寵物對戰接管畫面時只降 alpha：bar 是保護框，戰鬥中 Hide 會被封鎖，
    -- SetAlpha 永遠合法。OVER 與 CLOSE 都要接（誰後到依勝負而定，處理冪等）。
    ns.Events.Register("PET_BATTLE_OPENING_START", "bar", function() bar:SetAlpha(0) end)
    ns.Events.Register("PET_BATTLE_OVER",  "bar", function() bar:SetAlpha(1) end)
    ns.Events.Register("PET_BATTLE_CLOSE", "bar", function() bar:SetAlpha(1) end)
end

----------------------------------------------------------------------
-- ApplyAll：設定變更後的唯一入口（建實例、同步啟用狀態、重排）
----------------------------------------------------------------------
function ns.ApplyAll()
    ns.InitDB()
    -- secure 按鈕的建立與 Show/Hide 都是戰鬥違禁品，整包延到脫戰
    if InCombatLockdown() then
        ns.Defer("applyall", ns.ApplyAll)
        return
    end

    if not db.enabled then
        if bar then bar:Hide() end
        for _, inst in pairs(instances) do
            if inst.Disable then inst:Disable() end
        end
        ns.Poll.SetEnabled(false)
        if ns.MicroMenu then ns.MicroMenu.UpdateBlizzardHidden() end
        ApplyInset()          -- 關掉資訊列就把 UIParent 放回去
        UpdateEditModeState()
        return
    end

    EnsureBar()
    ns.Poll.SetEnabled(true)

    for _, def in ipairs(ns.BLOCK_DEFS) do
        local cfg = db.blocks[def.key]
        local factory = ns.Blocks and ns.Blocks[def.key]
        if cfg and cfg.enabled and factory then
            local inst = instances[def.key]
            if not inst then
                inst = factory.create()
                inst.key = def.key
                instances[def.key] = inst
            end
            if inst.Enable then inst:Enable() end
            for _, tile in ipairs(inst.tiles) do
                tile:ApplyFont(db.fontSize)
            end
            if inst.Update then xpcall(inst.Update, ns.ReportError, inst) end
        else
            local inst = instances[def.key]
            if inst then
                if inst.Disable then inst:Disable() end
                for _, tile in ipairs(inst.tiles) do tile:Hide() end
            end
        end
    end

    if ns.MicroMenu then ns.MicroMenu.UpdateBlizzardHidden() end
    ApplyColors()
    ApplyInset()              -- 先縮 UIParent，資訊列再錨到縮出來的那條上
    ApplyPosition()
    Layout()
    bar:Show()
    if settingsOverlay and settingsOverlay:IsShown() then
        settingsOverlay.label:SetText(Docked() and L["DOCKED_LABEL"] or L["DRAG_LABEL"])
    end
    UpdateEditModeState()
end

----------------------------------------------------------------------
-- 還原全部設定（設定 > 關於）
--
-- ⚠ 必須**原地清空**這張表，不能 `MiliUI_InfoBar_DB = {}`：上面的 `db`
-- 拿著舊表的參照，換新表等於整支插件從此讀不到玩家的設定。
----------------------------------------------------------------------
function ns.ResetDB()
    ns.InitDB()
    -- 戰隊資訊的角色記錄是資料不是設定，還原預設值不該把它清掉；
    -- 遷移印記也在同一張表裡，清了下次登入又會從 MiliUI_DB 搬一次舊記錄回來
    local warband = db.warband
    wipe(db)
    CopyDefaults(ns.DB_DEFAULTS, db)
    if type(warband) == "table" then db.warband = warband end
    db.posVersion = 2       -- 位置遷移已經是最新格式，別讓它再跑一次
    ns.ApplyAll()
end

----------------------------------------------------------------------
-- 啟動
----------------------------------------------------------------------
ns.Events.Register("PLAYER_REGEN_ENABLED", "defer", FlushDeferred)
ns.Events.Register("PLAYER_LOGIN", "boot", function()
    ns.InitDB()
    HookEditMode()
    -- 登入時暴雪的 UpdateUIParentPosition 早就跑過了，掛勾接不到那次：
    -- 現在的 TOPLEFT 偏移就是它的值（我們還沒動過 UIParent）
    blizzTopOffset = CurrentTopOffset()
    ns.ApplyAll()
end)
-- 載入畫面會重置一些外部狀態（暴雪那排的可見度），進世界後強制重推一次。
-- 沒拖過的預設位置也在這裡重算：登入那一刻 MicroMenuContainer 的 rect
-- 不一定就緒，進世界後 Edit Mode 版面已套完，讀得到正確位置。
-- 外力把 UIParent 的錨點重設之後把內縮貼回去：當下一次、0.5 秒後再一次保險
-- （暴雪套版面的時機不保證在我們之前）。使用者實測會重設的時機：鑰石開始
--（CHALLENGE_MODE_START）；載入畫面保險起見一起接。
local function RepairInset()
    if not (db and db.dock and db.dock ~= "none") then return end
    if not InCombatLockdown() then ApplyInset(true); ApplyPosition() end
    C_Timer.After(0.5, function()
        if db and not InCombatLockdown() then ApplyInset(true); ApplyPosition() end
    end)
end

ns.Events.Register("PLAYER_ENTERING_WORLD", "bar-repair", function()
    if ns.MicroMenu then ns.MicroMenu.UpdateBlizzardHidden(true) end
    if db and (db.x == nil or db.y == nil) then ApplyPosition() end
    RepairInset()
end)
ns.Events.Register("CHALLENGE_MODE_START", "dock-inset", RepairInset)
ns.Events.Register("ZONE_CHANGED_NEW_AREA", "dock-inset", RepairInset)
-- 停靠的內縮量是像素換算的，縮放或解析度一變就要重貼（順便防暴雪重設 UIParent）
ns.Events.Register("UI_SCALE_CHANGED",    "dock-inset", function() if db then ApplyInset(true); ApplyPosition() end end)
ns.Events.Register("DISPLAY_SIZE_CHANGED", "dock-inset", function() if db then ApplyInset(true); ApplyPosition() end end)
