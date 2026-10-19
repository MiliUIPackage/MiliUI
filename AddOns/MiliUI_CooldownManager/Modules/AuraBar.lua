------------------------------------------------------------
-- 引擎寫層數的光環條：一顆單格 AuraContainer ＋ 交給按鈕的 StatusBar
--
-- 給「光環層數讀不到」的列用（自訂格子的層數列、資源條的 auraBar 資源）：
-- GetPlayerAuraBySpellID 在首領戰／M+ 常回 nil 或秘密值，有些增益（沒被標成可讀的）連戰鬥外都讀不到。
-- 這裡不讀：
--   CreateFrame("AuraContainer", …, "CustomAuraContainerTemplate") → SetUnit("player") →
--   AddAuraSlot(…, "HELPFUL", { candidateFilters = { includeSpellIDs = … }, initializeFrame = … }) →
--   SetEnabled(true)
-- initializeFrame 裡建一條**整列寬**的 StatusBar 交給按鈕的 SetApplicationBar(bar, { maxApplications })：
-- 引擎在安全端把光環的層數寫進去（光環消失寫 0），戰鬥中、受限內容裡都一樣，插件端零讀取。
-- （玩家自己的增益用 spellID 過濾不受身分閘限制。）
--
-- 另一種 kind = "instances"：每施放一次就多一顆**獨立的**光環（各自計時、層數欄是 0，例如鐵鬃）。
-- 這種用 AddAuraGroup（maxFrameCount ＝ 格數、layout 的 elementWidth／Height／Spacing ＝ 一格的大小與格距）：
-- 引擎有幾顆光環就排幾個按鈕，一格一顆；每顆按鈕的 StatusBar 交給 SetDurationBar(bar, { direction =
-- RemainingTime })，剩餘時間由引擎倒著跑。
--
-- 第三種 kind = "duration"：**光環剩餘時間條**（資源條的 auraTimer 列）。單格 AddAuraSlot，按鈕的整列寬 StatusBar
-- 交給 SetDurationBar(bar, { direction = RemainingTime })：光環在身上時由引擎往下縮，光環不在時按鈕藏起來
-- （列上的裝飾畫空條）。要秒數時另建一個 FontString 交給 SetDurationText（formatter 在容器建立前先建好）。
-- 上限秒數不必知道：引擎用光環自己的持續時間（含延長）。
-- 秒數可以換成「剩幾個 GCD」（text.gcd）：數字格式器每 GCD 一段（Core/Text.lua 的 GcdFormatter），
-- GCD 長度進簽章。
--
-- 自訂列（Modules/CustomBars.lua）也走 duration：秒數可以靠左／靠右（text.point／pad）、低秒變色交給
-- SetDurationText 的 textColor 色彩曲線（text.low；曲線在容器建立前先建好）、層數靠左／右（count.point）、
-- 層數不給格式器（count.plain：一般增益沒有層數，給 "%d" 會印 0）；「只在生效時顯示」的列連名字與圖示都建在
-- 按鈕子樹裡（spec.label：純字串／純檔案編號，initializeFrame 裡 SetText／SetTexture 不讀任何值）。
--
-- applications 也可以帶層數文字（spec.count）：FontString 交給 SetApplicationCount(fs, {})，
-- **不給格式器**（引擎拿格式器處理秘密層數會整顆容器壞掉），要接單位（例如「%」）另建一顆固定字的
-- FontString 貼在旁邊（無視苦痛的百分比條）。兩顆都錨在按鈕中線上，不互相錨定（層數那顆的字是秘密值）。
--
-- 格子外觀（每格的暗底、邊框（預設 1px 黑；粗細／顏色走 geom.px／geom.edge）、格與格之間的分隔、邊緣陰影（geom.shadow））
-- 是另外畫的「裝飾」：
--   * 一直顯示的列：裝飾畫在列上（不在按鈕子樹裡），尺寸變了原地重排，不必換容器
--   * 「有光環才顯示」的列：裝飾也建在按鈕子樹裡（按鈕只在有光環時顯示 ⇒ 整列跟著出現），
--     裝飾的幾何進簽章
-- 整列寬的填色跨過格距：第 k 層的填色終點落在第 k 個格距裡（W·k/n 與格子邊界差 gap·(1-k/n) < gap），
-- 格距 > 0 時填色貼圖在 initializeFrame 掛 REPEAT 遮罩把格距挖掉（AB.MaskPlan），格距跟點數型一樣透出世界、
-- 裝飾不畫分隔；掛不上遮罩（引擎不支援）才畫不透明的暗底色分隔把它蓋住。
--
-- 12.1 的硬規矩（跟 Modules/Custom.lua 的光環格同一套）：
--   * 容器是受保護的 intrinsic：它所在的列、面板容器（保護沿父層／錨點鏈往上傳）戰鬥中都不能
--     SetPoint／SetSize／Show／Hide ⇒ 用這支的模組在戰鬥中不重排（記旗標、脫戰補），容器層的寫入走 ns.Write
--   * 戰鬥中建 AuraContainer 會不可攔截地報錯 ⇒ 戰鬥中只記帳，PLAYER_REGEN_ENABLED 再建
--   * 樣式只能在 initializeFrame 裡烘 ⇒ 影響外觀的設定進**簽章**，變了換一顆容器；容器依簽章池化在
--     持有框上（frame 刪不掉，舊的 Hide 留著、改回來直接拿回去）
--   * initializeFrame 整段 xpcall、不 CreateColor、不掛 script、顏色一律純數字
--   * 容器不掛任何 script（forbidden）；重新可見時的補踢掛在自己的持有框上
--   * 讀不到按鈕顯不顯示、讀不到層數：沒有「0 層時做什麼」的 Lua 分支
------------------------------------------------------------
local _, ns = ...

-- 關掉貼圖的像素貼齊（Core/Media.lua 的 ns.NoSnap；離線測試沒載 Media 時是空操作）
local function NoSnap(t) if ns.NoSnap then ns.NoSnap(t) end return t end

ns.AuraBar = {}
local AB = ns.AuraBar

local SOLID = "Interface\\BUTTONS\\WHITE8X8"

local pending = {}          -- handle → true（戰鬥中要建／換容器）
AB.builds = 0
AB.lastError = nil

local function Fmt(v) return string.format("%.3f", tonumber(v) or 0) end

------------------------------------------------------------
-- 裝飾（格子外觀）：純函式算幾何，離線測得到
------------------------------------------------------------
-- 回傳 { cells = { { x, w }, … }, gaps = { { x, w }, … } }（x 從左緣量；reversed 時由呼叫端鏡像）
--
-- pixel（1 實體像素的 UI 單位，ns.P.Pixel(1)）給了就貼實體像素：
--   * 第 k 格的右界貼著引擎的填色終點 W·k/n：有格距時右界只能落在 [終點−gp, 終點] 的整數裡（分隔那 gp 個像素
--     要蓋住終點），這個範圍裡挑最接近等分格界 k·segW+(k−1)·gp 的那個（格距 ≥2 時才有得挑，格寬才不會頭一格多出
--     一截）；格距 0 取 ceil（終點落在這格右邊那條 1px 邊裡）。分隔／邊一定蓋得住填色的尾巴、不留半像素的亮縫
--   * 分隔一律整數個像素寬、落在整數像素上；格寬最多差 1px、最後一格右緣剛好 W（格寬不到 gp+1 像素的
--     退化情況只保證不出錯、不重疊）
--   不給（離線測試、舊呼叫）＝ 等分的浮點幾何。等分時分隔的 x 是 (i-1)·(W+gap)/n：
--   W+gap 不是 n 的倍數時每條分隔的小數部位從左到右線性累積，中段那幾條剛好卡在半像素上、糊成兩個像素
--   （秘法齊射 25 格：玩家回報「中間那條黑線比別的粗很多」，2026-10-12）
function AB.Geometry(W, n, gap, segW, pixel)
    local out = { cells = {}, gaps = {} }
    n = math.max(1, math.floor(tonumber(n) or 1))
    gap = tonumber(gap) or 0
    pixel = tonumber(pixel)
    if pixel and pixel > 0 then
        local Wp = math.floor(W / pixel + 0.5)
        local gp = math.floor(gap / pixel + 0.5)
        if gp < 0 then gp = 0 end
        local segW = (Wp - gp * (n - 1)) / n           -- 等分的格寬（像素，浮點）
        local left = 0
        for i = 1, n do
            local right
            if i == n then
                right = Wp
            else
                local f = Wp * i / n                    -- 引擎的填色終點（第 i 層）
                if gp > 0 then
                    local lo, hi = math.ceil(f - gp), math.floor(f)
                    right = math.floor(i * segW + (i - 1) * gp + 0.5)
                    if right < lo then right = lo elseif right > hi then right = hi end
                else
                    right = math.ceil(f)
                end
                if right < left then right = left end
            end
            out.cells[i] = { x = left * pixel, w = (right - left) * pixel }
            if i < n and gp > 0 then out.gaps[i] = { x = right * pixel, w = gp * pixel } end
            left = right + gp
        end
        return out
    end
    if not segW then segW = (W - gap * (n - 1)) / n end
    for i = 1, n do
        local x = (i - 1) * (segW + gap)
        out.cells[i] = { x = x, w = segW }
        if i < n and gap > 0 then out.gaps[i] = { x = x + segW, w = gap } end
    end
    return out
end

------------------------------------------------------------
-- 分段的透明格距：填色貼圖的遮罩（applications 專用）
--
-- 引擎的填色是整列寬連續的一條 StatusBar，格距底下一定有填色；要讓格距像點數型那樣透出世界，只能在
-- initializeFrame 給填色貼圖掛 MaskTexture 把格距挖掉。一張遮罩只有一個矩形，24 個格距用 REPEAT：遮罩寬＝一格的
-- 節距（格寬＋格距）、貼圖「左邊不透明、右端一截透明」橫向 REPEAT，矩形外照樣重複 ⇒ 每個節距挖掉同一截。
-- 透明那截佔節距的比例是貼圖的屬性（SetTexCoord 改不了：窗口縮放連週期一起縮），所以 Media/segmask-<den>.png
-- 一家子是 1/den；比例落在 1/den 與 2/den 之間時再疊一張同圖左移 s 的遮罩，兩張透明區的聯集剛好是要的寬。
-- 挖的寬度比格距多 1 實體像素（兩側各半）：格距的黑邊貼像素、遮罩節距是浮點，誤差藏在邊底下。
-- 跨框遮罩沒有文件依據（Core/Shape.lua 同一條），遮罩建在按鈕上 ⇒ 幾何進簽章，列寬／格距變了換容器。
-- 貼圖由 .claude/skills/miliui-cdm-segment-masks 的腳本產生，den 清單兩邊要一致。
-- （2026-10-12 秘法齊射 25 格回報：格距 2 時分隔是 4px 實心黑，點數型同設定是「邊＋透出世界＋邊」）
------------------------------------------------------------
local MASK_DENS = { 2, 4, 8, 16, 32, 64, 128 }
local MASK_FILE = "Interface\\AddOns\\MiliUI_CooldownManager\\Media\\segmask-%d.png"
AB.MASK_DENS = MASK_DENS
function AB.MaskFile(den) return MASK_FILE:format(den) end

-- period ＝ 節距（格寬＋格距）、gapW ＝ 要挖的寬（格距＋1 實體像素）、pixel ＝ 1 實體像素（兩側各放半個）
-- → { { den, x, w }, … }：x ＝ 遮罩左緣相對條左緣（填充反向時相對右緣、往外為正）、w ＝ 遮罩寬＝節距。
-- 第一張的透明段貼在節距尾端、第二張（需要時）左移 s。挖不了（比例 ≥ 1、節距 0）⇒ nil。
-- 比例比 1/最大 den 還小（節距很長、格距 1px）：單張、挖得比要的寬一點（< 節距/128）
function AB.MaskPlan(period, gapW, pixel)
    period, gapW = tonumber(period) or 0, tonumber(gapW) or 0
    if period <= 0 or gapW <= 0 or gapW >= period then return nil end
    local r = gapW / period
    local den = MASK_DENS[#MASK_DENS]
    for _, d in ipairs(MASK_DENS) do
        if 1 / d <= r then den = d; break end
    end
    local half = (tonumber(pixel) or 0) / 2
    local plan = { { den = den, x = half, w = period } }
    local s = (r - 1 / den) * period
    if s > 1e-6 then plan[2] = { den = den, x = half - s, w = period } end
    return plan
end

-- 在 parent 上建一組裝飾貼圖（暗底 BACKGROUND、黑邊與分隔在 overlay 子框上）。
-- anchor：幾何的基準框（列本身或按鈕）
local function NewDecor(parent)
    local d = { parent = parent, bgs = {}, edges = {}, seps = {}, shadows = {} }
    local ov = CreateFrame("Frame", nil, parent)
    ov:SetAllPoints(parent)
    d.overlay = ov
    return d
end

local function Tex(pool, i, parent, layer)
    local t = pool[i]
    if not t then
        t = NoSnap(parent:CreateTexture(nil, layer))
        t:SetTexture(SOLID)
        pool[i] = t
    end
    return t
end

-- geom = { W, H, n, gap, segW, reversed, segments, dim = { r, g, b, a }, px（邊框粗細，UI 單位；0 ＝ 不畫邊框；沒給 ＝ 1）,
--          edge = { r, g, b, a }（邊框與分隔的顏色；沒給 ＝ 不透明黑）, bgTex（暗底的材質，nil ＝ 純色）,
--          shadow = { px, alpha, l, r, under } | nil（邊緣陰影，Core/Shape.lua：px 實體像素、alpha 不透明度；
--                   l／r ＝ 只有一圈時往左／右多圍多少（版面單位，自訂列把圖示也圍進去）；under ＝ 層級照哪個框減一，省略＝裝飾的父框） }
-- 1 實體像素的 UI 單位（分段幾何貼像素用）；讀不到 ⇒ nil（等分的浮點幾何）
local function PixelUnit()
    local P = ns.P
    local v = P and P.Pixel and P.Pixel(1)
    return (type(v) == "number" and v > 0) and v or nil
end

local function LayoutDecor(d, anchor, geom)
    -- 分段貼實體像素（AB.Geometry 的 pixel）。一顆光環一格（instances）不貼：那些格是引擎的流式排版照 segW 等分放的，
    -- 裝飾要跟它對齊
    local g = AB.Geometry(geom.W, geom.segments and geom.n or 1, geom.segments and geom.gap or 0,
        geom.segments and geom.segW or geom.W, (geom.segments and not geom.instances) and PixelUnit() or nil)
    local px = tonumber(geom.px) or 1
    local H = geom.H
    local dim = geom.dim
    local ec = geom.edge
    local er, eg, eb, ea = 0, 0, 0, 1
    if type(ec) == "table" then er, eg, eb, ea = ec[1] or 0, ec[2] or 0, ec[3] or 0, ec[4] or 1 end
    local function Place(t, x, w, y, h)
        t:ClearAllPoints()
        if geom.reversed then
            t:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -x, -y)
        else
            t:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, -y)
        end
        t:SetSize(w, h)
        t:Show()
    end
    local nb, ne, ns2 = 0, 0, 0
    -- 間距 0：第 2 格起不畫左邊，跟前一格的右邊共用，否則交界是並排的 2px
    local shared = geom.segments and (tonumber(geom.gap) or 0) <= 0
    for ci, c in ipairs(g.cells) do
        nb = nb + 1
        local bg = Tex(d.bgs, nb, d.parent, "BACKGROUND")
        bg:SetTexture(geom.bgTex or SOLID)
        bg:SetVertexColor(dim[1], dim[2], dim[3], dim[4])
        Place(bg, c.x, c.w, 0, H)
        -- 邊框：上下左右各一條（疊在填色之上）；粗細 0 ＝ 不畫
        local skipLeft = shared and ci > 1
        for side = 1, 4 do
            if px > 0 and (side ~= 3 or not skipLeft) then
                ne = ne + 1
                local e = Tex(d.edges, ne, d.overlay, "OVERLAY")
                e:SetVertexColor(er, eg, eb, ea)
                if side == 1 then Place(e, c.x, c.w, 0, px)
                elseif side == 2 then Place(e, c.x, c.w, H - px, px)
                elseif side == 3 then Place(e, c.x, px, 0, H)
                else Place(e, c.x + c.w - px, px, 0, H) end
            end
        end
    end
    -- 分隔：格距有遮罩（geom.mask，填色在格距被挖掉）就不畫，格距像點數型一樣透出世界。
    -- 沒遮罩（引擎不支援、舊呼叫）時分隔要蓋住跨過格距的填色：畫成格子的暗底色、不透明（alpha 1：底下 1～k 格
    -- 的填色都會穿過格距，半透明會透出紫色），兩側各有 1px 黑邊
    if not geom.mask then
        for _, s in pairs(g.gaps) do
            ns2 = ns2 + 1
            local t = Tex(d.seps, ns2, d.overlay, "OVERLAY")
            t:SetTexture(SOLID)
            t:SetVertexColor(dim[1], dim[2], dim[3], 1)
            Place(t, s.x, s.w, 0, H)
        end
    end
    -- 邊緣陰影（Core/Shape.lua）：每格一圈；格距 0（相鄰兩格共用邊）或只有一格 ⇒ 整列一圈（圍 anchor，l／r 的延伸只在這時有效）。
    -- 陰影框是裝飾父框的子框、層級在 under（省略＝父框）底下一層 ⇒ 鄰列的條身壓在它上面
    local nsh = 0
    local sg, SH = geom.shadow, ns.Shape
    if type(sg) == "table" and SH and SH.NewEdgeShadow then
        local whole = shared or #g.cells == 1
        local count = whole and 1 or #g.cells
        for i = 1, count do
            local sh = d.shadows[i]
            if not sh then
                sh = SH.NewEdgeShadow(d.parent)
                d.shadows[i] = sh
            end
            if sh then
                nsh = i
                SH.PaintEdgeShadow(sh, whole and anchor or d.bgs[i], sg.px, sg.alpha, whole and sg or nil, sg.under)
            end
        end
    end
    for i = nb + 1, #d.bgs do d.bgs[i]:Hide() end
    for i = ne + 1, #d.edges do d.edges[i]:Hide() end
    for i = ns2 + 1, #d.seps do d.seps[i]:Hide() end
    for i = nsh + 1, #d.shadows do ns.Shape.PaintEdgeShadow(d.shadows[i], nil) end
end

-- 列上的裝飾（一直顯示的列）：懶建、原地重排
function AB.RowDecor(row, geom, level)
    local d = row.abDecor
    if not d then
        d = NewDecor(row)
        row.abDecor = d
    end
    if level then d.overlay:SetFrameLevel(level) end
    LayoutDecor(d, row, geom)
    d.overlay:Show()
    -- ⚠ 這裡不能再對暗底 SetAlpha(1)：貼圖的 SetAlpha 跟 SetVertexColor 的第四個參數是同一個值，
    -- 會把 LayoutDecor 剛寫的 dim[4] 打回 1 ⇒ 引擎畫的列暗底永遠不透明、「背景透明度」對它們無效
    -- （玩家回報 2026-10-15 惡魔之核；按鈕子樹裡的裝飾沒走這行所以一直是對的）
    return d
end

function AB.HideRowDecor(row)
    local d = row.abDecor
    if not d then return end
    d.overlay:Hide()
    for _, t in ipairs(d.bgs) do t:Hide() end
    -- 陰影框掛在列上（不在 overlay 底下），要自己收
    if ns.Shape then
        for _, sh in ipairs(d.shadows) do ns.Shape.PaintEdgeShadow(sh, nil) end
    end
end

-- 只重上色、不重排：暗底的顏色／材質、黑邊與分隔的顏色就地改（貼圖的顏色戰鬥中也能寫）。
-- 戰鬥中列是保護框（AuraContainer 連坐），RowDecor 那種 SetPoint／SetSize／Show 要等脫戰；
-- 玩家戰鬥中（打木樁疊層）改背景不透明度／底色／邊框色，引擎寫的列靠這支當場生效（點數型的列本來就每次更新重上色）
function AB.RecolorRowDecor(row, dim, edge, bgTex)
    local d = row.abDecor
    if not d then return end
    local er, eg, eb, ea = 0, 0, 0, 1
    if type(edge) == "table" then er, eg, eb, ea = edge[1] or 0, edge[2] or 0, edge[3] or 0, edge[4] or 1 end
    for _, t in ipairs(d.bgs) do
        if bgTex then t:SetTexture(bgTex) end
        t:SetVertexColor(dim[1], dim[2], dim[3], dim[4])
    end
    for _, t in ipairs(d.edges) do t:SetVertexColor(er, eg, eb, ea) end
    for _, t in ipairs(d.seps) do t:SetVertexColor(dim[1], dim[2], dim[3], 1) end
end

------------------------------------------------------------
-- 簽章與樣式（全部解成純數字；initializeFrame 裡只查這張表）
--
-- spec = { kind = "applications"（預設）| "instances", spellIDs = { id, … }, max, texture,
--          unit ＝ 看誰身上（預設 "player"；"target" 時換目標要叫 AB.Refresh）, filter ＝ 過濾字串（預設 "HELPFUL"）,
--          color = { r, g, b }, alpha, reversed,
--          inside = geom | nil（「有光環才顯示」：裝飾建在按鈕子樹裡），
--          cell = geom（instances 必填：一格的大小與格距，進簽章），
--          text = { font = 路徑, size = 實體像素字級, outline = 描邊旗標, decimals = 小數門檻, gcd = GCD 秒數 | nil, last = 最後一個 GCD 的字,
--                   point = "LEFT"|"CENTER"|"RIGHT"（沒給 ＝ 置中）, pad = 靠邊時離邊的距離（實體像素）,
--                   low = { below, r, g, b, a } | nil（剩餘秒數低於 below 換色：SetDurationText 的 textColor 曲線） }
--                 | nil（duration 專用：秒數文字，進簽章），
--          label = { name, font, size, outline, point, pad, w, off, icon, side, isize, gap, border, edge } | nil
--                 （duration 專用、跟 inside 一起用：名字與圖示建在按鈕子樹裡，進簽章），
--          strip = { h, r, g, b, a } | nil（applications 專用：條底部一條細的「光環剩餘時間」，SetDurationBar，進簽章）,
--          count = { font, size, outline, suffix, mode, decimals } | nil（applications 專用：文字，進簽章）
--                 mode ＝ "stacks"（預設，層數）｜"time"（剩餘秒數）｜"stacksTime"（層數 (秒數)）｜"timeStacks"（秒數 (層數)）；
--                 decimals ＝ 秒數低於這個值印一位小數；point／pad ＝ 層數靠哪一邊（只有 stacks、沒有單位時）；
--                 plain ＝ 層數不給格式器（引擎 0／1 層不印字） }
------------------------------------------------------------
-- 文字的位移（text／count 的 off ＝ { x, y }，已換成 FontString 自己的單位；沒給 ＝ 置中不動）
local function Off(t)
    local o = type(t) == "table" and t.off
    if type(o) ~= "table" then return 0, 0 end
    return tonumber(o[1]) or 0, tonumber(o[2]) or 0
end
local function OffSig(t)
    local x, y = Off(t)
    return Fmt(x) .. "," .. Fmt(y)
end

function AB.Signature(spec)
    local ids = {}
    for _, id in ipairs(spec.spellIDs or {}) do ids[#ids + 1] = tostring(id) end
    table.sort(ids)
    local c = spec.color or {}
    local kindTag = (spec.kind == "instances" and "inst") or (spec.kind == "duration" and "dur") or "apps"
    local parts = {
        kindTag,
        tostring(spec.unit or "player") .. "@" .. tostring(spec.filter or "HELPFUL"),
        table.concat(ids, ","), tostring(spec.max), tostring(spec.texture),
        Fmt(c.r), Fmt(c.g), Fmt(c.b), Fmt(spec.alpha), tostring(spec.reversed and true or false),
    }
    local cg = spec.kind == "instances" and spec.cell
    if cg then
        parts[#parts + 1] = table.concat({ "cell", Fmt(cg.segW), Fmt(cg.H), Fmt(cg.gap) }, ":")
    end
    local tx = spec.kind == "duration" and spec.text
    if type(tx) == "table" then
        parts[#parts + 1] = table.concat({ "txt", tostring(tx.font), Fmt(tx.size), tostring(tx.outline), tostring(tx.decimals),
            OffSig(tx) }, ":")
        if tx.point or tx.pad then parts[#parts + 1] = "tp:" .. tostring(tx.point) .. ":" .. Fmt(tx.pad) end
        local lo = tx.low
        if type(lo) == "table" then
            parts[#parts + 1] = table.concat({ "low", Fmt(lo.below), Fmt(lo.r), Fmt(lo.g), Fmt(lo.b), Fmt(lo.a or 1) }, ":")
        end
        if tx.gcd then parts[#parts + 1] = table.concat({ "gcd", Fmt(tx.gcd), tostring(tx.last) }, ":") end
    end
    local cn = spec.kind ~= "instances" and spec.count
    if type(cn) == "table" then
        parts[#parts + 1] = table.concat({ "cnt", tostring(cn.font), Fmt(cn.size), tostring(cn.outline), tostring(cn.suffix),
            tostring(cn.mode or "stacks"), tostring(cn.decimals), OffSig(cn) }, ":")
        if cn.point or cn.plain then
            parts[#parts + 1] = "cp:" .. tostring(cn.point) .. ":" .. Fmt(cn.pad) .. ":" .. tostring(cn.plain and true or false)
        end
    end
    local sp = spec.kind ~= "instances" and spec.kind ~= "duration" and spec.strip
    if type(sp) == "table" then
        parts[#parts + 1] = table.concat({ "strip", Fmt(sp.h), Fmt(sp.r), Fmt(sp.g), Fmt(sp.b), Fmt(sp.a) }, ":")
    end
    local mk = spec.kind ~= "instances" and spec.kind ~= "duration" and spec.mask
    if type(mk) == "table" then
        parts[#parts + 1] = table.concat({ "mask", Fmt(mk.period), Fmt(mk.gap), Fmt(mk.pixel) }, ":")
    end
    local lb = spec.kind == "duration" and spec.label
    if type(lb) == "table" then
        local e = lb.edge or {}
        parts[#parts + 1] = table.concat({ "lbl", tostring(lb.name), tostring(lb.font), Fmt(lb.size), tostring(lb.outline),
            tostring(lb.point), Fmt(lb.pad), Fmt(lb.w), OffSig(lb), tostring(lb.icon), tostring(lb.side), Fmt(lb.isize),
            Fmt(lb.gap), Fmt(lb.border), Fmt(e[1]), Fmt(e[2]), Fmt(e[3]), Fmt(e[4] or 1) }, ":")
    end
    local g = spec.inside
    if g then
        local dim = g.dim or {}
        local edge = g.edge or {}
        parts[#parts + 1] = table.concat({ "in", Fmt(g.W), Fmt(g.H), tostring(g.n), Fmt(g.gap), Fmt(g.segW),
            tostring(g.segments and true or false), Fmt(g.px), Fmt(dim[1]), Fmt(dim[2]), Fmt(dim[3]), Fmt(dim[4]),
            tostring(g.bgTex), Fmt(edge[1]), Fmt(edge[2]), Fmt(edge[3]), Fmt(edge[4] or 1) }, ":")
        local sg = g.shadow
        if type(sg) == "table" then
            parts[#parts + 1] = table.concat({ "sd", Fmt(sg.px), Fmt(sg.alpha), Fmt(sg.l), Fmt(sg.r) }, ":")
        end
    end
    return table.concat(parts, "|")
end

-- 靠邊的文字離邊多遠（LEFT 往右、RIGHT 往左、置中不動）
function AB.PadX(point, pad)
    pad = tonumber(pad) or 0
    if point == "LEFT" then return pad elseif point == "RIGHT" then return -pad end
    return 0
end

-- 剩餘秒數低於 below 的文字顏色：Step 色彩曲線（x ＝ 剩餘秒數；之前低色、之後白）。依參數快取，
-- 同一組共用一顆；建不起來（API 不在）回 nil ＝ 不變色。x 只在引擎裡，Lua 不 Evaluate
local lowCurves = {}
function AB.LowCurve(below, r, g, b, a)
    below = tonumber(below) or 0
    if below <= 0 then return nil end
    local key = table.concat({ Fmt(below), Fmt(r), Fmt(g), Fmt(b), Fmt(a or 1) }, "|")
    local hit = lowCurves[key]
    if hit ~= nil then return hit or nil end
    lowCurves[key] = false
    local CU = C_CurveUtil
    if not (CU and CU.CreateColorCurve and CreateColor) then return nil end
    local ok, curve = pcall(CU.CreateColorCurve)
    if not ok or not curve then return nil end
    local added = pcall(function()
        local low = CreateColor(tonumber(r) or 1, tonumber(g) or 0.3, tonumber(b) or 0.3, tonumber(a) or 1)
        local white = CreateColor(1, 1, 1, 1)
        curve:AddPoint(0, low)
        curve:AddPoint(below, low)
        curve:AddPoint(below + 0.01, white)
        curve:AddPoint(below + 86400, white)
    end)
    if not added then return nil end
    lowCurves[key] = curve
    return curve
end

------------------------------------------------------------
-- 持有框、容器
------------------------------------------------------------
local function Kick(c)
    pcall(function() c:Hide(); c:Show() end)
    if c.SetEnabled then pcall(c.SetEnabled, c, true) end
end

-- ⚠ 只踢「現在該顯示」的那顆（h.shownC）：列是池化的，持有框跟著列、容器留在池子裡。列換成別的資源
-- （HideContainer 收起來、shownC = false）之後列 Hide→Show（換型態、面板顯示條件），持有框的 OnShow 一樣會進來，
-- 這時不看 shownC 就把上一個資源的容器踢回畫面——守護德魯伊把鐵鬃排在怒氣上面、人形換回熊形之後，
-- 怒氣列上疊著一條鐵鬃的時間條（NGA 回報 2026-10-16），而且沒有任何東西會再把它收掉
local function OnHolderShow(h)
    local c = h.container
    if not c or not h.shownC then return end
    if InCombatLockdown() then
        h.pendingKick = true
        ns.Events.Register("PLAYER_REGEN_ENABLED", "aurabar", AB.OnRegen)
    else
        h.pendingKick = nil
        Kick(c)
    end
end

-- 一列一顆持有框（列是池化的，持有框跟著列、永不改用）。onRegen：脫戰補建好之後要列重排
function AB.New(row, onRegen)
    local h = CreateFrame("Frame", nil, row)
    h:SetAllPoints(row)
    h:EnableMouse(false)
    h.containers = {}
    h.okSigs, h.errSigs = {}, {}
    h.container, h.sig, h.shownC, h.pendingKick = false, false, false, false
    h.onRegen = onRegen
    -- 掛勾裡只記帳，工作丟到下一幀（容器層的 Show 可能在別人的流程裡）
    h:HookScript("OnShow", function() ns.Defer(OnHolderShow, h) end)
    return h
end

-- 剩餘秒數（duration 專用）：字型先給才能交出去（引擎會 SetText）；失敗只丟文字、不丟條
local function InitTimerText(btn, bar, st)
    local tx = st.text
    local tf = CreateFrame("Frame", nil, btn)
    tf:SetAllPoints(btn)
    tf:SetFrameLevel((bar:GetFrameLevel() or 1) + 10)
    local fs = tf:CreateFontString(nil, "OVERLAY")
    fs:SetFont(tx.font, tx.size, tx.outline or "OUTLINE")
    pcall(fs.SetIgnoreParentScale, fs, true)
    fs:SetTextColor(1, 1, 1, 1)
    local pt = tx.point or "CENTER"
    local ox, oy = Off(tx)
    fs:SetJustifyH(pt)
    fs:SetPoint(pt, btn, pt, ox + AB.PadX(pt, tx.pad), oy)
    -- 低秒變色：色彩曲線交給引擎（x ＝ 剩餘秒數，Lua 不讀）；不收就退回只有格式器
    if st.curve and st.remainingProp then
        local opts = { textColor = { curve = st.curve, property = st.remainingProp } }
        if st.formatter then opts.textFormatter = st.formatter end
        if pcall(btn.SetDurationText, btn, fs, opts) then return end
    end
    if not (st.formatter and pcall(btn.SetDurationText, btn, fs, { textFormatter = st.formatter })) then
        btn:SetDurationText(fs)
    end
end

-- 名字與圖示（duration 的 label，只在「只在生效時顯示」的列）：內容是建立當下的純字串／純檔案編號，
-- 之後不改。圖示貼在按鈕外側（條身就是按鈕，圖示在它左邊或右邊），框色＝邊框色、圖示內縮邊框粗細
local function InitLabel(btn, bar, st)
    local lb = st.label
    if lb.name then
        local tf = CreateFrame("Frame", nil, btn)
        tf:SetAllPoints(btn)
        tf:SetFrameLevel((bar:GetFrameLevel() or 1) + 10)
        local fs = tf:CreateFontString(nil, "OVERLAY")
        fs:SetFont(lb.font, lb.size, lb.outline or "OUTLINE")
        pcall(fs.SetIgnoreParentScale, fs, true)
        fs:SetTextColor(1, 1, 1, 1)
        local pt = lb.point or "LEFT"
        local ox, oy = Off(lb)
        fs:SetJustifyH(pt)
        fs:SetWordWrap(false)
        if (tonumber(lb.w) or 0) > 0 then fs:SetWidth(lb.w) end
        fs:SetPoint(pt, btn, pt, ox + AB.PadX(pt, lb.pad), oy)
        fs:SetText(lb.name)
    end
    if lb.icon and (lb.side == "left" or lb.side == "right") then
        local size, gap, b = tonumber(lb.isize) or 1, tonumber(lb.gap) or 0, tonumber(lb.border) or 0
        local e = lb.edge or {}
        local frame = btn:CreateTexture(nil, "BACKGROUND")
        frame:SetColorTexture(e[1] or 0, e[2] or 0, e[3] or 0, e[4] or 1)
        frame:SetSize(size, size)
        if lb.side == "left" then
            frame:SetPoint("TOPRIGHT", btn, "TOPLEFT", -gap, 0)
        else
            frame:SetPoint("TOPLEFT", btn, "TOPRIGHT", gap, 0)
        end
        local ic = btn:CreateTexture(nil, "ARTWORK")
        ic:SetTexture(lb.icon)
        ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        ic:SetPoint("TOPLEFT", frame, "TOPLEFT", b, -b)
        ic:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -b, b)
    end
end

-- 文字層（applications 專用）的一顆 FontString：自己一層子框、字型先給（引擎會 SetText）、忽略父層縮放
local function TextFS(tf, cn)
    local fs = tf:CreateFontString(nil, "OVERLAY")
    fs:SetFont(cn.font, cn.size, cn.outline or "OUTLINE")
    pcall(fs.SetIgnoreParentScale, fs, true)
    fs:SetTextColor(1, 1, 1, 1)
    return fs
end

-- 秒數交給 SetDurationText。wrap ＝ 用引擎的 textFormat 包一層（"({})"：秒數的括號，數字仍由格式器排）；
-- 包不起來退回只有秒數、格式器也不吃就用引擎預設
local function BindDuration(btn, fs, st, wrap)
    local fmt = st.formatter
    local P = Enum and Enum.DurationTextBindingProperty
    if wrap and fmt and P then
        local ok = pcall(btn.SetDurationText, btn, fs, { textFormat = {
            formatString = wrap, components = { { property = P.RemainingDuration, formatter = fmt } } } })
        if ok then return end
    end
    if not (fmt and pcall(btn.SetDurationText, btn, fs, { textFormatter = fmt })) then
        btn:SetDurationText(fs)
    end
end

-- 文字層（applications 專用），照 cn.mode：
--   stacks      層數交給 SetApplicationCount，給 C 端格式器 "%d"（不給的話引擎 1 層不印；光環不在時按鈕藏著，
--               所以不會印 0）。單位（cn.suffix，無視苦痛的「%」）是另一顆固定字，兩顆貼在按鈕中線偏右一點的
--               同一個點上（層數靠右、單位靠左）；有單位的（無視苦痛）照舊不給格式器（第 69 條實測過的路）
--   time        剩餘秒數置中（SetDurationText）
--   stacksTime  「4 (3.2)」：層數靠右停在中線左邊、秒數用 textFormat "({})" 靠左從中線右邊起
--   timeStacks  「3.2 (4)」：秒數靠右停在中線左邊、層數靠左從中線右邊起，括號是層數的格式器 "(%d)"
-- 兩段的寬度都是秘密值 ⇒ 不互相錨定，各自錨在按鈕中線上（字長不同時整體會偏離正中一點）
local function InitCountText(btn, bar, cn, st)
    local tf = CreateFrame("Frame", nil, btn)
    tf:SetAllPoints(btn)
    tf:SetFrameLevel((bar:GetFrameLevel() or 1) + 10)
    local mode = cn.mode or "stacks"
    local ox, oy = Off(cn)
    if mode == "time" then
        local fs = TextFS(tf, cn)
        fs:SetJustifyH("CENTER")
        fs:SetPoint("CENTER", btn, "CENTER", ox, oy)
        BindDuration(btn, fs, st)
        return
    end
    if mode == "stacksTime" or mode == "timeStacks" then
        local half = (tonumber(cn.size) or 10) * 0.15
        local left, right = TextFS(tf, cn), TextFS(tf, cn)
        left:SetJustifyH("RIGHT")
        left:SetPoint("RIGHT", btn, "CENTER", -half + ox, oy)
        right:SetJustifyH("LEFT")
        right:SetPoint("LEFT", btn, "CENTER", half + ox, oy)
        if mode == "stacksTime" then
            btn:SetApplicationCount(left, st.countFormatter and { formatter = st.countFormatter } or {})
            BindDuration(btn, right, st, "({})")
        else
            BindDuration(btn, left, st)
            btn:SetApplicationCount(right, st.countFormatter and { formatter = st.countFormatter } or {})
        end
        return
    end
    local hasSuffix = cn.suffix and cn.suffix ~= ""
    if cn.point and not hasSuffix then
        -- 靠邊的層數（自訂列）：自己一個點，不跟單位那顆並排
        local fs = TextFS(tf, cn)
        fs:SetJustifyH(cn.point)
        fs:SetPoint(cn.point, btn, cn.point, ox + AB.PadX(cn.point, cn.pad), oy)
        btn:SetApplicationCount(fs, st.countFormatter and { formatter = st.countFormatter } or {})
        return
    end
    local off = hasSuffix and (tonumber(cn.size) or 10) * 0.3 or 0
    local fs = TextFS(tf, cn)
    if off > 0 then
        fs:SetJustifyH("RIGHT")
        fs:SetPoint("RIGHT", btn, "CENTER", off + ox, oy)
    else
        fs:SetJustifyH("CENTER")
        fs:SetPoint("CENTER", btn, "CENTER", ox, oy)
    end
    btn:SetApplicationCount(fs, (off <= 0 and st.countFormatter) and { formatter = st.countFormatter } or {})
    if off > 0 then
        local sx = TextFS(tf, cn)
        sx:SetJustifyH("LEFT")
        sx:SetPoint("LEFT", btn, "CENTER", off + ox, oy)
        sx:SetText(cn.suffix)
    end
end

-- ⚠ 只能從 initializeFrame 呼叫（外面包 xpcall）。不 CreateColor、不掛 script、顏色純數字
local function InitButton(btn, c, st, h, sig)
    pcall(btn.SetMouseClickEnabled, btn, false)
    pcall(btn.SetMouseMotionEnabled, btn, false)       -- 純顯示：別擋住底下的東西
    if st.kind ~= "instances" then
        pcall(function()
            btn:ClearAllPoints()
            btn:SetAllPoints(c)                        -- slot 的按鈕不參與 flow layout
        end)
    else
        -- group 的流式排版只 SetPoint、**不設尺寸**（elementWidth／Height 只拿來算位置），
        -- 按鈕自己沒尺寸就是 0x0、什麼都看不到 ⇒ 一格的大小在這裡給
        pcall(btn.SetSize, btn, st.cell.segW, st.cell.H)
    end
    local g = st.inside
    if g then
        -- 「有光環才顯示」：暗底、黑邊、分隔全建在按鈕子樹裡
        local d = NewDecor(btn)
        LayoutDecor(d, btn, g)
        st.decorOverlay = d.overlay
    end
    local bar = CreateFrame("StatusBar", nil, btn)
    bar:SetAllPoints(btn)
    bar:SetStatusBarTexture(st.texture)
    NoSnap(bar)              -- 填充跟裝飾的 1px 邊相接：不貼齊
    local t = bar:GetStatusBarTexture()
    if t then t:SetVertexColor(st.r, st.g, st.b, st.alpha) end
    bar:SetReverseFill(st.reversed)
    -- 不自己 SetMinMaxValues／SetValue：引擎每次套用都寫 (0, maxApplications) 與層數
    if g and st.decorOverlay then
        st.decorOverlay:SetFrameLevel((bar:GetFrameLevel() or 1) + 2)
    end
    if st.kind == "instances" then
        -- 一顆光環一格：剩餘時間（CustomAuraButtonDurationBarOptions：interpolation、direction）
        local opts = {}
        if st.remaining then opts.direction = st.remaining end
        btn:SetDurationBar(bar, opts)
    elseif st.kind == "duration" then
        -- 光環剩餘時間：整列寬一條，引擎用光環自己的持續時間往下縮（值、上限都不經 Lua）
        local opts = {}
        if st.remaining then opts.direction = st.remaining end
        if st.interp then opts.interpolation = st.interp end
        btn:SetDurationBar(bar, opts)
        if st.text and btn.SetDurationText then
            local ok, err = pcall(InitTimerText, btn, bar, st)
            if not ok then AB.lastError = tostring(err) end
        end
        -- 時間條上也可以印層數（鐵鬃：條身是剩餘時間、中間是層數），只收 stacks 型
        if st.count and btn.SetApplicationCount then
            local ok, err = pcall(InitCountText, btn, bar, st.count, st)
            if not ok then AB.lastError = tostring(err) end
        end
        if st.label then
            local ok, err = pcall(InitLabel, btn, bar, st)
            if not ok then AB.lastError = tostring(err) end
        end
    else
        -- CustomAuraButtonApplicationBarOptions：maxApplications（必填）、interpolation（可省）。
        -- 12.1.5 多一個 minApplications（預設 0），12.1.0 沒有 ⇒ 不傳
        local opts = { maxApplications = st.max }
        if st.interp then opts.interpolation = st.interp end
        btn:SetApplicationBar(bar, opts)
        -- 透明格距：填色貼圖掛 REPEAT 遮罩（擺法 st.mask ＝ AB.MaskPlan 算好的表）。失敗只記錯、條照常
        if st.mask and bar.GetStatusBarTexture and btn.CreateMaskTexture then
            local ok, err = pcall(function()
                local ft = bar:GetStatusBarTexture()
                if not (ft and ft.AddMaskTexture) then return end
                for _, m in ipairs(st.mask) do
                    local mask = btn:CreateMaskTexture()
                    mask:SetTexture(AB.MaskFile(m.den), "REPEAT", "CLAMPTOWHITE")
                    if st.reversed then
                        -- 從右往左填：圖左右翻、從條右緣往外 x 起算
                        mask:SetTexCoord(1, 0, 0, 1)
                        mask:SetPoint("TOPRIGHT", bar, "TOPRIGHT", m.x, 0)
                        mask:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", m.x, 0)
                    else
                        mask:SetPoint("TOPLEFT", bar, "TOPLEFT", m.x, 0)
                        mask:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", m.x, 0)
                    end
                    mask:SetWidth(m.w)
                    ft:AddMaskTexture(mask)
                end
            end)
            if not ok then AB.lastError = tostring(err) end
        end
        -- 剩餘時間細條（無視苦痛）：同一顆按鈕再交一條 SetDurationBar，引擎用光環自己的持續時間（含延長）
        local sp = st.strip
        if sp and btn.SetDurationBar then
            local ok, err = pcall(function()
                local sb = CreateFrame("StatusBar", nil, btn)
                sb:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
                sb:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
                sb:SetHeight(sp.h)
                sb:SetStatusBarTexture(SOLID)
                local t = sb:GetStatusBarTexture()
                if t then t:SetVertexColor(sp.r, sp.g, sp.b, sp.a) end
                sb:SetReverseFill(st.reversed)
                sb:SetFrameLevel((bar:GetFrameLevel() or 1) + 3)
                local opts = {}
                if st.remaining then opts.direction = st.remaining end
                btn:SetDurationBar(sb, opts)
            end)
            if not ok then AB.lastError = tostring(err) end
        end
        -- 層數文字失敗只丟文字、不丟條
        if st.count and btn.SetApplicationCount then
            local ok, err = pcall(InitCountText, btn, bar, st.count, st)
            if not ok then AB.lastError = tostring(err) end
        end
    end
    h.okSigs[sig] = true
end

local function BuildContainer(h, st, sig)
    local c = CreateFrame("AuraContainer", nil, h, "CustomAuraContainerTemplate")
    c:SetAllPoints(h)
    c:SetFrameLevel((h:GetFrameLevel() or 1) + 1)
    -- 建立順序：SetUnit 在 slot 之前、SetEnabled 最後（本套組實跑過的順序）
    c:SetUnit(st.unit)
    local include = {}
    for _, id in ipairs(st.spellIDs) do include[id] = true end
    local handler = function(err)
        h.errSigs[sig] = tostring(err)
        AB.lastError = tostring(err)
        if ns.ReportError then ns.ReportError(err) end
    end
    local init = function(btn)
        xpcall(InitButton, handler, btn, c, st, h, sig)
    end
    if st.kind == "instances" then
        -- 從右到左：流式排版改錨右上、往左長（預設是左上、往右下長）
        if st.reversed then
            local FD = AnchorUtil and AnchorUtil.FlowDirection
            if c.SetFlowLayoutAnchorPoint then pcall(c.SetFlowLayoutAnchorPoint, c, "TOPRIGHT") end
            if FD and c.SetFlowLayoutGrowthDirection then pcall(c.SetFlowLayoutGrowthDirection, c, FD.Left, FD.Down) end
        end
        local cg = st.cell
        c:AddAuraGroup("bar", st.filter, {
            maxFrameCount = st.max,
            candidateFilters = { includeSpellIDs = include },
            initializeFrame = init,
            layout = { elementWidth = cg.segW, elementHeight = cg.H, elementSpacing = cg.gap },
        })
    else
        c:AddAuraSlot("bar", st.filter, {
            candidateFilters = { includeSpellIDs = include },
            initializeFrame = init,
        })
    end
    if c.SetEnabled then pcall(c.SetEnabled, c, true) end
    return c
end

-- 對上容器。回傳 "ready" | "pending"（戰鬥中，脫戰會叫 onRegen）| "failed"（這個簽章建不起來，
-- 呼叫端退回明文路徑）。容器層的 Show／Hide 走 ns.Write
function AB.Apply(h, spec)
    local sig = AB.Signature(spec)
    if h.errSigs[sig] then
        AB.HideContainer(h)
        return "failed"
    end
    if h.sig == sig and h.container then
        if not h.shownC then
            h.shownC = true
            ns.Write(h.container, function(c) c:Show() end, "shown")
        end
        return "ready"
    end
    if InCombatLockdown() then
        pending[h] = true
        ns.Events.Register("PLAYER_REGEN_ENABLED", "aurabar", AB.OnRegen)
        return "pending"
    end
    pending[h] = nil
    local old = h.container
    local c = h.containers[sig]
    if c then
        pcall(c.Show, c)
        Kick(c)
    else
        local c2 = spec.color or {}
        local st = {
            spellIDs = spec.spellIDs, max = math.max(1, math.floor(tonumber(spec.max) or 1)),
            unit = spec.unit or "player", filter = spec.filter or "HELPFUL",
            texture = spec.texture or SOLID,
            r = tonumber(c2.r) or 1, g = tonumber(c2.g) or 1, b = tonumber(c2.b) or 1,
            alpha = tonumber(spec.alpha) or 1, reversed = spec.reversed and true or false,
            inside = spec.inside, kind = spec.kind, cell = spec.cell,
            strip = (spec.kind ~= "instances" and spec.kind ~= "duration" and type(spec.strip) == "table") and spec.strip or nil,
            -- 透明格距：遮罩的擺法在這裡算好（initializeFrame 只照表建）
            mask = (spec.kind ~= "instances" and spec.kind ~= "duration" and type(spec.mask) == "table")
                and AB.MaskPlan(spec.mask.period, (tonumber(spec.mask.gap) or 0) + (tonumber(spec.mask.pixel) or 0), spec.mask.pixel) or nil,
            text = (spec.kind == "duration" and type(spec.text) == "table") and spec.text or nil,
            label = (spec.kind == "duration" and type(spec.label) == "table") and spec.label or nil,
            count = (spec.kind ~= "instances" and type(spec.count) == "table"
                and (spec.kind ~= "duration" or (spec.count.mode or "stacks") == "stacks")) and spec.count or nil,
            interp = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate or nil,
            remaining = Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime or nil,
        }
        -- formatter 在這裡（正常插件路徑）先建好：initializeFrame 裡只查表
        if st.text and ns.Text then
            if st.text.gcd and ns.Text.GcdFormatter then
                -- 剩幾個 GCD；格式器建不起來就退回秒數
                st.formatter = ns.Text.GcdFormatter(st.text.gcd, st.text.last)
            end
            if not st.formatter and ns.Text.PlainFormatter then
                st.formatter = ns.Text.PlainFormatter(st.text.decimals)
            end
        end
        -- 低秒變色的色彩曲線（同上：initializeFrame 裡不建物件）
        if st.text and type(st.text.low) == "table" then
            local lo = st.text.low
            st.curve = AB.LowCurve(lo.below, lo.r, lo.g, lo.b, lo.a)
            local P = Enum and Enum.DurationTextBindingProperty
            st.remainingProp = P and P.RemainingDuration or nil
        end
        -- 層數列的文字要秒數時：秒數格式器、「秒數 (層數)」的層數括號格式器，同樣先建好
        -- 層數格式器：1 層也印（不給格式器時引擎 1 層不印）；有單位的（無視苦痛「%」）不給
        local cn = st.count
        if cn and ns.Text then
            local mode = cn.mode or "stacks"
            if mode ~= "stacks" and ns.Text.PlainFormatter then
                st.formatter = ns.Text.PlainFormatter(cn.decimals)
            end
            if ns.Text.CountFormatter and not cn.plain and not (cn.suffix and cn.suffix ~= "") and mode ~= "time" then
                st.countFormatter = ns.Text.CountFormatter(mode == "timeStacks" and "(%d)" or "%d")
            end
        end
        if st.kind == "instances" and type(st.cell) ~= "table" then
            h.errSigs[sig] = "instances without cell geometry"
            return "failed"
        end
        local ok, built = pcall(BuildContainer, h, st, sig)
        if not ok or not built then
            h.errSigs[sig] = tostring(built)
            AB.lastError = tostring(built)
            if ns.ReportError then ns.ReportError(built) end
            return "failed"
        end
        c = built
        h.containers[sig] = c
        AB.builds = AB.builds + 1
        -- initializeFrame 失敗（例如沒有 SetApplicationBar）：這個簽章記成失敗，退回明文路徑
        if h.errSigs[sig] then
            pcall(c.Hide, c)
            return "failed"
        end
    end
    if old and old ~= c then pcall(old.Hide, old) end
    h.container, h.sig, h.shownC = c, sig, true
    return "ready"
end

-- 看 target 的容器：換目標時容器自己不會重掃（只聽 UNIT_AURA），要外部叫 UpdateAllAuras。
-- 這支在暴雪的 inbound（secureDelegates）介面上，暴雪註解寫明開放給「換目標之類的外部事件」用
function AB.Refresh(h)
    local c = h and h.container
    if c and c.UpdateAllAuras then pcall(c.UpdateAllAuras, c) end
end

-- 列換成別的內容（或整列不顯示）：目前的容器收起來（留在池子裡）
function AB.HideContainer(h)
    if not (h and h.container and h.shownC) then return end
    h.shownC = false
    ns.Write(h.container, function(c) c:Hide() end, "shown")
end

-- 這顆持有框目前的容器有沒有真的把條交給按鈕（initializeFrame 跑完）。按鈕是懶建的時候
-- 會是 nil（還不知道），不是 false
function AB.Bound(h)
    if not (h and h.sig) then return nil end
    if h.errSigs and h.errSigs[h.sig] then return false end
    if h.okSigs and h.okSigs[h.sig] then return true end
    return nil
end

function AB.IsPending(h) return pending[h] and true or false end

------------------------------------------------------------
-- /mcdm debug：一顆持有框的細節（「整列空白」要分得出是容器沒建、按鈕沒出來、還是按鈕出來了卻看不到）
-- 讀值一律 pcall、秘密值只印「秘密」不比較。玩家身上的光環另外用明文 API 掃一次對照（戰鬥中可能整串秘密）
------------------------------------------------------------
local function DTxt(v)
    if ns.IsSecret and ns.IsSecret(v) then return "秘密" end
    if type(v) == "number" then return (("%.1f"):format(v):gsub("%.0$", "")) end
    return tostring(v)
end

local function DRead(obj, method, ...)
    local fn = obj and obj[method]
    if type(fn) ~= "function" then return "✕" end
    local ok, a, b = pcall(fn, obj, ...)
    if not ok then return "err" end
    if b ~= nil then return DTxt(a) .. "x" .. DTxt(b) end
    return DTxt(a)
end

function AB.DebugLines(h, spellIDs, indent)
    indent = indent or "       "
    local out = {}
    if not h then
        out[1] = indent .. "光環條：沒有持有框"
        return out
    end
    local sig = h.sig or "—"
    out[#out + 1] = ("%s光環條：簽章 %s  建過 %d 顆  待建 %s  持有框 顯示 %s／可見 %s／尺寸 %s  補踢待辦 %s")
        :format(indent, tostring(sig), AB.builds, tostring(pending[h] and true or false),
            DRead(h, "IsShown"), DRead(h, "IsVisible"), DRead(h, "GetSize"), tostring(h.pendingKick))
    local err = h.sig and h.errSigs and h.errSigs[h.sig]
    if err then out[#out + 1] = indent .. "  這個簽章的錯誤：" .. tostring(err) end
    if AB.lastError then out[#out + 1] = indent .. "  最近錯誤：" .. tostring(AB.lastError) end
    local c = h.container
    if c then
        local kids = { pcall(function() return c:GetChildren() end) }
        local nKids, nShown = 0, 0
        local sizes = {}
        if kids[1] then
            for i = 2, #kids do
                local b = kids[i]
                nKids = nKids + 1
                local ok, s = pcall(b.IsShown, b)
                if ok and not (ns.IsSecret and ns.IsSecret(s)) and s then nShown = nShown + 1 end
                if #sizes < 6 then
                    sizes[#sizes + 1] = ("%s@%s%s"):format(DRead(b, "GetSize"), DRead(b, "GetLeft"),
                        (ok and (ns.IsSecret and ns.IsSecret(s))) and "(顯示秘密)" or (ok and s) and "" or "(藏)")
                end
            end
        end
        -- 啟用／UNIT_AURA 有沒有註冊：容器只在「可見且啟用」時註冊（暴雪 UpdateEventRegistrations），
        -- 沒註冊 ＝ 身上有光環也不會出按鈕（補踢沒做到的指紋）
        out[#out + 1] = ("%s  容器：顯示 %s／可見 %s／啟用 %s／UNIT_AURA 註冊 %s／尺寸 %s／alpha %s／層級 %s  按鈕 %s 顆（顯示 %d）%s")
            :format(indent, DRead(c, "IsShown"), DRead(c, "IsVisible"), DRead(c, "IsEnabled"),
                DRead(c, "IsEventRegistered", "UNIT_AURA"), DRead(c, "GetSize"),
                DRead(c, "GetEffectiveAlpha"), DRead(c, "GetFrameLevel"),
                kids[1] and tostring(nKids) or ("讀不到：" .. tostring(kids[2])), nShown,
                #sizes > 0 and ("  " .. table.concat(sizes, " ")) or "")
    else
        out[#out + 1] = indent .. "  容器：沒有"
    end
    -- 明文對照：身上這幾個 ID 的光環有幾顆、每顆的層數欄（鐵鬃這類「一施放一顆」的層數欄應該是 0）
    local U = C_UnitAuras
    if type(spellIDs) == "table" and U and U.GetAuraDataByIndex then
        local want = {}
        for _, id in ipairs(spellIDs) do want[id] = true end
        local found, secret = {}, 0
        for i = 1, 80 do
            local ok, a = pcall(U.GetAuraDataByIndex, "player", i, "HELPFUL")
            if not ok or type(a) ~= "table" then break end
            local sid = a.spellId
            if ns.IsSecret and ns.IsSecret(sid) then
                secret = secret + 1
            elseif want[sid] then
                found[#found + 1] = ("%s(層數 %s)"):format(DTxt(sid), DTxt(a.applications))
            end
        end
        local direct = {}
        if U.GetPlayerAuraBySpellID then
            for _, id in ipairs(spellIDs) do
                local ok, a = pcall(U.GetPlayerAuraBySpellID, id)
                direct[#direct + 1] = ("%s=%s"):format(tostring(id),
                    not ok and "err" or type(a) ~= "table" and "nil" or ("層數 " .. DTxt(a.applications)))
            end
        end
        out[#out + 1] = ("%s  身上（明文掃描）：%s%s  直接查：%s"):format(indent,
            #found > 0 and table.concat(found, "、") or "沒有",
            secret > 0 and ("（另有 " .. secret .. " 顆 ID 是秘密）") or "", table.concat(direct, " "))
    end
    return out
end

------------------------------------------------------------
-- 脫戰：補建、補踢
------------------------------------------------------------
function AB.OnRegen()
    ns.Events.Unregister("PLAYER_REGEN_ENABLED", "aurabar")
    local list = {}
    for h in pairs(pending) do list[#list + 1] = h end
    for _, h in ipairs(list) do
        pending[h] = nil
        if h.onRegen then
            local ok, err = xpcall(h.onRegen, ns.ReportError)
            if not ok then AB.lastError = err end
        end
    end
end

-- 持有框 OnShow 記下的補踢（戰鬥中顯示的），脫戰由 Pips／Resources 的重排順手做：
-- 那裡本來就會在脫戰重排，重排走 AB.Apply ⇒ 同簽章直接回 ready，所以補踢另外做
function AB.KickPending(h)
    if h and h.pendingKick and not InCombatLockdown() then
        h.pendingKick = nil
        if h.container and h.shownC then Kick(h.container) end
    end
end
